import AppKit
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class LauncherRuntimeServicesTests: XCTestCase {
    func testIsolatedCompositionCannotRegisterGlobalServicesAfterSettingsApply() {
        let launcher = LauncherWindowController(reduceMotionProvider: { true })
        let composition = LauncherRuntimeServices.activation(launcher: launcher, isolated: true, requestTerminate: {})
        XCTAssertTrue(composition.shortcutRegistrar is FakeGlobalShortcutRegistrar)
        XCTAssertTrue(composition.sessionObserver is FakeWorkspaceSessionObserver)
        composition.applyPreferences(ActivationPreferences())
        composition.startSessionObserver()
        XCTAssertNil(composition.touchProvider)
        composition.teardownActivationServices()
        XCTAssertFalse(launcher.isTornDown)
    }

    func testIsolatedLoginToggleNeverUsesRealSystemRegistration() {
        let login = LauncherRuntimeServices.login(isolated: true)
        XCTAssertTrue(login is FakeLaunchAtLoginService)
        XCTAssertFalse(login.usesRealLoginItemRegistration)
        XCTAssertEqual(login.setEnabled(true), .enabled)
        XCTAssertEqual(login.setEnabled(false), .disabled)
        XCTAssertFalse(login.usesRealLoginItemRegistration)
    }
    private func runtimeOwner(clock: FakePinchClock) -> ActivationComposition {
        _ = NSApplication.shared
        return ActivationComposition(launcher: LauncherWindowController(reduceMotionProvider: { true }),
                                     pinchClock: clock)
    }

    private func preferences(fourFingerEnabled: Bool) -> ActivationPreferences {
        var value = ActivationPreferences()
        value.fourFingerActivationEnabled = fourFingerEnabled
        return value
    }

    func testColdDisabledSettingsApplyCreatesProviderOnEnable() {
        let clock = FakePinchClock(), provider = MockTouchProvider(clock: FakePinchClock())
        let owner = runtimeOwner(clock: clock)
        defer { owner.teardownActivationServices() }
        let off = preferences(fourFingerEnabled: false)
        var factoryCalls = 0
        let factory: () -> any TouchProvider = { factoryCalls += 1; return provider }
        LauncherRuntimeServices.applyActivationPreferences(off, to: owner, isolated: false,
                                                          makeTouchProvider: factory)
        XCTAssertEqual(factoryCalls, 0)
        XCTAssertNil(owner.touchProvider)
        let store = InMemoryActivationPreferencesStore(initial: off)
        let settings = ActivationSettingsCoordinator(store: store, loginService: FakeLaunchAtLoginService(),
            initialCommitted: off, applyPreferences: { accepted in
                LauncherRuntimeServices.applyActivationPreferences(accepted, to: owner, isolated: false,
                                                                  makeTouchProvider: factory)
            })
        var draft = ActivationPreferencesDraft(committed: off)
        draft.fourFingerActivationEnabled = true
        guard case .applied(let accepted) = settings.applyDraft(draft) else {
            return XCTFail("An accepted existing gesture preference must apply")
        }
        XCTAssertTrue(accepted.fourFingerActivationEnabled)
        XCTAssertTrue(settings.committed.fourFingerActivationEnabled)
        XCTAssertEqual(factoryCalls, 1)
        XCTAssertTrue(owner.touchProvider === provider)
        XCTAssertTrue(provider.isStarted)
        XCTAssertEqual(owner.fourFinger?.activation.state, .ready)
        XCTAssertNil(owner.launcher.window)
    }

    func testColdEnabledAndRepeatedPreferencesCreateOnlyOneProvider() {
        let clock = FakePinchClock(), provider = MockTouchProvider(clock: FakePinchClock())
        let owner = runtimeOwner(clock: clock)
        defer { owner.teardownActivationServices() }
        let on = preferences(fourFingerEnabled: true)
        var factoryCalls = 0
        let factory: () -> any TouchProvider = { factoryCalls += 1; return provider }
        LauncherRuntimeServices.applyActivationPreferences(on, to: owner, isolated: false,
                                                          makeTouchProvider: factory)
        let notifications = provider.stateChangeCount
        LauncherRuntimeServices.applyActivationPreferences(on, to: owner, isolated: false,
                                                          makeTouchProvider: factory)
        XCTAssertEqual(factoryCalls, 1)
        XCTAssertTrue(owner.touchProvider === provider)
        XCTAssertTrue(provider.isStarted)
        XCTAssertEqual(provider.stateChangeCount, notifications)
        XCTAssertEqual(owner.fourFinger?.activation.state, .ready)
    }

    func testDisableAndReenableReuseTheExistingStoppedProvider() {
        let clock = FakePinchClock(), provider = MockTouchProvider(clock: FakePinchClock())
        let owner = runtimeOwner(clock: clock)
        defer { owner.teardownActivationServices() }
        var factoryCalls = 0
        let factory: () -> any TouchProvider = { factoryCalls += 1; return provider }
        LauncherRuntimeServices.applyActivationPreferences(preferences(fourFingerEnabled: true), to: owner,
                                                          isolated: false, makeTouchProvider: factory)
        LauncherRuntimeServices.applyActivationPreferences(preferences(fourFingerEnabled: false), to: owner,
                                                          isolated: false, makeTouchProvider: factory)
        XCTAssertFalse(provider.isStarted)
        XCTAssertEqual(owner.fourFinger?.activation.state, .off)
        let stoppedGeneration = provider.generation
        LauncherRuntimeServices.applyActivationPreferences(preferences(fourFingerEnabled: true), to: owner,
                                                          isolated: false, makeTouchProvider: factory)
        XCTAssertEqual(factoryCalls, 1)
        XCTAssertTrue(owner.touchProvider === provider)
        XCTAssertTrue(provider.isStarted)
        XCTAssertEqual(provider.generation, stoppedGeneration)
        XCTAssertEqual(owner.fourFinger?.activation.state, .ready)
    }

    func testIsolatedPreferenceTogglesNeverInvokeDeviceFactory() {
        let owner = runtimeOwner(clock: FakePinchClock())
        defer { owner.teardownActivationServices() }
        var factoryCalls = 0
        for enabled in [false, true, false, true] {
            LauncherRuntimeServices.applyActivationPreferences(preferences(fourFingerEnabled: enabled),
                to: owner, isolated: true, makeTouchProvider: {
                    factoryCalls += 1
                    return MockTouchProvider(clock: FakePinchClock())
                })
        }
        XCTAssertEqual(factoryCalls, 0)
        XCTAssertNil(owner.touchProvider)
        XCTAssertNil(owner.fourFinger)
        XCTAssertTrue(owner.appliedPlan.fourFingerEnabled)
        XCTAssertNil(owner.launcher.window)
    }

    func testLatePreferencesAfterTeardownDoNotResurrectServices() {
        let provider = MockTouchProvider(clock: FakePinchClock())
        let owner = runtimeOwner(clock: FakePinchClock())
        let on = preferences(fourFingerEnabled: true)
        var factoryCalls = 0
        let factory: () -> any TouchProvider = { factoryCalls += 1; return provider }
        LauncherRuntimeServices.applyActivationPreferences(on, to: owner, isolated: false,
                                                          makeTouchProvider: factory)
        owner.teardownActivationServices()
        LauncherRuntimeServices.applyActivationPreferences(on, to: owner, isolated: false,
                                                          makeTouchProvider: factory)
        XCTAssertEqual(factoryCalls, 1)
        XCTAssertFalse(provider.isStarted)
        XCTAssertNil(owner.touchProvider)
        XCTAssertNil(owner.fourFinger)
        XCTAssertFalse(owner.appliedPlan.fourFingerEnabled)
        XCTAssertEqual(owner.activationTeardownCount, 1)
    }

    func testUnavailableProviderRemainsHonestWithoutRepeatedConstruction() {
        let provider = MockTouchProvider(clock: FakePinchClock())
        provider.startupState = .unavailable
        let owner = runtimeOwner(clock: FakePinchClock())
        defer { owner.teardownActivationServices() }
        var factoryCalls = 0
        for _ in 0..<2 {
            LauncherRuntimeServices.applyActivationPreferences(preferences(fourFingerEnabled: true),
                to: owner, isolated: false, makeTouchProvider: { factoryCalls += 1; return provider })
        }
        XCTAssertEqual(factoryCalls, 1)
        XCTAssertTrue(owner.touchProvider === provider)
        XCTAssertEqual(owner.fourFinger?.activation.state, .unavailable)
        XCTAssertFalse(owner.fourFinger?.displayStatus.isReady ?? true)
    }

    func testPreferenceApplicationKeepsExplicitlyAttachedProvider() {
        let provider = MockTouchProvider(clock: FakePinchClock())
        let owner = runtimeOwner(clock: FakePinchClock())
        defer { owner.teardownActivationServices() }
        owner.attachTouchProvider(provider, userEnabled: true)
        var factoryCalls = 0
        LauncherRuntimeServices.applyActivationPreferences(preferences(fourFingerEnabled: true), to: owner,
            isolated: false, makeTouchProvider: {
                factoryCalls += 1
                return MockTouchProvider(clock: FakePinchClock())
            })
        XCTAssertEqual(factoryCalls, 0)
        XCTAssertTrue(owner.touchProvider === provider)
        XCTAssertTrue(provider.isStarted)
    }

    func testRefusedSettingsSaveStopsNewlyCreatedProviderDuringRuntimeRollback() {
        let provider = MockTouchProvider(clock: FakePinchClock())
        let owner = runtimeOwner(clock: FakePinchClock())
        defer { owner.teardownActivationServices() }
        let off = preferences(fourFingerEnabled: false)
        let store = InMemoryActivationPreferencesStore(initial: off)
        store.forcedStoredVersion = ActivationPreferences.currentSchemaVersion + 1
        var factoryCalls = 0
        let settings = ActivationSettingsCoordinator(store: store, loginService: FakeLaunchAtLoginService(),
            initialCommitted: off, applyPreferences: { accepted in
                LauncherRuntimeServices.applyActivationPreferences(accepted, to: owner, isolated: false,
                    makeTouchProvider: { factoryCalls += 1; return provider })
            })
        var draft = ActivationPreferencesDraft(committed: off)
        draft.fourFingerActivationEnabled = true
        guard case .persistRefused(_, let acceptedRuntime, let runtimeRestored) = settings.applyDraft(draft) else {
            return XCTFail("A future-schema refusal must retain the existing rollback contract")
        }
        XCTAssertTrue(runtimeRestored)
        XCTAssertFalse(acceptedRuntime.fourFingerActivationEnabled)
        XCTAssertFalse(settings.committed.fourFingerActivationEnabled)
        XCTAssertEqual(factoryCalls, 1)
        XCTAssertFalse(provider.isStarted)
        XCTAssertFalse(owner.appliedPlan.fourFingerEnabled)
        XCTAssertEqual(owner.fourFinger?.activation.state, .off)
    }

}
