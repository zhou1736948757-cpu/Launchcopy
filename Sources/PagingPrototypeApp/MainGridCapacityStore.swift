import AppGridUI
import Foundation

enum MainGridCapacityLoadResult: Equatable, Sendable {
    case missing, loaded(MainGridCapacity), corrupt, protectedPayload, unavailable

    var capacity: MainGridCapacity {
        if case .loaded(let capacity) = self { return capacity }
        return .default
    }
}

enum MainGridCapacitySaveResult: Equatable, Sendable {
    case saved, invalid, protectedPayload, recoveryRequired, failed
}

protocol MainGridCapacityPersisting: Sendable {
    func load() async -> MainGridCapacityLoadResult
    func save(_ capacity: MainGridCapacity, recoveringCorruptPayload: Bool) async -> MainGridCapacitySaveResult
}

/// Dedicated directory/file; reuses the established pinned-directory, no-follow,
/// expected-byte atomic replacement primitive without sharing preference state.
/// The primitive's .library.lock belongs only to this injected capacity directory.
/// Cooperative contention or an observed baseline change refuses the write.
/// Arbitrary writers ignoring that lock are not atomic transaction participants.
actor FileMainGridCapacityStore: MainGridCapacityPersisting {
    static let maximumPayloadBytes = 8 * 1024
    static let fileName = "capacity.json"

    private struct Envelope: Codable {
        let schemaVersion: Int
        let capacity: MainGridCapacity
    }

    private let io: any AppLibraryFileIO

    /// Does not create or inspect storage. Pass the dedicated capacity directory.
    init(directory: URL) {
        io = LocalAppLibraryFileIO(fileURL: directory.appendingPathComponent(Self.fileName))
    }

    init(io: any AppLibraryFileIO) { self.io = io }

    func load() -> MainGridCapacityLoadResult {
        do {
            guard let bytes = try io.read(maximumBytes: Self.maximumPayloadBytes) else { return .missing }
            return Self.decode(bytes)
        } catch { return .unavailable }
    }

    func save(_ capacity: MainGridCapacity,
              recoveringCorruptPayload: Bool = false) -> MainGridCapacitySaveResult {
        guard MainGridCapacity(columns: capacity.columns, rows: capacity.rows) == capacity else { return .invalid }
        let baseline: Data?
        do { baseline = try io.read(maximumBytes: Self.maximumPayloadBytes) }
        catch { return .failed }
        switch baseline.map(Self.decode) ?? .missing {
        case .protectedPayload: return .protectedPayload
        case .unavailable: return .failed
        case .corrupt where !recoveringCorruptPayload: return .recoveryRequired
        default: break
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let bytes = try? encoder.encode(Envelope(schemaVersion: 1, capacity: capacity)),
              bytes.count <= Self.maximumPayloadBytes else { return .invalid }
        do {
            // Always perform the replacement/flush, including equal-value retries
            // after a potentially indeterminate post-rename failure.
            try io.replaceAtomically(bytes, expecting: baseline)
            return .saved
        } catch { return .failed }
    }

    static func decode(_ data: Data) -> MainGridCapacityLoadResult {
        guard data.count <= maximumPayloadBytes,
              let text = String(data: data, encoding: .utf8) else { return .protectedPayload }
        let inspection = EnvelopeInspection(text)
        guard !inspection.duplicateKeys, !inspection.unknownKeys else { return .protectedPayload }
        // Inspect raw headers before Foundation's typed decoder, even when the
        // body is truncated. Overflow, fractional/quoted/duplicate/unknown schema
        // declarations must never become a repairable supported-v1 payload.
        guard inspection.versionTokens.count <= 1 else { return .protectedPayload }
        guard let token = inspection.versionTokens.first else { return .corrupt }
        guard token == "1" else { return .protectedPayload }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return .corrupt }
        guard Set(root.keys).isSubset(of: ["schemaVersion", "capacity"]) else { return .protectedPayload }
        if let body = root["capacity"] as? [String: Any],
           !Set(body.keys).isSubset(of: ["columns", "rows"]) { return .protectedPayload }
        guard Set(root.keys) == ["schemaVersion", "capacity"],
              let body = root["capacity"] as? [String: Any],
              Set(body.keys) == ["columns", "rows"],
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.schemaVersion == 1 else { return .corrupt }
        return .loaded(envelope.capacity)
    }

    /// Bounded lexical inspection, intentionally independent of body decoding.
    /// Decodes object-key string escapes so equivalent duplicate keys cannot be
    /// resolved differently by the two Foundation JSON readers. It is not a JSON
    /// validity parser: only a successful strict v1 decode admits loaded state.
    private struct EnvelopeInspection {
        private enum ObjectKind: Equatable { case root, capacity, other }
        private struct Frame {
            let kind: ObjectKind
            let isObject: Bool
            var keys: Set<String> = []
            var pendingKey: String?
        }
        var versionTokens: [String] = []
        var duplicateKeys = false
        var unknownKeys = false

        init(_ text: String) {
            let bytes = Array(text.utf8)
            var index = 0
            var frames: [Frame] = []
            func whitespace(_ byte: UInt8) -> Bool { byte == 9 || byte == 10 || byte == 13 || byte == 32 }
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
                    guard index < bytes.count else { return }
                    let literal = Data(bytes[start...index])
                    index += 1
                    var cursor = index
                    while cursor < bytes.count, whitespace(bytes[cursor]) { cursor += 1 }
                    guard cursor < bytes.count, bytes[cursor] == 58,
                          let last = frames.indices.last, frames[last].isObject,
                          let key = try? JSONDecoder().decode(String.self, from: literal) else { continue }
                    if !frames[last].keys.insert(key).inserted { duplicateKeys = true }
                    frames[last].pendingKey = key
                    switch frames[last].kind {
                    case .root:
                        if key != "schemaVersion" && key != "capacity" { unknownKeys = true }
                    case .capacity:
                        if key != "columns" && key != "rows" { unknownKeys = true }
                    case .other: unknownKeys = true
                    }
                    if frames[last].kind == .root, key == "schemaVersion" {
                        cursor += 1
                        while cursor < bytes.count, whitespace(bytes[cursor]) { cursor += 1 }
                        let valueStart = cursor
                        while cursor < bytes.count, !whitespace(bytes[cursor]),
                              bytes[cursor] != 44, bytes[cursor] != 125, bytes[cursor] != 93 { cursor += 1 }
                        versionTokens.append(String(decoding: bytes[valueStart..<cursor], as: UTF8.self))
                    }
                } else if byte == 123 || byte == 91 {
                    let kind: ObjectKind
                    if frames.isEmpty, byte == 123 { kind = .root }
                    else if let parent = frames.last, parent.isObject,
                            parent.kind == .root, parent.pendingKey == "capacity", byte == 123 { kind = .capacity }
                    else { kind = .other }
                    frames.append(Frame(kind: kind, isObject: byte == 123))
                    index += 1
                } else if byte == 125 || byte == 93 {
                    if !frames.isEmpty { frames.removeLast() }
                    index += 1
                } else { index += 1 }
            }
        }
    }
}
