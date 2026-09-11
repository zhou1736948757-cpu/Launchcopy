//
//  ActivationPreferences.swift
//  PagingPrototypeApp
//
//  Phase 1G 激活偏好持久化层（T-G-P3）。
//  PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT §3.10/§9.8/§21.2：
//  - 专用 namespace UserDefaults（独立 suite，与 Phase 1F layout store 分离；绝不触碰真实
//    用户 defaults 的既有 key）；
//  - schema version 字段；decode 前检查原始版本——unknown future schema 不被旧代码静默覆盖
//    （T-1G-A-r1 MINOR-2 契约：读时版本高于当前支持 → 拒绝写入/保留原值/明确错误）；
//  - 非法值回 Off 不崩溃（布尔/枚举非法值 → 安全默认）；
//  - reset activation settings 独立动作（只清 activation namespace，不动 layout store）；
//  - 持久化只写用户开关及获批配置，不写触点/设备序列号/原始坐标/后台应用身份。
//  Phase 1H T-1H-A：schema v2 = settings 增加 launchAtLoginEnabled；v1 → 迁移补 false。
//  纯 Foundation，无 AppKit。
//

import Foundation

/// 激活偏好值模型（用户开关 + 获批配置）。
/// T-1G-A 的 `ActivationSettings` 是纯值契约（不触碰任何 defaults）；本层负责持久化。
public struct ActivationPreferences: Equatable, Sendable {
    /// 当前支持的 schema 版本（v2：settings 含 launchAtLoginEnabled）。
    public static let currentSchemaVersion: Int = 2

    /// 数据 schema 版本（load 时从存储读取；默认当前版本；v1 load 会迁移到当前版本）。
    public var schemaVersion: Int
    /// 四指捏合呼出开关。
    /// 用户决策（Workflow/decisions/2026-09-05-four-finger-user-decisions.md）：**默认开启**，
    /// 覆盖 ADR-013 §7 原锁定 false；默认开启 ≠ 立即启用——仍须后端就绪（Enabled ≠ Ready，
    /// 由 FourFingerActivationState 表达）与物理门通过。
    public var fourFingerActivationEnabled: Bool
    /// 其余获批配置（hot corner / global shortcut / status item / launch at login）。
    public var settings: ActivationSettings

    public init(schemaVersion: Int = ActivationPreferences.currentSchemaVersion,
                fourFingerActivationEnabled: Bool = true,
                settings: ActivationSettings = ActivationSettings()) {
        self.schemaVersion = schemaVersion
        self.fourFingerActivationEnabled = fourFingerActivationEnabled
        self.settings = settings
    }
}

// MARK: - 读取/写入结果

/// load 结果：正常加载，或未来 schema（MINOR-2：保留原值，拒绝写入）。
public enum ActivationPreferencesLoadResult: Equatable, Sendable {
    case loaded(ActivationPreferences)
    /// 存储版本高于当前支持：旧代码不得解码/覆盖，返回明确错误。
    case futureSchema(storedVersion: Int)
}

/// save 结果。
public enum ActivationPreferencesSaveResult: Equatable, Sendable {
    case saved
    /// 存储版本高于当前支持：拒绝写入，不静默覆盖未来 schema 数据。
    case refusedFutureSchema(storedVersion: Int)
}

// MARK: - 持久化协议

/// 持久化协议（窄面；生产用 UserDefaults 实现，测试可用独立 suite 实例）。
public protocol ActivationPreferencesPersisting: AnyObject {
    /// 专用 suite 名。
    var suiteName: String { get }
    /// 读取偏好（decode 前检查原始 schema 版本）。
    func load() -> ActivationPreferencesLoadResult
    /// 写入偏好（未来 schema 拒绝写入）。
    @discardableResult
    func save(_ preferences: ActivationPreferences) -> ActivationPreferencesSaveResult
    /// 只清 activation namespace（不动 layout store 与 suite 内其他 key）。
    func resetActivation()
    /// 彻底清理整个 suite（测试/完整重置用）。
    func removePersistentDomain()
}

// MARK: - In-memory（Settings 测试 / suite 创建失败降级）

/// 内存偏好存储：不触碰 UserDefaults；供测试与 suite 创建失败时的 Settings 会话使用。
public final class InMemoryActivationPreferencesStore: ActivationPreferencesPersisting {
    public let suiteName: String
    private var preferences: ActivationPreferences
    /// 模拟未来 schema 拒绝写入（测试用）。
    public var forcedStoredVersion: Int?

    public init(suiteName: String = "memory.activation",
                initial: ActivationPreferences = ActivationPreferences()) {
        self.suiteName = suiteName
        self.preferences = initial
    }

    public func load() -> ActivationPreferencesLoadResult {
        if let forcedStoredVersion, forcedStoredVersion > ActivationPreferences.currentSchemaVersion {
            return .futureSchema(storedVersion: forcedStoredVersion)
        }
        return .loaded(preferences)
    }

    public func save(_ preferences: ActivationPreferences) -> ActivationPreferencesSaveResult {
        if let forcedStoredVersion, forcedStoredVersion > ActivationPreferences.currentSchemaVersion {
            return .refusedFutureSchema(storedVersion: forcedStoredVersion)
        }
        self.preferences = preferences
        return .saved
    }

    public func resetActivation() {
        preferences = ActivationPreferences()
    }

    public func removePersistentDomain() {
        preferences = ActivationPreferences()
        forcedStoredVersion = nil
    }
}

