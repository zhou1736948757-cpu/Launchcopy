//
//  CatalogPlannerTests.swift
//  AppCatalogCoreTests
//
//  §10.2：pageCount（0/1/35/36/多页）、appID(page:slot:) 映射、remap 五级降级
//  （located → successor → predecessor → clamped → emptyCatalog；绝不沿用旧数组 index）、
//  pageIndex、anchorCandidate、pageCount shrink/clamp。
//

import XCTest
import AppCatalogCore

final class CatalogPlannerTests: XCTestCase {

    private let planner = CatalogPlanner()

    /// count 条记录：displayName "App 000"…（0 填充 → 显示序 == 创建序），
    /// bundleID "com.example.app<i>" 零填充到 3 位（"app000"…）→ AppID 字符串全序 == 数值序
    /// （未填充时 "app37" < "app4"（'3'<'4'），会破坏后继/前驱测试的可读性）。
    private func records(_ count: Int) -> [AppRecord] {
        (0..<count).map { i in
            TestSupport.makeRecord(String(format: "com.example.app%03d", i),
                                   displayName: String(format: "App %03d", i),
                                   url: "/Applications/App\(i).app")
        }
    }

    // MARK: - pageCount（对齐 PagingSurface 默认 35：35 条 = 1 页、36 条 = 2 页）

    func testPageCountZeroItems() throws {
        let snapshot = try TestSupport.snapshot([])
        let plan = planner.plan(snapshot: snapshot, itemsPerPage: 35)
        XCTAssertEqual(plan.itemCount, 0)
        XCTAssertEqual(plan.pageCount, 0)
        XCTAssertEqual(plan.snapshotRevision, snapshot.revision)
        XCTAssertEqual(plan.itemsPerPage, 35)
    }

    func testPageCountOneItem() throws {
        let snapshot = try TestSupport.snapshot(records(1))
        XCTAssertEqual(planner.plan(snapshot: snapshot, itemsPerPage: 35).pageCount, 1)
    }

    func testPageCount35IsOnePage() throws {
        let snapshot = try TestSupport.snapshot(records(35))
        let plan = planner.plan(snapshot: snapshot, itemsPerPage: 35)
        XCTAssertEqual(plan.itemCount, 35)
        XCTAssertEqual(plan.pageCount, 1)
    }

    func testPageCount36IsTwoPages() throws {
        let snapshot = try TestSupport.snapshot(records(36))
        let plan = planner.plan(snapshot: snapshot, itemsPerPage: 35)
        XCTAssertEqual(plan.itemCount, 36)
        XCTAssertEqual(plan.pageCount, 2)
    }

    func testPageCountMultiples() throws {
        let snap70 = try TestSupport.snapshot(records(70))
        XCTAssertEqual(planner.plan(snapshot: snap70, itemsPerPage: 35).pageCount, 2)
        let snap71 = try TestSupport.snapshot(records(71))
        XCTAssertEqual(planner.plan(snapshot: snap71, itemsPerPage: 35).pageCount, 3)
    }

    // MARK: - appID(page:slot:)

    func testAppIDMappingAcrossPages() throws {
        let snapshot = try TestSupport.snapshot(records(36))
        let plan = planner.plan(snapshot: snapshot, itemsPerPage: 35)
        XCTAssertEqual(plan.appID(page: 0, slot: 0), snapshot.records[0].id)
        XCTAssertEqual(plan.appID(page: 0, slot: 34), snapshot.records[34].id)
        XCTAssertEqual(plan.appID(page: 1, slot: 0), snapshot.records[35].id)
        // 越界/空 → nil
        XCTAssertNil(plan.appID(page: 0, slot: 35))   // slot ≥ itemsPerPage
        XCTAssertNil(plan.appID(page: 1, slot: 34))   // 超 itemCount
        XCTAssertNil(plan.appID(page: 2, slot: 0))    // page ≥ pageCount
        XCTAssertNil(plan.appID(page: -1, slot: 0))
        XCTAssertNil(plan.appID(page: 0, slot: -1))
    }

