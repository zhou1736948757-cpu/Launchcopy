import CoreGraphics

public enum AppGridLayoutMode: Equatable, Sendable { case ordinary, search }

public struct AppGridGeometry: Equatable, Sendable {
    public let columns: Int
    public let cellHeight: CGFloat
    public let spacing: CGFloat
    public let area: CGRect
    public let rowCount: Int

    public init(bounds: CGRect, itemCount: Int, mode: AppGridLayoutMode,
                columns: Int = 5, rows: Int = 7, cellHeight: CGFloat = 88,
                preferredSpacing: CGFloat = 16, sideInset: CGFloat = 24,
                topInset: CGFloat = 96, bottomInset: CGFloat = 24) {
        self.columns = max(columns, 1)
        let safeWidth = max(bounds.width - sideInset * 2, 0)
        let safeHeight = max(bounds.height - topInset - bottomInset, 0)
        self.area = CGRect(x: bounds.minX + sideInset, y: bounds.minY + bottomInset,
                           width: safeWidth, height: safeHeight)
        let rows = mode == .ordinary ? max(rows, 1) : max(1, Int(ceil(Double(max(itemCount, 0)) / Double(self.columns))))
        self.rowCount = rows
        // Shrink cells only when the rows cannot fit even with zero spacing.
        self.cellHeight = min(max(cellHeight, 0), safeHeight / CGFloat(rows))
        let maxSpacing = rows > 1 ? max((safeHeight - CGFloat(rows) * self.cellHeight) / CGFloat(rows - 1), 0) : 0
        self.spacing = min(max(preferredSpacing, 0), maxSpacing)
    }

    public func frame(for index: Int, itemCount: Int) -> CGRect? {
        guard index >= 0, index < itemCount, index / columns < rowCount,
              area.width > 0, area.height > 0 else { return nil }
        let row = index / columns
        let column = index % columns
        let rowItems = min(columns, itemCount - row * columns)
        let effectiveSpacing = spacing
        let tileWidth = max((area.width - CGFloat(columns - 1) * effectiveSpacing) / CGFloat(columns), 0)
        let rowWidth = CGFloat(rowItems) * tileWidth + CGFloat(max(rowItems - 1, 0)) * effectiveSpacing
        let x = area.minX + (area.width - rowWidth) / 2 + CGFloat(column) * (tileWidth + effectiveSpacing)
        let occupiedHeight = CGFloat(rowCount) * cellHeight + CGFloat(max(rowCount - 1, 0)) * effectiveSpacing
        let verticalOrigin = area.minY + max((area.height - occupiedHeight) / 2, 0)
        let y = verticalOrigin + occupiedHeight - CGFloat(row + 1) * cellHeight - CGFloat(row) * effectiveSpacing
        return CGRect(x: x, y: y, width: tileWidth, height: cellHeight)
    }
}
