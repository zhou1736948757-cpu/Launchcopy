//
//  MultitouchSupportBackend.swift
//  PagingPrototypeApp
//
//  Phase 1G 真实 MultitouchSupport 后端 provider（T-G-P6）。
//  ADR-013 §20.1/§20.2 防护计划 + FOUR_FINGER_REFERENCE_AUDIT.md §2.2 审计结论。
//
//  编译排除 vs 运行时禁用（ADR-013 §8 区分表）：
//  本文件默认编译进 target；运行时仅在四指开关启用且用户确认后由上层 start()。
//  本文件不自动启动、不触碰窗口/UI、不申请权限、不弹权限窗（§18.2：未经同意不申请）。
//
//  私有 ABI 风险（R-01/R-02/R-07，用户已确认 2026-09-05）：
//  - MTTouch 布局与函数签名无 Apple 公开文档，按审计文档（参考实现 legacy 本机验证注释）
//    逐字段对齐；系统更新可能改变布局 → 崩溃或误读，跨版本不保证。
//  - 触点 state 为位掩码（R-02 已实机核实定案，64905 帧）：bit2(4)=在表面 / bit0(1)=接触事件 /
//    bit1(2)=移动事件；回调帧从不出现 0；离面 = 触点从帧消失（count 下降 / count=0 空帧）。
//    合成器按帧间 identifier 集合 diff 判定 began/ended，不再按 state 枚举值判定（旧假设已推翻）。
//  - 符号缺失在注册前失败（dlopen/dlsym 优雅不可用）；ABI 不可验证 → .unavailable，不重试。
//
//  锁序（§20.2）：
//  - 回调内只做最小拷贝（MTTouch → RawTouch 快照），合成/入队持窄锁，onFrame 锁外派发；
//  - 缓冲有界（maxQueueSize 默认 64，与 Mock 一致），过载只丢 moved，保留 began/ended
//    （关键帧；R-02 后合成器不产出 cancelled——触点消失即 ended，队列对任意非 moved 帧保留）；
//  - teardown 顺序：先 Unregister 再 Stop 再 dlclose，dlclose 只在无回调在途时（in-flight 计数）；
//  - 不在 deinit 承担主要注销（§20.3）；deinit 不 dlclose。
//
//  单调时间域（§19.3）：帧时间戳用 systemUptime 锚定换算（禁 Date()/墙钟差值）。
//  设备隔离（§20.1）：回调保留 device 参数；每设备独立会话/注册/注销；设备标识 = 进程内不透明 token。
//

import Darwin
import Foundation

// MARK: - 私有 ABI 类型（按审计文档 §2.2 布局）

/// 归一化/绝对坐标点（与参考实现布局一致）。
public struct MTPoint: Equatable, Sendable {
    public var x: Float
    public var y: Float
    public init(x: Float, y: Float) {
        self.x = x
        self.y = y
    }
}

/// 读数值（position + velocity；与参考实现布局一致）。
public struct MTReadout: Equatable, Sendable {
    public var position: MTPoint
    public var velocity: MTPoint
    public init(position: MTPoint, velocity: MTPoint) {
        self.position = position
        self.velocity = velocity
    }
}

/// MTTouch 结构布局（审计文档 §2.2：frame/timestamp/identifier/state/fingerID/handID/
/// normalized/size/zero1/angle/majorAxis/minorAxis/absolute/zero2/density）。
/// 来源：参考实现注释「与 legacy 验证可用布局完全对齐」（非 Apple 公开文档；R-01）。
/// 仅回调有效期内读取；传出纯值副本。
public struct MTTouch: Sendable {
    public var frame: Int32
    public var timestamp: Double
    public var identifier: Int32
    public var state: Int32
    public var fingerID: Int32
    public var handID: Int32
    public var normalized: MTReadout
    public var size: Float
    public var zero1: Int32
    public var angle: Float
    public var majorAxis: Float
    public var minorAxis: Float
    public var absolute: MTReadout
    public var zero2: (Int32, Int32)
    public var density: Float

    public init(frame: Int32, timestamp: Double, identifier: Int32, state: Int32,
                fingerID: Int32, handID: Int32, normalized: MTReadout, size: Float,
                zero1: Int32, angle: Float, majorAxis: Float, minorAxis: Float,
                absolute: MTReadout, zero2: (Int32, Int32), density: Float) {
        self.frame = frame
        self.timestamp = timestamp
        self.identifier = identifier
        self.state = state
        self.fingerID = fingerID
        self.handID = handID
        self.normalized = normalized
        self.size = size
        self.zero1 = zero1
        self.angle = angle
        self.majorAxis = majorAxis
        self.minorAxis = minorAxis
        self.absolute = absolute
        self.zero2 = zero2
        self.density = density
    }
}

// MARK: - 私有函数类型（C 调用约定，按审计文档签名）

public typealias MTDeviceRef = UnsafeMutableRawPointer

