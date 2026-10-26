import AppGridUI
import Foundation
import XCTest

final class AppLibraryCategoryTests: XCTestCase {
    func testExactApprovedOrderAndStoredSuffixes() throws {
        let expected = ["business", "developer-tools", "education", "entertainment", "finance", "games",
                        "graphics-design", "healthcare-fitness", "lifestyle", "medical", "music", "news",
                        "photography", "productivity", "reference", "social-networking", "sports", "travel",
                        "utilities", "video", "weather", "other"]
        XCTAssertEqual(AppLibraryCategory.allCases.map(\.rawValue), expected)
        XCTAssertEqual(Set(AppLibraryCategory.allCases).count, 22)
        XCTAssertNil(AppLibraryCategory(rawValue: "all"))
        for category in AppLibraryCategory.allCases {
            XCTAssertEqual(try JSONDecoder().decode(AppLibraryCategory.self,
                                                    from: JSONEncoder().encode(category)), category)
        }
        XCTAssertThrowsError(try JSONDecoder().decode(AppLibraryCategory.self, from: Data(#""all""#.utf8)))
    }

    func testEveryTopLevelDeclarationAndOtherFallback() {
        for category in AppLibraryCategory.allCases where category != .other {
            XCTAssertEqual(category.declaredIdentifier, "public.app-category." + category.rawValue)
            XCTAssertEqual(AppLibraryCategory(declaredIdentifier: category.declaredIdentifier), category)
        }
        XCTAssertNil(AppLibraryCategory.other.declaredIdentifier)
    }

    func testExactlyEnumeratedGameSubcategoriesFoldIntoGames() {
        let suffixes = ["action-games", "adventure-games", "arcade-games", "board-games", "card-games",
                        "casino-games", "dice-games", "educational-games", "family-games", "kids-games",
                        "music-games", "puzzle-games", "racing-games", "role-playing-games", "simulation-games",
                        "sports-games", "strategy-games", "trivia-games", "word-games"]
        XCTAssertEqual(Set(suffixes).count, 19)
        for suffix in suffixes {
            XCTAssertEqual(AppLibraryCategory.from(declaredIdentifier: "public.app-category." + suffix), .games)
        }
    }

    func testUnknownMalformedAndArbitraryGameIdentifiersAreOther() {
        for identifier: String? in [nil, "", "games", "developer-tools", "public.app-category.",
                                    "public.app-category.all", "public.app-category.unknown-games",
                                    "public.app-category.action-games.extra", "public.app-category.Games",
                                    "PUBLIC.APP-CATEGORY.games", "private.app-category.games",
                                    "public.app-category.games\u{0000}"] {
            XCTAssertEqual(AppLibraryCategory(declaredIdentifier: identifier), .other)
        }
    }
}
