//
//  TelemetryPrivacyRedLineTests.swift
//  PagingTelemetryTests
//
//  Phase 1B — 隐私红线断言（§3.1.14 / §3.2 / §3.3 / Explorer C / wave1-interfaces.md §G）：
//  app 显示名、bundle ID、文件路径、图标数据、启动 URL **任何形式**不得进入
//  telemetry 事件——包括扩展字段、description、key 派生。
//
//  四层冻结（任一被破坏即红：
//  ① 编码键白名单：任何事件的 JSON 键 ⊆ 28 键冻结集合（新增字段必改白名单，评审点）；
//  ② Mirror 属性表面 == 冻结属性名集合（新增属性如 appName/bundleID/path 立即失配）；
//  ③ 类型表面：无 URL / Data / 图像 / 字典 / 集合承载（杜绝 key 派生与字节夹带）；
//  ④ 敏感哨兵缺席：序列化 JSON、JSONL 行、String(describing:) 均不含任一哨兵。
//

import Foundation
import XCTest
@testable import PagingTelemetry

final class TelemetryPrivacyRedLineTests: XCTestCase {

    // MARK: - ① 编码键白名单

    func testEncodedKeysStayWithinFrozenWhitelist() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var event = TelemetryEvent(phase: TelemetryPhase.gestureBegan)
        // 全部 17 必需 + 11 扩展置非默认值
        event.gestureID = 1
        event.transitionID = 2
        event.inputDelta = 0.5
        event.visualOffset = 0.5
        event.semanticCurrentPage = 0
        event.proposedTarget = 1
        event.committedPage = 1
        event.frameInterval = 0.016
        event.pageHostViewCount = 2
        event.pagePrepareCache = .miss
        event.transitionToken = 99
        event.staleCallbackFired = true
        event.interruptSourceOffset = 0.25
        event.reduceMotionEnabled = true
        event.snapshotRevision = 42
        event.cellReuseCount = 7
        event.iconAsyncState = .staleRejected
        event.iconCacheCount = 128
        event.iconCacheEstimatedCost = 65_536
        event.catalogScanDurationMS = 123.4
        event.refreshDurationMS = 456.7

