//
//  ActivationApplyPlan.swift
//  PagingPrototypeApp
//
//  Phase 1H T-1H-A：Settings 域草稿 / 校验 / 事务性 apply plan（纯 Foundation）。
//  PHASE1H §6.1–§6.2：Draft → Validation & planning →（后续任务）Runtime application。
//  - 比较已提交 ActivationPreferences 与草稿，产出确定性有序步骤；
//  - 步骤顺序固定：status item → hot corner → shortcut → fourFinger → outwardHide → launchAtLogin；
//  - 回滚 = 成功步骤的逆序（恢复旧目标值）；
//  - 失败映射：指出失败步骤 + 仅回滚已成功前缀，语义为恢复先前已接受配置（不持久化草稿）。
//  本文件无 AppKit、无 SMAppService；Launch at Login 仅布尔目标值。
//

import Foundation

// MARK: - Draft

/// Settings UI 可变草稿（纯值；不直接写 UserDefaults / 系统服务）。
public struct ActivationPreferencesDraft: Equatable, Sendable {
    public var fourFingerActivationEnabled: Bool
    public var fourFingerOutwardHideEnabled: Bool
    public var hotCornerEnabled: Bool
    public var selectedCorner: HotCorner?
    public var globalShortcutEnabled: Bool
    public var shortcut: ShortcutSpec?
    public var showStatusItem: Bool
    public var launchAtLoginEnabled: Bool

    public init(
        fourFingerActivationEnabled: Bool = true,
        fourFingerOutwardHideEnabled: Bool = false,
        hotCornerEnabled: Bool = false,
        selectedCorner: HotCorner? = nil,
        globalShortcutEnabled: Bool = false,
        shortcut: ShortcutSpec? = nil,
        showStatusItem: Bool = true,
        launchAtLoginEnabled: Bool = false
    ) {
        self.fourFingerActivationEnabled = fourFingerActivationEnabled
        self.fourFingerOutwardHideEnabled = fourFingerOutwardHideEnabled
        self.hotCornerEnabled = hotCornerEnabled
        self.selectedCorner = selectedCorner
        self.globalShortcutEnabled = globalShortcutEnabled
        self.shortcut = shortcut
        self.showStatusItem = showStatusItem
        self.launchAtLoginEnabled = launchAtLoginEnabled
    }

    /// 从已提交偏好生成草稿。
    public init(committed: ActivationPreferences) {
        fourFingerActivationEnabled = committed.fourFingerActivationEnabled
        fourFingerOutwardHideEnabled = committed.fourFingerOutwardHideEnabled
        hotCornerEnabled = committed.settings.hotCornerEnabled
        selectedCorner = committed.settings.selectedCorner
        globalShortcutEnabled = committed.settings.globalShortcutEnabled
        shortcut = committed.settings.shortcut
        showStatusItem = committed.settings.showStatusItem
        launchAtLoginEnabled = committed.settings.launchAtLoginEnabled
    }

    /// 物化为待提交偏好（schema = 当前版本）。调用前应先通过校验。
    public func makePreferences() -> ActivationPreferences {
        var settings = ActivationSettings()
        settings.hotCornerEnabled = hotCornerEnabled
        settings.selectedCorner = selectedCorner
        settings.globalShortcutEnabled = globalShortcutEnabled
        settings.shortcut = shortcut
        settings.showStatusItem = showStatusItem
        settings.launchAtLoginEnabled = launchAtLoginEnabled
        return ActivationPreferences(
            schemaVersion: ActivationPreferences.currentSchemaVersion,
            fourFingerActivationEnabled: fourFingerActivationEnabled,
            fourFingerOutwardHideEnabled: fourFingerOutwardHideEnabled,
            settings: settings
        )
    }
}

// MARK: - Validation

/// 草稿校验错误（Sendable；可映射到 Settings 可操作提示）。
public enum ActivationDraftValidationError: Equatable, Sendable {
    /// 启用 Hot Corner 必须选择角。
    case hotCornerMissingSelectedCorner
    /// 启用全局快捷键必须提供 ShortcutSpec。
    case shortcutMissingSpec
    /// 快捷键缺少修饰键（裸键拒绝；与 ShortcutSpecValidator.isRegisterable 一致）。
    case shortcutMissingModifiers
}

