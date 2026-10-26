import AppKit
import AppCatalogCore
import AppGridUI
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

private actor GestureLibraryStore: AppLibraryPersisting {
    func load() async -> AppLibraryLoadResult { .missing }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) async -> AppLibrarySaveResult { .saved }
}

@MainActor
private final class GestureValidationOrderingWindow: NSWindow {
    var frontRequests = 0
    var backRequests = 0
    override func makeKeyAndOrderFront(_ sender: Any?) { frontRequests += 1 }
    override func orderBack(_ sender: Any?) { backRequests += 1 }
}

@MainActor
final class GestureValidationRuntimeTests: XCTestCase {
    private func hostilePreferences() -> ActivationPreferences {
        var value = ActivationPreferences(fourFingerOutwardHideEnabled: true)
        value.settings.hotCornerEnabled = true
        value.settings.selectedCorner = .topLeft
        value.settings.globalShortcutEnabled = true
        value.settings.launchAtLoginEnabled = true
        value.settings.showStatusItem = false
        return value
    }

    func testPolicyPreservesGestureChoicesButRemovesUnrelatedCapabilities() {
        let safe = GestureValidationPolicy.preferences(hostilePreferences())
        XCTAssertTrue(safe.fourFingerActivationEnabled)
        XCTAssertTrue(safe.fourFingerOutwardHideEnabled)
        XCTAssertEqual(safe.settings, ActivationSettings())
        XCTAssertFalse(GestureValidationPolicy.preferences(ActivationPreferences()).fourFingerOutwardHideEnabled)
    }

    func testDedicatedFactoryHasOnlyFakeNonTouchAdapters() {
        _ = NSApplication.shared
        let owner = LauncherRuntimeServices.gestureValidationActivation(
            launcher: LauncherWindowController(reduceMotionProvider: { true }), requestTerminate: {})
        defer { owner.teardownActivationServices() }
        XCTAssertTrue(owner.shortcutRegistrar is FakeGlobalShortcutRegistrar)
        XCTAssertTrue(owner.sessionObserver is FakeWorkspaceSessionObserver)
        XCTAssertNil(owner.touchProvider)
        XCTAssertNil(owner.appliedPlan.hotCorner)
    }

    func testDedicatedApplyIsLazySingleProviderClampedAndStopsOnTeardown() {
        _ = NSApplication.shared
        let owner = LauncherRuntimeServices.gestureValidationActivation(
            launcher: LauncherWindowController(reduceMotionProvider: { true }), requestTerminate: {})
        let provider = MockTouchProvider(clock: FakePinchClock())
        var calls = 0
        let factory: () -> any TouchProvider = { calls += 1; return provider }
        var prefs = hostilePreferences(); prefs.fourFingerActivationEnabled = false
        LauncherRuntimeServices.applyGestureValidationPreferences(prefs, to: owner, makeTouchProvider: factory)
        XCTAssertEqual(calls, 0)
        prefs.fourFingerActivationEnabled = true
        for _ in 0..<3 {
            LauncherRuntimeServices.applyGestureValidationPreferences(prefs, to: owner, makeTouchProvider: factory)
        }
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(provider.isStarted)
        XCTAssertNil(owner.appliedPlan.hotCorner)
        XCTAssertNil(owner.appliedPlan.globalShortcut)
        prefs.fourFingerActivationEnabled = false
        LauncherRuntimeServices.applyGestureValidationPreferences(prefs, to: owner, makeTouchProvider: factory)
        XCTAssertFalse(provider.isStarted)
        prefs.fourFingerActivationEnabled = true
        LauncherRuntimeServices.applyGestureValidationPreferences(prefs, to: owner, makeTouchProvider: factory)
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(provider.isStarted)
        owner.teardownActivationServices()
        XCTAssertFalse(provider.isStarted)
        LauncherRuntimeServices.applyGestureValidationPreferences(prefs, to: owner, makeTouchProvider: factory)
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(provider.isStarted)
    }

    func testOriginalIsolatedPreferenceFactoryCannotReadRealDevice() {
        let owner = LauncherRuntimeServices.activation(launcher: LauncherWindowController(), isolated: true, requestTerminate: {})
        defer { owner.teardownActivationServices() }
        var calls = 0
        LauncherRuntimeServices.applyActivationPreferences(hostilePreferences(), to: owner, isolated: true,
            makeTouchProvider: { calls += 1; return MockTouchProvider(clock: FakePinchClock()) })
        XCTAssertEqual(calls, 0)
        XCTAssertNil(owner.touchProvider)
    }

