import Foundation
import XCTest
import LauncherLocalization

final class SettingsLocalizedStringsTests: XCTestCase {
    func testEverySettingsCaseRendersItsActualSelectedResource() throws {
        for language in InterfaceLanguage.allCases {
            let table = try LocalizationTestResources.table(language)
            let strings = LocalizedStrings(language: language)
            for key in SettingsTextKey.allCases {
                let value = strings.settingsText(key)
                XCTAssertEqual(value, table[key.rawValue], "\(language.rawValue):\(key.rawValue)")
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                XCTAssertNotEqual(value, key.rawValue)
            }
        }
    }

    func testChineseConsumerMessagesPreserveExistingBaseline() {
        let baseline: [SettingsTextKey: String] = [
            .appearanceShowLabels: "显示应用名称",
            .appearanceBlurAccessibility: "壁纸模糊强度",
            .appearanceIconAccessibility: "基础及文件夹内图标首选尺寸",
            .appearanceFontAccessibility: "应用名称字号",
            .appearanceApply: "应用外观",
            .appearanceRestoreDefaults: "恢复默认",
            .appearanceBlurCaption: "壁纸模糊强度（0–60）",
            .appearanceHelp: "图标和名称在现有格子内自动适配，较大的设置可能缩小显示。0 表示不模糊。修改后点击应用；手势、拖拽或改名结束后再显示，关闭不会保存草稿。",
            .appearanceIconCaption: "基础／文件夹内图标首选尺寸（32–96 pt）",
            .appearanceFontCaption: "应用名称字号（9–16 pt）",
            .appearanceLoadFuture: "外观设置来自较新版本，本版本不会覆盖。",
            .appearanceLoadCorrupt: "外观设置无法读取，已使用默认值。点击应用可保存新的设置。",
            .appearanceInvalidDraft: "外观设置值无效，未保存修改。",
            .appearanceUnavailable: "外观设置暂不可用。",
            .appearanceSaveFuture: "较新版本的外观设置未被覆盖。",
            .appearanceInvalidPreferences: "模糊强度、图标尺寸或字号超出支持范围。",
            .appearanceSaveFailed: "外观设置无法保存，未应用修改。",
            .appearanceDraftDefaults: "默认值已载入草稿；点击应用后保存。",
            .appearanceApplied: "外观设置已应用。",
            .appearanceQueued: "外观设置已保存，等待手势、拖拽或改名结束后显示。",
            .appearancePresentationUnavailable: "外观设置已保存；当前界面不可用，重新打开后显示。",
            .managementHideSelected: "隐藏所选应用",
            .managementSaveAlias: "保存别名",
            .managementClearAlias: "恢复原名",
            .managementRestoreAll: "恢复全部隐藏应用",
            .managementAppAccessibility: "管理应用",
            .managementAliasPlaceholder: "留空恢复原名",
            .managementAliasAccessibility: "应用别名",
            .managementHelp: "隐藏不会删除应用或保存的排列。别名只影响显示和搜索，不会修改应用文件；原名仍可搜索。",
            .managementSelectApp: "选择应用…",
            .managementHiddenSuffix: "（已隐藏）",
            .managementLoadFuture: "应用管理设置来自较新版本，本版本不会覆盖。",
            .managementLoadCorrupt: "管理设置无法读取，已使用默认值；保存后替换损坏设置。",
            .managementSaved: "应用管理设置已保存。",
            .managementInvalidAlias: "别名不能包含控制字符，最多128个字符。",
            .managementSaveFuture: "较新版本的设置未被覆盖。",
            .managementSaveFailed: "无法应用设置，请重新选择应用后重试。",
            .sourcesAutomatic: "自动刷新应用列表",
            .sourcesAdd: "添加文件夹…",
            .sourcesRemove: "移除所选来源",
            .sourcesApply: "应用来源设置",
            .sourcesRefresh: "立即刷新",
            .sourcesRootAccessibility: "额外应用来源",
            .sourcesFixedCaption: "固定来源（保留）",
            .sourcesExtraCaption: "额外来源",
            .sourcesHelp: "仅支持可读取的本地文件夹；不接受整个主目录、磁盘根或网络位置。移除来源不会删除应用、保存的排列或别名。更改后点击应用；立即刷新仅使用已保存的来源。",
            .sourcesLoadFuture: "来源设置来自较新版本，本版本不会覆盖。",
            .sourcesLoadCorrupt: "来源设置无法读取，已使用固定来源；点击应用后保存新设置。",
            .sourcesWatchActive: "自动刷新已启用；变化会合并处理。",
            .sourcesWatchDisabled: "自动刷新已关闭；可使用立即刷新。",
            .sourcesWatchUnavailable: "自动刷新不可用；请使用立即刷新。",
            .sourcesWatchDegraded: "部分来源暂不可监测；请使用立即刷新重新检查（含恢复的文件夹）。",
            .sourcesSelectRoot: "选择额外来源…",
            .sourcesRemovedDraft: "来源已从草稿移除；点击应用后生效。应用和保存的排列不会被删除。",
            .sourcesPanelPrompt: "选择应用文件夹",
            .sourcesAddedDraft: "来源已加入草稿；点击应用后保存。",
            .sourcesAlreadyCovered: "所选文件夹已包含在固定来源中。",
            .sourcesRejected: "无法添加此来源；请选择可读取的本地应用文件夹。",
            .sourcesSaved: "来源设置已保存并应用。",
            .sourcesSaveFuture: "较新版本的来源设置未被覆盖。",
            .sourcesInvalidRoot: "来源校验失败，修改未保存；请重新选择文件夹。",
            .sourcesSaveFailed: "来源设置无法保存，修改未应用。",
            .sourcesSuperseded: "本次操作已取消或被更新的操作取代。"
        ]
        XCTAssertEqual(baseline.count, 63)
        let strings = LocalizedStrings(language: .simplifiedChinese)
        for (key, expected) in baseline {
            XCTAssertEqual(strings.settingsText(key), expected, key.rawValue)
        }
    }

