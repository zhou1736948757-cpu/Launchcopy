import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class AppRemovalFeedbackTests: XCTestCase {
    func testRemovalFeedbackIsDeferredLocalizedAndClearedWithoutNewViews() async {
        let view = ActionFeedbackNoticeView(frame: .init(x: 0, y: 0, width: 400, height: 40))
        defer { view.teardown() }
        let count = view.subviews.count
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            let before = view.languageFormattingCount
            view.show(removalReason: .moving, strings: strings)
            XCTAssertEqual(view.languageFormattingCount, before)
            let presented = await waitUntil { view.statusText == strings.removalText(.moving) }
            XCTAssertTrue(presented)
            XCTAssertEqual(view.accessibilityValue() as? String, strings.removalText(.moving))
            XCTAssertNil(view.reason)
            XCTAssertEqual(view.removalReason, .moving)
            XCTAssertEqual(view.subviews.count, count)
            let formatted = view.languageFormattingCount
            _ = view.requiredPresentationHeight(forWidth: 300)
            XCTAssertEqual(view.languageFormattingCount, formatted, "Layout stack does not format text")
        }
        view.clear()
        XCTAssertNil(view.reason); XCTAssertNil(view.removalReason)
        let hidden = await waitUntil { view.isHidden }; XCTAssertTrue(hidden)
    }

    func testSharedNoticeCannotRetainTwoCompetingReasons() async {
        let strings = LocalizedStrings(language: .english)
        let view = ActionFeedbackNoticeView(frame: .zero)
        defer { view.teardown() }
        view.show(reason: .launchFailed, strings: strings)
        view.show(removalReason: .unavailable, strings: strings)
        let removal = await waitUntil { view.statusText == strings.removalText(.unavailable) }
        XCTAssertTrue(removal); XCTAssertNil(view.reason)
        view.show(reason: .finderMissing, strings: strings)
        let finder = await waitUntil { view.statusText == strings.actionFeedbackText(.finderMissing) }
        XCTAssertTrue(finder); XCTAssertNil(view.removalReason)
    }
}
