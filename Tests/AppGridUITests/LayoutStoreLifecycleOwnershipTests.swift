import AppCatalogCore
import Foundation
import XCTest
@testable import AppGridUI

/// Continuation gates observe real actor admissions, not guessed task order.
/// All data and filesystem operations stay in this test's memory-only IO.
final class LayoutStoreLifecycleOwnershipTests: XCTestCase {
    func testConcurrentFirstCallersShareInitializationBeforeEnqueue() async throws {
        let io = LifecycleMemoryIO()
        defer { Task { await io.releaseAll() } }
        let gate = await io.gate(.create)
        let store = makeStore(io)
        let first = Task { await store.load() }
        try await until { await gate.arrivals > 0 }
        let second = Task { await store.load() }
        let enqueue = Task { await store.enqueue(self.layout(1)) }
        try await until { await store.lifecycleObservation.initializingCalls == 3 }
        let calls = await io.directoryCreations
        XCTAssertEqual(calls, 1)
        await gate.open()
        let a = await first.value
        let b = await second.value
        await enqueue.value
        XCTAssertEqual(a, .firstLaunch)
        XCTAssertEqual(b, a)
        try await settled(store, io, layoutGeneration: 1)
        let locks = await io.lockAcquisitions
        let finalCalls = await io.directoryCreations
        XCTAssertEqual(locks, 1)
        XCTAssertEqual(finalCalls, 1)
    }

    func testResetWaitsForOwnedWriteReplaceAndSyncBeforeArchiveAndSuccessor() async throws {
        for operation in [LifecycleMemoryIO.Operation.write, .replace, .sync] {
            let io = LifecycleMemoryIO()
            defer { Task { await io.releaseAll() } }
            let store = makeStore(io)
            try await seed(store, io)
            let gate = await io.gate(operation)
            await store.enqueue(layout(2))
            try await until { await gate.arrivals > 0 }
            let reset = Task { await store.reset(defaultLayout: self.layout(0)) }
            try await until { await store.lifecycleObservation.resetRevision == 1 }
            await store.enqueue(layout(3))
            await store.enqueue(layout(4))
            let flushed = await store.flush()
            let moves = await io.moves
            let maxActive = await io.maximumActiveWrites
            let cleanupDuringWrite = await io.cleanupDuringWrite
            XCTAssertEqual(flushed, .timedOut)
            XCTAssertEqual(moves, 0, "Archive raced \(operation)")
            XCTAssertEqual(maxActive, 1)
            XCTAssertFalse(cleanupDuringWrite)
            await gate.open()
            let receipt = await reset.value
            XCTAssertEqual(receipt, .reset(writeGeneration: 3))
            // Observe autonomous progress before invoking another store method.
            try await until { await io.completed.last?.layout.generation.value == 4 }
            try await settled(store, io, layoutGeneration: 4)
            let completed = await io.completed
            XCTAssertEqual(completed.map { $0.layout.generation.value }, [1, 2, 0, 4])
            XCTAssertEqual(completed.map(\.writeGeneration), [1, 2, 3, 4])
            let finalMax = await io.maximumActiveWrites
            let finalCleanup = await io.cleanupDuringWrite
            XCTAssertEqual(finalMax, 1)
            XCTAssertFalse(finalCleanup)
        }
    }

    func testArchiveSuspensionRetainsOnlyLatestPostResetSuccessor() async throws {
        let io = LifecycleMemoryIO()
        defer { Task { await io.releaseAll() } }
        let store = makeStore(io)
        try await seed(store, io)
        let gate = await io.gate(.move)
        let reset = Task { await store.reset(defaultLayout: self.layout(0)) }
        try await until { await gate.arrivals > 0 }
        await store.enqueue(layout(2))
        await store.enqueue(layout(3))
        let attempts = await io.writeAttempts
        XCTAssertEqual(attempts, 1)
        await gate.open()
        let result = await reset.value
        XCTAssertEqual(result, .reset(writeGeneration: 2))
        try await until { await io.completed.last?.layout.generation.value == 3 }
        try await settled(store, io, layoutGeneration: 3)
        let completed = await io.completed
        XCTAssertEqual(completed.map { $0.layout.generation.value }, [1, 0, 3])
        XCTAssertEqual(completed.map(\.writeGeneration), [1, 2, 3])
    }

