import AppKit
import Foundation
import LauncherLocalization
import XCTest
@testable import AppGridUI
@testable import PagingUI

/// Actual native views stay unshown. Execution belongs to Main's serial gate.
@MainActor
final class StatusLanguageConsumersTests: XCTestCase {
    private let states: [AppGridUIState] = [
        .loading, .ready, .empty, .partialFailure, .refreshing, .noResults
    ]

    private let expectedText: [(InterfaceLanguage, [String])] = [
        (.english, [
            "Loading application catalog…", "Application catalog ready",
            "No applications found", "Some app sources or items could not be read",
            "Refreshing application catalog…", "No applications match the search"
        ]),
        (.simplifiedChinese, [
            "正在加载应用列表…", "应用列表已就绪", "未找到应用",
            "部分应用来源或项目无法读取", "正在刷新应用列表…", "没有符合搜索条件的应用"
        ]),
        (.japanese, [
            "アプリ一覧を読み込み中…", "アプリ一覧の準備ができました",
            "アプリが見つかりません", "一部のアプリの取得元または項目を読み取れませんでした",
            "アプリ一覧を更新中…", "検索条件に一致するアプリがありません"
        ])
    ]

    private struct StaticResources: LocalizationResourceProviding {
        let data: Data?
        func localizableStringsData(for language: InterfaceLanguage) -> Data? { data }
    }

    private func makeView(strings: LocalizedStrings? = nil) -> AppGridStatusView {
        AppGridStatusView(frame: NSRect(x: 0, y: 0, width: 400, height: 180), strings: strings)
    }

    private func spinner(in view: AppGridStatusView) throws -> NSProgressIndicator {
        try XCTUnwrap(view.subviews.compactMap { $0 as? NSProgressIndicator }.first)
    }

    private func label(in view: AppGridStatusView) throws -> NSTextField {
        try XCTUnwrap(view.subviews.compactMap { $0 as? NSTextField }.first)
    }

    func testAllSixStatesRenderActualThreeLanguageSnapshotsOnRetainedView() async throws {
        let view = makeView()
        defer { view.teardown() }
        let textLabel = try label(in: view)
        let indicator = try spinner(in: view)
        for (language, texts) in expectedText {
            view.relabel(strings: LocalizedStrings(language: language))
            for (index, state) in states.enumerated() {
                view.update(state: state)
                XCTAssertEqual(view.state, state)
                await drainDeferredPresentationTurns()
                XCTAssertEqual(view.statusText, texts[index])
                XCTAssertEqual(view.accessibilityLabel(), texts[index])
                XCTAssertEqual(view.isHidden, state == .ready)
                XCTAssertEqual(view.isAccessibilityElement(), state != .ready)
                XCTAssertEqual(indicator.isHidden, !state.isBusy)
                XCTAssertFalse(textLabel.isAccessibilityElement())
                XCTAssertFalse(indicator.isAccessibilityElement())
                XCTAssertTrue(view.subviews.contains { $0 === textLabel })
                XCTAssertTrue(view.subviews.contains { $0 === indicator })
                XCTAssertFalse(view.statusText.contains("/Applications"))
                XCTAssertFalse(view.statusText.contains("fixture"))
                XCTAssertFalse(view.statusText.contains(".app"))
            }
        }
    }

    func testExplicitNilSnapshotUsesSafeEnglishWithoutDefaultResourceConstruction() async {
        let view = makeView(strings: nil)
        defer { view.teardown() }
        XCTAssertEqual(view.languageFormattingCount, 0)
        XCTAssertEqual(view.statusText, "")
        for (state, key) in zip(states, CatalogTextKey.allCases) {
            view.update(state: state)
            await drainDeferredPresentationTurns()
            XCTAssertEqual(view.statusText, key.englishFallback)
            XCTAssertEqual(view.accessibilityLabel(), key.englishFallback)
            XCTAssertNotEqual(view.statusText, key.rawValue)
        }
    }

