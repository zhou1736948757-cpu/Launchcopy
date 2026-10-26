import Foundation
import XCTest
@testable import PagingPrototypeApp

/// Pure resolver tests: temporary synthetic directories only, no AppKit, preferences,
/// catalog scans, package metadata, assets, or production storage.
final class UITestProfileTests: XCTestCase {
    func testLibraryStorageIsCandidateLocalLazyAndHasIndependentNamespace() throws {
        try withFixture { root in
            let app = try makeApp(in: root, candidate: "library-candidate")
            let profile = try UITestProfile.resolve(bundleURL: app, profileID: "one")
            XCTAssertEqual(profile.libraryDirectoryURL, profile.rootURL.appendingPathComponent("Library", isDirectory: true))
            XCTAssertFalse(FileManager.default.fileExists(atPath: profile.libraryDirectoryURL.path))
            XCTAssertTrue(profile.librarySuiteName.hasSuffix(".library"))
            XCTAssertNotEqual(profile.librarySuiteName, profile.languageSuiteName)
            let other = try UITestProfile.resolve(bundleURL: app, profileID: "two")
            XCTAssertNotEqual(profile.libraryDirectoryURL, other.libraryDirectoryURL)
            XCTAssertNotEqual(profile.librarySuiteName, other.librarySuiteName)
        }
    }

    func testLanguageNamespaceIsIndependentAndPreservesExistingSuiteIdentity() throws {
        try withFixture { root in
            let app = try makeApp(in: root, candidate: "candidate-a")
            let first = try UITestProfile.resolve(bundleURL: app, profileID: "one")
            let same = try UITestProfile.resolve(bundleURL: app, profileID: "one")
            let second = try UITestProfile.resolve(bundleURL: app, profileID: "two")
            XCTAssertEqual(first.languageSuiteName, same.languageSuiteName)
            XCTAssertNotEqual(first.languageSuiteName, second.languageSuiteName)
            XCTAssertTrue(first.languageSuiteName.hasSuffix(".language"))
            XCTAssertNotEqual(first.languageSuiteName, "com.launchcopy.language")
            XCTAssertEqual(Set([first.languageSuiteName, first.activationSuiteName,
                first.appearanceSuiteName, first.managementSuiteName, first.sourcesSuiteName]).count, 5)
            let namespace = String(first.languageSuiteName.dropLast(".language".count))
            XCTAssertEqual(first.activationSuiteName, namespace + ".activation")
            XCTAssertEqual(first.appearanceSuiteName, namespace + ".appearance")
            XCTAssertFalse(FileManager.default.fileExists(atPath: first.rootURL.path))
        }
    }

    func testIdentifierGrammarAndExactBounds() {
        for id in ["a", "0", "z-9", "a-", "a--b", String(repeating: "a", count: 48)] {
            XCTAssertTrue(UITestProfile.isValidID(id))
        }
        for id in ["", "-a", "A", "a_b", "a.b", "..", "../a", "/tmp/a", "a/b", "a\\b",
                   " a", "a ", "a\n", "a\t", "a\0", "é", "测试", "ａ", String(repeating: "a", count: 49)] {
            XCTAssertFalse(UITestProfile.isValidID(id))
        }
    }

    func testInvalidIdentifierCannotReachAProfileDirectory() throws {
        try withFixture { root in
            let app = try makeApp(in: root, candidate: "candidate-a")
            for id in ["", "../outside", "a/b", "UPPER", String(repeating: "a", count: 49)] {
                assertResolutionError(app, id: id, expected: .invalidID)
            }
            XCTAssertFalse(FileManager.default.fileExists(
                atPath: app.deletingLastPathComponent().appendingPathComponent("UITestProfiles").path
            ))
        }
    }

    func testResolvesCandidateSiblingProfileAndChildDirectoriesWithoutWriting() throws {
        try withFixture { root in
            let app = try makeApp(in: root, candidate: "candidate-a")
            let profile = try UITestProfile.resolve(bundleURL: app, profileID: "folder-01")
            let expectedRoot = app.deletingLastPathComponent()
                .appendingPathComponent("UITestProfiles/folder-01", isDirectory: true)
            XCTAssertEqual(profile.id, "folder-01")
            XCTAssertEqual(profile.bundleURL.path, app.path)
            XCTAssertEqual(profile.rootURL.path, expectedRoot.path)
            XCTAssertEqual(profile.layoutDirectoryURL.path, expectedRoot.appendingPathComponent("Layout").path)
            XCTAssertEqual(profile.applicationsDirectoryURL.path, expectedRoot.appendingPathComponent("Applications").path)
            XCTAssertEqual(profile.wallpaperCacheDirectoryURL.path, expectedRoot.appendingPathComponent("WallpaperCache").path)
            XCTAssertFalse(FileManager.default.fileExists(atPath: profile.rootURL.path))
        }
    }

