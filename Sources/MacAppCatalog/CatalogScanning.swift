//
//  CatalogScanning.swift
//  MacAppCatalog
//
//  Phase 1B — 扫描协议、可取消任务与扫描结果（wave1-interfaces.md §C，签名冻结）。
//  异步扫描位于 UI/手势热路径之外（§5.2 职责 1）；取消在条目间检查（§10.3 cancel 测试点）。
//

import Foundation
import AppCatalogCore

/// 一次扫描的结果。
public struct CatalogScanResult: Sendable {
    /// 扫描完成的快照；**取消时丢弃部分结果** → nil（§6.2 latest-wins 纪律：绝不应用半成品）。
    public let snapshot: CatalogSnapshot?
    /// 匿名扫描报告（仅计数 + 时长）。
    public let report: ScanReport
    /// 是否被取消（调用方 cancel 或最新 refresh 取代）。
    public let cancelled: Bool

    public init(snapshot: CatalogSnapshot?, report: ScanReport, cancelled: Bool) {
        self.snapshot = snapshot
        self.report = report
        self.cancelled = cancelled
    }
}

/// 可取消的扫描器抽象。实现必须：
/// - 异步执行（不阻塞调用线程）；
/// - 恰好调用一次 completion（成功/取消/失败都算完成）；
/// - 在条目之间检查取消，取消后返回 cancelled 结果并丢弃部分快照。
public protocol CatalogScanning: AnyObject {
    /// 发起一次扫描。`revision` 由调用方（CatalogRepository，revision 唯一拥有者）分配。
    /// 返回的 ScanTask 用于幂等取消。
    func scan(configuration: ScanConfiguration,
              revision: CatalogRevision,
              completion: @escaping @Sendable (CatalogScanResult) -> Void) -> ScanTask
}

/// 扫描任务句柄：幂等取消；`isCancelled` 供扫描器条目间检查。
public final class ScanTask: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelledFlag = false

    /// 是否已请求取消。线程安全；扫描器在条目间读取。
    public var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelledFlag
    }

    /// 请求取消。幂等：重复调用无副作用；取消后 `isCancelled` 恒为 true。
    public func cancel() {
        lock.lock()
        cancelledFlag = true
        lock.unlock()
    }
}
