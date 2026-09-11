//
//  PagingState.swift
//  PagingCore
//
//  Phase 1A — 五语义状态与归一化手势 phase（ADR-001 D1/D5）。
//

import Foundation

/// 五语义状态（ADR-001 D1）。
///
/// | 状态 | 视觉偏移持有者 | 语义页 | 进入/退出 |
/// |---|---|---|---|
/// | idle | Core（确定值） | committedPage | 无手势无动画 |
/// | tracking | GestureSession | committedPage 不变 | began 进入；ended→(released)→settling / cancelled→idle |
/// | settling | TransitionContext（插值） | targetPage 未 commit | 释放决策后进入；自然完成→idle / 中断→interrupted |
/// | interrupted | 新 GestureSession（从旧动画当前位置接管） | 不变 | settling + began 进入；瞬时状态立即转 tracking |
/// | cancelled | Core（重置到合法确定值） | clamp | 异常/外部干预进入；清理后→idle |
///
/// momentum 视为 tracking 子阶段（GestureSession 内部标记），不引入新顶层状态（D1）。
public enum PagingState: String, Sendable, Equatable {
    /// 无手势无动画。
    case idle
    /// 手势（或 momentum 子阶段）驱动视觉偏移；committedPage 不变。
    case tracking
    /// settle 动画插值中；targetPage 尚未 commit。
    case settling
    /// settling 被新手势接管时的瞬时状态；立即转 tracking（D4）。
    case interrupted
    /// 异常/外部干预进入；清理后→idle。
    case cancelled
}

/// 归一化手势 phase（Core 的唯一输入形态；UI 层负责从 NSEvent 转换，ADR-001 D10）。
///
/// momentum* 是 released（ended）之后同一手势的延续子阶段（D1/D5）。
public enum GesturePhase: String, Sendable, Equatable {
    /// 手指落下（新会话开始；settling 中 = 中断接管）。
    case began
    /// 手指移动（位移增量，px；正方向 = 向下一页）。
    case changed
    /// 手指抬起（会话进入 released，等待 momentum 或 finishGesture）。
    case ended
    /// 系统取消（回到静止位，不做 commit）。
    case cancelled
    /// momentum 阶段开始（tracking 子阶段标记）。
    case momentumBegan
    /// momentum 位移增量。
    case momentumChanged
    /// momentum 阶段结束（速度足够则进入惯性滑行，否则立即决策）。
    case momentumEnded
}
