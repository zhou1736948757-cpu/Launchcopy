// AppGridUITests — AppGridFocusCompositionTests（T-1E-folder-focus-layout-repair：组合布局/导航器/迁移）
// 实现：Worker A。纯逻辑测试；仅中性标识（AppNN / Group N），无真实 app/folder 名称。

import AppCatalogCore
import PagingUI
@testable import AppGridUI
import XCTest

final class AppGridFocusCompositionTests: XCTestCase {

    // MARK: - 组合 fixture

    /// 3 文件夹（各 2 成员，成员 = App00..App05）+ 32 未分组 app（App06..App37）
    /// → 组合 35 条目（文件夹在前，未分组 app 在后；TopLevelComposition.build 真实路径）。
    private func makeCompositionFixture(revision: UInt64 = 1)
        -> (snapshot: CatalogSnapshot, folders: [FolderEntry], entries: [TopLevelEntry]) {
        let snapshot = try! makeSnapshot(titles: (0..<38).map { "App\(String(format: "%02d", $0))" },
                                        revision: revision)
        let folderIDs = (0..<3).map {
            FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000000\($0)")!)
        }
        let folders = folderIDs.enumerated().map { index, id in
            FolderEntry(id: id, title: "Group \(index)",
                        members: [makeAppID("fixture.app\(String(format: "%02d", index * 2))"),
                                  makeAppID("fixture.app\(String(format: "%02d", index * 2 + 1))")])
        }
        let folderSnapshot = FolderSnapshot(generation: FolderGeneration(1), entries: folders)
        let entries = TopLevelComposition.build(catalog: snapshot, folders: folderSnapshot)
        return (snapshot, folders, entries)
    }

    /// 直接构造组合：7 文件夹 + 28 app → 35 条目（导航器 fixture：row 0 全 folder，row 1 含 folder）。
    private func makeNavigatorFixture(revision: UInt64 = 1)
        -> (snapshot: CatalogSnapshot, folders: [FolderEntry], entries: [TopLevelEntry]) {
        let snapshot = try! makeSnapshot(titles: (0..<28).map { "App\(String(format: "%02d", $0))" },
                                         revision: revision)
        let folders = (0..<7).map { index in
            FolderEntry(id: FolderID(uuid: UUID(uuidString: "10000000-0000-0000-0000-00000000000\(index)")!),
                        title: "Group \(index)", members: [])
        }
        let entries: [TopLevelEntry] = folders.map { .folder($0) } + snapshot.records.map { .app($0) }
        return (snapshot, folders, entries)
    }

    // MARK: - 组合布局：3 folder + 32 app → 35 条目

    func testCompositionLayoutPageAndSlots() throws {
        let (snapshot, _, entries) = makeCompositionFixture()
        XCTAssertEqual(entries.count, 35)
        let layout = AppGridFocusLayout.build(from: snapshot, composition: entries, itemsPerPage: 35)
        XCTAssertEqual(layout.pageCount, 1)
        XCTAssertEqual(layout.validItemCount, 35)
        XCTAssertEqual(layout.validSlots(on: 0), Array(0..<35))
    }

    func testCompositionLayoutFolderSlots() throws {
        let (snapshot, folders, entries) = makeCompositionFixture()
        let layout = AppGridFocusLayout.build(from: snapshot, composition: entries, itemsPerPage: 35)
        for slot in 0..<3 {
            XCTAssertEqual(layout.validEntry(page: 0, slot: slot), .folder(folders[slot].id))
        }
        // folder 槽位 validAppID == nil（不再返回同索引 app id）
        XCTAssertNil(layout.validAppID(page: 0, slot: 0))
        XCTAssertNil(layout.validAppID(page: 0, slot: 2))
    }

