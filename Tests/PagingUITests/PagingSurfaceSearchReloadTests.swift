//
//  PagingSurfaceSearchReloadTests.swift
//  PagingUITests
//
//  §8.3 / ADR-007 §2.2 同 revision 重载 seam（reloadCurrentPresentation）：
//  - idle/cancelled → 立即原子应用（pageCount + live hosts）；
//  - tracking/settling/interrupted → 只记录 latest pending，idle/cancelled 边界一次应用；
//  - 多次 pending 只应用最新；
//  - 新 catalog revision 优先于旧同 revision 重载（latest-wins 双轴，ADR-007 §2.4）；
//  - pageCount 缩小/0/1/多页；
//  - host/view 数上界不变；
//  - query 变化后旧图标乱序回调零错写（generation/token gating，ADR-007 §2.6）；
//  - teardown 后零写回。
//
// 不触碰 PagingCore；servedRevision 保持 base snapshot revision（绝不 mint/forge CatalogRevision）。
//

import AppKit
import XCTest
@testable import PagingCore
@testable import PagingUI

/// 可编程假提供者：与真实 AppGridUIPageContentProvider 同契约——只服务
/// revision == servedRevision 的请求并回显 presentation；否则中性占位（items 空）。
/// pageCount 可变（模拟 query 变化导致的结果页数变化，同 revision）。
private final class ReloadProvider: PagingPageContentProviding {
    /// nil = 未就绪（无已提交快照）→ 全部占位。
    var revision: UInt64?
    var pageCount: Int
    var requestedRevisions: [UInt64] = []
    var requestedPages: [Int] = []

    var servedRevision: UInt64? { revision }
    var servedPageCount: Int? { pageCount }

    init(revision: UInt64? = 1, pageCount: Int = 5) {
        self.revision = revision
        self.pageCount = pageCount
    }

    func content(for presentation: PagePresentationID, itemsPerPage: Int) -> PagingPageContent {
        requestedRevisions.append(presentation.revision)
        requestedPages.append(presentation.pageIndex)
        guard let served = revision, presentation.revision == served else {
            return PagingPageContent(presentationID: presentation, items: [], isPlaceholder: true)
        }
        guard presentation.pageIndex >= 0, presentation.pageIndex < pageCount else {
            return PagingPageContent(presentationID: presentation, items: [], isPlaceholder: true)
        }
        return PagingPageContent(
            presentationID: presentation,
            items: (0..<itemsPerPage).map {
                PagingPageContentItem(slot: $0, identity: nil, title: "r\(served)-p\(presentation.pageIndex)-\($0)")
            },
            isPlaceholder: false
        )
    }
}

/// 记录型假渲染器：记录 render/clear 调用（不绘制任何内容）。
private final class RecordingRenderer: PagingPageRendering {
    struct RenderCall {
        let pageIndex: Int
        let revision: UInt64
        let pageCount: Int
        let generation: UInt64
        let isPlaceholder: Bool
    }
    var calls: [RenderCall] = []
    var clearCount = 0

    func render(pageIndex: Int, content: PagingPageContent, pageCount: Int, reuseGeneration: UInt64) {
        calls.append(RenderCall(
            pageIndex: pageIndex,
            revision: content.presentationID.revision,
            pageCount: pageCount,
            generation: reuseGeneration,
            isPlaceholder: content.isPlaceholder
        ))
    }

    func clearForReuse() {
        clearCount += 1
    }
}

/// 门控渲染器：模拟 AppGridPageView 的 generation/token 防线——每次 render bump 自身
/// generation（对应 AppGridPageView.surfaceGeneration，token 字段 7 的源）；异步图标回调
/// 到达时校验捕获的 generation 是否仍当前，否则 stale 拒绝（stale apply = 0）。
private final class GatedRenderer: PagingPageRendering {
    struct RenderCall {
        let pageIndex: Int
        let revision: UInt64
        let pageCount: Int
        let generation: UInt64
    }
    var calls: [RenderCall] = []
    var clearCount = 0
    /// 每次 render/clear bump（模拟 AppGridPageView.surfaceGeneration）。
    private(set) var generation: UInt64 = 0
    /// 已投递但被门控拒绝的 apply 计数（stale result rejected）。
    private(set) var staleRejected = 0

