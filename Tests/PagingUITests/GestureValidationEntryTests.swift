import Foundation
import XCTest
@testable import PagingPrototypeApp

/// Pure entry resolution using owned temporary paths, without services or preferences.
final class GestureValidationEntryTests: XCTestCase {
    private final class Fixture {
        let directory: URL
        let bundle: URL

        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("gesture-entry-" + UUID().uuidString)
                .resolvingSymlinksInPath().standardizedFileURL
            bundle = directory.appendingPathComponent(".build/candidates/gesture/GestureValidation.app")
            try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        }

        deinit { try? FileManager.default.removeItem(at: directory) }
    }

    private var marker: [String: Any] { ["version": 1, "profile": "gesture-01"] }

    private func resolve(_ fixture: Fixture, arguments: [String] = [], metadata: Any?,
                         bundleID: String? = GestureValidationEntry.reservedBundleID,
                         uiTestMetadata: Any? = nil)
        -> Result<AppArguments.Options, NativeUITestEntry.Rejection> {
        GestureValidationEntry.resolve(arguments: arguments, bundleIdentifier: bundleID,
            bundleURL: fixture.bundle, metadata: metadata, uiTestMetadata: uiTestMetadata)
    }

    private func assertRejected(_ result: Result<AppArguments.Options, NativeUITestEntry.Rejection>,
                                as expected: NativeUITestEntry.Rejection,
                                file: StaticString = #filePath, line: UInt = #line) {
        guard case .failure(let reason) = result else {
            return XCTFail("Expected fail-closed entry resolution", file: file, line: line)
        }
        XCTAssertEqual(reason, expected, file: file, line: line)
    }

    func testExactIdentityAndMarkerForceOnlyDedicatedIsolatedWindowOptionsWithoutWrites() throws {
        let fixture = try Fixture()
        XCTAssertEqual(GestureValidationEntry.metadataKey, "LaunchcopyGestureValidationEntry")
        XCTAssertEqual(GestureValidationEntry.reservedBundleID, "com.launchcopy.gesture-validation")
        XCTAssertNotEqual(GestureValidationEntry.metadataKey, NativeUITestEntry.metadataKey)
        XCTAssertNotEqual(GestureValidationEntry.reservedBundleID, NativeUITestEntry.reservedBundleID)

        let options = try resolve(fixture, metadata: marker).get()
        var expected = AppArguments.Options.default
        expected.gestureValidation = true
        expected.uiTestWindowed = true
        expected.uiTestProfile = "gesture-01"
        expected.folderLab = true
        XCTAssertEqual(options, expected, "Content and diagnostics must retain safe defaults")
        XCTAssertFalse(options.fullscreen)
        let profile = try UITestProfile.resolve(bundleURL: fixture.bundle, profileID: "gesture-01")
        XCTAssertFalse(FileManager.default.fileExists(atPath: profile.rootURL.deletingLastPathComponent().path))
        XCTAssertEqual(try resolve(fixture, metadata: marker).get(), options)
        XCTAssertFalse(FileManager.default.fileExists(atPath: profile.rootURL.path))
    }

    func testPropertyListIntegerMarkerIsAcceptedAndBooleanOrRealIsRejected() throws {
        let fixture = try Fixture()
        for format in [PropertyListSerialization.PropertyListFormat.xml, .binary] {
            for (version, valid) in [(1 as Any, true), (true as Any, false), (1.0 as Any, false)] {
                let data = try PropertyListSerialization.data(
                    fromPropertyList: ["version": version, "profile": "gesture-01"], format: format, options: 0)
                let metadata = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                if valid {
                    XCTAssertTrue(try resolve(fixture, metadata: metadata).get().gestureValidation)
                } else {
                    assertRejected(resolve(fixture, metadata: metadata), as: .invalidMarker)
                }
            }
        }
    }

    func testMissingMalformedFutureAndExtraMarkerFieldsReject() throws {
        let fixture = try Fixture()
        let invalid: [Any?] = [nil, NSNull(), "gesture-01", [], [:],
            ["version": 1], ["profile": "gesture-01"],
            ["version": true, "profile": "gesture-01"],
            ["version": false, "profile": "gesture-01"],
            ["version": 1.0, "profile": "gesture-01"],
            ["version": "1", "profile": "gesture-01"],
            ["version": 0, "profile": "gesture-01"],
            ["version": 2, "profile": "gesture-01"],
            ["version": NSNumber(value: UInt64.max), "profile": "gesture-01"],
            ["version": NSNull(), "profile": "gesture-01"],
            ["version": 1, "profile": 1],
            ["version": 1, "profile": "gesture-01", "fixture": "sources-v1"],
            ["version": 1, "profile": "gesture-01", "backend": "real"]]
        for metadata in invalid {
            assertRejected(resolve(fixture, metadata: metadata), as: .invalidMarker)
        }
    }

    func testWrongIdentityAndAnyMixedUITestMarkerReject() throws {
        let fixture = try Fixture()
        let wrongIDs: [String?] = [nil, "", "com.launchcopy.app", NativeUITestEntry.reservedBundleID,
            "com.launchcopy.gesture-validation.other", "COM.LAUNCHCOPY.GESTURE-VALIDATION"]
        for id in wrongIDs {
            assertRejected(resolve(fixture, metadata: marker, bundleID: id), as: .invalidMarker)
        }
        let mixed: [Any] = [["version": 1, "profile": "gesture-01"],
            ["version": 2, "profile": "gesture-01", "fixture": "sources-v1"], [:], "invalid", NSNull()]
        for uiMarker in mixed {
            assertRejected(resolve(fixture, metadata: marker, uiTestMetadata: uiMarker), as: .invalidMarker)
        }
    }

    func testInvalidProfileIDsRejectBeforeAnyStorageIsCreated() throws {
        let fixture = try Fixture()
        for id in ["", "../gui", "/tmp/gui", "a/b", "a\\b", "GUI", "a_b", "a.b", " a", "a\n",
                   "é", String(repeating: "a", count: 49)] {
            assertRejected(resolve(fixture, metadata: ["version": 1, "profile": id]), as: .invalidMarker)
        }
        let profiles = fixture.bundle.deletingLastPathComponent().appendingPathComponent("UITestProfiles")
        XCTAssertFalse(FileManager.default.fileExists(atPath: profiles.path))
    }

    func testEveryCLIArgumentRejectsIncludingMatchingProfilesHelpAndProcessSerial() throws {
        let fixture = try Fixture()
        let arguments = [["--help"], ["-h"], ["--fullscreen"], ["--folder-lab"],
            ["--ui-test-windowed"], ["--ui-test-windowed", "--ui-test-profile", "gesture-01"],
            ["--ui-test-windowed", "--ui-test-profile", "other"],
            ["--catalog-root", "/SyntheticRoot"], ["--neutral-content"],
            ["--paging-lab"], ["--paging-telemetry"], ["--run-id", "fixture"],
            ["--frame-profile"], ["--frame-callback-profile"], ["--runloop-profile"],
            ["--disable-telemetry-bridge"], ["--frame-driver", "displaylink"],
            ["--page-hosting", "composited"], ["--page-count", "5"], ["--items-per-page", "35"],
            ["--momentum-decay", "invalid"], ["--gesture-validation"],
            ["--gesture-validation=true"], ["--unknown"], ["-psn_0_12345"], ["positional"], [""]]
        for args in arguments {
            assertRejected(resolve(fixture, arguments: args, metadata: marker), as: .invalidArguments)
        }
        assertRejected(resolve(fixture, arguments: ["--help"], metadata: nil), as: .invalidMarker)
    }

    func testOutsideMissingNonAppAndRemoteBundleLocationsReject() throws {
        let fixture = try Fixture()
        for path in ["Outside.app", ".build/candidates-other/gesture/Test.app", ".build/candidates/Test.app"] {
            let outside = fixture.directory.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
            assertRejected(GestureValidationEntry.resolve(arguments: [],
                bundleIdentifier: GestureValidationEntry.reservedBundleID, bundleURL: outside,
                metadata: marker, uiTestMetadata: nil), as: .invalidProfileLocation)
        }
        let missing = fixture.bundle.deletingLastPathComponent().appendingPathComponent("Missing.app")
        let file = fixture.bundle.deletingLastPathComponent().appendingPathComponent("File.app")
        try Data().write(to: file)
        let remote = try XCTUnwrap(URL(string: "https://example.invalid/.build/candidates/gesture/Test.app"))
        for url in [missing, file, fixture.bundle.deletingLastPathComponent(), remote] {
            assertRejected(GestureValidationEntry.resolve(arguments: [],
                bundleIdentifier: GestureValidationEntry.reservedBundleID, bundleURL: url,
                metadata: marker, uiTestMetadata: nil), as: .invalidProfileLocation)
        }
    }

    func testBundleSymlinkOutsideCandidateTreeRejectsCanonicalLocation() throws {
        let fixture = try Fixture()
        let outside = fixture.directory.appendingPathComponent("Outside.app")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let alias = fixture.bundle.deletingLastPathComponent().appendingPathComponent("Alias.app")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: outside)
        assertRejected(GestureValidationEntry.resolve(arguments: [],
            bundleIdentifier: GestureValidationEntry.reservedBundleID, bundleURL: alias,
            metadata: marker, uiTestMetadata: nil), as: .invalidProfileLocation)
    }

    func testEveryProfileOutputRejectsSymlinksAndFileCollisions() throws {
        for component in ["", "gesture-01", "gesture-01/Layout", "gesture-01/Applications",
                          "gesture-01/WallpaperCache", "gesture-01/Library", "gesture-01/LaunchActivity"] {
            for symlink in [false, true] {
                let fixture = try Fixture()
                let profiles = fixture.bundle.deletingLastPathComponent().appendingPathComponent("UITestProfiles")
                let target = component.isEmpty ? profiles : profiles.appendingPathComponent(component)
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                if symlink {
                    // A dangling link must be rejected even before its destination exists.
                    try FileManager.default.createSymbolicLink(at: target,
                        withDestinationURL: fixture.directory.appendingPathComponent("missing"))
                } else {
                    try Data().write(to: target)
                }
                assertRejected(resolve(fixture, metadata: marker), as: .invalidProfileLocation)
                XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.directory.appendingPathComponent("missing").path))
            }
        }
    }
}
