// AppGridUI — DragUI.DragUISessionCoordinator（Phase 1F §5.1–5.7 / ADR-010）
// 实现：T-1F-D1（Worker）。
//
// 统一输入仲裁协调器：把 AppKit 指针事件（mouseDown/mouseDragged/mouseUp）桥接到
// 已合并的纯 DragSession 域（DragSessionController），D 层只做薄壳：
// 坐标转换、源身份解析、几何提供、seam 派发、edge timer 调度、click 识别抑制。
//
// - 硬门：pointer-down 只能进 `.pressed`；click/open/launch 只在 mouse-up 未过阈值时派发；
//   drag 绝不启动 app / 打开 folder（仲裁窗口内抑制既有 NSClickGestureRecognizer）。
// - 边缘翻页：topLevel scope → KeyboardPageTurner seam；folder scope → overlay 翻页 seam。
// - commit：DragMutationEngine 成功后经 onCommit seam 交出新布局（T-1F-E 接 provider/persist）。
// - 统一 cancel 全路径（每个 DragCancelReason）→ 零写盘、零 preview/edge-timer/gesture 残留。
// - 隐私：无任何输出；token 进程内唯一驻留（ADR-010 Q9）；不触碰 pasteboard。
//
// 线程模型：视图主线程（MainActor）受限；edge Timer 在 main run loop common mode 调度。

import AppCatalogCore
import AppKit
import Foundation
import PagingUI

// MARK: - 中性 click census（T-1F-B8-wave-c Stage 1 取证装置）

/// 中性 click census（T-1F-B8-wave-c Stage 1）：静默门/派发点**仅递增计数**，
/// 无身份/无标题/无路径。内存计数恒维护（测试经 `@testable` 读取/重置；
/// 诊断可经 `snapshot()` 全量读取）；stderr 逐条输出仅在 env
/// `PAGING_CLICK_CENSUS=1` 时启用（默认关 = 零输出）。
public enum ClickCensus {

    /// 稳定 sink 名（结果文件 census 表列名；注释中的行号为 2026-09-02 现行行号）。
    public enum Sink {
        /// DragUISessionCoordinator.swift:104 teardown 后指针事件被拒。
        public static let pointerDownTornDown = "s0_pd_torndown"
        /// DragUISessionCoordinator.swift:105 dragGate 关闭（搜索激活/标题编辑；N2 面：注释称“点击不受影响”）。
        public static let dragGateClosed = "s1_draggate_closed"
        /// DragUISessionCoordinator.swift:106 visualHost nil。
        public static let visualHostNil = "s2_visualhost_nil"
        /// DragUISessionCoordinator.swift:121 layoutProvider nil（pointerDown 在 controller 之前被拒）。
        public static let layoutProviderNil = "s3_layoutprovider_nil"
        /// DragUISessionCoordinator.swift:117-118 resolveSource nil 且 sourceCell==nil（真空白按下）。
        public static let pendingBlankNoCell = "s4a_pendingblank_nocell"
        /// DragUISessionCoordinator.swift:117-118 resolveSource nil 且 sourceCell≠nil（N3 死路 A 证据）。
        public static let pendingBlankWithCell = "s4b_pendingblank_withcell"
        /// DragUISessionCoordinator.swift:129-131 stale source 回退武装（Defect-3 健康路径）。
        public static let fallbackArmed = "s4c_fallback_armed"
        /// DragUISessionCoordinator.swift:181-184 blank 分支派发 onOverlayBlankClick（N1 面本身）。
        public static let blankBranchDispatch = "s4d_blankbranch_dispatch"
        /// DragUISessionCoordinator.swift:181 blank 分支执行时抑制仍 true（N1 滞留形成点：分支无 endSession）。
        public static let blankBranchWhileSuppressed = "s4e_blankbranch_suppressed"
        /// DragUISessionCoordinator.swift:188-198 fallback 分支派发（内含 endSession，健康对照）。
        public static let fallbackDispatch = "s4f_fallback_dispatch"
        /// DragUISessionCoordinator.swift:202 pointerUp 时 controller 已 idle → 吞点。
        public static let pointerUpIdleSwallow = "s5_up_idle_swallow"
        /// dispatchClick → onCellClick（Path B click 派发到达装配层）。
        public static let dispatchClickCell = "s6_dispatch_click_cell"
        /// dispatchClick → onOverlayBlankClick（Path B blank 派发）。
        public static let dispatchClickBlank = "s6b_dispatch_click_blank"
        /// AppDelegate.handleDragCellClick :655/:660 if-let 静默（cast 失败即吞）。
        public static let handleClickSilent = "s7_handleclick_silent"
        /// AppDelegate.launchMember :764-765 guard 静默（无 launchController/assembly 或无 servedRevision）。
        public static let launchMemberSilent = "s7b_launchmember_silent"
        /// QuitOnBlankClickWindow.sendEvent :1040 命中未分类为 cell（空白命中）。
        public static let windowBlankUnclassified = "s8_window_blank_unclassified"
        /// QuitOnBlankClickWindow.sendEvent :1045 空白命中 + drag 激活 → 吞点。
        public static let windowDragActiveSwallow = "s8b_window_dragactive_swallow"
        /// QuitOnBlankClickWindow.sendEvent :1064 空白命中 → onBlankClick（terminate 通路）。
        public static let windowBlankTerminate = "s8c_window_blank_terminate"
        /// QuitOnBlankClickWindow.sendEvent cell 命中放行 super（AppKit 路由 → cell.mouseDown/recognizer）。
        public static let windowCellPassthrough = "s8d_window_cell_passthrough"
        /// 抑制滞留（N1 观测）：pointerDown 入口时抑制标志仍 true 而无任何活会话
        /// （controller idle 且无 pendingBlankPress）→ 上一会话泄漏的滞留。
        public static let suppressionResident = "s9_leak_suppression_resident"
        /// endSession 实际执行了抑制恢复（健康对照；与 s9_leak 对照判读）。
        public static let endSessionRestored = "s9b_endsession_restored"
        /// AppLaunchController 通路拒绝（前缀 + 具体中性 outcome 名，如 …_rejectedStaleRevision）。
        public static let launchRejectedPrefix = "sA_launch_rejected_"
        /// AppLaunchController 通路 .launched（基线）。
        public static let launchAccepted = "sA_launch_accepted"
        /// folder 拖拽诊断（2026-09-07）：geometryProvider(folder) 返回 nil →
        /// pointerDragged/pointerUp 静默 return / cancel(.teardown)（无 commit）。
        public static let dragGeometryNil = "s20_drag_geometry_nil"
        /// folder 拖拽诊断：controller 进入 .dragging（真实拖拽开始）。
        public static let dragBegan = "s20_drag_began"
        /// folder 拖拽诊断：intent 分类结果为 .invalid（→ consume reject）。
        public static let dragIntentInvalid = "s20_drag_intent_invalid"
        /// folder 拖拽诊断：drop 提交成功（.committed）。
        public static let dragCommitted = "s20_drag_committed"
        /// folder 拖拽诊断：drop no-op（落点换算回到原位 → 无变化）。
        public static let dragNoOp = "s20_drag_noop"
        /// folder 拖拽诊断：drop 被拒（.rejected）。
        public static let dragRejected = "s20_drag_rejected"
    }

