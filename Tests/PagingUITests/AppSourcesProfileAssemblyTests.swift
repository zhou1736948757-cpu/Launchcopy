import AppKit
import Foundation
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class AppSourcesProfileAssemblyTests: XCTestCase {
    private func fixture() throws -> (root: URL, bundle: URL, owner: AppDelegate) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bundle = root.appendingPathComponent(".build/candidates/source-test/LaunchcopyUITest.app")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        let options = try AppArguments.parse(["--ui-test-windowed", "--ui-test-profile", "sources"]).get()
        let owner = AppDelegate(options: options)
        try owner.configureUITestProfile(bundleURL: bundle)
        return (root, bundle, owner)
    }
    private func settle(_ predicate: () -> Bool) async {
        for _ in 0..<1000 { if predicate() { return }; await Task.yield() }
        XCTFail("Bounded asynchronous operation did not finish")
    }
    func testSourcesNamespaceDistinctAndFreshStoreReopensOnlyItsCandidate() throws {
        let value = try fixture(); defer { try? FileManager.default.removeItem(at: value.root) }
        let profile = try XCTUnwrap(value.owner.uiTestProfile)
        let other = try UITestProfile.resolve(bundleURL: value.bundle, profileID: "other")
        let suites = [profile.sourcesSuiteName, other.sourcesSuiteName]
        defer { for suite in suites { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) } }
        XCTAssertNotEqual(profile.sourcesSuiteName, UserDefaultsAppSourcesStore.defaultSuiteName)
        XCTAssertEqual(Set([profile.sourcesSuiteName, profile.activationSuiteName,
                            profile.appearanceSuiteName, profile.managementSuiteName]).count, 4)
        let store = try XCTUnwrap(UserDefaultsAppSourcesStore(suiteName: profile.sourcesSuiteName))
        let draft = AppSourcesPreferences(automaticRefreshEnabled: false)
        XCTAssertEqual(store.save(draft), .saved)
        let reopened = try XCTUnwrap(UserDefaultsAppSourcesStore(suiteName: profile.sourcesSuiteName))
        XCTAssertEqual(reopened.load(), .loaded(draft))
        XCTAssertEqual(UserDefaultsAppSourcesStore(suiteName: other.sourcesSuiteName)?.load(), .loaded(.default))
    }
    func testActualOwnerDiscardsTamperedExternalSourceBeforeCatalogAndWatch() async throws {
        let value = try fixture(); defer { try? FileManager.default.removeItem(at: value.root) }
        let profile = try XCTUnwrap(value.owner.uiTestProfile)
        let outside = value.root.appendingPathComponent("Outside")
        let contents = outside.appendingPathComponent("Private.app/Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist = try PropertyListSerialization.data(fromPropertyList:
            ["CFBundleIdentifier": "fixture.outside", "CFBundleName": "Outside"], format: .xml, options: 0)
        try plist.write(to: contents.appendingPathComponent("Info.plist"))
        let assembly = try XCTUnwrap(value.owner.makeContentAssembly())
        defer { value.owner.appSourcesCoordinator?.teardown(); assembly.teardown() }
        value.owner.assembly = assembly
        let watcher = SourcesWatchFake()
        let store = InMemoryAppSourcesStore(preferences: .init(customRootPaths: [outside.path]))
        let context = AppSourceRootAdmissionContext(homeURL: value.root.appendingPathComponent("FakeHome"),
            fixedRoots: [profile.applicationsDirectoryURL], allowedSyntheticRoot: profile.applicationsDirectoryURL)
        value.owner.installAppSources(assembly: assembly, store: store,
            admission: LocalAppSourceRootAdmitter(), watcher: watcher, context: context)
        await settle { value.owner.appSourcesCoordinator?.watchStatus == .degraded }
        XCTAssertEqual(watcher.roots, [[profile.applicationsDirectoryURL]])
        let outcome = await assembly.dataSource.refresh()
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(assembly.dataSource.currentSnapshot?.records.count, 0)
        // The canonical reference is retained privately, not scanned or silently repaired.
        XCTAssertEqual(store.load().preferences.customRootPaths, [outside.path])
    }
    func testUnconfiguredProfileCannotCreateSourceOwnerOrOpenStores() throws {
        let options = try AppArguments.parse(["--ui-test-windowed", "--ui-test-profile", "sources"]).get()
        let owner = AppDelegate(options: options)
        let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticApps")])
        defer { assembly.teardown() }
        owner.installAppSources(assembly: assembly, store: InMemoryAppSourcesStore(),
            admission: SourcesAdmissionFake(), watcher: SourcesWatchFake(),
            context: .init(homeURL: URL(fileURLWithPath: "/SyntheticHome"), fixedRoots: []))
        XCTAssertNil(owner.appSourcesCoordinator)
    }
    func testActualOwnerSettingsTabApplyAndHideCancelUseSharedConsumer() async throws {
        let value = try fixture(); defer { try? FileManager.default.removeItem(at: value.root) }
        let profile = try XCTUnwrap(value.owner.uiTestProfile)
        let assembly = try XCTUnwrap(value.owner.makeContentAssembly())
        value.owner.assembly = assembly
        let watcher = SourcesWatchFake(), store = InMemoryAppSourcesStore()
        value.owner.installAppSources(assembly: assembly, store: store, admission: SourcesAdmissionFake(),
            watcher: watcher, context: .init(homeURL: value.root.appendingPathComponent("FakeHome"),
                fixedRoots: [profile.applicationsDirectoryURL], allowedSyntheticRoot: profile.applicationsDirectoryURL))
        defer { value.owner.appSourcesCoordinator?.teardown(); assembly.teardown() }
        let controller = ActivationSettingsWindowController(draft: .init(committed: .init()))
        defer { controller.hideSettings() }
        value.owner.configureAppSourcesSettings(controller)
        let tabs = try XCTUnwrap(controller.window?.contentView as? NSTabView)
        XCTAssertTrue(tabs.tabViewItems.first { $0.identifier as? String == "sources" }?.view === controller.appSourcesView)
        controller.appSourcesView.automaticCheckbox.performClick(nil)
        controller.appSourcesView.applyButton.performClick(nil)
        await settle { store.load().preferences.automaticRefreshEnabled == false }
        XCTAssertEqual(value.owner.appSourcesCoordinator?.watchStatus, .disabled)
        controller.hideSettings()
        value.owner.configureAppSourcesSettings(controller)
        XCTAssertFalse(controller.appSourcesView.draft.automaticRefreshEnabled)
        XCTAssertEqual(assembly.scanRoots, [profile.applicationsDirectoryURL])
    }

    func testActualOwnerRevalidatesFixedProfileRootAfterReplacementAndRecovery() async throws {
        let value = try fixture(); defer { try? FileManager.default.removeItem(at: value.root) }
        let profile = try XCTUnwrap(value.owner.uiTestProfile)
        func makeApp(_ name: String, in directory: URL) throws {
            let contents = directory.appendingPathComponent(name + ".app/Contents")
            try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList:
                ["CFBundleIdentifier": "fixture." + name.lowercased(), "CFBundleName": name], format: .xml, options: 0)
            try data.write(to: contents.appendingPathComponent("Info.plist"))
        }
        try makeApp("Local", in: profile.applicationsDirectoryURL)
        let outside = value.root.appendingPathComponent("Outside")
        try makeApp("Outside", in: outside)
        let assembly = try XCTUnwrap(value.owner.makeContentAssembly())
        value.owner.assembly = assembly
        let watcher = SourcesWatchFake(), store = InMemoryAppSourcesStore()
        value.owner.installAppSources(assembly: assembly, store: store,
            admission: LocalAppSourceRootAdmitter(), watcher: watcher,
            context: .init(homeURL: value.root.appendingPathComponent("FakeHome"),
                fixedRoots: [profile.applicationsDirectoryURL], allowedSyntheticRoot: profile.applicationsDirectoryURL))
        defer { value.owner.appSourcesCoordinator?.teardown(); assembly.teardown() }
        await settle { value.owner.appSourcesCoordinator?.watchStatus == .active }
        _ = await assembly.dataSource.refresh()
        XCTAssertEqual(assembly.dataSource.currentSnapshot?.records.map(\.displayName), ["Local"])
        let saved = profile.rootURL.appendingPathComponent("SavedApplications")
        try FileManager.default.moveItem(at: profile.applicationsDirectoryURL, to: saved)
        try FileManager.default.createSymbolicLink(at: profile.applicationsDirectoryURL, withDestinationURL: outside)
        value.owner.appSourcesCoordinator?.refreshNow()
        await settle { value.owner.appSourcesCoordinator?.watchStatus == .degraded
            && assembly.dataSource.currentSnapshot?.records.isEmpty == true }
        XCTAssertEqual(watcher.roots.last, [])
        XCTAssertEqual(store.load(), .loaded(.default))
        XCTAssertEqual(assembly.scanRoots, [profile.applicationsDirectoryURL])
        // Return the same fixed reference safely; no reset, external scan, or preference repair.
        try FileManager.default.removeItem(at: profile.applicationsDirectoryURL)
        try FileManager.default.moveItem(at: saved, to: profile.applicationsDirectoryURL)
        value.owner.appSourcesCoordinator?.refreshNow()
        await settle { value.owner.appSourcesCoordinator?.watchStatus == .active
            && assembly.dataSource.currentSnapshot?.records.map(\.displayName) == ["Local"] }
        XCTAssertEqual(watcher.roots.last, [profile.applicationsDirectoryURL])
    }

}
