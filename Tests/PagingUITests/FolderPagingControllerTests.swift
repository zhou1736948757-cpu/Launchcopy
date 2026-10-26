import AppKit
import XCTest
import PagingCore
@testable import PagingUI

/// Input/state tests only: no NSApplication, windows, fixture writes, or real-time waits.
final class FolderPagingControllerTests: XCTestCase {
    private final class Clock {
        var now: TimeInterval = 100
    }

    func testInitialAndRepeatedIdleConfigurationNeverStartTimerOrEmitCommit() {
        let driver = FolderPagingController()
        defer { driver.tearDown() }
        XCTAssertTrue(driver.automaticallyDrivesFrames)
        XCTAssertFalse(driver.isActive)
        XCTAssertNil(driver.frameTimer)
        var offsets: [Double] = []
        var commits: [Int] = []
        var activity: [Bool] = []
        driver.onOffsetChange = { offsets.append($0) }
        driver.onCommit = { commits.append($0) }
        driver.onActivityChange = { activity.append($0) }
        driver.configure(pageCount: 4, pageWidth: 600, currentPage: 2, reduceMotion: false)
        let core = driver.core
        for _ in 0..<10 {
            driver.configure(pageCount: 4, pageWidth: 600, currentPage: 2, reduceMotion: false)
            driver.advanceFrame(deltaTime: 1.0 / 60.0)
        }
        XCTAssertTrue(driver.core === core)
        XCTAssertEqual(driver.core.parameters, PagingParameters())
        XCTAssertEqual(offsets, [2])
        XCTAssertTrue(commits.isEmpty)
        XCTAssertTrue(activity.isEmpty)
        XCTAssertFalse(driver.isActive)
        XCTAssertNil(driver.frameTimer)
    }

    func testFingerTrackingUsesPageUnitsAndCommitsOnceAfterRelease() {
        let driver = makeDriver()
        var offsets: [Double] = []
        var commits: [Int] = []
        var activity: [Bool] = []
        driver.onOffsetChange = { offsets.append($0) }
        driver.onCommit = { commits.append($0) }
        driver.onActivityChange = { activity.append($0) }
        send(driver, phase: .began)
        send(driver, phase: .changed, x: -200, at: 0.1)
        XCTAssertEqual(driver.core.visualOffset, 0.2, accuracy: 1e-9)
        send(driver, phase: .changed, x: -300, at: 0.2)
        XCTAssertEqual(driver.core.visualOffset, 0.5, accuracy: 1e-9)
        XCTAssertEqual(driver.core.committedPage, 0)
        XCTAssertTrue(driver.isActive)
        send(driver, phase: .ended, at: 0.3)
        XCTAssertNotNil(driver.pendingFinishSince)
        XCTAssertTrue(commits.isEmpty)
        finishPending(driver)
        settle(driver)
        XCTAssertEqual(driver.core.committedPage, 1)
        XCTAssertEqual(driver.core.visualOffset, 1)
        XCTAssertEqual(commits, [1])
        XCTAssertEqual(activity, [true, false])
        XCTAssertEqual(offsets.first ?? -1, 0.2, accuracy: 1e-9)
        XCTAssertEqual(offsets.last, 1)
        XCTAssertNil(driver.frameTimer)
    }

    func testNaturalAndTraditionalDirectionsAreEquivalent() {
        let natural = makeDriver()
        let traditional = makeDriver()
        send(natural, phase: .began)
        send(traditional, phase: .began, inverted: false)
        send(natural, phase: .changed, x: -300, at: 0.1)
        send(traditional, phase: .changed, x: 300, inverted: false, at: 0.1)
        XCTAssertEqual(natural.core.visualOffset, 0.3, accuracy: 1e-9)
        XCTAssertEqual(traditional.core.visualOffset, natural.core.visualOffset)
    }

    func testVerticalFingerMotionDoesNotMovePages() {
        let driver = makeDriver()
        send(driver, phase: .began)
        send(driver, phase: .changed, x: -200, y: 400, at: 0.1)
        XCTAssertEqual(driver.core.visualOffset, 0)
        send(driver, phase: .ended, at: 0.2)
        finishPending(driver)
        settle(driver)
        XCTAssertEqual(driver.core.committedPage, 0)
    }