    func testTabsAndHiddenSuffixHaveIntentionalIndependentTranslations() {
        let cases: [(InterfaceLanguage, [String], String)] = [
            (.english, ["Activation", "Appearance", "Apps", "Sources"], " (hidden)"),
            (.simplifiedChinese, ["激活", "外观", "应用管理", "应用来源"], "（已隐藏）"),
            (.japanese, ["起動操作", "外観", "アプリ管理", "アプリの検索場所"], "（非表示）")
        ]
        let tabs: [SettingsTextKey] = [.activationTabTitle, .appearanceTabTitle, .managementTabTitle, .sourcesTabTitle]
        let originalName = "App %@ {count} 日本語 😀"
        for (language, expectedTabs, suffix) in cases {
            let strings = LocalizedStrings(language: language)
            XCTAssertEqual(tabs.map { strings.settingsText($0) }, expectedTabs)
            XCTAssertEqual(originalName + strings.settingsText(.managementHiddenSuffix), originalName + suffix)
        }
    }

    func testSettingsWindowMenuAndButtonPreserveMainBaseline() {
        let keys: [SettingsTextKey] = [.settingsWindowTitle, .viewMenuTitle, .toggleLauncherTitle,
                                       .settingsButtonAccessibility]
        let expected: [(InterfaceLanguage, [String])] = [
            (.english, ["Settings", "View", "Show/Hide Launcher", "Settings"]),
            (.simplifiedChinese, ["设置", "视图", "显示/隐藏启动器", "设置"]),
            (.japanese, ["設定", "表示", "ランチャーを表示／非表示", "設定"])
        ]
        for (language, values) in expected {
            let strings = LocalizedStrings(language: language)
            XCTAssertEqual(keys.map { strings.settingsText($0) }, values)
        }
    }

