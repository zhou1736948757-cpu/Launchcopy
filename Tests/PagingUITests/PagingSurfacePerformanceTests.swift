//
//  PagingSurfacePerformanceTests.swift
//  PagingUITests
//
//  §7.4 性能边界（回归预警，非物理门）：view 数量上界、布局次数可观测、
//  长序列内存增长有界、stale completion 零提交。
//

import AppKit
import XCTest
@testable import PagingCore
@testable import PagingUI

final class PagingSurfacePerformanceTests: XCTestCase {

    /// 单页 view 预算：ceil(livePageRadius + prewarmDistance) × 2 + 1 = 3×2+1 = 7。
    private var viewBudget: Int { 7 }

    @MainActor
    func testViewBudgetBoundedAcrossLongScroll() async {
        let surface = makeSurface(pageCount: 100)
        // 半径 3：center 0 → 范围 [0,3]（4 个 live），永不超预算。
        XCTAssertEqual(surface.liveHostCount, 4)
        XCTAssertLessThanOrEqual(surface.liveHostCount, viewBudget)

        for round in 0..<30 {
            flingForwardOnce(surface, at: TimeInterval(round) * 10)
            XCTAssertLessThanOrEqual(surface.liveHostCount, viewBudget,
                                     "round \(round)：live view 数量上界")
            XCTAssertLessThanOrEqual(surface.poolHostCount, viewBudget,
                                     "round \(round)：复用池上界")
            // 每个 live 页索引合法且内容正确。
            for index in 0..<100 where surface.hostForPage(index) != nil {
                XCTAssertLessThan(index, surface.core.pageCount)
                await drainDeferredPresentationTurns()
                XCTAssertEqual(surface.hostForPage(index)?.accessibilityLabel() as? String,
                               "Page \(index + 1) of 100")
            }
        }
        XCTAssertEqual(surface.core.committedPage, 30)
        // center 30 → 范围 [27,33] → 满预算 7 个 live。
        XCTAssertEqual(surface.liveHostCount, viewBudget)
    }

    func testLayoutCountIsEventDrivenNotPerFrame() {
        let surface = makeSurface(pageCount: 5)
        let layoutsBefore = surface.layoutPerformedCount

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 400, at: 0.5)
        gestureEnded(surface, at: 0.5)
        finishPendingGesture(surface, at: 0.5)
        XCTAssertEqual(surface.core.state, .settling)

        for _ in 0..<60 { surface.advanceFrame(deltaTime: 1.0 / 60.0) }
        XCTAssertFalse(surface.core.isAnimating)

        // settle 60 帧内最多 1 次范围变化重布局（跨 0.5 边界），绝非每帧布局。
        let layoutsDuringSettle = surface.layoutPerformedCount - layoutsBefore
        XCTAssertLessThanOrEqual(layoutsDuringSettle, 2,
                                 "settle 帧不得触发布局风暴（实际 \(layoutsDuringSettle) 次）")
        XCTAssertEqual(surface.core.committedPage, 1)
    }

    func testLongSequenceMemoryGrowthBounded() {
        let surface = makeSurface(pageCount: 200)
        var peakLive = 0
        var peakPool = 0
        for round in 0..<40 {
            flingForwardOnce(surface, at: TimeInterval(round) * 10)
            peakLive = max(peakLive, surface.liveHostCount)
            peakPool = max(peakPool, surface.poolHostCount)
        }
        XCTAssertLessThanOrEqual(peakLive, viewBudget)
        XCTAssertLessThanOrEqual(peakPool, viewBudget)
        // 总 host 数（live + pool）恒有界：40 页旅程后仍 ≤ 2×预算。
        XCTAssertLessThanOrEqual(peakLive + peakPool, viewBudget * 2)
        XCTAssertEqual(surface.core.committedPage, 40)
    }

    func testStaleCompletionZeroCommitUnderRapidInterrupts() {
        let surface = makeSurface(pageCount: 5)
        // 先翻到 page 1（避免边界回弹同页提交干扰计数）。
        flingForwardOnce(surface)
        XCTAssertEqual(surface.core.committedPage, 1)
        XCTAssertEqual(surface.core.commitCount, 1)

        // 第二次翻页停在 settle 中（不推进动画）→ 留下一个活跃动画。
        gestureBegan(surface, at: 10)
        gestureChanged(surface, deltaX: 400, at: 10.5)
        gestureEnded(surface, at: 10.5)
        finishPendingGesture(surface, at: 10.5)
        XCTAssertEqual(surface.core.state, .settling)
        XCTAssertEqual(surface.core.commitCount, 1)

        // 5 次快速正反接管：每次 began 都打断一个活跃 settle（stale +1），
        // 期间零提交；最后一次 settle（后退到 0）随后自然完成。
        for round in 1...5 {
            let t = 10.5 + TimeInterval(round) * 0.1
            gestureBegan(surface, at: t)
            gestureChanged(surface, deltaX: CGFloat(round % 2 == 0 ? 600 : -600), at: t + 0.05)
            gestureEnded(surface, at: t + 0.05)
            finishPendingGesture(surface, at: t + 0.05)
        }
        XCTAssertEqual(surface.core.state, .settling)
        XCTAssertEqual(surface.core.commitCount, 1, "5 次接管期间零新提交")
        XCTAssertEqual(surface.core.staleRejectionCount, 5, "每次接管作废一个活跃动画")

        settleFrames(surface)
        XCTAssertEqual(surface.core.commitCount, 2, "只有最后一个 settle 自然完成")
        XCTAssertEqual(surface.core.committedPage, 0)
        XCTAssertEqual(surface.core.state, .idle)
    }

    func testPageFramesNeverOverlapAcrossScroll() {
        let surface = makeSurface(pageCount: 100)
        for round in 0..<20 {
            flingForwardOnce(surface, at: TimeInterval(round) * 10)
            let indices = (0..<100).filter { surface.hostForPage($0) != nil }.sorted()
            for pair in zip(indices, indices.dropFirst()) {
                let a = surface.hostForPage(pair.0)!
                let b = surface.hostForPage(pair.1)!
                XCTAssertEqual(a.frame.maxX, b.frame.minX, accuracy: 0.001,
                               "round \(round)：页面 frame 连续无重叠")
            }
        }
    }
}
