// AppGridUITests — FolderDomainTests（Phase 1E §3.1A 纯文件夹/分组领域模型；ADR-008）
// 实现：T-1E-A（Worker A）。
//
// 覆盖：FolderID / FolderGeneration / FolderTitle / FolderEntryBuilder / FolderSnapshot /
// TopLevelEntryIdentity / TopLevelEntry / ActivationRouter / FolderMembership.rebase /
// TopLevelComposition.build（含单成员解散、空文件夹移除、≥2 成员保留）。

import XCTest
@testable import AppGridUI
import AppCatalogCore

final class FolderDomainTests: XCTestCase {

    // MARK: - FolderID

    func testFolderIDRandomDistinct() {
        let a = FolderID()
        let b = FolderID()
        XCTAssertNotEqual(a, b)
    }

    func testFolderIDDeterministicUUID() {
        let uuid = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let a = FolderID(uuid: uuid)
        let b = FolderID(uuid: uuid)
        XCTAssertEqual(a, b)
    }

    func testFolderIDRedactedDescriptionHasNoRaw() {
        let id = FolderID()
        XCTAssertEqual(id.redactedDescription, "FolderID(<redacted>)")
        XCTAssertFalse(id.redactedDescription.contains("Group"))
    }

    // MARK: - FolderGeneration

    func testFolderGenerationZeroAndIncrement() {
        XCTAssertEqual(FolderGeneration.zero.value, 0)
        XCTAssertEqual(FolderGeneration.zero.incremented().value, 1)
        XCTAssertLessThan(FolderGeneration.zero, FolderGeneration(1))
        XCTAssertEqual(FolderGeneration(5), FolderGeneration(5))
    }

    // MARK: - FolderTitle

    func testFolderTitleTrimsWhitespace() {
        XCTAssertEqual(FolderTitle.normalized("  My Folder  ", fallback: "Group 1"), "My Folder")
    }

    func testFolderTitleBlankFallsBack() {
        XCTAssertEqual(FolderTitle.normalized("   ", fallback: "Group 1"), "Group 1")
        XCTAssertEqual(FolderTitle.normalized("", fallback: "Group 1"), "Group 1")
    }

    func testFolderTitleTruncatesToMaxLength() {
        let long = String(repeating: "a", count: 200)
        let result = FolderTitle.normalized(long, fallback: "Group 1")
        XCTAssertEqual(result.count, FolderTitle.maxLength)
    }

    func testFolderTitleUnicodeSafeTruncation() {
        // 组合字符（grapheme cluster）不得被劈开。
        let long = String(repeating: "e\u{301}", count: 100) // "é" 组合形式
        let result = FolderTitle.normalized(long, fallback: "Group 1")
        XCTAssertEqual(result.count, FolderTitle.maxLength)
        // 每个 grapheme 都是完整的 "é"（e + 组合重音），未被劈开。
        XCTAssertTrue(result.allSatisfy { $0 == "e\u{301}" })
    }

    // MARK: - FolderEntryBuilder

    func testFolderEntryBuilderDedupsPreservingOrder() {
        let a = makeAppID("com.example.a")
        let b = makeAppID("com.example.b")
        let c = makeAppID("com.example.c")
        let entry = FolderEntryBuilder.make(id: FolderID(), title: "Group 1",
                                            members: [a, b, a, c, b])
        XCTAssertEqual(entry.members, [a, b, c])
        XCTAssertEqual(entry.memberCount, 3)
    }

    // MARK: - TopLevelEntry / TopLevelEntryIdentity

    func testTopLevelEntryIdentityMapping() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta"], revision: 1)
        let record = snapshot.records[0]
        let entry = TopLevelEntry.app(record)
        XCTAssertEqual(entry.identity, .app(record.id))

