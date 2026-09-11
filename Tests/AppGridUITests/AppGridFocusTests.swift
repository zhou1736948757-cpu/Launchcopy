// AppGridUITests — AppGridFocusTests（Phase 1C §7.1 纯逻辑焦点 domain 测试）

import AppCatalogCore
import PagingUI
@testable import AppGridUI
import XCTest

final class AppGridFocusTests: XCTestCase {

    // MARK: - 空 catalog 无焦点

    func testEmptyCatalogNoFocus() throws {
        let empty = try makeSnapshot(titles: [], revision: 1)
        let layout = AppGridFocusLayout.build(from: empty, itemsPerPage: 35)
        XCTAssertEqual(layout.pageCount, 0)
        XCTAssertEqual(layout.validItemCount, 0)
        XCTAssertNil(layout.firstValidIdentity())

        var model = AppGridFocusModel()
        let outcome = model.apply(layout: layout)
        XCTAssertEqual(outcome, .empty)
        XCTAssertNil(model.current)
    }

    // MARK: - 确定性初始焦点

    func testDeterministicInitialFocus() throws {
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let layout = AppGridFocusLayout.build(from: snapshot, itemsPerPage: 35)
        let initial = AppGridFocusModel.initialFocus(in: layout)
        XCTAssertEqual(initial?.pageIndex, 0)
        XCTAssertEqual(initial?.slotIndex, 0)
        XCTAssertEqual(initial?.appID, makeAppID("fixture.alpha"))
        XCTAssertEqual(initial?.catalogRevision, 1)

        var model = AppGridFocusModel()
        let outcome = model.apply(layout: layout)
        XCTAssertEqual(model.current, initial)
        guard case .clamped = outcome else {
            return XCTFail("初始焦点应为 clamped(first valid)")
        }
    }

    // MARK: - pageCount 0/1/多页

    func testPageCountZeroOneMulti() throws {
        let empty = try makeSnapshot(titles: [], revision: 1)
        XCTAssertEqual(AppGridFocusLayout.build(from: empty, itemsPerPage: 35).pageCount, 0)

        let one = try makeSnapshot(titles: ["Alpha"], revision: 1)
        XCTAssertEqual(AppGridFocusLayout.build(from: one, itemsPerPage: 35).pageCount, 1)

        let multi = try makeSnapshot(titles: (0..<36).map { "App\(String(format: "%02d", $0))" }, revision: 1)
        XCTAssertEqual(AppGridFocusLayout.build(from: multi, itemsPerPage: 35).pageCount, 2)
    }

    // MARK: - catalog revision 更新保留同一 AppID

    func testRevisionUpdatePreservesSameAppID() throws {
        let rev1 = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        var model = AppGridFocusModel()
        model.apply(layout: AppGridFocusLayout.build(from: rev1, itemsPerPage: 35))
        XCTAssertEqual(model.current?.appID, makeAppID("fixture.alpha"))

        let rev2 = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma", "Delta"], revision: 2)
        let outcome = model.apply(layout: AppGridFocusLayout.build(from: rev2, itemsPerPage: 35))
        XCTAssertEqual(model.current?.appID, makeAppID("fixture.alpha"))
        XCTAssertEqual(model.current?.catalogRevision, 2)
        guard case .located = outcome else {
            return XCTFail("应 located，got \(outcome)")
        }
    }

    // MARK: - 焦点 App 消失 → successor / predecessor / clamped / empty

    func testFocusAppDisappearsSuccessorMigration() throws {
        let rev1 = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let alpha = makeAppID("fixture.alpha")
        var model = AppGridFocusModel(current: AppGridFocusIdentity(catalogRevision: 1, pageIndex: 0, slotIndex: 0, appID: alpha))

        let rev2 = try makeSnapshot(titles: ["Beta", "Gamma"], revision: 2)
        let outcome = model.apply(layout: AppGridFocusLayout.build(from: rev2, itemsPerPage: 35))
        guard case .successor(let id) = outcome else {
            return XCTFail("应 successor，got \(outcome)")
        }
        XCTAssertEqual(id.appID, makeAppID("fixture.beta"))
        XCTAssertEqual(model.current?.appID, makeAppID("fixture.beta"))
        XCTAssertEqual(model.current?.catalogRevision, 2)
    }

    func testFocusAppDisappearsPredecessorMigration() throws {
        let rev1 = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let gamma = makeAppID("fixture.gamma")
        var model = AppGridFocusModel(current: AppGridFocusIdentity(catalogRevision: 1, pageIndex: 0, slotIndex: 2, appID: gamma))

        let rev2 = try makeSnapshot(titles: ["Alpha", "Beta"], revision: 2)
        let outcome = model.apply(layout: AppGridFocusLayout.build(from: rev2, itemsPerPage: 35))
        guard case .predecessor = outcome else {
            return XCTFail("应 predecessor，got \(outcome)")
        }
        // 迁移聚焦到 predecessor 页首个有效 cell（ADR-006 文档化）
        XCTAssertEqual(model.current?.appID, makeAppID("fixture.alpha"))
        XCTAssertEqual(model.current?.catalogRevision, 2)
    }

