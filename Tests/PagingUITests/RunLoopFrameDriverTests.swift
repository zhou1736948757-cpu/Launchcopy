//
//  RunLoopFrameDriverTests.swift
//  PagingUITests
//
//  T-worker-b-frame-fix 回归：默认帧驱动 RunLoopFrameDriver（runloop common 模式 60Hz Timer）
//  ——真机证据显示 NSView.displayLink 在本环境零回调，Timer(.common) 泵是真实帧源。
//  - 真实 runloop 旋转下必须实际投递帧（advanceFrame 被调用、onAnimationFrame 计数增长）；
//  - stop()/teardown 后零回调（§7.3 门禁不回归）。
//

import XCTest
@testable import PagingUI

final class RunLoopFrameDriverTests: XCTestCase {

    /// 旋转主 runloop 一小段真实时间（让 .common Timer 实际触发）。
    private func spinMainRunLoop(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    func testTimerConfigurationIsClampedAndExposed() {
        let surface = makeSurface(pageCount: 5)
        let zeroTolerance = RunLoopFrameDriver(owner: surface, tolerance: 0)
        XCTAssertEqual(zeroTolerance.interval, 1.0 / 60.0, accuracy: 0.000_001)
        XCTAssertEqual(zeroTolerance.tolerance, 0, accuracy: 0.000_001)

        let clamped = RunLoopFrameDriver(owner: surface, interval: 0, tolerance: 9)
        XCTAssertEqual(clamped.interval, 0.001, accuracy: 0.000_001)
        XCTAssertEqual(clamped.tolerance, 0.001, accuracy: 0.000_001)
    }

    func testRunLoopFrameDriverPumpsFrames() {
        let surface = makeSurface(pageCount: 5)
        let driver = RunLoopFrameDriver(owner: surface)
        surface.frameDriver = driver

        var frames = 0
        surface.onAnimationFrame = { _ in frames += 1 }

        driver.start()
        XCTAssertTrue(driver.isRunning)
        spinMainRunLoop(0.15) // ≈9 个 60Hz 节拍
        XCTAssertGreaterThan(frames, 0, "runloop 60Hz 泵真实投递帧（advanceFrame 被调用）")

        driver.stop()
        XCTAssertFalse(driver.isRunning)
        let stopped = frames
        spinMainRunLoop(0.1)
        XCTAssertEqual(frames, stopped, "stop() 后不再投递帧")
    }

    func testStartIsIdempotentAndPumpCompletesSettleThenTeardownStops() {
        let surface = makeSurface(pageCount: 5)
        let driver = RunLoopFrameDriver(owner: surface)
        surface.frameDriver = driver

        var frames = 0
        surface.onAnimationFrame = { _ in frames += 1 }

        // 手势 → settle（surface 保活驱动；与真实 GUI 路径一致）。
        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 400, at: 0.5)
        gestureEnded(surface, at: 0.5)
        finishPendingGesture(surface, at: 0.5)
        XCTAssertEqual(surface.core.state, .settling)

        driver.start()
        driver.start() // 幂等：不创建第二个 Timer（否则帧率翻倍/异常）
        spinMainRunLoop(0.4) // 真实 60Hz 泵推进 settle → commit（phys-auto-02 卡死路径的回归）
        XCTAssertGreaterThan(frames, 0, "真实 runloop 泵投递帧")
        XCTAssertEqual(surface.core.committedPage, 1, "真实泵完成 settle → commit（不再卡两页中间）")
        XCTAssertEqual(surface.core.state, .idle)
        XCTAssertFalse(surface.core.isAnimating)
        XCTAssertFalse(driver.isRunning, "settle 完成 → surface 自停驱动")

        surface.teardown()
        XCTAssertFalse(driver.isRunning, "teardown 停帧泵（§7.3 零回调门禁）")
        let afterTeardown = frames
        spinMainRunLoop(0.1)
        XCTAssertEqual(frames, afterTeardown, "teardown 后零回调（Timer 回调亦被 isTearingDown 短路）")
        XCTAssertEqual(surface.core.staleRejectionCount, 0)
    }

