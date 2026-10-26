import Foundation
import XCTest
import LauncherLocalization

final class LocalizedStringsTests: XCTestCase {
    func testRealResourcesSupplyEveryRequiredTextAndTypedTemplate() throws {
        for language in InterfaceLanguage.allCases {
            let table = try LocalizationTestResources.table(language)
            let strings = LocalizedStrings(language: language)
            XCTAssertEqual(strings.language, language)
            for key in LocalizedTextKey.allCases {
                XCTAssertEqual(strings.text(key), table[key.rawValue], key.rawValue)
                XCTAssertFalse(strings.text(key).isEmpty)
                XCTAssertNotEqual(strings.text(key), key.rawValue)
            }
            XCTAssertFalse(strings.page(2, total: 12).contains("{"))
            XCTAssertFalse(strings.languageFutureVersion(9).contains("{"))
        }
        XCTAssertEqual(LocalizedStrings(language: .english).text(.languageTitle), "Language")
        XCTAssertEqual(LocalizedStrings(language: .simplifiedChinese).text(.languageTitle), "语言")
        XCTAssertEqual(LocalizedStrings(language: .japanese).text(.languageTitle), "言語")
    }

    func testSelectedLanguageControlsPluralRulesDespiteOppositeSystemPreference() {
        let english = LocalizedStrings(language: InterfaceLanguagePreference.english.resolve(preferredLanguages: ["ja-JP"]))
        let chinese = LocalizedStrings(language: InterfaceLanguagePreference.simplifiedChinese.resolve(preferredLanguages: ["en-US"]))
        let japanese = LocalizedStrings(language: InterfaceLanguagePreference.japanese.resolve(preferredLanguages: ["en-US"]))
        for count in [0, 1, 2, 100, -1, Int.min, Int.max] {
            XCTAssertEqual(english.memberCount(count), count == 1 ? "\(count) item" : "\(count) items")
            XCTAssertEqual(chinese.memberCount(count), "\(count) 个项目")
            XCTAssertEqual(japanese.memberCount(count), "\(count) 項目")
        }
    }

