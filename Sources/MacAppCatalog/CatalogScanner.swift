//
//  CatalogScanner.swift
//  MacAppCatalog
//
//  Phase 1B — CatalogScanning 的具体实现（§5.2 / wave1-interfaces.md §C）。
//  - 受限根枚举：递归遍历**目录**，`.app` bundle 是遍历终点（stopAtAppBundle）；
//  - 读取公开 Bundle metadata（Contents/Info.plist 的 CFBundleIdentifier / CFBundleName）；
//  - 失败分类只计数（无路径原文）；
//  - 条目间检查取消；取消 → 丢弃部分快照；
//  - 默认不跟随目录 symlink；跟随开启时以祖先链检测回边（symlinkCycleDetected）。
//  扫描在专用串行队列（qos .utility）上执行，远离 UI/手势热路径（§5.2 / §7）。
//

@preconcurrency import Foundation
import AppCatalogCore

// MARK: - Bundle metadata 读取（internal，可注入以实现确定性中途取消测试）

/// 单个 bundle 的 metadata 读取结果（分类 + 可选标识）。
internal enum BundleMetadataResult: Sendable {
    /// plist 合法；identifier 为 nil = 缺 CFBundleIdentifier（软失败，走 URL fallback 身份）。
    case valid(identifier: String?, displayName: String?)
    /// `Contents/Info.plist` 存在但不可读/不可解析。
    case corrupted
    /// 无 `Contents/Info.plist`（不是有效 bundle）。
    case missingInfoPlist
}

/// metadata 读取抽象：internal 注入点（默认实现 = BundleMetadataReader）。
/// 仅测试用于确定性中途取消（读完第 N 个 bundle 后 cancel 任务）。
internal protocol BundleMetadataReading: Sendable {
    func readBundleMetadata(at url: URL, fileManager: FileManager) -> BundleMetadataResult
}

/// 默认实现：只经公开文件系统 API 读取 bundle 内 `Contents/Info.plist`，不触碰 Launchpad/Dock 私有库。
internal struct BundleMetadataReader: BundleMetadataReading {
    func readBundleMetadata(at url: URL, fileManager: FileManager) -> BundleMetadataResult {
        let infoPlist = url.appendingPathComponent("Contents/Info.plist")
        guard fileManager.fileExists(atPath: infoPlist.path) else { return .missingInfoPlist }
        guard let data = try? Data(contentsOf: infoPlist) else { return .corrupted }
        guard let plist = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] else {
            return .corrupted
        }
        // 空字符串 bundle ID 视同缺失（无法承担主身份）。
        let rawIdentifier = plist["CFBundleIdentifier"] as? String
        let identifier = (rawIdentifier?.isEmpty == false) ? rawIdentifier : nil
        let name = plist["CFBundleName"] as? String
        return .valid(identifier: identifier, displayName: name)
    }
}

// MARK: - 扫描器

/// 受限根目录的 `.app` 枚举扫描器。线程安全：scan 可并发调用，各次扫描在串行队列上排队执行。
public final class CatalogScanner: CatalogScanning, @unchecked Sendable {
    private let queue: DispatchQueue
    private let metadataReader: any BundleMetadataReading

    public init() {
        self.metadataReader = BundleMetadataReader()
        self.queue = DispatchQueue(label: "PagingPrototype.CatalogScanner.\(UUID().uuidString)", qos: .utility)
    }

    /// 测试注入：自定义 metadata 读取器（如确定性中途取消）。
    internal init(metadataReader: any BundleMetadataReading) {
        self.metadataReader = metadataReader
        self.queue = DispatchQueue(label: "PagingPrototype.CatalogScanner.\(UUID().uuidString)", qos: .utility)
    }

    public func scan(configuration: ScanConfiguration,
                     revision: CatalogRevision,
                     completion: @escaping @Sendable (CatalogScanResult) -> Void) -> ScanTask {
        let task = ScanTask()
        queue.async { [self, configuration, task] in
            let result = performScan(configuration: configuration, revision: revision, task: task)
            completion(result)
        }
        return task
    }

    // MARK: 扫描主体

