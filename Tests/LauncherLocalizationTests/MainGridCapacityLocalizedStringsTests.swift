import Foundation
import LauncherLocalization
import XCTest

final class MainGridCapacityLocalizedStringsTests: XCTestCase {
    func testTypedKeysHaveExactRequiredCoverageAndDistinctShippedTranslations() throws {
        let cases = ["title", "columns", "rows", "itemsPerPage", "apply", "restoreDefaults", "help",
                     "loadCorrupt", "loadProtected", "unavailable", "invalidDraft", "draftDefaults",
                     "saving", "savedQueued", "applied", "presentationUnavailable", "saveFailed",
                     "recoveryRequired", "insufficientSpace"]
        let names = cases.map { "mainGridCapacity." + $0 }
        XCTAssertEqual(MainGridCapacityTextKey.allCases.map(\.rawValue), names)
        XCTAssertEqual(Set(names).count, 19)
        XCTAssertTrue(Set(names).isSubset(of: Set(LocalizedStrings.requiredResourceKeys)))
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            let table = try LocalizationTestResources.table(language)
            for key in MainGridCapacityTextKey.allCases {
                let text = strings.mainGridCapacityText(key)
                XCTAssertEqual(text, table[key.rawValue])
                XCTAssertFalse(text.isEmpty)
                XCTAssertNotEqual(text, key.rawValue)
                if language == .english { XCTAssertEqual(text, key.englishFallback) }
                else { XCTAssertNotEqual(text, key.englishFallback, "Missing translation: \(key.rawValue)") }
            }
        }
    }

    func testMissingSelectedKeysUseEnglishAndStrictValidationStillReportsEachOmission() throws {
        var japanese = try LocalizationTestResources.table(.japanese)
        for key in MainGridCapacityTextKey.allCases { japanese.removeValue(forKey: key.rawValue) }
        let provider = try LocalizationTestResources.provider(replacing: .japanese, with: japanese)
        let strings = LocalizedStrings(language: .japanese, resourceProvider: provider)
        let issues = LocalizedStrings.validateResources(resourceProvider: provider).issues
        XCTAssertEqual(issues.count, MainGridCapacityTextKey.allCases.count)
        XCTAssertEqual(Set(issues.compactMap(\.key)), Set(MainGridCapacityTextKey.allCases.map(\.rawValue)))
        XCTAssertTrue(issues.allSatisfy { $0.language == .japanese && $0.kind == .missingKey })
        for key in MainGridCapacityTextKey.allCases {
            XCTAssertEqual(strings.mainGridCapacityText(key), key.englishFallback)
        }
    }

    func testAbsentAllResourcesUsesSafeTypedFallbackIncludingProtectiveNotice() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language,
                                           resourceProvider: FixtureLocalizationResources(tables: [:]))
            for key in MainGridCapacityTextKey.allCases {
                XCTAssertEqual(strings.mainGridCapacityText(key), key.englishFallback)
            }
            XCTAssertTrue(strings.mainGridCapacityText(.insufficientSpace).contains("Settings"))
        }
    }

    func testEveryNewStaticKeyRejectsUnexpectedPlaceholdersAndFallsBackToEnglish() throws {
        for key in MainGridCapacityTextKey.allCases {
            var japanese = try LocalizationTestResources.table(.japanese)
            japanese[key.rawValue] = "Invalid {count}"
            let provider = try LocalizationTestResources.provider(replacing: .japanese, with: japanese)
            let issues = LocalizedStrings.validateResources(resourceProvider: provider).issues
            XCTAssertEqual(issues.count, 1)
            XCTAssertEqual(issues.first?.key, key.rawValue)
            XCTAssertEqual(issues.first?.kind, .invalidPlaceholderSignature)
            XCTAssertEqual(LocalizedStrings(language: .japanese, resourceProvider: provider)
                .mainGridCapacityText(key), key.englishFallback)
        }
    }

    func testCapacityTextRendersFromSnapshotWithoutFurtherResourceReads() throws {
        var tables: [String: Data] = [:]
        for language in InterfaceLanguage.allCases {
            tables[language.rawValue] = try LocalizationTestResources.encoded(LocalizationTestResources.table(language))
        }
        let provider = CountingLocalizationResources(fixture: FixtureLocalizationResources(tables: tables))
        let strings = LocalizedStrings(language: .japanese, resourceProvider: provider)
        let reads = provider.requestedLanguages
        for _ in 0..<10 {
            for key in MainGridCapacityTextKey.allCases { _ = strings.mainGridCapacityText(key) }
        }
        XCTAssertEqual(provider.requestedLanguages, reads)
    }
}