    func testCompositionLayoutAppSlots() throws {
        let (snapshot, _, entries) = makeCompositionFixture()
        let layout = AppGridFocusLayout.build(from: snapshot, composition: entries, itemsPerPage: 35)
        // 未分组首 app = App06（前 6 个 app 在文件夹内）
        XCTAssertEqual(layout.validEntry(page: 0, slot: 3), .app(makeAppID("fixture.app06")))
        XCTAssertEqual(layout.validAppID(page: 0, slot: 3), makeAppID("fixture.app06"))
        XCTAssertEqual(layout.validEntry(page: 0, slot: 34), .app(makeAppID("fixture.app37")))
        // 越界/空 slot
        XCTAssertNil(layout.validEntry(page: 0, slot: 35))
        XCTAssertNil(layout.validEntry(page: 1, slot: 0))
        XCTAssertNil(layout.validAppID(page: 0, slot: 35))
    }

    // MARK: - 导航器：folder 身份可移动（守卫不误拦）

    func testNavigatorMovesFromFolderIdentity() throws {
        let (snapshot, folders, entries) = makeNavigatorFixture()
        let layout = AppGridFocusLayout.build(from: snapshot, composition: entries, itemsPerPage: 35)
        let nav = AppGridFocusNavigator(columns: 5)
        let folder0 = AppGridFocusIdentity(catalogRevision: layout.revision, pageIndex: 0, slotIndex: 0,
                                           entryIdentity: .folder(folders[0].id))
        // ↓ → 同列下一行 = slot 5（folder 5）
        let down = nav.move(folder0, direction: .down, in: layout)
        XCTAssertEqual(down?.slotIndex, 5)
        XCTAssertEqual(down?.entryIdentity, .folder(folders[5].id))
        // ↑ 回到 slot 0
        let up = nav.move(down!, direction: .up, in: layout)
        XCTAssertEqual(up, folder0)
        // → slot 1（folder 1）
        let right = nav.move(folder0, direction: .right, in: layout)
        XCTAssertEqual(right?.slotIndex, 1)
        XCTAssertEqual(right?.entryIdentity, .folder(folders[1].id))
        // ← 回到 slot 0
        let left = nav.move(right!, direction: .left, in: layout)
        XCTAssertEqual(left, folder0)
    }

    func testNavigatorAppSlotIdentity() throws {
        let (snapshot, folders, entries) = makeNavigatorFixture()
        let layout = AppGridFocusLayout.build(from: snapshot, composition: entries, itemsPerPage: 35)
        let nav = AppGridFocusNavigator(columns: 5)
        // slot 2（folder 2）↓ → slot 7（row 1 col 2）= 未分组首 app
        let folder2 = AppGridFocusIdentity(catalogRevision: layout.revision, pageIndex: 0, slotIndex: 2,
                                           entryIdentity: .folder(folders[2].id))
        let down = nav.move(folder2, direction: .down, in: layout)
        XCTAssertEqual(down?.slotIndex, 7)
        XCTAssertEqual(down?.entryIdentity, .app(makeAppID("fixture.app00")))
        XCTAssertEqual(down?.appID, makeAppID("fixture.app00"))
    }

    func testStaleFolderIdentityNotNavigated() throws {
        let (snapshot, folders, entries) = makeNavigatorFixture()
        let layout = AppGridFocusLayout.build(from: snapshot, composition: entries, itemsPerPage: 35)
        let nav = AppGridFocusNavigator(columns: 5)
        let stale = AppGridFocusIdentity(catalogRevision: 0, pageIndex: 0, slotIndex: 0,
                                         entryIdentity: .folder(folders[0].id))
        XCTAssertNil(nav.move(stale, direction: .right, in: layout))
    }

    // MARK: - migrate：folder anchor located / clamped；app anchor 组合偏移 located

