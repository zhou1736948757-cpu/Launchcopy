// AppIconPipeline — 底层加载（wave1-interfaces.md §D）
// 默认实现只经公开 NSWorkspace API 读系统运行时图标：无磁盘缓存、不复制进资源/fixture/发布包。
// IconIdentity 不透明（不可还原原文）→ 无 resolver 时无法定位具体 app，
// 返回系统通用应用图标（公开 API NSWorkspace.icon(for: UTType.application)）。

import AppCatalogCore
import AppKit
import Foundation
import UniformTypeIdentifiers

/// 底层图标加载协议（可注入 fake loader；测试资源隔离 §10.4）。
public protocol IconLoading: Sendable {
    func load(key: IconKey) async throws -> NSImage
}

/// 默认加载器：仅 NSWorkspace 公开 API 运行时读取。
public struct SystemIconLoader: IconLoading {
    private let resolver: (@Sendable (IconIdentity) -> URL?)?

    /// 冻结契约构造：返回系统通用应用图标。
    public init() {
        self.resolver = nil
    }

    /// 附加构造（不破坏冻结的 `init()`）：装配层注入 identity → URL 解析后，
    /// 仍仅经 `NSWorkspace.icon(forFile:)` 公开 API 运行时读取；无磁盘缓存。
    public init(resolver: @escaping @Sendable (IconIdentity) -> URL?) {
        self.resolver = resolver
    }

    public func load(key: IconKey) async throws -> NSImage {
        let workspace = NSWorkspace.shared
        if let resolver, let url = resolver(key.identity) {
            return workspace.icon(forFile: url.path)
        }
        return workspace.icon(for: UTType.application)
    }
}
