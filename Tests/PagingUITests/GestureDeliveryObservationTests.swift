import XCTest
@testable import PagingPrototypeApp

/// Synthetic inputs only. Main owns serial build/test execution and composition integration.
final class GestureDeliveryObservationTests: XCTestCase {
    private func input(_ timestamp: TimeInterval = 10, count: Int = 4,
                       phase: PinchFramePhase = .moved) -> PinchFrame {
        PinchFrame(
            deviceID: PinchDeviceID(rawValue: 987_654_321), timestamp: timestamp, phase: phase,
            contacts: (0..<count).map {
                PinchContact(id: PinchContactID(rawValue: 123_456_789 + $0),
                             position: PinchPoint(x: 0.123456789, y: 0.987654321))
            }
        )
    }

    private var token: PinchEventToken {
        PinchEventToken(generation: 765_432_109, sessionID: PinchSessionID(rawValue: 876_543_210))
    }

    private func record(_ observation: inout GestureDeliveryObservation,
                        _ frame: PinchFrame? = nil, now: TimeInterval = 10,
                        admission: Bool = false, cutoff: TimeInterval? = nil,
                        expiry: TimeInterval = 0.5) {
        observation.record(frame: frame ?? input(), now: now, admission: admission,
                           cutoff: cutoff, expiry: expiry)
    }

    func testDefaultInitializationHasOnlyZeroCounters() {
        let observation = GestureDeliveryObservation()
        XCTAssertEqual(GestureDeliveryObservation.maxFrames, 20_000)
        XCTAssertEqual(observation.summary,
            "frames=0 maxFrames=20000 fourContactFrames=0 emptyTerminalFrames=0 "
                + "admittedFourContactFrames=0 preCutoffFrames=0 futureFrames=0 expiredFrames=0 "
                + "nonfiniteTimeFrames=0 showEvents=0 hideEvents=0 acceptedHides=0")
    }

    func testFourContactsAndAdmissionAreCountedIndependentlyOfFrameValidity() {
        var observation = GestureDeliveryObservation()
        for count in [0, 1, 2, 3, 4, 5, 8, 9] {
            record(&observation, input(count: count), admission: true)
        }
        record(&observation, admission: false)
        record(&observation, input(.nan), admission: true)
        XCTAssertEqual(observation.frames, 10)
        XCTAssertEqual(observation.fourContactFrames, 3)
        XCTAssertEqual(observation.admittedFourContactFrames, 2)
        XCTAssertEqual(observation.nonfiniteTimeFrames, 1)
    }

    func testEmptyTerminalIncludesZeroContactMovedButNotBeganOrHeldTerminal() {
        var observation = GestureDeliveryObservation()
        let phases: [PinchFramePhase] = [.began, .moved, .ended, .cancelled]
        for phase in phases {
            record(&observation, input(count: 0, phase: phase))
            record(&observation, input(count: 4, phase: phase))
        }
        XCTAssertEqual(observation.frames, 8)
        XCTAssertEqual(observation.emptyTerminalFrames, 3)
    }

    func testCutoffComparisonIsStrictAndIndependentOfExpiry() {
        var observation = GestureDeliveryObservation()
        record(&observation, input(9), cutoff: 10)
        record(&observation, input(10), cutoff: 10)
        record(&observation, input(11), now: 11, cutoff: 10)
        record(&observation, input(9), cutoff: nil)
        XCTAssertEqual(observation.preCutoffFrames, 1)
        XCTAssertEqual(observation.expiredFrames, 2)
    }

    func testFutureComparisonHasNoExpiryTolerance() {
        var observation = GestureDeliveryObservation()
        record(&observation, input(10))
        record(&observation, input(Double(10).nextUp))
        record(&observation, input(11), cutoff: 12)
        XCTAssertEqual(observation.futureFrames, 2)
        XCTAssertEqual(observation.expiredFrames, 0)
        XCTAssertEqual(observation.preCutoffFrames, 1)
    }

    func testExpiryMatchesRecognizerToleranceAndUsesSuppliedWindow() {
        var observation = GestureDeliveryObservation()
        record(&observation, input(9.5))
        record(&observation, input(9.5 - 0.5e-9))
        record(&observation, input(9.5 - 2e-9))
        record(&observation, input(9), expiry: 2)
        record(&observation, input(9), expiry: 0.25)
        XCTAssertEqual(observation.expiredFrames, 2)
        XCTAssertEqual(observation.futureFrames, 0)
    }

    func testNonfiniteFrameOrClockCountsOnceWithoutAgeClassification() {
        var observation = GestureDeliveryObservation()
        for invalid in [Double.nan, .infinity, -.infinity] {
            record(&observation, input(invalid))
            record(&observation, now: invalid)
            record(&observation, input(invalid), now: invalid)
        }
        XCTAssertEqual(observation.frames, 9)
        XCTAssertEqual(observation.nonfiniteTimeFrames, 9)
        XCTAssertEqual(observation.futureFrames, 0)
        XCTAssertEqual(observation.expiredFrames, 0)
    }

    func testEventKindsAndAcceptedFlushResultsAreSeparateCounters() {
        var observation = GestureDeliveryObservation()
        record(&observation)
        observation.record(events: [.showRequested(token: token), .hideRequested(token: token),
                                    .hideRequested(token: token)], hideRequested: false)
        record(&observation)
        observation.record(events: [.hideRequested(token: token)], hideRequested: true)
        XCTAssertEqual(observation.showEvents, 1)
        XCTAssertEqual(observation.hideEvents, 3)
        XCTAssertEqual(observation.acceptedHides, 1)
    }

