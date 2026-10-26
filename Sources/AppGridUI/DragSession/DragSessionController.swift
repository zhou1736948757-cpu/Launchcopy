// AppGridUI — DragSession.DragSessionController（Phase 1F §5.1 / ADR-010 Q2/Q7/Q8）
// 实现：T-1F-C（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 自定义窗口内 pointer 状态机（ADR-010 Q1：非 NSDraggingSession；可测性优先）：
// `idle → pressed → dragging/edgeTurnPending → commit | cancel → idle`。
// - 按下阈值仲裁：pointer-down 只能进 pressed；过阈值才 dragging；未过阈值
//   mouse-up 派发既有 click/open/launch（本层只发 .clicked 事件，不启动任何东西）。
// - 统一 cancel 出口：ESC / resign / refresh / search / title edit / overlay close /
//   teardown / second drag / layout mid-drag 变更 → 零写盘、无 preview/edge-timer 残留。
// - 第二个 drag 开始：先取消旧 session（废其 completion），再开始新的。
// - 每 session 至多 1 个 preview + 1 个 edge timer（deadline 由 D 层调度）。
// - 隐私：无任何输出；token 零身份、进程内唯一驻留（Q9）。

import Foundation

/// Synchronous, side-effect-free presentation policy. Only a validated creation consumes it.
public typealias FolderCreationTitleProvider = (
    _ target: PersistentAppReference, _ source: PersistentAppReference,
    _ layout: PersistentWorkspaceLayout
) -> String?

/// 可注入时钟（测试用假时钟控制 dwell/turn 时序）。
public protocol DragClock: Sendable {
    func now() -> TimeInterval
}

/// 系统时钟（生产默认）。
public struct SystemDragClock: DragClock {
    public init() {}
    public func now() -> TimeInterval {
        Date().timeIntervalSinceReferenceDate
    }
}

/// drag session 控制器（纯逻辑核心；AppKit 薄壳在 D 层）。
public final class DragSessionController {
    public private(set) var state: DragSessionState = .idle
    /// 唯一活动事务（pressed 时生成，commit/cancel/teardown 销毁）。
    public private(set) var activeTransaction: DragTransaction?
    /// 终局结果（一次 session 至多一个；旧 completion 由 token 校验拒绝）。
    public private(set) var lastOutcome: DragSessionOutcome?
    /// 下一次 edge dwell timer 的 deadline（nil = 无驻留；D 层据此调度真实 timer）。
    public private(set) var edgeDwellDeadline: TimeInterval?
    /// 最近一次 drop intent 分类（D 层驱动视觉）。
    public private(set) var lastIntent: DropIntent = .invalid
    /// move-out 显式 coordinator 状态（ADR-010 Q4 M5 overlayMoveOutArmed；可测）。
    public private(set) var moveOutArmed: Bool = false

    private let parameters: DragParameters
    private let clock: DragClock
    private var resolver: DropResolver?
    private var edgeScheduler = EdgePagingScheduler()
    private var source: DragSourceIdentity?
    private var downPoint: DragPoint?
    private var lastPoint: DragPoint?
    private var lastGeometry: DragGeometry?

    public init(parameters: DragParameters = .default, clock: DragClock = SystemDragClock()) {
        self.parameters = parameters
        self.clock = clock
    }

    // MARK: - 输入

    /// pointer-down 硬门：只能进 pressed（不启动、不开 folder）。空白处（source nil）
    /// 不进入 drag（ADR-010 Q2）。第二个 drag 开始 → 先取消旧 session。
    @discardableResult
    public func pointerDown(at point: DragPoint,
                            source: DragSourceIdentity?,
                            layout: PersistentWorkspaceLayout,
                            catalogGeneration: UInt64) -> [DragSessionEvent] {
        var events: [DragSessionEvent] = []
        if state != .idle {
            events += cancel(reason: .secondDrag)
        }
        guard let source else { return events }
        guard sourcePresent(source, in: layout) else { return events }   // stale source 拒绝

        let transaction = DragTransaction(opaqueToken: DragTokenFactory.makeToken(),
                                           scope: source.scope,
                                           sourceIdentity: source,
                                           layoutGeneration: layout.generation,
                                           catalogGeneration: catalogGeneration)
        resolver = DropResolver(transaction: transaction)
        activeTransaction = transaction
        self.source = source
        downPoint = point
        lastPoint = point
        lastGeometry = nil
        lastIntent = .invalid
        lastOutcome = nil
        moveOutArmed = false
        edgeScheduler = EdgePagingScheduler()
        edgeDwellDeadline = nil
        state = .pressed
        events.append(.pressed)
        return events
    }

