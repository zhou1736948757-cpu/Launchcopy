import AppCatalogCore
import AppGridUI
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

private actor ActivityControlledStore: LaunchActivityPersisting {
    let initial: LaunchActivityLoadResult
    var suspended = false
    var result: LaunchActivitySaveResult = .saved
    private(set) var writes: [LaunchActivityDocument] = []
    private var completion: CheckedContinuation<LaunchActivitySaveResult, Never>?
    private var onSuspendedSave: (@Sendable (Int) -> Void)?
    init(_ initial: LaunchActivityLoadResult = .missing) { self.initial = initial }
    func load() -> LaunchActivityLoadResult { initial }
    func configure(suspended: Bool = false, result: LaunchActivitySaveResult = .saved,
                   onSuspendedSave: (@Sendable (Int) -> Void)? = nil) {
        self.suspended = suspended; self.result = result
        self.onSuspendedSave = onSuspendedSave
    }
    func save(_ document: LaunchActivityDocument, recoveringCorruptPayload: Bool) async -> LaunchActivitySaveResult {
        writes.append(document)
        if suspended {
            return await withCheckedContinuation {
                completion = $0
                onSuspendedSave?(writes.count)
            }
        }
        return result
    }
    func complete(_ value: LaunchActivitySaveResult = .saved) {
        completion?.resume(returning: value); completion = nil
    }
}

/// Captured only by the owner's clock, so its release observes owner lifetime
/// without adding a production deinit hook or retaining the owner from the test.
private final class ActivityOwnerLifetimeProbe {
    let date: Date
    private let deallocated: XCTestExpectation

    init(date: Date, deallocated: XCTestExpectation) {
        self.date = date
        self.deallocated = deallocated
    }

    deinit { deallocated.fulfill() }
}

private actor ActivityEnabledLibraryStore: AppLibraryPersisting {
    func load() -> AppLibraryLoadResult { .loaded(.init(enabled: true)) }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) -> AppLibrarySaveResult { .saved }
}

private actor ActivityToggleLibraryStore: AppLibraryPersisting {
    private var value = AppLibraryPreferences(enabled: true)
    private var continuation: CheckedContinuation<AppLibrarySaveResult, Never>?
    private(set) var submissions = 0
    func load() -> AppLibraryLoadResult { .loaded(value) }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) async -> AppLibrarySaveResult {
        submissions += 1
        let result = await withCheckedContinuation { continuation = $0 }
        if result == .saved { value = preferences }
        return result
    }
    func complete(_ result: AppLibrarySaveResult) { continuation?.resume(returning: result); continuation = nil }
}

private actor ActivityDelayedLoadStore: LaunchActivityPersisting {
    private var continuation: CheckedContinuation<LaunchActivityLoadResult, Never>?
    private(set) var loadStarted = false
    private(set) var writes: [LaunchActivityDocument] = []
    func load() async -> LaunchActivityLoadResult {
        loadStarted = true
        return await withCheckedContinuation { continuation = $0 }
    }
    func release(_ result: LaunchActivityLoadResult) { continuation?.resume(returning: result); continuation = nil }
    func save(_ document: LaunchActivityDocument, recoveringCorruptPayload: Bool) -> LaunchActivitySaveResult {
        writes.append(document); return .saved
    }
}

