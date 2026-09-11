// AppGridUITests — TopLevelCompositionTests（Phase 1E / ADR-008 §2.1/§2.4：
// 顶层组合 [TopLevelEntry]（app + folder）；页数由组合条目数推导（folder = 一个槽位）；
// anchor/pageIndex 作用于组合；idle 原子提交（catalog + folder）；folder latest-wins；
// 刷新不重复/不遗漏/不伪造 CatalogRevision；单成员解散；folder generation 独立）

import AppCatalogCore
import AppIconPipeline
import PagingUI
@testable import AppGridUI
import XCTest

final class TopLevelCompositionTests: XCTestCase {

    private func makeFolder(id: FolderID, title: String, members: [AppID]) -> FolderEntry {
        FolderEntryBuilder.make(id: id, title: title, members: members)
    }

    private func makeFolders(generation: UInt64, entries: [FolderEntry]) -> FolderSnapshot {
        FolderSnapshot(generation: FolderGeneration(generation), entries: entries)
    }

    // MARK: - 顶层组合（app + folder）

    /// 空查询：顶层组合 = 文件夹在前 + 未分组 app 在后；content 呈现 folder 标题。
    func testEmptyQueryShowsAppsAndFolders() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let folderID = FolderID(uuid: UUID())
        let folder = makeFolder(id: folderID, title: "Group 1",
                                members: [makeAppID("fixture.alpha"), makeAppID("fixture.beta")])
        let provider = AppGridUIPageContentProvider(snapshot: snapshot,
                                                   folderSnapshot: makeFolders(generation: 1, entries: [folder]))

        XCTAssertEqual(provider.presentationEntries.count, 2, "folder + 未分组 Gamma")
        XCTAssertEqual(provider.presentationEntries[0].identity, .folder(folderID))
        XCTAssertEqual(provider.presentationEntries[1].identity, .app(makeAppID("fixture.gamma")))

