import AppGridUI
import AppCatalogCore
import Foundation
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class UITestProfileAssemblyTests: XCTestCase {
    private func candidate(in root: URL) throws -> URL {
        let bundle = root.appendingPathComponent(".build/candidates/fixture/Launchcopy.app", isDirectory: true)
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        return bundle
    }
    private func options(_ id: String) throws -> AppArguments.Options {
        try AppArguments.parse(["--ui-test-windowed", "--ui-test-profile", id]).get()
    }

    func testOrdinaryStartupConfigurationNeverResolvesTestStorage() throws {
        let owner = AppDelegate(options: .default)
        try owner.configureUITestProfile(bundleURL: URL(fileURLWithPath: "/NotAnApp"))
        XCTAssertNil(owner.uiTestProfile)
    }

    func testProfileCreatesOnlyCandidateLocalDirectoriesAndSurvivesFreshOwner() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = try candidate(in: root)
        let owner = AppDelegate(options: try options("alpha"))
        try owner.configureUITestProfile(bundleURL: bundle)
        let profile = try XCTUnwrap(owner.uiTestProfile)
        for path in [profile.layoutDirectoryURL, profile.applicationsDirectoryURL, profile.wallpaperCacheDirectoryURL] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: path.path))
            XCTAssertTrue(path.pathComponents.starts(with: profile.rootURL.pathComponents))
        }
        let marker = profile.layoutDirectoryURL.appendingPathComponent("fixture-marker")
        try Data([1, 2, 3]).write(to: marker)
        let reopened = AppDelegate(options: try options("alpha"))
        try reopened.configureUITestProfile(bundleURL: bundle)
        XCTAssertEqual(reopened.uiTestProfile, profile)
        XCTAssertEqual(try Data(contentsOf: marker), Data([1, 2, 3]))
        XCTAssertNotEqual(profile.appearanceSuiteName, UserDefaultsAppearancePreferencesStore.defaultSuiteName)
        XCTAssertNotEqual(profile.activationSuiteName, UserDefaultsActivationPreferencesStore.defaultSuiteName)
        XCTAssertNotEqual(profile.managementSuiteName, UserDefaultsAppManagementStore.defaultSuiteName)
    }

    func testExternalSyntheticRootRejectsBeforeCreatingProfileOrOpeningPreferences() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = try candidate(in: root)
        var configured = try options("alpha")
        configured.catalogRoots = [URL(fileURLWithPath: "/SyntheticOtherApps")]
        let owner = AppDelegate(options: configured)
        XCTAssertThrowsError(try owner.configureUITestProfile(bundleURL: bundle))
        XCTAssertNil(owner.uiTestProfile)
        let expected = bundle.deletingLastPathComponent().appendingPathComponent("UITestProfiles")
        XCTAssertFalse(FileManager.default.fileExists(atPath: expected.path))
    }

    func testContainedSyntheticRootAcceptsButPrefixSiblingRejects() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = try candidate(in: root)
        let profile = try UITestProfile.resolve(bundleURL: bundle, profileID: "alpha")
        var configured = try options("alpha")
        configured.catalogRoots = [profile.applicationsDirectoryURL.appendingPathComponent("Subset")]
        let owner = AppDelegate(options: configured)
        try owner.configureUITestProfile(bundleURL: bundle)
        XCTAssertEqual(owner.uiTestProfile, profile)
        configured.catalogRoots = [profile.rootURL.appendingPathComponent("Applications-other")]
        XCTAssertThrowsError(try AppDelegate(options: configured).configureUITestProfile(bundleURL: bundle))
    }

    func testAppearanceAndManagementWritesUseDistinctNamedTestSuites() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = try candidate(in: root)
        let first = try UITestProfile.resolve(bundleURL: bundle, profileID: "alpha")
        let second = try UITestProfile.resolve(bundleURL: bundle, profileID: "beta")
        let suites = [first.appearanceSuiteName, second.appearanceSuiteName,
                      first.managementSuiteName, second.managementSuiteName]
        defer { for suite in suites { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) } }
        let a = try XCTUnwrap(UserDefaultsAppearancePreferencesStore(suiteName: first.appearanceSuiteName))
        let b = try XCTUnwrap(UserDefaultsAppearancePreferencesStore(suiteName: second.appearanceSuiteName))
        let preference = AppearancePreferences(showsAppLabels: false, wallpaperBlurRadius: 12)
        XCTAssertEqual(a.save(preference), .saved)
        XCTAssertEqual(a.load(), .loaded(preference))
        XCTAssertEqual(b.load(), .loaded(.default))
        let managementA = try XCTUnwrap(UserDefaultsAppManagementStore(suiteName: first.managementSuiteName))
        let managementB = try XCTUnwrap(UserDefaultsAppManagementStore(suiteName: second.managementSuiteName))
        let metadata = AppManagementPreferences(hiddenKeys: ["bundle:fixture.example"], aliases: [:])
        XCTAssertEqual(managementA.save(metadata), .saved)
        XCTAssertEqual(managementA.load(), .loaded(metadata))
        XCTAssertEqual(managementB.load(), .loaded(.default))
    }
    func testConfiguredProfileAssemblyNeverAdoptsExternalDirectoryAliasOrResolverURL() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = try candidate(in: root)
        let owner = AppDelegate(options: try options("alpha"))
        try owner.configureUITestProfile(bundleURL: bundle)
        let profile = try XCTUnwrap(owner.uiTestProfile)
        let outside = root.appendingPathComponent("Outside")
        func app(in directory: URL, name: String, identifier: String) throws -> URL {
            let path = directory.appendingPathComponent(name + ".app")
            let contents = path.appendingPathComponent("Contents")
            try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
            let bytes = try PropertyListSerialization.data(fromPropertyList:
                ["CFBundleIdentifier": identifier, "CFBundleName": name], format: .xml, options: 0)
            try bytes.write(to: contents.appendingPathComponent("Info.plist"))
            return path
        }
        let valid = try app(in: profile.applicationsDirectoryURL, name: "Local", identifier: "fixture.local")
        _ = try app(in: outside, name: "Outside", identifier: "fixture.outside")
        try FileManager.default.createSymbolicLink(at: profile.applicationsDirectoryURL.appendingPathComponent("External"),
                                                   withDestinationURL: outside)
        let assembly = try XCTUnwrap(owner.makeContentAssembly())
        defer { assembly.teardown() }
        let outcome = await assembly.dataSource.refresh()
        XCTAssertTrue(outcome.succeeded)
        let snapshot = try XCTUnwrap(assembly.dataSource.currentSnapshot)
        XCTAssertEqual(snapshot.records.map(\.bundleIdentifier), ["fixture.local"])
        assembly.begin() // Uses the real cached-snapshot presentation callback/resolver wiring.
        XCTAssertNil(assembly.urlResolver.url(for: AppID.bundleIdentifier("fixture.outside")))
        XCTAssertEqual(assembly.urlResolver.url(for: AppID.bundleIdentifier("fixture.local"))?.standardizedFileURL,
                       valid.resolvingSymlinksInPath().standardizedFileURL)
        // Repeated real refresh retains the boundary, not just startup validation.
        _ = await assembly.dataSource.refresh()
        XCTAssertEqual(assembly.dataSource.currentSnapshot?.records.count, 1)
    }

    func testProfileCannotConstructOrdinaryCatalogBeforeSuccessfulConfiguration() throws {
        let owner = AppDelegate(options: try options("alpha"))
        XCTAssertNil(owner.makeContentAssembly())
    }

}
