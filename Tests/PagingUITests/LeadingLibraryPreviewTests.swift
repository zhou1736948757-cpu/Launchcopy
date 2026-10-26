import AppCatalogCore
import AppGridUI
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

private actor LeadingLibraryPreviewStore: AppLibraryPersisting {
    private var value: AppLibraryPreferences
    init(enabled: Bool) { value = .init(enabled: enabled) }
    func load() -> AppLibraryLoadResult { .loaded(value) }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) -> AppLibrarySaveResult {
        value = preferences
        return .saved
    }
}

/// Deliberately completes even after cancellation to exercise session invalidation.
private actor LeadingLibraryPreviewProjectionGate {
    private(set) var requests: [AppLibraryProjectionRequest] = []
    private var completions: [CheckedContinuation<AppLibrarySnapshot?, Never>] = []

    func run(_ request: AppLibraryProjectionRequest) async -> AppLibrarySnapshot? {
        requests.append(request)
        return await withCheckedContinuation { completions.append($0) }
    }

    func finishNext() {
        guard !completions.isEmpty else { return }
        let request = requests[requests.count - completions.count]
        let snapshot = AppLibraryProjection.make(catalog: request.catalog, management: request.management,
            preferences: request.preferences, query: request.query, category: request.category, locale: request.locale)
        completions.removeFirst().resume(returning: snapshot)
    }

    var count: Int { requests.count }
}

private final class LeadingLibraryPreviewGridResponder: NSView {
    override var acceptsFirstResponder: Bool { true }
}

