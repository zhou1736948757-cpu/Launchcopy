import Foundation
import LauncherLocalization
import XCTest

final class LaunchActivityLocalizedStringsTests: XCTestCase {
    func testExhaustiveTypedKeysMatchRequiredResourcesAndDistinctNonemptyTranslations() throws {
        let cases = ["title", "enabled", "privacyHelp", "recent", "frequent", "emptyRecent", "emptyFrequent",
                     "off", "saving", "saved", "saveFailed", "unavailable", "protected", "recoveryRequired",
                     "recover", "clear", "clearTitle", "clearMessage", "clearConfirm", "cancel", "cleared",
                     "retry", "waiting", "libraryDisabled"]
        let names = cases.map { "launchActivity." + $0 }
        XCTAssertEqual(LaunchActivityTextKey.allCases.map(\.rawValue), names)
        XCTAssertEqual(Set(names).count, 24)
        XCTAssertEqual(LocalizedStrings.requiredResourceKeys.filter { $0.hasPrefix("launchActivity.") }, names)
        for key in LaunchActivityTextKey.allCases {
            var translations: Set<String> = []
            for language in InterfaceLanguage.allCases {
                let table = try LocalizationTestResources.table(language)
                let text = LocalizedStrings(language: language).launchActivityText(key)
                XCTAssertEqual(text, table[key.rawValue])
                XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                XCTAssertNotEqual(text, key.rawValue)
                if language == .english { XCTAssertEqual(text, key.englishFallback) }
                else { XCTAssertNotEqual(text, key.englishFallback, "Missing translation: \(key.rawValue)") }
                translations.insert(text)
            }
            XCTAssertEqual(translations.count, 3, "Each shipped translation must be distinct: \(key.rawValue)")
        }
        XCTAssertTrue(LocalizedStrings.validateResources().isValid)
    }

