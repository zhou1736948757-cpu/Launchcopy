//
//  ScanConfiguration.swift
//  MacAppCatalog
//
//  Phase 1B — 扫描配置（wave1-interfaces.md §C，签名冻结）。
//  FileManager 仅用于测试注入（§H 待决点 4：Sendable 细节编译期处理——
//  本文件以 @preconcurrency import 弱化 Foundation 非 Sendable 类型的检查）。
//

@preconcurrency import Foundation

/// 一次扫描的完整配置。默认值即生产路径（隐私上界，§3.3/§5.2）。
/// §H 待决点 4：`fileManager: FileManager`（非 Sendable）是冻结接口的一部分；
/// `@unchecked Sendable` 为该编译期冲突的处理（接口形状不变：仍为 Sendable 结构）。
public struct ScanConfiguration: @unchecked Sendable {
    /// 扫描根；默认 = 四个受限根（CatalogRoots.defaults）。
    public var roots: [URL] = CatalogRoots.defaults

    /// 去重重叠根：例如 `/System/Applications/Utilities` ⊂ `/System/Applications` 时移除前者，
    /// 防止同一目录被枚举两次（§5.2「实现可以去重重叠根」）。
    public var dedupeOverlappingRoots: Bool = true

    /// 是否跟随目录 symlink。默认 false —— 防 symlink cycle（§5.2「防 symlink cycle」）。
    /// 跟随开启时（仅测试/显式配置），扫描器以「已解析路径祖先链」检测回边并分类为
    /// `ScanFailureKind.symlinkCycleDetected`（仅计数，无路径原文）。
    public var followDirectorySymlinks: Bool = false

    /// 识别 `.app` 后是否不进入其 bundle 内部（§5.2「识别 .app 后不继续进入其 bundle 内部」）。
    /// 默认 true：`.app` 目录是遍历终点，内嵌 helper（Contents/Helpers/*.app）绝不被当作顶层 app（§10.3）。
    /// 显式 false 时扫描器会进入 bundle 内部继续遍历（调用方显式放弃该安全行为）。
    public var stopAtAppBundle: Bool = true

    /// 枚举使用的 FileManager；仅测试注入（如 chmod 不可读目录的可控模拟）。生产路径使用 `.default`。
    /// §H 待决点 4：FileManager 非 Sendable —— @preconcurrency 抑制该冻结字段的检查（接口形状不变）。
    @preconcurrency public var fileManager: FileManager

    public init(roots: [URL] = CatalogRoots.defaults,
                dedupeOverlappingRoots: Bool = true,
                followDirectorySymlinks: Bool = false,
                stopAtAppBundle: Bool = true,
                fileManager: FileManager = .default) {
        self.roots = roots
        self.dedupeOverlappingRoots = dedupeOverlappingRoots
        self.followDirectorySymlinks = followDirectorySymlinks
        self.stopAtAppBundle = stopAtAppBundle
        self.fileManager = fileManager
    }
}
