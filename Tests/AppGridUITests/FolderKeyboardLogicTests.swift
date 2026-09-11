// AppGridUITests — FolderKeyboardLogicTests（Phase 1E §3.1D 键盘/焦点/标题编辑纯逻辑；ADR-008 §3 Q10/Q11）
// 实现：T-1E-D（Worker D）。
//
// 覆盖：FolderInnerNavigator（四方向 + 跨页 + 边界）、FolderKeyboardPriority（ESC 优先级 /
// Command-F 关闭后搜索）、FolderFocusRestore（关闭后恢复 folder 条目 / 消失回退）、
// FolderTitleEditing（Enter 提交 / Escape 取消 / focus-loss 确定性提交 / 空白回退 / 长度上限）。

import XCTest
@testable import AppGridUI
import AppCatalogCore

final class FolderKeyboardLogicTests: XCTestCase {

    // MARK: - 测试数据辅助

    private func appID(_ n: Int) -> AppID {
        AppID.bundleIdentifier("com.test.app\(n)")
    }

    private func record(_ n: Int) -> AppRecord {
        AppRecord(id: appID(n), displayName: "App \(n)", bundleIdentifier: "com.test.app\(n)",
                  canonicalURL: URL(fileURLWithPath: "/tmp/app\(n).app"),
                  iconIdentity: IconIdentity.from(appID: appID(n)), sourceRootPriority: 0)
    }

    private func folderEntry(_ n: Int, members: [Int]) -> FolderEntry {
        FolderEntry(id: FolderID(uuid: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!),
                    title: "Folder \(n)", members: members.map { appID($0) })
    }

    // MARK: - 激活分流（folder 打开 / app 启动 / 成员启动；ADR-008 §2.2）

    func testActivationRoutingFolderOpensNotLaunches() {
        let folder = folderEntry(1, members: [1, 2, 3])
        XCTAssertEqual(ActivationRouter.decide(for: .folder(folder)), .openFolder)
        XCTAssertEqual(ActivationRouter.decide(for: TopLevelEntryIdentity.folder(folder.id)), .openFolder)
    }

    func testActivationRoutingAppLaunches() {
        XCTAssertEqual(ActivationRouter.decide(for: .app(record(1))), .launchApp)
        XCTAssertEqual(ActivationRouter.decide(for: TopLevelEntryIdentity.app(appID(1))), .launchApp)
    }

    func testActivationRoutingMemberLaunches() {
        // 成员是 AppID → 走既有启动管线（folder 身份绝不路由到 launch）。
        XCTAssertEqual(ActivationRouter.decide(for: TopLevelEntryIdentity.app(appID(5))), .launchApp)
    }

    func testActivationRoutingNilRejects() {
        XCTAssertEqual(ActivationRouter.decide(for: TopLevelEntryIdentity?.none), .reject)
    }

    // MARK: - FolderInnerNavigator：四方向 + 跨页 + 边界

    func testInnerRightMovesWithinRow() {
        let nav = FolderInnerNavigator(columns: 5, membersPerPage: 35)
        let move = nav.move(currentIndex: 0, memberCount: 40, direction: .right)
        XCTAssertEqual(move, FolderInnerNavigator.Move(memberIndex: 1, crossedPage: false))
    }

    func testInnerRightCrossesPageAtRowBoundary() {
        let nav = FolderInnerNavigator(columns: 5, membersPerPage: 35)
        // index 34 = 第 0 页第 5 行末格（slot 34 % 5 = 4）→ 跨页到第 1 页首格（index 35）。
        let move = nav.move(currentIndex: 34, memberCount: 40, direction: .right)
        XCTAssertEqual(move, FolderInnerNavigator.Move(memberIndex: 35, crossedPage: true))
    }

    func testInnerRightNoWrapAtLastPage() {
        let nav = FolderInnerNavigator(columns: 5, membersPerPage: 35)
        // index 39 = 末页末格 → 无环绕。
        XCTAssertNil(nav.move(currentIndex: 39, memberCount: 40, direction: .right))
    }

    func testInnerLeftMovesWithinRow() {
        let nav = FolderInnerNavigator(columns: 5, membersPerPage: 35)
        let move = nav.move(currentIndex: 1, memberCount: 40, direction: .left)
        XCTAssertEqual(move, FolderInnerNavigator.Move(memberIndex: 0, crossedPage: false))
    }

    func testInnerLeftCrossesPageToPreviousLastSlot() {
        let nav = FolderInnerNavigator(columns: 5, membersPerPage: 35)
        // index 35 = 第 1 页首格 → 跨页到第 0 页末格（index 34）。
        let move = nav.move(currentIndex: 35, memberCount: 40, direction: .left)
        XCTAssertEqual(move, FolderInnerNavigator.Move(memberIndex: 34, crossedPage: true))
    }

