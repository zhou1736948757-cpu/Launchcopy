import AppKit
import Foundation
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import PagingPrototypeApp
@testable import PagingUI

/// Uses synthetic catalog records, temporary fake bundles, and the existing recording launcher.
/// No scanner, window, workspace launch, or real application is required.
@MainActor
final class AppManagementLaunchTests: XCTestCase {
    private var factory: FakeAppFactory!
    private var surface: PagingSurface!
    private var assembly: AppCatalogAssembly!
    private var launcher: RecordingLauncher!
    private var controller: AppLaunchController!

    override func setUpWithError() throws {
        factory = try FakeAppFactory(prefix: "app-management-launch-tests")
        surface = makeSurface(pageCount: 1, itemsPerPage: 35)
        assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        wireAssembly(assembly, to: surface)
        launcher = RecordingLauncher()
        controller = AppLaunchController(surface: surface, assembly: assembly, launcher: launcher)
    }

    override func tearDownWithError() throws {
        controller = nil
        assembly?.teardown()
        assembly = nil
        surface?.teardown()
        surface = nil
        launcher = nil
        factory?.removeRoot()
        factory = nil
    }

    private func serveApp() throws -> AppRecord {
        let url = try factory.makeApp(named: "Synthetic", bundleID: "fixture.management.launch")
        let id = CatalogFixture.appID("fixture.management.launch")
        let record = CatalogFixture.record(id: id, displayName: "Synthetic", bundleID: "fixture.management.launch",
                                           url: url, icon: IconIdentity.from(appID: id), rootPriority: 0)
        let snapshot = try CatalogFixture.snapshot(records: [record], revision: CatalogRevision(7))
        assembly.provider.receive(snapshot)
        _ = try XCTUnwrap(assembly.provider.applyPending(atCurrentPage: 0))
        XCTAssertEqual(assembly.provider.servedRevision, 7)
        XCTAssertEqual(assembly.bundleURL(for: id), url)
        return record
    }

    private func cell(for record: AppRecord) throws -> AppGridCellView {
        AppCatalogAssembly.makeMemberLaunchCell(
            appID: record.id, servedRevision: try XCTUnwrap(assembly.provider.servedRevision))
    }

    private func setHidden(_ hidden: Bool, for record: AppRecord) throws {
        let preferences = assembly.provider.managementPreferences.settingHidden(hidden, for: record)
        assembly.provider.receiveManagementPreferences(preferences)
        _ = try XCTUnwrap(assembly.provider.applyPending(atCurrentPage: 0))
        XCTAssertEqual(assembly.provider.isHidden(record.id), hidden)
        XCTAssertEqual(assembly.provider.servedRevision, 7, "Metadata changes must not forge catalog revisions")
    }

    func testHiddenAppWithCurrentRetainedBindingIsRejectedBeforeWorkspaceLauncher() throws {
        let record = try serveApp()
        let retainedCell = try cell(for: record)
        try setHidden(true, for: record)
        XCTAssertTrue(FileManager.default.fileExists(atPath: record.canonicalURL.path))
        XCTAssertEqual(assembly.bundleURL(for: record.id), record.canonicalURL)
        XCTAssertTrue(assembly.provider.presentationEntries.isEmpty)
        XCTAssertEqual(retainedCell.bindingToken?.catalogRevision, assembly.provider.servedRevision)
        var observed: [AppLaunchOutcome] = []
        controller.onLaunchAttempt = { observed.append($0) }

        XCTAssertEqual(controller.handleCell(retainedCell), .rejectedHiddenApp)
        XCTAssertEqual(controller.lastOutcome, .rejectedHiddenApp)
        XCTAssertEqual(controller.outcomeCounts[.rejectedHiddenApp], 1)
        XCTAssertEqual(observed, [.rejectedHiddenApp])
        XCTAssertTrue(launcher.opened.isEmpty, "Hidden protection must run before the injected workspace launcher")
    }

    func testHiddenRejectionPrecedesMissingFileValidation() throws {
        let record = try serveApp()
        let retainedCell = try cell(for: record)
        try setHidden(true, for: record)
        try FileManager.default.removeItem(at: record.canonicalURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: record.canonicalURL.path))

        XCTAssertEqual(controller.handleCell(retainedCell), .rejectedHiddenApp)
        XCTAssertNil(controller.outcomeCounts[.rejectedMissingFile])
        XCTAssertTrue(launcher.opened.isEmpty)
    }

    func testUnhidingRestoresLaunchThroughSameBindingAndFakeLauncher() throws {
        let record = try serveApp()
        let retainedCell = try cell(for: record)
        let originalToken = try XCTUnwrap(retainedCell.bindingToken)
        try setHidden(true, for: record)
        XCTAssertEqual(controller.handleCell(retainedCell), .rejectedHiddenApp)
        XCTAssertTrue(launcher.opened.isEmpty)
        try setHidden(false, for: record)

        XCTAssertEqual(retainedCell.bindingToken, originalToken)
        XCTAssertEqual(controller.handleCell(retainedCell), .launched)
        XCTAssertEqual(launcher.opened, [record.canonicalURL])
        XCTAssertEqual(controller.outcomeCounts[.rejectedHiddenApp], 1)
        XCTAssertEqual(controller.outcomeCounts[.launched], 1)
    }

    func testDefaultManagementPreferencesAllowVisibleSyntheticAppLaunch() throws {
        let record = try serveApp()
        XCTAssertEqual(assembly.provider.managementPreferences, .default)
        XCTAssertFalse(assembly.provider.isHidden(record.id))
        XCTAssertEqual(controller.handleCell(try cell(for: record)), .launched)
        XCTAssertEqual(launcher.opened, [record.canonicalURL])
    }

    func testFolderMemberLaunchCellCannotBypassHiddenProtectionOrRemoveCanonicalReferences() throws {
        let record = try serveApp()
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000083")!)
        let reference = PersistentAppReference.from(record: record)
        let layout = PersistentWorkspaceLayout(
            generation: .zero, topLevelOrder: [.folder(folderID)],
            folders: [PersistentFolderRecord(id: folderID, title: "Synthetic Group",
                                             members: [reference, .bundleID("fixture.management.absent")])])
        assembly.provider.receiveExpectedLayout(layout)
        _ = try XCTUnwrap(assembly.provider.applyPending(atCurrentPage: 0))
        try setHidden(true, for: record)
        let memberCell = try cell(for: record)

        XCTAssertEqual(controller.handleCell(memberCell), .rejectedHiddenApp)
        XCTAssertTrue(launcher.opened.isEmpty)
        XCTAssertEqual(assembly.provider.expectedLayout, layout)
        XCTAssertEqual(assembly.provider.record(for: record.id), record)
        XCTAssertEqual(assembly.bundleURL(for: record.id), record.canonicalURL)
    }

    func testStaleHiddenBindingStillUsesExistingRevisionGuardFirst() throws {
        let record = try serveApp()
        try setHidden(true, for: record)
        let staleCell = AppCatalogAssembly.makeMemberLaunchCell(appID: record.id, servedRevision: 6)
        XCTAssertEqual(controller.handleCell(staleCell), .rejectedStaleRevision)
        XCTAssertNil(controller.outcomeCounts[.rejectedHiddenApp])
        XCTAssertTrue(launcher.opened.isEmpty)
    }
}
