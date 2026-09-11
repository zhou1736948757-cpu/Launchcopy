// AppGridUITests — LayoutDomainMutationTests（Phase 1F §10.1 自动化验证矩阵，mutation 域）
// 实现：T-1F-A（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
// 隐私：全部 fixture 用中性类别标题（Alpha/Beta/... 派生 "fixture.…" 合成 bundleID），
// 无真实 app 名/bundle ID/路径；测试体不含任何真实身份原值。
//
// 覆盖 §10.1：deterministic default；顶层 reorder 前/后/首/尾；app/folder 互换；
// create folder 目标/源顺序；add to folder；cross-folder atomic move；inner reorder；
// move out；zero/one member dissolve（逻辑=永久 vs 投影=latent 保留）；duplicate/nested/
// stale reject；no-op 不增 generation；invalid target 不改原布局；generation 分离。

import AppCatalogCore
import Foundation
import XCTest
@testable import AppGridUI

final class LayoutDomainMutationTests: XCTestCase {

    // MARK: - 夹具（中性）

    /// 产出的 snapshot（CatalogBuilder 排序后）+ 对应 default layout（顺序以产出序为准，
    /// 不假设输入序——locale 排序由 CatalogBuilder 决定）。
    private func makeFixture(_ titles: [String], revision: UInt64 = 1)
        throws -> (CatalogSnapshot, PersistentWorkspaceLayout) {
        let snapshot = try makeSnapshot(titles: titles, revision: revision)
        return (snapshot, PersistentWorkspaceLayout.makeDefault(catalog: snapshot))
    }

    private func refs(_ snapshot: CatalogSnapshot) -> [PersistentAppReference] {
        snapshot.records.map { PersistentAppReference.from(record: $0) }
    }

    private func entryRefs(_ layout: PersistentWorkspaceLayout) -> [PersistentAppReference] {
        layout.topLevelOrder.compactMap { entry in
            if case .app(let ref) = entry { return ref }
            return nil
        }
    }

    private func ref(_ snapshot: CatalogSnapshot, titled title: String) -> PersistentAppReference? {
        snapshot.records.first { $0.displayName == title }
            .map { PersistentAppReference.from(record: $0) }
    }

    private func assertNoIssues(_ layout: PersistentWorkspaceLayout,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(WorkspaceLayoutValidator.validate(layout), [], file: file, line: line)
    }

    // MARK: - deterministic default layout