/// 草稿完整校验（apply 前必须全部通过）。
public enum ActivationDraftValidator {
    /// 返回全部违规（空 = 合法）。顺序稳定，便于测试。
    public static func validate(_ draft: ActivationPreferencesDraft) -> [ActivationDraftValidationError] {
        var errors: [ActivationDraftValidationError] = []

        if draft.hotCornerEnabled && draft.selectedCorner == nil {
            errors.append(.hotCornerMissingSelectedCorner)
        }

        if draft.globalShortcutEnabled {
            guard let spec = draft.shortcut else {
                errors.append(.shortcutMissingSpec)
                return errors
            }
            // 复用同 target 纯规则（至少一修饰键；禁止裸键）。
            if !ShortcutSpecValidator.isRegisterable(spec) {
                errors.append(.shortcutMissingModifiers)
            }
        }

        return errors
    }
}

// MARK: - Apply steps

/// 文档化 apply 顺序中的目标种类。
public enum ActivationApplyStepTarget: Int, Equatable, Sendable, CaseIterable {
    case statusItem = 0
    case hotCorner = 1
    case shortcut = 2
    case fourFinger = 3
    case launchAtLogin = 4
}

/// 一条可逆运行时变更（绝对目标值；nil/false = 关闭）。
public enum ActivationApplyStep: Equatable, Sendable {
    case statusItem(show: Bool)
    /// `nil` = Hot Corner 关闭。
    case hotCorner(HotCorner?)
    /// `nil` = 注销全局快捷键。
    case shortcut(ShortcutSpec?)
    case fourFinger(enabled: Bool)
    /// Saved mode choice; parent activation controls effective readiness separately.
    case fourFingerOutwardHide(enabled: Bool)
    case launchAtLogin(enabled: Bool)

    public var target: ActivationApplyStepTarget {
        switch self {
        case .statusItem: return .statusItem
        case .hotCorner: return .hotCorner
        case .shortcut: return .shortcut
        case .fourFinger, .fourFingerOutwardHide: return .fourFinger
        case .launchAtLogin: return .launchAtLogin
        }
    }
}

/// 校验通过后的确定性 apply / rollback 计划。
public struct ActivationApplyPlan: Equatable, Sendable {
    /// 正向步骤（仅含变更字段；固定顺序）。
    public let steps: [ActivationApplyStep]
    /// 成功 apply + persist 后应提交的偏好。
    public let proposed: ActivationPreferences
    /// 全量回滚 = `steps` 的逆序旧目标值（从 proposed 回到 committed）。
    public let rollbackSteps: [ActivationApplyStep]

    public var isNoOp: Bool { steps.isEmpty }

    public init(steps: [ActivationApplyStep],
                proposed: ActivationPreferences,
                rollbackSteps: [ActivationApplyStep]) {
        self.steps = steps
        self.proposed = proposed
        self.rollbackSteps = rollbackSteps
    }
}

/// 规划结果：合法计划，或校验失败。
public enum ActivationApplyPlanResult: Equatable, Sendable {
    case planned(ActivationApplyPlan)
    case invalid([ActivationDraftValidationError])
}

/// 中途失败映射：指出失败步骤，并给出已成功前缀的回滚序列。
/// 语义：`restorePreviousAcceptedConfig == true` → 恢复先前已接受配置，不持久化 proposed。
public struct ActivationApplyFailure: Equatable, Sendable {
    public let failedStep: ActivationApplyStep
    public let failedIndex: Int
    /// 仅回滚已成功步骤（`steps[0..<failedIndex]` 的逆序旧值）。
    public let rollbackSteps: [ActivationApplyStep]
    /// 固定为 true：失败 → 恢复先前已接受配置语义。
    public let restorePreviousAcceptedConfig: Bool

    public init(failedStep: ActivationApplyStep,
                failedIndex: Int,
                rollbackSteps: [ActivationApplyStep],
                restorePreviousAcceptedConfig: Bool = true) {
        self.failedStep = failedStep
        self.failedIndex = failedIndex
        self.rollbackSteps = rollbackSteps
        self.restorePreviousAcceptedConfig = restorePreviousAcceptedConfig
    }
}

