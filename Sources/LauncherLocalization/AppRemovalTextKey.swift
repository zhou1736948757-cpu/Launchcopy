/// Static copy for moving one selected app bundle to the macOS Trash.
/// App identity and path are presented separately by the action owner.
public enum AppRemovalTextKey: String, CaseIterable, Sendable {
    case moveToTrash = "appRemoval.moveToTrash"
    case confirmTitle = "appRemoval.confirmTitle"
    case confirmMessage = "appRemoval.confirmMessage"
    case cancel = "appRemoval.cancel"
    case confirmMove = "appRemoval.confirmMove"
    case inspecting = "appRemoval.inspecting"
    case moving = "appRemoval.moving"
    case moved = "appRemoval.moved"
    case unavailable = "appRemoval.unavailable"
    case running = "appRemoval.running"
    case failed = "appRemoval.failed"
    case changed = "appRemoval.changed"
    case quitTitle = "appRemoval.quitTitle"
    case quitMessage = "appRemoval.quitMessage"

    /// Last-resort text when selected-language and English resources are unavailable.
    public var englishFallback: String {
        switch self {
        case .moveToTrash: return "Move to Trash…"
        case .confirmTitle: return "Move App to Trash?"
        case .confirmMessage: return "Move only the selected app bundle to the macOS Trash. Support files and preferences are not removed; this is not a complete uninstall. You can recover the app using Finder. Cancel is selected by default."
        case .cancel: return "Cancel"
        case .confirmMove: return "Move to Trash"
        case .inspecting: return "Checking whether this app can be moved to Trash…"
        case .moving: return "Moving app to Trash…"
        case .moved: return "App moved to Trash. You can recover it using Finder."
        case .unavailable: return "This app cannot currently be moved to Trash."
        case .running: return "This app is running. Quit it yourself, then try again. Launchcopy will not force quit it."
        case .failed: return "Could not confirm that the app was moved to Trash. Check its location in Finder before trying again."
        case .changed: return "The selected app or its location changed. Select the app again and review a new confirmation."
        case .quitTitle: return "App Removal Is Unresolved"
        case .quitMessage: return "The Move to Trash operation has failed or its outcome is still unknown. Cancel Quit is selected by default. Check the app in Finder before trying again. Quitting does not cancel or undo an accepted operation."
        }
    }
}
