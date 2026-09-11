//
//  TelemetryArguments.swift
//  PagingTelemetry
//
//  telemetry 命令行参数解析（Docs/PHASE1_SPEC.md §5）：
//    --paging-telemetry      开启 telemetry（默认关闭）
//    --run-id <id>           指定 run ID（默认自动生成）
//
//  本模块只解析与 telemetry 相关的两个参数；其余参数（--page-count 等）
//  原样忽略，由 App 层（Worker D）负责解析。参数错误返回 .failure，
//  调用方应打印 helpText() 后继续正常启动，绝不崩溃。
//

import Foundation

/// telemetry 命令行参数解析与帮助文本。
public enum TelemetryArguments {

    /// 解析结果。
    public struct Options: Equatable, Sendable {
        /// `--paging-telemetry` 是否出现。
        public var telemetryEnabled: Bool
        /// `--run-id` 取值（未出现为 nil）。
        public var runID: String?

        public init(telemetryEnabled: Bool, runID: String?) {
            self.telemetryEnabled = telemetryEnabled
            self.runID = runID
        }

        /// 转换为 TelemetryConfiguration（runID 原样透传，nil 时 session 自动生成）。
        public func makeConfiguration() -> TelemetryConfiguration {
            TelemetryConfiguration(enabled: telemetryEnabled, runID: runID)
        }
    }

    /// 解析错误（均为可恢复错误：调用方打印帮助后继续正常启动）。
    public enum ParseError: Error, Equatable, Sendable {
        /// 参数缺少取值（如单独出现 `--run-id`，或取值是下一个参数）。
        case missingValue(String)
        /// run ID 取值为空字符串。
        case emptyRunID
    }

    /// 解析命令行参数（应传入完整 `CommandLine.arguments`）。
    ///
    /// - 识别：`--paging-telemetry`（无值）、`--run-id <value>`（空格分隔）。
    /// - 其他参数一律忽略（不属于本模块）。
    /// - `--run-id` 缺少取值或取值以 `--` 开头：返回 `.missingValue`。
    public static func parse(_ arguments: [String]) -> Result<Options, ParseError> {
        var enabled = false
        var runID: String?
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--paging-telemetry":
                enabled = true

            case "--run-id":
                guard index + 1 < arguments.count else {
                    return .failure(.missingValue(argument))
                }
                let value = arguments[index + 1]
                guard !value.isEmpty, !value.hasPrefix("--") else {
                    return .failure(.missingValue(argument))
                }
                runID = value
                index += 1 // 消费取值

            default:
                break // 其他参数不属于本模块，忽略
            }
            index += 1
        }

        if let runID, runID.isEmpty {
            return .failure(.emptyRunID)
        }
        return .success(Options(telemetryEnabled: enabled, runID: runID))
    }

    /// 帮助文本（供 App 层在参数错误或 --help 时打印；不崩溃）。
    public static func helpText() -> String {
        """
        PagingTelemetry 参数：
          --paging-telemetry      开启 telemetry（默认关闭）
          --run-id <id>           指定 run ID（默认自动生成；仅与 --paging-telemetry 配合使用）
        """
    }
}
