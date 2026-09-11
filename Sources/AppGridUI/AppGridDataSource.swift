// AppGridUI — AppGridDataSource（§E：AppGridUI 与 MacAppCatalog 解耦）
// 实现：T-worker-b-appgridui（Phase 1B Wave 2）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// AppGridUI 不 import MacAppCatalog：扫描/目录所有权经本协议注入。
// 装配层（Wave 3 PagingPrototypeApp）以 extension CatalogRepository: AppGridDataSource
// 或闭包适配器注入。AppGridUI 不含 scanner 所有权（§14.A）。

import AppCatalogCore
import Foundation

/// 目录数据源（只读视图 + 刷新触发）。
///
/// 线程模型：currentSnapshot 为不可变 Sendable 快照，任意线程可读；
/// `refresh()` 为 async，latest-wins/可取消语义由实现方保证（如 CatalogRepository actor）。
public protocol AppGridDataSource: AnyObject {
    /// 当前已提交快照（nil = 尚未完成任何成功扫描）。
    var currentSnapshot: CatalogSnapshot? { get }

    /// 当前 revision（默认实现 = currentSnapshot?.revision）。
    var currentRevision: CatalogRevision? { get }

    /// 触发一次刷新并返回中性结果（无路径/名称/身份原文，仅计数）。
    func refresh() async -> AppGridRefreshOutcome
}

public extension AppGridDataSource {
    var currentRevision: CatalogRevision? { currentSnapshot?.revision }
}

/// 刷新结果（中性：仅计数，无路径/名称/身份原文 —— Explorer C 边界）。
public struct AppGridRefreshOutcome: Sendable, Equatable {
    /// 扫描整体成功（cancelled 时恒 false）。
    public let succeeded: Bool
    /// 快照记录数。
    public let appCount: Int
    /// 失败分类计数合计（unreadable/corrupted/…；不含任何原文）。
    public let failureCount: Int
    /// 本次刷新被更新的 refresh 取代/取消。
    public let cancelled: Bool

    public init(succeeded: Bool = false, appCount: Int = 0,
                failureCount: Int = 0, cancelled: Bool = false) {
        self.succeeded = succeeded
        self.appCount = appCount
        self.failureCount = failureCount
        self.cancelled = cancelled
    }
}
