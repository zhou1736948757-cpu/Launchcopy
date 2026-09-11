// AppGridUI — FolderKeyboardLogic（Phase 1E §3.1D 键盘/焦点/标题编辑纯逻辑；ADR-008 §3 Q10/Q11）
// 实现：T-1E-D（Worker D）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 纯 Foundation 值类型，无 AppKit / I/O / 磁盘持久化 / 本机依赖。
//
// 内容：
// - `FolderInnerNavigator`：folder 打开时成员网格四方向导航 + 内部分页跨页（焦点/页一致）。
// - `FolderKeyboardPriority`：ESC 优先级（编辑标题 → 关闭 folder → 清除网格选择）与
//   Command-F（folder 打开 → 先安全关闭再搜索）。
// - `FolderFocusRestore`：关闭 folder 后焦点恢复到 folder 条目；folder 消失 → 确定性回退。
// - `FolderTitleEditing`：标题编辑结束语义（Enter 提交 / Escape 取消 / focus-loss 确定性提交）
//   + 规范化（复用 `FolderTitle.normalized`：空白回退 / 长度上限 / Unicode 安全）。
//
// 隐私硬边界：folder title / membership / identity 原值绝不进入 telemetry/JSONL/stdout/
// signpost/profile/report；仅中性计数与决策枚举。标题文本绝不落盘。

import AppCatalogCore
import Foundation

// MARK: - 内部成员导航（folder 打开时成员网格焦点移动 + 跨页）

/// 内部成员网格导航：基于完整成员列表（全局 index），页由 `index / membersPerPage` 推导。
///
/// 语义（镜像 `AppGridFocusNavigator` 的边界/跨页策略，ADR-006；T-1E 打字机环绕）：
/// - ←/→ 行内移动；到行边界 → 切换相邻页（右 → 下一页首格；左 → 上一页末格）；
/// - ↓ 列内下移；列底 → 下一列第一个（同页）；末列底 → 下一页首格（crossedPage: true）；末页 → nil；
/// - ↑ 列内上移；列顶 → 上一列最后一个（同页）；首列顶 → 上一页末格（crossedPage: true）；首页 → nil；
/// - 全局边界不环绕：末页最右/最下、首页最左/最上 → 不移动（nil）。
public struct FolderInnerNavigator: Sendable {
    public let columns: Int
    public let membersPerPage: Int

    public init(columns: Int, membersPerPage: Int) {
        precondition(columns > 0, "columns 必须 > 0")
        precondition(membersPerPage > 0, "membersPerPage 必须 > 0")
        self.columns = columns
        self.membersPerPage = membersPerPage
    }

    /// 移动结果：全局成员 index + 是否跨页。
    public struct Move: Equatable, Sendable {
        public let memberIndex: Int
        public let crossedPage: Bool
        public init(memberIndex: Int, crossedPage: Bool) {
            self.memberIndex = memberIndex
            self.crossedPage = crossedPage
        }
    }

    /// 在成员网格内移动。`memberCount` = 打开 folder 的成员总数。
    /// 返回 nil = 无法移动（边界 / 无效 index）。
    public func move(currentIndex: Int, memberCount: Int, direction: AppGridFocusDirection) -> Move? {
        guard memberCount > 0, currentIndex >= 0, currentIndex < memberCount else { return nil }
        let page = currentIndex / membersPerPage
        let slot = currentIndex % membersPerPage
        let pageStart = page * membersPerPage
        let pageEnd = min(pageStart + membersPerPage, memberCount)
        let pageSlots = pageEnd - pageStart

        switch direction {
        case .right:
            if slot + 1 < pageSlots {
                return Move(memberIndex: currentIndex + 1, crossedPage: false)
            }
            // 行边界 → 下一页首格（无环绕）。
            let nextPageStart = pageEnd
            guard nextPageStart < memberCount else { return nil }
            return Move(memberIndex: nextPageStart, crossedPage: true)
        case .left:
            if slot - 1 >= 0 {
                return Move(memberIndex: currentIndex - 1, crossedPage: false)
            }
            // 行边界 → 上一页末格（无环绕）。
            guard page > 0 else { return nil }
            let prevPageStart = (page - 1) * membersPerPage
            let prevPageEnd = min(prevPageStart + membersPerPage, memberCount)
            return Move(memberIndex: prevPageEnd - 1, crossedPage: true)
        case .down:
            let next = currentIndex + columns
            if next < pageEnd {
                return Move(memberIndex: next, crossedPage: false)
            }
            // 列底：下一列第一个（同页）；末列底 → 下一页首格（crossedPage: true）；末页 → nil。
            let col = slot % columns
            if col + 1 < columns, pageStart + col + 1 < pageEnd {
                return Move(memberIndex: pageStart + col + 1, crossedPage: false)
            }
            guard pageEnd < memberCount else { return nil }
            return Move(memberIndex: pageEnd, crossedPage: true)
        case .up:
            let prev = currentIndex - columns
            if prev >= pageStart {
                return Move(memberIndex: prev, crossedPage: false)
            }
            // 列顶：上一列最后一个（同页）；首列顶 → 上一页末格（crossedPage: true）；首页 → nil。
            let col = slot % columns
            if col > 0 {
                // 上一列最后一个 = 页内最大 slot s（pageStart <= s < pageEnd 且 s % columns == col - 1）。
                var s = pageEnd - 1
                while s >= pageStart && s % columns != col - 1 { s -= 1 }
                if s >= pageStart {
                    return Move(memberIndex: s, crossedPage: false)
                }
            }
            guard page > 0 else { return nil }
            let prevPageStart = (page - 1) * membersPerPage
            let prevPageEnd = min(prevPageStart + membersPerPage, memberCount)
            return Move(memberIndex: prevPageEnd - 1, crossedPage: true)
        }
    }
}

