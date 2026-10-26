// AppGridUI — FolderOpenState（Phase 1E §3.1C 文件夹打开状态 owner；ADR-008 §3 Q1/Q5）
// 实现：T-1E-C（Worker C）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 打开状态 owner：哪个文件夹打开 + 其内部页（session-only，不持久化）。
// - 打开 A 后立即打开 B：generation 递增，A 的旧异步成员图标回调被 generation 门控拒绝
//   （stale defense，ADR-008 §3 Q9）。
// - 内部分页完全独立于外层 PagingCore 状态：本类型只维护 innerPage，绝不驱动/污染外层。
// - 纯逻辑，无 AppKit / I/O / 磁盘持久化 / 本机依赖。
//
// 隐私硬边界：folder title / membership / identity 原值绝不进入 telemetry/JSONL/stdout/
// signpost/profile/report；仅中性计数（memberCount / innerPageCount / generation）。

import AppCatalogCore
import Foundation

/// 文件夹打开状态（session-only，不持久化）：哪个文件夹打开 + 其内部页。
///
/// 引用类型 owner：装配层持有并共享；每次 open/close/setInnerPage 递增 `generation`，
/// 作废在途成员图标异步回调（打开 A 后打开 B，A 的旧回调被 generation 门控拒绝）。
public final class FolderOpenState {

    /// Legacy standalone default; integrated folders use their applied layout capacity.
    public static let defaultMembersPerPage = 35

    /// 当前打开的文件夹条目（nil = 关闭）。
    public private(set) var openEntry: FolderEntry?
    /// 当前内部页（0-based；仅当 isOpen 时有效）。
    public private(set) var innerPage: Int = 0
    /// 打开/关闭/翻页时递增；作废在途成员图标回调（stale defense）。
    public private(set) var generation: UInt64 = 0
    /// 每页成员数（≥1）。
    public private(set) var membersPerPage: Int
    /// Applied folder columns, independent of the outer grid.
    public private(set) var columns: Int
    /// False while useful member geometry cannot be presented safely.
    public private(set) var isMemberPresentationAvailable = true

    public init(membersPerPage: Int = FolderOpenState.defaultMembersPerPage, columns: Int = 5) {
        self.membersPerPage = max(membersPerPage, 1)
        self.columns = max(columns, 1)
    }

    // MARK: - 查询

    public var isOpen: Bool { openEntry != nil }
    public var openFolderID: FolderID? { openEntry?.id }
    public var memberCount: Int { openEntry?.members.count ?? 0 }

    /// 内部页总数（0 = 无成员/未打开）。
    public var innerPageCount: Int {
        guard let entry = openEntry, !entry.members.isEmpty else { return 0 }
        return (entry.members.count - 1) / membersPerPage + 1
    }

    public func isOpen(_ folderID: FolderID) -> Bool { openEntry?.id == folderID }

    /// 指定内部页的成员 AppID 切片（越界 → 空数组）。
    public func members(onPage page: Int) -> [AppID] {
        guard let entry = openEntry, page >= 0, page < innerPageCount else { return [] }
        let start = page * membersPerPage
        let end = start + min(membersPerPage, entry.members.count - start)
        return Array(entry.members[start..<end])
    }

    // MARK: - 变更（均递增 generation）

    /// Atomically replaces the folder presentation snapshot without mutating membership.
    /// A surviving selected anchor wins; otherwise retain the old visible leading member.
    /// Identical normalized snapshots are no-ops, including when given another anchor.
    public func reconfigure(columns: Int, membersPerPage: Int, anchor: AppID?, isAvailable: Bool) {
        let newColumns = max(columns, 1)
        let newCapacity = max(membersPerPage, 1)
        guard self.columns != newColumns || self.membersPerPage != newCapacity ||
                isMemberPresentationAvailable != isAvailable else { return }

        let oldLeadingIndex = innerPage * self.membersPerPage
        let anchorIndex = anchor.flatMap { openEntry?.members.firstIndex(of: $0) }
        let retainedIndex = anchorIndex ?? min(oldLeadingIndex, max(memberCount - 1, 0))

        self.columns = newColumns
        self.membersPerPage = newCapacity
        isMemberPresentationAvailable = isAvailable
        innerPage = min(retainedIndex / newCapacity, max(innerPageCount - 1, 0))
        generation &+= 1
    }

    /// 打开文件夹：重置内部页到 0，递增 generation。
    public func open(_ entry: FolderEntry) {
        openEntry = entry
        innerPage = 0
        generation &+= 1
    }

    /// 就地替换当前打开条目（例如 folder 内 drag commit 后成员重排）。
    /// - 仅当已打开且 `entry.id` 与当前 openFolderID 一致时生效；否则 no-op。
    /// - 保留 `innerPage`（按新成员数 clamp）；递增 generation 作废在途图标回调。
    /// - 与 `open(_:)` 不同：不重置内部页到 0（避免多页 folder 内重排后跳回首页）。
    public func updateOpenEntry(_ entry: FolderEntry) {
        guard isOpen(entry.id) else { return }
        openEntry = entry
        let maxPage = max(innerPageCount - 1, 0)
        if innerPage > maxPage { innerPage = maxPage }
        generation &+= 1
    }

    /// 关闭文件夹（幂等：已关闭时无操作）。
    public func close() {
        guard isOpen else { return }
        openEntry = nil
        innerPage = 0
        generation &+= 1
    }

    /// 设置内部页（clamp 到合法范围；未打开或同页 → 无操作）。
    public func setInnerPage(_ page: Int) {
        guard isOpen else { return }
        let clamped = min(max(page, 0), max(innerPageCount - 1, 0))
        guard clamped != innerPage else { return }
        innerPage = clamped
        generation &+= 1
    }
}
