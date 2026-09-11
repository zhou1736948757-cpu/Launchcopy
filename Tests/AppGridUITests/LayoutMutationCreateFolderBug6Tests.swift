// AppGridUITests — LayoutMutationCreateFolderBug6Tests（BUG7 wave-a / 缺陷 1：建夹落点重定）
// 实现：T-1F-B7-wave-a（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
// 独立文件：避开 Wave A/C 刚改动的 DragDropTests / DragSessionControllerTests /
// DragUISessionCoordinatorTests，避免 reviewer diff 混淆。
// 覆盖：按格子位置语义的三构型落点（folder 顶替 drop 目标 target 原格；
// BUG7 wave-a：不做 targetIndex-1）+ 成员序锁 [target, source] = [B, A] +
// 拒绝路径不回归（.duplicateReference / .nestedFolder / .invalidTarget /
// .staleGeneration）。
// 隐私：中性夹具（Alpha/Beta/... 派生 "fixture.…" 合成 bundleID；无真实身份原值）。

import AppCatalogCore
import Foundation
import XCTest
@testable import AppGridUI

final class LayoutMutationCreateFolderBug6Tests: XCTestCase {

    // MARK: - 夹具（中性；r[i] = 顶层第 i 项，角色 A/B/C 按位置而非标题）

    private func makeLayoutFixture(_ titles: [String])
        throws -> (CatalogSnapshot, PersistentWorkspaceLayout) {
        let snapshot = try makeSnapshot(titles: titles, revision: 1)
        return (snapshot, PersistentWorkspaceLayout.makeDefault(catalog: snapshot))
    }

    private func refs(_ snapshot: CatalogSnapshot) -> [PersistentAppReference] {
        snapshot.records.map { PersistentAppReference.from(record: $0) }
    }

    private func assertNoIssues(_ layout: PersistentWorkspaceLayout,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(WorkspaceLayoutValidator.validate(layout), [], file: file, line: line)
    }

    // MARK: - 三构型落点（BUG7 wave-a：格子位置语义）

    /// 左方向（相邻）：[A, B, C]，A 拖到 B 上（source=0, target=1）→
    /// folder 顶替 B 原格（index 1）→ [C, F]。
    /// （旧 min 语义与 BUG6 wave-b 相对锚点在该构型下同为 [F, C]——folder 落 A 格，均必 FAIL。）
    func testBug6LeftDirectionFolderLandsAtTargetSlot() throws {
        let (snapshot, layout) = try makeLayoutFixture(["Alpha", "Beta", "Gamma"])
        let r = refs(snapshot)   // 角色按位置：A = r[0], B = r[1], C = r[2]
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000B6000001")!)
        let result = LayoutMutation(expectedGeneration: .zero).createFolder(
            in: layout, target: r[1], source: r[0], folderID: folderID)
        guard case .success(let newLayout) = result else {
            return XCTFail("expected success, got \(result)")
        }
        // 落点 = drop 目标 target 原 index（B 原下标 1）→ 结果 [C, F]（C 补到左边）。
        XCTAssertEqual(newLayout.topLevelOrder, [.app(r[2]), .folder(folderID)])
        XCTAssertEqual(newLayout.folders.count, 1)
        XCTAssertEqual(newLayout.folders[0].members, [r[1], r[0]])   // 先目标后源 [B, A]
        XCTAssertEqual(newLayout.generation.value, 1)
        assertNoIssues(newLayout)
    }

    /// 右方向（相邻）：[B, A, C]，A 拖到 B 上（source=1, target=0）→
    /// folder 顶替 B 原格（index 0）→ [F, C]。
    /// （target 恰为较小下标：与旧 min 语义同值——同值回归锁。）
    func testBug6RightDirectionFolderLandsAtTargetSlot() throws {
        let (snapshot, layout) = try makeLayoutFixture(["Alpha", "Beta", "Gamma"])
        let r = refs(snapshot)   // 角色按位置：B = r[0], A = r[1], C = r[2]
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000B6000002")!)
        let result = LayoutMutation(expectedGeneration: .zero).createFolder(
            in: layout, target: r[0], source: r[1], folderID: folderID)
        guard case .success(let newLayout) = result else {
            return XCTFail("expected success, got \(result)")
        }
        XCTAssertEqual(newLayout.topLevelOrder, [.folder(folderID), .app(r[2])])   // 索引 0 = B 原格
        XCTAssertEqual(newLayout.folders[0].members, [r[0], r[1]])                 // [B, A]
        XCTAssertEqual(newLayout.generation.value, 1)
        assertNoIssues(newLayout)
    }

