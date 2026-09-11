//
//  PinchRecognizerLifecycleTests.swift
//  PagingUITests
//
//  Phase 1G §23.1 生命周期纯逻辑部分（T-G-P1）：
//  P13 开关关闭/暂停/Quit 后 late callback 和排队事件被丢弃；
//  P14 start/stop 重入、旧 generation stop 不影响新订阅；
//  P15 同步重入假后端验证注册/注销无死锁（识别器为无锁值类型）。
//  另含 §19.2 合同 11：Suspend/stop/disable/restart 清基线/会话/待派发意图。
//

import XCTest
@testable import PagingPrototypeApp

final class PinchRecognizerLifecycleTests: XCTestCase {

    private let device = PinchDeviceID(rawValue: 1)

    // MARK: P13 开关关闭、暂停、Quit 后 late callback 和排队事件被丢弃

    func testP13DisableDropsLateCallbacks() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        r.disable()
        XCTAssertEqual(r.state, .disabled)
        let events = processAt(&r, clock, frame(device, 0.1, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(events, [], "disable 后 late callback 丢弃")
        XCTAssertEqual(r.fireCount, 0)
    }

    func testP13SuspendDropsCallbacks() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        r.suspend(reason: .sleep)
        XCTAssertEqual(r.state, .suspended(reason: .sleep))
        let events = processAt(&r, clock, frame(device, 0.1, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(events, [])
        XCTAssertEqual(r.fireCount, 0)
    }

    func testP13TeardownDropsCallbacks() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        r.teardown()
        XCTAssertEqual(r.state, .disabled)
        let events = processAt(&r, clock, frame(device, 0.1, .moved, squareContacts(halfSize: 0.16)))
        XCTAssertEqual(events, [])
    }

    func testP13FiredEventTokenGenerationInvalidatedByStop() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        let events = runStandardPinch(&r, clock, device: device)
        XCTAssertEqual(events.count, 1)
        guard case .showRequested(let token) = events[0] else {
            return XCTFail("事件必须是 showRequested")
        }
        XCTAssertEqual(token.generation, r.generation)

        r.stop()
        XCTAssertEqual(r.generation, token.generation + 1, "stop 使旧 generation 事件失效（消费方据此丢弃）")
    }

    // MARK: P14 start/stop 重入、旧 generation stop 不影响新订阅

    func testP14StartStopReentryIdempotent() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        r.start() // 已启动：幂等
        XCTAssertEqual(r.state, .idle)
        r.start()
        XCTAssertEqual(r.state, .idle)

        r.stop()
        XCTAssertEqual(r.state, .disabled)
        r.stop() // 已停止：幂等
        XCTAssertEqual(r.state, .disabled)
    }

    func testP14StopClearsSessionAndOldGenerationDoesNotAffectNewSubscription() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)
        let genBefore = r.generation

        r.stop()
        XCTAssertEqual(r.generation, genBefore + 1)
        XCTAssertEqual(r.state, .disabled)

        r.start()
        XCTAssertEqual(r.state, .idle)

        // 新订阅：全新会话可正常触发，事件携带当前 generation
        let events = runStandardPinch(&r, clock, device: device, start: 0.1)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(r.fireCount, 1)
        guard case .showRequested(let token) = events[0] else {
            return XCTFail("事件必须是 showRequested")
        }
        XCTAssertEqual(token.generation, r.generation, "新订阅事件携带当前 generation")
    }

    func testP14RestartClearsSessionAndBumpsGeneration() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)
        let genBefore = r.generation

        r.restart()
        XCTAssertEqual(r.generation, genBefore + 1)
        XCTAssertEqual(r.state, .idle)

        // 旧会话已清：新帧建立新候选
        _ = processAt(&r, clock, frame(device, 0.1, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)
    }

    // MARK: P15 同步重入假后端验证注册/注销无死锁

    func testP15SynchronousReentryFakeBackendNoDeadlock() {
        // 识别器为无锁值类型：同步重入（事件返回后立即继续投递帧）不会死锁。
        // register/unregister 属 provider 域（T-G-P2）；本测试验证识别器 API 重入安全。
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)
        var t: TimeInterval = 0
        var events: [PinchEvent] = []

        // 同步后端：每帧投递后立即处理返回事件；事件处理中再次投递（重入）。
        func deliver(_ contacts: [PinchContact]) {
            t += 0.1
            let produced = processAt(&r, clock, frame(device, t, .moved, contacts))
            for e in produced {
                events.append(e)
                // 重入：事件处理中立即投递下一帧（同位置，保持稳定）
                t += 0.1
                _ = processAt(&r, clock, frame(device, t, .moved, squareContacts(halfSize: 0.2)))
            }
        }

        deliver(squareContacts(halfSize: 0.2))   // t=0.1：首帧 → candidate（建基线）
        deliver(squareContacts(halfSize: 0.2))   // t=0.2：次帧 → recognizing（无稳定窗口）
        deliver(squareContacts(halfSize: 0.16))  // t=0.3：收缩 → fire（事件处理中重入 t=0.4）
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(r.fireCount, 1)
        XCTAssertEqual(r.state, .fired)
    }

    // MARK: §19.2 合同 11：Suspend/stop/disable/restart 清基线/会话/待派发意图

    func testContract11SuspendClearsSessionAndPendingIntent() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        r.suspend(reason: .sessionInactive)
        XCTAssertEqual(r.state, .suspended(reason: .sessionInactive))
        XCTAssertEqual(r.cancelCounts[.suspended], 1)

        r.resume()
        XCTAssertEqual(r.state, .idle)

        // 恢复后新会话必须重新建基线
        let fired = runStandardPinch(&r, clock, device: device, start: 0.1)
        XCTAssertEqual(fired.count, 1)
    }

    func testContract11StopClearsSession() {
        let clock = FakePinchClock()
        var r = makeRecognizer(clock: clock)

        _ = processAt(&r, clock, frame(device, 0, .began, squareContacts(halfSize: 0.2)))
        XCTAssertEqual(r.state, .candidate)

        r.stop()
        XCTAssertEqual(r.state, .disabled)
        XCTAssertEqual(r.cancelCounts[.stopped], 1)
        XCTAssertNil(r.activeSessionID, "会话已清")
    }
}
