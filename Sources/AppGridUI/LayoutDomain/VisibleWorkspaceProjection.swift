// AppGridUI — LayoutDomain.VisibleWorkspaceProjection（Phase 1F §3.1 / ADR-009 Q8/Q9）
// 实现：T-1F-A（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 派生可见投影（纯函数）：expected layout（唯一持久真相）+ 当前 `CatalogSnapshot`
// → 运行时呈现。规则（ADR-009 Q8 表）：
// - app 暂缺（catalog 无此引用）→ **隐藏，latent reference 保留**（一次扫描缺失绝不改布局）；
// - app 重现 → 自动回原逻辑位置/成员（投影按 layout 序推导，不依赖旧 index）；
// - 新 app（catalog 有、layout 无）→ 确定性追加到「未编排尾部」（顶层序末尾，folder 之外，
//   catalog 稳定序）；绝不随机打乱；
// - folder 可用成员 < 2 → **视觉 dissolve**（呈现为 app/隐藏），**不触碰 layout**；
//   成员重现 → folder 呈现恢复（Q9 区分：视觉 vs 逻辑 dissolve）。
// - 绝不伪造 CatalogRevision：本投影只透传输入 catalog 的 revision，不增不减。
// - 隐私：不做任何输出。

import AppCatalogCore
import Foundation

/// 派生可见投影：唯一持久真相 layout + 当前 catalog → 运行时呈现（值类型，纯函数产物）。
public struct VisibleWorkspaceProjection: Equatable, Sendable {

    /// 可见顶层条目（app 记录或 folder 呈现；单可用成员 folder → 视觉 dissolve 为 app）。
    public enum VisibleTopLevelEntry: Equatable, Sendable {
        case app(AppRecord)
        case folder(VisibleFolder)

        public var identity: WorkspaceTopLevelIdentity? {
            switch self {
            case .app(let record): return .app(PersistentAppReference.from(record: record))
            case .folder(let folder): return .folder(folder.id)
            }
        }
    }

    /// folder 呈现：只含 **catalog 可用**成员（保留 layout 成员序）；latent 计数含暂缺成员。
    public struct VisibleFolder: Equatable, Sendable {
        public let id: FolderID
        public let title: String
        public let availableMembers: [AppRecord]
        public let latentMemberCount: Int

        public init(id: FolderID, title: String,
                    availableMembers: [AppRecord], latentMemberCount: Int) {
            self.id = id
            self.title = title
            self.availableMembers = availableMembers
            self.latentMemberCount = latentMemberCount
        }
    }

    public let layoutGeneration: LayoutGeneration
    public let catalogRevision: CatalogRevision
    /// 可见顶层条目（layout 序 + 确定性未编排尾部）。
    public let topLevel: [VisibleTopLevelEntry]
    /// 暂缺引用（layout 有、catalog 无；保持 layout 迭代序，确定性列出）。
    public let latentAppReferences: [PersistentAppReference]
    /// 未编排 app（catalog 新 app；也含在 topLevel 尾部，此处独立列出供装配层计数）。
    public let unorchestratedAppRecords: [AppRecord]

    public init(layoutGeneration: LayoutGeneration,
                catalogRevision: CatalogRevision,
                topLevel: [VisibleTopLevelEntry],
                latentAppReferences: [PersistentAppReference],
                unorchestratedAppRecords: [AppRecord]) {
        self.layoutGeneration = layoutGeneration
        self.catalogRevision = catalogRevision
        self.topLevel = topLevel
        self.latentAppReferences = latentAppReferences
        self.unorchestratedAppRecords = unorchestratedAppRecords
    }

    /// 投影构建（纯函数；不修改 layout/catalog 任何状态）。
    public static func project(layout: PersistentWorkspaceLayout,
                               catalog: CatalogSnapshot) -> VisibleWorkspaceProjection {
        // Resolve once, not by rescanning the catalog for every stored reference.
        // Both keys preserve matches(record:) semantics, including a path reference
        // to an app which now also has a bundle ID. Stable first match wins.
        var recordsByReference: [String: AppRecord] = [:]
        for record in catalog.records {
            if let bundleID = record.bundleIdentifier {
                let key = PersistentAppReference.bundleID(bundleID).comparisonKey
                if recordsByReference[key] == nil { recordsByReference[key] = record }
            }
            let pathKey = PersistentAppReference.canonicalPath(
                PersistentAppReference.normalizedPath(record.canonicalURL)).comparisonKey
            if recordsByReference[pathKey] == nil { recordsByReference[pathKey] = record }
        }
        let foldersByID = Dictionary(layout.folders.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Index stored identities once. A saved path still represents a record
        // after it gains a bundle ID; do not append its newly preferred identity.
        let referenceResolver = WorkspaceAppReferenceResolver(layout: layout)

        var topLevel: [VisibleTopLevelEntry] = []
        var latent: [PersistentAppReference] = []

        for entry in layout.topLevelOrder {
            switch entry {
            case .app(let ref):
                // 暂缺 → 隐藏但 latent 保留；重现 → 回原逻辑位置。
                if let record = recordsByReference[ref.comparisonKey] {
                    topLevel.append(.app(record))
                } else {
                    latent.append(ref)
                }
            case .folder(let folderID):
                guard let folder = foldersByID[folderID] else { continue }  // 防御（validator 拦）
                var available: [AppRecord] = []
                var latentCount = 0
                for member in folder.members {
                    if let record = recordsByReference[member.comparisonKey] {
                        available.append(record)
                    } else {
                        latentCount += 1
                        latent.append(member)
                    }
                }
                if available.count >= 2 {
                    topLevel.append(.folder(VisibleFolder(id: folderID, title: folder.title,
                                                          availableMembers: available,
                                                          latentMemberCount: latentCount)))
                } else if available.count == 1 {
                    // 视觉 dissolve：单可用成员以 app 呈现（layout 不动；成员重现则恢复 folder）。
                    topLevel.append(.app(available[0]))
                }
                // 0 可用（全 latent）→ folder 隐藏；latent 已收集，layout 不动。
            }
        }

        // 未编排尾部：catalog 新 app 确定性追加（catalog 稳定序）。
        var unorchestrated: [AppRecord] = []
        for record in catalog.records {
            if referenceResolver.reference(for: record) == nil {
                unorchestrated.append(record)
            }
        }
        for record in unorchestrated { topLevel.append(.app(record)) }

        return VisibleWorkspaceProjection(layoutGeneration: layout.generation,
                                          catalogRevision: catalog.revision,
                                          topLevel: topLevel,
                                          latentAppReferences: latent,
                                          unorchestratedAppRecords: unorchestrated)
    }

    // MARK: - 查询（中性）

    /// 可见顶层条目数（含视觉 dissolve 呈现的 app 与未编排尾部）。
    public var visibleTopLevelCount: Int { topLevel.count }

    /// 顶层某身份是否可见（隐藏的 latent app / 全 latent folder 不在此列）。
    public func containsVisible(identity: WorkspaceTopLevelIdentity) -> Bool {
        topLevel.contains { $0.identity == identity }
    }

}
