import AppCatalogCore
import Foundation
import XCTest
@testable import AppGridUI

/// Real store/codec with isolated memory IO. Gates suspend IO without blocking
/// an executor; every test releases its gates even when an assertion fails.
final class LayoutStoreTerminalOutcomeTests: XCTestCase {
    private let directory = URL(fileURLWithPath: "/layout-store-terminal-fixture", isDirectory: true)

    func testUntouchedFirstLaunchFlushRemainsNothingPending() async {
        let store = makeStore(io: TerminalMemoryIO())
        let loaded = await store.load()
        let first = await store.flush()
        let second = await store.flush()
        XCTAssertEqual(loaded, .firstLaunch)
        XCTAssertEqual(first, .nothingPending)
        XCTAssertEqual(second, .nothingPending)
    }

    func testAsynchronousOverLimitRejectionSurvivesEmptyFlushUntilSuccessfulRecovery() async throws {
        let io = TerminalMemoryIO()
        let store = makeStore(io: io)
        try await seed(store, io: io)
        let original = await io.journal()
        let oversized = makeOverLimitLayout()
        XCTAssertThrowsError(try LayoutStoreCodec.encode(oversized, writeGeneration: 2)) {
            XCTAssertEqual($0 as? LayoutStoreCodecError, .overLimit)
        }
        await store.enqueue(oversized)
        try await waitUntil {
            await store.currentState() == .persistenceDegraded(.rejectedOverLimit)
        }
        let first = await store.flush()
        let second = await store.flush()
        let rejectedJournal = await io.journal()
        XCTAssertEqual(first, .rejectedOverLimit)
        XCTAssertEqual(second, .rejectedOverLimit)
        XCTAssertEqual(rejectedJournal, original)

        // Acceptance and failed IO must not themselves clear the rejection or LKG.
        await io.failNextWrites(2)
        await store.enqueue(makeLayout(3))
        try await waitForFailure(store)
        let failed = await store.flush()
        let failedJournal = await io.journal()
        XCTAssertEqual(failed, .failed)
        XCTAssertEqual(failedJournal, original)
        let recovered = await store.flush()
        XCTAssertEqual(recovered, .persisted(writeGeneration: 2))
        let empty = await store.flush()
        let state = await store.currentState()
        XCTAssertEqual(empty, .nothingPending)
        XCTAssertEqual(state, .healthy)
        try await assertLatest(io, layout: makeLayout(3), writeGeneration: 2)
    }

    func testAsynchronousStaleRejectionSurvivesEmptyFlushUntilNewerLayoutPersists() async throws {
        let io = TerminalMemoryIO()
        let disk = makeLayout(5)
        let bytes = try LayoutStoreCodec.encode(disk, writeGeneration: 7)
        await io.put(bytes, named: "workspace-layout-v1-a.json")
        let store = makeStore(io: io)
        let loaded = await store.load()
        let mode = await store.lockMode()
        XCTAssertEqual(loaded, .loaded(disk, writeGeneration: 7))
        XCTAssertEqual(mode, .lastWriterWins)
        await store.enqueue(makeLayout(4))
        try await waitUntil { await store.staleRejectionCount() == 1 }
        let first = await store.flush()
        let second = await store.flush()
        let journal = await io.journal()
        let attempts = await io.writeAttempts
        XCTAssertEqual(first, .staleRejected)
        XCTAssertEqual(second, .staleRejected)
        XCTAssertEqual(journal, ["workspace-layout-v1-a.json": bytes])
        XCTAssertEqual(attempts, 0)

        await store.enqueue(makeLayout(6))
        let recovered = await store.flush()
        let empty = await store.flush()
        let rejections = await store.staleRejectionCount()
        XCTAssertEqual(recovered, .nothingPending)
        XCTAssertEqual(empty, .nothingPending)
        XCTAssertEqual(rejections, 1)
        try await assertLatest(io, layout: makeLayout(6), writeGeneration: 8)
    }

