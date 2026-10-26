import AppKit

/// Native search rendering and editing, without an external or custom focus frame.
@MainActor
final class LibrarySearchField: NSSearchField {
    override init(frame: NSRect) {
        super.init(frame: frame)
        LauncherSearchHeader.configure(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
