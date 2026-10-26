import Foundation
import XCTest
@testable import PagingPrototypeApp

final class IntegratedPreviewPolicyTests: XCTestCase {
    private func hostilePreferences(parent: Bool, child: Bool) -> ActivationPreferences {
        var settings = ActivationSettings()
        settings.hotCornerEnabled = true
        settings.selectedCorner = .topLeft
        settings.globalShortcutEnabled = true
        settings.shortcut = ShortcutSpec(keyCode: 49, modifiers: [.command, .shift])
        settings.launchAtLoginEnabled = true
        settings.showStatusItem = false
        return ActivationPreferences(fourFingerActivationEnabled: parent,
            fourFingerOutwardHideEnabled: child, settings: settings)
    }

    func testPreferencesClampGlobalsAndPreserveEveryParentChildChoice() {
        for parent in [false, true] {
            for child in [false, true] {
                let input = hostilePreferences(parent: parent, child: child)
                let safe = IntegratedPreviewPolicy.preferences(input)
                XCTAssertEqual(safe.settings, ActivationSettings())
                XCTAssertEqual(safe.fourFingerActivationEnabled, parent)
                XCTAssertEqual(safe.fourFingerOutwardHideEnabled, child)
                XCTAssertEqual(safe.schemaVersion, input.schemaVersion)
                XCTAssertEqual(IntegratedPreviewPolicy.preferences(safe), safe)
                XCTAssertTrue(input.settings.globalShortcutEnabled, "Normalization must not mutate its input")
                XCTAssertFalse(input.settings.showStatusItem)
            }
        }
    }

    func testDraftClampsHostileApplyChoicesAndMatchesPreferenceNormalization() {
        for parent in [false, true] {
            for child in [false, true] {
                let input = hostilePreferences(parent: parent, child: child)
                let draft = ActivationPreferencesDraft(committed: input)
                let safe = IntegratedPreviewPolicy.draft(draft)
                XCTAssertEqual(safe, ActivationPreferencesDraft(
                    fourFingerActivationEnabled: parent, fourFingerOutwardHideEnabled: child))
                XCTAssertFalse(safe.globalShortcutEnabled)
                XCTAssertNil(safe.shortcut)
                XCTAssertFalse(safe.hotCornerEnabled)
                XCTAssertNil(safe.selectedCorner)
                XCTAssertFalse(safe.launchAtLoginEnabled)
                XCTAssertTrue(safe.showStatusItem)
                XCTAssertEqual(safe.makePreferences(), IntegratedPreviewPolicy.preferences(input))
                XCTAssertEqual(IntegratedPreviewPolicy.draft(safe), safe)
                XCTAssertTrue(draft.hotCornerEnabled, "Normalization must not mutate its input")
            }
        }
    }

    func testProductDefaultsKeepParentOnOptionalChildOffAndStatusMenuAvailable() {
        let preferences = IntegratedPreviewPolicy.preferences(ActivationPreferences())
        XCTAssertEqual(preferences, ActivationPreferences())
        XCTAssertTrue(preferences.fourFingerActivationEnabled)
        XCTAssertFalse(preferences.fourFingerOutwardHideEnabled)
        XCTAssertTrue(preferences.settings.showStatusItem)
        XCTAssertEqual(IntegratedPreviewPolicy.draft(ActivationPreferencesDraft()), ActivationPreferencesDraft())
    }
}
