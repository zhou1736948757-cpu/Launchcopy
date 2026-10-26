import AppCatalogCore
import AppGridUI
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

/// Real settings controls and unshown native windows. No catalog scan, icon work,
/// persistence, language owner replacement or test-only relabel implementation.
/// Execution is deferred until Main freezes the integrated localization sources.
@MainActor
final class LanguageSettingsConsumersTests: XCTestCase {
    private let frame = NSRect(x: 0, y: 0, width: 500, height: 560)
    private let languages: [InterfaceLanguage] = [.simplifiedChinese, .english, .japanese]

    private func mount(_ view: NSView) -> NSWindow {
        let window = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        return window
    }

    private func record(_ suffix: String, name: String) -> AppRecord {
        let bundle = "fixture.language.settings.\(suffix)"
        let id = CatalogFixture.appID(bundle)
        return CatalogFixture.record(id: id, displayName: name, bundleID: bundle,
            url: URL(fileURLWithPath: "/SyntheticApps/\(suffix).app"),
            icon: .from(appID: id), rootPriority: 0)
    }

    private func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }

    private func identities(_ view: NSView) -> [ObjectIdentifier] {
        descendants(view).map(ObjectIdentifier.init)
    }

    private func constraintIdentities(_ view: NSView) -> [ObjectIdentifier] {
        descendants(view).flatMap(\.constraints).map(ObjectIdentifier.init)
    }

    private func assertButtons(_ pairs: [(NSButton, SettingsTextKey)], strings: LocalizedStrings,
                               file: StaticString = #filePath, line: UInt = #line) {
        for (button, key) in pairs {
            XCTAssertEqual(button.title, strings.settingsText(key), file: file, line: line)
            XCTAssertEqual(button.accessibilityLabel(), button.title, file: file, line: line)
        }
    }

    private func assertLabels(_ pairs: [(NSTextField, SettingsTextKey)], strings: LocalizedStrings,
                              file: StaticString = #filePath, line: UInt = #line) {
        for (label, key) in pairs {
            XCTAssertEqual(label.stringValue, strings.settingsText(key), file: file, line: line)
            XCTAssertEqual(label.accessibilityLabel(), label.stringValue, file: file, line: line)
        }
    }

    private func assertStatus(_ label: NSTextField, key: SettingsTextKey, strings: LocalizedStrings,
                              color: NSColor, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(label.isHidden, file: file, line: line)
        XCTAssertEqual(label.stringValue, strings.settingsText(key), file: file, line: line)
        XCTAssertEqual(label.accessibilityLabel(), label.stringValue, file: file, line: line)
        XCTAssertEqual(label.textColor, color, file: file, line: line)
    }

    private func assertLiveStatus(_ label: NSTextField, keys: [LiveAppearanceTextKey],
                                  strings: LocalizedStrings, color: NSColor,
                                  validation: SettingsTextKey? = nil,
                                  presentationUnavailable: Bool = false,
                                  file: StaticString = #filePath, line: UInt = #line) {
        var messages = validation.map { [strings.settingsText($0)] } ?? []
        messages += keys.map { strings.liveAppearanceText($0) }
        if presentationUnavailable { messages.append(strings.settingsText(.appearancePresentationUnavailable)) }
        XCTAssertFalse(label.isHidden, file: file, line: line)
        XCTAssertEqual(label.stringValue, messages.joined(separator: "\n"), file: file, line: line)
        XCTAssertEqual(label.accessibilityLabel(), label.stringValue, file: file, line: line)
        XCTAssertEqual(label.accessibilityValue(), label.stringValue, file: file, line: line)
        XCTAssertEqual(label.textColor, color, file: file, line: line)
    }

    private func settle(_ predicate: () -> Bool, file: StaticString = #filePath,
                        line: UInt = #line) async {
        for _ in 0..<1000 {
            if predicate() { return }
            await Task.yield()
        }
        XCTFail("Bounded native callback did not complete", file: file, line: line)
    }

    func testInjectedInitialLanguageConfiguresTheRealViewsBeforePresentation() {
        for language in languages {
            let strings = LocalizedStrings(language: language)
            let appearance = AppearanceSettingsView(frame: frame, strings: strings)
            let management = AppManagementSettingsView(frame: frame, strings: strings)
            let sources = AppSourcesSettingsView(frame: frame, strings: strings)
            XCTAssertEqual(appearance.strings.language, language)
            XCTAssertEqual(management.strings.language, language)
            XCTAssertEqual(sources.strings.language, language)
            XCTAssertEqual(appearance.applyButton.title, strings.liveAppearanceText(.retry))
            XCTAssertEqual(appearance.applyButton.accessibilityLabel(), appearance.applyButton.title)
            XCTAssertTrue(appearance.applyButton.isHidden)
            assertButtons([(management.saveAliasButton, .managementSaveAlias),
                           (sources.addButton, .sourcesAdd)], strings: strings)
            XCTAssertEqual(management.appPopup.item(at: 0)?.title, strings.settingsText(.managementSelectApp))
            XCTAssertEqual(sources.rootsPopup.item(at: 0)?.title, strings.settingsText(.sourcesSelectRoot))
        }
    }

    func testAppearanceMountedTextAndAXPreserveDraftControlsAndCallbacksInAllLanguages() {
        let view = AppearanceSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        let draft = AppearancePreferences(showsAppLabels: false, wallpaperBlurRadius: 37,
                                          preferredIconSide: 59, appLabelFontSize: 14)
        view.reload(preferences: draft)
        var saves = 0, providerCalls = 0
        view.onApply = { _ in saves += 1; return .saved }
        view.onChange = { [weak view] _ in
            saves += 1
            view?.updateLiveStatus(.saved, presentation: .queued)
            return true
        }
        view.presentationStateProvider = { providerCalls += 1; return .queued }
        let controls = identities(view), constraints = constraintIdentities(view)
        let target = view.applyButton.target
        let action = view.applyButton.action
        let firstResponder = window.firstResponder
        var titles: [String] = []
        for language in languages {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            XCTAssertEqual(view.strings.language, language)
            assertButtons([(view.labelsCheckbox, .appearanceShowLabels)], strings: strings)
            XCTAssertEqual(view.applyButton.title, strings.liveAppearanceText(.retry))
            XCTAssertEqual(view.applyButton.accessibilityLabel(), view.applyButton.title)
            XCTAssertTrue(view.applyButton.isHidden)
            XCTAssertEqual(view.defaultsButton.title, strings.liveAppearanceText(.defaults))
            XCTAssertEqual(view.defaultsButton.accessibilityLabel(), view.defaultsButton.title)
            assertLabels([(view.blurCaption, .appearanceBlurCaption),
                          (view.iconCaption, .appearanceIconCaption),
                          (view.fontCaption, .appearanceFontCaption)], strings: strings)
            XCTAssertEqual(view.helpLabel.stringValue, strings.liveAppearanceText(.help))
            XCTAssertEqual(view.helpLabel.accessibilityLabel(), view.helpLabel.stringValue)
            XCTAssertEqual(view.blurSlider.accessibilityLabel(), strings.settingsText(.appearanceBlurAccessibility))
            XCTAssertEqual(view.iconSlider.accessibilityLabel(), strings.settingsText(.appearanceIconAccessibility))
            XCTAssertEqual(view.fontSlider.accessibilityLabel(), strings.settingsText(.appearanceFontAccessibility))
            XCTAssertEqual(view.draft, draft)
            XCTAssertEqual(view.labelsCheckbox.state, .off)
            XCTAssertEqual([view.blurSlider.integerValue, view.iconSlider.integerValue, view.fontSlider.integerValue], [37, 59, 14])
            XCTAssertEqual([view.blurValue.stringValue, view.iconValue.stringValue, view.fontValue.stringValue], ["37", "59", "14"])
            XCTAssertEqual(identities(view), controls)
            XCTAssertEqual(constraintIdentities(view), constraints)
            XCTAssertTrue(window.firstResponder === firstResponder)
            XCTAssertTrue(view.applyButton.target === target)
            XCTAssertEqual(view.applyButton.action, action)
            XCTAssertEqual(view.applyButton.identifier?.rawValue, "appearance.apply")
            XCTAssertTrue(view.statusLabel.isHidden)
            XCTAssertEqual(saves, 0)
            XCTAssertEqual(providerCalls, 0, "Relabel must rerender retained feedback, not query an owner")
            titles.append(view.applyButton.title)
        }
        XCTAssertEqual(titles.first, LocalizedStrings(language: .simplifiedChinese).liveAppearanceText(.retry))
        XCTAssertEqual(Set(titles).count, 3, "Missing translations must not look like three-language coverage")
        view.blurSlider.integerValue = 38
        view.controlChanged(nil)
        XCTAssertEqual(saves, 1, "The original live callback remains installed")
        XCTAssertEqual(view.draft, .init(showsAppLabels: false, wallpaperBlurRadius: 38,
                                        preferredIconSide: 59, appLabelFontSize: 14))
        view.reload(preferences: draft, loadResult: .corrupt)
        view.applyButton.performClick(nil)
        XCTAssertEqual(saves, 2, "The original explicit recovery callback remains installed")
        XCTAssertEqual(view.draft, draft)
    }

    func testAppearanceRetainsQueuedReceiptUntilStatusRefreshAndDefaultsAutosubmit() {
        let view = AppearanceSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        var state = AppearancePresentationState.queued
        var providerCalls = 0, saves = 0
        view.onApply = { _ in saves += 1; return .saved }
        view.onChange = { [weak view] _ in
            saves += 1
            view?.updateLiveStatus(.saved, presentation: state)
            return true
        }
        view.presentationStateProvider = { providerCalls += 1; return state }
        view.blurSlider.integerValue = 27
        view.controlChanged(nil)
        assertLiveStatus(view.statusLabel, keys: [.saved, .queued], strings: view.strings,
                         color: .secondaryLabelColor)
        let reads = providerCalls
        state = .applied
        for language in languages {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            assertLiveStatus(view.statusLabel, keys: [.saved, .queued], strings: strings, color: .secondaryLabelColor)
            XCTAssertEqual(providerCalls, reads)
            XCTAssertEqual(saves, 1)
        }
        view.refreshPresentationStatus()
        assertLiveStatus(view.statusLabel, keys: [.saved], strings: view.strings, color: .systemGreen)
        state = .unavailable
        view.refreshPresentationStatus()
        for language in languages {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            assertLiveStatus(view.statusLabel, keys: [.saved], strings: strings, color: .secondaryLabelColor,
                             presentationUnavailable: true)
        }
        view.defaultsButton.performClick(nil)
        for language in languages {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            view.refreshPresentationStatus()
            assertLiveStatus(view.statusLabel, keys: [.saved], strings: strings, color: .secondaryLabelColor,
                             presentationUnavailable: true)
            XCTAssertEqual(view.draft, .default)
            XCTAssertEqual(saves, 2, "Defaults automatically submit exactly once; relabel does not submit")
        }
    }

    func testAppearanceLoadsAndSaveFailuresKeepTheirMeaningAcrossRelabel() {
        let view = AppearanceSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        let draft = AppearancePreferences(wallpaperBlurRadius: 26)
        for (load, key, enabled) in [
            (AppearancePreferencesLoadResult.corrupt, LiveAppearanceTextKey.recoveryRequired, true),
            (.futureVersion(9), .protected, false)
        ] {
            view.reload(preferences: draft, loadResult: load)
            for language in languages {
                let strings = LocalizedStrings(language: language)
                view.relabel(strings: strings)
                assertLiveStatus(view.statusLabel, keys: [key], strings: strings, color: .systemRed)
                XCTAssertEqual(view.applyButton.isHidden, !enabled)
                XCTAssertEqual(view.draft, draft)
                for control in [view.labelsCheckbox, view.blurSlider, view.iconSlider, view.fontSlider,
                                view.applyButton, view.defaultsButton] as [NSControl] {
                    XCTAssertEqual(control.isEnabled, enabled)
                }
            }
        }
        var saves = 0
        for (result, key, validation) in [
            (AppearancePreferencesSaveResult.encodingFailed, LiveAppearanceTextKey.saveFailed, Optional<SettingsTextKey>.none),
            (.futureVersion(9), .protected, nil), (.invalidPreferences, .saveFailed, .appearanceInvalidPreferences)
        ] {
            view.reload(preferences: .default)
            // A real rejected live edit exposes Retry; no fabricated failed state.
            view.onChange = { _ in false }
            view.blurSlider.integerValue = draft.wallpaperBlurRadius
            view.controlChanged(nil)
            XCTAssertFalse(view.applyButton.isHidden)
            view.onApply = { _ in saves += 1; return result }
            let before = saves
            view.applyButton.performClick(nil)
            let expectedSaves = before + 1
            for language in languages {
                let strings = LocalizedStrings(language: language)
                view.relabel(strings: strings)
                assertLiveStatus(view.statusLabel, keys: [key], strings: strings, color: .systemRed,
                                 validation: validation)
                XCTAssertEqual(view.draft, draft)
                XCTAssertEqual(saves, expectedSaves)
            }
        }
        view.onApply = nil
        view.onChange = nil
        view.applyClicked(nil)
        for language in languages {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            assertLiveStatus(view.statusLabel, keys: [.unavailable], strings: strings, color: .systemRed)
        }
        view.reload(preferences: draft, loadResult: .corrupt)
        view.onApply = { _ in saves += 1; return .encodingFailed }
        let beforeRecovery = saves
        view.applyButton.performClick(nil)
        for language in languages {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            assertLiveStatus(view.statusLabel, keys: [.recoveryFailed], strings: strings, color: .systemRed)
            XCTAssertEqual(view.applyButton.title, strings.liveAppearanceText(.recover))
            XCTAssertFalse(view.applyButton.isHidden)
            XCTAssertTrue(view.applyButton.isEnabled)
            XCTAssertEqual(view.draft, draft)
            XCTAssertEqual(saves, beforeRecovery + 1)
        }
    }

    func testInvalidNativeAppearanceDraftIsNotResetOrSavedByRelabel() {
        let view = AppearanceSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        var saves = 0
        view.onApply = { _ in saves += 1; return .saved }
        // Inject an out-of-contract value through the actual control. Normal native
        // slider clamping must not prevent exercising the consumer's validation.
        view.blurSlider.maxValue = 100
        view.blurSlider.doubleValue = 61
        view.controlChanged(nil)
        for language in languages {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            assertStatus(view.statusLabel, key: .appearanceInvalidDraft, strings: strings, color: .systemRed)
            XCTAssertEqual(view.draft, .default)
            XCTAssertEqual(view.blurSlider.doubleValue, 61)
            XCTAssertEqual(view.blurValue.stringValue, "18")
            view.applyClicked(nil)
            XCTAssertEqual(saves, 0)
        }
    }

    func testManagementCanonicalSelectionKeepsOriginalAndAliasSearchMatching() throws {
        let app = record("search", name: "Original App 日本語")
        let preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Workspace Alias", for: app))
        let view = AppManagementSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        view.reload(records: [app], preferences: preferences)
        view.appPopup.selectItem(at: 1)
        view.selectionChanged(nil)
        let originalQuery = AppSearchQuery(raw: "Original", locale: Locale(identifier: "en_US_POSIX"))
        let aliasQuery = AppSearchQuery(raw: "Workspace", locale: Locale(identifier: "en_US_POSIX"))
        for language in languages {
            view.relabel(strings: LocalizedStrings(language: language))
            let selected = try XCTUnwrap(view.selectedRecord)
            XCTAssertEqual(selected, app)
            XCTAssertEqual(selected.displayName, "Original App 日本語")
            XCTAssertEqual(selected.canonicalURL, app.canonicalURL)
            XCTAssertEqual(view.aliasField.stringValue, "Workspace Alias")
            XCTAssertTrue(preferences.matches(selected, query: originalQuery))
            XCTAssertTrue(preferences.matches(selected, query: aliasQuery))
            XCTAssertEqual(originalQuery.raw, "Original")
            XCTAssertEqual(aliasQuery.raw, "Workspace")
        }
    }

    func testManagementMountedTextAXMenuIdentityAndUnsavedAliasRemainVerbatim() throws {
        let app = record("first", name: "原名 Original 😀")
        let other = record("second", name: "同名 Original 😀")
        let alias = "Alias 別名 % {name}"
        let preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias(alias, for: app))
            .settingHidden(true, for: app)
        let view = AppManagementSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        view.reload(records: [app, other], preferences: preferences)
        view.appPopup.selectItem(at: 1)
        view.selectionChanged(nil)
        view.aliasField.stringValue = "  Unsaved 別名 😀  "
        var aliases: [String?] = [], hiddenCalls = 0, restores = 0
        view.onSetAlias = { selected, value in XCTAssertEqual(selected, app); aliases.append(value); return .failed }
        view.onSetHidden = { _, _ in hiddenCalls += 1; return .failed }
        view.onRestoreAll = { restores += 1; return .failed }
        let items = view.appPopup.itemArray
        let controls = identities(view), constraints = constraintIdentities(view)
        var titles: [String] = []
        for language in languages {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            assertButtons([(view.hiddenCheckbox, .managementHideSelected), (view.saveAliasButton, .managementSaveAlias),
                           (view.clearAliasButton, .managementClearAlias), (view.restoreAllButton, .managementRestoreAll)], strings: strings)
            assertLabels([(view.helpLabel, .managementHelp)], strings: strings)
            XCTAssertEqual(view.aliasField.placeholderString, strings.settingsText(.managementAliasPlaceholder))
            XCTAssertEqual(view.aliasField.accessibilityLabel(), strings.settingsText(.managementAliasAccessibility))
            XCTAssertEqual(view.appPopup.accessibilityLabel(), strings.settingsText(.managementAppAccessibility))
            XCTAssertEqual(view.appPopup.item(at: 0)?.title, strings.settingsText(.managementSelectApp))
            XCTAssertEqual(view.appPopup.item(at: 1)?.title, "\(alias) — \(app.displayName)" + strings.settingsText(.managementHiddenSuffix))
            XCTAssertEqual(view.appPopup.item(at: 2)?.title, other.displayName)
            for (before, after) in zip(items, view.appPopup.itemArray) {
                XCTAssertTrue(before === after)
                XCTAssertEqual(after.accessibilityLabel(), after.title)
            }
            XCTAssertEqual(view.appPopup.itemArray.compactMap { ($0.representedObject as? AppRecord)?.id }, [app.id, other.id])
            XCTAssertEqual(view.selectedRecord, app)
            XCTAssertEqual(view.appPopup.indexOfSelectedItem, 1)
            XCTAssertEqual(view.aliasField.stringValue, "  Unsaved 別名 😀  ")
            XCTAssertEqual(view.hiddenCheckbox.state, .on)
            XCTAssertEqual(view.aliasField.identifier?.rawValue, "management.alias")
            XCTAssertEqual(identities(view), controls)
            XCTAssertEqual(constraintIdentities(view), constraints)
            let count = try XCTUnwrap(descendants(view).compactMap { $0 as? NSTextField }.first {
                $0.stringValue == strings.hiddenReferenceCount(1)
            })
            XCTAssertEqual(count.accessibilityLabel(), count.stringValue)
            XCTAssertTrue(view.statusLabel.isHidden)
            XCTAssertEqual(aliases.count + hiddenCalls + restores, 0)
            titles.append(view.saveAliasButton.title)
        }
        XCTAssertEqual(Set(titles).count, 3)
        view.saveAliasButton.performClick(nil)
        XCTAssertEqual(aliases, ["  Unsaved 別名 😀  "])
        XCTAssertEqual(hiddenCalls + restores, 0)
    }

    func testManagementRealFieldEditorSelectionAndMarkedTextSurviveRelabel() throws {
        let app = record("ime", name: "Original 日本語")
        let view = AppManagementSettingsView(frame: frame)
        let window = mount(view)
        defer { window.makeFirstResponder(nil); window.close() }
        view.reload(records: [app], preferences: .default)
        view.appPopup.selectItem(at: 1)
        view.selectionChanged(nil)
        view.aliasField.stringValue = "Draft alias"
        XCTAssertTrue(window.makeFirstResponder(view.aliasField))
        let editor = try XCTUnwrap(view.aliasField.currentEditor() as? NSTextView)
        editor.setSelectedRange(NSRange(location: 2, length: 3))
        for language in languages {
            let before = editor.selectedRange()
            view.relabel(strings: LocalizedStrings(language: language))
            XCTAssertTrue(window.firstResponder === editor)
            XCTAssertTrue(view.aliasField.currentEditor() === editor)
            XCTAssertEqual(editor.selectedRange(), before)
            XCTAssertEqual(editor.string, "Draft alias")
        }
        editor.setMarkedText("入力中", selectedRange: NSRange(location: 1, length: 1),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(editor.hasMarkedText())
        let text = editor.string, fieldValue = view.aliasField.stringValue
        let marked = editor.markedRange(), selection = editor.selectedRange()
        var callbacks = 0
        view.onSetAlias = { _, _ in callbacks += 1; return .saved }
        for language in languages {
            view.relabel(strings: LocalizedStrings(language: language))
            XCTAssertTrue(window.firstResponder === editor)
            XCTAssertTrue(view.aliasField.currentEditor() === editor)
            XCTAssertTrue(editor.hasMarkedText())
            XCTAssertEqual(editor.markedRange(), marked)
            XCTAssertEqual(editor.selectedRange(), selection)
            XCTAssertEqual(editor.string, text)
            XCTAssertEqual(view.aliasField.stringValue, fieldValue)
            XCTAssertEqual(view.selectedRecord, app)
            XCTAssertEqual(callbacks, 0)
        }
    }

    func testManagementReadOnlyCorruptAndSaveFeedbackRelabelWithoutMutations() {
        let app = record("feedback", name: "Original")
        let view = AppManagementSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        var calls = 0
        view.onSetAlias = { _, _ in calls += 1; return .saved }
        view.onSetHidden = { _, _ in calls += 1; return .saved }
        view.onRestoreAll = { calls += 1; return .saved }
        for (load, key, enabled) in [
            (AppManagementLoadResult.futureVersion(9), SettingsTextKey.managementLoadFuture, false),
            (.corrupt, .managementLoadCorrupt, true)
        ] {
            view.reload(records: [app], preferences: .default.settingHidden(true, for: app), loadResult: load)
            view.appPopup.selectItem(at: 1)
            view.selectionChanged(nil)
            view.aliasField.stringValue = "Draft"
            for language in languages {
                let strings = LocalizedStrings(language: language)
                view.relabel(strings: strings)
                assertStatus(view.statusLabel, key: key, strings: strings, color: .systemRed)
                for control in [view.hiddenCheckbox, view.aliasField, view.saveAliasButton,
                                view.clearAliasButton, view.restoreAllButton] as [NSControl] {
                    XCTAssertEqual(control.isEnabled, enabled)
                }
                XCTAssertEqual(view.aliasField.stringValue, "Draft")
                XCTAssertEqual(view.selectedRecord, app)
                if !enabled { view.saveAlias(nil); view.clearAlias(nil); view.hiddenChanged(nil); view.restoreAll(nil) }
                XCTAssertEqual(calls, 0)
            }
        }
        for (result, key) in [(AppManagementSaveResult.saved, SettingsTextKey.managementSaved),
                              (.failed, .managementSaveFailed), (.futureVersion(9), .managementSaveFuture),
                              (.invalidPreferences, .managementInvalidAlias)] {
            view.onSetAlias = { _, _ in calls += 1; return result }
            view.saveAliasButton.performClick(nil)
            let before = calls
            for language in languages {
                let strings = LocalizedStrings(language: language)
                view.relabel(strings: strings)
                assertStatus(view.statusLabel, key: key, strings: strings,
                             color: result == .saved ? .systemGreen : .systemRed)
                XCTAssertEqual(view.aliasField.stringValue, "Draft")
                XCTAssertEqual(calls, before)
            }
        }
    }

    func testHiddenReferenceCountsIncludeUninstalledReferencesInRealView() throws {
        let view = AppManagementSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        for count in [0, 1, 3] {
            let preferences = AppManagementPreferences(hiddenKeys: Set((0..<count).map { "bundle:fixture.absent.\($0)" }))
            view.reload(records: [], preferences: preferences)
            for language in languages {
                let strings = LocalizedStrings(language: language)
                view.relabel(strings: strings)
                let label = try XCTUnwrap(descendants(view).compactMap { $0 as? NSTextField }.first {
                    $0.stringValue == strings.hiddenReferenceCount(count)
                })
                XCTAssertEqual(label.accessibilityLabel(), label.stringValue)
                XCTAssertNil(view.selectedRecord)
                XCTAssertEqual(view.restoreAllButton.isEnabled, count > 0)
                if language == .simplifiedChinese {
                    XCTAssertEqual(label.stringValue, "\(count) 个隐藏引用（含暂未安装的应用）")
                }
            }
        }
    }

    func testSourcesMountedTextAXDraftPathsSelectionAndWatchStateArePreserved() {
        let view = AppSourcesSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        let paths = ["/Synthetic/Apps 日本語 %", "/Synthetic/Other 😀"]
        let fixed = [URL(fileURLWithPath: "/Synthetic/Fixed 原名")]
        let draft = AppSourcesPreferences(customRootPaths: paths, automaticRefreshEnabled: false)
        var admissions = 0, saves = 0, refreshes = 0, ownershipChanges = 0
        view.onAdmit = { _ in admissions += 1; return .alreadyCovered }
        view.onApply = { _ in saves += 1; return .saved }
        view.onRefresh = { refreshes += 1 }
        view.onPresentationOwnershipChange = { ownershipChanges += 1 }
        view.reload(preferences: draft, fixedRoots: fixed, watchStatus: .degraded)
        view.rootsPopup.selectItem(at: 2)
        view.selectionChanged(nil)
        let items = view.rootsPopup.itemArray
        let controls = identities(view), constraints = constraintIdentities(view)
        var titles: [String] = []
        for language in languages {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            assertButtons([(view.automaticCheckbox, .sourcesAutomatic), (view.addButton, .sourcesAdd),
                           (view.removeButton, .sourcesRemove), (view.applyButton, .sourcesApply),
                           (view.refreshButton, .sourcesRefresh)], strings: strings)
            assertLabels([(view.fixedCaption, .sourcesFixedCaption), (view.extraCaption, .sourcesExtraCaption),
                          (view.helpLabel, .sourcesHelp), (view.watchLabel, .sourcesWatchDegraded)], strings: strings)
            XCTAssertEqual(view.rootsPopup.accessibilityLabel(), strings.settingsText(.sourcesRootAccessibility))
            XCTAssertEqual(view.rootsPopup.item(at: 0)?.title, strings.settingsText(.sourcesSelectRoot))
            XCTAssertEqual(view.rootsPopup.itemArray.dropFirst().map(\.title), paths)
            XCTAssertEqual(view.rootsPopup.itemArray.compactMap { $0.representedObject as? String }, paths)
            for (before, after) in zip(items, view.rootsPopup.itemArray) {
                XCTAssertTrue(before === after)
                XCTAssertEqual(after.accessibilityLabel(), after.title)
            }
            XCTAssertEqual(view.rootsPopup.selectedItem?.representedObject as? String, paths[1])
            XCTAssertEqual(view.draft, draft)
            XCTAssertEqual(view.automaticCheckbox.state, .off)
            XCTAssertTrue(view.removeButton.isEnabled)
            XCTAssertTrue(descendants(view).compactMap { $0 as? NSTextField }.contains { $0.stringValue == fixed[0].path })
            XCTAssertEqual(identities(view), controls)
            XCTAssertEqual(constraintIdentities(view), constraints)
            XCTAssertEqual(view.applyButton.identifier?.rawValue, "sources.apply")
            XCTAssertFalse(view.hasPresentationOwnership)
            XCTAssertEqual(admissions + saves + refreshes + ownershipChanges, 0)
            titles.append(view.applyButton.title)
        }
        XCTAssertEqual(Set(titles).count, 3)
        view.refreshButton.performClick(nil)
        XCTAssertEqual(refreshes, 1)
        XCTAssertEqual(admissions + saves + ownershipChanges, 0)
        for (watch, key) in [(AppSourceWatchStatus.active, SettingsTextKey.sourcesWatchActive),
                             (.disabled, .sourcesWatchDisabled), (.unavailable, .sourcesWatchUnavailable),
                             (.degraded, .sourcesWatchDegraded)] {
            view.updateWatchStatus(watch)
            for language in languages {
                let strings = LocalizedStrings(language: language)
                view.relabel(strings: strings)
                assertLabels([(view.watchLabel, key)], strings: strings)
                XCTAssertEqual(view.draft, draft)
                XCTAssertEqual(refreshes, 1)
            }
        }
    }

    func testSourcesLoadAndRemovedDraftFeedbackStayLocalizedWithoutReload() {
        let view = AppSourcesSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        let draft = AppSourcesPreferences(customRootPaths: ["/Synthetic/A", "/Synthetic/B"])
        var callbacks = 0
        view.onApply = { _ in callbacks += 1; return .saved }
        view.onAdmit = { _ in callbacks += 1; return .alreadyCovered }
        view.onRefresh = { callbacks += 1 }
        for (load, key, enabled) in [(AppSourcesLoadResult.futureVersion(9), SettingsTextKey.sourcesLoadFuture, false),
                                     (.corrupt, .sourcesLoadCorrupt, true)] {
            view.reload(preferences: draft, fixedRoots: [], loadResult: load, watchStatus: .disabled)
            view.rootsPopup.selectItem(at: 1)
            view.selectionChanged(nil)
            for language in languages {
                let strings = LocalizedStrings(language: language)
                view.relabel(strings: strings)
                assertStatus(view.statusLabel, key: key, strings: strings, color: .systemRed)
                for control in [view.rootsPopup, view.automaticCheckbox, view.addButton,
                                view.removeButton, view.applyButton] as [NSControl] {
                    XCTAssertEqual(control.isEnabled, enabled)
                }
                XCTAssertTrue(view.refreshButton.isEnabled)
                XCTAssertEqual(view.draft, draft)
                XCTAssertEqual(view.rootsPopup.selectedItem?.representedObject as? String, "/Synthetic/A")
                XCTAssertEqual(callbacks, 0)
            }
        }
        view.removeButton.performClick(nil)
        let removed = view.draft
        for language in languages {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            assertStatus(view.statusLabel, key: .sourcesRemovedDraft, strings: strings, color: .systemGreen)
            XCTAssertEqual(view.draft, removed)
            XCTAssertEqual(callbacks, 0)
        }
        view.automaticCheckbox.performClick(nil)
        for language in languages {
            view.relabel(strings: LocalizedStrings(language: language))
            XCTAssertTrue(view.statusLabel.isHidden, "Relabel must not revive dismissed draft feedback")
        }
    }

    func testDelayedSourceAdmissionKeepsOperationAndUsesCurrentDisplayedLanguageExactlyOnce() async {
        let view = AppSourcesSettingsView(frame: frame)
        let window = mount(view)
        defer { view.cancelPendingOperations(); window.close() }
        var gate: CheckedContinuation<AppSourceRootAdmissionResult, Never>?
        var admissions = 0, saves = 0, refreshes = 0
        var ownership: [Bool] = []
        view.onAdmit = { _ in
            admissions += 1
            return await withCheckedContinuation { gate = $0 }
        }
        view.onApply = { _ in saves += 1; return .saved }
        view.onRefresh = { refreshes += 1 }
        view.onPresentationOwnershipChange = { [weak view] in ownership.append(view?.hasPresentationOwnership ?? false) }
        view.addDraftRoot(URL(fileURLWithPath: "/Synthetic/Selected"))
        await settle { gate != nil }
        XCTAssertEqual(ownership, [true])
        for language in languages {
            view.relabel(strings: LocalizedStrings(language: language))
            XCTAssertTrue(view.hasPresentationOwnership)
            XCTAssertFalse(view.addButton.isEnabled)
            XCTAssertEqual(view.draft, .default)
            XCTAssertEqual(admissions, 1)
            XCTAssertEqual(saves + refreshes, 0)
            XCTAssertEqual(ownership, [true], "Relabel must not release/reacquire the actual operation")
        }
        gate?.resume(returning: .accepted(URL(fileURLWithPath: "/Synthetic/Canonical 日本語")))
        await settle { !view.hasPresentationOwnership }
        XCTAssertEqual(ownership, [true, false])
        XCTAssertEqual(view.draft.customRootPaths, ["/Synthetic/Canonical 日本語"])
        assertStatus(view.statusLabel, key: .sourcesAddedDraft, strings: view.strings, color: .systemGreen)
        XCTAssertEqual(view.strings.language, .japanese)
        for language in languages {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            assertStatus(view.statusLabel, key: .sourcesAddedDraft, strings: strings, color: .systemGreen)
            XCTAssertEqual(admissions, 1)
            XCTAssertEqual(saves + refreshes, 0)
            XCTAssertEqual(ownership, [true, false])
        }
    }

    func testDelayedSourcesApplyAllOutcomesRetainDraftSelectionAndCallbackCounts() async {
        for (result, key) in [(AppSourcesApplyResult.saved, SettingsTextKey.sourcesSaved),
                              (.futureVersion, .sourcesSaveFuture), (.invalidRoot, .sourcesInvalidRoot),
                              (.failed, .sourcesSaveFailed), (.superseded, .sourcesSuperseded)] {
            let view = AppSourcesSettingsView(frame: frame)
            let window = mount(view)
            defer { view.cancelPendingOperations(); window.close() }
            let draft = AppSourcesPreferences(customRootPaths: ["/Synthetic/One", "/Synthetic/Two"], automaticRefreshEnabled: false)
            view.reload(preferences: draft, fixedRoots: [], watchStatus: .active)
            view.rootsPopup.selectItem(at: 2)
            view.selectionChanged(nil)
            let items = view.rootsPopup.itemArray
            var gate: CheckedContinuation<AppSourcesApplyResult, Never>?
            var submitted: [AppSourcesPreferences] = [], admissions = 0, refreshes = 0
            var ownership: [Bool] = []
            view.onApply = { value in
                submitted.append(value)
                return await withCheckedContinuation { gate = $0 }
            }
            view.onAdmit = { _ in admissions += 1; return .alreadyCovered }
            view.onRefresh = { refreshes += 1 }
            view.onPresentationOwnershipChange = { [weak view] in ownership.append(view?.hasPresentationOwnership ?? false) }
            view.applyButton.performClick(nil)
            await settle { gate != nil }
            for language in languages {
                view.relabel(strings: LocalizedStrings(language: language))
                XCTAssertEqual(view.draft, draft)
                XCTAssertEqual(view.rootsPopup.selectedItem?.representedObject as? String, "/Synthetic/Two")
                XCTAssertEqual(view.automaticCheckbox.state, .off)
                XCTAssertFalse(view.applyButton.isEnabled)
                XCTAssertTrue(view.hasPresentationOwnership)
                XCTAssertEqual(submitted, [draft])
                XCTAssertEqual(admissions + refreshes, 0)
                XCTAssertEqual(ownership, [true])
                for (before, after) in zip(items, view.rootsPopup.itemArray) { XCTAssertTrue(before === after) }
            }
            gate?.resume(returning: result)
            await settle { !view.hasPresentationOwnership }
            XCTAssertEqual(ownership, [true, false])
            for language in languages {
                let strings = LocalizedStrings(language: language)
                view.relabel(strings: strings)
                assertStatus(view.statusLabel, key: key, strings: strings, color: result == .saved ? .systemGreen : .systemRed)
                XCTAssertEqual(view.draft, draft)
                XCTAssertEqual(view.rootsPopup.indexOfSelectedItem, 2)
                XCTAssertEqual(submitted, [draft])
                XCTAssertEqual(admissions + refreshes, 0)
                XCTAssertEqual(ownership, [true, false])
            }
        }
    }

    func testSourceAdmissionRejectedAndAlreadyCoveredFeedbackRelabelWithoutNewWork() async {
        let view = AppSourcesSettingsView(frame: frame)
        let window = mount(view)
        defer { view.cancelPendingOperations(); window.close() }
        var calls = 0
        for (result, key) in [(AppSourceRootAdmissionResult.alreadyCovered, SettingsTextKey.sourcesAlreadyCovered),
                              (.rejected(.tooBroad), .sourcesRejected)] {
            view.onAdmit = { _ in calls += 1; return result }
            view.addDraftRoot(URL(fileURLWithPath: "/Synthetic/Selected"))
            await settle { !view.hasPresentationOwnership }
            let before = calls
            for language in languages {
                let strings = LocalizedStrings(language: language)
                view.relabel(strings: strings)
                assertStatus(view.statusLabel, key: key, strings: strings,
                             color: key == .sourcesRejected ? .systemRed : .systemGreen)
                XCTAssertEqual(view.draft, .default)
                XCTAssertEqual(calls, before)
            }
        }
    }

    func testActualSourcePanelBuilderUsesDisplayedPromptWithoutPresentingOrStartingWork() {
        let view = AppSourcesSettingsView(frame: frame)
        let window = mount(view)
        defer { window.close() }
        var callbacks = 0
        view.onAdmit = { _ in callbacks += 1; return .alreadyCovered }
        view.onApply = { _ in callbacks += 1; return .saved }
        view.onRefresh = { callbacks += 1 }
        view.onPresentationOwnershipChange = { callbacks += 1 }
        for language in languages {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            let panel = view.makeOpenPanel()
            XCTAssertEqual(panel.prompt, strings.settingsText(.sourcesPanelPrompt))
            XCTAssertTrue(panel.canChooseDirectories)
            XCTAssertFalse(panel.canChooseFiles)
            XCTAssertFalse(panel.allowsMultipleSelection)
            XCTAssertFalse(panel.resolvesAliases)
            XCTAssertFalse(panel.treatsFilePackagesAsDirectories)
            XCTAssertNil(window.attachedSheet)
            XCTAssertFalse(view.hasPresentationOwnership)
            XCTAssertEqual(view.draft, .default)
            XCTAssertEqual(callbacks, 0)
        }
    }

    func testSourceExplicitCancellationStillInvalidatesLateCallbackAndReleasesOwnershipOnce() async {
        let view = AppSourcesSettingsView(frame: frame)
        let window = mount(view)
        defer { view.cancelPendingOperations(); window.close() }
        var gate: CheckedContinuation<AppSourceRootAdmissionResult, Never>?
        var calls = 0, ownership: [Bool] = []
        view.onAdmit = { _ in calls += 1; return await withCheckedContinuation { gate = $0 } }
        view.onPresentationOwnershipChange = { [weak view] in ownership.append(view?.hasPresentationOwnership ?? false) }
        view.addDraftRoot(URL(fileURLWithPath: "/Synthetic/Selected"))
        await settle { gate != nil }
        view.relabel(strings: LocalizedStrings(language: .english))
        XCTAssertEqual(ownership, [true])
        view.cancelPendingOperations()
        XCTAssertEqual(ownership, [true, false])
        gate?.resume(returning: .accepted(URL(fileURLWithPath: "/Synthetic/Late")))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(view.draft, .default)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(ownership, [true, false])
        XCTAssertTrue(view.statusLabel.isHidden)
        XCTAssertTrue(view.addButton.isEnabled)
    }
}
