// AppGridUI — FolderDomain（Phase 1E §3.1A 纯文件夹/分组领域模型；ADR-008）
// 实现：T-1E-A（Worker A）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 纯 Foundation 值类型，无 AppKit、无 I/O、无磁盘持久化、无本机依赖。
//
// 内容：
// - `FolderID`：稳定、非名称/路径派生的不透明身份（UUID 承载；绝不从 title/name/path 派生）。
// - `FolderGeneration`：单调 latest-wins token，与 `CatalogRevision` 完全独立（镜像
//   `AppSearchGeneration` 模式）；folder 层绝不 mint/forge `CatalogRevision`。
// - `FolderTitle`：标题规范化（trim / 空白回退 / 长度上限 / Unicode 安全）。
// - `FolderEntry` / `FolderEntryBuilder`：FolderID + 标题 + 有序无重复成员。
// - `FolderSnapshot`：不可变 FolderEntry 集合 + folder generation。
// - `TopLevelEntryIdentity` / `TopLevelEntry`：中性顶层条目身份/条目（app 或 folder）。
// - `ActivationRouter`：激活分流决策（folder → openFolder；app → launchApp；nil → reject）。
// - `FolderMembership.rebase`：目录刷新成员收缩规则（移除成员 / 空文件夹移除 /
//   单成员文件夹解散）。
// - `TopLevelComposition.build`：顶层组合（应用 + 文件夹；单成员解散为 app 条目）。
//
// 隐私硬边界：folder title / membership / identity 原值绝不进入 telemetry/JSONL/stdout/
// signpost/profile/report；仅中性计数（folder_count / member_count / open-close outcome enum /
// stale rejection count / apply-duration numeric）。FolderID 对外不可还原原文。

import AppCatalogCore
import Foundation

// MARK: - FolderID（稳定、非名称派生的不透明身份）

/// 稳定、不包含名称/路径原文的 folder identity。
///
/// 由 `UUID` 承载，绝不从 title/name/path 派生；对外不可还原原文。
public struct FolderID: Hashable, Sendable {
    private let storage: UUID

    /// 新身份（随机 UUID）。
    public init() {
        self.storage = UUID()
    }

    /// 显式身份（测试/确定性注入用；仍不携带名称/路径原文）。
    public init(uuid: UUID) {
        self.storage = uuid
    }

    /// 仅调试；不含原文。
    public var redactedDescription: String {
        "FolderID(<redacted>)"
    }
}

// MARK: - FolderGeneration（单调 latest-wins token，独立于 CatalogRevision）

/// 单调 latest-wins token：folder 组合变化时递增；与 `CatalogRevision` 完全独立。
/// folder 层绝不 mint/forge `CatalogRevision`。
public struct FolderGeneration: Hashable, Comparable, Sendable {
    public let value: UInt64
    public init(_ value: UInt64) { self.value = value }
    public static let zero = FolderGeneration(0)
    public func incremented() -> FolderGeneration { FolderGeneration(value + 1) }
    public static func < (lhs: FolderGeneration, rhs: FolderGeneration) -> Bool {
        lhs.value < rhs.value
    }
}

// MARK: - FolderTitle（标题规范化）

/// 标题规范化：trim → 空白回退 → 长度上限 → Unicode 安全。
///
/// - `trimmingCharacters(in: .whitespacesAndNewlines)` 去除首尾空白。
/// - 空白标题回退到调用方提供的中性 fallback（如 `Group N`）。
/// - 长度上限按 `Character`（grapheme cluster）截断，绝不劈开一个 grapheme → Unicode 安全、
///   不崩溃、不泄漏日志。
public enum FolderTitle {
    /// 标题长度上限（Character 数）。
    public static let maxLength = 64

    /// 规范化标题。`raw` 为空白 → 返回 `fallback`；超长 → 截断到 `maxLength`。
    public static func normalized(_ raw: String, fallback: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return String(trimmed.prefix(maxLength))
    }
}

// MARK: - FolderEntry / FolderEntryBuilder

/// 文件夹条目：FolderID + 标题 + 有序成员（`[AppID]`）。
public struct FolderEntry: Hashable, Sendable {
    public let id: FolderID
    public let title: String
    public let members: [AppID]

    public init(id: FolderID, title: String, members: [AppID]) {
        self.id = id
        self.title = title
        self.members = members
    }

    public var memberCount: Int { members.count }
}

/// 成员规范化构建器：稳定顺序（保留输入顺序）+ 去重。
public enum FolderEntryBuilder {
    /// 构建 FolderEntry，成员去重且保持输入稳定顺序。
    public static func make(id: FolderID, title: String, members: [AppID]) -> FolderEntry {
        var seen = Set<AppID>()
        var ordered: [AppID] = []
        for member in members where seen.insert(member).inserted {
            ordered.append(member)
        }
        return FolderEntry(id: id, title: title, members: ordered)
    }
}

// MARK: - FolderSnapshot

/// 不可变 FolderEntry 集合 + folder generation（latest-wins 提交单元）。
public struct FolderSnapshot: Sendable, Equatable {
    public let generation: FolderGeneration
    public let entries: [FolderEntry]

    public init(generation: FolderGeneration, entries: [FolderEntry]) {
        self.generation = generation
        self.entries = entries
    }

    public var folderCount: Int { entries.count }
    public var isEmpty: Bool { entries.isEmpty }

