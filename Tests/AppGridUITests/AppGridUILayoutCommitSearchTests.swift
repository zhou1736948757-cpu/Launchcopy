import AppCatalogCore
import Foundation
import PagingUI
import XCTest
@testable import AppGridUI

@MainActor
final class AppGridUILayoutCommitSearchTests: XCTestCase {
    private func catalog() -> CatalogSnapshot {
        let records = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"].map { name in
            let bundleID = "fixture.layoutcommit.\(name.lowercased())"
            let id = AppID.bundleIdentifier(bundleID)
            return AppRecord(id: id, displayName: name, bundleIdentifier: bundleID,
                             canonicalURL: URL(fileURLWithPath: "/SyntheticApps/\(name).app"),
                             iconIdentity: .from(appID: id), sourceRootPriority: 0)
        }
        return CatalogSnapshot(revision: CatalogRevision(7), records: records)
    }

    private func folderLayout(_ snapshot: CatalogSnapshot) -> PersistentWorkspaceLayout {
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000092")!)
        let refs = snapshot.records.map { PersistentAppReference.from(record: $0) }
        return PersistentWorkspaceLayout(generation: LayoutGeneration(9),
            topLevelOrder: [.app(refs[4]), .folder(folderID), .app(refs[3]), .app(refs[2])],
            folders: [.init(id: folderID, title: "Fixture group", members: [refs[1], refs[0]])])
    }

    private func controller(_ snapshot: CatalogSnapshot?, capacity: Int = 2)
        -> AppGridSearchPresentationController {
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        provider.itemsPerPage = capacity
        let controller = AppGridSearchPresentationController(provider: provider)
        controller.itemsPerPage = capacity
        return controller
    }

    func testOriginalNameQueryRetainsAliasedFolderMemberAfterLayoutCommit() throws {
        let snapshot = catalog()
        let search = controller(snapshot)
        let preferences = try XCTUnwrap(AppManagementPreferences.default
            .settingAlias("Shortcut", for: snapshot.records[0]))
        search.provider.receiveManagementPreferences(preferences)
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        let query = AppSearchQuery(raw: " Alpha ", locale: Locale(identifier: "en_US_POSIX"))
        search.updateQuery(query)
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        let generation = search.latestGeneration
        let layout = folderLayout(snapshot)

        let update = try XCTUnwrap(search.commitLayout(layout, currentPage: 0))

        XCTAssertEqual(search.currentQuery, query)
        XCTAssertEqual(search.provider.activeQuery, query)
        XCTAssertEqual(search.latestGeneration, generation.incremented())
        XCTAssertEqual(search.provider.presentationRecords.map(\.id), [snapshot.records[0].id])
        XCTAssertEqual(search.provider.presentationRecords.map(\.displayName), ["Shortcut"])
        XCTAssertEqual(search.provider.presentationEntries.map(\.identity), [.app(snapshot.records[0].id)])
        XCTAssertEqual(search.provider.expectedLayout, layout)
        XCTAssertEqual(search.provider.servedSnapshot, snapshot)
        XCTAssertEqual(update.previousRevision, 7)
        XCTAssertEqual(update.newRevision, 7)
        XCTAssertFalse(search.provider.hasPendingSearchResult)
    }

    func testAliasQueryRemainsActiveAcrossLayoutCommit() throws {
        let snapshot = catalog()
        let search = controller(snapshot)
        search.provider.receiveManagementPreferences(try XCTUnwrap(AppManagementPreferences.default
            .settingAlias("Shortcut", for: snapshot.records[0])))
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        let query = AppSearchQuery(raw: "Shortcut")
        search.updateQuery(query)
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)

        XCTAssertNotNil(search.commitLayout(folderLayout(snapshot), currentPage: 0))

        XCTAssertEqual(search.currentQuery, query)
        XCTAssertEqual(search.provider.activeQuery, query)
        XCTAssertEqual(search.provider.presentationRecords.map(\.id), [snapshot.records[0].id])
        XCTAssertEqual(search.provider.presentationRecords.map(\.displayName), ["Shortcut"])
        XCTAssertEqual(search.provider.servedRevision, 7)
        XCTAssertFalse(search.provider.hasPendingSearchResult)
    }

    func testLayoutCommitRerunsQueryAgainstNewlyCommittedHiddenPreferences() throws {
        let snapshot = catalog()
        let search = controller(snapshot)
        let preferences = try XCTUnwrap(AppManagementPreferences.default
            .settingAlias("Shortcut", for: snapshot.records[0]))
        search.provider.receiveManagementPreferences(preferences)
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        let query = AppSearchQuery(raw: "Shortcut")
        search.updateQuery(query)
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(search.provider.presentationRecords.count, 1)
        search.provider.receiveManagementPreferences(preferences.settingHidden(true, for: snapshot.records[0]))
        let layout = folderLayout(snapshot)

        XCTAssertNotNil(search.commitLayout(layout, currentPage: 0))

        XCTAssertEqual(search.currentQuery, query)
        XCTAssertEqual(search.provider.activeQuery, query)
        XCTAssertTrue(search.provider.presentationEntries.isEmpty)
        XCTAssertTrue(search.provider.presentationRecords.isEmpty)
        XCTAssertEqual(search.provider.servedPageCount, 0)
        XCTAssertEqual(search.uiState, .noResults)
        XCTAssertEqual(search.provider.expectedLayout, layout)
        XCTAssertEqual(search.provider.servedSnapshot, snapshot)
        XCTAssertFalse(search.provider.hasPendingSearchResult)
    }

    func testClearingQueryRecoversCommittedMixedOrderAndFolderMembership() throws {
        let snapshot = catalog()
        let search = controller(snapshot)
        search.updateQuery(AppSearchQuery(raw: "Alpha"))
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        let layout = folderLayout(snapshot)
        XCTAssertNotNil(search.commitLayout(layout, currentPage: 0))

        search.clearQuery()
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)

        XCTAssertEqual(search.provider.presentationEntries.map(\.identity), [
            .app(snapshot.records[4].id), .folder(layout.folders[0].id),
            .app(snapshot.records[3].id), .app(snapshot.records[2].id)
        ])
        let entry = try XCTUnwrap(search.provider.presentationEntries.dropFirst().first)
        guard case .folder(let folder) = entry else {
            return XCTFail("Expected the committed folder in the second slot")
        }
        XCTAssertEqual(folder.title, layout.folders[0].title)
        XCTAssertEqual(folder.members, [snapshot.records[1].id, snapshot.records[0].id])
        XCTAssertEqual(search.provider.presentationRecords.map(\.id), [
            snapshot.records[4].id, snapshot.records[3].id, snapshot.records[2].id
        ])
        XCTAssertEqual(search.provider.servedPageCount, 2)
        XCTAssertEqual(search.provider.expectedLayout, layout)
        XCTAssertEqual(search.provider.servedRevision, 7)
        XCTAssertFalse(search.provider.hasPendingSearchResult)
    }

    func testBeforeCatalogCommitReturnsNilWithoutLeakingLayoutOrSearchPending() throws {
        let snapshot = catalog()
        let search = controller(nil)
        let query = AppSearchQuery(raw: "Alpha")
        search.updateQuery(query)
        search.receive(snapshot)
        let generation = search.latestGeneration
        var presentationCallbacks = 0
        var searchCallbacks = 0
        search.onPresentationUpdate = { _ in presentationCallbacks += 1 }
        search.onSearchResultCommitted = { searchCallbacks += 1 }

        XCTAssertNil(search.commitLayout(folderLayout(snapshot), currentPage: 99))

        XCTAssertEqual(search.latestGeneration, generation)
        XCTAssertEqual(search.currentQuery, query)
        XCTAssertNil(search.provider.activeQuery)
        XCTAssertNil(search.provider.expectedLayout)
        XCTAssertNil(search.provider.servedSnapshot)
        XCTAssertEqual(search.provider.pendingSnapshot, snapshot)
        XCTAssertFalse(search.provider.hasPendingSearchResult)
        XCTAssertFalse(search.provider.hasPendingFolderSnapshot)
        XCTAssertTrue(search.provider.presentationEntries.isEmpty)
        XCTAssertEqual(presentationCallbacks, 0)
        XCTAssertEqual(searchCallbacks, 0)

        // The rejected layout must not appear when the already-pending catalog arrives.
        XCTAssertNotNil(search.applyPendingAtIdleBoundary(currentPage: 0))
        XCTAssertNil(search.provider.expectedLayout)
        XCTAssertEqual(search.provider.activeQuery, query)
        search.clearQuery()
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(search.provider.presentationEntries.map(\.identity), snapshot.records.map { .app($0.id) })
        XCTAssertFalse(search.provider.hasPendingSnapshot)
        XCTAssertFalse(search.provider.hasPendingSearchResult)
    }

    func testNoQueryCommitReturnsLayoutPlanUsingSharedNondefaultCapacity() throws {
        let snapshot = catalog()
        let search = controller(snapshot)
        let update = try XCTUnwrap(search.commitLayout(folderLayout(snapshot), currentPage: 99))

        XCTAssertEqual(update.plan.itemsPerPage, 2)
        XCTAssertEqual(update.plan.itemCount, 4)
        XCTAssertEqual(update.plan.pageCount, 2)
        XCTAssertEqual(update.plan.pageCount, search.provider.servedPageCount)
        XCTAssertEqual(update.topLevelAnchor, .app(snapshot.records[4].id))
        XCTAssertEqual(update.outcome, .located(pageIndex: 0))
        XCTAssertEqual(update.newRevision, 7)
        XCTAssertNil(search.currentQuery)
        XCTAssertNil(search.provider.activeQuery)
        XCTAssertEqual(search.latestGeneration, .zero)
        XCTAssertFalse(search.provider.hasPendingSearchResult)
    }

    func testActiveQueryKeepsLayoutPlanAndSearchCountsAtSameCapacity() throws {
        let snapshot = catalog()
        let search = controller(snapshot)
        // This matches four apps, including both members of the new folder.
        search.updateQuery(AppSearchQuery(raw: "a"))
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        let update = try XCTUnwrap(search.commitLayout(folderLayout(snapshot), currentPage: 1))

        XCTAssertEqual(update.plan.itemsPerPage, 2)
        XCTAssertEqual(update.plan.itemCount, 4)
        XCTAssertEqual(update.plan.pageCount, 2)
        XCTAssertEqual(search.provider.presentationRecords.map(\.id), Array(snapshot.records.prefix(4)).map(\.id))
        XCTAssertEqual(search.provider.presentationEntries.count, 4)
        XCTAssertEqual(search.provider.servedPageCount, 2)

        search.updateQuery(AppSearchQuery(raw: "Alpha"))
        let filteredUpdate = try XCTUnwrap(search.commitLayout(folderLayout(snapshot), currentPage: 1))
        // The returned plan describes the layout; the caller uses the final search presentation.
        XCTAssertEqual(filteredUpdate.plan.itemsPerPage, 2)
        XCTAssertEqual(filteredUpdate.plan.itemCount, 4)
        XCTAssertEqual(filteredUpdate.plan.pageCount, 2)
        XCTAssertEqual(search.provider.presentationRecords.map(\.id), [snapshot.records[0].id])
        XCTAssertEqual(search.provider.servedPageCount, 1)
        XCTAssertEqual(search.provider.servedSnapshot, snapshot)
        XCTAssertFalse(search.provider.hasPendingSearchResult)
    }

    func testLayoutCommitConsumesLatestQueryWithoutCallbacksOrDeferredDuplicate() throws {
        let snapshot = catalog()
        let search = controller(snapshot)
        search.updateQuery(AppSearchQuery(raw: "Alpha"))
        _ = search.applyPendingAtIdleBoundary(currentPage: 0)
        search.updateQuery(AppSearchQuery(raw: "Beta"))
        let query = AppSearchQuery(raw: "Gamma")
        search.updateQuery(query)
        XCTAssertTrue(search.provider.hasPendingSearchResult)
        var presentationCallbacks = 0
        var searchCallbacks = 0
        search.onPresentationUpdate = { _ in presentationCallbacks += 1 }
        search.onSearchResultCommitted = { searchCallbacks += 1 }

        XCTAssertNotNil(search.commitLayout(folderLayout(snapshot), currentPage: 0))

        XCTAssertEqual(search.currentQuery, query)
        XCTAssertEqual(search.provider.activeQuery, query)
        XCTAssertEqual(search.provider.presentationRecords.map(\.id), [snapshot.records[2].id])
        XCTAssertFalse(search.provider.hasPendingSearchResult)
        XCTAssertFalse(search.provider.hasPendingSnapshot)
        XCTAssertFalse(search.provider.hasPendingFolderSnapshot)
        XCTAssertEqual(presentationCallbacks, 0)
        XCTAssertEqual(searchCallbacks, 0)
        XCTAssertNil(search.applyPendingAtIdleBoundary(currentPage: 0))
        XCTAssertEqual(presentationCallbacks, 0)
        XCTAssertEqual(searchCallbacks, 0)
    }
}
