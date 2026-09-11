// AppGridUITests — FolderOpenState（Phase 1E §3.1C 打开状态 owner）
// 纯逻辑测试：open/close/setInnerPage/generation/members；内部分页独立于外层。

import AppCatalogCore
import Foundation
@testable import AppGridUI
import XCTest

final class FolderOpenStateTests: XCTestCase {

    private func makeEntry(id: FolderID = FolderID(), title: String = "Group 1",
                           members: [AppID]) -> FolderEntry {
        FolderEntry(id: id, title: title, members: members)
    }

    private func makeIDs(_ count: Int) -> [AppID] {
        (0..<count).map { makeAppID("fixture.member\($0)") }
    }

    func testInitiallyClosed() {
        let state = FolderOpenState()
        XCTAssertFalse(state.isOpen)
        XCTAssertNil(state.openEntry)
        XCTAssertNil(state.openFolderID)
        XCTAssertEqual(state.memberCount, 0)
        XCTAssertEqual(state.innerPageCount, 0)
        XCTAssertEqual(state.generation, 0)
    }

    func testOpenSetsEntryAndResetsInnerPage() {
        let state = FolderOpenState()
        let entry = makeEntry(members: makeIDs(3))
        state.open(entry)
        XCTAssertTrue(state.isOpen)
        XCTAssertEqual(state.openFolderID, entry.id)
        XCTAssertEqual(state.memberCount, 3)
        XCTAssertEqual(state.innerPage, 0)
        XCTAssertEqual(state.generation, 1)
    }

    func testOpenBumpsGeneration() {
        let state = FolderOpenState()
        let a = makeEntry(members: makeIDs(2))
        let b = makeEntry(members: makeIDs(4))
        state.open(a)
        let genA = state.generation
        state.open(b)
        XCTAssertGreaterThan(state.generation, genA, "打开 A 后打开 B：generation 递增（A 旧回调被拒）")
        XCTAssertEqual(state.openFolderID, b.id)
    }

    func testCloseIsIdempotent() {
        let state = FolderOpenState()
        state.close()  // 已关闭 → 无操作
        XCTAssertEqual(state.generation, 0)
        state.open(makeEntry(members: makeIDs(2)))
        let gen = state.generation
        state.close()
        XCTAssertFalse(state.isOpen)
        XCTAssertNil(state.openEntry)
        XCTAssertGreaterThan(state.generation, gen)
        state.close()  // 再次关闭 → 无操作
        XCTAssertEqual(state.generation, gen + 1)
    }

    func testInnerPageCountAndMembers() {
        let state = FolderOpenState(membersPerPage: 3)
        let entry = makeEntry(members: makeIDs(7))
        state.open(entry)
        XCTAssertEqual(state.innerPageCount, 3)  // ceil(7/3) = 3
        XCTAssertEqual(state.members(onPage: 0).count, 3)
        XCTAssertEqual(state.members(onPage: 1).count, 3)
        XCTAssertEqual(state.members(onPage: 2).count, 1)
        XCTAssertEqual(state.members(onPage: 3).count, 0, "越界 → 空")
        XCTAssertEqual(state.members(onPage: -1).count, 0, "负页 → 空")
    }

    func testSetInnerPageClampsAndBumpsGeneration() {
        let state = FolderOpenState(membersPerPage: 3)
        state.open(makeEntry(members: makeIDs(7)))
        state.setInnerPage(1)
        XCTAssertEqual(state.innerPage, 1)
        let gen = state.generation
        state.setInnerPage(99)  // clamp 到最后一页
        XCTAssertEqual(state.innerPage, 2)
        XCTAssertGreaterThan(state.generation, gen)
        state.setInnerPage(2)  // 同页 → 无操作
        XCTAssertEqual(state.generation, gen + 1)
    }

    func testSetInnerPageWhenClosedIsNoOp() {
        let state = FolderOpenState()
        state.setInnerPage(1)
        XCTAssertEqual(state.innerPage, 0)
        XCTAssertEqual(state.generation, 0)
    }

    func testIsOpenForSpecificFolder() {
        let state = FolderOpenState()
        let id = FolderID()
        state.open(makeEntry(id: id, members: makeIDs(2)))
        XCTAssertTrue(state.isOpen(id))
        XCTAssertFalse(state.isOpen(FolderID()))
    }

    /// T-1G-FOLDER-DRAG-FIX：drag commit 后就地替换成员序，保留 innerPage。
    func testUpdateOpenEntryPreservesInnerPageAndReplacesMembers() {
        let state = FolderOpenState(membersPerPage: 3)
        let id = FolderID()
        let original = makeEntry(id: id, members: makeIDs(7))
        state.open(original)
        state.setInnerPage(1)
        let gen = state.generation

        let reordered = makeEntry(id: id, members: Array(makeIDs(7).reversed()))
        state.updateOpenEntry(reordered)
        XCTAssertEqual(state.openEntry?.members, reordered.members)
        XCTAssertEqual(state.innerPage, 1, "updateOpenEntry 不得把内部页重置为 0")
        XCTAssertGreaterThan(state.generation, gen)

        // 成员收缩导致当前页越界 → clamp。
        let shrunk = makeEntry(id: id, members: makeIDs(2))  // 1 页
        state.updateOpenEntry(shrunk)
        XCTAssertEqual(state.innerPage, 0, "成员收缩后 innerPage 应 clamp 到合法范围")
    }

    func testUpdateOpenEntryWrongIDOrClosedIsNoOp() {
        let state = FolderOpenState()
        let id = FolderID()
        state.updateOpenEntry(makeEntry(id: id, members: makeIDs(2)))
        XCTAssertFalse(state.isOpen)
        XCTAssertEqual(state.generation, 0)

        state.open(makeEntry(id: id, members: makeIDs(2)))
        let gen = state.generation
        state.updateOpenEntry(makeEntry(id: FolderID(), members: makeIDs(3)))
        XCTAssertEqual(state.generation, gen, "异 ID → no-op")
        XCTAssertEqual(state.memberCount, 2)
    }

    func testMembersPerPageClampedToAtLeastOne() {
        let state = FolderOpenState(membersPerPage: 0)
        XCTAssertEqual(state.membersPerPage, 1)
    }
}
