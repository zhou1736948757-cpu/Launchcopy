//
//  LauncherWindowController.swift
//  PagingPrototypeApp
//
//  Phase 1G T-1G-B：执行 LauncherPresentationCoordinator 输出的 effect。
//  窗口形态 = ADR-011 Q3 Option B（screen-covering borderless panel，非 native fullscreen Space）。
//  - 一进程最多一个 launcher window assembly；hide 不销毁；terminate/teardown 分离且幂等。
//  - present/dismiss 动画结束（或 Reduce Motion 跳过）后仅对匹配 requestID 调用 completeTransition。
//  - 不拥有键盘/搜索/folder 逻辑；仅暴露 preferredFirstResponder 恢复缝。
//

import AppKit
import Foundation

/// 执行 presentation effect 的单窗控制器（持有并暴露 `LauncherPresentationCoordinator`）。
@MainActor
public final class LauncherWindowController: NSObject {

    /// 纯状态机（UI 层唯一写者入口经本控制器的 handle/quit/terminate/suspend/resume）。
    public private(set) var coordinator: LauncherPresentationCoordinator

    /// 当前 assembly 窗口（attach 或 ensureWindow 后非 nil；teardown 后为 nil）。
    public private(set) var window: NSWindow?

    /// present 时恢复的 first responder（键盘控制器等）；不拥有其生命周期。
    public weak var preferredFirstResponder: NSResponder?

    /// 启动器真正藏起（orderOut）后回调：用于强制关掉设置窗等附属 UI。
    public var onLauncherDidHide: (() -> Void)?

    /// Reduce Motion 查询（可注入；默认系统偏好）。
    public var reduceMotionProvider: () -> Bool

    /// ScreenID → frame 解析（可注入；默认 NSScreen.screens + 确定性 fallback）。
    public var screenFrameProvider: (ScreenID) -> NSRect

    /// 非 RM 下 present/dismiss 动画时长（测试可缩短；RM 时强制 0）。
    public var presentDuration: TimeInterval = 0.18
    public var dismissDuration: TimeInterval = 0.14

    /// Test-only opt-in, set before attach/show. Production behavior is unchanged.
    /// A normal window ordered behind others does not provide background input.
    var backgroundUITestTitle = "Launchcopy — UI Test"
    public var backgroundUITestMode = false
    /// Only the dedicated device harness opts into ordinary-window activation.
    var foregroundWindowedPresentation = false
    var activateWindowedApplication: () -> Void = { NSApp.activate(ignoringOtherApps: false) }

    /// teardown 是否已执行（与 coordinator.teardownCount 对齐的 UI 侧标记）。
    public private(set) var isTornDown = false

    /// 窗口是否处于“用户可见”语义（orderFront 后且未 orderOut；alpha 动画中仍视为可见意图）。
    public var isWindowOrderedIn: Bool {
        guard let window, !isTornDown else { return false }
        return window.isVisible || window.occlusionState.contains(.visible)
    }

    /// 当前 in-flight 动画对应的 requestID；无动画时为 0。用于中断时作废旧 completion。
    private var inFlightAnimationRequestID: UInt64 = 0

    /// 是否由本控制器 `ensureWindow()` 创建（attach 的窗口不在 teardown 时 close）。
    private var ownsCreatedWindow = false

    /// 启动器可见时隐藏系统菜单栏/Dock，避免半透明菜单栏透出壁纸（非「真全屏 Space仍用 Option B panel）。
    private var savedPresentationOptions: NSApplication.PresentationOptions?
    private var chromeHiddenForLauncher = false

    public init(
        coordinator: LauncherPresentationCoordinator = LauncherPresentationCoordinator(),
        reduceMotionProvider: @escaping () -> Bool = {
            NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        },
        screenFrameProvider: ((ScreenID) -> NSRect)? = nil
    ) {
        self.coordinator = coordinator
        self.reduceMotionProvider = reduceMotionProvider
        self.screenFrameProvider = screenFrameProvider ?? Self.defaultScreenFrameProvider
        super.init()
    }

    // MARK: - Host seam

