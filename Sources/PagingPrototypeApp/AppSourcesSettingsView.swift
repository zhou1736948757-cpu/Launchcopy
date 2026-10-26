import AppKit
import LauncherLocalization

/// Independent draft. No scan/persistence work is performed by native controls.
@MainActor
public final class AppSourcesSettingsView: NSView {
    public private(set) var strings: LocalizedStrings
    public var onAdmit: ((URL) async -> AppSourceRootAdmissionResult)?
    public var onApply: ((AppSourcesPreferences) async -> AppSourcesApplyResult)?
    public var onRefresh: (() -> Void)?
    public private(set) var draft = AppSourcesPreferences.default
    let rootsPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    let automaticCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    let addButton = NSButton(title: "", target: nil, action: nil)
    let removeButton = NSButton(title: "", target: nil, action: nil)
    let applyButton = NSButton(title: "", target: nil, action: nil)
    let refreshButton = NSButton(title: "", target: nil, action: nil)
    let fixedCaption = NSTextField(labelWithString: "")
    let extraCaption = NSTextField(labelWithString: "")
    let helpLabel = NSTextField(wrappingLabelWithString: "")
    let statusLabel = NSTextField(wrappingLabelWithString: "")
    let watchLabel = NSTextField(wrappingLabelWithString: "")
    private let fixedLabel = NSTextField(wrappingLabelWithString: "")
    private var readOnly = false
    private var operation: Task<Void, Never>?
    private var operationGeneration: UInt64 = 0
    private var openPanel: NSOpenPanel?
    private var panelOwnershipRelease: (() -> Void)?
    public var acquireModalOwnership: (() -> (() -> Void))?
    var panelPresenter: (NSOpenPanel, NSWindow, @escaping (NSApplication.ModalResponse) -> Void) -> Void = {
        panel, window, finish in panel.beginSheetModal(for: window, completionHandler: finish)
    }
    private var busy = false
    public var onPresentationOwnershipChange: (() -> Void)?
    /// Sources has no editable text control. Panel filename IME is covered by panel ownership.
    public var hasPresentationOwnership: Bool { openPanel != nil || busy }
    private var lastReportedPresentationOwnership = false
    private var watchStatus: AppSourceWatchStatus = .disabled

    public override convenience init(frame frameRect: NSRect) {
        self.init(frame: frameRect, strings: LocalizedStrings(language: .simplifiedChinese))
    }

