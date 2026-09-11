//
//  PinchRecognizer.swift
//  PagingPrototypeApp
//
//  Phase 1G 独立四指捏合识别器（T-G-P1；T-G-P6 重构 R-05）。
//  PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT §19.2 十二条合同 + §23.1 P01-P20（纯逻辑部分）。
//  纯 Foundation 值类型：无 AppKit、无锁、无真实设备访问、不持久化触点数据。
//  设备标识 = 进程内不透明 token（不写盘、不跨运行关联）。
//  时钟 = 可注入单调时钟（生产 PinchSystemClock 用 systemUptime；禁止墙钟 Date 差值）。
//  输出 = 只发 show(source: fourFingerPinch, eventToken:) 等价语义（§21.1）；无 hide 事件（P17）。
//  判定模型（T-G-P6 定案，参照 LaunchBetter PinchAnalyzer 语义）：候选段首帧恰好 4 触点即建立基线半径，
//  每帧按 (baselineRadius - currentRadius) / baselineRadius >= shrinkThreshold 判定触发；
//  无稳定窗口、无噪声容忍、无重锚定（实机证据：快速捏合无静止段，稳定窗口模型无法识别，见 results/T-G-P6.md §R-03/R-04）。
//  参数经 T-G-P6 实机定案：shrinkThreshold 0.15（实测收缩 47-57%）、maxGestureDuration 3.5s（§R-03）、cooldown 0.5。
//

import Foundation

// MARK: - 时钟

/// 可注入单调时钟（测试注入 fake clock；生产用 PinchSystemClock）。
public protocol PinchClock: Sendable {
    func now() -> TimeInterval
}

/// 系统单调时钟适配（生产用；systemUptime 单调不回拨，禁止 Date 差值直接相减）。
public struct PinchSystemClock: PinchClock {
    public init() {}
    public func now() -> TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }
}

// MARK: - 不透明 token

/// 设备标识：进程内不透明 token。不写盘、不跨运行关联；识别器只按相等性使用。
public struct PinchDeviceID: Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
}

/// 触点标识：进程内不透明 token（provider 分配；识别器只按相等性使用）。
public struct PinchContactID: Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
}

/// 接触会话标识：识别器内部生成，随事件 token 派发用于去重。
public struct PinchSessionID: Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
}

// MARK: - 帧模型

/// 触点位置（任意单位；识别器只做相对几何，不记录原始轨迹）。
public struct PinchPoint: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// 单个触点。
public struct PinchContact: Equatable, Sendable {
    public var id: PinchContactID
    public var position: PinchPoint
    public init(id: PinchContactID, position: PinchPoint) {
        self.id = id
        self.position = position
    }
}

/// 帧阶段。
public enum PinchFramePhase: Equatable, Sendable {
    case began      // 会话首帧（一个或多个触点开始）
    case moved      // 进行中帧（0 触点 = 全部离面 = 结束证据）
    case ended      // 显式结束（全部离面）
    case cancelled  // 系统取消
}

/// 一帧触点数据（provider 交付；timestamp 与注入时钟同一单调时间域）。
/// provider 契约：每个接触会话按 began → moved* → ended/cancelled 顺序交付；
/// 识别器对 began 中段到达保守处理（视为普通帧，不重置锁存）。
public struct PinchFrame: Equatable, Sendable {
    public var deviceID: PinchDeviceID
    public var timestamp: TimeInterval
    public var phase: PinchFramePhase
    public var contacts: [PinchContact]

    public init(deviceID: PinchDeviceID, timestamp: TimeInterval, phase: PinchFramePhase, contacts: [PinchContact]) {
        self.deviceID = deviceID
        self.timestamp = timestamp
        self.phase = phase
        self.contacts = contacts
    }
}

// MARK: - 参数

