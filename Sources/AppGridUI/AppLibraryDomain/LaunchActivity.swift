import AppCatalogCore
import CryptoKit
import Foundation

public enum LaunchActivitySection: String, CaseIterable, Codable, Sendable {
    case recent, frequent
}

public struct LaunchActivityEntry: Codable, Equatable, Sendable {
    public var lastLaunch: Date
    /// Epoch-day UTC, never a locale or time-zone dependent calendar identifier.
    public var dailyCounts: [Int: Int]

    public init(lastLaunch: Date, dailyCounts: [Int: Int]) {
        self.lastLaunch = lastLaunch
        self.dailyCounts = dailyCounts
    }
}

/// Local accepted-request history, not evidence of process starts or application use.
/// All operations are pure. The owner gates accepted events, clear generations and I/O.
public struct LaunchActivityDocument: Codable, Equatable, Sendable {
    public var enabled: Bool
    public let salt: String
    public var entries: [String: LaunchActivityEntry]

    // Saturation bounds keep arithmetic and even adversarial decoded documents bounded.
    private static let maximumIdentities = 256
    private static let maximumDailyCount = 1_000_000
    private static let secondsPerDay = 86_400.0
    // Last second of year 9999; bounds conversion to epoch-day and date arithmetic.
    private static let maximumTimestamp = 253_402_300_799.0

    public init(enabled: Bool = false,
                salt: String = (UUID().uuidString + UUID().uuidString)
                    .replacingOccurrences(of: "-", with: "").lowercased(),
                entries: [String: LaunchActivityEntry] = [:]) {
        self.enabled = enabled
        self.salt = salt
        self.entries = entries
    }

    /// Structural validation has no dependency on the wall clock. Expiry and future
    /// exclusion happen in prune/projection, so loading never silently repairs bad data.
    public var isValid: Bool {
        Self.isHexDigest(salt) && entries.count <= Self.maximumIdentities
            && entries.allSatisfy { Self.isValidKey($0.key) && Self.isValidEntry($0.value) }
    }

    public func key(for record: AppRecord) -> String {
        switch PersistentAppReference.from(record: record) {
        case .bundleID(let canonicalID):
            return "bundle:" + canonicalID
        case .canonicalPath(let canonicalPath):
            let digest = SHA256.hash(data: Data((salt + canonicalPath).utf8))
            return "path-hash:" + digest.map { String(format: "%02x", $0) }.joined()
        }
    }

    /// One call represents one already validated accepted request. Equal timestamps
    /// can be distinct requests; the launch owner, not this document, deduplicates events.
    public mutating func record(_ record: AppRecord, at now: Date) {
        guard enabled, isValid, let today = Self.day(for: now) else { return }
        let identity = key(for: record)
        guard Self.isValidKey(identity) else { return }
        prune(at: now)
        var entry = entries[identity] ?? LaunchActivityEntry(lastLaunch: now, dailyCounts: [:])
        entry.lastLaunch = now
        entry.dailyCounts[today] = min(entry.dailyCounts[today, default: 0], Self.maximumDailyCount - 1) + 1
        entries[identity] = entry
        prune(at: now)
    }

    /// Retain today and the previous 29 UTC days, then prefer newest identities.
    /// Invalid clocks do not erase data. Future entries are removed as a whole:
    /// their same-day counts cannot safely be attributed to the past after rollback.
    public mutating func prune(at now: Date) {
        guard let today = Self.day(for: now) else { return }
        guard Self.isHexDigest(salt) else { entries.removeAll(); return }
        var retained: [String: LaunchActivityEntry] = [:]
        for (identity, stored) in entries {
            guard Self.isValidKey(identity), Self.isValidEntry(stored), stored.lastLaunch <= now else { continue }
            let buckets = stored.dailyCounts.filter { $0.key >= today - 29 && $0.key <= today }
            guard !buckets.isEmpty else { continue }
            retained[identity] = LaunchActivityEntry(lastLaunch: stored.lastLaunch, dailyCounts: buckets)
        }
        let newest = retained.keys.sorted {
            let lhs = retained[$0]!, rhs = retained[$1]!
            return lhs.lastLaunch == rhs.lastLaunch ? $0 < $1 : lhs.lastLaunch > rhs.lastLaunch
        }
        entries = Dictionary(uniqueKeysWithValues: newest.prefix(Self.maximumIdentities).map { ($0, retained[$0]!) })
    }

