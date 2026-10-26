import AppCatalogCore
import PagingUI
import XCTest
@testable import AppGridUI

@MainActor
final class AppManagementPresentationTests: XCTestCase {
    private func catalog(_ names: [String] = ["Alpha", "Beta", "Gamma"], revision: UInt64 = 7) -> CatalogSnapshot {
        let records = names.map { name in
            let id = AppID.bundleIdentifier("fixture.management.\(name.lowercased())")
            return AppRecord(id: id, displayName: name, bundleIdentifier: "fixture.management.\(name.lowercased())",
                             canonicalURL: URL(fileURLWithPath: "/SyntheticApps/\(name).app"),
                             iconIdentity: .from(appID: id), sourceRootPriority: 0)
        }
        return CatalogSnapshot(revision: CatalogRevision(revision), records: records)
    }
    private func folderLayout(_ snapshot: CatalogSnapshot) -> PersistentWorkspaceLayout {
        let id = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000091")!)
        let refs = snapshot.records.map { PersistentAppReference.from(record: $0) }
        return PersistentWorkspaceLayout(generation: LayoutGeneration(9),
            topLevelOrder: [.app(refs[2]), .folder(id)],
            folders: [.init(id: id, title: "Fixture group", members: Array(refs.prefix(2)))])
    }
    private func folder(in provider: AppGridUIPageContentProvider) -> FolderEntry? {
        provider.presentationEntries.compactMap { if case .folder(let value) = $0 { return value }; return nil }.first
    }

    func testMetadataIsStagedSameRevisionAndDoesNotMutateCanonicalCatalogOrLayout() throws {
        let snapshot = catalog()
        let layout = folderLayout(snapshot)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        _ = provider.applyCommittedLayout(layout, atCurrentPage: 0, itemsPerPage: 35)
        let canonical = provider.canonicalPresentationEntries
        var preferences = AppManagementPreferences.default.settingHidden(true, for: snapshot.records[2])
        preferences = try XCTUnwrap(preferences.settingAlias("Shortcut", for: snapshot.records[0]))
        provider.receiveManagementPreferences(preferences)
        XCTAssertEqual(provider.managementPreferences, .default)
        let update = try XCTUnwrap(provider.applyPending(atCurrentPage: 0))
        XCTAssertEqual(update.previousRevision, 7)
        XCTAssertEqual(update.newRevision, 7)
        XCTAssertEqual(provider.servedSnapshot, snapshot)
        XCTAssertEqual(provider.canonicalPresentationEntries, canonical)
        XCTAssertEqual(provider.expectedLayout, layout)
        XCTAssertEqual(provider.record(for: snapshot.records[0].id), snapshot.records[0])
        XCTAssertEqual(provider.displayName(for: snapshot.records[0].id), "Shortcut")
        XCTAssertEqual(provider.presentationEntries.count, 1)
        XCTAssertNil(provider.applyPending(atCurrentPage: 0))
    }

    func testOneVisibleMemberRemainsSameFolderAndRestoreRecoversMembershipAndOrder() throws {
        let snapshot = catalog()
        let layout = folderLayout(snapshot)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        _ = provider.applyCommittedLayout(layout, atCurrentPage: 0, itemsPerPage: 35)
        provider.receiveManagementPreferences(.default.settingHidden(true, for: snapshot.records[0]))
        _ = provider.applyPending(atCurrentPage: 0)
        let visible = try XCTUnwrap(folder(in: provider))
        XCTAssertEqual(visible.id, layout.folders[0].id)
        XCTAssertEqual(visible.members, [snapshot.records[1].id])
        XCTAssertEqual(provider.expectedLayout?.folders[0].members, layout.folders[0].members)
        provider.receiveManagementPreferences(.default)
        _ = provider.applyPending(atCurrentPage: 0)
        XCTAssertEqual(folder(in: provider)?.members, Array(snapshot.records.prefix(2)).map(\.id))
        XCTAssertEqual(provider.presentationEntries.first?.identity, .app(snapshot.records[2].id))
    }

    func testAllHiddenFolderDisappearsTemporarilyWithoutDeletingLatentReferences() throws {
        let snapshot = catalog()
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        let layout = folderLayout(snapshot)
        _ = provider.applyCommittedLayout(layout, atCurrentPage: 0, itemsPerPage: 35)
        var prefs = AppManagementPreferences.default
        for record in snapshot.records { prefs = prefs.settingHidden(true, for: record) }
        provider.receiveManagementPreferences(prefs)
        let update = try XCTUnwrap(provider.applyPending(atCurrentPage: 4))
        XCTAssertEqual(update.plan.pageCount, 0)
        XCTAssertTrue(provider.presentationEntries.isEmpty)
        XCTAssertEqual(provider.expectedLayout, layout)
        provider.receiveManagementPreferences(prefs.settingHidden(false, for: snapshot.records[0]))
        _ = provider.applyPending(atCurrentPage: 0)
        XCTAssertEqual(folder(in: provider)?.id, layout.folders[0].id)
        XCTAssertEqual(folder(in: provider)?.members, [snapshot.records[0].id])
    }

    func testExpectedLayoutAndMetadataArrivingBeforeFirstScanAreRetained() {
        let snapshot = catalog()
        let provider = AppGridUIPageContentProvider()
        let layout = folderLayout(snapshot)
        provider.receiveExpectedLayout(layout)
        provider.receiveManagementPreferences(.default.settingHidden(true, for: snapshot.records[2]))
        XCTAssertNil(provider.applyPending(atCurrentPage: 0))
        provider.receive(snapshot)
        _ = provider.applyPending(atCurrentPage: 0)
        XCTAssertEqual(provider.expectedLayout, layout)
        XCTAssertEqual(provider.presentationEntries.count, 1)
        XCTAssertEqual(folder(in: provider)?.members.count, 2)
        XCTAssertEqual(provider.servedRevision, 7)
    }