    /// 附着既有窗口（AppDelegate 内容层次保留）。转换为 borderless screen-covering 形态。
    /// hide 不销毁该窗口；teardown 不 close 附着窗口（由宿主负责）。
    public func attach(window: NSWindow) {
        precondition(!isTornDown, "cannot attach after teardown")
        self.window = window
        ownsCreatedWindow = false
        configureAsScreenCoveringPanel(window)
    }

    /// 确保存在唯一 borderless panel；已有则复用。
    @discardableResult
    public func ensureWindow() -> NSWindow {
        precondition(!isTornDown, "cannot ensureWindow after teardown")
        if let window {
            configureAsScreenCoveringPanel(window)
            return window
        }
        let panel = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSView(frame: panel.contentLayoutRect)
        configureAsScreenCoveringPanel(panel)
        window = panel
        ownsCreatedWindow = true
        return panel
    }

    // MARK: - Coordinator commands → effect → apply

    /// 经 coordinator 决策后执行 effect；返回 effect 供测试断言。
    @discardableResult
    public func handle(
        _ command: LauncherCommand,
        source: LauncherActivationSource,
        targetScreen: ScreenID
    ) -> LauncherPresentationEffect {
        let effect = coordinator.handle(command, source: source, targetScreen: targetScreen)
        apply(effect)
        return effect
    }

    @discardableResult
    public func show(source: LauncherActivationSource, targetScreen: ScreenID) -> LauncherPresentationEffect {
        let effect = coordinator.show(source: source, targetScreen: targetScreen)
        apply(effect)
        return effect
    }

    @discardableResult
    public func hide(source: LauncherActivationSource, reason: DismissReason) -> LauncherPresentationEffect {
        let effect = coordinator.hide(source: source, reason: reason)
        apply(effect)
        return effect
    }

    @discardableResult
    public func quit() -> LauncherPresentationEffect {
        let effect = coordinator.quit()
        apply(effect)
        return effect
    }

    @discardableResult
    public func terminate() -> LauncherPresentationEffect {
        let effect = coordinator.terminate()
        apply(effect)
        return effect
    }

    @discardableResult
    public func suspend(reason: LauncherSuspensionReason) -> LauncherPresentationEffect {
        let effect = coordinator.suspend(reason: reason)
        apply(effect)
        return effect
    }

    @discardableResult
    public func resume() -> LauncherPresentationEffect {
        let effect = coordinator.resume()
        apply(effect)
        return effect
    }

    /// UI/动画层完成回调入口：仅匹配 `activeRequestID` 时生效（stale → .none）。
    @discardableResult
    public func completeTransition(requestID: UInt64) -> LauncherPresentationEffect {
        coordinator.completeTransition(requestID: requestID)
    }

    /// 执行单个 effect（也可在外部先 mutate coordinator 再调用）。
    public func apply(_ effect: LauncherPresentationEffect) {
        guard !isTornDown || effect == .teardown || effect == .none else { return }
        switch effect {
        case .none:
            break
        case .present(let requestID, let targetScreen, _):
            performPresent(requestID: requestID, targetScreen: targetScreen)
        case .dismiss(let requestID, _, _):
            performDismiss(requestID: requestID)
        case .suspend:
            performSuspend()
        case .terminate:
            performTerminateIntent()
        case .teardown:
            performTeardown()
        }
    }

    /// T-1G-E：采纳外部已推进的 presentation 状态机（四指 `process`+`flush` 路径）。
    /// 组合根在 flush 前把本控制器的 coordinator 同步进 FourFinger，flush 后再 adopt 回来，
    /// 保证单一 presentation 权威、requestID 与 effect 一致；不另开第二窗路径。
    public func adoptCoordinator(_ coordinator: LauncherPresentationCoordinator) {
        self.coordinator = coordinator
    }

    /// 解析 ScreenID 对应 frame（测试可直接断言 fallback 确定性）。
    public func resolvedScreenFrame(for screenID: ScreenID) -> NSRect {
        screenFrameProvider(screenID)
    }

    // MARK: - Effect performers

