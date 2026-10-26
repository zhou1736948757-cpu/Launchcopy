import AppGridUI
import Foundation

/// Ephemeral only; queries and selections are never persisted or logged.
struct AppLibraryGridReturnContext: Equatable, Sendable {
    let query: String
    let page: Int
    let selection: AppGridFocusIdentity?
    let searchWasFocused: Bool
}

enum AppLibraryGridReturnPolicy {
    static func resolve(_ context: AppLibraryGridReturnContext,
                        in layout: AppGridFocusLayout) -> (page: Int, selection: AppGridFocusIdentity?) {
        guard layout.pageCount > 0 else { return (0, nil) }
        let page = min(max(0, context.page), layout.pageCount - 1)
        guard let selected = context.selection else { return (page, nil) }
        if let entry = selected.entryIdentity, let position = layout.position(of: entry) {
            return (position.page, .init(catalogRevision: layout.revision,
                pageIndex: position.page, slotIndex: position.slot, entryIdentity: entry))
        }
        // A removed/hidden anchor uses the closest valid slot on the clamped
        // former page, then first-valid. Never reuse its stale identity/revision.
        guard let last = layout.lastValidSlot(on: page) else { return (page, layout.firstValidIdentity()) }
        let slot = min(max(0, selected.slotIndex), last)
        return (page, .init(catalogRevision: layout.revision, pageIndex: page, slotIndex: slot,
                           entryIdentity: layout.validEntry(page: page, slot: slot)))
    }
}
