//
//  PagingPageContent.swift
//  PagingUI
//
//  §E 中性内容承载 seam（Explorer B 合并版，Wave 1 接口冻结草案）。
//
//  seam 单点：PagingSurface.relayoutPages() 内的 host.render(...) / host.clearForReuse()。
//  中性化决策：PagingUI 依赖方向固定为 PagingUI → PagingCore，不得新增对 AppCatalogCore 的
//  依赖 → revision 用不透明 UInt64、item identity 用 AnyHashable；§6.4 七字段 binding token
//  落到 AppGridUI 层（该层拥有 AppID/IconKey）。
//
//  热路径纪律（§5.4/§7）：content(for:itemsPerPage:) 必须同步内存命中——不得同步扫描、
//  读 Bundle、解码图标或等待异步；失败返回 isPlaceholder = true 的中性承载，不阻塞手势。
//  PagingUI 只请求承载，不拥有 scanner/icon loader（§14.A）。
//

import AppKit

/// 页面呈现身份：pageIndex + 内容 revision（不透明；一页所有 item 同 revision，§6.1）。
/// revision 拥有者单一（§H.6）：仅 CatalogRepository 分配；AppGridUI 只消费。
public struct PagePresentationID: Hashable, Sendable {
    /// 内容 revision（中性：AppGridUI 映射 CatalogRevision.value）。
    public let revision: UInt64
    /// 页面索引。
    public let pageIndex: Int

    public init(revision: UInt64, pageIndex: Int) {
        self.revision = revision
        self.pageIndex = pageIndex
    }
}

/// 中性内容条目：PagingUI 不依赖 AppCatalogCore；AppID 经 AnyHashable 承载；nil = 中性占位。
/// Sendable 注：`identity` 为 `AnyHashable?`（承载 AppID），而本 SDK 中 `AnyHashable`
/// 不满足 Sendable → 采用 @unchecked（字段全部不可变值类型；与 AppGridUI.ItemBindingToken
/// 同一必要偏离模式，满足冻结契约 §E 的 Sendable 要求）。
public struct PagingPageContentItem: Equatable, @unchecked Sendable {
    /// 页内槽位（0-based；渲染器按槽位布局）。
    public let slot: Int
    /// 业务身份（AppID Hashable 经 AnyHashable 传入；PagingUI 不解包）。
    public let identity: AnyHashable?
    /// 显示标题（nil = 中性占位 → 渲染器画槽位序号）。
    public let title: String?

    public init(slot: Int, identity: AnyHashable?, title: String?) {
        self.slot = slot
        self.identity = identity
        self.title = title
    }
}

/// 一页的中性内容承载。
public struct PagingPageContent: Sendable, Equatable {
    /// 本页内容的呈现身份（provider 回显请求的 presentation；revision 即本页内容基线）。
    public let presentationID: PagePresentationID
    /// 页内条目（数量由 itemsPerPage 契约决定；空数组 + isPlaceholder = 空页占位）。
    public let items: [PagingPageContentItem]
    /// true = 中性占位（未命中已准备内容 / provider 失败 / 缺省路径）。
    public let isPlaceholder: Bool

    public init(presentationID: PagePresentationID, items: [PagingPageContentItem], isPlaceholder: Bool) {
        self.presentationID = presentationID
        self.items = items
        self.isPlaceholder = isPlaceholder
    }
}

/// 内容提供：同步、热路径外调用；仅命中内存中的已准备内容（§5.4、§7）。
/// 不得同步扫描/读 Bundle/解码/等待异步；失败返回 isPlaceholder = true 的中性承载，不阻塞手势。
///
/// 契约（latest-wins，§6.2）：
/// - `servedRevision`：当前对外服务的 revision（单调递增；app 层刷新完成后经
///   `PagingSurface.refreshPresentation()` 推送）；**nil = 未就绪（无已提交快照）→ 中性占位**。
/// - `servedPageCount`：与 servedRevision 同快照的合法页面总数（surface 在 idle 边界
///   原子替换 presentation 时同步给 Core）；nil = 未就绪（跳过 pageCount 同步）。
/// - `content(for:itemsPerPage:)`：为指定 presentation 提供内容；只服务
///   revision == servedRevision 的请求并回显 presentation；revision 不可用/未准备/
///   页越界 → isPlaceholder = true 的中性承载（不得抛错、不得等待）。
public protocol PagingPageContentProviding: AnyObject {
    /// 当前对外服务的 revision（仅 CatalogRepository 分配；PagingUI 只消费）；nil = 未就绪。
    var servedRevision: UInt64? { get }
    /// 当前合法页面总数（与 servedRevision 同快照）；nil = 未就绪。
    var servedPageCount: Int? { get }
    /// 同步内存命中内容请求（回显 presentationID；未命中 → 中性占位）。
    func content(for presentation: PagePresentationID, itemsPerPage: Int) -> PagingPageContent
}

