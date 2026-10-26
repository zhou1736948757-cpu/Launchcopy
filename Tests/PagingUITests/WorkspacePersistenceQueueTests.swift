import AppGridUI
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class WorkspacePersistenceQueueTests: XCTestCase {
    private actor Store: LayoutStore {
        nonisolated let storeDirectory = URL(fileURLWithPath: "/SyntheticQueueStore")
        private(set) var enqueued: [UInt64] = []
        private(set) var started = 0
        private(set) var flushes = 0
        private var gate: CheckedContinuation<Void, Never>?
        private let suspendsFirst: Bool
        var flushResult: LayoutStoreFlushResult
        private var script: [LayoutStoreFlushResult] = []
        func setFlushScript(_ results: [LayoutStoreFlushResult]) { script = results }
        private var flushGate: CheckedContinuation<Void, Never>?
        private var suspendsFlush = false
        private var stateGate: CheckedContinuation<Void, Never>?
        private var suspendsState = false
        private(set) var stateCalls = 0
        func suspendState() { suspendsState = true }
        func releaseState() { suspendsState = false; stateGate?.resume(); stateGate = nil }
        init(suspendsFirst: Bool = false, flushResult: LayoutStoreFlushResult = .persisted(writeGeneration: 2)) {
            self.suspendsFirst = suspendsFirst; self.flushResult = flushResult
        }
        func load() async -> LayoutStoreLoadResult { .firstLaunch }
        func enqueue(_ layout: PersistentWorkspaceLayout) async {
            started += 1
            if suspendsFirst && started == 1 { await withCheckedContinuation { gate = $0 } }
            enqueued.append(layout.generation.value)
        }
        func release() { gate?.resume(); gate = nil }
        func suspendFlush() { suspendsFlush = true }
        func resumeFlush(with result: LayoutStoreFlushResult) {
            flushResult = result; suspendsFlush = false
            flushGate?.resume(); flushGate = nil
        }
        func flush() async -> LayoutStoreFlushResult {
            flushes += 1
            let scripted = script.isEmpty ? nil : script.removeFirst()
            if suspendsFlush { await withCheckedContinuation { flushGate = $0 } }
            return scripted ?? flushResult
        }
        func reset(defaultLayout: PersistentWorkspaceLayout) async -> LayoutStoreResetResult { .failed }
        func currentState() async -> LayoutStoreState {
            stateCalls += 1
            if suspendsState { await withCheckedContinuation { stateGate = $0 } }
            return .healthy
        }
        func lockMode() async -> LayoutStoreLockMode { .singleWriter }
        func staleRejectionCount() async -> UInt64 { 0 }
    }
    private func layout(_ generation: UInt64) -> PersistentWorkspaceLayout {
        .init(generation: LayoutGeneration(generation), topLevelOrder: [], folders: [])
    }
    private func waitForStart(_ store: Store) async {
        for _ in 0..<1000 { if await store.started > 0 { return }; await Task.yield() }
        XCTFail("Enqueue did not start")
    }

    func testDrainWaitsForAcceptedEnqueueBeforeFlush() async {
        let queue = WorkspacePersistenceQueue(), store = Store(suspendsFirst: true)
        queue.submit(layout(1), to: store, epoch: 1, isCurrent: { true }, observeState: { _ in })
        let drain = Task { await queue.drain(to: store, epoch: 1, isCurrent: { true }) }
        await waitForStart(store)
        let before = await store.flushes
        XCTAssertEqual(before, 0)
        await store.release()
        let result = await drain.value
        XCTAssertEqual(result, .persisted(writeGeneration: 2))
        let values = await store.enqueued, flushes = await store.flushes
        XCTAssertEqual(values, [1]); XCTAssertEqual(flushes, 1); XCTAssertEqual(queue.pendingCount, 0)
    }

    func testAcceptedWritesSerializeInSubmissionOrderWithinStoreEpoch() async {
        let queue = WorkspacePersistenceQueue(), store = Store(suspendsFirst: true)
        queue.submit(layout(1), to: store, epoch: 1, isCurrent: { true }, observeState: { _ in })
        queue.submit(layout(2), to: store, epoch: 1, isCurrent: { true }, observeState: { _ in })
        await waitForStart(store)
        let started = await store.started
        XCTAssertEqual(started, 1)
        await store.release()
        _ = await queue.drain(to: store, epoch: 1, isCurrent: { true })
        let values = await store.enqueued
        XCTAssertEqual(values, [1, 2]); XCTAssertEqual(queue.pendingCount, 0)
    }

    func testSupersededQueuedWriteNeverWritesOrPublishesIntoReplacementStore() async {
        let queue = WorkspacePersistenceQueue(), old = Store(), replacement = Store()
        var epoch: UInt64 = 1
        var oldFeedback = 0, currentFeedback = 0
        queue.submit(layout(1), to: old, epoch: 1, isCurrent: { epoch == 1 }, observeState: { _ in oldFeedback += 1 })
        epoch = 2
        queue.submit(layout(2), to: replacement, epoch: 2, isCurrent: { epoch == 2 }, observeState: { _ in currentFeedback += 1 })
        _ = await queue.drain(to: replacement, epoch: 2, isCurrent: { epoch == 2 })
        for _ in 0..<1000 { if currentFeedback == 1 { break }; try? await Task.sleep(for: .milliseconds(1)) }
        let previous = await old.enqueued, current = await replacement.enqueued
        XCTAssertTrue(previous.isEmpty); XCTAssertEqual(current, [2])
        XCTAssertEqual(oldFeedback, 0); XCTAssertEqual(currentFeedback, 1)
    }

    func testBoundedDrainTimeoutDoesNotFlushOrDropAcceptedWork() async {
        let queue = WorkspacePersistenceQueue(), store = Store(suspendsFirst: true)
        queue.submit(layout(1), to: store, epoch: 1, isCurrent: { true }, observeState: { _ in })
        await waitForStart(store)
        let result = await queue.drain(to: store, epoch: 1, enqueueWait: .zero, isCurrent: { true })
        XCTAssertEqual(result, .timedOut)
        XCTAssertEqual(queue.pendingCount, 1)
        let flushes = await store.flushes
        XCTAssertEqual(flushes, 0)
        await store.release()
        let retry = await queue.drain(to: store, epoch: 1, isCurrent: { true })
        XCTAssertEqual(retry, .persisted(writeGeneration: 2))
    }

    func testStaleDrainRejectsBeforeFlushing() async {
        let queue = WorkspacePersistenceQueue(), store = Store()
        let result = await queue.drain(to: store, epoch: 1, isCurrent: { false })
        XCTAssertEqual(result, .staleRejected)
        let flushes = await store.flushes
        XCTAssertEqual(flushes, 0)
    }

    func testStoreFlushFailureIsNotClaimedAsDurableSuccess() async {
        let queue = WorkspacePersistenceQueue(), store = Store(flushResult: .failed)
        queue.submit(layout(1), to: store, epoch: 1, isCurrent: { true }, observeState: { _ in })
        let result = await queue.drain(to: store, epoch: 1, isCurrent: { true })
        XCTAssertEqual(result, .failed)
    }

    func testReadOnlyAndEmptyFlushResultsRemainExplicit() async {
        for result in [LayoutStoreFlushResult.readOnly, .nothingPending] {
            let queue = WorkspacePersistenceQueue(), store = Store(flushResult: result)
            let drained = await queue.drain(to: store, epoch: 1, isCurrent: { true })
            XCTAssertEqual(drained, result)
        }
    }
    func testStalledFlushDeadlineRetainsOneOperationAndLateFailureIsObserved() async {
        let queue = WorkspacePersistenceQueue(), store = Store()
        await store.suspendFlush()
        var results: [LayoutStoreFlushResult] = []
        queue.submit(layout(1), to: store, epoch: 1, isCurrent: { true }, observeState: { _ in },
                     observeOutcome: { results.append($0) })
        for _ in 0..<1000 { if await store.flushes > 0 { break }; await Task.yield() }
        let clock = ContinuousClock(), start = clock.now
        let result = await queue.drain(to: store, epoch: 1, flushWait: .milliseconds(12), isCurrent: { true })
        XCTAssertEqual(result, .timedOut)
        XCTAssertLessThan(start.duration(to: clock.now), .seconds(1))
        let second = await queue.drain(to: store, epoch: 1, flushWait: .zero, isCurrent: { true })
        XCTAssertEqual(second, .timedOut)
        let calls = await store.flushes
        XCTAssertEqual(calls, 1)
        await store.resumeFlush(with: .failed)
        for _ in 0..<1000 { if !results.isEmpty { break }; try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertEqual(results, [.failed])
        // A failure is not cached as durability. A subsequent flush may recover.
        await store.resumeFlush(with: .persisted(writeGeneration: 3))
        let retry = await queue.drain(to: store, epoch: 1, isCurrent: { true })
        XCTAssertEqual(retry, .persisted(writeGeneration: 3))
    }

    func testDelayedOldEpochFlushNeverPublishesFeedbackAfterReplacement() async {
        let queue = WorkspacePersistenceQueue(), store = Store()
        await store.suspendFlush()
        var current = true, results: [LayoutStoreFlushResult] = []
        queue.submit(layout(1), to: store, epoch: 1, isCurrent: { current }, observeState: { _ in },
                     observeOutcome: { results.append($0) })
        for _ in 0..<1000 { if await store.flushes > 0 { break }; await Task.yield() }
        current = false
        await store.resumeFlush(with: .failed)
        for _ in 0..<20 { try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertTrue(results.isEmpty)
    }

    func testNewAcceptedBatchCannotReuseOldSuccessfulReceipt() async {
        let queue = WorkspacePersistenceQueue(), store = Store()
        queue.submit(layout(1), to: store, epoch: 1, isCurrent: { true }, observeState: { _ in })
        _ = await queue.drain(to: store, epoch: 1, isCurrent: { true })
        await store.resumeFlush(with: .failed)
        queue.submit(layout(2), to: store, epoch: 1, isCurrent: { true }, observeState: { _ in })
        let result = await queue.drain(to: store, epoch: 1, isCurrent: { true })
        XCTAssertEqual(result, .failed)
        let calls = await store.flushes
        XCTAssertGreaterThanOrEqual(calls, 2)
    }

    func testSubmissionDuringOngoingFlushRequiresAnotherReceiptForLatestBatch() async {
        let queue = WorkspacePersistenceQueue(), store = Store()
        await store.setFlushScript([.persisted(writeGeneration: 3), .failed])
        await store.suspendFlush()
        var results: [LayoutStoreFlushResult] = []
        queue.submit(layout(1), to: store, epoch: 1, isCurrent: { true }, observeState: { _ in },
                     observeOutcome: { results.append($0) })
        for _ in 0..<1000 { if await store.flushes > 0 { break }; await Task.yield() }
        let timeout = await queue.drain(to: store, epoch: 1, flushWait: .zero, isCurrent: { true })
        XCTAssertEqual(timeout, .timedOut)
        queue.submit(layout(2), to: store, epoch: 1, isCurrent: { true }, observeState: { _ in },
                     observeOutcome: { results.append($0) })
        let drain = Task { await queue.drain(to: store, epoch: 1, isCurrent: { true }) }
        await store.resumeFlush(with: .failed)
        let result = await drain.value
        XCTAssertEqual(result, .failed)
        for _ in 0..<1000 { if !results.isEmpty { break }; try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertEqual(results, [.failed], "Older success must not clear the latest batch's failure notice")
        let calls = await store.flushes
        XCTAssertGreaterThanOrEqual(calls, 2, "Earlier receipt cannot certify the newer enqueue; failed receipts may be retried")
    }

    func testEnqueueDuringSuspendedStateObservationStillObservesNewestFailure() async {
        let queue = WorkspacePersistenceQueue(), store = Store()
        await store.suspendState()
        var results: [LayoutStoreFlushResult] = []
        queue.submit(layout(1), to: store, epoch: 1, isCurrent: { true }, observeState: { _ in },
                     observeOutcome: { results.append($0) })
        for _ in 0..<1000 { if await store.stateCalls > 0 { break }; try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertEqual(results, [.persisted(writeGeneration: 2)])
        await store.resumeFlush(with: .failed)
        queue.submit(layout(2), to: store, epoch: 1, isCurrent: { true }, observeState: { _ in },
                     observeOutcome: { results.append($0) })
        for _ in 0..<1000 { if await store.enqueued.count == 2 { break }; await Task.yield() }
        await store.releaseState()
        for _ in 0..<1000 { if results.count == 2 { break }; try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertEqual(results, [.persisted(writeGeneration: 2), .failed])
    }

    func testAutomaticTimeoutCallbacksCannotPublishOldSuccessForNewerBatch() async {
        let queue = WorkspacePersistenceQueue(observationWait: .milliseconds(15)), store = Store()
        await store.setFlushScript([.persisted(writeGeneration: 3), .failed])
        await store.suspendFlush()
        var results: [LayoutStoreFlushResult] = []
        let observe: (LayoutStoreFlushResult) -> Void = { results.append($0) }
        queue.submit(layout(1), to: store, epoch: 1, isCurrent: { true }, observeState: { _ in }, observeOutcome: observe)
        for _ in 0..<1000 { if results.count == 1 { break }; try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertEqual(results, [.timedOut])
        queue.submit(layout(2), to: store, epoch: 1, isCurrent: { true }, observeState: { _ in }, observeOutcome: observe)
        for _ in 0..<1000 { if results.count == 2 { break }; try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertEqual(results, [.timedOut, .timedOut])
        await store.resumeFlush(with: .failed)
        for _ in 0..<1000 { if results.count > 2 { break }; try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertEqual(results, [.timedOut, .timedOut, .failed])
        let calls = await store.flushes
        XCTAssertEqual(calls, 2)
    }

}
