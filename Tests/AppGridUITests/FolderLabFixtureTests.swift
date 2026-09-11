// AppGridUITests — FolderLabFixtureTests（Phase 1E §3.1B 会话内 folder lab/demo；ADR-008 §2.5）
// 实现：T-1E-A（Worker A）；T-1E 修复（Worker）：末尾 groupSize 个 app 保持未分组。
//
// 覆盖：默认关闭、开启时按稳定 catalog 顺序分组、中性标题 `Group N`、空 catalog、
// 每组全新 FolderID、generation 透传、顶层翻页保留（末尾 groupSize 个 app 未分组）。

import XCTest
@testable import AppGridUI
import AppCatalogCore

final class FolderLabFixtureTests: XCTestCase {

    func testDefaultDisabled() {
        XCTAssertFalse(FolderLabFixture.defaultEnabled)
        XCTAssertEqual(FolderLabFixture.defaultGroupSize, 35)
    }

    func testDisabledReturnsNil() throws {
        let catalog = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let result = FolderLabFixture.makeGroups(from: catalog,
                                                 configuration: .init(enabled: false))
        XCTAssertNil(result)
    }

    func testEnabledGroupsByStableOrder() throws {
        let catalog = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma", "Delta", "Epsilon"], revision: 1)
        let result = FolderLabFixture.makeGroups(from: catalog,
                                                 configuration: .init(groupSize: 2, enabled: true),
                                                 generation: FolderGeneration(7))
        XCTAssertNotNil(result)
        let snapshot = result!
        XCTAssertEqual(snapshot.generation, FolderGeneration(7))
        // 5 apps、groupSize 2 → 前 3 个 app 分组（Group 1 = 2 个，Group 2 = 1 个），
        // 末尾 2 个 app 保持未分组。
        XCTAssertEqual(snapshot.entries.count, 2)

        // 中性标题。
        XCTAssertEqual(snapshot.entries[0].title, "Group 1")
        XCTAssertEqual(snapshot.entries[1].title, "Group 2")

        // 稳定顺序分组（只分组前 max(0, count - groupSize) 个）。
        XCTAssertEqual(snapshot.entries[0].members, [catalog.records[0].id, catalog.records[1].id])
        XCTAssertEqual(snapshot.entries[1].members, [catalog.records[2].id])

        // 末尾 groupSize 个 app 保持未分组（不在任何组内）。
        let grouped = snapshot.entries.flatMap(\.members)
        XCTAssertFalse(grouped.contains(catalog.records[3].id))
        XCTAssertFalse(grouped.contains(catalog.records[4].id))

        // 每组全新 FolderID（不派生自标题/成员）。
        let ids = snapshot.entries.map(\.id)
        XCTAssertEqual(Set(ids).count, 2)
    }

    func testEnabledEmptyCatalogReturnsEmptySnapshot() {
        let catalog = CatalogSnapshot(revision: CatalogRevision(1), records: [])
        let result = FolderLabFixture.makeGroups(from: catalog,
                                                 configuration: .init(groupSize: 2, enabled: true))
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.isEmpty)
    }

    func testInvalidGroupSizeReturnsNil() throws {
        let catalog = try makeSnapshot(titles: ["Alpha"], revision: 1)
        // 非法 groupSize（≤0）→ 防御性返回 nil（不崩溃）。
        let result = FolderLabFixture.makeGroups(from: catalog,
                                                 configuration: .init(groupSize: 0, enabled: true))
        XCTAssertNil(result)
    }

    // MARK: - 顶层翻页保留（T-1E 修复）

    /// 140 apps、groupSize 35 → 3 组（105 个分组）+ 35 个未分组。
    func test140AppsLeavesLastGroupSizeUngrouped() throws {
        let titles = (0..<140).map { "App\($0)" }
        let catalog = try makeSnapshot(titles: titles, revision: 1)
        let result = FolderLabFixture.makeGroups(from: catalog,
                                                 configuration: .init(groupSize: 35, enabled: true))
        XCTAssertNotNil(result)
        let snapshot = result!
        XCTAssertEqual(snapshot.entries.count, 3)
        XCTAssertEqual(snapshot.entries.map(\.title), ["Group 1", "Group 2", "Group 3"])
        // 每组 35 个成员。
        for entry in snapshot.entries {
            XCTAssertEqual(entry.members.count, 35)
        }
        // 前 105 个 app 全部分组；末尾 35 个 app 未分组。
        let grouped = snapshot.entries.flatMap(\.members)
        XCTAssertEqual(grouped.count, 105)
        for index in 0..<105 {
            XCTAssertTrue(grouped.contains(catalog.records[index].id), "index \(index) 应已分组")
        }
        for index in 105..<140 {
            XCTAssertFalse(grouped.contains(catalog.records[index].id), "index \(index) 应未分组")
        }
    }

    /// count == groupSize（35）→ 0 组，全部 35 个未分组。
    func testCountEqualToGroupSizeLeavesAllUngrouped() throws {
        let titles = (0..<35).map { "App\($0)" }
        let catalog = try makeSnapshot(titles: titles, revision: 1)
        let result = FolderLabFixture.makeGroups(from: catalog,
                                                 configuration: .init(groupSize: 35, enabled: true))
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.isEmpty)
    }

    /// count == 2*groupSize（70）→ 1 组 + 35 个未分组。
    func testCountTwiceGroupSizeLeavesOneGroup() throws {
        let titles = (0..<70).map { "App\($0)" }
        let catalog = try makeSnapshot(titles: titles, revision: 1)
        let result = FolderLabFixture.makeGroups(from: catalog,
                                                 configuration: .init(groupSize: 35, enabled: true))
        XCTAssertNotNil(result)
        let snapshot = result!
        XCTAssertEqual(snapshot.entries.count, 1)
        XCTAssertEqual(snapshot.entries[0].title, "Group 1")
        XCTAssertEqual(snapshot.entries[0].members.count, 35)
        // 前 35 个分组；末尾 35 个未分组。
        let grouped = snapshot.entries.flatMap(\.members)
        for index in 0..<35 {
            XCTAssertTrue(grouped.contains(catalog.records[index].id))
        }
        for index in 35..<70 {
            XCTAssertFalse(grouped.contains(catalog.records[index].id))
        }
    }

    /// count < groupSize → 0 组，全部未分组。
    func testCountLessThanGroupSizeLeavesAllUngrouped() throws {
        let titles = (0..<20).map { "App\($0)" }
        let catalog = try makeSnapshot(titles: titles, revision: 1)
        let result = FolderLabFixture.makeGroups(from: catalog,
                                                 configuration: .init(groupSize: 35, enabled: true))
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.isEmpty)
    }
}
