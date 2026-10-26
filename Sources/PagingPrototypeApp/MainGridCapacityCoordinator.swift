import AppGridUI
import Foundation

/// Owns accepted capacity writes independently of layout presentation readiness.
/// A successful disk receipt is not a claim that a busy grid has reconfigured.
@MainActor
final class MainGridCapacityCoordinator {
    private(set) var requestedCapacity: MainGridCapacity = .default
    private(set) var committed: MainGridCapacity = .default
    private(set) var persistedCapacity: MainGridCapacity = .default
    private(set) var persistedGeneration: UInt64 = 0
    private(set) var loadResult: MainGridCapacityLoadResult = .missing
    private(set) var latestSaveResult: MainGridCapacitySaveResult?
    private(set) var pendingCount = 0
    private(set) var isLoaded = false
    var onChange: (() -> Void)?

    var requiresQuitProtection: Bool {
        pendingCount > 0 || (latestSaveResult != nil && latestSaveResult != .saved)
    }

    private let store: any MainGridCapacityPersisting
    private var generation: UInt64 = 0
    private var isActive = true
    private var loadTask: Task<Void, Never>?
    private struct Write {
        let value: MainGridCapacity
        let recovering: Bool
        let generation: UInt64
    }
    private var tail: Task<Void, Never>?
    private var queued: Write?

    init(store: any MainGridCapacityPersisting) { self.store = store }

    /// Inspection never creates or repairs a payload. Concurrent callers share it.
    func loadIfNeeded() async {
        if let loadTask { await loadTask.value; return }
        guard isActive, !isLoaded else { return }
        let store = self.store
        let task = Task { [weak self] in
            let result = await store.load()
            guard let self, self.isActive else { return }
            self.loadResult = result
            self.requestedCapacity = result.capacity
            self.committed = result.capacity
            self.persistedCapacity = result.capacity
            self.isLoaded = true
            self.onChange?()
        }
        loadTask = task
        await task.value
        loadTask = nil
    }

    /// One active immutable write plus one newest queued edit; intermediate edits coalesce.
    /// Every actual receipt remains owned even when a newer intention supersedes it.
    @discardableResult
    func submit(_ draft: MainGridCapacity, recoveringCorruptPayload: Bool = false) -> Bool {
        guard isActive, isLoaded else { return false }
        switch loadResult {
        case .protectedPayload, .unavailable: return false
        default: break
        }
        if pendingCount == 0, !recoveringCorruptPayload,
           requestedCapacity == draft, committed == draft,
           latestSaveResult == nil || latestSaveResult == .saved,
           case .loaded(let healthy) = loadResult, healthy == draft {
            // Already acknowledged bytes: no new generation or physical write.
            latestSaveResult = .saved
            onChange?()
            return true
        }
        if pendingCount > 0, requestedCapacity == draft { return true }
        generation &+= 1
        requestedCapacity = draft
        let write = Write(value: draft, recovering: recoveringCorruptPayload, generation: generation)
        latestSaveResult = nil
        if tail != nil {
            // All intermediate unstarted intentions are superseded by the newest edit.
            queued = write
            pendingCount = 2
        } else { start(write) }
        onChange?()
        return true
    }

    private func start(_ write: Write) {
        pendingCount = 1
        let store = store
        tail = Task { [self] in
            let result = await store.save(write.value, recoveringCorruptPayload: write.recovering)
            if result == .saved {
                persistedCapacity = write.value
                persistedGeneration = write.generation
            }
            tail = nil
            if let next = queued {
                queued = nil
                start(next)
                return
            }
            pendingCount = 0
            guard isActive, write.generation == generation else { return }
            latestSaveResult = result
            committed = persistedCapacity
            if result == .saved || persistedGeneration > 0 { loadResult = .loaded(persistedCapacity) }
            onChange?()
        }
    }

    /// A bounded wait does not abandon or cancel the accepted writer on timeout.
    func drain(timeout: Duration = .seconds(2)) async -> LayoutStoreFlushResult {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while pendingCount > 0 {
            guard isActive, !Task.isCancelled else { return .staleRejected }
            guard clock.now < deadline else { return .timedOut }
            do { try await Task.sleep(for: .milliseconds(2)) }
            catch { return .timedOut }
        }
        guard isActive else { return .staleRejected }
        switch latestSaveResult {
        case .saved?:
            return persistedGeneration > 0 ? .persisted(writeGeneration: persistedGeneration) : .nothingPending
        case nil: return .nothingPending
        case .protectedPayload?, .recoveryRequired?: return .readOnly
        default: return .failed
        }
    }

    /// Teardown suppresses presentation callbacks, never cancels accepted I/O.
    func invalidate() {
        isActive = false
        onChange = nil
    }
}
