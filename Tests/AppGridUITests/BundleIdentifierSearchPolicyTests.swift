import AppCatalogCore
import AppGridUI
import Foundation
import XCTest

@MainActor
final class BundleIdentifierSearchPolicyTests: XCTestCase {
    private let locale = Locale(identifier: "en_US_POSIX")

    private func record(_ name: String = "Original", bundleID: String? = "com.fixture.identifieronly",
                        path: String = "/SyntheticApps/LocationOnly.app", id: AppID? = nil) -> AppRecord {
        let url = URL(fileURLWithPath: path)
        let identity = id ?? bundleID.flatMap { $0.isEmpty ? nil : AppID.bundleIdentifier($0) }
            ?? .canonicalURLFallback(url)
        return AppRecord(id: identity, displayName: name, bundleIdentifier: bundleID,
                         canonicalURL: url, iconIdentity: .from(appID: identity), sourceRootPriority: 7,
                         bundleMetadata: .init(declaredCategoryIdentifier: "public.app-category.utilities",
                                               version: "2", build: "10"))
    }

    /// Exercise the real shared-policy consumers, including the grid's idle commit.
    private func assertConsumers(_ records: [AppRecord], management: AppManagementPreferences,
                                 query raw: String, expected: [AppRecord],
                                 libraryOrder: [AppRecord]? = nil,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let catalog = CatalogSnapshot(revision: .init(42), records: records)
        let controller = AppGridSearchPresentationController(
            provider: AppGridUIPageContentProvider(snapshot: catalog))
        controller.provider.receiveManagementPreferences(management)
        controller.applyPendingAtIdleBoundary(currentPage: 0)
        let query = AppSearchQuery(raw: raw, locale: locale)
        controller.updateQuery(query)
        controller.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(controller.provider.presentationRecords,
                       expected.map { management.presentationRecord(for: $0) }, file: file, line: line)
        XCTAssertEqual(controller.provider.servedSnapshot, catalog, file: file, line: line)
        XCTAssertEqual(controller.currentQuery, query, file: file, line: line)
        let library = AppLibraryProjection.make(catalog: catalog, management: management,
                                                preferences: .default, query: raw, locale: locale)
        let ordered = libraryOrder ?? expected
        XCTAssertEqual(library.entries.map(\.record), ordered, file: file, line: line)
        XCTAssertEqual(library.entries.map(\.displayName), ordered.map { management.displayName(for: $0) },
                       file: file, line: line)
        XCTAssertEqual(library.counts.values.reduce(0, +), expected.count, file: file, line: line)
        XCTAssertEqual(library.revision, catalog.revision, file: file, line: line)
    }

    func testDefaultAndExistingInitializerFormsKeepIdentifierSearchOff() {
        let app = record()
        let key = AppManagementPreferences.key(for: app)
        let values = [AppManagementPreferences.default, AppManagementPreferences(),
                      AppManagementPreferences(hiddenKeys: []),
                      AppManagementPreferences(aliases: [key: "Workspace"]),
                      AppManagementPreferences(hiddenKeys: [], aliases: [key: "Workspace"])]
        for preferences in values {
            XCTAssertFalse(preferences.searchByBundleIdentifier)
            assertConsumers([app], management: preferences, query: "identifieronly", expected: [])
            assertConsumers([app], management: preferences, query: "original", expected: [app])
        }
    }

    func testOriginalAndAliasRemainIndependentSearchBranchesInBothModes() throws {
        let app = record("Café Original")
        for enabled in [false, true] {
            let preferences = try XCTUnwrap(AppManagementPreferences(searchByBundleIdentifier: enabled)
                .settingAlias("Ｒésumé Workspace", for: app))
            for raw in ["cafe", "ORIGINAL", "resume", "  ｗｏｒｋｓｐａｃｅ\n"] {
                assertConsumers([app], management: preferences, query: raw, expected: [app])
            }
            for raw in ["cafe resume", "original workspace", "unrelated"] {
                assertConsumers([app], management: preferences, query: raw, expected: [])
            }
        }
    }

