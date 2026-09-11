// AppGridUI — DragSession.DropResolver（Phase 1F §5.2 / ADR-010 Q8/Q9）
// 实现：T-1F-C（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// drop 校验：token 与唯一活动事务完全匹配；duplicate drop consumed once；
// stale source/target/layout/catalog 拒绝；session 未取消/未消费。
// 进程内 registry = 身份唯一驻留点；外部 payload 无从进入（Q9）。

import Foundation

/// drop 校验结果。
public enum DropResolution: Equatable, Sendable {
    case accept(DropIntent)
    case reject(DropRejectionReason)
}

/// 绑定唯一活动事务的 drop resolver（pressed 时创建，commit/cancel/teardown 销毁）。
public struct DropResolver: Equatable, Sendable {
    public let transaction: DragTransaction
    /// 已消费（成功 accept 后置位；duplicate drop → .tokenConsumed）。
    public private(set) var consumed: Bool

    public init(transaction: DragTransaction) {
        self.transaction = transaction
        self.consumed = false
    }

    /// 消费一次 drop。只认唯一活动 token；拒绝不消费（调用方随后销毁 resolver）。
    public mutating func consume(token: UInt64,
                                 intent: DropIntent,
                                 layout: PersistentWorkspaceLayout,
                                 catalogGeneration: UInt64) -> DropResolution {
        guard token == transaction.opaqueToken else { return .reject(.invalidToken) }
        guard !consumed else { return .reject(.tokenConsumed) }
        guard layout.generation == transaction.layoutGeneration else {
            return .reject(.staleLayout(expected: transaction.layoutGeneration, current: layout.generation))
        }
        guard catalogGeneration == transaction.catalogGeneration else {
            return .reject(.staleCatalog(expected: transaction.catalogGeneration, current: catalogGeneration))
        }
        guard sourceStillPresent(in: layout) else { return .reject(.sourceMissing) }
        guard targetStillValid(intent: intent, in: layout) else { return .reject(.targetMissing) }
        guard intent != .invalid else { return .reject(.invalidDropTarget) }

        consumed = true
        return .accept(intent)
    }

    // MARK: - 内部校验

    private func sourceStillPresent(in layout: PersistentWorkspaceLayout) -> Bool {
        switch transaction.sourceIdentity {
        case .topLevelApp(let ref):
            return layout.topLevelOrder.contains { $0 == .app(ref) }
        case .topLevelFolder(let id):
            return layout.topLevelOrder.contains { $0 == .folder(id) }
        case .folderMember(let folderID, let ref):
            return layout.folder(id: folderID)?.members.contains(ref) == true
        }
    }

    private func targetStillValid(intent: DropIntent, in layout: PersistentWorkspaceLayout) -> Bool {
        switch intent {
        case .insertion(let index):
            switch transaction.scope {
            case .topLevel:
                return index >= 0 && index <= layout.topLevelOrder.count
            case .folder(let folderID):
                guard let folder = layout.folder(id: folderID) else { return false }
                return index >= 0 && index <= folder.members.count
            }
        case .createFolder(let target):
            return layout.topLevelOrder.contains { $0 == .app(target) }
        case .intoFolder(let targetFolderID, _):
            return layout.folder(id: targetFolderID) != nil
        case .topLevelTarget(let index):
            return index >= 0 && index <= layout.topLevelOrder.count
        case .invalid:
            return false
        }
    }
}
