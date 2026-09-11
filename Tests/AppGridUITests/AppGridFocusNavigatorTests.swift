// AppGridUITests — AppGridFocusNavigatorTests（Phase 1C §7.1 方向键导航测试）

import AppCatalogCore
import PagingUI
@testable import AppGridUI
import XCTest

final class AppGridFocusNavigatorTests: XCTestCase {

    private func layout(titles: [String], revision: UInt64 = 1, itemsPerPage: Int = 35) throws -> AppGridFocusLayout {
        try AppGridFocusLayout.build(from: makeSnapshot(titles: titles, revision: revision), itemsPerPage: itemsPerPage)
    }

    private func identity(_ layout: AppGridFocusLayout, page: Int, slot: Int) -> AppGridFocusIdentity? {
        guard let appID = layout.validAppID(page: page, slot: slot) else { return nil }
        return AppGridFocusIdentity(catalogRevision: layout.revision, pageIndex: page, slotIndex: slot, appID: appID)
    }

    // MARK: - 5 列：左/右/上/下

    func testRightLeftIn5Columns() throws {
        let layout = try layout(titles: (0..<10).map { "App\(String(format: "%02d", $0))" }, itemsPerPage: 35)
        let nav = AppGridFocusNavigator(columns: 5)
        let start = identity(layout, page: 0, slot: 0)!

        let right = nav.move(start, direction: .right, in: layout)
        XCTAssertEqual(right?.slotIndex, 1)
        XCTAssertEqual(right?.pageIndex, 0)

        let left = nav.move(right!, direction: .left, in: layout)
        XCTAssertEqual(left, start)

        // 行末（slot 4 = row 0 末位）→ 下一行第一个（slot 5）。
        let row0end = identity(layout, page: 0, slot: 4)!
        let wrap = nav.move(row0end, direction: .right, in: layout)
        XCTAssertEqual(wrap?.slotIndex, 5)
        XCTAssertEqual(wrap?.pageIndex, 0)
        // 行首（slot 5 = row 1 首位）→ 上一行最后一个（slot 4）。
        let back = nav.move(wrap!, direction: .left, in: layout)
        XCTAssertEqual(back, row0end)
    }

    func testUpDownIn5Columns() throws {
        let layout = try layout(titles: (0..<10).map { "App\(String(format: "%02d", $0))" }, itemsPerPage: 35)
        let nav = AppGridFocusNavigator(columns: 5)
        let start = identity(layout, page: 0, slot: 0)!

        let down = nav.move(start, direction: .down, in: layout)
        XCTAssertEqual(down?.slotIndex, 5)
        XCTAssertEqual(down?.pageIndex, 0)

        let up = nav.move(down!, direction: .up, in: layout)
        XCTAssertEqual(up, start)

        // 列底（slot 5 = 列 0 底）→ 下一列第一个（slot 1，列 1 顶）。
        let col0bottom = identity(layout, page: 0, slot: 5)!
        let wrap = nav.move(col0bottom, direction: .down, in: layout)
        XCTAssertEqual(wrap?.slotIndex, 1)
        // 列顶（slot 1 = 列 1 顶）→ 上一列最后一个（slot 5）。
        let back = nav.move(wrap!, direction: .up, in: layout)
        XCTAssertEqual(back, col0bottom)
    }

    // MARK: - 非 5 列：左/右/上/下