        let folder = FolderEntry(id: FolderID(), title: "Group 1", members: [record.id])
        let folderEntry = TopLevelEntry.folder(folder)
        XCTAssertEqual(folderEntry.identity, .folder(folder.id))
    }

    // MARK: - ActivationRouter

    func testActivationRouterDecidesByEntry() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha"], revision: 1)
        let record = snapshot.records[0]
        let folder = FolderEntry(id: FolderID(), title: "Group 1", members: [record.id])
        XCTAssertEqual(ActivationRouter.decide(for: .app(record)), .launchApp)
        XCTAssertEqual(ActivationRouter.decide(for: .folder(folder)), .openFolder)
    }

    func testActivationRouterDecidesByIdentity() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha"], revision: 1)
        let record = snapshot.records[0]
        let folderID = FolderID()
        XCTAssertEqual(ActivationRouter.decide(for: .app(record.id)), .launchApp)
        XCTAssertEqual(ActivationRouter.decide(for: .folder(folderID)), .openFolder)
        XCTAssertEqual(ActivationRouter.decide(for: nil), .reject)
    }

    // MARK: - FolderMembership.rebase（ADR-008 §2.4）

    func testRebaseRemovesDeletedMembers() throws {
        let catalog = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let a = catalog.records[0].id
        let b = catalog.records[1].id
        let c = catalog.records[2].id
        let gone = makeAppID("com.example.gone")

        let folder1 = FolderEntry(id: FolderID(), title: "Group 1", members: [a, b])
        let folder2 = FolderEntry(id: FolderID(), title: "Group 2", members: [c, gone]) // 收缩后单成员
        let folder3 = FolderEntry(id: FolderID(), title: "Group 3", members: [gone])   // 收缩后空
        let folder4 = FolderEntry(id: FolderID(), title: "Group 4", members: [])       // 空

        let folders = FolderSnapshot(generation: FolderGeneration(1),
                                    entries: [folder1, folder2, folder3, folder4])
        let result = FolderMembership.rebase(folders, against: catalog, generation: FolderGeneration(2))

        // 仅 ≥2 成员文件夹保留。
        XCTAssertEqual(result.snapshot.entries.count, 1)
        XCTAssertEqual(result.snapshot.entries[0].id, folder1.id)
        XCTAssertEqual(result.snapshot.entries[0].members, [a, b])
        // 单成员解散 → 成员成为顶层 app。
        XCTAssertEqual(result.dissolvedAppIDs, [c])
        // 空文件夹 + 解散文件夹被移除。
        XCTAssertEqual(Set(result.removedFolderIDs), Set([folder2.id, folder3.id, folder4.id]))
        // generation 更新。
        XCTAssertEqual(result.snapshot.generation, FolderGeneration(2))
    }

    // MARK: - TopLevelComposition.build（单成员解散 / 空移除 / ≥2 保留）

    func testCompositionDissolvesSingleMemberAndDropsEmpty() throws {
        let catalog = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"], revision: 1)
        let a = catalog.records[0].id
        let b = catalog.records[1].id
        let c = catalog.records[2].id
        let d = catalog.records[3].id
        let e = catalog.records[4].id

        let folder1 = FolderEntry(id: FolderID(), title: "Group 1", members: [a, b]) // ≥2 → folder
        let folder2 = FolderEntry(id: FolderID(), title: "Group 2", members: [c])    // 单成员 → 解散
        let folder3 = FolderEntry(id: FolderID(), title: "Group 3", members: [])    // 空 → 移除

        let folders = FolderSnapshot(generation: FolderGeneration(1),
                                     entries: [folder1, folder2, folder3])
        let result = TopLevelComposition.build(catalog: catalog, folders: folders)

        // 文件夹在前，未分组 app 在后（catalog 稳定顺序）。
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result[0], .folder(folder1))
        XCTAssertEqual(result[1], .app(catalog.records[2])) // C 解散为 app
        XCTAssertEqual(result[2], .app(catalog.records[3])) // D 未分组
        XCTAssertEqual(result[3], .app(catalog.records[4])) // E 未分组
    }

    func testCompositionAllUngroupedWhenNoFolders() throws {
        let catalog = try makeSnapshot(titles: ["Alpha", "Beta"], revision: 1)
        let folders = FolderSnapshot(generation: FolderGeneration.zero, entries: [])
        let result = TopLevelComposition.build(catalog: catalog, folders: folders)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], .app(catalog.records[0]))
        XCTAssertEqual(result[1], .app(catalog.records[1]))
    }
}
