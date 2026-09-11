//
//  CatalogRepositoryTests.swift
//  MacAppCatalogTests
//
//  Phase 1B — CatalogRepository：revision 单调唯一拥有者 / latest-wins / coalesced 计数（§6.2、§10.3）。
//  latest-wins 用例用 ScriptedScanner 确定性编排；顺序刷新用真实 CatalogScanner + 临时 fake 根。
//

import XCTest
import AppCatalogCore
@testable import MacAppCatalog

final class CatalogRepositoryTests: XCTestCase {

    // MARK: 工具

    private func makeReport(appCount: Int, failures: [ScanFailureKind: Int] = [:]) -> ScanReport {
        ScanReport(appCount: appCount, failureCounts: failures, scanDuration: 0)
    }

    private func makeSnapshot(revision: CatalogRevision, count: Int) throws -> CatalogSnapshot {
        let records = (0..<count).map { index in
            CatalogFixture.record(id: .bundleIdentifier("com.example.repo\(index)"),
                                  displayName: "Repo App \(index)",
                                  bundleID: "com.example.repo\(index)",
                                  url: URL(fileURLWithPath: "/tmp/fake\(index).app"),
                                  icon: .from(appID: .bundleIdentifier("com.example.repo\(index)")),
                                  rootPriority: 0)
        }
        return try CatalogFixture.snapshot(records: records, revision: revision)
    }