    func testEnabledCanonicalIdentifierUsesTrimCaseDiacriticWidthAndLiteralSubstrings() {
        let app = record(bundleID: "Ｃｏｍ.Fixture.Café[Desk]*?")
        let preferences = AppManagementPreferences(searchByBundleIdentifier: true)
        for raw in ["  COM.FIXTURE.CAFE[DESK]*?\n", "fixture.cafe", "ｃａｆｅ", "[desk]", "*?", "."] {
            assertConsumers([app], management: preferences, query: raw, expected: [app])
        }
        for raw in ["comXfixture", "com.*", "cafe.*", "[d-z]", "id:com", "^com", "fixture cafe"] {
            assertConsumers([app], management: preferences, query: raw, expected: [])
        }
        // The public name-only matcher keeps its existing contract even with identifier matching enabled elsewhere.
        XCTAssertFalse(AppSearchMatcher().matches(app, query: .init(raw: "fixture.cafe", locale: locale)))
    }

    func testIdentifierFoldingUsesTheQueryLocale() {
        let app = record(bundleID: "COM.FIXTURE.I")
        let preferences = AppManagementPreferences(searchByBundleIdentifier: true)
        let turkish = Locale(identifier: "tr_TR")
        XCTAssertTrue(preferences.matches(app, query: .init(raw: "ı", locale: turkish)))
        XCTAssertFalse(preferences.matches(app, query: .init(raw: "ı", locale: locale)))
        XCTAssertEqual(AppLibraryProjection.make(
            catalog: .init(revision: .init(42), records: [app]), management: preferences,
            preferences: .default, query: "ı", locale: turkish).entries.map(\.record), [app])
        let controller = AppGridSearchPresentationController(
            provider: AppGridUIPageContentProvider(snapshot: .init(revision: .init(42), records: [app])))
        controller.provider.receiveManagementPreferences(preferences)
        controller.applyPendingAtIdleBoundary(currentPage: 0)
        controller.updateQuery(.init(raw: "ı", locale: turkish))
        controller.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(controller.provider.presentationRecords, [app])
    }

    func testMissingAndEmptyIdentifierNeverFallBackToAppIDPathOrOtherMetadata() {
        for identifier: String? in [nil, "", "com.fixture.actual"] {
            let app = record(bundleID: identifier, path: "/SyntheticApps/PathOnly.app",
                             id: .bundleIdentifier("com.fixture.identityonly"))
            let preferences = AppManagementPreferences(searchByBundleIdentifier: true)
            for raw in ["identityonly", "PathOnly", "/SyntheticApps", ".app", "utilities", "public.app-category", "id:"] {
                assertConsumers([app], management: preferences, query: raw, expected: [])
            }
            assertConsumers([app], management: preferences, query: "com.fixture.actual",
                            expected: identifier == "com.fixture.actual" ? [app] : [])
            assertConsumers([app], management: preferences, query: "original", expected: [app])
        }
    }

    func testHiddenRecordsAreExcludedBeforeNameAliasIdentifierAndEmptyQuery() {
        let app = record()
        for enabled in [false, true] {
            for hiddenKey in [AppManagementPreferences.key(for: app), "path:/syntheticapps/locationonly.app"] {
                let preferences = AppManagementPreferences(hiddenKeys: [hiddenKey],
                    aliases: [AppManagementPreferences.key(for: app): "Workspace"],
                    searchByBundleIdentifier: enabled)
                for raw in ["", " \t\n", "original", "workspace", "identifieronly"] {
                    XCTAssertFalse(preferences.matches(app, query: .init(raw: raw, locale: locale)))
                    assertConsumers([app], management: preferences, query: raw, expected: [])
                }
            }
        }
    }

