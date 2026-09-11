//
//  ActivationSettingsTests.swift
//  PagingUITests
//
//  Phase 1G §9.8 Preferences（9 项）纯逻辑部分：
//  default all system-wide triggers Off；encode/decode round trip；invalid enum fallback Off；
//  future schema safe behavior；isolated suite（纯模型，无 UserDefaults）；reset activation
//  settings only；changing corner stops old service before new service；shortcut rollback；
//  no coordinates/app data in defaults。
//  注：UserDefaults 持久化与独立 suite 由 T-G-P3 ActivationPreferences 负责（PLAN §7）；
//  本套件只测纯值模型与状态机逻辑，不触碰任何真实 defaults。
//

import XCTest
@testable import PagingPrototypeApp

final class ActivationSettingsTests: XCTestCase {

    // MARK: §9.8-1 default all system-wide triggers Off

    func testDefaultsAllSystemWideTriggersOff() {
        let settings = ActivationSettings()
        XCTAssertFalse(settings.hotCornerEnabled, "Hot Corner 默认 Off")
        XCTAssertNil(settings.selectedCorner)
        XCTAssertFalse(settings.globalShortcutEnabled, "全局快捷键默认 Off")
        XCTAssertNil(settings.shortcut)
        XCTAssertTrue(settings.showStatusItem, "status item 是应用内入口，默认显示")
        XCTAssertFalse(settings.launchAtLoginEnabled, "D4：Launch at Login 默认 Off")
        XCTAssertEqual(settings.schemaVersion, ActivationSettings.currentSchemaVersion)
        XCTAssertEqual(ActivationSettings.currentSchemaVersion, 2)
    }

    // MARK: §9.8-2 encode/decode round trip

