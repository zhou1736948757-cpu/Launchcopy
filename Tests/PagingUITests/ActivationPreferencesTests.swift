//
//  ActivationPreferencesTests.swift
//  PagingUITests
//
//  Phase 1G §9.8 Preferences（9 项）持久化部分（T-G-P3）：
//  default all system-wide triggers Off；encode/decode round trip；invalid enum fallback Off；
//  future schema safe behavior；isolated suite；reset activation settings only；
//  changing corner stops old service before new service（见 ActivationServicePlanTests）；
//  shortcut rollback（见 ActivationServicePlanTests）；no coordinates/app data in defaults。
//  另含 MINOR-2 契约测试（future schema 不被静默覆盖）。
//  全部使用独立 suite（UUID 命名），tearDown 清理，绝不污染真实用户 defaults。
//

import XCTest
@testable import PagingPrototypeApp

final class ActivationPreferencesTests: XCTestCase {

    private var suiteName: String!
    private var store: UserDefaultsActivationPreferencesStore!

    override func setUp() {
        super.setUp()
        suiteName = "com.pagingprototype.activation.tests.\(UUID().uuidString)"
        store = UserDefaultsActivationPreferencesStore(suiteName: suiteName)
        XCTAssertNotNil(store, "专用 suite 创建必须成功")
    }

