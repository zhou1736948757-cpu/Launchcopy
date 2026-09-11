// AppGridUI — LayoutDomain.PresentationAnchor（Phase 1F §3.1 / ADR-009 Q15）
// 实现：T-1F-A（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 重排/解散后的稳定落点：**身份型** anchor（持久引用 / folder 身份），经确定性 resolver
// 映射到当前投影的顶层下标。不依赖 hashValue（Swift Hashable.hashValue 进程内随机化，
// 跨进程/重启不稳定 —— ADR-009 Q15 明令持久顺序只允许显式 order + 确定性比较）。
//
// 用法：mutation 提交后，装配层用被移动条目的身份构造 anchor，在**提交后的投影**上
// resolve → 稳定落点（条目隐藏/latent → nil，调用层回退 firstAvailable/既有焦点迁移）。

import Foundation

/// 稳定落点（重排/解散后焦点/滚动的确定性目标）。
public enum PresentationAnchor: Equatable, Sendable {
    /// 顶层 app 引用（重排后的新位置；folded-in 视觉 dissolve 的 app 也可命中）。
    case topLevelApp(PersistentAppReference)
    /// folder 身份（folder 重排/改名后仍存在的落点）。
    case folder(FolderID)
    /// 首个可见条目（fallback；空投影 → nil）。
    case firstAvailable
}

/// anchor → 投影顶层下标的确定性解析（无 hashValue）。
public enum PresentationAnchorResolver {
    public static func resolve(_ anchor: PresentationAnchor,
                               in projection: VisibleWorkspaceProjection) -> Int? {
        switch anchor {
        case .firstAvailable:
            return projection.topLevel.isEmpty ? nil : 0
        case .folder(let folderID):
            return projection.topLevel.firstIndex {
                if case .folder(let folder) = $0 { return folder.id == folderID } else { return false }
            }
        case .topLevelApp(let ref):
            return projection.topLevel.firstIndex {
                if case .app(let record) = $0 { return ref.matches(record: record) } else { return false }
            }
        }
    }
}
