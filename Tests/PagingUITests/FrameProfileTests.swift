//
//  FrameProfileTests.swift
//  PagingUITests
//
//  --frame-profile 诊断模式（T-worker-b-frameprofile）：
//  - 参数解析（AppArgumentsTests 风格）：--frame-profile 解析、缺省关闭；
//  - 缺省关闭：无探针（零测量路径）、未激活 recorder 不产生文件；
//  - 帧记录：settle 期间逐帧各阶段耗时（input/state/view/total ns）+ 手势活动标记；
//  - 输入记录：gesture.changed 等输入事件各阶段耗时 + phase；
//  - 行为不变性：同一手势序列有/无探针 → 状态机结果完全一致。
//

import AppKit
import XCTest
@testable import PagingCore
@testable import PagingPrototypeApp
@testable import PagingUI

final class FrameProfileTests: XCTestCase {

    // MARK: - 参数解析（AppArgumentsTests 风格）

    func testFrameProfileArgumentParsed() throws {
        XCTAssertFalse(try AppArguments.parse([]).get().frameProfile, "缺省关闭")
        XCTAssertTrue(try AppArguments.parse(["--frame-profile"]).get().frameProfile)
        // 与既有参数共存。
        XCTAssertTrue(try AppArguments.parse(["--frame-profile", "--paging-lab", "--page-count", "3"]).get().frameProfile)
        XCTAssertFalse(try AppArguments.parse(["--paging-lab"]).get().frameProfile)
    }

    func testFrameProfileHelpText() {
        XCTAssertTrue(AppArguments.helpText().contains("--frame-profile"))
    }

    // MARK: - 缺省关闭（无测量路径 / 无文件）

    func testDefaultSurfaceHasNoProfiler() {
        let surface = makeSurface(pageCount: 5)
        XCTAssertNil(surface.frameProfiler, "缺省 = nil：零测量路径")
        // 无探针时行为照旧（手势 + 帧照常推进）。
        flingForwardOnce(surface)
        XCTAssertEqual(surface.core.committedPage, 1)
        XCTAssertEqual(surface.core.state, .idle)
    }

