import XCTest
import LauncherLocalization
@testable import PagingPrototypeApp

@MainActor
final class ActivationServiceLanguageTests: XCTestCase {
    func testLoginStateUsesSnapshotAndPreservesNativeErrorData() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            let states: [(LaunchAtLoginStatus, ActivationStatusTextKey)] = [
                (.disabled, .activationLoginDisabled), (.enabled, .activationLoginEnabled),
                (.requiresApproval, .activationLoginApproval), (.unavailable, .activationLoginUnavailable)]
            for (state, key) in states { XCTAssertEqual(ActivationServicePresentation.loginStatus(state, strings: strings), strings.activationStatusText(key)) }
            let data = "Native detail {count} %s 日本語"
            XCTAssertEqual(ActivationServicePresentation.loginStatus(.failure(message: data), strings: strings),
                           strings.activationStatusText(.activationLoginFailure) + " (" + data + ")")
        }
    }

    func testValidationRetainsSemanticErrorsAcrossLanguages() {
        let errors: [ActivationDraftValidationError] = [.hotCornerMissingSelectedCorner, .shortcutMissingSpec, .shortcutMissingModifiers]
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            XCTAssertEqual(ActivationServicePresentation.validation(errors, strings: strings),
                           [.activationCornerRequired, .activationShortcutRequired, .activationModifierRequired].map { strings.activationStatusText($0) }.joined(separator: "\n"))
        }
    }

    func testReadinessDistinguishesAbsentAndReadyWithoutStartingBackend() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            XCTAssertEqual(ActivationSettingsFourFingerReadiness.text(from: nil, strings: strings), strings.activationStatusText(.activationGestureNotReady))
        }
    }
}
