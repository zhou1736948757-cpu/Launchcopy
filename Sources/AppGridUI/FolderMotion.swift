import AppKit

/// Pure motion primitives for FolderOverlayView. Wiring and logical lifetime remain in the owner.
public struct FolderMotionState: Equatable, Sendable {
    public let generation: UInt64
    public let opacity: CGFloat
    public let scale: CGFloat
    public let displacement: CGFloat

    public init(generation: UInt64, opacity: CGFloat, scale: CGFloat, displacement: CGFloat) {
        self.generation = generation
        self.opacity = opacity
        self.scale = scale
        self.displacement = displacement
    }

    public static func entering(generation: UInt64, params: FolderOverlayView.MotionParams) -> Self {
        Self(generation: generation, opacity: 0, scale: params.scale, displacement: params.displacement)
    }

    public static func settled(generation: UInt64) -> Self {
        Self(generation: generation, opacity: 1, scale: 1, displacement: 0)
    }
}

/// Sanitized layer state used when a folder transition is interrupted.
public struct FolderMotionPresentation: Equatable {
    public let opacity: Float
    public let transform: CGAffineTransform

    public init(opacity: Float, transform: CGAffineTransform) {
        self.opacity = opacity
        self.transform = transform
    }

    public static let settled = Self(opacity: 1, transform: .identity)

    /// Clamps values from Core Animation and falls back when a layer exposes a
    /// non-finite value during removal or reparenting.
    public static func sanitized(opacity: Float, transform: CGAffineTransform,
                                 fallback: Self = .settled) -> Self {
        let fallbackOpacity = safeOpacity(fallback.opacity, fallback: 1)
        let fallbackTransform = safeTransform(fallback.transform, fallback: .identity)
        let safeOpacityValue = opacity.isFinite
            ? min(max(opacity, 0), 1)
            : fallbackOpacity
        let safeTransformValue = safeTransform(transform, fallback: fallbackTransform)
        return Self(opacity: safeOpacityValue, transform: safeTransformValue)
    }

    private static func safeOpacity(_ value: Float, fallback: Float) -> Float {
        guard value.isFinite else { return fallback }
        return min(max(value, 0), 1)
    }

    private static func safeTransform(_ value: CGAffineTransform,
                                       fallback: CGAffineTransform) -> CGAffineTransform {
        let components = [value.a, value.b, value.c, value.d, value.tx, value.ty]
        guard components.allSatisfy({ $0.isFinite }) else { return fallback }
        return CGAffineTransform(
            a: clamp(value.a, limit: 4),
            b: clamp(value.b, limit: 4),
            c: clamp(value.c, limit: 4),
            d: clamp(value.d, limit: 4),
            tx: clamp(value.tx, limit: 4096),
            ty: clamp(value.ty, limit: 4096))
    }

    private static func clamp(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        min(max(value, -limit), limit)
    }
}

/// Generation checks prevent an old completion from mutating a newer folder transition.
public enum FolderMotionGate {
    public static func accepts(completionGeneration: UInt64, currentGeneration: UInt64) -> Bool {
        completionGeneration == currentGeneration
    }
}

/// Resolves the optional source-cell anchor used by pointer Folder transitions.
///
/// A source frame is only a visual hint. If it is detached, stale, non-finite, or
/// outside the overlay's visible host, the caller must still run the opacity
/// transition with an identity transform rather than dropping the transition.
public enum FolderMotionGeometry {
    public static func isReliableSourceFrame(_ sourceFrame: NSRect?, visualFrame: NSRect) -> Bool {
        guard let sourceFrame,
              isUsable(sourceFrame),
              isUsable(visualFrame) else {
            return false
        }
        return visualFrame.intersects(sourceFrame)
    }

    /// Maps the panel into a uniformly fitted miniature centered on the source glyph.
    /// All rectangles use the panel parent's coordinates. The actual layer anchor is
    /// explicit because AppKit-backed layers need not pivot at their frame center.
    public static func sourceTransform(sourceFrame: NSRect?, panelFrame: NSRect,
                                       visibleBounds: NSRect,
                                       anchorPoint: CGPoint) -> CGAffineTransform {
        guard let sourceFrame,
              isReliableSourceFrame(sourceFrame, visualFrame: visibleBounds),
              isUsable(panelFrame),
              anchorPoint.x.isFinite, anchorPoint.y.isFinite,
              (0...1).contains(anchorPoint.x), (0...1).contains(anchorPoint.y) else {
            return .identity
        }
        let scale = min(1, min(sourceFrame.width / panelFrame.width,
                               sourceFrame.height / panelFrame.height))
        guard scale.isFinite, scale > 0 else { return .identity }
        let pivot = CGPoint(x: panelFrame.minX + panelFrame.width * anchorPoint.x,
                            y: panelFrame.minY + panelFrame.height * anchorPoint.y)
        let dx = sourceFrame.midX - pivot.x - scale * (panelFrame.midX - pivot.x)
        let dy = sourceFrame.midY - pivot.y - scale * (panelFrame.midY - pivot.y)
        guard dx.isFinite, dy.isFinite else { return .identity }
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: dx, ty: dy)
    }

    private static func isUsable(_ rect: NSRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite &&
            rect.size.width.isFinite && rect.size.height.isFinite &&
            rect.width > 0 && rect.height > 0 &&
            rect.maxX.isFinite && rect.maxY.isFinite && rect.midX.isFinite && rect.midY.isFinite
    }
}
