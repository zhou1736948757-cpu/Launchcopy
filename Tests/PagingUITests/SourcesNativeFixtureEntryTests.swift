import Foundation
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class SourcesNativeFixtureEntryTests: XCTestCase {
    private final class Fixture {
        let directory: URL
        let bundle: URL
        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("sources-native-entry-" + UUID().uuidString)
                .resolvingSymlinksInPath()
            bundle = directory.appendingPathComponent(".build/candidates/fixture/LaunchcopyUITest.app")
            try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        }
        deinit { try? FileManager.default.removeItem(at: directory) }
        var profile: UITestProfile { get throws { try UITestProfile.resolve(bundleURL: bundle, profileID: "gui") } }
        func makeChildren() throws {
            for name in ["Baseline", "Extras"] {
                try FileManager.default.createDirectory(at: profile.applicationsDirectoryURL
                    .appendingPathComponent(name), withIntermediateDirectories: true)
            }
        }
    }

    private let marker: [String: Any] = ["version": 2, "profile": "gui", "fixture": "sources-v1"]
    private func resolve(_ f: Fixture, metadata: Any?, arguments: [String] = [],
                         bundleID: String? = NativeUITestEntry.reservedBundleID)
        -> Result<AppArguments.Options, NativeUITestEntry.Rejection> {
        NativeUITestEntry.resolve(arguments: arguments, bundleIdentifier: bundleID,
                                 bundleURL: f.bundle, metadata: metadata)
    }
    private func assertRejected(_ result: Result<AppArguments.Options, NativeUITestEntry.Rejection>,
                                _ expected: NativeUITestEntry.Rejection,
                                file: StaticString = #filePath, line: UInt = #line) {
        switch result {
        case .success: XCTFail("Expected fail-closed rejection", file: file, line: line)
        case .failure(let reason): XCTAssertEqual(reason, expected, file: file, line: line)
        }
    }

    func testSourcesMarkerResolvesOnlyFixedBaselineWithoutCreatingDirectories() throws {
        let f = try Fixture()
        let options = try resolve(f, metadata: marker).get()
        let profile = try f.profile
        XCTAssertEqual(options.catalogRoots, [profile.applicationsDirectoryURL
            .appendingPathComponent("Baseline", isDirectory: true)])
        XCTAssertEqual(options.uiTestProfile, "gui")
        XCTAssertTrue(options.uiTestWindowed)
        XCTAssertTrue(options.folderLab)
        XCTAssertFalse(options.fullscreen)
        XCTAssertFalse(FileManager.default.fileExists(atPath: profile.rootURL.path))
        XCTAssertNotEqual(profile.sourcesSuiteName, UserDefaultsAppSourcesStore.defaultSuiteName)
    }

    func testVersionOneAndProductionRemainUnchanged() throws {
        let f = try Fixture()
        let old = try resolve(f, metadata: ["version": 1, "profile": "gui"]).get()
        XCTAssertTrue(old.catalogRoots.isEmpty)
        XCTAssertTrue(old.uiTestWindowed)
        XCTAssertEqual(try resolve(f, metadata: nil, bundleID: "com.launchcopy.app").get(), .default)
        assertRejected(resolve(f, metadata: ["version": 1, "profile": "gui", "fixture": "sources-v1"]), .invalidMarker)
    }

    func testExactSourcesMarkerRejectsWrongTypesVersionsKeysAndPreset() throws {
        let f = try Fixture()
        let invalid: [Any] = [
            ["version": 2, "profile": "gui"],
            ["version": 2.0, "profile": "gui", "fixture": "sources-v1"],
            ["version": true, "profile": "gui", "fixture": "sources-v1"],
            ["version": 3, "profile": "gui", "fixture": "sources-v1"],
            ["version": "2", "profile": "gui", "fixture": "sources-v1"],
            ["version": 2, "profile": "gui", "fixture": "unknown"],
            ["version": 2, "profile": "gui", "fixture": "../sources-v1"],
            ["version": 2, "profile": "gui", "fixture": true],
            ["version": 2, "profile": "gui", "fixture": 1],
            ["version": 2, "profile": "GUI", "fixture": "sources-v1"],
            ["version": 2, "profile": "gui", "fixture": "sources-v1", "root": "/not-allowed"]
        ]
        for value in invalid { assertRejected(resolve(f, metadata: value, arguments: ["--help"]), .invalidMarker) }
        assertRejected(resolve(f, metadata: marker, bundleID: "com.launchcopy.app"), .invalidMarker)
        assertRejected(resolve(f, metadata: marker, bundleID: nil), .invalidMarker)
    }

    func testSourcesMarkerRejectsExplicitContentAndProfileOverridesBeforeInjectingRoot() throws {
        let f = try Fixture()
        for arguments in [["--catalog-root", "/Synthetic"], ["--neutral-content"]] {
            assertRejected(resolve(f, metadata: marker, arguments: arguments), .conflictingContent)
        }
        assertRejected(resolve(f, metadata: marker, arguments: ["--ui-test-windowed", "--ui-test-profile", "other"]), .conflictingProfile)
        assertRejected(resolve(f, metadata: marker, arguments: ["--unknown-fixture"]), .invalidArguments)
        let compatible = try resolve(f, metadata: marker, arguments: ["--ui-test-windowed", "--ui-test-profile", "gui", "--fullscreen"]).get()
        XCTAssertFalse(compatible.fullscreen)
        XCTAssertEqual(compatible, try resolve(f, metadata: marker).get())
    }

    func testBothFixedChildrenRejectFilesAndSymlinksWithoutReplacement() throws {
        for name in ["Baseline", "Extras"] {
            for kind in ["file", "escape-link", "dangling-link", "internal-link"] {
                let f = try Fixture()
                let applications = try f.profile.applicationsDirectoryURL
                try FileManager.default.createDirectory(at: applications, withIntermediateDirectories: true)
                let child = applications.appendingPathComponent(name)
                if kind == "file" { try Data("owned fixture".utf8).write(to: child) }
                else {
                    let target = kind == "escape-link" ? f.directory
                        : applications.appendingPathComponent(kind == "dangling-link" ? "Missing" : "Internal")
                    if kind == "internal-link" {
                        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                    }
                    try FileManager.default.createSymbolicLink(at: child, withDestinationURL: target)
                }
                let before = try FileManager.default.attributesOfItem(atPath: child.path)[.type] as? FileAttributeType
                assertRejected(resolve(f, metadata: marker), .invalidProfileLocation)
                XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: child.path)[.type] as? FileAttributeType, before)
            }
        }
    }

    func testSourcesMarkerRetainsParentProfileLocationGuard() throws {
        let f = try Fixture()
        let root = try f.profile.rootURL
        try FileManager.default.createDirectory(at: root.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: root, withDestinationURL: f.directory)
        assertRejected(resolve(f, metadata: marker), .invalidProfileLocation)
    }

    func testExistingRuntimeAssemblyAndAdmissionUsePresetWithoutBroaderAccess() async throws {
        let f = try Fixture()
        try f.makeChildren()
        let options = try resolve(f, metadata: marker).get()
        let app = AppDelegate(options: options)
        try app.configureUITestProfile(bundleURL: f.bundle)
        let assembly = try XCTUnwrap(app.makeContentAssembly())
        defer { assembly.teardown() }
        XCTAssertEqual(assembly.scanRoots, options.catalogRoots)
        let profile = try f.profile
        let extras = profile.applicationsDirectoryURL.appendingPathComponent("Extras", isDirectory: true)
        let context = AppSourceRootAdmissionContext(homeURL: f.directory.appendingPathComponent("SyntheticHome"),
            fixedRoots: assembly.scanRoots, allowedSyntheticRoot: profile.applicationsDirectoryURL)
        let admitted = await LocalAppSourceRootAdmitter().admit(extras, context: context)
        XCTAssertEqual(admitted, .accepted(extras))
        let outside = await LocalAppSourceRootAdmitter().admit(f.directory, context: context)
        XCTAssertEqual(outside, .rejected(.outsideSyntheticRoot))
        let legacyContext = AppSourceRootAdmissionContext(homeURL: context.homeURL,
            fixedRoots: [profile.applicationsDirectoryURL], allowedSyntheticRoot: profile.applicationsDirectoryURL)
        let legacy = await LocalAppSourceRootAdmitter().admit(extras, context: legacyContext)
        XCTAssertEqual(legacy, .alreadyCovered)
    }
}
