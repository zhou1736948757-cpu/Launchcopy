import AppKit
import Foundation
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp
@testable import PagingUI

/// Self-contained unshown-view code gates. No application, window, real timer,
/// catalog, icon pipeline, disk resources or shared test support is needed.
final class ActionFeedbackNoticeTests: XCTestCase {
    func testSixStableKeysAndEnglishFallbacks() throws {
        try TestMain.run {
            XCTAssertEqual(Set(ActionFeedbackTextKey.allCases.map(\.rawValue)), Set([
                "actionFeedback.launchFailed", "actionFeedback.launchMissing",
                "actionFeedback.launchUnavailable", "actionFeedback.finderMissing",
                "actionFeedback.finderUnavailable", "actionFeedback.feedbackAccessibility"
            ]))
            for key in ActionFeedbackTextKey.allCases {
                XCTAssertEqual(key.englishFallback, FeedbackExpectations.values(for: .english)[key])
            }
        }
    }

    func testOptionalInitialSnapshotAndDefaultInitializerDoNoPresentationWork() throws {
        try TestMain.run {
            let provider = FeedbackSnapshotProvider()
            let strings = LocalizedStrings(language: .japanese, resourceProvider: provider)
            let reads = provider.readCount
            let time = NoticeTestTime()
            let view = makeView(time, strings: strings)
            let fallback = ActionFeedbackNoticeView(frame: .zero)
            defer { view.teardown(); fallback.teardown() }
            XCTAssertTrue(view.isHidden)
            XCTAssertTrue(fallback.isHidden)
            XCTAssertEqual(view.statusText, "")
            XCTAssertEqual(view.languageFormattingCount, 0)
            XCTAssertEqual(view.sizingMeasurementCount, 0)
            XCTAssertEqual(fallback.languageFormattingCount, 0)
            XCTAssertEqual(time.activeCount, 0)
            XCTAssertEqual(provider.readCount, reads)
            XCTAssertEqual(view.subviews.count, 1)
            XCTAssertNil(view.window)
        }
    }

    func testActualLabelAndAccessibilityUseAllFiveReasonsInAllThreeLanguages() throws {
        try TestMain.run {
            let time = NoticeTestTime(), provider = FeedbackSnapshotProvider()
            let view = makeView(time)
            defer { view.teardown() }
            let label = try XCTUnwrap(view.subviews.first as? NSTextField)
            let identity = ObjectIdentifier(label)
            for language in InterfaceLanguage.allCases {
                let strings = LocalizedStrings(language: language, resourceProvider: provider)
                let reads = provider.readCount
                for key in ActionFeedbackTextKey.allCases where key != .feedbackAccessibility {
                    let count = view.languageFormattingCount
                    view.show(reason: key, strings: strings)
                    XCTAssertEqual(view.languageFormattingCount, count)
                    time.flush()
                    XCTAssertFalse(view.isHidden)
                    XCTAssertEqual(view.reason, key)
                    XCTAssertEqual(label.stringValue, FeedbackExpectations.values(for: language)[key])
                    XCTAssertEqual(view.accessibilityValue() as? String, label.stringValue)
                    XCTAssertEqual(view.accessibilityLabel(),
                        FeedbackExpectations.values(for: language)[.feedbackAccessibility])
                    XCTAssertEqual(view.accessibilityRole(), .staticText)
                    XCTAssertTrue(view.isAccessibilityElement())
                    XCTAssertFalse(label.isAccessibilityElement())
                    XCTAssertFalse(label.isEditable)
                    XCTAssertFalse(label.isSelectable)
                    XCTAssertTrue(label.refusesFirstResponder)
                    XCTAssertEqual(ObjectIdentifier(view.subviews[0]), identity)
                    XCTAssertEqual(view.languageFormattingCount, count + 2)
                    XCTAssertEqual(time.activeCount, 1)
                    XCTAssertEqual(provider.readCount, reads, "Only snapshot construction consumes a provider")
                }
            }
        }
    }

    func testMissingResourcesUseSafeEnglishAndAccessibilityKeyCannotShowAnError() throws {
        try TestMain.run {
            let time = NoticeTestTime(), view = makeView(time)
            defer { view.teardown() }
            let strings = LocalizedStrings(language: .japanese, resourceProvider: AbsentFeedbackResources())
            view.show(reason: .feedbackAccessibility, strings: strings)
            XCTAssertNil(view.reason)
            XCTAssertEqual(time.activeCount, 0)
            for key in ActionFeedbackTextKey.allCases where key != .feedbackAccessibility {
                view.show(reason: key, strings: strings)
                time.flush()
                XCTAssertEqual(view.statusText, key.englishFallback)
                XCTAssertEqual(view.accessibilityLabel(), ActionFeedbackTextKey.feedbackAccessibility.englishFallback)
            }
        }
    }