    func testResetClearsRetainedRejectionAndPersistsDefault() async throws {
        let io = TerminalMemoryIO()
        let store = makeStore(io: io)
        try await seed(store, io: io)
        await store.enqueue(makeOverLimitLayout())
        try await waitUntil {
            await store.currentState() == .persistenceDegraded(.rejectedOverLimit)
        }
        let rejected = await store.flush()
        XCTAssertEqual(rejected, .rejectedOverLimit)
        let reset = await store.reset(defaultLayout: makeLayout(0))
        let empty = await store.flush()
        let state = await store.currentState()
        let archives = await io.archiveCount
        XCTAssertEqual(reset, .reset(writeGeneration: 2))
        XCTAssertEqual(empty, .nothingPending)
        XCTAssertEqual(state, .healthy)
        XCTAssertEqual(archives, 1)
        try await assertLatest(io, layout: makeLayout(0), writeGeneration: 2)
    }

    func testExhaustedRetriesUseOneFinalAttemptAndPreservePendingOnFailure() async throws {
        let io = TerminalMemoryIO()
        let store = makeStore(io: io, retries: [0, 0])
        try await seed(store, io: io)
        let original = await io.journal()
        await io.failNextWrites(4) // Three background attempts, then one final attempt.
        await store.enqueue(makeLayout(2))
        try await waitForFailure(store, retryCount: 2)
        let backgroundAttempts = await io.writeAttempts
        XCTAssertEqual(backgroundAttempts, 4) // Includes seed.
        let failed = await store.flush()
        let finalAttempts = await io.writeAttempts
        let journal = await io.journal()
        XCTAssertEqual(failed, .failed)
        XCTAssertEqual(finalAttempts, 5)
        XCTAssertEqual(journal, original)
        let recovered = await store.flush()
        XCTAssertEqual(recovered, .persisted(writeGeneration: 2))
        try await assertLatest(io, layout: makeLayout(2), writeGeneration: 2)
        let slots = await io.journal()
        XCTAssertEqual(slots.count, 2)
        XCTAssertEqual(slots["workspace-layout-v1-a.json"], original["workspace-layout-v1-a.json"])
    }

    func testConcurrentFlushesShareSuspendedFinalFailureWithoutParallelWrites() async throws {
        let io = TerminalMemoryIO()
        let store = makeStore(io: io, retries: [0, 0], timeout: 0.5)
        try await seedAndFail(store, io: io, retryCount: 2)
        let original = await io.journal()
        let gate = TerminalIOGate()
        defer { Task { await gate.open() } }
        await io.failNextWrites(1)
        await io.suspendNext(.write, gate: gate)
        let first = observeFlush(store)
        try await waitUntil { await gate.arrivals == 1 }
        let second = observeFlush(store)
        try await waitUntil { await second.started }
        try await Task.sleep(nanoseconds: 10_000_000)
        let attemptsWhileSuspended = await io.writeAttempts
        let active = await io.activeJournalWrites
        XCTAssertEqual(attemptsWhileSuspended, 5)
        XCTAssertEqual(active, 1)
        await gate.open()
        let firstResult = try await flushResult(first)
        let secondResult = try await flushResult(second)
        let attempts = await io.writeAttempts
        let maxActive = await io.maximumActiveJournalWrites
        let journal = await io.journal()
        XCTAssertEqual(firstResult, .failed)
        XCTAssertEqual(secondResult, .failed)
        XCTAssertEqual(attempts, 5)
        XCTAssertEqual(maxActive, 1)
        XCTAssertEqual(journal, original)
        let recovered = await store.flush()
        XCTAssertEqual(recovered, .persisted(writeGeneration: 2))
    }

    func testFinalFlushTimeoutRetainsWriterLKGAndAutomaticallyDrainsLatestSuccessor() async throws {
        try await assertTimeoutAndSuccessor(finalWriteFails: false)
    }

