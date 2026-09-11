//
//  PageTargetPolicy.swift
//  PagingCore
//
//  Phase 1A — 目标页策略（ADR-001 D9）。
//
//  释放后计算 targetPage：输入 = 位移比例（visualOffset − committedPage×pageWidth 归一化）、
//  近期速度（含 momentum）、边界位置、Reduce Motion；输出 = 回弹/前进/后退。
//  阈值全部来自 PagingParameters 集中配置，禁止 magic number。
//  Reduce Motion 下策略逻辑完全一致（ADR-001 D8：仅动画参数不同，转换条件不变）。
//

import Foundation

/// 目标页决策（D9：回弹/前进/后退）。
public enum TargetDecision: String, Sendable, Equatable {
    /// 回弹到当前页。
    case bounce
    /// 前进一页。
    case advance
    /// 后退一页。
    case retreat
}

/// 目标页策略：纯函数，无状态。
public enum PageTargetPolicy {

    /// 计算释放后的目标页决策。
    ///
    /// - Parameters:
    ///   - offset: 释放时 visualOffset（页宽单位）。
    ///   - committedPage: 当前语义页。
    ///   - velocityPxPerSecond: 近期速度（含 momentum；px/s，已缩放）。
    ///   - pageWidth: 页宽（px）。
    ///   - pageCount: 页数。
    ///   - parameters: 集中参数。
    ///   - reduceMotion: RM 标记（D8：策略不变，保留签名以表达 D9 输入面；逻辑不使用）。
    /// - Returns: 回弹/前进/后退。边界由调用方 clamp（本函数亦对候选页 clamp 后判定回弹）。
    public static func decide(
        offset: Double,
        committedPage: Int,
        velocityPxPerSecond: Double,
        pageWidth: Double,
        pageCount: Int,
        parameters: PagingParameters,
        reduceMotion: Bool
    ) -> TargetDecision {
        // 无页/单页/无效宽度：唯一合法结果是回弹到当前页。
        guard pageCount > 1, pageWidth > 0 else { return .bounce }

        let ratio = offset - Double(committedPage)          // 页宽单位
        let absRatio = abs(ratio)
        let absVelocity = abs(velocityPxPerSecond)

        // 方向：速度达到强制阈值时用速度方向（甩动），否则用位移方向。
        let direction: Double
        if absVelocity >= parameters.velocityThreshold {
            direction = velocityPxPerSecond >= 0 ? 1 : -1
        } else {
            direction = ratio >= 0 ? 1 : -1
        }

        let shouldTurn: Bool
        // T-worker-b-retreat/-fullscreen/-thresh45/-thresh43/-thresh42：回退方向位移阈值 × retreatDisplacementFactor
        // （35/42 ≈ 0.833333 → 0.42×35/42 = 0.35 页；全屏基准下前进 0.42 / 回退 0.35），补偿生理不对称
        // （往回滑行程天然短）；前进保持 displacementThreshold；速度强制路径（下一分支）不受影响。
        // direction 已先行算出（速度/位移符号），无循环依赖。
        let threshold = direction == -1
            ? parameters.displacementThreshold * parameters.retreatDisplacementFactor
            : parameters.displacementThreshold
        if absRatio >= threshold {
            // 位移条件：达到翻页阈值（低速度大位移）。
            shouldTurn = true
        } else if absVelocity >= parameters.velocityThreshold {
            // 速度强制：高速度小位移。
            shouldTurn = true
        } else {
            // 位移 + 速度加权混合（velocityContribution：0=纯位移；合法范围 0.0–0.5，
            // 0.5=速度加权上限——位移为主、速度为辅，与 PagingParameters 约束一致）。
            let normalizedVelocity = absVelocity / parameters.velocityThreshold // 0..<1（低于强制阈值）
            let blended = absRatio + parameters.velocityContribution * normalizedVelocity
            shouldTurn = blended >= threshold
        }

        // 边界：候选目标页 clamp 到 [0, pageCount−1]；clamp 后等于当前页 → 回弹（首/末越界）。
        let candidate = committedPage + (shouldTurn ? Int(direction) : 0)
        let clamped = min(max(candidate, 0), pageCount - 1)
        if clamped == committedPage {
            return .bounce
        }
        return clamped > committedPage ? .advance : .retreat
    }
}
