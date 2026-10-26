import Foundation
import XCTest
import LauncherLocalization

final class StatusMenuNoticeLocalizedStringsTests: XCTestCase {
    private let editKeys: [MenuTextKey] = [.edit, .undo, .redo, .cut, .copy, .paste, .selectAll]

    func testNativeEditMenuHasExactLocalizedLabelsAndEnglishSafetyValues() {
        let english = ["Edit", "Undo", "Redo", "Cut", "Copy", "Paste", "Select All"]
        let expected: [(InterfaceLanguage, [String])] = [
            (.english, english),
            (.simplifiedChinese, ["编辑", "撤销", "重做", "剪切", "复制", "粘贴", "全选"]),
            (.japanese, ["編集", "取り消す", "やり直す", "カット", "コピー", "ペースト", "すべてを選択"])
        ]
        XCTAssertEqual(editKeys.map(\.englishFallback), english)
        for (language, labels) in expected {
            let strings = LocalizedStrings(language: language)
            XCTAssertEqual(editKeys.map { strings.menuText($0) }, labels, language.rawValue)
        }
    }

    func testEachMissingEditEntryFallsBackToActualEnglishResourceWithoutChangingOtherLabels() throws {
        var english = try LocalizationTestResources.table(.english)
        for key in editKeys {
            english[key.rawValue] = "English resource for \(key.rawValue)"
        }
        for language in [InterfaceLanguage.simplifiedChinese, .japanese] {
            let intact = try LocalizationTestResources.table(language)
            for key in editKeys {
                var table = intact
                table.removeValue(forKey: key.rawValue)
                var tables = try LocalizationTestResources.provider(replacing: language, with: table).tables
                tables["en"] = try LocalizationTestResources.encoded(english)
                let provider = FixtureLocalizationResources(tables: tables)
                let issues = LocalizedStrings.validateResources(resourceProvider: provider).issues
                XCTAssertEqual(issues.count, 1)
                XCTAssertEqual(issues.first?.language, language)
                XCTAssertEqual(issues.first?.key, key.rawValue)
                XCTAssertEqual(issues.first?.kind, .missingKey)
                let strings = LocalizedStrings(language: language, resourceProvider: provider)
                XCTAssertEqual(strings.menuText(key), english[key.rawValue])
                XCTAssertEqual(strings.language, language)
                for remaining in MenuTextKey.allCases where remaining != key {
                    XCTAssertEqual(strings.menuText(remaining), intact[remaining.rawValue])
                }

                var missingEnglishTable = english
                missingEnglishTable.removeValue(forKey: key.rawValue)
                tables["en"] = try LocalizationTestResources.encoded(missingEnglishTable)
                let missingEnglish = FixtureLocalizationResources(tables: tables)
                XCTAssertEqual(LocalizedStrings(language: language, resourceProvider: missingEnglish).menuText(key),
                               key.englishFallback)
            }
        }
    }

    func testEveryEditEntryRejectsInvalidValuesAndArgumentsWithoutWeakeningValidation() throws {
        for language in InterfaceLanguage.allCases {
            let intact = try LocalizationTestResources.table(language)
            for key in editKeys {
                let invalid: [(String, LocalizationResourceIssueKind)] = [
                    ("", .invalidValue), (" \n\t", .invalidValue), (key.rawValue, .invalidValue),
                    ("\u{0000}", .invalidValue), (String(repeating: "a", count: 4097), .invalidValue),
                    ("Unexpected {count}", .invalidPlaceholderSignature)
                ]
                for (value, kind) in invalid {
                    var table = intact
                    table[key.rawValue] = value
                    let provider = try LocalizationTestResources.provider(replacing: language, with: table)
                    let issues = LocalizedStrings.validateResources(resourceProvider: provider).issues
                    XCTAssertEqual(issues.count, 1)
                    XCTAssertEqual(issues.first?.language, language)
                    XCTAssertEqual(issues.first?.key, key.rawValue)
                    XCTAssertEqual(issues.first?.kind, kind)
                    let strings = LocalizedStrings(language: language, resourceProvider: provider)
                    XCTAssertEqual(strings.menuText(key), key.englishFallback)
                    for remaining in MenuTextKey.allCases where remaining != key {
                        XCTAssertEqual(strings.menuText(remaining), intact[remaining.rawValue])
                    }
                    if language != .english {
                        var english = try LocalizationTestResources.table(.english)
                        english[key.rawValue] = value
                        var tables = provider.tables
                        tables["en"] = try LocalizationTestResources.encoded(english)
                        let invalidEnglish = FixtureLocalizationResources(tables: tables)
                        XCTAssertEqual(LocalizedStrings(language: language, resourceProvider: invalidEnglish).menuText(key),
                                       key.englishFallback)
                    }
                }
            }
        }
    }

    func testEveryActualNewStaticEntryUsesItsSelectedTable() throws {
        for language in InterfaceLanguage.allCases {
            let table = try LocalizationTestResources.table(language)
            let strings = LocalizedStrings(language: language)
            for key in MenuTextKey.allCases { XCTAssertEqual(strings.menuText(key), table[key.rawValue]) }
            for key in CatalogTextKey.allCases { XCTAssertEqual(strings.catalogText(key), table[key.rawValue]) }
            for key in NoticeTextKey.allCases { XCTAssertEqual(strings.noticeText(key), table[key.rawValue]) }
        }
        XCTAssertTrue(LocalizedStrings.validateResources().isValid)
    }

    func testMissingOrInvalidNewResourcesNeverExposeRawKeys() {
        let providers = [
            FixtureLocalizationResources(tables: [:]),
            FixtureLocalizationResources(tables: ["en": Data("invalid table".utf8),
                                                  "zh-Hans": Data([0, 255]), "ja": Data([0, 255])])
        ]
        for provider in providers {
            for language in InterfaceLanguage.allCases {
                let strings = LocalizedStrings(language: language, resourceProvider: provider)
                for key in MenuTextKey.allCases { XCTAssertEqual(strings.menuText(key), key.englishFallback) }
                for key in CatalogTextKey.allCases { XCTAssertEqual(strings.catalogText(key), key.englishFallback) }
                for key in NoticeTextKey.allCases { XCTAssertEqual(strings.noticeText(key), key.englishFallback) }
            }
        }
    }
}