    func render(pageIndex: Int, content: PagingPageContent, pageCount: Int, reuseGeneration: UInt64) {
        generation &+= 1
        calls.append(RenderCall(
            pageIndex: pageIndex,
            revision: content.presentationID.revision,
            pageCount: pageCount,
            generation: generation
        ))
    }

    func clearForReuse() {
        clearCount += 1
        generation &+= 1
    }

    /// 模拟异步图标回调：捕获的 generation 仍当前 → 可写回；否则 stale 拒绝（零错写）。
    func applyIconIfValid(capturedGeneration: UInt64) -> Bool {
        if capturedGeneration == generation {
            return true
        }
        staleRejected += 1
        return false
    }
}

/// 无窗口 seamed surface（provider/renderer 在 init 后注入，与装配层接线方式一致）。
private func makeReloadSurface(
    provider: PagingPageContentProviding?,
    renderer: PagingPageRendering? = nil,
    pageCount: Int = 5,
    itemsPerPage: Int = 8
) -> PagingSurface {
    let surface = PagingSurface(pageCount: pageCount, itemsPerPage: itemsPerPage)
    surface.frameDriver = nil
    surface.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
    surface.layout()
    surface.contentProvider = provider
    surface.renderer = renderer
    return surface
}

final class PagingSurfaceSearchReloadTests: XCTestCase {

    // MARK: - idle → 立即 reload

    func testIdleReloadAppliesImmediately() {
        let provider = ReloadProvider(revision: 3, pageCount: 5)
        let renderer = RecordingRenderer()
        let surface = makeReloadSurface(provider: provider, renderer: renderer, pageCount: 5)
        XCTAssertEqual(surface.core.state, .idle)
        let before = renderer.calls.count
        XCTAssertGreaterThan(before, 0, "初始 pass 已渲染 live hosts")

        renderer.calls.removeAll()
        surface.reloadCurrentPresentation()
        XCTAssertFalse(renderer.calls.isEmpty, "idle 立即 reload：live hosts 全量重渲染")
        XCTAssertTrue(renderer.calls.allSatisfy { $0.revision == 3 }, "同 revision 重载保持 revision 3")
        XCTAssertEqual(surface.servedRevision, 3, "servedRevision 不变（不 mint/forge CatalogRevision）")
        XCTAssertFalse(surface.pendingSameRevisionReload, "idle 立即应用，无 pending")
    }

    func testReloadKeepsServedRevisionUnchanged() {
        let provider = ReloadProvider(revision: 7, pageCount: 5)
        let surface = makeReloadSurface(provider: provider, pageCount: 5)
        XCTAssertEqual(surface.servedRevision, 7)

        provider.pageCount = 3 // query 变化 → 结果页数变化，但 revision 不变
        surface.reloadCurrentPresentation()
        XCTAssertEqual(surface.servedRevision, 7, "query 变化绝不 mint/forge CatalogRevision")
        XCTAssertEqual(surface.core.pageCount, 3, "pageCount 随 provider 当前 presentation 更新")
    }

    // MARK: - tracking/settling/interrupted → 只 pending

    func testTrackingReloadOnlyPending() {
        let provider = ReloadProvider(revision: 1, pageCount: 8)
        let renderer = RecordingRenderer()
        let surface = makeReloadSurface(provider: provider, renderer: renderer, pageCount: 8)
        renderer.calls.removeAll()

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 200, at: 0.2)
        XCTAssertEqual(surface.core.state, .tracking)

        surface.reloadCurrentPresentation()
        XCTAssertTrue(renderer.calls.isEmpty, "tracking 中 reload 不中途换内容（只 pending）")
        XCTAssertTrue(surface.pendingSameRevisionReload, "tracking 中只记录 latest pending")

