import AppGridUI
import Foundation
import XCTest
@testable import PagingPrototypeApp

private actor LibraryGatedStore: AppLibraryPersisting {
    private(set) var submissions: [AppLibraryPreferences] = []
    private var completions: [CheckedContinuation<AppLibrarySaveResult, Never>] = []
    private var persisted: AppLibraryPreferences = .default
    func load() -> AppLibraryLoadResult { .loaded(persisted) }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) async -> AppLibrarySaveResult {
        submissions.append(preferences)
        return await withCheckedContinuation { completions.append($0) }
    }
    func complete(_ result: AppLibrarySaveResult) {
        if result == .saved { persisted = submissions[submissions.count - completions.count] }
        completions.removeFirst().resume(returning: result)
    }
    var count: Int { submissions.count }
}

@MainActor
final class AppLibraryPreferencesCoordinatorTests: XCTestCase {
    private func waitForCount(_ expected: Int, in store: LibraryGatedStore) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while await store.count < expected, ContinuousClock.now < deadline { await Task.yield() }
        let count = await store.count
        XCTAssertEqual(count, expected)
    }

    func testAcceptedWritesAreSerialAndOnlyLatestSuccessPublishes() async {
        let store = LibraryGatedStore()
        let owner = AppLibraryPreferencesCoordinator(store: store)
        await owner.loadIfNeeded()
        let first = AppLibraryPreferences(enabled: true)
        let second = AppLibraryPreferences(enabled: true, categoryOverrides: ["bundle:fixture": .video])
        XCTAssertTrue(owner.submit(first))
        XCTAssertTrue(owner.submit(second))
        await waitForCount(1, in: store)
        XCTAssertEqual(owner.pendingCount, 2)
        XCTAssertEqual(owner.committed, .default)
        await store.complete(.saved)
        await waitForCount(2, in: store)
        XCTAssertEqual(owner.committed, .default)
        await store.complete(.saved)
        let drained = await owner.drain()
        XCTAssertEqual(drained, .persisted(writeGeneration: 2))
        XCTAssertEqual(owner.committed, second)
        XCTAssertEqual(owner.pendingCount, 0)
    }

    func testSaveFailurePreservesPriorPresentationAndQuitDrainIsFailure() async {
        let store = LibraryGatedStore()
        let owner = AppLibraryPreferencesCoordinator(store: store)
        await owner.loadIfNeeded()
        XCTAssertTrue(owner.submit(.init(enabled: true)))
        await waitForCount(1, in: store)
        await store.complete(.failed)
        let drained = await owner.drain()
        XCTAssertEqual(drained, .failed)
        XCTAssertEqual(owner.committed, .default)
        XCTAssertEqual(owner.latestSaveResult, .failed)
    }

    func testTimedOutDrainDoesNotCancelOrForgetAcceptedWrite() async {
        let store = LibraryGatedStore()
        let owner = AppLibraryPreferencesCoordinator(store: store)
        await owner.loadIfNeeded()
        owner.submit(.init(enabled: true))
        await waitForCount(1, in: store)
        let start = ContinuousClock.now
        let result = await owner.drain(timeout: .milliseconds(5))
        XCTAssertEqual(result, .timedOut)
        XCTAssertLessThan(start.duration(to: .now), .seconds(1))
        XCTAssertEqual(owner.pendingCount, 1)
        await store.complete(.saved)
        let drained = await owner.drain()
        XCTAssertEqual(drained, .persisted(writeGeneration: 1))
        XCTAssertTrue(owner.committed.enabled)
    }

    func testInvalidationSuppressesLateUIWithoutCancellingAcceptedWrite() async {
        let store = LibraryGatedStore()
        let owner = AppLibraryPreferencesCoordinator(store: store)
        await owner.loadIfNeeded()
        owner.submit(.init(enabled: true))
        await waitForCount(1, in: store)
        owner.invalidate()
        await store.complete(.saved)
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while owner.pendingCount > 0, ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertEqual(owner.pendingCount, 0)
        XCTAssertFalse(owner.committed.enabled)
        XCTAssertFalse(owner.submit(.init(enabled: true)))
    }

    func testCannotSubmitBeforeLazyLoad() async {
        let store = LibraryGatedStore()
        let owner = AppLibraryPreferencesCoordinator(store: store)
        XCTAssertFalse(owner.submit(.init(enabled: true)))
        let idle = await owner.drain()
        XCTAssertEqual(idle, .nothingPending)
        await owner.loadIfNeeded()
        XCTAssertTrue(owner.isLoaded)
        XCTAssertEqual(owner.loadResult, .loaded(.default))
    }

    func testEarlierSuccessAndLatestFailureRetainActualPersistedBaselineForNextDraft() async {
        let store = LibraryGatedStore()
        let owner = AppLibraryPreferencesCoordinator(store: store)
        await owner.loadIfNeeded()
        let accepted = AppLibraryPreferences(enabled: true, categoryOverrides: ["bundle:fixture": .music])
        let failing = AppLibraryPreferences(enabled: false, categoryOverrides: ["bundle:fixture": .video])
        owner.submit(accepted)
        owner.submit(failing)
        await waitForCount(1, in: store)
        await store.complete(.saved)
        await waitForCount(2, in: store)
        XCTAssertEqual(owner.persistedPreferences, accepted)
        XCTAssertEqual(owner.persistedGeneration, 1)
        XCTAssertEqual(owner.committed, .default, "Do not expose an intermediate draft while the newer request is pending")
        await store.complete(.failed)
        let drained = await owner.drain()
        XCTAssertEqual(drained, .failed)
        XCTAssertEqual(owner.latestSaveResult, .failed)
        XCTAssertEqual(owner.committed, accepted, "Terminal failure must not pretend the file is still the original baseline")
        let reloaded = await store.load()
        XCTAssertEqual(reloaded, .loaded(owner.committed))
        var nextDraft = owner.committed
        nextDraft.categoryOverrides["bundle:second"] = .business
        owner.submit(nextDraft)
        await waitForCount(3, in: store)
        await store.complete(.saved)
        _ = await owner.drain()
        XCTAssertEqual(owner.committed.categoryOverrides["bundle:fixture"], .music)
        XCTAssertEqual(owner.committed.categoryOverrides["bundle:second"], .business)
    }
}
