import AppKit
import AppIconPipeline
import XCTest
@testable import AppGridUI

@MainActor
final class MainGridPageMetricsTests: XCTestCase {
    func testSameCapacityDifferentShapeChangesMetricsWithoutRebinding() throws {
        let pipeline = IconPipeline(loader: GatedIconLoader(), limits: .init())
        let page = AppGridPageView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
        defer { page.teardown(); pipeline.shutdown() }
        page.frame = CGRect(x: 0, y: 0, width: 1200, height: 1000)
        let shapeA = try XCTUnwrap(MainGridCapacity(columns: 3, rows: 8))
        let shapeB = try XCTUnwrap(MainGridCapacity(columns: 4, rows: 6))
        page.gridCapacity = shapeA
        page.render(pageIndex: 0, content: makeContent(revision: 1, page: 0,
                    titles: (0..<24).map { "Fixture \($0)" }), pageCount: 1, reuseGeneration: 0)
        page.layoutSubtreeIfNeeded()
        let cell = try XCTUnwrap(page.cell(at: 3))
        let frameA = cell.frame
        let token = cell.bindingToken
        let generation = page.surfaceGeneration
        let requests = pipeline.stats.requests
        page.gridCapacity = shapeB
        page.layoutSubtreeIfNeeded()
        let expected = AppGridGeometry(bounds: page.bounds, itemCount: 24, mode: .ordinary,
                                       columns: 4, rows: 6)
        XCTAssertEqual(cell.frame, expected.frame(for: 3, itemCount: 24))
        XCTAssertNotEqual(cell.frame, frameA)
        XCTAssertEqual(cell.bindingToken, token, "Metrics do not pretend to be a binding transaction")
        XCTAssertEqual(page.surfaceGeneration, generation)
        XCTAssertEqual(pipeline.stats.requests, requests)
        XCTAssertEqual(page.gridCapacity.itemsPerPage, 24)
    }

    func testMaximumCapacityRendersAllRowsWithinBounds() throws {
        let pipeline = IconPipeline(loader: GatedIconLoader(), limits: .init())
        let page = AppGridPageView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
        defer { page.teardown(); pipeline.shutdown() }
        page.frame = CGRect(x: 0, y: 0, width: 1200, height: 1000)
        page.gridCapacity = try XCTUnwrap(MainGridCapacity(columns: 8, rows: 8))
        page.render(pageIndex: 0, content: makeContent(revision: 1, page: 0,
                    titles: (0..<64).map { "Fixture \($0)" }), pageCount: 1, reuseGeneration: 0)
        page.layoutSubtreeIfNeeded()
        XCTAssertEqual(page.cellCount, 64)
        for index in 0..<64 {
            let cell = try XCTUnwrap(page.cell(at: index))
            XCTAssertTrue(page.bounds.contains(cell.frame))
            XCTAssertGreaterThan(cell.frame.width, 0)
            XCTAssertGreaterThan(cell.frame.height, 0)
        }
    }
}
