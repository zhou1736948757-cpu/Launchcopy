import AppCatalogCore
import AppGridUI
import Foundation
import XCTest
@testable import MacAppCatalog
@testable import PagingPrototypeApp

/// Empty injected scans only: no filesystem, application icons, windows, or assembly setup.
final class CatalogTimingSnapshotTests: XCTestCase {
    func testInitialPairAndLegacyProjectionsAreNil() {
        let scanner = TimingSnapshotScanner()
        let source = makeSource(scanner)
        defer { source.close(); scanner.close() }

        XCTAssertEqual(source.refreshTimings, CatalogRefreshTimings())
        XCTAssertNil(source.lastScanDurationMS)
        XCTAssertNil(source.lastRefreshDurationMS)
    }

    func testAcceptedRefreshPublishesPairAndSerialLegacyValuesIncludingFailedScan() async throws {
        let scanner = TimingSnapshotScanner()
        let source = makeSource(scanner)
        defer { source.close(); scanner.close() }

        scanner.enqueue(duration: 0.125)
        let success = await source.refresh()
        XCTAssertTrue(success.succeeded)
        let historicalSnapshot = try XCTUnwrap(source.currentSnapshot)
        let first = source.refreshTimings
        XCTAssertEqual(first.scanDurationMS, 125)
        XCTAssertTrue(try XCTUnwrap(first.refreshDurationMS).isFinite)
        // The writer is idle here; these scalar comparisons do not promise an atomic multi-read.
        XCTAssertEqual(source.lastScanDurationMS, first.scanDurationMS)
        XCTAssertEqual(source.lastRefreshDurationMS, first.refreshDurationMS)

        scanner.enqueue(duration: 0.25, producesSnapshot: false)
        let failure = await source.refresh()
        XCTAssertFalse(failure.succeeded)
        XCTAssertFalse(failure.cancelled)
        let latest = source.refreshTimings
        XCTAssertEqual(latest.scanDurationMS, 250)
        XCTAssertTrue(try XCTUnwrap(latest.refreshDurationMS).isFinite)
        XCTAssertEqual(source.lastScanDurationMS, latest.scanDurationMS)
        XCTAssertEqual(source.lastRefreshDurationMS, latest.refreshDurationMS)
        XCTAssertEqual(source.currentSnapshot, historicalSnapshot)
    }

    func testInvalidatedOldResultCannotReplaceTimingsAndNextGenerationRecovers() async throws {
        let scanner = TimingSnapshotScanner()
        let source = makeSource(scanner)
        defer { source.close(); scanner.close() }
        scanner.enqueue(duration: 0.125)
        _ = await source.refresh()
        let accepted = source.refreshTimings

        let admitted = expectation(description: "old generation scan admitted")
        scanner.enqueue(duration: 9, held: true, admitted: admitted)
        let obsolete = Task { await source.refresh() }
        defer { obsolete.cancel() }
        try await requireHeld(scanner, admitted: admitted)
        source.invalidateRequests()
        XCTAssertEqual(source.refreshTimings, accepted)
        scanner.finishHeld()
        let rejected = await obsolete.value
        XCTAssertTrue(rejected.cancelled)
        XCTAssertNil(source.currentSnapshot)
        XCTAssertEqual(source.refreshTimings, accepted)

        scanner.enqueue(duration: 0.375)
        let recovered = await source.refresh()
        XCTAssertTrue(recovered.succeeded)
        XCTAssertEqual(source.refreshTimings.scanDurationMS, 375)
        XCTAssertNotNil(source.currentSnapshot)
    }

    func testCloseRetainsHistoricalTimingsAndRejectsOldAndFutureResults() async throws {
        let scanner = TimingSnapshotScanner()
        let source = makeSource(scanner)
        defer { source.close(); scanner.close() }
        scanner.enqueue(duration: 0.125)
        _ = await source.refresh()
        let accepted = source.refreshTimings

        let admitted = expectation(description: "scan admitted before close")
        scanner.enqueue(duration: 9, held: true, admitted: admitted)
        let obsolete = Task { await source.refresh() }
        defer { obsolete.cancel() }
        try await requireHeld(scanner, admitted: admitted)
        source.close()
        XCTAssertEqual(source.refreshTimings, accepted)
        scanner.finishHeld()
        let rejected = await obsolete.value
        XCTAssertTrue(rejected.cancelled)
        XCTAssertNil(source.currentSnapshot)
        XCTAssertEqual(source.refreshTimings, accepted)
        let countBefore = scanner.scanCount
        let closed = await source.refresh()
        XCTAssertTrue(closed.cancelled)
        XCTAssertEqual(scanner.scanCount, countBefore)
        XCTAssertEqual(source.refreshTimings, accepted)
        XCTAssertEqual(source.lastScanDurationMS, accepted.scanDurationMS)
        XCTAssertEqual(source.lastRefreshDurationMS, accepted.refreshDurationMS)
    }

