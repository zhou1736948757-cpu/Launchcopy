//
//  ActivationComposition.swift
//  PagingPrototypeApp
//
//  Phase 1G T-1G-E：激活入口组合根（可注入 fake；生产由 AppDelegate 宿主）。
//  - 全部入口只经同一 LauncherWindowController / presentation coordinator。
//  - 四指生产路径 = process(frame) + flushPendingShows()，再 apply effect（同步 adopt）。
//  - Prefs → shortcut / hot corner / four-finger 启停；默认 shortcut/hot corner Off。
//  - Quit → quit + terminate + activation teardown once；hide 不 terminate。
//  隐私：无 global NSEvent monitor / CGEvent tap / Accessibility。
//

import Foundation

/// 激活服务组合根：持有 prefs 驱动的入口适配器，并把命令收敛到单一 launcher。
@MainActor
public final class ActivationComposition {

    public let launcher: LauncherWindowController

    public private(set) var shortcutRegistrar: any GlobalShortcutRegistering
    public private(set) var hotCornerMonitor: HotCornerMonitor
    public private(set) var sessionObserver: any WorkspaceSessionObserving

    /// 四指接线（值类型；每次 mutate 后写回本属性）。
    public private(set) var fourFinger: FourFingerActivationCoordinator?
    public private(set) var touchProvider: (any TouchProvider)?

    /// 当前已应用的服务计划（diff 基准）。
    public private(set) var appliedPlan = ActivationServicePlan()

    /// 进程退出请求计数（测试断言 hide 不触发；quit 触发一次）。
    public private(set) var terminateRequestCount = 0
    /// 激活服务 teardown 次数（验收：恰好一次）。
    public private(set) var activationTeardownCount = 0

    /// 宿主注入：真实路径 = `NSApp.terminate`；测试可捕获。
    public var onRequestTerminate: (() -> Void)?

    /// 宿主注入：hide 前取消 drag/folder/search/title 等瞬态（ADR-011 Q7）。
    public var onPrepareHide: (() -> Void)?
    /// Host-owned idle-work admission; fail closed without a live host.
    public var canHideFromFourFinger: () -> Bool = { false }
    private var touchAttachmentGeneration: UInt64 = 0
    private let touchDeliveryFence = FourFingerDeliveryFence()
    private var outwardInputNotBefore: TimeInterval?

    /// 宿主注入：屏幕几何变化前取消 Folder/其他依赖窗口坐标的瞬态。
    public var onScreensChanged: (() -> Void)?

    /// 四指时钟（生产 = 系统；测试注入 FakePinchClock）。
    private let pinchClock: PinchClock
    /// Installed only by an explicit diagnostic host; nil avoids formatting/I/O.
    var onFourFingerDiagnostic: ((String) -> Void)?
    /// Explicit dedicated-host diagnostic only; default nil, bounded, no raw input retained.
    private(set) var gestureDeliveryObservation: GestureDeliveryObservation?
    func startGestureDeliveryObservation() {
        guard activationTeardownCount == 0 else { return }
        gestureDeliveryObservation = GestureDeliveryObservation()
    }
    func stopGestureDeliveryObservation() { gestureDeliveryObservation = nil }
    /// 是否已请求过 quit（避免重复 terminate 请求风暴；teardown 仍幂等）。
    private var didRequestQuit = false

    public init(
        launcher: LauncherWindowController,
        shortcutRegistrar: any GlobalShortcutRegistering = FakeGlobalShortcutRegistrar(),
        hotCornerMonitor: HotCornerMonitor? = nil,
        sessionObserver: any WorkspaceSessionObserving = FakeWorkspaceSessionObserver(),
        pinchClock: PinchClock = PinchSystemClock(),
        onRequestTerminate: (() -> Void)? = nil
    ) {
        self.launcher = launcher
        self.shortcutRegistrar = shortcutRegistrar
        self.sessionObserver = sessionObserver
        self.pinchClock = pinchClock
        self.onRequestTerminate = onRequestTerminate

        if let hotCornerMonitor {
            self.hotCornerMonitor = hotCornerMonitor
        } else {
            self.hotCornerMonitor = HotCornerMonitor(
                pointerLocator: FakeHotCornerPointerLocator(),
                geometryProvider: FakeHotCornerGeometryProvider(
                    geometry: ScreenGeometrySnapshot(screens: [
                        ScreenGeometrySnapshot.Screen(
                            id: ScreenID(index: 0),
                            frame: LauncherRect(
                                origin: LauncherPoint(x: 0, y: 0),
                                size: LauncherSize(width: 1440, height: 900)
                            ),
                            scale: 2
                        )
                    ])
                ),
                scheduler: FakeHotCornerScheduler()
            )
        }

        wireCallbacks()
    }

