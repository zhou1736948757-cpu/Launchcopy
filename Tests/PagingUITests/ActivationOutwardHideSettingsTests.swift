import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

/// Unshown native controls with injected callbacks. Main owns execution.
@MainActor
final class ActivationOutwardHideSettingsTests: XCTestCase {
    private let outwardID = "activation.fourFingerOutwardHide"
    private let strings = LocalizedStrings(language: .english)

    private func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }

    private func root(_ controller: ActivationSettingsWindowController) throws -> NSView {
        let tabs = try XCTUnwrap(controller.window?.contentView as? NSTabView)
        return try XCTUnwrap(tabs.tabViewItems.first { $0.identifier as? String == "activation" }?.view)
    }

    private func outward(_ controller: ActivationSettingsWindowController) throws -> NSButton {
        try XCTUnwrap(descendants(root(controller)).compactMap { $0 as? NSButton }.first {
            $0.accessibilityIdentifier() == outwardID
        })
    }

    private func button(
        _ controller: ActivationSettingsWindowController, _ key: ActivationTextKey
    ) throws -> NSButton {
        try XCTUnwrap(descendants(root(controller)).compactMap { $0 as? NSButton }.first {
            $0.accessibilityLabel() == strings.activationText(key)
        })
    }

    private func dispose(_ controller: ActivationSettingsWindowController) {
        controller.hideSettings()
        controller.window?.delegate = nil
        controller.window?.contentView = nil
    }

    func testInitialParentOffDisablesNestedChoiceWithoutClearingIt() throws {
        let draft = ActivationPreferencesDraft(
            fourFingerActivationEnabled: false, fourFingerOutwardHideEnabled: true
        )
        let controller = ActivationSettingsWindowController(draft: draft, strings: strings)
        defer { dispose(controller) }
        let child = try outward(controller)
        let parent = try button(controller, .fourFingerEnable)
        XCTAssertFalse(try XCTUnwrap(controller.window).isVisible)
        XCTAssertEqual(child.identifier?.rawValue, outwardID)
        XCTAssertEqual(child.state, .on)
        XCTAssertFalse(child.isEnabled)
        XCTAssertFalse(child.superview === parent.superview, "The optional control must be nested")
        XCTAssertTrue(child.superview?.superview === parent.superview)
        child.performClick(nil)
        XCTAssertEqual(controller.collectDraftFromControls(), draft)
    }

    func testParentActionRefreshesEnabledStateAndCollectsUnappliedEditsWithoutApplying() throws {
        var expected = ActivationPreferencesDraft(
            fourFingerOutwardHideEnabled: true,
            globalShortcutEnabled: true,
            shortcut: ShortcutSpec(keyCode: 3, modifiers: [.command, .shift])
        )
        let controller = ActivationSettingsWindowController(draft: expected, strings: strings)
        defer { dispose(controller) }
        let child = try outward(controller)
        let parent = try button(controller, .fourFingerEnable)
        var applies = 0
        controller.onApply = { _ in applies += 1; return .success }
        // Other controls can hold edits that have not sent their action yet.
        try button(controller, .showStatusItemAccessibility).state = .off
        try button(controller, .launchAtLoginAccessibility).state = .on
        expected.showStatusItem = false
        expected.launchAtLoginEnabled = true
        expected.fourFingerActivationEnabled = false
        parent.performClick(nil)
        XCTAssertFalse(child.isEnabled)
        XCTAssertEqual(child.state, .on)
        XCTAssertEqual(controller.draft, expected)
        XCTAssertEqual(controller.collectDraftFromControls(), expected)
        XCTAssertEqual(applies, 0)

        parent.performClick(nil)
        XCTAssertTrue(child.isEnabled)
        XCTAssertEqual(child.state, .on)
        XCTAssertTrue(controller.draft.fourFingerOutwardHideEnabled)
        child.performClick(nil)
        XCTAssertFalse(controller.draft.fourFingerOutwardHideEnabled)
        parent.performClick(nil)
        XCTAssertFalse(child.isEnabled)
        XCTAssertEqual(child.state, .off)
        XCTAssertEqual(controller.draft.shortcut, expected.shortcut)
        XCTAssertFalse(controller.draft.showStatusItem)
        XCTAssertTrue(controller.draft.launchAtLoginEnabled)
        XCTAssertEqual(applies, 0)
    }

    func testRelabelKeepsControlIdentityChoiceAndAvailabilityAcrossAllLanguages() throws {
        let draft = ActivationPreferencesDraft(
            fourFingerActivationEnabled: false, fourFingerOutwardHideEnabled: true
        )
        let controller = ActivationSettingsWindowController(draft: draft, strings: strings)
        defer { dispose(controller) }
        let child = try outward(controller)
        for language in InterfaceLanguage.allCases {
            let localized = LocalizedStrings(language: language)
            controller.relabel(strings: localized)
            XCTAssertTrue(try outward(controller) === child)
            XCTAssertEqual(child.title, localized.activationText(.fourFingerOutwardHideEnable))
            XCTAssertEqual(child.accessibilityLabel(), child.title)
            XCTAssertEqual(child.toolTip, localized.activationText(.fourFingerOutwardHideHelp))
            XCTAssertEqual(child.accessibilityHelp(), child.toolTip)
            XCTAssertFalse(child.isEnabled)
            XCTAssertEqual(child.state, .on)
            XCTAssertEqual(controller.collectDraftFromControls(), draft)
        }
    }

    func testExplicitApplyFailureKeepsOptionalDraftAndRetryAppliesSameChoice() throws {
        let controller = ActivationSettingsWindowController(draft: .init(), strings: strings)
        defer { dispose(controller) }
        let child = try outward(controller)
        let apply = try button(controller, .applyAccessibility)
        var attempts: [ActivationPreferencesDraft] = []
        var shouldFail = true
        var alerts = 0
        controller.alertPresenter = { alert, _, finish in
            alerts += 1
            XCTAssertEqual(alert.informativeText, "Save refused")
            finish()
        }
        controller.onApply = { draft in
            attempts.append(draft)
            return shouldFail ? .failure(title: "Apply failed", message: "Save refused") : .success
        }
        child.performClick(nil)
        XCTAssertTrue(attempts.isEmpty)
        XCTAssertTrue(controller.draft.fourFingerOutwardHideEnabled)
        apply.performClick(nil)
        XCTAssertEqual(alerts, 1)
        XCTAssertEqual(attempts.count, 1)
        XCTAssertTrue(controller.draft.fourFingerOutwardHideEnabled)
        XCTAssertEqual(child.state, .on)
        shouldFail = false
        apply.performClick(nil)
        XCTAssertEqual(attempts.count, 2)
        XCTAssertEqual(attempts.first, attempts.last)
        XCTAssertTrue(try XCTUnwrap(attempts.last).fourFingerOutwardHideEnabled)
    }

    func testRestoreDefaultsUsesExistingApplyPathAndClearsOptionalChoice() throws {
        let controller = ActivationSettingsWindowController(
            draft: .init(fourFingerActivationEnabled: false, fourFingerOutwardHideEnabled: true),
            strings: strings
        )
        defer { dispose(controller) }
        var applied: [ActivationPreferencesDraft] = []
        var restores = 0
        controller.onRevert = { restores += 1; return .init(committed: ActivationPreferences()) }
        controller.onApply = { applied.append($0); return .success }
        try button(controller, .revertAccessibility).performClick(nil)
        XCTAssertEqual(restores, 1)
        XCTAssertEqual(applied, [ActivationPreferencesDraft()])
        XCTAssertEqual(controller.collectDraftFromControls(), .init())
        XCTAssertEqual(try outward(controller).state, .off)
        XCTAssertTrue(try outward(controller).isEnabled)
    }

    func testRestoreDefaultsOnFutureStoreUsesSaveRefusalAndPreservesStoredChoice() throws {
        let committed = ActivationPreferences(
            fourFingerActivationEnabled: false, fourFingerOutwardHideEnabled: true
        )
        let store = InMemoryActivationPreferencesStore(initial: committed)
        store.forcedStoredVersion = 4
        let controller = ActivationSettingsWindowController(draft: .init(committed: committed), strings: strings)
        defer { dispose(controller) }
        let login = FakeLaunchAtLoginService()
        var runtime: [ActivationPreferences] = []
        var alerts = 0
        controller.alertPresenter = { _, _, finish in alerts += 1; finish() }
        controller.onRevert = { .init() }
        controller.onApply = { draft in
            let result = ActivationApplyTransaction.run(
                committed: committed, draft: draft,
                context: ActivationApplyTransactionContext(
                    applyPreferences: { runtime.append($0) },
                    loginService: login, persist: { store.save($0) }
                )
            )
            XCTAssertEqual(result, .persistRefused(
                storedVersion: 4, acceptedRuntime: committed, runtimeRestored: true
            ))
            return .failure(title: "Apply failed", message: "Future schema")
        }
        try button(controller, .revertAccessibility).performClick(nil)
        XCTAssertEqual(alerts, 1)
        XCTAssertEqual(runtime, [ActivationPreferences(), committed])
        store.forcedStoredVersion = nil
        XCTAssertEqual(store.load(), .loaded(committed))
        // The window retains the attempted defaults draft unless its owner reloads accepted runtime.
        XCTAssertEqual(controller.collectDraftFromControls(), .init())
    }
}
