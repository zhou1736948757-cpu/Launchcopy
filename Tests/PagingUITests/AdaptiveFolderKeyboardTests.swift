import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
@testable import PagingPrototypeApp
import XCTest

@MainActor
final class AdaptiveFolderKeyboardTests: XCTestCase {
    @MainActor
    private struct Fixture {
        let entry: FolderEntry
        let state: FolderOpenState
        let keyboard: KeyboardFocusController
        let overlay: FolderOverlayView
        let pipeline: IconPipeline

        func refresh() {
            guard let entry = state.openEntry else { return }
            overlay.membersPerPage = state.membersPerPage
            overlay.configure(entry: entry, innerPage: state.innerPage, reduceMotion: true) { _ in "Member" }
            keyboard.reconcileFolderLayout()
        }

        func reflow(columns: Int, capacity: Int, available: Bool = true) {
            state.reconfigure(columns: columns, membersPerPage: capacity,
                              anchor: keyboard.focusedFolderMember, isAvailable: available)
            refresh()
        }

        func changePageExplicitly(to page: Int) {
            keyboard.clearInnerSelectionForPageChange()
            state.setInnerPage(page)
            refresh()
        }
    }

    private func makeFixture(count: Int = 35, columns: Int = 5, capacity: Int = 15) -> Fixture {
        let entry = FolderEntry(id: FolderID(), title: "Adaptive keyboard fixture", members: (0..<count).map {
            AppID.bundleIdentifier("fixture.adaptive.keyboard\($0)")
        })
        let state = FolderOpenState(membersPerPage: capacity, columns: columns)
        // Deliberately keep the outer grid at five columns for three-column folder tests.
        let keyboard = KeyboardFocusController(columns: 5)
        let pipeline = IconPipeline(loader: RecordingIconLoader(), limits: .init())
        let overlay = FolderOverlayView(iconPipeline: pipeline, iconPointSize: 48, displayScale: 1)
        overlay.frame = NSRect(x: 0, y: 0, width: 1400, height: 1000)
        overlay.membersPerPage = capacity
        keyboard.folderOpenStateProvider = { state }
        keyboard.folderOverlayProvider = { [weak overlay] in overlay }
        keyboard.onOpenFolder = { [weak overlay] _ in
            state.open(entry)
            overlay?.configure(entry: entry, innerPage: state.innerPage, reduceMotion: true) { _ in "Member" }
        }
        keyboard.onInnerPageChange = { [weak keyboard, weak overlay] page in
            state.setInnerPage(page)
            overlay?.configure(entry: entry, innerPage: state.innerPage, reduceMotion: true) { _ in "Member" }
            keyboard?.reconcileFolderLayout()
        }
        keyboard.openFolderFromClick(entry.id)
        return Fixture(entry: entry, state: state, keyboard: keyboard, overlay: overlay, pipeline: pipeline)
    }

