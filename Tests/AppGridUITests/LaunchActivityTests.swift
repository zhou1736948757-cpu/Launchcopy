import AppCatalogCore
import AppGridUI
import CryptoKit
import Foundation
import XCTest

final class LaunchActivityTests: XCTestCase {
    private let salt = String(repeating: "a", count: 64)
    private let today = 21_000
    private var now: Date { Date(timeIntervalSince1970: Double(today * 86_400 + 123)) }

    private func app(_ index: Int, bundleID: String? = nil, path: String? = nil) -> AppRecord {
        let url = URL(fileURLWithPath: path ?? "/SyntheticActivity/App\(index).app")
        let bundle = bundleID ?? "fixture.activity.\(index)"
        let id = AppID.bundleIdentifier(bundle)
        return AppRecord(id: id, displayName: "App \(index)", bundleIdentifier: bundle,
                         canonicalURL: url, iconIdentity: .from(appID: id), sourceRootPriority: 0)
    }

    private func entry(_ offset: TimeInterval = 0, count: Int = 1) -> LaunchActivityEntry {
        let date = now.addingTimeInterval(offset)
        let day = Int(floor(date.timeIntervalSince1970 / 86_400))
        return LaunchActivityEntry(lastLaunch: date, dailyCounts: [day: count])
    }

    func testDefaultOffUsesIndependentValidRandomSaltsAndDoesNotRecord() {
        var first = LaunchActivityDocument()
        let second = LaunchActivityDocument()
        XCTAssertFalse(first.enabled)
        XCTAssertTrue(first.isValid)
        XCTAssertEqual(first.salt.count, 64)
        XCTAssertNotEqual(first.salt, second.salt)
        let original = first
        first.record(app(1), at: now)
        XCTAssertEqual(first, original)
        XCTAssertTrue(first.rankedKeys(section: .recent, at: now).isEmpty)
        XCTAssertEqual(LaunchActivitySection.allCases, [.recent, .frequent])
    }

    func testIdentityReusesCanonicalBundleReferenceAcrossMovesAndNames() throws {
        var document = LaunchActivityDocument(enabled: true, salt: salt)
        let first = app(1, bundleID: "fixture.Canonical", path: "/SyntheticActivity/Old.app")
        let moved = app(2, bundleID: "fixture.Canonical", path: "/SyntheticActivity/New.app")
        XCTAssertEqual(document.key(for: first), PersistentAppReference.from(record: first).comparisonKey)
        XCTAssertEqual(document.key(for: first), document.key(for: moved))
        XCTAssertEqual(document.key(for: first), LaunchActivityDocument().key(for: first), "Bundle identity is independent of profile salt")
        document.record(first, at: now.addingTimeInterval(-1))
        document.record(moved, at: now)
        XCTAssertEqual(document.entries.count, 1)
        XCTAssertEqual(document.entries[document.key(for: moved)]?.dailyCounts[today], 2)
        let text = String(decoding: try JSONEncoder().encode(document), as: UTF8.self)
        XCTAssertFalse(text.contains("SyntheticActivity"))
        XCTAssertFalse(text.contains("Old.app"))
        XCTAssertFalse(text.contains("New.app"))
        XCTAssertFalse(text.contains("App 1"))
    }

    func testPathFallbackIsCanonicalSaltedSHA256AndPersistsNoPathOrName() throws {
        let url = URL(fileURLWithPath: "/SyntheticActivity/Folder/../PrivateName.app/")
        let id = AppID.canonicalURLFallback(url)
        let record = AppRecord(id: id, displayName: "Private Display Name", bundleIdentifier: nil,
                               canonicalURL: url, iconIdentity: .from(appID: id), sourceRootPriority: 0)
        var document = LaunchActivityDocument(enabled: true, salt: salt)
        let expected = SHA256.hash(data: Data((salt + PersistentAppReference.normalizedPath(url)).utf8))
            .map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(document.key(for: record), "path-hash:" + expected)
        XCTAssertNotEqual(document.key(for: record), LaunchActivityDocument(salt: String(repeating: "b", count: 64)).key(for: record))
        document.record(record, at: now)
        let encoded = try JSONEncoder().encode(document)
        let text = String(decoding: encoded, as: UTF8.self)
        XCTAssertFalse(text.contains("SyntheticActivity"))
        XCTAssertFalse(text.contains("PrivateName"))
        XCTAssertFalse(text.contains("Private Display Name"))
        XCTAssertEqual(try JSONDecoder().decode(LaunchActivityDocument.self, from: encoded), document)
    }

