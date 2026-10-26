import AppCatalogCore
import AppGridUI
import Foundation
import XCTest
@testable import MacAppCatalog
@testable import PagingPrototypeApp

/// Real repository -> adapter -> refresh-controller wiring, with synthetic inputs only.
/// No assembly, windows, icons, production roots, or persistent settings are needed.
@MainActor
final class CatalogIssueSeverityAdapterTests: XCTestCase {
    func testEveryReportCategoryMapsThroughActualAdapterAndControllerIncludingZeroApps() async throws {
        for kind in ScanFailureKind.allCases {
            for appCount in [0, 1] {
                let records = makeRecords(count: appCount, fallback: kind == .missingBundleIdentifier)
                let scanner = SeverityReportScanner(responses: [.init(records: records, counts: [kind: 2])])
                let source = makeSource(scanner)
                defer { source.close(); scanner.close() }
                let controller = AppGridRefreshController(dataSource: source)
                let soft = kind == .missingBundleIdentifier ? 2 : 0
                let expected: AppGridUIState = soft == 0 ? .partialFailure : (appCount == 0 ? .empty : .ready)

                await refresh(controller, expected: expected, begin: true)

                XCTAssertEqual(controller.lastOutcome,
                    .init(succeeded: true, appCount: appCount, failureCount: 2, nonBlockingFailureCount: soft),
                    kind.rawValue)
                XCTAssertEqual(controller.lastOutcome?.discoveryFailureCount, 2 - soft, kind.rawValue)
                XCTAssertEqual(source.currentSnapshot?.records, records)
                XCTAssertEqual(controller.provider.pendingSnapshot, source.currentSnapshot)
                XCTAssertNil(controller.provider.servedSnapshot)
                XCTAssertNotNil(controller.applyPendingAtIdleBoundary(currentPage: 0))
                XCTAssertEqual(controller.provider.servedSnapshot?.records, records)
                if kind == .missingBundleIdentifier, let record = records.first {
                    XCTAssertNil(record.bundleIdentifier)
                    XCTAssertEqual(record.id, .canonicalURLFallback(record.canonicalURL))
                }
            }
        }
    }

    func testEveryHardCategoryKeepsMixedReportsPartialWithAndWithoutApps() async {
        for kind in ScanFailureKind.allCases where kind != .missingBundleIdentifier {
            for appCount in [0, 1] {
                let scanner = SeverityReportScanner(responses: [.init(
                    records: makeRecords(count: appCount, fallback: true),
                    counts: [.missingBundleIdentifier: 3, kind: 2])])
                let source = makeSource(scanner)
                defer { source.close(); scanner.close() }
                let controller = AppGridRefreshController(dataSource: source)

                await refresh(controller, expected: .partialFailure, begin: true)

                XCTAssertEqual(controller.lastOutcome,
                    .init(succeeded: true, appCount: appCount, failureCount: 5, nonBlockingFailureCount: 3),
                    kind.rawValue)
                XCTAssertEqual(controller.lastOutcome?.discoveryFailureCount, 2, kind.rawValue)
            }
        }
    }

    func testHealthyReportsResolveToReadyOrEmpty() async {
        for appCount in [0, 1] {
            let scanner = SeverityReportScanner(responses: [.init(records: makeRecords(count: appCount))])
            let source = makeSource(scanner)
            defer { source.close(); scanner.close() }
            let controller = AppGridRefreshController(dataSource: source)

            await refresh(controller, expected: appCount == 0 ? .empty : .ready, begin: true)

            XCTAssertEqual(controller.lastOutcome, .init(succeeded: true, appCount: appCount))
        }
    }

