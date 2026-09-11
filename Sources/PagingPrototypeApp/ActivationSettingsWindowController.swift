//
//  ActivationSettingsWindowController.swift
//  PagingPrototypeApp
//
//  Phase 1H T-1H-B：原生 AppKit 激活设置窗（单实例）。
//  - 草稿 vs 已提交：打开时载入已提交；应用 = 校验 → 注入 apply；失败中文 NSAlert 并保留草稿。
//  - 关闭不退出驻留应用；无障碍标签齐全。
//  - D6：中文产品文案；不记录指针坐标 / 屏幕 UUID / 按键历史。
//

import AppKit
import Foundation

// MARK: - Chinese product strings（Settings）

/// Settings / 状态菜单中文文案边界（localization-ready；本阶段直接中文常量）。
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
public final class ActivationSettingsWindowController: NSWindowController, NSWindowDelegate {

    private static weak var sharedInstance: ActivationSettingsWindowController?

    /// 当前草稿（控件双向绑定到此值的快照；Apply/Revert 经回调）。
    public private(set) var draft: ActivationPreferencesDraft

    /// 四指就绪旁路文案提供者（注入；默认「未就绪」）。
    public var fourFingerReadinessProvider: () -> String

    /// Launch at Login 状态文案提供者。
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
    private var fourFingerStatusLabel: NSTextField!
    private var launchAtLoginCheckbox: NSButton!
    private var launchAtLoginStatusLabel: NSTextField!
    private var applySuccessLabel: NSTextField!
    private var applySuccessHideWorkItem: DispatchWorkItem?

    /// 本地 keyDown 录制 monitor（仅 Settings 窗；非全局 / 非 CGEvent tap）。
    private var shortcutRecordingMonitor: Any?
    private var isRecordingShortcut = false

    public static var shared: ActivationSettingsWindowController? { sharedInstance }

