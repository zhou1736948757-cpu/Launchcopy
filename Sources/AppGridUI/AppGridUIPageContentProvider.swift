// AppGridUI — AppGridUIPageContentProvider（§E seam 内容提供；§6.2/6.3 一致性）
// 实现：T-worker-b-appgridui（Phase 1B Wave 2）+ T-1E-B（Phase 1E 顶层组合）。
// AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 职责：
// - CatalogSnapshot + FolderSnapshot → 每页内容槽位（顶层组合 [TopLevelEntry]：
//   app 条目显示名 + AppID、folder 条目标题 + FolderID，均经 AnyHashable 承载；
//   PagingUI 中性化：revision 用 UInt64、identity 用 AnyHashable，§E 中性化决策）；
// - servedRevision/pageCount 语义：只服务“已提交”快照；pageCount 由顶层组合条目数推导
//   （每个 folder = 一个槽位；0 条目 = 0 页；ceil(count/itemsPerPage)，用实例 itemsPerPage）；
// - pendingLatestSnapshot / pendingFolderSnapshot（latest-wins）：手势/transition 期间
//   新快照/新 folder 组合只进 pending，连续刷新只保留最新；idle 边界（applyPending）
//   一次性原子 commit（catalog + folder 同界）+ anchor remap；
// - anchor remap = 五级降级（located → successor → predecessor → clamped → emptyCatalog，
//   ADR-004 已冻结；绝不沿用旧数组 index）。app-only 组合委托 CatalogPlanner（精确既有行为）；
//   混合组合用组合感知 remap（anchor 为稳定顶层条目身份 app AppID 或 folder FolderID）。
// - 搜索扁平化：搜索激活时 presentation 为 app-only（成员扁平化）；退出搜索恢复完整顶层组合。
// - folder 层绝不 mint/forge CatalogRevision；folder generation 为独立单调 token。
//
// 热路径纪律（§7）：content(for:) 纯同步内存命中，无扫描/读 Bundle/解码/等待异步。
//
// 隐私：folder 标题/成员/身份原值与图标数据绝不进入 telemetry/JSONL/stdout/signpost/
// profile/report；仅中性计数。

import AppCatalogCore
import Foundation
import PagingUI

/// 提交后的一页内容（供装配层刷新 PagingSurface presentation）。
public struct AppGridPresentationUpdate: Sendable, Equatable {
    public let plan: PagePlan
    public let outcome: AnchorOutcome
    /// 更新前记录的稳定 anchor（committed page 首个可见 AppID；nil = 无 served 快照或首项为 folder）。
    public let anchor: AppID?
    /// 更新前记录的稳定顶层条目身份（app AppID 或 folder FolderID；nil = 无 served 快照）。
    public let topLevelAnchor: TopLevelEntryIdentity?
    /// 更新前 revision（nil = 首次呈现）。
    public let previousRevision: UInt64?
    public var newRevision: UInt64 { plan.snapshotRevision.value }

    public init(plan: PagePlan, outcome: AnchorOutcome, anchor: AppID?,
                topLevelAnchor: TopLevelEntryIdentity?, previousRevision: UInt64?) {
        self.plan = plan
        self.outcome = outcome
        self.anchor = anchor
        self.topLevelAnchor = topLevelAnchor
        self.previousRevision = previousRevision
    }
}

/// 内容提供者：只命中内存中已准备内容；未就绪/越界/revision 不匹配 → 中性占位，
/// 不阻塞手势（§E 约束 ⑤）。
public final class AppGridUIPageContentProvider: PagingPageContentProviding {

