import AppCatalogCore
import AppIconPipeline
import AppKit
import XCTest
@testable import AppGridUI

@MainActor
final class FolderReorderIconContinuityTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let pipeline = IconPipeline(loader: DeferredFixtureIconLoader(), limits: .init())
        let overlay: FolderOverlayView
        let ids = (0..<3).map { makeAppID("fixture.reorder.continuity.\($0)") }
        let images = (0..<3).map { makeIconImage(r: UInt8(40 + $0 * 70)) }
        let folderID = FolderID()

        init() {
            overlay = FolderOverlayView(iconPipeline: pipeline)
            overlay.frame = NSRect(x: 0, y: 0, width: 1000, height: 800)
            overlay.membersPerPage = 3
        }

        func entry(_ members: [AppID]? = nil, id: FolderID? = nil,
                   title: String = "Owned continuity") -> FolderEntry {
            FolderEntry(id: id ?? folderID, title: title, members: members ?? ids)
        }

        func configure(_ entry: FolderEntry, page: Int = 0, revision: UInt64 = 7,
                       reduceMotion: Bool = false) {
            overlay.configure(entry: entry, innerPage: page, reduceMotion: reduceMotion,
                              catalogRevision: revision) { _ in "Owned member" }
            overlay.layoutSubtreeIfNeeded()
        }

        func seed() throws {
            configure(entry())
            for index in ids.indices {
                let cell = try XCTUnwrap(overlay.memberCell(at: index))
                let token = try XCTUnwrap(cell.bindingToken)
                XCTAssertTrue(cell.applyIconIfValid(images[index], token: token))
            }
        }

        func teardown() { overlay.teardown(); pipeline.shutdown() }
    }

    func testPureReorderMovesKnownIconsSynchronouslyWithoutWaitingForDelivery() throws {
        let fixture = Fixture(); defer { fixture.teardown() }
        try fixture.seed()
        let oldTokens = try fixture.ids.indices.map {
            try XCTUnwrap(fixture.overlay.memberCell(at: $0)?.bindingToken)
        }
        let requests = fixture.pipeline.stats.requests
        for permutation in [[2, 0, 1], [1, 2, 0], [0, 1, 2]] {
            fixture.configure(fixture.entry(permutation.map { fixture.ids[$0] }))
            // No await/run-loop drain: current pixels must not depend on an async cache hit.
            for (slot, original) in permutation.enumerated() {
                let cell = try XCTUnwrap(fixture.overlay.memberCell(at: slot))
                XCTAssertEqual(cell.bindingToken?.appID as? AppID, fixture.ids[original])
                XCTAssertTrue(cell.iconView.image === fixture.images[original])
                XCTAssertFalse(cell.applyIconIfValid(fixture.images[0], token: oldTokens[slot]))
            }
        }
        XCTAssertEqual(fixture.pipeline.stats.requests - requests, 9,
                       "Continuity must not bypass normal fresh generation-gated requests")
        fixture.overlay.clearContent()
        for slot in 0..<3 { XCTAssertNil(fixture.overlay.memberCell(at: slot)?.iconView.image) }
    }

    func testDifferentCatalogFolderPageCapacityMembersAndTransitionsDoNotReuseIcons() throws {
        for change in ["catalog", "folder", "title", "page", "capacity", "members", "motion", "transition"] {
            let fixture = Fixture(); defer { fixture.teardown() }
            try fixture.seed()
            var entry = fixture.entry([fixture.ids[1], fixture.ids[0], fixture.ids[2]])
            var page = 0, revision: UInt64 = 7
            switch change {
            case "catalog": revision = 8
            case "folder": entry = fixture.entry(entry.members, id: FolderID())
            case "title": entry = fixture.entry(entry.members, title: "Different owned title")
            case "page": fixture.overlay.membersPerPage = 2; page = 1
            case "capacity": fixture.overlay.membersPerPage = 2
            case "members": entry = fixture.entry(Array(entry.members.prefix(2)))
            case "transition": fixture.overlay.setPanelTransitionActive(true)
            default: break
            }
            fixture.configure(entry, page: page, revision: revision, reduceMotion: change == "motion")
            for slot in 0..<fixture.overlay.memberCellCount {
                XCTAssertNil(fixture.overlay.memberCell(at: slot)?.iconView.image, change)
            }
        }
    }

    func testMismatchedOutgoingTokenNeverCarriesItsImageToANewBinding() throws {
        let fixture = Fixture(); defer { fixture.teardown() }
        try fixture.seed()
        let source = try XCTUnwrap(fixture.overlay.memberCell(at: 0))
        let old = try XCTUnwrap(source.bindingToken)
        let wrongKey = IconKey(identity: IconIdentity.from(appID: fixture.ids[0]),
                               pointSize: 96, displayScale: 2)
        source.bind(name: "Owned member", token: ItemBindingToken(catalogRevision: old.catalogRevision,
            pageIdentity: old.pageIdentity, itemSlot: old.itemSlot, appID: old.appID,
            reuseGeneration: old.reuseGeneration, iconKey: wrongKey,
            surfaceGeneration: old.surfaceGeneration))
        source.iconView.image = fixture.images[0]
        fixture.configure(fixture.entry([fixture.ids[1], fixture.ids[0], fixture.ids[2]]))
        XCTAssertTrue(fixture.overlay.memberCell(at: 0)?.iconView.image === fixture.images[1])
        XCTAssertNil(fixture.overlay.memberCell(at: 1)?.iconView.image)
        XCTAssertTrue(fixture.overlay.memberCell(at: 2)?.iconView.image === fixture.images[2])
    }

    func testAsyncDeliveryStillReplacesRetainedIconsUnderTheNewFullBinding() async throws {
        let fixture = Fixture(); defer { fixture.teardown() }
        try fixture.seed()
        fixture.configure(fixture.entry([fixture.ids[1], fixture.ids[0], fixture.ids[2]]))
        XCTAssertTrue(fixture.overlay.memberCell(at: 0)?.iconView.image === fixture.images[1])
        let deadline = Date().addingTimeInterval(3)
        while fixture.overlay.memberCell(at: 0)?.iconView.image === fixture.images[1], Date() < deadline {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let image = try XCTUnwrap(fixture.overlay.memberCell(at: 0)?.iconView.image)
        XCTAssertFalse(fixture.images.contains { $0 === image })
        XCTAssertEqual(fixture.overlay.memberCell(at: 0)?.bindingToken?.appID as? AppID, fixture.ids[1])
        XCTAssertGreaterThan(fixture.overlay.staleIconApplyCount, 0)
    }
}

/// Cancellation-safe synthetic loading. MainActor delivery cannot run inside a synchronous test span.
private final class DeferredFixtureIconLoader: IconLoading, @unchecked Sendable {
    private let image = makeIconImage(r: 210, g: 30, b: 90)
    func load(key: IconKey) async throws -> NSImage {
        try await Task.sleep(nanoseconds: 1_000_000)
        return image
    }
}
