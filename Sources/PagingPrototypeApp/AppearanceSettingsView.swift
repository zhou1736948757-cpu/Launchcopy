import AppKit
import LauncherLocalization

/// Persistence and presentation are separate owner-reported facts.
public enum LiveSettingsSaveState: Equatable {
    case idle, pending, saved, failed, protected, recoveryRequired, unavailable
}

/// Native tracking returns only after the final slider action has been delivered.
/// Interaction-end flushing stays local to the control, without an event monitor.
@MainActor
final class LiveAppearanceSlider: NSSlider {
    var onTrackingEnded: (() -> Void)?
    private(set) var isTrackingMouse = false

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        isTrackingMouse = true
        defer { isTrackingMouse = false; trackingDidEnd() }
        super.mouseDown(with: event)
    }

    func trackingDidEnd() { onTrackingEnded?() }
}

/// One scrolling page; domain owners admit edits and publish actual save feedback.
@MainActor
public final class AppearanceSettingsView: NSView {
    public private(set) var strings: LocalizedStrings
    public private(set) var draft = AppearancePreferences.default
    public var presentationStateProvider: (() -> AppearancePresentationState)?
    public var onChange: ((AppearancePreferences) -> Bool)?
    public var onFlush: (() -> Void)?
    /// Candidate geometry for this draft in the owner's current main-page viewport.
    /// This callback reports neither persistence nor displayed presentation receipts.
    public var mainIconFitProvider: ((AppearancePreferences) -> (app: CGFloat, folder: CGFloat)?)? {
        didSet { refreshMainIconFit() }
    }
    public var onRestoreGridDefaults: (() -> Void)? {
        didSet { renderFeedback() }
    }
    /// Explicit retry/recovery only. Ordinary controls never invoke this callback.
    public var onApply: ((AppearancePreferences) -> AppearancePreferencesSaveResult)?
    /// Retained dismissal seam; the owner binds this to flushing accepted work.
    var onDiscardDraft: (() -> Void)?

    let labelsCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let blurSlider = LiveAppearanceSlider(value: 18, minValue: 0, maxValue: 60, target: nil, action: nil)
    let blurValue = NSTextField(labelWithString: "18")
    let mainIconSlider = LiveAppearanceSlider(value: 80, minValue: 32, maxValue: 96, target: nil, action: nil)
    let mainIconValue = NSTextField(labelWithString: "80")
    let iconSlider = LiveAppearanceSlider(value: Double(AppearancePreferences.defaultIconSide),
        minValue: Double(AppearancePreferences.supportedIconSide.lowerBound),
        maxValue: Double(AppearancePreferences.supportedIconSide.upperBound), target: nil, action: nil)
    let iconValue = NSTextField(labelWithString: String(AppearancePreferences.defaultIconSide))
    let fontSlider = LiveAppearanceSlider(value: 11, minValue: 9, maxValue: 16, target: nil, action: nil)
    let fontValue = NSTextField(labelWithString: "11")
    let blurCaption = NSTextField(wrappingLabelWithString: "")
    let mainIconCaption = NSTextField(wrappingLabelWithString: "")
    let iconCaption = NSTextField(wrappingLabelWithString: "")
    let fontCaption = NSTextField(wrappingLabelWithString: "")
    let helpLabel = NSTextField(wrappingLabelWithString: "")
    let iconHelpLabel = NSTextField(wrappingLabelWithString: "")
    let mainIconFitLabel = NSTextField(wrappingLabelWithString: "")
    let statusLabel = NSTextField(wrappingLabelWithString: "")
    let applyButton = NSButton(title: "", target: nil, action: nil)
    let defaultsButton = NSButton(title: "", target: nil, action: nil)
    let gridTitleLabel = NSTextField(wrappingLabelWithString: "")
    private let contentStack = NSStackView()
    private let gridSectionStack = NSStackView()
    private(set) var mainGridSection: MainGridCapacitySettingsView?
    private(set) var liveSaveState: LiveSettingsSaveState = .idle
    private var presentation: AppearancePresentationState = .applied
    private var requiresRecovery = false
    private var recoverySubmitted = false
    private var protectedPayload = false
    private var lastSubmitted: AppearancePreferences? = .default
    private var validationFeedback: SettingsTextKey?
    private var statusRevision = 0

