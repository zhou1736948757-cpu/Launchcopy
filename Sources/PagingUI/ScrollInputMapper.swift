//
//  ScrollInputMapper.swift
//  PagingUI
//
//  NSEvent scrollWheel → Core 输入决策的纯函数映射（无 AppKit 副作用，可完全单测）。
//
//  约定（产品决策，见 Workflow/results/T-worker-d.md Deviations）：
//  - scrollingDelta 语义：正值 = 内容向右/向上移动（系统已按用户的"自然滚动"偏好
//    归一化；isDirectionInvertedFromDevice == true 表示自然滚动开启）。
//  - 分页方向与物理手指方向一致（Photos 式）：手指向左恒为"下一页"（core delta > 0），
//    不受自然/传统滚动设置影响；鼠标滚轮向右 = 下一页（横向滚轮标准行为）。
//    推导：normalized = -scrollingDeltaX × (isDirectionInverted ? 1 : -1)：
//      自然滚动 手指左移 → scrollingDeltaX < 0 → normalized > 0 → 下一页 ✓
//      传统滚动 手指左移 → 内容右移 → scrollingDeltaX > 0 → normalized > 0 → 下一页 ✓
//      滚轮向右 → scrollingDeltaX > 0 → normalized > 0 → 下一页 ✓
//  - 横向主导：|Δx| >= |Δy| 时按横向处理；否则忽略（垂直滚动不参与分页）。
//  - phase 归一化（D10）：began/changed/ended/cancelled/momentum*；无 phase 事件走
//    legacy 鼠标滚轮 fallback（Core legacyScrollDelta）。
//  - 防御性序列：Core 侧兜底（D5），本映射只保证"照实转发 + 明显的错误序列修正"。
//

import AppKit
import Foundation

/// 一条归一化后的输入决策（由映射器产出、由 PagingSurface 逐条执行）。
public enum ScrollInputAction: Equatable {
    case gestureBegan
    case gestureChanged(Double)
    case gestureEnded
    case gestureCancelled
    case momentumBegan
    case momentumChanged(Double)
    case momentumEnded
    /// 结束未决手势（ended 后无 momentum 事件时由 UI 调用 finishGesture —— Worker B 偏差 #1）。
    case finishPendingGesture
    /// 无 phase 的旧式鼠标滚轮输入（Core legacyScrollDelta）。
    case legacyScroll(Double)
    case ignore
}

/// NSEvent → ScrollInputAction 纯函数映射。
public enum ScrollInputMapper {

    /// 归一化横向增量（页面方向为正，见文件头约定）。
    public static func normalizedDelta(scrollingDeltaX: CGFloat, isDirectionInverted: Bool) -> Double {
        let factor: Double = isDirectionInverted ? 1 : -1
        return -Double(scrollingDeltaX) * factor
    }

    /// 把一次 scrollWheel 事件映射为 0..n 条输入决策。
    /// - Parameters:
    ///   - needsFinish: 是否存在"ended 后未消费"的待结束手势（由 PagingSurface 维护）。
    public static func map(
        phase: NSEvent.Phase,
        momentumPhase: NSEvent.Phase,
        scrollingDeltaX: CGFloat,
        scrollingDeltaY: CGFloat,
        isDirectionInverted: Bool,
        needsFinish: Bool
    ) -> [ScrollInputAction] {
        let hasMomentum = !momentumPhase.isEmpty
        let hasPhase = !phase.isEmpty

        // momentum 事件（ended 后跟随的惯性事件：phase 为空、momentumPhase 有值）
        if hasMomentum {
            if momentumPhase.contains(.began) {
                return [.momentumBegan]
            }
            let delta = normalizedDelta(scrollingDeltaX: scrollingDeltaX, isDirectionInverted: isDirectionInverted)
            if momentumPhase.contains(.changed) {
                return [.momentumChanged(delta)]
            }
            if momentumPhase.contains(.ended) {
                return [.momentumEnded]
            }
            return [.ignore]
        }

        if hasPhase {
            if phase.contains(.began) {
                // 新手势开始：先结束未决手势（释放决策），再 began（D5：接管旧释放会话）。
                return needsFinish ? [.finishPendingGesture, .gestureBegan] : [.gestureBegan]
            }
            if phase.contains(.changed) {
                // 横向主导：|Δx| >= |Δy| 才参与分页。
                if abs(scrollingDeltaX) < abs(scrollingDeltaY) {
                    return [.ignore]
                }
                let delta = normalizedDelta(scrollingDeltaX: scrollingDeltaX, isDirectionInverted: isDirectionInverted)
                return [.gestureChanged(delta)]
            }
            if phase.contains(.ended) {
                return needsFinish ? [] : [.gestureEnded]
            }
            if phase.contains(.cancelled) {
                return [.gestureCancelled]
            }
            // .mayBegin / .stationary / 其他：不产生输入。
            return [.ignore]
        }

        // 无 phase：旧式鼠标滚轮 fallback；若存在未决手势 → 先结束。
        if needsFinish {
            return [.finishPendingGesture]
        }
        let delta = normalizedDelta(scrollingDeltaX: scrollingDeltaX, isDirectionInverted: isDirectionInverted)
        return delta == 0 ? [.ignore] : [.legacyScroll(delta)]
    }
}
