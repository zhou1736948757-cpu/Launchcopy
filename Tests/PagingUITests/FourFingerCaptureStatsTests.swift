//
//  FourFingerCaptureStatsTests.swift
//  PagingUITests
//
//  Phase 1G T-G-P6：采集工具统计逻辑（每场景帧数、触点计数分布、
//  会话数 began→ended/cancelled/零触点 moved 闭合序列、场景独立）。
//

import XCTest
@testable import PagingPrototypeApp

final class FourFingerCaptureStatsTests: XCTestCase {

    private let device = PinchDeviceID(rawValue: 1)

    private func frame(_ phase: PinchFramePhase, contacts: Int,
                       deviceID: PinchDeviceID? = nil) -> PinchFrame {
        PinchFrame(deviceID: deviceID ?? device, timestamp: 0, phase: phase,
                   contacts: (0..<contacts).map {
                       PinchContact(id: PinchContactID(rawValue: $0),
                                    position: PinchPoint(x: 0.1 * Double($0), y: 0.1))
                   })
    }

    func testPerScenarioFrameCounts() {
        var stats = FourFingerCaptureStats()
        stats.record(frame(.began, contacts: 4), scenario: "slow-pinch")
        stats.record(frame(.moved, contacts: 4), scenario: "slow-pinch")
        stats.record(frame(.ended, contacts: 0), scenario: "slow-pinch")
        stats.record(frame(.began, contacts: 4), scenario: "fast-pinch")
        XCTAssertEqual(stats.scenarios["slow-pinch"]?.frameCount, 3)
        XCTAssertEqual(stats.scenarios["fast-pinch"]?.frameCount, 1)
    }

    func testContactCountDistribution() {
        var stats = FourFingerCaptureStats()
        stats.record(frame(.began, contacts: 4), scenario: "s")
        stats.record(frame(.moved, contacts: 4), scenario: "s")
        stats.record(frame(.moved, contacts: 3), scenario: "s")
        stats.record(frame(.ended, contacts: 0), scenario: "s")
        let dist = stats.scenarios["s"]?.contactCountDistribution
        XCTAssertEqual(dist?[4], 2)
        XCTAssertEqual(dist?[3], 1)
        XCTAssertEqual(dist?[0], 1)
    }

    func testSessionCountBeganEnded() {
        var stats = FourFingerCaptureStats()
        stats.record(frame(.began, contacts: 4), scenario: "s")
        stats.record(frame(.moved, contacts: 4), scenario: "s")
        stats.record(frame(.ended, contacts: 0), scenario: "s")
        stats.record(frame(.began, contacts: 4), scenario: "s")
        stats.record(frame(.ended, contacts: 0), scenario: "s")
        XCTAssertEqual(stats.scenarios["s"]?.sessionCount, 2)
        XCTAssertEqual(stats.scenarios["s"]?.beganCount, 2)
        XCTAssertEqual(stats.scenarios["s"]?.endedCount, 2)
    }

    func testSessionCountCancelled() {
        var stats = FourFingerCaptureStats()
        stats.record(frame(.began, contacts: 4), scenario: "s")
        stats.record(frame(.cancelled, contacts: 0), scenario: "s")
        XCTAssertEqual(stats.scenarios["s"]?.sessionCount, 1)
        XCTAssertEqual(stats.scenarios["s"]?.cancelledCount, 1)
    }

    func testSessionCountZeroContactMovedIsEndEvidence() {
        var stats = FourFingerCaptureStats()
        stats.record(frame(.began, contacts: 4), scenario: "s")
        stats.record(frame(.moved, contacts: 0), scenario: "s")
        XCTAssertEqual(stats.scenarios["s"]?.sessionCount, 1)
    }

    func testOpenSessionNotCountedUntilClosed() {
        var stats = FourFingerCaptureStats()
        stats.record(frame(.began, contacts: 4), scenario: "s")
        XCTAssertEqual(stats.scenarios["s"]?.sessionCount, 0, "未闭合会话不计")
    }

    func testScenariosIndependent() {
        var stats = FourFingerCaptureStats()
        stats.record(frame(.began, contacts: 4), scenario: "slow-pinch")
        stats.record(frame(.began, contacts: 4), scenario: "fast-pinch")
        stats.record(frame(.ended, contacts: 0), scenario: "slow-pinch")
        XCTAssertEqual(stats.scenarios["slow-pinch"]?.sessionCount, 1)
        XCTAssertEqual(stats.scenarios["fast-pinch"]?.sessionCount, 0)
        XCTAssertEqual(stats.scenarioNames, ["fast-pinch", "slow-pinch"])
    }

    func testSummaryFormat() {
        var stats = FourFingerCaptureStats()
        stats.record(frame(.began, contacts: 4), scenario: "slow-pinch")
        stats.record(frame(.ended, contacts: 0), scenario: "slow-pinch")
        let summary = stats.summary(for: "slow-pinch")
        XCTAssertTrue(summary.contains("scenario=slow-pinch"))
        XCTAssertTrue(summary.contains("frames=2"))
        XCTAssertTrue(summary.contains("sessions=1"))
        XCTAssertTrue(summary.contains("began=1"))
        XCTAssertTrue(summary.contains("ended=1"))
    }
}
