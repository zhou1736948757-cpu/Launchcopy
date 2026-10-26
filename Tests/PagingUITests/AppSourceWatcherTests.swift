import CoreServices
import Dispatch
import Foundation
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class AppSourceWatcherTests: XCTestCase {
    // Synthetic command arguments only: no directory is created, read, or really watched.
    private let root = URL(fileURLWithPath: "/synthetic/Applications")

    func testRecursiveRootIntentSinceNowLatencyAndActiveStatus() async throws {
        let fixture = WatchFixture()
        defer { fixture.cleanup() }
        let nestedRoot = root.appendingPathComponent("Selected")
        let status = await fixture.replace([root, nestedRoot])
        XCTAssertEqual(status, .active)
        let command = try XCTUnwrap(fixture.backend.commands.first)
        XCTAssertEqual(command.roots, [root, nestedRoot], "Never broaden to a parent or volume")
        XCTAssertEqual(command.sinceWhen, FSEventStreamEventId(kFSEventStreamEventIdSinceNow))
        XCTAssertGreaterThanOrEqual(command.latency, 0.5)
        XCTAssertEqual(command.flags, FSEventStreamCreateFlags(kFSEventStreamCreateFlagWatchRoot),
                       "Default directory events are recursive; no FileEvents/NoDefer/IgnoreSelf")
        let stream = try XCTUnwrap(fixture.backend.streams.first)
        XCTAssertEqual(stream.actions, [.schedule, .start])
        XCTAssertEqual(stream.queueQoS, .utility)
    }

    func testEmptyAndInvalidRootsNeverAdvertiseActiveOrCreateStream() async {
        let fixture = WatchFixture()
        defer { fixture.cleanup() }
        let empty = await fixture.watcher.replaceRoots([]) { XCTFail("Disabled watcher fired") }
        let invalid = await fixture.watcher.replaceRoots([URL(string: "https://example.invalid/apps")!]) {
            XCTFail("Invalid watcher fired")
        }
        XCTAssertEqual(empty, .disabled)
        XCTAssertEqual(invalid, .unavailable)
        XCTAssertTrue(fixture.backend.commands.isEmpty)
        XCTAssertEqual(fixture.utility.pendingCount, 0)
    }

    func testMissingOrUnreadableRootIsDegradedAndManualRetryCanRecover() async throws {
        let fixture = WatchFixture()
        defer { fixture.cleanup() }
        fixture.probe.usable = false
        let degraded = await fixture.replace([root])
        XCTAssertEqual(degraded, .degraded)
        XCTAssertEqual(fixture.backend.commands.first?.roots, [root])
        var changes = 0
        // A stream at a missing admitted root remains best-effort, with no parent watch/poll.
        let stillDegraded = await fixture.replace([root]) { changes += 1 }
        XCTAssertEqual(stillDegraded, .degraded)
        try XCTUnwrap(fixture.backend.streams.last).emit()
        fixture.main.runAll()
        XCTAssertEqual(changes, 1)
        fixture.probe.usable = true
        let recovered = await fixture.replace([root])
        XCTAssertEqual(recovered, .active, "Recovery is an explicit replacement, not polling")
        XCTAssertEqual(fixture.backend.commands.map(\.roots), [[root], [root], [root]])
    }

    func testCreationAndStartFailuresAreUnavailableAndStartFailureReleasesWhileScheduled() async throws {
        for plan in [FakeWatchBackend.Plan.creationFailure, .startFailure] {
            let fixture = WatchFixture(plans: [plan])
            defer { fixture.cleanup() }
            var changes = 0
            let status = await fixture.replace([root]) { changes += 1 }
            XCTAssertEqual(status, .unavailable)
            fixture.main.runAll() // Fake start emits even when it returns failure.
            XCTAssertEqual(changes, 0)
            fixture.utility.runAllReady()
            if plan == .startFailure {
                let stream = try XCTUnwrap(fixture.backend.streams.first)
                XCTAssertEqual(stream.actions, [.schedule, .start, .invalidate, .release])
                XCTAssertFalse(stream.hasCallback)
            } else {
                XCTAssertTrue(fixture.backend.streams.isEmpty)
            }
        }
    }

    func testConcurrentCallbackStormHasOnePendingMainDeliveryAndCanRearm() async throws {
        let fixture = WatchFixture()
        defer { fixture.cleanup() }
        var changes = 0
        _ = await fixture.replace([root]) { changes += 1 }
        let callback = try XCTUnwrap(fixture.backend.streams.first?.callback)
        DispatchQueue.concurrentPerform(iterations: 10_000) { _ in callback() }
        XCTAssertEqual(fixture.main.pendingCount, 1)
        XCTAssertEqual(fixture.main.enqueueCount, 1)
        XCTAssertEqual(changes, 0)
        fixture.main.runAll()
        XCTAssertEqual(changes, 1)
        callback()
        fixture.main.runAll()
        XCTAssertEqual(changes, 2)
        XCTAssertEqual(fixture.main.enqueueCount, 2)
    }

    func testStartupStormConsumedBeforeSessionInstallationReplaysExactlyOnce() async throws {
        for usable in [true, false] {
            let fixture = WatchFixture()
            defer { fixture.cleanup() }
            fixture.probe.usable = usable
            var changes = 0
            let task = Task { await fixture.watcher.replaceRoots([root]) { changes += 1 } }
            let setup = await fixture.utility.takeNext()
            setup()
            let stream = try XCTUnwrap(fixture.backend.streams.first)
            // No await here: this MainActor turn consumes delivery before the setup
            // continuation can resume and install its successfully started session.
            for _ in 0..<10_000 { stream.emit() }
            XCTAssertEqual(fixture.main.pendingCount, 1)
            fixture.main.runAll()
            XCTAssertEqual(changes, 0)
            XCTAssertEqual(fixture.main.pendingCount, 0)
            // A second pre-install batch remains the same single retained invalidation.
            stream.emit()
            fixture.main.runAll()
            XCTAssertEqual(changes, 0)
            XCTAssertEqual(fixture.main.enqueueCount, 2)

            let status = await task.value
            XCTAssertEqual(status, usable ? .active : .degraded)
            XCTAssertEqual(changes, 1)
            fixture.main.runAll()
            XCTAssertEqual(changes, 1, "Replay must not create another Main delivery")
            XCTAssertEqual(fixture.main.enqueueCount, 2)
            stream.emit()
            fixture.main.runAll()
            XCTAssertEqual(changes, 2, "Installed events still use the ordinary mailbox")
        }
    }

    func testConsumedStartupChangeIsDiscardedOnFailureCancellationAndStop() async throws {
        enum Ending: Equatable { case failure, cancellation, stop }
        for ending in [Ending.failure, .cancellation, .stop] {
            let fixture = WatchFixture(plans: ending == .failure ? [.startFailure, .success] : [])
            defer { fixture.cleanup() }
            var changes = 0
            let task = Task { await fixture.watcher.replaceRoots([root]) { changes += 1 } }
            let setup = await fixture.utility.takeNext()
            setup()
            let stream = try XCTUnwrap(fixture.backend.streams.first)
            let lateCallback = try XCTUnwrap(stream.callback)
            stream.emit()
            fixture.main.runAll() // Consume into the startup bool, still before any await.
            XCTAssertEqual(changes, 0)
            switch ending {
            case .failure: break
            case .cancellation: task.cancel()
            case .stop: fixture.watcher.stop()
            }
            let status = await task.value
            XCTAssertEqual(status, ending == .failure ? .unavailable : .disabled)
            lateCallback()
            fixture.main.runAll()
            XCTAssertEqual(changes, 0)
            fixture.utility.runAllReady()
            XCTAssertEqual(stream.actions, ending == .failure
                ? [.schedule, .start, .invalidate, .release]
                : [.schedule, .start, .stop, .invalidate, .release])

            let restarted = await fixture.replace([root]) { changes += 1 }
            XCTAssertEqual(restarted, .active)
            XCTAssertEqual(changes, 0, "Discarded startup change must not survive a retry")
            try XCTUnwrap(fixture.backend.streams.last).emit()
            fixture.main.runAll()
            XCTAssertEqual(changes, 1)
        }
    }

    func testStopGatesPendingAndLateCallbacksImmediatelyAndQueuesIdempotentCleanup() async throws {
        let fixture = WatchFixture()
        defer { fixture.cleanup() }
        var changes = 0
        _ = await fixture.replace([root]) { changes += 1 }
        let stream = try XCTUnwrap(fixture.backend.streams.first)
        let lateCallback = try XCTUnwrap(stream.callback)
        stream.emit()
        fixture.watcher.stop()
        fixture.watcher.stop()
        XCTAssertEqual(stream.actions, [.schedule, .start], "Stop must not wait for utility cleanup")
        XCTAssertEqual(fixture.utility.pendingCount, 1)
        lateCallback()
        fixture.main.runAll()
        XCTAssertEqual(changes, 0)
        fixture.utility.runAllReady()
        XCTAssertEqual(stream.actions, [.schedule, .start, .stop, .invalidate, .release])
        XCTAssertFalse(stream.hasCallback)
        lateCallback()
        XCTAssertEqual(fixture.main.pendingCount, 0)
    }

    func testReplaceDropsOldEventsAndReusesOnePendingMainSlotAcrossGenerations() async throws {
        let fixture = WatchFixture()
        defer { fixture.cleanup() }
        var oldChanges = 0, newChanges = 0
        _ = await fixture.replace([root]) { oldChanges += 1 }
        let oldCallback = try XCTUnwrap(fixture.backend.streams.first?.callback)
        oldCallback()
        _ = await fixture.replace([root.appendingPathComponent("New")]) { newChanges += 1 }
        oldCallback()
        try XCTUnwrap(fixture.backend.streams.last).emit()
        XCTAssertEqual(fixture.main.pendingCount, 1)
        XCTAssertEqual(fixture.main.enqueueCount, 1)
        fixture.main.runAll()
        XCTAssertEqual(oldChanges, 0)
        XCTAssertEqual(newChanges, 1)
        fixture.utility.runAllReady()
        XCTAssertEqual(fixture.backend.streams.first?.actions, [.schedule, .start, .stop, .invalidate, .release])
    }

    func testFailedReplacementCannotRetainOldCoverageOrDeliverQueuedOldEvents() async throws {
        let fixture = WatchFixture(plans: [.success, .creationFailure])
        defer { fixture.cleanup() }
        var changes = 0
        _ = await fixture.replace([root]) { changes += 1 }
        let old = try XCTUnwrap(fixture.backend.streams.first)
        let callback = try XCTUnwrap(old.callback)
        callback()
        let status = await fixture.replace([root.appendingPathComponent("New")]) { changes += 1 }
        XCTAssertEqual(status, .unavailable)
        callback()
        fixture.main.runAll()
        XCTAssertEqual(changes, 0)
        fixture.utility.runAllReady()
        XCTAssertFalse(old.hasCallback)
    }

    func testStopOrTaskCancellationDuringSetupClosesCreatedStreamWithoutInstallingIt() async throws {
        for cancelTask in [false, true] {
            let fixture = WatchFixture()
            defer { fixture.cleanup() }
            var changes = 0
            let task = Task { await fixture.watcher.replaceRoots([root]) { changes += 1 } }
            let setup = await fixture.utility.takeNext()
            if cancelTask { task.cancel() } else { fixture.watcher.stop() }
            setup()
            let status = await task.value
            XCTAssertEqual(status, .disabled)
            let stream = try XCTUnwrap(fixture.backend.streams.first)
            stream.emit()
            fixture.main.runAll()
            XCTAssertEqual(changes, 0)
            fixture.utility.runAllReady()
            XCTAssertEqual(stream.actions, [.schedule, .start, .stop, .invalidate, .release])
        }
    }

    func testReplacementDuringPendingSetupGatesOldSuccessAndFailureAfterAwait() async throws {
        for oldPlan in [FakeWatchBackend.Plan.success, .creationFailure, .startFailure] {
            let fixture = WatchFixture(plans: [oldPlan, .success])
            defer { fixture.cleanup() }
            var oldChanges = 0, newChanges = 0
            let oldTask = Task { await fixture.watcher.replaceRoots([root]) { oldChanges += 1 } }
            let oldSetup = await fixture.utility.takeNext()
            let newTask = Task {
                await fixture.watcher.replaceRoots([root.appendingPathComponent("New")]) { newChanges += 1 }
            }
            let newSetup = await fixture.utility.takeNext() // New generation is now established.
            oldSetup()
            newSetup()
            // Both continuations are queued, but neither can install a session until this
            // MainActor turn suspends. Old success/failure must preserve new startup dirt.
            for stream in fixture.backend.streams { stream.emit() }
            fixture.main.runAll()
            XCTAssertEqual(oldChanges, 0)
            XCTAssertEqual(newChanges, 0)
            let oldStatus = await oldTask.value
            XCTAssertEqual(oldStatus, .disabled)
            let newStatus = await newTask.value
            XCTAssertEqual(newStatus, .active)
            XCTAssertEqual(oldChanges, 0)
            XCTAssertEqual(newChanges, 1, "Stale setup must not discard the new startup replay")
            fixture.utility.runAllReady()
            try XCTUnwrap(fixture.backend.streams.last).emit()
            fixture.main.runAll()
            XCTAssertEqual(oldChanges, 0)
            XCTAssertEqual(newChanges, 2, "Stale failure must not invalidate the new gate")
        }
    }

    func testDeinitReleasesResourcesAndQueuedDeliveryDoesNotRetainWatcher() async throws {
        let backend = FakeWatchBackend()
        let utility = ManualWatchUtility()
        let main = ManualWatchMain()
        var watcher: FSEventsAppSourceWatcher? = FSEventsAppSourceWatcher(
            backend: backend, enqueueMain: { main.enqueue($0) }, rootIsUsable: { _ in true }, utility: utility
        )
        var changes = 0
        _ = await completeReplacement(try XCTUnwrap(watcher), roots: [root], backend: backend, utility: utility) {
            changes += 1
        }
        let stream = try XCTUnwrap(backend.streams.first)
        stream.emit()
        weak var weakWatcher = watcher
        watcher = nil
        XCTAssertNil(weakWatcher)
        main.runAll()
        XCTAssertEqual(changes, 0)
        utility.runAllReady()
        XCTAssertEqual(stream.actions, [.schedule, .start, .stop, .invalidate, .release])
        XCTAssertFalse(stream.hasCallback)
    }

    func testProductionUtilitySchedulerKeepsInjectedProbeAndNativeLifecycleOffMain() async throws {
        let backend = FakeWatchBackend()
        let probe = FakeWatchProbe()
        let main = ManualWatchMain()
        let utility = AppSourceWatchUtilityExecutor()
        let watcher = FSEventsAppSourceWatcher(
            backend: backend, enqueueMain: { main.enqueue($0) }, rootIsUsable: { probe.check($0) }, utility: utility
        )
        let status = await watcher.replaceRoots([root]) {}
        XCTAssertEqual(status, .active)
        watcher.stop()
        // An async queue barrier observes cleanup without a semaphore, sleep or real IO.
        await utility.perform {}
        XCTAssertFalse(probe.wasCalledOnMain)
        XCTAssertFalse(backend.wasCreatedOnMain)
        let stream = try XCTUnwrap(backend.streams.first)
        XCTAssertFalse(stream.wasCalledOnMain)
        XCTAssertEqual(stream.actions, [.schedule, .start, .stop, .invalidate, .release])
    }
}