    func testLateFinalFailureDoesNotDiscardNewerPendingLayout() async throws {
        try await assertTimeoutAndSuccessor(finalWriteFails: true)
    }

    func testIdenticalEnqueueDuringTimedOutFinalAttemptStillCoalesces() async throws {
        let io = TerminalMemoryIO()
        let store = makeStore(io: io, timeout: 0.03)
        try await seedAndFail(store, io: io)
        let gate = TerminalIOGate()
        defer { Task { await gate.open() } }
        await io.suspendNext(.write, gate: gate)
        let observation = observeFlush(store)
        try await waitUntil { await gate.arrivals == 1 }
        let result = try await flushResult(observation)
        XCTAssertEqual(result, .timedOut)
        await store.enqueue(makeLayout(2))
        await gate.open()
        try await waitUntil { await store.currentState() == .healthy }
        let resumed = await store.flush()
        let attempts = await io.writeAttempts
        let staleCount = await store.staleRejectionCount()
        XCTAssertEqual(resumed, .nothingPending)
        XCTAssertEqual(attempts, 3)
        XCTAssertEqual(staleCount, 0)
        try await assertLatest(io, layout: makeLayout(2), writeGeneration: 2)
    }

    func testFinalAttemptDeadlineCoversSlotReadReplaceAndDirectorySync() async throws {
        for operation in [TerminalMemoryIO.Operation.read, .replace, .sync] {
            let io = TerminalMemoryIO()
            let store = makeStore(io: io, timeout: 0.03)
            try await seedAndFail(store, io: io)
            let original = await io.journal()
            let gate = TerminalIOGate()
            defer { Task { await gate.open() } }
            await io.suspendNext(operation, gate: gate)
            let observation = observeFlush(store)
            try await waitUntil { await gate.arrivals == 1 }
            let result = try await flushResult(observation)
            XCTAssertEqual(result, .timedOut, "Suspended operation: \(operation)")
            let duringTimeout = await io.journal()
            // A sync stall may already have replaced B; A must remain intact.
            XCTAssertEqual(duringTimeout["workspace-layout-v1-a.json"],
                           original["workspace-layout-v1-a.json"])
            await gate.open()
            try await waitUntil { await store.currentState() == .healthy }
            let resumed = await store.flush()
            XCTAssertEqual(resumed, .nothingPending)
            try await assertLatest(io, layout: makeLayout(2), writeGeneration: 2)
            let maxActive = await io.maximumActiveJournalWrites
            XCTAssertEqual(maxActive, 1)
        }
    }

    func testFutureVersionProtectionSurvivesFlushAndEnqueueWithoutWrites() async throws {
        let io = TerminalMemoryIO()
        let encoded = try LayoutStoreCodec.encode(makeLayout(1), writeGeneration: 1)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json["schemaVersion"] = 99
        let bytes = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        await io.put(bytes, named: "workspace-layout-v1-a.json")
        let store = makeStore(io: io)
        let loaded = await store.load()
        await store.enqueue(makeLayout(2))
        let first = await store.flush()
        let second = await store.flush()
        let journal = await io.journal()
        let attempts = await io.writeAttempts
        XCTAssertEqual(loaded, .readOnlyProtection(.unknownFutureVersion(99)))
        XCTAssertEqual(first, .readOnly)
        XCTAssertEqual(second, .readOnly)
        XCTAssertEqual(journal, ["workspace-layout-v1-a.json": bytes])
        XCTAssertEqual(attempts, 0)
    }

    func testByteOversizedEncodingPreservesPreviouslyAcceptedJournal() async throws {
        let io = TerminalMemoryIO()
        let store = makeStore(io: io)
        try await seed(store, io: io)
        let original = await io.journal()
        let layout = PersistentWorkspaceLayout(generation: .init(2),
            topLevelOrder: [.app(.canonicalPath("/Synthetic/" + String(repeating: "x", count: LayoutStoreCodec.maxFileBytes)))], folders: [])
        await store.enqueue(layout)
        let result = await store.flush()
        XCTAssertEqual(result, .rejectedOverLimit)
        let after = await io.journal()
        XCTAssertEqual(after, original)
    }

