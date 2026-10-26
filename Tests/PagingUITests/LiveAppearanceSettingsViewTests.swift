import AppGridUI
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

/// Authored for Main's serialized execution. Callbacks are in-memory fakes;
/// no stores, catalogs, shown windows, native input playback or timing assumptions.
@MainActor
final class LiveAppearanceSettingsViewTests: XCTestCase {
    private let english = LocalizedStrings(language: .english)
    private let frame = NSRect(x: 0, y: 0, width: 500, height: 560)

    private func appearance() -> AppearanceSettingsView {
        AppearanceSettingsView(frame: frame, strings: english)
    }

    private func grid(_ load: MainGridCapacityLoadResult = .missing,
                      embedded: Bool = false) -> MainGridCapacitySettingsView {
        let view = MainGridCapacitySettingsView(frame: frame, strings: english, embedded: embedded)
        view.reload(capacity: .default, loadResult: load)
        return view
    }

    private func select(_ view: MainGridCapacitySettingsView, columns: Int, rows: Int) {
        view.columnsPopup.selectItem(withTag: columns)
        view.rowsPopup.selectItem(withTag: rows)
        view.controlChanged(nil)
    }

    private func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }

    private func visible(_ view: NSView) -> Bool {
        !view.isHidden && (view.superview.map { visible($0) } ?? true)
    }

    func testNativeSliderActionsSubmitContinuousValuesAfterUpdatingCaptions() {
        let view = appearance()
        var writes: [AppearancePreferences] = []
        var explicitApplies = 0
        view.onApply = { _ in explicitApplies += 1; return .saved }
        view.onChange = { [weak view] preferences in
            guard let view else { XCTFail("View released during its action"); return false }
            XCTAssertEqual(view.blurValue.stringValue, String(preferences.wallpaperBlurRadius))
            XCTAssertEqual(view.iconValue.stringValue, String(preferences.preferredIconSide))
            XCTAssertEqual(view.fontValue.stringValue, String(preferences.appLabelFontSize))
            writes.append(preferences)
            return true
        }
        for (slider, value) in [(view.blurSlider, 35), (view.iconSlider, 60), (view.fontSlider, 15)] {
            XCTAssertTrue(slider.isContinuous)
            XCTAssertTrue(slider.target === view)
            slider.integerValue = value
            XCTAssertTrue(slider.sendAction(slider.action, to: slider.target))
        }
        view.labelsCheckbox.performClick(nil)
        XCTAssertEqual(writes.count, 4)
        XCTAssertEqual(writes.last, AppearancePreferences(showsAppLabels: false,
            wallpaperBlurRadius: 35, preferredIconSide: 60, appLabelFontSize: 15))
        view.controlChanged(nil)
        XCTAssertEqual(writes.count, 4, "Equal native values do not enqueue duplicate requests")
        XCTAssertEqual(explicitApplies, 0)
        XCTAssertTrue(view.applyButton.isHidden)
        XCTAssertEqual(view.liveSaveState, .pending)
        XCTAssertEqual(view.statusLabel.stringValue, english.liveAppearanceText(.saving))
    }

    func testTrackingCompletionBridgeFlushesNewestValueOncePerSliderCompletion() {
        let view = appearance()
        var submitted: [AppearancePreferences] = []
        var flushed: [AppearancePreferences] = []
        view.onChange = { submitted.append($0); return true }
        view.onFlush = { [weak view] in
            if let view { flushed.append(view.draft) }
        }
        for (slider, value) in [(view.blurSlider, 30), (view.iconSlider, 56), (view.fontSlider, 14)] {
            slider.integerValue = value
            view.controlChanged(nil) // Synthetic continuous update, not a completed non-mouse action.
            slider.trackingDidEnd()
            XCTAssertEqual(flushed.last, submitted.last)
        }
        XCTAssertEqual(flushed.count, 3)
        // This exercises the configured completion seam. Native mouse tracking
        // and the placement after super.mouseDown require Main's runtime review.
    }

    func testReloadRelabelAndEmbeddingNeverSubmitOrFlush() {
        let view = appearance()
        let capacity = grid()
        var actions = 0
        view.onChange = { _ in actions += 1; return true }
        view.onApply = { _ in actions += 1; return .saved }
        view.onFlush = { actions += 1 }
        view.onRestoreGridDefaults = { actions += 1 }
        capacity.onApply = { _ in actions += 1; return true }
        let custom = AppearancePreferences(showsAppLabels: false, wallpaperBlurRadius: 31,
            preferredIconSide: 59, appLabelFontSize: 13)
        for load in [AppearancePreferencesLoadResult.loaded(custom), .corrupt, .futureVersion(99)] {
            view.reload(preferences: custom, loadResult: load)
            for language in InterfaceLanguage.allCases {
                view.relabel(strings: LocalizedStrings(language: language))
                capacity.relabel(strings: LocalizedStrings(language: language))
            }
            XCTAssertEqual(view.draft, custom)
        }
        for load in [MainGridCapacityLoadResult.missing, .loaded(.default), .corrupt,
                     .protectedPayload, .unavailable] {
            capacity.reload(capacity: .default, loadResult: load)
        }
        view.attachMainGridSection(capacity)
        view.attachMainGridSection(capacity)
        XCTAssertEqual(actions, 0)
    }

    func testOwnerReceiptAndPresentationRemainSeparateAndRelabelRetainsState() {
        let view = appearance()
        view.onChange = { _ in true }
        view.blurSlider.integerValue = 40
        view.controlChanged(nil)
        view.presentationStateProvider = { .unavailable }
        view.refreshPresentationStatus()
        XCTAssertEqual(view.statusLabel.stringValue, english.liveAppearanceText(.saving),
            "Unavailable presentation cannot claim persistence success while saving")
        view.presentationStateProvider = { .queued }
        view.refreshPresentationStatus()
        XCTAssertEqual(view.liveSaveState, .pending)
        XCTAssertFalse(view.statusLabel.stringValue.contains(english.liveAppearanceText(.saved)))
        view.updateLiveStatus(.saved, presentation: .queued)
        let controls = descendants(view).map(ObjectIdentifier.init)
        let constraints = descendants(view).flatMap(\.constraints).map(ObjectIdentifier.init)
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            XCTAssertEqual(view.liveSaveState, .saved)
            XCTAssertEqual(view.draft.wallpaperBlurRadius, 40)
            XCTAssertEqual(view.statusLabel.stringValue,
                strings.liveAppearanceText(.saved) + "\n" + strings.liveAppearanceText(.queued))
            XCTAssertEqual(view.statusLabel.accessibilityValue(), view.statusLabel.stringValue)
            XCTAssertEqual(descendants(view).map(ObjectIdentifier.init), controls)
            XCTAssertEqual(descendants(view).flatMap(\.constraints).map(ObjectIdentifier.init), constraints)
            XCTAssertTrue(view.applyButton.isHidden)
        }
    }

    func testSynchronousOwnerStatusIsNotOverwrittenByBooleanAdmissionOrRejection() {
        for state in [LiveSettingsSaveState.saved, .protected, .recoveryRequired, .failed] {
            let view = appearance()
            view.onChange = { [weak view] _ in
                view?.updateLiveStatus(state, presentation: .queued)
                return state == .saved
            }
            view.iconSlider.integerValue = 63
            view.controlChanged(nil)
            XCTAssertEqual(view.liveSaveState, state)
            XCTAssertEqual(view.draft.preferredIconSide, 63)
            XCTAssertEqual(view.applyButton.isHidden, state == .saved || state == .protected)
        }
    }

    func testFailureExposesExplicitRetryWithoutDuplicatingAutomaticRequest() {
        let view = appearance()
        var automatic: [AppearancePreferences] = []
        var retries: [AppearancePreferences] = []
        view.onChange = { automatic.append($0); return false }
        view.onApply = { retries.append($0); return .saved }
        view.iconSlider.integerValue = 64
        view.controlChanged(nil)
        XCTAssertEqual(view.liveSaveState, .failed)
        XCTAssertFalse(view.applyButton.isHidden)
        XCTAssertEqual(view.applyButton.title, english.liveAppearanceText(.retry))
        view.applyButton.performClick(nil)
        XCTAssertEqual(automatic.count, 1)
        XCTAssertEqual(retries, automatic)
        XCTAssertEqual(view.liveSaveState, .saved)
        XCTAssertTrue(view.applyButton.isHidden)
    }

    func testRetryCanResubmitThroughLiveOwnerAndFlushWhenExplicitCallbackIsAbsent() {
        let view = appearance()
        var requests = 0, flushes = 0
        view.onChange = { _ in requests += 1; return requests > 1 }
        view.onFlush = { flushes += 1 }
        view.blurSlider.integerValue = 41
        view.controlChanged(nil)
        view.applyClicked(nil)
        XCTAssertEqual(requests, 2)
        XCTAssertEqual(flushes, 1)
        XCTAssertEqual(view.liveSaveState, .pending, "Admission still is not a save receipt")
    }

    func testCorruptAppearanceRequiresExplicitRecoveryEvenAfterDefaultsAndStraySuccess() {
        let view = appearance()
        var automatic = 0, recoveries = 0
        view.onChange = { _ in automatic += 1; return true }
        view.onApply = { _ in recoveries += 1; return .saved }
        view.reload(preferences: .default, loadResult: .corrupt)
        view.fontSlider.integerValue = 16
        view.controlChanged(nil)
        view.defaultsClicked(nil)
        view.updateLiveStatus(.saved, presentation: .applied)
        XCTAssertEqual(automatic, 0)
        XCTAssertEqual(recoveries, 0)
        XCTAssertEqual(view.liveSaveState, .recoveryRequired)
        XCTAssertFalse(view.applyButton.isHidden)
        XCTAssertEqual(view.applyButton.title, english.liveAppearanceText(.recover))
        view.applyButton.performClick(nil)
        XCTAssertEqual(recoveries, 1)
        XCTAssertEqual(view.liveSaveState, .saved)
        XCTAssertTrue(view.applyButton.isHidden)
        view.fontSlider.integerValue = 12
        view.controlChanged(nil)
        XCTAssertEqual(automatic, 1)
    }

    func testUnavailableAndFutureAppearanceRefuseOwnWritesButStillRequestGridDefaults() {
        for unavailable in [false, true] {
            let view = appearance()
            if unavailable { view.updateLiveStatus(.unavailable, presentation: .unavailable) }
            else { view.reload(preferences: .default, loadResult: .futureVersion(99)) }
            var appearanceWrites = 0, gridDefaults = 0
            view.onChange = { _ in appearanceWrites += 1; return true }
            view.onApply = { _ in appearanceWrites += 1; return .saved }
            view.onRestoreGridDefaults = { gridDefaults += 1 }
            XCTAssertTrue(view.defaultsButton.isEnabled)
            XCTAssertFalse(view.blurSlider.isEnabled)
            view.blurSlider.integerValue = 55
            view.controlChanged(nil)
            view.applyClicked(nil)
            view.defaultsButton.performClick(nil)
            XCTAssertEqual(appearanceWrites, 0)
            XCTAssertEqual(gridDefaults, 1)
            XCTAssertEqual(view.draft, .default)
            if !unavailable {
                view.updateLiveStatus(.idle, presentation: .applied)
                XCTAssertEqual(view.liveSaveState, .protected, "Only a reload can replace a protected snapshot")
            }
        }
    }

    func testHealthyGridEditsAndDefaultsAutomaticallySubmitAndAwaitReceipts() throws {
        let view = grid()
        var requests: [MainGridCapacity] = []
        var recoveryFlags: [Bool] = []
        view.onApply = { [weak view] capacity in
            requests.append(capacity)
            recoveryFlags.append(view?.isExplicitRecoveryRequest ?? true)
            return true
        }
        select(view, columns: 8, rows: 4)
        XCTAssertEqual(requests, [try XCTUnwrap(MainGridCapacity(columns: 8, rows: 4))])
        XCTAssertEqual(view.countLabel.stringValue, "Items per page: 32")
        XCTAssertEqual(view.statusLabel.stringValue, english.mainGridCapacityText(.saving))
        XCTAssertTrue(view.applyButton.isHidden)
        select(view, columns: 8, rows: 4)
        XCTAssertEqual(requests.count, 1)
        view.defaultsClicked(nil)
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.last, MainGridCapacity.default)
        XCTAssertEqual(recoveryFlags, [false, false])
        view.updateStatus(pendingCount: 0, saveResult: nil, presentation: .applied)
        XCTAssertEqual(view.statusLabel.stringValue, english.mainGridCapacityText(.saving))
        view.updateStatus(pendingCount: 0, saveResult: .saved, presentation: .queued)
        XCTAssertEqual(view.statusLabel.stringValue, english.mainGridCapacityText(.savedQueued))
        XCTAssertTrue(view.applyButton.isHidden)
    }

    func testGridRecoveryFlagExistsOnlyDuringExplicitCallbackAndResetsAfterRejection() {
        let view = grid(.corrupt)
        var recoveryFlags: [Bool] = []
        view.onApply = { [weak view] _ in
            recoveryFlags.append(view?.isExplicitRecoveryRequest ?? false)
            return false
        }
        select(view, columns: 6, rows: 6)
        view.defaultsClicked(nil)
        view.relabel(strings: LocalizedStrings(language: .japanese))
        XCTAssertTrue(recoveryFlags.isEmpty)
        XCTAssertFalse(view.isExplicitRecoveryRequest)
        view.applyClicked(nil)
        XCTAssertEqual(recoveryFlags, [true])
        XCTAssertFalse(view.isExplicitRecoveryRequest)
        XCTAssertTrue(view.applyButton.isEnabled)
        XCTAssertFalse(view.applyButton.isHidden)
        view.applyClicked(nil)
        XCTAssertEqual(recoveryFlags, [true, true])
        XCTAssertFalse(view.isExplicitRecoveryRequest)
    }

    func testRecoveryAdmissionCannotEraseWarningOrAcceptNewDraftBeforeReceipt() {
        let view = grid(.corrupt)
        var requests: [MainGridCapacity] = []
        view.onApply = { requests.append($0); return true }
        view.updateStatus(pendingCount: 0, saveResult: .saved, presentation: .applied)
        XCTAssertFalse(view.loadStatusLabel.isHidden)
        XCTAssertFalse(view.applyButton.isHidden)
        view.applyClicked(nil)
        XCTAssertFalse(view.columnsPopup.isEnabled)
        XCTAssertFalse(view.loadStatusLabel.isHidden)
        select(view, columns: 8, rows: 8)
        view.defaultsClicked(nil)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(view.draft, .default)
        view.updateStatus(pendingCount: 0, saveResult: .failed, presentation: .applied)
        XCTAssertTrue(view.applyButton.isEnabled)
        // Programmatic selection above bypassed disabled native controls. Restore
        // their accepted selection before exercising the explicit retry action.
        view.columnsPopup.selectItem(withTag: view.draft.columns)
        view.rowsPopup.selectItem(withTag: view.draft.rows)
        view.applyClicked(nil)
        view.updateStatus(pendingCount: 0, saveResult: .saved, presentation: .queued)
        XCTAssertTrue(view.loadStatusLabel.isHidden)
        XCTAssertTrue(view.applyButton.isHidden)
        XCTAssertTrue(view.columnsPopup.isEnabled)
    }

    func testGridFailedSaveRetriesLatestDraftWithoutRecoveryAuthorization() {
        let view = grid()
        var requests: [MainGridCapacity] = []
        view.onApply = { [weak view] capacity in
            XCTAssertEqual(view?.isExplicitRecoveryRequest, false)
            requests.append(capacity)
            return true
        }
        select(view, columns: 8, rows: 8)
        view.updateStatus(pendingCount: 0, saveResult: .failed, presentation: .queued)
        XCTAssertFalse(view.applyButton.isHidden)
        XCTAssertEqual(view.applyButton.title, english.liveAppearanceText(.retry))
        view.applyButton.performClick(nil)
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first, requests.last)
        XCTAssertTrue(view.applyButton.isHidden)
        XCTAssertEqual(view.statusLabel.stringValue, english.mainGridCapacityText(.saving))
    }

    func testGridSynchronousAuthoritativeProtectionSurvivesRejectedAdmission() {
        for result in [MainGridCapacitySaveResult.protectedPayload, .recoveryRequired] {
            let view = grid()
            view.onApply = { [weak view] _ in
                view?.updateStatus(pendingCount: 0, saveResult: result, presentation: .queued)
                return false
            }
            select(view, columns: 8, rows: 6)
            XCTAssertEqual(view.statusLabel.stringValue,
                english.liveAppearanceText(result == .protectedPayload ? .protected : .recoveryRequired))
            XCTAssertEqual(view.applyButton.isHidden, result == .protectedPayload)
            XCTAssertFalse(view.isExplicitRecoveryRequest)
        }
    }

    func testProtectedAndUnavailableGridLoadsRejectAllActionsAndStraySuccess() {
        for load in [MainGridCapacityLoadResult.protectedPayload, .unavailable] {
            let view = grid(load)
            var requests = 0
            view.onApply = { _ in requests += 1; return true }
            select(view, columns: 8, rows: 8)
            view.defaultsClicked(nil)
            view.applyClicked(nil)
            view.updateStatus(pendingCount: 0, saveResult: .saved, presentation: .applied)
            XCTAssertEqual(requests, 0)
            XCTAssertEqual(view.draft, .default)
            XCTAssertFalse(view.columnsPopup.isEnabled)
            XCTAssertTrue(view.statusLabel.isHidden)
            XCTAssertFalse(view.loadStatusLabel.isHidden)
        }
    }

    func testInvalidGridMenusCannotAutosubmitIncludingDefaults() {
        let view = grid()
        var requests = 0
        view.onApply = { _ in requests += 1; return true }
        view.rowsPopup.item(at: 0)?.tag = 99
        select(view, columns: 8, rows: 8)
        view.defaultsClicked(nil)
        view.applyClicked(nil)
        XCTAssertEqual(requests, 0)
        XCTAssertEqual(view.draftStatusLabel.stringValue, english.mainGridCapacityText(.invalidDraft))
    }

    func testEmbeddingPreservesControlsMenusAndDraftWithoutNestedScrollingOrWrites() {
        let view = grid()
        select(view, columns: 8, rows: 4)
        let draft = view.draft
        let columnPopup = view.columnsPopup
        let menuItems = view.columnsPopup.itemArray.map(ObjectIdentifier.init)
        var writes = 0
        view.onApply = { _ in writes += 1; return true }
        view.setEmbedded(true)
        XCTAssertTrue(view.isEmbedded)
        XCTAssertTrue(descendants(view).allSatisfy { !($0 is NSScrollView) })
        XCTAssertTrue(view.defaultsButton.isHidden)
        XCTAssertEqual(view.draft, draft)
        XCTAssertTrue(view.columnsPopup === columnPopup)
        XCTAssertEqual(view.columnsPopup.itemArray.map(ObjectIdentifier.init), menuItems)
        XCTAssertEqual(writes, 0)
        view.setEmbedded(false)
        XCTAssertEqual(descendants(view).filter { $0 is NSScrollView }.count, 1)
        XCTAssertEqual(view.draft, draft)
        XCTAssertEqual(writes, 0)
    }

    func testControllerHasSixTabsSameGridOneScrollAndOneScopedDefaults() throws {
        _ = NSApplication.shared
        let controller = ActivationSettingsWindowController(draft: .init(committed: .init()), strings: english)
        defer {
            controller.window?.delegate = nil
            controller.window?.contentView = nil
            controller.window?.close()
        }
        let tabs = try XCTUnwrap(controller.window?.contentView as? NSTabView)
        XCTAssertEqual(tabs.tabViewItems.compactMap { $0.identifier as? String },
            ["activation", "appearance", "management", "sources", "language", "library"])
        let view = controller.appearanceView
        let capacity = controller.mainGridCapacityView
        XCTAssertTrue(view.mainGridSection === capacity)
        XCTAssertTrue(capacity.isDescendant(of: view))
        XCTAssertTrue(capacity.isEmbedded)
        XCTAssertEqual(descendants(view).filter { $0 is NSScrollView }.count, 1)
        let defaults = descendants(view).compactMap { $0 as? NSButton }.filter {
            let identifier = $0.identifier?.rawValue
            return visible($0) && (identifier == "appearance.defaults" || identifier == "mainGridCapacity.defaults")
        }
        XCTAssertEqual(defaults.count, 1)
        XCTAssertTrue(defaults.first === view.defaultsButton)
        let activation = controller.draft
        controller.appManagementView.aliasField.stringValue = "Retained alias draft"
        capacity.reload(capacity: .default, loadResult: .missing)
        var appearanceRequests: [AppearancePreferences] = []
        var gridRequests: [MainGridCapacity] = []
        view.onChange = { appearanceRequests.append($0); return true }
        capacity.onApply = { gridRequests.append($0); return true }
        view.defaultsButton.performClick(nil)
        XCTAssertEqual(appearanceRequests, [.default])
        XCTAssertEqual(gridRequests, [.default])
        XCTAssertEqual(controller.draft, activation)
        XCTAssertEqual(controller.appManagementView.aliasField.stringValue, "Retained alias draft")
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            controller.relabel(strings: strings)
            XCTAssertEqual(tabs.numberOfTabViewItems, 6)
            XCTAssertTrue(view.mainGridSection === capacity)
            XCTAssertEqual(view.gridTitleLabel.stringValue, strings.mainGridCapacityText(.title))
            XCTAssertEqual(view.helpLabel.stringValue, strings.liveAppearanceText(.help))
            XCTAssertEqual(capacity.helpLabel.stringValue, strings.liveAppearanceText(.gridHelp))
        }
        XCTAssertEqual(appearanceRequests.count, 1)
        XCTAssertEqual(gridRequests.count, 1)
    }

    func testCombinedDefaultsRetainsHonestIndependentFailureAndSuccess() {
        let view = appearance()
        let capacity = grid(embedded: true)
        view.attachMainGridSection(capacity)
        view.onRestoreGridDefaults = { capacity.defaultsClicked(nil) }
        view.onChange = { [weak view] _ in
            view?.updateLiveStatus(.failed, presentation: .queued)
            return false
        }
        capacity.onApply = { [weak capacity] _ in
            capacity?.updateStatus(pendingCount: 0, saveResult: .saved, presentation: .queued)
            return true
        }
        view.defaultsClicked(nil)
        XCTAssertEqual(view.liveSaveState, .failed)
        XCTAssertFalse(view.applyButton.isHidden)
        XCTAssertEqual(capacity.statusLabel.stringValue, english.mainGridCapacityText(.savedQueued))
        XCTAssertTrue(capacity.applyButton.isHidden)
    }

    func testControllerRetainsDismissalHooksForOwnerFlushWithoutResettingDraft() throws {
        _ = NSApplication.shared
        let controller = ActivationSettingsWindowController(draft: .init(committed: .init()), strings: english)
        defer {
            controller.window?.delegate = nil
            controller.window?.contentView = nil
            controller.window?.close()
        }
        let view = controller.appearanceView
        let capacity = controller.mainGridCapacityView
        capacity.reload(capacity: .default, loadResult: .missing)
        view.onChange = { _ in true }
        capacity.onApply = { _ in true }
        view.blurSlider.integerValue = 50
        view.controlChanged(nil)
        select(capacity, columns: 8, rows: 8)
        var appearanceFlushes = 0, gridFlushes = 0
        view.onFlush = { appearanceFlushes += 1 }
        view.onDiscardDraft = { [weak view] in view?.onFlush?() }
        capacity.onDiscardDraft = { gridFlushes += 1 }
        controller.hideSettings()
        XCTAssertFalse(controller.windowShouldClose(try XCTUnwrap(controller.window)))
        XCTAssertEqual(appearanceFlushes, 2)
        XCTAssertEqual(gridFlushes, 2)
        XCTAssertEqual(view.draft.wallpaperBlurRadius, 50)
        XCTAssertEqual(capacity.draft.columns, 8)
        XCTAssertEqual(capacity.draft.rows, 8)
    }
    func testDiscreteCheckboxAndNonMouseSliderActionsFlushTheirAcceptedValue() {
        let view = AppearanceSettingsView(frame: .zero, strings: english)
        var submitted: [AppearancePreferences] = []
        var flushed: [AppearancePreferences] = []
        view.onChange = { submitted.append($0); return true }
        view.onFlush = { flushed.append(view.draft) }
        view.labelsCheckbox.performClick(nil)
        XCTAssertEqual(flushed, submitted)
        XCTAssertEqual(flushed.count, 1)
        view.iconSlider.integerValue = 64
        view.controlChanged(view.iconSlider) // The same target/action used by a non-mouse native edit.
        XCTAssertEqual(flushed, submitted)
        XCTAssertEqual(flushed.count, 2)
    }

    func testFailedAppearanceRecoveryInstructionNamesVisibleRecoveryActionInAllLanguages() {
        for language in InterfaceLanguage.allCases {
            let view = AppearanceSettingsView(frame: .zero, strings: .init(language: language))
            view.reload(preferences: .default, loadResult: .corrupt)
            view.onApply = { _ in .encodingFailed }
            view.applyClicked(nil)
            XCTAssertFalse(view.applyButton.isHidden)
            XCTAssertTrue(view.statusLabel.stringValue.contains(view.applyButton.title))
        }
    }

    func testFailedGridRecoveryInstructionNamesVisibleRecoveryActionInAllLanguages() {
        for language in InterfaceLanguage.allCases {
            let view = MainGridCapacitySettingsView(frame: .zero, strings: .init(language: language))
            view.reload(capacity: .default, loadResult: .corrupt)
            view.onApply = { _ in true }
            view.applyClicked(nil)
            view.updateStatus(pendingCount: 0, saveResult: .failed, presentation: .applied)
            XCTAssertFalse(view.applyButton.isHidden)
            XCTAssertTrue(view.statusLabel.stringValue.contains(view.applyButton.title))
        }
    }

}
