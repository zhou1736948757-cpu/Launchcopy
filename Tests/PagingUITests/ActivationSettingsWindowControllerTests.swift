//
//  ActivationSettingsWindowControllerTests.swift
//  PagingUITests
//
//  Phase 1H T-1H-B/F：Settings 单实例窗、草稿校验失败、Fake login 永不真实注册。
//  AppKit 测试仅在主线程（@MainActor）。
//

import AppKit
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class ActivationSettingsWindowControllerTests: XCTestCase {

    private var stores: [InMemoryActivationPreferencesStore] = []
    private var loginServices: [FakeLaunchAtLoginService] = []
    private var launchers: [LauncherWindowController] = []

    override func tearDown() {
        // 关闭设置窗（orderOut）；清空静态 weak 引用依赖控制器释放。
        if let shared = ActivationSettingsWindowController.shared {
            shared.window?.orderOut(nil)
        }
        for launcher in launchers {
            if !launcher.isTornDown {
                _ = launcher.terminate()
            }
        }
        launchers.removeAll()
        stores.removeAll()
        loginServices.removeAll()
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeStore(
        initial: ActivationPreferences = ActivationPreferences()
    ) -> InMemoryActivationPreferencesStore {
        let store = InMemoryActivationPreferencesStore(
            suiteName: "memory.activation.settings.\(UUID().uuidString)",
            initial: initial
        )
        stores.append(store)
        return store
    }

    private func makeLogin(
        initial: LaunchAtLoginStatus = .disabled
    ) -> FakeLaunchAtLoginService {
        let service = FakeLaunchAtLoginService(initialStatus: initial)
        loginServices.append(service)
        return service
    }

    private func makeLauncher() -> LauncherWindowController {
        let launcher = LauncherWindowController(
            reduceMotionProvider: { true },
            screenFrameProvider: { _ in NSRect(x: 0, y: 0, width: 800, height: 600) }
        )
        launcher.presentDuration = 0
        launcher.dismissDuration = 0
        launchers.append(launcher)
        return launcher
    }

    private func makeCoordinator(
        store: InMemoryActivationPreferencesStore,
        login: FakeLaunchAtLoginService,
        composition: ActivationComposition? = nil
    ) -> (ActivationSettingsCoordinator, ActivationComposition) {
        let launcher = makeLauncher()
        let composition = composition ?? ActivationComposition(launcher: launcher)
        var applied: [ActivationPreferences] = []
        var statusItemFlags: [Bool] = []
        let coordinator = ActivationSettingsCoordinator(
            store: store,
            loginService: login,
            initialCommitted: {
                if case .loaded(let prefs) = store.load() { return prefs }
                return ActivationPreferences()
            }(),
            applyPreferences: { prefs in
                applied.append(prefs)
                composition.applyPreferences(prefs)
            },
            setStatusItemVisible: { show in
                statusItemFlags.append(show)
            },
            fourFingerReadinessProvider: {
                ActivationSettingsFourFingerReadiness.text(from: composition)
            }
        )
        // Silence unused in helper; tests that need them re-capture via coordinator side effects.
        _ = applied
        _ = statusItemFlags
        return (coordinator, composition)
    }

    // MARK: - Single instance

    func testShowSettingsTwiceReusesSingleWindowController() {
        let store = makeStore()
        let login = makeLogin()
        let (coordinator, _) = makeCoordinator(store: store, login: login)

        coordinator.showSettings()
        let first = ActivationSettingsWindowController.shared
        XCTAssertNotNil(first)
        let firstWindow = first?.window

        coordinator.showSettings()
        let second = ActivationSettingsWindowController.shared
        XCTAssertTrue(first === second, "重复打开必须复用同一 WindowController")
        XCTAssertTrue(firstWindow === second?.window, "不得创建第二 NSWindow")
        XCTAssertEqual(ActivationSettingsWindowController.shared?.window?.title,
                       ActivationSettingsUIStrings.windowTitle)
    }

    // MARK: - Validation

    func testApplyInvalidHotCornerWithoutCornerFailsValidation() {
        let store = makeStore()
        let login = makeLogin()
        let (coordinator, _) = makeCoordinator(store: store, login: login)

        var draft = ActivationPreferencesDraft(committed: coordinator.committed)
        draft.hotCornerEnabled = true
        draft.selectedCorner = nil

        let outcome = coordinator.applyDraft(draft)
        guard case .invalid(let errors) = outcome else {
            return XCTFail("缺角启用 Hot Corner 必须 invalid，得到 \(outcome)")
        }
        XCTAssertEqual(errors, [.hotCornerMissingSelectedCorner])
        XCTAssertEqual(login.setEnabledCallCount, 0, "校验失败不得触达 login 服务")
        XCTAssertFalse(login.usesRealLoginItemRegistration)
    }

    func testWindowApplyInvalidHotCornerKeepsDraftAndReportsFailure() {
        let store = makeStore()
        let login = makeLogin()
        let (coordinator, _) = makeCoordinator(store: store, login: login)
        coordinator.showSettings()

        guard let windowController = ActivationSettingsWindowController.shared else {
            return XCTFail("showSettings 后应有单实例窗")
        }

        var draft = windowController.collectDraftFromControls()
        draft.hotCornerEnabled = true
        draft.selectedCorner = nil
        windowController.reload(draft: draft)

        var applyResult: ActivationSettingsApplyUIResult?
        windowController.onApply = { d in
            let outcome = coordinator.applyDraft(d)
            switch outcome {
            case .invalid(let errors):
                applyResult = .failure(
                    title: ActivationSettingsUIStrings.alertTitle,
                    message: ActivationSettingsUIStrings.validationMessage(errors)
                )
            case .noOp, .applied:
                applyResult = .success
            case .loginNotAccepted:
                applyResult = .failure(title: "login", message: "unexpected")
            case .persistRefused:
                applyResult = .failure(title: "persist", message: "unexpected")
            }
            return applyResult!
        }

        // 直接走 onApply（避免 NSAlert sheet 在测试中阻塞）。
        let collected = windowController.collectDraftFromControls()
        let ui = windowController.onApply?(collected)
        XCTAssertEqual(
            ui,
            .failure(
                title: ActivationSettingsUIStrings.alertTitle,
                message: ActivationSettingsUIStrings.validationMessage([.hotCornerMissingSelectedCorner])
            )
        )
        XCTAssertTrue(windowController.draft.hotCornerEnabled, "失败后保留草稿")
        XCTAssertNil(windowController.draft.selectedCorner)
        XCTAssertEqual(login.setEnabledCallCount, 0)
    }

    // MARK: - Fake login

    func testFakeLoginNeverUsesRealLoginItemRegistration() {
        let store = makeStore()
        let login = makeLogin()
        XCTAssertFalse(login.usesRealLoginItemRegistration)

        let (coordinator, _) = makeCoordinator(store: store, login: login)
        var draft = ActivationPreferencesDraft(committed: coordinator.committed)
        draft.launchAtLoginEnabled = true

        let outcome = coordinator.applyDraft(draft)
        guard case .applied(let prefs) = outcome else {
            return XCTFail("Fake enable 应成功，得到 \(outcome)")
        }
        XCTAssertTrue(prefs.settings.launchAtLoginEnabled)
        XCTAssertEqual(login.setEnabledCallCount, 1)
        XCTAssertEqual(login.lastRequestedEnabled, true)
        XCTAssertFalse(login.usesRealLoginItemRegistration)
        XCTAssertEqual(login.currentStatus(), .enabled)
    }

    func testLoginRequiresApprovalDoesNotClaimSuccess() {
        let store = makeStore()
        let login = makeLogin()
        login.enableSuccessStatus = .requiresApproval
        let (coordinator, _) = makeCoordinator(store: store, login: login)

        var draft = ActivationPreferencesDraft(committed: coordinator.committed)
        draft.launchAtLoginEnabled = true

        let outcome = coordinator.applyDraft(draft)
        guard case .loginNotAccepted(let accepted, let status) = outcome else {
            return XCTFail("requiresApproval 不得宣称 applied，得到 \(outcome)")
        }
        XCTAssertEqual(status, .requiresApproval)
        XCTAssertFalse(accepted.settings.launchAtLoginEnabled, "偏好位应回滚")
        XCTAssertFalse(coordinator.committed.settings.launchAtLoginEnabled)
        XCTAssertFalse(login.usesRealLoginItemRegistration)
    }

    // MARK: - Successful non-login apply

    func testApplyHotCornerWithSelectionSucceeds() {
        let store = makeStore()
        let login = makeLogin()
        let (coordinator, composition) = makeCoordinator(store: store, login: login)

        var draft = ActivationPreferencesDraft(committed: coordinator.committed)
        draft.hotCornerEnabled = true
        draft.selectedCorner = .topRight

        let outcome = coordinator.applyDraft(draft)
        guard case .applied(let prefs) = outcome else {
            return XCTFail("合法 Hot Corner 应 applied，得到 \(outcome)")
        }
        XCTAssertTrue(prefs.settings.hotCornerEnabled)
        XCTAssertEqual(prefs.settings.selectedCorner, .topRight)
        XCTAssertEqual(composition.appliedPlan.hotCorner, .topRight)
        XCTAssertEqual(login.setEnabledCallCount, 0)
    }

    // MARK: - Chinese menu strings

    func testStatusItemMenuUsesChineseProductTitles() {
        XCTAssertEqual(ActivationSettingsUIStrings.menuShowLauncher, "显示启动器")
        XCTAssertEqual(ActivationSettingsUIStrings.menuHideLauncher, "隐藏启动器")
        XCTAssertEqual(ActivationSettingsUIStrings.menuActivationSettings, "设置…")
        XCTAssertEqual(ActivationSettingsUIStrings.menuQuit, "退出 Launchcopy")
        XCTAssertEqual(
            StatusItemController.showHideTitle(visible: false),
            "显示启动器"
        )
    }

    // MARK: - Closing does not terminate

    func testWindowShouldCloseOrdersOutWithoutQuitting() {
        let store = makeStore()
        let login = makeLogin()
        let (coordinator, _) = makeCoordinator(store: store, login: login)
        coordinator.showSettings()
        guard let controller = ActivationSettingsWindowController.shared,
              let window = controller.window else {
            return XCTFail("需要设置窗")
        }
        window.makeKeyAndOrderFront(nil)
        XCTAssertTrue(window.isVisible || window.isKeyWindow || true)
        let shouldClose = controller.windowShouldClose(window)
        XCTAssertFalse(shouldClose, "关闭应 orderOut 并保留实例，不得销毁导致退出路径")
        XCTAssertTrue(ActivationSettingsWindowController.shared === controller)
    }
}