    func testAliasAndOriginalSearchAndHiddenFilteringRetainCurrentQuery() throws {
        let snapshot = catalog()
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        let search = AppGridSearchPresentationController(provider: provider)
        search.updateQuery(AppSearchQuery(raw: "Alpha"))
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        let prefs = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Shortcut", for: snapshot.records[0]))
        provider.receiveManagementPreferences(prefs)
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(search.currentQuery?.raw, "Alpha")
        XCTAssertEqual(provider.presentationRecords.map(\.displayName), ["Shortcut"])
        search.updateQuery(AppSearchQuery(raw: "Shortcut"))
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(provider.presentationRecords.map(\.id), [snapshot.records[0].id])
        provider.receiveManagementPreferences(prefs.settingHidden(true, for: snapshot.records[0]))
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertTrue(provider.presentationRecords.isEmpty)
        XCTAssertEqual(search.uiState, .noResults)
        XCTAssertEqual(provider.servedRevision, 7)
        provider.receiveManagementPreferences(prefs)
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(provider.presentationRecords.map(\.id), [snapshot.records[0].id])
    }

    func testClearingSearchRecoversSavedMixedOrderInsteadOfCatalogOrder() {
        let snapshot = catalog()
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        let layout = folderLayout(snapshot)
        _ = provider.applyCommittedLayout(layout, atCurrentPage: 0, itemsPerPage: 35)
        let expected = provider.presentationEntries
        let search = AppGridSearchPresentationController(provider: provider)
        search.updateQuery(AppSearchQuery(raw: "Beta"))
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(provider.presentationRecords.map(\.id), [snapshot.records[1].id])
        search.clearQuery()
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(provider.presentationEntries, expected)
    }

    func testRefreshKeepsSavedOrderAndAliasesAndAppendsNewApps() throws {
        let snapshot = catalog()
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        let layout = folderLayout(snapshot)
        _ = provider.applyCommittedLayout(layout, atCurrentPage: 0, itemsPerPage: 35)
        provider.receiveManagementPreferences(try XCTUnwrap(.default.settingAlias("Shortcut", for: snapshot.records[2])))
        _ = provider.applyPending(atCurrentPage: 0)
        let refreshed = catalog(["Alpha", "Beta", "Gamma", "Delta"], revision: 8)
        provider.receive(refreshed)
        _ = provider.applyPending(atCurrentPage: 0)
        XCTAssertEqual(provider.presentationEntries.first?.identity, .app(snapshot.records[2].id))
        XCTAssertEqual(provider.presentationRecords.map(\.displayName), ["Shortcut", "Delta"])
        XCTAssertEqual(provider.expectedLayout, layout)
        XCTAssertEqual(provider.servedRevision, 8)
    }

    func testLatestMetadataWinsAndReturningToCommittedCancelsPendingEdit() {
        let snapshot = catalog()
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        provider.receiveManagementPreferences(.default.settingHidden(true, for: snapshot.records[0]))
        provider.receiveManagementPreferences(.default)
        XCTAssertNil(provider.applyPending(atCurrentPage: 0))
        XCTAssertEqual(provider.presentationRecords, snapshot.records)
    }

    func testIndexedProjectionPreservesFirstBundleMatchAndPathMatchToBundledApp() {
        let id = AppID.bundleIdentifier("fixture.projection.same")
        func record(_ path: String, _ name: String) -> AppRecord {
            .init(id: id, displayName: name, bundleIdentifier: "fixture.projection.same",
                  canonicalURL: URL(fileURLWithPath: path), iconIdentity: .from(appID: id), sourceRootPriority: 0)
        }
        let first = record("/SyntheticApps/First.app", "First")
        let second = record("/SyntheticApps/SECOND.app", "Second")
        let snapshot = CatalogSnapshot(revision: CatalogRevision(1), records: [first, second])
        let missing = PersistentAppReference.canonicalPath("/syntheticapps/missing.app")
        let layout = PersistentWorkspaceLayout(generation: .zero, topLevelOrder: [
            .app(.bundleID("fixture.projection.same")),
            .app(.canonicalPath(PersistentAppReference.normalizedPath(second.canonicalURL))), .app(missing)
        ], folders: [])
        let projection = VisibleWorkspaceProjection.project(layout: layout, catalog: snapshot)
        let records = projection.topLevel.compactMap { if case .app(let value) = $0 { return value }; return nil }
        XCTAssertEqual(records, [first, second])
        XCTAssertEqual(projection.latentAppReferences, [missing])
        XCTAssertTrue(projection.unorchestratedAppRecords.isEmpty)
    }

    func testValidTwoMemberLatentFolderRestoresWhenCatalogMembersReturn() {
        let full = catalog()
        let saved = folderLayout(full)
        let missing = CatalogSnapshot(revision: CatalogRevision(8), records: [full.records[2]])
        let provider = AppGridUIPageContentProvider(snapshot: missing)
        _ = provider.applyCommittedLayout(saved, atCurrentPage: 0, itemsPerPage: 35)
        XCTAssertNil(folder(in: provider))
        XCTAssertEqual(provider.expectedLayout, saved)
        provider.receive(full)
        _ = provider.applyPending(atCurrentPage: 0)
        XCTAssertEqual(folder(in: provider)?.id, saved.folders[0].id)
        XCTAssertEqual(folder(in: provider)?.members, Array(full.records.prefix(2)).map(\.id))
        XCTAssertEqual(provider.expectedLayout, saved)
    }
}