    override func tearDown() {
        store?.removePersistentDomain()
        store = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: §9.8-1 default all system-wide triggers Off

    func testFreshLoadReturnsProductDefaults() {
        guard case .loaded(let prefs) = store.load() else {
            return XCTFail("全新安装必须 loaded")
        }
        XCTAssertTrue(prefs.fourFingerActivationEnabled,
                      "用户决策 2026-09-05：四指默认开启（覆盖 ADR-013 §7 原锁定 false）")
        XCTAssertEqual(prefs.schemaVersion, ActivationPreferences.currentSchemaVersion)
        XCTAssertEqual(ActivationPreferences.currentSchemaVersion, 2)
        XCTAssertFalse(prefs.settings.hotCornerEnabled, "hot corner 默认 Off")
        XCTAssertNil(prefs.settings.selectedCorner)
        XCTAssertFalse(prefs.settings.globalShortcutEnabled, "global shortcut 默认 Off")
        XCTAssertNil(prefs.settings.shortcut)
        XCTAssertTrue(prefs.settings.showStatusItem, "status item 是应用内入口，默认显示")
        XCTAssertFalse(prefs.settings.launchAtLoginEnabled, "D4：Launch at Login 默认 Off")
    }

    // MARK: §9.8-2 encode/decode round trip

    func testSaveLoadRoundTrip() {
        var prefs = ActivationPreferences()
        prefs.fourFingerActivationEnabled = false
        prefs.settings.hotCornerEnabled = true
        prefs.settings.selectedCorner = .topLeft
        prefs.settings.globalShortcutEnabled = true
        prefs.settings.shortcut = ShortcutSpec(keyCode: 3, modifiers: [.command, .shift])
        prefs.settings.showStatusItem = false
        prefs.settings.launchAtLoginEnabled = true

        XCTAssertEqual(store.save(prefs), .saved)
        guard case .loaded(let loaded) = store.load() else {
            return XCTFail("round trip 必须 loaded")
        }
        // save 规范化 settings.schemaVersion 到当前版本
        prefs.settings.schemaVersion = ActivationSettings.currentSchemaVersion
        XCTAssertEqual(loaded, prefs)
        XCTAssertFalse(loaded.fourFingerActivationEnabled)
        XCTAssertTrue(loaded.settings.hotCornerEnabled)
        XCTAssertEqual(loaded.settings.selectedCorner, .topLeft)
        XCTAssertEqual(loaded.settings.shortcut, ShortcutSpec(keyCode: 3, modifiers: [.command, .shift]))
        XCTAssertFalse(loaded.settings.showStatusItem)
        XCTAssertTrue(loaded.settings.launchAtLoginEnabled)
    }

    func testSaveLoadRoundTripDefaults() {
        let prefs = ActivationPreferences()
        XCTAssertEqual(store.save(prefs), .saved)
        guard case .loaded(let loaded) = store.load() else {
            return XCTFail("round trip 必须 loaded")
        }
        XCTAssertEqual(loaded, prefs)
    }

    // MARK: §9.8-3 invalid enum fallback Off

    func testInvalidFourFingerValueFallsBackOff() {
        // 模拟损坏：fourFinger key 存了非 Bool 类型（String）
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("yes", forKey: "activation.fourFingerActivationEnabled")
        defaults.set(1, forKey: "activation.schemaVersion")

        guard case .loaded(let prefs) = store.load() else {
            return XCTFail("非法布尔值必须安全加载")
        }
        XCTAssertFalse(prefs.fourFingerActivationEnabled, "非法布尔值 → 安全 Off，不崩溃")
    }

    func testCorruptPayloadFallsBackSafeDefaults() {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(1, forKey: "activation.schemaVersion")
        defaults.set(Data("not json".utf8), forKey: "activation.settingsPayload")

        guard case .loaded(let prefs) = store.load() else {
            return XCTFail("损坏载荷必须安全加载")
        }
        XCTAssertEqual(prefs.settings, ActivationSettings(), "损坏载荷 → 安全默认（全部 Off）")
    }

    func testInvalidCornerInPayloadFallsBackOff() {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(1, forKey: "activation.schemaVersion")
        let json = """
        {"schemaVersion":1,"hotCornerEnabled":true,"selectedCorner":"middle",
         "globalShortcutEnabled":false,"showStatusItem":true}
        """
        defaults.set(Data(json.utf8), forKey: "activation.settingsPayload")

        guard case .loaded(let prefs) = store.load() else {
            return XCTFail("非法枚举必须安全加载")
        }
        XCTAssertNil(prefs.settings.selectedCorner, "非法角 → nil")
        XCTAssertFalse(prefs.settings.hotCornerEnabled, "非法角 → 安全 Off，不崩溃")
    }

    // MARK: §9.8-4 future schema safe behavior（MINOR-2 契约）

    func testFutureSchemaLoadPreservesData() {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(999, forKey: "activation.schemaVersion")
        let futurePayload = Data("future-schema-payload".utf8)
        defaults.set(futurePayload, forKey: "activation.settingsPayload")

        let result = store.load()
        guard case .futureSchema(let storedVersion) = result else {
            return XCTFail("未来 schema 必须返回 futureSchema，实际: \(result)")
        }
        XCTAssertEqual(storedVersion, 999)
        // 原值保留：载荷未被解码/改写
        XCTAssertEqual(defaults.data(forKey: "activation.settingsPayload"), futurePayload)
        XCTAssertEqual(defaults.integer(forKey: "activation.schemaVersion"), 999)
    }

    func testFutureSchemaSaveRefused() {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(999, forKey: "activation.schemaVersion")
        let futurePayload = Data("future-schema-payload".utf8)
        defaults.set(futurePayload, forKey: "activation.settingsPayload")

        let result = store.save(ActivationPreferences())
        guard case .refusedFutureSchema(let storedVersion) = result else {
            return XCTFail("未来 schema 必须拒绝写入，实际: \(result)")
        }
        XCTAssertEqual(storedVersion, 999)
        // 不静默覆盖：版本与载荷原样保留，且未写入任何新值
        XCTAssertEqual(defaults.integer(forKey: "activation.schemaVersion"), 999)
        XCTAssertEqual(defaults.data(forKey: "activation.settingsPayload"), futurePayload)
        XCTAssertNil(defaults.object(forKey: "activation.fourFingerActivationEnabled"),
                     "拒绝写入时不得写入任何新值")
    }

    func testCorruptedVersionTreatedAsFresh() {
        // 版本 key 损坏（非 Int）：无法确认真实版本，按全新安装处理（安全默认，允许写入）
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("corrupted", forKey: "activation.schemaVersion")

        guard case .loaded(let prefs) = store.load() else {
            return XCTFail("损坏版本必须安全加载")
        }
        XCTAssertEqual(prefs, ActivationPreferences())
        XCTAssertEqual(store.save(ActivationPreferences()), .saved)
    }

    // MARK: §9.8-5 isolated suite

    func testIsolatedSuiteDoesNotTouchStandardDefaults() {
        var prefs = ActivationPreferences()
        prefs.fourFingerActivationEnabled = true
        prefs.settings.hotCornerEnabled = true
        prefs.settings.selectedCorner = .bottomRight
        _ = store.save(prefs)

        let standardKeys = UserDefaults.standard.dictionaryRepresentation().keys
        let polluted = standardKeys.filter { $0.hasPrefix("activation.") }
        XCTAssertTrue(polluted.isEmpty, "专用 suite 操作不得污染标准 defaults: \(polluted)")
    }

    // MARK: §9.8-6 reset activation settings only

    func testResetActivationClearsOnlyActivationKeys() {
        var prefs = ActivationPreferences()
        prefs.fourFingerActivationEnabled = false
        prefs.settings.hotCornerEnabled = true
        prefs.settings.selectedCorner = .topRight
        _ = store.save(prefs)

        // suite 内放一个外来 key（模拟未来其他 namespace）
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("foreign", forKey: "other.namespace.key")

        store.resetActivation()

        XCTAssertNil(defaults.object(forKey: "activation.schemaVersion"))
        XCTAssertNil(defaults.object(forKey: "activation.fourFingerActivationEnabled"))
        XCTAssertNil(defaults.object(forKey: "activation.settingsPayload"))
        XCTAssertEqual(defaults.string(forKey: "other.namespace.key"), "foreign",
                       "reset 只清 activation namespace，不动 suite 内其他 key")
    }

    func testResetActivationDoesNotTouchLayoutStore() {
        // Phase 1F layout store 是独立 suite：reset activation 不得触碰
        let layoutSuite = "com.pagingprototype.layout.tests.\(UUID().uuidString)"
        let layoutDefaults = UserDefaults(suiteName: layoutSuite)!
        layoutDefaults.set("layout-data", forKey: "layout.key")
        defer { layoutDefaults.removePersistentDomain(forName: layoutSuite) }

        _ = store.save(ActivationPreferences())
        store.resetActivation()

        XCTAssertEqual(layoutDefaults.string(forKey: "layout.key"), "layout-data",
                       "layout store 不受 reset activation 影响")
    }

    func testLoadAfterResetReturnsProductDefaults() {
        var prefs = ActivationPreferences()
        prefs.fourFingerActivationEnabled = false
        prefs.settings.hotCornerEnabled = true
        prefs.settings.selectedCorner = .topLeft
        _ = store.save(prefs)

        store.resetActivation()

        guard case .loaded(let loaded) = store.load() else {
            return XCTFail("reset 后必须 loaded")
        }
        XCTAssertEqual(loaded, ActivationPreferences(),
                       "reset 后回到产品默认（四指默认开启，其余 trigger 全 Off）")
    }

    // MARK: §9.8-9 no coordinates/app data in defaults

    func testNoCoordinatesOrAppDataInDefaults() {
        var prefs = ActivationPreferences()
        prefs.fourFingerActivationEnabled = true
        prefs.settings.hotCornerEnabled = true
        prefs.settings.selectedCorner = .topLeft
        prefs.settings.globalShortcutEnabled = true
        prefs.settings.shortcut = ShortcutSpec(keyCode: 3, modifiers: [.command])
        _ = store.save(prefs)

        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.synchronize() // 确保持久域可见
        let keys = Set(defaults.persistentDomain(forName: suiteName)?.keys ?? [:].keys)
        let allowed: Set<String> = ["activation.schemaVersion",
                                    "activation.fourFingerActivationEnabled",
                                    "activation.settingsPayload"]
        XCTAssertTrue(keys.isSubset(of: allowed), "持久化 key 必须是中性白名单，实际: \(keys)")

        // 载荷 JSON 只含中性字段（无坐标/设备序列号/后台应用身份）
        let payload = defaults.data(forKey: "activation.settingsPayload")!
        let object = try! JSONSerialization.jsonObject(with: payload) as! [String: Any]
        let payloadKeys = Set(object.keys)
        let allowedPayload: Set<String> = ["schemaVersion", "hotCornerEnabled", "selectedCorner",
                                           "globalShortcutEnabled", "shortcut", "showStatusItem",
                                           "launchAtLoginEnabled"]
        XCTAssertTrue(payloadKeys.isSubset(of: allowedPayload),
                      "载荷字段必须是中性白名单，实际: \(payloadKeys)")
    }

    // MARK: 版本写入契约

    func testSaveWritesCurrentSchemaVersion() {
        var prefs = ActivationPreferences()
        prefs.schemaVersion = 999 // 调用方误设未来版本
        XCTAssertEqual(store.save(prefs), .saved)

        let defaults = UserDefaults(suiteName: suiteName)!
        XCTAssertEqual(defaults.integer(forKey: "activation.schemaVersion"),
                       ActivationPreferences.currentSchemaVersion,
                       "存储始终写当前 schema 版本，不写未来版本（避免自锁只读）")
        guard case .loaded(let loaded) = store.load() else {
            return XCTFail("保存后必须可加载")
        }
        XCTAssertEqual(loaded.schemaVersion, ActivationPreferences.currentSchemaVersion)
    }

    // MARK: Schema v1 → v2 migration（T-1H-A）

    func testSchemaV1LoadMigratesLaunchAtLoginDefaultOff() {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(1, forKey: "activation.schemaVersion")
        defaults.set(true, forKey: "activation.fourFingerActivationEnabled")
        let v1JSON = """
        {"schemaVersion":1,"hotCornerEnabled":true,"selectedCorner":"topLeft",
         "globalShortcutEnabled":false,"showStatusItem":true}
        """
        defaults.set(Data(v1JSON.utf8), forKey: "activation.settingsPayload")

        guard case .loaded(let prefs) = store.load() else {
            return XCTFail("v1 必须可迁移加载")
        }
        XCTAssertEqual(prefs.schemaVersion, ActivationPreferences.currentSchemaVersion)
        XCTAssertEqual(prefs.settings.schemaVersion, ActivationSettings.currentSchemaVersion)
        XCTAssertFalse(prefs.settings.launchAtLoginEnabled, "v1 → v2 补 launchAtLoginEnabled=false")
        XCTAssertTrue(prefs.settings.hotCornerEnabled)
        XCTAssertEqual(prefs.settings.selectedCorner, .topLeft)
        XCTAssertTrue(prefs.fourFingerActivationEnabled)

        // 磁盘仍为 v1，直到显式 save；save 后写 v2
        XCTAssertEqual(defaults.integer(forKey: "activation.schemaVersion"), 1)
        XCTAssertEqual(store.save(prefs), .saved)
        XCTAssertEqual(defaults.integer(forKey: "activation.schemaVersion"),
                       ActivationPreferences.currentSchemaVersion)
        guard case .loaded(let reloaded) = store.load() else {
            return XCTFail("迁移保存后必须可加载")
        }
        XCTAssertFalse(reloaded.settings.launchAtLoginEnabled)
        XCTAssertEqual(reloaded.schemaVersion, 2)
    }

    func testSchemaV2PersistsLaunchAtLoginEnabled() {
        var prefs = ActivationPreferences()
        prefs.settings.launchAtLoginEnabled = true
        XCTAssertEqual(store.save(prefs), .saved)

        guard case .loaded(let loaded) = store.load() else {
            return XCTFail("v2 必须 loaded")
        }
        XCTAssertTrue(loaded.settings.launchAtLoginEnabled)
        XCTAssertEqual(loaded.schemaVersion, 2)
    }
}
