import Foundation
import LauncherLocalization
import XCTest

final class AppRemovalLocalizedStringsTests: XCTestCase {
    // Independent of the production enum so an omitted case cannot hide a missing key.
    private let expectedKeys = [
        "appRemoval.moveToTrash", "appRemoval.confirmTitle", "appRemoval.confirmMessage",
        "appRemoval.cancel", "appRemoval.confirmMove", "appRemoval.inspecting",
        "appRemoval.moving", "appRemoval.moved", "appRemoval.unavailable",
        "appRemoval.running", "appRemoval.failed", "appRemoval.changed",
        "appRemoval.quitTitle", "appRemoval.quitMessage"
    ]

    func testAllCasesMatchIndependentContractAndThreeStaticTranslations() throws {
        XCTAssertEqual(AppRemovalTextKey.allCases.map(\.rawValue), expectedKeys)
        XCTAssertEqual(Set(expectedKeys).count, 14)
        XCTAssertEqual(LocalizedStrings.requiredResourceKeys.count, 369)
        XCTAssertEqual(LocalizedStrings.requiredResourceKeys.filter { $0.hasPrefix("appRemoval.") }, expectedKeys)
        for key in AppRemovalTextKey.allCases {
            var translations: Set<String> = []
            for language in InterfaceLanguage.allCases {
                let table = try LocalizationTestResources.table(language)
                let text = LocalizedStrings(language: language).removalText(key)
                XCTAssertEqual(text, table[key.rawValue])
                XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                XCTAssertNotEqual(text, key.rawValue)
                for marker in ["{", "}", "%"] {
                    XCTAssertFalse(text.contains(marker), "Static signature: \(language.rawValue):\(key.rawValue)")
                }
                if language == .english { XCTAssertEqual(text, key.englishFallback) }
                else { XCTAssertNotEqual(text, key.englishFallback) }
                translations.insert(text)
            }
            XCTAssertEqual(translations.count, 3, key.rawValue)
        }
        XCTAssertTrue(LocalizedStrings.validateResources().isValid)
    }

