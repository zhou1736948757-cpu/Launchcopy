import CoreFoundation
import Foundation

/// Strict bundle-only opt-in, resolved before AppKit, stores or diagnostic sessions.
/// Ordinary isolated UI-test entry remains a separate, fake-only capability path.
enum GestureValidationEntry {
    static let metadataKey = "LaunchcopyGestureValidationEntry"
    static let reservedBundleID = "com.launchcopy.gesture-validation"

    static func resolve(arguments: [String], bundleIdentifier: String?, bundleURL: URL,
                        metadata: Any?, uiTestMetadata: Any?)
        -> Result<AppArguments.Options, NativeUITestEntry.Rejection> {
        guard bundleIdentifier == reservedBundleID, uiTestMetadata == nil,
              let marker = metadata as? [String: Any],
              Set(marker.keys) == Set(["version", "profile"]),
              let version = marker["version"] as? NSNumber,
              CFGetTypeID(version) != CFBooleanGetTypeID(),
              Set(["c", "s", "i", "l", "q", "C", "S", "I", "L", "Q"])
                .contains(String(cString: version.objCType)),
              version.int64Value == 1, version.doubleValue == 1,
              let profileID = marker["profile"] as? String, UITestProfile.isValidID(profileID) else {
            return .failure(.invalidMarker)
        }
        // No CLI overrides, including help, positional arguments or process-serial flags.
        // A pure startup check is routed separately by AppStartupPlan.
        guard arguments.isEmpty else { return .failure(.invalidArguments) }
        do {
            _ = try UITestProfile.resolve(bundleURL: bundleURL, profileID: profileID)
        } catch {
            return .failure(.invalidProfileLocation)
        }

        var options = AppArguments.Options.default
        options.gestureValidation = true
        options.uiTestWindowed = true
        options.fullscreen = false
        options.uiTestProfile = profileID
        options.folderLab = true
        return .success(options)
    }
}
