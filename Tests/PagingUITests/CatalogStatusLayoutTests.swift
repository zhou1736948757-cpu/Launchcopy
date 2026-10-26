import AppGridUI
import CoreGraphics
import XCTest
@testable import PagingPrototypeApp

final class CatalogStatusLayoutTests: XCTestCase {
    func testFooterNeverIntersectsOrdinaryCellsOrDotStripAcrossSizesAndCapacities() throws {
        for size in [CGSize(width: 500, height: 500), CGSize(width: 1000, height: 668), CGSize(width: 1470, height: 956)] {
            for origin in [CGPoint.zero, CGPoint(x: 31, y: 57)] {
                let bounds = CGRect(origin: origin, size: size)
                for rows in [3, 5, 8] {
                    let capacity = try XCTUnwrap(MainGridCapacity(columns: rows, rows: rows))
                    let grid = MainGridLayoutMetrics.geometry(bounds: bounds, itemCount: capacity.itemsPerPage,
                        mode: .ordinary, capacity: capacity, appearance: .default)
                    let cells = (0..<capacity.itemsPerPage).compactMap { grid.frame(for: $0, itemCount: capacity.itemsPerPage) }
                    let bottom = cells.map(\.minY).min() ?? bounds.minY
                    let dots = CGRect(x: bounds.midX - 160, y: bounds.minY, width: 320, height: min(32, bottom - bounds.minY))
                    let result = CatalogStatusLayout.compactFrame(in: bounds, gridContentMinY: bottom,
                        pageDotsFrame: dots, height: 20)
                    XCTAssertGreaterThan(result.width, 24)
                    XCTAssertTrue(bounds.contains(result))
                    XCTAssertFalse(result.intersects(dots))
                    XCTAssertTrue(cells.allSatisfy { !$0.intersects(result) })
                    XCTAssertLessThanOrEqual(result.height, 20)
                }
            }
        }
    }

    func testUsesLargerLeadingSpaceAndFullGutterWithoutDots() {
        let bounds = CGRect(x: 20, y: 40, width: 1000, height: 700)
        let dots = CGRect(x: 800, y: 40, width: 200, height: 24)
        let leading = CatalogStatusLayout.compactFrame(in: bounds, gridContentMinY: 64, pageDotsFrame: dots, height: 20)
        XCTAssertEqual(leading.minX, 28)
        XCTAssertFalse(leading.intersects(dots))
        let full = CatalogStatusLayout.compactFrame(in: bounds, gridContentMinY: 64, pageDotsFrame: nil, height: 20)
        XCTAssertEqual(full.maxX, bounds.maxX - 8)
        XCTAssertEqual(full.width, 360)
    }

    func testNarrowFooterUsesOnlyExistingHeaderGapWithoutMovingAnyControls() {
        let bounds = CGRect(x: 0, y: 0, width: 340, height: 600)
        let dots = CGRect(x: 16, y: 0, width: 308, height: 24)
        let search = CGRect(x: 20, y: 523, width: 300, height: 28)
        let settings = CGRect(x: 292, y: 552, width: 36, height: 36)
        let result = CatalogStatusLayout.compactFrame(in: bounds, gridContentMinY: 24,
            pageDotsFrame: dots, height: 20, gridContentMaxY: 504,
            searchFrame: search, settingsFrame: settings)
        XCTAssertGreaterThan(result.width, 24)
        XCTAssertGreaterThan(result.height, 15)
        XCTAssertTrue(bounds.contains(result))
        XCTAssertGreaterThan(result.minY, 504)
        XCTAssertFalse(result.intersects(search))
        XCTAssertFalse(result.intersects(settings))
        XCTAssertFalse(result.intersects(dots))
    }

    func testInvalidGeometryAndEmptyGutterDoNotProduceNonfiniteFrames() {
        for bounds in [CGRect.zero, CGRect(x: CGFloat.infinity, y: 0, width: 500, height: 500)] {
            XCTAssertEqual(CatalogStatusLayout.compactFrame(in: bounds, gridContentMinY: 24,
                pageDotsFrame: nil, height: 20), .zero)
        }
        XCTAssertEqual(CatalogStatusLayout.compactFrame(in: CGRect(x: 0, y: 0, width: 500, height: 500),
            gridContentMinY: 0, pageDotsFrame: nil, height: 20), .zero)
    }
}
