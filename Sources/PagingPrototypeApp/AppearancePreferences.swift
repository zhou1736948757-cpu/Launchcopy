import Foundation
import AppGridUI

/// Independently authored appearance state; unrelated to activation or workspace layout.
public struct AppearancePreferences: Codable, Equatable, Sendable {
    public static let defaultBlurRadius = 18
    public static let defaultIconSide = 80
    public static let supportedIconSide = 32...96
    public static let supportedBlurRadius = 0...60
    public var showsAppLabels: Bool
    public var wallpaperBlurRadius: Int
    public var preferredIconSide: Int
    public var appLabelFontSize: Int
    /// Nil inherits the base size, as saved by schema 1/2. New profiles choose 80pt.
    public var mainPreferredIconSide: Int?

    public init(showsAppLabels: Bool = true, wallpaperBlurRadius: Int = defaultBlurRadius,
                preferredIconSide: Int = Self.defaultIconSide, appLabelFontSize: Int = 11,
                mainPreferredIconSide: Int? = 80) {
        self.showsAppLabels = showsAppLabels
        self.wallpaperBlurRadius = wallpaperBlurRadius
        self.preferredIconSide = preferredIconSide
        self.appLabelFontSize = appLabelFontSize
        self.mainPreferredIconSide = mainPreferredIconSide
    }

    public var itemAppearance: GridItemAppearance {
        GridItemAppearance(preferredIconSide: preferredIconSide, appLabelFontSize: appLabelFontSize)
    }
    public var mainItemAppearance: GridItemAppearance {
        GridItemAppearance(preferredIconSide: mainPreferredIconSide ?? preferredIconSide,
                           appLabelFontSize: appLabelFontSize)
    }
    public var isValid: Bool {
        Self.supportedBlurRadius.contains(wallpaperBlurRadius)
            && Self.supportedIconSide.contains(preferredIconSide) && itemAppearance.isValid
            && (mainPreferredIconSide.map { (32...96).contains($0) } ?? true)
    }
    public static let `default` = AppearancePreferences()
}

public enum AppearancePreferencesLoadResult: Equatable, Sendable {
    case loaded(AppearancePreferences)
    case corrupt
    case futureVersion(Int)

    public var preferences: AppearancePreferences {
        if case .loaded(let preferences) = self { return preferences }
        return .default
    }
}

public enum AppearancePreferencesSaveResult: Equatable, Sendable {
    case saved
    case invalidPreferences
    case futureVersion(Int)
    case encodingFailed
}

@MainActor
public protocol AppearancePreferencesPersisting: AnyObject {
    func load() -> AppearancePreferencesLoadResult
    func save(_ preferences: AppearancePreferences) -> AppearancePreferencesSaveResult
}

/// One atomic payload in a dedicated suite; loading never repairs or overwrites data.
@MainActor
public final class UserDefaultsAppearancePreferencesStore: AppearancePreferencesPersisting {
    nonisolated public static let defaultSuiteName = "com.launchcopy.appearance"
    static let payloadKey = "appearance.payload"
    private let defaults: UserDefaults
    private struct Header: Decodable { var schemaVersion: Int }
    private struct LegacyPayload: Decodable {
        struct Preferences: Decodable { var showsAppLabels: Bool; var wallpaperBlurRadius: Int }
        var preferences: Preferences
    }
    private struct SchemaTwoPayload: Decodable {
        struct Preferences: Decodable {
            var showsAppLabels: Bool
            var wallpaperBlurRadius: Int
            var preferredIconSide: Int
            var appLabelFontSize: Int
        }
        var preferences: Preferences
    }
    private struct Payload: Codable {
        var schemaVersion: Int
        var preferences: AppearancePreferences
    }

