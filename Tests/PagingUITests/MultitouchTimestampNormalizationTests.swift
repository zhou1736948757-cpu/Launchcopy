import AppKit
import XCTest
@testable import PagingPrototypeApp

/// Deterministic synthetic input only; these cases do not establish physical-device acceptance.
final class MultitouchTimestampNormalizationTests: XCTestCase {
    private let device = PinchDeviceID(rawValue: 81)

    private func sample(_ synthesizer: inout MultitouchFrameSynthesizer,
                        source: Double, ingress: TimeInterval,
                        halfSize: Double = 0.2, contactCount: Int = 4,
                        deviceID: PinchDeviceID? = nil,
                        file: StaticString = #filePath, line: UInt = #line) throws -> PinchFrame {
        let touches = squareContacts(halfSize: halfSize).prefix(contactCount).enumerated().map { index, contact in
            RawTouch(identifier: Int32(index + 1), state: MTTouchState.onSurfaceBit,
                     x: Float(contact.position.x), y: Float(contact.position.y))
        }
        let frames = synthesizer.synthesize(deviceID: deviceID ?? device,
                                            callbackTimestamp: source, touches: touches,
                                            uptimeNow: ingress)
        XCTAssertEqual(frames.count, 1, file: file, line: line)
        return try XCTUnwrap(frames.first, file: file, line: line)
    }

    private func optionalRecognizer(_ clock: FakePinchClock) -> PinchRecognizer {
        var recognizer = PinchRecognizer(clock: clock)
        recognizer.setOutwardHideEnabled(true)
        recognizer.start()
        return recognizer
    }

    @discardableResult
    private func consume(_ input: PinchFrame, at consumerTime: TimeInterval,
                         recognizer: inout PinchRecognizer, clock: FakePinchClock) -> [PinchEvent] {
        // Deliberately do not use processAt: consumer time must remain independent of ingress.
        clock.current = consumerTime
        return recognizer.process(input, allowOutwardHide: true)
    }

    func testBiasedInitialLatencyAndAheadCallbacksStayBoundedAndOrdered() throws {
        var synthesizer = MultitouchFrameSynthesizer()
        // The first receipt is late relative to subsequent source deltas. The last
        // receipt catches up, exposing whether a previous cap incorrectly reanchored.
        let samples: [(Double, Double, Double)] = [
            (100, 10, 10), (100.125, 10.015625, 10.015625),
            (100.25, 10.03125, 10.03125), (100.375, 10.125, 10.125),
            (100.5, 10.75, 10.5)
        ]
        var previous = -Double.infinity
        for (source, ingress, expected) in samples {
            let input = try sample(&synthesizer, source: source, ingress: ingress)
            XCTAssertTrue(input.timestamp.isFinite)
            XCTAssertLessThanOrEqual(input.timestamp, ingress)
            XCTAssertGreaterThanOrEqual(input.timestamp, previous)
            XCTAssertEqual(input.timestamp, expected, accuracy: 0.000001)
            previous = input.timestamp
        }
    }

    func testNormalSourceDeltasAndDuplicateTimesAreRetained() throws {
        var synthesizer = MultitouchFrameSynthesizer()
        let first = try sample(&synthesizer, source: 100, ingress: 10)
        let second = try sample(&synthesizer, source: 100.0625, ingress: 10.125)
        let third = try sample(&synthesizer, source: 100.125, ingress: 10.375)
        let duplicate = try sample(&synthesizer, source: 100.125, ingress: 10.5)
        XCTAssertEqual(first.phase, .began)
        XCTAssertEqual(second.phase, .moved)
        XCTAssertEqual(second.timestamp - first.timestamp, 0.0625, accuracy: 0.000001)
        XCTAssertEqual(third.timestamp - second.timestamp, 0.0625, accuracy: 0.000001)
        XCTAssertEqual(duplicate.timestamp, third.timestamp)
        XCTAssertEqual(duplicate.contacts.map(\.id), first.contacts.map(\.id))
    }

    func testSlowerSourceIsNotRenewedAtReceiptAndRemainsStale() throws {
        var synthesizer = MultitouchFrameSynthesizer()
        let clock = FakePinchClock()
        var recognizer = optionalRecognizer(clock)
        let first = try sample(&synthesizer, source: 100, ingress: 10)
        XCTAssertTrue(consume(first, at: 10, recognizer: &recognizer, clock: clock).isEmpty)
        let old = try sample(&synthesizer, source: 100.125, ingress: 11, halfSize: 0.25)
        XCTAssertEqual(old.timestamp, 10.125, accuracy: 0.000001)
        XCTAssertGreaterThan(11 - old.timestamp, recognizer.parameters.dataExpiryInterval)
        XCTAssertTrue(consume(old, at: 11, recognizer: &recognizer, clock: clock).isEmpty)
        XCTAssertEqual(recognizer.rejectedFrameCount, 1)
        XCTAssertEqual(recognizer.fireCount, 0)
        let next = try sample(&synthesizer, source: 100.25, ingress: 11.125)
        XCTAssertEqual(next.timestamp, 10.25, accuracy: 0.000001, "An old receipt must not move the anchor")
    }

