import AppKit
import XCTest
@testable import AppGridUI

final class FolderMotionTests: XCTestCase {
    func testEnteringStateUsesParams() {
        let state = FolderMotionState.entering(generation: 7, params: .standard)
        XCTAssertEqual(state, .init(generation: 7, opacity: 0, scale: 1, displacement: 0))
    }

    func testReduceMotionKeepsIdentityTransform() {
        let state = FolderMotionState.entering(generation: 2, params: .reduceMotion)
        XCTAssertEqual(state.scale, 1)
        XCTAssertEqual(state.displacement, 0)
        XCTAssertEqual(FolderOverlayView.MotionParams.reduceMotion.duration, 0.18)
    }

    func testSourceOriginContractRequiresFullGlyphTravelAndUniformFit() {
        let panel = NSRect(x: 100, y: 120, width: 700, height: 450)
        let glyph = NSRect(x: 30, y: 40, width: 48, height: 48)
        let transform = FolderMotionGeometry.sourceTransform(sourceFrame: glyph, panelFrame: panel,
            visibleBounds: NSRect(x: 0, y: 0, width: 1000, height: 900), anchorPoint: CGPoint(x: 0.5, y: 0.5))
        let pivot = NSPoint(x: panel.midX, y: panel.midY)
        let center = CGPoint(x: panel.midX - pivot.x, y: panel.midY - pivot.y).applying(transform)
        XCTAssertEqual(center.x + pivot.x, glyph.midX, accuracy: 0.0001)
        XCTAssertEqual(center.y + pivot.y, glyph.midY, accuracy: 0.0001)
        XCTAssertEqual(transform.a, min(glyph.width / panel.width, glyph.height / panel.height), accuracy: 0.0001)
    }

    func testStaleCompletionIsRejected() {
        XCTAssertTrue(FolderMotionGate.accepts(completionGeneration: 4, currentGeneration: 4))
        XCTAssertFalse(FolderMotionGate.accepts(completionGeneration: 3, currentGeneration: 4))
    }

    func testPresentationClampsFiniteLayerValues() {
        let presentation = FolderMotionPresentation.sanitized(
            opacity: 2,
            transform: CGAffineTransform(a: 9, b: -9, c: 6, d: -6, tx: 8_192, ty: -8_192))

        XCTAssertEqual(presentation.opacity, 1)
        XCTAssertEqual(presentation.transform.a, 4)
        XCTAssertEqual(presentation.transform.b, -4)
        XCTAssertEqual(presentation.transform.c, 4)
        XCTAssertEqual(presentation.transform.d, -4)
        XCTAssertEqual(presentation.transform.tx, 4_096)
        XCTAssertEqual(presentation.transform.ty, -4_096)
    }

    func testPresentationUsesFallbackForNonFiniteLayerValues() {
        let fallback = FolderMotionPresentation(
            opacity: 0.42,
            transform: CGAffineTransform(translationX: 12, y: -18))
        let presentation = FolderMotionPresentation.sanitized(
            opacity: .nan,
            transform: CGAffineTransform(
                a: .infinity, b: 0, c: 0, d: 1, tx: CGFloat.nan, ty: 0),
            fallback: fallback)

        XCTAssertEqual(presentation, fallback)
    }

    func testSourceOriginGeometryAcrossPositionsOriginsAndLayerAnchors() {
        let viewport = NSRect(x: 80, y: -40, width: 1600, height: 1000)
        let panel = NSRect(x: 350, y: 110, width: 800, height: 500)
        for anchor in [CGPoint.zero, CGPoint(x: 0.5, y: 0.5), CGPoint(x: 1, y: 1), CGPoint(x: 0.2, y: 0.8)] {
            for glyph in [NSRect(x: 90, y: -30, width: 48, height: 48),
                          NSRect(x: 1600, y: 880, width: 64, height: 32),
                          NSRect(x: 700, y: 420, width: 32, height: 64)] {
                let transform = FolderMotionGeometry.sourceTransform(sourceFrame: glyph,
                    panelFrame: panel, visibleBounds: viewport, anchorPoint: anchor)
                let pivot = CGPoint(x: panel.minX + panel.width * anchor.x,
                                    y: panel.minY + panel.height * anchor.y)
                let mapped = panel.offsetBy(dx: -pivot.x, dy: -pivot.y).applying(transform)
                    .offsetBy(dx: pivot.x, dy: pivot.y)
                XCTAssertEqual(mapped.midX, glyph.midX, accuracy: 0.0001)
                XCTAssertEqual(mapped.midY, glyph.midY, accuracy: 0.0001)
                XCTAssertLessThanOrEqual(mapped.width, glyph.width + 0.0001)
                XCTAssertLessThanOrEqual(mapped.height, glyph.height + 0.0001)
                XCTAssertEqual(mapped.width / mapped.height, panel.width / panel.height, accuracy: 0.0001)
                XCTAssertEqual(transform.a, transform.d)
                XCTAssertEqual(transform.b, 0); XCTAssertEqual(transform.c, 0)
            }
        }
    }

    func testInvalidAndMissingSourceGeometryFallsBackToIdentity() {
        let viewport = NSRect(x: 0, y: 0, width: 1200, height: 900)
        let panel = NSRect(x: 100, y: 100, width: 800, height: 600)
        for source: NSRect? in [nil, .zero, NSRect(x: CGFloat.nan, y: 20, width: 48, height: 48),
                                NSRect(x: 1300, y: 10, width: 48, height: 48),
                                NSRect(x: CGFloat.greatestFiniteMagnitude, y: 0,
                                       width: CGFloat.greatestFiniteMagnitude, height: 48)] {
            XCTAssertEqual(FolderMotionGeometry.sourceTransform(sourceFrame: source, panelFrame: panel,
                visibleBounds: viewport, anchorPoint: .zero), .identity)
        }
        for badPanel in [NSRect.zero, NSRect(x: 10, y: 0, width: CGFloat.infinity, height: 90)] {
            XCTAssertEqual(FolderMotionGeometry.sourceTransform(sourceFrame: NSRect(x: 20, y: 30, width: 48, height: 48),
                panelFrame: badPanel, visibleBounds: viewport, anchorPoint: .zero), .identity)
        }
        for badAnchor in [CGPoint(x: CGFloat.nan, y: 0), CGPoint(x: 1.1, y: 0)] {
            XCTAssertEqual(FolderMotionGeometry.sourceTransform(sourceFrame: NSRect(x: 20, y: 30, width: 48, height: 48),
                panelFrame: panel, visibleBounds: viewport, anchorPoint: badAnchor), .identity)
        }
    }

    func testApprovedMotionDurationsAreSeparateFromPagingParameters() {
        XCTAssertEqual(FolderOverlayView.MotionParams.standard.duration, 0.24)
        XCTAssertEqual(FolderOverlayView.MotionParams.standard.exitDuration, 0.20)
        XCTAssertEqual(FolderOverlayView.MotionParams.reduceMotion.duration, 0.18)
        XCTAssertEqual(FolderOverlayView.MotionParams.reduceMotion.exitDuration, 0.18)
    }
}