    private static let lock = NSLock()
    private static var counts: [String: Int] = [:]
    private static let stderrEnabled =
        ProcessInfo.processInfo.environment["PAGING_CLICK_CENSUS"] == "1"

    /// 记一次 sink 命中（仅计数；env 开启时向 stderr 输出一行 `PAGING_CLICK_CENSUS <sink> <n>`）。
    public static func hit(_ sink: String) {
        lock.lock()
        counts[sink, default: 0] += 1
        let n = counts[sink] ?? 0
        lock.unlock()
        if stderrEnabled {
            FileHandle.standardError.write(Data("PAGING_CLICK_CENSUS \(sink) \(n)\n".utf8))
        }
    }

    /// 读取单个 sink 计数（测试断言用）。
    public static func count(_ sink: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return counts[sink] ?? 0
    }

    /// 全量快照（内存可读；结果文件 census 表由 E 序列回填时引用）。
    public static func snapshot() -> [String: Int] {
        lock.lock(); defer { lock.unlock() }
        return counts
    }

    /// 测试专用重置（生产代码绝不调用；跨测试计数隔离）。
    public static func resetForTesting() {
        lock.lock(); counts = [:]; lock.unlock()
    }
}

/// Phase 1F：AppKit drag UI 统一输入仲裁协调器（T-1F-D1）。
@MainActor
public final class DragUISessionCoordinator {

    /// 生产装配共享实例（AppDelegate 设置/清空；cell 经 `dragCoordinator ?? shared` 查找）。
    /// 单窗口应用；测试用实例属性注入，不依赖 shared。
    public static var shared: DragUISessionCoordinator?

    // MARK: - Seams（装配层接线；测试注入）

