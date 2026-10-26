import AppGridUI
import AppKit
import LauncherLocalization

/// Automatically submits healthy edits. Only the owner supplies persistence receipts
/// and presentation state; admission alone never establishes a successful save.
@MainActor
final class MainGridCapacitySettingsView: NSView {
    private(set) var strings: LocalizedStrings
    private(set) var draft: MainGridCapacity = .default {
        didSet { if draft != oldValue { onDraftChange?() } }
    }
    /// Projection-only observer; never submits or acknowledges persistence.
    var onDraftChange: (() -> Void)?
    var onApply: ((MainGridCapacity) -> Bool)?
    var onDiscardDraft: (() -> Void)?
    /// True only inside an explicit recovery callback; live actions never authorize repair.
    private(set) var isExplicitRecoveryRequest = false

    let columnsPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let rowsPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let countLabel = NSTextField(labelWithString: "")
    let applyButton = NSButton(title: "", target: nil, action: nil)
    let defaultsButton = NSButton(title: "", target: nil, action: nil)
    let columnsLabel = NSTextField(labelWithString: "")
    let rowsLabel = NSTextField(labelWithString: "")
    let helpLabel = NSTextField(wrappingLabelWithString: "")
    let loadStatusLabel = NSTextField(wrappingLabelWithString: "")
    let statusLabel = NSTextField(wrappingLabelWithString: "")
    let draftStatusLabel = NSTextField(wrappingLabelWithString: "")

    private var columnsItems: [NSMenuItem] = []
    private var rowsItems: [NSMenuItem] = []
    private var writesAllowed = false
    private var requiresExplicitRecovery = false
    private var recoverySubmitted = false
    private var retryRequired = false
    private var lastSubmitted: MainGridCapacity?
    private var statusRevision = 0
    private(set) var isEmbedded = false
    private let contentStack = NSStackView()
    private let buttonRow = NSStackView()
    private var layoutConstraints: [NSLayoutConstraint] = []
    private var loadFeedback: Feedback?
    private var receiptFeedback: Feedback?
    private var draftFeedback: Feedback?

    private struct Feedback {
        let key: MainGridCapacityTextKey
        let color: NSColor
    }

