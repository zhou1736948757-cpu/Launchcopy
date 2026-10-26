import AppKit
import AppGridUI
import PagingUI

// MARK: - T-1F-B10-regression-fix §2.1 第 4 项（E4）：env 门控手动投递 A/B 实验门（仅诊断）

/// E4 env 门控（**仅供诊断 A/B 实验，禁止作为生产路径常驻**）：
/// `PAGING_CLICK_PROBE_MANUAL_DELIVERY=1` 时在 cell 放行分支手动 `hit?.mouseDown(with:)` 并
/// return（不调 super）；默认未设 env = 门控关，生产路径逐字不变（零行为变更）。
/// 经 `getenv` 每次实读（不用 ProcessInfo.environment 字典，避免进程级缓存歧义；
/// 测试可 setenv/unsetenv 确定性控制）。中性：仅布尔判断，不携带任何身份/坐标。
private enum E4ManualDeliveryGate {
    static var isEnabled: Bool {
        guard let raw = getenv("PAGING_CLICK_PROBE_MANUAL_DELIVERY") else { return false }
        return String(cString: raw) == "1"
    }
}

// MARK: - T-1F-B10-regression-fix §2.2 B1（REPORT §15 定案）：env 门控手动投递闭环（生产候选）

/// B1 env 门控（**生产路径，默认开；转正 2026-09-06 实机定案**）：
/// `PAGING_CLICK_MANUAL_DELIVERY` 未设或 =1 时，cell 命中的 leftMouseDown 手动投递给真实
/// `AppGridCellView` ancestor，并记录 `lastManualMouseDownCell`（weak），leftMouseUp /
/// leftMouseDragged 在记录存在时投给记录 cell——与 E4 诊断探针门（无闭环二分器，
/// `PAGING_CLICK_PROBE_MANUAL_DELIVERY`）**分离**：本门含完整 up/dragged 闭环
/// （cell.mouseUp → coordinator.pointerUp → endSession → dispatchClick → onCellClick
/// → sA launch），消除 E4-B 运行「手动 down 后 state 卡 .pressed」死态。
/// 两门同时开启时 **B1 优先**（E4 分支不执行，行为确定可测）；`PAGING_CLICK_MANUAL_DELIVERY=0`
/// 显式关闭（诊断对照：AppKit 正常投递 = B10 修复前死路径，点击 cell 不启动）。
/// 转正依据（2026-09-06 实机 A/B）：默认关时点击 cell 仅 s8d 放行、s10 恒 0、软件不启动；
/// 门控开时 s10 → s6 → sA_launch_accepted 完整闭环（/tmp/b10-run1-gated.log 证据）。
/// 经 `getenv` 每次实读（不用 ProcessInfo.environment 字典，避免进程级缓存歧义；
/// 测试可 setenv/unsetenv 确定性控制）。中性：仅布尔判断，不携带任何身份/坐标。
private enum B1ManualDeliveryGate {
    static var isEnabled: Bool {
        guard let raw = getenv("PAGING_CLICK_MANUAL_DELIVERY") else { return true }
        return String(cString: raw) == "1"
    }
}

// MARK: - 单击空白背景退出的宿主窗口（T-1C-D repair）

/// 全屏「单击空白背景退出」宿主窗口。
///
/// 为什么要用窗口级 `sendEvent` 拦截而不是给 surface 挂手势识别器：
/// - `PagingSurface` 是 `public final`（冻结），无法通过子类覆盖 `mouseDown(with:)`，且
///   它是仅有的、铺满窗口的交互视图——任何「容器视图 mouseDown」方案都得改 hitTest 重定向命中，
///   而 AppKit 的 scrollWheel 事件目标正是经 hitTest 决定的，那样会破坏翻页。因此把拦截点放在
///   窗口 `sendEvent`：这是**本窗口内**的一次事件入口（每次真实鼠标事件都经过），**不是**红线
///   「全局 NSEvent monitor」（`NSEvent.addGlobalMonitorForEvents`），窗口外/其他 app 完全不触碰。
/// - 每次真实的 `leftMouseDown` 都会评估命中（不再依赖 may-not-fire 的点击识别），且不做 hitTest
///   改写 → scrollWheel 翻页、键盘导航的事件路由零改动。
///
/// 行为：命中空白背景（非 app cell，含 grid 间隙/边距/page 空白）→ 搜索激活时退出搜索、
/// 否则首击即退出；命中 app cell（或其 icon/label 子视图）→ 原样交给 super 分发，surface 上
/// AppLaunchController 的 cell 单击识别器照常启动。cell 判定走下方 `blankClickResolvesToCell`
/// （沿 superview 链校验，点击 cell 内部子视图不误判）。
final class QuitOnBlankClickWindow: NSWindow {
    /// 空白背景被首次实击时回调（AppDelegate 据此退出；搜索未激活路径）。
    var onBlankClick: (() -> Void)?
    /// An open folder owns every scroll sequence, including ignored/blocked events.
    @MainActor var onFolderScroll: ((NSEvent) -> Void)?
    /// True consumes a content click that only ends inline folder-title editing.
    @MainActor var onFolderTitlePointerDown: ((NSEvent) -> Bool)?
    private var isConsumingTitleDismissal = false
    @MainActor var libraryActiveProvider: (() -> Bool)?
    @MainActor var mainGridInputIsAvailable: (() -> Bool)?
    private var gridScrollSequenceGate = MainGridScrollSequenceGate()
    @MainActor var onLibraryEscape: (() -> Bool)?
    @MainActor var onLeadingLibraryEvent: ((NSEvent) -> Bool)?

