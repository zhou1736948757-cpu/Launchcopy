import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import LauncherLocalization
import PagingUI
import XCTest
@testable import PagingPrototypeApp

private actor OwnerCardPreparationStore: AppLibraryPersisting {
    private var value: AppLibraryPreferences

    init(_ value: AppLibraryPreferences) { self.value = value }

    func load() -> AppLibraryLoadResult { .loaded(value) }

    func save(_ preferences: AppLibraryPreferences,
              recoveringCorruptPayload: Bool) -> AppLibrarySaveResult {
        value = preferences
        return .saved
    }
}

/// Holds only normal session projections. Idle preparation must never reach it.
@MainActor
private final class OwnerCardSessionProjectionGate {
    private(set) var requests: [AppLibraryProjectionRequest] = []
    private var pending: [(AppLibraryProjectionRequest, CheckedContinuation<AppLibrarySnapshot?, Never>)] = []
    private var isReleased = false
    var hasPendingRequests: Bool { !pending.isEmpty }

    func project(_ request: AppLibraryProjectionRequest) async -> AppLibrarySnapshot? {
        guard !isReleased else { return nil }
        requests.append(request)
        // Deliberately complete even canceled requests, exercising the owner's
        // generation checks instead of relying on cooperative worker cancellation.
        return await withCheckedContinuation { pending.append((request, $0)) }
    }

    @discardableResult
    func finishNext() -> Bool {
        guard !pending.isEmpty else { return false }
        let (request, continuation) = pending.removeFirst()
        continuation.resume(returning: AppLibraryProjection.make(
            catalog: request.catalog, management: request.management,
            preferences: request.preferences, query: request.query,
            category: request.category, locale: request.locale))
        return true
    }

    func releaseAll() {
        isReleased = true
        while finishNext() {}
    }
}

