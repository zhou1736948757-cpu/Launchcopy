import AppGridUI
import Foundation

enum LaunchActivityLoadResult: Equatable, Sendable {
    case missing, loaded(LaunchActivityDocument), corrupt, oversized, unavailable
    case futureVersion, ambiguousSchema

    var document: LaunchActivityDocument {
        if case .loaded(let value) = self { return value }
        return LaunchActivityDocument()
    }
}

enum LaunchActivitySaveResult: Equatable, Sendable {
    case saved, invalidPreferences, recoveryRequired, protectedPayload, unavailable, failed
}

protocol LaunchActivityPersisting: Sendable {
    func load() async -> LaunchActivityLoadResult
    func save(_ document: LaunchActivityDocument,
              recoveringCorruptPayload: Bool) async -> LaunchActivitySaveResult
}

/// Separate activity envelope/namespace; never changes Library or workspace schemas.
/// The composition owner supplies a URL in its resolved profile's Activity directory.
/// Reuses descriptor-relative, no-follow, bounded-read and compare-under-lock I/O.
actor LaunchActivityFileStore: LaunchActivityPersisting {
    static let maximumPayloadBytes = 1_048_576

    private struct Payload: Codable {
        let schemaVersion: Int
        let document: LaunchActivityDocument
    }
    private let io: any AppLibraryFileIO

    init(fileURL: URL) { io = LocalAppLibraryFileIO(fileURL: fileURL) }
    init(io: any AppLibraryFileIO) { self.io = io }

    func load() -> LaunchActivityLoadResult {
        do {
            guard let bytes = try io.read(maximumBytes: Self.maximumPayloadBytes) else { return .missing }
            return Self.decode(bytes)
        } catch { return .unavailable }
    }

    func save(_ document: LaunchActivityDocument,
              recoveringCorruptPayload: Bool = false) -> LaunchActivitySaveResult {
        guard document.isValid else { return .invalidPreferences }
        let existing: Data?
        do { existing = try io.read(maximumBytes: Self.maximumPayloadBytes) }
        catch { return .unavailable }
        switch existing.map(Self.decode) ?? .missing {
        case .futureVersion, .ambiguousSchema, .oversized: return .protectedPayload
        case .unavailable: return .unavailable
        case .corrupt where !recoveringCorruptPayload: return .recoveryRequired
        default: break
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let bytes = try? encoder.encode(Payload(schemaVersion: 1, document: document)),
              bytes.count <= Self.maximumPayloadBytes else { return .invalidPreferences }
        do {
            try io.replaceAtomically(bytes, expecting: existing)
            return .saved
        } catch { return .failed }
    }

    /// Decoding and loading preserve the exact document without reading the clock.
    /// The owner prunes with its injected clock and tracks any resulting save receipt.
    static func decode(_ data: Data) -> LaunchActivityLoadResult {
        guard data.count <= maximumPayloadBytes else { return .oversized }
        guard let text = String(data: data, encoding: .utf8) else { return .ambiguousSchema }
        guard !JSONLexicalInspection.hasDuplicateObjectKeys(text) else { return .ambiguousSchema }
        let tokens = JSONLexicalInspection.rootVersionTokens(text)
        guard tokens.count == 1, let token = tokens.first else {
            return tokens.isEmpty ? .corrupt : .ambiguousSchema
        }
        if token != "1" {
            if let version = Decimal(string: token, locale: Locale(identifier: "en_US_POSIX")), version > 1 {
                return .futureVersion
            }
            if token.first?.isNumber == true { return .ambiguousSchema }
            return .corrupt
        }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              Set(root.keys) == ["schemaVersion", "document"],
              let document = root["document"] as? [String: Any],
              Set(document.keys) == ["enabled", "salt", "entries"],
              let entries = document["entries"] as? [String: Any],
              entries.count <= 256 else { return .corrupt }
        for value in entries.values {
            guard let entry = value as? [String: Any],
                  Set(entry.keys) == ["lastLaunch", "dailyCounts"],
                  let counts = entry["dailyCounts"] as? [String: Any], counts.count <= 30,
                  // Reject textual aliases such as "01" / "+1" which can collide
                  // after decoding an Int-keyed dictionary despite unique JSON keys.
                  counts.keys.allSatisfy({ key in Int(key).map { String($0) == key } ?? false }) else {
                return .corrupt
            }
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.schemaVersion == 1, payload.document.isValid else { return .corrupt }
        return .loaded(payload.document)
    }
}
