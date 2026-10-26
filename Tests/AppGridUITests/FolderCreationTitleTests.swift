import Foundation
import XCTest
import AppGridUI

final class FolderCreationTitleTests: XCTestCase {
    func testMixedKnownCategoriesPreferTheStationaryTargetCategory() {
        XCTAssertEqual(make(target: .photography, source: .developerTools,
                            labels: [.photography: "Photos", .developerTools: "Development"]), "Photos")
        XCTAssertEqual(make(target: .developerTools, source: .photography,
                            labels: [.photography: "Photos", .developerTools: "Development"]), "Development")
    }

    func testUnknownCategoriesUseANeutralTitleInsteadOfConcatenatedAppNames() {
        XCTAssertEqual(make(target: .other, source: .other), "Apps")
        XCTAssertEqual(make(target: .other, source: .other, fallback: "应用"), "应用")
        XCTAssertEqual(make(target: .other, source: .other, fallback: "アプリ"), "アプリ")
    }

    func testEverySharedKnownCategoryUsesInjectedLocalizedTitle() {
        for category in AppLibraryCategory.allCases where category != .other {
            XCTAssertEqual(make(target: category, source: category,
                                labels: [category: "本地分类"]), "本地分类")
        }
    }

    func testEveryKnownCategoryCanSupplyTheOnlyAvailableLabelInEitherPosition() {
        for category in AppLibraryCategory.allCases where category != .other {
            XCTAssertEqual(make(target: category, labels: [category: "Category"]), "Category")
            XCTAssertEqual(make(source: category, labels: [category: "Category"]), "Category")
        }
    }

    func testKnownSourceSuppliesLabelWhenTargetIsUnknownOrMissing() {
        for target in [nil, AppLibraryCategory.other] {
            XCTAssertEqual(make(target: target, source: .education,
                                labels: [.education: "教育", .other: "其他"]), "教育")
        }
    }

    func testOtherNeverUsesItsInjectedCategoryTitle() {
        XCTAssertEqual(make(target: .other, source: .other, labels: [.other: "Other"]), "Apps")
        XCTAssertEqual(make(target: .other, source: .games,
                            labels: [.other: "Other", .games: "Games"]), "Games")
    }

    func testUnknownDeclaredCategoryIdentifiersFallBackWithoutInferringFromNames() {
        XCTAssertEqual(make(target: .init(declaredIdentifier: "public.app-category.unknown"),
                            source: .init(declaredIdentifier: nil)), "Apps")
    }

    func testMissingTargetLabelFallsThroughToSourceThenFallback() {
        XCTAssertEqual(make(target: .music, source: .video, labels: [.video: "Video"]), "Video")
        XCTAssertEqual(make(target: .music, source: .music), "Apps")
    }

    func testUnusableTargetLabelFallsThroughToSourceThenFallback() {
        for raw in ["", " \t\r\n", "\u{0000}\u{001B}", "\u{200D}\u{FE0F}", "\u{0301}"] {
            XCTAssertEqual(make(target: .music, source: .video,
                                labels: [.music: raw, .video: "Video"]), "Video")
            XCTAssertEqual(make(target: .music, source: .video,
                                labels: [.music: raw, .video: raw], fallback: "应用"), "应用")
        }
    }

    func testMissingInputsUseTheLocalizedFallback() {
        XCTAssertEqual(make(fallback: "应用"), "应用")
        XCTAssertEqual(make(fallback: "アプリ"), "アプリ")
    }

    func testUnusableFallbackUsesTheNeutralEmergencyTitle() {
        for raw in ["", " \r\n", "\u{0000}\u{001B}", "\u{200D}\u{FE0F}", "\u{0301}"] {
            XCTAssertEqual(make(fallback: raw), "Apps")
        }
        XCTAssertEqual(make(fallback: "", existing: ["Apps", "Apps 2"]), "Apps 3")
    }