    func testMissingSyntheticRootRemainsADiscoveryFailureWithZeroApps() async {
        let missingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("catalog-severity-missing-\(UUID().uuidString)", isDirectory: true)
        let source = CatalogRepositoryDataSource(
            repository: CatalogRepository(policy: .init(), scanning: CatalogScanner()),
            configuration: ScanConfiguration(roots: [missingRoot]))
        defer { source.close() }
        let controller = AppGridRefreshController(dataSource: source)

        await refresh(controller, expected: .partialFailure, begin: true)

        XCTAssertEqual(controller.lastOutcome, .init(succeeded: true, failureCount: 1))
        XCTAssertEqual(controller.lastOutcome?.discoveryFailureCount, 1)
        XCTAssertEqual(source.currentSnapshot?.records.count, 0)
        XCTAssertEqual(controller.provider.pendingSnapshot?.records.count, 0)
    }

    func testWholeScanFailureRemainsPartialEvenWithNoIssuesOrOnlySoftIssues() async {
        let cases: [[ScanFailureKind: Int]] = [[:], [.missingBundleIdentifier: 3], [.unreadableDirectory: 1]]
        for counts in cases {
            let scanner = SeverityReportScanner(responses: [.init(counts: counts, producesSnapshot: false)])
            let source = makeSource(scanner)
            defer { source.close(); scanner.close() }
            let controller = AppGridRefreshController(dataSource: source)

            await refresh(controller, expected: .partialFailure, begin: true)

            XCTAssertEqual(controller.lastOutcome?.succeeded, false)
            XCTAssertEqual(controller.lastOutcome?.cancelled, false)
            XCTAssertEqual(controller.lastOutcome?.failureCount, counts.values.reduce(0, +))
            XCTAssertEqual(controller.lastOutcome?.nonBlockingFailureCount, counts[.missingBundleIdentifier] ?? 0)
            XCTAssertNil(source.currentSnapshot)
            XCTAssertNil(controller.provider.pendingSnapshot)
        }
    }

    func testAdapterNormalizesCategoryCountsWithoutHidingHardIssuesOrOverflowing() async {
        let cases: [(counts: [ScanFailureKind: Int], total: Int, soft: Int, hard: Int)] = [
            ([.missingBundleIdentifier: 3, .unreadableDirectory: 2, .corruptedBundle: Int.min], 5, 3, 2),
            ([.missingBundleIdentifier: Int.min, .invalidAppBundle: 2], 2, 0, 2),
            ([.missingBundleIdentifier: Int.max, .symlinkCycleDetected: 1], Int.max, Int.max - 1, 1),
            ([.unreadableDirectory: Int.max, .invalidAppBundle: 1], Int.max, 0, Int.max),
        ]
        for item in cases {
            let scanner = SeverityReportScanner(responses: [.init(counts: item.counts)])
            let source = makeSource(scanner)
            defer { source.close(); scanner.close() }

            let outcome = await source.refresh()

            XCTAssertTrue(outcome.succeeded)
            XCTAssertFalse(outcome.cancelled)
            XCTAssertEqual(outcome.failureCount, item.total)
            XCTAssertEqual(outcome.nonBlockingFailureCount, item.soft)
            XCTAssertEqual(outcome.discoveryFailureCount, item.hard)
        }
    }

    func testCancelledReportRetainsPriorStateAndSnapshotThenHealthyRefreshRecovers() async throws {
        let records = makeRecords(count: 1)
        let scanner = SeverityReportScanner(responses: [
            .init(records: records, counts: [.unreadableDirectory: 1]),
            .init(records: makeRecords(count: 2), counts: [.missingBundleIdentifier: 3, .invalidAppBundle: 2],
                  cancelled: true),
            .init(records: records),
        ])
        let source = makeSource(scanner)
        defer { source.close(); scanner.close() }
        let controller = AppGridRefreshController(dataSource: source)
        await refresh(controller, expected: .partialFailure, begin: true)
        XCTAssertNotNil(controller.applyPendingAtIdleBoundary(currentPage: 0))
        let accepted = try XCTUnwrap(source.currentSnapshot)

        await refresh(controller, expected: .partialFailure)

        XCTAssertEqual(controller.lastOutcome,
            .init(failureCount: 5, nonBlockingFailureCount: 3, cancelled: true))
        XCTAssertEqual(source.currentSnapshot, accepted)
        XCTAssertEqual(controller.provider.servedSnapshot, accepted)
        XCTAssertNil(controller.provider.pendingSnapshot)

        await refresh(controller, expected: .ready)

        XCTAssertEqual(controller.lastOutcome, .init(succeeded: true, appCount: 1))
        XCTAssertEqual(controller.provider.pendingRevision, 3)
        XCTAssertEqual(controller.provider.servedSnapshot, accepted)
        XCTAssertNotNil(controller.applyPendingAtIdleBoundary(currentPage: 0))
        XCTAssertEqual(controller.provider.servedRevision, 3)
    }