    func testFutureChangedShapeProtectsEitherSlotEvenWithValidV1Peer() async throws {
        let future = Data("{\"schemaVersion\":99,\"replacementPayload\":true}".utf8)
        let valid = try LayoutStoreCodec.encode(makeLayout(1), writeGeneration: 1)
        for futureSlot in ["workspace-layout-v1-a.json", "workspace-layout-v1-b.json"] {
            for withPeer in [false, true] {
                let io = TerminalMemoryIO()
                await io.put(future, named: futureSlot)
                if withPeer {
                    await io.put(valid, named: futureSlot.contains("-a.") ? "workspace-layout-v1-b.json" : "workspace-layout-v1-a.json")
                }
                let original = await io.journal()
                let store = makeStore(io: io)
                let result = await store.load()
                XCTAssertEqual(result, .readOnlyProtection(.unknownFutureVersion(99)))
                await store.enqueue(makeLayout(2))
                let flushed = await store.flush()
                XCTAssertEqual(flushed, .readOnly)
                let after = await io.journal()
                XCTAssertEqual(after, original)
                let attempts = await io.writeAttempts
                XCTAssertEqual(attempts, 0)
            }
        }
    }

    private func assertTimeoutAndSuccessor(finalWriteFails: Bool) async throws {
        let io = TerminalMemoryIO()
        let store = makeStore(io: io, retries: [0, 0], timeout: 0.03)
        try await seedAndFail(store, io: io, retryCount: 2)
        let original = await io.journal()
        let gate = TerminalIOGate()
        defer { Task { await gate.open() } }
        if finalWriteFails { await io.failNextWrites(1) }
        await io.suspendNext(.write, gate: gate)
        let observation = observeFlush(store)
        try await waitUntil { await gate.arrivals == 1 }
        let result = try await flushResult(observation)
        XCTAssertEqual(result, .timedOut) // Returned while the IO gate remains closed.
        let stalledJournal = await io.journal()
        let stalledState = await store.currentState()
        XCTAssertEqual(stalledJournal, original)
        XCTAssertEqual(stalledState, .persistenceDegraded(.writeFailed(retryCount: 2)))

        await store.enqueue(makeLayout(3))
        await store.enqueue(makeLayout(4))
        let secondResult = try await flushResult(observeFlush(store))
        let attemptsBeforeRelease = await io.writeAttempts
        let maxBeforeRelease = await io.maximumActiveJournalWrites
        XCTAssertEqual(secondResult, .timedOut)
        XCTAssertEqual(attemptsBeforeRelease, 5)
        XCTAssertEqual(maxBeforeRelease, 1)

        await gate.open()
        // No flush/enqueue triggers recovery: the retained writer must resume and
        // consume the latest successor itself, exactly once.
        try await waitUntil { await io.latestLayoutGeneration() == 4 }
        if finalWriteFails {
            // The fake IO marker precedes sync/store bookkeeping. In this degraded
            // branch, healthy is published only after the successor's autonomous drain.
            try await waitUntil { await store.currentState() == .healthy }
        }
        let resumed = await store.flush()
        let state = await store.currentState()
        let attemptsAfterRelease = await io.writeAttempts
        let generations = await io.completedLayoutGenerations
        let maxActive = await io.maximumActiveJournalWrites
        // The fake journal marker precedes fsync and actor bookkeeping. Depending
        // on scheduling, flush observes a completed writer or joins its final
        // successful receipt. Both must certify exactly the latest generation;
        // a failed/timed-out/stale receipt is still rejected. The generation-4
        // marker above proves the successor progressed without this flush.
        switch resumed {
        case .nothingPending: break
        case .persisted(let generation):
            XCTAssertEqual(generation, finalWriteFails ? 2 : 3)
        default: XCTFail("Autonomous successor did not reach a successful flush outcome")
        }
        XCTAssertEqual(state, .healthy)
        XCTAssertEqual(attemptsAfterRelease, 6)
        XCTAssertEqual(generations, finalWriteFails ? [1, 4] : [1, 2, 4])
        XCTAssertEqual(maxActive, 1)
        try await assertLatest(io, layout: makeLayout(4),
                               writeGeneration: finalWriteFails ? 2 : 3)
    }

