//
//  PagingSeamTests.swift
//  PagingUITests
//
//  §E 内容承载 seam（Wave 2）：
//  - revision 一致性：tracking 全程同 revision、相邻页不混（§6.1）；
//  - pin 生命周期：began 捕获 servedRevision / idle 边界清除 / interrupted 保持（Explorer B）；
//  - refreshPresentation：idle 批量 re-prepare；tracking/settling 只写 pendingLatestSnapshot，
//    idle/cancelled 边界一次性 apply（§6.2 latest-wins）；
//  - clear 作废在途绑定：reuseGeneration bump → stale apply = 0（§6.4/§10.5）；
//  - nil provider → NeutralContentProvider 中性占位（Phase 1A 回归模式，§E 约束④）；
//  - provider 未就绪（servedRevision == nil）→ 中性占位、refresh 无操作。
//

import AppKit
import XCTest
@testable import PagingCore
@testable import PagingUI

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

/// 可编程假提供者：与真实 AppGridUIPageContentProvider 同契约——
/// 只服务 revision == servedRevision 的请求并回显 presentation；否则中性占位（items 空）。
private final class FakeContentProvider: PagingPageContentProviding {
    /// nil = 未就绪（无已提交快照）→ 全部占位。
    var revision: UInt64?
    var pageCount: Int = 5
    var requestedRevisions: [UInt64] = []

    var servedRevision: UInt64? { revision }
    var servedPageCount: Int? { pageCount }

    init(revision: UInt64? = 1, pageCount: Int = 5) {
        self.revision = revision
        self.pageCount = pageCount
    }

    func content(for presentation: PagePresentationID, itemsPerPage: Int) -> PagingPageContent {
        requestedRevisions.append(presentation.revision)
        guard let served = revision, presentation.revision == served else {
            return PagingPageContent(presentationID: presentation, items: [], isPlaceholder: true)
        }
        return PagingPageContent(
            presentationID: presentation,
            items: (0..<itemsPerPage).map { PagingPageContentItem(slot: $0, identity: nil, title: "r\(served)-\($0)") },
            isPlaceholder: false
        )
    }
}

