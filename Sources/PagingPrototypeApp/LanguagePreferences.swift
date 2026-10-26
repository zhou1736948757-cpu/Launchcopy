import Foundation
import LauncherLocalization

public struct LanguagePreferences: Codable, Equatable, Sendable {
    public var language: InterfaceLanguagePreference

    public init(language: InterfaceLanguagePreference = .system) {
        self.language = language
    }

    public static let `default` = LanguagePreferences()
}

public enum LanguagePreferencesLoadResult: Equatable, Sendable {
    case missing
    case loaded(LanguagePreferences)
    case corrupt
    case futureVersion(Int)
    case futureVersionUnrepresentable
    case oversized
    case unavailable

    public var preferences: LanguagePreferences {
        if case let .loaded(preferences) = self {
            return preferences
        }
        return .default
    }
}

public enum LanguagePreferencesSaveResult: Equatable, Sendable {
    case saved
    case futureVersion(Int)
    case futureVersionUnrepresentable
    case oversized
    case unavailable
    case encodingFailed
}

@MainActor
public protocol LanguagePreferencesPersisting: AnyObject {
    func load() -> LanguagePreferencesLoadResult
    func save(_ preferences: LanguagePreferences) -> LanguagePreferencesSaveResult
}

@MainActor
public final class UserDefaultsLanguagePreferencesStore: LanguagePreferencesPersisting {
    nonisolated public static let defaultSuiteName = "com.launchcopy.language"
    nonisolated static let payloadKey = "language.payload"
    nonisolated static let maximumPayloadBytes = 16_384

    private let defaults: UserDefaults

