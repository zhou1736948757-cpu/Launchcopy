//
//  FourFingerActivationCoordinator.swift
//  PagingPrototypeApp
//
//  Phase 1G 四指激活接线组件（T-G-P4）。
//  PinchEvent.showRequested(token:) → LauncherPresentationCoordinator.show(source: .fourFingerPinch, targetScreen:)。
//  纯逻辑值类型：不触碰窗口行为代码/AppDelegate；targetScreen 由接线层注入（T-1G-E 接真实屏幕）。
//  语义（PLAN §9 不变量 2/3；PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT §21.1/§19.3）：
//  - 四指只发 show，永不 hide/quit（不变量 3；quit 由呈现协调器独占）。
//  - 同一 PinchEventToken 只产生一次 show（token.generation + sessionID 去重，§19.3）。
//  - Q-1（Workflow/decisions/2026-09-05-pending-questions-1g.md）：识别器 suspend() 不递增
//    generation → 本层在 suspend 时清空排队 show（"suspend 时清队列"），suspend 前排队事件不得重放。
//  - QUESTION-1（T-G-P3-r1）：provider 重复上报 ready → 幂等接受（不崩溃、不重复启动服务）。
//  - QUESTION-2（T-G-P3-r1）：displayKind (enabled:true, state:.off) → .disabled
//    （后端 off = 无活动，事实展示；开关开不冒充就绪）。
//  - 输入交接（§21.1 会话结束优先）：fired 后交接期间新 show 去重；全指释放（会话结束）清除交接。
//  纯 Foundation；中性计数允许记录；不记录触点坐标/设备序列号/时间戳原始值。
//

import Foundation

/// 四指激活接线组件（值类型；接线层持有并执行其输出的 effect）。
public struct FourFingerActivationCoordinator: Sendable {
    /// 识别器（本组件持有；generation 校验与交接检测依赖其状态）。
    public private(set) var recognizer: PinchRecognizer
    /// 呈现协调器（show 的唯一出口；四指只经此发 show——PLAN §9 不变量 2）。
    public private(set) var presentation: LauncherPresentationCoordinator
    /// 四指入口状态机（后端事实；QUESTION-1 幂等 ready 在此落实）。
    public private(set) var activation: FourFingerActivationStateMachine
    /// 目标屏幕（由接线层注入；T-1G-E 接真实屏幕列表）。
    public var targetScreen: ScreenID
    /// 用户开关（来自 ActivationPreferences；接线层注入；仅用于展示，不 gate 识别器生命周期）。
    public var userEnabled: Bool

    /// 去重：最近一次已消费（产生 show）的事件 token（§19.3）。
    public private(set) var lastConsumedToken: PinchEventToken?
    /// 排队中的 show 事件（Q-1：suspend/stop/restart 时清空；有界，防接线层不 flush 的积压）。
    public private(set) var pendingShowTokens: [PinchEventToken]
    /// 交接 token：show 派发后到会话结束前，新 show 去重（§21.1）。
    public private(set) var handoffToken: PinchEventToken?

    // 中性计数（允许记录；PLAN §9 不变量 7）
    public private(set) var showCount: Int
    public private(set) var suppressedShowCount: Int
    public private(set) var droppedStaleEventCount: Int
    public private(set) var droppedDuplicateEventCount: Int
    public private(set) var droppedHandoffEventCount: Int
    public private(set) var droppedSuspendedEventCount: Int
    public private(set) var droppedTerminatingEventCount: Int

    /// 排队上限（防积压；超出丢新事件并计数——首个手势优先）。
    public static let maxPendingShowTokens = 8

    /// 标准 init：创建识别器（注入 clock 与参数）、呈现协调器、状态机。
    public init(clock: PinchClock,
                targetScreen: ScreenID,
                parameters: PinchParameters = PinchParameters(),
                userEnabled: Bool = false) {
        self.recognizer = PinchRecognizer(parameters: parameters, clock: clock)
        self.presentation = LauncherPresentationCoordinator()
        self.activation = FourFingerActivationStateMachine()
        self.targetScreen = targetScreen
        self.userEnabled = userEnabled
        self.lastConsumedToken = nil
        self.pendingShowTokens = []
        self.handoffToken = nil
        self.showCount = 0
        self.suppressedShowCount = 0
        self.droppedStaleEventCount = 0
        self.droppedDuplicateEventCount = 0
        self.droppedHandoffEventCount = 0
        self.droppedSuspendedEventCount = 0
        self.droppedTerminatingEventCount = 0
    }