    func testDelayedConsumerRejectsIngressBoundedFramesUntilValidRelease() throws {
        var synthesizer = MultitouchFrameSynthesizer()
        let clock = FakePinchClock()
        var recognizer = optionalRecognizer(clock)
        // Capture both values before advancing the consumer clock; this models a backlog.
        let queued = [
            try sample(&synthesizer, source: 100, ingress: 10),
            try sample(&synthesizer, source: 101, ingress: 10.125, halfSize: 0.25)
        ]
        XCTAssertEqual(queued.map(\.timestamp), [10, 10.125])
        for input in queued {
            XCTAssertTrue(consume(input, at: 11, recognizer: &recognizer, clock: clock).isEmpty)
        }
        XCTAssertEqual(recognizer.rejectedFrameCount, 2)
        let held = try sample(&synthesizer, source: 102, ingress: 11.125, halfSize: 0.3)
        XCTAssertTrue(consume(held, at: 11.125, recognizer: &recognizer, clock: clock).isEmpty)
        XCTAssertEqual(recognizer.fireCount, 0)
        let release = try sample(&synthesizer, source: 103, ingress: 11.25, contactCount: 0)
        XCTAssertTrue(consume(release, at: 11.25, recognizer: &recognizer, clock: clock).isEmpty)
        let baseline = try sample(&synthesizer, source: 104, ingress: 11.375)
        XCTAssertTrue(consume(baseline, at: 11.375, recognizer: &recognizer, clock: clock).isEmpty)
        let outward = try sample(&synthesizer, source: 105, ingress: 11.5, halfSize: 0.25)
        let events = consume(outward, at: 11.5, recognizer: &recognizer, clock: clock)
        XCTAssertEqual(events.count, 1)
        guard case .hideRequested? = events.first else { return XCTFail("Expected Hide after valid release") }
    }

    func testRawRegressionHiddenByIngressCapStillRejectsAndPreservesWatermark() throws {
        var synthesizer = MultitouchFrameSynthesizer()
        let clock = FakePinchClock()
        var recognizer = optionalRecognizer(clock)
        let first = try sample(&synthesizer, source: 100, ingress: 10)
        consume(first, at: 10, recognizer: &recognizer, clock: clock)
        let ahead = try sample(&synthesizer, source: 102, ingress: 10.125)
        consume(ahead, at: 10.125, recognizer: &recognizer, clock: clock)
        // Both raw 102 and raw 101 map ahead of ingress. Capping alone would
        // disguise the source regression as a later, valid outward movement.
        let regressed = try sample(&synthesizer, source: 101, ingress: 10.25, halfSize: 0.25)
        XCTAssertTrue(regressed.timestamp.isNaN)
        XCTAssertEqual(regressed.phase, .moved)
        XCTAssertEqual(regressed.contacts.count, 4)
        XCTAssertEqual(regressed.contacts.map(\.id), ahead.contacts.map(\.id))
        XCTAssertTrue(consume(regressed, at: 10.25, recognizer: &recognizer, clock: clock).isEmpty)
        XCTAssertEqual(recognizer.rejectedFrameCount, 1)
        XCTAssertEqual(recognizer.state, .waitingForRelease)
        let stillRegressed = try sample(&synthesizer, source: 101.5, ingress: 10.375)
        XCTAssertTrue(stillRegressed.timestamp.isNaN, "Invalid samples must not lower the raw watermark")
        let ordered = try sample(&synthesizer, source: 102.5, ingress: 10.5, halfSize: 0.3)
        XCTAssertTrue(ordered.timestamp.isFinite)
        XCTAssertTrue(consume(ordered, at: 10.5, recognizer: &recognizer, clock: clock).isEmpty)
        XCTAssertEqual(recognizer.fireCount, 0)
    }

