import XCTest
import PagingCore

final class TakeoverReentrancyTests: XCTestCase {
    private enum Seed: CaseIterable { case directNavigation, gestureRelease }
    private enum Boundary: CaseIterable { case stale, interruption, interrupted }

    private enum Event: Equatable {
        case state(PagingState)
        case offset(Double)
        case begin(UInt64)
        case commit(UInt64)
        case stale(UInt64)
        case interruption(offset: Double, target: Int?, token: UInt64?)

        var boundary: Boundary? {
            switch self {
            case .stale: return .stale
            case .interruption: return .interruption
            case .state(.interrupted): return .interrupted
            default: return nil
            }
        }
    }

    private final class Fixture {
        var core: PagingCore!
        var trace: [Event] = []
        var callbacksAfterTeardown: [Event] = []
        var armedBoundary: Boundary?
        var action: (() -> Void)?
        var actionCount = 0

        init() {
            var events = PagingCoreEvents()
            events.onStateChange = { [weak self] in self?.record(.state($0)) }
            events.onVisualOffsetChange = { [weak self] in self?.record(.offset($0)) }
            events.onTransitionBegin = { [weak self] in self?.record(.begin($0.token)) }
            events.onCommit = { [weak self] in self?.record(.commit($0.token)) }
            events.onStaleRejection = { [weak self] in self?.record(.stale($0)) }
            events.onInterruption = { [weak self] in
                self?.record(.interruption(offset: $0.takeoverOffset,
                                           target: $0.abandonedTargetPage, token: $0.abandonedToken))
            }
            core = PagingCore(pageCount: 8, pageWidth: 1000, initialPage: 1, events: events)
        }

        private func record(_ event: Event) {
            trace.append(event)
            if core.isTearingDown { callbacksAfterTeardown.append(event) }
            guard let boundary = armedBoundary, event.boundary == boundary else { return }
            // Disarm before invoking user code: nested callbacks cannot recursively fire the action.
            armedBoundary = nil
            let callback = action
            action = nil
            actionCount += 1
            callback?()
        }

        func arm(_ boundary: Boundary, action: @escaping () -> Void) {
            trace.removeAll()
            armedBoundary = boundary
            self.action = action
        }

        func seed(_ seed: Seed) throws -> TransitionContext {
            switch seed {
            case .directNavigation:
                XCTAssertTrue(core.requestPage(6, timestamp: 0))
            case .gestureRelease:
                XCTAssertTrue(core.handleGesturePhase(.began, timestamp: 0))
                XCTAssertTrue(core.handleGesturePhase(.changed, delta: 250, timestamp: 0.5))
                XCTAssertTrue(core.handleGesturePhase(.ended, timestamp: 0.6))
                XCTAssertTrue(core.finishGesture(timestamp: 0.6))
            }
            let context = try XCTUnwrap(core.activeTransition)
            _ = core.tick(deltaTime: 0.02)
            XCTAssertEqual(core.state, .settling)
            XCTAssertTrue(core.activeTransition === context)
            XCTAssertNotEqual(core.visualOffset, Double(core.committedPage))
            trace.removeAll()
            return context
        }
    }

    private func finish(_ core: PagingCore, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<600 {
            if core.state == .idle { return }
            _ = core.tick(deltaTime: 1.0 / 60)
        }
        XCTFail("Transition did not finish within 600 synchronous frames", file: file, line: line)
    }