    /// Deliver an original deferred native event without re-entering arbitration.
    func deliverOriginalNativeEvent(_ event: NSEvent) { super.sendEvent(event) }
    /// T-1D 修复：空白背景 + 搜索激活时的退出搜索 seam。返回 true = 已退出搜索并吞掉本点击；
    /// false = 搜索未激活，调用方按原路径终止。由 AppDelegate 接 AppSearchController.
    @MainActor var onBlankClickShouldExitSearch: (() -> Bool)?
    /// T-1E-E：folder 打开状态提供者（nil = 无 folder 打开层）。folder 打开时空白点击
    /// 只关闭 folder（不退出）；folder 关闭后下一次真实背景单击才退出（两阶段，ADR-008 §3 Q10）。
    @MainActor var folderOpenStateProvider: (() -> FolderOpenState?)?
    /// Phase 1F（T-1F-D1）：drag 仲裁守卫。**空白** mouseDown 时 drag 激活 → cancel(.escape)
    /// 并吞掉本点击（返回 true；不退出）。false = 无 drag，调用方按原路径处理。
    /// T-1F-B7-wave-c 收窄：本 seam 仅在空白命中（!blankClickResolvesToCell）时评估；
    /// cell 命中不吞（secondDrag 归 coordinator 仲裁）。
    @MainActor var onDragActiveCancel: (() -> Bool)?
    /// Phase 1F（T-1F-D1）：ESC keyDown 时 drag 激活 → cancel(.escape) 并吞掉（返回 true）。
    /// false = 无 drag，事件放行给键盘控制器（既有 ESC 语义不变）。
    @MainActor var onEscapeDuringDrag: (() -> Bool)?
    /// Opt-in isolated diagnostics only; never intercepts or retains the native event.
    @MainActor var onFolderMouseUpTiming: ((TimeInterval, TimeInterval) -> Void)?
    /// T-1F-B10-regression-fix §2.1 取证（E5-fix）：`PagingSurface.layoutPerformedCount`
    /// 只读提供者（AppDelegate 接线；nil = 无 surface，按 0 计）。纯观测，零行为变更。
    var layoutPerformedCountProvider: (() -> Int)?
    /// T-1F-B10-regression-fix §2.1 取证（E5-fix）：上次 leftMouseDown 观测时的
    /// `layoutPerformedCount` 基线（纯观测状态，零行为变更；每窗口实例从 0 起算）。
    private var lastLayoutPerformedCountAtPreviousClick = 0
    /// T-1F-B10-regression-fix §2.2 B1（REPORT §15 ②）：手动投递闭环的记录视图
    /// （weak；**仅 B1 门控开时非 nil**——门控关时恒 nil，本属性零行为影响）。
    /// cell 命中 leftMouseDown 手动投递后记录；leftMouseUp/leftMouseDragged 投递到
    /// 记录视图；窗口失 key / ESC 打断时清空（防 stale 记录，B 运行边界外防护）。
    private weak var lastManualMouseDownCell: AppGridCellView?

