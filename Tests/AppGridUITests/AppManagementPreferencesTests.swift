import AppCatalogCore
import Foundation
import XCTest
import AppGridUI

final class AppManagementPreferencesTests: XCTestCase {
    private let locale = Locale(identifier: "en_US_POSIX")

    private func record(
        name: String = "Original",
        bundleID: String? = "fixture.metadata.original",
        path: String = "/SyntheticApps/Original.app",
        priority: Int = 7
    ) -> AppRecord {
        let url = URL(fileURLWithPath: path)
        let id = bundleID.flatMap { $0.isEmpty ? nil : AppID.bundleIdentifier($0) }
            ?? AppID.canonicalURLFallback(url)
        return AppRecord(id: id, displayName: name, bundleIdentifier: bundleID,
                         canonicalURL: url, iconIdentity: .from(appID: id),
                         sourceRootPriority: priority)
    }

    private func query(_ raw: String) -> AppSearchQuery {
        AppSearchQuery(raw: raw, locale: locale)
    }

    private func identityTransition() -> (old: AppRecord, current: AppRecord) {
        (
            record(bundleID: nil, path: "/SyntheticApps/Sub/../Original.app/"),
            record(path: "/syntheticapps/original.app")
        )
    }

    func testDefaultsLeaveCatalogUnchanged() {
        let records = [record(), record(name: "Second", bundleID: nil, path: "/SyntheticApps/Second.app")]
        let preferences = AppManagementPreferences()
        XCTAssertEqual(preferences, .default)
        XCTAssertEqual(preferences.hiddenKeys, [])
        XCTAssertEqual(preferences.aliases, [:])
        XCTAssertTrue(preferences.isValid)
        XCTAssertEqual(preferences.visibleRecords(records), records)
        for app in records {
            XCTAssertFalse(preferences.isHidden(app))
            XCTAssertEqual(preferences.displayName(for: app), app.displayName)
            XCTAssertEqual(preferences.presentationRecord(for: app), app)
        }
    }

    func testBundleReferenceUsesExistingKeyAndSurvivesNameAndURLChanges() throws {
        let original = record()
        let renamed = record(name: "Renamed", path: "/SyntheticApps/Moved.app")
        XCTAssertEqual(AppManagementPreferences.key(for: original),
                       PersistentAppReference.from(record: original).comparisonKey)
        XCTAssertEqual(AppManagementPreferences.key(for: original), "bundle:fixture.metadata.original")
        XCTAssertEqual(AppManagementPreferences.key(for: original), AppManagementPreferences.key(for: renamed))
        let preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Alias", for: original))
            .settingHidden(true, for: original)
        XCTAssertTrue(preferences.isHidden(renamed))
        XCTAssertEqual(preferences.displayName(for: renamed), "Alias")
    }

    func testPathReferenceNormalizesPathAndSurvivesNameChanges() throws {
        let original = record(bundleID: nil, path: "/SyntheticApps/Sub/../Fallback.app/")
        let renamed = record(name: "Renamed", bundleID: nil, path: "/syntheticapps/fallback.app")
        XCTAssertEqual(AppManagementPreferences.key(for: original),
                       PersistentAppReference.from(record: original).comparisonKey)
        XCTAssertEqual(AppManagementPreferences.key(for: original), "path:/syntheticapps/fallback.app")
        XCTAssertEqual(AppManagementPreferences.key(for: original), AppManagementPreferences.key(for: renamed))
        let preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Alias", for: original))
            .settingHidden(true, for: original)
        XCTAssertTrue(preferences.isHidden(renamed))
        XCTAssertEqual(preferences.displayName(for: renamed), "Alias")
    }

    func testEmptyBundleIdentifierUsesPathFallback() {
        let emptyBundle = record(bundleID: "")
        let missingBundle = record(bundleID: nil)
        XCTAssertEqual(AppManagementPreferences.key(for: emptyBundle), AppManagementPreferences.key(for: missingBundle))
        XCTAssertTrue(AppManagementPreferences.key(for: emptyBundle).hasPrefix("path:"))
    }