/// 识别参数（§19.2 合同 3：阈值/时间上限/冷却/安全上限分别命名；T-G-P6 已删除稳定窗口与噪声容忍）。
/// 数值经 T-G-P6 实机定案：收缩阈值 0.15（实测收缩 47-57%，余量充足）、时间上限 3.5s（§R-03：慢速手势候选到触发 1.6-3.2s）。
public struct PinchParameters: Equatable, Sendable {
    /// 严格有效触点数量（合同 1：恰好 4，非 >=4）。
    public var requiredContactCount: Int
    /// 归一化收缩触发阈值（合同 3；T-G-P6 首帧基线模型：相对首帧半径收缩 ≥ 阈值触发）。
    public var shrinkThreshold: Double
    /// 归一化扩张取消阈值（P17：pinchOut 无 Hide；扩张超限取消候选）。
    public var expansionCancelThreshold: Double
    /// 手势时间上限（合同 3；候选超限取消；T-G-P6 定案 3.5s，慢速手势候选到触发 1.6-3.2s）。
    public var maxGestureDuration: TimeInterval
    /// 触发后冷却（合同 7：附加保护，不是重新武装唯一条件；单调时钟、识别器级，跨会话/跨设备）。
    public var cooldown: TimeInterval
    /// 单帧触点数量上限（合同 10：非法计数安全拒绝）。
    public var maxContactCount: Int
    /// 基线半径下限（合同 10：候选首帧近零半径安全拒绝）。
    public var minBaselineRadius: Double
    /// 数据过期窗口（合同 10/12：过期帧拒绝；候选/识别中静默超限保守重置）。
    public var dataExpiryInterval: TimeInterval

    public init(
        requiredContactCount: Int = 4,
        shrinkThreshold: Double = 0.15,
        expansionCancelThreshold: Double = 0.15,
        maxGestureDuration: TimeInterval = 3.5,
        cooldown: TimeInterval = 0.5,
        maxContactCount: Int = 8,
        minBaselineRadius: Double = 0.02,
        dataExpiryInterval: TimeInterval = 0.5
    ) {
        self.requiredContactCount = requiredContactCount
        self.shrinkThreshold = shrinkThreshold
        self.expansionCancelThreshold = expansionCancelThreshold
        self.maxGestureDuration = maxGestureDuration
        self.cooldown = cooldown
        self.maxContactCount = maxContactCount
        self.minBaselineRadius = minBaselineRadius
        self.dataExpiryInterval = dataExpiryInterval
    }
}

// MARK: - 状态

/// 挂起原因（与 LauncherSuspensionReason 对齐但独立；识别器不依赖 presentation 层）。
public enum PinchSuspensionReason: Equatable, Sendable {
    case sleep
    case sessionInactive
    case screenConfigurationChanged
}

/// 识别器状态（§19.2 十二条可测语义；Fired 与 WaitingForRelease 分开保留以区分 P02/P07 与 P17）。
/// T-G-P6 首帧基线模型：candidate = 候选首帧（恰好 4 触点）建基线；次帧起进入 recognizing 逐帧判定（无稳定窗口）。
public enum PinchRecognizerState: Equatable, Sendable {
    case disabled
    case idle
    case candidate
    case recognizing
    case fired
    case waitingForRelease
    case suspended(reason: PinchSuspensionReason)
}

/// 会话取消原因（中性 enum，允许低频统计）。
public enum PinchCancelReason: Equatable, Sendable {
    case contactCountChanged
    case contactReplaced
    case dataExpired
    case degenerateGeometry
    case timeLimitExceeded
    case expansion
    case suspended
    case stopped
    case disconnected
}

// MARK: - 事件

/// 事件 token（generation + sessionID；消费方用于派发去重与丢弃旧事件，§19.3）。
public struct PinchEventToken: Equatable, Sendable {
    public let generation: Int
    public let sessionID: PinchSessionID
    public init(generation: Int, sessionID: PinchSessionID) {
        self.generation = generation
        self.sessionID = sessionID
    }
}

/// 识别器输出事件（§21.1：只发 show(source: fourFingerPinch, eventToken:) 等价语义；无 hide 事件，P17）。
public enum PinchEvent: Equatable, Sendable {
    case showRequested(token: PinchEventToken)
}

