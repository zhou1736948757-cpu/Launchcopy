import Foundation
import XCTest
import LauncherLocalization

final class InterfaceLanguageResolutionTests: XCTestCase {
    func testStableIdentifiersAndPreferenceOrder() throws {
        XCTAssertEqual(InterfaceLanguage.allCases.map(\.rawValue), ["en", "zh-Hans", "ja"])
        XCTAssertEqual(InterfaceLanguagePreference.allCases.map(\.rawValue), ["system", "zh-Hans", "en", "ja"])
        XCTAssertNil(InterfaceLanguage(rawValue: "zh-Hant"))
        XCTAssertNil(InterfaceLanguagePreference(rawValue: "EN"))
        for preference in InterfaceLanguagePreference.allCases {
            let data = try JSONEncoder().encode(preference)
            XCTAssertEqual(try JSONDecoder().decode(InterfaceLanguagePreference.self, from: data), preference)
        }
        for language in InterfaceLanguage.allCases {
            let data = try JSONEncoder().encode(language)
            XCTAssertEqual(try JSONDecoder().decode(InterfaceLanguage.self, from: data), language)
        }
        XCTAssertThrowsError(try JSONDecoder().decode(InterfaceLanguagePreference.self, from: Data("\"zh-Hant\"".utf8)))
    }

    func testApprovedSupportedTagTable() {
        let rows: [(String, InterfaceLanguage)] = [
            ("en-US", .english), ("en-GB", .english),
            ("ja", .japanese), ("ja-JP", .japanese),
            ("zh", .simplifiedChinese), ("zh-Hans", .simplifiedChinese),
            ("zh-CN", .simplifiedChinese), ("zh-SG", .simplifiedChinese),
            ("zh-Hans-TW", .simplifiedChinese), ("ZH_hans_CN", .simplifiedChinese)
        ]
        for (tag, expected) in rows {
            // A distinct second choice proves whether an English tag actually matched.
            let next = expected == .japanese ? "zh-Hans" : "ja"
            XCTAssertEqual(InterfaceLanguagePreference.system.resolve(preferredLanguages: [tag, next]), expected, tag)
        }
    }

    func testApprovedUnsupportedTagsContinueOrderedList() {
        for tag in ["zh-TW", "zh-HK", "zh-MO", "zh-Hant", "zh-Hant-CN", "zh-Latn", "zh-US", "unknown", "zh--CN"] {
            XCTAssertEqual(InterfaceLanguagePreference.system.resolve(preferredLanguages: [tag, "ja", "en"]), .japanese, tag)
        }
        XCTAssertEqual(InterfaceLanguagePreference.system.resolve(preferredLanguages: ["zh-Hant", "ja", "en"]), .japanese)
        XCTAssertEqual(InterfaceLanguagePreference.system.resolve(preferredLanguages: ["zh-TW", "en"]), .english)
        XCTAssertEqual(InterfaceLanguagePreference.system.resolve(preferredLanguages: []), .english)
        XCTAssertEqual(InterfaceLanguagePreference.system.resolve(preferredLanguages: ["fr-FR", "de-DE"]), .english)
    }

    func testOverridesIgnorePreferredLanguageIdentifiers() {
        let lists = [[], ["ja", "en"], ["zh-Hant", "zh-CN"], ["", "en--US"]]
        for tags in lists {
            XCTAssertEqual(InterfaceLanguagePreference.english.resolve(preferredLanguages: tags), .english)
            XCTAssertEqual(InterfaceLanguagePreference.simplifiedChinese.resolve(preferredLanguages: tags), .simplifiedChinese)
            XCTAssertEqual(InterfaceLanguagePreference.japanese.resolve(preferredLanguages: tags), .japanese)
        }
        XCTAssertEqual(InterfaceLanguagePreference.system.resolve(preferredLanguages: ["fr", "ja", "zh"]), .japanese)
        XCTAssertEqual(InterfaceLanguagePreference.system.resolve(preferredLanguages: ["en", "ja", "zh"]), .english)
        XCTAssertEqual(InterfaceLanguagePreference.system.resolve(preferredLanguages: ["zh-SG", "ja", "en"]), .simplifiedChinese)
    }

    func testCaseSeparatorsAndExplicitScripts() {
        let rows: [(String, InterfaceLanguage)] = [
            ("EN_us", .english), ("en-Latn-GB", .english),
            ("JA_jp", .japanese), ("ja-Jpan-JP", .japanese),
            ("zH_hAnS_tW", .simplifiedChinese), ("zh-Hans-HK", .simplifiedChinese),
            ("zh-Hans-MO", .simplifiedChinese), ("zh-Hans-US", .simplifiedChinese),
            ("zh-Hans-419", .simplifiedChinese)
        ]
        for (tag, expected) in rows {
            let next = expected == .japanese ? "en" : "ja"
            XCTAssertEqual(InterfaceLanguagePreference.system.resolve(preferredLanguages: [tag, next]), expected, tag)
        }
    }

    func testMalformedAndUnknownScriptTagsDoNotGuess() {
        let rejected = [
            "", " en", "en ", "en\n", "en--US", "en__US", "-en", "en-", "en_US_",
            "english", "enochian", "japanese", "zhong", "e-US", "eng-US",
            "en@US", "en.UTF-8", "en/US", "ｅｎ-US", "zh-CＮ", "en-😀",
            "en-Zzzz", "ja-Zzzz", "zh-Zzzz", "en-Hans", "ja-Latn",
            "zh-Hant-SG", "zh-419", "zh-GB", "zh-USA", "zh-CN-Hans",
            "en-US-US", "en-US-u", "en-US-x", "en-US-u-a", "en-US-u-ca-u-nu",
            "en-US-abc", "en-US-abcdefghi", "en-US-1996-1996", "en-US-x-abcdefghi",
            "en-\(String(repeating: "a", count: 256))"
        ]
        for tag in rejected {
            XCTAssertEqual(InterfaceLanguagePreference.system.resolve(preferredLanguages: [tag, "ja"]), .japanese, tag)
            XCTAssertEqual(InterfaceLanguagePreference.system.resolve(preferredLanguages: [tag, "zh-CN"]), .simplifiedChinese, tag)
        }
    }

    func testWellFormedVariantsAndExtensionsRemainOrdered() {
        for tag in ["en-US-1996", "en-Latn-US-u-ca-gregory", "en-US-u-nu-latn-x-local", "en-US-x-a"] {
            XCTAssertEqual(InterfaceLanguagePreference.system.resolve(preferredLanguages: [tag, "ja"]), .english, tag)
        }
        XCTAssertEqual(InterfaceLanguagePreference.system.resolve(preferredLanguages: ["ja-JP-u-ca-japanese", "en"]), .japanese)
        XCTAssertEqual(InterfaceLanguagePreference.system.resolve(preferredLanguages: ["zh-Hans-TW-u-nu-hanidec", "en"]), .simplifiedChinese)
        XCTAssertEqual(InterfaceLanguagePreference.system.resolve(preferredLanguages: ["zh-Hant-CN-u-ca-chinese", "ja"]), .japanese)
    }
}
