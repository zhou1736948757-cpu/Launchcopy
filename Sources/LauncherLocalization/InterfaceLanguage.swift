import Foundation

public enum InterfaceLanguage: String, CaseIterable, Codable, Sendable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case japanese = "ja"
}

public enum InterfaceLanguagePreference: String, CaseIterable, Codable, Sendable {
    case system = "system"
    case simplifiedChinese = "zh-Hans"
    case english = "en"
    case japanese = "ja"

    /// Uses only the supplied ordered identifiers; it never reads or changes OS locale.
    public func resolve(preferredLanguages: [String]) -> InterfaceLanguage {
        switch self {
        case .english: return .english
        case .simplifiedChinese: return .simplifiedChinese
        case .japanese: return .japanese
        case .system:
            for identifier in preferredLanguages {
                if let language = SupportedLanguageTag(identifier)?.language {
                    return language
                }
            }
            return .english
        }
    }
}

/// A bounded BCP-47-style parser, rather than permissive Foundation locale inference.
/// Accepts the supported primary languages, compatible known scripts, regions,
/// well-formed variants, extensions and private-use tails. Extlangs and grandfathered
/// identifiers are outside this interface-language contract and are rejected.
private struct SupportedLanguageTag {
    let language: InterfaceLanguage

    init?(_ identifier: String) {
        guard !identifier.isEmpty, identifier.utf8.count <= 255,
              identifier.utf8.allSatisfy({ Self.isAlpha($0) || Self.isDigit($0) || $0 == 45 || $0 == 95 }) else {
            return nil
        }
        let parts = identifier.replacingOccurrences(of: "_", with: "-")
            .lowercased().split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard !parts.contains(""), let primary = parts.first,
              ["en", "ja", "zh"].contains(primary) else { return nil }

        var cursor = 1
        var script: String?
        var region: String?
        if cursor < parts.count, parts[cursor].utf8.count == 4,
           parts[cursor].utf8.allSatisfy(Self.isAlpha) {
            script = parts[cursor]
            cursor += 1
        }
        if cursor < parts.count {
            let candidate = parts[cursor]
            if (candidate.utf8.count == 2 && candidate.utf8.allSatisfy(Self.isAlpha)) ||
                (candidate.utf8.count == 3 && candidate.utf8.allSatisfy(Self.isDigit)) {
                region = candidate
                cursor += 1
            }
        }

        var variants = Set<String>()
        while cursor < parts.count, Self.isVariant(parts[cursor]) {
            guard variants.insert(parts[cursor]).inserted else { return nil }
            cursor += 1
        }
        var singletons = Set<String>()
        while cursor < parts.count {
            let singleton = parts[cursor]
            guard singleton.utf8.count == 1,
                  singletons.insert(singleton).inserted else { return nil }
            cursor += 1
            let start = cursor
            if singleton == "x" {
                // Private use is last and allows one-character subtags.
                guard cursor < parts.count,
                      parts[cursor...].allSatisfy({ (1...8).contains($0.utf8.count) }) else { return nil }
                cursor = parts.count
            } else {
                while cursor < parts.count, (2...8).contains(parts[cursor].utf8.count) {
                    cursor += 1
                }
                guard cursor > start else { return nil }
            }
        }

        switch primary {
        case "en":
            guard script == nil || script == "latn" else { return nil }
            language = .english
        case "ja":
            guard script == nil || script == "jpan" else { return nil }
            language = .japanese
        case "zh":
            // A supplied script takes precedence over region. Hant is unsupported.
            if let script {
                guard script == "hans" else { return nil }
            } else {
                guard region == nil || region == "cn" || region == "sg" else { return nil }
            }
            language = .simplifiedChinese
        default:
            return nil
        }
    }

    private static func isAlpha(_ byte: UInt8) -> Bool {
        (65...90).contains(byte) || (97...122).contains(byte)
    }

    private static func isDigit(_ byte: UInt8) -> Bool { (48...57).contains(byte) }

    private static func isVariant(_ part: String) -> Bool {
        let bytes = Array(part.utf8)
        return (5...8).contains(bytes.count) ||
            (bytes.count == 4 && bytes.first.map(isDigit) == true)
    }
}
