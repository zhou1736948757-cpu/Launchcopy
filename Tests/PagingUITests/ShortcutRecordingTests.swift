//
//  ShortcutRecordingTests.swift
//  PagingUITests
//
//  Phase 1H：ShortcutDisplay / ShortcutPreset / ShortcutRecording 纯映射测试。
//

import AppKit
import XCTest
@testable import PagingPrototypeApp

final class ShortcutRecordingTests: XCTestCase {

    // MARK: - Display

    func testKeyNameKnownCodes() {
        XCTAssertEqual(ShortcutDisplay.keyName(forKeyCode: 49), "Space")
        XCTAssertEqual(ShortcutDisplay.keyName(forKeyCode: 37), "L")
        XCTAssertEqual(ShortcutDisplay.keyName(forKeyCode: 36), "Return")
        XCTAssertEqual(ShortcutDisplay.keyName(forKeyCode: 48), "Tab")
        XCTAssertEqual(ShortcutDisplay.keyName(forKeyCode: 53), "Esc")
        XCTAssertNil(ShortcutDisplay.keyName(forKeyCode: 9999))
    }

    func testModifierSymbolsOrder() {
        XCTAssertEqual(
            ShortcutDisplay.modifierSymbols([.control, .option, .shift, .command]),
            "⌃⌥⇧⌘"
        )
        XCTAssertEqual(ShortcutDisplay.modifierSymbols([.command, .option]), "⌥⌘")
        XCTAssertEqual(ShortcutDisplay.modifierSymbols([]), "")
    }

    func testDescriptionHumanReadableAndFallback() {
        let space = ShortcutSpec(keyCode: 49, modifiers: [.command, .option])
        XCTAssertEqual(ShortcutDisplay.description(for: space), "⌥⌘Space")

        let unknown = ShortcutSpec(keyCode: 200, modifiers: [.control, .command])
        XCTAssertEqual(ShortcutDisplay.description(for: unknown), "⌃⌘·键码 200")

        let bareUnknown = ShortcutSpec(keyCode: 200, modifiers: [])
        XCTAssertEqual(ShortcutDisplay.description(for: bareUnknown), "键码 200")
    }

    func testUIStringsShortcutDescriptionUsesDisplay() {
        XCTAssertEqual(ActivationSettingsUIStrings.shortcutPlaceholder, "未设置")
        XCTAssertEqual(ActivationSettingsUIStrings.shortcutDescription(nil), "未设置")
        let spec = ShortcutSpec(keyCode: 37, modifiers: [.control, .option])
        XCTAssertEqual(
            ActivationSettingsUIStrings.shortcutDescription(spec),
            ShortcutDisplay.description(for: spec)
        )
        XCTAssertFalse(
            ActivationSettingsUIStrings.validationMessage([.shortcutMissingSpec])
                .contains("稍后可改")
        )
    }

    // MARK: - Presets

    func testPresetSpecsAndMatching() {
        XCTAssertNil(ShortcutPreset.custom.spec)
        XCTAssertEqual(
            ShortcutPreset.commandOptionSpace.spec,
            ShortcutSpec(keyCode: 49, modifiers: [.command, .option])
        )
        XCTAssertEqual(
            ShortcutPreset.controlCommandSpace.spec,
            ShortcutSpec(keyCode: 49, modifiers: [.control, .command])
        )
        XCTAssertEqual(
            ShortcutPreset.commandOptionL.spec,
            ShortcutSpec(keyCode: 37, modifiers: [.command, .option])
        )
        XCTAssertEqual(
            ShortcutPreset.controlOptionL.spec,
            ShortcutSpec(keyCode: 37, modifiers: [.control, .option])
        )

        XCTAssertEqual(
            ShortcutPreset.matching(ShortcutPreset.commandOptionSpace.spec),
            .commandOptionSpace
        )
        XCTAssertEqual(
            ShortcutPreset.matching(ShortcutSpec(keyCode: 0, modifiers: [.command])),
            .custom
        )
        XCTAssertEqual(ShortcutPreset.matching(nil), .custom)
        XCTAssertEqual(ShortcutPreset.commandOptionSpace.menuTitle, "⌥⌘Space")
        XCTAssertEqual(ShortcutPreset.custom.menuTitle, "自定义…")
        XCTAssertEqual(ShortcutPreset.custom.rawValue, -1)
    }