    private func waitFor(_ condition: () -> Bool, timeout: TimeInterval = 5) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline { return false }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        return true
    }

    // MARK: 顺序刷新（真实扫描器）：单调 revision + current/lastReport

    func testSequentialRefreshesMonotonicRevision() async throws {
        let factory = try FakeAppFactory()
        try factory.makeApp(named: "One", bundleID: "com.example.one")
        let repo = CatalogRepository(policy: .init(), scanning: CatalogScanner())
        let config = ScanConfiguration(roots: [factory.root])

        let first = await repo.refresh(configuration: config)
        XCTAssertFalse(first.cancelled)
        XCTAssertFalse(first.coalesced)
        XCTAssertEqual(first.snapshot?.revision, .init(1))
        let currentAfterFirst = await repo.current
        let reportAfterFirst = await repo.lastReport
        XCTAssertEqual(currentAfterFirst, first.snapshot)
        XCTAssertEqual(reportAfterFirst?.appCount, 1)

        try factory.makeApp(named: "Two", bundleID: "com.example.two")
        let second = await repo.refresh(configuration: config)
        XCTAssertEqual(second.snapshot?.revision, .init(2))     // 严格递增
        let currentAfterSecond = await repo.current
        let reportAfterSecond = await repo.lastReport
        XCTAssertEqual(currentAfterSecond?.revision, .init(2))
        XCTAssertEqual(currentAfterSecond?.records.count, 2)
        XCTAssertEqual(reportAfterSecond?.appCount, 2)
    }

    // MARK: latest-wins：新 refresh 取消旧任务；旧结果 coalesced 且不触碰 current

    func testLatestWinsSupersededRefreshIsCoalesced() async throws {
        let scanner = ScriptedScanner()
        let repo = CatalogRepository(policy: .init(), scanning: scanner)
        let config = ScanConfiguration(roots: [URL(fileURLWithPath: "/tmp/fake-root")])

        let first = Task { await repo.refresh(configuration: config) }
        let firstStarted = await waitFor { scanner.started == 1 }
        XCTAssertTrue(firstStarted)
        let second = Task { await repo.refresh(configuration: config) }
        let secondStarted = await waitFor { scanner.started == 2 }
        XCTAssertTrue(secondStarted)

        // 完成第二个（最新）→ 应用。
        let secondSnapshot = try makeSnapshot(revision: .init(2), count: 2)
        scanner.completeLatest(snapshot: secondSnapshot, report: makeReport(appCount: 2))
        let secondResult = await second.value
        XCTAssertFalse(secondResult.coalesced)
        XCTAssertFalse(secondResult.cancelled)
        XCTAssertEqual(secondResult.snapshot, secondSnapshot)
        let currentAfterSecond = await repo.current
        XCTAssertEqual(currentAfterSecond, secondSnapshot)      // latest-wins 已应用

        // 完成第一个（已被取代）→ coalesced，结果丢弃，current 不变。
        let firstSnapshot = try makeSnapshot(revision: .init(1), count: 1)
        scanner.completeOldest(snapshot: firstSnapshot, report: makeReport(appCount: 1))
        let firstResult = await first.value
        XCTAssertTrue(firstResult.coalesced)                    // 被更新的 refresh 取代
        XCTAssertTrue(firstResult.cancelled)                    // 任务已被取消
        XCTAssertNil(firstResult.snapshot)                      // 部分结果丢弃
        XCTAssertEqual(scanner.cancelledTaskCount, 1)           // latest-wins：旧任务被取消并观察
        let currentAfterFirst = await repo.current
        XCTAssertEqual(currentAfterFirst, secondSnapshot)       // 旧结果绝不覆盖新结果
    }

    func testSupersededCompletionArrivingLateIsStillCoalesced() async throws {
        // 完成顺序反了：新任务先完成、旧任务后完成 → 旧结果依旧被丢弃。
        let scanner = ScriptedScanner()
        let repo = CatalogRepository(policy: .init(), scanning: scanner)
        let config = ScanConfiguration(roots: [URL(fileURLWithPath: "/tmp/fake-root")])

        let first = Task { await repo.refresh(configuration: config) }
        var ok = await waitFor { scanner.started == 1 }
        XCTAssertTrue(ok)
        let second = Task { await repo.refresh(configuration: config) }
        ok = await waitFor { scanner.started == 2 }
        XCTAssertTrue(ok)

        scanner.completeLatest(snapshot: try makeSnapshot(revision: .init(2), count: 2),
                               report: makeReport(appCount: 2))
        let secondResult = await second.value
        XCTAssertFalse(secondResult.coalesced)

        scanner.completeOldest(snapshot: try makeSnapshot(revision: .init(1), count: 1),
                               report: makeReport(appCount: 1))
        let firstResult = await first.value
        XCTAssertTrue(firstResult.coalesced)
        XCTAssertNil(firstResult.snapshot)
        let current = await repo.current
        XCTAssertEqual(current?.revision, .init(2))
    }

    // MARK: 取消语义：cancelled 扫描丢弃部分结果、保持旧 current、revision 仍单调

    func testCancelledRefreshKeepsCurrentAndConsumesRevision() async throws {
        let scanner = ScriptedScanner()
        let repo = CatalogRepository(policy: .init(), scanning: scanner)
        let config = ScanConfiguration(roots: [URL(fileURLWithPath: "/tmp/fake-root")])

        // 第一次成功应用 → revision 1。
        let first = Task { await repo.refresh(configuration: config) }
        var ok = await waitFor { scanner.started == 1 }
        XCTAssertTrue(ok)
        scanner.completeLatest(snapshot: try makeSnapshot(revision: .init(1), count: 1),
                               report: makeReport(appCount: 1))
        let firstValue = await first.value
        XCTAssertEqual(firstValue.snapshot?.revision, .init(1))
        let currentAfterFirst = await repo.current
        XCTAssertEqual(currentAfterFirst?.revision, .init(1))

        // 第二次被取消（部分结果丢弃）→ current 保持 revision 1。
        let second = Task { await repo.refresh(configuration: config) }
        ok = await waitFor { scanner.started == 2 }
        XCTAssertTrue(ok)
        scanner.cancelAllPending()
        scanner.completeLatest(snapshot: try makeSnapshot(revision: .init(2), count: 5),
                               report: makeReport(appCount: 5))
        let secondResult = await second.value
        XCTAssertTrue(secondResult.cancelled)
        XCTAssertNil(secondResult.snapshot)
        XCTAssertFalse(secondResult.coalesced)
        let currentAfterSecond = await repo.current
        XCTAssertEqual(currentAfterSecond?.revision, .init(1))  // 旧 current 不被半成品覆盖

        // 第三次成功 → revision 3（单调计数器按调用递增，即使中间被取消）。
        let third = Task { await repo.refresh(configuration: config) }
        ok = await waitFor { scanner.started == 3 }
        XCTAssertTrue(ok)
        scanner.completeLatest(snapshot: try makeSnapshot(revision: .init(3), count: 1),
                               report: makeReport(appCount: 1))
        let thirdValue = await third.value
        XCTAssertEqual(thirdValue.snapshot?.revision, .init(3))
        let currentAfterThird = await repo.current
        XCTAssertEqual(currentAfterThird?.revision, .init(3))
    }

    // MARK: repository 以自身 policy 收敛（构建失败不崩溃）

    func testRepositoryAppliesItsOwnPolicy() async throws {
        let scanner = ScriptedScanner()
        let repo = CatalogRepository(policy: CatalogPolicy(), scanning: scanner)
        let config = ScanConfiguration(roots: [URL(fileURLWithPath: "/tmp/fake-root")])

        let refresh = Task { await repo.refresh(configuration: config) }
        let ok = await waitFor { scanner.started == 1 }
        XCTAssertTrue(ok)
        let snapshot = try makeSnapshot(revision: .init(1), count: 3)
        scanner.completeLatest(snapshot: snapshot, report: makeReport(appCount: 3))

        let result = await refresh.value
        XCTAssertNotNil(result.snapshot)
        XCTAssertEqual(result.snapshot?.revision, .init(1))
        // current 是经 CatalogBuilder(policy) 收敛的结果；记录集合与扫描产物一致。
        let current = await repo.current
        XCTAssertEqual(current?.revision, result.snapshot?.revision)
        XCTAssertEqual(Set(current?.records ?? []), Set(snapshot.records))
    }
}