    func testSixSecondMonotonicBoundaryClearsTextAndDoesNotReviveOnRelabel() throws {
        try TestMain.run {
            let time = NoticeTestTime(), view = makeView(time)
            defer { view.teardown() }
            let strings = snapshot(.english)
            view.show(reason: .launchFailed, strings: strings)
            time.flush()
            XCTAssertEqual(view.expirationDeadline, 106)
            time.now = 105.999
            time.wallTime = -100_000 // Wall time is intentionally not an input to the view.
            view.relabel(strings: snapshot(.japanese)); time.flush()
            XCTAssertFalse(view.isHidden)
            XCTAssertEqual(view.expirationDeadline, 106)
            time.now = 106
            let formats = view.languageFormattingCount
            time.runTurn() // Timer only stages expiry presentation.
            XCTAssertEqual(view.languageFormattingCount, formats)
            XCTAssertFalse(view.isHidden)
            time.flush()
            assertCleared(view)
            for language in InterfaceLanguage.allCases {
                view.relabel(strings: snapshot(language))
                view.applyMaterialPolicy(reduceTransparency: true, increaseContrast: true)
                view.frame.size = NSSize(width: 120, height: 50)
                view.layout(); time.flush()
                assertCleared(view)
            }
            XCTAssertEqual(view.languageFormattingCount, formats)
            XCTAssertEqual(time.activeCount, 0)
        }
    }

    func testLatestErrorWinsBeforeRenderAndSameReasonRestartsOnlyForANewShow() throws {
        try TestMain.run {
            let time = NoticeTestTime(), view = makeView(time)
            defer { view.teardown() }
            view.show(reason: .launchFailed, strings: snapshot(.english))
            time.now = 101
            view.show(reason: .finderMissing, strings: snapshot(.japanese))
            XCTAssertEqual(time.activeCount, 1)
            time.flush()
            XCTAssertEqual(view.reason, .finderMissing)
            XCTAssertEqual(view.statusText, FeedbackExpectations.values(for: .japanese)[.finderMissing])
            XCTAssertEqual(view.expirationDeadline, 107)
            let oldExpiry = try XCTUnwrap(time.activeIDs.first)
            time.now = 104
            view.show(reason: .finderMissing, strings: snapshot(.english))
            time.deliver(oldExpiry) // A cancelled old timer is deliberately delivered.
            time.flush()
            XCTAssertEqual(view.expirationDeadline, 110)
            XCTAssertEqual(view.statusText, ActionFeedbackTextKey.finderMissing.englishFallback)
            time.now = 107; time.flush()
            XCTAssertFalse(view.isHidden)
            time.now = 110; time.flush()
            assertCleared(view)
        }
    }

    func testLateFirstRenderNeverPresentsAnAlreadyExpiredError() throws {
        try TestMain.run {
            let time = NoticeTestTime(), view = makeView(time)
            defer { view.teardown() }
            var presentations = 0
            view.onPresentationApplied = { presentations += 1 }
            view.show(reason: .launchMissing, strings: snapshot(.english))
            time.now = 120
            time.flush()
            assertCleared(view)
            XCTAssertEqual(view.languageFormattingCount, 0)
            XCTAssertEqual(view.sizingMeasurementCount, 0)
            XCTAssertEqual(presentations, 1)
            XCTAssertEqual(time.activeCount, 0)
        }
    }

    func testRelabelResizeAndMaterialKeepTheSameDeadlineAndTimer() throws {
        try TestMain.run {
            let time = NoticeTestTime(), view = makeView(time)
            defer { view.teardown() }
            view.show(reason: .launchUnavailable, strings: snapshot(.english)); time.flush()
            let expiry = time.activeIDs
            time.now = 104
            for language in InterfaceLanguage.allCases {
                view.relabel(strings: snapshot(language))
                view.applyMaterialPolicy(reduceTransparency: true, increaseContrast: false)
                view.frame = NSRect(x: 0, y: 0, width: 110, height: 64)
                view.layout(); time.flush()
                XCTAssertEqual(view.expirationDeadline, 106)
                XCTAssertEqual(time.activeIDs, expiry)
            }
            time.now = 106
            // Relabel must observe expiry even when the timer was delayed by the scheduler.
            view.relabel(strings: snapshot(.japanese))
            let count = view.languageFormattingCount
            time.flush()
            assertCleared(view)
            XCTAssertEqual(view.languageFormattingCount, count)
        }
    }

