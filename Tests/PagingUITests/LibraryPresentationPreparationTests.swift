import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

private actor PreparationLibraryStore: AppLibraryPersisting {
    var value: AppLibraryPreferences
    init(enabled: Bool) { value = .init(enabled: enabled) }
    func load() -> AppLibraryLoadResult { .loaded(value) }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) -> AppLibrarySaveResult {
        value = preferences; return .saved
    }
}

/// Construction/admission counters on a detached synthetic fixture, not a claim
/// of measured frame-time reduction or real trackpad acceptance.
@MainActor
final class LibraryPresentationPreparationTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let host = NSView(frame: .init(x: 0, y: 0, width: 1000, height: 700))
        let projection = AppLibraryProjectionController()
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: IconCacheLimits())
        let preferences: AppLibraryPreferencesCoordinator
        let owner: AppLibraryOwnerController
        var ready = true
        var catalog: CatalogSnapshot
        init(enabled: Bool = true, ready: Bool = true) {
            self.ready = ready
            preferences = AppLibraryPreferencesCoordinator(store: PreparationLibraryStore(enabled: enabled))
            owner = AppLibraryOwnerController(preferences: preferences, strings: .init(language: .english), iconPipeline: pipeline, projection: projection)
            let id = AppID.bundleIdentifier("fixture.prepared.library")
            let record = AppRecord(id: id, displayName: "Prepared Fixture", bundleIdentifier: "fixture.prepared.library",
                canonicalURL: URL(fileURLWithPath: "/SyntheticPreparation/Fixture.app"), iconIdentity: .from(appID: id), sourceRootPriority: 0)
            catalog = .init(revision: .init(1), records: [record])
            owner.catalogProvider = { [weak self] in self?.catalog }
            owner.canTransition = { [weak self] in self?.ready == true }
            owner.canExecuteAction = { true }
            owner.captureGrid = { .init(query: "", page: 0, selection: nil, searchWasFocused: false) }
            owner.attach(to: host, showsEntryButton: false)
        }
        func teardown() { owner.teardown(); pipeline.shutdown() }
    }
    private func waitUntil(_ condition: () -> Bool) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !condition(), ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertTrue(condition())
    }
    private func drain() async { for _ in 0..<12 { await Task.yield() } }

    func testIdlePreparationConstructsOnlyOneEmptyDetachedInertShell() async {
        let f = Fixture(); defer { f.teardown() }
        await f.preferences.loadIfNeeded()
        await waitUntil { f.owner.hasPreparedPresentation }
        XCTAssertEqual(f.owner.presentationConstructionCount, 1)
        XCTAssertFalse(f.owner.isOpen); XCTAssertNil(f.owner.view)
        XCTAssertTrue(f.host.subviews.isEmpty)
        XCTAssertFalse(f.projection.isOpen); XCTAssertNil(f.projection.snapshot)
        XCTAssertEqual(f.pipeline.stats.requests, 0)
        for _ in 0..<20 { f.owner.refreshReadiness() }
        await drain()
        XCTAssertEqual(f.owner.presentationConstructionCount, 1)
    }
    func testFirstPreviewConsumesPreparedShellWithoutConstructingOnEntry() async throws {
        let f = Fixture(); defer { f.teardown() }
        await f.preferences.loadIfNeeded()
        await waitUntil { f.owner.hasPreparedPresentation }
        let count = f.owner.presentationConstructionCount
        XCTAssertTrue(f.owner.enter(preview: true))
        XCTAssertEqual(f.owner.presentationConstructionCount, count)
        XCTAssertFalse(f.owner.hasPreparedPresentation)
        let view = try XCTUnwrap(f.owner.view)
        XCTAssertTrue(view.isAccessibilityHidden())
        f.owner.cancelPreview()
        XCTAssertNil(f.owner.view); XCTAssertNil(view.superview)
        XCTAssertTrue(f.owner.hasPreparedPresentation)
        XCTAssertFalse(f.projection.isOpen); XCTAssertNil(f.projection.snapshot)
        XCTAssertTrue(f.owner.enter(preview: true))
        XCTAssertTrue(f.owner.view === view)
        XCTAssertEqual(f.owner.presentationConstructionCount, count)
    }
    func testCloseReusesResetShellButRevokesPriorActionAndDraft() async throws {
        let f = Fixture(); defer { f.teardown() }
        await f.preferences.loadIfNeeded()
        XCTAssertTrue(f.owner.enter())
        await waitUntil { f.projection.snapshot != nil }
        let view = try XCTUnwrap(f.owner.view)
        let record = try XCTUnwrap(f.catalog.records.first)
        let old = AppLibraryActionRequest(record: record, catalogRevision: f.catalog.revision, generation: f.owner.actionGeneration)
        view.searchField.stringValue = "draft"
        view.controlTextDidChange(.init(name: NSControl.textDidChangeNotification, object: view.searchField))
        let constructions = f.owner.presentationConstructionCount
        f.owner.back()
        XCTAssertEqual(view.query, ""); XCTAssertEqual(view.resultsTable.numberOfRows, 0)
        XCTAssertNil(f.projection.snapshot)
        XCTAssertNil(f.owner.resolve(old, checkingReadiness: false))
        XCTAssertTrue(f.owner.enter())
        XCTAssertTrue(f.owner.view === view)
        XCTAssertEqual(f.owner.presentationConstructionCount, constructions)
        XCTAssertEqual(view.query, "")
        XCTAssertNil(f.owner.resolve(old, checkingReadiness: false))
    }
    func testDisabledFeatureDoesNoPreparationAndDropsRetainedShellOnOptOut() async {
        let f = Fixture(enabled: false); defer { f.teardown() }
        await f.preferences.loadIfNeeded(); await drain()
        XCTAssertFalse(f.owner.hasPreparedPresentation)
        XCTAssertEqual(f.owner.presentationConstructionCount, 0)
        XCTAssertTrue(f.preferences.submit(.init(enabled: true)))
        await waitUntil { f.owner.hasPreparedPresentation }
        XCTAssertTrue(f.preferences.submit(.init(enabled: false)))
        await waitUntil { !f.preferences.committed.enabled && f.preferences.pendingCount == 0 }
        XCTAssertFalse(f.owner.hasPreparedPresentation)
        await drain()
        XCTAssertFalse(f.owner.hasPreparedPresentation)
        XCTAssertFalse(f.owner.enter())
    }
    func testBusyGridDefersConstructionUntilReadinessRetry() async {
        let f = Fixture(ready: false); defer { f.teardown() }
        await f.preferences.loadIfNeeded(); await drain()
        XCTAssertEqual(f.owner.presentationConstructionCount, 0)
        f.ready = true; f.owner.refreshReadiness()
        await waitUntil { f.owner.hasPreparedPresentation }
        XCTAssertEqual(f.owner.presentationConstructionCount, 1)
    }
    func testTeardownCancelsQueuedPreparationAndDropsCache() async {
        let f = Fixture()
        await f.preferences.loadIfNeeded()
        f.owner.refreshReadiness(); f.owner.teardown()
        let count = f.owner.presentationConstructionCount
        await drain()
        XCTAssertFalse(f.owner.hasPreparedPresentation)
        XCTAssertEqual(f.owner.presentationConstructionCount, count)
        XCTAssertNil(f.owner.view); XCTAssertTrue(f.host.subviews.isEmpty)
        f.pipeline.shutdown()
    }
    func testPreparedShellUsesCurrentLanguageAndBoundsOnEntry() async throws {
        let f = Fixture(); defer { f.teardown() }
        await f.preferences.loadIfNeeded()
        await waitUntil { f.owner.hasPreparedPresentation }
        f.owner.relabel(strings: .init(language: .japanese))
        f.host.setFrameSize(.init(width: 700, height: 500))
        XCTAssertTrue(f.owner.enter(preview: true))
        let view = try XCTUnwrap(f.owner.view)
        XCTAssertEqual(view.frame, f.host.bounds.insetBy(dx: 16, dy: 12))
        XCTAssertEqual(view.searchField.placeholderString, LocalizedStrings(language: .japanese).text(.searchPlaceholder))
        XCTAssertEqual(view.layer?.affineTransform(), .identity)
        XCTAssertEqual(view.layer?.opacity, 1)
    }
    func testCatalogChangesNeverMakePreparedShellAnActionableSnapshotCache() async {
        let f = Fixture(); defer { f.teardown() }
        await f.preferences.loadIfNeeded()
        await waitUntil { f.owner.hasPreparedPresentation }
        f.owner.invalidateSourceTargets()
        XCTAssertFalse(f.owner.enter())
        f.catalog = .init(revision: .init(2), records: [])
        f.owner.catalogDidCommit()
        XCTAssertTrue(f.owner.enter())
        await waitUntil { f.projection.snapshot?.revision == .init(2) }
        XCTAssertTrue(f.projection.snapshot?.entries.isEmpty == true)
        XCTAssertEqual(f.owner.presentationConstructionCount, 1)
    }
    func testBlockedSessionLifecycleHideThenReuseRestoresInteraction() async throws {
        let f = Fixture(); defer { f.teardown() }
        await f.preferences.loadIfNeeded()
        XCTAssertTrue(f.owner.enter())
        await waitUntil { f.projection.snapshot != nil }
        let view = try XCTUnwrap(f.owner.view)
        view.setAppActionsBlocked(true)
        XCTAssertFalse(view.backButton.isEnabled)
        f.owner.hide() // A lifecycle hide does not wait for the blocked action.
        XCTAssertNil(f.owner.view)
        f.owner.view?.setAppActionsBlocked(false) // Completion while closed has no current view.
        XCTAssertTrue(f.owner.enter())
        XCTAssertTrue(f.owner.view === view)
        await waitUntil { f.projection.snapshot != nil }
        XCTAssertTrue(view.backButton.isEnabled)
        XCTAssertTrue(view.galleryView.cards.first?.iconButtons.first?.isEnabled == true)
    }

    func testCategoryFailurePresentationIsClearedAcrossReusedSessions() async throws {
        let f = Fixture(); defer { f.teardown() }
        await f.preferences.loadIfNeeded()
        XCTAssertTrue(f.owner.enter())
        let view = try XCTUnwrap(f.owner.view)
        func openDetails() async {
            view.searchField.stringValue = "Prepared"
            view.controlTextDidChange(.init(name: NSControl.textDidChangeNotification, object: view.searchField))
            await waitUntil { f.projection.snapshot != nil }
            view.resultsTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            view.tableViewSelectionDidChange(.init(name: NSTableView.selectionDidChangeNotification, object: view.resultsTable))
            view.showDetails(nil)
            XCTAssertTrue(view.detailsOpen)
        }
        await openDetails()
        view.categorySaveDidComplete(.failed)
        let status = try XCTUnwrap(view.categorySaveStatusLabel)
        XCTAssertFalse(status.isHidden)
        XCTAssertFalse(status.stringValue.isEmpty)
        f.owner.hide()
        XCTAssertTrue(status.isHidden)
        XCTAssertEqual(status.stringValue, "")
        XCTAssertTrue(f.owner.enter())
        XCTAssertTrue(f.owner.view === view)
        await openDetails()
        XCTAssertTrue(status.isHidden)
        XCTAssertEqual(status.stringValue, "")
    }

}