    /// 非相邻：[A, X, B, C]，A 拖到 B 上（source=0, target=2，中间隔 X）→
    /// folder 顶替 B 原格（index 2）→ [X, C, F]。
    /// （旧 min 语义 → [F, X, C]；BUG6 wave-b 相对锚点 → [X, F, C]，左偏一格——均必 FAIL。）
    func testBug6NonAdjacentSourceLeftFolderLandsAtTargetSlotNotSourceSlot() throws {
        let (snapshot, layout) = try makeLayoutFixture(["Alpha", "Beta", "Gamma", "Delta"])
        let r = refs(snapshot)   // 角色按位置：A = r[0], X = r[1], B = r[2], C = r[3]
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000B6000003")!)
        let result = LayoutMutation(expectedGeneration: .zero).createFolder(
            in: layout, target: r[2], source: r[0], folderID: folderID)
        guard case .success(let newLayout) = result else {
            return XCTFail("expected success, got \(result)")
        }
        XCTAssertEqual(newLayout.topLevelOrder, [.app(r[1]), .app(r[3]), .folder(folderID)])
        XCTAssertEqual(newLayout.folders[0].members, [r[2], r[0]])   // 先目标后源 [B, A]
        assertNoIssues(newLayout)
    }

    // MARK: - 拒绝路径不回归

    /// .duplicateReference / .nestedFolder / .invalidTarget / .staleGeneration 四条拒绝路径
    /// 行为不变，且拒绝不产生任何写入（generation 与布局原值不变）。
    func testBug6RejectionPathsUnchanged() throws {
        let (snapshot, layout) = try makeLayoutFixture(["Alpha", "Beta", "Gamma"])
        let r = refs(snapshot)
        let engine = LayoutMutation(expectedGeneration: .zero)

        // .duplicateReference：target == source。
        if case .rejected(let reason) = engine.createFolder(in: layout, target: r[0], source: r[0]) {
            XCTAssertEqual(reason, .duplicateReference)
        } else { XCTFail("expected duplicateReference") }

        // .nestedFolder：任一操作数已是 folder 成员（不隐式嵌套/合并）。
        guard case .success(let f) = engine.createFolder(in: layout, target: r[0], source: r[1]) else {
            return XCTFail()
        }
        if case .rejected(let reason) = LayoutMutation(expectedGeneration: f.generation)
            .createFolder(in: f, target: r[2], source: r[0]) {
            XCTAssertEqual(reason, .nestedFolder)
        } else { XCTFail("expected nestedFolder") }

        // .invalidTarget：未知引用。
        let unknown = PersistentAppReference.bundleID("fixture.unknown")
        if case .rejected(let reason) = engine.createFolder(in: layout, target: unknown, source: r[2]) {
            XCTAssertEqual(reason, .invalidTarget)
        } else { XCTFail("expected invalidTarget") }

        // .staleGeneration：expectedGeneration 与当前不符。
        if case .rejected(let reason) = LayoutMutation(expectedGeneration: .zero.incremented())
            .createFolder(in: layout, target: r[0], source: r[1]) {
            XCTAssertEqual(reason, .staleGeneration(expected: .zero.incremented(), current: .zero))
        } else { XCTFail("expected staleGeneration") }

        // 全部拒绝后原布局不变、无半提交。
        XCTAssertEqual(layout.generation, .zero)
        XCTAssertEqual(layout, PersistentWorkspaceLayout.makeDefault(catalog: snapshot))
        assertNoIssues(layout)
    }
}