/// 无窗口 seamed surface（provider/renderer 在 init 后注入，与装配层接线方式一致）。
private func makeSeamedSurface(
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

final class PagingSeamTests: XCTestCase {

    // MARK: - revision 一致性（§6.1）

    func testInitialPassRendersSingleRevision() {
        let provider = FakeContentProvider(revision: 3, pageCount: 8)
        let renderer = RecordingRenderer()
        let surface = makeSeamedSurface(provider: provider, renderer: renderer, pageCount: 8)

        XCTAssertEqual(surface.servedRevision, 3, "provider 注入时采纳 servedRevision")
        XCTAssertFalse(renderer.calls.isEmpty)
        XCTAssertTrue(renderer.calls.allSatisfy { $0.revision == 3 }, "初始 pass 全部 live 页同 revision")
        XCTAssertTrue(provider.requestedRevisions.allSatisfy { $0 == 3 }, "seam 请求全部携带 pass revision")
    }

    func testTrackingKeepsSingleRevisionAcrossFling() {
        let provider = FakeContentProvider(revision: 3, pageCount: 20)
        let renderer = RecordingRenderer()
        let surface = makeSeamedSurface(provider: provider, renderer: renderer, pageCount: 20)
        XCTAssertNil(surface.pinnedPresentation, "provider 注入时 pin 未激活")

        renderer.calls.removeAll()
        for _ in 0..<5 { flingForwardOnce(surface) } // 长旅程：tracking/settling 多次 relayout + 回收
        XCTAssertEqual(surface.core.committedPage, 5)
        XCTAssertTrue(renderer.calls.allSatisfy { $0.revision == 3 }, "tracking 全程同 revision（无混版）")
        XCTAssertEqual(surface.servedRevision, 3, "手势中不采纳新 revision（pin 纪律）")
    }

    func testAdjacentPagesNeverMixRevisionsAfterRefresh() {
        let provider = FakeContentProvider(revision: 1, pageCount: 20)
        let renderer = RecordingRenderer()
        let surface = makeSeamedSurface(provider: provider, renderer: renderer, pageCount: 20)

        for _ in 0..<2 { flingForwardOnce(surface) }
        renderer.calls.removeAll()
        provider.revision = 2
        surface.refreshPresentation() // idle：原子替换 presentation
        XCTAssertFalse(renderer.calls.isEmpty)
        XCTAssertTrue(renderer.calls.allSatisfy { $0.revision == 2 }, "refresh 后所有 live 页同 revision 2")
        XCTAssertEqual(surface.servedRevision, 2)

        renderer.calls.removeAll()
        flingForwardOnce(surface) // 新页进入范围也同 revision 2
        XCTAssertTrue(renderer.calls.allSatisfy { $0.revision == 2 }, "相邻页不混 revision")
    }

    // MARK: - pin 生命周期（began / idle / interrupted）

    func testPinLifecycleBeganAndIdleClear() {
        let surface = makeSeamedSurface(provider: FakeContentProvider(revision: 4), pageCount: 8)

        // began：捕获 servedRevision + 当前页。
        surface.beginInteraction()
        XCTAssertEqual(surface.pinnedPresentation?.revision, 4, "began 捕获 servedRevision")
        XCTAssertEqual(surface.pinnedPresentation?.pageIndex, 0, "began 捕获当前页")

        // idle 边界 endInteraction：清除 pin。
        surface.endInteraction()
        XCTAssertNil(surface.pinnedPresentation, "idle 边界清除 pin")

        // 手势自动接线：gestureBegan → pin；tracking 中 endInteraction → 保持。
        gestureBegan(surface, at: 0)
        XCTAssertEqual(surface.pinnedPresentation?.revision, 4, "手势 began 自动捕获 pin")
        gestureChanged(surface, deltaX: 200, at: 0.2)
        XCTAssertEqual(surface.core.state, .tracking)
        surface.endInteraction()
        XCTAssertNotNil(surface.pinnedPresentation, "tracking 中 endInteraction 保持 pin")

        gestureEnded(surface, at: 0.4)
        finishPendingGesture(surface, at: 0.4)
        settleFrames(surface)
        XCTAssertEqual(surface.core.state, .idle)
        XCTAssertNil(surface.pinnedPresentation, "idle 边界自动清除 pin")
    }

    func testPinSurvivesInterruptionUntilIdle() {
        let provider = FakeContentProvider(revision: 1, pageCount: 8)
        let surface = makeSeamedSurface(provider: provider, pageCount: 8)

        // 第一次手势 → settle。
        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 600, at: 0.5)
        gestureEnded(surface, at: 0.5)
        finishPendingGesture(surface, at: 0.5)
        XCTAssertEqual(surface.core.state, .settling)
        XCTAssertNotNil(surface.pinnedPresentation, "settle 中 pin 保持")

        // settle 中接管（D4/D5 → interrupted 瞬时态 → tracking）。
        gestureBegan(surface, at: 1.0)
        XCTAssertEqual(surface.core.state, .tracking)
        XCTAssertNotNil(surface.pinnedPresentation, "中断接管后 pin 仍保持（interrupted 保持）")
        surface.endInteraction()
        XCTAssertNotNil(surface.pinnedPresentation, "中断边界 endInteraction 保持 pin（interrupted）")

        // 完成接管手势 → idle → pin 清除。
        gestureChanged(surface, deltaX: -200, at: 1.3)
        gestureEnded(surface, at: 1.5)
        finishPendingGesture(surface, at: 1.5)
        settleFrames(surface)
        XCTAssertEqual(surface.core.state, .idle)
        XCTAssertNil(surface.pinnedPresentation, "idle 边界清除 pin")
    }

    // MARK: - refreshPresentation（latest-wins，§6.2）

    func testRefreshDuringTrackingCachesPendingAndAppliesAtIdle() {
        let provider = FakeContentProvider(revision: 1, pageCount: 8)
        let renderer = RecordingRenderer()
        let surface = makeSeamedSurface(provider: provider, renderer: renderer, pageCount: 8)
        renderer.calls.removeAll()

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 300, at: 0.2)
        XCTAssertEqual(surface.core.state, .tracking)
        XCTAssertEqual(surface.pinnedPresentation?.revision, 1)

        // tracking 中 refresh：只写 pendingLatestSnapshot；live 内容不动（latest-wins）。
        provider.revision = 2
        surface.refreshPresentation()
        XCTAssertEqual(surface.pinnedPresentation?.revision, 1, "pin 保持旧 revision")
        XCTAssertEqual(surface.pendingLatestSnapshot?.revision, 2, "pending 缓存最新 revision")
        let during = renderer.calls
        XCTAssertTrue(during.allSatisfy { $0.revision == 1 }, "gesture 期间 live 内容不跳版")

        // idle 边界：一次性 apply → 全量 re-prepare 到新 revision。
        gestureEnded(surface, at: 0.4)
        finishPendingGesture(surface, at: 0.4)
        settleFrames(surface)
        XCTAssertEqual(surface.core.state, .idle)
        XCTAssertNil(surface.pinnedPresentation, "idle 边界清除 pin")
        XCTAssertNil(surface.pendingLatestSnapshot, "idle 边界一次性 apply（pending 清空）")
        XCTAssertEqual(surface.servedRevision, 2)

        let after = renderer.calls.dropFirst(during.count)
        XCTAssertFalse(after.isEmpty)
        XCTAssertEqual(after.last?.revision, 2, "apply 后最后一批 render 为新 revision")
        if let firstRev2 = after.firstIndex(where: { $0.revision == 2 }) {
            XCTAssertTrue(after.dropFirst(firstRev2).allSatisfy { $0.revision == 2 },
                          "apply 后不再出现旧 revision")
        }
    }

    func testLatestWinsMultipleRefreshDuringGesture() {
        let provider = FakeContentProvider(revision: 1, pageCount: 8)
        let surface = makeSeamedSurface(provider: provider, pageCount: 8)

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 200, at: 0.2)
        provider.revision = 2
        surface.refreshPresentation()
        provider.revision = 3
        surface.refreshPresentation()
        provider.revision = 4
        surface.refreshPresentation()
        XCTAssertEqual(surface.pendingLatestSnapshot?.revision, 4, "只缓存最新（latest-wins，不堆积）")

        gestureEnded(surface, at: 0.4)
        finishPendingGesture(surface, at: 0.4)
        settleFrames(surface)
        XCTAssertNil(surface.pendingLatestSnapshot)
        XCTAssertEqual(surface.servedRevision, 4)
    }

    func testRefreshPresentationBatchRePrepareAllLiveHosts() {
        let provider = FakeContentProvider(revision: 1, pageCount: 5)
        let renderer = RecordingRenderer()
        let surface = makeSeamedSurface(provider: provider, renderer: renderer, pageCount: 5)
        let liveCount = surface.liveHostCount
        XCTAssertGreaterThan(liveCount, 0)
        XCTAssertEqual(renderer.calls.count, liveCount, "renderer 注入即全量渲染 live hosts")

        renderer.calls.removeAll()
        provider.revision = 2
        surface.refreshPresentation()
        XCTAssertEqual(renderer.calls.count, liveCount, "refreshPresentation 批量 re-prepare 全部 live hosts")
        XCTAssertTrue(renderer.calls.allSatisfy { $0.revision == 2 })
    }

    // MARK: - clear 作废在途绑定（§6.4：stale apply = 0）

    func testClearForReuseBumpsGenerationAndInvalidatesInflightBinding() {
        let surface = makeSurface(pageCount: 20, itemsPerPage: 8)
        let host = try! XCTUnwrap(surface.hostForPage(0))
        let gen0 = host.reuseGeneration
        XCTAssertEqual(gen0, 0)
        XCTAssertTrue(host.isReuseGenerationCurrent(gen0), "render 后当前 generation 有效")

        // 在途异步绑定模拟：捕获 gen0 → 翻走（clear 必然 bump）→ stale apply 被拒。
        // 注意：池化复用可能让该 host 再次 live（pool LIFO），故只断言 generation 契约
        // （clear 时 bump + 旧 generation 作废），不断言 -1 中间态。
        for _ in 0..<6 { flingForwardOnce(surface) } // page 0 出半径 → clearForReuse
        XCTAssertEqual(host.reuseGeneration, gen0 + 1, "clear 时 generation bump（且 pool 复用再 render 不再额外 bump）")
        XCTAssertFalse(host.isReuseGenerationCurrent(gen0), "旧 generation 作废在途绑定（stale apply = 0）")
        XCTAssertTrue(host.isReuseGenerationCurrent(host.reuseGeneration), "bump 后当前 generation 有效")
    }

    func testRecycleCallsClearForReuseAndRenderCarriesBumpedGeneration() {
        let provider = FakeContentProvider(revision: 1, pageCount: 20)
        let renderer = RecordingRenderer()
        let surface = makeSeamedSurface(provider: provider, renderer: renderer, pageCount: 20)
        XCTAssertTrue(renderer.calls.allSatisfy { $0.generation == 0 }, "初始 host generation 0")

        renderer.calls.removeAll()
        for _ in 0..<6 { flingForwardOnce(surface) } // 回收路径 → clearForReuse
        XCTAssertGreaterThanOrEqual(renderer.clearCount, 1, "回收时 host.clearForReuse → 渲染器 clearForReuse")

        renderer.calls.removeAll()
        for _ in 0..<6 { flingBackwardOnce(surface, at: 100) } // 复用池 host：generation 已 bump
        XCTAssertTrue(renderer.calls.allSatisfy { $0.generation >= 1 },
                      "render 携带 clear 后 bump 的 generation（防串图基线）")
    }

    // MARK: - nil provider → 中性占位（Phase 1A 回归模式）

    @MainActor
    func testNilProviderServesNeutralPlaceholder() async {
        let surface = makeSurface(pageCount: 5, itemsPerPage: 8) // nil provider
        XCTAssertEqual(surface.servedRevision, 0)
        XCTAssertNil(surface.pinnedPresentation)
        for index in 0..<4 {
            let host = surface.hostForPage(index)
            XCTAssertEqual(host?.preparedItemsPerPage, 8, "中性占位 item 数 = itemsPerPage")
            XCTAssertEqual(host?.visibleItemCount, 8, "中性 tile 网格渲染（Phase 1A 行为）")
            await drainDeferredPresentationTurns()
            XCTAssertEqual(host?.accessibilityLabel() as? String, "Page \(index + 1) of 5")
        }
        // refreshPresentation 在无 provider 时无操作。
        let layoutsBefore = surface.layoutPerformedCount
        surface.refreshPresentation()
        XCTAssertEqual(surface.servedRevision, 0)
        XCTAssertEqual(surface.layoutPerformedCount, layoutsBefore, "无 provider：refresh 不触发任何布局/渲染")
    }

    func testNilProviderContentIsPlaceholderViaRenderer() {
        let renderer = RecordingRenderer()
        let surface = makeSurface(pageCount: 3, itemsPerPage: 8)
        surface.renderer = renderer
        XCTAssertFalse(renderer.calls.isEmpty)
        XCTAssertTrue(renderer.calls.allSatisfy { $0.isPlaceholder }, "nil provider → 中性占位内容")
        XCTAssertEqual(renderer.calls.first?.revision, 0)
    }

    func testProviderNotReadyServesNeutralPlaceholderUntilRefresh() {
        let provider = FakeContentProvider(revision: nil, pageCount: 8) // 未就绪
        let renderer = RecordingRenderer()
        let surface = makeSeamedSurface(provider: provider, renderer: renderer, pageCount: 8)
        XCTAssertEqual(surface.servedRevision, 0, "未就绪 provider：不采纳 revision")
        XCTAssertTrue(renderer.calls.allSatisfy { $0.isPlaceholder }, "未就绪 → 全部中性占位（不阻塞手势）")

        renderer.calls.removeAll()
        surface.refreshPresentation() // nil servedRevision → 无操作
        XCTAssertTrue(renderer.calls.isEmpty)

        provider.revision = 5 // 就绪
        surface.refreshPresentation()
        XCTAssertEqual(surface.servedRevision, 5)
        XCTAssertTrue(renderer.calls.allSatisfy { $0.revision == 5 && !$0.isPlaceholder })
    }

    // MARK: - idle 边界事件 / pageCount 变化走 seam

    func testOnIdleBoundaryFiresOncePerSettle() {
        let surface = makeSurface(pageCount: 5)
        var boundaryCount = 0
        surface.onIdleBoundary = { boundaryCount += 1 }

        flingForwardOnce(surface)
        XCTAssertEqual(boundaryCount, 1, "settle 完成 → idle 边界事件一次")
        XCTAssertEqual(surface.core.state, .idle)

        gestureBegan(surface, at: 10)
        gestureChanged(surface, deltaX: 100, at: 10.2)
        XCTAssertEqual(boundaryCount, 1, "tracking 中不触发")
        gestureEnded(surface, at: 10.3)
        finishPendingGesture(surface, at: 10.3)
        settleFrames(surface)
        XCTAssertEqual(boundaryCount, 2, "第二次 settle 完成再触发一次")
    }

    func testSetPageCountRefreshesLiveHostsViaSeam() {
        let provider = FakeContentProvider(revision: 1, pageCount: 5)
        let renderer = RecordingRenderer()
        let surface = makeSeamedSurface(provider: provider, renderer: renderer, pageCount: 5)
        renderer.calls.removeAll()
        surface.setPageCount(8)
        XCTAssertEqual(surface.core.pageCount, 8)
        XCTAssertFalse(renderer.calls.isEmpty)
        XCTAssertTrue(renderer.calls.allSatisfy { $0.pageCount == 8 }, "live hosts 经 seam 刷新页码")
    }
}