// MARK: - 键盘优先级（ESC / Command-F）

/// 键盘动作（中性决策枚举；不含任何身份/标题原文）。
public enum FolderKeyboardAction: Equatable, Sendable {
    case cancelTitleEdit
    case closeFolder
    case clearGridSelection
    case closeFolderThenSearch
    case search
}

/// ESC / Command-F 优先级决策（ADR-008 §3 Q10 / §8.1 输入优先级）。
public enum FolderKeyboardPriority {
    /// ESC 优先级：编辑标题 → 取消/结束编辑；folder 打开 → 关闭 folder；否则 → 清除网格选择。
    public static func escAction(editingTitle: Bool, folderOpen: Bool) -> FolderKeyboardAction {
        if editingTitle { return .cancelTitleEdit }
        if folderOpen { return .closeFolder }
        return .clearGridSelection
    }

    /// Command-F：folder 打开 → 先安全关闭 folder 再进入全局搜索；否则直接搜索。
    public static func commandFAction(folderOpen: Bool) -> FolderKeyboardAction {
        folderOpen ? .closeFolderThenSearch : .search
    }

    /// 标题编辑状态在动作后的结果（ADR-008 §3 Q11；T-1E-D repair）。
    ///
    /// folder 关闭类动作（`.closeFolder` / `.closeFolderThenSearch`）与取消编辑
    /// （`.cancelTitleEdit`）都会结束标题编辑（→ false），保证任何 folder 关闭路径
    /// 都不残留 stale `isEditingTitle`——否则 Command-F 在标题编辑中关闭 folder 后，
    /// 搜索退出、键盘控制器重获 first responder 时箭头/Return 仍被吞掉（导航死锁）。
    /// 其余动作（`.clearGridSelection` / `.search`）不改变编辑状态。
    public static func nextEditingState(editingTitle: Bool, action: FolderKeyboardAction) -> Bool {
        switch action {
        case .closeFolder, .closeFolderThenSearch, .cancelTitleEdit:
            return false
        case .clearGridSelection, .search:
            return editingTitle
        }
    }
}

// MARK: - 关闭 folder 后焦点恢复

/// 关闭 folder 后焦点恢复到 folder 条目；folder 消失 → 确定性回退（ADR-008 §3 Q10）。
public enum FolderFocusRestore {
    /// 在顶层组合中定位条目身份 → (page, slot)；不存在 → nil。
    public static func position(of identity: TopLevelEntryIdentity,
                                in entries: [TopLevelEntry],
                                itemsPerPage: Int) -> (page: Int, slot: Int)? {
        guard itemsPerPage > 0 else { return nil }
        guard let index = entries.firstIndex(where: { $0.identity == identity }) else { return nil }
        return (index / itemsPerPage, index % itemsPerPage)
    }

    /// 关闭 folder 后恢复焦点目标：
    /// - folder 条目仍存在 → 定位到它（绝不沿用旧 index）；
    /// - folder 消失（解散/移除）→ 回退到组合首条目（确定性）。
    /// 空组合 → nil（无焦点）。
    public static func restoreTarget(folderIdentity: TopLevelEntryIdentity?,
                                     in entries: [TopLevelEntry],
                                     itemsPerPage: Int,
                                     revision: UInt64) -> AppGridFocusIdentity? {
        if let folderIdentity,
           let pos = position(of: folderIdentity, in: entries, itemsPerPage: itemsPerPage) {
            return AppGridFocusIdentity(catalogRevision: revision, pageIndex: pos.page,
                                        slotIndex: pos.slot, entryIdentity: folderIdentity)
        }
        guard let first = entries.first, let id = first.identity else { return nil }
        return AppGridFocusIdentity(catalogRevision: revision, pageIndex: 0, slotIndex: 0,
                                    entryIdentity: id)
    }
}

// MARK: - 标题编辑结束语义

/// 标题编辑结束语义（ADR-008 §3 Q11）：Enter 提交 / Escape 取消 / focus-loss 确定性提交。
///
/// 规范化复用 `FolderTitle.normalized`（trim / 空白回退 / 64-Character 上限 / Unicode 安全）。
/// 标题文本绝不进入 telemetry/JSONL/stdout/signpost/profile/report，绝不落盘。
public enum FolderTitleEditing {
    /// 编辑结束结果。
    public enum Outcome: Equatable, Sendable {
        case commit(String)   // 规范化后的标题
        case cancel
    }

    /// 解析编辑结束：
    /// - `cancel`（Escape）→ `.cancel`（优先）；
    /// - `commit`（Enter）或 `focusLoss` → `.commit(normalized)`（确定性）；
    /// - 否则 → `.cancel`（防御性，不应发生）。
    public static func resolve(commit: Bool, cancel: Bool, focusLoss: Bool,
                               raw: String, fallback: String) -> Outcome {
        if cancel { return .cancel }
        if commit || focusLoss {
            return .commit(FolderTitle.normalized(raw, fallback: fallback))
        }
        return .cancel
    }
}
