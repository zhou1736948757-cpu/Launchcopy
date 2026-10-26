import AppCatalogCore
import AppGridUI
import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

@MainActor
final class LibraryCategoryGalleryTests: XCTestCase {
    private let strings = LocalizedStrings(language: .english)
    private func entry(_ index: Int, category: AppLibraryCategory = .utilities) -> AppLibraryEntry {
        let id = AppID.bundleIdentifier("fixture.gallery.\(index)")
        let record = AppRecord(id: id, displayName: "Gallery \(index)", bundleIdentifier: "fixture.gallery.\(index)",
            canonicalURL: URL(fileURLWithPath: "/SyntheticGallery/App\(index).app"),
            iconIdentity: .from(appID: id), sourceRootPriority: 0)
        return .init(record: record, displayName: record.displayName, category: category)
    }
    private func apply(_ view: AppLibraryView, _ entries: [AppLibraryEntry], generation: UInt64 = 1, loading: Bool = false) {
        let counts = entries.reduce(into: [AppLibraryCategory: Int]()) { $0[$1.category, default: 0] += 1 }
        view.apply(snapshot: .init(revision: .init(generation), entries: entries, counts: counts),
            isLoading: loading, catalogIsEmpty: entries.isEmpty, actionGeneration: generation)
        view.layoutSubtreeIfNeeded()
    }
    private func selectCategory(_ category: AppLibraryCategory, in view: AppLibraryView) throws {
        let row = try XCTUnwrap(AppLibraryCategory.allCases.firstIndex(of: category)) + 1
        view.categoriesTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        view.tableViewSelectionDidChange(.init(name: NSTableView.selectionDidChangeNotification,
            object: view.categoriesTable))
    }
    private func descendants(of view: NSView) -> [NSView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
    private func contextEvent() throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(with: .rightMouseDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil, eventNumber: 1, clickCount: 1, pressure: 1))
    }
    func testGeometryAdaptsWithoutOverlappingOrOverflowingViewport() {
        for width: CGFloat in [180, 320, 540, 900, 1600] {
            let geometry = LibraryGalleryGeometry(width: width, height: 400, count: 22)
            XCTAssertGreaterThanOrEqual(geometry.columns, 1)
            XCTAssertLessThanOrEqual(geometry.columns, 4)
            XCTAssertLessThanOrEqual(geometry.cardSide, 248)
            for (index, frame) in geometry.frames.enumerated() {
                XCTAssertGreaterThanOrEqual(frame.minX, 0)
                XCTAssertLessThanOrEqual(frame.maxX, width)
                XCTAssertLessThanOrEqual(frame.maxY, geometry.documentSize.height)
                for other in geometry.frames.dropFirst(index + 1) { XCTAssertFalse(frame.intersects(other)) }
            }
        }
        XCTAssertTrue(LibraryGalleryGeometry(width: 0, height: 0, count: 0).frames.isEmpty)
    }
    func testOverviewUsesOnlyPopulatedCategoriesInStableTaxonomyOrder() {
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700), strings: strings)
        defer { view.reset() }
        apply(view, [entry(1), entry(2, category: .games), entry(3)])
        XCTAssertTrue(view.showsGallery)
        XCTAssertFalse(view.galleryView.isHidden)
        XCTAssertTrue(view.categoriesTable.isHiddenOrHasHiddenAncestor)
        XCTAssertTrue(view.resultsTable.isHiddenOrHasHiddenAncestor)
        XCTAssertEqual(view.galleryView.cards.map(\.category), [.games, .utilities])
        XCTAssertEqual(view.galleryView.cards.map { $0.entries.count }, [1, 2])
    }
    func testOverviewHidesRootBackInWideAndCompactHeadersAndKeepsEscapeExit() {
        for width: CGFloat in [320, 1000] {
            let view = AppLibraryView(frame: .init(x: 0, y: 0, width: width, height: 700), strings: strings)
            defer { view.reset() }
            var exits = 0
            view.onBack = { exits += 1 }
            // Initial empty/loading and populated overview both omit the target.
            XCTAssertTrue(view.backButton.isHidden)
            XCTAssertTrue(view.backButton.isAccessibilityHidden())
            apply(view, [entry(1)])
            XCTAssertTrue(view.backButton.isHidden)
            XCTAssertTrue(view.backButton.isAccessibilityHidden())
            XCTAssertEqual(view.searchField.frame, LauncherSearchHeader.frame(in: view.bounds, flipped: true))
            XCTAssertTrue(view.handleEscape())
            XCTAssertEqual(exits, 1)
        }
    }

    func testExplicitCategoryFilterRetainsBackAndReturningHidesItAgain() throws {
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700), strings: strings)
        defer { view.reset() }
        var exits = 0
        view.onBack = { exits += 1 }
        apply(view, [entry(1)])
        try selectCategory(.utilities, in: view)
        apply(view, [entry(1)], generation: 2)
        XCTAssertFalse(view.backButton.isHidden)
        XCTAssertFalse(view.backButton.isAccessibilityHidden())
        view.backButton.performClick(nil)
        view.layoutSubtreeIfNeeded()
        XCTAssertTrue(view.showsGallery)
        XCTAssertTrue(view.backButton.isHidden)
        XCTAssertTrue(view.backButton.isAccessibilityHidden())
        XCTAssertEqual(exits, 0)
    }

    func testCardsUseThreeLargeAndFourMiniaturesOnlyForOverflow() {
        let gallery = AppLibraryGalleryView(frame: .init(x: 0, y: 0, width: 800, height: 600))
        gallery.apply(entries: (0..<80).map { entry($0) }, strings: strings, generation: 1, pipeline: nil)
        let card = gallery.cards[0]
        XCTAssertEqual(card.iconButtons.count, 7)
        XCTAssertEqual(card.iconButtons.filter { !$0.isMiniature }.count, 3)
        XCTAssertEqual(card.iconButtons.filter(\.isMiniature).count, 4)
        XCTAssertEqual(card.iconButtons.filter { $0.isAccessibilityHidden() }.count, 0)
        XCTAssertEqual(card.iconButtons[3].accessibilityIdentifier(), "library.card.utilities.app.3")
        XCTAssertTrue(card.iconButtons[3].isEnabled)
        card.frame = .init(x: 0, y: 0, width: 220, height: 252)
        card.layoutSubtreeIfNeeded()
        for button in card.iconButtons { XCTAssertTrue(card.bounds.contains(button.frame)) }
        gallery.apply(entries: (0..<4).map { entry($0) }, strings: strings, generation: 2, pipeline: nil)
        XCTAssertTrue(gallery.cards[0].iconButtons.allSatisfy { !$0.isMiniature })
    }
    func testExplicitCategoryFilterAndBackRestoreGalleryWithoutLeavingLibrary() throws {
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700), strings: strings)
        defer { view.reset() }
        var categories: [AppLibraryCategory?] = []
        var backs = 0
        view.onCategoryChange = { categories.append($0) }
        view.onBack = { backs += 1 }
        apply(view, [entry(1)])
        try selectCategory(.utilities, in: view)
        XCTAssertEqual(view.selectedCategory, .utilities)
        apply(view, [entry(1)], generation: 2)
        XCTAssertFalse(view.showsGallery)
        view.back(nil)
        XCTAssertNil(view.selectedCategory)
        XCTAssertEqual(categories, [.utilities, nil])
        XCTAssertEqual(backs, 0)
        apply(view, [entry(1)], generation: 3)
        XCTAssertTrue(view.showsGallery)
        XCTAssertTrue(view.handleEscape())
        XCTAssertEqual(backs, 1)
    }
    func testEveryIconUsesCurrentImmutableRequestButBlockedStaleAndLoadingDoNotOpen() {
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700), strings: strings)
        defer { view.reset() }
        let entries = (0..<8).map { entry($0) }
        var requests: [AppLibraryActionRequest] = []
        view.onOpen = { requests.append($0) }
        apply(view, entries, generation: 9)
        let oldCard = view.galleryView.cards[0]
        for button in oldCard.iconButtons { button.performClick(nil) }
        XCTAssertEqual(requests, entries.prefix(7).map {
            .init(record: $0.record, catalogRevision: .init(9), generation: 9)
        })
        view.setAppActionsBlocked(true)
        for button in oldCard.iconButtons {
            XCTAssertFalse(button.isEnabled)
            button.performClick(nil)
            button.onActivate?()
            button.onDetails?()
        }
        XCTAssertEqual(requests.count, 7)
        XCTAssertFalse(view.detailsOpen)
        view.setAppActionsBlocked(false)
        apply(view, entries, generation: 10)
        withExtendedLifetime(oldCard) {
            for button in oldCard.iconButtons {
                XCTAssertFalse(button.isEnabled)
                button.performClick(nil)
                button.onActivate?()
                button.onDetails?()
            }
        }
        XCTAssertEqual(requests.count, 7, "Detached old-generation controls must not issue a fresh action")
        let currentCard = view.galleryView.cards[0]
        currentCard.iconButtons[6].performClick(nil)
        XCTAssertEqual(requests.last, .init(record: entries[6].record, catalogRevision: .init(10), generation: 10))
        apply(view, entries, generation: 11, loading: true)
        XCTAssertTrue(view.galleryView.cards.isEmpty)
        for button in currentCard.iconButtons {
            XCTAssertFalse(button.isEnabled)
            button.performClick(nil)
            button.onActivate?()
            button.onDetails?()
        }
        XCTAssertEqual(requests.count, 8)
        XCTAssertNil(view.selectedCategory)
        XCTAssertFalse(view.detailsOpen)
    }
    func testAllVisibleIconsLaunchTheirRepresentedAppsWithoutCategoryExpansion() {
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700), strings: strings)
        defer { view.reset() }
        let entries = (0..<80).map { entry($0) }
        var categories: [AppLibraryCategory?] = []
        var requests: [AppLibraryActionRequest] = []
        view.onCategoryChange = { categories.append($0) }
        view.onOpen = { requests.append($0) }
        apply(view, entries, generation: 37)
        let card = view.galleryView.cards[0]
        for (button, entry) in zip(card.iconButtons, entries) {
            button.performClick(nil)
            XCTAssertEqual(requests.last, .init(record: entry.record, catalogRevision: .init(37), generation: 37))
            XCTAssertNil(view.selectedCategory)
            XCTAssertTrue(view.showsGallery)
            XCTAssertFalse(view.detailsOpen)
        }
        XCTAssertEqual(requests.count, 7)
        XCTAssertTrue(categories.isEmpty)
    }
    func testCardBackgroundAndCaptionHaveNoCategoryControlOrAccessibilityPress() throws {
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700), strings: strings)
        defer { view.reset() }
        var categories: [AppLibraryCategory?] = []
        var requests: [AppLibraryActionRequest] = []
        view.onCategoryChange = { categories.append($0) }
        view.onOpen = { requests.append($0) }
        apply(view, (0..<8).map { entry($0) })
        let card = try XCTUnwrap(view.galleryView.cards.first)
        let caption = try XCTUnwrap(card.subviews.compactMap { $0 as? NSTextField }.first)
        let allSubviews = descendants(of: card)
        XCTAssertEqual(allSubviews.compactMap { $0 as? NSButton }.count, card.iconButtons.count)
        XCTAssertFalse(allSubviews.contains { $0.accessibilityIdentifier().hasPrefix("library.card.open.") })
        XCTAssertFalse(card.responds(to: NSSelectorFromString("enterCategory:")))
        XCTAssertTrue(card.isAccessibilityElement())
        XCTAssertEqual(card.accessibilityRole(), .group)
        XCTAssertEqual(card.accessibilityLabel(), "Utilities, 8")
        XCTAssertFalse(card.acceptsFirstResponder)
        XCTAssertFalse(card.accessibilityPerformPress())
        XCTAssertEqual(caption.stringValue, "Utilities")
        XCTAssertFalse(caption.isAccessibilityElement())
        XCTAssertFalse(caption.isSelectable)
        XCTAssertFalse(caption.acceptsFirstResponder)
        XCTAssertNil(caption.target)
        XCTAssertNil(caption.action)
        XCTAssertFalse(caption.accessibilityPerformPress())
        let backgroundHit = try XCTUnwrap(card.hitTest(.init(x: card.frame.midX, y: card.frame.minY + 2)))
        XCTAssertFalse(backgroundHit is NSControl)
        let captionPoint = card.convert(.init(x: caption.frame.midX, y: caption.frame.midY), to: card.superview)
        let captionHit = try XCTUnwrap(card.hitTest(captionPoint))
        XCTAssertFalse(captionHit is NSButton)
        XCTAssertTrue(requests.isEmpty)
        XCTAssertTrue(categories.isEmpty)
        XCTAssertNil(view.selectedCategory)
        XCTAssertTrue(view.showsGallery)
    }
    func testEveryVisibleIconExposesItsOwnAppLabelAndKeyboardFocus() {
        let gallery = AppLibraryGalleryView(frame: .init(x: 0, y: 0, width: 800, height: 600))
        let entries = (0..<8).map { entry($0) }
        gallery.apply(entries: entries, strings: strings, generation: 1, pipeline: nil)
        for (index, button) in gallery.cards[0].iconButtons.enumerated() {
            XCTAssertTrue(button.isAccessibilityElement())
            XCTAssertFalse(button.isAccessibilityHidden())
            XCTAssertEqual(button.accessibilityLabel(), entries[index].displayName)
            XCTAssertEqual(button.toolTip, entries[index].displayName)
            XCTAssertEqual(button.accessibilityIdentifier(), "library.card.utilities.app.\(index)")
            XCTAssertFalse(button.refusesFirstResponder)
        }
    }
    func testDisallowingApplicationActionsBlocksEveryIconBeforeAndAfterBinding() {
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700), strings: strings)
        defer { view.reset() }
        let entries = (0..<8).map { entry($0) }
        var requests: [AppLibraryActionRequest] = []
        view.onOpen = { requests.append($0) }
        for disabledBeforeBinding in [true, false] {
            view.allowsExternalApplicationActions = !disabledBeforeBinding
            apply(view, entries)
            view.allowsExternalApplicationActions = false
            let card = view.galleryView.cards[0]
            for button in card.iconButtons {
                XCTAssertFalse(button.isEnabled)
                button.performClick(nil)
                button.onActivate?()
            }
            card.onOpen?(entries[6].record.id)
            XCTAssertTrue(requests.isEmpty, "Miniatures and retained callbacks must obey the same launch policy")
        }
        view.allowsExternalApplicationActions = true
        let card = view.galleryView.cards[0]
        XCTAssertTrue(card.iconButtons.allSatisfy(\.isEnabled))
        card.iconButtons[6].performClick(nil)
        XCTAssertEqual(requests, [.init(record: entries[6].record, catalogRevision: .init(1), generation: 1)])
        XCTAssertNil(view.selectedCategory)
    }
    func testEveryIconRetainsItsOwnDetailsContextActionAndBlockedMenusStayInert() throws {
        let gallery = AppLibraryGalleryView(frame: .init(x: 0, y: 0, width: 800, height: 600))
        let entries = (0..<8).map { entry($0) }
        let event = try contextEvent()
        var details: [AppID] = []
        var opens: [AppID] = []
        gallery.onOpen = { opens.append($0) }
        gallery.onDetails = { details.append($0) }
        gallery.apply(entries: entries, strings: strings, generation: 1, pipeline: nil)
        let card = gallery.cards[0]
        var menus: [NSMenu] = []
        for button in card.iconButtons {
            let menu = try XCTUnwrap(button.menu(for: event))
            XCTAssertEqual(menu.items.map(\.title), [strings.libraryText(.details)])
            menu.performActionForItem(at: 0)
            menus.append(menu)
        }
        XCTAssertEqual(details, entries.prefix(7).map(\.record.id))
        XCTAssertTrue(opens.isEmpty)
        gallery.setBlocked(true)
        for (button, menu) in zip(card.iconButtons, menus) {
            XCTAssertNil(button.menu(for: event))
            menu.performActionForItem(at: 0)
            button.onDetails?()
        }
        XCTAssertEqual(details.count, 7)
        gallery.setBlocked(false)
        gallery.apply(entries: entries, strings: strings, generation: 2, pipeline: nil)
        for (button, menu) in zip(card.iconButtons, menus) {
            XCTAssertFalse(button.isEnabled)
            XCTAssertNil(button.menu(for: event))
            menu.performActionForItem(at: 0)
            button.onDetails?()
        }
        XCTAssertEqual(details.count, 7, "A retained context menu cannot outlive its card binding")
        XCTAssertTrue(opens.isEmpty)
    }
    func testSearchAndKeyboardAllResultsRetainAccessibleListPath() {
        let window = NSWindow(contentRect: .init(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 800, height: 600), strings: strings)
        window.contentView = view
        defer { view.reset(); window.contentView = nil; window.close() }
        apply(view, [entry(1)])
        view.focusSearch()
        _ = view.control(view.searchField, textView: NSTextView(), doCommandBy: #selector(NSResponder.moveDown(_:)))
        view.layoutSubtreeIfNeeded()
        XCTAssertFalse(view.showsGallery)
        XCTAssertFalse(view.resultsTable.isHiddenOrHasHiddenAncestor)
        XCTAssertTrue(window.firstResponder === view.resultsTable)
        XCTAssertTrue(view.handleEscape())
        apply(view, [entry(1)], generation: 2)
        XCTAssertTrue(view.showsGallery)
        view.searchField.stringValue = "Gallery"
        view.controlTextDidChange(.init(name: NSControl.textDidChangeNotification, object: view.searchField))
        apply(view, [entry(1)], generation: 3)
        XCTAssertFalse(view.showsGallery)
        XCTAssertTrue(view.galleryView.isHidden)
    }
    func testRelabelRebindRevokesOldControlsEvenWithSameProjectionGeneration() throws {
        let gallery = AppLibraryGalleryView(frame: .init(x: 0, y: 0, width: 800, height: 600))
        let entries = (0..<8).map { entry($0) }
        var opens = 0
        var details = 0
        gallery.onOpen = { _ in opens += 1 }
        gallery.onDetails = { _ in details += 1 }
        gallery.apply(entries: entries, strings: strings, generation: 1, pipeline: nil)
        let oldCard = gallery.cards[0]
        let oldOpen = try XCTUnwrap(oldCard.onOpen)
        let oldDetails = try XCTUnwrap(oldCard.onDetails)
        gallery.apply(entries: entries, strings: .init(language: .japanese), generation: 1, pipeline: nil)
        withExtendedLifetime(oldCard) {
            XCTAssertTrue(oldCard.isAccessibilityHidden())
            XCTAssertNil(oldCard.onOpen)
            XCTAssertNil(oldCard.onDetails)
            for button in oldCard.iconButtons {
                XCTAssertFalse(button.isEnabled)
                button.performClick(nil)
                button.onActivate?()
                button.onDetails?()
            }
            // Captured gallery callbacks still have to reject the old binding,
            // independently of the retired card's disabled buttons and callbacks.
            oldOpen(entries[6].record.id)
            oldDetails(entries[6].record.id)
            XCTAssertEqual(opens, 0)
            XCTAssertEqual(details, 0)
        }
        gallery.cards[0].iconButtons[6].performClick(nil)
        XCTAssertEqual(opens, 1)
    }
    func testReplacedCardsHaveNoRetainedButtonClosureCycle() {
        let gallery = AppLibraryGalleryView(frame: .init(x: 0, y: 0, width: 800, height: 600))
        weak var card: LibraryCategoryCard?
        weak var button: LibraryGalleryIconButton?
        autoreleasepool {
            gallery.apply(entries: (0..<8).map { entry($0) }, strings: strings, generation: 1, pipeline: nil)
            card = gallery.cards.first
            button = card?.iconButtons.first
            gallery.apply(entries: [], strings: strings, generation: 2, pipeline: nil)
        }
        XCTAssertNil(card)
        XCTAssertNil(button)
    }
    func testEmptyAndResetDoNotKeepCardsOrActions() {
        let view = AppLibraryView(frame: .init(x: 0, y: 0, width: 800, height: 600), strings: strings)
        apply(view, [entry(1)])
        view.reset()
        XCTAssertTrue(view.galleryView.cards.isEmpty)
        apply(view, [])
        XCTAssertTrue(view.galleryView.cards.isEmpty)
        XCTAssertFalse(view.statusLabel.isHidden)
    }
}
