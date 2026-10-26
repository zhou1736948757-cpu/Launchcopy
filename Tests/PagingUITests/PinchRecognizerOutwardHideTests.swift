import XCTest
@testable import PagingPrototypeApp

/// Synthetic value-state coverage only; no provider, window, or physical device is used.
final class PinchRecognizerOutwardHideTests: XCTestCase {
    private let device = PinchDeviceID(rawValue: 41)

    private func makeOutward(_ clock: FakePinchClock,
                             parameters: PinchParameters = PinchParameters(cooldown: 0)) -> PinchRecognizer {
        var recognizer = PinchRecognizer(parameters: parameters, clock: clock)
        recognizer.setOutwardHideEnabled(true)
        recognizer.start()
        return recognizer
    }

    @discardableResult
    private func deliver(_ recognizer: inout PinchRecognizer, _ clock: FakePinchClock,
                         _ time: TimeInterval, _ size: Double,
                         allow: Bool = true, phase: PinchFramePhase = .moved,
                         ids: [Int] = [1, 2, 3, 4]) -> [PinchEvent] {
        clock.current = time
        return recognizer.process(frame(device, time, phase, squareContacts(halfSize: size, ids: ids)),
                                  allowOutwardHide: allow)
    }

    private func release(_ recognizer: inout PinchRecognizer, _ clock: FakePinchClock,
                         _ time: TimeInterval) {
        clock.current = time
        XCTAssertEqual(recognizer.process(frame(device, time, .ended, [])), [])
    }

    func testDefaultsAndDisabledExpansionKeepOriginalTrace() {
        let parameters = PinchParameters()
        XCTAssertEqual(parameters.outwardGrowthThreshold, 0.15)
        XCTAssertEqual(parameters.shrinkThreshold, 0.15)
        XCTAssertEqual(parameters.maxGestureDuration, 3.5)
        XCTAssertEqual(parameters.cooldown, 0.5)
        let clock = FakePinchClock()
        var recognizer = makeRecognizer(clock: clock)
        XCTAssertFalse(recognizer.outwardHideEnabled)
        XCTAssertEqual(deliver(&recognizer, clock, 0, 0.2, phase: .began), [])
        XCTAssertEqual(recognizer.state, .candidate)
        XCTAssertEqual(deliver(&recognizer, clock, 0.1, 0.24, allow: false), [])
        XCTAssertEqual(recognizer.state, .waitingForRelease)
        XCTAssertEqual(recognizer.cancelCounts[.expansion], 1)
        XCTAssertEqual(deliver(&recognizer, clock, 0.2, 0.1), [])
        XCTAssertEqual(recognizer.fireCount, 0)
        release(&recognizer, clock, 0.3)
        XCTAssertEqual(runStandardPinch(&recognizer, clock, device: device, start: 0.4).count, 1)
        XCTAssertEqual(recognizer.generation, 0)
    }

    func testDisabledModePreservesInwardEventsStatesAndCountersWithAdmissionFalse() {
        let clockA = FakePinchClock()
        let clockB = FakePinchClock()
        var original = makeRecognizer(clock: clockA)
        var explicitOff = makeRecognizer(clock: clockB)
        explicitOff.setOutwardHideEnabled(false)
        let frames = [
            frame(device, 0, .began, squareContacts(halfSize: 0.2)),
            frame(device, 0.1, .moved, squareContacts(halfSize: 0.19)),
            frame(device, 0.2, .moved, squareContacts(halfSize: 0.16)),
            frame(device, 0.3, .moved, squareContacts(halfSize: 0.3)),
            frame(device, 0.4, .ended, [])
        ]
        for input in frames {
            clockA.current = input.timestamp
            clockB.current = input.timestamp
            XCTAssertEqual(original.process(input), explicitOff.process(input, allowOutwardHide: false))
            XCTAssertEqual(original.state, explicitOff.state)
            XCTAssertEqual(original.fireCount, explicitOff.fireCount)
            XCTAssertEqual(original.suppressedFireCount, explicitOff.suppressedFireCount)
            XCTAssertEqual(original.cancelCounts, explicitOff.cancelCounts)
            XCTAssertEqual(original.rejectedFrameCount, explicitOff.rejectedFrameCount)
            XCTAssertEqual(original.generation, explicitOff.generation)
            XCTAssertEqual(original.lastFireLatency, explicitOff.lastFireLatency)
        }
    }

