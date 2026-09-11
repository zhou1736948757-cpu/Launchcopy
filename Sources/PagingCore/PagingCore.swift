//
//  PagingCore.swift
//  PagingCore
//
//  Phase 1A — 纯逻辑分页状态机（ADR-001 全部决策落地）。
//
//  边界：不依赖 AppKit / Core Animation / 窗口 / 真实事件（D10）。
//  输入为归一化手势事件（GesturePhase/delta/timestamp），输出为状态 + visualOffset +
//  commit/stale/interruption 事件；UI 层负责 NSEvent 转换与渲染。
//  单线程（主线程）使用；无锁。
//

import Foundation

/// 中断信息（D4；telemetry 的 interruption/interruptSourceOffset 来源）。
public struct PagingInterruption: Sendable, Equatable {
    /// 接管时刻的显示位置（= 新 GestureSession 的 startOffset，页宽单位）。
    public let takeoverOffset: Double
    /// 被作废动画的目标页（无则 nil）。
    public let abandonedTargetPage: Int?
    /// 被作废动画的 token（无则 nil）。
    public let abandonedToken: UInt64?
}

/// Core 事件出口（UI/telemetry 挂接；teardown 后不再触发任何回调，ADR-001 D7）。
public struct PagingCoreEvents {
    /// 状态迁移（含 interrupted/cancelled 瞬时态）。
    public var onStateChange: ((PagingState) -> Void)?
    /// 视觉偏移变更（UI 渲染唯一数据源，D1）。
    public var onVisualOffsetChange: ((Double) -> Void)?
    /// settle 开始（新 transition）。
    public var onTransitionBegin: ((TransitionContext) -> Void)?
    /// 自然完成 commit。
    public var onCommit: ((TransitionContext) -> Void)?
    /// stale completion 被拒（携带被拒 token）。
    public var onStaleRejection: ((UInt64) -> Void)?
    /// 中断发生。
    public var onInterruption: ((PagingInterruption) -> Void)?

    public init() {}
}

/// 纯逻辑分页状态机。视觉偏移唯一所有权在 Core（D1）。
public final class PagingCore {

    // MARK: - 只读状态

    /// 当前语义状态。
    public private(set) var state: PagingState = .idle
    /// 语义页：仅在 settle 自然完成（commit 到 targetPage）或 cancel/teardown（clamp）时变更（D1）。
    public private(set) var committedPage: Int
    /// 视觉偏移（页宽单位连续值）：UI 渲染唯一数据源；tracking 由会话驱动、settling 由插值驱动。
    public private(set) var visualOffset: Double
    /// 页数。
    public private(set) var pageCount: Int
    /// 页宽（px）。
    public private(set) var pageWidth: Double
    /// 单调递增 transition token（每次 beginSettle 递增；中断本身不递增，D3）。
    public private(set) var transitionToken: UInt64 = 0
    /// 当前活跃 transition（settling 期间非 nil）。
    public private(set) var activeTransition: TransitionContext?
    /// 当前手势会话（tracking 期间非 nil）。
    public private(set) var currentSession: GestureSession?
    /// 被拒绝的 completion 请求总数（D3）：含中断/取消/teardown/重基准化时作废动画的
    /// 隐式 completion，以及 completeSettle 显式拒绝（含 teardown 后的拒绝，但 teardown 后不触发回调，D7）。
    public private(set) var staleRejectionCount: UInt64 = 0
    /// 成功 commit 的 settle 总数（含同页回弹的自然完成）。
    public private(set) var commitCount: UInt64 = 0
    /// 中断次数（settling → interrupted）。
    public private(set) var interruptionCount: UInt64 = 0
    /// teardown 标记（D7：第一时间置位；此后所有入口短路，无残留回调）。
    public private(set) var isTearingDown = false
    /// Reduce Motion 生效标记（D8）。
    public private(set) var reduceMotion: Bool

