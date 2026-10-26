import AppGridUI
import Darwin
import Foundation

/// Neutral states only; preferences remain private, local application data.
enum AppLibraryLoadResult: Equatable, Sendable {
    case missing, loaded(AppLibraryPreferences), corrupt, oversized, unavailable
    case futureVersion, ambiguousSchema

    var preferences: AppLibraryPreferences {
        if case .loaded(let value) = self { return value }
        return .default
    }
}

enum AppLibrarySaveResult: Equatable, Sendable {
    case saved, invalidPreferences, recoveryRequired, protectedPayload, unavailable, failed
}

protocol AppLibraryPersisting: Sendable {
    func load() async -> AppLibraryLoadResult
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) async -> AppLibrarySaveResult
}

/// Synchronous I/O is confined to the store actor, never AppKit or frame callbacks.
protocol AppLibraryFileIO: Sendable {
    func read(maximumBytes: Int) throws -> Data?
    func replaceAtomically(_ data: Data, expecting expected: Data?) throws
}

enum AppLibraryFileError: Error { case unavailable }

/// Cooperative writers use one advisory lock; all path operations below are
/// relative to pinned no-follow directory descriptors. Uncooperative external
/// writers are not transaction participants; no unconditional race-proof claim.
struct LocalAppLibraryFileIO: AppLibraryFileIO {
    let fileURL: URL
    /// Nil in production; deterministic target/namespace-swap regression seam.
    var beforeReplacement: (@Sendable () throws -> Void)? = nil

    func read(maximumBytes: Int) throws -> Data? {
        guard let directory = try openDirectory(create: false) else { return nil }
        defer { Darwin.close(directory) }
        return try read(at: directory, maximumBytes: maximumBytes)
    }