    func testNonfiniteFirstCallbackDoesNotPoisonTimeAnchors() throws {
        for invalid in [Double.nan, .infinity, -.infinity] {
            var synthesizer = MultitouchFrameSynthesizer()
            let bad = try sample(&synthesizer, source: invalid, ingress: 10)
            XCTAssertTrue(bad.timestamp.isNaN)
            XCTAssertEqual(bad.phase, .began)
            XCTAssertEqual(bad.contacts.count, 4)
            let firstValid = try sample(&synthesizer, source: 100, ingress: 20)
            XCTAssertEqual(firstValid.timestamp, 20)
            XCTAssertEqual(firstValid.phase, .moved, "Invalid time must not discard contact synthesis")
            XCTAssertEqual(firstValid.contacts.map(\.id), bad.contacts.map(\.id))
            let next = try sample(&synthesizer, source: 100.125, ingress: 20.5)
            XCTAssertEqual(next.timestamp, 20.125, accuracy: 0.000001)
        }
    }

    func testInvalidIngressDoesNotPoisonFirstAnchorOrExistingWatermark() throws {
        for invalid in [Double.nan, .infinity, -.infinity, -1] {
            var synthesizer = MultitouchFrameSynthesizer()
            let badFirst = try sample(&synthesizer, source: 1000, ingress: invalid)
            XCTAssertTrue(badFirst.timestamp.isNaN)
            let valid = try sample(&synthesizer, source: 100, ingress: 20)
            XCTAssertEqual(valid.timestamp, 20)
            let badLater = try sample(&synthesizer, source: 200, ingress: invalid)
            XCTAssertTrue(badLater.timestamp.isNaN)
            let recovery = try sample(&synthesizer, source: 100.125, ingress: 20.5)
            XCTAssertEqual(recovery.timestamp, 20.125, accuracy: 0.000001)
        }
    }

    func testFiniteSourceDeltaOverflowIsInvalidWithoutPoisoningState() throws {
        var synthesizer = MultitouchFrameSynthesizer()
        // Both raw inputs are finite, but subtracting their extremes overflows.
        let first = try sample(&synthesizer, source: -Double.greatestFiniteMagnitude, ingress: 10)
        XCTAssertEqual(first.timestamp, 10)
        let overflow = try sample(&synthesizer, source: Double.greatestFiniteMagnitude, ingress: 10.125)
        XCTAssertTrue(overflow.timestamp.isNaN, "min(infinity, ingress) must not hide arithmetic overflow")
        XCTAssertEqual(overflow.phase, .moved)
        let recovery = try sample(&synthesizer, source: -Double.greatestFiniteMagnitude, ingress: 10.25)
        XCTAssertEqual(recovery.timestamp, 10, "Overflow must change neither anchor nor raw watermark")
    }

    func testDeviceAnchorsAndRawWatermarksRemainIsolated() throws {
        var synthesizer = MultitouchFrameSynthesizer()
        let other = PinchDeviceID(rawValue: 82)
        _ = try sample(&synthesizer, source: 100, ingress: 10)
        let otherFirst = try sample(&synthesizer, source: 5, ingress: 10.125, deviceID: other)
        XCTAssertEqual(otherFirst.phase, .began)
        XCTAssertEqual(otherFirst.timestamp, 10.125)
        _ = try sample(&synthesizer, source: 102, ingress: 10.25)
        let regression = try sample(&synthesizer, source: 101, ingress: 10.375)
        XCTAssertTrue(regression.timestamp.isNaN)
        let otherNext = try sample(&synthesizer, source: 5.125, ingress: 10.5, deviceID: other)
        XCTAssertEqual(otherNext.timestamp, 10.25, accuracy: 0.000001)
        XCTAssertEqual(otherNext.phase, .moved)
        XCTAssertEqual(otherNext.contacts.map(\.id), otherFirst.contacts.map(\.id))
        _ = try sample(&synthesizer, source: 103, ingress: 10.625, contactCount: 0)
        let otherHeld = try sample(&synthesizer, source: 5.25, ingress: 10.75, deviceID: other)
        XCTAssertEqual(otherHeld.timestamp, 10.375, accuracy: 0.000001)
        XCTAssertEqual(otherHeld.phase, .moved)
    }