    func testSmallSlowReleaseBouncesToCommittedPage() {
        let driver = makeDriver(page: 1)
        send(driver, phase: .began)
        send(driver, phase: .changed, x: -100, at: 1)
        send(driver, phase: .ended, at: 1.1)
        finishPending(driver)
        settle(driver)
        XCTAssertEqual(driver.core.committedPage, 1)
        XCTAssertEqual(driver.core.visualOffset, 1)
    }

    func testReleaseWaitUsesInjectedClockAndExactHundredMillisecondWindow() {
        let clock = Clock()
        let driver = makeDriver(clock: clock)
        send(driver, phase: .began)
        send(driver, phase: .changed, x: -500, at: 0.5)
        send(driver, phase: .ended, at: 0.6)
        XCTAssertEqual(driver.pendingFinishSince, 100)
        clock.now = 100.099
        driver.advanceFrame(deltaTime: 1.0 / 60.0)
        XCTAssertEqual(driver.core.state, .tracking)
        XCTAssertNotNil(driver.pendingFinishSince)
        clock.now = 100.101
        driver.advanceFrame(deltaTime: 1.0 / 60.0)
        XCTAssertEqual(driver.core.state, .settling)
        XCTAssertNil(driver.pendingFinishSince)
        XCTAssertEqual(driver.core.activeTransition?.createdAt, 100)
        settle(driver)
        XCTAssertEqual(driver.core.committedPage, 1)
    }

    func testMomentumTakesOverReleaseWaitAndUsesProductionCutoff() {
        let clock = Clock()
        let driver = makeDriver(clock: clock)
        var commits: [Int] = []
        driver.onCommit = { commits.append($0) }
        send(driver, phase: .began)
        send(driver, phase: .changed, x: -300, at: 0.1)
        send(driver, phase: .ended, at: 0.12)
        send(driver, momentum: .began, at: 0.13)
        XCTAssertNil(driver.pendingFinishSince)
        clock.now += 1
        driver.advanceFrame(deltaTime: 1.0 / 60.0)
        XCTAssertEqual(driver.core.state, .tracking, "The old timeout must not finish momentum")
        send(driver, momentum: .changed, x: -80, at: 0.14)
        XCTAssertEqual(driver.core.state, .tracking)
        send(driver, momentum: .changed, x: -80, at: 0.15)
        XCTAssertEqual(driver.core.state, .settling, "Production defaults follow two momentum changes")
        let offset = driver.core.visualOffset
        send(driver, momentum: .changed, x: -900, at: 0.16)
        send(driver, momentum: .ended, at: 0.17)
        XCTAssertEqual(driver.core.visualOffset, offset)
        settle(driver)
        XCTAssertEqual(commits, [1])
    }

    func testMomentumEndedGlideMatchesUnchangedCore() {
        let driver = makeDriver()
        let expected = PagingCore(pageCount: 4, pageWidth: 1000)
        send(driver, phase: .began)
        expected.handleGesturePhase(.began, timestamp: 0)
        send(driver, phase: .changed, x: -300, at: 0.1)
        expected.handleGesturePhase(.changed, delta: 300, timestamp: 0.1)
        send(driver, phase: .ended, at: 0.12)
        expected.handleGesturePhase(.ended, timestamp: 0.12)
        send(driver, momentum: .began, at: 0.13)
        expected.handleGesturePhase(.momentumBegan, timestamp: 0.13)
        send(driver, momentum: .changed, x: -80, at: 0.14)
        expected.handleGesturePhase(.momentumChanged, delta: 80, timestamp: 0.14)
        send(driver, momentum: .ended, at: 0.15)
        expected.handleGesturePhase(.momentumEnded, timestamp: 0.15)
        for _ in 0..<240 {
            driver.advanceFrame(deltaTime: 1.0 / 60.0)
            expected.tick(deltaTime: 1.0 / 60.0)
            XCTAssertEqual(driver.core.visualOffset, expected.visualOffset, accuracy: 1e-9)
            XCTAssertEqual(driver.core.state, expected.state)
        }
        XCTAssertEqual(driver.core.committedPage, expected.committedPage)
        XCTAssertEqual(driver.core.commitCount, expected.commitCount)
        XCTAssertFalse(driver.isActive)
    }

