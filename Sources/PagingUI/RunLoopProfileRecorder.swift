//
//  RunLoopProfileRecorder.swift
//  PagingUI
//
//  runloop 级主线程探针（opt-in；--frame-profile 或 --runloop-profile）。
//
//  观察活动掩码 = entry/beforeTimers/beforeSources/beforeWaiting/afterWaiting/exit。
//  本环境 SDK 缺少 afterTimers/afterSources。记录只作为 coarse active-vs-waiting
//  边界，不能单独证明 scheduler / wake-up / WindowServer。
//
//  关联字段 timestamp_ns 使用 DiagnosticMonotonicClock（CLOCK_MONOTONIC_RAW）。
//  遗留字段 timestamp 仍是 ProcessInfo.systemUptime，不得与 timestamp_ns 或
//  callback entry_ns 做精确相减。
//

import AppKit
import Foundation

/// runloop 级主线程探针。
public final class RunLoopProfileRecorder {

    /// 是否激活（false = 全部方法 no-op；缺省关闭）。
    public private(set) var isActive: Bool

    /// 输出文件 URL（缺省 /tmp/launch-copy-paging-prototype-<runID>-runloop.jsonl）。
    public let fileURL: URL

    /// 观察者是否已注册到主 runloop。
    public private(set) var isObserving = false

    /// 已记录样本数（含已落盘与仍在缓冲的）。
    public private(set) var recordCount = 0

    /// JSONL lines dropped because the in-memory buffer exceeded capacity.
    public private(set) var droppedRecordCount = 0

    /// 文件写入失败批次数（异步 writer 的失败不会崩溃；查询可能等待 writer）。
    public var writeFailureCount: Int {
        writer?.failureCount ?? 0
    }

    /// 缓冲上限（防失控增长；超出丢弃最旧）。
    public var bufferCapacity = 20_000

    /// 批量落盘阈值（达到才写文件；观察回调内不做 I/O）。
    public var flushThreshold = 512

    /// 观察的活动掩码：用于 coarse active-vs-waiting 模式，不细分 timer/source。
    /// 注：本环境 SDK 的 CFRunLoop.h 被裁剪（缺 kCFRunLoopAfterTimers(1<<3) 与
    /// kCFRunLoopAfterSources(1<<4)），运行时记录也可能缺少这些活动；不要由单个
    /// waiting 区间推断系统调度或具体等待原因。
    public static let observedActivities: CFRunLoopActivity = [
        .entry, .beforeTimers, .beforeSources, .beforeWaiting, .afterWaiting, .exit,
    ]

    private let clock: DiagnosticMonotonicClock
    private let modeProvider: () -> String?
    private var buffer: [String] = []
    /// Lazily created only after an active recorder accepts a batch.
    private var writer: BufferedJSONLWriter?
    private var observer: CFRunLoopObserver?
    private var lastTimestampNS: UInt64?
    private var lastActivityName: String?
    private var lastSame: [String: UInt64] = [:]
    private var observationSeq: UInt64 = 0

    /// - Parameters:
    ///   - runID: 本次 run 的 ID（经文件安全净化后用于文件名）。
    ///   - fileURL: 输出文件（缺省 /tmp/launch-copy-paging-prototype-<runID>-runloop.jsonl）。
    ///   - active: 是否立即激活（缺省 false = 关闭）。
    public convenience init(
        runID: String,
        fileURL: URL? = nil,
        active: Bool = false,
        clock: DiagnosticMonotonicClock = .system
    ) {
        self.init(
            runID: runID,
            fileURL: fileURL,
            active: active,
            clock: clock,
            modeProvider: Self.currentRawRunLoopMode,
            writer: nil
        )
    }

    /// Internal seam for deterministic clock, mode, and writer tests.
    init(
        runID: String,
        fileURL: URL? = nil,
        active: Bool,
        clock: DiagnosticMonotonicClock,
        modeProvider: @escaping () -> String?,
        writer: BufferedJSONLWriter?
    ) {
        let sanitized = Self.sanitizedRunID(runID)
        self.fileURL = fileURL
            ?? URL(fileURLWithPath: "/tmp/launch-copy-paging-prototype-\(sanitized)-runloop.jsonl")
        self.isActive = active
        self.clock = clock
        self.modeProvider = modeProvider
        self.writer = writer
    }

