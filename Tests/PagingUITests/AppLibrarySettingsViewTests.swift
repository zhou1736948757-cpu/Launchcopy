import AppGridUI
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class AppLibrarySettingsViewTests: XCTestCase {
    func testInitialStateIsDisabledOffAndLoadingInEveryLanguage() {
        for language in InterfaceLanguage.allCases {
            let view = makeView(language: language)
            XCTAssertEqual(view.enabledCheckbox.state, .off)
            XCTAssertFalse(view.enabledCheckbox.isEnabled)
            XCTAssertTrue(view.recoverButton.isHidden)
            XCTAssertFalse(view.recoverButton.isEnabled)
            assertStatus(.loading, in: view)
        }
    }

    func testMissingLoadIsDefaultOffAndNeverRequestsWriteOrRecovery() {
        let view = makeView()
        var toggles: [Bool] = []
        var recoveries = 0
        view.onSetEnabled = { toggles.append($0); return true }
        view.onRecover = { recoveries += 1 }
        apply(view, load: .missing)
        XCTAssertEqual(view.enabledCheckbox.state, .off)
        XCTAssertTrue(view.enabledCheckbox.isEnabled)
        XCTAssertTrue(view.statusLabel.isHidden)
        XCTAssertTrue(view.recoverButton.isHidden)
        for language in InterfaceLanguage.allCases {
            view.relabel(strings: LocalizedStrings(language: language))
        }
        XCTAssertTrue(toggles.isEmpty)
        XCTAssertEqual(recoveries, 0)
    }

    func testLabelsAndStableAccessibilityIdentifiersInEnglishChineseAndJapanese() {
        let view = makeView()
        view.onRecover = {}
        apply(view, load: .corrupt)
        let expectedTitles: [(InterfaceLanguage, String)] = [
            (.english, "Enable App Library"),
            (.simplifiedChinese, "启用应用资料库"),
            (.japanese, "アプリライブラリを有効にする")
        ]
        for (language, title) in expectedTitles {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            XCTAssertEqual(view.enabledCheckbox.title, title)
            XCTAssertEqual(view.enabledCheckbox.accessibilityLabel(), title)
            XCTAssertEqual(view.recoverButton.title, strings.libraryText(.recover))
            XCTAssertEqual(view.recoverButton.accessibilityLabel(), strings.libraryText(.recover))
            for (control, identifier) in [
                (view.enabledCheckbox as NSView, "library.settings.enabled"),
                (view.recoverButton as NSView, "library.settings.recover"),
                (view.statusLabel as NSView, "library.settings.status")
            ] {
                XCTAssertEqual(control.identifier?.rawValue, identifier)
                XCTAssertEqual(control.accessibilityIdentifier(), identifier)
            }
            assertStatus(.loadCorrupt, in: view)
        }
    }

    func testProtectedLoadsAreUnknownAndCannotToggleOrRecoverEvenByDirectAction() {
        let view = makeView()
        var toggles = 0
        var recoveries = 0
        view.onSetEnabled = { _ in toggles += 1; return true }
        view.onRecover = { recoveries += 1 }
        for load in [AppLibraryLoadResult.futureVersion, .ambiguousSchema, .oversized, .unavailable] {
            // Supplied defaults do not prove the enablement of protected bytes.
            apply(view, enabled: true, load: load, save: .saved)
            XCTAssertEqual(view.enabledCheckbox.state, .mixed)
            XCTAssertTrue(view.enabledCheckbox.allowsMixedState)
            XCTAssertEqual(view.enabledCheckbox.accessibilityHelp(), view.strings.libraryText(.unknown))
            XCTAssertFalse(view.enabledCheckbox.isEnabled)
            XCTAssertTrue(view.recoverButton.isHidden)
            XCTAssertFalse(view.recoverButton.isEnabled)
            view.enabledCheckbox.state = .on
            view.enabledChanged(nil)
            view.recoverClicked(nil)
            XCTAssertEqual(view.enabledCheckbox.state, .mixed)
            for language in InterfaceLanguage.allCases {
                view.relabel(strings: LocalizedStrings(language: language))
                assertStatus(load == .futureVersion ? .loadFuture : .unavailable, in: view)
                XCTAssertEqual(view.enabledCheckbox.state, .mixed)
            }
        }
        XCTAssertEqual(toggles, 0)
        XCTAssertEqual(recoveries, 0)
    }

    func testProtectedAndUnavailableSaveReceiptsDisableOtherwiseHealthyState() {
        let view = makeView()
        var calls = 0
        view.onSetEnabled = { _ in calls += 1; return true }
        for receipt in [AppLibrarySaveResult.protectedPayload, .unavailable] {
            apply(view, enabled: true, load: .loaded(.init(enabled: true)), save: receipt)
            XCTAssertEqual(view.enabledCheckbox.state, .mixed)
            XCTAssertFalse(view.enabledCheckbox.isEnabled)
            assertStatus(.unavailable, in: view)
            view.enabledChanged(nil)
        }
        XCTAssertEqual(calls, 0)
    }

    func testCorruptRequiresExplicitRecoveryAndDoesNotSpeculateAboutConfirmation() {
        let view = makeView()
        var requested: [Bool] = []
        var recoveries = 0
        view.onSetEnabled = { requested.append($0); return true }
        view.onRecover = { recoveries += 1 }
        apply(view, enabled: true, load: .corrupt)
        XCTAssertEqual(view.enabledCheckbox.state, .off)
        XCTAssertFalse(view.enabledCheckbox.isEnabled)
        XCTAssertFalse(view.recoverButton.isHidden)
        XCTAssertTrue(view.recoverButton.isEnabled)
        assertStatus(.loadCorrupt, in: view)
        view.enabledCheckbox.state = .on
        view.enabledChanged(nil)
        view.relabel(strings: LocalizedStrings(language: .japanese))
        XCTAssertEqual(view.enabledCheckbox.state, .off)
        XCTAssertEqual(recoveries, 0)
        XCTAssertTrue(requested.isEmpty)
        view.recoverButton.performClick(nil)
        XCTAssertEqual(recoveries, 1)
        // An owner dialog can be cancelled. The view cannot infer acceptance.
        XCTAssertFalse(view.enabledCheckbox.isEnabled)
        XCTAssertEqual(view.enabledCheckbox.state, .off)
        assertStatus(.loadCorrupt, in: view)
    }

    func testRecoveryAvailabilityTracksCallbackAndRecoveryRequiredReceipt() {
        let view = makeView()
        apply(view, load: .missing, save: .recoveryRequired)
        XCTAssertFalse(view.enabledCheckbox.isEnabled)
        XCTAssertFalse(view.recoverButton.isHidden)
        XCTAssertFalse(view.recoverButton.isEnabled)
        var recoveries = 0
        view.onRecover = { recoveries += 1 }
        XCTAssertTrue(view.recoverButton.isEnabled)
        view.recoverButton.performClick(nil)
        XCTAssertEqual(recoveries, 1)
        view.onRecover = nil
        view.recoverClicked(nil)
        XCTAssertFalse(view.recoverButton.isEnabled)
        XCTAssertEqual(recoveries, 1)
    }

    func testRecoveryPendingFailureAndSuccessfulReceiptUseOwnerState() {
        let view = makeView()
        var recoveries = 0
        view.onRecover = { recoveries += 1 }
        apply(view, load: .corrupt, pending: 1)
        assertStatus(.pending, in: view)
        XCTAssertFalse(view.enabledCheckbox.isEnabled)
        XCTAssertFalse(view.recoverButton.isHidden)
        XCTAssertFalse(view.recoverButton.isEnabled)
        view.recoverClicked(nil)
        XCTAssertEqual(recoveries, 0)
        apply(view, load: .corrupt, save: .failed)
        XCTAssertEqual(view.statusLabel.stringValue,
                       view.strings.libraryText(.saveFailed) + "\n" + view.strings.libraryText(.loadCorrupt))
        XCTAssertFalse(view.enabledCheckbox.isEnabled)
        XCTAssertTrue(view.recoverButton.isEnabled)
        apply(view, load: .loaded(.default), save: .saved)
        XCTAssertEqual(view.enabledCheckbox.state, .off)
        XCTAssertTrue(view.enabledCheckbox.isEnabled)
        XCTAssertTrue(view.recoverButton.isHidden)
        assertStatus(.saved, in: view)
    }

    func testAcceptedToggleCapturesRequestButNeverClaimsDraftWasCommitted() {
        let view = makeView()
        apply(view)
        var requested: [Bool] = []
        view.onSetEnabled = { requested.append($0); return true }
        view.enabledCheckbox.performClick(nil)
        XCTAssertEqual(requested, [true])
        XCTAssertEqual(view.enabledCheckbox.state, .off)
        XCTAssertFalse(view.enabledCheckbox.isEnabled)
        assertStatus(.pending, in: view)
        for language in InterfaceLanguage.allCases {
            view.relabel(strings: LocalizedStrings(language: language))
            XCTAssertEqual(view.enabledCheckbox.state, .off)
            XCTAssertFalse(view.enabledCheckbox.isEnabled)
            assertStatus(.pending, in: view)
        }
        // Direct actions cannot enqueue another edit before an owner receipt.
        view.enabledCheckbox.state = .on
        view.enabledChanged(nil)
        XCTAssertEqual(view.enabledCheckbox.state, .off)
        XCTAssertEqual(requested, [true])
        apply(view, enabled: true, load: .loaded(.init(enabled: true)), save: .saved)
        XCTAssertEqual(view.enabledCheckbox.state, .on)
        XCTAssertTrue(view.enabledCheckbox.isEnabled)
        assertStatus(.saved, in: view)
        view.enabledCheckbox.performClick(nil)
        XCTAssertEqual(requested, [true, false])
        XCTAssertEqual(view.enabledCheckbox.state, .on)
        assertStatus(.pending, in: view)
    }

    func testRejectedToggleImmediatelyRestoresBothCommittedValues() {
        for enabled in [false, true] {
            let view = makeView()
            apply(view, enabled: enabled, load: .loaded(.init(enabled: enabled)))
            var requested: [Bool] = []
            view.onSetEnabled = { requested.append($0); return false }
            view.enabledCheckbox.performClick(nil)
            XCTAssertEqual(requested, [!enabled])
            XCTAssertEqual(view.enabledCheckbox.state, enabled ? .on : .off)
            XCTAssertTrue(view.enabledCheckbox.isEnabled)
            assertStatus(.saveFailed, in: view)
            view.relabel(strings: LocalizedStrings(language: .simplifiedChinese))
            assertStatus(.saveFailed, in: view)
            XCTAssertEqual(requested, [!enabled])
        }
    }

    func testNoCallbackRestoresCheckboxAndReportsUnavailableWithoutPending() {
        let view = makeView()
        apply(view)
        view.enabledCheckbox.performClick(nil)
        XCTAssertEqual(view.enabledCheckbox.state, .off)
        XCTAssertTrue(view.enabledCheckbox.isEnabled)
        assertStatus(.unavailable, in: view)
    }

    func testReentrantPendingSnapshotKeepsCapturedRequestAndFailureRestoresBaseline() {
        let view = makeView()
        apply(view)
        var captured: Bool?
        view.onSetEnabled = { [weak view] requested in
            guard let view else { return false }
            captured = requested
            self.apply(view, pending: 1)
            return true
        }
        view.enabledCheckbox.performClick(nil)
        XCTAssertEqual(captured, true)
        XCTAssertEqual(view.enabledCheckbox.state, .off)
        assertStatus(.pending, in: view)
        apply(view, save: .failed)
        XCTAssertEqual(view.enabledCheckbox.state, .off)
        XCTAssertTrue(view.enabledCheckbox.isEnabled)
        assertStatus(.saveFailed, in: view)
    }

    func testSynchronousTerminalSnapshotIsNotOverwrittenByAcceptanceReturn() {
        let view = makeView()
        apply(view)
        view.onSetEnabled = { [weak view] requested in
            guard let view else { return false }
            self.apply(view, enabled: requested, load: .loaded(.init(enabled: requested)), save: .saved)
            return true
        }
        view.enabledCheckbox.performClick(nil)
        XCTAssertEqual(view.enabledCheckbox.state, .on)
        XCTAssertTrue(view.enabledCheckbox.isEnabled)
        assertStatus(.saved, in: view)
    }

    func testLoadingAndMultiplePendingWritesIgnoreStaleSavedReceiptAndBlockActions() {
        let view = makeView()
        var calls = 0
        view.onSetEnabled = { _ in calls += 1; return true }
        view.onRecover = { calls += 1 }
        apply(view, enabled: true, save: .saved, loaded: false)
        XCTAssertEqual(view.enabledCheckbox.state, .off)
        XCTAssertFalse(view.enabledCheckbox.isEnabled)
        assertStatus(.loading, in: view)
        view.enabledChanged(nil)
        view.recoverClicked(nil)
        for count in [2, 1] {
            apply(view, enabled: true, load: .loaded(.init(enabled: true)), pending: count, save: .saved)
            XCTAssertEqual(view.enabledCheckbox.state, .on)
            XCTAssertFalse(view.enabledCheckbox.isEnabled)
            XCTAssertFalse(view.recoverButton.isEnabled)
            assertStatus(.pending, in: view)
            view.enabledChanged(nil)
            view.recoverClicked(nil)
        }
        // Failure of a later draft must retain an earlier actual saved baseline.
        apply(view, enabled: true, load: .loaded(.init(enabled: true)), save: .failed)
        XCTAssertEqual(view.enabledCheckbox.state, .on)
        XCTAssertTrue(view.enabledCheckbox.isEnabled)
        assertStatus(.saveFailed, in: view)
        XCTAssertEqual(calls, 0)
    }

    func testTerminalFailureKindsAndCommittedInputOverrideObsoleteLoadAssociatedValue() {
        let view = makeView()
        for receipt in [AppLibrarySaveResult.failed, .invalidPreferences] {
            apply(view, enabled: true, load: .loaded(.default), save: receipt)
            XCTAssertEqual(view.enabledCheckbox.state, .on)
            XCTAssertTrue(view.enabledCheckbox.isEnabled)
            assertStatus(.saveFailed, in: view)
        }
        apply(view, enabled: false, load: .loaded(.init(enabled: true)), save: .saved)
        XCTAssertEqual(view.enabledCheckbox.state, .off)
        assertStatus(.saved, in: view)
    }

    func testLocalizedRecoveryAndStatusFitSmallSettingsPane() {
        for language in InterfaceLanguage.allCases {
            let view = makeView(language: language)
            view.onRecover = {}
            view.setFrameSize(NSSize(width: 340, height: 360))
            let receipts: [AppLibrarySaveResult?] = [nil, .failed]
            for receipt in receipts {
                apply(view, load: .corrupt, save: receipt)
                view.layoutSubtreeIfNeeded()
                for control in [view.enabledCheckbox as NSView, view.statusLabel, view.recoverButton] {
                    let physical = view.convert(control.bounds, from: control)
                    XCTAssertTrue(view.bounds.contains(physical), "The complete native control frame must remain within the pane")
                    // Auto Layout anchors native alignment rectangles. AppKit's
                    // wrapping labels have a 2pt frame/alignment inset; measuring
                    // their raw frame against alignment margins creates a false
                    // overflow despite the complete frame remaining in the pane.
                    let rect = view.convert(control.alignmentRect(forFrame: control.frame), from: control.superview)
                    XCTAssertGreaterThan(rect.width, 0)
                    XCTAssertGreaterThan(rect.height, 0)
                    XCTAssertGreaterThanOrEqual(rect.minX, 23)
                    XCTAssertLessThanOrEqual(rect.maxX, view.bounds.width - 23, "control=\(type(of: control)), clip=\(view.scrollView.contentView.frame), document=\(String(describing: view.scrollView.documentView?.frame)), frame=\(physical)")
                    XCTAssertGreaterThanOrEqual(rect.minY, 23)
                    XCTAssertLessThanOrEqual(rect.maxY, view.bounds.height - 23)
                }
                let statusRect = view.convert(view.statusLabel.bounds, from: view.statusLabel)
                let recoveryRect = view.convert(view.recoverButton.bounds, from: view.recoverButton)
                XCTAssertFalse(statusRect.intersects(recoveryRect))
            }
        }
    }

    private func makeView(language: InterfaceLanguage = .english) -> AppLibrarySettingsView {
        AppLibrarySettingsView(frame: NSRect(x: 0, y: 0, width: 500, height: 560),
                               strings: LocalizedStrings(language: language))
    }

    private func apply(_ view: AppLibrarySettingsView, enabled: Bool = false,
                       load: AppLibraryLoadResult = .missing, pending: Int = 0,
                       save: AppLibrarySaveResult? = nil, loaded: Bool = true) {
        view.applyState(preferences: .init(enabled: enabled), loadResult: load,
                        pendingCount: pending, saveResult: save, isLoaded: loaded)
    }

    private func assertStatus(_ key: LibraryTextKey, in view: AppLibrarySettingsView,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(view.statusLabel.stringValue, view.strings.libraryText(key), file: file, line: line)
        XCTAssertEqual(view.statusLabel.accessibilityLabel(), view.strings.libraryText(key), file: file, line: line)
        XCTAssertFalse(view.statusLabel.isHidden, file: file, line: line)
    }
}
