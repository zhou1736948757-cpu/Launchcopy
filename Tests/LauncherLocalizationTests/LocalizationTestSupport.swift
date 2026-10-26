import Foundation
import XCTest
import LauncherLocalization

struct FixtureLocalizationResources: LocalizationResourceProviding {
    let tables: [String: Data]

    func localizableStringsData(for language: InterfaceLanguage) -> Data? {
        tables[language.rawValue]
    }
}

/// Lock-protected instrumentation; unchecked conformance is confined to the test probe.
final class CountingLocalizationResources: LocalizationResourceProviding, @unchecked Sendable {
    private let fixture: FixtureLocalizationResources
    private let lock = NSLock()
    private var requests: [String] = []

    init(fixture: FixtureLocalizationResources) { self.fixture = fixture }

    var requestedLanguages: [String] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    func localizableStringsData(for language: InterfaceLanguage) -> Data? {
        lock.lock()
        requests.append(language.rawValue)
        lock.unlock()
        return fixture.localizableStringsData(for: language)
    }
}

enum LocalizationTestResources {
    static func table(_ language: InterfaceLanguage) throws -> [String: String] {
        let bytes = try XCTUnwrap(BundleLocalizationResourceProvider().localizableStringsData(for: language))
        let propertyList = try PropertyListSerialization.propertyList(from: bytes, options: [], format: nil)
        return try XCTUnwrap(propertyList as? [String: String])
    }

    static func encoded(_ table: [String: String]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: table, format: .xml, options: 0)
    }

    static func provider(
        replacing language: InterfaceLanguage,
        with table: [String: String]
    ) throws -> FixtureLocalizationResources {
        var tables: [String: Data] = [:]
        for candidate in InterfaceLanguage.allCases {
            tables[candidate.rawValue] = try encoded(candidate == language ? table : self.table(candidate))
        }
        return FixtureLocalizationResources(tables: tables)
    }
}
