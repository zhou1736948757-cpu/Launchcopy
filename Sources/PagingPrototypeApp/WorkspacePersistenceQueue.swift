import AppGridUI
import Foundation

/// Orders accepted writes for a store epoch and exposes an asynchronous drain.
/// Captured stores never change underneath a queued submission. No frame-path I/O.
@MainActor
public final class WorkspacePersistenceQueue {
    private struct Pending {
        let epoch: UInt64
        let task: Task<Void, Never>
    }
    private var nextID: UInt64 = 0
    private var pending: [UInt64: Pending] = [:]
    private var tail: (id: UInt64, epoch: UInt64, task: Task<Void, Never>)?
    private final class FlushOperation {
        let submissionID: UInt64?
        var task: Task<Void, Never>?
        var result: LayoutStoreFlushResult?
        var completions: [(LayoutStoreFlushResult) -> Void] = []
        init(submissionID: UInt64?) { self.submissionID = submissionID }
        var completedSuccessfully: Bool {
            switch result { case .persisted?, .nothingPending?: return true; default: return false }
        }
    }
    private var flushes: [UInt64: FlushOperation] = [:]
    private var observers: [UInt64: Task<Void, Never>] = [:]
    private var latestSubmission: [UInt64: UInt64] = [:]
    public var pendingCount: Int { pending.count }

    private let observationWait: Duration
    public init(observationWait: Duration = .seconds(2)) { self.observationWait = observationWait }

    public func submit(_ layout: PersistentWorkspaceLayout, to store: any LayoutStore,
                       epoch: UInt64, isCurrent: @escaping () -> Bool,
                       observeState: @escaping (LayoutStoreState) -> Void,
                       observeOutcome: @escaping (LayoutStoreFlushResult) -> Void = { _ in }) {
        nextID &+= 1
        let id = nextID
        latestSubmission[epoch] = id
        let predecessor = tail?.epoch == epoch ? tail?.task : nil
        let task = Task { [weak self] in
            await predecessor?.value
            guard let self else { return }
            defer {
                self.pending[id] = nil
                if self.tail?.id == id { self.tail = nil }
            }
            guard isCurrent() else { return }
            await store.enqueue(layout)
            guard isCurrent() else { return }
            self.scheduleObservation(to: store, epoch: epoch, isCurrent: isCurrent,
                                     observeState: observeState, observeOutcome: observeOutcome)
        }
        pending[id] = .init(epoch: epoch, task: task)
        tail = (id, epoch, task)
    }

    /// Does not block the main runloop or use a task-group cancellation race whose
    /// losing child could remain suspended on Task.value indefinitely. Store.flush
    /// has its own bounded barrier; the enqueue wait below is bounded separately.
    public func drain(to store: any LayoutStore, epoch: UInt64,
                      enqueueWait: Duration = .seconds(2),
                      flushWait: Duration = .seconds(2),
                      isCurrent: () -> Bool) async -> LayoutStoreFlushResult {
        let clock = ContinuousClock()
        let enqueueDeadline = clock.now.advanced(by: enqueueWait)
        var flushDeadline: ContinuousClock.Instant?
        while true {
            while pending.values.contains(where: { $0.epoch == epoch }) {
                guard isCurrent(), !Task.isCancelled else { return .staleRejected }
                guard clock.now < enqueueDeadline else { return .timedOut }
                do { try await Task.sleep(for: .milliseconds(2)) }
                catch { return .timedOut }
            }
            guard isCurrent(), !Task.isCancelled else { return .staleRejected }
            let operation: FlushOperation
            if let existing = flushes[epoch], existing.result == nil ||
                (existing.submissionID == latestSubmission[epoch] && existing.completedSuccessfully) {
                operation = existing
            } else {
                operation = FlushOperation(submissionID: latestSubmission[epoch])
                flushes[epoch] = operation
                // Retain ownership after caller timeout; never await an unfinishable
                // losing child or start a second writer for this epoch.
                operation.task = Task {
                    let result = await store.flush()
                    operation.result = result
                    operation.task = nil
                    let completions = operation.completions
                    operation.completions.removeAll()
                    for completion in completions { completion(result) }
                }
            }
            if flushDeadline == nil { flushDeadline = clock.now.advanced(by: flushWait) }
            while operation.result == nil {
                guard isCurrent(), !Task.isCancelled else { return .staleRejected }
                guard clock.now < flushDeadline! else { return .timedOut }
                do { try await Task.sleep(for: .milliseconds(2)) }
                catch { return .timedOut }
            }
            guard isCurrent() else { return .staleRejected }
            // A newer accepted batch may have arrived while this receipt was in
            // flight. Never certify its durability using the earlier receipt.
            if operation.submissionID != latestSubmission[epoch] {
                guard clock.now < flushDeadline! else { return .timedOut }
                continue
            }
            return operation.result ?? .timedOut
        }
    }

    private func scheduleObservation(to store: any LayoutStore, epoch: UInt64,
                                     isCurrent: @escaping () -> Bool,
                                     observeState: @escaping (LayoutStoreState) -> Void,
                                     observeOutcome: @escaping (LayoutStoreFlushResult) -> Void) {
        guard observers[epoch] == nil else { return }
        observers[epoch] = Task { [weak self] in
            guard let self else { return }
            defer { self.observers[epoch] = nil }
            while isCurrent() {
                let batch = self.latestSubmission[epoch]
                let result = await self.drain(to: store, epoch: epoch, flushWait: self.observationWait, isCurrent: isCurrent)
                guard isCurrent() else { return }
                if self.latestSubmission[epoch] != batch { continue }
                observeOutcome(result)
                if result == .timedOut, let operation = self.flushes[epoch], operation.result == nil {
                    operation.completions.append { [weak self, weak operation] completion in
                        guard isCurrent(), self?.latestSubmission[epoch] == batch else { return }
                        guard operation?.submissionID == batch else {
                            self?.scheduleObservation(to: store, epoch: epoch, isCurrent: isCurrent,
                                observeState: observeState, observeOutcome: observeOutcome)
                            return
                        }
                        observeOutcome(completion)
                        Task {
                            let state = await store.currentState()
                            if isCurrent(), self?.latestSubmission[epoch] == batch { observeState(state) }
                        }
                    }
                } else {
                    let state = await store.currentState()
                    guard isCurrent() else { return }
                    if self.latestSubmission[epoch] != batch { continue }
                    observeState(state)
                }
                return
            }
        }
    }
}
