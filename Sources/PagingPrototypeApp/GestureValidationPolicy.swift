import Foundation

/// Narrow capability policy for the separately identified physical-gesture harness.
/// This never changes what the existing isolated UI entry can construct.
enum GestureValidationPolicy {
    static func preferences(_ value: ActivationPreferences) -> ActivationPreferences {
        var result = value
        result.settings = ActivationSettings()
        return result
    }

    static func draft(_ value: ActivationPreferencesDraft) -> ActivationPreferencesDraft {
        var result = value
        result.globalShortcutEnabled = false
        result.shortcut = nil
        result.hotCornerEnabled = false
        result.selectedCorner = nil
        result.launchAtLoginEnabled = false
        result.showStatusItem = true
        return result
    }
}

/// Never launches even an owned fixture; gesture testing needs no external actions.
struct GestureValidationAppLauncher: AppLaunching {
    func openApplication(at url: URL) -> Bool { false }
}
