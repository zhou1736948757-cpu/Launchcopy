import Foundation
import XCTest
import LauncherLocalization

final class LocalizationResourceValidationTests: XCTestCase {
    func testRequiredKeyContractAndEveryShippedTableHaveExactCoverage() throws {
        let textKeys = [
            "languageFutureProtected", "languageTitle", "followSystem", "languageHelp", "apply", "restoreDefaults",
            "languageApplied", "languageQueued", "languageSaveFailed", "languageCorrupt",
            "languageStoreUnavailable", "languageDraftDefaults", "close", "cancel",
            "searchPlaceholder", "searchAccessibility", "settingsTitle", "showLauncher",
            "hideLauncher", "quitLauncher"
        ]
        let settingsKeys = [
            "activationTabTitle", "appearanceTabTitle", "managementTabTitle",
            "sourcesTabTitle", "settingsWindowTitle", "viewMenuTitle",
            "toggleLauncherTitle", "settingsButtonAccessibility",
            "appearanceShowLabels", "appearanceBlurAccessibility",
            "appearanceIconAccessibility", "appearanceMainIconAccessibility", "appearanceMainIconCaption",
            "appearanceMainIconFitFormat", "appearanceIndependentIconsHelp",
            "appearanceFontAccessibility", "appearanceApply",
            "appearanceRestoreDefaults", "appearanceBlurCaption", "appearanceHelp",
            "appearanceIconCaption", "appearanceFontCaption", "appearanceLoadFuture",
            "appearanceLoadCorrupt", "appearanceInvalidDraft", "appearanceUnavailable",
            "appearanceSaveFuture", "appearanceInvalidPreferences", "appearanceSaveFailed",
            "appearanceDraftDefaults", "appearanceApplied", "appearanceQueued",
            "appearancePresentationUnavailable", "managementHideSelected", "managementSaveAlias",
            "managementClearAlias", "managementRestoreAll", "managementAppAccessibility",
            "managementAliasPlaceholder", "managementAliasAccessibility", "managementHelp",
            "managementSelectApp", "managementHiddenSuffix", "managementLoadFuture",
            "managementLoadCorrupt", "managementSaved", "managementInvalidAlias",
            "managementSaveFuture", "managementSaveFailed", "managementSearchIdentifiers",
            "managementIdentifierSearchHelp", "managementIdentifierSearchApplied",
            "managementIdentifierSearchQueued", "managementIdentifierSearchFailed",
            "managementIdentifierSearchFuture", "managementIdentifierSearchCorrupt", "sourcesAutomatic",
            "sourcesAdd", "sourcesRemove", "sourcesApply",
            "sourcesRefresh", "sourcesRootAccessibility", "sourcesFixedCaption",
            "sourcesExtraCaption", "sourcesHelp", "sourcesLoadFuture",
            "sourcesLoadCorrupt", "sourcesWatchActive", "sourcesWatchDisabled",
            "sourcesWatchUnavailable", "sourcesWatchDegraded", "sourcesSelectRoot",
            "sourcesRemovedDraft", "sourcesPanelPrompt", "sourcesAddedDraft",
            "sourcesAlreadyCovered", "sourcesRejected", "sourcesSaved",
            "sourcesSaveFuture", "sourcesInvalidRoot", "sourcesSaveFailed",
            "sourcesSuperseded"
        ]
        let menuKeys = [
            "menu.launch", "menu.setAlias", "menu.restoreOriginalName", "menu.hideApp",
            "menu.revealInFinder", "menu.organizeApps", "menu.moveToFolder", "menu.moveToTopLevel",
            "menu.edit", "menu.undo", "menu.redo", "menu.cut", "menu.copy", "menu.paste", "menu.selectAll"
        ]
        let removalKeys = [
            "appRemoval.moveToTrash", "appRemoval.confirmTitle", "appRemoval.confirmMessage",
            "appRemoval.cancel", "appRemoval.confirmMove", "appRemoval.inspecting",
            "appRemoval.moving", "appRemoval.moved", "appRemoval.unavailable",
            "appRemoval.running", "appRemoval.failed", "appRemoval.changed",
            "appRemoval.quitTitle", "appRemoval.quitMessage"
        ]
        let allKeys = textKeys + ["languageFutureVersion", "page", "memberCountOne", "memberCountOther"] +
            settingsKeys + ["hiddenReferenceCountOne", "hiddenReferenceCountOther", "folderHelpOne", "folderHelpOther", "activationFutureVersion", "activation.keyCode"] +
            ActivationTextKey.allCases.map(\.rawValue) + ActivationStatusTextKey.allCases.map(\.rawValue) +
            GridTextKey.allCases.map(\.rawValue) + menuKeys +
            CatalogTextKey.allCases.map(\.rawValue) + NoticeTextKey.allCases.map(\.rawValue) + ActionFeedbackTextKey.allCases.map(\.rawValue) + LibraryTextKey.allCases.map(\.rawValue) + MainGridCapacityTextKey.allCases.map(\.rawValue) + LiveAppearanceTextKey.allCases.map(\.rawValue) + LaunchActivityTextKey.allCases.map(\.rawValue) + removalKeys
        XCTAssertEqual(LocalizedTextKey.allCases.map(\.rawValue), textKeys)
        XCTAssertEqual(SettingsTextKey.allCases.map(\.rawValue), settingsKeys)
        XCTAssertEqual(MenuTextKey.allCases.map(\.rawValue), menuKeys)
        XCTAssertEqual(MenuTextKey.allCases.count, 15)
        XCTAssertEqual(AppRemovalTextKey.allCases.map(\.rawValue), removalKeys)
        XCTAssertEqual(allKeys.count, 369)
        XCTAssertEqual(allKeys.count, 127 + ActivationTextKey.allCases.count + ActivationStatusTextKey.allCases.count + GridTextKey.allCases.count + CatalogTextKey.allCases.count + NoticeTextKey.allCases.count + ActionFeedbackTextKey.allCases.count + LibraryTextKey.allCases.count + MainGridCapacityTextKey.allCases.count + LiveAppearanceTextKey.allCases.count + LaunchActivityTextKey.allCases.count + AppRemovalTextKey.allCases.count)
        XCTAssertEqual(Set(allKeys).count, allKeys.count, "Static keys and templates must not collide")
        XCTAssertEqual(LocalizedStrings.requiredResourceKeys, allKeys)
        for language in InterfaceLanguage.allCases {
            let table = try LocalizationTestResources.table(language)
            XCTAssertEqual(Set(table.keys), Set(allKeys), language.rawValue)
            if language != .english {
                XCTAssertEqual(table["memberCountOne"], table["memberCountOther"], "Invariant count resources must agree")
                XCTAssertEqual(table["hiddenReferenceCountOne"], table["hiddenReferenceCountOther"],
                               "Invariant hidden-reference resources must agree")
            }
        }
        XCTAssertTrue(LocalizedStrings.validateResources().isValid)
        XCTAssertEqual(LocalizedStrings.validateResources().issues, [])
    }