    func testEmptyPlanAppIDAlwaysNil() throws {
        let snapshot = try TestSupport.snapshot([])
        let plan = planner.plan(snapshot: snapshot, itemsPerPage: 35)
        XCTAssertNil(plan.appID(page: 0, slot: 0))
    }

    // MARK: - remap：located（规则 1）

    func testRemapLocatedWhenAnchorExists() throws {
        let snapshot = try TestSupport.snapshot(records(40))
        let anchor = snapshot.records[37].id          // 新快照 index 37 → 页 1
        let (plan, outcome) = planner.remap(snapshot: snapshot, anchor: anchor, itemsPerPage: 35)
        XCTAssertEqual(outcome, .located(pageIndex: 1))
        XCTAssertEqual(plan.pageCount, 2)
    }

    func testRemapUsesNewIndexNotOldIndex() throws {
        // 旧快照 [P, Q, R, X]（X 旧 index 3 → 旧页 1）；新快照 X 在 index 0 → 新页 0。
        // 若沿用旧数组 index（3/2=1）会得到 1；断言 0 证明 remap 完全由新快照推导（规则 6）。
        let new = try TestSupport.snapshot(records(4))
        let anchor = new.records[0].id
        let (_, outcome) = planner.remap(snapshot: new, anchor: anchor, itemsPerPage: 2)
        XCTAssertEqual(outcome, .located(pageIndex: 0))
    }

    // MARK: - remap：successor / predecessor（规则 2/3；AppID 全序近似）

    func testRemapSuccessorWhenAnchorRemoved() throws {
        let full = try TestSupport.snapshot(records(3))
        let remaining = try TestSupport.snapshot(Array(records(3).dropFirst()))   // app1, app2
        let anchor = full.records[0].id                                           // app0 已消失
        let (_, outcome) = planner.remap(snapshot: remaining, anchor: anchor, itemsPerPage: 35)
        XCTAssertEqual(outcome, .successor(pageIndex: 0))   // 后继 = 首个 AppID 全序 > app0 = app1
    }

    func testRemapPredecessorWhenNoSuccessor() throws {
        let snapshot = try TestSupport.snapshot(records(3))
        let anchor = AppID.bundleIdentifier("com.example.zzz")   // 从未存在且大于全部
        let (_, outcome) = planner.remap(snapshot: snapshot, anchor: anchor, itemsPerPage: 35)
        XCTAssertEqual(outcome, .predecessor(pageIndex: 0))     // 前驱 = 最后一个 < zzz = app2 → 页 0
    }

    func testRemapPredecessorSpansLaterPage() throws {
        let snapshot = try TestSupport.snapshot(records(40))
        let anchor = AppID.bundleIdentifier("com.example.zzz")
        let (_, outcome) = planner.remap(snapshot: snapshot, anchor: anchor, itemsPerPage: 35)
        XCTAssertEqual(outcome, .predecessor(pageIndex: 1))     // app39 → index 39 → 页 1
    }

    // MARK: - remap：clamped / emptyCatalog（规则 4/5）

    func testRemapNilAnchorClampsToFirstPage() throws {
        let snapshot = try TestSupport.snapshot(records(40))
        let (_, outcome) = planner.remap(snapshot: snapshot, anchor: nil, itemsPerPage: 35)
        XCTAssertEqual(outcome, .clamped(pageIndex: 0))
    }

    func testRemapEmptyCatalog() throws {
        let snapshot = try TestSupport.snapshot([])
        let (plan, outcome) = planner.remap(snapshot: snapshot, anchor: nil, itemsPerPage: 35)
        XCTAssertEqual(outcome, .emptyCatalog)
        XCTAssertEqual(plan.pageCount, 0)
        let (_, outcome2) = planner.remap(snapshot: snapshot,
                                          anchor: AppID.bundleIdentifier("com.example.x"), itemsPerPage: 35)
        XCTAssertEqual(outcome2, .emptyCatalog)
    }

