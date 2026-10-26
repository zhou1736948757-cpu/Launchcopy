import AppKit
import XCTest
import PagingCore
@testable import PagingUI

/// Deterministic shared-pump contracts: no windows, event synthesis, or run-loop waits.
final class LeadingPaneSharedFrameTests: XCTestCase {
    private final class FrameDriver: PagingFrameDriving {
        private(set) var isRunning = false
        private(set) var starts = 0
        private(set) var stops = 0

        func start() {
            guard !isRunning else { return }
            isRunning = true
            starts += 1
        }

        func stop() {
            guard isRunning else { return }
            isRunning = false
            stops += 1
        }
    }

    private let frameTime: TimeInterval = 1.0 / 60.0

    func testSupplementalDemandSharesExistingDriverAndPreservesTelemetry() {
        let (surface, driver) = makeSharedSurface()
        defer { surface.teardown() }
        var needsFrames = true
        var telemetry: [TimeInterval] = []
        var steps: [TimeInterval] = []
        surface.onAnimationFrame = { telemetry.append($0) }
        surface.supplementalFrameStep = { steps.append($0) }
        surface.supplementalFrameDemand = { needsFrames }
        let layouts = surface.layoutPerformedCount

        surface.refreshFrameDemand()
        surface.refreshFrameDemand()
        XCTAssertTrue(surface.frameDriver === driver)
        XCTAssertTrue(driver.isRunning)
        XCTAssertEqual(driver.starts, 1)
        surface.simulateFrame(deltaTime: frameTime)
        surface.simulateFrame(deltaTime: frameTime)
        XCTAssertEqual(telemetry, [frameTime, frameTime])
        XCTAssertEqual(steps, telemetry)
        XCTAssertEqual(surface.core.state, .idle)
        XCTAssertEqual(surface.layoutPerformedCount, layouts)

        needsFrames = false
        surface.refreshFrameDemand()
        XCTAssertFalse(driver.isRunning)
        surface.supplementalFrameStep = nil
        surface.supplementalFrameDemand = nil
        surface.refreshFrameDemand()
        surface.simulateFrame(deltaTime: frameTime)
        XCTAssertEqual(steps.count, 2)
        XCTAssertEqual(telemetry.count, 3, "Clearing supplemental work preserves telemetry")
        XCTAssertEqual(driver.stops, 1)
    }

