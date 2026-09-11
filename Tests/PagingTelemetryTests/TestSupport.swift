//
//  TestSupport.swift
//  PagingTelemetryTests
//
//  共享测试工具：临时输出目录（不污染 /tmp 正式命名空间）与 17 字段清单。
//

import Foundation
import XCTest
@testable import PagingTelemetry

/// PHASE1_SPEC §6 规定的 17 个必需字段（JSON 键名）。
let requiredTelemetryKeys: Set<String> = [
    "run_id", "gesture_id", "transition_id", "event_phase", "timestamp",
    "input_delta", "visual_offset", "semantic_current_page", "proposed_target",
    "committed_page", "interruption_count", "stale_rejection_count",
    "frame_interval", "layout_count", "page_host_view_count",
    "page_prepare_cache", "teardown_callback_count",
]

/// 11 个可选扩展字段（4 个 Phase 1A + 7 个 Phase 1B；JSON 键名，全部 snake_case）。
let extensionTelemetryKeys: Set<String> = [
    "transition_token", "stale_callback_fired", "interrupt_source_offset", "reduce_motion_enabled",
    "snapshot_revision", "cell_reuse_count", "icon_async_state", "icon_cache_count",
    "icon_cache_estimated_cost", "catalog_scan_duration_ms", "refresh_duration_ms",
]

/// 全部合法 JSON 键（17 必需 + 11 扩展 = 28）。隐私红线测试以此断言编码键白名单：
/// 任何事件编码后不得出现白名单之外的键（潜在敏感承载）。
let allTelemetryKeys: Set<String> = requiredTelemetryKeys.union(extensionTelemetryKeys)

/// TelemetryEvent 全部存储属性名（冻结表面，对应 28 个 JSON 键）。
/// 隐私红线测试以此断言 Mirror 属性表面 == 白名单：新增任何属性（如 appName/bundleID/path）
/// 都会使本清单失配而测试失败。
let telemetryPropertyNames: Set<String> = [
    "runID", "gestureID", "transitionID", "phase", "timestamp", "inputDelta", "visualOffset",
    "semanticCurrentPage", "proposedTarget", "committedPage", "interruptionCount",
    "staleRejectionCount", "frameInterval", "layoutCount", "pageHostViewCount",
    "pagePrepareCache", "teardownCallbackCount", "transitionToken", "staleCallbackFired",
    "interruptSourceOffset", "reduceMotionEnabled", "snapshotRevision", "cellReuseCount",
    "iconAsyncState", "iconCacheCount", "iconCacheEstimatedCost", "catalogScanDurationMS",
    "refreshDurationMS",
]

/// 隐私红线哨兵（§3.1.14 / §3.2 / §3.3 / Explorer C）：
/// app 显示名 / bundle ID / 文件路径 / 图标数据 / 启动 URL 的代表性形式。
/// 任何 telemetry 序列化输出（JSONL 行、编码 JSON、description）都不得包含其中任一。
let privacySentinels: [String] = [
    "SekritApp",                                   // app 显示名
    "com.example.sekrit",                          // bundle identifier
    "/Users/mac/Applications/SekritApp.app",       // 绝对路径
    "SekritApp.app",                               // 相对路径 / 文件名
    "file:///Users/mac/Applications/SekritApp.app", // 启动 URL
    "iVBORw0KGgoAAAANSUhEUgAAAA==",               // 图标字节（base64 前缀）
    "89504E470D0A1A0A",                            // PNG magic（hex）
]

extension XCTestCase {

    /// 创建一次性临时输出目录（tests 专用，绝不对 /tmp 正式命名空间写入）。
    func makeTempOutputDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PagingTelemetryTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    /// 读取日志文件的全部行。
    func readLines(of url: URL) throws -> [String] {
        let data = try Data(contentsOf: url)
        let text = String(decoding: data, as: UTF8.self)
        return text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }

    /// 把一行 JSONL 解析为 JSON 字典；解析失败即 XCTFail。
    func jsonObject(fromLine lineText: String, file: StaticString = #filePath, line: UInt = #line) -> [String: Any] {
        guard let data = lineText.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            XCTFail("JSONL 行无法解析为 JSON 对象: \(lineText)", file: file, line: line)
            return [:]
        }
        return object
    }

    /// 断言一行 JSONL 包含全部 17 个必需字段。
    func assertRequiredFields(_ object: [String: Any], file: StaticString = #filePath, line: UInt = #line) {
        let missing = requiredTelemetryKeys.subtracting(object.keys)
        XCTAssertTrue(missing.isEmpty, "缺少必需字段: \(missing.sorted())", file: file, line: line)
    }
}
