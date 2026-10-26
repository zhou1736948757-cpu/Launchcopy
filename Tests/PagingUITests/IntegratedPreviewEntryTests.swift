import Foundation
import XCTest
@testable import PagingPrototypeApp

/// Owned temporary paths only; resolution must never create profile storage.
final class IntegratedPreviewEntryTests: XCTestCase {
    private final class Fixture {
        let directory: URL
        let bundle: URL

        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("integrated-entry-" + UUID().uuidString)
                .resolvingSymlinksInPath().standardizedFileURL
            bundle = directory.appendingPathComponent(".build/candidates/integrated/IntegratedPreview.app")
            try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        }

        deinit { try? FileManager.default.removeItem(at: directory) }
    }

    private var marker: [String: Any] { ["version": 1, "profile": "integrated-01"] }

    private func resolve(_ fixture: Fixture, arguments: [String] = [], metadata: Any?,
                         bundleID: String? = IntegratedPreviewEntry.reservedBundleID,
                         bundleURL: URL? = nil, uiTestMetadata: Any? = nil,
                         gestureMetadata: Any? = nil)
        -> Result<AppArguments.Options, NativeUITestEntry.Rejection> {
        IntegratedPreviewEntry.resolve(arguments: arguments, bundleIdentifier: bundleID,
            bundleURL: bundleURL ?? fixture.bundle, metadata: metadata,
            uiTestMetadata: uiTestMetadata, gestureMetadata: gestureMetadata)
    }

    private func assertRejected(_ result: Result<AppArguments.Options, NativeUITestEntry.Rejection>,
                                as expected: NativeUITestEntry.Rejection,
                                file: StaticString = #filePath, line: UInt = #line) {
        guard case .failure(let reason) = result else {
            return XCTFail("Expected fail-closed entry resolution", file: file, line: line)
        }
        XCTAssertEqual(reason, expected, file: file, line: line)
    }

    func testExactEntrySelectsOnlyPreviewOptionsWithoutCreatingStorage() throws {
        let fixture = try Fixture()
        XCTAssertEqual(IntegratedPreviewEntry.metadataKey, "LaunchcopyIntegratedPreviewEntry")
        XCTAssertEqual(IntegratedPreviewEntry.reservedBundleID, "com.launchcopy.integrated-preview")
        let options = try resolve(fixture, metadata: marker).get()
        var expected = AppArguments.Options.default
        expected.integratedPreview = true
        expected.uiTestWindowed = true
        expected.uiTestProfile = "integrated-01"
        XCTAssertEqual(options, expected, "Content and diagnostic options must retain safe defaults")
        XCTAssertFalse(options.gestureValidation)
        XCTAssertFalse(options.fullscreen)
        XCTAssertFalse(options.folderLab)
        XCTAssertTrue(options.catalogRoots.isEmpty)
        XCTAssertFalse(options.neutralContent)
        XCTAssertFalse(options.pagingLab)
        XCTAssertFalse(options.telemetryEnabled)
        XCTAssertFalse(options.frameProfile)
        XCTAssertFalse(options.frameCallbackProfile)
        XCTAssertFalse(options.runLoopProfile)
        XCTAssertNil(options.runID)
        let profile = try UITestProfile.resolve(bundleURL: fixture.bundle, profileID: "integrated-01")
        XCTAssertEqual(profile.bundleURL.pathComponents, fixture.bundle.pathComponents)
        XCTAssertFalse(FileManager.default.fileExists(atPath: profile.rootURL.deletingLastPathComponent().path))
        XCTAssertEqual(try resolve(fixture, metadata: marker).get(), options)
        XCTAssertFalse(FileManager.default.fileExists(atPath: profile.rootURL.path))
    }

    func testPropertyListRequiresIntegerVersionInXMLAndBinary() throws {
        let fixture = try Fixture()
        for format in [PropertyListSerialization.PropertyListFormat.xml, .binary] {
            for (version, valid) in [(1 as Any, true), (true as Any, false), (1.0 as Any, false)] {
                let data = try PropertyListSerialization.data(
                    fromPropertyList: ["version": version, "profile": "integrated-01"],
                    format: format, options: 0)
                let metadata = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                if valid {
                    XCTAssertTrue(try resolve(fixture, metadata: metadata).get().integratedPreview)
                } else {
                    assertRejected(resolve(fixture, metadata: metadata), as: .invalidMarker)
                }
            }
        }
    }

    func testMissingMalformedFutureAndExtraMarkerFieldsReject() throws {
        let fixture = try Fixture()
        let invalid: [Any?] = [nil, NSNull(), "integrated-01", [], [:],
            ["version": 1], ["profile": "integrated-01"],
            ["version": true, "profile": "integrated-01"],
            ["version": false, "profile": "integrated-01"],
            ["version": 1.0, "profile": "integrated-01"],
            ["version": "1", "profile": "integrated-01"],
            ["version": 0, "profile": "integrated-01"],
            ["version": 2, "profile": "integrated-01"],
            ["version": NSNumber(value: UInt64.max), "profile": "integrated-01"],
            ["version": NSNull(), "profile": "integrated-01"],
            ["version": 1, "profile": 1],
            ["version": 1, "profile": "integrated-01", "fixture": "sources-v1"],
            ["version": 1, "profile": "integrated-01", "backend": "real"]]
        for metadata in invalid {
            assertRejected(resolve(fixture, metadata: metadata), as: .invalidMarker)
        }
    }

    func testWrongIdentityAndEitherMixedEntryMarkerReject() throws {
        let fixture = try Fixture()
        let wrongIDs: [String?] = [nil, "", "com.launchcopy.app", NativeUITestEntry.reservedBundleID,
            GestureValidationEntry.reservedBundleID, "com.launchcopy.integrated-preview.other",
            "COM.LAUNCHCOPY.INTEGRATED-PREVIEW"]
        for id in wrongIDs {
            assertRejected(resolve(fixture, metadata: marker, bundleID: id), as: .invalidMarker)
        }
        let mixedMarkers: [Any] = [marker, [:], "invalid", NSNull()]
        for otherMarker in mixedMarkers {
            assertRejected(resolve(fixture, metadata: marker, uiTestMetadata: otherMarker), as: .invalidMarker)
            assertRejected(resolve(fixture, metadata: marker, gestureMetadata: otherMarker), as: .invalidMarker)
            assertRejected(resolve(fixture, metadata: marker,
                uiTestMetadata: otherMarker, gestureMetadata: otherMarker), as: .invalidMarker)
        }
    }

    func testProfileIDBoundariesAndInvalidIDs() throws {
        let fixture = try Fixture()
        for id in ["a", "0", "integrated-01", String(repeating: "a", count: 48)] {
            XCTAssertEqual(try resolve(fixture, metadata: ["version": 1, "profile": id]).get().uiTestProfile, id)
        }
        for id in ["", "../gui", "/tmp/gui", "a/b", "a\\b", "GUI", "a_b", "a.b", " a", "a\n",
                   "é", String(repeating: "a", count: 49)] {
            assertRejected(resolve(fixture, metadata: ["version": 1, "profile": id]), as: .invalidMarker)
        }
    }

    func testEveryArgumentRejectsIncludingDiagnosticsAndMatchingProfile() throws {
        let fixture = try Fixture()
        let arguments = [["--help"], ["-h"], ["--fullscreen"], ["--folder-lab"],
            ["--ui-test-windowed"], ["--ui-test-windowed", "--ui-test-profile", "integrated-01"],
            ["--ui-test-profile", "other"], ["--catalog-root", "/SyntheticRoot"], ["--neutral-content"],
            ["--paging-lab"], ["--paging-telemetry"], ["--run-id", "fixture"],
            ["--frame-profile"], ["--frame-callback-profile"], ["--runloop-profile"],
            ["--disable-telemetry-bridge"], ["--frame-driver", "displaylink"],
            ["--gesture-validation"], ["--integrated-preview"], ["--integrated-preview=true"],
            ["--unknown"], ["-psn_0_12345"], ["positional"], [""]]
        for args in arguments {
            assertRejected(resolve(fixture, arguments: args, metadata: marker), as: .invalidArguments)
        }
    }

    func testOutsideMissingNonAppAndRemoteBundleLocationsReject() throws {
        let fixture = try Fixture()
        for path in ["Outside.app", ".build/candidates-other/integrated/Test.app", ".build/candidates/Test.app"] {
            let outside = fixture.directory.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
            assertRejected(resolve(fixture, metadata: marker, bundleURL: outside), as: .invalidProfileLocation)
        }
        let missing = fixture.bundle.deletingLastPathComponent().appendingPathComponent("Missing.app")
        let file = fixture.bundle.deletingLastPathComponent().appendingPathComponent("File.app")
        try Data().write(to: file)
        let remote = try XCTUnwrap(URL(string: "https://example.invalid/.build/candidates/integrated/Test.app"))
        for url in [missing, file, fixture.bundle.deletingLastPathComponent(), remote] {
            assertRejected(resolve(fixture, metadata: marker, bundleURL: url), as: .invalidProfileLocation)
        }
    }

    func testBundleAndCandidateSymlinksRejectEvenWithinCandidateTree() throws {
        let fixture = try Fixture()
        let candidate = fixture.bundle.deletingLastPathComponent()
        let bundleAlias = candidate.appendingPathComponent("Alias.app")
        try FileManager.default.createSymbolicLink(at: bundleAlias, withDestinationURL: fixture.bundle)
        let candidateAlias = candidate.deletingLastPathComponent().appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: candidateAlias, withDestinationURL: candidate)
        let outside = fixture.directory.appendingPathComponent("Outside.app")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let escaped = candidate.appendingPathComponent("Escaped.app")
        try FileManager.default.createSymbolicLink(at: escaped, withDestinationURL: outside)
        for url in [bundleAlias, candidateAlias.appendingPathComponent(fixture.bundle.lastPathComponent), escaped] {
            assertRejected(resolve(fixture, metadata: marker, bundleURL: url), as: .invalidProfileLocation)
        }
    }

    func testEveryProfileOutputRejectsSymlinksAndFileCollisions() throws {
        for component in ["", "integrated-01", "integrated-01/Layout", "integrated-01/Applications",
                          "integrated-01/WallpaperCache", "integrated-01/Library", "integrated-01/LaunchActivity", "integrated-01/MainGridCapacity"] {
            for symlink in [false, true] {
                let fixture = try Fixture()
                let profiles = fixture.bundle.deletingLastPathComponent().appendingPathComponent("UITestProfiles")
                let target = component.isEmpty ? profiles : profiles.appendingPathComponent(component)
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                if symlink {
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

    func testCapacityLocalDanglingAndSelfLinksRejectWithoutChangingLegacyEntries() throws {
        for kind in ["local", "dangling", "self"] {
            let fixture = try Fixture()
            let profile = try UITestProfile.resolve(bundleURL: fixture.bundle, profileID: "integrated-01")
            try FileManager.default.createDirectory(at: profile.rootURL, withIntermediateDirectories: true)
            let capacity = profile.rootURL.appendingPathComponent("MainGridCapacity")
            let target: URL
            if kind == "self" { target = capacity }
            else {
                target = profile.rootURL.appendingPathComponent(kind == "local" ? "OwnedTarget" : "Absent")
                if kind == "local" { try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true) }
            }
            try FileManager.default.createSymbolicLink(at: capacity, withDestinationURL: target)
            assertRejected(resolve(fixture, metadata: marker), as: .invalidProfileLocation)
            guard case .success = NativeUITestEntry.resolve(arguments: [], bundleIdentifier: NativeUITestEntry.reservedBundleID,
                bundleURL: fixture.bundle, metadata: marker) else { return XCTFail("Do not alter legacy capacity fault handling") }
            guard case .success = GestureValidationEntry.resolve(arguments: [], bundleIdentifier: GestureValidationEntry.reservedBundleID,
                bundleURL: fixture.bundle, metadata: marker, uiTestMetadata: nil) else { return XCTFail("Do not alter gesture capacity fault handling") }
        }
    }

}