    func testDuplicateAndEarlyTimerDeliveriesCoalesceAndNeverExtendDeadline() throws {
        try TestMain.run {
            let time = NoticeTestTime(), view = makeView(time)
            defer { view.teardown() }
            view.show(reason: .finderUnavailable, strings: snapshot(.english)); time.flush()
            let expiry = try XCTUnwrap(time.activeIDs.first)
            time.now = 103
            time.deliver(expiry); time.deliver(expiry)
            let applies = view.presentationApplyCount
            time.flush()
            XCTAssertEqual(view.presentationApplyCount, applies + 1)
            XCTAssertEqual(view.expirationDeadline, 106)
            XCTAssertEqual(time.activeCount, 1)
            let replacement = try XCTUnwrap(time.activeIDs.first)
            XCTAssertNotEqual(replacement, expiry)
            time.now = 106
            time.deliver(replacement); time.deliver(replacement); time.deliver(expiry)
            time.flush()
            assertCleared(view)
            XCTAssertEqual(time.activeCount, 0)
        }
    }

    func testClearRejectsOldPresentationAndTimerButAllowsFreshError() throws {
        try TestMain.run {
            let time = NoticeTestTime(), view = makeView(time)
            defer { view.teardown() }
            view.show(reason: .launchFailed, strings: snapshot(.english))
            let oldPresentation = try XCTUnwrap(time.activeIDs.first)
            view.clear()
            view.relabel(strings: snapshot(.japanese))
            time.deliver(oldPresentation); time.flush()
            assertCleared(view)
            XCTAssertEqual(view.languageFormattingCount, 0)
            view.show(reason: .launchMissing, strings: snapshot(.english)); time.flush()
            let oldExpiry = try XCTUnwrap(time.activeIDs.first)
            view.clear(); view.clear(); time.flush()
            assertCleared(view)
            time.now = 102
            view.show(reason: .finderUnavailable, strings: snapshot(.japanese))
            time.deliver(oldExpiry); time.flush()
            XCTAssertEqual(view.reason, .finderUnavailable)
            XCTAssertEqual(view.expirationDeadline, 108)
        }
    }

    @MainActor
    func testTeardownRejectsEveryStaleCallbackAndFutureAPIAndDoesNotRetainView() async throws {
        weak var releasedView: ActionFeedbackNoticeView?
        try autoreleasepool {
            let time = NoticeTestTime()
            var view: ActionFeedbackNoticeView? = makeView(time)
            releasedView = view
            let strings = snapshot(.english)
            view?.show(reason: .launchFailed, strings: strings); time.flush()
            var applied = 0
            view?.onPresentationApplied = { applied += 1 }
            view?.relabel(strings: snapshot(.japanese))
            let callbacks = time.activeIDs
            let formats = view?.languageFormattingCount
            view?.teardown(); view?.teardown()
            view?.show(reason: .finderMissing, strings: strings)
            view?.relabel(strings: strings); view?.clear()
            view?.applyMaterialPolicy(reduceTransparency: true, increaseContrast: true)
            view?.layout()
            for id in callbacks { time.deliver(id); time.deliver(id) }
            time.now = 120; time.flush()
            assertCleared(try XCTUnwrap(view))
            XCTAssertEqual(view?.languageFormattingCount, formats)
            XCTAssertEqual(applied, 0)
            XCTAssertNil(view?.onPresentationApplied)
            XCTAssertEqual(time.activeCount, 0)
            view = nil
        }
        // AppKit/AX may retain autoreleased helpers until the native main-turn boundary.
        await drainDeferredPresentationTurns()
        XCTAssertNil(releasedView)
    }

    func testDetachClearsAndDropsObsoleteWorkWithoutCreatingAWindow() throws {
        try TestMain.run {
            let root = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
            let time = NoticeTestTime(), view = makeView(time)
            defer { view.teardown() }
            root.addSubview(view)
            view.show(reason: .launchMissing, strings: snapshot(.english)); time.flush()
            let expiry = try XCTUnwrap(time.activeIDs.first)
            view.removeFromSuperview()
            view.relabel(strings: snapshot(.japanese))
            time.deliver(expiry); time.flush()
            assertCleared(view)
            XCTAssertNil(view.superview)
            XCTAssertNil(root.window)
        }
    }