// MARK: - 会话内部状态

/// 单设备接触会话（内部；设备隔离，P09）。
private struct PinchDeviceSession: Sendable {
    enum Phase: Equatable, Sendable {
        case candidate
        case recognizing
        case fired
        case waitingForRelease
    }

    var sessionID: PinchSessionID
    var phase: Phase
    /// 候选建立时刻（首个恰好 4 触点帧；时间上限从此起算）。
    var candidateStartedAt: TimeInterval
    /// 基线半径（候选首帧建立后固定；T-G-P6 首帧基线模型，无重锚定）。
    var baselineRadius: Double?
    /// 候选首帧触点 ID 集合（触点更换取消判定，P08；无基线位置记录）。
    var contactIDs: Set<PinchContactID>
    /// 最近一帧时间戳（乱序判定）。
    var lastSeenTimestamp: TimeInterval
}

// MARK: - 识别器

/// 独立四指捏合识别器（纯值状态机；无锁，调用方负责串行化访问）。
public struct PinchRecognizer: Sendable {
    public private(set) var state: PinchRecognizerState
    /// 事件 generation（stop/restart/teardown 递增；消费方据此丢弃旧事件，P13/P14）。
    public private(set) var generation: Int
    /// 中性计数：识别次数（允许记录）。
    public private(set) var fireCount: Int
    /// 中性计数：冷却抑制的触发次数（允许记录）。
    public private(set) var suppressedFireCount: Int
    /// 中性计数：会话取消原因分布（允许记录）。
    public private(set) var cancelCounts: [PinchCancelReason: Int]
    /// 中性计数：被拒绝的帧数（非有限数/非法计数/乱序/未来/过期/畸形，允许记录）。
    public private(set) var rejectedFrameCount: Int
    /// 最近一次触发的延迟（候选建立 → 触发；低频统计）。
    public private(set) var lastFireLatency: TimeInterval?
    /// 最近活跃设备（聚合状态来源）。
    public private(set) var activeDeviceID: PinchDeviceID?
    /// 最近活跃会话。
    public private(set) var activeSessionID: PinchSessionID?

    public var parameters: PinchParameters
    private let clock: PinchClock
    private var sessions: [PinchDeviceID: PinchDeviceSession]
    private var nextSessionID: Int
    private var suspendedReason: PinchSuspensionReason?
    /// 最近触发时刻（识别器级冷却，跨会话/跨设备）。
    private var lastFireTime: TimeInterval?

    /// 时间比较容差（浮点误差防护；远小于任何交互参数，如 0.5-0.4=0.09999999999999998 的边界）。
    private static let timeEpsilon: TimeInterval = 1e-9

    public init(parameters: PinchParameters = PinchParameters(), clock: PinchClock) {
        self.parameters = parameters
        self.clock = clock
        self.state = .disabled
        self.generation = 0
        self.fireCount = 0
        self.suppressedFireCount = 0
        self.cancelCounts = [:]
        self.rejectedFrameCount = 0
        self.lastFireLatency = nil
        self.activeDeviceID = nil
        self.activeSessionID = nil
        self.sessions = [:]
        self.nextSessionID = 1
        self.suspendedReason = nil
        self.lastFireTime = nil
    }

    /// 是否已启用（UI 层据此管理采集订阅）。
    public var isEnabled: Bool {
        state != .disabled
    }

    /// 是否处于挂起状态。
    private var isSuspended: Bool {
        if case .suspended = state { return true }
        return false
    }

    // MARK: - 生命周期

    /// 启动/启用：disabled → idle（清空会话；幂等，P14）。
    public mutating func start() {
        guard state == .disabled else { return }
        clearAllSessions(reason: nil)
        suspendedReason = nil
        state = .idle
    }

    /// 停止/禁用：任何状态 → disabled；清基线/会话/待派发意图；generation +1（P13/P14）。
    public mutating func stop() {
        guard state != .disabled else { return }
        clearAllSessions(reason: .stopped)
        suspendedReason = nil
        generation += 1
        state = .disabled
    }