    func testConcurrentResetsKeepOwnReceiptsAndDistinctArchivesInAdmissionOrder() async throws {
        let io = LifecycleMemoryIO()
        defer { Task { await io.releaseAll() } }
        let store = makeStore(io)
        try await seed(store, io)
        let gate = await io.gate(.write)
        let first = Task { await store.reset(defaultLayout: self.layout(0)) }
        try await until { await gate.arrivals > 0 }
        await store.enqueue(layout(5)) // Intentionally superseded by the second reset.
        let second = Task { await store.reset(defaultLayout: self.layout(10)) }
        try await until { await store.lifecycleObservation.resetRevision == 2 }
        await store.enqueue(layout(11))
        let maxActive = await io.maximumActiveWrites
        XCTAssertEqual(maxActive, 1)
        await gate.open()
        let firstResult = await first.value
        let secondResult = await second.value
        XCTAssertEqual(firstResult, .reset(writeGeneration: 2))
        XCTAssertEqual(secondResult, .reset(writeGeneration: 3))
        try await until { await io.completed.last?.layout.generation.value == 11 }
        try await settled(store, io, layoutGeneration: 11)
        let completed = await io.completed
        let archives = await io.archives()
        XCTAssertEqual(completed.map { $0.layout.generation.value }, [1, 0, 10, 11])
        XCTAssertEqual(completed.map(\.writeGeneration), [1, 2, 3, 4])
        XCTAssertEqual(archives.count, 2)
        XCTAssertEqual(archives.values.compactMap(decode).map(\.writeGeneration).sorted(), [1, 2])
        let collisions = await io.archiveCollisions
        XCTAssertEqual(collisions, 0)
    }

    func testFlushTimeoutAndCancellationNeverCancelResetOrCertifyItsSuccessor() async throws {
        let io = LifecycleMemoryIO()
        defer { Task { await io.releaseAll() } }
        let store = makeStore(io)
        try await seed(store, io)
        let gate = await io.gate(.write)
        let reset = Task { await store.reset(defaultLayout: self.layout(0)) }
        try await until { await gate.arrivals > 0 }
        await store.enqueue(layout(2))
        let cancelled = Task { await store.flush() }
        cancelled.cancel()
        let cancelledResult = await cancelled.value
        let timeout = await store.flush()
        XCTAssertEqual(cancelledResult, .timedOut)
        XCTAssertEqual(timeout, .timedOut)
        let attempts = await io.writeAttempts
        let active = await io.activeWrites
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(active, 1)
        await gate.open()
        let resetResult = await reset.value
        XCTAssertEqual(resetResult, .reset(writeGeneration: 2))
        try await until { await io.completed.last?.layout.generation.value == 2 }
        try await settled(store, io, layoutGeneration: 2)
        let completed = await io.completed
        XCTAssertEqual(completed.map(\.writeGeneration), [1, 2, 3])
    }

    func testArchiveFailureRetainsJournalAndReportsFailureUntilSuccessorSaves() async throws {
        let io = LifecycleMemoryIO()
        let store = makeStore(io)
        try await seed(store, io)
        let before = await io.journal()
        await io.failNextMove()
        let result = await store.reset(defaultLayout: layout(0))
        let flushed = await store.flush()
        let after = await io.journal()
        XCTAssertEqual(result, .failed)
        XCTAssertEqual(flushed, .failed)
        XCTAssertEqual(after, before)
        await store.enqueue(layout(2))
        try await settled(store, io, layoutGeneration: 2)
        let latest = await io.completed.last
        XCTAssertEqual(latest?.writeGeneration, 2)
    }