    func testStagedFrameStackWorkHasZeroTextAXMeasurementAndMaterialApplies() throws {
        try TestMain.run {
            let time = NoticeTestTime(), view = makeView(time)
            defer { view.teardown() }
            let strings = snapshot(.english)
            var callbacks = 0
            view.onPresentationApplied = { callbacks += 1 }
            for index in 0..<120 {
                view.show(reason: index % 2 == 0 ? .launchFailed : .finderMissing, strings: strings)
                view.relabel(strings: strings)
                view.applyMaterialPolicy(reduceTransparency: index % 2 == 0, increaseContrast: true)
                view.frame.size = NSSize(width: CGFloat(100 + index), height: 60)
                _ = view.requiredPresentationHeight(forWidth: CGFloat(100 + index))
                view.layout()
                XCTAssertEqual(view.languageFormattingCount, 0)
                XCTAssertEqual(view.sizingMeasurementCount, 0)
                XCTAssertEqual(view.materialApplyCount, 0)
                XCTAssertEqual(view.presentationApplyCount, 0)
                XCTAssertEqual(view.statusText, "")
                XCTAssertNil(view.accessibilityLabel())
                XCTAssertEqual(callbacks, 0)
                XCTAssertEqual(time.activeCount, 1)
            }
            time.flush()
            XCTAssertEqual(view.reason, .finderMissing)
            XCTAssertEqual(view.languageFormattingCount, 2)
            XCTAssertEqual(view.sizingMeasurementCount, 1)
            XCTAssertEqual(view.materialApplyCount, 1)
            XCTAssertEqual(callbacks, 1)
            XCTAssertEqual(time.activeCount, 1)
        }
    }

    func testActualAdvanceFrameCallbackDefersFeedbackPresentationAndLookupWork() throws {
        try TestMain.run {
            let time = NoticeTestTime(), provider = FeedbackSnapshotProvider()
            let strings = LocalizedStrings(language: .japanese, resourceProvider: provider)
            let reads = provider.readCount
            let view = makeView(time)
            let surface = PagingSurface(pageCount: 3, itemsPerPage: 8)
            surface.frameDriver = nil
            surface.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
            defer { surface.onAnimationFrame = nil; surface.teardown(); view.teardown() }
            var calls = 0
            surface.onAnimationFrame = { _ in
                MainActor.assumeIsolated {
                    calls += 1
                    view.show(reason: .launchFailed, strings: strings)
                    view.relabel(strings: strings)
                    view.applyMaterialPolicy(reduceTransparency: true, increaseContrast: true)
                    _ = view.requiredPresentationHeight(forWidth: 180)
                    view.layout()
                }
            }
            XCTAssertTrue(surface.requestPage(2, timestamp: 100))
            for _ in 0..<120 {
                surface.advanceFrame(deltaTime: 1.0 / 60.0)
                XCTAssertEqual(view.languageFormattingCount, 0)
                XCTAssertEqual(view.sizingMeasurementCount, 0)
                XCTAssertEqual(view.materialApplyCount, 0)
                XCTAssertEqual(view.presentationApplyCount, 0)
                XCTAssertEqual(provider.readCount, reads)
            }
            XCTAssertEqual(calls, 120)
            time.flush()
            XCTAssertEqual(view.languageFormattingCount, 2)
            XCTAssertEqual(view.sizingMeasurementCount, 1)
            XCTAssertEqual(view.presentationApplyCount, 1)
            XCTAssertEqual(view.statusText, FeedbackExpectations.values(for: .japanese)[.launchFailed])
            XCTAssertEqual(provider.readCount, reads)
        }
    }

