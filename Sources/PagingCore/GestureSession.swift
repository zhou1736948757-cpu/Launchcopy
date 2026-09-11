//
//  GestureSession.swift
//  PagingCore
//
//  Phase 1A — 手势会话（ADR-001 D1/D4/D5）。
//
//  生命周期：began 创建 → changed 累积 → ended（released）→ [momentum 子阶段] → finishGesture 结束。
//  momentum 是 tracking 子阶段：session.isMomentum（momentumActive）为 true 期间
//  视觉偏移继续由输入驱动，不引入新顶层状态。
//  中断（settling + began）时新 session 以当前显示位置为 startOffset（D4：不跳回旧起点/目标）。
//

import Foundation

/// 一次手势会话。Core 主线程独占使用。
public final class GestureSession {

    // 速度估计窗口（实现细节常量，非交互参数）：
    // 取最近 0.1s 内最多 8 个样本；velocity = ΣscaledΔ / Σdt（确定性，可重复序列测试直接驱动）。
    // 单样本（如高速小位移）即得 delta/dt —— dt 为该样本距上一事件（含 began）的时间。
    private static let velocityWindowTime: TimeInterval = 0.1
    private static let velocitySampleCap = 8

    /// 会话 id（单调递增；供 telemetry 关联 gesture ID）。
    public private(set) var id: UInt64
    /// began 时的 visualOffset（页宽单位）。
    public private(set) var startOffset: Double
    /// began 时间戳。
    public private(set) var startTimestamp: TimeInterval
    /// 最近一次生效的 visualOffset（页宽单位；中断接管时即接管点）。
    public private(set) var currentOffset: Double
    /// 生效位移累计（页宽单位，已含边界阻尼）。
    public private(set) var totalDelta: Double
    /// 近期速度估计（px/s，已含 inputSensitivity 缩放；含 momentum 样本）。
    public private(set) var velocityPxPerSecond: Double = 0
    /// momentum 子阶段标记（D1：tracking 子阶段）。
    public private(set) var momentumActive = false
    /// finger up（ended 之后，等待 momentum 或 finishGesture）。
    public private(set) var released = false
    /// momentumEnded 后的惯性滑行模拟（由 Core tick 驱动，momentumDecay 每帧衰减）。
    public private(set) var isMomentumGlide = false
    /// 本 momentum 阶段已跟随的 momentumChanged 事件数（T-worker-b-glide 截断计数；
    /// beginMomentum 时归零）。
    public private(set) var momentumChangedCount = 0
    /// 最近样本时间戳。
    public private(set) var lastTimestamp: TimeInterval

    /// 速度窗口样本（scaled px, dt, timestamp）。
    private var samples: [(deltaPx: Double, dt: TimeInterval, timestamp: TimeInterval)] = []

    init(id: UInt64, startOffset: Double, timestamp: TimeInterval) {
        self.id = id
        self.startOffset = startOffset
        self.currentOffset = startOffset
        self.totalDelta = 0
        self.startTimestamp = timestamp
        self.lastTimestamp = timestamp
    }

    // MARK: - 输入记录（Core 调用；内部方法）

    /// 记录一次手势位移（changed 或 momentumChanged 共用）。
    func recordDelta(_ scaledDeltaPx: Double, timestamp: TimeInterval, resultingOffset: Double) {
        // 时间回拨防御（D5）：时间戳倒退的样本忽略。
        guard timestamp >= lastTimestamp || samples.isEmpty else { return }
        let dt = max(timestamp - lastTimestamp, 0)
        samples.append((scaledDeltaPx, dt, timestamp))
        lastTimestamp = max(timestamp, lastTimestamp)
        currentOffset = resultingOffset
        totalDelta = currentOffset - startOffset
        trimWindow(at: timestamp)
        recomputeVelocity()
    }

    /// ended：手指抬起。
    func markReleased() {
        released = true
    }

    /// momentum 开始：清空手指样本，velocity 改由 momentum 样本决定（物理上 momentum 代表释放瞬间的甩动速度）。
    func beginMomentum(timestamp: TimeInterval) {
        momentumActive = true
        momentumChangedCount = 0
        samples.removeAll()
        lastTimestamp = max(timestamp, lastTimestamp)
    }

    /// 记录一个已生效的 momentumChanged 事件（截断计数用）。
    func noteMomentumChanged() {
        momentumChangedCount += 1
    }

    /// 惯性滑行开始/结束。
    func beginGlide() {
        isMomentumGlide = true
    }

    func endGlide() {
        isMomentumGlide = false
    }

    /// 滑行中每帧更新速度（px/s；momentumDecay 在 Core 中应用）。
    func updateGlideVelocity(_ pxPerSecond: Double) {
        velocityPxPerSecond = pxPerSecond
    }

    /// 滑行中同步视觉偏移（currentOffset 必须跟随 Core.visualOffset，否则释放决策基准失真）。
    func syncToVisualOffset(_ offset: Double) {
        let delta = offset - currentOffset
        startOffset += delta
        currentOffset = offset
        totalDelta = currentOffset - startOffset
    }

    /// resize 比例保持 rebase（D6：物理位置不变；velocity px/s 不随宽度变化）。
    func rebase(oldWidth: Double, newWidth: Double) {
        guard oldWidth > 0, newWidth > 0 else { return }
        startOffset = startOffset * oldWidth / newWidth
        currentOffset = currentOffset * oldWidth / newWidth
        totalDelta = currentOffset - startOffset
    }

    // MARK: - 私有

    private func trimWindow(at timestamp: TimeInterval) {
        while samples.count > Self.velocitySampleCap {
            samples.removeFirst()
        }
        while samples.count > 1,
              let first = samples.first,
              timestamp - first.timestamp > Self.velocityWindowTime {
            samples.removeFirst()
        }
    }

    private func recomputeVelocity() {
        let sumDelta = samples.reduce(0.0) { $0 + $1.deltaPx }
        let sumDT = samples.reduce(0.0) { $0 + $1.dt }
        guard sumDT > 0 else { return } // 全为 dt=0 样本：保持当前速度
        velocityPxPerSecond = sumDelta / sumDT
    }
}
