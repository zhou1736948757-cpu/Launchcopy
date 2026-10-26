import Foundation

/// Parsing failure must never turn an explicitly isolated test into production startup.
/// Ordinary legacy argument fallback remains a separate, unchanged policy.
enum AppStartupSafety {
    static func mustRejectStartup(error: AppArguments.ParseError, arguments: [String]) -> Bool {
        if hasUITestIntent(arguments: arguments) { return true }
        switch error {
        case .invalidUITestProfile, .uiTestProfileRequiresWindowed, .duplicateUITestProfile,
             .invalidMomentumDecay, .invalidMomentumGlideFrames, .invalidMomentumOvershoot,
             .invalidFrameTimerTolerance:
            return true
        default:
            return false
        }
    }

    static func hasUITestIntent(arguments: [String]) -> Bool {
        arguments.contains { argument in
            let name = argument.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init)?.lowercased()
            return name == "--ui-test-profile" || name == "--ui-test-windowed"
        }
    }

}
