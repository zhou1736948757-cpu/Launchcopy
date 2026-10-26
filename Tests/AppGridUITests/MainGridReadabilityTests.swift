import AppKit
import XCTest
@testable import AppGridUI

final class MainGridReadabilityTests: XCTestCase {
    func testEveryApprovedShapeFitsLargeViewportAtLargestAppearance() throws {
        for columns in 3...8 {
            for rows in 3...8 {
                let shape = try XCTUnwrap(MainGridCapacity(columns: columns, rows: rows))
                XCTAssertTrue(MainGridReadability.isReadable(
                    bounds: CGRect(x: 10, y: 20, width: 1200, height: 1000), capacity: shape,
                    appearance: GridItemAppearance(preferredIconSide: 64, appLabelFontSize: 16),
                    showsLabels: true), "Approved shape \(columns)×\(rows)")
            }
        }
    }

    func testTinyEightByEightIsRejectedWithoutChangingShape() throws {
        let shape = try XCTUnwrap(MainGridCapacity(columns: 8, rows: 8))
        let tiny = CGRect(x: 0, y: 0, width: 700, height: 500)
        XCTAssertFalse(MainGridReadability.isReadable(bounds: tiny, capacity: shape,
                                                     appearance: .default, showsLabels: true))
        XCTAssertEqual(shape.itemsPerPage, 64)
        XCTAssertTrue(MainGridReadability.isReadable(bounds: CGRect(x: 0, y: 0, width: 1000, height: 900),
                                                    capacity: shape, appearance: .default, showsLabels: true))
    }

    func testLabelsAndFontMetricsAffectAdmissionWithoutChangingAppearance() throws {
        let shape = try XCTUnwrap(MainGridCapacity(columns: 8, rows: 8))
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 620)
        let large = GridItemAppearance(preferredIconSide: 64, appLabelFontSize: 16)
        XCTAssertFalse(MainGridReadability.isReadable(bounds: bounds, capacity: shape,
                                                     appearance: large, showsLabels: true))
        XCTAssertTrue(MainGridReadability.isReadable(bounds: bounds, capacity: shape,
                                                    appearance: large, showsLabels: false))
        XCTAssertTrue(MainGridReadability.isReadable(
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 650), capacity: shape,
            appearance: large, showsLabels: true), "Main-only padding now admits this formerly tighter boundary")
        XCTAssertEqual(large.preferredIconSide, 64)
        XCTAssertEqual(large.appLabelFontSize, 16)
    }

    func testNarrowOrInvalidBoundsNeverAdmitUnreadableGlyphs() {
        for bounds in [CGRect.zero, CGRect(x: 0, y: 0, width: 100, height: 1000),
                       CGRect(x: 0, y: 0, width: CGFloat.infinity, height: 1000),
                       CGRect(x: 0, y: 0, width: 1000, height: -1)] {
            XCTAssertFalse(MainGridReadability.isReadable(bounds: bounds, capacity: .default,
                                                         appearance: .default, showsLabels: true))
        }
    }

    func testConfiguredOrdinaryEnvelopeAndSearchOccupiedRowsStayDistinct() throws {
        let shape = try XCTUnwrap(MainGridCapacity(columns: 8, rows: 8))
        let bounds = CGRect(x: 10, y: 20, width: 1200, height: 1000)
        let ordinary = AppGridGeometry(bounds: bounds, itemCount: 64, mode: .ordinary,
                                       columns: shape.columns, rows: shape.rows)
        let partial = AppGridGeometry(bounds: bounds, itemCount: 9, mode: .ordinary,
                                      columns: shape.columns, rows: shape.rows)
        let search = AppGridGeometry(bounds: bounds, itemCount: 9, mode: .search,
                                     columns: shape.columns, rows: shape.rows)
        XCTAssertEqual(ordinary.rowCount, 8)
        XCTAssertEqual(partial.rowCount, 8)
        XCTAssertEqual(search.rowCount, 2)
        for index in 0..<shape.itemsPerPage {
            let frame = try XCTUnwrap(ordinary.frame(for: index, itemCount: shape.itemsPerPage))
            XCTAssertTrue(bounds.contains(frame))
        }
        XCTAssertEqual(ordinary.frame(for: 0, itemCount: 64)?.minY,
                       partial.frame(for: 0, itemCount: 9)?.minY)
    }

    func testMismatchedContentCannotPlaceCellsBeyondConfiguredOrdinaryRows() {
        let grid = AppGridGeometry(bounds: CGRect(x: 0, y: 0, width: 1000, height: 900),
                                   itemCount: 10, mode: .ordinary, columns: 3, rows: 3)
        XCTAssertNotNil(grid.frame(for: 8, itemCount: 10))
        XCTAssertNil(grid.frame(for: 9, itemCount: 10))
    }

    func testSearchSpacingCounterexampleCannotBypassReadability() throws {
        let capacity = try XCTUnwrap(MainGridCapacity(columns: 8, rows: 8))
        let bounds = CGRect(x: 0, y: 0, width: 350, height: 800)
        let ordinary = AppGridGeometry(bounds: bounds, itemCount: 64, mode: .ordinary, columns: 8, rows: 8)
        let search = AppGridGeometry(bounds: bounds, itemCount: 9, mode: .search, columns: 8, rows: 8)
        let ordinaryFrame = try XCTUnwrap(ordinary.frame(for: 0, itemCount: 64))
        let searchFrame = try XCTUnwrap(search.frame(for: 0, itemCount: 9))
        XCTAssertGreaterThan(ordinaryFrame.width, 24)
        XCTAssertLessThan(searchFrame.width, 24)
        XCTAssertFalse(MainGridReadability.isReadable(bounds: bounds, capacity: capacity,
                                                     appearance: .default, showsLabels: true))
    }

    func testAdmissionBoundsEveryPossibleOccupiedSearchRow() throws {
        for columns in 3...8 {
            for rows in 3...8 {
                let capacity = try XCTUnwrap(MainGridCapacity(columns: columns, rows: rows))
                for width: CGFloat in [350, 700, 1200] {
                    let bounds = CGRect(x: 10, y: 20, width: width, height: 900)
                    for labels in [true, false] {
                        for appearance in [GridItemAppearance.default,
                                           GridItemAppearance(preferredIconSide: 64, appLabelFontSize: 16)] {
                            guard MainGridReadability.isReadable(bounds: bounds, capacity: capacity,
                                                                 appearance: appearance, showsLabels: labels) else { continue }
                            for count in 1...capacity.itemsPerPage {
                                let grid = MainGridLayoutMetrics.geometry(bounds: bounds, itemCount: count,
                                    mode: .search, capacity: capacity, appearance: appearance)
                                let frame = try XCTUnwrap(grid.frame(for: 0, itemCount: count))
                                let cell = GridItemContentGeometry(bounds: CGRect(origin: .zero, size: frame.size),
                                    appearance: appearance, showsLabels: labels, isFolderCell: true, context: .mainGrid)
                                XCTAssertGreaterThanOrEqual(cell.iconFrame.width, MainGridReadability.minimumIconSide)
                                XCTAssertGreaterThanOrEqual(cell.iconFrame.height, MainGridReadability.minimumIconSide)
                                if labels { XCTAssertGreaterThanOrEqual(cell.countFrame.height, 12) }
                            }
                        }
                    }
                }
            }
        }
    }
}