    /// 集中参数。
    public var parameters: PagingParameters
    /// 事件出口。
    public let events: PagingCoreEvents

    /// 是否正在动画（settle 插值或惯性滑行）。
    public var isAnimating: Bool {
        state == .settling || (currentSession?.isMomentumGlide ?? false)
    }

    // MARK: - 私有

    private var sessionIDCounter: UInt64 = 0
    /// settle 插值内部速度（页宽单位/秒）。
    private var springVelocity: Double = 0
    private var lastFiredOffset: Double

    // 实现细节常量（非交互参数；不属于 PARAMETER_RATIONALE 的 23 项）：
    /// settle 完成位置容差：页宽比例的 0.1%（≈1px @ 1000px 页宽）。
    private static let positionEpsilon = 0.001
    /// settle 完成速度容差（页宽单位/秒；spring 包络衰减后速度量级远小于此）。
    private static let velocityEpsilon = 0.05
    /// 惯性滑行停止速度 = velocityThreshold × 5%（低于此即视为惯性耗尽）。
    private static let glideStopFraction = 0.05
    /// momentum 过冲软阻尼透传系数（T-worker-b-softdamp；越限部分按此比例前进，
    /// 每事件仍移动 → 无静止帧；任务建议值，与边界 overscroll 阻尼同量级）。
    private static let momentumOvershootDamping = 0.2
    /// pageWidth 下限防御（0/负值宽度无意义）。
    private static let minimumPageWidth = 1.0
    /// 偏移变更事件去重容差。
    private static let offsetEventEpsilon = 1e-12

    // MARK: - 初始化

    /// - Parameters:
    ///   - pageCount: 页数（0 允许：空内容，所有输入安全忽略）。
    ///   - pageWidth: 页宽 px（≤0 时钳到 minimumPageWidth）。
    ///   - parameters: 集中参数（默认 = PARAMETER_RATIONALE 表值）。
    ///   - initialPage: 初始语义页（clamp 到 [0, pageCount−1]）。
    ///   - reduceMotion: RM 初始值（UI 层按系统偏好传入；运行时可 setReduceMotion 动态切换）。
    ///   - events: 事件出口。
    public init(
        pageCount: Int,
        pageWidth: Double,
        parameters: PagingParameters = .init(),
        initialPage: Int = 0,
        reduceMotion: Bool = false,
        events: PagingCoreEvents = .init()
    ) {
        self.pageWidth = max(pageWidth, Self.minimumPageWidth)
        self.pageCount = max(pageCount, 0)
        let initial = min(max(initialPage, 0), max(self.pageCount - 1, 0))
        self.committedPage = initial
        self.visualOffset = Double(initial)
        self.lastFiredOffset = Double(initial)
        self.parameters = parameters
        self.reduceMotion = reduceMotion
        self.events = events
    }

    // MARK: - 输入（D10 归一化事件）

    /// 处理一个归一化手势 phase 事件。
    /// - Returns: 是否被接受并产生效果（防御性序列下返回 false）。
    @discardableResult
    public func handleGesturePhase(_ phase: GesturePhase, delta: Double = 0, timestamp: TimeInterval = 0) -> Bool {
        guard !isTearingDown else { return false }
        switch phase {
        case .began:
            return handleBegan(timestamp: timestamp)
        case .changed:
            return handleChanged(delta: delta, timestamp: timestamp)
        case .ended:
            return handleEnded(timestamp: timestamp)
        case .cancelled:
            handlePhaseCancelled()
            return true
        case .momentumBegan:
            return handleMomentumBegan(timestamp: timestamp)
        case .momentumChanged:
            return handleMomentumChanged(delta: delta, timestamp: timestamp)
        case .momentumEnded:
            return handleMomentumEnded(timestamp: timestamp)
        }
    }

