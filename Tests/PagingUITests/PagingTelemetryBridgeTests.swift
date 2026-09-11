//
//  PagingTelemetryBridgeTests.swift
//  PagingUITests
//
//  telemetry 最终接线验证（T-worker-d 责任）：
//  - 开启时：手势/transition/布局/teardown 事件写入独立 JSONL 文件；
//  - run ID 透传；teardown 后写 teardown.complete 且 teardownCallbackCount 恒为 0（D7）。
//

import AppKit
import XCTest
@testable import PagingPrototypeApp
@testable import PagingTelemetry
@testable import PagingUI

final class PagingTelemetryBridgeTests: XCTestCase {

    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("paging-ui-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testBridgeRecordsEventsToFileAndTeardownComplete() throws {
        let surface = PagingSurface(pageCount: 5, itemsPerPage: 8)
        surface.frameDriver = nil
        surface.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
        surface.layout()

        let configuration = TelemetryConfiguration(
            enabled: true,
            runID: "bridge-test-001",
            outputDirectory: tempDirectory
        )
        let session = TelemetrySession(configuration: configuration)
        session.begin()
        // 强引用保持 bridge 存活（闭包弱引用 bridge；同 AppDelegate 持有方式）。
        let bridge = PagingTelemetryBridge(surface: surface, session: session)
        XCTAssertNotNil(bridge)

        // 一次完整手势 + settle + teardown。
        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 600, at: 0.5)
        gestureEnded(surface, at: 0.5)
        finishPendingGesture(surface, at: 0.5)
        settleFrames(surface)
        surface.teardown()

        // 文件存在、run ID 正确、事件已写入、teardown 后计数冻结。
        let url = tempDirectory.appendingPathComponent("launch-copy-paging-prototype-bridge-test-001.jsonl")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(session.runID, "bridge-test-001")
        XCTAssertGreaterThanOrEqual(session.recordedEventCount, 6) // begin+end+手势+transition+commit+teardown
        XCTAssertEqual(session.teardownCallbackCount, 0, "D7：teardown 后零回调")

        // 抽查日志内容：含 teardown.complete 与 transition.commit。
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(content.contains("teardown.complete"))
        XCTAssertTrue(content.contains("transition.commit"))
        XCTAssertTrue(content.contains("\"run_id\":\"bridge-test-001\""))
    }

    func testBridgeDisabledIsNoOp() {
        let surface = PagingSurface(pageCount: 5, itemsPerPage: 8)
        surface.frameDriver = nil
        surface.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
        surface.layout()

        let session = TelemetrySession(configuration: TelemetryConfiguration(enabled: false))
        session.begin()
        _ = PagingTelemetryBridge(surface: surface, session: session)

        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 600, at: 0.5)
        gestureEnded(surface, at: 0.5)
        finishPendingGesture(surface, at: 0.5)
        settleFrames(surface)
        surface.teardown()

        XCTAssertEqual(session.recordedEventCount, 0, "默认关闭：不产生日志")
        XCTAssertEqual(session.logPathDescription, "telemetry disabled")
    }
}