/// 接触帧回调签名：(device, touches 指针, 数量, 时间戳, 帧号) -> Int32（审计 §2.2）。
public typealias MTContactFrameCallback =
    @convention(c) (MTDeviceRef, UnsafeMutableRawPointer, Int32, Double, Int32) -> Int32

private typealias MTDeviceCreateListFn = @convention(c) () -> Unmanaged<CFArray>?
private typealias MTRegisterContactFrameCallbackFn = @convention(c) (MTDeviceRef, MTContactFrameCallback) -> Void
private typealias MTUnregisterContactFrameCallbackFn = @convention(c) (MTDeviceRef, MTContactFrameCallback) -> Void
private typealias MTDeviceStartFn = @convention(c) (MTDeviceRef, Int32) -> Void
private typealias MTDeviceStopFn = @convention(c) (MTDeviceRef, Int32) -> Void

// MARK: - 全局回调盒（对齐 LaunchBetter MultitouchSupport：C 回调无 context，按活跃 backend 路由）

private let registryLock = NSLock()
/// 当前活跃后端（start 时设置，stop 时按 owner 清空）。不按 device 指针查表——
/// 回调里的 device 指针可能与枚举时不一致，按指针查表会导致 delivered=0、捏合无反应。
private weak var activeBackend: MultitouchSupportBackend?
private var activeBackendOwner: UInt64 = 0
/// 在途回调计数：dlclose 只在计数归零后执行（R-05）。
private var inFlightCallbacks = 0

/// 非捕获 C 回调（文件级；@convention(c) 闭包不可捕获上下文）。
/// 对齐 LaunchBetter：锁内取活跃 backend 快照，锁外 ingest；device 仅作合成器设备键，可回退。
private let contactFrameCallback: MTContactFrameCallback = { device, touchesPtr, count, timestamp, frame in
    let receivedAt = ProcessInfo.processInfo.systemUptime
    registryLock.lock()
    inFlightCallbacks += 1
    let backend = activeBackend
    registryLock.unlock()

    guard let backend else {
        registryLock.lock()
        inFlightCallbacks -= 1
        registryLock.unlock()
        return 0
    }
    backend.ingestRawFrame(deviceKey: device, touchesPtr: touchesPtr, count: count,
                           timestamp: timestamp, frame: frame, receivedAt: receivedAt)
    registryLock.lock()
    inFlightCallbacks -= 1
    registryLock.unlock()
    return 0
}

// MARK: - 设备抽象（真实实现 + 测试注入缝）

/// 单台触控设备（真实 = MTDeviceRef 包装；测试 = fake）。
public protocol MultitouchDevice: AnyObject {
    /// 进程内不透明标识（真实 = 设备指针；测试 = 对象指针）。
    var registryKey: MTDeviceRef { get }
    func registerContactFrameCallback(_ callback: MTContactFrameCallback) -> Bool
    func unregisterContactFrameCallback(_ callback: MTContactFrameCallback)
    func start() -> Bool
    func stop()
}

/// 私有框架库抽象（真实 = dlopen/dlsym 包装；测试 = fake dlopen 结果）。
public protocol MultitouchLibrary: AnyObject {
    func enumerateDevices() -> [MultitouchDevice]
    func close()
}

/// 真实库：dlopen /System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport
/// （RTLD_LAZY；失败 → nil，优雅不可用，不崩溃）。
final class RealMultitouchLibrary: MultitouchLibrary {
    private let handle: UnsafeMutableRawPointer
    private let createList: MTDeviceCreateListFn
    private let registerFn: MTRegisterContactFrameCallbackFn
    private let unregisterFn: MTUnregisterContactFrameCallbackFn
    private let startFn: MTDeviceStartFn
    private let stopFn: MTDeviceStopFn
    /// 持有设备列表生命周期（设备指针在数组存活期间有效）。
    private var deviceList: CFArray?

    init?() {
        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
            RTLD_LAZY
        ) else {
            return nil
        }
        guard
            let createList = dlsym(handle, "MTDeviceCreateList").map({
                unsafeBitCast($0, to: MTDeviceCreateListFn.self)
            }),
            let registerFn = dlsym(handle, "MTRegisterContactFrameCallback").map({
                unsafeBitCast($0, to: MTRegisterContactFrameCallbackFn.self)
            }),
            let unregisterFn = dlsym(handle, "MTUnregisterContactFrameCallback").map({
                unsafeBitCast($0, to: MTUnregisterContactFrameCallbackFn.self)
            }),
            let startFn = dlsym(handle, "MTDeviceStart").map({
                unsafeBitCast($0, to: MTDeviceStartFn.self)
            }),
            let stopFn = dlsym(handle, "MTDeviceStop").map({
                unsafeBitCast($0, to: MTDeviceStopFn.self)
            })
        else {
            dlclose(handle)
            return nil
        }
        self.handle = handle
        self.createList = createList
        self.registerFn = registerFn
        self.unregisterFn = unregisterFn
        self.startFn = startFn
        self.stopFn = stopFn
    }

    func enumerateDevices() -> [MultitouchDevice] {
        guard let listRef = createList() else { return [] }
        let list = listRef.takeUnretainedValue()
        deviceList = list
        let count = CFArrayGetCount(list)
        var devices: [MultitouchDevice] = []
        for index in 0..<count {
            guard let value = CFArrayGetValueAtIndex(list, index) else { continue }
            let device = UnsafeMutableRawPointer(mutating: value)
            devices.append(RealMultitouchDevice(device: device, registerFn: registerFn,
                                                unregisterFn: unregisterFn, startFn: startFn, stopFn: stopFn))
        }
        return devices
    }

    func close() {
        deviceList = nil
        dlclose(handle)
    }
}

