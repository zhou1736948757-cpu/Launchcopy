import CoreFoundation
import Foundation

/// Opt-in bundle data selects the existing isolated mode, never arbitrary commands.
/// Resolves before AppKit, application stores or global services are constructed.
enum NativeUITestEntry {
    static let metadataKey = "LaunchcopyUITestEntry"
    static let reservedBundleID = "com.launchcopy.ui-test"

    enum Rejection: String, Error, Equatable {
        case invalidMarker
        case invalidArguments
        case conflictingProfile
        case conflictingContent
        case invalidProfileLocation
    }

    static func resolve(arguments: [String],
                        parsed: Result<AppArguments.Options, AppArguments.ParseError>? = nil,
                        bundleIdentifier: String?, bundleURL: URL, metadata: Any?)
        -> Result<AppArguments.Options, Rejection> {
        // Dedicated gesture identity must never fall through the ordinary fake-only entry.
        guard bundleIdentifier != GestureValidationEntry.reservedBundleID,
              bundleIdentifier != IntegratedPreviewEntry.reservedBundleID else {
            return .failure(.invalidMarker)
        }
        let parsed = parsed ?? AppArguments.parse(arguments)
        let isReserved = bundleIdentifier == reservedBundleID
        if metadata == nil, !isReserved {
            let options: AppArguments.Options
            switch parsed {
            case .success(let value): options = value
            case .failure(let error):
                guard !AppStartupSafety.mustRejectStartup(error: error, arguments: arguments) else {
                    return .failure(.invalidArguments)
                }
                options = .default
            }
            return validateProfileLocation(options, bundleURL: bundleURL)
        }

        guard isReserved, let marker = metadata as? [String: Any],
              let version = marker["version"] as? NSNumber,
              CFGetTypeID(version) != CFBooleanGetTypeID(),
              Set(["c", "s", "i", "l", "q", "C", "S", "I", "L", "Q"]).contains(String(cString: version.objCType)),
              let profile = marker["profile"] as? String, UITestProfile.isValidID(profile) else {
            return .failure(.invalidMarker)
        }
        let sourcesFixture: Bool
        switch (version.int64Value, version.doubleValue) {
        case (1, 1):
            guard Set(marker.keys) == Set(["version", "profile"]) else {
                return .failure(.invalidMarker)
            }
            sourcesFixture = false
        case (2, 2):
            guard Set(marker.keys) == Set(["version", "profile", "fixture"]),
                  marker["fixture"] as? String == "sources-v1" else {
                return .failure(.invalidMarker)
            }
            sourcesFixture = true
        default:
            return .failure(.invalidMarker)
        }
        guard case .success(var options) = parsed else { return .failure(.invalidArguments) }
        guard options.uiTestProfile == nil || options.uiTestProfile == profile else {
            return .failure(.conflictingProfile)
        }
        guard options.catalogRoots.isEmpty, !options.neutralContent else {
            return .failure(.conflictingContent)
        }
        options.uiTestWindowed = true
        options.fullscreen = false
        options.uiTestProfile = profile
        options.folderLab = true
        return validateProfileLocation(options, bundleURL: bundleURL, sourcesFixture: sourcesFixture)
    }

    private static func validateProfileLocation(_ options: AppArguments.Options, bundleURL: URL,
                                                sourcesFixture: Bool = false)
        -> Result<AppArguments.Options, Rejection> {
        var options = options
        if let profileID = options.uiTestProfile {
            do {
                let profile = try UITestProfile.resolve(bundleURL: bundleURL, profileID: profileID)
                if sourcesFixture {
                    // Fixed owned children only; no caller-supplied root can enter metadata.
                    for name in ["Baseline", "Extras"] {
                        let child = profile.applicationsDirectoryURL.appendingPathComponent(name, isDirectory: true)
                        guard child.standardizedFileURL.resolvingSymlinksInPath().pathComponents == child.pathComponents else {
                            return .failure(.invalidProfileLocation)
                        }
                        do {
                            let attributes = try FileManager.default.attributesOfItem(atPath: child.path)
                            guard attributes[.type] as? FileAttributeType == .typeDirectory else {
                                return .failure(.invalidProfileLocation)
                            }
                        } catch let error as NSError where error.domain == NSCocoaErrorDomain
                            && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(error.code) {
                            // Native fixture seeding happens before launch, not during resolution.
                        }
                    }
                    options.catalogRoots = [profile.applicationsDirectoryURL
                        .appendingPathComponent("Baseline", isDirectory: true)]
                }
            } catch { return .failure(.invalidProfileLocation) }
        }
        return .success(options)
    }
}