    func testEveryActualResourceHasExpectedNamedIntegerPlaceholderSignature() throws {
        let expression = try NSRegularExpression(pattern: #"\{([^{}]*)\}"#)
        let expected = ["languageFutureVersion": ["version"], "page": ["page", "total"],
                        "memberCountOne": ["count"], "memberCountOther": ["count"],
                        "hiddenReferenceCountOne": ["count"], "hiddenReferenceCountOther": ["count"],
            "folderHelpOne": ["count"], "folderHelpOther": ["count"],
            "activationFutureVersion": ["version"], "activation.keyCode": ["keyCode"]]
        for language in InterfaceLanguage.allCases {
            for (key, value) in try LocalizationTestResources.table(language) {
                let source = value as NSString
                let tokens = expression.matches(in: value, range: NSRange(location: 0, length: source.length))
                    .map { source.substring(with: $0.range(at: 1)) }.sorted()
                XCTAssertEqual(tokens, (expected[key] ?? []).sorted(), "\(language.rawValue):\(key)")
            }
        }
    }

    func testAbsentInvalidOversizedAndNonStringTablesReportStableTableIssues() throws {
        let invalidTables = [
            Data("broken \"table".utf8),
            try PropertyListSerialization.data(fromPropertyList: ["page": 3], format: .xml, options: 0),
            try PropertyListSerialization.data(fromPropertyList: ["array root"], format: .xml, options: 0),
            Data(repeating: 65, count: 64 * 1024 + 1)
        ]
        let missing = LocalizedStrings.validateResources(resourceProvider: FixtureLocalizationResources(tables: [:]))
        XCTAssertEqual(missing.issues.map(\.language), InterfaceLanguage.allCases)
        XCTAssertTrue(missing.issues.allSatisfy { $0.kind == .missingResource && $0.key == nil })
        for bytes in invalidTables {
            let provider = FixtureLocalizationResources(tables: ["en": bytes, "zh-Hans": bytes, "ja": bytes])
            let report = LocalizedStrings.validateResources(resourceProvider: provider)
            XCTAssertEqual(report.issues.count, 3)
            XCTAssertTrue(report.issues.allSatisfy { $0.kind == .invalidTable && $0.key == nil })
            XCTAssertEqual(LocalizedStrings(language: .japanese, resourceProvider: provider).text(.apply), "Apply")
        }
    }

    func testInvalidPlaceholderKindCountAndNamesAreRejectedBeforeInterpolation() throws {
        let invalid = [
            "Page {page}", "Page {page} of {total} {total}", "Page {total} of {unknown}",
            "Page {page:int} of {total}", "Page {page} of {total", "Page {page}} of {total}",
            "Page {{page}} of {total}", "Page {PAGE} of {total}", "Page %d of %d", "Page {} of {total}"
        ]
        for template in invalid {
            var table = try LocalizationTestResources.table(.japanese)
            table["page"] = template
            let provider = try LocalizationTestResources.provider(replacing: .japanese, with: table)
            let issues = LocalizedStrings.validateResources(resourceProvider: provider).issues
            XCTAssertEqual(issues.count, 1)
            XCTAssertEqual(issues.first?.key, "page")
            XCTAssertEqual(issues.first?.kind, .invalidPlaceholderSignature)
            XCTAssertEqual(LocalizedStrings(language: .japanese, resourceProvider: provider).page(3, total: 5), "Page 3 of 5")
        }
    }

    func testStaticTextCannotAcquireArgumentsAndInvalidValuesDoNotRender() throws {
        for value in ["", " \n\t", "apply", "\u{0000}", String(repeating: "a", count: 4097), "Apply {count}"] {
            var table = try LocalizationTestResources.table(.japanese)
            table["apply"] = value
            let provider = try LocalizationTestResources.provider(replacing: .japanese, with: table)
            let report = LocalizedStrings.validateResources(resourceProvider: provider)
            XCTAssertFalse(report.isValid)
            XCTAssertEqual(report.issues.count, 1)
            XCTAssertEqual(report.issues.first?.key, "apply")
            XCTAssertEqual(LocalizedStrings(language: .japanese, resourceProvider: provider).text(.apply), "Apply")
        }
    }

    func testPrivacyMetadataOmitsUnknownKeysResourceValuesAndPaths() throws {
        let privateMarker = "synthetic-private-marker"
        var table = try LocalizationTestResources.table(.japanese)
        table["/synthetic/\(privateMarker)"] = privateMarker
        table["languageHelp"] = "Private content {\(privateMarker)}"
        table.removeValue(forKey: "apply")
        let provider = try LocalizationTestResources.provider(replacing: .japanese, with: table)
        let report = LocalizedStrings.validateResources(resourceProvider: provider)
        XCTAssertEqual(report.issues.count, 3)
        XCTAssertEqual(Set(report.issues.map(\.kind.rawValue)),
                       Set(["unexpectedKeys", "invalidPlaceholderSignature", "missingKey"]))
        XCTAssertTrue(report.issues.allSatisfy { $0.language == .japanese })
        XCTAssertTrue(report.issues.allSatisfy { $0.key == nil || LocalizedStrings.requiredResourceKeys.contains($0.key ?? "") })
        XCTAssertFalse(String(reflecting: report).contains(privateMarker))
        XCTAssertFalse(String(reflecting: report).contains("/synthetic/"))
        XCTAssertFalse(String(reflecting: report).contains("Private content"))
    }
}
