//
//  FourFingerActivationState.swift
//  PagingPrototypeApp
//
//  Phase 1G 四指入口状态模型（T-G-P3）。
//  PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT §21.2：配置至少能表达开关、后端可用性、未验证
//  状态和明确失败原因；状态 Off/Checking/Ready/NoDevice/Unavailable/PermissionNotConfirmed/
//  Suspended（与 T-G-P2 TouchProviderState 七态对齐）；Enabled ≠ Ready——用户打开开关但后端
//  失败时显示事实，不拿 "Enabled=true" 冒充 "Ready=true"。
//  纯值模型 + 状态转换；纯 Foundation，无 AppKit。
//

import Foundation

/// 四指入口状态（与 TouchProviderState 七态对齐；独立类型，可独立演化展示语义）。
public enum FourFingerActivationState: Equatable, Sendable {
    case off
    case checking
    case ready
    case noDevice
    case unavailable
    case permissionNotConfirmed
    case suspended(reason: PinchSuspensionReason)

    /// 与 T-G-P2 provider 状态对齐（1:1 映射）。
    public init(providerState: TouchProviderState) {
        switch providerState {
        case .off: self = .off
        case .checking: self = .checking
        case .ready: self = .ready
        case .noDevice: self = .noDevice
        case .unavailable: self = .unavailable
        case .permissionNotConfirmed: self = .permissionNotConfirmed
        case .suspended(let reason): self = .suspended(reason: reason)
        }
    }
}

/// 状态转换（合法表见 `FourFingerActivationStateMachine.nextState`）。
public enum FourFingerActivationTransition: Equatable, Sendable {
    /// off → checking（启动；已启动 = no-op，幂等）。
    case start
    /// checking → ready（后端就绪）。
    case backendReady
    /// checking/ready → noDevice（无设备）。
    case backendNoDevice
    /// checking/ready → unavailable（后端不可用）。
    case backendUnavailable
    /// checking/ready → permissionNotConfirmed（权限未确认）。
    case permissionNotConfirmed
    /// noDevice/unavailable/permissionNotConfirmed → checking（重新检查：设备接入/权限授予/重试）。
    case recheck
    /// 任意活动状态 → suspended（sleep/会话不活跃/屏幕重配；挂起中可更新原因）。
    case suspend(reason: PinchSuspensionReason)
    /// suspended → checking（恢复后重新检查；不自动弹权限、不呼出窗口，§21.2）。
    case resume
    /// 任意状态 → off（停止；已停止 = no-op，幂等）。
    case stop
}

/// 四指入口状态机（纯值模型；非法转换拒绝并返回 false，状态不变，不崩溃）。
public struct FourFingerActivationStateMachine: Equatable, Sendable {
    public private(set) var state: FourFingerActivationState

    public init(state: FourFingerActivationState = .off) {
        self.state = state
    }

    /// 应用转换；非法转换返回 false 且状态不变。
    @discardableResult
    public mutating func apply(_ transition: FourFingerActivationTransition) -> Bool {
        guard let next = Self.nextState(from: state, applying: transition) else { return false }
        state = next
        return true
    }

    /// 合法转换表（nil = 非法）。
    /// 幂等语义与 T-G-P2 provider 对齐：start 已启动 = no-op；stop 未启动 = no-op。
    public static func nextState(from state: FourFingerActivationState,
                                 applying transition: FourFingerActivationTransition) -> FourFingerActivationState? {
        switch (state, transition) {
        case (.off, .start):
            return .checking
        case (_, .start) where state != .off:
            return state // 已启动：no-op（幂等）
        case (.checking, .backendReady):
            return .ready
        case (.checking, .backendNoDevice):
            return .noDevice
        case (.checking, .backendUnavailable):
            return .unavailable
        case (.checking, .permissionNotConfirmed):
            return .permissionNotConfirmed
        case (.ready, .backendNoDevice):
            return .noDevice
        case (.ready, .backendUnavailable):
            return .unavailable
        case (.ready, .permissionNotConfirmed):
            return .permissionNotConfirmed
        case (.noDevice, .backendReady):
            return .ready
        case (.noDevice, .backendUnavailable):
            return .unavailable
        case (.noDevice, .recheck):
            return .checking
        case (.unavailable, .backendReady):
            return .ready
        case (.unavailable, .backendNoDevice):
            return .noDevice
        case (.unavailable, .recheck):
            return .checking
        case (.permissionNotConfirmed, .backendReady):
            return .ready
        case (.permissionNotConfirmed, .backendNoDevice):
            return .noDevice
        case (.permissionNotConfirmed, .backendUnavailable):
            return .unavailable
        case (.permissionNotConfirmed, .recheck):
            return .checking
        case (_, .suspend(let reason)) where state != .off:
            return .suspended(reason: reason) // 含挂起中更新原因（保持显示事实）
        case (.suspended, .resume):
            return .checking
        case (_, .stop) where state != .off:
            return .off
        case (.off, .stop):
            return .off // 已停止：no-op（幂等）
        default:
            return nil
        }
    }
}

// MARK: - 展示（Enabled ≠ Ready）

/// 展示种类（中性 enum；UI 层映射为文案，本层不产出用户可见字符串）。
public enum FourFingerActivationDisplayKind: Equatable, Sendable {
    /// 开关关（无论后端状态）。
    case disabled
    /// 已开启，检查中。
    case enabledChecking
    /// 已开启且就绪。
    case ready
    /// 已开启，无设备。
    case enabledNoDevice
    /// 已开启，后端不可用。
    case enabledUnavailable
    /// 已开启，权限未确认。
    case enabledPermissionNotConfirmed
    /// 已开启，挂起（sleep/会话不活跃/屏幕重配）。
    case enabledSuspended(reason: PinchSuspensionReason)
}

/// 入口状态展示模型：enabled（用户开关）与 state（后端事实）两个维度；Enabled ≠ Ready。
public struct FourFingerActivationStatus: Equatable, Sendable {
    /// 用户开关（来自 ActivationPreferences.fourFingerActivationEnabled）。
    public var enabled: Bool
    /// 后端事实（来自 provider 状态）。
    public var state: FourFingerActivationState

    public init(enabled: Bool, state: FourFingerActivationState) {
        self.enabled = enabled
        self.state = state
    }

    /// 真正可用 = 开关开 且 后端就绪（不拿 enabled 冒充 ready）。
    public var isReady: Bool {
        enabled && state == .ready
    }

    /// 展示种类：开关关 → disabled；开关开 → 按后端事实展示（显示事实，不冒充就绪）。
    public var displayKind: FourFingerActivationDisplayKind {
        switch state {
        case .off:
            return .disabled
        case .checking:
            return enabled ? .enabledChecking : .disabled
        case .ready:
            return enabled ? .ready : .disabled
        case .noDevice:
            return enabled ? .enabledNoDevice : .disabled
        case .unavailable:
            return enabled ? .enabledUnavailable : .disabled
        case .permissionNotConfirmed:
            return enabled ? .enabledPermissionNotConfirmed : .disabled
        case .suspended(let reason):
            return enabled ? .enabledSuspended(reason: reason) : .disabled
        }
    }
}
