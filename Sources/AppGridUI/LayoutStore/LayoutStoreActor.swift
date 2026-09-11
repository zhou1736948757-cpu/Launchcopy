// AppGridUI — LayoutStore.LayoutStoreActor（Phase 1F §6.1 / ADR-009 Q4–Q7/Q10/Q11）
// 实现：T-1F-B（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 版本化 layout store 的 actor 实现（进程内严格串行）：
// - A/B 双槽 generation journal：`workspace-layout-v1-{a,b}.json`，每槽携带单调
//   `writeGeneration` + 校验和；最新有效代 = last-known-good；temp 写 + fsync + 原子替换。
// - 写失败 → PERSISTENCE_DEGRADED（有界指数退避重试；绝不清除 LKG；内存已提交布局权威）。
// - coalescing sink：单 in-flight + 单 pending（latest-wins，绝不乱序）。
// - 有界 flush barrier：等 in-flight 完成（带超时）→ 同步落盘 pending；幂等。
// - 启动读入：首启无文件 → `.firstLaunch`（不报错）；corrupt/unknown version → 只读保护，
//   证据保留（quarantine 中性命名 / 原文件不动），绝不自动覆盖。
// - reset：归档 `*.reset-<stamp>`（证据保留）→ 清状态 → 立即持久化默认布局。
// - 多实例策略（ADR-009 Q6）：flock single-writer；锁被同机另一实例持有 → 降级 explicit
//   last-writer-wins（按 layout generation 比较，仅更高代可落盘；stale 拒绝计数）。
// - 隐私：本文件不产生任何输出；状态/结果载荷全部中性（无路径/无正文/无原值）。

import Foundation