    private func performScan(configuration: ScanConfiguration,
                             revision: CatalogRevision, task: ScanTask) -> CatalogScanResult {
        let start = Date()
        let fileManager = configuration.fileManager
        var failureCounts: [ScanFailureKind: Int] = [:]
        var records: [AppRecord] = []

        var roots = configuration.roots
        if configuration.dedupeOverlappingRoots {
            roots = Self.dedupeRoots(roots)
        }

        var ancestors: Set<URL> = []   // 当前下降路径（已解析）；回边检测
        var visited: Set<URL> = []     // 已完整遍历的目录（已解析）；防重复遍历

        for (rootIndex, root) in roots.enumerated() {
            guard !task.isCancelled else { break }
            // 一律以「已解析」URL 枚举：Foundation 的 contentsOfDirectory(at:) 不跟随末级 symlink
            // （ENOTDIR），且统一解析后 canonical URL/内含性判定自洽。
            let resolvedRoot = root.resolvingSymlinksInPath().standardizedFileURL
            ancestors.insert(resolvedRoot)
            visited.insert(resolvedRoot)
            walk(directory: resolvedRoot, root: resolvedRoot, rootPriority: rootIndex,
                 configuration: configuration, fileManager: fileManager,
                 task: task, failureCounts: &failureCounts, records: &records,
                 ancestors: &ancestors, visited: &visited)
            ancestors.remove(resolvedRoot)
        }

        let report = ScanReport(appCount: records.count, failureCounts: failureCounts,
                                scanDuration: Date().timeIntervalSince(start))
        guard !task.isCancelled else {
            // 中途取消：部分结果整体丢弃（快照 nil），仅计数照常回报。
            return CatalogScanResult(snapshot: nil, report: report, cancelled: true)
        }
        // 原始记录承载（canonical URL 去重/排序由 CatalogRepository 以其 policy 经 CatalogBuilder 收敛）。
        let draft = CatalogSnapshot(revision: revision, records: records)
        return CatalogScanResult(snapshot: draft, report: report, cancelled: false)
    }