    func testNormalizedApplyCannotPersistOrRegisterLoginAndOtherTriggers() {
        let initial = ActivationPreferences()
        let store = InMemoryActivationPreferencesStore(initial: initial)
        let login = FakeLaunchAtLoginService()
        var runtime: ActivationPreferences?
        let coordinator = ActivationSettingsCoordinator(store: store, loginService: login,
            initialCommitted: initial, applyPreferences: { runtime = $0 })
        coordinator.normalizeDraft = GestureValidationPolicy.draft
        let draft = ActivationPreferencesDraft(committed: hostilePreferences())
        _ = coordinator.applyDraft(draft)
        XCTAssertEqual(login.setEnabledCallCount, 0)
        XCTAssertEqual(coordinator.committed.settings, ActivationSettings())
        XCTAssertEqual(runtime?.settings, ActivationSettings())
        XCTAssertEqual(store.load(), .loaded(coordinator.committed))
        XCTAssertTrue(coordinator.committed.fourFingerOutwardHideEnabled)
    }

    func testDedicatedLauncherRefusesAllApplications() {
        XCTAssertFalse(GestureValidationAppLauncher().openApplication(at: URL(fileURLWithPath: "/Synthetic.app")))
    }

    func testMissingProfileDoesNotFallBackToFormalStorage() {
        var options = AppArguments.Options.default; options.gestureValidation = true; options.uiTestWindowed = true
        let owner = AppDelegate(options: options)
        XCTAssertThrowsError(try owner.configureUITestProfile(bundleURL: URL(fileURLWithPath: "/No.app")))
        XCTAssertNil(owner.uiTestProfile)
    }

