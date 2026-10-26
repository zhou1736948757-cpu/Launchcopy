import Foundation
import XCTest
@testable import PagingTelemetry

final class TelemetrySnapshotTests: XCTestCase {
    func testDisabledSnapshotIsDetachedAndLegacyRegistrationPolicyRemains() throws {
        let directory = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: .init(enabled: false, runID: "snapshot-disabled",
                                                            outputDirectory: directory))
        let initial = session.stateSnapshot
        XCTAssertFalse(initial.isActive)
        XCTAssertNil(initial.fileURL)
        XCTAssertEqual(initial.recordedEventCount, 0)
        XCTAssertEqual(initial.writeFailureCount, 0)
        XCTAssertEqual(initial.layoutCount, 0)
        XCTAssertEqual(session.registerLayout(), 1)
        XCTAssertEqual(session.registerCellReuse(), 1)
        XCTAssertEqual(session.registerStaleRejection(), 1)
        XCTAssertEqual(session.registerInterruption(), 1)
        XCTAssertEqual(session.registerTeardownCallback(), 1)
        session.begin()
        session.record(.init(phase: "fixture.disabled"))
        session.end()
        let value = session.stateSnapshot
        assertLegacy(session, matches: value)
        XCTAssertFalse(value.isActive)
        XCTAssertNil(value.fileURL)
        XCTAssertEqual(value.recordedEventCount, 0)
        XCTAssertEqual(value.layoutCount, 1)
        XCTAssertEqual(value.cellReuseCount, 1)
        XCTAssertEqual(value.staleRejectionCount, 1)
        XCTAssertEqual(value.interruptionCount, 1)
        XCTAssertEqual(value.teardownCallbackCount, 1)
        XCTAssertFalse(value.degradedToMemory)
        XCTAssertFalse(value.fileCapacityReached)
        XCTAssertEqual(initial.layoutCount, 0, "Value snapshots cannot mutate after publication")
        XCTAssertEqual(session.logPathDescription, "telemetry disabled")
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    func testCapacityEndSnapshotsPreserveLogTextAndJSONLStampPolicy() throws {
        let directory = try makeTempOutputDirectory()
        let session = TelemetrySession(configuration: .init(enabled: true, runID: "snapshot-capacity",
            outputDirectory: directory, maxFileEventsPerRun: 3))
        session.begin()
        let began = session.stateSnapshot
        XCTAssertTrue(began.isActive)
        XCTAssertEqual(began.recordedEventCount, 1)
        XCTAssertFalse(began.fileCapacityReached)
        XCTAssertEqual(session.logPathDescription, try XCTUnwrap(began.fileURL).path)
        _ = session.registerInterruption()
        _ = session.registerStaleRejection()
        _ = session.registerLayout()
        _ = session.registerLayout()
        _ = session.registerTeardownCallback()
        _ = session.registerCellReuse()
        var explicit = TelemetryEvent(phase: "fixture.explicit")
        explicit.cellReuseCount = 99
        session.record(explicit)
        session.record(.init(phase: "fixture.capacity"))
        let capacity = session.stateSnapshot
        assertLegacy(session, matches: capacity)
        XCTAssertEqual(capacity.recordedEventCount, 3)
        XCTAssertTrue(capacity.fileCapacityReached)
        XCTAssertFalse(capacity.degradedToMemory)
        XCTAssertEqual(capacity.writeFailureCount, 0)
        XCTAssertEqual(session.logPathDescription,
                       "telemetry file-capacity-reached (3 events); continuing in bounded memory buffer")
        session.record(.init(phase: "fixture.memory"))
        session.end()
        let ended = session.stateSnapshot
        assertLegacy(session, matches: ended)
        XCTAssertFalse(ended.isActive)
        XCTAssertEqual(ended.recordedEventCount, 5)
        XCTAssertTrue(ended.fileCapacityReached)
        XCTAssertEqual(ended.layoutCount, 2)
        XCTAssertEqual(ended.interruptionCount, 1)
        XCTAssertEqual(ended.staleRejectionCount, 1)
        XCTAssertEqual(ended.teardownCallbackCount, 1)
        XCTAssertEqual(ended.cellReuseCount, 1)
        XCTAssertEqual(ended.fileURL, began.fileURL)
        let file = try XCTUnwrap(ended.fileURL)
        let rows = try readLines(of: file).map { try JSONDecoder().decode(TelemetryEvent.self, from: Data($0.utf8)) }
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows[1].cellReuseCount, 99)
        XCTAssertEqual(rows[2].cellReuseCount, 1)
        XCTAssertEqual(rows[2].layoutCount, 2)
        XCTAssertEqual(rows[2].interruptionCount, 1)
        XCTAssertEqual(rows[2].staleRejectionCount, 1)
        XCTAssertEqual(rows[2].teardownCallbackCount, 1)
        XCTAssertEqual(session.memoryBufferEvents.map(\.phase), ["fixture.memory", TelemetryPhase.runEnd])
        session.end()
        XCTAssertEqual(session.stateSnapshot, ended)
        XCTAssertTrue(began.isActive)
        XCTAssertEqual(began.recordedEventCount, 1)
        XCTAssertFalse(began.fileCapacityReached)
    }

    func testDegradedSnapshotAndEveryLegacyGetterRemainReadableAfterLifecycleCalls() throws {
        let session = try memorySession()
        session.begin()
        let began = session.stateSnapshot
        assertLegacy(session, matches: began)
        XCTAssertTrue(began.isActive)
        XCTAssertNil(began.fileURL)
        XCTAssertTrue(began.degradedToMemory)
        XCTAssertEqual(began.writeFailureCount, 1)
        XCTAssertEqual(session.logPathDescription, "telemetry degraded-to-memory (no file; writeFailureCount=1)")
        for _ in 0..<6 { session.record(.init(phase: "fixture.memory")) }
        session.flush()
        session.end()
        let ended = session.stateSnapshot
        assertLegacy(session, matches: ended)
        XCTAssertFalse(ended.isActive)
        XCTAssertEqual(ended.recordedEventCount, 8)
        XCTAssertEqual(ended.writeFailureCount, 1)
        XCTAssertFalse(ended.fileCapacityReached)
        XCTAssertEqual(session.memoryBufferEvents.count, 8)
    }

    func testConcurrentRegistrationReceiptsAndSameOwnerSnapshotsAreCoherent() throws {
        let session = try memorySession()
        session.begin()
        let observations = SnapshotObservations()
        let iterations = 300
        DispatchQueue.concurrentPerform(iterations: iterations) { _ in
            let receipt = session.registerLayout()
            _ = session.registerCellReuse()
            _ = session.registerStaleRejection()
            _ = session.registerInterruption()
            _ = session.registerTeardownCallback()
            session.record(.init(phase: "fixture.concurrent"))
            observations.capture(session.stateSnapshot, receipt: receipt, limit: iterations)
            // Exercise all synchronized legacy reads under concurrent writers;
            // separate getter calls are intentionally not treated as one snapshot.
            Self.touchLegacyGetters(session)
        }
        XCTAssertEqual(observations.violations, 0)
        XCTAssertEqual(observations.receipts.sorted(), Array(1...iterations))
        let value = session.stateSnapshot
        assertLegacy(session, matches: value)
        XCTAssertEqual(value.layoutCount, iterations)
        XCTAssertEqual(value.cellReuseCount, iterations)
        XCTAssertEqual(value.staleRejectionCount, iterations)
        XCTAssertEqual(value.interruptionCount, iterations)
        XCTAssertEqual(value.teardownCallbackCount, iterations)
        XCTAssertEqual(value.recordedEventCount, iterations + 1)
        session.end()
        XCTAssertEqual(session.stateSnapshot.recordedEventCount, iterations + 2)
        XCTAssertFalse(session.stateSnapshot.isActive)
        XCTAssertEqual(session.memoryBufferEvents.count, iterations + 2)
    }

    private func memorySession() throws -> TelemetrySession {
        let directory = try makeTempOutputDirectory()
        let blocker = directory.appendingPathComponent("owned-blocker")
        try Data().write(to: blocker)
        return TelemetrySession(configuration: .init(enabled: true, runID: "snapshot-memory",
            outputDirectory: blocker.appendingPathComponent("not-a-directory")))
    }

    private func assertLegacy(_ session: TelemetrySession, matches value: TelemetrySessionSnapshot,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(session.fileURL, value.fileURL, file: file, line: line)
        XCTAssertEqual(session.isActive, value.isActive, file: file, line: line)
        XCTAssertEqual(session.recordedEventCount, value.recordedEventCount, file: file, line: line)
        XCTAssertEqual(session.writeFailureCount, value.writeFailureCount, file: file, line: line)
        XCTAssertEqual(session.degradedToMemory, value.degradedToMemory, file: file, line: line)
        XCTAssertEqual(session.fileCapacityReached, value.fileCapacityReached, file: file, line: line)
        XCTAssertEqual(session.interruptionCount, value.interruptionCount, file: file, line: line)
        XCTAssertEqual(session.staleRejectionCount, value.staleRejectionCount, file: file, line: line)
        XCTAssertEqual(session.layoutCount, value.layoutCount, file: file, line: line)
        XCTAssertEqual(session.teardownCallbackCount, value.teardownCallbackCount, file: file, line: line)
        XCTAssertEqual(session.cellReuseCount, value.cellReuseCount, file: file, line: line)
    }

    private static func touchLegacyGetters(_ session: TelemetrySession) {
        _ = session.fileURL
        _ = session.isActive
        _ = session.recordedEventCount
        _ = session.writeFailureCount
        _ = session.degradedToMemory
        _ = session.fileCapacityReached
        _ = session.interruptionCount
        _ = session.staleRejectionCount
        _ = session.layoutCount
        _ = session.teardownCallbackCount
        _ = session.cellReuseCount
    }
}

private final class SnapshotObservations: @unchecked Sendable {
    private let lock = NSLock()
    private var storedReceipts: [Int] = []
    private var storedViolations = 0
    var receipts: [Int] { lock.lock(); defer { lock.unlock() }; return storedReceipts }
    var violations: Int { lock.lock(); defer { lock.unlock() }; return storedViolations }
    func capture(_ value: TelemetrySessionSnapshot, receipt: Int, limit: Int) {
        let counts = [value.layoutCount, value.cellReuseCount, value.staleRejectionCount,
                      value.interruptionCount, value.teardownCallbackCount]
        let coherent = zip(counts, counts.dropFirst()).allSatisfy { $0 >= $1 }
            && counts.allSatisfy { (0...limit).contains($0) }
            && value.recordedEventCount >= 1 && value.recordedEventCount <= limit + 1
            && value.recordedEventCount - 1 <= value.teardownCallbackCount
            && value.isActive && value.fileURL == nil && value.degradedToMemory
            && value.writeFailureCount == 1 && !value.fileCapacityReached
        lock.lock()
        storedReceipts.append(receipt)
        if !coherent { storedViolations += 1 }
        lock.unlock()
    }
}
