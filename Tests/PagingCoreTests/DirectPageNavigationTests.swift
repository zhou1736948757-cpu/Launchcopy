import XCTest
@testable import PagingCore

final class DirectPageNavigationTests: XCTestCase {
    private func core(_ count: Int = 8, page: Int = 0, reduceMotion: Bool = false) -> PagingCore {
        PagingCore(pageCount: count, pageWidth: 1000, initialPage: page, reduceMotion: reduceMotion)
    }
    private func finish(_ core: PagingCore) {
        for _ in 0..<600 { if core.state == .idle { return }; _ = core.tick(deltaTime: 1.0 / 60) }
        XCTFail("Existing spring did not settle within bounded frames")
    }
    func testEmptyOneSamePageAndNonfiniteRequestsAreInert() {
        for value in [core(0), core(1), core()] {
            XCTAssertFalse(value.requestPage(0)); XCTAssertFalse(value.requestPage(4, timestamp: .nan))
            XCTAssertEqual(value.transitionToken, 0); XCTAssertEqual(value.commitCount, 0)
        }
    }
    func testNonadjacentAndClampUseExistingSpringSingleCommit() {
        let value = core()
        XCTAssertTrue(value.requestPage(Int.max))
        XCTAssertEqual(value.activeTransition?.targetPage, 7)
        XCTAssertEqual(value.activeTransition?.reason, .directNavigation)
        XCTAssertTrue(value.isDirectNavigationActive); XCTAssertEqual(value.committedPage, 0)
        finish(value); XCTAssertEqual(value.committedPage, 7); XCTAssertEqual(value.commitCount, 1)
        XCTAssertFalse(value.isDirectNavigationActive)
        XCTAssertTrue(value.requestPage(Int.min)); finish(value)
        XCTAssertEqual(value.committedPage, 0); XCTAssertEqual(value.commitCount, 2)
    }
    func testLatestWinsStartsAtContinuousOffsetAndRejectsAllOldCompletions() throws {
        let value = core()
        XCTAssertTrue(value.requestPage(7)); let first = try XCTUnwrap(value.activeTransition)
        _ = value.tick(deltaTime: 0.05); let offset = value.visualOffset
        XCTAssertTrue(value.requestPage(2)); let second = try XCTUnwrap(value.activeTransition)
        XCTAssertEqual(second.fromOffset, offset); XCTAssertEqual(value.visualOffset, offset)
        XCTAssertFalse(value.requestPage(2)); XCTAssertEqual(value.transitionToken, second.token)
        XCTAssertTrue(value.requestPage(5)); let last = try XCTUnwrap(value.activeTransition)
        XCTAssertFalse(value.completeSettle(first)); XCTAssertFalse(value.completeSettle(second))
        finish(value); XCTAssertEqual(value.committedPage, 5); XCTAssertEqual(value.commitCount, 1)
        XCTAssertFalse(value.completeSettle(last)); XCTAssertEqual(value.commitCount, 1)
    }
    func testReturnToCommittedDuringDifferentSettleIsNotIdleNoOp() {
        let value = core(); XCTAssertTrue(value.requestPage(6)); _ = value.tick(deltaTime: 0.05)
        XCTAssertTrue(value.requestPage(0)); finish(value)
        XCTAssertEqual(value.committedPage, 0); XCTAssertEqual(value.commitCount, 1)
    }
    func testPhysicalTrackingReleaseAndMomentumRejectWithoutMutation() {
        let value = core()
        _ = value.handleGesturePhase(.began)
        _ = value.handleGesturePhase(.changed, delta: 250, timestamp: 0.5)
        for phase in [GesturePhase.ended, .momentumBegan, .momentumChanged] {
            _ = value.handleGesturePhase(phase, delta: 1, timestamp: 0.6)
            let offset = value.visualOffset, token = value.transitionToken, session = value.currentSession
            XCTAssertFalse(value.requestPage(5)); XCTAssertEqual(value.visualOffset, offset)
            XCTAssertEqual(value.transitionToken, token); XCTAssertTrue(value.currentSession === session)
        }
    }
    func testReduceMotionImmediateAndRestartKeepDirectOwnership() throws {
        let immediate = core(reduceMotion: true)
        XCTAssertTrue(immediate.requestPage(5)); XCTAssertEqual(immediate.committedPage, 5)
        XCTAssertEqual(immediate.commitCount, 1); XCTAssertFalse(immediate.isDirectNavigationActive)
        let value = core(); _ = value.requestPage(5); let old = try XCTUnwrap(value.activeTransition)
        value.setReduceMotion(true)
        XCTAssertEqual(value.committedPage, 5); XCTAssertEqual(value.commitCount, 1)
        XCTAssertFalse(value.completeSettle(old)); XCTAssertFalse(value.isDirectNavigationActive)
        // Nonzero RM duration verifies provenance even when a restart stays animated.
        let slower = core(); slower.parameters.settleDurationReduceMotion = 0.2
        _ = slower.requestPage(5); slower.setReduceMotion(true)
        XCTAssertEqual(slower.activeTransition?.reason, .reduceMotionChange)
        XCTAssertTrue(slower.isDirectNavigationActive); slower.cancel()
        XCTAssertFalse(slower.isDirectNavigationActive)
    }
    func testResizeCountAndTeardownInvalidateDirectButDoNotCommit() throws {
        for action in [0, 1, 2] {
            let value = core(); _ = value.requestPage(6); let old = try XCTUnwrap(value.activeTransition)
            if action == 0 { value.setPageWidth(1200) }
            if action == 1 { value.setPageCount(7) }
            if action == 2 { value.teardown() }
            XCTAssertFalse(value.isDirectNavigationActive); XCTAssertFalse(value.completeSettle(old))
            XCTAssertEqual(value.committedPage, 0); XCTAssertEqual(value.commitCount, 0)
        }
    }
    func testPhysicalBeganCanTakeOverDirectAtDisplayedOffset() {
        let value = core(); _ = value.requestPage(7); _ = value.tick(deltaTime: 0.05)
        let offset = value.visualOffset
        XCTAssertTrue(value.handleGesturePhase(.began, timestamp: 1))
        XCTAssertFalse(value.isDirectNavigationActive)
        XCTAssertEqual(value.currentSession?.startOffset, offset); XCTAssertEqual(value.state, .tracking)
    }
    func testBeginObserversCancelTeardownOrReplaceWithoutOldRMOffsetWrite() {
        for mode in 0..<3 {
            var value: PagingCore!
            var once = false
            var events = PagingCoreEvents()
            events.onStateChange = { state in
                guard state == .settling, !once else { return }; once = true
                if mode == 0 { value.cancel() }
                if mode == 1 { value.teardown() }
                if mode == 2 { _ = value.requestPage(2) }
            }
            value = PagingCore(pageCount: 8, pageWidth: 1000, reduceMotion: true, events: events)
            _ = value.requestPage(6)
            XCTAssertEqual(value.visualOffset, mode == 2 ? 2 : 0)
            XCTAssertEqual(value.committedPage, mode == 2 ? 2 : 0)
            XCTAssertEqual(value.commitCount, mode == 2 ? 1 : 0)
            XCTAssertEqual(value.state, .idle)
        }
    }
    func testTransitionBeginObserverCanCancelWithoutOldImmediateMove() {
        var value: PagingCore!
        var events = PagingCoreEvents(); events.onTransitionBegin = { _ in value.cancel() }
        value = PagingCore(pageCount: 8, pageWidth: 1000, reduceMotion: true, events: events)
        _ = value.requestPage(6)
        XCTAssertEqual(value.visualOffset, 0); XCTAssertEqual(value.commitCount, 0)
    }
    func testReentrantCommitPreservesLatestAcceptedContextAndCompletes() {
        for reduceMotion in [false, true] {
            var value: PagingCore!
            var once = false
            var events = PagingCoreEvents()
            events.onCommit = { _ in
                guard !once else { return }; once = true
                XCTAssertTrue(value.requestPage(5))
            }
            value = PagingCore(pageCount: 8, pageWidth: 1000, reduceMotion: reduceMotion, events: events)
            _ = value.requestPage(2); finish(value)
            XCTAssertEqual(value.committedPage, 5); XCTAssertEqual(value.visualOffset, 5)
            XCTAssertEqual(value.commitCount, 2); XCTAssertNil(value.activeTransition)
        }
    }

