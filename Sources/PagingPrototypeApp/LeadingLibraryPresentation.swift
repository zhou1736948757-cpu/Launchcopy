import AppKit

/// Only the two sibling panes move; wallpaper and canonical paging stay untouched.
/// Every write belongs to the finger/frame pump, never an implicit CA animation.
@MainActor
enum LeadingLibraryPresentation {
    static func render(offset: Double, width: CGFloat, reduceMotion: Bool,
                       gridViews: [NSView], libraryView: NSView?) {
        guard offset.isFinite, width.isFinite, width >= 0 else { return }
        withoutImplicitAnimations {
            for view in gridViews {
                prepare(view)
                view.layer?.setAffineTransform(reduceMotion ? .identity :
                    CGAffineTransform(translationX: CGFloat(1 - offset) * width, y: 0))
                view.layer?.opacity = reduceMotion ? Float(min(1, max(0, offset))) : 1
            }
            if let libraryView {
                prepare(libraryView)
                libraryView.layer?.setAffineTransform(reduceMotion ? .identity :
                    CGAffineTransform(translationX: -CGFloat(offset) * width, y: 0))
                libraryView.layer?.opacity = reduceMotion ? Float(min(1, max(0, 1 - offset))) : 1
            }
        }
    }

    static func reset(gridViews: [NSView], libraryView: NSView?) {
        withoutImplicitAnimations {
            for view in gridViews + [libraryView].compactMap({ $0 }) {
                view.layer?.setAffineTransform(.identity)
                view.layer?.opacity = 1
            }
        }
    }

    /// Idempotent layer creation only; state/geometry/focus remain untouched.
    @discardableResult
    static func prepareLayerBackings(for views: [NSView]) -> Int {
        var count = 0
        withoutImplicitAnimations {
            for view in views where !view.wantsLayer {
                view.wantsLayer = true
                count += 1
            }
        }
        return count
    }

    private static func prepare(_ view: NSView) {
        if !view.wantsLayer { view.wantsLayer = true }
    }

    private static func withoutImplicitAnimations(_ changes: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        changes()
    }
}