    func testHiddenReferenceCountUsesSelectedLanguageAndEnglishOneOther() {
        let english = LocalizedStrings(language: InterfaceLanguagePreference.english.resolve(preferredLanguages: ["ja"]))
        let chinese = LocalizedStrings(language: InterfaceLanguagePreference.simplifiedChinese.resolve(preferredLanguages: ["en"]))
        let japanese = LocalizedStrings(language: InterfaceLanguagePreference.japanese.resolve(preferredLanguages: ["en"]))
        for count in [0, 1, 2, 100, -1, Int.min, Int.max] {
            XCTAssertEqual(english.hiddenReferenceCount(count),
                           count == 1 ? "\(count) hidden reference (including apps not currently installed)" :
                               "\(count) hidden references (including apps not currently installed)")
            XCTAssertEqual(chinese.hiddenReferenceCount(count), "\(count) 个隐藏引用（含暂未安装的应用）")
            XCTAssertEqual(japanese.hiddenReferenceCount(count),
                           "非表示の参照 \(count) 件（現在インストールされていないアプリを含む）")
        }
    }

    func testMissingSettingsEntriesFallBackIndividuallyToActualEnglishResources() throws {
        var english = try LocalizationTestResources.table(.english)
        for key in SettingsTextKey.allCases {
            english[key.rawValue] = "English resource for \(key.rawValue)"
        }
        let intactJapanese = try LocalizationTestResources.table(.japanese)
        for key in SettingsTextKey.allCases {
            var japanese = intactJapanese
            japanese.removeValue(forKey: key.rawValue)
            let strings = LocalizedStrings(language: .japanese, resourceProvider: FixtureLocalizationResources(tables: [
                "en": try LocalizationTestResources.encoded(english),
                "ja": try LocalizationTestResources.encoded(japanese)
            ]))
            XCTAssertEqual(strings.settingsText(key), english[key.rawValue])
            for remaining in SettingsTextKey.allCases where remaining != key {
                XCTAssertEqual(strings.settingsText(remaining), intactJapanese[remaining.rawValue])
            }
            XCTAssertEqual(strings.language, .japanese)
        }
    }

    func testEverySettingsKeyIsStrictlyRequiredAndCannotAcquireArguments() throws {
        for key in SettingsTextKey.allCases {
            for replacement in [Optional<String>.none, .some("Unexpected {count}")] {
                var table = try LocalizationTestResources.table(.japanese)
                table[key.rawValue] = replacement
                let provider = try LocalizationTestResources.provider(replacing: .japanese, with: table)
                let issues = LocalizedStrings.validateResources(resourceProvider: provider).issues
                XCTAssertEqual(issues.count, 1)
                XCTAssertEqual(issues.first?.language, .japanese)
                XCTAssertEqual(issues.first?.key, key.rawValue)
                XCTAssertEqual(issues.first?.kind,
                               replacement == nil ? .missingKey : .invalidPlaceholderSignature)
                XCTAssertEqual(LocalizedStrings(language: .japanese, resourceProvider: provider).settingsText(key),
                               LocalizedStrings(language: .english).settingsText(key))
            }
        }
    }

    func testInvalidSettingsValuesReachEnglishSafetyWithoutAffectingValidTranslations() throws {
        for value in ["", " \n\t", "appearanceHelp", "\u{0000}", String(repeating: "a", count: 4097), "{count}"] {
            var japanese = try LocalizationTestResources.table(.japanese)
            var english = try LocalizationTestResources.table(.english)
            japanese["appearanceHelp"] = value
            english["appearanceHelp"] = value
            let strings = LocalizedStrings(language: .japanese, resourceProvider: FixtureLocalizationResources(tables: [
                "ja": try LocalizationTestResources.encoded(japanese),
                "en": try LocalizationTestResources.encoded(english)
            ]))
            XCTAssertEqual(strings.settingsText(.appearanceHelp), LocalizedStrings(language: .english).settingsText(.appearanceHelp))
            XCTAssertEqual(strings.settingsText(.sourcesRefresh), "今すぐ更新")
        }
    }