    /// 结束全部输入并触发释放决策（ended 无 momentum 时由 UI 调用；momentumEnded 后由 Core 内部调用）。
    @discardableResult
    public func finishGesture(timestamp: TimeInterval? = nil) -> Bool {
        guard !isTearingDown else { return false }
        guard let session = currentSession, state == .tracking else { return false }

        if pageCount == 0 {
            currentSession = nil
            setState(.idle)
            return false
        }

        let decision = PageTargetPolicy.decide(
            offset: session.currentOffset,
            committedPage: committedPage,
            velocityPxPerSecond: session.velocityPxPerSecond,
            pageWidth: pageWidth,
            pageCount: pageCount,
            parameters: parameters,
            reduceMotion: reduceMotion
        )
        let target: Int
        switch decision {
        case .bounce:
            target = committedPage
        case .advance:
            target = min(committedPage + 1, pageCount - 1)
        case .retreat:
            target = max(committedPage - 1, 0)
        }
        beginSettle(targetPage: target, fromOffset: session.currentOffset, reason: .gestureRelease, createdAt: timestamp ?? 0)
        return true
    }

    /// 无 phase 事件的旧式输入 fallback（D5：旧鼠标滚轮；单次位移即完整手势，不用于物理验收门）。
    @discardableResult
    public func legacyScrollDelta(_ delta: Double, timestamp: TimeInterval) -> Bool {
        guard !isTearingDown, pageCount > 0 else { return false }
        if state == .idle {
            startSession(offset: visualOffset, timestamp: timestamp)
            setState(.tracking)
        }
        guard state == .tracking, let session = currentSession, !session.released else { return false }
        applyTrackedDelta(session, scaledDeltaPx: delta * parameters.inputSensitivity, timestamp: timestamp)
        return finishGesture(timestamp: timestamp)
    }

    // MARK: - 动画驱动（D2：手动插值；UI display link 每帧调用）

    /// 推进一帧（settle 插值或惯性滑行）。
    /// - Returns: 是否仍在动画中（true = UI 应继续下一帧）。
    @discardableResult
    public func tick(deltaTime: TimeInterval) -> Bool {
        guard !isTearingDown, deltaTime > 0 else { return false }
        if state == .settling, let ctx = activeTransition {
            advanceSpring(deltaTime: deltaTime)
            let distance = abs(visualOffset - Double(ctx.targetPage))
            if distance < Self.positionEpsilon && abs(springVelocity) < Self.velocityEpsilon {
                _ = completeSettle(ctx)
            }
            return state == .settling
        }
        if state == .tracking, let session = currentSession, session.isMomentumGlide {
            advanceGlide(deltaTime: deltaTime)
            return state == .settling || (currentSession?.isMomentumGlide ?? false)
        }
        return false
    }

    /// 提交一个 transition（自然完成路径；也为"旧 completion 晚到"提供显式入口，D3 三防线）。
    /// - Returns: 是否成功 commit（false = 被拒，已计入 staleRejectionCount）。
    @discardableResult
    public func completeSettle(_ transition: TransitionContext) -> Bool {
        guard !isTearingDown else {
            // D7：teardown 后任何 completion 一律拒绝；计数但不触发回调（无残留回调）。
            transition.markStale()
            staleRejectionCount += 1
            return false
        }
        guard transition.commitState == .pending,
              transition.token == activeTransition?.token else {
            // D3：token 失配 / 已作废 / 已提交 → 拒绝并计数。
            transition.markStale()
            staleRejectionCount += 1
            events.onStaleRejection?(transition.token)
            return false
        }
        // 自然完成：commit 到 targetPage。
        committedPage = transition.targetPage
        visualOffset = Double(transition.targetPage)
        transition.markCommitted()
        activeTransition = nil
        springVelocity = 0
        commitCount += 1
        fireOffsetChangeIfChanged()
        events.onCommit?(transition)
        setState(.idle)
        return true
    }

    // MARK: - 环境变化（D6/D8）

