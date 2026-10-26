import XCTest
@testable import PagingPrototypeApp

/// Synthetic contact traces only. Main owns execution and integrated delivery tests.
final class PinchRecognizerOutwardLifecycleFenceTests: XCTestCase {
    private let device = PinchDeviceID(rawValue: 71)

    private enum Boundary: CaseIterable, Equatable {
        case stopStart, restart, sleep, sessionInactive, screenConfigurationChanged

        func apply(to recognizer: inout PinchRecognizer) {
            switch self {
            case .stopStart:
                recognizer.stop()
                recognizer.start()
            case .restart:
                recognizer.restart()
            case .sleep:
                recognizer.suspend(reason: .sleep)
                recognizer.resume()
            case .sessionInactive:
                recognizer.suspend(reason: .sessionInactive)
                recognizer.resume()
            case .screenConfigurationChanged:
                recognizer.suspend(reason: .screenConfigurationChanged)
                recognizer.resume()
            }
        }
    }

    private func makeOptional(_ clock: FakePinchClock) -> PinchRecognizer {
        var recognizer = makeRecognizer(clock: clock)
        recognizer.setOutwardHideEnabled(true)
        return recognizer
    }

    @discardableResult
    private func deliver(_ recognizer: inout PinchRecognizer, _ clock: FakePinchClock,
                         _ time: TimeInterval, _ size: Double,
                         deviceID: PinchDeviceID? = nil,
                         phase: PinchFramePhase = .moved, count: Int = 4) -> [PinchEvent] {
        processAt(&recognizer, clock, frame(deviceID ?? device, time, phase,
            Array(squareContacts(halfSize: size).prefix(count))))
    }

    private func release(_ recognizer: inout PinchRecognizer, _ clock: FakePinchClock,
                         _ time: TimeInterval, phase: PinchFramePhase = .ended) {
        XCTAssertEqual(processAt(&recognizer, clock, frame(device, time, phase, [])), [])
    }

    private func assertFreshHide(_ recognizer: inout PinchRecognizer, _ clock: FakePinchClock,
                                 at time: TimeInterval, deviceID: PinchDeviceID? = nil) {
        XCTAssertEqual(deliver(&recognizer, clock, time, 0.2, deviceID: deviceID), [])
        let events = deliver(&recognizer, clock, time + 0.1, 0.25, deviceID: deviceID)
        guard case .hideRequested(let token)? = events.first else {
            return XCTFail("A released device must accept a fresh outward gesture")
        }
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(token.generation, recognizer.generation)
    }

    func testOptionalLifecycleRetainsPartialAndFourContactGatesUntilRelease() {
        for boundary in Boundary.allCases {
            for count in [1, 2, 4] {
                let clock = FakePinchClock()
                var recognizer = makeOptional(clock)
                deliver(&recognizer, clock, 0, 0.2, phase: .began, count: count)
                let generation = recognizer.generation

                boundary.apply(to: &recognizer)
                XCTAssertEqual(recognizer.state, .idle)
                XCTAssertNil(recognizer.activeSessionID)
                XCTAssertGreaterThan(recognizer.generation, generation)
                XCTAssertTrue(recognizer.outwardHideEnabled)
                XCTAssertEqual(deliver(&recognizer, clock, 0.1, 0.25), [])
                XCTAssertEqual(deliver(&recognizer, clock, 0.2, 0.16), [])
                XCTAssertEqual(recognizer.fireCount, 0)

                release(&recognizer, clock, 0.3)
                assertFreshHide(&recognizer, clock, at: 0.4)
            }
        }
    }