    private func performPresent(requestID: UInt64, targetScreen: ScreenID) {
        let window = ensureWindow()
        if backgroundUITestMode {
            fillContentToWindowBounds(window)
            window.alphaValue = 1
            if foregroundWindowedPresentation {
                window.makeKeyAndOrderFront(nil)
                activateWindowedApplication()
            } else {
                window.orderBack(nil)
            }
            inFlightAnimationRequestID = 0
            _ = coordinator.completeTransition(requestID: requestID)
            return
        }
        // 必须用 NSScreen.frame（含菜单栏后方），禁止 visibleFrame——否则顶条透出壁纸。
        let frame = resolvedScreenFrame(for: targetScreen)
        window.setFrame(frame, display: true)
        fillContentToWindowBounds(window)
        applyLauncherChromeHidden(true)

        // 中断在飞动画时强制同步收尾（避免 AppKit 合并 animator 导致新 completion 永不触发）。
        let interrupting = inFlightAnimationRequestID != 0
        inFlightAnimationRequestID = requestID

        var duration = effectiveDuration(presentDuration)
        if interrupting {
            duration = 0
        }
        // 首显保持不透明：alpha 从 0 淡入时，用户会误以为「没有应用」。
        window.alphaValue = 1

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let preferredFirstResponder {
            window.makeFirstResponder(preferredFirstResponder)
        }

        finishTransition(requestID: requestID, duration: duration, animations: {
            window.animator().alphaValue = 1
        }, completion: {
            window.alphaValue = 1
            self.fillContentToWindowBounds(window)
        })
    }

    private func performDismiss(requestID: UInt64) {
        let interrupting = inFlightAnimationRequestID != 0
        inFlightAnimationRequestID = requestID
        guard let window else {
            applyLauncherChromeHidden(false)
            _ = coordinator.completeTransition(requestID: requestID)
            inFlightAnimationRequestID = 0
            return
        }

        // 中断 present→dismiss：同步完成，避免旧 NSAnimationContext completion 饿死新 transition。
        var duration = effectiveDuration(dismissDuration)
        if interrupting {
            duration = 0
        }
        finishTransition(requestID: requestID, duration: duration, animations: {
            window.animator().alphaValue = 0
        }, completion: {
            // hide ≠ destroy：orderOut 保留 assembly。
            window.orderOut(nil)
            window.alphaValue = 1
            self.applyLauncherChromeHidden(false)
            self.onLauncherDidHide?()
        })
    }

    private func performSuspend() {
        // 取消 in-flight（其 completion 因 requestID 不匹配而 no-op）。
        inFlightAnimationRequestID = 0
        window?.orderOut(nil)
        window?.alphaValue = 1
        applyLauncherChromeHidden(false)
        onLauncherDidHide?()
    }

    /// quit → .terminate effect：立即隐藏；进程退出由宿主 NSApp.terminate 负责（本控制器不杀进程）。
    private func performTerminateIntent() {
        inFlightAnimationRequestID = 0
        window?.orderOut(nil)
        window?.alphaValue = 1
        applyLauncherChromeHidden(false)
        onLauncherDidHide?()
    }

    private func performTeardown() {
        guard !isTornDown else { return }
        isTornDown = true
        inFlightAnimationRequestID = 0
        applyLauncherChromeHidden(false)
        onLauncherDidHide?()
        if let window {
            window.orderOut(nil)
            if ownsCreatedWindow {
                window.contentView = nil
                // 不调用 close() 以免触发未预期的 delegate 链；释放引用即可。
            }
        }
        window = nil
        preferredFirstResponder = nil
        ownsCreatedWindow = false
    }

    /// 隐藏/恢复菜单栏与 Dock，使黑底铺满物理屏（含原菜单栏条带）。
    private func applyLauncherChromeHidden(_ hidden: Bool) {
        if hidden {
            guard !chromeHiddenForLauncher else { return }
            savedPresentationOptions = NSApp.presentationOptions
            NSApp.presentationOptions = [.hideDock, .hideMenuBar]
            chromeHiddenForLauncher = true
        } else {
            guard chromeHiddenForLauncher else { return }
            NSApp.presentationOptions = savedPresentationOptions ?? []
            savedPresentationOptions = nil
            chromeHiddenForLauncher = false
        }
    }

    // MARK: - Animation + requestID guard

