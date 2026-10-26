import AppKit
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class LeadingLibraryPresentationTests: XCTestCase {
    func testIdleBackingCreationIsIdempotentAndPreservesPresentationState() {
        let view = NSView(frame: .init(x: 10, y: 20, width: 100, height: 80))
        view.isHidden = true
        view.alphaValue = 0.7
        let frame = view.frame
        CATransaction.begin()
        CATransaction.setDisableActions(false)
        XCTAssertEqual(LeadingLibraryPresentation.prepareLayerBackings(for: [view]), 1)
        XCTAssertFalse(CATransaction.disableActions())
        XCTAssertEqual(LeadingLibraryPresentation.prepareLayerBackings(for: [view]), 0)
        XCTAssertEqual(view.frame, frame)
        XCTAssertTrue(view.isHidden)
        XCTAssertEqual(view.alphaValue, 0.7)
        XCTAssertEqual(view.layer?.affineTransform(), .identity)
        XCTAssertTrue(view.layer?.animationKeys()?.isEmpty ?? true)
        CATransaction.commit()
    }

    func testTrackingUsesExactTranslationsAndResetLeavesNoAnimation() throws {
        let grid = NSView(frame: .init(x: 0, y: 0, width: 1000, height: 700))
        let library = NSView(frame: grid.frame)
        LeadingLibraryPresentation.render(offset: 0.25, width: 1000, reduceMotion: false,
                                          gridViews: [grid], libraryView: library)
        XCTAssertEqual(try XCTUnwrap(grid.layer).affineTransform().tx, 750)
        XCTAssertEqual(try XCTUnwrap(library.layer).affineTransform().tx, -250)
        XCTAssertEqual(grid.layer?.opacity, 1)
        LeadingLibraryPresentation.reset(gridViews: [grid], libraryView: library)
        XCTAssertEqual(grid.layer?.affineTransform(), .identity)
        XCTAssertEqual(library.layer?.affineTransform(), .identity)
        XCTAssertTrue(grid.layer?.animationKeys()?.isEmpty ?? true)
        XCTAssertTrue(library.layer?.animationKeys()?.isEmpty ?? true)
    }

    func testReducedMotionClampsOpacityWithoutTranslation() {
        let grid = NSView(); let library = NSView()
        LeadingLibraryPresentation.render(offset: 0.25, width: 800, reduceMotion: true,
                                          gridViews: [grid], libraryView: library)
        XCTAssertEqual(grid.layer?.affineTransform(), .identity)
        XCTAssertEqual(library.layer?.affineTransform(), .identity)
        XCTAssertEqual(grid.layer?.opacity, 0.25)
        XCTAssertEqual(library.layer?.opacity, 0.75)
        LeadingLibraryPresentation.render(offset: 1.2, width: 800, reduceMotion: true,
                                          gridViews: [grid], libraryView: library)
        XCTAssertEqual(grid.layer?.opacity, 1)
        XCTAssertEqual(library.layer?.opacity, 0)
        LeadingLibraryPresentation.reset(gridViews: [grid], libraryView: library)
        XCTAssertEqual(library.layer?.opacity, 1)
    }

    func testFrameWritesPreserveEnclosingTransactionAndRejectInvalidGeometry() {
        let view = NSView()
        CATransaction.begin()
        CATransaction.setDisableActions(false)
        LeadingLibraryPresentation.render(offset: 0.5, width: 800, reduceMotion: false,
                                          gridViews: [view], libraryView: nil)
        XCTAssertFalse(CATransaction.disableActions())
        let original = view.layer?.affineTransform()
        LeadingLibraryPresentation.render(offset: .nan, width: 800, reduceMotion: false,
                                          gridViews: [view], libraryView: nil)
        LeadingLibraryPresentation.render(offset: 0, width: -.infinity, reduceMotion: false,
                                          gridViews: [view], libraryView: nil)
        XCTAssertEqual(view.layer?.affineTransform(), original)
        LeadingLibraryPresentation.reset(gridViews: [view], libraryView: nil)
        XCTAssertFalse(CATransaction.disableActions())
        CATransaction.commit()
    }
}
