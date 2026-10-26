import AppCatalogCore
import AppGridUI
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

/// Real category delegate/cell presentation, without a shown window or scanner.
@MainActor
final class AppLibraryCategoryCellTests: XCTestCase {
    private func applyCount(_ count: Int, category: AppLibraryCategory, to view: AppLibraryView) {
        // Deliberate display-only stress snapshot, not a projection/count-engine test.
        view.apply(snapshot: .init(revision: .init(1), entries: [], counts: [category: count]),
                   isLoading: false, catalogIsEmpty: false, actionGeneration: 1)
    }

    private func cell(in view: AppLibraryView, category: AppLibraryCategory?) throws -> NSTableCellView {
        let row = try category.map { try XCTUnwrap(AppLibraryCategory.allCases.firstIndex(of: $0)) + 1 } ?? 0
        return try XCTUnwrap(view.tableView(view.categoriesTable,
            viewFor: view.categoriesTable.tableColumns.first, row: row) as? NSTableCellView)
    }

    private func countLabel(in cell: NSTableCellView) throws -> NSTextField {
        try XCTUnwrap(cell.subviews.compactMap { $0 as? NSTextField }.first {
            $0.identifier?.rawValue == "library.category.count"
        }, "The count needs independent trailing space; a combined tail-truncated label loses it")
    }

    func testLongLocalizedCategoryRetainsSeparateFullCountAtSupportedSidebarWidths() throws {
        for language in InterfaceLanguage.allCases {
            let strings = LocalizedStrings(language: language)
            let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700), strings: strings)
            defer { view.reset() }
            for category in [AppLibraryCategory.healthcareFitness, .socialNetworking] {
                for number in [0, 7, 12_345, 999_999] {
                    applyCount(number, category: category, to: view)
                    let cell = try cell(in: view, category: category)
                    let title = try XCTUnwrap(cell.textField)
                    let count = try countLabel(in: cell)
                    let fullTitle = AppLibraryCategoryLabels.title(for: category, strings: strings)
                    XCTAssertEqual(title.stringValue, fullTitle)
                    XCTAssertEqual(count.stringValue, String(number))
                    XCTAssertEqual(title.lineBreakMode, .byTruncatingTail)
                    for width: CGFloat in [112, 184, 200] {
                        cell.setFrameSize(.init(width: width, height: 30))
                        cell.needsLayout = true
                        cell.layoutSubtreeIfNeeded()
                        XCTAssertGreaterThanOrEqual(count.frame.width, ceil(count.intrinsicContentSize.width))
                        XCTAssertLessThanOrEqual(title.frame.maxX, count.frame.minX - 8 + 0.01)
                        XCTAssertLessThanOrEqual(count.frame.maxX, width - 8 + 0.01)
                        XCTAssertGreaterThanOrEqual(title.frame.width, 0)
                        XCTAssertEqual(cell.accessibilityLabel(), "\(fullTitle)  \(number)")
                        XCTAssertEqual(cell.toolTip, "\(fullTitle)  \(number)")
                    }
                }
            }
        }
    }

    func testRebindingKeepsOneCellAndFullAccessibleLabelWithoutDuplicateCount() throws {
        let cell = AppLibraryCategoryCell(frame: .init(x: 0, y: 0, width: 184, height: 30))
        let title = try XCTUnwrap(cell.textField)
        let count = try countLabel(in: cell)
        for (name, number) in [("ソーシャルネットワーキング", 12_345), ("All", 0), ("全部", 9)] {
            cell.bind(title: name, count: number)
            cell.layoutSubtreeIfNeeded()
            XCTAssertTrue(cell.textField === title)
            XCTAssertTrue(try countLabel(in: cell) === count)
            XCTAssertEqual(title.stringValue, name)
            XCTAssertEqual(count.stringValue, String(number))
            XCTAssertEqual(cell.accessibilityLabel(), "\(name)  \(number)")
            XCTAssertEqual(cell.toolTip, "\(name)  \(number)")
            XCTAssertEqual(title.accessibilityLabel(), "\(name)  \(number)")
            XCTAssertFalse(count.isAccessibilityElement())
        }
    }

    func testAllFilterCountAndRelabelPreserveSelectionAndQuery() throws {
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700),
                                  strings: LocalizedStrings(language: .english))
        defer { view.reset() }
        view.apply(snapshot: .init(revision: .init(1), entries: [], counts: [.healthcareFitness: 12, .socialNetworking: 7]),
                   isLoading: false, catalogIsEmpty: false, actionGeneration: 1)
        view.searchField.stringValue = "Independent draft"
        view.controlTextDidChange(.init(name: NSControl.textDidChangeNotification, object: view.searchField))
        let row = try XCTUnwrap(AppLibraryCategory.allCases.firstIndex(of: .healthcareFitness)) + 1
        view.categoriesTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        view.tableViewSelectionDidChange(.init(name: NSTableView.selectionDidChangeNotification, object: view.categoriesTable))
        view.relabel(strings: LocalizedStrings(language: .japanese))
        XCTAssertEqual(view.selectedCategory, .healthcareFitness)
        XCTAssertEqual(view.categoriesTable.selectedRow, row)
        XCTAssertEqual(view.query, "Independent draft")
        let all = try cell(in: view, category: nil)
        XCTAssertEqual(all.textField?.stringValue, "すべて")
        XCTAssertEqual(try countLabel(in: all).stringValue, "19")
        XCTAssertEqual(all.accessibilityLabel(), "すべて  19")
    }

    func testTransientTinyBoundsNeverProduceNegativeOrEscapingLabelFrames() throws {
        let cell = AppLibraryCategoryCell(frame: .zero)
        cell.bind(title: "A long title", count: 999_999)
        let count = try countLabel(in: cell)
        let title = try XCTUnwrap(cell.textField)
        for width: CGFloat in [0, 4, 8, 16, 30] {
            cell.setFrameSize(.init(width: width, height: 10))
            cell.needsLayout = true
            cell.layoutSubtreeIfNeeded()
            for label in [title, count] {
                XCTAssertGreaterThanOrEqual(label.frame.width, 0)
                XCTAssertGreaterThanOrEqual(label.frame.minX, 0)
                XCTAssertLessThanOrEqual(label.frame.maxX, width)
            }
        }
    }


    func testCellPreservesNativeTextCellAccessibilityExposure() throws {
        let baseline = NSTableCellView(frame: .zero)
        let baselineTitle = NSTextField(labelWithString: "Native title")
        baseline.textField = baselineTitle
        baseline.addSubview(baselineTitle)
        let cell = AppLibraryCategoryCell(frame: .zero)
        cell.bind(title: "ヘルスケア／フィットネス", count: 12)
        let title = try XCTUnwrap(cell.textField)
        XCTAssertEqual(cell.isAccessibilityElement(), baseline.isAccessibilityElement(),
                       "Do not introduce an unknown-role wrapper around the table's native cell")
        XCTAssertEqual(title.isAccessibilityElement(), baselineTitle.isAccessibilityElement())
        XCTAssertEqual(title.accessibilityLabel(), "ヘルスケア／フィットネス  12")
    }

}