    // MARK: - Prefs → services

    /// 按偏好启停服务（默认 shortcut/hot corner Off；fourFinger 默认 true）。
    public func applyPreferences(_ preferences: ActivationPreferences) {
        let plan = ActivationServicePlan(
            settings: preferences.settings,
            fourFingerEnabled: preferences.fourFingerActivationEnabled,
            fourFingerOutwardHideEnabled: preferences.fourFingerOutwardHideEnabled
        )
        applyPlan(plan)
    }

    /// 应用服务计划 diff（原子顺序由 ActivationServicePlanDiff 保证）。
    public func applyPlan(_ plan: ActivationServicePlan) {
        guard activationTeardownCount == 0, !didRequestQuit else { return }
        if (appliedPlan.fourFingerOutwardHideEnabled || plan.fourFingerOutwardHideEnabled),
           appliedPlan.fourFingerEnabled != plan.fourFingerEnabled
            || appliedPlan.fourFingerOutwardHideEnabled != plan.fourFingerOutwardHideEnabled {
            touchDeliveryFence.advance()
            outwardInputNotBefore = pinchClock.now()
        }
        let transitions = ActivationServicePlanDiff.transitions(from: appliedPlan, to: plan)
        for transition in transitions {
            applyTransition(transition)
        }
        appliedPlan = plan
        if var fourFinger {
            fourFinger.setOutwardHideEnabled(plan.fourFingerEnabled && plan.fourFingerOutwardHideEnabled)
            self.fourFinger = fourFinger
        }
        syncHotCornerLauncherVisibility()
    }

    /// 启动会话观察（生产在 didFinishLaunching 调用）。
    public func startSessionObserver() {
        sessionObserver.onEvent = { [weak self] event in
            MainActor.assumeIsolated {
                self?.handleSessionEvent(event)
            }
        }
        sessionObserver.start()
    }

    // MARK: - Hide / Quit

    /// 驻留 hide：取消瞬态后经单一 coordinator dismiss；**不**请求进程退出。
    @discardableResult
    public func hide(
        source: LauncherActivationSource,
        reason: DismissReason
    ) -> LauncherPresentationEffect {
        performHide(source: source, reason: reason)
    }

    private func performHide(source: LauncherActivationSource, reason: DismissReason,
                             admission: (() -> Bool)? = nil) -> LauncherPresentationEffect {
        guard admission?() != false else { return .none }
        onPrepareHide?()
        // Cleanup is a reentrant boundary: disabling/replacing the provider or
        // starting protected work must revoke an already recognized Hide.
        guard admission?() != false else { return .none }
        let effect = launcher.hide(source: source, reason: reason)
        syncHotCornerLauncherVisibility()
        return effect
    }

    /// 成功启动 app → hide（失败/拒绝保持可见）。
    @discardableResult
    public func handleLaunchOutcome(_ outcome: AppLaunchOutcome) -> LauncherPresentationEffect {
        guard outcome == .launched else { return .none }
        return hide(source: .statusItem, reason: .appLaunched)
    }

    /// ESC 耗尽 → hide。
    @discardableResult
    public func handleEscapeExhausted() -> LauncherPresentationEffect {
        hide(source: .statusItem, reason: .escape)
    }

    /// 空白背景 → hide。
    @discardableResult
    public func handleBackgroundClick() -> LauncherPresentationEffect {
        hide(source: .statusItem, reason: .backgroundClick)
    }

    /// 窗口关闭按钮 → hide（不销毁、不 quit）。
    @discardableResult
    public func handleWindowCloseRequest() -> LauncherPresentationEffect {
        hide(source: .statusItem, reason: .statusItem)
    }

