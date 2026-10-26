import AppCatalogCore
import Foundation

/// Pure management metadata and search policy; hidden apps and aliases use stable references.
/// These private keys and aliases must never enter diagnostics or telemetry.
/// Decoding preserves stored values; callers must check `isValid` before applying them.
public struct AppManagementPreferences: Codable, Equatable, Sendable {
    public var hiddenKeys: Set<String>
    public var aliases: [String: String]
    /// Default-off canonical identifier matching. Synthesized decoding requires this stored boolean.
    public var searchByBundleIdentifier: Bool

    public init(hiddenKeys: Set<String> = [], aliases: [String: String] = [:],
                searchByBundleIdentifier: Bool = false) {
        self.hiddenKeys = hiddenKeys
        self.aliases = aliases
        self.searchByBundleIdentifier = searchByBundleIdentifier
    }

    public static let `default` = AppManagementPreferences()

    public static func key(for record: AppRecord) -> String {
        PersistentAppReference.from(record: record).comparisonKey
    }

    /// Validates stored metadata without normalizing or discarding it.
    public var isValid: Bool {
        hiddenKeys.allSatisfy(Self.isValidKey)
            && aliases.allSatisfy { key, alias in
                Self.isValidKey(key) && Self.isValidAlias(alias)
            }
    }

    /// Either current identity key can retain hidden state from a path-only catalog record.
    public func isHidden(_ record: AppRecord) -> Bool {
        hiddenKeys.contains(Self.key(for: record))
            || hiddenKeys.contains(Self.pathKey(for: record))
    }

    public func displayName(for record: AppRecord) -> String {
        resolvedAlias(for: record) ?? record.displayName
    }

    /// The editable alias, including an older path-key fallback; nil means original name.
    public func alias(for record: AppRecord) -> String? { resolvedAlias(for: record) }

    /// Copies only the displayed name; canonical identity and launch/icon metadata survive.
    public func presentationRecord(for record: AppRecord) -> AppRecord {
        let name = displayName(for: record)
        guard name != record.displayName else { return record }
        return AppRecord(
            id: record.id,
            displayName: name,
            bundleIdentifier: record.bundleIdentifier,
            canonicalURL: record.canonicalURL,
            iconIdentity: record.iconIdentity,
            sourceRootPriority: record.sourceRootPriority,
            bundleMetadata: record.bundleMetadata
        )
    }

    /// Projects a stable subsequence without sorting or modifying the canonical catalog.
    public func visibleRecords(_ records: [AppRecord]) -> [AppRecord] {
        records.compactMap { record in
            isHidden(record) ? nil : presentationRecord(for: record)
        }
    }

    /// Search callers supply the canonical record so its original name remains searchable.
    public func matches(_ record: AppRecord, query: AppSearchQuery) -> Bool {
        guard !isHidden(record) else { return false }
        let matcher = AppSearchMatcher()
        if matcher.matches(record, query: query) { return true }
        if resolvedAlias(for: record) != nil,
           matcher.matches(presentationRecord(for: record), query: query) { return true }
        guard searchByBundleIdentifier,
              let identifier = record.bundleIdentifier, !identifier.isEmpty else { return false }
        let normalizedIdentifier = identifier.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: query.locale)
        return normalizedIdentifier.range(of: query.normalized, options: [.literal],
                                          locale: query.locale) != nil
    }

    /// Hide stores the preferred key; unhide clears both current identity keys.
    public func settingHidden(_ hidden: Bool, for record: AppRecord) -> Self {
        var updated = self
        let key = Self.key(for: record)
        if hidden {
            updated.hiddenKeys.insert(key)
        } else {
            updated.hiddenKeys.remove(key)
            updated.hiddenKeys.remove(Self.pathKey(for: record))
        }
        return updated
    }

    /// Nil or blank clears both current identity keys; an explicit alias replaces the path alias.
    /// Invalid input returns nil without changing this value.
    public func settingAlias(_ alias: String?, for record: AppRecord) -> Self? {
        let normalized = alias?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard normalized.isEmpty || Self.isValidAlias(normalized) else { return nil }
        var updated = self
        let key = Self.key(for: record)
        updated.aliases.removeValue(forKey: Self.pathKey(for: record))
        if normalized.isEmpty {
            updated.aliases.removeValue(forKey: key)
        } else {
            updated.aliases[key] = normalized
        }
        return updated
    }

    /// Read continuity for path-only records that gain a bundle ID, without migrating storage.
    private func resolvedAlias(for record: AppRecord) -> String? {
        aliases[Self.key(for: record)] ?? aliases[Self.pathKey(for: record)]
    }

    private static func pathKey(for record: AppRecord) -> String {
        PersistentAppReference.canonicalPath(
            PersistentAppReference.normalizedPath(record.canonicalURL)
        ).comparisonKey
    }

    private static func isValidKey(_ key: String) -> Bool {
        ["bundle:", "path:"].contains { prefix in
            key.hasPrefix(prefix) && key.count > prefix.count
        }
    }

    private static func isValidAlias(_ alias: String) -> Bool {
        !alias.isEmpty
            && alias == alias.trimmingCharacters(in: .whitespacesAndNewlines)
            && alias.count <= 128
            && !alias.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
    }
}
