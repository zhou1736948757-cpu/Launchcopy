import Foundation

/// Fixed approved order. All is a filter represented by nil, never a stored category.
public enum AppLibraryCategory: String, Codable, CaseIterable, Sendable {
    case business
    case developerTools = "developer-tools"
    case education
    case entertainment
    case finance
    case games
    case graphicsDesign = "graphics-design"
    case healthcareFitness = "healthcare-fitness"
    case lifestyle
    case medical
    case music
    case news
    case photography
    case productivity
    case reference
    case socialNetworking = "social-networking"
    case sports
    case travel
    case utilities
    case video
    case weather
    case other

    /// Other has no recognized bundle declaration.
    public var declaredIdentifier: String? {
        self == .other ? nil : Self.declaredPrefix + rawValue
    }

    public init(declaredIdentifier: String?) {
        self = Self.from(declaredIdentifier: declaredIdentifier)
    }

    public static func from(declaredIdentifier: String?) -> Self {
        guard let declaredIdentifier, declaredIdentifier.hasPrefix(declaredPrefix) else { return .other }
        let suffix = String(declaredIdentifier.dropFirst(declaredPrefix.count))
        if gameSuffixes.contains(suffix) { return .games }
        return Self(rawValue: suffix) ?? .other
    }

    private static let declaredPrefix = "public.app-category."
    private static let gameSuffixes: Set<String> = [
        "action-games", "adventure-games", "arcade-games", "board-games", "card-games",
        "casino-games", "dice-games", "educational-games", "family-games", "kids-games",
        "music-games", "puzzle-games", "racing-games", "role-playing-games", "simulation-games",
        "sports-games", "strategy-games", "trivia-games", "word-games"
    ]
}
