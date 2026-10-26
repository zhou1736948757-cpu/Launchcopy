import Foundation

/// An immutable presentation snapshot. Build outside frame callbacks and retain
/// it until the presentation owner safely accepts a new displayed language.
public struct LocalizedStrings: Sendable {
    public let language: InterfaceLanguage
    private let templates: [String: ValidatedTemplate]
    private let englishTemplates: [String: ValidatedTemplate]

    /// Reports the effective locator even when the packaged bundle is absent.
    /// App processes must never reach SwiftPM's absolute development-path fallback.
    public static var resourceBundleURL: URL {
        LocalizationResourceBundleLocator.resourceBundleURL(
            mainBundleURL: Bundle.main.bundleURL,
            mainResourceURL: Bundle.main.resourceURL,
            swiftPackageBundleURL: { Bundle.module.bundleURL }
        )
    }

    public static var requiredResourceKeys: [String] { ResourceKey.all.map(\.name) }

    public init(language: InterfaceLanguage) {
        self.init(language: language, resourceProvider: BundleLocalizationResourceProvider())
    }

    /// A deterministic seam for absent, invalid or independently packaged resources.
    /// The provider is consumed synchronously and is not retained in the snapshot.
    public init(language: InterfaceLanguage, resourceProvider: any LocalizationResourceProviding) {
        self.language = language
        let selected = ResourceTable(language: language, data: resourceProvider.localizableStringsData(for: language))
        let english = language == .english ? selected :
            ResourceTable(language: .english, data: resourceProvider.localizableStringsData(for: .english))
        templates = selected.templates
        englishTemplates = english.templates
    }

    public func text(_ key: LocalizedTextKey) -> String {
        render(.text(key)) ?? Self.safeEnglishText(key)
    }

    /// Reads only the validated snapshot. Relabel settings outside frame callbacks.
    public func settingsText(_ key: SettingsTextKey) -> String {
        render(.settingsText(key)) ?? Self.safeEnglishSettingsText(key)
    }

    /// Substitute exactly two rounded point sizes without executing a resource as
    /// a printf format string. Settings templates otherwise remain static text.
    public func mainIconFitText(app: Double, folder: Double) -> String {
        var parts = settingsText(.appearanceMainIconFitFormat).components(separatedBy: "%.0f")
        if parts.count != 3 || parts.contains(where: { $0.contains("%") }) {
            parts = Self.safeEnglishSettingsText(.appearanceMainIconFitFormat).components(separatedBy: "%.0f")
        }
        return parts[0] + String(format: "%.0f", app) + parts[1]
            + String(format: "%.0f", folder) + parts[2]
    }

    public func activationText(_ key: ActivationTextKey) -> String {
        render(.activationText(key)) ?? key.englishFallback
    }

    public func activationStatusText(_ key: ActivationStatusTextKey) -> String {
        render(.activationStatusText(key)) ?? key.englishFallback
    }

    public func gridText(_ key: GridTextKey) -> String {
        render(.gridText(key)) ?? key.englishFallback
    }

    public func menuText(_ key: MenuTextKey) -> String {
        render(.menuText(key)) ?? key.englishFallback
    }

    public func catalogText(_ key: CatalogTextKey) -> String {
        render(.catalogText(key)) ?? key.englishFallback
    }

    public func noticeText(_ key: NoticeTextKey) -> String {
        render(.noticeText(key)) ?? key.englishFallback
    }

    public func actionFeedbackText(_ key: ActionFeedbackTextKey) -> String {
        render(.actionFeedbackText(key)) ?? key.englishFallback
    }

    /// Reads only this validated snapshot; no domain dependency or rendering-time IO.
    public func libraryText(_ key: LibraryTextKey) -> String {
        render(.libraryText(key)) ?? key.englishFallback
    }

    public func mainGridCapacityText(_ key: MainGridCapacityTextKey) -> String {
        render(.mainGridCapacityText(key)) ?? key.englishFallback
    }

    /// Reads only this validated snapshot; save and presentation states remain separate.
    public func liveAppearanceText(_ key: LiveAppearanceTextKey) -> String {
        render(.liveAppearanceText(key)) ?? key.englishFallback
    }

