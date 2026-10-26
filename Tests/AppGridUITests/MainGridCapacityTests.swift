import AppCatalogCore
import Foundation
import XCTest
@testable import AppGridUI

final class MainGridCapacityTests: XCTestCase {
    private func identities(_ count: Int) -> [TopLevelEntryIdentity] {
        (0..<count).map { .app(.bundleIdentifier("fixture.capacity.\($0)")) }
    }

    func testDefaultEndpointsAndEverySupportedPairRoundTrip() throws {
        XCTAssertEqual(MainGridCapacity.default.columns, 5)
        XCTAssertEqual(MainGridCapacity.default.rows, 7)
        XCTAssertEqual(MainGridCapacity.default.itemsPerPage, 35)
        XCTAssertEqual(MainGridCapacity(columns: 3, rows: 3)?.itemsPerPage, 9)
        XCTAssertEqual(MainGridCapacity(columns: 8, rows: 8)?.itemsPerPage, 64)
        for columns in 3...8 {
            for rows in 3...8 {
                let capacity = try XCTUnwrap(MainGridCapacity(columns: columns, rows: rows))
                XCTAssertEqual(capacity.itemsPerPage, columns * rows)
                XCTAssertEqual(try JSONDecoder().decode(MainGridCapacity.self, from: JSONEncoder().encode(capacity)), capacity)
            }
        }
    }

    func testInvalidDimensionsIncludingExtremesAreRejectedBeforeArithmetic() {
        for invalid in [Int.min, -1, 0, 2, 9, Int.max] {
            XCTAssertNil(MainGridCapacity(columns: invalid, rows: 7))
            XCTAssertNil(MainGridCapacity(columns: 5, rows: invalid))
            XCTAssertNil(MainGridCapacity(columns: invalid, rows: invalid))
        }
    }

    func testInvalidDecodedPairsCannotBypassValidation() {
        let fixtures = [
            #"{"columns":2,"rows":7}"#,
            #"{"columns":5,"rows":9}"#,
            #"{"columns":9223372036854775807,"rows":9223372036854775807}"#,
            #"{"columns":-9223372036854775808,"rows":7}"#,
            #"{"columns":999999999999999999999999999999999999,"rows":7}"#,
            #"{"columns":true,"rows":7}"#,
            #"{"columns":"5","rows":7}"#,
            #"{"columns":5.5,"rows":7}"#,
            #"{"columns":5,"rows":null}"#,
            #"{"columns":5}"#,
            #"null"#
        ]
        for fixture in fixtures {
            XCTAssertThrowsError(try JSONDecoder().decode(MainGridCapacity.self, from: Data(fixture.utf8)))
        }
    }

    func testSameProductDifferentShapeRemainsDistinct() throws {
        let tall = try XCTUnwrap(MainGridCapacity(columns: 3, rows: 8))
        let wide = try XCTUnwrap(MainGridCapacity(columns: 8, rows: 3))
        XCTAssertEqual(tall.itemsPerPage, wide.itemsPerPage)
        XCTAssertNotEqual(tall, wide)
    }