    /// 已提交快照（UI 正在呈现的真相；nil = 未就绪 → 全部占位）。
    /// 语义 = base snapshot（完整目录，来自 refresh commit；§9.3）。
    public private(set) var servedSnapshot: CatalogSnapshot?
    /// base snapshot 别名（§9.3 / ADR-007 §2.2：完整目录，来自 refresh commit）。
    public var baseSnapshot: CatalogSnapshot? { servedSnapshot }
    public var servedRevision: UInt64? { servedSnapshot?.revision.value }
    /// 已提交的顶层组合（完整目录 + 文件夹；空查询 → base 组合；§9.3 / ADR-008 §2.1）。
    public private(set) var presentationEntries: [TopLevelEntry] = []
    /// 已提交的 app-only 投影（完整目录或搜索结果；空查询 → base records；§9.3）。
    /// 保留为 [AppRecord]：冻结消费者（AppDelegate/AppSearchController）据此构建
    /// CatalogSnapshot 供 AppGridFocusLayout.build。
    public private(set) var presentationRecords: [AppRecord] = []
    /// 当前已提交查询（nil = 无搜索/空查询 → 呈现 base 组合）。
    public private(set) var activeQuery: AppSearchQuery?
    /// 待提交搜索结果（同 revision latest query result；latest-wins；§9.3）。
    public private(set) var pendingSearchResult: AppSearchResultSet?
    public var hasPendingSearchResult: Bool { pendingSearchResult != nil }
    /// servedPageCount 基于顶层组合条目数（§9.3 / ADR-008 §2.1：page count 由组合条目数推导，
    /// 每个 folder = 一个槽位）。用实例 itemsPerPage（T-1E-H2 repair：非默认 --items-per-page
    /// 下不再硬编码 35）。
    public var servedPageCount: Int? {
        guard servedSnapshot != nil else { return nil }
        let count = presentationEntries.count
        return count == 0 ? 0 : (count + itemsPerPage - 1) / itemsPerPage
    }

    /// 待提交快照（latest-wins：连续 receive 只保留最新）。
    public private(set) var pendingSnapshot: CatalogSnapshot?
    public var pendingRevision: UInt64? { pendingSnapshot?.revision.value }
    public var hasPendingSnapshot: Bool { pendingSnapshot != nil }

    /// 已提交 folder 快照（已对 served catalog 收缩；nil = 无 folder 组合）。
    public private(set) var servedFolderSnapshot: FolderSnapshot?
    /// 待提交 folder 快照（latest-wins：连续 receiveFolderSnapshot 只保留最新）。
    public private(set) var pendingFolderSnapshot: FolderSnapshot?
    public var hasPendingFolderSnapshot: Bool { pendingFolderSnapshot != nil }

    /// 与 PagingSurface 默认对齐的每页 item 数（可被 content(for:itemsPerPage:) 覆盖）。
    public static let defaultItemsPerPage = 35

    /// 实例每页 item 数（默认 = defaultItemsPerPage；装配层按 surface.itemsPerPage 覆盖，
    /// servedPageCount 据此推导；T-1E-H2 repair）。
    public var itemsPerPage: Int = AppGridUIPageContentProvider.defaultItemsPerPage

    public init(snapshot: CatalogSnapshot? = nil, folderSnapshot: FolderSnapshot? = nil) {
        self.servedSnapshot = snapshot
        self.servedFolderSnapshot = folderSnapshot
        if let snapshot {
            let folders = folderSnapshot ?? FolderSnapshot(generation: .zero, entries: [])
            let composition = TopLevelComposition.build(catalog: snapshot, folders: folders)
            self.presentationEntries = composition
            self.presentationRecords = Self.appOnlyProjection(composition)
        } else {
            self.presentationEntries = []
            self.presentationRecords = []
        }
    }

    // MARK: - 快照接收（latest-wins）

    /// 接收新快照（扫描完成/推送到达）：只进 pending，不立刻替换 served。
    /// 手势/transition 期间的连续刷新只保留最新 revision（§6.2）。
    public func receive(_ snapshot: CatalogSnapshot) {
        pendingSnapshot = snapshot
    }

    public func discardPending() {
        pendingSnapshot = nil
    }

    // MARK: - Folder 快照接收（latest-wins；folder 层绝不 mint/forge CatalogRevision）

    /// 接收新 folder 组合（lab 重建/成员变化）：只进 pending，不立刻替换 served。
    /// 连续 receiveFolderSnapshot 只保留最新（latest-wins）；idle 边界随 catalog 原子提交。
    public func receiveFolderSnapshot(_ snapshot: FolderSnapshot) {
        pendingFolderSnapshot = snapshot
    }

    /// 丢弃待提交 folder 快照（幂等）。
    public func discardPendingFolderSnapshot() {
        pendingFolderSnapshot = nil
    }

    // MARK: - 搜索结果（§9.3 / ADR-007 §2.2：presentation records 驱动）

    /// 暂存搜索结果（latest-wins：连续 stage 只保留最新；控制器在 idle 边界提交）。
    public func stageSearchResult(_ result: AppSearchResultSet) {
        pendingSearchResult = result
    }

    /// 丢弃暂存搜索结果（幂等）。
    public func discardPendingSearchResult() {
        pendingSearchResult = nil
    }

