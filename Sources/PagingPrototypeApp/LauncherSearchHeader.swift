import AppKit

/// Shared native search styling and header geometry; query ownership remains separate.
enum LauncherSearchHeader {
    @MainActor
    static func configure(_ field: NSSearchField) {
        SearchFieldFocusPolicy.removeOutline(from: field)
        field.controlSize = .regular
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.recentsAutosaveName = nil
        field.maximumRecents = 0
    }

    static func frame(in bounds: NSRect, safeAreaTop: CGFloat = 0, flipped: Bool = false) -> NSRect {
        let width = min(CGFloat(300), max(0, bounds.width - 24))
        let height = min(CGFloat(28), max(0, bounds.height))
        let safeTop = safeAreaTop.isFinite ? max(0, safeAreaTop) : 0
        let topGap = min(safeTop + 12, max(0, bounds.height - height))
        return NSRect(x: bounds.midX - width / 2,
                      y: flipped ? bounds.minY + topGap : bounds.maxY - height - topGap,
                      width: width, height: height)
    }
}