    func testInnerLeftNoWrapAtFirstPage() {
        let nav = FolderInnerNavigator(columns: 5, membersPerPage: 35)
        XCTAssertNil(nav.move(currentIndex: 0, memberCount: 40, direction: .left))
    }

    func testInnerDownMovesSameColumn() {
        let nav = FolderInnerNavigator(columns: 5, membersPerPage: 35)
        let move = nav.move(currentIndex: 0, memberCount: 40, direction: .down)
        XCTAssertEqual(move, FolderInnerNavigator.Move(memberIndex: 5, crossedPage: false))
    }

    func testInnerDownWrapsAtColumnBottom() {
        let nav = FolderInnerNavigator(columns: 5, membersPerPage: 35)
        // 列底 → 下一列第一个（同页）：index 30 = 第 0 页第 0 列底 → 第 1 列第一个（index 1）。
        let wrap = nav.move(currentIndex: 30, memberCount: 40, direction: .down)
        XCTAssertEqual(wrap, FolderInnerNavigator.Move(memberIndex: 1, crossedPage: false))
        // 末列底 → 下一页首格（crossedPage: true）：index 34 = 第 0 页末列底 → 第 1 页首格（index 35）。
        let cross = nav.move(currentIndex: 34, memberCount: 40, direction: .down)
        XCTAssertEqual(cross, FolderInnerNavigator.Move(memberIndex: 35, crossedPage: true))
        // 末页 → nil：index 39 = 末页末列底，无下一页。
        XCTAssertNil(nav.move(currentIndex: 39, memberCount: 40, direction: .down))
    }

    func testInnerUpMovesSameColumn() {
        let nav = FolderInnerNavigator(columns: 5, membersPerPage: 35)
        let move = nav.move(currentIndex: 5, memberCount: 40, direction: .up)
        XCTAssertEqual(move, FolderInnerNavigator.Move(memberIndex: 0, crossedPage: false))
    }

    func testInnerUpWrapsAtColumnTop() {
        let nav = FolderInnerNavigator(columns: 5, membersPerPage: 35)
        // 列顶 → 上一列最后一个（同页）：index 1 = 第 0 页第 1 列顶 → 第 0 列最后一个（index 30）。
        let wrap = nav.move(currentIndex: 1, memberCount: 40, direction: .up)
        XCTAssertEqual(wrap, FolderInnerNavigator.Move(memberIndex: 30, crossedPage: false))
        // 首列顶 → 上一页末格（crossedPage: true）：index 35 = 第 1 页首列顶 → 第 0 页末格（index 34）。
        let cross = nav.move(currentIndex: 35, memberCount: 40, direction: .up)
        XCTAssertEqual(cross, FolderInnerNavigator.Move(memberIndex: 34, crossedPage: true))
        // 首页 → nil：index 0 = 首页首列顶。
        XCTAssertNil(nav.move(currentIndex: 0, memberCount: 40, direction: .up))
    }

    func testInnerPartialPageColumnWrap() {
        // 部分页（8 成员 5 列，单页）：列底/列顶环绕在部分页内仍正确。
        let nav = FolderInnerNavigator(columns: 5, membersPerPage: 35)
        // 列底 → 下一列第一个：index 5（第 0 列底）→ 1；index 7（第 2 列底）→ 3。
        XCTAssertEqual(nav.move(currentIndex: 5, memberCount: 8, direction: .down),
                       FolderInnerNavigator.Move(memberIndex: 1, crossedPage: false))
        XCTAssertEqual(nav.move(currentIndex: 7, memberCount: 8, direction: .down),
                       FolderInnerNavigator.Move(memberIndex: 3, crossedPage: false))
        // 末列底（index 4，第 4 列）→ 无下一页 → nil。
        XCTAssertNil(nav.move(currentIndex: 4, memberCount: 8, direction: .down))
        // 列顶 → 上一列最后一个：index 1（第 1 列顶）→ 5；index 3（第 3 列顶）→ 7。
        XCTAssertEqual(nav.move(currentIndex: 1, memberCount: 8, direction: .up),
                       FolderInnerNavigator.Move(memberIndex: 5, crossedPage: false))
        XCTAssertEqual(nav.move(currentIndex: 3, memberCount: 8, direction: .up),
                       FolderInnerNavigator.Move(memberIndex: 7, crossedPage: false))
        // 首页首列顶 → nil。
        XCTAssertNil(nav.move(currentIndex: 0, memberCount: 8, direction: .up))
    }

