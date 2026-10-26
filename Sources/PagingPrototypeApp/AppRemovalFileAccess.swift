import CryptoKit
import Darwin
import Foundation

struct AppRemovalCandidate: Equatable, Sendable {
    let url: URL
    let identity: AppRemovalFileIdentity
}

/// A path is not an identity. Include the parent binding and birth time as well as
/// the bundle's device/inode to help detect ordinary replacement and inode reuse.
struct AppRemovalFileIdentity: Equatable, Sendable {
    let device: UInt64
    let inode: UInt64
    let owner: UInt32
    let birthSeconds: Int64
    let birthNanoseconds: Int64
    let parentDevice: UInt64
    let parentInode: UInt64
    let bundle: AppRemovalBundleFileIdentity?

    init(device: UInt64, inode: UInt64, owner: UInt32 = 0,
         birthSeconds: Int64 = 0, birthNanoseconds: Int64 = 0,
         parentDevice: UInt64 = 0, parentInode: UInt64 = 0,
         bundle: AppRemovalBundleFileIdentity? = nil) {
        self.device = device
        self.inode = inode
        self.owner = owner
        self.birthSeconds = birthSeconds
        self.birthNanoseconds = birthNanoseconds
        self.parentDevice = parentDevice
        self.parentInode = parentInode
        self.bundle = bundle
    }
}

enum AppRemovalRejection: Equatable, Sendable {
    case unavailable, protectedLocation, wrongProfile, unsafePath
    case notOwned, notWritable, notLocal, changed
}

enum AppRemovalInspection: Equatable, Sendable {
    case eligible(AppRemovalCandidate)
    case rejected(AppRemovalRejection)
}

enum AppRemovalTrashResult: Equatable, Sendable {
    case moved
    case rejected(AppRemovalRejection)
    case failed
}

protocol AppRemovalFileAccess: Sendable {
    func inspect(url: URL, allowedTestRoot: URL?, selfBundleURL: URL) async -> AppRemovalInspection
    func moveToTrash(_ candidate: AppRemovalCandidate, allowedTestRoot: URL?,
                     selfBundleURL: URL) async -> AppRemovalTrashResult
}

/// Metadata-only seams: no bundle loading, directory enumeration, or process queries.
protocol AppRemovalFileProbing: Sendable {
    var currentUserID: UInt32 { get }
    func metadata(at url: URL) throws -> AppRemovalFileMetadata
    func isWritableDirectory(at url: URL) -> Bool
    func volume(at url: URL) throws -> AppRemovalVolumeMetadata
    func bundleMetadata(at url: URL, expectedDirectory: AppRemovalFileMetadata) throws -> AppRemovalBundleFileIdentity
}

struct AppRemovalFileMetadata: Equatable, Sendable {
    let device: UInt64
    let inode: UInt64
    let owner: UInt32
    let birthSeconds: Int64
    let birthNanoseconds: Int64
    let mode: UInt16
    let isDirectory: Bool
    let isSymbolicLink: Bool
    let prohibitsWrites: Bool
}

struct AppRemovalVolumeMetadata: Sendable {
    let isLocal: Bool?
    let isReadOnly: Bool?
}

/// Both stat observations and the bounded content digest participate in candidate
/// equality, including edits that preserve the plist's size or modification time.
struct AppRemovalBundleFileIdentity: Equatable, Sendable {
    let contents: AppRemovalFileMetadata
    let file: AppRemovalFileMetadata
    let byteCount: Int64
    let modifiedSeconds: Int64
    let modifiedNanoseconds: Int64
    let changedSeconds: Int64
    let changedNanoseconds: Int64
    let digest: String
}

enum AppRemovalBundleProbeFailure: Error {
    case unavailable, unsafePath, changed
}

struct FileManagerAppRemovalProbe: AppRemovalFileProbing {
    var currentUserID: UInt32 { getuid() }

