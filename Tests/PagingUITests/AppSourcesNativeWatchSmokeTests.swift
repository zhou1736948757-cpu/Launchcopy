import Foundation
import XCTest
@testable import PagingPrototypeApp

/// Public native adapter only on temporary synthetic roots; no GUI/user directories.
/// OS coverage is reported separately from injected deterministic watcher tests.
@MainActor
final class AppSourcesNativeWatchSmokeTests: XCTestCase {
    func testNativeRecursiveStreamSignalsInstallationInsideExistingNestedFolder() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let nested = root.appendingPathComponent("Tools/Nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let watcher = FSEventsAppSourceWatcher()
        defer { watcher.stop(); try? FileManager.default.removeItem(at: root) }
        let changed = expectation(description: "Neutral nested filesystem invalidation")
        changed.assertForOverFulfill = false
        let status = await watcher.replaceRoots([root]) { changed.fulfill() }
        guard status == .active else {
            throw XCTSkip("Native temporary-root event service unavailable or degraded; not a runtime PASS")
        }
        // The watched root and both ancestors already existed before SinceNow setup;
        // only the nested application location changes after the stream starts.
        let contents = nested.appendingPathComponent("Synthetic.app/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        try Data("synthetic metadata fixture".utf8).write(to: contents.appendingPathComponent("Marker"))
        await fulfillment(of: [changed], timeout: 8)
    }
}
