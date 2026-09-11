// AppGridUI — AppSearchResultSet / AppSearchGeneration（Phase 1D 纯搜索域；§9.1 / §8.2）
// 实现：T-1D-A（Worker A）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 纯 Foundation 值类型，无 AppKit、无 I/O。
//
// - `AppSearchGeneration`：搜索控制器内部 latest-wins token，单调递增，与 `CatalogRevision`
//   完全独立（§2.3 / §8.2）。query 变化绝不触碰 `CatalogRepository`/`CatalogRevision`。
// - `AppSearchResultSet`：presentation controller 的提交单元，携带
//   `baseCatalogRevision` + `queryGeneration` + 过滤后记录（保持快照稳定顺序）+ `resultCount`。
//
// 隐私：不提供可逆向输出 AppID 原文的 debug description；不记录 query 原文/结果 app 名。

import AppCatalogCore
import Foundation

/// 单调 latest-wins token：搜索控制器内部递增；与 `CatalogRevision` 完全独立。
public struct AppSearchGeneration: Hashable, Comparable, Sendable {
    public let value: UInt64
    public init(_ value: UInt64) { self.value = value }
    public static let zero = AppSearchGeneration(0)
    public func incremented() -> AppSearchGeneration { AppSearchGeneration(value + 1) }
    public static func < (lhs: AppSearchGeneration, rhs: AppSearchGeneration) -> Bool {
        lhs.value < rhs.value
    }
}

/// 搜索结果提交单元：base catalog revision + query generation + 过滤后记录。
///
/// `records` 是基础 `CatalogSnapshot.records` 的**稳定子序列**（保持快照顺序，不重排、不排名）。
/// 不为搜索结果分配新 `CatalogRevision`；`baseCatalogRevision` 来自 `CatalogRepository`。
public struct AppSearchResultSet: Equatable, Sendable {
    /// 基础 catalog revision（来自 `CatalogRepository`；query 变化不得伪造/改动）。
    public let baseCatalogRevision: CatalogRevision
    /// 搜索控制器内部 latest-wins token（与 `baseCatalogRevision` 完全独立）。
    public let queryGeneration: AppSearchGeneration
    /// 过滤后记录（保持基础快照稳定顺序）。
    public let records: [AppRecord]

    public init(baseCatalogRevision: CatalogRevision,
                queryGeneration: AppSearchGeneration,
                records: [AppRecord]) {
        self.baseCatalogRevision = baseCatalogRevision
        self.queryGeneration = queryGeneration
        self.records = records
    }

    /// 结果数。
    public var resultCount: Int { records.count }

    /// 无结果（0 条）。
    public var isEmpty: Bool { records.isEmpty }

    /// 分页：`pageCount = resultCount == 0 ? 0 : ceil(resultCount / itemsPerPage)`。
    /// 与 `CatalogPlanner.plan` 公式一致（35 条 = 1 页、36 条 = 2 页）；0 结果 = 0 页。
    public func pageCount(itemsPerPage: Int) -> Int {
        precondition(itemsPerPage > 0, "itemsPerPage 必须 > 0（接口契约）")
        return resultCount == 0 ? 0 : (resultCount + itemsPerPage - 1) / itemsPerPage
    }

    /// latest-wins 提交校验（纯函数）：仅当 `queryGeneration` 与 `baseCatalogRevision`
    /// **均为最新**时才可写回 UI。任一轴过期 → 拒绝（旧 generation / 旧 catalog revision）。
    public func isCurrent(latestGeneration: AppSearchGeneration,
                          latestRevision: CatalogRevision) -> Bool {
        queryGeneration == latestGeneration && baseCatalogRevision == latestRevision
    }
}
