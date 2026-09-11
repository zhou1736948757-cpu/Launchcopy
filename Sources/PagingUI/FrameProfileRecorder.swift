//
//  FrameProfileRecorder.swift
//  PagingUI
//
//  帧路径耗时探针（--frame-profile 诊断模式；T-worker-b-frameprofile）。
//
//  背景（Main 已分析，phys1b-03/04 telemetry）：卡顿帧（frame_interval > 20ms，
//  偶发 20–48ms）全部发生在 gesture.changed / transition / momentum 期间；与图标
//  加载（启动 1s 内完成）零重叠；与 layout 零共现；无周期性（排除 GC）。卡顿在
//  交互/渲染路径（输入处理 → 状态机 → 视图更新），具体环节未知 → 本探针逐阶段定位。
//
//  记录两类样本（同一 JSONL 文件，kind 区分；每行一条 JSON，sortedKeys）：
//  - kind=frame：帧回调（PagingSurface.advanceFrame）——
//    input_ns = 输入处理（pending 输入分发：待决释放决策窗口检查 + finishGesture，
//               含其同步事件回调的视图耗时）；
//    state_ns = 状态机推进（core.tick，扣除状态窗口内同步视图回调后的纯状态机耗时）；
//    view_ns  = 视图更新（状态窗口内 core 事件同步回调 handleCoreOffset/handleCoreState/
//               handleCoreCommit/handleCoreTransitionBegin 内耗时 + 帧末驱动控制）；
//    total_ns = 帧回调总耗时（未归属 = onAnimationFrame 观察钩子 + 测量自身开销）。
//  - kind=input：输入事件（PagingSurface.handleScrollInput：gesture.changed 等）——
//    input_ns = 输入处理（ScrollInputMapper.map + 动作分发，扣除 core/view 后余量）；
//    state_ns = 状态机推进（core.handleGesturePhase/finishGesture/legacyScrollDelta 调用，
//               扣除 core 窗口内同步视图回调后的纯状态机耗时）；
//    view_ns  = 视图更新（core 事件同步回调 + onGestureEvent 观察钩子）；
//    total_ns = 输入处理总耗时（未归属 = updateAnimationDriver + 测量自身开销）。
//  归属不变量：视图回调在 core 调用内同步触发（core 事件 → 视图处理），视图耗时是
//  core 耗时的子集 → 从 core 耗时中扣除，state/view 不双重计数；
//  input_ns + state_ns + view_ns ≤ total_ns（测试断言）。
//
//  设计约束：
//  - 默认关闭（isActive == false 时全部方法 no-op：零测量、零文件、零逻辑参与）；
//  - 测量开销最小化：内存缓冲 + 阈值批量落盘（帧路径上不做 I/O）；
//  - 探针不参与任何逻辑（只读计时，不改状态、不触发副作用）；
//  - 主线程使用（帧驱动与输入事件均在主线程；无锁）；
//  - 隐私：仅耗时数值与手势阶段枚举，无 app 名/路径/图标数据。
//

import AppKit
import Foundation

/// 帧路径耗时探针（--frame-profile 诊断模式）。
public final class FrameProfileRecorder {

    /// 是否激活（false = 全部方法 no-op；缺省关闭）。
    public private(set) var isActive: Bool

    /// 输出文件 URL（缺省 /tmp/launch-copy-paging-prototype-<runID>-profile.jsonl）。
    public let fileURL: URL

    /// 已记录样本数（含已落盘与仍在缓冲的）。
    public private(set) var recordCount = 0

    /// 文件写入失败批次数（异步 writer 的失败不会崩溃；查询可能等待 writer）。
    public var writeFailureCount: Int {
        writer?.failureCount ?? 0
    }

    /// 缓冲上限（防失控增长；超出丢弃最旧）。
    public var bufferCapacity = 20_000

    /// 批量落盘阈值（达到才写文件；帧路径不做 I/O）。
    public var flushThreshold = 512

