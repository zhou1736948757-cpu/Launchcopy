//
//  PagingTelemetry.swift
//  PagingTelemetry
//
//  Phase 1A 分页原型 — 可开关 JSONL telemetry 模块。
//
//  需求来源：Docs/PHASE1_SPEC.md §5（命令行参数）与 §6（Telemetry 规格，17 字段）。
//  设计对齐：Docs/ADR-001-PAGING-STATE-MODEL.md（gesture/transition ID、中断、
//  stale completion 拒绝、teardown callback 计数的语义均与状态模型契约一致）。
//
//  来源类别：PRODUCT_DECISION / PUBLIC_DOCUMENTATION（Apple Foundation 公开 API）。
//  本模块不依赖 AppKit / Core Animation，可被任何层安全引用。
//

import Foundation

/// Telemetry 运行配置。
///
/// 默认全部关闭：`enabled == false` 时 session 的 begin/record/end 均为 no-op，
/// release 默认不产生任何日志文件。
public struct TelemetryConfiguration: Sendable, Equatable {

    /// 是否启用 telemetry（默认 `false`，对应 `--paging-telemetry` 未出现）。
    public var enabled: Bool

    /// 外部指定的 run ID（对应 `--run-id <id>`）；`nil` 时在 session 创建时自动生成。
    public var runID: String?

    /// 日志输出目录（默认系统临时目录 `/tmp`）。
    public var outputDirectory: URL

    /// 输出文件名前缀（固定为 `launch-copy-paging-prototype`；禁止 Buho 品牌前缀）。
    /// 最终文件名为 `<prefix>-<runID>.jsonl`。
    public var fileNamePrefix: String

    /// 每次 run 写入日志文件的**事件数上界**（Phase 1B 容量边界，Explorer C 建议 (a)；
    /// 默认 100,000）。达到上界后本 run 不再追加文件，后续事件转入有界内存环形缓冲
    /// （`TelemetrySession.memoryCapacity` = 10,000）并置 `fileCapacityReached`，
    /// 事件总数仍累计于 `recordedEventCount`。文件模式因此存在严格的每 run 容量上界，
    /// 不会无限增长（容量/保留边界文档见 Docs/PRIVACY_DATA_MAP.md）。
    public var maxFileEventsPerRun: Int

    public init(
        enabled: Bool = false,
        runID: String? = nil,
        outputDirectory: URL = TelemetryConfiguration.defaultOutputDirectory,
        fileNamePrefix: String = "launch-copy-paging-prototype",
        maxFileEventsPerRun: Int = 100_000
    ) {
        self.enabled = enabled
        self.runID = runID
        self.outputDirectory = outputDirectory
        self.fileNamePrefix = fileNamePrefix
        self.maxFileEventsPerRun = max(1, maxFileEventsPerRun)
    }

    /// 默认输出目录：`/tmp`（PHASE1_SPEC §6 规定日志路径为
    /// `/tmp/launch-copy-paging-prototype-<run-id>.jsonl`）。
    public static var defaultOutputDirectory: URL {
        URL(fileURLWithPath: "/tmp")
    }

    /// 把任意 run ID 净化为文件安全形式：
    /// 仅保留 `[A-Za-z0-9._-]`，其余字符替换为 `_`，总长上限 64；空结果回退为 `"run"`。
    /// 防止 `--run-id` 输入造成路径逃逸或不可读文件名。
    public static func sanitizedRunID(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        var scalars = String.UnicodeScalarView()
        for scalar in raw.unicodeScalars {
            scalars.append(allowed.contains(scalar) ? scalar : "_")
        }
        let sanitized = String(String(scalars).prefix(64))
        return sanitized.isEmpty ? "run" : sanitized
    }

    /// 自动生成 run ID：`yyyyMMdd-HHmmss-XXXX`（本地时间 + 4 位随机十六进制）。
    public static func generateRunID() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        let stamp = formatter.string(from: Date())
        let suffix = String(format: "%04X", UInt16.random(in: 0...0xFFFF))
        return "\(stamp)-\(suffix)"
    }
}

/// 模块门面：为 App 层（Worker D）提供最小接线入口。
///
/// 典型用法：
/// ```swift
/// let options = try? TelemetryArguments.parse(CommandLine.arguments).get()
/// let session = PagingTelemetry.makeSession(enabled: options?.telemetryEnabled ?? false,
///                                            runID: options?.runID)
/// session.begin()
/// // ... 记录事件 ...
/// session.end()
/// print("telemetry: \(session.logPathDescription)")
/// ```
public enum PagingTelemetry {

    /// 依据命令行参数创建一个 telemetry session（参数解析失败视为未开启，不崩溃）。
    public static func makeSession(arguments: [String] = CommandLine.arguments) -> TelemetrySession {
        let options = (try? TelemetryArguments.parse(arguments).get())
            ?? TelemetryArguments.Options(telemetryEnabled: false, runID: nil)
        return TelemetrySession(configuration: options.makeConfiguration())
    }

    /// 显式开关与 run ID 创建 session。
    public static func makeSession(enabled: Bool, runID: String?) -> TelemetrySession {
        TelemetrySession(configuration: TelemetryConfiguration(enabled: enabled, runID: runID))
    }
}
