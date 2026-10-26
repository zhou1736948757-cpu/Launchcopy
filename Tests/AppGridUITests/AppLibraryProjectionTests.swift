import AppCatalogCore
import AppGridUI
import Foundation
import XCTest

final class AppLibraryProjectionTests: XCTestCase {
    private let locale = Locale(identifier: "en_US_POSIX")

    private func record(_ name: String, path: String, declared: String? = nil,
                        bundleID: String? = nil) -> AppRecord {
        let url = URL(fileURLWithPath: path)
        let id = bundleID.map(AppID.bundleIdentifier) ?? .canonicalURLFallback(url)
        return AppRecord(id: id, displayName: name, bundleIdentifier: bundleID, canonicalURL: url,
                         iconIdentity: .from(appID: id), sourceRootPriority: 0,
                         bundleMetadata: .init(declaredCategoryIdentifier: declared, version: "1", build: "10"))
    }

    private func make(_ records: [AppRecord], management: AppManagementPreferences = .default,
                      preferences: AppLibraryPreferences = .default, query: String = "",
                      category: AppLibraryCategory? = nil) -> AppLibrarySnapshot {
        AppLibraryProjection.make(catalog: .init(revision: .init(42), records: records),
                                  management: management, preferences: preferences,
                                  query: query, category: category, locale: locale)
    }

    func testEmptyCatalogPreservesRevisionAndHasExplicitZeroCounts() {
        let snapshot = make([])
        XCTAssertEqual(snapshot.revision, .init(42))
        XCTAssertEqual(snapshot.entries, [])
        XCTAssertEqual(snapshot.counts.count, 22)
        XCTAssertTrue(snapshot.counts.values.allSatisfy { $0 == 0 })
    }

    func testEmptyAndWhitespaceQueriesMatchAllVisibleRecords() {
        let first = record("Alpha", path: "/SyntheticApps/Alpha.app", declared: "public.app-category.business")
        let second = record("Beta", path: "/SyntheticApps/Beta.app", declared: "public.app-category.games")
        let hidden = record("Hidden", path: "/SyntheticApps/Hidden.app")
        let management = AppManagementPreferences.default.settingHidden(true, for: hidden)
        for query in ["", " ", "\t\n\r", "\u{00A0}\u{3000}"] {
            let result = make([hidden, second, first], management: management, query: query)
            XCTAssertEqual(result.entries.map(\.record), [first, second])
            XCTAssertEqual(result.counts.values.reduce(0, +), 2)
            XCTAssertEqual(result.counts[.business], 1)
            XCTAssertEqual(result.counts[.games], 1)
            XCTAssertEqual(result.counts[.other], 0)
        }
    }

    func testEntryRetainsCanonicalOriginalAndMetadataWithAliasAndManualCategory() throws {
        let source = record("Original", path: "/SyntheticApps/Original.app",
                            declared: "public.app-category.utilities", bundleID: "fixture.library.original")
        let management = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Alias", for: source))
        let preferences = AppLibraryPreferences.default.settingCategory(.games, for: source)
        let snapshot = make([source], management: management, preferences: preferences)
        let entry = try XCTUnwrap(snapshot.entries.first)
        XCTAssertEqual(entry.record, source)
        XCTAssertEqual(entry.record.displayName, "Original")
        XCTAssertEqual(entry.record.bundleMetadata, source.bundleMetadata)
        XCTAssertEqual(entry.displayName, "Alias")
        XCTAssertEqual(entry.category, .games)
        XCTAssertEqual(entry.manualCategory, .games)
        XCTAssertEqual(snapshot.counts[.games], 1)
        XCTAssertEqual(snapshot.counts[.utilities], 0)
        XCTAssertEqual(snapshot.revision, .init(42))
    }

    func testSearchUsesOriginalOrEffectiveAliasWithExistingFoldingAndNotBundleIDOrPath() throws {
        let source = record("Café Original", path: "/SyntheticApps/LocationOnly.app",
                            bundleID: "fixture.library.identifieronly")
        let management = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Ｒésumé Workspace", for: source))
        for query in ["cafe", "ORIGINAL", "resume", "ｗｏｒｋｓｐａｃｅ", " resume ", "\n\t"] {
            XCTAssertEqual(make([source], management: management, query: query).entries.map(\.record), [source])
        }
        for query in ["identifieronly", "LocationOnly", "/SyntheticApps", "cafe resume", "missing"] {
            let snapshot = make([source], management: management, query: query)
            XCTAssertTrue(snapshot.entries.isEmpty)
            XCTAssertEqual(snapshot.counts.values.reduce(0, +), 0)
        }
    }