/// 真实设备：MTDeviceRef 窄包装。
final class RealMultitouchDevice: MultitouchDevice {
    private let device: MTDeviceRef
    private let registerFn: MTRegisterContactFrameCallbackFn
    private let unregisterFn: MTUnregisterContactFrameCallbackFn
    private let startFn: MTDeviceStartFn
    private let stopFn: MTDeviceStopFn

    fileprivate init(device: MTDeviceRef,
         registerFn: @escaping MTRegisterContactFrameCallbackFn,
         unregisterFn: @escaping MTUnregisterContactFrameCallbackFn,
         startFn: @escaping MTDeviceStartFn,
         stopFn: @escaping MTDeviceStopFn) {
        self.device = device
        self.registerFn = registerFn
        self.unregisterFn = unregisterFn
        self.startFn = startFn
        self.stopFn = stopFn
    }

    var registryKey: MTDeviceRef { device }

    func registerContactFrameCallback(_ callback: MTContactFrameCallback) -> Bool {
        registerFn(device, callback)
        return true
    }

    func unregisterContactFrameCallback(_ callback: MTContactFrameCallback) {
        unregisterFn(device, callback)
    }

    func start() -> Bool {
        startFn(device, 0)
        return true
    }

    func stop() {
        stopFn(device, 0)
    }
}

// MARK: - 原始触点快照（回调内最小拷贝）

/// 回调内快照的原始触点（只取 identifier/state/normalized 坐标；不拷贝整块 MTTouch）。
public struct RawTouch: Equatable, Sendable {
    public var identifier: Int32
    public var state: Int32
    public var x: Float
    public var y: Float

    public init(identifier: Int32, state: Int32, x: Float, y: Float) {
        self.identifier = identifier
        self.state = state
        self.x = x
        self.y = y
    }
}

// MARK: - 帧合成器（原始触点 → PinchFrame；纯逻辑，可测）

/// 触点 state 位掩码常量（R-02 实机核实 64905 帧定案：state 是位掩码，非枚举）。
/// - bit2 (4) = 在表面静止（主导，81644 次；4/5/6/7）
/// - bit0 (1) = 接触/过渡事件（1/3/5/7 ≈ 各 1600-1700 次，过渡帧）
/// - bit1 (2) = 移动事件（2/6 = 290/571 次，移动帧）
/// state ∈ [1,7]：含 bit2 的 4/5/6/7 = 在表面；1/2/3 = 不在表面但有事件位（过渡帧）。
/// state=0 不会出现在回调帧（直方图无 state=0）；离面 = 触点从后续帧消失 + 可能 count=0 空帧。
/// 活跃判定：state != 0（任何非零都算接触中）。
/// 旧 began=1/moved=2/ended=3/cancelled=4 常量已删除（旧枚举假设被 rawdiag 原始诊断推翻；
/// 相位判定改由 MultitouchFrameSynthesizer 帧间 identifier diff 产出，见 synthesize）。
public enum MTTouchState {
    /// 未触摸（保留为语义常量；实际回调帧不出现 0）。
    public static let notTouching: Int32 = 0
    /// 在表面（bit2；4/5/6/7）。
    public static let onSurfaceBit: Int32 = 4
    /// 接触/过渡事件（bit0；1/3/5/7；仅过渡帧出现，不表示 began）。
    public static let contactEventBit: Int32 = 1
    /// 移动事件（bit1；2/6）。
    public static let moveEventBit: Int32 = 2
}

/// 帧合成器：按设备维护会话状态，把原始触点帧合成为契约帧
/// （began → moved* → ended；零触点/全部离面 = 结束证据）。
/// 相位判定基于**帧间触点 identifier 集合 diff**（R-02 定案：state 为位掩码，
/// 不再按枚举值判 began/ended/cancelled；触点消失即 ended，无 cancelled 概念）。
/// Map callback deltas to system uptime, bounded by callback receipt time.
/// Consumer delivery never refreshes timestamps, so queued input still expires.
public struct MultitouchFrameSynthesizer: Sendable {
    public struct DeviceState: Sendable {
        public var sessionOpen = false
        public var contactIDs: [Int32: PinchContactID] = [:]
        public var nextContactID = 1
        public var anchorUptime: TimeInterval?
        public var anchorCallbackTime: Double?
        /// Preserve raw ordering faults even when receipt-time bounding hides a delta.
        public var lastCallbackTimestamp: Double?
        /// 上一帧的原始 identifier 集合（帧间 diff 判定 began/ended 用）。
        public var lastContactIdentifiers: Set<Int32> = []

