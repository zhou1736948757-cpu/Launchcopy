import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import AppIconPipeline
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class AppGridRendererRetirementTests: XCTestCase {
    func testExplicitSweepRetiresReleasedHostAndInvalidatesItsCells() throws {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        let renderer = AppGridRenderer(iconPipeline: pipeline)
        defer { renderer.teardown(); pipeline.shutdown() }
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        weak var releasedHost: NSView?
        let page = try autoreleasepool { () throws -> AppGridPageView in
            let host = makeHost(in: container)
            releasedHost = host
            render(renderer, into: host, index: 4)
            let page = try XCTUnwrap(renderer.pageView(forPage: 4))
            host.removeFromSuperview()
            return page
        }
        XCTAssertNil(releasedHost, "The host must really deallocate, not only detach.")
        let oldCell = try XCTUnwrap(page.cell(at: 0))
        XCTAssertNotNil(oldCell.bindingToken)

        renderer.clearForReuse()

        XCTAssertEqual(renderer.livePageInstanceCount, 0)
        XCTAssertEqual(renderer.pooledInstanceCount, 1)
        XCTAssertNil(renderer.pageView(forPage: 4))
        XCTAssertEqual(page.pageIndex, -1)
        XCTAssertNil(page.presentationID)
        XCTAssertTrue(page.cell(at: 0) === oldCell, "Retain the empty cell allocation for reuse.")
        XCTAssertNil(oldCell.bindingToken, "Retirement must revoke old asynchronous/click ownership.")
        renderer.clearForReuse()
        XCTAssertEqual(renderer.pooledInstanceCount, 1, "Repeated sweeps must not duplicate a pool entry.")
    }

    func testNextRenderReusesReleasedHostsAcrossDistinctPageIndices() throws {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        let renderer = AppGridRenderer(iconPipeline: pipeline)
        defer { renderer.teardown(); pipeline.shutdown() }
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        var originalPage: AppGridPageView?

        for index in 0..<16 {
            weak var releasedHost: NSView?
            try autoreleasepool {
                let host = makeHost(in: container)
                releasedHost = host
                render(renderer, into: host, index: index)
                let page = try XCTUnwrap(renderer.pageView(forPage: index))
                if let originalPage {
                    XCTAssertTrue(page === originalPage, "The next render should reclaim the abandoned page.")
                } else {
                    originalPage = page
                }
                XCTAssertEqual(renderer.livePageInstanceCount, 1)
                XCTAssertEqual(renderer.totalInstancesCreated, 1)
                XCTAssertEqual(page.cellCount, 1)
                XCTAssertTrue(page.superview === host)
                host.removeFromSuperview()
            }
            XCTAssertNil(releasedHost)
        }
        renderer.clearForReuse()
        XCTAssertEqual(renderer.livePageInstanceCount, 0)
        XCTAssertEqual(renderer.pooledInstanceCount, 1)
    }

    func testSweepPreservesMountedPageAndDoesNotRebindItsCells() throws {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        let renderer = AppGridRenderer(iconPipeline: pipeline)
        defer { renderer.teardown(); pipeline.shutdown() }
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        let host = makeHost(in: container)
        render(renderer, into: host, index: 0)
        let page = try XCTUnwrap(renderer.pageView(forPage: 0))
        let cell = try XCTUnwrap(page.cell(at: 0))
        let token = try XCTUnwrap(cell.bindingToken)

        renderer.clearForReuse()

        XCTAssertTrue(renderer.pageView(forPage: 0) === page)
        XCTAssertTrue(page.cell(at: 0) === cell)
        XCTAssertEqual(cell.bindingToken, token)
        XCTAssertEqual(renderer.livePageInstanceCount, 1)
        XCTAssertEqual(renderer.pooledInstanceCount, 0)
        XCTAssertEqual(renderer.totalInstancesCreated, 1)
    }

    private func makeHost(in container: NSView) -> NSView {
        let host = NSView(frame: container.bounds)
        container.addSubview(host)
        return host
    }

    private func render(_ renderer: AppGridRenderer, into host: NSView, index: Int) {
        // Folder identities avoid filesystem-backed icons and catalog scanning.
        let folder = FolderID()
        let content = PagingPageContent(
            presentationID: PagePresentationID(revision: 1, pageIndex: index),
            items: [PagingPageContentItem(slot: 0, identity: AnyHashable(folder), title: "Fixture Folder")],
            isPlaceholder: false)
        renderer.renderTarget = host
        renderer.render(pageIndex: index, content: content, pageCount: 20, reuseGeneration: 0)
    }
}