    func testPathFallbackNormalizesCaseDotComponentsTrailingSlashAndEmptyBundleID() {
        func fallback(_ path: String, bundle: String?) -> AppRecord {
            let url = URL(fileURLWithPath: path)
            let id = AppID.canonicalURLFallback(url)
            return AppRecord(id: id, displayName: "Unpersisted", bundleIdentifier: bundle,
                             canonicalURL: url, iconIdentity: .from(appID: id), sourceRootPriority: 0)
        }
        let first = fallback("/SyntheticActivity/Folder/../Example.app/", bundle: nil)
        let canonical = fallback("/syntheticactivity/example.app", bundle: "")
        let other = fallback("/syntheticactivity/other.app", bundle: nil)
        var document = LaunchActivityDocument(enabled: true, salt: salt)
        XCTAssertEqual(document.key(for: first), document.key(for: canonical))
        XCTAssertNotEqual(document.key(for: first), document.key(for: other))
        document.record(first, at: now.addingTimeInterval(-1))
        document.record(canonical, at: now)
        XCTAssertEqual(document.entries.count, 1)
        XCTAssertEqual(document.entries[document.key(for: first)]?.dailyCounts[today], 2)
        XCTAssertTrue(document.isValid)
    }

    func testAcceptedRequestsAccumulateIncludingDistinctRequestsAtEqualTime() {
        let source = app(1)
        var document = LaunchActivityDocument(enabled: true, salt: salt)
        document.record(source, at: now)
        document.record(source, at: now)
        document.record(source, at: now.addingTimeInterval(5))
        XCTAssertEqual(document.entries.count, 1)
        XCTAssertEqual(document.entries[document.key(for: source)]?.dailyCounts, [today: 3])
        XCTAssertEqual(document.entries[document.key(for: source)]?.lastLaunch, now.addingTimeInterval(5))
        XCTAssertTrue(document.isValid)
    }

    func testRecentOrdersByLastThenStableKeyAndFrequentUsesTotalThenLastThenKey() {
        let a = "bundle:fixture.a", b = "bundle:fixture.b", c = "bundle:fixture.c", d = "bundle:fixture.d"
        let document = LaunchActivityDocument(enabled: true, salt: salt, entries: [
            d: entry(-5, count: 10), b: entry(), a: entry(), c: entry(-1)
        ])
        XCTAssertEqual(document.rankedKeys(section: .recent, at: now), [a, b, c, d])
        XCTAssertEqual(document.rankedKeys(section: .frequent, at: now), [d, a, b, c])
        var reordered = document
        reordered.entries = Dictionary(uniqueKeysWithValues: document.entries.sorted { $0.key < $1.key })
        XCTAssertEqual(reordered.rankedKeys(section: .frequent, at: now), [d, a, b, c])
    }

    func testFrequencyUsesOnlyCurrentAndPrevious29UTCDays() {
        let a = "bundle:fixture.a", b = "bundle:fixture.b"
        let document = LaunchActivityDocument(enabled: true, salt: salt, entries: [
            a: .init(lastLaunch: now.addingTimeInterval(-86_400),
                     dailyCounts: [today - 30: 100, today - 29: 2, today - 1: 1]),
            b: .init(lastLaunch: now, dailyCounts: [today: 4])
        ])
        XCTAssertTrue(document.isValid)
        XCTAssertEqual(document.rankedKeys(section: .frequent, at: now), [b, a])
        var pruned = document
        pruned.prune(at: now)
        XCTAssertEqual(pruned.entries[a]?.dailyCounts, [today - 29: 2, today - 1: 1])
        XCTAssertEqual(document.entries[a]?.dailyCounts[today - 30], 100, "Projection cannot mutate stored history")
    }

    func testUTCWindowCrossesMidnightWithoutLocaleOrTimeZone() {
        let source = app(1)
        let midnight = Date(timeIntervalSince1970: Double(today * 86_400))
        var document = LaunchActivityDocument(enabled: true, salt: salt)
        document.record(source, at: midnight.addingTimeInterval(-0.5))
        document.record(source, at: midnight.addingTimeInterval(0.5))
        XCTAssertEqual(document.entries[document.key(for: source)]?.dailyCounts, [today - 1: 1, today: 1])
        for days in 1...31 { document.record(source, at: midnight.addingTimeInterval(Double(days * 86_400))) }
        let counts = document.entries[document.key(for: source)]?.dailyCounts
        XCTAssertEqual(counts?.count, 30)
        XCTAssertEqual(counts?.keys.min(), today + 2)
        XCTAssertEqual(counts?.keys.max(), today + 31)
        XCTAssertTrue(document.isValid)
    }