@MainActor
private func completeReplacement(
    _ watcher: FSEventsAppSourceWatcher, roots: [URL], backend: FakeWatchBackend,
    utility: ManualWatchUtility, onChange: @escaping @MainActor () -> Void
) async -> AppSourceWatchStatus {
    let previousCount = backend.commands.count
    let task = Task { await watcher.replaceRoots(roots, onChange: onChange) }
    // Replacing a live stream queues old cleanup before new setup.
    while backend.commands.count == previousCount { (await utility.takeNext())() }
    return await task.value
}

@MainActor
private final class WatchFixture {
    let backend: FakeWatchBackend
    let utility: ManualWatchUtility
    let main: ManualWatchMain
    let probe: FakeWatchProbe
    let watcher: FSEventsAppSourceWatcher

    init(plans: [FakeWatchBackend.Plan] = []) {
        let backend = FakeWatchBackend(plans: plans)
        let utility = ManualWatchUtility()
        let main = ManualWatchMain()
        let probe = FakeWatchProbe()
        self.backend = backend
        self.utility = utility
        self.main = main
        self.probe = probe
        watcher = FSEventsAppSourceWatcher(
            backend: backend, enqueueMain: { main.enqueue($0) }, rootIsUsable: { probe.check($0) }, utility: utility
        )
    }