        let content = provider.content(for: PagePresentationID(revision: 1, pageIndex: 0), itemsPerPage: 35)
        XCTAssertFalse(content.isPlaceholder)
        XCTAssertEqual(content.items.count, 2)
        XCTAssertEqual(content.items[0].title, "Group 1")
        XCTAssertEqual(content.items[0].identity as? FolderID, folderID, "folder 身份经 AnyHashable 承载")
        XCTAssertEqual(content.items[1].title, "Gamma")
    }

    /// 页数由顶层组合条目数推导（每个 folder = 一个槽位）。
    func testPageCountFromTopLevelEntries() throws {
        let snapshot = try makeSnapshot(titles: (0..<70).map { "App\($0)" }, revision: 1)
        let f1 = makeFolder(id: FolderID(uuid: UUID()), title: "G1",
                            members: [makeAppID("fixture.app0"), makeAppID("fixture.app1")])
        let f2 = makeFolder(id: FolderID(uuid: UUID()), title: "G2",
                            members: [makeAppID("fixture.app2"), makeAppID("fixture.app3")])
        let provider = AppGridUIPageContentProvider(snapshot: snapshot,
                                                   folderSnapshot: makeFolders(generation: 1, entries: [f1, f2]))
        // 2 folder + 66 未分组 = 68 条目 → ceil(68/35) = 2 页
        XCTAssertEqual(provider.presentationEntries.count, 68)
        XCTAssertEqual(provider.servedPageCount, 2)
    }

    /// folder 是一个槽位（2 成员 folder 计 1 槽，不重复成员）。
    func testFolderIsOneSlot() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let folder = makeFolder(id: FolderID(uuid: UUID()), title: "G1",
                                members: [makeAppID("fixture.alpha"), makeAppID("fixture.beta")])
        let provider = AppGridUIPageContentProvider(snapshot: snapshot,
                                                   folderSnapshot: makeFolders(generation: 1, entries: [folder]))
        XCTAssertEqual(provider.presentationEntries.count, 2, "1 folder + 1 未分组 = 2 槽位（成员不重复）")
        XCTAssertEqual(provider.servedPageCount, 1)
    }

    // MARK: - anchor / pageIndex 作用于顶层组合

    /// topLevelAnchorCandidate = committed page 首个可见条目身份（folder 或 app）。
    func testTopLevelAnchorCandidate() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let folderID = FolderID(uuid: UUID())
        let folder = makeFolder(id: folderID, title: "G1",
                                members: [makeAppID("fixture.alpha"), makeAppID("fixture.beta")])
        let provider = AppGridUIPageContentProvider(snapshot: snapshot,
                                                   folderSnapshot: makeFolders(generation: 1, entries: [folder]))
        XCTAssertEqual(provider.topLevelAnchorCandidate(nearPage: 0), .folder(folderID))
        // 向后兼容 anchorCandidate：基于 app-only 投影 → 首个未分组 app（Gamma）
        XCTAssertEqual(provider.anchorCandidate(nearPage: 0), makeAppID("fixture.gamma"))
    }

    /// topLevelPageIndex 定位 folder/app 身份；folder 成员不在顶层。
    func testTopLevelPageIndex() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let folderID = FolderID(uuid: UUID())
        let folder = makeFolder(id: folderID, title: "G1",
                                members: [makeAppID("fixture.alpha"), makeAppID("fixture.beta")])
        let provider = AppGridUIPageContentProvider(snapshot: snapshot,
                                                   folderSnapshot: makeFolders(generation: 1, entries: [folder]))
        XCTAssertEqual(provider.topLevelPageIndex(of: .folder(folderID)), 0)
        XCTAssertEqual(provider.topLevelPageIndex(of: .app(makeAppID("fixture.gamma"))), 0)
        XCTAssertNil(provider.topLevelPageIndex(of: .app(makeAppID("fixture.alpha"))),
                     "alpha 在 folder 内，不在顶层")
    }

    // MARK: - idle 原子提交（catalog + folder）

    /// idle 边界一次性原子提交 catalog + folder；folder 收缩分配新 generation。
    func testIdleCommitAtomicCatalogAndFolder() throws {
        let snapshot1 = try makeSnapshot(titles: ["Alpha", "Beta"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot1)

        let snapshot2 = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 2)
        let folder = makeFolder(id: FolderID(uuid: UUID()), title: "G1",
                                members: [makeAppID("fixture.alpha"), makeAppID("fixture.beta")])
        provider.receive(snapshot2)
        provider.receiveFolderSnapshot(makeFolders(generation: 1, entries: [folder]))

        XCTAssertTrue(provider.hasPendingSnapshot)
        XCTAssertTrue(provider.hasPendingFolderSnapshot)

        let update = provider.applyPending(atCurrentPage: 0)
        XCTAssertNotNil(update)
        XCTAssertEqual(provider.servedRevision, 2)
        XCTAssertEqual(provider.servedFolderSnapshot?.generation, FolderGeneration(1),
                       "rebase 从 served nil → .zero → 分配 generation 1")
        XCTAssertFalse(provider.hasPendingSnapshot)
        XCTAssertFalse(provider.hasPendingFolderSnapshot)
        XCTAssertEqual(provider.presentationEntries.count, 2, "folder + Gamma")
    }

    /// folder latest-wins：连续 receiveFolderSnapshot 只保留最新。
    func testFolderLatestWins() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma", "Delta"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        let f1 = makeFolder(id: FolderID(uuid: UUID()), title: "G1",
                            members: [makeAppID("fixture.alpha"), makeAppID("fixture.beta")])
        let f2 = makeFolder(id: FolderID(uuid: UUID()), title: "G2",
                            members: [makeAppID("fixture.gamma"), makeAppID("fixture.delta")])
        provider.receiveFolderSnapshot(makeFolders(generation: 1, entries: [f1]))
        provider.receiveFolderSnapshot(makeFolders(generation: 2, entries: [f2]))

        XCTAssertEqual(provider.pendingFolderSnapshot?.generation, FolderGeneration(2), "latest-wins")
        let update = provider.applyPending(atCurrentPage: 0)
        XCTAssertNotNil(update)
        XCTAssertEqual(provider.servedFolderSnapshot?.entries.count, 1, "只提交最新 folder")
        XCTAssertEqual(provider.servedFolderSnapshot?.entries.first?.title, "G2")
    }

    /// 无 pending（catalog 与 folder 均无）→ applyPending 无操作。
    func testApplyPendingNoOpWithoutAnyPending() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        XCTAssertNil(provider.applyPending(atCurrentPage: 0))
    }

    // MARK: - 刷新不重复 / 不遗漏 / 不伪造 CatalogRevision

    /// no-repeat：同 revision 连续 stage 只保留最新，applyPending 只提交一次。
    func testRefreshNoRepeat() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        provider.receive(try makeSnapshot(titles: ["Alpha"], revision: 2))
        provider.receive(try makeSnapshot(titles: ["Alpha"], revision: 2))
        XCTAssertEqual(provider.pendingRevision, 2)
        let update = provider.applyPending(atCurrentPage: 0)
        XCTAssertNotNil(update)
        XCTAssertEqual(provider.servedRevision, 2)
        XCTAssertNil(provider.pendingSnapshot, "提交一次，不重复")
    }

    /// no-miss：较新 revision 不被旧 revision 覆盖（latest-wins 保留最新）。
    func testRefreshNoMiss() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        provider.receive(try makeSnapshot(titles: ["Alpha"], revision: 2))
        provider.receive(try makeSnapshot(titles: ["Alpha", "Beta"], revision: 3))
        XCTAssertEqual(provider.pendingRevision, 3, "最新 revision 不被旧覆盖")
        let update = provider.applyPending(atCurrentPage: 0)
        XCTAssertEqual(provider.servedRevision, 3)
        XCTAssertEqual(provider.presentationEntries.count, 2)
    }

    /// no-forge：servedRevision 恒来自 catalog snapshot，provider 绝不 mint/forge CatalogRevision。
    func testRefreshNoForge() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        provider.receive(try makeSnapshot(titles: ["Alpha", "Beta"], revision: 7))
        let update = provider.applyPending(atCurrentPage: 0)
        XCTAssertNotNil(update)
        XCTAssertEqual(provider.servedRevision, 7)
        XCTAssertEqual(provider.servedSnapshot?.revision.value, 7, "revision 来自 catalog，绝不伪造")
        XCTAssertEqual(update?.newRevision, 7)
    }

    /// folder generation 独立于 CatalogRevision（folder 层绝不 mint/forge CatalogRevision）。
    func testFolderGenerationIndependentOfCatalogRevision() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        let folder = makeFolder(id: FolderID(uuid: UUID()), title: "G1",
                                members: [makeAppID("fixture.alpha"), makeAppID("fixture.beta")])
        provider.receiveFolderSnapshot(makeFolders(generation: 5, entries: [folder]))
        let update = provider.applyPending(atCurrentPage: 0)
        XCTAssertNotNil(update)
        XCTAssertEqual(provider.servedRevision, 1, "catalog revision 不因 folder 变化")
        XCTAssertEqual(provider.servedFolderSnapshot?.generation, FolderGeneration(1),
                       "folder generation 独立单调 token")
    }

    // MARK: - 单成员解散 / 刷新成员收缩（ADR-008 §2.4）

    /// 单成员 folder 解散为顶层 app 条目。
    func testSingleMemberFolderDissolves() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta"], revision: 1)
        let folder = makeFolder(id: FolderID(uuid: UUID()), title: "G1",
                                members: [makeAppID("fixture.alpha")])
        let provider = AppGridUIPageContentProvider(snapshot: snapshot,
                                                   folderSnapshot: makeFolders(generation: 1, entries: [folder]))
        XCTAssertEqual(provider.presentationEntries.count, 2, "单成员解散 → 两个 app 条目")
        XCTAssertEqual(provider.presentationEntries[0].identity, .app(makeAppID("fixture.alpha")))
        XCTAssertEqual(provider.presentationEntries[1].identity, .app(makeAppID("fixture.beta")))
    }

    /// 刷新：已删 app 从成员移除；单成员 folder 解散；空 folder 移除。
    func testRefreshRemovesDeletedMembersAndDissolves() throws {
        let snapshot1 = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let folderID = FolderID(uuid: UUID())
        let folder = makeFolder(id: folderID, title: "G1",
                                members: [makeAppID("fixture.alpha"), makeAppID("fixture.beta")])
        let provider = AppGridUIPageContentProvider(snapshot: snapshot1,
                                                   folderSnapshot: makeFolders(generation: 1, entries: [folder]))
        XCTAssertEqual(provider.presentationEntries.count, 2, "folder + Gamma")

        // 刷新：Beta 删除 → folder 变单成员 → 解散；Gamma 保留
        let snapshot2 = try makeSnapshot(titles: ["Alpha", "Gamma"], revision: 2)
        provider.receive(snapshot2)
        let update = provider.applyPending(atCurrentPage: 0)
        XCTAssertNotNil(update)
        XCTAssertEqual(provider.servedRevision, 2)
        XCTAssertEqual(provider.presentationEntries.count, 2, "解散后 Alpha + Gamma 为 app 条目")
        XCTAssertEqual(provider.presentationEntries[0].identity, .app(makeAppID("fixture.alpha")))
        XCTAssertEqual(provider.presentationEntries[1].identity, .app(makeAppID("fixture.gamma")))
        XCTAssertEqual(provider.servedFolderSnapshot?.entries.count, 0, "单成员 folder 从 snapshot 移除")
    }

    // MARK: - 混合组合 remap（folder anchor 定位）

    /// folder anchor 在刷新后仍存在 → .located。
    func testRemapLocatedForFolderAnchor() throws {
        let snapshot1 = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let folderID = FolderID(uuid: UUID())
        let folder = makeFolder(id: folderID, title: "G1",
                                members: [makeAppID("fixture.alpha"), makeAppID("fixture.beta")])
        let provider = AppGridUIPageContentProvider(snapshot: snapshot1,
                                                   folderSnapshot: makeFolders(generation: 1, entries: [folder]))
        let anchor = provider.topLevelAnchorCandidate(nearPage: 0)
        XCTAssertEqual(anchor, .folder(folderID))

        let snapshot2 = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma", "Delta"], revision: 2)
        provider.receive(snapshot2)
        let update = provider.applyPending(atCurrentPage: 0)
        XCTAssertEqual(update?.outcome, .located(pageIndex: 0))
        XCTAssertEqual(update?.topLevelAnchor, .folder(folderID))
    }
}
