import AppCatalogCore
import AppGridUI
import Foundation
import XCTest

/// Exercises the real refresh controller with held, synthetic data-source completions.
@MainActor
final class CatalogIssueSeverityTests: XCTestCase {
    func testLegacyOutcomeCountsEveryIssueAsDiscoveryFailureByDefault() {
        let outcome = AppGridRefreshOutcome(succeeded: true, appCount: 1, failureCount: 3)
        XCTAssertEqual(outcome.failureCount, 3)
        XCTAssertEqual(outcome.nonBlockingFailureCount, 0)
        XCTAssertEqual(outcome.discoveryFailureCount, 3)
        XCTAssertEqual(AppGridRefreshOutcome(cancelled: true).nonBlockingFailureCount, 0)
    }

    func testOutcomeNormalizesAndBoundsClassificationWithoutSubtractingFromTotal() {
        let cases: [(total: Int, soft: Int, expectedTotal: Int, expectedSoft: Int)] = [
            (5, 2, 5, 2), (5, -1, 5, 0), (5, 9, 5, 5),
            (0, 9, 0, 0), (-1, 1, 0, 0), (Int.min, Int.min, 0, 0),
            (Int.max, Int.max, Int.max, Int.max), (Int.max, Int.min, Int.max, 0),
        ]
        for item in cases {
            let outcome = AppGridRefreshOutcome(failureCount: item.total,
                                               nonBlockingFailureCount: item.soft)
            XCTAssertEqual(outcome.failureCount, item.expectedTotal)
            XCTAssertEqual(outcome.nonBlockingFailureCount, item.expectedSoft)
            XCTAssertEqual(outcome.discoveryFailureCount, item.expectedTotal - item.expectedSoft)
        }
    }

    func testSuccessfulSeverityMatrixKeepsFullCountsAndDefersPresentationUntilIdle() async throws {
        let countCases: [(total: Int, soft: Int)] = [(0, 0), (3, 3), (2, 0), (5, 3)]
        for appCount in [0, 1] {
            for counts in countCases {
                let source = SeverityDataSource()
                defer { source.close() }
                let controller = AppGridRefreshController(dataSource: source)
                try await startRefresh(controller, source: source, begin: true)
                let snapshot = try makeSnapshot(titles: appCount == 0 ? [] : ["Synthetic"], revision: 1)
                let outcome = AppGridRefreshOutcome(succeeded: true, appCount: appCount,
                    failureCount: counts.total, nonBlockingFailureCount: counts.soft)
                let expected: AppGridUIState = counts.total > counts.soft
                    ? .partialFailure : (appCount == 0 ? .empty : .ready)

                await finishRefresh(controller, source: source, snapshot: snapshot,
                                    outcome: outcome, expected: expected)

                XCTAssertEqual(controller.lastOutcome, outcome)
                XCTAssertEqual(controller.lastOutcome?.failureCount, counts.total)
                XCTAssertEqual(controller.lastOutcome?.discoveryFailureCount, counts.total - counts.soft)
                XCTAssertEqual(controller.provider.pendingSnapshot, snapshot)
                XCTAssertNil(controller.provider.servedSnapshot)
                XCTAssertNotNil(controller.applyPendingAtIdleBoundary(currentPage: 0))
                XCTAssertEqual(controller.provider.servedSnapshot, snapshot)
                XCTAssertNil(controller.provider.pendingSnapshot)
            }
        }
    }

    func testWholeFailureRemainsPartialEvenWithNoDiscoveryIssuesOrNoApps() async throws {
        let countCases: [(total: Int, soft: Int)] = [(0, 0), (2, 2), (5, 3)]
        for appCount in [0, 1] {
            for counts in countCases {
                let source = SeverityDataSource()
                defer { source.close() }
                let controller = AppGridRefreshController(dataSource: source)
                try await startRefresh(controller, source: source, begin: true)
                let outcome = AppGridRefreshOutcome(succeeded: false, appCount: appCount,
                    failureCount: counts.total, nonBlockingFailureCount: counts.soft)

                await finishRefresh(controller, source: source, outcome: outcome, expected: .partialFailure)

                XCTAssertEqual(controller.lastOutcome, outcome)
                XCTAssertNil(controller.provider.pendingSnapshot)
                XCTAssertNil(controller.provider.servedSnapshot)
            }
        }
    }

