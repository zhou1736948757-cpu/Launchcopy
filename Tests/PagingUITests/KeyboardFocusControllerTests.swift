// PagingUITests — KeyboardFocusControllerTests（Phase 1C §7.2 AppKit responder / 页面表面接线）
// 实现：T-1C-B（Worker B）。
//
// 验证：first responder；方向键路由到焦点模型；未支持按键不吞掉；激活回调；
// 跨页焦点视觉不落旧 page host；teardown 后零 UI 写回；resize 后焦点仍映射到正确 cell。

import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import AppIconPipeline
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class KeyboardFocusControllerTests: XCTestCase {

    private var factory: FakeAppFactory!
    private var surface: PagingSurface!
    private var assembly: AppCatalogAssembly!
    private var controller: KeyboardFocusController!

    override func setUpWithError() throws {
        factory = try FakeAppFactory()
        surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        wireAssembly(assembly, to: surface)
    }

    override func tearDownWithError() throws {
        controller = nil
        assembly?.teardown()
        assembly = nil
        surface?.teardown()
        surface = nil
        factory?.removeRoot()
        factory = nil
    }

    private func readyController(apps: [String]) async throws -> KeyboardFocusController {
        _ = try factory.makeApps(names: apps)
        assembly.begin()
        let committed = await waitUntil { self.assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        let snapshot = try XCTUnwrap(assembly.provider.servedSnapshot)
        let layout = AppGridFocusLayout.build(from: snapshot, itemsPerPage: surface.itemsPerPage)
        var focusModel = AppGridFocusModel()
        focusModel.apply(layout: layout)
        let controller = KeyboardFocusController(columns: 5)
        controller.install(on: surface, focusModel: focusModel)
        self.controller = controller
        return controller
    }

    private func keyEvent(_ keyCode: UInt16) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                         timestamp: 0, windowNumber: 0, context: nil,
                         characters: "", charactersIgnoringModifiers: "",
                         isARepeat: false, keyCode: keyCode)!
    }

    private func rightArrow() -> NSEvent { keyEvent(124) }
    private func leftArrow() -> NSEvent { keyEvent(123) }
    private func returnKey() -> NSEvent { keyEvent(36) }
    /// T-1C-D：ESC（keyCode 53）→ 退出键盘选择。
    private func escapeKey() -> NSEvent { keyEvent(53) }

    /// T-1C-D：延迟焦点（deferred）测试台——空 focusModel 安装（install 不自动播种 → current == nil）。
    private func readyDeferredController(apps: [String]) async throws -> KeyboardFocusController {
        _ = try factory.makeApps(names: apps)
        assembly.begin()
        let committed = await waitUntil { self.assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        let controller = KeyboardFocusController(columns: 5)
        controller.install(on: surface, focusModel: AppGridFocusModel())
        self.controller = controller
        return controller
    }

    // MARK: - first responder

    func testAcceptsFirstResponder() async throws {
        let controller = try await readyController(apps: ["Alpha", "Beta"])
        XCTAssertTrue(controller.acceptsFirstResponder)
        XCTAssertTrue(controller.becomeFirstResponder())
    }

    // MARK: - 方向键路由到焦点模型

    func testArrowKeyMovesFocus() async throws {
        let controller = try await readyController(apps: ["Alpha", "Beta", "Gamma"])
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 0)
        controller.keyDown(with: rightArrow())
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 1)
        controller.keyDown(with: leftArrow())
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 0)
    }

    // MARK: - 未支持按键不吞掉

    func testUnsupportedKeyFallsThrough() async throws {
        let controller = try await readyController(apps: ["Alpha", "Beta"])
        var activated = false
        controller.onActivate = { _ in activated = true }
        let before = controller.focusModel.current
        // 未支持按键（keyCode 0 = 'a'）→ 不改变焦点、不触发激活。
        controller.keyDown(with: keyEvent(0))
        XCTAssertEqual(controller.focusModel.current, before)
        XCTAssertFalse(activated)
    }

    func testPerformKeyEquivalentFallsThrough() async throws {
        let controller = try await readyController(apps: ["Alpha", "Beta"])
        // 未支持按键的 performKeyEquivalent → false（fall through）。
        XCTAssertFalse(controller.performKeyEquivalent(with: keyEvent(0)))
    }

    // MARK: - 激活回调

    func testActivationCallsOnActivate() async throws {
        let controller = try await readyController(apps: ["Alpha", "Beta"])
        var activated: AppGridFocusIdentity?
        controller.onActivate = { activated = $0 }
        controller.keyDown(with: returnKey())
        XCTAssertEqual(activated, controller.focusModel.current)
    }

    // MARK: - 跨页焦点视觉不落旧 page host

    func testCrossPageFocusVisualLandsOnNewPage() async throws {
        let apps = (0..<40).map { String(format: "App%02d", $0) }
        let controller = try await readyController(apps: apps)
        // 打字机语义：走到 page 0 末位（slot 34，末行末）再跨页。
        for _ in 0..<34 {
            controller.keyDown(with: rightArrow())
        }
        XCTAssertEqual(controller.focusModel.current?.pageIndex, 0)
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 34)
        // 右移 → 跨页到 page 1, slot 0（下一页首格）。
        controller.keyDown(with: rightArrow())
        XCTAssertEqual(controller.focusModel.current?.pageIndex, 1)
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 0)
        // settle 完成 + 重应用焦点视觉。
        settleFrames(surface)
        controller.refreshFocusVisual()
        // 旧 page host 的 cell 不聚焦；新 page host 的 cell 聚焦。
        let oldCell = assembly.renderer.pageView(forPage: 0)?.cell(at: 34)
        let newCell = assembly.renderer.pageView(forPage: 1)?.cell(at: 0)
        XCTAssertEqual(oldCell?.isFocused, false, "焦点视觉不得落在旧 page host")
        XCTAssertEqual(newCell?.isFocused, true, "焦点视觉应落在新 page host")
    }

    // MARK: - teardown 后零 UI 写回

    func testTeardownZeroUIWriteback() async throws {
        let controller = try await readyController(apps: ["Alpha", "Beta"])
        surface.teardown()
        let before = controller.focusModel.current
        // teardown 后按键 → 不崩溃、不改变焦点。
        controller.keyDown(with: rightArrow())
        XCTAssertEqual(controller.focusModel.current, before)
        // teardown 后 refreshFocusVisual → 不崩溃、零 UI 写回。
        controller.refreshFocusVisual()
        XCTAssertTrue(surface.isTearingDown)
    }

    // MARK: - resize 后焦点仍映射到正确 cell

    func testResizeFocusStillMapsToCorrectCell() async throws {
        let controller = try await readyController(apps: ["Alpha", "Beta", "Gamma"])
        // 聚焦 page 0, slot 1。
        controller.keyDown(with: rightArrow())
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 1)
        // resize。
        surface.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        surface.layout()
        controller.refreshFocusVisual()
        let cell = assembly.renderer.pageView(forPage: 0)?.cell(at: 1)
        XCTAssertEqual(cell?.isFocused, true, "resize 后焦点仍映射到正确 cell")
    }

    // MARK: - F1（T-1C-C repair）：键盘跨页 settle 完成/中断 → 焦点调和到 committed/displayed 页

    /// 把当前 surface.onIdleBoundary 叠加为"先执行既有处理，再调和键盘跨页 settle"（F1 生产接线同构）。
    private func overlaySettleReconcile() {
        let prev = surface.onIdleBoundary
        surface.onIdleBoundary = { [weak controller, weak surface] in
            prev?()
            guard let controller, let surface else { return }
            controller.reconcileSettledCrossPage(committedPage: surface.core.committedPage)
        }
    }

    func testCrossPageSettleReconcilesFocusToCommittedPage() async throws {
        let apps = (0..<40).map { String(format: "App%02d", $0) }
        let controller = try await readyController(apps: apps)
        overlaySettleReconcile()
        // 打字机语义：走到 page 0 末位（slot 34）再跨页。
        for _ in 0..<34 {
            controller.keyDown(with: rightArrow())
        }
        XCTAssertEqual(controller.focusModel.current?.pageIndex, 0)
        // 右移 → 键盘跨页到 page 1, slot 0（settle 尚未 commit，焦点已立即指向 page 1）。
        controller.keyDown(with: rightArrow())
        XCTAssertEqual(controller.focusModel.current?.pageIndex, 1)
        // settle 完成 → Core 回 idle → 调和焦点到 committed/displayed 页。
        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 1)
        XCTAssertEqual(controller.focusModel.current?.pageIndex, surface.core.committedPage,
                       "焦点须指向已提交/已显示页")
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 0)
        // 焦点视觉落在新 page host；旧 page host 不聚焦。
        let oldCell = assembly.renderer.pageView(forPage: 0)?.cell(at: 34)
        let newCell = assembly.renderer.pageView(forPage: 1)?.cell(at: 0)
        XCTAssertEqual(oldCell?.isFocused, false, "焦点视觉不得落在旧 page host")
        XCTAssertEqual(newCell?.isFocused, true, "焦点视觉应落在新 page host")
    }

    func testInterruptedCrossPageSettleReclampsFocusToCommittedPage() async throws {
        let apps = (0..<40).map { String(format: "App%02d", $0) }
        let controller = try await readyController(apps: apps)
        overlaySettleReconcile()
        for _ in 0..<34 {
            controller.keyDown(with: rightArrow())
        }
        XCTAssertEqual(controller.focusModel.current?.pageIndex, 0)
        // 键盘跨页 → 焦点立即指向 page 1（尚未 commit，仅 settle 进行中）。
        controller.keyDown(with: rightArrow())
        XCTAssertEqual(controller.focusModel.current?.pageIndex, 1)
        // settle 推进中被触控板强势回退接管 → 中断，最终 committed/displayed 回到 page 0。
        gestureBegan(surface, at: 3.0)
        gestureChanged(surface, deltaX: -600, at: 3.05)
        gestureEnded(surface, at: 3.05)
        finishPendingGesture(surface, at: 3.05)
        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 0, "触控板接管后 committed 回到 page 0")
        // F1 调和后焦点绝不指向未显示页（stale 的 page 1 被重新落定到实际 committed page 0）。
        XCTAssertEqual(controller.focusModel.current?.pageIndex, surface.core.committedPage,
                       "焦点不得残留到未显示页")
        let cell = assembly.renderer.pageView(forPage: 0)?.cell(at: 0)
        XCTAssertEqual(cell?.isFocused, true, "焦点视觉应落在实际 committed page 的首个有效 cell")
    }

    // MARK: - T-1C-D（用户实测反馈 5 项 UX 调整）

    /// bug-1：← 跨页 settle 后焦点须保留上一页末位落点（打字机语义下 = 页末格，即末行末位；
    /// 回归：不得被钳制到页内首 cell）。
    func testCrossPageLeftSettlePreservesRowEndLanding() async throws {
        let apps = (0..<40).map { String(format: "App%02d", $0) }
        let controller = try await readyController(apps: apps)
        overlaySettleReconcile()
        // 打字机语义：走到 page 0 末位（slot 34，末行末位）。
        for _ in 0..<34 {
            controller.keyDown(with: rightArrow())
        }
        XCTAssertEqual(controller.focusModel.current?.pageIndex, 0)
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 34)
        // 右移 → 键盘跨页到 page 1, slot 0（下一页首格）。
        controller.keyDown(with: rightArrow())
        XCTAssertEqual(controller.focusModel.current?.pageIndex, 1)
        // 等 page 1 commit 并调和（确认留在 page 1）。
        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 1)
        // 左移 → 键盘跨页回 page 0：打字机语义落页末格 slot 34。
        controller.keyDown(with: leftArrow())
        XCTAssertEqual(controller.focusModel.current?.pageIndex, 0)
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 34)
        // 等 page 0 commit 并调和（reconcile 运行于此 idle 边界）。
        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 0)
        // bug-1 回归断言：← 跨页 settle 后须保留页末落点（reconcile 不得钳制到 slot 0）。
        XCTAssertEqual(controller.focusModel.current?.pageIndex, 0)
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 34,
                       "bug-1：← 跨页 settle 后须保留上一页末位落点")
        let cell = assembly.renderer.pageView(forPage: 0)?.cell(at: 34)
        XCTAssertEqual(cell?.isFocused, true, "焦点视觉应落在 page 0 末位 cell")
        let oldCell = assembly.renderer.pageView(forPage: 1)?.cell(at: 0)
        XCTAssertEqual(oldCell?.isFocused, false, "旧 page host 不聚焦")
    }

    /// deferred：install 空 focusModel 后 current == nil（无框）；首次方向键播种到当前
    /// committed 页 slot 0（不移动）；再按右移 → slot 1。
    func testDeferredFocusNoBoxUntilFirstArrow() async throws {
        let apps = (0..<40).map { String(format: "App%02d", $0) }
        let controller = try await readyDeferredController(apps: apps)
        XCTAssertEqual(surface.core.committedPage, 0)
        // 进入后无焦点框。
        XCTAssertNil(controller.focusModel.current, "deferred：进入后不显示焦点框")
        // 首次方向键播种到当前 committed 页 slot 0（仅显示，不移动）。
        controller.keyDown(with: rightArrow())
        XCTAssertEqual(controller.focusModel.current?.pageIndex, surface.core.committedPage,
                       "deferred：播种到当前 committed 页")
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 0)
        // 再按右移 → slot 1。
        controller.keyDown(with: rightArrow())
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 1)
    }

    /// ESC：选择后按 ESC → current == nil（清除选择框）；再按方向键重新播种 slot 0。
    func testEscClearsFocusAndReseedsOnNextArrow() async throws {
        let controller = try await readyController(apps: ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta"])
        // readyController 预置焦点 → 有框。
        XCTAssertNotNil(controller.focusModel.current)
        // 右移选择一个 cell（→ slot 1）。
        controller.keyDown(with: rightArrow())
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 1)
        // 记录 ESC 前聚焦的 cell 引用（slot 1）。
        let selectedCell = assembly.renderer.pageView(forPage: 0)?.cell(at: 1)
        XCTAssertEqual(selectedCell?.isFocused, true, "ESC 前该 cell 处于聚焦态")
        // ESC → 清除焦点框。
        controller.keyDown(with: escapeKey())
        XCTAssertNil(controller.focusModel.current, "ESC 清除焦点框")
        // 视觉清除：ESC 后旧 cell 的焦点框须真正消失（isFocused == false）。
        XCTAssertEqual(selectedCell?.isFocused, false, "ESC 后旧 cell 焦点视觉清除")
        // 再按方向键重新播种 slot 0。
        controller.keyDown(with: rightArrow())
        XCTAssertEqual(controller.focusModel.current?.slotIndex, 0,
                       "ESC 后方向键重新播种到当前 committed 页首格")
    }
}
