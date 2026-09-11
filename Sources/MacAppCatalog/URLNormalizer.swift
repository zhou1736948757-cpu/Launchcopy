//
//  URLNormalizer.swift
//  MacAppCatalog
//
//  Phase 1B — URL 规范化与根内含性（wave1-interfaces.md §C；§5.2 规则 1）。
//  同一 canonical URL 视为同一对象：规范化 = standardized（消解 ".."、重复斜杠等），
//  不做 symlink 解析（保持「按发现路径」的稳定身份；symlink 跟随策略由 ScanConfiguration 控制）。
//

import Foundation

/// URL 规范化工具。
public enum URLNormalizer {
    /// 规范化 `url`（standardized）并校验其位于 `root` 之内；不在根内返回 nil。
    /// - 规范化使用 `standardizedFileURL`（消解 `.`/`..`/重复分隔符，不解析 symlink）。
    /// - 根内含性使用「根路径 + 尾斜杠」前缀判定，避免 `/Applications` 误纳 `/ApplicationsX`。
    public static func canonicalize(_ url: URL, under root: URL) -> URL? {
        let standardized = url.standardizedFileURL
        guard isContained(standardized, in: root) else { return nil }
        return standardized
    }

    /// `url` 是否位于 `root` 之内（含相等：根自身也算包含）。
    /// 边界处理：
    /// - `root` 为标准化的绝对路径（`standardizedFileURL.path`，无尾斜杠）；
    /// - 相等 → true；
    /// - 严格子路径 → 必须带 `/` 前缀（`u == r + "/…"`），防止前缀陷阱（`/ApplicationsX` ⊄ `/Applications`）。
    public static func isContained(_ url: URL, in root: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        if path == rootPath { return true }
        // 根为文件系统根（"/"）时一切都在其内；但扫描上界禁止扫描 "/"，此处仅为判定完备。
        guard rootPath != "/" else { return path.hasPrefix("/") }
        return path.hasPrefix(rootPath + "/")
    }
}