    /// 显式 Quit：coordinator.quit → terminate → 请求进程退出；激活服务 teardown once。
    public func handleQuit() {
        guard !didRequestQuit else {
            // 已在 terminating：仍保证 teardown 幂等路径可再入。
            _ = launcher.terminate()
            teardownActivationServices()
            return
        }
        didRequestQuit = true
        _ = launcher.quit()
        _ = launcher.terminate()
        teardownActivationServices()
        terminateRequestCount += 1
        onRequestTerminate?()
    }

    /// 系统 `applicationWillTerminate`：若尚未 quit，补齐 quit+terminate+teardown。
    public func handleApplicationWillTerminate() {
        if !didRequestQuit {
            didRequestQuit = true
            _ = launcher.quit()
        }
        _ = launcher.terminate()
        teardownActivationServices()
    }

    /// 停全部激活服务（幂等；与窗控 teardown 分离）。
    public func teardownActivationServices() {
        guard activationTeardownCount == 0 else { return }
        activationTeardownCount = 1
        touchAttachmentGeneration &+= 1

        if let registrar = shortcutRegistrar as? CarbonGlobalShortcutRegistrar {
            registrar.teardown()
        } else {
            shortcutRegistrar.unregister()
        }
        shortcutRegistrar.onFired = nil

        hotCornerMonitor.teardown()
        sessionObserver.stop()
        sessionObserver.onEvent = nil

        touchProvider?.onFrame = nil
        touchProvider?.onStateChange = nil
        touchProvider?.stop()
        touchProvider = nil

        if var fourFinger {
            fourFinger.stop()
            self.fourFinger = fourFinger
        }
        fourFinger = nil
        onFourFingerDiagnostic = nil
        gestureDeliveryObservation = nil
        canHideFromFourFinger = { false }
        appliedPlan = ActivationServicePlan()
    }

    // MARK: - Four-finger process + flush

    /// 生产路径：同步 presentation → process → flush → adopt → apply effects。
    @discardableResult
    public func processFourFingerFrame(_ frame: PinchFrame) -> [LauncherPresentationEffect] {
        guard activationTeardownCount == 0, !didRequestQuit, var fourFinger else { return [] }
        fourFinger.targetScreen = LauncherTargetScreenResolver.resolve()
        fourFinger.adoptPresentation(launcher.coordinator)
        // 异步交付会使帧时间戳相对主线程 clock 偏旧；对齐到当前单调时钟再识别
        // （相对几何不变；避免 dataExpiry 把活流整段丢掉——对照 LaunchBetter 回调线程就地识别）。
        let now = pinchClock.now()
        let aligned = PinchFrame(
            deviceID: frame.deviceID,
            timestamp: now,
            phase: frame.phase,
            contacts: frame.contacts
        )
        let expectedAttachment = touchAttachmentGeneration
        let originalGeneration = fourFinger.recognizer.generation
        let admission = outwardHideIsAdmitted
        gestureDeliveryObservation?.record(frame: frame, now: now, admission: admission,
            cutoff: outwardInputNotBefore, expiry: fourFinger.recognizer.parameters.dataExpiryInterval)
        guard touchAttachmentGeneration == expectedAttachment,
              self.fourFinger?.recognizer.generation == originalGeneration else { return [] }
        if let cutoff = outwardInputNotBefore,
           frame.timestamp < cutoff {
            fourFinger.requireReleaseAfterDeliveryInvalidation(frame.deviceID)
            self.fourFinger = fourFinger
            return []
        }
        // The historical inward-only path aligns delivery time. Optional Hide
        // must retain the provider clock to reject backlog, invalid and reordered input.
        let input = fourFinger.requiresValidatedFrameTime ? frame : aligned
        let events = fourFinger.process(input, allowOutwardHide: admission)
        var effects = fourFinger.flushPendingShows()
        let hideRequested = fourFinger.flushPendingHides(allowHide: admission)
        gestureDeliveryObservation?.record(events: events, hideRequested: hideRequested)
        let expectedRecognizerGeneration = fourFinger.recognizer.generation
        launcher.adoptCoordinator(fourFinger.presentation)
        self.fourFinger = fourFinger
        if let report = onFourFingerDiagnostic, !events.isEmpty || effects.contains(where: { if case .present = $0 { return true }; return false }) {
            let presentCount = effects.filter { if case .present = $0 { return true }; return false }.count
            report("paging-fourfinger-show: events=\(events.count) presentEffects=\(presentCount) showCount=\(fourFinger.showCount) recognizer=\(fourFinger.recognizer.state) presentation=\(launcher.coordinator.state) contacts=\(frame.contacts.count)")
        }
        for effect in effects {
            launcher.apply(effect)
        }
        if hideRequested {
            let effect = performHide(source: .fourFingerPinch, reason: .fourFingerOutward) {
                self.touchAttachmentGeneration == expectedAttachment
                    && self.fourFinger?.recognizer.generation == expectedRecognizerGeneration
                    && self.outwardHideIsAdmitted
            }
            effects.append(effect)
        }
        syncHotCornerLauncherVisibility()
        return effects
    }