    func testRightLeftInNon5Columns() throws {
        let layout = try layout(titles: (0..<12).map { "App\(String(format: "%02d", $0))" }, itemsPerPage: 35)
        let nav = AppGridFocusNavigator(columns: 4)
        let start = identity(layout, page: 0, slot: 0)!
        let right = nav.move(start, direction: .right, in: layout)
        XCTAssertEqual(right?.slotIndex, 1)
        let right2 = nav.move(right!, direction: .right, in: layout)
        XCTAssertEqual(right2?.slotIndex, 2)
        let left = nav.move(right2!, direction: .left, in: layout)
        XCTAssertEqual(left?.slotIndex, 1)

        // 行末（slot 3 = row 0 末位）→ 下一行第一个（slot 4）。
        let row0end = identity(layout, page: 0, slot: 3)!
        let wrap = nav.move(row0end, direction: .right, in: layout)
        XCTAssertEqual(wrap?.slotIndex, 4)
        // 行首（slot 4 = row 1 首位）→ 上一行最后一个（slot 3）。
        let back = nav.move(wrap!, direction: .left, in: layout)
        XCTAssertEqual(back, row0end)
    }

    func testUpDownInNon5Columns() throws {
        let layout = try layout(titles: (0..<12).map { "App\(String(format: "%02d", $0))" }, itemsPerPage: 35)
        let nav = AppGridFocusNavigator(columns: 4)
        let start = identity(layout, page: 0, slot: 0)!
        let down = nav.move(start, direction: .down, in: layout)
        XCTAssertEqual(down?.slotIndex, 4)
        let up = nav.move(down!, direction: .up, in: layout)
        XCTAssertEqual(up, start)

        // 列底（slot 8 = 列 0 底）→ 下一列第一个（slot 1，列 1 顶）。
        let col0bottom = identity(layout, page: 0, slot: 8)!
        let wrap = nav.move(col0bottom, direction: .down, in: layout)
        XCTAssertEqual(wrap?.slotIndex, 1)
        // 列顶（slot 1 = 列 1 顶）→ 上一列最后一个（slot 8）。
        let back = nav.move(wrap!, direction: .up, in: layout)
        XCTAssertEqual(back, col0bottom)
    }

    // MARK: - 末页不完整网格不越界

    func testIncompleteLastPageNoOutOfBounds() throws {
        // 8 个 app，5 列，itemsPerPage 5 → 页 0 满（5），页 1 只有 3 个
        let layout = try layout(titles: (0..<8).map { "App\(String(format: "%02d", $0))" }, itemsPerPage: 5)
        let nav = AppGridFocusNavigator(columns: 5)
        // 页 1 最后一个有效 cell = slot 2
        let last = identity(layout, page: 1, slot: 2)!
        XCTAssertNil(nav.move(last, direction: .right, in: layout))
        XCTAssertNil(nav.move(last, direction: .down, in: layout))
        // 页 1 slot 0 下移 → 列底环绕到下一列第一个（slot 1，页内，不越界）
        let p1s0 = identity(layout, page: 1, slot: 0)!
        let wrapped = nav.move(p1s0, direction: .down, in: layout)
        XCTAssertEqual(wrapped?.slotIndex, 1)
        XCTAssertEqual(wrapped?.pageIndex, 1)
    }

    // MARK: - 边缘跨页策略

    func testCrossPageRight() throws {
        // 10 个 app，5 列，itemsPerPage 5 → 2 页
        let layout = try layout(titles: (0..<10).map { "App\(String(format: "%02d", $0))" }, itemsPerPage: 5)
        let nav = AppGridFocusNavigator(columns: 5)
        let row0end = identity(layout, page: 0, slot: 4)!
        let next = nav.move(row0end, direction: .right, in: layout)
        XCTAssertEqual(next?.pageIndex, 1)
        XCTAssertEqual(next?.slotIndex, 0)   // 页 1 首个有效 cell（打字机跨页）
    }

    func testCrossPageLeft() throws {
        let layout = try layout(titles: (0..<10).map { "App\(String(format: "%02d", $0))" }, itemsPerPage: 5)
        let nav = AppGridFocusNavigator(columns: 5)
        let p1s0 = identity(layout, page: 1, slot: 0)!
        let prev = nav.move(p1s0, direction: .left, in: layout)
        XCTAssertEqual(prev?.pageIndex, 0)
        XCTAssertEqual(prev?.slotIndex, 4)   // 页 0 末个有效 cell（打字机跨页）
    }