    func testStaleObserverDomainChangesCannotUseCachedIllegalTarget() {
        for count in [0, 2] {
            var value: PagingCore!
            var once = false
            var events = PagingCoreEvents()
            events.onStaleRejection = { _ in
                guard !once else { return }; once = true; value.setPageCount(count)
            }
            value = PagingCore(pageCount: 8, pageWidth: 1000, events: events)
            _ = value.requestPage(7)
            XCTAssertFalse(value.requestPage(6)); finish(value)
            XCTAssertEqual(value.committedPage, 0); XCTAssertEqual(value.visualOffset, 0)
            XCTAssertEqual(value.commitCount, 0); XCTAssertNil(value.activeTransition)
        }
    }
    func testRMStaleObserversCancelTearDownOrReplaceWithoutResurrection() {
        for mode in 0..<3 {
            var value: PagingCore!
            var once = false
            var events = PagingCoreEvents()
            events.onStaleRejection = { _ in
                guard !once else { return }; once = true
                if mode == 0 { value.cancel() }
                if mode == 1 { value.teardown() }
                if mode == 2 { _ = value.requestPage(2) }
            }
            value = PagingCore(pageCount: 8, pageWidth: 1000, events: events)
            _ = value.requestPage(7); value.setReduceMotion(true)
            XCTAssertEqual(value.committedPage, mode == 2 ? 2 : 0)
            XCTAssertEqual(value.visualOffset, mode == 2 ? 2 : 0)
            XCTAssertEqual(value.state, .idle); XCTAssertNil(value.activeTransition)
        }
    }

