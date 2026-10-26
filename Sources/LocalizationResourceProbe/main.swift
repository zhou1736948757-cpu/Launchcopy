import Foundation
import LauncherLocalization

// Developer verification executable only. It never imports AppKit, accesses
// preferences, launches the packaged app, or uses build-directory resources.
guard CommandLine.arguments.count == 2 else {
    fputs("localization-probe: expected one packaged app path\n", stderr)
    exit(2)
}
let appURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
guard appURL.pathExtension == "app" else {
    fputs("localization-probe: expected packaged app\n", stderr)
    exit(2)
}
let provider = BundleLocalizationResourceProvider(
    mainBundleURL: appURL,
    mainResourceURL: appURL.appendingPathComponent("Contents/Resources", isDirectory: true),
    swiftPackageBundleURL: { preconditionFailure("localization-probe: development fallback forbidden") }
)
let report = LocalizedStrings.validateResources(resourceProvider: provider)
let removalKeys = [
    "appRemoval.moveToTrash", "appRemoval.confirmTitle", "appRemoval.confirmMessage",
    "appRemoval.cancel", "appRemoval.confirmMove", "appRemoval.inspecting",
    "appRemoval.moving", "appRemoval.moved", "appRemoval.unavailable",
    "appRemoval.running", "appRemoval.failed", "appRemoval.changed",
    "appRemoval.quitTitle", "appRemoval.quitMessage"
]
guard LocalizedStrings.requiredResourceKeys.count == 369,
      LocalizedStrings.requiredResourceKeys.contains("activation.fourFingerOutwardHideEnable"),
      LocalizedStrings.requiredResourceKeys.contains("activation.fourFingerOutwardHideHelp"),
      LocalizedStrings.requiredResourceKeys.contains("grid.newFolderFallbackTitle"),
      LocalizedStrings.requiredResourceKeys.contains("grid.newFolderNameJoiner"),
      Set(LocalizedStrings.requiredResourceKeys).count == 369,
      AppRemovalTextKey.allCases.map(\.rawValue) == removalKeys,
      LocalizedStrings.requiredResourceKeys.filter({ $0.hasPrefix("appRemoval.") }) == removalKeys else {
    fputs("localization-probe: required key count or uniqueness changed\n", stderr)
    exit(1)
}
guard report.isValid else {
    fputs("localization-probe: required keys or signatures invalid (\(report.issues.count) issues)\n", stderr)
    exit(1)
}
for language in InterfaceLanguage.allCases {
    let strings = LocalizedStrings(language: language, resourceProvider: provider)
    for key in LocalizedTextKey.allCases {
        guard !strings.text(key).isEmpty, strings.text(key) != key.rawValue else {
            fputs("localization-probe: unusable required text\n", stderr)
            exit(1)
        }
    }
    for key in SettingsTextKey.allCases { guard !strings.settingsText(key).isEmpty else { exit(1) } }
    for key in ActivationTextKey.allCases { guard !strings.activationText(key).isEmpty else { exit(1) } }
    for key in ActivationStatusTextKey.allCases { guard !strings.activationStatusText(key).isEmpty else { exit(1) } }
    for key in GridTextKey.allCases { guard !strings.gridText(key).isEmpty else { exit(1) } }
    for key in MenuTextKey.allCases { guard !strings.menuText(key).isEmpty else { exit(1) } }
    for key in CatalogTextKey.allCases { guard !strings.catalogText(key).isEmpty else { exit(1) } }
    for key in NoticeTextKey.allCases { guard !strings.noticeText(key).isEmpty else { exit(1) } }
    for key in ActionFeedbackTextKey.allCases { guard !strings.actionFeedbackText(key).isEmpty else { exit(1) } }
    for key in MainGridCapacityTextKey.allCases {
        let text = strings.mainGridCapacityText(key)
        guard !text.isEmpty, text != key.rawValue else { exit(1) }
    }
    for key in LiveAppearanceTextKey.allCases {
        let text = strings.liveAppearanceText(key)
        guard !text.isEmpty, text != key.rawValue else { exit(1) }
    }
    for key in LaunchActivityTextKey.allCases {
        let text = strings.launchActivityText(key)
        guard !text.isEmpty, text != key.rawValue else { exit(1) }
    }
    for key in AppRemovalTextKey.allCases {
        let text = strings.removalText(key)
        guard !text.isEmpty, text != key.rawValue, !text.contains("%") else { exit(1) }
    }
    guard !strings.folderHelp(2).isEmpty, !strings.activationKeyCode(2).isEmpty, !strings.activationFutureVersion(2).isEmpty,
          !strings.languageFutureVersion(2).isEmpty,
          !strings.page(1, total: 2).isEmpty,
          !strings.memberCount(1).isEmpty, !strings.memberCount(2).isEmpty else {
        fputs("localization-probe: unusable typed template\n", stderr)
        exit(1)
    }
}
print("localization-probe: \(InterfaceLanguage.allCases.count) languages, \(LocalizedStrings.requiredResourceKeys.count) required keys and signatures verified from packaged app only")