/// Synthetic data, an in-memory store and unshown windows only. These assertions
/// cover owner transactions, not parent animation or physical gesture acceptance.
@MainActor
final class LeadingLibraryPreviewTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let preferences: AppLibraryPreferencesCoordinator
        let projection: AppLibraryProjectionController
        let owner: AppLibraryOwnerController
        let host = NSView(frame: .init(x: 0, y: 0, width: 1000, height: 700))
        let gridResponder = LeadingLibraryPreviewGridResponder(frame: .zero)
        let window: NSWindow
        let record: AppRecord
        let context: AppLibraryGridReturnContext
        var catalog: CatalogSnapshot
        var startupReadinessNotifications = 0
        var preparations = 0
        var captures = 0
        var hiddenChanges: [Bool] = []
        var restores: [AppLibraryGridReturnContext] = []

        init(enabled: Bool = true, projection: AppLibraryProjectionController? = nil) {
            let id = AppID.bundleIdentifier("fixture.leading.library")
            record = .init(id: id, displayName: "Preview Fixture", bundleIdentifier: "fixture.leading.library",
                canonicalURL: URL(fileURLWithPath: "/SyntheticLeadingLibrary/Fixture.app"),
                iconIdentity: .from(appID: id), sourceRootPriority: 0)
            catalog = .init(revision: .init(1), records: [record])
            context = .init(query: "saved grid query", page: 3,
                selection: .init(catalogRevision: 1, pageIndex: 3, slotIndex: 2, entryIdentity: .app(id)),
                searchWasFocused: true)
            preferences = AppLibraryPreferencesCoordinator(store: LeadingLibraryPreviewStore(enabled: enabled))
            self.projection = projection ?? AppLibraryProjectionController()
            owner = AppLibraryOwnerController(preferences: preferences, strings: .init(language: .english),
                projection: self.projection)
            window = NSWindow(contentRect: host.bounds, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            host.addSubview(gridResponder)
            window.makeFirstResponder(gridResponder)
            owner.canTransition = { true }
            owner.canExecuteAction = { true }
            owner.catalogProvider = { [weak self] in self?.catalog }
            owner.captureGrid = { [weak self] in
                guard let self else { return nil }
                self.captures += 1
                return self.context
            }
            owner.prepareEntry = { [weak self] in self?.preparations += 1 }
            owner.setGridHidden = { [weak self] hidden in self?.hiddenChanges.append(hidden) }
            owner.restoreGrid = { [weak self] context in self?.restores.append(context) }
            owner.onReadinessChange = { [weak self] in self?.startupReadinessNotifications += 1 }
            owner.attach(to: host)
        }

        func teardown() {
            owner.teardown()
            window.contentView = nil
            window.close()
        }

        var request: AppLibraryActionRequest {
            .init(record: record, catalogRevision: catalog.revision, generation: owner.actionGeneration)
        }
    }

    private func loadedFixture(enabled: Bool = true,
                               projection: AppLibraryProjectionController? = nil) async -> Fixture {
        let fixture = Fixture(enabled: enabled, projection: projection)
        await fixture.preferences.loadIfNeeded()
        // Loading the preference and the owner attach task are separate async seams.
        // Wait for both initial readiness receipts before asserting one preview projection.
        await waitUntil { fixture.startupReadinessNotifications >= 2 }
        return fixture
    }

    private func waitUntil(_ condition: () -> Bool) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !condition(), ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertTrue(condition())
    }

    private func waitForRequests(_ expected: Int, gate: LeadingLibraryPreviewProjectionGate) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while await gate.count < expected, ContinuousClock.now < deadline { await Task.yield() }
        let count = await gate.count
        XCTAssertEqual(count, expected)
    }

    func testPreviewMountsNormalProjectionWithoutPreparingHidingOrFocusing() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        XCTAssertTrue(owner.enter(preview: true))
        let view = try XCTUnwrap(owner.view)
        XCTAssertTrue(owner.isOpen)
        XCTAssertTrue(owner.isPreviewing)
        XCTAssertTrue(view.superview === fixture.host)
        XCTAssertTrue(view.isAccessibilityHidden())
        XCTAssertEqual(view.frame, fixture.host.bounds.insetBy(dx: 16, dy: 12))
        XCTAssertEqual(fixture.captures, 1)
        XCTAssertEqual(fixture.preparations, 0)
        XCTAssertTrue(fixture.hiddenChanges.isEmpty)
        XCTAssertTrue(fixture.window.firstResponder === fixture.gridResponder)
        XCTAssertNil(owner.preferredFirstResponder)
        await waitUntil { fixture.projection.snapshot != nil }
        XCTAssertEqual(view.resultsTable.numberOfRows, 1)
        XCTAssertTrue(fixture.window.firstResponder === fixture.gridResponder)
        XCTAssertNil(owner.preferredFirstResponder)
        XCTAssertFalse(owner.enter())
        XCTAssertFalse(owner.enter(preview: true))
        XCTAssertEqual(fixture.captures, 1)
        XCTAssertFalse(fixture.window.isVisible)
    }

    func testPreviewRejectsAllAppActionsIncludingReadinessBypass() async {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        var actions = 0
        owner.openApp = { _, _ in actions += 1 }
        owner.revealApp = { _ in actions += 1 }
        owner.setHidden = { _, _ in actions += 1 }
        owner.editAlias = { _, _ in actions += 1 }
        owner.assignFolder = { _, _ in actions += 1 }
        owner.moveToTrash = { _, _ in actions += 1 }
        XCTAssertTrue(owner.enter(preview: true))
        await waitUntil { fixture.projection.snapshot != nil }
        let request = fixture.request
        XCTAssertNil(owner.resolve(request))
        XCTAssertNil(owner.resolve(request, checkingReadiness: false))
        owner.view?.onOpen?(request)
        owner.view?.onReveal?(request)
        owner.view?.onSetHidden?(request, true)
        owner.view?.onEditAlias?(request)
        owner.view?.onFolderAssignment?(request)
        owner.view?.onMoveToTrash?(request)
        owner.view?.onSetCategory?(request, .music)
        XCTAssertEqual(actions, 0)
        XCTAssertEqual(fixture.preferences.pendingCount, 0)
        XCTAssertEqual(fixture.preferences.committed.category(for: fixture.record), .other)
    }

    func testCancelRemovesPreviewWithoutGridOrFocusMutationAndRevokesRequests() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        XCTAssertTrue(owner.enter(preview: true))
        await waitUntil { fixture.projection.snapshot != nil }
        let view = try XCTUnwrap(owner.view)
        let request = fixture.request
        owner.cancelPreview()
        XCTAssertFalse(owner.isOpen)
        XCTAssertFalse(owner.isPreviewing)
        XCTAssertNil(owner.view)
        XCTAssertNil(view.superview)
        XCTAssertNil(fixture.projection.snapshot)
        XCTAssertFalse(fixture.projection.isOpen)
        XCTAssertGreaterThan(owner.actionGeneration, request.generation)
        XCTAssertNil(owner.resolve(request, checkingReadiness: false))
        XCTAssertEqual(fixture.preparations, 0)
        XCTAssertTrue(fixture.hiddenChanges.isEmpty)
        XCTAssertTrue(fixture.restores.isEmpty)
        XCTAssertTrue(fixture.window.firstResponder === fixture.gridResponder)
        owner.cancelPreview()
        XCTAssertFalse(owner.commitPreview())
        XCTAssertTrue(fixture.hiddenChanges.isEmpty)
    }

    func testCommitReusesViewAndProjectionThenBackRestoresCapturedContext() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        XCTAssertTrue(owner.enter(preview: true))
        let view = try XCTUnwrap(owner.view)
        await waitUntil { fixture.projection.snapshot != nil }
        let generation = owner.actionGeneration
        owner.prepareEntry = {
            fixture.preparations += 1
            XCTAssertTrue(owner.isPreviewing)
            XCTAssertTrue(fixture.hiddenChanges.isEmpty)
            XCTAssertTrue(fixture.window.firstResponder === fixture.gridResponder)
        }
        XCTAssertTrue(owner.commitPreview())
        XCTAssertTrue(owner.isOpen)
        XCTAssertFalse(owner.isPreviewing)
        XCTAssertTrue(owner.view === view)
        XCTAssertEqual(owner.actionGeneration, generation, "Commit must not schedule another projection")
        XCTAssertFalse(view.isAccessibilityHidden())
        XCTAssertEqual(fixture.preparations, 1)
        XCTAssertEqual(fixture.captures, 1)
        XCTAssertEqual(fixture.hiddenChanges, [true])
        XCTAssertTrue(fixture.window.firstResponder === view.searchField.currentEditor())
        XCTAssertNotNil(owner.preferredFirstResponder)
        XCTAssertNotNil(owner.resolve(fixture.request))
        XCTAssertFalse(owner.commitPreview())
        owner.cancelPreview()
        XCTAssertTrue(owner.isOpen, "Preview cancellation cannot close a committed Library")
        owner.back()
        XCTAssertEqual(fixture.hiddenChanges, [true, false])
        XCTAssertEqual(fixture.restores, [fixture.context])
        owner.prepareEntry = {}
    }

    func testAdmissionDoesNotCaptureAndRejectsDisabledBlockedPendingAndInvalidatedEntry() async {
        let disabled = await loadedFixture(enabled: false)
        defer { disabled.teardown() }
        XCTAssertFalse(disabled.owner.canPreviewEntry)
        XCTAssertFalse(disabled.owner.enter(preview: true))
        XCTAssertEqual(disabled.captures, 0)

        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        XCTAssertTrue(owner.canPreviewEntry)
        XCTAssertTrue(owner.canPreviewEntry)
        XCTAssertEqual(fixture.captures, 0)
        owner.canTransition = { false }
        XCTAssertFalse(owner.canPreviewEntry)
        XCTAssertFalse(owner.enter(preview: true))
        owner.canTransition = { true }
        XCTAssertTrue(fixture.preferences.submit(fixture.preferences.committed))
        XCTAssertFalse(owner.canPreviewEntry)
        XCTAssertFalse(owner.enter(preview: true))
        _ = await fixture.preferences.drain()
        owner.invalidateSourceTargets()
        XCTAssertFalse(owner.canPreviewEntry)
        XCTAssertFalse(owner.enter(preview: true))
        XCTAssertEqual(fixture.captures, 0)
        XCTAssertEqual(fixture.preparations, 0)
        XCTAssertFalse(fixture.projection.isOpen)
        XCTAssertNil(owner.view)
    }

    func testCommitRechecksReadinessAndSourceBeforePreparation() async {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        XCTAssertFalse(owner.commitPreview())
        XCTAssertTrue(owner.enter(preview: true))
        owner.canTransition = { false }
        XCTAssertFalse(owner.commitPreview())
        owner.canTransition = { true }
        XCTAssertTrue(fixture.preferences.submit(fixture.preferences.committed))
        XCTAssertFalse(owner.commitPreview())
        _ = await fixture.preferences.drain()
        owner.invalidateSourceTargets()
        XCTAssertFalse(owner.commitPreview())
        XCTAssertTrue(owner.isPreviewing)
        XCTAssertEqual(fixture.preparations, 0)
        XCTAssertTrue(fixture.hiddenChanges.isEmpty)
        XCTAssertTrue(fixture.window.firstResponder === fixture.gridResponder)
    }

    func testCommitWhileProjectionRunsDoesNotRequireExternalActionReadiness() async throws {
        let gate = LeadingLibraryPreviewProjectionGate()
        let projection = AppLibraryProjectionController(work: { await gate.run($0) })
        let fixture = await loadedFixture(projection: projection)
        defer { fixture.teardown() }
        let owner = fixture.owner
        XCTAssertTrue(owner.enter(preview: true))
        let view = try XCTUnwrap(owner.view)
        await waitForRequests(1, gate: gate)
        owner.canExecuteAction = { false }
        XCTAssertTrue(owner.commitPreview(), "Parent completion may still block external actions")
        XCTAssertTrue(owner.view === view)
        XCTAssertFalse(owner.isPreviewing)
        XCTAssertTrue(projection.isProjecting)
        XCTAssertEqual(fixture.preparations, 1)
        XCTAssertEqual(fixture.hiddenChanges, [true])
        await gate.finishNext()
        await waitUntil { !projection.isProjecting }
        let count = await gate.count
        XCTAssertEqual(count, 1)
        XCTAssertEqual(view.resultsTable.numberOfRows, 1)
        XCTAssertNil(owner.resolve(fixture.request))
        owner.canExecuteAction = { true }
        XCTAssertNotNil(owner.resolve(fixture.request))
    }

    func testCommitCannotHideOrFocusAfterReentrantPreparationCancellation() async {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        XCTAssertTrue(owner.enter(preview: true))
        owner.prepareEntry = { [weak owner] in owner?.cancelPreview() }
        XCTAssertFalse(owner.commitPreview())
        XCTAssertFalse(owner.isOpen)
        XCTAssertTrue(fixture.hiddenChanges.isEmpty)
        XCTAssertTrue(fixture.restores.isEmpty)
        XCTAssertTrue(fixture.window.firstResponder === fixture.gridResponder)
    }

    func testCancelledProjectionCannotPublishIntoClosedOrReopenedPreview() async {
        let gate = LeadingLibraryPreviewProjectionGate()
        let projection = AppLibraryProjectionController(work: { await gate.run($0) })
        let fixture = await loadedFixture(projection: projection)
        defer { fixture.teardown() }
        let owner = fixture.owner
        XCTAssertTrue(owner.enter(preview: true))
        await waitForRequests(1, gate: gate)
        let oldRequest = fixture.request
        owner.cancelPreview()
        fixture.catalog = .init(revision: .init(2), records: [fixture.record])
        XCTAssertTrue(owner.enter(preview: true))
        XCTAssertNil(projection.snapshot)
        await gate.finishNext()
        await waitForRequests(2, gate: gate)
        XCTAssertNil(projection.snapshot)
        XCTAssertEqual(owner.view?.resultsTable.numberOfRows, 0)
        XCTAssertNil(owner.resolve(oldRequest, checkingReadiness: false))
        await gate.finishNext()
        await waitUntil { !projection.isProjecting }
        XCTAssertEqual(projection.snapshot?.revision, .init(2))
        XCTAssertEqual(owner.view?.resultsTable.numberOfRows, 1)
        XCTAssertNil(owner.resolve(fixture.request), "Even fresh preview results are not actionable")
        XCTAssertTrue(fixture.hiddenChanges.isEmpty)
    }

    func testLateResultAfterCancelCannotRemountOrNotifyPresentation() async {
        let gate = LeadingLibraryPreviewProjectionGate()
        let projection = AppLibraryProjectionController(work: { await gate.run($0) })
        let fixture = await loadedFixture(projection: projection)
        defer { fixture.teardown() }
        let owner = fixture.owner
        XCTAssertTrue(owner.enter(preview: true))
        await waitForRequests(1, gate: gate)
        owner.cancelPreview()
        var notifications = 0
        owner.onPresentationChange = { notifications += 1 }
        await gate.finishNext()
        await waitUntil { !projection.isProjecting }
        XCTAssertNil(projection.snapshot)
        XCTAssertNil(owner.view)
        XCTAssertFalse(owner.isOpen)
        XCTAssertEqual(notifications, 0)
        XCTAssertTrue(fixture.hiddenChanges.isEmpty)
        XCTAssertTrue(fixture.window.firstResponder === fixture.gridResponder)
    }

    func testBackCancellationRunsBeforeReadinessGuardAndEscapeOnlyNotifiesOnce() async {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        var callbacks = 0
        owner.onBeforeBack = { [weak owner] in
            guard let owner else { return }
            callbacks += 1
            XCTAssertTrue(owner.isOpen)
            owner.canTransition = { true }
        }
        XCTAssertTrue(owner.enter())
        owner.canTransition = { false }
        owner.back()
        XCTAssertEqual(callbacks, 1)
        XCTAssertEqual(fixture.restores, [fixture.context])
        XCTAssertTrue(owner.enter())
        owner.canTransition = { false }
        XCTAssertTrue(owner.handleEscape())
        XCTAssertEqual(callbacks, 2)
        XCTAssertFalse(owner.isOpen)
        XCTAssertEqual(fixture.restores, [fixture.context, fixture.context])
    }

    func testParentBackCancellationMaySynchronouslyDiscardPreview() async {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        owner.onBeforeBack = { [weak owner] in owner?.cancelPreview() }
        XCTAssertTrue(owner.enter(preview: true))
        owner.back()
        XCTAssertFalse(owner.isOpen)
        XCTAssertTrue(owner.enter(preview: true))
        XCTAssertTrue(owner.handleEscape())
        XCTAssertFalse(owner.isOpen)
        XCTAssertTrue(fixture.hiddenChanges.isEmpty)
        XCTAssertTrue(fixture.restores.isEmpty)
        XCTAssertTrue(fixture.window.firstResponder === fixture.gridResponder)
    }

    func testEscapePreservesQueryBeforeClosingAndCancelsPreviewWithoutRestoring() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        XCTAssertTrue(owner.enter())
        let view = try XCTUnwrap(owner.view)
        view.searchField.stringValue = "Library query"
        view.searchField.currentEditor()?.string = "Library query"
        view.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: view.searchField))
        XCTAssertTrue(owner.handleEscape())
        XCTAssertTrue(owner.isOpen)
        XCTAssertEqual(view.query, "")
        XCTAssertTrue(fixture.restores.isEmpty)
        owner.hide()
        fixture.hiddenChanges.removeAll()
        fixture.window.makeFirstResponder(fixture.gridResponder)
        XCTAssertTrue(owner.enter(preview: true))
        XCTAssertTrue(owner.handleEscape())
        XCTAssertFalse(owner.isOpen)
        XCTAssertTrue(fixture.restores.isEmpty)
        XCTAssertTrue(fixture.hiddenChanges.isEmpty)
        XCTAssertTrue(fixture.window.firstResponder === fixture.gridResponder)
    }

    func testSwipeReturnUsesCapturedQueryFirstPageAndClearedSelectionAndFocus() async {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        XCTAssertFalse(owner.backToFirstGridPage())
        XCTAssertTrue(owner.enter(preview: true))
        XCTAssertFalse(owner.backToFirstGridPage())
        XCTAssertTrue(owner.commitPreview())
        XCTAssertTrue(owner.backToFirstGridPage())
        XCTAssertEqual(fixture.restores, [.init(query: fixture.context.query, page: 0,
            selection: nil, searchWasFocused: false)])
        XCTAssertEqual(fixture.hiddenChanges, [true, false])
        XCTAssertFalse(owner.isOpen)
    }

    func testPresentationCallbacksObserveCompletedOpenCommitCloseAndPreferenceUpdates() async {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        var observations: [String] = []
        owner.onPresentationChange = {
            observations.append(owner.isOpen ? (owner.isPreviewing ? "preview" : "committed") : "closed")
        }
        XCTAssertTrue(owner.enter(preview: true))
        XCTAssertEqual(observations, ["preview"])
        XCTAssertTrue(owner.commitPreview())
        XCTAssertEqual(observations, ["preview", "committed"])
        owner.hide()
        XCTAssertEqual(observations, ["preview", "committed", "closed"])
        XCTAssertTrue(owner.enter())
        XCTAssertEqual(observations.last, "committed")
        var disabled = fixture.preferences.committed
        disabled.enabled = false
        XCTAssertTrue(fixture.preferences.submit(disabled))
        _ = await fixture.preferences.drain()
        XCTAssertEqual(observations.last, "closed")
        XCTAssertFalse(owner.isOpen)
        XCTAssertTrue(owner.entryButton?.isHidden == true)
        owner.onPresentationChange = nil
    }

    func testPreferenceDisableAndHideDiscardPreviewWithoutRestoringGrid() async {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        XCTAssertTrue(owner.enter(preview: true))
        owner.hide()
        XCTAssertFalse(owner.isPreviewing)
        XCTAssertTrue(owner.enter(preview: true))
        var disabled = fixture.preferences.committed
        disabled.enabled = false
        XCTAssertTrue(fixture.preferences.submit(disabled))
        _ = await fixture.preferences.drain()
        XCTAssertFalse(owner.isOpen)
        XCTAssertFalse(owner.isPreviewing)
        XCTAssertTrue(fixture.hiddenChanges.isEmpty)
        XCTAssertTrue(fixture.restores.isEmpty)
        XCTAssertTrue(fixture.window.firstResponder === fixture.gridResponder)
    }
    func testReturnRestoresGridBeforeRevealingAndDetachingLibrary() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        XCTAssertTrue(owner.enter())
        let library = try XCTUnwrap(owner.view)
        var order: [String] = []
        let host = fixture.host
        owner.restoreGrid = { _ in
            XCTAssertTrue(library.superview === host, "Keep the outgoing pane until the destination is ready")
            order.append("restore")
        }
        owner.setGridHidden = { hidden in if !hidden { order.append("reveal") } }
        owner.back()
        XCTAssertEqual(order, ["restore", "reveal"])
        XCTAssertNil(library.superview)
    }

    func testRestoreCallbackCannotReenterUntilOutgoingCloseHasFinished() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        XCTAssertTrue(owner.enter())
        let outgoing = try XCTUnwrap(owner.view)
        owner.restoreGrid = { [weak owner] _ in
            guard let owner else { XCTFail("Owner unexpectedly released during close"); return }
            XCTAssertFalse(owner.canPreviewEntry)
            XCTAssertFalse(owner.enter(), "Close callbacks must not admit a replacement session")
        }
        owner.back()
        XCTAssertFalse(owner.isOpen)
        XCTAssertNil(owner.view)
        XCTAssertNil(outgoing.superview)
        XCTAssertEqual(fixture.hiddenChanges, [true, false])
        XCTAssertTrue(owner.enter(), "Admission resumes after complete cleanup")
        XCTAssertTrue(owner.view === outgoing, "A cleaned detached shell may be reused only after close has completed")
    }

    func testRestoreCallbackTeardownDetachesOutgoingWithoutFurtherPresentationCallbacks() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        XCTAssertTrue(owner.enter())
        let outgoing = try XCTUnwrap(owner.view)
        var afterTeardownNotifications = 0
        var didTearDown = false
        owner.onReadinessChange = { if didTearDown { afterTeardownNotifications += 1 } }
        owner.onPresentationChange = { if didTearDown { afterTeardownNotifications += 1 } }
        owner.restoreGrid = { [weak owner] _ in
            guard let owner else { XCTFail("Owner unexpectedly released during restore"); return }
            owner.teardown()
            didTearDown = true
        }
        owner.back()
        XCTAssertFalse(owner.isOpen)
        XCTAssertNil(owner.view)
        XCTAssertNil(outgoing.superview)
        XCTAssertNil(owner.entryButton)
        XCTAssertFalse(owner.canPreviewEntry)
        XCTAssertFalse(owner.enter())
        XCTAssertEqual(afterTeardownNotifications, 0)
        XCTAssertEqual(fixture.hiddenChanges, [true], "A torn-down owner must not reveal or notify a dead host")
    }

    func testPreferenceDisableRestoreTeardownDoesNotNotifyOrRevealDeadOwner() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        XCTAssertTrue(owner.enter())
        let outgoing = try XCTUnwrap(owner.view)
        var didTearDown = false
        var lateNotifications = 0
        owner.onReadinessChange = { if didTearDown { lateNotifications += 1 } }
        owner.onPresentationChange = { if didTearDown { lateNotifications += 1 } }
        owner.restoreGrid = { [weak owner] _ in
            guard let owner else { XCTFail("Owner unexpectedly released during preference close"); return }
            owner.teardown()
            didTearDown = true
        }
        XCTAssertTrue(owner.preferences.submit(.init(enabled: false)))
        await waitUntil { didTearDown }
        XCTAssertFalse(owner.isOpen)
        XCTAssertNil(owner.view)
        XCTAssertNil(outgoing.superview)
        XCTAssertFalse(owner.canPreviewEntry)
        XCTAssertEqual(lateNotifications, 0)
        XCTAssertEqual(fixture.hiddenChanges, [true])
    }

    func testPreferenceReadinessCallbackTeardownSuppressesPresentationNotification() async {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let owner = fixture.owner
        var presentationNotifications = 0
        owner.onReadinessChange = { [weak owner] in owner?.teardown() }
        owner.onPresentationChange = { presentationNotifications += 1 }
        XCTAssertTrue(owner.preferences.submit(.init(enabled: false)))
        XCTAssertFalse(owner.canPreviewEntry)
        XCTAssertEqual(presentationNotifications, 0)
    }

}
