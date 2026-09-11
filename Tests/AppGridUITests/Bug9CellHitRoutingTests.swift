// AppGridUITests — Bug9CellHitRoutingTests（T-1F-B9-wave-a：BUG9 cell hitTest 漏斗回归）
// 验证（任务包 §6①-⑤ + ⑥⑦漏斗内直测；夹具中性 fixture.*，注入实例 coordinator）：
// - ①/②/③ hitTest(icon 中心/nameLabel/背景) === cell：子视图（NSImageView/NSTextField 家族）
//   不再拦截 mouse 路由，统一进 cell 自身 mouseDown（BUG9-REPORT §2 R1 候选修复面）；
// - ④ cell.mouseDown → coordinator.pointerDown（census snapshot s10_cell_mousedown_fired ≥ 1）；
// - ⑤ shared 与注入均 nil → s11_cell_lookup_nil+1 且不 crash、pointerDown 不进入；
// - ⑥ 漏斗下 drag 仲裁链完整（hitTest→mouseDown→pressed→拖过阈值→dragging；拖拽不派发点击）；
// - ⑦ folder overlay 命中不被 cell 漏斗劫持（overlay.hitTest === overlay）。
//
// 全部 @MainActor；fixture 合成数据（fixture.*），无真实 app 身份。

import AppCatalogCore
import AppIconPipeline
import AppKit
import PagingUI
@testable import AppGridUI
import XCTest

@MainActor
final class Bug9CellHitRoutingTests: XCTestCase {

    private var retainedHost: NSView?

    override func tearDown() {
        DragUISessionCoordinator.shared = nil
        retainedHost = nil
        super.tearDown()
    }

    // MARK: - 夹具（与 T1FD1FixUITests 同法；中性合成数据）

    private func makeParameters() -> DragParameters {
        DragParameters(dragStartThresholdPT: 6, edgeDwellDurationMs: 100, edgeZoneWidthPT: 40,
                       edgeHysteresisPT: 10, dropZoneMarginsPT: 8, overlayMoveOutArmThresholdPT: 24,
                       edgeTurnMinIntervalMs: 200, maxDragPreviewScale: 1.0)
    }

    private func makeHost() -> NSView {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        retainedHost = host
        return host
    }

    private func makeCoordinator(host: NSView) -> DragUISessionCoordinator {
        DragUISessionCoordinator(host: host, parameters: makeParameters(), clock: FakeDragClock(0))
    }

    private func makeAppCell(_ title: String) -> AppGridCellView {
        let cell = AppGridCellView(frame: NSRect(x: 0, y: 0, width: 80, height: 80))
        cell.bind(name: title, token: ItemBindingToken(
            catalogRevision: 1,
            pageIdentity: PagePresentationID(revision: 1, pageIndex: 0),
            itemSlot: 0,
            appID: AnyHashable(makeAppID("fixture.\(title.lowercased())")),
            reuseGeneration: 0,
            iconKey: nil,
            surfaceGeneration: 0))
        return cell
    }

    private func makeFolderID() -> FolderID {
        FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    }

