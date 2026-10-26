import AppKit
import AppCatalogCore
import AppGridUI
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class CatalogHostRangeCommitTests: XCTestCase {
    private func snapshot(_ names: [String], revision: UInt64) -> CatalogSnapshot {
        .init(revision: CatalogRevision(revision), records: names.map { name in
            let id = CatalogFixture.appID("fixture.range.\(name)")
            return CatalogFixture.record(id: id, displayName: name, bundleID: "fixture.range.\(name)",
                url: CatalogFixture.tempURL(named: name + ".app"), icon: .from(appID: id), rootPriority: 0)
        })
    }

    func testNewCatalogRevisionCreatesHostsAfterEmptySearchWithoutResizeOrQueryChange() throws {
        let owner = AppDelegate(options: .default)
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticRange")], loader: RecordingIconLoader())
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        let search = AppSearchController(presentation: assembly.searchPresentation, keyboardController: nil, surface: surface)
        defer { search.teardown(); surface.teardown(); assembly.teardown() }
        surface.contentProvider = assembly.provider; surface.renderer = assembly.renderer
        owner.surface = surface; owner.assembly = assembly; owner.search = search
        owner.installCatalogPresentationCallbacks(assembly: assembly, surface: surface)
        assembly.provider.receive(snapshot(["Alpha"], revision: 1))
        owner.applyPendingAtIdleBoundary()
        surface.layoutSubtreeIfNeeded() // Establish unchanged viewport BEFORE the empty query.
        search.field.stringValue = "Watch Probe"
        search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
        XCTAssertEqual(surface.core.pageCount, 0)
        XCTAssertEqual(surface.liveHostCount, 0)
        let bounds = surface.bounds
        assembly.provider.receive(snapshot(["Alpha", "Watch Probe"], revision: 2))
        owner.applyPendingAtIdleBoundary()
        XCTAssertEqual(surface.bounds, bounds)
        XCTAssertEqual(search.field.stringValue, "Watch Probe")
        XCTAssertEqual(assembly.provider.activeQuery, AppSearchQuery(raw: "Watch Probe"))
        XCTAssertEqual(assembly.provider.servedPageCount, 1)
        XCTAssertEqual(surface.core.pageCount, 1)
        XCTAssertEqual(surface.liveHostCount, 1, "A committed matching result needs a mounted host, not only a provider count")
        let cell = try XCTUnwrap(assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        XCTAssertEqual(cell.nameLabel.stringValue, "Watch Probe")
        XCTAssertEqual(surface.servedRevision, 2)
        owner.applyPendingAtIdleBoundary()
        XCTAssertEqual(surface.liveHostCount, 1)
    }

    func testDirectRevisionCommitFromZeroCreatesHostsWithoutOffsetEvent() throws {
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticRange")], loader: RecordingIconLoader())
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        defer { surface.teardown(); assembly.teardown() }
        surface.contentProvider = assembly.provider; surface.renderer = assembly.renderer
        assembly.provider.receive(snapshot([], revision: 1))
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        surface.refreshPresentation()
        XCTAssertEqual(surface.liveHostCount, 0)
        assembly.provider.receive(snapshot(["New"], revision: 2))
        _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
        var offsetEvents = 0
        surface.appEvents.onVisualOffsetChange = { _ in offsetEvents += 1 }
        surface.refreshPresentation()
        XCTAssertEqual(offsetEvents, 0)
        XCTAssertEqual(surface.liveHostCount, 1)
        let cell = try XCTUnwrap(assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        XCTAssertEqual(cell.nameLabel.stringValue, "New")
    }

    func testNewRevisionGrowthAndShrinkReconcileOnlyNeededHostRange() {
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticRange")], loader: RecordingIconLoader())
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        defer { surface.teardown(); assembly.teardown() }
        surface.contentProvider = assembly.provider; surface.renderer = assembly.renderer
        func present(_ count: Int, revision: UInt64) {
            assembly.provider.receive(snapshot((0..<count).map { "App\($0)" }, revision: revision))
            _ = assembly.commitPendingAtIdleBoundary(currentPage: 0)
            surface.refreshPresentation()
        }
        present(1, revision: 1)
        let oldLayoutCount = surface.layoutPerformedCount
        present(1, revision: 2)
        XCTAssertEqual(surface.layoutPerformedCount, oldLayoutCount, "Same host range needs no extra layout")
        present(71, revision: 3)
        XCTAssertEqual(surface.core.pageCount, 3)
        XCTAssertEqual(surface.liveHostCount, 3)
        present(1, revision: 4)
        XCTAssertEqual(surface.liveHostCount, 1)
        XCTAssertEqual(surface.core.visualOffset, 0)
        XCTAssertEqual(surface.core.commitCount, 0)
    }
}
