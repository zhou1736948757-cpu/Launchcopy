import AppKit
import LauncherLocalization

/// Relabel-only updates preserve the independent preference draft and controls.
@MainActor
public final class LanguageSettingsView: NSView {
    public private(set) var draft = LanguagePreferences.default
    public private(set) var strings: LocalizedStrings
    public var onApply: ((LanguagePreferences) -> LanguagePreferencesSaveResult)?
    public var presentationStateProvider: (() -> LanguagePresentationState)?
    let languagePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let headingLabel = NSTextField(labelWithString: "")
    let helpLabel = NSTextField(wrappingLabelWithString: "")
    let statusLabel = NSTextField(wrappingLabelWithString: "")
    let applyButton = NSButton(title: "", target: nil, action: nil)
    let defaultsButton = NSButton(title: "", target: nil, action: nil)
    private let choices: [InterfaceLanguagePreference] = [.system, .simplifiedChinese, .english, .japanese]
    private enum Feedback {
        case none, defaultsDraft, saved, corrupt, future(Int), futureUnknown, oversized, unavailable, failed
    }
    private var feedback = Feedback.none
    private var isReadOnly = false

    public override convenience init(frame frameRect: NSRect) {
        self.init(frame: frameRect, strings: LocalizedStrings(language: .simplifiedChinese))
    }

    public init(frame frameRect: NSRect, strings: LocalizedStrings) {
        self.strings = strings
        super.init(frame: frameRect)
        languagePopup.identifier = NSUserInterfaceItemIdentifier("language.choice")
        languagePopup.target = self
        languagePopup.action = #selector(choiceChanged(_:))
        applyButton.identifier = NSUserInterfaceItemIdentifier("language.apply")
        applyButton.target = self
        applyButton.action = #selector(applyClicked(_:))
        defaultsButton.identifier = NSUserInterfaceItemIdentifier("language.defaults")
        defaultsButton.target = self
        defaultsButton.action = #selector(defaultsClicked(_:))
        statusLabel.identifier = NSUserInterfaceItemIdentifier("language.status")
        helpLabel.textColor = .secondaryLabelColor
        let buttons = NSStackView(views: [applyButton, defaultsButton])
        buttons.orientation = .horizontal
        buttons.spacing = 12
        let stack = NSStackView(views: [headingLabel, languagePopup, helpLabel, buttons, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -24),
            helpLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            languagePopup.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor)
        ])
        relabel(strings: strings)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public func reload(preferences: LanguagePreferences, loadResult: LanguagePreferencesLoadResult) {
        draft = preferences
        languagePopup.selectItem(at: choices.firstIndex(of: draft.language) ?? 0)
        isReadOnly = false
        switch loadResult {
        case .futureVersion(let version): feedback = .future(version); isReadOnly = true
        case .futureVersionUnrepresentable: feedback = .futureUnknown; isReadOnly = true
        case .oversized: feedback = .oversized; isReadOnly = true
        case .unavailable: feedback = .unavailable; isReadOnly = true
        case .corrupt: feedback = .corrupt
        case .missing, .loaded: feedback = .none
        }
        if !isReadOnly, case .loaded = loadResult, presentationStateProvider?() == .queued {
            feedback = .saved
        }
        syncEnabledState()
        renderFeedback()
    }

    public func relabel(strings: LocalizedStrings) {
        self.strings = strings
        headingLabel.stringValue = strings.text(.languageTitle)
        headingLabel.setAccessibilityLabel(strings.text(.languageTitle))
        helpLabel.stringValue = strings.text(.languageHelp)
        applyButton.title = strings.text(.apply)
        applyButton.setAccessibilityLabel(applyButton.title)
        defaultsButton.title = strings.text(.restoreDefaults)
        defaultsButton.setAccessibilityLabel(defaultsButton.title)
        languagePopup.setAccessibilityLabel(strings.text(.languageTitle))
        // Items are stable identities. Only labels change; selection never reloads.
        if languagePopup.numberOfItems == 0 {
            languagePopup.addItems(withTitles: [strings.text(.followSystem), "简体中文", "English", "日本語"])
        }
        for (index, preference) in choices.enumerated() {
            let title: String
            switch preference {
            case .system: title = strings.text(.followSystem)
            case .simplifiedChinese: title = "简体中文"
            case .english: title = "English"
            case .japanese: title = "日本語"
            }
            languagePopup.item(at: index)?.title = title
            languagePopup.item(at: index)?.tag = index
        }
        renderFeedback()
    }

    public func refreshPresentationStatus() {
        if case .saved = feedback { renderFeedback() }
    }

    @objc func choiceChanged(_ sender: Any?) {
        guard !isReadOnly, choices.indices.contains(languagePopup.indexOfSelectedItem) else { return }
        draft = LanguagePreferences(language: choices[languagePopup.indexOfSelectedItem])
        feedback = .none
        renderFeedback()
    }

    @objc func applyClicked(_ sender: Any?) {
        guard !isReadOnly else { return }
        choiceChanged(sender)
        guard let onApply else { feedback = .unavailable; renderFeedback(); return }
        switch onApply(draft) {
        case .saved: feedback = .saved
        case .futureVersion(let version): feedback = .future(version); isReadOnly = true
        case .futureVersionUnrepresentable: feedback = .futureUnknown; isReadOnly = true
        case .oversized: feedback = .oversized; isReadOnly = true
        case .unavailable: feedback = .unavailable
        case .encodingFailed: feedback = .failed
        }
        syncEnabledState()
        renderFeedback()
    }

    @objc func defaultsClicked(_ sender: Any?) {
        guard !isReadOnly else { return }
        draft = .default
        languagePopup.selectItem(at: 0)
        feedback = .defaultsDraft
        renderFeedback()
    }

    private func syncEnabledState() {
        languagePopup.isEnabled = !isReadOnly
        applyButton.isEnabled = !isReadOnly
        defaultsButton.isEnabled = !isReadOnly
    }

    private func renderFeedback() {
        let message: String
        switch feedback {
        case .none: message = ""
        case .defaultsDraft: message = strings.text(.languageDraftDefaults)
        case .saved:
            switch presentationStateProvider?() ?? .unavailable {
            case .applied: message = strings.text(.languageApplied)
            case .queued: message = strings.text(.languageQueued)
            case .unavailable: message = strings.text(.languageStoreUnavailable)
            }
        case .corrupt: message = strings.text(.languageCorrupt)
        case .future(let version): message = strings.languageFutureVersion(version)
        case .futureUnknown: message = strings.text(.languageFutureProtected)
        case .oversized, .unavailable: message = strings.text(.languageStoreUnavailable)
        case .failed: message = strings.text(.languageSaveFailed)
        }
        statusLabel.stringValue = message
        statusLabel.setAccessibilityLabel(message)
        statusLabel.isHidden = message.isEmpty
    }
}
