//
//  ActivationSettings.swift
//  PagingPrototypeApp
//
//  Phase 1G 激活设置纯值模型（T-1G-A 纯逻辑；§9.8 Preferences 纯逻辑部分）。
//  PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT §3.10：默认全部系统级 trigger Off；decode
//  非法值回到安全 Off 不崩溃；unknown future schema 不被旧代码静默覆盖；reset activation
//  与 reset layout 是两个动作；不保存 pointer coordinates/screen ID/前台 app/按键历史/
//  窗口标题/搜索词/app identity。
//  Phase 1H T-1H-A：schema v2 增加 launchAtLoginEnabled（D4 默认 Off）。
//  注意：UserDefaults 持久化与独立 suite 由 T-G-P3 的 ActivationPreferences 负责（PLAN §7）；
//  本模型是纯值契约，测试不触碰任何真实 defaults。
//

import Foundation

/// 激活设置纯值模型（Codable；安全解码）。
public struct ActivationSettings: Codable, Equatable, Sendable {
    /// Schema v2：新增 `launchAtLoginEnabled`（默认 Off）。
    public static let currentSchemaVersion: Int = 2

    public var schemaVersion: Int
    public var hotCornerEnabled: Bool
    public var selectedCorner: HotCorner?
    public var globalShortcutEnabled: Bool
    public var shortcut: ShortcutSpec?
    public var showStatusItem: Bool
    /// Launch at Login 用户开关（D4：默认 Off；真实 SMAppService 由后续任务接线）。
    public var launchAtLoginEnabled: Bool

    /// 默认：全部系统级 trigger Off（shortcut Off、Hot Corner Off）；Launch at Login Off。
    public init() {
        schemaVersion = Self.currentSchemaVersion
        hotCornerEnabled = false
        selectedCorner = nil
        globalShortcutEnabled = false
        shortcut = nil
        showStatusItem = true
        launchAtLoginEnabled = false
    }

    /// 安全解码：非法枚举/缺失表示 → 安全 Off，不崩溃；未来 schema → 安全默认（不静默覆盖）。
    /// v1 载荷缺失 `launchAtLoginEnabled` → false（迁移由持久化层在 store schema 上确认）。
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        guard version <= Self.currentSchemaVersion else {
            // 未来 schema：旧代码不静默覆盖，返回安全默认（全部 Off）。
            self = ActivationSettings()
            return
        }
        schemaVersion = version
        hotCornerEnabled = try container.decodeIfPresent(Bool.self, forKey: .hotCornerEnabled) ?? false
        let cornerRaw = try container.decodeIfPresent(String.self, forKey: .selectedCorner)
        selectedCorner = cornerRaw.flatMap(HotCorner.init(rawValue:))
        if selectedCorner == nil {
            hotCornerEnabled = false // 非法角 → 安全 Off
        }
        globalShortcutEnabled = try container.decodeIfPresent(Bool.self, forKey: .globalShortcutEnabled) ?? false
        shortcut = try container.decodeIfPresent(ShortcutSpec.self, forKey: .shortcut)
        if shortcut == nil {
            globalShortcutEnabled = false // 无表示 → 安全 Off
        }
        showStatusItem = try container.decodeIfPresent(Bool.self, forKey: .showStatusItem) ?? true
        launchAtLoginEnabled = try container.decodeIfPresent(Bool.self, forKey: .launchAtLoginEnabled) ?? false
    }

    /// 只重置激活 trigger（hot corner / shortcut）；showStatusItem / launchAtLoginEnabled 保留。
    /// reset activation 与 reset layout 是两个动作（layout 由 Phase 1F layout store 管辖）。
    public func resetActivation() -> ActivationSettings {
        var copy = self
        copy.hotCornerEnabled = false
        copy.selectedCorner = nil
        copy.globalShortcutEnabled = false
        copy.shortcut = nil
        return copy
    }
}