    func testNonFileURLAndNonAppInputsReject() throws {
        try withFixture { root in
            let app = try makeApp(in: root, candidate: "candidate-a")
            let remote = try XCTUnwrap(URL(string: "https://example.invalid/.build/candidates/a/Fake.app"))
            assertResolutionError(remote, expected: .invalidBundleURL)
            let remoteFile = try XCTUnwrap(URL(string: "file://example.invalid/.build/candidates/a/Fake.app"))
            assertResolutionError(remoteFile, expected: .invalidBundleURL)
            assertResolutionError(app.deletingLastPathComponent(), expected: .notAppDirectory)
            assertResolutionError(app.appendingPathComponent("Contents"), expected: .notAppDirectory)
            let missing = app.deletingLastPathComponent().appendingPathComponent("Missing.app")
            assertResolutionError(missing, expected: .notAppDirectory)
            let file = app.deletingLastPathComponent().appendingPathComponent("File.app")
            try Data().write(to: file)
            assertResolutionError(file, expected: .notAppDirectory)
            let wrongExtension = app.deletingLastPathComponent().appendingPathComponent("Fake.app.backup")
            try FileManager.default.createDirectory(at: wrongExtension, withIntermediateDirectories: false)
            assertResolutionError(wrongExtension, expected: .notAppDirectory)
        }
    }

    func testOutsideAndLookalikeCandidateRootsReject() throws {
        try withFixture { root in
            for path in ["Applications/Fake.app", "candidates/a/Fake.app", ".build-other/candidates/a/Fake.app",
                         ".build/candidates-other/a/Fake.app", ".build/candidates/Fake.app"] {
                let app = root.appendingPathComponent(path, isDirectory: true)
                try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
                assertResolutionError(app, expected: .outsideCandidateDirectory)
            }
        }
    }

    func testDotComponentsCanonicalizeAndTraversalOutsideRejects() throws {
        try withFixture { root in
            let app = try makeApp(in: root, candidate: "candidate-a")
            let dotted = app.deletingLastPathComponent().appendingPathComponent("./unused/../Fake.app")
            let direct = try UITestProfile.resolve(bundleURL: app, profileID: "one")
            let normalized = try UITestProfile.resolve(bundleURL: dotted, profileID: "one")
            XCTAssertEqual(normalized, direct)
            let outside = root.appendingPathComponent("outside/Fake.app", isDirectory: true)
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
            let traversal = app.deletingLastPathComponent()
                .appendingPathComponent("../../../outside/Fake.app")
            assertResolutionError(traversal, expected: .outsideCandidateDirectory)
        }
    }

    func testBundleAndCandidateDirectorySymlinkAliasesShareCanonicalIdentity() throws {
        try withFixture { root in
            let app = try makeApp(in: root, candidate: "candidate-a")
            let expected = try UITestProfile.resolve(bundleURL: app, profileID: "one")
            let appAlias = root.appendingPathComponent("BundleAlias.app")
            try FileManager.default.createSymbolicLink(at: appAlias, withDestinationURL: app)
            XCTAssertEqual(try UITestProfile.resolve(bundleURL: appAlias, profileID: "one"), expected)
            let directoryAlias = root.appendingPathComponent("CandidateAlias", isDirectory: true)
            try FileManager.default.createSymbolicLink(at: directoryAlias,
                                                     withDestinationURL: app.deletingLastPathComponent())
            let throughDirectory = directoryAlias.appendingPathComponent("Fake.app")
            XCTAssertEqual(try UITestProfile.resolve(bundleURL: throughDirectory, profileID: "one"), expected)
        }
    }

    func testBundleSymlinkEscapingCandidateTreeRejects() throws {
        try withFixture { root in
            let outside = root.appendingPathComponent("outside/Fake.app", isDirectory: true)
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
            let alias = root.appendingPathComponent(".build/candidates/a/Alias.app")
            try FileManager.default.createDirectory(at: alias.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: outside)
            assertResolutionError(alias, expected: .outsideCandidateDirectory)
        }
    }

    func testCandidateAncestorSymlinkEscapingBuildTreeRejects() throws {
        try withFixture { root in
            let outside = root.appendingPathComponent("outside/a/Fake.app", isDirectory: true)
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
            let build = root.appendingPathComponent(".build", isDirectory: true)
            try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(at: build.appendingPathComponent("candidates"),
                                                     withDestinationURL: root.appendingPathComponent("outside"))
            assertResolutionError(build.appendingPathComponent("candidates/a/Fake.app"), expected: .outsideCandidateDirectory)
        }
    }