    /// resize / pageWidth 变化（D6 三分支）。
    /// - Note: resize 通知的 coalesce 属 UI 层（runloop 空闲或下一帧统一处理），Core 只处理单次调用。
    public func setPageWidth(_ newWidth: Double) {
        guard !isTearingDown else { return }
        let safeWidth = max(newWidth, Self.minimumPageWidth)
        guard safeWidth != pageWidth else { return }
        let oldWidth = pageWidth
        pageWidth = safeWidth

        switch state {
        case .tracking:
            // D6：比例保持 rebase（物理位置不变），手势继续。
            let rebased = visualOffset * oldWidth / safeWidth
            visualOffset = rebased
            currentSession?.rebase(oldWidth: oldWidth, newWidth: safeWidth)
        case .settling:
            // D6：重算 target（round + clamp）用新 token 重启动画。
            if activeTransition != nil {
                abandonActiveTransition()
            }
            springVelocity = 0
            let rebased = visualOffset * oldWidth / safeWidth
            visualOffset = rebased
            let target = clampToValidPage(Int(rebased.rounded()))
            beginSettle(targetPage: target, fromOffset: rebased, reason: .resizeRebase, createdAt: Date().timeIntervalSince1970)
        case .idle, .interrupted, .cancelled:
            // D6：idle → 更新 pageWidth + 一次布局（UI 层）；偏移保持静止位（语义页不变）。
            visualOffset = Double(committedPage)
        }
        fireOffsetChangeIfChanged()
    }

    /// pageCount 变化（D6 三分支）。
    public func setPageCount(_ newCount: Int) {
        guard !isTearingDown else { return }
        let count = max(newCount, 0)
        guard count != pageCount else { return }
        pageCount = count

        if count == 0 {
            // 无页：作废动画、清会话、归零。
            if activeTransition != nil {
                abandonActiveTransition()
            }
            currentSession = nil
            springVelocity = 0
            committedPage = 0
            visualOffset = 0
            setState(.cancelled)
            setState(.idle)
            fireOffsetChangeIfChanged()
            return
        }

        switch state {
        case .tracking:
            // D6：clamp committedPage 与 visualOffset，不中断手势。
            committedPage = min(committedPage, count - 1)
            let clamped = applyingBoundary(to: visualOffset)
            if clamped != visualOffset {
                visualOffset = clamped
                currentSession?.syncToVisualOffset(clamped)
            }
        case .settling:
            guard let ctx = activeTransition else { break }
            if ctx.targetPage < count {
                // target 合法 → 继续动画（D6）。
                break
            }
            // target 越界 → 作废（token 作废）+ clamp + 重置（新 token settle 到 clamped 页）。
            abandonActiveTransition()
            springVelocity = 0
            committedPage = min(committedPage, count - 1)
            let clamped = applyingBoundary(to: visualOffset)
            visualOffset = clamped
            let target = clampToValidPage(Int(clamped.rounded()))
            beginSettle(targetPage: target, fromOffset: clamped, reason: .pageCountChange, createdAt: Date().timeIntervalSince1970)
        case .idle, .interrupted, .cancelled:
            // D6：仅 clamp。
            committedPage = min(committedPage, count - 1)
            visualOffset = applyingBoundary(to: visualOffset)
        }
        fireOffsetChangeIfChanged()
    }

    /// Reduce Motion 动态切换（D8：参数降级，状态机/转换条件/token 机制不变）。
    public func setReduceMotion(_ enabled: Bool) {
        guard !isTearingDown, enabled != reduceMotion else { return }
        reduceMotion = enabled
        if state == .settling, let ctx = activeTransition {
            // 正在动画：用新参数重启（旧动画作废；token 机制不变）。
            let target = ctx.targetPage
            abandonActiveTransition()
            springVelocity = 0
            beginSettle(targetPage: target, fromOffset: visualOffset, reason: .reduceMotionChange, createdAt: Date().timeIntervalSince1970)
        }
    }

