import AppCatalogCore
import AppGridUI
import Foundation
import LauncherLocalization

/// Opt-in activity admission and accepted writes. Launching never waits for disk.
/// One active immutable save plus one latest queued snapshot bounds writer work.
@MainActor
final class LaunchActivityCoordinator {
    private struct Pending {
        let revision: UInt64
        let document: LaunchActivityDocument
        let recovering: Bool
        let clearing: Bool
    }

    private(set) var document = LaunchActivityDocument()
    private(set) var persistedDocument: LaunchActivityDocument?
    private(set) var loadResult: LaunchActivityLoadResult = .missing
    private(set) var latestSaveResult: LaunchActivitySaveResult?
    private(set) var isLoaded = false
    private(set) var libraryEnabled = false
    private(set) var generation: UInt64 = 0
    private(set) var isClearing = false
    private(set) var didClear = false
    var onChange: (() -> Void)?
    var projectionDate: Date { now() }
    var pendingCount: Int { (activeWrite == nil ? 0 : 1) + (pending == nil ? 0 : 1) }
    var requiresQuitProtection: Bool {
        pendingPrivacyDisable || pendingCount > 0 || (latestSaveResult != nil && latestSaveResult != .saved)
    }
    var canWrite: Bool {
        guard isActive, isLoaded else { return false }
        switch loadResult {
        case .missing, .loaded: return latestSaveResult != .protectedPayload && latestSaveResult != .recoveryRequired
        default: return false
        }
    }
    var canRecover: Bool {
        isActive && isLoaded && (loadResult == .corrupt || latestSaveResult == .recoveryRequired)
    }
    var isCollecting: Bool {
        isActive && isLoaded && libraryEnabled && document.enabled
            && persistedDocument?.enabled == true && canWrite && !isClearing
            && (latestSaveResult == nil || latestSaveResult == .saved)
    }

    private let store: any LaunchActivityPersisting
    private let now: () -> Date
    private var isActive = true
    private var revision: UInt64 = 0
    private var persistedRevision: UInt64 = 0
    private var pending: Pending?
    private var activeWrite: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var pendingPrivacyDisable = false

    init(store: any LaunchActivityPersisting, now: @escaping () -> Date = { Date() }) {
        self.store = store
        self.now = now
    }

    func loadIfNeeded() async {
        if let loadTask { await loadTask.value; return }
        guard isActive, !isLoaded else { return }
        let store = self.store
        let task = Task { [weak self] in
            let result = await store.load()
            guard let self, self.isActive else { return }
            self.loadResult = result
            if case .loaded(let value) = result {
                self.document = value
                self.persistedDocument = value
                if self.pendingPrivacyDisable { self.document.enabled = false }
                self.document.prune(at: self.now())
            }
            if self.pendingPrivacyDisable {
                // An accepted privacy stop survives a delayed read and receives
                // truthful failure/Quit protection if its file is not writable.
                switch result {
                case .unavailable: self.latestSaveResult = .unavailable
                case .corrupt: self.latestSaveResult = .recoveryRequired
                case .futureVersion, .ambiguousSchema, .oversized: self.latestSaveResult = .protectedPayload
                default: break
                }
                self.pendingPrivacyDisable = false
            }
            self.isLoaded = true
            if let persisted = self.persistedDocument, self.document != persisted {
                // Prune only an existing supported payload, preserving its opt-in.
                // Missing/default-OFF inspection still creates no directories/file.
                self.enqueue(self.document)
            } else { self.onChange?() }
        }
        loadTask = task
        await task.value
        loadTask = nil
    }

    func setLibraryEnabled(_ value: Bool) {
        guard isActive, value != libraryEnabled else { return }
        libraryEnabled = value
        generation &+= 1 // A disabled interval cannot be replayed after re-enable.
        onChange?()
    }

    @discardableResult
    func setEnabled(_ value: Bool) -> Bool {
        // Loading is not permission to overwrite a newer explicit OFF decision.
        // Retain it independently of the not-yet-known document/receipt baseline.
        if !value, isActive, !isLoaded {
            pendingPrivacyDisable = true
            generation &+= 1
            document.enabled = false
            didClear = false
            onChange?()
            return true
        }
        // Disabling admission is immediate even if the file has become protected.
        if !value, document.enabled {
            document.enabled = false
            generation &+= 1
            didClear = false
            guard canWrite else { onChange?(); return false }
            // Coalescing a privacy-OFF snapshot must retain the outstanding
            // clear barrier, including when Clear is only queued behind a write.
            enqueue(document, clearing: isClearing)
            return true
        }
        guard canWrite, libraryEnabled, !isClearing else { return false }
        guard value != document.enabled else { return true }
        generation &+= 1
        document.enabled = value
        document.prune(at: now())
        didClear = false
        enqueue(document)
        return true
    }

