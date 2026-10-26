import Foundation

/// Shared by actual layout and pre-layout icon admission. A mode/width change must
/// never leave background work using a different visibility threshold than the UI.
struct LibraryHorizontalLayout {
    static let margin: CGFloat = 16
    let availableWidth: CGFloat
    let isCompact: Bool
    let sidebarWidth: CGFloat
    let contentX: CGFloat
    let contentWidth: CGFloat
    private let showsGallery: Bool

    init(boundsWidth: CGFloat, showsGallery: Bool) {
        self.showsGallery = showsGallery
        availableWidth = max(0, boundsWidth - Self.margin * 2)
        isCompact = availableWidth < 420
        sidebarWidth = isCompact ? 0 : min(200, max(130, availableWidth * 0.23))
        contentX = showsGallery ? Self.margin : Self.margin + sidebarWidth + (isCompact ? 0 : 12)
        contentWidth = max(0, Self.margin + availableWidth - contentX)
    }

    func showsResultsBesideDetails(detailsOpen: Bool) -> Bool {
        detailsOpen && contentWidth >= 600
    }

    func allowsResultIcons(detailsOpen: Bool) -> Bool {
        !showsGallery && (!detailsOpen || showsResultsBesideDetails(detailsOpen: detailsOpen))
    }
}
