// AppGridUI — AppGridFocusNavigator（Phase 1C §3.3 方向键导航）
// 实现：T-1C-A（Worker A）。纯逻辑，无 AppKit 依赖。
//
// 行列从 itemsPerPage + 有效 item 数推导（columns 为布局参数，不硬编码 5×7）。
// 边界/跨页策略（文档化，ADR-006；T-1E 打字机环绕）：
// - → 行内右移；行末 → 下一行第一个（同页）；末行末 → 下一页首格；末页 → nil；
// - ← 行内左移；行首 → 上一行最后一个（同页）；首行首 → 上一页末格；首页 → nil；
// - ↓ 列内下移；列底 → 下一列第一个（同页）；末列底 → 下一页首格；末页 → nil；
// - ↑ 列内上移；列顶 → 上一列最后一个（同页）；首列顶 → 上一页末格；首页 → nil；
// - 全局边界不环绕：末页最右/最下、首页最左/最上 → 不移动（nil）。

import AppCatalogCore
import Foundation
import PagingUI

public enum AppGridFocusDirection: Equatable, Sendable {
    case left, right, up, down
}

/// 纯方向键网格导航器。
public struct AppGridFocusNavigator: Sendable {
    public let columns: Int

    public init(columns: Int) {
        precondition(columns > 0, "columns 必须 > 0")
        self.columns = columns
    }

    /// 方向键移动。返回目标焦点身份；无法移动（边界/无效/stale）返回 nil。
    public func move(_ identity: AppGridFocusIdentity,
                     direction: AppGridFocusDirection,
                     in layout: AppGridFocusLayout) -> AppGridFocusIdentity? {
        // stale / 无效守卫：revision 不匹配或当前 cell 无效 → 不导航。
        // 按中性条目身份比对（T-1E：folder 身份不被 validAppID 误拦）。
        guard identity.catalogRevision == layout.revision,
              layout.validEntry(page: identity.pageIndex, slot: identity.slotIndex) == identity.entryIdentity else {
            return nil
        }
        let page = identity.pageIndex
        let slot = identity.slotIndex
        let row = slot / columns
        let col = slot % columns
        let slots = layout.validSlots(on: page)

        switch direction {
        case .right:
            if let next = slots.first(where: { $0 > slot && $0 / columns == row }) {
                return makeIdentity(layout, page: page, slot: next)
            }
            // 行末 → 下一行第一个（同页）。
            if let next = slots.first(where: { $0 / columns == row + 1 }) {
                return makeIdentity(layout, page: page, slot: next)
            }
            // 末行末 → 下一页首格；末页 → nil。
            return crossPageRight(layout, from: page)
        case .left:
            if let prev = slots.last(where: { $0 < slot && $0 / columns == row }) {
                return makeIdentity(layout, page: page, slot: prev)
            }
            // 行首 → 上一行最后一个（同页）。
            if let prev = slots.last(where: { $0 / columns == row - 1 }) {
                return makeIdentity(layout, page: page, slot: prev)
            }
            // 首行首 → 上一页末格；首页 → nil。
            return crossPageLeft(layout, from: page)
        case .down:
            if let next = slots.first(where: { $0 > slot && $0 % columns == col }) {
                return makeIdentity(layout, page: page, slot: next)
            }
            // 列底 → 下一列第一个（同页）。
            if let next = slots.first(where: { $0 % columns == col + 1 }) {
                return makeIdentity(layout, page: page, slot: next)
            }
            // 末列底 → 下一页首格；末页 → nil。
            return crossPageRight(layout, from: page)
        case .up:
            if let prev = slots.last(where: { $0 < slot && $0 % columns == col }) {
                return makeIdentity(layout, page: page, slot: prev)
            }
            // 列顶 → 上一列最后一个（同页）。
            if let prev = slots.last(where: { $0 % columns == col - 1 }) {
                return makeIdentity(layout, page: page, slot: prev)
            }
            // 首列顶 → 上一页末格；首页 → nil。
            return crossPageLeft(layout, from: page)
        }
    }

    private func makeIdentity(_ layout: AppGridFocusLayout, page: Int, slot: Int) -> AppGridFocusIdentity? {
        guard let entry = layout.validEntry(page: page, slot: slot) else { return nil }
        return AppGridFocusIdentity(catalogRevision: layout.revision, pageIndex: page,
                                    slotIndex: slot, entryIdentity: entry)
    }

    /// 跨页右移：下一页首个有效 slot（打字机语义；末页 → nil）。
    private func crossPageRight(_ layout: AppGridFocusLayout, from page: Int) -> AppGridFocusIdentity? {
        let next = page + 1
        guard next < layout.pageCount else { return nil }
        guard let first = layout.validSlots(on: next).first else { return nil }
        return makeIdentity(layout, page: next, slot: first)
    }

    /// 跨页左移：上一页末个有效 slot（打字机语义；首页 → nil）。
    private func crossPageLeft(_ layout: AppGridFocusLayout, from page: Int) -> AppGridFocusIdentity? {
        let prev = page - 1
        guard prev >= 0 else { return nil }
        guard let last = layout.validSlots(on: prev).last else { return nil }
        return makeIdentity(layout, page: prev, slot: last)
    }
}