    /// 提交暂存搜索结果到 presentation（仅当结果 base revision 与当前 base 一致；
    /// 控制器在 idle 边界调用）。返回是否已提交。
    /// 搜索扁平化（ADR-008 §2.1/§2.4）：非空 query 提交后 presentation 为 app-only
    /// （成员扁平化，folder 隐藏）；空 query（退出搜索）恢复完整顶层组合（apps + folders）。
    @discardableResult
    public func commitPendingSearchResult(query: AppSearchQuery?) -> Bool {
        guard let result = pendingSearchResult else { return false }
        guard let base = servedSnapshot, result.baseCatalogRevision == base.revision else {
            pendingSearchResult = nil
            return false
        }
        if query?.isEmpty ?? true {
            // 空 query → 恢复完整顶层组合（apps + folders）。
            let folders = servedFolderSnapshot ?? FolderSnapshot(generation: .zero, entries: [])
            let composition = TopLevelComposition.build(catalog: base, folders: folders)
            presentationEntries = composition
            presentationRecords = Self.appOnlyProjection(composition)
        } else {
            // 非空 query → app-only（成员扁平化）。
            presentationEntries = result.records.map { .app($0) }
            presentationRecords = result.records
        }
        activeQuery = query
        pendingSearchResult = nil
        return true
    }

    // MARK: - idle 边界 commit + anchor remap（§6.2 idle / §6.3 规则 1–6）

    /// idle 边界一次性应用 pending（catalog + folder 原子提交）：
    /// 1. 更新前记录 anchor（committed page 首个可见顶层条目身份，从已提交组合取）；
    /// 2. 五级降级 remap（新组合 + anchor，绝不沿用旧 index）；
    /// 3. 原子替换 served = pending、清空 pending；
    /// 4. 返回 presentation update（装配层据此刷新 surface：setPageCount + refreshPresentation）。
    ///
    /// 无 pending（catalog 与 folder 均无）→ nil（无操作）。空组合 → outcome .emptyCatalog、
    /// pageCount 0（合法空态）。
    @discardableResult
    public func applyPending(atCurrentPage currentPage: Int, itemsPerPage: Int = AppGridUIPageContentProvider.defaultItemsPerPage)
        -> AppGridPresentationUpdate? {
        guard pendingSnapshot != nil || pendingFolderSnapshot != nil else { return nil }
        let previousRevision = servedRevision
        let anchor = topLevelAnchorCandidate(nearPage: currentPage, itemsPerPage: itemsPerPage)

        // 新 base catalog：pending 优先，否则沿用 served。
        let newBase: CatalogSnapshot
        if let pending = pendingSnapshot {
            newBase = pending
        } else if let served = servedSnapshot {
            newBase = served
        } else {
            return nil
        }

        // 新 folder 快照：pending 优先，否则对 served 收缩；均对 newBase 收缩（新 generation）。
        let newFolder: FolderSnapshot?
        if let pendingFolder = pendingFolderSnapshot {
            newFolder = rebaseFolder(pendingFolder, against: newBase)
        } else if let servedFolder = servedFolderSnapshot {
            newFolder = rebaseFolder(servedFolder, against: newBase)
        } else {
            newFolder = nil
        }

        // 顶层组合（app + folder；单成员解散为 app 条目；空 folder 移除）。
        let composition = TopLevelComposition.build(
            catalog: newBase,
            folders: newFolder ?? FolderSnapshot(generation: .zero, entries: []))

        // 五级降级 remap（app-only 委托 CatalogPlanner；混合用组合感知 remap）。
        let (pageCount, outcome) = remapComposition(composition, anchor: anchor,
                                                    itemsPerPage: itemsPerPage,
                                                    baseRevision: newBase.revision)
        let plan = PagePlan(snapshotRevision: newBase.revision, itemsPerPage: itemsPerPage,
                            itemCount: composition.count, pageCount: pageCount)

        // 原子提交。
        servedSnapshot = newBase
        servedFolderSnapshot = newFolder
        presentationEntries = composition
        presentationRecords = Self.appOnlyProjection(composition)
        pendingSnapshot = nil
        pendingFolderSnapshot = nil
        activeQuery = nil
        pendingSearchResult = nil

        return AppGridPresentationUpdate(plan: plan, outcome: outcome,
                                         anchor: Self.anchorAppID(anchor),
                                         topLevelAnchor: anchor,
                                         previousRevision: previousRevision)
    }