    func testCachedSizingFitsFullLinesAllLanguagesAndSmallBoundsWithoutFormattingOnLayout() throws {
        try TestMain.run {
            let time = NoticeTestTime(), view = makeView(time)
            defer { view.teardown() }
            let label = try XCTUnwrap(view.subviews.first as? NSTextField)
            for language in InterfaceLanguage.allCases {
                view.show(reason: .finderMissing, strings: snapshot(language)); time.flush()
                for width in [CGFloat(400), 180, 80, 0] {
                    let count = view.languageFormattingCount
                    let measurements = view.sizingMeasurementCount
                    _ = view.requiredPresentationHeight(forWidth: width)
                    XCTAssertEqual(view.sizingMeasurementCount, measurements)
                    time.flush()
                    let height = view.requiredPresentationHeight(forWidth: width)
                    XCTAssertGreaterThanOrEqual(height, 36)
                    view.frame = NSRect(x: 0, y: 0, width: width, height: height)
                    view.layout(); time.flush()
                    assertInside(label.frame, bounds: view.bounds)
                    if width > 0 {
                        let measured = try XCTUnwrap(label.cell).cellSize(forBounds: NSRect(
                            x: 0, y: 0, width: label.frame.width, height: CGFloat.greatestFiniteMagnitude)).height
                        XCTAssertGreaterThanOrEqual(label.frame.height + 0.001, measured)
                    }
                    XCTAssertEqual(view.languageFormattingCount, count)
                    XCTAssertEqual(view.expirationDeadline, 106)
                }
                for size in [NSSize.zero, NSSize(width: 1, height: 1), NSSize(width: 12, height: 8)] {
                    view.frame.size = size; view.layout(); time.flush()
                    assertInside(label.frame, bounds: view.bounds)
                }
            }
        }
    }

    func testMaterialVariantsKeepOnePassiveLabelAndNoFocusOrClickStealing() throws {
        try TestMain.run {
            let time = NoticeTestTime(), view = makeView(time)
            defer { view.teardown() }
            view.show(reason: .launchFailed, strings: snapshot(.english)); time.flush()
            let labelID = ObjectIdentifier(try XCTUnwrap(view.subviews.first))
            let formats = view.languageFormattingCount
            for transparency in [false, true] {
                for contrast in [false, true] {
                    view.applyMaterialPolicy(reduceTransparency: transparency, increaseContrast: contrast)
                    time.flush()
                    let layer = try XCTUnwrap(view.layer)
                    XCTAssertEqual(try XCTUnwrap(layer.backgroundColor).alpha, transparency ? 1 : 0.7, accuracy: 0.001)
                    XCTAssertEqual(layer.isOpaque, transparency)
                    XCTAssertEqual(layer.borderWidth, contrast ? 2 : 0)
                    XCTAssertEqual(layer.masksToBounds, true)
                    XCTAssertEqual(ObjectIdentifier(view.subviews[0]), labelID)
                    XCTAssertEqual(view.subviews.count, 1)
                    XCTAssertNil(view.hitTest(NSPoint(x: 10, y: 10)))
                    XCTAssertFalse(view.acceptsFirstResponder)
                    XCTAssertFalse(view.becomeFirstResponder())
                    XCTAssertEqual(view.languageFormattingCount, formats)
                    XCTAssertEqual(view.expirationDeadline, 106)
                }
            }
        }
    }
}

/// Synchronous XCTest methods explicitly enter the main actor before constructing AppKit.
private enum TestMain {
    static func run(_ body: @MainActor () throws -> Void) throws {
        if Thread.isMainThread {
            try MainActor.assumeIsolated { try body() }
        } else {
            try DispatchQueue.main.sync { try MainActor.assumeIsolated { try body() } }
        }
    }
}

@MainActor
private func makeView(_ time: NoticeTestTime, strings: LocalizedStrings? = nil) -> ActionFeedbackNoticeView {
    ActionFeedbackNoticeView(frame: NSRect(x: 0, y: 0, width: 320, height: 100), strings: strings,
        clock: { time.now }, scheduler: { delay, action in time.schedule(delay, action: action) })
}

private func snapshot(_ language: InterfaceLanguage) -> LocalizedStrings {
    LocalizedStrings(language: language, resourceProvider: FeedbackSnapshotProvider())
}

@MainActor
private func assertCleared(_ view: ActionFeedbackNoticeView,
                           file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(view.isHidden, file: file, line: line)
    XCTAssertNil(view.reason, file: file, line: line)
    XCTAssertNil(view.expirationDeadline, file: file, line: line)
    XCTAssertEqual(view.statusText, "", file: file, line: line)
    XCTAssertNil(view.accessibilityLabel(), file: file, line: line)
    XCTAssertNil(view.accessibilityValue(), file: file, line: line)
    XCTAssertFalse(view.isAccessibilityElement(), file: file, line: line)
    XCTAssertEqual(view.requiredPresentationHeight(forWidth: 320), 0, file: file, line: line)
}