// MARK: - UserDefaults 实现

/// UserDefaults 实现：专用 suite（默认 `com.pagingprototype.activation`），
/// key 带 `activation.` 前缀（双保险：suite 隔离 + 前缀隔离，绝不触碰真实用户 defaults 既有 key）。
/// Phase 1H：suite 名暂保持 `com.pagingprototype.activation`（产品 Bundle ID 变更不在本任务改 suite）。
public final class UserDefaultsActivationPreferencesStore: ActivationPreferencesPersisting {
    /// 默认专用 suite 名（与 Phase 1F layout store 分离；1H 暂不随 Bundle ID 改名）。
    public static let defaultSuiteName = "com.pagingprototype.activation"

    private enum Key {
        static let schemaVersion = "activation.schemaVersion"
        static let fourFingerActivationEnabled = "activation.fourFingerActivationEnabled"
        static let settingsPayload = "activation.settingsPayload"
    }

    public let suiteName: String
    private let defaults: UserDefaults

    /// 创建专用 suite 存储；suite 创建失败返回 nil（绝不回退到标准 defaults）。
    public init?(suiteName: String = UserDefaultsActivationPreferencesStore.defaultSuiteName) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        self.defaults = defaults
        self.suiteName = suiteName
    }

    // MARK: 读取

    public func load() -> ActivationPreferencesLoadResult {
        // MINOR-2：decode 前检查原始版本。
        guard let storedVersion = defaults.object(forKey: Key.schemaVersion) as? Int else {
            // 全新安装（无版本记录）：产品默认（四指默认开启，其余 trigger 全 Off）。
            return .loaded(ActivationPreferences())
        }
        guard storedVersion <= ActivationPreferences.currentSchemaVersion else {
            // 未来 schema：不解码、不覆盖，明确返回错误（旧代码不得静默抹掉）。
            return .futureSchema(storedVersion: storedVersion)
        }

        // 非法布尔值（非 Bool 类型）→ 安全 Off，不崩溃。
        let fourFinger: Bool
        if let raw = defaults.object(forKey: Key.fourFingerActivationEnabled) as? Bool {
            fourFinger = raw
        } else {
            fourFinger = false
        }

        // 载荷缺失/损坏 → 安全默认（全部 Off）；非法枚举由 ActivationSettings 安全解码处理。
        var settings = ActivationSettings()
        if let data = defaults.data(forKey: Key.settingsPayload),
           let decoded = try? JSONDecoder().decode(ActivationSettings.self, from: data) {
            settings = decoded
        }

        // v1 → v2：补 launchAtLoginEnabled=false，并将内存 schema 提升到当前版本。
        if storedVersion < ActivationPreferences.currentSchemaVersion {
            settings = Self.migrateSettings(settings, fromStoreVersion: storedVersion)
            return .loaded(ActivationPreferences(
                schemaVersion: ActivationPreferences.currentSchemaVersion,
                fourFingerActivationEnabled: fourFinger,
                settings: settings
            ))
        }

        return .loaded(ActivationPreferences(schemaVersion: storedVersion,
                                             fourFingerActivationEnabled: fourFinger,
                                             settings: settings))
    }

    // MARK: 写入

    public func save(_ preferences: ActivationPreferences) -> ActivationPreferencesSaveResult {
        // MINOR-2：写入前再次检查原始版本；未来 schema 拒绝写入，不静默覆盖。
        if let storedVersion = defaults.object(forKey: Key.schemaVersion) as? Int,
           storedVersion > ActivationPreferences.currentSchemaVersion {
            return .refusedFutureSchema(storedVersion: storedVersion)
        }

        // 写出前规范化 settings schema 到当前版本（避免长期残留 v1 标记）。
        var settings = preferences.settings
        settings.schemaVersion = ActivationSettings.currentSchemaVersion

        // 数据先写、版本最后写（提交标记）：中途崩溃不会留下"新版本 + 旧数据"。
        defaults.set(preferences.fourFingerActivationEnabled, forKey: Key.fourFingerActivationEnabled)
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Key.settingsPayload)
        }
        // 存储始终写当前 schema 版本（不写未来版本，避免自锁只读）。
        defaults.set(ActivationPreferences.currentSchemaVersion, forKey: Key.schemaVersion)
        return .saved
    }

    // MARK: 重置

    public func resetActivation() {
        // 只清 activation namespace 三个 key；不动 layout store（不同 suite）与 suite 内其他 key。
        defaults.removeObject(forKey: Key.schemaVersion)
        defaults.removeObject(forKey: Key.fourFingerActivationEnabled)
        defaults.removeObject(forKey: Key.settingsPayload)
    }

    public func removePersistentDomain() {
        defaults.removePersistentDomain(forName: suiteName)
    }

    // MARK: Migration

    /// 将旧 store schema 的 settings 迁移到当前版本。
    /// v1 → v2：显式补 `launchAtLoginEnabled = false` 并 bump settings.schemaVersion。
    static func migrateSettings(_ settings: ActivationSettings,
                                fromStoreVersion storedVersion: Int) -> ActivationSettings {
        var migrated = settings
        if storedVersion < 2 {
            migrated.launchAtLoginEnabled = false
        }
        if migrated.schemaVersion < ActivationSettings.currentSchemaVersion {
            migrated.schemaVersion = ActivationSettings.currentSchemaVersion
        }
        return migrated
    }
}