    private let clock = ContinuousClock()
    private var buffer: [String] = []
    /// Lazily created only after an active recorder accepts a batch.
    private var writer: BufferedJSONLWriter?

    // 帧测量窗口（advanceFrame）
    private var frameStart: ContinuousClock.Instant?
    private var frameInputDone: ContinuousClock.Instant?
    private var frameStateDone: ContinuousClock.Instant?
    private var frameViewDone: ContinuousClock.Instant?
    private var frameTimestamp: TimeInterval = 0

    // 输入测量窗口（handleScrollInput）
    private var inputStart: ContinuousClock.Instant?
    private var inputDispatchDone: ContinuousClock.Instant?
    private var inputViewDone: ContinuousClock.Instant?
    private var inputTimestamp: TimeInterval = 0
    private var inputPhase = ""

    // 子阶段累计（core 调用 / 视图回调；按测量窗口归属，窗口开始重置）
    // 视图回调在 core 调用内同步触发（core 事件 → 视图处理），故视图耗时是 core 耗时的
    // 子集：core 窗口内视图耗时单独累计（viewInsideCoreNS），避免 state/view 双重计数。
    private var coreAccumulatorNS: Int64 = 0
    private var coreNesting = 0
    private var coreWorkStart: ContinuousClock.Instant?
    private var viewAccumulatorNS: Int64 = 0
    private var viewInsideCoreNS: Int64 = 0
    private var viewNesting = 0
    private var viewWorkStart: ContinuousClock.Instant?
    private var viewWorkInsideCore = false
    /// 帧状态窗口（markFrameInputDone → markFrameStateDone）内的视图耗时。
    private var stateWindowViewNS: Int64 = 0

    /// - Parameters:
    ///   - runID: 本次 run 的 ID（经文件安全净化后用于文件名）。
    ///   - fileURL: 输出文件（缺省 /tmp/launch-copy-paging-prototype-<runID>-profile.jsonl）。
    ///   - active: 是否立即激活（缺省 false = 关闭）。
    public convenience init(runID: String, fileURL: URL? = nil, active: Bool = false) {
        self.init(runID: runID, fileURL: fileURL, active: active, writer: nil)
    }

    /// Internal seam for deterministic writer-queue tests. Production uses the
    /// public initializer, so the writer remains absent while diagnostics are off.
    init(runID: String, fileURL: URL? = nil, active: Bool, writer: BufferedJSONLWriter?) {
        let sanitized = Self.sanitizedRunID(runID)
        self.fileURL = fileURL
            ?? URL(fileURLWithPath: "/tmp/launch-copy-paging-prototype-\(sanitized)-profile.jsonl")
        self.isActive = active
        self.writer = writer
    }

    deinit {
        // 尽力落盘（对象销毁路径；不执行记录）。
        flush()
    }

    // MARK: - 帧回调测量（PagingSurface.advanceFrame）

    /// 开始一帧测量（帧回调入口）。
    public func beginFrame(timestamp: TimeInterval) {
        guard isActive else { return }
        frameStart = clock.now
        frameInputDone = nil
        frameStateDone = nil
        frameViewDone = nil
        frameTimestamp = timestamp
        resetSubStages()
    }

    /// 输入处理阶段结束（pending 输入分发完成）。
    /// 输入窗口内的视图回调（finishGesture 同步事件）归属 input_ns，从视图归属中剔除。
    public func markFrameInputDone() {
        guard isActive, frameStart != nil else { return }
        frameInputDone = clock.now
        viewAccumulatorNS = 0
        viewInsideCoreNS = 0
    }

    /// 状态机阶段结束（core.tick 返回）。
    /// 捕获状态窗口内的视图耗时（core.tick 同步事件回调），供 state/view 拆分。
    public func markFrameStateDone() {
        guard isActive, frameStart != nil else { return }
        frameStateDone = clock.now
        stateWindowViewNS = viewAccumulatorNS
    }

