import AppCatalogCore
import AppGridUI
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
private final class RuntimeLanguageStore: LanguagePreferencesPersisting {
    var result: LanguagePreferencesLoadResult
    var writes: [LanguagePreferences] = []
    init(_ preference: InterfaceLanguagePreference = .english) { result = .loaded(.init(language: preference)) }
    func load() -> LanguagePreferencesLoadResult { result }
    func save(_ value: LanguagePreferences) -> LanguagePreferencesSaveResult {
        writes.append(value); result = .loaded(value); return .saved
    }
}

@MainActor
final class LanguageRuntimeIntegrationTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let host = AppDelegate(options: .default)
        let center = NotificationCenter()
        let store = RuntimeLanguageStore()
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let controller: ActivationSettingsWindowController
        init() {
            _ = NSApplication.shared
            host.surface = surface
            host.installLanguagePreferences(store: store, preferredLanguages: { ["en"] }, center: center)
            controller = ActivationSettingsWindowController(draft: .init(committed: .init()), strings: host.languageStrings)
            host.configureLanguageSettings(controller)
            surface.onIdleBoundary = { [weak host] in host?.schedulePendingAppearancePresentation() }
        }
        func apply(_ language: InterfaceLanguagePreference) {
            let index: Int
            switch language { case .system: index = 0; case .simplifiedChinese: index = 1; case .english: index = 2; case .japanese: index = 3 }
            controller.languageView.languagePopup.selectItem(at: index)
            controller.languageView.applyButton.performClick(nil)
        }
        func tearDown() {
            host.teardownLanguagePresentation()
            controller.hideSettings()
            controller.window?.delegate = nil
            controller.window?.contentView = nil
            surface.teardown()
            host.surface = nil
            host.window = nil
        }
    }

    private func drainMainTurns(_ count: Int = 5) async {
        for _ in 0..<count {
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }

    func testSourcesConstructorRelabelBeforePopulationIsBoundsSafeInAllLanguages() {
        for language in InterfaceLanguage.allCases {
            let view = AppSourcesSettingsView(frame: .zero, strings: LocalizedStrings(language: language))
            XCTAssertEqual(view.rootsPopup.numberOfItems, 1)
            XCTAssertEqual(view.rootsPopup.item(at: 0)?.title, view.strings.settingsText(.sourcesSelectRoot))
            XCTAssertEqual(view.draft, .default)
        }
    }

    func testActualLanguageTabAndNativeApplyAreWiredAndDoNotShowWindows() async throws {
        let f = Fixture(); defer { f.tearDown() }
        let tabs = try XCTUnwrap(f.controller.window?.contentView as? NSTabView)
        XCTAssertEqual(tabs.tabViewItems.compactMap { $0.identifier as? String },
                       ["activation", "appearance", "management", "sources", "language", "library"])
        XCTAssertFalse(f.controller.window?.isVisible == true)
        f.apply(.japanese)
        XCTAssertEqual(f.store.writes, [.init(language: .japanese)])
        XCTAssertEqual(f.host.languageStrings?.language, .english)
        XCTAssertEqual(f.host.languagePresentationController?.state, .queued)
        await drainMainTurns()
        XCTAssertEqual(f.host.languageStrings?.language, .japanese)
        XCTAssertEqual(f.controller.appearanceView.strings.language, .japanese)
        XCTAssertEqual(f.controller.appManagementView.strings.language, .japanese)
        XCTAssertEqual(f.controller.appSourcesView.strings.language, .japanese)
        XCTAssertEqual(f.controller.languageView.statusLabel.stringValue, f.controller.languageView.strings.text(.languageApplied))
        XCTAssertEqual(f.host.languagePresentationApplyCount, 1)
    }

    func testCoreGestureQueuesLatestAndNoRelabelOccursInFrameStack() async {
        let f = Fixture(); defer { f.tearDown() }
        gestureBegan(f.surface, at: 0)
        let pin = f.surface.pinnedPresentation
        f.apply(.simplifiedChinese); f.apply(.japanese)
        XCTAssertEqual(f.surface.core.state, .tracking)
        XCTAssertEqual(f.surface.pinnedPresentation, pin)
        XCTAssertEqual(f.host.languagePresentationApplyCount, 0)
        gestureEnded(f.surface, at: 0.02); finishPendingGesture(f.surface, at: 0.03); settleFrames(f.surface)
        XCTAssertEqual(f.host.languagePresentationApplyCount, 0)
        await drainMainTurns()
        XCTAssertEqual(f.host.languageStrings?.language, .japanese)
        XCTAssertEqual(f.host.languagePresentationApplyCount, 1)
        XCTAssertEqual(f.surface.core.pageCount, 3)
    }

    func testRealMenuNotificationsCountOverlapAndApplyOnlyAfterFinalEnd() async {
        let f = Fixture(); defer { f.tearDown() }
        let menu = NSMenu()
        f.center.post(name: NSMenu.didBeginTrackingNotification, object: menu)
        f.center.post(name: NSMenu.didBeginTrackingNotification, object: menu)
        f.apply(.japanese)
        await drainMainTurns(); XCTAssertEqual(f.host.languageStrings?.language, .english)
        f.center.post(name: NSMenu.didEndTrackingNotification, object: menu)
        await drainMainTurns(); XCTAssertEqual(f.host.languageStrings?.language, .english)
        f.center.post(name: NSMenu.didEndTrackingNotification, object: menu)
        await drainMainTurns(); XCTAssertEqual(f.host.languageStrings?.language, .japanese)
        XCTAssertEqual(f.host.languagePresentationApplyCount, 1)
    }

    func testSourceBusyReleaseRetriesWithoutAnotherUserInput() async {
        let f = Fixture(); defer { f.tearDown() }
        let view = f.controller.appSourcesView
        var continuation: CheckedContinuation<AppSourceRootAdmissionResult, Never>?
        view.onAdmit = { _ in await withCheckedContinuation { continuation = $0 } }
        view.addDraftRoot(URL(fileURLWithPath: "/SyntheticLanguageApps"))
        await drainMainTurns()
        XCTAssertNotNil(continuation)
        XCTAssertTrue(view.hasPresentationOwnership)
        f.apply(.japanese)
        await drainMainTurns(); XCTAssertEqual(f.host.languageStrings?.language, .english)
        continuation?.resume(returning: .alreadyCovered)
        await drainMainTurns()
        XCTAssertFalse(view.hasPresentationOwnership)
        XCTAssertEqual(f.host.languageStrings?.language, .japanese)
        XCTAssertEqual(view.statusLabel.stringValue, view.strings.settingsText(.sourcesAlreadyCovered))
    }

    func testActualMarkedTextAndNotificationRetryPreserveEditorContent() async {
        let f = Fixture(); defer { f.tearDown() }
        let editor = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 40))
        f.controller.window?.contentView?.addSubview(editor)
        XCTAssertTrue(f.controller.window?.makeFirstResponder(editor) == true)
        editor.setMarkedText("synthetic composing", selectedRange: NSRange(location: 0, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(editor.hasMarkedText())
        f.apply(.japanese)
        await drainMainTurns(); XCTAssertEqual(f.host.languageStrings?.language, .english)
        let content = editor.string
        editor.unmarkText()
        f.center.post(name: NSText.didChangeNotification, object: editor)
        await drainMainTurns()
        XCTAssertEqual(f.host.languageStrings?.language, .japanese)
        XCTAssertEqual(editor.string, content)
    }

    func testReplacingNamespaceRejectsRetainedOldCoordinatorAndDiscardCallback() async throws {
        let f = Fixture(); defer { f.tearDown() }
        let old = try XCTUnwrap(f.host.languageSettingsCoordinator)
        let discard = f.controller.onDiscardLanguageDraft
        let next = RuntimeLanguageStore(.simplifiedChinese)
        f.host.installLanguagePreferences(store: next, preferredLanguages: { ["en"] }, center: f.center)
        f.host.configureLanguageSettings(f.controller)
        f.controller.languageView.languagePopup.selectItem(at: 3)
        f.controller.languageView.choiceChanged(nil)
        XCTAssertEqual(old.apply(.init(language: .japanese)), .unavailable)
        old.refreshAcceptedPresentation(); discard?()
        await drainMainTurns()
        XCTAssertEqual(f.host.languageStrings?.language, .simplifiedChinese)
        XCTAssertEqual(f.host.languageSettingsCoordinator?.committed.language, .simplifiedChinese)
        XCTAssertNil(f.host.languagePresentationController?.pendingLanguage)
        XCTAssertTrue(f.store.writes.isEmpty); XCTAssertTrue(next.writes.isEmpty)
        XCTAssertEqual(f.controller.languageView.draft.language, .japanese)
    }

    func testTearDownRejectsQueuedRelabelAndRemovesNotificationOwner() async {
        let f = Fixture(); defer { f.tearDown() }
        f.apply(.japanese)
        f.host.teardownLanguagePresentation()
        await drainMainTurns()
        f.center.post(name: NSMenu.didBeginTrackingNotification, object: NSMenu())
        XCTAssertEqual(f.host.languagePresentationController?.state, .unavailable)
        XCTAssertEqual(f.host.languageStrings?.language, .english)
        XCTAssertEqual(f.store.result, .loaded(.init(language: .japanese)))
        XCTAssertEqual(f.host.languagePresentationApplyCount, 0)
    }

    func testInvalidUnresolvedProfileNeverFallsBackToProductionLanguageStore() {
        var options = AppArguments.Options.default
        options.uiTestProfile = "unresolved"; options.uiTestWindowed = true
        let host = AppDelegate(options: options)
        host.installLanguagePreferences(preferredLanguages: { ["ja"] }, center: NotificationCenter())
        defer { host.teardownLanguagePresentation() }
        XCTAssertEqual(host.languageSettingsCoordinator?.loadResult, .unavailable)
        XCTAssertEqual(host.languageSettingsCoordinator?.apply(.default), .unavailable)
        XCTAssertEqual(host.languageStrings?.language, .japanese)
    }

    func testReentryPreparationPreservesAllDraftsAndDoesNotReconfigureSources() throws {
        let coordinator = ActivationSettingsCoordinator(store: InMemoryActivationPreferencesStore(),
                                                        loginService: FakeLaunchAtLoginService())
        coordinator.preservesInterfaceDraftsOnReopen = true
        var configurations = 0, refreshes = 0
        coordinator.configureAdditionalSettings = { _ in configurations += 1 }
        coordinator.refreshAcceptedInterfaceLanguage = { refreshes += 1 }
        let controller = coordinator.prepareSettingsForPresentation()
        defer { controller.hideSettings(); controller.window?.delegate = nil; controller.window?.contentView = nil }
        controller.applyShortcutPreset(.controlCommandSpace)
        let activationDraft = controller.draft
        controller.appearanceView.iconSlider.integerValue = 64
        controller.appearanceView.controlChanged(nil)
        controller.appManagementView.aliasField.stringValue = "synthetic unsaved alias"
        controller.appSourcesView.automaticCheckbox.state = .off
        controller.appSourcesView.automaticChanged(nil)
        XCTAssertTrue(coordinator.prepareSettingsForPresentation() === controller)
        XCTAssertEqual(configurations, 1); XCTAssertEqual(refreshes, 1)
        XCTAssertEqual(controller.draft, activationDraft)
        XCTAssertEqual(controller.appearanceView.draft.preferredIconSide, 64)
        XCTAssertEqual(controller.appManagementView.aliasField.stringValue, "synthetic unsaved alias")
        XCTAssertFalse(controller.appSourcesView.draft.automaticRefreshEnabled)
        XCTAssertFalse(controller.window?.isVisible == true)
    }

    func testCloseDiscardsOnlyLanguageDraftAndDoesNotSave() {
        let f = Fixture(); defer { f.tearDown() }
        f.controller.languageView.languagePopup.selectItem(at: 3)
        f.controller.languageView.choiceChanged(nil)
        f.controller.appManagementView.aliasField.stringValue = "synthetic alias draft"
        f.controller.hideSettings()
        XCTAssertEqual(f.controller.languageView.draft.language, .english)
        XCTAssertEqual(f.controller.appManagementView.aliasField.stringValue, "synthetic alias draft")
        XCTAssertTrue(f.store.writes.isEmpty)
    }

    func testSearchRelabelPreservesQueryAndSelectors() {
        let field = AppSearchFieldView(frame: .zero)
        field.stringValue = "synthetic original query"
        let action = field.action
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            field.relabel(strings: strings)
            XCTAssertEqual(field.stringValue, "synthetic original query")
            XCTAssertEqual(field.placeholderString, strings.text(.searchPlaceholder))
            XCTAssertEqual(field.accessibilityLabel(), strings.text(.searchAccessibility))
            XCTAssertEqual(field.action, action)
        }
    }

    func testStatusMenuRelabelPreservesNativeActionIdentities() {
        let controller = StatusItemController()
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            controller.relabel(strings: strings)
            let menu = controller.makeMenu()
            XCTAssertEqual(menu.item(withTag: StatusItemController.MenuActionTag.showHide.rawValue)?.title,
                           strings.text(.showLauncher))
            XCTAssertEqual(menu.item(withTag: StatusItemController.MenuActionTag.quit.rawValue)?.title,
                           strings.text(.quitLauncher))
            XCTAssertTrue(menu.item(withTag: StatusItemController.MenuActionTag.quit.rawValue)?.target === controller)
        }
    }
    func testActualHeldGridPointerDefersLocaleWithoutNewIconsOrCatalogChanges() async throws {
        let f = Fixture(); defer { f.tearDown() }
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticLanguage")], loader: RecordingIconLoader())
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 900))
        let window = NSWindow(contentRect: container.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = container
        defer {
            f.host.dragCoordinator?.teardown()
            assembly.teardown(); window.delegate = nil; window.contentView = nil
        }
        f.surface.frame = container.bounds; container.addSubview(f.surface)
        f.surface.contentProvider = assembly.provider; f.surface.renderer = assembly.renderer
        f.host.window = window; f.host.container = container; f.host.assembly = assembly
        let keyboard = KeyboardFocusController(columns: 5)
        f.host.keyboardController = keyboard; keyboard.install(on: f.surface, focusModel: .init())
        f.host.installFolderWiring(assembly: assembly, surface: f.surface, keyboard: keyboard,
            launch: AppLaunchController(surface: f.surface, assembly: assembly, session: nil))
        f.host.installDragUI(surface: f.surface, assembly: assembly)
        let records = (0..<105).map { number in
            let id = CatalogFixture.appID("fixture.language.\(number)")
            return CatalogFixture.record(id: id, displayName: "Synthetic \(number)", bundleID: "fixture.language.\(number)",
                url: CatalogFixture.tempURL(named: "Language\(number).app"), icon: .from(appID: id), rootPriority: 0)
        }
        assembly.provider.receive(.init(revision: CatalogRevision(7), records: records))
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        f.surface.refreshPresentation(); f.surface.layoutSubtreeIfNeeded()
        let cell = try XCTUnwrap(assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        cell.layoutSubtreeIfNeeded()
        let token = cell.bindingToken, requests = assembly.iconPipeline.stats.requests
        let revision = f.surface.servedRevision
        let point = cell.convert(NSPoint(x: cell.bounds.midX, y: cell.bounds.midY), to: nil)
        f.host.dragCoordinator?.pointerDown(locationInWindow: point, sourceCell: cell, memberFolderID: nil)
        XCTAssertTrue(f.host.dragCoordinator?.isSessionActive == true)
        f.apply(.japanese)
        await drainMainTurns(); XCTAssertEqual(f.host.languageStrings?.language, .english)
        f.host.dragCoordinator?.cancel(reason: .escape)
        await drainMainTurns()
        XCTAssertEqual(f.host.languageStrings?.language, .japanese)
        XCTAssertEqual(assembly.iconPipeline.stats.requests, requests)
        XCTAssertEqual(cell.bindingToken, token)
        XCTAssertEqual(f.surface.servedRevision, revision)
        XCTAssertEqual(f.surface.core.pageCount, 3)
    }

    func testShortcutRecordingSurvivesReentryAndLocaleWaitsForActualStop() async throws {
        let host = AppDelegate(options: .default), store = RuntimeLanguageStore()
        host.installLanguagePreferences(store: store, preferredLanguages: { ["en"] }, center: NotificationCenter())
        let coordinator = ActivationSettingsCoordinator(store: InMemoryActivationPreferencesStore(),
            loginService: FakeLaunchAtLoginService())
        coordinator.preservesInterfaceDraftsOnReopen = true
        coordinator.interfaceStringsProvider = { host.languageStrings }
        coordinator.configureAdditionalSettings = { host.configureLanguageSettings($0) }
        coordinator.refreshAcceptedInterfaceLanguage = { host.languageSettingsCoordinator?.refreshAcceptedPresentation() }
        let controller = coordinator.prepareSettingsForPresentation()
        defer { host.teardownLanguagePresentation(); controller.hideSettings(); controller.window?.delegate = nil; controller.window?.contentView = nil }
        let tabs = try XCTUnwrap(controller.window?.contentView as? NSTabView)
        let activation = try XCTUnwrap(tabs.tabViewItems.first { $0.identifier as? String == "activation" }?.view)
        func findRecordButton(_ view: NSView) -> NSButton? {
            if let button = view as? NSButton, button.action.map(NSStringFromSelector) == "shortcutRecordClicked:" { return button }
            return view.subviews.lazy.compactMap(findRecordButton).first
        }
        func findEnableButton(_ view: NSView) -> NSButton? {
            if let button = view as? NSButton, button.title == host.languageStrings?.activationText(.globalShortcutEnable) { return button }
            return view.subviews.lazy.compactMap(findEnableButton).first
        }
        let enable = try XCTUnwrap(findEnableButton(activation))
        enable.performClick(nil)
        XCTAssertTrue(controller.draft.globalShortcutEnabled)
        let button = try XCTUnwrap(findRecordButton(activation))
        XCTAssertTrue(button.isEnabled)
        button.performClick(nil)
        XCTAssertTrue(controller.isRecordingShortcut)
        controller.languageView.languagePopup.selectItem(at: 3)
        controller.languageView.applyButton.performClick(nil)
        _ = coordinator.prepareSettingsForPresentation()
        XCTAssertTrue(controller.isRecordingShortcut)
        await drainMainTurns(); XCTAssertEqual(host.languageStrings?.language, .english)
        controller.hideSettings()
        XCTAssertFalse(controller.isRecordingShortcut)
        await drainMainTurns()
        XCTAssertEqual(host.languageStrings?.language, .japanese)
        XCTAssertFalse(controller.window?.isVisible == true)
    }

    func testProductionReentryRebindsRetainedLanguageControlsAfterStoreReplacement() async {
        let host = AppDelegate(options: .default)
        let first = RuntimeLanguageStore(.english), second = RuntimeLanguageStore(.simplifiedChinese)
        host.installLanguagePreferences(store: first, preferredLanguages: { ["en"] }, center: NotificationCenter())
        let coordinator = ActivationSettingsCoordinator(store: InMemoryActivationPreferencesStore(),
            loginService: FakeLaunchAtLoginService())
        coordinator.preservesInterfaceDraftsOnReopen = true
        coordinator.interfaceStringsProvider = { host.languageStrings }
        coordinator.configureAdditionalSettings = { host.configureLanguageSettings($0) }
        coordinator.refreshAcceptedInterfaceLanguage = { [weak coordinator] in
            if let controller = coordinator?.retainedSettingsController { host.configureLanguageSettings(controller) }
        }
        let controller = coordinator.prepareSettingsForPresentation()
        defer { host.teardownLanguagePresentation(); controller.hideSettings(); controller.window?.delegate = nil; controller.window?.contentView = nil }
        controller.appManagementView.aliasField.stringValue = "retained synthetic alias"
        host.installLanguagePreferences(store: second, preferredLanguages: { ["en"] }, center: NotificationCenter())
        XCTAssertNil(controller.languageView.onApply)
        XCTAssertTrue(coordinator.prepareSettingsForPresentation() === controller)
        XCTAssertNotNil(controller.languageView.onApply)
        XCTAssertEqual(controller.languageView.draft.language, .simplifiedChinese)
        XCTAssertEqual(controller.appManagementView.aliasField.stringValue, "retained synthetic alias")
        controller.languageView.languagePopup.selectItem(at: 3)
        controller.languageView.applyButton.performClick(nil)
        await drainMainTurns()
        XCTAssertTrue(first.writes.isEmpty)
        XCTAssertEqual(second.writes, [.init(language: .japanese)])
        XCTAssertEqual(host.languageStrings?.language, .japanese)
    }

    func testProductionOwnerRelabelsRetainedGridPagerAndDotsWithoutCatalogOrIconWork() async throws {
        let f = Fixture(); defer { f.tearDown() }
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticLanguage")], loader: RecordingIconLoader())
        defer { assembly.teardown() }
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 900))
        container.addSubview(f.surface); f.surface.frame = container.bounds
        f.host.assembly = assembly
        f.surface.contentProvider = assembly.provider; f.surface.renderer = assembly.renderer
        let records = (0..<105).map { number in
            let id = CatalogFixture.appID("fixture.language.owner.\(number)")
            return CatalogFixture.record(id: id, displayName: "Untranslated 日本語 \(number)",
                bundleID: "fixture.language.owner.\(number)", url: CatalogFixture.tempURL(named: "Owner\(number).app"),
                icon: .from(appID: id), rootPriority: 0)
        }
        assembly.provider.receive(.init(revision: CatalogRevision(9), records: records))
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        f.surface.refreshPresentation(); f.surface.layoutSubtreeIfNeeded()
        f.host.installPageDots(in: container)
        let page = try XCTUnwrap(assembly.renderer.pageView(forPage: 0))
        let cell = try XCTUnwrap(page.cell(at: 0))
        let token = cell.bindingToken, revision = f.surface.servedRevision
        let requests = assembly.iconPipeline.stats.requests, instances = assembly.renderer.totalInstancesCreated
        f.apply(.japanese)
        await drainMainTurns(12)
        let strings = LocalizedStrings(language: .japanese)
        XCTAssertEqual(f.host.languageStrings?.language, .japanese)
        XCTAssertEqual(page.pageLabelText, strings.page(1, total: 3))
        XCTAssertEqual(f.surface.accessibilityDescription, strings.page(1, total: 3))
        XCTAssertEqual(f.host.pageDotsView?.accessibilityLabel(), strings.gridText(.pageNavigation))
        XCTAssertEqual(cell.boundName, records[0].displayName)
        XCTAssertEqual(cell.bindingToken, token)
        XCTAssertEqual(f.surface.servedRevision, revision)
        XCTAssertEqual(assembly.iconPipeline.stats.requests, requests)
        XCTAssertEqual(assembly.renderer.totalInstancesCreated, instances)
    }

    private func installPendingCatalogFixture(_ f: Fixture, managementStore: (any AppManagementPersisting)? = nil) async -> AppCatalogAssembly {
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticLanguage")], loader: RecordingIconLoader())
        f.host.assembly = assembly
        f.surface.frame = NSRect(x: 0, y: 0, width: 1000, height: 900)
        f.surface.contentProvider = assembly.provider; f.surface.renderer = assembly.renderer
        f.host.installCatalogPresentationCallbacks(assembly: assembly, surface: f.surface)
        f.host.installAppManagementPreferences(store: managementStore ?? InMemoryAppManagementStore())
        f.host.configureAppManagementSettings(f.controller)
        let records = (0..<105).map { number in
            let id = CatalogFixture.appID("fixture.catalog.frame.\(number)")
            return CatalogFixture.record(id: id, displayName: "Synthetic \(number)", bundleID: "fixture.catalog.frame.\(number)",
                url: CatalogFixture.tempURL(named: "Frame\(number).app"), icon: .from(appID: id), rootPriority: 0)
        }
        assembly.provider.receive(.init(revision: CatalogRevision(20), records: records))
        f.host.applyPendingAtIdleBoundary()
        await drainMainTurns(8)
        let view = f.controller.appManagementView
        view.appPopup.selectItem(at: 1)
        _ = view.perform(NSSelectorFromString("selectionChanged:"), with: view.appPopup)
        view.aliasField.stringValue = "Unfinished 日本語 alias"
        return assembly
    }

    func testActualProductionTerminalFrameCatalogCommitDefersAllManagementTemplateCallsAndKeepsDraft() async throws {
        let f = Fixture(); defer { f.tearDown() }
        let assembly = await installPendingCatalogFixture(f); defer { assembly.teardown() }
        let view = f.controller.appManagementView
        let selected = try XCTUnwrap(view.selectedRecord?.id)
        gestureBegan(f.surface, at: 0)
        gestureChanged(f.surface, deltaX: 400, at: 0.5)
        gestureEnded(f.surface, at: 0.5); finishPendingGesture(f.surface, at: 0.5)
        XCTAssertTrue(f.surface.core.isAnimating)
        assembly.provider.receive(.init(revision: CatalogRevision(21), records: try XCTUnwrap(assembly.provider.servedSnapshot).records))
        let reads = view.staticTemplateReadCount, formats = view.countTemplateRenderCount
        for _ in 0..<120 where f.surface.core.isAnimating {
            f.surface.advanceFrame(deltaTime: 1.0 / 60.0)
            XCTAssertEqual(view.staticTemplateReadCount, reads)
            XCTAssertEqual(view.countTemplateRenderCount, formats)
        }
        XCTAssertFalse(f.surface.core.isAnimating)
        XCTAssertEqual(assembly.provider.servedRevision, 21, "Catalog commit remains synchronous on terminal frame")
        await drainMainTurns(12)
        XCTAssertGreaterThan(view.staticTemplateReadCount, reads)
        XCTAssertGreaterThan(view.countTemplateRenderCount, formats)
        XCTAssertEqual(view.selectedRecord?.id, selected)
        XCTAssertEqual(view.aliasField.stringValue, "Unfinished 日本語 alias")
        XCTAssertEqual(view.saveAliasButton.title, LocalizedStrings(language: .english).settingsText(.managementSaveAlias))
    }

    func testDeferredManagementRefreshWaitsForActualEditorReleaseWithoutAnotherCatalogEvent() async throws {
        let f = Fixture(); defer { f.tearDown() }
        let assembly = await installPendingCatalogFixture(f); defer { assembly.teardown() }
        let view = f.controller.appManagementView
        let window = try XCTUnwrap(f.controller.window)
        let tabs = try XCTUnwrap(window.contentView as? NSTabView)
        tabs.selectTabViewItem(at: 2)
        tabs.layoutSubtreeIfNeeded()
        XCTAssertTrue(view.aliasField.isEditable)
        XCTAssertTrue(window.makeFirstResponder(view.aliasField))
        XCTAssertNotNil(view.aliasField.currentEditor())
        let reads = view.staticTemplateReadCount, formats = view.countTemplateRenderCount
        assembly.provider.receive(.init(revision: CatalogRevision(21), records: try XCTUnwrap(assembly.provider.servedSnapshot).records))
        f.host.applyPendingAtIdleBoundary()
        await drainMainTurns(8)
        XCTAssertEqual(view.staticTemplateReadCount, reads)
        XCTAssertEqual(view.countTemplateRenderCount, formats)
        let editor = view.aliasField.currentEditor()
        window.makeFirstResponder(nil)
        f.center.post(name: NSText.didEndEditingNotification, object: editor)
        await drainMainTurns(8)
        XCTAssertGreaterThan(view.staticTemplateReadCount, reads)
        XCTAssertGreaterThan(view.countTemplateRenderCount, formats)
        XCTAssertEqual(view.aliasField.stringValue, "Unfinished 日本語 alias")
    }

    func testLanguageTeardownDropsQueuedManagementRefreshAndItsTemplateCalls() async throws {
        let f = Fixture(); defer { f.tearDown() }
        let assembly = await installPendingCatalogFixture(f); defer { assembly.teardown() }
        let view = f.controller.appManagementView
        let reads = view.staticTemplateReadCount, formats = view.countTemplateRenderCount
        assembly.provider.receive(.init(revision: CatalogRevision(21), records: try XCTUnwrap(assembly.provider.servedSnapshot).records))
        f.host.applyPendingAtIdleBoundary()
        f.host.teardownLanguagePresentation()
        await drainMainTurns(8)
        XCTAssertEqual(view.staticTemplateReadCount, reads)
        XCTAssertEqual(view.countTemplateRenderCount, formats)
    }

    func testActualAliasSaveClearAndResaveDoNotReviveAcceptedClearedText() async throws {
        let f = Fixture(); defer { f.tearDown() }
        let assembly = await installPendingCatalogFixture(f); defer { assembly.teardown() }
        let view = f.controller.appManagementView
        let selected = try XCTUnwrap(view.selectedRecord?.id)
        view.aliasField.stringValue = "  Pinned  "
        view.saveAliasButton.performClick(nil)
        XCTAssertEqual(view.aliasField.stringValue, "Pinned")
        await drainMainTurns(8)
        XCTAssertEqual(view.aliasField.stringValue, "Pinned")
        XCTAssertEqual(assembly.provider.managementPreferences.alias(for: try XCTUnwrap(view.selectedRecord)), "Pinned")
        view.clearAliasButton.performClick(nil)
        XCTAssertEqual(view.aliasField.stringValue, "")
        await drainMainTurns(8)
        XCTAssertEqual(view.selectedRecord?.id, selected)
        XCTAssertEqual(view.aliasField.stringValue, "")
        XCTAssertFalse(view.appPopup.selectedItem?.title.contains("Pinned") == true)
        XCTAssertNil(assembly.provider.managementPreferences.alias(for: try XCTUnwrap(view.selectedRecord)))
        view.saveAliasButton.performClick(nil)
        await drainMainTurns(8)
        XCTAssertEqual(view.aliasField.stringValue, "")
        XCTAssertFalse(view.appPopup.selectedItem?.title.contains("Pinned") == true)
    }

    func testFailedClearAliasRetainsUnfinishedFieldDraft() async throws {
        let f = Fixture(); defer { f.tearDown() }
        let assembly = await installPendingCatalogFixture(f); defer { assembly.teardown() }
        let view = f.controller.appManagementView
        view.onSetAlias = { _, _ in .failed }
        view.aliasField.stringValue = "Unfinished draft"
        view.clearAliasButton.performClick(nil)
        await drainMainTurns(8)
        XCTAssertEqual(view.aliasField.stringValue, "Unfinished draft")
    }

    @MainActor
    private final class ControllableManagementStore: AppManagementPersisting {
        var preferences = AppManagementPreferences.default
        var rejectNext: AppManagementSaveResult?
        func load() -> AppManagementLoadResult { .loaded(preferences) }
        func save(_ value: AppManagementPreferences) -> AppManagementSaveResult {
            if let rejection = rejectNext { rejectNext = nil; return rejection }
            preferences = value
            return .saved
        }
    }

    func testAcceptedHiddenBaselineSurvivesRejectedInverseWhileRealAliasEditorHoldsRefresh() async throws {
        for acceptedHidden in [true, false] {
            let f = Fixture(); defer { f.tearDown() }
            let store = ControllableManagementStore()
            let assembly = await installPendingCatalogFixture(f, managementStore: store)
            defer { assembly.teardown() }
            let view = f.controller.appManagementView
            let selected = try XCTUnwrap(view.selectedRecord)
            if !acceptedHidden {
                view.hiddenCheckbox.performClick(nil)
                await drainMainTurns(8)
                XCTAssertEqual(view.hiddenCheckbox.state, .on)
            }
            let window = try XCTUnwrap(f.controller.window)
            let tabs = try XCTUnwrap(window.contentView as? NSTabView)
            tabs.selectTabViewItem(at: 2); tabs.layoutSubtreeIfNeeded()
            XCTAssertTrue(window.makeFirstResponder(view.aliasField))
            XCTAssertNotNil(view.aliasField.currentEditor())
            view.hiddenCheckbox.performClick(nil)
            XCTAssertEqual(view.hiddenCheckbox.state, acceptedHidden ? .on : .off)
            XCTAssertEqual(store.preferences.isHidden(selected), acceptedHidden)
            XCTAssertEqual(assembly.provider.managementPreferences.isHidden(selected), acceptedHidden)
            XCTAssertNotNil(view.aliasField.currentEditor())
            for rejection in [AppManagementSaveResult.failed, .futureVersion(2)] {
                store.rejectNext = rejection
                view.hiddenCheckbox.performClick(nil)
                await drainMainTurns(8)
                XCTAssertEqual(view.hiddenCheckbox.state, acceptedHidden ? .on : .off)
                XCTAssertEqual(store.preferences.isHidden(selected), acceptedHidden)
                XCTAssertEqual(assembly.provider.managementPreferences.isHidden(selected), acceptedHidden)
                XCTAssertNotNil(view.aliasField.currentEditor())
                XCTAssertEqual(view.aliasField.stringValue, "Unfinished 日本語 alias")
            }
            let editor = view.aliasField.currentEditor()
            window.makeFirstResponder(nil)
            f.center.post(name: NSText.didEndEditingNotification, object: editor)
            await drainMainTurns(8)
            XCTAssertEqual(view.hiddenCheckbox.state, acceptedHidden ? .on : .off)
            XCTAssertEqual(view.aliasField.stringValue, "Unfinished 日本語 alias")
        }
    }

}
