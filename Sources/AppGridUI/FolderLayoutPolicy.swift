import AppKit

/// One applied folder layout. Only the panel uses overlay coordinates; every
/// other frame is panel-local, in AppKit's unflipped coordinate system.
public struct FolderLayoutSnapshot: Equatable, Sendable {
    public let panelFrame: CGRect
    public let titleFrame: CGRect
    public let gridFrame: CGRect
    public let pageIndicatorFrame: CGRect
    public let previousButtonFrame: CGRect
    public let nextButtonFrame: CGRect
    public let insufficientSpaceMessageFrame: CGRect
    public let closeButtonFrame: CGRect
    public let cellFrames: [CGRect]
    public let columns: Int
    public let rows: Int
    public let canPresentMembers: Bool

    /// Unavailable layouts retain a safe paging divisor but expose no slots.
    public var capacity: Int { max(columns * rows, 1) }
}

/// Bounded folder-only geometry, independent of membership, label visibility,
/// screen discovery and backing scale. The caller supplies safe logical points.
public enum FolderLayoutPolicy {
    public static func resolve(usableBounds: CGRect,
                               appearance: GridItemAppearance) -> FolderLayoutSnapshot {
        let bounds = sanitized(usableBounds)
        let appearance = appearance.isValid ? appearance : .default
        let gap: CGFloat = 16
        let horizontalPadding: CGFloat = 48
        let verticalChrome: CGFloat = 132
        let minimumCellWidth: CGFloat = 112
        // Reuse the actual caption line measurement, including the established
        // default 14pt box. Members are app cells, with no folder-count caption.
        let captionHeight = GridItemContentGeometry(
            bounds: CGRect(x: 0, y: 0, width: minimumCellWidth, height: 256),
            appearance: appearance, showsLabels: true, isFolderCell: false
        ).nameFrame.height
        let minimumCellHeight = max(96, CGFloat(appearance.preferredIconSide) + captionHeight + 22)

        let insetX = min(24, bounds.width / 2)
        let insetY = min(24, bounds.height / 2)
        let maximumWidth = min(900, max(bounds.width - insetX * 2, 0))
        let maximumHeight = min(620, max(bounds.height - insetY * 2, 0))
        // Search only the bounded policy counts; never convert arbitrary input
        // dimensions to Int, even for huge or malformed rectangles.
        let fittingColumns = (1...5).reversed().first {
            horizontalPadding + CGFloat($0) * minimumCellWidth + CGFloat($0 - 1) * gap <= maximumWidth
        }
        let fittingRows = (1...3).reversed().first {
            verticalChrome + CGFloat($0) * minimumCellHeight + CGFloat($0 - 1) * gap <= maximumHeight
        }
        let canPresent = fittingColumns != nil && fittingRows != nil
        let columns = canPresent ? (fittingColumns ?? 1) : 1
        let rows = canPresent ? (fittingRows ?? 1) : 1
        let minimumWidth = horizontalPadding + CGFloat(columns) * minimumCellWidth + CGFloat(columns - 1) * gap
        let minimumHeight = verticalChrome + CGFloat(rows) * minimumCellHeight + CGFloat(rows - 1) * gap
        let width = min(maximumWidth, max(bounds.width * 0.60, minimumWidth))
        let height = min(maximumHeight, max(bounds.height * 0.65, minimumHeight))
        let panel = CGRect(x: bounds.origin.x + (bounds.width - width) / 2,
                           y: bounds.origin.y + (bounds.height - height) / 2,
                           width: width, height: height)

        let localBounds = CGRect(x: 0, y: 0, width: width, height: height)
        let horizontalInset = min(24, width / 2)
        let gridBottom = min(68, height)
        let gridTop = max(height - 64, gridBottom)
        let grid = CGRect(x: horizontalInset, y: gridBottom,
                          width: max(width - 48, 0), height: gridTop - gridBottom)
        var title = bounded(x: horizontalInset, y: max(height - 52, 0),
                            width: max(width - 48, 0), height: 40, in: localBounds)
        let indicator = bounded(x: 0, y: 8, width: width, height: 20, in: localBounds)
        let previous = bounded(x: 24, y: 8, width: 40, height: 24, in: localBounds)
        let next = bounded(x: max(width - 64, 0), y: 8, width: 40, height: 24, in: localBounds)

        // Unavailable chrome has its own shared, non-overlapping regions. At very
        // short heights the message takes the title's place; Close remains first.
        let close = bounded(x: max((width - min(120, max(width - 16, 0))) / 2, 0),
                            y: min(8, height), width: min(120, max(width - 16, 0)),
                            height: min(28, max(height - 16, 0)), in: localBounds)
        var message = CGRect.zero
        if !canPresent {
            let bottom = min(close.maxY + 8, height)
            let top = max(height - 12, bottom)
            if top - bottom < 104 { title = .zero }
            let messageTop = title.isEmpty ? top : max(title.minY - 8, bottom)
            let freeHeight = max(messageTop - bottom, 0)
            let messageHeight = min(48, freeHeight)
            message = bounded(x: min(16, width / 2), y: bottom + (freeHeight - messageHeight) / 2,
                              width: max(width - 32, 0), height: messageHeight, in: localBounds)
        }

        var cells: [CGRect] = []
        if canPresent {
            let cellWidth = (grid.width - CGFloat(columns - 1) * gap) / CGFloat(columns)
            let cellHeight = (grid.height - CGFloat(rows - 1) * gap) / CGFloat(rows)
            cells = (0..<(columns * rows)).map { index in
                let column = index % columns
                let row = index / columns
                return CGRect(x: grid.minX + CGFloat(column) * (cellWidth + gap),
                              y: grid.maxY - cellHeight - CGFloat(row) * (cellHeight + gap),
                              width: cellWidth, height: cellHeight)
            }
        }
        return FolderLayoutSnapshot(panelFrame: panel, titleFrame: title, gridFrame: grid,
                                    pageIndicatorFrame: indicator, previousButtonFrame: previous,
                                    nextButtonFrame: next,
                                    insufficientSpaceMessageFrame: message, closeButtonFrame: close,
                                    cellFrames: cells,
                                    columns: columns, rows: rows, canPresentMembers: canPresent)
    }

    /// Invalid origins become zero; invalid/negative/overflowing extents become
    /// zero independently, preserving any remaining meaningful safe geometry.
    private static func sanitized(_ rect: CGRect) -> CGRect {
        let x = rect.origin.x.isFinite ? rect.origin.x : 0
        let y = rect.origin.y.isFinite ? rect.origin.y : 0
        let width = rect.size.width.isFinite && rect.size.width >= 0
            && (x + rect.size.width).isFinite ? rect.size.width : 0
        let height = rect.size.height.isFinite && rect.size.height >= 0
            && (y + rect.size.height).isFinite ? rect.size.height : 0
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func bounded(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
                                in bounds: CGRect) -> CGRect {
        let x = min(max(x, 0), bounds.width)
        let y = min(max(y, 0), bounds.height)
        return CGRect(x: x, y: y, width: min(max(width, 0), bounds.width - x),
                      height: min(max(height, 0), bounds.height - y))
    }
}
