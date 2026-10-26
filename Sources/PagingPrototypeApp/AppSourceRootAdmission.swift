import Foundation

/// Assembly supplies the home and fixed boundaries; constructing this value performs no IO.
/// The isolated profile boundary must already be canonical, as established by UITestProfile.
public struct AppSourceRootAdmissionContext: Sendable {
    public let homeURL: URL
    public let fixedRoots: [URL]
    public let allowedSyntheticRoot: URL?
    public let requiresExactCanonicalPath: Bool

    public init(homeURL: URL, fixedRoots: [URL], allowedSyntheticRoot: URL? = nil,
                requiresExactCanonicalPath: Bool = false) {
        self.homeURL = homeURL
        self.fixedRoots = fixedRoots
        self.allowedSyntheticRoot = allowedSyntheticRoot
        self.requiresExactCanonicalPath = requiresExactCanonicalPath
    }
}

/// Neutral outcomes only: no paths, underlying errors, or permission prompts.
public enum AppSourceRootRejection: Equatable, Sendable {
    case invalidURL
    case tooBroad
    case outsideSyntheticRoot
    case missing
    case notDirectory
    case applicationBundle
    case unreadable
    case nonLocalVolume
    case unknownLocality
    case metadataUnavailable
    case changedCanonicalPath
}

public enum AppSourceRootAdmissionResult: Equatable, Sendable {
    case accepted(URL)
    case alreadyCovered
    case rejected(AppSourceRootRejection)
}

public protocol AppSourceRootAdmitting: Sendable {
    func admit(_ candidate: URL, context: AppSourceRootAdmissionContext) async -> AppSourceRootAdmissionResult
}

/// Synchronous probe methods are called exclusively from the admitter actor.
/// Keeping canonicalization separate prevents metadata reads after a symlink escapes a profile.
internal protocol AppSourceRootFileSystemProbing: Sendable {
    func canonicalURL(for url: URL) throws -> URL
    func metadata(at url: URL) throws -> AppSourceRootMetadata
}

internal struct AppSourceRootMetadata: Sendable {
    let isDirectory: Bool?
    let isReadable: Bool
    let volumeIsLocal: Bool?
    let isVolume: Bool?
    let volumeURL: URL?
}

internal enum AppSourceRootProbeFailure: Error, Sendable {
    case missing
    case unreadable
    case unavailable
}

/// Public FileManager/URL resource APIs only. No enumeration or home-directory lookup.
internal struct FileManagerAppSourceRootProbe: AppSourceRootFileSystemProbing {
    func canonicalURL(for url: URL) throws -> URL {
        url.resolvingSymlinksInPath()
    }

    func metadata(at url: URL) throws -> AppSourceRootMetadata {
        do {
            let fileManager = FileManager()
            let values = try url.resourceValues(forKeys: [
                .isDirectoryKey, .isReadableKey, .volumeIsLocalKey, .isVolumeKey, .volumeURLKey
            ])
            // Directory readability also requires search permission to discover its contents.
            let readable = values.isReadable != false
                && fileManager.isReadableFile(atPath: url.path)
                && fileManager.isExecutableFile(atPath: url.path)
            return AppSourceRootMetadata(
                isDirectory: values.isDirectory,
                isReadable: readable,
                volumeIsLocal: values.volumeIsLocal,
                isVolume: values.isVolume,
                volumeURL: values.volume
            )
        } catch {
            let error = error as NSError
            if error.domain == NSCocoaErrorDomain {
                if error.code == CocoaError.fileNoSuchFile.rawValue
                    || error.code == CocoaError.fileReadNoSuchFile.rawValue {
                    throw AppSourceRootProbeFailure.missing
                }
                if error.code == CocoaError.fileReadNoPermission.rawValue {
                    throw AppSourceRootProbeFailure.unreadable
                }
            }
            throw AppSourceRootProbeFailure.unavailable
        }
    }
}