    public init(frame frameRect: NSRect, strings: LocalizedStrings) {
        self.strings = strings
        super.init(frame: frameRect)
        let controls: [(NSControl, String, Selector)] = [
            (rootsPopup, "sources.root", #selector(selectionChanged(_:))),
            (automaticCheckbox, "sources.automatic", #selector(automaticChanged(_:))),
            (addButton, "sources.add", #selector(addClicked(_:))),
            (removeButton, "sources.remove", #selector(removeClicked(_:))),
            (applyButton, "sources.apply", #selector(applyClicked(_:))),
            (refreshButton, "sources.refresh", #selector(refreshClicked(_:)))
        ]
        for (control, id, selector) in controls {
            control.target = self; control.action = selector
            control.identifier = NSUserInterfaceItemIdentifier(id)
        }
        // Paths are unbounded content, not a minimum Settings window width.
        // Keep complete menu titles and represented identities; compress only
        // the closed control's presentation within its available row.
        rootsPopup.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        rootsPopup.cell?.lineBreakMode = .byTruncatingMiddle
        rootsPopup.setAccessibilityLabel(strings.settingsText(.sourcesRootAccessibility))
        automaticCheckbox.setAccessibilityLabel(strings.settingsText(.sourcesAutomatic))
        helpLabel.textColor = .secondaryLabelColor
        let actions = NSStackView(views: [addButton, removeButton]); actions.spacing = 12
        let applyRow = NSStackView(views: [applyButton, refreshButton]); applyRow.spacing = 12
        let stack = NSStackView(views: [fixedCaption, fixedLabel, extraCaption, rootsPopup, actions,
                                       automaticCheckbox, applyRow, watchLabel, helpLabel, statusLabel])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false; addSubview(scroll)
        let document = AppSourcesDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        stack.translatesAutoresizingMaskIntoConstraints = false; document.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            document.heightAnchor.constraint(greaterThanOrEqualTo: scroll.contentView.heightAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24),
            rootsPopup.widthAnchor.constraint(equalTo: stack.widthAnchor),
            fixedLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            helpLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            watchLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        relabel(strings: strings)
        reload(preferences: .default, fixedRoots: [], watchStatus: .disabled)
    }
    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public func reload(preferences: AppSourcesPreferences, fixedRoots: [URL],
                       loadResult: AppSourcesLoadResult? = nil, watchStatus: AppSourceWatchStatus) {
        cancelPendingOperations()
        draft = preferences
        if case .futureVersion? = loadResult { readOnly = true } else { readOnly = false }
        fixedLabel.stringValue = fixedRoots.map(\.path).joined(separator: "\n")
        syncControls(); updateWatchStatus(watchStatus)
        if readOnly { show(.sourcesLoadFuture, error: true) }
        else if case .corrupt? = loadResult { show(.sourcesLoadCorrupt, error: true) }
        else { feedback = nil; renderFeedback() }
    }
    public func updateWatchStatus(_ status: AppSourceWatchStatus) {
        watchStatus = status
        renderWatchStatus()
    }
    private func renderWatchStatus() {
        switch watchStatus {
        case .active: watchLabel.stringValue = strings.settingsText(.sourcesWatchActive)
        case .disabled: watchLabel.stringValue = strings.settingsText(.sourcesWatchDisabled)
        case .unavailable: watchLabel.stringValue = strings.settingsText(.sourcesWatchUnavailable)
        case .degraded: watchLabel.stringValue = strings.settingsText(.sourcesWatchDegraded)
        }
        watchLabel.setAccessibilityLabel(watchLabel.stringValue)
    }
    public func cancelPendingOperations() {
        operationGeneration &+= 1; operation?.cancel(); operation = nil
        let release = panelOwnershipRelease; panelOwnershipRelease = nil
        release?()
        openPanel?.cancel(nil); openPanel = nil; busy = false
        updateEnabled()
        notifyPresentationOwnershipChange()
    }
    private func syncControls() {
        let selected = rootsPopup.selectedItem?.representedObject as? String
        rootsPopup.removeAllItems(); rootsPopup.addItem(withTitle: strings.settingsText(.sourcesSelectRoot))
        for path in draft.customRootPaths {
            rootsPopup.addItem(withTitle: path); rootsPopup.lastItem?.representedObject = path
        }
        for item in rootsPopup.itemArray { item.setAccessibilityLabel(item.title) }
        if let selected, let index = draft.customRootPaths.firstIndex(of: selected) {
            rootsPopup.selectItem(at: index + 1)
        }
        automaticCheckbox.state = draft.automaticRefreshEnabled ? .on : .off
        updateEnabled()
    }
    private func updateEnabled() {
        for control in [rootsPopup, automaticCheckbox, addButton, applyButton] as [NSControl] {
            control.isEnabled = !readOnly && !busy
        }
        removeButton.isEnabled = !readOnly && !busy && rootsPopup.selectedItem?.representedObject is String
        refreshButton.isEnabled = !busy && onRefresh != nil
    }
    @objc func selectionChanged(_ sender: Any?) { updateEnabled() }
    @objc func automaticChanged(_ sender: Any?) {
        guard !readOnly, !busy else { return }
        draft.automaticRefreshEnabled = automaticCheckbox.state == .on
        feedback = nil
        renderFeedback()
    }
    @objc func removeClicked(_ sender: Any?) {
        guard !readOnly, !busy, let path = rootsPopup.selectedItem?.representedObject as? String else { return }
        draft.customRootPaths.removeAll { $0 == path }; syncControls()
        show(.sourcesRemovedDraft, error: false)
    }
    @objc func refreshClicked(_ sender: Any?) { onRefresh?() }
    @objc func addClicked(_ sender: Any?) {
        guard !readOnly, !busy, openPanel == nil, let window else { return }
        let panel = makeOpenPanel()
        openPanel = panel
        busy = true; updateEnabled()
        let generation = operationGeneration
        let rawRelease = acquireModalOwnership?()
        let gate = ApplicationSheetCompletionGate()
        let release: () -> Void = { if gate.claim() { rawRelease?() } }
        panelOwnershipRelease = release
        let completionGate = ApplicationSheetCompletionGate()
        panelPresenter(panel, window) { [weak self, weak panel] response in
            guard completionGate.claim() else { return }
            defer { release() }
            guard let self, generation == self.operationGeneration else { return }
            self.panelOwnershipRelease = nil
            self.openPanel = nil; self.busy = false; self.updateEnabled()
            if response == .OK, let url = panel?.url { self.addDraftRoot(url) }
            self.notifyPresentationOwnershipChange()
        }
        notifyPresentationOwnershipChange()
    }
    /// Shared by the real add action; construction alone does not present a sheet.
    func makeOpenPanel() -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false
        panel.allowsMultipleSelection = false; panel.resolvesAliases = false
        panel.treatsFilePackagesAsDirectories = false
        panel.prompt = strings.settingsText(.sourcesPanelPrompt)
        return panel
    }

    /// Same action path for tests and the explicitly selected panel URL.
    func addDraftRoot(_ url: URL) {
        guard !readOnly, !busy, let onAdmit else { return }
        busy = true; updateEnabled(); let generation = operationGeneration
        operation = Task { [weak self] in
            let result = await onAdmit(url)
            guard let self, generation == self.operationGeneration, !Task.isCancelled else { return }
            self.operation = nil; self.busy = false
            switch result {
            case .accepted(let root):
                if !self.draft.customRootPaths.contains(root.path) { self.draft.customRootPaths.append(root.path) }
                self.syncControls(); self.show(.sourcesAddedDraft, error: false)
            case .alreadyCovered: self.show(.sourcesAlreadyCovered, error: false)
            case .rejected: self.show(.sourcesRejected, error: true)
            }
            self.updateEnabled()
            self.notifyPresentationOwnershipChange()
        }
        notifyPresentationOwnershipChange()
    }
    @objc func applyClicked(_ sender: Any?) {
        guard !readOnly, !busy, let onApply else { return }
        busy = true; updateEnabled(); let generation = operationGeneration; let submitted = draft
        operation = Task { [weak self] in
            let result = await onApply(submitted)
            guard let self, generation == self.operationGeneration, !Task.isCancelled else { return }
            self.operation = nil; self.busy = false; self.updateEnabled()
            switch result {
            case .saved: self.show(.sourcesSaved, error: false)
            case .futureVersion: self.show(.sourcesSaveFuture, error: true)
            case .invalidRoot: self.show(.sourcesInvalidRoot, error: true)
            case .failed: self.show(.sourcesSaveFailed, error: true)
            case .superseded: self.show(.sourcesSuperseded, error: true)
            }
            self.notifyPresentationOwnershipChange()
        }
        notifyPresentationOwnershipChange()
    }
    private struct Feedback {
        let key: SettingsTextKey
        let isError: Bool
    }
    private var feedback: Feedback?

    private func show(_ key: SettingsTextKey, error: Bool) {
        feedback = Feedback(key: key, isError: error)
        renderFeedback()
    }

    private func renderFeedback() {
        let message = feedback.map { strings.settingsText($0.key) } ?? ""
        statusLabel.stringValue = message
        statusLabel.setAccessibilityLabel(message)
        statusLabel.isHidden = feedback == nil
        if let feedback { statusLabel.textColor = feedback.isError ? .systemRed : .systemGreen }
    }

    private func notifyPresentationOwnershipChange() {
        let owned = hasPresentationOwnership
        guard owned != lastReportedPresentationOwnership else { return }
        lastReportedPresentationOwnership = owned
        onPresentationOwnershipChange?()
    }

    /// Does not rebuild popup items, cancel tasks, advance generations or change roots.
    public func relabel(strings: LocalizedStrings) {
        self.strings = strings
        rootsPopup.setAccessibilityLabel(strings.settingsText(.sourcesRootAccessibility))
        // AppKit's optional item result does not make an out-of-range index safe.
        // Construction relabels before reload has populated the placeholder.
        if rootsPopup.numberOfItems > 0 {
            rootsPopup.item(at: 0)?.title = strings.settingsText(.sourcesSelectRoot)
        }
        for item in rootsPopup.itemArray { item.setAccessibilityLabel(item.title) }
        for (button, key) in [(automaticCheckbox, SettingsTextKey.sourcesAutomatic),
                              (addButton, .sourcesAdd), (removeButton, .sourcesRemove),
                              (applyButton, .sourcesApply), (refreshButton, .sourcesRefresh)] {
            button.title = strings.settingsText(key)
            button.setAccessibilityLabel(button.title)
        }
        for (label, key) in [(fixedCaption, SettingsTextKey.sourcesFixedCaption),
                             (extraCaption, .sourcesExtraCaption), (helpLabel, .sourcesHelp)] {
            label.stringValue = strings.settingsText(key)
            label.setAccessibilityLabel(label.stringValue)
        }
        // Normally the owner defers relabel until this panel closes. This is text-only
        // even if called directly while the native sheet is still presented.
        openPanel?.prompt = strings.settingsText(.sourcesPanelPrompt)
        renderWatchStatus()
        renderFeedback()
    }

}

/// Native scrolling keeps long source paths and status messages reachable in small windows.
private final class AppSourcesDocumentView: NSView {
    override var isFlipped: Bool { true }
}
