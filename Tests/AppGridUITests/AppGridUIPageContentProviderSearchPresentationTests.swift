// AppGridUITests — AppGridUIPageContentProvider 搜索呈现（§9.3 / §16.2：
// base/presentation records；servedRevision 保持 base revision；content 切片 presentation records；
// pending search 不泄露；latest-wins；page count 由 result count 推导；anchor 保留/降级）

import AppCatalogCore
import AppIconPipeline
import PagingUI
@testable import AppGridUI
import XCTest

final class AppGridUIPageContentProviderSearchPresentationTests: XCTestCase {

    private func makeResult(baseRevision: UInt64, generation: UInt64,
                            records: [AppRecord]) -> AppSearchResultSet {
        AppSearchResultSet(baseCatalogRevision: CatalogRevision(baseRevision),
                           queryGeneration: AppSearchGeneration(generation),
                           records: records)
    }

    // MARK: - 空 query = base records

    func testEmptyQueryPresentsBaseRecords() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)

        provider.stageSearchResult(makeResult(baseRevision: 1, generation: 1, records: snapshot.records))
        XCTAssertTrue(provider.commitPendingSearchResult(query: AppSearchQuery(raw: "")))

        XCTAssertEqual(provider.presentationRecords.count, 3, "空 query → base records")
        XCTAssertEqual(provider.servedRevision, 1)
        let content = provider.content(for: PagePresentationID(revision: 1, pageIndex: 0), itemsPerPage: 35)
        XCTAssertEqual(content.items.map { $0.title }, ["Alpha", "Beta", "Gamma"])
    }

    // MARK: - 非空 query = filtered records

    func testNonEmptyQueryPresentsFilteredRecords() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)

        let filtered = snapshot.records.filter { $0.displayName.contains("e") } // Beta
        provider.stageSearchResult(makeResult(baseRevision: 1, generation: 1, records: filtered))
        XCTAssertTrue(provider.commitPendingSearchResult(query: AppSearchQuery(raw: "e")))

        XCTAssertEqual(provider.presentationRecords.map { $0.displayName }, ["Beta"])
        XCTAssertEqual(provider.servedRevision, 1, "servedRevision 不因 query 变化")
        let content = provider.content(for: PagePresentationID(revision: 1, pageIndex: 0), itemsPerPage: 35)
        XCTAssertEqual(content.items.map { $0.title }, ["Beta"])
    }

    // MARK: - servedRevision 不因 query 变化（不 mint 假 revision）

    func testServedRevisionUnchangedByQuery() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 7)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        XCTAssertEqual(provider.servedRevision, 7)

        provider.stageSearchResult(makeResult(baseRevision: 7, generation: 1, records: [snapshot.records[0]]))
        XCTAssertTrue(provider.commitPendingSearchResult(query: AppSearchQuery(raw: "Alpha")))

        XCTAssertEqual(provider.servedRevision, 7, "查询变化绝不 mint 假 revision")
        XCTAssertEqual(provider.baseSnapshot?.revision.value, 7)
    }

    // MARK: - page count 由 result count 推导

    func testPageCountFromResultCount() throws {
        let snapshot = try makeSnapshot(titles: (0..<70).map { "App\($0)" }, revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        XCTAssertEqual(provider.servedPageCount, 2, "70 base → 2 页")

        // 过滤到 1 条 → 1 页
        provider.stageSearchResult(makeResult(baseRevision: 1, generation: 1, records: [snapshot.records[0]]))
        XCTAssertTrue(provider.commitPendingSearchResult(query: AppSearchQuery(raw: "App0")))
        XCTAssertEqual(provider.servedPageCount, 1)

        // 0 结果 → 0 页（合法空态；search field 仍可交互）
        provider.stageSearchResult(makeResult(baseRevision: 1, generation: 2, records: []))
        XCTAssertTrue(provider.commitPendingSearchResult(query: AppSearchQuery(raw: "zzz")))
        XCTAssertEqual(provider.servedPageCount, 0)
        XCTAssertTrue(provider.content(for: PagePresentationID(revision: 1, pageIndex: 0),
                                       itemsPerPage: 35).isPlaceholder, "0 结果 → 任何页请求占位")
    }

    // MARK: - content 只命中已提交 result（pending 不泄露）

    func testContentOnlyHitsCommittedResult() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)

        // 暂存但未提交 → content 仍为 base records（pending 不读）
        provider.stageSearchResult(makeResult(baseRevision: 1, generation: 1, records: [snapshot.records[0]]))
        let before = provider.content(for: PagePresentationID(revision: 1, pageIndex: 0), itemsPerPage: 35)
        XCTAssertEqual(before.items.count, 3, "pending 未提交 → content 不读 pending")
        XCTAssertEqual(provider.servedPageCount, 1, "pending 未提交 → pageCount 不变（3 条 = 1 页）")

        // 提交后 → content 为过滤结果
        XCTAssertTrue(provider.commitPendingSearchResult(query: AppSearchQuery(raw: "Alpha")))
        let after = provider.content(for: PagePresentationID(revision: 1, pageIndex: 0), itemsPerPage: 35)
        XCTAssertEqual(after.items.count, 1)
        XCTAssertEqual(after.items[0].title, "Alpha")
    }

    /// pending search 不泄露到当前手势页：手势期间（未提交）content 保持旧呈现。
    func testPendingSearchNotLeakedToCurrentGesturePage() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)

        // 手势期间新 query 结果暂存（未提交）→ 当前页内容不变
        provider.stageSearchResult(makeResult(baseRevision: 1, generation: 1, records: [snapshot.records[2]]))
        let duringGesture = provider.content(for: PagePresentationID(revision: 1, pageIndex: 0), itemsPerPage: 35)
        XCTAssertEqual(duringGesture.items.count, 3, "手势期间 pending 不替换已提交呈现")
        XCTAssertEqual(provider.hasPendingSearchResult, true)
    }

    // MARK: - 快速 query latest-wins

    func testRapidQueryLatestWins() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)

        provider.stageSearchResult(makeResult(baseRevision: 1, generation: 1, records: [snapshot.records[0]]))
        provider.stageSearchResult(makeResult(baseRevision: 1, generation: 2, records: [snapshot.records[1]]))
        provider.stageSearchResult(makeResult(baseRevision: 1, generation: 3, records: [snapshot.records[2]]))

        XCTAssertEqual(provider.pendingSearchResult?.queryGeneration, AppSearchGeneration(3),
                       "latest-wins：连续 stage 只保留最新")
        XCTAssertTrue(provider.commitPendingSearchResult(query: AppSearchQuery(raw: "Gamma")))
        XCTAssertEqual(provider.presentationRecords.map { $0.displayName }, ["Gamma"])
    }

    // MARK: - 旧 base revision 结果拒绝（latest-wins 双轴）

    func testStaleBaseRevisionResultRejected() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)

        // 结果基于旧 base revision 2，但当前 base 是 1 → 拒绝提交
        provider.stageSearchResult(makeResult(baseRevision: 2, generation: 1, records: [snapshot.records[0]]))
        XCTAssertFalse(provider.commitPendingSearchResult(query: AppSearchQuery(raw: "Alpha")),
                       "旧 base revision 结果拒绝")
        XCTAssertEqual(provider.presentationRecords.count, 3, "拒绝后保持 base records")
        XCTAssertNil(provider.pendingSearchResult, "拒绝后清空 pending")
    }

    // MARK: - anchor 保留/降级（§16.2 / ADR-007 §2.5）

    func testAnchorPreservedWhenStillInResults() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        let anchor = try XCTUnwrap(provider.anchorCandidate(nearPage: 0))
        XCTAssertEqual(anchor, makeAppID("fixture.alpha"))

        // 搜索提交后 anchor 仍在结果中 → 可定位
        provider.stageSearchResult(makeResult(baseRevision: 1, generation: 1, records: snapshot.records))
        XCTAssertTrue(provider.commitPendingSearchResult(query: AppSearchQuery(raw: "")))
        XCTAssertEqual(provider.pageIndex(of: anchor, itemsPerPage: 35), 0, "anchor 仍在结果中 → located")
    }

    func testAnchorDegradesWhenRemovedFromResults() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        let anchor = try XCTUnwrap(provider.anchorCandidate(nearPage: 0))
        XCTAssertEqual(anchor, makeAppID("fixture.alpha"))

        // 搜索移除 anchor → pageIndex nil（不在结果中）
        provider.stageSearchResult(makeResult(baseRevision: 1, generation: 1,
                                              records: [snapshot.records[1], snapshot.records[2]]))
        XCTAssertTrue(provider.commitPendingSearchResult(query: AppSearchQuery(raw: "Beta")))
        XCTAssertNil(provider.pageIndex(of: anchor, itemsPerPage: 35), "anchor 不在结果中 → 降级")
        XCTAssertEqual(provider.presentationRecords.map { $0.displayName }, ["Beta", "Gamma"])
    }

    // MARK: - base 空 vs 无搜索结果区分（§16.2 / §10）

    func testBaseEmptyVsNoSearchResultsDistinguished() throws {
        // base 空 → presentationRecords 空（.empty 语义）
        let emptyBase = try makeSnapshot(titles: [], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: emptyBase)
        XCTAssertTrue(provider.presentationRecords.isEmpty)
        XCTAssertEqual(provider.servedPageCount, 0)

        // base 非空 + 0 结果 → presentationRecords 空（.noResults 语义，由控制器 uiState 区分）
        let nonEmptyBase = try makeSnapshot(titles: ["Alpha", "Beta"], revision: 2)
        let provider2 = AppGridUIPageContentProvider(snapshot: nonEmptyBase)
        provider2.stageSearchResult(makeResult(baseRevision: 2, generation: 1, records: []))
        XCTAssertTrue(provider2.commitPendingSearchResult(query: AppSearchQuery(raw: "zzz")))
        XCTAssertTrue(provider2.presentationRecords.isEmpty)
        XCTAssertEqual(provider2.servedPageCount, 0)
        XCTAssertEqual(provider2.baseSnapshot?.records.count, 2, "base 非空（与空目录区分）")
    }
}
