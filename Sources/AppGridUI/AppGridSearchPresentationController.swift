// AppGridUI — AppGridSearchPresentationController（Phase 1D 搜索 presentation 层；§9.3 / ADR-007 §2.2-2.5）
// 实现：T-1D-B（Worker B）+ T-1E-B（Phase 1E：移除死回调 onStateChange——无设置方、无调用方）。
// AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 职责：
// - 拥有查询代（search-controller 内部 latest-wins token，与 baseCatalogRevision 完全独立，§2.3）；
// - 接收查询变化与 catalog 快照；用 T-1D-A matcher 计算过滤结果集（空 query → base records）；
// - 驱动 provider 的 presentation records（servedRevision 保持 base revision，绝不 mint 假 revision）；
// - idle 边界提交（镜像 pendingLatestSnapshot 纪律，§2.4）：catalog refresh 优先，
//   新 base 上重跑当前查询；同 revision 搜索结果 latest-wins 提交。
//
// 隐私：query 原文/归一化文本/结果 app 名绝不进入 telemetry/log/stdout/signpost/profile/report。

import AppCatalogCore
import Foundation

/// 搜索呈现编排器：拥有查询代，计算过滤结果集，驱动 provider 的 presentation records，
/// idle 边界提交（catalog refresh 优先，同 revision 搜索结果 latest-wins）。
@MainActor
public final class AppGridSearchPresentationController {

    public let provider: AppGridUIPageContentProvider
    public let matcher: AppSearchMatcher
    public var itemsPerPage: Int = AppGridUIPageContentProvider.defaultItemsPerPage

    /// 查询代（latest-wins token，与 baseCatalogRevision 完全独立；§2.3）。
    public private(set) var latestGeneration: AppSearchGeneration = .zero
    /// 当前查询（nil = 无搜索/空查询）。
    public private(set) var currentQuery: AppSearchQuery?

    /// 呈现更新回调（catalog commit 后触发；装配层刷新 surface）。
    public var onPresentationUpdate: ((AppGridPresentationUpdate) -> Void)?
    /// 搜索结果提交回调（同 revision 重载；装配层调 surface.reloadCurrentPresentation()）。
    public var onSearchResultCommitted: (() -> Void)?

    public init(provider: AppGridUIPageContentProvider = AppGridUIPageContentProvider(),
                matcher: AppSearchMatcher = AppSearchMatcher()) {
        self.provider = provider
        self.matcher = matcher
    }

    // MARK: - 查询变化

    /// 查询变化：递增查询代，对当前 base snapshot 计算过滤结果，暂存为 pendingSearchResult。
    /// 空/纯空白/换行 query → 结果 = base records（无过滤）。
    public func updateQuery(_ query: AppSearchQuery) {
        latestGeneration = latestGeneration.incremented()
        currentQuery = query
        guard let base = provider.servedSnapshot else { return } // 尚无 base → 无结果可算
        let records = filter(base.records, query: query)
        let result = AppSearchResultSet(baseCatalogRevision: base.revision,
                                        queryGeneration: latestGeneration,
                                        records: records)
        provider.stageSearchResult(result)
    }

    /// 清空查询（等价于空 query；结果 = base records）。
    public func clearQuery() {
        updateQuery(AppSearchQuery(raw: ""))
    }

    // MARK: - Catalog 快照

    /// 接收新 catalog 快照（pendingCatalogSnapshot；latest-wins）。
    public func receive(_ snapshot: CatalogSnapshot) {
        provider.receive(snapshot)
    }

    // MARK: - idle 边界提交（§9.3 / ADR-007 §2.4）

    /// idle 边界一次性提交：
    /// 1. catalog refresh 优先：存在 pendingCatalogSnapshot → applyPending（新 base 提交，
    ///    presentationRecords 重置为 base records）→ 在新 base 上重跑当前查询 → 提交搜索结果；
    /// 2. 否则存在 pendingSearchResult 且 current → 提交到 presentationRecords。
    @discardableResult
    public func applyPendingAtIdleBoundary(currentPage: Int) -> AppGridPresentationUpdate? {
        if let update = provider.applyPending(atCurrentPage: currentPage, itemsPerPage: itemsPerPage) {
            if let query = currentQuery {
                updateQuery(query) // 新 base 上重跑当前查询
            }
            commitPendingSearchResultIfCurrent()
            onPresentationUpdate?(update)
            return update
        }
        if commitPendingSearchResultIfCurrent() {
            onSearchResultCommitted?()
        }
        return nil
    }

    // MARK: - 状态推导

    /// 搜索感知的中性 UI 状态（§10：base 空 → .empty；base 非空 + active 非空 query + 0 结果 → .noResults）。
    public var uiState: AppGridUIState {
        guard let base = provider.servedSnapshot else { return .loading }
        if base.records.isEmpty { return .empty }
        if let query = currentQuery, !query.isEmpty, provider.presentationRecords.isEmpty {
            return .noResults
        }
        return .ready
    }

    // MARK: - 内部

    private func filter(_ records: [AppRecord], query: AppSearchQuery) -> [AppRecord] {
        guard !query.isEmpty else { return records }
        return records.filter { matcher.matches($0, query: query) }
    }

    @discardableResult
    private func commitPendingSearchResultIfCurrent() -> Bool {
        guard let result = provider.pendingSearchResult else { return false }
        // latest-wins 双轴：仅当 result 的 base revision 与当前 base 一致才提交。
        guard result.baseCatalogRevision == provider.servedSnapshot?.revision else {
            provider.discardPendingSearchResult()
            return false
        }
        return provider.commitPendingSearchResult(query: currentQuery)
    }
}