    func testHiddenReferenceTemplatesHaveStrictNamedIntegerSignatures() throws {
        let invalid = ["Hidden references", "{count}{count}", "{total}", "{count:int}",
                       "{count", "{count}}", "%d hidden references"]
        for key in ["hiddenReferenceCountOne", "hiddenReferenceCountOther"] {
            for value in invalid {
                var table = try LocalizationTestResources.table(.english)
                table[key] = value
                let provider = try LocalizationTestResources.provider(replacing: .english, with: table)
                let issues = LocalizedStrings.validateResources(resourceProvider: provider).issues
                XCTAssertEqual(issues.count, 1)
                XCTAssertEqual(issues.first?.key, key)
                XCTAssertEqual(issues.first?.kind, .invalidPlaceholderSignature)
                let count = key == "hiddenReferenceCountOne" ? 1 : 3
                XCTAssertEqual(LocalizedStrings(language: .english, resourceProvider: provider).hiddenReferenceCount(count),
                               "\(count) hidden \(count == 1 ? "reference" : "references") (including apps not currently installed)")
            }
        }
    }

    func testHiddenReferenceFallbackChoosesEnglishPluralGrammarAndActualResource() throws {
        var japanese = try LocalizationTestResources.table(.japanese)
        var english = try LocalizationTestResources.table(.english)
        japanese["hiddenReferenceCountOther"] = "Invalid {unexpected}"
        english["hiddenReferenceCountOne"] = "One hidden reference: {count}"
        english["hiddenReferenceCountOther"] = "Other hidden references: {count}"
        let strings = LocalizedStrings(language: .japanese, resourceProvider: FixtureLocalizationResources(tables: [
            "ja": try LocalizationTestResources.encoded(japanese),
            "en": try LocalizationTestResources.encoded(english)
        ]))
        XCTAssertEqual(strings.hiddenReferenceCount(1), "One hidden reference: 1")
        for count in [0, 2, -1, Int.min, Int.max] {
            XCTAssertEqual(strings.hiddenReferenceCount(count), "Other hidden references: \(count)")
        }
        XCTAssertEqual(strings.settingsText(.appearanceApply), "外観を適用")
    }

    func testInvariantCountsUseOtherResourceEvenForOne() throws {
        for language in [InterfaceLanguage.simplifiedChinese, .japanese] {
            var table = try LocalizationTestResources.table(language)
            table["hiddenReferenceCountOne"] = "Unused singular: {count}"
            table["hiddenReferenceCountOther"] = "Invariant selected resource: {count}"
            let strings = LocalizedStrings(language: language,
                                           resourceProvider: try LocalizationTestResources.provider(replacing: language, with: table))
            XCTAssertEqual(strings.hiddenReferenceCount(1), "Invariant selected resource: 1")
            XCTAssertEqual(strings.hiddenReferenceCount(0), "Invariant selected resource: 0")
        }
    }

    func testAbsentAndInvalidResourcesSupplyAllKeySpecificSafetyValues() {
        let providers = [
            FixtureLocalizationResources(tables: [:]),
            FixtureLocalizationResources(tables: ["en": Data("invalid bytes".utf8), "ja": Data([0, 255])])
        ]
        let english = LocalizedStrings(language: .english)
        for provider in providers {
            for language in InterfaceLanguage.allCases {
                let strings = LocalizedStrings(language: language, resourceProvider: provider)
                for key in SettingsTextKey.allCases {
                    XCTAssertEqual(strings.settingsText(key), english.settingsText(key), key.rawValue)
                    XCTAssertNotEqual(strings.settingsText(key), key.rawValue)
                }
                for count in [0, 1, 2, -1, Int.min, Int.max] {
                    XCTAssertEqual(strings.hiddenReferenceCount(count), english.hiddenReferenceCount(count))
                }
            }
        }
    }

    func testSettingsPercentSignsEscapesAndUnicodeAreLiteral() {
        let table = #"""
        "appearanceHelp" = "Choose \"Launchcopy\"\n日本語 😀 100% %@ %d";
        "hiddenReferenceCountOther" = "{count} references\t100% %@";
        """#
        let strings = LocalizedStrings(language: .japanese,
                                       resourceProvider: FixtureLocalizationResources(tables: ["ja": Data(table.utf8)]))
        XCTAssertEqual(strings.settingsText(.appearanceHelp), "Choose \"Launchcopy\"\n日本語 😀 100% %@ %d")
        XCTAssertEqual(strings.hiddenReferenceCount(2), "2 references\t100% %@")
    }
}

