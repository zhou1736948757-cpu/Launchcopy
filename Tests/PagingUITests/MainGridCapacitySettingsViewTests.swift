import AppGridUI
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

/// Source-authored coverage for Main's serialized execution. No real store or
/// catalog is used, and settings windows remain unshown.
@MainActor
final class MainGridCapacitySettingsViewTests: XCTestCase {
    private let frame = NSRect(x: 0, y: 0, width: 500, height: 560)
    private let english = LocalizedStrings(language: .english)

    private func makeView(capacity: MainGridCapacity = .default,
                          loadResult: MainGridCapacityLoadResult = .missing) -> MainGridCapacitySettingsView {
        let view = MainGridCapacitySettingsView(frame: frame, strings: english)
        view.reload(capacity: capacity, loadResult: loadResult)
        return view
    }

    private func select(_ view: MainGridCapacitySettingsView, columns: Int, rows: Int) {
        view.columnsPopup.selectItem(withTag: columns)
        view.rowsPopup.selectItem(withTag: rows)
        view.controlChanged(nil)
    }

    private func assertStatus(_ label: NSTextField, _ key: MainGridCapacityTextKey,
                              strings: LocalizedStrings, file: StaticString = #filePath,
                              line: UInt = #line) {
        XCTAssertFalse(label.isHidden, file: file, line: line)
        let expected: String
        switch key {
        case .loadCorrupt, .recoveryRequired: expected = strings.liveAppearanceText(.recoveryRequired)
        case .loadProtected: expected = strings.liveAppearanceText(.protected)
        case .unavailable: expected = strings.liveAppearanceText(.unavailable)
        case .saveFailed: expected = strings.liveAppearanceText(.saveFailed)
        default: expected = strings.mainGridCapacityText(key)
        }
        XCTAssertEqual(label.stringValue, expected, file: file, line: line)
        XCTAssertEqual(label.accessibilityLabel(), label.stringValue, file: file, line: line)
        XCTAssertEqual(label.accessibilityValue(), label.stringValue, file: file, line: line)
    }

