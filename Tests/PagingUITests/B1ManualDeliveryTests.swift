// PagingUITests — B1ManualDeliveryTests（T-1F-B10-regression-fix §2.2 B1 生产修复候选测试）
// 覆盖（任务包 §6 验证 + §7 验收「B1 闭环 / env 默认关自证 / 空白+ESC 强制回归」；夹具中性，
// 无真实 app 身份）：
// ① B1 门默认关（env 未设）：cell 命中 → s8d == 1、s18 absent+present 合计 == 1（super
//    sendEvent 完整走完）、s10 == 0（生产死路径复现 = 零行为变更自证）、sE4 == 0；
// ② B1 门开（env = "1"）：leftMouseDown 命中 cell → 手动投递（s10 == 1）+ 记录；
//    leftMouseUp → 投记录视图 .mouseUp + 清记录（up 后再 up/drag 不再投递）；拖拽链投递；
//    空白点击仍走原 s8/s8c 分支；ESC key53 维持原语义 + 清记录；
// ③ 与 E4 探针门互斥声明：两门同开 → B1 优先（sE4 == 0）；仅探针门开 → sE4 == 1（独立可测）；
// ④ 全链（Fixture B，真实 QuitOnBlankClickWindow + 合成 NSEvent + coordinator 全 wiring）：
//    click 闭环 s10/s9b/s6/sA_launch_accepted 全活、连续 5 击无 stuck-.pressed（s13a/s13b
//    配平、s9_leak == 0）、拖拽回归（down→dragged 过阈值→up → commit）、ESC → cancel + 恢复。
//
// 投递观测（AppGridCellView 为 final，禁子类化—冻结树不可触碰）：Fixture A 经
// `cell.dragCoordinator`（public 属性）接线真实 coordinator——裸 cell（无 bindingToken）按下
// 解析失败走既有 fallback 武装（s4c）→ up 经 fallback 分支派发 onCellClick（可断言计数）；
// dragged 过阈值 → fallback 清除 + endSession → 随后 up 落 idle → s5 吞点（可断言）。
// 门控关/记录 nil 走 super 原语义（headless 下 AppKit 不路由到 cell——既有 E4 门控关测试
// 同证）→ 计数零增，与手动投递形成判别对。
//
// env 控制：B1/E4 门控经 `getenv` 每次实读（非 ProcessInfo 字典），setenv/unsetenv 确定性生效；
// tearDown 兜底 unsetenv（跨测试防泄漏）。ClickCensus.resetForTesting() 每测试隔离。
// 零新增 census sink：全部断言复用既有 sink（s8d/s8/s8c/s10/s11/s13a/s13b/s9b/s9_leak/
// s5/s6/sA/sE4/s18 家族 + s4c fallbackArmed）。