    func testEveryOutputDirectoryRejectsSymlinkEscapes() throws {
        for component in ["", "one", "one/Layout", "one/Applications", "one/WallpaperCache", "one/Library"] {
            try withFixture { root in
                let app = try makeApp(in: root, candidate: "candidate-a")
                let profiles = app.deletingLastPathComponent().appendingPathComponent("UITestProfiles", isDirectory: true)
                let link = component.isEmpty ? profiles : profiles.appendingPathComponent(component)
                try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
                let outside = root.appendingPathComponent("outside", isDirectory: true)
                try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
                try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)
                assertResolutionError(app, expected: .unsafeProfileDirectory)
            }
        }
    }

    func testEveryOutputDirectoryRejectsExistingFileCollisions() throws {
        for component in ["", "one", "one/Layout", "one/Applications", "one/WallpaperCache", "one/Library"] {
            try withFixture { root in
                let app = try makeApp(in: root, candidate: "candidate-a")
                let profiles = app.deletingLastPathComponent().appendingPathComponent("UITestProfiles", isDirectory: true)
                let file = component.isEmpty ? profiles : profiles.appendingPathComponent(component)
                try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data().write(to: file)
                assertResolutionError(app, expected: .unsafeProfileDirectory)
            }
        }
    }

    func testDanglingOutputSymlinkRejects() throws {
        try withFixture { root in
            let app = try makeApp(in: root, candidate: "candidate-a")
            let profiles = app.deletingLastPathComponent().appendingPathComponent("UITestProfiles")
            try FileManager.default.createSymbolicLink(at: profiles, withDestinationURL: root.appendingPathComponent("missing"))
            assertResolutionError(app, expected: .unsafeProfileDirectory)
        }
    }

    func testSuitesAndDirectoriesRemainStableAcrossRestartResolution() throws {
        try withFixture { root in
            let app = try makeApp(in: root, candidate: "candidate-a")
            let before = try UITestProfile.resolve(bundleURL: app, profileID: "one")
            for directory in [before.layoutDirectoryURL, before.applicationsDirectoryURL, before.wallpaperCacheDirectoryURL] {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let sentinel = before.layoutDirectoryURL.appendingPathComponent("sentinel.txt")
            let data = Data("synthetic restart evidence".utf8)
            try data.write(to: sentinel)
            let after = try UITestProfile.resolve(bundleURL: app, profileID: "one")
            XCTAssertEqual(before, after)
            XCTAssertEqual(try Data(contentsOf: sentinel), data, "Resolution never clears retained test data")
        }
    }

    func testCandidateAndProfileChangesIsolateAllStorageAndSuiteNames() throws {
        try withFixture { root in
            let firstApp = try makeApp(in: root, candidate: "candidate-a")
            let secondApp = try makeApp(in: root, candidate: "candidate-b")
            var profiles: [UITestProfile] = []
            for app in [firstApp, secondApp] {
                for id in ["one", "two"] {
                    profiles.append(try UITestProfile.resolve(bundleURL: app, profileID: id))
                }
            }
            XCTAssertEqual(Set(profiles.map(\.rootURL)).count, 4)
            XCTAssertEqual(Set(profiles.map(\.layoutDirectoryURL)).count, 4)
            XCTAssertEqual(Set(profiles.map(\.applicationsDirectoryURL)).count, 4)
            XCTAssertEqual(Set(profiles.map(\.wallpaperCacheDirectoryURL)).count, 4)
            XCTAssertEqual(Set(profiles.flatMap(suites)).count, 12)
        }
    }

    func testNamespacesHaveOnlyVersionedHashAndPurposeNeverRawInput() throws {
        try withFixture { root in
            let app = try makeApp(in: root, candidate: "private-candidate-marker")
            let profile = try UITestProfile.resolve(bundleURL: app, profileID: "private-profile-marker")
            let names = suites(profile)
            XCTAssertEqual(Set(names).count, 3)
            for (name, purpose) in zip(names, ["activation", "appearance", "management"]) {
                let prefix = "com.launchcopy.ui-test.v1."
                XCTAssertTrue(name.hasPrefix(prefix))
                XCTAssertTrue(name.hasSuffix("." + purpose))
                let digest = name.dropFirst(prefix.count).dropLast(purpose.count + 1)
                XCTAssertEqual(digest.utf8.count, 64)
                XCTAssertTrue(digest.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) })
                XCTAssertFalse(name.contains(root.path))
                XCTAssertFalse(name.contains("private-candidate-marker"))
                XCTAssertFalse(name.contains("private-profile-marker"))
                XCTAssertFalse(name.contains("Fake.app"))
                XCTAssertFalse(name.contains("/"))
            }
        }
    }

    private func suites(_ profile: UITestProfile) -> [String] {
        [profile.activationSuiteName, profile.appearanceSuiteName, profile.managementSuiteName]
    }

    private func withFixture(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("UITestProfileTests-" + UUID().uuidString, isDirectory: true)
            .resolvingSymlinksInPath().standardizedFileURL
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func makeApp(in root: URL, candidate: String) throws -> URL {
        let app = root.appendingPathComponent(".build/candidates/\(candidate)/Fake.app", isDirectory: true)
        try FileManager.default.createDirectory(at: app, withIntermediateDirectories: true)
        return app
    }

    private func assertResolutionError(
        _ bundleURL: URL, id: String = "one", expected: UITestProfile.ResolutionError,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertThrowsError(try UITestProfile.resolve(bundleURL: bundleURL, profileID: id), file: file, line: line) { error in
            XCTAssertEqual(error as? UITestProfile.ResolutionError, expected, file: file, line: line)
        }
    }
}