    private func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }

    func testUnconfiguredViewCannotWriteUntilTheOwnerLoadsIt() {
        let view = MainGridCapacitySettingsView(frame: frame, strings: english)
        var writes = 0
        view.onApply = { _ in writes += 1; return true }
        XCTAssertFalse(view.applyButton.isEnabled)
        XCTAssertFalse(view.defaultsButton.isEnabled)
        XCTAssertFalse(view.columnsPopup.isEnabled)
        XCTAssertFalse(view.rowsPopup.isEnabled)
        assertStatus(view.loadStatusLabel, .unavailable, strings: english)
        view.applyClicked(nil)
        view.defaultsClicked(nil)
        XCTAssertEqual(writes, 0)
        XCTAssertEqual(view.draft, .default)
        view.reload(capacity: .default, loadResult: .missing)
        XCTAssertTrue(view.applyButton.isEnabled)
        XCTAssertTrue(view.applyButton.isHidden, "Healthy loads need no Apply action")
        XCTAssertTrue(view.loadStatusLabel.isHidden)
    }

    func testEveryBoundedPairUsesExactTagsAndDerivedCountAndAutomaticallySubmits() throws {
        let view = makeView()
        var writes: [MainGridCapacity] = [], expected: [MainGridCapacity] = []
        view.onApply = { writes.append($0); return true }
        XCTAssertEqual(view.columnsPopup.itemArray.map(\.tag), Array(3...8))
        XCTAssertEqual(view.rowsPopup.itemArray.map(\.tag), Array(3...8))
        XCTAssertEqual(view.columnsPopup.selectedTag(), 5)
        XCTAssertEqual(view.rowsPopup.selectedTag(), 7)
        for columns in 3...8 {
            for rows in 3...8 {
                select(view, columns: columns, rows: rows)
                let capacity = try XCTUnwrap(MainGridCapacity(columns: columns, rows: rows))
                expected.append(capacity)
                XCTAssertEqual(view.draft, capacity)
                XCTAssertEqual(view.countLabel.stringValue, "Items per page: \(columns * rows)")
                XCTAssertEqual(view.countLabel.accessibilityValue(),
                               "Items per page: \(columns * rows)")
                XCTAssertLessThanOrEqual(capacity.itemsPerPage, 64)
                XCTAssertEqual(writes, expected, "Each valid changed selection submits exactly once")
                XCTAssertTrue(view.applyButton.isHidden)
            }
        }
        XCTAssertEqual(writes.count, 36)
    }

    func testAdmissionShowsSavingUntilAnActualReceiptAndThenTracksPresentation() {
        let view = makeView()
        var accepted: [MainGridCapacity] = []
        view.onApply = { accepted.append($0); return true }
        select(view, columns: 8, rows: 8)
        XCTAssertEqual(accepted, [view.draft])
        assertStatus(view.statusLabel, .saving, strings: english)
        view.updateStatus(pendingCount: 0, saveResult: nil, presentation: .applied)
        assertStatus(view.statusLabel, .saving, strings: english)
        view.updateStatus(pendingCount: 1, saveResult: .saved, presentation: .applied)
        assertStatus(view.statusLabel, .saving, strings: english)
        view.updateStatus(pendingCount: 0, saveResult: .saved, presentation: .queued)
        assertStatus(view.statusLabel, .savedQueued, strings: english)
        view.updateStatus(pendingCount: 0, saveResult: .saved, presentation: .applied)
        assertStatus(view.statusLabel, .applied, strings: english)
        view.updateStatus(pendingCount: 0, saveResult: .saved, presentation: .unavailable)
        assertStatus(view.statusLabel, .presentationUnavailable, strings: english)
    }

    func testSynchronousOwnerReceiptIsNotOverwrittenByAdmission() {
        let view = makeView()
        view.onApply = { [weak view] _ in
            view?.updateStatus(pendingCount: 0, saveResult: .saved, presentation: .queued)
            return true
        }
        select(view, columns: 6, rows: 8)
        assertStatus(view.statusLabel, .savedQueued, strings: english)
    }

    func testRejectedOrMissingOwnerDoesNotClaimSavedAndRetainsDraft() {
        let view = makeView()
        select(view, columns: 8, rows: 3)
        let draft = view.draft
        view.applyClicked(nil)
        assertStatus(view.statusLabel, .unavailable, strings: english)
        view.onApply = { _ in false }
        view.applyButton.performClick(nil)
        assertStatus(view.statusLabel, .unavailable, strings: english)
        XCTAssertEqual(view.draft, draft)
        XCTAssertEqual(view.columnsPopup.selectedTag(), 8)
        XCTAssertEqual(view.rowsPopup.selectedTag(), 3)
    }

    func testFailureAndLateReceiptsRetainNewerDirtyDraftAndAllowRetry() throws {
        let view = makeView()
        var writes: [MainGridCapacity] = []
        view.onApply = { writes.append($0); return true }
        select(view, columns: 8, rows: 8)
        let accepted = view.draft
        select(view, columns: 3, rows: 4)
        let dirty = try XCTUnwrap(MainGridCapacity(columns: 3, rows: 4))
        XCTAssertEqual(writes, [accepted, dirty], "The newer edit is automatically admitted")
        view.updateStatus(pendingCount: 0, saveResult: .failed, presentation: .applied)
        assertStatus(view.statusLabel, .saveFailed, strings: english)
        XCTAssertEqual(view.draft, dirty)
        XCTAssertEqual(view.columnsPopup.selectedTag(), 3)
        XCTAssertEqual(view.rowsPopup.selectedTag(), 4)
        XCTAssertTrue(view.applyButton.isEnabled)
        XCTAssertFalse(view.applyButton.isHidden)
        view.applyButton.performClick(nil)
        XCTAssertEqual(writes, [accepted, dirty, dirty], "Retry explicitly resubmits the newest retained intent")
        assertStatus(view.statusLabel, .saving, strings: english)
        view.updateStatus(pendingCount: 0, saveResult: .saved, presentation: .queued)
        XCTAssertEqual(view.draft, dirty)
    }

    func testProtectedAndUnavailableLoadsBlockEvenDirectActions() throws {
        let capacity = try XCTUnwrap(MainGridCapacity(columns: 8, rows: 6))
        for result in [MainGridCapacityLoadResult.protectedPayload, .unavailable] {
            let view = makeView(capacity: capacity, loadResult: result)
            var writes = 0
            view.onApply = { _ in writes += 1; return true }
            XCTAssertFalse(view.columnsPopup.isEnabled)
            XCTAssertFalse(view.rowsPopup.isEnabled)
            XCTAssertFalse(view.applyButton.isEnabled)
            XCTAssertFalse(view.defaultsButton.isEnabled)
            view.defaultsClicked(nil)
            view.columnsPopup.selectItem(withTag: 3)
            view.controlChanged(nil)
            view.applyClicked(nil)
            XCTAssertEqual(view.draft, capacity)
            XCTAssertEqual(writes, 0)
            assertStatus(view.loadStatusLabel,
                         result == .protectedPayload ? .loadProtected : .unavailable, strings: english)
        }
    }

    func testCorruptLoadNeedsExplicitRecoveryAndOnlyItsSuccessfulReceiptClearsWarning() {
        let view = makeView(loadResult: .corrupt)
        var writes = 0
        view.onApply = { _ in writes += 1; return true }
        assertStatus(view.loadStatusLabel, .loadCorrupt, strings: english)
        XCTAssertTrue(view.applyButton.isEnabled)
        XCTAssertFalse(view.applyButton.isHidden)
        XCTAssertEqual(view.applyButton.title, english.liveAppearanceText(.recover))
        view.defaultsButton.performClick(nil)
        view.relabel(strings: LocalizedStrings(language: .japanese))
        XCTAssertEqual(writes, 0)
        view.applyButton.performClick(nil)
        XCTAssertEqual(writes, 1)
        assertStatus(view.loadStatusLabel, .loadCorrupt, strings: view.strings)
        view.updateStatus(pendingCount: 0, saveResult: .failed, presentation: .applied)
        assertStatus(view.loadStatusLabel, .loadCorrupt, strings: view.strings)
        XCTAssertEqual(view.statusLabel.stringValue, view.strings.liveAppearanceText(.recoveryFailed))
        XCTAssertEqual(view.statusLabel.accessibilityLabel(), view.statusLabel.stringValue)
        XCTAssertEqual(view.statusLabel.textColor, .systemRed)
        view.updateStatus(pendingCount: 0, saveResult: .saved, presentation: .queued)
        assertStatus(view.loadStatusLabel, .loadCorrupt, strings: view.strings)
        XCTAssertEqual(writes, 1, "A stale success after failure must not repair corruption")
        view.applyButton.performClick(nil)
        XCTAssertEqual(writes, 2)
        view.updateStatus(pendingCount: 0, saveResult: .saved, presentation: .queued)
        XCTAssertTrue(view.loadStatusLabel.isHidden)
    }

    func testDefaultsAutomaticallySubmitsAndReceiptRefreshRetainsDefaultSelection() {
        let view = makeView()
        select(view, columns: 8, rows: 8)
        var writes = 0
        view.onApply = { _ in writes += 1; return true }
        view.defaultsButton.performClick(nil)
        XCTAssertEqual(view.draft, .default)
        XCTAssertEqual(view.columnsPopup.selectedTag(), 5)
        XCTAssertEqual(view.rowsPopup.selectedTag(), 7)
        XCTAssertEqual(view.countLabel.stringValue, "Items per page: 35")
        XCTAssertTrue(view.draftStatusLabel.isHidden, "Defaults are submitted, not staged for Apply")
        assertStatus(view.statusLabel, .saving, strings: english)
        view.updateStatus(pendingCount: 0, saveResult: .saved, presentation: .queued)
        XCTAssertTrue(view.draftStatusLabel.isHidden)
        assertStatus(view.statusLabel, .savedQueued, strings: english)
        XCTAssertEqual(view.draft, .default)
        XCTAssertEqual(writes, 1)
    }

    func testTamperedTagsMenusAndTitlesRejectInsteadOfClampingTheDraft() {
        for mutation in 0..<5 {
            let view = makeView()
            select(view, columns: 8, rows: 8)
            let draft = view.draft
            var writes = 0
            view.onApply = { _ in writes += 1; return true }
            switch mutation {
            case 0: view.columnsPopup.selectedItem?.tag = Int.max
            case 1: view.rowsPopup.selectedItem?.tag = -3
            case 2: view.columnsPopup.removeAllItems()
            case 3:
                view.rowsPopup.addItem(withTitle: "Injected item")
                view.rowsPopup.lastItem?.tag = 8
                view.rowsPopup.selectItem(at: view.rowsPopup.numberOfItems - 1)
            default: view.rowsPopup.selectedItem?.title = "64"
            }
            view.controlChanged(nil)
            view.applyClicked(nil)
            XCTAssertEqual(view.draft, draft)
            XCTAssertEqual(writes, 0)
            assertStatus(view.draftStatusLabel, .invalidDraft, strings: english)
        }
    }

    func testTamperedDisplayedCountCannotSaveAndExplicitEditRecovers() {
        let view = makeView()
        var writes = 0
        view.onApply = { _ in writes += 1; return true }
        for text in ["Items per page: 65", "Items per page: -1", "Items per page: 999999999999999999999999"] {
            view.countLabel.stringValue = text
            view.applyClicked(nil)
            XCTAssertEqual(writes, 0)
            XCTAssertEqual(view.draft, .default)
            assertStatus(view.draftStatusLabel, .invalidDraft, strings: english)
        }
        select(view, columns: 8, rows: 8)
        XCTAssertEqual(writes, 1)
    }

    func testReceiptFailuresUseTypedFeedbackAndProtectionPreventsFurtherWrites() {
        let cases: [(MainGridCapacitySaveResult, MainGridCapacityTextKey, Bool)] = [
            (.invalid, .invalidDraft, true), (.failed, .saveFailed, true),
            (.protectedPayload, .loadProtected, false), (.recoveryRequired, .recoveryRequired, true)
        ]
        for (receipt, key, writable) in cases {
            let view = makeView()
            var writes = 0
            view.onApply = { _ in writes += 1; return true }
            select(view, columns: 6, rows: 8)
            let draft = view.draft
            view.updateStatus(pendingCount: 0, saveResult: receipt, presentation: .applied)
            assertStatus(view.statusLabel, key, strings: english)
            XCTAssertEqual(view.applyButton.isEnabled, writable)
            XCTAssertEqual(view.applyButton.isHidden, receipt == .protectedPayload)
            XCTAssertEqual(view.draft, draft)
            for language in InterfaceLanguage.allCases {
                view.relabel(strings: LocalizedStrings(language: language))
                assertStatus(view.statusLabel, key, strings: view.strings)
                XCTAssertEqual(view.draft, draft)
                XCTAssertEqual(view.applyButton.isEnabled, writable)
                XCTAssertEqual(writes, 1, "Receipt refresh and relabel must not issue writes")
            }
            if receipt == .protectedPayload {
                view.defaultsClicked(nil)
                view.applyClicked(nil)
                select(view, columns: 3, rows: 3)
                XCTAssertEqual(view.draft, draft)
                XCTAssertEqual(writes, 1, "Protection blocks direct actions after the original request")
            }
        }
    }

    func testRelabelRetainsDirtyDraftMenuIdentityCallbacksConstraintsAndInvalidSelection() {
        let view = makeView()
        select(view, columns: 8, rows: 4)
        let draft = view.draft
        let controls = descendants(view).map(ObjectIdentifier.init)
        let constraints = descendants(view).flatMap(\.constraints).map(ObjectIdentifier.init)
        let menuItems = (view.columnsPopup.itemArray + view.rowsPopup.itemArray).map(ObjectIdentifier.init)
        let target = view.applyButton.target
        let action = view.applyButton.action
        var writes = 0, discards = 0
        view.onApply = { _ in writes += 1; return true }
        view.onDiscardDraft = { discards += 1 }
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            XCTAssertEqual(view.draft, draft)
            XCTAssertEqual(view.columnsPopup.selectedTag(), 8)
            XCTAssertEqual(view.rowsPopup.selectedTag(), 4)
            XCTAssertEqual(view.countLabel.stringValue, strings.mainGridCapacityText(.itemsPerPage) + ": 32")
            XCTAssertEqual(view.columnsPopup.accessibilityLabel(), strings.mainGridCapacityText(.columns))
            XCTAssertEqual(view.rowsPopup.accessibilityLabel(), strings.mainGridCapacityText(.rows))
            XCTAssertEqual(view.applyButton.title, strings.liveAppearanceText(.retry))
            XCTAssertEqual(view.defaultsButton.title, strings.mainGridCapacityText(.restoreDefaults))
            XCTAssertEqual(descendants(view).map(ObjectIdentifier.init), controls)
            XCTAssertEqual(descendants(view).flatMap(\.constraints).map(ObjectIdentifier.init), constraints)
            XCTAssertEqual((view.columnsPopup.itemArray + view.rowsPopup.itemArray).map(ObjectIdentifier.init), menuItems)
            XCTAssertTrue(view.applyButton.target === target)
            XCTAssertEqual(view.applyButton.action, action)
            XCTAssertEqual(writes, 0)
            XCTAssertEqual(discards, 0)
        }
        view.rowsPopup.selectedItem?.tag = 99
        view.controlChanged(nil)
        view.relabel(strings: english)
        XCTAssertEqual(view.rowsPopup.selectedTag(), 99)
        XCTAssertEqual(view.draft, draft)
        assertStatus(view.draftStatusLabel, .invalidDraft, strings: english)
        view.rowsPopup.selectedItem?.tag = 4
        view.controlChanged(nil)
        XCTAssertEqual(writes, 1)
    }

    func testControllerRetainsGridUnderAppearanceAndPreservesSubmittedEditsOnHideAndClose() throws {
        let controller = ActivationSettingsWindowController(
            draft: .init(committed: ActivationPreferences()), strings: english)
        let view = controller.mainGridCapacityView
        let tabs = try XCTUnwrap(controller.window?.contentView as? NSTabView)
        let appearanceTab = tabs.tabViewItem(at: 1)
        XCTAssertTrue(appearanceTab.view === controller.appearanceView)
        XCTAssertTrue(controller.appearanceView.mainGridSection === view)
        XCTAssertTrue(view.isDescendant(of: controller.appearanceView))
        XCTAssertTrue(view.isEmbedded)
        XCTAssertFalse(tabs.tabViewItems.contains { $0.identifier as? String == "grid" })
        XCTAssertEqual(tabs.numberOfTabViewItems, 6)
        XCTAssertFalse(controller.window?.isVisible == true)
        let appearance = controller.appearanceView.draft
        let activation = controller.draft
        view.reload(capacity: .default, loadResult: .missing)
        var dismissals = 0
        var writes: [MainGridCapacity] = []
        view.onApply = { writes.append($0); return true }
        view.onDiscardDraft = { dismissals += 1 }
        select(view, columns: 8, rows: 8)
        let first = view.draft
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            controller.relabel(strings: strings)
            XCTAssertEqual(controller.appearanceView.gridTitleLabel.stringValue,
                           strings.mainGridCapacityText(.title))
            XCTAssertTrue(controller.appearanceView.mainGridSection === view)
            XCTAssertEqual(view.columnsPopup.selectedTag(), 8)
            XCTAssertEqual(view.rowsPopup.selectedTag(), 8)
            XCTAssertEqual(writes, [first], "Relabel must not submit again")
        }
        controller.hideSettings()
        XCTAssertEqual(dismissals, 1)
        XCTAssertEqual(view.draft, first)
        select(view, columns: 3, rows: 3)
        let second = view.draft
        XCTAssertFalse(controller.windowShouldClose(try XCTUnwrap(controller.window)))
        XCTAssertEqual(dismissals, 2)
        XCTAssertEqual(view.draft, second)
        XCTAssertEqual(writes, [first, second], "Hide and close retain submitted values without duplicate requests")
        XCTAssertEqual(controller.appearanceView.draft, appearance)
        XCTAssertEqual(controller.draft, activation)
    }
}
