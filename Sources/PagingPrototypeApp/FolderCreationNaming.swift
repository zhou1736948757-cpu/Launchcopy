import AppCatalogCore
import AppGridUI
import LauncherLocalization

/// Reads only committed value snapshots. No disk, network, or UI work belongs in a drop.
enum FolderCreationNaming {
    static func title(target: PersistentAppReference, source: PersistentAppReference,
                      layout: PersistentWorkspaceLayout, catalog: CatalogSnapshot,
                      libraryPreferences: AppLibraryPreferences,
                      strings: LocalizedStrings?) -> String {
        func category(for reference: PersistentAppReference) -> AppLibraryCategory? {
            guard let record = catalog.records.first(where: { reference.matches(record: $0) }) else { return nil }
            return libraryPreferences.category(for: record)
        }
        let categoryTitles = Dictionary(uniqueKeysWithValues: AppLibraryCategory.allCases.map { category in
            let key = AppLibraryCategoryLabels.key(for: category)
            return (category, strings?.libraryText(key) ?? key.englishFallback)
        })
        return FolderCreationTitle.make(targetCategory: category(for: target),
            sourceCategory: category(for: source), categoryTitles: categoryTitles,
            fallbackTitle: strings?.gridText(.newFolderFallbackTitle) ?? GridTextKey.newFolderFallbackTitle.englishFallback,
            existingTitles: layout.folders.map(\.title))
    }
}
