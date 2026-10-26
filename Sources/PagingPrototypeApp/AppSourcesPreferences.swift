import Foundation

/// Additional discovery inputs only. Fixed baseline roots belong to application assembly.
public struct AppSourcesPreferences: Codable, Equatable, Sendable {
    public var customRootPaths: [String]
    public var automaticRefreshEnabled: Bool

    public init(customRootPaths: [String] = [], automaticRefreshEnabled: Bool = true) {
        self.customRootPaths = customRootPaths
        self.automaticRefreshEnabled = automaticRefreshEnabled
    }

    public static let `default` = AppSourcesPreferences()

    /// Requires canonical absolute paths and uniqueness, without filesystem access.
    /// Existence, permissions, local-volume and home boundaries are runtime admission concerns.
    public var isValid: Bool {
        var seen = Set<String>()
        for path in customRootPaths {
            guard let standardized = Self.standardizedRootPath(path), standardized == path,
                  seen.insert(path).inserted else { return false }
        }
        return true
    }

    /// Lexical POSIX normalization only; never expands a home directory or resolves a symlink.
    /// Returns nil for nonabsolute paths, ASCII controls, and the whole filesystem root.
    public static func standardizedRootPath(_ path: String) -> String? {
        guard path.hasPrefix("/"),
              !path.unicodeScalars.contains(where: { $0.value < 0x20 || $0.value == 0x7F }) else {
            return nil
        }
        var components: [Substring] = []
        for component in path.split(separator: "/", omittingEmptySubsequences: true) {
            if component == "." { continue }
            if component == ".." {
                if !components.isEmpty { components.removeLast() }
            } else {
                components.append(component)
            }
        }
        guard !components.isEmpty else { return nil }
        return "/" + components.joined(separator: "/")
    }
}
