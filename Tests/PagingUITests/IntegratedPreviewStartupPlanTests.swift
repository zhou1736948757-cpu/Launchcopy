import Foundation
import XCTest
@testable import PagingPrototypeApp

final class IntegratedPreviewStartupPlanTests: XCTestCase {
    private var marker: [String: Any] { ["version": 1, "profile": "integrated"] }
    private func withBundle(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .resolvingSymlinksInPath()
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = root.appendingPathComponent(".build/candidates/preview/Preview.app")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        try body(bundle)
    }
    private func plan(_ bundle: URL, environment: [String: String] = [:], arguments: [String] = [],
                      id: String = IntegratedPreviewEntry.reservedBundleID,
                      preview: Any? = nil, ui: Any? = nil, gesture: Any? = nil) -> AppStartupPlan.Action {
        AppStartupPlan.resolve(arguments: arguments, environment: environment, bundleIdentifier: id,
            bundleURL: bundle, metadata: ui, gestureMetadata: gesture, integratedMetadata: preview)
    }
    private func reject(_ action: AppStartupPlan.Action, file: StaticString = #filePath, line: UInt = #line) {
        guard case .reject = action else { return XCTFail("Expected strict rejection", file: file, line: line) }
    }
    func testExactEntryAndPureCheckReachOnlyPreviewWithNoStorageCreation() throws {
        try withBundle { bundle in
            for check in [false, true] {
                let result = plan(bundle, environment: check ? ["LAUNCHCOPY_STARTUP_CHECK": "1"] : [:], preview: marker)
                let options: AppArguments.Options
                if check {
                    guard case .check(let value) = result else { return XCTFail("Expected pure check") }
                    options = value
                } else {
                    guard case .application(let value, nil) = result else { return XCTFail("Expected preview") }
                    options = value
                }
                XCTAssertTrue(options.integratedPreview)
                XCTAssertFalse(options.gestureValidation)
                XCTAssertFalse(options.folderLab)
                XCTAssertFalse(options.telemetryEnabled)
                XCTAssertTrue(options.catalogRoots.isEmpty)
                XCTAssertEqual(options.uiTestProfile, "integrated")
                XCTAssertFalse(FileManager.default.fileExists(atPath: bundle.deletingLastPathComponent()
                    .appendingPathComponent("UITestProfiles").path))
            }
        }
    }
    func testEveryDiagnosticEnvironmentRefusesEvenCombinedStartupCheck() throws {
        try withBundle { bundle in
            for key in ["PAGING_PROTOTYPE_PERF", "PAGING_PROTOTYPE_SMOKE", "PAGING_PROTOTYPE_GUI_SELFDRIVE"] {
                for check in [false, true] {
                    var environment = [key: "1"]
                    if check { environment["LAUNCHCOPY_STARTUP_CHECK"] = "1" }
                    reject(plan(bundle, environment: environment, preview: marker))
                }
            }
        }
    }
    func testMissingWrongAndMixedMarkersNeverReachLegacyRoutes() throws {
        try withBundle { bundle in
            for environment in [[:], ["PAGING_PROTOTYPE_PERF": "1"], ["LAUNCHCOPY_STARTUP_CHECK": "1"]] {
                reject(plan(bundle, environment: environment))
                reject(plan(bundle, environment: environment, preview: marker, ui: marker))
                reject(plan(bundle, environment: environment, preview: marker, gesture: marker))
                for id in ["com.launchcopy.app", NativeUITestEntry.reservedBundleID, GestureValidationEntry.reservedBundleID] {
                    reject(plan(bundle, environment: environment, id: id, preview: marker))
                }
            }
            guard case .failure = NativeUITestEntry.resolve(arguments: [], bundleIdentifier: IntegratedPreviewEntry.reservedBundleID,
                bundleURL: bundle, metadata: nil) else { return XCTFail("Legacy resolver must refuse preview identity") }
        }
    }
    func testCLIAndBadLocationNeverObtainPreviewCapabilities() throws {
        try withBundle { bundle in
            for arguments in [["--help"], ["--catalog-root", "/Applications"], ["--ui-test-profile", "integrated"]] {
                reject(plan(bundle, arguments: arguments, preview: marker))
            }
            reject(plan(bundle.deletingLastPathComponent(), preview: marker))
        }
    }
    func testOldUIAndGestureEntriesDoNotAcquireIntegratedFlag() throws {
        try withBundle { bundle in
            for gesture in [false, true] {
                let result = plan(bundle, id: gesture ? GestureValidationEntry.reservedBundleID : NativeUITestEntry.reservedBundleID,
                    ui: gesture ? nil : marker, gesture: gesture ? marker : nil)
                guard case .application(let options, nil) = result else { return XCTFail("Old entry changed") }
                XCTAssertFalse(options.integratedPreview)
                XCTAssertEqual(options.gestureValidation, gesture)
            }
        }
    }
}
