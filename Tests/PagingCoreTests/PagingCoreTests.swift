//
//  PagingCoreTests.swift
//  PagingCoreTests
//
//  Phase 1A — Core 单元测试（VALIDATION_PLAN §1.1 / Prompt §7.1）。
//
//  覆盖：page count 0/1/2/多页、current page 首/中/尾、小位移回弹、翻页条件、
//  高速度小位移、低速度大位移、首/末越界、transition 中断、连续两次反向中断、
//  旧 completion 晚到、tracking/settling 时 pageCount 减少、resize、cancel、teardown、
//  Reduce Motion、防御性事件序列、momentum 子阶段与边界滑行。
//
//  Core 为纯逻辑（无 AppKit/CA/窗口/真实事件），测试直接以归一化事件序列驱动。
//

import XCTest
@testable import PagingCore

/// 事件记录器：独立对象，避免初始化顺序问题。
final class EventRecorder {
    var committedPages: [Int] = []
    var commitContexts: [TransitionContext] = []
    var staleTokens: [UInt64] = []
    var stateHistory: [PagingState] = []
    var offsetHistory: [Double] = []
    var interruptions: [PagingInterruption] = []
    var transitions: [TransitionContext] = []
}

/// 测试台：以固定 dt 驱动 Core，记录 commit/stale/state/offset/interruption 事件。
final class CoreHarness {
    let core: PagingCore
    let recorder: EventRecorder
    private(set) var now: TimeInterval = 0

    init(pageCount: Int, pageWidth: Double = 1000, parameters: PagingParameters = .init(),
         reduceMotion: Bool = false, initialPage: Int = 0) {
        let recorder = EventRecorder()
        var events = PagingCoreEvents()
        events.onCommit = { ctx in
            recorder.committedPages.append(ctx.targetPage)
            recorder.commitContexts.append(ctx)
        }
        events.onStaleRejection = { token in recorder.staleTokens.append(token) }
        events.onStateChange = { s in recorder.stateHistory.append(s) }
        events.onVisualOffsetChange = { o in recorder.offsetHistory.append(o) }
        events.onInterruption = { i in recorder.interruptions.append(i) }
        events.onTransitionBegin = { ctx in recorder.transitions.append(ctx) }
        core = PagingCore(pageCount: pageCount, pageWidth: pageWidth, parameters: parameters,
                          initialPage: initialPage, reduceMotion: reduceMotion, events: events)
        self.recorder = recorder
    }

    var committedPages: [Int] { recorder.committedPages }
    var commitContexts: [TransitionContext] { recorder.commitContexts }
    var staleTokens: [UInt64] { recorder.staleTokens }
    var stateHistory: [PagingState] { recorder.stateHistory }
    var offsetHistory: [Double] { recorder.offsetHistory }
    var interruptions: [PagingInterruption] { recorder.interruptions }
    var transitions: [TransitionContext] { recorder.transitions }

    var staleCount: Int { recorder.staleTokens.count }
    var commitCount: Int { recorder.committedPages.count }
    var interruptionCount: Int { recorder.interruptions.count }

    @discardableResult func begin(dt: TimeInterval = 0) -> Bool {
        now += dt
        return core.handleGesturePhase(.began, timestamp: now)
    }
    @discardableResult func change(delta: Double, dt: TimeInterval) -> Bool {
        now += dt
        return core.handleGesturePhase(.changed, delta: delta, timestamp: now)
    }
    @discardableResult func end(dt: TimeInterval = 0) -> Bool {
        now += dt
        return core.handleGesturePhase(.ended, timestamp: now)
    }
    @discardableResult func momentumBegan(dt: TimeInterval = 0) -> Bool {
        now += dt
        return core.handleGesturePhase(.momentumBegan, timestamp: now)
    }
    @discardableResult func momentumChange(delta: Double, dt: TimeInterval) -> Bool {
        now += dt
        return core.handleGesturePhase(.momentumChanged, delta: delta, timestamp: now)
    }
    @discardableResult func momentumEnd(dt: TimeInterval = 0) -> Bool {
        now += dt
        return core.handleGesturePhase(.momentumEnded, timestamp: now)
    }
    @discardableResult func finish(dt: TimeInterval = 0) -> Bool {
        now += dt
        return core.finishGesture(timestamp: now)
    }
    @discardableResult func tick(dt: TimeInterval = 1.0 / 60.0) -> Bool {
        core.tick(deltaTime: dt)
    }
    /// 驱动 tick 直到 settle/滑行结束（上限 4000 帧 = 66.7s，远超 spring 收敛时间）。
    func tickUntilSettled(maxFrames: Int = 4000) {
        var frames = 0
        while core.isAnimating && frames < maxFrames {
            _ = tick()
            frames += 1
        }
    }
    func cancelled() {
        core.handleGesturePhase(.cancelled)
    }
}

final class PagingCoreTests: XCTestCase {

    // MARK: - page count 0 / 1 / 2 / 多页

    func testPageCountZero() {
        let h = CoreHarness(pageCount: 0)
        XCTAssertEqual(h.core.state, .idle)
        XCTAssertEqual(h.core.committedPage, 0)
        XCTAssertEqual(h.core.visualOffset, 0, accuracy: 1e-12)
        // 全部输入安全忽略，不崩溃
        XCTAssertFalse(h.begin())
        XCTAssertFalse(h.change(delta: 500, dt: 1.0))
        XCTAssertFalse(h.end())
        XCTAssertFalse(h.finish())
        XCTAssertFalse(h.tick())
        XCTAssertFalse(h.core.legacyScrollDelta(500, timestamp: 1))
        h.core.setPageWidth(2000)   // 不崩溃
        h.core.setPageCount(0)      // 不崩溃
        h.core.cancel()             // 不崩溃
        h.core.teardown()           // 不崩溃
        XCTAssertEqual(h.core.committedPage, 0)
        XCTAssertEqual(h.core.visualOffset, 0, accuracy: 1e-12)
    }

