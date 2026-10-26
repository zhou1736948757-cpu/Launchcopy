import AppKit
import AppCatalogCore
import AppGridUI
import LauncherLocalization
import MacAppCatalog
import XCTest
@testable import PagingPrototypeApp

private actor PreviewLibraryStore: AppLibraryPersisting {
    func load() async -> AppLibraryLoadResult { .missing }
    func save(_ value: AppLibraryPreferences, recoveringCorruptPayload: Bool) async -> AppLibrarySaveResult { .saved }
}

@MainActor
final class IntegratedPreviewRuntimeTests: XCTestCase {
    private func options() -> AppArguments.Options {
        var value = AppArguments.Options.default
        value.integratedPreview = true; value.uiTestWindowed = true; value.uiTestProfile = "integrated"
        return value
    }
    private func withBundle(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = root.appendingPathComponent(".build/candidates/preview/Preview.app")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        try body(bundle)
    }
    func testRealGestureFactoryIsLazyIdempotentAndHasNoOtherRealAdapters() {
        let owner = LauncherRuntimeServices.integratedPreviewActivation(launcher: LauncherWindowController(), requestTerminate: {})
        defer { owner.teardownActivationServices() }
        XCTAssertTrue(owner.shortcutRegistrar is FakeGlobalShortcutRegistrar)
        XCTAssertTrue(owner.sessionObserver is FakeWorkspaceSessionObserver)
        XCTAssertNil(owner.touchProvider)
        let provider = MockTouchProvider(clock: FakePinchClock())
        var calls = 0
        let factory: () -> any TouchProvider = { calls += 1; return provider }
        var prefs = ActivationPreferences(fourFingerOutwardHideEnabled: true)
        prefs.fourFingerActivationEnabled = false
        LauncherRuntimeServices.applyIntegratedPreviewPreferences(prefs, to: owner, makeTouchProvider: factory)
        XCTAssertEqual(calls, 0)
        prefs.fourFingerActivationEnabled = true
        prefs.settings.globalShortcutEnabled = true; prefs.settings.hotCornerEnabled = true
        prefs.settings.selectedCorner = .topLeft; prefs.settings.launchAtLoginEnabled = true
        for _ in 0..<3 { LauncherRuntimeServices.applyIntegratedPreviewPreferences(prefs, to: owner, makeTouchProvider: factory) }
        XCTAssertEqual(calls, 1); XCTAssertTrue(provider.isStarted)
        XCTAssertNil(owner.appliedPlan.globalShortcut); XCTAssertNil(owner.appliedPlan.hotCorner)
        prefs.fourFingerActivationEnabled = false
        LauncherRuntimeServices.applyIntegratedPreviewPreferences(prefs, to: owner, makeTouchProvider: factory)
        XCTAssertFalse(provider.isStarted)
        owner.teardownActivationServices()
        prefs.fourFingerActivationEnabled = true
        LauncherRuntimeServices.applyIntegratedPreviewPreferences(prefs, to: owner, makeTouchProvider: factory)
        XCTAssertEqual(calls, 1); XCTAssertFalse(provider.isStarted)
    }
    func testHostRequiresIsolatedProfileAndRefusesRootOverrides() throws {
        var invalid = options(); invalid.uiTestProfile = nil
        XCTAssertThrowsError(try AppDelegate(options: invalid).configureUITestProfile(bundleURL: URL(fileURLWithPath: "/Missing.app")))
        try withBundle { bundle in
            var invalid = options(); invalid.catalogRoots = [URL(fileURLWithPath: "/Applications")]
            let host = AppDelegate(options: invalid)
            XCTAssertThrowsError(try host.configureUITestProfile(bundleURL: bundle))
            XCTAssertNil(host.uiTestProfile); XCTAssertNil(host.makeContentAssembly())
            let unconfigured = AppDelegate(options: options())
            XCTAssertNil(unconfigured.makeContentAssembly())
        }
    }
    func testPreviewHasFixedRealRootsButOwnWritesAndNoSourceOrActivityCoordinator() throws {
        try withBundle { bundle in
            let host = AppDelegate(options: options())
            try host.configureUITestProfile(bundleURL: bundle)
            let profile = try XCTUnwrap(host.uiTestProfile)
            let assembly = try XCTUnwrap(host.makeContentAssembly())
            defer { assembly.teardown(); host.appLibraryOwner?.teardown() }
            XCTAssertEqual(assembly.scanRoots, CatalogRoots.defaults)
            XCTAssertNotEqual(assembly.scanRoots, [profile.applicationsDirectoryURL])
            XCTAssertTrue(profile.layoutDirectoryURL.path.hasPrefix(bundle.deletingLastPathComponent().path))
            host.installAppSources(assembly: assembly)
            XCTAssertNil(host.appSourcesCoordinator)
            host.installAppLibrary(in: NSView(), store: PreviewLibraryStore())
            let library = try XCTUnwrap(host.appLibraryOwner)
            XCTAssertNil(library.activity)
            XCTAssertTrue(library.allowsExternalApplicationActions)
            XCTAssertFalse(library.allowsApplicationRemoval)
            XCTAssertFalse(FileManager.default.fileExists(atPath: profile.rootURL.appendingPathComponent("LaunchActivity").path))
            let controller = ActivationSettingsWindowController(draft: .init(), strings: .init(language: .english))
            defer { controller.hideSettings(); controller.window?.delegate = nil; controller.window?.contentView = nil }
            host.configureAppSourcesSettings(controller)
            XCTAssertFalse(controller.appSourcesView.addButton.isEnabled)
            XCTAssertFalse(controller.appSourcesView.refreshButton.isEnabled)
        }
    }
    func testPreviewSharedLaunchRemainsAvailableWhileRemovalExecutorRejects() throws {
        try withBundle { bundle in
            let target = bundle.deletingLastPathComponent().appendingPathComponent("Owned.app")
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            let host = AppDelegate(options: options())
            let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
            let assembly = AppCatalogAssembly(roots: [target.deletingLastPathComponent()])
            defer { host.teardownActionFeedback(); surface.teardown(); assembly.teardown() }
            let id = AppID.bundleIdentifier("fixture.preview.target")
            let record = CatalogFixture.record(id: id, displayName: "Fixture", bundleID: "fixture.preview.target",
                url: target, icon: .from(appID: id), rootPriority: 0)
            assembly.provider.receive(.init(revision: CatalogRevision(1), records: [record]))
            _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
            let executor = RecordingLauncher()
            let launch = AppLaunchController(surface: surface, assembly: assembly, launcher: executor)
            host.installLaunchAttemptFeedback(launch, assembly: assembly)
            XCTAssertEqual(launch.handleApp(appID: id, expectedRevision: CatalogRevision(1),
                expectedURL: URL(fileURLWithPath: "/Wrong.app")), .rejectedMissingApp)
            XCTAssertTrue(executor.opened.isEmpty)
            XCTAssertEqual(launch.handleApp(appID: id, expectedRevision: CatalogRevision(1),
                expectedURL: record.canonicalURL), .launched)
            XCTAssertEqual(executor.opened, [record.canonicalURL])
            host.beginAppRemoval(record, additionalValidation: { XCTFail("Removal must reject before admission"); return true })
            XCTAssertNil(host.appRemovalCoordinator)
        }
    }
    func testLibraryKeepsLaunchButHidesAndRejectsRemovalEvenDirectly() throws {
        let view = AppLibraryView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700), strings: .init(language: .english))
        defer { view.reset() }
        view.allowsApplicationRemoval = false
        let id = AppID.bundleIdentifier("fixture.preview.target")
        let record = CatalogFixture.record(id: id, displayName: "Fixture", bundleID: "fixture.preview.target",
            url: URL(fileURLWithPath: "/Synthetic/Preview.app"), icon: .from(appID: id), rootPriority: 0)
        let entry = AppLibraryEntry(record: record, displayName: record.displayName, category: .utilities, manualCategory: nil)
        view.apply(snapshot: .init(revision: CatalogRevision(1), entries: [entry], counts: [.utilities: 1]),
            isLoading: false, catalogIsEmpty: false, actionGeneration: 1)
        var removals = 0; var launches = 0
        view.onMoveToTrash = { _ in removals += 1 }; view.onOpen = { _ in launches += 1 }
        view.resultsTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        view.tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification, object: view.resultsTable))
        view.showDetails(nil)
        XCTAssertTrue(try XCTUnwrap(view.removalButton).isHidden)
        XCTAssertFalse(try XCTUnwrap(view.removalButton).isEnabled)
        XCTAssertTrue(try XCTUnwrap(view.openButton).isEnabled)
        view.moveSelectionToTrash(nil); view.openSelection(nil)
        XCTAssertEqual(removals, 0); XCTAssertEqual(launches, 1)
        view.relabel(strings: .init(language: .japanese))
        XCTAssertTrue(try XCTUnwrap(view.removalButton).isHidden)
    }
    func testNormalizedSettingsApplyCannotPersistOrRegisterOtherGlobals() {
        let initial = ActivationPreferences()
        let store = InMemoryActivationPreferencesStore(initial: initial)
        let login = FakeLaunchAtLoginService()
        var runtime: ActivationPreferences?
        let coordinator = ActivationSettingsCoordinator(store: store, loginService: login,
            initialCommitted: initial, applyPreferences: { runtime = $0 })
        coordinator.normalizeDraft = IntegratedPreviewPolicy.draft
        var bad = initial; bad.fourFingerOutwardHideEnabled = true
        bad.settings.globalShortcutEnabled = true; bad.settings.hotCornerEnabled = true
        bad.settings.selectedCorner = .topLeft; bad.settings.launchAtLoginEnabled = true
        _ = coordinator.applyDraft(.init(committed: bad))
        XCTAssertEqual(login.setEnabledCallCount, 0)
        XCTAssertEqual(runtime?.settings, ActivationSettings())
        XCTAssertTrue(coordinator.committed.fourFingerOutwardHideEnabled)
        XCTAssertEqual(store.load(), .loaded(coordinator.committed))
    }
}