    func testFiredSessionCannotActAgainAcrossOptionalLifecycleBoundaries() {
        for boundary in Boundary.allCases {
            for firstSize in [0.16, 0.25] {
                let clock = FakePinchClock()
                var recognizer = makeOptional(clock)
                deliver(&recognizer, clock, 0, 0.2)
                XCTAssertEqual(deliver(&recognizer, clock, 0.1, firstSize).count, 1)

                boundary.apply(to: &recognizer)
                XCTAssertEqual(deliver(&recognizer, clock, 0.2, 0.2), [])
                XCTAssertEqual(deliver(&recognizer, clock, 0.3, 0.25), [])
                XCTAssertEqual(deliver(&recognizer, clock, 0.4, 0.16), [])
                XCTAssertEqual(recognizer.fireCount, 1)

                release(&recognizer, clock, 0.5)
                assertFreshHide(&recognizer, clock, at: 0.6)
                XCTAssertEqual(recognizer.fireCount, 2)
            }
        }
    }

    func testExplicitModeOffQuarantineSurvivesEveryLifecycleBoundary() {
        for boundary in Boundary.allCases {
            let clock = FakePinchClock()
            var recognizer = makeOptional(clock)
            deliver(&recognizer, clock, 0, 0.2)
            recognizer.setOutwardHideEnabled(false)
            let generation = recognizer.generation

            boundary.apply(to: &recognizer)
            XCTAssertFalse(recognizer.outwardHideEnabled)
            XCTAssertGreaterThan(recognizer.generation, generation)
            XCTAssertEqual(deliver(&recognizer, clock, 0.1, 0.2), [])
            XCTAssertEqual(deliver(&recognizer, clock, 0.2, 0.16), [])
            recognizer.setOutwardHideEnabled(true)
            XCTAssertEqual(deliver(&recognizer, clock, 0.3, 0.25), [])
            XCTAssertEqual(recognizer.fireCount, 0)

            release(&recognizer, clock, 0.4)
            assertFreshHide(&recognizer, clock, at: 0.5)
        }
    }

    func testParentStopStartOrderingCannotClearKnownContactsWhileModeIsOff() {
        for disableBeforeStop in [false, true] {
            let clock = FakePinchClock()
            var recognizer = makeOptional(clock)
            deliver(&recognizer, clock, 0, 0.2)
            if disableBeforeStop { recognizer.setOutwardHideEnabled(false) }
            recognizer.stop()
            if !disableBeforeStop { recognizer.setOutwardHideEnabled(false) }
            recognizer.start()
            recognizer.setOutwardHideEnabled(true)

            XCTAssertEqual(deliver(&recognizer, clock, 0.1, 0.2), [])
            XCTAssertEqual(deliver(&recognizer, clock, 0.2, 0.25), [])
            XCTAssertEqual(deliver(&recognizer, clock, 0.3, 0.16), [])
            release(&recognizer, clock, 0.4)
            assertFreshHide(&recognizer, clock, at: 0.5)
        }
    }

    func testModeOffQuarantineRejectsOldAndNonemptyReleaseFramesAfterRestart() {
        let clock = FakePinchClock()
        var recognizer = makeOptional(clock)
        deliver(&recognizer, clock, 0.2, 0.2)
        recognizer.setOutwardHideEnabled(false)
        recognizer.restart()

        clock.current = 0.3
        XCTAssertEqual(recognizer.process(frame(device, 0.1, .ended, [])), [])
        XCTAssertEqual(deliver(&recognizer, clock, 0.31, 0.2, phase: .ended), [])
        XCTAssertEqual(deliver(&recognizer, clock, 0.32, 0.2, phase: .cancelled), [])
        XCTAssertEqual(deliver(&recognizer, clock, 0.4, 0.2), [])
        XCTAssertEqual(deliver(&recognizer, clock, 0.5, 0.16), [])
        XCTAssertEqual(recognizer.rejectedFrameCount, 3)
        XCTAssertEqual(recognizer.fireCount, 0)

        release(&recognizer, clock, 0.6, phase: .moved)
        deliver(&recognizer, clock, 0.7, 0.2)
        let events = deliver(&recognizer, clock, 0.8, 0.16)
        guard case .showRequested? = events.first else {
            return XCTFail("A reliable release must restore inward-only recognition")
        }
        XCTAssertEqual(events.count, 1)
    }