    /// 当前已提交布局（nil = 无布局 → 不进入 drag）。
    public var layoutProvider: () -> PersistentWorkspaceLayout? = { nil }
    /// 当前 catalog generation（装配层接 servedRevision）。
    public var catalogGenerationProvider: () -> UInt64 = { 0 }
    /// 当前 catalog 快照（源身份解析；nil = 无快照 → 源解析失败）。
    public var catalogSnapshotProvider: () -> CatalogSnapshot? = { nil }
    /// 几何提供者（scope → DragGeometry；nil = 无几何 → 本次 move/up 无操作）。
    public var geometryProvider: (DragScope) -> DragGeometry? = { _ in nil }
    /// commit seam：mutation 成功 → 交出新布局（T-1F-E 接 provider/persist）。
    public var onCommit: (PersistentWorkspaceLayout) -> Void = { _ in }
    /// Computes a new-folder title from committed snapshots after drop validation.
    /// Never perform IO, present UI, or mutate owners in this synchronous policy.
    public var folderCreationTitleProvider: FolderCreationTitleProvider?
    /// cell 点击派发（mouse-up 未过阈值；app 启动 / folder 打开 / 成员激活由装配层分流）。
    public var onCellClick: (AppGridCellView) -> Void = { _ in }
    /// overlay 面板外点击（mouse-up 未过阈值；→ 关闭 folder）。
    public var onOverlayBlankClick: () -> Void = {}
    /// 顶层 scope edge turn 入口（KeyboardPageTurner 同款用法；测试注入 spy）。
    public var topLevelPageTurn: (KeyboardPageDirection, TimeInterval) -> KeyboardPageTurnResult = { _, _ in .deferred }
    /// folder scope edge turn 入口（overlay nextPage/prevPage；测试注入 spy）。
    public var folderPageTurn: (Int) -> Void = { _ in }
    /// click 识别抑制（仲裁窗口内禁用既有 NSClickGestureRecognizer；nil = 不抑制）。
    public var clickRecognitionSuppressor: ((Bool) -> Void)?
    /// drag 门（搜索激活 / 标题编辑中 → false）。N2 修正（T-1F-B8-wave-c Stage 2）：
    /// false 时整个 pointerDown 被静默拒绝——含 Path B click 派发路径（onCellClick /
    /// onOverlayBlankClick 均不达）；Path A surface 识别器不受影响。
    /// 依据：census s1_draggate_closed + harness 测试 6（testDragGateClosed…）。
    public var dragGate: () -> Bool = { true }
    /// Allows click arbitration while preventing drag initiation (for active search).
    /// The complete pointer-down gate above retains its existing semantics.
    public var dragStartGate: () -> Bool = { true }
    /// 会话状态变化（视觉/守卫/测试）。
    public var onSessionStateChange: ((DragSessionState) -> Void)?

    // MARK: - 状态

    /// 状态机（与 coordinator 同参数/同 clock 创建）。
    public let controller: DragSessionController
    /// 参数（与 controller 同源；空白点击阈值/视觉几何复用）。
    public let parameters: DragParameters
    /// 视觉宿主（preview/指示视图挂载；nil = 无视觉）。
    public weak var visualHost: NSView?
    /// 中性拖拽视觉。
    public let visuals: DragUIVisuals
    /// 是否正在仲裁（空白点击守卫 / 测试）。
    public var isSessionActive: Bool {
        hasPointerOwnership || controller.state != .idle || pendingBlankPress != nil || isClickOnlyPress
    }

    private let clock: DragClock
    private var currentScope: DragScope?
    private var sourceCell: AppGridCellView?
    private var pendingBlankPress: DragPoint?
    // A blank/fallback candidate can become ineligible without releasing the held pointer.
    private var hasPointerOwnership = false
    private var sessionEndGeneration: UInt64 = 0
    /// Defect-3 修复 + N3（T-1F-B8-wave-c Stage 2）扩展：stale-source / 解析失败点击回退。
    /// controller.pointerDown 未产生 .pressed 时武装：源被 sourcePresent 拒绝（提交后
    /// 布局已移动源），或 resolveSource 失败（bindingToken nil / 查无 record）而 sourceCell
    /// 非 nil；mouse-up 未过阈值 → onCellClick(回退 cell)；过阈值 → no-op 清除。
    private var clickFallbackCell: AppGridCellView?
    private var clickFallbackDownPoint: DragPoint?
    /// Explicit search click arbitration is active even though the drag controller stays idle.
    /// Historical stale-source fallback retains its existing non-session diagnostic semantics.
    private var isClickOnlyPress = false
    private var currentPointer: DragPoint?
    private var currentGeometry: DragGeometry?
    private var edgeTimer: Timer?
    private var scheduledEdgeDeadline: TimeInterval?
    private var isSuppressingClickRecognition = false
    /// teardown 后为终态：所有指针事件/cancel 一律 no-op（T-1F-D1 修复）。
    private var isTornDown = false