    /// pointer 移动：阈值仲裁 → dragging；edge 调度；drop intent 分类；
    /// 双 generation 过期 → 统一 cancel（Q8 安全默认）。
    @discardableResult
    public func pointerMoved(to point: DragPoint,
                             geometry: DragGeometry,
                             layout: PersistentWorkspaceLayout,
                             catalogGeneration: UInt64) -> [DragSessionEvent] {
        guard state == .pressed || state == .dragging || state == .edgeTurnPending else { return [] }
        guard let transaction = activeTransaction else { return [] }
        if layout.generation != transaction.layoutGeneration {
            return cancel(reason: .layoutChanged)
        }
        if catalogGeneration != transaction.catalogGeneration {
            return cancel(reason: .catalogRefresh)
        }
        let enteredMainMoveOut = geometry.topLevelMoveOutBounds != nil
            && lastGeometry?.topLevelMoveOutBounds == nil
        lastPoint = point
        lastGeometry = geometry
        var events: [DragSessionEvent] = []
        if enteredMainMoveOut {
            // A folder's terminal edge is not the main pager's terminal edge.
            // Re-enter once in the new context even when the pointer did not move.
            events += edgeScheduler.cancel().map { .edge($0) }
            edgeScheduler = EdgePagingScheduler()
            edgeDwellDeadline = nil
        }

        if state == .pressed {
            guard let down = downPoint else { return [] }
            guard point.distance(to: down) >= parameters.dragStartThresholdPT else {
                return events   // 未过阈值：仍 pressed
            }
            state = .dragging
            events.append(.dragBegan)
        }

        // move-out 显式 arm（folder scope；Q4 M5）。
        if case .folder = transaction.scope, let down = downPoint {
            moveOutArmed = geometry.topLevelMoveOutBounds != nil
                || point.distance(to: down) >= parameters.overlayMoveOutArmThresholdPT
        }

        // edge 调度（dragging / edgeTurnPending）。
        let edgeEvents = edgeScheduler.update(pointer: point,
                                              containerWidth: geometry.containerWidth,
                                              page: geometry.page,
                                              pageCount: geometry.pageCount,
                                              now: clock.now(),
                                              parameters: parameters)
        events += edgeEvents.map { DragSessionEvent.edge($0) }
        syncEdgeState()

        // drop intent 分类（每帧重算；变化才发事件）。
        let intent = currentIntent(point: point, geometry: geometry)
        if intent != lastIntent {
            lastIntent = intent
            events.append(.intentChanged(intent))
        }
        return events
    }

    /// dwell timer 触发（D 层按 edgeDwellDeadline 调用）：一次 page turn 请求。
    /// turn 后 D 层以新 page 重新调用 pointerMoved（重新 hit-test + 重验 token/双 generation）。
    @discardableResult
    public func edgeTimerFired(geometry: DragGeometry,
                               layout: PersistentWorkspaceLayout,
                               catalogGeneration: UInt64) -> [DragSessionEvent] {
        guard state == .edgeTurnPending || state == .dragging else { return [] }
        guard let transaction = activeTransaction else { return [] }
        if layout.generation != transaction.layoutGeneration {
            return cancel(reason: .layoutChanged)
        }
        if catalogGeneration != transaction.catalogGeneration {
            return cancel(reason: .catalogRefresh)
        }
        let events = edgeScheduler.dwellElapsed(now: clock.now(),
                                               page: geometry.page,
                                               pageCount: geometry.pageCount,
                                               parameters: parameters)
        syncEdgeState()
        return events.map { DragSessionEvent.edge($0) }
    }

    /// Shared release classification; uses existing transaction input, never diagnostic storage.
    func releaseExceedsDragThreshold(at point: DragPoint) -> Bool {
        guard let downPoint else { return false }
        return point.distance(to: downPoint) >= parameters.dragStartThresholdPT
    }

