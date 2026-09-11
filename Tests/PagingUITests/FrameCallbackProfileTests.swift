//
//  FrameCallbackProfileTests.swift
//  PagingUITests
//

import Foundation
import XCTest
@testable import PagingUI

final class FrameCallbackProfileTests: XCTestCase {

    func testDefaultOffProducesNoFileOrRecord() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        var wallReads = 0
        var cpuReads = 0
        var modeReads = 0
        let recorder = FrameCallbackProfileRecorder(
            runID: "off",
            fileURL: url,
            active: false,
            clock: .init(
                wallNowNS: { wallReads += 1; return 1 },
                threadCPUNowNS: { cpuReads += 1; return 1 }
            ),
            modeProvider: { modeReads += 1; return "private.mode" }
        )

        let boundary = recorder.beginCallback(driverGeneration: 1, scheduledNS: 0, intervalNS: 10)
        recorder.endCallback(boundary, simulationDTNS: nil)
        recorder.markPreReturn(boundary)
        _ = recorder.recordGenerationArm(driverGeneration: 1, intervalNS: 10, toleranceNS: 0)
        recorder.flush()

        XCTAssertFalse(recorder.isActive)
        XCTAssertEqual(recorder.recordCount, 0)
        XCTAssertEqual(recorder.writeFailureCount, 0)
        XCTAssertEqual(recorder.droppedRecordCount, 0)
        XCTAssertEqual(recorder.incompleteDropCount, 0)
        XCTAssertEqual(wallReads, 0, "inactive hot path must not sample wall time")
        XCTAssertEqual(cpuReads, 0, "inactive hot path must not sample thread CPU time")
        XCTAssertEqual(modeReads, 0, "inactive hot path must not inspect run-loop mode")
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testDefaultFileNameAndRunIDSanitization() {
        let recorder = FrameCallbackProfileRecorder(runID: "abc 123/secret")
        XCTAssertEqual(
            recorder.fileURL.path,
            "/tmp/launch-copy-paging-prototype-abc_123_secret-callback.jsonl"
        )
        XCTAssertEqual(FrameCallbackProfileRecorder.sanitizedRunID(""), "run")
        XCTAssertEqual(FrameCallbackProfileRecorder.sanitizedRunID("ok-1.2_3"), "ok-1.2_3")
        XCTAssertEqual(FrameCallbackProfileRecorder.sanitizedRunID("a b/c"), "a_b_c")
        XCTAssertEqual(FrameCallbackProfileRecorder.sanitizedRunID(String(repeating: "x", count: 80)).count, 64)
    }

    func testScheduleMetricsAtDeadlineAndMissedPeriodBoundaries() {
        assertSchedule(scheduled: 100, entry: 99, interval: 10, lateness: -1, missed: 0, next: 100)
        assertSchedule(scheduled: 100, entry: 100, interval: 10, lateness: 0, missed: 0, next: 110)
        assertSchedule(scheduled: 100, entry: 109, interval: 10, lateness: 9, missed: 0, next: 110)
        assertSchedule(scheduled: 100, entry: 110, interval: 10, lateness: 10, missed: 1, next: 120)
        assertSchedule(scheduled: 100, entry: 129, interval: 10, lateness: 29, missed: 2, next: 130)
        assertSchedule(scheduled: 100, entry: 130, interval: 10, lateness: 30, missed: 3, next: 140)
    }

    func testScheduleMetricsSaturateInsteadOfOverflowing() {
        XCTAssertEqual(
            FrameCallbackProfileRecorder.latenessNanoseconds(scheduledNS: 0, entryNS: .max),
            .max
        )
        XCTAssertEqual(
            FrameCallbackProfileRecorder.latenessNanoseconds(scheduledNS: .max, entryNS: 0),
            .min
        )
        XCTAssertEqual(
            FrameCallbackProfileRecorder.nextNominalDeadlineNS(
                scheduledNS: UInt64.max - 5,
                entryNS: UInt64.max,
                intervalNS: 10
            ),
            UInt64.max
        )
        XCTAssertEqual(
            FrameCallbackProfileRecorder.nextNominalDeadlineNS(
                scheduledNS: 100,
                entryNS: 200,
                intervalNS: 0
            ),
            UInt64.max
        )
        XCTAssertEqual(
            FrameCallbackProfileRecorder.missedPeriods(
                scheduledNS: 100,
                entryNS: 200,
                intervalNS: 0
            ),
            0
        )
    }