    func testFocusAppDisappearsClampedMigration() throws {
        // 防御性：当前焦点无有效 appID（nil anchor）→ clamped 到首个有效 cell
        let rev2 = try makeSnapshot(titles: ["Zulu"], revision: 2)
        var model = AppGridFocusModel(current: AppGridFocusIdentity(catalogRevision: 1, pageIndex: 0, slotIndex: 0, appID: nil))
        let outcome = model.apply(layout: AppGridFocusLayout.build(from: rev2, itemsPerPage: 35))
        guard case .clamped(let id) = outcome else {
            return XCTFail("应 clamped，got \(outcome)")
        }
        XCTAssertEqual(id.appID, makeAppID("fixture.zulu"))
        XCTAssertEqual(model.current?.appID, makeAppID("fixture.zulu"))
    }

    func testFocusAppDisappearsEmptyMigration() throws {
        let rev1 = try makeSnapshot(titles: ["Alpha"], revision: 1)
        let alpha = makeAppID("fixture.alpha")
        var model = AppGridFocusModel(current: AppGridFocusIdentity(catalogRevision: 1, pageIndex: 0, slotIndex: 0, appID: alpha))

        let rev2 = try makeSnapshot(titles: [], revision: 2)
        let outcome = model.apply(layout: AppGridFocusLayout.build(from: rev2, itemsPerPage: 35))
        XCTAssertEqual(outcome, .empty)
        XCTAssertNil(model.current)
    }

    // MARK: - 旧 index 不会在新 snapshot 中错误复用

    func testOldIndexNotReusedInNewSnapshot() throws {
        // rev1: Alpha 在 slot 0；rev2: 插入 Aardvark（排序在 Alpha 前）→ Alpha 移到 slot 1
        let rev1 = try makeSnapshot(titles: ["Alpha", "Beta"], revision: 1)
        let alpha = makeAppID("fixture.alpha")
        var model = AppGridFocusModel(current: AppGridFocusIdentity(catalogRevision: 1, pageIndex: 0, slotIndex: 0, appID: alpha))

        let rev2 = try makeSnapshot(titles: ["Aardvark", "Alpha", "Beta"], revision: 2)
        let outcome = model.apply(layout: AppGridFocusLayout.build(from: rev2, itemsPerPage: 35))
        guard case .located(let id) = outcome else {
            return XCTFail("应 located，got \(outcome)")
        }
        XCTAssertEqual(id.slotIndex, 1)   // Alpha 新位置，不是旧 slot 0
        XCTAssertEqual(id.appID, alpha)
    }

    // MARK: - 旧 revision 永不夺回焦点

    func testOldRevisionNeverReclaimsFocus() throws {
        let rev2 = try makeSnapshot(titles: ["Alpha", "Beta"], revision: 2)
        let alpha = makeAppID("fixture.alpha")
        var model = AppGridFocusModel(current: AppGridFocusIdentity(catalogRevision: 2, pageIndex: 0, slotIndex: 0, appID: alpha))

        // 应用旧 revision（1）→ 不迁移，保持当前
        let rev1 = try makeSnapshot(titles: ["Alpha"], revision: 1)
        let outcome = model.apply(layout: AppGridFocusLayout.build(from: rev1, itemsPerPage: 35))
        guard case .unchanged(let id) = outcome else {
            return XCTFail("应 unchanged，got \(outcome)")
        }
        XCTAssertEqual(id, model.current)
        XCTAssertEqual(model.current?.catalogRevision, 2)
    }

    // MARK: - placeholder/空 slot 不可启动

    func testPlaceholderEmptySlotNotLaunchable() throws {
        // 3 个有效 app，itemsPerPage 5 → slot 3/4 为空（placeholder）
        let snapshot = try makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let layout = AppGridFocusLayout.build(from: snapshot, itemsPerPage: 5)
        XCTAssertEqual(layout.validItemCount, 3)
        XCTAssertEqual(layout.validSlots(on: 0), [0, 1, 2])
        XCTAssertNil(layout.validAppID(page: 0, slot: 3))
        XCTAssertNil(layout.validAppID(page: 0, slot: 4))
        XCTAssertEqual(layout.validAppID(page: 0, slot: 0), makeAppID("fixture.alpha"))
    }

    // MARK: - 焦点身份 revision-stable

    func testIdentityRevisionStable() throws {
        let a = AppGridFocusIdentity(catalogRevision: 1, pageIndex: 0, slotIndex: 0, appID: makeAppID("fixture.alpha"))
        let b = AppGridFocusIdentity(catalogRevision: 1, pageIndex: 0, slotIndex: 0, appID: makeAppID("fixture.alpha"))
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.presentationID, PagePresentationID(revision: 1, pageIndex: 0))
        XCTAssertNotEqual(a, AppGridFocusIdentity(catalogRevision: 2, pageIndex: 0, slotIndex: 0, appID: makeAppID("fixture.alpha")))
    }
}