    func testEmptyQueriesKeepVisibleRecordsWithoutIdentifiersInBothModes() {
        let missing = record("Alpha", bundleID: nil, path: "/SyntheticApps/Alpha.app")
        let empty = record("Beta", bundleID: "", path: "/SyntheticApps/Beta.app")
        let hidden = record("Hidden")
        for enabled in [false, true] {
            let preferences = AppManagementPreferences(
                hiddenKeys: [AppManagementPreferences.key(for: hidden)], searchByBundleIdentifier: enabled)
            for raw in ["", " ", "\t\n\r", "\u{00A0}\u{3000}"] {
                assertConsumers([hidden, empty, missing], management: preferences, query: raw,
                                expected: [empty, missing], libraryOrder: [missing, empty])
            }
        }
    }

    func testSameQueryPolicyToggleRecomputesBothConsumersWithoutChangingCatalog() {
        let app = record()
        let catalog = CatalogSnapshot(revision: .init(42), records: [app])
        let query = AppSearchQuery(raw: "identifieronly", locale: locale)
        let controller = AppGridSearchPresentationController(
            provider: AppGridUIPageContentProvider(snapshot: catalog))
        controller.updateQuery(query)
        controller.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertTrue(controller.provider.presentationRecords.isEmpty)
        var generation = controller.latestGeneration
        for enabled in [true, false, true] {
            let preferences = AppManagementPreferences(searchByBundleIdentifier: enabled)
            let previousRecords = controller.provider.presentationRecords
            controller.provider.receiveManagementPreferences(preferences)
            // Staging preferences alone cannot publish results under a different policy.
            XCTAssertEqual(controller.provider.presentationRecords, previousRecords)
            XCTAssertEqual(controller.currentQuery, query)
            XCTAssertEqual(controller.latestGeneration, generation)
            controller.applyPendingAtIdleBoundary(currentPage: 0)
            XCTAssertEqual(controller.latestGeneration, generation.incremented())
            generation = controller.latestGeneration
            XCTAssertEqual(controller.provider.presentationRecords, enabled ? [app] : [])
            XCTAssertEqual(controller.provider.servedSnapshot, catalog)
            XCTAssertEqual(controller.currentQuery, query)
            let library = AppLibraryProjection.make(catalog: catalog, management: preferences,
                preferences: .default, query: query.raw, locale: query.locale)
            XCTAssertEqual(library.entries.map(\.record), enabled ? [app] : [])
            XCTAssertEqual(library.revision, catalog.revision)
        }
    }

    func testIdentifierMatchesPreserveGridOrderLibraryAliasSortAndCanonicalIdentity() throws {
        let zulu = record("Zulu", bundleID: "com.fixture.shared.zulu", path: "/SyntheticApps/Zulu.app")
        let alpha = record("Alpha", bundleID: "com.fixture.shared.alpha", path: "/SyntheticApps/Alpha.app")
        let hidden = record("Hidden", bundleID: "com.fixture.shared.hidden", path: "/SyntheticApps/Hidden.app")
        let preferences = try XCTUnwrap(AppManagementPreferences(searchByBundleIdentifier: true)
            .settingAlias("Aardvark", for: zulu)).settingHidden(true, for: hidden)
        assertConsumers([alpha, hidden, zulu], management: preferences, query: "shared",
                        expected: [alpha, zulu], libraryOrder: [zulu, alpha])
        let presented = preferences.presentationRecord(for: zulu)
        XCTAssertEqual(presented.displayName, "Aardvark")
        XCTAssertEqual(presented.id, zulu.id)
        XCTAssertEqual(presented.bundleIdentifier, zulu.bundleIdentifier)
        XCTAssertEqual(presented.canonicalURL, zulu.canonicalURL)
        XCTAssertEqual(presented.iconIdentity, zulu.iconIdentity)
        XCTAssertEqual(presented.sourceRootPriority, zulu.sourceRootPriority)
        XCTAssertEqual(presented.bundleMetadata, zulu.bundleMetadata)
        XCTAssertEqual(zulu.displayName, "Zulu")
    }

