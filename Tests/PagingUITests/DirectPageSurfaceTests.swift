import AppKit
import XCTest
@testable import PagingCore
@testable import PagingUI

@MainActor
final class DirectPageSurfaceTests: XCTestCase {
    func testContinuousReplacementAndPinSingleFinalCommit() throws {
        let surface = makeSurface(pageCount: 100)
        defer { surface.teardown() }
        XCTAssertTrue(surface.requestPage(99)); let pin = surface.pinnedPresentation
        surface.advanceFrame(deltaTime: 0.05)
        let shown = Double(-surface.pageContainer.frame.minX / max(surface.bounds.width, 64))
        XCTAssertEqual(shown, surface.presentedOffset, accuracy: 1e-10)
        XCTAssertTrue(surface.requestPage(3)); XCTAssertEqual(surface.core.activeTransition?.fromOffset, shown)
        XCTAssertEqual(surface.pinnedPresentation, pin)
        XCTAssertLessThan(settleFrames(surface), 600)
        XCTAssertEqual(surface.core.committedPage, 3); XCTAssertEqual(surface.core.commitCount, 1)
        XCTAssertNil(surface.pinnedPresentation)
    }
    func testTrackingAndPendingFinishIgnoreDotWithoutFlushingPhysicalWindow() {
        let surface = makeSurface()
        defer { surface.teardown() }
        gestureBegan(surface, at: 0); gestureChanged(surface, deltaX: 250, at: 0.5)
        gestureEnded(surface, at: 0.6)
        let wait = surface.pendingFinishSince, offset = surface.core.visualOffset
        let pin = surface.pinnedPresentation
        XCTAssertFalse(surface.requestPage(4)); XCTAssertEqual(surface.pendingFinishSince, wait)
        XCTAssertTrue(surface.needsFinish); XCTAssertEqual(surface.core.visualOffset, offset)
        surface.cancelDirectNavigation()
        XCTAssertEqual(surface.pinnedPresentation, pin); XCTAssertEqual(surface.core.state, .tracking)
    }
    func testHundredPageJumpsBoundResidencyAtEveryFrame() {
        let surface = makeSurface(pageCount: 100)
        defer { surface.teardown() }
        for target in [99, 2, 97, 0, 99, 0] {
            XCTAssertTrue(surface.requestPage(target))
            for _ in 0..<600 {
                XCTAssertLessThanOrEqual(surface.liveHostCount, 7)
                XCTAssertLessThanOrEqual(surface.liveHostCount + surface.poolHostCount, 14)
                if !surface.core.isAnimating { break }
                surface.advanceFrame(deltaTime: 1.0 / 60)
            }
            XCTAssertEqual(surface.core.committedPage, target)
        }
    }
    func testHeightResizeAndScopedCancelStopOnlyDirectTransitions() throws {
        let surface = makeSurface()
        defer { surface.teardown() }
        _ = surface.requestPage(4); let old = try XCTUnwrap(surface.core.activeTransition)
        surface.frame.size.height += 20; surface.layout()
        XCTAssertEqual(surface.core.state, .idle); XCTAssertFalse(surface.core.completeSettle(old))
        gestureBegan(surface, at: 0); surface.cancelDirectNavigation()
        XCTAssertEqual(surface.core.state, .tracking)
    }
    func testObservationDoesNotRunOnEveryOffsetAndTeardownClearsIt() {
        let surface = makeSurface()
        defer { surface.teardown() }
        var notifications = 0
        surface.onPageNavigationChange = { notifications += 1 }
        _ = surface.requestPage(4); let initial = notifications
        for _ in 0..<4 { surface.advanceFrame(deltaTime: 1.0 / 60) }
        XCTAssertEqual(notifications, initial)
        surface.cancelDirectNavigation(); XCTAssertGreaterThan(notifications, initial)
        surface.teardown(); let final = notifications
        _ = surface.requestPage(2); XCTAssertEqual(notifications, final)
    }
    func testNavigationObserverCancelsSynchronousRMBeforeAnyStaleMove() {
        let surface = makeSurface(reduceMotion: true); defer { surface.teardown() }
        var once = false
        surface.onPageNavigationChange = {
            if !once && surface.isDirectNavigationActive { once = true; surface.cancelDirectNavigation() }
        }
        _ = surface.requestPage(4)
        XCTAssertEqual(surface.presentedOffset, 0); XCTAssertEqual(surface.core.committedPage, 0)
        XCTAssertEqual(surface.core.commitCount, 0); XCTAssertNil(surface.pinnedPresentation)
    }
    func testCommitObserverNewRequestRetainsPinAndFinalLatestTarget() {
        let surface = makeSurface(); defer { surface.teardown() }
        var once = false
        surface.onPageNavigationChange = {
            if surface.core.committedPage == 2 && !once {
                once = true; XCTAssertTrue(surface.requestPage(4))
            }
        }
        _ = surface.requestPage(2); settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 4); XCTAssertEqual(surface.core.commitCount, 2)
        XCTAssertNil(surface.pinnedPresentation); XCTAssertNil(surface.core.activeTransition)
    }

    func testReentrantOffsetCancelOrRMReplaceAlwaysRendersOwnedOffset() {
        for immediate in [false, true] {
            let surface = makeSurface(reduceMotion: immediate); defer { surface.teardown() }
            var once = false
            surface.appEvents.onVisualOffsetChange = { _ in
                guard !once else { return }; once = true
                if immediate { _ = surface.requestPage(2) } else { surface.cancelDirectNavigation() }
            }
            _ = surface.requestPage(4)
            if !immediate { surface.advanceFrame(deltaTime: 1.0 / 60) }
            XCTAssertEqual(Double(-surface.pageContainer.frame.minX / max(surface.bounds.width, 64)),
                           surface.core.visualOffset, accuracy: 1e-10)
            XCTAssertEqual(surface.core.committedPage, immediate ? 2 : 0)
            XCTAssertEqual(surface.core.state, .idle)
        }
    }
    private final class Provider: PagingPageContentProviding {
        var servedRevision: UInt64?
        var servedPageCount: Int?
        init(_ revision: UInt64?, count: Int = 5) { servedRevision = revision; servedPageCount = count }
        func content(for presentation: PagePresentationID, itemsPerPage: Int) -> PagingPageContent {
            .init(presentationID: presentation, items: [], isPlaceholder: servedRevision == nil)
        }
    }
    func testProviderReplacementCancelsEqualAndNewRevisionDirectContextsBeforeBinding() throws {
        for revision: UInt64? in [7, 8, nil] {
            let surface = makeSurface(); defer { surface.teardown() }
            surface.contentProvider = Provider(7)
            _ = surface.requestPage(4); let old = try XCTUnwrap(surface.core.activeTransition)
            surface.contentProvider = Provider(revision)
            XCTAssertFalse(surface.core.completeSettle(old)); XCTAssertNil(surface.pinnedPresentation)
            XCTAssertEqual(surface.core.commitCount, 0); XCTAssertEqual(surface.core.state, .idle)
        }
        let surface = makeSurface(); defer { surface.teardown() }
        surface.contentProvider = Provider(7); _ = surface.requestPage(4)
        surface.contentProvider = nil
        XCTAssertFalse(surface.isDirectNavigationActive); XCTAssertNil(surface.pinnedPresentation)
        gestureBegan(surface, at: 0)
        surface.contentProvider = Provider(8)
        XCTAssertEqual(surface.core.state, .tracking)
    }

    func testLifecycleCancellationRejectsReentrantSurfaceRequestWhileClosing() {
        let surface = makeSurface(); defer { surface.teardown() }
        surface.appEvents.onStaleRejection = { _ in XCTAssertFalse(surface.requestPage(2)) }
        _ = surface.requestPage(4); surface.cancelDirectNavigation()
        XCTAssertEqual(surface.core.state, .idle); XCTAssertNil(surface.core.activeTransition)
        XCTAssertNil(surface.pinnedPresentation)
    }

}