    private func effectiveDuration(_ base: TimeInterval) -> TimeInterval {
        (backgroundUITestMode || reduceMotionProvider()) ? 0 : max(0, base)
    }

    private func finishTransition(
        requestID: UInt64,
        duration: TimeInterval,
        animations: @escaping () -> Void,
        completion: @escaping () -> Void
    ) {
        let finish: () -> Void = { [weak self] in
            guard let self else { return }
            // 仅匹配当前 in-flight 且仍为 coordinator.activeRequestID 时提交。
            guard self.inFlightAnimationRequestID == requestID else { return }
            completion()
            _ = self.coordinator.completeTransition(requestID: requestID)
            if self.inFlightAnimationRequestID == requestID {
                self.inFlightAnimationRequestID = 0
            }
        }

        if duration <= 0 {
            finish()
            return
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = duration
            animations()
        }, completionHandler: {
            // AppKit 可能在任意队列回调；状态机与窗口操作要求主线程。
            if Thread.isMainThread {
                finish()
            } else {
                DispatchQueue.main.async(execute: finish)
            }
        })
    }

    // MARK: - Panel configuration (Option B)

    private func configureAsScreenCoveringPanel(_ window: NSWindow) {
        if backgroundUITestMode {
            let desired: NSWindow.StyleMask = [.titled, .closable, .resizable]
            if window.styleMask != desired { window.styleMask = desired }
            window.collectionBehavior = []
            window.level = .normal
            window.title = backgroundUITestTitle
            window.isReleasedWhenClosed = false
            fillContentToWindowBounds(window)
            return
        }
        // 公开 API borderless panel：覆盖目标屏 frame，不进入独立 fullscreen Space。
        if window.styleMask.contains(.fullScreen) {
            // 若曾误入系统全屏，退出后再改形态（避免残留 Space）。
            window.toggleFullScreen(nil)
        }
        // 仅在需要时改 styleMask：titled→borderless 会短暂把 contentView 移出窗口，
        // 触发 PagingSurface.viewDidMoveToWindow(nil) → 永久 teardown（表现为没有应用）。
        let desired: NSWindow.StyleMask = [.borderless]
        if window.styleMask != desired {
            window.styleMask = desired
        }
        // LaunchBetter LauncherWindow：isOpaque=false + clear，壁纸由内容层绘制。
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        // 可出现在各 Space / 其他 app 的 fullscreen 之上，但自身不是 fullscreen Space。
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = .normal
        window.title = ""
        // 铺满物理屏完整 frame（含菜单栏后方）；禁止用 visibleFrame。
        if let screen = window.screen ?? NSScreen.main {
            window.setFrame(screen.frame, display: true)
        }
        fillContentToWindowBounds(window)
    }

    /// 将 contentView（及常见全宽子视图）铺满当前 contentLayoutRect。
    private func fillContentToWindowBounds(_ window: NSWindow) {
        let bounds = NSRect(origin: .zero, size: backgroundUITestMode
                            ? window.contentLayoutRect.size : window.frame.size)
        guard let content = window.contentView else { return }
        if content.frame.size != bounds.size || content.frame.origin != .zero {
            content.frame = bounds
        }
        content.autoresizingMask = [.width, .height]
        for subview in content.subviews {
            // PagingSurface 以 width/height 自适配；若仍停在旧尺寸则强制铺满。
            if subview.autoresizingMask.contains(.width),
               subview.autoresizingMask.contains(.height),
               abs(subview.bounds.width - bounds.width) > 0.5
                || abs(subview.bounds.height - bounds.height) > 0.5 {
                subview.frame = bounds
            }
        }
        content.needsLayout = true
        content.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
    }

    /// 默认 ScreenID → frame：列表下标命中；否则 main → first → 合成 1440×900。
    public static func defaultScreenFrameProvider(_ screenID: ScreenID) -> NSRect {
        let screens = NSScreen.screens
        if screenID.index >= 0, screenID.index < screens.count {
            return screens[screenID.index].frame
        }
        if let main = NSScreen.main {
            return main.frame
        }
        if let first = screens.first {
            return first.frame
        }
        // 无屏环境（极端/无头）确定性合成 frame——不读 UUID/名称。
        return NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
}
