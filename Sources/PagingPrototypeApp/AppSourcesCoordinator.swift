import Foundation

public enum AppSourcesApplyResult: Equatable, Sendable {
    case saved, invalidRoot, futureVersion, failed, superseded
}

/// One transaction owner; discovery inputs never mutate workspace organization.
@MainActor
public final class AppSourcesCoordinator {
    public private(set) var committed: AppSourcesPreferences
    public private(set) var loadResult: AppSourcesLoadResult
    public private(set) var watchStatus: AppSourceWatchStatus = .disabled
    public var onWatchStatusChange: ((AppSourceWatchStatus) -> Void)?
    private let store: any AppSourcesPersisting
    private let admission: any AppSourceRootAdmitting
    private let context: AppSourceRootAdmissionContext
    private let fixedRoots: [URL]
    private let watcher: any AppSourceWatching
    private let replaceRoots: ([URL]) -> Void
    private let requestRefresh: (_ immediate: Bool) -> Void
    private var transaction: UInt64 = 0
    private var watchGeneration: UInt64 = 0
    private var watchTask: Task<Void, Never>?
    private var watchedRoots: [URL] = []
    private var sourceGeneration: UInt64 = 0
    private var watchedSourceGeneration: UInt64?
    private var backendWatchStatus: AppSourceWatchStatus = .disabled
    // Availability returning does not prove a previously lost stream reattached.
    private var fixedRootCoverageLost = false
    private var coverageRefreshPending = false
    private var isActive = false
    private var isTornDown = false

    public init(store: any AppSourcesPersisting, admission: any AppSourceRootAdmitting,
                context: AppSourceRootAdmissionContext, fixedRoots: [URL],
                watcher: any AppSourceWatching,
                replaceRoots: @escaping ([URL]) -> Void,
                requestRefresh: @escaping (Bool) -> Void) {
        self.store = store; self.admission = admission; self.context = context
        self.fixedRoots = fixedRoots; self.watcher = watcher
        self.replaceRoots = replaceRoots; self.requestRefresh = requestRefresh
        loadResult = store.load(); committed = loadResult.preferences
    }

    public func activate() {
        guard !isActive, !isTornDown else { return }
        isActive = true
        replaceRoots(fixedRoots + committed.customRootPaths.map { URL(fileURLWithPath: $0) })
        updateWatchSet()
    }

    public func admitDraftRoot(_ url: URL) async -> AppSourceRootAdmissionResult {
        await admission.admit(url, context: context)
    }

    @discardableResult
    public func apply(_ draft: AppSourcesPreferences) async -> AppSourcesApplyResult {
        guard !isTornDown, draft.isValid else { return .invalidRoot }
        if case .futureVersion = loadResult { return .futureVersion }
        transaction &+= 1
        let ticket = transaction
        // Retain temporarily unavailable, previously accepted references. Revalidation
        // before every actual scan excludes unsafe/replaced roots; removal/toggle is
        // still possible without forcing a missing disk to be mounted first.
        for path in draft.customRootPaths where !committed.customRootPaths.contains(path) {
            guard case .accepted(let root) = await admission.admit(URL(fileURLWithPath: path), context: context),
                  root.path == path else { return .invalidRoot }
            guard ticket == transaction, !isTornDown, !Task.isCancelled else { return .superseded }
        }
        guard ticket == transaction, !isTornDown, !Task.isCancelled else { return .superseded }
        switch store.save(draft) {
        case .futureVersion: return .futureVersion
        case .invalidPreferences: return .invalidRoot
        case .failed: return .failed
        case .saved: break
        }
        let rootsChanged = committed.customRootPaths != draft.customRootPaths
        if rootsChanged || committed.automaticRefreshEnabled != draft.automaticRefreshEnabled {
            sourceGeneration &+= 1
        }
        committed = draft; loadResult = .loaded(draft)
        if isActive {
            if rootsChanged {
                replaceRoots(fixedRoots + draft.customRootPaths.map { URL(fileURLWithPath: $0) })
                requestRefresh(true)
            }
            updateWatchSet()
        }
        return .saved
    }

