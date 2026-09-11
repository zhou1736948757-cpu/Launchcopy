// AppGridUI — DragSession.DragTransaction（Phase 1F §5.1 / ADR-010 Q2/Q9）
// 实现：T-1F-C（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 统一事务结构：不透明 token（本阶段仅进程内生成/校验，**绝不进入 pasteboard**；
// 进程内 registry = 身份唯一驻留点）+ scope + 源身份 + 双 generation。
// 外部进程无从构造有效 token；重复 drop / 外部 payload 一律拒绝（Q9）。

import Foundation

/// drag 作用域（ADR-010 Q6）：顶层 vs 打开 folder 的 inner 语义。
public enum DragScope: Equatable, Sendable {
    case topLevel
    case folder(FolderID)
}

/// 拖拽源身份（ADR-010 Q2 的 sourceIdentity；用专用类型表达 folder 成员源，
/// 因为 folder scope 的源是成员 app 而非顶层条目）。
public enum DragSourceIdentity: Equatable, Sendable {
    case topLevelApp(PersistentAppReference)
    case topLevelFolder(FolderID)
    case folderMember(folderID: FolderID, app: PersistentAppReference)

    /// 源 app 引用（顶层 app 或 folder 成员；folder 源为 nil）。
    public var appReference: PersistentAppReference? {
        switch self {
        case .topLevelApp(let ref): return ref
        case .folderMember(_, let ref): return ref
        case .topLevelFolder: return nil
        }
    }

    /// 源所在 scope。
    public var scope: DragScope {
        switch self {
        case .topLevelApp, .topLevelFolder: return .topLevel
        case .folderMember(let folderID, _): return .folder(folderID)
        }
    }
}

/// 统一 drag 事务（ADR-010 Q2）：pressed 时生成，commit/cancel/teardown 销毁。
public struct DragTransaction: Equatable, Sendable {
    /// 进程内随机不透明 token（零身份；绝不落 pasteboard）。
    public let opaqueToken: UInt64
    public let scope: DragScope
    public let sourceIdentity: DragSourceIdentity
    /// pressed 时捕获的已提交 layout generation（drop 时校验未过期）。
    public let layoutGeneration: LayoutGeneration
    /// pressed 时捕获的 catalog generation（drop 时校验未过期）。
    public let catalogGeneration: UInt64

    public init(opaqueToken: UInt64,
                scope: DragScope,
                sourceIdentity: DragSourceIdentity,
                layoutGeneration: LayoutGeneration,
                catalogGeneration: UInt64) {
        self.opaqueToken = opaqueToken
        self.scope = scope
        self.sourceIdentity = sourceIdentity
        self.layoutGeneration = layoutGeneration
        self.catalogGeneration = catalogGeneration
    }
}

/// 进程内 token 工厂：随机 UInt64（避开 0 哨兵；0 保留给"无 token/外部伪造"测试语义）。
public enum DragTokenFactory {
    public static func makeToken() -> UInt64 {
        UInt64.random(in: 1 ... UInt64.max)
    }
}