    func testExactRetentionBoundaryKeepsDayMinus29AndDropsDayMinus30() {
        let midnight = Date(timeIntervalSince1970: Double(today * 86_400))
        let retained = Date(timeIntervalSince1970: Double((today - 29) * 86_400))
        let expired = retained.addingTimeInterval(-0.001)
        var document = LaunchActivityDocument(enabled: true, salt: salt, entries: [
            "bundle:fixture.retained": .init(lastLaunch: retained, dailyCounts: [today - 29: 1]),
            "bundle:fixture.expired": .init(lastLaunch: expired, dailyCounts: [today - 30: 1]),
            "bundle:fixture.today": .init(lastLaunch: midnight, dailyCounts: [today: 1])
        ])
        XCTAssertTrue(document.isValid)
        for section in LaunchActivitySection.allCases {
            XCTAssertEqual(document.rankedKeys(section: section, at: midnight),
                           ["bundle:fixture.today", "bundle:fixture.retained"])
        }
        document.prune(at: midnight)
        XCTAssertEqual(document.entries.count, 2)
        XCTAssertNil(document.entries["bundle:fixture.expired"])
        XCTAssertEqual(document.entries["bundle:fixture.retained"]?.lastLaunch, retained)
    }

    func testFutureEntriesAreExcludedAsAWholeAfterClockRollback() {
        let past = "bundle:fixture.past", future = "bundle:fixture.future"
        var document = LaunchActivityDocument(enabled: true, salt: salt, entries: [
            past: entry(-1), future: entry(1, count: 100)
        ])
        XCTAssertTrue(document.isValid)
        for section in LaunchActivitySection.allCases {
            XCTAssertEqual(document.rankedKeys(section: section, at: now), [past])
        }
        document.prune(at: now)
        XCTAssertNil(document.entries[future])
        XCTAssertNotNil(document.entries[past])
    }

    func testDisabledRetentionDoesNotRecordOrProjectButCanExpire() {
        let key = "bundle:fixture.old"
        var document = LaunchActivityDocument(salt: salt, entries: [key: entry(-30 * 86_400)])
        let retained = document
        document.record(app(2), at: now)
        XCTAssertEqual(document, retained)
        XCTAssertTrue(document.rankedKeys(section: .frequent, at: now).isEmpty)
        document.prune(at: now)
        XCTAssertTrue(document.entries.isEmpty)
        XCTAssertFalse(document.enabled)
    }

    func testInvalidClocksDoNotRecordPruneOrProject() {
        let document = LaunchActivityDocument(enabled: true, salt: salt, entries: ["bundle:fixture.one": entry()])
        for timestamp in [Double.nan, .infinity, -.infinity, -1, 0, Double.greatestFiniteMagnitude] {
            let clock = Date(timeIntervalSince1970: timestamp)
            var copy = document
            copy.record(app(1), at: clock)
            copy.prune(at: clock)
            XCTAssertEqual(copy, document)
            XCTAssertTrue(copy.rankedKeys(section: .recent, at: clock).isEmpty)
        }
    }