    /// T-1F-B10-regression-fix §2.2 B1（REPORT §15 ④）：窗口失 key → 清手动投递记录
    /// （防 stale；门控关时记录恒 nil，零行为变更）。原失 key 语义（AppDelegate
    /// `windowDidResignKey` → dragCoordinator cancel(.windowResign)）逐字不变。
    override func resignKey() {
        lastManualMouseDownCell = nil
        isConsumingTitleDismissal = false
        super.resignKey()
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            PointerInputDiagnostics.record(.windowDown)
            PointerInputDiagnostics.record(isKeyWindow
                ? (NSApp.isActive ? .windowKeyActive : .windowKeyInactive)
                : (NSApp.isActive ? .windowNotKeyActive : .windowNotKeyInactive))
        case .leftMouseDragged: PointerInputDiagnostics.record(.windowDragged)
        case .leftMouseUp: PointerInputDiagnostics.record(.windowUp)
        default: break
        }
        if event.type == .leftMouseUp {
            MainActor.assumeIsolated {
                if let observer = onFolderMouseUpTiming {
                    observer(event.timestamp, ProcessInfo.processInfo.systemUptime)
                }
            }
        }
        if isConsumingTitleDismissal {
            if event.type == .leftMouseUp { isConsumingTitleDismissal = false; return }
            if event.type == .leftMouseDragged { return }
        }
        if event.type == .leftMouseDown { isConsumingTitleDismissal = false }
        // Titled test windows have native title-bar and resize input outside their content.
        // Nil hit-test there is not a launcher background click. Let AppKit move/resize it.
        if event.type == .leftMouseDown, styleMask.contains(.titled),
           (!contentLayoutRect.contains(event.locationInWindow)
            || (styleMask.contains(.resizable)
                && !contentLayoutRect.insetBy(dx: 4, dy: 4).contains(event.locationInWindow))) {
            super.sendEvent(event)
            return
        }
        if event.type == .leftMouseDown,
           MainActor.assumeIsolated({ onFolderTitlePointerDown?(event) == true }) {
            PointerInputDiagnostics.record(.titleDismissed)
            isConsumingTitleDismissal = true
            lastManualMouseDownCell = nil
            return
        }
        if event.type == .scrollWheel,
           MainActor.assumeIsolated({ folderOpenStateProvider?()?.isOpen == true }) {
            MainActor.assumeIsolated { onFolderScroll?(event) }
            return
        }
        if event.type == .scrollWheel {
            MainActor.assumeIsolated {
                gridScrollSequenceGate.observeBoundary(phase: event.phase, momentumPhase: event.momentumPhase,
                    inputIsAvailable: mainGridInputIsAvailable?() != false)
            }
        }
        if MainActor.assumeIsolated({ onLeadingLibraryEvent?(event) == true }) {
            if event.type == .leftMouseDown { PointerInputDiagnostics.record(.leadingLibraryConsumed) }
            return
        }
        // Library is a native responder/scroll mode in this same window.
        // Never hand its blank space or controls to the hidden grid click funnel.
        if MainActor.assumeIsolated({ libraryActiveProvider?() == true }) {
            if event.type == .leftMouseDown { PointerInputDiagnostics.record(.libraryConsumed) }
            lastManualMouseDownCell = nil
            if event.type == .keyDown, event.keyCode == 53, attachedSheet == nil,
               (firstResponder as? NSTextView)?.hasMarkedText() != true,
               MainActor.assumeIsolated({ onLibraryEscape?() == true }) { return }
            super.sendEvent(event)
            return
        }
        if event.type == .scrollWheel,
           MainActor.assumeIsolated({
               gridScrollSequenceGate.shouldSuppress(phase: event.phase, momentumPhase: event.momentumPhase,
                   inputIsAvailable: mainGridInputIsAvailable?() != false)
           }) { return }
        // T-1F-B10-regression-fix §2.2 B1（REPORT §15 ②③）：env 门控
        // `PAGING_CLICK_MANUAL_DELIVERY=1`（未设时默认开）时，leftMouseUp/leftMouseDragged
        // 在记录非 nil（经 B1 down 分支配对记录的真实 cell）时手动投递给记录 cell 并 return。
        // 闭环关键环：cell.mouseUp →
        // coordinator.pointerUp（s9b endSession）→ dispatchClick（s6）→ onCellClick → sA
        // launch；拖拽链 → coordinator s4a-s4c（预览/拖拽不回归）。**记录 nil（无配对 down
        // / 门控关）→ 本块整体不执行，维持原 super.sendEvent 语义逐字不变。**
        if B1ManualDeliveryGate.isEnabled {
            switch event.type {
            case .leftMouseUp:
                if let target = lastManualMouseDownCell {
                    PointerInputDiagnostics.record(.b1Up)
                    // Retire this capture before client callbacks can admit another press,
                    // including a new press on this same cell.
                    lastManualMouseDownCell = nil
                    target.mouseUp(with: event)
                    return
                }
            case .leftMouseDragged:
                if let target = lastManualMouseDownCell {
                    PointerInputDiagnostics.record(.b1Dragged)
                    target.mouseDragged(with: event)
                    return
                }
            default:
                break
            }
        }
        // Phase 1F：ESC 且 drag 激活 → cancel(.escape) 并吞掉（drag 中 ESC 不落入键盘控制器）。
        if event.type == .keyDown, event.keyCode == 53 {
            // T-1F-B10-regression-fix §2.2 B1（REPORT §15 ④）：ESC 打断 → 清手动投递记录
            // （防 stale；门控关时记录恒 nil，零行为变更）。原 ESC 语义（onEscapeDuringDrag
            // 判定吞点 / 放行键盘控制器）逐字不变。
            lastManualMouseDownCell = nil
            if let onEscapeDuringDrag, MainActor.assumeIsolated({ onEscapeDuringDrag() }) {
                return
            }
        }
        // T-1F-B10-regression-fix §2.1 取证（E6b）：事件元数据中性观测——mouseDown 家族
        // （leftMouseDown/rightMouseDown/otherMouseDown）每点击记录 type/subtype/buttonNumber
        // 三中性 int（编码进 sink 名，仅入内存 snapshot；stderr 只打 sink 名+计数，无坐标/
        // 无窗口标题/无应用名，隐私 A/B/C）。判别（BUG10-REGRESSION-REPORT §10 E6b）：
        // subtype≠0 或 type≠leftMouseDown → 非正常事件 → c/j 系统拦截。
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            ClickCensus.observeEventMetadata(
                type: event.type.rawValue,
                subtype: event.subtype.rawValue,
                buttonNumber: event.buttonNumber)
        default:
            break
        }
        // T-1F-B10-regression-fix §2.1 取证：投递探针（只读观测，零行为变更）。记录
        // 「窗口手动 hitTest 结果」vs「AppKit 内部路由目标」的类名链（ClickDeliveryProbeView
        // 为 contentView 时生效；非探针 contentView 下全部 no-op，行为与既有完全一致）。
        var deliveryProbe: ClickDeliveryProbeView?
        var observedManualHit = false
        if event.type == .leftMouseDown {
            // T-1F-B10-regression-fix §2.1 取证（E1）：event 窗口归属一致性中性观测——
            // event.windowNumber vs self.windowNumber vs NSApp.keyWindow?.windowNumber
            // 三者一致性布尔位（仅计数 + 布尔，零行为变更；隐私 A/B/C：窗口号码只在
            // 进程内做相等比较，绝不出现在 sink 名/输出中，禁窗口身份/标题/坐标原文）。
            // 判别（BUG10-REGRESSION-REPORT §9 E1）：任一不一致 → 命中候选 e。
            ClickCensus.observeWindowOwnership(
                eventWindowNumber: event.windowNumber,
                selfWindowNumber: windowNumber,
                keyWindowNumber: NSApp.keyWindow?.windowNumber)
            // T-1F-B10-regression-fix §2.1 取证（E5-fix）：命中视图缓存失效对照——直接读
            // PagingSurface.layoutPerformedCount（冻结树 :169 public private(set)，只读不调用）
            // 替代已降级的 E5 funnel（applyPresentationUpdate 计数点已移除）；本点击与上一次
            // leftMouseDown 之间的计数增量 > 0 = 发生过 relayout（中性布尔，零行为变更）。
            // 判别：s18_internal_hittest_absent 与 relayout 时机强相关 → 命中候选 f。
            let layoutOpsNow = layoutPerformedCountProvider?() ?? 0
            ClickCensus.observeRelayoutSincePreviousClick(
                relayoutOccurred: layoutOpsNow - lastLayoutPerformedCountAtPreviousClick > 0)
            lastLayoutPerformedCountAtPreviousClick = layoutOpsNow
            // T-1F-B9-wave-b Stage 1 census（s8e）：窗口 key 态观测（仅计数 + 读状态，零行为变更）。
            // BUG9-REPORT §2 R5：全屏 0.3s 延迟 toggle 后 key 状态从未被观测过。sink 名携带
            // key/active 两状态位（`isKeyWindow` / `NSApp.isActive`）仅入内存 snapshot；stderr
            // 只打 sink 名+计数（无身份原则：无窗口标题/无坐标/无应用名，隐私 A/B/C）。
            ClickCensus.hit(ClickCensus.Sink.windowKeyState(
                isKeyWindow: isKeyWindow, appActive: NSApp.isActive))
            // 每次真实的鼠标左键按下都评估命中。
            if let contentView {
                deliveryProbe = contentView as? ClickDeliveryProbeView
                // 探针：把下一次 hitTest 标记为「窗口手动调用」（与 AppKit 内部路由调用区分）。
                deliveryProbe?.markNextHitTestAsManual()
                let point = contentView.convert(event.locationInWindow, from: nil)
                let hit = contentView.hitTest(point)
                observedManualHit = true
                // 设置齿轮等主面板 chrome：必须走完整 AppKit 分发（含 mouseUp→action），
                // 不能当空白隐藏，也不能只手动 mouseDown（B1）导致点一下却退出。
                if blankClickResolvesToInteractionZone(hit) {
                    PointerInputDiagnostics.record(.interactionControl)
                    super.sendEvent(event)
                    return
                }
                if !blankClickResolvesToCell(hit, at: point, in: contentView) {
                    PointerInputDiagnostics.record(.blankHit)
                    // T-1F-B8-wave-c census（S8）：空白命中计数点（仅计数）。
                    ClickCensus.hit(ClickCensus.Sink.windowBlankUnclassified)
                    // Phase 1F：空白 mouseDown 且 drag 激活 → cancel(.escape) 并吞掉（防御；
                    // 正常不可能）。T-1F-B7-wave-c 收窄：drag cancel 仅评估**空白命中**——
                    // cell 命中（含活动会话内的第二次 pointerDown）放行 super，由 coordinator
                    // secondDrag 仲裁处理，不再被窗口层吞掉（曾致 cell 单击静默丢失）。
                    if let onDragActiveCancel, MainActor.assumeIsolated({ onDragActiveCancel() }) {
                        // T-1F-B8-wave-c census（S8）：drag 激活吞点计数点（仅计数）。
                        ClickCensus.hit(ClickCensus.Sink.windowDragActiveSwallow)
                        return
                    }
                    // T-1E-E：folder 打开 → 打开层是显式 interaction zone（点击关闭 folder，
                    // 不退出）。事件放行给打开层（FolderOverlayView.mouseDown → handleClick →
                    // onRequestClose → closeFolder）。folder 关闭后下一次真实背景单击才退出。
                    if let folderOpenState = MainActor.assumeIsolated({ folderOpenStateProvider?() }),
                       folderOpenState.isOpen {
                        PointerInputDiagnostics.record(.folderNativeDown)
                        super.sendEvent(event)
                        return
                    }
                    // 空白背景：
                    // - 搜索激活 → 退出搜索（清 query / 恢复目录 / 恢复焦点），吞掉本点击，应用保持存活；
                    // - 搜索未激活 → 维持既有空白退出（终止）。
                    if let exitSearch = onBlankClickShouldExitSearch,
                       MainActor.assumeIsolated({ exitSearch() }) {
                        return
                    }
                    // 空白 + 搜索未激活 → 既有空白退出（终止），吞掉本点击。
                    // T-1F-B8-wave-c census（S8）：terminate 通路计数点（仅计数）。
                    ClickCensus.hit(ClickCensus.Sink.windowBlankTerminate)
                    onBlankClick?()
                    return
                } else {
                    // T-1F-B8-wave-c census（S8）：cell 命中放行 super 计数点（仅计数）。
                    ClickCensus.hit(ClickCensus.Sink.windowCellPassthrough)
                    // T-1F-B10-regression-fix §2.2 B1（REPORT §15 ①；**生产路径，默认开**）：
                    // `PAGING_CLICK_MANUAL_DELIVERY=1` 且命中 cell → 手动投递给真实
                    // `AppGridCellView` ancestor + 记录 `lastManualMouseDownCell`
                    // （weak）→ return（不调 super）。与 E4 探针门分离：本分支含 up/dragged
                    // 闭环（sendEvent 顶部投递到记录视图），消除 E4-B 运行「手动 down 后无
                    // mouseUp 投递、state 卡 .pressed」死态。两门同开时 **B1 优先**（E4 分支
                    // 不执行）——行为确定可测。未设 env 时本分支默认进入；显式 env=0 才走
                    // super.sendEvent 对照路径。
                    if B1ManualDeliveryGate.isEnabled {
                        if let cell = appGridCellAncestor(hit) {
                            PointerInputDiagnostics.record(.b1Down)
                            lastManualMouseDownCell = cell
                            cell.mouseDown(with: event)
                        }
                        return
                    }
                    // T-1F-B10-regression-fix §2.1 第 4 项（E4）：env 门控手动投递 A/B 实验。
                    // **仅供诊断 A/B 实验，禁止作为生产路径常驻。** `PAGING_CLICK_PROBE_MANUAL_DELIVERY=1`
                    // 时，在放行 super.sendEvent 之前手动 `hit?.mouseDown(with: event)` 并 return
                    // （不调 super）——判别断点在 AppKit 内部分发层 vs 事件/视图链自身（REPORT
                    // §14：A1 证 subtype=0 亦死 → h 候选；E4 二分：结果 A = 手动投递触发 s10 →
                    // 事件与视图链健全、断点纯在 AppKit 分发；结果 B = 仍零 → 事件被标记 handled
                    // / 命中视图非 cell → 升级「重建事件 + 手动投递」）。默认未设 env = 本分支
                    // 不进，走既有 super.sendEvent 生产路径逐字不变（s8d / s18 absent+present 记账照旧）。
                    if E4ManualDeliveryGate.isEnabled {
                        ClickCensus.hit(ClickCensus.Sink.e4ManualDelivery)
                        hit?.mouseDown(with: event)
                        return
                    }
                }
            }
        }
        // 探针：仅对放行 super 的 leftMouseDown 观测 AppKit 内部路由——super.sendEvent 前后
        // 对照内部 hitTest 调用计数：未增 = AppKit 未咨询视图树（投递目标来自其他来源，
        // 如 tracking 缓存/坐标系基准失配 → 锁定 BUG10-REGRESSION-REPORT §3.2 候选 ①）。
        if observedManualHit {
            deliveryProbe?.beginInternalObservation()
        }
        let internalHitTestBefore = deliveryProbe?.internalHitTestCallCount
        super.sendEvent(event)
        if observedManualHit, let deliveryProbe, let before = internalHitTestBefore {
            deliveryProbe.endInternalObservation()
            if deliveryProbe.internalHitTestCallCount == before {
                ClickCensus.hit(ClickCensus.Sink.deliveryProbeInternalHitTestAbsent)
            } else {
                ClickCensus.hit(ClickCensus.Sink.deliveryProbeInternalHitTestPresent)
            }
        }
    }
}

