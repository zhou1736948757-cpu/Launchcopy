import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class PageDotsViewTests: XCTestCase {
    private func makeView(count: Int = 3, committed: Int = 0, enabled: Bool = true) -> PageDotsView {
        // Native performClick dispatches through NSApplication; no window is opened.
        _ = NSApplication.shared
        let view = PageDotsView(frame: NSRect(x: 0, y: 0, width: 360, height: 32))
        view.relabel(strings: LocalizedStrings(language: .simplifiedChinese))
        view.update(pageCount: count, committedPage: committed, isEnabled: enabled)
        view.layoutSubtreeIfNeeded()
        return view
    }

    private func buttons(_ view: PageDotsView) -> [NSButton] {
        view.subviews.compactMap { $0 as? NSButton }
    }

    private func dots(_ view: PageDotsView) -> [NSButton] {
        buttons(view).filter {
            !$0.isHidden && ($0.identifier?.rawValue.hasPrefix("launchcopy.chrome.page-dot.") ?? false)
        }.sorted { $0.tag < $1.tag }
    }

    private func windowButton(_ view: PageDotsView, next: Bool) throws -> NSButton {
        let suffix = next ? "next" : "previous"
        return try XCTUnwrap(buttons(view).first {
            $0.identifier?.rawValue == "launchcopy.chrome.page-window.\(suffix)"
        })
    }

    private func selectedPages(_ view: PageDotsView) -> [Int] {
        dots(view).filter { $0.state == .on }.map(\.tag)
    }

    func testEmptyOneAndNegativeCountsHideAndDisableEveryControl() {
        let view = makeView(count: 12)
        var requests: [Int] = []
        view.onRequestPage = { requests.append($0) }
        for count in [0, 1, -1, Int.min] {
            view.update(pageCount: count, committedPage: Int.max, isEnabled: true)
            XCTAssertTrue(view.isHidden)
            XCTAssertEqual(view.intrinsicContentSize, .zero)
            XCTAssertTrue(dots(view).isEmpty)
            XCTAssertTrue(buttons(view).allSatisfy { !$0.isEnabled })
            for button in buttons(view) { button.performClick(nil) }
        }
        XCTAssertTrue(requests.isEmpty)
    }

    func testVisibleCountAndAbsoluteIdentifiersAtBoundary() {
        let view = makeView(count: 9, committed: 8)
        XCTAssertFalse(view.isHidden)
        XCTAssertEqual(dots(view).map(\.tag), Array(0..<9))
        XCTAssertEqual(selectedPages(view), [8])
        XCTAssertEqual(dots(view).map { $0.identifier?.rawValue },
                       (0..<9).map { "launchcopy.chrome.page-dot.\($0)" })
        XCTAssertTrue(buttons(view).filter { !($0.identifier?.rawValue.hasPrefix("launchcopy.chrome.page-dot.") ?? false) }
            .allSatisfy(\.isHidden))
        view.update(pageCount: 10, committedPage: 9, isEnabled: true)
        XCTAssertEqual(dots(view).map(\.tag), Array(1..<10))
        XCTAssertEqual(buttons(view).filter { !$0.isHidden }.count, 11)
    }

    func testNativeNonadjacentClickEmitsExactlyOneRequestWithoutChangingSelection() throws {
        let view = makeView(count: 9, committed: 1)
        let button = try XCTUnwrap(dots(view).last)
        var requests: [Int] = []
        view.onRequestPage = { requests.append($0) }
        button.performClick(nil)
        XCTAssertEqual(requests, [8])
        XCTAssertEqual(selectedPages(view), [1])
        XCTAssertEqual(button.state, .off)
        XCTAssertTrue(button.refusesFirstResponder)
    }

    func testNativeSelectedPageClickAlwaysEmitsAndPreservesCommittedState() throws {
        let view = makeView(count: 5, committed: 2)
        let button = try XCTUnwrap(dots(view).first { $0.tag == 2 })
        var requests: [Int] = []
        view.onRequestPage = { requests.append($0) }
        button.performClick(nil)
        button.performClick(nil)
        XCTAssertEqual(requests, [2, 2])
        XCTAssertEqual(button.state, .on)
        XCTAssertEqual(selectedPages(view), [2])
    }

    func testAccessibilityPressRejectsHiddenStripAndRecoversWhenShown() throws {
        let view = makeView(count: 3, committed: 1)
        let selected = try XCTUnwrap(dots(view).first { $0.tag == 1 })
        var requests: [Int] = []
        view.onRequestPage = { requests.append($0) }
        view.isHidden = true
        XCTAssertFalse(selected.accessibilityPerformPress())
        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(selected.state, .on)
        view.isHidden = false
        XCTAssertTrue(selected.accessibilityPerformPress())
        XCTAssertEqual(requests, [1])
    }

    func testAccessibilityPressRejectsHiddenAncestorForDotsAndWindowControls() throws {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 100))
        let view = makeView(count: 30, committed: 0)
        root.addSubview(view)
        let target = try XCTUnwrap(dots(view).last)
        let next = try windowButton(view, next: true)
        let originalTags = dots(view).map(\.tag)
        var requests: [Int] = []
        view.onRequestPage = { requests.append($0) }
        root.isHidden = true
        XCTAssertFalse(target.accessibilityPerformPress())
        XCTAssertFalse(next.accessibilityPerformPress())
        XCTAssertTrue(requests.isEmpty)
        XCTAssertEqual(dots(view).map(\.tag), originalTags)
        root.isHidden = false
        XCTAssertTrue(target.accessibilityPerformPress())
        XCTAssertEqual(requests, [8])
    }

    func testAccessibilityPressUsesNativeActionAndHonorsOwnerDisablement() throws {
        let view = makeView(count: 3, committed: 1)
        let selected = try XCTUnwrap(dots(view).first { $0.tag == 1 })
        var requests: [Int] = []
        view.onRequestPage = { requests.append($0) }
        XCTAssertTrue(selected.accessibilityPerformPress())
        XCTAssertEqual(requests, [1])
        XCTAssertEqual(selectedPages(view), [1])
        view.update(pageCount: 3, committedPage: 1, isEnabled: false)
        _ = selected.accessibilityPerformPress()
        XCTAssertEqual(requests, [1])
    }

    func testCallbackMaySynchronouslyCommitWithoutSelectionBeingOverwritten() throws {
        let view = makeView(count: 9, committed: 0)
        let button = try XCTUnwrap(dots(view).last)
        var requests: [Int] = []
        view.onRequestPage = { [weak view] page in
            requests.append(page)
            view?.update(pageCount: 9, committedPage: page, isEnabled: true)
        }
        button.performClick(nil)
        XCTAssertEqual(requests, [8])
        XCTAssertEqual(selectedPages(view), [8])
    }

    func testNilCallbackStillRestoresSelection() throws {
        let view = makeView(count: 3, committed: 1)
        try XCTUnwrap(dots(view).first).performClick(nil)
        XCTAssertEqual(selectedPages(view), [1])
    }

    func testInactiveOrFolderOwnerDisablesDotsAndBothWindowControls() throws {
        let view = makeView(count: 30, committed: 15)
        let range = dots(view).map(\.tag)
        var requests: [Int] = []
        view.onRequestPage = { requests.append($0) }
        view.update(pageCount: 30, committedPage: 15, isEnabled: false)
        XCTAssertTrue(buttons(view).allSatisfy { !$0.isEnabled })
        for button in buttons(view) { button.performClick(nil) }
        XCTAssertEqual(dots(view).map(\.tag), range)
        XCTAssertEqual(selectedPages(view), [15])
        XCTAssertTrue(requests.isEmpty)
        view.update(pageCount: 30, committedPage: 15, isEnabled: true)
        try XCTUnwrap(dots(view).first).performClick(nil)
        XCTAssertEqual(requests, [range[0]])
    }

    func testCommittedPageClampsAgainstLatestCount() {
        let view = makeView(count: 100, committed: 99)
        view.update(pageCount: 3, committedPage: 99, isEnabled: true)
        XCTAssertEqual(selectedPages(view), [2])
        view.update(pageCount: 3, committedPage: Int.min, isEnabled: true)
        XCTAssertEqual(selectedPages(view), [0])
        view.update(pageCount: 3, committedPage: Int.max, isEnabled: true)
        XCTAssertEqual(selectedPages(view), [2])
    }

    func testNativeActionDefensivelyClampsStaleAbsoluteTargetAgainstCurrentCount() throws {
        let view = makeView(count: 100, committed: 99)
        view.update(pageCount: 3, committedPage: 2, isEnabled: true)
        let button = try XCTUnwrap(dots(view).first)
        var requests: [Int] = []
        view.onRequestPage = { requests.append($0) }
        // Model a previously captured absolute target arriving after count replacement.
        button.tag = Int.max
        button.performClick(nil)
        button.tag = Int.min
        button.performClick(nil)
        XCTAssertEqual(requests, [2, 0])
        XCTAssertEqual(dots(view).map(\.tag), [0, 1, 2])
        XCTAssertEqual(selectedPages(view), [2])
    }

    func testRetainedHiddenButtonCannotDispatchAfterCountShrink() throws {
        let view = makeView(count: 9)
        let oldLast = try XCTUnwrap(dots(view).last)
        var requests: [Int] = []
        view.onRequestPage = { requests.append($0) }
        view.update(pageCount: 2, committedPage: 0, isEnabled: true)
        oldLast.performClick(nil)
        XCTAssertTrue(requests.isEmpty)
        XCTAssertTrue(oldLast.isHidden)
        XCTAssertFalse(oldLast.isEnabled)
    }

    func testIntMaxCountRemainsBoundedAndLabelsAvoidOverflow() async throws {
        let view = makeView(count: Int.max, committed: Int.max)
        XCTAssertEqual(buttons(view).count, 11)
        XCTAssertEqual(dots(view).count, 9)
        XCTAssertEqual(dots(view).last?.tag, Int.max - 1)
        XCTAssertEqual(selectedPages(view), [Int.max - 1])
        await drainDeferredPresentationTurns()
        XCTAssertTrue(try XCTUnwrap(dots(view).last?.accessibilityLabel()).contains("共 \(Int.max) 页"))
        XCTAssertFalse(try windowButton(view, next: true).isEnabled)
        let previous = try windowButton(view, next: false)
        previous.performClick(nil)
        XCTAssertEqual(dots(view).first?.tag, Int.max - 18)
        try windowButton(view, next: true).performClick(nil)
        XCTAssertEqual(dots(view).last?.tag, Int.max - 1)
    }

    func testWindowTraversalReachesAllPagesAndNeverNavigates() async throws {
        let view = makeView(count: 25, committed: 0)
        let previous = try windowButton(view, next: false)
        let next = try windowButton(view, next: true)
        var requests: [Int] = []
        view.onRequestPage = { requests.append($0) }
        var reached = Set(dots(view).map(\.tag))
        XCTAssertFalse(previous.isEnabled)
        next.performClick(nil)
        XCTAssertEqual(dots(view).first?.tag, 9)
        reached.formUnion(dots(view).map(\.tag))
        XCTAssertTrue(selectedPages(view).isEmpty)
        next.performClick(nil)
        XCTAssertEqual(dots(view).map(\.tag), Array(16..<25))
        reached.formUnion(dots(view).map(\.tag))
        XCTAssertFalse(next.isEnabled)
        next.performClick(nil)
        XCTAssertEqual(dots(view).first?.tag, 16)
        XCTAssertEqual(reached, Set(0..<25))
        previous.performClick(nil)
        XCTAssertEqual(dots(view).first?.tag, 7)
        previous.performClick(nil)
        XCTAssertEqual(dots(view).first?.tag, 0)
        XCTAssertEqual(selectedPages(view), [0])
        XCTAssertFalse(previous.isEnabled)
        XCTAssertTrue(requests.isEmpty)
        await drainDeferredPresentationTurns()
        XCTAssertEqual(view.accessibilityValue() as? String, "第 1 页，共 25 页")
    }

    func testEqualUpdatesKeepBrowsedWindowAndDoNotInvalidateLayoutOrRebuild() throws {
        let view = makeView(count: 100, committed: 0)
        let identities = buttons(view).map { ObjectIdentifier($0) }
        try windowButton(view, next: true).performClick(nil)
        let range = dots(view).map(\.tag)
        view.needsLayout = false
        for _ in 0..<100 {
            view.update(pageCount: 100, committedPage: 0, isEnabled: true)
        }
        XCTAssertFalse(view.needsLayout)
        XCTAssertEqual(dots(view).map(\.tag), range)
        XCTAssertEqual(buttons(view).map { ObjectIdentifier($0) }, identities)
        view.update(pageCount: 100, committedPage: 0, isEnabled: false)
        view.update(pageCount: 100, committedPage: 0, isEnabled: true)
        XCTAssertEqual(dots(view).map(\.tag), range)
    }

    func testPresentationChangesOnlyRecenterWhenCommittedPageLeavesWindow() {
        let view = makeView(count: 100, committed: 50)
        XCTAssertEqual(dots(view).map(\.tag), Array(46..<55))
        view.update(pageCount: 100, committedPage: 51, isEnabled: true)
        XCTAssertEqual(dots(view).map(\.tag), Array(46..<55))
        XCTAssertEqual(selectedPages(view), [51])
        view.update(pageCount: 101, committedPage: 51, isEnabled: true)
        XCTAssertEqual(dots(view).map(\.tag), Array(46..<55))
        view.update(pageCount: 101, committedPage: 90, isEnabled: true)
        XCTAssertEqual(dots(view).map(\.tag), Array(86..<95))
    }

    func testReuseAcrossHideCountChangesAndMaterialChanges() {
        let view = makeView()
        let identities = buttons(view).map { ObjectIdentifier($0) }
        for count in [0, 1, 2, 9, 10, 100, Int.max, 3] {
            view.update(pageCount: count, committedPage: count - 1, isEnabled: true)
            view.applyMaterialPolicy(reduceTransparency: count % 2 == 0, increaseContrast: true)
            XCTAssertEqual(buttons(view).count, 11)
            XCTAssertEqual(buttons(view).map { ObjectIdentifier($0) }, identities)
        }
    }

    func testAccessibilityExposesPageCountCurrentAndWindowMeaning() async throws {
        let view = makeView(count: 12, committed: 2)
        XCTAssertEqual(view.accessibilityRole(), .group)
        await drainDeferredPresentationTurns()
        XCTAssertEqual(view.accessibilityLabel(), LocalizedStrings(language: .simplifiedChinese).gridText(.pageNavigation))
        await drainDeferredPresentationTurns()
        XCTAssertEqual(view.accessibilityValue() as? String, "第 3 页，共 12 页")
        let current = try XCTUnwrap(dots(view).first { $0.tag == 2 })
        await drainDeferredPresentationTurns()
        XCTAssertEqual(current.accessibilityLabel(), "第 3 页，共 12 页，当前页")
        await drainDeferredPresentationTurns()
        XCTAssertEqual(current.accessibilityValue() as? String, "当前页")
        let other = try XCTUnwrap(dots(view).first { $0.tag == 1 })
        await drainDeferredPresentationTurns()
        XCTAssertEqual(other.accessibilityLabel(), "第 2 页，共 12 页")
        await drainDeferredPresentationTurns()
        XCTAssertEqual(other.accessibilityValue() as? String, "未选中")
        await drainDeferredPresentationTurns()
        XCTAssertEqual(try windowButton(view, next: false).accessibilityLabel(), LocalizedStrings(language: .simplifiedChinese).gridText(.previousPageWindow))
        await drainDeferredPresentationTurns()
        XCTAssertEqual(try windowButton(view, next: true).accessibilityLabel(), LocalizedStrings(language: .simplifiedChinese).gridText(.nextPageWindow))
        view.update(pageCount: 3, committedPage: 1, isEnabled: false)
        await drainDeferredPresentationTurns()
        XCTAssertEqual(dots(view)[1].accessibilityLabel(), "第 2 页，共 3 页，当前页")
        XCTAssertFalse(dots(view)[1].isEnabled)
    }

    func testMaterialPolicyHasTransparentAndOpaqueContrastVariantsWithoutChangingControls() throws {
        let view = makeView(count: 12, committed: 3)
        let identities = buttons(view).map { ObjectIdentifier($0) }
        let range = dots(view).map(\.tag)
        let layer = try XCTUnwrap(view.layer)
        for transparency in [true, false] {
            for contrast in [true, false] {
                view.applyMaterialPolicy(reduceTransparency: transparency, increaseContrast: contrast)
                let color = try XCTUnwrap(layer.backgroundColor).alpha
                XCTAssertEqual(color, transparency ? 1 : 0.32, accuracy: 0.001)
                XCTAssertEqual(layer.isOpaque, transparency)
                XCTAssertEqual(layer.borderWidth, contrast ? 2 : 0)
                XCTAssertEqual(buttons(view).map { ObjectIdentifier($0) }, identities)
                XCTAssertEqual(dots(view).map(\.tag), range)
                XCTAssertEqual(selectedPages(view), [3])
            }
        }
    }

    func testLayoutFitsParentBoundsAndUsesIntrinsicSize() {
        let view = makeView(count: 100)
        for width in [CGFloat(360), 324, 160, 0] {
            view.frame = NSRect(x: 0, y: 0, width: width, height: 32)
            view.layout()
            for button in buttons(view).filter({ !$0.isHidden }) {
                XCTAssertGreaterThanOrEqual(button.frame.minX, view.bounds.minX - 0.001)
                XCTAssertLessThanOrEqual(button.frame.maxX, view.bounds.maxX + 0.001)
                XCTAssertGreaterThanOrEqual(button.frame.minY, view.bounds.minY)
                XCTAssertLessThanOrEqual(button.frame.maxY, view.bounds.maxY)
            }
        }
        XCTAssertEqual(view.intrinsicContentSize, NSSize(width: 320, height: 32))
    }

    func testMainFrameAndAllControlsPreserveOwnerKeyboardFocus() {
        let view = makeView(count: 100, committed: 50)
        view.frame = NSRect(x: 0, y: 0, width: 320, height: 40)
        view.layout()
        XCTAssertTrue(buttons(view).allSatisfy(\.refusesFirstResponder))
        XCTAssertTrue(buttons(view).allSatisfy { $0.frame.height == 24 && $0.frame.midY == 20 })
    }

    func testActualButtonAndDisabledStripGapHitRemainLauncherChrome() throws {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 100))
        let view = makeView(count: 3)
        view.frame.origin = NSPoint(x: 20, y: 20)
        root.addSubview(view)
        view.layout()
        XCTAssertEqual(view.identifier?.rawValue, "launchcopy.chrome.page-dots")
        let first = try XCTUnwrap(dots(view).first)
        let second = dots(view)[1]
        let buttonPoint = view.convert(NSPoint(x: first.frame.midX, y: first.frame.midY), to: root)
        let gapPoint = view.convert(NSPoint(x: (first.frame.maxX + second.frame.minX) / 2,
                                           y: first.frame.midY), to: root)
        XCTAssertTrue(blankClickResolvesToLauncherChrome(root.hitTest(buttonPoint)))
        // Main's integration must recognize chrome identifiers on the NSView container as well.
        XCTAssertTrue(root.hitTest(gapPoint) === view)
        XCTAssertTrue(blankClickResolvesToLauncherChrome(root.hitTest(gapPoint)))
        view.update(pageCount: 3, committedPage: 0, isEnabled: false)
        XCTAssertTrue(blankClickResolvesToLauncherChrome(root.hitTest(buttonPoint)))
        XCTAssertTrue(blankClickResolvesToLauncherChrome(root.hitTest(gapPoint)))
    }
}
