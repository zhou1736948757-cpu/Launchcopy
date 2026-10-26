import AppCatalogCore
import AppGridUI
import Foundation
import XCTest
@testable import PagingPrototypeApp

private actor LibraryProjectionGate {
    private(set) var requests: [AppLibraryProjectionRequest] = []
    private var completions: [CheckedContinuation<AppLibrarySnapshot?, Never>] = []
    func run(_ request: AppLibraryProjectionRequest) async -> AppLibrarySnapshot? {
        requests.append(request)
        return await withCheckedContinuation { completions.append($0) }
    }
    func finish(with revision: CatalogRevision? = nil) {
        let request = requests[requests.count - completions.count]
        let result = AppLibraryProjection.make(catalog: request.catalog, management: request.management,
            preferences: request.preferences, query: request.query, category: request.category, locale: request.locale)
        completions.removeFirst().resume(returning: revision.map {
            AppLibrarySnapshot(revision: $0, entries: result.entries, counts: result.counts)
        } ?? result)
    }
    var count: Int { requests.count }
}

@MainActor
final class AppLibraryProjectionControllerTests: XCTestCase {
    private func request(revision: UInt64 = 1, query: String = "") -> AppLibraryProjectionRequest {
        let id = AppID.bundleIdentifier("fixture")
        let record = AppRecord(id: id, displayName: "Fixture", bundleIdentifier: "fixture",
            canonicalURL: URL(fileURLWithPath: "/SyntheticFixture.app"), iconIdentity: .from(appID: id), sourceRootPriority: 0)
        return .init(catalog: .init(revision: .init(revision), records: [record]), management: .default,
                     preferences: .init(enabled: true), query: query, locale: Locale(identifier: "en_US_POSIX"))
    }
    private func waitForCount(_ expected: Int, gate: LibraryProjectionGate) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while await gate.count < expected, ContinuousClock.now < deadline { await Task.yield() }
        let count = await gate.count
        XCTAssertEqual(count, expected)
    }
    private func waitForCompletion(_ owner: AppLibraryProjectionController) async {
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        while owner.isProjecting, ContinuousClock.now < deadline { await Task.yield() }
        XCTAssertFalse(owner.isProjecting)
    }

    func testClosedLibraryStartsNoProjectionWork() async {
        let gate = LibraryProjectionGate()
        let owner = AppLibraryProjectionController(work: { await gate.run($0) })
        owner.update(request())
        await Task.yield()
        let count = await gate.count
        XCTAssertEqual(count, 0)
        XCTAssertNil(owner.snapshot)
        XCTAssertFalse(owner.isOpen)
    }

    func testQueryBurstCoalescesToOnePendingLatestInput() async {
        let gate = LibraryProjectionGate()
        let owner = AppLibraryProjectionController(work: { await gate.run($0) })
        owner.open(request())
        await waitForCount(1, gate: gate)
        owner.update(request(query: "No match"))
        owner.update(request(revision: 2, query: "Fixture"))
        await gate.finish()
        await waitForCount(2, gate: gate)
        XCTAssertNil(owner.snapshot)
        let queries = await gate.requests.map(\.query)
        XCTAssertEqual(queries, ["", "Fixture"])
        await gate.finish()
        await waitForCompletion(owner)
        XCTAssertEqual(owner.snapshot?.revision, .init(2))
        XCTAssertEqual(owner.snapshot?.entries.count, 1)
    }

    func testCloseAndReopenCannotPublishOldCatalog() async {
        let gate = LibraryProjectionGate()
        let owner = AppLibraryProjectionController(work: { await gate.run($0) })
        owner.open(request(revision: 1))
        await waitForCount(1, gate: gate)
        owner.close()
        owner.open(request(revision: 3))
        let count = await gate.count
        XCTAssertEqual(count, 1)
        await gate.finish()
        await waitForCount(2, gate: gate)
        XCTAssertNil(owner.snapshot)
        await gate.finish()
        await waitForCompletion(owner)
        XCTAssertEqual(owner.snapshot?.revision, .init(3))
    }

    func testWrongRevisionResultIsNeverActionable() async {
        let gate = LibraryProjectionGate()
        let owner = AppLibraryProjectionController(work: { await gate.run($0) })
        var updates: [Bool] = []
        owner.onChange = { updates.append(owner.isProjecting) }
        owner.open(request(revision: 3))
        await waitForCount(1, gate: gate)
        await gate.finish(with: .init(2))
        await waitForCompletion(owner)
        XCTAssertNil(owner.snapshot)
        XCTAssertEqual(updates, [true, false], "Observers must see both loading and terminal failure state")
    }

    func testDefaultOffMainProjectionHasRealResult() async {
        let owner = AppLibraryProjectionController()
        owner.open(request())
        await waitForCompletion(owner)
        XCTAssertEqual(owner.snapshot?.entries.count, 1)
        owner.close()
        XCTAssertNil(owner.snapshot)
    }
}
