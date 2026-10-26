//
//  ActivationSettingsWindowController.swift
//  PagingPrototypeApp
//
//  Retained native settings window with draft-preserving language presentation.
//  Activation transactions and service status renderers remain coordinator-owned.
//  No pointer positions, screen identifiers or key history are recorded.
//

import AppKit
import Foundation
import LauncherLocalization

// MARK: - Legacy compatibility and selected-snapshot helpers

/// Legacy static APIs retain their original text for source/test compatibility.
/// Shipping controls use typed snapshot overloads and ActivationTextKey instead.
public enum ActivationSettingsUIStrings {
    public static let windowTitle = "设置"
    public static let showStatusItem = "状态菜单显示"
    public static let globalShortcut = "全局快捷键"
    public static let globalShortcutEnable = "启用全局快捷键"
    public static let hotCorner = "Hot Corner"
    public static let hotCornerEnable = "启用 Hot Corner"
    public static let fourFinger = "四指捏合"
    public static let fourFingerEnable = "启用四指捏合"
    public static let launchAtLogin = "登录时打开"
    public static let launchAtLoginEnable = "登录时打开 Launchcopy"
    public static let apply = "应用"
    public static let revert = "恢复默认"
    public static let close = "关闭"
    public static let applySuccess = "已应用成功"
    public static let cornerNone = "未选择"
    public static let cornerTopLeft = "左上角"
    public static let cornerTopRight = "右上角"
    public static let cornerBottomLeft = "左下角"
    public static let cornerBottomRight = "右下角"
    public static let shortcutPlaceholder = "未设置"
    public static let shortcutPresetLabel = "预设"
    public static let shortcutRecord = "录制热键"
    public static let shortcutRecordingPrompt = "请按下组合键…"
    public static let shortcutNeedsModifier = "需要至少一个修饰键"
    public static let fourFingerReady = "就绪"
    public static let fourFingerNotReady = "未就绪"
    public static let alertTitle = "无法应用设置"
    public static let loginAlertTitle = "登录时打开未完成"

    public static let menuShowLauncher = "显示启动器"
    public static let menuHideLauncher = "隐藏启动器"
    public static let menuActivationSettings = "设置…"
    public static let menuQuit = "退出 Launchcopy"

    public static func cornerTitle(_ corner: HotCorner) -> String {
        switch corner {
        case .topLeft: return cornerTopLeft
        case .topRight: return cornerTopRight
        case .bottomLeft: return cornerBottomLeft
        case .bottomRight: return cornerBottomRight
        }
    }

    public static func shortcutDescription(_ spec: ShortcutSpec?) -> String {
        guard let spec else { return shortcutPlaceholder }
        return ShortcutDisplay.description(for: spec)
    }

    public static func launchAtLoginStatusText(_ status: LaunchAtLoginStatus) -> String {
        switch status {
        case .disabled: return "当前：已关闭"
        case .enabled: return "当前：已启用"
        case .requiresApproval: return "当前：需要在系统设置中批准"
        case .unavailable: return "当前：不可用"
        case .failure(let message): return "当前：失败（\(message)）"
        case .operationFailed(let enabling): return enabling ? "当前：失败（无法启用登录时打开。）" : "当前：失败（无法关闭登录时打开。）"
        }
    }

    public static func fourFingerReadinessText(isReady: Bool, detail: String? = nil) -> String {
        if isReady { return fourFingerReady }
        if let detail, !detail.isEmpty { return "\(fourFingerNotReady)（\(detail)）" }
        return fourFingerNotReady
    }

    public static func validationMessage(_ errors: [ActivationDraftValidationError]) -> String {
        let lines = errors.map { error -> String in
            switch error {
            case .hotCornerMissingSelectedCorner:
                return "启用 Hot Corner 前请选择一个角落。"
            case .shortcutMissingSpec:
                return "启用全局快捷键前请选择预设或录制热键。"
            case .shortcutMissingModifiers:
                return "全局快捷键必须包含至少一个修饰键。"
            }
        }
        return lines.joined(separator: "\n")
    }

    public static func cornerTitle(_ corner: HotCorner, strings: LocalizedStrings) -> String {
        switch corner {
        case .topLeft: return strings.activationText(.cornerTopLeft)
        case .topRight: return strings.activationText(.cornerTopRight)
        case .bottomLeft: return strings.activationText(.cornerBottomLeft)
        case .bottomRight: return strings.activationText(.cornerBottomRight)
        }
    }

    public static func shortcutDescription(_ spec: ShortcutSpec?, strings: LocalizedStrings) -> String {
        guard let spec else { return strings.activationText(.shortcutPlaceholder) }
        return ShortcutDisplay.description(for: spec, strings: strings)
    }