    // MARK: - cancel / teardown（D1/D7）

    /// 外部干预取消：作废活跃动画，重置到合法确定值（committedPage 静止位），清理会话。
    public func cancel() {
        guard !isTearingDown else { return }
        let hadActivity = activeTransition != nil || state == .tracking
        if activeTransition != nil {
            abandonActiveTransition()
        }
        currentSession = nil
        springVelocity = 0
        committedPage = min(committedPage, max(pageCount - 1, 0))
        visualOffset = Double(committedPage)
        fireOffsetChangeIfChanged()
        if hadActivity || state != .idle {
            setState(.cancelled)
            setState(.idle)
        }
    }

    /// teardown（窗口关闭路径；D7 时序：①isTearingDown 第一时间置位 → ⑤清 activeTransition → ⑥定最终状态。
    /// ②停 display link / ③移除动画 / ④移除 observer 属 UI 层；Core 侧所有入口此后短路，无残留回调）。
    public func teardown() {
        guard !isTearingDown else { return }
        isTearingDown = true
        if activeTransition != nil {
            // 作废动画的 completion 视为被拒（计数；不触发回调——teardown 后零回调，D7）。
            activeTransition?.markStale()
            staleRejectionCount += 1
            activeTransition = nil
        }
        currentSession = nil
        springVelocity = 0
        committedPage = min(committedPage, max(pageCount - 1, 0))
        visualOffset = Double(committedPage)
        state = .idle
    }

    // MARK: - 私有：phase 处理（D5 防御性）

    private func handleBegan(timestamp: TimeInterval) -> Bool {
        guard pageCount > 0 else { return false }
        switch state {
        case .settling:
            // D4：同步接管——旧动画作废，新会话以当前显示位置为起点（不跳回旧起点/目标）。
            interruptActiveTransition(takeoverOffset: visualOffset)
            startSession(offset: visualOffset, timestamp: timestamp)
            setState(.tracking)
            return true
        case .tracking:
            if currentSession?.released == true || currentSession?.isMomentumGlide == true {
                // 旧释放会话被新触控接管：无活跃动画，直接替换会话（momentum 滑行同样被接管）。
                currentSession?.endGlide()
                startSession(offset: visualOffset, timestamp: timestamp)
                return true
            }
            // D5：重复 began（手指未抬起）→ 忽略。
            return false
        case .idle:
            startSession(offset: visualOffset, timestamp: timestamp)
            setState(.tracking)
            return true
        case .interrupted, .cancelled:
            return false
        }
    }

    private func handleChanged(delta: Double, timestamp: TimeInterval) -> Bool {
        guard let session = currentSession, state == .tracking, !session.released else { return false }
        applyTrackedDelta(session, scaledDeltaPx: delta * parameters.inputSensitivity, timestamp: timestamp)
        return true
    }

    private func handleEnded(timestamp: TimeInterval) -> Bool {
        guard let session = currentSession, state == .tracking, !session.released else { return false }
        session.markReleased()
        return true
    }

    private func handleMomentumBegan(timestamp: TimeInterval) -> Bool {
        guard let session = currentSession, state == .tracking, session.released else { return false }
        session.beginMomentum(timestamp: timestamp)
        // T-worker-b-glide：momentumGlideFrames=0 → 不跟随系统流，momentum 一开始即释放决策
        // （=RM 降级效果：无惯性滑行，直接回弹/翻页/吸住；RM 下参数不生效，D8 行为不变）。
        if !reduceMotion, parameters.momentumGlideFrames == 0 {
            return finishGesture(timestamp: timestamp)
        }
        return true
    }