    func testDeliveryInvalidationQuarantinesUnknownDeviceWithoutEnablingRecognition() {
        let clock = FakePinchClock()
        var recognizer = PinchRecognizer(parameters: PinchParameters(cooldown: 0), clock: clock)
        let generation = recognizer.generation
        recognizer.requireReleaseAfterDeliveryInvalidation(device)
        XCTAssertEqual(recognizer.generation, generation + 1)
        XCTAssertEqual(recognizer.state, .disabled)
        XCTAssertFalse(recognizer.isEnabled)
        XCTAssertFalse(recognizer.outwardHideEnabled)
        XCTAssertNil(recognizer.activeSessionID)

        recognizer.start()
        XCTAssertEqual(deliver(&recognizer, clock, 0, 0.2), [])
        XCTAssertEqual(deliver(&recognizer, clock, 0.1, 0.16), [])
        recognizer.setOutwardHideEnabled(true)
        recognizer.restart()
        XCTAssertEqual(deliver(&recognizer, clock, 0.2, 0.25), [])
        XCTAssertEqual(recognizer.fireCount, 0)
        release(&recognizer, clock, 0.3)
        assertFreshHide(&recognizer, clock, at: 0.4)
    }

    func testDeliveryInvalidationAlsoFencesExistingSessionsAndTheirGeneration() {
        let clock = FakePinchClock()
        var recognizer = makeOptional(clock)
        let unknown = PinchDeviceID(rawValue: 72)
        let candidate = PinchDeviceID(rawValue: 73)
        deliver(&recognizer, clock, 0, 0.2)
        let events = deliver(&recognizer, clock, 0.1, 0.25)
        guard case .hideRequested(let token)? = events.first else { return XCTFail("Expected Hide") }
        deliver(&recognizer, clock, 0.15, 0.2, deviceID: candidate)

        recognizer.requireReleaseAfterDeliveryInvalidation(unknown)
        XCTAssertGreaterThan(recognizer.generation, token.generation)
        XCTAssertEqual(deliver(&recognizer, clock, 0.2, 0.2), [])
        XCTAssertEqual(deliver(&recognizer, clock, 0.3, 0.16), [])
        XCTAssertEqual(deliver(&recognizer, clock, 0.4, 0.25, deviceID: candidate), [])
        XCTAssertEqual(deliver(&recognizer, clock, 0.45, 0.16, deviceID: candidate), [])
        XCTAssertEqual(deliver(&recognizer, clock, 0.5, 0.2, deviceID: unknown), [])
        XCTAssertEqual(deliver(&recognizer, clock, 0.55, 0.25, deviceID: unknown), [])
        XCTAssertEqual(recognizer.fireCount, 1)

        release(&recognizer, clock, 0.6)
        assertFreshHide(&recognizer, clock, at: 0.7)
        XCTAssertEqual(deliver(&recognizer, clock, 0.9, 0.16, deviceID: unknown), [])
    }

    func testDeliveryInvalidationDoesNotResumeSuspendedRecognizer() {
        let clock = FakePinchClock()
        var recognizer = makeOptional(clock)
        recognizer.suspend(reason: .sessionInactive)
        let generation = recognizer.generation
        recognizer.requireReleaseAfterDeliveryInvalidation(device)
        XCTAssertEqual(recognizer.state, .suspended(reason: .sessionInactive))
        XCTAssertEqual(recognizer.generation, generation + 1)
        XCTAssertEqual(deliver(&recognizer, clock, 0, 0.2), [])
        recognizer.resume()
        XCTAssertEqual(deliver(&recognizer, clock, 0.1, 0.2), [])
        XCTAssertEqual(deliver(&recognizer, clock, 0.2, 0.25), [])
        release(&recognizer, clock, 0.3)
        assertFreshHide(&recognizer, clock, at: 0.4)
    }