// MARK: - T-1F-B10-regression-fix §2.1 取证：窗口内部投递目标探针（只读观测，零行为变更）

/// 窗口 contentView 链上的只读投递探针（T-1F-B10-regression-fix §2.1.1）：
/// 记录「窗口手动 hitTest 结果」vs「AppKit 内部路由目标」的类名链，判别事件在窗口层与
/// cell 之间被整体吞掉的机制（BUG10-REGRESSION-REPORT §3.2 候选 ①：窗口内部投递目标与
/// sendEvent 覆盖层手动 `contentView.hitTest` 不同源）。
///
/// - 中性：只记 `type(of:)` 类名链（禁坐标/身份/标题，隐私 A/B/C）。
/// - 零行为变更：`hitTest`/`mouseDown` 均原样转发 super，返回值/响应链与普通 NSView 完全一致；
///   非探针 contentView 下（`contentView as? ClickDeliveryProbeView` 为 nil）零观测零影响。
/// - 计数：经 `ClickCensus.hit`（内存计数恒维护；env `PAGING_CLICK_CENSUS=1` 时 stderr 输出）。
/// - 挂载：作为窗口 contentView（AppDelegate :208 容器；全屏过渡不替换 contentView，探针常驻）。
final class ClickDeliveryProbeView: NSView {
    /// Host-owned chrome follows actual bounds changes, independently of paging layout.
    var onLayout: (() -> Void)?