    // MARK: - 已提交布局应用（T-1F-D1-fix-e1：drag commit → 呈现面）

    /// 应用已提交布局（T-1F-D1-fix-e1）：把 `PersistentWorkspaceLayout` 落到呈现面。
    /// - 解析 layout.topLevelOrder 条目：PersistentAppReference → servedSnapshot 记录；
    ///   FolderID → layout.folders 记录 → FolderEntry（成员解析为 AppID）；不可解析条目跳过。
    /// - 呈现 = 布局顺序（任意交错，可表达 reorder 与 createFolder）；presentationRecords =
    ///   app-only 投影；servedFolderSnapshot = 布局 folder 集合（generation 递增）。
    /// - pageCount = ceil(count/itemsPerPage)（非空 ≥ 1）；currentPage 先按旧呈现页数 clamp
    ///   再记录 anchor（五级降级 remap 复用既有 helper）；plan.snapshotRevision = served revision。
    /// - 无 served 快照 → nil（no-op）。served catalog 不变（布局提交不 mint/forge CatalogRevision）。
    @discardableResult
    public func applyCommittedLayout(_ layout: PersistentWorkspaceLayout,
                                      atCurrentPage currentPage: Int,
                                      itemsPerPage: Int) -> AppGridPresentationUpdate? {
        guard let served = servedSnapshot else { return nil }

        // 布局 folder 集合 → FolderSnapshot（成员解析为 AppID；不可解析成员跳过；generation 递增）。
        let nextFolderGeneration = (servedFolderSnapshot?.generation ?? .zero).incremented()
        let folderEntries = layout.folders.compactMap { record -> FolderEntry? in
            let members = record.members.compactMap { ref -> AppID? in
                served.records.first(where: { ref.matches(record: $0) })?.id
            }
            return FolderEntry(id: record.id, title: record.title, members: members)
        }
        let folderSnapshot = FolderSnapshot(generation: nextFolderGeneration, entries: folderEntries)

        // 顶层组合 = 布局顺序（app 引用 → 记录；folder 身份 → 已解析 folder 条目；不可解析跳过）。
        var entries: [TopLevelEntry] = []
        for entry in layout.topLevelOrder {
            switch entry {
            case .app(let ref):
                if let record = served.records.first(where: { ref.matches(record: $0) }) {
                    entries.append(.app(record))
                }
            case .folder(let folderID):
                if let folderEntry = folderEntries.first(where: { $0.id == folderID }) {
                    entries.append(.folder(folderEntry))
                }
            }
        }

        // 更新前 anchor（旧呈现；currentPage 先按旧页数 clamp，越界 → 末页首位）。
        let oldPageCount = presentationEntries.isEmpty
            ? 0 : (presentationEntries.count + itemsPerPage - 1) / itemsPerPage
        let clampedPage = oldPageCount == 0 ? 0 : min(max(currentPage, 0), oldPageCount - 1)
        let anchor = topLevelAnchorCandidate(nearPage: clampedPage, itemsPerPage: itemsPerPage)

        // 五级降级 remap + pageCount（复用既有 helper；非空组合 pageCount = ceil(count/itemsPerPage)）。
        let (pageCount, outcome) = remapComposition(entries, anchor: anchor,
                                                    itemsPerPage: itemsPerPage,
                                                    baseRevision: served.revision)
        let plan = PagePlan(snapshotRevision: served.revision, itemsPerPage: itemsPerPage,
                            itemCount: entries.count, pageCount: pageCount)

        // 原子提交（served catalog 不变；呈现 = 布局顺序；搜索态被布局提交取代）。
        servedFolderSnapshot = folderSnapshot
        presentationEntries = entries
        presentationRecords = Self.appOnlyProjection(entries)
        activeQuery = nil
        pendingSearchResult = nil

        return AppGridPresentationUpdate(plan: plan, outcome: outcome,
                                         anchor: Self.anchorAppID(anchor),
                                         topLevelAnchor: anchor,
                                         previousRevision: servedRevision)
    }

    /// 更新前记录稳定 anchor = committed page 首个可见 AppID（§6.3）。
    /// 基于 app-only 投影（搜索激活时 = 结果集首个可见 AppID；首项为 folder → nil）。
    public func anchorCandidate(nearPage: Int, itemsPerPage: Int = AppGridUIPageContentProvider.defaultItemsPerPage) -> AppID? {
        guard let snapshot = servedSnapshot else { return nil }
        let presentation = CatalogSnapshot(revision: snapshot.revision, records: presentationRecords)
        return CatalogPlanner().anchorCandidate(nearPage: nearPage, in: presentation, itemsPerPage: itemsPerPage)
    }