    /// 单实例工厂：已存在则复用并刷新草稿；否则创建。
    @discardableResult
    public static func sharedOrCreate(
        draft: ActivationPreferencesDraft,
        fourFingerReadinessProvider: @escaping () -> String = {
            ActivationSettingsUIStrings.fourFingerNotReady
        },
        launchAtLoginStatusProvider: @escaping () -> String = {
            ActivationSettingsUIStrings.launchAtLoginStatusText(.disabled)
        },
        onApply: ((ActivationPreferencesDraft) -> ActivationSettingsApplyUIResult)? = nil,
        onRevert: (() -> ActivationPreferencesDraft)? = nil
    ) -> ActivationSettingsWindowController {
        if let existing = sharedInstance {
            existing.fourFingerReadinessProvider = fourFingerReadinessProvider
            existing.launchAtLoginStatusProvider = launchAtLoginStatusProvider
            if let onApply { existing.onApply = onApply }
            if let onRevert { existing.onRevert = onRevert }
            existing.reload(draft: draft)
            return existing
        }
        let created = ActivationSettingsWindowController(
            draft: draft,
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
        fourFingerReadinessProvider: @escaping () -> String = {
            ActivationSettingsUIStrings.fourFingerNotReady
        },
        launchAtLoginStatusProvider: @escaping () -> String = {
            ActivationSettingsUIStrings.launchAtLoginStatusText(.disabled)
        },
        onApply: ((ActivationPreferencesDraft) -> ActivationSettingsApplyUIResult)? = nil,
        onRevert: (() -> ActivationPreferencesDraft)? = nil
    ) {
        self.draft = draft
        self.fourFingerReadinessProvider = fourFingerReadinessProvider
        self.launchAtLoginStatusProvider = launchAtLoginStatusProvider
        self.onApply = onApply
        self.onRevert = onRevert
        let window = Self.makeWindow()
        super.init(window: window)
        window.delegate = self
        buildContent(in: window)
        reload(draft: draft)
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
        stopShortcutRecording(restoreLabel: true)
        isPresented = false
        window?.orderOut(nil)
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
                showApplySuccessBanner(message: "已恢复默认设置")
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
        hotCornerPopup.isEnabled = hotCornerEnableCheckbox.state == .on
        shortcutRecordButton.isEnabled = shortcutEnableCheckbox.state == .on
        shortcutPresetPopup.isEnabled = shortcutEnableCheckbox.state == .on
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
        shortcutDescriptionLabel.stringValue = ActivationSettingsUIStrings.shortcutDescription(draft.shortcut)
        draft = collectDraftFromControls()
    }

    /// 模拟录制成功（测试钩子；生产路径走本地 keyDown monitor）。
    public func applyRecordedShortcut(_ spec: ShortcutSpec) {
        draft.shortcut = spec
        draft.globalShortcutEnabled = true
        shortcutEnableCheckbox.state = .on
        stopShortcutRecording(restoreLabel: false)
        selectShortcutPresetInPopup(.custom)
        shortcutDescriptionLabel.stringValue = ActivationSettingsUIStrings.shortcutDescription(spec)
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

    private static func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = ActivationSettingsUIStrings.windowTitle
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
            title: ActivationSettingsUIStrings.showStatusItem,
            accessibility: "状态菜单显示开关"
        )
        stack.addArrangedSubview(showStatusItemCheckbox)

        // Shortcut
        shortcutEnableCheckbox = makeCheckbox(
            title: ActivationSettingsUIStrings.globalShortcutEnable,
            accessibility: "启用全局快捷键"
        )
        shortcutPresetPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        shortcutPresetPopup.translatesAutoresizingMaskIntoConstraints = false
        shortcutPresetPopup.setAccessibilityLabel("全局快捷键预设")
        populateShortcutPresetPopup()
        shortcutPresetPopup.target = self
        shortcutPresetPopup.action = #selector(shortcutPresetChanged(_:))
        let presetRow = NSStackView()
        presetRow.orientation = .horizontal
        presetRow.spacing = 8
        presetRow.translatesAutoresizingMaskIntoConstraints = false
        let presetCaption = NSTextField(labelWithString: ActivationSettingsUIStrings.shortcutPresetLabel)
        presetCaption.setAccessibilityLabel(ActivationSettingsUIStrings.shortcutPresetLabel)
        presetRow.addArrangedSubview(presetCaption)
        presetRow.addArrangedSubview(shortcutPresetPopup)
        shortcutRecordButton = makeButton(
            title: ActivationSettingsUIStrings.shortcutRecord,
            accessibility: "录制全局热键",
            action: #selector(shortcutRecordClicked(_:))
        )
        shortcutDescriptionLabel = makeStatusLabel(accessibility: "当前全局快捷键描述")
        stack.addArrangedSubview(labeledSection(
            ActivationSettingsUIStrings.globalShortcut,
            views: [shortcutEnableCheckbox, presetRow, shortcutRecordButton, shortcutDescriptionLabel]
        ))

        // Hot Corner
        hotCornerEnableCheckbox = makeCheckbox(
            title: ActivationSettingsUIStrings.hotCornerEnable,
            accessibility: "启用 Hot Corner"
        )
        hotCornerPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        hotCornerPopup.translatesAutoresizingMaskIntoConstraints = false
        hotCornerPopup.setAccessibilityLabel("Hot Corner 角落选择")
        populateCornerPopup()
        hotCornerPopup.target = self
        hotCornerPopup.action = #selector(controlChanged(_:))
        stack.addArrangedSubview(labeledSection(
            ActivationSettingsUIStrings.hotCorner,
            views: [hotCornerEnableCheckbox, hotCornerPopup]
        ))

        // Four-finger
        fourFingerEnableCheckbox = makeCheckbox(
            title: ActivationSettingsUIStrings.fourFingerEnable,
            accessibility: "启用四指捏合"
        )
        fourFingerStatusLabel = makeStatusLabel(accessibility: "四指捏合就绪状态")
        stack.addArrangedSubview(labeledSection(
            ActivationSettingsUIStrings.fourFinger,
            views: [fourFingerEnableCheckbox, fourFingerStatusLabel]
        ))

        // Launch at Login
        launchAtLoginCheckbox = makeCheckbox(
            title: ActivationSettingsUIStrings.launchAtLoginEnable,
            accessibility: "登录时打开开关"
        )
        launchAtLoginStatusLabel = makeStatusLabel(accessibility: "登录时打开当前状态")
        stack.addArrangedSubview(labeledSection(
            ActivationSettingsUIStrings.launchAtLogin,
            views: [launchAtLoginCheckbox, launchAtLoginStatusLabel]
        ))

        // Buttons
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        let applyButton = makeButton(
            title: ActivationSettingsUIStrings.apply,
            accessibility: "应用设置",
            action: #selector(applyClicked(_:))
        )
        applyButton.keyEquivalent = "\r"
        let revertButton = makeButton(
            title: ActivationSettingsUIStrings.revert,
            accessibility: "还原设置",
            action: #selector(revertClicked(_:))
        )
        let closeButton = makeButton(
            title: ActivationSettingsUIStrings.close,
            accessibility: "关闭设置窗口",
            action: #selector(closeClicked(_:))
        )
        buttonRow.addArrangedSubview(applyButton)
        buttonRow.addArrangedSubview(revertButton)
        buttonRow.addArrangedSubview(closeButton)
        stack.addArrangedSubview(buttonRow)

        applySuccessLabel = makeStatusLabel(accessibility: "应用结果提示")
        applySuccessLabel.textColor = .systemGreen
        applySuccessLabel.isHidden = true
        applySuccessLabel.stringValue = ""
        stack.addArrangedSubview(applySuccessLabel)

        window.contentView = root
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: root.bottomAnchor, constant: -20),
            hotCornerPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            shortcutPresetPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
        ])
    }

    private func showApplySuccessBanner(message: String = ActivationSettingsUIStrings.applySuccess) {
        applySuccessHideWorkItem?.cancel()
        applySuccessLabel.stringValue = message
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
        applySuccessLabel?.isHidden = true
        applySuccessLabel?.stringValue = ""
    }

    private func syncControlsFromDraft() {
        showStatusItemCheckbox.state = draft.showStatusItem ? .on : .off
        shortcutEnableCheckbox.state = draft.globalShortcutEnabled ? .on : .off
        shortcutRecordButton.isEnabled = draft.globalShortcutEnabled
        shortcutPresetPopup.isEnabled = draft.globalShortcutEnabled
        selectShortcutPresetInPopup(ShortcutPreset.matching(draft.shortcut))
        if !isRecordingShortcut {
            shortcutDescriptionLabel.stringValue = ActivationSettingsUIStrings.shortcutDescription(draft.shortcut)
            shortcutRecordButton.title = ActivationSettingsUIStrings.shortcutRecord
        }
        hotCornerEnableCheckbox.state = draft.hotCornerEnabled ? .on : .off
        hotCornerPopup.isEnabled = draft.hotCornerEnabled
        selectCornerInPopup(draft.selectedCorner)
        fourFingerEnableCheckbox.state = draft.fourFingerActivationEnabled ? .on : .off
        launchAtLoginCheckbox.state = draft.launchAtLoginEnabled ? .on : .off
    }

    private func refreshSideStatusLabels() {
        fourFingerStatusLabel.stringValue = fourFingerReadinessProvider()
        launchAtLoginStatusLabel.stringValue = launchAtLoginStatusProvider()
        if !isRecordingShortcut {
            shortcutDescriptionLabel.stringValue = ActivationSettingsUIStrings.shortcutDescription(draft.shortcut)
        }
    }

    private func populateShortcutPresetPopup() {
        shortcutPresetPopup.removeAllItems()
        for preset in ShortcutPreset.menuOrder {
            shortcutPresetPopup.addItem(withTitle: preset.menuTitle)
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

    private func startShortcutRecording() {
        guard !isRecordingShortcut else { return }
        isRecordingShortcut = true
        shortcutRecordButton.title = ActivationSettingsUIStrings.shortcutRecordingPrompt
        shortcutDescriptionLabel.stringValue = ActivationSettingsUIStrings.shortcutRecordingPrompt
        shortcutRecordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleShortcutRecordingKeyDown(event)
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
        shortcutRecordButton?.title = ActivationSettingsUIStrings.shortcutRecord
        if restoreLabel, wasRecording, shortcutDescriptionLabel != nil {
            shortcutDescriptionLabel.stringValue = ActivationSettingsUIStrings.shortcutDescription(draft.shortcut)
        }
    }

    private func handleShortcutRecordingKeyDown(_ event: NSEvent) {
        switch ShortcutRecording.interpretKeyDown(
            keyCode: event.keyCode,
            modifierFlags: event.modifierFlags
        ) {
        case .cancel:
            stopShortcutRecording(restoreLabel: true)
        case .rejectBareKey:
            shortcutDescriptionLabel.stringValue = ActivationSettingsUIStrings.shortcutNeedsModifier
        case .accept(let spec):
            applyRecordedShortcut(spec)
        }
    }

    private func populateCornerPopup() {
        hotCornerPopup.removeAllItems()
        hotCornerPopup.addItem(withTitle: ActivationSettingsUIStrings.cornerNone)
        hotCornerPopup.lastItem?.tag = -1
        for corner in HotCorner.allCases {
            hotCornerPopup.addItem(withTitle: ActivationSettingsUIStrings.cornerTitle(corner))
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

    private func makeCheckbox(title: String, accessibility: String) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: self, action: #selector(controlChanged(_:)))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setAccessibilityLabel(accessibility)
        return button
    }

    private func makeButton(title: String, accessibility: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setAccessibilityLabel(accessibility)
        return button
    }

    private func makeStatusLabel(accessibility: String) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabelColor
        label.setAccessibilityLabel(accessibility)
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

    private func labeledSection(_ title: String, views: [NSView]) -> NSStackView {
        let stack = sectionStack()
        let header = NSTextField(labelWithString: title)
        header.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        header.setAccessibilityLabel(title)
        stack.addArrangedSubview(header)
        for view in views {
            stack.addArrangedSubview(view)
        }
        return stack
    }

    private func presentAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: ActivationSettingsUIStrings.close)
        if let window {
            alert.beginSheetModal(for: window, completionHandler: { _ in })
        } else {
            alert.runModal()
        }
    }
}
