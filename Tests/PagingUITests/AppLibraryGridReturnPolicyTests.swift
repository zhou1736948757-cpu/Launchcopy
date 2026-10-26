import AppCatalogCore
import AppGridUI
import XCTest
@testable import PagingPrototypeApp

final class AppLibraryGridReturnPolicyTests: XCTestCase {
    private func layout(_ names: [String], revision: UInt64 = 2) -> AppGridFocusLayout {
        let records = names.map { name -> AppRecord in
            let id = AppID.bundleIdentifier("fixture." + name)
            return .init(id: id, displayName: name, bundleIdentifier: "fixture." + name,
                canonicalURL: URL(fileURLWithPath: "/Synthetic/" + name + ".app"), iconIdentity: .from(appID: id), sourceRootPriority: 0)
        }
        return .build(from: .init(revision: .init(revision), records: records), itemsPerPage: 2)
    }

    func testLocatedAnchorRestoresNewPageAndRealCurrentRevision() {
        let old = layout(["A", "B", "C"], revision: 1)
        let selected = AppGridFocusIdentity(catalogRevision: 1, pageIndex: 1, slotIndex: 0, entryIdentity: old.validEntry(page: 1, slot: 0))
        let context = AppLibraryGridReturnContext(query: "query", page: 1, selection: selected, searchWasFocused: false)
        let target = AppLibraryGridReturnPolicy.resolve(context, in: layout(["C", "A", "B"]))
        XCTAssertEqual(target.page, 0)
        XCTAssertEqual(target.selection?.slotIndex, 0)
        XCTAssertEqual(target.selection?.catalogRevision, 2)
        XCTAssertEqual(target.selection?.entryIdentity, selected.entryIdentity)
    }

    func testRemovedOrHiddenAnchorUsesNearestValidCurrentSlot() {
        let old = layout(["A", "B", "C", "D"], revision: 1)
        let selected = AppGridFocusIdentity(catalogRevision: 1, pageIndex: 1, slotIndex: 1, entryIdentity: old.validEntry(page: 1, slot: 1))
        let context = AppLibraryGridReturnContext(query: "", page: 1, selection: selected, searchWasFocused: false)
        let target = AppLibraryGridReturnPolicy.resolve(context, in: layout(["A", "B", "C"]))
        XCTAssertEqual(target.page, 1)
        XCTAssertEqual(target.selection?.slotIndex, 0)
        XCTAssertNotEqual(target.selection?.entryIdentity, selected.entryIdentity)
    }

    func testNoSelectionKeepsDeferredFocusAndEmptyCatalogClearsIt() {
        let context = AppLibraryGridReturnContext(query: "", page: 20, selection: nil, searchWasFocused: true)
        let target = AppLibraryGridReturnPolicy.resolve(context, in: layout(["A", "B", "C"]))
        XCTAssertEqual(target.page, 1)
        XCTAssertNil(target.selection)
        let empty = AppLibraryGridReturnPolicy.resolve(context, in: layout([]))
        XCTAssertEqual(empty.page, 0)
        XCTAssertNil(empty.selection)
    }
}