    /// 视图阶段结束（驱动控制完成）。
    public func markFrameViewDone() {
        guard isActive, frameStart != nil else { return }
        frameViewDone = clock.now
    }

    /// 结束一帧测量并缓冲记录（帧回调出口）。
    public func endFrame(gestureActive: Bool) {
        guard isActive, let frameStart else { return }
        let end = clock.now
        let inputNS = frameInputDone.map { ns(frameStart, $0) } ?? 0
        let stateRawNS = frameStateDone.map { ns(frameInputDone ?? frameStart, $0) } ?? 0
        let driverNS = frameViewDone.map { ns(frameStateDone ?? frameStart, $0) } ?? 0
        let stateNS = max(0, stateRawNS - stateWindowViewNS)
        let viewNS = stateWindowViewNS + driverNS
        let totalNS = ns(frameStart, end)
        let line = "{\"gesture_active\":\(gestureActive),\"input_ns\":\(inputNS),\"kind\":\"frame\",\"state_ns\":\(stateNS),\"timestamp\":\(Self.formatTimestamp(frameTimestamp)),\"total_ns\":\(totalNS),\"view_ns\":\(viewNS)}"
        appendLine(line)
        self.frameStart = nil
    }

    // MARK: - 输入事件测量（PagingSurface.handleScrollInput）

    /// 开始一次输入事件测量（输入入口）。
    public func beginInput(timestamp: TimeInterval, phase: String) {
        guard isActive else { return }
        inputStart = clock.now
        inputDispatchDone = nil
        inputViewDone = nil
        inputTimestamp = timestamp
        inputPhase = phase
        resetSubStages()
    }

    /// 输入分发阶段结束（动作循环完成）。
    public func markInputDispatchDone() {
        guard isActive, inputStart != nil else { return }
        inputDispatchDone = clock.now
    }

    /// 视图阶段结束（驱动控制完成）。
    public func markInputViewDone() {
        guard isActive, inputStart != nil else { return }
        inputViewDone = clock.now
    }

    /// 结束一次输入事件测量并缓冲记录（输入出口）。
    public func endInput(gestureActive: Bool) {
        guard isActive, let inputStart else { return }
        let end = clock.now
        let dispatchNS = inputDispatchDone.map { ns(inputStart, $0) } ?? 0
        // 视图回调在 core 调用内同步触发 → 从 core 耗时中扣除，避免双重计数。
        let stateNS = max(0, coreAccumulatorNS - viewInsideCoreNS)
        let viewNS = viewAccumulatorNS
        let inputNS = max(0, dispatchNS - stateNS - viewNS)
        let totalNS = ns(inputStart, end)
        let line = "{\"gesture_active\":\(gestureActive),\"input_ns\":\(inputNS),\"kind\":\"input\",\"phase\":\"\(inputPhase)\",\"state_ns\":\(stateNS),\"timestamp\":\(Self.formatTimestamp(inputTimestamp)),\"total_ns\":\(totalNS),\"view_ns\":\(viewNS)}"
        appendLine(line)
        self.inputStart = nil
    }

    // MARK: - 子阶段计时（core 调用 / 视图回调；PagingSurface 内部调用）

    /// core 调用计时开始（apply 内 core.handleGesturePhase/finishGesture/legacyScrollDelta）。
    public func coreWorkBegin() {
        guard isActive, inputStart != nil, coreNesting == 0 else { return }
        coreWorkStart = clock.now
        coreNesting = 1
    }

    /// core 调用计时结束。
    public func coreWorkEnd() {
        guard isActive, coreNesting > 0, let coreWorkStart else { return }
        coreAccumulatorNS += ns(coreWorkStart, clock.now)
        coreNesting = 0
        self.coreWorkStart = nil
    }

