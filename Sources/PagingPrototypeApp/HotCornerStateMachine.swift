//
//  HotCornerStateMachine.swift
//  PagingPrototypeApp
//
//  Phase 1G Hot Corner 纯状态机（T-1G-A）。
//  PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT §3.7：默认 Off；用户显式选择 corner 后才启动
//  检测；从 zone 外进入才开始 dwell；启动时已在角落不立即触发；dwell 满足后只触发一次 .show；
//  必须离开带 hysteresis 的 re-arm 区才能再次触发；cooldown/dwell/zone size/poll interval 分离；
//  按键按下/drag/sleep/session inactive 不触发；launcher 可见时暂停；屏幕重配取消 dwell；
//  唤醒后要求指针重新离开/进入；disabled 时零动作。Hot Corner 只发 .show，永不反向 hide。
//  可注入 fake clock。纯 Foundation，无 AppKit。
//

import Foundation

/// 屏幕角落（中性 enum，允许记录）。
public enum HotCorner: String, Codable, CaseIterable, Equatable, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

/// 可注入时钟（测试注入 fake clock；生产用 HotCornerSystemClock）。
public protocol HotCornerClock: Sendable {
    func now() -> TimeInterval
}

/// 系统时钟适配（生产用）。
public struct HotCornerSystemClock: HotCornerClock {
    public init() {}

    public func now() -> TimeInterval {
        Date().timeIntervalSinceReferenceDate
    }
}

/// Hot Corner 参数（§3.9：与显示刷新率无关，dwell/cooldown 不用 frame count）。
public struct HotCornerParameters: Equatable, Sendable {
    /// 角落热区边长（pt）。
    public var zoneSize: Double
    /// 驻留时长（s）。
    public var dwellDuration: TimeInterval
    /// re-arm 回退余量（pt）。
    public var hysteresisInset: Double
    /// 触发后冷却（s）。
    public var cooldown: TimeInterval

    public init(zoneSize: Double, dwellDuration: TimeInterval, hysteresisInset: Double, cooldown: TimeInterval) {
        self.zoneSize = zoneSize
        self.dwellDuration = dwellDuration
        self.hysteresisInset = hysteresisInset
        self.cooldown = cooldown
    }
}

/// Hot Corner 状态（§3.7 领域状态）。
public enum HotCornerState: Equatable, Sendable {
    case disabled
    case armed
    case insideCandidate(corner: HotCorner, screenID: ScreenID, enteredAt: TimeInterval)
    case triggeredAwaitingExit(corner: HotCorner, screenID: ScreenID)
    case suspended(reason: LauncherSuspensionReason)
}

/// 状态机输出事件（只发 .show，永不反向 hide）。
public enum HotCornerEvent: Equatable, Sendable {
    case showRequested(corner: HotCorner, screenID: ScreenID)
}

/// Hot Corner 纯状态机（值类型；UI 层负责低频轮询调度与 NSEvent.mouseLocation 采样）。
public struct HotCornerStateMachine {
    public private(set) var state: HotCornerState
    public private(set) var selectedCorner: HotCorner?
    public private(set) var lastTriggerTime: TimeInterval?
    /// 中性计数（允许记录）。
    public private(set) var triggerCount: Int
    public private(set) var geometry: ScreenGeometrySnapshot?

    public var parameters: HotCornerParameters
    private let clock: HotCornerClock
    private var requiresExitBeforeDwell: Bool
    private var launcherIsVisible: Bool
    private var inputSuppressed: Bool

    public init(
        parameters: HotCornerParameters,
        clock: HotCornerClock,
        geometry: ScreenGeometrySnapshot? = nil
    ) {
        self.parameters = parameters
        self.clock = clock
        self.geometry = geometry
        self.state = .disabled
        self.selectedCorner = nil
        self.lastTriggerTime = nil
        self.triggerCount = 0
        self.requiresExitBeforeDwell = false
        self.launcherIsVisible = false
        self.inputSuppressed = false
    }

    /// 是否处于检测中（UI 层据此管理 timer：disabled = 零 timer 零轮询）。
    public var isActive: Bool {
        state != .disabled
    }

    // MARK: - 配置

    /// 启用（用户显式选择 corner 后调用）。从 disabled/任意状态 → armed。
    public mutating func enable(corner: HotCorner) {
        selectedCorner = corner
        state = .armed
        requiresExitBeforeDwell = false
    }

