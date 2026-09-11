// AppGridUI — AppGridFocusLayout（Phase 1C §3.1/§3.3 纯输入网格布局）
// 实现：T-1C-A（Worker A）；T-1E-folder-focus-layout-repair（Worker A）组合化。
//
// 纯输入：pageCount / itemsPerPage / 每页有效身份（仅可启动 app 或可打开 folder；
// placeholder/空 slot 排除）。行列从 itemsPerPage + 有效 item 数推导，不硬编码 5×7。
// 迁移镜像 CatalogPlanner.remap 五级降级（located → successor → predecessor → clamped → emptyCatalog）；
// folder anchor 无 remap 路径（消失 → clamped 首有效，确定性）。
//
// 组合化（ADR-008 §3 Q3）：布局由顶层组合（app + folder）构建，焦点身份携带中性条目身份
// （TopLevelEntryIdentity）；app-only 构建（build(from:itemsPerPage:)）保持向后兼容。

import AppCatalogCore
import Foundation
import PagingUI

/// 纯输入网格布局：描述"哪些 cell 是有效可启动 app / 可打开 folder"。
///
/// 由 `CatalogSnapshot` + 顶层组合 `[TopLevelEntry]` 构建（组合含 app + folder；
/// placeholder/空 slot 天然排除）。行列从 itemsPerPage + 有效 item 数推导。
public struct AppGridFocusLayout: Equatable, Sendable {
    public let snapshot: CatalogSnapshot
    /// 统一顶层组合（app + folder；app-only 构建时 = records.map { .app($0) }）。
    public let entries: [TopLevelEntry]
    public let itemsPerPage: Int

    public init(snapshot: CatalogSnapshot, entries: [TopLevelEntry], itemsPerPage: Int) {
        precondition(itemsPerPage > 0, "itemsPerPage 必须 > 0")
        self.snapshot = snapshot
        self.entries = entries
        self.itemsPerPage = itemsPerPage
    }

    /// 从 CatalogSnapshot + 顶层组合构建布局（app + folder 统一组合）。
    public static func build(from snapshot: CatalogSnapshot, composition: [TopLevelEntry],
                             itemsPerPage: Int) -> AppGridFocusLayout {
        AppGridFocusLayout(snapshot: snapshot, entries: composition, itemsPerPage: itemsPerPage)
    }

    /// 从 CatalogSnapshot 构建布局（app-only 便捷路径：组合 = records.map { .app($0) }）。
    public static func build(from snapshot: CatalogSnapshot, itemsPerPage: Int) -> AppGridFocusLayout {
        AppGridFocusLayout(snapshot: snapshot, entries: snapshot.records.map { .app($0) },
                           itemsPerPage: itemsPerPage)
    }

    public var revision: UInt64 { snapshot.revision.value }
    public var validItemCount: Int { entries.count }
    public var pageCount: Int { validItemCount == 0 ? 0 : (validItemCount + itemsPerPage - 1) / itemsPerPage }

    // MARK: - 每页有效身份（可启动 app 或可打开 folder；placeholder/空 slot 排除）

    /// 页内有效槽位（0-based，升序）。越界/空页返回 []。
    public func validSlots(on page: Int) -> [Int] {
        guard page >= 0, page < pageCount else { return [] }
        let start = page * itemsPerPage
        let end = min(start + itemsPerPage, validItemCount)
        guard start < end else { return [] }
        return Array(start..<end).map { $0 - start }
    }

    /// 页内槽位 → 中性顶层条目身份（app 或 folder）；无效（placeholder/空 slot/越界）返回 nil。
    public func validEntry(page: Int, slot: Int) -> TopLevelEntryIdentity? {
        guard page >= 0, page < pageCount, slot >= 0, slot < itemsPerPage else { return nil }
        let index = page * itemsPerPage + slot
        guard index < validItemCount else { return nil }
        return entries[index].identity
    }

    /// 兼容助手：`validEntry` 的 `.app(id)` case → id；folder/占位 → nil。
    public func validAppID(page: Int, slot: Int) -> AppID? {
        if case .app(let id)? = validEntry(page: page, slot: slot) { return id }
        return nil
    }

    /// 每页有效 app 身份（page → [(slot, appID)]；folder/placeholder/空 slot 排除）。
    public func validIdentities(on page: Int) -> [(slot: Int, appID: AppID)] {
        validSlots(on: page).compactMap { slot in
            validAppID(page: page, slot: slot).map { (slot, $0) }
        }
    }

    // MARK: - 初始焦点 / 定位

    /// 确定性初始焦点：page 0 第一个有效 cell；空组合 → nil。
    public func firstValidIdentity() -> AppGridFocusIdentity? {
        guard pageCount > 0, validItemCount > 0 else { return nil }
        guard let entry = validEntry(page: 0, slot: 0) else { return nil }
        return AppGridFocusIdentity(catalogRevision: revision, pageIndex: 0, slotIndex: 0,
                                    entryIdentity: entry)
    }