    /// Reads only this validated snapshot; all activity copy has a static signature.
    public func launchActivityText(_ key: LaunchActivityTextKey) -> String {
        render(.launchActivityText(key)) ?? key.englishFallback
    }

    /// Static removal copy only; the action owner supplies app identity separately.
    public func removalText(_ key: AppRemovalTextKey) -> String {
        render(.removalText(key)) ?? key.englishFallback
    }

    public func folderHelp(_ count: Int) -> String {
        let key: ResourceKey = language == .english && count == 1 ? .folderHelpOne : .folderHelpOther
        let englishKey: ResourceKey = count == 1 ? .folderHelpOne : .folderHelpOther
        return templates[key.name]?.render(["count": count]) ??
            englishTemplates[englishKey.name]?.render(["count": count]) ??
            (count == 1 ? "Folder containing \(count) item" : "Folder containing \(count) items")
    }

    public func activationKeyCode(_ keyCode: Int) -> String {
        render(.activationKeyCode, arguments: ["keyCode": keyCode]) ?? "Key code \(keyCode)"
    }

    public func activationFutureVersion(_ version: Int) -> String {
        render(.activationFutureVersion, arguments: ["version": version]) ??
            "Could not save settings (storage version \(version) is newer than this app). Restoring the previous configuration was attempted."
    }

    /// Formats the full hidden-reference sentence, including uninstalled apps.
    /// The displayed language selects grammar; English fallback selects its own
    /// one/other form. All Int values are preserved without locale-dependent IO.
    public func hiddenReferenceCount(_ count: Int) -> String {
        let key: ResourceKey = language == .english && count == 1 ? .hiddenReferenceCountOne : .hiddenReferenceCountOther
        let englishKey: ResourceKey = count == 1 ? .hiddenReferenceCountOne : .hiddenReferenceCountOther
        return templates[key.name]?.render(["count": count]) ??
            englishTemplates[englishKey.name]?.render(["count": count]) ??
            (count == 1 ? "\(count) hidden reference (including apps not currently installed)" :
                "\(count) hidden references (including apps not currently installed)")
    }

    public func languageFutureVersion(_ version: Int) -> String {
        render(.languageFutureVersion, arguments: ["version": version]) ??
            "Language settings use a newer version (\(version)) and cannot be changed."
    }

    public func page(_ page: Int, total: Int) -> String {
        render(.page, arguments: ["page": page, "total": total]) ??
            "Page \(page) of \(total)"
    }

    public func memberCount(_ count: Int) -> String {
        // The selected language, not the OS locale, defines the plural rule.
        // Chinese and Japanese always use their invariant "other" resource.
        let key: ResourceKey = language == .english && count == 1 ? .memberCountOne : .memberCountOther
        let englishKey: ResourceKey = count == 1 ? .memberCountOne : .memberCountOther
        return templates[key.name]?.render(["count": count]) ??
            englishTemplates[englishKey.name]?.render(["count": count]) ??
            (count == 1 ? "\(count) item" : "\(count) items")
    }

    private func render(_ key: ResourceKey, arguments: [String: Int] = [:]) -> String? {
        templates[key.name]?.render(arguments) ?? englishTemplates[key.name]?.render(arguments)
    }

    /// Validates raw shipped tables before any fallback can hide a missing entry.
    /// The report intentionally excludes resource contents, arbitrary keys and paths.
    public static func validateResources(
        resourceProvider: any LocalizationResourceProviding = BundleLocalizationResourceProvider()
    ) -> LocalizationResourceValidation {
        let issues = InterfaceLanguage.allCases.flatMap { language in
            ResourceTable(language: language, data: resourceProvider.localizableStringsData(for: language)).issues
        }
        return LocalizationResourceValidation(issues: issues)
    }

