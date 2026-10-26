import AppGridUI

/// Serves UI state, not pending input or catalog candidates. No text, IO or mutation.
enum CatalogStatusPresentation {
    static func resolve(refresh: AppGridUIState, hasSnapshot: Bool, hasVisibleApps: Bool,
                        hasCommittedQuery: Bool, committedResultIsEmpty: Bool) -> AppGridUIState {
        switch refresh {
        case .partialFailure: return .partialFailure
        case .refreshing: return .refreshing
        default: break
        }
        guard hasSnapshot else { return .loading }
        guard hasVisibleApps else { return .empty }
        if hasCommittedQuery && committedResultIsEmpty { return .noResults }
        return .ready
    }
}