    /// 深度优先遍历：目录递归；`.app` 为终点（默认）；条目间检查取消。
    private func walk(directory: URL, root: URL, rootPriority: Int,
                      configuration: ScanConfiguration, fileManager: FileManager,
                      task: ScanTask, failureCounts: inout [ScanFailureKind: Int],
                      records: inout [AppRecord],
                      ancestors: inout Set<URL>, visited: inout Set<URL>) {
        guard !task.isCancelled else { return }

        let entries: [URL]
        do {
            entries = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles])
        } catch {
            failureCounts[.unreadableDirectory, default: 0] += 1
            return
        }

        for entry in entries {
            guard !task.isCancelled else { return }
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let isSymlink = values?.isSymbolicLink ?? false
            // 注意：同时请求 isDirectoryKey + isSymbolicLinkKey 时，symlink 的 isDirectory 返回链接自身
            // 的类型（恒 false）；必须解析目标后再判定目录性，否则 symlink 目录会被静默跳过
            // （cycle 检测与目录遍历都会失效）。
            var isDirectory = values?.isDirectory ?? false
            if isSymlink {
                isDirectory = (try? entry.resolvingSymlinksInPath()
                    .resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            }
            let isAppCandidate = entry.pathExtension == "app"

            if isAppCandidate {
                // `.app` 目录是遍历终点（stopAtAppBundle=true 时绝不进入 bundle 内部 → helper 不可见）。
                if isSymlink && !configuration.followDirectorySymlinks {
                    continue // 默认不跟随 symlink 的 bundle
                }
                // 顶层 `.app` 总是入册（§5.2 规则 4 的 fallback 身份也在此产生）。
                processBundle(entry, root: root, rootPriority: rootPriority,
                              configuration: configuration, fileManager: fileManager,
                              failureCounts: &failureCounts, records: &records)
                if !configuration.stopAtAppBundle {
                    // 显式关闭 stopAtAppBundle：进入 bundle 内部继续遍历（调用方放弃 §5.2 默认安全行为）。
                    descend(entry, root: root, rootPriority: rootPriority, configuration: configuration,
                            fileManager: fileManager, task: task, failureCounts: &failureCounts,
                            records: &records, ancestors: &ancestors, visited: &visited)
                }
                continue
            }

            if isDirectory {
                descend(entry, root: root, rootPriority: rootPriority, configuration: configuration,
                        fileManager: fileManager, task: task, failureCounts: &failureCounts,
                        records: &records, ancestors: &ancestors, visited: &visited)
            }
            // 其余（普通文件）忽略
        }
    }

    /// 进入一个目录（含 symlink 策略与回边检测）。
    private func descend(_ directory: URL, root: URL, rootPriority: Int,
                         configuration: ScanConfiguration, fileManager: FileManager,
                         task: ScanTask, failureCounts: inout [ScanFailureKind: Int],
                         records: inout [AppRecord],
                         ancestors: inout Set<URL>, visited: inout Set<URL>) {
        guard !task.isCancelled else { return }

        let resolved = directory.resolvingSymlinksInPath().standardizedFileURL
        if ancestors.contains(resolved) {
            // 回边：跟随 symlink 走到了当前路径上的祖先目录 → 防无限递归。
            failureCounts[.symlinkCycleDetected, default: 0] += 1
            return
        }
        if visited.contains(resolved) {
            // 已完整遍历过（真实路径或另一 symlink 到达）→ 不重复遍历（防 DAG 膨胀/重复记录）。
            return
        }
        ancestors.insert(resolved)
        visited.insert(resolved)
        // 以已解析 URL 枚举（见 performScan 注释：contentsOfDirectory 不跟随末级 symlink）。
        walk(directory: resolved, root: root, rootPriority: rootPriority,
             configuration: configuration, fileManager: fileManager, task: task,
             failureCounts: &failureCounts, records: &records,
             ancestors: &ancestors, visited: &visited)
        ancestors.remove(resolved)
    }

    /// 处理单个 `.app`：读 metadata → 分类（计数）→ 构造记录。
    private func processBundle(_ bundleURL: URL, root: URL, rootPriority: Int,
                               configuration: ScanConfiguration, fileManager: FileManager,
                               failureCounts: inout [ScanFailureKind: Int],
                               records: inout [AppRecord]) {
        let canonical = URLNormalizer.canonicalize(bundleURL, under: root) ?? bundleURL.standardizedFileURL
        switch metadataReader.readBundleMetadata(at: bundleURL, fileManager: fileManager) {
        case .missingInfoPlist:
            failureCounts[.invalidAppBundle, default: 0] += 1
        case .corrupted:
            failureCounts[.corruptedBundle, default: 0] += 1
        case .valid(let identifier, let displayName):
            if identifier == nil {
                // 软失败：仍以 canonical URL fallback 身份入册（§5.2 规则 4），同时计数供 telemetry。
                failureCounts[.missingBundleIdentifier, default: 0] += 1
            }
            let name = displayName ?? bundleURL.deletingPathExtension().lastPathComponent
            let appID = identifier.map { AppID.bundleIdentifier($0) }
                ?? AppID.canonicalURLFallback(canonical)
            records.append(AppRecord(id: appID, displayName: name, bundleIdentifier: identifier,
                                     canonicalURL: canonical, iconIdentity: .from(appID: appID),
                                     sourceRootPriority: rootPriority))
        }
    }

    // MARK: 重叠根去重

    /// 去重重叠根：按出现顺序保留；若某根被先前的根包含（或与之相同）则丢弃；
    /// 若新根包含先前保留的根，则移除被包含者（如 [Utilities, System/Applications] → 仅保留后者）。
    internal static func dedupeRoots(_ roots: [URL]) -> [URL] {
        var result: [URL] = []
        for root in roots {
            let standardized = root.standardizedFileURL
            let alreadyCovered = result.contains { URLNormalizer.isContained(standardized, in: $0) }
            if alreadyCovered { continue }
            result.removeAll { URLNormalizer.isContained($0, in: standardized) }
            result.append(standardized)
        }
        return result
    }
}
