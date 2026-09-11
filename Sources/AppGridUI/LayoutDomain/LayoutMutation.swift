// AppGridUI — LayoutDomain.LayoutMutation（Phase 1F §3.1 / ADR-009 Q9/Q16 / ADR-010 Q4）
// 实现：T-1F-A（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// **唯一写入口**：`LayoutMutation(expectedGeneration:)`。所有成功 mutation：
// - 原子提交（失败无半提交，不变量⑧）；结果只含完整已提交布局（不变量⑩）；
// - 成功 → `LayoutGeneration` 单调 +1（不变量⑨：与 CatalogRevision/FolderGeneration 分离；
//   本层绝不 mint/forge CatalogRevision——引擎入参根本没有 catalog）；
// - 无实际位移/变化 → `.noOp`（不增 generation，零写盘语义；10.1 锁定）。
// - `.cancelled` 为语义保留位：drag 会话的取消路径（ESC/失焦/refresh…）经统一 cancel
//   出口**不进入**引擎，由调用层映射为 cancelled，零写盘（ADR-010 Q7）。
//
// 语义速查（ADR-010 M1–M5 + ADR-009 Q16）：
// - `reorderTopLevel` / `reorderFolderMembers`：原子重排；无位移 → no-op。
// - `createFolder`：目标+源为初始成员，**先目标后源**（§3.3/ADR-010 M3 产品决策）；
//   落点 = drop 目标 target 原 index（格子位置语义；不做 targetIndex-1，先算后删再
//   clamp；BUG7 wave-a 语义修订）；中性默认标题 `Group N`。
// - `addToFolder`：顶层 app 移入 / 跨 folder 原子 move；已是成员 → no-op；
//   源 folder 剩 1 逻辑成员 → 一次原子逻辑 dissolve（ADR-009 Q9）。
// - `moveOutOfFolder`：成员回确定顶层位；剩 1 → dissolve（剩余成员回 folder 原顶层位）；
//   剩 0 → 删除 folder；全部一个原子 mutation。
// - `renameFolder`：真 mutation（64-grapheme 规范化复用 `FolderTitle.normalized` 既有语义；
//   空白回退为原标题）；改名 = layout mutation，generation 递增；改名后重投影即恢复（重启恢复）。
//
// 隐私：不做任何输出；错误载荷为进程内 domain 错误（FolderID 不透明；ref 不落诊断）。

import Foundation

/// mutation 结果（含四种状态）。
public enum LayoutMutationResult: Equatable, Sendable {
    /// 已提交的新布局（generation 已 +1；唯一"已提交"视图）。
    case success(PersistentWorkspaceLayout)
    /// 拒绝（stale/非法 target/将破坏不变量）；原布局不变、无半提交。
    case rejected(LayoutMutationRejection)
    /// 取消（引擎不产生此结果；由取消路径映射，零写盘）。
    case cancelled
    /// 无实际变化（不增 generation、零写盘语义）。
    case noOp(PersistentWorkspaceLayout)
}

/// 拒绝原因（进程内 domain 错误；不进 telemetry/日志）。
public enum LayoutMutationRejection: Equatable, Sendable {
    case staleGeneration(expected: LayoutGeneration, current: LayoutGeneration)
    case invalidTarget
    case duplicateReference
    case nestedFolder
    case folderDoesNotExist(FolderID)
    case topLevelEntryNotFound(WorkspaceTopLevelIdentity)
    case memberNotFound(PersistentAppReference)
}

/// folder 成员插入位置（确定性）。
public enum FolderInsertionPosition: Equatable, Sendable {
    case head
    case tail
}

/// 唯一写入口（expectedGeneration = 调用时持有的已提交 generation；失配 → stale 拒绝）。
public struct LayoutMutation {
    public let expectedGeneration: LayoutGeneration

    public init(expectedGeneration: LayoutGeneration) {
        self.expectedGeneration = expectedGeneration
    }

    // MARK: - 顶层重排（M1/M2）