    /// 窗口 + host + cell（frame 偏移非零，验证 hitTest 坐标系正确）。
    private func makeWindowWithCell() -> (window: NSWindow, host: NSView, cell: AppGridCellView) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let host = makeHost()
        window.contentView = host
        let cell = makeAppCell("fixtureapp")
        cell.frame = NSRect(x: 20, y: 20, width: 80, height: 80)
        host.addSubview(cell)
        host.layoutSubtreeIfNeeded()
        return (window, host, cell)
    }

    private func makeMouseDownEvent(in window: NSWindow, at point: NSPoint) -> NSEvent {
        NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [], timestamp: 0,
                           windowNumber: window.windowNumber, context: nil,
                           eventNumber: 0, clickCount: 1, pressure: 1)!
    }

    private func makeMouseDraggedEvent(in window: NSWindow, at point: NSPoint) -> NSEvent {
        NSEvent.mouseEvent(with: .leftMouseDragged, location: point, modifierFlags: [], timestamp: 0,
                           windowNumber: window.windowNumber, context: nil,
                           eventNumber: 1, clickCount: 1, pressure: 1)!
    }

    private func makeMouseUpEvent(in window: NSWindow, at point: NSPoint) -> NSEvent {
        NSEvent.mouseEvent(with: .leftMouseUp, location: point, modifierFlags: [], timestamp: 0,
                           windowNumber: window.windowNumber, context: nil,
                           eventNumber: 2, clickCount: 1, pressure: 1)!
    }

    /// 布好 layout/catalog/geometry 的注入 coordinator + cell（仲裁链可用）。
    private func makeWiredCellAndCoordinator() -> (NSView, DragUISessionCoordinator, AppGridCellView) {
        let host = makeHost()
        let coordinator = makeCoordinator(host: host)
        let (layout, snapshot) = makeDragLayout(titles: ["app1", "app2"])
        coordinator.layoutProvider = { layout }
        coordinator.catalogSnapshotProvider = { snapshot }
        coordinator.geometryProvider = { _ in
            topLevelGeometry(frames: rowFrames([.app(ref("app1")), .app(ref("app2"))]))
        }
        let cell = makeAppCell("app1")
        cell.dragCoordinator = coordinator
        return (host, coordinator, cell)
    }

    // MARK: - §6 ①②③：hitTest 漏斗（icon/标签/背景统一命中 cell）

    func testHitTestAtIconCenterReturnsCell() {
        let (window, _, cell) = makeWindowWithCell()
        // 直接以 cell 为入口调用（与父视图默认 hitTest 下探同一调用约定：父坐标系点）。
        let iconCenterInSuperview = cell.convert(
            NSPoint(x: cell.iconView.frame.midX, y: cell.iconView.frame.midY), to: cell.superview)
        XCTAssertTrue(cell.hitTest(iconCenterInSuperview) === cell,
                      "icon（最大点击靶，NSImageView）中心必须命中 cell 自身")
        // 真实窗口路由面：contentView.hitTest 沿树下探到 cell.hitTest。
        let windowPoint = cell.convert(
            NSPoint(x: cell.iconView.frame.midX, y: cell.iconView.frame.midY), to: nil)
        XCTAssertTrue(window.contentView?.hitTest(windowPoint) === cell,
                      "窗口层 hitTest 在 icon 区域必须路由到 cell（漏斗出口）")
    }

    func testHitTestAtNameLabelReturnsCell() {
        let (window, _, cell) = makeWindowWithCell()
        let labelPointInSuperview = cell.convert(
            NSPoint(x: cell.nameLabel.frame.midX, y: cell.nameLabel.frame.midY), to: cell.superview)
        XCTAssertTrue(cell.hitTest(labelPointInSuperview) === cell,
                      "名称标签（NSTextField label）点击必须命中 cell 自身")
        let windowPoint = cell.convert(
            NSPoint(x: cell.nameLabel.frame.midX, y: cell.nameLabel.frame.midY), to: nil)
        XCTAssertTrue(window.contentView?.hitTest(windowPoint) === cell,
                      "窗口层 hitTest 在名称标签区域必须路由到 cell")
    }

    func testHitTestAtBackgroundReturnsCell() {
        let (window, _, cell) = makeWindowWithCell()
        // 格内空白：避让 icon（y ∈ [20,68]）与标签（y ∈ [0,26]）的纯背景点。
        let backgroundPoint = NSPoint(x: 6, y: cell.bounds.maxY - 4)
        let pointInSuperview = cell.convert(backgroundPoint, to: cell.superview)
        XCTAssertTrue(cell.hitTest(pointInSuperview) === cell, "格内空白点击必须命中 cell 自身")
        let windowPoint = cell.convert(backgroundPoint, to: nil)
        XCTAssertTrue(window.contentView?.hitTest(windowPoint) === cell,
                      "窗口层 hitTest 在格内空白区域必须路由到 cell")
        XCTAssertEqual(cell.hitTest(pointInSuperview), window.contentView?.hitTest(windowPoint),
                       "两条调用面命中同一视图")
    }

    // MARK: - §6 ④：mouseDown 经 cell → pointerDown 被调（census s10 ≥ 1）

    func testCellMouseDownRoutesToCoordinatorPointerDownAndCensus() {
        let (_, coordinator, cell) = makeWiredCellAndCoordinator()
        ClickCensus.resetForTesting()

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = cell
        let downPoint = cell.convert(NSPoint(x: cell.bounds.midX, y: cell.bounds.midY), to: nil)

        cell.mouseDown(with: makeMouseDownEvent(in: window, at: downPoint))
        XCTAssertEqual(coordinator.controller.state, .pressed,
                       "cell.mouseDown → pointerDown → 仲裁 .pressed（漏斗出口接通）")
        XCTAssertTrue(coordinator.isSessionActive)

        let snapshotCensus = ClickCensus.snapshot()
        XCTAssertGreaterThanOrEqual(snapshotCensus[ClickCensus.Sink.cellMouseDownFired] ?? 0, 1,
                                    "census snapshot s10_cell_mousedown_fired ≥ 1")
        XCTAssertGreaterThanOrEqual(ClickCensus.count(ClickCensus.Sink.cellMouseDownFired), 1,
                                    "s10 单 sink 计数 ≥ 1")

        coordinator.pointerUp(locationInWindow: downPoint)
    }

    // MARK: - §6 ⑤：shared 与注入均 nil → s11+1 且不 crash

    func testLookupNilIncrementsS11WithoutCrash() {
        let cell = makeAppCell("app1")   // dragCoordinator 保持 nil
        let previousShared = DragUISessionCoordinator.shared
        DragUISessionCoordinator.shared = nil
        defer { DragUISessionCoordinator.shared = previousShared }
        ClickCensus.resetForTesting()

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        // 不 crash 即通过：mouseDown 到达但无仲裁下游（原 optional-chaining 语义等价）。
        cell.mouseDown(with: makeMouseDownEvent(in: window, at: NSPoint(x: 40, y: 40)))
        XCTAssertGreaterThanOrEqual(ClickCensus.count(ClickCensus.Sink.cellLookupNil), 1,
                                    "shared 与注入均 nil → s11_cell_lookup_nil+1")
        XCTAssertGreaterThanOrEqual(ClickCensus.count(ClickCensus.Sink.cellMouseDownFired), 1,
                                    "s10 恒计数（入口布点与 lookup 结果无关）")
        XCTAssertEqual(ClickCensus.snapshot()[ClickCensus.Sink.cellLookupNil],
                       ClickCensus.count(ClickCensus.Sink.cellLookupNil),
                       "snapshot 与单 sink 计数一致")
    }

    // MARK: - §6 ⑥：漏斗下 drag 仲裁链完整（pointerDown→beginArbitration 未回归）

    func testArbitrationChainIntactThroughFunnel() {
        let (_, coordinator, cell) = makeWiredCellAndCoordinator()
        var clicks: [AppGridCellView] = []
        coordinator.onCellClick = { clicks.append($0) }

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = cell
        let downPoint = cell.convert(NSPoint(x: cell.bounds.midX, y: cell.bounds.midY), to: nil)
        let draggedPoint = NSPoint(x: downPoint.x + 20, y: downPoint.y)   // 20pt ≥ 6 阈值

        cell.mouseDown(with: makeMouseDownEvent(in: window, at: downPoint))
        XCTAssertEqual(coordinator.controller.state, .pressed)
        cell.mouseDragged(with: makeMouseDraggedEvent(in: window, at: draggedPoint))
        XCTAssertEqual(coordinator.controller.state, .dragging, "漏斗内拖过阈值 → dragging")
        XCTAssertTrue(coordinator.visuals.isPreviewVisible)
        cell.mouseUp(with: makeMouseUpEvent(in: window, at: draggedPoint))
        XCTAssertEqual(clicks.count, 0, "拖拽路径不派发点击（仲裁语义未回归）")
    }

    // MARK: - §6 ⑦：folder overlay 命中不被 cell 漏斗劫持

    func testFolderOverlayHitTestNotHijackedByCellFunnel() {
        let loader = GatedIconLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())
        defer { pipeline.shutdown() }
        let overlay = FolderOverlayView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = overlay
        overlay.layoutSubtreeIfNeeded()

        let ids = [makeAppID("fixture.member0"), makeAppID("fixture.member1")]
        let entry = FolderEntry(id: makeFolderID(), title: "Group 1", members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { id in
            id == ids[0] ? "Member0" : "Member1"
        }
        overlay.layoutSubtreeIfNeeded()

        guard let memberCell = overlay.memberCell(at: 0) else {
            XCTFail("no member cell")
            return
        }
        // 成员 cell 区域命中必须仍归 overlay（overlay.hitTest 恒返回 self，先例不受影响）。
        let windowPoint = memberCell.convert(
            NSPoint(x: memberCell.bounds.midX, y: memberCell.bounds.midY), to: nil)
        let hit = overlay.hitTest(windowPoint)
        XCTAssertTrue(hit === overlay, "overlay 命中仍归 overlay（cell 漏斗不劫持成员 cell 区域）")
        XCTAssertFalse(hit is AppGridCellView)
    }
}