    func testCategoryAndFallbackAreLiteralTextNotFormatOrLocalizationKeys() {
        XCTAssertEqual(make(target: .games, labels: [.games: "%@ Games %d"]), "%@ Games %d")
        XCTAssertEqual(make(fallback: "folder.fallback %@"), "folder.fallback %@")
        XCTAssertEqual(make(fallback: "library.category.games"), "library.category.games")
    }

    func testWhitespaceAndEmbeddedControlsCannotInjectLines() {
        XCTAssertEqual(make(target: .developerTools,
                            labels: [.developerTools: " \t开发\r\n工具\u{2028} "]), "开发 工具")
        XCTAssertEqual(make(fallback: " \u{0000}应用\n程序\u{2029}"), "应用 程序")
    }

    func testBidirectionalAndUnsafeFormatControlsAreRemoved() {
        XCTAssertEqual(make(fallback: "\u{202E}Alpha\u{202C}\u{2066}\u{FEFF}\u{200B}"), "Alpha")
    }

    func testZWJEmojiVariationSelectorsAndScriptJoinersArePreserved() {
        let title = "👩‍👩‍👧‍👦 👩🏽‍💻 ❤️ می\u{200C}نویسم"
        XCTAssertEqual(make(fallback: title), title)
        XCTAssertEqual(make(target: .games, labels: [.games: title]), title)
    }

    func testSubdivisionFlagEmojiTagsArePreserved() {
        let flag = "\u{1F3F4}\u{E0067}\u{E0062}\u{E0065}\u{E006E}\u{E0067}\u{E007F}"
        XCTAssertEqual(make(fallback: flag), flag)
    }

    func testTitlesAtAndAbove64GraphemesUseTheExistingLimit() {
        for count in [63, 64, 65, 200] {
            let raw = String(repeating: "界", count: count)
            let expected = FolderTitle.normalized(raw, fallback: "Apps")
            XCTAssertEqual(make(fallback: raw), expected)
            XCTAssertEqual(make(target: .games, labels: [.games: raw]), expected)
        }
    }

    func testCombiningAndZWJEmojiGraphemesAreNeverSplit() {
        for grapheme in ["e\u{0301}", "👩‍👩‍👧‍👦", "👩🏽‍💻", "🇯🇵"] {
            let raw = String(repeating: grapheme, count: 70)
            let result = make(fallback: raw)
            XCTAssertEqual(result, String(repeating: grapheme, count: 64))
            XCTAssertEqual(result.count, FolderTitle.maxLength)
        }
    }

    func testClippingAtWhitespaceProducesAStableNormalizedTitle() {
        let stem = String(repeating: "a", count: 63)
        XCTAssertEqual(make(fallback: stem + " more"), stem)
        XCTAssertEqual(make(fallback: stem + " more", existing: [stem + " other"]),
                       String(repeating: "a", count: 62) + " 2")
    }

    func testCollisionComparisonIgnoresCaseDiacriticsAndCanonicalForm() {
        XCTAssertEqual(make(fallback: "Café", existing: [" \tCAFE\n", "cafe\u{0301} 2", "CAFÉ 3"]), "Café 4")
    }

    func testFixedPOSIXComparisonHandlesLetterICollisions() {
        XCTAssertEqual(make(fallback: "FILE", existing: ["file", "FiLe 2"]), "FILE 3")
    }

    func testCollisionUsesNormalizedExistingTitlesIncludingClippingAndControls() {
        let long = String(repeating: "a", count: 64)
        XCTAssertEqual(make(fallback: long, existing: ["  " + long + "extra  "]),
                       String(repeating: "a", count: 62) + " 2")
        XCTAssertEqual(make(fallback: "Alpha Beta", existing: ["Alpha\r\nBeta"]), "Alpha Beta 2")
    }

    func testSuffixStartsAtTwoAndFillsTheSmallestHole() {
        XCTAssertEqual(make(fallback: "Tools", existing: ["Tools"]), "Tools 2")
        XCTAssertEqual(make(fallback: "Tools", existing: ["Tools", "Tools 3", "Tools 4"]), "Tools 2")
        XCTAssertEqual(make(fallback: "Tools", existing: ["Tools", "Tools 2", "Tools 4"]), "Tools 3")
    }