    private func handleMomentumChanged(delta: Double, timestamp: TimeInterval) -> Bool {
        guard let session = currentSession, state == .tracking, session.released, session.momentumActive else { return false }
        if session.isMomentumGlide {
            session.endGlide() // 事件驱动重新接管滑行（D5：phase 优先）
        }
        applyTrackedDelta(session, scaledDeltaPx: delta * parameters.inputSensitivity, timestamp: timestamp)
        session.noteMomentumChanged()
        // T-worker-b-glide 截断：跟随帧数达上限（N 帧 ≈ 2N 事件）→ 用当前速度做释放决策。
        // 决策路径与 momentumEnded 一致（回弹/翻页/吸住，无跳变）；截断后系统后续 momentum
        // 事件被上方 guard（state 已离开 tracking）防御拒绝 → commit 至多 1 次，无双重提交。
        if !reduceMotion,
           let limit = parameters.momentumGlideFrames,
           limit >= 1,
           session.momentumChangedCount >= limit * 2 {
            return finishGesture(timestamp: timestamp)
        }
        return true
    }

    private func handleMomentumEnded(timestamp: TimeInterval) -> Bool {
        guard let session = currentSession, state == .tracking, session.released else { return false }
        let stopVelocity = parameters.velocityThreshold * Self.glideStopFraction
        if abs(session.velocityPxPerSecond) > stopVelocity && !reduceMotion {
            // 惯性滑行（tracking 子阶段；Core tick 驱动，momentumDecay 每帧衰减）。
            // D8：Reduce Motion 下降级为不做惯性滑行（momentum 缩短 → 0），直接释放决策；
            //     速度仍参与翻页决策，状态机/转换条件/token 机制不变。
            session.beginGlide()
            return true
        }
        // 惯性已耗尽（或 RM）→ 直接释放决策。
        return finishGesture(timestamp: timestamp)
    }

    private func handlePhaseCancelled() {
        guard state == .tracking, currentSession != nil else { return }
        // 系统取消手势：回到 committedPage 静止位；不做 commit（D1：cancelled→idle）。
        currentSession = nil
        springVelocity = 0
        visualOffset = Double(committedPage)
        fireOffsetChangeIfChanged()
        setState(.cancelled)
        setState(.idle)
    }

    private func applyTrackedDelta(_ session: GestureSession, scaledDeltaPx: Double, timestamp: TimeInterval) {
        let raw = visualOffset + scaledDeltaPx / pageWidth
        var bounded = applyingBoundary(to: raw)
        // T-worker-b-overshoot：momentum 跟随阶段过冲钳制——只限展示 offset；
        // 速度估算走样本真实 delta/dt（recordDelta），不受钳制影响 → 决策速度完整保留。
        if session.momentumActive {
            bounded = applyingMomentumOvershootClamp(to: bounded)
        }
        visualOffset = bounded
        session.recordDelta(scaledDeltaPx, timestamp: timestamp, resultingOffset: bounded)
        fireOffsetChangeIfChanged()
    }

    // MARK: - 私有：settle / 中断 / 边界 / 滑行

    private func beginSettle(targetPage: Int, fromOffset: Double, reason: SettleReason, createdAt: TimeInterval) {
        transitionToken &+= 1
        let ctx = TransitionContext(
            token: transitionToken,
            targetPage: targetPage,
            fromOffset: fromOffset,
            reason: reason,
            createdAt: createdAt
        )
        activeTransition = ctx
        springVelocity = 0
        setState(.settling)
        events.onTransitionBegin?(ctx)

        let duration = parameters.effectiveSettleDuration(reduceMotion: reduceMotion)
        if duration <= 0.001 {
            // RM：即刻提交（D8：参数降级，token/状态机逻辑不变）。
            visualOffset = Double(targetPage)
            fireOffsetChangeIfChanged()
            _ = completeSettle(ctx)
        } else if abs(fromOffset - Double(targetPage)) < Self.positionEpsilon {
            // 已在目标位（无位移回弹）→ 立即自然完成（避免无意义动画）。
            _ = completeSettle(ctx)
        }
    }

