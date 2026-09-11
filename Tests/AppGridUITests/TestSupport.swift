// AppGridUITests — TestSupport（§10.5：fake 数据 + fake loader（程序生成图像），
// 绝不触碰真实 /Applications；无第三方图标/真实 app 进测试产物）。

import AppCatalogCore
import AppIconPipeline
import AppKit
import Foundation
import PagingUI
@testable import AppGridUI
import XCTest

// MARK: - 程序生成图像（位图内存填充，零文件系统/零真实资源；与 AppIconPipelineTests 同法）

func makeIconImage(pixelWidth: Int = 32, pixelHeight: Int = 32,
                   r: UInt8 = 70, g: UInt8 = 110, b: UInt8 = 190) -> NSImage {
    precondition(pixelWidth > 0 && pixelHeight > 0)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: pixelWidth,
                               pixelsHigh: pixelHeight,
                               bitsPerSample: 8,
                               samplesPerPixel: 4,
                               hasAlpha: true,
                               isPlanar: false,
                               colorSpaceName: .deviceRGB,
                               bytesPerRow: 0,
                               bitsPerPixel: 0)!
    if let data = rep.bitmapData {
        for y in 0..<pixelHeight {
            for x in 0..<pixelWidth {
                let offset = (y * pixelWidth + x) * 4
                data[offset] = r
                data[offset + 1] = g
                data[offset + 2] = b
                data[offset + 3] = 255
            }
        }
    }
    let image = NSImage(size: NSSize(width: pixelWidth, height: pixelHeight))
    image.addRepresentation(rep)
    return image
}

// MARK: - 快照/记录工厂（经 CatalogFixture；displayName 排序由 CatalogBuilder 决定）
// bundleID 由标题派生（"fixture." + 小写标题）→ AppID 全序与展示序一致，
// 使 successor/predecessor 锚点测试可预测（§6.3 规则 2/3）。

func makeAppID(_ bundleID: String) -> AppID {
    CatalogFixture.appID(bundleID)
}

func makeSnapshot(titles: [String], revision: UInt64) throws -> CatalogSnapshot {
    let records = titles.enumerated().map { index, title in
        let bundleID = "fixture.\(title.lowercased())"
        let id = makeAppID(bundleID)
        return CatalogFixture.record(id: id, displayName: title, bundleID: bundleID,
                                     url: CatalogFixture.tempURL(named: "\(bundleID)-\(index).app"),
                                     icon: IconIdentity.from(appID: id), rootPriority: 0)
    }
    return try CatalogFixture.snapshot(records: records, revision: CatalogRevision(revision))
}

// MARK: - seam 内容工厂（测试直接构造 PagingPageContent）

func makeContent(revision: UInt64, page: Int, titles: [String],
                 appIDs: [AppID]? = nil, itemsPerPage: Int = 35) -> PagingPageContent {
    let presentation = PagePresentationID(revision: revision, pageIndex: page)
    var items: [PagingPageContentItem] = []
    for (index, title) in titles.enumerated() {
        let identity: AnyHashable? = appIDs.map { AnyHashable($0[index]) }
        items.append(PagingPageContentItem(slot: page * itemsPerPage + index,
                                           identity: identity, title: title))
    }
    return PagingPageContent(presentationID: presentation, items: items, isPlaceholder: false)
}

func makePlaceholderContent(revision: UInt64, page: Int) -> PagingPageContent {
    PagingPageContent(presentationID: PagePresentationID(revision: revision, pageIndex: page),
                      items: [], isPlaceholder: true)
}

// MARK: - 线程安全计数/单值盒（与 AppIconPipelineTests 同法）

final class CallbackBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _count = 0
    func increment() {
        lock.lock()
        _count += 1
        lock.unlock()
    }
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }
}

/// 线程安全 apply 结果记录器（onIconApplyResult 观察；测试断言 applied/stale/failed 计数）。
final class ApplyRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _results: [(ItemBindingToken, AppGridIconApplyResult)] = []

    func record(_ token: ItemBindingToken, _ result: AppGridIconApplyResult) {
        lock.lock()
        _results.append((token, result))
        lock.unlock()
    }

    var results: [(ItemBindingToken, AppGridIconApplyResult)] {
        lock.lock()
        defer { lock.unlock() }
        return _results
    }

    func count(_ result: AppGridIconApplyResult) -> Int {
        results.filter { $0.1 == result }.count
    }
}

// MARK: - GatedIconLoader：按 key 挂起加载，测试控制完成顺序（乱序到达验证）

enum GatedLoaderError: Error {
    case injected
}

