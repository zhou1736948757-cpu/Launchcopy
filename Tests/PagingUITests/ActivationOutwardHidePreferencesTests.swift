import Foundation
import XCTest
@testable import PagingPrototypeApp

final class ActivationOutwardHidePreferencesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: UserDefaultsActivationPreferencesStore!
    private let outwardKey = "activation.fourFingerOutwardHideEnabled"

    override func setUp() {
        super.setUp()
        suiteName = "com.pagingprototype.activation.outward.tests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = UserDefaultsActivationPreferencesStore(suiteName: suiteName)!
    }

    override func tearDown() {
        store.removePersistentDomain()
        store = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func storedDomain() -> NSDictionary {
        (defaults.persistentDomain(forName: suiteName) ?? [:]) as NSDictionary
    }

    func testFreshDefaultsAreOptOutAndReadDoesNotWrite() {
        let before = storedDomain()
        XCTAssertEqual(store.load(), .loaded(ActivationPreferences()))
        XCTAssertFalse(ActivationPreferences().fourFingerOutwardHideEnabled)
        XCTAssertEqual(ActivationPreferences.currentSchemaVersion, 3)
        XCTAssertEqual(ActivationSettings.currentSchemaVersion, 2)
        XCTAssertEqual(storedDomain(), before)
    }

    func testSchemaThreeRoundTripPreservesChoiceWithEitherParentState() {
        for parent in [false, true] {
            let preferences = ActivationPreferences(
                fourFingerActivationEnabled: parent, fourFingerOutwardHideEnabled: true
            )
            XCTAssertEqual(store.save(preferences), .saved)
            XCTAssertEqual(store.load(), .loaded(preferences))
            XCTAssertTrue(defaults.bool(forKey: outwardKey))
            XCTAssertEqual(defaults.integer(forKey: "activation.schemaVersion"), 3)
        }
    }

    func testLegacySchemasIgnoreStrayOutwardKeyPreserveChoicesAndNeverWriteOnLoad() throws {
        for version in [1, 2] {
            for parent in [false, true] {
                var settings = ActivationSettings()
                settings.hotCornerEnabled = true
                settings.selectedCorner = .bottomRight
                settings.globalShortcutEnabled = true
                settings.shortcut = ShortcutSpec(keyCode: 3, modifiers: [.command, .shift])
                settings.showStatusItem = false
                settings.launchAtLoginEnabled = true
                defaults.set(version, forKey: "activation.schemaVersion")
                defaults.set(parent, forKey: "activation.fourFingerActivationEnabled")
                defaults.set(true, forKey: outwardKey)
                defaults.set(try JSONEncoder().encode(settings), forKey: "activation.settingsPayload")
                let before = storedDomain()

                guard case .loaded(let loaded) = store.load() else {
                    return XCTFail("Legacy preferences must load")
                }
                if version == 1 { settings.launchAtLoginEnabled = false }
                XCTAssertEqual(loaded, ActivationPreferences(
                    fourFingerActivationEnabled: parent,
                    fourFingerOutwardHideEnabled: false,
                    settings: settings
                ))
                XCTAssertEqual(storedDomain(), before, "Migration is in memory until explicit Apply")
                XCTAssertEqual(store.save(loaded), .saved)
                XCTAssertEqual(defaults.integer(forKey: "activation.schemaVersion"), 3)
                XCTAssertFalse(defaults.bool(forKey: outwardKey))
            }
        }
    }

    func testSchemaThreeMissingOrMalformedOutwardKeyIsOptOutWithoutWrites() {
        defaults.set(3, forKey: "activation.schemaVersion")
        defaults.set(true, forKey: "activation.fourFingerActivationEnabled")
        let invalidValues: [Any?] = [nil, "true", [true], Data([1])]
        for raw in invalidValues {
            if let raw { defaults.set(raw, forKey: outwardKey) }
            else { defaults.removeObject(forKey: outwardKey) }
            let before = storedDomain()
            guard case .loaded(let loaded) = store.load() else {
                return XCTFail("Malformed optional values must load safely")
            }
            XCTAssertFalse(loaded.fourFingerOutwardHideEnabled)
            XCTAssertTrue(loaded.fourFingerActivationEnabled)
            XCTAssertEqual(storedDomain(), before)
        }
    }

    func testFirstFutureSchemaRefusesLoadAndSaveWithoutChangingAnyKey() {
        defaults.set(4, forKey: "activation.schemaVersion")
        defaults.set(true, forKey: outwardKey)
        defaults.set(Data("future payload".utf8), forKey: "activation.settingsPayload")
        defaults.set("retained", forKey: "other.namespace")
        let before = storedDomain()
        XCTAssertEqual(store.load(), .futureSchema(storedVersion: 4))
        XCTAssertEqual(store.save(ActivationPreferences()), .refusedFutureSchema(storedVersion: 4))
        XCTAssertEqual(storedDomain(), before)
    }

    func testResetClearsOutwardChoiceAndPreservesOtherNamespace() {
        XCTAssertEqual(store.save(ActivationPreferences(fourFingerOutwardHideEnabled: true)), .saved)
        defaults.set("retained", forKey: "other.namespace")
        store.resetActivation()
        XCTAssertNil(defaults.object(forKey: outwardKey))
        XCTAssertEqual(defaults.string(forKey: "other.namespace"), "retained")
        XCTAssertEqual(store.load(), .loaded(ActivationPreferences()))
    }

    func testInMemoryStoreCarriesChoiceAndResetsToOptOut() {
        let preferences = ActivationPreferences(
            fourFingerActivationEnabled: false, fourFingerOutwardHideEnabled: true
        )
        let memory = InMemoryActivationPreferencesStore(initial: preferences)
        XCTAssertEqual(memory.load(), .loaded(preferences))
        memory.forcedStoredVersion = 4
        XCTAssertEqual(memory.save(ActivationPreferences()), .refusedFutureSchema(storedVersion: 4))
        memory.forcedStoredVersion = nil
        XCTAssertEqual(memory.load(), .loaded(preferences))
        memory.resetActivation()
        XCTAssertEqual(memory.load(), .loaded(ActivationPreferences()))
    }
    func testNumericImpostorsNeverOptInAndRealBooleansRetainMeaningWithoutWrites() throws {
        let name = "fixture.activation.outward.numeric.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let store = try XCTUnwrap(UserDefaultsActivationPreferencesStore(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(3, forKey: "activation.schemaVersion")
        let cases: [(Any, Bool)] = [(1, false), (0, false), (NSNumber(value: 1), false),
            (NSNumber(value: 0), false), (NSNumber(value: 1.0), false), (NSNumber(value: 2), false),
            (NSNumber(value: true), true), (NSNumber(value: false), false)]
        for (raw, expected) in cases {
            defaults.set(raw, forKey: "activation.fourFingerOutwardHideEnabled")
            let before = defaults.dictionaryRepresentation() as NSDictionary
            guard case .loaded(let value) = store.load() else { return XCTFail("Expected schema3") }
            XCTAssertEqual(value.fourFingerOutwardHideEnabled, expected)
            XCTAssertEqual(defaults.dictionaryRepresentation() as NSDictionary, before)
        }
    }

}