    private func interruptActiveTransition(takeoverOffset: Double) {
        guard let ctx = activeTransition else { return }
        ctx.markStale()
        activeTransition = nil
        springVelocity = 0
        staleRejectionCount += 1
        interruptionCount += 1
        events.onStaleRejection?(ctx.token)
        events.onInterruption?(PagingInterruption(
            takeoverOffset: takeoverOffset,
            abandonedTargetPage: ctx.targetPage,
            abandonedToken: ctx.token
        ))
        setState(.interrupted)
    }

    private func abandonActiveTransition() {
        guard let ctx = activeTransition else { return }
        ctx.markStale()
        activeTransition = nil
        springVelocity = 0
        staleRejectionCount += 1
        events.onStaleRejection?(ctx.token)
    }

    /// momentum 过冲软阻尼（T-worker-b-softdamp/-symdamp；原硬钳制在越限点顶死 offset → 多事件
    /// 静止帧 ≈60ms"顿一下再吸"；改为软阻尼逼近）：momentum 阶段 offset 越过 committedPage+1+
    /// momentumMaxOvershoot（正向）/ committedPage-1-momentumMaxOvershoot（负向，T-worker-b-symdamp
    /// 对称化：阻尼线 = 目标页 ± overshoot，与正向同构）后，越限深度按事件增量递推吸收
    /// （depth += Self.momentumOvershootDamping × 本事件 delta）——正 delta 下每事件 offset
    /// 严格前进（无静止帧）、单调逼近；峰值 = 阻尼线 ± 0.2×越限后增量累计。边界页（committed
    /// 在首/末页）不介入——既有 applyingBoundary 阻尼已约束（其上限 maxLegal+maximumOverscroll
    /// ≤ 本软阻尼上界，不冲突；committed=1 时负向线 = −0.2，首页 overscroll 仍由边界阻尼负责）。
    /// 只改展示 offset，速度样本（真实 delta/dt）不受影响。
    private func applyingMomentumOvershootClamp(to newOffset: Double) -> Double {
        let overshoot = parameters.momentumMaxOvershoot
        guard overshoot >= 0 else { return newOffset }
        if newOffset > Double(committedPage + 1) + overshoot, committedPage < pageCount - 1 {
            let limit = Double(committedPage + 1) + overshoot
            let prevDepth = max(visualOffset - limit, 0)
            let depth = prevDepth + (newOffset - visualOffset) * Self.momentumOvershootDamping
            return limit + max(depth, 0)
        }
        if newOffset < Double(committedPage - 1) - overshoot, committedPage > 0 {
            let limit = Double(committedPage - 1) - overshoot
            // T-worker-b-symdamp：阻尼线低于首页（committed=1 → 线 −0.2 < minLegal 0）时
            // 钳制不介入——首页 overscroll 由既有边界阻尼负责（避免双重阻尼互相抵消）。
            guard limit >= 0 else { return newOffset }
            let prevDepth = max(limit - visualOffset, 0)
            let depth = prevDepth + (visualOffset - newOffset) * Self.momentumOvershootDamping
            return limit - max(depth, 0)
        }
        return newOffset
    }

    /// 边界阻尼（D6/D1 边界反馈）：越界增量阻尼（boundaryResistance），越界深度封顶（maximumOverscroll / RM 0）。
    /// 向内回拉不阻尼；保证单调连续，不累积无限位移。
    private func applyingBoundary(to newOffset: Double) -> Double {
        guard pageCount > 0 else { return 0 }
        let maxOverscroll = parameters.effectiveMaximumOverscroll(reduceMotion: reduceMotion)
        let minLegal = 0.0
        let maxLegal = Double(pageCount - 1)
        let prev = visualOffset
        var result = newOffset
        if newOffset < minLegal {
            let prevDepth = max(minLegal - prev, 0)
            let candidateDepth = max(minLegal - newOffset, 0)
            let added = candidateDepth - prevDepth
            let dampedAdded = added > 0 ? added * parameters.boundaryResistance : added
            let depth = min(max(prevDepth + dampedAdded, 0), maxOverscroll)
            result = minLegal - depth
        } else if newOffset > maxLegal {
            let prevDepth = max(prev - maxLegal, 0)
            let candidateDepth = max(newOffset - maxLegal, 0)
            let added = candidateDepth - prevDepth
            let dampedAdded = added > 0 ? added * parameters.boundaryResistance : added
            let depth = min(max(prevDepth + dampedAdded, 0), maxOverscroll)
            result = maxLegal + depth
        }
        return result
    }

