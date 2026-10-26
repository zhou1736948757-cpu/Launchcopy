import AppCatalogCore

/// Finds the stored reference representing a catalog record without migrating it.
/// Reuse one resolver for batch queries against the same immutable layout.
/// Index construction is linear in layout entries and references; each query
/// normalizes one path and performs at most two dictionary lookups.
public struct WorkspaceAppReferenceResolver: Sendable {
    private struct IndexedReference: Sendable {
        let reference: PersistentAppReference
        let order: Int
    }

    private let referencesByKey: [String: IndexedReference]

    /// Indexes top-level apps first, then folders in canonical top-level order
    /// and members in stored order. The first matching reference wins across
    /// both bundle and path identities; neither identity kind has priority.
    public init(layout: PersistentWorkspaceLayout) {
        var referencesByKey: [String: IndexedReference] = [:]
        var order = 0
        func index(_ reference: PersistentAppReference) {
            let key = reference.comparisonKey
            if referencesByKey[key] == nil {
                referencesByKey[key] = IndexedReference(reference: reference, order: order)
            }
            order += 1
        }

        for entry in layout.topLevelOrder {
            if case .app(let reference) = entry { index(reference) }
        }

        let foldersByID = Dictionary(layout.folders.map { ($0.id, $0) },
                                     uniquingKeysWith: { first, _ in first })
        var indexedFolders = Set<FolderID>()
        for entry in layout.topLevelOrder {
            if case .folder(let id) = entry,
               indexedFolders.insert(id).inserted,
               let folder = foldersByID[id] {
                for member in folder.members { index(member) }
            }
        }
        // Valid layouts have no unlisted folders. Still retain their references
        // defensively when querying an unvalidated layout; never rewrite it.
        for folder in layout.folders where !indexedFolders.contains(folder.id) {
            for member in folder.members { index(member) }
        }
        self.referencesByKey = referencesByKey
    }

    /// Returns the existing stored reference, or nil if no reference matches.
    /// Matching is identical to PersistentAppReference.matches(record:), including
    /// an empty bundle ID and a saved path for a record that now has a bundle ID.
    public func reference(for record: AppRecord) -> PersistentAppReference? {
        let pathKey = PersistentAppReference.canonicalPath(
            PersistentAppReference.normalizedPath(record.canonicalURL)).comparisonKey
        let path = referencesByKey[pathKey]
        guard let bundleID = record.bundleIdentifier,
              let bundle = referencesByKey[PersistentAppReference.bundleID(bundleID).comparisonKey] else {
            return path?.reference
        }
        if let path, path.order < bundle.order { return path.reference }
        return bundle.reference
    }

    /// Convenience lookup for a single record. For many records, reuse init(layout:).
    public static func reference(for record: AppRecord,
                                 in layout: PersistentWorkspaceLayout) -> PersistentAppReference? {
        WorkspaceAppReferenceResolver(layout: layout).reference(for: record)
    }
}
