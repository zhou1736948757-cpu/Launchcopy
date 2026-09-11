//
//  PagingSurfacePendingFinishTests.swift
//  PagingUITests
//
//  T-worker-b-input-fix 回归：真实触控板「ended 后零事件」路径的释放决策自动触发。
//  - 慢滑释放后无任何下一事件（无 momentum / 无新 began / 无 phase 事件）→ 帧驱动在
//    pendingFinishThreshold 窗口期满后自动 core.finishGesture()（回弹/翻页/吸住）。
//  - momentum 在窗口内到达 → 接管释放流程，不得被自动 finish 误伤（fling 速度不丢）。
//  - teardown 后零回调（§7.3 门禁不回归）。
//  时间源可注入：测试用合成时钟，避免真实等待。
//

import XCTest
@testable import PagingUI

final class PagingSurfacePendingFinishTests: XCTestCase {

    /// 合成时钟（引用盒）：pendingFinishTimeSource 读 box.value，测试推进"当前时间"。
    private final class FakeClock {
        var value: TimeInterval = 0
    }

    private func makeSurfaceWithClock(pageCount: Int = 5, clock: FakeClock) -> PagingSurface {
        let surface = makeSurface(pageCount: pageCount)
        surface.pendingFinishTimeSource = { clock.value }
        return surface
    }

    // MARK: - 测试 A：ended 后零事件 → 窗口期满 → 释放决策自动发生

    func testEndedWithNoFurtherEventsAutoFinishes() {
        let clock = FakeClock()
        let surface = makeSurfaceWithClock(clock: clock)

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 400, at: 0.5) // 400px/0.5s = 800px/s ≥ 强制阈值（700）→ 速度强制翻页
        gestureEnded(surface, at: 0.5)
        XCTAssertTrue(surface.needsFinish, "ended 置待决释放")
        XCTAssertEqual(surface.core.state, .tracking)

        // 窗口未满：推进帧也不得释放（保持跟踪）。
        clock.value = 0.05
        surface.advanceFrame(deltaTime: 1.0 / 60.0)
        XCTAssertEqual(surface.core.state, .tracking)
        XCTAssertEqual(surface.core.commitCount, 0)

        // 窗口期满：自动 finishGesture → settle（回弹或翻页的决策入口）。
        clock.value = 0.2 // ended 时合成时钟=0（pendingFinishSince=0）→ 0.2-0 ≥ 0.1 窗口已满
        surface.advanceFrame(deltaTime: 1.0 / 60.0)
        XCTAssertEqual(surface.core.state, .settling, "自动 finishGesture → settle")
        XCTAssertEqual(surface.core.activeTransition?.reason, .gestureRelease)
        XCTAssertFalse(surface.needsFinish, "待决状态已清")
        XCTAssertNil(surface.pendingFinishSince)

        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 1, "速度强制（800px/s ≥ 700）→ 翻页")
        XCTAssertEqual(surface.core.commitCount, 1)
        XCTAssertEqual(surface.core.state, .idle)
    }

    func testEndedAtBoundaryAutoFinishBouncesBack() {
        let clock = FakeClock()
        let surface = makeSurfaceWithClock(clock: clock)

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: -150, at: 0.5) // 首页向左越界意图
        gestureEnded(surface, at: 0.5)

        clock.value = 0.2
        surface.advanceFrame(deltaTime: 1.0 / 60.0)
        XCTAssertEqual(surface.core.state, .settling)

        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 0, "边界回弹回首页")
        XCTAssertEqual(surface.core.visualOffset, 0, accuracy: 1e-9)
        XCTAssertEqual(surface.core.commitCount, 1, "回弹也是释放决策（同页 commit）")
        XCTAssertEqual(surface.core.state, .idle)
    }

    // MARK: - 测试 B：窗口内 momentum 到达 → 不误伤，fling 速度不丢

    func testMomentumWithinWindowNotClobbered() {
        let clock = FakeClock()
        let surface = makeSurfaceWithClock(clock: clock)

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 500, at: 0.5) // 1000px/s 快甩
        gestureEnded(surface, at: 0.5)
        XCTAssertTrue(surface.needsFinish)

        // momentum 在窗口内（0.52s）到达 → 接管释放流程。
        momentumBegan(surface, at: 0.52)
        XCTAssertFalse(surface.needsFinish, "momentum 接管清除待决释放")
        XCTAssertNil(surface.pendingFinishSince)
        XCTAssertEqual(surface.core.state, .tracking)

        // 时间远超窗口 + 推进帧：不得提前 finish（momentum 流程继续）。
        clock.value = 5.0
        surface.advanceFrame(deltaTime: 1.0 / 60.0)
        surface.advanceFrame(deltaTime: 1.0 / 60.0)
        XCTAssertEqual(surface.core.state, .tracking, "无提前 finish")
        XCTAssertEqual(surface.core.commitCount, 0, "无提前 commit")
        XCTAssertTrue(surface.core.currentSession?.momentumActive == true, "momentum 会话存活")

        // momentum 正常结束 → 高速进入惯性滑行 → 滑行耗尽 → 释放决策（fling 速度保留）。
        momentumEnded(surface, at: 0.6)
        XCTAssertTrue(surface.core.currentSession?.isMomentumGlide == true, "1000px/s > 40px/s → glide")
        XCTAssertTrue(surface.core.isAnimating)
        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 1, "fling 速度未丢：翻页")
        XCTAssertEqual(surface.core.commitCount, 1)
        XCTAssertEqual(surface.core.state, .idle)
    }

    // MARK: - 测试 C：teardown 后推进帧 → 零回调、无 finish

    func testTeardownClearsPendingAndZeroCallbacks() {
        let clock = FakeClock()
        let surface = makeSurfaceWithClock(clock: clock)

        var commitCount = 0
        var stateChangeCount = 0
        var offsetChangeCount = 0
        surface.appEvents.onCommit = { _ in commitCount += 1 }
        surface.appEvents.onStateChange = { _ in stateChangeCount += 1 }
        surface.appEvents.onVisualOffsetChange = { _ in offsetChangeCount += 1 }

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 400, at: 0.5)
        gestureEnded(surface, at: 0.5)
        XCTAssertNotNil(surface.pendingFinishSince, "ended 后有待决释放")

        // 归零：跟踪期间的回调不计（本测试只断言 teardown 后零新增回调）。
        commitCount = 0
        stateChangeCount = 0
        offsetChangeCount = 0

        surface.teardown()
        XCTAssertNil(surface.pendingFinishSince, "teardown 清除待决释放")
        XCTAssertFalse(surface.needsFinish)

        clock.value = 5.0 // 远超窗口
        surface.advanceFrame(deltaTime: 1.0 / 60.0)
        XCTAssertEqual(commitCount, 0, "teardown 后零 commit 回调")
        XCTAssertEqual(stateChangeCount, 0, "teardown 后零状态回调")
        XCTAssertEqual(offsetChangeCount, 0, "teardown 后零偏移回调")
        XCTAssertEqual(surface.core.staleRejectionCount, 0)
        XCTAssertEqual(surface.core.commitCount, 0)
        XCTAssertEqual(surface.core.state, .idle)
    }
}