    public init(host: NSView? = nil,
                parameters: DragParameters = .default,
                clock: DragClock = SystemDragClock(),
                reduceMotionProvider: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }) {
        self.parameters = parameters
        self.clock = clock
        self.controller = DragSessionController(parameters: parameters, clock: clock)
        self.visualHost = host
        self.visuals = DragUIVisuals(host: host, reduceMotionProvider: reduceMotionProvider)
    }

    // MARK: - 视觉宿主切换（BUG10 缺陷 B，方案 B1）

    /// 切换视觉宿主：**同一动作**同时更新 `visualHost`（指针坐标系）与
    /// `visuals` 的 attach 宿主（preview/指示坐标系）——两坐标系必须同源，
    /// 否则 preview 相对指针偏移（本方案最易错点，契约测试锁死）。
    /// 生产唯一驱动点：AppDelegate.refreshFolderOverlay（folder 打开 → overlay；
    /// folder 关闭 → surface）。同值重复调用幂等。
    public func setVisualHost(_ newHost: NSView?) {
        if let oldHost = visualHost, let newHost, oldHost !== newHost, let pointer = currentPointer {
            let converted = newHost.convert(NSPoint(x: CGFloat(pointer.x), y: CGFloat(pointer.y)), from: oldHost)
            currentPointer = DragPoint(x: Double(converted.x), y: Double(converted.y))
        }
        visualHost = newHost
        visuals.setHost(newHost)
    }

    /// Capture the member while its panel is available, then elevate the durable preview.
    public func prepareAndElevateMoveOutPreview(above overlay: NSView) {
        guard !isTornDown else { return }
        visuals.capturePreview(from: sourceCell)
        elevateMoveOutPreview(above: overlay)
    }

    /// Re-elevate cached content after a host switch without reading the source cell.
    public func elevateMoveOutPreview(above overlay: NSView) {
        guard !isTornDown else { return }
        let pointer = currentPointer ?? DragPoint(x: 0, y: 0)
        let point = NSPoint(x: CGFloat(pointer.x), y: CGFloat(pointer.y))
        // overlay 盖住 surface；preview 必须挂到 contentView 且在 overlay 之上，否则「图标消失」。
        visuals.elevatePreviewAbove(overlay, at: point)
    }

    // MARK: - 指针事件（视图层调用；locationInWindow 与 NSEvent 同基）

    /// pointer-down：进入仲裁（pressed / 空白点击候选）。
    /// - sourceCell == nil → overlay 面板外空白按下（mouse-up 未过阈值 → onOverlayBlankClick）。
    /// - memberFolderID != nil → folder 成员源（.folderMember）。
    public func pointerDown(locationInWindow: NSPoint, sourceCell: AppGridCellView?, memberFolderID: FolderID?) {
        PointerInputDiagnostics.record(.coordinatorDown)
        guard !isTornDown else { ClickCensus.hit(ClickCensus.Sink.pointerDownTornDown); return }
        // T-1F-B8-wave-c census（N1 观测）：抑制标志仍 true 而无任何活会话
        //（controller idle 且无空白候选）→ 上一会话泄漏的抑制滞留。
        if isSuppressingClickRecognition, !isSessionActive {
            ClickCensus.hit(ClickCensus.Sink.suppressionResident)
        }
        guard dragGate() else { PointerInputDiagnostics.record(.dragGateDenied); ClickCensus.hit(ClickCensus.Sink.dragGateClosed); return }
        guard let host = visualHost else { PointerInputDiagnostics.record(.visualHostMissing); ClickCensus.hit(ClickCensus.Sink.visualHostNil); return }
        hasPointerOwnership = true
        let hostPoint = host.convert(locationInWindow, from: nil)
        let point = DragPoint(x: Double(hostPoint.x), y: Double(hostPoint.y))
        currentPointer = point

        // 第二个 drag：先结束旧仲裁的 cell 级抑制（surface 级抑制保持到整个仲裁结束）。
        if let previous = self.sourceCell, previous !== sourceCell {
            previous.setClickRecognitionEnabled(true)
        }

        isClickOnlyPress = false
        if !dragStartGate() {
            PointerInputDiagnostics.record(.clickOnly)
            // Use the existing thresholded click fallback without entering the drag controller.
            // Suppress both click recognizers until release so manual delivery launches once.
            isClickOnlyPress = true
            self.sourceCell = sourceCell
            clickFallbackCell = sourceCell
            clickFallbackDownPoint = sourceCell == nil ? nil : point
            pendingBlankPress = sourceCell == nil ? point : nil
            beginArbitration()
            return
        }

        let source = resolveSource(sourceCell: sourceCell, memberFolderID: memberFolderID)
        if source == nil {
            PointerInputDiagnostics.record(.sourceMissing)
            // T-1F-B8-wave-c census（N3 观测）：sourceCell ≠ nil 但解析失败
            //（bindingToken nil / 查无 record）= 原死路 A；sourceCell == nil = 真空白（对照）。
            ClickCensus.hit(sourceCell == nil
                            ? ClickCensus.Sink.pendingBlankNoCell
                            : ClickCensus.Sink.pendingBlankWithCell)
        }
        guard let source else {
            if sourceCell == nil {
                pendingBlankPress = point
            } else {
                // N3（T-1F-B8-wave-c Stage 2 预授权）：有 cell 的按下解析失败 → 归位为
                // fallback 武装（复用 pointerUp fallback 分支既有派发），不再当空白。
                // 依据：census s4b_pendingblank_withcell 计数点语义。
                ClickCensus.hit(ClickCensus.Sink.fallbackArmed)
                clickFallbackCell = sourceCell
                clickFallbackDownPoint = point
            }
            return
        }
        guard let layout = layoutProvider() else { PointerInputDiagnostics.record(.layoutMissing); ClickCensus.hit(ClickCensus.Sink.layoutProviderNil); return }
        self.sourceCell = sourceCell
        let events = controller.pointerDown(at: point, source: source, layout: layout,
                                            catalogGeneration: catalogGenerationProvider())
        if events.contains(where: { if case .pressed = $0 { return true }; return false }) {
            // 真实会话开始：清除任何遗留回退。
            clickFallbackCell = nil
            clickFallbackDownPoint = nil
        } else if sourceCell != nil {
            PointerInputDiagnostics.record(.sourceStale)
            // stale source（提交后布局已移动源）：武装点击回退，不 arm 空白按下。
            ClickCensus.hit(ClickCensus.Sink.fallbackArmed)
            clickFallbackCell = sourceCell
            clickFallbackDownPoint = point
        }
        handleEvents(events)
    }

    /// pointer 移动：阈值仲裁 → dragging；edge 调度；intent 分类（全部在 controller 内）。
    public func pointerDragged(locationInWindow: NSPoint) {
        PointerInputDiagnostics.record(.pointerDragged)
        guard !isTornDown else { return }
        guard let host = visualHost else { return }
        let hostPoint = host.convert(locationInWindow, from: nil)
        let point = DragPoint(x: Double(hostPoint.x), y: Double(hostPoint.y))
        currentPointer = point

        if let blank = pendingBlankPress {
            if point.distance(to: blank) >= parameters.dragStartThresholdPT {
                pendingBlankPress = nil   // 过阈值 → 空白点击候选取消（空白无 drag 源）
            }
            return
        }
        if clickFallbackCell != nil {
            // stale-source 拖拽尝试：过阈值 → no-op 清除（不进入 controller 路径）。
            if let down = clickFallbackDownPoint,
               point.distance(to: down) >= parameters.dragStartThresholdPT {
                // Discard the click candidate and restore suppression, but keep the
                // physical pointer owned until up/cancel; appearance must still wait.
                endSession(keepingPointerOwnership: true)
            }
            return
        }
        guard controller.state != .idle else { return }
        guard let scope = currentScope, let geometry = geometryProvider(scope) else {
            PointerInputDiagnostics.record(.geometryMissing)
            // T-1F-D1-fix-e1 + folder 拖拽诊断（s20）：folder scope geometry nil →
            // 本次 move 无操作（preview/蓝条不跟）。
            if let cs = currentScope, case .folder = cs {
                ClickCensus.hit(ClickCensus.Sink.dragGeometryNil)
            }
            return
        }
        guard let layout = layoutProvider() else { PointerInputDiagnostics.record(.layoutMissing); return }
        currentGeometry = geometry
        PointerInputDiagnostics.record(.movementProcessed)
        let events = controller.pointerMoved(to: point, geometry: geometry, layout: layout,
                                             catalogGeneration: catalogGenerationProvider())
        handleEvents(events)
        if controller.state == .dragging {
            visuals.movePreview(to: NSPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
        }
        // 跨行槽位的同一个 insertion index 可能同时来自上一行末项右半和下一行
        // 首项左半；即使 controller 没有发出 intentChanged，也必须用当前 pointer
        // 重刷蓝条锚点。edgeTurnPending 仍属于有效拖动帧，但 preview 语义保持原样。
        if controller.state == .dragging || controller.state == .edgeTurnPending {
            // 只有 insertion 类视觉需要按 pointer 重刷：同一 index 的跨行两侧
            // 可能换锚点；create-folder/folder-highlight 在 intentChanged 时
            // 已更新，逐帧重建其 layer/geometry 会引入无意义 churn。
            switch controller.lastIntent {
            case .insertion, .topLevelTarget:
                visuals.updateIntent(controller.lastIntent, geometry: geometry, pointer: point)
            case .intoFolder, .createFolder, .invalid:
                break
            }
        }
        scheduleEdgeTimerIfNeeded()
    }

    /// pointer-up：未过阈值 → click 派发；过阈值 → drop 解析（commit/noOp/reject）。
    public func pointerUp(locationInWindow: NSPoint) {
        PointerInputDiagnostics.record(.pointerUp)
        if controller.activeTransaction == nil { PointerInputDiagnostics.record(.releaseWithoutTransaction) }
        let ownedPointer = hasPointerOwnership
        let previousEndGeneration = sessionEndGeneration
        hasPointerOwnership = false
        defer {
            // Controller-idle auxiliary releases otherwise bypass endSession's notification.
            // Do not duplicate a normal end, or notify over a reentrant newer press.
            if !isTornDown, ownedPointer, !isSessionActive, sessionEndGeneration == previousEndGeneration {
                onSessionStateChange?(.idle)
            }
        }
        guard !isTornDown else { return }
        guard let host = visualHost else {
            // Host loss invalidates the controller session as well as UI arbitration.
            if controller.state != .idle { cancel(reason: .windowResign) }
            else if ownedPointer { endSession() }
            return
        }
        let hostPoint = host.convert(locationInWindow, from: nil)
        let point = DragPoint(x: Double(hostPoint.x), y: Double(hostPoint.y))
        currentPointer = point

        if let blank = pendingBlankPress {
            pendingBlankPress = nil
            let isBlankClick = point.distance(to: blank) < parameters.dragStartThresholdPT
            if isBlankClick {
                // census（T-1F-B8-wave-c）：s4e = 分支执行时抑制仍 true（修复前为滞留
                // 形成点；保留观测——修复后 E 序列应见其紧随 s9b 恢复、s9_leak 恒 0）。
                if isSuppressingClickRecognition {
                    ClickCensus.hit(ClickCensus.Sink.blankBranchWhileSuppressed)
                }
                ClickCensus.hit(ClickCensus.Sink.blankBranchDispatch)
            }
            // N1（T-1F-B8-wave-c Stage 2 预授权）：blank 分支必经 endSession —— 幂等
            //（isSuppressingClickRecognition guard 使重复调用安全），与 fallback 分支
            //（BUG6 Wave C 堵漏）同一「先清会话/恢复抑制再派发」先例：会话/抑制卫生
            // 不再依赖 onOverlayBlankClick 实现细节（生产 closeFolder 的
            // cancel(.overlayClosed) 代偿面）。
            // 依据：harness 测试 4/5 + census s4e_blankbranch_suppressed / s9_leak_suppression_resident。
            endSession()
            if isBlankClick {
                onOverlayBlankClick()   // 未过阈值 → 空白点击（关闭 folder）
            }
            return
        }
        if let fallback = clickFallbackCell {
            ClickCensus.hit(ClickCensus.Sink.fallbackDispatch)
            // BUG6 Wave C 堵漏：fallback 分支必经 endSession() —— 它是恢复
            // clickRecognitionSuppressor(true) 的路径，漏掉会让 surface click 识别
            // 永久禁用（点不开 app / 空白点击退不出）。endSession 会清
            // clickFallbackCell/DownPoint/sourceCell 与抑制标志。
            let down = clickFallbackDownPoint ?? point
            let isClick = point.distance(to: down) < parameters.dragStartThresholdPT
            endSession()   // 先清会话/恢复抑制再派发：onCellClick → handleDragCellClick →
                           // launchController 可能重入 cancel(.catalogRefresh)，避免重入时状态半旧半新。
            if isClick {
                onCellClick(fallback)   // 未过阈值 → stale-source 点击回退派发
            }
            return
        }
        guard controller.state != .idle else {
            ClickCensus.hit(ClickCensus.Sink.pointerUpIdleSwallow)
            return
        }

        if controller.state == .pressed {
            PointerInputDiagnostics.record(.releaseWhilePressed)
            if controller.releaseExceedsDragThreshold(at: point) { PointerInputDiagnostics.record(.releaseDisplaced) }
            // click 路径：controller 直接 reset + .clicked（几何/布局不参与）。
            let events = controller.pointerUp(at: point,
                                              geometry: DragGeometry(itemFrames: [], containerWidth: 0, page: 0, pageCount: 1),
                                              layout: layoutProvider() ?? Self.emptyLayout,
                                              catalogGeneration: catalogGenerationProvider())
            handleEvents(events)
            return
        }

        guard let scope = currentScope, let geometry = geometryProvider(scope) else {
            // folder 拖拽诊断（s20）：up 时 geometry nil → cancel(.teardown)（无 commit）。
            if let cs = currentScope, case .folder = cs {
                ClickCensus.hit(ClickCensus.Sink.dragGeometryNil)
            }
            cancel(reason: .teardown)
            return
        }
        guard let layout = layoutProvider() else {
            cancel(reason: .teardown)
            return
        }
        currentGeometry = geometry
        let events = controller.pointerUp(at: point, geometry: geometry, layout: layout,
                                          catalogGeneration: catalogGenerationProvider(),
                                          folderTitleProvider: folderCreationTitleProvider)
        handleEvents(events)
    }

    /// 统一 cancel（ESC/resign/refresh/search/titleEdit/overlayClose/teardown/secondDrag/layoutChanged）。
    public func cancel(reason: DragCancelReason) {
        guard !isTornDown else { return }
        let wasClickOnlyPress = isClickOnlyPress
        let ownedPointer = hasPointerOwnership
        pendingBlankPress = nil
        clickFallbackCell = nil
        clickFallbackDownPoint = nil
        guard controller.state != .idle || wasClickOnlyPress || ownedPointer else { return }
        PointerInputDiagnostics.recordCancellation(reason)
        if controller.state != .idle { _ = controller.cancel(reason: reason) }
        endSession()
    }

    /// edge dwell timer 触发（生产由 Timer 调度；测试直接调用）。
    public func edgeTimerFired() {
        guard controller.state == .dragging || controller.state == .edgeTurnPending else { return }
        guard let scope = currentScope, let geometry = geometryProvider(scope) else { return }
        guard let layout = layoutProvider() else { return }
        currentGeometry = geometry
        let events = controller.edgeTimerFired(geometry: geometry, layout: layout,
                                               catalogGeneration: catalogGenerationProvider())
        handleEvents(events)
        scheduleEdgeTimerIfNeeded()
    }

    /// teardown：cancel(.teardown) + 停 timer + 清视觉 + 恢复 click 识别（幂等；终态）。
    public func teardown() {
        isTornDown = true
        pendingBlankPress = nil
        clickFallbackCell = nil
        clickFallbackDownPoint = nil
        if controller.state != .idle {
            _ = controller.cancel(reason: .teardown)
        }
        endSession()
        visuals.teardown()
    }

    // MARK: - 事件处理

    private func handleEvents(_ events: [DragSessionEvent]) {
        for event in events {
            switch event {
            case .pressed:
                PointerInputDiagnostics.record(.pressed)
                currentScope = controller.activeTransaction?.scope
                beginArbitration()
                onSessionStateChange?(.pressed)
            case .dragBegan:
                PointerInputDiagnostics.record(.dragBegan)
                ClickCensus.hit(ClickCensus.Sink.dragBegan)
                let pointer = currentPointer ?? DragPoint(x: 0, y: 0)
                visuals.showPreview(sourceCell: sourceCell,
                                    at: NSPoint(x: CGFloat(pointer.x), y: CGFloat(pointer.y)))
                onSessionStateChange?(.dragging)
            case .intentChanged(let intent):
                if case .invalid = intent {
                    ClickCensus.hit(ClickCensus.Sink.dragIntentInvalid)
                }
                if let geometry = currentGeometry {
                    if let pointer = currentPointer {
                        visuals.updateIntent(intent, geometry: geometry, pointer: pointer)
                    } else {
                        visuals.updateIntent(intent, geometry: geometry)
                    }
                }
            case .edge(let edgeEvent):
                handleEdgeEvent(edgeEvent)
            case .clicked:
                PointerInputDiagnostics.record(.clicked)
                completeClick()
            case .committed(let newLayout):
                PointerInputDiagnostics.record(.committed)
                ClickCensus.hit(ClickCensus.Sink.dragCommitted)
                onCommit(newLayout)
                endSession()
            case .noOp:
                PointerInputDiagnostics.record(.noOp)
                ClickCensus.hit(ClickCensus.Sink.dragNoOp)
                endSession()
            case .cancelled(let reason):
                PointerInputDiagnostics.recordCancellation(reason)
                if reason == .secondDrag {
                    // 旧 session 被新 pointer-down 取代：清旧视觉/计时，保持仲裁
                    // （新 session 的 .pressed 随后到达；cell 级抑制已在 pointerDown 切换）。
                    visuals.clearAll()
                    invalidateEdgeTimer()
                    onSessionStateChange?(.idle)
                } else {
                    endSession()
                }
            case .rejected:
                PointerInputDiagnostics.record(.rejected)
                ClickCensus.hit(ClickCensus.Sink.dragRejected)
                endSession()
            }
        }
    }

    private func handleEdgeEvent(_ event: EdgePagingEvent) {
        switch event {
        case .pageTurnRequested(let zone):
            performPageTurn(zone)
        case .dwellStarted:
            scheduleEdgeTimerIfNeeded()
        case .edgeEntered, .edgeLeft, .dwellCancelled, .atFirstPage, .atLastPage:
            break
        }
    }

    private func performPageTurn(_ zone: EdgeZone) {
        let visibleScope: DragScope? = currentGeometry?.topLevelMoveOutBounds != nil ? .topLevel : currentScope
        switch visibleScope {
        case .topLevel:
            let direction: KeyboardPageDirection = zone == .left ? .previous : .next
            _ = topLevelPageTurn(direction, ProcessInfo.processInfo.systemUptime)
        case .folder:
            folderPageTurn(zone == .left ? -1 : 1)
        case nil:
            break
        }
        // turn 后以新 page 重新调度（controller 已按新 page 重武装 deadline）。
        scheduleEdgeTimerIfNeeded()
    }

    /// Retain the original target while retiring old ownership before external callbacks.
    private func completeClick() {
        let cell = sourceCell
        let binding = cell?.bindingToken
        let releaseGeneration = sessionEndGeneration &+ 1
        endSession()
        // Idle observers may cancel, tear down, or reuse the target. Never activate a
        // replacement binding; a fresh admitted press must keep its own state intact.
        guard !isTornDown, sessionEndGeneration == releaseGeneration,
              cell?.bindingToken == binding else { return }
        if let cell {
            ClickCensus.hit(ClickCensus.Sink.dispatchClickCell)
            onCellClick(cell)
        } else {
            ClickCensus.hit(ClickCensus.Sink.dispatchClickBlank)
            onOverlayBlankClick()
        }
    }

    // MARK: - 仲裁生命周期

    private func beginArbitration() {
        guard !isSuppressingClickRecognition else { return }
        isSuppressingClickRecognition = true
        sourceCell?.setClickRecognitionEnabled(false)
        clickRecognitionSuppressor?(false)
    }

    private func endSession(keepingPointerOwnership: Bool = false) {
        let keepPointer = keepingPointerOwnership && hasPointerOwnership
        hasPointerOwnership = keepPointer
        sessionEndGeneration &+= 1
        if isSuppressingClickRecognition {
            isSuppressingClickRecognition = false
            sourceCell?.setClickRecognitionEnabled(true)
            clickRecognitionSuppressor?(true)
            ClickCensus.hit(ClickCensus.Sink.endSessionRestored)
        }
        sourceCell = nil
        currentScope = nil
        pendingBlankPress = nil
        clickFallbackCell = nil
        clickFallbackDownPoint = nil
        isClickOnlyPress = false
        currentPointer = nil
        currentGeometry = nil
        invalidateEdgeTimer()
        visuals.clearAll()
        if !keepPointer { onSessionStateChange?(.idle) }
    }

    // MARK: - 源身份解析

    private func resolveSource(sourceCell: AppGridCellView?, memberFolderID: FolderID?) -> DragSourceIdentity? {
        guard let cell = sourceCell else { return nil }
        if let folderID = memberFolderID {
            guard let appID = cell.bindingToken?.appID as? AppID,
                  let ref = appReference(for: appID) else { return nil }
            return .folderMember(folderID: folderID, app: ref)
        }
        if cell.isFolderCell {
            guard let folderID = cell.bindingToken?.appID as? FolderID else { return nil }
            return .topLevelFolder(folderID)
        }
        guard let appID = cell.bindingToken?.appID as? AppID,
              let ref = appReference(for: appID) else { return nil }
        if let layout = layoutProvider(), !layout.topLevelOrder.contains(.app(ref)),
           let owner = layout.folders.first(where: { $0.members.contains(ref) }),
           layout.topLevelOrder.contains(.folder(owner.id)) {
            // A visible singleton of a latent group is still owned by that group.
            // Dragging reorders the group; clicking continues to launch this app.
            return .topLevelFolder(owner.id)
        }
        return .topLevelApp(ref)
    }

    private func appReference(for appID: AppID) -> PersistentAppReference? {
        guard let snapshot = catalogSnapshotProvider() else { return nil }
        guard let record = snapshot.records.first(where: { $0.id == appID }) else { return nil }
        if let layout = layoutProvider(), let stored = WorkspaceAppReferenceResolver.reference(for: record, in: layout) {
            return stored
        }
        return PersistentAppReference.from(record: record)
    }

    // MARK: - Edge timer

    private func scheduleEdgeTimerIfNeeded() {
        guard let deadline = controller.edgeDwellDeadline else {
            invalidateEdgeTimer()
            return
        }
        if let timer = edgeTimer, timer.isValid, scheduledEdgeDeadline == deadline { return }
        invalidateEdgeTimer()
        let interval = max(deadline - clock.now(), 0.001)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.edgeTimerFired() }
        }
        RunLoop.main.add(timer, forMode: .common)
        edgeTimer = timer
        scheduledEdgeDeadline = deadline
    }

    private func invalidateEdgeTimer() {
        edgeTimer?.invalidate()
        edgeTimer = nil
        scheduledEdgeDeadline = nil
    }

    /// click 路径的占位几何/布局（controller 在 .pressed 分支不使用它们）。
    private static let emptyLayout = PersistentWorkspaceLayout(generation: .zero, topLevelOrder: [], folders: [])
}