    /// 更新前记录稳定顶层条目身份 = committed page 首个可见条目身份（app AppID 或 folder FolderID）。
    public func topLevelAnchorCandidate(nearPage: Int, itemsPerPage: Int = AppGridUIPageContentProvider.defaultItemsPerPage) -> TopLevelEntryIdentity? {
        guard servedSnapshot != nil else { return nil }
        guard itemsPerPage > 0, nearPage >= 0 else { return nil }
        let entries = presentationEntries
        guard !entries.isEmpty else { return nil }
        let pageCount = (entries.count + itemsPerPage - 1) / itemsPerPage
        guard nearPage < pageCount else { return nil }
        let index = nearPage * itemsPerPage
        guard index < entries.count else { return nil }
        return entries[index].identity
    }

    /// 定位 AppID 在当前呈现（顶层组合中的 app 条目）中的页（nil = 不存在/未就绪）。
    public func pageIndex(of appID: AppID, itemsPerPage: Int = AppGridUIPageContentProvider.defaultItemsPerPage) -> Int? {
        guard servedSnapshot != nil else { return nil }
        guard let index = presentationEntries.firstIndex(where: {
            if case .app(let record) = $0 { return record.id == appID } else { return false }
        }) else { return nil }
        return index / itemsPerPage
    }

    /// 定位顶层条目身份（app AppID 或 folder FolderID）在当前呈现中的页（nil = 不存在/未就绪）。
    public func topLevelPageIndex(of identity: TopLevelEntryIdentity, itemsPerPage: Int = AppGridUIPageContentProvider.defaultItemsPerPage) -> Int? {
        guard servedSnapshot != nil else { return nil }
        guard let index = presentationEntries.firstIndex(where: { $0.identity == identity }) else { return nil }
        return index / itemsPerPage
    }

    // MARK: - PagingPageContentProviding（同步、内存命中；§E 签名）

    /// 只服务“revision == servedRevision”的请求：一页所有 item 同 revision（§6.1）；
    /// 未就绪 / revision 不匹配 / 页越界 → 中性占位（isPlaceholder = true，items 空）。
    /// 切片顶层组合（§9.3 / ADR-008 §2.1：content 只命中已提交呈现，不读 pending）。
    public func content(for presentation: PagePresentationID, itemsPerPage: Int) -> PagingPageContent {
        guard servedSnapshot != nil else {
            return placeholderContent(for: presentation)
        }
        guard presentation.revision == servedRevision else {
            return placeholderContent(for: presentation)
        }
        let entries = presentationEntries
        let pageCount = entries.isEmpty ? 0 : (entries.count + itemsPerPage - 1) / itemsPerPage
        guard presentation.pageIndex >= 0, presentation.pageIndex < pageCount else {
            return placeholderContent(for: presentation)
        }

        var items: [PagingPageContentItem] = []
        let start = presentation.pageIndex * itemsPerPage
        let end = min(start + itemsPerPage, entries.count)
        guard start < end else {
            return placeholderContent(for: presentation)
        }
        for index in start..<end {
            let entry = entries[index]
            switch entry {
            case .app(let record):
                items.append(PagingPageContentItem(
                    slot: index,                          // 全局槽位（pageIndex * itemsPerPage + 页内序号）
                    identity: AnyHashable(record.id),     // AppID（Hashable）经 AnyHashable 承载
                    title: record.displayName             // 同步文本：app 显示名
                ))
            case .folder(let folder):
                items.append(PagingPageContentItem(
                    slot: index,
                    identity: AnyHashable(folder.id),     // FolderID（Hashable）经 AnyHashable 承载
                    title: folder.title                   // 同步文本：folder 标题
                ))
            }
        }
        return PagingPageContent(presentationID: presentation, items: items, isPlaceholder: false)
    }

    /// 中性占位内容：不阻塞手势；渲染方显示中性态（无身份、无名称）。
    public func placeholderContent(for presentation: PagePresentationID) -> PagingPageContent {
        PagingPageContent(presentationID: presentation, items: [], isPlaceholder: true)
    }

    // MARK: - 内部