    override func layout() {
        super.layout()
        onLayout?()
    }

    /// 透出壁纸：contentView 不得声明不透明。
    override var isOpaque: Bool { false }

    /// 类名链最大深度（命中视图 → 沿 superview 链向上至本探针；封顶防 sink 名过长）。
    private static let maxChainDepth = 8

    /// 下一次 hitTest 调用标记为「窗口手动调用」（sendEvent 在手动 hitTest 前设置；调用即消费）。
    private var nextHitTestIsManual = false
    /// 内部路由观测窗（sendEvent 放行 super 前开启、super.sendEvent 返回后关闭）。
    private var observingInternalRouting = false
    /// 观测窗内 AppKit 内部路由 hitTest 调用计数（sendEvent 前后对照判「未咨询视图树」）。
    private(set) var internalHitTestCallCount = 0

    /// sendEvent 手动 hitTest 前调用：把下一次 hitTest 标记为 manual（窗口自身调用）。
    func markNextHitTestAsManual() {
        nextHitTestIsManual = true
    }

    /// sendEvent 放行 `super.sendEvent` 前调用：开启内部路由观测窗。
    func beginInternalObservation() {
        observingInternalRouting = true
    }

    /// `super.sendEvent` 返回后调用：关闭内部路由观测窗。
    func endInternalObservation() {
        observingInternalRouting = false
    }

    /// 命中视图 → 类名链（中性：仅 `type(of:)` 字符串，沿 superview 向上至本探针，封顶）。
    private static func chainString(from view: NSView?, stoppingAt selfView: NSView) -> String {
        guard let view else { return "nil" }
        var names: [String] = []
        var node: NSView? = view
        while let current = node, names.count < maxChainDepth {
            names.append(String(describing: type(of: current)))
            if current === selfView { break }
            node = current.superview
        }
        return names.joined(separator: "_")
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        let result = super.hitTest(point)
        if nextHitTestIsManual {
            nextHitTestIsManual = false
            ClickCensus.hit(ClickCensus.Sink.deliveryProbeManualHitChain(
                chain: Self.chainString(from: result, stoppingAt: self)))
        } else if observingInternalRouting {
            internalHitTestCallCount += 1
            ClickCensus.hit(ClickCensus.Sink.deliveryProbeInternalHitChain(
                chain: Self.chainString(from: result, stoppingAt: self)))
        }
        return result
    }

    public override func mouseDown(with event: NSEvent) {
        // AppKit 把 mouseDown 投递给 contentView 自身（内部路由目标 = 容器；Chief 候选之一）。
        ClickCensus.hit(ClickCensus.Sink.deliveryProbeDeliveredToContentView)
        super.mouseDown(with: event)
    }

    // T-1F-B10-regression-fix §2.1 取证（E6a）：探针投递观测——mouseUp/mouseDragged/
    // rightMouseDown/otherMouseDown 纯转发 census（中性计数，隐私合规；转发 super 原样，
    // 返回值/响应链与普通 NSView 完全一致，零行为变更）。判别（BUG10-REGRESSION-REPORT
    // §10 E6a）：探针收 mouseDown → 投递目标=contentView（滞留跟踪会话）→ 命中 g/f；
    // 只收 mouseUp 不收 mouseDown → 事件对被拆散 → 识别器滞留（b/f 系）；两者皆零 →
    // 窗口级消费（h）。

    public override func mouseUp(with event: NSEvent) {
        ClickCensus.hit(ClickCensus.Sink.deliveryProbeMouseUp)
        super.mouseUp(with: event)
    }

    public override func mouseDragged(with event: NSEvent) {
        ClickCensus.hit(ClickCensus.Sink.deliveryProbeMouseDragged)
        super.mouseDragged(with: event)
    }

    public override func rightMouseDown(with event: NSEvent) {
        ClickCensus.hit(ClickCensus.Sink.deliveryProbeRightMouseDown)
        super.rightMouseDown(with: event)
    }

