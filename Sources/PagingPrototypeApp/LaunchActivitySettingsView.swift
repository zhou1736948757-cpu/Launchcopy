import AppKit
import LauncherLocalization

/// Presentation only. Main owns admission, committed state, confirmations and storage.
@MainActor
final class LaunchActivitySettingsView: NSView {
    struct State: Equatable {
        var enabled: Bool
        /// Owner permission to change the checkbox, including an immediate privacy disable.
        var canEnable: Bool
        var isBusy: Bool
        var canClear: Bool
        var status: LaunchActivityTextKey
        var canRetry: Bool
        var canRecover: Bool
    }

    var onSetEnabled: ((Bool) -> Void)?
    var onClear: (() -> Void)?
    var onRetry: (() -> Void)?
    var onRecover: (() -> Void)?

    private(set) var strings: LocalizedStrings
    let enabledCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let clearButton = NSButton(title: "", target: nil, action: nil)
    let retryButton = NSButton(title: "", target: nil, action: nil)
    let recoverButton = NSButton(title: "", target: nil, action: nil)
    let statusLabel = NSTextField(wrappingLabelWithString: "")
    let helpLabel = NSTextField(wrappingLabelWithString: "")
    private let headingLabel = NSTextField(wrappingLabelWithString: "")
    private var state = State(enabled: false, canEnable: false, isBusy: false,
                              canClear: false, status: .waiting, canRetry: false, canRecover: false)

    init(frame frameRect: NSRect, strings: LocalizedStrings) {
        self.strings = strings
        super.init(frame: frameRect)

        enabledCheckbox.target = self
        enabledCheckbox.action = #selector(enabledChanged(_:))
        enabledCheckbox.allowsMixedState = false
        enabledCheckbox.cell?.wraps = true
        enabledCheckbox.cell?.isScrollable = false
        enabledCheckbox.cell?.lineBreakMode = .byWordWrapping
        clearButton.target = self
        clearButton.action = #selector(clearClicked(_:))
        retryButton.target = self
        retryButton.action = #selector(retryClicked(_:))
        recoverButton.target = self
        recoverButton.action = #selector(recoverClicked(_:))
        for button in [clearButton, retryButton, recoverButton] {
            button.bezelStyle = .rounded
        }
        for (view, suffix) in [
            (self as NSView, "section"), (headingLabel, "title"),
            (enabledCheckbox, "enabled"), (helpLabel, "help"),
            (statusLabel, "status"), (clearButton, "clear"),
            (retryButton, "retry"), (recoverButton, "recover")
        ] {
            let identifier = "launchActivity.settings." + suffix
            view.identifier = NSUserInterfaceItemIdentifier(identifier)
            view.setAccessibilityIdentifier(identifier)
        }
        headingLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        for label in [helpLabel, statusLabel, headingLabel] {
            label.maximumNumberOfLines = 0
            label.lineBreakMode = .byWordWrapping
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        enabledCheckbox.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        enabledCheckbox.cell?.wraps = true
        enabledCheckbox.cell?.lineBreakMode = .byWordWrapping
        helpLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        helpLabel.textColor = .secondaryLabelColor
        statusLabel.textColor = .secondaryLabelColor

        // No fixed heights: the wrapping labels determine the fitting height of
        // this child when Main composes it into the Library settings pane.
        let stack = NSStackView(views: [headingLabel, enabledCheckbox, helpLabel,
                                        statusLabel, clearButton, retryButton, recoverButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.detachesHiddenViews = true
        // Prefer the arranged content's natural height when this view itself is
        // an arranged child. The enclosing pane may scroll rather than compress
        // the privacy explanation to satisfy a fixed viewport height.
        stack.setHuggingPriority(.defaultHigh, for: .vertical)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            headingLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            enabledCheckbox.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor),
            helpLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            clearButton.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor),
            retryButton.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor),
            recoverButton.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor)
        ])
        relabel(strings: strings)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func relabel(strings: LocalizedStrings) {
        self.strings = strings
        headingLabel.stringValue = strings.launchActivityText(.title)
        headingLabel.setAccessibilityLabel(headingLabel.stringValue)
        setAccessibilityLabel(headingLabel.stringValue)
        enabledCheckbox.title = strings.launchActivityText(.enabled)
        enabledCheckbox.setAccessibilityLabel(enabledCheckbox.title)
        helpLabel.stringValue = strings.launchActivityText(.privacyHelp)
        helpLabel.setAccessibilityLabel(helpLabel.stringValue)
        for (button, key) in [(clearButton, LaunchActivityTextKey.clear),
                              (retryButton, .retry), (recoverButton, .recover)] {
            button.title = strings.launchActivityText(key)
            button.setAccessibilityLabel(button.title)
        }
        renderState()
    }

    func applyState(_ state: State) {
        self.state = state
        renderState()
    }

    @objc func enabledChanged(_ sender: Any?) {
        let requested = enabledCheckbox.state == .on
        guard enabledCheckbox.state != .mixed,
              state.canEnable || (state.enabled && !requested) else {
            renderState()
            return
        }
        // Reset to the supplied baseline before calling Main. Main may publish a
        // new admission/receipt snapshot synchronously; never overwrite it after.
        renderState()
        onSetEnabled?(requested)
    }

    @objc func clearClicked(_ sender: Any?) {
        guard state.canClear, !state.isBusy else { return }
        onClear?() // Main presents confirmation before accepting a destructive action.
    }

    @objc func retryClicked(_ sender: Any?) {
        guard state.canRetry, !state.isBusy else { return }
        onRetry?()
    }

    @objc func recoverClicked(_ sender: Any?) {
        guard state.canRecover, !state.isBusy else { return }
        onRecover?()
    }

    private func renderState() {
        enabledCheckbox.state = state.enabled ? .on : .off
        // Do not gate this on isBusy: Main must be able to stop admission while
        // an earlier disk write is pending. canEnable is the owner's authority.
        enabledCheckbox.isEnabled = state.enabled || state.canEnable
        clearButton.isEnabled = state.canClear && !state.isBusy
        retryButton.isHidden = !state.canRetry
        retryButton.isEnabled = state.canRetry && !state.isBusy
        recoverButton.isHidden = !state.canRecover
        recoverButton.isEnabled = state.canRecover && !state.isBusy
        statusLabel.stringValue = strings.launchActivityText(state.status)
        statusLabel.setAccessibilityLabel(statusLabel.stringValue)
        statusLabel.textColor = state.status == .saveFailed ? .systemRed : .secondaryLabelColor
    }
}
