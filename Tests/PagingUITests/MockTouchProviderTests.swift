//
//  MockTouchProviderTests.swift
//  PagingUITests
//
//  Phase 1G T-G-P2 Mock provider 专项：
//  帧契约（began → moved* → ended/cancelled；零触点 moved = 结束证据）、
//  非法帧拒绝（NaN/Infinity/负时间戳/重复触点/超上限/畸形 began）、
//  设备隔离（device-scoped 独立会话）、单调时间域（帧时间戳来自注入时钟）、
//  状态通知机制（Off/Checking/Ready/NoDevice/Unavailable/PermissionNotConfirmed/Suspended）、
//  预置序列按时间推进回放（playback）。
//  合成匿名触点夹具（复用 PinchRecognizerTests 的 squareContacts）；不提交真实触控板轨迹。
//

import XCTest
@testable import PagingPrototypeApp

final class MockTouchProviderTests: XCTestCase {

    private let device = PinchDeviceID(rawValue: 1)

    private func makeMock() -> MockTouchProvider {
        MockTouchProvider(clock: FakePinchClock())
    }

    // MARK: 帧契约：began → moved* → ended/cancelled

    func testContractBeganMidSessionRejected() {
        let mock = makeMock()
        mock.start()
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device) // 违反：会话中 began
        XCTAssertEqual(mock.contractViolationCount, 1)
        XCTAssertEqual(mock.deliveredFrameCount, 1)
    }

    func testContractMovedWithoutBeganRejected() {
        let mock = makeMock()
        mock.start()
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.2), deviceID: device) // 违反：无 began
        XCTAssertEqual(mock.contractViolationCount, 1)
        XCTAssertEqual(mock.deliveredFrameCount, 0)
    }

    func testContractEndedWithoutBeganRejected() {
        let mock = makeMock()
        mock.start()
        mock.push(phase: .ended, contacts: [], deviceID: device) // 违反：无 began
        XCTAssertEqual(mock.contractViolationCount, 1)
        XCTAssertEqual(mock.deliveredFrameCount, 0)
    }

    func testContractCancelledWithoutBeganRejected() {
        let mock = makeMock()
        mock.start()
        mock.push(phase: .cancelled, contacts: [], deviceID: device) // 违反：无 began
        XCTAssertEqual(mock.contractViolationCount, 1)
        XCTAssertEqual(mock.deliveredFrameCount, 0)
    }

    func testContractZeroContactMovedClosesSession() {
        let mock = makeMock()
        mock.start()
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        mock.push(phase: .moved, contacts: [], deviceID: device) // 结束证据：会话关闭
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device) // 新会话合法
        XCTAssertEqual(mock.contractViolationCount, 0)
        XCTAssertEqual(mock.deliveredFrameCount, 3)
    }

    func testContractEndedClosesSession() {
        let mock = makeMock()
        mock.start()
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        mock.push(phase: .ended, contacts: [], deviceID: device)
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device) // 新会话合法
        XCTAssertEqual(mock.contractViolationCount, 0)
        XCTAssertEqual(mock.deliveredFrameCount, 3)
    }

    func testContractCancelledClosesSession() {
        let mock = makeMock()
        mock.start()
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        mock.push(phase: .cancelled, contacts: [], deviceID: device)
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device) // 新会话合法
        XCTAssertEqual(mock.contractViolationCount, 0)
        XCTAssertEqual(mock.deliveredFrameCount, 3)
    }

    func testContractMovedAfterEndEvidenceRejected() {
        let mock = makeMock()
        mock.start()
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        mock.push(phase: .moved, contacts: [], deviceID: device) // 结束证据
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.2), deviceID: device) // 违反：会话已关
        XCTAssertEqual(mock.contractViolationCount, 1)
        XCTAssertEqual(mock.deliveredFrameCount, 2)
    }

    // MARK: 非法帧拒绝

    func testInvalidFramesRejected() {
        let mock = makeMock()
        mock.start()

        // NaN 位置
        var nan = squareContacts(halfSize: 0.2)
        nan[0] = PinchContact(id: PinchContactID(rawValue: 1), position: PinchPoint(x: .nan, y: 0.3))
        mock.push(phase: .began, contacts: nan, deviceID: device)

        // Infinity 位置
        var inf = squareContacts(halfSize: 0.2)
        inf[1] = PinchContact(id: PinchContactID(rawValue: 2), position: PinchPoint(x: .infinity, y: 0.3))
        mock.push(phase: .began, contacts: inf, deviceID: device)

        // 负时间戳
        mock.push(PinchFrame(deviceID: device, timestamp: -1, phase: .began, contacts: squareContacts(halfSize: 0.2)))

        // 重复触点 id
        var dup = squareContacts(halfSize: 0.2)
        dup[3] = dup[0]
        mock.push(phase: .began, contacts: dup, deviceID: device)

        // 超上限计数（默认 maxContactCount = 16；构造 17 个）
        var many = squareContacts(halfSize: 0.2)
        for i in 5...17 {
            many.append(PinchContact(id: PinchContactID(rawValue: i), position: PinchPoint(x: 0.5, y: 0.5)))
        }
        mock.push(phase: .began, contacts: many, deviceID: device)

        // 畸形 began（零触点）
        mock.push(phase: .began, contacts: [], deviceID: device)

        XCTAssertEqual(mock.rejectedFrameCount, 6)
        XCTAssertEqual(mock.deliveredFrameCount, 0)
    }

    // MARK: 设备隔离（device-scoped 独立会话）

    func testDeviceScopedSessionsIndependent() {
        let mock = makeMock()
        mock.start()
        let deviceA = PinchDeviceID(rawValue: 1)
        let deviceB = PinchDeviceID(rawValue: 2)

        // A/B 独立会话交错：全部合法
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: deviceA)
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: deviceB)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.2), deviceID: deviceA)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.2), deviceID: deviceB)
        mock.push(phase: .ended, contacts: [], deviceID: deviceA)
        mock.push(phase: .ended, contacts: [], deviceID: deviceB)
        XCTAssertEqual(mock.contractViolationCount, 0)
        XCTAssertEqual(mock.deliveredFrameCount, 6)
    }

    func testDeviceScopedBeganIsPerDevice() {
        let mock = makeMock()
        mock.start()
        let deviceA = PinchDeviceID(rawValue: 1)
        let deviceB = PinchDeviceID(rawValue: 2)

        // A 会话中，B 可独立 began（不视为 A 的违反）
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: deviceA)
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: deviceB)
        XCTAssertEqual(mock.contractViolationCount, 0)

        // 同设备重复 began 才是违反
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: deviceA)
        XCTAssertEqual(mock.contractViolationCount, 1)
    }

    // MARK: 单调时间域（帧时间戳来自注入时钟，禁止墙钟）

    func testFramesStampedFromInjectedClock() {
        let clock = FakePinchClock()
        let mock = MockTouchProvider(clock: clock)
        var stamps: [TimeInterval] = []
        mock.onFrame = { stamps.append($0.timestamp) }
        mock.start()

        clock.current = 42.0
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        clock.advance(0.5)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.2), deviceID: device)

        XCTAssertEqual(stamps, [42.0, 42.5], "帧时间戳来自注入时钟（与识别器同一单调时间域）")
    }

    // MARK: 预置序列按时间推进回放

    func testPlaybackPresetSequenceAdvancesTime() {
        let clock = FakePinchClock()
        let mock = MockTouchProvider(clock: clock)
        var stamps: [TimeInterval] = []
        mock.onFrame = { stamps.append($0.timestamp) }
        mock.start()

        mock.playback([
            MockFrameStep(phase: .began, contacts: squareContacts(halfSize: 0.2), timeStep: 0.1),
            MockFrameStep(phase: .moved, contacts: squareContacts(halfSize: 0.2), timeStep: 0.01),
            MockFrameStep(phase: .moved, contacts: squareContacts(halfSize: 0.16), timeStep: 0),
        ], deviceID: device)

        XCTAssertEqual(stamps, [0, 0.1, 0.11], "预置序列按时间推进回放")
        XCTAssertEqual(clock.current, 0.11, "共享时钟被推进")
    }

    func testPlaybackRequiresStarted() {
        let mock = makeMock()
        mock.playback([MockFrameStep(phase: .began, contacts: squareContacts(halfSize: 0.2))], deviceID: device)
        XCTAssertEqual(mock.deliveredFrameCount, 0, "未启动回放零交付")
        XCTAssertEqual(mock.rejectedFrameCount, 1)
    }

    // MARK: 状态通知机制（Off/Checking/Ready/NoDevice/Unavailable/PermissionNotConfirmed/Suspended）

    func testStateNotificationSequence() {
        let clock = FakePinchClock()
        let mock = MockTouchProvider(clock: clock)
        var states: [TouchProviderState] = []
        mock.onStateChange = { states.append($0) }

        mock.start()
        mock.simulateStateChange(.noDevice)
        mock.simulateStateChange(.unavailable)
        mock.simulateStateChange(.permissionNotConfirmed)
        mock.simulateStateChange(.suspended(reason: .sleep))
        mock.stop()

        XCTAssertEqual(states, [
            .checking, .ready,
            .noDevice, .unavailable, .permissionNotConfirmed,
            .suspended(reason: .sleep),
            .off,
        ])
        XCTAssertEqual(mock.state, .off)
    }

    func testStartupStateConfigurable() {
        let clock = FakePinchClock()
        let mock = MockTouchProvider(clock: clock)
        mock.startupState = .noDevice
        var states: [TouchProviderState] = []
        mock.onStateChange = { states.append($0) }

        mock.start()

        XCTAssertEqual(mock.state, .noDevice)
        XCTAssertEqual(states, [.checking, .noDevice], "启动模拟枚举结果")
    }

    func testStateChangeNotificationOutsideLock() {
        // 状态回调内可安全调用 restart（锁外派发的确定性证明）
        let mock = makeMock()
        var restartCalled = false
        mock.onStateChange = { _ in
            if !restartCalled {
                restartCalled = true
                mock.restart()
            }
        }
        mock.start()
        XCTAssertTrue(restartCalled)
        XCTAssertTrue(mock.isStarted)
        XCTAssertEqual(mock.state, .ready)
    }
}
