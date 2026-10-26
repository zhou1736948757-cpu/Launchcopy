import Foundation
import LauncherLocalization
import XCTest

/// Resource and value tests only: no AppGridUI, app processes or production storage.
final class AppLibraryLocalizationTests: XCTestCase {
    func testTypedSchemaContainsAllNavigationDetailStateAndCategoryKeys() {
        let names = LibraryTextKey.allCases.map(\.rawValue)
        let coreNames = [
            "title", "back", "enable", "searchPlaceholder", "all", "empty", "noResults",
            "details", "originalName", "alias", "category", "automatic", "manualCategory",
            "bundleIdentifier", "location", "version", "build", "unknown", "open", "reveal",
            "saveCategory", "restoreAutomatic", "loadCorrupt", "loadFuture", "saveFailed",
            "saved", "pending", "unavailable", "recover", "automaticCategory", "loading"
        ].map { "library." + $0 }
        let expectedNames = coreNames + Self.categoryKeys.map(\.rawValue)
        XCTAssertEqual(Set(names), Set(expectedNames))
        XCTAssertEqual(names.count, expectedNames.count)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertEqual(Self.categoryKeys.count, 22)
        XCTAssertFalse(Self.categoryKeys.contains(.all), "All is a filter, never a stored category")
        let schema = LocalizedStrings.requiredResourceKeys
        XCTAssertEqual(schema.count, Set(schema).count)
        XCTAssertEqual(Set(schema.filter { $0.hasPrefix("library.") }), Set(names))
    }

    func testAllThreeShippedTablesContainNonemptyValuesWithoutFallback() throws {
        let tables = try Self.shippedTables()
        let provider = try LibraryTestResourceProvider(tables: tables)
        XCTAssertTrue(LocalizedStrings.validateResources(resourceProvider: provider).isValid)
        for language in InterfaceLanguage.allCases {
            let table = try XCTUnwrap(tables[language])
            XCTAssertEqual(Set(table.keys), Set(LocalizedStrings.requiredResourceKeys))
            let strings = LocalizedStrings(language: language, resourceProvider: provider)
            for key in LibraryTextKey.allCases {
                let value = try XCTUnwrap(table[key.rawValue], "\(language): \(key)")
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                XCTAssertNotEqual(value, key.rawValue)
                XCTAssertEqual(strings.libraryText(key), value, "Rendering must use the shipped value")
                if language == .english {
                    XCTAssertEqual(value, key.englishFallback)
                }
            }
        }
        XCTAssertEqual(tables[.english]?[LibraryTextKey.title.rawValue], "App Library")
        XCTAssertEqual(tables[.simplifiedChinese]?[LibraryTextKey.title.rawValue], "应用资料库")
        XCTAssertEqual(tables[.japanese]?[LibraryTextKey.title.rawValue], "アプリライブラリ")
    }

    func testAll22CategoryLabelsMatchTheApprovedFlatTaxonomy() throws {
        let tables = try Self.shippedTables()
        let labels: [InterfaceLanguage: [String]] = [
            .english: [
                "Business", "Developer Tools", "Education", "Entertainment", "Finance", "Games",
                "Graphics & Design", "Health & Fitness", "Lifestyle", "Medical", "Music",
                "News", "Photography", "Productivity", "Reference", "Social Networking",
                "Sports", "Travel", "Utilities", "Video", "Weather", "Other"
            ],
            .simplifiedChinese: [
                "商业", "开发者工具", "教育", "娱乐", "财务", "游戏", "图形与设计", "健康与健身",
                "生活", "医疗", "音乐", "新闻", "摄影", "效率", "参考", "社交", "体育", "旅行",
                "工具", "视频", "天气", "其他"
            ],
            .japanese: [
                "ビジネス", "開発者ツール", "教育", "エンターテインメント", "ファイナンス", "ゲーム",
                "グラフィック＆デザイン", "ヘルスケア／フィットネス", "ライフスタイル", "メディカル",
                "ミュージック", "ニュース", "写真", "仕事効率化", "辞書／辞典",
                "ソーシャルネットワーキング", "スポーツ", "旅行", "ユーティリティ", "ビデオ",
                "天気", "その他"
            ]
        ]
        for language in InterfaceLanguage.allCases {
            let table = try XCTUnwrap(tables[language])
            XCTAssertEqual(try Self.categoryKeys.map { try XCTUnwrap(table[$0.rawValue]) },
                           try XCTUnwrap(labels[language]))
        }
    }

