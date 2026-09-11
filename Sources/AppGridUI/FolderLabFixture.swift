// AppGridUI — FolderLabFixture（Phase 1E §3.1B 会话内 folder lab/demo 入口；ADR-008 §2.5）
// 实现：T-1E-A（Worker A）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 纯、确定、无 I/O、无本机依赖、无磁盘持久化。
//
// 规则（用户定案 2026-08-30，ADR-008 §2.5）：按当前稳定 catalog 顺序取前 N 个 app 为一组，
// 下一组取后续 N 个，依此类推；中性标题 `Group 1`、`Group 2`、…。默认 **off**（产品启动
// 不得偷偷重排用户应用）。不读取应用类别 / Launchpad / Dock 私有数据库 / 系统布局。
//
// 顶层翻页保留（T-1E 修复）：末尾 `groupSize` 个 app 始终保持未分组，只对前
// `max(0, count - groupSize)` 个 app 分组——顶层始终留有未分组 app 条目，翻页可测。
//
// 隐私：不记录真实 app 名 / bundle ID / 路径 / URL；标题为中性 `Group N`。

import AppCatalogCore
import Foundation

/// 会话内 folder lab/demo 入口：用已提交 catalog 生成测试分组。
public enum FolderLabFixture {

    /// 默认每组 app 数（与 PagingSurface 默认每页 35 对齐）。
    public static let defaultGroupSize = 35

    /// 默认关闭（产品启动不得重排用户应用）。
    public static let defaultEnabled = false

    /// lab 配置。
    public struct Configuration: Sendable, Equatable {
        public var groupSize: Int
        public var enabled: Bool

        public init(groupSize: Int = FolderLabFixture.defaultGroupSize,
                    enabled: Bool = FolderLabFixture.defaultEnabled) {
            self.groupSize = groupSize
            self.enabled = enabled
        }
    }

    /// 从已提交 catalog 生成会话内分组。
    ///
    /// - 默认关闭：`enabled == false` → 返回 `nil`（不重排用户应用）。
    /// - 开启时：按稳定 catalog 顺序每 `groupSize` 个 app 一组，中性标题 `Group N`。
    /// - 顶层翻页保留：末尾 `groupSize` 个 app 始终保持未分组，只对前
    ///   `max(0, count - groupSize)` 个 app 分组（顶层留有未分组 app 条目，翻页可测）。
    /// - 每组一个全新 `FolderID`（不派生自标题/成员）。
    /// - 返回 snapshot 的 generation 由调用方提供（默认 `.zero`）。
    /// - 单成员组保留在 snapshot 中，由 `TopLevelComposition.build` 在组合时解散（ADR-008 §2.4）。
    public static func makeGroups(from catalog: CatalogSnapshot,
                                  configuration: Configuration = .init(),
                                  generation: FolderGeneration = .zero) -> FolderSnapshot? {
        guard configuration.enabled, configuration.groupSize > 0 else { return nil }
        let records = catalog.records
        guard !records.isEmpty else {
            return FolderSnapshot(generation: generation, entries: [])
        }
        // 末尾 groupSize 个 app 保持未分组；只对前 max(0, count - groupSize) 个分组。
        let groupableCount = max(0, records.count - configuration.groupSize)
        var entries: [FolderEntry] = []
        var groupIndex = 0
        var start = 0
        while start < groupableCount {
            let end = min(start + configuration.groupSize, groupableCount)
            let members = records[start..<end].map(\.id)
            groupIndex += 1
            let title = FolderTitle.normalized("Group \(groupIndex)", fallback: "Group \(groupIndex)")
            entries.append(FolderEntryBuilder.make(id: FolderID(), title: title, members: members))
            start = end
        }
        return FolderSnapshot(generation: generation, entries: entries)
    }
}