    func testDedicatedHostDoesNotInstallSourceCoordinatorOrActivity() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = root.appendingPathComponent(".build/candidates/device/LaunchcopyGestureValidation.app")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        var options = AppArguments.Options.default
        options.gestureValidation = true; options.uiTestWindowed = true; options.uiTestProfile = "physical"
        let owner = AppDelegate(options: options)
        try owner.configureUITestProfile(bundleURL: bundle)
        let profile = try XCTUnwrap(owner.uiTestProfile)
        let assembly = try XCTUnwrap(owner.makeContentAssembly())
        defer { assembly.teardown() }
        XCTAssertEqual(assembly.scanRoots, [profile.applicationsDirectoryURL])
        owner.installAppSources(assembly: assembly)
        XCTAssertNil(owner.appSourcesCoordinator)
        owner.installAppLibrary(in: NSView(), store: GestureLibraryStore())
        XCTAssertNotNil(owner.appLibraryOwner)
        XCTAssertNil(owner.appLibraryOwner?.activity)
        owner.appLibraryOwner?.teardown()
        XCTAssertFalse(FileManager.default.fileExists(atPath: profile.rootURL.appendingPathComponent("LaunchActivity").path))
    }
    private func descendants(_ root: NSView) -> [NSView] {
        [root] + root.subviews.flatMap { descendants($0) }
    }

    func testRestrictedDetailsAndGalleryDisableOnlyExternalActions() throws {
        let strings = LocalizedStrings(language: .english)
        let view = AppLibraryView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700), strings: strings)
        defer { view.reset() }
        view.allowsExternalApplicationActions = false
        let record = CatalogFixture.record(id: .bundleIdentifier("fixture.gesture.item"), displayName: "Gesture Item",
            bundleID: "fixture.gesture.item", url: URL(fileURLWithPath: "/Synthetic/Gesture.app"),
            icon: .from(appID: .bundleIdentifier("fixture.gesture.item")), rootPriority: 0)
        let entry = AppLibraryEntry(record: record, displayName: record.displayName, category: .utilities, manualCategory: nil)
        view.apply(snapshot: .init(revision: CatalogRevision(1), entries: [entry], counts: [.utilities: 1]),
                   isLoading: false, catalogIsEmpty: false, actionGeneration: 1)
        let galleryApp = descendants(view.galleryView).compactMap { $0 as? NSButton }.first {
            $0.accessibilityIdentifier() == "library.card.utilities.app.0"
        }
        XCTAssertFalse(try XCTUnwrap(galleryApp).isEnabled)
        let category = descendants(view.galleryView).compactMap { $0 as? NSButton }.first {
            $0.accessibilityIdentifier() == "library.card.open.utilities"
        }
        XCTAssertNil(category, "The passive category card must not expose an expansion button")
        view.resultsTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        view.tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification, object: view.resultsTable))
        view.showDetails(nil)
        var requests = 0
        view.onOpen = { _ in requests += 1 }; view.onReveal = { _ in requests += 1 }
        view.onMoveToTrash = { _ in requests += 1 }
        for button in [view.openButton, view.revealButton, view.removalButton] {
            XCTAssertFalse(try XCTUnwrap(button).isEnabled)
        }
        view.openSelection(nil); view.revealSelection(nil); view.moveSelectionToTrash(nil)
        XCTAssertEqual(requests, 0)
        view.setAppActionsBlocked(true); view.setAppActionsBlocked(false)
        XCTAssertFalse(try XCTUnwrap(view.openButton).isEnabled)
        XCTAssertTrue(try XCTUnwrap(view.aliasButton).isEnabled)
        XCTAssertTrue(view.backButton.isEnabled)
    }

    func testHostExecutionGuardsRejectFinderRemovalAndSharedLaunch() throws {
        var options = AppArguments.Options.default; options.gestureValidation = true
        let owner = AppDelegate(options: options)
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [])
        defer { surface.teardown(); assembly.teardown() }
        let id = AppID.bundleIdentifier("fixture.gesture.refusal")
        let record = CatalogFixture.record(id: id, displayName: "Fixture", bundleID: "fixture.gesture.refusal",
            url: URL(fileURLWithPath: "/Synthetic/Fixture.app"), icon: .from(appID: id), rootPriority: 0)
        assembly.provider.receive(.init(revision: CatalogRevision(1), records: [record]))
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        let executor = RecordingLauncher()
        let launch = AppLaunchController(surface: surface, assembly: assembly, launcher: executor)
        owner.installLaunchAttemptFeedback(launch, assembly: assembly)
        XCTAssertEqual(launch.handleApp(appID: id, expectedRevision: CatalogRevision(1), expectedURL: record.canonicalURL), .rejectedNoBinding)
        XCTAssertTrue(executor.opened.isEmpty)
        var reveals = 0; owner.fileRevealRequester = { _ in reveals += 1 }
        XCTAssertEqual(owner.handleFinderReveal(record), .rejectedUnavailable)
        XCTAssertEqual(reveals, 0)
        owner.beginAppRemoval(record, additionalValidation: { XCTFail("No removal admission may run"); return true })
        XCTAssertNil(owner.appRemovalCoordinator)
        owner.teardownActionFeedback()
    }

    func testNativeActivationRestrictionSurvivesReloadAndRelabel() throws {
        let strings = LocalizedStrings(language: .english)
        let controller = ActivationSettingsWindowController(draft: .init(), strings: strings)
        defer { controller.hideSettings(); controller.window?.delegate = nil; controller.window?.contentView = nil }
        controller.fourFingerValidationOnly = true
        let tabs = try XCTUnwrap(controller.window?.contentView as? NSTabView)
        let root = try XCTUnwrap(tabs.tabViewItems.first { $0.identifier as? String == "activation" }?.view)
        for language in [InterfaceLanguage.english, .japanese, .simplifiedChinese] {
            controller.reload(draft: GestureValidationPolicy.draft(.init(committed: hostilePreferences())))
            let strings = LocalizedStrings(language: language)
            controller.relabel(strings: strings)
            for key in [ActivationTextKey.globalShortcutEnable, .hotCornerEnable, .launchAtLoginEnable] {
                let button = descendants(root).compactMap { $0 as? NSButton }.first { $0.title == strings.activationText(key) }
                XCTAssertFalse(try XCTUnwrap(button).isEnabled)
            }
            let gesture = descendants(root).compactMap { $0 as? NSButton }.first { $0.title == strings.activationText(.fourFingerEnable) }
            XCTAssertTrue(try XCTUnwrap(gesture).isEnabled)
        }
    }

    func testDedicatedWindowCanPresentInFrontWithoutChangingOrdinaryWindowGeometry() {
        _ = NSApplication.shared
        let owner = LauncherWindowController(reduceMotionProvider: { true })
        let window = GestureValidationOrderingWindow(contentRect: NSRect(x: 40, y: 80, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let frame = window.frame
        var activations = 0
        XCTAssertFalse(owner.foregroundWindowedPresentation)
        owner.backgroundUITestMode = true
        owner.foregroundWindowedPresentation = true
        owner.activateWindowedApplication = { activations += 1 }
        owner.attach(window: window)
        defer { _ = owner.terminate() }
        _ = owner.show(source: .fourFingerPinch, targetScreen: ScreenID(index: 0))
        XCTAssertEqual(window.frontRequests, 1)
        XCTAssertEqual(window.backRequests, 0)
        XCTAssertEqual(activations, 1)
        XCTAssertEqual(window.frame, frame)
        XCTAssertEqual(window.level, .normal)
        XCTAssertEqual(window.collectionBehavior, [])
        XCTAssertTrue(window.styleMask.contains(.titled))
        XCTAssertFalse(window.styleMask.contains(.fullScreen))
    }

}
