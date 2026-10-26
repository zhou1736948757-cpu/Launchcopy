import AppGridUI
import Foundation
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class IdentifierSearchStoreTests: XCTestCase {
    private func defaults() throws -> UserDefaults {
        let suite = "fixture.identifier-search.\(UUID().uuidString)"
        let value = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return value
    }

    func testLegacyLoadPreservesMetadataAndBytesWithoutEnablingOrMigrating() throws {
        let defaults = try defaults()
        let legacy = Data(#"{"schemaVersion":1,"preferences":{"hiddenKeys":["bundle:fixture.hidden"],"aliases":{"bundle:fixture.alias":"Alias"}}}"#.utf8)
        defaults.set(legacy, forKey: UserDefaultsAppManagementStore.payloadKey)
        let store = UserDefaultsAppManagementStore(defaults: defaults)
        let expected = AppManagementPreferences(hiddenKeys: ["bundle:fixture.hidden"], aliases: ["bundle:fixture.alias": "Alias"])
        XCTAssertEqual(store.load(), .loaded(expected))
        XCTAssertFalse(store.load().preferences.searchByBundleIdentifier)
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppManagementStore.payloadKey), legacy)
    }

    func testExplicitToggleWritesSchemaTwoAndPreservesLegacyMetadata() throws {
        let defaults = try defaults()
        let legacy = Data(#"{"schemaVersion":1,"preferences":{"hiddenKeys":["bundle:fixture.hidden"],"aliases":{"bundle:fixture.alias":"Alias"}}}"#.utf8)
        defaults.set(legacy, forKey: UserDefaultsAppManagementStore.payloadKey)
        let store = UserDefaultsAppManagementStore(defaults: defaults)
        var applied: [AppManagementPreferences] = []
        let coordinator = AppManagementCoordinator(store: store) { applied.append($0) }
        XCTAssertEqual(coordinator.applySearchByBundleIdentifier(true), .saved)
        let data = try XCTUnwrap(defaults.data(forKey: UserDefaultsAppManagementStore.payloadKey))
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(payload["schemaVersion"] as? Int, 2)
        let value = try XCTUnwrap(payload["preferences"] as? [String: Any])
        XCTAssertEqual(value["searchByBundleIdentifier"] as? Bool, true)
        XCTAssertEqual(coordinator.committed.hiddenKeys, ["bundle:fixture.hidden"])
        XCTAssertEqual(coordinator.committed.aliases, ["bundle:fixture.alias": "Alias"])
        XCTAssertEqual(applied, [coordinator.committed])
        XCTAssertEqual(UserDefaultsAppManagementStore(defaults: defaults).load(), .loaded(coordinator.committed),
                       "Same-process reload only; not a process-restart durability gate")
    }

    func testMalformedSchemaTwoFlagCannotBeSilentlyRepairedByToggle() throws {
        let defaults = try defaults()
        for flag: String? in [nil, "\"yes\"", "null", "1"] {
            let suffix = flag.map { ",\"searchByBundleIdentifier\":" + $0 } ?? ""
            let raw = "{\"schemaVersion\":2,\"preferences\":{\"hiddenKeys\":[],\"aliases\":{}" + suffix + "}}"
            let bytes = Data(raw.utf8)
            XCTAssertNoThrow(try JSONSerialization.jsonObject(with: bytes))
            defaults.set(bytes, forKey: UserDefaultsAppManagementStore.payloadKey)
            let store = UserDefaultsAppManagementStore(defaults: defaults)
            XCTAssertEqual(store.load(), .corrupt)
            let coordinator = AppManagementCoordinator(store: store) { _ in XCTFail("Malformed data applied") }
            XCTAssertEqual(coordinator.applySearchByBundleIdentifier(true), .failed)
            XCTAssertEqual(defaults.data(forKey: UserDefaultsAppManagementStore.payloadKey), bytes)
        }
    }

    func testFutureSchemaTwoSuccessorIsProtectedFromToggle() throws {
        let defaults = try defaults()
        let bytes = Data(#"{"schemaVersion":3,"unknown":[true]}"#.utf8)
        defaults.set(bytes, forKey: UserDefaultsAppManagementStore.payloadKey)
        let store = UserDefaultsAppManagementStore(defaults: defaults)
        let coordinator = AppManagementCoordinator(store: store) { _ in XCTFail("Future applied") }
        XCTAssertEqual(store.load(), .futureVersion(3))
        XCTAssertEqual(coordinator.applySearchByBundleIdentifier(false), .futureVersion(3))
        XCTAssertEqual(coordinator.applySearchByBundleIdentifier(true), .futureVersion(3))
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppManagementStore.payloadKey), bytes)
    }

    private final class Store: AppManagementPersisting {
        var value = AppManagementPreferences.default
        var result: AppManagementSaveResult = .saved
        var saves = 0
        func load() -> AppManagementLoadResult { .loaded(value) }
        func save(_ preferences: AppManagementPreferences) -> AppManagementSaveResult {
            saves += 1
            if result == .saved { value = preferences }
            return result
        }
    }

    func testFailureRetainsBaselineAndRetryComposesWithAliasMetadata() {
        let store = Store()
        store.value.aliases = ["bundle:fixture.alias": "Alias"]
        var applies = 0
        let coordinator = AppManagementCoordinator(store: store) { _ in applies += 1 }
        store.result = .failed
        XCTAssertEqual(coordinator.applySearchByBundleIdentifier(true), .failed)
        XCTAssertFalse(coordinator.committed.searchByBundleIdentifier)
        XCTAssertEqual(applies, 0)
        store.result = .saved
        XCTAssertEqual(coordinator.applySearchByBundleIdentifier(true), .saved)
        XCTAssertTrue(coordinator.committed.searchByBundleIdentifier)
        XCTAssertEqual(coordinator.committed.aliases, ["bundle:fixture.alias": "Alias"])
        XCTAssertEqual(applies, 1)
        store.value.hiddenKeys.insert("bundle:fixture.concurrent")
        XCTAssertEqual(coordinator.applySearchByBundleIdentifier(false), .failed)
        XCTAssertTrue(store.value.searchByBundleIdentifier)
        XCTAssertEqual(store.value.hiddenKeys, ["bundle:fixture.concurrent"])
        XCTAssertEqual(store.saves, 2, "A detected different baseline is not overwritten")
    }
}