    func testHideAndAliasCopiesPreserveBothFlagValuesAndUnrelatedMetadata() throws {
        let app = record()
        let key = AppManagementPreferences.key(for: app)
        let pathKey = "path:/syntheticapps/locationonly.app"
        let unrelated = "bundle:com.fixture.unrelated"
        for enabled in [false, true] {
            let original = AppManagementPreferences(hiddenKeys: [pathKey, unrelated],
                aliases: [pathKey: "Legacy", unrelated: "Unrelated"], searchByBundleIdentifier: enabled)
            let hidden = original.settingHidden(true, for: app)
            let visible = hidden.settingHidden(false, for: app)
            let aliased = try XCTUnwrap(visible.settingAlias("  Workspace  ", for: app))
            let reset = try XCTUnwrap(aliased.settingAlias(nil, for: app))
            let blankReset = try XCTUnwrap(aliased.settingAlias(" \n ", for: app))
            for copy in [hidden, visible, aliased, reset, blankReset] {
                XCTAssertEqual(copy.searchByBundleIdentifier, enabled)
                XCTAssertTrue(copy.hiddenKeys.contains(unrelated))
                XCTAssertEqual(copy.aliases[unrelated], "Unrelated")
            }
            XCTAssertEqual(hidden.hiddenKeys, [key, pathKey, unrelated])
            XCTAssertEqual(visible.hiddenKeys, [unrelated])
            XCTAssertEqual(aliased.aliases, [key: "Workspace", unrelated: "Unrelated"])
            XCTAssertEqual(reset.aliases, [unrelated: "Unrelated"])
            XCTAssertEqual(blankReset, reset)
            XCTAssertNil(aliased.settingAlias("Invalid\nAlias", for: app))
            XCTAssertEqual(original.hiddenKeys, [pathKey, unrelated])
            XCTAssertEqual(original.aliases[pathKey], "Legacy")
            XCTAssertEqual(original.searchByBundleIdentifier, enabled)
        }
    }

    func testSynthesizedCodableRoundTripsBothFlagsWithoutChangingMetadata() throws {
        for enabled in [false, true] {
            let preferences = AppManagementPreferences(
                hiddenKeys: ["bundle:com.fixture.hidden", "path:/syntheticapps/hidden.app"],
                aliases: ["bundle:com.fixture.alias": "Ｃａｆé"], searchByBundleIdentifier: enabled)
            let json = try JSONEncoder().encode(preferences)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
            XCTAssertEqual(object["searchByBundleIdentifier"] as? Bool, enabled)
            XCTAssertEqual(try JSONDecoder().decode(AppManagementPreferences.self, from: json), preferences)
            let plist = try PropertyListEncoder().encode(preferences)
            XCTAssertEqual(try PropertyListDecoder().decode(AppManagementPreferences.self, from: plist), preferences)
        }
    }

    func testSynthesizedDecodingRequiresBooleanRatherThanDefaultingMissingOrMalformedValue() throws {
        let missing = Data(#"{"hiddenKeys":[],"aliases":{}}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(AppManagementPreferences.self, from: missing)) { error in
            guard case DecodingError.keyNotFound(let key, _) = error else {
                return XCTFail("Expected a missing required boolean key")
            }
            XCTAssertEqual(key.stringValue, "searchByBundleIdentifier")
        }
        for flag in ["null", "0", "1", #""true""#, "[]", "{}"] {
            let json = "{\"hiddenKeys\":[],\"aliases\":{},\"searchByBundleIdentifier\":\(flag)}"
            XCTAssertThrowsError(try JSONDecoder().decode(AppManagementPreferences.self, from: Data(json.utf8)))
        }
        let legacy: [String: Any] = ["hiddenKeys": [String](), "aliases": [String: String]()]
        let plist = try PropertyListSerialization.data(fromPropertyList: legacy, format: .binary, options: 0)
        XCTAssertThrowsError(try PropertyListDecoder().decode(AppManagementPreferences.self, from: plist))
    }
}