    private static func safeEnglishSettingsText(_ key: SettingsTextKey) -> String {
        switch key {
        case .activationTabTitle: return "Activation"
        case .appearanceTabTitle: return "Appearance"
        case .managementTabTitle: return "Apps"
        case .sourcesTabTitle: return "Sources"
        case .settingsWindowTitle: return "Settings"
        case .viewMenuTitle: return "View"
        case .toggleLauncherTitle: return "Show/Hide Launcher"
        case .settingsButtonAccessibility: return "Settings"
        case .appearanceShowLabels: return "Show app names"
        case .appearanceBlurAccessibility: return "Wallpaper blur"
        case .appearanceIconAccessibility: return "Base and folder icon preferred size"
        case .appearanceMainIconAccessibility: return "Main-page icon preferred size"
        case .appearanceMainIconCaption: return "Main-page icon preferred size (32–96 pt)"
        case .appearanceMainIconFitFormat: return "Current-window candidate fit: app %.0f pt; folder entry %.0f pt. This estimate does not confirm saving or display."
        case .appearanceIndependentIconsHelp: return "Main-page icon size is independent of the base size used inside folders. Older settings inherit the base size until you move the main-page slider. Dense grids or smaller windows may fit icons below your preferred size; the preference and selected row and column counts stay unchanged. The fit estimate uses the current window and your selections; save and display status are reported separately."
        case .appearanceFontAccessibility: return "App name font size"
        case .appearanceApply: return "Apply Appearance"
        case .appearanceRestoreDefaults: return "Restore Defaults"
        case .appearanceBlurCaption: return "Wallpaper blur (0–60)"
        case .appearanceHelp: return "Icons and names fit within the existing cells, so larger settings may appear smaller. Set blur to 0 for no blur. Click Apply after making changes; they appear when gestures, dragging or renaming finish. Closing discards unsaved drafts."
        case .appearanceIconCaption: return "Base / inside-folder icon preferred size (32–96 pt)"
        case .appearanceFontCaption: return "App name font size (9–16 pt)"
        case .appearanceLoadFuture: return "Appearance settings were saved by a newer version and will not be overwritten."
        case .appearanceLoadCorrupt: return "Could not read appearance settings. Defaults are in use. Click Apply to save new settings."
        case .appearanceInvalidDraft: return "Appearance values are invalid. Changes were not saved."
        case .appearanceUnavailable: return "Appearance settings are currently unavailable."
        case .appearanceSaveFuture: return "Appearance settings from a newer version were not overwritten."
        case .appearanceInvalidPreferences: return "Blur, icon size or font size is outside the supported range."
        case .appearanceSaveFailed: return "Could not save appearance settings. Changes were not applied."
        case .appearanceDraftDefaults: return "Defaults loaded into the draft. Click Apply to save."
        case .appearanceApplied: return "Appearance settings applied."
        case .appearanceQueued: return "Appearance settings saved. They will appear when gestures, dragging or renaming finish."
        case .appearancePresentationUnavailable: return "Appearance settings saved. The interface is unavailable; reopen it to see the changes."
        case .managementHideSelected: return "Hide selected app"
        case .managementSaveAlias: return "Save Alias"
        case .managementClearAlias: return "Restore Original Name"
        case .managementRestoreAll: return "Show All Hidden Apps"
        case .managementAppAccessibility: return "Manage apps"
        case .managementAliasPlaceholder: return "Leave empty to restore the original name"
        case .managementAliasAccessibility: return "App alias"
        case .managementHelp: return "Hiding an app does not delete it or its saved arrangement. Aliases affect only display and search, not app files. You can still search by the original name."
        case .managementSelectApp: return "Select an app…"
        case .managementHiddenSuffix: return " (hidden)"
        case .managementLoadFuture: return "App management settings were saved by a newer version and will not be overwritten."
        case .managementLoadCorrupt: return "Could not read management settings. Defaults are in use; saving will replace the damaged settings."
        case .managementSaved: return "App management settings saved."
        case .managementInvalidAlias: return "Aliases cannot contain control characters and must be 128 characters or fewer."
        case .managementSaveFuture: return "Settings from a newer version were not overwritten."
        case .managementSaveFailed: return "Could not apply settings. Select the app again and retry."
        case .managementSearchIdentifiers: return "Search application identifiers"
        case .managementIdentifierSearchHelp: return "Also find apps by identifiers such as com.example.app. Original names and aliases remain searchable."
        case .managementIdentifierSearchApplied: return "Identifier search setting applied."
        case .managementIdentifierSearchQueued: return "Identifier search setting saved. It will apply when the current interaction finishes."
        case .managementIdentifierSearchFailed: return "Could not save the identifier search setting. The previous setting is retained. Try again."
        case .managementIdentifierSearchFuture: return "Identifier search cannot be changed because app management settings were saved by a newer version."
        case .managementIdentifierSearchCorrupt: return "Identifier search cannot be changed because app management settings could not be read."
        case .sourcesAutomatic: return "Refresh app list automatically"
        case .sourcesAdd: return "Add Folder…"
        case .sourcesRemove: return "Remove Selected Source"
        case .sourcesApply: return "Apply Source Settings"
        case .sourcesRefresh: return "Refresh Now"
        case .sourcesRootAccessibility: return "Additional app sources"
        case .sourcesFixedCaption: return "Fixed sources (retained)"
        case .sourcesExtraCaption: return "Additional sources"
        case .sourcesHelp: return "Only readable local folders are supported. Your entire home folder, disk roots and network locations are not accepted. Removing a source does not delete apps, saved arrangements or aliases. Click Apply after making changes; Refresh Now uses only saved sources."
        case .sourcesLoadFuture: return "Source settings were saved by a newer version and will not be overwritten."
        case .sourcesLoadCorrupt: return "Could not read source settings. Fixed sources are in use; click Apply to save new settings."
        case .sourcesWatchActive: return "Automatic refresh is on; changes are processed together."
        case .sourcesWatchDisabled: return "Automatic refresh is off. Use Refresh Now to update."
        case .sourcesWatchUnavailable: return "Automatic refresh is unavailable. Use Refresh Now."
        case .sourcesWatchDegraded: return "Some sources cannot currently be monitored. Use Refresh Now to check again, including folders that become available again."
        case .sourcesSelectRoot: return "Select an additional source…"
        case .sourcesRemovedDraft: return "Source removed from the draft. Click Apply to confirm; apps and saved arrangements will not be deleted."
        case .sourcesPanelPrompt: return "Choose App Folder"
        case .sourcesAddedDraft: return "Source added to the draft. Click Apply to save."
        case .sourcesAlreadyCovered: return "The selected folder is already included in the fixed sources."
        case .sourcesRejected: return "Could not add this source. Choose a readable local app folder."
        case .sourcesSaved: return "Source settings saved and applied."
        case .sourcesSaveFuture: return "Source settings from a newer version were not overwritten."
        case .sourcesInvalidRoot: return "Source validation failed. Changes were not saved; select the folder again."
        case .sourcesSaveFailed: return "Could not save source settings. Changes were not applied."
        case .sourcesSuperseded: return "This operation was cancelled or replaced by a newer operation."
        }
    }

