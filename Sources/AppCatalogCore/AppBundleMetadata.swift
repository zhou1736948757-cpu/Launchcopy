import Foundation

/// Optional declarations from the already decoded bundle plist, not verified app facts.
public struct AppBundleMetadata: Hashable, Sendable {
    public let declaredCategoryIdentifier: String?
    public let version: String?
    public let build: String?

    public init(declaredCategoryIdentifier: String? = nil,
                version: String? = nil, build: String? = nil) {
        self.declaredCategoryIdentifier = Self.optionalString(declaredCategoryIdentifier)
        self.version = Self.optionalString(version)
        self.build = Self.optionalString(build)
    }

    /// Bound work before trimming/scanning. Oversized, blank or control-containing
    /// declarations are unknown. Do not truncate declarations or coerce plist numbers.
    private static func optionalString(_ value: String?) -> String? {
        guard let value, value.utf8.prefix(1025).count <= 1024 else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            return nil
        }
        return trimmed
    }
}
