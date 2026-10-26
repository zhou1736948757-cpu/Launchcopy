import AppCatalogCore
import XCTest
@testable import AppGridUI

final class ProviderPendingPresentationTests: XCTestCase {
    func testEveryPendingOwnerPreventsPresentationRetentionUntilItsWorkIsConsumed() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta"], revision: 1)
        let work: [(String, (AppGridUIPageContentProvider) -> Void)] = [
            ("catalog", { $0.receive(snapshot) }),
            ("folders", { $0.receiveFolderSnapshot(.init(generation: .zero, entries: [])) }),
            ("layout", { $0.receiveExpectedLayout(.empty()) }),
            ("management", { $0.receiveManagementPreferences(.init(searchByBundleIdentifier: true)) }),
            ("search", { $0.stageSearchResult(.init(baseCatalogRevision: snapshot.revision,
                queryGeneration: .zero, records: snapshot.records)) })
        ]
        for (owner, enqueue) in work {
            let provider = AppGridUIPageContentProvider(snapshot: snapshot)
            XCTAssertFalse(provider.hasPendingPresentationChanges, owner)
            enqueue(provider)
            XCTAssertTrue(provider.hasPendingPresentationChanges, owner)
            XCTAssertEqual(provider.servedSnapshot, snapshot, "Reading pending work must not commit it")
            _ = provider.applyPending(atCurrentPage: 0)
            _ = provider.commitPendingSearchResult(query: nil)
            XCTAssertFalse(provider.hasPendingPresentationChanges, owner)
        }
    }

    func testConsumingOnePendingOwnerDoesNotHideAnotherOwnersWork() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        provider.receive(snapshot)
        provider.stageSearchResult(.init(baseCatalogRevision: snapshot.revision,
            queryGeneration: .zero, records: snapshot.records))
        provider.discardPending()
        XCTAssertTrue(provider.hasPendingPresentationChanges)
        provider.discardPendingSearchResult()
        XCTAssertFalse(provider.hasPendingPresentationChanges)
    }
}
