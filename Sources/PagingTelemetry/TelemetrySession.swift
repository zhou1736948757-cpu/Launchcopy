//
//  TelemetrySession.swift
//  PagingTelemetry
//
//  一次 telemetry run 的会话：管理日志文件生命周期、会话级累计计数器与 JSONL 写入。
//
//  设计要点：
//  - 默认关闭：`TelemetryConfiguration.enabled == false` 时 begin/record/end 全部 no-op；
//  - 每次正式 run 独立日志文件：`<outputDirectory>/<prefix>-<runID>.jsonl`；
//  - 每 run 文件事件数有上界（`TelemetryConfiguration.maxFileEventsPerRun`，默认 100,000）：
//    达成后截断文件写入、转入有界内存环形缓冲（容量/保留边界，Phase 1B）；
//  - 线程安全：内部串行队列，主线程高频调用可接受；
//  - 防御：目录创建/文件打开/写入失败时降级为有界内存环形缓冲，绝不崩溃、绝不抛出。
//

import Foundation

/// 一次 telemetry run 的会话。
///
/// 典型生命周期：`init(configuration:) → begin() → record(...) → end()`。
/// `end()` 写入 run.end 事件并关闭文件；`begin()` 重复调用幂等。
public final class TelemetrySession {

    // MARK: - 公开状态

    /// 本次 run 的 ID（外部指定，或自动生成）。
    public let runID: String

    /// 日志文件 URL（未启用/未 begin/降级时可能为 nil）。
    public private(set) var fileURL: URL?

    /// 会话是否处于激活状态（begin 之后、end 之前）。
    public private(set) var isActive = false

    /// 已成功记录的事件数（含 run.begin / run.end）。
    public private(set) var recordedEventCount = 0

    /// 文件写入失败次数（含目录创建失败）。
    public private(set) var writeFailureCount = 0

    /// 是否已降级为内存模式（文件不可用）。
    public private(set) var degradedToMemory = false

    /// 本次 run 的文件事件数上界已达成（Phase 1B 容量边界）：不再追加文件，
    /// 后续事件转入有界内存缓冲；事件总数仍累计于 `recordedEventCount`。
    public private(set) var fileCapacityReached = false

    /// 会话累计中断次数（ADR-001 D4）。
    public private(set) var interruptionCount = 0

    /// 会话累计 stale completion 拒绝次数（ADR-001 D3）。
    public private(set) var staleRejectionCount = 0

    /// 会话累计布局次数。
    public private(set) var layoutCount = 0

    /// 会话累计 teardown callback 次数（ADR-001 D7）。
    public private(set) var teardownCallbackCount = 0

    /// 会话累计 cell/host 复用次数（Phase 1B；经 `registerCellReuse()` 递增，
    /// 盖章到后续事件的 `cellReuseCount` 扩展字段）。
    public private(set) var cellReuseCount = 0

    // MARK: - 内部状态

    private let configuration: TelemetryConfiguration
    private let queue = DispatchQueue(label: "launch-copy.paging-telemetry.session")
    private var handle: FileHandle?
    private var memoryEvents: [TelemetryEvent] = []
    private let memoryCapacity = 10_000

    // MARK: - 生命周期

    /// 以给定配置创建会话。run ID 在此时确定（指定值经净化，或自动生成）。
    public init(configuration: TelemetryConfiguration) {
        self.configuration = configuration
        if let raw = configuration.runID {
            self.runID = TelemetryConfiguration.sanitizedRunID(raw)
        } else {
            self.runID = TelemetryConfiguration.generateRunID()
        }
    }

    deinit {
        // 尽力关闭文件句柄；不执行记录（对象已销毁）。
        queue.sync { try? self.handle?.close() }
    }

    /// 开启本次 run：创建/打开日志文件并写入 run.begin 事件。
    /// - 未启用（enabled == false）或重复调用：no-op。
    public func begin() {
        queue.sync {
            guard !self.isActive else { return }
            guard self.configuration.enabled else { return }
            self.openFileLocked()
            self.isActive = true
            self.recordLocked(TelemetryEvent(phase: TelemetryPhase.runBegin))
        }
    }

    /// 记录一条事件（盖章 run ID、时间戳与四个累计计数后追加为一行 JSONL）。
    /// - 会话未激活：no-op。
    /// - 写入失败：降级为内存缓冲并累计 writeFailureCount，不抛出、不崩溃。
    public func record(_ event: TelemetryEvent) {
        queue.sync {
            guard self.isActive else { return }
            self.recordLocked(event)
        }
    }

    /// 结束本次 run：写入 run.end 事件、刷新并关闭文件。
    /// 重复调用幂等；未 begin 时 no-op。
    public func end() {
        queue.sync {
            guard self.isActive else { return }
            self.recordLocked(TelemetryEvent(phase: TelemetryPhase.runEnd))
            try? self.handle?.close()
            self.handle = nil
            self.isActive = false
        }
    }