    func testDefaultWriteFailureKeepsArchiveAndImmutableStartupReceipt() async throws {
        let io = LifecycleMemoryIO()
        let store = makeStore(io)
        try await seed(store, io)
        let before = await io.journal()
        await io.failNextWrite()
        let result = await store.reset(defaultLayout: layout(0))
        let flushed = await store.flush()
        let startup = await store.load()
        let archives = await io.archives()
        XCTAssertEqual(result, .failed)
        XCTAssertEqual(flushed, .failed)
        XCTAssertEqual(startup, .firstLaunch)
        XCTAssertEqual(Set(archives.values), Set(before.values))
        await store.enqueue(layout(2))
        try await settled(store, io, layoutGeneration: 2)
        let latest = await io.completed.last
        XCTAssertEqual(latest?.writeGeneration, 2)
    }

    func testProtectedValidPeerHighWaterSurvivesExplicitResetInEitherSlot() async throws {
        let valid = try LayoutStoreCodec.encode(layout(8), writeGeneration: 900)
        let future = Data("{\"schemaVersion\":99,\"newPayload\":true}".utf8)
        let overLimit = Data(repeating: 32, count: LayoutStoreCodec.maxFileBytes + 1)
        for (protected, reason) in [(future, LayoutStoreReadOnlyReason.unknownFutureVersion(99)),
                                    (overLimit, .exceedsLimits)] {
            for protectedInA in [true, false] {
                let io = LifecycleMemoryIO()
                let a = protectedInA ? protected : valid
                let b = protectedInA ? valid : protected
                await io.put(a, named: "workspace-layout-v1-a.json")
                await io.put(b, named: "workspace-layout-v1-b.json")
                let store = makeStore(io)
                let startup = await store.load()
                XCTAssertEqual(startup, .readOnlyProtection(reason))
                await store.enqueue(layout(9))
                let attempts = await io.writeAttempts
                XCTAssertEqual(attempts, 0)
                let reset = await store.reset(defaultLayout: layout(0))
                let repeated = await store.load()
                let archives = await io.archives()
                XCTAssertEqual(reset, .reset(writeGeneration: 901))
                XCTAssertEqual(repeated, startup)
                XCTAssertEqual(Set(archives.values), Set([a, b]))
                await store.enqueue(layout(1))
                try await settled(store, io, layoutGeneration: 1)
                let latest = await io.completed.last
                XCTAssertEqual(latest?.writeGeneration, 902)
            }
        }
    }

    func testFailedProtectedArchiveDoesNotWriteAcceptedSuccessorOrLiftProtection() async throws {
        let io = LifecycleMemoryIO()
        defer { Task { await io.releaseAll() } }
        let future = Data("{\"schemaVersion\":99}".utf8)
        await io.put(future, named: "workspace-layout-v1-a.json")
        let store = makeStore(io)
        let startup = await store.load()
        let gate = await io.gate(.move)
        await io.failNextMove()
        let reset = Task { await store.reset(defaultLayout: self.layout(0)) }
        try await until { await gate.arrivals > 0 }
        await store.enqueue(layout(2))
        await gate.open()
        let result = await reset.value
        let flushed = await store.flush()
        let state = await store.currentState()
        let attempts = await io.writeAttempts
        let journal = await io.journal()
        XCTAssertEqual(result, .failed)
        XCTAssertEqual(flushed, .readOnly)
        XCTAssertEqual(state, .readOnlyProtection(.unknownFutureVersion(99)))
        XCTAssertEqual(attempts, 0)
        XCTAssertEqual(journal, ["workspace-layout-v1-a.json": future])
        let second = await store.reset(defaultLayout: layout(0))
        let reloaded = await store.load()
        XCTAssertEqual(second, .reset(writeGeneration: 1))
        XCTAssertEqual(reloaded, startup)
        let completed = await io.completed
        XCTAssertEqual(completed.map { $0.layout.generation.value }, [0])
    }

