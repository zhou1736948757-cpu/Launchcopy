import Foundation
import XCTest
import LauncherLocalization

final class ActivationGridLocalizedStringsTests: XCTestCase {
    func testActualThreeLanguageTablesContainEveryNewTypedEntry() throws {
        for language in InterfaceLanguage.allCases {
            let table = try LocalizationTestResources.table(language)
            let strings = LocalizedStrings(language: language)
            for key in ActivationTextKey.allCases { XCTAssertEqual(strings.activationText(key), table[key.rawValue]) }
            for key in ActivationStatusTextKey.allCases { XCTAssertEqual(strings.activationStatusText(key), table[key.rawValue]) }
            for key in GridTextKey.allCases { XCTAssertEqual(strings.gridText(key), table[key.rawValue]) }
        }
        XCTAssertTrue(LocalizedStrings.validateResources().isValid)
    }

    func testMissingAllResourcesUseSafeEnglishForEveryNewStaticKey() {
        let provider = FixtureLocalizationResources(tables: [:])
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language, resourceProvider: provider)
            for key in ActivationTextKey.allCases {
                XCTAssertEqual(strings.activationText(key), key.englishFallback)
                XCTAssertNotEqual(strings.activationText(key), key.rawValue)
            }
            for key in ActivationStatusTextKey.allCases { XCTAssertEqual(strings.activationStatusText(key), key.englishFallback) }
            for key in GridTextKey.allCases { XCTAssertEqual(strings.gridText(key), key.englishFallback) }
        }
    }

    func testTypedIntegerTemplatesPreserveValuesInAllLanguages() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            for value in [0, 1, 2, -1, Int.min, Int.max] {
                XCTAssertTrue(strings.folderHelp(value).contains(String(value)))
                XCTAssertTrue(strings.activationKeyCode(value).contains(String(value)))
                XCTAssertTrue(strings.activationFutureVersion(value).contains(String(value)))
                XCTAssertFalse(strings.folderHelp(value).contains("{count}"))
                XCTAssertFalse(strings.activationFutureVersion(value).contains("{version}"))
            }
        }
    }

    func testInvalidNewPlaceholderFallsBackToEnglishAndValidationRejectsIt() throws {
        for language in [InterfaceLanguage.simplifiedChinese, .japanese] {
            var table = try LocalizationTestResources.table(language)
            table["folderHelpOther"] = "Invalid {wrong}"
            table["activationFutureVersion"] = "Invalid {version} {version}"
            let provider = try LocalizationTestResources.provider(replacing: language, with: table)
            XCTAssertFalse(LocalizedStrings.validateResources(resourceProvider: provider).isValid)
            let strings = LocalizedStrings(language: language, resourceProvider: provider)
            XCTAssertEqual(strings.folderHelp(3), "Folder containing 3 items")
            XCTAssertTrue(strings.activationFutureVersion(4).contains("storage version 4"))
        }
    }
    func testEnglishFolderHelpUsesSingularAndOtherWithoutSystemLocale() {
        let strings = LocalizedStrings(language: .english)
        XCTAssertEqual(strings.folderHelp(1), "Folder containing 1 item")
        XCTAssertEqual(strings.folderHelp(0), "Folder containing 0 items")
        XCTAssertEqual(strings.folderHelp(2), "Folder containing 2 items")
    }

}