final class GatedIconLoader: IconLoading, @unchecked Sendable {
    private let lock = NSLock()
    private var gates: [IconKey: [CheckedContinuation<NSImage, Error>]] = [:]
    private let defaultImage: NSImage

    init(defaultImage: NSImage = makeIconImage()) {
        self.defaultImage = defaultImage
    }

    func load(key: IconKey) async throws -> NSImage {
        try await withCheckedThrowingContinuation { continuation in
            registerGate(key: key, continuation: continuation)
        }
    }

    /// 挂起中的 key 数（= 尚未完成的底层 load）。
    var pendingKeyCount: Int {
        pendingGatesSnapshot().count
    }

    /// 挂起中的 key 清单（诊断）。
    var pendingKeys: [IconKey] {
        Array(pendingGatesSnapshot().keys)
    }

    /// 同步锁段：挂起 gate 快照（规避 async 上下文中 NSLock 的不可用标注）。
    private func pendingGatesSnapshot() -> [IconKey: [CheckedContinuation<NSImage, Error>]] {
        lock.lock()
        defer { lock.unlock() }
        return gates
    }

    /// 同步锁段（规避 async 上下文中 NSLock 的不可用标注；与 AppIconPipelineTests 同法）。
    private func registerGate(key: IconKey, continuation: CheckedContinuation<NSImage, Error>) {
        lock.lock()
        gates[key, default: []].append(continuation)
        lock.unlock()
    }

    /// 同步锁段：取走指定 key 的全部挂起 continuation。
    private func takeGates(key: IconKey) -> [CheckedContinuation<NSImage, Error>] {
        lock.lock()
        defer { lock.unlock() }
        return gates.removeValue(forKey: key) ?? []
    }

    /// 完成指定 key 的全部挂起加载（按 FIFO resume）。
    func complete(key: IconKey, image: NSImage? = nil) {
        for continuation in takeGates(key: key) {
            continuation.resume(returning: image ?? defaultImage)
        }
    }

    /// 使指定 key 的挂起加载失败（→ failed(.loadFailed)，UI 保持中性 placeholder）。
    func fail(key: IconKey) {
        for continuation in takeGates(key: key) {
            continuation.resume(throwing: GatedLoaderError.injected)
        }
    }
}

/// 等待底层 load 挂起就位（load 任务运行在并发池线程；与主线程存在竞态）。
/// 先等 pending 再 complete/fail，消除"complete 早于 gate 注册"的测试竞态。
@MainActor
func waitForPendingLoads(_ loader: GatedIconLoader, count: Int,
                         timeout: TimeInterval = 3) async {
    let deadline = Date().addingTimeInterval(timeout)
    while loader.pendingKeyCount < count && Date() < deadline {
        try? await Task.sleep(nanoseconds: 5_000_000)
    }
}

// MARK: - ImmediateDataSource：scripted 刷新结果（无门控；计数刷新次数）

final class ImmediateDataSource: AppGridDataSource, @unchecked Sendable {
    private let lock = NSLock()
    private var _snapshot: CatalogSnapshot?
    private let outcomes: [AppGridRefreshOutcome]
    private var _refreshCount = 0
    private var _onRefresh: (() -> Void)?

    /// outcomes 按序取用；取尽后重复最后一个。
    init(snapshot: CatalogSnapshot? = nil, outcomes: [AppGridRefreshOutcome] = []) {
        self._snapshot = snapshot
        self.outcomes = outcomes
    }

    var currentSnapshot: CatalogSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return _snapshot
    }

    func setSnapshot(_ snapshot: CatalogSnapshot?) {
        lock.lock()
        _snapshot = snapshot
        lock.unlock()
    }

    /// 每次刷新触发回调（任意线程；测试断言 debounce 用）。
    var onRefresh: (() -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _onRefresh
        }
        set {
            lock.lock()
            _onRefresh = newValue
            lock.unlock()
        }
    }

    var refreshCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _refreshCount
    }

    func refresh() async -> AppGridRefreshOutcome {
        let (outcome, callback) = performRefreshLocked()
        callback?()
        return outcome
    }

    /// 同步锁段（规避 async 上下文中 NSLock 的不可用标注）。
    private func performRefreshLocked() -> (AppGridRefreshOutcome, (() -> Void)?) {
        lock.lock()
        defer { lock.unlock() }
        _refreshCount += 1
        let outcome: AppGridRefreshOutcome
        if outcomes.isEmpty {
            outcome = AppGridRefreshOutcome(succeeded: true, appCount: _snapshot?.records.count ?? 0)
        } else {
            let index = min(_refreshCount - 1, outcomes.count - 1)
            outcome = outcomes[max(0, index)]
        }
        return (outcome, _onRefresh)
    }
}
