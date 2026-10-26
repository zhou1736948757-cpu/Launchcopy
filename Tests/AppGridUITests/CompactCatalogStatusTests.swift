import AppKit
import LauncherLocalization
import XCTest
@testable import AppGridUI

@MainActor
final class CompactCatalogStatusTests: XCTestCase {
    private func drain() async {
        for _ in 0..<4 { await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } } }
    }

    func testCompactMessagesRetainFullLocalizedAXAndTooltipWhileStayingPassive() async throws {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            let view = AppGridStatusView(frame: NSRect(x: 0, y: 0, width: 80, height: 20), strings: strings)
            defer { view.teardown() }
            view.setCompactPresentation(true)
            for state in [AppGridUIState.partialFailure, .refreshing] {
                view.update(state: state); await drain(); view.layoutSubtreeIfNeeded()
                let key: CatalogTextKey = state == .partialFailure ? .partialFailure : .refreshing
                XCTAssertEqual(view.statusText, strings.catalogText(key))
                XCTAssertEqual(view.accessibilityLabel(), strings.catalogText(key))
                XCTAssertEqual(view.toolTip, strings.catalogText(key))
                XCTAssertEqual(view.requiredPresentationHeight(forWidth: 80), 20)
                let label = try XCTUnwrap(view.subviews.compactMap { $0 as? NSTextField }.first)
                XCTAssertEqual(label.maximumNumberOfLines, 1)
                XCTAssertEqual(label.lineBreakMode, .byTruncatingTail)
                XCTAssertNil(view.hitTest(NSPoint(x: 20, y: 10)))
                let spinner = try XCTUnwrap(view.subviews.compactMap { $0 as? NSProgressIndicator }.first)
                let warning = try XCTUnwrap(view.subviews.compactMap { $0 as? NSImageView }.first)
                XCTAssertEqual(spinner.isHidden, state != .refreshing)
                XCTAssertEqual(warning.isHidden, state != .partialFailure)
                XCTAssertFalse(spinner.isAccessibilityElement())
                XCTAssertFalse(warning.isAccessibilityElement())
            }
        }
    }

    func testRegularStyleAndTeardownRestoreTextAndDiscardQueuedCompactWork() async throws {
        let view = AppGridStatusView(frame: NSRect(x: 0, y: 0, width: 200, height: 180))
        view.setCompactPresentation(true); view.update(state: .partialFailure)
        await drain(); view.layoutSubtreeIfNeeded()
        view.setCompactPresentation(false); view.update(state: .loading)
        await drain(); view.layoutSubtreeIfNeeded()
        XCTAssertNil(view.toolTip)
        let label = try XCTUnwrap(view.subviews.compactMap { $0 as? NSTextField }.first)
        XCTAssertFalse(label.isHidden)
        XCTAssertEqual(label.maximumNumberOfLines, 0)
        XCTAssertGreaterThan(view.requiredPresentationHeight(forWidth: 200), 20)
        view.setCompactPresentation(true); view.teardown(); let count = view.languageFormattingCount
        await drain()
        XCTAssertEqual(view.languageFormattingCount, count)
        XCTAssertNil(view.toolTip)
        XCTAssertTrue(view.isHidden)
    }

    func testStyleAndLayoutStageWithoutFormattingOnTheCallingStack() async {
        let view = AppGridStatusView(frame: NSRect(x: 0, y: 0, width: 160, height: 20))
        defer { view.teardown() }
        await drain()
        let before = view.languageFormattingCount
        view.setCompactPresentation(true)
        view.update(state: .partialFailure)
        view.layoutSubtreeIfNeeded()
        XCTAssertEqual(view.languageFormattingCount, before)
        await drain()
        XCTAssertGreaterThan(view.languageFormattingCount, before)
        let rendered = view.languageFormattingCount
        for _ in 0..<10 {
            view.setCompactPresentation(true)
            view.layoutSubtreeIfNeeded()
        }
        await drain()
        XCTAssertEqual(view.languageFormattingCount, rendered)
    }
}