    func testNewGestureInterruptsSettlingAtDisplayedOffset() {
        let driver = makeDriver()
        releaseForward(driver)
        driver.advanceFrame(deltaTime: 1.0 / 60.0)
        let offset = driver.core.visualOffset
        let oldTransition = driver.core.activeTransition
        var activity: [Bool] = []
        driver.onActivityChange = { activity.append($0) }
        send(driver, phase: .began, at: 1)
        XCTAssertEqual(driver.core.visualOffset, offset)
        XCTAssertEqual(driver.core.currentSession?.startOffset, offset)
        XCTAssertEqual(driver.core.state, .tracking)
        XCTAssertEqual(oldTransition?.commitState, .stale)
        XCTAssertTrue(activity.isEmpty, "Interruption remains one continuous activity")
        send(driver, phase: .changed, x: 100, at: 1.1)
        XCTAssertEqual(driver.core.visualOffset, offset - 0.1, accuracy: 1e-9)
    }

    func testNewGestureFinishesOldReleaseBeforeOwnerCleanup() {
        let driver = makeDriver()
        var commits: [Int] = []
        driver.onCommit = { page in
            commits.append(page)
            driver.cancel()
            driver.configure(pageCount: 4, pageWidth: 1000, currentPage: page, reduceMotion: false)
        }
        send(driver, phase: .began)
        send(driver, phase: .ended, at: 0.1)
        send(driver, phase: .began, at: 0.2)
        XCTAssertEqual(commits, [0])
        XCTAssertEqual(driver.core.state, .tracking)
        XCTAssertFalse(driver.core.currentSession?.released ?? true)
        XCTAssertNil(driver.pendingFinishSince)
        send(driver, phase: .changed, x: -100, at: 0.3)
        XCTAssertEqual(driver.core.visualOffset, 0.1, accuracy: 1e-9)
    }

    func testFirstAndLastPageOverscrollAreDampedAndBounded() {
        for page in [0, 3] {
            let driver = makeDriver(page: page)
            send(driver, phase: .began)
            let x: CGFloat = page == 0 ? 200 : -200
            send(driver, phase: .changed, x: x, at: 0.1)
            let depth = abs(driver.core.visualOffset - Double(page))
            XCTAssertEqual(depth, 0.2 * PagingParameters().boundaryResistance, accuracy: 1e-9)
            for index in 2...10 {
                send(driver, phase: .changed, x: x, at: Double(index) * 0.1)
            }
            XCTAssertLessThanOrEqual(abs(driver.core.visualOffset - Double(page)), PagingParameters().maximumOverscroll)
            send(driver, phase: .ended, at: 1.1)
            finishPending(driver)
            settle(driver)
            XCTAssertEqual(driver.core.committedPage, page)
            XCTAssertEqual(driver.core.visualOffset, Double(page))
        }
    }

    func testRapidReversalContinuesFollowingFingerAndRetreats() {
        let driver = makeDriver(page: 1)
        send(driver, phase: .began)
        send(driver, phase: .changed, x: -350, at: 0.1)
        XCTAssertEqual(driver.core.visualOffset, 1.35, accuracy: 1e-9)
        send(driver, phase: .changed, x: 750, at: 0.11)
        XCTAssertEqual(driver.core.visualOffset, 0.6, accuracy: 1e-9)
        send(driver, phase: .ended, at: 0.12)
        finishPending(driver)
        settle(driver)
        XCTAssertEqual(driver.core.committedPage, 0)
    }

    func testRepeatedConfigurationDoesNotInterruptTrackingOrSettling() {
        let driver = makeDriver()
        let core = driver.core
        send(driver, phase: .began)
        send(driver, phase: .changed, x: -500, at: 0.1)
        driver.configure(pageCount: 4, pageWidth: 1000, currentPage: 0, reduceMotion: false)
        XCTAssertTrue(driver.core === core)
        XCTAssertEqual(driver.core.visualOffset, 0.5)
        XCTAssertEqual(driver.core.state, .tracking)
        send(driver, phase: .ended, at: 0.2)
        finishPending(driver)
        let transition = driver.core.activeTransition
        driver.configure(pageCount: 4, pageWidth: 1000, currentPage: 0, reduceMotion: false)
        XCTAssertTrue(driver.core.activeTransition === transition)
        settle(driver)
    }