    private func key(_ code: UInt16) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                         windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
                         isARepeat: false, keyCode: code)!
    }

    private func assertFocusedSlots(_ expected: [Int], in fixture: Fixture,
                                    file: StaticString = #filePath, line: UInt = #line) {
        let actual = (0..<fixture.overlay.memberCellCount).filter {
            fixture.overlay.memberCell(at: $0)?.isFocused == true
        }
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    func testOpenAndUnselectedReflowDoNotManufactureSelectionButKeepFirstArrowBehavior() {
        let fixture = makeFixture()
        defer { fixture.pipeline.shutdown() }
        XCTAssertNil(fixture.keyboard.focusedFolderMember)
        assertFocusedSlots([], in: fixture)

        fixture.reflow(columns: 3, capacity: 9)
        fixture.keyboard.reconcileFolderLayout()
        XCTAssertNil(fixture.keyboard.focusedFolderMember)
        assertFocusedSlots([], in: fixture)

        fixture.keyboard.keyDown(with: key(124))
        XCTAssertEqual(fixture.keyboard.focusedFolderMember, fixture.entry.members[1])
        assertFocusedSlots([1], in: fixture)
        XCTAssertNil(fixture.keyboard.focusModel.current)
    }

    func testThreeColumnTypewriterDownAndUpTransitionsUseFolderSnapshot() {
        let fixture = makeFixture(columns: 3, capacity: 9)
        defer { fixture.pipeline.shutdown() }
        // Column-first traversal: 0 -> 3 -> 6 -> 1 -> 4 -> 7 -> 2 -> 5 -> 8 -> next page 9.
        for expected in [3, 6, 1, 4, 7, 2, 5, 8, 9] {
            fixture.keyboard.keyDown(with: key(125))
            XCTAssertEqual(fixture.keyboard.focusedFolderMember, fixture.entry.members[expected])
            XCTAssertEqual(fixture.state.innerPage, expected / 9)
            assertFocusedSlots([expected % 9], in: fixture)
        }

        // The reverse crossing keeps the destination selection rather than clearing it.
        fixture.keyboard.keyDown(with: key(126))
        XCTAssertEqual(fixture.state.innerPage, 0)
        XCTAssertEqual(fixture.keyboard.focusedFolderMember, fixture.entry.members[8])
        assertFocusedSlots([8], in: fixture)
        fixture.keyboard.keyDown(with: key(126))
        XCTAssertEqual(fixture.keyboard.focusedFolderMember, fixture.entry.members[5])
        fixture.keyboard.keyDown(with: key(126))
        XCTAssertEqual(fixture.keyboard.focusedFolderMember, fixture.entry.members[2])
        fixture.keyboard.keyDown(with: key(126))
        XCTAssertEqual(fixture.keyboard.focusedFolderMember, fixture.entry.members[7])
        assertFocusedSlots([7], in: fixture)
    }

    func testCapacityFifteenKeyboardCrossingRetainsDestinationForReturn() {
        let fixture = makeFixture()
        defer { fixture.pipeline.shutdown() }
        var activated: [AppID] = []
        fixture.keyboard.onActivateMember = { activated.append($0) }
        for _ in 0..<15 { fixture.keyboard.keyDown(with: key(124)) }

        XCTAssertEqual(fixture.state.innerPage, 1)
        XCTAssertEqual(fixture.keyboard.focusedFolderMember, fixture.entry.members[15])
        assertFocusedSlots([0], in: fixture)
        fixture.keyboard.keyDown(with: key(36))
        XCTAssertEqual(activated, [fixture.entry.members[15]])

        fixture.keyboard.keyDown(with: key(123))
        XCTAssertEqual(fixture.state.innerPage, 0)
        XCTAssertEqual(fixture.keyboard.focusedFolderMember, fixture.entry.members[14])
        assertFocusedSlots([14], in: fixture)
    }

    func testExplicitPageTwoClearsSelectionAndReturnUsesCurrentPageFirst() {
        for (columns, capacity) in [(5, 15), (3, 9)] {
            let fixture = makeFixture(columns: columns, capacity: capacity)
            defer { fixture.pipeline.shutdown() }
            var activated: [AppID] = []
            fixture.keyboard.onActivateMember = { activated.append($0) }
            fixture.keyboard.keyDown(with: key(124))
            assertFocusedSlots([1], in: fixture)

            fixture.keyboard.clearInnerSelectionForPageChange()
            XCTAssertNil(fixture.keyboard.focusedFolderMember)
            assertFocusedSlots([], in: fixture)
            fixture.state.setInnerPage(1)
            fixture.refresh()
            fixture.keyboard.keyDown(with: key(36))

            XCTAssertEqual(activated, [fixture.entry.members[capacity]])
            XCTAssertNil(fixture.keyboard.focusedFolderMember, "Return does not create a selection")
            assertFocusedSlots([], in: fixture)
        }
    }

    func testFirstArrowAfterExplicitPageChangeSeedsCurrentPageBeforeMoving() {
        let fixture = makeFixture(columns: 3, capacity: 9)
        defer { fixture.pipeline.shutdown() }
        fixture.keyboard.keyDown(with: key(124))
        fixture.changePageExplicitly(to: 1)

        fixture.keyboard.keyDown(with: key(125))
        XCTAssertEqual(fixture.keyboard.focusedFolderMember, fixture.entry.members[9])
        assertFocusedSlots([0], in: fixture)
        fixture.keyboard.keyDown(with: key(125))
        XCTAssertEqual(fixture.keyboard.focusedFolderMember, fixture.entry.members[12])
        assertFocusedSlots([3], in: fixture)
    }

    func testOffPageSelectionNeverHighlightsOrActivatesItsOldSlot() {
        let fixture = makeFixture()
        defer { fixture.pipeline.shutdown() }
        var activated: [AppID] = []
        fixture.keyboard.onActivateMember = { activated.append($0) }
        fixture.keyboard.keyDown(with: key(124))
        // Defensive coverage for a caller that changes the page without the explicit clear seam.
        fixture.state.setInnerPage(1)
        fixture.refresh()

        XCTAssertEqual(fixture.keyboard.focusedFolderMember, fixture.entry.members[1])
        assertFocusedSlots([], in: fixture)
        fixture.keyboard.keyDown(with: key(36))
        XCTAssertEqual(activated, [fixture.entry.members[15]])
    }

    func testUnavailablePresentationBlocksArrowReturnAndKeyEquivalentWithoutLosingAnchor() {
        let fixture = makeFixture(columns: 3, capacity: 9)
        defer { fixture.pipeline.shutdown() }
        var activated: [AppID] = []
        var pageChanges: [Int] = []
        fixture.keyboard.onActivateMember = { activated.append($0) }
        fixture.keyboard.keyDown(with: key(125))
        let selected = fixture.entry.members[3]
        fixture.keyboard.onInnerPageChange = { pageChanges.append($0) }
        fixture.reflow(columns: 3, capacity: 9, available: false)
        let generation = fixture.state.generation

        for code in [UInt16(123), 124, 125, 126, 36, 76] {
            fixture.keyboard.keyDown(with: key(code))
        }
        XCTAssertTrue(fixture.keyboard.performKeyEquivalent(with: key(36)))
        XCTAssertTrue(fixture.keyboard.performKeyEquivalent(with: key(76)))
        XCTAssertTrue(activated.isEmpty)
        XCTAssertTrue(pageChanges.isEmpty)
        XCTAssertEqual(fixture.state.generation, generation)
        XCTAssertEqual(fixture.state.innerPage, 0)
        XCTAssertEqual(fixture.keyboard.focusedFolderMember, selected)
        assertFocusedSlots([], in: fixture)

        fixture.reflow(columns: 3, capacity: 9)
        XCTAssertEqual(fixture.keyboard.focusedFolderMember, selected)
        assertFocusedSlots([3], in: fixture)
        fixture.keyboard.keyDown(with: key(36))
        XCTAssertEqual(activated, [selected])
    }

    func testUnavailableUnselectedFolderDoesNotSeedFocusOrLaunch() {
        let fixture = makeFixture()
        defer { fixture.pipeline.shutdown() }
        var activated: [AppID] = []
        fixture.keyboard.onActivateMember = { activated.append($0) }
        fixture.reflow(columns: 5, capacity: 15, available: false)
        fixture.keyboard.keyDown(with: key(124))
        fixture.keyboard.keyDown(with: key(36))
        XCTAssertTrue(activated.isEmpty)
        XCTAssertNil(fixture.keyboard.focusedFolderMember)
        assertFocusedSlots([], in: fixture)

        fixture.reflow(columns: 5, capacity: 15)
        fixture.keyboard.keyDown(with: key(124))
        XCTAssertEqual(fixture.keyboard.focusedFolderMember, fixture.entry.members[1])
    }

    func testReflowPreservesActualIdentityAndRemapsPageAndSlotInBothDirections() {
        let fixture = makeFixture()
        defer { fixture.pipeline.shutdown() }
        var activated: [AppID] = []
        fixture.keyboard.onActivateMember = { activated.append($0) }
        for _ in 0..<26 { fixture.keyboard.keyDown(with: key(124)) }
        XCTAssertEqual(fixture.keyboard.focusedFolderMember, fixture.entry.members[26])
        XCTAssertEqual(fixture.state.innerPage, 1)

        fixture.reflow(columns: 3, capacity: 9)
        XCTAssertEqual(fixture.state.innerPage, 2)
        XCTAssertEqual(fixture.keyboard.focusedFolderMember, fixture.entry.members[26])
        assertFocusedSlots([8], in: fixture)
        fixture.keyboard.keyDown(with: key(36))
        XCTAssertEqual(activated, [fixture.entry.members[26]])

        fixture.reflow(columns: 5, capacity: 15)
        XCTAssertEqual(fixture.state.innerPage, 1)
        XCTAssertEqual(fixture.keyboard.focusedFolderMember, fixture.entry.members[26])
        assertFocusedSlots([11], in: fixture)
    }

    func testUnselectedLastPageReflowPreservesVisibleAnchorWithoutManufacturingFocus() {
        let fixture = makeFixture()
        defer { fixture.pipeline.shutdown() }
        fixture.changePageExplicitly(to: 2)
        fixture.reflow(columns: 3, capacity: 9)

        XCTAssertEqual(fixture.state.innerPage, 3)
        XCTAssertTrue(fixture.state.members(onPage: 3).contains(fixture.entry.members[30]))
        XCTAssertNil(fixture.keyboard.focusedFolderMember)
        assertFocusedSlots([], in: fixture)
        var activated: [AppID] = []
        fixture.keyboard.onActivateMember = { activated.append($0) }
        fixture.keyboard.keyDown(with: key(36))
        XCTAssertEqual(activated, [fixture.entry.members[27]])
    }

    func testRemovedSelectionClearsAndReturnUsesVisibleSurvivor() {
        let fixture = makeFixture()
        defer { fixture.pipeline.shutdown() }
        for _ in 0..<34 { fixture.keyboard.keyDown(with: key(124)) }
        let surviving = FolderEntry(id: fixture.entry.id, title: fixture.entry.title,
                                    members: Array(fixture.entry.members.prefix(16)))
        fixture.state.updateOpenEntry(surviving)
        fixture.reflow(columns: 3, capacity: 9)

        XCTAssertNil(fixture.keyboard.focusedFolderMember)
        XCTAssertEqual(fixture.state.innerPage, 1)
        assertFocusedSlots([], in: fixture)
        var activated: [AppID] = []
        fixture.keyboard.onActivateMember = { activated.append($0) }
        fixture.keyboard.keyDown(with: key(36))
        XCTAssertEqual(activated, [fixture.entry.members[9]])
    }

    func testEmptyFolderHasNoSelectionAndNoActivation() {
        let fixture = makeFixture(count: 0, columns: 3, capacity: 9)
        defer { fixture.pipeline.shutdown() }
        var activated: [AppID] = []
        fixture.keyboard.onActivateMember = { activated.append($0) }
        fixture.keyboard.reconcileFolderLayout()
        fixture.keyboard.keyDown(with: key(125))
        fixture.keyboard.keyDown(with: key(36))

        XCTAssertNil(fixture.keyboard.focusedFolderMember)
        XCTAssertEqual(fixture.state.innerPage, 0)
        XCTAssertTrue(activated.isEmpty)
        assertFocusedSlots([], in: fixture)
    }
}
