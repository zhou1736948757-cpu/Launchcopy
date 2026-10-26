import AppCatalogCore
import AppIconPipeline
import AppKit
import PagingUI
import XCTest
@testable import AppGridUI

@MainActor
final class MainPageReorderIconContinuityTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let pipeline = IconPipeline(loader: MainContinuityDeferredLoader(), limits: .init())
        let page: AppGridPageView
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 800))
        let ids = (0..<3).map { makeAppID("fixture.main.continuity.\($0)") }
        let images = (0..<3).map { makeIconImage(r: UInt8(40 + $0 * 70)) }

        init() {
            page = AppGridPageView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
            host.addSubview(page)
            page.frame = host.bounds
        }

        func content(_ order: [Int] = [0, 1, 2], revision: UInt64 = 7, index: Int = 0) -> PagingPageContent {
            makeContent(revision: revision, page: index, titles: order.map { "Owned app \($0)" },
                        appIDs: order.map { ids[$0] })
        }

        func render(_ content: PagingPageContent, reuse: UInt64 = 4, continuity: Bool = true) {
            page.render(pageIndex: content.presentationID.pageIndex, content: content, pageCount: 2,
                        reuseGeneration: reuse, retainingReadyIconsForReorder: continuity)
        }

        func seed() throws {
            render(content())
            for slot in ids.indices {
                let cell = try XCTUnwrap(page.cell(at: slot))
                XCTAssertTrue(cell.applyIconIfValid(images[slot], token: try XCTUnwrap(cell.bindingToken)))
            }
        }

        func teardown() { page.teardown(); pipeline.shutdown() }
    }

    func testReorderAndRepeatedRefreshRestorePixelsUnderNewBindingsSynchronously() throws {
        let f = Fixture(); defer { f.teardown() }
        try f.seed()
        let oldTokens = try f.ids.indices.map { try XCTUnwrap(f.page.cell(at: $0)?.bindingToken) }
        let requests = f.pipeline.stats.requests
        let generation = f.page.surfaceGeneration
        for order in [[2, 0, 1], [2, 0, 1], [1, 2, 0], [0, 1, 2]] {
            f.page.cell(at: 0)?.setFocused(true)
            f.render(f.content(order))
            f.page.layoutSubtreeIfNeeded()
            for (slot, original) in order.enumerated() {
                let cell = try XCTUnwrap(f.page.cell(at: slot))
                let token = try XCTUnwrap(cell.bindingToken)
                XCTAssertEqual(token.appID as? AppID, f.ids[original])
                XCTAssertEqual(token.itemSlot, slot)
                XCTAssertEqual(token.surfaceGeneration, f.page.surfaceGeneration)
                XCTAssertEqual(cell.boundName, "Owned app \(original)")
                XCTAssertTrue(cell.iconView.image === f.images[original])
                XCTAssertFalse(cell.applyIconIfValid(f.images[0], token: oldTokens[slot]))
                XCTAssertFalse(cell.isFocused, "A reused slot must not retain the old focus.")
            }
        }
        XCTAssertEqual(f.page.surfaceGeneration, generation + 4)
        XCTAssertEqual(f.pipeline.stats.requests - requests, 12,
                       "Ready pixels must never bypass fresh generation-gated requests.")
        f.page.clearForReuse()
        for slot in f.ids.indices {
            XCTAssertNil(f.page.cell(at: slot)?.bindingToken)
            XCTAssertNil(f.page.cell(at: slot)?.iconView.image)
        }
    }

    func testEachCorruptOutgoingTokenFieldRejectsOnlyThatSourceImage() throws {
        for field in 0..<7 {
            let f = Fixture(); defer { f.teardown() }
            try f.seed()
            let cell = try XCTUnwrap(f.page.cell(at: 0))
            let old = try XCTUnwrap(cell.bindingToken)
            let bad = ItemBindingToken(
                catalogRevision: field == 0 ? old.catalogRevision + 1 : old.catalogRevision,
                pageIdentity: field == 1 ? PagePresentationID(revision: 7, pageIndex: 1) : old.pageIdentity,
                itemSlot: field == 2 ? old.itemSlot + 1 : old.itemSlot,
                appID: field == 3 ? AnyHashable(f.ids[1]) : old.appID,
                reuseGeneration: field == 4 ? old.reuseGeneration + 1 : old.reuseGeneration,
                iconKey: field == 5 ? IconKey(identity: IconIdentity.from(appID: f.ids[0]),
                                              pointSize: 96, displayScale: 2) : old.iconKey,
                surfaceGeneration: field == 6 ? old.surfaceGeneration + 1 : old.surfaceGeneration)
            cell.bind(name: "Owned corrupt source", token: bad)
            cell.iconView.image = f.images[0]
            f.render(f.content([1, 0, 2]))
            XCTAssertTrue(f.page.cell(at: 0)?.iconView.image === f.images[1], "field \(field)")
            XCTAssertNil(f.page.cell(at: 1)?.iconView.image, "field \(field)")
            XCTAssertTrue(f.page.cell(at: 2)?.iconView.image === f.images[2], "field \(field)")
        }
    }

    func testCatalogSearchMembershipCapacityAndLifecycleChangesFailClosed() throws {
        for change in ["catalog", "page", "reuse", "searchIn", "searchOut", "members", "duplicate",
                       "capacity", "clear", "placeholder", "detached", "notAdmitted"] {
            let f = Fixture(); defer { f.teardown() }
            if change == "searchOut" { f.page.layoutMode = .search }
            try f.seed()
            var content = f.content([1, 0, 2])
            var reuse: UInt64 = 4
            switch change {
            case "catalog": content = f.content([1, 0, 2], revision: 8)
            case "page": content = f.content([1, 0, 2], index: 1)
            case "reuse": reuse = 5
            case "searchIn": f.page.layoutMode = .search
            case "searchOut": f.page.layoutMode = .ordinary
            case "members": content = f.content([1, 0])
            case "duplicate": content = f.content([1, 1, 2])
            case "capacity": f.page.gridCapacity = try XCTUnwrap(MainGridCapacity(columns: 8, rows: 8))
            case "clear": f.page.clearForReuse()
            case "placeholder": f.render(makePlaceholderContent(revision: 7, page: 0))
            case "detached": f.page.removeFromSuperview()
            default: break
            }
            f.render(content, reuse: reuse, continuity: change != "notAdmitted")
            for slot in 0..<f.page.cellCount {
                XCTAssertNil(f.page.cell(at: slot)?.iconView.image, change)
            }
        }
    }

    func testOnlyReadyAttachedAppCellsDonateAndFoldersStillRebind() throws {
        let f = Fixture(); defer { f.teardown() }
        try f.seed()
        f.page.cell(at: 0)?.iconView.image = nil
        f.page.cell(at: 1)?.removeFromSuperview()
        f.render(f.content([1, 0, 2]))
        XCTAssertNil(f.page.cell(at: 0)?.iconView.image)
        XCTAssertNil(f.page.cell(at: 1)?.iconView.image)
        XCTAssertTrue(f.page.cell(at: 2)?.iconView.image === f.images[2])

        // Mixed app/folder order must move the folder identity as well as app pixels.
        let folderID = FolderID()
        let folder = PagingPageContentItem(slot: 1, identity: AnyHashable(folderID), title: "Owned folder")
        let first = f.content().items[0]
        f.render(PagingPageContent(presentationID: .init(revision: 7, pageIndex: 0),
                                  items: [first, folder], isPlaceholder: false))
        let appCell = try XCTUnwrap(f.page.cell(at: 0))
        XCTAssertTrue(appCell.applyIconIfValid(f.images[0], token: try XCTUnwrap(appCell.bindingToken)))
        f.render(PagingPageContent(presentationID: .init(revision: 7, pageIndex: 0), items: [
            .init(slot: 0, identity: AnyHashable(folderID), title: "Renamed owned folder"),
            .init(slot: 1, identity: first.identity, title: first.title)], isPlaceholder: false))
        XCTAssertTrue(f.page.cell(at: 0)?.isFolderCell == true)
        XCTAssertEqual(f.page.cell(at: 0)?.bindingToken?.appID as? FolderID, folderID)
        XCTAssertEqual(f.page.cell(at: 0)?.boundName, "Renamed owned folder")
        XCTAssertNil(f.page.cell(at: 0)?.iconView.image)
        XCTAssertTrue(f.page.cell(at: 1)?.iconView.image === f.images[0])
    }

    func testAsyncRequestsStillRejectOldGenerationAndReplaceRetainedPixels() async throws {
        let f = Fixture(); defer { f.teardown() }
        try f.seed()
        let callbacks = expectation(description: "old and current consumers delivered")
        callbacks.expectedFulfillmentCount = 6
        let recorder = ApplyRecorder()
        f.page.onIconApplyResult = { token, result in
            recorder.record(token, result)
            callbacks.fulfill()
        }
        f.render(f.content([1, 0, 2]))
        XCTAssertTrue(f.page.cell(at: 0)?.iconView.image === f.images[1])
        await fulfillment(of: [callbacks], timeout: 3)
        XCTAssertEqual(recorder.count(.rejectedStale), 3)
        XCTAssertEqual(recorder.count(.applied), 3)
        XCTAssertEqual(f.page.staleIconApplyCount, 3)
        for slot in f.ids.indices {
            let image = try XCTUnwrap(f.page.cell(at: slot)?.iconView.image)
            XCTAssertFalse(f.images.contains { $0 === image })
        }
        f.page.teardown()
        f.render(f.content())
        XCTAssertEqual(f.page.cellCount, 0)
    }

    func testTeardownDuringContinuityRejectsAllPendingConsumersWithoutNewRequests() async throws {
        let f = Fixture(); defer { f.teardown() }
        try f.seed()
        let callbacks = expectation(description: "all consumers ignored after teardown")
        callbacks.expectedFulfillmentCount = 6
        let recorder = ApplyRecorder()
        f.page.onIconApplyResult = { token, result in
            recorder.record(token, result)
            callbacks.fulfill()
        }
        f.render(f.content([1, 0, 2]))
        let detachedCell = try XCTUnwrap(f.page.cell(at: 0))
        XCTAssertTrue(detachedCell.iconView.image === f.images[1])
        let requests = f.pipeline.stats.requests
        f.page.teardown()
        f.render(f.content())
        await fulfillment(of: [callbacks], timeout: 3)
        XCTAssertEqual(recorder.count(.ignoredAfterTeardown), 6)
        XCTAssertEqual(recorder.count(.applied), 0)
        XCTAssertEqual(f.page.cellCount, 0)
        XCTAssertNil(detachedCell.superview)
        XCTAssertTrue(detachedCell.iconView.image === f.images[1], "Late results must not touch removed cells.")
        XCTAssertEqual(f.pipeline.stats.requests, requests)
    }
}

private final class MainContinuityDeferredLoader: IconLoading, @unchecked Sendable {
    private let image = makeIconImage(r: 210, g: 30, b: 90)
    func load(key: IconKey) async throws -> NSImage {
        try await Task.sleep(nanoseconds: 1_000_000)
        return image
    }
}
