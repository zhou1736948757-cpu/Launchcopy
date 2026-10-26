import Foundation
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class FolderDropLatencyProbeTests: XCTestCase {
    private typealias Stage = FolderDropLatencyProbe.Stage

    func testCompleteFolderReleaseRecordsBoundaryAndStageArithmetic() throws {
        let probe = FolderDropLatencyProbe()
        let id = try XCTUnwrap(complete(probe, base: 100))
        let sample = try XCTUnwrap(probe.samples.last)

        XCTAssertEqual(sample.id, id)
        assertMS(sample.eventToWindowMS, 1_000)
        assertMS(sample.windowToOverlayMS, 1_000)
        assertMS(sample.eventToOverlayMS, 2_000)
        assertMS(sample.releaseToReturnMS, 6_000)
        for (index, stage) in Stage.allCases.enumerated() {
            assertMS(sample.stageOffsetsMS[stage], Double(index + 1) * 1_000)
        }
        XCTAssertNil(sample.nextTurnMS)
        XCTAssertNil(sample.willDrawMS)
        XCTAssertEqual(sample.readyIcons, 4)
        XCTAssertEqual(sample.visibleMembers, 6)
        XCTAssertFalse(sample.invalidClock)
    }

    func testClickAndNoOpReleaseDoNotProduceSamples() {
        let probe = FolderDropLatencyProbe()
        probe.noteWindowRelease(eventTimestamp: 10, now: 11)
        XCTAssertNil(probe.endRelease(now: 12, readyIcons: 0, visibleMembers: 0))
        probe.beginRelease(eventTimestamp: 20, now: 21)
        XCTAssertNil(probe.endRelease(now: 22, readyIcons: 1, visibleMembers: 1))
        probe.mark(.commitStart, now: 23)
        probe.noteWillDraw(now: 24)
        probe.noteNextTurn(for: 1, now: 25)
        XCTAssertTrue(probe.samples.isEmpty)
    }

    func testEveryRequiredStageIncludingFolderRefreshMustBePresent() {
        for omitted in Stage.allCases {
            let probe = FolderDropLatencyProbe()
            begin(probe, base: 100)
            for (index, stage) in Stage.allCases.enumerated() where stage != omitted {
                probe.mark(stage, now: 103 + Double(index))
            }
            XCTAssertNil(probe.endRelease(now: 108, readyIcons: 1, visibleMembers: 2),
                         "Missing \(omitted) must discard the release")
            XCTAssertTrue(probe.samples.isEmpty)
        }
    }

    func testUnrelatedMarkersAndTerminalCallbacksCannotCreateSamples() {
        let probe = FolderDropLatencyProbe()
        markAll(probe, base: 100)
        XCTAssertNil(probe.endRelease(now: 108, readyIcons: 4, visibleMembers: 6))
        probe.noteNextTurn(for: 99, now: 110)
        probe.noteWillDraw(now: 111)
        XCTAssertTrue(probe.samples.isEmpty)
    }

    func testNewBeginDiscardsUnfinishedRelease() throws {
        let probe = FolderDropLatencyProbe()
        begin(probe, base: 100)
        markAll(probe, base: 100)
        probe.beginRelease(eventTimestamp: 200, now: 202)
        XCTAssertNil(probe.endRelease(now: 208, readyIcons: 0, visibleMembers: 0))
        XCTAssertTrue(probe.samples.isEmpty)
        XCTAssertEqual(try XCTUnwrap(complete(probe, base: 300)), 1)
    }

    func testMissingWindowBoundaryRemainsNilWithoutInvalidatingClock() throws {
        let probe = FolderDropLatencyProbe()
        _ = complete(probe, base: 100, window: false)
        let sample = try XCTUnwrap(probe.samples.last)
        XCTAssertNil(sample.eventToWindowMS)
        XCTAssertNil(sample.windowToOverlayMS)
        assertMS(sample.eventToOverlayMS, 2_000)
        XCTAssertFalse(sample.invalidClock)
        XCTAssertTrue(probe.summary.contains("eventToWindowMS: unavailable"))
    }

    func testMismatchedWindowPairIsConsumedAndCannotBeReused() throws {
        let probe = FolderDropLatencyProbe()
        probe.noteWindowRelease(eventTimestamp: 100, now: 101)
        _ = complete(probe, base: 200, window: false)
        let unrelated = try XCTUnwrap(probe.samples.last)
        XCTAssertNil(unrelated.eventToWindowMS)
        XCTAssertNil(unrelated.windowToOverlayMS)
        XCTAssertFalse(unrelated.invalidClock)

        _ = complete(probe, base: 100, window: false)
        let later = try XCTUnwrap(probe.samples.last)
        XCTAssertNil(later.eventToWindowMS)
        XCTAssertNil(later.windowToOverlayMS)
    }

    func testOnlyLatestPendingWindowPairIsRetainedAndConsumedOnce() throws {
        let probe = FolderDropLatencyProbe()
        probe.noteWindowRelease(eventTimestamp: 50, now: 51)
        probe.noteWindowRelease(eventTimestamp: 100, now: 101)
        _ = complete(probe, base: 100, window: false)
        assertMS(try XCTUnwrap(probe.samples.last).eventToWindowMS, 1_000)
        _ = complete(probe, base: 100, window: false)
        XCTAssertNil(try XCTUnwrap(probe.samples.last).eventToWindowMS)
    }

    func testDiscardedReleaseDoesNotLeakWindowOrStageState() throws {
        let probe = FolderDropLatencyProbe()
        begin(probe, base: 100)
        probe.mark(.commitStart, now: 103)
        XCTAssertNil(probe.endRelease(now: 104, readyIcons: 1, visibleMembers: 1))
        _ = complete(probe, base: 100, window: false)
        let sample = try XCTUnwrap(probe.samples.last)
        XCTAssertNil(sample.eventToWindowMS)
        assertMS(sample.stageOffsetsMS[.commitStart], 1_000)
        XCTAssertFalse(sample.invalidClock)
    }

    func testFirstStageMarkerWinsIncludingInvalidFirstOccurrence() throws {
        let probe = FolderDropLatencyProbe()
        begin(probe, base: 100)
        probe.mark(.commitStart, now: 103)
        probe.mark(.commitStart, now: .nan)
        probe.mark(.providerReturn, now: .nan)
        probe.mark(.providerReturn, now: 104)
        probe.mark(.presentationReturn, now: 105)
        probe.mark(.folderRefreshReturn, now: 106)
        probe.mark(.commitReturn, now: 107)
        XCTAssertNotNil(probe.endRelease(now: 108, readyIcons: 4, visibleMembers: 6))
        let sample = try XCTUnwrap(probe.samples.last)
        assertMS(sample.stageOffsetsMS[.commitStart], 1_000)
        XCTAssertNil(sample.stageOffsetsMS[.providerReturn])
        XCTAssertTrue(sample.invalidClock)
    }

    func testDuplicateValidStageCannotOverwriteOrAffectOrder() throws {
        let probe = FolderDropLatencyProbe()
        begin(probe, base: 100)
        for (index, stage) in Stage.allCases.enumerated() {
            probe.mark(stage, now: 103 + Double(index))
            probe.mark(stage, now: 1_000)
        }
        _ = probe.endRelease(now: 108, readyIcons: 4, visibleMembers: 6)
        let sample = try XCTUnwrap(probe.samples.last)
        assertMS(sample.stageOffsetsMS[.commitStart], 1_000)
        assertMS(sample.stageOffsetsMS[.commitReturn], 5_000)
        XCTAssertFalse(sample.invalidClock)
    }

    func testOutOfOrderStagesAreFlaggedEvenWithForwardClocks() throws {
        let probe = FolderDropLatencyProbe()
        begin(probe, base: 100)
        probe.mark(.providerReturn, now: 103)
        probe.mark(.commitStart, now: 104)
        probe.mark(.presentationReturn, now: 105)
        probe.mark(.folderRefreshReturn, now: 106)
        probe.mark(.commitReturn, now: 107)
        XCTAssertNotNil(probe.endRelease(now: 108, readyIcons: 4, visibleMembers: 6))
        let sample = try XCTUnwrap(probe.samples.last)
        XCTAssertTrue(sample.invalidClock)
        XCTAssertNil(sample.stageOffsetsMS[.providerReturn])
        XCTAssertNil(sample.stageOffsetsMS[.commitStart])
    }

    func testBackwardStageClockIsUnavailableRatherThanClampedToZero() throws {
        let probe = FolderDropLatencyProbe()
        begin(probe, base: 100)
        probe.mark(.commitStart, now: 104)
        probe.mark(.providerReturn, now: 103)
        probe.mark(.presentationReturn, now: 105)
        probe.mark(.folderRefreshReturn, now: 106)
        probe.mark(.commitReturn, now: 107)
        _ = probe.endRelease(now: 108, readyIcons: 4, visibleMembers: 6)
        let sample = try XCTUnwrap(probe.samples.last)
        XCTAssertTrue(sample.invalidClock)
        XCTAssertNil(sample.stageOffsetsMS[.providerReturn])
        assertMS(sample.stageOffsetsMS[.presentationReturn], 3_000)
    }

    func testInvalidEventClocksDoNotSuppressValidOverlayDurations() throws {
        for clock in [-1.0, Double.nan, Double.infinity, -Double.infinity, 103] {
            let probe = FolderDropLatencyProbe()
            probe.beginRelease(eventTimestamp: clock, now: 102)
            markAll(probe, base: 100)
            _ = probe.endRelease(now: 108, readyIcons: 4, visibleMembers: 6)
            let sample = try XCTUnwrap(probe.samples.last)
            XCTAssertTrue(sample.invalidClock)
            XCTAssertNil(sample.eventToOverlayMS)
            assertMS(sample.releaseToReturnMS, 6_000)
        }
    }

    func testInvalidMatchingWindowClockIsFlaggedButUnrelatedClockIsIgnored() throws {
        for clock in [-1.0, Double.nan, Double.infinity, 99, 103] {
            let probe = FolderDropLatencyProbe()
            probe.noteWindowRelease(eventTimestamp: 100, now: clock)
            _ = complete(probe, base: 100, window: false)
            let sample = try XCTUnwrap(probe.samples.last)
            XCTAssertTrue(sample.invalidClock)
            XCTAssertTrue(sample.eventToWindowMS == nil || sample.windowToOverlayMS == nil)
            assertMS(sample.eventToOverlayMS, 2_000)
        }
        let probe = FolderDropLatencyProbe()
        probe.noteWindowRelease(eventTimestamp: 99, now: .nan)
        _ = complete(probe, base: 100, window: false)
        XCTAssertFalse(try XCTUnwrap(probe.samples.last).invalidClock)
    }

    func testInvalidReleaseOriginsLeaveAllRelativeDurationsUnavailable() throws {
        for clock in [-1.0, Double.nan, Double.infinity, -Double.infinity] {
            let probe = FolderDropLatencyProbe()
            probe.beginRelease(eventTimestamp: 100, now: clock)
            markAll(probe, base: 100)
            let id = try XCTUnwrap(probe.endRelease(now: 108, readyIcons: 4, visibleMembers: 6))
            probe.noteNextTurn(for: id, now: 109)
            probe.noteWillDraw(now: 110)
            let sample = try XCTUnwrap(probe.samples.last)
            XCTAssertTrue(sample.invalidClock)
            XCTAssertNil(sample.eventToOverlayMS)
            XCTAssertNil(sample.releaseToReturnMS)
            XCTAssertTrue(sample.stageOffsetsMS.isEmpty)
            XCTAssertNil(sample.nextTurnMS)
            XCTAssertNil(sample.willDrawMS)
        }
    }

    func testInvalidStageClocksLeaveTheirOffsetsUnavailable() throws {
        for stage in Stage.allCases {
            for clock in [-1.0, Double.nan, Double.infinity, -Double.infinity, 101] {
                let probe = FolderDropLatencyProbe()
                begin(probe, base: 100)
                for (index, marker) in Stage.allCases.enumerated() {
                    probe.mark(marker, now: marker == stage ? clock : 103 + Double(index))
                }
                _ = probe.endRelease(now: 108, readyIcons: 4, visibleMembers: 6)
                let sample = try XCTUnwrap(probe.samples.last)
                XCTAssertTrue(sample.invalidClock)
                XCTAssertNil(sample.stageOffsetsMS[stage])
            }
        }
    }

    func testInvalidOrBackwardReturnCannotBecomeSuccessfulZero() throws {
        for clock in [-1.0, Double.nan, Double.infinity, -Double.infinity, 106] {
            let probe = FolderDropLatencyProbe()
            begin(probe, base: 100)
            markAll(probe, base: 100)
            let id = try XCTUnwrap(probe.endRelease(now: clock, readyIcons: 4, visibleMembers: 6))
            probe.noteNextTurn(for: id, now: 109)
            probe.noteWillDraw(now: 110)
            let sample = try XCTUnwrap(probe.samples.last)
            XCTAssertTrue(sample.invalidClock)
            XCTAssertNil(sample.releaseToReturnMS)
            XCTAssertNil(sample.nextTurnMS)
            XCTAssertNil(sample.willDrawMS)
        }
    }

    func testFiniteClockArithmeticOverflowIsUnavailable() throws {
        let probe = FolderDropLatencyProbe()
        let largeClock = Double.greatestFiniteMagnitude / 2
        probe.noteWindowRelease(eventTimestamp: 0, now: largeClock)
        probe.beginRelease(eventTimestamp: 0, now: largeClock)
        for stage in Stage.allCases { probe.mark(stage, now: largeClock) }
        _ = probe.endRelease(now: largeClock, readyIcons: 0, visibleMembers: 0)
        let sample = try XCTUnwrap(probe.samples.last)
        XCTAssertTrue(sample.invalidClock)
        XCTAssertNil(sample.eventToWindowMS)
        XCTAssertNil(sample.eventToOverlayMS)
        assertMS(sample.windowToOverlayMS, 0)
        assertMS(sample.releaseToReturnMS, 0)
        XCTAssertFalse(probe.summary.lowercased().contains("inf"))
        XCTAssertFalse(probe.summary.lowercased().contains("nan"))
    }

    func testEqualValidClocksCanRecordRealZeroDurations() throws {
        let probe = FolderDropLatencyProbe()
        probe.noteWindowRelease(eventTimestamp: 0, now: 0)
        probe.beginRelease(eventTimestamp: 0, now: 0)
        for stage in Stage.allCases { probe.mark(stage, now: 0) }
        let id = try XCTUnwrap(probe.endRelease(now: 0, readyIcons: 0, visibleMembers: 0))
        probe.noteNextTurn(for: id, now: 0)
        probe.noteWillDraw(now: 0)
        let sample = try XCTUnwrap(probe.samples.last)
        XCTAssertFalse(sample.invalidClock)
        for value in [sample.eventToWindowMS, sample.windowToOverlayMS, sample.eventToOverlayMS,
                      sample.releaseToReturnMS, sample.nextTurnMS, sample.willDrawMS] {
            assertMS(value, 0)
        }
        for stage in Stage.allCases { assertMS(sample.stageOffsetsMS[stage], 0) }
    }

    func testNextTurnUsesReleaseOriginAndFirstMarkerWins() throws {
        let probe = FolderDropLatencyProbe()
        let id = try XCTUnwrap(complete(probe, base: 100))
        probe.noteNextTurn(for: id, now: 109)
        probe.noteNextTurn(for: id, now: .nan)
        probe.noteNextTurn(for: id, now: 120)
        let sample = try XCTUnwrap(probe.samples.last)
        assertMS(sample.nextTurnMS, 7_000)
        XCTAssertFalse(sample.invalidClock)
    }

    func testInvalidFirstNextTurnIsFlaggedAndCannotBeOverwritten() throws {
        for clock in [-1.0, Double.nan, Double.infinity, 107] {
            let probe = FolderDropLatencyProbe()
            let id = try XCTUnwrap(complete(probe, base: 100))
            probe.noteNextTurn(for: id, now: clock)
            probe.noteNextTurn(for: id, now: 109)
            let sample = try XCTUnwrap(probe.samples.last)
            XCTAssertNil(sample.nextTurnMS)
            XCTAssertTrue(sample.invalidClock)
        }
    }

    func testLateNextTurnUpdatesOnlyItsRetainedSample() throws {
        let probe = FolderDropLatencyProbe()
        let first = try XCTUnwrap(complete(probe, base: 100))
        let second = try XCTUnwrap(complete(probe, base: 200))
        probe.noteNextTurn(for: first, now: 210)
        probe.noteNextTurn(for: second, now: 211)
        assertMS(probe.samples[0].nextTurnMS, 108_000)
        assertMS(probe.samples[1].nextTurnMS, 9_000)
        probe.noteNextTurn(for: second + 100, now: .nan)
        XCTAssertFalse(probe.samples[1].invalidClock)
    }

    func testWillDrawRecordsOnlyLatestCompletedSampleAndFirstValidNotification() throws {
        let probe = FolderDropLatencyProbe()
        _ = complete(probe, base: 100)
        _ = complete(probe, base: 200)
        probe.noteWillDraw(now: 210)
        probe.noteWillDraw(now: .nan)
        probe.noteWillDraw(now: 220)
        XCTAssertNil(probe.samples[0].willDrawMS)
        assertMS(probe.samples[1].willDrawMS, 8_000)
        XCTAssertFalse(probe.samples[1].invalidClock)
    }

    func testInvalidWillDrawAllowsLaterValidNotificationWithoutClearingInvalidity() throws {
        for clock in [-1.0, Double.nan, Double.infinity, 107] {
            let probe = FolderDropLatencyProbe()
            _ = complete(probe, base: 100)
            probe.noteWillDraw(now: clock)
            XCTAssertNil(try XCTUnwrap(probe.samples.last).willDrawMS)
            probe.noteWillDraw(now: 110)
            let sample = try XCTUnwrap(probe.samples.last)
            assertMS(sample.willDrawMS, 8_000)
            XCTAssertTrue(sample.invalidClock)
        }
    }

    func testDrawDuringReleaseIsNotACompletedBoundary() throws {
        let probe = FolderDropLatencyProbe()
        _ = complete(probe, base: 100)
        begin(probe, base: 200)
        markAll(probe, base: 200)
        probe.noteWillDraw(now: 207)
        XCTAssertNil(probe.samples[0].willDrawMS)
        _ = probe.endRelease(now: 208, readyIcons: 4, visibleMembers: 6)
        probe.noteWillDraw(now: 210)
        XCTAssertNil(probe.samples[0].willDrawMS)
        assertMS(probe.samples[1].willDrawMS, 8_000)
    }

    func testAsyncMarkersCanArriveInEitherOrder() throws {
        let probe = FolderDropLatencyProbe()
        let id = try XCTUnwrap(complete(probe, base: 100))
        probe.noteWillDraw(now: 109)
        probe.noteNextTurn(for: id, now: 110)
        let sample = try XCTUnwrap(probe.samples.last)
        assertMS(sample.willDrawMS, 7_000)
        assertMS(sample.nextTurnMS, 8_000)
        XCTAssertFalse(sample.invalidClock)
    }

    func testDrawClockCannotRegressBehindAnObservedNextTurn() throws {
        let probe = FolderDropLatencyProbe()
        let id = try XCTUnwrap(complete(probe, base: 100))
        probe.noteNextTurn(for: id, now: 110)
        probe.noteWillDraw(now: 109)
        let sample = try XCTUnwrap(probe.samples.last)
        assertMS(sample.nextTurnMS, 8_000)
        XCTAssertNil(sample.willDrawMS)
        XCTAssertTrue(sample.invalidClock)
        probe.noteWillDraw(now: 111)
        assertMS(probe.samples.last?.willDrawMS, 9_000)
        XCTAssertTrue(try XCTUnwrap(probe.samples.last).invalidClock)
    }

    func testNextTurnClockCannotRegressBehindAnObservedDraw() throws {
        let probe = FolderDropLatencyProbe()
        let id = try XCTUnwrap(complete(probe, base: 100))
        probe.noteWillDraw(now: 110)
        probe.noteNextTurn(for: id, now: 109)
        let sample = try XCTUnwrap(probe.samples.last)
        assertMS(sample.willDrawMS, 8_000)
        XCTAssertNil(sample.nextTurnMS)
        XCTAssertTrue(sample.invalidClock)
    }

    func testRetentionIsCappedAtEightAndEvictedCallbacksCannotAttach() throws {
        let probe = FolderDropLatencyProbe()
        var ids: [UInt64] = []
        for ordinal in 1...12 {
            ids.append(try XCTUnwrap(complete(probe, base: Double(ordinal * 100))))
            XCTAssertLessThanOrEqual(probe.samples.count, 8)
        }
        XCTAssertEqual(ids, (1...12).map { UInt64($0) })
        XCTAssertEqual(probe.samples.map(\.id), Array(ids.suffix(8)))
        probe.noteNextTurn(for: ids[0], now: .nan)
        XCTAssertTrue(probe.samples.allSatisfy { $0.nextTurnMS == nil && !$0.invalidClock })
        XCTAssertEqual(probe.summary.components(separatedBy: "Sample ordinal: ").count - 1, 3)
        XCTAssertTrue(probe.summary.contains("Sample ordinal: 10\n"))
        XCTAssertTrue(probe.summary.contains("Sample ordinal: 11\n"))
        XCTAssertTrue(probe.summary.contains("Sample ordinal: 12\n"))
        XCTAssertFalse(probe.summary.contains("Sample ordinal: 9\n"))
    }

    func testResetClearsAllPendingStateWithoutReusingIDs() throws {
        let probe = FolderDropLatencyProbe()
        let oldID = try XCTUnwrap(complete(probe, base: 100))
        begin(probe, base: 200)
        markAll(probe, base: 200)
        probe.noteWindowRelease(eventTimestamp: 300, now: 301)
        probe.reset()
        XCTAssertTrue(probe.samples.isEmpty)
        XCTAssertNil(probe.endRelease(now: 208, readyIcons: 4, visibleMembers: 6))
        probe.noteNextTurn(for: oldID, now: .nan)
        probe.noteWillDraw(now: .nan)
        let newID = try XCTUnwrap(complete(probe, base: 300, window: false))
        XCTAssertGreaterThan(newID, oldID)
        probe.noteNextTurn(for: oldID, now: 310)
        let sample = try XCTUnwrap(probe.samples.last)
        XCTAssertNil(sample.eventToWindowMS)
        XCTAssertNil(sample.nextTurnMS)
        XCTAssertNil(sample.willDrawMS)
        XCTAssertFalse(sample.invalidClock)
        probe.reset()
        probe.reset()
        XCTAssertGreaterThan(try XCTUnwrap(complete(probe, base: 400)), newID)
    }

    func testReportContainsOnlyFixedLabelsCountsOrdinalsAndDurations() throws {
        let probe = FolderDropLatencyProbe()
        _ = complete(probe, base: 8_765_432)
        XCTAssertEqual(probe.summary, """
        Folder drop timing
        Retained samples: 1; limit: 8; shown: 1
        viewWillDraw is a pre-draw boundary.
        Sample ordinal: 1
        eventToWindowMS: 1000.000
        windowToOverlayMS: 1000.000
        eventToOverlayMS: 2000.000
        releaseToReturnMS: 6000.000
        commitStartMS: 1000.000
        providerReturnMS: 2000.000
        presentationReturnMS: 3000.000
        folderRefreshReturnMS: 4000.000
        commitReturnMS: 5000.000
        nextTurnMS: unavailable
        willDrawMS: unavailable
        readyIcons: 4; visibleMembers: 6
        invalidClock: 0
        """)
        XCTAssertFalse(probe.summary.contains("8765432"))
        let shifted = FolderDropLatencyProbe()
        _ = complete(shifted, base: 100)
        XCTAssertEqual(probe.summary, shifted.summary, "Absolute clock origins must not reach the report")
    }

    func testReportSurfacesInvalidityAndUnavailableBoundaries() {
        let probe = FolderDropLatencyProbe()
        probe.beginRelease(eventTimestamp: .nan, now: 102)
        markAll(probe, base: 100)
        _ = probe.endRelease(now: .nan, readyIcons: 0, visibleMembers: 6)
        XCTAssertTrue(probe.summary.contains("eventToWindowMS: unavailable"))
        XCTAssertTrue(probe.summary.contains("eventToOverlayMS: unavailable"))
        XCTAssertTrue(probe.summary.contains("releaseToReturnMS: unavailable"))
        XCTAssertTrue(probe.summary.contains("invalidClock: 1"))
        XCTAssertFalse(probe.summary.lowercased().contains("nan"))
        XCTAssertFalse(probe.summary.lowercased().contains("inf"))
    }

    // Synthetic seconds: event=base, window=base+1, overlay=base+2,
    // owner stages=base+3...7, overlay return=base+8.
    private func begin(_ probe: FolderDropLatencyProbe, base: Double, window: Bool = true) {
        if window { probe.noteWindowRelease(eventTimestamp: base, now: base + 1) }
        probe.beginRelease(eventTimestamp: base, now: base + 2)
    }

    private func markAll(_ probe: FolderDropLatencyProbe, base: Double) {
        for (index, stage) in Stage.allCases.enumerated() {
            probe.mark(stage, now: base + 3 + Double(index))
        }
    }

    @discardableResult
    private func complete(_ probe: FolderDropLatencyProbe, base: Double, window: Bool = true) -> UInt64? {
        begin(probe, base: base, window: window)
        markAll(probe, base: base)
        return probe.endRelease(now: base + 8, readyIcons: 4, visibleMembers: 6)
    }

    private func assertMS(_ actual: Double?, _ expected: Double,
                          file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else {
            XCTFail("Expected a measured duration, received an unavailable boundary", file: file, line: line)
            return
        }
        XCTAssertEqual(actual, expected, accuracy: 0.000_001, file: file, line: line)
    }
}