    func testValidationRejectsInvalidDatesCountsBucketsKeysAndSalt() {
        var badEntries: [LaunchActivityEntry] = [
            .init(lastLaunch: now, dailyCounts: [:]),
            .init(lastLaunch: now, dailyCounts: [today: 0]),
            .init(lastLaunch: now, dailyCounts: [today: -1]),
            .init(lastLaunch: now, dailyCounts: [today: Int.max]),
            .init(lastLaunch: now, dailyCounts: [today + 1: 1, today: 1]),
            .init(lastLaunch: now, dailyCounts: [Int.min: 1, today: 1]),
            .init(lastLaunch: now, dailyCounts: [today - 30: 1, today: 1]),
            .init(lastLaunch: now, dailyCounts: [today - 1: 1]),
            .init(lastLaunch: now, dailyCounts: Dictionary(uniqueKeysWithValues: (0...30).map { (today - $0, 1) }))
        ]
        badEntries += [Double.nan, .infinity, -.infinity, -1, 0, Double.greatestFiniteMagnitude].map {
            LaunchActivityEntry(lastLaunch: Date(timeIntervalSince1970: $0), dailyCounts: [today: 1])
        }
        for invalid in badEntries {
            let document = LaunchActivityDocument(enabled: true, salt: salt, entries: ["bundle:fixture.bad": invalid])
            XCTAssertFalse(document.isValid)
            XCTAssertTrue(document.rankedKeys(section: .recent, at: now).isEmpty)
        }
        for key in ["path:/private/raw.app", "bundle:", "bundle:/raw/path", "bundle:bad\nvalue",
                    "path-hash:abc", "path-hash:" + String(repeating: "G", count: 64),
                    "bundle:" + String(repeating: "x", count: 513)] {
            var document = LaunchActivityDocument(enabled: true, salt: salt, entries: [key: entry()])
            XCTAssertFalse(document.isValid)
            let original = document
            document.record(app(1), at: now)
            XCTAssertEqual(document, original)
        }
        for salt in ["", "abc", String(repeating: "g", count: 64), String(repeating: "A", count: 64)] {
            XCTAssertFalse(LaunchActivityDocument(salt: salt).isValid)
        }
    }

    func testCountsSaturateWithoutOverflow() {
        let source = app(1)
        var document = LaunchActivityDocument(enabled: true, salt: salt)
        let identity = document.key(for: source)
        document.entries[identity] = entry(count: 1_000_000)
        document.record(source, at: now)
        XCTAssertEqual(document.entries[identity]?.dailyCounts[today], 1_000_000)
        XCTAssertTrue(document.isValid)
    }

    func testAllMaximumBoundsTogetherRemainValidAndRankWithoutOverflow() {
        let buckets = Dictionary(uniqueKeysWithValues: (0..<30).map { (today - $0, 1_000_000) })
        let full = LaunchActivityEntry(lastLaunch: now, dailyCounts: buckets)
        let keys = (0..<256).map { String(format: "bundle:fixture.%03d", $0) }
        var document = LaunchActivityDocument(enabled: true, salt: salt,
            entries: Dictionary(uniqueKeysWithValues: keys.map { ($0, full) }))
        XCTAssertTrue(document.isValid)
        XCTAssertEqual(document.entries.count, 256)
        XCTAssertTrue(document.entries.values.allSatisfy { $0.dailyCounts.count == 30 })
        XCTAssertEqual(document.entries.values.reduce(0) { $0 + $1.dailyCounts.values.reduce(0, +) }, 7_680_000_000)
        for section in LaunchActivitySection.allCases {
            XCTAssertEqual(document.rankedKeys(section: section, at: now), keys)
        }
        let original = document
        document.prune(at: now)
        XCTAssertEqual(document, original)
    }

    func testPositiveTimestampBoundsAdmitEdgesAndRejectBeyondUpperBound() {
        for timestamp in [0.001, 253_402_300_799.0] {
            let clock = Date(timeIntervalSince1970: timestamp)
            let source = app(1)
            var document = LaunchActivityDocument(enabled: true, salt: salt)
            document.record(source, at: clock)
            XCTAssertTrue(document.isValid)
            XCTAssertEqual(document.entries.count, 1)
            XCTAssertEqual(document.entries[document.key(for: source)]?.lastLaunch, clock)
            XCTAssertEqual(document.rankedKeys(section: .recent, at: clock), [document.key(for: source)])
            XCTAssertTrue(document.rankedKeys(section: .recent, at: clock.addingTimeInterval(-0.0005)).isEmpty)
        }
        var document = LaunchActivityDocument(enabled: true, salt: salt)
        document.record(app(1), at: Date(timeIntervalSince1970: 253_402_300_800.0))
        XCTAssertTrue(document.entries.isEmpty)
    }

    func testRecordingEvictsOldestAt256AndRankedKeysAreNotSectionLimited() {
        var document = LaunchActivityDocument(enabled: true, salt: salt)
        for index in 0..<300 { document.record(app(index), at: now.addingTimeInterval(Double(index))) }
        XCTAssertTrue(document.isValid)
        XCTAssertEqual(document.entries.count, 256)
        XCTAssertNil(document.entries[document.key(for: app(43))])
        XCTAssertNotNil(document.entries[document.key(for: app(44))])
        XCTAssertEqual(document.rankedKeys(section: .recent, at: now.addingTimeInterval(300)).count, 256)
        XCTAssertEqual(document.rankedKeys(section: .frequent, at: now.addingTimeInterval(300)).count, 256)
    }