    func testKeyboardPageSynchronizationWorksWhenIdleAndBusyWithoutCommit() {
        let driver = makeDriver()
        var commits: [Int] = []
        driver.onCommit = { commits.append($0) }
        driver.configure(pageCount: 4, pageWidth: 1000, currentPage: 2, reduceMotion: false)
        XCTAssertEqual(driver.core.committedPage, 2)
        send(driver, phase: .began)
        send(driver, phase: .changed, x: 200, at: 0.1)
        send(driver, phase: .ended, at: 0.2)
        let oldCore = driver.core
        driver.configure(pageCount: 4, pageWidth: 1000, currentPage: 1, reduceMotion: false)
        XCTAssertTrue(oldCore.isTearingDown)
        XCTAssertEqual(driver.core.committedPage, 1)
        XCTAssertEqual(driver.core.visualOffset, 1)
        XCTAssertFalse(driver.isActive)
        XCTAssertNil(driver.pendingFinishSince)
        XCTAssertNil(driver.frameTimer)
        XCTAssertTrue(commits.isEmpty)
    }

    func testGeometryCountAndMotionChangesCancelAndClampAuthoritativePage() {
        let driver = makeDriver(page: 3)
        send(driver, phase: .began)
        send(driver, phase: .changed, x: 200, at: 0.1)
        let oldCore = driver.core
        driver.configure(pageCount: 2, pageWidth: 600, currentPage: 3, reduceMotion: true)
        XCTAssertTrue(oldCore.isTearingDown)
        XCTAssertEqual(driver.core.pageCount, 2)
        XCTAssertEqual(driver.core.pageWidth, 600)
        XCTAssertEqual(driver.core.committedPage, 1)
        XCTAssertEqual(driver.core.visualOffset, 1)
        XCTAssertTrue(driver.core.reduceMotion)
        XCTAssertEqual(driver.core.parameters, PagingParameters())
        XCTAssertFalse(driver.isActive)
    }

    func testEmptyAndUnavailableGeometryRejectInputWithoutTimers() {
        let driver = makeDriver()
        for width in [0, -10, Double.nan, Double.infinity] {
            driver.configure(pageCount: 4, pageWidth: width, currentPage: 0, reduceMotion: false)
            send(driver, phase: .began)
            send(driver, phase: .changed, x: -500, at: 0.1)
            send(driver, phase: .ended, at: 0.2)
            XCTAssertFalse(driver.isActive)
            XCTAssertTrue(driver.core.visualOffset.isFinite)
            XCTAssertNil(driver.frameTimer)
        }
        driver.configure(pageCount: 0, pageWidth: 600, currentPage: 10, reduceMotion: false)
        send(driver, phase: .began)
        XCTAssertEqual(driver.core.committedPage, 0)
        XCTAssertFalse(driver.isActive)
        driver.configure(pageCount: 2, pageWidth: 600, currentPage: 0, reduceMotion: false)
        send(driver, phase: .began)
        XCTAssertTrue(driver.isActive, "Valid geometry can resume input")
    }

    func testCancelTrackingReleaseWaitAndSettleRestoresLastCommittedPage() {
        for stage in 0...2 {
            let clock = Clock()
            let driver = makeDriver(page: 1, clock: clock)
            var commits: [Int] = []
            var offsets: [Double] = []
            var activity: [Bool] = []
            driver.onCommit = { commits.append($0) }
            driver.onOffsetChange = { offsets.append($0) }
            driver.onActivityChange = { activity.append($0) }
            send(driver, phase: .began)
            send(driver, phase: .changed, x: -500, at: 0.1)
            if stage >= 1 { send(driver, phase: .ended, at: 0.2) }
            if stage == 2 { finishPending(driver) }
            driver.cancel()
            driver.cancel()
            clock.now += 1
            driver.advanceFrame(deltaTime: 1.0 / 60.0)
            XCTAssertEqual(driver.core.committedPage, 1)
            XCTAssertEqual(driver.core.visualOffset, 1)
            XCTAssertEqual(offsets.last, 1)
            XCTAssertEqual(activity, [true, false])
            XCTAssertTrue(commits.isEmpty)
            XCTAssertFalse(driver.isActive)
            XCTAssertNil(driver.pendingFinishSince)
            XCTAssertNil(driver.frameTimer)
        }
    }

