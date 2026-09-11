//
//  LauncherPresentationCoordinatorTests.swift
//  PagingUITests
//
//  Phase 1G §9.1 Presentation state machine（12 项）+ 负样本：
//  hidden+show；visible+show 幂等；hidden+hide 幂等；visible+toggle；presenting+repeated show；
//  presenting+hide；dismissing+show；stale completion rejected；two sources same timestamp；
//  hot corner repeated show 不反向 hide；quit dominates；terminate teardown once。
//

import XCTest
@testable import PagingPrototypeApp

final class LauncherPresentationCoordinatorTests: XCTestCase {

    private let screenA = ScreenID(index: 0)
    private let screenB = ScreenID(index: 1)

    // MARK: §9.1-1 hidden + show

    func testHiddenShowPresents() {
        var coordinator = LauncherPresentationCoordinator()
        let effect = coordinator.show(source: .statusItem, targetScreen: screenA)
        XCTAssertEqual(effect, .present(requestID: 1, targetScreen: screenA, source: .statusItem))
        XCTAssertEqual(coordinator.state, .presenting(requestID: 1, targetScreen: screenA))
        XCTAssertEqual(coordinator.activeRequestID, 1)
    }

    // MARK: §9.1-2 visible + show 幂等

    func testVisibleShowIsIdempotent() {
        var coordinator = LauncherPresentationCoordinator()
        _ = coordinator.show(source: .statusItem, targetScreen: screenA)
        _ = coordinator.completeTransition(requestID: 1)
        XCTAssertEqual(coordinator.state, .visible(screenID: screenA))

        let effect = coordinator.show(source: .dockReopen, targetScreen: screenB)
        XCTAssertEqual(effect, .none)
        XCTAssertEqual(coordinator.state, .visible(screenID: screenA), "show 在 visible 幂等，不换屏不换状态")
        XCTAssertEqual(coordinator.activeRequestID, 0)
    }

    // MARK: §9.1-3 hidden + hide 幂等

    func testHiddenHideIsIdempotent() {
        var coordinator = LauncherPresentationCoordinator()
        let effect = coordinator.hide(source: .statusItem, reason: .statusItem)
        XCTAssertEqual(effect, .none)
        XCTAssertEqual(coordinator.state, .hidden)
        XCTAssertEqual(coordinator.activeRequestID, 0)
    }

    // MARK: §9.1-4 visible + toggle

    func testVisibleToggleHides() {
        var coordinator = LauncherPresentationCoordinator()
        _ = coordinator.show(source: .statusItem, targetScreen: screenA)
        _ = coordinator.completeTransition(requestID: 1)
        XCTAssertEqual(coordinator.state, .visible(screenID: screenA))

        let effect = coordinator.toggle(source: .statusItem, targetScreen: screenA)
        XCTAssertEqual(effect, .dismiss(requestID: 2, reason: .statusItem, source: .statusItem))
        XCTAssertEqual(coordinator.state, .dismissing(requestID: 2, reason: .statusItem))
    }

    func testHiddenToggleShows() {
        var coordinator = LauncherPresentationCoordinator()
        let effect = coordinator.toggle(source: .globalShortcut, targetScreen: screenA)
        XCTAssertEqual(effect, .present(requestID: 1, targetScreen: screenA, source: .globalShortcut))
        XCTAssertEqual(coordinator.state, .presenting(requestID: 1, targetScreen: screenA))
    }

    // MARK: §9.1-5 presenting + repeated show 幂等

    func testPresentingRepeatedShowIsIdempotent() {
        var coordinator = LauncherPresentationCoordinator()
        _ = coordinator.show(source: .statusItem, targetScreen: screenA)
        let effect = coordinator.show(source: .hotCorner, targetScreen: screenB)
        XCTAssertEqual(effect, .none)
        XCTAssertEqual(coordinator.state, .presenting(requestID: 1, targetScreen: screenA))
        XCTAssertEqual(coordinator.activeRequestID, 1, "不产生第二个 request")
    }

