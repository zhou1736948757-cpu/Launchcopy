// AppGridUI — AppGridFocusIdentity（Phase 1C §3.1 焦点身份；revision-stable）
// 实现：T-1C-A（Worker A）。纯逻辑，无 AppKit 依赖。
// Phase 1E 泛化（T-1E-A）：焦点身份从"仅 app"泛化为"中性顶层条目身份"（app 或 folder），
// 保持 app 行为向后兼容（appID 计算属性 + appID 构造仍可用）。
//
// 焦点身份 revision-stable：携带 catalogRevision + 中性条目身份 + presentation identity，
// 可回答"当前聚焦哪一页/哪个有效 item、属于哪个 snapshot revision、刷新/复用后是否仍有效"。
// 与 ItemBindingToken 对齐：catalogRevision / pageIdentity（PagePresentationID）/ 条目身份。
// 隐私：不记录 app 名 / bundle ID 原文 / 路径 / URL / 图标数据 / folder 标题（身份不透明）。

import AppCatalogCore
import Foundation
import PagingUI

/// 键盘焦点身份（revision-stable 值类型）。
///
/// - `catalogRevision` 与 `presentationID.revision` 必须一致（同一内容基线）。
/// - `entryIdentity` 为 nil 表示中性占位（不可启动）；正常焦点恒为有效可启动 app 或可打开 folder。
/// - `appID` 为向后兼容计算属性：仅当 `entryIdentity == .app(id)` 时返回 id；folder/占位 → nil。
public struct AppGridFocusIdentity: Hashable, Equatable, Sendable {
    public let catalogRevision: UInt64
    public let pageIndex: Int
    public let slotIndex: Int
    public let presentationID: PagePresentationID
    /// 中性顶层条目身份（app 或 folder）；nil = 中性占位。
    public let entryIdentity: TopLevelEntryIdentity?

    /// 向后兼容：app 身份（`entryIdentity == .app(id)` 时返回 id；folder/占位 → nil）。
    public var appID: AppID? {
        if case .app(let id)? = entryIdentity { return id }
        return nil
    }

    /// 向后兼容构造：app 身份（presentationID 由 revision + pageIndex 派生）。
    public init(catalogRevision: UInt64,
                pageIndex: Int,
                slotIndex: Int,
                appID: AppID?,
                presentationID: PagePresentationID) {
        self.catalogRevision = catalogRevision
        self.pageIndex = pageIndex
        self.slotIndex = slotIndex
        self.presentationID = presentationID
        self.entryIdentity = appID.map { .app($0) }
    }

    /// 向后兼容便捷构造：presentationID 由 revision + pageIndex 派生（保证与 catalogRevision 一致）。
    public init(catalogRevision: UInt64, pageIndex: Int, slotIndex: Int, appID: AppID?) {
        self.init(catalogRevision: catalogRevision,
                  pageIndex: pageIndex,
                  slotIndex: slotIndex,
                  appID: appID,
                  presentationID: PagePresentationID(revision: catalogRevision, pageIndex: pageIndex))
    }

    /// 中性条目身份构造（app 或 folder；presentationID 由 revision + pageIndex 派生）。
    public init(catalogRevision: UInt64,
                pageIndex: Int,
                slotIndex: Int,
                entryIdentity: TopLevelEntryIdentity?,
                presentationID: PagePresentationID) {
        self.catalogRevision = catalogRevision
        self.pageIndex = pageIndex
        self.slotIndex = slotIndex
        self.presentationID = presentationID
        self.entryIdentity = entryIdentity
    }

    /// 中性条目身份便捷构造：presentationID 由 revision + pageIndex 派生。
    public init(catalogRevision: UInt64, pageIndex: Int, slotIndex: Int, entryIdentity: TopLevelEntryIdentity?) {
        self.init(catalogRevision: catalogRevision,
                  pageIndex: pageIndex,
                  slotIndex: slotIndex,
                  entryIdentity: entryIdentity,
                  presentationID: PagePresentationID(revision: catalogRevision, pageIndex: pageIndex))
    }
}