    /// 对 folder 快照做成员收缩（删成员 / 空移除 / 单成员解散），并分配新 generation。
    private func rebaseFolder(_ folders: FolderSnapshot, against catalog: CatalogSnapshot) -> FolderSnapshot {
        let nextGeneration = (servedFolderSnapshot?.generation ?? .zero).incremented()
        return FolderMembership.rebase(folders, against: catalog, generation: nextGeneration).snapshot
    }

    /// 五级降级 remap（§6.3 规则 1–5，顺序即判定顺序）：
    /// 1. 空组合 → `.emptyCatalog`（pageCount 0，合法空态）；
    /// 2. anchor 存在 → `.located(anchor 在新组合中的页)`；
    /// 3. anchor 消失 → `.successor(新组合稳定顺序中首个身份全序大于 anchor 的条目所在页)`；
    /// 4. 无后继 → `.predecessor(最后一个身份全序小于 anchor 的条目所在页)`；
    /// 5. 都无（含 anchor == nil）→ `.clamped(page 0)`。
    /// app-only 组合委托 `CatalogPlanner.remap`（精确既有行为，含 AppID 全序）；混合组合用
    /// 组合感知 remap（身份全序：folder 在 app 前；同类按 hashValue 稳定序——运行内确定）。
    private func remapComposition(_ composition: [TopLevelEntry],
                                  anchor: TopLevelEntryIdentity?,
                                  itemsPerPage: Int,
                                  baseRevision: CatalogRevision) -> (pageCount: Int, outcome: AnchorOutcome) {
        let pageCount = composition.isEmpty ? 0 : (composition.count + itemsPerPage - 1) / itemsPerPage
        guard !composition.isEmpty else { return (0, .emptyCatalog) }

        // app-only 组合 → 委托 CatalogPlanner（精确既有行为）。
        if composition.allSatisfy({ if case .app = $0 { return true } else { return false } }) {
            let appRecords = composition.compactMap { if case .app(let record) = $0 { return record } else { return nil } }
            let synthetic = CatalogSnapshot(revision: baseRevision, records: appRecords)
            let (plan, outcome) = CatalogPlanner().remap(snapshot: synthetic,
                                                         anchor: Self.anchorAppID(anchor),
                                                         itemsPerPage: itemsPerPage)
            return (plan.pageCount, outcome)
        }

        // 混合组合 → 组合感知 remap。
        guard let anchor else { return (pageCount, .clamped(pageIndex: 0)) }
        if let index = composition.firstIndex(where: { $0.identity == anchor }) {
            return (pageCount, .located(pageIndex: index / itemsPerPage))
        }
        if let index = composition.firstIndex(where: { identityOrder(anchor, $0.identity!) == .orderedAscending }) {
            return (pageCount, .successor(pageIndex: index / itemsPerPage))
        }
        if let index = composition.lastIndex(where: { identityOrder($0.identity!, anchor) == .orderedAscending }) {
            return (pageCount, .predecessor(pageIndex: index / itemsPerPage))
        }
        return (pageCount, .clamped(pageIndex: 0))
    }

    /// 顶层条目身份全序（混合组合 remap 用）：folder 在 app 前；同类按 hashValue 稳定序。
    private func identityOrder(_ a: TopLevelEntryIdentity, _ b: TopLevelEntryIdentity) -> ComparisonResult {
        switch (a, b) {
        case (.app, .folder): return .orderedAscending
        case (.folder, .app): return .orderedDescending
        case (.app(let x), .app(let y)):
            if x.hashValue < y.hashValue { return .orderedAscending }
            if x.hashValue > y.hashValue { return .orderedDescending }
            return .orderedSame
        case (.folder(let x), .folder(let y)):
            if x.hashValue < y.hashValue { return .orderedAscending }
            if x.hashValue > y.hashValue { return .orderedDescending }
            return .orderedSame
        }
    }

    /// 顶层条目身份 → app-only 投影（[AppRecord]；folder 条目剔除）。
    private static func appOnlyProjection(_ composition: [TopLevelEntry]) -> [AppRecord] {
        composition.compactMap { if case .app(let record) = $0 { return record } else { return nil } }
    }

    /// 顶层条目身份 → AppID（folder/占位 → nil）。
    private static func anchorAppID(_ identity: TopLevelEntryIdentity?) -> AppID? {
        if case .app(let id)? = identity { return id }
        return nil
    }
}