    private func makeStore(io: TerminalMemoryIO, retries: [TimeInterval] = [],
                           timeout: TimeInterval = 0.5) -> LayoutStoreActor {
        LayoutStoreActor(storeDirectory: directory, io: io,
                         retrySchedule: retries, flushTimeout: timeout)
    }

    private func makeLayout(_ generation: UInt64) -> PersistentWorkspaceLayout {
        PersistentWorkspaceLayout(generation: LayoutGeneration(generation),
                                  topLevelOrder: [.app(.bundleID("fixture.alpha"))], folders: [])
    }

    private func makeOverLimitLayout() -> PersistentWorkspaceLayout {
        let entries: [WorkspaceTopLevelEntry] = (0...LayoutStoreCodec.maxAppReferences).map {
            .app(.bundleID("fixture.item.\($0)"))
        }
        return PersistentWorkspaceLayout(generation: LayoutGeneration(2),
                                         topLevelOrder: entries, folders: [])
    }

    private func seed(_ store: LayoutStoreActor, io: TerminalMemoryIO) async throws {
        _ = await store.load()
        await store.enqueue(makeLayout(1))
        let result = await store.flush()
        XCTAssertEqual(result, .nothingPending)
        try await assertLatest(io, layout: makeLayout(1), writeGeneration: 1)
    }

    private func seedAndFail(_ store: LayoutStoreActor, io: TerminalMemoryIO,
                             retryCount: Int = 0) async throws {
        try await seed(store, io: io)
        await io.failNextWrites(retryCount + 1)
        await store.enqueue(makeLayout(2))
        try await waitForFailure(store, retryCount: retryCount)
    }

    private func waitForFailure(_ store: LayoutStoreActor, retryCount: Int = 0) async throws {
        try await waitUntil {
            await store.currentState() == .persistenceDegraded(.writeFailed(retryCount: retryCount))
        }
    }

    private func assertLatest(_ io: TerminalMemoryIO, layout: PersistentWorkspaceLayout,
                              writeGeneration: UInt64,
                              file: StaticString = #filePath, line: UInt = #line) async throws {
        let journal = await io.journal()
        let decoded = journal.values.compactMap { data -> DecodedLayout? in
            if case .valid(let result) = LayoutStoreCodec.decode(data) { return result }
            return nil
        }.max { $0.writeGeneration < $1.writeGeneration }
        XCTAssertEqual(decoded, DecodedLayout(layout: layout, writeGeneration: writeGeneration),
                       file: file, line: line)
    }

    private func observeFlush(_ store: LayoutStoreActor) -> TerminalFlushProbe {
        let probe = TerminalFlushProbe()
        Task {
            await probe.markStarted()
            let result = await store.flush()
            await probe.record(result)
        }
        return probe
    }

    private func flushResult(_ probe: TerminalFlushProbe,
                             file: StaticString = #filePath, line: UInt = #line) async throws -> LayoutStoreFlushResult {
        try await waitUntil(file: file, line: line) { await probe.result != nil }
        let result = await probe.result
        return try XCTUnwrap(result, file: file, line: line)
    }

    private enum WaitError: Error { case deadlineExceeded }