    /// Rank every eligible identity before visibility filtering and section limits.
    public func rankedKeys(section: LaunchActivitySection, at now: Date) -> [String] {
        guard enabled, isValid, let today = Self.day(for: now) else { return [] }
        let scores: [(key: String, last: Date, total: Int)] = entries.compactMap { identity, entry in
            guard entry.lastLaunch <= now else { return nil }
            let total = entry.dailyCounts.reduce(0) { sum, bucket in
                sum + ((bucket.key >= today - 29 && bucket.key <= today) ? bucket.value : 0)
            }
            guard total > 0 else { return nil }
            return (identity, entry.lastLaunch, total)
        }
        return scores.sorted { lhs, rhs in
            if section == .frequent, lhs.total != rhs.total { return lhs.total > rhs.total }
            if lhs.last != rhs.last { return lhs.last > rhs.last }
            return lhs.key < rhs.key
        }.map(\.key)
    }

    /// The supplied base already enforces hidden/query/category/catalog admission.
    /// Preserve its revision/count meanings and its effective aliases/categories.
    public func filtering(_ snapshot: AppLibrarySnapshot, section: LaunchActivitySection,
                          at now: Date) -> AppLibrarySnapshot {
        let ranked = rankedKeys(section: section, at: now)
        guard !ranked.isEmpty else {
            return AppLibrarySnapshot(revision: snapshot.revision, entries: [], counts: snapshot.counts)
        }
        var visibleByKey: [String: AppLibraryEntry] = [:]
        for entry in snapshot.entries {
            let identity = key(for: entry.record)
            // A multi-instance catalog still contributes only one stable identity.
            if visibleByKey[identity] == nil { visibleByKey[identity] = entry }
        }
        let limit = section == .recent ? 12 : 8
        let visible = ranked.lazy.compactMap { visibleByKey[$0] }.prefix(limit)
        return AppLibrarySnapshot(revision: snapshot.revision, entries: Array(visible), counts: snapshot.counts)
    }

    private static func day(for date: Date) -> Int? {
        let timestamp = date.timeIntervalSince1970
        guard timestamp.isFinite, timestamp > 0, timestamp <= maximumTimestamp else { return nil }
        return Int(floor(timestamp / secondsPerDay))
    }

    private static func isValidEntry(_ entry: LaunchActivityEntry) -> Bool {
        guard let lastDay = day(for: entry.lastLaunch), !entry.dailyCounts.isEmpty,
              entry.dailyCounts.count <= 30, entry.dailyCounts[lastDay] != nil else { return false }
        return entry.dailyCounts.allSatisfy { day, count in
            day >= 0 && day >= lastDay - 29 && day <= lastDay
                && count > 0 && count <= maximumDailyCount
        }
    }

    private static func isHexDigest(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    private static func isValidKey(_ key: String) -> Bool {
        if key.hasPrefix("path-hash:") { return isHexDigest(String(key.dropFirst(10))) }
        guard key.hasPrefix("bundle:") else { return false }
        let identifier = key.dropFirst(7)
        return !identifier.isEmpty && identifier.utf8.count <= 512
            && identifier.unicodeScalars.allSatisfy {
                !CharacterSet.whitespacesAndNewlines.contains($0)
                    && !CharacterSet.controlCharacters.contains($0) && $0 != "/" && $0 != "\\"
            }
    }
}
