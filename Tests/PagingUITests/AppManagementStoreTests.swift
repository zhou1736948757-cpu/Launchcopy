import AppGridUI
import Foundation
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class AppManagementStoreTests: XCTestCase {
    private final class Store: AppManagementPersisting {
        var loaded: AppManagementLoadResult = .loaded(.default)
        var result: AppManagementSaveResult = .saved
        var saved: [AppManagementPreferences] = []
        var events: [String] = []

        func load() -> AppManagementLoadResult { loaded }
        func save(_ preferences: AppManagementPreferences) -> AppManagementSaveResult {
            events.append("save")
            saved.append(preferences)
            if result == .saved { loaded = .loaded(preferences) }
            return result
        }
    }

    private func defaults() throws -> UserDefaults {
        let suite = "fixture.app-management.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return defaults
    }

    private var changed: AppManagementPreferences {
        .init(hiddenKeys: ["bundle:fixture.management.hidden"],
              aliases: ["path:/syntheticapps/alias.app": "Workspace"])
    }

    func testMissingPayloadLoadsDefaultsWithoutWriting() throws {
        let defaults = try defaults()
        let store = UserDefaultsAppManagementStore(defaults: defaults)
        XCTAssertEqual(store.load(), .loaded(.default))
        XCTAssertNil(defaults.object(forKey: UserDefaultsAppManagementStore.payloadKey))
    }

    func testPayloadRoundTripsThroughNewStoreAndPreservesForeignKeys() throws {
        let defaults = try defaults()
        defaults.set("untouched", forKey: "fixture.foreign")
        let store = UserDefaultsAppManagementStore(defaults: defaults)
        XCTAssertEqual(store.save(changed), .saved)
        XCTAssertEqual(UserDefaultsAppManagementStore(defaults: defaults).load(), .loaded(changed))
        XCTAssertEqual(defaults.string(forKey: "fixture.foreign"), "untouched")
    }

    func testCorruptPayloadsRemainUntouchedUntilExplicitRepair() throws {
        let defaults = try defaults()
        let key = UserDefaultsAppManagementStore.payloadKey
        let payloads: [Any] = [
            "wrong stored type",
            Data("not JSON".utf8),
            Data(#"{"schemaVersion":0,"preferences":{"hiddenKeys":[],"aliases":{}}}"#.utf8),
            Data(#"{"schemaVersion":1}"#.utf8),
            Data(#"{"schemaVersion":1,"preferences":{"hiddenKeys":["bundle:"],"aliases":{}}}"#.utf8),
            Data(#"{"schemaVersion":1,"preferences":{"hiddenKeys":[],"aliases":{"bundle:fixture.invalid":" Raw "}}}"#.utf8),
            Data(repeating: 0, count: 1_048_577)
        ]
        for payload in payloads {
            defaults.set(payload, forKey: key)
            let before = try XCTUnwrap(defaults.object(forKey: key) as? NSObject)
            let store = UserDefaultsAppManagementStore(defaults: defaults)
            XCTAssertEqual(store.load(), .corrupt)
            XCTAssertEqual(store.load().preferences, .default)
            XCTAssertEqual(defaults.object(forKey: key) as? NSObject, before)
            XCTAssertEqual(store.save(.default), .saved)
            XCTAssertEqual(store.load(), .loaded(.default))
        }
    }

    func testFutureSchemaWithUnknownShapeRejectsOverwrite() throws {
        let defaults = try defaults()
        let future = Data(#"{"schemaVersion":9,"newerField":[1,2,3]}"#.utf8)
        defaults.set(future, forKey: UserDefaultsAppManagementStore.payloadKey)
        let store = UserDefaultsAppManagementStore(defaults: defaults)
        XCTAssertEqual(store.load(), .futureVersion(9))
        XCTAssertEqual(store.load().preferences, .default)
        for preferences in [AppManagementPreferences.default, changed] {
            XCTAssertEqual(store.save(preferences), .futureVersion(9))
            XCTAssertEqual(defaults.data(forKey: UserDefaultsAppManagementStore.payloadKey), future)
        }
    }

    func testInvalidAndOversizedSavesPreservePreviousPayload() throws {
        let defaults = try defaults()
        let store = UserDefaultsAppManagementStore(defaults: defaults)
        XCTAssertEqual(store.save(changed), .saved)
        let before = defaults.data(forKey: UserDefaultsAppManagementStore.payloadKey)
        XCTAssertEqual(store.save(.init(hiddenKeys: ["invalid"])), .invalidPreferences)
        // Valid aliases whose aggregate encoding exceeds the store's bounded payload size.
        let oversized = AppManagementPreferences(aliases: Dictionary(uniqueKeysWithValues:
            (0..<9_000).map { ("bundle:fixture.management.\($0)", String(repeating: "x", count: 128)) }))
        XCTAssertTrue(oversized.isValid)
        XCTAssertEqual(store.save(oversized), .failed)
        XCTAssertEqual(defaults.data(forKey: UserDefaultsAppManagementStore.payloadKey), before)
        XCTAssertEqual(store.load(), .loaded(changed))
    }

    func testInMemoryStoreRoundTripsAndRejectsInvalidMutation() {
        let store = InMemoryAppManagementStore()
        XCTAssertEqual(store.load(), .loaded(.default))
        XCTAssertEqual(store.save(changed), .saved)
        XCTAssertEqual(store.save(.init(aliases: ["bundle:fixture.invalid": ""])), .invalidPreferences)
        XCTAssertEqual(store.load(), .loaded(changed))
    }

    func testCoordinatorLoadsWithoutApplyingAndSavesBeforeCallback() {
        let store = Store()
        store.loaded = .loaded(changed)
        var applied: [AppManagementPreferences] = []
        let coordinator = AppManagementCoordinator(store: store) { preferences in
            XCTAssertEqual(store.loaded, .loaded(preferences))
            XCTAssertEqual(store.saved.last, preferences)
            store.events.append("apply")
            applied.append(preferences)
        }
        XCTAssertEqual(coordinator.committed, changed)
        XCTAssertEqual(coordinator.loadResult, .loaded(changed))
        XCTAssertTrue(store.events.isEmpty)
        XCTAssertEqual(coordinator.apply(.default), .saved)
        XCTAssertEqual(store.events, ["save", "apply"])
        XCTAssertEqual(applied, [.default])
        XCTAssertEqual(coordinator.committed, .default)
        XCTAssertEqual(coordinator.loadResult, .loaded(.default))
    }

    func testEqualCommittedPreferencesAreNoOpBeforeAndAfterChange() {
        let store = Store()
        var applies = 0
        let coordinator = AppManagementCoordinator(store: store) { _ in applies += 1 }
        XCTAssertEqual(coordinator.apply(.default), .saved)
        XCTAssertTrue(store.saved.isEmpty)
        XCTAssertEqual(applies, 0)
        XCTAssertEqual(coordinator.apply(changed), .saved)
        XCTAssertEqual(coordinator.apply(changed), .saved)
        XCTAssertEqual(store.saved, [changed])
        XCTAssertEqual(applies, 1)
    }

    func testRejectedSavesDoNotCommitOrApplyAndCanBeRetried() {
        for result: AppManagementSaveResult in [.failed, .invalidPreferences, .futureVersion(4)] {
            let store = Store()
            store.result = result
            var applied: [AppManagementPreferences] = []
            let coordinator = AppManagementCoordinator(store: store) { applied.append($0) }
            XCTAssertEqual(coordinator.apply(changed), result)
            XCTAssertEqual(coordinator.committed, .default)
            XCTAssertEqual(coordinator.loadResult, .loaded(.default))
            XCTAssertTrue(applied.isEmpty)
            store.result = .saved
            XCTAssertEqual(coordinator.apply(changed), .saved)
            XCTAssertEqual(store.saved, [changed, changed])
            XCTAssertEqual(applied, [changed])
        }
    }

    func testInvalidDraftNeverReachesStoreOrCallback() {
        let store = Store()
        let coordinator = AppManagementCoordinator(store: store) { _ in XCTFail("Invalid draft applied") }
        XCTAssertEqual(coordinator.apply(.init(hiddenKeys: ["bundle:"])), .invalidPreferences)
        XCTAssertTrue(store.saved.isEmpty)
        XCTAssertEqual(coordinator.committed, .default)
        XCTAssertEqual(coordinator.loadResult, .loaded(.default))
    }

    func testFutureSchemaRejectsEqualAndChangedDraftsWithoutSaving() {
        let store = Store()
        store.loaded = .futureVersion(3)
        let coordinator = AppManagementCoordinator(store: store) { _ in XCTFail("Future schema applied") }
        XCTAssertEqual(coordinator.committed, .default)
        XCTAssertEqual(coordinator.apply(.default), .futureVersion(3))
        XCTAssertEqual(coordinator.apply(changed), .futureVersion(3))
        XCTAssertEqual(coordinator.loadResult, .futureVersion(3))
        XCTAssertTrue(store.saved.isEmpty)
    }

    func testNewFuturePayloadIsRecheckedEvenForEqualDraft() {
        let store = Store()
        let coordinator = AppManagementCoordinator(store: store) { _ in XCTFail("Protected payload applied") }
        store.loaded = .futureVersion(7)
        XCTAssertEqual(coordinator.apply(.default), .futureVersion(7))
        XCTAssertEqual(coordinator.apply(changed), .futureVersion(7))
        XCTAssertTrue(store.saved.isEmpty)
        XCTAssertEqual(coordinator.committed, .default)
    }

    func testCorruptRepairFailureRemainsRetryableAndEqualRepairWritesOnlyOnce() {
        let store = Store()
        store.loaded = .corrupt
        store.result = .failed
        let coordinator = AppManagementCoordinator(store: store) { _ in XCTFail("Equal repair needs no UI work") }
        XCTAssertEqual(coordinator.committed, .default)
        XCTAssertEqual(coordinator.loadResult, .corrupt)
        XCTAssertTrue(store.saved.isEmpty)
        XCTAssertEqual(coordinator.apply(.default), .failed)
        XCTAssertEqual(coordinator.loadResult, .corrupt)
        store.result = .saved
        XCTAssertEqual(coordinator.apply(.default), .saved)
        XCTAssertEqual(coordinator.loadResult, .loaded(.default))
        XCTAssertEqual(coordinator.apply(.default), .saved)
        XCTAssertEqual(store.saved, [.default, .default])
    }
}