        public init() {}
    }

    public var devices: [PinchDeviceID: DeviceState] = [:]

    public init() {}

    /// 合成一帧。返回空数组 = 拒绝（零触点且无会话；无会话的 ended 帧拒绝）。
    /// began/ended 判定（帧间 diff，per-device）：
    /// - 会话未开 && active 非空 → .began（记录 identifier 集合，会话开）；
    /// - 会话开 && active 空 / touches 空 → .ended（结束证据；会话关，清集合）；
    /// - 会话开 && active 非空 → 见 synthesize 内 diff 规则（全部新出现=重锚 .began、
    ///   部分消失=.moved 注销消失触点、无边界=.moved）。
    /// cancelled 概念删除：ABI 无 cancelled 证据，触点消失即 ended。
    public mutating func synthesize(deviceID: PinchDeviceID, callbackTimestamp: Double,
                                    touches: [RawTouch], uptimeNow: TimeInterval) -> [PinchFrame] {
        var state = devices[deviceID] ?? DeviceState()
        defer { devices[deviceID] = state }

        let timestamp = Self.normalizedTimestamp(callbackTimestamp, receivedAt: uptimeNow, state: &state)

        // 活跃触点 = state != 0（R-02 位掩码：任何非零都算接触中）
        let active = touches.filter { $0.state != MTTouchState.notTouching }
        let activeIdentifiers = Set(active.map(\.identifier))

        // 结束证据：零触点 / 全部离面 = 会话关闭（重新武装条件；触点从帧消失 = ended）
        if touches.isEmpty || active.isEmpty {
            guard state.sessionOpen else { return [] }
            // An invalid terminal is not release evidence. Keep the source
            // session open so the next valid empty frame can reach the consumer
            // and clear its quarantine, rather than swallowing another gesture.
            if timestamp.isFinite {
                state.sessionOpen = false
                state.contactIDs.removeAll()
                state.lastContactIdentifiers.removeAll()
            }
            return [PinchFrame(deviceID: deviceID, timestamp: timestamp, phase: .ended, contacts: [])]
        }

        // 会话未开 && active 非空 → .began（记录 identifier 集合，会话开）
        guard state.sessionOpen else {
            state.sessionOpen = true
            state.lastContactIdentifiers = activeIdentifiers
            return [PinchFrame(deviceID: deviceID, timestamp: timestamp, phase: .began,
                               contacts: Self.mapContacts(active, state: &state))]
        }

        // 会话开 && active 非空：帧间 identifier 集合 diff（R-02 定案）
        let previous = state.lastContactIdentifiers
        let newIdentifiers = activeIdentifiers.subtracting(previous)
        let vanishedIdentifiers = previous.subtracting(activeIdentifiers)

        // 1) 全部触点均为新出现（首帧类场景/重锚定；含「上一会话触点全部消失但本帧有活动触点」——
        //    全部消失 + active 非空 ⟺ 全部新出现，同一帧的两种表述，重锚定优先于关会话）：
        //    → .began 重开会话，身份映射随会话重置（新会话全新 ID；识别器对会话中 began 保守处理）。
        if !newIdentifiers.isEmpty && newIdentifiers.count == activeIdentifiers.count {
            state.contactIDs.removeAll()
            state.lastContactIdentifiers = activeIdentifiers
            return [PinchFrame(deviceID: deviceID, timestamp: timestamp, phase: .began,
                               contacts: Self.mapContacts(active, state: &state))]
        }

        // 2) 部分触点消失（上帧有、本帧无）：该触点即 ended；剩余触点继续 → .moved
        //    （仅当会话中触点全部消失才关会话——真实形态为空帧/离面帧，已由上方结束证据分支产出 .ended；
        //    此处注销消失触点的身份映射，重现身 = 新触点）。
        if !vanishedIdentifiers.isEmpty {
            for identifier in vanishedIdentifiers {
                state.contactIDs.removeValue(forKey: identifier)
            }
            state.lastContactIdentifiers = activeIdentifiers
            return [PinchFrame(deviceID: deviceID, timestamp: timestamp, phase: .moved,
                               contacts: Self.mapContacts(active, state: &state))]
        }

        // 3) 其余（会话中、无 began 边界、无消失）→ .moved
        state.lastContactIdentifiers = activeIdentifiers
        return [PinchFrame(deviceID: deviceID, timestamp: timestamp, phase: .moved,
                           contacts: Self.mapContacts(active, state: &state))]
    }