    func testCancellationRestoresEveryStableStateAndRetainsCommittedPresentation() async throws {
        let stableStates: [AppGridUIState] = [.ready, .empty, .partialFailure]
        for priorState in stableStates {
            let source = SeverityDataSource()
            defer { source.close() }
            let controller = AppGridRefreshController(dataSource: source)
            let appCount = priorState == .empty ? 0 : 1
            let snapshot = try makeSnapshot(titles: appCount == 0 ? [] : ["Retained"], revision: 1)
            try await startRefresh(controller, source: source, begin: true)
            await finishRefresh(controller, source: source, snapshot: snapshot,
                outcome: .init(succeeded: true, appCount: appCount,
                               failureCount: priorState == .partialFailure ? 1 : 0), expected: priorState)
            XCTAssertNotNil(controller.applyPendingAtIdleBoundary(currentPage: 0))

            try await startRefresh(controller, source: source)
            XCTAssertEqual(controller.state, .refreshing)
            let cancelled = AppGridRefreshOutcome(failureCount: 4, nonBlockingFailureCount: 3, cancelled: true)
            await finishRefresh(controller, source: source, outcome: cancelled, expected: priorState)

            XCTAssertEqual(controller.lastOutcome, cancelled)
            XCTAssertEqual(controller.provider.servedSnapshot, snapshot)
            XCTAssertNil(controller.provider.pendingSnapshot)
            XCTAssertNil(controller.applyPendingAtIdleBoundary(currentPage: 0))
        }
    }

    func testInitialCancellationKeepsLoadingAndQueuedRefreshRecovers() async throws {
        let source = SeverityDataSource()
        defer { source.close() }
        let controller = AppGridRefreshController(dataSource: source)
        try await startRefresh(controller, source: source, begin: true)
        let nextStarted = expectation(description: "queued refresh after cancellation")
        source.expectStart(nextStarted)
        controller.refreshNow()
        source.finish(outcome: .init(cancelled: true))
        try await requireStarted(nextStarted, source: source)

        XCTAssertEqual(controller.state, .loading)
        XCTAssertEqual(controller.lastOutcome, .init(cancelled: true))
        XCTAssertNil(controller.provider.pendingSnapshot)
        XCTAssertNil(controller.provider.servedSnapshot)

        let snapshot = try makeSnapshot(titles: ["Recovered"], revision: 2)
        await finishRefresh(controller, source: source, snapshot: snapshot,
                            outcome: .init(succeeded: true, appCount: 1), expected: .ready)
        XCTAssertEqual(controller.provider.pendingSnapshot, snapshot)
    }

    func testQueuedRefreshReplacesHardPendingResultWithLatestSoftOnlyResult() async throws {
        let source = SeverityDataSource()
        defer { source.close() }
        let controller = AppGridRefreshController(dataSource: source)
        try await startRefresh(controller, source: source, begin: true)
        let nextStarted = expectation(description: "queued latest refresh")
        source.expectStart(nextStarted)
        controller.refreshNow()
        source.finish(snapshot: try makeSnapshot(titles: [], revision: 1),
                      outcome: .init(succeeded: true, failureCount: 1))
        try await requireStarted(nextStarted, source: source)

        XCTAssertEqual(controller.state, .refreshing)
        XCTAssertEqual(controller.lastOutcome?.discoveryFailureCount, 1)
        XCTAssertEqual(controller.provider.pendingRevision, 1)
        XCTAssertNil(controller.provider.servedSnapshot)

        let latest = try makeSnapshot(titles: ["Latest"], revision: 2)
        await finishRefresh(controller, source: source, snapshot: latest,
            outcome: .init(succeeded: true, appCount: 1, failureCount: 1, nonBlockingFailureCount: 1),
            expected: .ready)
        XCTAssertEqual(controller.provider.pendingSnapshot, latest)
        XCTAssertNil(controller.provider.servedSnapshot)
        XCTAssertEqual(controller.applyPendingAtIdleBoundary(currentPage: 0)?.newRevision, 2)
        XCTAssertEqual(controller.provider.servedSnapshot, latest)
    }

