import AppCatalogCore
import AppIconPipeline
import AppKit
import PagingUI
import XCTest
@testable import AppGridUI

@MainActor
final class LargeMainGridLayoutTests: XCTestCase {
    private let bounds = CGRect(x: 13, y: 27, width: 1000, height: 700)
    private let large = GridItemAppearance(preferredIconSide: 80, appLabelFontSize: 12)

    func testLargeMainIconsUseWidthInsteadOfRejectedCenteredCap() {
        let capacity = MainGridCapacity(columns: 6, rows: 5)!
        let grid = MainGridLayoutMetrics.geometry(bounds: bounds, itemCount: 30,
            mode: .ordinary, capacity: capacity, appearance: large)
        let first = grid.frame(for: 0, itemCount: 30)!
        let last = grid.frame(for: 5, itemCount: 30)!
        XCTAssertEqual(first.minX, bounds.minX + 24, accuracy: 0.001)
        XCTAssertEqual(last.maxX, bounds.maxX - 24, accuracy: 0.001)
        XCTAssertGreaterThan(first.width, 128)
        let fit = MainGridLayoutMetrics.fittedIconSides(bounds: bounds, capacity: capacity,
            appearance: large, showsLabels: true)!
        XCTAssertEqual(fit.app, 80, accuracy: 0.001)
        XCTAssertEqual(fit.folder, 80, accuracy: 0.001)
    }

    func testDenseGridReportsRealFitRatherThanClaimingPreferredSize() {
        let capacity = MainGridCapacity(columns: 5, rows: 7)!
        let fit = MainGridLayoutMetrics.fittedIconSides(bounds: bounds, capacity: capacity,
            appearance: GridItemAppearance(preferredIconSide: 96, appLabelFontSize: 12),
            showsLabels: true)!
        XCTAssertLessThan(fit.app, 96)
        XCTAssertLessThan(fit.folder, 96)
        XCTAssertGreaterThan(fit.folder, 24)
        XCTAssertNil(MainGridLayoutMetrics.fittedIconSides(bounds: .zero,
            capacity: capacity, appearance: large, showsLabels: true))
    }

    func testLargeCellsPreservePartialAndSearchCenteringAndFrameContainment() {
        for mode in [AppGridLayoutMode.ordinary, .search] {
            for columns in 3...8 {
                for rows in 3...8 {
                    let capacity = MainGridCapacity(columns: columns, rows: rows)!
                    let count = min(columns + 2, capacity.itemsPerPage)
                    let grid = MainGridLayoutMetrics.geometry(bounds: bounds, itemCount: count,
                        mode: mode, capacity: capacity, appearance: large)
                    for index in 0..<count {
                        let frame = grid.frame(for: index, itemCount: count)!
                        XCTAssertGreaterThanOrEqual(frame.minX, bounds.minX)
                        XCTAssertLessThanOrEqual(frame.maxX, bounds.maxX)
                        XCTAssertGreaterThanOrEqual(frame.minY, bounds.minY)
                        XCTAssertLessThanOrEqual(frame.maxY, bounds.maxY)
                    }
                    let start = (count - 1) / columns * columns
                    XCTAssertEqual((grid.frame(for: start, itemCount: count)!.minX
                        + grid.frame(for: count - 1, itemCount: count)!.maxX) / 2,
                        bounds.midX, accuracy: 0.001)
                }
            }
        }
    }

    func testMainPageAppearanceRelayoutRetainsBindingAndIconRequests() {
        let pipeline = IconPipeline(loader: GatedIconLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let page = AppGridPageView(iconPipeline: pipeline)
        page.frame = bounds
        page.gridCapacity = MainGridCapacity(columns: 6, rows: 5)!
        page.render(pageIndex: 0, content: makeContent(revision: 1, page: 0,
            titles: ["Synthetic Main App"]), pageCount: 1, reuseGeneration: 1)
        page.layoutSubtreeIfNeeded()
        let cell = page.cell(at: 0)!
        let token = cell.bindingToken
        let generation = page.surfaceGeneration
        XCTAssertEqual(cell.contentLayoutContext, .mainGrid)
        page.needsLayout = false
        page.itemAppearance = large
        XCTAssertTrue(page.needsLayout)
        page.layoutSubtreeIfNeeded()
        cell.layoutSubtreeIfNeeded()
        XCTAssertEqual(cell.iconView.frame.width, 80, accuracy: 0.001)
        XCTAssertEqual(cell.bindingToken, token)
        XCTAssertEqual(page.surfaceGeneration, generation)
        XCTAssertTrue(page.cell(at: 0) === cell)
        XCTAssertEqual(pipeline.stats.requests, 0, "Identity-free fixture makes layout-only work observable")
    }

    func testMainDragPreviewRetainsActualLargeGlyphAfterSourceDisappears() throws {
        let cell = AppGridCellView(frame: CGRect(x: 0, y: 0, width: 160, height: 116))
        cell.contentLayoutContext = .mainGrid
        cell.itemAppearance = large
        cell.bind(name: "Synthetic Large App", token: ItemBindingToken(catalogRevision: 1,
            pageIdentity: PagePresentationID(revision: 1, pageIndex: 0), itemSlot: 0,
            appID: AnyHashable(makeAppID("fixture.large.preview")), reuseGeneration: 1,
            iconKey: nil, surfaceGeneration: 1))
        cell.iconView.image = makeIconImage(pixelWidth: 192, pixelHeight: 192)
        cell.layoutSubtreeIfNeeded()
        let host = NSView(frame: CGRect(x: 0, y: 0, width: 900, height: 700))
        let visuals = DragUIVisuals(host: host, reduceMotionProvider: { true })
        visuals.showPreview(sourceCell: cell, at: CGPoint(x: 300, y: 300))
        let preview = try XCTUnwrap(host.subviews.first {
            $0.subviews.contains { $0 is NSImageView }
        })
        let icon = try XCTUnwrap(preview.subviews.compactMap { $0 as? NSImageView }.first)
        XCTAssertEqual(icon.frame.width, 80, accuracy: 0.001)
        XCTAssertGreaterThan(preview.frame.height, 88)
        cell.clearContent()
        visuals.capturePreview(from: nil)
        visuals.reaffirmPreview(at: CGPoint(x: 400, y: 300))
        XCTAssertEqual(icon.frame.width, 80, accuracy: 0.001)
        XCTAssertEqual(preview.frame.midX, 400, accuracy: 0.001)
    }
}
