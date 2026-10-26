/// Live Appearance copy shared by the appearance and main-grid presentation owners.
public enum LiveAppearanceTextKey: String, CaseIterable, Sendable {
    case help = "liveAppearance.help"
    case gridHelp = "liveAppearance.gridHelp"
    case saving = "liveAppearance.saving"
    /// Use only for the relevant owner's current save acknowledgment, not visual presentation.
    case saved = "liveAppearance.saved"
    case saveFailed = "liveAppearance.saveFailed"
    case retry = "liveAppearance.retry"
    case recover = "liveAppearance.recover"
    case defaults = "liveAppearance.defaults"
    /// Reports a scoped defaults request; each domain must still display its own save result.
    case defaultsApplied = "liveAppearance.defaultsApplied"
    /// Pending presentation only; this key makes no claim about save completion.
    case queued = "liveAppearance.queued"
    case unavailable = "liveAppearance.unavailable"
    case protected = "liveAppearance.protected"
    case recoveryRequired = "liveAppearance.recoveryRequired"
    case recoveryFailed = "liveAppearance.recoveryFailed"

    /// Last-resort text when selected-language and English resources are unavailable.
    public var englishFallback: String {
        switch self {
        case .help: return "Changes take effect as you edit and save automatically. Visual updates wait only while an interaction cannot safely be interrupted. Closing settings does not discard changes. Icons and names fit within the existing cells, so larger settings may appear smaller. Set blur to 0 for no blur."
        case .gridHelp: return "Choose 3–8 columns and rows for the main grid; valid changes save automatically. The layout updates as you edit when safe, and waits only for interactions that cannot safely be interrupted to finish and for folders and App Library to close. Folder layouts stay independent. Closing settings does not discard changes."
        case .saving: return "Saving changes…"
        case .saved: return "Changes saved."
        case .saveFailed: return "Could not save changes. Your latest changes are retained. Choose Retry Saving to try again."
        case .retry: return "Retry Saving"
        case .recover: return "Recover Settings"
        case .defaults: return "Restore Appearance Defaults"
        case .defaultsApplied: return "Appearance defaults and the main-grid default of 5 columns and 7 rows have been requested. Each section reports its own save result; either save can fail independently. Other settings and app arrangement are unchanged."
        case .queued: return "Waiting to show the latest changes until the current interaction can finish safely. Main-grid layout changes also wait for folders and App Library to close."
        case .unavailable: return "Settings are unavailable. Automatic saving is paused; stored data will not be overwritten."
        case .protected: return "Saved settings use a newer or unrecognized format and are protected. Automatic saving is paused; stored data will not be overwritten."
        case .recoveryFailed: return "Recovery failed. Your selection is retained. Choose Recover Settings to try again."
        case .recoveryRequired: return "Saved settings are damaged. Automatic saving is paused. Choose Recover Settings to explicitly replace the damaged settings."
        }
    }
}
