//
//  TouchProviderIntegrationTests.swift
//  PagingUITests
//
//  Phase 1G T-G-P2 集成测试：MockTouchProvider 帧序列 → PinchRecognizer 完整识别。
//  复用 T-G-P1 夹具模式（FakePinchClock/squareContacts/makeRecognizer），验证 provider→recognizer 接线：
//  同步 push、异步 drain、playback 预置序列、两设备独立会话、stop 后帧不达识别器。
//  合成匿名触点夹具；不提交真实触控板轨迹。
//

import XCTest
@testable import PagingPrototypeApp

final class TouchProviderIntegrationTests: XCTestCase {

    private let device = PinchDeviceID(rawValue: 1)

    // MARK: 同步 push → 完整识别

    func testIntegrationSynchronousPushFullPinch() {
        let clock = FakePinchClock()
        let mock = MockTouchProvider(clock: clock)
        var r = makeRecognizer(clock: clock)
        var events: [PinchEvent] = []
        mock.onFrame = { frame in events += r.process(frame) }
        mock.start()

        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        clock.advance(0.1)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        clock.advance(0.01)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.16), deviceID: device)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(r.fireCount, 1)
        XCTAssertEqual(r.state, .fired)
        guard case .showRequested(let token) = events[0] else {
            return XCTFail("事件必须是 showRequested")
        }
        XCTAssertEqual(token.generation, r.generation)
        XCTAssertEqual(token.sessionID, r.activeSessionID, "事件 token 携带当前会话")
    }

    func testIntegrationReleaseReArmsThroughProvider() {
        let clock = FakePinchClock()
        let mock = MockTouchProvider(clock: clock)
        var r = makeRecognizer(clock: clock)
        var events: [PinchEvent] = []
        mock.onFrame = { frame in events += r.process(frame) }
        mock.start()

        // 第一次触发
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        clock.advance(0.1)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        clock.advance(0.01)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.16), deviceID: device)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(r.fireCount, 1)

        // 零触点 moved（结束证据）→ 释放
        clock.advance(0.1)
        mock.push(phase: .moved, contacts: [], deviceID: device)
        XCTAssertEqual(r.state, .idle)

        // 新会话再次触发
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        clock.advance(0.1)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        clock.advance(0.01)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.16), deviceID: device)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(r.fireCount, 2)
    }

    func testIntegrationTwoDevicesIndependentSessions() {
        let clock = FakePinchClock()
        let mock = MockTouchProvider(clock: clock)
        var r = makeRecognizer(clock: clock)
        var events: [PinchEvent] = []
        mock.onFrame = { frame in events += r.process(frame) }
        mock.start()
        let deviceA = PinchDeviceID(rawValue: 1)
        let deviceB = PinchDeviceID(rawValue: 2)

        // A 全捏合触发
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: deviceA)
        clock.advance(0.1)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.2), deviceID: deviceA)
        clock.advance(0.01)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.16), deviceID: deviceA)
        XCTAssertEqual(events.count, 1)

        // B 独立会话全捏合触发（设备隔离，不继承 A 基线）
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: deviceB)
        clock.advance(0.1)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.2), deviceID: deviceB)
        clock.advance(0.01)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.16), deviceID: deviceB)
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(r.fireCount, 2)
    }

    // MARK: 异步 drain → 完整识别

    func testIntegrationAsyncDrainFullPinch() {
        let clock = FakePinchClock()
        let mock = MockTouchProvider(clock: clock, deliveryMode: .asynchronous)
        var r = makeRecognizer(clock: clock)
        var events: [PinchEvent] = []
        mock.onFrame = { frame in events += r.process(frame) }
        mock.start()

        // push 阶段推进共享时钟（帧按 push 时刻打戳）
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        clock.advance(0.1)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        clock.advance(0.01)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.16), deviceID: device)
        XCTAssertEqual(mock.pendingFrameCount, 3)
        XCTAssertEqual(events.count, 0, "异步模式 push 不立即交付")

        mock.drain() // 模拟异步回调线程交付
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(r.fireCount, 1)
        XCTAssertEqual(r.state, .fired)
    }

    // MARK: playback 预置序列 → 完整识别

    func testIntegrationPlaybackFullPinch() {
        let clock = FakePinchClock()
        let mock = MockTouchProvider(clock: clock)
        var r = makeRecognizer(clock: clock)
        var events: [PinchEvent] = []
        mock.onFrame = { frame in events += r.process(frame) }
        mock.start()

        mock.playback([
            MockFrameStep(phase: .began, contacts: squareContacts(halfSize: 0.2), timeStep: 0.1),
            MockFrameStep(phase: .moved, contacts: squareContacts(halfSize: 0.2), timeStep: 0.01),
            MockFrameStep(phase: .moved, contacts: squareContacts(halfSize: 0.16), timeStep: 0),
        ], deviceID: device)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(r.fireCount, 1)
        XCTAssertEqual(r.state, .fired)
    }

    // MARK: stop 后帧不达识别器（P13 集成）

    func testIntegrationStopDropsFramesBeforeRecognizer() {
        let clock = FakePinchClock()
        let mock = MockTouchProvider(clock: clock)
        var r = makeRecognizer(clock: clock)
        var events: [PinchEvent] = []
        mock.onFrame = { frame in events += r.process(frame) }
        mock.start()

        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        XCTAssertEqual(r.state, .candidate)

        mock.stop()
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.16), deviceID: device)
        XCTAssertEqual(events, [], "stop 后帧不达识别器")
        XCTAssertEqual(r.fireCount, 0)
        XCTAssertEqual(r.state, .candidate, "识别器状态不被迟到帧改变")
    }

    // MARK: 状态门控（suspended 帧由识别器丢弃，P13 集成）

    func testIntegrationSuspendedFramesDroppedByRecognizer() {
        let clock = FakePinchClock()
        let mock = MockTouchProvider(clock: clock)
        var r = makeRecognizer(clock: clock)
        var events: [PinchEvent] = []
        mock.onFrame = { frame in events += r.process(frame) }
        mock.start()

        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        XCTAssertEqual(r.state, .candidate)

        r.suspend(reason: .sleep)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.16), deviceID: device)
        XCTAssertEqual(events, [], "suspended 后帧被识别器丢弃")
        XCTAssertEqual(r.fireCount, 0)
    }
}
