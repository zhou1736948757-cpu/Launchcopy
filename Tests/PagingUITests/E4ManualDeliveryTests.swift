// PagingUITests — E4ManualDeliveryTests（T-1F-B10-regression-fix §2.1 第 4 项 E4 门控测试）
// 覆盖（任务包 §6 验证 + §7 验收「E4 env 默认关自证 / 门控开时手动投递路径断言」；夹具中性，
// 无真实 app 身份）：
// ① env 未设（默认关）：cell 命中 → s8d == 1、s18 absent+present 合计 == 1（super.sendEvent
//   完整走完、观测窗闭合）= 生产路径逐字不变（零行为变更）；E4 sink == 0（门控分支不进）；
// ② env = "1"（门控开）：E4 sink == 1 且 s10 == 1（手动 hit?.mouseDown 到达同一 cell，
//   s10 布点联动断言）且 s18 absent+present == 0（手动投递后 return，super 未调）；
// ③ env = "0"（非 "1"）：同默认关（门控判断严格等于 "1"）；
// ④ sE4 sink 名中性断言（无窗口号码/身份/标题/坐标原文）。
//
// env 控制：E4 门控经 `getenv` 每次实读（非 ProcessInfo 字典，避免进程级缓存歧义），
// setenv/unsetenv 确定性生效；tearDown 兜底 unsetenv（跨测试防泄漏）。
// ClickCensus.resetForTesting() 每测试隔离。

import AppKit
import XCTest
@testable import AppGridUI
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class E4ManualDeliveryTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // B1 转正（2026-09-06）后默认开；E4 探针门测试需显式关 B1 才能测 E4 分支（B1 优先）。
        XCTAssertEqual(setenv("PAGING_CLICK_MANUAL_DELIVERY", "0", 1), 0, "测试 env 设置")
    }

    override func tearDown() {
        unsetenv("PAGING_CLICK_PROBE_MANUAL_DELIVERY")
        unsetenv("PAGING_CLICK_MANUAL_DELIVERY")
        super.tearDown()
    }

    /// 夹具：探针 contentView + 真实 cell（与 ClickDeliveryProbeTests 同构；中性 fixture）。
    private func makeWindowWithCell() -> (window: QuitOnBlankClickWindow, probe: ClickDeliveryProbeView, cell: AppGridCellView) {
        let probe = ClickDeliveryProbeView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let window = QuitOnBlankClickWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = probe
        let cell = AppGridCellView(frame: NSRect(x: 20, y: 20, width: 80, height: 80))
        probe.addSubview(cell)
        probe.layoutSubtreeIfNeeded()
        window.onBlankClick = { }
        return (window, probe, cell)
    }

    private func mouseDown(at point: NSPoint, in window: NSWindow) -> NSEvent {
        NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [],
                           timestamp: 0, windowNumber: window.windowNumber, context: nil,
                           eventNumber: 1, clickCount: 1, pressure: 1)!
    }

    /// cell 在探针（contentView）内的类名链（中性：仅 type(of:) 类名；同 ClickDeliveryProbeTests）。
    private func cellChain(in probe: ClickDeliveryProbeView) -> String {
        "AppGridCellView_\(String(describing: type(of: probe)))"
    }

    private func observeWindowClosedCounts() -> Int {
        ClickCensus.count(ClickCensus.Sink.deliveryProbeInternalHitTestAbsent)
            + ClickCensus.count(ClickCensus.Sink.deliveryProbeInternalHitTestPresent)
    }

    // MARK: - ① env 未设（默认关）：门控分支不进、super 原样调用（零行为变更自证）

    func testGateOffByDefaultCellHitTakesUnchangedSuperPath() {
        unsetenv("PAGING_CLICK_PROBE_MANUAL_DELIVERY")
        ClickCensus.resetForTesting()
        let (window, probe, _) = makeWindowWithCell()

        window.sendEvent(mouseDown(at: NSPoint(x: 60, y: 60), in: window))

        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowCellPassthrough), 1, "s8d cell 放行")
        XCTAssertEqual(observeWindowClosedCounts(), 1,
                       "super.sendEvent 完整走完（absent/present 记账恰一）→ 生产路径未变")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.e4ManualDelivery), 0, "门控关：E4 分支不进")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.deliveryProbeManualHitChain(
            chain: cellChain(in: probe))), 1, "手动 hitTest 链照常记录（既有观测零行为变更）")
    }

    // MARK: - ③ env = "0"（非 "1"）：同默认关（门控判断严格等于 "1"）

    func testGateValueNonOneBehavesAsOff() {
        XCTAssertEqual(setenv("PAGING_CLICK_PROBE_MANUAL_DELIVERY", "0", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_PROBE_MANUAL_DELIVERY") }
        ClickCensus.resetForTesting()
        let (window, _, _) = makeWindowWithCell()

        window.sendEvent(mouseDown(at: NSPoint(x: 60, y: 60), in: window))

        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.e4ManualDelivery), 0, "env=0（非 1）：E4 分支不进")
        XCTAssertEqual(observeWindowClosedCounts(), 1, "super 原样调用")
    }

    // MARK: - ② env = "1"（门控开）：手动投递分支可达、hit?.mouseDown 被调（s10 联动）、super 未调

    func testGateOnManuallyDeliversMouseDownToHitBeforeSuper() {
        XCTAssertEqual(setenv("PAGING_CLICK_PROBE_MANUAL_DELIVERY", "1", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_PROBE_MANUAL_DELIVERY") }
        ClickCensus.resetForTesting()
        let (window, probe, _) = makeWindowWithCell()

        window.sendEvent(mouseDown(at: NSPoint(x: 60, y: 60), in: window))

        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.e4ManualDelivery), 1,
                       "E4 手动投递分支执行（门控开 + cell 命中）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.cellMouseDownFired), 1,
                       "手动 hit?.mouseDown 到达命中 cell → s10 增量（结果 A 判别位；s10 布点联动断言）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowCellPassthrough), 1, "s8d 仍计（放行分支进入）")
        XCTAssertEqual(observeWindowClosedCounts(), 0,
                       "手动投递后 return：super.sendEvent 未调（内部路由观测窗未开 → absent/present 均 0）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.deliveryProbeManualHitChain(
            chain: cellChain(in: probe))), 1, "手动投递目标 = 窗口手动 hitTest 命中的同一 cell 链")
    }

    // MARK: - ④ sE4 sink 名中性断言（无窗口号码/身份/标题/坐标原文）

    func testE4SinkNameIsNeutral() {
        XCTAssertEqual(ClickCensus.Sink.e4ManualDelivery, "sE4_manual_delivery")
        XCTAssertFalse(ClickCensus.Sink.e4ManualDelivery.contains("windowNumber"),
                       "sink 名不含窗口号码原文（隐私）")
        XCTAssertFalse(ClickCensus.Sink.e4ManualDelivery.contains("_win_"), "sink 名不含窗口身份（隐私）")
        XCTAssertFalse(ClickCensus.Sink.e4ManualDelivery.contains("NSApp"), "sink 名不含 App 身份（隐私）")
    }
}
