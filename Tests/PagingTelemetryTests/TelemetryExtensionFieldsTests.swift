//
//  TelemetryExtensionFieldsTests.swift
//  PagingTelemetryTests
//
//  Phase 1B — 7 个可选扩展字段（snapshot_revision / cell_reuse_count /
//  icon_async_state / icon_cache_count / icon_cache_estimated_cost /
//  catalog_scan_duration_ms / refresh_duration_ms）的编码、缺省省略、边界与
//  会话盖章测试；以及每 run 文件容量上界测试。
//
//  红线（app 名/bundle ID/路径/图标数据/启动 URL 禁入）见
//  TelemetryPrivacyRedLineTests.swift，本文件只验证字段契约本身。
//

import Foundation
import XCTest
@testable import PagingTelemetry

final class TelemetryExtensionFieldsTests: XCTestCase {

    // MARK: - IconAsyncState 原始值（JSON 键即 rawValue，snake_case 稳定）

    func testIconAsyncStateRawValuesAreStableSnakeCase() {
        XCTAssertEqual(IconAsyncState.idle.rawValue, "idle")
        XCTAssertEqual(IconAsyncState.inflight.rawValue, "inflight")
        XCTAssertEqual(IconAsyncState.completed.rawValue, "completed")
        XCTAssertEqual(IconAsyncState.failed.rawValue, "failed")
        XCTAssertEqual(IconAsyncState.cancelled.rawValue, "cancelled")
        XCTAssertEqual(IconAsyncState.staleRejected.rawValue, "stale_rejected")
        XCTAssertEqual(IconAsyncState.allCases.count, 6, "状态集合冻结为 6 个，新增状态必须显式评审")
    }