    /// 全注入 init（测试/特殊初始状态，如 presentation 已 visible/terminating）。
    public init(recognizer: PinchRecognizer,
                presentation: LauncherPresentationCoordinator = LauncherPresentationCoordinator(),
                activation: FourFingerActivationStateMachine = FourFingerActivationStateMachine(),
                targetScreen: ScreenID,
                userEnabled: Bool = false) {
        self.recognizer = recognizer
        self.presentation = presentation
        self.activation = activation
        self.targetScreen = targetScreen
        self.userEnabled = userEnabled
        self.lastConsumedToken = nil
        self.pendingShowTokens = []
        self.handoffToken = nil
        self.showCount = 0
        self.suppressedShowCount = 0
        self.droppedStaleEventCount = 0
        self.droppedDuplicateEventCount = 0
        self.droppedHandoffEventCount = 0
        self.droppedSuspendedEventCount = 0
        self.droppedTerminatingEventCount = 0
    }

    // MARK: - 查询

    /// 展示状态（QUESTION-2：开关开 + 后端 off → .disabled——后端 off = 无活动，事实展示）。
    public var displayStatus: FourFingerActivationStatus {
        FourFingerActivationStatus(enabled: userEnabled, state: activation.state)
    }

    /// 真正可用 = 开关开 且 后端就绪（Enabled ≠ Ready，§21.2）。
    public var isReady: Bool {
        displayStatus.isReady
    }

    // MARK: - 生命周期（接线层驱动；识别器与状态机同步）

    /// 启动：识别器 → idle；状态机 → checking（幂等）。
    public mutating func start() {
        recognizer.start()
        _ = activation.apply(.start)
    }

    /// 停止：识别器 → disabled（generation+1）；状态机 → off；清排队与交接。
    public mutating func stop() {
        recognizer.stop()
        _ = activation.apply(.stop)
        pendingShowTokens.removeAll()
        handoffToken = nil
        lastConsumedToken = nil
    }

    /// 重启：识别器 generation+1 → idle；状态机 off → checking；清排队与交接。
    public mutating func restart() {
        recognizer.restart()
        _ = activation.apply(.stop)
        _ = activation.apply(.start)
        pendingShowTokens.removeAll()
        handoffToken = nil
        lastConsumedToken = nil
    }

    /// 挂起（sleep/会话不活跃/屏幕重配）：转发识别器/状态机/呈现协调器；
    /// **Q-1：清空排队 show**（suspend 不递增识别器 generation，只能靠清队列防重放）。
    @discardableResult
    public mutating func suspend(reason: PinchSuspensionReason) -> LauncherPresentationEffect {
        recognizer.suspend(reason: reason)
        _ = activation.apply(.suspend(reason: reason))
        pendingShowTokens.removeAll()
        handoffToken = nil
        return presentation.suspend(reason: launcherSuspensionReason(reason))
    }

    /// 恢复：识别器 → idle；状态机 → checking；呈现 → hidden（不自动弹窗，§21.2）。
    @discardableResult
    public mutating func resume() -> LauncherPresentationEffect {
        recognizer.resume()
        _ = activation.apply(.resume)
        return presentation.resume()
    }

    // MARK: - 事件入口

    /// 处理一帧（识别器路径）：转发识别器；showRequested 事件入队（Q-1：suspend 时清队列）。
    /// 返回事件仅供观察/测试断言（已自动入队）；派发请调用 flushPendingShows()。
    /// 注意：不要对返回值再调用 handlePinchEvent（会重复入队；去重保证安全，但属误用）。
    @discardableResult
    public mutating func process(_ frame: PinchFrame) -> [PinchEvent] {
        let wasLatched = recognizer.state == .fired || recognizer.state == .waitingForRelease
        let events = recognizer.process(frame)
        // §21.1 会话结束（全指释放）优先：交接清除（排队保留——延迟派发的 show 仍应生效）
        if wasLatched && recognizer.state == .idle {
            handoffToken = nil
        }
        for event in events {
            if case .showRequested(let token) = event {
                enqueueShow(token: token)
            }
        }
        return events
    }

    /// 外部事件源路径：showRequested 事件入队（与 process 同一队列），由 flushPendingShows() 派发。
    /// 契约：外部源不得跨 suspend 保留事件（suspend 清队列；挂起期间到达的事件在派发时被拒）。
    public mutating func handlePinchEvent(_ event: PinchEvent) {
        if case .showRequested(let token) = event {
            enqueueShow(token: token)
        }
    }

