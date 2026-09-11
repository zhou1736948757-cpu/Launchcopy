// AppGridUI — LayoutDomain.PersistentAppReference（Phase 1F §3.1 / ADR-009 Q2 方案 1）
// 实现：T-1F-A（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 独立持久引用 DTO，**不等于 AppID**：bundle-ID 主 + canonical path 确定性 fallback。
// - 只经 `AppRecord` 公开面构建（bundleIdentifier / canonicalURL）——**绝不读取 AppID.storage**
//   （ADR-004 安全边界；AppID 对 LayoutDomain 是不透明身份，仅用于同模块既有呈现层桥接）。
// - **禁止身份来源**：Swift Hasher / displayName / redactedDescription（进程内不稳定 /
//   用户可见名可变 / 设计为不可逆）；本类型不含 displayName，也不提供 hash 值参与身份。
// - fallback 存储为确定性稳定串：`standardizedFileURL.path` 归一化（去尾部 "/"、大小写
//   规范化），比较与匹配一律基于该稳定串（大小写不敏感、忽略尾部 "/"，ADR-009 Q2）。
// - 显式 `comparisonKey` 取代一切 hashValue：bundle-ID 键 < path fallback 键，同类串升序
//   （镜像 AppID 锚点全序语义——但这是持久比较键，非进程内 hash）。
// - 隐私边界：bundle ID / path 原值只允许进入布局文件这一受控例外（T-1F-B 落盘），
//   绝不进 telemetry/JSONL/stdout/signpost/profile/report。

import AppCatalogCore
import Foundation

/// 持久 app 引用：bundle-ID 主；无 bundle ID → deterministic canonical path fallback。
public enum PersistentAppReference: Equatable, Sendable {
    case bundleID(String)
    case canonicalPath(String)   // 已归一化的稳定串（见 normalizedPath）

    /// 从 `AppRecord` 公开面构建（bundle ID 空/缺失 → fallback）。
    public static func from(record: AppRecord) -> PersistentAppReference {
        if let bundleID = record.bundleIdentifier, !bundleID.isEmpty {
            return .bundleID(bundleID)
        }
        return .canonicalPath(normalizedPath(record.canonicalURL))
    }

    /// 确定性比较键（持久顺序/唯一性裁决专用；禁 hashValue）。
    /// bundle-ID 键 < path fallback 键；同类按字符串升序。
    public var comparisonKey: String {
        switch self {
        case .bundleID(let id): return "bundle:" + id
        case .canonicalPath(let path): return "path:" + path
        }
    }

    /// 记录是否命中本引用（匹配用同一稳定串语义；多实例 catalog 取首个命中，调用方保证确定性）。
    public func matches(record: AppRecord) -> Bool {
        switch self {
        case .bundleID(let id):
            return record.bundleIdentifier == id
        case .canonicalPath(let path):
            return PersistentAppReference.normalizedPath(record.canonicalURL) == path
        }
    }

    /// 归一化：去 symlink 语义沿用 `standardizedFileURL`（ADR-004 既有），再统一大小写与尾部 "/"。
    public static func normalizedPath(_ url: URL) -> String {
        var path = url.standardizedFileURL.path
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path.lowercased()
    }
}