    func testEveryMissingLibraryKeyIsStrictlyReportedEvenWhenRenderingFallsBack() throws {
        let shipped = try Self.shippedTables()
        for language in InterfaceLanguage.allCases {
            for key in LibraryTextKey.allCases {
                var tables = shipped
                tables[language]?.removeValue(forKey: key.rawValue)
                let provider = try LibraryTestResourceProvider(tables: tables)
                let report = LocalizedStrings.validateResources(resourceProvider: provider)
                XCTAssertFalse(report.isValid, "\(language): \(key)")
                XCTAssertEqual(report.issues.count, 1, "\(language): \(key)")
                let issue = try XCTUnwrap(report.issues.first)
                XCTAssertEqual(issue.language, language)
                XCTAssertEqual(issue.key, key.rawValue)
                XCTAssertEqual(issue.kind, .missingKey)
                let strings = LocalizedStrings(language: language, resourceProvider: provider)
                XCTAssertEqual(strings.libraryText(key), key.englishFallback)
            }
        }
    }

    func testMissingSelectedKeysPreferValidatedEnglishResourceOverBuiltInFallback() throws {
        let shipped = try Self.shippedTables()
        for language in [InterfaceLanguage.simplifiedChinese, .japanese] {
            var tables = shipped
            for key in LibraryTextKey.allCases {
                tables[language]?.removeValue(forKey: key.rawValue)
                tables[.english]?[key.rawValue] = "Validated English: " + key.englishFallback
            }
            let provider = try LibraryTestResourceProvider(tables: tables)
            let strings = LocalizedStrings(language: language, resourceProvider: provider)
            for key in LibraryTextKey.allCases {
                XCTAssertEqual(strings.libraryText(key), "Validated English: " + key.englishFallback)
            }
            XCTAssertFalse(LocalizedStrings.validateResources(resourceProvider: provider).isValid)
        }
    }

    func testMissingBothSelectedAndEnglishKeysUseSafeBuiltInFallbacks() throws {
        let shipped = try Self.shippedTables()
        for language in InterfaceLanguage.allCases {
            var tables = shipped
            for key in LibraryTextKey.allCases {
                tables[language]?.removeValue(forKey: key.rawValue)
                tables[.english]?.removeValue(forKey: key.rawValue)
            }
            let provider = try LibraryTestResourceProvider(tables: tables)
            let strings = LocalizedStrings(language: language, resourceProvider: provider)
            for key in LibraryTextKey.allCases {
                XCTAssertEqual(strings.libraryText(key), key.englishFallback)
                XCTAssertFalse(strings.libraryText(key).isEmpty)
                XCTAssertNotEqual(strings.libraryText(key), key.rawValue)
            }
            XCTAssertFalse(LocalizedStrings.validateResources(resourceProvider: provider).isValid)
        }
    }

    func testAbsentAndMalformedResourcesUseSafeEnglishForEveryKey() {
        let absent = LibraryTestResourceProvider(resources: [:])
        let malformed = LibraryTestResourceProvider(resources: Dictionary(
            uniqueKeysWithValues: InterfaceLanguage.allCases.map { ($0, Data("not a strings table".utf8)) }
        ))
        for provider in [absent, malformed] {
            XCTAssertFalse(LocalizedStrings.validateResources(resourceProvider: provider).isValid)
            for language in InterfaceLanguage.allCases {
                let strings = LocalizedStrings(language: language, resourceProvider: provider)
                for key in LibraryTextKey.allCases {
                    XCTAssertEqual(strings.libraryText(key), key.englishFallback)
                }
            }
        }
        XCTAssertEqual(LocalizedStrings.validateResources(resourceProvider: absent).issues.map(\.kind),
                       Array(repeating: .missingResource, count: InterfaceLanguage.allCases.count))
        XCTAssertEqual(LocalizedStrings.validateResources(resourceProvider: malformed).issues.map(\.kind),
                       Array(repeating: .invalidTable, count: InterfaceLanguage.allCases.count))
    }