    // MARK: §9.1-6 presenting + hide（中断）

    func testPresentingHideInterrupts() {
        var coordinator = LauncherPresentationCoordinator()
        _ = coordinator.show(source: .statusItem, targetScreen: screenA)
        let effect = coordinator.hide(source: .statusItem, reason: .escape)
        XCTAssertEqual(effect, .dismiss(requestID: 2, reason: .escape, source: .statusItem))
        XCTAssertEqual(coordinator.state, .dismissing(requestID: 2, reason: .escape))
        XCTAssertEqual(coordinator.activeRequestID, 2, "旧 presenting request 作废")
    }

    // MARK: §9.1-7 dismissing + show（中断）

    func testDismissingShowInterrupts() {
        var coordinator = LauncherPresentationCoordinator()
        _ = coordinator.show(source: .statusItem, targetScreen: screenA)
        _ = coordinator.completeTransition(requestID: 1)
        _ = coordinator.hide(source: .statusItem, reason: .backgroundClick)
        XCTAssertEqual(coordinator.state, .dismissing(requestID: 2, reason: .backgroundClick))

        let effect = coordinator.show(source: .dockReopen, targetScreen: screenA)
        XCTAssertEqual(effect, .present(requestID: 3, targetScreen: screenA, source: .dockReopen))
        XCTAssertEqual(coordinator.state, .presenting(requestID: 3, targetScreen: screenA))
    }

    // MARK: §9.1-8 stale completion rejected

    func testStaleCompletionRejected() {
        var coordinator = LauncherPresentationCoordinator()
        _ = coordinator.show(source: .statusItem, targetScreen: screenA) // request 1
        _ = coordinator.hide(source: .statusItem, reason: .escape)        // request 2（中断）
        XCTAssertEqual(coordinator.state, .dismissing(requestID: 2, reason: .escape))

        // 旧 presenting 的 completion 到达 → 拒绝
        let stale = coordinator.completeTransition(requestID: 1)
        XCTAssertEqual(stale, .none)
        XCTAssertEqual(coordinator.state, .dismissing(requestID: 2, reason: .escape), "旧 completion 不覆盖新状态")

        // 当前 dismissing 的 completion → 生效
        let current = coordinator.completeTransition(requestID: 2)
        XCTAssertEqual(current, .none)
        XCTAssertEqual(coordinator.state, .hidden)
    }

    func testCompleteTransitionWithoutTransitionIsNoop() {
        var coordinator = LauncherPresentationCoordinator()
        XCTAssertEqual(coordinator.completeTransition(requestID: 0), .none)
        XCTAssertEqual(coordinator.state, .hidden)
    }

    // MARK: §9.1-9 two sources same timestamp

    func testTwoSourcesSameTimestampSinglePresent() {
        var coordinator = LauncherPresentationCoordinator()
        let first = coordinator.show(source: .statusItem, targetScreen: screenA)
        let second = coordinator.show(source: .globalShortcut, targetScreen: screenA)
        XCTAssertEqual(first, .present(requestID: 1, targetScreen: screenA, source: .statusItem))
        XCTAssertEqual(second, .none, "同刻第二入口幂等，只产生一个 present effect")
        XCTAssertEqual(coordinator.state, .presenting(requestID: 1, targetScreen: screenA))
    }

    // MARK: §9.1-10 hot corner repeated show 不反向 hide

    func testHotCornerRepeatedShowNeverHides() {
        var coordinator = LauncherPresentationCoordinator()
        _ = coordinator.show(source: .hotCorner, targetScreen: screenA)
        _ = coordinator.completeTransition(requestID: 1)
        XCTAssertEqual(coordinator.state, .visible(screenID: screenA))

        for _ in 0..<3 {
            let effect = coordinator.show(source: .hotCorner, targetScreen: screenA)
            XCTAssertEqual(effect, .none, "Hot Corner 重复 show 永不反向 hide")
        }
        XCTAssertEqual(coordinator.state, .visible(screenID: screenA))
    }