    func replace(_ roots: [URL], onChange: @escaping @MainActor () -> Void = {}) async -> AppSourceWatchStatus {
        await completeReplacement(watcher, roots: roots, backend: backend, utility: utility, onChange: onChange)
    }

    func cleanup() {
        watcher.stop()
        utility.runAllReady()
        main.runAll()
    }
}

private extension NSLock {
    func watchTestLocked<Value>(_ body: () -> Value) -> Value {
        lock()
        defer { unlock() }
        return body()
    }
}

private final class FakeWatchBackend: AppSourceWatchStreamBackend, @unchecked Sendable {
    enum Plan: Equatable { case success, creationFailure, startFailure }
    private let lock = NSLock()
    private var plans: [Plan]
    private var recordedCommands: [AppSourceWatchStreamConfiguration] = []
    private var createdStreams: [FakeWatchStream] = []
    private var createdOnMain = false
    var commands: [AppSourceWatchStreamConfiguration] { lock.watchTestLocked { recordedCommands } }
    var streams: [FakeWatchStream] { lock.watchTestLocked { createdStreams } }
    var wasCreatedOnMain: Bool { lock.watchTestLocked { createdOnMain } }

    init(plans: [Plan] = []) { self.plans = plans }

    func makeStream(configuration: AppSourceWatchStreamConfiguration,
                    onChange: @escaping @Sendable () -> Void) -> AppSourceWatchStream? {
        lock.watchTestLocked {
            recordedCommands.append(configuration)
            createdOnMain = createdOnMain || Thread.isMainThread
            let plan = plans.isEmpty ? .success : plans.removeFirst()
            guard plan != .creationFailure else { return nil }
            let stream = FakeWatchStream(startSucceeds: plan != .startFailure, callback: onChange)
            createdStreams.append(stream)
            return stream
        }
    }
}

