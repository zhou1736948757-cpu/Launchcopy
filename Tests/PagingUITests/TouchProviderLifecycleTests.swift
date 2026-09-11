//
//  TouchProviderLifecycleTests.swift
//  PagingUITests
//
//  Phase 1G §23.1 P13/P14/P15 + §20.2 锁序（T-G-P2，provider 域）：
//  P13 开关关闭/Quit 后 late callback 和排队事件被丢弃（provider 层：stop 清缓冲 + generation 校验）；
//  P14 start/start、stop/stop、start-stop-start 幂等与序列正确；
//  P15 同步重入假后端验证注册/注销无死锁（回调内 stop/restart）；
//  §20.2 回调锁外派发（回调内可安全重入）、缓冲有界（迟到帧不无限堆积）、保留 begin/end/cancel。
//  合成匿名触点夹具（复用 PinchRecognizerTests 的 squareContacts）；不提交真实触控板轨迹。
//

import XCTest
@testable import PagingPrototypeApp

extension FakePinchClock: PinchClockAdvancing {
    func advance(by delta: TimeInterval) { advance(delta) }
}

final class TouchProviderLifecycleTests: XCTestCase {

    private let device = PinchDeviceID(rawValue: 1)

    private func makeMock(deliveryMode: MockTouchProvider.DeliveryMode = .synchronous) -> MockTouchProvider {
        MockTouchProvider(clock: FakePinchClock(), deliveryMode: deliveryMode)
    }

    // MARK: P13 开关关闭/Quit 后 late callback 和排队事件被丢弃

    func testP13StopDropsQueuedLateCallbacks() {
        let mock = makeMock(deliveryMode: .asynchronous)
        mock.start()
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        XCTAssertEqual(mock.pendingFrameCount, 2)

        mock.stop()
        XCTAssertEqual(mock.pendingFrameCount, 0, "stop 清空缓冲")

        mock.drain() // 迟到回调：队列已清 → 零交付
        XCTAssertEqual(mock.deliveredFrameCount, 0)
    }

    func testP13StopDropsFramesPushedAfterStop() {
        let mock = makeMock()
        mock.start()
        mock.stop()
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        XCTAssertEqual(mock.deliveredFrameCount, 0)
        XCTAssertEqual(mock.rejectedFrameCount, 1, "未启动 push 被拒绝")
    }

    func testP13StopBumpsGenerationInvalidatingOldEvents() {
        let mock = makeMock()
        mock.start()
        let gen = mock.generation
        mock.stop()
        XCTAssertEqual(mock.generation, gen + 1, "stop 使旧 generation 事件失效（消费方据此丢弃）")
    }

    func testP13RestartClearsQueueAndBumpsGeneration() {
        let mock = makeMock(deliveryMode: .asynchronous)
        mock.start()
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        let gen = mock.generation
        mock.restart()
        XCTAssertEqual(mock.generation, gen + 1)
        XCTAssertEqual(mock.pendingFrameCount, 0, "restart 清空缓冲")
        mock.drain()
        XCTAssertEqual(mock.deliveredFrameCount, 0, "restart 后迟到回调零交付")
    }

    // MARK: P14 start/start、stop/stop、start-stop-start

    func testP14StartStartIdempotent() {
        let mock = makeMock()
        mock.start()
        let gen = mock.generation
        let state = mock.state
        let changes = mock.stateChangeCount
        mock.start() // 已启动：no-op
        XCTAssertEqual(mock.generation, gen)
        XCTAssertEqual(mock.state, state)
        XCTAssertEqual(mock.stateChangeCount, changes, "重复 start 无状态通知")
    }

    func testP14StopStopIdempotent() {
        let mock = makeMock()
        mock.start()
        mock.stop()
        let gen = mock.generation
        let changes = mock.stateChangeCount
        mock.stop() // 未启动：no-op
        XCTAssertEqual(mock.generation, gen)
        XCTAssertEqual(mock.state, .off)
        XCTAssertEqual(mock.stateChangeCount, changes, "重复 stop 无状态通知")
    }

    func testP14StartStopStartSequence() {
        let mock = makeMock()
        mock.start()
        mock.stop()
        mock.start()
        XCTAssertTrue(mock.isStarted)
        XCTAssertEqual(mock.state, .ready)
        // 新订阅可正常交付
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        XCTAssertEqual(mock.deliveredFrameCount, 1)
    }

