//
//  TestSupport.swift
//  PagingUITests
//
//  测试台：无窗口创建 PagingSurface，经内部 handleScrollInput/advanceFrame
//  驱动与真实 scrollWheel 完全相同的输入路径（自动化输入回归；物理门用真实触控板）。
//

import AppKit
import XCTest
@testable import PagingUI

/// 创建无窗口 surface（固定 1000×700，触发首轮布局）。
func makeSurface(pageCount: Int = 5, itemsPerPage: Int = 8, initialPage: Int = 0,
                 reduceMotion: Bool = false, labMode: Bool = false) -> PagingSurface {
    let surface = PagingSurface(
        pageCount: pageCount,
        itemsPerPage: itemsPerPage,
        initialPage: initialPage,
        reduceMotion: reduceMotion,
        labMode: labMode
    )
    surface.frameDriver = nil // 测试手动 advanceFrame（teardown-driver 测试除外）
    surface.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
    surface.layout()
    return surface
}

/// 自然滚动（isDirectionInverted = true）下的手势输入 helpers。
/// 注意：deltaX 参数 = **手指意图位移**（>0 手指左移 → 下一页）。
/// 自然滚动下手指左移的原始 scrollingDeltaX < 0，故传 -deltaX；
/// mapper 归一化后 Core 收到 +deltaX（与真实触控板路径完全一致）。
func gestureBegan(_ s: PagingSurface, at t: TimeInterval) {
    s.handleScrollInput(phase: .began, momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0,
                        isDirectionInverted: true, timestamp: t)
}

func gestureChanged(_ s: PagingSurface, deltaX: CGFloat, at t: TimeInterval) {
    s.handleScrollInput(phase: .changed, momentumPhase: [], scrollingDeltaX: -deltaX, scrollingDeltaY: 0,
                        isDirectionInverted: true, timestamp: t)
}

func gestureEnded(_ s: PagingSurface, at t: TimeInterval) {
    s.handleScrollInput(phase: .ended, momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0,
                        isDirectionInverted: true, timestamp: t)
}

/// ended 后无 momentum 事件：由 UI 调用 finishGesture（Worker B 偏差 #1 的 UI 侧验证路径）。
func finishPendingGesture(_ s: PagingSurface, at t: TimeInterval) {
    s.handleScrollInput(phase: [], momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0,
                        isDirectionInverted: true, timestamp: t)
}

func momentumBegan(_ s: PagingSurface, at t: TimeInterval) {
    s.handleScrollInput(phase: [], momentumPhase: .began, scrollingDeltaX: 0, scrollingDeltaY: 0,
                        isDirectionInverted: true, timestamp: t)
}

func momentumChanged(_ s: PagingSurface, deltaX: CGFloat, at t: TimeInterval) {
    s.handleScrollInput(phase: [], momentumPhase: .changed, scrollingDeltaX: -deltaX, scrollingDeltaY: 0,
                        isDirectionInverted: true, timestamp: t)
}

func momentumEnded(_ s: PagingSurface, at t: TimeInterval) {
    s.handleScrollInput(phase: [], momentumPhase: .ended, scrollingDeltaX: 0, scrollingDeltaY: 0,
                        isDirectionInverted: true, timestamp: t)
}

/// 推进动画直到静止（上限帧数防御死循环）。
@discardableResult
func settleFrames(_ s: PagingSurface, maxFrames: Int = 600) -> Int {
    var frames = 0
    while s.core.isAnimating, frames < maxFrames {
        s.advanceFrame(deltaTime: 1.0 / 60.0)
        frames += 1
    }
    return frames
}

/// 单次强制翻页（velocity ≥ velocityThreshold → advance）：
/// began → changed(400px, 0.5s → 800px/s) → ended → finishPending → 动画至静止。
@discardableResult
func flingForwardOnce(_ s: PagingSurface, at t: TimeInterval = 0) -> Bool {
    gestureBegan(s, at: t)
    gestureChanged(s, deltaX: 400, at: t + 0.5)
    gestureEnded(s, at: t + 0.5)
    finishPendingGesture(s, at: t + 0.5)
    settleFrames(s)
    return s.core.state == .idle
}

/// 单次强制回退一页（velocity ≤ -velocityThreshold → retreat）。
@discardableResult
func flingBackwardOnce(_ s: PagingSurface, at t: TimeInterval = 0) -> Bool {
    gestureBegan(s, at: t)
    gestureChanged(s, deltaX: -400, at: t + 0.5)
    gestureEnded(s, at: t + 0.5)
    finishPendingGesture(s, at: t + 0.5)
    settleFrames(s)
    return s.core.state == .idle
}