    public override func otherMouseDown(with event: NSEvent) {
        ClickCensus.hit(ClickCensus.Sink.deliveryProbeOtherMouseDown)
        super.otherMouseDown(with: event)
    }
}

/// 空白-vs-cell 命中分类（T-1C-D repair）：命中视图链（含 icon/label 子视图）是否含 AppGridCellView。
/// 供 `QuitOnBlankClickWindow.sendEvent` 与单测（blank-vs-cell）共用；纯视图逻辑、无副作用。
/// T-1D-E：搜索 field/editor/clear button 是显式 "interaction zone"（ADR-007 §2.7）——
/// 点击它们不触发空白单击退出；真实背景空白仍首击退出。
/// 主面板 chrome（设置齿轮等）：空白点击不得吞掉。
func blankClickResolvesToLauncherChrome(_ hit: NSView?) -> Bool {
    var node = hit
    while let current = node {
        let id = current.identifier?.rawValue ?? ""
        if id.hasPrefix("launchcopy.chrome.") { return true }
        if current is NSButton, id == "launchcopy.launcherSettingsButton" { return true }
        node = current.superview
    }
    return false
}

/// Returns the owning cell for a hit inside an icon, label, or other cell descendant.
/// The returned view is the only valid B1 manual-delivery target because its mouse handlers
/// enter `DragUISessionCoordinator`.
func appGridCellAncestor(_ hit: NSView?) -> AppGridCellView? {
    var node = hit
    while let current = node {
        if let cell = current as? AppGridCellView {
            return cell
        }
        node = current.superview
    }
    return nil
}

/// Explicit controls must retain normal AppKit down/up/action delivery. This is deliberately
/// separate from `blankClickResolvesToCell`, whose boolean contract also covers interaction zones.
func blankClickResolvesToInteractionZone(_ hit: NSView?) -> Bool {
    AppSearchFieldView.isSearchFieldOrSubview(hit) || blankClickResolvesToLauncherChrome(hit)
}

func blankClickResolvesToCell(_ hit: NSView?, at point: NSPoint? = nil, in rootView: NSView? = nil) -> Bool {
    // 搜索 field/editor/clear button → interaction zone（不退出）。
    if blankClickResolvesToInteractionZone(hit) {
        return true
    }
    if let cell = appGridCellAncestor(hit) {
            if let point, let rootView,
               !cell.acceptsLaunchHit(at: cell.convert(point, from: rootView)) {
                return false
            }
            // 命中链是否含 FolderOverlayView：从被命中 cell 沿祖先链向上检查（overlay 是
            // cell 的祖先；「cell 在 overlay 内」= 成员 cell，祖先链含打开层）。
            var ancestor = cell.superview
            var chainHasOverlay = false
            while let parent = ancestor {
                if parent is FolderOverlayView {
                    chainHasOverlay = true
                    break
                }
                ancestor = parent.superview
            }
            // T-1F-B10-wave-a forensics census（s17）：返回 true 时命中链是否含
            // FolderOverlayView 的布尔位（仅计数，零行为变更）。判别「cell 在 overlay 内
            // vs 在 grid 内」关键位：_ov1 = 命中链经 overlay（成员 cell 在打开层内——
            // 窗口层判 cell 放行 super，但 AppKit 事件仍可能被 overlay.hitTest 吞掉）；
            // _ov0 = cell 在 grid 内（健康路径）。sink 名只携带布尔位，无身份。
            ClickCensus.hit(ClickCensus.Sink.blankHitChainHasOverlay(hasOverlay: chainHasOverlay))
            return true
    }
    return false
}

// MARK: - T-1F-B9-wave-b Stage 1 census sink 声明（任务包 §3：可放 AppDelegate.swift 同文件）

/// s8e/s13 sink（仅命名空间声明；计数机制与 env 门控沿用 `ClickCensus`，本文件零机制改动）。
extension ClickCensus.Sink {
    /// s8e 基名：窗口 key 态观测（QuitOnBlankClickWindow.sendEvent leftMouseDown 处）。
    /// 实际 sink 为基名 + `_key{n}_active{n}` 状态位变体（`isKeyWindow` / `NSApp.isActive`），
    /// 状态位仅随 sink 名入内存 snapshot；stderr 只打 sink 名+计数（无身份：无窗口标题/
    /// 无坐标/无应用名，隐私 A/B/C）。
    public static let windowKeyStateBase = "s8e_window_key_state"

    /// s8e 状态位 sink 名（两 bool → 四变体；变体名不含任何身份信息）。
    public static func windowKeyState(isKeyWindow: Bool, appActive: Bool) -> String {
        "\(windowKeyStateBase)_key\(isKeyWindow ? 1 : 0)_active\(appActive ? 1 : 0)"
    }

    /// s13a：抑制闭包启用向（闭包收到 enabled = false → 抑制开启；AppDelegate.installDragUI 闭包；
    /// 与 coordinator beginArbitration → suppressor(false) 对应）。
    public static let suppressionEnable = "s13a_enable"

    /// s13b：抑制闭包恢复向（闭包收到 enabled = true → endSession 恢复；与 s9b_endsession_restored 对照）。
    public static let suppressionDisable = "s13b_disable"
}

// MARK: - T-1F-B10-wave-a forensics census sink 声明（AppDelegate 层布点；仅命名空间声明，
// 计数机制与 env 门控沿用 `ClickCensus`，本文件零机制改动）

extension ClickCensus.Sink {
    /// s16 基名：closeFolder 执行后 overlay 的 superview 状态（AppDelegate.closeFolder 末行）。
    /// 实际 sink 为基名 + `_sv1`/`_sv0` 布尔位变体（`overlay.superview == nil`），
    /// 状态位仅随 sink 名入内存 snapshot；stderr 只打 sink 名+计数（无身份，隐私 A/B/C）。
    public static let closeFolderOverlayStateBase = "s16_closefolder_overlay_state"