    func testPageCountOne() {
        let h = CoreHarness(pageCount: 1)
        XCTAssertTrue(h.begin())
        XCTAssertTrue(h.change(delta: 500, dt: 1.0))
        XCTAssertTrue(h.end())
        XCTAssertTrue(h.finish())
        XCTAssertEqual(h.core.state, .settling)
        XCTAssertEqual(h.core.activeTransition?.targetPage, 0) // 单页唯一合法目标
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 0)
        XCTAssertEqual(h.core.visualOffset, 0, accuracy: 1e-9)
        XCTAssertEqual(h.commitCount, 1)
        XCTAssertEqual(h.staleCount, 0)
    }

    func testPageCountTwo() {
        let h = CoreHarness(pageCount: 2)
        // 前进
        XCTAssertTrue(h.begin())
        XCTAssertTrue(h.change(delta: 600, dt: 1.0))
        XCTAssertTrue(h.end())
        XCTAssertTrue(h.finish())
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.core.visualOffset, 1.0, accuracy: 1e-9)
        // 后退
        XCTAssertTrue(h.begin())
        XCTAssertTrue(h.change(delta: -600, dt: 1.0))
        XCTAssertTrue(h.end())
        XCTAssertTrue(h.finish())
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 0)
        XCTAssertEqual(h.core.visualOffset, 0, accuracy: 1e-9)
        XCTAssertEqual(h.commitCount, 2)
    }

    func testMultiPage() {
        let h = CoreHarness(pageCount: 5)
        for _ in 0..<2 {
            _ = h.begin()
            _ = h.change(delta: 600, dt: 1.0)
            _ = h.end()
            _ = h.finish()
            h.tickUntilSettled()
        }
        XCTAssertEqual(h.core.committedPage, 2)
        XCTAssertEqual(h.core.visualOffset, 2.0, accuracy: 1e-9)
        XCTAssertEqual(h.commitCount, 2)
    }

    // MARK: - current page 首 / 中 / 尾

    func testCurrentPageFirst() {
        let h = CoreHarness(pageCount: 5)
        XCTAssertEqual(h.core.committedPage, 0)
        XCTAssertEqual(h.core.visualOffset, 0, accuracy: 1e-12)
    }

    func testCurrentPageMiddle() {
        let h = CoreHarness(pageCount: 5)
        for _ in 0..<2 {
            _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end(); _ = h.finish()
            h.tickUntilSettled()
        }
        XCTAssertEqual(h.core.committedPage, 2)
        XCTAssertEqual(h.core.visualOffset, 2.0, accuracy: 1e-9)
    }

    func testCurrentPageLast() {
        let h = CoreHarness(pageCount: 5, initialPage: 4)
        XCTAssertEqual(h.core.committedPage, 4)
        XCTAssertEqual(h.core.visualOffset, 4.0, accuracy: 1e-12)
        // 末页继续向前 → 回弹，committedPage 不变
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end(); _ = h.finish()
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 4)
        XCTAssertEqual(h.core.visualOffset, 4.0, accuracy: 1e-9)
        XCTAssertEqual(h.commitCount, 1) // 同页回弹仍是一次自然完成
    }

    // MARK: - 小位移回弹 / 翻页条件 / 速度

    func testSmallDisplacementBounces() {
        let h = CoreHarness(pageCount: 5)
        _ = h.begin()
        _ = h.change(delta: 100, dt: 1.0) // 0.1 页，100 px/s
        XCTAssertEqual(h.core.visualOffset, 0.1, accuracy: 1e-9)
        XCTAssertEqual(h.core.committedPage, 0) // tracking 中不 commit
        _ = h.end()
        _ = h.finish()
        XCTAssertEqual(h.core.state, .settling)
        XCTAssertEqual(h.core.activeTransition?.targetPage, 0)
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 0)
        XCTAssertEqual(h.core.visualOffset, 0, accuracy: 1e-9)
        XCTAssertEqual(h.commitCount, 1)
        XCTAssertEqual(h.staleCount, 0)
    }

    func testTurnConditionMet() {
        let h = CoreHarness(pageCount: 5)
        _ = h.begin()
        _ = h.change(delta: 600, dt: 1.0) // 0.6 页 ≥ 阈值，600 px/s < 700（非速度强制）
        _ = h.end()
        _ = h.finish()
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.core.visualOffset, 1.0, accuracy: 1e-9)
    }

    func testHighVelocitySmallDisplacement() {
        let h = CoreHarness(pageCount: 5)
        _ = h.begin()
        _ = h.change(delta: 80, dt: 0.02) // 0.08 页 < 阈值，但 4000 px/s ≥ 700 → 强制翻页
        _ = h.end()
        _ = h.finish()
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 1)
    }

    func testLowVelocityLargeDisplacement() {
        let h = CoreHarness(pageCount: 5)
        _ = h.begin()
        _ = h.change(delta: 600, dt: 2.0) // 0.6 页 ≥ 阈值，300 px/s（低速）
        _ = h.end()
        _ = h.finish()
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 1)
    }

    // MARK: - 回退方向位移阈值宽容化（T-worker-b-retreat → -fullscreen 全屏基准 → -thresh46 → -thresh45 → -thresh43 → -thresh42：前进 0.42 / 回退 0.35）

    func testFullscreenBaselineThresholdBoundaries() {
        // 阈值边界（velocityContribution = 0 隔离纯位移判定；第 15 轮用户目标）：
        // 前进 0.41 < 0.42 → bounce、前进 0.42 ≥ 0.42 → advance；
        // 回退 0.34 < 0.35 → bounce、回退 0.35 ≥ 0.35 → retreat。
        var parameters = PagingParameters()
        parameters.velocityContribution = 0
        let hFwdLow = CoreHarness(pageCount: 5, parameters: parameters)
        _ = hFwdLow.begin(); _ = hFwdLow.change(delta: 410, dt: 2.05); _ = hFwdLow.end(); _ = hFwdLow.finish()
        hFwdLow.tickUntilSettled()
        XCTAssertEqual(hFwdLow.core.committedPage, 0, "前进 0.41 < 0.42 → bounce")

        let hFwdHit = CoreHarness(pageCount: 5, parameters: parameters)
        // 420px（0.42 页）：swift -e 验证 420.0/1000.0 >= 0.42 精确（double），
        // 合成 ratio 亦恰为 0.42 → 无需 1-ulp 偏移（0.46 时代的 461px 偏移随阈值下移消失）。
        _ = hFwdHit.begin(); _ = hFwdHit.change(delta: 420, dt: 2.1); _ = hFwdHit.end(); _ = hFwdHit.finish()
        hFwdHit.tickUntilSettled()
        XCTAssertEqual(hFwdHit.core.committedPage, 1, "前进 0.42 ≥ 0.42 → advance")

        let hBackLow = CoreHarness(pageCount: 5, parameters: parameters, initialPage: 1)
        _ = hBackLow.begin(); _ = hBackLow.change(delta: -340, dt: 1.7); _ = hBackLow.end(); _ = hBackLow.finish()
        hBackLow.tickUntilSettled()
        XCTAssertEqual(hBackLow.core.committedPage, 1, "回退 0.34 < 0.35 → bounce")

        let hBackHit = CoreHarness(pageCount: 5, parameters: parameters, initialPage: 1)
        // −350px（0.35 页）：0.42×35/42 在 double 中恰等于 0.35（swift -e 验证），
        // 合成 −350px/1000px 的 ratio 亦恰为 −0.35 → 无需 1-ulp 偏移。
        _ = hBackHit.begin(); _ = hBackHit.change(delta: -350, dt: 1.75); _ = hBackHit.end(); _ = hBackHit.finish()
        hBackHit.tickUntilSettled()
        XCTAssertEqual(hBackHit.core.committedPage, 0, "回退 0.35 ≥ 0.35 → retreat")
    }

    func testFullscreenBaselineDefaultPathAsymmetry() {
        // 核心不对称断言（默认参数、真实混合路径）：
        // 回退 0.35 @200px/s → 位移分支 retreat；前进 0.41 @16.7px/s → blended 0.4163 < 0.42
        // → bounce；回退 0.34 @16.7px/s → blended 0.3463 < 0.35 → bounce。
        let hBack = CoreHarness(pageCount: 5, initialPage: 1)
        _ = hBack.begin()
        _ = hBack.change(delta: -350, dt: 1.75) // −0.35 页，200 px/s（位移分支 ≥ 0.35）
        _ = hBack.end()
        _ = hBack.finish()
        hBack.tickUntilSettled()
        XCTAssertEqual(hBack.core.committedPage, 0, "回退 0.35 ≥ 0.35 → retreat")

        let hFwd = CoreHarness(pageCount: 5)
        _ = hFwd.begin()
        _ = hFwd.change(delta: 410, dt: 24.6) // +0.41 页，16.7 px/s（近零速度，混合路径）
        _ = hFwd.end()
        _ = hFwd.finish()
        hFwd.tickUntilSettled()
        XCTAssertEqual(hFwd.core.committedPage, 0, "前进 0.41 blended 0.4163 < 0.42 → bounce")

        let hBackLow = CoreHarness(pageCount: 5, initialPage: 1)
        _ = hBackLow.begin()
        _ = hBackLow.change(delta: -340, dt: 20.4) // −0.34 页，16.7 px/s
        _ = hBackLow.end()
        _ = hBackLow.finish()
        hBackLow.tickUntilSettled()
        XCTAssertEqual(hBackLow.core.committedPage, 1, "回退 0.34 blended 0.3463 < 0.35 → bounce")
    }

    func testRetreatVelocityForcedPathUnaffected() {
        // 速度强制路径不受系数影响：857 px/s（≥ 700）位移仅 0.3 页 →
        // 回退 retreat、前进 advance（两方向同路径）。
        let hBack = CoreHarness(pageCount: 5, initialPage: 1)
        _ = hBack.begin()
        _ = hBack.change(delta: -300, dt: 0.35) // −0.3 页，857 px/s
        _ = hBack.end()
        _ = hBack.finish()
        hBack.tickUntilSettled()
        XCTAssertEqual(hBack.core.committedPage, 0, "回退速度强制 → retreat")

        let hFwd = CoreHarness(pageCount: 5)
        _ = hFwd.begin()
        _ = hFwd.change(delta: 300, dt: 0.35) // +0.3 页，857 px/s
        _ = hFwd.end()
        _ = hFwd.finish()
        hFwd.tickUntilSettled()
        XCTAssertEqual(hFwd.core.committedPage, 1, "前进速度强制 → advance")
    }

    // MARK: - 首/末越界（overscroll 阻尼与封顶）

    func testFirstPageBackwardOverscroll() {
        let h = CoreHarness(pageCount: 5)
        _ = h.begin()
        _ = h.change(delta: -400, dt: 1.0) // 越界 0.4 页 → 阻尼 ×0.35 = 0.14
        XCTAssertEqual(h.core.visualOffset, -0.14, accuracy: 1e-9)
        _ = h.end()
        _ = h.finish()
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 0)
        XCTAssertEqual(h.core.visualOffset, 0, accuracy: 1e-9)
        XCTAssertEqual(h.commitCount, 1)
    }

    func testFirstPageBackwardOverscrollCapped() {
        let h = CoreHarness(pageCount: 5)
        _ = h.begin()
        _ = h.change(delta: -3000, dt: 1.0) // 越界 3.0 页 → 阻尼 1.05 → 封顶 0.25
        XCTAssertEqual(h.core.visualOffset, -0.25, accuracy: 1e-9)
    }

    func testLastPageForwardOverscroll() {
        let h = CoreHarness(pageCount: 5, initialPage: 4)
        _ = h.begin()
        _ = h.change(delta: 400, dt: 1.0)
        XCTAssertEqual(h.core.visualOffset, 4.14, accuracy: 1e-9)
        _ = h.end()
        _ = h.finish()
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 4)
        XCTAssertEqual(h.core.visualOffset, 4.0, accuracy: 1e-9)
    }

    func testLastPageForwardOverscrollCapped() {
        let h = CoreHarness(pageCount: 5, initialPage: 4)
        _ = h.begin()
        _ = h.change(delta: 3000, dt: 1.0)
        XCTAssertEqual(h.core.visualOffset, 4.25, accuracy: 1e-9)
    }

    // MARK: - transition 中断（D4：立即接管、位置连续、不跳回旧点）

    func testTransitionInterruption() {
        let h = CoreHarness(pageCount: 5)
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end(); _ = h.finish()
        XCTAssertEqual(h.core.state, .settling)
        let ctxA = try! XCTUnwrap(h.core.activeTransition)
        XCTAssertEqual(ctxA.token, 1)
        _ = h.tick(); _ = h.tick(); _ = h.tick()
        let offsetBefore = h.core.visualOffset
        XCTAssertGreaterThan(offsetBefore, 0.5)
        XCTAssertLessThan(offsetBefore, 0.9)

        // 新手势立即接管
        XCTAssertTrue(h.begin())
        XCTAssertEqual(h.core.state, .tracking)
        XCTAssertEqual(h.interruptionCount, 1)
        XCTAssertEqual(h.staleCount, 1)
        XCTAssertNil(h.core.activeTransition)
        // 门禁 2：接管位置 == 用户当前看到的位置（连续，不跳回旧起点/目标）
        XCTAssertEqual(h.core.currentSession?.startOffset ?? -1, offsetBefore, accuracy: 0)
        // 门禁 4：旧 completion 不覆盖新状态
        XCTAssertFalse(h.core.completeSettle(ctxA))
        XCTAssertEqual(h.staleCount, 2)
        XCTAssertEqual(h.core.committedPage, 0)

        // 新手势继续（接管后的位移比例足以翻页）
        _ = h.change(delta: -200, dt: 1.0)
        _ = h.end()
        _ = h.finish()
        XCTAssertEqual(h.core.activeTransition?.token, 2)
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.commitCount, 1) // 门禁 5：无双重 commit
        XCTAssertEqual(h.staleCount, 2)
    }

    func testDoubleReverseInterruption() {
        let h = CoreHarness(pageCount: 5, initialPage: 1)
        // G1：向 0 翻页 → settle A (token 1)
        _ = h.begin(); _ = h.change(delta: -600, dt: 1.0); _ = h.end(); _ = h.finish()
        let ctxA = try! XCTUnwrap(h.core.activeTransition)
        XCTAssertEqual(ctxA.targetPage, 0)
        _ = h.tick(); _ = h.tick(); _ = h.tick()
        let offset1 = h.core.visualOffset
        // 反向接管 1：+900 px/s 甩动（强制前进）→ 结果反转，目标 2
        XCTAssertTrue(h.begin())
        XCTAssertEqual(h.core.currentSession?.startOffset ?? -1, offset1, accuracy: 0)
        _ = h.change(delta: 900, dt: 1.0); _ = h.end(); _ = h.finish()
        XCTAssertEqual(h.core.activeTransition?.token, 2)
        XCTAssertEqual(h.core.activeTransition?.targetPage, 2)
        _ = h.tick(); _ = h.tick()
        let offset2 = h.core.visualOffset
        // 再次反向接管 2（连续两次反向中断）：回拉 400 px，位移不足 → 回弹到 committed 1
        XCTAssertTrue(h.begin())
        XCTAssertEqual(h.core.currentSession?.startOffset ?? -1, offset2, accuracy: 0)
        XCTAssertEqual(h.interruptionCount, 2)
        XCTAssertEqual(h.staleCount, 2)
        _ = h.change(delta: -400, dt: 1.0); _ = h.end(); _ = h.finish()
        XCTAssertEqual(h.core.activeTransition?.token, 3)
        XCTAssertEqual(h.core.activeTransition?.targetPage, 1)
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.core.visualOffset, 1.0, accuracy: 1e-9)
        XCTAssertEqual(h.commitCount, 1) // 门禁 5：快速正反操作无双重 commit
        // 旧 completion 晚到：全被拒
        XCTAssertFalse(h.core.completeSettle(ctxA))
        XCTAssertEqual(h.staleCount, 3)
        XCTAssertEqual(h.core.committedPage, 1)
    }

    // MARK: - 旧 completion 晚到（D3）

    func testLateCompletionRejected() {
        let h = CoreHarness(pageCount: 5)
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end(); _ = h.finish()
        let ctxA = try! XCTUnwrap(h.core.activeTransition)
        _ = h.tick(); _ = h.tick()
        // 取消 → 旧动画作废
        h.core.cancel()
        XCTAssertEqual(h.staleCount, 1)
        XCTAssertEqual(h.core.committedPage, 0)
        // 新手势 → 新 settle 完成 commit
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end(); _ = h.finish()
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.commitCount, 1)
        // 旧 completion 此刻才到 → 拒绝，不影响新状态
        XCTAssertFalse(h.core.completeSettle(ctxA))
        XCTAssertEqual(h.staleCount, 2)
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.commitCount, 1)
    }

    // MARK: - pageCount 变化（D6）

    func testPageCountReductionDuringTracking() {
        let h = CoreHarness(pageCount: 5, initialPage: 2)
        _ = h.begin()
        _ = h.change(delta: 100, dt: 1.0)
        XCTAssertEqual(h.core.visualOffset, 2.1, accuracy: 1e-9)
        h.core.setPageCount(3)
        XCTAssertEqual(h.core.state, .tracking)   // 不中断手势
        XCTAssertEqual(h.core.committedPage, 2)   // clamp 后仍合法
        XCTAssertEqual(h.core.visualOffset, 2.1, accuracy: 1e-9)
        _ = h.change(delta: 100, dt: 1.0)         // 手势继续：offset 2.1 已在新末页外 0.1，
        XCTAssertEqual(h.core.visualOffset, 2.135, accuracy: 1e-9) // 越界增量按边界阻尼 ×0.35
        _ = h.end(); _ = h.finish()
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 2)   // 小位移回弹
        XCTAssertEqual(h.commitCount, 1)
        XCTAssertEqual(h.staleCount, 0)
    }

    func testPageCountReductionDuringTrackingToSinglePage() {
        let h = CoreHarness(pageCount: 5, initialPage: 2)
        _ = h.begin()
        _ = h.change(delta: 100, dt: 1.0)
        h.core.setPageCount(1)
        XCTAssertEqual(h.core.committedPage, 0)          // clamp
        XCTAssertEqual(h.core.visualOffset, 0.25, accuracy: 1e-9) // 越界深度 clamp + 封顶
        XCTAssertEqual(h.core.state, .tracking)
        _ = h.change(delta: 100, dt: 1.0)
        XCTAssertEqual(h.core.visualOffset, 0.25, accuracy: 1e-9) // 已到 overscroll 上限：外推被阻尼封顶
        _ = h.end(); _ = h.finish()
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 0)
    }

    func testPageCountReductionDuringSettlingValidTarget() {
        let h = CoreHarness(pageCount: 5, initialPage: 1)
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end(); _ = h.finish()
        let ctxA = try! XCTUnwrap(h.core.activeTransition)
        XCTAssertEqual(ctxA.targetPage, 2)
        _ = h.tick(); _ = h.tick()
        h.core.setPageCount(3) // target 2 < 3 → 合法，继续动画
        XCTAssertEqual(h.staleCount, 0)
        XCTAssertEqual(h.core.activeTransition?.token, 1)
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 2)
        XCTAssertEqual(h.commitCount, 1)
    }

    func testPageCountReductionDuringSettlingInvalidTarget() {
        let h = CoreHarness(pageCount: 5, initialPage: 3)
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end(); _ = h.finish()
        let ctxA = try! XCTUnwrap(h.core.activeTransition)
        XCTAssertEqual(ctxA.targetPage, 4)
        _ = h.tick(); _ = h.tick()
        h.core.setPageCount(3) // target 4 ≥ 3 → 作废 + clamp + 重置
        XCTAssertEqual(h.staleCount, 1)
        XCTAssertNotEqual(h.core.activeTransition?.token, ctxA.token)
        XCTAssertEqual(h.core.activeTransition?.reason, .pageCountChange)
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 2)
        XCTAssertEqual(h.core.visualOffset, 2.0, accuracy: 1e-9)
        XCTAssertEqual(h.commitCount, 1)
        // 旧 completion 晚到 → 拒绝
        XCTAssertFalse(h.core.completeSettle(ctxA))
        XCTAssertEqual(h.staleCount, 2)
    }

    // MARK: - resize / pageWidth（D6）

    func testResizeDuringTrackingProportionalRebase() {
        let h = CoreHarness(pageCount: 5, initialPage: 1)
        _ = h.begin()
        _ = h.change(delta: 100, dt: 1.0) // offset 1.1（1100 px）
        XCTAssertEqual(h.core.visualOffset, 1.1, accuracy: 1e-9)
        h.core.setPageWidth(500)          // 物理位置保持：1100 px / 500 = 2.2 页
        XCTAssertEqual(h.core.state, .tracking)
        XCTAssertEqual(h.core.visualOffset, 2.2, accuracy: 1e-9)
        XCTAssertEqual(h.core.currentSession?.startOffset ?? -1, 2.0, accuracy: 1e-9)
        XCTAssertEqual(h.core.currentSession?.currentOffset ?? -1, 2.2, accuracy: 1e-9)
        _ = h.change(delta: 100, dt: 1.0) // 手势继续：100 px 在新页宽 500 下 = 0.2 页
        XCTAssertEqual(h.core.visualOffset, 2.4, accuracy: 1e-9)
        _ = h.end(); _ = h.finish()
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 2) // 位移 1.3 页 ≥ 阈值 → 前进
        XCTAssertEqual(h.core.visualOffset, 2.0, accuracy: 1e-9)
        XCTAssertEqual(h.commitCount, 1)
    }

    func testResizeDuringSettlingRecomputesTargetWithNewToken() {
        let h = CoreHarness(pageCount: 5, initialPage: 1)
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end(); _ = h.finish()
        let ctxA = try! XCTUnwrap(h.core.activeTransition)
        XCTAssertEqual(ctxA.targetPage, 2)
        _ = h.tick(); _ = h.tick()
        let offsetBefore = h.core.visualOffset // ≈1.669
        h.core.setPageWidth(500)
        // 旧 token 作废；物理位置保持；目标 = round(rebased) + clamp
        XCTAssertEqual(h.staleCount, 1)
        XCTAssertEqual(h.core.activeTransition?.token, 2)
        XCTAssertEqual(h.core.visualOffset, offsetBefore * 2, accuracy: 1e-9)
        XCTAssertEqual(h.core.activeTransition?.targetPage, 3)
        XCTAssertEqual(h.core.activeTransition?.reason, .resizeRebase)
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 3)
        XCTAssertEqual(h.core.visualOffset, 3.0, accuracy: 1e-9)
        XCTAssertEqual(h.commitCount, 1)
        XCTAssertFalse(h.core.completeSettle(ctxA))
        XCTAssertEqual(h.staleCount, 2)
    }

    /// Q-2（Reviewer E）：resize/pageCount/RM 重启路径的 createdAt 必须是真实创建时间戳
    /// （诊断字段语义；旧实现恒 0）。锚点 1_600_000_000 = 2020-09，远早于任何真实运行。
    func testRestartPathsRecordCreationTimestamp() {
        // resize 重启（D6，settling 中 rebase）
        let h = CoreHarness(pageCount: 5, initialPage: 1)
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end(); _ = h.finish()
        XCTAssertEqual(h.core.state, .settling)
        h.core.setPageWidth(500)
        XCTAssertEqual(h.core.activeTransition?.reason, .resizeRebase)
        XCTAssertGreaterThan(h.core.activeTransition?.createdAt ?? 0, 1_600_000_000, "resizeRebase 路径记录真实时间戳")

        // pageCount 重启（D6，target 越界 → 作废 + 重置；合法 target 时不重启故不测）
        let h2 = CoreHarness(pageCount: 5, initialPage: 3)
        _ = h2.begin(); _ = h2.change(delta: 600, dt: 1.0); _ = h2.end(); _ = h2.finish()
        XCTAssertEqual(h2.core.activeTransition?.targetPage, 4)
        h2.core.setPageCount(3) // target 4 ≥ 3 → 作废 + clamp + 重置
        XCTAssertEqual(h2.core.activeTransition?.reason, .pageCountChange)
        XCTAssertGreaterThan(h2.core.activeTransition?.createdAt ?? 0, 1_600_000_000, "pageCountChange 路径记录真实时间戳")

        // RM 重启（D8；RM 下 beginSettle 立即完成 → 经 onTransitionBegin 记录捕获）
        let h3 = CoreHarness(pageCount: 5, initialPage: 1)
        _ = h3.begin(); _ = h3.change(delta: 600, dt: 1.0); _ = h3.end(); _ = h3.finish()
        XCTAssertEqual(h3.core.state, .settling)
        let transitionsBefore = h3.transitions.count
        h3.core.setReduceMotion(true)
        XCTAssertGreaterThan(h3.transitions.count, transitionsBefore, "RM 重启产生新 transition")
        XCTAssertEqual(h3.transitions.last?.reason, .reduceMotionChange)
        XCTAssertGreaterThan(h3.transitions.last?.createdAt ?? 0, 1_600_000_000, "reduceMotionChange 路径记录真实时间戳")
    }

    func testResizeIdle() {
        let h = CoreHarness(pageCount: 5, initialPage: 2)
        h.core.setPageWidth(2000)
        XCTAssertEqual(h.core.state, .idle)
        XCTAssertEqual(h.core.committedPage, 2)
        XCTAssertEqual(h.core.visualOffset, 2.0, accuracy: 1e-12) // 语义页静止位不变
        XCTAssertEqual(h.transitions.count, 0)
        XCTAssertEqual(h.commitCount, 0)
    }

    // MARK: - cancel / teardown（D1/D7）

    func testCancelDuringTracking() {
        let h = CoreHarness(pageCount: 5, initialPage: 1)
        _ = h.begin()
        _ = h.change(delta: 200, dt: 1.0)
        h.core.cancel()
        XCTAssertEqual(h.core.state, .idle)
        XCTAssertEqual(h.core.visualOffset, 1.0, accuracy: 1e-12) // 回到静止位
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.commitCount, 0)
        XCTAssertEqual(h.staleCount, 0)
        XCTAssertNil(h.core.currentSession)
        // 之后新手势正常
        _ = h.begin(); _ = h.change(delta: 200, dt: 1.0); _ = h.end(); _ = h.finish()
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.commitCount, 1)
    }

    func testCancelDuringSettling() {
        let h = CoreHarness(pageCount: 5)
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end(); _ = h.finish()
        let ctxA = try! XCTUnwrap(h.core.activeTransition)
        _ = h.tick(); _ = h.tick()
        h.core.cancel()
        XCTAssertEqual(h.core.state, .idle)
        XCTAssertEqual(h.core.visualOffset, 0, accuracy: 1e-12)
        XCTAssertEqual(h.core.committedPage, 0)
        XCTAssertEqual(h.commitCount, 0)
        XCTAssertEqual(h.staleCount, 1)
        XCTAssertFalse(h.core.completeSettle(ctxA))
        XCTAssertEqual(h.staleCount, 2)
    }

    func testTeardownNoResidualCallbacks() {
        let h = CoreHarness(pageCount: 5)
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end(); _ = h.finish()
        let ctxA = try! XCTUnwrap(h.core.activeTransition)
        _ = h.tick(); _ = h.tick()
        h.core.teardown()
        XCTAssertTrue(h.core.isTearingDown)
        XCTAssertEqual(h.core.state, .idle)
        XCTAssertNil(h.core.activeTransition)
        XCTAssertEqual(h.core.visualOffset, 0, accuracy: 1e-12)
        XCTAssertEqual(h.core.committedPage, 0)
        XCTAssertEqual(h.core.staleRejectionCount, 1) // 作废动画计入拒绝计数
        XCTAssertEqual(h.staleTokens.count, 0)        // 但 teardown 后不触发任何回调（D7）

        // teardown 后一切短路：无状态变化、无回调、无崩溃
        let eventsBefore = h.stateHistory.count + h.offsetHistory.count + h.commitContexts.count
        XCTAssertFalse(h.core.completeSettle(ctxA))
        XCTAssertEqual(h.core.staleRejectionCount, 2)  // 拒绝计数 +1，但不触发回调（D7）
        XCTAssertEqual(h.staleTokens.count, 0)
        XCTAssertFalse(h.tick())
        XCTAssertFalse(h.begin())
        XCTAssertFalse(h.change(delta: 500, dt: 1.0))
        XCTAssertFalse(h.end())
        XCTAssertFalse(h.finish())
        XCTAssertFalse(h.core.legacyScrollDelta(500, timestamp: 1))
        h.core.setPageWidth(999)   // no-op
        h.core.setPageCount(9)     // no-op
        h.core.setReduceMotion(true) // no-op
        h.core.cancel()            // no-op
        XCTAssertEqual(h.core.pageWidth, 1000)
        XCTAssertEqual(h.core.pageCount, 5)
        XCTAssertEqual(h.stateHistory.count + h.offsetHistory.count + h.commitContexts.count, eventsBefore)
    }

    // MARK: - Reduce Motion（D8）

    func testReduceMotionInstantCommit() {
        let h = CoreHarness(pageCount: 5, reduceMotion: true)
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end()
        XCTAssertTrue(h.finish())
        XCTAssertEqual(h.core.state, .idle) // 即刻提交，无需 tick
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.core.visualOffset, 1.0, accuracy: 1e-12)
        XCTAssertEqual(h.commitCount, 1)
    }

    func testReduceMotionInstantBounce() {
        let h = CoreHarness(pageCount: 5, reduceMotion: true)
        _ = h.begin(); _ = h.change(delta: 100, dt: 1.0); _ = h.end()
        XCTAssertTrue(h.finish())
        XCTAssertEqual(h.core.committedPage, 0)
        XCTAssertEqual(h.core.visualOffset, 0, accuracy: 1e-12)
        XCTAssertEqual(h.commitCount, 1)
    }

    func testReduceMotionNoOverscroll() {
        let h = CoreHarness(pageCount: 5, reduceMotion: true)
        _ = h.begin()
        _ = h.change(delta: -400, dt: 1.0)
        XCTAssertEqual(h.core.visualOffset, 0, accuracy: 1e-12) // RM overscroll = 0：硬边界
    }

    func testReduceMotionToggleMidSettle() {
        let h = CoreHarness(pageCount: 5, reduceMotion: false)
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end(); _ = h.finish()
        let ctxA = try! XCTUnwrap(h.core.activeTransition)
        _ = h.tick()
        h.core.setReduceMotion(true) // 动态切换：旧动画作废，RM 即刻提交
        XCTAssertEqual(h.staleCount, 1)
        XCTAssertEqual(h.core.state, .idle)
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.core.visualOffset, 1.0, accuracy: 1e-12)
        XCTAssertEqual(h.commitCount, 1)
        XCTAssertFalse(h.core.completeSettle(ctxA))
        XCTAssertEqual(h.staleCount, 2)
    }

    func testReduceMotionMomentumStillTurnsPage() {
        let h = CoreHarness(pageCount: 5, reduceMotion: true)
        _ = h.begin(); _ = h.change(delta: 100, dt: 1.0); _ = h.end()
        _ = h.momentumBegan()
        _ = h.momentumChange(delta: 150, dt: 0.05) // 3000 px/s
        XCTAssertTrue(h.momentumEnd())             // RM 下降级为不做惯性滑行，直接决策
        XCTAssertEqual(h.core.state, .idle)        // 即刻提交
        XCTAssertEqual(h.core.committedPage, 1)    // 高速甩动仍翻页（状态机逻辑不变）
        XCTAssertEqual(h.core.visualOffset, 1.0, accuracy: 1e-12)
        XCTAssertEqual(h.commitCount, 1)
    }

    // MARK: - momentum 子阶段与边界滑行

    func testMomentumIsTrackingSubStage() {
        let h = CoreHarness(pageCount: 5)
        _ = h.begin(); _ = h.change(delta: 30, dt: 1.0); _ = h.end()
        XCTAssertTrue(h.momentumBegan())
        XCTAssertEqual(h.core.state, .tracking) // momentum 不引入新顶层状态（D1）
        XCTAssertEqual(h.core.currentSession?.momentumActive, true)
        // 速度 30 px/s ≤ 停止阈值 → momentumEnd 直接决策（回弹）
        XCTAssertTrue(h.momentumEnd())
        XCTAssertEqual(h.core.state, .settling)
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 0)
        XCTAssertEqual(h.commitCount, 1)
    }

    func testMomentumGlideIntoBoundaryIsSafe() {
        let h = CoreHarness(pageCount: 5)
        _ = h.begin(); _ = h.change(delta: -50, dt: 0.05) // −1000 px/s
        _ = h.end()
        _ = h.momentumBegan()
        _ = h.momentumChange(delta: -200, dt: 0.05) // −4000 px/s
        XCTAssertTrue(h.momentumEnd())
        XCTAssertTrue(h.core.currentSession?.isMomentumGlide == true)
        h.tickUntilSettled() // 滑行撞首页边界 → 阻尼停止 → 回弹
        XCTAssertEqual(h.core.state, .idle)
        XCTAssertEqual(h.core.committedPage, 0)
        XCTAssertEqual(h.core.visualOffset, 0, accuracy: 1e-9)
        XCTAssertEqual(h.commitCount, 1)
        XCTAssertEqual(h.staleCount, 0)
    }

    // MARK: - momentum 系统流截断（T-worker-b-glide）

    private func glideParameters(_ frames: Int?) -> PagingParameters {
        var parameters = PagingParameters()
        parameters.momentumGlideFrames = frames
        return parameters
    }

    func testMomentumGlideFramesOneTruncatesLongStream() {
        // N=1：最多跟随 2 个 momentumChanged 事件后释放决策（settle），commit 恰 1 次，
        // 后续系统 momentum 事件被防御拒绝（无双重 commit）。
        let h = CoreHarness(pageCount: 5, parameters: glideParameters(1))
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end() // offset 0.6 → 过半
        XCTAssertTrue(h.momentumBegan())
        XCTAssertEqual(h.core.state, .tracking)
        _ = h.momentumChange(delta: 150, dt: 0.05)
        XCTAssertEqual(h.core.state, .tracking, "第 1 个 momentum 事件仍跟随")
        XCTAssertTrue(h.momentumChange(delta: 100, dt: 0.05))
        XCTAssertEqual(h.core.state, .settling, "第 2 个 momentum 事件后截断决策 → settle")
        XCTAssertEqual(h.commitCount, 0, "settle 未完成前不 commit")
        // 截断后系统流继续投递 → 全部防御拒绝，不得再进 tracking / 双重 commit。
        XCTAssertFalse(h.momentumChange(delta: 50, dt: 0.05))
        XCTAssertFalse(h.momentumChange(delta: 20, dt: 0.05))
        XCTAssertFalse(h.momentumEnd())
        XCTAssertEqual(h.core.state, .settling)
        XCTAssertEqual(h.staleCount, 0, "截断是正常决策，不产生 stale")
        h.tickUntilSettled()
        XCTAssertEqual(h.core.state, .idle)
        XCTAssertEqual(h.core.committedPage, 1, "位移过半 → 翻页")
        XCTAssertEqual(h.commitCount, 1, "commit 恰 1 次（无双重 commit）")
    }

    func testMomentumGlideFramesZeroDirectDecision() {
        // N=0：momentum 一开始即释放决策（=RM 降级效果），无系统流跟随。
        let h = CoreHarness(pageCount: 5, parameters: glideParameters(0))
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end()
        XCTAssertTrue(h.momentumBegan())
        XCTAssertEqual(h.core.state, .settling, "momentumBegan 即决策")
        XCTAssertFalse(h.momentumChange(delta: 150, dt: 0.05))
        XCTAssertFalse(h.momentumEnd())
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.commitCount, 1)
    }

    func testMomentumGlideFramesNilFollowsFullStream() {
        // nil（显式）= 跟随完整系统流（momentum 期间保持 tracking），不截断——语义保留。
        let h = CoreHarness(pageCount: 5, parameters: glideParameters(nil))
        _ = h.begin(); _ = h.change(delta: 30, dt: 1.0); _ = h.end()
        _ = h.momentumBegan()
        for _ in 0..<10 {
            XCTAssertTrue(h.momentumChange(delta: 1, dt: 0.05), "长系统流不被截断")
        }
        XCTAssertEqual(h.core.state, .tracking)
        // 速度 = 10×1px / 0.5s = 20px/s ≤ 停止阈值 40 → momentumEnd 直接决策（不滑行）。
        XCTAssertTrue(h.momentumEnd()) // 决策点仍在 momentumEnded
        XCTAssertEqual(h.core.state, .settling)
        h.tickUntilSettled()
        XCTAssertEqual(h.commitCount, 1)
    }

    func testMomentumGlideDefaultIsOne() {
        // 物理门固化：PagingParameters 默认 N=1（不再跟随完整系统流）——
        // 默认参数下第 2 个 momentum 事件后截断决策 → settle 吸住（惯性不拖长）。
        let h = CoreHarness(pageCount: 5) // 默认参数（momentumGlideFrames = 1）
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end() // offset 0.6 → 过半
        XCTAssertTrue(h.momentumBegan())
        XCTAssertEqual(h.core.state, .tracking)
        XCTAssertTrue(h.momentumChange(delta: 150, dt: 0.05))
        XCTAssertEqual(h.core.state, .tracking, "第 1 个 momentum 事件仍跟随")
        XCTAssertTrue(h.momentumChange(delta: 100, dt: 0.05))
        XCTAssertEqual(h.core.state, .settling, "第 2 个 momentum 事件后截断决策（默认 N=1）")
        XCTAssertFalse(h.momentumChange(delta: 50, dt: 0.05), "截断后系统流被防御拒绝")
        XCTAssertFalse(h.momentumEnd())
        h.tickUntilSettled()
        XCTAssertEqual(h.core.state, .idle)
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.commitCount, 1)
        XCTAssertEqual(h.staleCount, 0)
    }

    func testMomentumGlideFramesIgnoredUnderReduceMotion() {
        // RM 强制 0 语义：D8 既有降级不变——参数不改变 RM 行为（决策点仍在 momentumEnded）。
        var parameters = PagingParameters()
        parameters.momentumGlideFrames = 1
        let h = CoreHarness(pageCount: 5, parameters: parameters, reduceMotion: true)
        _ = h.begin(); _ = h.change(delta: 100, dt: 1.0); _ = h.end()
        _ = h.momentumBegan()
        _ = h.momentumChange(delta: 150, dt: 0.05) // 3000 px/s
        XCTAssertEqual(h.core.state, .tracking, "RM 下 momentum 流照常跟随（D8 行为不变）")
        XCTAssertTrue(h.momentumEnd())
        XCTAssertEqual(h.core.state, .idle) // RM 即刻提交
        XCTAssertEqual(h.core.committedPage, 1) // 高速甩动仍翻页
        XCTAssertEqual(h.commitCount, 1)
        XCTAssertFalse(h.core.currentSession?.isMomentumGlide ?? false)
    }

    func testMomentumGlideFramesTenTruncatesAtTwentyEvents() {
        // 用户复测试值 N=10（≈0.1s 目标）：最多跟随 20 个 momentumChanged 事件后决策，
        // 第 19 个仍跟随、第 20 个后 settle；后续事件拒绝；commit 恰 1 次。
        let h = CoreHarness(pageCount: 5, parameters: glideParameters(10))
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end() // offset 0.6 → 过半
        XCTAssertTrue(h.momentumBegan())
        for index in 1...19 {
            XCTAssertTrue(h.momentumChange(delta: 5, dt: 0.05), "第 \(index) 个事件仍跟随")
        }
        XCTAssertEqual(h.core.state, .tracking)
        XCTAssertTrue(h.momentumChange(delta: 5, dt: 0.05)) // 第 20 个 → 截断
        XCTAssertEqual(h.core.state, .settling, "第 20 个 momentum 事件后截断决策")
        XCTAssertFalse(h.momentumChange(delta: 5, dt: 0.05))
        XCTAssertFalse(h.momentumEnd())
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.commitCount, 1, "commit 恰 1 次（无双重 commit）")
        XCTAssertEqual(h.staleCount, 0)
    }

    // MARK: - momentum 过冲钳制（T-worker-b-overshoot）

    private func overshootParameters(frames: Int?, maxOvershoot: Double = 0.20) -> PagingParameters {
        var parameters = PagingParameters()
        parameters.momentumGlideFrames = frames
        parameters.momentumMaxOvershoot = maxOvershoot
        return parameters
    }

    func testMomentumOvershootClampedFastFling() {
        // gi=69 快甩事件形态（phys-auto-07）：ended 2.429 → 10 个 momentum 事件冲到 4.036。
        // 软阻尼递推（T-worker-b-softdamp）：越限（3.20）后 depth += 0.2×事件delta →
        // 峰值 = 3.20 + 0.2×(0.182+0.171+0.152+0.145+0.139+0.134+0.061) = 3.3968；
        // 截断点决策目标 3；拉回 = 0.3968 ≤ 0.20 + 阻尼余量。
        // 无静止帧：10 个事件 offset 严格单调递增；决策速度保留（样本真实 delta/dt ≫ 700）。
        let parameters = overshootParameters(frames: 5)
        let h = CoreHarness(pageCount: 5, parameters: parameters, initialPage: 2)
        _ = h.begin(); _ = h.change(delta: 429, dt: 0.05); _ = h.end() // offset 2.429（2.0+0.429，未触边界）
        XCTAssertTrue(h.momentumBegan())
        // 事件 delta（页）×1000px；dt 0.015s（≈66Hz，phys-auto-02 实测率）。
        let pageDeltas: [Double] = [0.221, 0.208, 0.194, 0.182, 0.171, 0.152, 0.145, 0.139, 0.134, 0.061]
        let limit = 2.0 + 1.0 + 0.20 // committed+1+maxOvershoot = 3.20
        let beyondDeltas: [Double] = [0.182, 0.171, 0.152, 0.145, 0.139, 0.134, 0.061] // 事件 4–10（越限后）
        let dampedExcess = 0.2 * beyondDeltas.reduce(0, +) // 0.1968
        var peak = 0.0
        var previous = h.core.visualOffset
        for (_, pages) in pageDeltas.enumerated() {
            _ = h.momentumChange(delta: pages * 1000, dt: 0.015)
            let current = h.core.visualOffset
            XCTAssertGreaterThan(current, previous, "钳制区无静止帧：每事件 offset 严格前进")
            previous = current
            peak = max(peak, current)
        }
        // 第 10 事件 = 截断点（2N=10）→ settle。
        XCTAssertEqual(h.core.state, .settling, "截断点决策")
        XCTAssertEqual(peak, limit + dampedExcess, accuracy: 1e-9,
                       "峰值 = 上限 + 0.2×越限后增量累计（硬钳制 3.20 / 无钳制 4.036）")
        let ctx = try! XCTUnwrap(h.core.activeTransition)
        XCTAssertEqual(ctx.targetPage, 3, "一页一翻：committed 2 → 3")
        XCTAssertEqual(ctx.fromOffset, limit + dampedExcess, accuracy: 1e-9, "settle 起点 = 软阻尼峰值位")
        XCTAssertLessThanOrEqual(abs(ctx.fromOffset - Double(ctx.targetPage)), 0.20 + dampedExcess + 1e-9,
                                 "拉回 ≤ 0.20 + 阻尼余量")
        XCTAssertGreaterThan(h.core.currentSession?.velocityPxPerSecond ?? 0, parameters.velocityThreshold,
                             "决策速度保留：真实样本速度 ≫ velocityThreshold（软阻尼不影响计速）")
        XCTAssertFalse(h.momentumChange(delta: 50, dt: 0.015))
        XCTAssertFalse(h.momentumEnd())
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 3)
        XCTAssertEqual(h.commitCount, 1, "commit 恰 1 次")
        XCTAssertEqual(h.staleCount, 0)
    }

    func testMomentumOvershootSoftDampNoFrozenFrames() {
        // 纯钳制区压力测试：8 个事件 ×0.3 页（raw 2.5→4.9）——硬钳制会顶死产生 6 个静止帧；
        // 软阻尼递推下每事件仍前进 0.2×delta = 0.06 页，严格递增，峰值 = 3.20 + 6×0.06 = 3.56。
        let h = CoreHarness(pageCount: 5, parameters: overshootParameters(frames: 10), initialPage: 2)
        _ = h.begin(); _ = h.change(delta: 500, dt: 1.0); _ = h.end() // offset 2.5
        XCTAssertTrue(h.momentumBegan())
        var peak = 0.0
        var previous = h.core.visualOffset
        for _ in 0..<8 { // 每事件 +0.3 页（300px @ 0.015s = 20000px/s）
            _ = h.momentumChange(delta: 300, dt: 0.015)
            let current = h.core.visualOffset
            XCTAssertGreaterThan(current, previous, "无静止帧：越限事件仍前进（阻尼 0.2×delta）")
            previous = current
            peak = max(peak, current)
        }
        XCTAssertEqual(h.core.state, .tracking, "2N=20 未截断，仍跟踪")
        XCTAssertEqual(peak, 3.20 + 6 * 0.2 * 0.3, accuracy: 1e-9, "峰值 = 上限 + 0.2×(越限后 6 事件增量) = 3.56")
        XCTAssertLessThanOrEqual(peak, 3.20 + 6 * 0.2 * 0.3 + 1e-9)
    }

    func testMomentumOvershootCustomValueApplied() {
        // 自定义 momentumMaxOvershoot（CLI 可调路径）：0.1 → 上限 3.10，
        // 峰值 = 3.10 + 0.2×0.984 = 3.2968。
        let h = CoreHarness(pageCount: 5, parameters: overshootParameters(frames: 5, maxOvershoot: 0.1), initialPage: 2)
        _ = h.begin(); _ = h.change(delta: 429, dt: 0.05); _ = h.end() // offset 2.429
        XCTAssertTrue(h.momentumBegan())
        let pageDeltas: [Double] = [0.221, 0.208, 0.194, 0.182, 0.171, 0.152, 0.145, 0.139, 0.134, 0.061]
        var peak = 0.0
        for (_, pages) in pageDeltas.enumerated() {
            _ = h.momentumChange(delta: pages * 1000, dt: 0.015)
            peak = max(peak, h.core.visualOffset)
        }
        XCTAssertEqual(h.core.state, .settling)
        let limit = 2.0 + 1.0 + 0.1 // 3.10
        let dampedExcess = 0.2 * [0.182, 0.171, 0.152, 0.145, 0.139, 0.134, 0.061].reduce(0, +)
        XCTAssertEqual(peak, limit + dampedExcess, accuracy: 1e-9, "自定义 0.1 软阻尼生效")
        let ctx = try! XCTUnwrap(h.core.activeTransition)
        XCTAssertEqual(ctx.targetPage, 3)
        XCTAssertEqual(ctx.fromOffset, limit + dampedExcess, accuracy: 1e-9)
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 3)
        XCTAssertEqual(h.commitCount, 1)
    }

    func testMomentumOvershootSoftDampReverse() {
        // 反向（往左，用户感知方向）：gi=71 形态——committed 3、ended 1.875 → 10 个负向 momentum
        // 事件反推。负向软阻尼（T-worker-b-symdamp 后）：阻尼线 = (committed−1)−0.2 = 1.8，
        // began 位 1.875 在线内（初深 0）→ 终点 = 1.8 − 0.2×1.607 = 1.4786；决策 retreat → 2；
        // 拉回 = 2.0 − 1.4786 = 0.5214 ≤ 0.20 + 0.3214。
        let parameters = overshootParameters(frames: 5)
        let h = CoreHarness(pageCount: 5, parameters: parameters, initialPage: 3)
        _ = h.begin(); _ = h.change(delta: -1125, dt: 0.05); _ = h.end() // offset 1.875
        XCTAssertTrue(h.momentumBegan())
        let pageDeltas: [Double] = [0.221, 0.208, 0.194, 0.182, 0.171, 0.152, 0.145, 0.139, 0.134, 0.061]
        let limit = (3.0 - 1.0) - 0.20 // 1.8（目标 2 − overshoot）
        let initialDepth = max(limit - 1.875, 0) // 0（began 在线内）
        let dampedExcess = 0.2 * pageDeltas.reduce(0, +) // 0.3214
        var previous = h.core.visualOffset
        for (_, pages) in pageDeltas.enumerated() {
            _ = h.momentumChange(delta: -pages * 1000, dt: 0.015)
            let current = h.core.visualOffset
            XCTAssertLessThan(current, previous, "负向钳制区无静止帧：每事件 offset 严格后退")
            previous = current
        }
        XCTAssertEqual(h.core.state, .settling, "第 10 事件 = 截断点（2N=10）")
        XCTAssertEqual(h.core.visualOffset, limit - (initialDepth + dampedExcess), accuracy: 1e-9,
                       "终点 = 阻尼线 −（初深 + 0.2×越限增量累计）")
        let ctx = try! XCTUnwrap(h.core.activeTransition)
        XCTAssertEqual(ctx.targetPage, 2, "一页一翻反向：committed 3 → 2")
        XCTAssertEqual(ctx.fromOffset, limit - (initialDepth + dampedExcess), accuracy: 1e-9)
        XCTAssertLessThanOrEqual(abs(ctx.fromOffset - Double(ctx.targetPage)), 0.20 + dampedExcess + 1e-9,
                                 "拉回 ≤ 0.20 + 阻尼余量")
        XCTAssertGreaterThan(abs(h.core.currentSession?.velocityPxPerSecond ?? 0), parameters.velocityThreshold,
                             "决策速度保留（负向）")
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 2)
        XCTAssertEqual(h.commitCount, 1)
        XCTAssertEqual(h.staleCount, 0)
    }

    func testMomentumOvershootSymmetryForwardBackward() {
        // T-worker-b-symdamp 对称性：阻尼线 = 目标页 ± overshoot（正向 3.2 / 负向 1.8），
        // 相同 |delta| 序列下正/负向自由行程相同（0.7 页），且均在事件 8 才首触阻尼，
        // 阻尼段每事件位移相同（0.02 页）。
        let hF = CoreHarness(pageCount: 5, parameters: overshootParameters(frames: 10), initialPage: 2)
        _ = hF.begin(); _ = hF.change(delta: 429, dt: 0.05); _ = hF.end() // 2.429
        XCTAssertTrue(hF.momentumBegan())
        var fwdAfter7 = 0.0
        for index in 0..<10 {
            _ = hF.momentumChange(delta: 100, dt: 0.015) // +0.1 页/事件
            if index == 6 { fwdAfter7 = hF.core.visualOffset }
        }
        XCTAssertEqual(fwdAfter7, 2.429 + 0.7, accuracy: 1e-9, "正向自由行程 0.7（事件 1–7 未阻尼）")
        XCTAssertEqual(hF.core.visualOffset, 3.2 + 3 * 0.02, accuracy: 1e-9, "正向事件 8–10 每事件 +0.02")

        let hB = CoreHarness(pageCount: 5, parameters: overshootParameters(frames: 10), initialPage: 3)
        _ = hB.begin(); _ = hB.change(delta: -429, dt: 0.05); _ = hB.end() // 2.571（阻尼线 1.8 + 0.771）
        XCTAssertTrue(hB.momentumBegan())
        var bwdAfter7 = 0.0
        for index in 0..<10 {
            _ = hB.momentumChange(delta: -100, dt: 0.015) // −0.1 页/事件
            if index == 6 { bwdAfter7 = hB.core.visualOffset }
        }
        XCTAssertEqual(bwdAfter7, 2.571 - 0.7, accuracy: 1e-9, "负向自由行程 0.7（事件 1–7 未阻尼）")
        XCTAssertEqual(hB.core.visualOffset, 1.8 - 3 * 0.02, accuracy: 1e-9, "负向事件 8–10 每事件 −0.02")

        XCTAssertEqual(abs(fwdAfter7 - 2.429), abs(2.571 - bwdAfter7), accuracy: 1e-9,
                       "正/负向自由行程相同（对称）")
        XCTAssertEqual(hF.core.visualOffset - 3.2, 1.8 - hB.core.visualOffset, accuracy: 1e-9,
                       "正/负向阻尼段位移对称（3.2+0.06 / 1.8−0.06）")
    }

    func testMomentumOvershootFirstPageBoundaryGoverns() {
        // committed=1 时负向阻尼线 = −0.2（< 首页 minLegal 0）——越界由既有边界阻尼负责：
        // 10×(−0.2) 从 0.95 冲过首页 0 → 边界阻尼递推封顶 −0.25（钳制线 −0.2 下 depth 计算
        // 自洽：display 仍 = −0.25，不叠加双重阻尼）。
        let h = CoreHarness(pageCount: 5, parameters: overshootParameters(frames: 10), initialPage: 1)
        _ = h.begin(); _ = h.change(delta: -50, dt: 0.05); _ = h.end() // offset 0.95
        XCTAssertTrue(h.momentumBegan())
        var trough = 0.0
        for _ in 0..<10 {
            _ = h.momentumChange(delta: -200, dt: 0.015) // −0.2 页/事件
            trough = min(trough, h.core.visualOffset)
        }
        XCTAssertEqual(trough, -0.25, accuracy: 1e-9, "边界 overscroll 封顶 −0.25（非阻尼线 −0.2）")
        XCTAssertGreaterThanOrEqual(trough, -0.25 - 1e-9)
        _ = h.momentumEnd()
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 0) // 高速负向 → retreat → 首页
        XCTAssertEqual(h.commitCount, 1)
    }

    func testMomentumOvershootSlowFlingUnclamped() {
        // 慢甩：offset 未越限（< committed+1+0.35）→ 钳制不触发，峰值 = 真实累计。
        // 位移 0.64 ≥ 0.5 → 按位移翻页（速度 600px/s < 700 非强制）。
        let h = CoreHarness(pageCount: 5, parameters: overshootParameters(frames: 1), initialPage: 2)
        _ = h.begin(); _ = h.change(delta: 600, dt: 1.0); _ = h.end() // offset 2.6
        XCTAssertTrue(h.momentumBegan())
        _ = h.momentumChange(delta: 20, dt: 0.05) // +0.02 页
        XCTAssertEqual(h.core.visualOffset, 2.62, accuracy: 1e-9, "未触发钳制（< 3.35）")
        XCTAssertEqual(h.core.state, .tracking)
        XCTAssertTrue(h.momentumChange(delta: 20, dt: 0.05)) // 第 2 事件 = 截断点（2N=2）
        XCTAssertEqual(h.core.state, .settling)
        XCTAssertEqual(h.core.visualOffset, 2.64, accuracy: 1e-9, "峰值 = 真实累计，无钳制")
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 3) // 位移 0.64 ≥ 0.5 → 翻页
        XCTAssertEqual(h.commitCount, 1)
    }

    func testMomentumOvershootBoundaryLastPageDampingGoverns() {
        // 边界页（末页）：正向越界走既有 overscroll 阻尼（增量 ×0.35 阻尼、深度封顶 0.25），
        // 本钳制不介入（committed == pageCount-1 → guard 跳过）。
        // 深度递推：手指 0.2×0.35=0.07 → 5 事件各 +0.05×0.35=0.0175 → 0.1575。
        let h = CoreHarness(pageCount: 5, parameters: overshootParameters(frames: 10), initialPage: 4)
        _ = h.begin(); _ = h.change(delta: 200, dt: 1.0); _ = h.end() // offset 4.07（边界阻尼后）
        XCTAssertTrue(h.momentumBegan())
        var peak = 0.0
        for _ in 0..<5 {
            _ = h.momentumChange(delta: 50, dt: 0.05)
            peak = max(peak, h.core.visualOffset)
        }
        XCTAssertEqual(peak, 4.0 + 0.1575, accuracy: 1e-9, "边界阻尼递推值（非 momentum 钳制上界 3.35+）")
        XCTAssertLessThanOrEqual(peak, 4.25 + 1e-9, "边界 overscroll 封顶 0.25 未被突破")
        _ = h.momentumEnd() // 高速（1000px/s）→ glide → 撞边界 → 回弹
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 4)
        XCTAssertEqual(h.commitCount, 1)
    }

    func testMomentumOvershootBoundaryFirstPageBackward() {
        // 边界页（首页）：负向越界走既有 overscroll 阻尼（下限 -0.25），本钳制不介入
        // （committed == 0 → guard 跳过）。深度递推：手指 0.05×0.35=0.0175 → 5 事件
        // 各 +0.05×0.35=0.0175 → 0.105。
        let h = CoreHarness(pageCount: 5, parameters: overshootParameters(frames: 10), initialPage: 0)
        _ = h.begin(); _ = h.change(delta: -50, dt: 0.05); _ = h.end() // offset -0.0175（边界阻尼后）
        XCTAssertTrue(h.momentumBegan())
        var trough = 0.0
        for _ in 0..<5 {
            _ = h.momentumChange(delta: -50, dt: 0.05)
            trough = min(trough, h.core.visualOffset)
        }
        XCTAssertEqual(trough, -0.105, accuracy: 1e-9, "边界阻尼递推值")
        XCTAssertGreaterThanOrEqual(trough, -0.25 - 1e-9, "边界 overscroll 下限 -0.25 未被突破")
        _ = h.momentumEnd()
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 0)
        XCTAssertEqual(h.commitCount, 1)
    }

    // MARK: - 防御性事件序列（D5）

    func testDefensiveDuplicateBeganIgnored() {
        let h = CoreHarness(pageCount: 5)
        XCTAssertTrue(h.begin())
        let sessionID = h.core.currentSession?.id
        XCTAssertFalse(h.begin()) // 手指未抬起时的重复 began → 忽略
        XCTAssertEqual(h.core.currentSession?.id, sessionID)
    }

    func testDefensiveChangedWithoutSession() {
        let h = CoreHarness(pageCount: 5)
        XCTAssertFalse(h.change(delta: 500, dt: 1.0))
        XCTAssertEqual(h.core.visualOffset, 0, accuracy: 1e-12)
    }

    func testDefensiveEndedWithoutSession() {
        let h = CoreHarness(pageCount: 5)
        XCTAssertFalse(h.end())
    }

    func testDefensiveChangedAfterEndedIgnored() {
        let h = CoreHarness(pageCount: 5)
        _ = h.begin(); _ = h.change(delta: 100, dt: 1.0)
        XCTAssertTrue(h.end())
        XCTAssertFalse(h.change(delta: 500, dt: 1.0)) // ended 后 changed 忽略
        XCTAssertEqual(h.core.visualOffset, 0.1, accuracy: 1e-9)
    }

    func testDefensiveEndedAfterEndedIgnored() {
        let h = CoreHarness(pageCount: 5)
        _ = h.begin(); _ = h.change(delta: 100, dt: 1.0)
        XCTAssertTrue(h.end())
        XCTAssertFalse(h.end())
    }

    func testDefensiveMomentumWithoutRelease() {
        let h = CoreHarness(pageCount: 5)
        _ = h.begin()
        XCTAssertFalse(h.momentumBegan()) // 未 ended 的 momentum → 忽略
        XCTAssertFalse(h.momentumChange(delta: 100, dt: 0.05))
    }

    func testDefensiveMomentumChangedWithoutMomentumBegan() {
        let h = CoreHarness(pageCount: 5)
        _ = h.begin(); _ = h.change(delta: 100, dt: 1.0); _ = h.end()
        XCTAssertFalse(h.momentumChange(delta: 100, dt: 0.05))
    }

    func testDefensivePhaseCancelledSnapsToRest() {
        let h = CoreHarness(pageCount: 5, initialPage: 1)
        _ = h.begin()
        _ = h.change(delta: 200, dt: 1.0)
        XCTAssertEqual(h.core.visualOffset, 1.2, accuracy: 1e-9)
        h.cancelled()
        XCTAssertEqual(h.core.state, .idle)
        XCTAssertEqual(h.core.visualOffset, 1.0, accuracy: 1e-12) // 回到静止位，不 commit
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.commitCount, 0)
        XCTAssertNil(h.core.currentSession)
        // 之后新手势正常
        XCTAssertTrue(h.begin())
        XCTAssertEqual(h.core.state, .tracking)
    }

    func testLegacyScrollFallback() {
        let h = CoreHarness(pageCount: 5)
        XCTAssertTrue(h.core.legacyScrollDelta(600, timestamp: 0)) // 单次位移即完整手势
        XCTAssertEqual(h.core.state, .settling)
        h.tickUntilSettled()
        XCTAssertEqual(h.core.committedPage, 1)
        XCTAssertEqual(h.commitCount, 1)
    }
}
