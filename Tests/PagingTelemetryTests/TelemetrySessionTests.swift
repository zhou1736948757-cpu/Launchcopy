//
//  TelemetrySessionTests.swift
//  PagingTelemetryTests
//
//  TelemetrySession 生命周期、默认关闭、JSONL 完整性、run ID 隔离、
//  异常输入防御与降级行为测试。
//

import Foundation
import XCTest
@testable import PagingTelemetry

final class TelemetrySessionTests: XCTestCase {

    // MARK: - 默认关闭（验收：无参数时不产生日志）

    func testDefaultDisabledProducesNoOutput() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(enabled: false, outputDirectory: dir))

        session.begin()
        session.record(TelemetryEvent(phase: TelemetryPhase.gestureBegan))
        session.record(TelemetryEvent(phase: TelemetryPhase.gestureChanged))
        session.end()

        XCTAssertFalse(session.isActive)
        XCTAssertEqual(session.recordedEventCount, 0)
        XCTAssertNil(session.fileURL)
        XCTAssertEqual(session.logPathDescription, "telemetry disabled")

        let remaining = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(remaining.isEmpty, "禁用时应不产生任何文件，实际: \(remaining)")
    }

    func testDisabledRecordWithoutBeginIsNoOp() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(enabled: false, outputDirectory: dir))

        session.record(TelemetryEvent(phase: TelemetryPhase.frame))
        session.end()

        XCTAssertEqual(session.recordedEventCount, 0)
        let remaining = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(remaining.isEmpty)
    }

    // MARK: - 开启后事件落盘 + JSONL 完整性

    func testEnabledRunWritesJSONLFileWithAllLines() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "test-run-1", outputDirectory: dir))

        session.begin()
        session.record(TelemetryEvent(phase: TelemetryPhase.gestureBegan))
        session.record(TelemetryEvent(phase: TelemetryPhase.gestureChanged))
        session.record(TelemetryEvent(phase: TelemetryPhase.gestureEnded))
        session.end()

        XCTAssertTrue(session.isActive == false)
        XCTAssertEqual(session.recordedEventCount, 5) // begin + 3 + end

        let expectedName = "launch-copy-paging-prototype-test-run-1.jsonl"
        XCTAssertEqual(session.fileURL?.lastPathComponent, expectedName)

        let fileURL = dir.appendingPathComponent(expectedName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let lines = try readLines(of: fileURL)
        XCTAssertEqual(lines.count, 5)

        let phases = lines.map { jsonObject(fromLine: $0)["event_phase"] as? String }
        XCTAssertEqual(phases, ["run.begin", "gesture.began", "gesture.changed", "gesture.ended", "run.end"])
    }

    func testEveryLineCarriesAllSeventeenFields() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "fields-check", outputDirectory: dir))

        // 最小事件（仅 phase）与全字段事件混录
        session.begin()
        session.record(TelemetryEvent(phase: TelemetryPhase.frame))
        var full = TelemetryEvent(phase: TelemetryPhase.transitionCommit)
        full.gestureID = 7
        full.transitionID = 3
        full.inputDelta = -0.5
        full.visualOffset = 1.25
        full.semanticCurrentPage = 1
        full.proposedTarget = 2
        full.committedPage = 2
        full.frameInterval = 0.0167
        full.pageHostViewCount = 3
        full.pagePrepareCache = .hit
        full.transitionToken = 42
        full.staleCallbackFired = false
        full.interruptSourceOffset = 1.25
        full.reduceMotionEnabled = false
        session.record(full)
        session.end()

        let fileURL = dir.appendingPathComponent("launch-copy-paging-prototype-fields-check.jsonl")
        let lines = try readLines(of: fileURL)
        XCTAssertEqual(lines.count, 4) // run.begin + frame + transitionCommit + run.end

        // 每条都含 17 个必需字段
        for line in lines {
            assertRequiredFields(jsonObject(fromLine: line))
        }

        // 最小事件的默认值
        let minimal = jsonObject(fromLine: lines[1])
        XCTAssertEqual(minimal["gesture_id"] as? UInt64 ?? 0, 0)
        XCTAssertEqual(minimal["semantic_current_page"] as? Int ?? 0, -1)
        XCTAssertEqual(minimal["page_prepare_cache"] as? String, "n/a")

        // 全字段事件的显式值 + 扩展字段
        let fullObj = jsonObject(fromLine: lines[2])
        XCTAssertEqual(fullObj["gesture_id"] as? UInt64, 7)
        XCTAssertEqual(fullObj["transition_id"] as? UInt64, 3)
        XCTAssertEqual(fullObj["input_delta"] as? Double, -0.5)
        XCTAssertEqual(fullObj["visual_offset"] as? Double, 1.25)
        XCTAssertEqual(fullObj["committed_page"] as? Int, 2)
        XCTAssertEqual(fullObj["frame_interval"] as? Double, 0.0167)
        XCTAssertEqual(fullObj["page_host_view_count"] as? Int, 3)
        XCTAssertEqual(fullObj["page_prepare_cache"] as? String, "hit")
        XCTAssertEqual(fullObj["transition_token"] as? UInt64, 42)
        XCTAssertEqual(fullObj["stale_callback_fired"] as? Bool, false)
        XCTAssertEqual(fullObj["interrupt_source_offset"] as? Double, 1.25)
        XCTAssertEqual(fullObj["reduce_motion_enabled"] as? Bool, false)
    }

    func testEventsDecodeBackToTelemetryEvent() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "decode-check", outputDirectory: dir))

        var event = TelemetryEvent(phase: TelemetryPhase.interruptionBegan)
        event.gestureID = 9
        event.transitionID = 4
        event.interruptSourceOffset = 0.75
        session.begin()
        session.record(event)
        session.end()

        let fileURL = dir.appendingPathComponent("launch-copy-paging-prototype-decode-check.jsonl")
        let lines = try readLines(of: fileURL)
        let eventLine = lines[1]

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TelemetryEvent.self, from: Data(eventLine.utf8))
        XCTAssertEqual(decoded.runID, "decode-check")
        XCTAssertEqual(decoded.phase, TelemetryPhase.interruptionBegan)
        XCTAssertEqual(decoded.gestureID, 9)
        XCTAssertEqual(decoded.transitionID, 4)
        XCTAssertEqual(decoded.interruptSourceOffset, 0.75)
    }

    // MARK: - run ID 隔离

    func testRunIDIsolationBetweenSessions() throws {
        let dir = try makeTempOutputDirectory()

        let alpha = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "alpha", outputDirectory: dir))
        alpha.begin()
        alpha.record(TelemetryEvent(phase: TelemetryPhase.gestureBegan))
        alpha.end()

        let beta = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "beta", outputDirectory: dir))
        beta.begin()
        beta.record(TelemetryEvent(phase: TelemetryPhase.transitionCommit))
        beta.end()

        let alphaURL = dir.appendingPathComponent("launch-copy-paging-prototype-alpha.jsonl")
        let betaURL = dir.appendingPathComponent("launch-copy-paging-prototype-beta.jsonl")
        XCTAssertTrue(FileManager.default.fileExists(atPath: alphaURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: betaURL.path))

        for line in try readLines(of: alphaURL) {
            XCTAssertEqual(jsonObject(fromLine: line)["run_id"] as? String, "alpha")
        }
        for line in try readLines(of: betaURL) {
            XCTAssertEqual(jsonObject(fromLine: line)["run_id"] as? String, "beta")
        }
    }

    func testGeneratedRunIDWhenNotProvided() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: nil, outputDirectory: dir))

        session.begin()
        session.end()

        XCTAssertFalse(session.runID.isEmpty)
        XCTAssertEqual(session.fileURL?.lastPathComponent, "launch-copy-paging-prototype-\(session.runID).jsonl")
        XCTAssertTrue(FileManager.default.fileExists(atPath: session.fileURL!.path))
    }

    // MARK: - 累计计数盖章

    func testCountersStampedIntoEvents() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "counters", outputDirectory: dir))

        session.begin()
        XCTAssertEqual(session.registerInterruption(), 1)
        XCTAssertEqual(session.registerInterruption(), 2)
        XCTAssertEqual(session.registerStaleRejection(), 1)
        XCTAssertEqual(session.registerLayout(), 1)
        XCTAssertEqual(session.registerLayout(), 2)
        XCTAssertEqual(session.registerLayout(), 3)
        XCTAssertEqual(session.registerTeardownCallback(), 1)
        session.record(TelemetryEvent(phase: TelemetryPhase.teardownComplete))
        session.end()

        let fileURL = dir.appendingPathComponent("launch-copy-paging-prototype-counters.jsonl")
        let lines = try readLines(of: fileURL)
        let obj = jsonObject(fromLine: lines[1])
        XCTAssertEqual(obj["interruption_count"] as? Int, 2)
        XCTAssertEqual(obj["stale_rejection_count"] as? Int, 1)
        XCTAssertEqual(obj["layout_count"] as? Int, 3)
        XCTAssertEqual(obj["teardown_callback_count"] as? Int, 1)
    }

    // MARK: - 时间戳

    func testTimestampStampedWhenZeroAndPreservedWhenExplicit() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "timestamps", outputDirectory: dir))

        session.begin()
        session.record(TelemetryEvent(phase: TelemetryPhase.gestureBegan)) // timestamp 0 → 盖章

        var explicit = TelemetryEvent(phase: TelemetryPhase.frame)
        explicit.timestamp = 1_234_567_890.5
        session.record(explicit)
        session.end()

        let fileURL = dir.appendingPathComponent("launch-copy-paging-prototype-timestamps.jsonl")
        let lines = try readLines(of: fileURL)

        let stamped = jsonObject(fromLine: lines[1])["timestamp"] as? Double ?? 0
        XCTAssertGreaterThan(stamped, 1_700_000_000, "应盖章为当前时间戳")
        XCTAssertLessThan(stamped, Date().timeIntervalSince1970 + 60)

        let preserved = jsonObject(fromLine: lines[2])["timestamp"] as? Double
        XCTAssertEqual(preserved, 1_234_567_890.5)
    }

    // MARK: - 异常输入不崩溃（§7.4 自动化边界）

    func testRecordAfterEndIsNoOp() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "after-end", outputDirectory: dir))

        session.begin()
        session.record(TelemetryEvent(phase: TelemetryPhase.gestureBegan))
        session.end()
        session.record(TelemetryEvent(phase: TelemetryPhase.gestureChanged)) // end 之后 → no-op
        session.end() // 重复 end → no-op

        let fileURL = dir.appendingPathComponent("launch-copy-paging-prototype-after-end.jsonl")
        let lines = try readLines(of: fileURL)
        XCTAssertEqual(lines.count, 3, "应为 run.begin + gesture.began + run.end，end 后记录不得追加")
    }

    func testDoubleBeginIsIdempotent() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "double-begin", outputDirectory: dir))

        session.begin()
        session.begin()
        session.end()

        let fileURL = dir.appendingPathComponent("launch-copy-paging-prototype-double-begin.jsonl")
        let lines = try readLines(of: fileURL)
        XCTAssertEqual(lines.count, 2, "重复 begin 不应重复写入 run.begin")
    }

    func testPathTraversalRunIDIsSanitized() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "../evil/../../etc/passwd", outputDirectory: dir))

        XCTAssertEqual(session.runID, ".._evil_.._.._etc_passwd")

        session.begin()
        session.end()

        // 文件必须留在输出目录内，且名为净化后的形式
        let expectedURL = dir.appendingPathComponent("launch-copy-paging-prototype-.._evil_.._.._etc_passwd.jsonl")
        XCTAssertEqual(session.fileURL, expectedURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedURL.path))

        // 输出目录外不应出现任何文件
        let parent = dir.deletingLastPathComponent()
        let parentContents = try FileManager.default.contentsOfDirectory(atPath: parent.path)
            .filter { $0.contains("launch-copy-paging-prototype") }
        XCTAssertTrue(parentContents.isEmpty, "文件逃逸出输出目录: \(parentContents)")
    }

    func testVeryLongRunIDIsCapped() throws {
        let dir = try makeTempOutputDirectory()
        let longID = String(repeating: "x", count: 500)
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: longID, outputDirectory: dir))

        XCTAssertEqual(session.runID.count, 64)
        session.begin()
        session.end()
        XCTAssertTrue(FileManager.default.fileExists(atPath: session.fileURL!.path))
    }

    func testExtremeNumericValuesDoNotBreakJSONL() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "extreme", outputDirectory: dir))

        session.begin()
        var extreme = TelemetryEvent(phase: TelemetryPhase.gestureChanged)
        extreme.inputDelta = -1e300
        extreme.visualOffset = 1e300
        extreme.frameInterval = 1e-9
        session.record(extreme)
        session.end()

        let fileURL = dir.appendingPathComponent("launch-copy-paging-prototype-extreme.jsonl")
        let lines = try readLines(of: fileURL)
        assertRequiredFields(jsonObject(fromLine: lines[1]))
        let obj = jsonObject(fromLine: lines[1])
        XCTAssertEqual(obj["input_delta"] as? Double, -1e300)
        XCTAssertEqual(obj["visual_offset"] as? Double, 1e300)
    }

    // MARK: - 文件失败降级（不崩溃）

    func testUnwritableOutputDirectoryDegradesToMemory() throws {
        // 输出目录的父路径是一个文件 → 目录创建必然失败
        let blocker = FileManager.default.temporaryDirectory
            .appendingPathComponent("PagingTelemetryTests-blocker-\(UUID().uuidString)")
        try Data("blocker".utf8).write(to: blocker)
        addTeardownBlock { try? FileManager.default.removeItem(at: blocker) }

        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "degraded", outputDirectory: blocker.appendingPathComponent("sub")))

        session.begin()
        session.record(TelemetryEvent(phase: TelemetryPhase.gestureBegan))
        session.record(TelemetryEvent(phase: TelemetryPhase.transitionCommit))
        session.end()

        XCTAssertTrue(session.degradedToMemory)
        XCTAssertGreaterThanOrEqual(session.writeFailureCount, 1)
        XCTAssertEqual(session.recordedEventCount, 4) // run.begin + 2 事件 + run.end
        XCTAssertEqual(session.memoryBufferEvents.count, 4)
        XCTAssertTrue(session.logPathDescription.contains("degraded-to-memory"))
        XCTAssertNil(session.fileURL)
    }

    func testMemoryBufferIsBounded() throws {
        let blocker = FileManager.default.temporaryDirectory
            .appendingPathComponent("PagingTelemetryTests-blocker-\(UUID().uuidString)")
        try Data("blocker".utf8).write(to: blocker)
        addTeardownBlock { try? FileManager.default.removeItem(at: blocker) }

        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "bounded", outputDirectory: blocker.appendingPathComponent("sub")))

        session.begin()
        for _ in 0..<10_500 {
            session.record(TelemetryEvent(phase: TelemetryPhase.frame))
        }
        session.end()

        XCTAssertTrue(session.degradedToMemory)
        XCTAssertEqual(session.memoryBufferEvents.count, 10_000, "内存缓冲应有上界")
        XCTAssertEqual(session.recordedEventCount, 10_502)
    }

    // MARK: - 线程安全冒烟

    func testConcurrentRecordingIsSafe() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "concurrent", outputDirectory: dir))

        session.begin()
        DispatchQueue.concurrentPerform(iterations: 800) { index in
            var event = TelemetryEvent(phase: TelemetryPhase.gestureChanged)
            event.gestureID = UInt64(index)
            session.record(event)
        }
        session.end()

        XCTAssertEqual(session.recordedEventCount, 802) // 800 + begin + end

        let fileURL = dir.appendingPathComponent("launch-copy-paging-prototype-concurrent.jsonl")
        let lines = try readLines(of: fileURL)
        XCTAssertEqual(lines.count, 802)
        let gestureIDs = Set(lines.dropFirst().dropLast().map { jsonObject(fromLine: $0)["gesture_id"] as? UInt64 ?? 0 })
        XCTAssertEqual(gestureIDs.count, 800, "并发写入不应丢事件或重复")
    }
}