    func testMissingSnapshotResourcesStillRenderSafeEnglishOnActualView() async {
        let strings = LocalizedStrings(language: .japanese, resourceProvider: StaticResources(data: nil))
        let view = makeView(strings: strings)
        defer { view.teardown() }
        for (state, key) in zip(states, CatalogTextKey.allCases) {
            view.update(state: state)
            await drainDeferredPresentationTurns()
            XCTAssertEqual(view.statusText, key.englishFallback)
        }
    }

    func testEqualStateRelabelRefreshesTextAccessibilityAndKeepsControls() async throws {
        let view = makeView(strings: LocalizedStrings(language: .english))
        defer { view.teardown() }
        view.update(state: .partialFailure)
        await drainDeferredPresentationTurns()
        let textLabel = try label(in: view)
        let indicator = try spinner(in: view)
        let frame = view.frame
        for (language, texts) in expectedText {
            let count = view.languageFormattingCount
            view.update(state: .partialFailure)
            view.relabel(strings: LocalizedStrings(language: language))
            XCTAssertEqual(view.state, .partialFailure)
            XCTAssertEqual(view.languageFormattingCount, count)
            await drainDeferredPresentationTurns()
            XCTAssertEqual(view.languageFormattingCount, count + 1)
            XCTAssertEqual(view.statusText, texts[3])
            XCTAssertEqual(view.accessibilityLabel(), texts[3])
            XCTAssertEqual(view.frame, frame)
            XCTAssertTrue(view.subviews.contains { $0 === textLabel })
            XCTAssertTrue(view.subviews.contains { $0 === indicator })
            XCTAssertTrue(indicator.isHidden)
        }
    }

    func testConstructionAndUpdatesDeferTextSpinnerAndAccessibilityTogether() async throws {
        let view = makeView(strings: LocalizedStrings(language: .english))
        defer { view.teardown() }
        let indicator = try spinner(in: view)
        XCTAssertEqual(view.state, .loading)
        XCTAssertEqual(view.languageFormattingCount, 0)
        XCTAssertEqual(view.statusText, "")
        XCTAssertTrue(indicator.isHidden)
        XCTAssertTrue(view.isHidden)
        XCTAssertFalse(view.isAccessibilityElement())
        await drainDeferredPresentationTurns()
        let oldText = view.statusText
        let count = view.languageFormattingCount
        XCTAssertFalse(indicator.isHidden)
        XCTAssertFalse(view.isHidden)
        view.update(state: .ready)
        view.relabel(strings: LocalizedStrings(language: .japanese))
        XCTAssertEqual(view.state, .ready)
        XCTAssertEqual(view.statusText, oldText)
        XCTAssertEqual(view.accessibilityLabel(), oldText)
        XCTAssertEqual(view.languageFormattingCount, count)
        XCTAssertFalse(indicator.isHidden)
        XCTAssertFalse(view.isHidden)
        await drainDeferredPresentationTurns()
        XCTAssertEqual(view.languageFormattingCount, count + 1)
        XCTAssertEqual(view.statusText, "アプリ一覧の準備ができました")
        XCTAssertEqual(view.accessibilityLabel(), view.statusText)
        XCTAssertTrue(indicator.isHidden)
        XCTAssertTrue(view.isHidden)
        XCTAssertFalse(view.isAccessibilityElement())
    }

    func testCoalescedLatestStateAndLanguageWinWithoutStaleBusyPresentation() async throws {
        let view = makeView(strings: LocalizedStrings(language: .english))
        defer { view.teardown() }
        view.update(state: .refreshing)
        view.relabel(strings: LocalizedStrings(language: .simplifiedChinese))
        view.update(state: .partialFailure)
        view.relabel(strings: LocalizedStrings(language: .english))
        view.update(state: .ready)
        view.relabel(strings: LocalizedStrings(language: .japanese))
        view.update(state: .noResults)
        XCTAssertEqual(view.state, .noResults)
        XCTAssertEqual(view.languageFormattingCount, 0)
        await drainDeferredPresentationTurns()
        XCTAssertEqual(view.languageFormattingCount, 1)
        XCTAssertEqual(view.statusText, "検索条件に一致するアプリがありません")
        XCTAssertEqual(view.accessibilityLabel(), view.statusText)
        XCTAssertTrue(try spinner(in: view).isHidden)
        XCTAssertFalse(view.isHidden)
        await drainDeferredPresentationTurns()
        XCTAssertEqual(view.languageFormattingCount, 1)
    }