/// 页面渲染：render 前必须已清空（复用路径由 clearForReuse 保证，对应 PageHostView 同名方法）；
/// reuseGeneration bump 作废在途异步绑定（防串图，§6.4）。
///
/// **reuseGeneration 契约（§6.4 binding token 的承载侧）：**
/// - 每个页面承载实例（默认 PageHostView）持有一个单调递增的 `reuseGeneration`；
/// - `clearForReuse()` 时 bump —— 该实例此前 render 时发起的全部在途异步绑定（图标加载、
///   图像解码、任何延迟写回）即刻作废；
/// - `render(pageIndex:content:pageCount:reuseGeneration:)` 携带**本次 render 时有效**的
///   generation；渲染器/单元格在异步回调到达时必须校验：捕获的 generation ≠ 当前
///   generation → 丢弃（stale apply 计数必须为 0，§10.5）。
/// - 承载视图销毁（surface teardown）另行 bump surface 级 generation（`PagingSurface.
///   surfaceGeneration`），作废跨页面生命周期的在途绑定。
///
/// §6.4 七字段 binding token 位于 AppGridUI 层（该层拥有 AppID/IconKey）：
/// 1. catalogRevision  2. pageIdentity（PagePresentationID）  3. itemSlot
/// 4. appID（AnyHashable?）  5. reuseGeneration  6. iconKey（IconKey?）
/// 7. surfaceGeneration（PagingSurface.surfaceGeneration 提供）
/// apply 条件：七字段全匹配且 view 仍有效才写回。
public protocol PagingPageRendering: AnyObject {
    /// 渲染一页内容（调用前 view 层级必须已清空；携带本次有效的 reuseGeneration）。
    func render(pageIndex: Int, content: PagingPageContent, pageCount: Int, reuseGeneration: UInt64)
    /// 进入复用池前的清理：清空 view 层级 + generation bump（作废全部在途异步绑定）。
    func clearForReuse()
}

/// 自定义渲染器的可选目标绑定：注入 PageHostView 的自定义渲染器若需要把内容绘制进承载
/// 视图的层级，实现本协议；PagingUI 在每次 render 前设置 `renderTarget`（承载视图自身）。
/// 纯记录型渲染器（测试/装饰）无需实现本协议。
public protocol PagingPageRenderingTargetBinding: AnyObject {
    /// 当前承载视图（render 前由 PagingUI 绑定）。
    var renderTarget: NSView? { get set }
}

/// 中性缺省内容提供者（Phase 1A 回归模式，§E 约束④：NeutralContentProvider 路径继续可运行）。
/// - `contentProvider == nil` 时 PagingSurface 使用本缺省：任何请求都返回中性占位内容；
/// - servedRevision 恒 0（无业务 revision 概念）；servedPageCount 恒 0（surface 在
///   provider 为 nil 时不借它改 pageCount——Phase 1A 语义：pageCount 由 app 层经
///   `setPageCount` 维持）；
/// - items = itemsPerPage 个中性条目（identity/title 均 nil → 渲染器画 slot+1 序号，
///   与 Phase 1A 中性 tile 网格完全一致）。
public final class NeutralContentProvider: PagingPageContentProviding {

    public var servedRevision: UInt64? { 0 }
    public var servedPageCount: Int? { 0 }

    public init() {}

    public func content(for presentation: PagePresentationID, itemsPerPage: Int) -> PagingPageContent {
        PagingPageContent(
            presentationID: presentation,
            items: (0..<itemsPerPage).map { PagingPageContentItem(slot: $0, identity: nil, title: nil) },
            isPlaceholder: true
        )
    }
}