    /// The first callback's receipt latency can bias anchor-plus-delta into the
    /// future. Cap at *ingress*, not main-queue delivery; leave older mapped
    /// times unchanged. Do not reanchor: that could renew stale source samples.
    /// With ordered source and receipt clocks, the minimum remains ordered.
    /// Invalid raw order must remain invalid even if the cap would conceal it.
    private static func normalizedTimestamp(_ sourceTime: Double, receivedAt uptime: TimeInterval,
                                            state: inout DeviceState) -> TimeInterval {
        guard sourceTime.isFinite, uptime.isFinite, uptime >= 0,
              state.lastCallbackTimestamp.map({ sourceTime >= $0 }) ?? true else {
            return .nan // Existing consumer validation quarantines until valid release.
        }
        let mapped: TimeInterval
        if let anchorUptime = state.anchorUptime, let anchorCallbackTime = state.anchorCallbackTime {
            mapped = anchorUptime + (sourceTime - anchorCallbackTime)
        } else {
            mapped = uptime
        }
        guard mapped.isFinite, mapped >= 0 else { return .nan }
        if state.anchorUptime == nil {
            state.anchorUptime = uptime
            state.anchorCallbackTime = sourceTime
        }
        state.lastCallbackTimestamp = sourceTime
        return min(mapped, uptime)
    }

    /// 触点身份映射（每设备；会话内稳定，会话间全新；不透明 token）——原 L344-357 逻辑保持不变。
    private static func mapContacts(_ active: [RawTouch], state: inout DeviceState) -> [PinchContact] {
        var contacts: [PinchContact] = []
        contacts.reserveCapacity(active.count)
        for t in active {
            let id: PinchContactID
            if let existing = state.contactIDs[t.identifier] {
                id = existing
            } else {
                id = PinchContactID(rawValue: state.nextContactID)
                state.nextContactID += 1
                state.contactIDs[t.identifier] = id
            }
            contacts.append(PinchContact(id: id, position: PinchPoint(x: Double(t.x), y: Double(t.y))))
        }
        return contacts
    }
}

// MARK: - 有界帧缓冲（过载只丢 moved，保留 began/ended/cancelled）

/// 有界帧队列：满时优先丢 moved（可压缩），保留 began/ended/cancelled（重新武装条件）；
/// 无 moved 可丢时拒绝新帧。与 MockTouchProvider 的 maxQueueSize=64 语义一致。
/// （R-02 后本后端合成器不产出 .cancelled——触点消失即 ended；队列对任意非 moved 帧保留。）
public final class BoundedFrameQueue: @unchecked Sendable {
    public enum EnqueueResult: Equatable, Sendable {
        case accepted
        case droppedMoved
        case rejected
    }

    private let lock = NSLock()
    private let maxSize: Int
    private var frames: [PinchFrame] = []
    public private(set) var droppedMovedCount = 0
    public private(set) var rejectedCount = 0

    public init(maxSize: Int) {
        self.maxSize = max(1, maxSize)
    }

    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return frames.count
    }

    @discardableResult
    public func enqueue(_ frame: PinchFrame) -> EnqueueResult {
        lock.lock()
        defer { lock.unlock() }
        guard frames.count < maxSize else {
            if let idx = frames.firstIndex(where: { $0.phase == .moved }) {
                frames.remove(at: idx)
                droppedMovedCount += 1
                frames.append(frame)
                return .droppedMoved
            }
            rejectedCount += 1
            return .rejected
        }
        frames.append(frame)
        return .accepted
    }

    public func drain() -> [PinchFrame] {
        lock.lock()
        defer { lock.unlock() }
        let out = frames
        frames.removeAll()
        return out
    }

    public func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        frames.removeAll()
    }
}

// MARK: - 真实后端 provider

/// 真实 MultitouchSupport 后端（T-G-P6 交付物 1）。
///
/// 生命周期（幂等，与 TouchProvider 协议一致）：
/// - start()：off → checking → ready / noDevice / unavailable（已启动 = no-op）；
/// - stop()：任何状态 → off；清空缓冲与开放会话；generation +1；teardown 顺序
///   先 Unregister 再 Stop 再 dlclose（dlclose 只在无回调在途时）；
/// - restart()：清空并重新启用；generation +1。
///
/// 状态上报：设备列表为空 → .noDevice；dlopen/符号缺失 → .unavailable（lastStartDetail 带原因）；
/// 正常 → .ready。不申请权限、不弹权限窗（§18.2）；无法区分「未授予」与「从未申请」时如实上报。
///
/// 注入缝（测试）：libraryFactory 可注入 fake dlopen 结果；deliveryMode 可注入同步交付。
public final class MultitouchSupportBackend: TouchProvider {
    /// 交付模式：asynchronous = 回调线程入队、串行派发队列交付（生产默认；多设备串行消费）；
    /// synchronous = 回调线程直接交付（测试用；单设备单线程假设）。
    public enum DeliveryMode: Sendable {
        case asynchronous
        case synchronous
    }

