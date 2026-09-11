//
//  PagingFrameDriver.swift
//  PagingUI
//
//  动画帧驱动抽象（ADR-001 D2：手动插值）。
//  - PagingSurface 只依赖协议；测试可注入 nil（手动 advanceFrame）或观察 start/stop。
//  - 默认实现 RunLoopFrameDriver：主 runloop common 模式 60Hz Timer 帧泵。
//
//  T-worker-b-frame-fix（真机证据）：本环境（Aqua 会话、窗口真实显示）NSView.displayLink
//  全程零回调（phys-auto-02 telemetry：frame 事件 0，gesture/settle 事件正常）——display link
//  API 在此环境不投递帧（疑似虚拟显示/无 vsync 对齐的环境问题；T-step6 曾误判为"无头"）。
//  帧源 = runloop 60Hz 节拍（≈16.67ms），**非 vsync 对齐**；vsync 对齐留 Phase 1B。
//  common 模式保证滚动跟踪（runloop 停在 eventTracking mode）期间仍触发，与 settle 同源。
//

import AppKit
import os

/// 帧驱动协议（UI 层抽象，便于测试与替换）。
public protocol PagingFrameDriving: AnyObject {
    /// 是否正在运行。
    var isRunning: Bool { get }
    func start()
    func stop()
}

/// runloop 60Hz 帧泵实现（默认驱动）。
public final class RunLoopFrameDriver: PagingFrameDriving {

    public private(set) var isRunning = false

    /// 弱引用持有者（避免驱动→surface 强环；surface 持有驱动）。
    private weak var owner: PagingSurface?
    private var timer: Timer?
    private var lastTimestamp: TimeInterval = 0
    private var generation: UInt64 = 0
    private var nextNominalDeadlineNS: UInt64?

    /// Opt-in Timer callback-boundary profiler. Nil by default and therefore
    /// absent from the production hot path.
    public var callbackProfiler: FrameCallbackProfileRecorder?

    /// Signposts for Instruments / xctrace. Created only when the callback
    /// profiler is active; production start() never constructs one.
    private var hitchSignposter: OSSignposter?

    /// 帧泵周期。公开只读，供实验记录与测试；生产默认仍为 60Hz。
    public let interval: TimeInterval

    /// Foundation Timer 的允许延迟窗口。
    /// 生产默认 0ms（PRODUCT_TIMER_TOLERANCE_0MS，T-A4-0ms）；定位实验可显式设为 0 做单变量 A/B。
    public let tolerance: TimeInterval

    /// 单帧最大 dt（秒）：runloop 停顿（如后台/卡顿）后恢复时不放大 dt 造成弹簧失稳。
    private static let maxDeltaTime: TimeInterval = 0.1

    public init(
        owner: PagingSurface,
        interval: TimeInterval = 1.0 / 60.0,
        tolerance: TimeInterval = 0,
        callbackProfiler: FrameCallbackProfileRecorder? = nil
    ) {
        self.owner = owner
        self.interval = max(interval, 0.001)
        self.tolerance = min(max(tolerance, 0), self.interval)
        self.callbackProfiler = callbackProfiler
    }

    public func start() {
        guard timer == nil, let owner else { return }
        lastTimestamp = 0
        generation = generation == UInt64.max ? 1 : generation + 1
        let intervalNS = Self.nanoseconds(for: interval)
        if let callbackProfiler, callbackProfiler.isActive {
            // PointsOfInterest so Time Profiler / Logging templates actually record us.
            let signposter = OSSignposter(subsystem: "PagingPrototype", category: .pointsOfInterest)
            hitchSignposter = signposter
            let armState = signposter.beginInterval("TimerGenerationArm")
            nextNominalDeadlineNS = callbackProfiler.recordGenerationArm(
                driverGeneration: generation,
                intervalNS: intervalNS,
                toleranceNS: Self.nanoseconds(for: tolerance)
            )
            signposter.endInterval("TimerGenerationArm", armState)
        } else {
            hitchSignposter = nil
            nextNominalDeadlineNS = nil
        }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self, weak owner] _ in
            guard let self, let owner, !owner.isTearingDown else { return }

            let profiler = self.callbackProfiler
            let signposter = self.hitchSignposter
            let callbackState = signposter?.beginInterval("TimerCallback")
            let callbackGeneration = self.generation
            let boundary = profiler?.beginCallback(
                driverGeneration: callbackGeneration,
                scheduledNS: self.nextNominalDeadlineNS ?? 0,
                intervalNS: Self.nanoseconds(for: self.interval)
            )
            defer {
                // Closure-return-adjacent marker. This is still not a true
                // closure return; Swift/runtime work after `defer` remains
                // unobserved.
                profiler?.markPreReturn(boundary)
                if let signposter, let callbackState {
                    signposter.endInterval("TimerCallback", callbackState)
                }
            }
            let advanceState = signposter?.beginInterval("AdvanceFrame")
            let dt = self.handleFrame(now: ProcessInfo.processInfo.systemUptime)
            if let signposter, let advanceState {
                signposter.endInterval("AdvanceFrame", advanceState)
            }
            if let boundary {
                // `advanceFrame` may finish the animation and synchronously stop the
                // driver. Always close the record for the callback already in flight,
                // but do not resurrect nominal schedule state after stop().
                let tailState = signposter?.beginInterval("CallbackTail")
                let nextDeadline = profiler?.nextNominalDeadlineNS(after: boundary)
                profiler?.endCallback(boundary, simulationDTNS: dt.flatMap(Self.nanosecondsOptional))
                // A callback may synchronously stop and restart the driver. Never let
                // an older generation overwrite the new generation's nominal schedule.
                if self.isRunning, self.generation == callbackGeneration {
                    self.nextNominalDeadlineNS = nextDeadline
                } else if !self.isRunning {
                    self.nextNominalDeadlineNS = nil
                }
                if let signposter, let tailState {
                    signposter.endInterval("CallbackTail", tailState)
                }
            }
        }
        timer.tolerance = tolerance // 生产默认 0ms（T-A4-0ms）；定位实验可设 0 做单变量 A/B
        // common 模式：eventTracking（滚动跟踪）与默认 idle 均触发。
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        isRunning = true
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        nextNominalDeadlineNS = nil
        hitchSignposter = nil
        isRunning = false
    }

    deinit {
        timer?.invalidate()
    }

    private func handleFrame(now: TimeInterval) -> TimeInterval? {
        let dt: TimeInterval
        if lastTimestamp == 0 {
            dt = interval
        } else {
            dt = min(max(now - lastTimestamp, 0), Self.maxDeltaTime)
        }
        lastTimestamp = now
        owner?.advanceFrame(deltaTime: dt)
        return owner == nil ? nil : dt
    }

    private static func nanoseconds(for interval: TimeInterval) -> UInt64 {
        guard interval.isFinite, interval > 0 else { return 0 }
        let scaled = interval * 1_000_000_000.0
        guard scaled < Double(UInt64.max) else { return UInt64.max }
        return UInt64(scaled.rounded())
    }

    private static func nanosecondsOptional(for interval: TimeInterval) -> UInt64? {
        nanoseconds(for: interval)
    }
}
