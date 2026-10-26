import AppKit
import AppCatalogCore
import LauncherLocalization
import XCTest
@testable import AppGridUI
@testable import PagingUI
@testable import PagingPrototypeApp

@MainActor
final class ChromeGeometryOrderTests: XCTestCase {
    func testWindowGeometryDelegatesAnchorNoticeToUpdatedSearchWithoutRenewingDeadline() async throws {
        for screenChange in [false, true] {
            _ = NSApplication.shared
            let host = AppDelegate(options: .default)
            let root = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
            let window = NSWindow(contentRect: root.bounds, styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = root
            let assembly = AppCatalogAssembly(roots: [URL(fileURLWithPath: "/SyntheticChromeGeometry")], loader: RecordingIconLoader())
            let search = AppSearchController(presentation: assembly.searchPresentation, keyboardController: nil, surface: nil)
            host.window = window; host.container = root; host.search = search
            root.addSubview(search.field)
            search.field.autoresizingMask = [.minXMargin, .maxXMargin, .minYMargin]
            // Deterministic prior screen inset. The real delegate will resolve CURRENT
            // window metadata; no screen change or visible window is performed here.
            let currentInset = window.screen?.safeAreaInsets.top ?? 0
            search.field.frame = AppDelegate.searchFieldFrame(in: root.bounds, safeAreaTop: currentInset + 32)
            search.field.stringValue = "Synthetic Query"
            host.installActionFeedback(in: root)
            let notice = try XCTUnwrap(host.actionFeedbackView)
            notice.show(reason: .launchFailed, strings: LocalizedStrings(language: .english))
            for _ in 0..<5 { await drainDeferredPresentationTurns() }
            defer {
                host.teardownActionFeedback(); search.teardown(); assembly.teardown()
                window.delegate = nil; window.contentView = nil
            }
            let deadline = notice.expirationDeadline
            XCTAssertFalse(notice.isHidden)
            XCTAssertFalse(window.isVisible)
            let notification = Notification(name: screenChange ? NSWindow.didChangeScreenNotification : NSWindow.didResizeNotification,
                object: window)
            if screenChange { host.windowDidChangeScreen(notification) }
            else { host.windowDidResize(notification) }
            let currentFrame = AppDelegate.searchFieldFrame(in: root.bounds, safeAreaTop: window.screen?.safeAreaInsets.top ?? 0)
            XCTAssertEqual(search.field.frame, currentFrame)
            XCTAssertEqual(notice.frame.maxY, currentFrame.minY - 12, accuracy: 0.001,
                "A geometry transaction must lay out dependent feedback AFTER the search field")
            XCTAssertEqual(notice.expirationDeadline, deadline)
            XCTAssertEqual(search.field.stringValue, "Synthetic Query")
            XCTAssertFalse(window.isVisible)
        }
    }

    func testAbsentSearchStillLaysOutFallbackNoticeWithoutRenewingDeadline() async throws {
        _ = NSApplication.shared
        let host = AppDelegate(options: .default)
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        host.container = root
        host.installActionFeedback(in: root)
        defer { host.teardownActionFeedback() }
        let notice = try XCTUnwrap(host.actionFeedbackView)
        notice.show(reason: .launchFailed, strings: LocalizedStrings(language: .english))
        for _ in 0..<5 { await drainDeferredPresentationTurns() }
        let deadline = notice.expirationDeadline
        notice.frame = .zero
        host.windowDidResize(Notification(name: NSWindow.didResizeNotification))
        XCTAssertEqual(notice.frame.maxY, root.bounds.maxY - 80, accuracy: 0.001)
        XCTAssertEqual(notice.expirationDeadline, deadline)
        XCTAssertFalse(notice.isHidden)
    }
}