    // MARK: §9.1-11 quit dominates

    func testQuitDominatesLaterRequests() {
        var coordinator = LauncherPresentationCoordinator()
        _ = coordinator.show(source: .statusItem, targetScreen: screenA)
        _ = coordinator.completeTransition(requestID: 1)
        XCTAssertEqual(coordinator.state, .visible(screenID: screenA))

        let quitEffect = coordinator.quit()
        XCTAssertEqual(quitEffect, .terminate)
        XCTAssertEqual(coordinator.state, .terminating)

        // quit 后一切命令拒绝
        XCTAssertEqual(coordinator.show(source: .statusItem, targetScreen: screenA), .none)
        XCTAssertEqual(coordinator.hide(source: .statusItem, reason: .escape), .none)
        XCTAssertEqual(coordinator.toggle(source: .statusItem, targetScreen: screenA), .none)
        XCTAssertEqual(coordinator.quit(), .none)
        XCTAssertEqual(coordinator.state, .terminating)
    }

    func testQuitFromEveryState() {
        for initialState in [LauncherPresentationState.hidden,
                             .presenting(requestID: 1, targetScreen: ScreenID(index: 0)),
                             .visible(screenID: ScreenID(index: 0)),
                             .dismissing(requestID: 1, reason: .escape),
                             .suspended(reason: .sleep)] {
            var coordinator = LauncherPresentationCoordinator(initialState: initialState)
            XCTAssertEqual(coordinator.quit(), .terminate, "quit dominates from \(initialState)")
            XCTAssertEqual(coordinator.state, .terminating)
        }
    }

    // MARK: §9.1-12 terminate teardown once

    func testTerminateTeardownOnce() {
        var coordinator = LauncherPresentationCoordinator()
        XCTAssertEqual(coordinator.terminate(), .teardown)
        XCTAssertEqual(coordinator.teardownCount, 1)
        XCTAssertEqual(coordinator.terminate(), .none, "第二次 terminate 不再 teardown")
        XCTAssertEqual(coordinator.teardownCount, 1)
    }

    func testQuitThenTerminateTeardownOnce() {
        var coordinator = LauncherPresentationCoordinator()
        _ = coordinator.show(source: .statusItem, targetScreen: screenA)
        XCTAssertEqual(coordinator.quit(), .terminate)
        XCTAssertEqual(coordinator.terminate(), .teardown, "quit 后 terminate 仍执行最终 teardown 一次")
        XCTAssertEqual(coordinator.terminate(), .none)
        XCTAssertEqual(coordinator.teardownCount, 1)
    }

    // MARK: 负样本（不该触发的场景）

    func testDismissingHideIsIdempotent() {
        var coordinator = LauncherPresentationCoordinator()
        _ = coordinator.show(source: .statusItem, targetScreen: screenA)
        _ = coordinator.completeTransition(requestID: 1)
        _ = coordinator.hide(source: .statusItem, reason: .backgroundClick)
        XCTAssertEqual(coordinator.state, .dismissing(requestID: 2, reason: .backgroundClick))

        let effect = coordinator.hide(source: .statusItem, reason: .escape)
        XCTAssertEqual(effect, .none, "hide 在 dismissing 幂等，不换 reason 不换 request")
        XCTAssertEqual(coordinator.state, .dismissing(requestID: 2, reason: .backgroundClick))
    }

    func testSuspendedHideIsIdempotentAndToggleShows() {
        var coordinator = LauncherPresentationCoordinator()
        _ = coordinator.suspend(reason: .sleep)
        XCTAssertEqual(coordinator.state, .suspended(reason: .sleep))

        XCTAssertEqual(coordinator.hide(source: .statusItem, reason: .escape), .none, "suspended 已隐藏，hide 幂等")
        let toggle = coordinator.toggle(source: .statusItem, targetScreen: screenA)
        XCTAssertEqual(toggle, .present(requestID: 1, targetScreen: screenA, source: .statusItem))
    }

