import AppCatalogCore
import Foundation

/// Pure preferences. Missing apps retain dormant overrides; no reads migrate storage.
/// Decoding preserves values for explicit `isValid` checks by the storage owner.
public struct AppLibraryPreferences: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var categoryOverrides: [String: AppLibraryCategory]

    public init(enabled: Bool = false, categoryOverrides: [String: AppLibraryCategory] = [:]) {
        self.enabled = enabled
        self.categoryOverrides = categoryOverrides
    }

    public static let `default` = AppLibraryPreferences()

    /// Same reference-key grammar as app management; no autonomous normalization.
    public var isValid: Bool {
        categoryOverrides.keys.allSatisfy { key in
            ["bundle:", "path:"].contains { prefix in
                key.hasPrefix(prefix) && key.count > prefix.count
            }
        }
    }

    public func manualCategory(for record: AppRecord) -> AppLibraryCategory? {
        categoryOverrides[Self.key(for: record)] ?? categoryOverrides[Self.pathKey(for: record)]
    }

    public func category(for record: AppRecord) -> AppLibraryCategory {
        manualCategory(for: record)
            ?? AppLibraryCategory(declaredIdentifier: record.bundleMetadata.declaredCategoryIdentifier)
    }

    /// Nil resets both current identities. Explicit choices replace a legacy path override.
    public func settingCategory(_ category: AppLibraryCategory?, for record: AppRecord) -> Self {
        var updated = self
        updated.categoryOverrides.removeValue(forKey: Self.pathKey(for: record))
        let key = Self.key(for: record)
        if let category {
            updated.categoryOverrides[key] = category
        } else {
            updated.categoryOverrides.removeValue(forKey: key)
        }
        return updated
    }

    private static func key(for record: AppRecord) -> String {
        PersistentAppReference.from(record: record).comparisonKey
    }

    private static func pathKey(for record: AppRecord) -> String {
        PersistentAppReference.canonicalPath(
            PersistentAppReference.normalizedPath(record.canonicalURL)
        ).comparisonKey
    }
}
