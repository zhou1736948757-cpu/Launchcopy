//
//  TelemetryEvent.swift
//  PagingTelemetry
//
//  Telemetry 事件模型：固定 17 个必需字段（Docs/PHASE1_SPEC.md §6）+
//  Explorer 建议的 4 个可选扩展字段 + Phase 1B 的 7 个可选扩展字段
//  （Explorer C / wave1-interfaces.md §G：snapshot_revision / cell_reuse_count /
//  icon_async_state / icon_cache_count / icon_cache_estimated_cost /
//  catalog_scan_duration_ms / refresh_duration_ms）。
//
//  隐私红线（§3.1.14 / §3.2 / §3.3 / Explorer C）：本模型**没有任何字段**可以承载
//  app 显示名、bundle ID、文件路径、图标字节/哈希或启动 URL —— 全部扩展字段均为
//  匿名数值/枚举；红线由 Tests/PagingTelemetryTests/TelemetryPrivacyRedLineTests.swift
//  以「编码键白名单 + Mirror 属性表面 + 敏感哨兵缺席」三层断言冻结。
//

import Foundation

/// 页面 prepare/cache 结果（对应 PHASE1_SPEC §6 "page prepare/cache hit/miss"）。
public enum PageCacheOutcome: String, Codable, Sendable, Equatable {
    /// 本事件不涉及页面缓存（默认）。
    case notApplicable = "n/a"
    /// 页面命中缓存，直接复用，无重新 prepare。
    case hit
    /// 页面未命中缓存，需要 prepare。
    case miss
}

/// 图标异步状态（Phase 1B 扩展；§6.4 binding token 观测用）。
///
/// 无任何身份信息：不含 icon key、bundle ID、路径或字节（Explorer C 红线）。
/// 原始值即 JSON 值（snake_case），编码/解码稳定。
public enum IconAsyncState: String, Codable, Sendable, Equatable, CaseIterable {
    /// 本事件不涉及图标异步请求。
    case idle
    /// 图标请求已提交、in-flight（含合并到既有 in-flight 的请求）。
    case inflight
    /// 图标加载完成（成功投递或进入缓存）。
    case completed
    /// 图标加载失败（placeholder 路径）。
    case failed
    /// 请求被取消（单 consumer 取消 / cancelAll / shutdown）。
    case cancelled
    /// 过期 completion 被 binding token / generation 拒绝（stale async apply 观测，应为 0）。
    case staleRejected = "stale_rejected"
}

/// 一条 telemetry 事件。
///
/// 字段契约：
/// - 17 个必需字段全部为非可选，编码时**总是出现**，保证每条 JSONL 记录字段完整；
/// - 11 个扩展字段（4 个 Phase 1A + 7 个 Phase 1B）仅在设置时编码；
/// - `gestureID` / `transitionID`：调用方分配（会话内/单调），`0` 表示本事件不适用；
/// - `timestamp`：自 1970-01-01 起的秒数；`0` 表示写入时由 session 盖章为当前时间；
/// - 页面类字段（`semanticCurrentPage` 等）：`-1` 表示不适用；
/// - `interruptionCount` / `staleRejectionCount` / `layoutCount` / `teardownCallbackCount`：
///   会话级累计计数，写入时由 `TelemetrySession` 统一盖章（调用方不必自行维护，
///   通过 `register*` 方法递增）；
/// - `cellReuseCount`：会话级累计 cell 复用计数（Phase 1B），同样由 `TelemetrySession`
///   经 `registerCellReuse()` 盖章；事件显式值优先，未登记过复用时省略（保持可选字段
///   缺省省略语义）。
public struct TelemetryEvent: Codable, Equatable, Sendable {

    // MARK: - 17 个必需字段（PHASE1_SPEC §6）

    /// run ID（写入时由 session 盖章）。
    public var runID: String = ""

    /// 手势会话 ID（调用方分配；0 = 不适用）。
    public var gestureID: UInt64 = 0

    /// 过渡（settle transition）ID（调用方分配；0 = 不适用）。
    public var transitionID: UInt64 = 0

