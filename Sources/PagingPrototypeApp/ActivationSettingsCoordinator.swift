//
//  ActivationSettingsCoordinator.swift
//  PagingPrototypeApp
//
//  Phase 1H T-1H-B/F：Settings 组合薄协调器。
//  - 持有 store + login service + window controller；showSettings 前置已有窗或创建单实例。
//  - Apply：validate → ActivationApplyTransaction → persist / composition / login。
//  - 启动时不自动启用真实 login item（D4）。
//

import AppKit
import Foundation

/// Settings 协调器（AppDelegate 强持有）。
@MainActor
public final class ActivationSettingsCoordinator {

    public let store: any ActivationPreferencesPersisting
    public let loginService: any LaunchAtLoginServicing

    /// 注入：将已接受偏好应用到激活组合根。
    public var applyPreferences: (ActivationPreferences) -> Void

    /// 注入：status item 可见性变更（安装 / 拆除）。
    public var setStatusItemVisible: (Bool) -> Void

    /// 注入：四指就绪中文旁路（Enabled ≠ Ready）。
    public var fourFingerReadinessProvider: () -> String

    /// 最近一次已接受并用于 UI 的偏好（与 store 对齐；future schema 时用内存默认）。
    public private(set) var committed: ActivationPreferences

    private var windowController: ActivationSettingsWindowController?

    public init(
        store: any ActivationPreferencesPersisting,
        loginService: any LaunchAtLoginServicing,
        initialCommitted: ActivationPreferences? = nil,
        applyPreferences: @escaping (ActivationPreferences) -> Void = { _ in },
        setStatusItemVisible: @escaping (Bool) -> Void = { _ in },
        fourFingerReadinessProvider: @escaping () -> String = {
            ActivationSettingsUIStrings.fourFingerNotReady
        }
    ) {
        self.store = store
        self.loginService = loginService
        self.applyPreferences = applyPreferences
        self.setStatusItemVisible = setStatusItemVisible
        self.fourFingerReadinessProvider = fourFingerReadinessProvider
        if let initialCommitted {
            self.committed = initialCommitted
        } else {
            switch store.load() {
            case .loaded(let prefs):
                self.committed = prefs
            case .futureSchema:
                self.committed = ActivationPreferences()
            }
        }
    }

    // MARK: - Show

    /// 打开或前置同一设置窗（永不创建重复实例）。
    public func showSettings() {
        let draft = ActivationPreferencesDraft(committed: committed)
        let controller = ActivationSettingsWindowController.sharedOrCreate(
            draft: draft,
            fourFingerReadinessProvider: { [weak self] in
                self?.fourFingerReadinessProvider() ?? ActivationSettingsUIStrings.fourFingerNotReady
            },
            launchAtLoginStatusProvider: { [weak self] in
                let status = self?.loginService.currentStatus() ?? .disabled
                return ActivationSettingsUIStrings.launchAtLoginStatusText(status)
            },
            onApply: { [weak self] draft in
                self?.handleApply(draft) ?? .failure(
                    title: ActivationSettingsUIStrings.alertTitle,
                    message: "内部错误：设置协调器不可用。"
                )
            },
            onRevert: {
                // 「恢复默认」= 产品出厂默认（含 launchAtLogin=false、热键/热角 Off 等），
                // 不是回到上次已提交草稿。
                ActivationPreferencesDraft(committed: ActivationPreferences())
            }
        )
        self.windowController = controller
        controller.showSettings()
    }

    /// 设置窗是否在前台可见。
    public var isSettingsVisible: Bool {
        windowController?.isSettingsVisible == true
            || ActivationSettingsWindowController.shared?.isSettingsVisible == true
    }

    /// 隐藏设置窗（启动器空白点击优先关闭设置时用）。
    public func hideSettings() {
        windowController?.hideSettings()
        ActivationSettingsWindowController.shared?.hideSettings()
    }

    // MARK: - Apply

    /// 供测试直接调用的 Apply（不依赖窗体）。
    @discardableResult
    public func applyDraft(_ draft: ActivationPreferencesDraft) -> ActivationApplyTransactionOutcome {
        let context = ActivationApplyTransactionContext(
            applyPreferences: { [weak self] prefs in
                self?.applyPreferences(prefs)
            },
            setStatusItemVisible: { [weak self] show in
                self?.setStatusItemVisible(show)
            },
            loginService: loginService,
            persist: { [weak self] prefs in
                guard let self else { return .refusedFutureSchema(storedVersion: Int.max) }
                return self.store.save(prefs)
            }
        )
        let outcome = ActivationApplyTransaction.run(
            committed: committed,
            draft: draft,
            context: context
        )
        switch outcome {
        case .noOp(let prefs):
            committed = prefs
        case .applied(let prefs):
            committed = prefs
            windowController?.reload(draft: ActivationPreferencesDraft(committed: prefs))
        case .loginNotAccepted(let accepted, _):
            committed = accepted
            windowController?.reload(draft: ActivationPreferencesDraft(committed: accepted))
        case .invalid:
            break
        case .persistRefused(_, let acceptedRuntime, _):
            committed = acceptedRuntime
            windowController?.reload(draft: ActivationPreferencesDraft(committed: acceptedRuntime))
        }
        return outcome
    }

    private func handleApply(_ draft: ActivationPreferencesDraft) -> ActivationSettingsApplyUIResult {
        let outcome = applyDraft(draft)
        switch outcome {
        case .noOp, .applied:
            return .success
        case .invalid(let errors):
            return .failure(
                title: ActivationSettingsUIStrings.alertTitle,
                message: ActivationSettingsUIStrings.validationMessage(errors)
            )
        case .loginNotAccepted(_, let status):
            let detail = ActivationSettingsUIStrings.launchAtLoginStatusText(status)
            return .failure(
                title: ActivationSettingsUIStrings.loginAlertTitle,
                message: "未能完成「登录时打开」。\(detail)\n其他已接受的设置已保存；登录项偏好未宣称成功。"
            )
        case .persistRefused(let version, _, _):
            return .failure(
                title: ActivationSettingsUIStrings.alertTitle,
                message: "无法写入偏好（存储版本 \(version) 新于当前应用）。已尝试恢复先前配置。"
            )
        }
    }
}

// MARK: - Four-finger readiness helper

public enum ActivationSettingsFourFingerReadiness {
    /// 从组合根推导中文旁路文案（Enabled ≠ Ready）。
    @MainActor
    public static func text(from composition: ActivationComposition?) -> String {
        guard let composition else {
            return ActivationSettingsUIStrings.fourFingerNotReady
        }
        guard let fourFinger = composition.fourFinger else {
            if composition.appliedPlan.fourFingerEnabled {
                return ActivationSettingsUIStrings.fourFingerReadinessText(
                    isReady: false,
                    detail: "后端未连接"
                )
            }
            return ActivationSettingsUIStrings.fourFingerReadinessText(isReady: false)
        }
        let status = fourFinger.displayStatus
        if status.isReady {
            return ActivationSettingsUIStrings.fourFingerReady
        }
        let detail: String
        switch status.state {
        case .off: detail = "已关闭"
        case .checking: detail = "检查中"
        case .ready: detail = status.enabled ? "就绪" : "开关已关"
        case .noDevice: detail = "无设备"
        case .unavailable: detail = "不可用"
        case .permissionNotConfirmed: detail = "权限未确认"
        case .suspended: detail = "已挂起"
        }
        return ActivationSettingsUIStrings.fourFingerReadinessText(isReady: false, detail: detail)
    }
}
