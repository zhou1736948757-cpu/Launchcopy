import AppCatalogCore
@testable import AppGridUI
import XCTest

final class AdaptiveFolderOpenStateTests: XCTestCase {
    private func makeEntry(count: Int) -> FolderEntry {
        FolderEntry(id: FolderID(), title: "Adaptive fixture", members: (0..<count).map {
            AppID.bundleIdentifier("fixture.adaptive.member\($0)")
        })
    }

    func testLegacyDefaultsAndPositiveNormalization() {
        let legacy = FolderOpenState()
        XCTAssertEqual(legacy.membersPerPage, 35)
        XCTAssertEqual(legacy.columns, 5)
        XCTAssertTrue(legacy.isMemberPresentationAvailable)

        let state = FolderOpenState(membersPerPage: 0, columns: -3)
        XCTAssertEqual(state.membersPerPage, 1)
        XCTAssertEqual(state.columns, 1)
        state.reconfigure(columns: -1, membersPerPage: -8, anchor: nil, isAvailable: true)
        XCTAssertEqual(state.generation, 0, "Equivalent normalized snapshots are no-ops")
    }

    func testAdaptiveCapacitiesPresentEveryMemberExactlyOnceInCanonicalOrder() {
        for count in [0, 1, 9, 15, 16, 35, 36, 73] {
            let entry = makeEntry(count: count)
            let state = FolderOpenState()
            state.open(entry)
            for (columns, capacity) in [(5, 15), (3, 9)] {
                state.reconfigure(columns: columns, membersPerPage: capacity,
                                  anchor: nil, isAvailable: true)
                let expectedPages = count == 0 ? 0 : (count - 1) / capacity + 1
                XCTAssertEqual(state.innerPageCount, expectedPages)
                let presented = (0..<state.innerPageCount).flatMap { state.members(onPage: $0) }
                XCTAssertEqual(presented, entry.members)
                XCTAssertEqual(state.openEntry, entry)
                XCTAssertTrue(state.members(onPage: state.innerPageCount).isEmpty)
            }
        }
    }

    func testFocusedAnchorSelectsItsNewPageRatherThanTheOldLeadingMember() {
        let entry = makeEntry(count: 35)
        let state = FolderOpenState(membersPerPage: 15)
        state.open(entry)
        state.setInnerPage(1)
        let generation = state.generation

        state.reconfigure(columns: 3, membersPerPage: 9, anchor: entry.members[26], isAvailable: true)

        XCTAssertEqual(state.innerPage, 2)
        XCTAssertEqual(state.members(onPage: 2).last, entry.members[26])
        XCTAssertEqual(state.generation, generation + 1)
        XCTAssertEqual(state.openEntry, entry)
    }

    func testNoFocusRetainsThePreviouslyVisibleLeadingMember() {
        let entry = makeEntry(count: 35)
        let state = FolderOpenState(membersPerPage: 15)
        state.open(entry)
        state.setInnerPage(1)

        state.reconfigure(columns: 3, membersPerPage: 9, anchor: nil, isAvailable: true)

        XCTAssertEqual(state.innerPage, 1)
        XCTAssertTrue(state.members(onPage: state.innerPage).contains(entry.members[15]))
        XCTAssertEqual(state.openEntry, entry)
    }

    func testLastPartialPageAnchorsAcrossShrinkAndExpansion() {
        let entry = makeEntry(count: 35)
        let state = FolderOpenState(membersPerPage: 15)
        state.open(entry)
        state.setInnerPage(2)

        state.reconfigure(columns: 3, membersPerPage: 9, anchor: nil, isAvailable: true)
        XCTAssertEqual(state.innerPage, 3)
        XCTAssertEqual(state.members(onPage: 3), Array(entry.members[27..<35]))

        state.reconfigure(columns: 5, membersPerPage: 15, anchor: entry.members[34], isAvailable: true)
        XCTAssertEqual(state.innerPage, 2)
        XCTAssertEqual(state.members(onPage: 2), Array(entry.members[30..<35]))
        XCTAssertEqual(state.openEntry, entry)
    }

    func testMissingAnchorFallsBackToTheOldVisibleLeadingMember() {
        let entry = makeEntry(count: 35)
        let state = FolderOpenState(membersPerPage: 15)
        state.open(entry)
        state.setInnerPage(2)

        state.reconfigure(columns: 3, membersPerPage: 9,
                          anchor: .bundleIdentifier("fixture.removed"), isAvailable: true)

        XCTAssertEqual(state.innerPage, 3)
        XCTAssertTrue(state.members(onPage: state.innerPage).contains(entry.members[30]))
    }

