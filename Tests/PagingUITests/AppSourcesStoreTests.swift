import Foundation
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class AppSourcesStoreTests: XCTestCase {
    private func isolatedDefaults() throws -> (suite: String, defaults: UserDefaults) {
        let suite = "fixture.app-sources.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        return (suite, defaults)
    }

    private var changed: AppSourcesPreferences {
        .init(customRootPaths: ["/synthetic/apps", "/synthetic/应用程序"], automaticRefreshEnabled: false)
    }

    func testNamespaceIsIndependentAndMissingPayloadDoesNotWrite() throws {
        XCTAssertEqual(UserDefaultsAppSourcesStore.defaultSuiteName, "com.launchcopy.app-sources")
        XCTAssertEqual(UserDefaultsAppSourcesStore.payloadKey, "sources.payload")
        let fixture = try isolatedDefaults()
        let store = try XCTUnwrap(UserDefaultsAppSourcesStore(suiteName: fixture.suite))
        XCTAssertEqual(store.load(), .loaded(.default))
        XCTAssertNil(fixture.defaults.object(forKey: UserDefaultsAppSourcesStore.payloadKey))
    }

    func testOneVersionedPayloadRoundTripsDefaultsPathsAndToggle() throws {
        let fixture = try isolatedDefaults()
        let store = UserDefaultsAppSourcesStore(defaults: fixture.defaults)
        for value in [AppSourcesPreferences.default, changed,
                      .init(customRootPaths: changed.customRootPaths, automaticRefreshEnabled: true),
                      .init(automaticRefreshEnabled: false)] {
            XCTAssertEqual(store.save(value), .saved)
            let reopened = try XCTUnwrap(UserDefaultsAppSourcesStore(suiteName: fixture.suite))
            XCTAssertEqual(reopened.load(), .loaded(value))
            let bytes = try XCTUnwrap(fixture.defaults.data(forKey: UserDefaultsAppSourcesStore.payloadKey))
            let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            XCTAssertEqual(payload["schemaVersion"] as? Int, 1)
            XCTAssertEqual(Set(payload.keys), ["schemaVersion", "preferences"])
            let domain = fixture.defaults.persistentDomain(forName: fixture.suite) ?? [:]
            XCTAssertEqual(Set(domain.keys), [UserDefaultsAppSourcesStore.payloadKey])
        }
    }

    func testMalformedLegacyAndInvalidPayloadsStayUntouchedOnLoad() throws {
        let fixture = try isolatedDefaults()
        let key = UserDefaultsAppSourcesStore.payloadKey
        let payloads: [Any] = [
            "wrong stored type", Data("not JSON".utf8), Data("null".utf8),
            Data(#"{"customRootPaths":[],"automaticRefreshEnabled":true}"#.utf8),
            Data(#"{"schemaVersion":0,"preferences":{"customRootPaths":[],"automaticRefreshEnabled":true}}"#.utf8),
            Data(#"{"schemaVersion":-1,"preferences":{"customRootPaths":[],"automaticRefreshEnabled":true}}"#.utf8),
            Data(#"{"schemaVersion":1}"#.utf8),
            Data(#"{"schemaVersion":1,"preferences":{"customRootPaths":[]}}"#.utf8),
            Data(#"{"schemaVersion":1,"preferences":{"customRootPaths":["/"],"automaticRefreshEnabled":true}}"#.utf8),
            Data(#"{"schemaVersion":1,"preferences":{"customRootPaths":["/synthetic/./apps"],"automaticRefreshEnabled":true}}"#.utf8),
            Data(#"{"schemaVersion":1,"preferences":{"customRootPaths":["/synthetic/apps","/synthetic/apps"],"automaticRefreshEnabled":true}}"#.utf8),
            Data(#"{"schemaVersion":1,"preferences":{"customRootPaths":["/synthetic/\u0000apps"],"automaticRefreshEnabled":true}}"#.utf8)
        ]
        for payload in payloads {
            fixture.defaults.set(payload, forKey: key)
            let before = try XCTUnwrap(fixture.defaults.object(forKey: key) as? NSObject)
            let store = UserDefaultsAppSourcesStore(defaults: fixture.defaults)
            XCTAssertEqual(store.load(), .corrupt)
            XCTAssertEqual(store.load().preferences, .default)
            XCTAssertEqual(fixture.defaults.object(forKey: key) as? NSObject, before)
        }
    }

    func testExplicitSaveCanRepairBoundedCorruptionButLoadNeverDoes() throws {
        let fixture = try isolatedDefaults()
        let bytes = Data("not JSON".utf8)
        fixture.defaults.set(bytes, forKey: UserDefaultsAppSourcesStore.payloadKey)
        let store = UserDefaultsAppSourcesStore(defaults: fixture.defaults)
        XCTAssertEqual(store.load(), .corrupt)
        XCTAssertEqual(fixture.defaults.data(forKey: UserDefaultsAppSourcesStore.payloadKey), bytes)
        XCTAssertEqual(store.save(.default), .saved)
        XCTAssertEqual(store.load(), .loaded(.default))
    }

    func testFutureVersionUnknownShapeIsReadOnlyForAllDrafts() throws {
        let fixture = try isolatedDefaults()
        let bytes = Data(#"{"schemaVersion":9,"newerField":[1,2,3]}"#.utf8)
        fixture.defaults.set(bytes, forKey: UserDefaultsAppSourcesStore.payloadKey)
        let store = UserDefaultsAppSourcesStore(defaults: fixture.defaults)
        XCTAssertEqual(store.load(), .futureVersion(9))
        XCTAssertEqual(store.load().preferences, .default)
        for value in [AppSourcesPreferences.default, changed, .init(customRootPaths: ["/"])] {
            XCTAssertEqual(store.save(value), .futureVersion(9))
            XCTAssertEqual(fixture.defaults.data(forKey: UserDefaultsAppSourcesStore.payloadKey), bytes)
        }
    }

    func testSaveRechecksFutureVersionWrittenAfterAnEarlierLoad() throws {
        let fixture = try isolatedDefaults()
        let store = UserDefaultsAppSourcesStore(defaults: fixture.defaults)
        XCTAssertEqual(store.load(), .loaded(.default))
        let bytes = Data(#"{"schemaVersion":2,"unknown":true}"#.utf8)
        fixture.defaults.set(bytes, forKey: UserDefaultsAppSourcesStore.payloadKey)
        XCTAssertEqual(store.save(changed), .futureVersion(2))
        XCTAssertEqual(fixture.defaults.data(forKey: UserDefaultsAppSourcesStore.payloadKey), bytes)
    }

    func testUnknownCurrentFieldsAreNotRewrittenByLoad() throws {
        let fixture = try isolatedDefaults()
        let bytes = Data(#"{"schemaVersion":1,"unknown":42,"preferences":{"customRootPaths":[],"automaticRefreshEnabled":true,"extra":"preserve"}}"#.utf8)
        fixture.defaults.set(bytes, forKey: UserDefaultsAppSourcesStore.payloadKey)
        XCTAssertEqual(UserDefaultsAppSourcesStore(defaults: fixture.defaults).load(), .loaded(.default))
        XCTAssertEqual(fixture.defaults.data(forKey: UserDefaultsAppSourcesStore.payloadKey), bytes)
    }

    func testInvalidAndOversizedSavePreserveEarlierBytes() throws {
        let fixture = try isolatedDefaults()
        let store = UserDefaultsAppSourcesStore(defaults: fixture.defaults)
        XCTAssertEqual(store.save(changed), .saved)
        let before = fixture.defaults.data(forKey: UserDefaultsAppSourcesStore.payloadKey)
        for path in ["", "/", "relative", "/synthetic/../apps", "/synthetic/\u{7F}apps"] {
            XCTAssertEqual(store.save(.init(customRootPaths: [path])), .invalidPreferences)
            XCTAssertEqual(fixture.defaults.data(forKey: UserDefaultsAppSourcesStore.payloadKey), before)
        }
        let oversized = AppSourcesPreferences(customRootPaths: ["/synthetic/" + String(repeating: "x", count: 1_048_576)])
        XCTAssertTrue(oversized.isValid)
        XCTAssertEqual(store.save(oversized), .failed)
        XCTAssertEqual(fixture.defaults.data(forKey: UserDefaultsAppSourcesStore.payloadKey), before)
        XCTAssertEqual(store.load(), .loaded(changed))
    }

    func testInvalidSaveDoesNotCreatePayloadOrRepairCorruptBytes() throws {
        let fixture = try isolatedDefaults()
        let store = UserDefaultsAppSourcesStore(defaults: fixture.defaults)
        let invalid = AppSourcesPreferences(customRootPaths: ["/"])
        XCTAssertEqual(store.save(invalid), .invalidPreferences)
        XCTAssertNil(fixture.defaults.object(forKey: UserDefaultsAppSourcesStore.payloadKey))
        let bytes = Data("unrecognized bytes".utf8)
        fixture.defaults.set(bytes, forKey: UserDefaultsAppSourcesStore.payloadKey)
        XCTAssertEqual(store.save(invalid), .invalidPreferences)
        XCTAssertEqual(fixture.defaults.data(forKey: UserDefaultsAppSourcesStore.payloadKey), bytes)
    }

    func testOneMiBBoundaryAndOversizedFutureBytesArePreserved() throws {
        let fixture = try isolatedDefaults()
        let key = UserDefaultsAppSourcesStore.payloadKey
        let prefix = #"{"schemaVersion":9,"unknown":""#
        let suffix = #""}"#
        let limit = 1_048_576
        let atLimit = Data((prefix + String(repeating: "x", count: limit - prefix.utf8.count - suffix.utf8.count) + suffix).utf8)
        XCTAssertEqual(atLimit.count, limit)
        fixture.defaults.set(atLimit, forKey: key)
        let store = UserDefaultsAppSourcesStore(defaults: fixture.defaults)
        XCTAssertEqual(store.load(), .futureVersion(9))
        XCTAssertEqual(store.save(.default), .futureVersion(9))
        XCTAssertEqual(fixture.defaults.data(forKey: key), atLimit)
        let oversized = atLimit + Data(" ".utf8)
        fixture.defaults.set(oversized, forKey: key)
        XCTAssertEqual(store.load(), .corrupt)
        XCTAssertEqual(store.load().preferences, .default)
        XCTAssertEqual(store.save(.default), .failed)
        XCTAssertEqual(fixture.defaults.data(forKey: key), oversized)
    }

    func testIndependentSuitesAndForeignStoreKeysRemainSeparate() throws {
        let first = try isolatedDefaults()
        let second = try isolatedDefaults()
        let foreignKeys = ["activation.payload", "appearance.payload", "management.payload", "layout.payload"]
        for key in foreignKeys { first.defaults.set(Data("synthetic \(key)".utf8), forKey: key) }
        let before = first.defaults.persistentDomain(forName: first.suite) ?? [:]
        let store = try XCTUnwrap(UserDefaultsAppSourcesStore(suiteName: first.suite))
        let other = try XCTUnwrap(UserDefaultsAppSourcesStore(suiteName: second.suite))
        XCTAssertEqual(store.save(changed), .saved)
        XCTAssertEqual(other.load(), .loaded(.default))
        XCTAssertNil(second.defaults.object(forKey: UserDefaultsAppSourcesStore.payloadKey))
        for key in foreignKeys {
            XCTAssertEqual(first.defaults.object(forKey: key) as? NSObject, before[key] as? NSObject)
        }
        XCTAssertEqual(other.save(.default), .saved)
        XCTAssertEqual(store.load(), .loaded(changed))
    }

    func testInMemoryStoresHaveIndependentValuesAndRejectInvalidMutation() {
        let store = InMemoryAppSourcesStore()
        let other = InMemoryAppSourcesStore(preferences: changed)
        XCTAssertEqual(store.load(), .loaded(.default))
        XCTAssertEqual(other.load(), .loaded(changed))
        XCTAssertEqual(store.save(changed), .saved)
        XCTAssertEqual(store.save(.init(customRootPaths: ["/"])), .invalidPreferences)
        XCTAssertEqual(store.load(), .loaded(changed))
        XCTAssertEqual(other.save(.default), .saved)
        XCTAssertEqual(store.load(), .loaded(changed))
        let invalidSeed = InMemoryAppSourcesStore(preferences: .init(customRootPaths: ["relative"]))
        XCTAssertEqual(invalidSeed.load(), .corrupt)
        XCTAssertEqual(invalidSeed.load().preferences, .default)
    }
}
