import AppGridUI
import AppKit
import PagingUI
import XCTest
@testable import PagingPrototypeApp

private actor LeadingLibraryRouteOwnershipStore: AppLibraryPersisting {
    func load() -> AppLibraryLoadResult { .loaded(.init(enabled: true)) }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) -> AppLibrarySaveResult {
        .saved
    }
}

/// Value-only routing checks: no synthesized events, windows, or automatic frame driver.
@MainActor
final class LeadingLibraryRouteOwnershipTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let surface: PagingSurface
        let preferences: AppLibraryPreferencesCoordinator
        let owner: AppLibraryOwnerController
        let host: NSView
        let navigator: LeadingLibraryNavigator

        init() {
            surface = PagingSurface(pageCount: 4, pageWidth: 1000)
            surface.frameDriver = nil
            preferences = AppLibraryPreferencesCoordinator(store: LeadingLibraryRouteOwnershipStore())
            owner = AppLibraryOwnerController(preferences: preferences, strings: .init(language: .english))
            host = NSView(frame: .init(x: 0, y: 0, width: 1000, height: 700))
            owner.canTransition = { true }
            owner.captureGrid = { .init(query: "", page: 0, selection: nil, searchWasFocused: false) }
            owner.attach(to: host)
            navigator = LeadingLibraryNavigator(surface: surface, owner: owner)
            navigator.canNavigate = { true }
            navigator.canEnterFromGrid = { true }
            navigator.width = { 1000 }
            owner.onPresentationChange = { [weak navigator] in navigator?.ownerDidChange() }
        }

        func route(_ phase: NSEvent.Phase = [], x: CGFloat = 0, y: CGFloat = 0,
                   momentum: NSEvent.Phase = []) -> LeadingLibraryScrollDecision {
            navigator.routeScrollInput(phase: phase, momentumPhase: momentum,
                deltaX: x, deltaY: y, isDirectionInverted: true)
        }

        func teardown() {
            navigator.teardown()
            owner.teardown()
            surface.teardown()
        }
    }

    private func makeFixture() async -> Fixture {
        let fixture = Fixture()
        await fixture.preferences.loadIfNeeded()
        return fixture
    }

    private func assertDecision(_ decision: LeadingLibraryScrollDecision,
                                _ destination: LeadingLibraryScrollRouter.Destination,
                                consumes: Bool,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(decision.destination, destination, file: file, line: line)
        XCTAssertEqual(decision.consumesOriginalEvent, consumes, file: file, line: line)
    }

    func testButtonEntryAfterGridEndDrainsLateMomentumUntilNewBegin() async {
        let f = await makeFixture()
        defer { f.teardown() }

        assertDecision(f.route(.began), .hold, consumes: true)
        assertDecision(f.route(.changed, x: -20), .grid, consumes: false)
        assertDecision(f.route(.ended), .grid, consumes: false)

        XCTAssertTrue(f.owner.enter())
        XCTAssertTrue(f.owner.isOpen)
        XCTAssertEqual(f.navigator.location, .library)
        assertDecision(f.route(x: -12, momentum: .began), .drain, consumes: true)
        assertDecision(f.route(x: -8, momentum: .changed), .drain, consumes: true)
        assertDecision(f.route(momentum: .ended), .drain, consumes: true)
        assertDecision(f.route(.changed, x: -4), .drain, consumes: true)

        assertDecision(f.route(.began), .hold, consumes: true)
        assertDecision(f.route(.changed, y: 20), .native, consumes: false)
        XCTAssertTrue(f.owner.isOpen)
        XCTAssertEqual(f.surface.core.committedPage, 0)
    }

    func testHideDuringNativeLibraryStreamDrainsTailBeforeGridCanResume() async {
        let f = await makeFixture()
        defer { f.teardown() }

        XCTAssertTrue(f.owner.enter())
        XCTAssertEqual(f.navigator.location, .library)
        assertDecision(f.route(.began), .hold, consumes: true)
        assertDecision(f.route(.changed, y: 20), .native, consumes: false)

        f.owner.hide()
        XCTAssertFalse(f.owner.isOpen)
        XCTAssertEqual(f.navigator.location, .grid)
        assertDecision(f.route(.changed, y: 20), .drain, consumes: true)
        assertDecision(f.route(.ended), .drain, consumes: true)
        assertDecision(f.route(y: 12, momentum: .began), .drain, consumes: true)
        assertDecision(f.route(x: -20, momentum: .changed), .drain, consumes: true)
        assertDecision(f.route(momentum: .ended), .drain, consumes: true)
        assertDecision(f.route(.changed, x: -20), .drain, consumes: true)

        assertDecision(f.route(.began), .hold, consumes: true)
        assertDecision(f.route(.changed, x: -20), .grid, consumes: false)
        XCTAssertEqual(f.surface.core.committedPage, 0)
    }

    func testRevokedGridAdmissionDrainsSelectedStreamEvenAfterAdmissionReturns() async {
        let f = await makeFixture()
        defer { f.teardown() }

        assertDecision(f.route(.began), .hold, consumes: true)
        assertDecision(f.route(.changed, x: -20), .grid, consumes: false)
        f.navigator.canForwardGridInput = { false }
        assertDecision(f.route(.changed, x: -20), .drain, consumes: true)
        assertDecision(f.route(.ended), .drain, consumes: true)
        assertDecision(f.route(x: -12, momentum: .began), .drain, consumes: true)

        f.navigator.canForwardGridInput = { true }
        assertDecision(f.route(x: -8, momentum: .changed), .drain, consumes: true)
        assertDecision(f.route(momentum: .ended), .drain, consumes: true)
        assertDecision(f.route(.changed, x: -20), .drain, consumes: true)
        assertDecision(f.route(.began), .hold, consumes: true)
        assertDecision(f.route(.changed, x: -20), .grid, consumes: false)
    }

    func testIndependentWheelRecoversAfterGridAdmissionDrain() async {
        let f = await makeFixture()
        defer { f.teardown() }

        assertDecision(f.route(.began), .hold, consumes: true)
        assertDecision(f.route(.changed, x: -20), .grid, consumes: false)
        f.navigator.canForwardGridInput = { false }
        assertDecision(f.route(.ended), .drain, consumes: true)
        f.navigator.canForwardGridInput = { true }
        assertDecision(f.route(x: -8, momentum: .changed), .drain, consumes: true)
        assertDecision(f.route(momentum: .ended), .drain, consumes: true)

        // Empty direct and momentum phases identify a new independent wheel input.
        assertDecision(f.route(x: -20), .grid, consumes: false)
        assertDecision(f.route(x: 20), .parent, consumes: true)
    }

    func testGridOriginalEventsRemainAvailableToWindowDispatchForEntireStream() async {
        let f = await makeFixture()
        defer { f.teardown() }

        assertDecision(f.route(.began), .hold, consumes: true)
        assertDecision(f.route(.changed, x: -20), .grid, consumes: false)
        // Reversing direction cannot transfer an already selected grid stream.
        assertDecision(f.route(.changed, x: 20), .grid, consumes: false)
        assertDecision(f.route(.ended), .grid, consumes: false)
        assertDecision(f.route(x: 12, momentum: .began), .grid, consumes: false)
        assertDecision(f.route(x: 8, momentum: .changed), .grid, consumes: false)
        assertDecision(f.route(momentum: .ended), .grid, consumes: false)
    }

    func testNativeOriginalEventsRemainAvailableToNativeDispatchForEntireStream() async {
        let f = await makeFixture()
        defer { f.teardown() }

        XCTAssertTrue(f.owner.enter())
        assertDecision(f.route(.began), .hold, consumes: true)
        assertDecision(f.route(.changed, y: 20), .native, consumes: false)
        assertDecision(f.route(.changed, x: -20), .native, consumes: false)
        assertDecision(f.route(.ended), .native, consumes: false)
        assertDecision(f.route(y: 12, momentum: .began), .native, consumes: false)
        assertDecision(f.route(y: 8, momentum: .changed), .native, consumes: false)
        assertDecision(f.route(momentum: .ended), .native, consumes: false)
    }

    func testHeldParentAndDrainedInputsConsumeOriginalEvents() async {
        let f = await makeFixture()
        defer { f.teardown() }

        assertDecision(f.route(.began), .hold, consumes: true)
        assertDecision(f.route(.changed, x: 20), .parent, consumes: true)
        assertDecision(f.route(.ended), .parent, consumes: true)
        assertDecision(f.route(x: 12, momentum: .began), .parent, consumes: true)
        assertDecision(f.route(x: 8, momentum: .changed), .parent, consumes: true)
        assertDecision(f.route(momentum: .ended), .parent, consumes: true)

        f.navigator.cancel()
        assertDecision(f.route(.changed, x: -20), .drain, consumes: true)
        assertDecision(f.route(momentum: .ended), .drain, consumes: true)
    }

    func testIneligibleStreamPassesOriginalEventsThrough() async {
        let f = await makeFixture()
        defer { f.teardown() }

        f.navigator.canNavigate = { false }
        assertDecision(f.route(.began), .pass, consumes: false)
        assertDecision(f.route(.changed, x: 20), .pass, consumes: false)
        assertDecision(f.route(.ended), .pass, consumes: false)
    }
}
