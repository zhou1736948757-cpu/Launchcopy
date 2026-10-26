import AppCatalogCore
import AppIconPipeline
import AppKit
import Foundation
import PagingUI
import XCTest
@testable import AppGridUI

@MainActor
final class MoveOutCachedElevationTests: XCTestCase {
    func testPostSwitchElevationRetainsPreCollapseCaptureAfterSourceClearAndReuse() throws {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.borderless], backing: .buffered, defer: false)
        defer { withExtendedLifetime(window) {} }
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
        let surface = NSView(frame: NSRect(x: 15, y: 10, width: 450, height: 350))
        let overlay = NSView(frame: NSRect(x: 40, y: 30, width: 400, height: 300))
        window.contentView = content
        content.addSubview(surface)
        content.addSubview(overlay)
        XCTAssertFalse(window.isVisible)

        let (coordinator, source, token) = makeDraggingMember(host: overlay)
        defer { coordinator.teardown() }
        XCTAssertNil(source.window, "The real source cell is never shown or attached to a window.")
        let initialCapture = try XCTUnwrap(coordinator.visuals.previewIconImage)

        // The compatibility entry point must still refresh the source before collapse.
        source.bind(name: "Captured member", token: token)
        let latestIcon = makeIcon(color: .systemBlue)
        source.iconView.image = latestIcon
        coordinator.prepareAndElevateMoveOutPreview(above: overlay)
        let captured = try XCTUnwrap(coordinator.visuals.previewIconImage)
        let capturedBytes = try XCTUnwrap(captured.tiffRepresentation)
        let capturedFrame = coordinator.visuals.previewFrame
        let capturedPoint = overlay.convert(NSPoint(x: 140, y: 240), to: content)
        XCTAssertEqual(capturedFrame.origin.x, capturedPoint.x - capturedFrame.width / 2)
        XCTAssertEqual(capturedFrame.origin.y, capturedPoint.y + 24)
        XCTAssertFalse(captured === initialCapture)
        XCTAssertFalse(captured === latestIcon, "The preview owns a durable image, not the source image.")
        XCTAssertEqual(coordinator.visuals.previewNameText, "Captured member")
        XCTAssertTrue(coordinator.visuals.visualViewSuperviews[0] === content)
        let initialPreview = try XCTUnwrap(content.subviews.last)
        XCTAssertFalse(initialPreview === overlay)
        XCTAssertEqual(initialPreview.frame, capturedFrame)

        // Model panel collapse clearing its cell before the geometric host changes.
        overlay.isHidden = true
        source.clearContent()
        coordinator.setVisualHost(surface)
        coordinator.elevateMoveOutPreview(above: overlay)
        XCTAssertTrue(coordinator.visualHost === surface)
        XCTAssertTrue(coordinator.visuals.previewIconImage === captured,
                      "Any source recapture replaces the saved snapshot identity, even for a blank cell.")
        XCTAssertEqual(coordinator.visuals.previewNameText, "Captured member")
        XCTAssertEqual(coordinator.visuals.previewFrame, capturedFrame,
                       "Elevation retains the existing currentPointer placement semantics.")
        XCTAssertTrue(coordinator.visuals.visualViewSuperviews[0] === content)
        let preview = try XCTUnwrap(content.subviews.last)
        XCTAssertTrue(preview === initialPreview)
        XCTAssertFalse(preview === overlay)
        XCTAssertEqual(preview.frame, coordinator.visuals.previewFrame)
        XCTAssertEqual(preview.alphaValue, 1)
        XCTAssertFalse(preview.isHidden)

        // Reuse the same source object for unrelated content, then change hosts again.
        source.bind(name: "Reused cell", token: token)
        source.iconView.image = makeIcon(color: .systemRed)
        let nextHost = NSView(frame: NSRect(x: 70, y: 55, width: 400, height: 300))
        content.addSubview(nextHost, positioned: .below, relativeTo: overlay)
        coordinator.setVisualHost(nextHost)
        coordinator.elevateMoveOutPreview(above: overlay)
        XCTAssertTrue(coordinator.visualHost === nextHost)
        XCTAssertTrue(coordinator.visuals.previewIconImage === captured)
        XCTAssertEqual(coordinator.visuals.previewNameText, "Captured member")
        XCTAssertEqual(captured.tiffRepresentation, capturedBytes)
        XCTAssertTrue(content.subviews.last === preview, "The cached preview remains above the overlay.")

        // Subsequent moves still convert window coordinates through the current host.
        let windowPoint = NSPoint(x: 250, y: 150)
        let localPoint = content.convert(windowPoint, from: nil)
        coordinator.pointerDragged(locationInWindow: windowPoint)
        XCTAssertEqual(coordinator.visuals.previewFrame.origin.x,
                       localPoint.x - capturedFrame.width / 2, accuracy: 0.001)
        XCTAssertEqual(coordinator.visuals.previewFrame.origin.y, localPoint.y + 24, accuracy: 0.001)
        XCTAssertTrue(coordinator.visuals.previewIconImage === captured)

        coordinator.teardown()
        coordinator.teardown()
        XCTAssertFalse(coordinator.isSessionActive)
        XCTAssertEqual(coordinator.controller.state, .idle)
        XCTAssertFalse(coordinator.visuals.isPreviewVisible)
        XCTAssertNil(coordinator.visuals.previewIconImage)
        XCTAssertEqual(coordinator.visuals.previewNameText, "")
        XCTAssertTrue(coordinator.visuals.visualViewSuperviews.allSatisfy { $0 == nil })
    }

    func testCollapsedMemberDragTurnsVisibleMainPageWithoutTurningFolderPage() {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        let clock = FakeDragClock(0)
        let (coordinator, source, _) = makeDraggingMember(host: host, clock: clock)
        defer { coordinator.teardown(); withExtendedLifetime(source) {} }
        var mainTurns = 0, folderTurns = 0
        coordinator.topLevelPageTurn = { _, _ in mainTurns += 1; return .deferred }
        coordinator.folderPageTurn = { _ in folderTurns += 1 }
        coordinator.geometryProvider = { _ in
            DragGeometry(itemFrames: [], topLevelFrames: [], containerWidth: 500,
                page: 0, pageCount: 2,
                topLevelMoveOutBounds: .init(x: 0, y: 0, width: 500, height: 300))
        }
        coordinator.pointerDragged(locationInWindow: host.convert(NSPoint(x: 498, y: 140), to: nil))
        clock.current = 0.6
        coordinator.edgeTimerFired()
        XCTAssertEqual(mainTurns, 1)
        XCTAssertEqual(folderTurns, 0)
        if case .folder = coordinator.controller.activeTransaction?.scope {} else {
            XCTFail("The canonical member source must not be converted to a top-level source")
        }
    }

    private final class FlippedContainer: NSView {
        override var isFlipped: Bool { true }
    }

    func testElevationUsesDestinationParentCoordinatesAndFlipBeforeAnyNewMovement() throws {
        _ = NSApplication.shared
        for rootFlipped in [false, true] {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            let content: NSView = rootFlipped
                ? FlippedContainer(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
                : NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
            let overlay = NSView(frame: NSRect(x: 40, y: 30, width: 400, height: 300))
            let next = FlippedContainer(frame: NSRect(x: 70, y: 55, width: 400, height: 300))
            window.contentView = content
            content.addSubview(next); content.addSubview(overlay)
            let (coordinator, source, _) = makeDraggingMember(host: overlay)
            defer { coordinator.teardown(); withExtendedLifetime(window) {} }
            coordinator.prepareAndElevateMoveOutPreview(above: overlay)
            let pointer = content.convert(NSPoint(x: 140, y: 240), from: overlay)
            let frame = coordinator.visuals.previewFrame
            XCTAssertEqual(frame.midX, pointer.x, accuracy: 0.001)
            XCTAssertEqual(frame.minY, rootFlipped ? pointer.y - frame.height - 12 : pointer.y + 24,
                           accuracy: 0.001)
            let pixels = try XCTUnwrap(coordinator.visuals.previewIconImage)
            source.clearContent()
            coordinator.setVisualHost(next)
            coordinator.elevateMoveOutPreview(above: overlay)
            XCTAssertEqual(coordinator.visuals.previewFrame, frame,
                           "Host switch must not move a captured icon without a pointer event")
            XCTAssertTrue(coordinator.visuals.previewIconImage === pixels)
            XCTAssertTrue(coordinator.visuals.visualViewSuperviews[0] === content)
        }
    }

    func testCachedElevationWithoutWindowAndLateCallsAfterTeardown() throws {
        let overlay = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let surface = NSView(frame: overlay.frame)
        let (coordinator, source, _) = makeDraggingMember(host: overlay)
        defer { coordinator.teardown() }
        coordinator.prepareAndElevateMoveOutPreview(above: overlay)
        let captured = try XCTUnwrap(coordinator.visuals.previewIconImage)
        source.clearContent()
        coordinator.setVisualHost(surface)
        coordinator.elevateMoveOutPreview(above: overlay)
        XCTAssertTrue(coordinator.visuals.previewIconImage === captured)
        XCTAssertEqual(coordinator.visuals.previewNameText, "app1")
        XCTAssertTrue(coordinator.visuals.visualViewSuperviews[0] === surface,
                      "An unwindowed overlay uses the existing reaffirmation fallback.")

        coordinator.teardown()
        coordinator.setVisualHost(overlay)
        coordinator.elevateMoveOutPreview(above: overlay)
        coordinator.prepareAndElevateMoveOutPreview(above: overlay)
        coordinator.teardown()
        XCTAssertEqual(coordinator.controller.state, .idle)
        XCTAssertFalse(coordinator.isSessionActive)
        XCTAssertFalse(coordinator.visuals.isPreviewVisible)
        XCTAssertNil(coordinator.visuals.previewIconImage)
        XCTAssertTrue(coordinator.visuals.visualViewSuperviews.allSatisfy { $0 == nil },
                      "Late move-out calls must not resurrect a torn-down preview.")
    }

    private func makeDraggingMember(host: NSView, clock: FakeDragClock = FakeDragClock(0))
        -> (DragUISessionCoordinator, AppGridCellView, ItemBindingToken) {
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000071")!)
        let (_, catalog) = makeDragLayout(titles: ["app1", "app2"])
        let layout = PersistentWorkspaceLayout(
            generation: .zero, topLevelOrder: [.folder(folderID)],
            folders: [PersistentFolderRecord(id: folderID, title: "Synthetic folder",
                                             members: [ref("app1"), ref("app2")])])
        let geometry = folderGeometry(
            memberFrames: [DragItemFrame(identity: .app(ref("app1")),
                                        frame: DragRect(x: 0, y: 200, width: 80, height: 80))],
            topLevelFrames: [folderFrame(folderID, x: 0)])
        let coordinator = DragUISessionCoordinator(host: host, clock: clock,
                                                   reduceMotionProvider: { true })
        coordinator.layoutProvider = { layout }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.geometryProvider = { _ in geometry }
        let source = AppGridCellView(frame: NSRect(x: 0, y: 0, width: 80, height: 80))
        let token = ItemBindingToken(
            catalogRevision: 1, pageIdentity: PagePresentationID(revision: 1, pageIndex: 0),
            itemSlot: 0, appID: AnyHashable(makeAppID("fixture.app1")),
            reuseGeneration: 0, iconKey: nil, surfaceGeneration: 0)
        source.bind(name: "app1", token: token)
        source.iconView.image = makeIcon(color: .systemGreen)
        coordinator.pointerDown(locationInWindow: host.convert(NSPoint(x: 40, y: 240), to: nil),
                                sourceCell: source, memberFolderID: folderID)
        coordinator.pointerDragged(locationInWindow: host.convert(NSPoint(x: 140, y: 240), to: nil))
        XCTAssertEqual(coordinator.controller.state, .dragging)
        return (coordinator, source, token)
    }

    private func makeIcon(color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 32, height: 32), flipped: false) { rect in
            color.setFill()
            NSBezierPath(rect: rect).fill()
            return true
        }
    }
}
