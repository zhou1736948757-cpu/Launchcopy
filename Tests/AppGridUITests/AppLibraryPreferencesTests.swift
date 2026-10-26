import AppCatalogCore
import AppGridUI
import Foundation
import XCTest

final class AppLibraryPreferencesTests: XCTestCase {
    private func record(bundleID: String? = "fixture.library.preferences",
                        path: String = "/SyntheticApps/Original.app",
                        declared: String? = "public.app-category.utilities") -> AppRecord {
        let url = URL(fileURLWithPath: path)
        let id = bundleID.map(AppID.bundleIdentifier) ?? .canonicalURLFallback(url)
        return AppRecord(id: id, displayName: "Original", bundleIdentifier: bundleID,
                         canonicalURL: url, iconIdentity: .from(appID: id), sourceRootPriority: 0,
                         bundleMetadata: .init(declaredCategoryIdentifier: declared))
    }

    func testDefaultsDisabledAndAutomaticClassificationUsesOnlyDeclaration() {
        let preferences = AppLibraryPreferences.default
        XCTAssertFalse(preferences.enabled)
        XCTAssertTrue(preferences.categoryOverrides.isEmpty)
        XCTAssertTrue(preferences.isValid)
        XCTAssertNil(preferences.manualCategory(for: record()))
        XCTAssertEqual(preferences.category(for: record()), .utilities)
        XCTAssertEqual(preferences.category(for: record(declared: nil)), .other)
        XCTAssertEqual(preferences.category(for: record(declared: "public.app-category.unknown-games")), .other)
    }

    func testPreferredBundleOverridePrecedesPathAndReadDoesNotMigrate() {
        let old = record(bundleID: nil)
        let current = record()
        let pathKey = AppManagementPreferences.key(for: old)
        let bundleKey = AppManagementPreferences.key(for: current)
        let fallback = AppLibraryPreferences(categoryOverrides: [pathKey: .games])
        XCTAssertEqual(fallback.manualCategory(for: current), .games)
        XCTAssertEqual(fallback.category(for: current), .games)
        XCTAssertNil(fallback.categoryOverrides[bundleKey])
        let both = AppLibraryPreferences(categoryOverrides: [pathKey: .games, bundleKey: .business])
        XCTAssertEqual(both.category(for: current), .business)
        XCTAssertEqual(both.category(for: old), .games)
        XCTAssertEqual(both.categoryOverrides, [pathKey: .games, bundleKey: .business])
    }

    func testExplicitChoiceReplacesPathOverrideAndPreservesDormantEntriesAndEnabled() {
        let current = record()
        let path = AppManagementPreferences.key(for: record(bundleID: nil))
        let bundle = AppManagementPreferences.key(for: current)
        let stored = AppLibraryPreferences(enabled: true, categoryOverrides: [
            path: .games, "bundle:fixture.library.absent": .education
        ])
        let updated = stored.settingCategory(.other, for: current)
        XCTAssertEqual(updated.categoryOverrides, [bundle: .other, "bundle:fixture.library.absent": .education])
        XCTAssertTrue(updated.enabled)
        XCTAssertEqual(updated.manualCategory(for: current), .other)
        XCTAssertEqual(updated.category(for: current), .other)
        XCTAssertEqual(updated.settingCategory(.other, for: current), updated)
        XCTAssertEqual(stored.categoryOverrides[path], .games)
    }

    func testAutomaticResetClearsPreferredAndPathKeysInEveryCombination() {
        let current = record()
        let path = AppManagementPreferences.key(for: record(bundleID: nil))
        let bundle = AppManagementPreferences.key(for: current)
        for keys in [[path], [bundle], [path, bundle]] {
            var stored = AppLibraryPreferences(enabled: true, categoryOverrides: ["bundle:dormant": .music])
            for key in keys { stored.categoryOverrides[key] = .games }
            let reset = stored.settingCategory(nil, for: current)
            XCTAssertEqual(reset.categoryOverrides, ["bundle:dormant": .music])
            XCTAssertTrue(reset.enabled)
            XCTAssertNil(reset.manualCategory(for: current))
            XCTAssertEqual(reset.category(for: current), .utilities)
            XCTAssertEqual(reset.settingCategory(nil, for: current), reset)
            XCTAssertEqual(stored.categoryOverrides.count, keys.count + 1)
        }
    }

    func testPathIdentityUsesExistingCanonicalNormalizationAndBundleMatchingIsExact() {
        let preferences = AppLibraryPreferences(categoryOverrides: [
            "path:/syntheticapps/original.app": .photography,
            "bundle:Fixture.Library.Preferences": .finance
        ])
        XCTAssertEqual(preferences.manualCategory(for: record(path: "/SyntheticApps/Sub/../Original.app/")), .photography)
        XCTAssertNil(preferences.manualCategory(for: record(path: "/SyntheticApps/Moved.app")))
        XCTAssertEqual(preferences.manualCategory(for: record(bundleID: "Fixture.Library.Preferences")), .finance)
        for bundleID: String? in [nil, ""] {
            let app = record(bundleID: bundleID)
            let updated = AppLibraryPreferences.default.settingCategory(.news, for: app)
            XCTAssertEqual(updated.categoryOverrides, ["path:/syntheticapps/original.app": .news])
            XCTAssertEqual(updated.settingCategory(nil, for: app), .default)
        }
    }

    func testJSONAndPlistRoundTripsRetainDormantOverridesWithoutEnablement() throws {
        let value = AppLibraryPreferences(categoryOverrides: ["bundle:absent": .games, "path:/absent.app": .weather])
        let json = try JSONDecoder().decode(AppLibraryPreferences.self, from: JSONEncoder().encode(value))
        let plist = try PropertyListDecoder().decode(AppLibraryPreferences.self, from: PropertyListEncoder().encode(value))
        XCTAssertEqual(json, value)
        XCTAssertEqual(plist, value)
        XCTAssertFalse(json.enabled)
        XCTAssertTrue(json.isValid)
    }

    func testInvalidKeysArePreservedByDecodingForExplicitValidation() throws {
        for key in ["", "bundle:", "path:", "unknown:value", "Bundle:fixture", "bundleID:fixture"] {
            let invalid = AppLibraryPreferences(categoryOverrides: [key: .games])
            XCTAssertFalse(invalid.isValid)
            let decoded = try JSONDecoder().decode(AppLibraryPreferences.self, from: JSONEncoder().encode(invalid))
            XCTAssertEqual(decoded, invalid)
            XCTAssertFalse(decoded.isValid)
        }
    }

    func testMalformedTypesAndUnknownStoredCategoriesAreRejected() {
        for fixture in [#"{"enabled":"false","categoryOverrides":{}}"#,
                        #"{"enabled":false,"categoryOverrides":[]}"#,
                        #"{"enabled":false,"categoryOverrides":{"bundle:fixture":"all"}}"#,
                        #"{"enabled":false,"categoryOverrides":{"bundle:fixture":"future-category"}}"#,
                        #"{"enabled":false,"categoryOverrides":{"bundle:fixture":5}}"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(AppLibraryPreferences.self, from: Data(fixture.utf8)))
        }
    }
}