    func testCancelStaleObserverCannotStrandItsNewerAcceptedTarget() {
        var value: PagingCore!
        var once = false
        var events = PagingCoreEvents()
        events.onStaleRejection = { _ in
            guard !once else { return }; once = true; XCTAssertTrue(value.requestPage(2))
        }
        value = PagingCore(pageCount: 8, pageWidth: 1000, events: events)
        _ = value.requestPage(7); value.cancel(); finish(value)
        XCTAssertEqual(value.committedPage, 2); XCTAssertNil(value.activeTransition)
    }

    func testCancellationResetOffsetObserverCannotStrandNewRequestOrEmitAfterTeardown() {
        for tearDown in [false, true] {
            var value: PagingCore!
            var once = false
            var enabled = false
            var callbacksAfterTeardown = 0
            var events = PagingCoreEvents()
            events.onVisualOffsetChange = { offset in
                guard enabled, offset == 0, !once else { return }; once = true
                if tearDown { value.teardown() } else { XCTAssertTrue(value.requestPage(2)) }
            }
            events.onStateChange = { _ in if value.isTearingDown { callbacksAfterTeardown += 1 } }
            value = PagingCore(pageCount: 8, pageWidth: 1000, events: events)
            _ = value.requestPage(7); _ = value.tick(deltaTime: 0.05); enabled = true
            value.cancel(); finish(value)
            XCTAssertEqual(value.committedPage, tearDown ? 0 : 2)
            XCTAssertNil(value.activeTransition); XCTAssertEqual(callbacksAfterTeardown, 0)
        }
    }

    func testEnvironmentCancelObserverTeardownPreventsLaterDomainMutation() {
        for resize in [false, true] {
            var value: PagingCore!
            var events = PagingCoreEvents(); events.onStaleRejection = { _ in value.teardown() }
            value = PagingCore(pageCount: 8, pageWidth: 1000, events: events)
            _ = value.requestPage(7)
            if resize { value.setPageWidth(1200) } else { value.setPageCount(2) }
            XCTAssertTrue(value.isTearingDown); XCTAssertEqual(value.pageCount, 8)
            XCTAssertEqual(value.pageWidth, 1000); XCTAssertEqual(value.state, .idle)
        }
    }

}