    func testTeardownAtEveryTakeoverBoundarySuppressesEveryLaterCallback() throws {
        for seed in Seed.allCases {
            for boundary in Boundary.allCases {
                let fixture = Fixture()
                let core = fixture.core!
                let old = try fixture.seed(seed)
                let token = core.transitionToken
                var traceAtTeardown: [Event] = []
                fixture.arm(boundary) {
                    core.teardown()
                    traceAtTeardown = fixture.trace
                }
                XCTAssertFalse(core.handleGesturePhase(.began, timestamp: 1))
                XCTAssertEqual(fixture.actionCount, 1)
                XCTAssertTrue(core.isTearingDown)
                XCTAssertEqual(core.state, .idle)
                XCTAssertNil(core.currentSession)
                XCTAssertNil(core.activeTransition)
                XCTAssertEqual(core.visualOffset, 1)
                XCTAssertEqual(core.committedPage, 1)
                XCTAssertEqual(core.transitionToken, token)
                XCTAssertEqual(core.commitCount, 0)
                XCTAssertEqual(old.commitState, .stale)
                XCTAssertFalse(core.completeSettle(old))
                XCTAssertFalse(core.handleGesturePhase(.began, timestamp: 2))
                XCTAssertFalse(core.handleGesturePhase(.changed, delta: 200, timestamp: 2.1))
                XCTAssertFalse(core.finishGesture(timestamp: 2.2))
                XCTAssertFalse(core.requestPage(4, timestamp: 2.3))
                XCTAssertFalse(core.tick(deltaTime: 1.0 / 60))
                core.cancel()
                core.teardown()
                XCTAssertEqual(fixture.trace, traceAtTeardown)
                XCTAssertEqual(fixture.callbacksAfterTeardown, [])
                XCTAssertNil(core.currentSession)
                XCTAssertEqual(core.state, .idle)
            }
        }
    }

    func testCancelAtEveryTakeoverBoundaryRemainsIdleWithoutOldContinuation() throws {
        for seed in Seed.allCases {
            for boundary in Boundary.allCases {
                let fixture = Fixture()
                let core = fixture.core!
                let old = try fixture.seed(seed)
                let token = core.transitionToken
                var cancelledTrace: [Event] = []
                fixture.arm(boundary) {
                    core.cancel()
                    cancelledTrace = fixture.trace
                }
                XCTAssertFalse(core.handleGesturePhase(.began, timestamp: 1))
                XCTAssertEqual(fixture.actionCount, 1)
                XCTAssertEqual(fixture.trace, cancelledTrace)
                XCTAssertEqual(Array(fixture.trace.suffix(2)), [.state(.cancelled), .state(.idle)])
                XCTAssertEqual(core.state, .idle)
                XCTAssertNil(core.currentSession)
                XCTAssertNil(core.activeTransition)
                XCTAssertEqual(core.visualOffset, 1)
                XCTAssertEqual(core.committedPage, 1)
                XCTAssertEqual(core.transitionToken, token)
                XCTAssertEqual(core.commitCount, 0)
                XCTAssertEqual(core.interruptionCount, 1)
                XCTAssertFalse(core.completeSettle(old))
                XCTAssertFalse(core.tick(deltaTime: 1.0 / 60))
                XCTAssertEqual(core.state, .idle)
                XCTAssertNil(core.currentSession)
            }
        }
    }

    func testAcceptedRequestAtSettlingCallbacksKeepsExactContextTokenAndBoundedCommit() throws {
        for seed in Seed.allCases {
            for boundary in [Boundary.stale, .interruption] {
                let fixture = Fixture()
                let core = fixture.core!
                let old = try fixture.seed(seed)
                let offset = core.visualOffset
                var newer: TransitionContext?
                var acceptedTrace: [Event] = []
                fixture.arm(boundary) {
                    XCTAssertEqual(core.state, .settling)
                    XCTAssertNil(core.activeTransition)
                    XCTAssertTrue(core.canRequestPage(4))
                    XCTAssertTrue(core.requestPage(4, timestamp: 1.1))
                    newer = core.activeTransition
                    acceptedTrace = fixture.trace
                }
                XCTAssertFalse(core.handleGesturePhase(.began, timestamp: 1))
                let context = try XCTUnwrap(newer)
                XCTAssertEqual(fixture.actionCount, 1)
                XCTAssertEqual(fixture.trace, acceptedTrace)
                XCTAssertEqual(core.state, .settling)
                XCTAssertTrue(core.activeTransition === context)
                XCTAssertNil(core.currentSession)
                XCTAssertEqual(context.token, old.token + 1)
                XCTAssertEqual(core.transitionToken, context.token)
                XCTAssertEqual(context.targetPage, 4)
                XCTAssertEqual(context.fromOffset, offset)
                XCTAssertEqual(core.visualOffset, offset)
                XCTAssertEqual(context.commitState, .pending)
                XCTAssertFalse(core.completeSettle(old))
                XCTAssertTrue(core.activeTransition === context)
                XCTAssertEqual(core.transitionToken, context.token)
                XCTAssertEqual(core.commitCount, 0)
                finish(core)
                XCTAssertEqual(context.commitState, .committed)
                XCTAssertTrue(context.hasCommitted)
                XCTAssertEqual(core.committedPage, 4)
                XCTAssertEqual(core.visualOffset, 4)
                XCTAssertEqual(core.commitCount, 1)
                XCTAssertEqual(fixture.trace.filter { $0 == .commit(context.token) }.count, 1)
                XCTAssertNil(core.activeTransition)
                XCTAssertFalse(core.completeSettle(old))
                XCTAssertEqual(core.commitCount, 1)
                XCTAssertEqual(core.committedPage, 4)
            }
        }
    }

