// AppGridUI — AppGridUIState（§3.1.11 中性 UI 状态）+ 呈现更新类型
// 实现：T-worker-b-appgridui（Phase 1B Wave 2）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 状态机语义（确定性，供测试断言）：
// - .loading        —— 首次扫描/初始加载中（尚无内容）；
// - .ready          —— 扫描成功、有内容、无失败；
// - .empty          —— 扫描成功但 0 条（空目录合法态；pageCount 0）；
// - .partialFailure —— 刷新失败或部分失败（有失败分类计数；可能仍保留旧内容展示）；
// - .refreshing     —— 已有内容时的后台刷新中；
// - .noResults      —— base catalog 非空 + active 非空 query + 0 结果（§10；中性文本，
//                      不含 query 原文；不改既有态语义）。
//
// 描述文本全部中性：不含 app 名 / bundle ID / 路径 / query 原文（§3.3 + Explorer C 红线）。

import Foundation

/// AppGrid 整体中性 UI 状态。
public enum AppGridUIState: Equatable, Sendable {
    case loading
    case ready
    case empty
    case partialFailure
    case refreshing
    case noResults

    /// 可访问描述（§9：loading/empty/partial failure 有可访问描述）。
    public var accessibilityDescription: String {
        switch self {
        case .loading: return "Loading application catalog…"
        case .ready: return "Application catalog ready"
        case .empty: return "No applications found"
        case .partialFailure: return "Some applications could not be loaded"
        case .refreshing: return "Refreshing application catalog…"
        case .noResults: return "No applications match the search"
        }
    }

    /// 忙碌态（显示 spinner）。
    public var isBusy: Bool {
        switch self {
        case .loading, .refreshing: return true
        case .ready, .empty, .partialFailure, .noResults: return false
        }
    }
}