    func testConcurrentSnapshotReadsMatchWholeAcceptedPublications() async throws {
        let scanner = TimingSnapshotScanner()
        let source = makeSource(scanner)
        defer { source.close(); scanner.close() }
        var previous = source.refreshTimings

        // Each round races four readers against one accepted publication. The writer's
        // receipt is captured before the next round, so old/new whole-pair membership
        // needs no assumptions about Date() or injected scan duration ordering.
        for round in 1...32 {
            let admitted = expectation(description: "concurrent scan \(round) admitted")
            scanner.enqueue(duration: Double(round), held: true, admitted: admitted)
            let refresh = Task { await source.refresh() }
            defer { refresh.cancel() }
            try await requireHeld(scanner, admitted: admitted)
            let observations = await withTaskGroup(of: [CatalogRefreshTimings].self) { group in
                for _ in 0..<4 {
                    group.addTask {
                        var samples: [CatalogRefreshTimings] = []
                        for index in 0..<128 {
                            samples.append(source.refreshTimings)
                            if index.isMultiple(of: 8) { await Task.yield() }
                        }
                        return samples
                    }
                }
                group.addTask {
                    scanner.finishHeld()
                    let outcome = await refresh.value
                    XCTAssertTrue(outcome.succeeded)
                    return [source.refreshTimings]
                }
                var collected: [CatalogRefreshTimings] = []
                for await samples in group { collected.append(contentsOf: samples) }
                return collected
            }
            let current = source.refreshTimings
            XCTAssertEqual(current.scanDurationMS, Double(round) * 1000)
            XCTAssertNotNil(current.refreshDurationMS)
            XCTAssertEqual(observations.count, 513)
            XCTAssertTrue(observations.allSatisfy { $0 == previous || $0 == current },
                          "Every snapshot must equal a complete accepted pair")
            previous = current
        }
    }

    private func makeSource(_ scanner: TimingSnapshotScanner) -> CatalogRepositoryDataSource {
        CatalogRepositoryDataSource(repository: CatalogRepository(policy: .init(), scanning: scanner),
                                    configuration: ScanConfiguration(roots: []))
    }

    private func requireHeld(_ scanner: TimingSnapshotScanner, admitted: XCTestExpectation) async throws {
        await fulfillment(of: [admitted], timeout: 3)
        guard scanner.hasHeld else {
            // Closing also completes late registrations if admission timed out.
            scanner.close()
            throw TimingSnapshotWaitError.timedOut
        }
    }
}

private enum TimingSnapshotWaitError: Error { case timedOut }

/// All mutable fake state is lock-confined; callbacks run outside the lock.
/// Held callbacks deliberately deliver success after invalidation/close to test the consumer fence.
private final class TimingSnapshotScanner: CatalogScanning, @unchecked Sendable {
    private struct Response {
        let duration: Double
        let producesSnapshot: Bool
        let held: Bool
        let admitted: XCTestExpectation?
    }
    private struct Pending {
        let response: Response
        let revision: CatalogRevision
        let completion: @Sendable (CatalogScanResult) -> Void

        func finish() {
            completion(.init(snapshot: response.producesSnapshot ? .init(revision: revision, records: []) : nil,
                             report: .init(appCount: 0, failureCounts: [:], scanDuration: response.duration),
                             cancelled: false))
        }
    }
    private let lock = NSLock()
    private var queued: [Response] = []
    private var pending: Pending?
    private var closed = false
    private var count = 0

    var scanCount: Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }

    var hasHeld: Bool {
        lock.lock(); defer { lock.unlock() }
        return pending != nil
    }

    func enqueue(duration: Double, producesSnapshot: Bool = true, held: Bool = false,
                 admitted: XCTestExpectation? = nil) {
        lock.lock(); defer { lock.unlock() }
        queued.append(.init(duration: duration, producesSnapshot: producesSnapshot,
                            held: held, admitted: admitted))
    }

    func scan(configuration: ScanConfiguration, revision: CatalogRevision,
              completion: @escaping @Sendable (CatalogScanResult) -> Void) -> ScanTask {
        let task = ScanTask()
        lock.lock()
        count += 1
        let response = !closed && !queued.isEmpty ? queued.removeFirst() : nil
        let entry = response.map { Pending(response: $0, revision: revision, completion: completion) }
        if response?.held == true { pending = entry }
        lock.unlock()
        guard let response, let entry else {
            task.cancel()
            completion(Self.cancelledResult)
            return task
        }
        response.admitted?.fulfill()
        if !response.held { entry.finish() }
        return task
    }

    func finishHeld() {
        lock.lock()
        let entry = pending
        pending = nil
        lock.unlock()
        entry?.finish()
    }

    func close() {
        lock.lock()
        closed = true
        queued.removeAll()
        let entry = pending
        pending = nil
        lock.unlock()
        entry?.completion(Self.cancelledResult)
    }

    private static var cancelledResult: CatalogScanResult {
        .init(snapshot: nil, report: .init(appCount: 0, failureCounts: [:], scanDuration: 0), cancelled: true)
    }
}