    /// spring 手动插值（D2 选定方案；每帧闭式解）。
    /// 角频率推导：阻尼包络衰减到 1% 的时刻 = effectiveSettleDuration → ω0 = ln(100) / (ζ × duration)。
    private func advanceSpring(deltaTime: TimeInterval) {
        guard let ctx = activeTransition else { return }
        let target = Double(ctx.targetPage)
        let zeta = parameters.settleSpringDamping
        let duration = parameters.effectiveSettleDuration(reduceMotion: reduceMotion)
        guard zeta > 0, duration > 0 else { return }
        let omega0 = log(100.0) / (zeta * duration)
        let omegaD = omega0 * sqrt(max(1 - zeta * zeta, 0.0001))
        let x0 = visualOffset - target
        let v0 = springVelocity
        let a = x0
        let b = (v0 + zeta * omega0 * x0) / omegaD
        let decay = exp(-zeta * omega0 * deltaTime)
        let cosT = cos(omegaD * deltaTime)
        let sinT = sin(omegaD * deltaTime)
        let x = decay * (a * cosT + b * sinT)
        let v = decay * ((-zeta * omega0 * a + omegaD * b) * cosT + (-zeta * omega0 * b - omegaD * a) * sinT)
        visualOffset = target + x
        springVelocity = v
        fireOffsetChangeIfChanged()
    }

    /// momentum 惯性滑行（tracking 子阶段；D1）。每帧位移 velocity×dt，速度按 momentumDecay 衰减；
    /// 撞边界（clamp 生效）或速度耗尽（≤ velocityThreshold × glideStopFraction）→ 停止并释放决策。
    private func advanceGlide(deltaTime: TimeInterval) {
        guard let session = currentSession, session.isMomentumGlide, pageWidth > 0 else { return }
        var velocityPages = session.velocityPxPerSecond / pageWidth
        let raw = visualOffset + velocityPages * deltaTime
        let bounded = applyingBoundary(to: raw)
        let hitBoundary = abs(bounded - raw) > 1e-12
        visualOffset = bounded
        fireOffsetChangeIfChanged()
        if hitBoundary {
            velocityPages = 0
        } else {
            velocityPages *= parameters.momentumDecay
        }
        session.updateGlideVelocity(velocityPages * pageWidth)
        session.syncToVisualOffset(visualOffset)
        let stopVelocity = parameters.velocityThreshold * Self.glideStopFraction
        if hitBoundary || abs(session.velocityPxPerSecond) <= stopVelocity {
            session.endGlide()
            _ = finishGesture(timestamp: session.lastTimestamp)
        }
    }

    // MARK: - 私有：辅助

    private func startSession(offset: Double, timestamp: TimeInterval) {
        sessionIDCounter &+= 1
        currentSession = GestureSession(id: sessionIDCounter, startOffset: offset, timestamp: timestamp)
    }

    private func clampToValidPage(_ page: Int) -> Int {
        min(max(page, 0), max(pageCount - 1, 0))
    }

    private func setState(_ newState: PagingState) {
        guard state != newState else { return }
        state = newState
        events.onStateChange?(state)
    }

    private func fireOffsetChangeIfChanged() {
        guard abs(visualOffset - lastFiredOffset) > Self.offsetEventEpsilon else { return }
        lastFiredOffset = visualOffset
        events.onVisualOffsetChange?(visualOffset)
    }
}