    func testObsoleteConfigurationCannotPublishSeverityOrSnapshotAndNextRefreshRecovers() async throws {
        let started = expectation(description: "old configuration scan held")
        let scanner = SeverityReportScanner(responses: [
            .init(records: makeRecords(count: 1), counts: [.missingBundleIdentifier: 9, .unreadableDirectory: 2],
                  held: true, started: started),
            .init(records: makeRecords(count: 1)),
        ])
        let source = makeSource(scanner)
        defer { source.close(); scanner.close() }
        let request = Task { await source.refresh() }
        defer { request.cancel() }
        try await requireHeld(started, scanner: scanner, index: 0)
        source.invalidateRequests()
        scanner.finish(0)

        let rejected = await request.value

        XCTAssertEqual(rejected, .init(cancelled: true))
        XCTAssertNil(source.currentSnapshot)
        XCTAssertEqual(source.refreshTimings, .init())
        let recovered = await source.refresh()
        XCTAssertEqual(recovered, .init(succeeded: true, appCount: 1))
        XCTAssertEqual(source.currentSnapshot?.revision, CatalogRevision(2))
    }

    func testLatestAcceptedRefreshRetainsItsSnapshotWhenSupersededSeverityArrivesLate() async throws {
        let firstStarted = expectation(description: "first scan held")
        let latestStarted = expectation(description: "latest scan held")
        let scanner = SeverityReportScanner(responses: [
            .init(records: makeRecords(count: 1), counts: [.unreadableDirectory: 2],
                  held: true, started: firstStarted),
            .init(records: makeRecords(count: 2, fallback: true), counts: [.missingBundleIdentifier: 2],
                  held: true, started: latestStarted),
        ])
        let source = makeSource(scanner)
        defer { source.close(); scanner.close() }
        let first = Task { await source.refresh() }
        defer { first.cancel() }
        try await requireHeld(firstStarted, scanner: scanner, index: 0)
        let latest = Task { await source.refresh() }
        defer { latest.cancel() }
        try await requireHeld(latestStarted, scanner: scanner, index: 1)

        scanner.finish(1)
        let accepted = await latest.value
        let snapshot = try XCTUnwrap(source.currentSnapshot)
        XCTAssertEqual(accepted,
            .init(succeeded: true, appCount: 2, failureCount: 2, nonBlockingFailureCount: 2))
        XCTAssertEqual(snapshot.revision, CatalogRevision(2))

        scanner.finish(0)
        let superseded = await first.value
        XCTAssertEqual(superseded, .init(failureCount: 2, cancelled: true))
        XCTAssertEqual(source.currentSnapshot, snapshot)
    }

    private func makeSource(_ scanner: SeverityReportScanner) -> CatalogRepositoryDataSource {
        CatalogRepositoryDataSource(repository: CatalogRepository(policy: .init(), scanning: scanner),
                                    configuration: ScanConfiguration(roots: []))
    }

