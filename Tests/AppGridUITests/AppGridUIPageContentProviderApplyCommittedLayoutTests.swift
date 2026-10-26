// AppGridUITests — AppGridUIPageContentProviderApplyCommittedLayoutTests（T-1F-D1-fix-e1）
// provider.applyCommittedLayout 单元测试：drag commit 布局 → 呈现面。
// 覆盖：重排后按布局顺序呈现；createFolder → folder cell 含成员；不可解析条目跳过；
// 无 served 快照 → nil；pageCount + currentPage clamp；folder generation 递增；
// 同 catalog revision（布局提交不 mint/forge CatalogRevision）。
// 隐私：仅中性 fixture 数据（fixture.alpha/beta、'Group 1'、固定 UUID）。

import AppCatalogCore
import AppIconPipeline
import PagingUI
@testable import AppGridUI
import XCTest

final class AppGridUIPageContentProviderApplyCommittedLayoutTests: XCTestCase {

    private func ref(_ title: String) -> PersistentAppReference {
        PersistentAppReference.bundleID("fixture.\(title.lowercased())")
    }

    private func makeLayout(topLevel: [WorkspaceTopLevelEntry],
                            folders: [PersistentFolderRecord] = [],
                            generation: UInt64 = 0) -> PersistentWorkspaceLayout {
        PersistentWorkspaceLayout(generation: LayoutGeneration(generation),
                                  topLevelOrder: topLevel, folders: folders)
    }

    // MARK: - 重排：布局顺序即呈现顺序

    /// 用户缺陷 2 主路径：drag 重排两个顶层 app → 网格按新顺序呈现。
    func testReorderReRendersInLayoutOrder() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma", "Delta"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        // catalog 序 = bundle ID 升序：alpha, beta, delta, gamma。
        XCTAssertEqual(provider.presentationEntries.map(\.identity),
                       [.app(makeAppID("fixture.alpha")), .app(makeAppID("fixture.beta")),
                        .app(makeAppID("fixture.delta")), .app(makeAppID("fixture.gamma"))])

        let layout = makeLayout(topLevel: [.app(ref("beta")), .app(ref("alpha")),
                                           .app(ref("gamma")), .app(ref("delta"))])
        let update = provider.applyCommittedLayout(layout, atCurrentPage: 0, itemsPerPage: 35)

        XCTAssertNotNil(update)
        XCTAssertEqual(update?.outcome, .located(pageIndex: 0), "anchor Alpha 重排后仍在页 0")
        XCTAssertEqual(update?.previousRevision, 1)
        XCTAssertEqual(update?.newRevision, 1, "布局提交不 mint/forge CatalogRevision")
        XCTAssertEqual(update?.plan.snapshotRevision.value, 1)
        XCTAssertEqual(update?.plan.itemCount, 4)
        XCTAssertEqual(update?.plan.pageCount, 1)
        XCTAssertEqual(provider.presentationEntries.map(\.identity),
                       [.app(makeAppID("fixture.beta")), .app(makeAppID("fixture.alpha")),
                        .app(makeAppID("fixture.gamma")), .app(makeAppID("fixture.delta"))],
                       "呈现 = 布局顺序（任意交错）")
        XCTAssertEqual(provider.presentationRecords.map(\.id),
                       [makeAppID("fixture.beta"), makeAppID("fixture.alpha"),
                        makeAppID("fixture.gamma"), makeAppID("fixture.delta")],
                       "app-only 投影 = 布局顺序")
        XCTAssertEqual(provider.servedRevision, 1, "served catalog 不变")