    func testCompleteFirstTickSchemaUsesNullsAndAnonymousMode() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        var wallValues: [UInt64] = [1_000, 1_125, 1_140]
        var cpuValues: [UInt64] = [40, 70, 75]
        let rawMode = "private.secret.mode.with.identifiers"
        let recorder = FrameCallbackProfileRecorder(
            runID: "schema",
            fileURL: url,
            active: true,
            clock: .init(
                wallNowNS: { wallValues.removeFirst() },
                threadCPUNowNS: { cpuValues.removeFirst() }
            ),
            modeProvider: { rawMode }
        )

        let boundary = try XCTUnwrap(
            recorder.beginCallback(driverGeneration: 7, scheduledNS: 950, intervalNS: 100)
        )
        recorder.endCallback(boundary, simulationDTNS: nil)
        XCTAssertEqual(recorder.recordCount, 0, "JSON is emitted only at the pre-return marker")
        recorder.markPreReturn(boundary)
        XCTAssertEqual(recorder.recordCount, 1)
        recorder.flush()

        let data = try Data(contentsOf: url)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains(rawMode), "raw run-loop mode must never reach JSONL")
        let lines = text.split(separator: "\n")
        XCTAssertEqual(lines.count, 1)
        let record = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(lines[0].utf8)) as? [String: Any]
        )
        XCTAssertEqual(
            Set(record.keys),
            Set([
                "kind", "callback_seq", "driver_generation", "scheduled_ns", "entry_ns", "exit_ns",
                "pre_return_ns", "lateness_ns", "missed_periods", "first_tick", "raw_callback_interval_ns",
                "simulation_dt_ns", "callback_wall_ns", "thread_cpu_entry_ns", "thread_cpu_exit_ns",
                "thread_cpu_pre_return_ns", "callback_cpu_ns", "closure_tail_wall_ns",
                "closure_tail_cpu_ns", "mode", "nominal_interval_ns",
            ])
        )
        XCTAssertEqual(record["kind"] as? String, "frame_callback")
        XCTAssertEqual((record["callback_seq"] as? NSNumber)?.uint64Value, 1)
        XCTAssertEqual((record["driver_generation"] as? NSNumber)?.uint64Value, 7)
        XCTAssertEqual((record["scheduled_ns"] as? NSNumber)?.uint64Value, 950)
        XCTAssertEqual((record["entry_ns"] as? NSNumber)?.uint64Value, 1_000)
        XCTAssertEqual((record["exit_ns"] as? NSNumber)?.uint64Value, 1_125)
        XCTAssertEqual((record["lateness_ns"] as? NSNumber)?.int64Value, 50)
        XCTAssertEqual((record["missed_periods"] as? NSNumber)?.uint64Value, 0)
        XCTAssertEqual((record["nominal_interval_ns"] as? NSNumber)?.uint64Value, 100)
        XCTAssertEqual((record["first_tick"] as? NSNumber)?.boolValue, true)
        XCTAssertTrue(record["raw_callback_interval_ns"] is NSNull)
        XCTAssertTrue(record["simulation_dt_ns"] is NSNull)
        XCTAssertEqual((record["callback_wall_ns"] as? NSNumber)?.uint64Value, 125)
        XCTAssertEqual((record["thread_cpu_entry_ns"] as? NSNumber)?.uint64Value, 40)
        XCTAssertEqual((record["thread_cpu_exit_ns"] as? NSNumber)?.uint64Value, 70)
        XCTAssertEqual((record["callback_cpu_ns"] as? NSNumber)?.uint64Value, 30)
        XCTAssertEqual((record["pre_return_ns"] as? NSNumber)?.uint64Value, 1_140)
        XCTAssertEqual((record["thread_cpu_pre_return_ns"] as? NSNumber)?.uint64Value, 75)
        XCTAssertEqual((record["closure_tail_wall_ns"] as? NSNumber)?.uint64Value, 15)
        XCTAssertEqual((record["closure_tail_cpu_ns"] as? NSNumber)?.uint64Value, 5)
        XCTAssertEqual(record["mode"] as? String, "other")
        XCTAssertTrue(Set(["default", "eventTracking", "modalPanel", "other", "none"]).contains(record["mode"] as? String ?? ""))
    }

    func testModeCategoryHasOnlyFixedAnonymousVocabulary() {
        let cases: [(String?, String)] = [
            (nil, "none"),
            ("kCFRunLoopDefaultMode", "default"),
            ("NSDefaultRunLoopMode", "default"),
            ("NSEventTrackingRunLoopMode", "eventTracking"),
            ("NSModalPanelRunLoopMode", "modalPanel"),
            ("private.raw.mode", "other"),
        ]
        let vocabulary = Set(["default", "eventTracking", "modalPanel", "other", "none"])

        for (raw, expected) in cases {
            let category = FrameCallbackProfileRecorder.modeCategory(rawMode: raw)
            XCTAssertEqual(category, expected)
            XCTAssertTrue(vocabulary.contains(category))
            if raw == "private.raw.mode" {
                XCTAssertNotEqual(category, raw)
            }
        }
    }

    func testMarkerOrderAndTailDeltasUseInjectedClock() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        var wallValues: [UInt64] = [100, 130, 145]
        var cpuValues: [UInt64] = [1, 4, 9]
        let recorder = FrameCallbackProfileRecorder(
            runID: "markers",
            fileURL: url,
            active: true,
            clock: .init(
                wallNowNS: { wallValues.removeFirst() },
                threadCPUNowNS: { cpuValues.removeFirst() }
            ),
            modeProvider: { "kCFRunLoopDefaultMode" }
        )

        let boundary = try XCTUnwrap(
            recorder.beginCallback(driverGeneration: 1, scheduledNS: 100, intervalNS: 16)
        )
        recorder.endCallback(boundary, simulationDTNS: 16)
        recorder.markPreReturn(boundary)
        recorder.flush()

        let record = try readCallback(url)
        let entry = try XCTUnwrap((record["entry_ns"] as? NSNumber)?.uint64Value)
        let exit = try XCTUnwrap((record["exit_ns"] as? NSNumber)?.uint64Value)
        let preReturn = try XCTUnwrap((record["pre_return_ns"] as? NSNumber)?.uint64Value)
        XCTAssertLessThanOrEqual(entry, exit)
        XCTAssertLessThanOrEqual(exit, preReturn)
        XCTAssertEqual((record["callback_wall_ns"] as? NSNumber)?.uint64Value, 30)
        XCTAssertEqual((record["closure_tail_wall_ns"] as? NSNumber)?.uint64Value, 15)
        XCTAssertEqual((record["callback_cpu_ns"] as? NSNumber)?.uint64Value, 3)
        XCTAssertEqual((record["closure_tail_cpu_ns"] as? NSNumber)?.uint64Value, 5)
        XCTAssertEqual(record["mode"] as? String, "default")
        XCTAssertFalse(String(describing: record).contains("kCFRunLoopDefaultMode"))
    }

    func testEndCallbackWithoutPreReturnDoesNotEmitAndIsCounted() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        var wall: UInt64 = 10
        let recorder = FrameCallbackProfileRecorder(
            runID: "incomplete",
            fileURL: url,
            active: true,
            clock: .init(
                wallNowNS: { wall += 1; return wall },
                threadCPUNowNS: { 1 }
            ),
            modeProvider: { nil }
        )
        let boundary = try XCTUnwrap(
            recorder.beginCallback(driverGeneration: 1, scheduledNS: 0, intervalNS: 10)
        )
        recorder.endCallback(boundary, simulationDTNS: nil)
        recorder.flush()
        XCTAssertEqual(recorder.recordCount, 0)
        XCTAssertEqual(recorder.incompleteDropCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testGenerationArmRecordAndStartStopWithoutTick() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        var wallValues: [UInt64] = [500]
        let recorder = FrameCallbackProfileRecorder(
            runID: "arm",
            fileURL: url,
            active: true,
            clock: .init(
                wallNowNS: { wallValues.removeFirst() },
                threadCPUNowNS: { 0 }
            ),
            modeProvider: { nil }
        )
        let deadline = recorder.recordGenerationArm(
            driverGeneration: 3,
            intervalNS: 16_666_667,
            toleranceNS: 0
        )
        recorder.flush()
        XCTAssertEqual(deadline, 500 + 16_666_667)
        XCTAssertEqual(recorder.recordCount, 1)

        let record = try readCallback(url)
        XCTAssertEqual(record["kind"] as? String, "timer_generation_arm")
        XCTAssertEqual((record["driver_generation"] as? NSNumber)?.uint64Value, 3)
        XCTAssertEqual((record["arm_ns"] as? NSNumber)?.uint64Value, 500)
        XCTAssertEqual((record["nominal_first_deadline_ns"] as? NSNumber)?.uint64Value, deadline)
        XCTAssertEqual((record["interval_ns"] as? NSNumber)?.uint64Value, 16_666_667)
        XCTAssertEqual((record["tolerance_ns"] as? NSNumber)?.uint64Value, 0)
        XCTAssertEqual(
            Set(record.keys),
            Set(["kind", "driver_generation", "arm_ns", "nominal_first_deadline_ns", "interval_ns", "tolerance_ns"])
        )
    }

    func testNegativeTailIsEmittedAsNullNotClamped() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        var wallValues: [UInt64] = [100, 130, 120]
        var cpuValues: [UInt64] = [10, 20, 15]
        let recorder = FrameCallbackProfileRecorder(
            runID: "negative-tail",
            fileURL: url,
            active: true,
            clock: .init(
                wallNowNS: { wallValues.removeFirst() },
                threadCPUNowNS: { cpuValues.removeFirst() }
            ),
            modeProvider: { nil }
        )
        let boundary = try XCTUnwrap(
            recorder.beginCallback(driverGeneration: 1, scheduledNS: 100, intervalNS: 10)
        )
        recorder.endCallback(boundary, simulationDTNS: nil)
        recorder.markPreReturn(boundary)
        recorder.flush()
        let record = try readCallback(url)
        XCTAssertEqual((record["entry_ns"] as? NSNumber)?.uint64Value, 100)
        XCTAssertEqual((record["exit_ns"] as? NSNumber)?.uint64Value, 130)
        XCTAssertEqual((record["pre_return_ns"] as? NSNumber)?.uint64Value, 120)
        XCTAssertTrue(record["closure_tail_wall_ns"] is NSNull)
        XCTAssertTrue(record["closure_tail_cpu_ns"] is NSNull)
    }

    func testBufferOverflowDropsOldestAndRemainsQueryable() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url) }
        var wall: UInt64 = 0
        let recorder = FrameCallbackProfileRecorder(
            runID: "overflow",
            fileURL: url,
            active: true,
            clock: .init(
                wallNowNS: { wall += 10; return wall },
                threadCPUNowNS: { 1 }
            ),
            modeProvider: { nil }
        )
        recorder.bufferCapacity = 1
        recorder.flushThreshold = 100
        for generation in 1...3 {
            _ = recorder.recordGenerationArm(driverGeneration: UInt64(generation), intervalNS: 10, toleranceNS: 0)
        }
        XCTAssertEqual(recorder.recordCount, 3)
        XCTAssertEqual(recorder.droppedRecordCount, 2)
        recorder.flush()
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(text.split(separator: "\n").count, 1)
    }

    func testWriterFailureCountIsQueryableWithoutCrashing() {
        enum ForcedWriteFailure: Error { case forced }
        let writer = BufferedJSONLWriter(fileURL: temporaryURL()) { _ in
            throw ForcedWriteFailure.forced
        }
        var wall: UInt64 = 0
        let recorder = FrameCallbackProfileRecorder(
            runID: "write-failure",
            fileURL: temporaryURL(),
            active: true,
            clock: .init(
                wallNowNS: { wall += 1; return wall },
                threadCPUNowNS: { 1 }
            ),
            modeProvider: { nil },
            writer: writer
        )
        recorder.flushThreshold = 1
        _ = recorder.recordGenerationArm(driverGeneration: 1, intervalNS: 10, toleranceNS: 0)
        recorder.flush()
        XCTAssertEqual(recorder.writeFailureCount, 1)
    }

    func testSharedFakeClockDomainWithRunLoopRecorder() throws {
        let callbackURL = temporaryURL()
        let runLoopURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("runloop-\(UUID().uuidString).jsonl")
        defer {
            try? FileManager.default.removeItem(at: callbackURL)
            try? FileManager.default.removeItem(at: runLoopURL)
        }
        var wall: UInt64 = 1_000
        let clock = DiagnosticMonotonicClock(
            wallNowNS: { wall += 5; return wall },
            threadCPUNowNS: { 2 }
        )
        var callbackModeReads = 0
        var runLoopModeReads = 0
        let callback = FrameCallbackProfileRecorder(
            runID: "shared-clock",
            fileURL: callbackURL,
            active: true,
            clock: clock,
            modeProvider: { callbackModeReads += 1; return "NSDefaultRunLoopMode" }
        )
        let runLoop = RunLoopProfileRecorder(
            runID: "shared-clock",
            fileURL: runLoopURL,
            active: true,
            clock: clock,
            modeProvider: { runLoopModeReads += 1; return "NSDefaultRunLoopMode" },
            writer: nil
        )

        let armDeadline = callback.recordGenerationArm(driverGeneration: 1, intervalNS: 20, toleranceNS: 0)
        let boundary = try XCTUnwrap(
            callback.beginCallback(driverGeneration: 1, scheduledNS: armDeadline, intervalNS: 20)
        )
        runLoop.recordObservationForTesting(.beforeWaiting)
        callback.endCallback(boundary, simulationDTNS: 20)
        runLoop.recordObservationForTesting(.afterWaiting)
        callback.markPreReturn(boundary)
        callback.flush()
        runLoop.flush()

        let callbackRecord = try readCallback(callbackURL, kind: "frame_callback")
        let runLoopLines = try String(contentsOf: runLoopURL, encoding: .utf8)
            .split(separator: "\n")
            .map { line -> [String: Any] in
                try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            }
        let entry = try XCTUnwrap((callbackRecord["entry_ns"] as? NSNumber)?.uint64Value)
        let preReturn = try XCTUnwrap((callbackRecord["pre_return_ns"] as? NSNumber)?.uint64Value)
        let firstObserver = try XCTUnwrap((runLoopLines[0]["timestamp_ns"] as? NSNumber)?.uint64Value)
        let secondObserver = try XCTUnwrap((runLoopLines[1]["timestamp_ns"] as? NSNumber)?.uint64Value)
        XCTAssertGreaterThan(firstObserver, entry)
        XCTAssertLessThan(secondObserver, preReturn)
        XCTAssertEqual(runLoopLines[0]["previous_activity"] as? String, "none")
        XCTAssertEqual(runLoopLines[1]["previous_activity"] as? String, "beforeWaiting")
        XCTAssertEqual((runLoopLines[0]["observation_seq"] as? NSNumber)?.uint64Value, 1)
        XCTAssertEqual((runLoopLines[1]["observation_seq"] as? NSNumber)?.uint64Value, 2)
        XCTAssertEqual(callbackModeReads, 1)
        XCTAssertEqual(runLoopModeReads, 2)
        XCTAssertEqual(callbackRecord["mode"] as? String, "default")
        XCTAssertEqual(runLoopLines[0]["mode"] as? String, "default")
    }

    private func readCallback(_ url: URL, kind: String? = nil) throws -> [String: Any] {
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
        let records = try lines.map { line in
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
        }
        if let kind {
            return try XCTUnwrap(records.first { $0["kind"] as? String == kind })
        }
        return try XCTUnwrap(records.first)
    }

    private func assertSchedule(
        scheduled: UInt64,
        entry: UInt64,
        interval: UInt64,
        lateness: Int64,
        missed: UInt64,
        next: UInt64,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let metrics = FrameCallbackProfileRecorder.scheduleMetrics(
            scheduledNS: scheduled,
            entryNS: entry,
            intervalNS: interval
        )
        XCTAssertEqual(metrics.latenessNS, lateness, file: file, line: line)
        XCTAssertEqual(metrics.missedPeriods, missed, file: file, line: line)
        XCTAssertEqual(metrics.nextNominalDeadlineNS, next, file: file, line: line)
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("frame-callback-profile-\(UUID().uuidString).jsonl")
    }
}