/// 版本化 layout store actor（ADR-009 Q6：actor/串行队列，进程内严格串行）。
public actor LayoutStoreActor: LayoutStore {

    public let storeDirectory: URL

    private let io: any LayoutStoreIO
    private let retrySchedule: [TimeInterval]   // 每次失败后的退避；count = 重试上限
    private let flushTimeout: TimeInterval

    // 槽文件名（中性；ADR-009 Q5）。
    private enum Slot: CaseIterable {
        case a, b
        var fileName: String {
            switch self {
            case .a: return "workspace-layout-v1-a.json"
            case .b: return "workspace-layout-v1-b.json"
            }
        }
        var label: String {
            switch self {
            case .a: return "a"
            case .b: return "b"
            }
        }
    }

    private static let lockFileName = "workspace-layout.lock"

    // 运行时状态
    private var hasLoaded = false
    private var loadResult: LayoutStoreLoadResult?
    private var lock: LayoutStoreLock?
    private var lockMode: LayoutStoreLockMode = .singleWriter
    private var state: LayoutStoreState = .healthy
    private var pendingLayout: PersistentWorkspaceLayout?
    private var isPersisting = false
    private var lastPersistedGeneration: UInt64 = 0
    private var staleRejections: UInt64 = 0

    public init(storeDirectory: URL,
                io: any LayoutStoreIO = FileManagerLayoutStoreIO(),
                retrySchedule: [TimeInterval] = [0.05, 0.1, 0.2],
                flushTimeout: TimeInterval = 2.0) {
        self.storeDirectory = storeDirectory
        self.io = io
        self.retrySchedule = retrySchedule
        self.flushTimeout = flushTimeout
    }

    // MARK: - LayoutStore

    public func load() async -> LayoutStoreLoadResult {
        await ensureLoaded()
        return loadResult ?? .firstLaunch
    }

    public func enqueue(_ layout: PersistentWorkspaceLayout) async {
        await ensureLoaded()
        if case .readOnlyProtection = state { return }   // 持久化暂停
        pendingLayout = layout                            // coalescing：latest-wins
        if !isPersisting {
            isPersisting = true
            spawnPersistLoop()
        }
    }

    public func flush() async -> LayoutStoreFlushResult {
        await ensureLoaded()
        if case .readOnlyProtection = state { return .readOnly }
        // 有界 barrier：等在途持久化完成（带超时）。
        let deadline = Date().addingTimeInterval(flushTimeout)
        while isPersisting && Date() < deadline {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        if isPersisting { return .timedOut }
        guard let layout = pendingLayout else { return .nothingPending }
        // 同步落盘（单次尝试；失败如实报告，pending 保留待下次）。
        let outcome = await persistOnce(layout)
        switch outcome {
        case .success(let generation):
            pendingLayout = nil
            lastPersistedGeneration = generation
            state = .healthy
            return .persisted(writeGeneration: generation)
        case .failed:
            state = .persistenceDegraded(.writeFailed(retryCount: 0))
            return .failed
        case .staleRejected:
            staleRejections += 1
            pendingLayout = nil
            return .staleRejected
        case .rejectedOverLimit:
            state = .persistenceDegraded(.rejectedOverLimit)
            pendingLayout = nil
            return .rejectedOverLimit
        }
    }

    public func reset(defaultLayout: PersistentWorkspaceLayout) async -> LayoutStoreResetResult {
        await ensureLoaded()
        // 归档全部槽文件（中性命名，证据保留；ADR-009 Q11）→ 清状态 → 立即持久化默认。
        let stamp = Self.archiveStamp()
        do {
            for slot in Slot.allCases {
                let url = storeDirectory.appendingPathComponent(slot.fileName)
                if await io.fileExists(at: url) {
                    let archive = storeDirectory
                        .appendingPathComponent("workspace-layout-\(stamp).reset-\(slot.label)")
                    try await io.moveFile(from: url, to: archive)
                }
            }
            await cleanupTempFiles()
        } catch {
            return .failed
        }
        state = .healthy
        pendingLayout = nil
        let outcome = await persistOnce(defaultLayout)
        switch outcome {
        case .success(let generation):
            return .reset(writeGeneration: generation)
        default:
            return .failed
        }
    }

    public func currentState() async -> LayoutStoreState {
        state
    }

    public func lockMode() async -> LayoutStoreLockMode {
        lockMode
    }

    public func staleRejectionCount() async -> UInt64 {
        staleRejections
    }

    // MARK: - 启动读入

    private func ensureLoaded() async {
        guard !hasLoaded else { return }
        // 每一条路径（主分类、unknownFutureVersion/overLimit 提前返回、catch 分支）都必须置位，
        // 否则每次 actor 方法调用都会重跑完整 load 并重分类 state（绕过只读保护、破坏 flush 语义）。
        defer { hasLoaded = true }
        do {
            try await io.createDirectoryIfNeeded(at: storeDirectory)
        } catch {
            // 目录不可建 → 无文件可读（首启语义），但持久化不可用。
            state = .persistenceDegraded(.writeFailed(retryCount: 0))
            loadResult = .firstLaunch
            hasLoaded = true
            return
        }
        // 多实例协调：flock（ADR-009 Q6）。
        do {
            lock = try await io.acquireLock(at: storeDirectory.appendingPathComponent(Self.lockFileName))
        } catch {
            lock = nil
        }
        lockMode = (lock != nil) ? .singleWriter : .lastWriterWins

        await cleanupTempFiles()   // 中断写残留（非证据；槽文件才是真相）

        let a = await readSlot(.a)
        let b = await readSlot(.b)

        // 未知未来版本：任何槽出现 → 只读保护，原文件绝不动（绝不降级覆盖）。
        if case .unknownFutureVersion(let version) = a {
            setReadOnly(.unknownFutureVersion(version)); return
        }
        if case .unknownFutureVersion(let version) = b {
            setReadOnly(.unknownFutureVersion(version)); return
        }
        // 超限：任何槽超限 → 只读保护，原文件保留（ADR-009 Q7）。
        if case .overLimit = a { setReadOnly(.exceedsLimits); return }
        if case .overLimit = b { setReadOnly(.exceedsLimits); return }

        switch (a, b) {
        case (.absent, .absent):
            loadResult = .firstLaunch
            state = .healthy
        case (.valid(let decoded), _):
            loadResult = .loaded(decoded.layout, writeGeneration: decoded.writeGeneration)
            state = .healthy
            lastPersistedGeneration = decoded.writeGeneration
        case (.corrupt, .valid(let decoded)):
            // 主槽坏、备槽有效：加载 last-known-good；损坏证据保留，下次成功写才轮换。
            loadResult = .loadedFromBackup(decoded.layout, writeGeneration: decoded.writeGeneration)
            state = .healthy
            lastPersistedGeneration = decoded.writeGeneration
        case (.absent, .valid(let decoded)):
            loadResult = .loaded(decoded.layout, writeGeneration: decoded.writeGeneration)
            state = .healthy
            lastPersistedGeneration = decoded.writeGeneration
        case (.corrupt, .corrupt), (.corrupt, .absent), (.absent, .corrupt):
            // 双坏/单坏无备：quarantine 中性命名（证据保留）→ 安全只读保护。
            await quarantineCorruptSlots()
            setReadOnly(.bothSlotsCorrupt)
        default:
            break   // 不可达：unknownFutureVersion/overLimit 已在上方提前返回
        }
    }

    private func setReadOnly(_ reason: LayoutStoreReadOnlyReason) {
        state = .readOnlyProtection(reason)
        loadResult = .readOnlyProtection(reason)
        pendingLayout = nil
    }

    private func readSlot(_ slot: Slot) async -> SlotRead {
        let url = storeDirectory.appendingPathComponent(slot.fileName)
        guard await io.fileExists(at: url) else { return .absent }
        guard let data = await io.readFile(at: url) else { return .corrupt }
        switch LayoutStoreCodec.decode(data) {
        case .valid(let decoded): return .valid(decoded)
        case .corrupt: return .corrupt
        case .unknownFutureVersion(let version): return .unknownFutureVersion(version)
        case .overLimit: return .overLimit
        }
    }

    private func quarantineCorruptSlots() async {
        let stamp = Self.archiveStamp()
        for slot in Slot.allCases {
            let url = storeDirectory.appendingPathComponent(slot.fileName)
            if await io.fileExists(at: url) {
                let quarantine = storeDirectory
                    .appendingPathComponent("workspace-layout-\(stamp).corrupt-\(slot.label)")
                try? await io.moveFile(from: url, to: quarantine)
            }
        }
    }

    private func cleanupTempFiles() async {
        let urls = await io.contentsOfDirectory(at: storeDirectory)
        for url in urls where url.lastPathComponent.hasSuffix(".tmp") {
            await io.removeFileIfExists(at: url)
        }
    }

    // MARK: - 持久化

    private enum PersistOutcome {
        case success(writeGeneration: UInt64)
        case failed
        case staleRejected
        case rejectedOverLimit
    }

    private enum SlotRead {
        case valid(DecodedLayout)
        case corrupt
        case unknownFutureVersion(Int)
        case overLimit
        case absent

        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }
    }

    private func spawnPersistLoop() {
        Task { await self.runPersistLoop() }
    }

    /// coalescing drain：单 in-flight + 单 pending（latest-wins）。
    private func runPersistLoop() async {
        drain: while let layout = pendingLayout {
            let outcome = await persistWithRetries(layout)
            switch outcome {
            case .success(let generation):
                if pendingLayout == layout { pendingLayout = nil }
                lastPersistedGeneration = generation
                state = .healthy
            case .superseded:
                continue   // 更新 pending 已到达；循环重读
            case .failed(let retries):
                state = .persistenceDegraded(.writeFailed(retryCount: retries))
                // 注意：switch 内的 break 只退出 switch；必须用带标签的 break 退出 drain 循环，
                // 否则 isPersisting 永不复位，flush barrier 必然超时（T-1F-B 回归测试实证）。
                if pendingLayout == layout { break drain }   // pending 保留待 flush/下次 enqueue
            case .staleRejected:
                staleRejections += 1
                if pendingLayout == layout { pendingLayout = nil }   // 磁盘已更新 → 丢弃
            case .rejectedOverLimit:
                state = .persistenceDegraded(.rejectedOverLimit)
                if pendingLayout == layout { pendingLayout = nil }
            }
        }
        isPersisting = false
    }

    private enum RetryOutcome {
        case success(writeGeneration: UInt64)
        case failed(retryCount: Int)
        case superseded
        case staleRejected
        case rejectedOverLimit
    }

    /// 有界重试（指数退避；上限 = retrySchedule.count）。每次尝试前重查 pending（latest-wins）。
    private func persistWithRetries(_ layout: PersistentWorkspaceLayout) async -> RetryOutcome {
        var attempt = 0
        while true {
            if let newer = pendingLayout, newer != layout { return .superseded }
            let outcome = await persistOnce(layout)
            switch outcome {
            case .success(let generation):
                return .success(writeGeneration: generation)
            case .staleRejected:
                return .staleRejected
            case .rejectedOverLimit:
                return .rejectedOverLimit
            case .failed:
                attempt += 1
                if attempt > retrySchedule.count { return .failed(retryCount: attempt - 1) }
                let delay = retrySchedule[attempt - 1]
                if delay > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
    }

    /// 单次持久化：读槽 → 多实例裁决 → 编码 → temp 写 → 原子替换 → 目录 fsync。
    private func persistOnce(_ layout: PersistentWorkspaceLayout) async -> PersistOutcome {
        let a = await readSlot(.a)
        let b = await readSlot(.b)
        let maxDiskWrite = max(writeGeneration(of: a) ?? 0, writeGeneration(of: b) ?? 0)
        let maxDiskLayout = max(layoutGeneration(of: a), layoutGeneration(of: b))
        let hasValidSlot = a.isValid || b.isValid

        // 多实例 last-writer-wins：仅更高 layout generation 可落盘（ADR-009 Q6）。
        if lockMode == .lastWriterWins && hasValidSlot && layout.generation.value <= maxDiskLayout {
            return .staleRejected
        }

        let nextGeneration = max(lastPersistedGeneration, maxDiskWrite) + 1
        let data: Data
        do {
            data = try LayoutStoreCodec.encode(layout, writeGeneration: nextGeneration)
        } catch {
            return .rejectedOverLimit   // 超限/非法布局 → 拒写（中性）
        }

        let target = rotationTarget(a: a, b: b)
        let slotURL = storeDirectory.appendingPathComponent(target.fileName)
        let tempURL = slotURL.appendingPathExtension("tmp")
        do {
            try await io.writeFile(data, to: tempURL)
            try await io.replaceFile(at: tempURL, with: slotURL)
            await io.fsyncDirectory(at: storeDirectory)
        } catch {
            return .failed   // temp 残留 = 中断写证据；load 时清理
        }
        return .success(writeGeneration: nextGeneration)
    }

    /// 轮换目标：写较低 writeGeneration 的槽（nil = 最低；平局 → A）。损坏槽视为最低。
    private func rotationTarget(a: SlotRead, b: SlotRead) -> Slot {
        switch (writeGeneration(of: a), writeGeneration(of: b)) {
        case (nil, nil): return .a
        case (.some, nil): return .b
        case (nil, .some): return .a
        case (.some(let ga), .some(let gb)): return ga <= gb ? .a : .b
        }
    }

    private func writeGeneration(of read: SlotRead) -> UInt64? {
        if case .valid(let decoded) = read { return decoded.writeGeneration }
        return nil
    }

    private func layoutGeneration(of read: SlotRead) -> UInt64 {
        if case .valid(let decoded) = read { return decoded.layout.generation.value }
        return 0
    }

    // MARK: - 工具

    /// 中性归档时间戳（不含正文）。
    private static func archiveStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }
}