    /// 视图回调计时开始（handleCoreOffset/handleCoreState/handleCoreCommit/
    /// handleCoreTransitionBegin/onGestureEvent）。
    public func viewWorkBegin() {
        guard isActive, viewNesting == 0, frameStart != nil || inputStart != nil else { return }
        viewWorkStart = clock.now
        viewNesting = 1
        viewWorkInsideCore = coreNesting > 0
    }

    /// 视图回调计时结束。
    public func viewWorkEnd() {
        guard isActive, viewNesting > 0, let viewWorkStart else { return }
        let delta = ns(viewWorkStart, clock.now)
        viewAccumulatorNS += delta
        if viewWorkInsideCore {
            viewInsideCoreNS += delta
        }
        viewNesting = 0
        self.viewWorkStart = nil
    }

    // MARK: - 落盘

    /// 把当前缓冲切批并等待专用串行 writer 完成已接收记录。此方法可在
    /// teardown 调用；帧/输入热回调只会异步入队，不会在调用线程做文件 I/O。
    public func flush() {
        enqueueBufferedLines()
        writer?.flush()
    }

    // MARK: - 工具

    /// 输入事件阶段描述（kind=input 记录的 phase 字段；momentum 事件带 momentum. 前缀）。
    public static func phaseName(phase: NSEvent.Phase, momentumPhase: NSEvent.Phase) -> String {
        let isMomentum = momentumPhase.contains(.began)
            || momentumPhase.contains(.changed)
            || momentumPhase.contains(.ended)
        let source = isMomentum ? momentumPhase : phase
        let name: String
        switch source {
        case .began: name = "began"
        case .changed: name = "changed"
        case .ended: name = "ended"
        case .cancelled: name = "cancelled"
        case .stationary: name = "stationary"
        case .mayBegin: name = "mayBegin"
        default: name = "none"
        }
        return isMomentum ? "momentum.\(name)" : name
    }

    /// 把 run ID 净化为文件安全形式（与 PagingTelemetry 同规则；PagingUI 不依赖 PagingTelemetry）。
    public static func sanitizedRunID(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        var scalars = String.UnicodeScalarView()
        for scalar in raw.unicodeScalars {
            scalars.append(allowed.contains(scalar) ? scalar : "_")
        }
        let sanitized = String(String(scalars).prefix(64))
        return sanitized.isEmpty ? "run" : sanitized
    }

    private func resetSubStages() {
        coreAccumulatorNS = 0
        coreNesting = 0
        coreWorkStart = nil
        viewAccumulatorNS = 0
        viewInsideCoreNS = 0
        viewNesting = 0
        viewWorkStart = nil
        viewWorkInsideCore = false
        stateWindowViewNS = 0
    }

    private func appendLine(_ line: String) {
        buffer.append(line)
        recordCount += 1
        if buffer.count > bufferCapacity {
            buffer.removeFirst(buffer.count - bufferCapacity)
        }
        if buffer.count >= flushThreshold {
            // `endFrame` has already captured total_ns before this point. The
            // hot path only swaps the batch and schedules serial writer work.
            enqueueBufferedLines()
        }
    }

    private func enqueueBufferedLines() {
        guard !buffer.isEmpty else { return }
        let lines = buffer
        buffer.removeAll(keepingCapacity: true)
        let writer = writer ?? BufferedJSONLWriter(fileURL: fileURL)
        self.writer = writer
        writer.enqueue(lines)
    }

    /// 两个时刻之间的纳秒数（ContinuousClock，单调时钟）。
    private func ns(_ start: ContinuousClock.Instant, _ end: ContinuousClock.Instant) -> Int64 {
        let duration = start.duration(to: end)
        let (seconds, attoseconds) = duration.components
        return seconds * 1_000_000_000 + attoseconds / 1_000_000_000
    }

    private static func formatTimestamp(_ value: TimeInterval) -> String {
        String(format: "%.6f", value)
    }
}