    func testDeterministicDefaultLayoutMatchesCatalogOrderTwice() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma", "Delta"])
        let again = PersistentWorkspaceLayout.makeDefault(catalog: snapshot)
        XCTAssertEqual(layout, again)                       // 两次构建相等
        XCTAssertEqual(layout.generation, .zero)
        XCTAssertTrue(layout.folders.isEmpty)
        XCTAssertEqual(entryRefs(layout), refs(snapshot))   // 保持 catalog 产出序
        assertNoIssues(layout)
    }

    func testDefaultLayoutEmptyCatalogIsEmpty() throws {
        let (_, layout) = try makeFixture([])
        XCTAssertEqual(layout, PersistentWorkspaceLayout.empty())
        XCTAssertEqual(layout.generation, .zero)
        assertNoIssues(layout)
    }

    // MARK: - top-level reorder（前/后/首/尾）

    func testReorderToFront() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma", "Delta"])
        let r = refs(snapshot)
        let result = LayoutMutation(expectedGeneration: .zero)
            .reorderTopLevel(in: layout, identity: .app(r[1]), toIndex: 0)
        guard case .success(let newLayout) = result else {
            return XCTFail("expected success, got \(result)")
        }
        XCTAssertEqual(entryRefs(newLayout), [r[1], r[0], r[2], r[3]])
        XCTAssertEqual(newLayout.generation.value, 1)
        assertNoIssues(newLayout)
    }

    func testReorderToBack() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma", "Delta"])
        let r = refs(snapshot)
        let result = LayoutMutation(expectedGeneration: .zero)
            .reorderTopLevel(in: layout, identity: .app(r[0]), toIndex: 3)
        guard case .success(let newLayout) = result else {
            return XCTFail("expected success, got \(result)")
        }
        XCTAssertEqual(entryRefs(newLayout), [r[1], r[2], r[3], r[0]])
        assertNoIssues(newLayout)
    }

    func testReorderAlreadyFirstAndLastAreNoOp() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma"])
        let r = refs(snapshot)
        let engine = LayoutMutation(expectedGeneration: .zero)
        guard case .noOp = engine.reorderTopLevel(in: layout, identity: .app(r[0]), toIndex: 0) else {
            return XCTFail("expected noOp")
        }
        guard case .noOp = engine.reorderTopLevel(in: layout, identity: .app(r[2]), toIndex: 2) else {
            return XCTFail("expected noOp")
        }
        // no-op 不增 generation
        XCTAssertEqual(layout.generation, .zero)
    }

    func testReorderClampsOutOfRange() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma"])
        let r = refs(snapshot)
        let engine = LayoutMutation(expectedGeneration: .zero)
        guard case .success(let front) = engine.reorderTopLevel(in: layout, identity: .app(r[2]), toIndex: -50) else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(entryRefs(front), [r[2], r[0], r[1]])
        guard case .success(let back) = engine.reorderTopLevel(in: layout, identity: .app(r[0]), toIndex: 99) else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(entryRefs(back), [r[1], r[2], r[0]])
        assertNoIssues(front)
        assertNoIssues(back)
    }

    // MARK: - app/folder 互换（交错条目统一重排）

    func testReorderMovesFolderAndAppsInterleaved() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma", "Delta"])
        let r = refs(snapshot)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
        var current = layout
        var engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let withFolder) = engine.createFolder(
            in: current, target: r[0], source: r[1], folderID: folderID) else {
            return XCTFail("create failed")
        }
        current = withFolder
        engine = LayoutMutation(expectedGeneration: current.generation)
        // [F, Gamma, Delta] → 把 Gamma 移到最前：[Gamma, F, Delta]
        guard case .success(let reordered) = engine.reorderTopLevel(
            in: current, identity: .app(r[2]), toIndex: 0) else {
            return XCTFail("reorder failed")
        }
        XCTAssertEqual(reordered.topLevelOrder.count, 3)
        XCTAssertEqual(reordered.topLevelOrder[0], .app(r[2]))
        XCTAssertEqual(reordered.topLevelOrder[1], .folder(folderID))
        XCTAssertEqual(reordered.topLevelOrder[2], .app(r[3]))
        // 再把 folder 移到末尾：[Gamma, Delta, F] —— folder 与 app 互换成功
        engine = LayoutMutation(expectedGeneration: reordered.generation)
        guard case .success(let swapped) = engine.reorderTopLevel(
            in: reordered, identity: .folder(folderID), toIndex: 2) else {
            return XCTFail("folder reorder failed")
        }
        XCTAssertEqual(swapped.topLevelOrder[2], .folder(folderID))
        XCTAssertEqual(swapped.generation.value, reordered.generation.value + 1)
        assertNoIssues(swapped)
    }

    // MARK: - create folder（目标/源顺序 + 顶层位 + 默认标题）

    func testCreateFolderLandsAtTargetPositionWhenTargetPrecedesSource() throws {
        // BUG6 wave-b 语义：新 folder 落在 drop 目标 target 原位。
        // 本夹具 target(B, idx 1) 在 source(C, idx 2) 前 → 落点 = targetIndex = 1：
        // [Alpha, F, Delta]（target 比 source 更小下标时与旧 min 语义同值，为同值回归锁）。
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma", "Delta"])
        let r = refs(snapshot)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!)
        let result = LayoutMutation(expectedGeneration: .zero).createFolder(
            in: layout, target: r[1], source: r[2], folderID: folderID)
        guard case .success(let newLayout) = result else {
            return XCTFail("expected success, got \(result)")
        }
        XCTAssertEqual(newLayout.folders.count, 1)
        let folder = newLayout.folders[0]
        XCTAssertEqual(folder.id, folderID)
        XCTAssertEqual(folder.members, [r[1], r[2]])        // 先目标后源
        XCTAssertEqual(folder.title, "Group 1")             // 中性默认标题
        // 顶层位 = drop 目标 target 原位（B 原下标 1，target 在 source 左）：
        // [Alpha, F, Delta]
        XCTAssertEqual(newLayout.topLevelOrder, [.app(r[0]), .folder(folderID), .app(r[3])])
        XCTAssertEqual(newLayout.generation.value, 1)
        assertNoIssues(newLayout)
    }

    func testCreateFolderReversedOperandsReversesMembers() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma", "Delta"])
        let r = refs(snapshot)
        let result = LayoutMutation(expectedGeneration: .zero).createFolder(
            in: layout, target: r[2], source: r[1])
        guard case .success(let newLayout) = result else {
            return XCTFail("expected success, got \(result)")
        }
        XCTAssertEqual(newLayout.folders[0].members, [r[2], r[1]])   // 目标在前（语义随操作数）
        assertNoIssues(newLayout)
    }

    func testCreateFolderSequentialDefaultTitles() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma", "Delta"])
        let r = refs(snapshot)
        var current = layout
        var engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let first) = engine.createFolder(in: current, target: r[0], source: r[1]) else {
            return XCTFail("create failed")
        }
        XCTAssertEqual(first.folders[0].title, "Group 1")
        current = first
        engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let second) = engine.createFolder(in: current, target: r[2], source: r[3]) else {
            return XCTFail("create failed")
        }
        XCTAssertEqual(second.folders.map(\.title), ["Group 1", "Group 2"])
        assertNoIssues(second)
    }

    func testCreateFolderCustomTitleNormalizedAndWhitespaceFallback() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta"])
        let r = refs(snapshot)
        let engine = LayoutMutation(expectedGeneration: .zero)
        guard case .success(let custom) = engine.createFolder(
            in: layout, target: r[0], source: r[1], title: "  Productivity  ") else {
            return XCTFail("create failed")
        }
        XCTAssertEqual(custom.folders[0].title, "Productivity")      // trim
        let fallback = engine.createFolder(in: layout, target: r[0], source: r[1], title: "   ")
        guard case .success(let blankTitle) = fallback else {
            return XCTFail("create failed")
        }
        XCTAssertEqual(blankTitle.folders[0].title, "Group 1")       // 空白 → 中性默认回退
        assertNoIssues(custom)
        assertNoIssues(blankTitle)
    }

    // MARK: - add to folder（移入 / 已是成员 no-op）

    func testAddToFolderMovesTopLevelApp() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma", "Delta"])
        let r = refs(snapshot)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!)
        var current = layout
        var engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let withFolder) = engine.createFolder(in: current, target: r[1], source: r[2], folderID: folderID) else {
            return XCTFail("create failed")
        }
        current = withFolder
        engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let added) = engine.addToFolder(in: current, app: r[0], folderID: folderID, at: .tail) else {
            return XCTFail("add failed")
        }
        XCTAssertEqual(added.folders[0].members, [r[1], r[2], r[0]])  // tail 追加
        XCTAssertEqual(entryRefs(added), [r[3]])                      // 顶层仅剩 Delta
        XCTAssertEqual(added.generation.value, withFolder.generation.value + 1)
        assertNoIssues(added)
    }

    func testAddToFolderHeadPosition() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma"])
        let r = refs(snapshot)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A4")!)
        var current = layout
        var engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let f) = engine.createFolder(in: current, target: r[0], source: r[1], folderID: folderID) else {
            return XCTFail("create failed")
        }
        current = f
        engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let added) = engine.addToFolder(in: current, app: r[2], folderID: folderID, at: .head) else {
            return XCTFail("add failed")
        }
        XCTAssertEqual(added.folders[0].members, [r[2], r[0], r[1]])
        assertNoIssues(added)
    }

    func testAddToFolderAlreadyMemberIsNoOp() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma"])
        let r = refs(snapshot)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A5")!)
        var current = layout
        var engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let f) = engine.createFolder(in: current, target: r[0], source: r[1], folderID: folderID) else {
            return XCTFail("create failed")
        }
        current = f
        engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .noOp = engine.addToFolder(in: current, app: r[1], folderID: folderID) else {
            return XCTFail("expected noOp")
        }
        XCTAssertEqual(current.generation.value, 1)   // 不增 generation
        XCTAssertEqual(current, f)                    // 布局不变
        assertNoIssues(current)
    }

    // MARK: - cross-folder atomic move（含源 folder dissolve 单次提交）

    func testCrossFolderMoveWithSourceDissolveIsSingleAtomicCommit() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma", "Delta"])
        let r = refs(snapshot)
        let f1 = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!)
        let f2 = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!)
        var current = layout
        var engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let step1) = engine.createFolder(in: current, target: r[0], source: r[1], folderID: f1) else { return XCTFail() }
        current = step1
        engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let step2) = engine.createFolder(in: current, target: r[2], source: r[3], folderID: f2) else { return XCTFail() }
        current = step2   // [F1, F2]；F1=[A,B]，F2=[Gamma,Delta]
        engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let moved) = engine.addToFolder(in: current, app: r[0], folderID: f2, at: .tail) else {
            return XCTFail("cross move failed")
        }
        // 源 F1 剩 [B] → 逻辑 dissolve：B 回 F1 原顶层位；F2 追加 A；全部一次提交（gen 只 +1）
        XCTAssertEqual(moved.folders.count, 1)
        XCTAssertEqual(moved.folders[0].id, f2)
        XCTAssertEqual(moved.folders[0].members, [r[2], r[3], r[0]])
        XCTAssertEqual(moved.topLevelOrder, [.app(r[1]), .folder(f2)])
        XCTAssertEqual(moved.generation.value, step2.generation.value + 1)
        assertNoIssues(moved)
    }

    func testCrossFolderMoveWithoutDissolveKeepsSource() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma", "Delta", "Epsilon"])
        let r = refs(snapshot)
        let f1 = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000B3")!)
        let f2 = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000B4")!)
        var current = layout
        var engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let s1) = engine.createFolder(in: current, target: r[0], source: r[1], folderID: f1) else { return XCTFail() }
        current = s1
        engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let s2) = engine.addToFolder(in: current, app: r[2], folderID: f1) else { return XCTFail() }   // F1=[A,B,C]
        current = s2
        engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let s3) = engine.createFolder(in: current, target: r[3], source: r[4], folderID: f2) else { return XCTFail() }
        current = s3
        engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let moved) = engine.addToFolder(in: current, app: r[0], folderID: f2, at: .tail) else {
            return XCTFail("cross move failed")
        }
        XCTAssertEqual(moved.folders.first { $0.id == f1 }?.members, [r[1], r[2]])  // 源保留（剩 2）
        XCTAssertEqual(moved.folders.first { $0.id == f2 }?.members, [r[3], r[4], r[0]])
        XCTAssertEqual(moved.generation.value, s3.generation.value + 1)
        assertNoIssues(moved)
    }

    // MARK: - folder inner reorder

    func testReorderFolderMembers() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma", "Delta"])
        let r = refs(snapshot)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!)
        var current = layout
        var engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let f) = engine.createFolder(in: current, target: r[0], source: r[1], folderID: folderID) else { return XCTFail() }
        current = f
        engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let add) = engine.addToFolder(in: current, app: r[2], folderID: folderID) else { return XCTFail() }
        current = add   // F=[A,B,C]
        engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let reordered) = engine.reorderFolderMembers(in: current, folderID: folderID, member: r[2], toIndex: 0) else {
            return XCTFail("inner reorder failed")
        }
        XCTAssertEqual(reordered.folders[0].members, [r[2], r[0], r[1]])
        XCTAssertEqual(reordered.generation.value, add.generation.value + 1)
        assertNoIssues(reordered)
    }

    func testReorderFolderMembersSameIndexIsNoOp() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma"])
        let r = refs(snapshot)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000C2")!)
        var current = layout
        var engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let f) = engine.createFolder(in: current, target: r[0], source: r[1], folderID: folderID) else { return XCTFail() }
        current = f
        engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .noOp = engine.reorderFolderMembers(in: current, folderID: folderID, member: r[0], toIndex: 0) else {
            return XCTFail("expected noOp")
        }
        XCTAssertEqual(current.generation.value, 1)
        assertNoIssues(current)
    }

    // MARK: - move out（确定顶层位 / zero / one member dissolve）

    func testMoveOutKeepsFolderPlacement() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma", "Delta"])
        let r = refs(snapshot)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!)
        var current = layout
        var engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let f) = engine.createFolder(in: current, target: r[0], source: r[1], folderID: folderID) else { return XCTFail() }
        current = f
        engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let add) = engine.addToFolder(in: current, app: r[2], folderID: folderID) else { return XCTFail() }
        current = add   // [F, Delta]，F=[A,B,C]
        engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let moved) = engine.moveOutOfFolder(in: current, folderID: folderID, member: r[0], toIndex: 1) else {
            return XCTFail("move out failed")
        }
        XCTAssertEqual(moved.folders[0].members, [r[1], r[2]])
        XCTAssertEqual(moved.topLevelOrder, [.folder(folderID), .app(r[0]), .app(r[3])])
        assertNoIssues(moved)
    }

    func testMoveOutOnlyMemberDeletesFolder() throws {
        // 手构 1 逻辑成员 folder（测试夹具；mutation 是唯一生产写入口，校验器会在其外拦截）。
        // 夹具必须满足结构性不变量前提：成员只在 folder 内，不在顶层。
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000D2")!)
        let aRef = PersistentAppReference.bundleID("fixture.alpha")
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.folder(folderID)],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1", members: [aRef])])
        let result = LayoutMutation(expectedGeneration: .zero).moveOutOfFolder(
            in: layout, folderID: folderID, member: aRef, toIndex: 1)
        guard case .success(let newLayout) = result else {
            return XCTFail("expected success, got \(result)")
        }
        XCTAssertTrue(newLayout.folders.isEmpty)          // 零成员 → folder 删除（永久）
        XCTAssertEqual(newLayout.topLevelOrder, [.app(aRef)])
        XCTAssertEqual(newLayout.generation.value, 1)
        assertNoIssues(newLayout)                          // 提交后必满足不变量
    }

    func testMoveOutLeavingOneMemberLogicalDissolveIsPermanent() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma", "Delta"])
        let r = refs(snapshot)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000D3")!)
        var current = layout
        var engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let f) = engine.createFolder(in: current, target: r[0], source: r[1], folderID: folderID) else { return XCTFail() }
        current = f   // F=[A,B] at index 0
        engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let dissolved) = engine.moveOutOfFolder(
            in: current, folderID: folderID, member: r[0], toIndex: 2) else {
            return XCTFail("move out failed")
        }
        // 剩 [B] → 逻辑 dissolve：folder 记录删除；B 回 folder 原顶层位（index 0）；A 插 toIndex 2
        XCTAssertTrue(dissolved.folders.isEmpty)
        XCTAssertEqual(dissolved.topLevelOrder, [.app(r[1]), .app(r[2]), .app(r[0]), .app(r[3])])
        XCTAssertEqual(dissolved.generation.value, current.generation.value + 1)   // 单次提交 +1
        assertNoIssues(dissolved)
        // 永久性：从已提交布局重投影（模拟重启）——无 folder 呈现
        let projection = VisibleWorkspaceProjection.project(layout: dissolved, catalog: snapshot)
        XCTAssertEqual(projection.topLevel.count, 4)
        XCTAssertFalse(projection.containsVisible(identity: .folder(folderID)))
        XCTAssertEqual(projection.latentAppReferences.count, 0)
    }

    // MARK: - 视觉 dissolve（投影层；latent 保留 + 重现恢复；layout 不动）

    func testVisualDissolveKeepsLatentFolderUntilReappearance() throws {
        let full = try makeSnapshot(titles: ["Alpha", "Beta"], revision: 1)
        let r = refs(full)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000E1")!)
        guard case .success(let withFolder) = LayoutMutation(expectedGeneration: .zero).createFolder(
            in: PersistentWorkspaceLayout.makeDefault(catalog: full),
            target: r[0], source: r[1], folderID: folderID) else { return XCTFail() }
        XCTAssertEqual(withFolder.folders[0].members.count, 2)

        // catalog 缺 Beta（暂缺）→ 视觉 dissolve：folder 呈现为 app；latent 保留 B；layout 不动
        let partial = try makeSnapshot(titles: ["Alpha"], revision: 1)
        let projection = VisibleWorkspaceProjection.project(layout: withFolder, catalog: partial)
        XCTAssertEqual(projection.topLevel.count, 1)
        if case .app(let record) = projection.topLevel[0] {
            XCTAssertEqual(record.displayName, "Alpha")
        } else {
            XCTFail("visual dissolve should present the available app")
        }
        XCTAssertEqual(projection.latentAppReferences, [r[1]])
        XCTAssertFalse(projection.containsVisible(identity: .folder(folderID)))

        // 重现 → folder 呈现恢复；latent 清空；layout 仍是同一已提交值（未被投影改动）
        let restored = VisibleWorkspaceProjection.project(layout: withFolder, catalog: full)
        XCTAssertEqual(restored.topLevel.count, 1)
        if case .folder(let visible) = restored.topLevel[0] {
            XCTAssertEqual(visible.id, folderID)
            XCTAssertEqual(visible.availableMembers.map(\.id), full.records.map(\.id))
        } else {
            XCTFail("folder should reappear")
        }
        XCTAssertTrue(restored.latentAppReferences.isEmpty)
        XCTAssertEqual(withFolder, withFolder)   // 布局本身从未改变（值语义）
    }

    // MARK: - 暂缺 app：隐藏但 latent 保留，重现回原逻辑位

    func testLatentAppHiddenThenReappearsAtLogicalPosition() throws {
        let full = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let layout = PersistentWorkspaceLayout.makeDefault(catalog: full)
        let sansBeta = try makeSnapshot(titles: ["Alpha", "Gamma"], revision: 1)
        let hidden = VisibleWorkspaceProjection.project(layout: layout, catalog: sansBeta)
        XCTAssertEqual(hidden.topLevel.count, 2)
        XCTAssertEqual(hidden.latentAppReferences, [PersistentAppReference.from(record: full.records[1])])

        let again = VisibleWorkspaceProjection.project(layout: layout, catalog: full)
        XCTAssertEqual(again.topLevel.count, 3)
        XCTAssertTrue(again.latentAppReferences.isEmpty)
        // 暂缺→重现 与 从未暂缺 的投影一致（逻辑位置恢复）
        XCTAssertEqual(again, VisibleWorkspaceProjection.project(layout: layout, catalog: full))
    }

    // MARK: - 新 app 确定性追加（投影不反向写 layout）

    func testNewAppDeterministicallyAppended() throws {
        let old = try makeSnapshot(titles: ["Alpha", "Beta"], revision: 1)
        let layout = PersistentWorkspaceLayout.makeDefault(catalog: old)
        let neu = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 2)
        let projection = VisibleWorkspaceProjection.project(layout: layout, catalog: neu)
        XCTAssertEqual(projection.topLevel.count, 3)
        if case .app(let last) = projection.topLevel[2] {
            XCTAssertEqual(last.displayName, "Gamma")
        } else {
            XCTFail("new app should append as visible app")
        }
        XCTAssertEqual(projection.unorchestratedAppRecords.map(\.displayName), ["Gamma"])
        XCTAssertEqual(layout.topLevelOrder.count, 2)   // layout 未被反向修改
        assertNoIssues(layout)
    }

    // MARK: - rejections（stale / duplicate / nested / invalid；失败无半提交）

    func testCreateFolderDuplicateReferenceRejected() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta"])
        let r = refs(snapshot)
        let result = LayoutMutation(expectedGeneration: .zero).createFolder(in: layout, target: r[0], source: r[0])
        guard case .rejected(let reason) = result else { return XCTFail("expected rejection") }
        XCTAssertEqual(reason, .duplicateReference)
        XCTAssertEqual(layout, PersistentWorkspaceLayout.makeDefault(catalog: snapshot))  // 原布局不变
        XCTAssertEqual(layout.generation, .zero)
    }

    func testCreateFolderNestedSourceRejected() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma"])
        let r = refs(snapshot)
        var current = layout
        var engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let f) = engine.createFolder(in: current, target: r[0], source: r[1]) else { return XCTFail() }
        current = f
        engine = LayoutMutation(expectedGeneration: current.generation)
        let result = engine.createFolder(in: current, target: r[2], source: r[0])   // 源已在 folder
        guard case .rejected(let reason) = result else { return XCTFail("expected rejection") }
        XCTAssertEqual(reason, .nestedFolder)
        XCTAssertEqual(current, f)    // 不变
        assertNoIssues(current)
    }

    func testStaleGenerationRejectedWithoutMutation() throws {
        let (_, layout) = try makeFixture(["Alpha", "Beta", "Gamma"])
        var current = layout
        let engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .app(let targetRef) = current.topLevelOrder[0],
              case .app(let sourceRef) = current.topLevelOrder[1],
              case .success(let f) = engine.createFolder(in: current, target: targetRef, source: sourceRef) else { return XCTFail() }
        current = f
        let stale = LayoutMutation(expectedGeneration: .zero)   // 已过期的 expectedGeneration
        let result = stale.reorderTopLevel(in: current, identity: .folder(current.folders[0].id), toIndex: 2)
        guard case .rejected(let reason) = result else { return XCTFail("expected stale rejection") }
        XCTAssertEqual(reason, .staleGeneration(expected: .zero, current: current.generation))
        XCTAssertEqual(current, f)    // 无半提交
        XCTAssertEqual(current.generation.value, 1)
        assertNoIssues(current)
    }

    func testInvalidTargetsLeaveLayoutUntouched() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta", "Gamma"])
        let r = refs(snapshot)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000F1")!)
        var current = layout
        var engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let f) = engine.createFolder(in: current, target: r[0], source: r[1], folderID: folderID) else { return XCTFail() }
        current = f
        engine = LayoutMutation(expectedGeneration: current.generation)
        let unknown = PersistentAppReference.bundleID("fixture.unknown")

        if case .rejected(let reason) = engine.addToFolder(in: current, app: unknown, folderID: folderID) {
            XCTAssertEqual(reason, .invalidTarget)
        } else { XCTFail("expected invalidTarget") }

        if case .rejected(let reason) = engine.reorderTopLevel(in: current, identity: .app(unknown), toIndex: 0) {
            XCTAssertEqual(reason, .topLevelEntryNotFound(.app(unknown)))
        } else { XCTFail("expected topLevelEntryNotFound") }

        if case .rejected(let reason) = engine.moveOutOfFolder(in: current, folderID: folderID, member: unknown, toIndex: 0) {
            XCTAssertEqual(reason, .memberNotFound(unknown))
        } else { XCTFail("expected memberNotFound") }

        if case .rejected(let reason) = engine.createFolder(in: current, target: unknown, source: r[2]) {
            XCTAssertEqual(reason, .invalidTarget)
        } else { XCTFail("expected invalidTarget") }

        let missingFolder = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-00000000FFFF")!)
        if case .rejected(let reason) = engine.addToFolder(in: current, app: r[2], folderID: missingFolder) {
            XCTAssertEqual(reason, .folderDoesNotExist(missingFolder))
        } else { XCTFail("expected folderDoesNotExist") }

        XCTAssertEqual(current, f)    // 全部拒绝后布局原值不变
        assertNoIssues(current)
    }

    // MARK: - renameFolder（真 mutation；64-grapheme；重启恢复）

    func testRenameNormalizesTo64Graphemes() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta"])
        let r = refs(snapshot)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000D4")!)
        var current = layout
        var engine = LayoutMutation(expectedGeneration: current.generation)
        guard case .success(let f) = engine.createFolder(in: current, target: r[0], source: r[1], folderID: folderID) else { return XCTFail() }
        current = f
        engine = LayoutMutation(expectedGeneration: current.generation)
        let longTitle = String(repeating: "N", count: 70)
        guard case .success(let renamed) = engine.renameFolder(in: current, folderID: folderID, to: longTitle) else {
            return XCTFail("rename failed")
        }
        XCTAssertEqual(renamed.folders[0].title.count, 64)                    // 64-grapheme 截断
        XCTAssertEqual(renamed.folders[0].title, String(repeating: "N", count: 64))
        XCTAssertEqual(renamed.generation.value, current.generation.value + 1)
        // 重启恢复：从已提交布局重投影 → 新标题（持久语义）
        let projection = VisibleWorkspaceProjection.project(layout: renamed, catalog: snapshot)
        if case .folder(let visible) = projection.topLevel[0] {
            XCTAssertEqual(visible.title, String(repeating: "N", count: 64))
        } else { XCTFail("folder should be visible") }
        assertNoIssues(renamed)
    }

    func testRenameGraphemeCountsCharactersNotScalars() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta"])
        let r = refs(snapshot)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000E2")!)
        guard case .success(let f) = LayoutMutation(expectedGeneration: .zero).createFolder(
            in: layout, target: r[0], source: r[1], folderID: folderID) else { return XCTFail() }
        // 组合字形（e + 组合重音）按 1 grapheme 计：重复 70 次组合 → 截断为 64 grapheme
        let combined = String(repeating: "e\u{0301}", count: 70)
        guard case .success(let renamed) = LayoutMutation(expectedGeneration: f.generation)
            .renameFolder(in: f, folderID: folderID, to: combined) else { return XCTFail() }
        XCTAssertEqual(renamed.folders[0].title.count, 64)
        XCTAssertEqual(renamed.folders[0].title, String(repeating: "e\u{0301}", count: 64))
        assertNoIssues(renamed)
    }

    func testRenameWhitespaceFallsBackToOriginalAndSameTitleIsNoOp() throws {
        let (snapshot, layout) = try makeFixture(["Alpha", "Beta"])
        let r = refs(snapshot)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000F2")!)
        guard case .success(let f) = LayoutMutation(expectedGeneration: .zero).createFolder(
            in: layout, target: r[0], source: r[1], title: "Productivity", folderID: folderID) else { return XCTFail() }
        let engine = LayoutMutation(expectedGeneration: f.generation)
        guard case .noOp = engine.renameFolder(in: f, folderID: folderID, to: "   ") else {
            return XCTFail("whitespace rename should fall back and be no-op")
        }
        guard case .noOp = engine.renameFolder(in: f, folderID: folderID, to: "Productivity") else {
            return XCTFail("same title should be no-op")
        }
        XCTAssertEqual(f.generation.value, 1)      // 无真实改名 → 不增 generation
        XCTAssertEqual(f.folders[0].title, "Productivity")
        assertNoIssues(f)
        _ = snapshot
    }

    // MARK: - generation 分离（引擎不接触 catalog；投影 revision 透传）

    func testLayoutGenerationIndependentOfCatalogRevision() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta"], revision: 7)
        let layout = PersistentWorkspaceLayout.makeDefault(catalog: snapshot)
        XCTAssertEqual(layout.generation, .zero)
        guard case .app(let firstRef) = layout.topLevelOrder[0],
              case .app(let secondRef) = layout.topLevelOrder[1],
              case .success(let f) = LayoutMutation(expectedGeneration: .zero).createFolder(
                in: layout, target: firstRef, source: secondRef) else { return XCTFail() }
        XCTAssertEqual(f.generation.value, 1)                      // mutation 只动 layout generation
        let projection = VisibleWorkspaceProjection.project(layout: f, catalog: snapshot)
        XCTAssertEqual(projection.layoutGeneration, f.generation)
        XCTAssertEqual(projection.catalogRevision.value, 7)        // 透传，不伪造
        XCTAssertEqual(f.generation.value, 1)                      // catalog 无反向影响
        assertNoIssues(f)
    }
}