    public init?(suiteName: String = defaultSuiteName) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            return nil
        }
        self.defaults = defaults
    }

    internal init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func load() -> LanguagePreferencesLoadResult {
        // Inspect the stored type; data(forKey:) would lose the missing/corrupt distinction.
        guard let object = defaults.object(forKey: Self.payloadKey) else {
            return .missing
        }
        guard let data = object as? Data else {
            // Wrong-type property lists can also contain large, uninspectable content.
            var remainingBytes = Self.maximumPayloadBytes
            return Self.fitsInspectionBudget(object, remaining: &remainingBytes)
                ? .corrupt : .oversized
        }
        guard data.count <= Self.maximumPayloadBytes else {
            return .oversized
        }

        guard let normalized = Self.normalizedJSONData(data) else { return .corrupt }
        // Even an ambiguous/duplicate header cannot hide an unrepresentable
        // future numeric token behind a known value selected by another decoder.
        if let protected = Self.protectedRootVersion(normalized) {
            return protected
        }
        // A valid future header protects bytes even if its body is absent or unknown.
        guard let header = try? JSONDecoder().decode(Header.self, from: normalized),
              header.schemaVersion >= 1 else {
            // A numeric future header can exceed Int even in a small payload.
            // Preserve that unrepresentable version instead of permitting repair.
            if let root = (try? JSONSerialization.jsonObject(with: normalized)) as? [String: Any],
               let version = root["schemaVersion"] as? NSNumber,
               version.doubleValue >= Double(Int.max) {
                return .futureVersionUnrepresentable
            }
            return .corrupt
        }
        if header.schemaVersion > 1 {
            return .futureVersion(header.schemaVersion)
        }

        // Version 1 has an exact shape and a validated raw language identifier.
        guard let root = (try? JSONSerialization.jsonObject(with: normalized)) as? [String: Any],
              Set(root.keys) == Set(["schemaVersion", "preferences"]),
              let preferences = root["preferences"] as? [String: Any],
              Set(preferences.keys) == Set(["language"]),
              let rawLanguage = preferences["language"] as? String,
              let language = InterfaceLanguagePreference(rawValue: rawLanguage) else {
            return .corrupt
        }
        // Foundation decoders can resolve duplicate keys differently. A newer
        // root version observed by either reader remains protected.
        if let rootVersion = root["schemaVersion"] as? NSNumber,
           rootVersion.doubleValue >= 2, rootVersion.doubleValue.rounded() == rootVersion.doubleValue {
            if let version = Int(exactly: rootVersion.doubleValue) { return .futureVersion(version) }
            return .futureVersionUnrepresentable
        }
        return .loaded(LanguagePreferences(language: language))
    }

    public func save(_ preferences: LanguagePreferences) -> LanguagePreferencesSaveResult {
        // Reinspect before equality: another owner may have replaced or deleted the payload.
        switch load() {
        case let .futureVersion(version):
            return .futureVersion(version)
        case .futureVersionUnrepresentable:
            return .futureVersionUnrepresentable
        case .oversized:
            return .oversized
        case .unavailable:
            return .unavailable
        case let .loaded(current) where current == preferences:
            return .saved
        case .missing, .corrupt, .loaded:
            break
        }

        let data: Data
        do {
            data = try JSONEncoder().encode(Payload(schemaVersion: 1, preferences: preferences))
        } catch {
            return .encodingFailed
        }
        guard data.count <= Self.maximumPayloadBytes else {
            return .oversized
        }
        defaults.set(data, forKey: Self.payloadKey)
        // UserDefaults acknowledgement does not establish a disk flush or restart durability.
        return .saved
    }

    /// Foundation numeric decoding also rejects values beyond Double/Decimal.
    /// Inspect only root-level schemaVersion tokens, without converting the whole
    /// document's numbers. This conservative read-only preflight never repairs data.
    private static func normalizedJSONData(_ data: Data) -> Data? {
        let text: String?
        if data.starts(with: [0xFF, 0xFE, 0x00, 0x00]) { text = String(data: data, encoding: .utf32LittleEndian) }
        else if data.starts(with: [0x00, 0x00, 0xFE, 0xFF]) { text = String(data: data, encoding: .utf32BigEndian) }
        else if data.starts(with: [0xFF, 0xFE]) { text = String(data: data, encoding: .utf16LittleEndian) }
        else if data.starts(with: [0xFE, 0xFF]) { text = String(data: data, encoding: .utf16BigEndian) }
        else if data.count >= 4, data[0] == 0, data[1] == 0, data[2] == 0 { text = String(data: data, encoding: .utf32BigEndian) }
        else if data.count >= 4, data[1] == 0, data[2] == 0, data[3] == 0 { text = String(data: data, encoding: .utf32LittleEndian) }
        else if data.count >= 4, data[0] == 0, data[2] == 0 { text = String(data: data, encoding: .utf16BigEndian) }
        else if data.count >= 4, data[1] == 0, data[3] == 0 { text = String(data: data, encoding: .utf16LittleEndian) }
        else { text = String(data: data, encoding: .utf8) }
        guard var text else { return nil }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        return Data(text.utf8)
    }

    private static func protectedRootVersion(_ data: Data) -> LanguagePreferencesLoadResult? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let bytes = Array(text.utf8)
        var index = bytes.starts(with: [0xEF, 0xBB, 0xBF]) ? 3 : 0
        func whitespace(_ byte: UInt8) -> Bool { [9, 10, 13, 32].contains(byte) }
        while index < bytes.count, whitespace(bytes[index]) { index += 1 }
        guard index < bytes.count, bytes[index] == 123 else { return nil }
        var depth = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 34 {
                let start = index
                index += 1
                var escaped = false
                while index < bytes.count {
                    let character = bytes[index]
                    if !escaped && character == 34 { break }
                    if !escaped && character == 92 { escaped = true }
                    else { escaped = false }
                    index += 1
                }
                guard index < bytes.count else { return nil }
                let literal = Data(bytes[start...index])
                index += 1
                guard depth == 1,
                      let key = try? JSONDecoder().decode(String.self, from: literal),
                      key == "schemaVersion" else { continue }
                var cursor = index
                while cursor < bytes.count, whitespace(bytes[cursor]) { cursor += 1 }
                guard cursor < bytes.count, bytes[cursor] == 58 else { continue }
                cursor += 1
                while cursor < bytes.count, whitespace(bytes[cursor]) { cursor += 1 }
                let numberStart = cursor
                while cursor < bytes.count, !whitespace(bytes[cursor]),
                      ![44, 125, 93].contains(bytes[cursor]) { cursor += 1 }
                let token = String(decoding: bytes[numberStart..<cursor], as: UTF8.self)
                let pattern = #"^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$"#
                if token.range(of: pattern, options: .regularExpression) != nil {
                    // Match the schema decoder's integral decimal/exponent forms,
                    // not only plain integer spellings (e.g. 2.0 and 2e0).
                    let version = Int(token) ?? (try? JSONDecoder().decode(Int.self, from: Data(token.utf8)))
                    if let version, version > 1 { return .futureVersion(version) }
                    if version == nil, let number = Double(token), number >= Double(Int.max) {
                        return .futureVersionUnrepresentable
                    }
                }
                // Continue scanning rather than treating nested values as headers.
            } else if byte == 123 || byte == 91 { depth += 1; index += 1 }
            else if byte == 125 || byte == 93 { depth -= 1; index += 1 }
            else { index += 1 }
        }
        return nil
    }

    private struct Header: Decodable {
        let schemaVersion: Int
    }

    private struct Payload: Encodable {
        let schemaVersion: Int
        let preferences: LanguagePreferences
    }

    // Bound malformed property-list inspection without serializing a potentially huge value.
    // Exhausted byte/depth budgets are read-only, just like oversized JSON Data.
    private static func fitsInspectionBudget(
        _ value: Any,
        remaining: inout Int,
        depth: Int = 0
    ) -> Bool {
        guard depth < 64, remaining > 0 else { return false }
        remaining -= 1
        if let data = value as? Data {
            guard data.count <= remaining else { return false }
            remaining -= data.count
        } else if let string = value as? String {
            let count = string.utf8.prefix(remaining + 1).count
            guard count <= remaining else { return false }
            remaining -= count
        } else if let values = value as? [Any] {
            guard values.count <= remaining else { return false }
            for element in values {
                guard fitsInspectionBudget(element, remaining: &remaining, depth: depth + 1) else {
                    return false
                }
            }
        } else if let values = value as? [String: Any] {
            guard values.count <= remaining else { return false }
            for (key, element) in values {
                guard fitsInspectionBudget(key, remaining: &remaining, depth: depth + 1),
                      fitsInspectionBudget(element, remaining: &remaining, depth: depth + 1) else {
                    return false
                }
            }
        } else {
            guard remaining >= 8 else { return false }
            remaining -= 8
        }
        return true
    }
}

@MainActor
public final class UnavailableLanguagePreferencesStore: LanguagePreferencesPersisting {
    public init() {}

    public func load() -> LanguagePreferencesLoadResult {
        .unavailable
    }

    public func save(_ preferences: LanguagePreferences) -> LanguagePreferencesSaveResult {
        .unavailable
    }
}