    func testTeardownInvalidatesInitialQueuedRenderAndIsTerminal() async throws {
        let view = makeView(strings: LocalizedStrings(language: .japanese))
        view.update(state: .empty)
        view.teardown()
        view.relabel(strings: LocalizedStrings(language: .english))
        view.update(state: .refreshing)
        view.teardown()
        await drainDeferredPresentationTurns()
        XCTAssertEqual(view.state, .empty)
        XCTAssertEqual(view.languageFormattingCount, 0)
        XCTAssertEqual(view.statusText, "")
        XCTAssertTrue(view.isHidden)
        XCTAssertTrue(try spinner(in: view).isHidden)
        XCTAssertFalse(view.isAccessibilityElement())
    }

    func testTeardownCannotBeOverwrittenByQueuedRelabelOnExternallyRetainedView() async throws {
        let view = makeView(strings: LocalizedStrings(language: .english))
        await drainDeferredPresentationTurns()
        let text = view.statusText
        let accessibilityText = view.accessibilityLabel()
        let count = view.languageFormattingCount
        view.relabel(strings: LocalizedStrings(language: .japanese))
        view.update(state: .noResults)
        view.teardown()
        await drainDeferredPresentationTurns()
        XCTAssertEqual(view.languageFormattingCount, count)
        XCTAssertEqual(view.statusText, text)
        XCTAssertEqual(view.accessibilityLabel(), accessibilityText)
        XCTAssertTrue(try spinner(in: view).isHidden)
        XCTAssertTrue(view.isHidden)
        XCTAssertFalse(view.isAccessibilityElement())
    }

    func testActualSurfaceFrameCallbackStagesStatusWithoutStaticStringRendering() async throws {
        let english = LocalizedStrings(language: .english)
        let japanese = LocalizedStrings(language: .japanese)
        let view = makeView(strings: english)
        let surface = PagingSurface(pageCount: 3, labMode: false)
        surface.frameDriver = nil
        defer { surface.teardown(); view.teardown() }
        await drainDeferredPresentationTurns()
        let indicator = try spinner(in: view)
        let count = view.languageFormattingCount
        let text = view.statusText
        var frames = 0
        surface.onAnimationFrame = { _ in
            frames += 1
            view.update(state: .partialFailure)
            view.relabel(strings: japanese)
            view.layout()
            XCTAssertEqual(view.languageFormattingCount, count)
            XCTAssertEqual(view.statusText, text)
            XCTAssertEqual(view.accessibilityLabel(), text)
            XCTAssertFalse(indicator.isHidden)
        }
        for _ in 0..<120 { surface.advanceFrame(deltaTime: 1.0 / 60) }
        XCTAssertEqual(frames, 120)
        XCTAssertEqual(view.state, .partialFailure)
        XCTAssertEqual(view.languageFormattingCount, count)
        await drainDeferredPresentationTurns()
        XCTAssertEqual(view.languageFormattingCount, count + 1)
        XCTAssertEqual(view.statusText, "一部のアプリの取得元または項目を読み取れませんでした")
        XCTAssertTrue(indicator.isHidden)
    }

    func testStaticEqualStateAndLayoutTurnsDoNotRenderAgain() async {
        let view = makeView()
        defer { view.teardown() }
        view.update(state: .empty)
        await drainDeferredPresentationTurns()
        let count = view.languageFormattingCount
        for _ in 0..<120 {
            view.update(state: .empty)
            view.layout()
        }
        await drainDeferredPresentationTurns()
        XCTAssertEqual(view.languageFormattingCount, count)
        XCTAssertEqual(view.statusText, "No applications found")
    }