    func testOutwardThresholdIsSeparateAndHideCarriesCurrentToken() {
        let clock = FakePinchClock()
        var recognizer = makeOutward(clock, parameters: PinchParameters(
            expansionCancelThreshold: 0.01, cooldown: 0, outwardGrowthThreshold: 0.25))
        XCTAssertEqual(deliver(&recognizer, clock, 0, 0.2, phase: .began), [])
        XCTAssertEqual(deliver(&recognizer, clock, 0.1, 0.24), [])
        XCTAssertEqual(recognizer.state, .recognizing)
        let events = deliver(&recognizer, clock, 0.2, 0.26)
        guard case .hideRequested(let token)? = events.first else { return XCTFail("Expected Hide") }
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(token.generation, recognizer.generation)
        XCTAssertEqual(token.sessionID, recognizer.activeSessionID)
        XCTAssertEqual(recognizer.fireCount, 1)
        XCTAssertEqual(recognizer.lastFireLatency ?? -1, 0.2, accuracy: 0.000001)
        XCTAssertNil(recognizer.cancelCounts[.expansion])
    }

    func testDefaultGrowthThresholdRejectsBelowAndAcceptsAbove() {
        let clock = FakePinchClock()
        var recognizer = makeOutward(clock)
        deliver(&recognizer, clock, 0, 0.2)
        XCTAssertEqual(deliver(&recognizer, clock, 0.1, 0.2298), [])
        guard case .hideRequested? = deliver(&recognizer, clock, 0.2, 0.2302).first else {
            return XCTFail("Growth beyond the independent 15 percent threshold must request Hide")
        }
    }

    func testExactGrowthThresholdIsInclusive() {
        let clock = FakePinchClock()
        var recognizer = makeOutward(clock, parameters: PinchParameters(cooldown: 0, outwardGrowthThreshold: 1))
        deliver(&recognizer, clock, 0, 0.125)
        guard case .hideRequested? = deliver(&recognizer, clock, 0.1, 0.25).first else {
            return XCTFail("Exact relative growth threshold must be inclusive")
        }
    }

    func testEitherDirectionConsumesSessionIncludingReversalAndCountChanges() {
        for firstSize in [0.16, 0.24] {
            let clock = FakePinchClock()
            var recognizer = makeOutward(clock)
            deliver(&recognizer, clock, 0, 0.2)
            XCTAssertEqual(deliver(&recognizer, clock, 0.1, firstSize).count, 1)
            for index in 0..<16 {
                let time = 0.2 + Double(index) * 0.1
                XCTAssertEqual(deliver(&recognizer, clock, time, index.isMultiple(of: 2) ? 0.1 : 0.4), [])
            }
            clock.current = 1.9
            XCTAssertEqual(recognizer.process(frame(device, 1.9, .moved,
                                                    Array(squareContacts(halfSize: 0.2).prefix(3)))), [])
            XCTAssertEqual(deliver(&recognizer, clock, 2, 0.4, phase: .began), [])
            XCTAssertEqual(recognizer.fireCount, 1)
            release(&recognizer, clock, 2.1)
            deliver(&recognizer, clock, 2.2, 0.2)
            XCTAssertEqual(deliver(&recognizer, clock, 2.3, 0.24).count, 1)
        }
    }

