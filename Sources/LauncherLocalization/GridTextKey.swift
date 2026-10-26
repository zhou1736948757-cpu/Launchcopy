/// App-owned grid and paging vocabulary. User content is never a localization key.
public enum GridTextKey: String, CaseIterable, Sendable {
    case pageNavigation = "grid.pageNavigation"
    case previousPageWindow = "grid.previousPageWindow"
    case nextPageWindow = "grid.nextPageWindow"
    case currentPageSuffix = "grid.currentPageSuffix"
    case currentPage = "grid.currentPage"
    case unselectedPage = "grid.unselectedPage"
    case noPages = "grid.noPages"
    case previousPage = "grid.previousPage"
    case nextPage = "grid.nextPage"
    case renameFolder = "grid.renameFolder"
    case renameFolderPrefix = "grid.renameFolderPrefix"
    case folderName = "grid.folderName"
    case folderInsufficientSpace = "grid.folderInsufficientSpace"
    case closeFolder = "grid.closeFolder"
    case newFolderFallbackTitle = "grid.newFolderFallbackTitle"
    case newFolderNameJoiner = "grid.newFolderNameJoiner"

    public var englishFallback: String {
        switch self {
        case .pageNavigation: return "Page navigation"
        case .previousPageWindow: return "Show previous pages"
        case .nextPageWindow: return "Show next pages"
        case .currentPageSuffix: return ", current page"
        case .currentPage: return "Current page"
        case .unselectedPage: return "Not selected"
        case .noPages: return "No pages"
        case .previousPage: return "Previous page"
        case .nextPage: return "Next page"
        case .renameFolder: return "Rename folder"
        case .renameFolderPrefix: return "Rename folder: "
        case .folderName: return "Folder name"
        case .folderInsufficientSpace: return "Enlarge the window to show the apps in this folder."
        case .closeFolder: return "Close folder"
        case .newFolderFallbackTitle: return "Apps"
        case .newFolderNameJoiner: return " & "
        }
    }
}