    /// disable 别名（与 stop 同语义）。
    public mutating func disable() {
        stop()
    }

    /// teardown 别名（幂等；UI 层保证 teardown 后零回调）。
    public mutating func teardown() {
        stop()
    }

    /// 重启：清空并重新启用（generation +1；旧 generation 事件失效，P14）。
    public mutating func restart() {
        clearAllSessions(reason: .stopped)
        suspendedReason = nil
        generation += 1
        state = .idle
    }

    /// 挂起（sleep / session inactive / 屏幕重配）：清基线/会话/待派发意图（合同 11）。
    public mutating func suspend(reason: PinchSuspensionReason) {
        guard state != .disabled else { return }
        clearAllSessions(reason: .suspended)
        suspendedReason = reason
        state = .suspended(reason: reason)
    }

    /// 恢复：→ idle（新会话必须重新建基线）。
    public mutating func resume() {
        guard case .suspended = state else { return }
        suspendedReason = nil
        state = .idle
    }

    /// 设备断开（可靠结束证据；移除该设备会话，P10）。
    public mutating func deviceDisconnected(_ deviceID: PinchDeviceID) {
        guard state != .disabled, !isSuspended else { return }
        if sessions.removeValue(forKey: deviceID) != nil {
            recordCancel(.disconnected)
        }
        refreshAggregateState()
    }

    // MARK: - 帧处理

    /// 处理一帧（provider 交付；返回本帧产生的事件）。
    public mutating func process(_ frame: PinchFrame) -> [PinchEvent] {
        switch state {
        case .disabled, .suspended:
            return [] // P13：开关关闭/暂停后 late callback 丢弃
        case .idle, .candidate, .recognizing, .fired, .waitingForRelease:
            break
        }

        // 合同 10：非有限数 / 非法计数 / 重复触点 / 负时间戳安全拒绝
        guard validateFrame(frame) else { return [] }

        let now = clock.now()

        // 合同 10/12：未来帧拒绝；过期帧拒绝
        guard frame.timestamp <= now else {
            rejectedFrameCount += 1
            return []
        }
        // 绝对年龄（合同 10）：帧时间戳相对识别时钟过期则拒绝。
        // 生产异步交付路径在 ActivationComposition 对齐时间戳后再调用，避免误杀活流。
        guard now - frame.timestamp <= parameters.dataExpiryInterval + Self.timeEpsilon else {
            rejectedFrameCount += 1
            return []
        }

        // 合同 12：候选/识别中静默超限 → 保守重置（非"无回调=释放"）；锁存状态保持
        if let session = sessions[frame.deviceID],
           now - session.lastSeenTimestamp > parameters.dataExpiryInterval + Self.timeEpsilon {
            switch session.phase {
            case .candidate, .recognizing:
                sessions.removeValue(forKey: frame.deviceID)
                recordCancel(.dataExpired)
                // T-G-P7 R-08（M-1 修复）：静默移除后立即刷新聚合状态（与 deviceDisconnected/endSession 一致），
                // 否则同帧触点数 ≠ 4 提前 return 时 state 会停留在 .candidate/.recognizing 而 sessions 已空。
                refreshAggregateState()
            case .fired, .waitingForRelease:
                break
            }
        }

        // 结束证据（P10）：零触点 moved / ended / cancelled
        if frame.phase == .ended || frame.phase == .cancelled || (frame.phase == .moved && frame.contacts.isEmpty) {
            endSession(frame.deviceID)
            return []
        }

        // began 帧必须带触点（0 触点 began 为畸形帧，拒绝）
        if frame.phase == .began && frame.contacts.isEmpty {
            rejectedFrameCount += 1
            return []
        }

        // 无会话：恰好 requiredContactCount 触点才建立候选（合同 1；P04）
        guard let existing = sessions[frame.deviceID] else {
            guard frame.contacts.count == parameters.requiredContactCount else { return [] }
            var session = newSession(deviceID: frame.deviceID, timestamp: frame.timestamp)
            let events = advance(session: &session, frame: frame, now: now)
            sessions[frame.deviceID] = session
            refreshAggregateState()
            return events
        }

        // 有会话：乱序拒绝（P12）
        guard frame.timestamp >= existing.lastSeenTimestamp else {
            rejectedFrameCount += 1
            return []
        }

        var session = existing
        session.lastSeenTimestamp = frame.timestamp
        let events = advance(session: &session, frame: frame, now: now)
        sessions[frame.deviceID] = session
        refreshAggregateState()
        return events
    }