    /// s16 状态位 sink 名（superview.nil → _sv1；superview 非 nil → _sv0）。
    public static func closeFolderOverlayState(superviewIsNil: Bool) -> String {
        "\(closeFolderOverlayStateBase)_sv\(superviewIsNil ? 1 : 0)"
    }

    /// s17 基名：blankClickResolvesToCell 返回 true 时命中链是否含 FolderOverlayView。
    /// 实际 sink 为基名 + `_ov1`/`_ov0` 布尔位变体（链中是否出现打开层），
    /// 状态位仅随 sink 名入内存 snapshot；stderr 只打 sink 名+计数（无身份，隐私 A/B/C）。
    public static let blankHitChainHasOverlayBase = "s17_blankhit_chain_has_overlay"

    /// s17 状态位 sink 名（链含 overlay → _ov1；不含 → _ov0）。
    public static func blankHitChainHasOverlay(hasOverlay: Bool) -> String {
        "\(blankHitChainHasOverlayBase)_ov\(hasOverlay ? 1 : 0)"
    }
}

// MARK: - T-1F-B10-regression-fix §2.1 census sink 声明（窗口投递探针；仅命名空间声明，
// 计数机制与 env 门控沿用 `ClickCensus`，本文件零机制改动）

extension ClickCensus.Sink {
    /// s18 基名：窗口手动 hitTest 结果类名链（sendEvent 手动调用；链 = `type(of:)` 类名沿
    /// superview 向上至探针，"_" 连接，封顶 8 层）。sink 名只含类名（中性，隐私 A/B/C）。
    public static let deliveryProbeManualHitChainBase = "s18_hit_manual_chain"

    /// s18 手动 hitTest 结果链 sink 名（链编码进 sink 名；每链独立计数）。
    public static func deliveryProbeManualHitChain(chain: String) -> String {
        "\(deliveryProbeManualHitChainBase)_\(chain)"
    }

    /// s18 基名：AppKit 内部路由 hitTest 结果类名链（super.sendEvent 期间的非手动调用）。
    public static let deliveryProbeInternalHitChainBase = "s18_hit_internal_chain"

    /// s18 内部路由 hitTest 结果链 sink 名。
    public static func deliveryProbeInternalHitChain(chain: String) -> String {
        "\(deliveryProbeInternalHitChainBase)_\(chain)"
    }

    /// s18：AppKit 把 mouseDown 投递给 contentView 自身（探针 mouseDown 到达；Chief 候选
    /// 「containerView」的直接证据）。
    public static let deliveryProbeDeliveredToContentView = "s18_delivered_contentview"

    /// s18：leftMouseDown 放行 super.sendEvent 后未观察到任何内部 hitTest 调用
    /// （AppKit 未咨询视图树 → 投递目标来自其他来源，如 tracking 缓存/坐标系基准失配）。
    public static let deliveryProbeInternalHitTestAbsent = "s18_internal_hittest_absent"

    /// s18：leftMouseDown 放行 super.sendEvent 后观察到 ≥1 次内部 hitTest 调用。
    public static let deliveryProbeInternalHitTestPresent = "s18_internal_hittest_present"
}

// MARK: - T-1F-B10-regression-fix §2.1 取证 E6a/E6b sink 声明与观测（仅命名空间声明 +
// 纯观测 helper；计数机制与 env 门控沿用 `ClickCensus`，本文件零机制改动）

extension ClickCensus.Sink {
    /// E6a（探针投递观测，BUG10-REGRESSION-REPORT §10 E6a）：ClickDeliveryProbeView
    /// （contentView）mouseUp 纯转发 census（中性计数，隐私合规）。
    public static let deliveryProbeMouseUp = "sE6a_probe_mouseup"
    /// E6a：mouseDragged 纯转发 census。
    public static let deliveryProbeMouseDragged = "sE6a_probe_mousedragged"
    /// E6a：rightMouseDown 纯转发 census。
    public static let deliveryProbeRightMouseDown = "sE6a_probe_rightmousedown"
    /// E6a：otherMouseDown 纯转发 census。
    public static let deliveryProbeOtherMouseDown = "sE6a_probe_othermousedown"

    /// E6a''（分发入口监视，任务包 §2.1 步骤 4）：local monitor 收到 leftMouseDown。
    public static let monitorMouseDown = "sE6_monitor_down"
    /// E6a''：local monitor 收到 leftMouseUp。
    public static let monitorMouseUp = "sE6_monitor_up"

    /// E6b 基名（事件元数据，BUG10-REGRESSION-REPORT §10 E6b）：每点击记录
    /// `event.type.rawValue`/`subtype.rawValue`/`buttonNumber` 三中性 int，编码进 sink 名
    /// `sE6b_meta_type_<t>_subtype_<s>_button_<b>`。仅入内存 snapshot；stderr 只打
    /// sink 名+计数（无坐标/无窗口标题/无应用名，隐私 A/B/C）。判别：subtype≠0 或
    /// type≠leftMouseDown → 非正常事件 → c/j 系统拦截。
    public static let eventMetadataBase = "sE6b_meta"
    /// E6b 状态位 sink 名（type/subtype/buttonNumber 三中性 int 编码）。
    public static func eventMetadata(type: UInt, subtype: Int16, buttonNumber: Int) -> String {
        "\(eventMetadataBase)_type_\(type)_subtype_\(subtype)_button_\(buttonNumber)"
    }
}

// MARK: - T-1F-B10-regression-fix §2.1 第 4 项（E4）sink 声明（env 门控手动投递 A/B 实验；
// 仅命名空间声明，计数机制与 env 门控沿用 `ClickCensus`，本文件零机制改动）