private final class FakeWatchStream: AppSourceWatchStream, @unchecked Sendable {
    enum Action: Equatable { case schedule, start, stop, invalidate, release }
    private let lock = NSLock()
    private let startSucceeds: Bool
    private var handler: (@Sendable () -> Void)?
    private var recordedActions: [Action] = []
    private var qos: DispatchQoS.QoSClass?
    private var calledOnMain = false
    var actions: [Action] { lock.watchTestLocked { recordedActions } }
    var callback: (@Sendable () -> Void)? { lock.watchTestLocked { handler } }
    var hasCallback: Bool { callback != nil }
    var queueQoS: DispatchQoS.QoSClass? { lock.watchTestLocked { qos } }
    var wasCalledOnMain: Bool { lock.watchTestLocked { calledOnMain } }

    init(startSucceeds: Bool, callback: @escaping @Sendable () -> Void) {
        self.startSucceeds = startSucceeds
        self.handler = callback
    }

    private func record(_ action: Action) {
        lock.watchTestLocked {
            recordedActions.append(action)
            calledOnMain = calledOnMain || Thread.isMainThread
        }
    }

    func schedule(on queue: DispatchQueue) {
        lock.watchTestLocked { qos = queue.qos.qosClass }
        record(.schedule)
    }
    func start() -> Bool {
        record(.start)
        if !startSucceeds { emit() }
        return startSucceeds
    }
    func stop() { record(.stop) }
    func invalidate() { record(.invalidate) }
    func release() {
        record(.release)
        lock.watchTestLocked { handler = nil }
    }
    func emit() { callback?() }
}