    public override convenience init(frame frameRect: NSRect) {
        self.init(frame: frameRect, strings: LocalizedStrings(language: .simplifiedChinese))
    }

    public init(frame frameRect: NSRect, strings: LocalizedStrings) {
        self.strings = strings
        super.init(frame: frameRect)
        labelsCheckbox.target = self
        labelsCheckbox.action = #selector(controlChanged(_:))
        labelsCheckbox.identifier = NSUserInterfaceItemIdentifier("appearance.showLabels")
        for (slider, identifier) in [
            (blurSlider, "appearance.wallpaperBlur"),
            (mainIconSlider, "appearance.mainIconSize"),
            (iconSlider, "appearance.iconSize"),
            (fontSlider, "appearance.labelFontSize")
        ] {
            slider.target = self
            slider.action = #selector(controlChanged(_:))
            slider.isContinuous = true
            slider.identifier = NSUserInterfaceItemIdentifier(identifier)
            slider.onTrackingEnded = { [weak self] in self?.onFlush?() }
        }
        applyButton.target = self
        applyButton.action = #selector(applyClicked(_:))
        applyButton.identifier = NSUserInterfaceItemIdentifier("appearance.apply")
        defaultsButton.target = self
        defaultsButton.action = #selector(defaultsClicked(_:))
        defaultsButton.identifier = NSUserInterfaceItemIdentifier("appearance.defaults")
        for button in [applyButton, defaultsButton] { button.bezelStyle = .rounded }
        helpLabel.textColor = .secondaryLabelColor
        iconHelpLabel.textColor = .secondaryLabelColor
        mainIconFitLabel.textColor = .secondaryLabelColor
        mainIconFitLabel.identifier = NSUserInterfaceItemIdentifier("appearance.mainIconFit")
        mainIconSlider.setAccessibilityIdentifier("appearance.mainIconSize")
        mainIconFitLabel.setAccessibilityIdentifier("appearance.mainIconFit")
        gridTitleLabel.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        configureVerticalStack(contentStack, spacing: 18)
        configureVerticalStack(gridSectionStack, spacing: 12)
        gridSectionStack.addArrangedSubview(gridTitleLabel)
        gridSectionStack.isHidden = true
        let buttons = NSStackView(views: [applyButton, defaultsButton])
        buttons.orientation = .horizontal
        buttons.spacing = 12
        let contents: [NSView] = [labelsCheckbox, blurCaption, sliderRow(blurSlider, value: blurValue),
            mainIconCaption, sliderRow(mainIconSlider, value: mainIconValue),
            iconCaption, sliderRow(iconSlider, value: iconValue),
            fontCaption, sliderRow(fontSlider, value: fontValue), helpLabel,
            iconHelpLabel, mainIconFitLabel, statusLabel, gridSectionStack, buttons]
        for view in contents {
            contentStack.addArrangedSubview(view)
        }
        for case let row as NSStackView in contentStack.arrangedSubviews
            where row !== gridSectionStack && row !== buttons {
            row.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        }
        let document = AppearanceSettingsDocumentView(frame: .zero)
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(contentStack)
        let scroll = NSScrollView(frame: .zero)
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            contentStack.topAnchor.constraint(equalTo: document.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24),
            helpLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            iconHelpLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            mainIconFitLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            gridSectionStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            gridTitleLabel.widthAnchor.constraint(equalTo: gridSectionStack.widthAnchor)
        ])
        relabel(strings: strings)
        reload(preferences: .default)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Composition only: retain the owner's existing view and all callbacks/state.
    func attachMainGridSection(_ section: MainGridCapacitySettingsView) {
        guard mainGridSection !== section else { return }
        if let previous = mainGridSection {
            previous.onDraftChange = nil
            gridSectionStack.removeArrangedSubview(previous)
            previous.removeFromSuperview()
        }
        section.setEmbedded(true)
        section.translatesAutoresizingMaskIntoConstraints = false
        mainGridSection = section
        section.onDraftChange = { [weak self] in self?.refreshMainIconFit() }
        gridSectionStack.addArrangedSubview(section)
        section.widthAnchor.constraint(equalTo: gridSectionStack.widthAnchor).isActive = true
        gridSectionStack.isHidden = false
        refreshMainIconFit()
        renderFeedback()
    }

    /// Snapshot synchronization is silent, including supported corrupt/future loads.
    public func reload(preferences: AppearancePreferences,
                       loadResult: AppearancePreferencesLoadResult? = nil) {
        draft = preferences
        lastSubmitted = preferences
        validationFeedback = nil
        requiresRecovery = false
        recoverySubmitted = false
        protectedPayload = false
        syncControls()
        switch loadResult {
        case .futureVersion?:
            protectedPayload = true
            liveSaveState = .protected
        case .corrupt?:
            requiresRecovery = true
            liveSaveState = .recoveryRequired
        default: liveSaveState = .idle
        }
        presentation = presentationStateProvider?() ?? .applied
        statusRevision += 1
        renderFeedback()
    }

    /// The owner must suppress stale receipts before calling this method.
    public func updateLiveStatus(_ state: LiveSettingsSaveState,
                                 presentation: AppearancePresentationState) {
        statusRevision += 1
        self.presentation = presentation
        if state == .protected { protectedPayload = true }
        if state == .recoveryRequired { requiresRecovery = true; recoverySubmitted = false }
        if state == .failed { recoverySubmitted = false }
        if state == .saved, recoverySubmitted {
            requiresRecovery = false
            recoverySubmitted = false
        }
        if protectedPayload { liveSaveState = .protected }
        else if requiresRecovery, state != .failed, !(state == .pending && recoverySubmitted) {
            liveSaveState = .recoveryRequired
        } else { liveSaveState = state }
        renderFeedback()
    }

    @objc func controlChanged(_ sender: Any?) {
        guard controlsMayChange,
              collectControls(mainIconChanged: (sender as? NSControl) === mainIconSlider) else { return }
        guard !requiresRecovery else { renderFeedback(); return }
        submitChange()
        // Discrete/keyboard/accessibility actions end here. Continuous native
        // mouse tracking flushes only when mouseDown returns after its final action.
        if let control = sender as? NSControl {
            if control === labelsCheckbox || (control as? LiveAppearanceSlider)?.isTrackingMouse == false {
                onFlush?()
            }
        }
    }

    /// Deliberate recovery or retry; never re-enters the automatic action path.
    @objc func applyClicked(_ sender: Any?) {
        guard controlsMayChange, requiresRecovery || liveSaveState == .failed,
              collectControls() else { return }
        guard let onApply else {
            if !requiresRecovery { submitChange(force: true); onFlush?() }
            return
        }
        recoverySubmitted = requiresRecovery
        updateLiveStatus(.pending, presentation: presentationStateProvider?() ?? presentation)
        switch onApply(draft) {
        case .saved:
            lastSubmitted = draft
            updateLiveStatus(.saved, presentation: presentationStateProvider?() ?? presentation)
        case .futureVersion:
            updateLiveStatus(.protected, presentation: presentation)
        case .invalidPreferences:
            validationFeedback = .appearanceInvalidPreferences
            updateLiveStatus(.failed, presentation: presentation)
        case .encodingFailed:
            updateLiveStatus(.failed, presentation: presentation)
        }
    }

    @objc func defaultsClicked(_ sender: Any?) {
        // Independent domains may have different availability/protection outcomes.
        if controlsMayChange {
            draft = .default
            validationFeedback = nil
            syncControls()
            if !requiresRecovery { submitChange(force: true) }
            else { renderFeedback() }
        }
        onRestoreGridDefaults?()
        onFlush?()
    }

    private var controlsMayChange: Bool {
        !protectedPayload && liveSaveState != .unavailable
    }

    @discardableResult
    private func collectControls(mainIconChanged: Bool = false) -> Bool {
        let blur = blurSlider.doubleValue.rounded()
        let mainIcon = mainIconSlider.doubleValue.rounded()
        let icon = iconSlider.doubleValue.rounded()
        let font = fontSlider.doubleValue.rounded()
        guard blur.isFinite, mainIcon.isFinite, icon.isFinite, font.isFinite,
              (0...60).contains(blur), (32...96).contains(mainIcon),
              (Double(AppearancePreferences.supportedIconSide.lowerBound)...Double(AppearancePreferences.supportedIconSide.upperBound)).contains(icon), (9...16).contains(font) else {
            validationFeedback = .appearanceInvalidDraft
            renderFeedback()
            return false
        }
        // Mutate the retained draft so unrelated controls keep legacy inheritance
        // or an explicit override, including recovery/retry collections.
        draft.showsAppLabels = labelsCheckbox.state == .on
        draft.wallpaperBlurRadius = Int(blur)
        draft.preferredIconSide = Int(icon)
        draft.appLabelFontSize = Int(font)
        if mainIconChanged { draft.mainPreferredIconSide = Int(mainIcon) }
        // Keep continuous tracking untouched; only an inherited main slider must
        // follow a base-size edit. Captions still show the rounded draft values.
        if draft.mainPreferredIconSide == nil {
            mainIconSlider.integerValue = draft.mainItemAppearance.preferredIconSide
        }
        validationFeedback = nil
        updateValueCaptions()
        return true
    }

    private func submitChange(force: Bool = false) {
        guard !requiresRecovery, controlsMayChange else { return }
        guard force || draft != lastSubmitted else { renderFeedback(); return }
        guard let onChange else {
            updateLiveStatus(.unavailable, presentation: presentation)
            return
        }
        updateLiveStatus(.pending, presentation: presentationStateProvider?() ?? presentation)
        let revision = statusRevision
        let submitted = draft
        if onChange(submitted) { lastSubmitted = submitted }
        else if statusRevision == revision {
            updateLiveStatus(.failed, presentation: presentation)
        }
    }

    private func syncControls() {
        labelsCheckbox.state = draft.showsAppLabels ? .on : .off
        blurSlider.integerValue = draft.wallpaperBlurRadius
        mainIconSlider.integerValue = draft.mainItemAppearance.preferredIconSide
        iconSlider.integerValue = draft.preferredIconSide
        fontSlider.integerValue = draft.appLabelFontSize
        updateValueCaptions()
    }

    private func updateValueCaptions() {
        for (label, value) in [(blurValue, draft.wallpaperBlurRadius),
                               (mainIconValue, draft.mainItemAppearance.preferredIconSide),
                               (iconValue, draft.preferredIconSide), (fontValue, draft.appLabelFontSize)] {
            label.stringValue = String(value)
            label.setAccessibilityValue(label.stringValue)
        }
        refreshMainIconFit()
    }

    /// Refresh after viewport or main-grid capacity changes. Never submits a draft
    /// or changes save/presentation feedback, even while presentation is queued.
    public func refreshMainIconFit() {
        let fit = mainIconFitProvider?(draft)
        let message: String
        if let fit, fit.app.isFinite, fit.folder.isFinite, fit.app >= 0, fit.folder >= 0 {
            message = strings.mainIconFitText(app: Double(fit.app), folder: Double(fit.folder))
        } else {
            message = ""
        }
        mainIconFitLabel.stringValue = message
        mainIconFitLabel.setAccessibilityLabel(message)
        mainIconFitLabel.setAccessibilityValue(message)
        mainIconFitLabel.isHidden = message.isEmpty
    }

    /// Presentation-only refresh cannot promote pending persistence to Saved.
    public func refreshPresentationStatus() {
        presentation = presentationStateProvider?() ?? presentation
        renderFeedback()
    }

    private func renderFeedback() {
        let key: LiveAppearanceTextKey?
        switch liveSaveState {
        case .idle: key = nil
        case .pending: key = .saving
        case .saved: key = .saved
        case .failed: key = requiresRecovery ? .recoveryFailed : .saveFailed
        case .protected: key = .protected
        case .recoveryRequired: key = .recoveryRequired
        case .unavailable: key = .unavailable
        }
        var messages = key.map { [strings.liveAppearanceText($0)] } ?? []
        if liveSaveState == .idle || liveSaveState == .pending || liveSaveState == .saved {
            switch presentation {
            case .applied: break
            case .queued: messages.append(strings.liveAppearanceText(.queued))
            case .unavailable:
                // Legacy presentation-unavailable copy asserts persistence success.
                // It is truthful only once the owner has acknowledged this save.
                if liveSaveState == .saved {
                    messages.append(strings.settingsText(.appearancePresentationUnavailable))
                }
            }
        }
        if let validationFeedback { messages.insert(strings.settingsText(validationFeedback), at: 0) }
        let message = messages.joined(separator: "\n")
        statusLabel.stringValue = message
        statusLabel.setAccessibilityLabel(message)
        statusLabel.setAccessibilityValue(message)
        statusLabel.isHidden = message.isEmpty
        let isError = validationFeedback != nil || liveSaveState == .failed
            || liveSaveState == .protected || liveSaveState == .recoveryRequired || liveSaveState == .unavailable
        statusLabel.textColor = isError ? .systemRed
            : (liveSaveState == .saved && presentation == .applied ? .systemGreen : .secondaryLabelColor)
        for control in [labelsCheckbox as NSControl, blurSlider, mainIconSlider, iconSlider, fontSlider] {
            control.isEnabled = controlsMayChange
        }
        applyButton.isHidden = protectedPayload || (!requiresRecovery && liveSaveState != .failed)
        applyButton.isEnabled = controlsMayChange
        applyButton.title = strings.liveAppearanceText(requiresRecovery ? .recover : .retry)
        applyButton.setAccessibilityLabel(applyButton.title)
        defaultsButton.isEnabled = controlsMayChange || onRestoreGridDefaults != nil || mainGridSection != nil
    }

    /// Text and accessibility only; no snapshot synchronization or submissions.
    public func relabel(strings: LocalizedStrings) {
        self.strings = strings
        labelsCheckbox.title = strings.settingsText(.appearanceShowLabels)
        labelsCheckbox.setAccessibilityLabel(labelsCheckbox.title)
        blurSlider.setAccessibilityLabel(strings.settingsText(.appearanceBlurAccessibility))
        mainIconSlider.setAccessibilityLabel(strings.settingsText(.appearanceMainIconAccessibility))
        iconSlider.setAccessibilityLabel(strings.settingsText(.appearanceIconAccessibility))
        fontSlider.setAccessibilityLabel(strings.settingsText(.appearanceFontAccessibility))
        for (label, key) in [(blurCaption, SettingsTextKey.appearanceBlurCaption),
                             (mainIconCaption, .appearanceMainIconCaption),
                             (iconCaption, .appearanceIconCaption), (fontCaption, .appearanceFontCaption)] {
            label.stringValue = strings.settingsText(key)
            label.setAccessibilityLabel(label.stringValue)
        }
        helpLabel.stringValue = strings.liveAppearanceText(.help)
        helpLabel.setAccessibilityLabel(helpLabel.stringValue)
        iconHelpLabel.stringValue = strings.settingsText(.appearanceIndependentIconsHelp)
        iconHelpLabel.setAccessibilityLabel(iconHelpLabel.stringValue)
        refreshMainIconFit()
        gridTitleLabel.stringValue = strings.mainGridCapacityText(.title)
        gridTitleLabel.setAccessibilityLabel(gridTitleLabel.stringValue)
        defaultsButton.title = strings.liveAppearanceText(.defaults)
        defaultsButton.setAccessibilityLabel(defaultsButton.title)
        renderFeedback()
    }

    private func configureVerticalStack(_ stack: NSStackView, spacing: CGFloat) {
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        stack.detachesHiddenViews = true
        stack.translatesAutoresizingMaskIntoConstraints = false
    }

    private func sliderRow(_ slider: NSSlider, value: NSTextField) -> NSStackView {
        value.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        value.setContentCompressionResistancePriority(.required, for: .horizontal)
        let row = NSStackView(views: [slider, value])
        row.orientation = .horizontal
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        let minimumWidth = slider.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
        minimumWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            value.widthAnchor.constraint(greaterThanOrEqualToConstant: 28), minimumWidth
        ])
        return row
    }
}

private final class AppearanceSettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}
