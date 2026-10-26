import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class LaunchActivitySettingsViewTests: XCTestCase {
    func testInitialStateIsOffNoninteractiveAndWaitingInEveryLanguage() {
        for language in InterfaceLanguage.allCases {
            let view = makeView(language: language)
            XCTAssertEqual(view.enabledCheckbox.state, .off)
            XCTAssertFalse(view.enabledCheckbox.isEnabled)
            XCTAssertFalse(view.clearButton.isEnabled)
            XCTAssertFalse(view.retryButton.isEnabled)
            XCTAssertFalse(view.recoverButton.isEnabled)
            XCTAssertTrue(view.retryButton.isHidden)
            XCTAssertTrue(view.recoverButton.isHidden)
            assertStatus(.waiting, in: view)
        }
    }

    func testApplyAndRelabelNeverRequestActionsAndUseExactOwnerState() {
        let view = makeView()
        var calls = 0
        view.onSetEnabled = { _ in calls += 1 }
        view.onClear = { calls += 1 }
        view.onRetry = { calls += 1 }
        view.onRecover = { calls += 1 }
        for key in LaunchActivityTextKey.allCases {
            apply(view, enabled: true, canEnable: true, canClear: true, status: key,
                  canRetry: true, canRecover: true)
            for language in InterfaceLanguage.allCases {
                view.relabel(strings: LocalizedStrings(language: language))
                XCTAssertEqual(view.enabledCheckbox.state, .on)
                XCTAssertTrue(view.enabledCheckbox.isEnabled)
                XCTAssertTrue(view.clearButton.isEnabled)
                XCTAssertTrue(view.retryButton.isEnabled)
                XCTAssertTrue(view.recoverButton.isEnabled)
                assertStatus(key, in: view)
            }
        }
        XCTAssertEqual(calls, 0)
    }

    func testCheckboxImmediatelySendsBoolAndWaitsForOwnerAdmissionOrReceipt() {
        let view = makeView()
        var requests: [Bool] = []
        view.onSetEnabled = { requests.append($0) }
        for enabled in [false, true] {
            apply(view, enabled: enabled, canEnable: true, status: .saved)
            view.enabledCheckbox.performClick(nil)
            XCTAssertEqual(requests.last, !enabled)
            XCTAssertEqual(view.enabledCheckbox.state, enabled ? .on : .off)
            assertStatus(.saved, in: view)
        }
        XCTAssertEqual(requests, [true, false])
        // The checkbox does not infer that callback delivery means admission.
        apply(view, enabled: false, canEnable: true, status: .saveFailed, canRetry: true)
        XCTAssertEqual(view.enabledCheckbox.state, .off)
        assertStatus(.saveFailed, in: view)
    }

    func testSynchronousOwnerSnapshotIsNotOverwrittenAfterToggleCallback() {
        let view = makeView()
        apply(view, canEnable: true)
        var requests: [Bool] = []
        view.onSetEnabled = { [weak view] enabled in
            requests.append(enabled)
            guard let view else { return }
            self.apply(view, enabled: enabled, canEnable: true, busy: true, status: .saving)
        }
        view.enabledCheckbox.performClick(nil)
        XCTAssertEqual(requests, [true])
        XCTAssertEqual(view.enabledCheckbox.state, .on)
        assertStatus(.saving, in: view)
        apply(view, enabled: true, canEnable: true, canClear: true, status: .saved)
        assertStatus(.saved, in: view)
        view.onSetEnabled = { [weak view] enabled in
            requests.append(enabled)
            guard let view else { return }
            self.apply(view, enabled: enabled, canEnable: true, canClear: true, status: .off)
        }
        view.enabledCheckbox.performClick(nil)
        XCTAssertEqual(requests, [true, false])
        XCTAssertEqual(view.enabledCheckbox.state, .off)
        assertStatus(.off, in: view)
    }

    func testBusyStateAllowsOwnerAuthorizedImmediatePrivacyDisableButBlocksOtherActions() {
        let view = makeView()
        var toggles: [Bool] = []
        var otherActions = 0
        view.onSetEnabled = { toggles.append($0) }
        view.onClear = { otherActions += 1 }
        view.onRetry = { otherActions += 1 }
        view.onRecover = { otherActions += 1 }
        apply(view, enabled: true, canEnable: true, busy: true, canClear: true, status: .saving,
              canRetry: true, canRecover: true)
        XCTAssertTrue(view.enabledCheckbox.isEnabled)
        for button in [view.clearButton, view.retryButton, view.recoverButton] {
            XCTAssertFalse(button.isEnabled)
            button.performClick(nil)
        }
        view.clearClicked(nil)
        view.retryClicked(nil)
        view.recoverClicked(nil)
        view.enabledCheckbox.performClick(nil)
        XCTAssertEqual(toggles, [false])
        XCTAssertEqual(otherActions, 0)
        XCTAssertEqual(view.enabledCheckbox.state, .on, "Main supplies the admitted disable snapshot")
        assertStatus(.saving, in: view)
    }

    func testProtectedUnavailableWaitingAndLibraryDisabledBlockUnapprovedDirectActions() {
        let view = makeView()
        var calls = 0
        view.onSetEnabled = { _ in calls += 1 }
        view.onClear = { calls += 1 }
        view.onRetry = { calls += 1 }
        view.onRecover = { calls += 1 }
        for status in [LaunchActivityTextKey.protected, .unavailable, .waiting, .libraryDisabled] {
            apply(view, status: status)
            view.enabledCheckbox.state = .on
            view.enabledChanged(nil)
            view.clearClicked(nil)
            view.retryClicked(nil)
            view.recoverClicked(nil)
            XCTAssertEqual(view.enabledCheckbox.state, .off)
            XCTAssertFalse(view.enabledCheckbox.isEnabled)
            XCTAssertFalse(view.clearButton.isEnabled)
            XCTAssertTrue(view.retryButton.isHidden)
            XCTAssertTrue(view.recoverButton.isHidden)
            assertStatus(status, in: view)
        }
        XCTAssertEqual(calls, 0)
    }

    func testMissingCallbacksAndInvalidMixedValueNeverInventAdmissionOrSuccess() {
        let view = makeView()
        apply(view, canEnable: true, canClear: true, status: .off, canRetry: true, canRecover: true)
        view.enabledCheckbox.performClick(nil)
        view.clearButton.performClick(nil)
        view.retryButton.performClick(nil)
        view.recoverButton.performClick(nil)
        XCTAssertEqual(view.enabledCheckbox.state, .off)
        assertStatus(.off, in: view)
        var toggles = 0
        view.onSetEnabled = { _ in toggles += 1 }
        view.enabledCheckbox.allowsMixedState = true
        view.enabledCheckbox.state = .mixed
        view.enabledChanged(nil)
        XCTAssertEqual(toggles, 0)
        XCTAssertEqual(view.enabledCheckbox.state, .off)
    }

    func testClearRequestsOnlyOwnerConfirmationAndDoesNotChangeEnablementOrStatus() {
        let view = makeView()
        var clears = 0
        var toggles = 0
        view.onSetEnabled = { _ in toggles += 1 }
        view.onClear = { clears += 1 } // Owner may cancel its confirmation dialog.
        for enabled in [false, true] {
            apply(view, enabled: enabled, canEnable: true, canClear: true, status: .saved)
            view.clearButton.performClick(nil)
            XCTAssertEqual(view.enabledCheckbox.state, enabled ? .on : .off)
            assertStatus(.saved, in: view)
            apply(view, enabled: enabled, canEnable: true, status: .cleared)
            XCTAssertEqual(view.enabledCheckbox.state, enabled ? .on : .off)
            assertStatus(.cleared, in: view)
            view.clearClicked(nil)
        }
        XCTAssertEqual(clears, 2)
        XCTAssertEqual(toggles, 0)
    }

    func testRetryAndRecoveryFollowSuppliedPermissionsWithoutSpeculativeSuccess() {
        let view = makeView()
        var retries = 0
        var recoveries = 0
        view.onRetry = { retries += 1 }
        view.onRecover = { recoveries += 1 }
        apply(view, enabled: true, canEnable: true, status: .saveFailed, canRetry: true)
        XCTAssertFalse(view.retryButton.isHidden)
        XCTAssertTrue(view.recoverButton.isHidden)
        view.retryButton.performClick(nil)
        view.recoverClicked(nil)
        assertStatus(.saveFailed, in: view)
        XCTAssertEqual(view.statusLabel.textColor, .systemRed)
        apply(view, status: .recoveryRequired, canRecover: true)
        XCTAssertTrue(view.retryButton.isHidden)
        XCTAssertFalse(view.recoverButton.isHidden)
        view.retryClicked(nil)
        view.recoverButton.performClick(nil)
        assertStatus(.recoveryRequired, in: view)
        apply(view, busy: true, status: .saving, canRecover: true)
        view.recoverClicked(nil)
        apply(view, canEnable: true, status: .saved)
        XCTAssertTrue(view.retryButton.isHidden)
        XCTAssertTrue(view.recoverButton.isHidden)
        XCTAssertEqual(view.statusLabel.textColor, .secondaryLabelColor)
        XCTAssertEqual(retries, 1)
        XCTAssertEqual(recoveries, 1)
    }

    func testLocalizedAccessibilityAndControlIdentitiesSurviveRelabel() {
        let view = makeView()
        apply(view, enabled: true, canEnable: true, canClear: true, status: .saveFailed,
              canRetry: true, canRecover: true)
        let controls = descendants(view).map(ObjectIdentifier.init)
        let constraints = descendants(view).flatMap(\.constraints).map(ObjectIdentifier.init)
        let action = view.enabledCheckbox.action
        let target = view.enabledCheckbox.target
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            view.relabel(strings: strings)
            XCTAssertEqual(view.accessibilityLabel(), strings.launchActivityText(.title))
            XCTAssertEqual(view.enabledCheckbox.title, strings.launchActivityText(.enabled))
            XCTAssertEqual(view.helpLabel.stringValue, strings.launchActivityText(.privacyHelp))
            XCTAssertEqual(view.helpLabel.accessibilityLabel(), view.helpLabel.stringValue)
            for (button, key) in [(view.enabledCheckbox, LaunchActivityTextKey.enabled),
                                  (view.clearButton, .clear), (view.retryButton, .retry), (view.recoverButton, .recover)] {
                XCTAssertEqual(button.title, strings.launchActivityText(key))
                XCTAssertEqual(button.accessibilityLabel(), button.title)
            }
            for (control, suffix) in [(view as NSView, "section"), (view.enabledCheckbox, "enabled"),
                                      (view.clearButton, "clear"), (view.retryButton, "retry"),
                                      (view.recoverButton, "recover"), (view.statusLabel, "status"), (view.helpLabel, "help")] {
                XCTAssertEqual(control.identifier?.rawValue, "launchActivity.settings." + suffix)
                XCTAssertEqual(control.accessibilityIdentifier(), "launchActivity.settings." + suffix)
            }
            XCTAssertEqual(descendants(view).map(ObjectIdentifier.init), controls)
            XCTAssertEqual(descendants(view).flatMap(\.constraints).map(ObjectIdentifier.init), constraints)
            XCTAssertEqual(view.enabledCheckbox.action, action)
            XCTAssertTrue(view.enabledCheckbox.target === target)
            XCTAssertEqual(view.enabledCheckbox.state, .on)
            assertStatus(.saveFailed, in: view)
        }
    }

    func testVerticalIntrinsicLayoutWrapsHelpAndStatusAndDetachesHiddenActions() throws {
        for language in InterfaceLanguage.allCases {
            let view = makeView(language: language)
            let stack = try XCTUnwrap(view.subviews.first as? NSStackView)
            XCTAssertEqual(stack.orientation, .vertical)
            XCTAssertEqual(stack.alignment, .leading)
            XCTAssertTrue(stack.detachesHiddenViews)
            for label in [view.helpLabel, view.statusLabel] {
                XCTAssertEqual(label.maximumNumberOfLines, 0)
                XCTAssertEqual(label.lineBreakMode, .byWordWrapping)
                XCTAssertEqual(label.contentCompressionResistancePriority(for: .vertical), .required)
                XCTAssertEqual(label.contentCompressionResistancePriority(for: .horizontal), .defaultLow)
            }
            // A 500pt Library pane gives this child 452pt after Main's insets.
            // The child must keep its full explanation even at narrower widths.
            for width in [CGFloat(340), 452, 500] {
                view.setFrameSize(NSSize(width: width, height: 900))
                apply(view, canClear: true, status: .protected, canRecover: true)
                view.layoutSubtreeIfNeeded()
                for control in [view.enabledCheckbox as NSView, view.helpLabel, view.statusLabel,
                                view.clearButton, view.recoverButton] {
                    let rect = view.convert(control.bounds, from: control)
                    XCTAssertGreaterThan(rect.width, 0)
                    XCTAssertGreaterThan(rect.height, 0)
                    XCTAssertGreaterThanOrEqual(rect.minX, 0)
                    XCTAssertLessThanOrEqual(rect.maxX, width)
                }
                let helpRect = view.convert(view.helpLabel.bounds, from: view.helpLabel)
                let statusRect = view.convert(view.statusLabel.bounds, from: view.statusLabel)
                XCTAssertFalse(helpRect.intersects(statusRect))
                XCTAssertGreaterThan(view.fittingSize.height, 0)
                apply(view, canEnable: true, status: .off)
                XCTAssertTrue(view.retryButton.isHidden)
                XCTAssertTrue(view.recoverButton.isHidden)
                XCTAssertFalse(view.retryButton.isEnabled)
                XCTAssertFalse(view.recoverButton.isEnabled)
            }
        }
    }

    private func makeView(language: InterfaceLanguage = .english) -> LaunchActivitySettingsView {
        LaunchActivitySettingsView(frame: NSRect(x: 0, y: 0, width: 500, height: 700),
                                   strings: LocalizedStrings(language: language))
    }

    private func apply(_ view: LaunchActivitySettingsView, enabled: Bool = false, canEnable: Bool = false,
                       busy: Bool = false, canClear: Bool = false, status: LaunchActivityTextKey = .off,
                       canRetry: Bool = false, canRecover: Bool = false) {
        view.applyState(.init(enabled: enabled, canEnable: canEnable, isBusy: busy, canClear: canClear,
                              status: status, canRetry: canRetry, canRecover: canRecover))
    }

    private func assertStatus(_ key: LaunchActivityTextKey, in view: LaunchActivitySettingsView,
                              file: StaticString = #filePath, line: UInt = #line) {
        let text = view.strings.launchActivityText(key)
        XCTAssertEqual(view.statusLabel.stringValue, text, file: file, line: line)
        XCTAssertEqual(view.statusLabel.accessibilityLabel(), text, file: file, line: line)
        XCTAssertFalse(view.statusLabel.isHidden, file: file, line: line)
    }

    private func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { descendants($0) }
    }
    func testPrivacyDisableRemainsAvailableWhenLibraryOrPersistenceIsUnavailable() {
        let view = makeView()
        var requested: Bool?
        view.onSetEnabled = { requested = $0 }
        apply(view, enabled: true, canEnable: false, busy: true, status: .protected)
        XCTAssertTrue(view.enabledCheckbox.isEnabled)
        view.enabledCheckbox.state = .off
        view.enabledChanged(nil)
        XCTAssertEqual(requested, false)
    }

}
