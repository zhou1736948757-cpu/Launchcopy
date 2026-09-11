// AppGridUI — LayoutDomain.PersistentWorkspaceLayout（Phase 1F §3.1 / ADR-009 所有权模型）
// 实现：T-1F-A（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 唯一持久真相源（逻辑布局层所有）：顶层 app/folder **任意交错**有序条目 + folder
// 稳定身份/标题/有序成员 + layout generation。专用 DTO：
// - **不得自动 Codable** `FolderSnapshot`/`TopLevelEntry`/`FolderOpenState`（1E 派生投影
//   固化进持久真相 = ADR-009 Q15 明确禁止）；本域 DTO 也不自备 Codable——受控编码投影由
//   T-1F-B 的 LayoutStore adapter 负责（§10.2 schema v1），FolderID 经受控投影重建。
// - 顺序真相只在 `topLevelOrder` 显式数组中（无 hashValue 参与持久顺序）。
// - 不变量校验统一走 `WorkspaceLayoutValidator`（本模块校验器）；mutation 只经
//   `LayoutMutation(expectedGeneration:)` 产出的布局均满足全部结构性不变量。

import AppCatalogCore
import Foundation

/// 中性顶层条目身份（app 持久引用或 folder 稳定身份）。
public enum WorkspaceTopLevelIdentity: Equatable, Sendable {
    case app(PersistentAppReference)
    case folder(FolderID)
}

/// 中性顶层条目：app 引用或 folder 身份。
public enum WorkspaceTopLevelEntry: Equatable, Sendable {
    case app(PersistentAppReference)
    case folder(FolderID)

    public var identity: WorkspaceTopLevelIdentity {
        switch self {
        case .app(let ref): return .app(ref)
        case .folder(let id): return .folder(id)
        }
    }
}

/// 持久 folder 记录：稳定身份 + 标题（≤64 grapheme，沿用 `FolderTitle.normalized` 语义）
/// + 有序无重复成员（只含 app 引用；folder 绝不嵌套）。
public struct PersistentFolderRecord: Equatable, Sendable {
    public let id: FolderID
    public let title: String
    public let members: [PersistentAppReference]

    public init(id: FolderID, title: String, members: [PersistentAppReference]) {
        self.id = id
        self.title = title
        self.members = members
    }

    public var memberCount: Int { members.count }

    func withTitle(_ newTitle: String) -> PersistentFolderRecord {
        PersistentFolderRecord(id: id, title: newTitle, members: members)
    }

    func withMembers(_ newMembers: [PersistentAppReference]) -> PersistentFolderRecord {
        PersistentFolderRecord(id: id, title: title, members: newMembers)
    }
}

/// 唯一持久真相源：顶层有序条目（app/folder 任意交错）+ folder 集合 + generation。
public struct PersistentWorkspaceLayout: Equatable, Sendable {
    public let generation: LayoutGeneration
    public let topLevelOrder: [WorkspaceTopLevelEntry]
    public let folders: [PersistentFolderRecord]

    public init(generation: LayoutGeneration,
                topLevelOrder: [WorkspaceTopLevelEntry],
                folders: [PersistentFolderRecord]) {
        self.generation = generation
        self.topLevelOrder = topLevelOrder
        self.folders = folders
    }

    /// 空布局（中性初始态；无 folder、无条目、generation zero）。
    public init() {
        self.init(generation: .zero, topLevelOrder: [], folders: [])
    }

    // MARK: - 查询（中性）

    public func folder(id: FolderID) -> PersistentFolderRecord? {
        folders.first { $0.id == id }
    }

    /// 任意 folder 内是否已含该 app 引用（唯一性裁决助手；线性扫描，禁 hash 身份）。
    public func containsAppReferenceInAnyFolder(_ ref: PersistentAppReference) -> Bool {
        folders.contains { $0.members.contains(ref) }
    }

    /// 中性计数：布局内全部 app 引用数（顶层 + 所有 folder 成员）。
    public var appReferenceCount: Int {
        topLevelOrder.reduce(into: 0) { count, entry in
            if case .app = entry { count += 1 }
        } + folders.reduce(0) { $0 + $1.members.count }
    }

    // MARK: - 确定性默认布局（ADR-009 Q11 reset 语义；无用户布局时安全默认）

    /// 由 catalog 构建确定性默认布局：全部 app 为顶层条目（保持 catalog 稳定序），无 folder。
    /// 同 bundle-ID 多实例（`.keepMultiInstance` 快照）去重为单个引用（保留首个，确定性）。
    public static func makeDefault(catalog: CatalogSnapshot) -> PersistentWorkspaceLayout {
        var seen = Set<String>()
        var topLevel: [WorkspaceTopLevelEntry] = []
        for record in catalog.records {
            let ref = PersistentAppReference.from(record: record)
            if seen.insert(ref.comparisonKey).inserted {
                topLevel.append(.app(ref))
            }
        }
        return PersistentWorkspaceLayout(generation: .zero, topLevelOrder: topLevel, folders: [])
    }

    /// 显式空默认（store 未就绪/空文件时的安全呈现基线）。
    public static func empty() -> PersistentWorkspaceLayout {
        PersistentWorkspaceLayout()
    }

    // MARK: - 内部构建助手（仅 LayoutMutation / 校验器用；internal 不构成公开写入口之外的修改面）

    func replacing(generation newGeneration: LayoutGeneration,
                               topLevelOrder newTopLevel: [WorkspaceTopLevelEntry]? = nil,
                               folders newFolders: [PersistentFolderRecord]? = nil) -> PersistentWorkspaceLayout {
        PersistentWorkspaceLayout(generation: newGeneration,
                                  topLevelOrder: newTopLevel ?? topLevelOrder,
                                  folders: newFolders ?? folders)
    }
}