    private static func safeEnglishText(_ key: LocalizedTextKey) -> String {
        switch key {
        case .languageFutureProtected: return "Saved language settings use an unreadable newer schema and will not be overwritten."
        case .languageTitle: return "Language"
        case .followSystem: return "Follow System"
        case .languageHelp: return "Choose the interface language for Launchcopy. Apply to save your choice."
        case .apply: return "Apply"
        case .restoreDefaults: return "Restore Defaults"
        case .languageApplied: return "Language saved and applied."
        case .languageQueued: return "Language saved. It will apply when the current interaction finishes."
        case .languageSaveFailed: return "Could not save the language. Your selection is still a draft."
        case .languageCorrupt: return "Saved language settings are invalid. Choose a language and apply to replace them."
        case .languageStoreUnavailable: return "Language settings are unavailable. Your selection has not been saved."
        case .languageDraftDefaults: return "Follow System selected. Apply to save this default."
        case .close: return "Close"
        case .cancel: return "Cancel"
        case .searchPlaceholder: return "Search apps"
        case .searchAccessibility: return "Search apps"
        case .settingsTitle: return "Launchcopy Settings"
        case .showLauncher: return "Show Launchcopy"
        case .hideLauncher: return "Hide Launchcopy"
        case .quitLauncher: return "Quit Launchcopy"
        }
    }
}