    /// 库工厂（默认真实 dlopen；测试注入 fake）。
    public var libraryFactory: () -> MultitouchLibrary?

    private let lock = NSLock()
    private let deliveryQueue: DispatchQueue
    private let deliveryMode: DeliveryMode
    private let queue: BoundedFrameQueue

    private var stateStorage: TouchProviderState = .off
    private var generationStorage = 0
    private var isStartedStorage = false
    private var library: MultitouchLibrary?
    private var devices: [MultitouchDevice] = []
    private var deviceKeyMap: [MTDeviceRef: PinchDeviceID] = [:]
    private var synthesizer = MultitouchFrameSynthesizer()
    private var drainScheduled = false
    /// start 尝试代数：.checking 通知后（锁外加载）被 stop/restart 打断时撤销本次注册。
    private var startAttempt = 0
    private var nextDeviceID = 1
    /// 与全局 activeBackendOwner 配对；stop 仅清自己的 owner，避免旧实例清新实例。
    private var deviceOwner: UInt64 = 0
    private static var nextOwner: UInt64 = 1

    // 中性计数（允许记录；不记录坐标/序列号/时间戳原始值）
    private var deliveredFrameCountStorage = 0
    private var rejectedFrameCountStorage = 0
    private var droppedMovedFrameCountStorage = 0
    private var stateChangeCountStorage = 0
    private var lastStartDetailStorage = "notStarted"
    private var lastTeardownDetailStorage = "notStopped"
    /// 诊断：原始回调到达次数（含被 deviceKeyMap 拒绝前；中性计数）。
    private var rawCallbackCountStorage = 0

    public var onStateChange: ((TouchProviderState) -> Void)?
    public var onFrame: ((PinchFrame) -> Void)?

    public init(maxQueueSize: Int = 64,
                deliveryMode: DeliveryMode = .asynchronous,
                libraryFactory: (() -> MultitouchLibrary?)? = nil) {
        self.deliveryMode = deliveryMode
        self.queue = BoundedFrameQueue(maxSize: max(1, maxQueueSize))
        self.deliveryQueue = DispatchQueue(label: "com.pagingprototype.multitouch.delivery")
        self.libraryFactory = libraryFactory ?? { RealMultitouchLibrary() }
    }

    // MARK: - TouchProvider 状态访问（读侧加锁）

    public var state: TouchProviderState {
        lock.lock()
        defer { lock.unlock() }
        return stateStorage
    }

    public var generation: Int {
        lock.lock()
        defer { lock.unlock() }
        return generationStorage
    }

