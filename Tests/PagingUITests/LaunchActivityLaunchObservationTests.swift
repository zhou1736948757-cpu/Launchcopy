import AppCatalogCore
import AppGridUI
import AppKit
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

private struct ActivityHookLauncher: AppLaunching {
    let open: @Sendable () -> Bool
    func openApplication(at url: URL) -> Bool { open() }
}

@MainActor
final class LaunchActivityLaunchObservationTests: XCTestCase {
    func testCommonCellAndDirectLaunchCountOnlyExecutorAcceptances() async throws {
        let factory = try FakeAppFactory(prefix: "activity-launch")
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        defer { assembly.teardown(); surface.teardown(); factory.removeRoot() }
        _ = try factory.makeApps(names: ["Activity"])
        wireAssembly(assembly, to: surface); assembly.begin()
        let ready = await waitUntil { assembly.provider.servedSnapshot != nil }; XCTAssertTrue(ready)
        let snapshot = try XCTUnwrap(assembly.provider.servedSnapshot)
        let record = try XCTUnwrap(snapshot.records.first)
        let cell = try XCTUnwrap(assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let launcher = RecordingLauncher()
        let controller = AppLaunchController(surface: surface, assembly: assembly, launcher: launcher)
        var prepared = 0, accepted = 0
        controller.prepareLaunchObservation = { target in
            XCTAssertEqual(target.id, record.id); prepared += 1
            return { accepted += 1 }
        }
        XCTAssertEqual(controller.handleCell(cell), .launched)
        XCTAssertEqual(controller.handleApp(appID: record.id, expectedRevision: snapshot.revision, expectedURL: record.canonicalURL), .launched)
        XCTAssertEqual(prepared, 2); XCTAssertEqual(accepted, 2)
        launcher.shouldSucceed = false
        XCTAssertEqual(controller.handleCell(cell), .failedToLaunch)
        XCTAssertEqual(prepared, 3); XCTAssertEqual(accepted, 2)
        XCTAssertEqual(controller.handleApp(appID: record.id, expectedRevision: .init(snapshot.revision.value + 1), expectedURL: record.canonicalURL), .rejectedStaleRevision)
        XCTAssertEqual(prepared, 3); XCTAssertEqual(accepted, 2)
    }

    func testObserverPreparedBeforeExternalExecutorAndCanBeRevoked() async throws {
        let factory = try FakeAppFactory(prefix: "activity-reentrant")
        let surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        defer { assembly.teardown(); surface.teardown(); factory.removeRoot() }
        _ = try factory.makeApps(names: ["Activity"])
        wireAssembly(assembly, to: surface); assembly.begin()
        let ready = await waitUntil { assembly.provider.servedSnapshot != nil }; XCTAssertTrue(ready)
        let cell = try XCTUnwrap(assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        var stage: [String] = []
        let launcher = ActivityHookLauncher(open: {
            MainActor.assumeIsolated { stage.append("executor") }; return true
        })
        let controller = AppLaunchController(surface: surface, assembly: assembly, launcher: launcher)
        controller.prepareLaunchObservation = { _ in
            stage.append("prepare")
            return { stage.append("accepted") }
        }
        XCTAssertEqual(controller.handleCell(cell), .launched)
        XCTAssertEqual(stage, ["prepare", "executor", "accepted"])
    }
}
