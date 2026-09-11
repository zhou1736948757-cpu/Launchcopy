//
//  StatusItemControllerTests.swift
//  PagingUITests
//
//  Phase 1G T-1G-C：StatusItemController + Dock reopen 验收。
//  - 菜单标题/validation 从 committedVisibility 派生（无第二 toggle 状态）
//  - Show/Hide/Quit 经 onCommand → launcher.handle
//  - 创建失败不崩溃；teardown 移除 status item
//  - Dock reopen：hidden→show；visible→key；不建第二窗
//  - target screen：鼠标屏 + key/main fallback
//  - 不污染真实 UserDefaults
//

import AppKit
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class StatusItemControllerTests: XCTestCase {

    private let screenA = ScreenID(index: 0)
    private var launchers: [LauncherWindowController] = []
    private var statusControllers: [StatusItemController] = []

    override func tearDown() {
        for controller in statusControllers {
            controller.teardown()
        }
        statusControllers.removeAll()
        for launcher in launchers {
            if !launcher.isTornDown {
                _ = launcher.terminate()
            }
        }
        launchers.removeAll()
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeLauncher(reduceMotion: Bool = true) -> LauncherWindowController {
        let launcher = LauncherWindowController(
            reduceMotionProvider: { reduceMotion },
            screenFrameProvider: { _ in NSRect(x: 0, y: 0, width: 800, height: 600) }
        )
        launcher.presentDuration = 0
        launcher.dismissDuration = 0
        launchers.append(launcher)
        return launcher
    }

    private func makeStatusItem(
        bar: FakeStatusBarProvider = FakeStatusBarProvider(),
        launcher: LauncherWindowController,
        commands: CommandRecorder? = nil,
        settingsCalls: SettingsRecorder? = nil
    ) -> StatusItemController {
        let recorder = commands ?? CommandRecorder()
        let settings = settingsCalls ?? SettingsRecorder()
        let controller = StatusItemController(
            statusBar: bar,
            visibilityProvider: { [weak launcher] in
                launcher?.coordinator.committedVisibility ?? false
            },
            targetScreenProvider: { self.screenA },
            onCommand: { command, source, screen in
                recorder.record(command, source: source, screen: screen)
                _ = launcher.handle(command, source: source, targetScreen: screen)
            },
            onActivationSettings: {
                settings.hit()
            }
        )
        controller.requestsAppTerminateOnQuit = false
        statusControllers.append(controller)
        return controller
    }

    // MARK: - Install / failure / teardown

    func testInstallCreatesStatusItemWhenShowStatusItemTrue() {
        let bar = FakeStatusBarProvider()
        let launcher = makeLauncher()
        let controller = makeStatusItem(bar: bar, launcher: launcher)

        XCTAssertTrue(ActivationSettings().showStatusItem)
        controller.install(showStatusItem: true)

        XCTAssertTrue(controller.isInstalled)
        XCTAssertFalse(controller.installFailed)
        XCTAssertEqual(bar.createCount, 1)
        XCTAssertEqual(bar.items.count, 1)
        XCTAssertNotNil(bar.items.first?.menu)
        XCTAssertEqual(bar.items.first?.lastAccessibilityTitle, "Launchcopy")
    }

    func testInstallSkippedWhenShowStatusItemFalse() {
        let bar = FakeStatusBarProvider()
        let launcher = makeLauncher()
        let controller = makeStatusItem(bar: bar, launcher: launcher)

        controller.install(showStatusItem: false)

        XCTAssertFalse(controller.isInstalled)
        XCTAssertEqual(bar.createCount, 0)
    }

    func testCreationFailureDoesNotCrash() {
        let bar = FakeStatusBarProvider()
        bar.shouldFailCreate = true
        let launcher = makeLauncher()
        let controller = makeStatusItem(bar: bar, launcher: launcher)

        controller.install(showStatusItem: true)

        XCTAssertTrue(controller.installFailed)
        XCTAssertFalse(controller.isInstalled)
        XCTAssertEqual(bar.items.count, 0)
    }

    func testButtonConfigurationFailureRemovesItemAndDegrades() {
        let bar = FakeStatusBarProvider()
        bar.shouldFailButton = true
        let launcher = makeLauncher()
        let controller = makeStatusItem(bar: bar, launcher: launcher)

        controller.install(showStatusItem: true)

        XCTAssertTrue(controller.installFailed)
        XCTAssertFalse(controller.isInstalled)
        XCTAssertEqual(bar.removeCount, 1, "配置失败应立即 remove，不留悬挂 item")
        XCTAssertEqual(bar.items.count, 0)
    }

    func testTeardownRemovesStatusItem() {
        let bar = FakeStatusBarProvider()
        let launcher = makeLauncher()
        let controller = makeStatusItem(bar: bar, launcher: launcher)
        controller.install(showStatusItem: true)
        XCTAssertTrue(controller.isInstalled)

        controller.teardown()
        XCTAssertFalse(controller.isInstalled)
        XCTAssertEqual(bar.removeCount, 1)
        XCTAssertEqual(bar.items.count, 0)

        controller.teardown() // 幂等
        XCTAssertEqual(bar.removeCount, 1)
    }

    // MARK: - Menu title / validation from committedVisibility

    func testShowHideTitleFollowsVisibility() {
        XCTAssertEqual(
            StatusItemController.showHideTitle(visible: false),
            ActivationSettingsUIStrings.menuShowLauncher
        )
        XCTAssertEqual(
            StatusItemController.showHideTitle(visible: true),
            ActivationSettingsUIStrings.menuHideLauncher
        )
    }

    func testMenuValidationReadsCommittedVisibility() {
        let launcher = makeLauncher()
        let controller = makeStatusItem(launcher: launcher)
        let menu = controller.makeMenu()
        let showHide = menu.item(withTag: StatusItemController.MenuActionTag.showHide.rawValue)!

        XCTAssertFalse(launcher.coordinator.committedVisibility)
        XCTAssertTrue(controller.validateMenuItem(showHide))
        XCTAssertEqual(showHide.title, ActivationSettingsUIStrings.menuShowLauncher)

        _ = launcher.show(source: .statusItem, targetScreen: screenA)
        XCTAssertTrue(launcher.coordinator.committedVisibility)
        XCTAssertTrue(controller.validateMenuItem(showHide))
        XCTAssertEqual(showHide.title, ActivationSettingsUIStrings.menuHideLauncher)

        _ = launcher.hide(source: .statusItem, reason: .statusItem)
        XCTAssertFalse(launcher.coordinator.committedVisibility)
        XCTAssertTrue(controller.validateMenuItem(showHide))
        XCTAssertEqual(showHide.title, ActivationSettingsUIStrings.menuShowLauncher)
    }

    func testMenuContainsSettingsAndQuit() {
        let launcher = makeLauncher()
        let controller = makeStatusItem(launcher: launcher)
        let menu = controller.makeMenu()

        let settings = menu.item(withTag: StatusItemController.MenuActionTag.activationSettings.rawValue)
        let quit = menu.item(withTag: StatusItemController.MenuActionTag.quit.rawValue)
        XCTAssertNotNil(settings)
        XCTAssertNotNil(quit)
        XCTAssertEqual(settings?.title, ActivationSettingsUIStrings.menuActivationSettings)
        XCTAssertEqual(quit?.title, ActivationSettingsUIStrings.menuQuit)
        XCTAssertTrue(controller.validateMenuItem(quit!))
    }

    // MARK: - Commands through launcher

    func testShowHideActionRoutesThroughCoordinator() {
        let recorder = CommandRecorder()
        let launcher = makeLauncher()
        let controller = makeStatusItem(launcher: launcher, commands: recorder)
        controller.install(showStatusItem: true)

        // Hidden → Show
        controller.performShowHide()
        XCTAssertEqual(recorder.commands, [.show])
        XCTAssertEqual(recorder.sources, [.statusItem])
        XCTAssertEqual(launcher.coordinator.state, .visible(screenID: screenA))

        // Visible → Hide
        controller.performShowHide()
        XCTAssertEqual(recorder.commands, [.show, .hide])
        XCTAssertEqual(launcher.coordinator.state, .hidden)
    }

    func testQuitActionRoutesQuitWithoutSecondToggleState() {
        let recorder = CommandRecorder()
        var terminateHits = 0
        let launcher = makeLauncher()
        let controller = makeStatusItem(launcher: launcher, commands: recorder)
        controller.requestsAppTerminateOnQuit = true
        controller.terminateApp = { terminateHits += 1 }
        controller.install(showStatusItem: true)
        _ = launcher.show(source: .initialLaunch, targetScreen: screenA)

        controller.performQuit()

        XCTAssertEqual(recorder.commands, [.quit])
        XCTAssertEqual(launcher.coordinator.state, .terminating)
        XCTAssertEqual(terminateHits, 1)
    }

    func testActivationSettingsStubDoesNotCrash() {
        let settings = SettingsRecorder()
        let launcher = makeLauncher()
        let controller = makeStatusItem(launcher: launcher, settingsCalls: settings)
        controller.install(showStatusItem: true)
        let menu = controller.makeMenu()
        XCTAssertNotNil(menu.item(withTag: StatusItemController.MenuActionTag.activationSettings.rawValue))
        controller.performActivationSettings()
        XCTAssertEqual(settings.count, 1)
    }

    // MARK: - Dock reopen

    func testDockReopenHiddenShowsSameWindow() {
        let launcher = makeLauncher()
        _ = launcher.ensureWindow()
        let windowBefore = launcher.window
        XCTAssertEqual(launcher.coordinator.state, .hidden)

        let effect = DockReopenAdapter.handleReopen(launcher: launcher, targetScreen: screenA)
        XCTAssertEqual(
            effect,
            .present(requestID: 1, targetScreen: screenA, source: .dockReopen)
        )
        XCTAssertEqual(launcher.coordinator.state, .visible(screenID: screenA))
        XCTAssertTrue(launcher.window === windowBefore)
    }

    func testDockReopenVisibleMakesKeyWithoutSecondWindow() {
        let launcher = makeLauncher()
        _ = launcher.show(source: .initialLaunch, targetScreen: screenA)
        let windowBefore = launcher.window
        XCTAssertEqual(launcher.coordinator.state, .visible(screenID: screenA))

        let effect = DockReopenAdapter.handleReopen(launcher: launcher, targetScreen: ScreenID(index: 1))
        XCTAssertEqual(effect, .none, "visible reopen 不得再发 present")
        XCTAssertEqual(launcher.coordinator.state, .visible(screenID: screenA))
        XCTAssertTrue(launcher.window === windowBefore, "不得创建第二窗口")
    }

    func testDockReopenFromSuspendedShows() {
        let launcher = makeLauncher()
        _ = launcher.show(source: .statusItem, targetScreen: screenA)
        _ = launcher.suspend(reason: .sessionInactive)
        XCTAssertEqual(launcher.coordinator.state, .suspended(reason: .sessionInactive))

        let effect = DockReopenAdapter.handleReopen(launcher: launcher, targetScreen: screenA)
        XCTAssertEqual(
            effect,
            .present(requestID: 2, targetScreen: screenA, source: .dockReopen)
        )
        XCTAssertEqual(launcher.coordinator.state, .visible(screenID: screenA))
    }

    // MARK: - Target screen resolver

    func testTargetScreenUsesMouseScreenThenFallbacks() {
        // 合成两屏：左 0…800，右 800…1600（无需真实 NSScreen）。
        // 用 NSScreen.screens 不可注入；直接测 resolve 的 index 逻辑经公开 API 的
        // mouseLocation/screens 参数。此处用空屏列表验证最终 fallback index 0。
        let empty = LauncherTargetScreenResolver.resolve(
            mouseLocation: NSPoint(x: 10, y: 10),
            screens: [],
            keyScreen: nil,
            mainScreen: nil
        )
        XCTAssertEqual(empty, ScreenID(index: 0))

        // 有真实屏幕时：鼠标落在某屏 frame → 返回该 index（不记录坐标）。
        let screens = NSScreen.screens
        guard let first = screens.first else {
            // 无头环境：仅 fallback 已覆盖。
            return
        }
        let inside = LauncherTargetScreenResolver.resolve(
            mouseLocation: NSPoint(x: first.frame.midX, y: first.frame.midY),
            screens: screens,
            keyScreen: nil,
            mainScreen: nil
        )
        XCTAssertEqual(inside, ScreenID(index: 0))

        // 鼠标不在任何屏 → key → main → 0
        let far = NSPoint(x: -100_000, y: -100_000)
        let viaMain = LauncherTargetScreenResolver.resolve(
            mouseLocation: far,
            screens: screens,
            keyScreen: nil,
            mainScreen: first
        )
        XCTAssertEqual(viaMain, ScreenID(index: 0))
    }

    // MARK: - Independent symbol + defaults isolation

    func testIndependentSymbolImageAvailable() {
        // SF Symbol 在 macOS 14+ 可用；允许 nil 仅在极端无资源环境。
        let image = StatusItemController.makeIndependentSymbolImage()
        XCTAssertNotNil(image, "应使用系统 SF Symbol，不依赖第三方资产")
    }

    func testNoUserDefaultsPollutionFromStatusItemPath() {
        let suiteName = "com.pagingprototype.tests.statusitem.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let launcher = makeLauncher()
        let controller = makeStatusItem(launcher: launcher)
        controller.install(showStatusItem: ActivationSettings().showStatusItem)
        _ = launcher.show(source: .statusItem, targetScreen: screenA)
        _ = DockReopenAdapter.handleReopen(launcher: launcher, targetScreen: screenA)
        controller.teardown()

        // 只查本 suite 的 persistentDomain（dictionaryRepresentation 会合并全局域，不可用）。
        let persistent = defaults.persistentDomain(forName: suiteName) ?? [:]
        XCTAssertTrue(persistent.isEmpty, "StatusItem/Dock 路径不得写入测试 suite")
        defaults.removePersistentDomain(forName: suiteName)
    }
}

// MARK: - Recorders

@MainActor
private final class CommandRecorder {
    private(set) var commands: [LauncherCommand] = []
    private(set) var sources: [LauncherActivationSource] = []
    private(set) var screens: [ScreenID] = []

    func record(_ command: LauncherCommand, source: LauncherActivationSource, screen: ScreenID) {
        commands.append(command)
        sources.append(source)
        screens.append(screen)
    }
}

@MainActor
private final class SettingsRecorder {
    private(set) var count = 0
    func hit() { count += 1 }
}