/// All canonicalization and metadata IO executes on this actor, never on the caller's MainActor.
/// Admission is a pre-scan gate; only the returned canonical URL may be persisted or scanned.
public actor LocalAppSourceRootAdmitter: AppSourceRootAdmitting {
    private let probe: any AppSourceRootFileSystemProbing

    public init() {
        probe = FileManagerAppSourceRootProbe()
    }

    internal init(probe: any AppSourceRootFileSystemProbing) {
        self.probe = probe
    }

    public func admit(_ candidate: URL, context: AppSourceRootAdmissionContext) async -> AppSourceRootAdmissionResult {
        guard let lexical = Self.localAbsoluteURL(candidate),
              let home = Self.localAbsoluteURL(context.homeURL) else {
            return .rejected(.invalidURL)
        }
        let synthetic: URL?
        if let boundary = context.allowedSyntheticRoot {
            guard let normalized = Self.localAbsoluteURL(boundary), normalized.path != "/" else {
                return .rejected(.outsideSyntheticRoot)
            }
            synthetic = normalized
        } else {
            synthetic = nil
        }

        // In a profile, even canonicalization of an external selection is forbidden.
        if let rejection = Self.boundaryRejection(lexical, home: home, synthetic: synthetic) {
            return .rejected(rejection)
        }
        do {
            // Resolve the original path: collapsing '..' first can change symlink traversal.
            guard let canonical = Self.localAbsoluteURL(try probe.canonicalURL(for: candidate)) else {
                return .rejected(.invalidURL)
            }
            if let rejection = Self.boundaryRejection(canonical, home: home, synthetic: synthetic) {
                return .rejected(rejection)
            }

            if context.requiresExactCanonicalPath, canonical.pathComponents != lexical.pathComponents {
                return .rejected(.changedCanonicalPath)
            }

            // Trusted fixed inputs stay unchanged, even when temporarily unavailable.
            // No IO is performed on context roots (especially production roots in a profile).
            if context.fixedRoots.contains(where: { fixed in
                guard let root = Self.localAbsoluteURL(fixed), root.path != "/" else { return false }
                return Self.contains(canonical, in: root)
            }) {
                return .alreadyCovered
            }

            let metadata = try probe.metadata(at: canonical)
            guard let isDirectory = metadata.isDirectory else { return .rejected(.metadataUnavailable) }
            guard isDirectory else { return .rejected(.notDirectory) }
            guard metadata.isReadable else { return .rejected(.unreadable) }
            guard let local = metadata.volumeIsLocal else { return .rejected(.unknownLocality) }
            guard local else { return .rejected(.nonLocalVolume) }
            guard let isVolume = metadata.isVolume,
                  let volume = metadata.volumeURL.flatMap(Self.localAbsoluteURL) else {
                return .rejected(.metadataUnavailable)
            }
            guard !isVolume, canonical.pathComponents != volume.pathComponents else {
                return .rejected(.tooBroad)
            }
            return .accepted(canonical)
        } catch AppSourceRootProbeFailure.missing {
            return .rejected(.missing)
        } catch AppSourceRootProbeFailure.unreadable {
            return .rejected(.unreadable)
        } catch {
            return .rejected(.metadataUnavailable)
        }
    }

    private static func boundaryRejection(_ candidate: URL, home: URL, synthetic: URL?) -> AppSourceRootRejection? {
        if let synthetic, !contains(candidate, in: synthetic) {
            return .outsideSyntheticRoot
        }
        // A bundle or one of its descendants is not an application source.
        // Scanning it as a root would expose embedded helpers despite bundle-stop policy.
        if candidate.pathComponents.contains(where: { $0.lowercased().hasSuffix(".app") }) {
            return .applicationBundle
        }
        // Reject the home itself and every ancestor, not ordinary Applications descendants.
        // Conservatively reject case aliases of broad boundaries as well: typical
        // macOS volumes are case-insensitive, but Foundation may preserve input case.
        let candidateComponents = candidate.pathComponents.map { $0.lowercased() }
        let homeComponents = home.pathComponents.map { $0.lowercased() }
        let isHomeOrAncestor = homeComponents.count >= candidateComponents.count
            && homeComponents.starts(with: candidateComponents)
        let broadPath = candidate.path.lowercased()
        if isHomeOrAncestor
            || broadPath == "/"
            || broadPath == "/volumes"
            || broadPath == "/system/volumes" {
            return .tooBroad
        }
        return nil
    }

    private static func contains(_ child: URL, in root: URL) -> Bool {
        let childComponents = child.pathComponents
        let rootComponents = root.pathComponents
        return childComponents.count >= rootComponents.count
            && childComponents.starts(with: rootComponents)
    }

    /// Pure lexical normalization: standardizedFileURL can perform filesystem resolution.
    /// File URLs with a base, credentials, query, or fragment are not folder selections.
    private static func localAbsoluteURL(_ url: URL) -> URL? {
        guard url.baseURL == nil, url.isFileURL,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.host == nil || parts.host == "" || parts.host?.lowercased() == "localhost",
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.query == nil, parts.fragment == nil,
              parts.path.hasPrefix("/"),
              !parts.path.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) else {
            return nil
        }
        var components: [Substring] = []
        for component in parts.path.split(separator: "/", omittingEmptySubsequences: true) {
            if component == "." { continue }
            if component == ".." {
                if !components.isEmpty { components.removeLast() }
            } else {
                components.append(component)
            }
        }
        return URL(fileURLWithPath: "/" + components.joined(separator: "/"), isDirectory: true)
    }
}

/// One shared off-Main admission path for both scanning and native watch setup.
/// Ordinary system baselines retain their established trust contract; mutable
/// isolated roots never inherit that shortcut after startup.
public enum AppSourceRootSetResolver {
    public struct Result: Equatable, Sendable {
        public let roots: [URL]
        public let excludedReferenceCount: Int
    }

    public static func resolve(fixedRoots: [URL], customRoots: [URL],
                               context: AppSourceRootAdmissionContext,
                               admission: any AppSourceRootAdmitting) async -> Result {
        var roots: [URL] = [], excluded = 0
        if context.allowedSyntheticRoot != nil {
            let exact = AppSourceRootAdmissionContext(homeURL: context.homeURL, fixedRoots: context.fixedRoots,
                allowedSyntheticRoot: context.allowedSyntheticRoot, requiresExactCanonicalPath: true)
            for root in fixedRoots {
                if Task.isCancelled { break }
                let result = await admission.admit(root, context: exact)
                if result == .alreadyCovered { roots.append(root) }
                else if case .accepted(let canonical) = result, canonical.path == root.path { roots.append(root) }
                else { excluded += 1 }
            }
        } else { roots = fixedRoots }
        for root in customRoots {
            if Task.isCancelled { break }
            if case .accepted(let canonical) = await admission.admit(root, context: context),
               canonical.path == root.path { roots.append(canonical) }
            else { excluded += 1 }
        }
        return Result(roots: roots, excludedReferenceCount: excluded)
    }
}
