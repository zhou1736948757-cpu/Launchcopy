import XCTest
import LauncherLocalization

final class ActivationOutwardHideLocalizedStringsTests: XCTestCase {
    private let keys: [ActivationTextKey] = [.fourFingerOutwardHideEnable, .fourFingerOutwardHideHelp]

    func testAllShippedLanguagesTranslateBothRequiredKeys() throws {
        for key in keys {
            var translations: Set<String> = []
            XCTAssertTrue(LocalizedStrings.requiredResourceKeys.contains(key.rawValue))
            for language in InterfaceLanguage.allCases {
                let expected = try XCTUnwrap(LocalizationTestResources.table(language)[key.rawValue])
                XCTAssertFalse(expected.isEmpty)
                XCTAssertEqual(LocalizedStrings(language: language).activationText(key), expected)
                translations.insert(expected)
            }
            XCTAssertEqual(translations.count, 3)
        }
    }

    func testMissingResourcesUseSafeEnglishFallback() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language,
                                           resourceProvider: FixtureLocalizationResources(tables: [:]))
            for key in keys {
                XCTAssertEqual(strings.activationText(key), key.englishFallback)
                XCTAssertNotEqual(strings.activationText(key), key.rawValue)
            }
        }
    }

    func testMissingSelectedTranslationUsesEnglishResource() throws {
        for language in [InterfaceLanguage.simplifiedChinese, .japanese] {
            var table = try LocalizationTestResources.table(language)
            keys.forEach { table.removeValue(forKey: $0.rawValue) }
            let strings = LocalizedStrings(language: language, resourceProvider:
                try LocalizationTestResources.provider(replacing: language, with: table))
            let english = try LocalizationTestResources.table(.english)
            for key in keys {
                XCTAssertEqual(strings.activationText(key), english[key.rawValue])
            }
        }
    }
}
