//
//  TouchProvider.swift
//  PagingPrototypeApp
//
//  Phase 1G 平台 provider 协议（T-G-P2）。
//  PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT §20.2 回调与锁序 + §23.1 P13/P14/P15（provider 域）。
//  纯 Foundation：无 AppKit、无真实设备访问、无持久化、无私有 API。
//  帧契约：每个接触会话按 began → moved* → ended/cancelled 顺序交付；
//  零触点 moved 帧 = 全部离面 = 结束证据（会话关闭）；
//  帧 timestamp 与注入时钟同一单调时间域（禁止墙钟 Date() 差值）。
//  状态通知：Off/Checking/Ready/NoDevice/Unavailable/PermissionNotConfirmed/Suspended
//  （与 T-G-P3 入口状态模型对齐；本文件只定义通知机制，不实现 UI）。
//  锁序（§20.2）：实现必须保证 user closure（onFrame/onStateChange）在锁外调用；
//  缓冲有界且保留 began/ended/cancelled（不"只留最新帧"丢重新武装条件）。
//

import Foundation

// MARK: - 状态

/// Provider 状态（与 T-G-P3 入口状态模型对齐；Enabled ≠ Ready）。
public enum TouchProviderState: Equatable, Sendable {
    case off
    case checking
    case ready
    case noDevice
    case unavailable
    case permissionNotConfirmed
    case suspended(reason: PinchSuspensionReason)
}

// MARK: - 时钟

/// 可推进单调时钟（playback 预置序列回放推进共享时钟用；生产系统时钟为只读）。
public protocol PinchClockAdvancing: PinchClock {
    func advance(by delta: TimeInterval)
}

// MARK: - 协议

/// 平台触点 provider（T-G-P2）。
///
/// 设备生命周期（幂等语义）：
/// - `start()`：已启动 = no-op（不重复通知、不递增 generation）；
/// - `stop()`：未启动 = no-op；停止时清空缓冲与开放会话、generation +1（旧事件失效）；
/// - `restart()`：清空并重新启用，生成新 generation。
///
/// 有效触点帧：
/// - 帧必须携带设备标识（`PinchFrame.deviceID`，与识别器 `PinchDeviceID` 对齐）；
/// - 帧 timestamp 与注入时钟同一单调时间域（禁止墙钟 `Date()`）；
/// - 每个接触会话按 began → moved* → ended/cancelled 顺序交付；零触点 moved = 结束证据；
/// - 违反序列的帧被拒绝（不交付），拒绝计数可查（实现提供中性计数）。
///
/// 锁序（§20.2）：
/// - `onFrame`/`onStateChange` 在锁外派发；回调内可安全调用 start/stop/restart（同步重入不死锁）；
/// - 缓冲有界；过载丢帧优先丢 moved（可压缩），保留 began/ended/cancelled（重新武装条件）。
public protocol TouchProvider: AnyObject {
    /// 当前状态。
    var state: TouchProviderState { get }
    /// 状态变化通知（锁外派发；T-G-P3 消费）。
    var onStateChange: ((TouchProviderState) -> Void)? { get set }
    /// 帧交付回调（锁外派发；消费方串行消费——识别器为无锁值类型，需串行访问）。
    var onFrame: ((PinchFrame) -> Void)? { get set }
    /// 当前 generation（stop/restart 递增；消费方据此丢弃旧事件，§20.2）。
    var generation: Int { get }
    /// 是否已启动。
    var isStarted: Bool { get }

    /// 启动：off → checking → 就绪态（幂等：已启动 = no-op）。
    func start()
    /// 停止：任何状态 → off；清空缓冲与开放会话；generation +1（幂等：未启动 = no-op）。
    func stop()
    /// 重启：清空并重新启用；generation +1（旧 generation 事件失效）。
    func restart()
}