    /// Capture BEFORE calling the external executor. Reentrant disable, clear,
    /// library changes or owner teardown revoke this token before acceptance.
    func prepareObservation(for record: AppRecord) -> (() -> Void)? {
        guard isCollecting else { return nil }
        let token = generation
        var consumed = false
        return { [weak self] in
            guard !consumed else { return }
            consumed = true
            guard let self, self.isCollecting, self.generation == token else { return }
            let old = self.document
            self.document.record(record, at: self.now())
            guard self.document != old else { return }
            self.didClear = false
            self.enqueue(self.document)
        }
    }

    /// Caller owns the explicit native confirmation. Disable/clear never affect
    /// workspace layout, categories, aliases or hidden preferences.
    @discardableResult
    func clear(expectedGeneration: UInt64) -> Bool {
        guard canWrite, !isClearing, expectedGeneration == generation else { return false }
        generation &+= 1
        isClearing = true
        didClear = false
        document = LaunchActivityDocument(enabled: document.enabled)
        enqueue(document, clearing: true)
        return true
    }

    @discardableResult
    func recover() -> Bool {
        guard canRecover, pendingCount == 0 else { return false }
        generation &+= 1
        isClearing = true
        didClear = false
        document = LaunchActivityDocument() // Explicit recovery never enables tracking.
        enqueue(document, recovering: true, clearing: true)
        return true
    }

    @discardableResult
    func retry() -> Bool {
        guard canWrite, pendingCount == 0, let result = latestSaveResult, result != .saved else { return false }
        enqueue(document, clearing: isClearing)
        return true
    }

    private func enqueue(_ value: LaunchActivityDocument, recovering: Bool = false, clearing: Bool = false) {
        revision &+= 1
        pending = Pending(revision: revision, document: value, recovering: recovering, clearing: clearing)
        latestSaveResult = nil
        startNext()
        if isActive { onChange?() }
    }

    private func startNext() {
        guard activeWrite == nil, let next = pending else { return }
        pending = nil
        let store = self.store
        // Own accepted work through its receipt and queued handoff, even after
        // invalidation releases the UI owner. Clearing activeWrite below breaks
        // this temporary ownership once the finite pending chain has settled.
        activeWrite = Task { [self] in
            let result = await store.save(next.document, recoveringCorruptPayload: next.recovering)
            self.activeWrite = nil
            if result == .saved {
                self.persistedDocument = next.document
                self.persistedRevision = next.revision
                self.loadResult = .loaded(next.document)
            }
            if next.revision == self.revision {
                self.latestSaveResult = result
                if next.clearing, result == .saved { self.isClearing = false; self.didClear = true }
            }
            self.startNext()
            if self.isActive { self.onChange?() }
        }
    }

    func drain(timeout: Duration = .seconds(2)) async -> LayoutStoreFlushResult {
        let clock = ContinuousClock(), deadline = ContinuousClock().now.advanced(by: timeout)
        while pendingCount > 0 || pendingPrivacyDisable {
            guard isActive, !Task.isCancelled else { return .staleRejected }
            guard clock.now < deadline else { return .timedOut }
            do { try await Task.sleep(for: .milliseconds(2)) } catch { return .timedOut }
        }
        guard isActive else { return .staleRejected }
        switch latestSaveResult {
        case .saved?: return .persisted(writeGeneration: persistedRevision)
        case nil: return .nothingPending
        case .protectedPayload?, .recoveryRequired?: return .readOnly
        default: return .failed
        }
    }

    func invalidate() {
        isActive = false
        generation &+= 1
        onChange = nil
        // Accepted writes retain ownership; they are never cancelled on hide.
    }

    var status: LaunchActivityTextKey {
        guard isLoaded else { return .waiting }
        if pendingCount > 0 { return .saving }
        switch latestSaveResult {
        case .saved?: if didClear { return .cleared }
        case .protectedPayload?: return .protected
        case .recoveryRequired?: return .recoveryRequired
        case .failed?, .unavailable?, .invalidPreferences?: return .saveFailed
        case nil: break
        }
        switch loadResult {
        case .futureVersion, .ambiguousSchema, .oversized: return .protected
        case .corrupt: return .recoveryRequired
        case .unavailable: return .unavailable
        default: break
        }
        if !libraryEnabled { return .libraryDisabled }
        return document.enabled ? .saved : .off
    }
}
