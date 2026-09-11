//
//  StatusItemController.swift
//  PagingPrototypeApp
//
//  Phase 1G T-1G-C：NSStatusBar 菜单栏入口 + Dock reopen adapter。
//  - Show/Hide 标题与 enable 从 LauncherPresentationCoordinator.committedVisibility 派生，
//    不维护第二套 toggle 状态（ADR-011 Q1 / PHASE1G §3.4）。
//  - Quit → launcher.handle(.quit) 后由宿主 terminate；Activation Settings → 宿主 showSettings。
//  - 菜单文案：中文产品名 Launchcopy（Phase 1H D1/D6）。
//  - 创建失败不崩溃（降级保留 Dock reopen / 其他入口）。
//  - target screen：鼠标所在屏，fallback key/main（ADR-011 Q9）。
//  - 隐私：不记录指针坐标、屏幕 UUID/名称、前台 app、窗口标题。
//

import AppKit
import Foundation

// MARK: - Status bar seam（可注入；测试用 Fake，生产用 System）

/// 可移除的 status item 句柄（抽象 NSStatusItem，避免测试依赖真实菜单栏槽位）。
public protocol StatusItemHandle: AnyObject {
    var menu: NSMenu? { get set }
    /// 配置按钮图像 / 标题 / 无障碍标签；button 不可用时返回 false（创建失败降级）。
    @discardableResult
    func configureButton(image: NSImage?, title: String?, accessibilityTitle: String) -> Bool
}

/// Status bar 工厂：创建失败返回 nil（应用不得崩溃）。
public protocol StatusBarProviding: AnyObject {
    func createStatusItem(length: CGFloat) -> StatusItemHandle?
    func removeStatusItem(_ item: StatusItemHandle)
}

/// 生产 status bar（公开 NSStatusBar API）。
public final class SystemStatusBarProvider: StatusBarProviding {
    public init() {}

    public func createStatusItem(length: CGFloat) -> StatusItemHandle? {
        let item = NSStatusBar.system.statusItem(withLength: length)
        return SystemStatusItemHandle(item: item)
    }

    public func removeStatusItem(_ item: StatusItemHandle) {
        guard let system = item as? SystemStatusItemHandle else { return }
        NSStatusBar.system.removeStatusItem(system.item)
    }
}

private final class SystemStatusItemHandle: StatusItemHandle {
    let item: NSStatusItem

    init(item: NSStatusItem) {
        self.item = item
    }

    var menu: NSMenu? {
        get { item.menu }
        set { item.menu = newValue }
    }

    func configureButton(image: NSImage?, title: String?, accessibilityTitle: String) -> Bool {
        guard let button = item.button else { return false }
        button.image = image
        button.image?.isTemplate = true
        // 仅图标在拥挤菜单栏里极易「看不见」；配短标题提高可发现性。
        button.title = title ?? ""
        button.imagePosition = (image != nil && title != nil && !title!.isEmpty) ? .imageLeading : .imageOnly
        button.setAccessibilityTitle(accessibilityTitle)
        return true
    }
}

// MARK: - Target screen（ADR-011 Q9）

/// status item / Dock reopen / shortcut 共用：鼠标所在屏 → key → main → index 0。
/// 入参可注入；省略时在主线程读系统屏列表与鼠标位置。不持久化、不记录坐标原文。
public enum LauncherTargetScreenResolver {
    /// - Note: 无默认实参读 `NSApp`（避免非隔离 default-arg 警告）；生产调用方在主线程调用
    ///   `resolve()` 无参重载，或显式传入可测几何。
    @MainActor
    public static func resolve(
        mouseLocation: NSPoint? = nil,
        screens: [NSScreen]? = nil,
        keyScreen: NSScreen? = nil,
        mainScreen: NSScreen? = nil
    ) -> ScreenID {
        let point = mouseLocation ?? NSEvent.mouseLocation
        let list = screens ?? NSScreen.screens
        let key = keyScreen ?? NSApp.keyWindow?.screen
        let main = mainScreen ?? NSScreen.main
        if let index = list.firstIndex(where: { $0.frame.contains(point) }) {
            return ScreenID(index: index)
        }
        if let key, let index = list.firstIndex(where: { $0 === key }) {
            return ScreenID(index: index)
        }
        if let main, let index = list.firstIndex(where: { $0 === main }) {
            return ScreenID(index: index)
        }
        return ScreenID(index: 0)
    }
}

