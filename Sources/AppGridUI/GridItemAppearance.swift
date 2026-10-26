import AppKit

/// Display preferences only: these values never change icon keys or item identity.
public struct GridItemAppearance: Codable, Equatable, Sendable {
    public var preferredIconSide: Int
    public var appLabelFontSize: Int

    public init(preferredIconSide: Int = 48, appLabelFontSize: Int = 11) {
        self.preferredIconSide = preferredIconSide
        self.appLabelFontSize = appLabelFontSize
    }

    public var isValid: Bool {
        (32...96).contains(preferredIconSide) && (9...16).contains(appLabelFontSize)
    }

    public static let `default` = GridItemAppearance()
}

/// Content placement is explicit; direct callers retain standard geometry.
public enum GridItemLayoutContext: Equatable, Sendable {
    case standard
    case mainGrid
    case folderGrid
}

/// Shared cell-local geometry for item views and drawing-only drag previews.
/// Frames use AppKit's unflipped coordinates. Hidden caption frames remain available
/// for deterministic visibility toggles, but do not reserve icon space.
public struct GridItemContentGeometry: Equatable, Sendable {
    public let iconFrame: CGRect
    public let nameFrame: CGRect
    public let countFrame: CGRect

    public init(bounds: CGRect, appearance: GridItemAppearance,
                showsLabels: Bool, isFolderCell: Bool,
                context: GridItemLayoutContext = .standard,
                iconSideLimit: CGFloat? = nil) {
        let appearance = appearance.isValid ? appearance : .default
        var width = bounds.size.width.isFinite ? max(bounds.size.width, 0) : 0
        var height = bounds.size.height.isFinite ? max(bounds.size.height, 0) : 0
        let x = bounds.origin.x.isFinite ? bounds.origin.x : 0
        let y = bounds.origin.y.isFinite ? bounds.origin.y : 0

        // Preserve the established default line box. Other sizes use the system
        // font's readable line metrics, rounded up with one point of breathing room.
        let font = NSFont.systemFont(ofSize: CGFloat(appearance.appLabelFontSize))
        let lineHeight = appearance.appLabelFontSize == 11
            ? CGFloat(14) : ceil(font.ascender - font.descender + font.leading) + 1

        if context != .standard {
            // Reject overflowing extents independently without changing standard behavior.
            if !(x + width).isFinite { width = 0 }
            if !(y + height).isFinite { height = 0 }
            let isFolderMember = context == .folderGrid
            let padding = min(CGFloat(isFolderMember ? 6 : 2), height / 2)
            let contentHeight = max(height - 2 * padding, 0)
            let nameHeight = min(lineHeight, contentHeight)
            let countHeight = min(CGFloat(12), max(contentHeight - nameHeight, 0))
            let captionSpace = showsLabels ? nameHeight + (isFolderCell ? countHeight : 0) : 0
            let available = max(contentHeight - captionSpace, 0)
            let gap = captionSpace > 0 ? min(CGFloat(isFolderMember ? 6 : 4), available) : 0
            // A durable preview can retain the source's actual fractional fit
            // without altering its saved integer preference or caption spacing.
            let preferredSide = CGFloat(appearance.preferredIconSide)
            let sideLimit = iconSideLimit.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil } ?? preferredSide
            let side = min(preferredSide, sideLimit, width, max(available - gap, 0))
            let stackHeight = captionSpace + gap + side
            let bottom = y + padding + max((contentHeight - stackHeight) / 2, 0)
            let captionY = showsLabels ? bottom : y + padding
            let captionX = x + min(CGFloat(2), width / 2)
            let captionWidth = max(width - 4, 0)
            nameFrame = CGRect(x: captionX, y: captionY, width: captionWidth, height: nameHeight)
            countFrame = CGRect(x: captionX, y: captionY + nameHeight,
                                width: captionWidth,
                                height: min(countHeight, max(y + height - padding - nameFrame.maxY, 0)))
            iconFrame = CGRect(x: x + (width - side) / 2,
                               y: bottom + captionSpace + gap, width: side, height: side)
            return
        }

        let nameHeight = min(lineHeight, height)
        let countHeight = min(CGFloat(12), max(height - nameHeight, 0))
        let captionX = x + min(CGFloat(2), width / 2)
        let captionWidth = max(width - 4, 0)
        nameFrame = CGRect(x: captionX, y: y, width: captionWidth, height: nameHeight)
        countFrame = CGRect(x: captionX, y: y + nameHeight,
                            width: captionWidth, height: countHeight)

        let captionSpace = showsLabels ? nameHeight + (isFolderCell ? countHeight : 0) : 0
        let topInset = min(CGFloat(12), height)
        let available = max(height - topInset - captionSpace, 0)
        let gap = captionSpace > 0 ? min(CGFloat(2), available) : 0
        let side = min(CGFloat(appearance.preferredIconSide), width, max(available - gap, 0))
        // A cell too short even for captions has an empty icon above the caption
        // stack. Both that empty frame and the compressed captions stay bounded.
        iconFrame = CGRect(x: x + (width - side) / 2,
                           y: y + max(captionSpace, height - topInset - side),
                           width: side, height: side)
    }
}
