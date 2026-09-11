//
//  TelemetryEventTests.swift
//  PagingTelemetryTests
//
//  TelemetryEvent 编码/解码与阶段常量测试。
//

import Foundation
import XCTest
@testable import PagingTelemetry

final class TelemetryEventTests: XCTestCase {

    func testPageCacheOutcomeRawValues() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for outcome in [PageCacheOutcome.notApplicable, .hit, .miss] {
            let data = try encoder.encode(outcome)
            let decoded = try decoder.decode(PageCacheOutcome.self, from: data)
            XCTAssertEqual(decoded, outcome)
            XCTAssertEqual(decoded.rawValue, outcome.rawValue)
        }
    }

    func testJSONKeysAreSnakeCaseAndStable() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var event = TelemetryEvent(phase: TelemetryPhase.gestureBegan)
        event.gestureID = 1
        event.transitionID = 2
        event.inputDelta = 0.5
        event.visualOffset = 0.5
        event.semanticCurrentPage = 0
        event.proposedTarget = 1
        event.committedPage = 1
        event.frameInterval = 0.016
        event.pageHostViewCount = 2
        event.pagePrepareCache = .miss
        event.transitionToken = 99
        event.staleCallbackFired = true
        event.interruptSourceOffset = 0.25
        event.reduceMotionEnabled = true

        let data = try encoder.encode(event)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let keys = Set(object.keys)

        // 17 必需键全部以 snake_case 出现，且无额外必需键
        XCTAssertTrue(requiredTelemetryKeys.isSubset(of: keys))
        for key in requiredTelemetryKeys {
            XCTAssertFalse(key.contains(where: { $0.isUppercase }), "键应为 snake_case: \(key)")
        }
        // 扩展键
        XCTAssertEqual(object["transition_token"] as? UInt64, 99)
        XCTAssertEqual(object["stale_callback_fired"] as? Bool, true)
        XCTAssertEqual(object["interrupt_source_offset"] as? Double, 0.25)
        XCTAssertEqual(object["reduce_motion_enabled"] as? Bool, true)
        XCTAssertEqual(object["page_prepare_cache"] as? String, "miss")
        XCTAssertEqual(object["event_phase"] as? String, "gesture.began")
    }

    func testRoundTripWithDecoder() throws {
        let encoder = JSONEncoder()
        var event = TelemetryEvent(phase: TelemetryPhase.transitionCommit)
        event.runID = "rt"
        event.timestamp = 123.456
        event.interruptionCount = 2
        event.staleRejectionCount = 3
        event.layoutCount = 4
        event.teardownCallbackCount = 5

        let data = try encoder.encode(event)
        let decoded = try JSONDecoder().decode(TelemetryEvent.self, from: data)
        XCTAssertEqual(decoded, event)
        XCTAssertEqual(decoded.phase, TelemetryPhase.transitionCommit)
        XCTAssertEqual(decoded.interruptionCount, 2)
        XCTAssertEqual(decoded.staleRejectionCount, 3)
    }

    func testOptionalExtrasAreOmittedWhenNil() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(TelemetryEvent(phase: TelemetryPhase.frame))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNil(object["transition_token"])
        XCTAssertNil(object["stale_callback_fired"])
        XCTAssertNil(object["interrupt_source_offset"])
        XCTAssertNil(object["reduce_motion_enabled"])
    }

    func testPhaseConstantsAreStableStrings() {
        XCTAssertEqual(TelemetryPhase.runBegin, "run.begin")
        XCTAssertEqual(TelemetryPhase.runEnd, "run.end")
        XCTAssertEqual(TelemetryPhase.gestureBegan, "gesture.began")
        XCTAssertEqual(TelemetryPhase.gestureChanged, "gesture.changed")
        XCTAssertEqual(TelemetryPhase.gestureEnded, "gesture.ended")
        XCTAssertEqual(TelemetryPhase.gestureMomentum, "gesture.momentum")
        XCTAssertEqual(TelemetryPhase.gestureCancelled, "gesture.cancelled")
        XCTAssertEqual(TelemetryPhase.transitionBegin, "transition.begin")
        XCTAssertEqual(TelemetryPhase.transitionCommit, "transition.commit")
        XCTAssertEqual(TelemetryPhase.transitionStaleRejected, "transition.stale_rejected")
        XCTAssertEqual(TelemetryPhase.transitionCancelled, "transition.cancelled")
        XCTAssertEqual(TelemetryPhase.interruptionBegan, "interruption.began")
        XCTAssertEqual(TelemetryPhase.frame, "frame")
        XCTAssertEqual(TelemetryPhase.layout, "layout")
        XCTAssertEqual(TelemetryPhase.pagePrepare, "page.prepare")
        XCTAssertEqual(TelemetryPhase.pageReuse, "page.reuse")
        XCTAssertEqual(TelemetryPhase.pageCacheHit, "page.cache_hit")
        XCTAssertEqual(TelemetryPhase.pageCacheMiss, "page.cache_miss")
        XCTAssertEqual(TelemetryPhase.resize, "resize")
        XCTAssertEqual(TelemetryPhase.pageCountChanged, "page_count.changed")
        XCTAssertEqual(TelemetryPhase.stateChanged, "state.changed")
        XCTAssertEqual(TelemetryPhase.teardownCallback, "teardown.callback")
        XCTAssertEqual(TelemetryPhase.teardownComplete, "teardown.complete")
    }
}
