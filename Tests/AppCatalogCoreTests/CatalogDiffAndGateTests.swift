//
//  CatalogDiffAndGateTests.swift
//  AppCatalogCoreTests
//
//  §10.2：add/remove/reorder diff、snapshot revision 单调、stale revision 拒绝。
//

import XCTest
import AppCatalogCore

final class CatalogDiffAndGateTests: XCTestCase {

    /// displayName == 记录名（单字母，排序稳定）；bundleID "com.example.<name>"；URL /Applications/<name>.app。
    private func rec(_ name: String) -> AppRecord {
        TestSupport.makeRecord("com.example.\(name)", displayName: name, url: "/Applications/\(name).app")
    }

    // MARK: - diff

    func testDiffAdd() throws {
        let from = try TestSupport.snapshot([rec("A")], revision: 1)
        let to = try TestSupport.snapshot([rec("A"), rec("B")], revision: 2)
        let diff = try CatalogDiffBuilder.diff(from: from, to: to)
        XCTAssertEqual(diff.fromRevision, CatalogRevision(1))
        XCTAssertEqual(diff.toRevision, CatalogRevision(2))
        XCTAssertEqual(diff.added.map(\.id), [rec("B").id])
        XCTAssertEqual(diff.removed, [])
        XCTAssertEqual(diff.moved, [rec("B").id])   // 新增项索引变化 → 属重排涉及项
    }

    func testDiffRemove() throws {
        let from = try TestSupport.snapshot([rec("A"), rec("B"), rec("C")], revision: 1)
        let to = try TestSupport.snapshot([rec("A"), rec("C")], revision: 2)
        let diff = try CatalogDiffBuilder.diff(from: from, to: to)
        XCTAssertEqual(diff.added, [])
        XCTAssertEqual(diff.removed.map(\.id), [rec("B").id])
        // moved = 重排涉及项：C 因移除位移（index 2→1）、B 移除（1→nil）→ to 顺序 [C] + from-only [B]
        XCTAssertEqual(diff.moved, [rec("C").id, rec("B").id])
    }

    func testDiffReorderViaOrderingChange() throws {
        let zed = TestSupport.makeRecord("com.example.z", displayName: "z", url: "/Applications/z.app")
        let umlaut = TestSupport.makeRecord("com.example.ae", displayName: "ä", url: "/Applications/ae.app")
        // de_DE：ä < z；sv_SE：z < ä（瑞典语 ä 排 z 后）→ 同一集合、两种排序 → 纯重排 diff
        let de = CatalogPolicy(ordering: CatalogOrdering(locale: Locale(identifier: "de_DE")))
        let sv = CatalogPolicy(ordering: CatalogOrdering(locale: Locale(identifier: "sv_SE")))
        let from = try TestSupport.snapshot([zed, umlaut], revision: 1, policy: de)   // [ä, z]
        let to = try TestSupport.snapshot([zed, umlaut], revision: 2, policy: sv)     // [z, ä]
        let diff = try CatalogDiffBuilder.diff(from: from, to: to)
        XCTAssertEqual(diff.added, [])
        XCTAssertEqual(diff.removed, [])
        XCTAssertEqual(diff.moved, [zed.id, umlaut.id])   // 两记录索引均变化（to 顺序）
    }

    func testDiffCombinedAddRemoveAndShift() throws {
        let from = try TestSupport.snapshot([rec("A"), rec("B"), rec("C")], revision: 1)
        let to = try TestSupport.snapshot([rec("B"), rec("D")], revision: 2)
        let diff = try CatalogDiffBuilder.diff(from: from, to: to)
        XCTAssertEqual(diff.added.map(\.id), [rec("D").id])
        XCTAssertEqual(diff.removed.map(\.id), [rec("A").id, rec("C").id])
        // moved：B 位移（1→0）、D 新增（to 顺序 [B, D]）+ from-only 移除 [A, C]
        XCTAssertEqual(diff.moved, [rec("B").id, rec("D").id, rec("A").id, rec("C").id])
    }

    func testDiffIdenticalContentDifferentRevision() throws {
        let from = try TestSupport.snapshot([rec("A"), rec("B")], revision: 1)
        let to = try TestSupport.snapshot([rec("A"), rec("B")], revision: 2)
        let diff = try CatalogDiffBuilder.diff(from: from, to: to)
        XCTAssertEqual(diff.added, [])
        XCTAssertEqual(diff.removed, [])
        XCTAssertEqual(diff.moved, [])
    }

    func testDiffRequiresStrictlyIncreasingRevision() throws {
        let snap1 = try TestSupport.snapshot([rec("A")], revision: 1)
        let snap1b = try TestSupport.snapshot([rec("A"), rec("B")], revision: 1)
        XCTAssertThrowsError(try CatalogDiffBuilder.diff(from: snap1, to: snap1b)) { error in
            XCTAssertEqual(error as? CatalogGateError,
                           .nonMonotonic(attempted: CatalogRevision(1), previous: CatalogRevision(1)))
        }
        let snap0 = try TestSupport.snapshot([rec("A")], revision: 0)
        XCTAssertThrowsError(try CatalogDiffBuilder.diff(from: snap1, to: snap0))
    }

    // MARK: - SnapshotGate（strictly increasing / stale 拒绝）

    func testGateAcceptsStrictlyIncreasing() throws {
        var gate = SnapshotGate()
        XCTAssertNil(gate.current)
        XCTAssertEqual(try gate.accept(try TestSupport.snapshot([], revision: 0)).revision, CatalogRevision(0))
        XCTAssertEqual(gate.current, CatalogRevision(0))
        _ = try gate.accept(try TestSupport.snapshot([], revision: 1))
        _ = try gate.accept(try TestSupport.snapshot([], revision: 10))
        XCTAssertEqual(gate.current, CatalogRevision(10))
    }

    func testGateRejectsStaleAndEqual() throws {
        var gate = SnapshotGate()
        _ = try gate.accept(try TestSupport.snapshot([], revision: 5))
        XCTAssertThrowsError(try gate.accept(try TestSupport.snapshot([], revision: 4))) { error in
            XCTAssertEqual(error as? CatalogGateError,
                           .staleRevision(current: CatalogRevision(5), attempted: CatalogRevision(4)))
        }
        XCTAssertThrowsError(try gate.accept(try TestSupport.snapshot([], revision: 5)))
        XCTAssertEqual(gate.current, CatalogRevision(5))   // 拒绝不改变内部状态
    }

    func testGateAcceptsAfterRejection() throws {
        var gate = SnapshotGate()
        _ = try gate.accept(try TestSupport.snapshot([], revision: 5))
        XCTAssertThrowsError(try gate.accept(try TestSupport.snapshot([], revision: 3)))
        _ = try gate.accept(try TestSupport.snapshot([], revision: 6))
        XCTAssertEqual(gate.current, CatalogRevision(6))
    }
}
