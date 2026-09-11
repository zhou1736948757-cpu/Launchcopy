// AppIconPipeline — IconKey（wave1-interfaces.md §D）
// Key 不含 catalog revision（revision 用于 UI apply 资格，不使 cache key 失效）；
// 仅含不透明 IconIdentity → 天然不含 bundle ID 原文 / 路径 / 哈希（Explorer C 约束）。

import AppCatalogCore
import Foundation

/// 图标外观变体。当前仅系统外观；预留扩展点（实验证明需要再加）。
public enum AppearanceVariant: Hashable, Sendable {
    case system
}

/// 图标缓存/加载键：identity + 请求尺寸 + 显示 scale + 外观。
/// 不含 revision、不含 bundle ID 原文、不含路径/哈希（隐私硬边界）。
/// description 一律脱敏：不透出 identity 原文（防调试日志/telemetry 意外泄露）。
public struct IconKey: Hashable, Sendable, CustomStringConvertible {
    public let identity: IconIdentity
    public let pointSize: Double
    public let displayScale: Double
    public let appearance: AppearanceVariant

    /// 像素尺寸（pt × scale）；缓存 cost 估计的输入之一。
    public var pixelSize: Double { pointSize * displayScale }

    public init(identity: IconIdentity, pointSize: Double, displayScale: Double,
                appearance: AppearanceVariant = .system) {
        self.identity = identity
        self.pointSize = pointSize
        self.displayScale = displayScale
        self.appearance = appearance
    }

    public var description: String {
        "IconKey(identity: <redacted>, pointSize: \(pointSize), displayScale: \(displayScale), appearance: \(appearance))"
    }
}