    func testRequestDuringInterruptedIsRejectedAndOrdinaryTakeoverContinues() throws {
        for seed in Seed.allCases {
            let fixture = Fixture()
            let core = fixture.core!
            let old = try fixture.seed(seed)
            let session = core.currentSession
            let offset = core.visualOffset
            fixture.arm(.interrupted) {
                XCTAssertEqual(core.state, .interrupted)
                XCTAssertFalse(core.canRequestPage(4))
                XCTAssertFalse(core.requestPage(4, timestamp: 1.1))
                XCTAssertEqual(core.state, .interrupted)
                XCTAssertEqual(core.transitionToken, old.token)
                XCTAssertNil(core.activeTransition)
                XCTAssertTrue(core.currentSession === session)
                XCTAssertEqual(core.visualOffset, offset)
            }
            XCTAssertTrue(core.handleGesturePhase(.began, timestamp: 1))
            XCTAssertEqual(fixture.actionCount, 1)
            XCTAssertEqual(core.state, .tracking)
            let takeover = try XCTUnwrap(core.currentSession)
            XCTAssertFalse(takeover === session)
            XCTAssertEqual(takeover.startTimestamp, 1)
            XCTAssertEqual(takeover.startOffset, offset)
            XCTAssertEqual(core.visualOffset, offset)
            XCTAssertEqual(core.transitionToken, old.token)
            XCTAssertEqual(fixture.trace, ordinaryTrace(old: old, offset: offset))
            XCTAssertTrue(core.handleGesturePhase(.ended, timestamp: 2))
            XCTAssertTrue(core.finishGesture(timestamp: 2))
            finish(core)
            XCTAssertEqual(core.commitCount, 1)
        }
    }

    func testRejectedRequestAtSettlingCallbacksDoesNotRevokeOrdinaryTakeover() throws {
        for seed in Seed.allCases {
            for boundary in [Boundary.stale, .interruption] {
                let fixture = Fixture()
                let core = fixture.core!
                let old = try fixture.seed(seed)
                let session = core.currentSession
                let offset = core.visualOffset
                fixture.arm(boundary) {
                    XCTAssertEqual(core.state, .settling)
                    XCTAssertNil(core.activeTransition)
                    let traceBeforeRequest = fixture.trace
                    XCTAssertTrue(core.canRequestPage(4))
                    XCTAssertFalse(core.requestPage(4, timestamp: .nan))
                    XCTAssertEqual(fixture.trace, traceBeforeRequest)
                    XCTAssertEqual(core.state, .settling)
                    XCTAssertNil(core.activeTransition)
                    XCTAssertTrue(core.currentSession === session)
                    XCTAssertEqual(core.transitionToken, old.token)
                    XCTAssertEqual(core.visualOffset, offset)
                }
                XCTAssertTrue(core.handleGesturePhase(.began, timestamp: 1))
                XCTAssertEqual(fixture.actionCount, 1)
                XCTAssertEqual(fixture.trace, ordinaryTrace(old: old, offset: offset))
                XCTAssertEqual(core.state, .tracking)
                XCTAssertEqual(core.currentSession?.startOffset, offset)
                XCTAssertEqual(core.currentSession?.startTimestamp, 1)
                XCTAssertEqual(core.commitCount, 0)
            }
        }
    }

