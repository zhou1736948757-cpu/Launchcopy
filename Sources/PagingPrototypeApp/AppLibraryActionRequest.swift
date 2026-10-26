import AppCatalogCore
import Foundation

/// A Library selection is not a grid cell. Preserve the actually displayed
/// canonical identity/URL/revision and owner generation for execution-time checks.
struct AppLibraryActionRequest: Equatable, Sendable {
    let appID: AppID
    let canonicalURL: URL
    let catalogRevision: CatalogRevision
    let generation: UInt64

    init(record: AppRecord, catalogRevision: CatalogRevision, generation: UInt64) {
        appID = record.id
        canonicalURL = record.canonicalURL
        self.catalogRevision = catalogRevision
        self.generation = generation
    }
}
