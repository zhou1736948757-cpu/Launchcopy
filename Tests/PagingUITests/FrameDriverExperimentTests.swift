//
//  FrameDriverExperimentTests.swift
//  PagingUITests
//
//  Phase 1B §8 可选帧源实验（独立测试范围）：DisplayLinkFrameDriver 探测/回退/证据。
//  用可编程 fake display link —— 测试不依赖真实 CADisplayLink 行为（真机证据经
//  --frame-driver auto/displaylink 的 GUI 自驱冒烟采集，见 T-worker-b-integration.md）。
//  同步测试（wait(for:) 旋转主 runloop 触发探测 Timer）——与 RunLoopFrameDriverTests 同构。
//

import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

/// 可编程 display link fake：按 start 触发固定次数回调（或零回调）。
final class FakeDisplayLinkProvider: DisplayLinkProviding {
    var isRunning = false
    var onTick: ((TimeInterval) -> Void)?
    /// 每次 start 同步触发的回调数（0 = 零回调环境）。
    var callbacksPerStart: Int
    var interval: TimeInterval = 1.0 / 60.0
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(callbacksPerStart: Int) {
        self.callbacksPerStart = callbacksPerStart
    }

    func start(on runLoop: RunLoop) {
        startCount += 1
        isRunning = true
        for _ in 0..<callbacksPerStart {
            onTick?(interval)
        }
    }

    func stop() {
        isRunning = false
        stopCount += 1
    }
}

final class FrameDriverExperimentTests: XCTestCase {

    private func makeSurface() -> PagingSurface {
        let surface = PagingSurface(pageCount: 5, itemsPerPage: 8)
        surface.frameDriver = nil
        surface.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
        surface.layout()
        return surface
    }

    func testZeroCallbacksFallsBackWithReason() {
        let surface = makeSurface()
        let fake = FakeDisplayLinkProvider(callbacksPerStart: 0)
        let driver = DisplayLinkFrameDriver(owner: surface, provider: fake, probeWindow: 0.1)
        var captured = ""
        let expectation = expectation(description: "evidence")
        driver.evidenceHandler = { captured = $0; expectation.fulfill() }
        driver.start()

        wait(for: [expectation], timeout: 5)
        guard case .fellBackToRunLoop(let reason) = driver.state else {
            XCTFail("零回调 → 必须回退: \(driver.state)")
            driver.stop()
            surface.teardown()
            return
        }
        XCTAssertTrue(reason.contains("zero display link callbacks"), "fallback reason 应如实记录零回调: \(reason)")
        XCTAssertTrue(captured.contains("zero display link callbacks"))
        XCTAssertEqual(fake.stopCount, 1, "零回调 → 探针停止")
        driver.stop()
        surface.teardown()
    }

    func testCallbacksRetainedWithObservedInterval() {
        let surface = makeSurface()
        let fake = FakeDisplayLinkProvider(callbacksPerStart: 5)
        fake.interval = 1.0 / 60.0
        let driver = DisplayLinkFrameDriver(owner: surface, provider: fake, probeWindow: 0.1)
        var captured = ""
        let expectation = expectation(description: "evidence")
        driver.evidenceHandler = { captured = $0; expectation.fulfill() }
        driver.start()

        wait(for: [expectation], timeout: 5)
        guard case .displayLink(let observed) = driver.state else {
            XCTFail("有回调时应保留 display link 探针: \(driver.state)")
            driver.stop()
            surface.teardown()
            return
        }
        XCTAssertEqual(observed, 1.0 / 60.0, accuracy: 0.0001, "observed interval = 实测平均帧间隔")
        XCTAssertTrue(captured.contains("display link probe retained"))
        XCTAssertGreaterThanOrEqual(driver.callbackCount, 5)
        driver.stop()
        surface.teardown()
    }

    func testForcedDisplayLinkStillFallsBackHonestly() {
        let surface = makeSurface()
        let fake = FakeDisplayLinkProvider(callbacksPerStart: 0)
        let driver = DisplayLinkFrameDriver(owner: surface, provider: fake,
                                            forceDisplayLink: true, probeWindow: 0.1)
        var captured = ""
        let expectation = expectation(description: "evidence")
        driver.evidenceHandler = { captured = $0; expectation.fulfill() }
        driver.start()

        wait(for: [expectation], timeout: 5)
        XCTAssertTrue(captured.contains("forced displaylink"), "forced 模式零回调也必须如实回退（不假装 PASS）")
        guard case .fellBackToRunLoop = driver.state else {
            XCTFail("forced 模式零回调 → 必须回退: \(driver.state)")
            driver.stop()
            surface.teardown()
            return
        }
        driver.stop()
        surface.teardown()
    }

    func testFramesNeverFreezeDuringProbe() {
        // 探测期间帧源（RunLoopFrameDriver）恒在：start 后 driver.isRunning 保持 true，
        // 回退后仍 true（60Hz RunLoop 路径不受影响）；stop 幂等。
        let surface = makeSurface()
        let fake = FakeDisplayLinkProvider(callbacksPerStart: 0)
        let driver = DisplayLinkFrameDriver(owner: surface, provider: fake, probeWindow: 0.1)
        let expectation = expectation(description: "evidence")
        driver.evidenceHandler = { _ in expectation.fulfill() }
        driver.start()

        wait(for: [expectation], timeout: 5)
        XCTAssertTrue(driver.isRunning, "回退后帧驱动仍在运行（帧源 = RunLoop，不冻结）")
        driver.stop()
        XCTAssertFalse(driver.isRunning)
        driver.stop() // 幂等
        surface.teardown()
    }
}