    func testBlockedFirstContactAndTransientBlockRemainIneligibleUntilRelease() {
        for blockAtFirstContact in [true, false] {
            let clock = FakePinchClock()
            var recognizer = makeOutward(clock)
            clock.current = 0
            let partial = Array(squareContacts(halfSize: 0.2).prefix(2))
            XCTAssertEqual(recognizer.process(frame(device, 0, .began, partial),
                                              allowOutwardHide: !blockAtFirstContact), [])
            deliver(&recognizer, clock, 0.1, 0.2)
            deliver(&recognizer, clock, 0.2, 0.21, allow: blockAtFirstContact)
            XCTAssertEqual(deliver(&recognizer, clock, 0.3, 0.24), [])
            XCTAssertEqual(recognizer.state, .fired)
            XCTAssertEqual(deliver(&recognizer, clock, 0.4, 0.1), [])
            XCTAssertEqual(recognizer.fireCount, 0)
            XCTAssertEqual(recognizer.suppressedFireCount, 1)
            release(&recognizer, clock, 0.5)
            deliver(&recognizer, clock, 0.6, 0.2)
            XCTAssertEqual(deliver(&recognizer, clock, 0.7, 0.24).count, 1)
        }
    }

    func testHideAdmissionDoesNotBlockInwardShow() {
        let clock = FakePinchClock()
        var recognizer = makeOutward(clock)
        deliver(&recognizer, clock, 0, 0.2, allow: false)
        guard case .showRequested? = deliver(&recognizer, clock, 0.1, 0.16, allow: false).first else {
            return XCTFail("Host Hide admission must not gate inward Show")
        }
    }

    func testModeEditsAreIdempotentAndCannotEnableDisabledRecognizer() {
        let clock = FakePinchClock()
        var recognizer = PinchRecognizer(clock: clock)
        recognizer.setOutwardHideEnabled(true)
        XCTAssertEqual(recognizer.state, .disabled)
        XCTAssertEqual(recognizer.generation, 1)
        recognizer.setOutwardHideEnabled(true)
        XCTAssertEqual(recognizer.generation, 1)
        recognizer.setOutwardHideEnabled(false)
        XCTAssertEqual(recognizer.state, .disabled)
        XCTAssertEqual(recognizer.generation, 2)
        XCTAssertEqual(deliver(&recognizer, clock, 0, 0.24), [])
    }

    func testModeToggleWithPartialOrFourHeldContactsRequiresRelease() {
        for count in [2, 4] {
            let clock = FakePinchClock()
            var recognizer = makeRecognizer(clock: clock)
            clock.current = 0
            _ = recognizer.process(frame(device, 0, .began,
                                         Array(squareContacts(halfSize: 0.2).prefix(count))))
            let generation = recognizer.generation
            recognizer.setOutwardHideEnabled(true)
            recognizer.setOutwardHideEnabled(false)
            recognizer.setOutwardHideEnabled(true)
            XCTAssertEqual(recognizer.generation, generation + 3)
            XCTAssertEqual(deliver(&recognizer, clock, 0.1, 0.24), [])
            XCTAssertEqual(deliver(&recognizer, clock, 0.2, 0.1), [])
            release(&recognizer, clock, 0.3)
            deliver(&recognizer, clock, 0.4, 0.2)
            XCTAssertEqual(deliver(&recognizer, clock, 0.5, 0.24).count, 1)
        }
    }

    func testContactReplacementAndCountChangesCancelOutwardCandidate() {
        for replacement in [false, true] {
            let clock = FakePinchClock()
            var recognizer = makeOutward(clock)
            deliver(&recognizer, clock, 0, 0.2)
            clock.current = 0.1
            let contacts = replacement ? squareContacts(halfSize: 0.24, ids: [1, 2, 3, 9]) :
                Array(squareContacts(halfSize: 0.24).prefix(3))
            XCTAssertEqual(recognizer.process(frame(device, 0.1, .moved, contacts)), [])
            XCTAssertEqual(recognizer.state, .waitingForRelease)
            XCTAssertEqual(recognizer.cancelCounts[replacement ? .contactReplaced : .contactCountChanged], 1)
            XCTAssertEqual(deliver(&recognizer, clock, 0.2, 0.3), [])
        }
    }