// MARK: - Dock reopen adapter

/// Dock 图标点击 / reopen：hidden|suspended → show；visible|presenting → makeKey；永不第二窗。
@MainActor
public enum DockReopenAdapter {
    /// - Returns: coordinator effect（visible 路径恒为 `.none`）。
    @discardableResult
    public static func handleReopen(
        launcher: LauncherWindowController,
        targetScreen: ScreenID
    ) -> LauncherPresentationEffect {
        switch launcher.coordinator.state {
        case .hidden, .suspended, .dismissing:
            return launcher.show(source: .dockReopen, targetScreen: targetScreen)
        case .presenting, .visible:
            if let window = launcher.window {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            return .none
        case .terminating:
            return .none
        }
    }
}

// MARK: - StatusItemController

/// 菜单栏入口控制器（强引用 status item；teardown 移除）。
@MainActor
public final class StatusItemController: NSObject, NSMenuItemValidation {

    public enum MenuActionTag: Int {
        case showHide = 1
        case activationSettings = 2
        case quit = 3
    }

    /// committedVisibility 查询（通常 = launcher.coordinator.committedVisibility）。
    public var visibilityProvider: () -> Bool

    /// target screen（通常 = LauncherTargetScreenResolver.resolve）。
    public var targetScreenProvider: () -> ScreenID

    /// 命令出口：Show/Hide/Quit → 宿主转发到 LauncherWindowController.handle。
    public var onCommand: (LauncherCommand, LauncherActivationSource, ScreenID) -> Void

    /// Activation Settings（Phase 1H：宿主打开单实例设置窗；不得崩溃）。
    public var onActivationSettings: () -> Void

    /// Quit 后是否请求进程退出（默认 true；测试可关）。
    public var requestsAppTerminateOnQuit: Bool = true

    /// 退出进程回调（可注入；默认 NSApp.terminate）。
    public var terminateApp: () -> Void = { NSApp.terminate(nil) }

    private let statusBar: StatusBarProviding
    private var statusItem: StatusItemHandle?
    /// 已安装且按钮配置成功。
    public private(set) var isInstalled = false
    /// 创建/配置失败（降级；应用继续）。
    public private(set) var installFailed = false

    public init(
        statusBar: StatusBarProviding = SystemStatusBarProvider(),
        visibilityProvider: @escaping () -> Bool = { false },
        targetScreenProvider: (() -> ScreenID)? = nil,
        onCommand: @escaping (LauncherCommand, LauncherActivationSource, ScreenID) -> Void = { _, _, _ in },
        onActivationSettings: @escaping () -> Void = {}
    ) {
        self.statusBar = statusBar
        self.visibilityProvider = visibilityProvider
        self.targetScreenProvider = targetScreenProvider ?? { LauncherTargetScreenResolver.resolve() }
        self.onCommand = onCommand
        self.onActivationSettings = onActivationSettings
        super.init()
    }

    // MARK: - Lifecycle

    /// 按 `showStatusItem` 安装；false → 不创建；创建失败 → installFailed，不崩溃。
    public func install(showStatusItem: Bool) {
        guard showStatusItem else {
            isInstalled = false
            installFailed = false
            return
        }
        guard statusItem == nil else { return }

        // variableLength：图标 + 「LC」短标题，避免拥挤菜单栏里「只有淡色模板图标」看不见。
        guard let item = statusBar.createStatusItem(length: NSStatusItem.variableLength) else {
            installFailed = true
            isInstalled = false
            return
        }

        let symbol = Self.makeIndependentSymbolImage()
        let configured = item.configureButton(
            image: symbol,
            title: "LC",
            accessibilityTitle: "Launchcopy"
        )
        guard configured else {
            statusBar.removeStatusItem(item)
            installFailed = true
            isInstalled = false
            return
        }

        item.menu = makeMenu()
        statusItem = item
        isInstalled = true
        installFailed = false
    }

    /// 移除 status item 与 target/action 引用（幂等）。
    public func teardown() {
        if let item = statusItem {
            item.menu = nil
            statusBar.removeStatusItem(item)
        }
        statusItem = nil
        isInstalled = false
    }

    // MARK: - Menu

    /// 构建菜单（也可在未安装时供测试直接断言）。
    public func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "Launchcopy")
        menu.autoenablesItems = true

