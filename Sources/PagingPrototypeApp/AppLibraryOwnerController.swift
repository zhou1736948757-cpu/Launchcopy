import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import LauncherLocalization

/// Optional same-window mode owner. The shared catalog, window and actions remain
/// application-owned; no second scanner, pager, persistence file or global hook.
@MainActor
final class AppLibraryOwnerController: NSObject {
    var entryProfile: LibraryEntryProfile?
    let preferences: AppLibraryPreferencesCoordinator
    let activity: LaunchActivityCoordinator?
    private(set) var isOpen = false
    private(set) var isPreviewing = false
    /// A committed pane with no projection work; independent of keyboard focus.
    var hasSettledPresentation: Bool {
        isOpen && !isPreviewing && !isClosing && !projection.isProjecting && projection.snapshot != nil
    }
    private(set) var view: AppLibraryView?
    private(set) var actionGeneration: UInt64 = 0
    private(set) var entryButton: NSButton?
    private var returnContext: AppLibraryGridReturnContext?
    private weak var host: NSView?
    private weak var settingsView: AppLibrarySettingsView?
    private let iconPipeline: IconPipeline?
    private var strings: LocalizedStrings
    private let projection: AppLibraryProjectionController
    private var isActive = true
    private var isClosing = false
    private var invalidatedSourceRevision: CatalogRevision?
    private var sourceRefreshFailed = false
    private var catalogRefreshState: AppGridUIState = .loading
    private var startupTask: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private var preparationGeneration: UInt64 = 0
    private var preparedView: AppLibraryView?
    private struct PreparationKey: Equatable {
        let revision: CatalogRevision
        let management: AppManagementPreferences
        let preferences: AppLibraryPreferences
        let language: InterfaceLanguage
    }
    private var preparedKey: PreparationKey?
    private let displayWarmup = LibraryIdleDisplayWarmup()
    private struct DisplayPreparationKey: Equatable {
        let frame: NSRect
        let scale: Double
        let appearance: NSAppearance.Name
        let reduceTransparency: Bool
        let increaseContrast: Bool
        let activitySectionsEnabled: Bool
    }
    private var preparedDisplayKey: DisplayPreparationKey?
    private var currentDisplayKey: DisplayPreparationKey? {
        guard let host, let window = host.window, window.isVisible, !window.isMiniaturized,
              host.bounds.width.isFinite, host.bounds.height.isFinite,
              host.bounds.width > 0, host.bounds.height > 0 else { return nil }
        return .init(frame: presentationFrame(in: host), scale: Double(window.backingScaleFactor),
            appearance: host.effectiveAppearance.name,
            reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
            increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast,
            activitySectionsEnabled: activitySectionsEnabled)
    }
    /// Only missing layer backings are prepared; never hide, translate or display
    /// the live grid to simulate a compositor warm-up.
    var prepareGridLayerBackings: () -> Int = { 0 }
    var hasPreparedDisplay: Bool {
        preparedDisplayKey != nil && preparedDisplayKey == currentDisplayKey
            && preparedKey == currentPreparationKey && hasPreparedCards
    }
    var hasPreparedCards: Bool { preparedView?.galleryView.hasPreparedCards == true }
    private var currentPreparationKey: PreparationKey? {
        guard let catalog = catalogProvider() else { return nil }
        return .init(revision: catalog.revision, management: managementProvider(),
            preferences: preferences.committed, language: strings.language)
    }
    private(set) var presentationConstructionCount = 0
    var hasPreparedPresentation: Bool { preparedView != nil }
    private var sessionGeneration: UInt64 = 0
    private var pendingCategorySession: UInt64?
    private var lastSearchFrame: NSRect?
    private var pendingLibraryEnabled: Bool?
    private var needsActivityProjection = false
    private var isHandlingEscape = false
    var onActivityClearRequested: (() -> Void)?
    var onActivityRecoveryRequested: (() -> Void)?
    /// Semantic presentation and preference changes, never projection frames.
    var onPresentationChange: (() -> Void)?
    /// Cancel parent navigation before readiness checks. Cancellation may discard
    /// a preview synchronously; committed close remains owned by this controller.
    var onBeforeBack: (() -> Void)?