    /// T-1G-E：与 `LauncherWindowController` 同步同一份 presentation 状态机（flush 前后调用）。
    public mutating func adoptPresentation(_ presentation: LauncherPresentationCoordinator) {
        self.presentation = presentation
    }

    /// 派发排队中的 show 事件（按入队顺序；含全部校验：terminating/suspended/generation/去重/交接）。
    @discardableResult
    public mutating func flushPendingShows() -> [LauncherPresentationEffect] {
        var effects: [LauncherPresentationEffect] = []
        for token in pendingShowTokens {
            effects.append(dispatchShow(token: token))
        }
        pendingShowTokens.removeAll()
        return effects
    }

    // MARK: - 后端事实（QUESTION-1）

    /// 处理 provider 状态变化（仅更新状态机；识别器生命周期由 start/stop 驱动）。
    /// QUESTION-1：重复上报 ready → 幂等接受（不崩溃、不重复启动服务）。
    /// 无合法转换的 provider 报告被安全忽略（状态不变，不崩溃）。
    public mutating func handleProviderState(_ state: TouchProviderState) {
        switch state {
        case .off:
            _ = activation.apply(.stop)
        case .checking:
            switch activation.state {
            case .checking:
                break // 已 checking：no-op
            case .noDevice, .unavailable, .permissionNotConfirmed:
                _ = activation.apply(.recheck) // 重新检查
            default:
                break // ready/off/suspended：无合法转换，忽略（状态机契约）
            }
        case .ready:
            guard activation.state != .ready else { return } // QUESTION-1：重复 ready 幂等
            _ = activation.apply(.backendReady)
        case .noDevice:
            _ = activation.apply(.backendNoDevice)
        case .unavailable:
            _ = activation.apply(.backendUnavailable)
        case .permissionNotConfirmed:
            _ = activation.apply(.permissionNotConfirmed)
        case .suspended(let reason):
            _ = activation.apply(.suspend(reason: reason))
        }
    }

    // MARK: - 私有

    private mutating func enqueueShow(token: PinchEventToken) {
        guard pendingShowTokens.count < Self.maxPendingShowTokens else {
            suppressedShowCount += 1
            return // 有界：超出丢新事件（首个手势优先）
        }
        pendingShowTokens.append(token)
    }

    /// 单事件派发（全部校验；四指只发 show，永不 hide/quit——不变量 3）。
    private mutating func dispatchShow(token: PinchEventToken) -> LauncherPresentationEffect {
        // §21.1：正在 Quit → 拒绝新请求
        if presentation.state == .terminating {
            droppedTerminatingEventCount += 1
            suppressedShowCount += 1
            return .none
        }
        // Q-1：挂起期间到达的 show 拒绝（suspend 后不重放）
        let activationSuspended: Bool
        if case .suspended = activation.state { activationSuspended = true } else { activationSuspended = false }
        let presentationSuspended: Bool
        if case .suspended = presentation.state { presentationSuspended = true } else { presentationSuspended = false }
        if activationSuspended || presentationSuspended {
            droppedSuspendedEventCount += 1
            suppressedShowCount += 1
            return .none
        }
        // §19.3：generation 校验（stop/restart 后旧事件丢弃）
        guard token.generation == recognizer.generation else {
            droppedStaleEventCount += 1
            suppressedShowCount += 1
            return .none
        }
        // §19.3：同一 token 只一次 show（去重）
        guard lastConsumedToken != token else {
            droppedDuplicateEventCount += 1
            suppressedShowCount += 1
            return .none
        }
        // §21.1：交接期间（show 派发后到会话结束）新 show 去重
        if let handoff = handoffToken, handoff != token {
            droppedHandoffEventCount += 1
            suppressedShowCount += 1
            return .none
        }
        lastConsumedToken = token
        if handoffToken == nil {
            handoffToken = token // §21.1：交接开始
        }
        showCount += 1
        return presentation.show(source: .fourFingerPinch, targetScreen: targetScreen)
    }

    private func launcherSuspensionReason(_ reason: PinchSuspensionReason) -> LauncherSuspensionReason {
        switch reason {
        case .sleep: return .sleep
        case .sessionInactive: return .sessionInactive
        case .screenConfigurationChanged: return .screenConfigurationChanged
        }
    }
}