    func testEncodeDecodeRoundTrip() throws {
        var settings = ActivationSettings()
        settings.hotCornerEnabled = true
        settings.selectedCorner = .topLeft
        settings.globalShortcutEnabled = true
        settings.shortcut = ShortcutSpec(keyCode: 3, modifiers: [.command, .shift])
        settings.showStatusItem = false
        settings.launchAtLoginEnabled = true

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ActivationSettings.self, from: data)
        XCTAssertEqual(decoded, settings)
        XCTAssertTrue(decoded.hotCornerEnabled)
        XCTAssertEqual(decoded.selectedCorner, .topLeft)
        XCTAssertTrue(decoded.globalShortcutEnabled)
        XCTAssertEqual(decoded.shortcut, ShortcutSpec(keyCode: 3, modifiers: [.command, .shift]))
        XCTAssertFalse(decoded.showStatusItem)
        XCTAssertTrue(decoded.launchAtLoginEnabled)
    }

    func testSchemaV1PayloadMigratesLaunchAtLoginDefaultOff() throws {
        // v1 载荷无 launchAtLoginEnabled → decode 补 false（store 层另做 schema bump）
        let json = """
        {"schemaVersion":1,"hotCornerEnabled":false,"globalShortcutEnabled":false,"showStatusItem":true}
        """
        let decoded = try JSONDecoder().decode(ActivationSettings.self, from: Data(json.utf8))
        XCTAssertFalse(decoded.launchAtLoginEnabled)
        XCTAssertEqual(decoded.schemaVersion, 1)
    }

    // MARK: §9.8-3 invalid enum fallback Off

    func testInvalidCornerFallsBackOff() throws {
        let json = """
        {"schemaVersion":1,"hotCornerEnabled":true,"selectedCorner":"middle",
         "globalShortcutEnabled":false,"showStatusItem":true}
        """
        let decoded = try JSONDecoder().decode(ActivationSettings.self, from: Data(json.utf8))
        XCTAssertNil(decoded.selectedCorner, "非法角 → nil")
        XCTAssertFalse(decoded.hotCornerEnabled, "非法角 → 安全 Off，不崩溃")
    }

    func testInvalidShortcutFallsBackOff() throws {
        let json = """
        {"schemaVersion":1,"hotCornerEnabled":false,"globalShortcutEnabled":true,
         "shortcut":null,"showStatusItem":true}
        """
        let decoded = try JSONDecoder().decode(ActivationSettings.self, from: Data(json.utf8))
        XCTAssertNil(decoded.shortcut)
        XCTAssertFalse(decoded.globalShortcutEnabled, "无表示 → 安全 Off")
    }

    // MARK: §9.8-4 future schema safe behavior

    func testFutureSchemaReturnsSafeDefaults() throws {
        let json = """
        {"schemaVersion":999,"hotCornerEnabled":true,"selectedCorner":"topLeft",
         "globalShortcutEnabled":true,"showStatusItem":false}
        """
        let decoded = try JSONDecoder().decode(ActivationSettings.self, from: Data(json.utf8))
        // 未来 schema：旧代码不静默覆盖，返回安全默认（全部 Off）
        XCTAssertEqual(decoded, ActivationSettings())
        XCTAssertFalse(decoded.hotCornerEnabled)
        XCTAssertFalse(decoded.globalShortcutEnabled)
        XCTAssertTrue(decoded.showStatusItem)
    }

    // MARK: §9.8-5 isolated suite（纯模型，无 UserDefaults）

    func testModelIsPureAndTransportAgnostic() throws {
        // 模型不依赖任何 UserDefaults suite：JSON 字符串直接解码即可（内存传输）
        let json = """
        {"schemaVersion":1,"hotCornerEnabled":true,"selectedCorner":"bottomRight",
         "globalShortcutEnabled":false,"showStatusItem":true}
        """
        let decoded = try JSONDecoder().decode(ActivationSettings.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.selectedCorner, .bottomRight)
        // 编码同样不触碰 defaults
        let data = try JSONEncoder().encode(decoded)
        XCTAssertFalse(data.isEmpty)
        // 真实 defaults 持久化与独立 suite 由 T-G-P3 ActivationPreferences 负责（PLAN §7）
    }

    // MARK: §9.8-6 reset activation settings only

    func testResetActivationOnly() {
        var settings = ActivationSettings()
        settings.hotCornerEnabled = true
        settings.selectedCorner = .topRight
        settings.globalShortcutEnabled = true
        settings.shortcut = ShortcutSpec(keyCode: 3, modifiers: [.command])
        settings.showStatusItem = false
        settings.launchAtLoginEnabled = true

        let reset = settings.resetActivation()
        XCTAssertFalse(reset.hotCornerEnabled)
        XCTAssertNil(reset.selectedCorner)
        XCTAssertFalse(reset.globalShortcutEnabled)
        XCTAssertNil(reset.shortcut)
        XCTAssertEqual(reset.showStatusItem, false, "reset activation 不动 status item 偏好")
        XCTAssertTrue(reset.launchAtLoginEnabled, "reset activation 不动 launch at login 偏好")
        XCTAssertEqual(reset.schemaVersion, settings.schemaVersion)
        // 原值不变（值语义）
        XCTAssertTrue(settings.hotCornerEnabled)
    }

    // MARK: §9.8-7 changing corner stops old service before new service

    func testChangingCornerStopsOldServiceBeforeNew() {
        let clock = HotCornerSystemClock()
        let geometry = ScreenGeometrySnapshot(screens: [
            ScreenGeometrySnapshot.Screen(id: ScreenID(index: 0),
                                          frame: LauncherRect(origin: LauncherPoint(x: 0, y: 0),
                                                              size: LauncherSize(width: 1000, height: 800)),
                                          scale: 1.0),
        ])
        var machine = HotCornerStateMachine(
            parameters: HotCornerParameters(zoneSize: 20, dwellDuration: 0.5,
                                            hysteresisInset: 10, cooldown: 2.0),
            clock: clock,
            geometry: geometry
        )
        machine.enable(corner: .topLeft)
        _ = machine.sample(pointer: LauncherPoint(x: 5, y: 795))
        if case .insideCandidate(let corner, let screenID, _) = machine.state {
            XCTAssertEqual(corner, .topLeft)
            XCTAssertEqual(screenID, ScreenID(index: 0))
        } else {
            XCTFail("expected insideCandidate, got \(machine.state)")
        }

        // 换 corner：旧服务（topLeft dwell）先停，新服务从 armed 开始
        machine.enable(corner: .topRight)
        XCTAssertEqual(machine.state, .armed, "换 corner 取消旧 dwell，不残留")
        XCTAssertEqual(machine.selectedCorner, .topRight)
        XCTAssertEqual(machine.triggerCount, 0)
    }

    // MARK: §9.8-8 shortcut rollback

    func testShortcutRollbackKeepsOldRegistration() {
        let old = ShortcutSpec(keyCode: 3, modifiers: [.command])
        let new = ShortcutSpec(keyCode: 4, modifiers: [.command, .option])
        let registration = ShortcutRegistration(spec: old, outcome: .configured)
        XCTAssertTrue(registration.isConfigured)

        // 新注册冲突/不可用 → 保留旧注册（rollback，不悄悄丢掉）
        XCTAssertEqual(registration.applying(.conflict, for: new), registration)
        XCTAssertEqual(registration.applying(.unavailable, for: new), registration)
        XCTAssertEqual(registration.applying(.conflict, for: new).spec, old)

        // 新注册成功 → 替换
        let configured = registration.applying(.configured, for: new)
        XCTAssertEqual(configured.spec, new)
        XCTAssertEqual(configured.outcome, .configured)

        // 注销
        XCTAssertEqual(configured.unregistered(), ShortcutRegistration(spec: nil, outcome: nil))
        XCTAssertFalse(configured.unregistered().isConfigured)
    }

    // MARK: §9.8-9 no coordinates/app data in defaults

    func testNoCoordinatesOrAppDataInDefaults() throws {
        var settings = ActivationSettings()
        settings.hotCornerEnabled = true
        settings.selectedCorner = .topLeft
        settings.globalShortcutEnabled = true
        settings.shortcut = ShortcutSpec(keyCode: 3, modifiers: [.command])

        let data = try JSONEncoder().encode(settings)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let keys: Set<String> = object.map { Set($0.keys) } ?? []

        // 只允许中性字段：无 pointer 坐标、无 screen ID/名称、无前台 app、无按键历史、无窗口标题
        let allowed: Set<String> = ["schemaVersion", "hotCornerEnabled", "selectedCorner",
                                    "globalShortcutEnabled", "shortcut", "showStatusItem",
                                    "launchAtLoginEnabled"]
        XCTAssertTrue(keys.isSubset(of: allowed), "持久化字段必须是中性白名单，实际: \(keys)")

        // ShortcutSpec 同样只含中性键码/修饰键
        let shortcutData = try JSONEncoder().encode(settings.shortcut!)
        let shortcutObject = try JSONSerialization.jsonObject(with: shortcutData) as? [String: Any]
        let shortcutKeys: Set<String> = shortcutObject.map { Set($0.keys) } ?? []
        XCTAssertEqual(shortcutKeys, ["keyCode", "modifiers"], "快捷键只存中性表示，不存按键文本")
    }
}