    func testPrivacyCopyExplainsAcceptanceLocalRetentionAndDisableWithoutErasure() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            let help = strings.launchActivityText(.privacyHelp)
            XCTAssertTrue(help.contains("Launchcopy"))
            XCTAssertTrue(help.contains("UTC"))
            switch language {
            case .english:
                for phrase in ["Off by default", "only app identities", "times/counts", "accepted by its launch executor",
                               "on this Mac", "30-day", "no monitoring", "no uploads",
                               "does not prove that an app opened or was used", "stops recording", "hides Recent and Frequent",
                               "without erasing retained data", "Clear History"] {
                    XCTAssertTrue(help.contains(phrase), phrase)
                }
                for key in [LaunchActivityTextKey.off, .libraryDisabled] {
                    let text = strings.launchActivityText(key)
                    XCTAssertTrue(text.contains("hidden"))
                    XCTAssertTrue(text.contains("Retained data is not erased"))
                    XCTAssertTrue(text.contains("Clear History"))
                }
            case .simplifiedChinese:
                for phrase in ["默认关闭", "仅记录", "启动执行器接受", "应用标识", "请求时间和次数", "仅存于本机",
                               "30 天", "不监控", "不上传", "不代表应用已打开或实际使用", "停止记录并隐藏",
                               "不会删除已保留的数据", "清除历史记录"] {
                    XCTAssertTrue(help.contains(phrase), phrase)
                }
                for key in [LaunchActivityTextKey.off, .libraryDisabled] {
                    let text = strings.launchActivityText(key)
                    XCTAssertTrue(text.contains("隐藏"))
                    XCTAssertTrue(text.contains("已保留的数据不会删除"))
                    XCTAssertTrue(text.contains("清除历史记录"))
                }
            case .japanese:
                for phrase in ["初期設定はオフ", "受け付けられたリクエスト", "識別情報、時刻、回数だけ", "このMac内だけ",
                               "30日間", "監視、アップロードは行いません", "使用されたことの証明ではありません",
                               "記録を停止", "非表示", "保持中のデータは削除しません", "履歴を消去"] {
                    XCTAssertTrue(help.contains(phrase), phrase)
                }
                for key in [LaunchActivityTextKey.off, .libraryDisabled] {
                    let text = strings.launchActivityText(key)
                    XCTAssertTrue(text.contains("非表示"))
                    XCTAssertTrue(text.contains("保持中のデータは削除しません"))
                    XCTAssertTrue(text.contains("履歴を消去"))
                }
            }
        }
    }

    func testClearConfirmationIsIrreversibleFeatureOnlyAndDoesNotEnableRecording() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            let message = strings.launchActivityText(.clearMessage)
            XCTAssertTrue(message.contains("Launchcopy"))
            XCTAssertNotEqual(strings.launchActivityText(.clearConfirm), strings.launchActivityText(.cancel))
            XCTAssertNotEqual(strings.launchActivityText(.clear), strings.launchActivityText(.clearConfirm))
            switch language {
            case .english:
                for phrase in ["Permanently delete only", "Recent and Frequent", "cannot be undone", "categories, aliases, hidden apps",
                               "app arrangement and other settings stay unchanged", "does not turn recording on"] {
                    XCTAssertTrue(message.contains(phrase), phrase)
                }
            case .simplifiedChinese:
                for phrase in ["范围仅限", "“最近”和“常用”", "无法撤销", "分类、别名、隐藏应用", "应用排列和其他设置均保持不变",
                               "不会开启记录功能"] {
                    XCTAssertTrue(message.contains(phrase), phrase)
                }
            case .japanese:
                for phrase in ["記録だけを完全に削除", "取り消せません", "カテゴリ、別名、非表示のアプリ", "アプリの配置、その他の設定は変わりません",
                               "記録はオンになりません"] {
                    XCTAssertTrue(message.contains(phrase), phrase)
                }
            }
        }
    }

    func testSaveFailureProtectionAndRecoveryUseDistinctStaticFeedback() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            let keys: [LaunchActivityTextKey] = [.off, .saving, .saved, .saveFailed, .unavailable,
                                                .protected, .recoveryRequired, .cleared, .waiting, .libraryDisabled]
            XCTAssertEqual(Set(keys.map { strings.launchActivityText($0) }).count, keys.count)
            XCTAssertTrue(strings.launchActivityText(.saveFailed).contains(strings.launchActivityText(.retry)))
            XCTAssertTrue(strings.launchActivityText(.recoveryRequired).contains(strings.launchActivityText(.recover)))
        }
    }

    func testMissingSelectedKeysReportEachOmissionAndUseEnglish() throws {
        for language in InterfaceLanguage.allCases where language != .english {
            var table = try LocalizationTestResources.table(language)
            for key in LaunchActivityTextKey.allCases { table.removeValue(forKey: key.rawValue) }
            let provider = try LocalizationTestResources.provider(replacing: language, with: table)
            let issues = LocalizedStrings.validateResources(resourceProvider: provider).issues
            XCTAssertEqual(issues.count, LaunchActivityTextKey.allCases.count)
            XCTAssertEqual(Set(issues.compactMap(\.key)), Set(LaunchActivityTextKey.allCases.map(\.rawValue)))
            XCTAssertTrue(issues.allSatisfy { $0.language == language && $0.kind == .missingKey })
            let strings = LocalizedStrings(language: language, resourceProvider: provider)
            for key in LaunchActivityTextKey.allCases {
                XCTAssertEqual(strings.launchActivityText(key), key.englishFallback)
            }
        }
    }

    func testAbsentResourcesUseTypedEnglishFallbackInEveryLanguage() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language, resourceProvider: FixtureLocalizationResources(tables: [:]))
            for key in LaunchActivityTextKey.allCases {
                XCTAssertEqual(strings.launchActivityText(key), key.englishFallback)
            }
        }
    }

    func testEveryStaticKeyRejectsDynamicPlaceholderSignatures() throws {
        for language in InterfaceLanguage.allCases {
            for key in LaunchActivityTextKey.allCases {
                var table = try LocalizationTestResources.table(language)
                table[key.rawValue] = "Invalid {count}"
                let provider = try LocalizationTestResources.provider(replacing: language, with: table)
                let issues = LocalizedStrings.validateResources(resourceProvider: provider).issues
                XCTAssertEqual(issues.count, 1)
                XCTAssertEqual(issues.first?.language, language)
                XCTAssertEqual(issues.first?.key, key.rawValue)
                XCTAssertEqual(issues.first?.kind, .invalidPlaceholderSignature)
                XCTAssertEqual(LocalizedStrings(language: language, resourceProvider: provider).launchActivityText(key), key.englishFallback)
            }
        }
    }

    func testRenderingReadsOnlyTheImmutableSnapshot() throws {
        var tables: [String: Data] = [:]
        for language in InterfaceLanguage.allCases {
            tables[language.rawValue] = try LocalizationTestResources.encoded(LocalizationTestResources.table(language))
        }
        let provider = CountingLocalizationResources(fixture: FixtureLocalizationResources(tables: tables))
        let strings = LocalizedStrings(language: .japanese, resourceProvider: provider)
        let reads = provider.requestedLanguages
        for _ in 0..<10 {
            for key in LaunchActivityTextKey.allCases { _ = strings.launchActivityText(key) }
        }
        XCTAssertEqual(provider.requestedLanguages, reads)
    }
}