    private var outwardHideIsAdmitted: Bool {
        guard activationTeardownCount == 0, !didRequestQuit,
              appliedPlan.fourFingerEnabled, appliedPlan.fourFingerOutwardHideEnabled,
              fourFinger?.isReady == true,
              case .visible = launcher.coordinator.state else { return false }
        return canHideFromFourFinger()
    }

    /// 注入/替换 touch provider（测试用 Mock；生产 MultitouchSupportBackend）。
    public func attachTouchProvider(_ provider: any TouchProvider, userEnabled: Bool) {
        guard activationTeardownCount == 0 else { return }
        touchAttachmentGeneration &+= 1
        let attachment = touchAttachmentGeneration
        touchProvider?.onFrame = nil
        touchProvider?.onStateChange = nil
        touchProvider?.stop()

        var coordinator = FourFingerActivationCoordinator(
            clock: pinchClock,
            targetScreen: ScreenID(index: 0),
            userEnabled: userEnabled
        )
        coordinator.adoptPresentation(launcher.coordinator)
        coordinator.setOutwardHideEnabled(userEnabled && appliedPlan.fourFingerOutwardHideEnabled)
        coordinator.start()
        self.fourFinger = coordinator

        let deliveryFence = touchDeliveryFence
        provider.onFrame = { [weak self] frame in
            let delivery = deliveryFence.snapshot()
            // Provider 回调可能来自交付队列；presentation 写必须在主线程。
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    guard let self, self.touchAttachmentGeneration == attachment else { return }
                    self.receiveFourFingerFrame(frame, delivery: delivery)
                }
            } else {
                DispatchQueue.main.async {
                    guard let self, self.touchAttachmentGeneration == attachment else { return }
                    self.receiveFourFingerFrame(frame, delivery: delivery)
                }
            }
        }
        provider.onStateChange = { [weak self] state in
            let delivery = deliveryFence.snapshot()
            let applyState = { [weak self] in
                guard let self, self.touchAttachmentGeneration == attachment,
                      deliveryFence.snapshot() == delivery,
                      self.activationTeardownCount == 0, var fourFinger = self.fourFinger else { return }
                fourFinger.handleProviderState(state)
                self.fourFinger = fourFinger
            }
            if Thread.isMainThread {
                MainActor.assumeIsolated(applyState)
            } else {
                DispatchQueue.main.async {
                    MainActor.assumeIsolated(applyState)
                }
            }
        }
        self.touchProvider = provider
        provider.start()
        if case .ready = provider.state {
            if var fourFinger = self.fourFinger, self.touchAttachmentGeneration == attachment {
                fourFinger.handleProviderState(.ready)
                self.fourFinger = fourFinger
            }
        }
    }

    private func receiveFourFingerFrame(_ frame: PinchFrame, delivery: UInt64) {
        guard touchDeliveryFence.snapshot() == delivery else {
            // A contact frame queued before a mode/service edit cannot gain the
            // new generation. Preserve release protection even if its baseline
            // had not reached the main actor when the edit occurred.
            if !frame.contacts.isEmpty, var fourFinger {
                fourFinger.requireReleaseAfterDeliveryInvalidation(frame.deviceID)
                self.fourFinger = fourFinger
            }
            return
        }
        _ = processFourFingerFrame(frame)
    }

    // MARK: - Session

    public func handleSessionEvent(_ event: WorkspaceSessionEvent) {
        if appliedPlan.fourFingerOutwardHideEnabled { touchDeliveryFence.advance() }
        WorkspaceSessionHotCornerBridge.apply(event, to: hotCornerMonitor)

        switch event {
        case .willSleep:
            if var fourFinger {
                fourFinger.adoptPresentation(launcher.coordinator)
                let effect = fourFinger.suspend(reason: .sleep)
                launcher.adoptCoordinator(fourFinger.presentation)
                launcher.apply(effect)
                self.fourFinger = fourFinger
            } else {
                _ = launcher.suspend(reason: .sleep)
            }
        case .sessionResigned:
            if var fourFinger {
                fourFinger.adoptPresentation(launcher.coordinator)
                let effect = fourFinger.suspend(reason: .sessionInactive)
                launcher.adoptCoordinator(fourFinger.presentation)
                launcher.apply(effect)
                self.fourFinger = fourFinger
            } else {
                _ = launcher.suspend(reason: .sessionInactive)
            }
        case .didWake, .sessionActivated:
            if var fourFinger {
                fourFinger.adoptPresentation(launcher.coordinator)
                let effect = fourFinger.resume()
                launcher.adoptCoordinator(fourFinger.presentation)
                launcher.apply(effect)
                self.fourFinger = fourFinger
            } else {
                _ = launcher.resume()
            }
        case .screensChanged:
            onScreensChanged?()
            if var fourFinger {
                fourFinger.targetScreen = LauncherTargetScreenResolver.resolve()
                self.fourFinger = fourFinger
            }
        }
        syncHotCornerLauncherVisibility()
    }

    // MARK: - Private

    private func wireCallbacks() {
        shortcutRegistrar.onFired = { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                let screen = LauncherTargetScreenResolver.resolve()
                _ = self.launcher.handle(.toggle, source: .globalShortcut, targetScreen: screen)
                self.syncHotCornerLauncherVisibility()
            }
        }

        hotCornerMonitor.onShowRequested = { [weak self] _, screenID in
            MainActor.assumeIsolated {
                guard let self else { return }
                _ = self.launcher.show(source: .hotCorner, targetScreen: screenID)
                self.syncHotCornerLauncherVisibility()
            }
        }
    }

    private func applyTransition(_ transition: ActivationServiceTransition) {
        switch transition {
        case .startHotCorner(let corner), .restartHotCorner(let corner):
            hotCornerMonitor.enable(corner: corner)
        case .stopHotCorner:
            hotCornerMonitor.disable()
        case .startShortcut(let spec), .restartShortcut(let spec):
            _ = shortcutRegistrar.register(spec)
        case .stopShortcut:
            shortcutRegistrar.unregister()
        case .startFourFinger:
            // 生产/测试：若已有 provider 则只更新 userEnabled；否则由宿主 attachTouchProvider。
            if var fourFinger {
                fourFinger.userEnabled = true
                if fourFinger.activation.state == .off {
                    fourFinger.start()
                }
                self.fourFinger = fourFinger
            }
            if let touchProvider, !touchProvider.isStarted {
                touchProvider.start()
            }
        case .setFourFingerOutwardHide:
            break // Applied once from the final effective plan, without provider churn.
        case .stopFourFinger:
            touchProvider?.stop()
            if var fourFinger {
                fourFinger.userEnabled = false
                fourFinger.stop()
                self.fourFinger = fourFinger
            }
        }
    }

    private func syncHotCornerLauncherVisibility() {
        hotCornerMonitor.setLauncherVisible(launcher.coordinator.committedVisibility)
    }
}

/// Receipt-time epoch only: no contact coordinates, provider calls or user closures
/// are stored under this lock. Bridges provider queues to main-actor mode edits.
private final class FourFingerDeliveryFence: @unchecked Sendable {
    private let lock = NSLock()
    private var generation: UInt64 = 0

    func snapshot() -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        return generation
    }

    func advance() {
        lock.lock(); defer { lock.unlock() }
        generation &+= 1
    }
}
