import XCTest
@testable import PagingPrototypeApp

/// Only the pure coordinator is exercised. Hide window effects belong to composition tests.
final class FourFingerOutwardHideCoordinatorTests: XCTestCase {
    private let screen = ScreenID(index: 0)
    private let device = PinchDeviceID(rawValue: 51)

    private func makeCoordinator(_ clock: FakePinchClock,
                                 visible: Bool = true) -> FourFingerActivationCoordinator {
        var coordinator = FourFingerActivationCoordinator(
            clock: clock, targetScreen: screen, parameters: PinchParameters(cooldown: 0), userEnabled: true)
        coordinator.setOutwardHideEnabled(true)
        coordinator.start()
        coordinator.handleProviderState(.ready)
        if visible { coordinator.adoptPresentation(LauncherPresentationCoordinator(initialState: .visible(screenID: screen))) }
        return coordinator
    }

    private func token(_ coordinator: FourFingerActivationCoordinator, _ session: Int = 1) -> PinchEventToken {
        PinchEventToken(generation: coordinator.recognizer.generation, sessionID: PinchSessionID(rawValue: session))
    }

    @discardableResult
    private func deliver(_ coordinator: inout FourFingerActivationCoordinator, _ clock: FakePinchClock,
                         _ time: TimeInterval, _ size: Double, allow: Bool = true,
                         deviceID: PinchDeviceID? = nil) -> [PinchEvent] {
        clock.current = time
        return coordinator.process(frame(deviceID ?? device, time, .moved, squareContacts(halfSize: size)),
                                   allowOutwardHide: allow)
    }

    private func release(_ coordinator: inout FourFingerActivationCoordinator, _ clock: FakePinchClock,
                         _ time: TimeInterval, deviceID: PinchDeviceID? = nil) {
        clock.current = time
        _ = coordinator.process(frame(deviceID ?? device, time, .ended, []))
    }

