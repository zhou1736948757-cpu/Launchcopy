import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import PagingUI
@testable import PagingPrototypeApp
import XCTest

@MainActor
final class AppContextMenuRendererTests: XCTestCase {
    private func content(page: Int, count: Int = 1) -> PagingPageContent {
        PagingPageContent(presentationID: PagePresentationID(revision: 1, pageIndex: page),
                          items: (0..<count).map { index in
            PagingPageContentItem(slot: index,
                                  identity: AnyHashable(CatalogFixture.appID("fixture.menu.renderer\(page)-\(index)")),
                                  title: "Fixture \(page)-\(index)")
        }, isPlaceholder: false)
    }

    private func event(_ cell: AppGridCellView) throws -> NSEvent {
        cell.layout()
        let point = cell.convert(NSPoint(x: cell.iconView.frame.midX, y: cell.iconView.frame.midY), to: nil)
        return try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: point,
                                              modifierFlags: [], timestamp: 0, windowNumber: 0,
                                              context: nil, eventNumber: 0, clickCount: 1, pressure: 1))
    }

    func testFactoryReplacementReachesLivePooledReusedAndNewPagesWithoutRendering() throws {
        let pipeline = IconPipeline(loader: ContextMenuRendererLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let renderer = AppGridRenderer(iconPipeline: pipeline)
        defer { renderer.teardown() }
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 1600, height: 700))
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 700))
        root.addSubview(host)
        renderer.renderTarget = host
        let first = NSMenu(title: "First")
        let latest = NSMenu(title: "Latest")
        renderer.appContextMenuProvider = { _ in first }
        renderer.render(pageIndex: 0, content: content(page: 0), pageCount: 3, reuseGeneration: 1)
        let page = try XCTUnwrap(renderer.pageView(forPage: 0))
        page.layout()
        let cell = try XCTUnwrap(page.cell(at: 0))
        let request = try event(cell)
        XCTAssertTrue(cell.menu(for: request) === first)
        let binding = cell.bindingToken
        let generation = page.surfaceGeneration
        let frame = cell.frame
        let stats = pipeline.stats
        renderer.appContextMenuProvider = { _ in latest }
        XCTAssertTrue(cell.menu(for: request) === latest)
        XCTAssertEqual(cell.bindingToken, binding)
        XCTAssertEqual(cell.frame, frame)
        XCTAssertEqual(page.surfaceGeneration, generation)
        XCTAssertEqual(page.reuseGeneration, 1)
        XCTAssertEqual(pipeline.stats, stats)
        XCTAssertEqual(renderer.totalInstancesCreated, 1)

        host.removeFromSuperview()
        renderer.clearForReuse()
        XCTAssertEqual(renderer.pooledInstanceCount, 1)
        XCTAssertEqual(renderer.livePageInstanceCount, 0)
        XCTAssertNil(cell.menu(for: request))
        let pooledGeneration = page.surfaceGeneration
        let pooledStats = pipeline.stats
        renderer.appContextMenuProvider = { _ in first }
        XCTAssertNotNil(page.appContextMenuProvider)
        XCTAssertNil(cell.bindingToken)
        XCTAssertEqual(page.surfaceGeneration, pooledGeneration)
        XCTAssertEqual(pipeline.stats, pooledStats)
        // A retained cleared cell can prove that the pooled consumer received the replacement.
        // Bind a synthetic identity directly; this does not invoke the renderer or icon pipeline.
        cell.bind(name: "Fixture pooled", token: try XCTUnwrap(binding))
        XCTAssertTrue(cell.menu(for: request) === first)
        cell.clearContent()

        root.addSubview(host)
        renderer.render(pageIndex: 1, content: content(page: 1), pageCount: 3, reuseGeneration: 2)
        XCTAssertTrue(renderer.pageView(forPage: 1) === page)
        XCTAssertTrue(page.cell(at: 0) === cell)
        XCTAssertTrue(cell.menu(for: try event(cell)) === first)
        let secondHost = NSView(frame: NSRect(x: 800, y: 0, width: 800, height: 700))
        root.addSubview(secondHost)
        renderer.renderTarget = secondHost
        renderer.render(pageIndex: 2, content: content(page: 2, count: 2), pageCount: 3, reuseGeneration: 2)
        let newPage = try XCTUnwrap(renderer.pageView(forPage: 2))
        newPage.layout()
        XCTAssertEqual(renderer.totalInstancesCreated, 2)
        for index in 0..<2 {
            let newCell = try XCTUnwrap(newPage.cell(at: index))
            XCTAssertTrue(newCell.menu(for: try event(newCell)) === first)
        }
        renderer.appContextMenuProvider = nil
        XCTAssertNil(cell.menu(for: try event(cell)))
        for index in 0..<2 {
            let newCell = try XCTUnwrap(newPage.cell(at: index))
            XCTAssertNil(newCell.menu(for: try event(newCell)))
        }
    }

    func testRenderReassertsRendererFactoryAndRejectsFolderMenus() throws {
        let pipeline = IconPipeline(loader: ContextMenuRendererLoader(), limits: .init())
        defer { pipeline.shutdown() }
        let renderer = AppGridRenderer(iconPipeline: pipeline)
        defer { renderer.teardown() }
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 700))
        let host = NSView(frame: root.bounds)
        root.addSubview(host)
        renderer.renderTarget = host
        let expected = NSMenu(title: "Renderer")
        let unexpected = NSMenu(title: "Direct mutation")
        var calls = 0
        renderer.appContextMenuProvider = { _ in calls += 1; return expected }
        renderer.render(pageIndex: 0, content: content(page: 0), pageCount: 1, reuseGeneration: 1)
        let page = try XCTUnwrap(renderer.pageView(forPage: 0))
        let cell = try XCTUnwrap(page.cell(at: 0))
        page.appContextMenuProvider = { _ in unexpected }
        cell.appContextMenuProvider = { _ in unexpected }
        renderer.render(pageIndex: 0, content: content(page: 0), pageCount: 1, reuseGeneration: 2)
        page.layout()
        XCTAssertTrue(cell.menu(for: try event(cell)) === expected)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000072")!)
        let folderContent = PagingPageContent(
            presentationID: PagePresentationID(revision: 1, pageIndex: 0),
            items: [PagingPageContentItem(slot: 0, identity: AnyHashable(folderID), title: "Group")],
            isPlaceholder: false)
        renderer.render(pageIndex: 0, content: folderContent, pageCount: 1, reuseGeneration: 3)
        XCTAssertTrue(page.cell(at: 0) === cell)
        XCTAssertNil(cell.menu(for: try event(cell)))
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(renderer.totalInstancesCreated, 1)
    }
}

private final class ContextMenuRendererLoader: IconLoading, @unchecked Sendable {
    private let image = NSImage(size: NSSize(width: 48, height: 48))
    func load(key: IconKey) async throws -> NSImage { image }
}