    func testObsoleteFlushReceiptCannotCertifyResetOrStalledSuccessor() async throws {
        let io = LifecycleMemoryIO()
        defer { Task { await io.releaseAll() } }
        let store = makeStore(io)
        try await seed(store, io)
        await io.failNextWrite()
        await store.enqueue(layout(2))
        try await until {
            await store.currentState() == .persistenceDegraded(.writeFailed(retryCount: 0))
        }
        let oldWrite = await io.gate(.write)
        await io.failNextWrite()
        let obsoleteFlush = Task { await store.flush() }
        try await until { await oldWrite.arrivals > 0 }
        let archive = await io.gate(.move)
        let reset = Task { await store.reset(defaultLayout: self.layout(0)) }
        try await until { await store.lifecycleObservation.resetRevision == 1 }
        await store.enqueue(layout(3))
        await oldWrite.open()
        try await until { await archive.arrivals > 0 }
        let obsoleteResult = await obsoleteFlush.value
        XCTAssertEqual(obsoleteResult, .timedOut) // Not the old epoch's failure receipt.
        let defaultSync = await io.gate(.sync)
        await archive.open()
        try await until { await defaultSync.arrivals > 0 }
        let successorWrite = await io.gate(.write)
        await defaultSync.open()
        let resetResult = await reset.value
        XCTAssertEqual(resetResult, .reset(writeGeneration: 2))
        try await until { await successorWrite.arrivals > 0 }
        let held = await store.flush()
        XCTAssertEqual(held, .timedOut) // Default durability is not successor durability.
        let beforeRelease = await io.completed
        XCTAssertEqual(beforeRelease.map { $0.layout.generation.value }, [1, 0])
        await successorWrite.open()
        try await until { await io.completed.last?.layout.generation.value == 3 }
        try await settled(store, io, layoutGeneration: 3)
        let completed = await io.completed
        XCTAssertEqual(completed.map(\.writeGeneration), [1, 2, 3])
    }

    func testWritableResetFailuresAutonomouslyDrainAlreadyAdmittedLatestSuccessor() async throws {
        for failDuringArchive in [true, false] {
            let io = LifecycleMemoryIO()
            defer { Task { await io.releaseAll() } }
            let store = makeStore(io)
            try await seed(store, io)
            let failureGate = await io.gate(failDuringArchive ? .move : .write)
            if failDuringArchive {
                await io.failNextMove()
            } else {
                await io.failNextWrite()
            }
            let reset = Task { await store.reset(defaultLayout: self.layout(0)) }
            try await until { await failureGate.arrivals > 0 }
            await store.enqueue(layout(2))
            await store.enqueue(layout(3))
            let successorWrite = await io.gate(.write)
            await failureGate.open()
            let resetResult = await reset.value
            XCTAssertEqual(resetResult, .failed)
            // Arrival proves recovery began without another flush/enqueue call.
            try await until { await successorWrite.arrivals > 0 }
            let state = await store.currentState()
            let completedBeforeRelease = await io.completed
            XCTAssertEqual(state, .persistenceDegraded(.writeFailed(retryCount: 0)))
            XCTAssertEqual(completedBeforeRelease.map { $0.layout.generation.value }, [1])
            await successorWrite.open()
            try await until { await io.completed.last?.layout.generation.value == 3 }
            try await settled(store, io, layoutGeneration: 3)
            let completed = await io.completed
            let maxActive = await io.maximumActiveWrites
            let archives = await io.archives()
            XCTAssertEqual(completed.map { $0.layout.generation.value }, [1, 3])
            XCTAssertEqual(completed.map(\.writeGeneration), [1, 2])
            XCTAssertEqual(maxActive, 1)
            XCTAssertEqual(archives.count, failDuringArchive ? 0 : 1)
        }
    }

