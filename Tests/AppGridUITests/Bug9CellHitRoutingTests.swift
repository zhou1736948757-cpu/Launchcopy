// AppGridUITests — Bug9CellHitRoutingTests（T-1F-B9-wave-a：BUG9 cell hitTest 漏斗回归）
// 验证（任务包 §6①-⑤ + ⑥⑦漏斗内直测；夹具中性 fixture.*，注入实例 coordinator）：
// - ① icon（±4pt 热区，folder 为 folderSymbol 同框）命中 cell；nameLabel / 格内 padding /
//   cell 外部均不命中（落空点走既有空白路径，不进入启动链）。
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

    /// 窗口 + host + cell（大 frame 偏移，验证 hitTest 的父坐标契约）。
    private func makeWindowWithCell() -> (window: NSWindow, host: NSView, cell: AppGridCellView) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let host = makeHost()
        window.contentView = host
        let cell = makeAppCell("fixtureapp")
        cell.frame = NSRect(x: 240, y: 170, width: 80, height: 80)
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

    // MARK: - §6 ①②③：hitTest 漏斗（icon±4pt 热区命中 cell；label/padding/外部落空）
    //
    // T-1J-LM-HITREVERT：恢复用户验收的 icon±4 启动热区契约（Reviewer r1 M1：整 cell bounds
    // 命中未经授权；D-1J-HIT-REGION-REVERT 决策恢复 icon±4）。nameLabel / 格内 padding 点击
    // 不命中 cell，落空后沿既有空白路径分类。

    func testHitTestAtIconCenterReturnsCell() {
        let (window, _, cell) = makeWindowWithCell()
        // Direct calls use the receiver's superview coordinate space. The large frame
        // origin makes an accidental local-coordinate interpretation fail this assertion.
        let iconCenterInCell = NSPoint(x: cell.iconView.frame.midX, y: cell.iconView.frame.midY)
        let iconCenterInSuperview = cell.convert(iconCenterInCell, to: cell.superview)
        XCTAssertTrue(cell.hitTest(iconCenterInSuperview) === cell,
                      "icon（最大点击靶，NSImageView）中心必须命中 cell 自身")
        // 真实窗口路由面：contentView.hitTest 沿树下探到 cell.hitTest。
        let windowPoint = cell.convert(
            NSPoint(x: cell.iconView.frame.midX, y: cell.iconView.frame.midY), to: nil)
        XCTAssertTrue(window.contentView?.hitTest(windowPoint) === cell,
                      "窗口层 hitTest 在 icon 区域必须路由到 cell（漏斗出口）")
        // ±4 外扩边仍在热区内（icon 外缘 +3pt < +4pt padding → 命中）。
        let paddedEdgeInCell = NSPoint(x: cell.iconView.frame.maxX + 3,
                                       y: cell.iconView.frame.midY)
        let paddedEdgeInSuperview = cell.convert(paddedEdgeInCell, to: cell.superview)
        XCTAssertTrue(cell.hitTest(paddedEdgeInSuperview) === cell,
                      "icon 外扩 4pt 热区内的点必须命中 cell")
    }

    func testHitTestAtNameLabelMissesCell() {
        let (window, _, cell) = makeWindowWithCell()
        let local = NSPoint(x: cell.nameLabel.frame.midX, y: cell.nameLabel.frame.midY)
        let superviewPoint = cell.convert(local, to: cell.superview)
        XCTAssertNil(cell.hitTest(superviewPoint),
                     "名称区域在 icon±4 热区之外，不得命中 cell（落空 → 空白路径）")
        let windowPoint = cell.convert(local, to: nil)
        XCTAssertFalse(window.contentView?.hitTest(windowPoint) === cell,
                       "窗口层 hitTest 在名称区域不得路由到 cell")
    }

    func testHitTestAtCellPaddingMissesCell() {
        let (window, _, cell) = makeWindowWithCell()
        let local = NSPoint(x: 6, y: cell.bounds.maxY - 4)
        let superviewPoint = cell.convert(local, to: cell.superview)
        XCTAssertNil(cell.hitTest(superviewPoint),
                     "格内 padding 在 icon±4 热区之外，不得命中 cell（落空 → 空白路径）")
        let windowPoint = cell.convert(local, to: nil)
        XCTAssertFalse(window.contentView?.hitTest(windowPoint) === cell,
                       "窗口层 hitTest 在格内 padding 不得路由到 cell")
    }

    /// folder cell：热区 = folderSymbolView frame ±4（与 iconView 同 slot）；名称区仍落空。
    func testFolderCellHitTestUsesFolderSymbolFrame() {
        let (window, host, appCell) = makeWindowWithCell()
        appCell.removeFromSuperview()
        let cell = AppGridCellView(frame: NSRect(x: 240, y: 170, width: 80, height: 80))
        cell.bindFolder(title: "fixturefolder", memberCount: 2, token: ItemBindingToken(
            catalogRevision: 1,
            pageIdentity: PagePresentationID(revision: 1, pageIndex: 0),
            itemSlot: 0,
            appID: AnyHashable(makeFolderID()),
            reuseGeneration: 0,
            iconKey: nil,
            surfaceGeneration: 0))
        host.addSubview(cell)
        host.layoutSubtreeIfNeeded()
        cell.layout()
        XCTAssertTrue(cell.isFolderCell)
        XCTAssertTrue(cell.isFolderSymbolVisible, "folder cell 应显示中性符号")

        // folderSymbolView 与 iconView 同 frame（layout 同 slot）；符号区中心命中 cell。
        let symbolCenterInCell = NSPoint(x: cell.iconView.frame.midX, y: cell.iconView.frame.midY)
        XCTAssertTrue(cell.hitTest(cell.convert(symbolCenterInCell, to: cell.superview)) === cell,
                      "folder cell：符号区（±4 热区内）必须命中 cell")
        let windowPoint = cell.convert(symbolCenterInCell, to: nil)
        XCTAssertTrue(window.contentView?.hitTest(windowPoint) === cell,
                      "窗口层 hitTest 在 folder 符号区必须路由到 cell")

        let labelInCell = NSPoint(x: cell.nameLabel.frame.midX, y: cell.nameLabel.frame.midY)
        XCTAssertNil(cell.hitTest(cell.convert(labelInCell, to: cell.superview)),
                     "folder cell：名称区域在 icon±4 热区之外，不得命中")
    }

    func testHitTestOutsideCellMissesCell() {
        let (window, _, cell) = makeWindowWithCell()
        let outside = NSPoint(x: cell.frame.minX - 1, y: cell.frame.midY)
        XCTAssertNil(cell.hitTest(outside), "cell 外部不得命中 cell")
        let windowPoint = cell.convert(NSPoint(x: -1, y: cell.bounds.midY), to: nil)
        XCTAssertFalse(window.contentView?.hitTest(windowPoint) === cell,
                       "窗口层 hitTest 在 cell 外部不得路由到 cell")
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
