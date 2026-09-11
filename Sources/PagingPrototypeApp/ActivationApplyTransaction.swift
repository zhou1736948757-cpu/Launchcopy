//
//  ActivationApplyTransaction.swift
//  PagingPrototypeApp
//
//  Phase 1H T-1H-B/F：Settings 草稿的运行时事务执行（校验 → 计划 → 运行时 → 持久化）。
//  - 纯步骤顺序沿用 ActivationApplyPlanner（statusItem → hotCorner → shortcut → fourFinger → launchAtLogin）。
//  - Launch at Login 经 LaunchAtLoginServicing；requiresApproval / failure / unavailable 不宣称成功，回滚偏好位。
//  - 测试注入 FakeLaunchAtLoginService；不得在测试路径触达真实 SMAppService 注册。
//

import Foundation

/// Settings Apply 事务结果（可映射到中文 NSAlert）。
public enum ActivationApplyTransactionOutcome: Equatable, Sendable {
    /// 草稿与已提交相等：无副作用。
    case noOp(ActivationPreferences)
    /// 校验失败：不改运行时、不持久化。
    case invalid([ActivationDraftValidationError])
    /// 全部步骤被接受并已持久化。
    case applied(ActivationPreferences)
    /// Launch at Login 未被接受（requiresApproval / failure / unavailable / 方向不匹配）。
    /// `accepted` 已回滚 login 偏好位并尽量恢复运行时；已按 accepted 持久化（若可）。
    case loginNotAccepted(accepted: ActivationPreferences, status: LaunchAtLoginStatus)
    /// 持久化被拒绝（未来 schema）；`runtimeRestored` 表示是否已尝试恢复已提交运行时。
    case persistRefused(storedVersion: Int, acceptedRuntime: ActivationPreferences, runtimeRestored: Bool)
}

/// 运行时副作用注入面（组合根 / 测试 Fake）。
@MainActor
public struct ActivationApplyTransactionContext {
    public var applyPreferences: (ActivationPreferences) -> Void
    public var setStatusItemVisible: (Bool) -> Void
    public var loginService: any LaunchAtLoginServicing
    public var persist: (ActivationPreferences) -> ActivationPreferencesSaveResult

    public init(
        applyPreferences: @escaping (ActivationPreferences) -> Void,
        setStatusItemVisible: @escaping (Bool) -> Void = { _ in },
        loginService: any LaunchAtLoginServicing,
        persist: @escaping (ActivationPreferences) -> ActivationPreferencesSaveResult
    ) {
        self.applyPreferences = applyPreferences
        self.setStatusItemVisible = setStatusItemVisible
        self.loginService = loginService
        self.persist = persist
    }
}

/// 执行 Settings Apply 事务。
@MainActor
public enum ActivationApplyTransaction {

    /// 校验草稿、应用可逆运行时变更、仅在接受态持久化。
    public static func run(
        committed: ActivationPreferences,
        draft: ActivationPreferencesDraft,
        context: ActivationApplyTransactionContext
    ) -> ActivationApplyTransactionOutcome {
        switch ActivationApplyPlanner.plan(from: committed, to: draft) {
        case .invalid(let errors):
            return .invalid(errors)
        case .planned(let plan):
            if plan.isNoOp {
                return .noOp(committed)
            }
            return execute(plan: plan, committed: committed, context: context)
        }
    }

    // MARK: - Execute

    private static func execute(
        plan: ActivationApplyPlan,
        committed: ActivationPreferences,
        context: ActivationApplyTransactionContext
    ) -> ActivationApplyTransactionOutcome {
        let proposed = plan.proposed
        let loginStep = plan.steps.first(where: {
            if case .launchAtLogin = $0 { return true }
            return false
        })

        // 先按「非 login」目标推进运行时；login 偏好位暂保留已提交值，直至服务确认。
        var accepted = proposed
        accepted.settings.launchAtLoginEnabled = committed.settings.launchAtLoginEnabled

        applyNonLoginRuntime(accepted: accepted, committed: committed, context: context)

        if case .launchAtLogin(let enabled) = loginStep {
            let status = context.loginService.setEnabled(enabled)
            if Self.isLoginStatusAcceptable(status, requestedEnabled: enabled) {
                accepted.settings.launchAtLoginEnabled = enabled
            } else {
                // 不宣称成功：偏好位保持旧值；若先前为关且本次想开启失败，尝试卸载以对齐 disabled。
                if enabled, committed.settings.launchAtLoginEnabled == false {
                    _ = context.loginService.setEnabled(false)
                }
                accepted.settings.launchAtLoginEnabled = committed.settings.launchAtLoginEnabled
                // 运行时非 login 部分已是 proposed；login 位与 committed 一致。
                switch context.persist(accepted) {
                case .saved:
                    return .loginNotAccepted(accepted: accepted, status: status)
                case .refusedFutureSchema(let version):
                    restoreCommittedRuntime(committed, context: context)
                    return .persistRefused(
                        storedVersion: version,
                        acceptedRuntime: committed,
                        runtimeRestored: true
                    )
                }
            }
        }

        switch context.persist(accepted) {
        case .saved:
            return .applied(accepted)
        case .refusedFutureSchema(let version):
            restoreCommittedRuntime(committed, context: context)
            return .persistRefused(
                storedVersion: version,
                acceptedRuntime: committed,
                runtimeRestored: true
            )
        }
    }

    /// 应用 status item + composition 偏好（不含 login 服务调用）。
    private static func applyNonLoginRuntime(
        accepted: ActivationPreferences,
        committed: ActivationPreferences,
        context: ActivationApplyTransactionContext
    ) {
        if accepted.settings.showStatusItem != committed.settings.showStatusItem {
            context.setStatusItemVisible(accepted.settings.showStatusItem)
        }
        context.applyPreferences(accepted)
    }

    private static func restoreCommittedRuntime(
        _ committed: ActivationPreferences,
        context: ActivationApplyTransactionContext
    ) {
        context.setStatusItemVisible(committed.settings.showStatusItem)
        context.applyPreferences(committed)
        _ = context.loginService.setEnabled(committed.settings.launchAtLoginEnabled)
    }

    /// 请求方向与产品态是否一致（不允许 requiresApproval/failure 冒充成功）。
    public static func isLoginStatusAcceptable(
        _ status: LaunchAtLoginStatus,
        requestedEnabled: Bool
    ) -> Bool {
        switch status {
        case .enabled:
            return requestedEnabled
        case .disabled:
            return !requestedEnabled
        case .requiresApproval, .unavailable, .failure:
            return false
        }
    }
}
