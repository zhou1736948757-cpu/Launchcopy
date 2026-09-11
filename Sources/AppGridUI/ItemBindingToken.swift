// AppGridUI — ItemBindingToken（§6.4 七字段 binding token；wave1-interfaces.md §E）
// 实现：T-worker-b-appgridui（Phase 1B Wave 2）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 每个可复用 item/host 的异步写回（图标 apply）前必须校验七字段全匹配且 view 仍有效；
// 只有全部匹配才写回。测试断言：stale async icon apply == 0（§10.5）。
//
// 字段语义：
//   1. catalogRevision   —— 内容所属 catalog revision（UInt64，中性：映射 CatalogRevision.value）
//   2. pageIdentity      —— 页面呈现身份（含 page index；PagePresentationID）
//   3. itemSlot          —— item 槽位（全局槽位 = pageIndex * itemsPerPage + 页内序号）
//   4. appID             —— AppID（Hashable）经 AnyHashable 承载；nil = 中性占位
//   5. reuseGeneration   —— 复用代（PagingSurface 每次 clearForReuse bump，render 携带）
//   6. iconKey           —— IconKey（AppIconPipeline 类型；不含 bundle ID 原文/路径/哈希）
//   7. surfaceGeneration —— 页面视图生命周期代（本视图每次 clearForReuse/render bump）

import AppCatalogCore
import AppIconPipeline
import Foundation
import PagingUI

/// 七字段绑定 token：图标异步写回的唯一资格凭证。
/// Sendable 注：`appID` 为 `AnyHashable?`（承载 AppID），而本 SDK 中 `AnyHashable`
/// 不满足 Sendable → 采用 @unchecked（字段全部不可变值类型；与 AppIconPipeline.IconResult
/// 同一必要偏离模式，满足冻结契约 §E 的 Sendable 要求）。
public struct ItemBindingToken: Equatable, @unchecked Sendable {
    public let catalogRevision: UInt64           // 1. catalogRevision
    public let pageIdentity: PagePresentationID  // 2. page identity（含 page index）
    public let itemSlot: Int                     // 3. item slot
    public let appID: AnyHashable?               // 4. AppID（Hashable）
    public let reuseGeneration: UInt64           // 5. reuseGeneration
    public let iconKey: IconKey?                 // 6. IconKey（AppIconPipeline 类型）
    public let surfaceGeneration: UInt64         // 7. surface lifecycle generation

    public init(catalogRevision: UInt64,
                pageIdentity: PagePresentationID,
                itemSlot: Int,
                appID: AnyHashable?,
                reuseGeneration: UInt64,
                iconKey: IconKey?,
                surfaceGeneration: UInt64) {
        self.catalogRevision = catalogRevision
        self.pageIdentity = pageIdentity
        self.itemSlot = itemSlot
        self.appID = appID
        self.reuseGeneration = reuseGeneration
        self.iconKey = iconKey
        self.surfaceGeneration = surfaceGeneration
    }

    /// 全字段匹配校验（图标异步 apply 前调用；七字段任一不符 → stale，拒绝写回）。
    public func matches(_ other: ItemBindingToken) -> Bool {
        self == other
    }
}