    /// 重排顶层条目到 `toIndex`（0-based 最终下标；移除后插入，越界 clamp）。
    /// 无位移 → `.noOp`（不增 generation）。folder/app 任意交错统一处理。
    public func reorderTopLevel(in layout: PersistentWorkspaceLayout,
                                identity: WorkspaceTopLevelIdentity,
                                toIndex: Int) -> LayoutMutationResult {
        guard layout.generation == expectedGeneration else {
            return .rejected(.staleGeneration(expected: expectedGeneration, current: layout.generation))
        }
        guard let fromIndex = layout.topLevelOrder.firstIndex(where: { $0.identity == identity }) else {
            return .rejected(.topLevelEntryNotFound(identity))
        }
        var ordered = layout.topLevelOrder
        let entry = ordered.remove(at: fromIndex)
        let clamped = min(max(toIndex, 0), ordered.count)
        guard clamped != fromIndex else { return .noOp(layout) }
        ordered.insert(entry, at: clamped)
        return .success(layout.replacing(generation: layout.generation.incremented(),
                                         topLevelOrder: ordered))
    }

    // MARK: - 创建 folder（M3）

    /// 创建 folder：`target`（drop 目标）与 `source`（被拖 app）为初始成员，**先目标后源**。
    /// - 两者必须都是顶层 app 条目且互异；任一已在 folder 内 → `.nestedFolder`（不隐式嵌套/合并）；
    ///   任一未知 → `.invalidTarget`；相同 → `.duplicateReference`。
    /// - 新 folder 的顶层位置 = drop 目标 target 原 index（格子位置语义；不做 targetIndex-1，
    ///   先算后删再 clamp；BUG7 wave-a 语义修订）：被拖走的是 source、留原地被拖到的是
    ///   target → folder 顶替 target 原格。
    /// - 标题：`title` 传入则经 64-grapheme 规范化；nil → 中性默认 `Group N`（最小未用 N）。
    /// - `folderID` 可注入（确定性测试/恢复）；缺省新 UUID。
    public func createFolder(in layout: PersistentWorkspaceLayout,
                             target: PersistentAppReference,
                             source: PersistentAppReference,
                             title: String? = nil,
                             folderID: FolderID? = nil) -> LayoutMutationResult {
        guard layout.generation == expectedGeneration else {
            return .rejected(.staleGeneration(expected: expectedGeneration, current: layout.generation))
        }
        guard target != source else { return .rejected(.duplicateReference) }
        // 已在 folder 内的 app 不能作为建夹操作数（避免隐式嵌套/合并语义）。
        if layout.containsAppReferenceInAnyFolder(target) || layout.containsAppReferenceInAnyFolder(source) {
            return .rejected(.nestedFolder)
        }
        guard let targetIndex = layout.topLevelOrder.firstIndex(where: { $0 == .app(target) }),
              let sourceIndex = layout.topLevelOrder.firstIndex(where: { $0 == .app(source) }) else {
            return .rejected(.invalidTarget)
        }
        let resolvedTitle = title.map { FolderTitle.normalized($0, fallback: LayoutMutation.defaultFolderTitle(for: layout)) }
            ?? LayoutMutation.defaultFolderTitle(for: layout)
        let id = folderID ?? FolderID()
        let record = PersistentFolderRecord(id: id, title: resolvedTitle, members: [target, source])

        var ordered = layout.topLevelOrder
        // 顶层落点 = drop 目标 target 原 index（格子位置语义；不做 targetIndex-1；
        // BUG7 wave-a）。先算后删再 clamp，绝不读删除后的中间态下标；两项按大
        // index 先删，落点再 min(..., 余数 count) 兜底。
        let insertion = targetIndex
        ordered.remove(at: max(targetIndex, sourceIndex))
        ordered.remove(at: min(targetIndex, sourceIndex))
        ordered.insert(.folder(id), at: min(insertion, ordered.count))
        return .success(layout.replacing(generation: layout.generation.incremented(),
                                         topLevelOrder: ordered,
                                         folders: layout.folders + [record]))
    }

    /// 中性默认标题：`Group N`，N = 未使用的最小正整数（已解散编号可复用；确定性）。
    public static func defaultFolderTitle(for layout: PersistentWorkspaceLayout) -> String {
        var used = Set<String>()
        for folder in layout.folders { used.insert(folder.title) }
        var n = 1
        while used.contains("Group \(n)") { n += 1 }
        return "Group \(n)"
    }

    // MARK: - 移入 folder（M4；含跨 folder 原子 move）