    func testCrossPageRightToShorterNextPageLandsOnFirstSlot() throws {
        // 13 个 app，itemsPerPage 10，5 列 → 页 0 满（10，2 行），页 1 3 个（1 行）
        let layout = try layout(titles: (0..<13).map { "App\(String(format: "%02d", $0))" }, itemsPerPage: 10)
        let nav = AppGridFocusNavigator(columns: 5)
        // 页 0 行 1 末位 = slot 9
        let row1end = identity(layout, page: 0, slot: 9)!
        let next = nav.move(row1end, direction: .right, in: layout)
        XCTAssertEqual(next?.pageIndex, 1)
        // 打字机跨页：页 1 首个有效 cell = slot 0（不再 row-preserving clamp）
        XCTAssertEqual(next?.slotIndex, 0)
    }

    func testNoWrapAtGlobalBoundary() throws {
        let layout = try layout(titles: (0..<10).map { "App\(String(format: "%02d", $0))" }, itemsPerPage: 5)
        let nav = AppGridFocusNavigator(columns: 5)
        // 末页末位 = 页 1 slot 4
        let last = identity(layout, page: 1, slot: 4)!
        XCTAssertNil(nav.move(last, direction: .right, in: layout))
        XCTAssertNil(nav.move(last, direction: .down, in: layout))
        // 首页首位 = 页 0 slot 0
        let first = identity(layout, page: 0, slot: 0)!
        XCTAssertNil(nav.move(first, direction: .left, in: layout))
        XCTAssertNil(nav.move(first, direction: .up, in: layout))
    }

    // MARK: - 重复/快速方向键序列可预测

    func testRepeatedArrowKeysPredictable() throws {
        let layout = try layout(titles: (0..<10).map { "App\(String(format: "%02d", $0))" }, itemsPerPage: 5)
        let nav = AppGridFocusNavigator(columns: 5)
        var current = identity(layout, page: 0, slot: 0)!
        for _ in 0..<4 {
            current = nav.move(current, direction: .right, in: layout)!
        }
        XCTAssertEqual(current.slotIndex, 4)
        // 再右移 → 跨页到页 1 slot 0（打字机：末行末 → 下一页首格）
        current = nav.move(current, direction: .right, in: layout)!
        XCTAssertEqual(current.pageIndex, 1)
        XCTAssertEqual(current.slotIndex, 0)
        // 页 1 行内继续右移 → slot 1
        current = nav.move(current, direction: .right, in: layout)!
        XCTAssertEqual(current.pageIndex, 1)
        XCTAssertEqual(current.slotIndex, 1)
    }

    func testRapidSequencePredictable() throws {
        let layout = try layout(titles: (0..<10).map { "App\(String(format: "%02d", $0))" }, itemsPerPage: 5)
        let nav = AppGridFocusNavigator(columns: 5)
        var current = identity(layout, page: 0, slot: 0)!
        // 右 → slot 1
        current = nav.move(current, direction: .right, in: layout)!
        XCTAssertEqual(current.slotIndex, 1)
        // 下 → 列底环绕到下一列第一个（slot 2，页内）
        current = nav.move(current, direction: .down, in: layout)!
        XCTAssertEqual(current.slotIndex, 2)
        // 右 → slot 3（行内继续）
        current = nav.move(current, direction: .right, in: layout)!
        XCTAssertEqual(current.slotIndex, 3)
        // 右 → slot 4（行末）
        current = nav.move(current, direction: .right, in: layout)!
        XCTAssertEqual(current.slotIndex, 4)
        // 下 → 末列底 → 下一页首格（页 1 slot 0）
        current = nav.move(current, direction: .down, in: layout)!
        XCTAssertEqual(current.pageIndex, 1)
        XCTAssertEqual(current.slotIndex, 0)
        // 下 → 列底环绕到下一列第一个（页 1 slot 1）
        current = nav.move(current, direction: .down, in: layout)!
        XCTAssertEqual(current.pageIndex, 1)
        XCTAssertEqual(current.slotIndex, 1)
    }