private func assertInside(_ frame: NSRect, bounds: NSRect,
                          file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertGreaterThanOrEqual(frame.width, 0, file: file, line: line)
    XCTAssertGreaterThanOrEqual(frame.height, 0, file: file, line: line)
    XCTAssertGreaterThanOrEqual(frame.minX, bounds.minX - 0.001, file: file, line: line)
    XCTAssertGreaterThanOrEqual(frame.minY, bounds.minY - 0.001, file: file, line: line)
    XCTAssertLessThanOrEqual(frame.maxX, bounds.maxX + 0.001, file: file, line: line)
    XCTAssertLessThanOrEqual(frame.maxY, bounds.maxY + 0.001, file: file, line: line)
}

@MainActor
private final class NoticeTestTime {
    var now: TimeInterval = 100
    var wallTime: TimeInterval = 1_000
    private struct Job {
        let due: TimeInterval
        let action: @MainActor () -> Void
    }
    private var nextID = 0
    private var jobs: [Int: Job] = [:]
    private var active: Set<Int> = []
    var activeIDs: [Int] { active.sorted() }
    var activeCount: Int { active.count }

    func schedule(_ delay: TimeInterval, action: @escaping @MainActor () -> Void) -> ActionFeedbackNoticeView.Cancellation {
        nextID += 1
        let id = nextID
        jobs[id] = Job(due: now + delay, action: action)
        active.insert(id)
        return { [weak self] in _ = self?.active.remove(id) }
    }

    /// Keep delivered callbacks to adversarially replay cancelled/duplicate jobs.
    func deliver(_ id: Int) {
        active.remove(id)
        jobs[id]?.action()
    }

    func runTurn() {
        let due = activeIDs.filter { (jobs[$0]?.due ?? .infinity) <= now }
        for id in due { deliver(id) }
    }

    func flush(file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<20 {
            guard active.contains(where: { (jobs[$0]?.due ?? .infinity) <= now }) else { return }
            runTurn()
        }
        XCTFail("Deferred feedback did not converge within 20 turns", file: file, line: line)
    }
}

private struct AbsentFeedbackResources: LocalizationResourceProviding {
    func localizableStringsData(for language: InterfaceLanguage) -> Data? { nil }
}

/// Counts snapshot consumption without network/disk IO; mutable count is lock-protected.
private final class FeedbackSnapshotProvider: LocalizationResourceProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var reads = 0
    var readCount: Int { lock.lock(); defer { lock.unlock() }; return reads }

    func localizableStringsData(for language: InterfaceLanguage) -> Data? {
        lock.lock(); reads += 1; lock.unlock()
        let table = Dictionary(uniqueKeysWithValues: FeedbackExpectations.values(for: language).map { ($0.key.rawValue, $0.value) })
        return try? PropertyListSerialization.data(fromPropertyList: table, format: .xml, options: 0)
    }
}

private enum FeedbackExpectations {
    static func values(for language: InterfaceLanguage) -> [ActionFeedbackTextKey: String] {
        switch language {
        case .english:
            return [.launchFailed: "Could not open the app. Try again.",
                .launchMissing: "The app could not be found. Refresh the app list and try again.",
                .launchUnavailable: "The app is currently unavailable. Refresh the app list and try again.",
                .finderMissing: "The app could not be found. Refresh the app list before showing it in Finder.",
                .finderUnavailable: "The app is currently unavailable. Try showing it in Finder again later.",
                .feedbackAccessibility: "App action status"]
        case .simplifiedChinese:
            return [.launchFailed: "无法打开应用，请重试。",
                .launchMissing: "找不到应用，请刷新应用列表后重试。",
                .launchUnavailable: "应用暂时不可用，请刷新应用列表后重试。",
                .finderMissing: "找不到应用，请先刷新应用列表，再尝试在访达中显示。",
                .finderUnavailable: "应用暂时不可用，请稍后再尝试在访达中显示。",
                .feedbackAccessibility: "应用操作状态"]
        case .japanese:
            return [.launchFailed: "アプリを開けませんでした。もう一度お試しください。",
                .launchMissing: "アプリが見つかりません。アプリ一覧を更新してから、もう一度お試しください。",
                .launchUnavailable: "アプリは現在利用できません。アプリ一覧を更新してから、もう一度お試しください。",
                .finderMissing: "アプリが見つかりません。アプリ一覧を更新してから、Finderで表示してください。",
                .finderUnavailable: "アプリは現在利用できません。しばらくしてから、Finderでの表示をお試しください。",
                .feedbackAccessibility: "アプリの操作状況"]
        }
    }
}