    /// 事件阶段（推荐使用 `TelemetryPhase` 常量；也允许自定义字符串）。
    public var phase: String

    /// 时间戳（1970 秒；0 = 写入时盖章为当前时间）。
    public var timestamp: TimeInterval = 0

    /// 本次输入增量（以 pageWidth 为单位的连续值，有符号；0 = 不适用）。
    public var inputDelta: Double = 0

    /// 视觉偏移（以 pageWidth 为单位的连续值；Core 唯一所有权，ADR-001 D1；0 = 不适用）。
    public var visualOffset: Double = 0

    /// 语义当前页（-1 = 不适用）。
    public var semanticCurrentPage: Int = -1

    /// 释放后提议目标页（-1 = 不适用）。
    public var proposedTarget: Int = -1

    /// 已提交页（仅 settle 自然完成时变化，ADR-001 D1；-1 = 不适用）。
    public var committedPage: Int = -1

    /// 会话累计中断次数（session 盖章）。
    public var interruptionCount: Int = 0

    /// 会话累计 stale completion 拒绝次数（ADR-001 D3；session 盖章）。
    public var staleRejectionCount: Int = 0

    /// 帧间隔（秒，如 0.0167；0 = 不适用）。
    public var frameInterval: TimeInterval = 0

    /// 会话累计布局次数（session 盖章）。
    public var layoutCount: Int = 0

    /// 当前页面承载的 host/view 数量（0 = 不适用）。
    public var pageHostViewCount: Int = 0

    /// 页面 prepare/cache 结果（默认 `n/a`）。
    public var pagePrepareCache: PageCacheOutcome = .notApplicable

    /// 会话累计 teardown callback 次数（ADR-001 D7；session 盖章）。
    public var teardownCallbackCount: Int = 0

    // MARK: - 可选扩展字段（Explorer 建议，可选）

    /// 单调递增 transition token（ADR-001 D3；仅事件涉及 transition 时设置）。
    public var transitionToken: UInt64?

    /// 是否发生了 stale callback 观测（ADR-001 D3 验收观测）。
    public var staleCallbackFired: Bool?

    /// 中断发生时的接管偏移（ADR-001 D4，pageWidth 单位；连续性验证用）。
    public var interruptSourceOffset: Double?

    /// 事件发生时的 Reduce Motion 状态（ADR-001 D8）。
    public var reduceMotionEnabled: Bool?

    // MARK: - Phase 1B 可选扩展字段（Explorer C §G 建议；全部匿名、仅设置时编码）

    /// 事件时的 catalog revision/generation（单调、无身份；§6 snapshot 一致性归因；nil = 不适用）。
    public var snapshotRevision: Int?

    /// 会话累计 cell/host 复用计数（session 经 `registerCellReuse()` 盖章；
    /// nil = 尚未登记复用；§10.6 复用上界证据）。
    public var cellReuseCount: Int?

    /// 图标异步状态（无身份；nil = 本事件不涉及图标）。
    public var iconAsyncState: IconAsyncState?

    /// 图标内存缓存当前条目数（有界 count 上界内；nil = 不适用）。
    public var iconCacheCount: Int?

    /// 图标内存缓存当前估计成本（估计解码成本，非真实字节/哈希；nil = 不适用）。
    public var iconCacheEstimatedCost: Int?

    /// 最近一次 catalog 扫描耗时（毫秒；匿名时序指标，§10.6 热路径外；nil = 不适用）。
    public var catalogScanDurationMS: Double?

    /// 最近一次 refresh（扫描 + snapshot apply）耗时（毫秒；匿名时序指标；nil = 不适用）。
    public var refreshDurationMS: Double?

    public init(phase: String) {
        self.phase = phase
    }

