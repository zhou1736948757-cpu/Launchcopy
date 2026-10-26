import Foundation
import XCTest
@testable import PagingPrototypeApp

final class AppStartupPlanTests: XCTestCase {
    private let rawURL = URL(fileURLWithPath: "/SyntheticOutside.app")
    private func plan(_ args: [String], env: [String: String], metadata: Any? = nil,
                      id: String? = nil, url: URL? = nil) -> AppStartupPlan.Action {
        AppStartupPlan.resolve(arguments: args, environment: env, bundleIdentifier: id,
            bundleURL: url ?? rawURL, metadata: metadata)
    }

    func testExplicitTestIntentCannotReachPerformanceOrSmokeBeforeValidation() {
        for env in [["PAGING_PROTOTYPE_PERF": "1"], ["PAGING_PROTOTYPE_SMOKE": "1"],
                    ["PAGING_PROTOTYPE_PERF": "1", "PAGING_PROTOTYPE_SMOKE": "1"]] {
            for args in [["--ui-test-profile", "../gui"], ["--UI-TEST-PROFILE=gui"],
                         ["--ui-test-windowed", "--unknown-fixture"],
                         ["--ui-test-windowed", "--ui-test-profile", "gui"]] {
                guard case .reject = plan(args, env: env) else {
                    XCTFail("Explicit isolated intent must preflight before diagnostic work")
                    continue
                }
            }
        }
    }

    func testCheckPrecedesDiagnosticsHelpCompositedAndLegacyErrorOutput() {
        let env = ["LAUNCHCOPY_STARTUP_CHECK": "1", "PAGING_PROTOTYPE_PERF": "1", "PAGING_PROTOTYPE_SMOKE": "1"]
        for args in [[], ["--help"], ["--page-hosting", "composited"], ["--private-fixture-name"]] {
            guard case .check = plan(args, env: env) else {
                XCTFail("Check must carry only resolved options, not verbose/diagnostic routing")
                continue
            }
        }
        for args in [["--ui-test-windowed", "--private-fixture-name"], ["--momentum-decay", "invalid"]] {
            guard case .reject = plan(args, env: env) else {
                XCTFail("Check rejection must be neutral rather than legacy raw-error output")
                continue
            }
        }
    }

    func testOrdinaryHeadlessDiagnosticPrecedenceAndLegacyApplicationBehaviorRemain() {
        guard case .performance = plan(["--unknown-fixture"], env: ["PAGING_PROTOTYPE_PERF": "1", "PAGING_PROTOTYPE_SMOKE": "1"]) else {
            return XCTFail("Ordinary legacy performance still precedes parsing/smoke")
        }
        guard case .smoke = plan(["--unknown-fixture"], env: ["PAGING_PROTOTYPE_SMOKE": "1"]) else {
            return XCTFail("Ordinary smoke keeps its own parsing/reporting path")
        }
        guard case .application(let options, let error) = plan(["--unknown-fixture"], env: [:]) else {
            return XCTFail("Ordinary application error preserves fallback")
        }
        XCTAssertEqual(options, .default)
        XCTAssertEqual(error, .unknownArgument("--unknown-fixture"))
        guard case .legacyReject(.invalidMomentumDecay("invalid")) = plan(["--momentum-decay", "invalid"], env: [:]) else {
            return XCTFail("Ordinary fatal tuning diagnostics remain their legacy route")
        }
    }

    func testMarkedOrReservedBadMetadataCannotReachAnyDiagnosticBranch() {
        for env in [[:], ["PAGING_PROTOTYPE_PERF": "1"], ["PAGING_PROTOTYPE_SMOKE": "1"], ["LAUNCHCOPY_STARTUP_CHECK": "1"]] {
            for (id, marker) in [(NativeUITestEntry.reservedBundleID, nil),
                                 ("com.launchcopy.app", ["version": 1, "profile": "gui"] as Any?)] {
                guard case .reject(.invalidMarker) = plan([], env: env, metadata: marker, id: id) else {
                    XCTFail("Bundle test intent must never escape validation")
                    continue
                }
            }
        }
    }

    func testValidExplicitProfilePreflightsWithoutCreatingStorageBeforePerformance() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("startup-plan-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent(".build/candidates/fixture/Test.app")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let args = ["--ui-test-windowed", "--ui-test-profile", "gui"]
        guard case .performance = plan(args, env: ["PAGING_PROTOTYPE_PERF": "1"], url: url) else {
            return XCTFail("A validated explicit profile may enter its requested diagnostic mode")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.deletingLastPathComponent().appendingPathComponent("UITestProfiles").path))
        guard case .check(let options) = plan(args, env: ["LAUNCHCOPY_STARTUP_CHECK": "1", "PAGING_PROTOTYPE_PERF": "1"], url: url) else {
            return XCTFail("Neutral check must still win after successful validation")
        }
        XCTAssertTrue(options.uiTestWindowed)
        XCTAssertEqual(options.uiTestProfile, "gui")
    }
}
