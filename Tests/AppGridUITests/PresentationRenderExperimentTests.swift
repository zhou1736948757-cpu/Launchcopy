import AppKit
import QuartzCore
import XCTest

final class PresentationRenderExperimentTests: XCTestCase {
    func testCompareCacheDisplayAndPresentationRender() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 180),
            styleMask: .borderless,
            backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        let view = SolidView(frame: NSRect(x: 20, y: 20, width: 100, height: 80))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.red.cgColor
        window.contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView?.addSubview(view)
        window.orderOut(nil)
        window.displayIfNeeded()

        let modelRep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: modelRep)
        let modelBounds = opaqueBounds(modelRep)
        view.layer?.setAffineTransform(CGAffineTransform(translationX: 30, y: 0).scaledBy(x: 0.5, y: 0.5))
        let transformedRep = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: transformedRep)
        let transformedBounds = opaqueBounds(transformedRep)
        view.layer?.setAffineTransform(.identity)

        let start = CGAffineTransform(translationX: 30, y: 0).scaledBy(x: 0.5, y: 0.5)
        let animation = CABasicAnimation(keyPath: "transform")
        animation.fromValue = CATransform3DMakeAffineTransform(start)
        animation.toValue = CATransform3DMakeAffineTransform(.identity)
        animation.duration = 2
        animation.beginTime = CACurrentMediaTime()
        view.layer?.add(animation, forKey: "experiment")
        RunLoop.main.run(until: Date().addingTimeInterval(0.35))

        guard let presentation = view.layer?.presentation() else {
            XCTFail("presentation layer unavailable")
            return
        }
        let cached = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: cached)
        let rendered = try XCTUnwrap(renderPresentation(presentation, size: view.bounds.size))

        let cachedBounds = opaqueBounds(cached)
        let renderedBounds = opaqueBounds(rendered)
        print("RENDER_EXPERIMENT reps model=\(modelRep.pixelsWide)x\(modelRep.pixelsHigh) \(String(describing: modelBounds)) transformed=\(transformedRep.pixelsWide)x\(transformedRep.pixelsHigh) \(String(describing: transformedBounds)) presentation=\(presentation.affineTransform()) cached=\(cached.pixelsWide)x\(cached.pixelsHigh) \(String(describing: cachedBounds)) rendered=\(rendered.pixelsWide)x\(rendered.pixelsHigh) \(String(describing: renderedBounds))")
        XCTAssertNotNil(cachedBounds)
        XCTAssertNotNil(renderedBounds)
        window.close()
    }

    private func renderPresentation(_ layer: CALayer, size: NSSize) -> NSBitmapImageRep? {
        let width = max(Int(size.width), 1)
        let height = max(Int(size.height), 1)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: 0,
            bitsPerPixel: 0) else { return nil }
        guard let context = NSGraphicsContext(bitmapImageRep: rep)?.cgContext else { return nil }
        context.clear(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        layer.render(in: context)
        return rep
    }

    private func opaqueBounds(_ rep: NSBitmapImageRep) -> CGRect? {
        var result: CGRect?
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.05 else { continue }
                let point = NSPoint(x: x, y: y)
                result = result.map { $0.union(NSRect(origin: point, size: .zero)) }
                    ?? NSRect(origin: point, size: .zero)
            }
        }
        return result
    }
}

private final class SolidView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.red.setFill()
        dirtyRect.fill()
    }
}