    func testInvalidValuesAndUnexpectedPlaceholdersAreRejectedPerKey() throws {
        let shipped = try Self.shippedTables()
        for language in InterfaceLanguage.allCases {
            for key in [LibraryTextKey.title, .categoryOther] {
                let invalidValues: [(String, LocalizationResourceIssueKind)] = [
                    (" \n\t", .invalidValue), (key.rawValue, .invalidValue),
                    ("Invalid\u{0001}", .invalidValue), (String(repeating: "x", count: 4097), .invalidValue),
                    ("Unexpected {count}", .invalidPlaceholderSignature)
                ]
                for (value, expectedKind) in invalidValues {
                    var tables = shipped
                    tables[language]?[key.rawValue] = value
                    if language != .english {
                        tables[.english]?[key.rawValue] = "Validated English fallback"
                    }
                    let provider = try LibraryTestResourceProvider(tables: tables)
                    let report = LocalizedStrings.validateResources(resourceProvider: provider)
                    XCTAssertEqual(report.issues.count, 1)
                    let issue = try XCTUnwrap(report.issues.first)
                    XCTAssertEqual(issue.language, language)
                    XCTAssertEqual(issue.key, key.rawValue)
                    XCTAssertEqual(issue.kind, expectedKind)
                    let strings = LocalizedStrings(language: language, resourceProvider: provider)
                    XCTAssertEqual(strings.libraryText(key),
                                   language == .english ? key.englishFallback : "Validated English fallback")
                    // Invalid keys must not discard other valid selected-language entries.
                    XCTAssertEqual(strings.libraryText(.back), shipped[language]?[LibraryTextKey.back.rawValue])
                }
            }
        }
    }

    func testUnexpectedLibraryKeysFailStrictValidationWithoutLeakingUnknownKeys() throws {
        let shipped = try Self.shippedTables()
        for language in InterfaceLanguage.allCases {
            var tables = shipped
            tables[language]?["library.unapprovedCategory"] = "Unapproved label"
            let provider = try LibraryTestResourceProvider(tables: tables)
            let report = LocalizedStrings.validateResources(resourceProvider: provider)
            XCTAssertFalse(report.isValid)
            XCTAssertEqual(report.issues.count, 1)
            let issue = try XCTUnwrap(report.issues.first)
            XCTAssertEqual(issue.language, language)
            XCTAssertEqual(issue.kind, .unexpectedKeys)
            XCTAssertNil(issue.key)
            let strings = LocalizedStrings(language: language, resourceProvider: provider)
            XCTAssertEqual(strings.libraryText(.title), shipped[language]?[LibraryTextKey.title.rawValue])
        }
    }

    private static let categoryKeys: [LibraryTextKey] = [
        .categoryBusiness, .categoryDeveloperTools, .categoryEducation, .categoryEntertainment,
        .categoryFinance, .categoryGames, .categoryGraphicsDesign, .categoryHealthcareFitness,
        .categoryLifestyle, .categoryMedical, .categoryMusic, .categoryNews, .categoryPhotography,
        .categoryProductivity, .categoryReference, .categorySocialNetworking, .categorySports,
        .categoryTravel, .categoryUtilities, .categoryVideo, .categoryWeather, .categoryOther
    ]

    private static func shippedTables() throws -> [InterfaceLanguage: [String: String]] {
        let provider = BundleLocalizationResourceProvider()
        return try Dictionary(uniqueKeysWithValues: InterfaceLanguage.allCases.map { language in
            let data = try XCTUnwrap(provider.localizableStringsData(for: language))
            let propertyList = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            return (language, try XCTUnwrap(propertyList as? [String: String]))
        })
    }
}

private struct LibraryTestResourceProvider: LocalizationResourceProviding {
    let resources: [InterfaceLanguage: Data]

    init(resources: [InterfaceLanguage: Data]) {
        self.resources = resources
    }

    init(tables: [InterfaceLanguage: [String: String]]) throws {
        resources = try tables.mapValues {
            try PropertyListSerialization.data(fromPropertyList: $0, format: .xml, options: 0)
        }
    }

    func localizableStringsData(for language: InterfaceLanguage) -> Data? {
        resources[language]
    }
}

