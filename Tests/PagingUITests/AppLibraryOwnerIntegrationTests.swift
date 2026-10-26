import AppCatalogCore
import AppGridUI
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

private actor NativeLibraryTestStore: AppLibraryPersisting {
    var value: AppLibraryPreferences
    var saveResult: AppLibrarySaveResult
    init(enabled: Bool = true, saveResult: AppLibrarySaveResult = .saved) {
        value = .init(enabled: enabled)
        self.saveResult = saveResult
    }
    func load() -> AppLibraryLoadResult { .loaded(value) }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) -> AppLibrarySaveResult {
        if saveResult == .saved { value = preferences }
        return saveResult
    }
}

private actor BootstrapProjectionGate {
    private var completion: CheckedContinuation<AppLibrarySnapshot?, Never>?
    private(set) var started = false
    func run(_ request: AppLibraryProjectionRequest) async -> AppLibrarySnapshot? {
        started = true
        return await withCheckedContinuation { completion = $0 }
    }
    func finish() { completion?.resume(returning: nil); completion = nil }
}

@MainActor
final class AppLibraryOwnerIntegrationTests: XCTestCase {
    private func record(_ name: String = "Alpha") -> AppRecord {
        let id = AppID.bundleIdentifier("fixture.library." + name)
        return .init(id: id, displayName: name, bundleIdentifier: "fixture.library." + name,
            canonicalURL: URL(fileURLWithPath: "/SyntheticLibrary/" + name + ".app"),
            iconIdentity: .from(appID: id), sourceRootPriority: 0)
    }
    private func waitUntil(_ condition: () -> Bool) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !condition(), ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertTrue(condition())
    }
    private func owner(enabled: Bool = true) async -> (AppLibraryOwnerController, NSView, AppLibraryProjectionController) {
        let preferences = AppLibraryPreferencesCoordinator(store: NativeLibraryTestStore(enabled: enabled))
        let projection = AppLibraryProjectionController()
        let owner = AppLibraryOwnerController(preferences: preferences, strings: .init(language: .english), projection: projection)
        let host = NSView(frame: .init(x: 0, y: 0, width: 960, height: 700))
        owner.canTransition = { true }
        owner.canExecuteAction = { true }
        owner.captureGrid = { .init(query: "saved-grid-query", page: 2, selection: nil, searchWasFocused: true) }
        owner.catalogProvider = { .init(revision: .init(1), records: [self.record()]) }
        owner.attach(to: host)
        await preferences.loadIfNeeded()
        return (owner, host, projection)
    }

    func testDisabledLibraryAllocatesNoViewAndStartsNoProjection() async {
        let (owner, host, projection) = await owner(enabled: false)
        XCTAssertFalse(owner.enter())
        XCTAssertNil(owner.view)
        XCTAssertFalse(projection.isOpen)
        XCTAssertTrue(owner.entryButton?.isHidden == true)
        XCTAssertEqual(host.subviews.count, 1, "Only hidden discoverability control, not a Library subtree")
        owner.teardown()
    }

    func testEnterBackPreservesEphemeralGridContextAndReleasesLibrary() async {
        let (owner, host, projection) = await owner()
        var changes: [Bool] = [], restored: AppLibraryGridReturnContext?
        owner.setGridHidden = { changes.append($0) }
        owner.restoreGrid = { restored = $0 }
        XCTAssertTrue(owner.enter())
        XCTAssertTrue(owner.view?.superview === host)
        XCTAssertTrue(owner.entryButton?.isHidden == true)
        await waitUntil { projection.snapshot != nil }
        owner.back()
        XCTAssertEqual(changes, [true, false])
        XCTAssertEqual(restored?.query, "saved-grid-query")
        XCTAssertEqual(restored?.page, 2)
        XCTAssertTrue(restored?.searchWasFocused == true)
        XCTAssertNil(owner.view)
        XCTAssertFalse(projection.isOpen)
        owner.teardown()
    }

    func testHideResetsLibraryWithoutRestoringOldQueryOrReopeningFolder() async {
        let (owner, host, projection) = await owner()
        var restores = 0, preparations = 0
        owner.restoreGrid = { _ in restores += 1 }
        owner.prepareEntry = { preparations += 1 }
        XCTAssertTrue(owner.enter())
        _ = host
        await waitUntil { projection.snapshot != nil }
        owner.hide()
        XCTAssertEqual(restores, 0)
        XCTAssertFalse(owner.isOpen)
        XCTAssertTrue(owner.enter())
        XCTAssertEqual(owner.view?.query, "")
        XCTAssertEqual(preparations, 2)
        owner.teardown()
    }

    func testProtectedTransitionsRejectBeforeCancellingGrid() async {
        let (owner, host, _) = await owner()
        _ = host
        var cancellations = 0
        owner.prepareEntry = { cancellations += 1 }
        owner.canTransition = { false }
        XCTAssertFalse(owner.enter())
        XCTAssertEqual(cancellations, 0)
        XCTAssertNil(owner.view)
        owner.teardown()
    }

    func testSourceChangeInvalidatesSelectionUntilNewerCommittedCatalog() async {
        let (owner, host, projection) = await owner()
        _ = host
        let app = record()
        var catalog = CatalogSnapshot(revision: .init(1), records: [app])
        owner.catalogProvider = { catalog }
        XCTAssertTrue(owner.enter())
        await waitUntil { projection.snapshot != nil }
        let stale = AppLibraryActionRequest(record: app, catalogRevision: catalog.revision, generation: owner.actionGeneration)
        XCTAssertNotNil(owner.resolve(stale))
        owner.invalidateSourceTargets()
        XCTAssertNil(owner.resolve(stale))
        owner.noteCatalogRefreshState(.partialFailure)
        XCTAssertEqual(owner.view?.statusLabel.stringValue, LocalizedStrings(language: .english).libraryText(.unavailable))
        XCTAssertTrue(owner.view?.statusLabel.isHidden == false)
        XCTAssertNil(owner.resolve(stale), "Failure feedback must not reopen old-source actions")
        owner.catalogDidCommit()
        XCTAssertNil(projection.snapshot, "Same-revision metadata updates cannot acknowledge source replacement")
        catalog = .init(revision: .init(2), records: [app])
        owner.catalogDidCommit()
        await waitUntil { projection.snapshot?.revision == .init(2) }
        XCTAssertNil(owner.resolve(stale))
        let fresh = AppLibraryActionRequest(record: app, catalogRevision: catalog.revision, generation: owner.actionGeneration)
        XCTAssertNotNil(owner.resolve(fresh))
        owner.teardown()
    }

    func testHiddenOrChangedURLNeverExecutesOldLibrarySelection() async {
        let (owner, host, projection) = await owner()
        _ = host
        let app = record()
        var management = AppManagementPreferences.default
        owner.managementProvider = { management }
        XCTAssertTrue(owner.enter())
        await waitUntil { projection.snapshot != nil }
        let request = AppLibraryActionRequest(record: app, catalogRevision: .init(1), generation: owner.actionGeneration)
        var opens = 0
        owner.openApp = { _, _ in opens += 1 }
        owner.view?.onOpen?(request)
        XCTAssertEqual(opens, 1)
        management = management.settingHidden(true, for: app)
        owner.view?.onOpen?(request)
        XCTAssertEqual(opens, 1)
        management = .default
        owner.catalogProvider = {
            .init(revision: .init(1), records: [.init(id: app.id, displayName: app.displayName,
                bundleIdentifier: app.bundleIdentifier, canonicalURL: URL(fileURLWithPath: "/Changed.app"),
                iconIdentity: app.iconIdentity, sourceRootPriority: 0)])
        }
        owner.view?.onOpen?(request)
        XCTAssertEqual(opens, 1)
        owner.teardown()
    }

    func testCategoryWritesCommitSharedPreferencesWithoutCatalogOrLayoutMutation() async {
        let (owner, host, projection) = await owner()
        _ = host
        let app = record()
        XCTAssertTrue(owner.enter())
        await waitUntil { projection.snapshot != nil }
        let request = AppLibraryActionRequest(record: app, catalogRevision: .init(1), generation: owner.actionGeneration)
        owner.view?.onSetCategory?(request, .music)
        _ = await owner.preferences.drain()
        await waitUntil { projection.snapshot?.entries.first?.category == .music }
        XCTAssertEqual(projection.snapshot?.revision, .init(1))
        XCTAssertEqual(owner.preferences.committed.category(for: app), .music)
        XCTAssertNil(owner.resolve(request), "Accepted write refresh invalidates its original action packet")
        owner.teardown()
    }

    func testLifecycleReadinessBlocksPublicActionButModalBindingStillUsesCurrentEpoch() async {
        let (owner, host, projection) = await owner()
        _ = host
        let app = record()
        XCTAssertTrue(owner.enter())
        await waitUntil { projection.snapshot != nil }
        let request = AppLibraryActionRequest(record: app, catalogRevision: .init(1), generation: owner.actionGeneration)
        owner.canExecuteAction = { false }
        XCTAssertNil(owner.resolve(request))
        XCTAssertNotNil(owner.resolve(request, checkingReadiness: false))
        owner.hide()
        XCTAssertNil(owner.resolve(request, checkingReadiness: false))
        owner.teardown()
    }

    func testCategorySaveFailureNotifiesActiveSessionAndPreservesBaseline() async {
        let preferences = AppLibraryPreferencesCoordinator(store: NativeLibraryTestStore(saveResult: .failed))
        let projection = AppLibraryProjectionController()
        let owner = AppLibraryOwnerController(preferences: preferences, strings: .init(language: .english), projection: projection)
        let host = NSView(frame: .init(x: 0, y: 0, width: 960, height: 700))
        owner.canTransition = { true }
        owner.canExecuteAction = { true }
        owner.captureGrid = { .init(query: "", page: 0, selection: nil, searchWasFocused: false) }
        let app = record()
        owner.catalogProvider = { .init(revision: .init(1), records: [app]) }
        owner.attach(to: host)
        await preferences.loadIfNeeded()
        var failures = 0
        owner.onCategorySaveFailure = { failures += 1 }
        XCTAssertTrue(owner.enter())
        await waitUntil { projection.snapshot != nil }
        let request = AppLibraryActionRequest(record: app, catalogRevision: .init(1), generation: owner.actionGeneration)
        owner.view?.onSetCategory?(request, .music)
        _ = await preferences.drain()
        XCTAssertEqual(failures, 1)
        XCTAssertEqual(preferences.committed.category(for: app), .other)
        XCTAssertTrue(preferences.requiresQuitProtection)
        owner.hide()
        XCTAssertTrue(owner.enter())
        await waitUntil { projection.snapshot != nil }
        XCTAssertEqual(failures, 1, "Do not replay obsolete failure into a new Library session")
        owner.teardown()
    }

    func testFinalProductionRefreshCompositionRetainsConsumerAndLibraryFailureDelivery() async throws {
        let app = AppDelegate(options: .default)
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticSourceFailure")], loader: RecordingIconLoader())
        app.surface = surface; app.assembly = assembly
        surface.contentProvider = assembly.provider
        surface.renderer = assembly.renderer
        var observed: [AppGridUIState] = []
        assembly.refreshController.onStateChange = { observed.append($0) }
        // This is the actual final startup composition, not an isolated first helper.
        app.installFinalCatalogRuntimeCallbacks(assembly: assembly, surface: surface)
        let appRecord = record()
        assembly.provider.receive(.init(revision: .init(1), records: [appRecord]))
        _ = assembly.provider.applyPending(atCurrentPage: 0, itemsPerPage: 35)
        let host = NSView(frame: .init(x: 0, y: 0, width: 960, height: 700))
        app.installAppLibrary(in: host, store: NativeLibraryTestStore())
        let owner = try XCTUnwrap(app.appLibraryOwner)
        defer { owner.teardown(); assembly.teardown(); surface.teardown() }
        await owner.preferences.loadIfNeeded()
        owner.canTransition = { true }; owner.canExecuteAction = { true }
        owner.captureGrid = { .init(query: "", page: 0, selection: nil, searchWasFocused: false) }
        XCTAssertTrue(owner.enter())
        // Startup projection refreshes may revoke a request before readiness. Wait
        // against the current generation, then pin a usable request for revocation.
        await waitUntil {
            let current = AppLibraryActionRequest(record: appRecord, catalogRevision: .init(1),
                                                  generation: owner.actionGeneration)
            return owner.resolve(current) != nil
        }
        let stale = AppLibraryActionRequest(record: appRecord, catalogRevision: .init(1), generation: owner.actionGeneration)
        XCTAssertNotNil(owner.resolve(stale))
        owner.invalidateSourceTargets()
        XCTAssertNil(owner.resolve(stale))
        assembly.refreshController.onStateChange?(.partialFailure)
        XCTAssertEqual(observed, [.partialFailure])
        XCTAssertEqual(owner.view?.statusLabel.stringValue, LocalizedStrings(language: .english).libraryText(.unavailable))
        XCTAssertNil(owner.resolve(stale))
        assembly.refreshController.onStateChange?(.refreshing)
        XCTAssertEqual(observed, [.partialFailure, .refreshing])
        XCTAssertEqual(owner.view?.statusLabel.stringValue, LocalizedStrings(language: .english).libraryText(.loading))
        XCTAssertNil(owner.resolve(stale))
        assembly.refreshController.onStateChange?(.partialFailure)
        owner.catalogDidCommit()
        XCTAssertEqual(observed, [.partialFailure, .refreshing, .partialFailure])
        XCTAssertEqual(owner.view?.statusLabel.stringValue, LocalizedStrings(language: .english).libraryText(.unavailable))
    }

    func testBootstrapLoadingFailureRetryAndFirstEmptyCommitUseActualFinalFanout() async throws {
        let app = AppDelegate(options: .default)
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticBootstrap")], loader: RecordingIconLoader())
        app.surface = surface; app.assembly = assembly
        surface.contentProvider = assembly.provider; surface.renderer = assembly.renderer
        app.installFinalCatalogRuntimeCallbacks(assembly: assembly, surface: surface)
        let host = NSView(frame: .init(x: 0, y: 0, width: 960, height: 700))
        app.installAppLibrary(in: host, store: NativeLibraryTestStore())
        let owner = try XCTUnwrap(app.appLibraryOwner)
        defer { owner.teardown(); assembly.teardown(); surface.teardown() }
        await owner.preferences.loadIfNeeded()
        owner.canTransition = { true }; owner.canExecuteAction = { true }
        owner.captureGrid = { .init(query: "", page: 0, selection: nil, searchWasFocused: false) }
        XCTAssertTrue(owner.enter())
        let strings = LocalizedStrings(language: .english)
        XCTAssertEqual(owner.view?.statusLabel.stringValue, strings.libraryText(.loading))
        assembly.refreshController.onStateChange?(.partialFailure)
        XCTAssertEqual(owner.view?.statusLabel.stringValue, strings.libraryText(.unavailable))
        assembly.refreshController.onStateChange?(.loading)
        XCTAssertEqual(owner.view?.statusLabel.stringValue, strings.libraryText(.loading))
        assembly.provider.receive(.init(revision: .init(1), records: []))
        _ = assembly.provider.applyPending(atCurrentPage: 0, itemsPerPage: 35)
        owner.catalogDidCommit()
        assembly.refreshController.onStateChange?(.empty)
        await waitUntil { owner.view?.statusLabel.stringValue == strings.libraryText(.empty) }
        let absent = record()
        let request = AppLibraryActionRequest(record: absent, catalogRevision: .init(1), generation: owner.actionGeneration)
        XCTAssertNil(owner.resolve(request))
    }

    func testDiscardedSourceProjectionCannotMaskCompletedSourceFailure() async {
        let gate = BootstrapProjectionGate()
        let projection = AppLibraryProjectionController(work: { await gate.run($0) })
        let preferences = AppLibraryPreferencesCoordinator(store: NativeLibraryTestStore())
        let owner = AppLibraryOwnerController(preferences: preferences, strings: .init(language: .english), projection: projection)
        let host = NSView(frame: .init(x: 0, y: 0, width: 960, height: 700))
        let app = record()
        owner.catalogProvider = { .init(revision: .init(1), records: [app]) }
        owner.canTransition = { true }; owner.canExecuteAction = { true }
        owner.captureGrid = { .init(query: "", page: 0, selection: nil, searchWasFocused: false) }
        owner.attach(to: host)
        await preferences.loadIfNeeded()
        XCTAssertTrue(owner.enter())
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while await !gate.started, ContinuousClock.now < deadline { await Task.yield() }
        owner.invalidateSourceTargets()
        owner.noteCatalogRefreshState(.partialFailure)
        XCTAssertTrue(projection.isProjecting, "Discarded worker is intentionally still owned until completion")
        XCTAssertFalse(projection.isOpen)
        let expected = LocalizedStrings(language: .english).libraryText(.unavailable)
        XCTAssertEqual(owner.view?.statusLabel.stringValue, expected,
                       "Obsolete work cannot obscure a terminal source failure")
        await gate.finish()
        await waitUntil { !projection.isProjecting }
        XCTAssertEqual(owner.view?.statusLabel.stringValue, expected)
        let stale = AppLibraryActionRequest(record: app, catalogRevision: .init(1), generation: owner.actionGeneration)
        XCTAssertNil(owner.resolve(stale))
        owner.teardown()
    }
}