    func replaceAtomically(_ data: Data, expecting expected: Data?) throws {
        guard let directory = try openDirectory(create: true) else { throw AppLibraryFileError.unavailable }
        defer { Darwin.close(directory) }
        let lock = Darwin.openat(directory, ".library.lock", O_CREAT | O_RDWR | O_NONBLOCK | O_NOFOLLOW, 0o600)
        guard lock >= 0 else { throw AppLibraryFileError.unavailable }
        defer { Darwin.close(lock) }
        var lockInfo = stat()
        guard fstat(lock, &lockInfo) == 0, lockInfo.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              flock(lock, LOCK_EX | LOCK_NB) == 0 else { throw AppLibraryFileError.unavailable }
        defer { _ = flock(lock, LOCK_UN) }
        // Compare under the shared lock: another participating writer may have
        // changed the target after this actor inspected it but before admission.
        guard try read(at: directory, maximumBytes: AppLibraryFileStore.maximumPayloadBytes) == expected else {
            throw AppLibraryFileError.unavailable
        }
        let temporary = ".library-write-" + UUID().uuidString
        let fd = Darwin.openat(directory, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw AppLibraryFileError.unavailable }
        defer { Darwin.close(fd); _ = Darwin.unlinkat(directory, temporary, 0) }
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let written = Darwin.write(fd, buffer.baseAddress?.advanced(by: offset), buffer.count - offset)
                if written < 0, errno == EINTR { continue }
                guard written > 0 else { throw AppLibraryFileError.unavailable }
                offset += written
            }
        }
        guard Darwin.fsync(fd) == 0 else { throw AppLibraryFileError.unavailable }
        try beforeReplacement?()
        guard let currentDirectory = try openDirectory(create: false) else { throw AppLibraryFileError.unavailable }
        defer { Darwin.close(currentDirectory) }
        var originalInfo = stat(), currentInfo = stat()
        guard fstat(directory, &originalInfo) == 0, fstat(currentDirectory, &currentInfo) == 0,
              originalInfo.st_dev == currentInfo.st_dev, originalInfo.st_ino == currentInfo.st_ino else {
            throw AppLibraryFileError.unavailable
        }
        // Detect non-participating changes observed before replacement, too.
        // Atomic CAS against arbitrary writers is not provided by renameat.
        guard try read(at: directory, maximumBytes: AppLibraryFileStore.maximumPayloadBytes) == expected,
              Darwin.renameat(directory, temporary, directory, fileURL.lastPathComponent) == 0,
              Darwin.fsync(directory) == 0 else { throw AppLibraryFileError.unavailable }
    }

    private func read(at directory: Int32, maximumBytes: Int) throws -> Data? {
        let fd = Darwin.openat(directory, fileURL.lastPathComponent, O_RDONLY | O_NONBLOCK | O_NOFOLLOW)
        guard fd >= 0 else {
            if errno == ENOENT { return nil }
            throw AppLibraryFileError.unavailable
        }
        defer { Darwin.close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
            throw AppLibraryFileError.unavailable
        }
        var bytes = [UInt8](repeating: 0, count: maximumBytes + 1)
        var count = 0
        while count < bytes.count {
            let received = bytes.withUnsafeMutableBytes { buffer in
                Darwin.read(fd, buffer.baseAddress?.advanced(by: count), buffer.count - count)
            }
            if received < 0 {
                if errno == EINTR { continue }
                throw AppLibraryFileError.unavailable
            }
            if received == 0 { break }
            count += received
        }
        return Data(bytes.prefix(count))
    }

    /// Directory-free missing-load inspection; mkdirat occurs only on an edit.
    /// No symbolic ancestor is followed between checking and opening the target.
    private func openDirectory(create: Bool) throws -> Int32? {
        guard fileURL.isFileURL, fileURL.host == nil || fileURL.host == "" || fileURL.host == "localhost",
              fileURL.path.hasPrefix("/"), !fileURL.lastPathComponent.isEmpty,
              !fileURL.pathComponents.contains("."), !fileURL.pathComponents.contains("..") else {
            throw AppLibraryFileError.unavailable
        }
        var current = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard current >= 0 else { throw AppLibraryFileError.unavailable }
        var handedOff = false
        defer { if !handedOff { Darwin.close(current) } }
        for component in fileURL.deletingLastPathComponent().pathComponents.dropFirst() {
            var next = Darwin.openat(current, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
            if next < 0, errno == ENOENT {
                guard create else { return nil }
                guard Darwin.mkdirat(current, component, 0o700) == 0 || errno == EEXIST else {
                    throw AppLibraryFileError.unavailable
                }
                next = Darwin.openat(current, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
            }
            guard next >= 0 else { throw AppLibraryFileError.unavailable }
            Darwin.close(current)
            current = next
        }
        handedOff = true
        return current
    }
}

/// One non-reentrant serial writer; optional metadata never enters the workspace file.
actor AppLibraryFileStore: AppLibraryPersisting {
    static let maximumPayloadBytes = 1_048_576
    private struct Payload: Codable {
        let schemaVersion: Int
        let preferences: AppLibraryPreferences
    }
    private let io: any AppLibraryFileIO

    init(fileURL: URL) { io = LocalAppLibraryFileIO(fileURL: fileURL) }
    init(io: any AppLibraryFileIO) { self.io = io }

    func load() -> AppLibraryLoadResult {
        do {
            guard let bytes = try io.read(maximumBytes: Self.maximumPayloadBytes) else { return .missing }
            return Self.decode(bytes)
        } catch { return .unavailable }
    }

    func save(_ preferences: AppLibraryPreferences,
              recoveringCorruptPayload: Bool = false) -> AppLibrarySaveResult {
        guard preferences.isValid else { return .invalidPreferences }
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
        guard let data = try? encoder.encode(Payload(schemaVersion: 1, preferences: preferences)),
              data.count <= Self.maximumPayloadBytes else { return .invalidPreferences }
        do { try io.replaceAtomically(data, expecting: existing); return .saved }
        catch { return .failed }
    }

    static func decode(_ data: Data) -> AppLibraryLoadResult {
        guard data.count <= maximumPayloadBytes else { return .oversized }
        // A single v1 header is the only writable schema. Duplicate or
        // unrepresentable headers are conservatively read-only, not repairable.
        // This protects future bytes even where Foundation decoders disagree.
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
            // Long numeric literals remain protected when Decimal cannot represent them.
            if token.first?.isNumber == true { return .ambiguousSchema }
            return .corrupt
        }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              Set(root.keys) == ["schemaVersion", "preferences"],
              let preferences = root["preferences"] as? [String: Any],
              Set(preferences.keys) == ["enabled", "categoryOverrides"],
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.schemaVersion == 1, payload.preferences.isValid else { return .corrupt }
        return .loaded(payload.preferences)
    }

}
