// AppGridUI — AppSearchMatcher（Phase 1D 纯搜索域；§6.1 匹配语义 / §9.1 纯搜索域）
// 实现：T-1D-A（Worker A）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 纯函数匹配：仅对 `AppRecord.displayName` 做**字面子串**匹配，大小写/变音/宽度不敏感，
// 可注入 `Locale`（经 `AppSearchQuery.locale` 注入）。确定性、无 AppKit、可单测。
//
// 明确不匹配：bundleIdentifier、canonical URL、路径、AppID、图标 metadata。
// 明确不做：拼音、首字母、token ranking、编辑距离、学习排序。
// 空/纯空白/换行 query → 匹配全部记录（无过滤）。

import AppCatalogCore
import Foundation

/// 纯匹配器：`matches(_:query:)` 只对 `displayName` 做字面子串匹配。
public struct AppSearchMatcher: Sendable {

    public init() {}

    /// 判断记录是否命中查询。
    ///
    /// - 空/纯空白/换行 query → 恒 true（全目录，无过滤）。
    /// - 否则：将 `displayName` 与 query 在**同一 Locale**（`query.locale`）下做
    ///   case/diacritic/width folding，再对折叠后的 `displayName` 做字面 substring 搜索。
    /// - 只读 `displayName`；不读 bundleIdentifier / canonicalURL / AppID / 图标 metadata。
    public func matches(_ record: AppRecord, query: AppSearchQuery) -> Bool {
        let normalizedQuery = query.normalized
        guard !normalizedQuery.isEmpty else { return true }
        let normalizedName = record.displayName.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: query.locale)
        return normalizedName.range(of: normalizedQuery, options: [.literal], locale: query.locale) != nil
    }
}