    /// 尽力把未落盘的缓冲同步到磁盘（当前实现为直写，此调用主要为显式边界语义）。
    public func flush() {
        queue.sync {
            guard let handle else { return }
            try? handle.synchronize()
        }
    }

    // MARK: - 累计计数（写入时统一盖章到后续事件）

    /// 登记一次中断，返回递增后的累计值（ADR-001 D4）。
    @discardableResult
    public func registerInterruption() -> Int {
        queue.sync { self.interruptionCount += 1; return self.interruptionCount }
    }

    /// 登记一次 stale completion 拒绝，返回递增后的累计值（ADR-001 D3）。
    @discardableResult
    public func registerStaleRejection() -> Int {
        queue.sync { self.staleRejectionCount += 1; return self.staleRejectionCount }
    }

    /// 登记一次布局，返回递增后的累计值。
    @discardableResult
    public func registerLayout() -> Int {
        queue.sync { self.layoutCount += 1; return self.layoutCount }
    }

    /// 登记一次 teardown callback 执行，返回递增后的累计值（ADR-001 D7）。
    @discardableResult
    public func registerTeardownCallback() -> Int {
        queue.sync { self.teardownCallbackCount += 1; return self.teardownCallbackCount }
    }

    /// 登记一次 cell/host 复用（Phase 1B），返回递增后的累计值。
    ///
    /// 复用计数由 session 统一盖章到后续事件的 `cellReuseCount` 扩展字段
    /// （仅累计值 > 0 时盖章，保持可选字段缺省省略语义；事件显式值优先）。
    @discardableResult
    public func registerCellReuse() -> Int {
        queue.sync { self.cellReuseCount += 1; return self.cellReuseCount }
    }

    // MARK: - 诊断

    /// 内存降级模式下的缓冲事件快照（有界，仅诊断用）。
    public var memoryBufferEvents: [TelemetryEvent] {
        queue.sync { self.memoryEvents }
    }

    /// 日志路径的可读描述（供 App 层打印到 stdout）：
    /// 正常返回文件路径；降级返回 degraded 说明；容量上界达成返回截断说明；
    /// 未启用返回 "telemetry disabled"。
    public var logPathDescription: String {
        queue.sync {
            if self.fileCapacityReached {
                return "telemetry file-capacity-reached (\(self.configuration.maxFileEventsPerRun) events); continuing in bounded memory buffer"
            }
            if self.degradedToMemory { return "telemetry degraded-to-memory (no file; writeFailureCount=\(self.writeFailureCount))" }
            if let fileURL { return fileURL.path }
            if !self.configuration.enabled { return "telemetry disabled" }
            return "telemetry not started"
        }
    }

    // MARK: - 内部实现（须在 queue 内调用）

    private func openFileLocked() {
        let directory = configuration.outputDirectory
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileName = "\(configuration.fileNamePrefix)-\(runID).jsonl"
            let url = directory.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            let file = try FileHandle(forWritingTo: url)
            try file.seekToEnd()
            self.handle = file
            self.fileURL = url
        } catch {
            self.degradedToMemory = true
            self.writeFailureCount += 1
        }
    }

    private func recordLocked(_ event: TelemetryEvent) {
        var stamped = event
        stamped.runID = self.runID
        if stamped.timestamp == 0 {
            stamped.timestamp = Date().timeIntervalSince1970
        }
        stamped.interruptionCount = self.interruptionCount
        stamped.staleRejectionCount = self.staleRejectionCount
        stamped.layoutCount = self.layoutCount
        stamped.teardownCallbackCount = self.teardownCallbackCount
        // Phase 1B 可选计数：仅累计值 > 0 时盖章（nil = 缺省省略）；事件显式值优先。
        if stamped.cellReuseCount == nil, self.cellReuseCount > 0 {
            stamped.cellReuseCount = self.cellReuseCount
        }

        if let handle, !self.fileCapacityReached {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                var line = try encoder.encode(stamped)
                line.append(0x0A) // "\n"
                try handle.write(contentsOf: line)
                self.recordedEventCount += 1
                // Phase 1B 容量边界：达到每 run 文件事件数上界后截断，转入内存缓冲。
                if self.recordedEventCount >= self.configuration.maxFileEventsPerRun {
                    self.fileCapacityReached = true
                }
            } catch {
                self.writeFailureCount += 1
                self.degradedToMemory = true
                self.appendMemoryLocked(stamped)
            }
        } else {
            self.appendMemoryLocked(stamped)
        }
    }

    private func appendMemoryLocked(_ event: TelemetryEvent) {
        self.recordedEventCount += 1
        if self.memoryEvents.count >= self.memoryCapacity {
            self.memoryEvents.removeFirst()
        }
        self.memoryEvents.append(event)
    }
}
