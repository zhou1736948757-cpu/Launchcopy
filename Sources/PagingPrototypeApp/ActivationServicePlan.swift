//
//  ActivationServicePlan.swift
//  PagingPrototypeApp
//
//  Phase 1G 激活服务启停计划（T-G-P3；偏好层语义，不接 AppDelegate）。
//  PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT §9.8-7/§9.8-8：换 corner 先停旧服务再启新服务；
//  快捷键重配失败保留旧注册（rollback，注册级语义见 ShortcutRegistrationOutcome）。
//  本层提供纯值计划语义：
//  - 原子：diff 整体计算，apply 整体应用（每步确定性）；
//  - 幂等：新旧计划相同 → 零转换；
//  - 可回滚：rollback = 反向 diff（transitions(from: new, to: old)），应用后恢复旧计划。
//  真实服务启停由接线层（T-G-P4）执行；本层只定义计划、顺序与回滚契约。
//  纯 Foundation，无 AppKit。
//

import Foundation

/// 激活服务种类（中性 enum，允许记录）。
public enum ActivationServiceKind: Equatable, Sendable, CaseIterable {
    case hotCorner
    case globalShortcut
    case fourFinger
}

/// 服务启停转换（携带目标值；restart = 先停旧服务再启新服务，§9.8-7）。
public enum ActivationServiceTransition: Equatable, Sendable {
    case startHotCorner(HotCorner)
    case stopHotCorner
    case restartHotCorner(HotCorner)
    case startShortcut(ShortcutSpec)
    case stopShortcut
    case restartShortcut(ShortcutSpec)
    case startFourFinger
    case stopFourFinger
    case setFourFingerOutwardHide(enabled: Bool)
}

/// 由偏好派生的服务计划（nil/off = 不运行）。
public struct ActivationServicePlan: Equatable, Sendable {
    public var hotCorner: HotCorner?
    public var globalShortcut: ShortcutSpec?
    public var fourFingerEnabled: Bool
    public var fourFingerOutwardHideEnabled: Bool

    public init(hotCorner: HotCorner? = nil,
                globalShortcut: ShortcutSpec? = nil,
                fourFingerEnabled: Bool = false,
                fourFingerOutwardHideEnabled: Bool = false) {
        self.hotCorner = hotCorner
        self.globalShortcut = globalShortcut
        self.fourFingerEnabled = fourFingerEnabled
        self.fourFingerOutwardHideEnabled = fourFingerOutwardHideEnabled
    }

    /// 从偏好派生：仅已启用的 trigger 进入计划
    /// （hotCornerEnabled 且选了 corner 才运行；globalShortcutEnabled 且有 spec 才运行）。
    public init(settings: ActivationSettings, fourFingerEnabled: Bool,
                fourFingerOutwardHideEnabled: Bool = false) {
        hotCorner = settings.hotCornerEnabled ? settings.selectedCorner : nil
        globalShortcut = settings.globalShortcutEnabled ? settings.shortcut : nil
        self.fourFingerEnabled = fourFingerEnabled
        self.fourFingerOutwardHideEnabled = fourFingerOutwardHideEnabled
    }

    /// 应用一条转换（确定性；restart 语义 = 停旧启新，计划字段直接落到目标值）。
    public mutating func apply(_ transition: ActivationServiceTransition) {
        switch transition {
        case .startHotCorner(let corner), .restartHotCorner(let corner):
            hotCorner = corner
        case .stopHotCorner:
            hotCorner = nil
        case .startShortcut(let spec), .restartShortcut(let spec):
            globalShortcut = spec
        case .stopShortcut:
            globalShortcut = nil
        case .startFourFinger:
            fourFingerEnabled = true
        case .stopFourFinger:
            fourFingerEnabled = false
        case .setFourFingerOutwardHide(let enabled):
            fourFingerOutwardHideEnabled = enabled
        }
    }
}

/// 计划 diff：原子、幂等、可回滚的转换序列。
public enum ActivationServicePlanDiff {
    /// 新旧计划差异。
    /// 顺序契约：先 stop 全部旧服务 → 再 restart 变更服务（停旧启新）→ 最后 start 新服务；
    /// 保证"换 corner 先停旧服务再启新服务"（§9.8-7）与整体原子应用。
    public static func transitions(from old: ActivationServicePlan,
                                   to new: ActivationServicePlan) -> [ActivationServiceTransition] {
        var result: [ActivationServiceTransition] = []

        // 1) stops（旧服务先停）
        if old.hotCorner != nil && new.hotCorner == nil {
            result.append(.stopHotCorner)
        }
        if old.globalShortcut != nil && new.globalShortcut == nil {
            result.append(.stopShortcut)
        }
        if old.fourFingerEnabled && !new.fourFingerEnabled {
            result.append(.stopFourFinger)
        }

        if old.fourFingerOutwardHideEnabled != new.fourFingerOutwardHideEnabled {
            result.append(.setFourFingerOutwardHide(enabled: new.fourFingerOutwardHideEnabled))
        }

        // 2) restarts（值变更：先停旧服务再启新服务）
        if let oldCorner = old.hotCorner, let newCorner = new.hotCorner, oldCorner != newCorner {
            result.append(.restartHotCorner(newCorner))
        }
        if let oldSpec = old.globalShortcut, let newSpec = new.globalShortcut, oldSpec != newSpec {
            result.append(.restartShortcut(newSpec))
        }

        // 3) starts（新服务最后启）
        if old.hotCorner == nil, let newCorner = new.hotCorner {
            result.append(.startHotCorner(newCorner))
        }
        if old.globalShortcut == nil, let newSpec = new.globalShortcut {
            result.append(.startShortcut(newSpec))
        }
        if !old.fourFingerEnabled && new.fourFingerEnabled {
            result.append(.startFourFinger)
        }

        return result
    }

    /// 回滚 = 反向 diff：应用后从新计划恢复旧计划（可回滚语义）。
    /// 若新计划应用中途失败，接线层以本序列恢复旧计划。
    public static func rollback(from new: ActivationServicePlan,
                                to old: ActivationServicePlan) -> [ActivationServiceTransition] {
        transitions(from: new, to: old)
    }
}
