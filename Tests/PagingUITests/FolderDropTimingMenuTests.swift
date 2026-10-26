import AppKit
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class FolderDropTimingMenuTests: XCTestCase {
    func testFormalMenusAndToggleCannotEnableDiagnosticObservers() {
        _ = NSApplication.shared
        let prior = NSApp.mainMenu
        defer { NSApp.mainMenu = prior }
        let owner = AppDelegate(options: .default)
        owner.installLauncherMenu()
        let items = NSApp.mainMenu?.items.flatMap { $0.submenu?.items ?? [] } ?? []
        XCTAssertFalse(items.contains { $0.identifier?.rawValue.hasPrefix("diagnostics.folderDrop") == true })
        owner.toggleFolderDropTiming(nil)
        XCTAssertNil(owner.folderDropLatencyProbe)
        owner.configureFolderDropTimingObservers()
        XCTAssertNil(owner.folderDropLatencyProbe)
    }

    func testNumericReportUsesBoundedScrollableReadOnlyAlertAccessory() throws {
        let owner = AppDelegate(options: .default)
        let probe = FolderDropLatencyProbe()
        owner.folderDropLatencyProbe = probe
        for base in [100.0, 200.0, 300.0] {
            probe.beginRelease(eventTimestamp: base, now: base)
            for stage in FolderDropLatencyProbe.Stage.allCases {
                probe.mark(stage, now: base)
            }
            probe.endRelease(now: base, readyIcons: 15, visibleMembers: 15)
        }
        let alert = owner.makeFolderDropTimingAlert()
        let scroll = try XCTUnwrap(alert.accessoryView as? NSScrollView)
        let text = try XCTUnwrap(scroll.documentView as? NSTextView)
        XCTAssertEqual(scroll.frame.height, 300)
        XCTAssertTrue(scroll.hasVerticalScroller)
        XCTAssertFalse(text.isEditable)
        XCTAssertEqual(text.string, probe.summary)
        XCTAssertGreaterThan(text.frame.height, scroll.frame.height)
        XCTAssertEqual(alert.buttons.count, 1)
    }

    func testWindowObserverIsOptInAndPreservesNativeReleaseTimestamp() throws {
        let window = QuitOnBlankClickWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
                                            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        XCTAssertNil(window.onFolderMouseUpTiming)
        let timestamp = ProcessInfo.processInfo.systemUptime
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: NSPoint(x: 50, y: 50),
            modifierFlags: [], timestamp: timestamp, windowNumber: window.windowNumber,
            context: nil, eventNumber: 1, clickCount: 1, pressure: 0))
        var observed: [(Double, Double)] = []
        window.onFolderMouseUpTiming = { observed.append(($0, $1)) }
        window.sendEvent(event)
        XCTAssertEqual(observed.count, 1)
        XCTAssertEqual(observed.first?.0, timestamp)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(observed.first?.1), timestamp)
        window.onFolderMouseUpTiming = nil
        window.sendEvent(event)
        XCTAssertEqual(observed.count, 1)
    }
}
