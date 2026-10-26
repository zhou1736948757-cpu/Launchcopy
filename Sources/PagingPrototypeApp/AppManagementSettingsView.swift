import AppCatalogCore
import AppGridUI
import AppKit
import LauncherLocalization

/// Canonical catalog list: hidden apps remain selectable and no icons are loaded.
@MainActor
public final class AppManagementSettingsView: NSView {
    public private(set) var strings: LocalizedStrings
    public var onSetHidden: ((AppRecord, Bool) -> AppManagementSaveResult)?
    public var onSetAlias: ((AppRecord, String?) -> AppManagementSaveResult)?
    public var onRestoreAll: (() -> AppManagementSaveResult)?
    public var onSetSearchByBundleIdentifier: ((Bool) -> AppManagementSaveResult)?
    public var identifierSearchPendingProvider: (() -> Bool)?
    private var records: [AppRecord] = []
    private var preferences = AppManagementPreferences.default
    let appPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let hiddenCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let aliasField = NSTextField()
    let saveAliasButton = NSButton(title: "", target: nil, action: nil)
    let clearAliasButton = NSButton(title: "", target: nil, action: nil)
    let restoreAllButton = NSButton(title: "", target: nil, action: nil)
    let helpLabel = NSTextField(wrappingLabelWithString: "")
    let statusLabel = NSTextField(wrappingLabelWithString: "")
    let identifierSearchCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let identifierSearchHelpLabel = NSTextField(wrappingLabelWithString: "")
    let identifierSearchStatusLabel = NSTextField(wrappingLabelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")
    private var readOnly = false
    // Corrupt metadata may still be explicitly repaired by the legacy controls.
    // This global policy toggle must never perform that repair implicitly.
    private var identifierSearchReadOnly = false
    private var identifierSearchFeedback: Feedback?

    public override convenience init(frame frameRect: NSRect) {
        self.init(frame: frameRect, strings: LocalizedStrings(language: .simplifiedChinese))
    }

    public init(frame frameRect: NSRect, strings: LocalizedStrings) {
        self.strings = strings
        super.init(frame: frameRect)
        appPopup.target = self
        appPopup.action = #selector(selectionChanged(_:))
        appPopup.setAccessibilityLabel(settingsText(.managementAppAccessibility))
        appPopup.identifier = NSUserInterfaceItemIdentifier("management.app")
        hiddenCheckbox.target = self
        hiddenCheckbox.action = #selector(hiddenChanged(_:))
        hiddenCheckbox.identifier = NSUserInterfaceItemIdentifier("management.hidden")
        aliasField.placeholderString = settingsText(.managementAliasPlaceholder)
        aliasField.setAccessibilityLabel(settingsText(.managementAliasAccessibility))
        aliasField.identifier = NSUserInterfaceItemIdentifier("management.alias")
        saveAliasButton.target = self
        saveAliasButton.action = #selector(saveAlias(_:))
        clearAliasButton.target = self
        clearAliasButton.action = #selector(clearAlias(_:))
        restoreAllButton.target = self
        restoreAllButton.action = #selector(restoreAll(_:))
        identifierSearchCheckbox.target = self
        identifierSearchCheckbox.action = #selector(identifierSearchChanged(_:))
        identifierSearchCheckbox.identifier = NSUserInterfaceItemIdentifier("management.search-identifiers")
        identifierSearchHelpLabel.identifier = NSUserInterfaceItemIdentifier("management.search-identifiers.help")
        identifierSearchStatusLabel.identifier = NSUserInterfaceItemIdentifier("management.search-identifiers.status")
        identifierSearchHelpLabel.textColor = .secondaryLabelColor
        identifierSearchHelpLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        identifierSearchStatusLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        let identifierSearch = NSStackView(views: [identifierSearchCheckbox, identifierSearchHelpLabel,
                                                   identifierSearchStatusLabel])
        identifierSearch.orientation = .vertical
        identifierSearch.alignment = .leading
        identifierSearch.spacing = 6
        let aliases = NSStackView(views: [saveAliasButton, clearAliasButton])
        aliases.orientation = .horizontal
        aliases.spacing = 12
        helpLabel.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [identifierSearch, appPopup, hiddenCheckbox, aliasField, aliases,
                                       restoreAllButton, countLabel, helpLabel, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -24),
            identifierSearch.widthAnchor.constraint(equalTo: stack.widthAnchor),
            identifierSearchHelpLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            identifierSearchStatusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            appPopup.widthAnchor.constraint(equalTo: stack.widthAnchor),
            aliasField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            helpLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        relabel(strings: strings)
        reload(records: [], preferences: .default)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public var selectedRecord: AppRecord? {
        guard let selected = appPopup.selectedItem?.representedObject as? AppRecord else { return nil }
        return records.first { $0.id == selected.id }
    }

    internal private(set) var staticTemplateReadCount = 0
    internal private(set) var countTemplateRenderCount = 0

    private func settingsText(_ key: SettingsTextKey) -> String {
        staticTemplateReadCount += 1
        return strings.settingsText(key)
    }

    private func hiddenReferenceText(_ count: Int) -> String {
        countTemplateRenderCount += 1
        return strings.hiddenReferenceCount(count)
    }

    /// Catalog-only refresh keeps an unfinished alias draft for the same selected app.
    /// The owner waits for field-editor/menu/modal ownership to finish before calling.
    public func refreshCatalog(records: [AppRecord], preferences: AppManagementPreferences,
                               loadResult: AppManagementLoadResult? = nil) {
        let selectedID = selectedRecord?.id
        let aliasDraft = aliasField.stringValue
        let acceptedAlias = selectedRecord.flatMap { self.preferences.alias(for: $0) } ?? ""
        let hasUnfinishedDraft = aliasDraft != acceptedAlias
        reload(records: records, preferences: preferences, loadResult: loadResult)
        if hasUnfinishedDraft, let selectedID, selectedRecord?.id == selectedID {
            aliasField.stringValue = aliasDraft
        }
    }

    public func reload(records: [AppRecord], preferences: AppManagementPreferences,
                       loadResult: AppManagementLoadResult? = nil) {
        let selectedID = selectedRecord?.id
        self.records = records
        self.preferences = preferences
        readOnly = false
        if case .futureVersion? = loadResult { readOnly = true }
        identifierSearchReadOnly = readOnly
        if case .corrupt? = loadResult { identifierSearchReadOnly = true }
        identifierSearchCheckbox.isEnabled = !identifierSearchReadOnly
        identifierSearchCheckbox.state = preferences.searchByBundleIdentifier ? .on : .off
        if readOnly {
            identifierSearchFeedback = Feedback(key: .managementIdentifierSearchFuture, isError: true)
        } else if case .corrupt? = loadResult {
            identifierSearchFeedback = Feedback(key: .managementIdentifierSearchCorrupt, isError: true)
        } else if let isPending = identifierSearchPendingProvider?() {
            identifierSearchFeedback = Feedback(key: isPending ? .managementIdentifierSearchQueued :
                                                .managementIdentifierSearchApplied, isError: false)
        } else {
            identifierSearchFeedback = nil
        }
        appPopup.removeAllItems()
        appPopup.addItem(withTitle: settingsText(.managementSelectApp))
        for record in records {
            let name = preferences.displayName(for: record)
            let title = name == record.displayName ? name : "\(name) — \(record.displayName)"
            let item = NSMenuItem(title: preferences.isHidden(record) ? title + settingsText(.managementHiddenSuffix) : title,
                                  action: nil, keyEquivalent: "")
            item.representedObject = record
            appPopup.menu?.addItem(item)
        }
        if let selectedID, let index = records.firstIndex(where: { $0.id == selectedID }) {
            appPopup.selectItem(at: index + 1)
        } else { appPopup.selectItem(at: 0) }
        countLabel.stringValue = hiddenReferenceText(preferences.hiddenKeys.count)
        restoreAllButton.isEnabled = !readOnly && !preferences.hiddenKeys.isEmpty
        selectionChanged(nil)
        relabel(strings: strings)
        if readOnly { showMessage(.managementLoadFuture, error: true) }
        else if case .corrupt? = loadResult { showMessage(.managementLoadCorrupt, error: true) }
        else { feedback = nil; renderFeedback() }
    }

    /// Refresh only the latest committed policy and its presentation receipt.
    /// Do not rebuild the menu, replace an alias draft/editor or clear alias feedback.
    public func refreshIdentifierSearchState(storedEnabled: Bool, isPending: Bool) {
        preferences.searchByBundleIdentifier = storedEnabled
        identifierSearchCheckbox.state = storedEnabled ? .on : .off
        if !identifierSearchReadOnly {
            identifierSearchFeedback = Feedback(key: isPending ? .managementIdentifierSearchQueued :
                                                .managementIdentifierSearchApplied, isError: false)
        }
        renderIdentifierSearchFeedback()
    }

    @objc func identifierSearchChanged(_ sender: Any?) {
        let storedEnabled = preferences.searchByBundleIdentifier
        guard !identifierSearchReadOnly else {
            identifierSearchCheckbox.state = storedEnabled ? .on : .off
            return
        }
        let requested = identifierSearchCheckbox.state == .on
        let result = onSetSearchByBundleIdentifier?(requested) ?? .failed
        switch result {
        case .saved:
            preferences.searchByBundleIdentifier = requested
            identifierSearchCheckbox.state = requested ? .on : .off
            // Saving acknowledges storage only. Without an owner receipt, do not
            // claim that the current presentation has already accepted the policy.
            let isPending = identifierSearchPendingProvider?() ?? true
            identifierSearchFeedback = Feedback(key: isPending ? .managementIdentifierSearchQueued :
                                                .managementIdentifierSearchApplied, isError: false)
        case .futureVersion:
            identifierSearchReadOnly = true
            identifierSearchCheckbox.isEnabled = false
            identifierSearchCheckbox.state = storedEnabled ? .on : .off
            identifierSearchFeedback = Feedback(key: .managementIdentifierSearchFuture, isError: true)
        case .failed, .invalidPreferences:
            identifierSearchCheckbox.state = storedEnabled ? .on : .off
            identifierSearchFeedback = Feedback(key: .managementIdentifierSearchFailed, isError: true)
        }
        renderIdentifierSearchFeedback()
    }

    @objc func selectionChanged(_ sender: Any?) {
        let selected = selectedRecord
        hiddenCheckbox.state = selected.map { preferences.isHidden($0) ? .on : .off } ?? .off
        aliasField.stringValue = selected.flatMap { preferences.alias(for: $0) } ?? ""
        for control in [hiddenCheckbox, aliasField, saveAliasButton, clearAliasButton] as [NSControl] {
            control.isEnabled = selected != nil && !readOnly
        }
    }
    @objc func hiddenChanged(_ sender: Any?) {
        guard !readOnly, let selected = selectedRecord else { return }
        let requestedHidden = hiddenCheckbox.state == .on
        let result = onSetHidden?(selected, requestedHidden) ?? .failed
        show(result)
        // Accepted state remains visible while the catalog-only refresh is queued.
        // Failed persistence must not leave the checkbox implying an applied change.
        if result == .saved {
            preferences = preferences.settingHidden(requestedHidden, for: selected)
        } else if selectedRecord?.id == selected.id {
            hiddenCheckbox.state = preferences.isHidden(selected) ? .on : .off
        }
    }
    @objc func saveAlias(_ sender: Any?) {
        guard !readOnly, let selected = selectedRecord else { return }
        let result = onSetAlias?(selected, aliasField.stringValue) ?? .failed
        if result == .saved, selectedRecord?.id == selected.id {
            preferences = preferences.settingAlias(aliasField.stringValue, for: selected) ?? preferences
            aliasField.stringValue = preferences.alias(for: selected) ?? ""
        }
        show(result)
    }
    @objc func clearAlias(_ sender: Any?) {
        guard !readOnly, let selected = selectedRecord else { return }
        let result = onSetAlias?(selected, nil) ?? .failed
        if result == .saved, selectedRecord?.id == selected.id {
            preferences = preferences.settingAlias(nil, for: selected) ?? preferences
            aliasField.stringValue = ""
        }
        show(result)
    }
    @objc func restoreAll(_ sender: Any?) {
        guard !readOnly else { return }
        show(onRestoreAll?() ?? .failed)
    }
    private func show(_ result: AppManagementSaveResult) {
        switch result {
        case .saved: showMessage(.managementSaved, error: false)
        case .invalidPreferences: showMessage(.managementInvalidAlias, error: true)
        case .futureVersion: showMessage(.managementSaveFuture, error: true)
        case .failed: showMessage(.managementSaveFailed, error: true)
        }
    }
    private struct Feedback {
        let key: SettingsTextKey
        let isError: Bool
    }
    private var feedback: Feedback?

    private func showMessage(_ key: SettingsTextKey, error: Bool) {
        feedback = Feedback(key: key, isError: error)
        renderFeedback()
    }

    private func renderFeedback() {
        let message = feedback.map { settingsText($0.key) } ?? ""
        statusLabel.stringValue = message
        statusLabel.setAccessibilityLabel(message)
        statusLabel.isHidden = feedback == nil
        if let feedback { statusLabel.textColor = feedback.isError ? .systemRed : .systemGreen }
    }

    private func renderIdentifierSearchFeedback() {
        let message = identifierSearchFeedback.map { settingsText($0.key) } ?? ""
        identifierSearchStatusLabel.stringValue = message
        identifierSearchStatusLabel.setAccessibilityLabel(message)
        identifierSearchStatusLabel.isHidden = identifierSearchFeedback == nil
        if let feedback = identifierSearchFeedback {
            identifierSearchStatusLabel.textColor = feedback.isError ? .systemRed :
                (feedback.key == .managementIdentifierSearchQueued ? .secondaryLabelColor : .systemGreen)
        }
    }

    /// Keep menu identities and the actual field editor (including IME text) intact.
    public func relabel(strings: LocalizedStrings) {
        self.strings = strings
        appPopup.setAccessibilityLabel(settingsText(.managementAppAccessibility))
        for item in appPopup.itemArray {
            if let record = item.representedObject as? AppRecord {
                let name = preferences.displayName(for: record)
                let title = name == record.displayName ? name : "\(name) — \(record.displayName)"
                item.title = preferences.isHidden(record) ? title + settingsText(.managementHiddenSuffix) : title
            } else {
                item.title = settingsText(.managementSelectApp)
            }
            item.setAccessibilityLabel(item.title)
        }
        for (button, key) in [(hiddenCheckbox, SettingsTextKey.managementHideSelected),
                              (identifierSearchCheckbox, .managementSearchIdentifiers),
                              (saveAliasButton, .managementSaveAlias),
                              (clearAliasButton, .managementClearAlias),
                              (restoreAllButton, .managementRestoreAll)] {
            button.title = settingsText(key)
            button.setAccessibilityLabel(button.title)
        }
        aliasField.placeholderString = settingsText(.managementAliasPlaceholder)
        aliasField.setAccessibilityLabel(settingsText(.managementAliasAccessibility))
        countLabel.stringValue = hiddenReferenceText(preferences.hiddenKeys.count)
        countLabel.setAccessibilityLabel(countLabel.stringValue)
        helpLabel.stringValue = settingsText(.managementHelp)
        helpLabel.setAccessibilityLabel(helpLabel.stringValue)
        identifierSearchHelpLabel.stringValue = settingsText(.managementIdentifierSearchHelp)
        identifierSearchHelpLabel.setAccessibilityLabel(identifierSearchHelpLabel.stringValue)
        identifierSearchCheckbox.setAccessibilityHelp(identifierSearchHelpLabel.stringValue)
        identifierSearchCheckbox.toolTip = identifierSearchHelpLabel.stringValue
        renderIdentifierSearchFeedback()
        renderFeedback()
    }

}