    // 显式 CodingKeys：固定 JSON 键名（snake_case），不依赖编码器策略。
    private enum CodingKeys: String, CodingKey {
        case runID = "run_id"
        case gestureID = "gesture_id"
        case transitionID = "transition_id"
        case phase = "event_phase"
        case timestamp
        case inputDelta = "input_delta"
        case visualOffset = "visual_offset"
        case semanticCurrentPage = "semantic_current_page"
        case proposedTarget = "proposed_target"
        case committedPage = "committed_page"
        case interruptionCount = "interruption_count"
        case staleRejectionCount = "stale_rejection_count"
        case frameInterval = "frame_interval"
        case layoutCount = "layout_count"
        case pageHostViewCount = "page_host_view_count"
        case pagePrepareCache = "page_prepare_cache"
        case teardownCallbackCount = "teardown_callback_count"
        case transitionToken = "transition_token"
        case staleCallbackFired = "stale_callback_fired"
        case interruptSourceOffset = "interrupt_source_offset"
        case reduceMotionEnabled = "reduce_motion_enabled"
        case snapshotRevision = "snapshot_revision"
        case cellReuseCount = "cell_reuse_count"
        case iconAsyncState = "icon_async_state"
        case iconCacheCount = "icon_cache_count"
        case iconCacheEstimatedCost = "icon_cache_estimated_cost"
        case catalogScanDurationMS = "catalog_scan_duration_ms"
        case refreshDurationMS = "refresh_duration_ms"
    }
}

/// 内置事件阶段常量。`TelemetryEvent.phase` 类型为 String，允许调用方扩展自定义阶段。
/// 语义与 ADR-001 状态机契约对齐（gesture/transition/interruption/teardown）。
public enum TelemetryPhase {

    // MARK: run 生命周期

    /// 一次正式 run 开始（session.begin 自动写入）。
    public static let runBegin = "run.begin"

    /// 一次正式 run 结束（session.end 自动写入）。
    public static let runEnd = "run.end"

    // MARK: 手势（ADR-001 D1/D5）

    /// 手势开始（tracking 进入）。
    public static let gestureBegan = "gesture.began"

    /// 手势位移（tracking 中）。
    public static let gestureChanged = "gesture.changed"

    /// 手势释放（→ settling 或回弹）。
    public static let gestureEnded = "gesture.ended"

    /// momentum 子阶段（tracking 子阶段，ADR-001 D1）。
    public static let gestureMomentum = "gesture.momentum"

    /// 手势被系统取消（→ cancelled/idle）。
    public static let gestureCancelled = "gesture.cancelled"

    // MARK: 过渡（ADR-001 D2/D3/D4）

    /// settle 过渡开始（携带 transitionID / transitionToken）。
    public static let transitionBegin = "transition.begin"

    /// settle 自然完成并 commit（token 校验通过，ADR-001 D3）。
    public static let transitionCommit = "transition.commit"

    /// 旧 completion 被 stale token 拒绝（ADR-001 D3 硬门禁 4）。
    public static let transitionStaleRejected = "transition.stale_rejected"

    /// 过渡被取消（中断/resize/pageCount/teardown 路径）。
    public static let transitionCancelled = "transition.cancelled"

    /// 中断发生（settling → interrupted → tracking，ADR-001 D4）。
    public static let interruptionBegan = "interruption.began"

    // MARK: 性能与结构（PHASE1_SPEC §6）

    /// 显示链路帧回调（携带 frameInterval）。
    public static let frame = "frame"

    /// 布局发生（携带 layoutCount）。
    public static let layout = "layout"

    /// 页面 prepare（未命中缓存时）。
    public static let pagePrepare = "page.prepare"

    /// 页面复用（缓存命中时）。
    public static let pageReuse = "page.reuse"

    /// 页面缓存命中。
    public static let pageCacheHit = "page.cache_hit"

    /// 页面缓存未命中。
    public static let pageCacheMiss = "page.cache_miss"

    /// resize / pageWidth 变化（ADR-001 D6）。
    public static let resize = "resize"

    /// pageCount 变化（ADR-001 D6）。
    public static let pageCountChanged = "page_count.changed"

    /// 状态机状态切换（携带语义页字段）。
    public static let stateChanged = "state.changed"

    // MARK: teardown（ADR-001 D7）

    /// teardown 路径中的一次回调执行。
    public static let teardownCallback = "teardown.callback"

    /// teardown 完成（期望之后 callback count 不再增长）。
    public static let teardownComplete = "teardown.complete"
}