private final class FakeWatchProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var isUsable = true
    private var calledOnMain = false
    var usable: Bool {
        get { lock.watchTestLocked { isUsable } }
        set { lock.watchTestLocked { isUsable = newValue } }
    }
    var wasCalledOnMain: Bool { lock.watchTestLocked { calledOnMain } }
    func check(_ root: URL) -> Bool {
        lock.watchTestLocked {
            calledOnMain = calledOnMain || Thread.isMainThread
            return isUsable
        }
    }
}

private final class ManualWatchUtility: AppSourceWatchUtilityScheduling, @unchecked Sendable {
    typealias Operation = @Sendable () -> Void
    let queue = DispatchQueue(label: "PagingPrototype.Tests.AppSourceWatcher", qos: .utility)
    private let lock = NSLock()
    private var operations: [Operation] = []
    private var waiter: CheckedContinuation<Operation, Never>?
    var pendingCount: Int { lock.watchTestLocked { operations.count } }

    func enqueue(_ operation: @escaping Operation) {
        let waiting = lock.watchTestLocked { () -> CheckedContinuation<Operation, Never>? in
            if let waiting = waiter { waiter = nil; return waiting }
            operations.append(operation)
            return nil
        }
        waiting?.resume(returning: operation)
    }

    func takeNext() async -> Operation {
        await withCheckedContinuation { continuation in
            let operation = lock.watchTestLocked { () -> Operation? in
                if !operations.isEmpty { return operations.removeFirst() }
                precondition(waiter == nil, "Only one manual utility consumer")
                waiter = continuation
                return nil
            }
            if let operation { continuation.resume(returning: operation) }
        }
    }

    @MainActor func runAllReady() {
        while let operation = lock.watchTestLocked({ operations.isEmpty ? nil : operations.removeFirst() }) {
            operation()
        }
    }
}

private final class ManualWatchMain: @unchecked Sendable {
    private let lock = NSLock()
    private var deliveries: [AppSourceWatchMainDelivery] = []
    private var enqueues = 0
    var pendingCount: Int { lock.watchTestLocked { deliveries.count } }
    var enqueueCount: Int { lock.watchTestLocked { enqueues } }

    func enqueue(_ delivery: @escaping AppSourceWatchMainDelivery) {
        lock.watchTestLocked { deliveries.append(delivery); enqueues += 1 }
    }

    @MainActor func runAll() {
        while let delivery = lock.watchTestLocked({ deliveries.isEmpty ? nil : deliveries.removeFirst() }) {
            delivery()
        }
    }
}
