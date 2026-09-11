//
//  MockTouchProvider.swift
//  PagingPrototypeApp
//
//  Phase 1G Mock 平台 provider（T-G-P2）。
//  合成匿名触点帧注入：预置帧序列按时间推进回放（playback），或命令式 push 帧。
//  支持模拟 start/stop/restart、异步迟到回调（asynchronous 模式 + drain）、
//  同步重入（回调内 stop/restart 不死锁）。
//  锁序（§20.2）：窄锁（NSLock）只保护状态与缓冲；user closure 在锁外调用；
//  缓冲有界且保留 began/ended/cancelled（过载只丢 moved）。
//  中性计数：交付/拒绝/契约违反/过载丢弃帧数（允许记录；不记录坐标/序列号/时间戳原始值）。
//

import Foundation

// MARK: - 预置序列步骤

/// 预置序列回放步骤（时间推进由共享时钟的 PinchClockAdvancing 能力驱动）。
public struct MockFrameStep: Equatable, Sendable {
    public var phase: PinchFramePhase
    public var contacts: [PinchContact]
    /// 本帧交付后推进共享时钟的增量（单调时间域）。
    public var timeStep: TimeInterval

    public init(phase: PinchFramePhase, contacts: [PinchContact], timeStep: TimeInterval = 0.01) {
        self.phase = phase
        self.contacts = contacts
        self.timeStep = timeStep
    }
}

// MARK: - Mock provider

public final class MockTouchProvider: TouchProvider {
    /// 交付模式：synchronous = push 即交付（模拟同步后端）；
    /// asynchronous = push 入有界队列，drain() 交付（模拟异步回调线程迟到交付）。
    public enum DeliveryMode: Sendable {
        case synchronous
        case asynchronous
    }

    private let lock = NSLock()
    private let clock: PinchClock
    private let deliveryMode: DeliveryMode
    private let maxQueueSize: Int
    private let maxContactCount: Int

    public private(set) var state: TouchProviderState = .off
    public var onStateChange: ((TouchProviderState) -> Void)?
    public var onFrame: ((PinchFrame) -> Void)?
    public private(set) var generation: Int = 0
    public private(set) var isStarted: Bool = false

    /// 启动完成后的状态（模拟枚举结果；默认 .ready）。
    public var startupState: TouchProviderState = .ready

    private var queue: [PinchFrame] = []
    private var openSessions: Set<PinchDeviceID> = []

    // 中性计数（允许记录；不记录坐标/序列号/时间戳原始值）
    public private(set) var deliveredFrameCount: Int = 0
    public private(set) var rejectedFrameCount: Int = 0
    public private(set) var contractViolationCount: Int = 0
    public private(set) var droppedMovedFrameCount: Int = 0
    public private(set) var stateChangeCount: Int = 0

    public init(clock: PinchClock,
                deliveryMode: DeliveryMode = .synchronous,
                maxQueueSize: Int = 64,
                maxContactCount: Int = 16) {
        self.clock = clock
        self.deliveryMode = deliveryMode
        self.maxQueueSize = max(1, maxQueueSize)
        self.maxContactCount = max(1, maxContactCount)
    }