    init(frame frameRect: NSRect, strings: LocalizedStrings, embedded: Bool = false) {
        self.strings = strings
        super.init(frame: frameRect)
        columnsItems = configure(columnsPopup, identifier: "mainGridCapacity.columns")
        rowsItems = configure(rowsPopup, identifier: "mainGridCapacity.rows")
        applyButton.target = self
        applyButton.action = #selector(applyClicked(_:))
        applyButton.identifier = NSUserInterfaceItemIdentifier("mainGridCapacity.apply")
        defaultsButton.target = self
        defaultsButton.action = #selector(defaultsClicked(_:))
        defaultsButton.identifier = NSUserInterfaceItemIdentifier("mainGridCapacity.defaults")
        countLabel.identifier = NSUserInterfaceItemIdentifier("mainGridCapacity.count")
        for button in [applyButton, defaultsButton] { button.bezelStyle = .rounded }
        helpLabel.textColor = .secondaryLabelColor

        let columnsRow = NSStackView(views: [columnsLabel, columnsPopup])
        let rowsRow = NSStackView(views: [rowsLabel, rowsPopup])
        for row in [columnsRow, rowsRow] { row.orientation = .horizontal; row.spacing = 12 }
        let stack = contentStack
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.detachesHiddenViews = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 12
        buttonRow.detachesHiddenViews = true
        buttonRow.addArrangedSubview(applyButton)
        buttonRow.addArrangedSubview(defaultsButton)
        let contents: [NSView] = [columnsRow, rowsRow, countLabel, helpLabel, loadStatusLabel,
            draftStatusLabel, statusLabel, buttonRow]
        for view in contents {
            stack.addArrangedSubview(view)
        }
        NSLayoutConstraint.activate([
            columnsPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            rowsPopup.widthAnchor.constraint(equalTo: columnsPopup.widthAnchor),
            helpLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            loadStatusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            draftStatusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        installLayout(embedded: embedded)
        // Factory/load readiness belongs to Main. An unconfigured view cannot write.
        reload(capacity: .default, loadResult: .unavailable)
        relabel(strings: strings)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Reparent the same controls without reloading, relabeling or writing anything.
    /// Embedded mode has no nested scroll view, fixed height or unused footer.
    func setEmbedded(_ embedded: Bool) {
        guard embedded != isEmbedded else { return }
        installLayout(embedded: embedded)
        updateWriteAvailability()
    }

    private func installLayout(embedded: Bool) {
        NSLayoutConstraint.deactivate(layoutConstraints)
        layoutConstraints = []
        contentStack.removeFromSuperview()
        for view in subviews { view.removeFromSuperview() }
        isEmbedded = embedded
        if embedded {
            addSubview(contentStack)
            layoutConstraints = [
                contentStack.topAnchor.constraint(equalTo: topAnchor),
                contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
                contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
                contentStack.bottomAnchor.constraint(equalTo: bottomAnchor)
            ]
        } else {
            let document = MainGridCapacitySettingsDocumentView(frame: .zero)
            document.translatesAutoresizingMaskIntoConstraints = false
            document.addSubview(contentStack)
            let scroll = NSScrollView(frame: .zero)
            scroll.hasVerticalScroller = true
            scroll.autohidesScrollers = true
            scroll.drawsBackground = false
            scroll.translatesAutoresizingMaskIntoConstraints = false
            scroll.documentView = document
            addSubview(scroll)
            layoutConstraints = [
                scroll.topAnchor.constraint(equalTo: topAnchor),
                scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
                scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
                scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
                document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
                contentStack.topAnchor.constraint(equalTo: document.topAnchor, constant: 24),
                contentStack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
                contentStack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24),
                contentStack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24)
            ]
        }
        NSLayoutConstraint.activate(layoutConstraints)
    }

    /// Owner snapshot synchronization is silent.
    func reload(capacity: MainGridCapacity, loadResult: MainGridCapacityLoadResult) {
        draft = capacity
        draftFeedback = nil
        receiptFeedback = nil
        requiresExplicitRecovery = false
        recoverySubmitted = false
        retryRequired = false
        lastSubmitted = capacity
        statusRevision += 1
        switch loadResult {
        case .protectedPayload:
            writesAllowed = false
            loadFeedback = Feedback(key: .loadProtected, color: .systemRed)
        case .unavailable:
            writesAllowed = false
            loadFeedback = Feedback(key: .unavailable, color: .systemRed)
        case .corrupt:
            writesAllowed = true
            requiresExplicitRecovery = true
            loadFeedback = Feedback(key: .loadCorrupt, color: .systemRed)
        case .missing, .loaded:
            writesAllowed = true
            loadFeedback = nil
        }
        columnsPopup.selectItem(withTag: capacity.columns)
        rowsPopup.selectItem(withTag: capacity.rows)
        renderCount()
        updateWriteAvailability()
        renderFeedback()
    }

    /// Receipt-only refresh: never replaces a dirty draft or its current selection.
    func updateStatus(pendingCount: Int, saveResult: MainGridCapacitySaveResult?,
                      presentation: AppearancePresentationState) {
        statusRevision += 1
        // Protected/unavailable loads remain fail-closed until an owner reload.
        guard writesAllowed else {
            updateWriteAvailability()
            renderFeedback()
            return
        }
        if pendingCount > 0 {
            receiptFeedback = Feedback(key: .saving, color: .secondaryLabelColor)
        } else {
            switch saveResult {
            case .saved?:
                // An unrelated/old success cannot authorize corrupt-payload repair.
                guard !requiresExplicitRecovery || recoverySubmitted else {
                    updateWriteAvailability()
                    renderFeedback()
                    return
                }
                requiresExplicitRecovery = false
                recoverySubmitted = false
                retryRequired = false
                if loadFeedback?.key == .loadCorrupt { loadFeedback = nil }
                switch presentation {
                case .applied: receiptFeedback = Feedback(key: .applied, color: .systemGreen)
                case .queued: receiptFeedback = Feedback(key: .savedQueued, color: .secondaryLabelColor)
                case .unavailable: receiptFeedback = Feedback(key: .presentationUnavailable, color: .secondaryLabelColor)
                }
            case .invalid?:
                recoverySubmitted = false
                retryRequired = true
                receiptFeedback = Feedback(key: .invalidDraft, color: .systemRed)
            case .protectedPayload?:
                writesAllowed = false
                receiptFeedback = Feedback(key: .loadProtected, color: .systemRed)
            case .recoveryRequired?:
                requiresExplicitRecovery = true
                recoverySubmitted = false
                receiptFeedback = Feedback(key: .recoveryRequired, color: .systemRed)
            case .failed?:
                recoverySubmitted = false
                retryRequired = true
                receiptFeedback = Feedback(key: .saveFailed, color: .systemRed)
            case nil:
                // Missing receipts cannot turn admission into Saved or Applied.
                break
            }
        }
        updateWriteAvailability()
        renderFeedback()
    }

    @objc func controlChanged(_ sender: Any?) {
        guard controlsMayChange else { return }
        guard let capacity = selectedCapacity() else {
            draftFeedback = Feedback(key: .invalidDraft, color: .systemRed)
            renderFeedback()
            return
        }
        draft = capacity
        draftFeedback = nil
        renderCount()
        renderFeedback()
        if !requiresExplicitRecovery { submitDraft() }
    }

    @objc func applyClicked(_ sender: Any?) {
        guard controlsMayChange else { return }
        // The displayed count is derived output, never an input or an authority.
        // Reject injected menu items/tags and stale/tampered count presentations.
        guard let capacity = selectedCapacity(), capacity == draft,
              countLabel.stringValue == countText(for: capacity) else {
            draftFeedback = Feedback(key: .invalidDraft, color: .systemRed)
            renderFeedback()
            return
        }
        draftFeedback = nil
        recoverySubmitted = requiresExplicitRecovery
        submitDraft(force: true, explicitRecovery: requiresExplicitRecovery)
    }

    private func submitDraft(force: Bool = false, explicitRecovery: Bool = false) {
        guard writesAllowed, force || !requiresExplicitRecovery else { return }
        guard force || draft != lastSubmitted else { return }
        guard let onApply else {
            recoverySubmitted = false
            retryRequired = true
            receiptFeedback = Feedback(key: .unavailable, color: .systemRed)
            updateWriteAvailability()
            renderFeedback()
            return
        }
        retryRequired = false
        // Set before invoking the owner: submit may synchronously publish status.
        receiptFeedback = Feedback(key: .saving, color: .secondaryLabelColor)
        updateWriteAvailability()
        renderFeedback()
        let revision = statusRevision
        let submitted = draft
        let admitted: Bool = {
            isExplicitRecoveryRequest = explicitRecovery && requiresExplicitRecovery
            defer { isExplicitRecoveryRequest = false }
            return onApply(submitted)
        }()
        if admitted { lastSubmitted = submitted }
        else if statusRevision == revision {
            recoverySubmitted = false
            retryRequired = true
            receiptFeedback = Feedback(key: .unavailable, color: .systemRed)
            updateWriteAvailability()
            renderFeedback()
        }
    }

    @objc func defaultsClicked(_ sender: Any?) {
        guard controlsMayChange else { return }
        draft = .default
        columnsPopup.selectItem(withTag: draft.columns)
        rowsPopup.selectItem(withTag: draft.rows)
        renderCount()
        draftFeedback = nil
        guard selectedCapacity() == draft else {
            draftFeedback = Feedback(key: .invalidDraft, color: .systemRed)
            renderFeedback()
            return
        }
        renderFeedback()
        if !requiresExplicitRecovery { submitDraft(force: true) }
    }

    /// Text/AX only. Retains menus, selections, dirty draft, callbacks and receipts.
    func relabel(strings: LocalizedStrings) {
        self.strings = strings
        for (label, key) in [(columnsLabel, MainGridCapacityTextKey.columns),
                             (rowsLabel, .rows)] {
            label.stringValue = strings.mainGridCapacityText(key)
            label.setAccessibilityLabel(label.stringValue)
        }
        columnsPopup.setAccessibilityLabel(strings.mainGridCapacityText(.columns))
        rowsPopup.setAccessibilityLabel(strings.mainGridCapacityText(.rows))
        helpLabel.stringValue = strings.liveAppearanceText(.gridHelp)
        helpLabel.setAccessibilityLabel(helpLabel.stringValue)
        defaultsButton.title = strings.mainGridCapacityText(.restoreDefaults)
        defaultsButton.setAccessibilityLabel(defaultsButton.title)
        updateWriteAvailability()
        renderCount()
        renderFeedback()
    }

    private func configure(_ popup: NSPopUpButton, identifier: String) -> [NSMenuItem] {
        popup.identifier = NSUserInterfaceItemIdentifier(identifier)
        popup.target = self
        popup.action = #selector(controlChanged(_:))
        for dimension in MainGridCapacity.supportedDimensions {
            popup.addItem(withTitle: String(dimension))
            popup.lastItem?.tag = dimension
            popup.lastItem?.setAccessibilityLabel(String(dimension))
        }
        return popup.itemArray
    }

    private func selectedCapacity() -> MainGridCapacity? {
        func dimension(_ popup: NSPopUpButton, retained: [NSMenuItem]) -> Int? {
            let dimensions = Array(MainGridCapacity.supportedDimensions)
            guard popup.numberOfItems == dimensions.count, retained.count == dimensions.count else { return nil }
            for (index, value) in dimensions.enumerated() {
                guard popup.item(at: index) === retained[index], retained[index].tag == value,
                      retained[index].title == String(value) else { return nil }
            }
            guard let item = popup.selectedItem, retained.contains(where: { $0 === item }) else { return nil }
            return item.tag
        }
        guard let columns = dimension(columnsPopup, retained: columnsItems),
              let rows = dimension(rowsPopup, retained: rowsItems) else { return nil }
        return MainGridCapacity(columns: columns, rows: rows)
    }

    private func countText(for capacity: MainGridCapacity) -> String {
        strings.mainGridCapacityText(.itemsPerPage) + ": " + String(capacity.itemsPerPage)
    }

    private func renderCount() {
        countLabel.stringValue = countText(for: draft)
        countLabel.setAccessibilityLabel(countLabel.stringValue)
        countLabel.setAccessibilityValue(String(draft.itemsPerPage))
    }

    private func updateWriteAvailability() {
        for control in [columnsPopup as NSControl, rowsPopup, applyButton, defaultsButton] {
            control.isEnabled = controlsMayChange
        }
        applyButton.isHidden = !requiresExplicitRecovery && !retryRequired
        applyButton.title = strings.liveAppearanceText(requiresExplicitRecovery ? .recover : .retry)
        applyButton.setAccessibilityLabel(applyButton.title)
        defaultsButton.isHidden = isEmbedded
        buttonRow.isHidden = applyButton.isHidden && defaultsButton.isHidden
    }

    private var controlsMayChange: Bool {
        writesAllowed && !(requiresExplicitRecovery && recoverySubmitted)
    }

    private func renderFeedback() {
        for (label, feedback) in [(loadStatusLabel, loadFeedback),
                                  (statusLabel, receiptFeedback), (draftStatusLabel, draftFeedback)] {
            let message = feedback.map { feedbackText($0.key) } ?? ""
            label.stringValue = message
            label.setAccessibilityLabel(message)
            label.setAccessibilityValue(message)
            label.isHidden = feedback == nil
            label.textColor = feedback?.color ?? .secondaryLabelColor
        }
    }

    private func feedbackText(_ key: MainGridCapacityTextKey) -> String {
        // Keep established receipt keys internally, while removing legacy Apply
        // instructions from every live error/recovery surface.
        switch key {
        case .loadCorrupt, .recoveryRequired: return strings.liveAppearanceText(.recoveryRequired)
        case .loadProtected: return strings.liveAppearanceText(.protected)
        case .unavailable: return strings.liveAppearanceText(.unavailable)
        case .saveFailed: return strings.liveAppearanceText(requiresExplicitRecovery ? .recoveryFailed : .saveFailed)
        default: return strings.mainGridCapacityText(key)
        }
    }
}

private final class MainGridCapacitySettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}
