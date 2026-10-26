import AppCatalogCore
import AppGridUI
import Dispatch
import Foundation
import XCTest

/// Controlled synthetic work only; never a physical-input or pre-migration AB gate.
@MainActor
final class IdentifierSearchWorkloadTests: XCTestCase {
    func testControlledNameAndIdentifierWorkloadsKeepExpectedResults() throws {
        let records: [AppRecord] = (0..<1_000).map { index in
            let bundle = "com.fixture.identifier-benchmark.\(index)"
            let id = AppID.bundleIdentifier(bundle)
            return .init(id: id, displayName: "Synthetic \(index)", bundleIdentifier: bundle,
                         canonicalURL: URL(fileURLWithPath: "/SyntheticBenchmark/\(index).app"),
                         iconIdentity: .from(appID: id), sourceRootPriority: 0)
        }
        let catalog = CatalogSnapshot(revision: .init(1), records: records)
        var observations: [[String: Any]] = []
        for enabled in [false, true] {
            let management = AppManagementPreferences(searchByBundleIdentifier: enabled)
            for identifierQuery in [false, true] {
                let raw = identifierQuery ? "com.fixture.identifier-benchmark." : "Synthetic"
                let expected = identifierQuery && !enabled ? 0 : records.count
                for iteration in 0..<3 {
                    let provider = AppGridUIPageContentProvider()
                    let grid = AppGridSearchPresentationController(provider: provider)
                    provider.receiveManagementPreferences(management)
                    grid.receive(catalog)
                    _ = grid.applyPendingAtIdleBoundary(currentPage: 0)
                    let started = DispatchTime.now().uptimeNanoseconds
                    grid.updateQuery(.init(raw: raw, locale: Locale(identifier: "en_US_POSIX")))
                    _ = grid.applyPendingAtIdleBoundary(currentPage: 0)
                    let gridElapsed = DispatchTime.now().uptimeNanoseconds - started
                    let libraryStarted = DispatchTime.now().uptimeNanoseconds
                    let library = AppLibraryProjection.make(catalog: catalog, management: management,
                        preferences: .init(), query: raw, locale: Locale(identifier: "en_US_POSIX"))
                    let libraryElapsed = DispatchTime.now().uptimeNanoseconds - libraryStarted
                    XCTAssertEqual(provider.presentationRecords.count, expected)
                    XCTAssertEqual(library.entries.count, expected)
                    observations.append(["identifier_mode": enabled, "identifier_query": identifierQuery,
                                         "iteration": iteration, "records": records.count, "matches": expected,
                                         "grid_nanoseconds": gridElapsed, "library_nanoseconds": libraryElapsed])
                }
            }
        }
        // Explicit test-only output with no query/identifier/path fields. All inputs
        // above are independently authored fixtures, not a user's app inventory.
        if let output = ProcessInfo.processInfo.environment["IDENTIFIER_SEARCH_WORKLOAD_OUTPUT"] {
            let data = try JSONSerialization.data(withJSONObject: ["synthetic_only": true,
                "physical_gate": false, "pre_migration_comparison": false, "samples": observations],
                options: [.sortedKeys, .prettyPrinted])
            try data.write(to: URL(fileURLWithPath: output), options: .atomic)
        }
    }
}