/// Synthetic, detached owner tests; no window, scanner, filesystem store or
/// physical-input/performance acceptance is implied by these assertions.
@MainActor
final class LibraryOwnerCardPreparationTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let host = NSView(frame: .init(x: 0, y: 0, width: 1000, height: 700))
        let gate: OwnerCardSessionProjectionGate
        let projection: AppLibraryProjectionController
        let preferences: AppLibraryPreferencesCoordinator
        let loader: RecordingIconLoader
        let pipeline: IconPipeline
        let owner: AppLibraryOwnerController
        let records: [AppRecord]
        var catalog: CatalogSnapshot
        var management = AppManagementPreferences.default
        var ready: Bool
        var capturedGridCount = 0
        var preparedEntryCount = 0
        var gridVisibilityChanges: [Bool] = []
        var opened: [AppLibraryActionRequest] = []
        private var didTearDown = false

        init(ready: Bool = true) {
            self.ready = ready
            let records = ["Arcade", "Melody", "Tools"].enumerated().map { index, name in
                let identifier = "fixture.owner.cards.\(index)"
                let id = AppID.bundleIdentifier(identifier)
                return AppRecord(id: id, displayName: name, bundleIdentifier: identifier,
                    canonicalURL: URL(fileURLWithPath: "/SyntheticOwnerCards/\(name).app"),
                    iconIdentity: .from(appID: id), sourceRootPriority: 0)
            }
            self.records = records
            catalog = .init(revision: .init(1), records: records)
            var initial = AppLibraryPreferences(enabled: true)
            for (record, category) in zip(records, [AppLibraryCategory.games, .music, .utilities]) {
                initial = initial.settingCategory(category, for: record)
            }
            preferences = AppLibraryPreferencesCoordinator(store: OwnerCardPreparationStore(initial))
            let gate = OwnerCardSessionProjectionGate()
            self.gate = gate
            projection = AppLibraryProjectionController(work: { await gate.project($0) })
            let loader = RecordingIconLoader()
            self.loader = loader
            pipeline = IconPipeline(loader: loader, limits: IconCacheLimits())
            owner = AppLibraryOwnerController(preferences: preferences,
                strings: .init(language: .english), iconPipeline: pipeline, projection: projection)
            owner.catalogProvider = { [weak self] in self?.catalog }
            owner.managementProvider = { [weak self] in self?.management ?? .default }
            owner.canTransition = { [weak self] in self?.ready == true }
            owner.canExecuteAction = { true }
            owner.captureGrid = { [weak self] in
                self?.capturedGridCount += 1
                return .init(query: "", page: 0, selection: nil, searchWasFocused: false)
            }
            owner.prepareEntry = { [weak self] in self?.preparedEntryCount += 1 }
            owner.setGridHidden = { [weak self] in self?.gridVisibilityChanges.append($0) }
            owner.openApp = { [weak self] request, _ in self?.opened.append(request) }
            owner.attach(to: host, showsEntryButton: false)
        }

        func request(for record: AppRecord) -> AppLibraryActionRequest {
            .init(record: record, catalogRevision: catalog.revision, generation: owner.actionGeneration)
        }

        func tearDown() {
            guard !didTearDown else { return }
            didTearDown = true
            owner.teardown()
            gate.releaseAll()
            pipeline.shutdown()
        }
    }

    private enum WaitFailure: Error { case deadline }
    private enum PreparationStage: CaseIterable { case queued, detached, complete }

    private func eventually(_ description: String, file: StaticString = #filePath,
                            line: UInt = #line, _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        while !condition(), ContinuousClock.now < deadline { await Task.yield() }
        guard condition() else {
            XCTFail("Timed out: \(description)", file: file, line: line)
            throw WaitFailure.deadline
        }
    }

    /// A bounded opportunity for canceled work to resume, without sleeps or an
    /// assumed number/order of executor turns. This is not a latency assertion.
    private func remainsUnprepared(_ f: Fixture, allowingEmptyShell: Bool = false,
                                  file: StaticString = #filePath, line: UInt = #line) async {
        let deadline = ContinuousClock.now.advanced(by: .milliseconds(50))
        repeat {
            XCTAssertFalse(f.owner.hasPreparedCards, file: file, line: line)
            if !allowingEmptyShell { XCTAssertFalse(f.owner.hasPreparedPresentation, file: file, line: line) }
            assertClosedAndInert(f, file: file, line: line)
            await Task.yield()
        } while ContinuousClock.now < deadline
    }

    private func assertClosedAndInert(_ f: Fixture, file: StaticString = #filePath,
                                      line: UInt = #line) {
        XCTAssertFalse(f.owner.isOpen, file: file, line: line)
        XCTAssertFalse(f.owner.isPreviewing, file: file, line: line)
        XCTAssertNil(f.owner.view, file: file, line: line)
        XCTAssertTrue(f.host.subviews.isEmpty, file: file, line: line)
        XCTAssertNil(f.host.window, file: file, line: line)
        XCTAssertFalse(f.projection.isOpen, file: file, line: line)
        XCTAssertFalse(f.projection.isProjecting, file: file, line: line)
        XCTAssertNil(f.projection.snapshot, file: file, line: line)
        XCTAssertTrue(f.gate.requests.isEmpty, file: file, line: line)
        XCTAssertTrue(f.opened.isEmpty, file: file, line: line)
        XCTAssertEqual(f.pipeline.stats.requests, 0, file: file, line: line)
        XCTAssertEqual(f.loader.requestedCount, 0, file: file, line: line)
        XCTAssertNil(f.owner.resolve(f.request(for: f.records[0]), checkingReadiness: false),
                     file: file, line: line)
    }

    private func deliverSession(_ f: Fixture, requestCount: Int = 1,
                                file: StaticString = #filePath, line: UInt = #line) async throws {
        try await eventually("normal projection request \(requestCount)", file: file, line: line) {
            // Startup may refresh an open session, so historical counts are only
            // a lower bound; delivery requires an actually queued continuation.
            f.gate.requests.count >= requestCount && f.gate.hasPendingRequests
        }
        XCTAssertTrue(f.gate.finishNext(), file: file, line: line)
        try await eventually("fresh normal snapshot", file: file, line: line) {
            guard f.projection.snapshot?.revision == f.catalog.revision, !f.projection.isProjecting else {
                // A superseded result starts the latest request only after it
                // returns. Keep delivering FIFO, including canceled requests.
                _ = f.gate.finishNext()
                return false
            }
            return true
        }
    }

    func testUnchangedCatalogPresentationCommitsDoNotDiscardOrRebuildPreparedCards() async throws {
        let f = Fixture()
        defer { f.tearDown() }
        let recorder = LibraryEntryProfile()
        f.owner.entryProfile = recorder
        await f.preferences.loadIfNeeded()
        try await eventually("initial prepared cards") { f.owner.hasPreparedCards }
        func readySamples() throws -> Int {
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: recorder.encodedSnapshot()) as? [String: Any])
            let samples = try XCTUnwrap(json["samples"] as? [[String: Any]])
            return samples.filter { ($0["tag"] as? String) == "preparedCardsReady" }.count
        }
        XCTAssertEqual(try readySamples(), 1)
        for _ in 0..<8 {
            f.owner.catalogDidCommit()
            XCTAssertTrue(f.owner.hasPreparedCards, "An unchanged presentation must not revoke valid idle work")
        }
        let deadline = ContinuousClock.now.advanced(by: .milliseconds(50))
        repeat { await Task.yield() } while ContinuousClock.now < deadline
        XCTAssertEqual(try readySamples(), 1)
        XCTAssertEqual(f.owner.presentationConstructionCount, 1)
        assertClosedAndInert(f)
    }

    func testZeroDeltaParentHoldPausesPreparationAndReleaseRetries() async throws {
        let f = Fixture()
        let surface = PagingSurface(pageCount: 2, pageWidth: 1000)
        surface.frameDriver = nil
        let navigator = LeadingLibraryNavigator(surface: surface, owner: f.owner)
        defer { navigator.teardown(); surface.teardown(); f.tearDown() }
        navigator.canNavigate = { true }
        navigator.canEnterFromGrid = { true }
        f.owner.canPrepare = { [weak navigator] in navigator?.isTransitioning == false }
        navigator.onReadinessChange = { [weak f] in f?.owner.refreshReadiness() }
        let held = navigator.routeScrollInput(phase: .began, momentumPhase: [],
            deltaX: 0, deltaY: 0, isDirectionInverted: false)
        XCTAssertEqual(held.destination, .hold)
        XCTAssertTrue(navigator.isTransitioning)
        await f.preferences.loadIfNeeded()
        await remainsUnprepared(f)
        let released = navigator.routeScrollInput(phase: .ended, momentumPhase: [],
            deltaX: 0, deltaY: 0, isDirectionInverted: false)
        XCTAssertEqual(released.destination, .grid)
        XCTAssertFalse(navigator.isTransitioning)
        try await eventually("card preparation after parent hold release") { f.owner.hasPreparedCards }
        assertClosedAndInert(f)
    }

    func testIdleCardsPrepareWithoutSessionActionsIconsOrHostAdmission() async throws {
        let f = Fixture()
        defer { f.tearDown() }
        await f.preferences.loadIfNeeded()
        let generation = f.owner.actionGeneration
        try await eventually("inert detached card pool") {
            self.assertClosedAndInert(f)
            return f.owner.hasPreparedCards
        }
        XCTAssertTrue(f.owner.hasPreparedPresentation)
        XCTAssertEqual(f.owner.actionGeneration, generation)
        XCTAssertEqual(f.owner.presentationConstructionCount, 1)
        XCTAssertEqual(f.capturedGridCount, 0)
        XCTAssertEqual(f.preparedEntryCount, 0)
        XCTAssertTrue(f.gridVisibilityChanges.isEmpty)
        XCTAssertNil(f.owner.entryProfile)
        for _ in 0..<8 { f.owner.refreshReadiness() }
        XCTAssertTrue(f.owner.hasPreparedCards)
        XCTAssertEqual(f.owner.presentationConstructionCount, 1)
        assertClosedAndInert(f)
    }

    func testPreviewRequiresFreshProjectionAndCancelRepreparesNewCardsAndControls() async throws {
        let f = Fixture()
        defer { f.tearDown() }
        await f.preferences.loadIfNeeded()
        try await eventually("first pool") { f.owner.hasPreparedCards }
        let constructions = f.owner.presentationConstructionCount
        XCTAssertTrue(f.owner.enter(preview: true))
        let view = try XCTUnwrap(f.owner.view)
        XCTAssertFalse(f.owner.hasPreparedCards)
        XCTAssertTrue(view.galleryView.hasPreparedCards, "Loading may retain a never-presented pool")
        XCTAssertTrue(view.galleryView.cards.isEmpty)
        XCTAssertNil(f.projection.snapshot)
        XCTAssertNil(f.owner.resolve(f.request(for: f.records[0]), checkingReadiness: false))
        try await deliverSession(f)
        XCTAssertFalse(view.galleryView.hasPreparedCards, "Matching normal delivery consumes the pool once")
        XCTAssertEqual(view.galleryView.cards.map(\.category), [.games, .music, .utilities])
        XCTAssertEqual(f.projection.snapshot?.entries.map(\.record.id), f.records.map(\.id))
        let oldCards = view.galleryView.cards
        let oldButton = try XCTUnwrap(oldCards.first?.iconButtons.first)
        let oldRequest = f.request(for: f.records[0])
        XCTAssertNil(f.owner.resolve(oldRequest, checkingReadiness: false), "Preview grants no app action")
        XCTAssertTrue(view.isAccessibilityHidden())
        f.owner.cancelPreview()
        XCTAssertNil(view.superview)
        XCTAssertTrue(view.galleryView.cards.isEmpty)
        XCTAssertTrue(oldCards.allSatisfy { $0.superview == nil })
        try await eventually("replacement pool") { f.owner.hasPreparedCards }
        XCTAssertTrue(view.galleryView.hasPreparedCards)
        XCTAssertFalse(f.projection.isOpen)
        XCTAssertNil(f.projection.snapshot)
        XCTAssertNil(f.owner.resolve(oldRequest, checkingReadiness: false))
        XCTAssertTrue(f.owner.enter(preview: true))
        XCTAssertTrue(f.owner.view === view)
        try await deliverSession(f, requestCount: 2)
        let newCards = view.galleryView.cards
        XCTAssertEqual(newCards.count, oldCards.count)
        let oldButtons = oldCards.flatMap(\.iconButtons)
        for card in newCards {
            XCTAssertFalse(oldCards.contains { $0 === card }, "Previously presented cards never reenter the pool")
            for button in card.iconButtons {
                XCTAssertFalse(oldButtons.contains { $0 === button })
            }
        }
        XCTAssertFalse(view.galleryView.hasPreparedCards)
        XCTAssertEqual(f.owner.presentationConstructionCount, constructions)
        XCTAssertTrue(f.owner.commitPreview())
        XCTAssertNil(f.owner.resolve(oldRequest, checkingReadiness: false))
        XCTAssertNotNil(f.owner.resolve(f.request(for: f.records[0])))
        // Retain the old cards so their weak button closures are still alive.
        withExtendedLifetime(oldCards) { oldButton.performClick(nil) }
        XCTAssertTrue(f.opened.isEmpty)
        let freshButton = try XCTUnwrap(newCards.first?.iconButtons.first)
        freshButton.performClick(nil)
        XCTAssertEqual(f.opened.count, 1)
        XCTAssertEqual(f.opened.first?.generation, f.owner.actionGeneration)
        let committedRequest = f.request(for: f.records[0])
        f.owner.back()
        XCTAssertNil(f.owner.view)
        XCTAssertNil(f.projection.snapshot)
        XCTAssertNil(f.owner.resolve(committedRequest, checkingReadiness: false))
        try await eventually("pool after committed close") { f.owner.hasPreparedCards }
        XCTAssertTrue(f.owner.enter(preview: true))
        try await deliverSession(f, requestCount: 3)
        for card in view.galleryView.cards {
            XCTAssertFalse(newCards.contains { $0 === card })
            XCTAssertFalse(oldCards.contains { $0 === card })
        }
        XCTAssertFalse(view.galleryView.hasPreparedCards)
        XCTAssertEqual(f.owner.presentationConstructionCount, constructions)
    }

    func testSourceInvalidationDiscardsPoolUntilStrictlyNewerCatalogCommit() async throws {
        for stage in PreparationStage.allCases {
            let f = Fixture(ready: false)
            defer { f.tearDown() }
            await f.preferences.loadIfNeeded()
            f.ready = true
            f.owner.refreshReadiness()
            switch stage {
            case .queued: break
            case .detached:
                try await eventually("detached shell") { f.owner.hasPreparedPresentation }
            case .complete:
                try await eventually("completed pool") { f.owner.hasPreparedCards }
            }
            f.owner.invalidateSourceTargets()
            XCTAssertFalse(f.owner.enter(preview: true))
            f.owner.catalogDidCommit() // Same revision cannot acknowledge replacement.
            f.owner.refreshReadiness()
            await remainsUnprepared(f, allowingEmptyShell: true)
            f.catalog = .init(revision: .init(2), records: [f.records[2]])
            f.owner.catalogDidCommit()
            try await eventually("new-source pool") { f.owner.hasPreparedCards }
            assertClosedAndInert(f)
            XCTAssertTrue(f.owner.enter(preview: true))
            try await deliverSession(f)
            XCTAssertEqual(f.projection.snapshot?.entries.map(\.record.id), [f.records[2].id])
            XCTAssertEqual(f.owner.view?.galleryView.cards.map(\.category), [.utilities])
        }
    }

    func testEarlyEntryCancelsQueuedPreparationAndUsesNormalColdProjection() async throws {
        let f = Fixture(ready: false)
        defer { f.tearDown() }
        await f.preferences.loadIfNeeded()
        XCTAssertFalse(f.owner.hasPreparedPresentation)
        f.ready = true
        f.owner.refreshReadiness()
        // No suspension between scheduling preparation and opening the session.
        XCTAssertTrue(f.owner.enter(preview: true))
        let view = try XCTUnwrap(f.owner.view)
        XCTAssertFalse(view.galleryView.hasPreparedCards)
        try await deliverSession(f)
        XCTAssertEqual(view.galleryView.cards.count, 3)
        XCTAssertFalse(f.owner.hasPreparedCards)
        XCTAssertFalse(view.galleryView.hasPreparedCards)
        XCTAssertEqual(f.owner.presentationConstructionCount, 1)
    }

    func testDisableCancelsQueuedPreparationAndDiscardsCompletedPool() async throws {
        for stage in PreparationStage.allCases {
            let f = Fixture(ready: false)
            defer { f.tearDown() }
            await f.preferences.loadIfNeeded()
            f.ready = true
            f.owner.refreshReadiness()
            switch stage {
            case .queued: break
            case .detached:
                try await eventually("detached shell") { f.owner.hasPreparedPresentation }
            case .complete:
                try await eventually("completed pool") { f.owner.hasPreparedCards }
            }
            var disabled = f.preferences.committed
            disabled.enabled = false
            XCTAssertTrue(f.preferences.submit(disabled))
            try await eventually("disabled preference receipt") {
                f.preferences.pendingCount == 0 && !f.preferences.committed.enabled
            }
            XCTAssertFalse(f.preferences.committed.enabled)
            XCTAssertFalse(f.owner.enter(preview: true))
            await remainsUnprepared(f)
        }
    }

    func testTeardownCancelsQueuedDetachedAndCompletedPreparation() async throws {
        for stage in PreparationStage.allCases {
            let f = Fixture(ready: false)
            defer { f.tearDown() }
            await f.preferences.loadIfNeeded()
            f.ready = true
            f.owner.refreshReadiness()
            switch stage {
            case .queued: break
            case .detached:
                try await eventually("detached shell") { f.owner.hasPreparedPresentation }
            case .complete:
                try await eventually("completed pool") { f.owner.hasPreparedCards }
            }
            f.tearDown()
            let constructions = f.owner.presentationConstructionCount
            f.owner.refreshReadiness()
            f.owner.catalogDidCommit()
            await remainsUnprepared(f)
            XCTAssertEqual(f.owner.presentationConstructionCount, constructions)
            XCTAssertFalse(f.owner.enter(preview: true))
        }
    }

    func testLanguageChangeRejectsOldPoolAndFreshNormalSessionUsesNewLabels() async throws {
        let f = Fixture()
        defer { f.tearDown() }
        await f.preferences.loadIfNeeded()
        try await eventually("English pool") { f.owner.hasPreparedCards }
        let japanese = LocalizedStrings(language: .japanese)
        f.owner.relabel(strings: japanese)
        // Enter synchronously so a replacement pool cannot hide stale-pool use.
        XCTAssertFalse(f.owner.hasPreparedCards)
        XCTAssertTrue(f.owner.enter(preview: true))
        let view = try XCTUnwrap(f.owner.view)
        XCTAssertFalse(view.galleryView.hasPreparedCards)
        XCTAssertTrue(view.galleryView.cards.isEmpty)
        XCTAssertNil(f.projection.snapshot)
        try await deliverSession(f)
        XCTAssertEqual(f.gate.requests.last?.locale.identifier, InterfaceLanguage.japanese.rawValue)
        XCTAssertEqual(view.searchField.placeholderString, japanese.text(.searchPlaceholder))
        for card in view.galleryView.cards {
            let title = AppLibraryCategoryLabels.title(for: card.category, strings: japanese)
            XCTAssertEqual(card.accessibilityRole(), .group)
            XCTAssertEqual(card.accessibilityLabel(), "\(title), \(card.entries.count)")
        }
        XCTAssertNil(f.owner.resolve(f.request(for: f.records[0]), checkingReadiness: false))
    }

    func testManagementChangeCannotPublishHiddenOrUnaliasedEntriesFromOldPool() async throws {
        let f = Fixture()
        defer { f.tearDown() }
        await f.preferences.loadIfNeeded()
        try await eventually("original management pool") { f.owner.hasPreparedCards }
        f.management = f.management.settingHidden(true, for: f.records[0])
        f.management = try XCTUnwrap(f.management.settingAlias("Current Alias", for: f.records[1]))
        // No catalog notification: the normal session must independently capture
        // current management data and reject a complete but mismatching pool.
        XCTAssertTrue(f.owner.enter(preview: true))
        let view = try XCTUnwrap(f.owner.view)
        XCTAssertTrue(view.galleryView.hasPreparedCards)
        XCTAssertTrue(view.galleryView.cards.isEmpty)
        XCTAssertNil(f.projection.snapshot)
        try await deliverSession(f)
        XCTAssertEqual(f.gate.requests.last?.management, f.management)
        let entries = view.galleryView.cards.flatMap(\.entries)
        XCTAssertEqual(entries.count, 2)
        XCTAssertFalse(entries.contains { $0.record.id == f.records[0].id })
        XCTAssertEqual(entries.first { $0.record.id == f.records[1].id }?.displayName, "Current Alias")
        XCTAssertFalse(view.galleryView.hasPreparedCards)
        XCTAssertTrue(f.owner.commitPreview())
        XCTAssertNil(f.owner.resolve(f.request(for: f.records[0])))
        XCTAssertNotNil(f.owner.resolve(f.request(for: f.records[1])))
    }
}