    /// pointer-up：未过阈值 → click；过阈值 → drop 校验 + mutation 提交。
    @discardableResult
    public func pointerUp(at point: DragPoint,
                          geometry: DragGeometry,
                          layout: PersistentWorkspaceLayout,
                          catalogGeneration: UInt64,
                          folderTitleProvider: FolderCreationTitleProvider? = nil) -> [DragSessionEvent] {
        guard state != .idle else { return [] }
        guard let transaction = activeTransaction else { return [] }

        if state == .pressed {
            let displaced = releaseExceedsDragThreshold(at: point)
            resetSession()
            // Missing/coalesced moves must not turn a distant release into an app launch.
            // There was no presented drag, so do not synthesize a mutation on release.
            if displaced { lastOutcome = .noOp; return [.noOp] }
            return [.clicked]
        }

        // 双 generation 过期 → 统一 cancel（防御；正常在 move 时已 cancel）。
        if layout.generation != transaction.layoutGeneration {
            return cancel(reason: .layoutChanged)
        }
        if catalogGeneration != transaction.catalogGeneration {
            return cancel(reason: .catalogRefresh)
        }

        guard var activeResolver = resolver, let source else {
            resetSession()
            lastOutcome = .cancelled(.teardown)
            return [.cancelled(.teardown)]
        }

        let intent = currentIntent(point: point, geometry: geometry)
        let resolution = activeResolver.consume(token: transaction.opaqueToken,
                                                 intent: intent,
                                                 layout: layout,
                                                 catalogGeneration: catalogGeneration)
        switch resolution {
        case .reject(let reason):
            resetSession()
            lastOutcome = .rejected(reason)
            return [.rejected(reason)]
        case .accept(let acceptedIntent):
            let folderTitle: String?
            if case .createFolder(let target) = acceptedIntent,
               case .topLevelApp(let app) = source {
                // Use the accepted release target, never the last hover's cached intent.
                folderTitle = folderTitleProvider?(target, app, layout)
            } else { folderTitle = nil }
            let result = DragMutationEngine.apply(intent: acceptedIntent, source: source,
                                                   layout: layout, folderTitle: folderTitle)
            switch result {
            case .success(let newLayout):
                resetSession()
                lastOutcome = .committed(newLayout)
                return [.committed(newLayout)]
            case .noOp:
                resetSession()
                lastOutcome = .noOp
                return [.noOp]
            case .rejected(let rejection):
                resetSession()
                lastOutcome = .rejected(.mutationRejected(rejection))
                return [.rejected(.mutationRejected(rejection))]
            case .cancelled:
                // 引擎不产生此结果（取消路径不进入引擎，Q7）；防御分支。
                resetSession()
                lastOutcome = .cancelled(.teardown)
                return [.cancelled(.teardown)]
            }
        }
    }

    /// 统一 cancel 出口（唯一实现）：ESC / resign / refresh / search / title edit /
    /// overlay close / teardown / second drag / layoutChanged → 零写盘、无残留。
    @discardableResult
    public func cancel(reason: DragCancelReason) -> [DragSessionEvent] {
        guard state != .idle else { return [] }
        let edgeEvents = edgeScheduler.cancel()
        resetSession()
        lastOutcome = .cancelled(reason)
        return edgeEvents.map { DragSessionEvent.edge($0) } + [.cancelled(reason)]
    }

    // MARK: - 内部

    private func syncEdgeState() {
        if edgeScheduler.dwellArmed {
            state = .edgeTurnPending
            edgeDwellDeadline = edgeScheduler.nextDwellDeadline(after: clock.now(), parameters: parameters)
        } else {
            if state == .edgeTurnPending { state = .dragging }
            edgeDwellDeadline = nil
        }
    }

    private func currentIntent(point: DragPoint, geometry: DragGeometry) -> DropIntent {
        guard let source else { return .invalid }
        let zones = DropZoneBuilder.zones(itemFrames: geometry.itemFrames,
                                          topLevelFrames: geometry.topLevelFrames,
                                          containerWidth: geometry.containerWidth,
                                          moveOutArmed: moveOutArmed,
                                          parameters: parameters,
                                          topLevelMoveOutBounds: geometry.topLevelMoveOutBounds)
        return DropZoneClassifier.classify(pointer: point, source: source, zones: zones)
    }

    private func sourcePresent(_ source: DragSourceIdentity, in layout: PersistentWorkspaceLayout) -> Bool {
        switch source {
        case .topLevelApp(let ref):
            return layout.topLevelOrder.contains { $0 == .app(ref) }
        case .topLevelFolder(let id):
            return layout.topLevelOrder.contains { $0 == .folder(id) }
        case .folderMember(let folderID, let ref):
            return layout.folder(id: folderID)?.members.contains(ref) == true
        }
    }

    private func resetSession() {
        state = .idle
        activeTransaction = nil
        resolver = nil
        source = nil
        downPoint = nil
        lastPoint = nil
        lastGeometry = nil
        lastIntent = .invalid
        moveOutArmed = false
        edgeScheduler = EdgePagingScheduler()
        edgeDwellDeadline = nil
    }
}
