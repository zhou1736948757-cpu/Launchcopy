// AppGridUITests — AppGridSearchPresentationController（§9.3 / §16.2 / ADR-007 §2.3-2.5：
// 查询代 latest-wins；过滤结果集；idle 边界提交；catalog refresh 优先 + 重跑 query；
// 无结果中性态（AppGridUIState.noResults + AppGridStatusView 渲染））

import AppCatalogCore
import AppIconPipeline
import AppKit
import PagingUI
@testable import AppGridUI
import XCTest

@MainActor
final class AppGridSearchPresentationControllerTests: XCTestCase {

    private func makeController(snapshot: CatalogSnapshot? = nil) -> AppGridSearchPresentationController {
        AppGridSearchPresentationController(provider: AppGridUIPageContentProvider(snapshot: snapshot))
    }

    // MARK: - 查询变化 → 过滤结果集

    func testUpdateQueryStagesFilteredResult() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let controller = makeController(snapshot: snapshot)

        controller.updateQuery(AppSearchQuery(raw: "e"))

        XCTAssertEqual(controller.latestGeneration, AppSearchGeneration(1))
        XCTAssertEqual(controller.provider.pendingSearchResult?.queryGeneration, AppSearchGeneration(1))
        XCTAssertEqual(controller.provider.pendingSearchResult?.baseCatalogRevision.value, 1)
        XCTAssertEqual(controller.provider.pendingSearchResult?.records.map { $0.displayName },
                       ["Beta"], "过滤结果保持 base 顺序")
    }

    func testEmptyQueryStagesBaseRecords() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let controller = makeController(snapshot: snapshot)

        controller.updateQuery(AppSearchQuery(raw: "   "))

        XCTAssertEqual(controller.provider.pendingSearchResult?.records.count, 3,
                       "空/纯空白 query → base records（无过滤）")
    }

    func testQueryGenerationMonotonic() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let controller = makeController(snapshot: snapshot)

        controller.updateQuery(AppSearchQuery(raw: "a"))
        controller.updateQuery(AppSearchQuery(raw: "b"))
        controller.updateQuery(AppSearchQuery(raw: "c"))

        XCTAssertEqual(controller.latestGeneration, AppSearchGeneration(3), "查询代单调递增")
        XCTAssertEqual(controller.provider.pendingSearchResult?.queryGeneration, AppSearchGeneration(3),
                       "latest-wins：只保留最新 generation")
    }

    // MARK: - idle 边界提交

    func testIdleBoundaryCommitsSearchResult() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let controller = makeController(snapshot: snapshot)
        var committed = 0
        controller.onSearchResultCommitted = { committed += 1 }

        controller.updateQuery(AppSearchQuery(raw: "e"))
        let update = controller.applyPendingAtIdleBoundary(currentPage: 0)

        XCTAssertNil(update, "无 pending catalog → 无 catalog update")
        XCTAssertEqual(committed, 1, "搜索结果提交回调触发")
        XCTAssertEqual(controller.provider.presentationRecords.map { $0.displayName }, ["Beta"])
        XCTAssertEqual(controller.provider.servedRevision, 1, "servedRevision 保持 base revision")
        XCTAssertFalse(controller.provider.hasPendingSearchResult)
    }

    func testIdleBoundaryNoOpWithoutPending() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let controller = makeController(snapshot: snapshot)
        var committed = 0
        controller.onSearchResultCommitted = { committed += 1 }

        XCTAssertNil(controller.applyPendingAtIdleBoundary(currentPage: 0))
        XCTAssertEqual(committed, 0, "无 pending → 无操作")
    }

    // MARK: - catalog refresh 优先 + 重跑 query（§2.4 / §16.2）

    func testCatalogRefreshRerunsQueryOnNewBase() throws {
        let snapshot1 = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let controller = makeController(snapshot: snapshot1)
        controller.updateQuery(AppSearchQuery(raw: "e"))
        controller.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(controller.provider.presentationRecords.map { $0.displayName }, ["Beta"])

        // catalog refresh 到新 base（revision 2），query 仍激活 → 在新 base 上重跑
        let snapshot2 = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma", "Delta"], revision: 2)
        controller.receive(snapshot2)
        let update = controller.applyPendingAtIdleBoundary(currentPage: 0)

        XCTAssertNotNil(update, "catalog refresh 提交")
        XCTAssertEqual(update?.newRevision, 2)
        XCTAssertEqual(controller.provider.servedRevision, 2)
        XCTAssertEqual(controller.provider.presentationRecords.map { $0.displayName },
                       ["Beta", "Delta"], "新 base 上重跑 query 'e'")
    }

    func testCatalogRefreshSupersedesOlderQueryResult() throws {
        let snapshot1 = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let controller = makeController(snapshot: snapshot1)
        controller.updateQuery(AppSearchQuery(raw: "e"))
        XCTAssertTrue(controller.provider.hasPendingSearchResult, "手势期间 query 结果暂存")

        // catalog refresh 到新 base → 新 base 提交，旧 query 结果被取代并重跑
        let snapshot2 = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma", "Delta"], revision: 2)
        controller.receive(snapshot2)
        let update = controller.applyPendingAtIdleBoundary(currentPage: 0)

        XCTAssertNotNil(update)
        XCTAssertEqual(controller.provider.servedRevision, 2)
        XCTAssertEqual(controller.provider.presentationRecords.map { $0.displayName },
                       ["Beta", "Delta"], "新 catalog revision 取代旧同 revision query 结果")
    }

    // MARK: - 状态推导（§10：base 空 vs 无搜索结果）

    func testUIStateDistinguishesEmptyAndNoResults() throws {
        // 无 base → loading
        let controller = makeController()
        XCTAssertEqual(controller.uiState, .loading)

        // base 空 → empty
        let emptyBase = try makeSnapshot(titles: [], revision: 1)
        let c2 = makeController(snapshot: emptyBase)
        XCTAssertEqual(c2.uiState, .empty)

        // base 非空 + 无 query → ready
        let base = try makeSnapshot(titles: ["Alpha", "Beta"], revision: 1)
        let c3 = makeController(snapshot: base)
        XCTAssertEqual(c3.uiState, .ready)

        // base 非空 + active 非空 query + 0 结果 → noResults
        c3.updateQuery(AppSearchQuery(raw: "zzz"))
        c3.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(c3.provider.presentationRecords.count, 0)
        XCTAssertEqual(c3.uiState, .noResults)

        // 清空 query → ready（base records）
        c3.clearQuery()
        c3.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(c3.uiState, .ready)
    }

    // MARK: - 无结果中性态渲染（AppGridStatusView）

    func testNoResultsStatusViewRendersNeutralText() {
        let view = AppGridStatusView(frame: NSRect(x: 0, y: 0, width: 400, height: 120))
        view.update(state: .noResults)

        XCTAssertEqual(view.state, .noResults)
        XCTAssertEqual(view.statusText, AppGridUIState.noResults.accessibilityDescription)
        XCTAssertEqual(view.accessibilityLabel(), AppGridUIState.noResults.accessibilityDescription)
        let spinner = view.subviews.compactMap { $0 as? NSProgressIndicator }.first
        XCTAssertTrue(spinner?.isHidden ?? false, "noResults 不显示 spinner")
        XCTAssertFalse(view.statusText.contains("zzz"), "空状态文本不含 query 原文")
        XCTAssertFalse(view.statusText.contains("fixture"), "空状态文本不含 app 名")
    }
}