    // MARK: - remap：pageCount shrink（§6.3 规则 5；10.2 page count shrink/clamp）

    func testRemapAfterPageCountShrink() throws {
        func shrink(_ count: Int) throws -> CatalogSnapshot { try TestSupport.snapshot(records(count)) }
        // 锚点仍在：pageCount 缩小但锚点保留 → located 到合法新页
        let anchor = try shrink(38).records[35].id   // app035
        XCTAssertEqual(planner.remap(snapshot: try shrink(38), anchor: anchor, itemsPerPage: 35).outcome,
                       .located(pageIndex: 1))
        XCTAssertEqual(planner.remap(snapshot: try shrink(36), anchor: anchor, itemsPerPage: 35).outcome,
                       .located(pageIndex: 1))
        // 锚点消失（35 条已不含 app035）→ 无后继 → 前驱 = app034 → 页 0（pageCount 缩到 1）
        XCTAssertEqual(planner.remap(snapshot: try shrink(35), anchor: anchor, itemsPerPage: 35).outcome,
                       .predecessor(pageIndex: 0))
        XCTAssertEqual(planner.remap(snapshot: try shrink(20), anchor: anchor, itemsPerPage: 35).outcome,
                       .predecessor(pageIndex: 0))
        // 锚点消失且落在多页尾部：app037 → 前驱 app036 → 页 1
        let tail = try shrink(38).records[37].id   // app037
        XCTAssertEqual(planner.remap(snapshot: try shrink(37), anchor: tail, itemsPerPage: 35).outcome,
                       .predecessor(pageIndex: 1))
    }

    // MARK: - pageIndex / anchorCandidate

    func testPageIndexOf() throws {
        let snapshot = try TestSupport.snapshot(records(40))
        XCTAssertEqual(planner.pageIndex(of: snapshot.records[0].id, in: snapshot, itemsPerPage: 35), 0)
        XCTAssertEqual(planner.pageIndex(of: snapshot.records[35].id, in: snapshot, itemsPerPage: 35), 1)
        XCTAssertEqual(planner.pageIndex(of: snapshot.records[39].id, in: snapshot, itemsPerPage: 35), 1)
        XCTAssertNil(planner.pageIndex(of: AppID.bundleIdentifier("com.example.missing"), in: snapshot, itemsPerPage: 35))
        let empty = try TestSupport.snapshot([])
        XCTAssertNil(planner.pageIndex(of: AppID.bundleIdentifier("com.example.x"), in: empty, itemsPerPage: 35))
    }

    func testAnchorCandidateFirstVisibleAppID() throws {
        let snapshot = try TestSupport.snapshot(records(36))
        XCTAssertEqual(planner.anchorCandidate(nearPage: 0, in: snapshot, itemsPerPage: 35), snapshot.records[0].id)
        XCTAssertEqual(planner.anchorCandidate(nearPage: 1, in: snapshot, itemsPerPage: 35), snapshot.records[35].id)
        XCTAssertNil(planner.anchorCandidate(nearPage: 2, in: snapshot, itemsPerPage: 35))   // 越界
        XCTAssertNil(planner.anchorCandidate(nearPage: -1, in: snapshot, itemsPerPage: 35))
        let empty = try TestSupport.snapshot([])
        XCTAssertNil(planner.anchorCandidate(nearPage: 0, in: empty, itemsPerPage: 35))
    }

    func testAnchorCandidateFeedsRemap() throws {
        // 更新前：committed page 1 的首个可见 AppID = records[35].id；更新后仍存在 → located(page 1)
        let before = try TestSupport.snapshot(records(40))
        let anchor = planner.anchorCandidate(nearPage: 1, in: before, itemsPerPage: 35)!
        let after = try TestSupport.snapshot(records(40).reversed().map { $0 })   // 相同集合重排（build 重新稳定排序）
        XCTAssertEqual(after.records, before.records)
        let (_, outcome) = planner.remap(snapshot: after, anchor: anchor, itemsPerPage: 35)
        XCTAssertEqual(outcome, .located(pageIndex: 1))
    }
}
