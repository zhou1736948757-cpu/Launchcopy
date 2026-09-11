// AppGridUITests — EdgePagingSchedulerTests（T-1F-C-tests-edge）
// 覆盖 EdgePagingScheduler 测试矩阵：进入/离开（hysteresis 回退）、首尾边界、
// dwell 满翻页（连续翻页）、翻页最小间隔、过期 timer、跨区、cancel、nextDwellDeadline。
// 纯调度器 API（无布局）；时序由 DragSessionTestSupport.FakeDragClock 驱动。
// fixture 为纯几何合成数据（无真实 app 身份）。

import Foundation
import XCTest
@testable import AppGridUI

final class EdgePagingSchedulerTests: XCTestCase {

    // MARK: - 工厂

    /// 小参数构造（仅 edge 相关参数可调；其余取默认初值）。
    private func makeParams(edgeDwellDurationMs: Double = 500,
                             edgeZoneWidthPT: Double = 40,
                             edgeHysteresisPT: Double = 10,
                             edgeTurnMinIntervalMs: Double = 400) -> DragParameters {
        DragParameters(dragStartThresholdPT: 6,
                       edgeDwellDurationMs: edgeDwellDurationMs,
                       edgeZoneWidthPT: edgeZoneWidthPT,
                       edgeHysteresisPT: edgeHysteresisPT,
                       dropZoneMarginsPT: 8,
                       overlayMoveOutArmThresholdPT: 24,
                       edgeTurnMinIntervalMs: edgeTurnMinIntervalMs,
                       maxDragPreviewScale: 1.0)
    }

    /// 容器 400pt：左缘 x<40，右缘 x>360；离开回退带 40..<50 / 350..360。
    private let containerWidth = 400.0

    // MARK: - 1. 进入/离开

    func testEnterLeftEdgeArmsDwell() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()

