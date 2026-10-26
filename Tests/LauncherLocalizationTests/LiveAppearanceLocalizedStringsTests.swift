import Foundation
import LauncherLocalization
import XCTest

final class LiveAppearanceLocalizedStringsTests: XCTestCase {
    func testTypedKeysHaveExactRequiredCoverageAndDistinctShippedTranslations() throws {
        let cases = ["help", "gridHelp", "saving", "saved", "saveFailed", "retry", "recover",
                     "defaults", "defaultsApplied", "queued", "unavailable", "protected", "recoveryRequired", "recoveryFailed"]
        let names = cases.map { "liveAppearance." + $0 }
        XCTAssertEqual(LiveAppearanceTextKey.allCases.map(\.rawValue), names)
        XCTAssertEqual(Set(names).count, 14)
        XCTAssertEqual(LocalizedStrings.requiredResourceKeys.filter { $0.hasPrefix("liveAppearance.") }, names)
        for key in LiveAppearanceTextKey.allCases {
            var translations: Set<String> = []
            for language in InterfaceLanguage.allCases {
                let strings = LocalizedStrings(language: language)
                let table = try LocalizationTestResources.table(language)
                let text = strings.liveAppearanceText(key)
                XCTAssertEqual(text, table[key.rawValue])
                XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                XCTAssertNotEqual(text, key.rawValue)
                if language == .english { XCTAssertEqual(text, key.englishFallback) }
                else { XCTAssertNotEqual(text, key.englishFallback, "Missing translation: \(key.rawValue)") }
                translations.insert(text)
            }
            XCTAssertEqual(translations.count, 3, "Translations must be distinct: \(key.rawValue)")
        }
        XCTAssertTrue(LocalizedStrings.validateResources().isValid)
    }