    func testInvalidEmptyTerminalPreservesSessionUntilValidReleaseThenFirstOutwardWorks() throws {
        let invalidTerminals: [(Double, TimeInterval)] = [
            (99.5, 10.125), (.nan, 10.125), (.infinity, 10.125), (-.infinity, 10.125),
            (100.125, .nan), (100.125, .infinity), (100.125, -.infinity), (100.125, -1)
        ]
        for (invalidSource, invalidIngress) in invalidTerminals {
            var synthesizer = MultitouchFrameSynthesizer()
            let clock = FakePinchClock()
            var recognizer = optionalRecognizer(clock)
            let first = try sample(&synthesizer, source: 100, ingress: 10)
            consume(first, at: 10, recognizer: &recognizer, clock: clock)
            let contactIDs = synthesizer.devices[device]?.contactIDs
            let invalidEnd = try sample(&synthesizer, source: invalidSource, ingress: invalidIngress, contactCount: 0)
            XCTAssertEqual(invalidEnd.phase, .ended)
            XCTAssertTrue(invalidEnd.timestamp.isNaN)
            XCTAssertTrue(invalidEnd.contacts.isEmpty)
            XCTAssertEqual(synthesizer.devices[device]?.sessionOpen, true)
            XCTAssertEqual(synthesizer.devices[device]?.contactIDs, contactIDs)
            XCTAssertTrue(consume(invalidEnd, at: 10.125, recognizer: &recognizer, clock: clock).isEmpty)
            XCTAssertEqual(recognizer.rejectedFrameCount, 1)
            XCTAssertEqual(recognizer.state, .waitingForRelease)

            // Exactly one subsequent valid empty callback must reach the consumer.
            let validEnd = try sample(&synthesizer, source: 100.25, ingress: 10.25, contactCount: 0)
            XCTAssertEqual(validEnd.phase, .ended)
            XCTAssertEqual(validEnd.timestamp, 10.25)
            XCTAssertEqual(synthesizer.devices[device]?.sessionOpen, false)
            XCTAssertEqual(synthesizer.devices[device]?.contactIDs.count, 0)
            XCTAssertTrue(consume(validEnd, at: 10.25, recognizer: &recognizer, clock: clock).isEmpty)
            XCTAssertEqual(recognizer.state, .idle)
            let baseline = try sample(&synthesizer, source: 100.375, ingress: 10.375)
            XCTAssertEqual(baseline.phase, .began)
            XCTAssertTrue(consume(baseline, at: 10.375, recognizer: &recognizer, clock: clock).isEmpty)
            let outward = try sample(&synthesizer, source: 100.5, ingress: 10.5, halfSize: 0.25)
            let events = consume(outward, at: 10.5, recognizer: &recognizer, clock: clock)
            XCTAssertEqual(events.count, 1)
            guard case .hideRequested? = events.first else {
                return XCTFail("The first gesture after a valid release must not be swallowed")
            }
            XCTAssertEqual(recognizer.fireCount, 1)
            XCTAssertEqual(recognizer.rejectedFrameCount, 1)
        }
    }

    func testSkewedStaggeredContactsOutwardReleaseAndInwardProduceOneEventEach() throws {
        var synthesizer = MultitouchFrameSynthesizer()
        let clock = FakePinchClock()
        var recognizer = optionalRecognizer(clock)
        // Anonymous synthetic landing, movement and release, with source deltas
        // ahead of ingress. Keep production thresholds and cooldown unchanged.
        let sequence: [(Double, Double, Double, Int)] = [
            (100, 10, 0.2, 1), (100.1, 10.01, 0.2, 2),
            (100.2, 10.02, 0.2, 4), (100.3, 10.04, 0.21, 4),
            (100.4, 10.06, 0.25, 4), (100.5, 10.08, 0.12, 4),
            (100.6, 10.1, 0.2, 3), (100.7, 10.12, 0.2, 0),
            (100.8, 10.7, 0.2, 4), (100.9, 10.75, 0.18, 4),
            (101, 10.8, 0.15, 4)
        ]
        var events: [PinchEvent] = []
        for (index, entry) in sequence.enumerated() {
            let (source, ingress, halfSize, count) = entry
            let input = try sample(&synthesizer, source: source, ingress: ingress,
                                   halfSize: halfSize, contactCount: count)
            XCTAssertLessThanOrEqual(input.timestamp, ingress)
            let emitted = consume(input, at: ingress, recognizer: &recognizer, clock: clock)
            XCTAssertEqual(emitted.count, index == 4 || index == 10 ? 1 : 0)
            events.append(contentsOf: emitted)
            if index == 7 {
                XCTAssertEqual(input.phase, .ended)
                XCTAssertEqual(recognizer.state, .idle)
            }
        }
        XCTAssertEqual(events.count, 2)
        guard events.count == 2,
              case .hideRequested(let hide) = events[0],
              case .showRequested(let show) = events[1] else {
            return XCTFail("Expected one outward Hide then one inward Show")
        }
        XCTAssertNotEqual(hide.sessionID, show.sessionID)
        XCTAssertEqual(recognizer.fireCount, 2)
        XCTAssertEqual(recognizer.rejectedFrameCount, 0)
    }

