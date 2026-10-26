import AppCatalogCore
import Foundation

public struct AppLibraryEntry: Equatable, Sendable {
    /// Canonical catalog record, including original name and bundle metadata.
    public let record: AppRecord
    public let displayName: String
    public let category: AppLibraryCategory
    public let manualCategory: AppLibraryCategory?

    public init(record: AppRecord, displayName: String, category: AppLibraryCategory,
                manualCategory: AppLibraryCategory? = nil) {
        self.record = record
        self.displayName = displayName
        self.category = category
        self.manualCategory = manualCategory
    }
}

public struct AppLibrarySnapshot: Equatable, Sendable {
    public let revision: CatalogRevision
    public let entries: [AppLibraryEntry]
    /// Visible query matches across all categories, independent of the selected filter.
    public let counts: [AppLibraryCategory: Int]

    public init(revision: CatalogRevision, entries: [AppLibraryEntry],
                counts: [AppLibraryCategory: Int]) {
        self.revision = revision
        self.entries = entries
        self.counts = counts
    }
}

/// Pure projection of the shared committed catalog. Scheduling and generation gates
/// belong to the owner; this code performs no I/O, tasks or catalog revision changes.
public enum AppLibraryProjection {
    public static func make(catalog: CatalogSnapshot, management: AppManagementPreferences,
                            preferences: AppLibraryPreferences, query: String = "",
                            category: AppLibraryCategory? = nil,
                            locale: Locale = .current) -> AppLibrarySnapshot {
        let search = AppSearchQuery(raw: query, locale: locale)
        var counts = Dictionary(uniqueKeysWithValues: AppLibraryCategory.allCases.map { ($0, 0) })
        var entries: [AppLibraryEntry] = []
        for record in catalog.records where management.matches(record, query: search) {
            let effective = preferences.category(for: record)
            counts[effective, default: 0] += 1
            guard category == nil || category == effective else { continue }
            entries.append(AppLibraryEntry(record: record,
                                           displayName: management.displayName(for: record),
                                           category: effective,
                                           manualCategory: preferences.manualCategory(for: record)))
        }
        entries.sort { left, right in
            let order = left.displayName.compare(right.displayName, options: [.caseInsensitive],
                                                 range: nil, locale: locale)
            if order != .orderedSame { return order == .orderedAscending }
            return left.record.canonicalURL.standardizedFileURL.path
                < right.record.canonicalURL.standardizedFileURL.path
        }
        return AppLibrarySnapshot(revision: catalog.revision, entries: entries, counts: counts)
    }
}
