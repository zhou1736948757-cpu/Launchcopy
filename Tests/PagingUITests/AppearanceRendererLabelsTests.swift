import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import PagingUI
@testable import PagingPrototypeApp
import XCTest

@MainActor
final class AppearanceRendererLabelsTests: XCTestCase {
    private func content(page: Int, count: Int = 1) -> PagingPageContent {
        PagingPageContent(
            presentationID: PagePresentationID(revision: 1, pageIndex: page),
            items: (0..<count).map {
                PagingPageContentItem(slot: page * 35 + $0,
                                      identity: AnyHashable(CatalogFixture.appID("fixture.labels.\(page).\($0)")),
                                      title: "Fixture \(page)-\($0)")
            }, isPlaceholder: false)
    }

    func testRendererDefaultAndLiveUpdatePreserveInstancesBindingsGeometryAndRequests() throws {
        let pipeline = IconPipeline(loader: RendererLabelsFixtureLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let renderer = AppGridRenderer(iconPipeline: pipeline)
        defer { renderer.teardown() }
        XCTAssertTrue(renderer.showsAppLabels)
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 1_600, height: 700))
        let hosts = (0..<2).map { index -> NSView in
            let host = NSView(frame: NSRect(x: CGFloat(index) * 800, y: 0, width: 800, height: 700))
            root.addSubview(host)
            renderer.renderTarget = host
            renderer.render(pageIndex: index, content: content(page: index), pageCount: 2, reuseGeneration: 4)
            return host
        }
        let pages = try (0..<2).map { try XCTUnwrap(renderer.pageView(forPage: $0)) }
        for page in pages { page.layout() }
        let cells = try pages.map { try XCTUnwrap($0.cell(at: 0)) }
        let bindings = cells.map { $0.bindingToken }
        let frames = cells.map { $0.frame }
        let generations = pages.map { $0.surfaceGeneration }
        let stats = pipeline.stats
        for visible in [false, false, true] {
            renderer.showsAppLabels = visible
            for index in 0..<2 {
                XCTAssertTrue(renderer.pageView(forPage: index) === pages[index])
                XCTAssertTrue(pages[index].superview === hosts[index])
                XCTAssertEqual(pages[index].showsAppLabels, visible)
                XCTAssertEqual(cells[index].nameLabel.isHidden, !visible)
                XCTAssertEqual(cells[index].bindingToken, bindings[index])
                XCTAssertEqual(cells[index].frame, frames[index])
                XCTAssertEqual(cells[index].accessibilityLabel(), "Fixture \(index)-0")
                XCTAssertEqual(pages[index].surfaceGeneration, generations[index])
                XCTAssertEqual(pages[index].reuseGeneration, 4)
            }
            XCTAssertEqual(pipeline.stats, stats)
            XCTAssertEqual(renderer.totalInstancesCreated, 2)
            XCTAssertEqual(renderer.livePageInstanceCount, 2)
            XCTAssertEqual(renderer.pooledInstanceCount, 0)
        }
    }

    func testRendererUpdatesPooledPageAndPolicySurvivesPoolReuseAndNewPages() throws {
        let pipeline = IconPipeline(loader: RendererLabelsFixtureLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let renderer = AppGridRenderer(iconPipeline: pipeline)
        defer { renderer.teardown() }
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 1_600, height: 700))
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 700))
        root.addSubview(host)
        renderer.renderTarget = host
        renderer.render(pageIndex: 0, content: content(page: 0), pageCount: 3, reuseGeneration: 1)
        let pooled = try XCTUnwrap(renderer.pageView(forPage: 0))
        let cell = try XCTUnwrap(pooled.cell(at: 0))
        host.removeFromSuperview()
        renderer.clearForReuse()
        XCTAssertEqual(renderer.pooledInstanceCount, 1)
        XCTAssertEqual(renderer.livePageInstanceCount, 0)
        let generation = pooled.surfaceGeneration
        let stats = pipeline.stats
        renderer.showsAppLabels = false
        XCTAssertFalse(pooled.showsAppLabels)
        XCTAssertTrue(cell.nameLabel.isHidden)
        XCTAssertNil(cell.bindingToken)
        XCTAssertEqual(pooled.surfaceGeneration, generation)
        XCTAssertEqual(pipeline.stats, stats)
        root.addSubview(host)
        renderer.render(pageIndex: 1, content: content(page: 1), pageCount: 3, reuseGeneration: 2)
        XCTAssertTrue(renderer.pageView(forPage: 1) === pooled)
        XCTAssertTrue(pooled.cell(at: 0) === cell)
        XCTAssertTrue(cell.nameLabel.isHidden)
        XCTAssertEqual(cell.accessibilityLabel(), "Fixture 1-0")
        XCTAssertEqual(renderer.totalInstancesCreated, 1)

        let secondHost = NSView(frame: NSRect(x: 800, y: 0, width: 800, height: 700))
        root.addSubview(secondHost)
        renderer.renderTarget = secondHost
        renderer.render(pageIndex: 2, content: content(page: 2, count: 2), pageCount: 3, reuseGeneration: 2)
        let newPage = try XCTUnwrap(renderer.pageView(forPage: 2))
        XCTAssertEqual(renderer.totalInstancesCreated, 2)
        XCTAssertFalse(newPage.showsAppLabels)
        for index in 0..<2 { XCTAssertTrue(try XCTUnwrap(newPage.cell(at: index)).nameLabel.isHidden) }
        renderer.showsAppLabels = true
        XCTAssertFalse(cell.nameLabel.isHidden)
        for index in 0..<2 { XCTAssertFalse(try XCTUnwrap(newPage.cell(at: index)).nameLabel.isHidden) }
    }

    func testEveryRenderReassertsRendererPolicyForExistingPagesAndCells() throws {
        let pipeline = IconPipeline(loader: RendererLabelsFixtureLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let renderer = AppGridRenderer(iconPipeline: pipeline)
        defer { renderer.teardown() }
        renderer.showsAppLabels = false
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 700))
        let host = NSView(frame: root.bounds)
        root.addSubview(host)
        renderer.renderTarget = host
        renderer.render(pageIndex: 0, content: content(page: 0), pageCount: 1, reuseGeneration: 1)
        let page = try XCTUnwrap(renderer.pageView(forPage: 0))
        let cell = try XCTUnwrap(page.cell(at: 0))
        page.showsAppLabels = true
        renderer.render(pageIndex: 0, content: content(page: 0), pageCount: 1, reuseGeneration: 2)
        XCTAssertFalse(page.showsAppLabels)
        XCTAssertTrue(cell.nameLabel.isHidden)
        // Even if a consumer mutates a cell directly, normal binding restores page policy.
        cell.showsAppLabels = true
        renderer.render(pageIndex: 0, content: content(page: 0), pageCount: 1, reuseGeneration: 3)
        XCTAssertTrue(cell.nameLabel.isHidden)
        XCTAssertTrue(renderer.pageView(forPage: 0) === page)
        XCTAssertEqual(renderer.totalInstancesCreated, 1)
    }
}

private final class RendererLabelsFixtureLoader: IconLoading, @unchecked Sendable {
    private let image = NSImage(size: NSSize(width: 48, height: 48))
    func load(key: IconKey) async throws -> NSImage { image }
}