    func testIconAsyncStateRoundTripsThroughJSON() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for state in IconAsyncState.allCases {
            let data = try encoder.encode(state)
            XCTAssertEqual(String(decoding: data, as: UTF8.self), "\"\(state.rawValue)\"")
            XCTAssertEqual(try decoder.decode(IconAsyncState.self, from: data), state)
        }
    }

    func testIconAsyncStateUnknownRawValueFailsDecode() {
        // 未知状态必须解码失败（严格 schema：不静默接受未来意外值，红线回归可发现）。
        XCTAssertThrowsError(try JSONDecoder().decode(IconAsyncState.self, from: Data("\"launched\"".utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(IconAsyncState.self, from: Data("\"stale-rejected\"".utf8)))
    }

    // MARK: - 编码：snake_case 键名 + 值正确

    func testExtensionFieldsEncodeWithStableSnakeCaseKeys() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var event = TelemetryEvent(phase: TelemetryPhase.pageReuse)
        event.snapshotRevision = 42
        event.cellReuseCount = 7
        event.iconAsyncState = .inflight
        event.iconCacheCount = 128
        event.iconCacheEstimatedCost = 65_536
        event.catalogScanDurationMS = 123.4
        event.refreshDurationMS = 456.7

        let data = try encoder.encode(event)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["snapshot_revision"] as? Int, 42)
        XCTAssertEqual(object["cell_reuse_count"] as? Int, 7)
        XCTAssertEqual(object["icon_async_state"] as? String, "inflight")
        XCTAssertEqual(object["icon_cache_count"] as? Int, 128)
        XCTAssertEqual(object["icon_cache_estimated_cost"] as? Int, 65_536)
        XCTAssertEqual(object["catalog_scan_duration_ms"] as? Double, 123.4)
        XCTAssertEqual(object["refresh_duration_ms"] as? Double, 456.7)

        // 键名 snake_case（无大写），且 17 必需字段不受影响
        for key in extensionTelemetryKeys {
            XCTAssertFalse(key.contains(where: { $0.isUppercase }), "扩展键应为 snake_case: \(key)")
        }
        XCTAssertTrue(requiredTelemetryKeys.isSubset(of: object.keys))
    }

    // MARK: - 缺省省略：nil 时键不出现

    func testNewExtensionFieldsAreOmittedWhenNil() throws {
        let data = try JSONEncoder().encode(TelemetryEvent(phase: TelemetryPhase.frame))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["snapshot_revision", "cell_reuse_count", "icon_async_state",
                    "icon_cache_count", "icon_cache_estimated_cost",
                    "catalog_scan_duration_ms", "refresh_duration_ms"] {
            XCTAssertNil(object[key], "\(key) 缺省应省略（可选字段仅在设置时编码）")
        }
        // 既有 4 个 Phase 1A 扩展同样省略（契约未回归）
        for key in ["transition_token", "stale_callback_fired",
                    "interrupt_source_offset", "reduce_motion_enabled"] {
            XCTAssertNil(object[key])
        }
    }

    // MARK: - 往返解码

    func testExtensionFieldsRoundTripWithDecoder() throws {
        var event = TelemetryEvent(phase: TelemetryPhase.pageCacheMiss)
        event.snapshotRevision = 9
        event.cellReuseCount = 3
        event.iconAsyncState = .staleRejected
        event.iconCacheCount = 0
        event.iconCacheEstimatedCost = 0
        event.catalogScanDurationMS = 0.5
        event.refreshDurationMS = -1 // Double 无界；负值作为“未知”哨兵无损往返

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(TelemetryEvent.self, from: data)
        XCTAssertEqual(decoded, event)
        XCTAssertEqual(decoded.iconAsyncState, .staleRejected)
        XCTAssertEqual(decoded.snapshotRevision, 9)
        XCTAssertEqual(decoded.refreshDurationMS, -1)
    }

    // MARK: - 边界值

    func testExtensionNumericBoundariesEncode() throws {
        let encoder = JSONEncoder()
        var event = TelemetryEvent(phase: TelemetryPhase.frame)
        event.snapshotRevision = .max
        event.cellReuseCount = 0 // 显式 0 是合法计数，必须编码（与缺省省略区分）
        event.iconCacheCount = .max
        event.iconCacheEstimatedCost = 0
        event.catalogScanDurationMS = 1e300
        event.refreshDurationMS = 1e-9

        let data = try encoder.encode(event)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["snapshot_revision"] as? Int, Int.max)
        XCTAssertEqual(object["cell_reuse_count"] as? Int, 0)
        XCTAssertEqual(object["icon_cache_count"] as? Int, Int.max)
        XCTAssertEqual(object["icon_cache_estimated_cost"] as? Int, 0)
        XCTAssertEqual(object["catalog_scan_duration_ms"] as? Double, 1e300)
        XCTAssertEqual(object["refresh_duration_ms"] as? Double, 1e-9)
    }

    func testNegativeSnapshotRevisionIsPassedThroughLosslessly() throws {
        // snapshot_revision 契约上单调递增，但 schema 不禁止调用方显式传值；
        // 编码层必须无损透传（边界防御：绝不因“不合法”改写或丢弃数据）。
        var event = TelemetryEvent(phase: TelemetryPhase.stateChanged)
        event.snapshotRevision = -1
        let data = try JSONEncoder().encode(event)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["snapshot_revision"] as? Int, -1)
    }

    // MARK: - 会话盖章：cellReuseCount（复用 register* 模式）

    func testRegisterCellReuseStampsIntoSubsequentEvents() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "reuse-stamp", outputDirectory: dir))

        session.begin()
        session.record(TelemetryEvent(phase: TelemetryPhase.pagePrepare)) // 复用登记前：省略
        XCTAssertEqual(session.registerCellReuse(), 1)
        XCTAssertEqual(session.registerCellReuse(), 2)
        session.record(TelemetryEvent(phase: TelemetryPhase.pageReuse))
        session.end()

        let fileURL = dir.appendingPathComponent("launch-copy-paging-prototype-reuse-stamp.jsonl")
        let lines = try readLines(of: fileURL)
        XCTAssertEqual(lines.count, 4)

        let before = jsonObject(fromLine: lines[1])
        XCTAssertNil(before["cell_reuse_count"], "未登记复用时扩展字段应省略")

        let after = jsonObject(fromLine: lines[2])
        XCTAssertEqual(after["cell_reuse_count"] as? Int, 2)

        let endEvent = jsonObject(fromLine: lines[3])
        XCTAssertEqual(endEvent["cell_reuse_count"] as? Int, 2, "run.end 也应携带当前累计值")
    }

    func testExplicitEventCellReuseCountWinsOverSessionStamp() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "reuse-explicit", outputDirectory: dir))

        session.begin()
        XCTAssertEqual(session.registerCellReuse(), 1)
        var event = TelemetryEvent(phase: TelemetryPhase.pageReuse)
        event.cellReuseCount = 999 // 事件显式值优先
        session.record(event)
        session.end()

        let fileURL = dir.appendingPathComponent("launch-copy-paging-prototype-reuse-explicit.jsonl")
        let lines = try readLines(of: fileURL)
        XCTAssertEqual(jsonObject(fromLine: lines[1])["cell_reuse_count"] as? Int, 999)
    }

    func testNoReuseRegisteredOmitsCellReuseCountEverywhere() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "reuse-none", outputDirectory: dir))

        session.begin()
        session.record(TelemetryEvent(phase: TelemetryPhase.pagePrepare))
        session.end()

        let fileURL = dir.appendingPathComponent("launch-copy-paging-prototype-reuse-none.jsonl")
        for line in try readLines(of: fileURL) {
            XCTAssertNil(jsonObject(fromLine: line)["cell_reuse_count"], "从未登记复用时整 run 不得出现该键")
        }
    }

    // MARK: - 每 run 文件容量上界（Phase 1B 容量边界）

    func testFileCapacityBoundTruncatesToMemory() throws {
        let dir = try makeTempOutputDirectory()
        let cap = 120
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "cap", outputDirectory: dir, maxFileEventsPerRun: cap))

        session.begin()
        for _ in 0..<200 {
            session.record(TelemetryEvent(phase: TelemetryPhase.frame))
        }
        session.end()

        XCTAssertTrue(session.fileCapacityReached)
        XCTAssertFalse(session.degradedToMemory, "容量截断不是写失败，不应置 degradedToMemory")
        XCTAssertEqual(session.writeFailureCount, 0)
        XCTAssertEqual(session.recordedEventCount, 202, "事件总数仍完整累计（200 + begin + end）")
        XCTAssertEqual(session.memoryBufferEvents.count, session.recordedEventCount - cap,
                       "溢出部分转入有界内存缓冲")
        XCTAssertTrue(session.logPathDescription.contains("file-capacity-reached"))
        XCTAssertNotNil(session.fileURL, "容量达成后文件仍存在（此前已写入的内容保留）")

        let fileURL = dir.appendingPathComponent("launch-copy-paging-prototype-cap.jsonl")
        let lines = try readLines(of: fileURL)
        XCTAssertEqual(lines.count, cap, "文件恰含上界条事件：run.begin + 119 帧（run.end 已转入内存缓冲）")

        // 文件内每条仍携带全部 17 必需字段（截断不破坏契约）
        for line in lines {
            assertRequiredFields(jsonObject(fromLine: line))
        }
    }

    func testFileCapacityBoundNotReachedInNormalRun() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "cap-ok", outputDirectory: dir, maxFileEventsPerRun: 100_000))

        session.begin()
        session.record(TelemetryEvent(phase: TelemetryPhase.frame))
        session.end()

        XCTAssertFalse(session.fileCapacityReached)
        XCTAssertNil(session.memoryBufferEvents.first)
        let fileURL = dir.appendingPathComponent("launch-copy-paging-prototype-cap-ok.jsonl")
        XCTAssertEqual(try readLines(of: fileURL).count, 3)
    }
}