    func testEventsRequireOneUnconsumedRecordedFrame() {
        var observation = GestureDeliveryObservation()
        let events: [PinchEvent] = [.showRequested(token: token), .hideRequested(token: token)]
        observation.record(events: events, hideRequested: true)
        XCTAssertEqual(observation.showEvents, 0)
        XCTAssertEqual(observation.acceptedHides, 0)
        record(&observation)
        observation.record(events: [], hideRequested: false)
        observation.record(events: events, hideRequested: true)
        XCTAssertEqual(observation.hideEvents, 0)
        XCTAssertEqual(observation.acceptedHides, 0)
        record(&observation)
        observation.record(events: events, hideRequested: true)
        observation.record(events: events, hideRequested: true)
        XCTAssertEqual(observation.showEvents, 1)
        XCTAssertEqual(observation.hideEvents, 1)
        XCTAssertEqual(observation.acceptedHides, 1)
    }

    func testLastAllowedFrameIncludesItsFlushThenAllObservationsFreeze() {
        var observation = GestureDeliveryObservation()
        let events: [PinchEvent] = [.showRequested(token: token), .hideRequested(token: token)]
        for _ in 0..<GestureDeliveryObservation.maxFrames {
            record(&observation, admission: true)
            observation.record(events: events, hideRequested: true)
        }
        XCTAssertEqual(observation.frames, 20_000)
        XCTAssertEqual(observation.fourContactFrames, 20_000)
        XCTAssertEqual(observation.admittedFourContactFrames, 20_000)
        XCTAssertEqual(observation.showEvents, 20_000)
        XCTAssertEqual(observation.hideEvents, 20_000)
        XCTAssertEqual(observation.acceptedHides, 20_000)
        let snapshot = observation.summary
        for _ in 0..<10 {
            record(&observation, input(.nan, count: 0, phase: .ended), now: .infinity, cutoff: 20)
            observation.record(events: events, hideRequested: true)
        }
        XCTAssertEqual(observation.summary, snapshot)
    }

    func testSkippedFinalFlushCannotCountEventsFromAnOverLimitFrame() {
        var observation = GestureDeliveryObservation()
        for _ in 0..<GestureDeliveryObservation.maxFrames {
            record(&observation, input(9), cutoff: 10)
        }
        record(&observation)
        observation.record(events: [.hideRequested(token: token)], hideRequested: true)
        XCTAssertEqual(observation.preCutoffFrames, 20_000)
        XCTAssertEqual(observation.hideEvents, 0)
        XCTAssertEqual(observation.acceptedHides, 0)
    }

    func testUnexpectedlyLargeEventBatchSaturatesWithoutRetainingIt() {
        var observation = GestureDeliveryObservation()
        record(&observation)
        observation.record(events: Array(repeating: .showRequested(token: token), count: 20_001)
            + Array(repeating: .hideRequested(token: token), count: 20_001), hideRequested: true)
        XCTAssertEqual(observation.showEvents, 20_000)
        XCTAssertEqual(observation.hideEvents, 20_000)
        XCTAssertEqual(observation.acceptedHides, 1)
    }

    func testResetByReplacementClearsCountersAndPendingFlush() {
        var observation = GestureDeliveryObservation()
        record(&observation, input(9), admission: true, cutoff: 10)
        observation.record(events: [.hideRequested(token: token)], hideRequested: true)
        record(&observation)
        observation = GestureDeliveryObservation()
        observation.record(events: [.hideRequested(token: token)], hideRequested: true)
        XCTAssertEqual(observation.summary, GestureDeliveryObservation().summary)
    }

    func testStoredStateAndSummaryContainOnlyBoundedAggregates() {
        var observation = GestureDeliveryObservation()
        record(&observation, input(123_456.789), now: 123_456.789, admission: true)
        observation.record(events: [.hideRequested(token: token)], hideRequested: true)
        let snapshot = observation.summary
        XCTAssertEqual(observation.summary, snapshot, "Reading the report must not mutate counters")
        for field in Mirror(reflecting: observation).children {
            XCTAssertTrue(field.value is Int || field.value is Bool,
                          "Stored state must contain only scalar counters and the flush flag")
        }
        XCTAssertLessThanOrEqual(snapshot.utf8.count, 512)
        for raw in ["987654321", "123456789", "0.123456789", "0.987654321", "123456.789",
                    "765432109", "876543210", "timestamp", "deviceID", "sessionID", "token",
                    "showRequested", "hideRequested"] {
            XCTAssertFalse(snapshot.contains(raw), "The report must not retain or render raw input")
        }
    }
    func testPresentationReportContainsOnlyStateKindAndHonestRequestBoundary() {
        let cases: [(LauncherPresentationState, String)] = [
            (.hidden, "hidden"), (.presenting(requestID: 987654, targetScreen: .init(index: 123456)), "presenting"),
            (.visible(screenID: .init(index: 123456)), "visible"),
            (.dismissing(requestID: 987654, reason: .fourFingerOutward), "dismissing"),
            (.suspended(reason: .sleep), "suspended"), (.terminating, "terminating")
        ]
        for (state, kind) in cases {
            let report = GestureDeliveryObservation.presentationSummary(state)
            XCTAssertTrue(report.hasPrefix("presentation=\(kind);"))
            XCTAssertTrue(report.contains("request dequeues, not visible effects"))
            XCTAssertFalse(report.contains("987654"))
            XCTAssertFalse(report.contains("123456"))
        }
    }

}
