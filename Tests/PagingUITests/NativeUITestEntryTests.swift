import Foundation
import XCTest
@testable import PagingPrototypeApp

final class NativeUITestEntryTests: XCTestCase {
    private final class Fixture {
        let directory: URL
        let bundle: URL
        init() throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("native-entry-" + UUID().uuidString)
            bundle = directory.appendingPathComponent(".build/candidates/fixture/LaunchcopyUITest.app")
            try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        }
        deinit { try? FileManager.default.removeItem(at: directory) }
    }

    private var marker: [String: Any] { ["version": 1, "profile": "gui"] }
    private func resolve(_ fixture: Fixture, arguments: [String] = [], metadata: Any?,
                         bundleID: String? = NativeUITestEntry.reservedBundleID)
        -> Result<AppArguments.Options, NativeUITestEntry.Rejection> {
        NativeUITestEntry.resolve(arguments: arguments, bundleIdentifier: bundleID,
            bundleURL: fixture.bundle, metadata: metadata)
    }
    private func rejection(_ result: Result<AppArguments.Options, NativeUITestEntry.Rejection>)
        -> NativeUITestEntry.Rejection? {
        if case .failure(let reason) = result { return reason }
        XCTFail("Expected fail-closed startup")
        return nil
    }

    func testDirectNativeMarkerSelectsSameIsolatedOptionsWithoutCreatingProfileDirectories() throws {
        let f = try Fixture()
        let options = try resolve(f, metadata: marker).get()
        XCTAssertTrue(options.uiTestWindowed)
        XCTAssertFalse(options.fullscreen)
        XCTAssertTrue(options.folderLab)
        XCTAssertEqual(options.uiTestProfile, "gui")
        XCTAssertTrue(options.catalogRoots.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: f.bundle.deletingLastPathComponent().appendingPathComponent("UITestProfiles").path))
        let profile = try UITestProfile.resolve(bundleURL: f.bundle, profileID: "gui")
        XCTAssertNotEqual(profile.appearanceSuiteName, UserDefaultsAppearancePreferencesStore.defaultSuiteName)
        XCTAssertNotEqual(profile.activationSuiteName, UserDefaultsActivationPreferencesStore.defaultSuiteName)
        XCTAssertNotEqual(profile.languageSuiteName, UserDefaultsLanguagePreferencesStore.defaultSuiteName)
    }

    func testProductionAndRawDeveloperNoMarkerPreserveDefaultsAndLegacyFallback() throws {
        let f = try Fixture()
        let ids: [String?] = [nil, "com.launchcopy.app"]
        for id in ids {
            XCTAssertEqual(try resolve(f, metadata: nil, bundleID: id).get(), .default)
            XCTAssertEqual(try resolve(f, arguments: ["--unknown-fixture"], metadata: nil, bundleID: id).get(), .default)
            let fullscreen = try resolve(f, arguments: ["--fullscreen"], metadata: nil, bundleID: id).get()
            XCTAssertTrue(fullscreen.fullscreen)
            XCTAssertFalse(fullscreen.uiTestWindowed)
            XCTAssertNil(fullscreen.uiTestProfile)
        }
    }

    func testReservedMissingWrongBundleMalformedAndFutureMarkersRejectEvenHelp() throws {
        let f = try Fixture()
        let bad: [Any?] = [nil, "gui", ["version": 1], ["profile": "gui"],
            ["version": true, "profile": "gui"], ["version": 1.0, "profile": "gui"],
            ["version": 2, "profile": "gui"], ["version": "1", "profile": "gui"],
            ["version": 1, "profile": "../gui"], ["version": 1, "profile": "GUI"],
            ["version": 1, "profile": "gui", "command": "never-run"]]
        for metadata in bad {
            XCTAssertEqual(rejection(resolve(f, arguments: ["--help"], metadata: metadata)), .invalidMarker)
        }
        XCTAssertEqual(rejection(resolve(f, metadata: marker, bundleID: "com.launchcopy.app")), .invalidMarker)
        XCTAssertEqual(rejection(resolve(f, metadata: marker, bundleID: nil)), .invalidMarker)
    }

    func testExplicitSameProfileRunnerRemainsCompatibleAndFullscreenCannotEscapeWindowedMode() throws {
        let f = try Fixture()
        let options = try resolve(f, arguments: ["--ui-test-windowed", "--ui-test-profile", "gui", "--folder-lab"], metadata: marker).get()
        XCTAssertEqual(options, try resolve(f, metadata: marker).get())
        let fullscreen = try resolve(f, arguments: ["--fullscreen"], metadata: marker).get()
        XCTAssertFalse(fullscreen.fullscreen)
        XCTAssertTrue(fullscreen.uiTestWindowed)
        XCTAssertEqual(try resolve(f, arguments: ["--ui-test-windowed"], metadata: marker).get().uiTestProfile, "gui")
        XCTAssertTrue(try resolve(f, arguments: ["--help"], metadata: marker).get().helpRequested)
    }

    func testConflictingProfileContentAndInvalidArgumentsNeverFallbackToProduction() throws {
        let f = try Fixture()
        XCTAssertEqual(rejection(resolve(f, arguments: ["--ui-test-windowed", "--ui-test-profile", "other"], metadata: marker)), .conflictingProfile)
        for args in [["--catalog-root", "/SyntheticRoot"], ["--neutral-content"]] {
            XCTAssertEqual(rejection(resolve(f, arguments: args, metadata: marker)), .conflictingContent)
        }
        for args in [["--unknown-fixture"], ["--page-count", "zero"], ["--run-id"],
                     ["--ui-test-profile", "gui"], ["--ui-test-windowed", "--ui-test-profile", "../gui"]] {
            XCTAssertEqual(rejection(resolve(f, arguments: args, metadata: marker)), .invalidArguments)
        }
        XCTAssertEqual(rejection(resolve(f, arguments: ["--ui-test-windowed", "--page-count", "zero"], metadata: nil, bundleID: "com.launchcopy.app")), .invalidArguments)
    }

    func testMarkedAndExplicitProfileRejectOutsideCandidateAndUnsafeProfileDirectories() throws {
        let f = try Fixture()
        let outside = f.directory.appendingPathComponent("Outside.app")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        XCTAssertEqual(rejection(NativeUITestEntry.resolve(arguments: [], bundleIdentifier: NativeUITestEntry.reservedBundleID,
            bundleURL: outside, metadata: marker)), .invalidProfileLocation)
        XCTAssertEqual(rejection(NativeUITestEntry.resolve(arguments: ["--ui-test-windowed", "--ui-test-profile", "gui"],
            bundleIdentifier: "com.launchcopy.app", bundleURL: outside, metadata: nil)), .invalidProfileLocation)
        let profiles = f.bundle.deletingLastPathComponent().appendingPathComponent("UITestProfiles")
        try FileManager.default.createDirectory(at: profiles, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: profiles.appendingPathComponent("gui"), withDestinationURL: f.directory)
        XCTAssertEqual(rejection(resolve(f, metadata: marker)), .invalidProfileLocation)
    }
}