    public func refreshNow() {
        guard isActive, !isTornDown else { return }
        updateWatchSet(forceRestart: true)
        requestRefresh(true)
    }

    private func setWatchStatus(_ value: AppSourceWatchStatus) {
        guard value != watchStatus else { return }
        watchStatus = value; onWatchStatusChange?(value)
    }

    private func updateWatchSet(forceRestart: Bool = false) {
        watchGeneration &+= 1
        let ticket = watchGeneration
        watchTask?.cancel(); watchTask = nil
        coverageRefreshPending = false
        guard committed.automaticRefreshEnabled, !isTornDown else {
            watcher.stop(); watchedRoots = []; watchedSourceGeneration = nil
            fixedRootCoverageLost = false
            backendWatchStatus = .disabled; setWatchStatus(.disabled); return
        }
        let paths = committed.customRootPaths
        watchTask = Task { [weak self] in
            guard let self else { return }
            let resolved = await AppSourceRootSetResolver.resolve(fixedRoots: self.fixedRoots,
                customRoots: paths.map { URL(fileURLWithPath: $0) }, context: self.context, admission: self.admission)
            guard ticket == self.watchGeneration, !Task.isCancelled, !self.isTornDown else { return }
            let fixedRootsAvailable = await self.fixedRootsAreAvailable()
            guard ticket == self.watchGeneration, !Task.isCancelled, !self.isTornDown else { return }
            let roots = resolved.roots
            let sourceTicket = self.sourceGeneration
            if roots != self.watchedRoots || self.watchedSourceGeneration != sourceTicket
                || self.watchStatus == .unavailable || self.watchStatus == .disabled
                || forceRestart {
                let status = await self.watcher.replaceRoots(roots) { [weak self] in
                    guard let self, self.sourceGeneration == sourceTicket else { return }
                    self.watchInvalidated()
                }
                guard ticket == self.watchGeneration, !Task.isCancelled, !self.isTornDown else { return }
                self.watchedRoots = roots; self.watchedSourceGeneration = sourceTicket
                self.backendWatchStatus = status
                self.fixedRootCoverageLost = !fixedRootsAvailable
            } else {
                self.fixedRootCoverageLost = self.fixedRootCoverageLost || !fixedRootsAvailable
            }
            let degraded = resolved.excludedReferenceCount > 0 || self.fixedRootCoverageLost
            let status = self.backendWatchStatus
            self.setWatchStatus(degraded && (status == .active || status == .disabled) ? .degraded : status)
            self.watchTask = nil
            if self.coverageRefreshPending { self.updateWatchSet() }
        }
    }

    /// Status-only inspection through the existing off-Main admitter. Do not change
    /// trusted scan roots or draft admission's already-covered shortcut. Retain all
    /// profile boundaries, but avoid that shortcut for these exact coverage probes.
    private func fixedRootsAreAvailable() async -> Bool {
        let coverageContext = AppSourceRootAdmissionContext(
            homeURL: context.homeURL, fixedRoots: [],
            allowedSyntheticRoot: context.allowedSyntheticRoot,
            requiresExactCanonicalPath: context.requiresExactCanonicalPath || context.allowedSyntheticRoot != nil
        )
        for root in fixedRoots {
            guard !Task.isCancelled else { return false }
            guard case .accepted = await admission.admit(root, context: coverageContext) else { return false }
        }
        return true
    }

    private func watchInvalidated() {
        guard isActive, !isTornDown, committed.automaticRefreshEnabled else { return }
        // Native adapter bounds delivery backlog; the existing refresh controller
        // supplies rescan debounce and one latest-wins follow-up, never frame IO.
        requestRefresh(false)
        if watchTask == nil { updateWatchSet() }
        else { coverageRefreshPending = true }
    }

    public func teardown() {
        guard !isTornDown else { return }
        isTornDown = true; transaction &+= 1; watchGeneration &+= 1
        watchTask?.cancel(); watchTask = nil; watcher.stop(); watchedRoots = []
        fixedRootCoverageLost = false
        coverageRefreshPending = false
        setWatchStatus(.disabled); onWatchStatusChange = nil
    }
}
