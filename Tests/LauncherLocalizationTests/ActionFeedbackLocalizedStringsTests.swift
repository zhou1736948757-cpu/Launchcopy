import XCTest
import LauncherLocalization

final class ActionFeedbackLocalizedStringsTests: XCTestCase {
    func testActualFeedbackKeysAndSelectedLanguageTablesMatchExactly() throws {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            let table = try LocalizationTestResources.table(language)
            for key in ActionFeedbackTextKey.allCases {
                XCTAssertEqual(strings.actionFeedbackText(key), table[key.rawValue])
                XCTAssertNotEqual(strings.actionFeedbackText(key), key.rawValue)
                XCTAssertFalse(strings.actionFeedbackText(key).contains("{path}"))
            }
        }
        XCTAssertTrue(LocalizedStrings.validateResources().isValid)
    }
    func testMissingAllFeedbackResourcesUsesSafeKeySpecificEnglish() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language, resourceProvider: FixtureLocalizationResources(tables: [:]))
            for key in ActionFeedbackTextKey.allCases { XCTAssertEqual(strings.actionFeedbackText(key), key.englishFallback) }
        }
    }
}