    func testStartStopWithoutTickEmitsArmAndNoCallback() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("runloop-callback-arm-only-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }
        let surface = makeSurface(pageCount: 5)
        let profiler = FrameCallbackProfileRecorder(
            runID: "arm-only",
            fileURL: url,
            active: true
        )
        let driver = RunLoopFrameDriver(
            owner: surface,
            interval: 0.05,
            tolerance: 0,
            callbackProfiler: profiler
        )
        surface.frameDriver = driver
        driver.start()
        driver.stop()
        profiler.flush()

        let records = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
            .map { line in
                try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
            }
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0]["kind"] as? String, "timer_generation_arm")
        XCTAssertEqual((records[0]["driver_generation"] as? NSNumber)?.uint64Value, 1)
        XCTAssertEqual((records[0]["tolerance_ns"] as? NSNumber)?.uint64Value, 0)
    }

    func testCallbackProfilerCapturesTimerBoundariesAcrossGenerations() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("runloop-callback-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }

        let surface = makeSurface(pageCount: 5)
        let profiler = FrameCallbackProfileRecorder(
            runID: "driver-boundary",
            fileURL: url,
            active: true
        )
        let driver = RunLoopFrameDriver(
            owner: surface,
            interval: 0.01,
            tolerance: 0,
            callbackProfiler: profiler
        )
        surface.frameDriver = driver

        driver.start()
        spinMainRunLoop(0.06)
        driver.stop()
        XCTAssertGreaterThan(profiler.recordCount, 0)

        let firstRunCount = profiler.recordCount
        driver.start()
        spinMainRunLoop(0.04)
        driver.stop()
        XCTAssertGreaterThan(profiler.recordCount, firstRunCount)
        profiler.flush()

        let lines = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
        XCTAssertEqual(lines.count, profiler.recordCount)
        let records = try lines.map { line in
            try XCTUnwrap(
                try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
            )
        }
        let callbacks = records.filter { $0["kind"] as? String == "frame_callback" }
        let arms = records.filter { $0["kind"] as? String == "timer_generation_arm" }
        XCTAssertFalse(callbacks.isEmpty)
        XCTAssertEqual(arms.count, 2)
        XCTAssertTrue(callbacks.allSatisfy { $0["simulation_dt_ns"] is NSNumber })
        XCTAssertTrue(callbacks.allSatisfy { $0["pre_return_ns"] is NSNumber })
        XCTAssertTrue(callbacks.contains { ($0["first_tick"] as? NSNumber)?.boolValue == true })
        XCTAssertTrue(callbacks.contains { ($0["driver_generation"] as? NSNumber)?.uint64Value == 2 })

        let sequences = callbacks.compactMap { ($0["callback_seq"] as? NSNumber)?.uint64Value }
        XCTAssertEqual(sequences, Array(1...UInt64(sequences.count)))
        let secondGeneration = callbacks.filter {
            ($0["driver_generation"] as? NSNumber)?.uint64Value == 2
        }
        XCTAssertTrue(secondGeneration.first?["raw_callback_interval_ns"] is NSNull)
        XCTAssertEqual((arms[0]["driver_generation"] as? NSNumber)?.uint64Value, 1)
        XCTAssertEqual((arms[1]["driver_generation"] as? NSNumber)?.uint64Value, 2)
    }

    func testCallbackReentrantStopAndRestartDoesNotRestoreOldGenerationSchedule() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("runloop-callback-reentrant-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }

        let surface = makeSurface(pageCount: 5)
        let profiler = FrameCallbackProfileRecorder(
            runID: "driver-reentrant-boundary",
            fileURL: url,
            active: true
        )
        let driver = RunLoopFrameDriver(
            owner: surface,
            interval: 0.02,
            tolerance: 0,
            callbackProfiler: profiler
        )
        // Keep the surface in a real settling state so advanceFrame() does not
        // immediately stop the newly restarted generation at the end of the old
        // callback. Prepare while no driver is attached to avoid an early Timer.
        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 400, at: 0.5)
        gestureEnded(surface, at: 0.5)
        finishPendingGesture(surface, at: 0.5)
        XCTAssertEqual(surface.core.state, .settling)
        surface.frameDriver = driver

        var restarted = false
        surface.onAnimationFrame = { _ in
            guard !restarted else { return }
            restarted = true
            // Make generation 1's next nominal deadline unambiguously stale before
            // generation 2 is armed. Without the generation guard, the old callback
            // would overwrite generation 2's fresh deadline after this restart.
            Thread.sleep(forTimeInterval: 0.05)
            driver.stop()
            driver.start()
        }

        driver.start()
        spinMainRunLoop(0.20)
        driver.stop()
        profiler.flush()

        let records = try String(contentsOf: url, encoding: .utf8)
            .split(separator: "\n")
            .map { line in
                try XCTUnwrap(
                    try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
                )
            }
        let callbacks = records.filter { $0["kind"] as? String == "frame_callback" }
        let firstGeneration = callbacks.filter {
            ($0["driver_generation"] as? NSNumber)?.uint64Value == 1
        }
        let secondGeneration = callbacks.filter {
            ($0["driver_generation"] as? NSNumber)?.uint64Value == 2
        }
        XCTAssertTrue(records.contains { $0["kind"] as? String == "timer_generation_arm" })
        let lastFirstGeneration = try XCTUnwrap(firstGeneration.last)
        let firstSecondGeneration = try XCTUnwrap(secondGeneration.first)
        XCTAssertTrue(firstSecondGeneration["first_tick"] as? Bool == true)
        XCTAssertTrue(firstSecondGeneration["raw_callback_interval_ns"] is NSNull)

        let firstGenerationExit = try XCTUnwrap(
            (lastFirstGeneration["exit_ns"] as? NSNumber)?.uint64Value
        )
        let secondGenerationScheduled = try XCTUnwrap(
            (firstSecondGeneration["scheduled_ns"] as? NSNumber)?.uint64Value
        )
        XCTAssertGreaterThan(
            secondGenerationScheduled,
            firstGenerationExit,
            "generation 2 must retain the fresh post-restart deadline instead of generation 1's stale schedule"
        )
    }

    func testStaleCompletionRejectedAfterTeardown() {
        // §7.3/D7：teardown 后 Core 拒绝一切 completion——帧泵停止不产生回调。
        let surface = makeSurface(pageCount: 5)
        var commits = 0
        surface.appEvents.onCommit = { _ in commits += 1 }
        let driver = RunLoopFrameDriver(owner: surface)
        surface.frameDriver = driver
        driver.start()
        surface.teardown()
        spinMainRunLoop(0.1)
        XCTAssertEqual(commits, 0)
        XCTAssertEqual(surface.core.staleRejectionCount, 0)
    }
}