// MARK: - 会话内布局构建（T-1F-D1；T-1F-E 以 store 替换）

/// 从 catalog 呈现面构建会话内 `PersistentWorkspaceLayout`（零磁盘写）。
/// 顶层顺序 = 呈现条目顺序（folder 条目在前，未分组 app 按 catalog 序）；
/// folder 成员经 catalog 记录解析为 PersistentAppReference（不在 catalog 的成员跳过）。
@MainActor
public enum DragUISessionLayoutFactory {

    public static func makeSessionLayout(catalog: CatalogSnapshot?,
                                         entries: [TopLevelEntry],
                                         folderSnapshot: FolderSnapshot?) -> PersistentWorkspaceLayout? {
        let topLevel = entries.map { entry -> WorkspaceTopLevelEntry in
            switch entry {
            case .app(let record):
                return .app(PersistentAppReference.from(record: record))
            case .folder(let folderEntry):
                return .folder(folderEntry.id)
            }
        }
        let folders = (folderSnapshot?.entries ?? []).compactMap { entry -> PersistentFolderRecord? in
            let members = entry.members.compactMap { appID -> PersistentAppReference? in
                guard let record = catalog?.records.first(where: { $0.id == appID }) else { return nil }
                return PersistentAppReference.from(record: record)
            }
            return PersistentFolderRecord(id: entry.id, title: entry.title, members: members)
        }
        return PersistentWorkspaceLayout(generation: .zero, topLevelOrder: topLevel, folders: folders)
    }
}
