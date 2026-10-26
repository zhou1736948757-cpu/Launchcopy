import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

/// Actual unshown settings controls. No store, service registration, app launch or
/// global recording monitor is used. Main owns native execution after integration.
@MainActor
final class ActivationLanguageConsumersTests: XCTestCase {
    private let languages: [InterfaceLanguage] = [.english, .simplifiedChinese, .japanese]

    private func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }

    private func activationRoot(_ controller: ActivationSettingsWindowController) throws -> NSView {
        let tabs = try XCTUnwrap(controller.window?.contentView as? NSTabView)
        return try XCTUnwrap(tabs.tabViewItems.first { $0.identifier as? String == "activation" }?.view)
    }

    private func control<T: NSView>(
        _ type: T.Type, in root: NSView, key: ActivationTextKey, strings: LocalizedStrings
    ) throws -> T {
        try XCTUnwrap(descendants(root).compactMap { $0 as? T }.first {
            $0.accessibilityLabel() == strings.activationText(key)
        })
    }

    private func keyEvent(_ code: UInt16, flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                                      timestamp: 0, windowNumber: 0, context: nil, characters: "",
                                      charactersIgnoringModifiers: "", isARepeat: false, keyCode: code))
    }

    private func dispose(_ controller: ActivationSettingsWindowController) {
        controller.hideSettings()
        controller.window?.delegate = nil
        controller.window?.contentView = nil
    }

    func testInitialSnapshotConfiguresActualActivationTextAndAccessibility() throws {
        let buttonKeys: [(ActivationTextKey, ActivationTextKey)] = [
            (.showStatusItem, .showStatusItemAccessibility),
            (.globalShortcutEnable, .globalShortcutEnable),
            (.shortcutRecord, .shortcutRecordAccessibility),
            (.hotCornerEnable, .hotCornerEnable),
            (.fourFingerEnable, .fourFingerEnable),
            (.launchAtLoginEnable, .launchAtLoginAccessibility),
            (.apply, .applyAccessibility), (.revert, .revertAccessibility), (.close, .closeAccessibility)
        ]
        var recordTitles: [String] = []
        for language in languages {
            let strings = LocalizedStrings(language: language)
            let controller = ActivationSettingsWindowController(draft: .init(), strings: strings)
            defer { dispose(controller) }
            let root = try activationRoot(controller)
            XCTAssertFalse(try XCTUnwrap(controller.window).isVisible)
            XCTAssertEqual(controller.window?.title, strings.settingsText(.settingsWindowTitle))
            for (title, accessibility) in buttonKeys {
                let button = try control(NSButton.self, in: root, key: accessibility, strings: strings)
                XCTAssertEqual(button.title, strings.activationText(title))
                XCTAssertTrue(button.target === controller)
                XCTAssertNotNil(button.action)
            }
            let captionKeys: [ActivationTextKey] = [.globalShortcut, .shortcutPresetLabel, .hotCorner, .fourFinger, .launchAtLogin]
            for key in captionKeys {
                let caption = try control(NSTextField.self, in: root, key: key, strings: strings)
                XCTAssertEqual(caption.stringValue, strings.activationText(key))
            }
            let recorder = try control(NSButton.self, in: root, key: .shortcutRecordAccessibility, strings: strings)
            let description = try control(NSTextField.self, in: root, key: .shortcutDescriptionAccessibility, strings: strings)
            XCTAssertEqual(recorder.toolTip, strings.activationText(.shortcutRecordingHelp))
            XCTAssertEqual(recorder.accessibilityHelp(), recorder.toolTip)
            XCTAssertEqual(description.accessibilityHelp(), recorder.toolTip)
            XCTAssertEqual(description.stringValue, ActivationSettingsUIStrings.shortcutDescription(controller.draft.shortcut, strings: strings))
            XCTAssertEqual(description.accessibilityValue() as? String, description.stringValue)
            let corners = try control(NSPopUpButton.self, in: root, key: .hotCornerAccessibility, strings: strings)
            XCTAssertEqual(corners.itemArray.map(\.tag), [-1, 0, 1, 2, 3])
            XCTAssertEqual(corners.itemArray.map(\.title), [strings.activationText(.cornerNone)] + HotCorner.allCases.map {
                ActivationSettingsUIStrings.cornerTitle($0, strings: strings)
            })
            let presets = try control(NSPopUpButton.self, in: root, key: .shortcutPresetAccessibility, strings: strings)
            XCTAssertEqual(presets.itemArray.map(\.tag), ShortcutPreset.menuOrder.map(\.rawValue))
            XCTAssertEqual(presets.itemArray.map(\.title), ShortcutPreset.menuOrder.map { $0.menuTitle(strings: strings) })
            let readiness = try control(NSTextField.self, in: root, key: .fourFingerStatusAccessibility, strings: strings)
            let login = try control(NSTextField.self, in: root, key: .launchAtLoginStatusAccessibility, strings: strings)
            XCTAssertEqual(readiness.stringValue, strings.activationStatusText(.activationGestureNotReady))
            XCTAssertEqual(login.stringValue, strings.activationStatusText(.activationLoginDisabled))
            recordTitles.append(recorder.title)
        }
        XCTAssertEqual(Set(recordTitles).count, 3, "All shipped supported tables must translate the real consumer")
    }

    func testRelabelPreservesMountedControlsItemsBindingsDraftsAndSelectedTab() throws {
        let initial = LocalizedStrings(language: .english)
        var draft = ActivationPreferencesDraft()
        draft.showStatusItem = false
        draft.globalShortcutEnabled = true
        draft.shortcut = ShortcutSpec(keyCode: 200, modifiers: [.control, .command])
        draft.hotCornerEnabled = true
        draft.selectedCorner = .bottomRight
        draft.fourFingerActivationEnabled = false
        draft.launchAtLoginEnabled = true
        let controller = ActivationSettingsWindowController(draft: draft, strings: initial)
        defer { dispose(controller) }
        let root = try activationRoot(controller)
        let tabs = try XCTUnwrap(controller.window?.contentView as? NSTabView)
        let cornerPopup = try control(NSPopUpButton.self, in: root, key: .hotCornerAccessibility, strings: initial)
        let presets = try control(NSPopUpButton.self, in: root, key: .shortcutPresetAccessibility, strings: initial)
        let shortcut = try control(NSTextField.self, in: root, key: .shortcutDescriptionAccessibility, strings: initial)
        let views = descendants(root)
        let identities = views.map(ObjectIdentifier.init)
        let constraints = views.flatMap(\.constraints).map(ObjectIdentifier.init)
        let controls = views.compactMap { $0 as? NSControl }
        let actions = controls.map(\.action)
        let targets = controls.map { $0.target as? NSObject }
        let enabled = controls.map(\.isEnabled)
        let buttons = controls.compactMap { $0 as? NSButton }.filter { !($0 is NSPopUpButton) }
        let states = buttons.map(\.state)
        let cornerItems = cornerPopup.itemArray
        let presetItems = presets.itemArray
        let marker = NSObject()
        cornerItems.forEach { $0.representedObject = marker }
        presetItems.forEach { $0.representedObject = marker }
        let selectedCorner = cornerPopup.selectedItem
        let selectedPreset = presets.selectedItem
        tabs.selectTabViewItem(withIdentifier: "appearance")
        let selectedTab = tabs.selectedTabViewItem
        controller.appManagementView.aliasField.stringValue = "User draft 日本語 % 😀"
        controller.appearanceView.blurSlider.doubleValue = 37
        controller.languageView.languagePopup.selectItem(at: 2)
        let languageSelection = controller.languageView.languagePopup.selectedItem
        let responder = controller.window?.firstResponder
        var applyCalls = 0, revertCalls = 0, readinessChanges = 0, discarded = 0
        controller.onApply = { _ in applyCalls += 1; return .success }
        controller.onRevert = { revertCalls += 1; return .init() }
        controller.onLanguageReadinessChange = { readinessChanges += 1 }
        controller.onDiscardLanguageDraft = { discarded += 1 }
        for language in languages {
            let strings = LocalizedStrings(language: language)
            controller.relabel(strings: strings)
            XCTAssertEqual(controller.draft, draft)
            XCTAssertEqual(controller.collectDraftFromControls(), draft)
            XCTAssertEqual(descendants(root).map(ObjectIdentifier.init), identities)
            XCTAssertEqual(descendants(root).flatMap(\.constraints).map(ObjectIdentifier.init), constraints)
            XCTAssertEqual(controls.map(\.action), actions)
            XCTAssertEqual(controls.map(\.isEnabled), enabled)
            XCTAssertEqual(buttons.map(\.state), states)
            for (before, after) in zip(targets, controls.map({ $0.target as? NSObject })) { XCTAssertTrue(before === after) }
            for (before, after) in zip(cornerItems, cornerPopup.itemArray) { XCTAssertTrue(before === after) }
            for (before, after) in zip(presetItems, presets.itemArray) { XCTAssertTrue(before === after) }
            XCTAssertTrue(cornerPopup.selectedItem === selectedCorner)
            XCTAssertTrue(presets.selectedItem === selectedPreset)
            XCTAssertTrue((cornerPopup.selectedItem?.representedObject as? NSObject) === marker)
            XCTAssertTrue((presets.selectedItem?.representedObject as? NSObject) === marker)
            XCTAssertTrue(tabs.selectedTabViewItem === selectedTab)
            XCTAssertTrue(controller.window?.firstResponder === responder)
            XCTAssertEqual(controller.appManagementView.aliasField.stringValue, "User draft 日本語 % 😀")
            XCTAssertEqual(controller.appearanceView.blurSlider.doubleValue, 37)
            XCTAssertTrue(controller.languageView.languagePopup.selectedItem === languageSelection)
            XCTAssertEqual(shortcut.stringValue, "⌃⌘·" + strings.activationKeyCode(200))
            XCTAssertEqual(applyCalls + revertCalls + readinessChanges + discarded, 0)
        }
    }

    func testRelabelPreservesRecordingAndBareKeyRejectionWithoutOwnershipChanges() throws {
        let initial = LocalizedStrings(language: .english)
        var draft = ActivationPreferencesDraft()
        draft.globalShortcutEnabled = true
        draft.shortcut = ShortcutPreset.commandOptionSpace.spec
        let controller = ActivationSettingsWindowController(draft: draft, strings: initial)
        defer { dispose(controller) }
        let root = try activationRoot(controller)
        let recorder = try control(NSButton.self, in: root, key: .shortcutRecordAccessibility, strings: initial)
        let description = try control(NSTextField.self, in: root, key: .shortcutDescriptionAccessibility, strings: initial)
        let presets = try control(NSPopUpButton.self, in: root, key: .shortcutPresetAccessibility, strings: initial)
        let selected = presets.selectedItem
        var ownershipChanges = 0, applyCalls = 0
        controller.onLanguageReadinessChange = { ownershipChanges += 1 }
        controller.onApply = { _ in applyCalls += 1; return .success }
        recorder.performClick(nil)
        XCTAssertTrue(controller.isRecordingShortcut)
        XCTAssertEqual(ownershipChanges, 1)
        // Deliberately exercise the relabel-only consumer even while recording;
        // production's language owner postpones this call until recording ends.
        for rejected in [false, true] {
            if rejected { controller.handleShortcutRecordingKeyDown(try keyEvent(49)) }
            for language in languages {
                let strings = LocalizedStrings(language: language)
                controller.relabel(strings: strings)
                XCTAssertTrue(controller.isRecordingShortcut)
                XCTAssertTrue(controller.hasLanguagePresentationOwnership)
                XCTAssertEqual(recorder.title, strings.activationText(.shortcutRecordingPrompt))
                XCTAssertEqual(recorder.accessibilityLabel(), recorder.title)
                XCTAssertEqual(description.stringValue, strings.activationText(rejected ? .shortcutNeedsModifier : .shortcutRecordingPrompt))
                XCTAssertEqual(description.accessibilityValue() as? String, description.stringValue)
                XCTAssertEqual(controller.draft, draft)
                XCTAssertTrue(presets.selectedItem === selected)
                XCTAssertEqual(ownershipChanges, 1)
                XCTAssertEqual(applyCalls, 0)
            }
        }
        controller.handleShortcutRecordingKeyDown(try keyEvent(53, flags: [.command]))
        XCTAssertFalse(controller.isRecordingShortcut)
        XCTAssertFalse(controller.hasLanguagePresentationOwnership)
        XCTAssertEqual(controller.draft, draft)
        XCTAssertEqual(ownershipChanges, 2)
        XCTAssertEqual(recorder.title, LocalizedStrings(language: .japanese).activationText(.shortcutRecord))
        XCTAssertEqual(description.stringValue, "⌥⌘Space")
    }

    func testActualRecordingAcceptanceAndPresetActionsKeepRawShortcutBindings() throws {
        let initial = LocalizedStrings(language: .japanese)
        var draft = ActivationPreferencesDraft()
        draft.globalShortcutEnabled = true
        let controller = ActivationSettingsWindowController(draft: draft, strings: initial)
        defer { dispose(controller) }
        let root = try activationRoot(controller)
        let recorder = try control(NSButton.self, in: root, key: .shortcutRecordAccessibility, strings: initial)
        let presets = try control(NSPopUpButton.self, in: root, key: .shortcutPresetAccessibility, strings: initial)
        let description = try control(NSTextField.self, in: root, key: .shortcutDescriptionAccessibility, strings: initial)
        recorder.performClick(nil)
        controller.handleShortcutRecordingKeyDown(try keyEvent(200, flags: [.control, .command]))
        let recorded = ShortcutSpec(keyCode: 200, modifiers: [.control, .command])
        XCTAssertFalse(controller.isRecordingShortcut)
        XCTAssertEqual(controller.draft.shortcut, recorded)
        XCTAssertEqual(presets.selectedItem?.tag, ShortcutPreset.custom.rawValue)
        XCTAssertEqual(description.stringValue, "⌃⌘·" + initial.activationKeyCode(200))
        for language in languages {
            let strings = LocalizedStrings(language: language)
            controller.relabel(strings: strings)
            for preset in ShortcutPreset.menuOrder where preset != .custom {
                let index = presets.indexOfItem(withTag: preset.rawValue)
                presets.selectItem(at: index)
                XCTAssertTrue(presets.sendAction(try XCTUnwrap(presets.action), to: presets.target))
                XCTAssertEqual(controller.draft.shortcut, preset.spec)
                XCTAssertTrue(controller.draft.globalShortcutEnabled)
                XCTAssertEqual(description.stringValue, ShortcutDisplay.description(for: try XCTUnwrap(preset.spec), strings: strings))
            }
            let previous = controller.draft.shortcut
            presets.selectItem(at: presets.indexOfItem(withTag: ShortcutPreset.custom.rawValue))
            XCTAssertTrue(presets.sendAction(try XCTUnwrap(presets.action), to: presets.target))
            XCTAssertEqual(controller.draft.shortcut, previous, "Custom preserves the user's binding")
        }
    }

    func testDisabledControlsAndMissingShortcutRemainDisabledAcrossRelabel() throws {
        let initial = LocalizedStrings(language: .english)
        var draft = ActivationPreferencesDraft()
        draft.globalShortcutEnabled = false
        draft.shortcut = nil
        draft.hotCornerEnabled = false
        draft.selectedCorner = nil
        let controller = ActivationSettingsWindowController(draft: draft, strings: initial)
        defer { dispose(controller) }
        let root = try activationRoot(controller)
        let recorder = try control(NSButton.self, in: root, key: .shortcutRecordAccessibility, strings: initial)
        let presets = try control(NSPopUpButton.self, in: root, key: .shortcutPresetAccessibility, strings: initial)
        let corners = try control(NSPopUpButton.self, in: root, key: .hotCornerAccessibility, strings: initial)
        let description = try control(NSTextField.self, in: root, key: .shortcutDescriptionAccessibility, strings: initial)
        for language in languages {
            let strings = LocalizedStrings(language: language)
            controller.relabel(strings: strings)
            XCTAssertFalse(recorder.isEnabled)
            XCTAssertFalse(presets.isEnabled)
            XCTAssertFalse(corners.isEnabled)
            XCTAssertEqual(corners.selectedItem?.tag, -1)
            XCTAssertEqual(description.stringValue, strings.activationText(.shortcutPlaceholder))
            XCTAssertEqual(controller.collectDraftFromControls(), draft)
            XCTAssertFalse(controller.isRecordingShortcut)
        }
    }

    func testRetainedReadinessAndLoginProvidersRerenderWithoutApplyOrDraftReload() throws {
        var displayed = LocalizedStrings(language: .english)
        var readinessReads = 0, loginReads = 0, applies = 0
        let draft = ActivationPreferencesDraft()
        let controller = ActivationSettingsWindowController(draft: draft, strings: displayed,
            fourFingerReadinessProvider: {
                readinessReads += 1
                return displayed.activationStatusText(.activationGestureNotReady)
            }, launchAtLoginStatusProvider: {
                loginReads += 1
                return displayed.activationStatusText(.activationLoginApproval)
            }, onApply: { _ in applies += 1; return .success })
        defer { dispose(controller) }
        let root = try activationRoot(controller)
        let readiness = try control(NSTextField.self, in: root, key: .fourFingerStatusAccessibility, strings: displayed)
        let login = try control(NSTextField.self, in: root, key: .launchAtLoginStatusAccessibility, strings: displayed)
        for language in languages {
            displayed = LocalizedStrings(language: language)
            let oldReadiness = readinessReads, oldLogin = loginReads
            controller.relabel(strings: displayed)
            XCTAssertEqual(readinessReads, oldReadiness + 1)
            XCTAssertEqual(loginReads, oldLogin + 1)
            XCTAssertEqual(readiness.stringValue, displayed.activationStatusText(.activationGestureNotReady))
            XCTAssertEqual(login.stringValue, displayed.activationStatusText(.activationLoginApproval))
            XCTAssertEqual(readiness.accessibilityValue() as? String, readiness.stringValue)
            XCTAssertEqual(login.accessibilityValue() as? String, login.stringValue)
            XCTAssertEqual(controller.draft, draft)
            XCTAssertEqual(applies, 0)
        }
    }

    func testApplyAndRestoreBannersRetainSemanticKindColorAndVisibilityAcrossRelabel() throws {
        let initial = LocalizedStrings(language: .english)
        let controller = ActivationSettingsWindowController(draft: .init(), strings: initial)
        defer { dispose(controller) }
        let root = try activationRoot(controller)
        let apply = try control(NSButton.self, in: root, key: .applyAccessibility, strings: initial)
        let restore = try control(NSButton.self, in: root, key: .revertAccessibility, strings: initial)
        let banner = try control(NSTextField.self, in: root, key: .applyResultAccessibility, strings: initial)
        var applies = 0, restores = 0
        controller.onApply = { _ in applies += 1; return .success }
        controller.onRevert = { restores += 1; return .init() }
        XCTAssertTrue(banner.isHidden)
        for (button, key) in [(apply, ActivationTextKey.applySuccess), (restore, .defaultsRestored)] {
            button.performClick(nil)
            let oldApplies = applies, oldRestores = restores
            let draft = controller.draft
            for language in languages {
                let strings = LocalizedStrings(language: language)
                controller.relabel(strings: strings)
                XCTAssertEqual(banner.stringValue, strings.activationText(key))
                XCTAssertEqual(banner.accessibilityValue() as? String, banner.stringValue)
                XCTAssertEqual(banner.textColor, .systemGreen)
                XCTAssertFalse(banner.isHidden)
                XCTAssertEqual(controller.draft, draft)
                XCTAssertEqual(applies, oldApplies)
                XCTAssertEqual(restores, oldRestores)
            }
        }
        XCTAssertEqual(applies, 2)
        XCTAssertEqual(restores, 1)
    }

    func testExpiredSuccessBannerIsNotRevivedByRelabel() async throws {
        let strings = LocalizedStrings(language: .english)
        let controller = ActivationSettingsWindowController(draft: .init(), strings: strings)
        defer { dispose(controller) }
        let root = try activationRoot(controller)
        let apply = try control(NSButton.self, in: root, key: .applyAccessibility, strings: strings)
        let banner = try control(NSTextField.self, in: root, key: .applyResultAccessibility, strings: strings)
        apply.performClick(nil)
        XCTAssertFalse(banner.isHidden)
        try await Task.sleep(nanoseconds: 1_300_000_000)
        for language in languages {
            controller.relabel(strings: LocalizedStrings(language: language))
            XCTAssertTrue(banner.isHidden)
            XCTAssertEqual(banner.stringValue, "")
        }
    }

    func testActionTimeAlertBuilderAndValidationUseDisplayedLanguageWithoutPresenting() throws {
        let errors: [ActivationDraftValidationError] = [.hotCornerMissingSelectedCorner, .shortcutMissingSpec, .shortcutMissingModifiers]
        let keys: [ActivationTextKey] = [.validationCornerMissing, .validationShortcutMissing, .validationShortcutModifiers]
        let controller = ActivationSettingsWindowController(draft: .init(), strings: LocalizedStrings(language: .english))
        defer { dispose(controller) }
        for language in languages {
            let strings = LocalizedStrings(language: language)
            controller.relabel(strings: strings)
            let message = ActivationSettingsUIStrings.validationMessage(errors, strings: strings)
            XCTAssertEqual(message, keys.map { strings.activationText($0) }.joined(separator: "\n"))
            let alert = controller.makeAlert(title: strings.activationText(.alertTitle), message: message)
            XCTAssertEqual(alert.messageText, strings.activationText(.alertTitle))
            XCTAssertEqual(alert.informativeText, message)
            XCTAssertEqual(alert.buttons.map(\.title), [strings.activationText(.close)])
            XCTAssertEqual(alert.alertStyle, .warning)
            XCTAssertNil(controller.window?.attachedSheet)
            XCTAssertFalse(try XCTUnwrap(controller.window).isVisible)
            let nativeDetail = "Native failure: 日本語 % %@ {keyCode} 😀"
            let loginAlert = controller.makeAlert(title: strings.activationText(.loginAlertTitle), message: nativeDetail)
            XCTAssertEqual(loginAlert.informativeText, nativeDetail)
        }
    }
}