import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import AppIconPipeline
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class B1ManualDeliveryTests: XCTestCase {

    override func tearDown() {
        unsetenv("PAGING_CLICK_MANUAL_DELIVERY")
        unsetenv("PAGING_CLICK_PROBE_MANUAL_DELIVERY")
        super.tearDown()
    }

    /// 观察窗闭合计数 = s18 absent + present（super.sendEvent 完整走完恰记一）。
    private func observeWindowClosedCounts() -> Int {
        ClickCensus.count(ClickCensus.Sink.deliveryProbeInternalHitTestAbsent)
            + ClickCensus.count(ClickCensus.Sink.deliveryProbeInternalHitTestPresent)
    }

    private final class ClickCounter {
        var count = 0
    }

    // MARK: - Fixture A（轻量：探针 contentView + 真 cell + per-cell coordinator；sendEvent 行为面）

    /// 夹具：探针 contentView + 真实 cell（与 E4ManualDeliveryTests 同构；中性 fixture）。
    private func makeWindowWithCell() -> (window: QuitOnBlankClickWindow, probe: ClickDeliveryProbeView, cell: AppGridCellView) {
        let probe = ClickDeliveryProbeView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let window = QuitOnBlankClickWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = probe
        let cell = AppGridCellView(frame: NSRect(x: 20, y: 20, width: 80, height: 80))
        probe.addSubview(cell)
        probe.layoutSubtreeIfNeeded()
        return (window, probe, cell)
    }

    /// Fixture A 投递观测 coordinator：裸 cell source 解析失败 → fallback 武装（s4c）；
    /// up 经 fallback 分支派发 onCellClick；dragged 过阈值 → fallback 清除 + endSession。
    /// 不设 shared——cell.dragCoordinator 每 cell 独享。
    private func makeCoordinator(host: NSView, counter: ClickCounter) -> DragUISessionCoordinator {
        let coordinator = DragUISessionCoordinator(host: host)
        coordinator.onCellClick = { [weak counter] _ in counter?.count += 1 }
        return coordinator
    }

    private func mouseEvent(_ type: NSEvent.EventType, at point: NSPoint, in window: NSWindow) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                           timestamp: 0, windowNumber: window.windowNumber, context: nil,
                           eventNumber: 1, clickCount: 1, pressure: 1)!
    }

    private func escapeKeyEvent(in window: NSWindow) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                         timestamp: 0, windowNumber: window.windowNumber, context: nil,
                         characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}",
                         isARepeat: false, keyCode: 53)!
    }

    // MARK: - ① B1 门默认开（转正 2026-09-06）：未设 env = 手动投递生效（生产路径）

    func testB1GateOnByDefaultCellHitDeliversManually() {
        unsetenv("PAGING_CLICK_MANUAL_DELIVERY")
        unsetenv("PAGING_CLICK_PROBE_MANUAL_DELIVERY")
        ClickCensus.resetForTesting()
        let (window, probe, cell) = makeWindowWithCell()
        let counter = ClickCounter()
        let coordinator = makeCoordinator(host: probe, counter: counter)
        cell.dragCoordinator = coordinator
        defer { coordinator.teardown() }

        window.sendEvent(mouseEvent(.leftMouseDown, at: NSPoint(x: 60, y: 60), in: window))

        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowCellPassthrough), 1, "s8d cell 放行")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.cellMouseDownFired), 1,
                       "默认开：手动投递到达命中 cell → s10（转正后生产路径）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.fallbackArmed), 1,
                       "手动 down 到达 cell → coordinator.pointerDown → fallback 武装")
        XCTAssertEqual(observeWindowClosedCounts(), 0,
                       "手动投递后 return：super.sendEvent 未调（观测窗未开 → absent/present 均 0）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.e4ManualDelivery), 0, "探针门不参与")
        XCTAssertEqual(counter.count, 0, "down 不派发 click（up 才派发）")
    }

    func testB1GateValueNonOneBehavesAsOff() {
        XCTAssertEqual(setenv("PAGING_CLICK_MANUAL_DELIVERY", "0", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_MANUAL_DELIVERY") }
        ClickCensus.resetForTesting()
        let (window, probe, cell) = makeWindowWithCell()
        let counter = ClickCounter()
        let coordinator = makeCoordinator(host: probe, counter: counter)
        cell.dragCoordinator = coordinator
        defer { coordinator.teardown() }

        window.sendEvent(mouseEvent(.leftMouseDown, at: NSPoint(x: 60, y: 60), in: window))

        XCTAssertEqual(observeWindowClosedCounts(), 1, "super 原样调用（env=0 非「1」→ 门关）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.cellMouseDownFired), 0, "s10 恒 0")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.fallbackArmed), 0, "coordinator 零参与")
    }

    // MARK: - ② B1 门开：down 手动投递 + 记录；up 投记录视图并清记录；drag 投记录视图

    func testB1GateOnDeliversMouseDownToHitAndRecords() {
        XCTAssertEqual(setenv("PAGING_CLICK_MANUAL_DELIVERY", "1", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_MANUAL_DELIVERY") }
        ClickCensus.resetForTesting()
        let (window, probe, cell) = makeWindowWithCell()
        let counter = ClickCounter()
        let coordinator = makeCoordinator(host: probe, counter: counter)
        cell.dragCoordinator = coordinator
        defer { coordinator.teardown() }

        window.sendEvent(mouseEvent(.leftMouseDown, at: NSPoint(x: 60, y: 60), in: window))

        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowCellPassthrough), 1, "s8d 仍计（放行分支进入）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.cellMouseDownFired), 1,
                       "B1 手动投递到达命中 cell → s10（REPORT §15 A 判定位）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.fallbackArmed), 1,
                       "手动 down 到达 cell → coordinator.pointerDown → fallback 武装（投递记录确认）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.cellLookupNil), 0, "s11 零（coordinator 解析成功）")
        XCTAssertEqual(observeWindowClosedCounts(), 0,
                       "手动投递后 return：super.sendEvent 未调（观测窗未开 → absent/present 均 0）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.e4ManualDelivery), 0, "探针门不参与")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.deliveryProbeManualHitChain(
            chain: "AppGridCellView_\(String(describing: type(of: probe)))")), 1,
            "投递目标 = 窗口手动 hitTest 命中的同一 cell 链")
    }

    func testB1GateOnUpDeliversToRecordedViewThenClears() {
        XCTAssertEqual(setenv("PAGING_CLICK_MANUAL_DELIVERY", "1", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_MANUAL_DELIVERY") }
        ClickCensus.resetForTesting()
        let (window, probe, cell) = makeWindowWithCell()
        let counter = ClickCounter()
        let coordinator = makeCoordinator(host: probe, counter: counter)
        cell.dragCoordinator = coordinator
        defer { coordinator.teardown() }
        let p = NSPoint(x: 60, y: 60)

        window.sendEvent(mouseEvent(.leftMouseDown, at: p, in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.fallbackArmed), 1, "down 已投递（fallback 武装）")

        window.sendEvent(mouseEvent(.leftMouseUp, at: p, in: window))
        XCTAssertEqual(counter.count, 1,
                       "up 投记录视图 → cell.mouseUp → pointerUp fallback 分支 → onCellClick（记录视图接收确认）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.cellMouseDownFired), 1, "down 不再重复")

        // 记录已清：第二次 up 不再手动投递（counter 不增；super 原语义）。
        window.sendEvent(mouseEvent(.leftMouseUp, at: p, in: window))
        XCTAssertEqual(counter.count, 1, "记录清空后 up 不投递")

        // 记录已清：drag 同样不投递。
        window.sendEvent(mouseEvent(.leftMouseDragged, at: NSPoint(x: 100, y: 60), in: window))
        XCTAssertEqual(counter.count, 1, "记录清空后 dragged 不投递")

        // 新一轮 down+up 恢复（记录重建）。
        window.sendEvent(mouseEvent(.leftMouseDown, at: p, in: window))
        window.sendEvent(mouseEvent(.leftMouseUp, at: p, in: window))
        XCTAssertEqual(counter.count, 2, "新一轮闭环恢复")
    }

    func testCompletedFallbackReleaseCannotClearReentrantCaptureEvenOnTheSameCell() {
        for sameCell in [true, false] {
            ClickCensus.resetForTesting()
            let (window, probe, first) = makeWindowWithCell()
            let second = sameCell ? first : AppGridCellView(frame: NSRect(x: 220, y: 20, width: 80, height: 80))
            if !sameCell { probe.addSubview(second) }
            probe.layoutSubtreeIfNeeded()
            let coordinator = DragUISessionCoordinator(host: probe)
            first.dragCoordinator = coordinator; second.dragCoordinator = coordinator
            var recognitionEnabled = true
            coordinator.clickRecognitionSuppressor = { recognitionEnabled = $0 }
            defer { coordinator.teardown() }
            let firstPoint = NSPoint(x: 60, y: 60)
            let secondPoint = sameCell ? firstPoint : NSPoint(x: 260, y: 60)
            var clicked: [ObjectIdentifier] = []
            coordinator.onCellClick = { cell in
                clicked.append(ObjectIdentifier(cell))
                if clicked.count == 1 {
                    window.sendEvent(self.mouseEvent(.leftMouseDown, at: secondPoint, in: window))
                }
            }
            window.sendEvent(mouseEvent(.leftMouseDown, at: firstPoint, in: window))
            window.sendEvent(mouseEvent(.leftMouseUp, at: firstPoint, in: window))
            XCTAssertTrue(coordinator.isSessionActive, "The reentrant press owns the next release")
            window.sendEvent(mouseEvent(.leftMouseUp, at: secondPoint, in: window))
            XCTAssertEqual(clicked, [ObjectIdentifier(first), ObjectIdentifier(second)])
            XCTAssertFalse(coordinator.isSessionActive)
            XCTAssertTrue(recognitionEnabled)
        }
    }

    func testOrdinaryClickCleanupCannotClearReentrantCoordinatorPress() async throws {
        let (fixture, _) = try await mountedB1Fixture()
        defer { teardownFixture(fixture) }
        let page = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0))
        let first = try XCTUnwrap(page.cell(at: 0)), second = try XCTUnwrap(page.cell(at: 1))
        let firstPoint = windowPoint(of: first), secondPoint = windowPoint(of: second)
        var clicked: [ObjectIdentifier] = [], blankClicks = 0
        var recognitionEnabled = true
        let suppressor = fixture.coordinator.clickRecognitionSuppressor
        fixture.coordinator.clickRecognitionSuppressor = { enabled in
            recognitionEnabled = enabled
            suppressor?(enabled)
        }
        fixture.coordinator.onOverlayBlankClick = { blankClicks += 1 }
        fixture.coordinator.onCellClick = { [weak coordinator = fixture.coordinator] cell in
            clicked.append(ObjectIdentifier(cell))
            if clicked.count == 1 {
                coordinator?.pointerDown(locationInWindow: secondPoint, sourceCell: second, memberFolderID: nil)
            }
        }
        fixture.coordinator.pointerDown(locationInWindow: firstPoint, sourceCell: first, memberFolderID: nil)
        fixture.coordinator.pointerUp(locationInWindow: firstPoint)
        XCTAssertEqual(fixture.coordinator.controller.state, .pressed)
        XCTAssertFalse(recognitionEnabled)
        fixture.coordinator.pointerUp(locationInWindow: secondPoint)
        XCTAssertEqual(clicked, [ObjectIdentifier(first), ObjectIdentifier(second)])
        XCTAssertEqual(blankClicks, 0, "A newer cell press must not become an overlay-blank click")
        XCTAssertEqual(fixture.coordinator.controller.state, .idle)
        XCTAssertTrue(recognitionEnabled)
    }

    func testWindowAndCoordinatorKeepReentrantClickCaptureAndRecoverForAnotherClick() async throws {
        let (fixture, window) = try await mountedB1Fixture()
        defer { teardownFixture(fixture) }
        let page = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0))
        let first = try XCTUnwrap(page.cell(at: 0)), other = try XCTUnwrap(page.cell(at: 1))
        let firstPoint = windowPoint(of: first)
        for sameCell in [true, false] {
            let second = sameCell ? first : other
            let secondPoint = windowPoint(of: second)
            var clicked: [ObjectIdentifier] = [], blankClicks = 0
            fixture.coordinator.onOverlayBlankClick = { blankClicks += 1 }
            fixture.coordinator.onCellClick = { cell in
                clicked.append(ObjectIdentifier(cell))
                if clicked.count == 1 {
                    window.sendEvent(self.mouseEvent(.leftMouseDown, at: secondPoint, in: window))
                }
            }
            window.sendEvent(mouseEvent(.leftMouseDown, at: firstPoint, in: window))
            window.sendEvent(mouseEvent(.leftMouseUp, at: firstPoint, in: window))
            XCTAssertEqual(fixture.coordinator.controller.state, .pressed)
            window.sendEvent(mouseEvent(.leftMouseUp, at: secondPoint, in: window))
            XCTAssertEqual(clicked, [ObjectIdentifier(first), ObjectIdentifier(second)])
            XCTAssertEqual(blankClicks, 0)
            XCTAssertFalse(fixture.coordinator.isSessionActive)
            window.sendEvent(mouseEvent(.leftMouseUp, at: secondPoint, in: window))
            XCTAssertEqual(clicked.count, 2, "An unmatched extra release cannot click again")
            window.sendEvent(mouseEvent(.leftMouseDown, at: firstPoint, in: window))
            window.sendEvent(mouseEvent(.leftMouseUp, at: firstPoint, in: window))
            XCTAssertEqual(clicked, [ObjectIdentifier(first), ObjectIdentifier(second), ObjectIdentifier(first)])
            XCTAssertFalse(fixture.coordinator.isSessionActive)
        }
        XCTAssertEqual(fixture.launcher.opened.count, 0, "The callback fixture never launches an application")
    }

    func testIdleCleanupObserverCannotRetargetCompletedClickToItsNewPress() async throws {
        let (fixture, _) = try await mountedB1Fixture()
        defer { teardownFixture(fixture) }
        let page = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0))
        let first = try XCTUnwrap(page.cell(at: 0)), second = try XCTUnwrap(page.cell(at: 1))
        let firstPoint = windowPoint(of: first), secondPoint = windowPoint(of: second)
        var admitted = false, clicked: [ObjectIdentifier] = []
        fixture.coordinator.onSessionStateChange = { [weak coordinator = fixture.coordinator] state in
            guard state == .idle, !admitted else { return }
            admitted = true
            coordinator?.pointerDown(locationInWindow: secondPoint, sourceCell: second, memberFolderID: nil)
        }
        fixture.coordinator.onCellClick = { clicked.append(ObjectIdentifier($0)) }
        fixture.coordinator.pointerDown(locationInWindow: firstPoint, sourceCell: first, memberFolderID: nil)
        fixture.coordinator.pointerUp(locationInWindow: firstPoint)
        XCTAssertTrue(admitted)
        XCTAssertEqual(clicked, [ObjectIdentifier(first)])
        XCTAssertEqual(fixture.coordinator.controller.state, .pressed)
        fixture.coordinator.pointerUp(locationInWindow: secondPoint)
        XCTAssertEqual(clicked, [ObjectIdentifier(first), ObjectIdentifier(second)])
        XCTAssertFalse(fixture.coordinator.isSessionActive)
    }

    func testClickCleanupTeardownRefusesActivation() async throws {
        try await assertCleanupInterruptionRefusesActivation(.teardown)
    }

    func testClickCleanupCancellationRefusesActivation() async throws {
        try await assertCleanupInterruptionRefusesActivation(.cancel)
    }

    func testIdleNoOpCancellationDoesNotRevokeCompletedClick() async throws {
        let (fixture, _) = try await mountedB1Fixture()
        defer { teardownFixture(fixture) }
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let point = windowPoint(of: cell)
        var clicks = 0
        fixture.coordinator.onCellClick = { _ in clicks += 1 }
        fixture.coordinator.onSessionStateChange = { [weak coordinator = fixture.coordinator] state in
            if state == .idle { coordinator?.cancel(reason: .escape) }
        }
        fixture.coordinator.pointerDown(locationInWindow: point, sourceCell: cell, memberFolderID: nil)
        fixture.coordinator.pointerUp(locationInWindow: point)
        XCTAssertEqual(clicks, 1, "Existing idle cancel is a no-op, not cancellation of a completed click")
        XCTAssertFalse(fixture.coordinator.isSessionActive)
    }

    func testClickCleanupTargetReuseRefusesReplacementActivation() async throws {
        try await assertCleanupInterruptionRefusesActivation(.reuse)
    }

    private enum CleanupInterruption { case teardown, cancel, reuse }

    private func assertCleanupInterruptionRefusesActivation(_ interruption: CleanupInterruption) async throws {
        let (fixture, _) = try await mountedB1Fixture()
        defer { teardownFixture(fixture) }
        let page = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0))
        let cell = try XCTUnwrap(page.cell(at: 0)), replacement = try XCTUnwrap(page.cell(at: 1)?.bindingToken)
        let point = windowPoint(of: cell)
        var interrupted = false, clicks = 0, blankClicks = 0
        fixture.coordinator.onCellClick = { _ in clicks += 1 }
        fixture.coordinator.onOverlayBlankClick = { blankClicks += 1 }
        fixture.coordinator.onSessionStateChange = { [weak coordinator = fixture.coordinator, weak cell] state in
            guard state == .idle, !interrupted else { return }
            interrupted = true
            switch interruption {
            case .teardown: coordinator?.teardown()
            case .cancel:
                coordinator?.pointerDown(locationInWindow: point, sourceCell: cell, memberFolderID: nil)
                coordinator?.cancel(reason: .escape)
            case .reuse: cell?.bind(name: "Replacement fixture", token: replacement)
            }
        }
        fixture.coordinator.pointerDown(locationInWindow: point, sourceCell: cell, memberFolderID: nil)
        fixture.coordinator.pointerUp(locationInWindow: point)
        XCTAssertTrue(interrupted)
        XCTAssertEqual(clicks, 0)
        XCTAssertEqual(blankClicks, 0)
        XCTAssertFalse(fixture.coordinator.isSessionActive)
        XCTAssertEqual(fixture.launcher.opened.count, 0)
    }

    func testDuplicateReleaseInsideCompletedFallbackClickIsNotManuallyRedelivered() {
        ClickCensus.resetForTesting()
        let (window, probe, cell) = makeWindowWithCell()
        let coordinator = DragUISessionCoordinator(host: probe)
        cell.dragCoordinator = coordinator
        defer { coordinator.teardown() }
        let point = NSPoint(x: 60, y: 60)
        var clicks = 0
        coordinator.onCellClick = { _ in
            clicks += 1
            if clicks == 1 { window.sendEvent(self.mouseEvent(.leftMouseUp, at: point, in: window)) }
        }
        window.sendEvent(mouseEvent(.leftMouseDown, at: point, in: window))
        window.sendEvent(mouseEvent(.leftMouseUp, at: point, in: window))
        XCTAssertEqual(clicks, 1)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.fallbackDispatch), 1)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.pointerUpIdleSwallow), 0)
        XCTAssertFalse(coordinator.isSessionActive)
    }

    func testB1GateOnDraggedDeliversToRecordedView() {
        XCTAssertEqual(setenv("PAGING_CLICK_MANUAL_DELIVERY", "1", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_MANUAL_DELIVERY") }
        ClickCensus.resetForTesting()
        let (window, probe, cell) = makeWindowWithCell()
        let counter = ClickCounter()
        let coordinator = makeCoordinator(host: probe, counter: counter)
        cell.dragCoordinator = coordinator
        defer { coordinator.teardown() }
        let p = NSPoint(x: 60, y: 60)

        window.sendEvent(mouseEvent(.leftMouseDown, at: p, in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.fallbackArmed), 1, "down 已投递")

        // dragged 手动投递 → pointerDragged：过阈值 → fallback 清除 + endSession（click 候选作废）。
        window.sendEvent(mouseEvent(.leftMouseDragged, at: NSPoint(x: 120, y: 60), in: window))
        XCTAssertEqual(counter.count, 0, "拖拽不派发 click")

        // up 仍投记录视图（记录未清——仅 up 清记录）→ 落 idle → s5 吞点（拖拽链消费确认）。
        window.sendEvent(mouseEvent(.leftMouseUp, at: NSPoint(x: 120, y: 60), in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.pointerUpIdleSwallow), 1,
                       "drag 已投递（fallback 被清除）→ up 落 idle → s5（与「未投递 → 零计数」判别对）")
        XCTAssertEqual(counter.count, 0, "drag+up 全程零 click 派发")
    }

    func testB1InteractionZoneUsesAppKitPassThroughInsteadOfManualCellDelivery() {
        XCTAssertEqual(setenv("PAGING_CLICK_MANUAL_DELIVERY", "1", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_MANUAL_DELIVERY") }
        ClickCensus.resetForTesting()
        let (window, probe, cell) = makeWindowWithCell()
        let field = AppSearchFieldView(frame: NSRect(x: 180, y: 210, width: 160, height: 28))
        probe.addSubview(field)
        let counter = ClickCounter()
        let coordinator = makeCoordinator(host: probe, counter: counter)
        cell.dragCoordinator = coordinator
        defer { coordinator.teardown() }

        window.sendEvent(mouseEvent(.leftMouseDown, at: NSPoint(x: 220, y: 224), in: window))

        XCTAssertTrue(blankClickResolvesToInteractionZone(field))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.cellMouseDownFired), 0,
                       "search interaction zone must not enter B1 cell delivery")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowCellPassthrough), 0,
                       "search interaction zone is handled before cell classification")
        // Headless AppKit may deliver this control event without consulting the probe's
        // internal hitTest path. The production invariant here is that the window does not
        // enter B1 or classify the control as blank; the event is handed to super above.
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowBlankUnclassified), 0,
                       "interaction zone must not enter the blank termination path")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.deliveryProbeManualHitChain(
            chain: "AppSearchFieldView_\(String(describing: type(of: probe)))")), 1,
                       "manual hit testing still identifies the search control before pass-through")
        XCTAssertEqual(counter.count, 0)
    }

    // MARK: - ②-④ 空白点击（门控开）：原 s8/s8c 分支不变；ESC key53：原语义 + 清记录

    func testB1GateOnBlankClickStillTakesBlankTerminatePath() {
        XCTAssertEqual(setenv("PAGING_CLICK_MANUAL_DELIVERY", "1", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_MANUAL_DELIVERY") }
        ClickCensus.resetForTesting()
        let (window, _, _) = makeWindowWithCell()
        final class FlagBox { var terminated = false }
        let flag = FlagBox()
        window.onBlankClick = { flag.terminated = true }

        window.sendEvent(mouseEvent(.leftMouseDown, at: NSPoint(x: 350, y: 250), in: window))

        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowBlankUnclassified), 1, "s8 空白命中")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowBlankTerminate), 1, "s8c 空白退出（门控开仍走原分支）")
        XCTAssertTrue(flag.terminated, "onBlankClick 照常回调")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowCellPassthrough), 0, "非 cell 命中")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.cellMouseDownFired), 0, "s10 不增（空白不投递）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowDragActiveSwallow), 0, "无 drag 吞点参与")
    }

    func testB1GateOnEscapeClearsRecordAndKeepsSuperSemantics() {
        XCTAssertEqual(setenv("PAGING_CLICK_MANUAL_DELIVERY", "1", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_MANUAL_DELIVERY") }
        ClickCensus.resetForTesting()
        let (window, probe, cell) = makeWindowWithCell()
        let counter = ClickCounter()
        let coordinator = makeCoordinator(host: probe, counter: counter)
        cell.dragCoordinator = coordinator
        defer { coordinator.teardown() }
        // 生产同构（AppDelegate.onEscapeDuringDrag）：ESC → cancel + 吞点。
        window.onEscapeDuringDrag = { [weak coordinator] in
            coordinator?.cancel(reason: .escape)
            return true
        }
        let p = NSPoint(x: 60, y: 60)

        window.sendEvent(mouseEvent(.leftMouseDown, at: p, in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.fallbackArmed), 1, "down 已投递")

        window.sendEvent(escapeKeyEvent(in: window))
        // 记录已清：ESC 后 up 不再投递（防 stale；§2.2 B1 ④）。
        window.sendEvent(mouseEvent(.leftMouseUp, at: p, in: window))
        XCTAssertEqual(counter.count, 0, "ESC 打断清记录 → up 不投递（stale 防护生效）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.cellMouseDownFired), 1, "down 不再重复")

        // 新一轮点击恢复（记录重建）。
        window.sendEvent(mouseEvent(.leftMouseDown, at: p, in: window))
        window.sendEvent(mouseEvent(.leftMouseUp, at: p, in: window))
        XCTAssertEqual(counter.count, 1, "ESC 后新一轮 down+up 闭环恢复")
    }

    // MARK: - ③ 两门互斥声明：同开 B1 优先；仅探针门开 = E4 独立可测

    func testB1AndProbeGatesBothOnB1TakesPriority() {
        XCTAssertEqual(setenv("PAGING_CLICK_MANUAL_DELIVERY", "1", 1), 0, "测试 env 设置")
        XCTAssertEqual(setenv("PAGING_CLICK_PROBE_MANUAL_DELIVERY", "1", 1), 0, "测试 env 设置")
        defer {
            unsetenv("PAGING_CLICK_MANUAL_DELIVERY")
            unsetenv("PAGING_CLICK_PROBE_MANUAL_DELIVERY")
        }
        ClickCensus.resetForTesting()
        let (window, probe, cell) = makeWindowWithCell()
        let counter = ClickCounter()
        let coordinator = makeCoordinator(host: probe, counter: counter)
        cell.dragCoordinator = coordinator
        defer { coordinator.teardown() }

        window.sendEvent(mouseEvent(.leftMouseDown, at: NSPoint(x: 60, y: 60), in: window))

        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.cellMouseDownFired), 1, "手动投递发生（B1 优先）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.e4ManualDelivery), 0,
                       "两门同开 → B1 分支先行 return，E4 分支不执行（行为确定）")
        XCTAssertEqual(observeWindowClosedCounts(), 0, "super 未调")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.fallbackArmed), 1, "B1 手动投递路径生效")
    }

    func testProbeGateAloneStillIndependent() {
        XCTAssertEqual(setenv("PAGING_CLICK_PROBE_MANUAL_DELIVERY", "1", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_PROBE_MANUAL_DELIVERY") }
        // B1 转正（2026-09-06）后默认开；本测试验证 E4 门独立可测 → 显式关 B1。
        XCTAssertEqual(setenv("PAGING_CLICK_MANUAL_DELIVERY", "0", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_MANUAL_DELIVERY") }
        ClickCensus.resetForTesting()
        let (window, _, _) = makeWindowWithCell()

        window.sendEvent(mouseEvent(.leftMouseDown, at: NSPoint(x: 60, y: 60), in: window))

        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.e4ManualDelivery), 1, "E4 门独立可测（B1 显式关）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.cellMouseDownFired), 1, "E4 手动投递照旧（s10）")
    }

    // MARK: - Fixture B（全链：真实窗口 + coordinator 全 wiring；B1 闭环验收）

    /// fixture app 持久引用（bundleID = "fixture." + 小写标题；与 FakeAppFactory 同源）。
    private func ref(_ title: String) -> PersistentAppReference {
        PersistentAppReference.bundleID("fixture.\(title.lowercased())")
    }

    /// WorkspaceTopLevelEntry → 中性顶层身份（bundleID 引用 → AppID；folder → FolderID）。
    private func identity(for entry: WorkspaceTopLevelEntry) -> TopLevelEntryIdentity? {
        switch entry {
        case .app(let ref):
            if case .bundleID(let id) = ref { return .app(CatalogFixture.appID(id)) }
            return nil
        case .folder(let id): return .folder(id)
        }
    }

    private var factory: FakeAppFactory!
    private var mountedWindows: [NSWindow] = []

    private final class TerminationBox { var terminated = false }

    override func setUpWithError() throws {
        factory = try FakeAppFactory()
        ClickCensus.resetForTesting()
    }

    override func tearDownWithError() throws {
        factory?.removeRoot()
        factory = nil
        mountedWindows.removeAll()
    }

    /// 全链夹具（复刻 DragCommitIntegrationTests.CommitFixture 装配；B1 只走 topLevel
    /// click/drag 路径：store/持久化腿未建模，onCommit 接呈现刷新 + 提交记录）。
    @MainActor
    private final class CommitFixture {
        let assembly: AppCatalogAssembly
        let surface: PagingSurface
        let keyboard: KeyboardFocusController
        let folderOpenState: FolderOpenState
        let overlay: FolderOverlayView
        let launch: AppLaunchController
        let launcher: RecordingLauncher
        let coordinator: DragUISessionCoordinator
        var sessionLayout: PersistentWorkspaceLayout?
        var commits: [PersistentWorkspaceLayout] = []
        var isTitleEditing = false

        init(assembly: AppCatalogAssembly, surface: PagingSurface,
             keyboard: KeyboardFocusController, folderOpenState: FolderOpenState,
             overlay: FolderOverlayView, launch: AppLaunchController,
             launcher: RecordingLauncher, coordinator: DragUISessionCoordinator) {
            self.assembly = assembly
            self.surface = surface
            self.keyboard = keyboard
            self.folderOpenState = folderOpenState
            self.overlay = overlay
            self.launch = launch
            self.launcher = launcher
            self.coordinator = coordinator
        }

        /// onCommit 呈现刷新（AppDelegate 同构；store 腿未建模）。
        func handleCommit(_ newLayout: PersistentWorkspaceLayout) {
            sessionLayout = newLayout
            commits.append(newLayout)
            let provider = assembly.provider
            let update = provider.applyCommittedLayout(newLayout,
                                                       atCurrentPage: surface.core.committedPage,
                                                       itemsPerPage: surface.itemsPerPage)
            if let update {
                surface.refreshPresentation()
                surface.setPageCount(update.plan.pageCount)
                if let base = provider.servedSnapshot {
                    let layout = AppGridFocusLayout.build(from: base,
                                                          composition: provider.presentationEntries,
                                                          itemsPerPage: surface.itemsPerPage)
                    keyboard.applyLayout(layout)
                }
            }
        }

        /// 拖拽几何（host 坐标系；与 AppDelegate.makeDragGeometry 同构；仅 topLevel 腿）。
        func makeDragGeometry(scope: DragScope) -> DragGeometry? {
            let catalog = assembly.provider.servedSnapshot
            switch scope {
            case .topLevel:
                let page = surface.core.committedPage
                guard let pageView = assembly.renderer.pageView(forPage: page) else { return nil }
                let frames = pageView.dragItemFrames(convertedTo: surface, catalog: catalog)
                return DragGeometry(itemFrames: frames,
                                    containerWidth: Double(surface.bounds.width),
                                    page: page, pageCount: surface.core.pageCount)
            case .folder(let folderID):
                guard folderOpenState.isOpen(folderID) else { return nil }
                let memberFrames = overlay.memberDragItemFrames(convertedTo: surface, catalog: catalog)
                let page = folderOpenState.innerPage
                let pageCount = folderOpenState.innerPageCount
                return DragGeometry(itemFrames: memberFrames, topLevelFrames: memberFrames,
                                    containerWidth: Double(surface.bounds.width),
                                    page: page, pageCount: pageCount)
            }
        }

        /// click 派发（AppDelegate.handleDragCellClick 同构；B1 断言仅 app cell 腿）。
        func handleCellClick(_ cell: AppGridCellView) {
            if cell.isFolderCell { return }
            guard let appID = cell.bindingToken?.appID as? AppID,
                  let served = assembly.provider.servedRevision else { return }
            _ = launch.handleCell(
                AppCatalogAssembly.makeMemberLaunchCell(appID: appID, servedRevision: served))
        }

        /// 当前页某 slot 的 cell 中心（surface 坐标系）。
        func cellCenter(slot: Int) -> NSPoint? {
            guard let pageView = assembly.renderer.pageView(forPage: surface.core.committedPage),
                  let cell = pageView.cell(at: slot) else { return nil }
            let rect = cell.convert(cell.bounds, to: surface)
            return NSPoint(x: rect.midX, y: rect.midY)
        }
    }

    private func makeFixture(appNames: [String] = ["Alpha", "Beta", "Gamma", "Delta", "Echo", "Foxtrot"])
        async throws -> CommitFixture {
        _ = try factory.makeApps(names: appNames)
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        assembly.folderLabEnabled = false
        assembly.folderSnapshotGenerator = { catalog in
            FolderLabFixture.makeGroups(from: catalog, configuration: .init(groupSize: 2, enabled: false))
        }
        wireAssembly(assembly, to: surface)
        assembly.renderer.folderSnapshotProvider = { [weak assembly] in
            assembly?.provider.servedFolderSnapshot
        }
        let folderOpenState = FolderOpenState(membersPerPage: surface.itemsPerPage)
        let keyboard = KeyboardFocusController(columns: 5)
        keyboard.install(on: surface, focusModel: AppGridFocusModel())
        let overlay = FolderOverlayView(iconPipeline: assembly.iconPipeline, displayScale: 2)
        overlay.membersPerPage = folderOpenState.membersPerPage
        keyboard.folderOpenStateProvider = { folderOpenState }
        keyboard.folderOverlayProvider = { overlay }
        let launcher = RecordingLauncher()
        let launch = AppLaunchController(surface: surface, assembly: assembly, launcher: launcher)
        launch.install()
        assembly.begin()
        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        assembly.rebuildFolderCompositionIfNeeded()
        _ = assembly.refreshController.applyPendingAtIdleBoundary(currentPage: 0)

        let coordinator = DragUISessionCoordinator(host: surface)
        let fixture = CommitFixture(assembly: assembly, surface: surface, keyboard: keyboard,
                                    folderOpenState: folderOpenState, overlay: overlay,
                                    launch: launch, launcher: launcher, coordinator: coordinator)
        coordinator.layoutProvider = { [weak fixture] in
            guard let fixture else { return nil }
            if let sessionLayout = fixture.sessionLayout { return sessionLayout }
            return DragUISessionLayoutFactory.makeSessionLayout(
                catalog: fixture.assembly.provider.servedSnapshot,
                entries: fixture.assembly.provider.presentationEntries,
                folderSnapshot: fixture.assembly.provider.servedFolderSnapshot)
        }
        coordinator.catalogGenerationProvider = { [weak fixture] in
            fixture?.assembly.provider.servedRevision ?? 0
        }
        coordinator.catalogSnapshotProvider = { [weak fixture] in
            fixture?.assembly.provider.servedSnapshot
        }
        coordinator.geometryProvider = { [weak fixture] scope in
            fixture?.makeDragGeometry(scope: scope)
        }
        coordinator.onCommit = { [weak fixture] newLayout in
            fixture?.handleCommit(newLayout)
        }
        coordinator.onCellClick = { [weak fixture] cell in
            fixture?.handleCellClick(cell)
        }
        // B1 路径不触发 overlay blank（topLevel click/drag 仅）；onOverlayBlankClick 留默认 no-op。
        coordinator.topLevelPageTurn = { [weak fixture] direction, timestamp in
            guard let fixture else { return .deferred }
            return KeyboardPageTurner(surface: fixture.surface).turn(direction: direction, timestamp: timestamp)
        }
        coordinator.folderPageTurn = { [weak fixture] delta in
            guard let fixture else { return }
            if delta < 0 { fixture.overlay.prevPage() } else { fixture.overlay.nextPage() }
        }
        coordinator.clickRecognitionSuppressor = { [weak surface] enabled in
            guard let surface else { return }
            ClickCensus.hit(enabled ? ClickCensus.Sink.suppressionDisable
                                    : ClickCensus.Sink.suppressionEnable)
            for recognizer in surface.gestureRecognizers where recognizer is NSClickGestureRecognizer {
                recognizer.isEnabled = enabled
            }
        }
        coordinator.dragGate = { [weak fixture] in
            guard let fixture else { return true }
            return !fixture.isTitleEditing
        }
        DragUISessionCoordinator.shared = coordinator
        launch.onLaunchAttempt = { outcome in
            if outcome == .launched {
                ClickCensus.hit(ClickCensus.Sink.launchAccepted)
            } else {
                ClickCensus.hit(ClickCensus.Sink.launchRejectedPrefix + String(describing: outcome))
            }
        }
        return fixture
    }

    /// 把 fixture 的 surface 挂进真实 QuitOnBlankClickWindow + 生产同构窗口 seams
    /// （DragCommitIntegrationTests.mountInQuitWindow 同法；onBlankClick 只置旗标不真退）。
    @discardableResult
    private func mountInQuitWindow(_ fixture: CommitFixture) throws
        -> (window: QuitOnBlankClickWindow, container: NSView, termination: TerminationBox) {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        let window = QuitOnBlankClickWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = container
        fixture.surface.frame = container.bounds
        container.addSubview(fixture.surface)
        // headless 无显示周期，惰性创建的 cell 零 frame → 强制全树布局（只补布局，无行为语义变更）。
        fixture.surface.layoutSubtreeIfNeeded()
        let termination = TerminationBox()
        window.onBlankClickShouldExitSearch = { false }
        window.onBlankClick = { [weak termination] in termination?.terminated = true }
        window.onDragActiveCancel = { [weak fixture] in
            guard let fixture, fixture.coordinator.isSessionActive else { return false }
            fixture.coordinator.cancel(reason: .escape)
            return true
        }
        window.onEscapeDuringDrag = { [weak fixture] in
            guard let fixture, fixture.coordinator.isSessionActive else { return false }
            fixture.coordinator.cancel(reason: .escape)
            return true
        }
        window.folderOpenStateProvider = { [weak fixture] in fixture?.folderOpenState }
        mountedWindows.append(window)
        return (window, container, termination)
    }

    /// 合成 NSEvent（window 基坐标）。
    private func pointerEvent(_ type: NSEvent.EventType, atWindowPoint p: NSPoint,
                              in window: NSWindow) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: p, modifierFlags: [],
                           timestamp: ProcessInfo.processInfo.systemUptime,
                           windowNumber: window.windowNumber, context: nil,
                           eventNumber: 0, clickCount: 1, pressure: 1)!
    }

    /// 真 cell 坐标 → window 基坐标（event.locationInWindow 同基）。
    private func windowPoint(of cell: AppGridCellView) -> NSPoint {
        let rect = cell.convert(cell.bounds, to: nil)
        return NSPoint(x: rect.midX, y: rect.midY)
    }

    private func surfaceLaunchRecognizer(_ surface: PagingSurface) -> NSClickGestureRecognizer? {
        surface.gestureRecognizers
            .first(where: { $0 is NSClickGestureRecognizer }) as? NSClickGestureRecognizer
    }

    /// 门控开 + 挂载 fixture（测试内复用；env 由调用方控制）。
    private func mountedB1Fixture() async throws -> (fixture: CommitFixture, window: QuitOnBlankClickWindow) {
        let fixture = try await makeFixture()
        let (window, _, _) = try mountInQuitWindow(fixture)
        return (fixture, window)
    }

    private func teardownFixture(_ fixture: CommitFixture) {
        DragUISessionCoordinator.shared = nil
        fixture.coordinator.teardown()
        fixture.assembly.teardown()
        fixture.surface.teardown()
    }

    // MARK: - ④ B1 闭环验收（门控开，§15）：click 全链、5 连击无滞留、拖拽回归、ESC 恢复、门关自证

    func testB1GateOnFullClickChainLaunches() async throws {
        XCTAssertEqual(setenv("PAGING_CLICK_MANUAL_DELIVERY", "1", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_MANUAL_DELIVERY") }
        ClickCensus.resetForTesting()
        let (fixture, window) = try await mountedB1Fixture()
        defer { teardownFixture(fixture) }
        let recognizer = try XCTUnwrap(surfaceLaunchRecognizer(fixture.surface))
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let p = windowPoint(of: cell)

        window.sendEvent(pointerEvent(.leftMouseDown, atWindowPoint: p, in: window))
        XCTAssertEqual(fixture.coordinator.controller.state, .pressed, "down → .pressed")
        XCTAssertFalse(recognizer.isEnabled, "仲裁窗口内 Path A 被抑制（beginArbitration → s13a）")

        window.sendEvent(pointerEvent(.leftMouseUp, atWindowPoint: p, in: window))
        XCTAssertEqual(fixture.launcher.opened.count, 1, "点击启动一次")
        XCTAssertEqual(fixture.launch.lastOutcome, .launched, "sA 通路 outcome")
        XCTAssertEqual(fixture.coordinator.controller.state, .idle, "闭环后回到 idle（无 stuck-.pressed）")
        XCTAssertTrue(recognizer.isEnabled, "endSession → Path A 恢复（s13b）")

        // census 全链（复用既有 sink，零新增）。
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.cellMouseDownFired), 1, "s10 增量 = 击数")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.endSessionRestored), 1, "s9b 配平")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.dispatchClickCell), 1, "s6 click 派发")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.launchAccepted), 1, "sA_launch_accepted > 0")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionEnable), 1, "s13a 恰一")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionDisable), 1, "s13b 配平")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.pointerUpIdleSwallow), 0,
                       "s5 健康链零 idle-swallow（健康 click 的 up 落在活动会话）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionResident), 0, "s9_leak 零（无抑制滞留）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.cellLookupNil), 0, "s11 零")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.dragGateClosed), 0, "s1 零（dragGate 未拦截）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.e4ManualDelivery), 0, "探针门不参与")
    }

    func testB1GateOnFiveConsecutiveClicksNoStateStuck() async throws {
        XCTAssertEqual(setenv("PAGING_CLICK_MANUAL_DELIVERY", "1", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_MANUAL_DELIVERY") }
        ClickCensus.resetForTesting()
        let (fixture, window) = try await mountedB1Fixture()
        defer { teardownFixture(fixture) }
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let p = windowPoint(of: cell)

        for _ in 0..<5 {
            window.sendEvent(pointerEvent(.leftMouseDown, atWindowPoint: p, in: window))
            XCTAssertEqual(fixture.coordinator.controller.state, .pressed, "down → pressed")
            window.sendEvent(pointerEvent(.leftMouseUp, atWindowPoint: p, in: window))
            XCTAssertEqual(fixture.coordinator.controller.state, .idle, "up → idle（无 stuck-.pressed）")
        }

        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.cellMouseDownFired), 5, "s10 == 击数")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.dispatchClickCell), 5, "s6 == 击数")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.launchAccepted), 5, "sA == 击数")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.endSessionRestored), 5, "s9b 配平")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionEnable), 5, "s13a 配平")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionDisable), 5, "s13b 配平（无滞留）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionResident), 0, "s9_leak 零")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.pointerUpIdleSwallow), 0, "s5 零（每击闭环内）")
        XCTAssertEqual(fixture.launcher.opened.count, 5, "5 击 5 启动")
    }

    func testB1GateOnDragChainRegression() async throws {
        XCTAssertEqual(setenv("PAGING_CLICK_MANUAL_DELIVERY", "1", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_MANUAL_DELIVERY") }
        ClickCensus.resetForTesting()
        let (fixture, window) = try await mountedB1Fixture()
        defer { teardownFixture(fixture) }
        let center = try XCTUnwrap(fixture.cellCenter(slot: 2))
        // 落点必须落进**其他 slot** 的 drop zone（源 slot 自身 zone 内 drop = noOp 不 commit）：
        // 拖至 +350（x ≈ 850 = 第 4 列）→ 跨 slot 重排 commit。
        let drop = NSPoint(x: center.x + 350, y: center.y)

        window.sendEvent(pointerEvent(.leftMouseDown, atWindowPoint: center, in: window))
        XCTAssertEqual(fixture.coordinator.controller.state, .pressed, "down → pressed")
        window.sendEvent(pointerEvent(.leftMouseDragged,
                                      atWindowPoint: NSPoint(x: center.x + 30, y: center.y), in: window))
        XCTAssertEqual(fixture.coordinator.controller.state, .dragging, "过阈值 → dragging（drag 链活）")
        window.sendEvent(pointerEvent(.leftMouseDragged, atWindowPoint: drop, in: window))
        window.sendEvent(pointerEvent(.leftMouseUp, atWindowPoint: drop, in: window))

        XCTAssertEqual(fixture.coordinator.controller.state, .idle, "commit 后 idle")
        XCTAssertEqual(fixture.commits.count, 1, "真实 pointer 会话（经 sendEvent 手动投递链）→ .committed")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.cellMouseDownFired), 1, "s10 恰一（down 投递）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.dispatchClickCell), 0, "拖拽不派发 click（s6 零）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.launchAccepted), 0, "拖拽不启动（sA 零）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.pointerUpIdleSwallow), 0, "s5 零")
        XCTAssertEqual(fixture.launcher.opened.count, 0, "拖拽零启动")
    }

    func testB1GateOnEscapeDuringDragCancelsThenClickRecovers() async throws {
        XCTAssertEqual(setenv("PAGING_CLICK_MANUAL_DELIVERY", "1", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_MANUAL_DELIVERY") }
        ClickCensus.resetForTesting()
        let (fixture, window) = try await mountedB1Fixture()
        defer { teardownFixture(fixture) }
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let p = windowPoint(of: cell)

        window.sendEvent(pointerEvent(.leftMouseDown, atWindowPoint: p, in: window))
        XCTAssertEqual(fixture.coordinator.controller.state, .pressed, "down → pressed")
        // ESC key53（keyCode 53 + characters "\u{1B}"）。
        let keyEsc = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                      timestamp: ProcessInfo.processInfo.systemUptime,
                                      windowNumber: window.windowNumber, context: nil,
                                      characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}",
                                      isARepeat: false, keyCode: 53)!
        window.sendEvent(keyEsc)
        XCTAssertEqual(fixture.coordinator.controller.state, .idle, "ESC → cancel(.escape) → idle（对照 B-run 双失效态翻转）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.endSessionRestored), 1, "cancel → endSession → s9b 恢复")

        // 恢复：新一轮 down+up 闭环启动（记录已清，无 stale 干扰）。
        window.sendEvent(pointerEvent(.leftMouseDown, atWindowPoint: p, in: window))
        window.sendEvent(pointerEvent(.leftMouseUp, atWindowPoint: p, in: window))
        XCTAssertEqual(fixture.launcher.opened.count, 1, "ESC 后点击恢复启动")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.launchAccepted), 1, "sA > 0（恢复）")
        XCTAssertEqual(fixture.coordinator.controller.state, .idle, "恢复后仍 idle")
    }

    func testB1GateOnByDefaultFullChainLaunches() async throws {
        unsetenv("PAGING_CLICK_MANUAL_DELIVERY")
        unsetenv("PAGING_CLICK_PROBE_MANUAL_DELIVERY")
        ClickCensus.resetForTesting()
        let (fixture, window) = try await mountedB1Fixture()
        defer { teardownFixture(fixture) }
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let p = windowPoint(of: cell)

        window.sendEvent(pointerEvent(.leftMouseDown, atWindowPoint: p, in: window))
        window.sendEvent(pointerEvent(.leftMouseUp, atWindowPoint: p, in: window))

        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowCellPassthrough), 1, "s8d 放行（窗口层判定不变）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.cellMouseDownFired), 1,
                       "默认开：s10 = 1（转正后生产路径；实机证据 /tmp/b10-run1-gated.log）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.dispatchClickCell), 1, "s6 = 1（click 派发）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.launchAccepted), 1, "sA = 1（启动成功）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.e4ManualDelivery), 0, "探针门不参与")
        XCTAssertEqual(fixture.launcher.opened.count, 1, "启动 1 次")
        XCTAssertEqual(fixture.coordinator.controller.state, .idle, "idle 不变")
    }
}
