import AppKit
import XCTest
@testable import AppGridUI

final class AppGridGeometryTests: XCTestCase {
    func testOrdinaryUsesStableSevenRowEnvelope() {
        let full = AppGridGeometry(bounds: CGRect(x: 10, y: 20, width: 1000, height: 900), itemCount: 35, mode: .ordinary)
        let partial = AppGridGeometry(bounds: CGRect(x: 10, y: 20, width: 1000, height: 900), itemCount: 6, mode: .ordinary)
        XCTAssertEqual(full.rowCount, 7); XCTAssertEqual(partial.rowCount, 7)
        XCTAssertEqual(full.frame(for: 0, itemCount: 35)?.minY, partial.frame(for: 0, itemCount: 6)?.minY)
        XCTAssertGreaterThan(full.frame(for: 34, itemCount: 35)!.minY, full.area.minY)
        XCTAssertLessThanOrEqual(full.frame(for: 34, itemCount: 35)!.maxY, full.area.maxY)
    }

    func testEffectiveSpacingIsUsedWhenSmallRegionClampsSpacing() {
        let geometry = AppGridGeometry(bounds: CGRect(x: 0, y: 0, width: 800, height: 650), itemCount: 35, mode: .ordinary)
        XCTAssertLessThan(geometry.spacing, 16)
        let first = geometry.frame(for: 0, itemCount: 35)!
        let secondRow = geometry.frame(for: 5, itemCount: 35)!
        XCTAssertEqual(first.minX, secondRow.minX, accuracy: 0.01)
        XCTAssertEqual(first.minY - secondRow.maxY, geometry.spacing, accuracy: 0.01)
    }

    func testSearchCentersOccupiedRowsAndPreservesBoundsOrigin() {
        let geometry = AppGridGeometry(bounds: CGRect(x: 10, y: 20, width: 1000, height: 900), itemCount: 1, mode: .search)
        let frame = geometry.frame(for: 0, itemCount: 1)!
        XCTAssertEqual(frame.midX, 510, accuracy: 0.01)
        XCTAssertGreaterThanOrEqual(frame.minY, 20)
    }

    func testGeometryNeverReturnsNegativeDimensionsWhenSmall() {
        let unusable = AppGridGeometry(bounds: CGRect(x: 3, y: 4, width: 200, height: 100), itemCount: 35, mode: .ordinary)
        XCTAssertNil(unusable.frame(for: 0, itemCount: 35), "No frame when the usable region has no height")

        let geometry = AppGridGeometry(bounds: CGRect(x: 3, y: 4, width: 200, height: 220), itemCount: 35, mode: .ordinary)
        for index in 0..<35 {
            guard let frame = geometry.frame(for: index, itemCount: 35) else {
                XCTFail("Expected a frame in a positive usable region")
                continue
            }
            XCTAssertGreaterThanOrEqual(frame.width, 0)
            XCTAssertGreaterThanOrEqual(frame.height, 0)
        }
    }
}