    func testCancelThenFreshBeganAtEveryBoundaryPreservesTheAcceptedSession() throws {
        for seed in Seed.allCases {
            for boundary in Boundary.allCases {
                let fixture = Fixture()
                let core = fixture.core!
                let old = try fixture.seed(seed)
                let priorSession = core.currentSession
                var fresh: GestureSession?
                var freshTrace: [Event] = []
                fixture.arm(boundary) {
                    core.cancel()
                    XCTAssertEqual(core.state, .idle)
                    XCTAssertTrue(core.handleGesturePhase(.began, timestamp: 10))
                    fresh = core.currentSession
                    freshTrace = fixture.trace
                }
                XCTAssertFalse(core.handleGesturePhase(.began, timestamp: 1))
                let session = try XCTUnwrap(fresh)
                XCTAssertEqual(fixture.actionCount, 1)
                XCTAssertEqual(fixture.trace, freshTrace)
                XCTAssertEqual(core.state, .tracking)
                XCTAssertTrue(core.currentSession === session)
                XCTAssertFalse(session === priorSession)
                if let priorSession { XCTAssertGreaterThan(session.id, priorSession.id) }
                XCTAssertEqual(session.startTimestamp, 10)
                XCTAssertEqual(session.startOffset, 1)
                XCTAssertEqual(core.visualOffset, 1)
                XCTAssertEqual(core.transitionToken, old.token)
                XCTAssertNil(core.activeTransition)
                XCTAssertFalse(core.completeSettle(old))
                XCTAssertTrue(core.currentSession === session)
                XCTAssertTrue(core.handleGesturePhase(.changed, delta: 600, timestamp: 11))
                XCTAssertTrue(core.handleGesturePhase(.ended, timestamp: 12))
                XCTAssertTrue(core.finishGesture(timestamp: 12))
                let released = try XCTUnwrap(core.activeTransition)
                XCTAssertEqual(released.token, old.token + 1)
                XCTAssertEqual(released.targetPage, 2)
                finish(core)
                XCTAssertEqual(core.committedPage, 2)
                XCTAssertEqual(core.visualOffset, 2)
                XCTAssertEqual(core.commitCount, 1)
            }
        }
    }

    func testNestedBeganWhileSettlingHasNoContextIsRejectedWithoutMutation() throws {
        for seed in Seed.allCases {
            for boundary in [Boundary.stale, .interruption] {
                let fixture = Fixture()
                let core = fixture.core!
                let old = try fixture.seed(seed)
                let session = core.currentSession
                let offset = core.visualOffset
                fixture.arm(boundary) {
                    XCTAssertEqual(core.state, .settling)
                    XCTAssertNil(core.activeTransition)
                    let traceBeforeNestedBegan = fixture.trace
                    XCTAssertFalse(core.handleGesturePhase(.began, timestamp: 99))
                    XCTAssertEqual(fixture.trace, traceBeforeNestedBegan)
                    XCTAssertEqual(core.state, .settling)
                    XCTAssertTrue(core.currentSession === session)
                    XCTAssertEqual(core.transitionToken, old.token)
                    XCTAssertEqual(core.visualOffset, offset)
                }
                XCTAssertTrue(core.handleGesturePhase(.began, timestamp: 1))
                XCTAssertEqual(fixture.actionCount, 1)
                XCTAssertEqual(fixture.trace, ordinaryTrace(old: old, offset: offset))
                XCTAssertEqual(core.state, .tracking)
                XCTAssertEqual(core.currentSession?.startTimestamp, 1)
                XCTAssertEqual(core.currentSession?.startOffset, offset)
                XCTAssertFalse(core.currentSession === session)
            }
        }
    }