    private func waitUntil(file: StaticString = #filePath, line: UInt = #line,
                           _ predicate: () async -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        while !(await predicate()) {
            guard clock.now < deadline else {
                XCTFail("Timed out waiting for test observation", file: file, line: line)
                throw WaitError.deadlineExceeded
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
    }
}

private actor TerminalFlushProbe {
    private(set) var started = false
    private(set) var result: LayoutStoreFlushResult?
    func markStarted() { started = true }
    func record(_ result: LayoutStoreFlushResult) { self.result = result }
}

private actor TerminalIOGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var arrivals = 0

    func wait() async {
        arrivals += 1
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters = []
        for waiter in pending { waiter.resume() }
    }
}

private actor TerminalMemoryIO: LayoutStoreIO {
    enum Operation: Equatable { case read, write, replace, sync }
    private var files: [String: Data] = [:]
    private var failuresRemaining = 0
    private var nextGate: (operation: Operation, gate: TerminalIOGate)?
    private var replacedGeneration: UInt64?
    private(set) var writeAttempts = 0
    private(set) var activeJournalWrites = 0
    private(set) var maximumActiveJournalWrites = 0
    private(set) var completedLayoutGenerations: [UInt64] = []
    var archiveCount: Int { files.keys.filter { $0.contains(".reset-") }.count }

    func failNextWrites(_ count: Int) { failuresRemaining = count }
    func suspendNext(_ operation: Operation, gate: TerminalIOGate) { nextGate = (operation, gate) }
    func put(_ data: Data, named name: String) { files[name] = data }
    func journal() -> [String: Data] {
        files.filter { $0.key == "workspace-layout-v1-a.json" || $0.key == "workspace-layout-v1-b.json" }
    }
    func latestLayoutGeneration() -> UInt64? {
        journal().values.compactMap { data -> DecodedLayout? in
            if case .valid(let decoded) = LayoutStoreCodec.decode(data) { return decoded }
            return nil
        }.max { $0.writeGeneration < $1.writeGeneration }?.layout.generation.value
    }

    private func waitIfGated(_ operation: Operation) async {
        guard let nextGate, nextGate.operation == operation else { return }
        self.nextGate = nil
        await nextGate.gate.wait()
    }

    func createDirectoryIfNeeded(at url: URL) async throws {}
    func acquireLock(at url: URL) async throws -> LayoutStoreLock? { nil }
    func fileExists(at url: URL) async -> Bool { files[url.lastPathComponent] != nil }
    func contentsOfDirectory(at url: URL) async -> [URL] {
        files.keys.map { url.appendingPathComponent($0) }
    }
    func readFile(at url: URL) async -> Data? {
        await waitIfGated(.read)
        return files[url.lastPathComponent]
    }
    func writeFile(_ data: Data, to url: URL) async throws {
        writeAttempts += 1
        activeJournalWrites += 1
        maximumActiveJournalWrites = max(maximumActiveJournalWrites, activeJournalWrites)
        let fails = failuresRemaining > 0
        if fails { failuresRemaining -= 1 }
        await waitIfGated(.write)
        if fails {
            activeJournalWrites -= 1
            throw LayoutStoreIOError.writeFailed
        }
        files[url.lastPathComponent] = data
    }
    func replaceFile(at source: URL, with destination: URL) async throws {
        await waitIfGated(.replace)
        guard let data = files.removeValue(forKey: source.lastPathComponent) else {
            activeJournalWrites -= 1
            throw LayoutStoreIOError.writeFailed
        }
        files[destination.lastPathComponent] = data
        if case .valid(let decoded) = LayoutStoreCodec.decode(data) {
            replacedGeneration = decoded.layout.generation.value
        }
    }
    func fsyncDirectory(at url: URL) async {
        await waitIfGated(.sync)
        if let replacedGeneration { completedLayoutGenerations.append(replacedGeneration) }
        replacedGeneration = nil
        activeJournalWrites -= 1
    }
    func removeFileIfExists(at url: URL) async { files.removeValue(forKey: url.lastPathComponent) }
    func moveFile(from source: URL, to destination: URL) async throws {
        guard let data = files.removeValue(forKey: source.lastPathComponent) else {
            throw LayoutStoreIOError.writeFailed
        }
        files[destination.lastPathComponent] = data
    }
}