    func metadata(at url: URL) throws -> AppRemovalFileMetadata {
        var value = stat()
        // A directory URL may carry a trailing separator. lstat("link/")
        // follows the link, so strip trailing separators before this syscall.
        var filePath = url.path
        while filePath.count > 1, filePath.hasSuffix("/") { filePath.removeLast() }
        let result = filePath.withCString { path -> Int32 in
            return lstat(path, &value)
        }
        guard result == 0 else { throw ProbeFailure.unavailable }
        return Self.metadata(from: value)
    }

    private static func metadata(from value: stat) -> AppRemovalFileMetadata {
        let kind = value.st_mode & mode_t(S_IFMT)
        let writeProhibitions = UInt32(UF_IMMUTABLE | SF_IMMUTABLE | UF_APPEND | SF_APPEND)
        return AppRemovalFileMetadata(
            device: UInt64(bitPattern: Int64(value.st_dev)), inode: UInt64(value.st_ino),
            owner: value.st_uid, birthSeconds: Int64(value.st_birthtimespec.tv_sec),
            birthNanoseconds: Int64(value.st_birthtimespec.tv_nsec),
            mode: UInt16(value.st_mode),
            isDirectory: kind == mode_t(S_IFDIR), isSymbolicLink: kind == mode_t(S_IFLNK),
            prohibitsWrites: value.st_flags & writeProhibitions != 0
        )
    }

    func isWritableDirectory(at url: URL) -> Bool {
        // Search permission is needed in addition to write permission. access()
        // uses the real uid; FileManager also accounts for ordinary ACL policy.
        let accessible = url.withUnsafeFileSystemRepresentation { path -> Bool in
            guard let path else { return false }
            return access(path, W_OK | X_OK) == 0
        }
        return accessible && FileManager().isWritableFile(atPath: url.path)
    }

    func volume(at url: URL) throws -> AppRemovalVolumeMetadata {
        // Reconstruct the URL to avoid retaining cached resource observations.
        let freshURL = URL(fileURLWithPath: url.path, isDirectory: true)
        let values = try freshURL.resourceValues(forKeys: [.volumeIsLocalKey, .volumeIsReadOnlyKey])
        return AppRemovalVolumeMetadata(isLocal: values.volumeIsLocal, isReadOnly: values.volumeIsReadOnly)
    }