        let showHide = NSMenuItem(
            title: Self.showHideTitle(visible: visibilityProvider()),
            action: #selector(showHideAction(_:)),
            keyEquivalent: ""
        )
        showHide.tag = MenuActionTag.showHide.rawValue
        showHide.target = self
        menu.addItem(showHide)

        let settings = NSMenuItem(
            title: ActivationSettingsUIStrings.menuActivationSettings,
            action: #selector(activationSettingsAction(_:)),
            keyEquivalent: ""
        )
        settings.tag = MenuActionTag.activationSettings.rawValue
        settings.target = self
        menu.addItem(settings)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(
            title: ActivationSettingsUIStrings.menuQuit,
            action: #selector(quitAction(_:)),
            keyEquivalent: ""
        )
        quit.tag = MenuActionTag.quit.rawValue
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    /// Show/Hide 动态标题（committedVisibility；中文产品文案）。
    public static func showHideTitle(visible: Bool) -> String {
        visible
            ? ActivationSettingsUIStrings.menuHideLauncher
            : ActivationSettingsUIStrings.menuShowLauncher
    }

    /// 刷新已安装菜单的 Show/Hide 标题（菜单将开时也可由 validation 驱动）。
    public func refreshMenuTitles() {
        guard let menu = statusItem?.menu else { return }
        if let item = menu.item(withTag: MenuActionTag.showHide.rawValue) {
            item.title = Self.showHideTitle(visible: visibilityProvider())
        }
    }

    // MARK: - NSMenuItemValidation

    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch MenuActionTag(rawValue: menuItem.tag) {
        case .showHide:
            let visible = visibilityProvider()
            menuItem.title = Self.showHideTitle(visible: visible)
            return true
        case .activationSettings, .quit:
            return true
        case nil:
            return true
        }
    }

    // MARK: - Actions

    /// 测试/菜单共用入口（避免测试依赖 `NSApp.sendAction` 在无 GUI runloop 下的可选 action）。
    public func performShowHide() {
        showHideAction(nil)
    }

    public func performActivationSettings() {
        activationSettingsAction(nil)
    }

    public func performQuit() {
        quitAction(nil)
    }

    @objc private func showHideAction(_ sender: Any?) {
        let visible = visibilityProvider()
        let screen = targetScreenProvider()
        // 可见 → hide；隐藏 → show。经同一 onCommand，不本地维护 toggle 位。
        let command: LauncherCommand = visible ? .hide : .show
        onCommand(command, .statusItem, screen)
    }

    @objc private func activationSettingsAction(_ sender: Any?) {
        onActivationSettings()
    }

    @objc private func quitAction(_ sender: Any?) {
        let screen = targetScreenProvider()
        onCommand(.quit, .statusItem, screen)
        if requestsAppTerminateOnQuit {
            terminateApp()
        }
    }

    // MARK: - Symbol

    /// 独立 SF Symbol（不复制第三方资产）。square.grid.2x2 = 中性 launcher 网格意象。
    public static func makeIndependentSymbolImage() -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        return NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "Launchcopy")?
            .withSymbolConfiguration(config)
    }
}

// MARK: - Test fake status bar

/// 测试用 Fake：可模拟创建失败 / 记录 remove（生产路径不使用）。
public final class FakeStatusBarProvider: StatusBarProviding {
    public var shouldFailCreate = false
    public var shouldFailButton = false
    public private(set) var createCount = 0
    public private(set) var removeCount = 0
    public private(set) var items: [FakeStatusItemHandle] = []

    public init() {}

    public func createStatusItem(length: CGFloat) -> StatusItemHandle? {
        createCount += 1
        if shouldFailCreate { return nil }
        let handle = FakeStatusItemHandle(failButton: shouldFailButton)
        items.append(handle)
        return handle
    }

    public func removeStatusItem(_ item: StatusItemHandle) {
        removeCount += 1
        items.removeAll { $0 === item }
    }
}

public final class FakeStatusItemHandle: StatusItemHandle {
    public var menu: NSMenu?
    public var lastImage: NSImage?
    public var lastTitle: String?
    public var lastAccessibilityTitle: String?
    private let failButton: Bool

    public init(failButton: Bool = false) {
        self.failButton = failButton
    }

    public func configureButton(image: NSImage?, title: String?, accessibilityTitle: String) -> Bool {
        if failButton { return false }
        lastImage = image
        lastTitle = title
        lastAccessibilityTitle = accessibilityTitle
        return true
    }
}