    func testDeletedAnchorAfterMembershipUpdateUsesClampedSurvivingPage() {
        let entry = makeEntry(count: 35)
        let state = FolderOpenState(membersPerPage: 15)
        state.open(entry)
        state.setInnerPage(2)
        let surviving = FolderEntry(id: entry.id, title: entry.title,
                                    members: Array(entry.members.prefix(16)))
        state.updateOpenEntry(surviving)
        let generation = state.generation

        state.reconfigure(columns: 3, membersPerPage: 9, anchor: entry.members[34], isAvailable: true)

        XCTAssertEqual(state.innerPage, 1)
        XCTAssertEqual(state.members(onPage: 1).last, entry.members[15])
        XCTAssertEqual(state.openEntry, surviving)
        XCTAssertEqual(state.generation, generation + 1)
    }

    func testIdenticalSnapshotDoesNotRepageOrInvalidateGenerationForAnotherAnchor() {
        let entry = makeEntry(count: 35)
        let state = FolderOpenState(membersPerPage: 9, columns: 3)
        state.open(entry)
        state.setInnerPage(2)
        let generation = state.generation

        state.reconfigure(columns: 3, membersPerPage: 9, anchor: entry.members[0], isAvailable: true)
        state.reconfigure(columns: 3, membersPerPage: 9, anchor: nil, isAvailable: true)

        XCTAssertEqual(state.innerPage, 2)
        XCTAssertEqual(state.generation, generation)
    }

    func testColumnCapacityAndAvailabilityChangesEachInvalidateExactlyOnce() {
        let entry = makeEntry(count: 35)
        let state = FolderOpenState(membersPerPage: 15)
        state.open(entry)
        state.setInnerPage(2)
        var generation = state.generation

        state.reconfigure(columns: 3, membersPerPage: 15, anchor: nil, isAvailable: true)
        generation += 1
        XCTAssertEqual(state.generation, generation)
        state.reconfigure(columns: 3, membersPerPage: 9, anchor: nil, isAvailable: true)
        generation += 1
        XCTAssertEqual(state.generation, generation)
        state.reconfigure(columns: 3, membersPerPage: 9, anchor: entry.members[34], isAvailable: false)
        generation += 1
        XCTAssertEqual(state.generation, generation)
        XCTAssertFalse(state.isMemberPresentationAvailable)
        XCTAssertEqual(state.innerPage, 3)

        state.reconfigure(columns: 3, membersPerPage: 9, anchor: nil, isAvailable: false)
        XCTAssertEqual(state.generation, generation)
        state.reconfigure(columns: 3, membersPerPage: 9, anchor: entry.members[34], isAvailable: true)
        XCTAssertEqual(state.generation, generation + 1)
        XCTAssertTrue(state.isMemberPresentationAvailable)
        XCTAssertEqual(state.innerPage, 3)
        XCTAssertEqual(state.openEntry, entry)
    }

    func testClosedAndEmptyReconfigurationRemainOnPageZero() {
        let state = FolderOpenState()
        state.reconfigure(columns: 3, membersPerPage: 9, anchor: nil, isAvailable: false)
        XCTAssertFalse(state.isOpen)
        XCTAssertEqual(state.innerPage, 0)
        XCTAssertEqual(state.innerPageCount, 0)
        XCTAssertEqual(state.generation, 1)

        state.open(makeEntry(count: 0))
        state.reconfigure(columns: 5, membersPerPage: 15, anchor: nil, isAvailable: true)
        XCTAssertTrue(state.isOpen)
        XCTAssertEqual(state.innerPage, 0)
        XCTAssertEqual(state.innerPageCount, 0)
        XCTAssertTrue(state.members(onPage: 0).isEmpty)
    }

    func testLargePositiveCapacityAndInvalidPageQueriesDoNotOverflow() {
        let entry = makeEntry(count: 35)
        let state = FolderOpenState(membersPerPage: 15)
        state.open(entry)
        state.setInnerPage(2)
        state.reconfigure(columns: Int.max, membersPerPage: Int.max, anchor: nil, isAvailable: true)

        XCTAssertEqual(state.innerPage, 0)
        XCTAssertEqual(state.innerPageCount, 1)
        XCTAssertEqual(state.members(onPage: 0), entry.members)
        XCTAssertTrue(state.members(onPage: Int.max).isEmpty)
        XCTAssertTrue(state.members(onPage: Int.min).isEmpty)
    }
}