    // MARK: - Flag mapping / keyDown interpretation

    func testModifiersFromNSEventFlags() {
        let flags: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .capsLock]
        let mods = ShortcutRecording.modifiers(from: flags)
        XCTAssertEqual(mods, [.command, .option, .control, .shift])
        XCTAssertEqual(ShortcutRecording.modifiers(from: []), [])
    }

    func testInterpretKeyDownAcceptRejectCancel() {
        XCTAssertEqual(
            ShortcutRecording.interpretKeyDown(keyCode: 53, modifierFlags: [.command]),
            .cancel
        )
        XCTAssertEqual(
            ShortcutRecording.interpretKeyDown(keyCode: 49, modifierFlags: []),
            .rejectBareKey
        )
        XCTAssertEqual(
            ShortcutRecording.interpretKeyDown(keyCode: 49, modifierFlags: [.command, .option]),
            .accept(ShortcutSpec(keyCode: 49, modifiers: [.command, .option]))
        )
        XCTAssertEqual(
            ShortcutRecording.interpretKeyDown(keyCode: 37, modifierFlags: [.control, .option]),
            .accept(ShortcutSpec(keyCode: 37, modifiers: [.control, .option]))
        )
    }
}

@MainActor
final class ShortcutRecordingSettingsUITests: XCTestCase {

    override func tearDown() {
        if let shared = ActivationSettingsWindowController.shared {
            shared.window?.orderOut(nil)
        }
        super.tearDown()
    }

    func testPresetSelectionWritesShortcutAndEnables() {
        var draft = ActivationPreferencesDraft()
        draft.globalShortcutEnabled = false
        draft.shortcut = nil
        let controller = ActivationSettingsWindowController.sharedOrCreate(draft: draft)
        defer { controller.window?.orderOut(nil) }

        controller.applyShortcutPreset(.commandOptionL)
        XCTAssertEqual(
            controller.draft.shortcut,
            ShortcutSpec(keyCode: 37, modifiers: [.command, .option])
        )
        XCTAssertTrue(controller.draft.globalShortcutEnabled)
        XCTAssertEqual(
            ActivationSettingsUIStrings.shortcutDescription(controller.draft.shortcut),
            "⌥⌘L"
        )
        let collected = controller.collectDraftFromControls()
        XCTAssertEqual(collected.shortcut, controller.draft.shortcut)
        XCTAssertTrue(collected.globalShortcutEnabled)
    }

    func testRecordedShortcutSelectsCustomAndUpdatesDescription() {
        var draft = ActivationPreferencesDraft()
        draft.shortcut = ShortcutPreset.commandOptionSpace.spec
        draft.globalShortcutEnabled = true
        let controller = ActivationSettingsWindowController.sharedOrCreate(draft: draft)
        defer { controller.window?.orderOut(nil) }

        let custom = ShortcutSpec(keyCode: 3, modifiers: [.command, .shift])
        controller.applyRecordedShortcut(custom)
        XCTAssertEqual(controller.draft.shortcut, custom)
        XCTAssertTrue(controller.draft.globalShortcutEnabled)
        XCTAssertEqual(
            ActivationSettingsUIStrings.shortcutDescription(controller.draft.shortcut),
            "⇧⌘F"
        )
        XCTAssertEqual(ShortcutPreset.matching(controller.draft.shortcut), .custom)
    }

    func testRecordingUIStrings() {
        XCTAssertEqual(ActivationSettingsUIStrings.shortcutRecord, "录制热键")
        XCTAssertEqual(ActivationSettingsUIStrings.shortcutRecordingPrompt, "请按下组合键…")
        XCTAssertEqual(ActivationSettingsUIStrings.shortcutNeedsModifier, "需要至少一个修饰键")
        XCTAssertEqual(ActivationSettingsUIStrings.shortcutPresetLabel, "预设")
    }
}