    private func makeRecords(count: Int, fallback: Bool = false) -> [AppRecord] {
        (0..<count).map { index in
            let bundleID = "fixture.severity.\(index)"
            let url = CatalogFixture.tempURL(named: "severity-\(index).app")
            let id = fallback ? AppID.canonicalURLFallback(url) : CatalogFixture.appID(bundleID)
            return CatalogFixture.record(id: id, displayName: "Synthetic \(index)",
                bundleID: fallback ? nil : bundleID, url: url, icon: .from(appID: id), rootPriority: 0)
        }
    }

    private func refresh(_ controller: AppGridRefreshController, expected: AppGridUIState,
                         begin: Bool = false) async {
        let settled = expectation(description: "adapter refresh settled at \(expected)")
        controller.onStateChange = { state in
            if state == expected { settled.fulfill() }
        }
        defer { controller.onStateChange = nil }
        if begin { controller.begin() } else { controller.refreshNow() }
        await fulfillment(of: [settled], timeout: 3)
        XCTAssertEqual(controller.state, expected)
    }

    private func requireHeld(_ started: XCTestExpectation, scanner: SeverityReportScanner,
                             index: Int) async throws {
        await fulfillment(of: [started], timeout: 3)
        guard scanner.isHeld(index) else { throw SeverityReportWaitError.notStarted }
    }
}

private enum SeverityReportWaitError: Error { case notStarted }

private struct SeverityReportResponse {
    var records: [AppRecord] = []
    var counts: [ScanFailureKind: Int] = [:]
    var producesSnapshot = true
    var cancelled = false
    var held = false
    var started: XCTestExpectation?
}

/// Held callbacks can deliberately succeed after cancellation to exercise consumer fences.
/// Every callback is completed once, outside the lock; close also rejects late registrations.
private final class SeverityReportScanner: CatalogScanning, @unchecked Sendable {
    private struct Pending {
        let response: SeverityReportResponse
        let revision: CatalogRevision
        let task: ScanTask
        let completion: @Sendable (CatalogScanResult) -> Void

        func finish() {
            let snapshot = response.producesSnapshot && !response.cancelled
                ? CatalogSnapshot(revision: revision, records: response.records) : nil
            completion(.init(snapshot: snapshot,
                report: .init(appCount: response.records.count, failureCounts: response.counts, scanDuration: 0.125),
                cancelled: response.cancelled))
        }
    }

    private let lock = NSLock()
    private let responses: [SeverityReportResponse]
    private var nextIndex = 0
    private var pending: [Int: Pending] = [:]
    private var closed = false

    init(responses: [SeverityReportResponse]) { self.responses = responses }

    func scan(configuration: ScanConfiguration, revision: CatalogRevision,
              completion: @escaping @Sendable (CatalogScanResult) -> Void) -> ScanTask {
        let task = ScanTask()
        lock.lock()
        let index = nextIndex
        nextIndex += 1
        let response = !closed && index < responses.count ? responses[index] : nil
        let entry = response.map { Pending(response: $0, revision: revision, task: task, completion: completion) }
        if response?.held == true { pending[index] = entry }
        lock.unlock()
        guard let response, let entry else {
            task.cancel()
            completion(Self.cancelledResult)
            return task
        }
        response.started?.fulfill()
        if !response.held { entry.finish() }
        return task
    }

    func isHeld(_ index: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return pending[index] != nil
    }

    func finish(_ index: Int) {
        lock.lock()
        let entry = pending.removeValue(forKey: index)
        lock.unlock()
        XCTAssertNotNil(entry, "The scan must be held before completion")
        entry?.finish()
    }

    func close() {
        lock.lock()
        closed = true
        let entries = Array(pending.values)
        pending.removeAll()
        lock.unlock()
        for entry in entries {
            entry.task.cancel()
            entry.completion(Self.cancelledResult)
        }
    }

    private static var cancelledResult: CatalogScanResult {
        .init(snapshot: nil, report: .init(appCount: 0, failureCounts: [:], scanDuration: 0), cancelled: true)
    }
}