    public static func validationMessage(
        _ errors: [ActivationDraftValidationError], strings: LocalizedStrings
    ) -> String {
        errors.map { error in
            let key: ActivationTextKey
            switch error {
            case .hotCornerMissingSelectedCorner: key = .validationCornerMissing
            case .shortcutMissingSpec: key = .validationShortcutMissing
            case .shortcutMissingModifiers: key = .validationShortcutModifiers
            }
            return strings.activationText(key)
        }.joined(separator: "\n")
    }
}

// MARK: - Apply UI callback result

/// 窗体 Apply 回调结果（由 Coordinator 映射事务 outcome）。
public enum ActivationSettingsApplyUIResult: Equatable, Sendable {
    case success
    case failure(title: String, message: String)
}

// MARK: - Window controller

/// 激活设置窗控制器（单实例；静态 weak + 工厂）。
@MainActor
public final class ActivationSettingsWindowController: NSWindowController, NSWindowDelegate, NSTabViewDelegate {

    private static weak var sharedInstance: ActivationSettingsWindowController?

    /// 当前草稿（控件双向绑定到此值的快照；Apply/Revert 经回调）。
    public private(set) var draft: ActivationPreferencesDraft

    /// Readiness renderer; the default resolves against the retained displayed snapshot.
    public var fourFingerReadinessProvider: () -> String

    /// Login status renderer supplied by the service owner, using the displayed snapshot.
    public var launchAtLoginStatusProvider: () -> String

    /// Apply：校验/事务由宿主执行；失败时返回中文提示且保留草稿。
    public var onApply: ((ActivationPreferencesDraft) -> ActivationSettingsApplyUIResult)?

    /// 还原：宿主返回已提交草稿。
    public var onRevert: (() -> ActivationPreferencesDraft)?

    // Controls
    private var showStatusItemCheckbox: NSButton!
    private var shortcutEnableCheckbox: NSButton!
    private var shortcutPresetPopup: NSPopUpButton!
    private var shortcutRecordButton: NSButton!
    private var shortcutDescriptionLabel: NSTextField!
    private var hotCornerEnableCheckbox: NSButton!
    private var hotCornerPopup: NSPopUpButton!
    private var fourFingerEnableCheckbox: NSButton!
    private var fourFingerOutwardHideCheckbox: NSButton!
    private var fourFingerStatusLabel: NSTextField!
    private var launchAtLoginCheckbox: NSButton!
    private var launchAtLoginStatusLabel: NSTextField!
    private var applySuccessLabel: NSTextField!
    private var applySuccessHideWorkItem: DispatchWorkItem?

    /// 本地 keyDown 录制 monitor（仅 Settings 窗；非全局 / 非 CGEvent tap）。
    private var shortcutRecordingMonitor: Any?
    private(set) var isRecordingShortcut = false

    public static var shared: ActivationSettingsWindowController? { sharedInstance }
    public let appearanceView: AppearanceSettingsView
    let mainGridCapacityView: MainGridCapacitySettingsView
    public let appManagementView: AppManagementSettingsView
    public let appSourcesView: AppSourcesSettingsView
    public let languageView: LanguageSettingsView
    let appLibrarySettingsView: AppLibrarySettingsView
    public var onLanguageReadinessChange: (() -> Void)?
    public var onDiscardLanguageDraft: (() -> Void)?
    private var languageStrings: LocalizedStrings
    private var activationButtonTitles: [(NSButton, ActivationTextKey)] = []
    private var activationLabelTitles: [(NSTextField, ActivationTextKey)] = []
    private var activationAccessibility: [(NSView, ActivationTextKey)] = []
    private var shortcutRecordingNeedsModifier = false
    private var applySuccessKey: ActivationTextKey?
    private weak var sectionTabs: NSTabView?

    public var hasLanguagePresentationOwnership: Bool {
        isRecordingShortcut || appSourcesView.hasPresentationOwnership
            || window?.attachedSheet != nil
            || (window?.firstResponder as? NSTextView)?.hasMarkedText() == true
    }

    /// Presentation only: never reload drafts, stop recording or rebuild tabs.
    public var acquireModalOwnership: (() -> (() -> Void))?
    /// Platform seam; the default is the same real AppKit presentation path.
    var alertPresenter: (NSAlert, NSWindow?, @escaping () -> Void) -> Void = { alert, window, finish in
        if let window { alert.beginSheetModal(for: window) { _ in finish() } }
        else { _ = alert.runModal(); finish() }
    }

    public func relabel(strings: LocalizedStrings) {
        languageStrings = strings
        window?.title = strings.settingsText(.settingsWindowTitle)
        for tab in sectionTabs?.tabViewItems ?? [] {
            switch tab.identifier as? String {
            case "activation": tab.label = strings.settingsText(.activationTabTitle)
            case "appearance": tab.label = strings.settingsText(.appearanceTabTitle)
            case "management": tab.label = strings.settingsText(.managementTabTitle)
            case "sources": tab.label = strings.settingsText(.sourcesTabTitle)
            case "language": tab.label = strings.text(.languageTitle)
            case "library": tab.label = strings.libraryText(.title)
            default: break
            }
        }
        relabelActivationControls()
        languageView.relabel(strings: strings)
        appearanceView.relabel(strings: strings)
        appManagementView.relabel(strings: strings)
        appSourcesView.relabel(strings: strings)
        appLibrarySettingsView.relabel(strings: strings)
        mainGridCapacityView.relabel(strings: strings)
    }