    // MARK: - 内部

    private mutating func validateFrame(_ frame: PinchFrame) -> Bool {
        guard frame.timestamp >= 0 else {
            rejectedFrameCount += 1
            return false
        }
        guard frame.contacts.count <= parameters.maxContactCount else {
            rejectedFrameCount += 1
            return false
        }
        var seen = Set<PinchContactID>()
        for contact in frame.contacts {
            guard contact.position.x.isFinite, contact.position.y.isFinite else {
                rejectedFrameCount += 1
                return false
            }
            guard seen.insert(contact.id).inserted else {
                rejectedFrameCount += 1
                return false
            }
        }
        return true
    }

    private mutating func newSession(deviceID: PinchDeviceID, timestamp: TimeInterval) -> PinchDeviceSession {
        let sessionID = PinchSessionID(rawValue: nextSessionID)
        nextSessionID += 1
        return PinchDeviceSession(
            sessionID: sessionID,
            phase: .candidate,
            candidateStartedAt: timestamp,
            baselineRadius: nil,
            contactIDs: [],
            lastSeenTimestamp: timestamp
        )
    }

    private mutating func advance(session: inout PinchDeviceSession, frame: PinchFrame, now: TimeInterval) -> [PinchEvent] {
        switch session.phase {
        case .candidate, .recognizing:
            // 触点数量必须恰好 requiredContactCount（合同 1；五指/三指 → 取消候选，P04/P07）
            guard frame.contacts.count == parameters.requiredContactCount else {
                cancelSession(&session, reason: .contactCountChanged)
                return []
            }
            // 触点身份必须与基线一致（合同 5；P08；首帧后 contactIDs 非空起校验）
            if !session.contactIDs.isEmpty {
                let ids = Set(frame.contacts.map(\.id))
                guard ids == session.contactIDs else {
                    cancelSession(&session, reason: .contactReplaced)
                    return []
                }
            }
            // 时间上限（合同 3；R-03 定案 3.5s）
            guard frame.timestamp - session.candidateStartedAt <= parameters.maxGestureDuration + Self.timeEpsilon else {
                cancelSession(&session, reason: .timeLimitExceeded)
                return []
            }

            if session.phase == .candidate {
                // 首帧建基线；次帧起（baselineRadius 已固定）进入 recognizing 逐帧判定（T-G-P6：无稳定窗口）
                guard session.baselineRadius == nil else {
                    session.phase = .recognizing
                    return advanceRecognizing(session: &session, frame: frame, now: now)
                }
                return advanceCandidate(session: &session, frame: frame)
            }
            return advanceRecognizing(session: &session, frame: frame, now: now)

        case .fired, .waitingForRelease:
            // 锁存：触点仍在面 → 保持（P02/P07/P17）；结束证据在 process() 已处理
            return []
        }
    }

    private mutating func advanceCandidate(session: inout PinchDeviceSession, frame: PinchFrame) -> [PinchEvent] {
        // 首帧基线（T-G-P6 R-05：参照 LaunchBetter PinchAnalyzer 语义；无稳定窗口/无噪声容忍/无重锚定）
        let positions = Dictionary(uniqueKeysWithValues: frame.contacts.map { ($0.id, $0.position) })
        let baselineRadius = radius(of: positions)
        guard baselineRadius >= parameters.minBaselineRadius else {
            cancelSession(&session, reason: .degenerateGeometry)
            return []
        }
        session.baselineRadius = baselineRadius
        session.contactIDs = Set(frame.contacts.map(\.id))
        // 首帧收缩量为 0，不判定；次帧起 advance() 转 recognizing 逐帧判定（快速捏合可在次帧即触发）
        return []
    }