    var catalogProvider: () -> CatalogSnapshot? = { nil }
    var managementProvider: () -> AppManagementPreferences = { .default }
    var canTransition: () -> Bool = { false }
    /// Preparation must also yield to held parent input, without denying navigation.
    var canPrepare: () -> Bool = { true }
    var canExecuteAction: () -> Bool = { false }
    var captureGrid: () -> AppLibraryGridReturnContext? = { nil }
    var prepareEntry: () -> Void = {}
    var setGridHidden: (Bool) -> Void = { _ in }
    var restoreGrid: (AppLibraryGridReturnContext) -> Void = { _ in }
    var onReadinessChange: () -> Void = {}
    var onRecoveryRequested: () -> Void = {}
    var onCategorySaveFailure: () -> Void = {}
    var openApp: (AppLibraryActionRequest, AppRecord) -> Void = { _, _ in }
    /// External actions are unavailable in the dedicated physical-gesture harness.
    var allowsExternalApplicationActions = true {
        didSet { view?.allowsExternalApplicationActions = allowsExternalApplicationActions }
    }
    var allowsApplicationRemoval = true {
        didSet { view?.allowsApplicationRemoval = allowsApplicationRemoval }
    }
    var revealApp: (AppRecord) -> Void = { _ in }
    var setHidden: (AppRecord, Bool) -> Void = { _, _ in }
    var editAlias: (AppLibraryActionRequest, AppRecord) -> Void = { _, _ in }
    var assignFolder: (AppLibraryActionRequest, AppRecord) -> Void = { _, _ in }
    var moveToTrash: (AppLibraryActionRequest, AppRecord) -> Void = { _, _ in }

    init(preferences: AppLibraryPreferencesCoordinator, strings: LocalizedStrings,
         iconPipeline: IconPipeline? = nil, projection: AppLibraryProjectionController? = nil,
         activity: LaunchActivityCoordinator? = nil) {
        self.preferences = preferences
        self.activity = activity
        self.strings = strings
        self.iconPipeline = iconPipeline
        self.projection = projection ?? AppLibraryProjectionController()
        super.init()
        preferences.onChange = { [weak self] in self?.preferencesChanged() }
        self.projection.onChange = { [weak self] in self?.renderProjection() }
        activity?.onChange = { [weak self] in self?.activityChanged() }
    }

