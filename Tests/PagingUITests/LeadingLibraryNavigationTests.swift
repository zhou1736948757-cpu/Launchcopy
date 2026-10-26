import AppKit
import AppGridUI
import LauncherLocalization
import PagingCore
import PagingUI
import XCTest
@testable import PagingPrototypeApp

final class LeadingLibraryScrollRouterTests: XCTestCase {
    private func route(_ router: inout LeadingLibraryScrollRouter, _ phase: NSEvent.Phase,
                       x: CGFloat = 0, y: CGFloat = 0, momentum: NSEvent.Phase = [],
                       eligible: Bool = true, library: Bool = false, moving: Bool = false,
                       inverted: Bool = true) -> LeadingLibraryScrollRouter.Destination {
        router.route(phase: phase, momentum: momentum, deltaX: x, deltaY: y,
            inverted: inverted, eligible: eligible, location: library ? .library : .grid,
            parentIsMoving: moving)
    }
    func testZeroBeginHoldsThenOutwardGridMovementSelectsParent() {
        var router = LeadingLibraryScrollRouter()
        XCTAssertEqual(route(&router, .began), .hold)
        XCTAssertEqual(route(&router, .changed, x: 12), .parent)
        XCTAssertEqual(route(&router, .ended), .parent)
        XCTAssertEqual(route(&router, [], x: -90, momentum: .began, eligible: false, library: true), .parent)
        XCTAssertEqual(route(&router, [], x: -90, momentum: .changed, eligible: false, library: true), .parent)
        XCTAssertEqual(route(&router, [], momentum: .ended, eligible: false, library: true), .parent)
    }
    func testGridNextPageSequenceNeverSwitchesToParentMidstream() {
        var router = LeadingLibraryScrollRouter()
        XCTAssertEqual(route(&router, .began), .hold)
        XCTAssertEqual(route(&router, .changed, x: -15), .grid)
        XCTAssertEqual(route(&router, .changed, x: 100), .grid)
        XCTAssertEqual(route(&router, .ended), .grid)
    }
    func testLibraryVerticalNativeSequenceAndHorizontalReturn() {
        var router = LeadingLibraryScrollRouter()
        XCTAssertEqual(route(&router, .began, library: true), .hold)
        XCTAssertEqual(route(&router, .changed, x: 1, y: 30, library: true), .native)
        XCTAssertEqual(route(&router, .changed, x: -30, library: true), .native)
        XCTAssertEqual(route(&router, .began, library: true), .hold)
        XCTAssertEqual(route(&router, .changed, x: -30, library: true), .parent)
    }
    func testCancelledUndecidedBeginReturnsToOriginalConsumer() {
        var router = LeadingLibraryScrollRouter()
        _ = route(&router, .began)
        XCTAssertEqual(route(&router, .cancelled), .grid)
        _ = route(&router, .began, library: true)
        XCTAssertEqual(route(&router, .cancelled, library: true), .native)
    }
    func testDisabledProtectedOrNonfirstPageDoesNotCapture() {
        var router = LeadingLibraryScrollRouter()
        XCTAssertEqual(route(&router, .began, eligible: false), .pass)
        XCTAssertEqual(route(&router, .changed, x: 30, eligible: true), .pass)
    }
    func testCancellationDrainsTailUntilFreshBegin() {
        var router = LeadingLibraryScrollRouter()
        router.drain()
        XCTAssertEqual(route(&router, .changed, x: -90), .drain)
        XCTAssertEqual(route(&router, [], momentum: .ended), .drain)
        XCTAssertEqual(route(&router, .began), .hold)
    }
    func testNewBeginInterruptingParentKeepsSameOwner() {
        var router = LeadingLibraryScrollRouter()
        XCTAssertEqual(route(&router, .began, eligible: false, moving: true), .parent)
        XCTAssertEqual(route(&router, .changed, x: -9, eligible: false, moving: true), .parent)
    }
    func testNaturalDirectionMappingAndLegacyWheel() {
        var router = LeadingLibraryScrollRouter()
        XCTAssertEqual(route(&router, [], x: -40, inverted: false), .parent)
        XCTAssertEqual(route(&router, [], x: 40, inverted: false), .grid)
        XCTAssertEqual(route(&router, [], x: 0, y: 40, library: true), .native)
    }
    func testIndependentWheelAfterCommitOrCancelStartsFreshButMomentumStaysDrained() {
        var router = LeadingLibraryScrollRouter()
        router.drain()
        XCTAssertEqual(route(&router, [], x: -40, momentum: .changed), .drain)
        XCTAssertEqual(route(&router, [], x: 40), .parent)
        router.drain()
        XCTAssertEqual(route(&router, [], x: -40, library: true), .parent)
    }
}

private actor LeadingLibraryMemoryStore: AppLibraryPersisting {
    func load() -> AppLibraryLoadResult { .loaded(.init(enabled: true)) }
    func save(_ value: AppLibraryPreferences, recoveringCorruptPayload: Bool) -> AppLibrarySaveResult { .saved }
}