    // MARK: - 部分末页列环绕（T-1E 打字机）

    func testColumnWrapOnPartialPage() throws {
        // 32 个 app，5 列，itemsPerPage 35 → 单页 32 项（7 行，末行 2 项）
        let layout = try layout(titles: (0..<32).map { "App\(String(format: "%02d", $0))" }, itemsPerPage: 35)
        let nav = AppGridFocusNavigator(columns: 5)
        // 列底（slot 30 = 列 0 底）↓ → 下一列第一个（slot 1）
        let col0bottom = identity(layout, page: 0, slot: 30)!
        let down = nav.move(col0bottom, direction: .down, in: layout)
        XCTAssertEqual(down?.slotIndex, 1)
        XCTAssertEqual(down?.pageIndex, 0)
        // 列顶（slot 1 = 列 1 顶）↑ → 上一列最后一个（slot 30）
        let up = nav.move(down!, direction: .up, in: layout)
        XCTAssertEqual(up, col0bottom)
        // 末列底（slot 29 = 列 4 底）↓ → 无下一列 → 末页 → nil
        let lastColBottom = identity(layout, page: 0, slot: 29)!
        XCTAssertNil(nav.move(lastColBottom, direction: .down, in: layout))
    }

    func testColumnWrapCrossesPage() throws {
        // 32 个 app，5 列，itemsPerPage 20 → 页 0 满（20，4 行），页 1 12 个
        let layout = try layout(titles: (0..<32).map { "App\(String(format: "%02d", $0))" }, itemsPerPage: 20)
        let nav = AppGridFocusNavigator(columns: 5)
        // 页 0 末列底（slot 19）↓ → 下一页首格（页 1 slot 0）
        let page0end = identity(layout, page: 0, slot: 19)!
        let next = nav.move(page0end, direction: .down, in: layout)
        XCTAssertEqual(next?.pageIndex, 1)
        XCTAssertEqual(next?.slotIndex, 0)
        // 页 1 首列顶（slot 0）↑ → 上一页末格（页 0 slot 19）
        let p1s0 = identity(layout, page: 1, slot: 0)!
        let prev = nav.move(p1s0, direction: .up, in: layout)
        XCTAssertEqual(prev?.pageIndex, 0)
        XCTAssertEqual(prev?.slotIndex, 19)
    }

    // MARK: - stale 身份不导航

    func testStaleIdentityNotNavigated() throws {
        let layout = try layout(titles: (0..<10).map { "App\(String(format: "%02d", $0))" }, itemsPerPage: 5)
        let nav = AppGridFocusNavigator(columns: 5)
        let stale = AppGridFocusIdentity(catalogRevision: 0, pageIndex: 0, slotIndex: 0, appID: makeAppID("fixture.app00"))
        XCTAssertNil(nav.move(stale, direction: .right, in: layout))
    }

    // MARK: - Reduce Motion 无关（导航决策不依赖 RM 参数；状态正确）

    func testReduceMotionIndependentNavigationState() throws {
        // 纯逻辑导航无 RM 参数；验证跨页导航状态正确（RM 只影响动画，不影响焦点状态）
        let layout = try layout(titles: (0..<10).map { "App\(String(format: "%02d", $0))" }, itemsPerPage: 5)
        let nav = AppGridFocusNavigator(columns: 5)
        let row0end = identity(layout, page: 0, slot: 4)!
        let next = nav.move(row0end, direction: .right, in: layout)
        XCTAssertEqual(next?.pageIndex, 1)
        XCTAssertEqual(next?.slotIndex, 0)
        XCTAssertEqual(next?.catalogRevision, layout.revision)
    }
}
