// PagingUITests — ClickDeliveryProbeTests（T-1F-B10-regression-fix §2.1 取证装置测试）
// 覆盖（任务包 §2.1.1/§3 测试条款；夹具中性 fixture.*，无真实 app 身份）：
// ① 探针 hitTest 手动调用（markNextHitTestAsManual）→ s18_hit_manual_chain_<类名链> 计数，
//    返回值与 super 一致（=== cell，零行为变更）；
// ② 探针 hitTest 内部调用（观测窗内、未标记）→ s18_hit_internal_chain_<类名链> 计数 +
//    internalHitTestCallCount 增；观测窗外调用零记录；
// ③ 探针 mouseDown → s18_delivered_contentview 计数 + 原样转发 super（不 crash）；
// ④ QuitOnBlankClickWindow + 探针 contentView：cell 点击 → 手动链含 AppGridCellView、
//    s8d 放行、不终止；放行后 absent/present 记账恰一；
// ⑤ 探针 contentView 下空白点击终止路径不变（探针零行为变更回归锁）；
// ⑥ s18 sink 名字符串断言（中性：仅类名，无坐标/身份/标题）；
// ⑦ E1 窗口归属一致性观测（纯 helper 布尔位 + sendEvent 端到端恰记）；
// ⑧ E5-fix 布局计数/两次点击间 relayout 布尔（纯 helper + provider 差分端到端 +
//    真实 PagingSurface.layoutPerformedCount 读取）；
// ⑨ E1/E5/E6 sink 名中性断言（仅布尔位/中性 int 语义，无窗口号码/标题/坐标）；
// ⑩ env 门控缺省关：sink 命中不写 stderr（PAGING_CLICK_CENSUS != 1 时捕获 stderr 断言无输出）；
// ⑪ E6a 探针 mouseUp/mouseDragged/rightMouseDown/otherMouseDown 纯转发 census；
// ⑫ E6b 事件元数据（type/subtype/buttonNumber 三中性 int）helper 直调 + sendEvent 端到端；
// ⑬ E6a'' 分发入口监视（sE6_monitor_down/up）helper 直调（monitor 安装/移除生命周期靠构建+评审）。
//
// 全部 @MainActor；ClickCensus.resetForTesting() 保证跨测试计数隔离。

