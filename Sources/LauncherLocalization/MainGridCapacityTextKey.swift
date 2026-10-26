/// Main-grid settings and presentation feedback, independent of storage and UI types.
public enum MainGridCapacityTextKey: String, CaseIterable, Sendable {
    case title = "mainGridCapacity.title"
    case columns = "mainGridCapacity.columns"
    case rows = "mainGridCapacity.rows"
    case itemsPerPage = "mainGridCapacity.itemsPerPage"
    case apply = "mainGridCapacity.apply"
    case restoreDefaults = "mainGridCapacity.restoreDefaults"
    case help = "mainGridCapacity.help"
    case loadCorrupt = "mainGridCapacity.loadCorrupt"
    case loadProtected = "mainGridCapacity.loadProtected"
    case unavailable = "mainGridCapacity.unavailable"
    case invalidDraft = "mainGridCapacity.invalidDraft"
    case draftDefaults = "mainGridCapacity.draftDefaults"
    case saving = "mainGridCapacity.saving"
    case savedQueued = "mainGridCapacity.savedQueued"
    case applied = "mainGridCapacity.applied"
    case presentationUnavailable = "mainGridCapacity.presentationUnavailable"
    case saveFailed = "mainGridCapacity.saveFailed"
    case recoveryRequired = "mainGridCapacity.recoveryRequired"
    case insufficientSpace = "mainGridCapacity.insufficientSpace"

    /// Last-resort text when selected-language and English resources are unavailable.
    public var englishFallback: String {
        switch self {
        case .title: return "Grid"
        case .columns: return "Columns"
        case .rows: return "Rows"
        case .itemsPerPage: return "Items per page"
        case .apply: return "Apply Grid"
        case .restoreDefaults: return "Default Grid"
        case .help: return "Choose 3–8 columns and rows for the main grid. Folders keep their own layout. Apply saves this draft; the grid updates when the current interaction finishes and folders or App Library are closed. Closing settings discards unsaved edits."
        case .loadCorrupt: return "Saved grid settings are damaged. The draft uses defaults. Apply explicitly replaces the damaged grid settings; other settings are unchanged."
        case .loadProtected: return "Saved grid settings use an unsupported format and cannot be changed. The saved file will not be overwritten."
        case .unavailable: return "Grid settings are unavailable. The draft has not been saved."
        case .invalidDraft: return "Grid values are invalid. Choose 3–8 columns and rows. The draft has not been saved."
        case .draftDefaults: return "Default grid (5 columns, 7 rows) loaded into the draft. Apply to save only grid settings."
        case .saving: return "Saving grid settings…"
        case .savedQueued: return "Grid settings saved. They will apply when the current interaction finishes and folders or App Library are closed."
        case .applied: return "Saved grid settings applied."
        case .presentationUnavailable: return "Grid settings saved. The launcher is unavailable; reopen it to see the changes."
        case .saveFailed: return "Could not save grid settings. The draft is retained; try Apply again."
        case .recoveryRequired: return "Saved grid settings are damaged. Reopen settings to review recovery, then Apply to replace them."
        case .insufficientSpace: return "The window is too small for this grid. Enlarge the window or reduce columns or rows in Settings."
        }
    }
}
