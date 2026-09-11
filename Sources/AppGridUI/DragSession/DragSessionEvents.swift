// AppGridUI — DragSession.DragSessionEvents（Phase 1F §5.1 / ADR-010 Q2/Q7）
// 实现：T-1F-C（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 状态机状态、对外事件、终局结果与统一 cancel 原因。事件只描述"发生了什么"，
// 视觉执行（preview/insertion 线/folder-create 高亮/edge 动画）全部在 D 层。

import Foundation

/// pointer 状态机状态（ADR-010 Q2）：
/// `idle → pressed → dragging/edgeTurnPending → commit | cancel → idle`。
public enum DragSessionState: Equatable, Sendable {
    case idle
    /// pointer-down 已记录源身份，未过阈值（未过阈值 mouse-up → click）。
    case pressed
    /// 已过按下阈值（drag 进行中）。
    case dragging
    /// dragging 内边缘驻留计时中（dwell 满 → 一次 page turn → 重新 hit-test → 回 dragging）。
    case edgeTurnPending
}

/// 统一 cancel 原因（ADR-010 Q7 全量覆盖；全部收敛同一出口，零写盘）。
public enum DragCancelReason: Equatable, Sendable, CaseIterable {
    case escape
    case windowResign
    case catalogRefresh
    case searchActivated
    case titleEditBegan
    case overlayClosed
    case teardown
    case secondDrag
    /// 布局 mid-drag 变更（ADR-010 Q8 安全默认：cancel drag）。
    case layoutChanged
}

/// drop 拒绝原因（进程内 domain 错误；不进 telemetry/日志/报告）。
public enum DropRejectionReason: Equatable, Sendable {
    case noActiveSession
    case invalidToken
    case tokenConsumed
    case sessionCancelled
    case staleLayout(expected: LayoutGeneration, current: LayoutGeneration)
    case staleCatalog(expected: UInt64, current: UInt64)
    case sourceMissing
    case targetMissing
    case invalidDropTarget
    /// 引擎拒绝（stale/非法 target/将破坏不变量；原布局不变、无半提交）。
    case mutationRejected(LayoutMutationRejection)
}

/// 终局结果（一次 session 至多一个；旧 completion 由 token 校验拒绝）。
public enum DragSessionOutcome: Equatable, Sendable {
    /// mutation 已提交（新布局，generation 已 +1；呈现/持久化由上层链处理）。
    case committed(PersistentWorkspaceLayout)
    /// drop 无实际位移（不增 generation、零写盘）。
    case noOp
    case cancelled(DragCancelReason)
    case rejected(DropRejectionReason)
}

/// 对外事件（D 层据此驱动视觉；本层不产任何视图副作用）。
public enum DragSessionEvent: Equatable, Sendable {
    /// 进入 pressed（源身份已记录；D 层可开始阈值视觉）。
    case pressed
    /// 过阈值进入 dragging（D 层显示 drag preview）。
    case dragBegan
    /// drop intent 分类变化（D 层更新 insertion 线 / folder-create 高亮 / invalid 态）。
    case intentChanged(DropIntent)
    /// edge paging 事件（D 层驱动外层/内层翻页入口与动画）。
    case edge(EdgePagingEvent)
    /// 未过阈值 mouse-up：派发既有 click/open/launch（D 层执行；本层不启动任何东西）。
    case clicked
    /// mutation 已提交（携带新布局）。
    case committed(PersistentWorkspaceLayout)
    /// drop 无位移（零写盘）。
    case noOp
    case cancelled(DragCancelReason)
    case rejected(DropRejectionReason)
}