import AppKit
import XCTest
@testable import AppGridUI
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class ClickDeliveryProbeTests: XCTestCase {

    override func tearDown() {
        DragUISessionCoordinator.shared = nil
        super.tearDown()
    }

    // MARK: - 夹具（中性合成数据）

    private func makeProbeWindow() -> (window: QuitOnBlankClickWindow, probe: ClickDeliveryProbeView) {
        let probe = ClickDeliveryProbeView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let window = QuitOnBlankClickWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = probe
        return (window, probe)
    }

    private func makeCell(in host: NSView) -> AppGridCellView {
        let cell = AppGridCellView(frame: NSRect(x: 20, y: 20, width: 80, height: 80))
        host.addSubview(cell)
        return cell
    }

    private func mouseDown(at point: NSPoint, in window: NSWindow) -> NSEvent {
        NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [],
                           timestamp: 0, windowNumber: window.windowNumber, context: nil,
                           eventNumber: 1, clickCount: 1, pressure: 1)!
    }

    /// cell 在探针（contentView）内的类名链（中性：仅 type(of:) 类名）。
    private func cellChain(in probe: ClickDeliveryProbeView) -> String {
        "AppGridCellView_\(String(describing: type(of: probe)))"
    }

    // MARK: - ① 手动 hitTest 调用 → 手动链 sink + 返回值不变

    func testManualHitTestRecordsManualChainAndReturnsSuperResult() {
        ClickCensus.resetForTesting()
        let (_, probe) = makeProbeWindow()
        let cell = makeCell(in: probe)
        probe.layoutSubtreeIfNeeded()

        probe.markNextHitTestAsManual()
        let hit = probe.hitTest(NSPoint(x: 60, y: 60))
        XCTAssertTrue(hit === cell, "探针 hitTest 返回值与 super 一致（零行为变更）")
        let chain = cellChain(in: probe)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.deliveryProbeManualHitChain(chain: chain)), 1,
                       "手动调用 → s18_hit_manual_chain_<链> 计数 1")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.deliveryProbeInternalHitChain(chain: chain)), 0,
                       "手动调用不记内部链")
        XCTAssertEqual(probe.internalHitTestCallCount, 0, "手动调用不计入内部路由计数")
    }

    // MARK: - ② 内部 hitTest 调用（观测窗内）→ 内部链 sink + 计数；窗外零记录

    func testInternalHitTestRecordsInternalChainAndCountOnlyInsideObservationWindow() {
        ClickCensus.resetForTesting()
        let (_, probe) = makeProbeWindow()
        let cell = makeCell(in: probe)
        probe.layoutSubtreeIfNeeded()
        let chain = cellChain(in: probe)

        // 观测窗外：调用不记录。
        _ = probe.hitTest(NSPoint(x: 60, y: 60))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.deliveryProbeInternalHitChain(chain: chain)), 0,
                       "观测窗外内部调用零记录")
        XCTAssertEqual(probe.internalHitTestCallCount, 0)

        // 观测窗内：记录内部链 + 计数。
        probe.beginInternalObservation()
        let hit = probe.hitTest(NSPoint(x: 60, y: 60))
        XCTAssertTrue(hit === cell, "观测窗内返回值仍与 super 一致")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.deliveryProbeInternalHitChain(chain: chain)), 1,
                       "观测窗内调用 → s18_hit_internal_chain_<链> 计数 1")
        XCTAssertEqual(probe.internalHitTestCallCount, 1, "内部路由计数 +1")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.deliveryProbeManualHitChain(chain: chain)), 0,
                       "内部调用不记手动链")

        // 关闭观测窗：再次调用零记录。
        probe.endInternalObservation()
        _ = probe.hitTest(NSPoint(x: 60, y: 60))
        XCTAssertEqual(probe.internalHitTestCallCount, 1, "观测窗关闭后计数不再增")
    }

    // MARK: - ③ 探针 mouseDown → s18_delivered_contentview + 原样转发

    func testProbeMouseDownRecordsDeliveryAndForwardsToSuper() {
        ClickCensus.resetForTesting()
        let (window, probe) = makeProbeWindow()
        probe.mouseDown(with: mouseDown(at: NSPoint(x: 60, y: 60), in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.deliveryProbeDeliveredToContentView), 1,
                       "投递给 contentView → s18_delivered_contentview 计数 1")
        // 转发 super 不 crash（NSView 默认 mouseDown 沿响应链上抛；无观察副作用）。
    }

    // MARK: - ④ 窗口 sendEvent：cell 点击 → 手动链 + s8d 放行 + 不终止 + absent/present 恰一

    func testWindowCellClickRecordsManualChainAndPassthroughWithoutTerminate() {
        // B1 转正（2026-09-06）后默认开；本测试验证窗口分类 + 观测窗闭合 → 显式关 B1。
        XCTAssertEqual(setenv("PAGING_CLICK_MANUAL_DELIVERY", "0", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_MANUAL_DELIVERY") }
        ClickCensus.resetForTesting()
        let (window, probe) = makeProbeWindow()
        let cell = makeCell(in: probe)
        probe.layoutSubtreeIfNeeded()
        var terminated = false
        window.onBlankClick = { terminated = true }

        window.sendEvent(mouseDown(at: NSPoint(x: 60, y: 60), in: window))

        let chain = cellChain(in: probe)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.deliveryProbeManualHitChain(chain: chain)), 1,
                       "窗口手动 hitTest 结果链含 AppGridCellView（s8d 判定依据）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowCellPassthrough), 1,
                       "cell 命中放行 super（s8d）")
        XCTAssertFalse(terminated, "cell 点击不触发终止")
        let absent = ClickCensus.count(ClickCensus.Sink.deliveryProbeInternalHitTestAbsent)
        let present = ClickCensus.count(ClickCensus.Sink.deliveryProbeInternalHitTestPresent)
        XCTAssertEqual(absent + present, 1, "放行后 absent/present 记账恰一（观测窗闭合）")
    }

    // MARK: - ⑤ 探针 contentView 下空白点击终止路径不变（零行为变更回归锁）

    func testWindowBlankClickStillTerminatesWithProbeContentView() {
        ClickCensus.resetForTesting()
        let (window, probe) = makeProbeWindow()
        var terminated = false
        window.onBlankClick = { terminated = true }

        window.sendEvent(mouseDown(at: NSPoint(x: 20, y: 20), in: window))

        XCTAssertTrue(terminated, "探针 contentView 下空白点击仍走终止路径（零行为变更）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowBlankTerminate), 1, "s8c 计数 1")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowCellPassthrough), 0, "无 cell 放行")
    }

    // MARK: - ⑥ s18 sink 名字符串断言（中性：仅类名）

    func testS18SinkNamesAreNeutralClassChains() {
        XCTAssertEqual(ClickCensus.Sink.deliveryProbeManualHitChainBase, "s18_hit_manual_chain")
        XCTAssertEqual(ClickCensus.Sink.deliveryProbeInternalHitChainBase, "s18_hit_internal_chain")
        XCTAssertEqual(ClickCensus.Sink.deliveryProbeDeliveredToContentView, "s18_delivered_contentview")
        XCTAssertEqual(ClickCensus.Sink.deliveryProbeInternalHitTestAbsent, "s18_internal_hittest_absent")
        XCTAssertEqual(ClickCensus.Sink.deliveryProbeInternalHitTestPresent, "s18_internal_hittest_present")
        // 链编码：仅类名（无坐标/身份/标题）；探针自身类名结尾。
        let (_, probe) = makeProbeWindow()
        let chain = cellChain(in: probe)
        XCTAssertEqual(ClickCensus.Sink.deliveryProbeManualHitChain(chain: chain),
                       "s18_hit_manual_chain_AppGridCellView_\(String(describing: type(of: probe)))")
        XCTAssertTrue(chain.hasSuffix(String(describing: type(of: probe))),
                      "链以探针（contentView）类名结尾")
    }

    // MARK: - ⑦ E1 窗口归属一致性观测（§2.1 步骤 1；仅计数 + 布尔位，零行为变更）

    /// 三窗号完全一致 → match 恰一，无任何 mismatch 位。
    func testWindowOwnershipObservationMatchRecordsMatchSink() {
        ClickCensus.resetForTesting()
        ClickCensus.observeWindowOwnership(eventWindowNumber: 42, selfWindowNumber: 42, keyWindowNumber: 42)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMatch), 1, "三者一致 → sE1_match 计数 1")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMismatchEvSelf), 0)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMismatchEvKey), 0)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMismatchSelfKey), 0)
    }

    /// event 与 self/key 均异（ev=11, self=22, key=22）→ evSelf 与 evKey 两布尔位同时置位，
    /// self==key 无 selfKey 位（三数两两比较语义：ev 为唯一异者时必记 evSelf+evKey 两位）。
    func testWindowOwnershipObservationEventSelfMismatchRecordsEvSelfBit() {
        ClickCensus.resetForTesting()
        ClickCensus.observeWindowOwnership(eventWindowNumber: 11, selfWindowNumber: 22, keyWindowNumber: 22)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMismatchEvSelf), 1, "ev≠self → evSelf 位")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMismatchEvKey), 1, "ev≠key → evKey 位")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMatch), 0)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMismatchSelfKey), 0, "self==key 无 selfKey 位")
    }

    /// keyWindow == nil：ev==self，但两者 != nil → evKey 与 selfKey 两布尔位同时置位。
    func testWindowOwnershipObservationSelfKeyMismatchWhenKeyNil() {
        ClickCensus.resetForTesting()
        ClickCensus.observeWindowOwnership(eventWindowNumber: 33, selfWindowNumber: 33, keyWindowNumber: nil)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMismatchEvKey), 1, "key=nil → evKey 位")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMismatchSelfKey), 1, "key=nil → selfKey 位")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMatch), 0)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMismatchEvSelf), 0, "ev==self 无 evSelf 位")
    }

    /// 三窗号两两互异 → 三个 mismatch 位全部置位（无 match）。
    func testWindowOwnershipObservationFullyDisjointRecordsAllMismatchBits() {
        ClickCensus.resetForTesting()
        ClickCensus.observeWindowOwnership(eventWindowNumber: 1, selfWindowNumber: 2, keyWindowNumber: 3)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMismatchEvSelf), 1)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMismatchEvKey), 1)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMismatchSelfKey), 1)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMatch), 0)
    }

    /// sendEvent 端到端：每次 leftMouseDown 经 E1 观测记恰一次一致性结果。夹具窗口未被
    /// makeKey → keyWindow 为 nil 或其它窗口 → 确定性记 evKey + selfKey 两个 mismatch 位；
    /// event 与 self 恒同窗（evSelf 恒 0，match 恒 0）。
    func testSendEventRecordsConsistentOwnershipBitsPerClick() {
        ClickCensus.resetForTesting()
        let (window, probe) = makeProbeWindow()
        let cell = makeCell(in: probe)
        probe.layoutSubtreeIfNeeded()
        window.onBlankClick = { }

        window.sendEvent(mouseDown(at: NSPoint(x: 60, y: 60), in: window))

        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMatch), 0,
                       "测试窗口非 key → 无全一致")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMismatchEvSelf), 0,
                       "event 与 self 同窗 → 恒无 evSelf 位")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMismatchEvKey), 1,
                       "key 窗口（nil 或其它）≠ event 窗 → evKey 位恰一")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMismatchSelfKey), 1,
                       "key 窗口 ≠ self 窗 → selfKey 位恰一")
    }

    // MARK: - ⑧ E5-fix 缓存失效对照观测（§2.1 步骤 2；仅计数，零行为变更）

    /// 纯 helper：relayoutOccurred 布尔映射 _yes/_no sink。
    func testRelayoutObservationDirect() {
        ClickCensus.resetForTesting()
        ClickCensus.observeRelayoutSincePreviousClick(relayoutOccurred: true)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.relayoutBetweenClicks(true)), 1)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.relayoutBetweenClicks(false)), 0)
    }

    /// sendEvent 端到端差分（E5-fix provider 语义）：provider 直接读
    /// `PagingSurface.layoutPerformedCount`（冻结树 :169 public private(set)，只读不调用）
    /// 替代已降级的 E5 funnel；测试用 boxed 计数模拟 surface 计数增量。点击间无增量 → _no；
    /// 增量 ≥1 → _yes；窗口基线随每次点击滚动。
    func testSendEventRecordsRelayoutBetweenClicksDeltas() {
        ClickCensus.resetForTesting()
        let (window, probe) = makeProbeWindow()
        let cell = makeCell(in: probe)
        probe.layoutSubtreeIfNeeded()
        window.onBlankClick = { }
        let point = NSPoint(x: 60, y: 60)
        // E5-fix：provider 接线（AppDelegate 侧同款：`self?.surface?.layoutPerformedCount ?? 0`）。
        var layoutCount = 0
        window.layoutPerformedCountProvider = { layoutCount }

        // 点击 1：provider=0、窗口基线 0 → 无 relayout → _no。
        window.sendEvent(mouseDown(at: point, in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.relayoutBetweenClicks(false)), 1,
                       "首次点击（无布局增量）→ _no")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.relayoutBetweenClicks(true)), 0)

        // 模拟一次 relayout（layoutPerformedCount 增量）→ 点击 2 → _yes。
        layoutCount += 1
        window.sendEvent(mouseDown(at: point, in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.relayoutBetweenClicks(true)), 1,
                       "两次点击间有布局增量 → _yes")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.relayoutBetweenClicks(false)), 1,
                       "_no 不再增（基线已滚动）")
    }

    /// E5-fix 端到端（真实 PagingSurface）：provider 读真实 `layoutPerformedCount`；
    /// `relayoutPages()`（internal，@testable 可调；生产侧只读不调用）增量 → 两次点击间 _yes。
    func testSendEventE5FixReadsRealSurfaceLayoutPerformedCount() {
        ClickCensus.resetForTesting()
        let (window, probe) = makeProbeWindow()
        _ = makeCell(in: probe)
        probe.layoutSubtreeIfNeeded()
        window.onBlankClick = { }
        let point = NSPoint(x: 60, y: 60)

        // 真实 PagingSurface（中性夹具；AppDelegate 侧接线同款 provider）。
        let surface = PagingSurface(pageCount: 2, itemsPerPage: 8, initialPage: 0,
                                    reduceMotion: false, labMode: false)
        surface.frame = NSRect(x: 0, y: 0, width: 400, height: 300)
        window.layoutPerformedCountProvider = { [weak surface] in surface?.layoutPerformedCount ?? 0 }

        // 预热首击：surface init 已产生布局计数（relayoutPages），首击建立窗口基线
        // （基线 = 当前计数；生产同构：窗口创建后首次点击前的启动期布局计入首击差分）。
        window.sendEvent(mouseDown(at: point, in: window))
        ClickCensus.resetForTesting()

        // 点击 1（基线已建立）：无 relayout → _no。
        window.sendEvent(mouseDown(at: point, in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.relayoutBetweenClicks(false)), 1,
                       "真实 surface 无布局增量 → _no")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.relayoutBetweenClicks(true)), 0)

        // 真实 relayout（relayoutPages 内部入口）→ 点击 2 → _yes。
        let countBefore = surface.layoutPerformedCount
        surface.relayoutPages()
        XCTAssertGreaterThan(surface.layoutPerformedCount, countBefore,
                             "relayoutPages 增量 layoutPerformedCount（:742）")
        window.sendEvent(mouseDown(at: point, in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.relayoutBetweenClicks(true)), 1,
                       "真实布局增量 → _yes")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.relayoutBetweenClicks(false)), 1,
                       "_no 不再增（基线已滚动）")
    }

    // MARK: - ⑨ E1/E5/E6 sink 名中性断言（仅布尔位/中性 int 语义，无窗口号码/标题/坐标）

    func testE1E5E6SinkNamesAreNeutral() {
        XCTAssertEqual(ClickCensus.Sink.windowOwnerMatch, "sE1_window_owner_match")
        XCTAssertEqual(ClickCensus.Sink.windowOwnerMismatchEvSelf, "sE1_window_owner_mismatch_evSelf")
        XCTAssertEqual(ClickCensus.Sink.windowOwnerMismatchEvKey, "sE1_window_owner_mismatch_evKey")
        XCTAssertEqual(ClickCensus.Sink.windowOwnerMismatchSelfKey, "sE1_window_owner_mismatch_selfKey")
        XCTAssertEqual(ClickCensus.Sink.relayoutBetweenClicks(true), "sE5_relayout_between_clicks_yes")
        XCTAssertEqual(ClickCensus.Sink.relayoutBetweenClicks(false), "sE5_relayout_between_clicks_no")
        XCTAssertEqual(ClickCensus.Sink.deliveryProbeMouseUp, "sE6a_probe_mouseup")
        XCTAssertEqual(ClickCensus.Sink.deliveryProbeMouseDragged, "sE6a_probe_mousedragged")
        XCTAssertEqual(ClickCensus.Sink.deliveryProbeRightMouseDown, "sE6a_probe_rightmousedown")
        XCTAssertEqual(ClickCensus.Sink.deliveryProbeOtherMouseDown, "sE6a_probe_othermousedown")
        XCTAssertEqual(ClickCensus.Sink.monitorMouseDown, "sE6_monitor_down")
        XCTAssertEqual(ClickCensus.Sink.monitorMouseUp, "sE6_monitor_up")
        XCTAssertEqual(ClickCensus.Sink.eventMetadataBase, "sE6b_meta")
        XCTAssertEqual(ClickCensus.Sink.eventMetadata(type: 1, subtype: 0, buttonNumber: 0),
                       "sE6b_meta_type_1_subtype_0_button_0")
        // 隐私 A/B/C：sink 名不得携带窗口号码/身份/标题/坐标原文（仅布尔位/中性 int 语义）。
        let names = [ClickCensus.Sink.windowOwnerMatch,
                     ClickCensus.Sink.windowOwnerMismatchEvSelf,
                     ClickCensus.Sink.windowOwnerMismatchEvKey,
                     ClickCensus.Sink.windowOwnerMismatchSelfKey,
                     ClickCensus.Sink.relayoutBetweenClicks(true),
                     ClickCensus.Sink.relayoutBetweenClicks(false),
                     ClickCensus.Sink.deliveryProbeMouseUp,
                     ClickCensus.Sink.deliveryProbeMouseDragged,
                     ClickCensus.Sink.deliveryProbeRightMouseDown,
                     ClickCensus.Sink.deliveryProbeOtherMouseDown,
                     ClickCensus.Sink.monitorMouseDown,
                     ClickCensus.Sink.monitorMouseUp,
                     ClickCensus.Sink.eventMetadata(type: 1, subtype: 0, buttonNumber: 0)]
        for name in names {
            XCTAssertFalse(name.contains("windowNumber"), "sink 名不含窗口号码原文（隐私）：\(name)")
            XCTAssertFalse(name.contains("_win_"), "sink 名不含窗口身份（隐私）：\(name)")
            XCTAssertFalse(name.contains("NSApp"), "sink 名不含 App 身份（隐私）：\(name)")
        }
    }

    // MARK: - ⑩ env 门控缺省关：sink 命中不写 stderr（零输出自证）

    /// 门控缺省（未设 PAGING_CLICK_CENSUS=1）：E1/E5 sink 命中只计数、stderr 零输出
    /// （沿用既有 ClickCensus 管道；本断言捕获进程 stderr 验证无 `PAGING_CLICK_CENSUS`
    /// 行）。env 置 1 时跳过（输出为预期行为，非本断言面）。
    func testESinksSilentWhenGateOffByDefault() throws {
        try XCTSkipIf(ProcessInfo.processInfo.environment["PAGING_CLICK_CENSUS"] == "1",
                      "PAGING_CLICK_CENSUS=1：门控开启（stderr 输出为预期），本静默断言不适用")

        // 捕获 stderr：dup2 管道写端到 fd 2（XCTest 输出走 stdout，不受影响）。
        var fds = [Int32](repeating: 0, count: 2)
        XCTAssertEqual(pipe(&fds), 0, "stderr 捕获管道建立")
        let savedErr = dup(STDERR_FILENO)
        XCTAssertGreaterThanOrEqual(savedErr, 0, "保存原 stderr fd")
        XCTAssertEqual(dup2(fds[1], STDERR_FILENO), STDERR_FILENO, "重定向 fd 2 到管道")
        close(fds[1])
        defer {
            dup2(savedErr, STDERR_FILENO)
            close(savedErr)
            close(fds[0])
        }

        ClickCensus.resetForTesting()
        ClickCensus.hit(ClickCensus.Sink.windowOwnerMatch)
        ClickCensus.hit(ClickCensus.Sink.windowOwnerMismatchEvSelf)
        ClickCensus.hit(ClickCensus.Sink.windowOwnerMismatchEvKey)
        ClickCensus.hit(ClickCensus.Sink.windowOwnerMismatchSelfKey)
        ClickCensus.hit(ClickCensus.Sink.deliveryProbeMouseUp)
        ClickCensus.hit(ClickCensus.Sink.relayoutBetweenClicks(true))
        ClickCensus.hit(ClickCensus.Sink.eventMetadata(type: 1, subtype: 0, buttonNumber: 0))
        ClickCensus.hit(ClickCensus.Sink.monitorMouseDown)
        ClickCensus.hit(ClickCensus.Sink.monitorMouseUp)
        // 计数侧照常维护（与输出侧门控正交）。
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowOwnerMatch), 1, "门控关时计数仍维护")

        // 非阻塞读净管道：门控关 → 无任何 census stderr 行。
        let flags = fcntl(fds[0], F_GETFL)
        fcntl(fds[0], F_SETFL, flags | O_NONBLOCK)
        var collected = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = read(fds[0], &buffer, buffer.count)
            if n > 0 {
                collected.append(contentsOf: buffer[0..<Int(n)])
            } else {
                break
            }
        }
        let stderrText = String(decoding: collected, as: UTF8.self)
        XCTAssertFalse(stderrText.contains("PAGING_CLICK_CENSUS"),
                       "门控缺省关：sink 命中不写 stderr（实测输出：\(stderrText)）")
    }

    // MARK: - ⑪ E6a 探针投递观测（§2.1 步骤 3；纯转发 census，零行为变更）

    /// 探针 mouseUp/mouseDragged/rightMouseDown/otherMouseDown 各记中性计数 + 原样转发 super。
    func testProbeMouseEventForwardingCensus() {
        ClickCensus.resetForTesting()
        let (window, probe) = makeProbeWindow()

        let up = NSEvent.mouseEvent(with: .leftMouseUp, location: NSPoint(x: 60, y: 60),
                                    modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                    context: nil, eventNumber: 2, clickCount: 1, pressure: 0)!
        let dragged = NSEvent.mouseEvent(with: .leftMouseDragged, location: NSPoint(x: 70, y: 70),
                                         modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                         context: nil, eventNumber: 3, clickCount: 1, pressure: 0)!
        let rightDown = NSEvent.mouseEvent(with: .rightMouseDown, location: NSPoint(x: 60, y: 60),
                                           modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                           context: nil, eventNumber: 4, clickCount: 1, pressure: 0)!
        let otherDown = NSEvent.mouseEvent(with: .otherMouseDown, location: NSPoint(x: 60, y: 60),
                                           modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                           context: nil, eventNumber: 5, clickCount: 1, pressure: 0)!

        probe.mouseUp(with: up)
        probe.mouseDragged(with: dragged)
        probe.rightMouseDown(with: rightDown)
        probe.otherMouseDown(with: otherDown)

        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.deliveryProbeMouseUp), 1,
                       "E6a mouseUp 转发计数 1")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.deliveryProbeMouseDragged), 1,
                       "E6a mouseDragged 转发计数 1")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.deliveryProbeRightMouseDown), 1,
                       "E6a rightMouseDown 转发计数 1")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.deliveryProbeOtherMouseDown), 1,
                       "E6a otherMouseDown 转发计数 1")
        // 转发 super 不 crash（NSView 默认实现沿响应链上抛；无观察副作用）。
    }

    // MARK: - ⑫ E6b 事件元数据观测（§2.1 步骤 4；type/subtype/buttonNumber 三中性 int）

    /// 纯 helper：三中性 int 编码进 sink 名（仅入内存 snapshot；stderr 只打 sink 名+计数）。
    func testEventMetadataObservationDirect() {
        ClickCensus.resetForTesting()
        ClickCensus.observeEventMetadata(type: 1, subtype: 0, buttonNumber: 0)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.eventMetadata(type: 1, subtype: 0, buttonNumber: 0)), 1,
                       "E6b 元数据 sink 计数 1")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.eventMetadata(type: 3, subtype: 0, buttonNumber: 1)), 0,
                       "不同元数据组合互不串扰")
    }

    /// sendEvent 端到端：mouseDown 家族（leftMouseDown/rightMouseDown/otherMouseDown）每点击
    /// 记恰一次元数据 sink（sink 名 = 事件自身 type/subtype/buttonNumber 编码）。
    func testSendEventRecordsEventMetadataPerMouseDownFamilyClick() {
        ClickCensus.resetForTesting()
        let (window, probe) = makeProbeWindow()
        _ = makeCell(in: probe)
        probe.layoutSubtreeIfNeeded()
        window.onBlankClick = { }

        let left = mouseDown(at: NSPoint(x: 60, y: 60), in: window)
        window.sendEvent(left)
        let leftSink = ClickCensus.Sink.eventMetadata(
            type: left.type.rawValue, subtype: left.subtype.rawValue, buttonNumber: left.buttonNumber)
        XCTAssertEqual(ClickCensus.count(leftSink), 1, "leftMouseDown 元数据 sink 恰一")

        let right = NSEvent.mouseEvent(with: .rightMouseDown, location: NSPoint(x: 60, y: 60),
                                       modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                       context: nil, eventNumber: 6, clickCount: 1, pressure: 0)!
        window.sendEvent(right)
        let rightSink = ClickCensus.Sink.eventMetadata(
            type: right.type.rawValue, subtype: right.subtype.rawValue, buttonNumber: right.buttonNumber)
        XCTAssertEqual(ClickCensus.count(rightSink), 1, "rightMouseDown 元数据 sink 恰一")

        let other = NSEvent.mouseEvent(with: .otherMouseDown, location: NSPoint(x: 60, y: 60),
                                       modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                       context: nil, eventNumber: 7, clickCount: 1, pressure: 0)!
        window.sendEvent(other)
        let otherSink = ClickCensus.Sink.eventMetadata(
            type: other.type.rawValue, subtype: other.subtype.rawValue, buttonNumber: other.buttonNumber)
        XCTAssertEqual(ClickCensus.count(otherSink), 1, "otherMouseDown 元数据 sink 恰一")

        // 非 mouseDown 家族（如 keyDown）不记元数据。
        let key = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                   timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                   characters: "a", charactersIgnoringModifiers: "a",
                                   isARepeat: false, keyCode: 0)!
        window.sendEvent(key)
        let metaTotal = ClickCensus.snapshot().filter { $0.key.hasPrefix(ClickCensus.Sink.eventMetadataBase) }
            .reduce(0) { $0 + $1.value }
        XCTAssertEqual(metaTotal, 3, "仅 mouseDown 家族 3 次点击记元数据（keyDown 不记）")
    }

    // MARK: - ⑬ E6a'' 分发入口监视（§2.1 步骤 4；helper 直调；monitor 安装/移除生命周期靠构建+评审）

    /// E6a'' helper 直调：leftMouseDown → sE6_monitor_down 恰一；leftMouseUp → sE6_monitor_up 恰一。
    func testMonitorEventObservationDirect() {
        ClickCensus.resetForTesting()
        ClickCensus.observeMonitorEvent(type: .leftMouseDown)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.monitorMouseDown), 1,
                       "E6a'' monitor down 计数 1")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.monitorMouseUp), 0)

        ClickCensus.observeMonitorEvent(type: .leftMouseUp)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.monitorMouseUp), 1,
                       "E6a'' monitor up 计数 1")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.monitorMouseDown), 1,
                       "down 不再增")
    }
}
