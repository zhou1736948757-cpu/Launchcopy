import Foundation
import XCTest
@testable import PagingPrototypeApp

/// Resolver-only routing: no app, process, provider, preferences or diagnostic session.
final class GestureValidationStartupPlanTests: XCTestCase {
    private final class Fixture {
        let directory: URL
        let bundle: URL

        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("gesture-startup-" + UUID().uuidString)
                .resolvingSymlinksInPath().standardizedFileURL
            bundle = directory.appendingPathComponent(".build/candidates/gesture/GestureValidation.app")
            try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        }

        deinit { try? FileManager.default.removeItem(at: directory) }
    }

    private var marker: [String: Any] { ["version": 1, "profile": "gesture-01"] }
    private var environments: [[String: String]] {
        [[:], ["PAGING_PROTOTYPE_PERF": "1"], ["PAGING_PROTOTYPE_SMOKE": "1"],
         ["PAGING_PROTOTYPE_PERF": "1", "PAGING_PROTOTYPE_SMOKE": "1"],
         ["LAUNCHCOPY_STARTUP_CHECK": "1"],
         ["LAUNCHCOPY_STARTUP_CHECK": "1", "PAGING_PROTOTYPE_PERF": "1"],
         ["LAUNCHCOPY_STARTUP_CHECK": "1", "PAGING_PROTOTYPE_SMOKE": "1"],
         ["LAUNCHCOPY_STARTUP_CHECK": "1", "PAGING_PROTOTYPE_PERF": "1", "PAGING_PROTOTYPE_SMOKE": "1"]]
    }

    private func plan(_ fixture: Fixture, arguments: [String] = [], environment: [String: String] = [:],
                      id: String? = GestureValidationEntry.reservedBundleID,
                      gestureMetadata: Any?, uiTestMetadata: Any? = nil, bundleURL: URL? = nil)
        -> AppStartupPlan.Action {
        AppStartupPlan.resolve(arguments: arguments, environment: environment,
            bundleIdentifier: id, bundleURL: bundleURL ?? fixture.bundle,
            metadata: uiTestMetadata, gestureMetadata: gestureMetadata)
    }

    private func assertRejected(_ action: AppStartupPlan.Action, as expected: NativeUITestEntry.Rejection,
                                file: StaticString = #filePath, line: UInt = #line) {
        guard case .reject(let reason) = action else {
            return XCTFail("Invalid dedicated entry escaped startup validation", file: file, line: line)
        }
        XCTAssertEqual(reason, expected, file: file, line: line)
    }

    func testValidEntryRoutesToDedicatedApplicationWithoutParseErrorOrStorageWrites() throws {
        let fixture = try Fixture()
        guard case .application(let options, let error) = plan(fixture, gestureMetadata: marker) else {
            return XCTFail("Valid dedicated entry must reach its ordinary window route")
        }
        XCTAssertNil(error)
        XCTAssertTrue(options.gestureValidation)
        XCTAssertTrue(options.uiTestWindowed)
        XCTAssertFalse(options.fullscreen)
        XCTAssertEqual(options.uiTestProfile, "gesture-01")
        XCTAssertTrue(options.folderLab)
        XCTAssertFalse(FileManager.default.fileExists(atPath:
            fixture.bundle.deletingLastPathComponent().appendingPathComponent("UITestProfiles").path))
    }

    func testDedicatedEntryRejectsHeadlessDiagnosticsExceptPureStartupCheck() throws {
        let fixture = try Fixture()
        for environment in environments where !environment.isEmpty {
            let action = plan(fixture, environment: environment, gestureMetadata: marker)
            if environment["LAUNCHCOPY_STARTUP_CHECK"] == "1" {
                guard case .check(let options) = action else {
                    XCTFail("Validated startup check must precede all diagnostic flags")
                    continue
                }
                XCTAssertTrue(options.gestureValidation)
                XCTAssertEqual(options.uiTestProfile, "gesture-01")
                XCTAssertFalse(options.telemetryEnabled)
                XCTAssertFalse(options.frameProfile)
                XCTAssertFalse(options.helpRequested)
            } else {
                assertRejected(action, as: .invalidArguments)
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath:
            fixture.bundle.deletingLastPathComponent().appendingPathComponent("UITestProfiles").path))
    }

    func testMissingWrongMixedAndMalformedMarkersNeverBypassThroughAnyRoute() throws {
        let fixture = try Fixture()
        let invalid: [(String?, Any?, Any?)] = [
            (GestureValidationEntry.reservedBundleID, nil, nil),
            (GestureValidationEntry.reservedBundleID, NSNull(), nil),
            (GestureValidationEntry.reservedBundleID, ["version": true, "profile": "gesture-01"], nil),
            (GestureValidationEntry.reservedBundleID, ["version": 1.0, "profile": "gesture-01"], nil),
            (GestureValidationEntry.reservedBundleID, ["version": 1, "profile": "../gui"], nil),
            (GestureValidationEntry.reservedBundleID, ["version": 1, "profile": "gesture-01", "extra": 1], nil),
            (GestureValidationEntry.reservedBundleID, marker, marker),
            (GestureValidationEntry.reservedBundleID, nil, marker),
            (NativeUITestEntry.reservedBundleID, marker, marker),
            (NativeUITestEntry.reservedBundleID, marker, nil),
            ("com.launchcopy.app", marker, nil),
            (nil, marker, nil)]
        for environment in environments {
            for (id, gestureMarker, uiMarker) in invalid {
                assertRejected(plan(fixture, environment: environment, id: id,
                    gestureMetadata: gestureMarker, uiTestMetadata: uiMarker), as: .invalidMarker)
            }
        }
    }

    func testCLIOverridesAndBadProfileLocationRejectEvenStartupCheck() throws {
        let fixture = try Fixture()
        let arguments = [["--help"], ["--fullscreen"], ["--paging-telemetry"],
            ["--frame-profile"], ["--run-id", "fixture"], ["--catalog-root", "/SyntheticRoot"],
            ["--ui-test-windowed", "--ui-test-profile", "gesture-01"],
            ["--neutral-content"], ["--unknown"], ["-psn_0_12345"], ["positional"]]
        let outside = fixture.directory.appendingPathComponent("Outside.app")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        for environment in environments {
            for args in arguments {
                assertRejected(plan(fixture, arguments: args, environment: environment,
                    gestureMetadata: marker), as: .invalidArguments)
            }
            assertRejected(plan(fixture, environment: environment, gestureMetadata: marker,
                bundleURL: outside), as: .invalidProfileLocation)
        }
    }

    func testDirectNativeUITestResolverAlwaysRejectsDedicatedIdentity() throws {
        let fixture = try Fixture()
        for metadata in [nil, marker as Any?, ["version": 2, "profile": "gesture-01", "fixture": "sources-v1"] as Any?] {
            for args in [[], ["--help"], ["--ui-test-windowed", "--ui-test-profile", "gesture-01"]] {
                let result = NativeUITestEntry.resolve(arguments: args, parsed: .success(.default),
                    bundleIdentifier: GestureValidationEntry.reservedBundleID, bundleURL: fixture.bundle, metadata: metadata)
                guard case .failure(.invalidMarker) = result else {
                    XCTFail("Ordinary entry must never accept the reserved gesture identity")
                    continue
                }
            }
        }
    }

    func testLegacyFakeOnlyApplicationAndDiagnosticRoutesRemainUnchanged() throws {
        let fixture = try Fixture()
        for version in [1, 2] {
            var uiMarker: [String: Any] = ["version": version, "profile": "gui"]
            if version == 2 { uiMarker["fixture"] = "sources-v1" }
            for environment in environments {
                // Omit gestureMetadata to exercise backward-compatible call sites.
                let action = AppStartupPlan.resolve(arguments: [], environment: environment,
                    bundleIdentifier: NativeUITestEntry.reservedBundleID, bundleURL: fixture.bundle, metadata: uiMarker)
                switch action {
                case .check(let options), .application(let options, parseError: _):
                    XCTAssertFalse(options.gestureValidation)
                    XCTAssertTrue(options.uiTestWindowed)
                    XCTAssertEqual(options.uiTestProfile, "gui")
                case .performance:
                    XCTAssertEqual(environment["PAGING_PROTOTYPE_PERF"], "1")
                    XCTAssertNotEqual(environment["LAUNCHCOPY_STARTUP_CHECK"], "1")
                case .smoke:
                    XCTAssertEqual(environment["PAGING_PROTOTYPE_SMOKE"], "1")
                    XCTAssertNotEqual(environment["PAGING_PROTOTYPE_PERF"], "1")
                    XCTAssertNotEqual(environment["LAUNCHCOPY_STARTUP_CHECK"], "1")
                default:
                    XCTFail("Existing fake-only metadata must preserve its route")
                }
            }
        }
        let args = ["--ui-test-windowed", "--ui-test-profile", "gui"]
        let explicit = try NativeUITestEntry.resolve(arguments: args, bundleIdentifier: nil,
            bundleURL: fixture.bundle, metadata: nil).get()
        XCTAssertFalse(explicit.gestureValidation)
    }

    func testParserAndEnvironmentCannotEnableDedicatedMode() throws {
        XCTAssertFalse(AppArguments.Options.default.gestureValidation)
        for args in [[], ["--fullscreen"], ["--folder-lab"], ["--paging-telemetry"],
                     ["--ui-test-windowed", "--ui-test-profile", "gesture-01"]] {
            XCTAssertFalse(try AppArguments.parse(args).get().gestureValidation)
        }
        for flag in ["--gesture-validation", "--gesture-validation=true", "--real-gestures"] {
            guard case .failure(.unknownArgument(let argument)) = AppArguments.parse([flag]) else {
                XCTFail("No CLI switch may enable dedicated validation")
                continue
            }
            XCTAssertEqual(argument, flag)
        }
        let fixture = try Fixture()
        let environment = ["LAUNCHCOPY_STARTUP_CHECK": "1", "LAUNCHCOPY_GESTURE_VALIDATION": "1",
            "PAGING_PROTOTYPE_GESTURE_VALIDATION": "1"]
        guard case .check(let options) = plan(fixture, environment: environment, id: "com.launchcopy.app",
            gestureMetadata: nil) else {
            return XCTFail("Environment values alone must preserve ordinary startup")
        }
        XCTAssertEqual(options, .default)
    }
}
