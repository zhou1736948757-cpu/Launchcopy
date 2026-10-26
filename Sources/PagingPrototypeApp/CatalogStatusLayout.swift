import CoreGraphics

/// Uses only the existing footer gutter; never moves application or paging content.
enum CatalogStatusLayout {
    static func compactFrame(in bounds: CGRect, gridContentMinY: CGFloat,
                             pageDotsFrame: CGRect?, height preferredHeight: CGFloat,
                             gridContentMaxY: CGFloat? = nil, searchFrame: CGRect? = nil,
                             settingsFrame: CGRect? = nil) -> CGRect {
        guard bounds.width.isFinite, bounds.height.isFinite, bounds.minX.isFinite, bounds.minY.isFinite,
              bounds.maxX.isFinite, bounds.maxY.isFinite,
              bounds.width > 0, bounds.height > 0, gridContentMinY.isFinite,
              preferredHeight.isFinite, preferredHeight > 0 else { return .zero }
        let gutter = min(bounds.height, max(gridContentMinY - bounds.minY, 0))
        let height = min(gutter, preferredHeight)
        guard height > 0 else { return .zero }
        let inset = min(8, bounds.width / 2)
        let usable = CGRect(x: bounds.minX + inset, y: bounds.minY + (gutter - height) / 2,
                            width: max(bounds.width - 2 * inset, 0), height: height)
        var leadingEnd = usable.maxX
        var trailingStart = usable.minX
        if let dots = pageDotsFrame {
            guard dots.minX.isFinite, dots.minY.isFinite, dots.width.isFinite, dots.height.isFinite else { return .zero }
            if dots.intersects(usable) {
                leadingEnd = min(usable.maxX, max(usable.minX, dots.minX - 8))
                trailingStart = max(usable.minX, min(usable.maxX, dots.maxX + 8))
            }
        }
        let leadingWidth = max(leadingEnd - usable.minX, 0)
        let trailingWidth = max(usable.maxX - trailingStart, 0)
        let useTrailing = trailingWidth >= leadingWidth
        let width = min(360, useTrailing ? trailingWidth : leadingWidth)
        // Very narrow windows may leave no footer space beside the unchanged dot strip.
        // Use only the existing gap above the grid and below search/settings, never a cell.
        if width < 24, let gridTop = gridContentMaxY, gridTop.isFinite {
            let headerBottom = max(bounds.minY, gridTop) + 1
            let headerTop = min(bounds.maxY, searchFrame?.minY ?? bounds.maxY,
                                settingsFrame?.minY ?? bounds.maxY) - 1
            let headerHeight = min(preferredHeight, headerTop - headerBottom)
            if headerHeight.isFinite, headerHeight >= 16, usable.width > 0 {
                let headerWidth = min(360, usable.width)
                return CGRect(x: usable.maxX - headerWidth, y: headerBottom,
                              width: headerWidth, height: headerHeight)
            }
        }
        return CGRect(x: useTrailing ? usable.maxX - width : usable.minX,
                      y: usable.minY, width: width, height: height)
    }
}