    func testBackendCarriesCapturedReceiptWithoutResamplingDuringSynthesisOrDelivery() throws {
        let fakeDevice = FakeMultitouchDevice()
        let backend = MultitouchSupportBackend(deliveryMode: .synchronous,
            libraryFactory: { FakeMultitouchLibrary(devices: [fakeDevice]) })
        var delivered: [PinchFrame] = []
        backend.onFrame = { delivered.append($0) }
        backend.start()
        defer { backend.stop() }
        let contacts = squareContacts(halfSize: 0.2).enumerated().map { index, contact in
            RawTouch(identifier: Int32(index + 1), state: MTTouchState.onSurfaceBit,
                     x: Float(contact.position.x), y: Float(contact.position.y))
        }
        // Fixed, deliberately old receipt samples: neither synthesis nor the
        // callback-to-onFrame path may replace these with the live system clock.
        backend.ingestRawTouches(deviceKey: fakeDevice.registryKey, timestamp: 100, frame: 0,
                                 touches: contacts, receivedAt: 10)
        backend.ingestRawTouches(deviceKey: fakeDevice.registryKey, timestamp: 101, frame: 1,
                                 touches: contacts, receivedAt: 10.125)
        XCTAssertEqual(delivered.count, 2)
        XCTAssertEqual(delivered.map(\.timestamp), [10, 10.125])
        let clock = FakePinchClock()
        var recognizer = optionalRecognizer(clock)
        for input in delivered {
            XCTAssertTrue(consume(input, at: 11, recognizer: &recognizer, clock: clock).isEmpty)
        }
        XCTAssertEqual(recognizer.rejectedFrameCount, 2)
        XCTAssertEqual(recognizer.fireCount, 0)
    }

    @MainActor
    func testIngressBeforeModeCutoffIsNotRenewedAtConsumerDelivery() throws {
        _ = NSApplication.shared
        let clock = FakePinchClock()
        clock.current = 9
        let launcher = LauncherWindowController(
            coordinator: .init(initialState: .visible(screenID: .init(index: 0))),
            reduceMotionProvider: { true })
        let composition = ActivationComposition(launcher: launcher, pinchClock: clock)
        defer { composition.teardownActivationServices() }
        let provider = MockTouchProvider(clock: clock)
        composition.attachTouchProvider(provider, userEnabled: true)
        composition.applyPreferences(.init(fourFingerActivationEnabled: true, fourFingerOutwardHideEnabled: false))
        composition.canHideFromFourFinger = { true }
        var synthesizer = MultitouchFrameSynthesizer()
        let buffered = [
            try sample(&synthesizer, source: 100, ingress: 10),
            try sample(&synthesizer, source: 101, ingress: 10.125, halfSize: 0.25)
        ]
        clock.current = 10.25
        composition.applyPreferences(.init(fourFingerActivationEnabled: true, fourFingerOutwardHideEnabled: true))
        clock.current = 10.375
        for input in buffered {
            XCTAssertLessThan(clock.current - input.timestamp, PinchParameters().dataExpiryInterval,
                              "These frames are fresh enough; only the mode cutoff should exclude them")
            XCTAssertTrue(composition.processFourFingerFrame(input).isEmpty)
        }
        XCTAssertEqual(composition.fourFinger?.recognizer.fireCount, 0)
        for (source, ingress, size) in [(102.0, 10.5, 0.2), (103.0, 10.625, 0.25)] {
            clock.current = ingress
            XCTAssertTrue(composition.processFourFingerFrame(
                try sample(&synthesizer, source: source, ingress: ingress, halfSize: size)).isEmpty)
        }
        XCTAssertEqual(launcher.coordinator.state, .visible(screenID: .init(index: 0)))
        clock.current = 10.75
        XCTAssertTrue(composition.processFourFingerFrame(
            try sample(&synthesizer, source: 104, ingress: 10.75, contactCount: 0)).isEmpty)
        clock.current = 10.875
        XCTAssertTrue(composition.processFourFingerFrame(
            try sample(&synthesizer, source: 105, ingress: 10.875)).isEmpty)
        clock.current = 11
        let effects = composition.processFourFingerFrame(
            try sample(&synthesizer, source: 106, ingress: 11, halfSize: 0.25))
        XCTAssertEqual(effects.count, 1)
        guard case .dismiss(_, .fourFingerOutward, .fourFingerPinch)? = effects.first else {
            return XCTFail("A fresh post-release gesture must still hide")
        }
        XCTAssertEqual(launcher.coordinator.state, .hidden)
        XCTAssertEqual(composition.terminateRequestCount, 0)
    }
}
