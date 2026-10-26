// AppIconPipeline — 异步图标管道（wave1-interfaces.md §D / §5.3 逐项落点）
// 设计要点：
// - 同 IconKey in-flight 合并（inFlightMerged）；cache hit 不重载；
// - 有界内存缓存（count/cost 双上界 + LRU）；memory pressure 清理；
// - 单 consumer 取消不影响他人；全部取消才取消底层（cancelAll）；
// - 所有 UI 写回 MainActor；shutdown 后零回调；
// - 过期 completion 可进 cache 但不得写回旧 cell：pipeline 无条件投递 + 调用方按
//   generation 门控（onApply 携带调用方注入的 generation，供 UI 校验复用串图）；
// - 图标字节/哈希/路径不入 telemetry：stats 仅计数；
// - 加载后统一缩略：最大 256×256（用户指定；写回缓存前纯内存等比缩放，缓存 cost 自动按新尺寸计）。

import AppCatalogCore
import AppKit
import Foundation

// MARK: - Stats（仅计数与估计 cost；无字节/哈希/路径）

public struct IconPipelineStats: Sendable, Equatable {
    public var requests: Int            // 被接受的 request() 次数（shutdown 后拒绝的不计）
    public var cacheHits: Int
    public var cacheMisses: Int         // 缓存未命中次数（含随后合并到 in-flight 的请求；requests == hits + misses）
    public var inFlightMerged: Int      // 命中 in-flight 合并的请求数
    public var cancellations: Int       // 被取消的 consumer 数（单 consumer cancel + cancelAll）
    public var evictions: Int           // 缓存驱逐数（LRU 上界 + purgeExpired + 手动 purgeAll）
    public var memoryPressurePurges: Int // memory pressure 清理移除的条目数

    public init(requests: Int = 0, cacheHits: Int = 0, cacheMisses: Int = 0,
                inFlightMerged: Int = 0, cancellations: Int = 0,
                evictions: Int = 0, memoryPressurePurges: Int = 0) {
        self.requests = requests
        self.cacheHits = cacheHits
        self.cacheMisses = cacheMisses
        self.inFlightMerged = inFlightMerged
        self.cancellations = cancellations
        self.evictions = evictions
        self.memoryPressurePurges = memoryPressurePurges
    }
}

// MARK: - 最大并发闸

/// 异步信号量（permits 个并发）。
private actor AsyncSemaphore {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Bool, Never>
    }
    private var permits: Int
    private var waitQueue: [Waiter] = []
    var waitingCount: Int { waitQueue.count }

    init(permits: Int) { self.permits = permits }

    private func acquire() async -> Bool {
        let id = UUID()
        return await withTaskCancellationHandler(operation: {
            guard !Task.isCancelled else { return false }
            if permits > 0 { permits -= 1; return true }
            return await withCheckedContinuation { continuation in
                // Covers cancellation before the handler's actor hop arrives.
                guard !Task.isCancelled else { continuation.resume(returning: false); return }
                waitQueue.append(.init(id: id, continuation: continuation))
            }
        }, onCancel: {
            Task { await self.cancelWaiter(id) }
        })
    }

    private func cancelWaiter(_ id: UUID) {
        guard let index = waitQueue.firstIndex(where: { $0.id == id }) else { return }
        waitQueue.remove(at: index).continuation.resume(returning: false)
    }

    private func release() {
        if waitQueue.isEmpty { permits += 1 }
        else { waitQueue.removeFirst().continuation.resume(returning: true) }
    }

    func withPermit<T>(_ body: () async throws -> T) async throws -> T {
        guard await acquire() else { throw CancellationError() }
        defer { release() }
        // Grant and cancellation can race; a granted canceled waiter still owes
        // exactly one release, but must never start a now-unowned native load.
        try Task.checkCancellation()
        return try await body()
    }
}

// MARK: - Consumer（单请求消费者；投递/取消互斥）

private final class Consumer: @unchecked Sendable {
    enum State {
        case pending
        case delivered
        case cancelled
    }

