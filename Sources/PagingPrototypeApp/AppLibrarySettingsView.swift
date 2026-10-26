import AppGridUI
import AppKit
import LauncherLocalization

/// Presentation only. The owner supplies committed preferences and save receipts,
/// and owns storage, recovery confirmation and accepted-write lifetime.
@MainActor
final class AppLibrarySettingsView: NSView {
    var onSetEnabled: ((Bool) -> Bool)?
    var onRecover: (() -> Void)? {
        didSet { renderState() }
    }

    let scrollView = NSScrollView()
    private let contentDocument = LibrarySettingsDocumentView()
    let activitySettingsView: LaunchActivitySettingsView
    private(set) var strings: LocalizedStrings
    let enabledCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let recoverButton = NSButton(title: "", target: nil, action: nil)
    let statusLabel = NSTextField(wrappingLabelWithString: "")
    private let headingLabel = NSTextField(labelWithString: "")
    private var preferences = AppLibraryPreferences.default
    private var loadResult = AppLibraryLoadResult.missing
    private var pendingCount = 0
    private var saveResult: AppLibrarySaveResult?
    private var isLoaded = false
    // Acceptance is not a receipt. Keep the requested value separate from the
    // checkbox, which always displays committed state (or explicitly unknown).
    private var pendingEnabled: Bool?
    private var localFeedback: LibraryTextKey?

    init(frame frameRect: NSRect, strings: LocalizedStrings) {
        self.strings = strings
        self.activitySettingsView = LaunchActivitySettingsView(frame: .zero, strings: strings)
        super.init(frame: frameRect)
        enabledCheckbox.target = self
        enabledCheckbox.action = #selector(enabledChanged(_:))
        recoverButton.target = self
        recoverButton.action = #selector(recoverClicked(_:))
        recoverButton.bezelStyle = .rounded
        for (view, identifier) in [
            (enabledCheckbox as NSView, "library.settings.enabled"),
            (recoverButton as NSView, "library.settings.recover"),
            (statusLabel as NSView, "library.settings.status")
        ] {
            view.identifier = NSUserInterfaceItemIdentifier(identifier)
            view.setAccessibilityIdentifier(identifier)
        }
        headingLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 0
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        statusLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        // Stack the recovery control below the wrapping status; a horizontal
        // button row would compete with long localized messages in the 500pt pane.
        let stack = NSStackView(views: [headingLabel, enabledCheckbox, statusLabel, recoverButton, activitySettingsView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.detachesHiddenViews = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentDocument.translatesAutoresizingMaskIntoConstraints = false
        contentDocument.addSubview(stack)
        scrollView.documentView = contentDocument
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentDocument.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            contentDocument.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            contentDocument.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor),
            stack.leadingAnchor.constraint(equalTo: contentDocument.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentDocument.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentDocument.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: contentDocument.bottomAnchor, constant: -24),
            activitySettingsView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            headingLabel.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor),
            enabledCheckbox.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            recoverButton.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor)
        ])
        relabel(strings: strings)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func applyState(preferences: AppLibraryPreferences, loadResult: AppLibraryLoadResult,
                    pendingCount: Int, saveResult: AppLibrarySaveResult?, isLoaded: Bool) {
        self.preferences = preferences
        self.loadResult = loadResult
        self.pendingCount = max(0, pendingCount)
        self.saveResult = saveResult
        self.isLoaded = isLoaded
        localFeedback = nil
        // A terminal owner snapshot reconciles to the actual last successful
        // baseline, including an older successful write followed by a failure.
        if !isLoaded || self.pendingCount == 0 { pendingEnabled = nil }
        renderState()
    }

    /// Localization changes only presentation. Never reload, submit or recover.
    func relabel(strings: LocalizedStrings) {
        activitySettingsView.relabel(strings: strings)
        self.strings = strings
        headingLabel.stringValue = strings.libraryText(.title)
        headingLabel.setAccessibilityLabel(headingLabel.stringValue)
        enabledCheckbox.title = strings.libraryText(.enable)
        enabledCheckbox.setAccessibilityLabel(enabledCheckbox.title)
        recoverButton.title = strings.libraryText(.recover)
        recoverButton.setAccessibilityLabel(recoverButton.title)
        renderState()
    }

    @objc func enabledChanged(_ sender: Any?) {
        guard canChangeEnabled else { renderState(); return }
        let requested = enabledCheckbox.state == .on
        guard let onSetEnabled else {
            localFeedback = .unavailable
            renderState()
            return
        }
        pendingEnabled = requested
        localFeedback = nil
        renderState()
        // The callback may synchronously apply a pending or terminal snapshot.
        // Set local pending before invoking it, never after a possible receipt.
        if !onSetEnabled(requested) {
            pendingEnabled = nil
            localFeedback = .saveFailed
            renderState()
        }
    }

    @objc func recoverClicked(_ sender: Any?) {
        guard canRecover else { return }
        // Merely request the owner's confirmation flow. No speculative reset.
        onRecover?()
    }

    private var isPending: Bool { pendingCount > 0 || pendingEnabled != nil }

    private var needsRecovery: Bool {
        if case .corrupt = loadResult { return true }
        return saveResult == .recoveryRequired
    }

    private var isProtected: Bool {
        switch loadResult {
        case .futureVersion, .ambiguousSchema, .oversized, .unavailable: return true
        case .missing, .loaded, .corrupt: break
        }
        return saveResult == .protectedPayload || saveResult == .unavailable
    }

    private var canChangeEnabled: Bool {
        isLoaded && !isPending && !isProtected && !needsRecovery
    }

    private var canRecover: Bool {
        isLoaded && !isPending && !isProtected && needsRecovery && onRecover != nil
    }

    private var statusKey: LibraryTextKey? {
        guard isLoaded else { return .loading }
        // Protected bytes take precedence over stale save receipts, without
        // claiming that ambiguous or oversized content is a newer schema.
        if case .futureVersion = loadResult { return .loadFuture }
        if isProtected { return .unavailable }
        if isPending { return .pending }
        if needsRecovery {
            return saveResult == .failed || saveResult == .invalidPreferences ? .saveFailed : .loadCorrupt
        }
        if let localFeedback { return localFeedback }
        switch saveResult {
        case .saved?: return .saved
        case .invalidPreferences?, .failed?: return .saveFailed
        case .recoveryRequired?: return .loadCorrupt
        case .protectedPayload?, .unavailable?: return .unavailable
        case nil: return nil
        }
    }

    private func renderState() {
        let unknown = isLoaded && isProtected
        enabledCheckbox.allowsMixedState = unknown
        enabledCheckbox.state = unknown ? .mixed
            : (isLoaded && !needsRecovery && preferences.enabled ? .on : .off)
        enabledCheckbox.setAccessibilityHelp(unknown ? strings.libraryText(.unknown) : nil)
        enabledCheckbox.isEnabled = canChangeEnabled
        recoverButton.isHidden = !isLoaded || !needsRecovery || isProtected
        recoverButton.isEnabled = canRecover
        let key = statusKey
        var message = key.map { strings.libraryText($0) } ?? ""
        if needsRecovery && key == .saveFailed {
            message += "\n" + strings.libraryText(.loadCorrupt)
        }
        statusLabel.stringValue = message
        statusLabel.setAccessibilityLabel(message)
        statusLabel.isHidden = message.isEmpty
    }
}

private final class LibrarySettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}
