import AppGridUI
import Foundation
import XCTest
@testable import PagingPrototypeApp

private actor CapacityGatedStore: MainGridCapacityPersisting {
    private var persisted: MainGridCapacity
    private let initial: MainGridCapacityLoadResult
    private var completions: [CheckedContinuation<MainGridCapacitySaveResult, Never>] = []
    private(set) var submissions: [MainGridCapacity] = []
    private(set) var recoveryFlags: [Bool] = []
    private(set) var loadCount = 0

    init(initial: MainGridCapacityLoadResult = .loaded(.default)) {
        self.initial = initial
        persisted = initial.capacity
    }

    func load() -> MainGridCapacityLoadResult { loadCount += 1; return initial }

    func save(_ capacity: MainGridCapacity, recoveringCorruptPayload: Bool) async -> MainGridCapacitySaveResult {
        submissions.append(capacity)
        recoveryFlags.append(recoveringCorruptPayload)
        return await withCheckedContinuation { completions.append($0) }
    }

    func finish(_ result: MainGridCapacitySaveResult) {
        guard !completions.isEmpty else { return }
        if result == .saved { persisted = submissions[submissions.count - completions.count] }
        completions.removeFirst().resume(returning: result)
    }

    var count: Int { submissions.count }
}

@MainActor
final class MainGridCapacityCoordinatorTests: XCTestCase {
    private var small: MainGridCapacity { MainGridCapacity(columns: 3, rows: 3)! }
    private var large: MainGridCapacity { MainGridCapacity(columns: 8, rows: 8)! }