    func testTwoDevicesCannotCombineContactsOrInheritAdmission() {
        let clock = FakePinchClock()
        var recognizer = makeOutward(clock)
        let other = PinchDeviceID(rawValue: 42)
        for (index, id) in [device, other].enumerated() {
            clock.current = Double(index) * 0.01
            XCTAssertEqual(recognizer.process(frame(id, clock.current, .began,
                                                    Array(squareContacts(halfSize: 0.2).prefix(2))),
                                              allowOutwardHide: id != device), [])
        }
        deliver(&recognizer, clock, 0.1, 0.2)
        XCTAssertEqual(deliver(&recognizer, clock, 0.2, 0.24), [])
        clock.current = 0.3
        _ = recognizer.process(frame(other, 0.3, .moved, squareContacts(halfSize: 0.2)))
        clock.current = 0.4
        guard case .hideRequested? = recognizer.process(
            frame(other, 0.4, .moved, squareContacts(halfSize: 0.24))).first else {
            return XCTFail("The other device retains independent baseline and admission")
        }
    }

    func testCooldownIsSharedAcrossDirectionsAndConsumesSuppressedSession() {
        let clock = FakePinchClock()
        var recognizer = makeOutward(clock, parameters: PinchParameters())
        deliver(&recognizer, clock, 0, 0.2)
        XCTAssertEqual(deliver(&recognizer, clock, 0.1, 0.24).count, 1)
        release(&recognizer, clock, 0.15)
        deliver(&recognizer, clock, 0.2, 0.2)
        XCTAssertEqual(deliver(&recognizer, clock, 0.3, 0.16), [])
        XCTAssertEqual(recognizer.suppressedFireCount, 1)
        XCTAssertEqual(deliver(&recognizer, clock, 0.7, 0.24), [])
        release(&recognizer, clock, 0.8)
        deliver(&recognizer, clock, 0.9, 0.2)
        guard case .showRequested? = deliver(&recognizer, clock, 1, 0.16).first else {
            return XCTFail("Release and elapsed cooldown rearm inward Show")
        }
        release(&recognizer, clock, 1.05)
        deliver(&recognizer, clock, 1.1, 0.2)
        XCTAssertEqual(deliver(&recognizer, clock, 1.2, 0.24), [])
        XCTAssertEqual(recognizer.suppressedFireCount, 2)
    }

    func testSilentExpiryCannotReanchorOutwardWhileContactsRemainHeld() {
        let clock = FakePinchClock()
        var recognizer = makeOutward(clock)
        deliver(&recognizer, clock, 0, 0.2)
        XCTAssertEqual(deliver(&recognizer, clock, 0.6, 0.24), [])
        XCTAssertEqual(recognizer.state, .waitingForRelease)
        XCTAssertEqual(recognizer.cancelCounts[.dataExpired], 1)
        XCTAssertEqual(deliver(&recognizer, clock, 0.7, 0.3), [])
        release(&recognizer, clock, 0.8)
        deliver(&recognizer, clock, 0.9, 0.2)
        XCTAssertEqual(deliver(&recognizer, clock, 1, 0.24).count, 1)
    }

    func testDurationLimitCancelsDespiteFreshFrames() {
        let clock = FakePinchClock()
        var recognizer = makeOutward(clock)
        deliver(&recognizer, clock, 0, 0.2)
        for index in 1...8 { deliver(&recognizer, clock, Double(index) * 0.4, 0.21) }
        XCTAssertEqual(deliver(&recognizer, clock, 3.6, 0.24), [])
        XCTAssertEqual(recognizer.cancelCounts[.timeLimitExceeded], 1)
        XCTAssertEqual(recognizer.state, .waitingForRelease)
    }