    private mutating func advanceRecognizing(session: inout PinchDeviceSession, frame: PinchFrame, now: TimeInterval) -> [PinchEvent] {
        guard let baselineRadius = session.baselineRadius, baselineRadius > 0 else {
            cancelSession(&session, reason: .degenerateGeometry)
            return []
        }
        // 每帧判定（T-G-P6：相对首帧基线，无重锚定；触发后 startDistance 更新语义不适用——本状态机锁存 fired，一会话一次）
        let currentRadius = radius(of: Dictionary(uniqueKeysWithValues: frame.contacts.map { ($0.id, $0.position) }))
        let contraction = (baselineRadius - currentRadius) / baselineRadius

        if contraction >= parameters.shrinkThreshold {
            // 冷却（合同 7：附加保护；识别器级，跨会话/跨设备）
            if let last = lastFireTime, now - last < parameters.cooldown - Self.timeEpsilon {
                suppressedFireCount += 1
                session.phase = .fired // 仍锁存（合同 6：一会话一次）
                return []
            }
            lastFireTime = now
            session.phase = .fired
            fireCount += 1
            lastFireLatency = now - session.candidateStartedAt
            let token = PinchEventToken(generation: generation, sessionID: session.sessionID)
            return [.showRequested(token: token)]
        }

        if contraction <= -parameters.expansionCancelThreshold {
            // P17：pinchOut 无 Hide；扩张超限取消候选（锁存至释放，合同 8）
            cancelSession(&session, reason: .expansion)
            return []
        }

        return [] // 收缩未达阈值：继续跟踪
    }

    private mutating func cancelSession(_ session: inout PinchDeviceSession, reason: PinchCancelReason) {
        session.phase = .waitingForRelease
        recordCancel(reason)
    }

    private mutating func endSession(_ deviceID: PinchDeviceID) {
        sessions.removeValue(forKey: deviceID)
        refreshAggregateState()
    }

    private mutating func clearAllSessions(reason: PinchCancelReason?) {
        if !sessions.isEmpty {
            if let reason = reason {
                recordCancel(reason)
            }
            sessions.removeAll()
        }
        activeDeviceID = nil
        activeSessionID = nil
        lastFireTime = nil
    }

    private mutating func recordCancel(_ reason: PinchCancelReason) {
        cancelCounts[reason, default: 0] += 1
    }

    private mutating func refreshAggregateState() {
        if state == .disabled { return }
        if let reason = suspendedReason {
            state = .suspended(reason: reason)
            return
        }
        guard let (deviceID, session) = sessions.max(by: { $0.value.lastSeenTimestamp < $1.value.lastSeenTimestamp }) else {
            state = .idle
            activeDeviceID = nil
            activeSessionID = nil
            return
        }
        activeDeviceID = deviceID
        activeSessionID = session.sessionID
        switch session.phase {
        case .candidate: state = .candidate
        case .recognizing: state = .recognizing
        case .fired: state = .fired
        case .waitingForRelease: state = .waitingForRelease
        }
    }

    private func radius(of positions: [PinchContactID: PinchPoint]) -> Double {
        guard !positions.isEmpty else { return 0 }
        var cx = 0.0
        var cy = 0.0
        for p in positions.values {
            cx += p.x
            cy += p.y
        }
        cx /= Double(positions.count)
        cy /= Double(positions.count)
        var sum = 0.0
        for p in positions.values {
            sum += distance(p, PinchPoint(x: cx, y: cy))
        }
        return sum / Double(positions.count)
    }

    private func distance(_ a: PinchPoint, _ b: PinchPoint) -> Double {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
