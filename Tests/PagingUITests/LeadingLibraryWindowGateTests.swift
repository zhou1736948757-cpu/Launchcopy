import AppKit
import AppGridUI
import PagingUI
import XCTest
@testable import PagingPrototypeApp

private actor LeadingWindowGateStore: AppLibraryPersisting {
    func load() -> AppLibraryLoadResult { .loaded(.init(enabled: true)) }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) -> AppLibrarySaveResult { .saved }
}

/// Mirrors Window ordering with values only; no NSEvent, native dispatch or shown window.
@MainActor
final class LeadingLibraryWindowGateTests: XCTestCase {
    @MainActor
    private final class Fixture {
        enum Outcome: Equatable { case consumedByNavigator, suppressedGrid, native }
        let surface = PagingSurface(pageCount: 2, pageWidth: 1000)
        let preferences = AppLibraryPreferencesCoordinator(store: LeadingWindowGateStore())
        let owner: AppLibraryOwnerController
        let host = NSView(frame: .init(x: 0, y: 0, width: 1000, height: 700))
        let navigator: LeadingLibraryNavigator
        var gate = MainGridScrollSequenceGate()
        var available = true
        var lateGateVisits = 0
        init() {
            surface.frameDriver = nil
            owner = AppLibraryOwnerController(preferences: preferences, strings: .init(language: .english))
            owner.canTransition = { true }
            owner.captureGrid = { .init(query: "", page: 0, selection: nil, searchWasFocused: false) }
            owner.attach(to: host)
            navigator = LeadingLibraryNavigator(surface: surface, owner: owner)
            navigator.canNavigate = { [weak self] in self?.available == true }
            navigator.canEnterFromGrid = { true }
            navigator.canForwardGridInput = { [weak self] in self?.available == true && self?.owner.isOpen != true }
            navigator.width = { 1000 }
            owner.onPresentationChange = { [weak navigator] in navigator?.ownerDidChange() }
        }
        func dispatch(_ phase: NSEvent.Phase = [], momentum: NSEvent.Phase = [],
                      x: CGFloat = 0, y: CGFloat = 0) -> Outcome {
            gate.observeBoundary(phase: phase, momentumPhase: momentum, inputIsAvailable: available)
            let decision = navigator.routeScrollInput(phase: phase, momentumPhase: momentum,
                deltaX: x, deltaY: y, isDirectionInverted: true)
            if decision.consumesOriginalEvent { return .consumedByNavigator }
            if owner.isOpen { return .native } // Library's early native branch precedes grid gate.
            lateGateVisits += 1
            return gate.shouldSuppress(phase: phase, momentumPhase: momentum, inputIsAvailable: available)
                ? .suppressedGrid : .native
        }
        func teardown() { navigator.teardown(); owner.teardown(); surface.teardown() }
    }
    private func make() async -> Fixture {
        let fixture = Fixture()
        await fixture.preferences.loadIfNeeded()
        return fixture
    }
    func testUnreadableThenReadableHeldBeginLetsGridChangesAndTailThrough() async {
        let f = await make(); defer { f.teardown() }
        f.available = false
        XCTAssertEqual(f.dispatch(.began), .suppressedGrid)
        XCTAssertTrue(f.gate.isSuppressing)
        f.available = true
        let visits = f.lateGateVisits
        XCTAssertEqual(f.dispatch(.began), .consumedByNavigator)
        XCTAssertEqual(f.lateGateVisits, visits, "A held begin never visits the late gate")
        XCTAssertFalse(f.gate.isSuppressing, "Fresh boundary must be observed before parent holds it")
        XCTAssertEqual(f.dispatch(.changed, x: -20), .native)
        XCTAssertEqual(f.dispatch(.ended), .native)
        XCTAssertEqual(f.dispatch(momentum: .began, x: -8), .native)
        XCTAssertEqual(f.dispatch(momentum: .changed, x: -4), .native)
        XCTAssertEqual(f.dispatch(momentum: .ended), .native)
    }
    func testReadabilityRecoveryAloneDoesNotReleaseOldStream() async {
        let f = await make(); defer { f.teardown() }
        f.available = false
        XCTAssertEqual(f.dispatch(.began), .suppressedGrid)
        f.available = true
        XCTAssertEqual(f.dispatch(.changed, x: -20), .suppressedGrid)
        XCTAssertEqual(f.dispatch(.ended), .suppressedGrid)
        XCTAssertEqual(f.dispatch(momentum: .began, x: -10), .suppressedGrid)
        XCTAssertEqual(f.dispatch(momentum: .changed, x: -5), .suppressedGrid)
        XCTAssertEqual(f.dispatch(momentum: .ended), .suppressedGrid)
        XCTAssertTrue(f.gate.isSuppressing)
    }
    func testConsumedParentAndDrainedEventsNeverVisitLateGridGate() async {
        let f = await make(); defer { f.teardown() }
        XCTAssertEqual(f.dispatch(.began), .consumedByNavigator)
        XCTAssertEqual(f.dispatch(.changed, x: 20), .consumedByNavigator)
        XCTAssertEqual(f.lateGateVisits, 0)
        f.navigator.cancel()
        XCTAssertEqual(f.dispatch(.changed, x: -20), .consumedByNavigator)
        XCTAssertEqual(f.dispatch(momentum: .ended), .consumedByNavigator)
        XCTAssertEqual(f.lateGateVisits, 0)
    }
    func testLibraryNativeInputBypassesLateGridGate() async {
        let f = await make(); defer { f.teardown() }
        XCTAssertTrue(f.owner.enter())
        XCTAssertEqual(f.dispatch(.began), .consumedByNavigator)
        XCTAssertEqual(f.dispatch(.changed, y: 20), .native)
        XCTAssertEqual(f.lateGateVisits, 0)
    }
    func testAvailableFreshBoundariesResetBeforeLateGate() {
        for (phase, momentum): (NSEvent.Phase, NSEvent.Phase) in [(.began, []), (.mayBegin, []), ([], [])] {
            var gate = MainGridScrollSequenceGate()
            XCTAssertTrue(gate.shouldSuppress(phase: .began, momentumPhase: [], inputIsAvailable: false))
            gate.observeBoundary(phase: phase, momentumPhase: momentum, inputIsAvailable: true)
            XCTAssertFalse(gate.isSuppressing)
        }
    }
    func testUnavailableFreshBoundariesCannotResetSuppression() {
        for phase: NSEvent.Phase in [.began, .mayBegin, []] {
            var gate = MainGridScrollSequenceGate()
            _ = gate.shouldSuppress(phase: .began, momentumPhase: [], inputIsAvailable: false)
            gate.observeBoundary(phase: phase, momentumPhase: [], inputIsAvailable: false)
            XCTAssertTrue(gate.isSuppressing)
        }
    }
    func testOldChangesEndsAndMomentumCannotResetSuppression() {
        for (phase, momentum): (NSEvent.Phase, NSEvent.Phase) in [(.changed, []), (.ended, []), ([], .began), ([], .changed), ([], .ended)] {
            var gate = MainGridScrollSequenceGate()
            _ = gate.shouldSuppress(phase: .began, momentumPhase: [], inputIsAvailable: false)
            gate.observeBoundary(phase: phase, momentumPhase: momentum, inputIsAvailable: true)
            XCTAssertTrue(gate.isSuppressing)
        }
    }
}
