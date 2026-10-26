import AppKit

/// One composition choice for profile isolation. No test-profile settings action
/// can later swap a fake global registrar/login service for a production adapter.
@MainActor
enum LauncherRuntimeServices {
    static func activation(launcher: LauncherWindowController, isolated: Bool,
                           requestTerminate: @escaping () -> Void) -> ActivationComposition {
        if isolated {
            // Existing fake adapters have no system registration, device reads or
            // timer-based global pointer polling. Local hide/reopen still works.
            return ActivationComposition(launcher: launcher, onRequestTerminate: requestTerminate)
        }
        let hotCorner = HotCornerMonitor(pointerLocator: NSEventPointerLocator(),
            geometryProvider: NSScreenGeometryProvider(), scheduler: MainRunLoopHotCornerScheduler())
        return ActivationComposition(launcher: launcher,
            shortcutRegistrar: CarbonGlobalShortcutRegistrar(), hotCornerMonitor: hotCorner,
            sessionObserver: WorkspaceSessionObserver(), pinchClock: PinchSystemClock(),
            onRequestTerminate: requestTerminate)
    }

    /// Shared host path for startup and accepted settings; the factory is lazy.
    static func applyActivationPreferences(_ preferences: ActivationPreferences,
                                          to composition: ActivationComposition,
                                          isolated: Bool,
                                          makeTouchProvider: () -> any TouchProvider = { MultitouchSupportBackend() }) {
        guard composition.activationTeardownCount == 0 else { return }
        // A saved Off preference must remain device-free until an accepted enable.
        // Existing providers retain their normal stop/restart and readiness semantics.
        if !isolated, preferences.fourFingerActivationEnabled, composition.touchProvider == nil {
            composition.attachTouchProvider(makeTouchProvider(), userEnabled: true)
        }
        composition.applyPreferences(preferences)
    }

    /// Separate from activation(isolated:): that existing entry remains fake-only.
    static func gestureValidationActivation(launcher: LauncherWindowController,
                                            requestTerminate: @escaping () -> Void) -> ActivationComposition {
        ActivationComposition(launcher: launcher, pinchClock: PinchSystemClock(),
                              onRequestTerminate: requestTerminate)
    }

    static func applyGestureValidationPreferences(_ preferences: ActivationPreferences,
                                                  to composition: ActivationComposition,
                                                  makeTouchProvider: () -> any TouchProvider = { MultitouchSupportBackend() }) {
        guard composition.activationTeardownCount == 0 else { return }
        let safe = GestureValidationPolicy.preferences(preferences)
        if safe.fourFingerActivationEnabled, composition.touchProvider == nil {
            composition.attachTouchProvider(makeTouchProvider(), userEnabled: true)
        }
        composition.applyPreferences(safe)
    }

    /// Real catalog/launch are host capabilities, not a way to enable other globals.
    static func integratedPreviewActivation(launcher: LauncherWindowController,
                                           requestTerminate: @escaping () -> Void) -> ActivationComposition {
        ActivationComposition(launcher: launcher, pinchClock: PinchSystemClock(),
                              onRequestTerminate: requestTerminate)
    }

    static func applyIntegratedPreviewPreferences(_ preferences: ActivationPreferences,
                                                 to composition: ActivationComposition,
                                                 makeTouchProvider: () -> any TouchProvider = { MultitouchSupportBackend() }) {
        guard composition.activationTeardownCount == 0 else { return }
        let safe = IntegratedPreviewPolicy.preferences(preferences)
        if safe.fourFingerActivationEnabled, composition.touchProvider == nil {
            composition.attachTouchProvider(makeTouchProvider(), userEnabled: true)
        }
        composition.applyPreferences(safe)
    }

    static func login(isolated: Bool) -> any LaunchAtLoginServicing {
        if isolated { return FakeLaunchAtLoginService() }
        return SMAppServiceLaunchAtLoginService()
    }
}