    /// Internal seam for deterministic writer-queue tests.
    convenience init(runID: String, fileURL: URL? = nil, active: Bool, writer: BufferedJSONLWriter?) {
        self.init(
            runID: runID,
            fileURL: fileURL,
            active: active,
            clock: .system,
            modeProvider: Self.currentRawRunLoopMode,
            writer: writer
        )
    }

    deinit {
        // 尽力移除观察者 + 落盘（对象销毁路径；不执行记录）。
        stop()
        flush()
    }

    // MARK: - 生命周期

    /// 注册观察者到主 runloop（幂等；未激活时 no-op）。
    public func start() {
        guard isActive, observer == nil else { return }
        let observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            Self.observedActivities.rawValue,
            true, // repeats：每个 runloop 周期都观察
            0
        ) { [weak self] _, activity in
            self?.handle(activity)
        }
        guard let observer else { return }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        self.observer = observer
        isObserving = true
    }

    /// 移除观察者（幂等）。
    public func stop() {
        guard let observer else { return }
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
        self.observer = nil
        isObserving = false
    }

    // MARK: - 观察回调（主 runloop 线程）

    private func handle(_ activity: CFRunLoopActivity) {
        guard isActive else { return }
        let now = clock.wallNowNS()
        let name = Self.activityName(activity)
        let mode = Self.modeCategory(rawMode: modeProvider())
        let gapNS: UInt64 = lastTimestampNS.map { now >= $0 ? now - $0 : 0 } ?? 0
        let sinceSameNS: UInt64 = lastSame[name].map { now >= $0 ? now - $0 : 0 } ?? 0
        let previous = lastActivityName ?? "none"
        lastTimestampNS = now
        lastActivityName = name
        lastSame[name] = now
        if observationSeq < UInt64.max {
            observationSeq += 1
        }
        let line = "{\"activity\":\"\(name)\",\"gap_ns\":\(gapNS),\"kind\":\"runloop\",\"mode\":\"\(mode)\",\"observation_seq\":\(observationSeq),\"previous_activity\":\"\(previous)\",\"since_same_ns\":\(sinceSameNS),\"timestamp\":\(Self.formatTimestamp(ProcessInfo.processInfo.systemUptime)),\"timestamp_ns\":\(now)}"
        appendLine(line)
    }

    /// Testing seam: record one observation with the injected clock. Production
    /// observers call the same private `handle`.
    func recordObservationForTesting(_ activity: CFRunLoopActivity) {
        handle(activity)
    }

    // MARK: - 落盘

    /// 切出当前缓冲并等待专用串行 writer 落完此前接收的记录。观察回调只会
    /// 异步入队；目录创建、open、write 与权限调整都不在主 runloop 回调执行。
    public func flush() {
        enqueueBufferedLines()
        writer?.flush()
    }

    // MARK: - 工具

    /// CFRunLoopActivity → 稳定活动名（JSON 值）。
    public static func activityName(_ activity: CFRunLoopActivity) -> String {
        switch activity {
        case .entry: return "entry"
        case .beforeTimers: return "beforeTimers"
        case .beforeSources: return "beforeSources"
        case .beforeWaiting: return "beforeWaiting"
        case .afterWaiting: return "afterWaiting"
        case .exit: return "exit"
        default: return "unknown"
        }
    }

    /// 把当前 runloop mode 压缩为固定匿名类别；绝不写出原始 mode 字符串。
    /// `other` 仅说明当前 mode 不属于已知三类，不能据此推断具体系统组件。
    public static func modeCategory(rawMode: String?) -> String {
        guard let rawMode else { return "none" }
        if rawMode.contains("kCFRunLoopDefaultMode") || rawMode.contains("NSDefaultRunLoopMode") { return "default" }
        if rawMode.contains("NSEventTrackingRunLoopMode") { return "eventTracking" }
        if rawMode.contains("NSModalPanelRunLoopMode") { return "modalPanel" }
        return "other"
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

    private static func currentRawRunLoopMode() -> String? {
        CFRunLoopCopyCurrentMode(CFRunLoopGetMain()).map { String(describing: $0) }
    }

    private func appendLine(_ line: String) {
        buffer.append(line)
        recordCount += 1
        let capacity = max(bufferCapacity, 0)
        if buffer.count > capacity {
            let overflow = buffer.count - capacity
            buffer.removeFirst(overflow)
            droppedRecordCount += overflow
        }
        if buffer.count >= max(flushThreshold, 1) {
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

    private static func formatTimestamp(_ value: TimeInterval) -> String {
        String(format: "%.6f", value)
    }
}
