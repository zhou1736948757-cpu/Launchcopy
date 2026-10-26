import Foundation

public enum AppSourcesLoadResult: Equatable, Sendable {
    case loaded(AppSourcesPreferences)
    case corrupt
    case futureVersion(Int)

    /// The owner chooses the safe fallback; loading itself never repairs stored bytes.
    public var preferences: AppSourcesPreferences {
        if case .loaded(let value) = self { return value }
        return .default
    }
}

public enum AppSourcesSaveResult: Equatable, Sendable {
    case saved
    case invalidPreferences
    case futureVersion(Int)
    case failed
}

@MainActor
public protocol AppSourcesPersisting: AnyObject {
    func load() -> AppSourcesLoadResult
    func save(_ preferences: AppSourcesPreferences) -> AppSourcesSaveResult
}

/// Private, independent preferences. Each explicit save replaces exactly one versioned payload.
@MainActor
public final class UserDefaultsAppSourcesStore: AppSourcesPersisting {
    nonisolated public static let defaultSuiteName = "com.launchcopy.app-sources"
    static let payloadKey = "sources.payload"
    private static let maximumPayloadBytes = 1_048_576
    private let defaults: UserDefaults

    private struct Header: Decodable { var schemaVersion: Int }
    private struct Payload: Codable {
        var schemaVersion: Int
        var preferences: AppSourcesPreferences
    }

    public init?(suiteName: String = defaultSuiteName) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        self.defaults = defaults
    }

    init(defaults: UserDefaults) { self.defaults = defaults }

    public func load() -> AppSourcesLoadResult {
        guard defaults.object(forKey: Self.payloadKey) != nil else { return .loaded(.default) }
        guard let data = defaults.data(forKey: Self.payloadKey),
              data.count <= Self.maximumPayloadBytes,
              let header = try? JSONDecoder().decode(Header.self, from: data) else { return .corrupt }
        if header.schemaVersion > 1 { return .futureVersion(header.schemaVersion) }
        guard header.schemaVersion == 1,
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.preferences.isValid else { return .corrupt }
        return .loaded(payload.preferences)
    }

    public func save(_ preferences: AppSourcesPreferences) -> AppSourcesSaveResult {
        if case .futureVersion(let version) = load() { return .futureVersion(version) }
        guard preferences.isValid else { return .invalidPreferences }
        // An oversized existing payload cannot be inspected safely for its version.
        // Preserve it rather than accidentally overwriting a newer schema.
        if let existing = defaults.data(forKey: Self.payloadKey), existing.count > Self.maximumPayloadBytes {
            return .failed
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(Payload(schemaVersion: 1, preferences: preferences)),
              data.count <= Self.maximumPayloadBytes else { return .failed }
        defaults.set(data, forKey: Self.payloadKey)
        return .saved
    }
}

/// Test/service composition storage; never opens production UserDefaults.
@MainActor
public final class InMemoryAppSourcesStore: AppSourcesPersisting {
    private var preferences: AppSourcesPreferences

    public init(preferences: AppSourcesPreferences = .default) { self.preferences = preferences }

    public func load() -> AppSourcesLoadResult {
        preferences.isValid ? .loaded(preferences) : .corrupt
    }

    public func save(_ preferences: AppSourcesPreferences) -> AppSourcesSaveResult {
        guard preferences.isValid else { return .invalidPreferences }
        self.preferences = preferences
        return .saved
    }
}