    func testP14RestartGeneratesNewGenerationAndDelivers() {
        let mock = makeMock()
        mock.start()
        let gen = mock.generation
        mock.restart()
        XCTAssertEqual(mock.generation, gen + 1)
        XCTAssertTrue(mock.isStarted)
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        XCTAssertEqual(mock.deliveredFrameCount, 1)
    }

    // MARK: P15 同步重入假后端无死锁（回调内 stop/restart）

    func testP15StopInsideFrameCallbackNoDeadlock() {
        let mock = makeMock()
        mock.start()
        var stopCalled = false
        mock.onFrame = { _ in
            if !stopCalled {
                stopCalled = true
                mock.stop() // 回调内 stop：不得死锁
            }
        }
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        XCTAssertTrue(stopCalled)
        XCTAssertFalse(mock.isStarted)
        XCTAssertEqual(mock.deliveredFrameCount, 1, "stop 后后续帧被丢弃")
    }

    func testP15RestartInsideFrameCallbackNoDeadlock() {
        let mock = makeMock()
        mock.start()
        let genBefore = mock.generation
        var restartCalled = false
        mock.onFrame = { _ in
            if !restartCalled {
                restartCalled = true
                mock.restart() // 回调内 restart：不得死锁
            }
        }
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        XCTAssertTrue(restartCalled)
        XCTAssertEqual(mock.generation, genBefore + 1)
        XCTAssertTrue(mock.isStarted)
        // restart 后新帧正常交付
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        XCTAssertEqual(mock.deliveredFrameCount, 2)
    }

    func testP15StopInsideStateChangeCallbackNoDeadlock() {
        let mock = makeMock()
        var stopCalled = false
        mock.onStateChange = { _ in
            if !stopCalled {
                stopCalled = true
                mock.stop() // 状态回调内 stop：不得死锁
            }
        }
        mock.start()
        XCTAssertTrue(stopCalled)
        XCTAssertFalse(mock.isStarted)
        XCTAssertEqual(mock.state, .off, "重入后最终状态正确")
    }

    // MARK: §20.2 回调锁外派发、缓冲有界、保留 begin/end/cancel

    func testSection20_2CallbacksDispatchedOutsideLock() {
        // 回调内同步重入（push/stop/restart）不死锁 = 锁外派发的确定性证明
        let mock = makeMock()
        mock.start()
        var reentered = false
        mock.onFrame = { _ in
            if !reentered {
                reentered = true
                mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.2), deviceID: self.device) // 回调内 push
            }
        }
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        XCTAssertTrue(reentered)
        XCTAssertEqual(mock.deliveredFrameCount, 2, "回调内 push 正常交付")
    }

    func testSection20_2BoundedBufferDropsMovedKeepsBeginEndCancel() {
        let mock = MockTouchProvider(clock: FakePinchClock(), deliveryMode: .asynchronous, maxQueueSize: 2)
        mock.start()
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.16), deviceID: device)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.1), deviceID: device)
        mock.push(phase: .ended, contacts: [], deviceID: device)
        XCTAssertEqual(mock.pendingFrameCount, 2, "缓冲有界")
        XCTAssertEqual(mock.droppedMovedFrameCount, 3, "过载只丢 moved")
        XCTAssertEqual(mock.rejectedFrameCount, 0, "关键帧不丢")

        var delivered: [PinchFramePhase] = []
        mock.onFrame = { delivered.append($0.phase) }
        mock.drain()
        XCTAssertEqual(delivered, [.began, .ended], "保留 begin/end（重新武装条件）")
    }

    func testSection20_2AsyncDrainDeliversInOrder() {
        let mock = makeMock(deliveryMode: .asynchronous)
        mock.start()
        var delivered: [PinchFramePhase] = []
        mock.onFrame = { delivered.append($0.phase) }
        mock.push(phase: .began, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        mock.push(phase: .moved, contacts: squareContacts(halfSize: 0.2), deviceID: device)
        mock.push(phase: .ended, contacts: [], deviceID: device)
        XCTAssertEqual(mock.pendingFrameCount, 3)
        mock.drain()
        XCTAssertEqual(delivered, [.began, .moved, .ended], "按序交付")
        XCTAssertEqual(mock.pendingFrameCount, 0)
    }
}