    func testHideFlushAcceptsTokenWithoutMutatingPresentationAndShowFlushIsSeparate() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock)
        let presentation = coordinator.presentation
        deliver(&coordinator, clock, 0, 0.2)
        let events = deliver(&coordinator, clock, 0.1, 0.24)
        guard case .hideRequested(let requested)? = events.first else { return XCTFail("Expected Hide") }
        XCTAssertEqual(coordinator.pendingHideTokens, [requested])
        XCTAssertEqual(coordinator.flushPendingShows(), [])
        XCTAssertEqual(coordinator.pendingHideTokens, [requested])
        XCTAssertTrue(coordinator.flushPendingHides(allowHide: true))
        XCTAssertEqual(coordinator.lastAcceptedHideToken, requested)
        XCTAssertEqual(coordinator.lastConsumedToken, requested)
        XCTAssertEqual(coordinator.handoffToken, requested)
        XCTAssertEqual(coordinator.hideCount, 1)
        XCTAssertEqual(coordinator.showCount, 0)
        XCTAssertEqual(coordinator.presentation, presentation)
        XCTAssertTrue(coordinator.pendingHideTokens.isEmpty)
        XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
        XCTAssertNil(coordinator.lastAcceptedHideToken)
        XCTAssertEqual(coordinator.presentation, presentation)
    }

    func testFlushRefusalConsumesTokenAndCannotReplayEitherDirection() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock)
        let request = token(coordinator)
        coordinator.handlePinchEvent(.hideRequested(token: request))
        XCTAssertFalse(coordinator.flushPendingHides(allowHide: false))
        XCTAssertTrue(coordinator.pendingHideTokens.isEmpty)
        XCTAssertNil(coordinator.lastAcceptedHideToken)
        coordinator.handlePinchEvent(.hideRequested(token: request))
        XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
        coordinator.handlePinchEvent(.showRequested(token: request))
        XCTAssertEqual(coordinator.flushPendingShows(), [.none])
        XCTAssertEqual(coordinator.hideCount, 0)
        XCTAssertEqual(coordinator.showCount, 0)
        XCTAssertEqual(coordinator.presentation.state, .visible(screenID: screen))
    }

    func testAcceptedShowThenHideAndHideThenShowShareConsumption() {
        for showFirst in [true, false] {
            let clock = FakePinchClock()
            var coordinator = makeCoordinator(clock)
            let request = token(coordinator)
            if showFirst {
                coordinator.handlePinchEvent(.showRequested(token: request))
                XCTAssertEqual(coordinator.flushPendingShows(), [.none])
                coordinator.handlePinchEvent(.hideRequested(token: request))
                XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
            } else {
                coordinator.handlePinchEvent(.hideRequested(token: request))
                XCTAssertTrue(coordinator.flushPendingHides(allowHide: true))
                coordinator.handlePinchEvent(.showRequested(token: request))
                XCTAssertEqual(coordinator.flushPendingShows(), [.none])
            }
            XCTAssertEqual(coordinator.showCount + coordinator.hideCount, 1)
            XCTAssertEqual(coordinator.droppedDuplicateEventCount, 1)
        }
    }

    func testMultiplePendingHidesAcceptAtMostOneAndPreserveAcceptedToken() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock)
        let first = token(coordinator)
        let second = token(coordinator, 2)
        coordinator.handlePinchEvent(.hideRequested(token: first))
        coordinator.handlePinchEvent(.hideRequested(token: first))
        coordinator.handlePinchEvent(.hideRequested(token: second))
        let before = coordinator.presentation
        XCTAssertTrue(coordinator.flushPendingHides(allowHide: true))
        XCTAssertEqual(coordinator.hideCount, 1)
        XCTAssertEqual(coordinator.lastAcceptedHideToken, first)
        XCTAssertEqual(coordinator.lastConsumedToken, first)
        XCTAssertEqual(coordinator.handoffToken, first)
        XCTAssertEqual(coordinator.presentation, before)
        coordinator.handlePinchEvent(.hideRequested(token: second))
        XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
    }

    func testHideQueueIsBoundedAndOverflowNeverChangesPresentation() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock)
        let before = coordinator.presentation
        for session in 1...64 {
            coordinator.handlePinchEvent(.hideRequested(token: token(coordinator, session)))
        }
        XCTAssertEqual(coordinator.pendingHideTokens.count, FourFingerActivationCoordinator.maxPendingHideTokens)
        XCTAssertGreaterThan(coordinator.suppressedHideCount, 0)
        _ = coordinator.flushPendingHides(allowHide: true)
        XCTAssertLessThanOrEqual(coordinator.hideCount, 1)
        XCTAssertTrue(coordinator.pendingHideTokens.isEmpty)
        XCTAssertEqual(coordinator.presentation, before)
        for session in 1...64 {
            coordinator.handlePinchEvent(.hideRequested(token: token(coordinator, session)))
            XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
        }
    }

    func testVisibilityAndHostAdmissionAreSampledFromFirstContactAndRemainSticky() {
        for blockedByVisibility in [true, false] {
            let clock = FakePinchClock()
            var coordinator = makeCoordinator(clock, visible: !blockedByVisibility)
            clock.current = 0
            _ = coordinator.process(frame(device, 0, .began, Array(squareContacts(halfSize: 0.2).prefix(2))),
                                    allowOutwardHide: blockedByVisibility)
            coordinator.adoptPresentation(LauncherPresentationCoordinator(initialState: .visible(screenID: screen)))
            deliver(&coordinator, clock, 0.1, 0.2)
            XCTAssertEqual(deliver(&coordinator, clock, 0.2, 0.24), [])
            XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
            release(&coordinator, clock, 0.3)
            deliver(&coordinator, clock, 0.4, 0.2)
            XCTAssertEqual(deliver(&coordinator, clock, 0.5, 0.24).count, 1)
            XCTAssertTrue(coordinator.flushPendingHides(allowHide: true))
        }
    }

    func testTransientHostRefusalAfterRequestDiscardsPendingHidePermanently() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock)
        deliver(&coordinator, clock, 0, 0.2)
        deliver(&coordinator, clock, 0.1, 0.24)
        guard let request = coordinator.pendingHideTokens.first else { return XCTFail("Expected pending Hide") }
        deliver(&coordinator, clock, 0.2, 0.25, allow: false)
        deliver(&coordinator, clock, 0.3, 0.26)
        XCTAssertTrue(coordinator.pendingHideTokens.isEmpty)
        XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
        coordinator.handlePinchEvent(.hideRequested(token: request))
        XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
    }

    func testMalformedFrameAfterRequestDiscardsPendingHide() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock)
        deliver(&coordinator, clock, 0, 0.2)
        deliver(&coordinator, clock, 0.1, 0.24)
        clock.current = 0.2
        var contacts = squareContacts(halfSize: 0.25)
        contacts[0].position.x = .nan
        XCTAssertEqual(coordinator.process(frame(device, 0.2, .moved, contacts)), [])
        XCTAssertTrue(coordinator.pendingHideTokens.isEmpty)
        XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
    }

    func testEveryNonvisiblePresentationRefusesAndCannotReplayAfterBecomingVisible() {
        let states: [LauncherPresentationState] = [
            .hidden, .presenting(requestID: 5, targetScreen: screen),
            .dismissing(requestID: 6, reason: .statusItem),
            .suspended(reason: .sleep), .terminating
        ]
        for state in states {
            let clock = FakePinchClock()
            var coordinator = makeCoordinator(clock)
            let request = token(coordinator)
            coordinator.handlePinchEvent(.hideRequested(token: request))
            coordinator.adoptPresentation(LauncherPresentationCoordinator(initialState: state))
            XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
            XCTAssertEqual(coordinator.presentation.state, state)
            coordinator.adoptPresentation(LauncherPresentationCoordinator(initialState: .visible(screenID: screen)))
            coordinator.handlePinchEvent(.hideRequested(token: request))
            XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
        }
    }

    func testParentModeAndBackendReadinessAreAllRequired() {
        for gate in 0..<3 {
            let clock = FakePinchClock()
            var coordinator = makeCoordinator(clock)
            switch gate {
            case 0: coordinator.userEnabled = false
            case 1: coordinator.setOutwardHideEnabled(false)
            default: coordinator.handleProviderState(.noDevice)
            }
            let request = token(coordinator)
            coordinator.handlePinchEvent(.hideRequested(token: request))
            XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
            XCTAssertEqual(coordinator.hideCount, 0)
            XCTAssertEqual(coordinator.presentation.state, .visible(screenID: screen))
        }
        let clock = FakePinchClock()
        var checking = FourFingerActivationCoordinator(clock: clock, targetScreen: screen, userEnabled: true)
        checking.setOutwardHideEnabled(true)
        checking.start()
        checking.adoptPresentation(LauncherPresentationCoordinator(initialState: .visible(screenID: screen)))
        checking.handlePinchEvent(.hideRequested(token: token(checking)))
        checking.handleProviderState(.ready)
        XCTAssertFalse(checking.flushPendingHides(allowHide: true))
    }

    func testModeEditIsIdempotentClearsBothQueuesAndNeverStartsDisabledRecognizer() {
        let clock = FakePinchClock()
        var disabled = FourFingerActivationCoordinator(clock: clock, targetScreen: screen)
        disabled.setOutwardHideEnabled(true)
        XCTAssertTrue(disabled.outwardHideEnabled)
        XCTAssertTrue(disabled.recognizer.outwardHideEnabled)
        XCTAssertEqual(disabled.recognizer.state, .disabled)
        XCTAssertEqual(disabled.activation.state, .off)
        let generation = disabled.recognizer.generation
        disabled.setOutwardHideEnabled(true)
        XCTAssertEqual(disabled.recognizer.generation, generation)
        var coordinator = makeCoordinator(clock)
        coordinator.handlePinchEvent(.showRequested(token: token(coordinator)))
        coordinator.handlePinchEvent(.hideRequested(token: token(coordinator, 2)))
        let before = coordinator.recognizer.generation
        coordinator.setOutwardHideEnabled(false)
        XCTAssertEqual(coordinator.recognizer.generation, before + 1)
        XCTAssertEqual(coordinator.activation.state, .ready)
        XCTAssertEqual(coordinator.recognizer.state, .idle)
        XCTAssertTrue(coordinator.pendingShowTokens.isEmpty)
        XCTAssertTrue(coordinator.pendingHideTokens.isEmpty)
    }

    func testModeOrParentToggleDuringHeldContactsRequiresRelease() {
        for toggleParent in [true, false] {
            let clock = FakePinchClock()
            var coordinator = makeCoordinator(clock)
            deliver(&coordinator, clock, 0, 0.2)
            if toggleParent {
                coordinator.userEnabled = false
                coordinator.userEnabled = true
            } else {
                coordinator.setOutwardHideEnabled(false)
                coordinator.setOutwardHideEnabled(true)
            }
            XCTAssertEqual(deliver(&coordinator, clock, 0.1, 0.24), [])
            XCTAssertEqual(deliver(&coordinator, clock, 0.2, 0.16), [])
            XCTAssertEqual(coordinator.flushPendingShows(), [])
            XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
            release(&coordinator, clock, 0.3)
            deliver(&coordinator, clock, 0.4, 0.2)
            deliver(&coordinator, clock, 0.5, 0.24)
            XCTAssertTrue(coordinator.flushPendingHides(allowHide: true))
        }
    }

    func testLifecycleAndProviderInvalidationClearQueuesAndFenceOldTokens() {
        for operation in 0..<8 {
            let clock = FakePinchClock()
            var coordinator = makeCoordinator(clock)
            deliver(&coordinator, clock, 0, 0.2)
            deliver(&coordinator, clock, 0.1, 0.24)
            guard let request = coordinator.pendingHideTokens.first else { return XCTFail("Expected pending Hide") }
            switch operation {
            case 0: coordinator.stop(); coordinator.start(); coordinator.handleProviderState(.ready)
            case 1: coordinator.restart(); coordinator.handleProviderState(.ready)
            case 2:
                _ = coordinator.suspend(reason: .sleep)
                _ = coordinator.resume()
                coordinator.handleProviderState(.ready)
            case 3: coordinator.handleProviderState(.noDevice); coordinator.handleProviderState(.ready)
            case 4: coordinator.handleProviderState(.unavailable); coordinator.handleProviderState(.ready)
            case 5: coordinator.handleProviderState(.permissionNotConfirmed); coordinator.handleProviderState(.ready)
            case 6: coordinator.handleProviderState(.checking); coordinator.handleProviderState(.ready)
            default:
                coordinator.handleProviderState(.off)
                coordinator.start()
                coordinator.handleProviderState(.ready)
            }
            XCTAssertTrue(coordinator.pendingHideTokens.isEmpty)
            XCTAssertNil(coordinator.lastAcceptedHideToken)
            XCTAssertGreaterThan(coordinator.recognizer.generation, request.generation)
            coordinator.adoptPresentation(LauncherPresentationCoordinator(initialState: .visible(screenID: screen)))
            coordinator.handlePinchEvent(.hideRequested(token: request))
            XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
        }
    }

    func testReadyRevalidationDropsPendingHideUntilBackendIsReadyAgain() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock)
        coordinator.handlePinchEvent(.hideRequested(token: token(coordinator)))
        let generation = coordinator.recognizer.generation
        coordinator.handleProviderState(.checking)
        XCTAssertEqual(coordinator.activation.state, .checking)
        XCTAssertFalse(coordinator.isReady)
        XCTAssertGreaterThan(coordinator.recognizer.generation, generation)
        XCTAssertTrue(coordinator.pendingHideTokens.isEmpty)
        XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
        coordinator.handleProviderState(.ready)
        let readyGeneration = coordinator.recognizer.generation
        coordinator.handleProviderState(.ready)
        XCTAssertEqual(coordinator.recognizer.generation, readyGeneration)
        XCTAssertTrue(coordinator.isReady)
    }

    func testCancelledFrameDiscardsPendingHide() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock)
        deliver(&coordinator, clock, 0, 0.2)
        deliver(&coordinator, clock, 0.1, 0.24)
        clock.current = 0.2
        _ = coordinator.process(frame(device, 0.2, .cancelled, []))
        XCTAssertTrue(coordinator.pendingHideTokens.isEmpty)
        XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
        XCTAssertEqual(coordinator.recognizer.state, .idle)
    }

    func testBackendLossDuringHeldContactsCannotFireAfterReadyUntilRelease() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock)
        deliver(&coordinator, clock, 0, 0.2)
        coordinator.handleProviderState(.unavailable)
        coordinator.handleProviderState(.ready)
        XCTAssertEqual(deliver(&coordinator, clock, 0.1, 0.24), [])
        release(&coordinator, clock, 0.2)
        deliver(&coordinator, clock, 0.3, 0.2)
        deliver(&coordinator, clock, 0.4, 0.24)
        XCTAssertTrue(coordinator.flushPendingHides(allowHide: true))
    }

    func testHandoffAcrossDevicesAndDirectionsWaitsForAllContactsToRelease() {
        let clock = FakePinchClock()
        var coordinator = makeCoordinator(clock)
        let other = PinchDeviceID(rawValue: 52)
        deliver(&coordinator, clock, 0, 0.2)
        deliver(&coordinator, clock, 0.1, 0.24)
        XCTAssertTrue(coordinator.flushPendingHides(allowHide: true))
        deliver(&coordinator, clock, 0.2, 0.2, deviceID: other)
        deliver(&coordinator, clock, 0.3, 0.16, deviceID: other)
        XCTAssertEqual(coordinator.flushPendingShows(), [.none])
        XCTAssertEqual(coordinator.showCount, 0)
        XCTAssertGreaterThan(coordinator.droppedHandoffEventCount, 0)
        release(&coordinator, clock, 0.4)
        XCTAssertNotNil(coordinator.handoffToken)
        release(&coordinator, clock, 0.5, deviceID: other)
        XCTAssertNil(coordinator.handoffToken)
        deliver(&coordinator, clock, 0.6, 0.2)
        deliver(&coordinator, clock, 0.7, 0.16)
        XCTAssertEqual(coordinator.flushPendingShows(), [.none])
        XCTAssertEqual(coordinator.showCount, 1)
        XCTAssertEqual(coordinator.hideCount, 1)
    }

    func testDefaultOffRetainsLegacyShowAndNoHide() {
        let clock = FakePinchClock()
        var coordinator = FourFingerActivationCoordinator(clock: clock, targetScreen: screen,
                                                          parameters: PinchParameters(cooldown: 0), userEnabled: true)
        coordinator.start()
        coordinator.handleProviderState(.ready)
        XCTAssertFalse(coordinator.outwardHideEnabled)
        deliver(&coordinator, clock, 0, 0.2, allow: false)
        deliver(&coordinator, clock, 0.1, 0.24, allow: false)
        XCTAssertEqual(coordinator.recognizer.cancelCounts[.expansion], 1)
        XCTAssertFalse(coordinator.flushPendingHides(allowHide: true))
        release(&coordinator, clock, 0.2)
        deliver(&coordinator, clock, 0.3, 0.2, allow: false)
        deliver(&coordinator, clock, 0.4, 0.16, allow: false)
        XCTAssertEqual(coordinator.flushPendingShows(), [.present(requestID: 1, targetScreen: screen, source: .fourFingerPinch)])
        XCTAssertEqual(coordinator.hideCount, 0)
    }
}
