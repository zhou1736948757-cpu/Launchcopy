import AppKit
import XCTest
@testable import PagingPrototypeApp

/// Pure visible presentation state; no native windows, real devices or registration.
@MainActor
final class FourFingerOutwardHideCompositionTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let clock = FakePinchClock()
        let launcher: LauncherWindowController
        let composition: ActivationComposition
        let provider: MockTouchProvider
        var allowed = true
        init(mode: Bool = true, installHost: Bool = true) {
            _ = NSApplication.shared
            launcher = LauncherWindowController(coordinator: .init(initialState: .visible(screenID: .init(index: 0))),
                                                reduceMotionProvider: { true })
            composition = ActivationComposition(launcher: launcher, pinchClock: clock)
            provider = MockTouchProvider(clock: clock)
            composition.attachTouchProvider(provider, userEnabled: true)
            composition.applyPreferences(.init(fourFingerActivationEnabled: true, fourFingerOutwardHideEnabled: mode))
            if installHost { composition.canHideFromFourFinger = { [weak self] in self?.allowed == true } }
        }
        @discardableResult
        func send(_ time: Double, _ phase: PinchFramePhase, _ size: Double) -> [LauncherPresentationEffect] {
            clock.current = time
            return composition.processFourFingerFrame(frame(.init(rawValue: 1), time, phase,
                phase == .ended ? [] : squareContacts(halfSize: size)))
        }
        func teardown() { composition.teardownActivationServices() }
    }

    func testOutwardUsesResidentHideWithoutCreatingWindowOrQuitting() {
        let f = Fixture(); defer { f.teardown() }
        var preparations = 0
        f.composition.onPrepareHide = { preparations += 1 }
        XCTAssertTrue(f.send(0, .began, 0.2).isEmpty)
        let effects = f.send(0.1, .moved, 0.25)
        XCTAssertEqual(effects.count, 1)
        guard let effect = effects.first, case .dismiss(_, .fourFingerOutward, .fourFingerPinch) = effect else {
            return XCTFail("Expected resident outward Hide")
        }
        XCTAssertEqual(f.launcher.coordinator.state, .hidden)
        XCTAssertNil(f.launcher.window)
        XCTAssertEqual(preparations, 1)
        XCTAssertEqual(f.composition.terminateRequestCount, 0)
        XCTAssertEqual(f.composition.activationTeardownCount, 0)
        XCTAssertTrue(f.send(0.2, .moved, 0.12).isEmpty, "One action, even after direction reversal")
    }

    func testDisabledOrMissingHostNeverHides() {
        for f in [Fixture(mode: false), Fixture(installHost: false)] {
            defer { f.teardown() }
            _ = f.send(0, .began, 0.2)
            XCTAssertTrue(f.send(0.1, .moved, 0.25).isEmpty)
            XCTAssertEqual(f.launcher.coordinator.state, .visible(screenID: .init(index: 0)))
        }
    }

    func testBlockedStartCannotHideWhenHostLaterBecomesIdleUntilFreshSession() {
        let f = Fixture(); defer { f.teardown() }
        f.allowed = false
        _ = f.send(0, .began, 0.2)
        f.allowed = true
        XCTAssertTrue(f.send(0.1, .moved, 0.25).isEmpty)
        _ = f.send(0.2, .ended, 0)
        _ = f.send(1, .began, 0.2)
        XCTAssertFalse(f.send(1.1, .moved, 0.25).isEmpty)
        XCTAssertEqual(f.launcher.coordinator.state, .hidden)
    }

    func testAnyBusyFrameRevokesOutwardAdmissionForEntireHeldSession() {
        let f = Fixture(); defer { f.teardown() }
        _ = f.send(0, .began, 0.2)
        f.allowed = false
        _ = f.send(0.05, .moved, 0.21)
        f.allowed = true
        XCTAssertTrue(f.send(0.1, .moved, 0.25).isEmpty)
        XCTAssertEqual(f.launcher.coordinator.state, .visible(screenID: .init(index: 0)))
    }

    func testReentrantModeDisableDuringCleanupRevokesAlreadyRecognizedHide() {
        let f = Fixture(); defer { f.teardown() }
        f.composition.onPrepareHide = {
            f.composition.applyPreferences(.init(fourFingerActivationEnabled: true,
                                                 fourFingerOutwardHideEnabled: false))
        }
        _ = f.send(0, .began, 0.2)
        XCTAssertEqual(f.send(0.1, .moved, 0.25), [.none])
        XCTAssertEqual(f.launcher.coordinator.state, .visible(screenID: .init(index: 0)))
        XCTAssertEqual(f.composition.terminateRequestCount, 0)
    }

    func testReentrantProviderReplacementDuringCleanupCannotHideNewOwner() {
        let f = Fixture(); defer { f.teardown() }
        let replacement = MockTouchProvider(clock: f.clock)
        f.composition.onPrepareHide = { f.composition.attachTouchProvider(replacement, userEnabled: true) }
        _ = f.send(0, .began, 0.2)
        XCTAssertEqual(f.send(0.1, .moved, 0.25), [.none])
        XCTAssertTrue(f.composition.touchProvider === replacement)
        XCTAssertEqual(f.launcher.coordinator.state, .visible(screenID: .init(index: 0)))
    }

    func testOldProviderCallbacksCannotEnterReplacementRecognizer() throws {
        let f = Fixture(); defer { f.teardown() }
        let oldFrame = try XCTUnwrap(f.provider.onFrame)
        let oldState = try XCTUnwrap(f.provider.onStateChange)
        let replacement = MockTouchProvider(clock: f.clock)
        f.composition.attachTouchProvider(replacement, userEnabled: true)
        let generation = f.composition.fourFinger?.recognizer.generation
        oldFrame(frame(.init(rawValue: 1), 0, .began, squareContacts(halfSize: 0.2)))
        oldFrame(frame(.init(rawValue: 1), 0, .moved, squareContacts(halfSize: 0.25)))
        oldState(.unavailable)
        XCTAssertEqual(f.composition.fourFinger?.recognizer.generation, generation)
        XCTAssertEqual(f.composition.fourFinger?.recognizer.state, .idle)
        XCTAssertEqual(f.composition.fourFinger?.activation.state, .ready)
        XCTAssertEqual(f.launcher.coordinator.state, .visible(screenID: .init(index: 0)))
    }

    func testPlainModeChangeDoesNotRestartProviderAndParentOffRetainsChoice() {
        let f = Fixture(mode: false); defer { f.teardown() }
        let generation = f.provider.generation
        f.composition.applyPreferences(.init(fourFingerActivationEnabled: true, fourFingerOutwardHideEnabled: true))
        XCTAssertEqual(f.provider.generation, generation)
        XCTAssertTrue(f.composition.touchProvider === f.provider)
        f.composition.applyPreferences(.init(fourFingerActivationEnabled: false, fourFingerOutwardHideEnabled: true))
        XCTAssertTrue(f.composition.appliedPlan.fourFingerOutwardHideEnabled)
        XCTAssertFalse(f.provider.isStarted)
        XCTAssertTrue(f.send(0, .began, 0.2).isEmpty)
        XCTAssertTrue(f.send(0.1, .moved, 0.25).isEmpty)
    }

    func testReentrantReadinessChangeCannotOverwriteNewRecognizerGeneration() {
        let f = Fixture(); defer { f.teardown() }
        f.composition.canHideFromFourFinger = {
            f.composition.applyPreferences(.init(fourFingerActivationEnabled: true,
                                                 fourFingerOutwardHideEnabled: false))
            return true
        }
        let before = f.composition.fourFinger?.recognizer.generation
        XCTAssertTrue(f.send(0, .began, 0.2).isEmpty)
        XCTAssertNotEqual(f.composition.fourFinger?.recognizer.generation, before)
        XCTAssertFalse(f.composition.appliedPlan.fourFingerOutwardHideEnabled)
    }

    func testTeardownCannotBeReactivatedByPreferencesOrNewProvider() {
        let f = Fixture()
        f.teardown()
        let replacement = MockTouchProvider(clock: f.clock)
        f.composition.attachTouchProvider(replacement, userEnabled: true)
        f.composition.applyPreferences(.init(fourFingerActivationEnabled: true, fourFingerOutwardHideEnabled: true))
        XCTAssertFalse(replacement.isStarted)
        XCTAssertNil(f.composition.fourFinger)
        XCTAssertFalse(f.composition.appliedPlan.fourFingerEnabled)
        XCTAssertTrue(f.send(0, .began, 0.2).isEmpty)
    }

    func testServicePlanDiffAppliesAndRollsBackOptionalChoiceIncludingParentOff() {
        for parent in [false, true] {
            let original = ActivationServicePlan(fourFingerEnabled: parent)
            let desired = ActivationServicePlan(fourFingerEnabled: parent, fourFingerOutwardHideEnabled: true)
            let forward = ActivationServicePlanDiff.transitions(from: original, to: desired)
            XCTAssertEqual(forward, [.setFourFingerOutwardHide(enabled: true)])
            var state = original
            for transition in forward { state.apply(transition) }
            XCTAssertEqual(state, desired)
            for transition in ActivationServicePlanDiff.rollback(from: desired, to: original) { state.apply(transition) }
            XCTAssertEqual(state, original)
        }
    }
    func testProductionParentStopStartRequiresReleaseOfHeldContacts() {
        let f = Fixture(); defer { f.teardown() }
        f.send(0, .began, 0.2)
        f.composition.applyPreferences(.init(fourFingerActivationEnabled: false, fourFingerOutwardHideEnabled: true))
        f.composition.applyPreferences(.init(fourFingerActivationEnabled: true, fourFingerOutwardHideEnabled: true))
        XCTAssertTrue(f.provider.isStarted)
        XCTAssertTrue(f.send(0.1, .moved, 0.2).isEmpty)
        XCTAssertTrue(f.send(0.2, .moved, 0.3).isEmpty)
        XCTAssertEqual(f.launcher.coordinator.state, .visible(screenID: .init(index: 0)))
        f.send(0.3, .ended, 0)
        f.send(0.4, .began, 0.2)
        XCTAssertEqual(f.send(0.5, .moved, 0.25).count, 1)
        XCTAssertEqual(f.launcher.coordinator.state, .hidden)
    }

    private final class FrameDelivery: @unchecked Sendable {
        let callback: (PinchFrame) -> Void
        init(_ callback: @escaping (PinchFrame) -> Void) { self.callback = callback }
        func enqueue(_ frames: [PinchFrame]) {
            let enqueued = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                for frame in frames { self.callback(frame) }
                enqueued.signal()
            }
            XCTAssertEqual(enqueued.wait(timeout: .now() + 2), .success)

        }
    }

    func testSameProviderQueuedFramesCannotAcquireModeOrParentRestartGeneration() async throws {
        for restartParent in [false, true] {
            let f = Fixture(mode: restartParent); defer { f.teardown() }
            let delivery = FrameDelivery(try XCTUnwrap(f.provider.onFrame))
            let device = PinchDeviceID(rawValue: 1)
            f.clock.current = 0.1
            delivery.enqueue([
                frame(device, 0, .began, squareContacts(halfSize: 0.2)),
                frame(device, 0.1, .moved, squareContacts(halfSize: 0.25))
            ])
            // Main actor has not yielded: both old frames really are queued.
            XCTAssertEqual(f.composition.fourFinger?.recognizer.fireCount, 0)
            if restartParent {
                f.composition.applyPreferences(.init(fourFingerActivationEnabled: false, fourFingerOutwardHideEnabled: true))
            }
            f.composition.applyPreferences(.init(fourFingerActivationEnabled: true, fourFingerOutwardHideEnabled: true))
            let drained = expectation(description: "Queued provider callbacks drained")
            DispatchQueue.main.async { drained.fulfill() }
            await fulfillment(of: [drained], timeout: 2)
            XCTAssertEqual(f.launcher.coordinator.state, .visible(screenID: .init(index: 0)))
            XCTAssertEqual(f.composition.fourFinger?.recognizer.fireCount, 0)
            XCTAssertTrue(f.send(0.2, .moved, 0.2).isEmpty)
            XCTAssertTrue(f.send(0.3, .moved, 0.3).isEmpty, "Dropped first contacts still require release")
            f.send(0.4, .ended, 0)
            f.send(0.5, .began, 0.2)
            XCTAssertEqual(f.send(0.6, .moved, 0.25).count, 1)
        }
    }

    func testOptionalCompositionPreservesSourceTimeValidationAndReleaseQuarantine() {
        let invalidTimes: [Double] = [.nan, .infinity, -1, 0.05, 0.3]
        for timestamp in invalidTimes {
            let f = Fixture(); defer { f.teardown() }
            f.send(0.1, .began, 0.2)
            f.clock.current = 0.2
            let generation = f.composition.fourFinger?.recognizer.generation ?? 0
            XCTAssertTrue(f.composition.processFourFingerFrame(frame(.init(rawValue: 1), timestamp,
                .moved, squareContacts(halfSize: 0.25))).isEmpty)
            if timestamp < 0 {
                XCTAssertGreaterThan(f.composition.fourFinger?.recognizer.generation ?? 0, generation,
                                     "Pre-mode input is fenced before recognition")
            } else {
                XCTAssertGreaterThan(f.composition.fourFinger?.recognizer.rejectedFrameCount ?? 0, 0)
            }
            XCTAssertTrue(f.send(0.3, .moved, 0.3).isEmpty)
            XCTAssertEqual(f.launcher.coordinator.state, .visible(screenID: .init(index: 0)))
            f.send(0.4, .ended, 0)
            f.send(0.5, .began, 0.2)
            XCTAssertEqual(f.send(0.6, .moved, 0.25).count, 1)
        }
    }

    func testQueuedExpiredBaselineCannotHideAfterMainQueueRecovers() async throws {
        let f = Fixture(); defer { f.teardown() }
        let delivery = FrameDelivery(try XCTUnwrap(f.provider.onFrame))
        f.clock.current = 1
        delivery.enqueue([
            frame(.init(rawValue: 1), 0, .began, squareContacts(halfSize: 0.2)),
            frame(.init(rawValue: 1), 0.1, .moved, squareContacts(halfSize: 0.25))
        ])
        let drained = expectation(description: "Expired queued frames drained")
        DispatchQueue.main.async { drained.fulfill() }
        await fulfillment(of: [drained], timeout: 2)
        XCTAssertEqual(f.launcher.coordinator.state, .visible(screenID: .init(index: 0)))
        XCTAssertEqual(f.composition.fourFinger?.recognizer.fireCount, 0)
        XCTAssertGreaterThan(f.composition.fourFinger?.recognizer.rejectedFrameCount ?? 0, 0)
        XCTAssertTrue(f.send(1.1, .moved, 0.2).isEmpty)
        XCTAssertTrue(f.send(1.2, .moved, 0.3).isEmpty)
        f.send(1.3, .ended, 0)
        f.send(1.4, .began, 0.2)
        XCTAssertEqual(f.send(1.5, .moved, 0.25).count, 1)
    }

    func testProviderBufferedBeforeModeEditCannotCreateFreshSessionAfterEdit() {
        let f = Fixture(mode: false); defer { f.teardown() }
        f.clock.current = 0.2
        f.composition.applyPreferences(.init(fourFingerActivationEnabled: true, fourFingerOutwardHideEnabled: true))
        // Still younger than expiry, but captured before this opt-in mode existed.
        XCTAssertTrue(f.composition.processFourFingerFrame(frame(.init(rawValue: 1), 0.1,
            .began, squareContacts(halfSize: 0.2))).isEmpty)
        XCTAssertTrue(f.send(0.3, .moved, 0.25).isEmpty)
        XCTAssertEqual(f.launcher.coordinator.state, .visible(screenID: .init(index: 0)))
        f.send(0.4, .ended, 0)
        f.send(0.5, .began, 0.2)
        XCTAssertEqual(f.send(0.6, .moved, 0.25).count, 1)
    }

    func testTurningOptionalOffCannotAcceptOldReleaseOrBufferedContacts() {
        for establishedBaseline in [false, true] {
            let f = Fixture(); defer { f.teardown() }
            if establishedBaseline { f.send(0.2, .began, 0.2) }
            f.clock.current = 0.3
            f.composition.applyPreferences(.init(fourFingerActivationEnabled: true, fourFingerOutwardHideEnabled: false))
            if !establishedBaseline {
                XCTAssertTrue(f.composition.processFourFingerFrame(frame(.init(rawValue: 1), 0.2,
                    .began, squareContacts(halfSize: 0.2))).isEmpty)
            }
            f.clock.current = 0.4
            XCTAssertTrue(f.composition.processFourFingerFrame(frame(.init(rawValue: 1), 0.1, .ended, [])).isEmpty)
            XCTAssertTrue(f.send(0.5, .moved, 0.2).isEmpty)
            XCTAssertTrue(f.send(0.6, .moved, 0.1).isEmpty)
            XCTAssertEqual(f.composition.fourFinger?.showCount, 0, "An old release cannot rearm inward Show")
            f.send(0.7, .ended, 0)
            f.send(0.8, .began, 0.2)
            f.send(0.9, .moved, 0.1)
            XCTAssertEqual(f.composition.fourFinger?.showCount, 1)
        }
    }

}
