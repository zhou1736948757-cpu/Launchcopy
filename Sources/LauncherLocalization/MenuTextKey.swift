/// App-owned menu vocabulary. User folder titles and action identities stay verbatim.
public enum MenuTextKey: String, CaseIterable, Sendable {
    case launch = "menu.launch"
    case setAlias = "menu.setAlias"
    case restoreOriginalName = "menu.restoreOriginalName"
    case hideApp = "menu.hideApp"
    case revealInFinder = "menu.revealInFinder"
    case organizeApps = "menu.organizeApps"
    case moveToFolder = "menu.moveToFolder"
    case moveToTopLevel = "menu.moveToTopLevel"
    case edit = "menu.edit"
    case undo = "menu.undo"
    case redo = "menu.redo"
    case cut = "menu.cut"
    case copy = "menu.copy"
    case paste = "menu.paste"
    case selectAll = "menu.selectAll"

    public var englishFallback: String {
        switch self {
        case .launch: return "Open"
        case .setAlias: return "Set Alias…"
        case .restoreOriginalName: return "Restore Original Name"
        case .hideApp: return "Hide App"
        case .revealInFinder: return "Show in Finder"
        case .organizeApps: return "Organize App"
        case .moveToFolder: return "Move to Folder"
        case .moveToTopLevel: return "Move to Main Page"
        case .edit: return "Edit"
        case .undo: return "Undo"
        case .redo: return "Redo"
        case .cut: return "Cut"
        case .copy: return "Copy"
        case .paste: return "Paste"
        case .selectAll: return "Select All"
        }
    }
}
