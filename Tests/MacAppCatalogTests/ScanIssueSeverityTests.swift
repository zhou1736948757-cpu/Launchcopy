import XCTest
@testable import MacAppCatalog

final class ScanIssueSeverityTests: XCTestCase {
    func testOnlyMissingBundleIdentifierIsNonBlocking() {
        for kind in ScanFailureKind.allCases {
            let report = ScanReport(appCount: 0, failureCounts: [kind: 2], scanDuration: 0)
            let expectedSoft = kind == .missingBundleIdentifier ? 2 : 0
            XCTAssertEqual(report.failureCount, 2, kind.rawValue)
            XCTAssertEqual(report.nonBlockingFailureCount, expectedSoft, kind.rawValue)
            XCTAssertEqual(report.discoveryFailureCount, 2 - expectedSoft, kind.rawValue)
            XCTAssertEqual(report.failureCounts, [kind: 2])
        }
    }

    func testMixedCountsPreserveAllAnonymousIssues() {
        let counts: [ScanFailureKind: Int] = [
            .missingBundleIdentifier: 7, .unreadableDirectory: 2, .corruptedBundle: 3,
            .invalidAppBundle: 4, .symlinkCycleDetected: 5,
        ]
        let report = ScanReport(appCount: 9, failureCounts: counts, scanDuration: 0.125)
        XCTAssertEqual(report.failureCount, 21)
        XCTAssertEqual(report.nonBlockingFailureCount, 7)
        XCTAssertEqual(report.discoveryFailureCount, 14)
        XCTAssertEqual(report.failureCounts, counts)
        XCTAssertEqual(report.appCount, 9)
        XCTAssertEqual(report.scanDuration, 0.125)
    }

    func testNegativeCategoriesCannotCancelGenuineDiscoveryFailures() {
        let counts: [ScanFailureKind: Int] = [
            .missingBundleIdentifier: 3, .unreadableDirectory: 2,
            .corruptedBundle: Int.min, .invalidAppBundle: -8,
        ]
        let report = ScanReport(appCount: 0, failureCounts: counts, scanDuration: 0)
        XCTAssertEqual(report.failureCount, 5)
        XCTAssertEqual(report.nonBlockingFailureCount, 3)
        XCTAssertEqual(report.discoveryFailureCount, 2)
        XCTAssertEqual(report.failureCounts, counts)

        let negativeSoft = ScanReport(appCount: 0,
            failureCounts: [.missingBundleIdentifier: Int.min, .unreadableDirectory: 2], scanDuration: 0)
        XCTAssertEqual(negativeSoft.failureCount, 2)
        XCTAssertEqual(negativeSoft.nonBlockingFailureCount, 0)
        XCTAssertEqual(negativeSoft.discoveryFailureCount, 2)
    }

    func testSaturatedTotalsReserveDiscoveryFailuresBeforeNonBlockingIssues() {
        let mixed = ScanReport(appCount: 0,
            failureCounts: [.missingBundleIdentifier: Int.max, .unreadableDirectory: 1], scanDuration: 0)
        XCTAssertEqual(mixed.failureCount, Int.max)
        XCTAssertEqual(mixed.nonBlockingFailureCount, Int.max - 1)
        XCTAssertEqual(mixed.discoveryFailureCount, 1)

        let hardOverflow = ScanReport(appCount: 0, failureCounts: [
            .missingBundleIdentifier: 1, .unreadableDirectory: Int.max, .invalidAppBundle: 1,
        ], scanDuration: 0)
        XCTAssertEqual(hardOverflow.failureCount, Int.max)
        XCTAssertEqual(hardOverflow.nonBlockingFailureCount, 0)
        XCTAssertEqual(hardOverflow.discoveryFailureCount, Int.max)

        let softOnly = ScanReport(appCount: 0, failureCounts: [.missingBundleIdentifier: Int.max], scanDuration: 0)
        XCTAssertEqual(softOnly.failureCount, Int.max)
        XCTAssertEqual(softOnly.nonBlockingFailureCount, Int.max)
        XCTAssertEqual(softOnly.discoveryFailureCount, 0)
    }

    func testEmptyAndNegativeOnlyReportsHaveNoClassifiedIssues() {
        let cases: [[ScanFailureKind: Int]] = [[:], [.missingBundleIdentifier: -1, .corruptedBundle: Int.min]]
        for counts in cases {
            let report = ScanReport(appCount: 0, failureCounts: counts, scanDuration: 0)
            XCTAssertEqual(report.failureCount, 0)
            XCTAssertEqual(report.nonBlockingFailureCount, 0)
            XCTAssertEqual(report.discoveryFailureCount, 0)
        }
    }
}
