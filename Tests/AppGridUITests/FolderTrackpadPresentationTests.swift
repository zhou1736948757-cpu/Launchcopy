import AppKit
import XCTest
import AppCatalogCore
import AppIconPipeline
@testable import AppGridUI
@testable import PagingUI

@MainActor
final class FolderTrackpadPresentationTests: XCTestCase {
    private func fixture(reduceMotion: Bool = false) -> (FolderOverlayView, IconPipeline, FolderEntry) {
        let pipeline = IconPipeline(loader: GatedIconLoader(), limits: .init())
        let overlay = FolderOverlayView(iconPipeline: pipeline)
        overlay.frame = NSRect(x: 0, y: 0, width: 1000, height: 800)
        overlay.applyFolderLayout(FolderLayoutPolicy.resolve(usableBounds: overlay.bounds, appearance: .default))
        let entry = FolderEntry(id: FolderID(), title: "Swipe fixture", members: (0..<35).map { makeAppID("swipe.\($0)") })
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: reduceMotion) { _ in "Application" }
        overlay.layoutSubtreeIfNeeded()
        overlay.trackpadPager.automaticallyDrivesFrames = false
        overlay.onInnerPageChange = { [weak overlay] page in
            overlay?.configure(entry: entry, innerPage: page, reduceMotion: reduceMotion) { _ in "Application" }
            overlay?.layoutSubtreeIfNeeded()
        }
        return (overlay, pipeline, entry)
    }

    private func scroll(_ overlay: FolderOverlayView, _ phase: NSEvent.Phase, x: CGFloat = 0, y: CGFloat = 0, t: Double = 1) {
        overlay.handleTrackpadScroll(phase: phase, momentumPhase: [], deltaX: x, deltaY: y,
                                     isDirectionInverted: true, timestamp: t)
    }

    func testDraggingMovesOnlyBoundedClippedMemberPresentationThenCommits() {
        let (overlay, pipeline, entry) = fixture()
        defer { overlay.teardown(); pipeline.shutdown() }
        let panel = overlay.panelFrame
        let title = overlay.titleEditorFrame
        let originalCellFrame = overlay.memberCell(at: 0)?.frame
        scroll(overlay, .began)
        scroll(overlay, .changed, x: -400, t: 1.1)
        XCTAssertTrue(overlay.isTrackpadPagingActive)
        XCTAssertGreaterThan(overlay.trackpadPager.core.visualOffset, 0)
        XCTAssertLessThanOrEqual(overlay.trackpadVisualPageCount, 3)
        XCTAssertGreaterThan(overlay.trackpadVisualPageCount, 0)
        XCTAssertLessThan(overlay.trackpadVisualFrame(for: 0)?.minX ?? 0, 0)
        XCTAssertEqual(overlay.panelFrame, panel)
        XCTAssertEqual(overlay.titleEditorFrame, title)
        XCTAssertEqual(overlay.memberCell(at: 0)?.frame, originalCellFrame)
        XCTAssertTrue(overlay.memberCell(at: 0)?.isHidden == true)
        var clock = 10.0
        overlay.trackpadPager.pendingFinishTimeSource = { clock }
        scroll(overlay, .ended, t: 1.2)
        clock += 0.101
        for _ in 0..<180 { overlay.trackpadPager.advanceFrame(deltaTime: 1.0 / 60) }
        XCTAssertEqual(overlay.currentInnerPage, 1)
        XCTAssertEqual(overlay.memberAppID(at: 0), entry.members[overlay.membersPerPage])
        XCTAssertEqual(overlay.trackpadVisualPageCount, 0)
        XCTAssertFalse(overlay.isTrackpadPagingActive)
        XCTAssertFalse(overlay.memberCell(at: 0)?.isHidden ?? true)
    }

    func testVerticalScrollDoesNotMoveAndRejectedInputDoesNotStartPaging() {
        let (overlay, pipeline, _) = fixture()
        defer { overlay.teardown(); pipeline.shutdown() }
        scroll(overlay, .began)
        scroll(overlay, .changed, x: 2, y: 200)
        XCTAssertEqual(overlay.trackpadPager.core.visualOffset, 0)
        XCTAssertEqual(overlay.trackpadVisualPageCount, 0)
        overlay.cancelTrackpadPaging()
        overlay.canBeginTrackpadPaging = { false }
        scroll(overlay, .began)
        scroll(overlay, .changed, x: -400)
        XCTAssertFalse(overlay.isTrackpadPagingActive)
        XCTAssertEqual(overlay.currentInnerPage, 0)
    }

    func testResizeUnavailableAndTitleEditorCancelMotionWithoutClosingFolder() {
        let (overlay, pipeline, entry) = fixture()
        defer { overlay.teardown(); pipeline.shutdown() }
        scroll(overlay, .began)
        scroll(overlay, .changed, x: -180)
        overlay.frame.size.width -= 100
        overlay.layoutSubtreeIfNeeded()
        XCTAssertFalse(overlay.isTrackpadPagingActive)
        XCTAssertEqual(overlay.trackpadVisualPageCount, 0)
        XCTAssertEqual(overlay.currentEntry?.id, entry.id)
        scroll(overlay, .began)
        scroll(overlay, .changed, x: -180)
        overlay.setMemberPresentationAvailable(false)
        XCTAssertFalse(overlay.isTrackpadPagingActive)
        XCTAssertEqual(overlay.trackpadVisualPageCount, 0)
        overlay.setMemberPresentationAvailable(true)
        XCTAssertTrue(overlay.mountTitleEditor(NSView()))
        scroll(overlay, .began)
        scroll(overlay, .changed, x: -400)
        XCTAssertFalse(overlay.isTrackpadPagingActive)
        XCTAssertEqual(overlay.currentInnerPage, 0)
    }

    func testVisualOnlyClearAndTeardownStopAllInnerWork() {
        let (overlay, pipeline, _) = fixture()
        defer { pipeline.shutdown() }
        scroll(overlay, .began)
        scroll(overlay, .changed, x: -180)
        overlay.setVisualOnly(true)
        XCTAssertFalse(overlay.isTrackpadPagingActive)
        XCTAssertEqual(overlay.trackpadVisualPageCount, 0)
        scroll(overlay, .began)
        XCTAssertFalse(overlay.isTrackpadPagingActive)
        overlay.clearContent()
        overlay.teardown()
        overlay.trackpadPager.advanceFrame(deltaTime: 1)
        XCTAssertNil(overlay.currentEntry)
        XCTAssertEqual(overlay.trackpadVisualPageCount, 0)
    }

    func testReduceMotionDoesNotTranslateMemberViews() {
        let (overlay, pipeline, _) = fixture(reduceMotion: true)
        defer { overlay.teardown(); pipeline.shutdown() }
        scroll(overlay, .began)
        scroll(overlay, .changed, x: -400)
        XCTAssertEqual(overlay.trackpadVisualPageCount, 0)
        XCTAssertFalse(overlay.memberCell(at: 0)?.isHidden ?? true)
    }
    func testLongContinuousDragKeepsFartherVisiblePageInsideBoundedWindow() {
        let (overlay, pipeline, _) = fixture()
        defer { overlay.teardown(); pipeline.shutdown() }
        scroll(overlay, .began)
        scroll(overlay, .changed, x: -CGFloat(overlay.trackpadPager.core.pageWidth) * 1.5, t: 1.1)
        XCTAssertGreaterThan(overlay.trackpadPager.core.visualOffset, 1)
        XCTAssertNotNil(overlay.trackpadVisualFrame(for: 2), "Visible second-next page must not become empty space")
        XCTAssertLessThanOrEqual(overlay.trackpadVisualPageCount, 3)
    }

}
