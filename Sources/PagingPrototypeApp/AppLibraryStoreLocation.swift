import Foundation

/// Pure storage routing. A requested but unresolved test profile is a startup
/// rejection, never an invitation to open the production Library preferences.
enum AppLibraryStoreLocation {
    static func resolve(testProfileRequested: Bool, profile: UITestProfile?,
                        applicationSupportURL: URL?) -> URL? {
        if let profile {
            return profile.libraryDirectoryURL.appendingPathComponent("preferences.json")
        }
        guard !testProfileRequested, let root = applicationSupportURL,
              root.isFileURL, root.host == nil || root.host == "" || root.host == "localhost" else { return nil }
        return root.appendingPathComponent("Launchcopy", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("preferences.json")
    }
}