    public func entry(for id: FolderID) -> FolderEntry? {
        entries.first { $0.id == id }
    }
}

// MARK: - 中性顶层条目身份 / 条目

/// 中性顶层条目身份：app `AppID` 或 folder `FolderID`。
public enum TopLevelEntryIdentity: Hashable, Sendable {
    case app(AppID)
    case folder(FolderID)
}

/// 中性顶层条目：`.app(AppRecord)` 或 `.folder(FolderEntry)`。
public enum TopLevelEntry: Sendable, Equatable {
    case app(AppRecord)
    case folder(FolderEntry)

    /// 该条目的中性身份（app → `.app(id)`；folder → `.folder(id)`）。
    public var identity: TopLevelEntryIdentity? {
        switch self {
        case .app(let record): return .app(record.id)
        case .folder(let entry): return .folder(entry.id)
        }
    }
}

// MARK: - 激活分流决策（纯）

/// 激活分流结果。
public enum ActivationDecision: Sendable, Equatable {
    case openFolder
    case launchApp
    case reject   // placeholder / stale / 无有效身份
}

/// 统一激活分流器：folder 分支只能打开文件夹；app 分支委托现有启动管线；
/// folder identity 绝不路由到 launch。
public enum ActivationRouter {
    /// 按顶层条目类型分流。
    public static func decide(for entry: TopLevelEntry) -> ActivationDecision {
        switch entry {
        case .app: return .launchApp
        case .folder: return .openFolder
        }
    }

    /// 按中性身份分流；nil（placeholder/stale）→ `.reject`。
    public static func decide(for identity: TopLevelEntryIdentity?) -> ActivationDecision {
        switch identity {
        case .app: return .launchApp
        case .folder: return .openFolder
        case nil: return .reject
        }
    }
}

// MARK: - 目录刷新成员收缩规则（ADR-008 §2.4）

/// rebase 结果：收缩后的 folder snapshot + 解散的单成员 app + 被移除的空文件夹。
public struct FolderRebaseResult: Sendable, Equatable {
    /// 收缩后的 snapshot（仅含 ≥ 2 成员的文件夹）。
    public let snapshot: FolderSnapshot
    /// 单成员文件夹解散后成为顶层 app 条目的成员 AppID（按 folder 顺序）。
    public let dissolvedAppIDs: [AppID]
    /// 从 snapshot 移除的文件夹（空文件夹 + 解散的单成员文件夹）。
    public let removedFolderIDs: [FolderID]
}

/// 目录刷新成员收缩规则（deterministic）：
/// - 已删除应用从成员移除；
/// - 空文件夹从呈现移除；
/// - 单成员文件夹解散（成员成为顶层 app 条目；folder 条目仅 ≥ 2 成员存在）。
public enum FolderMembership {
    /// 把 folder snapshot 对新的 catalog snapshot 做成员收缩，返回新 snapshot（新 generation）。
    public static func rebase(_ folders: FolderSnapshot,
                              against catalog: CatalogSnapshot,
                              generation: FolderGeneration) -> FolderRebaseResult {
        let catalogIDs = Set(catalog.records.map(\.id))
        var newEntries: [FolderEntry] = []
        var dissolved: [AppID] = []
        var removed: [FolderID] = []
        for entry in folders.entries {
            let members = entry.members.filter { catalogIDs.contains($0) }
            if members.isEmpty {
                removed.append(entry.id)                       // 空文件夹移除
            } else if members.count == 1 {
                dissolved.append(members[0])                   // 单成员解散
                removed.append(entry.id)
            } else {
                newEntries.append(FolderEntry(id: entry.id, title: entry.title, members: members))
            }
        }
        let snapshot = FolderSnapshot(generation: generation, entries: newEntries)
        return FolderRebaseResult(snapshot: snapshot, dissolvedAppIDs: dissolved,
                                  removedFolderIDs: removed)
    }
}

// MARK: - 顶层组合（应用 + 文件夹；单成员解散）

/// 顶层组合构建：把 catalog + folder snapshot 组合为中性顶层条目序列。
///
/// 规则（deterministic）：
/// - 每个 ≥ 2 成员的文件夹 → `.folder`（保持 snapshot 顺序）；
/// - 单成员文件夹解散 → 其成员作为 `.app` 条目（出现在未分组 app 区）；
/// - 空文件夹 → 不贡献任何条目；
/// - 未分组 app（不在任何 ≥ 2 成员文件夹内）→ `.app`（保持 catalog 稳定顺序）。
/// 顺序：文件夹在前（snapshot 顺序），未分组 app 在后（catalog 顺序）。
public enum TopLevelComposition {
    public static func build(catalog: CatalogSnapshot, folders: FolderSnapshot) -> [TopLevelEntry] {
        var grouped = Set<AppID>()
        var folderEntries: [FolderEntry] = []
        for entry in folders.entries {
            if entry.members.count >= 2 {
                folderEntries.append(entry)
                grouped.formUnion(entry.members)
            }
            // 单成员 / 空文件夹：不贡献 folder 条目（单成员成员进入未分组 app 区）。
        }
        var result: [TopLevelEntry] = []
        for entry in folderEntries {
            result.append(.folder(entry))
        }
        for record in catalog.records where !grouped.contains(record.id) {
            result.append(.app(record))
        }
        return result
    }
}
