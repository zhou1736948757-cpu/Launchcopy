// AppGridUI — LayoutDomain.LayoutGeneration（Phase 1F §3.1 / ADR-009 不变量⑨）
// 实现：T-1F-A（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 单调 latest-wins token，**只属于逻辑布局**：与 `CatalogRevision`（AppCatalogCore，
// ADR-004 revision 所有权冻结）、`FolderGeneration`（1E 呈现层）、search generation、
// surface generation 完全分离。layout 层绝不 mint/forge `CatalogRevision`。
// 只读 `value` 供中性计数器（write_count / stale_rejection_count）使用；原值不进任何诊断输出。

import Foundation

/// 单调 layout generation：仅成功 mutation 递增（`LayoutMutation` 唯一写入口）。
public struct LayoutGeneration: Hashable, Comparable, Sendable {
    public let value: UInt64
    public init(_ value: UInt64) { self.value = value }
    public static let zero = LayoutGeneration(0)
    public func incremented() -> LayoutGeneration { LayoutGeneration(value + 1) }
    public static func < (lhs: LayoutGeneration, rhs: LayoutGeneration) -> Bool {
        lhs.value < rhs.value
    }
}