    private func waitForCount(_ count: Int, in store: CapacityGatedStore) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while await store.count < count, ContinuousClock.now < deadline { await Task.yield() }
        let actual = await store.count
        XCTAssertEqual(actual, count)
    }

    func testTwoHundredSelectionsKeepOnlyActiveAndLatestQueuedWrite() async {
        let store = CapacityGatedStore()
        let owner = MainGridCapacityCoordinator(store: store)
        await owner.loadIfNeeded()
        owner.submit(small)
        await waitForCount(1, in: store)
        for n in 0..<200 {
            let shape = MainGridCapacity(columns: 3 + n % 6, rows: 3 + (n / 6) % 6)!
            XCTAssertTrue(owner.submit(shape))
            XCTAssertLessThanOrEqual(owner.pendingCount, 2)
        }
        let newest = owner.requestedCapacity
        await store.finish(.saved)
        await waitForCount(2, in: store)
        let submitted = await store.submissions
        XCTAssertEqual(submitted, [small, newest])
        await store.finish(.saved)
        let result = await owner.drain()
        if case .persisted = result {} else { XCTFail("Expected actual newest receipt") }
        XCTAssertEqual(owner.committed, newest)
        XCTAssertFalse(owner.requiresQuitProtection)
    }

    func testHealthyEqualIdleSubmissionDoesNotWriteOrRequireQuitProtection() async {
        let store = CapacityGatedStore()
        let owner = MainGridCapacityCoordinator(store: store)
        await owner.loadIfNeeded()
        XCTAssertTrue(owner.submit(.default))
        XCTAssertEqual(owner.pendingCount, 0)
        XCTAssertFalse(owner.requiresQuitProtection)
        if owner.pendingCount > 0 {
            await waitForCount(1, in: store)
            await store.finish(.saved)
            _ = await owner.drain()
        }
        let count = await store.count
        XCTAssertEqual(count, 0)
    }

    func testLoadIsSharedAndCannotSubmitBeforeInspection() async {
        let store = CapacityGatedStore()
        let owner = MainGridCapacityCoordinator(store: store)
        XCTAssertFalse(owner.submit(large))
        async let a: Void = owner.loadIfNeeded()
        async let b: Void = owner.loadIfNeeded()
        _ = await (a, b)
        let loads = await store.loadCount
        XCTAssertEqual(loads, 1)
        XCTAssertTrue(owner.isLoaded)
        XCTAssertEqual(owner.committed, .default)
        let drained = await owner.drain()
        XCTAssertEqual(drained, .nothingPending)
        XCTAssertFalse(owner.requiresQuitProtection)
    }

    func testSerialReceiptsOnlyPublishNewestAfterItsActualSuccess() async {
        let store = CapacityGatedStore()
        let owner = MainGridCapacityCoordinator(store: store)
        await owner.loadIfNeeded()
        XCTAssertTrue(owner.submit(small))
        XCTAssertTrue(owner.submit(large))
        await waitForCount(1, in: store)
        XCTAssertEqual(owner.pendingCount, 2)
        XCTAssertTrue(owner.requiresQuitProtection)
        await store.finish(.saved)
        await waitForCount(2, in: store)
        XCTAssertEqual(owner.committed, .default)
        XCTAssertEqual(owner.persistedCapacity, small)
        await store.finish(.saved)
        let drained = await owner.drain()
        XCTAssertEqual(drained, .persisted(writeGeneration: 2))
        XCTAssertEqual(owner.committed, large)
        XCTAssertEqual(owner.pendingCount, 0)
        XCTAssertFalse(owner.requiresQuitProtection)
    }

    func testLatestFailurePublishesPriorRealReceiptAndProtectsQuitUntilRetry() async {
        let store = CapacityGatedStore()
        let owner = MainGridCapacityCoordinator(store: store)
        await owner.loadIfNeeded()
        owner.submit(small)
        owner.submit(large)
        await waitForCount(1, in: store)
        await store.finish(.saved)
        await waitForCount(2, in: store)
        await store.finish(.failed)
        let failure = await owner.drain()
        XCTAssertEqual(failure, .failed)
        XCTAssertEqual(owner.committed, small)
        XCTAssertTrue(owner.requiresQuitProtection)
        owner.submit(large)
        await waitForCount(3, in: store)
        await store.finish(.saved)
        let success = await owner.drain()
        XCTAssertEqual(success, .persisted(writeGeneration: 3))
        XCTAssertEqual(owner.committed, large)
        XCTAssertFalse(owner.requiresQuitProtection)
    }

    func testTimeoutRetainsWriteAndLaterDrainSeesItsReceipt() async {
        let store = CapacityGatedStore()
        let owner = MainGridCapacityCoordinator(store: store)
        await owner.loadIfNeeded()
        owner.submit(large)
        await waitForCount(1, in: store)
        let before = ContinuousClock.now
        let result = await owner.drain(timeout: .milliseconds(5))
        XCTAssertEqual(result, .timedOut)
        XCTAssertLessThan(before.duration(to: .now), .seconds(1))
        XCTAssertEqual(owner.pendingCount, 1)
        XCTAssertTrue(owner.requiresQuitProtection)
        await store.finish(.saved)
        let receipt = await owner.drain()
        XCTAssertEqual(receipt, .persisted(writeGeneration: 1))
        XCTAssertEqual(owner.committed, large)
    }

    func testInvalidationSuppressesCallbacksButNotAcceptedWrites() async {
        let store = CapacityGatedStore()
        let owner = MainGridCapacityCoordinator(store: store)
        await owner.loadIfNeeded()
        owner.submit(large)
        await waitForCount(1, in: store)
        var callbacks = 0
        owner.onChange = { callbacks += 1 }
        owner.invalidate()
        await store.finish(.saved)
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while owner.pendingCount > 0, ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertEqual(owner.pendingCount, 0)
        XCTAssertEqual(owner.persistedCapacity, large)
        XCTAssertEqual(owner.committed, .default)
        XCTAssertEqual(callbacks, 0)
        XCTAssertFalse(owner.submit(small))
        let stale = await owner.drain()
        XCTAssertEqual(stale, .staleRejected)
    }

    func testProtectedOrUnavailableLoadCannotAcceptAWrite() async {
        for state: MainGridCapacityLoadResult in [.protectedPayload, .unavailable] {
            let store = CapacityGatedStore(initial: state)
            let owner = MainGridCapacityCoordinator(store: store)
            await owner.loadIfNeeded()
            XCTAssertFalse(owner.submit(large, recoveringCorruptPayload: true))
            let writes = await store.count
            XCTAssertEqual(writes, 0)
            XCTAssertEqual(owner.committed, .default)
        }
    }

    func testExplicitCorruptRecoveryFlagReachesStoreAndFailureStaysReadOnly() async {
        let store = CapacityGatedStore(initial: .corrupt)
        let owner = MainGridCapacityCoordinator(store: store)
        await owner.loadIfNeeded()
        owner.submit(small)
        await waitForCount(1, in: store)
        await store.finish(.recoveryRequired)
        let protected = await owner.drain()
        XCTAssertEqual(protected, .readOnly)
        XCTAssertEqual(owner.loadResult, .corrupt)
        owner.submit(small, recoveringCorruptPayload: true)
        await waitForCount(2, in: store)
        await store.finish(.saved)
        let recovered = await owner.drain()
        XCTAssertEqual(recovered, .persisted(writeGeneration: 2))
        XCTAssertEqual(owner.loadResult, .loaded(small))
        let flags = await store.recoveryFlags
        XCTAssertEqual(flags, [false, true])
    }
}
