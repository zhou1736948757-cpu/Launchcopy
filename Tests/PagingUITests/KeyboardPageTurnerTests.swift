// PagingUITests — KeyboardPageTurnerTests（Phase 1C §7.2 键盘跨页 seam）
// 实现：T-1C-B（Worker B）。
//
// 验证：idle 时合成手势翻页；非 idle（tracking/settling）延迟/忽略且不破坏手势/settle；
// 边界不翻页；teardown 零副作用；settle 期间按键不产生双重 commit。

import AppKit
import XCTest
@testable import PagingUI

final class KeyboardPageTurnerTests: XCTestCase {

    func testTurnNextWhenIdle() {
        let surface = makeSurface(pageCount: 5)
        let turner = KeyboardPageTurner(surface: surface)
        let result = turner.turn(direction: .next, timestamp: 0)
        XCTAssertEqual(result, .turned(1))
        XCTAssertEqual(surface.core.state, .settling, "合成手势应触发 settle")
        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 1)
        XCTAssertEqual(surface.core.state, .idle)
    }

    func testTurnPreviousWhenIdle() {
        let surface = makeSurface(pageCount: 5)
        _ = KeyboardPageTurner(surface: surface).turn(direction: .next, timestamp: 0)
        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 1)

        let turner = KeyboardPageTurner(surface: surface)
        let result = turner.turn(direction: .previous, timestamp: 10)
        XCTAssertEqual(result, .turned(0))
        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 0)
    }

    func testDeferredWhenTracking() {
        let surface = makeSurface(pageCount: 5)
        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 200, at: 0.2)
        XCTAssertEqual(surface.core.state, .tracking)

        let turner = KeyboardPageTurner(surface: surface)
        let result = turner.turn(direction: .next, timestamp: 0.3)
        XCTAssertEqual(result, .deferred, "tracking 中键盘跨页应延迟/忽略")
        XCTAssertEqual(surface.core.state, .tracking, "不破坏进行中的手势")

        // 手势仍可正常完成。
        gestureEnded(surface, at: 0.4)
        finishPendingGesture(surface, at: 0.4)
        settleFrames(surface)
        XCTAssertEqual(surface.core.state, .idle)
    }

    func testDeferredDuringSettleNoDoubleCommit() {
        let surface = makeSurface(pageCount: 5)
        let turner = KeyboardPageTurner(surface: surface)
        _ = turner.turn(direction: .next, timestamp: 0)
        XCTAssertEqual(surface.core.state, .settling)

        // settle 中再次按键 → 延迟，不破坏 settle，不产生双重 commit。
        XCTAssertEqual(turner.turn(direction: .next, timestamp: 0.1), .deferred)
        XCTAssertEqual(turner.turn(direction: .next, timestamp: 0.2), .deferred)
        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 1)
        XCTAssertEqual(surface.core.commitCount, 1, "settle 期间按键不产生双重 commit")
    }

    func testAtBoundary() {
        let surface = makeSurface(pageCount: 1)
        let turner = KeyboardPageTurner(surface: surface)
        XCTAssertEqual(turner.turn(direction: .next, timestamp: 0), .atBoundary)
        XCTAssertEqual(turner.turn(direction: .previous, timestamp: 0), .atBoundary)
        XCTAssertEqual(surface.core.state, .idle, "边界不触发任何手势")
    }

    func testTornDown() {
        let surface = makeSurface(pageCount: 5)
        surface.teardown()
        let turner = KeyboardPageTurner(surface: surface)
        XCTAssertEqual(turner.turn(direction: .next, timestamp: 0), .tornDown)
        XCTAssertEqual(surface.core.state, .idle)
    }
}