    /// 单实例工厂：已存在则复用并刷新草稿；否则创建。
    @discardableResult
    public static func sharedOrCreate(
        draft: ActivationPreferencesDraft,
        strings: LocalizedStrings? = nil,
        preserveExistingDraft: Bool = false,
        fourFingerReadinessProvider: (() -> String)? = nil,
        launchAtLoginStatusProvider: (() -> String)? = nil,
        onApply: ((ActivationPreferencesDraft) -> ActivationSettingsApplyUIResult)? = nil,
        onRevert: (() -> ActivationPreferencesDraft)? = nil
    ) -> ActivationSettingsWindowController {
        if let existing = sharedInstance {
            existing.installStatusProviders(
                fourFinger: fourFingerReadinessProvider, login: launchAtLoginStatusProvider
            )
            if let onApply { existing.onApply = onApply }
            if let onRevert { existing.onRevert = onRevert }
            if !preserveExistingDraft { existing.reload(draft: draft) }
            if let strings { existing.relabel(strings: strings) }
            return existing
        }
        let created = ActivationSettingsWindowController(
            draft: draft,
            strings: strings,
            fourFingerReadinessProvider: fourFingerReadinessProvider,
            launchAtLoginStatusProvider: launchAtLoginStatusProvider,
            onApply: onApply,
            onRevert: onRevert
        )
        sharedInstance = created
        return created
    }

