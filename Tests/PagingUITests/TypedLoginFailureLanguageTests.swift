import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class TypedLoginFailureLanguageTests: XCTestCase {
    func testProductionCatchSeamUsesTypedDirectionAndKeepsTruthfulStates() {
        XCTAssertEqual(SMAppServiceLaunchAtLoginService.statusAfterFailedOperation(mapped: .disabled, enabling: true), .operationFailed(enabling: true))
        XCTAssertEqual(SMAppServiceLaunchAtLoginService.statusAfterFailedOperation(mapped: .enabled, enabling: false), .operationFailed(enabling: false))
        for enabling in [true, false] {
            for state in [LaunchAtLoginStatus.requiresApproval, .unavailable] {
                XCTAssertEqual(SMAppServiceLaunchAtLoginService.statusAfterFailedOperation(mapped: state, enabling: enabling), state)
            }
            XCTAssertEqual(SMAppServiceLaunchAtLoginService.statusAfterFailedOperation(mapped: .failure(message: "Native private detail"), enabling: enabling), .operationFailed(enabling: enabling))
            XCTAssertFalse(ActivationApplyTransaction.isLoginStatusAcceptable(.operationFailed(enabling: enabling), requestedEnabled: enabling))
        }
        XCTAssertEqual(SMAppServiceLaunchAtLoginService.statusAfterFailedOperation(mapped: .enabled, enabling: true), .enabled)
        XCTAssertEqual(SMAppServiceLaunchAtLoginService.statusAfterFailedOperation(mapped: .disabled, enabling: false), .disabled)
    }

    func testAllThreeLanguagesTranslateAuthoredReasonsButKeepNativeDetailLiteral() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            for enabling in [true, false] {
                let reason: ActivationStatusTextKey = enabling ? .activationLoginEnableFailed : .activationLoginDisableFailed
                XCTAssertEqual(ActivationServicePresentation.loginStatus(.operationFailed(enabling: enabling), strings: strings),
                    strings.activationStatusText(.activationLoginFailure) + " (" + strings.activationStatusText(reason) + ")")
            }
            let literal = "Native {path} %s 日本語 detail"
            XCTAssertEqual(ActivationServicePresentation.loginStatus(.failure(message: literal), strings: strings),
                strings.activationStatusText(.activationLoginFailure) + " (" + literal + ")")
        }
    }

    func testActualRetainedSettingsLabelRelabelsTypedFailureWithoutRecordingOrDraftReload() throws {
        let service = FakeLaunchAtLoginService(initialStatus: .operationFailed(enabling: true))
        let coordinator = ActivationSettingsCoordinator(store: InMemoryActivationPreferencesStore(), loginService: service)
        var strings = LocalizedStrings(language: .english)
        coordinator.interfaceStringsProvider = { strings }
        coordinator.preservesInterfaceDraftsOnReopen = true
        let controller = coordinator.prepareSettingsForPresentation()
        defer { controller.hideSettings(); controller.window?.delegate = nil; controller.window?.contentView = nil }
        let originalDraft = controller.draft
        func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
        let tabs = try XCTUnwrap(controller.window?.contentView as? NSTabView)
        let activation = try XCTUnwrap(tabs.tabViewItem(at: 0).view)
        for language in InterfaceLanguage.allCases {
            strings = LocalizedStrings(language: language)
            controller.relabel(strings: strings)
            let labels = descendants(activation).compactMap { $0 as? NSTextField }
            XCTAssertTrue(labels.contains { $0.stringValue == ActivationServicePresentation.loginStatus(.operationFailed(enabling: true), strings: strings) })
            XCTAssertEqual(controller.draft, originalDraft)
            XCTAssertFalse(controller.isRecordingShortcut)
            XCTAssertFalse(service.usesRealLoginItemRegistration)
            XCTAssertEqual(service.setEnabledCallCount, 0)
        }
    }
    func testActualApplyTransactionPersistsOtherSettingsRollsBackLoginAndBuildsLocalizedFailureAlert() throws {
        _ = NSApplication.shared
        var retainedControllers: [ActivationSettingsWindowController] = []
        defer {
            for controller in retainedControllers {
                controller.hideSettings(); controller.window?.delegate = nil; controller.window?.contentView = nil
            }
        }
        for language in InterfaceLanguage.allCases {
            for enabling in [true, false] {
                var initial = ActivationPreferences()
                initial.settings.launchAtLoginEnabled = !enabling
                let store = InMemoryActivationPreferencesStore(initial: initial)
                let service = FakeLaunchAtLoginService(initialStatus: enabling ? .disabled : .enabled)
                service.nextForcedStatus = .operationFailed(enabling: enabling)
                let coordinator = ActivationSettingsCoordinator(store: store, loginService: service, initialCommitted: initial)
                let strings = LocalizedStrings(language: language)
                coordinator.interfaceStringsProvider = { strings }
                let controller = coordinator.prepareSettingsForPresentation()
                retainedControllers.append(controller)
                var draft = ActivationPreferencesDraft(committed: initial)
                draft.launchAtLoginEnabled = enabling; draft.showStatusItem = false
                controller.reload(draft: draft)
                var alert: NSAlert?, finish: (() -> Void)?
                controller.alertPresenter = { value, _, completed in alert = value; finish = completed }
                func descendants(_ view: NSView) -> [NSView] { [view] + view.subviews.flatMap(descendants) }
                let content = try XCTUnwrap(controller.window?.contentView)
                let apply = try XCTUnwrap(descendants(content).compactMap { $0 as? NSButton }.first {
                    $0.action.map(NSStringFromSelector) == "applyClicked:"
                })
                apply.performClick(nil)
                XCTAssertEqual(service.setEnabledCallCount, enabling ? 2 : 1,
                    "Existing policy retries disable after failed enable; never re-enables after a failed disable")
                XCTAssertEqual(service.lastRequestedEnabled, false)
                XCTAssertFalse(service.usesRealLoginItemRegistration)
                XCTAssertEqual(coordinator.committed.settings.launchAtLoginEnabled, initial.settings.launchAtLoginEnabled)
                XCTAssertFalse(coordinator.committed.settings.showStatusItem)
                if case .loaded(let saved) = store.load() { XCTAssertEqual(saved, coordinator.committed) }
                else { XCTFail("Accepted rollback must be saved in the injected store") }
                let shown = try XCTUnwrap(alert)
                XCTAssertEqual(shown.messageText, strings.activationStatusText(.activationLoginAlertTitle))
                XCTAssertTrue(shown.informativeText.contains(strings.activationStatusText(
                    enabling ? .activationLoginEnableFailed : .activationLoginDisableFailed)))
                XCTAssertTrue(shown.informativeText.contains(strings.activationStatusText(.activationLoginPartial)))
                try XCTUnwrap(finish)()
                controller.hideSettings()
            }
        }
    }

}