    /// 把 app 加入 folder：顶层 app → 移入；他 folder 成员 → 跨 folder 原子 move（源 folder
    /// 按 dissolve 规则收缩）；已是该 folder 成员 → `.noOp`（不增 generation）。
    /// app 不在布局（未知引用）→ `.invalidTarget`（新 app 只经投影追加，不反向写布局）。
    public func addToFolder(in layout: PersistentWorkspaceLayout,
                            app: PersistentAppReference,
                            folderID: FolderID,
                            at position: FolderInsertionPosition = .tail) -> LayoutMutationResult {
        guard layout.generation == expectedGeneration else {
            return .rejected(.staleGeneration(expected: expectedGeneration, current: layout.generation))
        }
        guard let folderIndex = layout.folders.firstIndex(where: { $0.id == folderID }) else {
            return .rejected(.folderDoesNotExist(folderID))
        }
        guard !layout.folders[folderIndex].members.contains(app) else { return .noOp(layout) }

        // 顶层 app → 移入（单个原子提交）。
        if let topIndex = layout.topLevelOrder.firstIndex(where: { $0 == .app(app) }) {
            var ordered = layout.topLevelOrder
            ordered.remove(at: topIndex)
            var folders = layout.folders
            folders[folderIndex] = inserted(folders[folderIndex], app: app, position: position)
            return .success(layout.replacing(generation: layout.generation.incremented(),
                                             topLevelOrder: ordered, folders: folders))
        }
        // 跨 folder 原子 move（源 folder dissolve 归并进同一次提交）。
        if let sourceFolderIndex = layout.folders.firstIndex(where: { $0.members.contains(app) }) {
            return crossFolderMove(layout, app: app, sourceFolderIndex: sourceFolderIndex,
                                   targetFolderID: folderID, position: position)
        }
        return .rejected(.invalidTarget)
    }

    // MARK: - 移出 folder（M5）

    /// 把 folder 成员移出为顶层条目（插入 `toIndex`，0-based，clamp）。
    /// 源 folder 剩 1 逻辑成员 → 一次原子**逻辑 dissolve**（剩余成员回 folder 原顶层位、
    /// folder 记录删除）；剩 0 → 删除 folder。全部一个原子 mutation。
    public func moveOutOfFolder(in layout: PersistentWorkspaceLayout,
                                folderID: FolderID,
                                member: PersistentAppReference,
                                toIndex: Int) -> LayoutMutationResult {
        guard layout.generation == expectedGeneration else {
            return .rejected(.staleGeneration(expected: expectedGeneration, current: layout.generation))
        }
        guard let folderIndex = layout.folders.firstIndex(where: { $0.id == folderID }) else {
            return .rejected(.folderDoesNotExist(folderID))
        }
        let folder = layout.folders[folderIndex]
        guard folder.members.contains(member) else { return .rejected(.memberNotFound(member)) }

        var folders = layout.folders
        var ordered = layout.topLevelOrder
        let folderTopIndex = ordered.firstIndex(where: { $0 == .folder(folderID) })
        let remaining = folder.members.filter { $0 != member }

        switch remaining.count {
        case 0:
            folders.remove(at: folderIndex)
            if let i = folderTopIndex { ordered.remove(at: i) }
        case 1:
            let last = remaining[0]
            folders.remove(at: folderIndex)
            if let i = folderTopIndex {
                ordered.remove(at: i)
                ordered.insert(.app(last), at: min(i, ordered.count))   // 确定顶层位
            } else {
                ordered.append(.app(last))
            }
        default:
            folders[folderIndex] = folder.withMembers(remaining)
        }
        ordered.insert(.app(member), at: min(max(toIndex, 0), ordered.count))
        return .success(layout.replacing(generation: layout.generation.incremented(),
                                         topLevelOrder: ordered, folders: folders))
    }

    // MARK: - folder 内重排（§3.5）

