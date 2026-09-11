//
//  ScrollInputMapperTests.swift
//  PagingUITests
//
//  NSEvent → Core 输入决策纯函数映射测试（§3.C：横向主导、自然滚动方向、
//  momentum、异常 phase 防御、legacy fallback、finishGesture 时机）。
//

import AppKit
import XCTest
@testable import PagingUI

final class ScrollInputMapperTests: XCTestCase {

    // MARK: - 自然滚动方向（核心约定）

    func testNaturalTrackpadFingersLeftIsNextPage() {
        // 自然滚动（inverted=true）：手指左移 → scrollingDeltaX < 0 → 下一页（core delta > 0）。
        XCTAssertEqual(ScrollInputMapper.normalizedDelta(scrollingDeltaX: -50, isDirectionInverted: true), 50, accuracy: 1e-9)
    }

    func testNaturalTrackpadFingersRightIsPreviousPage() {
        XCTAssertEqual(ScrollInputMapper.normalizedDelta(scrollingDeltaX: 50, isDirectionInverted: true), -50, accuracy: 1e-9)
    }

    func testLegacyAndWheelRightIsNextPage() {
        // 传统滚动/滚轮（inverted=false）：内容右移（scrollingDeltaX > 0）→ 下一页。
        XCTAssertEqual(ScrollInputMapper.normalizedDelta(scrollingDeltaX: 50, isDirectionInverted: false), 50, accuracy: 1e-9)
        XCTAssertEqual(ScrollInputMapper.normalizedDelta(scrollingDeltaX: -50, isDirectionInverted: false), -50, accuracy: 1e-9)
    }

    // MARK: - phase 归一化

    func testPhaseMapping() {
        XCTAssertEqual(ScrollInputMapper.map(phase: .began, momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0, isDirectionInverted: true, needsFinish: false), [.gestureBegan])
        XCTAssertEqual(
            ScrollInputMapper.map(phase: .changed, momentumPhase: [], scrollingDeltaX: 100, scrollingDeltaY: 0, isDirectionInverted: true, needsFinish: false),
            [.gestureChanged(-100)]
        )
        XCTAssertEqual(ScrollInputMapper.map(phase: .ended, momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0, isDirectionInverted: true, needsFinish: false), [.gestureEnded])
        XCTAssertEqual(ScrollInputMapper.map(phase: .cancelled, momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0, isDirectionInverted: true, needsFinish: false), [.gestureCancelled])
    }

    // MARK: - 横向主导

    func testHorizontalDominance() {
        // |Δx| < |Δy|：垂直滚动忽略。
        XCTAssertEqual(
            ScrollInputMapper.map(phase: .changed, momentumPhase: [], scrollingDeltaX: 30, scrollingDeltaY: 100, isDirectionInverted: true, needsFinish: false),
            [.ignore]
        )
        // |Δx| >= |Δy|：横向参与分页。
        XCTAssertEqual(
            ScrollInputMapper.map(phase: .changed, momentumPhase: [], scrollingDeltaX: 100, scrollingDeltaY: 30, isDirectionInverted: true, needsFinish: false),
            [.gestureChanged(-100)]
        )
    }

    // MARK: - momentum

    func testMomentumMapping() {
        XCTAssertEqual(ScrollInputMapper.map(phase: [], momentumPhase: .began, scrollingDeltaX: 0, scrollingDeltaY: 0, isDirectionInverted: true, needsFinish: false), [.momentumBegan])
        XCTAssertEqual(
            ScrollInputMapper.map(phase: [], momentumPhase: .changed, scrollingDeltaX: -60, scrollingDeltaY: 0, isDirectionInverted: true, needsFinish: false),
            [.momentumChanged(60)]
        )
        XCTAssertEqual(ScrollInputMapper.map(phase: [], momentumPhase: .ended, scrollingDeltaX: 0, scrollingDeltaY: 0, isDirectionInverted: true, needsFinish: false), [.momentumEnded])
    }

    // MARK: - finishGesture 时机（Worker B 偏差 #1 的映射侧）

    func testNewBeganAfterEndedFinishesPendingFirst() {
        XCTAssertEqual(
            ScrollInputMapper.map(phase: .began, momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0, isDirectionInverted: true, needsFinish: true),
            [.finishPendingGesture, .gestureBegan]
        )
    }

    func testNoPhaseEventAfterEndedFinishesPending() {
        XCTAssertEqual(
            ScrollInputMapper.map(phase: [], momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0, isDirectionInverted: true, needsFinish: true),
            [.finishPendingGesture]
        )
    }

    func testDuplicateEndedIgnored() {
        XCTAssertEqual(
            ScrollInputMapper.map(phase: .ended, momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0, isDirectionInverted: true, needsFinish: true),
            []
        )
    }

    // MARK: - 异常 phase 防御（D5：UI 照实转发 + 明显错误序列修正）

    func testMayBeginAndStationaryIgnored() {
        XCTAssertEqual(ScrollInputMapper.map(phase: .mayBegin, momentumPhase: [], scrollingDeltaX: 10, scrollingDeltaY: 0, isDirectionInverted: true, needsFinish: false), [.ignore])
        XCTAssertEqual(ScrollInputMapper.map(phase: .stationary, momentumPhase: [], scrollingDeltaX: 10, scrollingDeltaY: 0, isDirectionInverted: true, needsFinish: false), [.ignore])
    }

    func testMomentumChangedWithoutBeganStillForwarded() {
        // 防御：未见 began 的 momentum changed 照实转发（Core 侧会拒绝/接管）。
        XCTAssertEqual(
            ScrollInputMapper.map(phase: [], momentumPhase: .changed, scrollingDeltaX: -40, scrollingDeltaY: 0, isDirectionInverted: true, needsFinish: false),
            [.momentumChanged(40)]
        )
    }

    // MARK: - legacy 鼠标滚轮 fallback

    func testLegacyScrollFallback() {
        // 传统滚动（inverted=false）：滚轮向左（scrollingDeltaX < 0）→ 上一页（core delta < 0）。
        XCTAssertEqual(
            ScrollInputMapper.map(phase: [], momentumPhase: [], scrollingDeltaX: -10, scrollingDeltaY: 0, isDirectionInverted: false, needsFinish: false),
            [.legacyScroll(-10)]
        )
        XCTAssertEqual(
            ScrollInputMapper.map(phase: [], momentumPhase: [], scrollingDeltaX: 0, scrollingDeltaY: 0, isDirectionInverted: false, needsFinish: false),
            [.ignore]
        )
    }
}