// MARK: - 确定性编排扫描器（latest-wins / 取消测试）

/// 手动触发的假扫描器：scan() 只登记任务与完成回调；测试按需 complete，
/// 完成时以「任务是否已被取消」模拟真实扫描器的取消语义。
private final class ScriptedScanner: CatalogScanning, @unchecked Sendable {
    private struct Pending {
        let task: ScanTask
        let completion: @Sendable (CatalogScanResult) -> Void
    }

    private let lock = NSLock()
    private var nextID = 0
    private var pending: [Int: Pending] = [:]
    private var startedCount = 0
    private var cancelledTaskIDs: [Int] = []

    var started: Int {
        lock.lock()
        defer { lock.unlock() }
        return startedCount
    }

    var cancelledTaskCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return cancelledTaskIDs.count
    }

    func scan(configuration: ScanConfiguration,
              revision: CatalogRevision,
              completion: @escaping @Sendable (CatalogScanResult) -> Void) -> ScanTask {
        lock.lock()
        let id = nextID
        nextID += 1
        let task = ScanTask()
        pending[id] = Pending(task: task, completion: completion)
        startedCount += 1
        lock.unlock()
        return task
    }

    /// 完成最新登记的扫描（按任务取消状态决定回报）。
    func completeLatest(snapshot: CatalogSnapshot?, report: ScanReport) {
        complete(extreme: .max, snapshot: snapshot, report: report)
    }

    /// 完成最早登记的扫描。
    func completeOldest(snapshot: CatalogSnapshot?, report: ScanReport) {
        complete(extreme: .min, snapshot: snapshot, report: report)
    }

    func cancelAllPending() {
        lock.lock()
        let tasks = pending.values.map(\.task)
        lock.unlock()
        for task in tasks { task.cancel() }
    }

    private func complete(extreme: Int, snapshot: CatalogSnapshot?, report: ScanReport) {
        lock.lock()
        let id: Int
        switch extreme {
        case .min: id = pending.keys.min() ?? -1
        default: id = pending.keys.max() ?? -1
        }
        let entry = pending.removeValue(forKey: id)
        lock.unlock()
        guard let entry else { return }
        let cancelled = entry.task.isCancelled
        if cancelled {
            lock.lock()
            cancelledTaskIDs.append(id)
            lock.unlock()
        }
        entry.completion(CatalogScanResult(snapshot: cancelled ? nil : snapshot,
                                           report: report, cancelled: cancelled))
    }
}
