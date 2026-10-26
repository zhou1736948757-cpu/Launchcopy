import CoreFoundation
import Foundation

/// Bundle-only preview opt-in, resolved before stores, services or diagnostics open.
enum IntegratedPreviewEntry {
    static let metadataKey = "LaunchcopyIntegratedPreviewEntry"
    static let reservedBundleID = "com.launchcopy.integrated-preview"

    static func resolve(arguments: [String], bundleIdentifier: String?, bundleURL: URL,
                        metadata: Any?, uiTestMetadata: Any?, gestureMetadata: Any?)
        -> Result<AppArguments.Options, NativeUITestEntry.Rejection> {
        guard bundleIdentifier == reservedBundleID,
              uiTestMetadata == nil, gestureMetadata == nil,
              let marker = metadata as? [String: Any],
              Set(marker.keys) == Set(["version", "profile"]),
              let version = marker["version"] as? NSNumber,
              CFGetTypeID(version) != CFBooleanGetTypeID(),
              Set(["c", "s", "i", "l", "q", "C", "S", "I", "L", "Q"])
                .contains(String(cString: version.objCType)),
              version.int64Value == 1, version.doubleValue == 1,
              let profileID = marker["profile"] as? String,
              UITestProfile.isValidID(profileID) else {
            return .failure(.invalidMarker)
        }
        // Startup-check and headless diagnostic routing belong to AppStartupPlan.
        // Even matching profile overrides, help and positional arguments must reject.
        guard arguments.isEmpty else { return .failure(.invalidArguments) }
        guard bundleURL.standardizedFileURL.resolvingSymlinksInPath()
            .standardizedFileURL.pathComponents == bundleURL.pathComponents else {
            return .failure(.invalidProfileLocation)
        }
        do {
            let profile = try UITestProfile.resolve(bundleURL: bundleURL, profileID: profileID)
            try validateStorage(profile)
        } catch {
            return .failure(.invalidProfileLocation)
        }

        var options = AppArguments.Options.default
        options.integratedPreview = true
        options.gestureValidation = false
        options.uiTestWindowed = true
        options.fullscreen = false
        options.uiTestProfile = profileID
        options.folderLab = false
        options.catalogRoots = []
        return .success(options)
    }

    /// Capacity storage is a real preview output, although older UI profiles
    /// deliberately handle its faults later. Keep this stricter entry local.
    static func validateStorage(_ profile: UITestProfile) throws {
        let directory = profile.rootURL.appendingPathComponent("MainGridCapacity", isDirectory: true)
        guard directory.standardizedFileURL.resolvingSymlinksInPath().pathComponents == directory.pathComponents,
              (try? FileManager.default.destinationOfSymbolicLink(atPath: directory.path)) == nil else {
            throw NativeUITestEntry.Rejection.invalidProfileLocation
        }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            throw NativeUITestEntry.Rejection.invalidProfileLocation
        }
    }

}
