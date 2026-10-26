import AppKit

/// Main-page sizing only. Folder panels keep their standard content geometry.
public enum MainGridLayoutMetrics {
    public static func preferredCellHeight(for appearance: GridItemAppearance) -> CGFloat {
        let appearance = appearance.isValid ? appearance : .default
        let captions = GridItemContentGeometry(
            bounds: CGRect(x: 0, y: 0, width: 256, height: 512),
            appearance: appearance, showsLabels: true, isFolderCell: true)
        return max(88, CGFloat(appearance.preferredIconSide)
                   + captions.nameFrame.height + captions.countFrame.height + 8)
    }

    public static func geometry(bounds: CGRect, itemCount: Int, mode: AppGridLayoutMode,
                                capacity: MainGridCapacity, appearance: GridItemAppearance,
                                preferredSpacing: CGFloat = 16) -> AppGridGeometry {
        AppGridGeometry(bounds: bounds, itemCount: itemCount, mode: mode,
                        columns: capacity.columns, rows: capacity.rows,
                        cellHeight: preferredCellHeight(for: appearance),
                        preferredSpacing: preferredSpacing)
    }

    /// A geometry projection, not a statement that a pending setting is displayed.
    public static func fittedIconSides(bounds: CGRect, capacity: MainGridCapacity,
                                       appearance: GridItemAppearance, showsLabels: Bool)
        -> (app: CGFloat, folder: CGFloat)? {
        guard bounds.width.isFinite, bounds.height.isFinite,
              bounds.minX.isFinite, bounds.minY.isFinite, appearance.isValid else { return nil }
        let grid = geometry(bounds: bounds, itemCount: capacity.itemsPerPage,
                            mode: .ordinary, capacity: capacity, appearance: appearance)
        guard let frame = grid.frame(for: 0, itemCount: capacity.itemsPerPage) else { return nil }
        let local = CGRect(origin: .zero, size: frame.size)
        let app = GridItemContentGeometry(bounds: local, appearance: appearance,
            showsLabels: showsLabels, isFolderCell: false, context: .mainGrid)
        let folder = GridItemContentGeometry(bounds: local, appearance: appearance,
            showsLabels: showsLabels, isFolderCell: true, context: .mainGrid)
        return (app.iconFrame.width, folder.iconFrame.width)
    }
}