    /// 禁用：任何状态 → disabled；零动作（UI 层须停 timer）。
    public mutating func disable() {
        selectedCorner = nil
        state = .disabled
        requiresExitBeforeDwell = false
    }

    /// teardown 别名（幂等；UI 层保证 teardown 后零回调）。
    public mutating func teardown() {
        disable()
    }

    /// 挂起（sleep / session inactive / 屏幕重配）。
    public mutating func suspend(reason: LauncherSuspensionReason) {
        guard state != .disabled else { return }
        state = .suspended(reason: reason)
    }

    /// 恢复：→ armed，并要求指针重新离开/进入后才开始 dwell（§3.11，不立即触发）。
    public mutating func resume() {
        guard case .suspended = state else { return }
        state = .armed
        requiresExitBeforeDwell = true
    }

    /// 屏幕几何原子替换：取消旧 dwell / 重新武装（§3.8）。
    public mutating func updateGeometry(_ snapshot: ScreenGeometrySnapshot?) {
        geometry = snapshot
        switch state {
        case .insideCandidate, .triggeredAwaitingExit:
            state = .armed
        default:
            break
        }
    }

    /// launcher 可见时暂停触发（不发重复请求）；隐藏时重置 dwell 起点。
    public mutating func setLauncherVisible(_ visible: Bool) {
        launcherIsVisible = visible
        if !visible, case .insideCandidate(let corner, let screenID, _) = state {
            state = .insideCandidate(corner: corner, screenID: screenID, enteredAt: clock.now())
        }
    }

    /// 鼠标按键按下 / drag active：取消 dwell（重新进入才重新计时），不触发。
    public mutating func setInputSuppressed(_ suppressed: Bool) {
        inputSuppressed = suppressed
        if suppressed, case .insideCandidate = state {
            state = .armed
        }
    }

    // MARK: - 采样

    /// 一次采样（UI 层低频轮询调用；pointer 为当前指针位置，时钟由注入 clock 提供）。
    public mutating func sample(pointer: LauncherPoint) -> [HotCornerEvent] {
        guard let selected = selectedCorner, let geometry = geometry else { return [] }
        let now = clock.now()

        switch state {
        case .disabled, .suspended:
            return []

        case .armed:
            guard !inputSuppressed else { return [] }
            guard let match = geometry.cornerZone(at: pointer, zoneSize: parameters.zoneSize),
                  match.corner == selected else {
                // 观察到指针在热区外：清除"唤醒后需先离开"标记
                requiresExitBeforeDwell = false
                return []
            }
            if requiresExitBeforeDwell {
                return [] // 唤醒后：要求先离开再进入
            }
            state = .insideCandidate(corner: match.corner, screenID: match.screenID, enteredAt: now)
            return []

        case .insideCandidate(let corner, let screenID, let enteredAt):
            // 乱序/过期样本忽略（stale timer/session）
            guard now >= enteredAt else { return [] }
            guard !inputSuppressed else {
                state = .armed // 按键/drag：取消 dwell
                return []
            }
            guard !launcherIsVisible else { return [] } // 可见时暂停，不发重复请求
            guard let match = geometry.cornerZone(at: pointer, zoneSize: parameters.zoneSize) else {
                state = .armed // 已离开全部热区：取消 dwell
                return []
            }
            if match.corner != corner || match.screenID != screenID {
                // 快速跨越到另一角落：旧 dwell 取消，新角落重新计时（不触发）
                state = .insideCandidate(corner: match.corner, screenID: match.screenID, enteredAt: now)
                return []
            }
            guard now - enteredAt >= parameters.dwellDuration else { return [] }
            if let last = lastTriggerTime, now - last < parameters.cooldown {
                return [] // 冷却中：保持 insideCandidate，冷却满后再触发
            }
            lastTriggerTime = now
            triggerCount += 1
            state = .triggeredAwaitingExit(corner: corner, screenID: screenID)
            return [.showRequested(corner: corner, screenID: screenID)]

        case .triggeredAwaitingExit(let corner, let screenID):
            guard !geometry.isInsideReArmZone(
                pointer: pointer,
                corner: corner,
                screenID: screenID,
                zoneSize: parameters.zoneSize,
                hysteresis: parameters.hysteresisInset
            ) else {
                return [] // 仍在 re-arm 区：保持，不重复触发
            }
            state = .armed // 离开 re-arm 区 → 重新武装
            return []
        }
    }
}