    public init(
        draft: ActivationPreferencesDraft,
        strings: LocalizedStrings? = nil,
        fourFingerReadinessProvider: (() -> String)? = nil,
        launchAtLoginStatusProvider: (() -> String)? = nil,
        onApply: ((ActivationPreferencesDraft) -> ActivationSettingsApplyUIResult)? = nil,
        onRevert: (() -> ActivationPreferencesDraft)? = nil
    ) {
        self.draft = draft
        let initialStrings = strings ?? LocalizedStrings(language: .simplifiedChinese)
        languageStrings = initialStrings
        appearanceView = AppearanceSettingsView(frame: .zero, strings: initialStrings)
        mainGridCapacityView = MainGridCapacitySettingsView(frame: .zero, strings: initialStrings, embedded: true)
        appManagementView = AppManagementSettingsView(frame: .zero, strings: initialStrings)
        appSourcesView = AppSourcesSettingsView(frame: .zero, strings: initialStrings)
        languageView = LanguageSettingsView(frame: .zero, strings: initialStrings)
        appLibrarySettingsView = AppLibrarySettingsView(frame: .zero, strings: initialStrings)
        self.fourFingerReadinessProvider = fourFingerReadinessProvider ?? {
            initialStrings.activationStatusText(.activationGestureNotReady)
        }
        self.launchAtLoginStatusProvider = launchAtLoginStatusProvider ?? {
            initialStrings.activationStatusText(.activationLoginDisabled)
        }
        self.onApply = onApply
        self.onRevert = onRevert
        let window = Self.makeWindow(strings: initialStrings)
        super.init(window: window)
        appearanceView.attachMainGridSection(mainGridCapacityView)
        appearanceView.onRestoreGridDefaults = { [weak mainGridCapacityView] in
            mainGridCapacityView?.defaultsClicked(nil)
        }
        installStatusProviders(fourFinger: fourFingerReadinessProvider, login: launchAtLoginStatusProvider)
        window.delegate = self
        buildContent(in: window)
        reload(draft: draft)
        relabel(strings: initialStrings)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Show / reload

    /// 前置已有窗或首次显示；不创建第二实例（由工厂保证）。
    public func showSettings() {
        guard let window else { return }
        refreshSideStatusLabels()
        isPresented = true
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 显式呈现标记（比单靠 `NSWindow.isVisible` 更稳：避免偶发误判导致空白点击直接藏启动器）。
    private var isPresented = false

    /// 设置窗是否可见（用于启动器空白点击优先级：先关设置，再藏启动器）。
    public var isSettingsVisible: Bool {
        if isPresented { return true }
        guard let window else { return false }
        return window.isVisible || window.isKeyWindow
    }

    /// 隐藏设置窗（不退出应用、不销毁单实例）。
    public func hideSettings() {
        appSourcesView.cancelPendingOperations()
        stopShortcutRecording(restoreLabel: true)
        isPresented = false
        window?.orderOut(nil)
        appearanceView.onDiscardDraft?()
        mainGridCapacityView.onDiscardDraft?()
        onDiscardLanguageDraft?()
        onLanguageReadinessChange?()
    }

    /// 用新草稿覆盖控件（打开 / 应用成功 / 还原）。
    public func reload(draft: ActivationPreferencesDraft) {
        stopShortcutRecording(restoreLabel: true)
        self.draft = draft
        syncControlsFromDraft()
        refreshSideStatusLabels()
    }

    /// 从控件收集当前草稿（Apply 前调用）。
    public func collectDraftFromControls() -> ActivationPreferencesDraft {
        var next = draft
        next.showStatusItem = showStatusItemCheckbox.state == .on
        next.globalShortcutEnabled = shortcutEnableCheckbox.state == .on
        next.hotCornerEnabled = hotCornerEnableCheckbox.state == .on
        next.selectedCorner = selectedCornerFromPopup()
        next.fourFingerActivationEnabled = fourFingerEnableCheckbox.state == .on
        next.fourFingerOutwardHideEnabled = fourFingerOutwardHideCheckbox.state == .on
        next.launchAtLoginEnabled = launchAtLoginCheckbox.state == .on
        // shortcut 由预设选择 / 录制写入 draft.shortcut；此处保留当前值。
        return next
    }

    // MARK: - NSWindowDelegate

    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 关闭设置窗 ≠ 退出应用：仅隐藏，保留单实例。
        hideSettings()
        return false
    }

    // MARK: - Actions

    @objc private func applyClicked(_ sender: Any?) {
        stopShortcutRecording(restoreLabel: true)
        let next = collectDraftFromControls()
        draft = next
        let result = onApply?(next) ?? .success
        switch result {
        case .success:
            showApplySuccessBanner()
        case .failure(let title, let message):
            hideApplySuccessBanner()
            presentAlert(title: title, message: message)
        }
    }

    @objc private func revertClicked(_ sender: Any?) {
        stopShortcutRecording(restoreLabel: true)
        // 「恢复默认」= 产品出厂默认，不是回到上次已提交值。
        if let defaultsDraft = onRevert?() {
            reload(draft: defaultsDraft)
            let result = onApply?(defaultsDraft) ?? .success
            switch result {
            case .success:
                showApplySuccessBanner(key: .defaultsRestored)
            case .failure(let title, let message):
                hideApplySuccessBanner()
                presentAlert(title: title, message: message)
            }
        }
    }

    @objc private func closeClicked(_ sender: Any?) {
        hideSettings()
    }

    @objc private func controlChanged(_ sender: Any?) {
        // 取消勾选「启用全局快捷键」时必须结束录制态，避免仍显示「请按下组合键…」。
        if shortcutEnableCheckbox.state != .on, isRecordingShortcut {
            stopShortcutRecording(restoreLabel: true)
        }
        draft = collectDraftFromControls()
        // Refresh only availability: reloading controls here would discard unrelated edits.
        fourFingerOutwardHideCheckbox.isEnabled = draft.fourFingerActivationEnabled
        hotCornerPopup.isEnabled = hotCornerEnableCheckbox.state == .on
        shortcutRecordButton.isEnabled = shortcutEnableCheckbox.state == .on
        shortcutPresetPopup.isEnabled = shortcutEnableCheckbox.state == .on
        applyValidationControlAvailability()
    }

    @objc private func shortcutPresetChanged(_ sender: Any?) {
        let tag = shortcutPresetPopup.selectedItem?.tag ?? ShortcutPreset.custom.rawValue
        let preset = ShortcutPreset(rawValue: tag) ?? .custom
        applyShortcutPreset(preset)
    }

    /// 应用预设：写入 `draft.shortcut` 并启用开关；「自定义…」保留当前值。
    /// 供菜单 action 与测试共用。
    public func applyShortcutPreset(_ preset: ShortcutPreset) {
        stopShortcutRecording(restoreLabel: true)
        selectShortcutPresetInPopup(preset)
        if let spec = preset.spec {
            draft.shortcut = spec
            draft.globalShortcutEnabled = true
            shortcutEnableCheckbox.state = .on
        }
        // 「自定义…」保留当前 draft.shortcut，不覆盖。
        renderShortcutPresentation()
        draft = collectDraftFromControls()
    }

    /// 模拟录制成功（测试钩子；生产路径走本地 keyDown monitor）。
    public func applyRecordedShortcut(_ spec: ShortcutSpec) {
        draft.shortcut = spec
        draft.globalShortcutEnabled = true
        shortcutEnableCheckbox.state = .on
        stopShortcutRecording(restoreLabel: false)
        selectShortcutPresetInPopup(.custom)
        renderShortcutPresentation()
        draft = collectDraftFromControls()
    }

    @objc private func shortcutRecordClicked(_ sender: Any?) {
        if isRecordingShortcut {
            stopShortcutRecording(restoreLabel: true)
            return
        }
        // 未启用全局热键时不允许进入录制态。
        guard shortcutEnableCheckbox.state == .on else { return }
        startShortcutRecording()
    }

    // MARK: - Private UI

    private static func makeWindow(strings: LocalizedStrings) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = strings.settingsText(.settingsWindowTitle)
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func buildContent(in window: NSWindow) {
        let root = NSView(frame: window.contentView?.bounds ?? .zero)
        root.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(stack)

        showStatusItemCheckbox = makeCheckbox(
            key: .showStatusItem,
            accessibility: .showStatusItemAccessibility
        )
        stack.addArrangedSubview(showStatusItemCheckbox)

        // Shortcut
        shortcutEnableCheckbox = makeCheckbox(
            key: .globalShortcutEnable,
            accessibility: .globalShortcutEnable
        )
        shortcutPresetPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        shortcutPresetPopup.translatesAutoresizingMaskIntoConstraints = false
        registerAccessibility(shortcutPresetPopup, key: .shortcutPresetAccessibility)
        populateShortcutPresetPopup()
        shortcutPresetPopup.target = self
        shortcutPresetPopup.action = #selector(shortcutPresetChanged(_:))
        let presetRow = NSStackView()
        presetRow.orientation = .horizontal
        presetRow.spacing = 8
        presetRow.translatesAutoresizingMaskIntoConstraints = false
        let presetCaption = makeCaption(key: .shortcutPresetLabel)
        presetRow.addArrangedSubview(presetCaption)
        presetRow.addArrangedSubview(shortcutPresetPopup)
        shortcutRecordButton = makeButton(
            key: .shortcutRecord,
            accessibility: .shortcutRecordAccessibility,
            action: #selector(shortcutRecordClicked(_:))
        )
        shortcutDescriptionLabel = makeStatusLabel(accessibility: .shortcutDescriptionAccessibility)
        stack.addArrangedSubview(labeledSection(
            .globalShortcut,
            views: [shortcutEnableCheckbox, presetRow, shortcutRecordButton, shortcutDescriptionLabel]
        ))

        // Hot Corner
        hotCornerEnableCheckbox = makeCheckbox(
            key: .hotCornerEnable,
            accessibility: .hotCornerEnable
        )
        hotCornerPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        hotCornerPopup.translatesAutoresizingMaskIntoConstraints = false
        registerAccessibility(hotCornerPopup, key: .hotCornerAccessibility)
        populateCornerPopup()
        hotCornerPopup.target = self
        hotCornerPopup.action = #selector(controlChanged(_:))
        stack.addArrangedSubview(labeledSection(
            .hotCorner,
            views: [hotCornerEnableCheckbox, hotCornerPopup]
        ))

        // Four-finger
        fourFingerEnableCheckbox = makeCheckbox(
            key: .fourFingerEnable,
            accessibility: .fourFingerEnable
        )
        fourFingerOutwardHideCheckbox = makeCheckbox(
            key: .fourFingerOutwardHideEnable,
            accessibility: .fourFingerOutwardHideEnable
        )
        fourFingerOutwardHideCheckbox.identifier = NSUserInterfaceItemIdentifier("activation.fourFingerOutwardHide")
        fourFingerOutwardHideCheckbox.setAccessibilityIdentifier("activation.fourFingerOutwardHide")
        let outwardHideRow = NSView()
        outwardHideRow.translatesAutoresizingMaskIntoConstraints = false
        outwardHideRow.addSubview(fourFingerOutwardHideCheckbox)
        NSLayoutConstraint.activate([
            fourFingerOutwardHideCheckbox.leadingAnchor.constraint(equalTo: outwardHideRow.leadingAnchor, constant: 18),
            fourFingerOutwardHideCheckbox.trailingAnchor.constraint(equalTo: outwardHideRow.trailingAnchor),
            fourFingerOutwardHideCheckbox.topAnchor.constraint(equalTo: outwardHideRow.topAnchor),
            fourFingerOutwardHideCheckbox.bottomAnchor.constraint(equalTo: outwardHideRow.bottomAnchor),
        ])
        fourFingerStatusLabel = makeStatusLabel(accessibility: .fourFingerStatusAccessibility)
        stack.addArrangedSubview(labeledSection(
            .fourFinger,
            views: [fourFingerEnableCheckbox, outwardHideRow, fourFingerStatusLabel]
        ))

        // Launch at Login
        launchAtLoginCheckbox = makeCheckbox(
            key: .launchAtLoginEnable,
            accessibility: .launchAtLoginAccessibility
        )
        launchAtLoginStatusLabel = makeStatusLabel(accessibility: .launchAtLoginStatusAccessibility)
        stack.addArrangedSubview(labeledSection(
            .launchAtLogin,
            views: [launchAtLoginCheckbox, launchAtLoginStatusLabel]
        ))

        // Buttons
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        let applyButton = makeButton(
            key: .apply,
            accessibility: .applyAccessibility,
            action: #selector(applyClicked(_:))
        )
        applyButton.keyEquivalent = "\r"
        let revertButton = makeButton(
            key: .revert,
            accessibility: .revertAccessibility,
            action: #selector(revertClicked(_:))
        )
        let closeButton = makeButton(
            key: .close,
            accessibility: .closeAccessibility,
            action: #selector(closeClicked(_:))
        )
        buttonRow.addArrangedSubview(applyButton)
        buttonRow.addArrangedSubview(revertButton)
        buttonRow.addArrangedSubview(closeButton)
        stack.addArrangedSubview(buttonRow)

        applySuccessLabel = makeStatusLabel(accessibility: .applyResultAccessibility)
        applySuccessLabel.textColor = .systemGreen
        applySuccessLabel.isHidden = true
        applySuccessLabel.stringValue = ""
        stack.addArrangedSubview(applySuccessLabel)

        let tabs = NSTabView()
        tabs.delegate = self
        sectionTabs = tabs
        tabs.identifier = NSUserInterfaceItemIdentifier("launchcopy.settings.sections")
        let activation = NSTabViewItem(identifier: "activation")
        activation.label = languageStrings.settingsText(.activationTabTitle)
        activation.view = root
        let appearance = NSTabViewItem(identifier: "appearance")
        appearance.label = languageStrings.settingsText(.appearanceTabTitle)
        appearance.view = appearanceView
        tabs.addTabViewItem(activation)
        tabs.addTabViewItem(appearance)
        let management = NSTabViewItem(identifier: "management")
        management.label = languageStrings.settingsText(.managementTabTitle)
        management.view = appManagementView
        tabs.addTabViewItem(management)
        let sources = NSTabViewItem(identifier: "sources")
        sources.label = languageStrings.settingsText(.sourcesTabTitle)
        sources.view = appSourcesView
        tabs.addTabViewItem(sources)
        let language = NSTabViewItem(identifier: "language")
        language.label = languageStrings.text(.languageTitle)
        language.view = languageView
        tabs.addTabViewItem(language)
        let library = NSTabViewItem(identifier: "library")
        library.label = languageStrings.libraryText(.title)
        library.view = appLibrarySettingsView
        tabs.addTabViewItem(library)
        window.contentView = tabs
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -20),
            hotCornerPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            shortcutPresetPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
        ])
    }

    private func showApplySuccessBanner(key: ActivationTextKey = .applySuccess) {
        applySuccessHideWorkItem?.cancel()
        applySuccessKey = key
        applySuccessLabel.stringValue = languageStrings.activationText(key)
        applySuccessLabel.setAccessibilityValue(applySuccessLabel.stringValue)
        applySuccessLabel.isHidden = false
        let work = DispatchWorkItem { [weak self] in
            self?.hideApplySuccessBanner()
        }
        applySuccessHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func hideApplySuccessBanner() {
        applySuccessHideWorkItem?.cancel()
        applySuccessHideWorkItem = nil
        applySuccessKey = nil
        applySuccessLabel?.setAccessibilityValue("")
        applySuccessLabel?.isHidden = true
        applySuccessLabel?.stringValue = ""
    }

    /// Bounded real-gesture entries cannot offer unrelated global activation controls.
    var fourFingerValidationOnly = false {
        didSet { if isWindowLoaded { syncControlsFromDraft() } }
    }

    private func applyValidationControlAvailability() {
        guard fourFingerValidationOnly else { return }
        for control in [showStatusItemCheckbox, shortcutEnableCheckbox, shortcutRecordButton,
                        shortcutPresetPopup, hotCornerEnableCheckbox, hotCornerPopup,
                        launchAtLoginCheckbox] as [NSControl?] {
            control?.isEnabled = false
        }
    }

    private func syncControlsFromDraft() {
        showStatusItemCheckbox.state = draft.showStatusItem ? .on : .off
        shortcutEnableCheckbox.state = draft.globalShortcutEnabled ? .on : .off
        shortcutRecordButton.isEnabled = draft.globalShortcutEnabled
        shortcutPresetPopup.isEnabled = draft.globalShortcutEnabled
        selectShortcutPresetInPopup(ShortcutPreset.matching(draft.shortcut))
        renderShortcutPresentation()
        hotCornerEnableCheckbox.state = draft.hotCornerEnabled ? .on : .off
        hotCornerPopup.isEnabled = draft.hotCornerEnabled
        selectCornerInPopup(draft.selectedCorner)
        fourFingerEnableCheckbox.state = draft.fourFingerActivationEnabled ? .on : .off
        fourFingerOutwardHideCheckbox.state = draft.fourFingerOutwardHideEnabled ? .on : .off
        fourFingerOutwardHideCheckbox.isEnabled = draft.fourFingerActivationEnabled
        launchAtLoginCheckbox.state = draft.launchAtLoginEnabled ? .on : .off
        applyValidationControlAvailability()
    }

    private func installStatusProviders(fourFinger: (() -> String)?, login: (() -> String)?) {
        fourFingerReadinessProvider = fourFinger ?? { [weak self] in
            self?.languageStrings.activationStatusText(.activationGestureNotReady)
                ?? ActivationStatusTextKey.activationGestureNotReady.englishFallback
        }
        launchAtLoginStatusProvider = login ?? { [weak self] in
            self?.languageStrings.activationStatusText(.activationLoginDisabled)
                ?? ActivationStatusTextKey.activationLoginDisabled.englishFallback
        }
    }

    private func refreshSideStatusLabels() {
        fourFingerStatusLabel.stringValue = fourFingerReadinessProvider()
        launchAtLoginStatusLabel.stringValue = launchAtLoginStatusProvider()
        fourFingerStatusLabel.setAccessibilityValue(fourFingerStatusLabel.stringValue)
        launchAtLoginStatusLabel.setAccessibilityValue(launchAtLoginStatusLabel.stringValue)
        renderShortcutPresentation()
    }

    private func relabelActivationControls() {
        for (button, key) in activationButtonTitles {
            button.title = languageStrings.activationText(key)
        }
        for (label, key) in activationLabelTitles {
            label.stringValue = languageStrings.activationText(key)
        }
        for (view, key) in activationAccessibility {
            view.setAccessibilityLabel(languageStrings.activationText(key))
        }
        let outwardHelp = languageStrings.activationText(.fourFingerOutwardHideHelp)
        fourFingerOutwardHideCheckbox.toolTip = outwardHelp
        fourFingerOutwardHideCheckbox.setAccessibilityHelp(outwardHelp)
        // Mutate retained menu items only: selection, represented objects and tags survive.
        for item in shortcutPresetPopup.itemArray {
            if let preset = ShortcutPreset(rawValue: item.tag) {
                item.title = preset.menuTitle(strings: languageStrings)
                item.setAccessibilityLabel(item.title)
            }
        }
        for item in hotCornerPopup.itemArray {
            item.title = Self.corner(forTag: item.tag).map {
                ActivationSettingsUIStrings.cornerTitle($0, strings: languageStrings)
            } ?? languageStrings.activationText(.cornerNone)
            item.setAccessibilityLabel(item.title)
        }
        if let key = applySuccessKey, !applySuccessLabel.isHidden {
            applySuccessLabel.stringValue = languageStrings.activationText(key)
            applySuccessLabel.setAccessibilityValue(applySuccessLabel.stringValue)
        }
        // Main supplies current-snapshot status renderers; no application transaction occurs.
        refreshSideStatusLabels()
    }

    private func renderShortcutPresentation() {
        shortcutRecordButton.title = languageStrings.activationText(
            isRecordingShortcut ? .shortcutRecordingPrompt : .shortcutRecord
        )
        shortcutRecordButton.setAccessibilityLabel(languageStrings.activationText(
            isRecordingShortcut ? .shortcutRecordingPrompt : .shortcutRecordAccessibility
        ))
        let help = languageStrings.activationText(.shortcutRecordingHelp)
        shortcutRecordButton.toolTip = help
        shortcutRecordButton.setAccessibilityHelp(help)
        shortcutDescriptionLabel.toolTip = help
        shortcutDescriptionLabel.setAccessibilityHelp(help)
        if isRecordingShortcut {
            shortcutDescriptionLabel.stringValue = languageStrings.activationText(
                shortcutRecordingNeedsModifier ? .shortcutNeedsModifier : .shortcutRecordingPrompt
            )
        } else {
            shortcutDescriptionLabel.stringValue = ActivationSettingsUIStrings.shortcutDescription(
                draft.shortcut, strings: languageStrings
            )
        }
        shortcutDescriptionLabel.setAccessibilityValue(shortcutDescriptionLabel.stringValue)
    }

    private func populateShortcutPresetPopup() {
        shortcutPresetPopup.removeAllItems()
        for preset in ShortcutPreset.menuOrder {
            shortcutPresetPopup.addItem(withTitle: preset.menuTitle(strings: languageStrings))
            shortcutPresetPopup.lastItem?.tag = preset.rawValue
        }
    }

    private func selectShortcutPresetInPopup(_ preset: ShortcutPreset) {
        let index = shortcutPresetPopup.indexOfItem(withTag: preset.rawValue)
        if index >= 0 {
            shortcutPresetPopup.selectItem(at: index)
        } else {
            shortcutPresetPopup.selectItem(at: 0)
        }
    }

    // MARK: - Shortcut recording (local monitor only)

    public func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        if tabViewItem?.identifier as? String != "activation" {
            stopShortcutRecording(restoreLabel: true)
        }
    }

    private func startShortcutRecording() {
        guard !isRecordingShortcut else { return }
        isRecordingShortcut = true
        shortcutRecordingNeedsModifier = false
        renderShortcutPresentation()
        onLanguageReadinessChange?()
        shortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecordingShortcut, event.window === self.window else { return event }
            self.handleShortcutRecordingKeyDown(event)
            return nil
        }
    }

    private func stopShortcutRecording(restoreLabel: Bool) {
        if let shortcutRecordingMonitor {
            NSEvent.removeMonitor(shortcutRecordingMonitor)
            self.shortcutRecordingMonitor = nil
        }
        let wasRecording = isRecordingShortcut
        isRecordingShortcut = false
        shortcutRecordingNeedsModifier = false
        if shortcutRecordButton != nil {
            if restoreLabel || !wasRecording { renderShortcutPresentation() }
            else {
                shortcutRecordButton.title = languageStrings.activationText(.shortcutRecord)
                shortcutRecordButton.setAccessibilityLabel(languageStrings.activationText(.shortcutRecordAccessibility))
            }
        }
        if wasRecording { onLanguageReadinessChange?() }
    }

    func handleShortcutRecordingKeyDown(_ event: NSEvent) {
        guard isRecordingShortcut else { return }
        switch ShortcutRecording.interpretKeyDown(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags
        ) {
        case .cancel:
            stopShortcutRecording(restoreLabel: true)
        case .rejectBareKey:
            shortcutRecordingNeedsModifier = true
            renderShortcutPresentation()
        case .accept(let spec):
            applyRecordedShortcut(spec)
        }
    }

    private func populateCornerPopup() {
        hotCornerPopup.removeAllItems()
        hotCornerPopup.addItem(withTitle: languageStrings.activationText(.cornerNone))
        hotCornerPopup.lastItem?.tag = -1
        for corner in HotCorner.allCases {
            hotCornerPopup.addItem(withTitle: ActivationSettingsUIStrings.cornerTitle(corner, strings: languageStrings))
            hotCornerPopup.lastItem?.tag = Self.tag(for: corner)
        }
    }

    private func selectCornerInPopup(_ corner: HotCorner?) {
        let tag = corner.map(Self.tag(for:)) ?? -1
        let index = hotCornerPopup.indexOfItem(withTag: tag)
        if index >= 0 {
            hotCornerPopup.selectItem(at: index)
        } else {
            hotCornerPopup.selectItem(at: 0)
        }
    }

    private func selectedCornerFromPopup() -> HotCorner? {
        let tag = hotCornerPopup.selectedItem?.tag ?? -1
        return Self.corner(forTag: tag)
    }

    private static func tag(for corner: HotCorner) -> Int {
        switch corner {
        case .topLeft: return 0
        case .topRight: return 1
        case .bottomLeft: return 2
        case .bottomRight: return 3
        }
    }

    private static func corner(forTag tag: Int) -> HotCorner? {
        switch tag {
        case 0: return .topLeft
        case 1: return .topRight
        case 2: return .bottomLeft
        case 3: return .bottomRight
        default: return nil
        }
    }

    private func registerAccessibility(_ view: NSView, key: ActivationTextKey) {
        activationAccessibility.append((view, key))
        view.setAccessibilityLabel(languageStrings.activationText(key))
    }

    private func makeCheckbox(key: ActivationTextKey, accessibility: ActivationTextKey) -> NSButton {
        let button = NSButton(checkboxWithTitle: languageStrings.activationText(key), target: self,
                              action: #selector(controlChanged(_:)))
        button.translatesAutoresizingMaskIntoConstraints = false
        activationButtonTitles.append((button, key))
        registerAccessibility(button, key: accessibility)
        return button
    }

    private func makeButton(key: ActivationTextKey, accessibility: ActivationTextKey, action: Selector) -> NSButton {
        let button = NSButton(title: languageStrings.activationText(key), target: self, action: action)
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        activationButtonTitles.append((button, key))
        registerAccessibility(button, key: accessibility)
        return button
    }

    private func makeStatusLabel(accessibility: ActivationTextKey) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabelColor
        registerAccessibility(label, key: accessibility)
        return label
    }

    private func makeCaption(key: ActivationTextKey) -> NSTextField {
        let label = NSTextField(labelWithString: languageStrings.activationText(key))
        activationLabelTitles.append((label, key))
        registerAccessibility(label, key: key)
        return label
    }

    private func sectionStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func labeledSection(_ key: ActivationTextKey, views: [NSView]) -> NSStackView {
        let stack = sectionStack()
        let header = makeCaption(key: key)
        header.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        stack.addArrangedSubview(header)
        for view in views {
            stack.addArrangedSubview(view)
        }
        return stack
    }

    /// Constructs the same action-time alert used in production, without presenting it.
    func makeAlert(title: String, message: String) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: languageStrings.activationText(.close))
        return alert
    }

    func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: languageStrings.noticeText(.okay))
        let release = acquireModalOwnership?()
        let gate = ApplicationSheetCompletionGate()
        alertPresenter(alert, window) { [weak self] in
            guard gate.claim() else { return }
            release?()
            self?.onLanguageReadinessChange?()
        }

    }
}
