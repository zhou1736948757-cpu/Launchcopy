//
//  PagingCoreSequenceTests.swift
//  PagingCoreTests
//
//  Phase 1A — 可重复事件序列测试（VALIDATION_PLAN §1.2 / Prompt §7.2）。
//
//  六条序列，每条断言：最终页、视觉偏移、transition 状态、commit 次数、stale callback 数量。
//
//  序列：
//  1. begin → changes → end
//  2. begin → changes → end → momentum
//  3. settling → begin opposite direction
//  4. settling → resize
//  5. settling → pageCount reduction
//  6. tracking → window close
//

import XCTest
@testable import PagingCore

final class PagingCoreSequenceTests: XCTestCase {

    // MARK: - 序列 1：begin → changes → end

    func testSequenceBeginChangesEnd() {
        let h = CoreHarness(pageCount: 5)
        XCTAssertTrue(h.begin(dt: 0.0))
        XCTAssertTrue(h.change(delta: 300, dt: 0.5))
        XCTAssertTrue(h.change(delta: 300, dt: 0.5)) // 共 0.6 页，600 px/s
        XCTAssertTrue(h.end())
        XCTAssertTrue(h.finish()) // 无 momentum → 显式结束输入

        // 中间断言：settling、目标页、pending
        XCTAssertEqual(h.core.state, .settling)
        XCTAssertEqual(h.core.activeTransition?.targetPage, 1)
        XCTAssertEqual(h.core.activeTransition?.commitState, .pending)
        XCTAssertEqual(h.core.committedPage, 0) // 未 commit

        h.tickUntilSettled()
        // 最终断言：最终页 / 视觉偏移 / transition 状态 / commit 次数 / stale 数量
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.core.visualOffset, 1.0, accuracy: 1e-9)
        XCTAssertNil(h.core.activeTransition)
        XCTAssertEqual(h.commitContexts.last?.commitState, .committed)
        XCTAssertEqual(h.commitContexts.last?.hasCommitted, true)
        XCTAssertEqual(h.commitCount, 1)
        XCTAssertEqual(h.staleCount, 0)
        XCTAssertEqual(h.core.state, .idle)
    }

    // MARK: - 序列 2：begin → changes → end → momentum

    func testSequenceBeginChangesEndMomentum() {
        let h = CoreHarness(pageCount: 5)
        XCTAssertTrue(h.begin())
        XCTAssertTrue(h.change(delta: 200, dt: 1.0)) // 0.2 页，200 px/s
        XCTAssertTrue(h.end())
        XCTAssertTrue(h.momentumBegan())
        XCTAssertTrue(h.momentumChange(delta: 150, dt: 0.05)) // 3000 px/s
        XCTAssertTrue(h.momentumEnd()) // 进入惯性滑行（tracking 子阶段）

        XCTAssertEqual(h.core.state, .tracking)
        XCTAssertTrue(h.core.currentSession?.isMomentumGlide == true)
        XCTAssertEqual(h.core.committedPage, 0)

        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 1) // momentum 速度 + 滑行位移 → 翻页
        XCTAssertEqual(h.core.visualOffset, 1.0, accuracy: 1e-9)
        XCTAssertEqual(h.commitCount, 1)
        XCTAssertEqual(h.staleCount, 0)
        XCTAssertEqual(h.core.state, .idle)

        // 对照：同一手势无 momentum → 回弹（证明 momentum 影响结果）
        let contrast = CoreHarness(pageCount: 5)
        _ = contrast.begin()
        _ = contrast.change(delta: 200, dt: 1.0)
        _ = contrast.end()
        _ = contrast.finish()
        contrast.tickUntilSettled()
        XCTAssertEqual(contrast.core.committedPage, 0)
        XCTAssertEqual(contrast.commitCount, 1)
    }

    // MARK: - 序列 3：settling → begin opposite direction

    func testSequenceSettlingBeginOppositeDirection() {
        let h = CoreHarness(pageCount: 5, initialPage: 1)
        // 向 0 翻页并进入 settle
        _ = h.begin(); _ = h.change(delta: -600, dt: 1.0); _ = h.end(); _ = h.finish()
        XCTAssertEqual(h.core.state, .settling)
        XCTAssertEqual(h.core.activeTransition?.targetPage, 0)
        _ = h.tick(); _ = h.tick(); _ = h.tick()
        let offsetBefore = h.core.visualOffset

        // settle 中反向 begin → 立即接管
        XCTAssertTrue(h.begin())
        XCTAssertEqual(h.core.state, .tracking)
        XCTAssertEqual(h.interruptionCount, 1)
        XCTAssertEqual(h.staleCount, 1) // 旧动画 completion 被拒计数
        XCTAssertEqual(h.core.currentSession?.startOffset ?? -1, offsetBefore, accuracy: 0) // 位置连续
        XCTAssertNil(h.core.activeTransition)

        // 反向甩动（+900 px/s ≥ 速度阈值 → 强制前进）翻过中点，结果反转：原向 0 的 settle 被取消，改落 2
        _ = h.change(delta: 900, dt: 1.0)
        _ = h.end()
        XCTAssertTrue(h.finish())
        XCTAssertEqual(h.core.activeTransition?.targetPage, 2)
        h.tickUntilSettled()

        XCTAssertEqual(h.core.committedPage, 2)
        XCTAssertEqual(h.core.visualOffset, 2.0, accuracy: 1e-9)
        XCTAssertEqual(h.commitCount, 1) // 无双重 commit
        XCTAssertEqual(h.staleCount, 1)
        XCTAssertEqual(h.interruptionCount, 1)
        XCTAssertEqual(h.core.state, .idle)
    }

    // MARK: - 序列 4：settling → resize

    func testSequenceSettlingResize() {
        let h = CoreHarness(pageCount: 5, initialPage: 1)
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end(); _ = h.finish()
        XCTAssertEqual(h.core.state, .settling)
        XCTAssertEqual(h.core.activeTransition?.targetPage, 2)
        _ = h.tick(); _ = h.tick()
        let offsetBefore = h.core.visualOffset

        h.core.setPageWidth(500)
        XCTAssertEqual(h.staleCount, 1)              // 旧动画作废
        XCTAssertEqual(h.core.activeTransition?.reason, .resizeRebase)
        XCTAssertEqual(h.core.visualOffset, offsetBefore * 2, accuracy: 1e-9) // 物理位置保持
        XCTAssertEqual(h.core.activeTransition?.targetPage, 3) // round + clamp
        h.tickUntilSettled()

        XCTAssertEqual(h.core.committedPage, 3)
        XCTAssertEqual(h.core.visualOffset, 3.0, accuracy: 1e-9)
        XCTAssertEqual(h.commitCount, 1)
        XCTAssertEqual(h.staleCount, 1)
        XCTAssertEqual(h.core.state, .idle)
    }

    // MARK: - 序列 5：settling → pageCount reduction

    func testSequenceSettlingPageCountReduction() {
        let h = CoreHarness(pageCount: 5, initialPage: 3)
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end(); _ = h.finish()
        XCTAssertEqual(h.core.state, .settling)
        XCTAssertEqual(h.core.activeTransition?.targetPage, 4)
        _ = h.tick(); _ = h.tick()

        h.core.setPageCount(3) // target 4 越界 → 作废 + clamp + 重置
        XCTAssertEqual(h.staleCount, 1)
        XCTAssertEqual(h.core.activeTransition?.reason, .pageCountChange)
        XCTAssertEqual(h.core.activeTransition?.targetPage, 2)
        h.tickUntilSettled()

        XCTAssertEqual(h.core.committedPage, 2)
        XCTAssertEqual(h.core.visualOffset, 2.0, accuracy: 1e-9)
        XCTAssertEqual(h.commitCount, 1)
        XCTAssertEqual(h.staleCount, 1)
        XCTAssertEqual(h.core.state, .idle)
    }

    func testSequenceSettlingPageCountReductionValidTarget() {
        let h = CoreHarness(pageCount: 5, initialPage: 0)
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end(); _ = h.finish()
        XCTAssertEqual(h.core.activeTransition?.targetPage, 1)
        _ = h.tick(); _ = h.tick()
        h.core.setPageCount(3) // target 1 < 3 → 合法，继续动画
        XCTAssertEqual(h.staleCount, 0)
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.core.visualOffset, 1.0, accuracy: 1e-9)
        XCTAssertEqual(h.commitCount, 1)
        XCTAssertEqual(h.staleCount, 0)
    }

    // MARK: - 序列 6：tracking → window close

    func testSequenceTrackingWindowClose() {
        let h = CoreHarness(pageCount: 5)
        XCTAssertTrue(h.begin())
        XCTAssertTrue(h.change(delta: 200, dt: 1.0))
        XCTAssertEqual(h.core.state, .tracking)
        XCTAssertEqual(h.core.visualOffset, 0.2, accuracy: 1e-9)
        let eventsBefore = h.stateHistory.count + h.offsetHistory.count + h.commitContexts.count

        h.core.teardown() // 窗口关闭
        XCTAssertTrue(h.core.isTearingDown)
        XCTAssertEqual(h.core.state, .idle)
        XCTAssertEqual(h.core.committedPage, 0)
        XCTAssertEqual(h.core.visualOffset, 0, accuracy: 1e-12)
        XCTAssertNil(h.core.currentSession)
        XCTAssertNil(h.core.activeTransition)
        XCTAssertEqual(h.commitCount, 0)
        XCTAssertEqual(h.staleCount, 0) // tracking 中无动画可作废

        // teardown 后所有事件被拒；回调数冻结（D7：无残留回调）
        XCTAssertFalse(h.begin())
        XCTAssertFalse(h.change(delta: 100, dt: 1.0))
        XCTAssertFalse(h.end())
        XCTAssertFalse(h.finish())
        XCTAssertFalse(h.tick())
        XCTAssertFalse(h.momentumBegan())
        XCTAssertFalse(h.core.legacyScrollDelta(100, timestamp: 1))
        XCTAssertEqual(h.core.state, .idle)
        XCTAssertEqual(h.stateHistory.count + h.offsetHistory.count + h.commitContexts.count, eventsBefore)
        XCTAssertEqual(h.commitCount, 0)
        XCTAssertEqual(h.staleCount, 0)
    }
}