    func testEqualDisplayNamesHaveIndependentMetadata() throws {
        let first = record(name: "Shared", bundleID: "fixture.metadata.first")
        let second = record(name: "Shared", bundleID: "fixture.metadata.second")
        let preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias("First alias", for: first))
            .settingHidden(true, for: first)
        XCTAssertNotEqual(AppManagementPreferences.key(for: first), AppManagementPreferences.key(for: second))
        XCTAssertFalse(preferences.isHidden(second))
        XCTAssertEqual(preferences.displayName(for: second), "Shared")
    }

    func testPresentationCopiesOnlyDisplayNameForBothReferenceKinds() throws {
        let records = [record(), record(bundleID: nil, path: "/SyntheticApps/Fallback.app", priority: 3)]
        for app in records {
            let preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Alias", for: app))
            let presented = preferences.presentationRecord(for: app)
            XCTAssertEqual(presented.displayName, "Alias")
            XCTAssertEqual(presented.id, app.id)
            XCTAssertEqual(presented.canonicalURL, app.canonicalURL)
            XCTAssertEqual(presented.bundleIdentifier, app.bundleIdentifier)
            XCTAssertEqual(presented.iconIdentity, app.iconIdentity)
            XCTAssertEqual(presented.sourceRootPriority, app.sourceRootPriority)
            XCTAssertEqual(AppManagementPreferences.key(for: presented), AppManagementPreferences.key(for: app))
            XCTAssertEqual(app.displayName, "Original")
        }
    }

    func testVisibleProjectionPreservesInputOrderAndCanonicalCatalog() throws {
        let first = record(name: "Zulu", bundleID: "fixture.metadata.first")
        let hidden = record(name: "Middle", bundleID: "fixture.metadata.hidden")
        let last = record(name: "Alpha", bundleID: nil, path: "/SyntheticApps/Last.app")
        let records = [first, hidden, last]
        let preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias("A alias", for: first))
            .settingHidden(true, for: hidden)
        let visible = preferences.visibleRecords(records)
        XCTAssertEqual(visible.map(\.id), [first.id, last.id])
        XCTAssertEqual(visible.map(\.displayName), ["A alias", "Alpha"])
        XCTAssertEqual(visible.map(\.canonicalURL), [first.canonicalURL, last.canonicalURL])
        XCTAssertEqual(visible.map(\.iconIdentity), [first.iconIdentity, last.iconIdentity])
        XCTAssertEqual(records, [first, hidden, last])
        XCTAssertEqual(records.map(\.displayName), ["Zulu", "Middle", "Alpha"])
        XCTAssertEqual(preferences.visibleRecords([]), [])
    }

    func testHideAllAndRestoreRecoversOriginalOrderAndAliases() throws {
        let first = record(name: "First", bundleID: "fixture.metadata.first")
        let second = record(name: "Second", bundleID: nil, path: "/SyntheticApps/Second.app")
        let records = [first, second]
        var preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Alias", for: second))
        for app in records { preferences = preferences.settingHidden(true, for: app) }
        XCTAssertEqual(preferences.visibleRecords(records), [])
        for app in records { preferences = preferences.settingHidden(false, for: app) }
        XCTAssertEqual(preferences.visibleRecords(records).map(\.id), records.map(\.id))
        XCTAssertEqual(preferences.visibleRecords(records).map(\.displayName), ["First", "Alias"])
        XCTAssertEqual(preferences.hiddenKeys, [])
    }

    func testHiddenUpdatesAreIdempotentAndPreserveOtherMetadata() throws {
        let target = record()
        let other = record(bundleID: "fixture.metadata.other")
        let initial = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Alias", for: target))
            .settingHidden(true, for: other)
        let hidden = initial.settingHidden(true, for: target)
        XCTAssertEqual(hidden.settingHidden(true, for: target), hidden)
        XCTAssertEqual(hidden.settingHidden(false, for: target), initial)
        XCTAssertEqual(initial.settingHidden(false, for: target), initial)
        XCTAssertFalse(initial.isHidden(target))
        XCTAssertEqual(hidden.aliases, initial.aliases)
    }

    func testSearchMatchesOriginalAndAliasWithUnicodeFolding() throws {
        let app = record(name: "Ｃａｆé Original")
        let preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Ｒésumé Workspace", for: app))
        for text in ["cafe", "CAFÉ", "original", "resume", "ＲÉＳＵＭÉ", " workspace ", "sum"] {
            XCTAssertTrue(preferences.matches(app, query: query(text)))
        }
        XCTAssertFalse(preferences.matches(app, query: query("unrelated")))
        XCTAssertFalse(preferences.matches(app, query: query("original resume")))
    }

    func testSearchUsesSameLocaleAndLiteralSemanticsAsExistingMatcher() throws {
        let app = record(name: "Istanbul Photos")
        let preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias("İzmir [Desk]", for: app))
        let matcher = AppSearchMatcher()
        for localeID in ["en_US_POSIX", "tr_TR"] {
            for text in ["i", "İ", "[Desk]", ".*", "Istanbul", "izmir", ""] {
                let query = AppSearchQuery(raw: text, locale: Locale(identifier: localeID))
                let expected = matcher.matches(app, query: query)
                    || matcher.matches(preferences.presentationRecord(for: app), query: query)
                XCTAssertEqual(preferences.matches(app, query: query), expected)
            }
        }
    }

    func testSearchDoesNotMatchBundlePathOrFuzzyNames() throws {
        let app = record(name: "Calculator")
        let preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Workspace", for: app))
        for text in ["fixture.metadata", "/SyntheticApps", "Original.app", "Calclator", "wksp"] {
            XCTAssertFalse(preferences.matches(app, query: query(text)))
        }
    }

    func testHiddenNeverMatchesOriginalAliasOrEmptyQuery() throws {
        let app = record(name: "Original")
        let visible = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Alias", for: app))
        let hidden = visible.settingHidden(true, for: app)
        for text in ["", " \t\n ", "original", "alias"] {
            XCTAssertTrue(visible.matches(app, query: query(text)))
            XCTAssertFalse(hidden.matches(app, query: query(text)))
        }
    }

    func testDefaultSearchUsesExistingMatcher() {
        let app = record(name: "Café Ａｐｐ")
        let matcher = AppSearchMatcher()
        for text in ["", " \n ", "cafe", "APP", "unrelated"] {
            XCTAssertEqual(AppManagementPreferences.default.matches(app, query: query(text)),
                           matcher.matches(app, query: query(text)))
        }
    }

    func testAliasTrimsSurroundingWhitespaceAndPreservesInternalSpaces() throws {
        let app = record()
        let preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias(" \t\n Café  Desk \r\n ", for: app))
        XCTAssertEqual(preferences.displayName(for: app), "Café  Desk")
        XCTAssertTrue(preferences.isValid)
        XCTAssertEqual(AppManagementPreferences.default.displayName(for: app), "Original")
    }

    func testNilAndBlankAliasRemoveOnlyTargetAlias() throws {
        let target = record()
        let other = record(bundleID: "fixture.metadata.other")
        let targetAlias = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Alias", for: target))
        let preferences = try XCTUnwrap(targetAlias.settingAlias("Other alias", for: other))
            .settingHidden(true, for: target)
        for input: String? in [nil, "", " \t\n\r ", "\u{00A0}\u{3000}"] {
            let updated = try XCTUnwrap(preferences.settingAlias(input, for: target))
            XCTAssertNil(updated.aliases[AppManagementPreferences.key(for: target)])
            XCTAssertEqual(updated.displayName(for: target), target.displayName)
            XCTAssertEqual(updated.displayName(for: other), "Other alias")
            XCTAssertEqual(updated.hiddenKeys, preferences.hiddenKeys)
        }
        XCTAssertEqual(preferences.displayName(for: target), "Alias")
    }

    func testAliasRejectsInternalControlCharactersWithoutMutation() throws {
        let app = record()
        let preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Kept", for: app))
        for scalar in ["\u{0000}", "\t", "\n", "\r", "\u{001B}", "\u{007F}", "\u{0085}", "\u{200B}"] {
            XCTAssertNil(preferences.settingAlias("Left" + scalar + "Right", for: app))
        }
        XCTAssertEqual(preferences.displayName(for: app), "Kept")
        XCTAssertTrue(preferences.isValid)
    }

    func testAliasLimitCountsGraphemesRatherThanScalarsOrBytes() throws {
        let app = record()
        for grapheme in ["x", "e\u{0301}", "🇨🇦"] {
            let boundary = String(repeating: grapheme, count: 128)
            XCTAssertEqual(boundary.count, 128)
            let preferences = try XCTUnwrap(AppManagementPreferences.default.settingAlias(" " + boundary + " ", for: app))
            XCTAssertEqual(preferences.displayName(for: app), boundary)
            XCTAssertTrue(preferences.isValid)
            XCTAssertNil(preferences.settingAlias(boundary + grapheme, for: app))
        }
    }

    func testPathHiddenContinuityAfterGainingBundleIDDoesNotRewriteMetadata() {
        let (old, current) = identityTransition()
        let pathKey = AppManagementPreferences.key(for: old)
        let preferences = AppManagementPreferences(
            hiddenKeys: [pathKey, "bundle:fixture.metadata.unrelated"],
            aliases: [pathKey: "Legacy workspace", "path:/syntheticapps/unrelated.app": "Unrelated"]
        )
        let stored = preferences
        XCTAssertEqual(pathKey, "path:/syntheticapps/original.app")
        XCTAssertEqual(AppManagementPreferences.key(for: current), "bundle:fixture.metadata.original")
        XCTAssertTrue(preferences.isHidden(old))
        XCTAssertTrue(preferences.isHidden(current))
        XCTAssertEqual(preferences.visibleRecords([current]), [])
        XCTAssertEqual(preferences.displayName(for: current), "Legacy workspace")
        for text in ["", "original", "legacy"] {
            XCTAssertFalse(preferences.matches(current, query: query(text)))
        }
        XCTAssertEqual(preferences, stored)
        XCTAssertFalse(preferences.hiddenKeys.contains(AppManagementPreferences.key(for: current)))
        XCTAssertNil(preferences.aliases[AppManagementPreferences.key(for: current)])
    }

    func testPathAliasContinuityPreservesPresentationIdentityAndOriginalSearch() {
        let (old, current) = identityTransition()
        let preferences = AppManagementPreferences(
            aliases: [AppManagementPreferences.key(for: old): "Ｒésumé Workspace"]
        )
        let stored = preferences
        let presented = preferences.presentationRecord(for: current)
        XCTAssertEqual(presented.displayName, "Ｒésumé Workspace")
        XCTAssertEqual(presented.id, current.id)
        XCTAssertEqual(presented.bundleIdentifier, current.bundleIdentifier)
        XCTAssertEqual(presented.canonicalURL, current.canonicalURL)
        XCTAssertEqual(presented.iconIdentity, current.iconIdentity)
        XCTAssertEqual(presented.sourceRootPriority, current.sourceRootPriority)
        let other = record(name: "Second", bundleID: "fixture.metadata.second",
                           path: "/SyntheticApps/Second.app")
        XCTAssertEqual(preferences.visibleRecords([other, current]), [other, presented])
        for text in ["", "original", "resume", "workspace"] {
            XCTAssertTrue(preferences.matches(current, query: query(text)))
        }
        for text in ["unrelated", "original resume", "fixture.metadata", "/syntheticapps"] {
            XCTAssertFalse(preferences.matches(current, query: query(text)))
        }
        XCTAssertEqual(current.displayName, "Original")
        XCTAssertEqual(preferences, stored)
    }

    func testBundleAliasPrecedesLegacyPathAliasIncludingSearch() {
        let (old, current) = identityTransition()
        let preferences = AppManagementPreferences(aliases: [
            AppManagementPreferences.key(for: old): "Legacy workspace",
            AppManagementPreferences.key(for: current): "Preferred desk"
        ])
        let stored = preferences
        XCTAssertEqual(preferences.displayName(for: current), "Preferred desk")
        XCTAssertEqual(preferences.displayName(for: old), "Legacy workspace")
        XCTAssertEqual(preferences.visibleRecords([current]).map(\.displayName), ["Preferred desk"])
        for text in ["original", "preferred", "desk"] {
            XCTAssertTrue(preferences.matches(current, query: query(text)))
        }
        XCTAssertFalse(preferences.matches(current, query: query("legacy")))
        XCTAssertEqual(preferences, stored)
    }

    func testContinuityUsesExactBundleKeyAndOnlyCurrentNormalizedPath() {
        let (old, current) = identityTransition()
        let differentlyCasedBundle = record(bundleID: "Fixture.Metadata.Original",
                                            path: "/SyntheticApps/Different.app")
        let otherPath = record(bundleID: nil, path: "/SyntheticApps/Different.app")
        let preferences = AppManagementPreferences(
            hiddenKeys: [AppManagementPreferences.key(for: differentlyCasedBundle),
                         AppManagementPreferences.key(for: otherPath)],
            aliases: [AppManagementPreferences.key(for: differentlyCasedBundle): "Other bundle",
                      AppManagementPreferences.key(for: otherPath): "Other path"]
        )
        XCTAssertFalse(preferences.isHidden(current))
        XCTAssertEqual(preferences.displayName(for: current), current.displayName)
        XCTAssertEqual(preferences.settingHidden(false, for: current), preferences)
        XCTAssertEqual(preferences.settingAlias(nil, for: current), preferences)
        let legacy = AppManagementPreferences(
            hiddenKeys: [AppManagementPreferences.key(for: old)],
            aliases: [AppManagementPreferences.key(for: old): "Legacy"]
        )
        let moved = record(path: "/SyntheticApps/Moved.app")
        XCTAssertFalse(legacy.isHidden(moved))
        XCTAssertEqual(legacy.displayName(for: moved), moved.displayName)
    }

    func testContinuityAcrossCodableReloadsPreservesOldNewAndUnrelatedKeys() throws {
        let (old, current) = identityTransition()
        let pathKey = AppManagementPreferences.key(for: old)
        let bundleKey = AppManagementPreferences.key(for: current)
        for hasBundleMetadata in [false, true] {
            var stored = AppManagementPreferences(
                hiddenKeys: [pathKey, "bundle:fixture.metadata.unrelated"],
                aliases: [pathKey: "Legacy 🇨🇦", "path:/syntheticapps/unrelated.app": "Unrelated"]
            )
            if hasBundleMetadata {
                stored.hiddenKeys.insert(bundleKey)
                stored.aliases[bundleKey] = "Preferred Ｃａｆé"
            }
            let expectedName = hasBundleMetadata ? "Preferred Ｃａｆé" : "Legacy 🇨🇦"
            var reloaded = stored
            for _ in 0..<2 {
                reloaded = try JSONDecoder().decode(
                    AppManagementPreferences.self, from: JSONEncoder().encode(reloaded)
                )
                XCTAssertEqual(reloaded, stored)
                XCTAssertTrue(reloaded.isValid)
                XCTAssertTrue(reloaded.isHidden(current))
                XCTAssertEqual(reloaded.displayName(for: current), expectedName)
                XCTAssertEqual(reloaded.visibleRecords([current]), [])
                XCTAssertFalse(reloaded.matches(current, query: query("original")))
                let visible = reloaded.settingHidden(false, for: current)
                XCTAssertTrue(visible.matches(current, query: query("original")))
                XCTAssertTrue(visible.matches(current, query: query(expectedName)))
                XCTAssertEqual(visible.visibleRecords([current]).map(\.displayName), [expectedName])
                reloaded = try PropertyListDecoder().decode(
                    AppManagementPreferences.self, from: PropertyListEncoder().encode(reloaded)
                )
                XCTAssertEqual(reloaded, stored)
                XCTAssertTrue(reloaded.isHidden(current))
                XCTAssertEqual(reloaded.displayName(for: current), expectedName)
            }
        }
    }

    func testUnhideClearsBothCurrentIdentityKeysAndPreservesUnrelatedMetadata() throws {
        let (old, current) = identityTransition()
        let pathKey = AppManagementPreferences.key(for: old)
        let bundleKey = AppManagementPreferences.key(for: current)
        let unrelated: Set<String> = ["bundle:fixture.metadata.unrelated", "path:/syntheticapps/unrelated.app"]
        let identityKeySets: [Set<String>] = [[pathKey], [bundleKey], [pathKey, bundleKey]]
        for targetKeys in identityKeySets {
            let stored = AppManagementPreferences(
                hiddenKeys: unrelated.union(targetKeys),
                aliases: [pathKey: "Legacy workspace", bundleKey: "Preferred desk"]
            )
            let updated = stored.settingHidden(false, for: current)
            XCTAssertEqual(updated.hiddenKeys, unrelated)
            XCTAssertEqual(updated.aliases, stored.aliases)
            XCTAssertFalse(updated.isHidden(old))
            XCTAssertFalse(updated.isHidden(current))
            XCTAssertEqual(updated.settingHidden(false, for: current), updated)
            XCTAssertEqual(updated.visibleRecords([current]).map(\.id), [current.id])
            XCTAssertTrue(updated.matches(current, query: query("original")))
            let reloaded = try JSONDecoder().decode(
                AppManagementPreferences.self, from: JSONEncoder().encode(updated)
            )
            XCTAssertEqual(reloaded, updated)
            XCTAssertFalse(reloaded.isHidden(current))
            XCTAssertEqual(stored.hiddenKeys, unrelated.union(targetKeys))
        }
    }

    func testHideStoresPreferredKeyWithoutMigratingLegacyOrUnrelatedEntries() {
        let (old, current) = identityTransition()
        let pathKey = AppManagementPreferences.key(for: old)
        let bundleKey = AppManagementPreferences.key(for: current)
        let unrelated: Set<String> = ["bundle:fixture.metadata.unrelated", "path:/syntheticapps/unrelated.app"]
        for hasLegacyKey in [false, true] {
            let stored = AppManagementPreferences(
                hiddenKeys: hasLegacyKey ? unrelated.union([pathKey]) : unrelated,
                aliases: [pathKey: "Legacy", "bundle:fixture.metadata.unrelated": "Unrelated"]
            )
            let updated = stored.settingHidden(true, for: current)
            XCTAssertEqual(updated.hiddenKeys, stored.hiddenKeys.union([bundleKey]))
            XCTAssertEqual(updated.aliases, stored.aliases)
            XCTAssertEqual(updated.settingHidden(true, for: current), updated)
            XCTAssertTrue(updated.isHidden(current))
            XCTAssertEqual(updated.hiddenKeys.contains(pathKey), hasLegacyKey)
        }
    }

    func testResetAliasClearsBothCurrentIdentityKeysAndPreservesOtherMetadata() throws {
        let (old, current) = identityTransition()
        let pathKey = AppManagementPreferences.key(for: old)
        let bundleKey = AppManagementPreferences.key(for: current)
        let unrelated = ["bundle:fixture.metadata.unrelated": "Unrelated bundle",
                         "path:/syntheticapps/unrelated.app": "Unrelated path"]
        for targetKeys in [[pathKey], [bundleKey], [pathKey, bundleKey]] {
            var stored = AppManagementPreferences(
                hiddenKeys: [pathKey, bundleKey, "bundle:fixture.metadata.unrelated"],
                aliases: unrelated
            )
            for key in targetKeys { stored.aliases[key] = "Alias" }
            for input: String? in [nil, "", " \t\n\r ", "\u{00A0}\u{3000}"] {
                let updated = try XCTUnwrap(stored.settingAlias(input, for: current))
                XCTAssertEqual(updated.aliases, unrelated)
                XCTAssertEqual(updated.hiddenKeys, stored.hiddenKeys)
                XCTAssertEqual(updated.displayName(for: current), current.displayName)
                XCTAssertEqual(updated.displayName(for: old), old.displayName)
                XCTAssertEqual(updated.settingAlias(input, for: current), updated)
                let reloaded = try PropertyListDecoder().decode(
                    AppManagementPreferences.self, from: PropertyListEncoder().encode(updated)
                )
                XCTAssertEqual(reloaded, updated)
                XCTAssertEqual(reloaded.displayName(for: current), current.displayName)
            }
            XCTAssertEqual(stored.aliases.count, unrelated.count + targetKeys.count)
        }
    }

    func testExplicitAliasReplacesOnlySameAppLegacyAliasAndRejectsInvalidInput() throws {
        let (old, current) = identityTransition()
        let pathKey = AppManagementPreferences.key(for: old)
        let bundleKey = AppManagementPreferences.key(for: current)
        let unrelated = ["bundle:fixture.metadata.unrelated": "Unrelated bundle",
                         "path:/syntheticapps/unrelated.app": "Unrelated path"]
        for targetKeys in [[pathKey], [bundleKey], [pathKey, bundleKey]] {
            var stored = AppManagementPreferences(hiddenKeys: [pathKey, bundleKey], aliases: unrelated)
            for key in targetKeys { stored.aliases[key] = "Legacy" }
            XCTAssertNil(stored.settingAlias("Invalid\nAlias", for: current))
            XCTAssertNil(stored.settingAlias(String(repeating: "x", count: 129), for: current))
            XCTAssertEqual(stored.aliases.count, unrelated.count + targetKeys.count)
            let updated = try XCTUnwrap(stored.settingAlias("  Current desk  ", for: current))
            var expected = unrelated
            expected[bundleKey] = "Current desk"
            XCTAssertEqual(updated.aliases, expected)
            XCTAssertEqual(updated.hiddenKeys, stored.hiddenKeys)
            XCTAssertEqual(updated.displayName(for: current), "Current desk")
            XCTAssertEqual(updated.displayName(for: old), old.displayName)
            XCTAssertEqual(updated.settingAlias("Current desk", for: current), updated)
            let reloaded = try JSONDecoder().decode(
                AppManagementPreferences.self, from: JSONEncoder().encode(updated)
            )
            XCTAssertEqual(reloaded, updated)
            XCTAssertNil(reloaded.aliases[pathKey])
            XCTAssertEqual(reloaded.displayName(for: current), "Current desk")
            let visible = updated.settingHidden(false, for: current)
            XCTAssertTrue(visible.matches(current, query: query("original")))
            XCTAssertTrue(visible.matches(current, query: query("current")))
            XCTAssertFalse(visible.matches(current, query: query("legacy")))
        }
    }

    func testSingleIdentityWritesAndClearsRemainUnchangedForPathAndBundleRecords() throws {
        for app in [record(), record(bundleID: nil), record(bundleID: "")] {
            let key = AppManagementPreferences.key(for: app)
            let aliased = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Alias", for: app))
            let hidden = aliased.settingHidden(true, for: app)
            XCTAssertEqual(hidden.hiddenKeys, [key])
            XCTAssertEqual(hidden.aliases, [key: "Alias"])
            XCTAssertEqual(hidden.settingHidden(false, for: app), aliased)
            XCTAssertEqual(try XCTUnwrap(aliased.settingAlias(nil, for: app)), .default)
            XCTAssertEqual(try XCTUnwrap(aliased.settingAlias("  ", for: app)), .default)
        }
    }

    func testValidationAcceptsBothNonemptyReferencePrefixes() {
        let preferences = AppManagementPreferences(
            hiddenKeys: ["bundle:fixture.metadata.hidden", "path:/syntheticapps/hidden.app"],
            aliases: ["bundle:fixture.metadata.alias": "Alias", "path:/syntheticapps/alias.app": "Path alias"]
        )
        XCTAssertTrue(preferences.isValid)
    }

    func testValidationRejectsInvalidKeysInEachCollection() {
        for key in ["", "bundle:", "path:", "unknown:value", "Bundle:fixture", "bundleID:fixture"] {
            XCTAssertFalse(AppManagementPreferences(hiddenKeys: [key]).isValid)
            XCTAssertFalse(AppManagementPreferences(aliases: [key: "Alias"]).isValid)
        }
    }

    func testValidationRejectsUnnormalizedEmptyOversizedAndControlAliases() {
        let key = AppManagementPreferences.key(for: record())
        for alias in ["", " ", " Alias", "Alias ", "\nAlias", "A\tB", "A\u{0000}B", String(repeating: "x", count: 129)] {
            XCTAssertFalse(AppManagementPreferences(aliases: [key: alias]).isValid)
        }
        var preferences = AppManagementPreferences.default
        preferences.aliases[key] = " Raw "
        XCTAssertFalse(preferences.isValid)
        preferences.aliases[key] = "Normalized"
        XCTAssertTrue(preferences.isValid)
        preferences.hiddenKeys.insert("invalid")
        XCTAssertFalse(preferences.isValid)
    }

    func testCodableRoundTripPreservesBothReferenceKindsAndUnicodeAliases() throws {
        let preferences = AppManagementPreferences(
            hiddenKeys: ["bundle:fixture.metadata.hidden", "path:/syntheticapps/hidden.app"],
            aliases: ["bundle:fixture.metadata.alias": "Ｃａｆé", "path:/syntheticapps/alias.app": "Workspace 🇨🇦"]
        )
        for value in [AppManagementPreferences.default, preferences] {
            let json = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(AppManagementPreferences.self, from: json)
            XCTAssertEqual(decoded, value)
            XCTAssertTrue(decoded.isValid)
            let plist = try PropertyListEncoder().encode(value)
            XCTAssertEqual(try PropertyListDecoder().decode(AppManagementPreferences.self, from: plist), value)
        }
    }

    func testDecodingPreservesInvalidValuesForExplicitValidation() throws {
        let invalid = AppManagementPreferences(hiddenKeys: ["bundle:"],
                                               aliases: ["path:/syntheticapps/alias.app": " Unnormalized "])
        let decoded = try JSONDecoder().decode(AppManagementPreferences.self, from: JSONEncoder().encode(invalid))
        XCTAssertEqual(decoded, invalid)
        XCTAssertFalse(decoded.isValid)
    }

    func testMalformedCodableCollectionsAreRejected() {
        for fixture in [#"{"hiddenKeys":{},"aliases":{}}"#,
                        #"{"hiddenKeys":[],"aliases":{"bundle:fixture":1}}"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(AppManagementPreferences.self, from: Data(fixture.utf8)))
        }
    }
}