    func testInnerDownUpCrossPageKeepsFocusPageConsistent() {
        // 跨页后 memberIndex 落在新页首格/末格，页 = index / membersPerPage 与 crossedPage 一致。
        let nav = FolderInnerNavigator(columns: 5, membersPerPage: 35)
        let down = nav.move(currentIndex: 34, memberCount: 40, direction: .down)!
        XCTAssertEqual(down.memberIndex / 35, 1)   // 新页 = 1
        XCTAssertEqual(down.memberIndex % 35, 0)   // 新页首格
        let up = nav.move(currentIndex: 35, memberCount: 40, direction: .up)!
        XCTAssertEqual(up.memberIndex / 35, 0)     // 新页 = 0
        XCTAssertEqual(up.memberIndex % 35, 34)    // 新页末格
    }

    func testInnerInvalidIndexReturnsNil() {
        let nav = FolderInnerNavigator(columns: 5, membersPerPage: 35)
        XCTAssertNil(nav.move(currentIndex: 40, memberCount: 40, direction: .right))
        XCTAssertNil(nav.move(currentIndex: -1, memberCount: 40, direction: .right))
        XCTAssertNil(nav.move(currentIndex: 0, memberCount: 0, direction: .right))
    }

    func testInnerCrossPageKeepsFocusPageConsistent() {
        // 跨页后 memberIndex 落在新页首格/末格，页 = index / membersPerPage 一致。
        let nav = FolderInnerNavigator(columns: 5, membersPerPage: 35)
        let right = nav.move(currentIndex: 34, memberCount: 40, direction: .right)!
        XCTAssertEqual(right.memberIndex / 35, 1)   // 新页 = 1
        XCTAssertEqual(right.memberIndex % 35, 0)   // 新页首格
        let left = nav.move(currentIndex: 35, memberCount: 40, direction: .left)!
        XCTAssertEqual(left.memberIndex / 35, 0)    // 新页 = 0
        XCTAssertEqual(left.memberIndex % 35, 34)   // 新页末格
    }

    // MARK: - FolderKeyboardPriority：ESC 优先级

    func testEscPriorityTitleEditFirst() {
        XCTAssertEqual(FolderKeyboardPriority.escAction(editingTitle: true, folderOpen: true),
                       .cancelTitleEdit)
        XCTAssertEqual(FolderKeyboardPriority.escAction(editingTitle: true, folderOpen: false),
                       .cancelTitleEdit)
    }

    func testEscPriorityFolderOpenSecond() {
        XCTAssertEqual(FolderKeyboardPriority.escAction(editingTitle: false, folderOpen: true),
                       .closeFolder)
    }

    func testEscPriorityTopLevelLast() {
        XCTAssertEqual(FolderKeyboardPriority.escAction(editingTitle: false, folderOpen: false),
                       .clearGridSelection)
    }

    // MARK: - FolderKeyboardPriority：Command-F

    func testCommandFClosesFolderThenSearch() {
        XCTAssertEqual(FolderKeyboardPriority.commandFAction(folderOpen: true), .closeFolderThenSearch)
    }

    func testCommandFDirectSearchWhenClosed() {
        XCTAssertEqual(FolderKeyboardPriority.commandFAction(folderOpen: false), .search)
    }

    // MARK: - T-1E-D repair：folder 关闭复位标题编辑（stale isEditingTitle 回归）

    func testCommandFDuringTitleEditingResetsEditingFlag() {
        // 场景：folder 打开 + 标题编辑中 → Command-F → .closeFolderThenSearch。
        let action = FolderKeyboardPriority.commandFAction(folderOpen: true)
        XCTAssertEqual(action, .closeFolderThenSearch)
        // folder 关闭动作必须结束标题编辑（修复 stale isEditingTitle）。
        let editingAfterClose = FolderKeyboardPriority.nextEditingState(editingTitle: true, action: action)
        XCTAssertFalse(editingAfterClose, "Command-F 关闭 folder 后 isEditingTitle 必须复位")
        // 搜索退出后键盘控制器重获 first responder：编辑标志已复位 → 不再 fall through 到 super。
        // 顶层（folder 已关）ESC 走清除网格选择，箭头/Return 走顶层导航/激活分流。
        XCTAssertEqual(FolderKeyboardPriority.escAction(editingTitle: editingAfterClose, folderOpen: false),
                       .clearGridSelection)
    }

    func testAllFolderCloseActionsResetTitleEditing() {
        // ESC 关闭 folder 与 Command-F 关闭 folder 都结束标题编辑（单一事实源 closeFolder）。
        XCTAssertFalse(FolderKeyboardPriority.nextEditingState(editingTitle: true, action: .closeFolder))
        XCTAssertFalse(FolderKeyboardPriority.nextEditingState(editingTitle: true, action: .closeFolderThenSearch))
        // 取消编辑同样复位。
        XCTAssertFalse(FolderKeyboardPriority.nextEditingState(editingTitle: true, action: .cancelTitleEdit))
    }