    public func contains(_ identity: TopLevelEntryIdentity) -> Bool {
        entries.contains { $0.identity == identity }
    }

    /// 中性条目身份 → (page, slot)；不存在返回 nil。
    /// 按组合 `entries` 搜索（app 在组合中的网格位置含文件夹偏移，不再搜 snapshot.records）。
    public func position(of identity: TopLevelEntryIdentity) -> (page: Int, slot: Int)? {
        guard let index = entries.firstIndex(where: { $0.identity == identity }) else { return nil }
        return (index / itemsPerPage, index % itemsPerPage)
    }

    // MARK: - 行列推导（从 itemsPerPage + 有效 item 数，不硬编码 5×7）

    /// 页内行数 = ceil(有效 item 数 / columns)；空页 → 0。
    public func rowCount(page: Int, columns: Int) -> Int {
        guard columns > 0 else { return 0 }
        let count = validSlots(on: page).count
        return count == 0 ? 0 : (count + columns - 1) / columns
    }

    public func lastValidSlot(on page: Int) -> Int? {
        validSlots(on: page).last
    }

    // MARK: - 迁移（app anchor 镜像 CatalogPlanner.remap 五级降级；folder anchor 确定性 clamped）

    /// 把旧 revision 的焦点身份迁移到本布局（新 revision）。
    ///
    /// 规则（anchor = `identity.entryIdentity`）：
    /// 1. 本布局 revision 不新于身份 → `.unchanged`（旧 revision 永不夺回焦点）；
    /// 2. 空组合 → `.empty`；
    /// 3. anchor 仍存在 → `.located`（定位到新位置，绝不沿用旧 index）；
    /// 4. `.app` anchor 消失 → 委托 `CatalogPlanner.remap` 得 successor/predecessor/clamped 页，
    ///    聚焦该页首个有效 cell（`.located` 定位到 anchor 精确位置）；
    /// 5. `.folder` anchor 消失 → `.clamped(firstValidIdentity())`（确定性；folder 无 remap 路径）；
    /// 6. 无有效 anchor（nil）→ 既有"clamped 首有效"路径。
    public func migrate(identity: AppGridFocusIdentity) -> AppGridFocusMigration {
        // 旧 revision 永不夺回焦点：本布局 revision 不新于身份 → 保持现状。
        if identity.catalogRevision >= revision {
            return .unchanged(identity)
        }
        // 空组合 → empty。
        guard pageCount > 0, validItemCount > 0 else { return .empty }
        // 无有效 anchor → 确定性初始（clamped 到首个有效 cell）。
        guard let anchor = identity.entryIdentity else {
            return firstValidIdentity().map { .clamped($0) } ?? .empty
        }
        switch anchor {
        case .app(let appID):
            // anchor 仍存在 → located（定位到新位置，绝不沿用旧 index）。
            if let pos = position(of: .app(appID)) {
                let target = AppGridFocusIdentity(catalogRevision: revision, pageIndex: pos.page,
                                                  slotIndex: pos.slot, entryIdentity: .app(appID))
                return .located(target)
            }
            // anchor 消失 → 镜像 remap 五级降级（app-only 路径）。
            let planner = CatalogPlanner()
            let (_, outcome) = planner.remap(snapshot: snapshot, anchor: appID, itemsPerPage: itemsPerPage)
            switch outcome {
            case .located(let pageIndex):
                return firstValid(on: pageIndex).map { .located($0) } ?? .empty
            case .successor(let pageIndex):
                return firstValid(on: pageIndex).map { .successor($0) } ?? .empty
            case .predecessor(let pageIndex):
                return firstValid(on: pageIndex).map { .predecessor($0) } ?? .empty
            case .clamped(let pageIndex):
                return firstValid(on: pageIndex).map { .clamped($0) } ?? .empty
            case .emptyCatalog:
                return .empty
            }
        case .folder(let folderID):
            // anchor 仍存在 → located（定位到新位置）。
            if let pos = position(of: .folder(folderID)) {
                let target = AppGridFocusIdentity(catalogRevision: revision, pageIndex: pos.page,
                                                  slotIndex: pos.slot, entryIdentity: .folder(folderID))
                return .located(target)
            }
            // anchor 消失 → 确定性 clamped 到首个有效 cell（folder 无 remap 路径）。
            return firstValidIdentity().map { .clamped($0) } ?? .empty
        }
    }

    private func firstValid(on page: Int) -> AppGridFocusIdentity? {
        guard let slot = validSlots(on: page).first,
              let entry = validEntry(page: page, slot: slot) else { return nil }
        return AppGridFocusIdentity(catalogRevision: revision, pageIndex: page, slotIndex: slot,
                                    entryIdentity: entry)
    }
}