@MainActor
final class LaunchActivityCoordinatorTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_800_000_000)
    private func record(_ suffix: String = "one") -> AppRecord {
        let url = URL(fileURLWithPath: "/fixture/" + suffix + ".app")
        let id = AppID.bundleIdentifier("fixture." + suffix)
        return AppRecord(id: id, displayName: suffix, bundleIdentifier: "fixture." + suffix,
            canonicalURL: url, iconIdentity: .from(appID: id), sourceRootPriority: 0)
    }
    private func spin(_ predicate: () async -> Bool) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while !(await predicate()), ContinuousClock.now < deadline { await Task.yield() }
        let ready = await predicate(); XCTAssertTrue(ready)
    }
    private func enabled() async -> (LaunchActivityCoordinator, ActivityControlledStore) {
        let store = ActivityControlledStore()
        let owner = LaunchActivityCoordinator(store: store, now: { self.date })
        await owner.loadIfNeeded(); owner.setLibraryEnabled(true)
        XCTAssertTrue(owner.setEnabled(true))
        _ = await owner.drain()
        return (owner, store)
    }
    func testDefaultOffLoadDoesNotSaveOrRecord() async {
        let store = ActivityControlledStore()
        let owner = LaunchActivityCoordinator(store: store)
        await owner.loadIfNeeded(); owner.setLibraryEnabled(true)
        XCTAssertNil(owner.prepareObservation(for: record()))
        XCTAssertFalse(owner.document.enabled)
        XCTAssertFalse(owner.requiresQuitProtection)
        let writes = await store.writes; XCTAssertTrue(writes.isEmpty)
        owner.invalidate()
    }
    func testEnableRequiresDurableReceiptAndLibraryPermission() async {
        let store = ActivityControlledStore(); await store.configure(suspended: true)
        let owner = LaunchActivityCoordinator(store: store, now: { self.date })
        await owner.loadIfNeeded()
        XCTAssertFalse(owner.setEnabled(true))
        owner.setLibraryEnabled(true); XCTAssertTrue(owner.setEnabled(true))
        XCTAssertNil(owner.prepareObservation(for: record()))
        await spin { await store.writes.count == 1 }
        await store.complete(); _ = await owner.drain()
        XCTAssertNotNil(owner.prepareObservation(for: record()))
        owner.invalidate()
    }
    func testObservationIsOneShotAndDisabledIntervalRevokesIt() async {
        let (owner, _) = await enabled()
        let once = owner.prepareObservation(for: record())
        once?(); once?(); _ = await owner.drain()
        XCTAssertEqual(owner.document.entries.count, 1)
        XCTAssertEqual(owner.document.entries.values.first?.dailyCounts.values.reduce(0, +), 1)
        let stale = owner.prepareObservation(for: record("two"))
        owner.setLibraryEnabled(false); owner.setLibraryEnabled(true)
        stale?(); XCTAssertEqual(owner.document.entries.count, 1)
        let old = owner.prepareObservation(for: record("three"))
        XCTAssertTrue(owner.setEnabled(false)); _ = await owner.drain()
        XCTAssertTrue(owner.setEnabled(true)); _ = await owner.drain()
        old?(); XCTAssertEqual(owner.document.entries.count, 1)
        owner.invalidate()
    }
    func testClearSupersedesOldQueuedDataAndRevokesPreparedEvents() async {
        let (owner, store) = await enabled(); await store.configure(suspended: true)
        let old = owner.prepareObservation(for: record("old"))
        owner.prepareObservation(for: record("first"))?()
        await spin { await store.writes.count == 2 }
        owner.prepareObservation(for: record("queued"))?()
        XCTAssertEqual(owner.pendingCount, 2)
        XCTAssertTrue(owner.clear(expectedGeneration: owner.generation))
        old?(); XCTAssertTrue(owner.document.entries.isEmpty)
        XCTAssertNil(owner.prepareObservation(for: record("duringClear")))
        await store.configure(); await store.complete()
        _ = await owner.drain()
        let writes = await store.writes
        XCTAssertEqual(writes.count, 3)
        XCTAssertTrue(writes.last?.entries.isEmpty == true)
        XCTAssertTrue(owner.didClear); XCTAssertTrue(owner.document.enabled)
        owner.invalidate()
    }
    func testQueuedClearRetainsWriterAfterInvalidationAndExternalOwnerRelease() async throws {
        try await assertQueuedWriteSurvivesOwnerRelease(clearHistory: true, disableRecording: false)
    }

    func testQueuedPrivacyOffRetainsWriterAfterInvalidationAndExternalOwnerRelease() async throws {
        try await assertQueuedWriteSurvivesOwnerRelease(clearHistory: false, disableRecording: true)
    }

    func testQueuedClearAndPrivacyOffCoalesceAfterInvalidationAndExternalOwnerRelease() async throws {
        try await assertQueuedWriteSurvivesOwnerRelease(clearHistory: true, disableRecording: true)
    }

    func testQueuedPrivacyOffReleasesWriterAfterFailedReceipt() async throws {
        try await assertQueuedWriteSurvivesOwnerRelease(clearHistory: false, disableRecording: true,
                                                       finalResult: .failed)
    }

    private func assertQueuedWriteSurvivesOwnerRelease(
        clearHistory: Bool, disableRecording: Bool,
        finalResult: LaunchActivitySaveResult = .saved,
        file: StaticString = #filePath, line: UInt = #line
    ) async throws {
        let firstStarted = expectation(description: "Older accepted save is suspended")
        let secondStarted = expectation(description: "Latest queued save is suspended")
        let deallocated = expectation(description: "Writer releases its owner after the final receipt")
        let fixedDate = date
        var initial = LaunchActivityDocument(enabled: true)
        initial.record(record("retained"), at: fixedDate)
        let store = ActivityControlledStore(.loaded(initial))
        await store.configure(suspended: true, onSuspendedSave: { count in
            if count == 1 { firstStarted.fulfill() }
            if count == 2 { secondStarted.fulfill() }
        })
        var owner: LaunchActivityCoordinator? = LaunchActivityCoordinator(store: store, now: {
            [probe = ActivityOwnerLifetimeProbe(date: fixedDate, deallocated: deallocated)] in
            probe.date
        })
        weak var weakOwner = owner
        await owner?.loadIfNeeded()
        owner?.setLibraryEnabled(true)
        var callbacks = 0
        owner?.onChange = { callbacks += 1 }

        owner?.prepareObservation(for: record("active"))?()
        await fulfillment(of: [firstStarted], timeout: 2)
        let activeDocument = try XCTUnwrap(owner?.document, file: file, line: line)
        // This unstarted history snapshot must be superseded, not saved as a third write.
        owner?.prepareObservation(for: record("superseded"))?()
        if clearHistory {
            let generation = try XCTUnwrap(owner?.generation, file: file, line: line)
            XCTAssertEqual(owner?.clear(expectedGeneration: generation), true, file: file, line: line)
        }
        if disableRecording {
            XCTAssertEqual(owner?.setEnabled(false), true, file: file, line: line)
        }
        let queuedDocument = try XCTUnwrap(owner?.document, file: file, line: line)
        XCTAssertEqual(queuedDocument.enabled, !disableRecording, file: file, line: line)
        XCTAssertEqual(queuedDocument.entries.count, clearHistory ? 0 : 3, file: file, line: line)
        XCTAssertEqual(owner?.pendingCount, 2, file: file, line: line)
        let beforeRelease = await store.writes
        XCTAssertEqual(beforeRelease, [activeDocument], file: file, line: line)

        owner?.invalidate()
        let callbacksAtInvalidation = callbacks
        owner = nil
        XCTAssertNotNil(weakOwner, "The accepted writer must own the queued handoff", file: file, line: line)
        await store.complete()
        await fulfillment(of: [secondStarted], timeout: 2)
        let handedOff = await store.writes
        XCTAssertEqual(handedOff, [activeDocument, queuedDocument], file: file, line: line)
        XCTAssertNotNil(weakOwner, file: file, line: line)
        XCTAssertEqual(weakOwner?.pendingCount, 1, file: file, line: line)
        XCTAssertEqual(weakOwner?.requiresQuitProtection, true, file: file, line: line)
        XCTAssertEqual(weakOwner?.isClearing, clearHistory, file: file, line: line)
        XCTAssertEqual(weakOwner?.isCollecting, false, file: file, line: line)
        XCTAssertEqual(callbacks, callbacksAtInvalidation, file: file, line: line)

        await store.complete(finalResult)
        await fulfillment(of: [deallocated], timeout: 2)
        XCTAssertNil(weakOwner, "No completed task may keep the inactive owner alive", file: file, line: line)
        let settled = await store.writes
        XCTAssertEqual(settled, [activeDocument, queuedDocument], file: file, line: line)
        XCTAssertEqual(callbacks, callbacksAtInvalidation, file: file, line: line)
    }

    func testRecordBurstHasOnlyOneActiveAndLatestQueuedWrite() async {
        let (owner, store) = await enabled(); await store.configure(suspended: true)
        owner.prepareObservation(for: record("a"))?()
        await spin { await store.writes.count == 2 }
        for i in 0..<60 { owner.prepareObservation(for: record("n" + String(i)))?() }
        XCTAssertEqual(owner.pendingCount, 2)
        let during = await store.writes; XCTAssertEqual(during.count, 2)
        await store.configure(); await store.complete(); _ = await owner.drain()
        let after = await store.writes
        XCTAssertEqual(after.count, 3); XCTAssertEqual(after.last?.entries.count, 61)
        owner.invalidate()
    }
    func testFailedWriteRetainsIntentProtectsQuitAndRetries() async {
        let (owner, store) = await enabled(); await store.configure(result: .failed)
        owner.prepareObservation(for: record())?()
        let drained = await owner.drain(); XCTAssertEqual(drained, .failed)
        XCTAssertEqual(owner.document.entries.count, 1)
        XCTAssertTrue(owner.requiresQuitProtection)
        XCTAssertNil(owner.prepareObservation(for: record("notAdmitted")))
        await store.configure(); XCTAssertTrue(owner.retry()); _ = await owner.drain()
        XCTAssertFalse(owner.requiresQuitProtection)
        XCTAssertNotNil(owner.prepareObservation(for: record()))
        owner.invalidate()
    }
    func testCorruptRecoveryIsExplicitAndNeverEnablesCollection() async {
        let store = ActivityControlledStore(.corrupt)
        let owner = LaunchActivityCoordinator(store: store)
        await owner.loadIfNeeded(); owner.setLibraryEnabled(true)
        XCTAssertFalse(owner.setEnabled(true)); XCTAssertFalse(owner.retry())
        XCTAssertTrue(owner.recover()); _ = await owner.drain()
        XCTAssertFalse(owner.document.enabled)
        XCTAssertNil(owner.prepareObservation(for: record()))
        let writes = await store.writes; XCTAssertEqual(writes.count, 1)
        owner.invalidate()
    }
    func testProtectedLoadNeverWritesEvenForClearOrRecovery() async {
        for state: LaunchActivityLoadResult in [.futureVersion, .ambiguousSchema, .oversized, .unavailable] {
            let store = ActivityControlledStore(state)
            let owner = LaunchActivityCoordinator(store: store)
            await owner.loadIfNeeded(); owner.setLibraryEnabled(true)
            XCTAssertFalse(owner.setEnabled(true)); XCTAssertFalse(owner.recover())
            XCTAssertFalse(owner.clear(expectedGeneration: owner.generation))
            let writes = await store.writes; XCTAssertTrue(writes.isEmpty)
            owner.invalidate()
        }
    }
    func testClearFailureRemainsBlockedUntilAcknowledgedRetry() async {
        let (owner, store) = await enabled(); owner.prepareObservation(for: record())?(); _ = await owner.drain()
        await store.configure(result: .failed)
        XCTAssertTrue(owner.clear(expectedGeneration: owner.generation)); _ = await owner.drain()
        XCTAssertTrue(owner.isClearing); XCTAssertTrue(owner.requiresQuitProtection)
        XCTAssertNil(owner.prepareObservation(for: record()))
        await store.configure(); XCTAssertTrue(owner.retry()); _ = await owner.drain()
        XCTAssertFalse(owner.isClearing); XCTAssertTrue(owner.didClear)
        let writes = await store.writes; XCTAssertTrue(writes.last?.entries.isEmpty == true)
        owner.invalidate()
    }
    func testInvalidateRevokesPreparedEventAndSuppressesCallbacks() async {
        let (owner, _) = await enabled(); let event = owner.prepareObservation(for: record())
        var callbacks = 0; owner.onChange = { callbacks += 1 }
        owner.invalidate(); event?()
        XCTAssertTrue(owner.document.entries.isEmpty); XCTAssertEqual(callbacks, 0)
    }
    func testStoreLocationFailsClosedAndKeepsSeparateFeatureDirectory() throws {
        XCTAssertNil(LaunchActivityStoreLocation.resolve(testProfileRequested: true, profile: nil,
            applicationSupportURL: URL(fileURLWithPath: "/fixture/support")))
        let location = try XCTUnwrap(LaunchActivityStoreLocation.resolve(testProfileRequested: false, profile: nil,
            applicationSupportURL: URL(fileURLWithPath: "/fixture/support")))
        XCTAssertEqual(location.path, "/fixture/support/Launchcopy/LaunchActivity/activity.json")
    }
    func testOptInSectionsUseExistingResultAndCompactNavigation() {
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 900, height: 600),
            strings: LocalizedStrings(language: .english))
        let original = view.numberOfRows(in: view.categoriesTable)
        view.setActivitySectionsEnabled(true)
        XCTAssertEqual(view.numberOfRows(in: view.categoriesTable), original + 2)
        XCTAssertEqual(view.compactCategoryPicker.itemTitle(at: 1), LocalizedStrings(language: .english).launchActivityText(.recent))
        view.compactCategoryPicker.selectItem(at: 1); view.compactCategoryChanged(nil)
        XCTAssertEqual(view.selectedActivitySection, .recent); XCTAssertNil(view.selectedCategory)
        view.compactCategoryPicker.selectItem(at: 2); view.compactCategoryChanged(nil)
        XCTAssertEqual(view.selectedActivitySection, .frequent)
        view.compactCategoryPicker.selectItem(at: 3); view.compactCategoryChanged(nil)
        XCTAssertNil(view.selectedActivitySection); XCTAssertEqual(view.selectedCategory, AppLibraryCategory.allCases.first)
        view.setActivitySectionsEnabled(false)
        XCTAssertEqual(view.numberOfRows(in: view.categoriesTable), original)
    }
    func testExistingExpiredHistoryPrunesOnLoadWithoutChangingOptIn() async {
        var doc = LaunchActivityDocument(enabled: true)
        doc.record(record(), at: date.addingTimeInterval(-40 * 86_400))
        doc.enabled = false
        let store = ActivityControlledStore(.loaded(doc))
        let owner = LaunchActivityCoordinator(store: store, now: { self.date })
        await owner.loadIfNeeded(); _ = await owner.drain()
        XCTAssertFalse(owner.document.enabled); XCTAssertTrue(owner.document.entries.isEmpty)
        let writes = await store.writes
        XCTAssertEqual(writes.count, 1); XCTAssertFalse(writes[0].enabled)
        XCTAssertTrue(writes[0].entries.isEmpty)
        owner.invalidate()
    }

    func testPendingActivityWriteParticipatesInActualQuitOwnerAndCancel() async throws {
        let store = ActivityControlledStore()
        await store.configure(suspended: true)
        let app = AppDelegate(options: .default)
        let host = NSView(frame: .init(x: 0, y: 0, width: 900, height: 600))
        app.installAppLibrary(in: host, store: ActivityEnabledLibraryStore(), activityStore: store)
        let library = try XCTUnwrap(app.appLibraryOwner)
        await library.preferences.loadIfNeeded()
        let activity = try XCTUnwrap(library.activity)
        await activity.loadIfNeeded(); activity.setLibraryEnabled(true)
        XCTAssertTrue(activity.setEnabled(true))
        await spin { await store.writes.count == 1 }
        var reply: Bool?, failure: LayoutStoreFlushResult?
        let outcome = app.requestWorkspaceQuit(reply: { reply = $0 }, chooseOnFailure: { result, complete in
            failure = result; complete(false)
        })
        XCTAssertEqual(outcome, .terminateLater)
        await store.complete(.failed)
        await spin { reply != nil }
        XCTAssertEqual(reply, false); XCTAssertEqual(failure, .failed)
        XCTAssertTrue(activity.requiresQuitProtection)
        library.teardown()
    }

    func testBackgroundLibraryProjectionUsesActivityOrderingAndSharedQueryFiltering() async throws {
        let alpha = record("alpha"), beta = record("beta")
        var document = LaunchActivityDocument(enabled: true)
        document.record(alpha, at: date.addingTimeInterval(-60))
        document.record(beta, at: date)
        let catalog = CatalogSnapshot(revision: .init(7), records: [alpha, beta])
        let projection = AppLibraryProjectionController()
        projection.open(.init(catalog: catalog, management: .default, preferences: .init(enabled: true),
            activity: document, activitySection: .recent, activityNow: date))
        await spin { projection.snapshot != nil }
        XCTAssertEqual(projection.snapshot?.entries.map(\.record.id), [beta.id, alpha.id])
        let hidden = AppManagementPreferences.default.settingHidden(true, for: beta)
        projection.update(.init(catalog: catalog, management: hidden, preferences: .init(enabled: true),
            query: "alpha", activity: document, activitySection: .frequent, activityNow: date))
        await spin { projection.snapshot != nil }
        XCTAssertEqual(projection.snapshot?.entries.map(\.record.id), [alpha.id])
        projection.close()
    }

    func testReviewClearThenPrivacyDisableSettlesBothActiveAndQueuedClear() async {
        for olderWrite in [false, true] {
            for result: LaunchActivitySaveResult in [.saved, .failed] {
                let (owner, store) = await enabled()
                await store.configure(suspended: true)
                if olderWrite {
                    owner.prepareObservation(for: record())?()
                    await spin { await store.writes.count == 2 }
                }
                XCTAssertTrue(owner.clear(expectedGeneration: owner.generation))
                if !olderWrite { await spin { await store.writes.count == 2 } }
                XCTAssertTrue(owner.setEnabled(false))
                await store.configure(result: result); await store.complete()
                _ = await owner.drain()
                if result == .failed {
                    XCTAssertTrue(owner.requiresQuitProtection)
                    await store.configure(); XCTAssertTrue(owner.retry()); _ = await owner.drain()
                }
                XCTAssertFalse(owner.document.enabled)
                XCTAssertTrue(owner.document.entries.isEmpty)
                XCTAssertFalse(owner.isClearing)
                XCTAssertTrue(owner.setEnabled(true))
                _ = await owner.drain()
                owner.invalidate()
            }
        }
    }

    func testReviewFailedLibraryDisableNeverAutomaticallyResumesRecording() async throws {
        for failureResult: AppLibrarySaveResult in [.failed, .unavailable, .protectedPayload] {
            var doc = LaunchActivityDocument(enabled: true)
            doc.record(record(), at: date)
            let activity = LaunchActivityCoordinator(store: ActivityControlledStore(.loaded(doc)), now: { self.date })
            let store = ActivityToggleLibraryStore()
            let preferences = AppLibraryPreferencesCoordinator(store: store)
            let owner = AppLibraryOwnerController(preferences: preferences,
                strings: LocalizedStrings(language: .english), activity: activity)
            owner.canTransition = { true }
            let host = NSView(frame: .init(x: 0, y: 0, width: 900, height: 600))
            owner.attach(to: host)
            await preferences.loadIfNeeded(); await activity.loadIfNeeded()
            await spin { activity.libraryEnabled }
            let settings = AppLibrarySettingsView(frame: host.bounds, strings: .init(language: .english))
            owner.configureSettings(settings)
            XCTAssertTrue(activity.isCollecting)
            XCTAssertEqual(settings.onSetEnabled?(false), true)
            XCTAssertFalse(activity.isCollecting)
            await spin { await store.submissions == 1 }
            await store.complete(failureResult)
            await spin { preferences.pendingCount == 0 }
            XCTAssertTrue(preferences.committed.enabled) // Existing acknowledged preference remains ON.
            XCTAssertFalse(activity.isCollecting) // Privacy stop must not be rolled back with the preference.
            XCTAssertNil(activity.prepareObservation(for: record("notAdmitted")))
            XCTAssertTrue(preferences.submit(.init(enabled: true)))
            await spin { await store.submissions == 2 }; await store.complete(.saved)
            await spin { preferences.pendingCount == 0 }
            XCTAssertFalse(activity.isCollecting) // An unrelated save is not a new opt-in.
            settings.activitySettingsView.onSetEnabled?(false); _ = await activity.drain()
            settings.activitySettingsView.onSetEnabled?(true); _ = await activity.drain()
            XCTAssertTrue(activity.isCollecting) // Only an explicit activity opt-in resumes it.
            owner.teardown()
        }
    }

    func testReviewPrivacyDisableDuringInitialLoadCannotBeOverwrittenByLoadedOptIn() async throws {
        var old = LaunchActivityDocument(enabled: true)
        old.record(record(), at: date)
        let activityStore = ActivityDelayedLoadStore()
        let activity = LaunchActivityCoordinator(store: activityStore, now: { self.date })
        let libraryStore = ActivityToggleLibraryStore()
        let preferences = AppLibraryPreferencesCoordinator(store: libraryStore)
        let owner = AppLibraryOwnerController(preferences: preferences,
            strings: .init(language: .english), activity: activity)
        owner.canTransition = { true }
        let host = NSView(frame: .init(x: 0, y: 0, width: 900, height: 600))
        owner.attach(to: host); await preferences.loadIfNeeded()
        await spin { await activityStore.loadStarted }
        let settings = AppLibrarySettingsView(frame: host.bounds, strings: .init(language: .english))
        owner.configureSettings(settings)
        XCTAssertFalse(activity.isLoaded)
        XCTAssertEqual(settings.onSetEnabled?(false), true)
        XCTAssertTrue(activity.requiresQuitProtection)
        await spin { await libraryStore.submissions == 1 }; await libraryStore.complete(.failed)
        await spin { preferences.pendingCount == 0 }
        await activityStore.release(.loaded(old))
        await spin { activity.isLoaded }; _ = await activity.drain()
        XCTAssertFalse(activity.document.enabled)
        XCTAssertFalse(activity.isCollecting)
        XCTAssertEqual(activity.document.entries.count, 1) // Keep history, not old consent.
        let writes = await activityStore.writes
        XCTAssertEqual(writes.count, 1)
        XCTAssertFalse(writes.last?.enabled ?? true)
        owner.teardown()
    }

    func testPreloadPrivacyStopHasBoundedQuitProtectionAndNeverOverwritesProtectedFiles() async {
        for state: LaunchActivityLoadResult in [.missing, .corrupt, .unavailable, .futureVersion, .ambiguousSchema, .oversized] {
            let store = ActivityControlledStore(state)
            let owner = LaunchActivityCoordinator(store: store)
            XCTAssertTrue(owner.setEnabled(false))
            XCTAssertTrue(owner.requiresQuitProtection)
            let pendingDrain = await owner.drain(timeout: .zero)
            XCTAssertEqual(pendingDrain, .timedOut)
            await owner.loadIfNeeded()
            XCTAssertFalse(owner.document.enabled); XCTAssertFalse(owner.isCollecting)
            let result = await owner.drain()
            if state == .missing {
                XCTAssertEqual(result, .nothingPending)
                XCTAssertFalse(owner.requiresQuitProtection)
            } else {
                XCTAssertTrue(owner.requiresQuitProtection)
                XCTAssertTrue(result == .readOnly || result == .failed)
            }
            let writes = await store.writes; XCTAssertTrue(writes.isEmpty)
            owner.invalidate()
        }
    }

}
