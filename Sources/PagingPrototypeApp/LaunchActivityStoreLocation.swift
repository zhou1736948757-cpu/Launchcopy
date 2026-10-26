import Foundation

/// Separate feature data; unresolved isolated startup cannot reach formal data.
enum LaunchActivityStoreLocation {
    static func resolve(testProfileRequested: Bool, profile: UITestProfile?, applicationSupportURL: URL?) -> URL? {
        if let profile { return profile.rootURL.appendingPathComponent("LaunchActivity", isDirectory: true).appendingPathComponent("activity.json") }
        guard !testProfileRequested, let root = applicationSupportURL, root.isFileURL,
              root.host == nil || root.host == "" || root.host == "localhost" else { return nil }
        return root.appendingPathComponent("Launchcopy", isDirectory: true)
            .appendingPathComponent("LaunchActivity", isDirectory: true).appendingPathComponent("activity.json")
    }
}