    /// 排队待交付帧数（asynchronous 模式）。
    public var pendingFrameCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return queue.count
    }

    // MARK: - TouchProvider 生命周期

    public func start() {
        var notifications: [TouchProviderState] = []
        lock.lock()
        guard !isStarted else {
            lock.unlock()
            return // 幂等：已启动 = no-op
        }
        isStarted = true
        state = .checking
        notifications.append(.checking)
        stateChangeCount += 1
        if startupState != .checking {
            state = startupState
            notifications.append(startupState)
            stateChangeCount += 1
        }
        lock.unlock()
        for s in notifications { onStateChange?(s) } // 锁外派发
    }

    public func stop() {
        var notification: TouchProviderState?
        lock.lock()
        guard isStarted else {
            lock.unlock()
            return // 幂等：未启动 = no-op
        }
        isStarted = false
        generation += 1
        queue.removeAll()
        openSessions.removeAll()
        state = .off
        notification = .off
        stateChangeCount += 1
        lock.unlock()
        if let n = notification { onStateChange?(n) } // 锁外派发
    }

    public func restart() {
        var notifications: [TouchProviderState] = []
        lock.lock()
        isStarted = true
        generation += 1
        queue.removeAll()
        openSessions.removeAll()
        state = .checking
        notifications.append(.checking)
        stateChangeCount += 1
        if startupState != .checking {
            state = startupState
            notifications.append(startupState)
            stateChangeCount += 1
        }
        lock.unlock()
        for s in notifications { onStateChange?(s) } // 锁外派发
    }

    /// 模拟状态变化（测试驱动 NoDevice/Unavailable/PermissionNotConfirmed/Suspended 等）。
    public func simulateStateChange(_ newState: TouchProviderState) {
        lock.lock()
        state = newState
        stateChangeCount += 1
        lock.unlock()
        onStateChange?(newState) // 锁外派发
    }

    // MARK: - 帧注入

    /// 命令式 push：完整帧（timestamp 由调用方给定，须与注入时钟同一单调时间域）。
    public func push(_ frame: PinchFrame) {
        var toDeliver: PinchFrame?
        lock.lock()
        guard isStarted else {
            rejectedFrameCount += 1
            lock.unlock()
            return
        }
        guard validate(frame) else {
            rejectedFrameCount += 1
            lock.unlock()
            return
        }
        guard checkContract(frame) else {
            contractViolationCount += 1
            lock.unlock()
            return
        }
        switch deliveryMode {
        case .synchronous:
            toDeliver = frame
        case .asynchronous:
            if queue.count >= maxQueueSize {
                // 过载：优先丢 moved（可压缩），保留 began/ended/cancelled（重新武装条件）
                if let idx = queue.firstIndex(where: { $0.phase == .moved }) {
                    queue.remove(at: idx)
                    droppedMovedFrameCount += 1
                } else {
                    rejectedFrameCount += 1
                    lock.unlock()
                    return
                }
            }
            queue.append(frame)
        }
        lock.unlock()
        if let f = toDeliver { deliver(f) }
    }

    /// 命令式 push：自动打时间戳（clock.now()；调用方推进共享时钟模拟时间流逝）。
    public func push(phase: PinchFramePhase, contacts: [PinchContact], deviceID: PinchDeviceID) {
        push(PinchFrame(deviceID: deviceID, timestamp: clock.now(), phase: phase, contacts: contacts))
    }

    /// 预置帧序列按时间推进回放：每帧以 clock.now() 打戳交付，随后推进共享时钟 timeStep。
    /// 时间推进需要时钟支持 PinchClockAdvancing（测试用 FakePinchClock）；只读时钟下所有帧同戳（仅测试用途）。
    public func playback(_ steps: [MockFrameStep], deviceID: PinchDeviceID) {
        for step in steps {
            push(PinchFrame(deviceID: deviceID, timestamp: clock.now(), phase: step.phase, contacts: step.contacts))
            if let advancing = clock as? PinchClockAdvancing {
                advancing.advance(by: step.timeStep)
            }
        }
    }

    /// 异步模式：交付排队帧（模拟异步回调线程迟到交付；stop/restart 后队列已清 → 零交付）。
    public func drain() {
        var frames: [PinchFrame] = []
        lock.lock()
        frames = queue
        queue.removeAll()
        lock.unlock()
        for f in frames { deliver(f) }
    }

    // MARK: - 内部

    private func validate(_ frame: PinchFrame) -> Bool {
        guard frame.timestamp >= 0 else { return false }
        guard frame.contacts.count <= maxContactCount else { return false }
        if frame.phase == .began && frame.contacts.isEmpty { return false } // 畸形 began
        var seen = Set<PinchContactID>()
        for c in frame.contacts {
            guard c.position.x.isFinite, c.position.y.isFinite else { return false }
            guard seen.insert(c.id).inserted else { return false }
        }
        return true
    }

    /// 帧契约：began → moved* → ended/cancelled；零触点 moved = 结束证据（会话关闭）。
    private func checkContract(_ frame: PinchFrame) -> Bool {
        switch frame.phase {
        case .began:
            guard !openSessions.contains(frame.deviceID) else { return false }
            openSessions.insert(frame.deviceID)
        case .moved:
            guard openSessions.contains(frame.deviceID) else { return false }
            if frame.contacts.isEmpty {
                openSessions.remove(frame.deviceID) // 结束证据
            }
        case .ended, .cancelled:
            guard openSessions.contains(frame.deviceID) else { return false }
            openSessions.remove(frame.deviceID)
        }
        return true
    }

    private func deliver(_ frame: PinchFrame) {
        lock.lock()
        deliveredFrameCount += 1
        lock.unlock()
        onFrame?(frame) // 锁外派发（§20.2：user closure 在锁外调用）
    }
}
