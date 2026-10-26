//
//  BlankClickToQuitTests.swift
//  PagingUITests
//
//  T-1C-D repair：blank-vs-cell 命中分类 helper（`blankClickResolvesToCell`）单测。
//  `blankClickResolvesToCell(_:)` 是纯视图逻辑（沿 superview 链判断命中是否含 AppGridCellView），
//  无副作用、不触发手势/启动/退出，可在无头环境下构造 NSView 层次直接验证。
//  注意：真正的「首次实击必退」是 GUI 交互门禁（依赖真实窗口事件分发/全屏过渡），不在单测范围，
//  已标注为手工验收项；本测试只锁定分类正确性（空白→退、cell/icon/label→不误判）。
//

import AppKit
import XCTest
@testable import AppGridUI
@testable import AppIconPipeline
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class BlankClickToQuitTests: XCTestCase {

    /// T-1F-B10-wave-a：overlay 夹具持有的 IconPipeline（防提前释放；tearDown shutdown）。
    private var retainedPipelines: [IconPipeline] = []

    override func tearDown() {
        for pipeline in retainedPipelines { pipeline.shutdown() }
        retainedPipelines.removeAll()
        super.tearDown()
    }

    // MARK: - T-1D：窗口 sendEvent 空白点击路由（需真实 QuitOnBlankClickWindow + 搜索控制器 harness）

    /// 构造一个 QuitOnBlankClickWindow + surface + keyboard + search field/controller 的 harness，
    /// onBlankClickShouldExitSearch 按生产 AppDelegate 接线（搜索激活→退出搜索并返回 true）。
    /// onBlankClick 由各测试自设（捕获本地 terminate 标志）。
    @MainActor
    private func makeClickHarness() -> (window: QuitOnBlankClickWindow, container: NSView, surface: PagingSurface, keyboard: KeyboardFocusController, search: AppSearchController) {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        let window = QuitOnBlankClickWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = container
        let surface = PagingSurface(pageCount: 2, itemsPerPage: 8, initialPage: 0,
                                    reduceMotion: false, labMode: false)
        surface.frameDriver = nil
        surface.frame = container.bounds
        container.addSubview(surface)
        let keyboard = KeyboardFocusController(columns: 5)
        keyboard.install(on: surface, focusModel: AppGridFocusModel())
        let presentation = AppGridSearchPresentationController()
        let search = AppSearchController(presentation: presentation, keyboardController: keyboard, surface: surface)
        container.addSubview(search.field)
        search.install(in: window)
        // 搜索框放顶部居中（远离下方空白测试点）。
        search.field.frame = NSRect(x: 350, y: 660, width: 300, height: 28)
        window.makeFirstResponder(keyboard)
        // 生产 AppDelegate 同构：搜索激活 → 退出搜索并返回 true；未激活 → false（走 terminate）。
        window.onBlankClickShouldExitSearch = { [weak search] in
            guard let search = search, search.isSearchActive else { return false }
            search.exitSearchAndRestoreFocus()
            return true
        }
        return (window, container, surface, keyboard, search)
    }

    private func blankMouseDown(at point: NSPoint) -> NSEvent {
        NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [],
                           timestamp: 0, windowNumber: 0, context: nil,
                           eventNumber: 1, clickCount: 1, pressure: 0)!
    }

    // MARK: - 搜索激活时空白点击 → 退出搜索（不终止）

    func testBlankClickWhileSearchFocusedEmptyQueryExitsAndStaysAlive() {
        let h = makeClickHarness()
        var terminated = false
        h.window.onBlankClick = { terminated = true }
        // canonical：用户点击搜索框（空 query，还没开始搜索）→ field first responder。
        h.window.makeFirstResponder(h.search.field)
        XCTAssertTrue(h.search.isSearchActive, "空 query + field first responder → 搜索激活")
        h.window.sendEvent(blankMouseDown(at: NSPoint(x: 20, y: 20)))
        XCTAssertFalse(h.search.isSearchActive, "空白退出后搜索不再激活")
        XCTAssertTrue(h.window.firstResponder === h.keyboard, "焦点恢复到键盘控制器")
        XCTAssertFalse(terminated, "空白点击被 CONSUME：退出搜索而非终止应用")
    }

    func testBlankClickWhileSearchQueryClearsQueryExitsAndStaysAlive() {
        let h = makeClickHarness()
        var terminated = false
        h.window.onBlankClick = { terminated = true }
        h.search.activateSearch()
        h.search.field.stringValue = "e"
        h.search.field.currentEditor()?.string = "e"
        h.search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: h.search.field))
        XCTAssertTrue(h.search.isSearchActive, "非空 query → 搜索激活")
        h.window.sendEvent(blankMouseDown(at: NSPoint(x: 20, y: 20)))
        XCTAssertFalse(h.search.isSearchActive, "退出后搜索不再激活")
        XCTAssertEqual(h.search.field.stringValue, "", "field 文本被清空")
        XCTAssertTrue(h.search.presentation.currentQuery?.isEmpty == true, "query 被清空")
        XCTAssertTrue(h.window.firstResponder === h.keyboard, "焦点恢复到键盘控制器")
        XCTAssertFalse(terminated, "空白点击被 CONSUME：退出搜索而非终止应用")
    }

    // MARK: - 搜索未激活时空白点击 → 终止（原行为不变）

    func testBlankClickWhileSearchInactiveTerminates() {
        let h = makeClickHarness()
        var terminated = false
        h.window.onBlankClick = { terminated = true }
        XCTAssertFalse(h.search.isSearchActive, "搜索未激活")
        h.window.sendEvent(blankMouseDown(at: NSPoint(x: 20, y: 20)))
        XCTAssertTrue(terminated, "搜索未激活：空白点击 → 终止路径")
        XCTAssertFalse(h.search.isSearchActive)
    }

    // MARK: - 搜索激活时命中 cell → pass-through（不退出、不终止）

    func testCellClickDuringSearchPassesThrough() {
        let h = makeClickHarness()
        var terminated = false
        h.window.onBlankClick = { terminated = true }
        // 真实 cell 挂容器（搜索激活下点击它应 pass-through，不触发退出/不终止）。
        let cell = AppGridCellView(frame: NSRect(x: 100, y: 100, width: 60, height: 60))
        h.container.addSubview(cell)
        h.search.activateSearch()
        XCTAssertTrue(h.search.isSearchActive)
        // 命中 cell → blankClickResolvesToCell true → 跳过空白退出分支 → super 分发。
        XCTAssertTrue(blankClickResolvesToCell(cell), "搜索结果 cell 仍判定为 cell（pass-through 分类）")
        h.window.sendEvent(blankMouseDown(at: NSPoint(x: 130, y: 130)))
        XCTAssertTrue(h.search.isSearchActive, "cell 点击 pass-through：搜索仍激活（未退出）")
        XCTAssertFalse(terminated, "cell 点击不触发终止")
    }

    // MARK: - T-1F-B7-wave-c：drag 激活守卫收口（cell 命中不吞；空白命中才 cancel+吞）

    /// drag 激活（onDragActiveCancel 恒 true）时命中 cell 的 mouseDown 必须**不**评估守卫
    /// （收窄：cell 命中放行 super，secondDrag 归 coordinator 仲裁；修复前任何 leftMouseDown
    /// 只要 session active 即被 cancel+吞掉）。
    func testCellMouseDownDuringActiveDragSessionNotSwallowed() {
        let h = makeClickHarness()
        var cancelCalls = 0
        h.window.onDragActiveCancel = { cancelCalls += 1; return true }
        let cell = AppGridCellView(frame: NSRect(x: 100, y: 100, width: 60, height: 60))
        h.container.addSubview(cell)
        h.window.sendEvent(blankMouseDown(at: NSPoint(x: 130, y: 130)))
        XCTAssertEqual(cancelCalls, 0, "cell 命中不评估 drag cancel（收窄契约）")
    }

    /// drag 激活时**空白** mouseDown → cancel(.escape) + 吞掉（防御保留：不退出、不终止）。
    func testBlankMouseDownDuringActiveDragSessionCancelsAndSwallows() {
        let h = makeClickHarness()
        var terminated = false
        var cancelCalls = 0
        h.window.onBlankClick = { terminated = true }
        h.window.onDragActiveCancel = { cancelCalls += 1; return true }
        h.window.sendEvent(blankMouseDown(at: NSPoint(x: 20, y: 20)))
        XCTAssertEqual(cancelCalls, 1, "空白命中评估 drag cancel")
        XCTAssertFalse(terminated, "空白 + drag 激活 → 吞掉本点击（不退出）")
    }

    /// 构造一个 root（空白背景）+ 挂在其上的真实 cell 层次。
    private func makeHierarchy() -> (root: NSView, cell: AppGridCellView) {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        let cell = AppGridCellView(frame: NSRect(x: 50, y: 50, width: 60, height: 60))
        root.addSubview(cell)
        return (root, cell)
    }

    // MARK: - 空白背景应退出（分类为非 cell）

    func testBlankRootIsNotCell() {
        let (root, _) = makeHierarchy()
        XCTAssertFalse(blankClickResolvesToCell(root), "空白根视图不应判定为 cell")
    }

    func testBlankNilIsNotCell() {
        XCTAssertFalse(blankClickResolvesToCell(nil), "nil hit（未命中）应视为空白背景，走退出")
    }

    func testUnrelatedNestedViewIsNotCell() {
        let outer = NSView(frame: .zero)
        let inner = NSView(frame: .zero)
        outer.addSubview(inner)
        XCTAssertFalse(blankClickResolvesToCell(inner), "与 cell 无关的嵌套视图不应判定为 cell")
    }

    // MARK: - 命中 cell（或其子视图）应放行启动（分类为 cell，不退出）

    func testCellItselfIsCell() {
        let (_, cell) = makeHierarchy()
        XCTAssertTrue(blankClickResolvesToCell(cell), "命中 AppGridCellView 本身应判定为 cell，不退出")
    }

    func testCellIconSubviewIsCell() {
        let (_, cell) = makeHierarchy()
        XCTAssertTrue(blankClickResolvesToCell(cell.iconView),
                      "点击 cell 内图标子视图应沿 superview 链判为 cell，不误判为空退出")
    }

    func testCellNameLabelSubviewIsCell() {
        let (_, cell) = makeHierarchy()
        XCTAssertTrue(blankClickResolvesToCell(cell.nameLabel),
                      "点击 cell 内名称标签子视图应沿 superview 链判为 cell，不误判为空退出")
    }

    /// icon±4 契约（T-1J-LM-HITREVERT 恢复）：cell 内的 nameLabel / padding 点击点不命中
    /// 启动热区 —— 窗口层分类落空，沿既有空白路径处理（不误判为 cell 放行）。
    func testCellInteriorNonIconPointsClassifyAsBlank() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        let cell = AppGridCellView(frame: NSRect(x: 50, y: 50, width: 88, height: 88))
        root.addSubview(cell)
        cell.layout()

        // 对照：图标中心点仍判为 cell（icon±4 热区内 → pass-through 分类）。
        let iconInRoot = cell.convert(
            NSPoint(x: cell.iconView.frame.midX, y: cell.iconView.frame.midY), to: root)
        XCTAssertTrue(blankClickResolvesToCell(root.hitTest(iconInRoot), at: iconInRoot, in: root),
                      "icon±4 内点击 → cell 分类（不退出）")

        // nameLabel 中点：cell.hitTest 落空 → 命中链无 cell → 空白分类。
        let labelInRoot = cell.convert(
            NSPoint(x: cell.nameLabel.frame.midX, y: cell.nameLabel.frame.midY), to: root)
        XCTAssertFalse(blankClickResolvesToCell(root.hitTest(labelInRoot), at: labelInRoot, in: root),
                       "nameLabel 点击在 icon±4 之外 → 空白路径（不误判为 cell）")
        // 点级门禁复核：即便 hit 误传为 cell，acceptsLaunchHit 仍把非热区点判为空白。
        XCTAssertFalse(blankClickResolvesToCell(cell, at: labelInRoot, in: root),
                       "hit=cell 但点在 icon±4 热区外 → 点级门禁判空白")

        // 格内 padding（cell 左上内角）：同样落空 → 空白分类。
        let paddingInRoot = cell.convert(NSPoint(x: 4, y: cell.bounds.maxY - 4), to: root)
        XCTAssertFalse(blankClickResolvesToCell(root.hitTest(paddingInRoot), at: paddingInRoot, in: root),
                       "格内 padding 点击在 icon±4 之外 → 空白路径")
    }

    func testNestedCellDescendantResolvesToOwningCell() {
        let (_, cell) = makeHierarchy()
        let nestedView = NSView(frame: .zero)
        cell.iconView.addSubview(nestedView)

        XCTAssertTrue(appGridCellAncestor(cell) === cell)
        XCTAssertTrue(appGridCellAncestor(cell.iconView) === cell)
        XCTAssertTrue(appGridCellAncestor(nestedView) === cell,
                      "B1 must deliver to the owning cell, not an arbitrary descendant")
        XCTAssertNil(appGridCellAncestor(NSView(frame: .zero)))
    }

    func testInteractionZoneClassificationIsSeparateFromCellResolution() {
        let field = AppSearchFieldView(frame: NSRect(x: 0, y: 0, width: 200, height: 28))
        let fieldSubview = NSView(frame: .zero)
        field.addSubview(fieldSubview)

        XCTAssertTrue(blankClickResolvesToInteractionZone(field))
        XCTAssertTrue(blankClickResolvesToInteractionZone(fieldSubview))
        XCTAssertFalse(blankClickResolvesToInteractionZone(NSView(frame: .zero)))
        XCTAssertNil(appGridCellAncestor(fieldSubview))
    }

    // MARK: - T-1D-E：搜索 field/editor/clear button 是 interaction zone（不退出）

    func testSearchFieldItselfIsInteractionZone() {
        let field = AppSearchFieldView(frame: NSRect(x: 0, y: 0, width: 200, height: 28))
        XCTAssertTrue(blankClickResolvesToCell(field),
                      "点击搜索 field 本身应判为 interaction zone，不触发空白退出")
    }

    func testSearchFieldSubviewIsInteractionZone() {
        let field = AppSearchFieldView(frame: NSRect(x: 0, y: 0, width: 200, height: 28))
        // 任意子视图（clear button 等）沿 superview 链 → interaction zone。
        let subview = NSView(frame: .zero)
        field.addSubview(subview)
        XCTAssertTrue(blankClickResolvesToCell(subview),
                      "点击 field 子视图应沿 superview 链判为 interaction zone，不触发空白退出")
    }

    func testSearchFieldInHierarchyIsInteractionZone() {
        // field 挂在容器中（生产 overlay 布局）→ 点击 field 仍判为 interaction zone。
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        let field = AppSearchFieldView(frame: NSRect(x: 50, y: 300, width: 200, height: 28))
        root.addSubview(field)
        XCTAssertTrue(blankClickResolvesToCell(field),
                      "容器中的搜索 field 应判为 interaction zone，不触发空白退出")
    }

    // MARK: - T-1F-B10-wave-a：s17 命中链 overlay 布尔位（仅计数；分类行为零变化）

    /// 夹具：root → overlay（FolderOverlayView）→ cell。
    /// 命中链 = [cell, overlay, root]；blankClickResolvesToCell 返回 true 且
    /// 链含 overlay → _ov1 位（成员 cell 在打开层内；窗口层判 cell 放行 super 的判别位）。
    private func makeOverlayHierarchy() -> (root: NSView, overlay: FolderOverlayView, cell: AppGridCellView) {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        retainedPipelines.append(pipeline)
        let overlay = FolderOverlayView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
        overlay.frame = NSRect(x: 0, y: 0, width: 400, height: 400)
        root.addSubview(overlay)
        let cell = AppGridCellView(frame: NSRect(x: 50, y: 50, width: 60, height: 60))
        overlay.addSubview(cell)
        return (root, overlay, cell)
    }

    func testCellInsideOverlayMarkedOv1() {
        ClickCensus.resetForTesting()
        let (_, _, cell) = makeOverlayHierarchy()
        XCTAssertTrue(blankClickResolvesToCell(cell), "overlay 内成员 cell 仍判为 cell（分类不变）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.blankHitChainHasOverlay(hasOverlay: true)), 1,
                       "命中链含 overlay → _ov1")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.blankHitChainHasOverlay(hasOverlay: false)), 0)
    }

    func testGridCellOutsideOverlayMarkedOv0() {
        ClickCensus.resetForTesting()
        let (root, _) = makeHierarchy()
        let cell = AppGridCellView(frame: NSRect(x: 50, y: 50, width: 60, height: 60))
        root.addSubview(cell)
        XCTAssertTrue(blankClickResolvesToCell(cell), "grid 内 cell 仍判为 cell（分类不变）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.blankHitChainHasOverlay(hasOverlay: false)), 1,
                       "命中链不含 overlay → _ov0")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.blankHitChainHasOverlay(hasOverlay: true)), 0)
    }

    func testIconSubviewInsideOverlayMarkedOv1() {
        ClickCensus.resetForTesting()
        let (_, _, cell) = makeOverlayHierarchy()
        XCTAssertTrue(blankClickResolvesToCell(cell.iconView),
                      "overlay 内成员 cell 的图标子视图仍判为 cell（分类不变）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.blankHitChainHasOverlay(hasOverlay: true)), 1)
    }

    func testS17SinkNamesCarryOverlayBits() {
        XCTAssertEqual(ClickCensus.Sink.blankHitChainHasOverlayBase, "s17_blankhit_chain_has_overlay")
        XCTAssertEqual(ClickCensus.Sink.blankHitChainHasOverlay(hasOverlay: true), "s17_blankhit_chain_has_overlay_ov1")
        XCTAssertEqual(ClickCensus.Sink.blankHitChainHasOverlay(hasOverlay: false), "s17_blankhit_chain_has_overlay_ov0")
    }
    func testNativeTitleBarMouseDownDoesNotDismissOrExitSearch() {
        let h = makeClickHarness()
        var dismissals = 0
        var searchExits = 0
        h.window.onBlankClick = { dismissals += 1 }
        h.window.onBlankClickShouldExitSearch = { searchExits += 1; return true }
        let titlePoint = NSPoint(x: h.window.contentLayoutRect.midX,
                                y: h.window.contentLayoutRect.maxY + 8)
        h.window.sendEvent(blankMouseDown(at: titlePoint))
        XCTAssertEqual(dismissals, 0)
        XCTAssertEqual(searchExits, 0, "Native title-bar dragging must bypass launcher blank-click handling")
    }

}