    func testLiveCopyHasNoApplyOrDiscardDraftInstructions() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            for key in LiveAppearanceTextKey.allCases {
                let text = strings.liveAppearanceText(key).lowercased()
                for obsolete in ["apply", "draft", "点击应用", "草稿", "適用", "下書き",
                                 "closing settings discards", "closing discards",
                                 "关闭设置会丢弃", "閉じると未保存"] {
                    XCTAssertFalse(text.contains(obsolete), "\(language.rawValue):\(key.rawValue):\(obsolete)")
                }
                XCTAssertFalse(text.contains("fsync"))
            }
            for key in [LiveAppearanceTextKey.help, .gridHelp] {
                let help = strings.liveAppearanceText(key)
                switch language {
                case .english:
                    XCTAssertTrue(help.contains("as you edit"))
                    XCTAssertTrue(help.contains("save automatically"))
                    XCTAssertTrue(help.contains("Closing settings does not discard changes."))
                case .simplifiedChinese:
                    XCTAssertTrue(help.contains("实时"))
                    XCTAssertTrue(help.contains("自动保存"))
                    XCTAssertTrue(help.contains("关闭设置不会丢弃修改。"))
                case .japanese:
                    XCTAssertTrue(help.contains("編集中"))
                    XCTAssertTrue(help.contains("自動で保存"))
                    XCTAssertTrue(help.contains("設定を閉じても変更は破棄されません。"))
                }
            }
        }
    }

    func testSavePresentationDefaultsAndRecoveryRemainSeparate() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            let retry = strings.liveAppearanceText(.retry)
            let recover = strings.liveAppearanceText(.recover)
            XCTAssertNotEqual(retry, recover)
            XCTAssertTrue(strings.liveAppearanceText(.saveFailed).contains(retry))
            XCTAssertTrue(strings.liveAppearanceText(.recoveryRequired).contains(recover))
            XCTAssertNotEqual(strings.liveAppearanceText(.saved), strings.liveAppearanceText(.queued))
            switch language {
            case .english:
                XCTAssertEqual(strings.liveAppearanceText(.saved), "Changes saved.")
                XCTAssertTrue(strings.liveAppearanceText(.queued).contains("Waiting to show"))
                XCTAssertTrue(strings.liveAppearanceText(.gridHelp).contains("Folder layouts stay independent"))
                XCTAssertTrue(strings.liveAppearanceText(.defaultsApplied).contains("5 columns and 7 rows"))
                XCTAssertTrue(strings.liveAppearanceText(.defaultsApplied).contains("either save can fail independently"))
                XCTAssertTrue(strings.liveAppearanceText(.defaultsApplied).contains("Other settings and app arrangement are unchanged"))
                for key in [LiveAppearanceTextKey.unavailable, .protected] {
                    XCTAssertTrue(strings.liveAppearanceText(key).contains("Automatic saving is paused"))
                    XCTAssertTrue(strings.liveAppearanceText(key).contains("stored data will not be overwritten"))
                }
            case .simplifiedChinese:
                XCTAssertEqual(strings.liveAppearanceText(.saved), "修改已保存。")
                XCTAssertTrue(strings.liveAppearanceText(.queued).contains("等待"))
                XCTAssertTrue(strings.liveAppearanceText(.gridHelp).contains("文件夹保持独立布局"))
                XCTAssertTrue(strings.liveAppearanceText(.defaultsApplied).contains("5 列、7 行"))
                XCTAssertTrue(strings.liveAppearanceText(.defaultsApplied).contains("任一保存都可能独立失败"))
                XCTAssertTrue(strings.liveAppearanceText(.defaultsApplied).contains("其他设置和应用排列不变"))
                for key in [LiveAppearanceTextKey.unavailable, .protected] {
                    XCTAssertTrue(strings.liveAppearanceText(key).contains("自动保存已暂停"))
                    XCTAssertTrue(strings.liveAppearanceText(key).contains("不会覆盖已存储的数据"))
                }
            case .japanese:
                XCTAssertEqual(strings.liveAppearanceText(.saved), "変更を保存しました。")
                XCTAssertTrue(strings.liveAppearanceText(.queued).contains("待っています"))
                XCTAssertTrue(strings.liveAppearanceText(.gridHelp).contains("フォルダのレイアウトは独立"))
                XCTAssertTrue(strings.liveAppearanceText(.defaultsApplied).contains("5列・7行"))
                XCTAssertTrue(strings.liveAppearanceText(.defaultsApplied).contains("どちらか一方の保存だけが失敗"))
                XCTAssertTrue(strings.liveAppearanceText(.defaultsApplied).contains("他の設定とアプリの配置は変わりません"))
                for key in [LiveAppearanceTextKey.unavailable, .protected] {
                    XCTAssertTrue(strings.liveAppearanceText(key).contains("自動保存は停止"))
                    XCTAssertTrue(strings.liveAppearanceText(key).contains("保存済みのデータは上書きしません"))
                }
            }
        }
    }

    func testMissingSelectedKeysUseEnglishAndValidationReportsEveryOmission() throws {
        for language in InterfaceLanguage.allCases where language != .english {
            var table = try LocalizationTestResources.table(language)
            for key in LiveAppearanceTextKey.allCases { table.removeValue(forKey: key.rawValue) }
            let provider = try LocalizationTestResources.provider(replacing: language, with: table)
            let strings = LocalizedStrings(language: language, resourceProvider: provider)
            let issues = LocalizedStrings.validateResources(resourceProvider: provider).issues
            XCTAssertEqual(issues.count, LiveAppearanceTextKey.allCases.count)
            XCTAssertEqual(Set(issues.compactMap(\.key)), Set(LiveAppearanceTextKey.allCases.map(\.rawValue)))
            XCTAssertTrue(issues.allSatisfy { $0.language == language && $0.kind == .missingKey })
            for key in LiveAppearanceTextKey.allCases {
                XCTAssertEqual(strings.liveAppearanceText(key), key.englishFallback)
            }
        }
    }

    func testAbsentResourcesUseTypedFallbackForEveryLanguage() {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language,
                                           resourceProvider: FixtureLocalizationResources(tables: [:]))
            for key in LiveAppearanceTextKey.allCases {
                XCTAssertEqual(strings.liveAppearanceText(key), key.englishFallback)
            }
        }
    }

    func testEveryStaticKeyRejectsUnexpectedPlaceholdersInEveryLanguage() throws {
        for language in InterfaceLanguage.allCases {
            for key in LiveAppearanceTextKey.allCases {
                var table = try LocalizationTestResources.table(language)
                table[key.rawValue] = "Invalid {count}"
                let provider = try LocalizationTestResources.provider(replacing: language, with: table)
                let issues = LocalizedStrings.validateResources(resourceProvider: provider).issues
                XCTAssertEqual(issues.count, 1)
                XCTAssertEqual(issues.first?.language, language)
                XCTAssertEqual(issues.first?.key, key.rawValue)
                XCTAssertEqual(issues.first?.kind, .invalidPlaceholderSignature)
                XCTAssertEqual(LocalizedStrings(language: language, resourceProvider: provider)
                    .liveAppearanceText(key), key.englishFallback)
            }
        }
    }

    func testLiveTextRendersFromSnapshotWithoutFurtherResourceReads() throws {
        var tables: [String: Data] = [:]
        for language in InterfaceLanguage.allCases {
            tables[language.rawValue] = try LocalizationTestResources.encoded(LocalizationTestResources.table(language))
        }
        let provider = CountingLocalizationResources(fixture: FixtureLocalizationResources(tables: tables))
        let strings = LocalizedStrings(language: .japanese, resourceProvider: provider)
        let reads = provider.requestedLanguages
        for _ in 0..<10 {
            for key in LiveAppearanceTextKey.allCases { _ = strings.liveAppearanceText(key) }
        }
        XCTAssertEqual(provider.requestedLanguages, reads)
    }
}