    func testOverCapFailsValidationAndPruneEvictsStableKeyTiesDeterministically() {
        let keys = (0..<257).map { String(format: "bundle:fixture.%03d", $0) }
        let pairs = keys.map { ($0, entry()) }
        var forward = LaunchActivityDocument(enabled: true, salt: salt, entries: Dictionary(uniqueKeysWithValues: pairs))
        var backward = LaunchActivityDocument(enabled: true, salt: salt, entries: Dictionary(uniqueKeysWithValues: pairs.reversed()))
        XCTAssertFalse(forward.isValid)
        XCTAssertTrue(forward.rankedKeys(section: .recent, at: now).isEmpty)
        forward.prune(at: now)
        backward.prune(at: now)
        XCTAssertEqual(forward, backward)
        XCTAssertTrue(forward.isValid)
        XCTAssertNil(forward.entries[keys.last!])
        XCTAssertEqual(forward.entries.count, 256)
    }

    func testVisibilityAndCatalogFilteringPrecedeRecentAndFrequentLimits() {
        let records = (0..<40).map { app($0) }
        var document = LaunchActivityDocument(enabled: true, salt: salt)
        for (index, source) in records.enumerated().reversed() {
            document.record(source, at: now.addingTimeInterval(-Double(index)))
        }
        // First 10 are unavailable; next 10 hidden; 20 eligible remain after both.
        let hidden = Set(records[10..<20].map { AppManagementPreferences.key(for: $0) })
        let base = AppLibraryProjection.make(catalog: .init(revision: .init(77), records: Array(records.dropFirst(10))),
                                              management: .init(hiddenKeys: hidden), preferences: .default)
        for (section, limit) in [(LaunchActivitySection.recent, 12), (.frequent, 8)] {
            let filtered = document.filtering(base, section: section, at: now)
            XCTAssertEqual(filtered.entries.map(\.record), Array(records[20..<(20 + limit)]))
            XCTAssertEqual(filtered.counts, base.counts)
            XCTAssertEqual(filtered.revision, base.revision)
        }
    }

    func testFilteringPreservesAliasCategoryQueryAndDormantHistory() throws {
        let present = app(1), absent = app(2)
        var document = LaunchActivityDocument(enabled: true, salt: salt)
        document.record(present, at: now)
        document.record(absent, at: now)
        let management = try XCTUnwrap(AppManagementPreferences.default.settingAlias("Renamed", for: present))
        let preferences = AppLibraryPreferences.default.settingCategory(.music, for: present)
        let base = AppLibraryProjection.make(catalog: .init(revision: .init(2), records: [present]),
                                              management: management, preferences: preferences, query: "Renamed")
        let original = document
        let filtered = document.filtering(base, section: .recent, at: now)
        XCTAssertEqual(filtered.entries, base.entries)
        XCTAssertEqual(filtered.entries.first?.displayName, "Renamed")
        XCTAssertEqual(filtered.entries.first?.category, .music)
        XCTAssertEqual(document, original)
        let noMatches = AppLibrarySnapshot(revision: base.revision, entries: [], counts: base.counts)
        XCTAssertTrue(document.filtering(noMatches, section: .recent, at: now).entries.isEmpty)
        document.enabled = false
        XCTAssertTrue(document.filtering(base, section: .recent, at: now).entries.isEmpty)
        XCTAssertEqual(document.filtering(base, section: .recent, at: now).counts, base.counts)
    }

    func testMultipleCatalogInstancesYieldOneIdentityUsingFirstBaseEntry() {
        let first = app(1, bundleID: "fixture.shared"), second = app(2, bundleID: "fixture.shared")
        var document = LaunchActivityDocument(enabled: true, salt: salt)
        document.record(first, at: now)
        let base = AppLibrarySnapshot(revision: .init(8), entries: [
            .init(record: first, displayName: "First", category: .other),
            .init(record: second, displayName: "Second", category: .other)
        ], counts: [.other: 2])
        let filtered = document.filtering(base, section: .recent, at: now)
        XCTAssertEqual(filtered.entries.count, 1)
        XCTAssertEqual(filtered.entries.first?.record, first)
        XCTAssertEqual(filtered.counts, [.other: 2])
    }
}
