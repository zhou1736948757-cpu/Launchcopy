import AppIconPipeline
import AppKit
import XCTest
@testable import AppGridUI

@MainActor
final class FolderDropTimingHooksTests: XCTestCase {
    func testObserverIsDefaultOffAndVisualOnlyOrTeardownNeverReports() throws {
        let pipeline = IconPipeline(loader: GatedIconLoader(), limits: .init())
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        defer { overlay.teardown(); pipeline.shutdown() }
        XCTAssertNil(overlay.onDropDiagnosticEvent)
        let event = try XCTUnwrap(NSEvent.mouseEvent(with: .leftMouseUp, location: .zero,
            modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 0))
        var events: [FolderOverlayView.DropDiagnosticEvent] = []
        overlay.onDropDiagnosticEvent = { events.append($0) }
        overlay.mouseUp(with: event)
        XCTAssertEqual(events.count, 2)
        guard case .willRelease(let timestamp, let begin) = events[0],
              case .didRelease(let end, let ready, let count) = events[1] else {
            return XCTFail("Release markers must surround the existing handler")
        }
        XCTAssertEqual(timestamp, event.timestamp)
        XCTAssertGreaterThanOrEqual(end, begin)
        XCTAssertEqual(ready, 0)
        XCTAssertEqual(count, 0)
        overlay.viewWillDraw()
        XCTAssertEqual(events.count, 3)
        overlay.setVisualOnly(true)
        overlay.mouseUp(with: event)
        overlay.viewWillDraw()
        XCTAssertEqual(events.count, 3)
        overlay.teardown()
        XCTAssertNil(overlay.onDropDiagnosticEvent)
        overlay.mouseUp(with: event)
        overlay.viewWillDraw()
        XCTAssertEqual(events.count, 3)
    }
}