        let events = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                                       containerWidth: containerWidth,
                                       page: 2, pageCount: 5,
                                       now: clock.now(), parameters: params)

        XCTAssertEqual(events, [.edgeEntered(.left), .dwellStarted(.left)])
        XCTAssertEqual(scheduler.currentZone, .left)
        XCTAssertTrue(scheduler.dwellArmed)
    }

    func testLeaveLeftEdgeEmitsEdgeLeftAndDisarms() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()
        _ = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                             containerWidth: containerWidth,
                             page: 2, pageCount: 5,
                             now: clock.now(), parameters: params)

        clock.current = 101
        let events = scheduler.update(pointer: DragPoint(x: 60, y: 100),
                                       containerWidth: containerWidth,
                                       page: 2, pageCount: 5,
                                       now: clock.now(), parameters: params)

        XCTAssertEqual(events, [.edgeLeft(.left)])
        XCTAssertNil(scheduler.currentZone)
        XCTAssertFalse(scheduler.dwellArmed)
    }

    func testHysteresisKeepsZoneWithinFallbackBand() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()
        _ = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                             containerWidth: containerWidth,
                             page: 2, pageCount: 5,
                             now: clock.now(), parameters: params)

        // x = 45 在左缘回退带（40..<50）内：仍属 .left，无事件。
        clock.current = 101
        let events = scheduler.update(pointer: DragPoint(x: 45, y: 100),
                                       containerWidth: containerWidth,
                                       page: 2, pageCount: 5,
                                       now: clock.now(), parameters: params)

        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(scheduler.currentZone, .left)
        XCTAssertTrue(scheduler.dwellArmed)
    }

    func testLeaveRightEdgeWithHysteresis() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()
        _ = scheduler.update(pointer: DragPoint(x: 390, y: 100),
                             containerWidth: containerWidth,
                             page: 2, pageCount: 5,
                             now: clock.now(), parameters: params)

        // x = 355 在右缘回退带（350..360] 内：仍属 .right，无事件。
        clock.current = 101
        XCTAssertTrue(scheduler.update(pointer: DragPoint(x: 355, y: 100),
                                       containerWidth: containerWidth,
                                       page: 2, pageCount: 5,
                                       now: clock.now(), parameters: params).isEmpty)

        // x = 340 越过回退带：离开。
        clock.current = 102
        let events = scheduler.update(pointer: DragPoint(x: 340, y: 100),
                                       containerWidth: containerWidth,
                                       page: 2, pageCount: 5,
                                       now: clock.now(), parameters: params)
        XCTAssertEqual(events, [.edgeLeft(.right)])
        XCTAssertNil(scheduler.currentZone)
        XCTAssertFalse(scheduler.dwellArmed)
    }

    func testUpdateWithinSameZoneEmitsNothing() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()
        _ = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                             containerWidth: containerWidth,
                             page: 2, pageCount: 5,
                             now: clock.now(), parameters: params)

        clock.current = 100.1
        let events = scheduler.update(pointer: DragPoint(x: 20, y: 100),
                                       containerWidth: containerWidth,
                                       page: 2, pageCount: 5,
                                       now: clock.now(), parameters: params)

        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(scheduler.currentZone, .left)
        XCTAssertTrue(scheduler.dwellArmed)
    }

    func testUpdateOutsideZoneEmitsNothing() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()

        let events = scheduler.update(pointer: DragPoint(x: 200, y: 100),
                                       containerWidth: containerWidth,
                                       page: 2, pageCount: 5,
                                       now: clock.now(), parameters: params)

        XCTAssertTrue(events.isEmpty)
        XCTAssertNil(scheduler.currentZone)
        XCTAssertFalse(scheduler.dwellArmed)
    }

    // MARK: - 2. 首尾边界

    func testFirstPageLeftEdgeEmitsAtFirstPageWithoutDwell() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()

        let events = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                                       containerWidth: containerWidth,
                                       page: 0, pageCount: 5,
                                       now: clock.now(), parameters: params)

        XCTAssertEqual(events, [.edgeEntered(.left), .atFirstPage(.left)])
        XCTAssertEqual(scheduler.currentZone, .left)
        XCTAssertFalse(scheduler.dwellArmed)
    }

    func testLastPageRightEdgeEmitsAtLastPageWithoutDwell() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()

        let events = scheduler.update(pointer: DragPoint(x: 390, y: 100),
                                       containerWidth: containerWidth,
                                       page: 4, pageCount: 5,
                                       now: clock.now(), parameters: params)

        XCTAssertEqual(events, [.edgeEntered(.right), .atLastPage(.right)])
        XCTAssertEqual(scheduler.currentZone, .right)
        XCTAssertFalse(scheduler.dwellArmed)
    }

    func testMiddlePageRightEdgeArmsDwell() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()

        let events = scheduler.update(pointer: DragPoint(x: 390, y: 100),
                                       containerWidth: containerWidth,
                                       page: 2, pageCount: 5,
                                       now: clock.now(), parameters: params)

        XCTAssertEqual(events, [.edgeEntered(.right), .dwellStarted(.right)])
        XCTAssertEqual(scheduler.currentZone, .right)
        XCTAssertTrue(scheduler.dwellArmed)
    }

    func testSinglePageBothEdgesAreBoundaries() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()

        let left = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                                     containerWidth: containerWidth,
                                     page: 0, pageCount: 1,
                                     now: clock.now(), parameters: params)
        XCTAssertEqual(left, [.edgeEntered(.left), .atFirstPage(.left)])
        XCTAssertFalse(scheduler.dwellArmed)

        clock.current = 101
        let right = scheduler.update(pointer: DragPoint(x: 390, y: 100),
                                      containerWidth: containerWidth,
                                      page: 0, pageCount: 1,
                                      now: clock.now(), parameters: params)
        XCTAssertEqual(right, [.edgeLeft(.left), .edgeEntered(.right), .atLastPage(.right)])
        XCTAssertFalse(scheduler.dwellArmed)
    }

    func testLeaveBoundaryZoneEmitsEdgeLeft() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()
        _ = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                             containerWidth: containerWidth,
                             page: 0, pageCount: 5,
                             now: clock.now(), parameters: params)
        XCTAssertFalse(scheduler.dwellArmed)

        clock.current = 101
        let events = scheduler.update(pointer: DragPoint(x: 60, y: 100),
                                       containerWidth: containerWidth,
                                       page: 0, pageCount: 5,
                                       now: clock.now(), parameters: params)
        XCTAssertEqual(events, [.edgeLeft(.left)])
        XCTAssertNil(scheduler.currentZone)
        XCTAssertFalse(scheduler.dwellArmed)
    }

    // MARK: - 3. dwell 满翻页（连续翻页）

    func testDwellElapsedRequestsPageTurnAndStaysArmed() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams(edgeDwellDurationMs: 500)
        _ = scheduler.update(pointer: DragPoint(x: 390, y: 100),
                             containerWidth: containerWidth,
                             page: 2, pageCount: 5,
                             now: clock.now(), parameters: params)

        clock.current = 100.5
        let events = scheduler.dwellElapsed(now: clock.now(),
                                            page: 2, pageCount: 5,
                                            parameters: params)
        XCTAssertEqual(events, [.pageTurnRequested(.right)])
        XCTAssertTrue(scheduler.dwellArmed)   // 保持武装，支持连续翻页
        XCTAssertEqual(scheduler.lastTurnTime, 100.5)

        // 连续翻页：越过最小间隔后再次 dwellElapsed 再翻一页。
        clock.current = 101.0
        let events2 = scheduler.dwellElapsed(now: clock.now(),
                                             page: 3, pageCount: 5,
                                             parameters: params)
        XCTAssertEqual(events2, [.pageTurnRequested(.right)])
        XCTAssertEqual(scheduler.lastTurnTime, 101.0)
    }

    func testDwellElapsedAtBoundaryAfterPageChangeDisarmsAndEmitsBoundary() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()
        _ = scheduler.update(pointer: DragPoint(x: 390, y: 100),
                             containerWidth: containerWidth,
                             page: 2, pageCount: 5,
                             now: clock.now(), parameters: params)
        XCTAssertTrue(scheduler.dwellArmed)

        // 外部翻页推进到末页后，过期 dwell timer 触发 → 边界事件 + 复位。
        clock.current = 100.6
        let events = scheduler.dwellElapsed(now: clock.now(),
                                            page: 4, pageCount: 5,
                                            parameters: params)
        XCTAssertEqual(events, [.atLastPage(.right)])
        XCTAssertFalse(scheduler.dwellArmed)
    }

    // MARK: - 4. 翻页最小间隔

    func testTurnMinIntervalSuppressesImmediateSecondTurn() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams(edgeTurnMinIntervalMs: 400)
        _ = scheduler.update(pointer: DragPoint(x: 390, y: 100),
                             containerWidth: containerWidth,
                             page: 2, pageCount: 5,
                             now: clock.now(), parameters: params)

        clock.current = 100.5
        _ = scheduler.dwellElapsed(now: clock.now(), page: 2, pageCount: 5, parameters: params)

        // 翻页后立即触发：间隔内 → 无事件（deadline 重新武装）。
        clock.current = 100.6
        let events = scheduler.dwellElapsed(now: clock.now(),
                                            page: 3, pageCount: 5,
                                            parameters: params)
        XCTAssertTrue(events.isEmpty)
        XCTAssertTrue(scheduler.dwellArmed)

        // 推进时钟越过 edgeTurnMinIntervalMs → 再翻。
        clock.current = 100.91
        let events2 = scheduler.dwellElapsed(now: clock.now(),
                                             page: 3, pageCount: 5,
                                             parameters: params)
        XCTAssertEqual(events2, [.pageTurnRequested(.right)])
    }

    // MARK: - 5. 过期 timer

    func testDwellElapsedWithoutArmingReturnsEmpty() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()

        XCTAssertTrue(scheduler.dwellElapsed(now: clock.now(),
                                             page: 2, pageCount: 5,
                                             parameters: params).isEmpty)
    }

    func testDwellElapsedAfterLeaveReturnsEmpty() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()
        _ = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                             containerWidth: containerWidth,
                             page: 2, pageCount: 5,
                             now: clock.now(), parameters: params)
        clock.current = 101
        _ = scheduler.update(pointer: DragPoint(x: 60, y: 100),
                             containerWidth: containerWidth,
                             page: 2, pageCount: 5,
                             now: clock.now(), parameters: params)

        // 离开边缘后残留 timer 触发 → 无事件。
        clock.current = 101.5
        XCTAssertTrue(scheduler.dwellElapsed(now: clock.now(),
                                             page: 2, pageCount: 5,
                                             parameters: params).isEmpty)
    }

    // MARK: - 6. 跨区

    func testCrossZoneLeftToRightEmitsLeaveThenEnter() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()
        _ = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                             containerWidth: containerWidth,
                             page: 2, pageCount: 5,
                             now: clock.now(), parameters: params)

        clock.current = 101
        let events = scheduler.update(pointer: DragPoint(x: 390, y: 100),
                                       containerWidth: containerWidth,
                                       page: 2, pageCount: 5,
                                       now: clock.now(), parameters: params)

        XCTAssertEqual(events, [.edgeLeft(.left), .edgeEntered(.right), .dwellStarted(.right)])
        XCTAssertEqual(scheduler.currentZone, .right)
        XCTAssertTrue(scheduler.dwellArmed)
    }

    func testCrossZoneRightToLeft() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()
        _ = scheduler.update(pointer: DragPoint(x: 390, y: 100),
                             containerWidth: containerWidth,
                             page: 2, pageCount: 5,
                             now: clock.now(), parameters: params)

        clock.current = 101
        let events = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                                       containerWidth: containerWidth,
                                       page: 2, pageCount: 5,
                                       now: clock.now(), parameters: params)

        XCTAssertEqual(events, [.edgeLeft(.right), .edgeEntered(.left), .dwellStarted(.left)])
        XCTAssertEqual(scheduler.currentZone, .left)
        XCTAssertTrue(scheduler.dwellArmed)
    }

    // MARK: - 7. cancel

    func testCancelWhileArmedEmitsDwellCancelledAndClearsState() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()
        _ = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                             containerWidth: containerWidth,
                             page: 2, pageCount: 5,
                             now: clock.now(), parameters: params)
        clock.current = 100.5
        _ = scheduler.dwellElapsed(now: clock.now(), page: 2, pageCount: 5, parameters: params)
        let lastTurn = scheduler.lastTurnTime

        let events = scheduler.cancel()

        XCTAssertEqual(events, [.dwellCancelled])
        XCTAssertNil(scheduler.currentZone)
        XCTAssertFalse(scheduler.dwellArmed)
        XCTAssertEqual(scheduler.lastTurnTime, lastTurn)   // lastTurnTime 保留
    }

    func testCancelWhileUnarmedReturnsEmpty() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()
        _ = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                             containerWidth: containerWidth,
                             page: 0, pageCount: 5,
                             now: clock.now(), parameters: params)
        XCTAssertFalse(scheduler.dwellArmed)   // 边界进入不武装

        let events = scheduler.cancel()

        XCTAssertTrue(events.isEmpty)
        XCTAssertNil(scheduler.currentZone)
        XCTAssertFalse(scheduler.dwellArmed)
    }

    func testReenterAfterCancelArmsFreshly() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()
        _ = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                             containerWidth: containerWidth,
                             page: 2, pageCount: 5,
                             now: clock.now(), parameters: params)
        _ = scheduler.cancel()

        clock.current = 101
        let events = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                                       containerWidth: containerWidth,
                                       page: 2, pageCount: 5,
                                       now: clock.now(), parameters: params)

        XCTAssertEqual(events, [.edgeEntered(.left), .dwellStarted(.left)])
        XCTAssertTrue(scheduler.dwellArmed)
    }

    // MARK: - 8. nextDwellDeadline

    func testNextDwellDeadlineNilWhenUnarmed() {
        let scheduler = EdgePagingScheduler()
        let params = makeParams()

        XCTAssertNil(scheduler.nextDwellDeadline(after: 100, parameters: params))
    }

    func testNextDwellDeadlineNilAtBoundary() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams()
        _ = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                             containerWidth: containerWidth,
                             page: 0, pageCount: 5,
                             now: clock.now(), parameters: params)

        XCTAssertNil(scheduler.nextDwellDeadline(after: 100, parameters: params))
    }

    func testNextDwellDeadlineArmedIsNowPlusDwell() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams(edgeDwellDurationMs: 500)
        _ = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                             containerWidth: containerWidth,
                             page: 2, pageCount: 5,
                             now: clock.now(), parameters: params)

        XCTAssertEqual(scheduler.nextDwellDeadline(after: 100, parameters: params)!, 100.5, accuracy: 1e-9)
    }

    func testNextDwellDeadlineAfterTurnRespectsMinInterval() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams(edgeDwellDurationMs: 500, edgeTurnMinIntervalMs: 400)
        _ = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                             containerWidth: containerWidth,
                             page: 2, pageCount: 5,
                             now: clock.now(), parameters: params)
        clock.current = 100.5
        _ = scheduler.dwellElapsed(now: clock.now(), page: 2, pageCount: 5, parameters: params)

        // now = 100.6：base = 101.1，lastTurn + 0.4 = 100.9 → max = 101.1。
        XCTAssertEqual(scheduler.nextDwellDeadline(after: 100.6, parameters: params)!, 101.1, accuracy: 1e-9)
        // now = 101.0：base = 101.5，lastTurn + 0.4 = 100.9 → max = 101.5。
        XCTAssertEqual(scheduler.nextDwellDeadline(after: 101.0, parameters: params)!, 101.5, accuracy: 1e-9)
    }

    func testNextDwellDeadlineMinIntervalDominatesWhenDwellShorter() {
        var scheduler = EdgePagingScheduler()
        let clock = FakeDragClock(100)
        let params = makeParams(edgeDwellDurationMs: 200, edgeTurnMinIntervalMs: 400)
        _ = scheduler.update(pointer: DragPoint(x: 10, y: 100),
                             containerWidth: containerWidth,
                             page: 2, pageCount: 5,
                             now: clock.now(), parameters: params)
        clock.current = 100.2
        _ = scheduler.dwellElapsed(now: clock.now(), page: 2, pageCount: 5, parameters: params)

        // now = 100.2：base = 100.4，lastTurn + 0.4 = 100.6 → max = 100.6（最小间隔主导）。
        XCTAssertEqual(scheduler.nextDwellDeadline(after: 100.2, parameters: params)!, 100.6, accuracy: 1e-9)
    }
}