extension ClickCensus.Sink {
    /// E4（手动投递 A/B 实验，任务包 §2.1 第 4 项 / REPORT §9 E4）：门控
    /// `PAGING_CLICK_PROBE_MANUAL_DELIVERY=1` 开启且 cell 命中时，手动投递分支执行
    /// （仅计数，中性；**仅供诊断，禁止作为生产路径常驻**）。判别：
    /// `sE4_manual_delivery` > 0 且 `s10` > 0 = 结果 A（事件与视图链健全，断点在 AppKit
    /// 分发）；`sE4_manual_delivery` > 0 且 `s10` == 0 = 结果 B（升级「重建事件 + 手动投递」）。
    /// 门控关时恒 0。
    public static let e4ManualDelivery = "sE4_manual_delivery"
}

extension ClickCensus {
    /// E6b 观测（仅计数；零行为变更）：记录一次 mouseDown 家族事件的 type/subtype/
    /// buttonNumber 三中性 int（编码进 sink 名；数值仅入内存 snapshot，stderr 只打
    /// sink 名+计数）。入参为 `NSEvent.EventType.rawValue`（UInt）、
    /// `NSEvent.EventSubtype.rawValue`（Int16）、`event.buttonNumber`（Int）。
    static func observeEventMetadata(type: UInt, subtype: Int16, buttonNumber: Int) {
        ClickCensus.hit(ClickCensus.Sink.eventMetadata(
            type: type, subtype: subtype, buttonNumber: buttonNumber))
    }

    /// E6a'' 观测（仅计数；零行为变更）：local monitor 收到 mouseDown 家族事件时调用
    /// （monitor 匹配面 = [.leftMouseDown, .leftMouseUp]，故仅两型可达）。
    static func observeMonitorEvent(type: NSEvent.EventType) {
        ClickCensus.hit(type == .leftMouseDown
            ? ClickCensus.Sink.monitorMouseDown
            : ClickCensus.Sink.monitorMouseUp)
    }
}

// MARK: - T-1F-B10-regression-fix §2.1 取证 E1/E5 sink 声明与观测（仅命名空间声明 +
// 纯观测 helper；计数机制与 env 门控沿用 `ClickCensus`，本文件零机制改动）

extension ClickCensus.Sink {
    /// E1（窗口归属一致性，BUG10-REGRESSION-REPORT §9 E1）：event / self / keyWindow 三者
    /// 窗口号码完全一致 → match。sink 名只携带一致/不一致布尔位；窗口号码只在进程内做相等
    /// 比较，绝不出现在 sink 名/输出中（隐私 A/B/C：禁窗口号码/标题/坐标/身份原文）。
    public static let windowOwnerMatch = "sE1_window_owner_match"
    /// E1：event.windowNumber != self.windowNumber（事件窗口号码与宿主窗口不一致）。
    public static let windowOwnerMismatchEvSelf = "sE1_window_owner_mismatch_evSelf"
    /// E1：event.windowNumber != NSApp.keyWindow?.windowNumber（事件与 key 窗口号码不一致）。
    public static let windowOwnerMismatchEvKey = "sE1_window_owner_mismatch_evKey"
    /// E1：self.windowNumber != NSApp.keyWindow?.windowNumber（宿主与 key 窗口号码不一致；
    /// 含 keyWindow 为 nil 的情形）。
    public static let windowOwnerMismatchSelfKey = "sE1_window_owner_mismatch_selfKey"

    /// E5-fix（缓存失效对照，BUG10-REGRESSION-REPORT §9 E5 / §10）：直接读
    /// `PagingSurface.layoutPerformedCount`（PagingUI 冻结树 :169 public private(set)，
    /// 只读不调用）替代已降级的 E5 funnel（applyPresentationUpdate 计数点已移除）。
    /// 基名：本点击与上一次 leftMouseDown 之间 `layoutPerformedCount` 是否增量 ≥1。
    /// 实际 sink 为基名 + `_yes`/`_no` 布尔位变体（仅布尔，无身份）。
    public static let relayoutBetweenClicksBase = "sE5_relayout_between_clicks"
    /// E5-fix 状态位 sink 名（两次点击间有 relayout → _yes；无 → _no）。
    public static func relayoutBetweenClicks(_ occurred: Bool) -> String {
        "\(relayoutBetweenClicksBase)_\(occurred ? "yes" : "no")"
    }
}

extension ClickCensus {
    /// E1 观测（仅计数 + 布尔位；零行为变更，不改任何分支条件）：
    /// event / self / keyWindow 三者窗口号码一致性。入参号码仅在进程内做相等比较，
    /// 绝不出现在 sink 名/输出中（隐私 A/B/C）。判别：任一不一致 → 候选 e。
    static func observeWindowOwnership(eventWindowNumber: Int,
                                       selfWindowNumber: Int,
                                       keyWindowNumber: Int?) {
        let evSelfConsistent = eventWindowNumber == selfWindowNumber
        let evKeyConsistent = eventWindowNumber == keyWindowNumber
        let selfKeyConsistent = selfWindowNumber == keyWindowNumber
        if evSelfConsistent && evKeyConsistent && selfKeyConsistent {
            ClickCensus.hit(ClickCensus.Sink.windowOwnerMatch)
        } else {
            if !evSelfConsistent { ClickCensus.hit(ClickCensus.Sink.windowOwnerMismatchEvSelf) }
            if !evKeyConsistent { ClickCensus.hit(ClickCensus.Sink.windowOwnerMismatchEvKey) }
            if !selfKeyConsistent { ClickCensus.hit(ClickCensus.Sink.windowOwnerMismatchSelfKey) }
        }
    }

    /// E5 观测（仅计数；零行为变更）：两次 leftMouseDown 之间是否发生已知布局触发
    /// （sendEvent 处由窗口基线计数差分后调用；`relayoutOccurred` 为中性布尔）。
    static func observeRelayoutSincePreviousClick(relayoutOccurred: Bool) {
        ClickCensus.hit(ClickCensus.Sink.relayoutBetweenClicks(relayoutOccurred))
    }
}


// The composition root emits a diagnostic-only snapshot under the same private
// gate. Expose its read-only value rather than widening the gate type's access.
extension QuitOnBlankClickWindow {
    static var isManualDeliveryProbeEnabled: Bool { E4ManualDeliveryGate.isEnabled }
}
