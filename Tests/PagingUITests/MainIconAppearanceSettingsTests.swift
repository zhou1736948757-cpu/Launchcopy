import AppKit
import Foundation
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

/// In-memory view contracts for Main's serialized test run. No shown windows,
/// storage writes, synthetic native input, builds or timing assumptions.
@MainActor
final class MainIconAppearanceSettingsTests: XCTestCase {
    private let english = LocalizedStrings(language: .english)
    private let newKeys: [SettingsTextKey] = [
        .appearanceMainIconAccessibility, .appearanceMainIconCaption,
        .appearanceMainIconFitFormat, .appearanceIndependentIconsHelp
    ]

    private func makeView() -> AppearanceSettingsView {
        AppearanceSettingsView(frame: NSRect(x: 0, y: 0, width: 500, height: 560), strings: english)
    }

    private func send(_ slider: NSSlider, _ value: Int) {
        slider.integerValue = value
        XCTAssertTrue(slider.sendAction(slider.action, to: slider.target))
    }

    private func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }

    func testCleanDefaultsAndEveryMainSizePreserveFolderRangeAndAutomaticAdmission() {
        let view = makeView()
        XCTAssertEqual(view.mainIconSlider.minValue, 32)
        XCTAssertEqual(view.mainIconSlider.maxValue, 96)
        XCTAssertEqual(view.mainIconSlider.integerValue, 80)
        XCTAssertEqual(view.mainIconValue.stringValue, "80")
        XCTAssertEqual(view.draft.mainPreferredIconSide, 80)
        XCTAssertEqual(view.iconSlider.minValue, 32)
        XCTAssertEqual(view.iconSlider.maxValue, 96)
        XCTAssertEqual(view.iconSlider.integerValue, 80)
        XCTAssertTrue(view.mainIconSlider.isContinuous)
        XCTAssertEqual(view.mainIconSlider.identifier?.rawValue, "appearance.mainIconSize")
        XCTAssertEqual(view.mainIconSlider.accessibilityIdentifier(), "appearance.mainIconSize")
        XCTAssertEqual(view.mainIconSlider.accessibilityLabel(),
                       english.settingsText(.appearanceMainIconAccessibility))
        XCTAssertEqual(view.mainIconCaption.stringValue, english.settingsText(.appearanceMainIconCaption))
        XCTAssertEqual(view.iconCaption.stringValue, english.settingsText(.appearanceIconCaption))
        XCTAssertTrue(view.iconCaption.stringValue.contains("folder"))
        var writes: [AppearancePreferences] = []
        var flushes = 0
        view.onChange = { [weak view] candidate in
            XCTAssertEqual(view?.mainIconValue.stringValue, String(candidate.mainItemAppearance.preferredIconSide))
            writes.append(candidate)
            return true
        }
        view.onFlush = { flushes += 1 }
        for value in 32...96 {
            send(view.mainIconSlider, value)
            XCTAssertEqual(view.draft.mainPreferredIconSide, value)
            XCTAssertEqual(view.draft.preferredIconSide, 80)
            XCTAssertEqual(view.draft.itemAppearance.preferredIconSide, 80)
            XCTAssertEqual(view.draft.mainItemAppearance.preferredIconSide, value)
            XCTAssertEqual(view.liveSaveState, .pending, "Admission is not a persistence receipt")
        }
        XCTAssertEqual(writes.count, 65)
        XCTAssertEqual(flushes, 65)
        XCTAssertTrue(view.applyButton.isHidden)
    }

    func testOutOfRangeMainAndBaseDraftsCannotSubmitOrReplaceRetainedIntent() {
        for (isMain, value) in [(true, 31), (true, 97), (false, 97)] {
            let view = makeView()
            var writes = 0
            view.onChange = { _ in writes += 1; return true }
            let before = view.draft
            let slider = isMain ? view.mainIconSlider : view.iconSlider
            // Widen the native control only to exercise validation, not its clamp.
            slider.minValue = 0
            slider.maxValue = 100
            send(slider, value)
            XCTAssertEqual(view.draft, before)
            XCTAssertEqual(writes, 0)
            XCTAssertEqual(view.statusLabel.stringValue, english.settingsText(.appearanceInvalidDraft))
        }
    }

    func testOtherControlsPreserveExplicitOverrideAndMainChangesPreserveOtherDraftValues() {
        let view = makeView()
        var writes: [AppearancePreferences] = []
        view.onChange = { writes.append($0); return true }
        send(view.mainIconSlider, 96)
        send(view.blurSlider, 39)
        send(view.iconSlider, 64)
        send(view.fontSlider, 16)
        view.labelsCheckbox.performClick(nil)
        XCTAssertEqual(writes.count, 5)
        XCTAssertTrue(writes.allSatisfy { $0.mainPreferredIconSide == 96 })
        XCTAssertFalse(view.draft.showsAppLabels)
        XCTAssertEqual(view.draft.wallpaperBlurRadius, 39)
        XCTAssertEqual(view.draft.preferredIconSide, 64)
        XCTAssertEqual(view.draft.appLabelFontSize, 16)
        let beforeMainEdit = view.draft
        send(view.mainIconSlider, 80)
        var expected = beforeMainEdit
        expected.mainPreferredIconSide = 80
        XCTAssertEqual(view.draft, expected)
        view.updateLiveStatus(.failed, presentation: .queued)
        var retry: AppearancePreferences?
        view.onApply = { retry = $0; return .saved }
        view.applyClicked(nil)
        XCTAssertEqual(retry, expected)
        XCTAssertEqual(view.draft, expected)
    }

    func testLegacyNilInheritsBaseAcrossAllUnrelatedEditsUntilMainSliderIsMoved() {
        let view = makeView()
        var legacy = AppearancePreferences.default
        legacy.mainPreferredIconSide = nil
        legacy.preferredIconSide = 54
        view.reload(preferences: legacy, loadResult: .loaded(legacy))
        XCTAssertEqual(view.mainIconSlider.integerValue, 54)
        XCTAssertEqual(view.mainIconValue.stringValue, "54")
        var writes: [AppearancePreferences] = []
        view.onChange = { writes.append($0); return true }
        send(view.blurSlider, 24)
        send(view.fontSlider, 12)
        view.labelsCheckbox.performClick(nil)
        send(view.iconSlider, 64)
        XCTAssertTrue(writes.allSatisfy { $0.mainPreferredIconSide == nil })
        XCTAssertEqual(writes.count, 4)
        XCTAssertNil(view.draft.mainPreferredIconSide)
        XCTAssertEqual(view.mainIconSlider.integerValue, 64)
        XCTAssertEqual(view.mainIconValue.stringValue, "64")
        // An explicit main action at the inherited value still records ownership.
        send(view.mainIconSlider, 64)
        XCTAssertEqual(view.draft.mainPreferredIconSide, 64)
        send(view.iconSlider, 32)
        XCTAssertEqual(view.draft.mainPreferredIconSide, 64)
        XCTAssertEqual(view.mainIconSlider.integerValue, 64)
        XCTAssertEqual(view.iconSlider.integerValue, 32)
    }

    func testCandidateFitTracksControlsDraftSyncViewportProviderAndRelabelWithoutReceipts() {
        let view = makeView()
        XCTAssertTrue(view.mainIconFitLabel.isHidden)
        var observed: [AppearancePreferences] = []
        var fit: (app: CGFloat, folder: CGFloat) = (79.6, 71.2)
        view.mainIconFitProvider = { candidate in
            observed.append(candidate)
            return fit
        }
        XCTAssertEqual(observed.last, view.draft)
        XCTAssertFalse(view.mainIconFitLabel.isHidden)
        XCTAssertEqual(view.mainIconFitLabel.stringValue, english.mainIconFitText(app: 79.6, folder: 71.2))
        XCTAssertTrue(view.mainIconFitLabel.stringValue.contains("app 80 pt; folder entry 71 pt"))
        XCTAssertTrue(view.mainIconFitLabel.stringValue.contains("Current-window candidate"))
        XCTAssertTrue(view.mainIconFitLabel.stringValue.contains("does not confirm saving or display"))
        var writes = 0
        view.onChange = { _ in writes += 1; return true }
        for (slider, value) in [(view.mainIconSlider, 96), (view.iconSlider, 64),
                                (view.blurSlider, 25), (view.fontSlider, 12)] {
            let oldCount = observed.count
            send(slider, value)
            XCTAssertGreaterThan(observed.count, oldCount)
            XCTAssertEqual(observed.last, view.draft)
        }
        view.labelsCheckbox.performClick(nil)
        XCTAssertEqual(observed.last, view.draft)
        view.updateLiveStatus(.saved, presentation: .queued)
        let status = view.statusLabel.stringValue
        let submitted = view.draft
        fit = (61.3, 49.7)
        view.refreshMainIconFit()
        XCTAssertEqual(view.mainIconFitLabel.stringValue, english.mainIconFitText(app: 61.3, folder: 49.7))
        XCTAssertEqual(view.statusLabel.stringValue, status)
        XCTAssertEqual(view.liveSaveState, .saved)
        XCTAssertEqual(view.draft, submitted)
        let writeCount = writes
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            XCTAssertEqual(view.mainIconFitLabel.stringValue, strings.mainIconFitText(app: 61.3, folder: 49.7))
            XCTAssertEqual(view.mainIconFitLabel.accessibilityLabel(), view.mainIconFitLabel.stringValue)
            XCTAssertEqual(view.mainIconFitLabel.accessibilityValue() as? String, view.mainIconFitLabel.stringValue)
            XCTAssertEqual(view.mainIconCaption.stringValue, strings.settingsText(.appearanceMainIconCaption))
            XCTAssertEqual(view.iconHelpLabel.stringValue, strings.settingsText(.appearanceIndependentIconsHelp))
            XCTAssertEqual(view.draft, submitted)
            XCTAssertEqual(writes, writeCount)
        }
        var loaded = submitted
        loaded.mainPreferredIconSide = nil
        loaded.preferredIconSide = 54
        view.reload(preferences: loaded)
        XCTAssertEqual(observed.last, loaded)
        XCTAssertEqual(view.mainIconValue.stringValue, "54")
        XCTAssertEqual(writes, writeCount)
        view.mainIconFitProvider = { _ in (32, 24) }
        XCTAssertEqual(view.mainIconFitLabel.stringValue, view.strings.mainIconFitText(app: 32, folder: 24))
        view.mainIconFitProvider = nil
        XCTAssertTrue(view.mainIconFitLabel.isHidden)
        XCTAssertEqual(view.mainIconFitLabel.stringValue, "")
    }

    func testUnavailableOrInvalidFitStaysHiddenAndNeverFabricatesGeometry() {
        let view = makeView()
        let results: [(app: CGFloat, folder: CGFloat)?] = [
            nil, (.nan, 40), (40, .infinity), (-1, 40), (40, -1)
        ]
        for result in results {
            view.mainIconFitProvider = { _ in result }
            XCTAssertTrue(view.mainIconFitLabel.isHidden)
            XCTAssertEqual(view.mainIconFitLabel.stringValue, "")
        }
        view.mainIconFitProvider = { _ in (0, 0) }
        XCTAssertFalse(view.mainIconFitLabel.isHidden, "A real zero-fit result must remain truthful")
        XCTAssertEqual(view.mainIconFitLabel.stringValue, english.mainIconFitText(app: 0, folder: 0))
        XCTAssertEqual(view.liveSaveState, .idle)
    }

    func testDefaultsRecoveryAndProtectionKeepExistingOwnerSemantics() {
        let view = makeView()
        var custom = AppearancePreferences.default
        custom.mainPreferredIconSide = 96
        custom.preferredIconSide = 64
        var writes: [AppearancePreferences] = []
        var recoveries: [AppearancePreferences] = []
        view.onChange = { writes.append($0); return true }
        view.onApply = { recoveries.append($0); return .saved }
        view.reload(preferences: custom, loadResult: .corrupt)
        send(view.mainIconSlider, 88)
        XCTAssertTrue(writes.isEmpty)
        XCTAssertEqual(view.liveSaveState, .recoveryRequired)
        view.defaultsClicked(nil)
        XCTAssertEqual(view.draft, .default)
        XCTAssertEqual(view.mainIconSlider.integerValue, 80)
        XCTAssertEqual(view.iconSlider.integerValue, 80)
        XCTAssertTrue(writes.isEmpty)
        view.applyClicked(nil)
        XCTAssertEqual(recoveries, [.default])
        XCTAssertEqual(view.liveSaveState, .saved)
        view.reload(preferences: custom, loadResult: .loaded(custom))
        view.defaultsClicked(nil)
        XCTAssertEqual(writes, [.default])
        for state in [LiveSettingsSaveState.protected, .unavailable] {
            view.reload(preferences: custom)
            view.updateLiveStatus(state, presentation: .queued)
            let beforeWrites = writes.count
            let beforeRecoveries = recoveries.count
            XCTAssertFalse(view.mainIconSlider.isEnabled)
            XCTAssertFalse(view.iconSlider.isEnabled)
            view.mainIconSlider.integerValue = 32
            view.controlChanged(view.mainIconSlider)
            view.defaultsClicked(nil)
            view.applyClicked(nil)
            view.mainIconFitProvider = { _ in (32, 24) }
            view.refreshMainIconFit()
            XCTAssertEqual(view.draft, custom)
            XCTAssertEqual(writes.count, beforeWrites)
            XCTAssertEqual(recoveries.count, beforeRecoveries)
            XCTAssertEqual(view.liveSaveState, state)
        }
        view.reload(preferences: custom, loadResult: .futureVersion(99))
        XCTAssertFalse(view.mainIconSlider.isEnabled)
        view.defaultsClicked(nil)
        XCTAssertEqual(view.draft, custom)
        XCTAssertEqual(view.liveSaveState, .protected)
    }

    func testNewControlsAndMergedCapacityRemainAccessibleInsideTheSameScrollView() throws {
        let view = makeView()
        let grid = MainGridCapacitySettingsView(frame: view.bounds, strings: english)
        view.attachMainGridSection(grid)
        let scroll = try XCTUnwrap(descendants(view).first { $0 is NSScrollView } as? NSScrollView)
        let document = try XCTUnwrap(scroll.documentView)
        for control in [view.labelsCheckbox as NSView, view.mainIconSlider, view.iconSlider,
                        view.fontSlider, grid.columnsPopup, grid.rowsPopup] {
            XCTAssertTrue(control.isDescendant(of: document))
            XCTAssertFalse(control.accessibilityLabel()?.isEmpty ?? true)
        }
        XCTAssertTrue(view.mainIconFitLabel.isDescendant(of: document))
        let identities = descendants(view).map(ObjectIdentifier.init)
        view.relabel(strings: LocalizedStrings(language: .japanese))
        XCTAssertEqual(descendants(view).map(ObjectIdentifier.init), identities)
        XCTAssertTrue(view.mainGridSection === grid)
    }

    func testNewTypedKeysUseShippedTablesAndEnglishFallbackAndSafeRoundedFitSlots() throws {
        XCTAssertTrue(LocalizedStrings.validateResources().isValid)
        let bundle = BundleLocalizationResourceProvider()
        for language in InterfaceLanguage.allCases {
            let data = try XCTUnwrap(bundle.localizableStringsData(for: language))
            let table = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
            let strings = LocalizedStrings(language: language)
            for key in newKeys {
                XCTAssertTrue(LocalizedStrings.requiredResourceKeys.contains(key.rawValue))
                XCTAssertEqual(strings.settingsText(key), table[key.rawValue])
                XCTAssertNotEqual(strings.settingsText(key), key.rawValue)
                if language != .english { XCTAssertNotEqual(strings.settingsText(key), english.settingsText(key)) }
            }
            let format = strings.settingsText(.appearanceMainIconFitFormat)
            XCTAssertEqual(format.components(separatedBy: "%.0f").count, 3)
            XCTAssertFalse(strings.mainIconFitText(app: 79.6, folder: 47.2).contains("%.0f"))
            XCTAssertTrue(strings.mainIconFitText(app: 79.6, folder: 47.2).contains("80"))
            XCTAssertTrue(strings.mainIconFitText(app: 79.6, folder: 47.2).contains("47"))
            let absent = LocalizedStrings(language: language, resourceProvider: MainIconTestResources(tables: [:]))
            for key in newKeys { XCTAssertEqual(absent.settingsText(key), english.settingsText(key)) }
            XCTAssertEqual(absent.mainIconFitText(app: 80, folder: 64), english.mainIconFitText(app: 80, folder: 64))
            // Keep the old explicit-Apply help available to legacy consumers.
            XCTAssertEqual(absent.settingsText(.appearanceHelp), english.settingsText(.appearanceHelp))
            for invalid in ["No sizes", "%@ %.0f %.0f", "%.0f %.0f %.0f", "{count}"] {
                var changed = table
                changed[SettingsTextKey.appearanceMainIconFitFormat.rawValue] = invalid
                let bytes = try PropertyListSerialization.data(fromPropertyList: changed, format: .xml, options: 0)
                let provider = MainIconTestResources(tables: [language.rawValue: bytes])
                XCTAssertEqual(LocalizedStrings(language: language, resourceProvider: provider)
                    .mainIconFitText(app: 80, folder: 64), english.mainIconFitText(app: 80, folder: 64))
            }
        }
    }
}

private struct MainIconTestResources: LocalizationResourceProviding {
    let tables: [String: Data]
    func localizableStringsData(for language: InterfaceLanguage) -> Data? { tables[language.rawValue] }
}