    func testCancelAfterGestureCommitUsesNewCommittedPage() {
        let driver = makeDriver()
        releaseForward(driver)
        settle(driver)
        send(driver, phase: .began, at: 1)
        send(driver, phase: .changed, x: -100, at: 1.1)
        driver.cancel()
        XCTAssertEqual(driver.core.committedPage, 1)
        XCTAssertEqual(driver.core.visualOffset, 1)
    }

    func testCancelledPhaseAndOrphanEventsLeaveNoPendingRelease() {
        let driver = makeDriver()
        send(driver, phase: .ended)
        send(driver, phase: .changed, x: -100)
        send(driver, momentum: .began)
        send(driver, momentum: .changed, x: -100)
        send(driver, momentum: .ended)
        XCTAssertFalse(driver.isActive)
        XCTAssertNil(driver.pendingFinishSince)
        send(driver, phase: .began)
        send(driver, phase: .changed, x: -200, at: 0.1)
        send(driver, phase: .cancelled, at: 0.2)
        XCTAssertEqual(driver.core.visualOffset, 0)
        XCTAssertFalse(driver.isActive)
        XCTAssertNil(driver.pendingFinishSince)
    }

    func testReduceMotionCompletesWithoutSettleTimerAndEmitsOneCommit() {
        let driver = makeDriver(reduceMotion: true)
        var commits: [Int] = []
        driver.onCommit = { commits.append($0) }
        releaseForward(driver)
        XCTAssertEqual(driver.core.committedPage, 1)
        XCTAssertEqual(driver.core.visualOffset, 1)
        XCTAssertFalse(driver.isActive)
        XCTAssertNil(driver.frameTimer)
        XCTAssertEqual(commits, [1])
    }

    func testLegacyInputUsesSameCoreDecisionAndNoPhaseFinishesPendingRelease() {
        let driver = makeDriver()
        let expected = PagingCore(pageCount: 4, pageWidth: 1000)
        send(driver, x: -500, at: 0.5)
        expected.legacyScrollDelta(500, timestamp: 0.5)
        XCTAssertEqual(driver.core.visualOffset, expected.visualOffset)
        XCTAssertEqual(driver.core.activeTransition?.targetPage, expected.activeTransition?.targetPage)
        settle(driver)
        send(driver, phase: .began, at: 1)
        send(driver, phase: .changed, x: -100, at: 2)
        send(driver, phase: .ended, at: 2.1)
        send(driver, x: -900, at: 2.2)
        XCTAssertNil(driver.pendingFinishSince)
        XCTAssertEqual(driver.core.visualOffset, 1.1, accuracy: 1e-9, "No-phase event finishes old release without adding its delta")
        settle(driver)
    }

    func testReentrantCommitCanCancelAndReconfigureAuthoritativePage() {
        let driver = makeDriver()
        let oldCore = driver.core
        var commits: [Int] = []
        driver.onCommit = { page in
            commits.append(page)
            driver.cancel()
            driver.configure(pageCount: 5, pageWidth: 600, currentPage: 3, reduceMotion: true)
        }
        releaseForward(driver)
        settle(driver)
        XCTAssertEqual(commits, [1])
        XCTAssertTrue(oldCore.isTearingDown)
        XCTAssertEqual(driver.core.committedPage, 3)
        XCTAssertEqual(driver.core.visualOffset, 3)
        XCTAssertEqual(driver.core.pageWidth, 600)
        XCTAssertFalse(driver.isActive)
        // A retained old core and its event closures cannot write into the replacement.
        oldCore.events.onVisualOffsetChange?(99)
        XCTAssertFalse(oldCore.handleGesturePhase(.began, timestamp: 2))
        driver.advanceFrame(deltaTime: 1.0 / 60.0)
        XCTAssertEqual(driver.core.committedPage, 3)
        XCTAssertEqual(commits, [1])
    }

