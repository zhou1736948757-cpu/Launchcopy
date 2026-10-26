import AppGridUI
import AppIconPipeline
import AppKit
import PagingUI
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class MainGridRendererMetricsTests: XCTestCase {
    func testShapePropagatesToLivePooledAndReusedPagesWithoutIconWork() throws {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        let renderer = AppGridRenderer(iconPipeline: pipeline)
        defer { renderer.teardown(); pipeline.shutdown() }
        let container = NSView(frame: CGRect(x: 0, y: 0, width: 1200, height: 1000))
        let firstHost = NSView(frame: container.bounds)
        let secondHost = NSView(frame: container.bounds)
        container.addSubview(firstHost)
        container.addSubview(secondHost)
        render(renderer, host: firstHost, page: 0)
        render(renderer, host: secondHost, page: 1)
        let first = try XCTUnwrap(renderer.pageView(forPage: 0))
        let second = try XCTUnwrap(renderer.pageView(forPage: 1))
        let liveToken = second.cell(at: 0)?.bindingToken
        firstHost.removeFromSuperview()
        renderer.clearForReuse()
        XCTAssertEqual(renderer.pooledInstanceCount, 1)
        let requests = pipeline.stats.requests
        let large = try XCTUnwrap(MainGridCapacity(columns: 8, rows: 8))
        renderer.gridCapacity = large
        XCTAssertEqual(first.gridCapacity, large)
        XCTAssertEqual(second.gridCapacity, large)
        XCTAssertEqual(second.cell(at: 0)?.bindingToken, liveToken)
        XCTAssertEqual(pipeline.stats.requests, requests)
        container.addSubview(firstHost)
        render(renderer, host: firstHost, page: 2)
        XCTAssertTrue(renderer.pageView(forPage: 2) === first)
        XCTAssertEqual(first.gridCapacity, large)
        XCTAssertEqual(renderer.totalInstancesCreated, 2)
        XCTAssertEqual(pipeline.stats.requests, requests)
    }

    private func render(_ renderer: AppGridRenderer, host: NSView, page: Int) {
        let folder = FolderID()
        renderer.renderTarget = host
        renderer.render(pageIndex: page, content: PagingPageContent(
            presentationID: PagePresentationID(revision: 1, pageIndex: page),
            items: [.init(slot: 0, identity: AnyHashable(folder), title: "Fixture Folder")],
            isPlaceholder: false), pageCount: 3, reuseGeneration: 0)
    }
}