    func testInvalidOptionalFirstFrameStaysQuarantinedAcrossLifecycleUntilRelease() {
        let invalidTimes: [(TimeInterval, TimeInterval)] = [
            (.nan, 0.2), (.infinity, 0.2), (-1, 0.2), (0.3, 0.2), (0, 1)
        ]
        for boundary in Boundary.allCases {
            for (timestamp, now) in invalidTimes {
                let clock = FakePinchClock()
                var recognizer = makeOptional(clock)
                clock.current = now
                XCTAssertEqual(recognizer.process(frame(device, timestamp, .began,
                    squareContacts(halfSize: 0.2))), [])
                XCTAssertEqual(recognizer.rejectedFrameCount, 1)

                boundary.apply(to: &recognizer)
                XCTAssertEqual(deliver(&recognizer, clock, 2, 0.2), [])
                XCTAssertEqual(deliver(&recognizer, clock, 2.1, 0.25), [])
                XCTAssertEqual(deliver(&recognizer, clock, 2.2, 0.16), [])
                XCTAssertEqual(recognizer.fireCount, 0)
                release(&recognizer, clock, 2.3)
                assertFreshHide(&recognizer, clock, at: 2.4)
            }
        }
    }

    func testDisconnectReleasesOnlyItsDeviceEvenWhileStoppedOrSuspended() {
        let other = PinchDeviceID(rawValue: 72)
        for lifecycle in 0..<3 {
            let clock = FakePinchClock()
            var recognizer = makeOptional(clock)
            deliver(&recognizer, clock, 0, 0.2)
            deliver(&recognizer, clock, 0.05, 0.2, deviceID: other)
            switch lifecycle {
            case 0: recognizer.restart()
            case 1: recognizer.stop()
            default: recognizer.suspend(reason: .sleep)
            }
            recognizer.deviceDisconnected(device)
            if lifecycle == 1 { recognizer.start() }
            if lifecycle == 2 { recognizer.resume() }

            XCTAssertEqual(deliver(&recognizer, clock, 0.1, 0.2, deviceID: other), [])
            XCTAssertEqual(deliver(&recognizer, clock, 0.2, 0.25, deviceID: other), [])
            assertFreshHide(&recognizer, clock, at: 0.3)
            XCTAssertEqual(deliver(&recognizer, clock, 0.5, 0.16, deviceID: other), [])
            recognizer.deviceDisconnected(other)
            assertFreshHide(&recognizer, clock, at: 0.6, deviceID: other)
        }
    }

    func testNeverEnabledLifecycleKeepsHistoricalFreshCandidateAndExpansionCancel() {
        for boundary in Boundary.allCases {
            let clock = FakePinchClock()
            var recognizer = makeRecognizer(clock: clock)
            deliver(&recognizer, clock, 0, 0.2)
            let generation = recognizer.generation
            boundary.apply(to: &recognizer)
            let expectedGeneration = generation + (boundary == .stopStart || boundary == .restart ? 1 : 0)
            XCTAssertEqual(recognizer.generation, expectedGeneration)

            deliver(&recognizer, clock, 0.1, 0.2)
            XCTAssertEqual(recognizer.state, .candidate)
            XCTAssertEqual(deliver(&recognizer, clock, 0.2, 0.25), [])
            XCTAssertEqual(recognizer.state, .waitingForRelease)
            XCTAssertEqual(recognizer.cancelCounts[.expansion], 1)
            release(&recognizer, clock, 0.3)
            let events = runStandardPinch(&recognizer, clock, device: device, start: 0.4)
            guard case .showRequested? = events.first else { return XCTFail("Expected legacy Show") }
            XCTAssertEqual(events.count, 1)
            XCTAssertEqual(recognizer.fireCount, 1)
            XCTAssertEqual(recognizer.generation, expectedGeneration)
            XCTAssertFalse(recognizer.outwardHideEnabled)
        }
    }

    func testOptionalLifecycleWithoutKnownContactsDoesNotBlockNewGesture() {
        for boundary in Boundary.allCases {
            let clock = FakePinchClock()
            var recognizer = makeOptional(clock)
            boundary.apply(to: &recognizer)
            assertFreshHide(&recognizer, clock, at: 0)
        }
    }
}