    func attach(to host: NSView, showsEntryButton: Bool = true) {
        self.host = host
        if showsEntryButton {
            let button = NSButton(title: strings.libraryText(.title), target: self, action: #selector(enterFromButton(_:)))
            button.bezelStyle = .rounded
            button.identifier = .init("library.entry")
            button.setAccessibilityLabel(strings.libraryText(.title))
            button.isHidden = true
            host.addSubview(button)
            entryButton = button
        }
        startupTask = Task { [weak self] in
            guard let self else { return }
            await self.preferences.loadIfNeeded()
            await self.activity?.loadIfNeeded()
            guard self.isActive else { return }
            self.startupTask = nil
            self.preferencesChanged()
        }
    }

    func configureSettings(_ view: AppLibrarySettingsView) {
        settingsView = view
        view.onSetEnabled = { [weak self] enabled in
            guard let self, self.isActive, self.canTransition(), self.preferences.pendingCount == 0 else { return false }
            var draft = self.preferences.committed
            draft.enabled = enabled
            self.pendingLibraryEnabled = enabled
            if !enabled {
                self.activity?.setLibraryEnabled(false)
                // A failed Library preference receipt must never reinstate an
                // opted-out tracker. Preserve the history, not its ON admission.
                _ = self.activity?.setEnabled(false)
            }
            let accepted = self.preferences.submit(draft)
            if !accepted { self.pendingLibraryEnabled = nil; self.activity?.setLibraryEnabled(self.preferences.committed.enabled) }
            return accepted
        }
        view.onRecover = { [weak self] in self?.onRecoveryRequested() }
        view.activitySettingsView.onSetEnabled = { [weak self] enabled in
            guard let self, self.isActive, self.canTransition() else { return }
            _ = self.activity?.setEnabled(enabled)
            self.renderActivitySettings()
        }
        view.activitySettingsView.onClear = { [weak self] in self?.onActivityClearRequested?() }
        view.activitySettingsView.onRecover = { [weak self] in self?.onActivityRecoveryRequested?() }
        view.activitySettingsView.onRetry = { [weak self] in _ = self?.activity?.retry() }
        renderSettings()
    }

    @discardableResult
    func recoverPreferences() -> Bool {
        guard isActive, canTransition(), preferences.pendingCount == 0,
              preferences.loadResult == .corrupt || preferences.latestSaveResult == .recoveryRequired else { return false }
        return preferences.submit(.default, recoveringCorruptPayload: true)
    }

    /// Admission without capturing or changing the grid. The parent supplies
    /// transition readiness and owns any temporary root-layer translation.
    var canPreviewEntry: Bool {
        isActive && !isClosing && !isOpen && preferences.isLoaded && preferences.committed.enabled
            && preferences.pendingCount == 0 && invalidatedSourceRevision == nil
            && host != nil && canTransition()
    }

    @discardableResult
    func enter(preview: Bool = false) -> Bool {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let profile = entryProfile
        let profileStart = profile?.begin()
        defer { if let profileStart { profile?.end(.entry, since: profileStart, count: 0) } }
        guard canPreviewEntry,
              let host, let context = captureGrid() else { return false }
        if !preview {
            prepareEntry()
            // Closing a folder can synchronously commit a new catalog/lifecycle.
            guard isActive, canTransition() else { return false }
        }
        returnContext = context
        sessionGeneration &+= 1
        let session = sessionGeneration
        isOpen = true
        isPreviewing = preview
        cancelPreparation()
        let view = preparedView ?? makePresentation(frame: presentationFrame(in: host))
        preparedView = nil
        self.view = view
        view.appearance = nil // Inherit the live destination, not an idle appearance snapshot.
        view.frame = presentationFrame(in: host)
        // Recycled shells may have ended a canceled/translated parent transition.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        view.layer?.setAffineTransform(.identity)
        view.layer?.opacity = 1
        CATransaction.commit()
        view.setActivitySectionsEnabled(activitySectionsEnabled)
        view.setAccessibilityHidden(preview)
        // A preview cannot paint at identity before the parent installs its offset.
        view.isHidden = preview
        host.addSubview(view, positioned: .above, relativeTo: nil)
        view.autoresizingMask = [.width, .height]
        let searchFrame = lastSearchFrame ?? LauncherSearchHeader.frame(in: host.bounds)
        // Preserve the standalone owner's existing body frame when no host header
        // was supplied. The app composition always supplies its screen-safe frame.
        if lastSearchFrame != nil { layout(searchFrame: searchFrame) }
        view.mountSearchHeader(in: host, frame: searchFrame)
        if !preview {
            setGridHidden(true)
            guard isActive, isOpen, sessionGeneration == session, self.view === view else { return false }
            view.setSearchHeaderVisible(true)
        }
        refreshEntryState()
        refreshProjection()
        guard isActive, isOpen, sessionGeneration == session, self.view === view else { return false }
        if !preview { view.focusSearch() }
        onPresentationChange?()
        return true
    }

    /// Build a detached shell. Idle preparation may also attach a never-presented
    /// card pool; only a fresh live snapshot can consume it and grant any action.
    private func makePresentation(frame: NSRect) -> AppLibraryView {
        let profile = entryProfile
        let profileStart = profile?.begin()
        defer { if let profileStart { profile?.end(.shellConstruction, since: profileStart, count: 0) } }
        presentationConstructionCount += 1
        let view = AppLibraryView(frame: frame, strings: strings, iconPipeline: iconPipeline)
        view.allowsExternalApplicationActions = allowsExternalApplicationActions
        view.allowsApplicationRemoval = allowsApplicationRemoval
        view.entryProfile = entryProfile
        view.wantsLayer = true
        view.onBack = { [weak self] in self?.back() }
        view.onQueryChange = { [weak self] _ in self?.refreshProjection() }
        view.onCategoryChange = { [weak self] _ in self?.refreshProjection() }
        view.onActivitySectionChange = { [weak self] _ in self?.refreshProjection() }
        view.setActivitySectionsEnabled(activitySectionsEnabled)
        view.onPresentationOwnershipChange = { [weak self] in self?.onReadinessChange() }
        view.onOpen = { [weak self] request in
            guard let self, self.allowsExternalApplicationActions, let record = self.resolve(request) else { return }
            self.openApp(request, record)
        }
        view.onReveal = { [weak self] request in
            guard let self, self.allowsExternalApplicationActions, let record = self.resolve(request) else { return }
            self.revealApp(record)
        }
        view.onSetHidden = { [weak self] request, hidden in
            guard let self, let record = self.resolve(request) else { return }
            self.setHidden(record, hidden)
        }
        view.onEditAlias = { [weak self] request in
            guard let self, let record = self.resolve(request) else { return }
            self.editAlias(request, record)
        }
        view.onFolderAssignment = { [weak self] request in
            guard let self, let record = self.resolve(request) else { return }
            self.assignFolder(request, record)
        }
        view.onMoveToTrash = { [weak self] request in
            guard let self, self.allowsExternalApplicationActions, self.allowsApplicationRemoval,
                  let record = self.resolve(request) else { return }
            self.moveToTrash(request, record)
        }
        view.onSetCategory = { [weak self] request, category in
            guard let self, let record = self.resolve(request), self.preferences.pendingCount == 0 else { return }
            let draft = self.preferences.committed.settingCategory(category, for: record)
            self.pendingCategorySession = self.sessionGeneration
            _ = self.preferences.submit(draft)
        }
        return view
    }

    private var canPreparePresentation: Bool {
        isActive && !isClosing && !isOpen && preferences.isLoaded
            && preferences.committed.enabled && preferences.pendingCount == 0
            && invalidatedSourceRevision == nil && host != nil && canTransition() && canPrepare()
    }

    private func schedulePreparationIfReady() {
        guard preparationTask == nil, canPreparePresentation else { return }
        let key = currentPreparationKey
        let displayKey = currentDisplayKey
        if hasPreparedCards, preparedKey == key,
           displayKey == nil || preparedDisplayKey == displayKey { return }
        preparationGeneration &+= 1
        let token = preparationGeneration
        preparationTask = Task { [weak self] in
            guard let self else { return }
            // One slot, including canceled continuations; no fan-out during input.
            defer {
                self.preparationTask = nil
                if self.preparationGeneration != token || self.currentPreparationKey != key
                    || self.currentDisplayKey != displayKey {
                    self.schedulePreparationIfReady()
                }
            }
            await Task.yield()
            guard self.preparationGeneration == token, !Task.isCancelled,
                  self.canPreparePresentation, let host = self.host else { return }
            let prepared = self.preparedView ?? self.makePresentation(frame: self.presentationFrame(in: host))
            prepared.frame = self.presentationFrame(in: host)
            prepared.setAccessibilityHidden(true)
            prepared.setActivitySectionsEnabled(self.activitySectionsEnabled)
            // Detached roots do not receive the window's initial layout pass.
            prepared.needsLayout = true
            prepared.layoutSubtreeIfNeeded()
            self.preparedView = prepared
            guard let key, self.currentPreparationKey == key, let catalog = self.catalogProvider() else { return }
            if !prepared.galleryView.hasPreparedCards || self.preparedKey != key {
                self.preparedDisplayKey = nil // Readiness belongs to these particular controls.
                let request = AppLibraryProjectionRequest(catalog: catalog, management: key.management,
                    preferences: key.preferences, locale: Locale(identifier: key.language.rawValue))
                // Separate immutable projection: never grants a live action/session.
                let snapshot = await AppLibraryProjectionController.backgroundProjection(request)
                guard let snapshot, self.preparationGeneration == token, !Task.isCancelled,
                      self.canPreparePresentation, self.currentPreparationKey == key,
                      self.preparedView === prepared else { return }
                let completed = await prepared.galleryView.prepareCards(entries: snapshot.entries, strings: self.strings) { [weak self, weak prepared] in
                    guard let self, let prepared else { return false }
                    return self.preparationGeneration == token && !Task.isCancelled
                        && self.canPreparePresentation && self.currentPreparationKey == key
                        && self.preparedView === prepared
                }
                guard completed, self.preparationGeneration == token else { return }
                self.preparedKey = key
            }
            // Optional native drawing is not startup- or scroll-dispatch work.
            // Detached fixtures/hidden windows retain their old zero-icon contract.
            guard let displayKey else { return }
            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            let admitted: @MainActor () -> Bool = { [weak self, weak prepared] in
                guard let self, let prepared else { return false }
                return self.preparationGeneration == token && !Task.isCancelled
                    && self.canPreparePresentation && self.currentPreparationKey == key
                    && self.currentDisplayKey == displayKey && self.preparedView === prepared
                    && prepared.window == nil && prepared.galleryView.hasPreparedCards
            }
            guard admitted() else { return }
            let layersStart = self.entryProfile?.begin()
            let addedLayers = self.prepareGridLayerBackings()
            if let layersStart { self.entryProfile?.end(.idleLayerPreparation, since: layersStart, count: addedLayers) }
            guard admitted() else { return }
            prepared.appearance = host.effectiveAppearance
            let start = self.entryProfile?.begin()
            let completed = await prepared.galleryView.prepareDisplay(using: self.displayWarmup,
                pipeline: self.iconPipeline, displayScale: displayKey.scale,
                appearance: host.effectiveAppearance, shouldContinue: admitted)
            if let start { self.entryProfile?.end(.idleDisplay, since: start) }
            if completed, admitted() {
                self.preparedDisplayKey = displayKey
                self.entryProfile?.mark(.idleDisplayReady)
            }
        }
    }

    /// Real scroll input wins over optional pre-display, including a zero-delta
    /// began. Retain a completed inert pool; do not make navigation await a loader.
    func suspendPreparationForInput() {
        guard preparationTask != nil else { return }
        preparationGeneration &+= 1
        displayWarmup.cancel()
        preparationTask?.cancel()
    }

    private func cancelPreparation(discardingView: Bool = false) {
        preparationGeneration &+= 1
        displayWarmup.cancel()
        preparationTask?.cancel()
        preparedKey = nil
        preparedDisplayKey = nil
        if discardingView {
            preparedView?.galleryView.discardPreparation()
            preparedView = nil
        }
    }

    private func presentationFrame(in host: NSView) -> NSRect {
        var frame = host.bounds.insetBy(dx: 16, dy: 12)
        if lastSearchFrame != nil {
            frame.size.height = max(0, frame.height - (host.window?.screen?.safeAreaInsets.top ?? 0))
        }
        return frame
    }

    /// Called by the parent only after the hidden body has its initial offset.
    func revealPreviewPresentation() {
        guard isActive, isOpen, isPreviewing, let view else { return }
        view.isHidden = false
    }

    @discardableResult
    func commitPreview() -> Bool {
        guard isActive, isOpen, isPreviewing, preferences.isLoaded, preferences.committed.enabled,
              preferences.pendingCount == 0, invalidatedSourceRevision == nil, canTransition(),
              host != nil, let view else { return false }
        let session = sessionGeneration
        prepareEntry()
        // Preparation can synchronously cancel this session or invalidate admission.
        guard isActive, isOpen, isPreviewing, sessionGeneration == session, self.view === view,
              preferences.isLoaded, preferences.committed.enabled, preferences.pendingCount == 0,
              invalidatedSourceRevision == nil, canTransition() else { return false }
        isPreviewing = false
        view.setAccessibilityHidden(false)
        setGridHidden(true)
        guard isActive, isOpen, sessionGeneration == session, self.view === view else { return false }
        view.isHidden = false
        view.setSearchHeaderVisible(true)
        refreshEntryState()
        view.focusSearch()
        onPresentationChange?()
        return true
    }

    func cancelPreview() {
        guard isPreviewing else { return }
        close(restoring: false)
    }

    @objc private func enterFromButton(_ sender: Any?) { _ = enter() }

    func back() {
        guard isOpen else { return }
        if !isHandlingEscape { onBeforeBack?() }
        guard isOpen else { return }
        if isPreviewing { cancelPreview(); return }
        guard preferences.pendingCount == 0, canTransition() else { return }
        close(restoring: true)
    }

    /// A committed swipe return preserves the grid query but intentionally drops
    /// the prior page, pointer selection and search-field focus.
    @discardableResult
    func backToFirstGridPage() -> Bool {
        guard isOpen, !isPreviewing, preferences.pendingCount == 0, canTransition(),
              let context = returnContext else { return false }
        returnContext = .init(query: context.query, page: 0, selection: nil, searchWasFocused: false)
        close(restoring: true)
        return true
    }

    func hide() { close(restoring: false) }

    private func close(restoring: Bool) {
        guard isOpen, !isClosing else { return }
        isClosing = true
        defer {
            isClosing = false
            if isActive { schedulePreparationIfReady() }
        }
        let outgoing = view
        let context = returnContext
        let wasPreviewing = isPreviewing
        isOpen = false
        isPreviewing = false
        sessionGeneration &+= 1
        actionGeneration &+= 1
        returnContext = nil
        projection.close()
        if let outgoing { relinquishResponder(in: outgoing) }
        outgoing?.reset()
        // Reset/closeDetails can synchronously focus another Library control.
        // Keep the window neutral before detaching, without touching a new owner.
        if let outgoing { relinquishResponder(in: outgoing) }
        // Detach the old native field before restoring another control's shared
        // editor; reparenting it later can revoke the newly restored grid editor.
        outgoing?.unmountSearchHeader()
        // Prepare the retained destination before revealing it. Query restoration
        // may synchronously rebind cells; never do that after the grid is visible.
        if isActive, restoring, !wasPreviewing, let context { restoreGrid(context) }
        outgoing?.removeFromSuperview()
        if view === outgoing { view = nil }
        if isActive, preferences.committed.enabled, let outgoing, host != nil {
            outgoing.setAccessibilityHidden(true)
            preparedView = outgoing // reset() already revoked content, images and draft state.
        }
        // Synchronous reset/restore consumers may tear down the owner. Finish
        // detaching the captured identity, but never notify or reveal a dead host.
        guard isActive else { return }
        if !wasPreviewing { setGridHidden(false) }
        guard isActive else { return }
        refreshEntryState()
        onReadinessChange()
        if isActive { onPresentationChange?() }
    }

    /// Resign while the mounted subtree can still prove ownership. Ending only
    /// its field editor can leave a control (and its native focus ring) active.
    private func relinquishResponder(in library: AppLibraryView) {
        guard let window = library.window else { return }
        func owns(_ responder: NSResponder?) -> Bool {
            guard let responder else { return false }
            if let editor = responder as? NSTextView, editor.isFieldEditor {
                if library.searchField.currentEditor() === editor { return true }
                if let control = editor.delegate as? NSView,
                   control === library.searchField || control === library || control.isDescendant(of: library) { return true }
            }
            guard let view = responder as? NSView else { return false }
            return view === library.searchField || view === library || view.isDescendant(of: library)
        }

        guard owns(window.firstResponder) else { return }
        _ = window.makeFirstResponder(nil)
        // Lifecycle teardown may need to finish an editor that refused normal
        // resignation. Recheck after each callback: another owner may take focus.
        if owns(window.firstResponder) {
            window.endEditing(for: library)
            if owns(window.firstResponder) { _ = window.makeFirstResponder(nil) }
        }
    }

    func handleEscape() -> Bool {
        guard isOpen else { return false }
        onBeforeBack?()
        guard isOpen else { return true }
        if isPreviewing { cancelPreview(); return true }
        if preferences.pendingCount > 0 || !canTransition() { return true }
        // The view delegates its final Escape to back(); notify the parent only
        // once while retaining the view's detail/query/composition precedence.
        isHandlingEscape = true
        defer { isHandlingEscape = false }
        return view?.handleEscape() ?? true
    }

    var preferredFirstResponder: NSResponder? { isOpen && !isPreviewing ? view?.preferredFirstResponder : nil }
    var hasPresentationOwnership: Bool { isOpen && view?.hasPresentationOwnership == true }

    func invalidateSourceTargets() {
        cancelPreparation()
        // Keep only the empty native shell; source-bearing cards are revoked.
        preparedView?.galleryView.discardPreparation()
        view?.galleryView.discardPreparation()
        invalidatedSourceRevision = catalogProvider()?.revision ?? .zero
        sourceRefreshFailed = false
        actionGeneration &+= 1
        projection.close()
        renderProjection()
        refreshEntryState()
    }

    /// Failed source replacement keeps old actions revoked, but must not pretend
    /// an already completed failed rescan is still loading forever.
    func noteCatalogRefreshState(_ state: AppGridUIState) {
        guard isActive else { return }
        catalogRefreshState = state
        if invalidatedSourceRevision != nil { sourceRefreshFailed = state == .partialFailure }
        renderProjection()
    }

    func catalogDidCommit() {
        guard isActive else { return }
        // Presentation-only commits (including search/arrangement changes) can
        // retain the same catalog key. Do not rebuild an already valid idle pool.
        if let old = invalidatedSourceRevision, let revision = catalogProvider()?.revision, revision > old {
            invalidatedSourceRevision = nil
            sourceRefreshFailed = false
        }
        if isOpen { refreshProjection() }
        refreshEntryState()
        schedulePreparationIfReady()
    }

    func refreshReadiness() {
        refreshEntryState()
        schedulePreparationIfReady()
        if needsActivityProjection, canTransition() {
            needsActivityProjection = false
            view?.setActivitySectionsEnabled(activitySectionsEnabled)
            if isOpen { refreshProjection() }
        }
    }

    private var activitySectionsEnabled: Bool {
        activity?.document.enabled == true && activity?.persistedDocument?.enabled == true
            && activity?.libraryEnabled == true && activity?.canWrite == true
    }

    private func activityChanged() {
        guard isActive else { return }
        renderActivitySettings()
        needsActivityProjection = true
        refreshReadiness()
        onReadinessChange()
    }

    private func renderActivitySettings() {
        guard let settingsView else { return }
        let value = activity
        settingsView.activitySettingsView.applyState(.init(
            enabled: value?.document.enabled ?? false,
            canEnable: value?.canWrite == true && value?.libraryEnabled == true && value?.isClearing != true,
            isBusy: (value?.pendingCount ?? 0) > 0,
            canClear: value?.canWrite == true && value?.isClearing != true && (value?.document.entries.isEmpty == false || value?.persistedDocument?.entries.isEmpty == false),
            status: value?.status ?? .unavailable,
            canRetry: value?.canWrite == true && value?.requiresQuitProtection == true && value?.pendingCount == 0,
            canRecover: value?.canRecover == true && value?.pendingCount == 0))
    }

    func resolve(_ request: AppLibraryActionRequest, checkingReadiness: Bool = true) -> AppRecord? {
        guard isActive, isOpen, !isPreviewing, preferences.pendingCount == 0, invalidatedSourceRevision == nil,
              (!checkingReadiness || canExecuteAction()), request.generation == actionGeneration,
              let snapshot = projection.snapshot, snapshot.revision == request.catalogRevision,
              let catalog = catalogProvider(), catalog.revision == request.catalogRevision,
              let record = catalog.records.first(where: { $0.id == request.appID }),
              record.canonicalURL == request.canonicalURL, !managementProvider().isHidden(record),
              snapshot.entries.contains(where: { $0.record.id == record.id && $0.record.canonicalURL == record.canonicalURL }) else { return nil }
        return record
    }

    private func preferencesChanged() {
        guard isActive else { return }
        // Accepted-write completion is also a readiness transition. Consumers
        // rejected while the writer was pending must be retried without polling.
        defer {
            if isActive {
                onReadinessChange()
                if isActive { onPresentationChange?() }
            }
        }
        if preferences.pendingCount == 0 { pendingLibraryEnabled = nil }
        if !preferences.committed.enabled || preferences.pendingCount > 0 {
            cancelPreparation(discardingView: true)
        }
        activity?.setLibraryEnabled(preferences.committed.enabled && pendingLibraryEnabled != false)
        renderSettings()
        if preferences.pendingCount == 0, let session = pendingCategorySession,
           let result = preferences.latestSaveResult {
            pendingCategorySession = nil
            if isOpen, session == sessionGeneration {
                view?.categorySaveDidComplete(result)
                if result != .saved { onCategorySaveFailure() }
            }
        }
        guard isActive else { return }
        if isOpen, !preferences.committed.enabled { close(restoring: true) }
        guard isActive else { return }
        if isOpen { refreshProjection() }
        refreshEntryState()
        schedulePreparationIfReady()
    }

    private func refreshProjection() {
        guard isActive, isOpen, let view else { return }
        actionGeneration &+= 1
        guard invalidatedSourceRevision == nil, let catalog = catalogProvider() else {
            projection.close()
            renderProjection()
            return
        }
        entryProfile?.mark(.projectionRequested)
        let request = AppLibraryProjectionRequest(catalog: catalog, management: managementProvider(),
            preferences: preferences.committed, query: view.query, category: view.selectedCategory,
            locale: Locale(identifier: strings.language.rawValue),
            activity: activitySectionsEnabled ? activity?.document : nil,
            activitySection: view.selectedActivitySection, activityNow: activity?.projectionDate ?? Date())
        if projection.isOpen { projection.update(request) } else { projection.open(request) }
    }

    private func renderProjection() {
        let profile = entryProfile
        let profileStart = profile?.begin()
        defer { if let profileStart { profile?.end(.renderProjection, since: profileStart, count: 0) } }
        guard isOpen else { return }
        if let snapshot = projection.snapshot { entryProfile?.mark(.projectionDelivered, count: snapshot.entries.count) }
        view?.apply(snapshot: preferences.pendingCount == 0 ? projection.snapshot : nil,
            isLoading: (projection.isOpen && projection.isProjecting) || preferences.pendingCount > 0
                || (catalogProvider() == nil && catalogRefreshState.isBusy)
                || (invalidatedSourceRevision != nil && !sourceRefreshFailed),
            catalogIsEmpty: catalogProvider()?.records.isEmpty == true, actionGeneration: actionGeneration)
    }

    private func renderSettings() {
        settingsView?.applyState(preferences: preferences.committed, loadResult: preferences.loadResult,
            pendingCount: preferences.pendingCount, saveResult: preferences.latestSaveResult, isLoaded: preferences.isLoaded)
        renderActivitySettings()
    }

    private func refreshEntryState() {
        entryButton?.isHidden = !preferences.committed.enabled || isOpen
        entryButton?.isEnabled = preferences.isLoaded && preferences.pendingCount == 0 && canTransition() && invalidatedSourceRevision == nil
    }

    func relabel(strings: LocalizedStrings) {
        cancelPreparation()
        preparedView?.galleryView.discardPreparation()
        self.strings = strings
        entryButton?.title = strings.libraryText(.title)
        entryButton?.setAccessibilityLabel(strings.libraryText(.title))
        settingsView?.relabel(strings: strings)
        view?.relabel(strings: strings)
        preparedView?.relabel(strings: strings)
        if isOpen { refreshProjection() }
        schedulePreparationIfReady()
    }

    func layout(searchFrame: NSRect) {
        lastSearchFrame = searchFrame
        guard let host else { return }
        let width = min(CGFloat(132), max(32, searchFrame.minX - host.bounds.minX - 32))
        entryButton?.frame = .init(x: host.bounds.minX + 16, y: searchFrame.minY, width: width, height: searchFrame.height)
        entryButton?.image = width < 100 ? NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: strings.libraryText(.title)) : nil
        entryButton?.imagePosition = width < 100 ? .imageOnly : .noImage
        if let view {
            view.frame = presentationFrame(in: host)
            if view.searchField.superview === host { view.searchField.frame = searchFrame }
        }
        schedulePreparationIfReady()
    }

    func teardown() {
        hide()
        isActive = false
        cancelPreparation(discardingView: true)
        preferences.onChange = nil
        preferences.invalidate()
        activity?.invalidate()
        settingsView?.activitySettingsView.onSetEnabled = nil
        settingsView?.activitySettingsView.onClear = nil
        settingsView?.activitySettingsView.onRetry = nil
        settingsView?.activitySettingsView.onRecover = nil
        projection.onChange = nil
        projection.close()
        settingsView?.onSetEnabled = nil
        settingsView?.onRecover = nil
        entryButton?.removeFromSuperview()
        entryButton = nil
        host = nil
    }
}