    public init?(suiteName: String = defaultSuiteName) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return nil }
        self.defaults = defaults
    }

    init(defaults: UserDefaults) { self.defaults = defaults }

    public func load() -> AppearancePreferencesLoadResult {
        guard defaults.object(forKey: Self.payloadKey) != nil else { return .loaded(.default) }
        guard let data = defaults.data(forKey: Self.payloadKey),
              let header = try? JSONDecoder().decode(Header.self, from: data) else { return .corrupt }
        if header.schemaVersion > 4 { return .futureVersion(header.schemaVersion) }
        let preferences: AppearancePreferences
        switch header.schemaVersion {
        case 1:
            guard let legacy = try? JSONDecoder().decode(LegacyPayload.self, from: data) else { return .corrupt }
            preferences = AppearancePreferences(showsAppLabels: legacy.preferences.showsAppLabels,
                                               wallpaperBlurRadius: legacy.preferences.wallpaperBlurRadius,
                                               preferredIconSide: 48,
                                               mainPreferredIconSide: nil)
        case 2:
            guard let legacy = try? JSONDecoder().decode(SchemaTwoPayload.self, from: data) else { return .corrupt }
            preferences = AppearancePreferences(showsAppLabels: legacy.preferences.showsAppLabels,
                                               wallpaperBlurRadius: legacy.preferences.wallpaperBlurRadius,
                                               preferredIconSide: legacy.preferences.preferredIconSide,
                                               appLabelFontSize: legacy.preferences.appLabelFontSize,
                                               mainPreferredIconSide: nil)
        case 3, 4:
            guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return .corrupt }
            preferences = payload.preferences
        default: return .corrupt
        }
        // Older schemas cannot acquire values their writers never supported.
        if header.schemaVersion <= 3, !(32...64).contains(preferences.preferredIconSide) { return .corrupt }
        guard preferences.isValid else { return .corrupt }
        return .loaded(preferences)
    }

    public func save(_ preferences: AppearancePreferences) -> AppearancePreferencesSaveResult {
        if case .futureVersion(let version) = load() { return .futureVersion(version) }
        guard preferences.isValid else { return .invalidPreferences }
        guard let data = try? JSONEncoder().encode(Payload(schemaVersion: 4, preferences: preferences)) else {
            return .encodingFailed
        }
        defaults.set(data, forKey: Self.payloadKey)
        return .saved
    }
}

@MainActor
public final class InMemoryAppearancePreferencesStore: AppearancePreferencesPersisting {
    private var preferences: AppearancePreferences
    public init(preferences: AppearancePreferences = .default) { self.preferences = preferences }
    public func load() -> AppearancePreferencesLoadResult { .loaded(preferences) }
    public func save(_ preferences: AppearancePreferences) -> AppearancePreferencesSaveResult {
        guard preferences.isValid else { return .invalidPreferences }
        self.preferences = preferences
        return .saved
    }
}

/// Commit only after persistence accepts the draft. No frame or slider-event work.
@MainActor
public final class AppearanceSettingsCoordinator {
    public private(set) var committed: AppearancePreferences
    public private(set) var loadResult: AppearancePreferencesLoadResult
    private let store: any AppearancePreferencesPersisting
    private let applyPreferences: (AppearancePreferences) -> Void
    /// Successful command acknowledgment, including unchanged healthy values.
    /// The live owner uses this to order commands against pending intentions.
    var onAcknowledged: ((AppearancePreferences) -> Void)?

    public init(store: any AppearancePreferencesPersisting,
                applyPreferences: @escaping (AppearancePreferences) -> Void) {
        self.store = store
        self.applyPreferences = applyPreferences
        loadResult = store.load()
        committed = loadResult.preferences
    }

    /// Fresh read for live-edit admission; inspection never repairs storage.
    func inspectLoadResult() -> AppearancePreferencesLoadResult { store.load() }

    @discardableResult
    public func apply(_ draft: AppearancePreferences) -> AppearancePreferencesSaveResult {
        guard draft.isValid else { return .invalidPreferences }
        let persistedResult = store.load()
        if case .futureVersion(let version) = persistedResult { return .futureVersion(version) }
        // Skip persistence only when the current healthy payload matches the unchanged draft.
        if draft == committed, case .loaded(let preferences) = persistedResult, preferences == draft {
            loadResult = persistedResult
            onAcknowledged?(draft)
            return .saved
        }
        let result = store.save(draft)
        guard result == .saved else { return result }
        let changed = draft != committed
        committed = draft
        loadResult = .loaded(draft)
        if changed { applyPreferences(draft) }
        onAcknowledged?(draft)
        return .saved
    }
}

/// Saved settings and displayed geometry can differ while an input owner is active.
public enum AppearancePresentationState: Equatable, Sendable {
    case applied
    case queued
    case unavailable
}
