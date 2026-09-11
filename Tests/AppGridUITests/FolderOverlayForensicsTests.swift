// AppGridUITests — FolderOverlayForensicsTests（T-1F-B10-wave-a：BUG10 缺陷 A 取证布点 s14/s15）
// 验证（任务包 §2 布点 1/2 + §5 验证②③）：
// - s14：overlay.hitTest 入口逐次计数；挂载时 _sv0、removeFromSuperview 后 _sv1
//   （superview==nil 布尔位翻转）；hitTest 返回值零回归（按钮区/成员区/遮罩区 === 改前一致）；
// - s15：mouseDown 面板内非成员区（标题区）静默 return +1 且 coordinator 零派发
//   （controller 保持 idle、空白计数不增）；成员命中 → pointerDown 到达（不走 s15）；
//   遮罩区 → 空白按下派发（不走 s15）——两条既有分支逐一对齐；
// - sink 变体名编码（_sv1/_sv0）硬断言。
//
// 全部 @MainActor；fixture 合成数据（fixture.* / 'Group 1' / 固定 UUID），无真实 app 身份。

import AppCatalogCore
import AppIconPipeline
import AppKit
import PagingUI
@testable import AppGridUI
import XCTest

@MainActor
final class FolderOverlayForensicsTests: XCTestCase {

    private var retainedHost: NSView?
    private var retainedPipelines: [IconPipeline] = []

    override func tearDown() {
        DragUISessionCoordinator.shared = nil
        retainedHost = nil
        for pipeline in retainedPipelines { pipeline.shutdown() }
        retainedPipelines.removeAll()
        super.tearDown()
    }

    private func makeParameters() -> DragParameters {
        DragParameters(dragStartThresholdPT: 6, edgeDwellDurationMs: 100, edgeZoneWidthPT: 40,
                       edgeHysteresisPT: 10, dropZoneMarginsPT: 8, overlayMoveOutArmThresholdPT: 24,
                       edgeTurnMinIntervalMs: 200, maxDragPreviewScale: 1.0)
    }

    private func makeCoordinator(host: NSView) -> DragUISessionCoordinator {
        let coordinator = DragUISessionCoordinator(host: host, parameters: makeParameters(),
                                                   clock: FakeDragClock(0))
        retainedHost = host
        return coordinator
    }