@MainActor
final class LeadingLibraryNavigationTests: XCTestCase {
    private func make() async -> (LeadingLibraryNavigator, AppLibraryOwnerController, PagingSurface, NSView) {
        let surface = PagingSurface(pageCount: 4, pageWidth: 1000)
        surface.frameDriver = nil
        let preferences = AppLibraryPreferencesCoordinator(store: LeadingLibraryMemoryStore())
        let owner = AppLibraryOwnerController(preferences: preferences, strings: .init(language: .english))
        owner.canTransition = { true }
        owner.captureGrid = { .init(query: "retained", page: 2, selection: nil, searchWasFocused: true) }
        let host = NSView(frame: .init(x: 0, y: 0, width: 1000, height: 700))
        owner.attach(to: host)
        await preferences.loadIfNeeded()
        let navigator = LeadingLibraryNavigator(surface: surface, owner: owner)
        navigator.width = { 1000 }
        navigator.canNavigate = { true }
        navigator.canEnterFromGrid = { true }
        owner.onPresentationChange = { [weak navigator] in navigator?.ownerDidChange() }
        owner.onBeforeBack = { [weak navigator] in navigator?.cancel() }
        return (navigator, owner, surface, host)
    }
    private func settle(_ navigator: LeadingLibraryNavigator) {
        for _ in 0..<600 {
            if !navigator.pager.needsFrames { break }
            navigator.pager.advanceFrame(deltaTime: 1.0 / 60)
        }
        XCTAssertFalse(navigator.pager.needsFrames)
    }
    func testParentCommitAndSwipeBackKeepCanonicalApplicationDomainUnchanged() async {
        let (nav, owner, surface, host) = await make()
        defer { nav.teardown(); owner.teardown(); surface.teardown(); _ = host }
        XCTAssertTrue(nav.beginTransition())
        XCTAssertTrue(owner.isPreviewing)
        XCTAssertEqual(nav.pager.core.pageCount, 2)
        XCTAssertTrue(nav.pager.requestPage(0))
        settle(nav)
        XCTAssertEqual(nav.location, .library)
        XCTAssertTrue(owner.isOpen)
        XCTAssertFalse(owner.isPreviewing)
        XCTAssertEqual(surface.core.pageCount, 4)
        XCTAssertEqual(surface.core.committedPage, 0)
        var restored: AppLibraryGridReturnContext?
        owner.restoreGrid = { restored = $0 }
        XCTAssertTrue(nav.beginTransition())
        XCTAssertTrue(nav.pager.requestPage(1))
        settle(nav)
        XCTAssertEqual(nav.location, .grid)
        XCTAssertFalse(owner.isOpen)
        XCTAssertEqual(restored?.query, "retained")
        XCTAssertEqual(restored?.page, 0)
        XCTAssertNil(restored?.selection)
        XCTAssertEqual(restored?.searchWasFocused, false)
    }
    func testPreviewCancellationKeepsOriginalQueryPageAndSelectionTransaction() async {
        let (nav, owner, surface, host) = await make()
        defer { nav.teardown(); owner.teardown(); surface.teardown(); _ = host }
        var restores = 0, prepared = 0
        owner.restoreGrid = { _ in restores += 1 }
        owner.prepareEntry = { prepared += 1 }
        XCTAssertTrue(nav.beginTransition())
        _ = nav.pager.requestPage(0)
        nav.pager.advanceFrame(deltaTime: 0.03)
        nav.cancel()
        XCTAssertFalse(owner.isOpen)
        XCTAssertFalse(nav.isTransitioning)
        XCTAssertFalse(nav.pager.needsFrames)
        XCTAssertEqual(restores, 0)
        XCTAssertEqual(prepared, 0)
        XCTAssertEqual(surface.core.committedPage, 0)
    }
    func testButtonCloseReturnsPriorPageWhileSwipeIsDistinct() async {
        let (nav, owner, surface, host) = await make()
        defer { nav.teardown(); owner.teardown(); surface.teardown(); _ = host }
        var firstPagePreparations = 0
        nav.prepareFirstGridPage = { firstPagePreparations += 1 }
        var context: AppLibraryGridReturnContext?
        owner.restoreGrid = { context = $0 }
        XCTAssertTrue(owner.enter())
        XCTAssertEqual(nav.location, .library)
        XCTAssertEqual(firstPagePreparations, 1)
        owner.back()
        XCTAssertEqual(context?.page, 2)
        XCTAssertEqual(context?.query, "retained")
        XCTAssertEqual(context?.searchWasFocused, true)
        XCTAssertEqual(nav.location, .grid)
    }
    func testRejectedAdmissionAndTeardownCannotMountOrRestartPreview() async {
        let (nav, owner, surface, host) = await make()
        defer { owner.teardown(); surface.teardown(); _ = host }
        nav.canNavigate = { false }
        XCTAssertFalse(nav.beginTransition())
        XCTAssertFalse(owner.isOpen)
        nav.canNavigate = { true }
        nav.canEnterFromGrid = { false }
        XCTAssertFalse(nav.beginTransition())
        nav.teardown()
        nav.canEnterFromGrid = { true }
        XCTAssertFalse(nav.beginTransition())
        XCTAssertNil(surface.supplementalFrameStep)
        XCTAssertNil(surface.supplementalFrameDemand)
    }
    func testNativeCancellationValuePathEndsPreviewAndInputOwnership() async {
        let (nav, owner, surface, host) = await make()
        defer { nav.teardown(); owner.teardown(); surface.teardown(); _ = host }
        var previewVisible = false
        nav.setGridPreviewVisible = { previewVisible = $0 }
        XCTAssertTrue(nav.beginTransition())
        nav.handleParentInput(phase: .began, momentumPhase: [], deltaX: 0, deltaY: 0,
            isDirectionInverted: true, timestamp: 0)
        nav.handleParentInput(phase: .changed, momentumPhase: [], deltaX: 60, deltaY: 0,
            isDirectionInverted: true, timestamp: 0.1)
        XCTAssertTrue(nav.isTransitioning)
        nav.handleParentInput(phase: .cancelled, momentumPhase: [], deltaX: 0, deltaY: 0,
            isDirectionInverted: true, timestamp: 0.2)
        XCTAssertFalse(nav.isTransitioning)
        XCTAssertFalse(owner.isOpen)
        XCTAssertFalse(previewVisible)
        XCTAssertFalse(nav.pager.needsFrames)
        XCTAssertEqual(surface.core.committedPage, 0)
    }
}