    func testOrdinaryTakeoverKeepsExactTraceDisplayedOffsetAndBoundedCommit() throws {
        for seed in Seed.allCases {
            let fixture = Fixture()
            let core = fixture.core!
            let old = try fixture.seed(seed)
            let priorSession = core.currentSession
            let offset = core.visualOffset
            let staleCount = core.staleRejectionCount
            XCTAssertTrue(core.handleGesturePhase(.began, timestamp: 1))
            XCTAssertEqual(fixture.trace, ordinaryTrace(old: old, offset: offset))
            XCTAssertEqual(old.commitState, .stale)
            XCTAssertFalse(old.hasCommitted)
            XCTAssertEqual(core.staleRejectionCount, staleCount + 1)
            XCTAssertEqual(core.interruptionCount, 1)
            XCTAssertEqual(core.transitionToken, old.token)
            XCTAssertEqual(core.committedPage, 1)
            XCTAssertEqual(core.visualOffset, offset)
            let session = try XCTUnwrap(core.currentSession)
            XCTAssertFalse(session === priorSession)
            XCTAssertEqual(session.startOffset, offset)
            XCTAssertEqual(session.currentOffset, offset)
            XCTAssertEqual(session.startTimestamp, 1)
            XCTAssertNil(core.activeTransition)
            XCTAssertEqual(core.commitCount, 0)
            XCTAssertTrue(core.handleGesturePhase(.ended, timestamp: 2))
            XCTAssertTrue(core.finishGesture(timestamp: 2))
            let released = try XCTUnwrap(core.activeTransition)
            XCTAssertEqual(released.token, old.token + 1)
            XCTAssertEqual(released.fromOffset, offset)
            finish(core)
            XCTAssertTrue(released.hasCommitted)
            XCTAssertEqual(core.visualOffset, Double(released.targetPage))
            XCTAssertEqual(core.committedPage, released.targetPage)
            XCTAssertEqual(core.commitCount, 1)
            XCTAssertNil(core.activeTransition)
        }
    }

    func testOldCompletionCannotMutateTrackingOrItsLaterPendingAndCommittedTransition() throws {
        for seed in Seed.allCases {
            let fixture = Fixture()
            let core = fixture.core!
            let old = try fixture.seed(seed)
            XCTAssertTrue(core.handleGesturePhase(.began, timestamp: 1))
            let session = try XCTUnwrap(core.currentSession)
            let offset = core.visualOffset
            let staleCount = core.staleRejectionCount
            XCTAssertFalse(core.completeSettle(old))
            XCTAssertEqual(core.staleRejectionCount, staleCount + 1)
            XCTAssertEqual(fixture.trace.last, .stale(old.token))
            XCTAssertEqual(core.state, .tracking)
            XCTAssertTrue(core.currentSession === session)
            XCTAssertEqual(core.visualOffset, offset)
            XCTAssertEqual(core.transitionToken, old.token)
            XCTAssertEqual(core.commitCount, 0)
            XCTAssertTrue(core.handleGesturePhase(.ended, timestamp: 2))
            XCTAssertTrue(core.finishGesture(timestamp: 2))
            let newer = try XCTUnwrap(core.activeTransition)
            XCTAssertFalse(core.completeSettle(old))
            XCTAssertTrue(core.activeTransition === newer)
            XCTAssertEqual(core.transitionToken, newer.token)
            XCTAssertEqual(newer.commitState, .pending)
            XCTAssertEqual(core.state, .settling)
            finish(core)
            XCTAssertFalse(core.completeSettle(old))
            XCTAssertEqual(core.state, .idle)
            XCTAssertEqual(core.transitionToken, newer.token)
            XCTAssertEqual(core.committedPage, newer.targetPage)
            XCTAssertEqual(core.visualOffset, Double(newer.targetPage))
            XCTAssertEqual(core.commitCount, 1)
            XCTAssertTrue(newer.hasCommitted)
            XCTAssertEqual(fixture.trace.filter { $0 == .commit(newer.token) }.count, 1)
        }
    }

    private func ordinaryTrace(old: TransitionContext, offset: Double) -> [Event] {
        [
            .stale(old.token),
            .interruption(offset: offset, target: old.targetPage, token: old.token),
            .state(.interrupted),
            .state(.tracking)
        ]
    }
}