    func testNonFolderCloseActionsPreserveEditingState() {
        // 清除网格选择 / 直接搜索不改变编辑状态。
        XCTAssertTrue(FolderKeyboardPriority.nextEditingState(editingTitle: true, action: .clearGridSelection))
        XCTAssertTrue(FolderKeyboardPriority.nextEditingState(editingTitle: true, action: .search))
        XCTAssertFalse(FolderKeyboardPriority.nextEditingState(editingTitle: false, action: .search))
    }

    // MARK: - FolderFocusRestore

    func testRestoreLocatesFolderEntry() {
        let folder = folderEntry(1, members: [1, 2, 3])
        let entries: [TopLevelEntry] = [.folder(folder), .app(record(4)), .app(record(5))]
        let target = FolderFocusRestore.restoreTarget(
            folderIdentity: .folder(folder.id), in: entries, itemsPerPage: 35, revision: 7)
        XCTAssertEqual(target?.catalogRevision, 7)
        XCTAssertEqual(target?.pageIndex, 0)
        XCTAssertEqual(target?.slotIndex, 0)
        XCTAssertEqual(target?.entryIdentity, .folder(folder.id))
    }

    func testRestoreFolderOnLaterPage() {
        let folder = folderEntry(1, members: [1, 2, 3])
        // folder 在第 2 个槽位（itemsPerPage=2 → 第 1 页第 0 槽）。
        let entries: [TopLevelEntry] = [.app(record(4)), .app(record(5)), .folder(folder)]
        let target = FolderFocusRestore.restoreTarget(
            folderIdentity: .folder(folder.id), in: entries, itemsPerPage: 2, revision: 7)
        XCTAssertEqual(target?.pageIndex, 1)
        XCTAssertEqual(target?.slotIndex, 0)
        XCTAssertEqual(target?.entryIdentity, .folder(folder.id))
    }

    func testRestoreFallsBackWhenFolderVanished() {
        // folder 已消失（解散/移除）→ 回退到组合首条目。
        let entries: [TopLevelEntry] = [.app(record(4)), .app(record(5))]
        let target = FolderFocusRestore.restoreTarget(
            folderIdentity: .folder(FolderID()), in: entries, itemsPerPage: 35, revision: 7)
        XCTAssertEqual(target?.pageIndex, 0)
        XCTAssertEqual(target?.slotIndex, 0)
        XCTAssertEqual(target?.entryIdentity, .app(appID(4)))
    }

    func testRestoreEmptyCompositionReturnsNil() {
        XCTAssertNil(FolderFocusRestore.restoreTarget(
            folderIdentity: .folder(FolderID()), in: [], itemsPerPage: 35, revision: 7))
    }

    func testRestoreNilFolderIdentityFallsBack() {
        let entries: [TopLevelEntry] = [.app(record(4))]
        let target = FolderFocusRestore.restoreTarget(
            folderIdentity: nil, in: entries, itemsPerPage: 35, revision: 7)
        XCTAssertEqual(target?.entryIdentity, .app(appID(4)))
    }

    // MARK: - FolderTitleEditing

    func testTitleEnterCommitsNormalized() {
        XCTAssertEqual(FolderTitleEditing.resolve(commit: true, cancel: false, focusLoss: false,
                                                  raw: "  My Folder  ", fallback: "Group 1"),
                       .commit("My Folder"))
    }

    func testTitleEscapeCancels() {
        XCTAssertEqual(FolderTitleEditing.resolve(commit: false, cancel: true, focusLoss: false,
                                                  raw: "My Folder", fallback: "Group 1"),
                       .cancel)
    }

    func testTitleFocusLossCommitsDeterministically() {
        XCTAssertEqual(FolderTitleEditing.resolve(commit: false, cancel: false, focusLoss: true,
                                                  raw: "My Folder", fallback: "Group 1"),
                       .commit("My Folder"))
    }

    func testTitleBlankFallsBack() {
        XCTAssertEqual(FolderTitleEditing.resolve(commit: true, cancel: false, focusLoss: false,
                                                  raw: "   ", fallback: "Group 1"),
                       .commit("Group 1"))
    }

    func testTitleTruncatesToMaxLength() {
        let long = String(repeating: "a", count: 200)
        let result = FolderTitleEditing.resolve(commit: true, cancel: false, focusLoss: false,
                                                raw: long, fallback: "Group 1")
        guard case .commit(let title) = result else { return XCTFail("应提交") }
        XCTAssertEqual(title.count, FolderTitle.maxLength)
    }

    func testTitleCancelTakesPriorityOverCommit() {
        XCTAssertEqual(FolderTitleEditing.resolve(commit: true, cancel: true, focusLoss: false,
                                                  raw: "My Folder", fallback: "Group 1"),
                       .cancel)
    }
}
