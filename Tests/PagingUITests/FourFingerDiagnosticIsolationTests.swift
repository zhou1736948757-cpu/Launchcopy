import AppKit
import Darwin
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class FourFingerDiagnosticIsolationTests: XCTestCase {
    private func composition(clock: FakePinchClock) -> ActivationComposition {
        _ = NSApplication.shared
        // Pure visible state ensures recognizer events cannot order a native window.
        let launcher = LauncherWindowController(coordinator: .init(initialState: .visible(screenID: ScreenID(index: 0))),
            reduceMotionProvider: { true })
        let result = ActivationComposition(launcher: launcher, pinchClock: clock)
        result.attachTouchProvider(MockTouchProvider(clock: clock), userEnabled: true)
        return result
    }

    private func recognize(_ composition: ActivationComposition, clock: FakePinchClock) {
        for (time, phase, size) in [(0.0, PinchFramePhase.began, 0.2), (0.1, .moved, 0.2), (0.11, .moved, 0.16)] {
            clock.current = time
            _ = composition.processFourFingerFrame(PinchFrame(deviceID: PinchDeviceID(rawValue: 1),
                timestamp: time, phase: phase, contacts: squareContacts(halfSize: size)))
        }
    }

    private func captureOutput(_ body: () -> Void) throws -> String {
        let pipe = Pipe()
        let saved = dup(STDOUT_FILENO)
        guard saved >= 0 else { throw NSError(domain: "SyntheticCapture", code: 1) }
        defer { close(saved) }
        fflush(stdout)
        guard dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO) >= 0 else {
            throw NSError(domain: "SyntheticCapture", code: 2)
        }
        body()
        fflush(stdout)
        XCTAssertGreaterThanOrEqual(dup2(saved, STDOUT_FILENO), 0)
        pipe.fileHandleForWriting.closeFile()
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }

    func testDefaultSyntheticRecognitionDoesNotWriteDiagnosticStdout() throws {
        let clock = FakePinchClock()
        let current = composition(clock: clock)
        defer { current.teardownActivationServices() }
        let output = try captureOutput { recognize(current, clock: clock) }
        XCTAssertEqual(current.fourFinger?.recognizer.state, .fired)
        XCTAssertNil(current.launcher.window)
        XCTAssertFalse(output.contains("paging-fourfinger-"), "Diagnostics must be explicitly enabled")
    }

    private final class LifetimeProbe {
        weak var owner: ActivationComposition?
        weak var diagnostics: FourFingerDiagnostics?
    }

    private final class Scheduler {
        var ticks: [FourFingerDiagnostics.Tick] = []
        var timers: [Timer] = []
        func make(_ tick: @escaping FourFingerDiagnostics.Tick) -> Timer {
            ticks.append(tick)
            // Unscheduled timers model lifecycle without native RunLoop/device polling.
            let timer = Timer(timeInterval: 2, repeats: true) { _ in
                MainActor.assumeIsolated { tick() }
            }
            timers.append(timer)
            return timer
        }
    }

    func testDisabledDiagnosticsCreatesNoTimerOrSinkAndRecognitionStaysLive() {
        let clock = FakePinchClock(), scheduler = Scheduler()
        let owner = composition(clock: clock)
        defer { owner.teardownActivationServices() }
        var messages: [String] = []
        let diagnostics = FourFingerDiagnostics(enabled: false, sink: { messages.append($0) }, makeTimer: scheduler.make)
        diagnostics.start(for: owner)
        recognize(owner, clock: clock)
        XCTAssertEqual(owner.fourFinger?.recognizer.state, .fired)
        XCTAssertNil(owner.onFourFingerDiagnostic)
        XCTAssertNil(owner.launcher.window)
        XCTAssertTrue(scheduler.timers.isEmpty)
        XCTAssertTrue(messages.isEmpty)
        diagnostics.stop()
    }

    func testOptInSyntheticRecognitionReportsNeutralCountsWithoutOrderingWindow() {
        let clock = FakePinchClock(), scheduler = Scheduler()
        let owner = composition(clock: clock)
        defer { owner.teardownActivationServices() }
        var messages: [String] = []
        let diagnostics = FourFingerDiagnostics(enabled: true, sink: { messages.append($0) }, makeTimer: scheduler.make)
        defer { diagnostics.stop() }
        diagnostics.start(for: owner)
        recognize(owner, clock: clock)
        XCTAssertEqual(messages.count, 1)
        XCTAssertTrue(messages[0].hasPrefix("paging-fourfinger-show: events=1"))
        XCTAssertFalse(messages[0].contains("fixture"))
        XCTAssertFalse(messages[0].contains("/"))
        XCTAssertEqual(owner.fourFinger?.recognizer.state, .fired)
        XCTAssertNil(owner.launcher.window)
        XCTAssertEqual(scheduler.timers.count, 1)
    }

    func testReplacementAndStopRejectRetainedTicksAndCallback() throws {
        let scheduler = Scheduler()
        let first = composition(clock: FakePinchClock()), second = composition(clock: FakePinchClock())
        defer { first.teardownActivationServices(); second.teardownActivationServices() }
        var messages: [String] = []
        let diagnostics = FourFingerDiagnostics(enabled: true, sink: { messages.append($0) }, makeTimer: scheduler.make)
        diagnostics.start(for: first)
        let oldCallback = try XCTUnwrap(first.onFourFingerDiagnostic)
        let oldTick = try XCTUnwrap(scheduler.ticks.first)
        diagnostics.start(for: second)
        let currentCallback = try XCTUnwrap(second.onFourFingerDiagnostic)
        XCTAssertNil(first.onFourFingerDiagnostic)
        XCTAssertFalse(scheduler.timers[0].isValid)
        oldCallback("obsolete"); oldTick()
        XCTAssertTrue(messages.isEmpty)
        XCTAssertTrue(scheduler.timers[1].isValid)
        currentCallback("neutral")
        XCTAssertEqual(messages, ["neutral"])
        diagnostics.stop(); diagnostics.stop()
        XCTAssertNil(second.onFourFingerDiagnostic)
        XCTAssertFalse(scheduler.timers[1].isValid)
        currentCallback("late"); scheduler.ticks[1]()
        XCTAssertEqual(messages, ["neutral"])
    }

    func testOptInFakeBackendSamplingStopsAfterBackendStop() {
        let scheduler = Scheduler(), clock = FakePinchClock()
        let owner = composition(clock: clock)
        defer { owner.teardownActivationServices() }
        let device = FakeMultitouchDevice()
        let backend = MultitouchSupportBackend(deliveryMode: .synchronous,
            libraryFactory: { FakeMultitouchLibrary(devices: [device]) })
        owner.attachTouchProvider(backend, userEnabled: true)
        XCTAssertTrue(backend.isStarted)
        var messages: [String] = []
        let diagnostics = FourFingerDiagnostics(enabled: true, sink: { messages.append($0) }, makeTimer: scheduler.make)
        diagnostics.start(for: owner)
        scheduler.ticks[0]()
        XCTAssertEqual(messages.count, 1)
        XCTAssertTrue(messages[0].hasPrefix("paging-fourfinger-tick: raw=0 delivered=0 rejected=0"))
        XCTAssertTrue(scheduler.timers[0].isValid)
        backend.stop(); scheduler.ticks[0]()
        XCTAssertEqual(messages.count, 2)
        XCTAssertFalse(scheduler.timers[0].isValid)
        XCTAssertNil(owner.onFourFingerDiagnostic)
        scheduler.ticks[0]()
        XCTAssertEqual(messages.count, 2)
    }

    func testMissingBackendStopsTimerWithoutSamplingMockOrChangingState() {
        let scheduler = Scheduler(), owner = composition(clock: FakePinchClock())
        defer { owner.teardownActivationServices() }
        var messages: [String] = []
        let diagnostics = FourFingerDiagnostics(enabled: true, sink: { messages.append($0) }, makeTimer: scheduler.make)
        let state = owner.fourFinger?.displayStatus
        diagnostics.start(for: owner)
        scheduler.ticks[0]()
        XCTAssertTrue(messages.isEmpty)
        XCTAssertNil(diagnostics.timer)
        XCTAssertFalse(scheduler.timers[0].isValid)
        XCTAssertNil(owner.onFourFingerDiagnostic)
        XCTAssertEqual(owner.fourFinger?.displayStatus, state)
    }

    func testDiagnosticDeallocationInvalidatesTimerAndLateCallbackCannotRetainOwner() throws {
        let scheduler = Scheduler()
        var owner: ActivationComposition? = composition(clock: FakePinchClock())
        let lifetime = LifetimeProbe()
        lifetime.owner = owner
        var messages: [String] = []
        var diagnostics: FourFingerDiagnostics? = FourFingerDiagnostics(enabled: true,
            sink: { messages.append($0) }, makeTimer: scheduler.make)
        lifetime.diagnostics = diagnostics
        diagnostics?.start(for: try XCTUnwrap(owner))
        let callback = try XCTUnwrap(owner?.onFourFingerDiagnostic)
        diagnostics = nil
        XCTAssertNil(lifetime.diagnostics)
        XCTAssertFalse(scheduler.timers[0].isValid)
        callback("late"); scheduler.ticks[0]()
        XCTAssertTrue(messages.isEmpty)
        owner?.teardownActivationServices(); owner = nil
        XCTAssertNil(lifetime.owner)
    }
}