    func testOldFlushWaiterCrossesResetAndRetriesCurrentEpochFailure() async throws {
        let io = LifecycleMemoryIO()
        defer { Task { await io.releaseAll() } }
        let store = LayoutStoreActor(
            storeDirectory: URL(fileURLWithPath: "/memory-only-journal-lifecycle"),
            io: io, retrySchedule: [], flushTimeout: 2)
        try await seed(store, io)
        await io.failNextWrite()
        await store.enqueue(layout(2))
        try await until {
            await store.currentState() == .persistenceDegraded(.writeFailed(retryCount: 0))
        }
        let oldWrite = await io.gate(.write)
        await io.failNextWrite()
        let oldFlush = Task { await store.flush() }
        try await until { await oldWrite.arrivals > 0 }
        let archive = await io.gate(.move)
        let reset = Task { await store.reset(defaultLayout: self.layout(0)) }
        try await until { await store.lifecycleObservation.resetRevision == 1 }
        await store.enqueue(layout(3))
        await oldWrite.open()
        try await until { await archive.arrivals > 0 }
        let defaultSync = await io.gate(.sync)
        await archive.open()
        try await until { await defaultSync.arrivals > 0 }
        let successorFailure = await io.gate(.write)
        await io.failNextWrite()
        await defaultSync.open()
        let resetResult = await reset.value
        XCTAssertEqual(resetResult, .reset(writeGeneration: 2))
        try await until { await successorFailure.arrivals > 0 }
        let currentFinal = await io.gate(.write)
        await successorFailure.open()
        // Only the original pre-reset flush can start this current-epoch final
        // attempt. A stale failure receipt would return early instead.
        try await until { await currentFinal.arrivals > 0 }
        let beforeFinal = await io.completed
        XCTAssertEqual(beforeFinal.map { $0.layout.generation.value }, [1, 0])
        await currentFinal.open()
        let result = await oldFlush.value
        XCTAssertEqual(result, .persisted(writeGeneration: 3))
        let final = await io.completed.last
        XCTAssertEqual(final?.layout, layout(3))
        XCTAssertEqual(final?.writeGeneration, 3)
        let maximum = await io.maximumActiveWrites
        XCTAssertEqual(maximum, 1)
    }

