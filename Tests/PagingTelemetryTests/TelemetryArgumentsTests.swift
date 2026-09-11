//
//  TelemetryArgumentsTests.swift
//  PagingTelemetryTests
//
//  命令行参数解析（--paging-telemetry / --run-id）测试。
//

import XCTest
@testable import PagingTelemetry

final class TelemetryArgumentsTests: XCTestCase {

    func testNoArgumentsMeansDisabled() throws {
        let options = try TelemetryArguments.parse([]).get()
        XCTAssertFalse(options.telemetryEnabled)
        XCTAssertNil(options.runID)
    }

    func testTelemetryFlagEnables() throws {
        let options = try TelemetryArguments.parse(["--paging-telemetry"]).get()
        XCTAssertTrue(options.telemetryEnabled)
        XCTAssertNil(options.runID)
    }

    func testFlagWithRunID() throws {
        let options = try TelemetryArguments.parse(["--paging-telemetry", "--run-id", "abc123"]).get()
        XCTAssertTrue(options.telemetryEnabled)
        XCTAssertEqual(options.runID, "abc123")
    }

    func testRunIDWithoutFlagIsParsedButInert() throws {
        let options = try TelemetryArguments.parse(["--run-id", "solo"]).get()
        XCTAssertFalse(options.telemetryEnabled)
        XCTAssertEqual(options.runID, "solo")
    }

    func testUnrelatedArgumentsAreIgnored() throws {
        let options = try TelemetryArguments.parse([
            "--page-count", "10", "--items-per-page", "35",
            "--paging-telemetry", "--run-id", "run-42",
        ]).get()
        XCTAssertTrue(options.telemetryEnabled)
        XCTAssertEqual(options.runID, "run-42")
    }

    func testMissingRunIDValueFailsWithoutCrash() throws {
        let result = TelemetryArguments.parse(["--paging-telemetry", "--run-id"])
        guard case .failure(let error) = result else {
            return XCTFail("缺少取值应返回 .failure")
        }
        XCTAssertEqual(error, .missingValue("--run-id"))
    }

    func testRunIDValueThatLooksLikeFlagFailsWithoutCrash() throws {
        let result = TelemetryArguments.parse(["--run-id", "--paging-telemetry"])
        guard case .failure(let error) = result else {
            return XCTFail("取值以 -- 开头应返回 .failure")
        }
        XCTAssertEqual(error, .missingValue("--run-id"))
    }

    func testRunIDValueAfterFlagInMiddle() throws {
        let options = try TelemetryArguments.parse(["--run-id", "mid", "--paging-telemetry"]).get()
        XCTAssertTrue(options.telemetryEnabled)
        XCTAssertEqual(options.runID, "mid")
    }

    func testHelpTextIsNonEmptyAndDocumentsBothFlags() {
        let help = TelemetryArguments.helpText()
        XCTAssertFalse(help.isEmpty)
        XCTAssertTrue(help.contains("--paging-telemetry"))
        XCTAssertTrue(help.contains("--run-id"))
    }

    func testOptionsMakeConfiguration() throws {
        let options = try TelemetryArguments.parse(["--paging-telemetry", "--run-id", "cfg-run"]).get()
        let config = options.makeConfiguration()
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.runID, "cfg-run")
        XCTAssertEqual(config.fileNamePrefix, "launch-copy-paging-prototype")
    }

    func testFacadeSessionFromArguments() throws {
        // 模拟 App 层接线：带参数 → 启用
        let enabled = PagingTelemetry.makeSession(arguments: ["app", "--paging-telemetry", "--run-id", "facade"])
        XCTAssertEqual(enabled.runID, "facade")

        // 无参数 → 未启用（begin 不产生输出）
        let disabled = PagingTelemetry.makeSession(arguments: ["app"])
        disabled.begin()
        disabled.record(TelemetryEvent(phase: TelemetryPhase.gestureBegan))
        disabled.end()
        XCTAssertEqual(disabled.recordedEventCount, 0)
    }
}