        let content = provider.content(for: PagePresentationID(revision: 1, pageIndex: 0), itemsPerPage: 35)
        XCTAssertFalse(content.isPlaceholder)
        XCTAssertEqual(content.items.map(\.title), ["Beta", "Alpha", "Gamma", "Delta"],
                       "content(for:) 服务新顺序 → 网格重渲染")
    }

    // MARK: - createFolder：folder cell 含 A+B

    /// 用户缺陷 2 主路径：drag A 到 B（createFolder）→ folder cell 含 A+B。
    func testCreateFolderShowsFolderCellWithMembers() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)

        let layout = makeLayout(
            topLevel: [.folder(folderID), .app(ref("gamma"))],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1",
                                             members: [ref("alpha"), ref("beta")])])
        let update = provider.applyCommittedLayout(layout, atCurrentPage: 0, itemsPerPage: 35)

        XCTAssertNotNil(update)
        XCTAssertEqual(update?.outcome, .successor(pageIndex: 0),
                       "anchor Alpha 进入 folder → 后继 = 首个 folder 条目所在页")
        XCTAssertEqual(update?.plan.itemCount, 2)
        XCTAssertEqual(update?.plan.pageCount, 1)

        guard case .folder(let folderEntry)? = provider.presentationEntries.first else {
            return XCTFail("期望首个条目为 folder，got \(String(describing: provider.presentationEntries.first))")
        }
        XCTAssertEqual(folderEntry.id, folderID)
        XCTAssertEqual(folderEntry.title, "Group 1")
        XCTAssertEqual(folderEntry.members, [makeAppID("fixture.alpha"), makeAppID("fixture.beta")],
                       "folder cell 含 A+B")

        let folderSnapshot = try XCTUnwrap(provider.servedFolderSnapshot)
        XCTAssertEqual(folderSnapshot.generation, FolderGeneration(1), "folder generation 递增")
        XCTAssertEqual(folderSnapshot.entry(for: folderID)?.members,
                       [makeAppID("fixture.alpha"), makeAppID("fixture.beta")])

        XCTAssertEqual(provider.presentationRecords.map(\.id), [makeAppID("fixture.gamma")],
                       "app-only 投影剔除 folder 条目")

        let content = provider.content(for: PagePresentationID(revision: 1, pageIndex: 0), itemsPerPage: 35)
        XCTAssertEqual(content.items.count, 2)
        XCTAssertEqual(content.items[0].identity as? FolderID, folderID)
        XCTAssertEqual(content.items[0].title, "Group 1")
        XCTAssertEqual(content.items[1].title, "Gamma")
    }

    // MARK: - 不可解析条目跳过

    /// 布局条目在 served catalog 中不可解析 → 跳过（app 引用缺失 / folder 身份缺失 /
    /// folder 成员缺失）。
    func testUnresolvableEntriesSkipped() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        let ghostFolderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!)

        let layout = makeLayout(
            topLevel: [.app(ref("alpha")), .app(ref("missing")), .folder(ghostFolderID), .app(ref("beta"))],
            folders: [PersistentFolderRecord(id: ghostFolderID, title: "Ghost",
                                             members: [ref("missing")])])
        let update = provider.applyCommittedLayout(layout, atCurrentPage: 0, itemsPerPage: 35)

        XCTAssertNotNil(update)
        XCTAssertEqual(provider.presentationEntries.map(\.identity),
                       [.app(makeAppID("fixture.alpha")),
                        .app(makeAppID("fixture.beta"))],
                       "全成员不可用的 folder 只在持久布局保留，不显示空的占位 folder")
        XCTAssertNil(provider.servedFolderSnapshot?.entry(for: ghostFolderID))
        XCTAssertEqual(provider.expectedLayout, layout, "暂缺引用不得从持久真相删除")
        XCTAssertEqual(update?.plan.itemCount, 2)
    }

    // MARK: - 无 served 快照 → nil

    func testNoServedSnapshotReturnsNil() {
        let provider = AppGridUIPageContentProvider()
        let layout = makeLayout(topLevel: [.app(ref("alpha"))])
        XCTAssertNil(provider.applyCommittedLayout(layout, atCurrentPage: 0, itemsPerPage: 35),
                     "无 served 快照 → no-op")
    }

    // MARK: - pageCount + currentPage clamp

    /// 40 条 / 35 每页 → 2 页；currentPage 越界（99）先按旧页数 clamp 到 1 → anchor 仍记录
    /// （App35）→ 重排后 .located（无 clamp 则 anchor nil → .clamped）。
    func testPageCountAndCurrentPageClamp() throws {
        let titles = (0..<40).map { String(format: "App%02d", $0) }
        let snapshot = try makeSnapshot(titles: titles, revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        XCTAssertEqual(provider.servedPageCount, 2)

        let reversed = (0..<40).reversed().map { index in
            WorkspaceTopLevelEntry.app(PersistentAppReference.bundleID("fixture.app\(String(format: "%02d", index))"))
        }
        let update = provider.applyCommittedLayout(makeLayout(topLevel: reversed),
                                                   atCurrentPage: 99, itemsPerPage: 35)

        XCTAssertNotNil(update)
        XCTAssertEqual(update?.outcome, .located(pageIndex: 0),
                       "currentPage 99 → clamp 到旧页 1 → anchor App35 重排后位于页 0")
        XCTAssertEqual(update?.plan.pageCount, 2, "40 条 / 35 每页 = 2 页")
        XCTAssertEqual(update?.plan.itemCount, 40)

        let page1 = provider.content(for: PagePresentationID(revision: 1, pageIndex: 1), itemsPerPage: 35)
        XCTAssertFalse(page1.isPlaceholder)
        XCTAssertEqual(page1.items.map(\.title), ["App04", "App03", "App02", "App01", "App00"],
                       "重排后尾页 = 原序倒序的末 5 条")
    }

    // MARK: - folder generation 跨 commit 递增

    func testFolderGenerationIncrementsAcrossCommits() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let provider = AppGridUIPageContentProvider(snapshot: snapshot)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!)

        let layout1 = makeLayout(
            topLevel: [.folder(folderID), .app(ref("gamma"))],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1",
                                             members: [ref("alpha"), ref("beta")])])
        _ = provider.applyCommittedLayout(layout1, atCurrentPage: 0, itemsPerPage: 35)
        XCTAssertEqual(provider.servedFolderSnapshot?.generation, FolderGeneration(1))

        let layout2 = makeLayout(
            topLevel: [.app(ref("alpha")), .app(ref("beta")), .app(ref("gamma"))],
            generation: 1)
        _ = provider.applyCommittedLayout(layout2, atCurrentPage: 0, itemsPerPage: 35)
        XCTAssertEqual(provider.servedFolderSnapshot?.generation, FolderGeneration(2),
                       "folder generation 每次 commit 递增（即使 folder 集合为空）")
        XCTAssertEqual(provider.servedFolderSnapshot?.entries, [])
        XCTAssertEqual(provider.presentationEntries.map(\.identity),
                       [.app(makeAppID("fixture.alpha")), .app(makeAppID("fixture.beta")),
                        .app(makeAppID("fixture.gamma"))])
    }
}
