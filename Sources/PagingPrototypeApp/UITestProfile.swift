import CryptoKit
import Foundation

/// Candidate-local UI test storage, resolved without creating files or opening preferences.
/// A candidate is the canonical directory containing the packaged app, as used by
/// Scripts/package-app.sh (.build/candidates/<candidate>/Launchcopy.app).
public struct UITestProfile: Equatable, Sendable {
    public let id: String
    public let bundleURL: URL
    public let rootURL: URL
    public let layoutDirectoryURL: URL
    public let applicationsDirectoryURL: URL
    public let wallpaperCacheDirectoryURL: URL
    public let libraryDirectoryURL: URL
    public let activationSuiteName: String
    public let appearanceSuiteName: String
    public let managementSuiteName: String
    public let languageSuiteName: String
    public let sourcesSuiteName: String
    public let librarySuiteName: String

    /// Errors deliberately contain no input path, bundle name, or profile identifier.
    public enum ResolutionError: Error, Equatable, Sendable {
        case invalidID
        case invalidBundleURL
        case notAppDirectory
        case outsideCandidateDirectory
        case unsafeProfileDirectory
    }

    private init(id: String, bundleURL: URL, rootURL: URL, namespace: String) {
        self.id = id
        self.bundleURL = bundleURL
        self.rootURL = rootURL
        layoutDirectoryURL = rootURL.appendingPathComponent("Layout", isDirectory: true)
        applicationsDirectoryURL = rootURL.appendingPathComponent("Applications", isDirectory: true)
        wallpaperCacheDirectoryURL = rootURL.appendingPathComponent("WallpaperCache", isDirectory: true)
        libraryDirectoryURL = rootURL.appendingPathComponent("Library", isDirectory: true)
        activationSuiteName = namespace + ".activation"
        appearanceSuiteName = namespace + ".appearance"
        managementSuiteName = namespace + ".management"
        sourcesSuiteName = namespace + ".sources"
        languageSuiteName = namespace + ".language"
        librarySuiteName = namespace + ".library"
    }

    /// Exactly [a-z0-9][a-z0-9-]{0,47}. Never trim, case-fold, or normalize invalid input.
    public static func isValidID(_ id: String) -> Bool {
        let bytes = id.utf8
        guard (1...48).contains(bytes.count), let first = bytes.first,
              isLowercaseLetterOrDigit(first) else { return false }
        return bytes.dropFirst().allSatisfy { isLowercaseLetterOrDigit($0) || $0 == 45 }
    }

    /// Requires an existing .app directory inside a canonical .build/candidates tree.
    /// The bundle's containing candidate directory owns UITestProfiles/<id>.
    /// Candidate aliases resolve to the same identity; symlinks escaping the tree reject.
    /// Existing output directories must resolve to their exact candidate-local locations.
    /// The caller creates directories only after successful resolution and must reject
    /// startup on failure, never substituting production storage or preference suites.
    public static func resolve(bundleURL: URL, profileID: String) throws -> UITestProfile {
        guard isValidID(profileID) else { throw ResolutionError.invalidID }
        guard bundleURL.isFileURL,
              bundleURL.host == nil || bundleURL.host == "" || bundleURL.host == "localhost" else {
            throw ResolutionError.invalidBundleURL
        }

        let canonicalBundle = canonicalURL(bundleURL)
        var isDirectory: ObjCBool = false
        guard canonicalBundle.pathExtension == "app",
              FileManager.default.fileExists(atPath: canonicalBundle.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw ResolutionError.notAppDirectory
        }

        let candidateDirectory = canonicalBundle.deletingLastPathComponent()
        let components = candidateDirectory.pathComponents
        // Exact adjacent components avoid prefix tricks such as candidates-other.
        // Require a candidate subdirectory so two artifacts cannot share a global test root.
        let isCandidate = components.indices.contains { index in
            components[index] == ".build" && index + 2 < components.count
                && components[index + 1] == "candidates"
        }
        guard isCandidate else { throw ResolutionError.outsideCandidateDirectory }

        let profilesDirectory = candidateDirectory.appendingPathComponent("UITestProfiles", isDirectory: true)
        let root = profilesDirectory.appendingPathComponent(profileID, isDirectory: true)
        for directory in [profilesDirectory, root,
                          root.appendingPathComponent("Layout", isDirectory: true),
                          root.appendingPathComponent("Applications", isDirectory: true),
                          root.appendingPathComponent("WallpaperCache", isDirectory: true),
                          root.appendingPathComponent("Library", isDirectory: true),
                          root.appendingPathComponent("LaunchActivity", isDirectory: true)] {
            try validateOutputDirectory(directory)
        }

        // Length-framed fields prevent ambiguous concatenation. Hash the candidate
        // directory (the storage owner), not a process ID or a randomized Swift hash.
        // Sibling bundles in the same artifact directory intentionally share its profile.
        let fields = ["launchcopy-ui-test-profile-v1", candidateDirectory.path, profileID]
        let identity = fields.map { "\($0.utf8.count):\($0)" }.joined()
        let digest = SHA256.hash(data: Data(identity.utf8))
        let hex = digest.map { String(format: "%02x", Int($0)) }.joined()
        let namespace = "com.launchcopy.ui-test.v1." + hex
        return UITestProfile(id: profileID, bundleURL: canonicalBundle, rootURL: root, namespace: namespace)
    }

    private static func isLowercaseLetterOrDigit(_ byte: UInt8) -> Bool {
        (97...122).contains(byte) || (48...57).contains(byte)
    }

    private static func canonicalURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath().standardizedFileURL
    }

    private static func validateOutputDirectory(_ directory: URL) throws {
        guard canonicalURL(directory).pathComponents == directory.pathComponents else {
            throw ResolutionError.unsafeProfileDirectory
        }
        // Reject symlink entries even when dangling or targeting the same lexical path.
        // This also keeps the create-after-resolve contract free of hidden aliases.
        guard (try? FileManager.default.destinationOfSymbolicLink(atPath: directory.path)) == nil else {
            throw ResolutionError.unsafeProfileDirectory
        }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
           !isDirectory.boolValue {
            throw ResolutionError.unsafeProfileDirectory
        }
    }
}