    func testConfirmationStatesSelectedBundleScopeRecoveryAndDefaultCancel() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            let message = strings.removalText(.confirmMessage)
            XCTAssertTrue(message.contains("macOS"))
            XCTAssertTrue(message.contains("Finder"))
            XCTAssertTrue(message.contains(strings.removalText(.cancel)))
            XCTAssertNotEqual(strings.removalText(.confirmMove), strings.removalText(.cancel))
            XCTAssertNotEqual(strings.removalText(.moveToTrash), strings.removalText(.confirmMove))
            let phrases: [String]
            switch language {
            case .english:
                phrases = ["only the selected app bundle", "Support files and preferences are not removed",
                           "not a complete uninstall", "recover the app using Finder", "Cancel is selected by default"]
            case .simplifiedChinese:
                phrases = ["仅将所选应用包", "不会删除支持文件和偏好设置", "不是完整卸载", "使用 Finder 恢复", "默认选中“取消”"]
            case .japanese:
                phrases = ["選択したアプリのバンドルだけ", "サポートファイルや環境設定は削除しない",
                           "完全なアンインストールではありません", "Finderからアプリを元に戻せます", "初期選択は「キャンセル」"]
            }
            for phrase in phrases { XCTAssertTrue(message.contains(phrase), phrase) }
            XCTAssertTrue(strings.removalText(.moved).contains("Finder"))
        }
    }

    func testRunningRefusalAndUnresolvedQuitRemainSeparateFromSaveFailure() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            let running = strings.removalText(.running)
            let quit = strings.removalText(.quitMessage)
            XCTAssertTrue(running.contains("Launchcopy"))
            XCTAssertTrue(quit.contains("Finder"))
            XCTAssertTrue(quit.contains(strings.noticeText(.cancelQuit)))
            XCTAssertNotEqual(strings.removalText(.quitTitle), strings.noticeText(.quitSaveTitle))
            XCTAssertNotEqual(quit, strings.noticeText(.quitSaveMessage))
            let states: [AppRemovalTextKey] = [.inspecting, .moving, .moved, .unavailable, .running, .failed, .changed]
            XCTAssertEqual(Set(states.map { strings.removalText($0) }).count, states.count)
            let runningPhrases: [String]
            let quitPhrases: [String]
            switch language {
            case .english:
                runningPhrases = ["is running", "Quit it yourself", "will not force quit"]
                quitPhrases = ["has failed", "still unknown", "Cancel Quit is selected by default",
                               "does not cancel or undo an accepted operation"]
            case .simplifiedChinese:
                runningPhrases = ["正在运行", "请自行退出", "不会强制退出"]
                quitPhrases = ["已失败", "结果仍未知", "默认选中“取消退出”", "不会取消或撤销已接受的操作"]
            case .japanese:
                runningPhrases = ["実行中", "ご自身でアプリを終了", "強制終了することはありません"]
                quitPhrases = ["失敗", "結果がまだ不明", "初期選択は「終了をキャンセル」",
                               "受け付け済みの操作はキャンセルも取り消しもされません"]
            }
            for phrase in runningPhrases { XCTAssertTrue(running.contains(phrase), phrase) }
            for phrase in quitPhrases { XCTAssertTrue(quit.contains(phrase), phrase) }
        }
    }

    func testMissingSelectedKeysReportEveryOmissionAndUseEnglishResourceBeforeFallback() throws {
        for language in InterfaceLanguage.allCases where language != .english {
            var tables: [String: Data] = [:]
            for candidate in InterfaceLanguage.allCases {
                var table = try LocalizationTestResources.table(candidate)
                for key in expectedKeys {
                    if candidate == language { table.removeValue(forKey: key) }
                    if candidate == .english { table[key] = "English resource for " + key }
                }
                tables[candidate.rawValue] = try LocalizationTestResources.encoded(table)
            }
            let provider = FixtureLocalizationResources(tables: tables)
            let issues = LocalizedStrings.validateResources(resourceProvider: provider).issues
            XCTAssertEqual(issues.count, 14)
            XCTAssertEqual(Set(issues.compactMap(\.key)), Set(expectedKeys))
            XCTAssertTrue(issues.allSatisfy { $0.language == language && $0.kind == .missingKey })
            let strings = LocalizedStrings(language: language, resourceProvider: provider)
            for key in AppRemovalTextKey.allCases {
                XCTAssertEqual(strings.removalText(key), "English resource for " + key.rawValue)
            }
        }
    }

    func testAbsentResourcesUseTypedEnglishFallbackForEveryCaseAndLanguage() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language, resourceProvider: FixtureLocalizationResources(tables: [:]))
            for key in AppRemovalTextKey.allCases {
                XCTAssertEqual(strings.removalText(key), key.englishFallback)
            }
        }
    }

    func testEveryRemovalKeyRejectsDynamicSignaturesInEveryLanguage() throws {
        for language in InterfaceLanguage.allCases {
            var table = try LocalizationTestResources.table(language)
            for key in expectedKeys { table[key] = "Invalid {appName} {path} {count}" }
            let provider = try LocalizationTestResources.provider(replacing: language, with: table)
            let issues = LocalizedStrings.validateResources(resourceProvider: provider).issues
            XCTAssertEqual(issues.count, 14)
            XCTAssertEqual(Set(issues.compactMap(\.key)), Set(expectedKeys))
            XCTAssertTrue(issues.allSatisfy { $0.language == language && $0.kind == .invalidPlaceholderSignature })
            let strings = LocalizedStrings(language: language, resourceProvider: provider)
            for key in AppRemovalTextKey.allCases {
                XCTAssertEqual(strings.removalText(key), key.englishFallback)
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
            for key in AppRemovalTextKey.allCases { _ = strings.removalText(key) }
        }
        XCTAssertEqual(provider.requestedLanguages, reads)
    }
}
