// AppGridUITests — FolderSearchFlatteningTests（Phase 1E / ADR-008 §2.1/§2.4：
// 搜索扁平化为 app-only（成员扁平化）；搜索只按 app 显示名过滤，绝不按 folder 标题；
// 退出搜索恢复完整顶层组合；搜索激活时页数由扁平化 app 数推导）

import AppCatalogCore
import AppIconPipeline
import PagingUI
@testable import AppGridUI
import XCTest

@MainActor
final class FolderSearchFlatteningTests: XCTestCase {

    private func makeFolder(id: FolderID, title: String, members: [AppID]) -> FolderEntry {
        FolderEntryBuilder.make(id: id, title: title, members: members)
    }

    private func makeFolders(generation: UInt64, entries: [FolderEntry]) -> FolderSnapshot {
        FolderSnapshot(generation: FolderGeneration(generation), entries: entries)
    }

    private func makeResult(baseRevision: UInt64, generation: UInt64,
                            records: [AppRecord]) -> AppSearchResultSet {
        AppSearchResultSet(baseCatalogRevision: CatalogRevision(baseRevision),
                           queryGeneration: AppSearchGeneration(generation),
                           records: records)
    }

    /// 搜索激活 → presentation 为 app-only（成员扁平化，folder 隐藏）。
    func testSearchFlattensToAppOnly() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let folder = makeFolder(id: FolderID(uuid: UUID()), title: "G1",
                                members: [makeAppID("fixture.alpha"), makeAppID("fixture.beta")])
        let provider = AppGridUIPageContentProvider(snapshot: snapshot,
                                                   folderSnapshot: makeFolders(generation: 1, entries: [folder]))
        XCTAssertEqual(provider.presentationEntries.count, 2, "folder + Gamma")

        // 非空 query（搜索激活）→ app-only（成员扁平化）
        XCTAssertTrue(provider.commitPendingSearchResult(
            query: AppSearchQuery(raw: "a"),
            result: makeResult(baseRevision: 1, generation: 1, records: snapshot.records)))
        XCTAssertEqual(provider.presentationEntries.count, 3, "搜索扁平化成员为 app-only")
        XCTAssertEqual(provider.presentationEntries.map { $0.identity },
                       [.app(makeAppID("fixture.alpha")),
                        .app(makeAppID("fixture.beta")),
                        .app(makeAppID("fixture.gamma"))])
        XCTAssertEqual(provider.presentationRecords.count, 3, "app-only 投影")
    }

    /// 搜索只按 app 显示名过滤，绝不按 folder 标题（经搜索控制器全流程）。
    func testSearchFiltersByAppNameNotFolderTitle() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let folder = makeFolder(id: FolderID(uuid: UUID()), title: "G1",
                                members: [makeAppID("fixture.alpha"), makeAppID("fixture.beta")])
        let provider = AppGridUIPageContentProvider(snapshot: snapshot,
                                                   folderSnapshot: makeFolders(generation: 1, entries: [folder]))
        let controller = AppGridSearchPresentationController(provider: provider)

        // 按 folder 标题 "G1" 搜索 → 无 app 显示名匹配 → 0 结果
        controller.updateQuery(AppSearchQuery(raw: "G1"))
        controller.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(controller.provider.presentationEntries.count, 0, "folder 标题绝不匹配搜索")
        XCTAssertEqual(controller.provider.servedPageCount, 0)

        // 按 app 显示名 "Gamma" 搜索 → 命中
        controller.updateQuery(AppSearchQuery(raw: "Gamma"))
        controller.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(controller.provider.presentationEntries.count, 1)
        XCTAssertEqual(controller.provider.presentationEntries[0].identity,
                       .app(makeAppID("fixture.gamma")))
    }

    /// 退出搜索（清空 query）→ 恢复完整顶层组合（apps + folders）。
    func testExitingSearchRestoresComposition() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let folder = makeFolder(id: FolderID(uuid: UUID()), title: "G1",
                                members: [makeAppID("fixture.alpha"), makeAppID("fixture.beta")])
        let provider = AppGridUIPageContentProvider(snapshot: snapshot,
                                                   folderSnapshot: makeFolders(generation: 1, entries: [folder]))

        // 搜索激活 → app-only
        XCTAssertTrue(provider.commitPendingSearchResult(
            query: AppSearchQuery(raw: "Gamma"),
            result: makeResult(baseRevision: 1, generation: 1, records: [snapshot.records[2]])))
        XCTAssertEqual(provider.presentationEntries.count, 1)

        // 清空 query → 恢复完整组合
        XCTAssertTrue(provider.commitPendingSearchResult(
            query: AppSearchQuery(raw: ""),
            result: makeResult(baseRevision: 1, generation: 2, records: snapshot.records)))
        XCTAssertEqual(provider.presentationEntries.count, 2, "退出搜索恢复完整顶层组合")
        XCTAssertEqual(provider.presentationEntries[0].identity, .folder(folder.id))
        XCTAssertEqual(provider.presentationEntries[1].identity, .app(makeAppID("fixture.gamma")))
    }

    /// 搜索激活时页数由扁平化 app 数推导（folder 槽位不参与）。
    func testSearchResultAppOnlyPageCount() throws {
        let snapshot = try makeSnapshot(titles: (0..<36).map { "App\($0)" }, revision: 1)
        let folder = makeFolder(id: FolderID(uuid: UUID()), title: "G1",
                                members: [makeAppID("fixture.app0"), makeAppID("fixture.app1")])
        let provider = AppGridUIPageContentProvider(snapshot: snapshot,
                                                   folderSnapshot: makeFolders(generation: 1, entries: [folder]))
        // 1 folder + 34 未分组 = 35 条目 → 1 页
        XCTAssertEqual(provider.servedPageCount, 1)

        // 搜索激活 → 36 apps → 2 页
        XCTAssertTrue(provider.commitPendingSearchResult(
            query: AppSearchQuery(raw: "a"),
            result: makeResult(baseRevision: 1, generation: 1, records: snapshot.records)))
        XCTAssertEqual(provider.servedPageCount, 2, "搜索激活页数由扁平化 app 数推导")
    }

    /// 搜索提交后 content 只命中 app-only 呈现（folder 隐藏）。
    func testSearchContentIsAppOnly() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let folder = makeFolder(id: FolderID(uuid: UUID()), title: "G1",
                                members: [makeAppID("fixture.alpha"), makeAppID("fixture.beta")])
        let provider = AppGridUIPageContentProvider(snapshot: snapshot,
                                                   folderSnapshot: makeFolders(generation: 1, entries: [folder]))

        XCTAssertTrue(provider.commitPendingSearchResult(
            query: AppSearchQuery(raw: "a"),
            result: makeResult(baseRevision: 1, generation: 1, records: snapshot.records)))
        let content = provider.content(for: PagePresentationID(revision: 1, pageIndex: 0), itemsPerPage: 35)
        XCTAssertEqual(content.items.map { $0.title }, ["Alpha", "Beta", "Gamma"],
                       "搜索激活 content 为 app-only，无 folder 标题")
    }
}

// MARK: - 测试辅助：带 result 的 commit（避免与既有签名混淆）

private extension AppGridUIPageContentProvider {
    /// 便捷：stage + commit 一次搜索结果。
    @discardableResult
    func commitPendingSearchResult(query: AppSearchQuery?, result: AppSearchResultSet) -> Bool {
        stageSearchResult(result)
        return commitPendingSearchResult(query: query)
    }
}
