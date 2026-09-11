//
//  CatalogRepository.swift
//  MacAppCatalog
//
//  Phase 1B — 目录状态容器（wave1-interfaces.md §C，签名冻结；§6.2 纪律落点）。
//  - revision 单调分配的唯一拥有者（§H 待决点 6：CatalogFixture 显式传参，本 actor 独占分配）；
//  - latest-wins：新 refresh 到达 → 取消旧任务；被取代的刷新回报 coalesced=true 且不触碰 current；
//  - 取消/半成品绝不写入 current（部分结果丢弃）；
//  - 最终快照由本 actor 以自身 policy 经 CatalogBuilder 收敛（去重/排序权威在 repository）。
//

import Foundation
import AppCatalogCore

/// 一次 refresh 的回报（供 telemetry 计数：coalesced / cancelled）。
public struct CatalogRefreshResult: Sendable {
    /// 应用后的最终快照；取消/被取代/构建失败 → nil。
    public let snapshot: CatalogSnapshot?
    /// 匿名扫描报告（仅计数 + 时长）。
    public let report: ScanReport
    /// true = 本次刷新被更新的 refresh 取代（结果被丢弃，latest-wins）。
    public let coalesced: Bool
    /// true = 本次刷新被取消（部分结果丢弃）。
    public let cancelled: Bool

    public init(snapshot: CatalogSnapshot?, report: ScanReport, coalesced: Bool, cancelled: Bool) {
        self.snapshot = snapshot
        self.report = report
        self.coalesced = coalesced
        self.cancelled = cancelled
    }
}

/// 目录状态容器：revision 单调 + latest-wins refresh（§6.2）。
public actor CatalogRepository {
    private let policy: CatalogPolicy
    private let scanning: any CatalogScanning

    private var revisionCounter: CatalogRevision = .zero   // 每次 refresh 调用递增（含被取消者）
    private var nextToken: UInt64 = 0
    private var activeTask: PendingScan?
    private var continuations: [UInt64: CheckedContinuation<CatalogRefreshResult, Never>] = [:]

    /// 最近一次应用的快照（latest-wins 之后的最新者）。
    public private(set) var current: CatalogSnapshot?
    /// 最近一次扫描完成的匿名报告（含取消/被取代者，供诊断）。
    public private(set) var lastReport: ScanReport?

    public init(policy: CatalogPolicy, scanning: any CatalogScanning) {
        self.policy = policy
        self.scanning = scanning
    }

    private struct PendingScan {
        let token: UInt64
        let task: ScanTask
    }

    /// 发起一次刷新：分配单调 revision → 取消旧任务（latest-wins）→ 等待扫描完成。
    /// 返回后 `current` 可能未变（取消/被取代/构建失败），以返回值的快照为准。
    public func refresh(configuration: ScanConfiguration) async -> CatalogRefreshResult {
        let token = nextToken
        nextToken &+= 1
        let revision = revisionCounter.incremented()
        revisionCounter = revision

        // latest-wins：新 refresh 到达 → 旧任务取消（幂等；旧结果即使晚到也按 token 判为被取代）。
        activeTask?.task.cancel()

        let task = scanning.scan(configuration: configuration, revision: revision) { [weak self] result in
            Task { await self?.completeScan(token: token, result: result) }
        }
        activeTask = PendingScan(token: token, task: task)

        return await withCheckedContinuation { continuation in
            continuations[token] = continuation
        }
    }

    /// 扫描完成回调（任意线程 → 经 Task 回到本 actor）。
    private func completeScan(token: UInt64, result: CatalogScanResult) {
        let continuation = continuations.removeValue(forKey: token)

        guard let pending = activeTask, pending.token == token else {
            // 已被更新的 refresh 取代：结果整体丢弃（不触碰 current），只回报计数。
            continuation?.resume(returning: CatalogRefreshResult(snapshot: nil, report: result.report,
                                                                 coalesced: true, cancelled: result.cancelled))
            return
        }
        activeTask = nil

        guard !result.cancelled, let draft = result.snapshot else {
            // 取消（部分结果丢弃）或扫描器未产出快照：保持旧 current 不变。
            lastReport = result.report
            continuation?.resume(returning: CatalogRefreshResult(snapshot: nil, report: result.report,
                                                                 coalesced: false, cancelled: result.cancelled))
            return
        }

        do {
            // repository 是 policy 唯一权威：以自身 policy 收敛（canonical URL 去重 → bundleID 去重 → 稳定排序）。
            let snapshot = try CatalogBuilder.build(rawRecords: draft.records, policy: policy, revision: draft.revision)
            current = snapshot
            lastReport = result.report
            continuation?.resume(returning: CatalogRefreshResult(snapshot: snapshot, report: result.report,
                                                                 coalesced: false, cancelled: false))
        } catch {
            // 构建失败（异常输入）：不崩溃；保持旧 current，计数照常回报。
            lastReport = result.report
            continuation?.resume(returning: CatalogRefreshResult(snapshot: nil, report: result.report,
                                                                 coalesced: false, cancelled: false))
        }
    }

    deinit {
        // 防御：仓库被销毁时取消在途任务并唤醒所有等待者（绝不悬挂调用方）。
        activeTask?.task.cancel()
        let emptyReport = ScanReport(appCount: 0, failureCounts: [:], scanDuration: 0)
        for (_, continuation) in continuations {
            continuation.resume(returning: CatalogRefreshResult(snapshot: nil, report: emptyReport,
                                                                coalesced: true, cancelled: true))
        }
    }
}