    func testVisibleSelectedFolderAnchorsAcrossSmallerAndLargerPages() throws {
        var entries = identities(90)
        let folder = TopLevelEntryIdentity.folder(FolderID())
        entries[48] = folder
        for capacity in [try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3)),
                         try XCTUnwrap(MainGridCapacity(columns: 8, rows: 8))] {
            let result = MainGridCapacityAnchorRelocation.relocate(
                previousEntries: entries, currentEntries: entries, currentPageIndex: 1,
                selectedIdentity: folder, from: .default, to: capacity)
            XCTAssertEqual(result.anchorIdentity, folder)
            XCTAssertEqual(result.pageIndex, 48 / capacity.itemsPerPage)
            XCTAssertEqual(result.selectedIdentity, folder)
            XCTAssertEqual(result.selectedPageIndex, 48 / capacity.itemsPerPage)
            XCTAssertEqual(result.selectedSlotIndex, 48 % capacity.itemsPerPage)
        }
    }

    func testUnselectedPageUsesFirstSurvivorWithoutCreatingSelection() throws {
        let entries = identities(80)
        let current = entries.filter { $0 != entries[35] && $0 != entries[36] }
        let smaller = try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3))
        let result = MainGridCapacityAnchorRelocation.relocate(
            previousEntries: entries, currentEntries: current, currentPageIndex: 1,
            selectedIdentity: nil, from: .default, to: smaller)
        XCTAssertEqual(result.anchorIdentity, entries[37])
        XCTAssertEqual(result.pageIndex, 35 / 9)
        XCTAssertNil(result.selectedIdentity)
        XCTAssertNil(result.selectedPageIndex)
        XCTAssertNil(result.selectedSlotIndex)
    }

    func testOffPageSelectionDoesNotStealAnchorAndStillRelocates() throws {
        let entries = identities(80)
        let smaller = try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3))
        let result = MainGridCapacityAnchorRelocation.relocate(
            previousEntries: entries, currentEntries: entries, currentPageIndex: 1,
            selectedIdentity: entries[4], from: .default, to: smaller)
        XCTAssertEqual(result.anchorIdentity, entries[35])
        XCTAssertEqual(result.pageIndex, 3)
        XCTAssertEqual(result.selectedIdentity, entries[4])
        XCTAssertEqual(result.selectedPageIndex, 0)
        XCTAssertEqual(result.selectedSlotIndex, 4)
    }

    func testDisappearedPageAndSelectionUseNearestSurvivingOldIdentity() throws {
        let entries = identities(80)
        let current = [entries[2], entries[34], entries[71]]
        let result = MainGridCapacityAnchorRelocation.relocate(
            previousEntries: entries, currentEntries: current, currentPageIndex: 1,
            selectedIdentity: entries[48], from: .default,
            to: try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3)))
        XCTAssertEqual(result.anchorIdentity, entries[34])
        XCTAssertEqual(result.pageIndex, 0)
        XCTAssertNil(result.selectedIdentity)
    }

    func testPartialLastPageAndHostilePageIndicesAreClampedSafely() throws {
        let entries = identities(71)
        let smaller = try XCTUnwrap(MainGridCapacity(columns: 3, rows: 3))
        let last = MainGridCapacityAnchorRelocation.relocate(
            previousEntries: entries, currentEntries: entries, currentPageIndex: Int.max,
            selectedIdentity: nil, from: .default, to: smaller)
        XCTAssertEqual(last.anchorIdentity, entries[70])
        XCTAssertEqual(last.pageIndex, 7)
        let first = MainGridCapacityAnchorRelocation.relocate(
            previousEntries: entries, currentEntries: entries, currentPageIndex: Int.min,
            selectedIdentity: nil, from: .default, to: smaller)
        XCTAssertEqual(first.anchorIdentity, entries[0])
        XCTAssertEqual(first.pageIndex, 0)
    }

    func testEmptyAndCompletelyReplacedPresentationsHaveNoStaleFocus() {
        let previous = identities(40)
        let empty = MainGridCapacityAnchorRelocation.relocate(
            previousEntries: previous, currentEntries: [], currentPageIndex: Int.max,
            selectedIdentity: previous[35], from: .default, to: .default)
        XCTAssertEqual(empty.pageIndex, 0)
        XCTAssertNil(empty.anchorIdentity)
        XCTAssertNil(empty.selectedIdentity)
        let replacement: [TopLevelEntryIdentity] = [.folder(FolderID())]
        let fresh = MainGridCapacityAnchorRelocation.relocate(
            previousEntries: previous, currentEntries: replacement, currentPageIndex: 1,
            selectedIdentity: previous[35], from: .default, to: .default)
        XCTAssertEqual(fresh.anchorIdentity, replacement.first)
        XCTAssertEqual(fresh.pageIndex, 0)
        XCTAssertNil(fresh.selectedIdentity)
        let initiallyEmpty = MainGridCapacityAnchorRelocation.relocate(
            previousEntries: [], currentEntries: replacement, currentPageIndex: Int.max,
            selectedIdentity: nil, from: .default, to: .default)
        XCTAssertEqual(initiallyEmpty.anchorIdentity, replacement.first)
        XCTAssertNil(initiallyEmpty.selectedIdentity)
    }
}