    /// 重排 folder 成员到 `toIndex`（0-based 最终下标；移除后插入，clamp）。无位移 → `.noOp`。
    public func reorderFolderMembers(in layout: PersistentWorkspaceLayout,
                                     folderID: FolderID,
                                     member: PersistentAppReference,
                                     toIndex: Int) -> LayoutMutationResult {
        guard layout.generation == expectedGeneration else {
            return .rejected(.staleGeneration(expected: expectedGeneration, current: layout.generation))
        }
        guard let folderIndex = layout.folders.firstIndex(where: { $0.id == folderID }) else {
            return .rejected(.folderDoesNotExist(folderID))
        }
        let folder = layout.folders[folderIndex]
        guard let memberIndex = folder.members.firstIndex(where: { $0 == member }) else {
            return .rejected(.memberNotFound(member))
        }
        var members = folder.members
        let moved = members.remove(at: memberIndex)
        let clamped = min(max(toIndex, 0), members.count)
        guard clamped != memberIndex else { return .noOp(layout) }
        members.insert(moved, at: clamped)
        var folders = layout.folders
        folders[folderIndex] = folder.withMembers(members)
        return .success(layout.replacing(generation: layout.generation.incremented(), folders: folders))
    }

    // MARK: - renameFolder 真 mutation（ADR-009 Q16）

    /// 重命名 folder：标题经 `FolderTitle.normalized`（trim → 空白回退为原标题 →
    /// 64-grapheme Character 截断）规范化；与原标题相同 → `.noOp`；否则提交 + generation+1。
    /// 持久化语义：改名后从已提交布局重投影（模拟重启）即恢复新标题。
    public func renameFolder(in layout: PersistentWorkspaceLayout,
                             folderID: FolderID,
                             to title: String) -> LayoutMutationResult {
        guard layout.generation == expectedGeneration else {
            return .rejected(.staleGeneration(expected: expectedGeneration, current: layout.generation))
        }
        guard let folderIndex = layout.folders.firstIndex(where: { $0.id == folderID }) else {
            return .rejected(.folderDoesNotExist(folderID))
        }
        let folder = layout.folders[folderIndex]
        let normalized = FolderTitle.normalized(title, fallback: folder.title)
        guard normalized != folder.title else { return .noOp(layout) }
        var folders = layout.folders
        folders[folderIndex] = folder.withTitle(normalized)
        return .success(layout.replacing(generation: layout.generation.incremented(), folders: folders))
    }

    // MARK: - 内部

    private func inserted(_ folder: PersistentFolderRecord,
                          app: PersistentAppReference,
                          position: FolderInsertionPosition) -> PersistentFolderRecord {
        var members = folder.members
        switch position {
        case .tail: members.append(app)
        case .head: members.insert(app, at: 0)
        }
        return folder.withMembers(members)
    }

    /// 跨 folder 原子 move：源 folder 收缩（剩 1 → dissolve；剩 0 → 删除），目标 folder 追加；
    /// 全部在一次提交内完成（generation 只 +1）。
    private func crossFolderMove(_ layout: PersistentWorkspaceLayout,
                                 app: PersistentAppReference,
                                 sourceFolderIndex: Int,
                                 targetFolderID: FolderID,
                                 position: FolderInsertionPosition) -> LayoutMutationResult {
        var folders = layout.folders
        var ordered = layout.topLevelOrder
        let source = folders[sourceFolderIndex]
        let sourceTopIndex = ordered.firstIndex(where: { $0 == .folder(source.id) })
        let remaining = source.members.filter { $0 != app }

        switch remaining.count {
        case 0:
            folders.remove(at: sourceFolderIndex)
            if let i = sourceTopIndex { ordered.remove(at: i) }
        case 1:
            let last = remaining[0]
            folders.remove(at: sourceFolderIndex)
            if let i = sourceTopIndex {
                ordered.remove(at: i)
                ordered.insert(.app(last), at: min(i, ordered.count))
            } else {
                ordered.append(.app(last))
            }
        default:
            folders[sourceFolderIndex] = source.withMembers(remaining)
        }

        // 目标 folder 重新定位（源 folder 可能已被删除而改变索引）。
        guard let targetIndex = folders.firstIndex(where: { $0.id == targetFolderID }) else {
            return .rejected(.folderDoesNotExist(targetFolderID))
        }
        folders[targetIndex] = inserted(folders[targetIndex], app: app, position: position)
        return .success(layout.replacing(generation: layout.generation.incremented(),
                                         topLevelOrder: ordered, folders: folders))
    }
}