    func testHiddenPreferredAndPathFallbackRecordsAreExcludedFromResultsAndCounts() {
        let bundleHidden = record("Common One", path: "/SyntheticApps/One.app", bundleID: "fixture.library.one")
        let pathHidden = record("Common Two", path: "/SyntheticApps/Two.app", bundleID: "fixture.library.two")
        let visible = record("Common Three", path: "/SyntheticApps/Three.app",
                             declared: "public.app-category.business")
        let management = AppManagementPreferences(hiddenKeys: [
            AppManagementPreferences.key(for: bundleHidden), "path:/syntheticapps/two.app"
        ])
        let snapshot = make([bundleHidden, pathHidden, visible], management: management, query: "common")
        XCTAssertEqual(snapshot.entries.map(\.record), [visible])
        XCTAssertEqual(snapshot.counts[.business], 1)
        XCTAssertEqual(snapshot.counts[.other], 0)
        XCTAssertEqual(snapshot.counts.values.reduce(0, +), 1)
    }

    func testCountsUseVisibleQueryMatchesBeforeCategoryFiltering() {
        let business = record("Shared Business", path: "/SyntheticApps/Business.app",
                              declared: "public.app-category.business")
        let game = record("Shared Game", path: "/SyntheticApps/Game.app",
                          declared: "public.app-category.action-games")
        let other = record("Shared Other", path: "/SyntheticApps/Other.app")
        let excluded = record("Different Video", path: "/SyntheticApps/Video.app",
                              declared: "public.app-category.video")
        let records = [other, excluded, game, business]
        let all = make(records, query: "shared")
        let selected = make(records, query: "shared", category: .business)
        let emptySelection = make(records, query: "shared", category: .video)
        XCTAssertEqual(all.entries.count, 3)
        XCTAssertEqual(selected.entries.map(\.record), [business])
        XCTAssertTrue(emptySelection.entries.isEmpty)
        XCTAssertEqual(selected.counts, all.counts)
        XCTAssertEqual(emptySelection.counts, all.counts)
        XCTAssertEqual(all.counts[.business], 1)
        XCTAssertEqual(all.counts[.games], 1)
        XCTAssertEqual(all.counts[.other], 1)
        XCTAssertEqual(all.counts[.video], 0)
    }

    func testAliasSortAndCanonicalURLTieAreDeterministicAcrossInputOrders() throws {
        let renamed = record("Zulu", path: "/SyntheticApps/Renamed.app")
        let tieA = record("Beta", path: "/SyntheticApps/A.app")
        let tieZ = record("BETA", path: "/SyntheticApps/Z.app")
        let last = record("Omega", path: "/SyntheticApps/Last.app")
        let management = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Alpha", for: renamed))
        let expected = [renamed, tieA, tieZ, last]
        for input in [[last, tieZ, renamed, tieA], [tieA, renamed, last, tieZ], expected.reversed().map { $0 }] {
            XCTAssertEqual(make(input, management: management).entries.map(\.record), expected)
        }
    }

    func testSuppliedLocaleControlsSearchAndNameOrdering() {
        let zulu = record("Zulu", path: "/SyntheticApps/Zulu.app")
        let umlaut = record("Äpp", path: "/SyntheticApps/Umlaut.app")
        let records = [zulu, umlaut]
        let catalog = CatalogSnapshot(revision: .init(9), records: records)
        for locale in [Locale(identifier: "en_US_POSIX"), Locale(identifier: "sv_SE")] {
            let expected = records.sorted {
                $0.displayName.compare($1.displayName, options: [.caseInsensitive], range: nil, locale: locale)
                    == .orderedAscending
            }
            let result = AppLibraryProjection.make(catalog: catalog, management: .default,
                                                   preferences: .default, locale: locale)
            XCTAssertEqual(result.entries.map(\.record), expected)
            let search = AppLibraryProjection.make(catalog: catalog, management: .default,
                                                   preferences: .default, query: "app", locale: locale)
            XCTAssertEqual(search.entries.map(\.record), [umlaut])
        }
    }

    func testCatalogAbsenceAndProjectionDoNotPruneDormantPreferences() {
        let present = record("Present", path: "/SyntheticApps/Present.app", bundleID: "fixture.library.present")
        let absent = record("Absent", path: "/SyntheticApps/Absent.app", bundleID: "fixture.library.absent")
        let preferences = AppLibraryPreferences.default.settingCategory(.medical, for: absent)
        let stored = preferences
        XCTAssertEqual(make([present], preferences: preferences).entries.count, 1)
        XCTAssertTrue(make([], preferences: preferences).entries.isEmpty)
        let returned = make([absent], preferences: preferences)
        XCTAssertEqual(returned.entries.first?.manualCategory, .medical)
        XCTAssertEqual(preferences, stored)
        XCTAssertFalse(preferences.enabled, "Enablement is an owner scheduling decision, not a projection mutation")
    }

    func testPublicValueInitializersSupportOwnerEmptyAndErrorStateComposition() {
        let source = record("Fixture", path: "/SyntheticApps/Fixture.app")
        let entry = AppLibraryEntry(record: source, displayName: "Fixture", category: .other)
        let snapshot = AppLibrarySnapshot(revision: .init(12), entries: [entry], counts: [.other: 1])
        XCTAssertEqual(snapshot.revision, .init(12))
        XCTAssertEqual(snapshot.entries.first?.record, source)
        XCTAssertNil(snapshot.entries.first?.manualCategory)
        XCTAssertEqual(snapshot.counts[.other], 1)
    }
}