    func bundleMetadata(at url: URL, expectedDirectory: AppRemovalFileMetadata) throws -> AppRemovalBundleFileIdentity {
        // Open only the selected bundle and its two fixed metadata components.
        // No Bundle.load, executable loading, enumeration, or Info.plist symlinks.
        var path = url.path
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        let directoryFlags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        let appFD = path.withCString { open($0, directoryFlags) }
        guard appFD >= 0 else { throw Self.openFailure() }
        defer { close(appFD) }
        let appStat = try Self.descriptorStat(appFD)
        guard Self.metadata(from: appStat) == expectedDirectory else { throw AppRemovalBundleProbeFailure.changed }

        let contentsFD = openat(appFD, "Contents", directoryFlags)
        guard contentsFD >= 0 else { throw Self.openFailure() }
        defer { close(contentsFD) }
        let contentsStat = try Self.descriptorStat(contentsFD)

        // O_NONBLOCK ensures even a substituted FIFO cannot block before fstat
        // rejects it. O_NOFOLLOW applies to the actual Info.plist open.
        let fileFD = openat(contentsFD, "Info.plist", O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard fileFD >= 0 else { throw Self.openFailure() }
        defer { close(fileFD) }
        let before = try Self.descriptorStat(fileFD)
        let maximumBytes = 1_048_576
        guard before.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              contentsStat.st_dev == appStat.st_dev, before.st_dev == appStat.st_dev,
              before.st_size > 0, before.st_size <= Int64(maximumBytes) else {
            throw AppRemovalBundleProbeFailure.unsafePath
        }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while data.count <= maximumBytes {
            let remaining = min(buffer.count, maximumBytes + 1 - data.count)
            let count = buffer.withUnsafeMutableBytes { bytes in read(fileFD, bytes.baseAddress, remaining) }
            if count < 0 {
                if errno == EINTR { continue }
                throw AppRemovalBundleProbeFailure.unavailable
            }
            if count == 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
        guard data.count <= maximumBytes else { throw AppRemovalBundleProbeFailure.unsafePath }
        let after = try Self.descriptorStat(fileFD)
        guard Self.sameObservation(before, after), Int64(data.count) == Int64(after.st_size) else {
            throw AppRemovalBundleProbeFailure.changed
        }

        let parsed: Any
        do {
            parsed = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        } catch {
            throw AppRemovalBundleProbeFailure.unsafePath
        }
        guard let dictionary = parsed as? [String: Any],
              dictionary["CFBundlePackageType"] as? String == "APPL",
              let identifier = dictionary["CFBundleIdentifier"] as? String,
              Self.validMarker(identifier), identifier.unicodeScalars.allSatisfy({
                  (65...90).contains($0.value) || (97...122).contains($0.value)
                      || (48...57).contains($0.value) || $0 == "." || $0 == "-"
              }),
              let executable = dictionary["CFBundleExecutable"] as? String,
              Self.validMarker(executable), executable != ".", executable != "..",
              !executable.contains("/"), !executable.contains("\\"), !executable.contains(":") else {
            throw AppRemovalBundleProbeFailure.unsafePath
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        // Verify the names still bind to the opened descriptors after parsing
        // and hashing, without following a replacement link. The actor then
        // rechecks ancestors. This remains a non-atomic path-based operation.
        var namedFile = stat()
        var namedContents = stat()
        guard fstatat(contentsFD, "Info.plist", &namedFile, AT_SYMLINK_NOFOLLOW) == 0,
              fstatat(appFD, "Contents", &namedContents, AT_SYMLINK_NOFOLLOW) == 0,
              Self.sameObservation(after, namedFile), Self.sameObservation(contentsStat, namedContents) else {
            throw AppRemovalBundleProbeFailure.changed
        }
        return AppRemovalBundleFileIdentity(
            contents: Self.metadata(from: contentsStat), file: Self.metadata(from: after),
            byteCount: Int64(after.st_size), modifiedSeconds: Int64(after.st_mtimespec.tv_sec),
            modifiedNanoseconds: Int64(after.st_mtimespec.tv_nsec),
            changedSeconds: Int64(after.st_ctimespec.tv_sec), changedNanoseconds: Int64(after.st_ctimespec.tv_nsec),
            digest: digest
        )
    }

    private static func validMarker(_ string: String) -> Bool {
        !string.isEmpty && string == string.trimmingCharacters(in: .whitespacesAndNewlines)
            && !string.unicodeScalars.contains { $0.value < 32 || $0.value == 127 }
    }

    private static func descriptorStat(_ descriptor: Int32) throws -> stat {
        var value = stat()
        guard fstat(descriptor, &value) == 0 else { throw AppRemovalBundleProbeFailure.unavailable }
        return value
    }

    private static func sameObservation(_ first: stat, _ second: stat) -> Bool {
        metadata(from: first) == metadata(from: second) && first.st_size == second.st_size
            && first.st_mtimespec.tv_sec == second.st_mtimespec.tv_sec
            && first.st_mtimespec.tv_nsec == second.st_mtimespec.tv_nsec
            && first.st_ctimespec.tv_sec == second.st_ctimespec.tv_sec
            && first.st_ctimespec.tv_nsec == second.st_ctimespec.tv_nsec
    }

    private static func openFailure() -> AppRemovalBundleProbeFailure {
        errno == ELOOP || errno == ENOTDIR ? .unsafePath : .unavailable
    }

    private enum ProbeFailure: Error { case unavailable }
}

/// This independent actor owns all filesystem work, including the synchronous
/// platform call. There is no suspension between final inspection and Trash.
/// Catalog/lifecycle/running-app checks and confirmation remain the caller's job.
actor LocalAppRemovalFileAccess: AppRemovalFileAccess {
    private let probe: any AppRemovalFileProbing
    private let trash: @Sendable (URL) throws -> Void

    init() {
        probe = FileManagerAppRemovalProbe()
        trash = { url in
            // The public throwing API's successful receipt is the only success
            // signal. Never fall back to removeItem, a shell command, or a helper.
            try FileManager().trashItem(at: url, resultingItemURL: nil)
        }
    }

    /// Real inspection with an injected receipt; tests never need real Trash.
    init(trash: @escaping @Sendable (URL) throws -> Void) {
        probe = FileManagerAppRemovalProbe()
        self.trash = trash
    }

    /// Explicitly supply both dependencies so synthetic metadata cannot
    /// accidentally be paired with the production destructive operation.
    init(probe: any AppRemovalFileProbing, trash: @escaping @Sendable (URL) throws -> Void) {
        self.probe = probe
        self.trash = trash
    }

    func inspect(url: URL, allowedTestRoot: URL?, selfBundleURL: URL) async -> AppRemovalInspection {
        inspectFile(url: url, allowedTestRoot: allowedTestRoot, selfBundleURL: selfBundleURL)
    }

    func moveToTrash(_ candidate: AppRemovalCandidate, allowedTestRoot: URL?,
                     selfBundleURL: URL) async -> AppRemovalTrashResult {
        switch inspectFile(url: candidate.url, allowedTestRoot: allowedTestRoot, selfBundleURL: selfBundleURL) {
        case .rejected(let reason):
            return .rejected(reason)
        case .eligible(let fresh):
            guard fresh == candidate else { return .rejected(.changed) }
            // No await here: use the freshly inspected single path, once.
            // Path-based FileManager Trash cannot make this atomic against an
            // arbitrary adversarial replacement after revalidation.
            do {
                try trash(fresh.url)
                return .moved
            } catch {
                return .failed
            }
        }
    }

    private func inspectFile(url: URL, allowedTestRoot: URL?, selfBundleURL: URL) -> AppRemovalInspection {
        if url.isFileURL, let host = url.host, !host.isEmpty { return .rejected(.notLocal) }
        guard let target = Self.localDirectoryURL(url),
              target.pathExtension.lowercased() == "app",
              target.deletingPathExtension().lastPathComponent != "" else {
            return .rejected(.unsafePath)
        }

        let profileRoot: URL?
        if let allowedTestRoot {
            guard let root = Self.localDirectoryURL(allowedTestRoot), root.path != "/",
                  Self.contains(target, in: root), target.pathComponents != root.pathComponents else {
                return .rejected(.wrongProfile)
            }
            profileRoot = root
        } else {
            profileRoot = nil
        }

        // Profile containment is lexical and precedes any filesystem access.
        // Profile roots never override protected locations or link rejection.
        guard !Self.isProtected(target) else { return .rejected(.protectedLocation) }
        guard !target.deletingLastPathComponent().pathComponents.contains(where: Self.isAppComponent) else {
            return .rejected(.unsafePath)
        }
        guard let ownBundle = Self.localDirectoryURL(selfBundleURL),
              let canonicalOwnBundle = Self.localDirectoryURL(ownBundle.resolvingSymlinksInPath()) else {
            return .rejected(.unsafePath)
        }
        if [ownBundle, canonicalOwnBundle].contains(where: {
            Self.contains($0, in: target, ignoringCase: true)
                || Self.contains(target, in: $0, ignoringCase: true)
        }) {
            return .rejected(.protectedLocation)
        }

        do {
            var observations: [(url: URL, metadata: AppRemovalFileMetadata)] = []
            var prefix = URL(fileURLWithPath: "/", isDirectory: true)
            let components = target.pathComponents
            for index in components.indices {
                if index > 0 { prefix.appendPathComponent(components[index], isDirectory: true) }
                // lstat every component before descending; never resolve a
                // candidate symlink and then inspect its potentially external target.
                let metadata = try probe.metadata(at: prefix)
                guard !metadata.isSymbolicLink, metadata.isDirectory else {
                    let invalidProfile = profileRoot.map { Self.contains($0, in: prefix) } ?? false
                    return .rejected(invalidProfile ? .wrongProfile : .unsafePath)
                }
                if let profileRoot, prefix.pathComponents == profileRoot.pathComponents,
                   metadata.owner != probe.currentUserID {
                    return .rejected(.wrongProfile)
                }
                observations.append((prefix, metadata))
            }
            guard observations.count >= 2, let item = observations.last else { return .rejected(.unsafePath) }
            let parent = observations[observations.count - 2]
            guard item.metadata.owner == probe.currentUserID else { return .rejected(.notOwned) }
            // A bundle that is itself a mount point is not an ordinary directory
            // entry that can be moved to the parent's Trash.
            guard item.metadata.device == parent.metadata.device else { return .rejected(.unsafePath) }
            for entry in [item, parent] {
                let volume = try probe.volume(at: entry.url)
                guard let local = volume.isLocal, let readOnly = volume.isReadOnly else {
                    return .rejected(.unavailable)
                }
                guard local else { return .rejected(.notLocal) }
                guard !readOnly, !entry.metadata.prohibitsWrites,
                      probe.isWritableDirectory(at: entry.url) else { return .rejected(.notWritable) }
            }
            let bundleIdentity = try probe.bundleMetadata(at: target, expectedDirectory: item.metadata)
            // Detect changes during observation too, including substituted
            // ancestors/parents. These are fresh lstat calls, not URL cache reads.
            for entry in observations {
                guard try probe.metadata(at: entry.url) == entry.metadata else { return .rejected(.changed) }
            }
            return .eligible(AppRemovalCandidate(url: target, identity: AppRemovalFileIdentity(
                device: item.metadata.device, inode: item.metadata.inode, owner: item.metadata.owner,
                birthSeconds: item.metadata.birthSeconds, birthNanoseconds: item.metadata.birthNanoseconds,
                parentDevice: parent.metadata.device, parentInode: parent.metadata.inode, bundle: bundleIdentity
            )))
        } catch AppRemovalBundleProbeFailure.unsafePath {
            return .rejected(.unsafePath)
        } catch AppRemovalBundleProbeFailure.changed {
            return .rejected(.changed)
        } catch {
            return .rejected(.unavailable)
        }
    }

    /// Deliberately avoid standardizedFileURL: collapsing traversal or resolving
    /// aliases before link checks would change the path the user confirmed.
    private static func localDirectoryURL(_ url: URL) -> URL? {
        guard url.isFileURL, url.host == nil || url.host == "", url.query == nil, url.fragment == nil,
              url.user == nil, url.password == nil, url.port == nil,
              url.path.hasPrefix("/"),
              !url.path.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }),
              !url.pathComponents.contains(where: { component in
                  component.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 })
              }),
              !url.pathComponents.contains("."), !url.pathComponents.contains("..") else { return nil }
        return URL(fileURLWithPath: url.path, isDirectory: true)
    }

    private static func isAppComponent(_ component: String) -> Bool {
        component.lowercased().hasSuffix(".app")
    }

    private static func contains(_ candidate: URL, in root: URL, ignoringCase: Bool = false) -> Bool {
        let candidateParts = candidate.pathComponents.map { ignoringCase ? $0.lowercased() : $0 }
        let rootParts = root.pathComponents.map { ignoringCase ? $0.lowercased() : $0 }
        return candidateParts.starts(with: rootParts)
    }

    private static func isProtected(_ url: URL) -> Bool {
        let parts = url.pathComponents.map { $0.lowercased() }
        let protectedRoots: Set<String> = [
            "system", "library", "usr", "bin", "sbin", "private", "etc", "var", "tmp",
            "dev", "cores", "network", "net", "automount", ".vol"
        ]
        return parts.count < 2 || protectedRoots.contains(parts[1])
            || parts.contains(".trash") || parts.contains(".trashes")
    }
}