    public var isStarted: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isStartedStorage
    }

    public var deliveredFrameCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return deliveredFrameCountStorage
    }

    public var rejectedFrameCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return rejectedFrameCountStorage
    }

    public var droppedMovedFrameCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return droppedMovedFrameCountStorage
    }

    public var stateChangeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return stateChangeCountStorage
    }

    /// 最近一次启动细节（dlopenFailed / noDevices / ok(devices=N) / registrationFailed）。
    public var lastStartDetail: String {
        lock.lock()
        defer { lock.unlock() }
        return lastStartDetailStorage
    }

    /// 最近一次 teardown 细节（closed / dlcloseSkippedInFlightCallbacks）。
    public var lastTeardownDetail: String {
        lock.lock()
        defer { lock.unlock() }
        return lastTeardownDetailStorage
    }

    /// 原始 C 回调到达次数（中性；用于区分「无回调/权限」vs「查表拒绝」）。
    public var rawCallbackCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return rawCallbackCountStorage
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
        guard !isStartedStorage else {
            lock.unlock()
            return // 幂等：已启动 = no-op
        }
        isStartedStorage = true
        startAttempt += 1
        let attempt = startAttempt
        stateStorage = .checking
        stateChangeCountStorage += 1
        notifications.append(.checking)
        lock.unlock()
        for s in notifications { onStateChange?(s) } // 锁外派发

        // 库加载与设备注册在锁外（dlopen 可能慢；.checking 期间可被 stop/restart 打断）
        guard let lib = libraryFactory() else {
            finishStart(attempt: attempt, state: .unavailable, detail: "dlopenFailed",
                        library: nil, devices: [])
            return
        }
        let devs = lib.enumerateDevices()
        guard !devs.isEmpty else {
            lib.close() // 无设备：不保留句柄
            finishStart(attempt: attempt, state: .noDevice, detail: "noDevices",
                        library: nil, devices: [])
            return
        }

        // 对齐 LaunchBetter：先挂活跃 backend + 预填 deviceKeyMap，再 register/start，
        // 避免首批回调因查表未就绪被拒，也避免按 device 指针查表失败。
        let owner: UInt64
        lock.lock()
        Self.nextOwner &+= 1
        owner = Self.nextOwner
        deviceOwner = owner
        var preMap: [MTDeviceRef: PinchDeviceID] = [:]
        for d in devs {
            let id = PinchDeviceID(rawValue: nextDeviceID)
            nextDeviceID += 1
            preMap[d.registryKey] = id
        }
        deviceKeyMap = preMap
        lock.unlock()

        registryLock.lock()
        activeBackend = self
        activeBackendOwner = owner
        registryLock.unlock()

        var registered: [MultitouchDevice] = []
        for d in devs {
            if d.registerContactFrameCallback(contactFrameCallback) && d.start() {
                registered.append(d)
            } else {
                d.unregisterContactFrameCallback(contactFrameCallback)
            }
        }
        guard !registered.isEmpty else {
            registryLock.lock()
            if activeBackendOwner == owner {
                activeBackend = nil
            }
            registryLock.unlock()
            lib.close()
            finishStart(attempt: attempt, state: .unavailable, detail: "registrationFailed",
                        library: nil, devices: [])
            return
        }
        // 仅保留成功注册的设备键。
        lock.lock()
        let registeredKeys = Set(registered.map(\.registryKey))
        deviceKeyMap = deviceKeyMap.filter { registeredKeys.contains($0.key) }
        lock.unlock()
        finishStart(attempt: attempt, state: .ready, detail: "ok(devices=\(registered.count))",
                    library: lib, devices: registered)
    }

    public func stop() {
        var notification: TouchProviderState?
        var lib: MultitouchLibrary?
        var devs: [MultitouchDevice] = []
        lock.lock()
        guard isStartedStorage else {
            lock.unlock()
            return // 幂等：未启动 = no-op
        }
        isStartedStorage = false
        generationStorage += 1
        startAttempt += 1
        lib = library
        devs = devices
        library = nil
        devices = []
        deviceKeyMap.removeAll()
        synthesizer = MultitouchFrameSynthesizer()
        queue.removeAll()
        stateStorage = .off
        stateChangeCountStorage += 1
        notification = .off
        lock.unlock()

        teardownDevices(devs, library: lib)

        if let n = notification { onStateChange?(n) } // 锁外派发
    }

    public func restart() {
        // 与 Mock/识别器一致：restart 无条件 generation +1
        var lib: MultitouchLibrary?
        var devs: [MultitouchDevice] = []
        lock.lock()
        isStartedStorage = false
        generationStorage += 1
        startAttempt += 1
        lib = library
        devs = devices
        library = nil
        devices = []
        deviceKeyMap.removeAll()
        synthesizer = MultitouchFrameSynthesizer()
        queue.removeAll()
        lock.unlock()

        teardownDevices(devs, library: lib)
        start()
    }

    // MARK: - 帧注入（C 回调路径）

    /// C 回调入口：最小拷贝 MTTouch → RawTouch（回调内不做分析）。
    fileprivate func ingestRawFrame(deviceKey: MTDeviceRef, touchesPtr: UnsafeMutableRawPointer,
                                    count: Int32, timestamp: Double, frame: Int32,
                                    receivedAt: TimeInterval) {
        let n = Int(count)
        var rawTouches: [RawTouch] = []
        if n > 0 {
            let typed = touchesPtr.assumingMemoryBound(to: MTTouch.self)
            let buffer = UnsafeBufferPointer(start: typed, count: n)
            rawTouches.reserveCapacity(n)
            for t in buffer {
                rawTouches.append(RawTouch(identifier: t.identifier, state: t.state,
                                           x: t.normalized.position.x, y: t.normalized.position.y))
            }
        }
        ingestRawTouches(deviceKey: deviceKey, timestamp: timestamp, frame: frame,
                         touches: rawTouches, receivedAt: receivedAt)
    }

    /// 原始触点帧注入（合成 + 有界入队；onFrame 锁外派发）。
    /// 测试可直接调用（fake 帧源）。
    public func ingestRawTouches(deviceKey: MTDeviceRef, timestamp: Double, frame: Int32,
                                 touches: [RawTouch]) {
        let receivedAt = ProcessInfo.processInfo.systemUptime
        ingestRawTouches(deviceKey: deviceKey, timestamp: timestamp, frame: frame,
                         touches: touches, receivedAt: receivedAt)
    }

    /// Internal seam also used by the C callback: receipt precedes every copy,
    /// registry/backend lock and queue wait. Never resample it during delivery.
    func ingestRawTouches(deviceKey: MTDeviceRef, timestamp: Double, frame: Int32,
                          touches: [RawTouch], receivedAt: TimeInterval) {
        var frames: [PinchFrame] = []
        lock.lock()
        rawCallbackCountStorage += 1
        guard isStartedStorage else {
            rejectedFrameCountStorage += 1
            lock.unlock()
            return
        }
        // 设备键：精确命中 → 单设备回退（LaunchBetter 忽略回调 device）→ 任意首键。
        let deviceID: PinchDeviceID
        if let exact = deviceKeyMap[deviceKey] {
            deviceID = exact
        } else if deviceKeyMap.count == 1, let only = deviceKeyMap.values.first {
            deviceID = only
        } else if let first = deviceKeyMap.values.first {
            deviceID = first
        } else {
            rejectedFrameCountStorage += 1
            lock.unlock()
            return
        }
        frames = synthesizer.synthesize(deviceID: deviceID, callbackTimestamp: timestamp,
                                        touches: touches, uptimeNow: receivedAt)
        if frames.isEmpty {
            rejectedFrameCountStorage += 1
        }
        for f in frames {
            switch queue.enqueue(f) {
            case .accepted:
                break
            case .droppedMoved:
                droppedMovedFrameCountStorage += 1
            case .rejected:
                rejectedFrameCountStorage += 1
            }
        }
        if !frames.isEmpty {
            switch deliveryMode {
            case .synchronous:
                let toDeliver = queue.drain()
                lock.unlock()
                deliver(toDeliver)
                return
            case .asynchronous:
                if !drainScheduled {
                    drainScheduled = true
                    deliveryQueue.async { [weak self] in self?.drain() }
                }
            }
        }
        lock.unlock()
    }

    // MARK: - 内部

    /// 完成 start 的最终状态落定；被更新的 start/stop/restart 打断时撤销本次注册。
    private func finishStart(attempt: Int, state newState: TouchProviderState, detail: String,
                             library lib: MultitouchLibrary?, devices devs: [MultitouchDevice]) {
        var notification: TouchProviderState?
        lock.lock()
        guard isStartedStorage, startAttempt == attempt else {
            lock.unlock()
            teardownDevices(devs, library: lib)
            return
        }
        if !devs.isEmpty {
            library = lib
            devices = devs
            // deviceKeyMap 已在 start() 注册前预填；此处只确保成功设备仍在 map 中。
            if deviceKeyMap.isEmpty {
                for d in devs {
                    let id = PinchDeviceID(rawValue: nextDeviceID)
                    nextDeviceID += 1
                    deviceKeyMap[d.registryKey] = id
                }
            }
        }
        stateStorage = newState
        lastStartDetailStorage = detail
        stateChangeCountStorage += 1
        notification = newState
        lock.unlock()
        if let n = notification { onStateChange?(n) } // 锁外派发
    }

    /// teardown 顺序：先 Unregister 再 Stop 再 dlclose（dlclose 只在无回调在途时）。
    private func teardownDevices(_ devs: [MultitouchDevice], library lib: MultitouchLibrary?) {
        guard !devs.isEmpty || lib != nil else { return }
        let owner = deviceOwner
        registryLock.lock()
        for d in devs {
            d.unregisterContactFrameCallback(contactFrameCallback)
        }
        // 仅 owner 匹配时清空全局活跃 backend（对齐 LaunchBetter stopDevices owner 语义）。
        if activeBackendOwner == owner {
            activeBackend = nil
        }
        registryLock.unlock()
        for d in devs { d.stop() }
        guard let lib = lib else { return }
        if waitForInFlightCallbacks(timeout: 1.0) {
            lib.close()
            lock.lock()
            lastTeardownDetailStorage = "closed"
            lock.unlock()
        } else {
            // 超时仍有回调在途：跳过 dlclose（安全优先；句柄泄漏记录在案，不崩溃）
            lock.lock()
            lastTeardownDetailStorage = "dlcloseSkippedInFlightCallbacks"
            lock.unlock()
        }
    }

    /// 等待在途回调归零（dlclose 前置条件；R-05）。
    private func waitForInFlightCallbacks(timeout: TimeInterval) -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        while true {
            registryLock.lock()
            let n = inFlightCallbacks
            registryLock.unlock()
            if n == 0 { return true }
            if ProcessInfo.processInfo.systemUptime >= deadline { return false }
            usleep(1000)
        }
    }

    /// 串行派发队列上的交付循环：drain → 锁外 deliver → 队列非空则继续。
    /// 竞态防护：drainScheduled 置 false 后复查队列，保证入队帧最终被交付或随 stop 丢弃。
    private func drain() {
        while true {
            var frames: [PinchFrame] = []
            lock.lock()
            guard isStartedStorage else {
                drainScheduled = false
                lock.unlock()
                return
            }
            frames = queue.drain()
            drainScheduled = false
            let hasMore = queue.count > 0
            lock.unlock()
            deliver(frames)
            if !hasMore { return }
        }
    }

    private func deliver(_ frames: [PinchFrame]) {
        for f in frames {
            lock.lock()
            deliveredFrameCountStorage += 1
            lock.unlock()
            onFrame?(f) // 锁外派发（§20.2：user closure 在锁外调用）
        }
    }
}
