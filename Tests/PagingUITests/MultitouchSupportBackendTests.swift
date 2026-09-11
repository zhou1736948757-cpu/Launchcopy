//
//  MultitouchSupportBackendTests.swift
//  PagingUITests
//
//  Phase 1G T-G-P6：真实后端状态机上报路径（可注入 fake dlopen 结果）、
//  生命周期幂等、teardown 顺序（先 Unregister 再 Stop 再 dlclose）、
//  全链路（fake 帧源 → 真实 C 回调 → 合成 → 有界缓冲 → onFrame）、
//  设备隔离、回调内重入无死锁（§20.2 锁外派发）。
//  真实设备无法在 CI 测 → 全部经注入缝（libraryFactory + FakeMultitouchDevice）。
//

import XCTest
@testable import PagingPrototypeApp

// MARK: - 假设备（fake 帧源：走真实 C 回调路径）

final class FakeMultitouchDevice: MultitouchDevice {
    var registryKey: MTDeviceRef { Unmanaged.passUnretained(self).toOpaque() }
    var registeredCallback: MTContactFrameCallback?
    var registerResult = true
    var startResult = true
    private(set) var callLog: [String] = []

    func registerContactFrameCallback(_ callback: MTContactFrameCallback) -> Bool {
        registeredCallback = callback
        callLog.append("register")
        return registerResult
    }

    func unregisterContactFrameCallback(_ callback: MTContactFrameCallback) {
        registeredCallback = nil
        callLog.append("unregister")
    }

    func start() -> Bool {
        callLog.append("start")
        return startResult
    }

    func stop() {
        callLog.append("stop")
    }

    func clearLog() {
        callLog.removeAll()
    }

    /// 注入一帧（fake 帧源）：经真实 C 回调路径进入后端。
    func simulateFrame(touches: [MTTouch], timestamp: Double) {
        guard let cb = registeredCallback else { return }
        touches.withUnsafeBufferPointer { buf in
            _ = cb(registryKey, UnsafeMutableRawPointer(mutating: buf.baseAddress!),
                   Int32(buf.count), timestamp, 0)
        }
    }
}

// MARK: - 假库（fake dlopen 结果）

final class FakeMultitouchLibrary: MultitouchLibrary {
    var devices: [MultitouchDevice]
    private(set) var closeCount = 0

    init(devices: [MultitouchDevice]) {
        self.devices = devices
    }

    func enumerateDevices() -> [MultitouchDevice] { devices }
    func close() { closeCount += 1 }
}

/// 闭包延迟写入的持有者（makeBackend 返回时闭包尚未运行，须经持有者读取）。
final class FakeLibraryHolder {
    var library: FakeMultitouchLibrary?
}

// MARK: - 测试

final class MultitouchSupportBackendTests: XCTestCase {

    private func makeBackend(devices: [MultitouchDevice]? = nil,
                             maxQueueSize: Int = 64,
                             mode: MultitouchSupportBackend.DeliveryMode = .synchronous)
        -> (MultitouchSupportBackend, FakeLibraryHolder) {
        let holder = FakeLibraryHolder()
        let backend = MultitouchSupportBackend(maxQueueSize: maxQueueSize, deliveryMode: mode, libraryFactory: {
            if let devices = devices {
                let lib = FakeMultitouchLibrary(devices: devices)
                holder.library = lib
                return lib
            }
            return nil // dlopen 失败
        })
        return (backend, holder)
    }

    private func mtTouch(_ id: Int32, _ state: Int32, _ x: Float = 0.5, _ y: Float = 0.5) -> MTTouch {
        MTTouch(frame: 0, timestamp: 0, identifier: id, state: state, fingerID: 0, handID: 0,
                normalized: MTReadout(position: MTPoint(x: x, y: y), velocity: MTPoint(x: 0, y: 0)),
                size: 0, zero1: 0, angle: 0, majorAxis: 0, minorAxis: 0,
                absolute: MTReadout(position: MTPoint(x: 0, y: 0), velocity: MTPoint(x: 0, y: 0)),
                zero2: (0, 0), density: 0)
    }

