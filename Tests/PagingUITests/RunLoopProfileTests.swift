//
//  RunLoopProfileTests.swift
//  PagingUITests
//
//  runloop 级主线程探针（T-worker-b-runloopprofile；--frame-profile 同开）：
//  - 缺省关闭：未激活不注册观察者、不产生文件；
//  - 观察记录：主 runloop 周期内的 coarse active-vs-waiting 活动标记 +
//    timestamp / gap_ns / since_same_ns；不把单个 waiting 区间解释为系统调度，
//    也不细分 timer/source；
//  - 幂等：start/stop 重复调用安全；
//  - 帮助文本同步。
//

import AppKit
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class RunLoopProfileTests: XCTestCase {

    // MARK: - 缺省关闭（无观察者注册 / 无文件）

    func testRunLoopProfileDefaultOff() throws {
        let url = tempProfileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        var wallReads = 0
        var modeReads = 0
        let recorder = RunLoopProfileRecorder(
            runID: "off-test",
            fileURL: url,
            active: false,
            clock: DiagnosticMonotonicClock(
                wallNowNS: { wallReads += 1; return 1 },
                threadCPUNowNS: { 1 }
            ),
            modeProvider: { modeReads += 1; return "private.secret.mode" },
            writer: nil
        )
        recorder.start()
        recorder.recordObservationForTesting(.beforeWaiting)
        XCTAssertFalse(recorder.isObserving, "未激活：不注册观察者")
        recorder.flush()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "未激活：不产生文件")
        XCTAssertEqual(recorder.recordCount, 0, "未激活：零记录")
        XCTAssertEqual(wallReads, 0, "inactive observer must not sample the shared clock")
        XCTAssertEqual(modeReads, 0, "inactive observer must not inspect run-loop mode")
    }

    // MARK: - 输出格式

    func testRunLoopProfileFileNaming() {
        let recorder = RunLoopProfileRecorder(runID: "abc-123")
        XCTAssertEqual(recorder.fileURL.lastPathComponent, "launch-copy-paging-prototype-abc-123-runloop.jsonl")
        XCTAssertEqual(recorder.fileURL.deletingLastPathComponent().path, "/tmp")
    }

    func testRunLoopProfileSanitizedRunID() {
        XCTAssertEqual(RunLoopProfileRecorder.sanitizedRunID("a b/c"), "a_b_c")
        XCTAssertEqual(RunLoopProfileRecorder.sanitizedRunID(""), "run")
    }

    // MARK: - 观察记录（主 runloop 周期）

    func testRunLoopProfileRecordsActivities() throws {
        let url = tempProfileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = RunLoopProfileRecorder(runID: "active-test", fileURL: url, active: true)
        recorder.start()
        XCTAssertTrue(recorder.isObserving)

        // 主 runloop 转 50ms：观察者产生 coarse active/waiting 边界标记。
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        recorder.stop()
        XCTAssertFalse(recorder.isObserving)
        recorder.flush()

        let lines = try readProfileLines(url)
        XCTAssertFalse(lines.isEmpty, "runloop 周期应产生观察记录")
        XCTAssertEqual(lines.count, recorder.recordCount, "stop 后 flush 必须写完所有已接收记录")
        let known = Set(["entry", "beforeTimers", "beforeSources",
                         "beforeWaiting", "afterWaiting", "exit"])
        for record in lines {
            XCTAssertEqual(record["kind"], "runloop")
            XCTAssertTrue(Set(["default", "eventTracking", "modalPanel", "other", "none"]).contains(record["mode"] ?? ""),
                          "mode 只能是固定匿名类别")
            XCTAssertTrue(known.contains(record["activity"] ?? ""),
                          "未知活动 \(record["activity"] ?? "-")")
            XCTAssertNotNil(record["timestamp"], "遗留 uptime 字段保留，但不能作为同钟 join key")
            XCTAssertNotNil(record["timestamp_ns"], "同钟关联必须使用 timestamp_ns")
            XCTAssertNotNil(record["observation_seq"])
            XCTAssertNotNil(record["previous_activity"])
            XCTAssertGreaterThanOrEqual(Int64(record["gap_ns"] ?? "-1") ?? -1, 0, "gap_ns 非负")
            XCTAssertGreaterThanOrEqual(Int64(record["since_same_ns"] ?? "-1") ?? -1, 0, "since_same_ns 非负")
        }
        // 这些是粗粒度活动标记；顺序仅用于确认观察器活动，不把 gap 归因到
        // timer/source，也不把 waiting 单独解释为系统调度。
        let activities = Set(lines.compactMap { $0["activity"] })
        XCTAssertTrue(activities.contains("beforeWaiting"))
        XCTAssertTrue(activities.contains("afterWaiting"))
        XCTAssertTrue(activities.contains("beforeTimers"))
        XCTAssertTrue(activities.contains("beforeSources"))
        // 此环境的观察回调中会看到该活动顺序；这不是具体工作来源的归因。
        let sequence = lines.compactMap { $0["activity"] }
        XCTAssertTrue(sequence.contains("beforeTimers"))
        let timerIndex = sequence.firstIndex(of: "beforeTimers")!
        XCTAssertEqual(sequence[timerIndex + 1], "beforeSources", "beforeTimers → beforeSources 相邻")
        let sourceIndex = sequence.firstIndex(of: "beforeSources")!
        XCTAssertEqual(sequence[sourceIndex + 1], "beforeWaiting", "beforeSources → beforeWaiting 相邻")
    }

    func testRunLoopStopThenFlushPersistsEveryAcceptedRecord() throws {
        let url = tempProfileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = RunLoopProfileRecorder(runID: "stop-flush", fileURL: url, active: true)
        recorder.flushThreshold = 1
        recorder.start()
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        recorder.stop()

        let accepted = recorder.recordCount
        XCTAssertGreaterThan(accepted, 0)
        recorder.flush()

        let lines = try readProfileLines(url)
        XCTAssertEqual(lines.count, accepted, "flush 返回时不能遗漏此前已接收的异步批次")
    }

    func testModeCategoryNeverLeaksRawMode() {
        XCTAssertEqual(RunLoopProfileRecorder.modeCategory(rawMode: nil), "none")
        XCTAssertEqual(RunLoopProfileRecorder.modeCategory(rawMode: "kCFRunLoopDefaultMode"), "default")
        XCTAssertEqual(RunLoopProfileRecorder.modeCategory(rawMode: "NSDefaultRunLoopMode"), "default")
        XCTAssertEqual(RunLoopProfileRecorder.modeCategory(rawMode: "NSEventTrackingRunLoopMode"), "eventTracking")
        XCTAssertEqual(RunLoopProfileRecorder.modeCategory(rawMode: "NSModalPanelRunLoopMode"), "modalPanel")
        XCTAssertEqual(RunLoopProfileRecorder.modeCategory(rawMode: "private.secret.mode"), "other")
    }

    // MARK: - 幂等

    func testRunLoopProfileStartStopIdempotent() throws {
        let url = tempProfileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = RunLoopProfileRecorder(runID: "idem-test", fileURL: url, active: true)
        recorder.start()
        recorder.start() // 重复 start：不重复注册
        XCTAssertTrue(recorder.isObserving)
        recorder.stop()
        recorder.stop() // 重复 stop：安全
        XCTAssertFalse(recorder.isObserving)
        recorder.start()
        XCTAssertTrue(recorder.isObserving)
        recorder.stop()
        recorder.flush()
    }

    // MARK: - 帮助文本同步

    func testRunLoopProfileHelpTextMentionsRunLoop() {
        XCTAssertTrue(AppArguments.helpText().contains("--frame-profile"))
        XCTAssertTrue(AppArguments.helpText().contains("--runloop-profile"))
        XCTAssertTrue(AppArguments.helpText().contains("runloop"), "帮助文本说明 runloop 探针输出")
    }

    // MARK: - 工具

    private func tempProfileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("rlp-test-\(UUID().uuidString).jsonl")
    }

    /// 读取 profile 文件并解析为 [key: String] 记录数组（JSON 非法即抛错）。
    private func readProfileLines(_ url: URL) throws -> [[String: String]] {
        let data = try Data(contentsOf: url)
        let text = String(decoding: data, as: UTF8.self)
        return try text.split(separator: "\n").map { line in
            let object = try JSONSerialization.jsonObject(with: Data(String(line).utf8))
                as? [String: Any] ?? [:]
            return object.mapValues { value in
                if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() {
                    return number.boolValue ? "true" : "false"
                }
                return String(describing: value)
            }
        }
    }
}
