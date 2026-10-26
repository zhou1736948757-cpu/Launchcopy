// AppGridUI — DragSession.DragMutationEngine（Phase 1F §3.3–3.6 / ADR-010 Q4/Q11）
// 实现：T-1F-C（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 5 类 mutation 统一引擎：top-level reorder（M1/M2）/ create folder（M3）/
// add to folder（M4，含跨 folder 原子 move）/ move out（M5，含 cross-folder）。
// **全部经 `LayoutMutation(expectedGeneration:)` 单一写入口**（ADR-009）——
// 指针与无障碍路径产出逐位一致的 mutation（Q11：无第二套算法）。
// 本引擎不 mint/forge CatalogRevision；失败 → 无副作用 + 中性拒。
//
// BUG6 wave-a（§2c 方案 i，off-by-one）：.insertion 载荷 = 原布局条目序的插入槽位
// （槽位 i = 插到第 i 个条目前）。reorder* 先移除源：源在槽位左侧 → 槽位左移 1；
// 两类 reorder remove-then-insert 语义一致 → 同一换算。

import Foundation

/// intent + 源身份 → LayoutMutation 调用（纯映射；无状态）。
public enum DragMutationEngine {
    public static func apply(intent: DropIntent,
                             source: DragSourceIdentity,
                             layout: PersistentWorkspaceLayout,
                             folderTitle: String? = nil) -> LayoutMutationResult {
        let mutation = LayoutMutation(expectedGeneration: layout.generation)

        switch intent {
        case .insertion(let index):
            switch source {
            case .topLevelApp(let ref):
                // M1：顶层 app 重排。
                return mutation.reorderTopLevel(
                    in: layout, identity: .app(ref),
                    toIndex: reorderAdjustedIndex(
                        baseIndex: index,
                        sourceIndex: layout.topLevelOrder.firstIndex { $0 == .app(ref) }))
            case .topLevelFolder(let id):
                // M2：顶层 folder 重排（不改 folder ID/标题/成员）。
                return mutation.reorderTopLevel(
                    in: layout, identity: .folder(id),
                    toIndex: reorderAdjustedIndex(
                        baseIndex: index,
                        sourceIndex: layout.topLevelOrder.firstIndex { $0 == .folder(id) }))
            case .folderMember(let folderID, let ref):
                // §3.5：folder 内重排。
                return mutation.reorderFolderMembers(
                    in: layout, folderID: folderID, member: ref,
                    toIndex: reorderAdjustedIndex(
                        baseIndex: index,
                        sourceIndex: layout.folder(id: folderID)?.members.firstIndex(of: ref)))
            }

        case .createFolder(let target):
            // M3：目标+源为初始成员（先目标后源）；操作数必须顶层 app。
            guard case .topLevelApp(let ref) = source else {
                return .rejected(.invalidTarget)
            }
            return mutation.createFolder(in: layout, target: target, source: ref, title: folderTitle)

        case .intoFolder(let targetFolderID, let position):
            // M4：顶层 app 移入 / 跨 folder 原子 move；folder-on-folder 拒绝。
            guard let ref = source.appReference else {
                return .rejected(.invalidTarget)
            }
            return mutation.addToFolder(in: layout, app: ref, folderID: targetFolderID, at: position)

        case .topLevelTarget(let index):
            // M5：成员移出为顶层条目（剩 1 → 原子 dissolve；剩 0 → 删 folder）。
            guard case .folderMember(let folderID, let ref) = source else {
                return .rejected(.invalidTarget)
            }
            return mutation.moveOutOfFolder(in: layout, folderID: folderID, member: ref, toIndex: index)

        case .invalid:
            return .rejected(.invalidTarget)
        }
    }

    /// remove-then-insert 换算：源在槽位左侧 → 槽位左移 1；源未知 → 原样透传
    /// （由 mutation 拒绝）。.topLevelTarget（moveOutOfFolder）不经此换算。
    private static func reorderAdjustedIndex(baseIndex: Int, sourceIndex: Int?) -> Int {
        guard let sourceIndex, sourceIndex < baseIndex else { return baseIndex }
        return baseIndex - 1
    }
}
