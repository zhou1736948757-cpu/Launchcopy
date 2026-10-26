import AppGridUI
import Foundation

public enum AppManagementLoadResult: Equatable, Sendable {
    case loaded(AppManagementPreferences)
    case corrupt
    case futureVersion(Int)
    public var preferences: AppManagementPreferences {
        if case .loaded(let value) = self { return value }
        return .default
    }
}

public enum AppManagementSaveResult: Equatable, Sendable {
    case saved
    case invalidPreferences
    case futureVersion(Int)
    case failed
}

@MainActor
public protocol AppManagementPersisting: AnyObject {
    func load() -> AppManagementLoadResult
    func save(_ preferences: AppManagementPreferences) -> AppManagementSaveResult
}

/// Private identity/alias payload; never shared with diagnostics or the layout store.
@MainActor
public final class UserDefaultsAppManagementStore: AppManagementPersisting {
    nonisolated public static let defaultSuiteName = "com.launchcopy.app-management"
    static let payloadKey = "management.payload"
    private let defaults: UserDefaults
    private struct Header: Decodable { var schemaVersion: Int }
    private struct Payload: Codable { var schemaVersion: Int; var preferences: AppManagementPreferences }
    private struct LegacyPayload: Decodable {
        struct Preferences: Decodable {
            var hiddenKeys: Set<String>
            var aliases: [String: String]
        }
        var preferences: Preferences
    }

    public init?(suiteName: String = defaultSuiteName) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        self.defaults = defaults
    }
    init(defaults: UserDefaults) { self.defaults = defaults }

    public func load() -> AppManagementLoadResult {
        guard defaults.object(forKey: Self.payloadKey) != nil else { return .loaded(.default) }
        guard let data = defaults.data(forKey: Self.payloadKey), data.count <= 1_048_576,
              let header = try? JSONDecoder().decode(Header.self, from: data) else { return .corrupt }
        if header.schemaVersion > 2 { return .futureVersion(header.schemaVersion) }
        let preferences: AppManagementPreferences
        switch header.schemaVersion {
        case 1:
            guard let legacy = try? JSONDecoder().decode(LegacyPayload.self, from: data) else { return .corrupt }
            preferences = .init(hiddenKeys: legacy.preferences.hiddenKeys, aliases: legacy.preferences.aliases)
        case 2:
            guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return .corrupt }
            preferences = payload.preferences
        default: return .corrupt
        }
        guard preferences.isValid else { return .corrupt }
        return .loaded(preferences)
    }
    public func save(_ preferences: AppManagementPreferences) -> AppManagementSaveResult {
        if case .futureVersion(let version) = load() { return .futureVersion(version) }
        guard preferences.isValid else { return .invalidPreferences }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(Payload(schemaVersion: 2, preferences: preferences)),
              data.count <= 1_048_576 else { return .failed }
        defaults.set(data, forKey: Self.payloadKey)
        return .saved
    }
}

/// An unresolved isolated profile must never fall back to the formal suite.
@MainActor
final class UnavailableAppManagementStore: AppManagementPersisting {
    func load() -> AppManagementLoadResult { .corrupt }
    func save(_ preferences: AppManagementPreferences) -> AppManagementSaveResult { .failed }
}

@MainActor
public final class InMemoryAppManagementStore: AppManagementPersisting {
    private var preferences: AppManagementPreferences
    public init(preferences: AppManagementPreferences = .default) { self.preferences = preferences }
    public func load() -> AppManagementLoadResult { .loaded(preferences) }
    public func save(_ preferences: AppManagementPreferences) -> AppManagementSaveResult {
        guard preferences.isValid else { return .invalidPreferences }
        self.preferences = preferences
        return .saved
    }
}

@MainActor
public final class AppManagementCoordinator {
    public private(set) var committed: AppManagementPreferences
    public private(set) var loadResult: AppManagementLoadResult
    private let store: any AppManagementPersisting
    private let applyPreferences: (AppManagementPreferences) -> Void
    public init(store: any AppManagementPersisting, applyPreferences: @escaping (AppManagementPreferences) -> Void) {
        self.store = store
        self.applyPreferences = applyPreferences
        loadResult = store.load()
        committed = loadResult.preferences
    }
    @discardableResult
    public func apply(_ preferences: AppManagementPreferences) -> AppManagementSaveResult {
        guard preferences.isValid else { return .invalidPreferences }
        if case .futureVersion(let version) = store.load() { return .futureVersion(version) }
        if preferences == committed, case .loaded = loadResult { return .saved }
        let result = store.save(preferences)
        guard result == .saved else { return result }
        let changed = preferences != committed
        committed = preferences
        loadResult = .loaded(preferences)
        if changed { applyPreferences(preferences) }
        return .saved
    }

    /// The new toggle is not an implicit corruption-repair operation. Revalidate
    /// the actual baseline before deriving a draft; do not discard newer metadata.
    public func applySearchByBundleIdentifier(_ enabled: Bool) -> AppManagementSaveResult {
        switch store.load() {
        case .futureVersion(let version): return .futureVersion(version)
        case .corrupt: return .failed
        case .loaded(let current):
            guard current == committed else { return .failed }
        }
        var draft = committed
        draft.searchByBundleIdentifier = enabled
        return apply(draft)
    }
}