    /// 挂载 + 配置 2 成员的 overlay（400x300 窗口；面板居中；成员 cell 可经 memberCell(at:) 取）。
    private func makeMountedOverlay(folderID: FolderID = FolderID()) -> (overlay: FolderOverlayView, window: NSWindow) {
        let pipeline = IconPipeline(loader: GatedIconLoader(), limits: .init())
        retainedPipelines.append(pipeline)
        let overlay = FolderOverlayView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = overlay
        overlay.layoutSubtreeIfNeeded()

        let ids = [makeAppID("fixture.member0"), makeAppID("fixture.member1")]
        let entry = FolderEntry(id: folderID, title: "Group 1", members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { id in
            id == ids[0] ? "Member0" : "Member1"
        }
        overlay.layoutSubtreeIfNeeded()
        return (overlay, window)
    }

    private func mouseEvent(_ type: NSEvent.EventType, window: NSWindow, at windowPoint: NSPoint) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: windowPoint, modifierFlags: [], timestamp: 0,
                           windowNumber: window.windowNumber, context: nil,
                           eventNumber: 0, clickCount: 1, pressure: 1)!
    }

    // MARK: - s14：hitTest 入口 + superview==nil 布尔位

    func testHitTestCensusCountsAndSuperviewNilBitFlipsWhenDetached() throws {
        ClickCensus.resetForTesting()
        let (overlay, window) = makeMountedOverlay()
        let memberCell = try XCTUnwrap(overlay.memberCell(at: 0))
        let memberPoint = memberCell.convert(NSPoint(x: memberCell.bounds.midX, y: memberCell.bounds.midY),
                                             to: nil)
        // 遮罩区（panel 外）点：overlay 局部 (20, 150) 在 400x300 下 panel 恒居中且边距 ≥20。
        let maskPoint = overlay.convert(NSPoint(x: 20, y: 150), to: nil)

        // 挂载态两击：入口计数 +2，布尔位 _sv0（superview 非 nil）。
        XCTAssertTrue(overlay.hitTest(memberPoint) === overlay, "成员区命中仍归 overlay（零行为回归）")
        XCTAssertTrue(overlay.hitTest(maskPoint) === overlay, "遮罩区命中仍归 overlay（零行为回归）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.overlayHitTest(superviewIsNil: false)), 2,
                       "挂载态 hitTest 入口计数 + 布尔位 _sv0")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.overlayHitTest(superviewIsNil: true)), 0,
                       "挂载态不产生 _sv1")

        // 摘下后一击：布尔位翻转为 _sv1；hitTest 返回值语义不变（仍归 overlay）。
        overlay.removeFromSuperview()
        XCTAssertNil(overlay.superview)
        XCTAssertTrue(overlay.hitTest(memberPoint) === overlay,
                      "detached overlay 直接 hitTest 仍返回 self（返回值零行为变更）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.overlayHitTest(superviewIsNil: true)), 1,
                       "superview==nil 时布尔位翻转 _sv1")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.overlayHitTest(superviewIsNil: false)), 2)
        _ = window
    }

    func testHitTestButtonRegionsStillPassThroughAndCount() throws {
        ClickCensus.resetForTesting()
        // 按钮仅在多页 folder（非首末页）可见（prev 隐藏于第 0 页）；构造 3 成员 + 每页 1 个。
        let pipeline = IconPipeline(loader: GatedIconLoader(), limits: .init())
        retainedPipelines.append(pipeline)
        let overlay = FolderOverlayView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = overlay
        overlay.layoutSubtreeIfNeeded()
        overlay.membersPerPage = 1
        let ids = (0..<3).map { makeAppID("fixture.member\($0)") }
        overlay.configure(entry: FolderEntry(id: FolderID(), title: "Group 1", members: ids),
                          innerPage: 1, reduceMotion: false) { _ in "M" }
        overlay.layoutSubtreeIfNeeded()

        let panel = overlay.panelFrame
        // prev 按钮：panel 局部 (inset, 8, 40, 24) 中心；next：右缘对称。
        let prevCenter = overlay.convert(NSPoint(x: panel.minX + 24 + 20, y: panel.minY + 8 + 12), to: nil)
        let nextCenter = overlay.convert(NSPoint(x: panel.maxX - 24 - 20, y: panel.minY + 8 + 12), to: nil)
        XCTAssertTrue(overlay.hitTest(prevCenter) is NSButton, "prev 按钮区仍放行按钮自身（零行为回归）")
        XCTAssertTrue(overlay.hitTest(nextCenter) is NSButton, "next 按钮区仍放行按钮自身（零行为回归）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.overlayHitTest(superviewIsNil: false)), 2,
                       "按钮区命中同样经 hitTest 入口计数")
    }

    // MARK: - s15：mouseDown 面板内非成员区静默 return

    func testMouseDownPanelInnerNonMemberZoneSilentReturns() throws {
        ClickCensus.resetForTesting()
        let (overlay, window) = makeMountedOverlay()
        let coordinator = makeCoordinator(host: overlay)
        overlay.dragCoordinator = coordinator
        let panel = overlay.panelFrame
        // 标题区（面板内、成员网格外）：panel 顶部中央偏上。
        let titlePoint = overlay.convert(NSPoint(x: panel.midX, y: panel.maxY - 20), to: nil)
        overlay.mouseDown(with: mouseEvent(.leftMouseDown, window: window, at: titlePoint))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.overlayMouseDownSilentReturn), 1,
                       "面板内非成员区 → 静默 return 计数")
        XCTAssertEqual(coordinator.controller.state, .idle, "静默 return：coordinator 零派发（行为对齐）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.pendingBlankNoCell), 0, "未走空白按下派发")
    }

    func testMouseDownMemberCellReachesCoordinatorNotSilent() throws {
        ClickCensus.resetForTesting()
        let folderID = FolderID()
        let (overlay, window) = makeMountedOverlay(folderID: folderID)
        let memberCell = try XCTUnwrap(overlay.memberCell(at: 0))
        let coordinator = makeCoordinator(host: overlay)
        overlay.dragCoordinator = coordinator
        // T1FD1Fix 同构：member 源 + layout/catalog 注入达成 .pressed（成员源分支）。
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.folder(folderID)],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1",
                                             members: [ref("member0"), ref("member1")])])
        let (_, snapshot) = makeDragLayout(titles: ["member0", "member1"])
        coordinator.layoutProvider = { layout }
        coordinator.catalogSnapshotProvider = { snapshot }

        let memberPoint = memberCell.convert(NSPoint(x: memberCell.bounds.midX, y: memberCell.bounds.midY),
                                             to: nil)
        overlay.mouseDown(with: mouseEvent(.leftMouseDown, window: window, at: memberPoint))
        XCTAssertEqual(coordinator.controller.state, .pressed, "成员命中 → pointerDown 到达（行为对齐）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.overlayMouseDownSilentReturn), 0,
                       "成员命中分支不走静默 return")
    }

    func testMouseDownMaskZoneDispatchesBlankNotSilent() throws {
        ClickCensus.resetForTesting()
        let (overlay, window) = makeMountedOverlay()
        let coordinator = makeCoordinator(host: overlay)
        overlay.dragCoordinator = coordinator
        var blankClicks = 0
        coordinator.onOverlayBlankClick = { blankClicks += 1 }

        let maskPoint = overlay.convert(NSPoint(x: 20, y: 150), to: nil)
        overlay.mouseDown(with: mouseEvent(.leftMouseDown, window: window, at: maskPoint))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.overlayMouseDownSilentReturn), 0,
                       "遮罩区不走静默 return")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.pendingBlankNoCell), 1,
                       "遮罩区 → 空白按下派发（行为对齐）")
        overlay.mouseUp(with: mouseEvent(.leftMouseUp, window: window, at: maskPoint))
        XCTAssertEqual(blankClicks, 1, "未过阈值 → onOverlayBlankClick（行为对齐）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.blankBranchDispatch), 1)
    }

    // MARK: - sink 变体名编码

    func testOverlaySinkNamesCarrySuperviewBits() {
        XCTAssertEqual(ClickCensus.Sink.overlayHitTestBase, "s14_overlay_hittest")
        XCTAssertEqual(ClickCensus.Sink.overlayHitTest(superviewIsNil: true), "s14_overlay_hittest_sv1")
        XCTAssertEqual(ClickCensus.Sink.overlayHitTest(superviewIsNil: false), "s14_overlay_hittest_sv0")
        XCTAssertEqual(ClickCensus.Sink.overlayMouseDownSilentReturn, "s15_overlay_mousedown_silent_return")
    }
}