    func testClearingSupplementalDemandKeepsGridSpringRunning() {
        let (surface, driver) = makeSharedSurface()
        defer { surface.teardown() }
        surface.supplementalFrameDemand = { true }
        surface.refreshFrameDemand()
        XCTAssertTrue(surface.requestPage(1, timestamp: 0))
        surface.supplementalFrameDemand = nil
        surface.supplementalFrameStep = nil
        surface.refreshFrameDemand()
        XCTAssertTrue(driver.isRunning)
        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 1)
        XCTAssertFalse(driver.isRunning)
        XCTAssertEqual(driver.starts, 1)
    }

    func testTelemetryCanDetachSupplementalWorkBeforeItsFrameStep() {
        let (surface, driver) = makeSharedSurface()
        defer { surface.teardown() }
        var steps = 0
        surface.supplementalFrameDemand = { true }
        surface.supplementalFrameStep = { _ in steps += 1 }
        surface.onAnimationFrame = { [weak surface] _ in
            guard let surface else { return }
            surface.supplementalFrameStep = nil
            surface.supplementalFrameDemand = nil
            surface.refreshFrameDemand()
        }
        surface.refreshFrameDemand()
        surface.simulateFrame(deltaTime: frameTime)
        XCTAssertEqual(steps, 0)
        XCTAssertFalse(driver.isRunning)
        XCTAssertFalse(surface.isTearingDown)
    }

    func testClearingSupplementalDemandPreservesGridReleaseWait() {
        let (surface, driver) = makeSharedSurface()
        defer { surface.teardown() }
        var now: TimeInterval = 100
        surface.pendingFinishTimeSource = { now }
        surface.supplementalFrameDemand = { true }
        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 500, at: 0.5)
        gestureEnded(surface, at: 0.6)
        surface.supplementalFrameDemand = nil
        surface.refreshFrameDemand()
        XCTAssertTrue(driver.isRunning)
        now = 100.099
        surface.simulateFrame(deltaTime: frameTime)
        XCTAssertNotNil(surface.pendingFinishSince)
        XCTAssertEqual(surface.core.state, .tracking)
        now = 100.101
        surface.simulateFrame(deltaTime: frameTime)
        XCTAssertNil(surface.pendingFinishSince)
        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 1)
        XCTAssertFalse(driver.isRunning)
    }

    func testManualParentUsesSharedFramesAndUnchangedCoreSpring() {
        let (surface, driver) = makeSharedSurface(initialPage: 2)
        let parent = makeManualParent(parameters: surface.core.parameters)
        let expected = PagingCore(pageCount: 2, pageWidth: 1000, parameters: surface.core.parameters)
        defer { parent.tearDown(); surface.teardown(); expected.teardown() }
        var commits: [Int] = []
        var telemetryFrames = 0
        parent.onCommit = { commits.append($0) }
        surface.onAnimationFrame = { _ in telemetryFrames += 1 }
        surface.supplementalFrameDemand = { parent.needsFrames }
        surface.supplementalFrameStep = { parent.advanceFrame(deltaTime: $0) }
        XCTAssertTrue(parent.requestPage(1, timestamp: 42))
        XCTAssertTrue(expected.requestPage(1, timestamp: 42))
        surface.refreshFrameDemand()
        XCTAssertTrue(driver.isRunning)
        XCTAssertNil(parent.frameTimer)

        var frames = 0
        while parent.needsFrames, frames < 240 {
            surface.simulateFrame(deltaTime: frameTime)
            expected.tick(deltaTime: frameTime)
            XCTAssertEqual(parent.core.visualOffset, expected.visualOffset, accuracy: 1e-12)
            XCTAssertEqual(parent.core.state, expected.state)
            XCTAssertNil(parent.frameTimer)
            frames += 1
        }
        XCTAssertGreaterThan(frames, 0)
        XCTAssertFalse(parent.needsFrames)
        XCTAssertEqual(commits, [1])
        XCTAssertEqual(telemetryFrames, frames)
        XCTAssertEqual(surface.core.committedPage, 2)
        XCTAssertEqual(surface.core.pageCount, 5)
        XCTAssertFalse(driver.isRunning)
    }

    func testManualParentDemandDistinguishesTrackingReleaseWaitAndSettling() {
        let parent = makeManualParent()
        defer { parent.tearDown() }
        var now: TimeInterval = 100
        parent.pendingFinishTimeSource = { now }
        send(parent, phase: .began, at: 0)
        send(parent, phase: .changed, x: -500, at: 0.5)
        XCTAssertTrue(parent.isActive)
        XCTAssertFalse(parent.needsFrames)
        XCTAssertFalse(parent.requestPage(1, timestamp: 0.55))
        send(parent, phase: .ended, at: 0.6)
        XCTAssertTrue(parent.needsFrames)
        XCTAssertFalse(parent.requestPage(1, timestamp: 0.7))
        XCTAssertEqual(parent.pendingFinishSince, 100)
        now = 100.099
        parent.advanceFrame(deltaTime: frameTime)
        XCTAssertEqual(parent.core.state, .tracking)
        XCTAssertTrue(parent.needsFrames)
        now = 100.101
        parent.advanceFrame(deltaTime: frameTime)
        XCTAssertEqual(parent.core.state, .settling)
        XCTAssertNil(parent.pendingFinishSince)
        XCTAssertTrue(parent.needsFrames)
        XCTAssertNil(parent.frameTimer)
        parent.cancel()
        XCTAssertFalse(parent.isActive)
        XCTAssertFalse(parent.needsFrames)
        XCTAssertEqual(parent.core.committedPage, 0)
        XCTAssertNil(parent.frameTimer)
    }

    func testParentCancellationAndDetachmentStopSharedDemand() {
        let (surface, driver) = makeSharedSurface()
        let parent = makeManualParent()
        defer { parent.tearDown(); surface.teardown() }
        var commits: [Int] = []
        parent.onCommit = { commits.append($0) }
        surface.supplementalFrameDemand = { parent.needsFrames }
        surface.supplementalFrameStep = { parent.advanceFrame(deltaTime: $0) }
        XCTAssertTrue(parent.requestPage(1, timestamp: 0))
        surface.refreshFrameDemand()
        surface.simulateFrame(deltaTime: frameTime)
        parent.cancel()
        surface.refreshFrameDemand()
        XCTAssertFalse(driver.isRunning)
        XCTAssertFalse(parent.needsFrames)
        XCTAssertTrue(commits.isEmpty)
        XCTAssertNil(parent.frameTimer)
        surface.supplementalFrameStep = nil
        surface.supplementalFrameDemand = nil
        surface.refreshFrameDemand()
        surface.simulateFrame(deltaTime: frameTime)
        XCTAssertEqual(parent.core.visualOffset, 0)
        XCTAssertTrue(commits.isEmpty)
    }

    func testManualMomentumGlideNeedsFramesWhileStillTracking() {
        var parameters = PagingParameters()
        parameters.momentumGlideFrames = nil
        let parent = makeManualParent(parameters: parameters)
        defer { parent.tearDown() }
        send(parent, phase: .began, at: 0)
        send(parent, phase: .changed, x: -300, at: 0.1)
        send(parent, phase: .ended, at: 0.12)
        parent.handleScroll(phase: [], momentumPhase: .began, deltaX: 0, deltaY: 0,
                            isDirectionInverted: true, timestamp: 0.13)
        parent.handleScroll(phase: [], momentumPhase: .changed, deltaX: -80, deltaY: 0,
                            isDirectionInverted: true, timestamp: 0.14)
        parent.handleScroll(phase: [], momentumPhase: .ended, deltaX: 0, deltaY: 0,
                            isDirectionInverted: true, timestamp: 0.15)
        XCTAssertEqual(parent.core.state, .tracking)
        XCTAssertNil(parent.pendingFinishSince)
        XCTAssertTrue(parent.needsFrames)
        XCTAssertNil(parent.frameTimer)
    }

    func testConfigurationAdoptsChangedParametersAndRetainsDefaultFolderPolicy() {
        var parameters = PagingParameters()
        parameters.inputSensitivity = 0.75
        parameters.settleDuration = 0.3
        let parent = makeManualParent(parameters: parameters)
        defer { parent.tearDown() }
        let original = parent.core
        parent.configure(pageCount: 2, pageWidth: 1000, currentPage: 0, reduceMotion: false,
                         parameters: parameters)
        XCTAssertTrue(parent.core === original)
        XCTAssertEqual(parent.core.parameters, parameters)
        XCTAssertTrue(parent.requestPage(1, timestamp: 0))

        parameters.inputSensitivity = 1.2
        parent.configure(pageCount: 2, pageWidth: 1000, currentPage: 0, reduceMotion: false,
                         parameters: parameters)
        XCTAssertFalse(parent.core === original)
        XCTAssertEqual(parent.core.parameters, parameters)
        XCTAssertEqual(parent.core.state, .idle)
        XCTAssertFalse(parent.needsFrames)
        XCTAssertNil(parent.frameTimer)
        parent.configure(pageCount: 2, pageWidth: 1000, currentPage: 0, reduceMotion: false)
        XCTAssertEqual(parent.core.parameters, PagingParameters())
        XCTAssertFalse(parent.automaticallyDrivesFrames)
    }

    func testManualRequestSupportsRetargetingAndRejectsInvalidLifecycle() {
        let parent = makeManualParent()
        defer { parent.tearDown() }
        XCTAssertFalse(parent.requestPage(1, timestamp: .nan))
        XCTAssertTrue(parent.requestPage(1, timestamp: 0))
        XCTAssertFalse(parent.requestPage(1, timestamp: 0.01))
        parent.advanceFrame(deltaTime: frameTime)
        let offset = parent.core.visualOffset
        XCTAssertTrue(parent.requestPage(0, timestamp: 0.02))
        XCTAssertEqual(parent.core.activeTransition?.fromOffset, offset)
        XCTAssertNil(parent.frameTimer)
        parent.tearDown()
        XCTAssertFalse(parent.requestPage(1, timestamp: 1))
        XCTAssertFalse(parent.needsFrames)
        parent.advanceFrame(deltaTime: frameTime)
        XCTAssertNil(parent.frameTimer)

        let unconfigured = FolderPagingController()
        defer { unconfigured.tearDown() }
        unconfigured.automaticallyDrivesFrames = false
        XCTAssertFalse(unconfigured.requestPage(1, timestamp: 0))
        unconfigured.configure(pageCount: 2, pageWidth: 0, currentPage: 0, reduceMotion: false)
        XCTAssertFalse(unconfigured.requestPage(1, timestamp: 0))
    }

    func testReduceMotionRequestDeliversCommitAfterCoreOperationAndAllowsTeardown() {
        let parent = makeManualParent(reduceMotion: true)
        defer { parent.tearDown() }
        var commits: [Int] = []
        parent.onCommit = { page in
            XCTAssertEqual(parent.core.state, .idle)
            commits.append(page)
            parent.tearDown()
        }
        XCTAssertTrue(parent.requestPage(1, timestamp: 0))
        XCTAssertEqual(commits, [1])
        XCTAssertFalse(parent.needsFrames)
        XCTAssertNil(parent.frameTimer)
        parent.advanceFrame(deltaTime: frameTime)
        XCTAssertEqual(commits, [1])
    }

    func testTeardownClearsSupplementalHooksAndRejectsLateFramesAndRefresh() {
        let (surface, driver) = makeSharedSurface()
        var steps = 0
        var demands = 0
        var telemetry = 0
        surface.supplementalFrameStep = { _ in steps += 1 }
        surface.supplementalFrameDemand = { demands += 1; return true }
        surface.onAnimationFrame = { _ in telemetry += 1 }
        surface.refreshFrameDemand()
        let queries = demands
        surface.teardown()
        surface.teardown()
        surface.simulateFrame(deltaTime: frameTime)
        surface.refreshFrameDemand()
        XCTAssertNil(surface.supplementalFrameStep)
        XCTAssertNil(surface.supplementalFrameDemand)
        XCTAssertNil(surface.frameDriver)
        XCTAssertFalse(driver.isRunning)
        XCTAssertEqual(demands, queries)
        XCTAssertEqual(steps, 0)
        XCTAssertEqual(telemetry, 0)
    }

    func testTelemetryTeardownSkipsSupplementalAdvancement() {
        let (surface, driver) = makeSharedSurface()
        defer { surface.teardown() }
        var steps = 0
        surface.supplementalFrameStep = { _ in steps += 1 }
        surface.supplementalFrameDemand = { true }
        surface.onAnimationFrame = { [weak surface] _ in surface?.teardown() }
        XCTAssertTrue(surface.requestPage(1, timestamp: 0))
        surface.simulateFrame(deltaTime: frameTime)
        XCTAssertTrue(surface.isTearingDown)
        XCTAssertEqual(steps, 0)
        XCTAssertFalse(driver.isRunning)
    }

    func testGridTickTeardownSkipsSupplementalAdvancement() {
        let (surface, driver) = makeSharedSurface()
        defer { surface.teardown() }
        var steps = 0
        surface.supplementalFrameStep = { _ in steps += 1 }
        surface.supplementalFrameDemand = { true }
        XCTAssertTrue(surface.requestPage(1, timestamp: 0))
        surface.appEvents.onVisualOffsetChange = { [weak surface] _ in surface?.teardown() }
        surface.simulateFrame(deltaTime: frameTime)
        XCTAssertTrue(surface.isTearingDown)
        XCTAssertEqual(steps, 0)
        XCTAssertFalse(driver.isRunning)
    }

    func testReleaseCompletionTeardownSkipsRemainingFrameCallbacks() {
        let (surface, driver) = makeSharedSurface()
        defer { surface.teardown() }
        var now: TimeInterval = 100
        var callbacks = 0
        surface.pendingFinishTimeSource = { now }
        surface.onAnimationFrame = { _ in callbacks += 1 }
        surface.supplementalFrameStep = { _ in callbacks += 1 }
        surface.supplementalFrameDemand = { true }
        surface.appEvents.onTransitionBegin = { [weak surface] _ in surface?.teardown() }
        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 500, at: 0.5)
        gestureEnded(surface, at: 0.6)
        now = 100.101
        surface.simulateFrame(deltaTime: frameTime)
        XCTAssertTrue(surface.isTearingDown)
        XCTAssertEqual(callbacks, 0)
        XCTAssertFalse(driver.isRunning)
    }

    func testSupplementalTeardownDoesNotQueryDemandAgain() {
        let (surface, driver) = makeSharedSurface()
        defer { surface.teardown() }
        var demands = 0
        surface.supplementalFrameDemand = { demands += 1; return true }
        surface.supplementalFrameStep = { _ in surface.teardown() }
        surface.refreshFrameDemand()
        let queries = demands
        surface.simulateFrame(deltaTime: frameTime)
        XCTAssertEqual(demands, queries)
        XCTAssertNil(surface.supplementalFrameStep)
        XCTAssertNil(surface.supplementalFrameDemand)
        XCTAssertFalse(driver.isRunning)
    }

    func testDemandCallbackTeardownCannotRestartDriver() {
        let (surface, driver) = makeSharedSurface()
        defer { surface.teardown() }
        surface.supplementalFrameDemand = { true }
        surface.refreshFrameDemand()
        surface.supplementalFrameDemand = { surface.teardown(); return true }
        surface.refreshFrameDemand()
        XCTAssertTrue(surface.isTearingDown)
        XCTAssertFalse(driver.isRunning)
        XCTAssertEqual(driver.starts, 1)
        XCTAssertNil(surface.frameDriver)
    }

    private func makeSharedSurface(initialPage: Int = 0) -> (PagingSurface, FrameDriver) {
        let surface = makeSurface(initialPage: initialPage)
        let driver = FrameDriver()
        surface.frameDriver = driver
        return (surface, driver)
    }

    private func makeManualParent(parameters: PagingParameters? = nil,
                                  reduceMotion: Bool = false) -> FolderPagingController {
        let parent = FolderPagingController()
        parent.automaticallyDrivesFrames = false
        parent.configure(pageCount: 2, pageWidth: 1000, currentPage: 0, reduceMotion: reduceMotion,
                         parameters: parameters)
        return parent
    }

    private func send(_ parent: FolderPagingController, phase: NSEvent.Phase,
                      x: CGFloat = 0, at timestamp: TimeInterval) {
        parent.handleScroll(phase: phase, momentumPhase: [], deltaX: x, deltaY: 0,
                            isDirectionInverted: true, timestamp: timestamp)
    }
}
