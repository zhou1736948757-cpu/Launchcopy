import AppCatalogCore
import AppGridUI
import Foundation
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

final class FolderCreationNamingTests: XCTestCase {
    private func record(_ name: String, category: String? = nil, displayName: String? = nil) -> AppRecord {
        let id = AppID.bundleIdentifier("fixture.naming." + name)
        return AppRecord(id: id, displayName: displayName ?? name, bundleIdentifier: "fixture.naming." + name,
            canonicalURL: URL(fileURLWithPath: "/SyntheticNaming/" + name + ".app"),
            iconIdentity: .from(appID: id), sourceRootPriority: 0,
            bundleMetadata: .init(declaredCategoryIdentifier: category))
    }

    private func title(target: AppRecord, source: AppRecord, language: InterfaceLanguage,
                       library: AppLibraryPreferences = .default,
                       layout: PersistentWorkspaceLayout? = nil) -> String {
        let currentLayout = layout ?? PersistentWorkspaceLayout(generation: .zero,
            topLevelOrder: [.app(.from(record: target)), .app(.from(record: source))], folders: [])
        return FolderCreationNaming.title(target: .from(record: target), source: .from(record: source),
            layout: currentLayout, catalog: CatalogSnapshot(revision: .init(1), records: [target, source]),
            libraryPreferences: library, strings: .init(language: language))
    }

    func testUnknownCategoriesUseLocalizedAppsFallbackForEachLanguage() {
        let target = record("Alpha"), source = record("Beta")
        XCTAssertEqual(title(target: target, source: source, language: .english), "Apps")
        XCTAssertEqual(title(target: target, source: source, language: .simplifiedChinese), "应用")
        XCTAssertEqual(title(target: target, source: source, language: .japanese), "アプリ")
    }

    func testRecognizedCategoryUsesTheDisplayedCategoryForEachLanguage() {
        let target = record("Alpha", category: "public.app-category.utilities")
        let source = record("Beta", category: "public.app-category.utilities")
        for language in [InterfaceLanguage.english, .simplifiedChinese, .japanese] {
            let strings = LocalizedStrings(language: language)
            XCTAssertEqual(title(target: target, source: source, language: language),
                           strings.libraryText(.categoryUtilities))
        }
    }

    func testDisplayNameChangesDoNotAffectNeutralOrCategorySuggestions() {
        let target = record("Alpha"), source = record("Beta")
        let renamedTarget = record("Alpha", displayName: "Games")
        let renamedSource = record("Beta", displayName: "Utilities")
        XCTAssertEqual(title(target: target, source: source, language: .english), "Apps")
        XCTAssertEqual(title(target: renamedTarget, source: renamedSource, language: .english), "Apps")

        let categorizedTarget = record("Alpha", category: "public.app-category.utilities")
        let categorizedSource = record("Beta", category: "public.app-category.games")
        let renamedCategorizedTarget = record("Alpha", category: "public.app-category.utilities",
                                             displayName: "Games")
        let renamedCategorizedSource = record("Beta", category: "public.app-category.games",
                                             displayName: "Utilities")
        XCTAssertEqual(title(target: categorizedTarget, source: categorizedSource, language: .english), "Utilities")
        XCTAssertEqual(title(target: renamedCategorizedTarget, source: renamedCategorizedSource,
                             language: .english), "Utilities")
        XCTAssertEqual(renamedTarget.id, target.id)
        XCTAssertEqual(renamedSource.id, source.id)
        XCTAssertEqual(renamedCategorizedTarget.id, categorizedTarget.id)
        XCTAssertEqual(renamedCategorizedSource.id, categorizedSource.id)
        XCTAssertEqual(target.displayName, "Alpha")
        XCTAssertEqual(source.bundleIdentifier, "fixture.naming.Beta")
    }

    func testDifferentRecognizedCategoriesPreferTheTargetAndReverseWithDropOrder() {
        let utilities = record("Alpha", category: "public.app-category.utilities")
        let games = record("Beta", category: "public.app-category.games")
        XCTAssertEqual(title(target: utilities, source: games, language: .english), "Utilities")
        XCTAssertEqual(title(target: games, source: utilities, language: .english), "Games")
    }

    func testMissingOrUnknownTargetCategoryUsesRecognizedSourceCategory() {
        let source = record("Beta", category: "public.app-category.utilities")
        for target in [record("Alpha"), record("Alpha", category: "fixture.unrecognized-category")] {
            XCTAssertEqual(title(target: target, source: source, language: .english), "Utilities")
        }
    }