    let key: IconKey
    let generation: UInt64
    let onApply: @MainActor @Sendable (IconKey, UInt64, IconResult) -> Void

    private let stateLock = NSLock()
    private var state: State = .pending

    init(key: IconKey, generation: UInt64,
         onApply: @escaping @MainActor @Sendable (IconKey, UInt64, IconResult) -> Void) {
        self.key = key
        self.generation = generation
        self.onApply = onApply
    }

    /// 尝试标记为已投递；已在 cancelled/delivered 状态返回 false（取消与投递竞争：先到者胜）。
    func tryMarkDelivered() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard state == .pending else { return false }
        state = .delivered
        return true
    }

    func tryMarkCancelled() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard state == .pending else { return false }
        state = .cancelled
        return true
    }
}

// MARK: - Handle（单 consumer 取消）

public final class IconRequestHandle: @unchecked Sendable {
    private weak var pipeline: IconPipeline?
    private let key: IconKey
    private let consumer: Consumer?

    fileprivate init(pipeline: IconPipeline?, key: IconKey, consumer: Consumer?) {
        self.pipeline = pipeline
        self.key = key
        self.consumer = consumer
    }

    /// 单 consumer 取消；幂等；不影响同 key 其他 consumer。
    /// shutdown 后返回的惰性 handle 取消为空操作。
    public func cancel() {
        guard let pipeline, let consumer else { return }
        pipeline.cancelConsumer(consumer, key: key)
    }
}

// MARK: - Pipeline

public final class IconPipeline: @unchecked Sendable {
    private final class InFlightEntry {
        let loadID: UUID
        let task: Task<Void, Never>
        var consumers: [Consumer]
        init(loadID: UUID, task: Task<Void, Never>, consumers: [Consumer]) {
            self.loadID = loadID
            self.task = task
            self.consumers = consumers
        }
    }

    /// macOS 26 SDK 已移除 `NSApplication.didReceiveMemoryWarningNotification` 常量；
    /// 通知名（运行时字符串）仍由系统投递，按冻结契约继续监听，测试可直接 post。
    private let memoryWarningNotificationName =
        Notification.Name("NSApplicationDidReceiveMemoryWarningNotification")

    private let loader: any IconLoading
    private let limits: IconCacheLimits
    private let limiter: AsyncSemaphore
    private let lock = NSLock()
    private let memoryPressureQueue = DispatchQueue(label: "AppIconPipeline.memoryPressure")
    private var cache: IconCache
    private var inFlight: [IconKey: InFlightEntry] = [:]
    // Only accepted, not-yet-admitted MainActor callbacks are retained here.
    // No source-generation tombstones or catalog history accumulate.
    private var queuedDeliveries: [ObjectIdentifier: Consumer] = [:]
    private var processedLoadResults: UInt64 = 0
    private var counters = IconPipelineStats()
    private var isShutdown = false
    private var memoryPressureObserver: NSObjectProtocol?
    private var memoryPressureSource: DispatchSourceMemoryPressure?

