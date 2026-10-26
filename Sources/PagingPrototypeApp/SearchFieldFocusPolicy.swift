import AppKit

/// The user requested no blue outlines on either launcher search control.
/// Native caret, selection, editing and accessibility focus remain AppKit-owned.
@MainActor
enum SearchFieldFocusPolicy {
    static func removeOutline(from field: NSSearchField) {
        field.focusRingType = .none
        field.cell?.focusRingType = .none
    }
}