    func testSoftOnlyAndHealthyRefreshesClearEarlierDiscoveryWarning() async throws {
        let source = SeverityDataSource()
        defer { source.close() }
        let controller = AppGridRefreshController(dataSource: source)
        let outcomes: [(AppGridRefreshOutcome, AppGridUIState)] = [
            (.init(succeeded: true, appCount: 1, failureCount: 4, nonBlockingFailureCount: 3), .partialFailure),
            (.init(succeeded: true, appCount: 1, failureCount: 3, nonBlockingFailureCount: 3), .ready),
            (.init(succeeded: true, appCount: 1), .ready),
            (.init(succeeded: true), .empty),
        ]
        for (index, item) in outcomes.enumerated() {
            try await startRefresh(controller, source: source, begin: index == 0)
            let snapshot = try makeSnapshot(titles: item.0.appCount == 0 ? [] : ["Synthetic"],
                                            revision: UInt64(index + 1))
            await finishRefresh(controller, source: source, snapshot: snapshot,
                                outcome: item.0, expected: item.1)
            XCTAssertEqual(controller.lastOutcome, item.0)
            XCTAssertNotNil(controller.applyPendingAtIdleBoundary(currentPage: 0))
            XCTAssertEqual(controller.provider.servedSnapshot, snapshot)
        }
    }

    private func startRefresh(_ controller: AppGridRefreshController, source: SeverityDataSource,
                              begin: Bool = false) async throws {
        let started = expectation(description: "refresh started")
        source.expectStart(started)
        if begin { controller.begin() } else { controller.refreshNow() }
        try await requireStarted(started, source: source)
    }

    private func requireStarted(_ started: XCTestExpectation, source: SeverityDataSource) async throws {
        await fulfillment(of: [started], timeout: 3)
        guard source.hasPending else { throw SeverityRefreshWaitError.notStarted }
    }

    private func finishRefresh(_ controller: AppGridRefreshController, source: SeverityDataSource,
                               snapshot: CatalogSnapshot? = nil, outcome: AppGridRefreshOutcome,
                               expected: AppGridUIState) async {
        let settled = expectation(description: "refresh settled at \(expected)")
        controller.onStateChange = { state in
            if state == expected { settled.fulfill() }
        }
        defer { controller.onStateChange = nil }
        source.finish(snapshot: snapshot, outcome: outcome)
        await fulfillment(of: [settled], timeout: 3)
        XCTAssertEqual(controller.state, expected)
    }
}

private enum SeverityRefreshWaitError: Error { case notStarted }

/// Lock-confined gates provide deterministic completion and close on any failed assertion.
private final class SeverityDataSource: AppGridDataSource, @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: CatalogSnapshot?
    private var pending: CheckedContinuation<AppGridRefreshOutcome, Never>?
    private var started: XCTestExpectation?
    private var closed = false

    var currentSnapshot: CatalogSnapshot? {
        lock.lock(); defer { lock.unlock() }
        return snapshot
    }

    var hasPending: Bool {
        lock.lock(); defer { lock.unlock() }
        return pending != nil
    }

    func expectStart(_ expectation: XCTestExpectation) {
        lock.lock(); defer { lock.unlock() }
        started = expectation
    }

    func refresh() async -> AppGridRefreshOutcome {
        await withCheckedContinuation { register($0) }
    }

    private func register(_ continuation: CheckedContinuation<AppGridRefreshOutcome, Never>) {
        lock.lock()
        let rejected = closed || pending != nil
        if !rejected { pending = continuation }
        let expectation = started
        started = nil
        lock.unlock()
        expectation?.fulfill()
        if rejected { continuation.resume(returning: .init(cancelled: true)) }
    }

    func finish(snapshot: CatalogSnapshot? = nil, outcome: AppGridRefreshOutcome) {
        lock.lock()
        let continuation = pending
        pending = nil
        if let snapshot { self.snapshot = snapshot }
        lock.unlock()
        XCTAssertNotNil(continuation, "A refresh must be held before completion")
        continuation?.resume(returning: outcome)
    }

    func close() {
        lock.lock()
        closed = true
        let continuation = pending
        pending = nil
        lock.unlock()
        continuation?.resume(returning: .init(cancelled: true))
    }
}