    private func waitForDelivery(_ backend: MultitouchSupportBackend, expected: Int,
                                 timeout: TimeInterval = 2.0) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if backend.deliveredFrameCount >= expected { return }
            usleep(1000)
        }
    }

    // MARK: 状态机上报路径（可注入 fake dlopen 结果）

    func testDlopenFailureReportsUnavailable() {
        let (backend, _) = makeBackend(devices: nil)
        var states: [TouchProviderState] = []
        backend.onStateChange = { states.append($0) }
        backend.start()
        XCTAssertEqual(backend.state, .unavailable)
        XCTAssertEqual(backend.lastStartDetail, "dlopenFailed")
        XCTAssertEqual(states, [.checking, .unavailable])
    }

    func testEmptyDeviceListReportsNoDevice() {
        let (backend, holder) = makeBackend(devices: [])
        backend.start()
        XCTAssertEqual(backend.state, .noDevice)
        XCTAssertEqual(backend.lastStartDetail, "noDevices")
        XCTAssertEqual(holder.library?.closeCount, 1, "无设备时关闭库句柄")
    }

    func testDevicesReportReady() {
        let (backend, _) = makeBackend(devices: [FakeMultitouchDevice()])
        backend.start()
        XCTAssertEqual(backend.state, .ready)
        XCTAssertEqual(backend.lastStartDetail, "ok(devices=1)")
    }

    // MARK: 生命周期幂等（P14 语义）

    func testStartStartIdempotent() {
        let (backend, holder) = makeBackend(devices: [FakeMultitouchDevice()])
        backend.start()
        let gen = backend.generation
        let changes = backend.stateChangeCount
        backend.start()
        XCTAssertEqual(backend.generation, gen)
        XCTAssertEqual(backend.stateChangeCount, changes, "重复 start 无状态通知")
        XCTAssertEqual(holder.library?.closeCount, 0, "重复 start 不重建库")
    }

    func testStopStopIdempotent() {
        let (backend, _) = makeBackend(devices: [FakeMultitouchDevice()])
        backend.start()
        backend.stop()
        let gen = backend.generation
        backend.stop()
        XCTAssertEqual(backend.generation, gen)
        XCTAssertEqual(backend.state, .off)
    }

    func testStartStopStartSequence() {
        let (backend, _) = makeBackend(devices: [FakeMultitouchDevice()])
        backend.start()
        backend.stop()
        backend.start()
        XCTAssertTrue(backend.isStarted)
        XCTAssertEqual(backend.state, .ready)
    }

    func testRestartBumpsGeneration() {
        let (backend, _) = makeBackend(devices: [FakeMultitouchDevice()])
        backend.start()
        let gen = backend.generation
        backend.restart()
        XCTAssertEqual(backend.generation, gen + 1)
        XCTAssertTrue(backend.isStarted)
        XCTAssertEqual(backend.state, .ready)
    }

    // MARK: teardown 顺序（先 Unregister 再 Stop 再 dlclose）

    func testTeardownOrderUnregisterBeforeStop() {
        let fakeDevice = FakeMultitouchDevice()
        let (backend, holder) = makeBackend(devices: [fakeDevice])
        backend.start()
        fakeDevice.clearLog()
        backend.stop()
        XCTAssertEqual(fakeDevice.callLog, ["unregister", "stop"], "先 Unregister 再 Stop")
        XCTAssertEqual(holder.library?.closeCount, 1, "最后 dlclose")
        XCTAssertEqual(backend.lastTeardownDetail, "closed")
    }

    func testStopClearsQueueAndDropsLateFrames() {
        let fakeDevice = FakeMultitouchDevice()
        let (backend, _) = makeBackend(devices: [fakeDevice], mode: .asynchronous)
        backend.start()
        var delivered: [PinchFramePhase] = []
        backend.onFrame = { delivered.append($0.phase) }
        fakeDevice.simulateFrame(touches: [mtTouch(1, 5)], timestamp: 0)
        waitForDelivery(backend, expected: 1)
        XCTAssertEqual(delivered, [.began])

        backend.stop()
        // stop 后迟到帧（模拟已越过注册表查找的在途回调）：直接注入 → 拒绝
        backend.ingestRawTouches(deviceKey: fakeDevice.registryKey, timestamp: 0.1, frame: 0,
                                 touches: [RawTouch(identifier: 1, state: 6, x: 0.5, y: 0.5)])
        waitForDelivery(backend, expected: 1)
        XCTAssertEqual(delivered, [.began], "stop 后迟到帧丢弃")
        XCTAssertEqual(backend.rejectedFrameCount, 1)
    }

    // MARK: 全链路（fake 帧源 → C 回调 → 合成 → 缓冲 → onFrame）

    func testFullPipelineBeganMovedEnded() {
        let fakeDevice = FakeMultitouchDevice()
        let (backend, _) = makeBackend(devices: [fakeDevice])
        backend.start()
        var delivered: [PinchFramePhase] = []
        backend.onFrame = { delivered.append($0.phase) }
        // R-02 位掩码 state：5=接触事件（首帧 began）、6=移动、触点消失（空帧）= ended
        fakeDevice.simulateFrame(touches: [mtTouch(1, 5), mtTouch(2, 5), mtTouch(3, 5), mtTouch(4, 5)], timestamp: 100.0)
        fakeDevice.simulateFrame(touches: [mtTouch(1, 6), mtTouch(2, 6), mtTouch(3, 6), mtTouch(4, 6)], timestamp: 100.1)
        fakeDevice.simulateFrame(touches: [], timestamp: 100.2)
        XCTAssertEqual(delivered, [.began, .moved, .ended])
        XCTAssertEqual(backend.deliveredFrameCount, 3)
    }

    func testFullPipelineFourFingerRestNotCancelled() {
        // R-02 核心回归（全链路）：四指平放连续帧 [4,4,4,4]×6 → began 1 次 + moved 5 次，无 cancelled
        let fakeDevice = FakeMultitouchDevice()
        let (backend, _) = makeBackend(devices: [fakeDevice])
        backend.start()
        var delivered: [PinchFramePhase] = []
        backend.onFrame = { delivered.append($0.phase) }
        for i in 0..<6 {
            fakeDevice.simulateFrame(touches: [mtTouch(1, 4), mtTouch(2, 4), mtTouch(3, 4), mtTouch(4, 4)],
                                     timestamp: Double(i) * 0.01)
        }
        XCTAssertEqual(delivered, [.began, .moved, .moved, .moved, .moved, .moved],
                       "四指平放不再产出 cancelled")
        XCTAssertFalse(delivered.contains(.cancelled))
        XCTAssertEqual(backend.deliveredFrameCount, 6)
    }

    func testTwoDevicesIndependentSessions() {
        let d1 = FakeMultitouchDevice()
        let d2 = FakeMultitouchDevice()
        let (backend, _) = makeBackend(devices: [d1, d2])
        backend.start()
        var delivered: [PinchFramePhase] = []
        backend.onFrame = { delivered.append($0.phase) }
        d1.simulateFrame(touches: [mtTouch(1, 5)], timestamp: 0)
        d2.simulateFrame(touches: [], timestamp: 0) // d2 无会话 ended（空帧）→ 拒绝
        d2.simulateFrame(touches: [mtTouch(1, 5)], timestamp: 0.1) // d2 独立 began
        XCTAssertEqual(delivered, [.began, .began])
        XCTAssertEqual(backend.rejectedFrameCount, 1)
        // d1 会话不受 d2 影响
        d1.simulateFrame(touches: [mtTouch(1, 6)], timestamp: 0.2)
        XCTAssertEqual(delivered, [.began, .began, .moved])
    }

    func testAsyncBurstAllDelivered() {
        // 快速消费下无丢帧（丢帧策略由 BoundedFrameQueueTests 确定性覆盖）
        let fakeDevice = FakeMultitouchDevice()
        let (backend, _) = makeBackend(devices: [fakeDevice], mode: .asynchronous)
        backend.start()
        var delivered: [PinchFramePhase] = []
        backend.onFrame = { delivered.append($0.phase) }
        fakeDevice.simulateFrame(touches: [mtTouch(1, 5)], timestamp: 0)
        for i in 1..<20 {
            fakeDevice.simulateFrame(touches: [mtTouch(1, 6)], timestamp: Double(i) * 0.01)
        }
        fakeDevice.simulateFrame(touches: [], timestamp: 0.2) // 触点消失（空帧）= ended
        waitForDelivery(backend, expected: 21)
        XCTAssertEqual(delivered.count, 21, "快速消费下全量交付")
        XCTAssertEqual(delivered.first, .began)
        XCTAssertEqual(delivered.last, .ended)
    }

    // MARK: 回调内重入（§20.2 锁外派发）

    func testStopInsideFrameCallbackNoDeadlock() {
        let fakeDevice = FakeMultitouchDevice()
        let (backend, _) = makeBackend(devices: [fakeDevice])
        backend.start()
        var stopCalled = false
        backend.onFrame = { _ in
            if !stopCalled {
                stopCalled = true
                backend.stop() // 回调内 stop：不得死锁
            }
        }
        fakeDevice.simulateFrame(touches: [mtTouch(1, 5)], timestamp: 0)
        XCTAssertTrue(stopCalled)
        XCTAssertFalse(backend.isStarted)
        XCTAssertEqual(backend.state, .off)
    }

    func testRestartInsideFrameCallbackNoDeadlock() {
        let fakeDevice = FakeMultitouchDevice()
        let (backend, _) = makeBackend(devices: [fakeDevice])
        backend.start()
        let genBefore = backend.generation
        var restartCalled = false
        backend.onFrame = { _ in
            if !restartCalled {
                restartCalled = true
                backend.restart() // 回调内 restart：不得死锁
            }
        }
        fakeDevice.simulateFrame(touches: [mtTouch(1, 5)], timestamp: 0)
        XCTAssertTrue(restartCalled)
        XCTAssertEqual(backend.generation, genBefore + 1)
        XCTAssertTrue(backend.isStarted)
    }
}