    func testUnusedBaseDoesNotReceiveSuffixWhenNumberedTitlesExist() {
        XCTAssertEqual(make(fallback: "Tools", existing: ["Tools 2", "Tools 3", "Tools 99"]), "Tools")
    }

    func testExistingNumericEndingRemainsPartOfTheSuggestedBase() {
        XCTAssertEqual(make(fallback: "Studio 2", existing: ["Studio 2", "Studio 2 2", "Studio 3"]), "Studio 2 3")
    }

    func testCollisionSuffixSpaceIsReservedBeforeClippingEmoji() {
        let emoji = "👩🏽‍💻"
        let base = String(repeating: emoji, count: 64)
        let occupied = [base] + (2...9).map { String(repeating: emoji, count: 62) + " \($0)" }
        let result = make(fallback: base, existing: occupied)
        XCTAssertEqual(result, String(repeating: emoji, count: 61) + " 10")
        XCTAssertEqual(result.count, FolderTitle.maxLength)
    }

    func testCandidateIsComparedAfterClippingToReserveTheSuffix() {
        let base = String(repeating: "é", count: 64)
        XCTAssertEqual(make(fallback: base, existing: [base, String(repeating: "E", count: 62) + " 2"]),
                       String(repeating: "é", count: 62) + " 3")
    }

    func testSuffixClippingTrimsTheNewStemBoundary() {
        let base = String(repeating: "a", count: 61) + " bc"
        XCTAssertEqual(base.count, 64)
        XCTAssertEqual(make(fallback: base, existing: [base]), String(repeating: "a", count: 61) + " 2")
    }

    func testCategoryAndFallbackSuggestionsBothParticipateInDeduplication() {
        XCTAssertEqual(make(target: .games, source: .video, labels: [.games: "ゲーム", .video: "Video"],
                            existing: ["ゲーム", "ゲーム 2"]), "ゲーム 3")
        XCTAssertEqual(make(fallback: "应用", existing: ["应用", "应用 3"]), "应用 2")
    }

    func testUnusableExistingTitlesDoNotOccupyTheFallback() {
        XCTAssertEqual(make(existing: ["", "\n", "\u{0000}", "\u{200D}\u{FE0F}"]), "Apps")
    }

    func testDuplicateExistingEntriesAndOrderDoNotAffectTheResult() {
        let existing = ["CAFÉ 4", "cafe", "Café 2", "CAFE", "café 2", "Unrelated"]
        for offset in existing.indices {
            let rotated = Array(existing[offset...]) + Array(existing[..<offset])
            XCTAssertEqual(make(fallback: "Café", existing: rotated), "Café 3")
            XCTAssertEqual(make(fallback: "Café", existing: Array(rotated.reversed())), "Café 3")
        }
    }

    func testRepeatedCallsPreserveAllInputsAndSavedUserTitles() {
        let titles = ["  TOOLS  ", "Tools 3", "Group 1", "Untouched\nTitle", "Café"]
        let originalTitles = titles.map { Array($0.utf8) }
        let labels: [AppLibraryCategory: String] = [.utilities: "  Tools  ", .other: "Other"]
        for _ in 0..<5 {
            XCTAssertEqual(make(target: .utilities, source: .other, labels: labels, existing: titles), "Tools 2")
        }
        XCTAssertEqual(titles.map { Array($0.utf8) }, originalTitles)
        XCTAssertEqual(labels, [.utilities: "  Tools  ", .other: "Other"])
    }

    private func make(
        target: AppLibraryCategory? = nil,
        source: AppLibraryCategory? = nil,
        labels: [AppLibraryCategory: String] = [:],
        fallback: String = "Apps",
        existing: [String] = []
    ) -> String {
        FolderCreationTitle.make(targetCategory: target, sourceCategory: source,
                                 categoryTitles: labels, fallbackTitle: fallback,
                                 existingTitles: existing)
    }
}
