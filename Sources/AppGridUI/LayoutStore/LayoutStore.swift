// AppGridUI — LayoutStore.LayoutStore（Phase 1F §3.2/§6.1 / ADR-009 Q4–Q7/Q10/Q11）
// 实现：T-1F-B（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 版本化 layout store 的公开面：协议 + 结果/状态类型 + storeDirectory 注入抽象。
// - 生产默认目录 = Application Support 下独立中性子目录（ADR-009 Q5）；测试一律注入
//   temp root，绝不触碰真实 Application Support。
// - 隐私：本文件不产生任何输出；错误/状态载荷全部中性（无路径/无布局正文/无原值）。
// - 序列化/反序列化 `PersistentWorkspaceLayout` 走 `LayoutStoreCodec`（schema v1）；
//   FolderID 经受控投影（UUID storage 只进布局文件这一受控例外，ADR-009 Q3/Q12）。

import Foundation

// MARK: - 结果与状态类型

/// 启动读入结果（ADR-009 Q6/Q7）。
public enum LayoutStoreLoadResult: Equatable, Sendable {
    /// 主槽（A）有效并加载。
    case loaded(PersistentWorkspaceLayout, writeGeneration: UInt64)
    /// 主槽坏/缺失、备槽（B）有效：加载 last-known-good；损坏证据保留，下次成功写才轮换。
    case loadedFromBackup(PersistentWorkspaceLayout, writeGeneration: UInt64)
    /// 首启无任何槽文件：调用方以 catalog 构建确定性默认布局（不报错）。
    case firstLaunch
    /// 只读保护（双坏/超限/未知未来版本）：证据保留，持久化暂停，reset 才重建。
    case readOnlyProtection(LayoutStoreReadOnlyReason)
}

/// 只读保护原因（中性；不含路径/正文）。
public enum LayoutStoreReadOnlyReason: Equatable, Sendable {
    /// 双槽均损坏/不可解析（已 quarantine 中性命名，证据保留）。
    case bothSlotsCorrupt
    /// 载荷超工程上限（1 MiB / 512 folders / 10,000 refs / 2,048 members）。
    case exceedsLimits
    /// 未知未来 schemaVersion（绝不降级覆盖写入）。
    case unknownFutureVersion(Int)
}

/// store 持久化状态（ADR-009 Q10）。
public enum LayoutStoreState: Equatable, Sendable {
    /// 正常：最近一次写成功（或尚无写）。
    case healthy
    /// 持久化降级：写失败/超限拒写；内存已提交布局仍权威，LKG 绝不清除；后续成功写自动清除。
    case persistenceDegraded(LayoutStoreDegradation)
    /// 只读保护：启动读入发现双坏/超限/未知未来版本；持久化暂停，reset 才重建。
    case readOnlyProtection(LayoutStoreReadOnlyReason)
}

/// 降级原因（中性）。
public enum LayoutStoreDegradation: Equatable, Sendable {
    /// 写失败（含重试次数；有界重试已耗尽，pending 保留待 flush/下次 enqueue 再试）。
    case writeFailed(retryCount: Int)
    /// 超限拒写（ADR-009 Q4：超限 → 拒写 + PERSISTENCE_DEGRADED + 中性 UI 提示）。
    case rejectedOverLimit
}

/// flush barrier 结果（有界；幂等）。
public enum LayoutStoreFlushResult: Equatable, Sendable {
    /// pending 写已同步落盘。
    case persisted(writeGeneration: UInt64)
    /// 无 pending 写。
    case nothingPending
    /// 有界等待超时（在途持久化未在时限内完成）。
    case timedOut
    /// 只读保护态：不写盘。
    case readOnly
    /// 写失败（重试耗尽）。
    case failed
    /// 多实例 last-writer-wins：本实例 layout generation 不高于磁盘最新 → 拒绝落盘（stale）。
    case staleRejected
    /// 超限拒写。
    case rejectedOverLimit
}

/// reset 结果（ADR-009 Q11）。
public enum LayoutStoreResetResult: Equatable, Sendable {
    /// 已归档旧文件（中性命名 `*.reset-<stamp>`）并立即持久化默认布局。
    case reset(writeGeneration: UInt64)
    /// 失败（归档或默认写失败）。
    case failed
}

/// 多实例锁模式（ADR-009 Q6 显式裁决）。
public enum LayoutStoreLockMode: Equatable, Sendable {
    /// 本实例持有文件锁：single-writer，直接写。
    case singleWriter
    /// 检测到同机另一实例持有锁：降级 explicit last-writer-wins（仅更高 layout generation 可落盘）。
    case lastWriterWins
}

// MARK: - LayoutStore 协议

/// 版本化 layout store（ADR-009 Q5/Q6：可注入协议；生产实现 = actor 串行）。
public protocol LayoutStore: Sendable {
    /// 注入的 store 目录（测试断言 temp root 用；生产 = Application Support 中性子目录）。
    var storeDirectory: URL { get }

    /// 启动读入：首启无文件 → `.firstLaunch`（不报错）；corrupt/unknown version → 只读保护，
    /// 证据保留不自动覆盖。幂等（重复调用返回首次分类结果）。
    func load() async -> LayoutStoreLoadResult

    /// 入队持久化（coalescing sink：合并 pending 写，latest-wins；绝不乱序）。
    /// 只读保护态 → no-op（持久化暂停）。不阻塞调用方热路径。
    func enqueue(_ layout: PersistentWorkspaceLayout) async

    /// 有界 flush barrier：等待在途持久化完成（带超时），随后同步落盘 pending 写。幂等。
    func flush() async -> LayoutStoreFlushResult

    /// Archive journal evidence and persist the default after earlier owned I/O finishes.
    /// Concurrent resets execute in actor admission order. Reset supersedes earlier
    /// pending intentions; enqueues admitted afterward coalesce as successors and
    /// drain after the last reset. A timed-out flush does not cancel this ownership.
    func reset(defaultLayout: PersistentWorkspaceLayout) async -> LayoutStoreResetResult

    /// 当前持久化状态。
    func currentState() async -> LayoutStoreState

    /// 当前多实例锁模式。
    func lockMode() async -> LayoutStoreLockMode

    /// 中性计数器：stale 拒绝次数（ADR-009 Q12 允许的中性遥测）。
    func staleRejectionCount() async -> UInt64
}

// MARK: - storeDirectory 注入抽象（ADR-009 Q5）

/// store 目录解析抽象：生产 = Application Support 中性子目录；测试注入 temp root。
public protocol LayoutStoreDirectoryProviding: Sendable {
    func resolveStoreDirectory() throws -> URL
}

/// 生产默认：`<Application Support>/PagingPrototypeLayout/`（独立中性子目录；文件名中性）。
/// 明确不选：Launchpad/Dock 私有路径、Documents/Desktop/iCloud、/tmp、源码目录（ADR-009 Q5）。
public struct ApplicationSupportLayoutStoreDirectory: LayoutStoreDirectoryProviding {
    public let subdirectoryName: String

    public init(subdirectoryName: String = "PagingPrototypeLayout") {
        self.subdirectoryName = subdirectoryName
    }

    public func resolveStoreDirectory() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: true)
        return base.appendingPathComponent(subdirectoryName, isDirectory: true)
    }
}
