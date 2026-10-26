import AppCatalogCore
import AppGridUI
import Foundation

/// Immutable input captures every generation-affecting value. Library filtering
/// never invents a catalog revision or mutates the shared scanner/repository.
struct AppLibraryProjectionRequest: Sendable {
    let catalog: CatalogSnapshot
    let management: AppManagementPreferences
    let preferences: AppLibraryPreferences
    let query: String
    let category: AppLibraryCategory?
    let locale: Locale
    let activity: LaunchActivityDocument?
    let activitySection: LaunchActivitySection?
    let activityNow: Date

    init(catalog: CatalogSnapshot, management: AppManagementPreferences,
         preferences: AppLibraryPreferences, query: String = "",
         category: AppLibraryCategory? = nil, locale: Locale = .current,
         activity: LaunchActivityDocument? = nil, activitySection: LaunchActivitySection? = nil,
         activityNow: Date = Date()) {
        self.catalog = catalog
        self.management = management
        self.preferences = preferences
        self.query = query
        self.category = category
        self.locale = locale
        self.activity = activity
        self.activitySection = activitySection
        self.activityNow = activityNow
    }
}

/// At most one running projection and one replaceable pending request. Rapid
/// queries cannot create unbounded tasks, and closing invalidates every callback.
@MainActor
final class AppLibraryProjectionController {
    typealias Work = @Sendable (AppLibraryProjectionRequest) async -> AppLibrarySnapshot?
    private struct Pending {
        let generation: UInt64
        let request: AppLibraryProjectionRequest
    }
    private(set) var isOpen = false
    private(set) var snapshot: AppLibrarySnapshot?
    private(set) var isProjecting = false
    var onChange: (() -> Void)?
    private let work: Work
    private var generation: UInt64 = 0
    private var pending: Pending?
    private var task: Task<Void, Never>?

    init(work: Work? = nil) {
        self.work = work ?? { await AppLibraryProjectionController.backgroundProjection($0) }
    }

    func open(_ request: AppLibraryProjectionRequest) {
        isOpen = true
        update(request)
    }

    func update(_ request: AppLibraryProjectionRequest) {
        guard isOpen else { return }
        generation &+= 1
        pending = Pending(generation: generation, request: request)
        snapshot = nil // Stale results must not remain actionable while updating.
        startNextIfNeeded()
        onChange?()
    }

    func close() {
        isOpen = false
        generation &+= 1
        pending = nil
        snapshot = nil
        // Keep ownership until completion; do not start a second worker if reopened.
        task?.cancel()
        onChange?()
    }

    private func startNextIfNeeded() {
        guard isOpen, task == nil, let next = pending else { return }
        pending = nil
        isProjecting = true
        let work = self.work
        task = Task { [weak self] in
            let result = await work(next.request)
            guard let self else { return }
            self.task = nil
            self.isProjecting = false
            if self.isOpen, self.generation == next.generation, !Task.isCancelled {
                if let result, result.revision == next.request.catalog.revision {
                    self.snapshot = result
                }
                // A missing/rejected result is terminal too; observers must stop
                // displaying loading without exposing stale actionable entries.
                self.onChange?()
            }
            self.startNextIfNeeded()
        }
    }

    nonisolated static func backgroundProjection(_ request: AppLibraryProjectionRequest) async -> AppLibrarySnapshot? {
        let worker = Task.detached(priority: .utility) { () -> AppLibrarySnapshot? in
            guard !Task.isCancelled else { return nil }
            let snapshot = AppLibraryProjection.make(catalog: request.catalog,
                management: request.management, preferences: request.preferences,
                query: request.query, category: request.category, locale: request.locale)
            let result: AppLibrarySnapshot
            if let section = request.activitySection, let activity = request.activity, activity.enabled {
                result = activity.filtering(snapshot, section: section, at: request.activityNow)
            } else { result = snapshot }
            return Task.isCancelled ? nil : result
        }
        return await withTaskCancellationHandler(operation: { await worker.value },
                                                 onCancel: { worker.cancel() })
    }
}