// MARK: - Planner

/// 纯规划器：校验草稿、diff 已提交偏好、产出 apply / rollback / failure 映射。
public enum ActivationApplyPlanner {

    /// 校验草稿并相对 `committed` 生成确定性计划；相等 → 空步骤（no-op）。
    public static func plan(
        from committed: ActivationPreferences,
        to draft: ActivationPreferencesDraft
    ) -> ActivationApplyPlanResult {
        let errors = ActivationDraftValidator.validate(draft)
        guard errors.isEmpty else { return .invalid(errors) }

        let proposed = draft.makePreferences()
        let (steps, rollbackSteps) = diffSteps(from: committed, to: proposed)
        return .planned(ActivationApplyPlan(
            steps: steps,
            proposed: proposed,
            rollbackSteps: rollbackSteps
        ))
    }

    /// 将中途失败映射为回滚描述（纯值；不执行副作用）。
    /// - Parameter failedAtIndex: 失败步骤在 `plan.steps` 中的下标（该步未成功）。
    public static func failureMapping(
        plan: ActivationApplyPlan,
        failedAtIndex: Int
    ) -> ActivationApplyFailure {
        precondition(!plan.steps.isEmpty, "no-op plan cannot fail a step")
        precondition(failedAtIndex >= 0 && failedAtIndex < plan.steps.count,
                     "failedAtIndex out of range")
        // steps = [A_new, B_new, C_new]
        // rollbackSteps = [C_old, B_old, A_old]
        // failed at 1 → successful prefix [A_new] → rollback suffix [A_old]
        let successfulCount = failedAtIndex
        let rollback = Array(plan.rollbackSteps.suffix(successfulCount))
        return ActivationApplyFailure(
            failedStep: plan.steps[failedAtIndex],
            failedIndex: failedAtIndex,
            rollbackSteps: rollback,
            restorePreviousAcceptedConfig: true
        )
    }

    // MARK: Diff

    /// 固定顺序 diff：statusItem → hotCorner → shortcut → fourFinger → outwardHide → launchAtLogin。
    /// 回滚序列 = 正向变更的逆序旧值。
    public static func diffSteps(
        from committed: ActivationPreferences,
        to proposed: ActivationPreferences
    ) -> (steps: [ActivationApplyStep], rollbackSteps: [ActivationApplyStep]) {
        var steps: [ActivationApplyStep] = []
        var rollbackAccum: [ActivationApplyStep] = []

        func consider(old: ActivationApplyStep, new: ActivationApplyStep) {
            guard old != new else { return }
            steps.append(new)
            rollbackAccum.append(old)
        }

        consider(
            old: .statusItem(show: committed.settings.showStatusItem),
            new: .statusItem(show: proposed.settings.showStatusItem)
        )
        consider(
            old: .hotCorner(effectiveHotCorner(committed.settings)),
            new: .hotCorner(effectiveHotCorner(proposed.settings))
        )
        consider(
            old: .shortcut(effectiveShortcut(committed.settings)),
            new: .shortcut(effectiveShortcut(proposed.settings))
        )
        consider(
            old: .fourFinger(enabled: committed.fourFingerActivationEnabled),
            new: .fourFinger(enabled: proposed.fourFingerActivationEnabled)
        )
        consider(
            old: .fourFingerOutwardHide(enabled: committed.fourFingerOutwardHideEnabled),
            new: .fourFingerOutwardHide(enabled: proposed.fourFingerOutwardHideEnabled)
        )
        consider(
            old: .launchAtLogin(enabled: committed.settings.launchAtLoginEnabled),
            new: .launchAtLogin(enabled: proposed.settings.launchAtLoginEnabled)
        )

        return (steps, Array(rollbackAccum.reversed()))
    }

    private static func effectiveHotCorner(_ settings: ActivationSettings) -> HotCorner? {
        settings.hotCornerEnabled ? settings.selectedCorner : nil
    }

    private static func effectiveShortcut(_ settings: ActivationSettings) -> ShortcutSpec? {
        settings.globalShortcutEnabled ? settings.shortcut : nil
    }
}
