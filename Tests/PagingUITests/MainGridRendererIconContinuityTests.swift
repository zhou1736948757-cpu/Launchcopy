import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import AppIconPipeline
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class MainGridRendererIconContinuityTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        let renderer: AppGridRenderer
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 800))
        let host = PageHostView()
        let ids = (0..<3).map { CatalogFixture.appID("fixture.main.renderer.\($0)") }
        let images = (0..<3).map { _ in RecordingIconLoader.solidImage() }
        var mode: AppGridLayoutMode = .ordinary

        init() {
            renderer = AppGridRenderer(iconPipeline: pipeline)
            renderer.layoutModeProvider = { [weak self] in self?.mode ?? .ordinary }
            host.frame = container.bounds
            host.customRenderer = renderer
            container.addSubview(host)
        }

        func content(_ order: [Int] = [0, 1, 2], revision: UInt64 = 7,
                     index: Int = 0, placeholder: Bool = false) -> PagingPageContent {
            PagingPageContent(presentationID: .init(revision: revision, pageIndex: index),
                items: placeholder ? [] : order.enumerated().map { slot, original in
                    .init(slot: index * 35 + slot, identity: AnyHashable(ids[original]),
                          title: "Owned app \(original)")
                }, isPlaceholder: placeholder)
        }

        func render(_ content: PagingPageContent, into target: PageHostView? = nil) {
            let target = target ?? host
            target.render(pageIndex: content.presentationID.pageIndex, content: content,
                          pageCount: 2, reuseGeneration: target.reuseGeneration)
        }

        func seed() throws -> AppGridPageView {
            render(content())
            let page = try XCTUnwrap(renderer.pageView(forPage: 0))
            for slot in ids.indices {
                let cell = try XCTUnwrap(page.cell(at: slot))
                XCTAssertTrue(cell.applyIconIfValid(images[slot], token: try XCTUnwrap(cell.bindingToken)))
            }
            return page
        }

        func teardown() { renderer.teardown(); pipeline.shutdown() }
    }

    func testAttachedHostReorderKeepsReadyImagesAndStillRendersEveryNewBinding() throws {
        let f = Fixture(); defer { f.teardown() }
        let page = try f.seed()
        let generation = page.surfaceGeneration
        let requests = f.pipeline.stats.requests
        f.render(f.content([2, 0, 1]))
        XCTAssertTrue(f.renderer.pageView(forPage: 0) === page)
        XCTAssertEqual(page.surfaceGeneration, generation + 1)
        XCTAssertEqual(f.pipeline.stats.requests, requests + 3)
        for (slot, original) in [2, 0, 1].enumerated() {
            let cell = try XCTUnwrap(page.cell(at: slot))
            XCTAssertEqual(cell.bindingToken?.appID as? AppID, f.ids[original])
            XCTAssertTrue(cell.iconView.image === f.images[original])
        }
        XCTAssertEqual(f.renderer.totalInstancesCreated, 1)
        XCTAssertEqual(f.renderer.pooledInstanceCount, 0)
    }

    func testHostClearBeforeDetachImmediatelyRevokesBindingsAndCannotDonateAfterReuse() throws {
        let f = Fixture(); defer { f.teardown() }
        let page = try f.seed()
        let token = try XCTUnwrap(page.cell(at: 0)?.bindingToken)
        let generation = page.surfaceGeneration
        f.host.clearForReuse()
        XCTAssertTrue(f.host.superview === f.container, "Exercise the real clear-before-detach order.")
        XCTAssertEqual(f.renderer.livePageInstanceCount, 0)
        XCTAssertEqual(f.renderer.pooledInstanceCount, 1)
        XCTAssertEqual(page.pageIndex, -1)
        XCTAssertGreaterThan(page.surfaceGeneration, generation)
        for slot in f.ids.indices {
            XCTAssertNil(page.cell(at: slot)?.bindingToken)
            XCTAssertNil(page.cell(at: slot)?.iconView.image)
        }
        f.render(f.content([2, 0, 1]))
        XCTAssertTrue(f.renderer.pageView(forPage: 0) === page)
        XCTAssertEqual(page.reuseGeneration, f.host.reuseGeneration)
        XCTAssertFalse(try XCTUnwrap(page.cell(at: 0)).applyIconIfValid(f.images[0], token: token))
        for slot in f.ids.indices { XCTAssertNil(page.cell(at: slot)?.iconView.image) }
        XCTAssertEqual(f.renderer.totalInstancesCreated, 1)
    }

    func testCatalogSearchPlaceholderHostTransferAndPageReuseDoNotCarryPixels() throws {
        for change in ["catalog", "searchIn", "searchOut", "placeholder", "host", "page", "detached"] {
            let f = Fixture(); defer { f.teardown() }
            if change == "searchOut" { f.mode = .search }
            let oldPage = try f.seed()
            var content = f.content([2, 0, 1])
            var target = f.host
            switch change {
            case "catalog": content = f.content([2, 0, 1], revision: 8)
            case "searchIn": f.mode = .search
            case "searchOut": f.mode = .ordinary
            case "placeholder":
                f.render(f.content(placeholder: true))
                XCTAssertNil(f.renderer.pageView(forPage: 0))
                XCTAssertNil(oldPage.cell(at: 0)?.bindingToken)
            case "host":
                target = PageHostView()
                target.frame = f.container.bounds
                target.customRenderer = f.renderer
                f.container.addSubview(target)
            case "page": content = f.content([2, 0, 1], index: 1)
            case "detached":
                f.host.removeFromSuperview()
                f.renderer.clearForReuse()
                f.container.addSubview(f.host)
            default: break
            }
            f.render(content, into: target)
            let page = try XCTUnwrap(f.renderer.pageView(forPage: content.presentationID.pageIndex))
            for slot in f.ids.indices { XCTAssertNil(page.cell(at: slot)?.iconView.image, change) }
            XCTAssertEqual(f.renderer.livePageInstanceCount, 1, change)
            XCTAssertEqual(f.renderer.totalInstancesCreated, 1, change)
        }
    }

    func testCommittedLayoutReloadUpdatesRealOrderGeometryAndPersistableLayoutWithContinuousIcons() throws {
        let records = (0..<3).map { index -> AppRecord in
            let bundleID = "fixture.main.commit.\(index)"
            let id = CatalogFixture.appID(bundleID)
            return CatalogFixture.record(id: id, displayName: "Owned app \(index)", bundleID: bundleID,
                url: URL(fileURLWithPath: "/SyntheticApps/Owned\(index).app"),
                icon: IconIdentity.from(appID: id), rootPriority: 0)
        }
        let snapshot = try CatalogFixture.snapshot(records: records, revision: CatalogRevision(7))
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        let renderer = AppGridRenderer(iconPipeline: pipeline)
        renderer.layoutModeProvider = { provider.activeQuery?.isEmpty == false ? .search : .ordinary }
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        defer { surface.teardown(); renderer.teardown(); pipeline.shutdown() }
        surface.contentProvider = provider
        surface.renderer = renderer
        surface.refreshPresentation()
        surface.layoutSubtreeIfNeeded()
        let page = try XCTUnwrap(renderer.pageView(forPage: 0))
        page.layoutSubtreeIfNeeded()
        let images = records.map { _ in RecordingIconLoader.solidImage() }
        let previousTokens = try records.indices.map { try XCTUnwrap(page.cell(at: $0)?.bindingToken) }
        let previousFrames = try records.indices.map { try XCTUnwrap(page.cell(at: $0)).frame }
        for slot in records.indices {
            XCTAssertTrue(try XCTUnwrap(page.cell(at: slot)).applyIconIfValid(images[slot], token: previousTokens[slot]))
        }
        let requests = pipeline.stats.requests
        let generation = page.surfaceGeneration
        let order = [2, 0, 1]
        let committed = PersistentWorkspaceLayout(generation: LayoutGeneration(11),
            topLevelOrder: order.map { .app(PersistentAppReference.from(record: records[$0])) }, folders: [])
        let update = try XCTUnwrap(provider.applyCommittedLayout(committed, atCurrentPage: 0, itemsPerPage: 35))
        XCTAssertEqual(update.previousRevision, update.newRevision)
        surface.reloadCurrentPresentation()
        surface.layoutSubtreeIfNeeded()
        page.layoutSubtreeIfNeeded()

        XCTAssertEqual(provider.servedRevision, 7)
        XCTAssertEqual(provider.presentationRecords.map(\.id), order.map { records[$0].id })
        XCTAssertTrue(renderer.pageView(forPage: 0) === page)
        XCTAssertGreaterThan(page.surfaceGeneration, generation)
        XCTAssertEqual(pipeline.stats.requests - requests, 3)
        let focusLayout = AppGridFocusLayout.build(from: snapshot, composition: provider.presentationEntries, itemsPerPage: 35)
        for (slot, original) in order.enumerated() {
            let cell = try XCTUnwrap(page.cell(at: slot))
            XCTAssertEqual(cell.bindingToken?.appID as? AppID, records[original].id)
            XCTAssertEqual(cell.bindingToken?.itemSlot, slot)
            XCTAssertEqual(cell.frame, previousFrames[slot])
            XCTAssertEqual(focusLayout.validAppID(page: 0, slot: slot), records[original].id)
            XCTAssertTrue(cell.iconView.image === images[original], "No async turn before this assertion.")
            XCTAssertFalse(cell.applyIconIfValid(images[slot], token: previousTokens[slot]))
        }
        XCTAssertEqual(page.dragItemFrames(convertedTo: surface, catalog: snapshot).map(\.identity),
                       order.map { .app(PersistentAppReference.from(record: records[$0])) })
        let bytes = try LayoutStoreCodec.encode(committed, writeGeneration: 5)
        guard case .valid(let decoded) = LayoutStoreCodec.decode(bytes) else {
            return XCTFail("The committed order must remain persistable through the existing codec.")
        }
        XCTAssertEqual(decoded.layout, committed)
        XCTAssertEqual(decoded.writeGeneration, 5)
    }
}