    public init(loader: any IconLoading, limits: IconCacheLimits) {
        self.loader = loader
        self.limits = limits
        self.limiter = AsyncSemaphore(permits: max(1, limits.maxConcurrentLoads))
        self.cache = IconCache(limits: limits)
        self.memoryPressureObserver = NotificationCenter.default.addObserver(
            forName: memoryWarningNotificationName,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleMemoryPressure()
        }
        // 生产兜底：系统级 memory pressure 源（双通道汇入同一清理路径）
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: memoryPressureQueue
        )
        source.setEventHandler { [weak self] in
            self?.handleMemoryPressure()
        }
        source.resume()
        self.memoryPressureSource = source
    }

    deinit {
        if let memoryPressureObserver {
            NotificationCenter.default.removeObserver(memoryPressureObserver)
        }
        memoryPressureSource?.cancel()
        lock.lock()
        for entry in inFlight.values {
            entry.task.cancel()
        }
        inFlight.removeAll()
        lock.unlock()
    }

    /// 锁作用域辅助（同步；规避 async 上下文中 NSLock 的不可用标注）。
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    // MARK: 请求

    /// 请求图标：cache hit 直接投递；同 key in-flight 合并；否则经并发闸调 loader。
    /// 所有 onApply 写回都在 MainActor；generation 由调用方注入并原样回传（UI 门控复用串图）。
    @discardableResult
    public func request(key: IconKey,
                        generation: UInt64,
                        onApply: @escaping @MainActor @Sendable (IconKey, UInt64, IconResult) -> Void)
        -> IconRequestHandle {
        let consumer = Consumer(key: key, generation: generation, onApply: onApply)

        let outcome = withLock { () -> RequestOutcome in
            guard !isShutdown else {
                return .rejected
            }
            counters.requests += 1

            if let entry = cache.value(for: key) {
                counters.cacheHits += 1
                if consumer.tryMarkDelivered() {
                    queuedDeliveries[ObjectIdentifier(consumer)] = consumer
                }
                return .cached(entry.image)
            }

            counters.cacheMisses += 1
            if let existing = inFlight[key] {
                counters.inFlightMerged += 1
                existing.consumers.append(consumer)
                return .merged
            }

            let loadID = UUID()
            let task = Task { [weak self] in
                guard let self else { return }
                await self.performLoad(key: key, loadID: loadID)
            }
            inFlight[key] = InFlightEntry(loadID: loadID, task: task, consumers: [consumer])
            return .started
        }

        switch outcome {
        case .rejected:
            // 拒新请求：惰性 handle，此后零回调
            return IconRequestHandle(pipeline: nil, key: key, consumer: nil)
        case .cached(let image):
            deliverOnMain(consumer, .success(image))
            return IconRequestHandle(pipeline: self, key: key, consumer: consumer)
        case .merged, .started:
            return IconRequestHandle(pipeline: self, key: key, consumer: consumer)
        }
    }

    private enum RequestOutcome {
        case rejected
        case cached(NSImage)
        case merged
        case started
    }

    // MARK: 取消 / 清理 / 生命周期

    fileprivate func cancelConsumer(_ consumer: Consumer, key: IconKey) {
        guard consumer.tryMarkCancelled() else { return }
        withLock {
            counters.cancellations += 1
            if let entry = inFlight[key] {
                entry.consumers.removeAll { $0 === consumer }
                if entry.consumers.isEmpty {
                    // 全部 consumer 取消 → 取消底层 in-flight
                    entry.task.cancel()
                    inFlight.removeValue(forKey: key)
                }
            }
        }
    }

    /// 取消该 key 全部 consumer → 底层 in-flight 一并取消。
    public func cancelAll(for key: IconKey) {
        withLock {
            guard let entry = inFlight[key] else { return }
            for consumer in entry.consumers where consumer.tryMarkCancelled() {
                counters.cancellations += 1
            }
            entry.task.cancel()
            inFlight.removeValue(forKey: key)
        }
    }

    /// Revoke all cached variants, owned loads and queued deliveries for sources
    /// whose committed mapping changed. Unaffected identities keep their cache.
    /// A callback already admitted on MainActor has won its delivery boundary.
    public func invalidateSources(for identities: Set<IconIdentity>) {
        guard !identities.isEmpty else { return }
        let retiredTasks: [Task<Void, Never>] = withLock {
            guard !isShutdown else { return [] }
            var retired: [Task<Void, Never>] = []
            for key in Array(cache.entries.keys) where identities.contains(key.identity) {
                if cache.remove(key) { counters.evictions += 1 }
            }
            for key in Array(inFlight.keys) where identities.contains(key.identity) {
                guard let entry = inFlight.removeValue(forKey: key) else { continue }
                for consumer in entry.consumers where consumer.tryMarkCancelled() {
                    counters.cancellations += 1
                }
                retired.append(entry.task)
            }
            for (id, consumer) in queuedDeliveries where identities.contains(consumer.key.identity) {
                queuedDeliveries.removeValue(forKey: id)
            }
            return retired
        }
        // Cancellation handlers are synchronous and may reenter this pipeline.
        // Retire ownership first, then invoke them without holding its lock.
        for task in retiredTasks { task.cancel() }
    }

    /// 显式清理全部缓存条目。
    public func purgeAll() {
        withLock {
            let removed = cache.removeAll()
            counters.evictions += removed
        }
    }

    /// 清理插入时间早于 before 的缓存条目。
    public func purgeExpired(before date: Date) {
        withLock {
            let removed = cache.removeExpired(before: date)
            counters.evictions += removed
        }
    }

    /// teardown：拒新请求、清缓存、取消全部 in-flight、此后零回调。幂等。
    public func shutdown() {
        withLock {
            guard !isShutdown else { return }
            isShutdown = true
            queuedDeliveries.removeAll()
            cache.removeAll()                       // teardown 清空不计 eviction（非策略事件）
            for entry in inFlight.values {
                entry.task.cancel()
            }
            inFlight.removeAll()
            if let observer = memoryPressureObserver {
                NotificationCenter.default.removeObserver(observer)
                memoryPressureObserver = nil
            }
            memoryPressureSource?.cancel()
            memoryPressureSource = nil
        }
    }

    /// telemetry 计数快照（无字节/哈希/路径）。
    public var stats: IconPipelineStats {
        withLock { counters }
    }

    // Actor-independent, read-only seam for explicit queued-delivery test gates.
    var queuedDeliveryCount: Int { withLock { queuedDeliveries.count } }
    var waitingLoadCount: Int { get async { await limiter.waitingCount } }
    // Acquiring the finish lock means its entire ownership decision has ended.
    // Includes stale results; not a task/cancellation or UI-delivery count.
    var processedLoadResultCount: UInt64 { withLock { processedLoadResults } }

    // MARK: 内部

    private func performLoad(key: IconKey, loadID: UUID) async {
        let result: IconResult
        do {
            let image = try await limiter.withPermit { [loader] in
                try await loader.load(key: key)
            }
            // Native decoding may ignore task cancellation. Record its terminal
            // result through the existing loadID gate, without capping/caching it.
            guard !Task.isCancelled else {
                finish(key: key, loadID: loadID, result: .failed(.cancelled))
                return
            }
            // 统一缩略（写回缓存前）：加载后最大 256×256，纯内存操作；
            // 缓存 cost 由 estimatedCost 按缩略后最大 rep 自动计（无需改）。
            let capped = IconPipeline.cappedImage(image)
            result = .success(capped)
        } catch {
            if Task.isCancelled {
                return  // 自身被取消（全部 consumer 取消 / cancelAll / shutdown）：消费者已移除 → 零回调
            }
            result = .failed(error is CancellationError ? .cancelled : .loadFailed)
        }
        finish(key: key, loadID: loadID, result: result)
    }

    private func finish(key: IconKey, loadID: UUID, result: IconResult) {
        let cacheValue: (image: NSImage, cost: Int)?
        if case .success(let image) = result {
            cacheValue = (image, IconPipeline.estimatedCost(of: image))
        } else {
            cacheValue = nil
        }
        var targets: [Consumer] = []
        withLock {
            processedLoadResults &+= 1
            // Cancellation can remove this key and a new request can replace it
            // before a non-cooperative old loader returns. Only its current load
            // owns both cache insertion and removal/delivery of these consumers.
            guard !isShutdown, let entry = inFlight[key], entry.loadID == loadID else { return }
            inFlight.removeValue(forKey: key)
            if let cacheValue {
                counters.evictions += cache.insert(cacheValue.image, cost: cacheValue.cost, for: key)
            }
            for consumer in entry.consumers where consumer.tryMarkDelivered() {
                queuedDeliveries[ObjectIdentifier(consumer)] = consumer
                targets.append(consumer)
            }
        }
        for consumer in targets {
            deliverOnMain(consumer, result)
        }
    }

    /// Delivery admission and source invalidation share one lock, but UI callbacks
    /// run outside it. MainActor catalog commits cannot interleave with a callback.
    private func deliverOnMain(_ consumer: Consumer, _ result: IconResult) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let admitted = self.withLock {
                !self.isShutdown &&
                    self.queuedDeliveries.removeValue(forKey: ObjectIdentifier(consumer)) != nil
            }
            guard admitted else { return }
            consumer.onApply(consumer.key, consumer.generation, result)
        }
    }

    private func handleMemoryPressure() {
        withLock {
            guard !isShutdown else { return }
            let removed = cache.removeAll()
            counters.memoryPressurePurges += removed
        }
    }

    /// 估计解码成本 w×h×4（不读取真实字节；多 representation 取最大）。
    static func estimatedCost(of image: NSImage) -> Int {
        var maxPixels = 0
        let representations = image.representations
        if representations.isEmpty {
            let size = image.size
            maxPixels = max(1, Int(ceil(size.width))) * max(1, Int(ceil(size.height)))
        } else {
            for rep in representations {
                maxPixels = max(maxPixels, max(1, rep.pixelsWide) * max(1, rep.pixelsHigh))
            }
        }
        return max(1, maxPixels * 4)
    }

    // MARK: 图标尺寸上限（用户指定：最大 256×256）

    /// 图标像素上限：加载后统一缩略，任一边不超过该值（等比，保持宽高比）。
    static let maxIconPixelDimension = 256

    /// 加载后统一缩略：若最大 rep 任一边 > 256px，取最大 rep 等比绘制到 ≤256×256
    /// 的新 NSBitmapImageRep（纯内存），返回含单 rep 的新 NSImage；已 ≤256 则原样返回。
    /// 隐私红线：不读真实字节、不哈希、不写磁盘、不复制进资源。
    static func cappedImage(_ image: NSImage, maxDimension: Int = maxIconPixelDimension) -> NSImage {
        let (width, height) = largestPixelSize(of: image)
        guard width > maxDimension || height > maxDimension else { return image }

        let scale = min(Double(maxDimension) / Double(width),
                        Double(maxDimension) / Double(height))
        let targetWidth = max(1, Int((Double(width) * scale).rounded()))
        let targetHeight = max(1, Int((Double(height) * scale).rounded()))

        guard let targetRep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                               pixelsWide: targetWidth,
                                               pixelsHigh: targetHeight,
                                               bitsPerSample: 8,
                                               samplesPerPixel: 4,
                                               hasAlpha: true,
                                               isPlanar: false,
                                               colorSpaceName: .deviceRGB,
                                               bytesPerRow: 0,
                                               bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: targetRep) else {
            return image
        }
        targetRep.size = NSSize(width: targetWidth, height: targetHeight)
        let targetRect = NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        if let rep = largestRepresentation(of: image) {
            rep.draw(in: targetRect)
        } else {
            image.draw(in: targetRect)
        }
        NSGraphicsContext.restoreGraphicsState()

        let result = NSImage(size: NSSize(width: targetWidth, height: targetHeight))
        result.addRepresentation(targetRep)
        return result
    }

    /// 最大 rep 的像素尺寸（多 representation 取面积最大；无 rep 时回退 image.size）。
    private static func largestPixelSize(of image: NSImage) -> (width: Int, height: Int) {
        var best = (width: 0, height: 0)
        for rep in image.representations {
            let w = max(1, rep.pixelsWide)
            let h = max(1, rep.pixelsHigh)
            if w * h > best.width * best.height {
                best = (width: w, height: h)
            }
        }
        if best.width == 0 || best.height == 0 {
            best = (width: max(1, Int(ceil(image.size.width))),
                    height: max(1, Int(ceil(image.size.height))))
        }
        return best
    }

    /// 面积最大的 representation（缩略绘制源；无 rep 返回 nil）。
    private static func largestRepresentation(of image: NSImage) -> NSImageRep? {
        image.representations.max { lhs, rhs in
            max(1, lhs.pixelsWide) * max(1, lhs.pixelsHigh)
                < max(1, rhs.pixelsWide) * max(1, rhs.pixelsHigh)
        }
    }
}