    func testMigrateFolderAnchorLocated() throws {
        // rev1: [folder0, folder1, folder2, apps]；rev2: folder0 移到 index 1 → located 新位置
        let rev1 = makeCompositionFixture(revision: 1)
        let rev2 = makeCompositionFixture(revision: 2)
        var reordered = rev2.entries
        let folder0 = reordered.remove(at: 0)
        reordered.insert(folder0, at: 1)
        let layout2 = AppGridFocusLayout.build(from: rev2.snapshot, composition: reordered, itemsPerPage: 35)
        let identity = AppGridFocusIdentity(catalogRevision: 1, pageIndex: 0, slotIndex: 0,
                                            entryIdentity: .folder(rev1.folders[0].id))
        let outcome = layout2.migrate(identity: identity)
        guard case .located(let target) = outcome else {
            return XCTFail("应 located，got \(outcome)")
        }
        XCTAssertEqual(target.slotIndex, 1)
        XCTAssertEqual(target.entryIdentity, .folder(rev1.folders[0].id))
        XCTAssertEqual(target.catalogRevision, 2)
    }

    func testMigrateFolderAnchorClamped() throws {
        // rev1: 3 folders；rev2: folder2 消失 → clamped 到首有效（folder0）
        let rev1 = makeCompositionFixture(revision: 1)
        let rev2 = makeCompositionFixture(revision: 2)
        let trimmed = rev2.entries.filter { entry in
            if case .folder(let folder) = entry { return folder.id != rev1.folders[2].id }
            return true
        }
        let layout2 = AppGridFocusLayout.build(from: rev2.snapshot, composition: trimmed, itemsPerPage: 35)
        let identity = AppGridFocusIdentity(catalogRevision: 1, pageIndex: 0, slotIndex: 2,
                                            entryIdentity: .folder(rev1.folders[2].id))
        let outcome = layout2.migrate(identity: identity)
        guard case .clamped(let target) = outcome else {
            return XCTFail("应 clamped，got \(outcome)")
        }
        XCTAssertEqual(target.slotIndex, 0)
        XCTAssertEqual(target.entryIdentity, .folder(rev1.folders[0].id))
        XCTAssertEqual(target.catalogRevision, 2)
    }

    func testMigrateAppAnchorOffsetInComposition() throws {
        // rev1: app-only（无 folder）→ App06 在 slot 6；rev2: 组合 [3 folders, App06, ...] → slot 3
        let appOnly = try! makeSnapshot(titles: (0..<38).map { "App\(String(format: "%02d", $0))" },
                                        revision: 1)
        let identity = AppGridFocusIdentity(catalogRevision: 1, pageIndex: 0, slotIndex: 6,
                                            appID: makeAppID("fixture.app06"))
        let (snapshot2, _, entries2) = makeCompositionFixture(revision: 2)
        let layout2 = AppGridFocusLayout.build(from: snapshot2, composition: entries2, itemsPerPage: 35)
        let outcome = layout2.migrate(identity: identity)
        guard case .located(let target) = outcome else {
            return XCTFail("应 located，got \(outcome)")
        }
        XCTAssertEqual(target.slotIndex, 3)   // 组合中偏移（3 个文件夹在前）
        XCTAssertEqual(target.entryIdentity, .app(makeAppID("fixture.app06")))
        XCTAssertEqual(target.catalogRevision, 2)
    }

    // MARK: - app-only 构建兼容（validEntry/position/contains/firstValidIdentity）

    func testAppOnlyBuildCompat() throws {
        let snapshot = try! makeSnapshot(titles: ["App00", "App01", "App02"], revision: 1)
        let layout = AppGridFocusLayout.build(from: snapshot, itemsPerPage: 35)
        XCTAssertEqual(layout.validEntry(page: 0, slot: 0), .app(makeAppID("fixture.app00")))
        XCTAssertEqual(layout.validAppID(page: 0, slot: 0), makeAppID("fixture.app00"))
        XCTAssertEqual(layout.firstValidIdentity()?.entryIdentity, .app(makeAppID("fixture.app00")))
        XCTAssertEqual(layout.position(of: .app(makeAppID("fixture.app02")))?.slot, 2)
        XCTAssertTrue(layout.contains(.app(makeAppID("fixture.app01"))))
        XCTAssertFalse(layout.contains(.folder(FolderID())))
        XCTAssertNil(layout.position(of: .folder(FolderID())))
    }
}
