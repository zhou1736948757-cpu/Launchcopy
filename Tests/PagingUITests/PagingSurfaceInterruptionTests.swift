//
//  PagingSurfaceInterruptionTests.swift
//  PagingUITests
//
//  §3.F 中断安全硬门禁（UI 层验证）：立即接管、位置连续、不跳回旧点、
//  旧 completion 不覆盖、无双重 commit、关闭/resize/pageCount 安全。
//

import AppKit
import XCTest
@testable import PagingCore
@testable import PagingUI

final class PagingSurfaceInterruptionTests: XCTestCase {

    /// 开始一个翻页 settle 并推进若干帧。
    private func startSettling(_ surface: PagingSurface) -> (offsetBefore: Double, originBefore: CGFloat) {
        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 600, at: 0.5)
        gestureEnded(surface, at: 0.5)
        finishPendingGesture(surface, at: 0.5)
        XCTAssertEqual(surface.core.state, .settling)
        for _ in 0..<3 { surface.advanceFrame(deltaTime: 1.0 / 60.0) }
        return (surface.core.visualOffset, surface.pageContainer.frame.minX)
    }

    // MARK: - 可观测性转发（T-step6 探针发现：stale/interruption 曾不外发）

    /// Core 的 stale/interruption 事件必须经 surface.appEvents 外发
    /// （telemetry 桥依赖此转发记录 stale_rejected / interruption.began）。
    func testStaleAndInterruptionEventsForwardedToAppEvents() {
        let surface = makeSurface(pageCount: 5)
        var staleTokens: [UInt64] = []
        var interruptions: [PagingInterruption] = []
        surface.appEvents.onStaleRejection = { staleTokens.append($0) }
        surface.appEvents.onInterruption = { interruptions.append($0) }

        // 开始一个活跃 settle。
        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 600, at: 0.5)
        gestureEnded(surface, at: 0.5)
        finishPendingGesture(surface, at: 0.5)
        XCTAssertEqual(surface.core.state, .settling)
        XCTAssertTrue(staleTokens.isEmpty)
        XCTAssertTrue(interruptions.isEmpty)

        // settle 中接管：作废动画 → stale + interruption 各一。
        gestureBegan(surface, at: 1.0)
        XCTAssertEqual(surface.core.state, .tracking)
        XCTAssertEqual(interruptions.count, 1)
        XCTAssertEqual(staleTokens.count, 1)
        XCTAssertEqual(interruptions.first?.takeoverOffset ?? -1, surface.core.visualOffset, accuracy: 1e-9)
        XCTAssertNotNil(interruptions.first?.abandonedToken)
    }

    // MARK: - 硬门禁 1+2：settle 未结束新手势立即接管，位置连续（无跳变）

    func testInterruptTakeoverIsImmediateAndContinuous() {
        let surface = makeSurface(pageCount: 5)
        let (offsetBefore, originBefore) = startSettling(surface)

        gestureBegan(surface, at: 1.0) // settle 中新手势
        XCTAssertEqual(surface.core.state, .tracking)
        XCTAssertEqual(surface.core.interruptionCount, 1)
        // 接管点 = 当前显示位置：容器 origin 与偏移均无跳变。
        XCTAssertEqual(surface.pageContainer.frame.minX, originBefore, accuracy: 0.001)
        XCTAssertEqual(surface.core.visualOffset, offsetBefore, accuracy: 1e-9)
        XCTAssertEqual(surface.core.currentSession?.startOffset ?? -1, offsetBefore, accuracy: 1e-9)
        XCTAssertNil(surface.core.activeTransition)
    }

    // MARK: - 硬门禁 3+4：不跳回旧目标；旧 completion 不覆盖新状态

    func testOldCompletionDoesNotOverrideNewState() {
        let surface = makeSurface(pageCount: 5)
        let (_, _) = startSettling(surface)
        let oldContext = try! XCTUnwrap(surface.core.activeTransition) // 已被 interrupt 作废前的 ctx

        // 反向接管并完成新 settle
        gestureBegan(surface, at: 1.0)
        gestureChanged(surface, deltaX: -900, at: 1.5)
        gestureEnded(surface, at: 1.5)
        finishPendingGesture(surface, at: 1.5)
        XCTAssertEqual(surface.core.activeTransition?.targetPage, 0)
        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 0)
        XCTAssertEqual(surface.core.commitCount, 1)

        // 旧 completion 晚到：被拒，UI 状态不变。
        let offsetBefore = surface.core.visualOffset
        let originBefore = surface.pageContainer.frame.minX
        XCTAssertFalse(surface.core.completeSettle(oldContext))
        XCTAssertEqual(surface.core.visualOffset, offsetBefore, accuracy: 1e-9)
        XCTAssertEqual(surface.pageContainer.frame.minX, originBefore, accuracy: 0.001)
        XCTAssertEqual(surface.core.committedPage, 0)
    }

    // MARK: - 硬门禁 5：快速连续正反向操作无双重 commit

    func testRapidDoubleReverseSingleCommit() {
        let surface = makeSurface(pageCount: 5)
        for round in 0..<6 {
            let t = TimeInterval(round) * 10
            gestureBegan(surface, at: t)
            gestureChanged(surface, deltaX: 900, at: t + 0.1)
            gestureEnded(surface, at: t + 0.1)
            finishPendingGesture(surface, at: t + 0.1)
            // settle 未完成即反向
            gestureBegan(surface, at: t + 0.2)
            gestureChanged(surface, deltaX: -900, at: t + 0.3)
            gestureEnded(surface, at: t + 0.3)
            finishPendingGesture(surface, at: t + 0.3)
            settleFrames(surface)
        }
        XCTAssertEqual(surface.core.commitCount, 6, "每次反向接管后仅一次 commit，无双重 commit")
        XCTAssertEqual(surface.core.committedPage, 0)
        XCTAssertEqual(surface.core.state, .idle)
    }

    // MARK: - 硬门禁 6：resize / pageCount / 关闭安全

    func testResizeDuringSettlingRebasesAndRealigns() {
        let surface = makeSurface(pageCount: 5)
        let (offsetBefore, _) = startSettling(surface)

        surface.frame = NSRect(x: 0, y: 0, width: 500, height: 600)
        surface.layout() // resize 事件 → Core setPageWidth + 重布局
        XCTAssertEqual(surface.core.pageWidth, 500, accuracy: 1e-9)
        // D6 settling：offset 按 old/new 比例 rebase（×2），物理位置保持：
        // 容器 origin = -(offsetBefore×2)×500 = -offsetBefore×1000。
        XCTAssertEqual(surface.pageContainer.frame.minX, -offsetBefore * 1000, accuracy: 0.001)
        // 全部 live 页面按新宽度重新对齐（范围 center 1 → [0,4]，5 页全在）。
        for index in 0..<5 {
            XCTAssertEqual(surface.hostForPage(index)?.frame.width ?? 0, 500, accuracy: 0.001)
            XCTAssertEqual(surface.hostForPage(index)?.frame.minX ?? -1, CGFloat(index) * 500, accuracy: 0.001)
        }
        XCTAssertEqual(surface.pageContainer.frame.width, 5 * 500, accuracy: 0.001)
        settleFrames(surface)
        XCTAssertEqual(surface.core.state, .idle)
    }

    func testPageCountReductionDuringSettlingIsSafe() {
        let surface = makeSurface(pageCount: 5)
        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 1200, at: 0.5) // 两页位移
        gestureEnded(surface, at: 0.5)
        finishPendingGesture(surface, at: 0.5)
        // 单页决策 → target 1（从 page 0）
        XCTAssertEqual(surface.core.activeTransition?.targetPage, 1)
        _ = surface.advanceFrame(deltaTime: 1.0 / 60.0)

        surface.setPageCount(1) // 页数变 1：目标越界 → 作废 + clamp + 新 settle
        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 0)
        XCTAssertEqual(surface.core.visualOffset, 0, accuracy: 1e-9)
        XCTAssertNil(surface.hostForPage(1))
        XCTAssertEqual(surface.accessibilityDescription, "Page 1 of 1")
    }

    func testWindowCloseDuringSettleLeavesNoResidual() {
        // 用真实 display link 驱动（makeSurface 会置 nil；本测试验证驱动生命周期）。
        let surface = PagingSurface(pageCount: 5, itemsPerPage: 8)
        surface.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
        surface.layout()
        let driver = surface.frameDriver

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 600, at: 0.5)
        gestureEnded(surface, at: 0.5)
        finishPendingGesture(surface, at: 0.5)
        XCTAssertEqual(surface.core.state, .settling)
        XCTAssertTrue(driver?.isRunning ?? false, "settle 期间 display link 运行")

        surface.viewDidMoveToWindow() // 窗口关闭
        XCTAssertTrue(surface.isTearingDown)
        XCTAssertFalse(driver?.isRunning ?? true)
        XCTAssertTrue(surface.core.isTearingDown)

        // 之后任何输入/帧推进均为 no-op（无残留动画驱动器、无崩溃）。
        surface.advanceFrame(deltaTime: 1.0 / 60.0)
        gestureBegan(surface, at: 2.0)
        gestureChanged(surface, deltaX: 400, at: 2.5)
        XCTAssertEqual(surface.core.state, .idle)
        XCTAssertEqual(surface.core.committedPage, 0)
    }

    // MARK: - momentum 接管（D4：滑行中新手势同样立即接管）

    func testMomentumGlideInterruptedByNewGesture() {
        let surface = makeSurface(pageCount: 5)
        // 甩出 momentum → 惯性滑行
        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: -100, at: 0.05)
        gestureEnded(surface, at: 0.05)
        momentumBegan(surface, at: 0.05)
        momentumChanged(surface, deltaX: -200, at: 0.1)
        momentumEnded(surface, at: 0.1)
        XCTAssertTrue(surface.core.currentSession?.isMomentumGlide ?? false)
        _ = surface.advanceFrame(deltaTime: 1.0 / 60.0)

        // 滑行中新手势接管：位置连续。
        let offsetBefore = surface.core.visualOffset
        gestureBegan(surface, at: 0.2)
        XCTAssertEqual(surface.core.state, .tracking)
        XCTAssertEqual(surface.core.visualOffset, offsetBefore, accuracy: 1e-9)
        XCTAssertFalse(surface.core.currentSession?.isMomentumGlide ?? true)
        gestureChanged(surface, deltaX: -300, at: 0.3)
        gestureEnded(surface, at: 0.3)
        finishPendingGesture(surface, at: 0.3)
        settleFrames(surface)
        XCTAssertEqual(surface.core.state, .idle)
    }
}
