import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import AppIconPipeline
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class EmptyPresentationRetirementTests: XCTestCase {
    func testEmptyPresentationImmediatelyClearsRetainedHostsAndReusesGridPages() throws {
        let provider = EmptyRetirementProvider(pageCount: 4, apps: false)
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        let renderer = AppGridRenderer(iconPipeline: pipeline)
        let surface = makeSurface(pageCount: 4, itemsPerPage: 35)
        defer { surface.teardown(); renderer.teardown(); pipeline.shutdown() }
        surface.contentProvider = provider
        surface.renderer = renderer
        surface.refreshPresentation()
        let count = surface.liveHostCount
        XCTAssertGreaterThan(count, 1, "Exercise several mounted production grid pages.")
        let initialPages = try (0..<count).map { try XCTUnwrap(renderer.pageView(forPage: $0)) }
        let expectedInstances = renderer.totalInstancesCreated
        for _ in 0..<4 {
            let hosts = try (0..<count).map { try XCTUnwrap(surface.hostForPage($0)) }
            let generations = hosts.map(\.reuseGeneration)
            let cells = try initialPages.map { try XCTUnwrap($0.cell(at: 0)) }
            XCTAssertTrue(cells.allSatisfy { $0.bindingToken != nil })
            provider.pageCount = 0
            surface.reloadCurrentPresentation()

            XCTAssertEqual(surface.liveHostCount, 0)
            XCTAssertEqual(renderer.livePageInstanceCount, 0, "No future render may be required for retirement.")
            XCTAssertEqual(renderer.pooledInstanceCount, count)
            for (host, generation) in zip(hosts, generations) {
                XCTAssertNil(host.superview)
                XCTAssertEqual(host.pageIndex, -1)
                XCTAssertEqual(host.preparedItemsPerPage, 0)
                XCTAssertGreaterThan(host.reuseGeneration, generation)
            }
            XCTAssertTrue(cells.allSatisfy { $0.bindingToken == nil && $0.iconView.image == nil })
            XCTAssertTrue(initialPages.allSatisfy { $0.presentationID == nil && $0.pageIndex == -1 })

            provider.pageCount = 4
            surface.reloadCurrentPresentation()
            let restored = try (0..<count).map { try XCTUnwrap(renderer.pageView(forPage: $0)) }
            XCTAssertEqual(Set(restored.map(ObjectIdentifier.init)), Set(initialPages.map(ObjectIdentifier.init)))
            XCTAssertEqual(renderer.totalInstancesCreated, expectedInstances)
            XCTAssertEqual(renderer.livePageInstanceCount, count)
            XCTAssertEqual(renderer.pooledInstanceCount, 0)
        }
    }

    func testLateIconCompletionAfterEmptyPresentationCannotPopulateRetiredCell() async throws {
        let admitted = expectation(description: "generated icon loader admitted")
        let loader = EmptyRetirementIconLoader(admitted: admitted)
        let pipeline = IconPipeline(loader: loader, limits: .init())
        let renderer = AppGridRenderer(iconPipeline: pipeline)
        let provider = EmptyRetirementProvider(pageCount: 1, apps: true)
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        defer { surface.teardown(); renderer.teardown(); pipeline.shutdown(); loader.close() }
        surface.contentProvider = provider
        surface.renderer = renderer
        surface.refreshPresentation()
        let page = try XCTUnwrap(renderer.pageView(forPage: 0))
        let cell = try XCTUnwrap(page.cell(at: 0))
        await fulfillment(of: [admitted], timeout: 3)
        let completed = expectation(description: "all old consumers returned through generation guard")
        let requestCount = pipeline.stats.requests
        XCTAssertGreaterThan(requestCount, 0)
        completed.expectedFulfillmentCount = max(1, requestCount)
        var applied = 0
        renderer.onIconApplyResult = { _, result in
            if result == .applied { applied += 1 }
            completed.fulfill()
        }
        provider.pageCount = 0
        surface.reloadCurrentPresentation()
        XCTAssertNil(cell.bindingToken)
        loader.finish(image: RecordingIconLoader.solidImage())
        await fulfillment(of: [completed], timeout: 3)
        XCTAssertEqual(applied, 0)
        XCTAssertNil(cell.bindingToken)
        XCTAssertNil(cell.iconView.image)
        XCTAssertNil(page.presentationID)
        XCTAssertEqual(renderer.livePageInstanceCount, 0)
    }

    func testEmptyPresentationInvalidatesNeutralHostBindingsToo() throws {
        let provider = EmptyRetirementProvider(pageCount: 1, apps: false)
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        defer { surface.teardown() }
        surface.contentProvider = provider
        surface.refreshPresentation()
        let host = try XCTUnwrap(surface.hostForPage(0))
        let generation = host.reuseGeneration
        XCTAssertGreaterThan(host.subviews.count, 0)
        provider.pageCount = 0
        surface.reloadCurrentPresentation()
        XCTAssertEqual(surface.liveHostCount, 0)
        XCTAssertEqual(host.pageIndex, -1)
        XCTAssertEqual(host.preparedItemsPerPage, 0)
        XCTAssertGreaterThan(host.reuseGeneration, generation)
        XCTAssertTrue(host.subviews.allSatisfy { $0 is NSTextField && $0.isHidden },
                      "Neutral tiles are removed; an empty hidden page label may be retained.")
        XCTAssertTrue(host.subviews.compactMap { $0 as? NSTextField }.allSatisfy { $0.stringValue.isEmpty })
    }
}

private final class EmptyRetirementProvider: PagingPageContentProviding {
    var pageCount: Int
    let apps: Bool
    var servedRevision: UInt64? { 1 }
    var servedPageCount: Int? { pageCount }
    init(pageCount: Int, apps: Bool) { self.pageCount = pageCount; self.apps = apps }
    func content(for id: PagePresentationID, itemsPerPage: Int) -> PagingPageContent {
        guard id.pageIndex >= 0, id.pageIndex < pageCount else {
            return PagingPageContent(presentationID: id, items: [], isPlaceholder: true)
        }
        let identity: AnyHashable = apps ? AnyHashable(CatalogFixture.appID("fixture.empty.icon")) : AnyHashable(FolderID())
        return PagingPageContent(presentationID: id,
            items: [PagingPageContentItem(slot: 0, identity: identity, title: "Generated Fixture")], isPlaceholder: false)
    }
}

private final class EmptyRetirementIconLoader: IconLoading, @unchecked Sendable {
    let admitted: XCTestExpectation
    private let lock = NSLock()
    private var continuation: CheckedContinuation<NSImage, Error>?
    private var closed = false
    init(admitted: XCTestExpectation) { self.admitted = admitted }
    func load(key: IconKey) async throws -> NSImage {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if closed {
                lock.unlock()
                continuation.resume(throwing: CancellationError())
                return
            }
            self.continuation = continuation
            lock.unlock()
            admitted.fulfill()
        }
    }
    func finish(image: NSImage) {
        lock.lock(); let current = continuation; continuation = nil; lock.unlock()
        current?.resume(returning: image)
    }
    func close() {
        lock.lock(); closed = true; let current = continuation; continuation = nil; lock.unlock()
        current?.resume(throwing: CancellationError())
    }
}
