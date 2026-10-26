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
import LauncherLocalization

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
    public var retainedSettingsController: ActivationSettingsWindowController? { windowController }
    public var interfaceStringsProvider: (() -> LocalizedStrings?)?
    public var preservesInterfaceDraftsOnReopen = false
    /// Composition-owned capability normalization before validation, persistence or login actions.
    var normalizeDraft: (ActivationPreferencesDraft) -> ActivationPreferencesDraft = { $0 }
    public var refreshAcceptedInterfaceLanguage: (() -> Void)?
    /// Composition root configures optional settings sections without a second window.
    public var configureAdditionalSettings: ((ActivationSettingsWindowController) -> Void)?

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
    public func showSettings() { prepareSettingsForPresentation().showSettings() }

    /// Resolves/configures the actual controller without ordering or activating it.
    @discardableResult
    public func prepareSettingsForPresentation() -> ActivationSettingsWindowController {
        let preserveDrafts = preservesInterfaceDraftsOnReopen && windowController != nil
        let draft = ActivationPreferencesDraft(committed: committed)
        let controller = ActivationSettingsWindowController.sharedOrCreate(
            draft: draft,
            strings: interfaceStringsProvider?(),
            preserveExistingDraft: preserveDrafts,
            fourFingerReadinessProvider: { [weak self] in
                self?.fourFingerReadinessProvider() ?? ActivationSettingsUIStrings.fourFingerNotReady
            },
            launchAtLoginStatusProvider: { [weak self] in
                let status = self?.loginService.currentStatus() ?? .disabled
                return ActivationServicePresentation.loginStatus(status, strings: self?.interfaceStringsProvider?())
            },
            onApply: { [weak self] draft in
                self?.handleApply(draft) ?? .failure(
                    title: self?.interfaceStringsProvider?()?.activationStatusText(.activationAlertTitle) ?? ActivationSettingsUIStrings.alertTitle,
                    message: self?.interfaceStringsProvider?()?.activationStatusText(.activationCoordinatorUnavailable) ?? "内部错误：设置协调器不可用。"
                )
            },
            onRevert: {
                // 「恢复默认」= 产品出厂默认（含 launchAtLogin=false、热键/热角 Off 等），
                // 不是回到上次已提交草稿。
                ActivationPreferencesDraft(committed: ActivationPreferences())
            }
        )
        self.windowController = controller
        if preserveDrafts { refreshAcceptedInterfaceLanguage?() }
        else { configureAdditionalSettings?(controller) }
        return controller
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
        let draft = normalizeDraft(draft)
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
        let strings = interfaceStringsProvider?()
        switch outcome {
        case .noOp, .applied:
            return .success
        case .invalid(let errors):
            return .failure(
                title: strings?.activationStatusText(.activationAlertTitle) ?? ActivationSettingsUIStrings.alertTitle,
                message: ActivationServicePresentation.validation(errors, strings: strings)
            )
        case .loginNotAccepted(_, let status):
            let detail = ActivationServicePresentation.loginStatus(status, strings: strings)
            return .failure(
                title: strings?.activationStatusText(.activationLoginAlertTitle) ?? ActivationSettingsUIStrings.loginAlertTitle,
                message: strings.map { detail + "\n" + $0.activationStatusText(.activationLoginPartial) } ??
                    "未能完成「登录时打开」。\(detail)\n其他已接受的设置已保存；登录项偏好未宣称成功。"
            )
        case .persistRefused(let version, _, _):
            return .failure(
                title: strings?.activationStatusText(.activationAlertTitle) ?? ActivationSettingsUIStrings.alertTitle,
                message: strings?.activationFutureVersion(version) ??
                    "无法写入偏好（存储版本 \(version) 新于当前应用）。已尝试恢复先前配置。"
            )
        }
    }
}

// MARK: - Four-finger readiness helper

public enum ActivationSettingsFourFingerReadiness {
    /// 从组合根推导中文旁路文案（Enabled ≠ Ready）。
    @MainActor
    public static func text(from composition: ActivationComposition?, strings: LocalizedStrings? = nil) -> String {
        if let strings { return localizedText(from: composition, strings: strings) }
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

// Product copy is rendered from semantic outcomes, never persisted as a translated status.
internal enum ActivationServicePresentation {
    static func loginStatus(_ status: LaunchAtLoginStatus, strings: LocalizedStrings?) -> String {
        guard let strings else { return ActivationSettingsUIStrings.launchAtLoginStatusText(status) }
        switch status {
        case .disabled: return strings.activationStatusText(.activationLoginDisabled)
        case .enabled: return strings.activationStatusText(.activationLoginEnabled)
        case .requiresApproval: return strings.activationStatusText(.activationLoginApproval)
        case .unavailable: return strings.activationStatusText(.activationLoginUnavailable)
        case .failure(let detail):
            return strings.activationStatusText(.activationLoginFailure) + " (" + detail + ")"
        case .operationFailed(let enabling):
            return strings.activationStatusText(.activationLoginFailure) + " (" +
                strings.activationStatusText(enabling ? .activationLoginEnableFailed : .activationLoginDisableFailed) + ")"
        }
    }

    static func validation(_ errors: [ActivationDraftValidationError], strings: LocalizedStrings?) -> String {
        guard let strings else { return ActivationSettingsUIStrings.validationMessage(errors) }
        return errors.map { error in
            switch error {
            case .hotCornerMissingSelectedCorner: return strings.activationStatusText(.activationCornerRequired)
            case .shortcutMissingSpec: return strings.activationStatusText(.activationShortcutRequired)
            case .shortcutMissingModifiers: return strings.activationStatusText(.activationModifierRequired)
            }
        }.joined(separator: "\n")
    }
}

extension ActivationSettingsFourFingerReadiness {
    @MainActor
    private static func localizedText(from composition: ActivationComposition?, strings: LocalizedStrings) -> String {
        guard let composition else { return strings.activationStatusText(.activationGestureNotReady) }
        guard let backend = composition.fourFinger else {
            let label = strings.activationStatusText(.activationGestureNotReady)
            return composition.appliedPlan.fourFingerEnabled ?
                label + " (" + strings.activationStatusText(.activationGestureBackendMissing) + ")" : label
        }
        let status = backend.displayStatus
        if status.isReady { return strings.activationStatusText(.activationGestureReady) }
        let key: ActivationStatusTextKey
        switch status.state {
        case .off: key = .activationGestureOff
        case .checking: key = .activationGestureChecking
        case .ready: key = status.enabled ? .activationGestureReady : .activationGestureSwitchOff
        case .noDevice: key = .activationGestureNoDevice
        case .unavailable: key = .activationGestureUnavailable
        case .permissionNotConfirmed: key = .activationGesturePermission
        case .suspended: key = .activationGestureSuspended
        }
        return strings.activationStatusText(.activationGestureNotReady) + " (" + strings.activationStatusText(key) + ")"
    }
}