        // idle 边界一次应用。
        gestureEnded(surface, at: 0.4)
        finishPendingGesture(surface, at: 0.4)
        settleFrames(surface)
        XCTAssertEqual(surface.core.state, .idle)
        XCTAssertFalse(surface.pendingSameRevisionReload, "idle 边界应用后清空 pending")
        XCTAssertFalse(renderer.calls.isEmpty, "idle 边界应用同 revision 重载")
    }

    func testSettlingReloadOnlyPending() {
        let provider = ReloadProvider(revision: 1, pageCount: 8)
        let renderer = RecordingRenderer()
        let surface = makeReloadSurface(provider: provider, renderer: renderer, pageCount: 8)
        renderer.calls.removeAll()

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 600, at: 0.5)
        gestureEnded(surface, at: 0.5)
        finishPendingGesture(surface, at: 0.5)
        XCTAssertEqual(surface.core.state, .settling)

        // 记录 settling 期间已生效的 pageCount（动画自身会重渲染，不依赖 calls 为空）。
        let settledPageCount = surface.core.pageCount

        provider.pageCount = 3 // query 变化 → 结果缩页
        surface.reloadCurrentPresentation()
        XCTAssertTrue(surface.pendingSameRevisionReload, "settling 中只记录 latest pending")
        XCTAssertEqual(surface.core.pageCount, settledPageCount, "settling 中不中途改 pageCount（只 pending）")

        settleFrames(surface)
        XCTAssertEqual(surface.core.state, .idle)
        XCTAssertFalse(surface.pendingSameRevisionReload, "idle 边界应用后清空 pending")
        XCTAssertEqual(surface.core.pageCount, 3, "idle 边界应用同 revision 重载 → pageCount 更新")
    }

    // MARK: - 多次 pending 只应用最新

    func testMultiplePendingReloadAppliesLatestOnce() {
        let provider = ReloadProvider(revision: 1, pageCount: 8)
        let renderer = RecordingRenderer()
        let surface = makeReloadSurface(provider: provider, renderer: renderer, pageCount: 8)
        renderer.calls.removeAll()

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 200, at: 0.2)
        XCTAssertEqual(surface.core.state, .tracking)

        // 连续多次 query 变化 → 只记录最新（幂等，不堆积）。
        surface.reloadCurrentPresentation()
        surface.reloadCurrentPresentation()
        surface.reloadCurrentPresentation()
        XCTAssertTrue(surface.pendingSameRevisionReload, "多次 pending 只记录最新（latest-wins）")
        XCTAssertTrue(renderer.calls.isEmpty, "busy 期间零重渲染")

        gestureEnded(surface, at: 0.4)
        finishPendingGesture(surface, at: 0.4)
        settleFrames(surface)
        XCTAssertEqual(surface.core.state, .idle)
        XCTAssertFalse(surface.pendingSameRevisionReload, "idle 边界一次应用后清空")
        XCTAssertFalse(renderer.calls.isEmpty, "idle 边界应用一次（不重复堆积）")
    }

    // MARK: - 新 catalog revision 优先于旧同 revision 重载

    func testNewCatalogRevisionOutranksOldSameRevisionReload() {
        let provider = ReloadProvider(revision: 1, pageCount: 8)
        let renderer = RecordingRenderer()
        let surface = makeReloadSurface(provider: provider, renderer: renderer, pageCount: 8)
        renderer.calls.removeAll()

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 200, at: 0.2)
        XCTAssertEqual(surface.core.state, .tracking)

        // 先来旧同 revision 重载（query 变化）。
        surface.reloadCurrentPresentation()
        XCTAssertTrue(surface.pendingSameRevisionReload)

        // 再来新 catalog revision（refresh）—— 更强 truth，必须优先。
        provider.revision = 2
        surface.refreshPresentation()
        XCTAssertEqual(surface.pendingLatestSnapshot?.revision, 2, "pending catalog revision 已记录")
        XCTAssertTrue(surface.pendingSameRevisionReload, "同 revision 重载 pending 仍存在（不丢失）")

        // idle 边界：catalog revision 优先，同 revision 重载被取代。
        gestureEnded(surface, at: 0.4)
        finishPendingGesture(surface, at: 0.4)
        settleFrames(surface)
        XCTAssertEqual(surface.core.state, .idle)
        XCTAssertEqual(surface.servedRevision, 2, "新 catalog revision 应用")
        XCTAssertFalse(surface.pendingSameRevisionReload, "旧同 revision 重载被 catalog revision 取代")
        XCTAssertNil(surface.pendingLatestSnapshot, "pending catalog revision 已应用清空")

        let after = renderer.calls
        XCTAssertFalse(after.isEmpty)
        XCTAssertEqual(after.last?.revision, 2, "最终渲染为最新 catalog revision（旧重载未覆盖）")
    }

    func testOldSameRevisionReloadDoesNotOverrideNewCatalogRevision() {
        let provider = ReloadProvider(revision: 1, pageCount: 8)
        let renderer = RecordingRenderer()
        let surface = makeReloadSurface(provider: provider, renderer: renderer, pageCount: 8)
        renderer.calls.removeAll()

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 200, at: 0.2)
        XCTAssertEqual(surface.core.state, .tracking)

        // 先来新 catalog revision。
        provider.revision = 2
        surface.refreshPresentation()
        XCTAssertEqual(surface.pendingLatestSnapshot?.revision, 2)

        // 再来旧同 revision 重载 —— 不得覆盖 pending catalog revision。
        surface.reloadCurrentPresentation()
        XCTAssertEqual(surface.pendingLatestSnapshot?.revision, 2, "同 revision 重载不覆盖 pending catalog revision")
        XCTAssertTrue(surface.pendingSameRevisionReload)

        gestureEnded(surface, at: 0.4)
        finishPendingGesture(surface, at: 0.4)
        settleFrames(surface)
        XCTAssertEqual(surface.servedRevision, 2, "catalog revision 优先应用")
        XCTAssertEqual(renderer.calls.last?.revision, 2, "旧同 revision 重载未覆盖新 catalog revision")
    }

    // MARK: - pageCount 缩小 / 0 / 1 / 多页

    func testReloadUpdatesPageCountShrink() {
        let provider = ReloadProvider(revision: 1, pageCount: 5)
        let renderer = RecordingRenderer()
        let surface = makeReloadSurface(provider: provider, renderer: renderer, pageCount: 5)
        XCTAssertEqual(surface.core.pageCount, 5)

        renderer.calls.removeAll() // 清掉初始 pass 的渲染记录，只断言 reload 后的渲染
        provider.pageCount = 2 // query 变化 → 结果缩页
        surface.reloadCurrentPresentation()
        XCTAssertEqual(surface.core.pageCount, 2, "pageCount 合法缩小（经 setPageCount，非 shrink-then-restore）")
        XCTAssertFalse(renderer.calls.isEmpty)
        XCTAssertTrue(renderer.calls.allSatisfy { $0.pageCount == 2 }, "live hosts 经 seam 刷新页码")
        XCTAssertEqual(surface.servedRevision, 1, "revision 不变")
    }

    func testReloadUpdatesPageCountZero() {
        let provider = ReloadProvider(revision: 1, pageCount: 5)
        let surface = makeReloadSurface(provider: provider, pageCount: 5)
        XCTAssertEqual(surface.core.pageCount, 5)

        provider.pageCount = 0 // 无结果 → 0 页
        surface.reloadCurrentPresentation()
        XCTAssertEqual(surface.core.pageCount, 0, "无结果 → 0 页（合法空态）")
        XCTAssertEqual(surface.liveHostCount, 0, "0 页无 live host")
    }

    func testReloadUpdatesPageCountOne() {
        let provider = ReloadProvider(revision: 1, pageCount: 5)
        let surface = makeReloadSurface(provider: provider, pageCount: 5)

        provider.pageCount = 1
        surface.reloadCurrentPresentation()
        XCTAssertEqual(surface.core.pageCount, 1)
        XCTAssertEqual(surface.liveHostCount, 1, "单页 → 1 个 live host")
    }

    func testReloadUpdatesPageCountMulti() {
        let provider = ReloadProvider(revision: 1, pageCount: 5)
        let surface = makeReloadSurface(provider: provider, pageCount: 5)

        provider.pageCount = 8
        surface.reloadCurrentPresentation()
        XCTAssertEqual(surface.core.pageCount, 8, "多页 pageCount 更新")
        // live host 数受可见范围上界约束（radius 3 → 最多 7），不随 pageCount 无界增长。
        let bound = 2 * PagingSurface.pageRadius(for: surface.core.parameters) + 1
        XCTAssertLessThanOrEqual(surface.liveHostCount, bound, "live host 数不超上界")
        XCTAssertGreaterThan(surface.liveHostCount, 0, "有可见页 → 有 live host")
    }

    // MARK: - host/view 数上界不变

    func testReloadKeepsHostViewUpperBound() {
        let provider = ReloadProvider(revision: 1, pageCount: 20)
        let surface = makeReloadSurface(provider: provider, pageCount: 20)
        // 上界 = 2 * ceil(livePageRadius + prewarmDistance) + 1 = 2*3 + 1 = 7。
        let bound = 2 * PagingSurface.pageRadius(for: surface.core.parameters) + 1
        XCTAssertEqual(bound, 7)
        XCTAssertLessThanOrEqual(surface.liveHostCount, bound, "初始 live host 数不超上界")

        // 多次同 revision 重载（pageCount 变化）→ live host 数不无界增长。
        for count in [20, 12, 7, 3, 1, 0, 1, 5, 20] {
            provider.pageCount = count
            surface.reloadCurrentPresentation()
            XCTAssertLessThanOrEqual(surface.liveHostCount, bound,
                                      "reload 后 live host 数不超上界（pageCount=\(count)）")
        }
    }

    // MARK: - 旧图标乱序回调零错写（generation/token gating）

    func testReloadBumpsGenerationRejectingOldIconCallback() {
        let provider = ReloadProvider(revision: 1, pageCount: 5)
        let renderer = GatedRenderer()
        let surface = makeReloadSurface(provider: provider, renderer: renderer, pageCount: 5)
        XCTAssertFalse(renderer.calls.isEmpty, "初始 pass 已渲染")
        let genAfterInitial = renderer.generation
        XCTAssertGreaterThan(genAfterInitial, 0)

        // 初始 render 期间发起的在途图标回调（捕获 genAfterInitial）→ 当前仍有效。
        XCTAssertTrue(renderer.applyIconIfValid(capturedGeneration: genAfterInitial),
                      "初始 render 的 generation 当前有效")

        // query 变化 → 同 revision 重载 → 强制重渲染 → generation bump。
        surface.reloadCurrentPresentation()
        XCTAssertGreaterThan(renderer.generation, genAfterInitial, "reload 强制重渲染 → generation bump")
        XCTAssertFalse(renderer.calls.isEmpty, "reload 后 live hosts 已重渲染")

        // 旧图标回调（捕获旧 generation）→ 被 generation/token 拒绝，零错写。
        XCTAssertFalse(renderer.applyIconIfValid(capturedGeneration: genAfterInitial),
                      "旧图标回调被 generation 拒绝（stale apply = 0）")
        XCTAssertEqual(renderer.staleRejected, 1, "旧回调计数为 stale rejected")
    }

    // MARK: - teardown 后零写回

    func testReloadAfterTeardownZeroWriteback() {
        let provider = ReloadProvider(revision: 1, pageCount: 5)
        let renderer = RecordingRenderer()
        let surface = makeReloadSurface(provider: provider, renderer: renderer, pageCount: 5)
        renderer.calls.removeAll()

        surface.teardown()
        XCTAssertTrue(surface.isTearingDown)

        surface.reloadCurrentPresentation()
        XCTAssertTrue(renderer.calls.isEmpty, "teardown 后 reload 零写回")
        XCTAssertFalse(surface.pendingSameRevisionReload, "teardown 清空同 revision 重载 pending")
        XCTAssertNil(surface.pendingLatestSnapshot, "teardown 清空 catalog revision pending")
    }
}