        let data = try encoder.encode(event)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        let extra = Set(object.keys).subtracting(allTelemetryKeys)
        XCTAssertTrue(extra.isEmpty, "出现白名单外 JSON 键（潜在敏感承载）: \(extra.sorted())")
        XCTAssertEqual(object.count, 28, "全字段事件应为 17 必需 + 11 扩展 = 28 键")
        XCTAssertEqual(Set(object.keys), allTelemetryKeys)
    }

    // MARK: - ② Mirror 属性表面 == 冻结属性名集合

    func testPropertySurfaceMatchesFrozenWhitelist() {
        let event = TelemetryEvent(phase: "p")
        let labels = Set(Mirror(reflecting: event).children.compactMap(\.label))
        XCTAssertEqual(labels, telemetryPropertyNames,
                       "属性表面失配：新增属性必须经隐私评审并显式加入白名单")
    }

    // MARK: - ③ 类型表面：无 URL / Data / 图像 / 键控集合承载

    func testNoFieldTypeCanCarryIdentityPayload() {
        let event = TelemetryEvent(phase: "p")
        for child in Mirror(reflecting: event).children {
            let typeName = String(reflecting: type(of: child.value))
            XCTAssertFalse(typeName.contains("URL"),
                           "属性 \(child.label ?? "?") 类型 \(typeName) 可承载 URL/路径")
            XCTAssertFalse(typeName.contains("Data"),
                           "属性 \(child.label ?? "?") 类型 \(typeName) 可承载字节")
            XCTAssertFalse(typeName.contains("Image"),
                           "属性 \(child.label ?? "?") 类型 \(typeName) 可承载图像")
            XCTAssertFalse(typeName.contains("Dictionary"),
                           "属性 \(child.label ?? "?") 类型 \(typeName) 可承载 key 派生集合（如 bundleID→key）")
            XCTAssertFalse(typeName.contains("Array"),
                           "属性 \(child.label ?? "?") 类型 \(typeName) 可承载集合")
            XCTAssertFalse(typeName.contains("Set<"),
                           "属性 \(child.label ?? "?") 类型 \(typeName) 可承载集合")
        }
    }

    func testOnlyStringFieldsAreRunIDAndPhase() {
        let event = TelemetryEvent(phase: "p")
        for child in Mirror(reflecting: event).children {
            let label = child.label ?? "?"
            if label == "runID" || label == "phase" { continue }
            let typeName = String(reflecting: type(of: child.value))
            XCTAssertFalse(typeName.contains("String"),
                           "非 runID/phase 属性 \(label) 类型 \(typeName) 为 String，可承载 app 名/ID 原文")
        }
    }

    // MARK: - ④ 敏感哨兵缺席

    func testSerializedJSONContainsNoPrivacySentinels() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var event = TelemetryEvent(phase: TelemetryPhase.frame)
        // 所有数值/枚举字段置“最可能夹带”的边界值
        event.gestureID = UInt64.max
        event.transitionID = UInt64.max
        event.inputDelta = 1e300
        event.visualOffset = -1e300
        event.semanticCurrentPage = Int.max
        event.proposedTarget = Int.min
        event.committedPage = Int.max
        event.frameInterval = 1e-9
        event.pageHostViewCount = Int.max
        event.pagePrepareCache = .hit
        event.transitionToken = UInt64.max
        event.staleCallbackFired = true
        event.interruptSourceOffset = 1e300
        event.reduceMotionEnabled = true
        event.snapshotRevision = Int.max
        event.cellReuseCount = Int.max
        event.iconAsyncState = .completed
        event.iconCacheCount = Int.max
        event.iconCacheEstimatedCost = Int.max
        event.catalogScanDurationMS = 1e300
        event.refreshDurationMS = 1e300

        let json = String(decoding: try encoder.encode(event), as: UTF8.self)
        for sentinel in privacySentinels {
            XCTAssertFalse(json.contains(sentinel),
                           "编码 JSON 泄露敏感哨兵: \(sentinel)\n\(json)")
        }
    }

    func testDescriptionContainsNoPrivacySentinels() {
        var event = TelemetryEvent(phase: TelemetryPhase.pageReuse)
        event.snapshotRevision = 42
        event.cellReuseCount = 7
        event.iconAsyncState = .staleRejected
        event.iconCacheCount = 128
        event.iconCacheEstimatedCost = 65_536
        event.catalogScanDurationMS = 123.4
        event.refreshDurationMS = 456.7

        let description = String(describing: event)
        for sentinel in privacySentinels {
            XCTAssertFalse(description.contains(sentinel),
                           "description 泄露敏感哨兵: \(sentinel)\n\(description)")
        }
    }

    func testFullRunJSONLLinesContainNoPrivacySentinels() throws {
        let dir = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: "privacy-run", outputDirectory: dir))

        session.begin()
        session.registerCellReuse()
        session.registerCellReuse()
        var event = TelemetryEvent(phase: TelemetryPhase.pageReuse)
        event.snapshotRevision = 5
        event.cellReuseCount = 2
        event.iconAsyncState = .completed
        event.iconCacheCount = 64
        event.iconCacheEstimatedCost = 32_768
        event.catalogScanDurationMS = 42.5
        event.refreshDurationMS = 8.25
        session.record(event)
        var failed = TelemetryEvent(phase: TelemetryPhase.pageCacheMiss)
        failed.iconAsyncState = .failed
        failed.iconCacheCount = 63
        session.record(failed)
        session.end()

        let fileURL = dir.appendingPathComponent("launch-copy-paging-prototype-privacy-run.jsonl")
        let lines = try readLines(of: fileURL)
        XCTAssertEqual(lines.count, 4, "run.begin + 2 事件 + run.end")

        for line in lines {
            let object = jsonObject(fromLine: line)
            let extra = Set(object.keys).subtracting(allTelemetryKeys)
            XCTAssertTrue(extra.isEmpty, "JSONL 行出现白名单外键: \(extra.sorted())")

            for sentinel in privacySentinels {
                XCTAssertFalse(line.contains(sentinel),
                               "JSONL 行泄露敏感哨兵: \(sentinel)\n\(line)")
            }
        }

        // 文件名为冻结前缀 + 净化 runID（无目录/身份派生内容）
        XCTAssertEqual(fileURL.lastPathComponent, "launch-copy-paging-prototype-privacy-run.jsonl")
    }

    // MARK: - 会话级红线：runID 路径逃逸早已净化（补一条 Phase 1B 哨兵版）

    func testPathLikeRunIDNeverWritesRawPathIntoFile() throws {
        let dir = try makeTempOutputDirectory()
        let rawPath = "/Users/mac/Applications/SekritApp.app"
        let session = TelemetrySession(configuration: TelemetryConfiguration(
            enabled: true, runID: rawPath, outputDirectory: dir))

        // sanitizedRunID 允许 [A-Za-z0-9._-]：斜杠被替换为 "_"，点号保留。
        XCTAssertEqual(session.runID, "_Users_mac_Applications_SekritApp.app")

        session.begin()
        session.end()

        let fileURL = dir.appendingPathComponent("launch-copy-paging-prototype-_Users_mac_Applications_SekritApp.app.jsonl")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        for line in try readLines(of: fileURL) {
            // 原始路径（含斜杠的完整形式）不得出现在任何行；run_id 为净化形式。
            XCTAssertFalse(line.contains(rawPath), "原始路径形式泄露: \(line)")
        }
        // 输出目录外无文件逃逸
        let parentContents = try FileManager.default.contentsOfDirectory(atPath: dir.deletingLastPathComponent().path)
            .filter { $0.contains("launch-copy-paging-prototype") }
        XCTAssertTrue(parentContents.isEmpty)
    }
}
