/// Neutral catalog presentation vocabulary. App identities and queries remain data.
public enum CatalogTextKey: String, CaseIterable, Sendable {
    case loading = "catalog.loading"
    case ready = "catalog.ready"
    case empty = "catalog.empty"
    case partialFailure = "catalog.partialFailure"
    case refreshing = "catalog.refreshing"
    case noResults = "catalog.noResults"

    public var englishFallback: String {
        switch self {
        case .loading: return "Loading application catalog…"
        case .ready: return "Application catalog ready"
        case .empty: return "No applications found"
        case .partialFailure: return "Some app sources or items could not be read"
        case .refreshing: return "Refreshing application catalog…"
        case .noResults: return "No applications match the search"
        }
    }
}