    func testTypedPageAndVersionArgumentsPreserveLocalizedOrderAndIntBounds() {
        XCTAssertEqual(LocalizedStrings(language: .english).page(2, total: 10), "Page 2 of 10")
        XCTAssertEqual(LocalizedStrings(language: .simplifiedChinese).page(2, total: 10), "第 2 页，共 10 页")
        XCTAssertEqual(LocalizedStrings(language: .japanese).page(2, total: 10), "10 ページ中 2 ページ目")
        XCTAssertEqual(LocalizedStrings(language: .english).languageFutureVersion(8),
                       "Language settings use a newer version (8) and cannot be changed.")
        XCTAssertEqual(LocalizedStrings(language: .simplifiedChinese).languageFutureVersion(8),
                       "语言设置使用较新版本（8），暂时无法更改。")
        XCTAssertEqual(LocalizedStrings(language: .japanese).languageFutureVersion(8),
                       "言語設定は新しいバージョン（8）で保存されているため、変更できません。")
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            XCTAssertTrue(strings.page(Int.min, total: Int.max).contains(String(Int.min)))
            XCTAssertTrue(strings.page(Int.min, total: Int.max).contains(String(Int.max)))
            XCTAssertTrue(strings.languageFutureVersion(Int.max).contains(String(Int.max)))
        }
    }

    func testMissingSelectedEntryUsesActualEnglishResourceAndKeepsOtherTranslations() throws {
        var japanese = try LocalizationTestResources.table(.japanese)
        japanese.removeValue(forKey: "apply")
        let provider = try LocalizationTestResources.provider(replacing: .japanese, with: japanese)
        let strings = LocalizedStrings(language: .japanese, resourceProvider: provider)
        XCTAssertEqual(strings.text(.apply), "Apply")
        XCTAssertEqual(strings.text(.cancel), "キャンセル")
        XCTAssertEqual(strings.language, .japanese)
        var english = try LocalizationTestResources.table(.english)
        english["apply"] = "English resource sentinel"
        var tables = provider.tables
        tables["en"] = try LocalizationTestResources.encoded(english)
        XCTAssertEqual(LocalizedStrings(language: .japanese, resourceProvider: FixtureLocalizationResources(tables: tables)).text(.apply),
                       "English resource sentinel", "Fallback must read the actual English table before built-in safety values")
    }

    func testInvalidSelectedTemplatesFallBackIndividuallyWithoutInterpretingPrintf() throws {
        var japanese = try LocalizationTestResources.table(.japanese)
        japanese["page"] = "{page} / {total} / {privateName}"
        japanese["languageFutureVersion"] = "Version %@"
        japanese["memberCountOther"] = "{count} {count}"
        japanese["close"] = "close"
        japanese["cancel"] = "  \n"
        let strings = LocalizedStrings(language: .japanese,
                                       resourceProvider: try LocalizationTestResources.provider(replacing: .japanese, with: japanese))
        XCTAssertEqual(strings.page(3, total: 6), "Page 3 of 6")
        XCTAssertEqual(strings.languageFutureVersion(9), "Language settings use a newer version (9) and cannot be changed.")
        XCTAssertEqual(strings.memberCount(1), "1 item", "An English fallback uses English singular grammar")
        XCTAssertEqual(strings.memberCount(3), "3 items")
        XCTAssertEqual(strings.text(.close), "Close")
        XCTAssertEqual(strings.text(.cancel), "Cancel")
        XCTAssertEqual(strings.text(.apply), "適用")
    }

    func testAbsentAndInvalidTablesUseKeySpecificEnglishValuesWithoutRawKeys() {
        let providers = [
            FixtureLocalizationResources(tables: [:]),
            FixtureLocalizationResources(tables: ["en": Data("not a strings table".utf8), "ja": Data([0, 255])])
        ]
        let english = LocalizedStrings(language: .english)
        for provider in providers {
            for language in InterfaceLanguage.allCases {
                let strings = LocalizedStrings(language: language, resourceProvider: provider)
                for key in LocalizedTextKey.allCases {
                    XCTAssertEqual(strings.text(key), english.text(key))
                    XCTAssertNotEqual(strings.text(key), key.rawValue)
                }
                XCTAssertEqual(strings.page(1, total: 4), "Page 1 of 4")
                XCTAssertEqual(strings.memberCount(1), "1 item")
                XCTAssertEqual(strings.memberCount(0), "0 items")
                XCTAssertEqual(strings.languageFutureVersion(7), "Language settings use a newer version (7) and cannot be changed.")
            }
        }
    }

    func testResourceEscapesUnicodeAndPercentSignsAreLiteral() {
        let table = #"""
        "languageHelp" = "Choose \"Launchcopy\"\n日本語 😀 100% %@ %d";
        "page" = "{total} pages\tpage {page}, 100% %@";
        "memberCountOther" = "{count} 項目";
        """#
        let strings = LocalizedStrings(language: .japanese,
                                       resourceProvider: FixtureLocalizationResources(tables: ["ja": Data(table.utf8)]))
        XCTAssertEqual(strings.text(.languageHelp), "Choose \"Launchcopy\"\n日本語 😀 100% %@ %d")
        XCTAssertEqual(strings.page(2, total: 7), "7 pages\tpage 2, 100% %@")
    }

    func testLongValidResourceIsPreservedAndOversizedValueFallsBack() throws {
        var table = try LocalizationTestResources.table(.japanese)
        let longValue = String(repeating: "Readable text 😀 ", count: 100)
        table["languageHelp"] = longValue
        var strings = LocalizedStrings(language: .japanese,
                                       resourceProvider: try LocalizationTestResources.provider(replacing: .japanese, with: table))
        XCTAssertEqual(strings.text(.languageHelp), longValue)
        table["languageHelp"] = String(repeating: "a", count: 4097)
        strings = LocalizedStrings(language: .japanese,
                                   resourceProvider: try LocalizationTestResources.provider(replacing: .japanese, with: table))
        XCTAssertEqual(strings.text(.languageHelp), LocalizedStrings(language: .english).text(.languageHelp))
    }

    func testSnapshotDoesNotRetainProviderOrReadResourcesDuringRendering() throws {
        let fixture = try LocalizationTestResources.provider(replacing: .japanese,
                                                            with: LocalizationTestResources.table(.japanese))
        var provider: CountingLocalizationResources? = CountingLocalizationResources(fixture: fixture)
        weak var releasedProvider: CountingLocalizationResources?
        releasedProvider = provider
        let strings = LocalizedStrings(language: .japanese, resourceProvider: try XCTUnwrap(provider))
        XCTAssertEqual(provider?.requestedLanguages, ["ja", "en"])
        for _ in 0..<20 {
            for key in LocalizedTextKey.allCases { _ = strings.text(key) }
            for key in SettingsTextKey.allCases { _ = strings.settingsText(key) }
            _ = strings.hiddenReferenceCount(1)
            _ = strings.hiddenReferenceCount(20)
            _ = strings.page(2, total: 5)
            _ = strings.memberCount(1)
            _ = strings.languageFutureVersion(8)
        }
        XCTAssertEqual(provider?.requestedLanguages, ["ja", "en"], "Rendering must use only the immutable snapshot")
        provider = nil
        XCTAssertNil(releasedProvider, "The snapshot must not retain its IO provider")
        XCTAssertEqual(strings.text(.apply), "適用")
    }

    func testEnglishSnapshotReadsOnlyOneTable() throws {
        let provider = CountingLocalizationResources(fixture: FixtureLocalizationResources(
            tables: ["en": try LocalizationTestResources.encoded(LocalizationTestResources.table(.english))]
        ))
        let strings = LocalizedStrings(language: .english, resourceProvider: provider)
        XCTAssertEqual(strings.memberCount(1), "1 item")
        XCTAssertEqual(provider.requestedLanguages, ["en"])
    }

    func testBrokenSelectedAndEnglishEntriesReachSpecificSafetyValues() throws {
        var english = try LocalizationTestResources.table(.english)
        var japanese = try LocalizationTestResources.table(.japanese)
        for key in ["apply", "page", "memberCountOne", "memberCountOther", "languageFutureVersion"] {
            english[key] = "{unvalidated}"
            japanese[key] = "{unvalidated}"
        }
        let provider = FixtureLocalizationResources(tables: [
            "en": try LocalizationTestResources.encoded(english),
            "ja": try LocalizationTestResources.encoded(japanese)
        ])
        let strings = LocalizedStrings(language: .japanese, resourceProvider: provider)
        XCTAssertEqual(strings.text(.apply), "Apply")
        XCTAssertEqual(strings.page(1, total: 8), "Page 1 of 8")
        XCTAssertEqual(strings.memberCount(1), "1 item")
        XCTAssertEqual(strings.memberCount(2), "2 items")
        XCTAssertEqual(strings.languageFutureVersion(9), "Language settings use a newer version (9) and cannot be changed.")
        XCTAssertEqual(strings.text(.cancel), "キャンセル")
    }
}
