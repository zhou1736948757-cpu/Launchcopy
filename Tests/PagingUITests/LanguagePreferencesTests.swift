import Foundation
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class LanguagePreferencesTests: XCTestCase {
    func testUnrepresentablePositiveFutureVersionsCannotBeRepaired() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        for version in ["9223372036854775808", "18446744073709551616", "1e100", "1e1000", String(repeating: "9", count: 400)] {
            let original = Data("{\"schemaVersion\":\(version)}".utf8)
            fixture.defaults.set(original, forKey: key)
            let writes = fixture.defaults.payloadWriteCount
            let origin = fixture.store.load()
            XCTAssertEqual(origin, .futureVersionUnrepresentable)
            let view = LanguageSettingsView(frame: .zero)
            view.reload(preferences: origin.preferences, loadResult: origin)
            XCTAssertFalse(view.applyButton.isEnabled)
            var presentations = 0
            let coordinator = LanguageSettingsCoordinator(store: fixture.store) { _ in presentations += 1 }
            XCTAssertNotEqual(coordinator.apply(.default), .saved)
            XCTAssertNotEqual(fixture.store.save(.default), .saved)
            XCTAssertEqual(presentations, 0)
            XCTAssertEqual(fixture.defaults.payloadWriteCount, writes)
            XCTAssertEqual(fixture.defaults.object(forKey: key) as? Data, original)
        }
    }

    func testAmbiguousRootFutureVersionTokensRemainProtected() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let payloads = [
            #"{"schemaVersion":1,"schemaVersion":2,"preferences":{"language":"system"}}"#,
            #"{"schemaVersion":1,"schemaVersion":2e0,"preferences":{"language":"system"}}"#,
            #"{"schemaVersion":2e0,"schemaVersion":1,"preferences":{"language":"system"}}"#,
            #"{"schemaVersion":1,"schemaVersion":2.0,"preferences":{"language":"system"}}"#,
            #"{"schemaVersion":2.0,"schemaVersion":1,"preferences":{"language":"system"}}"#,
            #"{"schemaVersion":2,"schemaVersion":1,"preferences":{"language":"system"}}"#,
            #"{"schemaVersion":1,"schemaVersion":1e1000,"preferences":{"language":"system"}}"#,
            #"{"metadata":{"text":"brace } and \" schemaVersion"},"schema\u0056ersion":1e1000}"#
        ]
        for json in payloads {
            let original = Data(json.utf8)
            fixture.defaults.set(original, forKey: key)
            let writes = fixture.defaults.payloadWriteCount
            XCTAssertNotEqual(fixture.store.load(), .corrupt)
            XCTAssertNotEqual(fixture.store.save(.init(language: .japanese)), .saved)
            XCTAssertEqual(fixture.defaults.payloadWriteCount, writes)
            XCTAssertEqual(fixture.defaults.object(forKey: key) as? Data, original)
        }
    }

    func testFutureNumericHeaderEncodingMatrixPreservesOriginalBytes() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let encodings: [(String.Encoding, [UInt8])] = [
            (.utf8, [0xEF, 0xBB, 0xBF]), (.utf16LittleEndian, [0xFF, 0xFE]),
            (.utf16BigEndian, [0xFE, 0xFF]), (.utf32LittleEndian, [0xFF, 0xFE, 0, 0]),
            (.utf32BigEndian, [0, 0, 0xFE, 0xFF])
        ]
        for (encoding, bom) in encodings {
            for version in ["9223372036854775808", "1e1000", String(repeating: "9", count: 400)] {
                let raw = try XCTUnwrap("{\"schemaVersion\":\(version)}".data(using: encoding))
                XCTAssertFalse(raw.starts(with: bom), "Fixture must exercise BOM-less input")
                for original in [raw, Data(bom) + raw] {
                    fixture.defaults.set(original, forKey: key)
                    let writes = fixture.defaults.payloadWriteCount
                    XCTAssertEqual(fixture.store.load(), .futureVersionUnrepresentable)
                    let view = LanguageSettingsView(frame: .zero)
                    view.reload(preferences: .init(language: .japanese), loadResult: fixture.store.load())
                    XCTAssertFalse(view.applyButton.isEnabled)
                    XCTAssertFalse(view.defaultsButton.isEnabled)
                    XCTAssertFalse(view.languagePopup.isEnabled)
                    var presented = 0
                    let coordinator = LanguageSettingsCoordinator(store: fixture.store) { _ in presented += 1 }
                    XCTAssertEqual(coordinator.apply(.default), .futureVersionUnrepresentable)
                    XCTAssertEqual(fixture.store.save(.default), .futureVersionUnrepresentable)
                    XCTAssertEqual(view.draft.language, .japanese)
                    XCTAssertEqual(presented, 0)
                    XCTAssertEqual(fixture.defaults.payloadWriteCount, writes)
                    XCTAssertEqual(fixture.defaults.object(forKey: key) as? Data, original)
                }
            }
            let healthy = try XCTUnwrap(#"{"schemaVersion":1,"preferences":{"language":"ja"}}"#.data(using: encoding))
            for original in [healthy, Data(bom) + healthy] {
                fixture.defaults.set(original, forKey: key)
                XCTAssertEqual(fixture.store.load(), .loaded(.init(language: .japanese)), "encoding=\(encoding.rawValue), BOM=\(original.starts(with: bom))")
            }
        }
    }

    func testNestedFutureVersionDecoysDoNotProtectKnownCorruption() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let original = Data(#"{"schemaVersion":1,"preferences":{"language":"invalid"},"metadata":{"schemaVersion":1e1000}}"#.utf8)
        fixture.defaults.set(original, forKey: key)
        XCTAssertEqual(fixture.store.load(), .corrupt)
        XCTAssertEqual(fixture.store.save(.default), .saved)
    }

    func testDefaultsAndInspectionOriginsRemainDistinct() {
        XCTAssertEqual(LanguagePreferences(), .default)
        XCTAssertEqual(LanguagePreferences.default.language, .system)
        XCTAssertNotEqual(LanguagePreferencesLoadResult.missing, .loaded(.default))
        let degraded: [LanguagePreferencesLoadResult] = [
            .missing, .corrupt, .futureVersion(2), .oversized, .unavailable
        ]
        for result in degraded {
            XCTAssertEqual(result.preferences, .default)
        }
        let japanese = LanguagePreferences(language: .japanese)
        XCTAssertEqual(LanguagePreferencesLoadResult.loaded(japanese).preferences, japanese)
        XCTAssertEqual(UserDefaultsLanguagePreferencesStore.defaultSuiteName, "com.launchcopy.language")
        XCTAssertEqual(UserDefaultsLanguagePreferencesStore.payloadKey, "language.payload")
        XCTAssertEqual(UserDefaultsLanguagePreferencesStore.maximumPayloadBytes, 16_384)
    }

    func testMissingDoesNotWriteButExplicitDefaultSaveWritesOnce() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }

        XCTAssertEqual(fixture.store.load(), .missing)
        XCTAssertEqual(fixture.store.load().preferences, .default)
        XCTAssertNil(fixture.defaults.object(forKey: key))
        XCTAssertEqual(fixture.defaults.payloadWriteCount, 0)

        XCTAssertEqual(fixture.store.save(.default), .saved)
        XCTAssertEqual(fixture.defaults.payloadWriteCount, 1)
        XCTAssertEqual(fixture.store.load(), .loaded(.default))
        let data = try XCTUnwrap(fixture.defaults.object(forKey: key) as? Data)
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(root.keys), Set(["schemaVersion", "preferences"]))
        XCTAssertEqual(root["schemaVersion"] as? Int, 1)
        let body = try XCTUnwrap(root["preferences"] as? [String: Any])
        XCTAssertEqual(Set(body.keys), Set(["language"]))
        XCTAssertEqual(body["language"] as? String, "system")

        XCTAssertEqual(fixture.store.save(.default), .saved)
        XCTAssertEqual(fixture.defaults.payloadWriteCount, 1)
        XCTAssertEqual(fixture.defaults.object(forKey: key) as? Data, data)
    }

    func testSystemAndAllThreeExplicitLanguagesRoundTrip() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let languages: [InterfaceLanguagePreference] = [.system, .simplifiedChinese, .english, .japanese]
        XCTAssertEqual(Set(languages.map(\.rawValue)), Set(["system", "zh-Hans", "en", "ja"]))
        for language in languages {
            let preferences = LanguagePreferences(language: language)
            XCTAssertEqual(fixture.store.save(preferences), .saved)
            XCTAssertEqual(fixture.store.load(), .loaded(preferences))
            let reopened = try XCTUnwrap(UserDefaultsLanguagePreferencesStore(suiteName: fixture.suite))
            XCTAssertEqual(reopened.load(), .loaded(preferences))
            let encoded = try JSONEncoder().encode(preferences)
            XCTAssertEqual(try JSONDecoder().decode(LanguagePreferences.self, from: encoded), preferences)
        }
        XCTAssertEqual(fixture.defaults.payloadWriteCount, languages.count)
    }

    func testPublicCodableRejectsInvalidRawIdentifiers() {
        for raw in ["zh", "zh-Hant", "EN", "fr", "", "followSystem"] {
            let data = Data("{\"language\":\"\(raw)\"}".utf8)
            XCTAssertThrowsError(try JSONDecoder().decode(LanguagePreferences.self, from: data))
        }
    }

    func testInvalidRawIdentifiersLoadAsCorruptWithoutWriting() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        for raw in ["zh", "zh-Hant", "EN", "fr", "", "followSystem"] {
            let original = payload(language: raw)
            fixture.defaults.set(original, forKey: key)
            let count = fixture.defaults.payloadWriteCount
            XCTAssertEqual(fixture.store.load(), .corrupt)
            XCTAssertEqual(fixture.store.load().preferences, .default)
            XCTAssertEqual(fixture.defaults.object(forKey: key) as? Data, original)
            XCTAssertEqual(fixture.defaults.payloadWriteCount, count)
        }
    }

    func testMalformedSchemaAndStrictVersionOneShapeAreCorrupt() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let invalid = [
            "not JSON", "null", "[]", "{}",
            "{\"schemaVersion\":true,\"preferences\":{\"language\":\"en\"}}",
            "{\"schemaVersion\":\"1\",\"preferences\":{\"language\":\"en\"}}",
            "{\"schemaVersion\":1.5,\"preferences\":{\"language\":\"en\"}}",
            "{\"schemaVersion\":0,\"preferences\":{\"language\":\"en\"}}",
            "{\"schemaVersion\":-1,\"preferences\":{\"language\":\"en\"}}",
            "{\"schemaVersion\":null,\"preferences\":{\"language\":\"en\"}}",
            "{\"preferences\":{\"language\":\"en\"}}",
            "{\"schemaVersion\":1}",
            "{\"schemaVersion\":1,\"preferences\":null}",
            "{\"schemaVersion\":1,\"preferences\":[]}",
            "{\"schemaVersion\":1,\"preferences\":{}}",
            "{\"schemaVersion\":1,\"preferences\":{\"language\":7}}",
            "{\"schemaVersion\":1,\"preferences\":{\"language\":null}}",
            "{\"schemaVersion\":1,\"preferences\":{\"language\":\"en\",\"extra\":true}}",
            "{\"schemaVersion\":1,\"preferences\":{\"language\":\"en\"},\"extra\":true}"
        ]
        for json in invalid {
            let original = Data(json.utf8)
            fixture.defaults.set(original, forKey: key)
            let count = fixture.defaults.payloadWriteCount
            XCTAssertEqual(fixture.store.load(), .corrupt, json)
            XCTAssertEqual(fixture.defaults.object(forKey: key) as? Data, original)
            XCTAssertEqual(fixture.defaults.payloadWriteCount, count)
        }
    }

    func testFutureHeaderIsInspectedBeforeUnknownOrMissingBodyAndProtectsBytes() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        for version in [2, 99, Int.max] {
            for body in ["", ",\"preferences\":null", ",\"preferences\":{\"language\":\"future\"}"] {
                let original = Data("{\"schemaVersion\":\(version)\(body)}".utf8)
                fixture.defaults.set(original, forKey: key)
                let count = fixture.defaults.payloadWriteCount
                XCTAssertEqual(fixture.store.load(), .futureVersion(version))
                XCTAssertEqual(fixture.store.load().preferences, .default)
                XCTAssertEqual(fixture.store.save(.default), .futureVersion(version))
                XCTAssertEqual(fixture.store.save(LanguagePreferences(language: .japanese)), .futureVersion(version))
                XCTAssertEqual(fixture.defaults.payloadWriteCount, count)
                XCTAssertEqual(fixture.defaults.object(forKey: key) as? Data, original)
            }
        }
    }

    func testOversizedDataIsProtectedBeforeJSONOrHeaderDecoding() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let limit = UserDefaultsLanguagePreferencesStore.maximumPayloadBytes
        var future = Data("{\"schemaVersion\":2}".utf8)
        future.append(Data(repeating: 32, count: limit + 1 - future.count))
        for original in [Data(repeating: 0, count: limit + 1), future] {
            fixture.defaults.set(original, forKey: key)
            let count = fixture.defaults.payloadWriteCount
            XCTAssertEqual(fixture.store.load(), .oversized)
            XCTAssertEqual(fixture.store.save(.default), .oversized)
            XCTAssertEqual(fixture.defaults.payloadWriteCount, count)
            XCTAssertEqual(fixture.defaults.object(forKey: key) as? Data, original)
        }
    }

    func testExactlyMaximumPayloadSizeRemainsReadableAndEqualSavePreservesBytes() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        var original = payload(language: "en")
        original.append(Data(repeating: 32, count: UserDefaultsLanguagePreferencesStore.maximumPayloadBytes - original.count))
        fixture.defaults.set(original, forKey: key)
        let count = fixture.defaults.payloadWriteCount
        let english = LanguagePreferences(language: .english)
        XCTAssertEqual(fixture.store.load(), .loaded(english))
        XCTAssertEqual(fixture.store.save(english), .saved)
        XCTAssertEqual(fixture.defaults.payloadWriteCount, count)
        XCTAssertEqual(fixture.defaults.object(forKey: key) as? Data, original)
    }

    func testHealthyEqualSaveDoesNotWriteOrNormalizeOriginalJSON() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let original = Data(" { \"preferences\" : { \"language\" : \"system\" }, \"schemaVersion\" : 1 } \n".utf8)
        fixture.defaults.set(original, forKey: key)
        let count = fixture.defaults.payloadWriteCount
        XCTAssertEqual(fixture.store.load(), .loaded(.default))
        let inspections = fixture.defaults.payloadReadCount
        XCTAssertEqual(fixture.store.save(.default), .saved)
        XCTAssertEqual(fixture.defaults.payloadReadCount, inspections + 1)
        XCTAssertEqual(fixture.defaults.payloadWriteCount, count)
        XCTAssertEqual(fixture.defaults.object(forKey: key) as? Data, original)
    }

    func testSmallWrongTypesAreCorruptRatherThanMissingAndAllowExplicitRepair() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let invalid: [Any] = ["not Data", 1, ["en"], ["schemaVersion": 1]]
        for original in invalid {
            fixture.defaults.set(original, forKey: key)
            let count = fixture.defaults.payloadWriteCount
            XCTAssertEqual(fixture.store.load(), .corrupt)
            XCTAssertEqual(fixture.defaults.payloadWriteCount, count)
            XCTAssertEqual(fixture.store.save(.default), .saved)
            XCTAssertEqual(fixture.defaults.payloadWriteCount, count + 1)
            XCTAssertEqual(fixture.store.load(), .loaded(.default))
        }
    }

    func testOversizedWrongTypesAreReadOnlyAndRemainUnchanged() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        let size = UserDefaultsLanguagePreferencesStore.maximumPayloadBytes + 1
        let invalid: [Any] = [
            String(repeating: "x", count: size),
            String(repeating: "日", count: size / 2),
            Array(repeating: 1, count: size),
            ["nested": Data(repeating: 0, count: size)]
        ]
        for original in invalid {
            fixture.defaults.set(original, forKey: key)
            let before = try PropertyListSerialization.data(fromPropertyList: original, format: .binary, options: 0)
            let count = fixture.defaults.payloadWriteCount
            XCTAssertEqual(fixture.store.load(), .oversized)
            XCTAssertEqual(fixture.store.save(.default), .oversized)
            let remaining = try XCTUnwrap(fixture.defaults.object(forKey: key))
            let after = try PropertyListSerialization.data(fromPropertyList: remaining, format: .binary, options: 0)
            XCTAssertEqual(after, before)
            XCTAssertEqual(fixture.defaults.payloadWriteCount, count)
        }
    }

    func testExplicitEqualDefaultSaveRepairsKnownCorruptJSON() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        for original in [Data("broken JSON".utf8), payload(language: "unsupported")] {
            fixture.defaults.set(original, forKey: key)
            XCTAssertEqual(fixture.store.load(), .corrupt)
            XCTAssertEqual(fixture.store.load().preferences, .default)
            let count = fixture.defaults.payloadWriteCount
            XCTAssertEqual(fixture.store.save(.default), .saved)
            XCTAssertEqual(fixture.store.load(), .loaded(.default))
            XCTAssertEqual(fixture.defaults.payloadWriteCount, count + 1)
            XCTAssertNotEqual(fixture.defaults.object(forKey: key) as? Data, original)
        }
    }

    func testLateFutureReplacementRefusesEqualSaveAndPreservesBytes() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        XCTAssertEqual(fixture.store.save(.default), .saved)
        XCTAssertEqual(fixture.store.load(), .loaded(.default))
        let future = Data("{\"schemaVersion\":7,\"preferences\":{\"language\":\"system\"}}".utf8)
        fixture.defaults.set(future, forKey: key)
        let count = fixture.defaults.payloadWriteCount
        XCTAssertEqual(fixture.store.save(.default), .futureVersion(7))
        XCTAssertEqual(fixture.defaults.payloadWriteCount, count)
        XCTAssertEqual(fixture.defaults.object(forKey: key) as? Data, future)
    }

    func testLateOversizedReplacementRefusesEqualSaveAndPreservesBytes() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        XCTAssertEqual(fixture.store.save(.default), .saved)
        let oversized = Data(repeating: 0, count: UserDefaultsLanguagePreferencesStore.maximumPayloadBytes + 1)
        fixture.defaults.set(oversized, forKey: key)
        let count = fixture.defaults.payloadWriteCount
        XCTAssertEqual(fixture.store.save(.default), .oversized)
        XCTAssertEqual(fixture.defaults.payloadWriteCount, count)
        XCTAssertEqual(fixture.defaults.object(forKey: key) as? Data, oversized)
    }

    func testLateDeletionRequiresExplicitEqualDefaultWrite() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        XCTAssertEqual(fixture.store.save(.default), .saved)
        fixture.defaults.removeObject(forKey: key)
        let count = fixture.defaults.payloadWriteCount
        XCTAssertEqual(fixture.store.load(), .missing)
        XCTAssertNil(fixture.defaults.object(forKey: key))
        XCTAssertEqual(fixture.defaults.payloadWriteCount, count)
        XCTAssertEqual(fixture.store.save(.default), .saved)
        XCTAssertEqual(fixture.defaults.payloadWriteCount, count + 1)
        XCTAssertEqual(fixture.store.load(), .loaded(.default))
    }

    func testLateCorruptionRequiresExplicitEqualDefaultRepair() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        XCTAssertEqual(fixture.store.save(.default), .saved)
        let corrupt = payload(language: "fr")
        fixture.defaults.set(corrupt, forKey: key)
        let count = fixture.defaults.payloadWriteCount
        XCTAssertEqual(fixture.store.save(.default), .saved)
        XCTAssertEqual(fixture.defaults.payloadWriteCount, count + 1)
        XCTAssertEqual(fixture.store.load(), .loaded(.default))
    }

    func testLateDifferentHealthyPayloadCanBeExplicitlyReplaced() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanUp() }
        XCTAssertEqual(fixture.store.save(.default), .saved)
        fixture.defaults.set(payload(language: "ja"), forKey: key)
        let count = fixture.defaults.payloadWriteCount
        XCTAssertEqual(fixture.store.save(.default), .saved)
        XCTAssertEqual(fixture.defaults.payloadWriteCount, count + 1)
        XCTAssertEqual(fixture.store.load(), .loaded(.default))
    }

    func testUnavailableStoreNeverReportsPersistentAcceptance() {
        let store: any LanguagePreferencesPersisting = UnavailableLanguagePreferencesStore()
        XCTAssertEqual(store.load(), .unavailable)
        XCTAssertEqual(store.load().preferences, .default)
        for language in InterfaceLanguagePreference.allCases {
            XCTAssertEqual(store.save(LanguagePreferences(language: language)), .unavailable)
            XCTAssertEqual(store.load(), .unavailable)
        }
    }

    private var key: String { UserDefaultsLanguagePreferencesStore.payloadKey }

    private func payload(language: String) -> Data {
        Data("{\"schemaVersion\":1,\"preferences\":{\"language\":\"\(language)\"}}".utf8)
    }

    private func makeFixture() throws -> Fixture {
        let suite = "com.launchcopy.language.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(CountingLanguageDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return Fixture(
            suite: suite,
            defaults: defaults,
            store: UserDefaultsLanguagePreferencesStore(defaults: defaults)
        )
    }

    private struct Fixture {
        let suite: String
        let defaults: CountingLanguageDefaults
        let store: UserDefaultsLanguagePreferencesStore

        func cleanUp() {
            defaults.removePersistentDomain(forName: suite)
        }
    }
}

// All mutable spy state is locked; each test uses a dedicated UUID suite.
private final class CountingLanguageDefaults: UserDefaults, @unchecked Sendable {
    private let writeLock = NSLock()
    private var writeCount = 0
    private var readCount = 0

    var payloadWriteCount: Int {
        writeLock.lock()
        defer { writeLock.unlock() }
        return writeCount
    }

    var payloadReadCount: Int {
        writeLock.lock()
        defer { writeLock.unlock() }
        return readCount
    }

    override func object(forKey defaultName: String) -> Any? {
        if defaultName == UserDefaultsLanguagePreferencesStore.payloadKey {
            writeLock.lock()
            readCount += 1
            writeLock.unlock()
        }
        return super.object(forKey: defaultName)
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        if defaultName == UserDefaultsLanguagePreferencesStore.payloadKey {
            writeLock.lock()
            writeCount += 1
            writeLock.unlock()
        }
        super.set(value, forKey: defaultName)
    }
}