    func testReentrantOffsetCanCancelWithoutLeavingOldCoreHalfTracking() {
        let driver = makeDriver()
        var commits: [Int] = []
        var offsets: [Double] = []
        driver.onCommit = { commits.append($0) }
        driver.onOffsetChange = { offset in
            offsets.append(offset)
            if offset != 0 { driver.cancel() }
        }
        send(driver, phase: .began)
        send(driver, phase: .changed, x: -200, at: 0.1)
        XCTAssertEqual(offsets, [0.2, 0])
        XCTAssertEqual(driver.core.state, .idle)
        XCTAssertNil(driver.core.currentSession)
        XCTAssertFalse(driver.isActive)
        XCTAssertTrue(commits.isEmpty)
    }

    func testReentrantActivityCanCancelBeforeAnyMovement() {
        let driver = makeDriver()
        var activity: [Bool] = []
        driver.onActivityChange = { active in
            activity.append(active)
            if active { driver.cancel() }
        }
        send(driver, phase: .began)
        XCTAssertEqual(activity, [true, false])
        XCTAssertFalse(driver.isActive)
        XCTAssertNil(driver.core.currentSession)
        XCTAssertNil(driver.frameTimer)
    }

    func testTearDownInsideOffsetDropsRemainingCommitAndActivityCallbacks() {
        let driver = makeDriver(reduceMotion: true)
        var callbacks: [String] = []
        driver.onCommit = { _ in callbacks.append("commit") }
        driver.onActivityChange = { callbacks.append("active:\($0)") }
        send(driver, phase: .began)
        send(driver, phase: .changed, x: -500, at: 0.1)
        send(driver, phase: .ended, at: 0.2)
        driver.onOffsetChange = { _ in
            callbacks.append("offset")
            driver.tearDown()
        }
        finishPending(driver)
        XCTAssertEqual(callbacks, ["active:true", "offset"])
        XCTAssertTrue(driver.core.isTearingDown)
        XCTAssertFalse(driver.isActive)
        XCTAssertNil(driver.frameTimer)
    }

    func testTearDownIsTerminalIdempotentAndSilent() {
        let clock = Clock()
        let driver = makeDriver(clock: clock)
        send(driver, phase: .began)
        send(driver, phase: .ended, at: 0.1)
        var callbacks = 0
        driver.onCommit = { _ in callbacks += 1 }
        driver.onOffsetChange = { _ in callbacks += 1 }
        driver.onActivityChange = { _ in callbacks += 1 }
        driver.tearDown()
        driver.tearDown()
        driver.cancel()
        driver.configure(pageCount: 4, pageWidth: 600, currentPage: 3, reduceMotion: false)
        send(driver, phase: .began)
        clock.now += 1
        driver.advanceFrame(deltaTime: 1.0 / 60.0)
        XCTAssertEqual(callbacks, 0)
        XCTAssertFalse(driver.isActive)
        XCTAssertNil(driver.pendingFinishSince)
        XCTAssertNil(driver.frameTimer)
        XCTAssertTrue(driver.core.isTearingDown)
    }

    func testTimerOnlyRunsForPendingReleaseOrAnimationAndStopsOnIdle() {
        let driver = makeDriver()
        driver.automaticallyDrivesFrames = true
        XCTAssertNil(driver.frameTimer)
        send(driver, phase: .began)
        send(driver, phase: .changed, x: -500, at: 0.1)
        XCTAssertNil(driver.frameTimer, "Finger tracking is event-driven")
        send(driver, phase: .ended, at: 0.2)
        let timer = driver.frameTimer
        XCTAssertNotNil(timer)
        XCTAssertEqual(timer?.timeInterval ?? 0, 1.0 / 60.0, accuracy: 1e-9)
        XCTAssertEqual(timer?.tolerance, 0)
        finishPending(driver)
        XCTAssertTrue(driver.frameTimer === timer, "Pending release and settle share one timer")
        settle(driver)
        XCTAssertNil(driver.frameTimer)
        XCTAssertFalse(timer?.isValid ?? true)
    }

