import Foundation

/// Pure normalization for preview load and Apply; service composition stays separate.
enum IntegratedPreviewPolicy {
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
