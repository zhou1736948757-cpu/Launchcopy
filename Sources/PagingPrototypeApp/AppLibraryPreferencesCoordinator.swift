import AppGridUI
import Foundation

/// Accepted-write owner. Views never optimistically claim a category was saved.
@MainActor
final class AppLibraryPreferencesCoordinator {
    private(set) var committed: AppLibraryPreferences = .default
    private(set) var persistedPreferences: AppLibraryPreferences = .default
    private(set) var persistedGeneration: UInt64 = 0
    private(set) var loadResult: AppLibraryLoadResult = .missing
    private(set) var latestSaveResult: AppLibrarySaveResult?
    private(set) var pendingCount = 0
    private(set) var isLoaded = false
    var onChange: (() -> Void)?
    var requiresQuitProtection: Bool {
        pendingCount > 0 || (latestSaveResult != nil && latestSaveResult != .saved)
    }

    private let store: any AppLibraryPersisting
    private var generation: UInt64 = 0
    private var isActive = true
    private var loadTask: Task<Void, Never>?
    private var tail: Task<Void, Never>?

    init(store: any AppLibraryPersisting) { self.store = store }

    /// Exactly one lazy inspection. Loading a disabled feature performs no writes.
    func loadIfNeeded() async {
        if let loadTask { await loadTask.value; return }
        guard isActive, !isLoaded else { return }
        let store = self.store
        let task = Task { [weak self] in
            let result = await store.load()
            guard let self, self.isActive else { return }
            self.loadResult = result
            self.committed = result.preferences
            self.persistedPreferences = result.preferences
            self.isLoaded = true
            self.onChange?()
        }
        loadTask = task
        await task.value
        loadTask = nil
    }

    /// The captured draft is immutable and writes are ordered across async seams.
    /// Only the newest accepted successful generation can update presentation.
    @discardableResult
    func submit(_ draft: AppLibraryPreferences, recoveringCorruptPayload: Bool = false) -> Bool {
        guard isActive, isLoaded, draft.isValid else { return false }
        generation &+= 1
        let token = generation
        let predecessor = tail
        let store = self.store
        pendingCount += 1
        latestSaveResult = nil
        let task = Task { [weak self] in
            await predecessor?.value
            let result = await store.save(draft, recoveringCorruptPayload: recoveringCorruptPayload)
            guard let self else { return }
            self.pendingCount -= 1
            if result == .saved {
                // Bookkeeping of disk receipts is independent of UI freshness.
                self.persistedPreferences = draft
                self.persistedGeneration = token
            }
            guard self.isActive, token == self.generation else { return }
            self.tail = nil
            self.latestSaveResult = result
            // A newer failure cannot roll back an older accepted successful save.
            // Reconcile to that real baseline, never publish the failed draft.
            self.committed = self.persistedPreferences
            if result == .saved || self.persistedGeneration > 0 {
                self.loadResult = .loaded(self.persistedPreferences)
            }
            self.onChange?()
        }
        tail = task
        onChange?()
        return true
    }

    /// Polls receipts with a real bounded deadline. A timed-out writer stays owned;
    /// structured task-group races would accidentally wait for the losing writer.
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
        case .saved?: return .persisted(writeGeneration: generation)
        case nil: return .nothingPending
        case .protectedPayload?, .recoveryRequired?: return .readOnly
        default: return .failed
        }
    }

    /// Accepted writes are not cancelled; late UI callbacks are suppressed.
    func invalidate() {
        isActive = false
        onChange = nil
    }
}