    func testAutomaticFrameToggleCancelReconfigureAndTearDownInvalidateTimers() {
        let driver = makeDriver()
        releaseForward(driver)
        XCTAssertNil(driver.frameTimer)
        driver.automaticallyDrivesFrames = true
        let first = driver.frameTimer
        XCTAssertNotNil(first)
        driver.automaticallyDrivesFrames = false
        XCTAssertNil(driver.frameTimer)
        XCTAssertFalse(first?.isValid ?? true)
        driver.automaticallyDrivesFrames = true
        let second = driver.frameTimer
        driver.cancel()
        XCTAssertNil(driver.frameTimer)
        XCTAssertFalse(second?.isValid ?? true)
        releaseForward(driver)
        let third = driver.frameTimer
        driver.configure(pageCount: 2, pageWidth: 500, currentPage: 1, reduceMotion: false)
        XCTAssertNil(driver.frameTimer)
        XCTAssertFalse(third?.isValid ?? true)
        releaseForward(driver)
        let fourth = driver.frameTimer
        driver.tearDown()
        XCTAssertNil(driver.frameTimer)
        XCTAssertFalse(fourth?.isValid ?? true)
    }

    func testActiveTimerAndRetainedCoreDoNotRetainController() {
        var driver: FolderPagingController? = FolderPagingController()
        driver?.configure(pageCount: 4, pageWidth: 1000, currentPage: 0, reduceMotion: false)
        send(driver!, phase: .began)
        send(driver!, phase: .changed, x: -500, at: 0.1)
        send(driver!, phase: .ended, at: 0.2)
        weak var weakDriver = driver
        let timer = driver?.frameTimer
        let retainedCore = driver?.core
        XCTAssertNotNil(timer)
        driver = nil
        XCTAssertNil(weakDriver)
        XCTAssertFalse(timer?.isValid ?? true)
        XCTAssertTrue(retainedCore?.isTearingDown ?? false)
    }

    func testNonFiniteInputsAndInvalidFrameTimesDoNotPoisonState() {
        let driver = makeDriver()
        send(driver, phase: .began)
        send(driver, phase: .changed, x: .nan, at: 0.1)
        send(driver, phase: .changed, x: -100, at: .infinity)
        driver.advanceFrame(deltaTime: .nan)
        driver.advanceFrame(deltaTime: .infinity)
        driver.advanceFrame(deltaTime: -1)
        XCTAssertEqual(driver.core.visualOffset, 0)
        XCTAssertEqual(driver.core.state, .tracking)
    }

    private func makeDriver(page: Int = 0, reduceMotion: Bool = false, clock: Clock = Clock()) -> FolderPagingController {
        let driver = FolderPagingController()
        driver.automaticallyDrivesFrames = false
        driver.pendingFinishTimeSource = { clock.now }
        driver.configure(pageCount: 4, pageWidth: 1000, currentPage: page, reduceMotion: reduceMotion)
        addTeardownBlock { driver.tearDown() }
        return driver
    }

    private func send(
        _ driver: FolderPagingController,
        phase: NSEvent.Phase = [],
        momentum: NSEvent.Phase = [],
        x: CGFloat = 0,
        y: CGFloat = 0,
        inverted: Bool = true,
        at timestamp: TimeInterval = 0
    ) {
        driver.handleScroll(phase: phase, momentumPhase: momentum, deltaX: x, deltaY: y,
                            isDirectionInverted: inverted, timestamp: timestamp)
    }

    private func finishPending(_ driver: FolderPagingController) {
        send(driver, at: 0.6)
    }

    private func releaseForward(_ driver: FolderPagingController) {
        send(driver, phase: .began)
        send(driver, phase: .changed, x: -500, at: 0.1)
        send(driver, phase: .ended, at: 0.2)
        finishPending(driver)
    }

    private func settle(_ driver: FolderPagingController, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<240 {
            if !driver.isActive { break }
            driver.advanceFrame(deltaTime: 1.0 / 60.0)
        }
        XCTAssertFalse(driver.isActive, "Expected bounded settling to reach idle", file: file, line: line)
    }
}