    func testSuspendCancelsInFlightTransition() {
        var coordinator = LauncherPresentationCoordinator()
        _ = coordinator.show(source: .statusItem, targetScreen: screenA) // request 1
        let effect = coordinator.suspend(reason: .screenConfigurationChanged)
        XCTAssertEqual(effect, .suspend(reason: .screenConfigurationChanged))
        XCTAssertEqual(coordinator.state, .suspended(reason: .screenConfigurationChanged))
        XCTAssertEqual(coordinator.activeRequestID, 0, "in-flight transition 作废")

        // 旧 completion 到达 → 拒绝
        XCTAssertEqual(coordinator.completeTransition(requestID: 1), .none)
        XCTAssertEqual(coordinator.state, .suspended(reason: .screenConfigurationChanged))
    }

    func testResumeReturnsToHidden() {
        var coordinator = LauncherPresentationCoordinator()
        _ = coordinator.suspend(reason: .sleep)
        XCTAssertEqual(coordinator.resume(), .none)
        XCTAssertEqual(coordinator.state, .hidden, "唤醒后确定性回到 hidden，不自动弹窗")
        XCTAssertEqual(coordinator.resume(), .none, "非 suspended 时 resume 无操作")
    }

    func testTerminatingRejectsEverything() {
        var coordinator = LauncherPresentationCoordinator(initialState: .terminating)
        XCTAssertEqual(coordinator.show(source: .statusItem, targetScreen: screenA), .none)
        XCTAssertEqual(coordinator.hide(source: .statusItem, reason: .escape), .none)
        XCTAssertEqual(coordinator.toggle(source: .statusItem, targetScreen: screenA), .none)
        XCTAssertEqual(coordinator.suspend(reason: .sleep), .none)
        XCTAssertEqual(coordinator.state, .terminating)
    }

    // MARK: 命令分发与查询

    func testHandleCommandDispatch() {
        var coordinator = LauncherPresentationCoordinator()
        XCTAssertEqual(coordinator.handle(.show, source: .dockReopen, targetScreen: screenA),
                       .present(requestID: 1, targetScreen: screenA, source: .dockReopen))
        XCTAssertEqual(coordinator.handle(.hide, source: .statusItem, targetScreen: screenA),
                       .dismiss(requestID: 2, reason: .statusItem, source: .statusItem))
        XCTAssertEqual(coordinator.handle(.toggle, source: .globalShortcut, targetScreen: screenA),
                       .present(requestID: 3, targetScreen: screenA, source: .globalShortcut))
        XCTAssertEqual(coordinator.handle(.quit, source: .statusItem, targetScreen: screenA), .terminate)
    }

    func testCommittedVisibility() {
        var coordinator = LauncherPresentationCoordinator()
        XCTAssertFalse(coordinator.committedVisibility)
        _ = coordinator.show(source: .statusItem, targetScreen: screenA)
        XCTAssertTrue(coordinator.committedVisibility, "presenting 视为将可见")
        _ = coordinator.completeTransition(requestID: 1)
        XCTAssertTrue(coordinator.committedVisibility)
        _ = coordinator.hide(source: .statusItem, reason: .escape)
        XCTAssertFalse(coordinator.committedVisibility, "dismissing 视为将隐藏")
        _ = coordinator.completeTransition(requestID: 2)
        XCTAssertFalse(coordinator.committedVisibility)
    }

    func testCompleteTransitionCommitsVisibleAndHidden() {
        var coordinator = LauncherPresentationCoordinator()
        _ = coordinator.show(source: .statusItem, targetScreen: screenB)
        _ = coordinator.completeTransition(requestID: 1)
        XCTAssertEqual(coordinator.state, .visible(screenID: screenB), "presenting 完成 → visible(目标屏)")

        _ = coordinator.hide(source: .statusItem, reason: .appLaunched)
        _ = coordinator.completeTransition(requestID: 2)
        XCTAssertEqual(coordinator.state, .hidden, "dismissing 完成 → hidden")
    }
}
