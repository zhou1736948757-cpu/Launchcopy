import AppKit

/// Main-grid-only viewport admission. A rejected viewport keeps its logical
/// capacity; the composition root presents a message instead of shrinking it.
public enum MainGridReadability {
    public static let minimumIconSide: CGFloat = 24

    public static func isReadable(bounds: CGRect, capacity: MainGridCapacity,
                                  appearance: GridItemAppearance, showsLabels: Bool) -> Bool {
        guard bounds.width.isFinite, bounds.height.isFinite,
              bounds.minX.isFinite, bounds.minY.isFinite,
              bounds.width > 0, bounds.height > 0, appearance.isValid else { return false }
        // Fewer occupied search rows can increase spacing, which also reduces
        // horizontal cell width. Full ordinary geometry is not a lower bound.
        // Probe each possible search row count (at most eight), not every item
        // or a per-frame scan. Counts sharing a row count share cell dimensions.
        let ordinary = MainGridLayoutMetrics.geometry(bounds: bounds, itemCount: capacity.itemsPerPage,
            mode: .ordinary, capacity: capacity, appearance: appearance)
        guard fits(ordinary, itemCount: capacity.itemsPerPage, appearance: appearance,
                   showsLabels: showsLabels) else { return false }
        for rows in 1...capacity.rows {
            let count = (rows - 1) * capacity.columns + 1
            let search = MainGridLayoutMetrics.geometry(bounds: bounds, itemCount: count,
                mode: .search, capacity: capacity, appearance: appearance)
            guard fits(search, itemCount: count, appearance: appearance,
                       showsLabels: showsLabels) else { return false }
        }
        return true
    }

    private static func fits(_ grid: AppGridGeometry, itemCount: Int,
                             appearance: GridItemAppearance, showsLabels: Bool) -> Bool {
        guard let frame = grid.frame(for: 0, itemCount: itemCount) else { return false }
        // Include a folder's count line even if no folder currently exists, so
        // creating one cannot turn a previously admitted layout unreadable.
        let cell = GridItemContentGeometry(bounds: CGRect(origin: .zero, size: frame.size),
                                           appearance: appearance, showsLabels: showsLabels,
                                           isFolderCell: true, context: .mainGrid)
        guard cell.iconFrame.width >= minimumIconSide,
              cell.iconFrame.height >= minimumIconSide else { return false }
        if showsLabels {
            let font = NSFont.systemFont(ofSize: CGFloat(appearance.appLabelFontSize))
            let line = appearance.appLabelFontSize == 11
                ? CGFloat(14) : ceil(font.ascender - font.descender + font.leading) + 1
            return cell.nameFrame.height >= line && cell.countFrame.height >= 12
                && cell.nameFrame.width >= minimumIconSide
        }
        return true
    }
}
