//
//  TransitionContext.swift
//  PagingCore
//
//  Phase 1A — settle 过渡上下文（ADR-001 D3）。
//
//  stale completion rejection 三防线：
//  1. 单调递增 UInt64 transitionToken（每次 beginSettle 递增；中断本身不递增）；
//  2. commitState 三态（pending / committed / stale）；
//  3. hasCommitted 保证单次 commit（无双重 commit，§3.F 门禁 5）。
//

import Foundation

/// commit 资格状态（ADR-001 D3）。
public enum CommitState: String, Sendable, Equatable {
    /// 可提交。
    case pending
    /// 已提交（单次）。
    case committed
    /// 已作废（中断/取消/teardown/重基准化），其 completion 一律拒绝。
    case stale
}

/// settle 发起原因（telemetry 关联 transition 用）。
public enum SettleReason: String, Sendable, Equatable {
    /// 手势释放决策（回弹/前进/后退）。
    case gestureRelease
    /// resize/pageWidth 重基准化（D6）。
    case resizeRebase
    /// pageCount 变化后重置（D6）。
    case pageCountChange
    /// Reduce Motion 动态切换后重启（D8）。
    case reduceMotionChange
}

/// 一次 settle 的过渡上下文。
public final class TransitionContext {

    /// 创建时 token（单调递增；与 Core.transitionToken 比较判定资格）。
    public let token: UInt64
    /// 目标语义页（未 commit 前仅动画目标）。
    public let targetPage: Int
    /// 动画起点（页宽单位）。
    public let fromOffset: Double
    /// 发起原因。
    public let reason: SettleReason
    /// 创建时间戳。语义：手势发起的 settle = 手势事件时间戳（事件时基）；
    /// 非手势重启（resize/pageCount/RM 路径）= 壁钟时间 Date().timeIntervalSince1970
    /// （诊断字段，仅作关联用，两种时基不混算）。
    public let createdAt: TimeInterval
    /// commit 资格状态。
    public private(set) var commitState: CommitState
    /// 是否已 commit（单次提交保证）。
    public private(set) var hasCommitted: Bool

    init(token: UInt64, targetPage: Int, fromOffset: Double, reason: SettleReason, createdAt: TimeInterval) {
        self.token = token
        self.targetPage = targetPage
        self.fromOffset = fromOffset
        self.reason = reason
        self.createdAt = createdAt
        self.commitState = .pending
        self.hasCommitted = false
    }

    func markCommitted() {
        commitState = .committed
        hasCommitted = true
    }

    func markStale() {
        commitState = .stale
    }
}