    func testLongTextRewrapsAtCurrentBoundsAndStaysInsideCompactBounds() async throws {
        let longText = String(repeating: "Some app sources or items could not be read. 日本語 中文 ", count: 8)
        let data = try PropertyListSerialization.data(
            fromPropertyList: [CatalogTextKey.partialFailure.rawValue: longText],
            format: .xml, options: 0
        )
        let strings = LocalizedStrings(language: .english, resourceProvider: StaticResources(data: data))
        let view = makeView(strings: strings)
        defer { view.teardown() }
        view.update(state: .partialFailure)
        await drainDeferredPresentationTurns()
        let textLabel = try label(in: view)
        XCTAssertEqual(view.statusText, longText)
        view.frame.size = NSSize(width: 260, height: 600)
        view.layout()
        let narrowHeight = textLabel.frame.height
        XCTAssertGreaterThan(narrowHeight, 20)
        XCTAssertEqual(textLabel.maximumNumberOfLines, 0)
        XCTAssertTrue(view.bounds.contains(textLabel.frame))
        view.frame.size.width = 780
        view.layout()
        XCTAssertLessThan(textLabel.frame.height, narrowHeight)
        XCTAssertTrue(view.bounds.contains(textLabel.frame))
        let count = view.languageFormattingCount
        view.frame.size = NSSize(width: 110, height: 64)
        view.update(state: .refreshing)
        await drainDeferredPresentationTurns()
        view.layout()
        XCTAssertEqual(view.languageFormattingCount, count + 1)
        XCTAssertTrue(view.bounds.contains(textLabel.frame))
        XCTAssertTrue(view.bounds.contains(try spinner(in: view).frame))
        XCTAssertLessThanOrEqual(textLabel.frame.maxY, try spinner(in: view).frame.minY)
    }

    func testShippedFailureAndNoResultsTextWrapInAllThreeLanguages() async throws {
        let view = makeView()
        defer { view.teardown() }
        let textLabel = try label(in: view)
        for (language, _) in expectedText {
            view.relabel(strings: LocalizedStrings(language: language))
            for state in [AppGridUIState.partialFailure, .noResults] {
                view.update(state: state)
                await drainDeferredPresentationTurns()
                let count = view.languageFormattingCount
                view.frame.size = NSSize(width: 80, height: 240)
                view.layout()
                let narrowHeight = textLabel.frame.height
                XCTAssertGreaterThan(narrowHeight, 20)
                XCTAssertTrue(view.bounds.contains(textLabel.frame))
                view.frame.size.width = 720
                view.layout()
                XCTAssertLessThan(textLabel.frame.height, narrowHeight)
                XCTAssertTrue(view.bounds.contains(textLabel.frame))
                XCTAssertEqual(view.languageFormattingCount, count)
            }
        }
    }

    func testNativeHitTestingPassesLabelSpinnerAndBlankClicksToContainer() async throws {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 180))
        let view = makeView()
        defer { view.teardown() }
        root.addSubview(view)
        await drainDeferredPresentationTurns()
        view.layout()
        let textLabel = try label(in: view)
        let indicator = try spinner(in: view)
        let points = [
            NSPoint(x: 4, y: 4),
            NSPoint(x: textLabel.frame.midX, y: textLabel.frame.midY),
            NSPoint(x: indicator.frame.midX, y: indicator.frame.midY)
        ]
        for point in points {
            XCTAssertNil(view.hitTest(point))
            XCTAssertTrue(root.hitTest(point) === root)
        }
        XCTAssertFalse(view.acceptsFirstResponder)
        XCTAssertFalse(view.becomeFirstResponder())
        XCTAssertFalse(textLabel.isSelectable)
        XCTAssertFalse(textLabel.isEditable)
        view.update(state: .ready)
        await drainDeferredPresentationTurns()
        XCTAssertTrue(view.isHidden)
        XCTAssertTrue(root.hitTest(NSPoint(x: 200, y: 90)) === root)
    }
}
