import AppCatalogCore
import AppGridUI
import AppIconPipeline
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

/// Synthetic snapshots and ordinary mounted, unshown windows only. No launcher,
/// scanner, workspace action, production preferences or app lifecycle is started.
@MainActor
final class AppLibraryViewTests: XCTestCase {
    private var window: NSWindow!
    private var view: AppLibraryView!
    private let strings = LocalizedStrings(language: .english)

    override func setUpWithError() throws {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
                          styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        view = AppLibraryView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700), strings: strings)
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        XCTAssertFalse(window.isVisible)
    }

    override func tearDownWithError() throws {
        view?.reset()
        window?.contentView = nil
        view = nil
        window?.close()
        window = nil
    }

    private func entry(_ suffix: String, name: String = "Original", display: String? = nil,
                       category: AppLibraryCategory = .other, manual: AppLibraryCategory? = nil,
                       metadata: AppBundleMetadata = .init(), path: String? = nil) -> AppLibraryEntry {
        let bundleID = "fixture.library.view.\(suffix)"
        let id = AppID.bundleIdentifier(bundleID)
        let record = AppRecord(id: id, displayName: name, bundleIdentifier: bundleID,
                               canonicalURL: URL(fileURLWithPath: path ?? "/SyntheticApps/\(suffix).app"),
                               iconIdentity: .from(appID: id), sourceRootPriority: 0, bundleMetadata: metadata)
        return AppLibraryEntry(record: record, displayName: display ?? name, category: category, manualCategory: manual)
    }

    private func apply(_ entries: [AppLibraryEntry], revision: UInt64 = 1, generation: UInt64 = 1,
                       loading: Bool = false, empty: Bool = false) {
        let counts = entries.reduce(into: [AppLibraryCategory: Int]()) { $0[$1.category, default: 0] += 1 }
        view.apply(snapshot: AppLibrarySnapshot(revision: CatalogRevision(revision), entries: entries, counts: counts),
                   isLoading: loading, catalogIsEmpty: empty, actionGeneration: generation)
        view.layoutSubtreeIfNeeded()
    }

    private func select(_ row: Int) {
        view.resultsTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        view.tableViewSelectionDidChange(Notification(name: NSTableView.selectionDidChangeNotification,
                                                      object: view.resultsTable))
        // Most fixtures exercise Details. Its explicit action is intentionally
        // separate from ordinary keyboard or pointer row selection.
        view.showDetails(nil)
        view.layoutSubtreeIfNeeded()
    }

    private func query(_ value: String) {
        view.searchField.stringValue = value
        view.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: view.searchField))
    }

    func testCategoryResponderMovesToVisibleCounterpartAcrossCompactLayout() {
        // Category controls belong to the queried result browser, not the new overview.
        query("Focus")
        apply([entry("Focus")])
        XCTAssertTrue(window.makeFirstResponder(view.categoriesTable))
        XCTAssertTrue(window.firstResponder === view.categoriesTable, "Before compact: \(String(describing: window.firstResponder))")
        view.setFrameSize(.init(width: 360, height: 700))
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        XCTAssertTrue(view.categoriesTable.isHiddenOrHasHiddenAncestor)
        XCTAssertFalse(view.compactCategoryPicker.isHiddenOrHasHiddenAncestor)
        XCTAssertTrue(window.firstResponder === view.compactCategoryPicker, "After compact: \(String(describing: window.firstResponder))")
        XCTAssertTrue(view.preferredFirstResponder === view.compactCategoryPicker)

        XCTAssertTrue(window.makeFirstResponder(view.compactCategoryPicker))
        XCTAssertTrue(window.firstResponder === view.compactCategoryPicker, "Before wide: \(String(describing: window.firstResponder))")
        view.setFrameSize(.init(width: 1000, height: 700))
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        XCTAssertTrue(view.compactCategoryPicker.isHiddenOrHasHiddenAncestor)
        XCTAssertFalse(view.categoriesTable.isHiddenOrHasHiddenAncestor)
        XCTAssertTrue(window.firstResponder === view.categoriesTable, "After wide: \(String(describing: window.firstResponder))")
        XCTAssertTrue(view.preferredFirstResponder === view.categoriesTable)
    }

    func testCategoryLayoutDoesNotStealSearchCompositionOrResultFocus() throws {
        apply([entry("Focus")])
        view.focusSearch()
        let editor = try XCTUnwrap(view.searchField.currentEditor() as? NSTextView)
        editor.setMarkedText("かな", selectedRange: NSRange(location: 2, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        for width: CGFloat in [360, 1000] {
            view.setFrameSize(.init(width: width, height: 700))
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
            XCTAssertTrue(window.firstResponder === editor)
            XCTAssertTrue(view.preferredFirstResponder === editor)
            XCTAssertTrue(editor.hasMarkedText())
        }
        XCTAssertTrue(window.makeFirstResponder(view.resultsTable))
        for width: CGFloat in [360, 1000] {
            view.setFrameSize(.init(width: width, height: 700))
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
            XCTAssertTrue(window.firstResponder === view.resultsTable)
            XCTAssertTrue(view.preferredFirstResponder === view.resultsTable)
            XCTAssertFalse(view.resultsTable.isHiddenOrHasHiddenAncestor)
        }
    }

    func testNarrowKeyboardSelectionKeepsResultsResponderUntilExplicitDetails() throws {
        for width: CGFloat in [700, 360] {
            view.setFrameSize(.init(width: width, height: 700))
            apply([entry("A"), entry("B"), entry("C")])
            view.focusSearch()
            _ = view.control(view.searchField, textView: NSTextView(),
                             doCommandBy: #selector(NSResponder.moveDown(_:)))
            XCTAssertTrue(window.firstResponder === view.resultsTable)
            let arrow = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: "\u{f701}",
                charactersIgnoringModifiers: "\u{f701}", isARepeat: false, keyCode: 125))
            window.firstResponder?.keyDown(with: arrow)
            view.layoutSubtreeIfNeeded()
            XCTAssertEqual(view.resultsTable.selectedRow, 1)
            XCTAssertFalse(view.detailsOpen)
            XCTAssertTrue(window.firstResponder === view.resultsTable)
            var requests: [AppLibraryActionRequest] = []
            view.onOpen = { requests.append($0) }
            window.firstResponder?.keyDown(with: try key(36))
            XCTAssertEqual(requests.count, 1)
            XCTAssertEqual(requests.first?.appID, entry("B").record.id)
        }
    }

    func testUnsubmittedCategoryDraftSurvivesDetailsAndFreshIdentityButReceiptsReconcile() throws {
        let app = entry("Draft", category: .games, manual: .games)
        apply([app])
        select(0)
        let picker = try XCTUnwrap(view.categoryPicker)
        let financeIndex = try XCTUnwrap(AppLibraryCategory.allCases.firstIndex(of: .finance)) + 1
        picker.selectItem(at: financeIndex)
        view.categoryDraftChanged(picker)
        view.showDetails(nil)
        XCTAssertEqual(picker.indexOfSelectedItem, financeIndex)
        view.apply(snapshot: nil, isLoading: true, catalogIsEmpty: false, actionGeneration: 2)
        apply([app], revision: 2, generation: 3)
        XCTAssertEqual(picker.indexOfSelectedItem, financeIndex)
        view.categorySaveDidComplete(.failed)
        view.showDetails(nil)
        XCTAssertEqual(picker.indexOfSelectedItem, financeIndex)
        XCTAssertEqual(view.categorySaveStatusLabel?.stringValue, LocalizedStrings(language: .english).libraryText(.saveFailed))
        view.categorySaveDidComplete(.saved)
        apply([entry("Draft", category: .finance, manual: .finance)], revision: 3, generation: 4)
        XCTAssertEqual(picker.indexOfSelectedItem, financeIndex)
        XCTAssertTrue(view.categorySaveStatusLabel?.isHidden == true)
        apply([entry("Other", category: .music, manual: .music)], revision: 4, generation: 5)
        select(0)
        XCTAssertEqual(picker.indexOfSelectedItem, (AppLibraryCategory.allCases.firstIndex(of: .music) ?? 0) + 1)
    }

    private func key(_ code: UInt16) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                      windowNumber: window.windowNumber, context: nil,
                                      characters: code == 53 ? "\u{1b}" : "\r", charactersIgnoringModifiers: code == 53 ? "\u{1b}" : "\r",
                                      isARepeat: false, keyCode: code))
    }

    func testSearchReturnAndDownSelectFirstWithoutLaunchingThenResultReturnOpens() throws {
        let first = entry("first")
        apply([first, entry("second")], revision: 7, generation: 19)
        var requests: [AppLibraryActionRequest] = []
        view.onOpen = { requests.append($0) }
        let editor = NSTextView()
        for selector in [#selector(NSResponder.insertNewline(_:)), #selector(NSResponder.moveDown(_:))] {
            XCTAssertTrue(view.control(view.searchField, textView: editor, doCommandBy: selector))
            XCTAssertEqual(view.resultsTable.selectedRow, 0)
            XCTAssertTrue(requests.isEmpty)
            XCTAssertFalse(view.detailsOpen)
            XCTAssertTrue(window.firstResponder === view.resultsTable)
        }
        view.resultsTable.keyDown(with: try key(36))
        view.resultsTable.keyDown(with: try key(76))
        XCTAssertEqual(requests, Array(repeating: AppLibraryActionRequest(record: first.record,
                                                                         catalogRevision: CatalogRevision(7), generation: 19), count: 2))
    }

    func testTabCommandsStayNativeAndEmptySearchReturnDoesNotOpen() {
        apply([])
        var opens = 0
        view.onOpen = { _ in opens += 1 }
        let editor = NSTextView()
        XCTAssertFalse(view.control(view.searchField, textView: editor, doCommandBy: #selector(NSResponder.insertTab(_:))))
        XCTAssertFalse(view.control(view.searchField, textView: editor, doCommandBy: #selector(NSResponder.insertBacktab(_:))))
        XCTAssertTrue(view.control(view.searchField, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:))))
        XCTAssertEqual(view.resultsTable.selectedRow, -1)
        XCTAssertEqual(opens, 0)
    }

    func testEscapeClosesDetailsThenClearsQueryThenBack() {
        var queries: [String] = []
        var backs = 0
        view.onQueryChange = { queries.append($0) }
        view.onBack = { backs += 1 }
        query("Alias")
        apply([entry("one", display: "Alias")])
        select(0)
        XCTAssertTrue(view.detailsOpen)
        XCTAssertTrue(view.handleEscape())
        XCTAssertFalse(view.detailsOpen)
        XCTAssertEqual(view.query, "Alias")
        XCTAssertEqual(backs, 0)
        XCTAssertTrue(view.handleEscape())
        XCTAssertEqual(view.query, "")
        XCTAssertEqual(queries, ["Alias", ""])
        XCTAssertEqual(backs, 0)
        XCTAssertTrue(view.handleEscape())
        XCTAssertEqual(backs, 1)
    }

    func testCurrentApplyRetainsIdentityAcrossReorderButClearsRemovedSelectionAndActions() {
        let first = entry("first")
        let second = entry("second")
        apply([first, second])
        select(1)
        var requests: [AppLibraryActionRequest] = []
        view.onOpen = { requests.append($0) }
        let relocated = entry("second", path: "/SyntheticApps/Relocated.app")
        apply([relocated, first], revision: 2, generation: 8)
        XCTAssertEqual(view.resultsTable.selectedRow, 0)
        XCTAssertTrue(view.detailsOpen)
        view.openSelection(nil)
        XCTAssertEqual(requests.last, AppLibraryActionRequest(record: relocated.record,
                                                             catalogRevision: CatalogRevision(2), generation: 8))
        apply([first], revision: 3, generation: 9)
        XCTAssertEqual(view.resultsTable.selectedRow, -1)
        XCTAssertFalse(view.detailsOpen)
        view.openSelection(nil)
        view.saveCategory(nil)
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(view.detailValues.values.allSatisfy { $0.stringValue.isEmpty })
    }

    func testQueryAndCategoryChangesInvalidateActionsBeforeOwnerReturnsSnapshot() {
        var opens = 0
        var categories: [AppLibraryCategory?] = []
        view.onOpen = { _ in opens += 1 }
        view.onCategoryChange = { categories.append($0) }
        apply([entry("one")])
        select(0)
        query("new")
        view.openSelection(nil)
        XCTAssertEqual(opens, 0)
        XCTAssertFalse(view.detailsOpen)
        apply([entry("one")])
        select(0)
        let index = AppLibraryCategory.allCases.firstIndex(of: .games)! + 1
        view.compactCategoryPicker.selectItem(at: index)
        view.compactCategoryChanged(nil)
        view.openSelection(nil)
        XCTAssertEqual(view.selectedCategory, .games)
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(categories[0], .games)
        XCTAssertEqual(opens, 0)
    }

    func testCategoryPickerRequiresExplicitSaveAndAutomaticEmitsNil() throws {
        let app = entry("one", category: .games, manual: .games)
        apply([app])
        XCTAssertNil(view.categoryPicker, "Details controls are not allocated before selection.")
        select(0)
        let picker = try XCTUnwrap(view.categoryPicker)
        XCTAssertEqual(picker.numberOfItems, 23)
        XCTAssertEqual(picker.itemTitle(at: 0), strings.libraryText(.automatic))
        var categories: [AppLibraryCategory?] = []
        view.onSetCategory = { _, category in categories.append(category) }
        let index = AppLibraryCategory.allCases.firstIndex(of: .utilities)! + 1
        picker.selectItem(at: index)
        XCTAssertTrue(categories.isEmpty)
        try XCTUnwrap(view.saveCategoryButton).performClick(nil)
        picker.selectItem(at: 0)
        try XCTUnwrap(view.saveCategoryButton).performClick(nil)
        try XCTUnwrap(view.restoreAutomaticButton).performClick(nil)
        XCTAssertEqual(categories.count, 3)
        XCTAssertEqual(categories[0], .utilities)
        XCTAssertNil(categories[1])
        XCTAssertNil(categories[2])
    }

    func testFactualDetailsAndUnknownMetadataUseOnlySuppliedRecord() throws {
        apply([entry("one", display: "Alias", category: .games, manual: .games,
                     metadata: AppBundleMetadata(declaredCategoryIdentifier: "public.app-category.utilities",
                                                 version: "1.2", build: "42"))])
        select(0)
        XCTAssertEqual(view.detailValues[.originalName]?.stringValue, "Original")
        XCTAssertEqual(view.detailValues[.alias]?.stringValue, "Alias")
        XCTAssertEqual(view.detailValues[.category]?.stringValue, strings.libraryText(.categoryGames))
        XCTAssertEqual(view.detailValues[.automaticCategory]?.stringValue, strings.libraryText(.categoryUtilities))
        XCTAssertEqual(view.detailValues[.manualCategory]?.stringValue, strings.libraryText(.categoryGames))
        XCTAssertEqual(view.detailValues[.version]?.stringValue, "1.2")
        XCTAssertEqual(view.detailValues[.build]?.stringValue, "42")
        apply([entry("one")])
        XCTAssertEqual(view.detailValues[.version]?.stringValue, strings.libraryText(.unknown))
        XCTAssertEqual(view.detailValues[.build]?.stringValue, strings.libraryText(.unknown))
        XCTAssertEqual(view.detailValues[.alias]?.stringValue, strings.libraryText(.unknown))
        XCTAssertEqual(view.detailValues.count, 9)
    }

    func testManagementAndFolderButtonsEmitCanonicalRequestsWithoutFakeCells() throws {
        let app = entry("one")
        apply([app], revision: 12, generation: 34)
        var requests: [AppLibraryActionRequest] = []
        var hidden: [Bool] = []
        view.onReveal = { requests.append($0) }
        view.onEditAlias = { requests.append($0) }
        view.onSetHidden = { requests.append($0); hidden.append($1) }
        select(0)
        XCTAssertTrue(try XCTUnwrap(view.folderButton).isHidden)
        view.onFolderAssignment = { requests.append($0) }
        XCTAssertFalse(try XCTUnwrap(view.folderButton).isHidden)
        for button in [view.revealButton, view.aliasButton, view.hideButton, view.folderButton] {
            try XCTUnwrap(button).performClick(nil)
        }
        let request = AppLibraryActionRequest(record: app.record, catalogRevision: CatalogRevision(12), generation: 34)
        XCTAssertEqual(requests, Array(repeating: request, count: 4))
        XCTAssertEqual(hidden, [true])
        XCTAssertTrue(view.detailsOpen)
        XCTAssertEqual(view.folderButton?.title, strings.menuText(.organizeApps))
    }

    func testLoadingAndUnavailableStatesCannotEmitStaleActions() {
        apply([entry("one")])
        select(0)
        var opens = 0
        view.onOpen = { _ in opens += 1 }
        apply([entry("one")], loading: true)
        view.openSelection(nil)
        XCTAssertEqual(opens, 0)
        XCTAssertEqual(view.statusLabel.stringValue, strings.libraryText(.loading))
        view.apply(snapshot: nil, isLoading: false, catalogIsEmpty: false, actionGeneration: 3)
        XCTAssertEqual(view.statusLabel.stringValue, strings.libraryText(.unavailable))
        XCTAssertFalse(view.detailsOpen)
        apply([], empty: true)
        XCTAssertEqual(view.statusLabel.stringValue, strings.libraryText(.empty))
        apply([], empty: false)
        XCTAssertEqual(view.statusLabel.stringValue, strings.libraryText(.noResults))
    }

    func testResponderOwnershipNotificationsAndReset() throws {
        XCTAssertTrue(view.preferredFirstResponder === view.searchField)
        view.focusSearch()
        let editor = try XCTUnwrap(view.searchField.currentEditor())
        XCTAssertTrue(view.preferredFirstResponder === editor)
        XCTAssertTrue(view.hasPresentationOwnership)
        var notifications = 0
        view.onPresentationOwnershipChange = { notifications += 1 }
        view.controlTextDidBeginEditing(Notification(name: NSControl.textDidBeginEditingNotification, object: view.searchField))
        view.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: view.searchField))
        XCTAssertEqual(notifications, 2)
        window.makeFirstResponder(view.resultsTable)
        XCTAssertTrue(view.preferredFirstResponder === view.resultsTable)
        XCTAssertFalse(view.hasPresentationOwnership)
        view.reset()
        XCTAssertGreaterThanOrEqual(notifications, 3)
    }

    func testMarkedTextEscapeConsumesCompositionBeforeNavigation() throws {
        var backs = 0
        view.onBack = { backs += 1 }
        view.focusSearch()
        let editor = try XCTUnwrap(view.searchField.currentEditor() as? NSTextView)
        editor.setMarkedText("かな", selectedRange: NSRange(location: 2, length: 0), replacementRange: NSRange(location: NSNotFound, length: 0))
        XCTAssertTrue(editor.hasMarkedText())
        XCTAssertTrue(view.handleEscape())
        XCTAssertEqual(backs, 0)
    }

    func testRelabelPreservesQuerySelectionCategoryAndUnsubmittedPickerDraft() throws {
        query("Alias")
        apply([entry("one", display: "Alias", category: .games, manual: .games)])
        select(0)
        let picker = try XCTUnwrap(view.categoryPicker)
        let draft = AppLibraryCategory.allCases.firstIndex(of: .finance)! + 1
        picker.selectItem(at: draft)
        let japanese = LocalizedStrings(language: .japanese)
        view.relabel(strings: japanese)
        XCTAssertEqual(view.query, "Alias")
        XCTAssertEqual(view.searchField.stringValue, "Alias")
        XCTAssertEqual(view.resultsTable.selectedRow, 0)
        XCTAssertTrue(view.detailsOpen)
        XCTAssertEqual(picker.indexOfSelectedItem, draft)
        XCTAssertEqual(view.backButton.title, japanese.libraryText(.back))
        XCTAssertEqual(view.aliasButton?.title, japanese.menuText(.setAlias))
        XCTAssertEqual(view.searchField.accessibilityIdentifier(), "library.search")
        XCTAssertEqual(view.categoriesTable.accessibilityIdentifier(), "library.categories")
        XCTAssertEqual(view.resultsTable.accessibilityIdentifier(), "library.results")
    }

    func testCompactLayoutReplacesResultsAndKeepsControlsWithinRoot() throws {
        apply([entry("one")])
        select(0)
        let widths: [CGFloat] = [1000, 700, 480, 360]
        for width in widths {
            view.setFrameSize(NSSize(width: width, height: 480))
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
            for child in view.subviews where !child.isHidden {
                XCTAssertGreaterThanOrEqual(child.frame.minX, 0)
                XCTAssertLessThanOrEqual(child.frame.maxX, view.bounds.maxX + 1)
            }
            let scroll = try XCTUnwrap(view.subviews.first { $0.identifier?.rawValue == "library.details" })
            XCTAssertFalse(scroll.isHidden)
            XCTAssertGreaterThan(scroll.frame.height, 0)
            XCTAssertEqual(view.compactCategoryPicker.isHidden, width - 24 >= 420)
        }
    }

    func testResultsResponderMovesIntoDetailsBeforeNarrowingHidesResults() throws {
        for width: CGFloat in [700, 360] {
            view.setFrameSize(.init(width: 1000, height: 700))
            apply([entry("Focus")])
            select(0)
            XCTAssertTrue(window.makeFirstResponder(view.resultsTable))
            XCTAssertFalse(view.resultsTable.isHiddenOrHasHiddenAncestor)
            view.setFrameSize(.init(width: width, height: 700))
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
            let responder = try XCTUnwrap(window.firstResponder as? NSView)
            XCTAssertEqual(responder.accessibilityIdentifier(), "library.details.close")
            XCTAssertFalse(responder.isHiddenOrHasHiddenAncestor)
            XCTAssertTrue(view.preferredFirstResponder === responder)
            XCTAssertTrue(view.detailsOpen)
            XCTAssertEqual(view.resultsTable.selectedRow, 0)
        }
    }

    func testSurvivingDetailsRefreshMovesDisplacedResultsFocusIntoDrawer() throws {
        view.setFrameSize(.init(width: 360, height: 700))
        apply([entry("Survivor")])
        select(0)
        // Use an actual exposed details control, not a synthetic responder.
        let picker = try XCTUnwrap(view.categoryPicker)
        XCTAssertTrue(window.makeFirstResponder(picker))
        view.apply(snapshot: nil, isLoading: true, catalogIsEmpty: false, actionGeneration: 2)
        view.layoutSubtreeIfNeeded()
        XCTAssertTrue(window.firstResponder === view.resultsTable)
        XCTAssertFalse(view.resultsTable.isHiddenOrHasHiddenAncestor)
        apply([entry("Survivor", display: "Updated")], revision: 2, generation: 3)
        let responder = try XCTUnwrap(window.firstResponder as? NSView)
        XCTAssertEqual(responder.accessibilityIdentifier(), "library.details.close")
        XCTAssertFalse(responder.isHiddenOrHasHiddenAncestor)
        XCTAssertTrue(view.preferredFirstResponder === responder)
        XCTAssertTrue(view.detailsOpen)
        XCTAssertEqual(view.resultsTable.selectedRow, 0)
    }

    func testDetailsResizeDoesNotStealMarkedSearchOrVisibleControlFocus() throws {
        apply([entry("Focus")])
        select(0)
        view.focusSearch()
        let editor = try XCTUnwrap(view.searchField.currentEditor() as? NSTextView)
        editor.setMarkedText("かな", selectedRange: NSRange(location: 2, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        for width: CGFloat in [700, 360, 1000] {
            view.setFrameSize(.init(width: width, height: 700))
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
            XCTAssertTrue(window.firstResponder === editor)
            XCTAssertTrue(editor.hasMarkedText())
            XCTAssertEqual(editor.string, "かな")
        }
        // Ending marked editing may commit a query and revoke details. Build a
        // fresh settled selection before checking unrelated visible controls.
        view.reset()
        apply([entry("VisibleControl")])
        select(0)
        let picker = try XCTUnwrap(view.categoryPicker)
        XCTAssertTrue(view.detailsOpen)
        XCTAssertFalse(picker.isHiddenOrHasHiddenAncestor)
        XCTAssertTrue(window.makeFirstResponder(picker))
        for width: CGFloat in [360, 700, 1000] {
            view.setFrameSize(.init(width: width, height: 700))
            view.needsLayout = true
            view.layoutSubtreeIfNeeded()
            XCTAssertTrue(window.firstResponder === picker)
            XCTAssertFalse(picker.isHiddenOrHasHiddenAncestor)
        }
    }

    func testBlankHitRemainsInteractiveAndResetClearsContentWithoutOwnerCallbacks() throws {
        apply([entry("one")])
        select(0)
        query("draft")
        apply([entry("one")])
        select(0)
        var changes = 0
        view.onQueryChange = { _ in changes += 1 }
        view.onCategoryChange = { _ in changes += 1 }
        XCTAssertTrue(view.hitTest(NSPoint(x: 3, y: 3)) === view)
        view.reset()
        XCTAssertEqual(view.query, "")
        XCTAssertNil(view.selectedCategory)
        XCTAssertFalse(view.detailsOpen)
        XCTAssertEqual(view.resultsTable.numberOfRows, 0)
        XCTAssertEqual(changes, 0)
        XCTAssertTrue(view.detailValues.values.allSatisfy { $0.stringValue.isEmpty })
    }

    func testUnshownMountedWindowDoesNotPrefetchAnyCatalogIcons() {
        let pipeline = IconPipeline(loader: LibraryNeverLoadIcons(), limits: IconCacheLimits())
        defer { pipeline.shutdown() }
        view.reset()
        view = AppLibraryView(frame: NSRect(x: 0, y: 0, width: 700, height: 500), strings: strings, iconPipeline: pipeline)
        window.contentView = view
        apply((0..<500).map { entry("\($0)") })
        view.isHidden = true
        view.isHidden = false
        view.layoutSubtreeIfNeeded()
        XCTAssertEqual(pipeline.stats.requests, 0)
        view.reset()
        XCTAssertEqual(pipeline.stats.requests, 0)
    }

    func testHideAndResetReleaseResidentCellImages() throws {
        apply([entry("one")])
        let cell = try XCTUnwrap(view.resultsTable.view(atColumn: 0, row: 0, makeIfNecessary: true) as? NSTableCellView)
        cell.imageView?.image = NSImage(size: NSSize(width: 32, height: 32))
        XCTAssertNotNil(cell.imageView?.image)
        view.isHidden = true
        XCTAssertNil(cell.imageView?.image)
        view.isHidden = false
        cell.imageView?.image = NSImage(size: NSSize(width: 32, height: 32))
        view.reset()
        XCTAssertNil(cell.imageView?.image)
    }

    func testNilLoadingRevokesActionsThenRestoresDetailsOnlyForFreshSurvivingIdentity() {
        apply([entry("one"), entry("two")])
        select(1)
        var requests: [AppLibraryActionRequest] = []
        view.onOpen = { requests.append($0) }
        let generations: [UInt64] = [2, 3]
        for generation in generations {
            view.apply(snapshot: nil, isLoading: true, catalogIsEmpty: false, actionGeneration: generation)
            XCTAssertEqual(view.resultsTable.selectedRow, -1)
            XCTAssertFalse(view.detailsOpen)
            XCTAssertTrue(view.detailValues.values.allSatisfy { $0.stringValue.isEmpty })
            view.openSelection(nil)
        }
        XCTAssertTrue(requests.isEmpty)
        let refreshed = entry("two", display: "Updated Alias", category: .utilities, manual: .utilities,
                              metadata: AppBundleMetadata(version: "2.0"), path: "/SyntheticApps/Moved.app")
        apply([refreshed, entry("one")], revision: 4, generation: 4)
        XCTAssertEqual(view.resultsTable.selectedRow, 0)
        XCTAssertTrue(view.detailsOpen)
        XCTAssertEqual(view.detailValues[.alias]?.stringValue, "Updated Alias")
        XCTAssertEqual(view.detailValues[.manualCategory]?.stringValue, strings.libraryText(.categoryUtilities))
        XCTAssertEqual(view.detailValues[.version]?.stringValue, "2.0")
        view.openSelection(nil)
        XCTAssertEqual(requests, [AppLibraryActionRequest(record: refreshed.record,
                                                         catalogRevision: CatalogRevision(4), generation: 4)])
        view.apply(snapshot: nil, isLoading: true, catalogIsEmpty: false, actionGeneration: 5)
        apply([entry("one")], revision: 5, generation: 5)
        XCTAssertEqual(view.resultsTable.selectedRow, -1)
        XCTAssertFalse(view.detailsOpen)
        view.openSelection(nil)
        XCTAssertEqual(requests.count, 1)
        // A later reappearance must not resurrect the removed selection.
        apply([refreshed, entry("one")], revision: 6, generation: 6)
        XCTAssertEqual(view.resultsTable.selectedRow, -1)
        XCTAssertFalse(view.detailsOpen)
    }
}

private struct LibraryNeverLoadIcons: IconLoading {
    func load(key: IconKey) async throws -> NSImage { throw CancellationError() }
}
