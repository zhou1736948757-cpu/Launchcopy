//
//  CatalogRoots.swift
//  MacAppCatalog
//
//  Phase 1B — 受限扫描根（§5.2 / wave1-interfaces.md §C）。
//  默认根 = 隐私上界（Explorer C 约束）：绝不扫描整个 `/`、整个 `~`、网络卷或所有挂载卷。
//  四个受限根全部为 world-readable 或用户自有目录：枚举不需要 Full Disk Access、不需要 TCC。
//

import Foundation

/// 受限扫描根集合。
public enum CatalogRoots {
    /// 默认根（上界，§5.2）：
    /// 1. /Applications            —— 系统级用户应用（world-readable）
    /// 2. /System/Applications     —— 系统自带应用（world-readable）
    /// 3. /System/Applications/Utilities —— 系统工具（world-readable；与 #2 重叠，扫描时按配置去重）
    /// 4. ~/Applications           —— 用户自有应用（无需任何授权）
    ///
    /// 重叠说明：`/System/Applications/Utilities` 是 `/System/Applications` 的子目录；
    /// `ScanConfiguration.dedupeOverlappingRoots` 默认开启，扫描时会按 URLNormalizer 根内含性
    /// 移除被其他根包含的根，避免同一目录被枚举两次。
    public static let defaults: [URL] = [
        URL(fileURLWithPath: "/Applications"),
        URL(fileURLWithPath: "/System/Applications"),
        URL(fileURLWithPath: "/System/Applications/Utilities"),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
    ]
}