    func testInactiveRecorderProducesNoFile() throws {
        let url = tempProfileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = FrameProfileRecorder(runID: "inactive-test", fileURL: url, active: false)
        recorder.beginFrame(timestamp: 0)
        recorder.markFrameInputDone()
        recorder.markFrameStateDone()
        recorder.markFrameViewDone()
        recorder.endFrame(gestureActive: true)
        recorder.beginInput(timestamp: 0, phase: "changed")
        recorder.markInputDispatchDone()
        recorder.markInputViewDone()
        recorder.endInput(gestureActive: true)
        recorder.flush()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "未激活：不产生文件")
        XCTAssertEqual(recorder.recordCount, 0, "未激活：零记录")
    }

    // MARK: - 输出格式

    func testDefaultFileURLPattern() {
        let recorder = FrameProfileRecorder(runID: "abc-123")
        XCTAssertEqual(recorder.fileURL.lastPathComponent, "launch-copy-paging-prototype-abc-123-profile.jsonl")
        XCTAssertEqual(recorder.fileURL.deletingLastPathComponent().path, "/tmp")
    }

    func testRunIDSanitized() {
        XCTAssertEqual(FrameProfileRecorder.sanitizedRunID("a b/c"), "a_b_c")
        XCTAssertEqual(FrameProfileRecorder.sanitizedRunID(""), "run")
        XCTAssertEqual(FrameProfileRecorder.sanitizedRunID("ok-1.2_3"), "ok-1.2_3")
    }

    // MARK: - 帧记录（settle 期间逐帧阶段耗时）

    func testFrameRecordsWrittenDuringSettle() throws {
        let url = tempProfileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = FrameProfileRecorder(runID: "frame-test", fileURL: url, active: true)
        let surface = makeSurface(pageCount: 5)
        surface.frameProfiler = recorder

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 400, at: 0.5)
        gestureEnded(surface, at: 0.5)
        finishPendingGesture(surface, at: 0.5)
        XCTAssertEqual(surface.core.state, .settling)
        for _ in 0..<60 { surface.advanceFrame(deltaTime: 1.0 / 60.0) }
        recorder.flush()

        let lines = try readProfileLines(url)
        let frames = lines.filter { $0["kind"] == "frame" }
        XCTAssertFalse(frames.isEmpty, "settle 期间应有帧记录")
        XCTAssertTrue(frames.contains { $0["gesture_active"] == "true" }, "settle 帧 = 手势活动")
        for record in frames {
            XCTAssertNotNil(record["timestamp"], "每帧带时间戳")
            for key in ["input_ns", "state_ns", "view_ns", "total_ns"] {
                let value = Int64(record[key] ?? "-1") ?? -1
                XCTAssertGreaterThanOrEqual(value, 0, "\(key) 非负（实际 \(value)）")
            }
            let total = Int64(record["total_ns"] ?? "-1") ?? -1
            let input = Int64(record["input_ns"] ?? "-1") ?? -1
            let state = Int64(record["state_ns"] ?? "-1") ?? -1
            let view = Int64(record["view_ns"] ?? "-1") ?? -1
            XCTAssertLessThanOrEqual(input + state + view, total, "阶段和 ≤ 总耗时")
        }
    }

    // MARK: - 输入记录（gesture.changed 等）

    func testInputRecordsWrittenForGestureChanged() throws {
        let url = tempProfileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = FrameProfileRecorder(runID: "input-test", fileURL: url, active: true)
        let surface = makeSurface(pageCount: 5)
        surface.frameProfiler = recorder

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 200, at: 0.1)
        gestureChanged(surface, deltaX: 200, at: 0.2)
        gestureEnded(surface, at: 0.2)
        finishPendingGesture(surface, at: 0.2)
        recorder.flush()

        let lines = try readProfileLines(url)
        let inputs = lines.filter { $0["kind"] == "input" }
        XCTAssertEqual(inputs.count, 5, "began + 2×changed + ended + finishPendingGesture")
        XCTAssertTrue(inputs.contains { $0["phase"] == "began" })
        XCTAssertTrue(inputs.contains { $0["phase"] == "changed" })
        XCTAssertTrue(inputs.contains { $0["phase"] == "ended" })
        for record in inputs {
            XCTAssertEqual(record["gesture_active"], "true", "输入事件期间 = 手势活动")
            for key in ["input_ns", "state_ns", "view_ns", "total_ns"] {
                let value = Int64(record[key] ?? "-1") ?? -1
                XCTAssertGreaterThanOrEqual(value, 0, "\(key) 非负（实际 \(value)）")
            }
        }
    }

    func testMomentumInputRecordsPhase() throws {
        let url = tempProfileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = FrameProfileRecorder(runID: "momentum-test", fileURL: url, active: true)
        let surface = makeSurface(pageCount: 5)
        surface.frameProfiler = recorder

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 400, at: 0.5)
        gestureEnded(surface, at: 0.5)
        momentumBegan(surface, at: 0.5)
        momentumChanged(surface, deltaX: 100, at: 0.55)
        momentumEnded(surface, at: 0.6)
        recorder.flush()

        let lines = try readProfileLines(url)
        let inputs = lines.filter { $0["kind"] == "input" }
        XCTAssertTrue(inputs.contains { $0["phase"] == "momentum.began" })
        XCTAssertTrue(inputs.contains { $0["phase"] == "momentum.changed" })
        XCTAssertTrue(inputs.contains { $0["phase"] == "momentum.ended" })
    }

    // MARK: - 行为不变性（探针不参与逻辑）

    func testProfilerDoesNotChangeBehavior() {
        let url = tempProfileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = FrameProfileRecorder(runID: "invariance-test", fileURL: url, active: true)

        let plain = makeSurface(pageCount: 5)
        let profiled = makeSurface(pageCount: 5)
        profiled.frameProfiler = recorder

        for surface in [plain, profiled] {
            for round in 0..<3 {
                flingForwardOnce(surface, at: TimeInterval(round) * 10)
            }
        }
        XCTAssertEqual(plain.core.committedPage, profiled.core.committedPage)
        XCTAssertEqual(plain.core.commitCount, profiled.core.commitCount)
        XCTAssertEqual(plain.core.staleRejectionCount, profiled.core.staleRejectionCount)
        XCTAssertEqual(plain.core.state, profiled.core.state)
        XCTAssertEqual(plain.layoutPerformedCount, profiled.layoutPerformedCount)
        XCTAssertEqual(plain.liveHostCount, profiled.liveHostCount)
        XCTAssertEqual(plain.poolHostCount, profiled.poolHostCount)
    }

    // MARK: - 异步 writer 修复

    func testThresholdBatchIsQueuedOffTheCallingThread() {
        let url = tempProfileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let queue = DispatchQueue(label: "FrameProfileTests.suspendedWriter")
        queue.suspend()
        let lock = NSLock()
        var sinkCalls = 0
        var sinkRanOnMain = true
        let writer = BufferedJSONLWriter(fileURL: url, queue: queue) { _ in
            lock.lock()
            sinkCalls += 1
            sinkRanOnMain = Thread.isMainThread
            lock.unlock()
        }
        let recorder = FrameProfileRecorder(
            runID: "queued-threshold",
            fileURL: url,
            active: true,
            writer: writer
        )
        recorder.flushThreshold = 1

        recordInput(recorder, timestamp: 1)

        // The writer queue is suspended: reaching this assertion proves the
        // threshold callback only cut/enqueued the batch; it did not run a
        // blocking sink (or file I/O) on the calling thread.
        lock.lock()
        XCTAssertEqual(sinkCalls, 0)
        lock.unlock()

        queue.resume()
        recorder.flush()

        lock.lock()
        XCTAssertEqual(sinkCalls, 1)
        XCTAssertFalse(sinkRanOnMain, "诊断 sink 必须在专用 writer queue 执行")
        lock.unlock()
    }

    func testFlushWritesAllThresholdBatchesInAcceptanceOrder() throws {
        let url = tempProfileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = FrameProfileRecorder(runID: "ordered-batches", fileURL: url, active: true)
        recorder.flushThreshold = 2

        for timestamp in 1...5 {
            recordInput(recorder, timestamp: TimeInterval(timestamp))
        }
        XCTAssertEqual(recorder.recordCount, 5)

        recorder.flush()

        let lines = try readProfileLines(url)
        XCTAssertEqual(lines.count, 5, "flush 必须等待所有已接收批次落盘")
        XCTAssertEqual(
            lines.compactMap { $0["timestamp"] },
            ["1", "2", "3", "4", "5"],
            "串行 writer 必须保持批次与批内记录的接收顺序"
        )
    }

    func testDiagnosticFilePermissionsAreOwnerOnly() throws {
        let url = tempProfileURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let recorder = FrameProfileRecorder(runID: "permissions", fileURL: url, active: true)
        recordInput(recorder, timestamp: 1)
        recorder.flush()

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let permissions = try XCTUnwrap(attributes[.posixPermissions] as? NSNumber).intValue
        XCTAssertEqual(permissions & 0o777, 0o600)
    }

    func testWriterFailureCountIsQueryableWithoutCrashing() {
        enum ForcedWriteFailure: Error { case forced }

        let writer = BufferedJSONLWriter(fileURL: tempProfileURL()) { _ in
            throw ForcedWriteFailure.forced
        }
        let recorder = FrameProfileRecorder(
            runID: "write-failure",
            active: true,
            writer: writer
        )
        recorder.flushThreshold = 1

        recordInput(recorder, timestamp: 1)
        recorder.flush()

        XCTAssertEqual(recorder.writeFailureCount, 1)
    }

    // MARK: - 工具

    private func recordInput(_ recorder: FrameProfileRecorder, timestamp: TimeInterval) {
        recorder.beginInput(timestamp: timestamp, phase: "changed")
        recorder.markInputDispatchDone()
        recorder.markInputViewDone()
        recorder.endInput(gestureActive: true)
    }

    private func tempProfileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("fp-test-\(UUID().uuidString).jsonl")
    }

    /// 读取 profile 文件并解析为 [key: String] 记录数组（JSON 非法即抛错）。
    /// JSON 布尔归一化为 "true"/"false"（JSONSerialization 的 NSNumber 描述是 1/0）。
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
