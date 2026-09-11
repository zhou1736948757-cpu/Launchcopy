// AppGridUI — AppSearchQuery（Phase 1D 纯搜索域；§6.1 输入规范化 / §9.1 纯搜索域）
// 实现：T-1D-A（Worker A）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 纯 Foundation 值类型，无 AppKit、无 I/O。原始 query 仅存在于搜索控制器/NSSearchField
// 内存中；本类型只提供纯函数归一化，不记录、不持久化、不输出 query 原文。
//
// 归一化规则（§6.1）：
//   1. 去除头尾 whitespacesAndNewlines；
//   2. 使用可注入 Locale 执行 case-insensitive + diacritic-insensitive + width-insensitive folding；
//   3. 空/纯空白/换行 query → 无过滤（全目录）。

import Foundation

/// 搜索查询值：携带原始字符串 + 可注入 `Locale`，并提供纯函数归一化。
public struct AppSearchQuery: Equatable, Sendable {
    /// 原始查询字符串（仅存在于搜索控制器/NSSearchField 内存中；绝不进入 telemetry/log）。
    public let raw: String
    /// 归一化所用 Locale（可注入；测试注入固定 locale 保证确定性）。
    public let locale: Locale

    public init(raw: String, locale: Locale = .current) {
        self.raw = raw
        self.locale = locale
    }

    /// 去除头尾 `whitespacesAndNewlines` 后的字符串。
    public var trimmed: String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 归一化文本：trim → case/diacritic/width folding。
    /// 空/纯空白/换行 query 归一化为空字符串（→ 无过滤）。
    public var normalized: String {
        let t = trimmed
        guard !t.isEmpty else { return "" }
        return t.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                         locale: locale)
    }

    /// 空/纯空白/换行 query → 无过滤（全目录）。
    public var isEmpty: Bool {
        trimmed.isEmpty
    }
}