    func testCommittedCategoryOverridesApplyWithTheLibraryDisabled() {
        let target = record("Alpha", category: "public.app-category.utilities")
        let source = record("Beta", category: "public.app-category.games")
        let library = AppLibraryPreferences.default.settingCategory(.education, for: target)
            .settingCategory(.education, for: source)
        XCTAssertFalse(library.enabled)
        XCTAssertEqual(title(target: target, source: source, language: .english, library: library), "Education")
    }

    func testSingleCommittedTargetCategoryOverrideWinsWithTheLibraryDisabled() {
        let target = record("Alpha", category: "public.app-category.utilities")
        let source = record("Beta", category: "public.app-category.games")
        let library = AppLibraryPreferences.default.settingCategory(.education, for: target)
        XCTAssertFalse(library.enabled)
        XCTAssertEqual(title(target: target, source: source, language: .english, library: library), "Education")
    }

    func testNamesRemainPersistedContentRatherThanLiveLocalizedCategoryLabels() throws {
        let target = record("Alpha", category: "public.app-category.utilities")
        let source = record("Beta", category: "public.app-category.utilities")
        let englishTitle = title(target: target, source: source, language: .english)
        let folderID = FolderID()
        let layout = PersistentWorkspaceLayout(generation: .init(7), topLevelOrder: [.folder(folderID)],
            folders: [.init(id: folderID, title: englishTitle,
                             members: [.from(record: target), .from(record: source)])])
        let encoded = try LayoutStoreCodec.encode(layout, writeGeneration: 8)
        guard case .valid(let decoded) = LayoutStoreCodec.decode(encoded) else {
            return XCTFail("Generated folder title must survive the real persistence codec")
        }
        let restored = decoded.layout
        for language in [InterfaceLanguage.simplifiedChinese, .japanese] {
            XCTAssertEqual(title(target: target, source: source, language: language, layout: restored),
                           LocalizedStrings(language: language).libraryText(.categoryUtilities))
        }
        XCTAssertEqual(restored, layout)
        XCTAssertEqual(restored.folder(id: folderID)?.title, "Utilities")
    }

    func testFallbackNamesRemainPersistedContentAcrossLanguageChanges() throws {
        let target = record("Alpha"), source = record("Beta")
        let languages: [(InterfaceLanguage, String)] = [
            (.english, "Apps"), (.simplifiedChinese, "应用"), (.japanese, "アプリ")
        ]
        for (language, expectedTitle) in languages {
            let generatedTitle = title(target: target, source: source, language: language)
            XCTAssertEqual(generatedTitle, expectedTitle)
            let folderID = FolderID()
            let layout = PersistentWorkspaceLayout(generation: .init(7), topLevelOrder: [.folder(folderID)],
                folders: [.init(id: folderID, title: generatedTitle,
                                 members: [.from(record: target), .from(record: source)])])
            let encoded = try LayoutStoreCodec.encode(layout, writeGeneration: 8)
            guard case .valid(let decoded) = LayoutStoreCodec.decode(encoded) else {
                return XCTFail("Neutral folder title must survive the real persistence codec")
            }
            let restored = decoded.layout
            for (nextLanguage, nextTitle) in languages where nextLanguage != language {
                XCTAssertEqual(title(target: target, source: source, language: nextLanguage,
                                     layout: restored), nextTitle)
                XCTAssertEqual(restored.folder(id: folderID)?.title, expectedTitle)
            }
            XCTAssertEqual(restored, layout)
        }
    }

    func testExistingSavedPairTitlesAreNotMigrated() throws {
        let target = record("Alpha", category: "public.app-category.utilities")
        let source = record("Beta", category: "public.app-category.games")
        let savedTarget = record("Gamma"), savedSource = record("Delta")
        for savedTitle in ["Gamma & Delta", "Gamma与Delta", "Gamma・Delta"] {
            let folderID = FolderID()
            let layout = PersistentWorkspaceLayout(generation: .init(7),
                topLevelOrder: [.folder(folderID), .app(.from(record: target)), .app(.from(record: source))],
                folders: [.init(id: folderID, title: savedTitle,
                                 members: [.from(record: savedTarget), .from(record: savedSource)])])
            let encoded = try LayoutStoreCodec.encode(layout, writeGeneration: 8)
            guard case .valid(let decoded) = LayoutStoreCodec.decode(encoded) else {
                return XCTFail("Existing pair title must survive the real persistence codec")
            }
            let restored = decoded.layout
            for language in [InterfaceLanguage.english, .simplifiedChinese, .japanese] {
                XCTAssertEqual(title(target: target, source: source, language: language, layout: restored),
                               LocalizedStrings(language: language).libraryText(.categoryUtilities))
                XCTAssertEqual(restored.folder(id: folderID)?.title, savedTitle)
            }
            XCTAssertEqual(restored, layout)
        }
    }
}