    func testMalformedFramesFailClosedAndDoNotReleaseOrReanchor() {
        var duplicate = squareContacts(halfSize: 0.24)
        duplicate[3].id = duplicate[0].id
        var nan = squareContacts(halfSize: 0.24)
        nan[0].position.x = .nan
        var infinite = squareContacts(halfSize: 0.24)
        infinite[0].position.y = .infinity
        let malformed = [
            frame(device, .nan, .moved, squareContacts(halfSize: 0.24)),
            frame(device, .infinity, .moved, squareContacts(halfSize: 0.24)),
            frame(device, -1, .moved, squareContacts(halfSize: 0.24)),
            frame(device, 0.3, .moved, squareContacts(halfSize: 0.24)), // Future.
            frame(device, 0.05, .ended, []), // Out-of-order release.
            frame(device, 0.2, .moved, duplicate),
            frame(device, 0.2, .moved, nan),
            frame(device, 0.2, .moved, infinite),
            frame(device, 0.2, .ended, squareContacts(halfSize: 0.24)),
            frame(device, 0.2, .began, []),
            frame(device, 0.2, .moved, (1...9).map {
                PinchContact(id: PinchContactID(rawValue: $0), position: PinchPoint(x: 0.2, y: 0.3))
            })
        ]
        for input in malformed {
            let clock = FakePinchClock()
            var recognizer = makeOutward(clock)
            deliver(&recognizer, clock, 0.1, 0.2)
            clock.current = 0.2
            XCTAssertEqual(recognizer.process(input), [])
            XCTAssertGreaterThan(recognizer.rejectedFrameCount, 0)
            XCTAssertEqual(deliver(&recognizer, clock, 0.3, 0.24), [])
            XCTAssertEqual(deliver(&recognizer, clock, 0.4, 0.3), [])
            release(&recognizer, clock, 0.5)
            deliver(&recognizer, clock, 0.6, 0.2)
            XCTAssertEqual(deliver(&recognizer, clock, 0.7, 0.24).count, 1)
        }
    }

    func testStaleFrameAndInvalidClockCannotRequestHide() {
        for invalidClock in [Double.nan, .infinity, -1, 1] {
            let clock = FakePinchClock()
            var recognizer = makeOutward(clock)
            deliver(&recognizer, clock, 0, 0.2)
            clock.current = invalidClock
            XCTAssertEqual(recognizer.process(frame(device, 0.1, .moved, squareContacts(halfSize: 0.24))), [])
            XCTAssertEqual(recognizer.rejectedFrameCount, 1)
            XCTAssertEqual(deliver(&recognizer, clock, 1.1, 0.3), [])
        }
    }

    func testOverflowingGeometryAndInvalidThresholdFailClosed() {
        let clock = FakePinchClock()
        var recognizer = makeOutward(clock)
        deliver(&recognizer, clock, 0, 0.2)
        XCTAssertEqual(deliver(&recognizer, clock, 0.1, Double.greatestFiniteMagnitude), [])
        XCTAssertEqual(recognizer.cancelCounts[.degenerateGeometry], 1)
        for threshold in [Double.nan, .infinity, -0.1, 0] {
            var invalid = makeOutward(clock, parameters: PinchParameters(cooldown: 0,
                                                                       outwardGrowthThreshold: threshold))
            deliver(&invalid, clock, 0.2, 0.2)
            XCTAssertEqual(deliver(&invalid, clock, 0.3, 0.24), [])
        }
    }

    func testLifecycleClearsAdmissionAndPreservesSavedMode() {
        for operation in 0..<4 {
            let clock = FakePinchClock()
            var recognizer = makeOutward(clock)
            deliver(&recognizer, clock, 0, 0.2, allow: false)
            let generation = recognizer.generation
            switch operation {
            case 0: recognizer.stop(); recognizer.start()
            case 1: recognizer.restart()
            case 2: recognizer.suspend(reason: .sleep); recognizer.resume()
            default: recognizer.deviceDisconnected(device)
            }
            XCTAssertTrue(recognizer.outwardHideEnabled)
            XCTAssertEqual(recognizer.state, .idle)
            if operation != 3 { XCTAssertGreaterThan(recognizer.generation, generation) }
            deliver(&recognizer, clock, 0.1, 0.2)
            let held = deliver(&recognizer, clock, 0.2, 0.24)
            if operation == 3 {
                XCTAssertEqual(held.count, 1, "Disconnect is reliable release evidence")
            } else {
                XCTAssertEqual(held, [], "Lifecycle changes are not physical release")
                release(&recognizer, clock, 0.3)
                deliver(&recognizer, clock, 0.4, 0.2)
                XCTAssertEqual(deliver(&recognizer, clock, 0.5, 0.24).count, 1)
            }
        }
    }
}
