//
//  ScanFailure.swift
//  MacAppCatalog
//
//  Phase 1B — 扫描失败分类与扫描报告（wave1-interfaces.md §C）。
//  隐私硬边界（Explorer C 约束 / §10.3）：报告**只含计数**，不含任何路径/名称/ID 原文——
//  telemetry 边界在分类处即保证（§5.2 要点 ②）。失败详情仅在进程内错误传递中流转。
//

import Foundation

/// 失败分类（仅计数；无路径/名称/ID 原文）。
/// 每类只累计整数，绝不携带定位信息 —— 即使报告被写入日志也不会泄露目录布局。
public enum ScanFailureKind: String, Sendable, Equatable, CaseIterable {
    /// 目录枚举失败（权限不足/不存在/IO 错误）。根与子目录同样计数。
    case unreadableDirectory
    /// `Contents/Info.plist` 存在但不可读或不可解析（损坏 plist）。
    case corruptedBundle
    /// plist 合法但缺 `CFBundleIdentifier`（软失败：该 app 仍以 canonical URL fallback 身份入册，§5.2 规则 4）。
    case missingBundleIdentifier
    /// 目录以 `.app` 结尾但不是有效 bundle（无 `Contents/Info.plist`），不入册。
    case invalidAppBundle
    /// 跟随目录 symlink 时检测到回边（祖先链重复）——防无限递归；默认不跟随因此通常为 0。
    case symlinkCycleDetected
}

/// 一次扫描的匿名报告：只有计数与时长，无任何敏感原文（§3.3 / §10.3）。
public struct ScanReport: Sendable, Equatable {
    /// 成功入册的 app 记录数（含缺 bundle ID 的 fallback 记录）。
    public let appCount: Int
    /// 失败分类计数（不含定位信息）。
    public let failureCounts: [ScanFailureKind: Int]
    /// 扫描总耗时（秒）；供 telemetry `scan_duration_ms` 派生（Explorer C）。
    public let scanDuration: TimeInterval

    public init(appCount: Int, failureCounts: [ScanFailureKind: Int], scanDuration: TimeInterval) {
        self.appCount = appCount
        self.failureCounts = failureCounts
        self.scanDuration = scanDuration
    }
}