    private func makeStore(_ io: LifecycleMemoryIO) -> LayoutStoreActor {
        LayoutStoreActor(storeDirectory: URL(fileURLWithPath: "/memory-only-journal-lifecycle"),
                         io: io, retrySchedule: [], flushTimeout: 0.04)
    }
    private func layout(_ generation: UInt64) -> PersistentWorkspaceLayout {
        PersistentWorkspaceLayout(generation: .init(generation),
            topLevelOrder: [.app(.bundleID("fixture.lifecycle"))], folders: [])
    }
    private func seed(_ store: LayoutStoreActor, _ io: LifecycleMemoryIO) async throws {
        _ = await store.load()
        await store.enqueue(layout(1))
        try await settled(store, io, layoutGeneration: 1)
    }
    private func settled(_ store: LayoutStoreActor, _ io: LifecycleMemoryIO,
                         layoutGeneration: UInt64) async throws {
        try await until { await io.completed.last?.layout.generation.value == layoutGeneration }
        let result = await store.flush()
        switch result {
        case .nothingPending, .persisted: break
        default: XCTFail("Expected a successful settled journal, got \(result)")
        }
    }
    private func decode(_ bytes: Data) -> DecodedLayout? {
        if case .valid(let value) = LayoutStoreCodec.decode(bytes) { return value }
        return nil
    }
    private enum WaitFailure: Error { case deadline }
    private func until(_ condition: () async -> Bool,
                       file: StaticString = #filePath, line: UInt = #line) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(5))
        while !(await condition()) {
            guard clock.now < deadline else {
                XCTFail("Timed out waiting for explicit lifecycle observation", file: file, line: line)
                throw WaitFailure.deadline
            }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
    }
}

private actor LifecycleGate {
    private(set) var arrivals = 0
    private var opened = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        arrivals += 1
        if opened { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() {
        opened = true
        let pending = waiters
        waiters = []
        for waiter in pending { waiter.resume() }
    }
}

private actor LifecycleMemoryIO: LayoutStoreIO {
    enum Operation: Hashable { case create, read, write, replace, sync, move }
    private var files: [String: Data] = [:]
    private var gates: [Operation: LifecycleGate] = [:]
    private var failWrite = false
    private var failMove = false
    private var replaced: DecodedLayout?
    private(set) var directoryCreations = 0
    private(set) var lockAcquisitions = 0
    private(set) var writeAttempts = 0
    private(set) var activeWrites = 0
    private(set) var maximumActiveWrites = 0
    private(set) var cleanupDuringWrite = false
    private(set) var moves = 0
    private(set) var archiveCollisions = 0
    private(set) var completed: [DecodedLayout] = []
    func gate(_ operation: Operation) -> LifecycleGate {
        let gate = LifecycleGate()
        gates[operation] = gate
        return gate
    }
    func releaseAll() async { for gate in gates.values { await gate.open() } }
    func put(_ data: Data, named name: String) { files[name] = data }
    func failNextWrite() { failWrite = true }
    func failNextMove() { failMove = true }
    func journal() -> [String: Data] { files.filter { $0.key.hasSuffix(".json") } }
    func archives() -> [String: Data] { files.filter { $0.key.contains(".reset-") } }
    private func wait(_ operation: Operation) async { await gates[operation]?.wait() }
    func createDirectoryIfNeeded(at url: URL) async throws {
        directoryCreations += 1
        await wait(.create)
    }
    func acquireLock(at url: URL) async throws -> LayoutStoreLock? {
        lockAcquisitions += 1
        return nil
    }
    func fileExists(at url: URL) async -> Bool { files[url.lastPathComponent] != nil }
    func readFile(at url: URL) async -> Data? {
        await wait(.read)
        return files[url.lastPathComponent]
    }
    func contentsOfDirectory(at url: URL) async -> [URL] {
        if activeWrites > 0 { cleanupDuringWrite = true }
        return files.keys.map { url.appendingPathComponent($0) }
    }
    func removeFileIfExists(at url: URL) async {
        if activeWrites > 0 { cleanupDuringWrite = true }
        files.removeValue(forKey: url.lastPathComponent)
    }
    func writeFile(_ data: Data, to url: URL) async throws {
        writeAttempts += 1
        activeWrites += 1
        maximumActiveWrites = max(maximumActiveWrites, activeWrites)
        let fails = failWrite
        failWrite = false
        await wait(.write)
        if fails {
            activeWrites -= 1
            throw LayoutStoreIOError.writeFailed
        }
        files[url.lastPathComponent] = data
    }
    func replaceFile(at source: URL, with destination: URL) async throws {
        await wait(.replace)
        guard let data = files.removeValue(forKey: source.lastPathComponent) else {
            activeWrites -= 1
            throw LayoutStoreIOError.writeFailed
        }
        files[destination.lastPathComponent] = data
        if case .valid(let value) = LayoutStoreCodec.decode(data) { replaced = value }
    }
    func fsyncDirectory(at url: URL) async {
        await wait(.sync)
        if let replaced { completed.append(replaced) }
        replaced = nil
        activeWrites -= 1
    }
    func moveFile(from source: URL, to destination: URL) async throws {
        moves += 1
        await wait(.move)
        if failMove {
            failMove = false
            throw LayoutStoreIOError.writeFailed
        }
        guard files[destination.lastPathComponent] == nil else {
            archiveCollisions += 1
            throw LayoutStoreIOError.writeFailed
        }
        guard let data = files.removeValue(forKey: source.lastPathComponent) else {
            throw LayoutStoreIOError.writeFailed
        }
        files[destination.lastPathComponent] = data
    }
}
