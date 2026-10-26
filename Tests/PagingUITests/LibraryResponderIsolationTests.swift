import AppGridUI
import AppKit
import XCTest
@testable import PagingPrototypeApp

private actor ResponderIsolationPreferencesStore: AppLibraryPersisting {
    func load() -> AppLibraryLoadResult { .loaded(.init(enabled: true)) }
    func save(_ preferences: AppLibraryPreferences, recoveringCorruptPayload: Bool) -> AppLibrarySaveResult { .saved }
}

/// Observe the teardown boundary without replacing AppKit's responder behavior.
private final class ResponderIsolationWindow: NSWindow {
    var beforeRelinquishing: (() -> Void)?
    var afterRelinquishing: (() -> Void)?

    override func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        if responder == nil { beforeRelinquishing?() }
        let accepted = super.makeFirstResponder(responder)
        if responder == nil { afterRelinquishing?() }
        return accepted
    }
}

private final class ResponderIsolationControl: NSControl {
    override var acceptsFirstResponder: Bool { true }
}

/// Real mounted, unshown windows and in-memory preferences only. These tests
/// establish responder ownership/order, not visible focus-ring compositing.
@MainActor
final class LibraryResponderIsolationTests: XCTestCase {
    @MainActor
    private final class Fixture {
        let host = NSView(frame: .init(x: 0, y: 0, width: 1000, height: 700))
        let gridControl = ResponderIsolationControl(frame: .init(x: 0, y: 0, width: 40, height: 24))
        let gridSearch = NSTextField(frame: .init(x: 50, y: 0, width: 240, height: 24))
        let window: ResponderIsolationWindow
        let owner: AppLibraryOwnerController
        let context = AppLibraryGridReturnContext(query: "grid draft", page: 3,
                                                selection: nil, searchWasFocused: true)

        init() {
            window = ResponderIsolationWindow(contentRect: host.bounds, styleMask: [.titled],
                                             backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            host.addSubview(gridControl)
            host.addSubview(gridSearch)
            owner = AppLibraryOwnerController(
                preferences: AppLibraryPreferencesCoordinator(store: ResponderIsolationPreferencesStore()),
                strings: .init(language: .english))
            owner.canTransition = { true }
            owner.captureGrid = { [weak self] in self?.context }
            owner.attach(to: host)
        }

        func teardown() {
            window.beforeRelinquishing = nil
            window.afterRelinquishing = nil
            owner.teardown()
            window.contentView = nil
            window.close()
        }
    }

    private func loadedFixture() async -> Fixture {
        let fixture = Fixture()
        await fixture.owner.preferences.loadIfNeeded()
        XCTAssertFalse(fixture.window.isVisible)
        return fixture
    }

    private func enterSearch(_ fixture: Fixture) throws -> (AppLibraryView, NSTextView) {
        XCTAssertTrue(fixture.owner.enter())
        let library = try XCTUnwrap(fixture.owner.view)
        library.layoutSubtreeIfNeeded()
        let editor = try XCTUnwrap(library.searchField.currentEditor() as? NSTextView)
        XCTAssertTrue(editor.isFieldEditor)
        XCTAssertTrue(fixture.window.firstResponder === editor)
        library.searchField.stringValue = "Library draft"
        editor.string = "Library draft"
        library.controlTextDidChange(.init(name: NSControl.textDidChangeNotification, object: library.searchField))
        XCTAssertEqual(library.query, "Library draft")
        return (library, editor)
    }

    private func assertSearchReleased(_ fixture: Fixture, library: AppLibraryView, editor: NSTextView,
                                      closing: () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        var relinquishedWhileMounted = false
        fixture.window.beforeRelinquishing = {
            if fixture.window.firstResponder === editor || fixture.window.firstResponder === library.searchField {
                relinquishedWhileMounted = true
                XCTAssertTrue(library.superview === fixture.host, file: file, line: line)
                XCTAssertTrue(library.window === fixture.window, file: file, line: line)
                XCTAssertEqual(library.query, "Library draft", "Resign before reset clears the draft", file: file, line: line)
            }
        }
        closing()
        fixture.window.beforeRelinquishing = nil
        XCTAssertTrue(relinquishedWhileMounted, "Explicitly resign before destroying ownership evidence", file: file, line: line)
        XCTAssertFalse(fixture.owner.isOpen, file: file, line: line)
        XCTAssertNil(fixture.owner.view, file: file, line: line)
        XCTAssertNil(library.superview, file: file, line: line)
        XCTAssertNil(library.searchField.currentEditor(), file: file, line: line)
        XCTAssertFalse(fixture.window.firstResponder === editor, file: file, line: line)
        XCTAssertFalse(fixture.window.firstResponder === library.searchField, file: file, line: line)
        XCTAssertEqual(library.query, "", file: file, line: line)
        XCTAssertFalse(fixture.window.isVisible, file: file, line: line)
    }

    func testBackRelinquishesSearchBeforeResetAndRestoresCapturedContext() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let (library, editor) = try enterSearch(fixture)
        var restored: AppLibraryGridReturnContext?
        fixture.owner.restoreGrid = { restored = $0 }
        assertSearchReleased(fixture, library: library, editor: editor) { fixture.owner.back() }
        XCTAssertEqual(restored, fixture.context)
    }

    func testSwipeReturnRelinquishesSearchBeforeRestoringFirstPageGridResponder() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let (library, editor) = try enterSearch(fixture)
        var restored: AppLibraryGridReturnContext?
        fixture.owner.restoreGrid = { context in
            restored = context
            // The outgoing pane stays mounted until the destination is restored,
            // but it has already relinquished every Library-owned editor.
            XCTAssertNotNil(library.superview)
            XCTAssertNil(library.searchField.currentEditor())
            XCTAssertFalse(fixture.window.firstResponder === editor)
            XCTAssertTrue(fixture.window.makeFirstResponder(fixture.gridControl))
        }
        assertSearchReleased(fixture, library: library, editor: editor) {
            XCTAssertTrue(fixture.owner.backToFirstGridPage())
        }
        XCTAssertEqual(restored, .init(query: fixture.context.query, page: 0, selection: nil, searchWasFocused: false))
        XCTAssertTrue(fixture.window.firstResponder === fixture.gridControl)
    }

    func testHideRelinquishesSearchWithoutRestoringGrid() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let (library, editor) = try enterSearch(fixture)
        fixture.owner.restoreGrid = { _ in XCTFail("Hide must not restore prior focus") }
        assertSearchReleased(fixture, library: library, editor: editor) { fixture.owner.hide() }
    }

    func testTeardownRelinquishesSearchBeforeDetaching() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let (library, editor) = try enterSearch(fixture)
        assertSearchReleased(fixture, library: library, editor: editor) { fixture.owner.teardown() }
    }

    func testHideRelinquishesOwnedControlWithoutAnyFieldEditor() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        XCTAssertTrue(fixture.owner.enter())
        let library = try XCTUnwrap(fixture.owner.view)
        let container = NSView(frame: library.bounds)
        let control = ResponderIsolationControl(frame: .init(x: 0, y: 0, width: 80, height: 24))
        library.addSubview(container)
        container.addSubview(control)
        XCTAssertTrue(fixture.window.makeFirstResponder(control))
        XCTAssertTrue(fixture.window.firstResponder === control)
        XCTAssertNil(library.searchField.currentEditor())
        var relinquishedWhileMounted = false
        fixture.window.beforeRelinquishing = {
            if fixture.window.firstResponder === control {
                relinquishedWhileMounted = library.superview === fixture.host
            }
        }
        fixture.owner.hide()
        fixture.window.beforeRelinquishing = nil
        XCTAssertTrue(relinquishedWhileMounted)
        XCTAssertFalse(fixture.window.firstResponder === control)
        XCTAssertNil(library.superview)
    }

    func testHideRelinquishesAnotherLibraryControlsFieldEditor() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        XCTAssertTrue(fixture.owner.enter())
        let library = try XCTUnwrap(fixture.owner.view)
        let field = NSTextField(frame: .init(x: 0, y: 80, width: 240, height: 24))
        library.addSubview(field)
        XCTAssertTrue(fixture.window.makeFirstResponder(field))
        let editor = try XCTUnwrap(field.currentEditor())
        XCTAssertTrue(fixture.window.firstResponder === editor)
        XCTAssertNil(library.searchField.currentEditor())
        fixture.owner.hide()
        XCTAssertFalse(fixture.window.firstResponder === editor)
        XCTAssertFalse(fixture.window.firstResponder === field)
        XCTAssertNil(field.currentEditor())
    }

    func testResetReacquiredLibraryResponderIsRelinquishedBeforeRemoval() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let (library, editor) = try enterSearch(fixture)
        let control = ResponderIsolationControl(frame: .init(x: 0, y: 80, width: 80, height: 24))
        library.addSubview(control)
        var refocusedDuringReset = false
        var relinquishedAfterReset = false
        // Exercise reset's synchronous ownership notification, standing in for
        // closeDetails or another reset consumer returning focus to the browser.
        library.onPresentationOwnershipChange = {
            guard library.query.isEmpty else { return }
            refocusedDuringReset = true
            XCTAssertTrue(library.superview === fixture.host)
            XCTAssertTrue(fixture.window.makeFirstResponder(control))
        }
        fixture.window.beforeRelinquishing = {
            if fixture.window.firstResponder === control {
                relinquishedAfterReset = true
                XCTAssertTrue(refocusedDuringReset)
                XCTAssertTrue(library.superview === fixture.host)
                XCTAssertEqual(library.query, "")
            }
        }
        fixture.owner.hide()
        library.onPresentationOwnershipChange = nil
        fixture.window.beforeRelinquishing = nil
        XCTAssertTrue(refocusedDuringReset)
        XCTAssertTrue(relinquishedAfterReset)
        XCTAssertFalse(fixture.window.firstResponder === control)
        XCTAssertFalse(fixture.window.firstResponder === editor)
        XCTAssertNil(library.superview)
    }

    func testClosePreservesNonownedControl() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        _ = try enterSearch(fixture)
        XCTAssertTrue(fixture.window.makeFirstResponder(fixture.gridControl))
        fixture.window.beforeRelinquishing = { XCTFail("Library must not relinquish a nonowned responder") }
        fixture.owner.back()
        fixture.window.beforeRelinquishing = nil
        XCTAssertTrue(fixture.window.firstResponder === fixture.gridControl)
    }

    func testHidePreservesReusedWindowFieldEditorNowOwnedByGridSearch() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let (library, _) = try enterSearch(fixture)
        XCTAssertTrue(fixture.window.makeFirstResponder(fixture.gridSearch))
        let editor = try XCTUnwrap(fixture.gridSearch.currentEditor() as? NSTextView)
        editor.setMarkedText("かな", selectedRange: .init(location: 2, length: 0),
                             replacementRange: .init(location: NSNotFound, length: 0))
        XCTAssertTrue(editor.hasMarkedText())
        fixture.window.beforeRelinquishing = { XCTFail("The shared editor now belongs to another control") }
        fixture.owner.hide()
        fixture.window.beforeRelinquishing = nil
        XCTAssertTrue(fixture.window.firstResponder === editor)
        XCTAssertTrue(fixture.gridSearch.currentEditor() === editor)
        XCTAssertTrue(editor.hasMarkedText())
        XCTAssertEqual(editor.string, "かな")
        XCTAssertNil(library.searchField.currentEditor())
    }

    func testPreviewEntryAndCancellationPreserveNonownedEditorAndComposition() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        XCTAssertTrue(fixture.window.makeFirstResponder(fixture.gridSearch))
        let editor = try XCTUnwrap(fixture.gridSearch.currentEditor() as? NSTextView)
        editor.setMarkedText("かな", selectedRange: .init(location: 2, length: 0),
                             replacementRange: .init(location: NSNotFound, length: 0))
        fixture.owner.setGridHidden = { _ in XCTFail("A preview does not hide the grid") }
        fixture.owner.restoreGrid = { _ in XCTFail("Cancelling a preview does not restore focus") }
        fixture.window.beforeRelinquishing = { XCTFail("A preview never owned this editor") }
        XCTAssertTrue(fixture.owner.enter(preview: true))
        let library = try XCTUnwrap(fixture.owner.view)
        library.layoutSubtreeIfNeeded()
        XCTAssertTrue(fixture.window.firstResponder === editor)
        XCTAssertNil(fixture.owner.preferredFirstResponder)
        XCTAssertNil(library.searchField.currentEditor())
        fixture.owner.cancelPreview()
        fixture.window.beforeRelinquishing = nil
        XCTAssertTrue(fixture.window.firstResponder === editor)
        XCTAssertTrue(editor.hasMarkedText())
        XCTAssertEqual(editor.string, "かな")
        XCTAssertNil(library.superview)
        XCTAssertFalse(fixture.window.isVisible)
    }

    func testPreviewCommitTakesSearchFocusOnlyAtCommitThenReleasesOnHide() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        XCTAssertTrue(fixture.window.makeFirstResponder(fixture.gridControl))
        XCTAssertTrue(fixture.owner.enter(preview: true))
        XCTAssertTrue(fixture.window.firstResponder === fixture.gridControl)
        XCTAssertTrue(fixture.owner.commitPreview())
        let library = try XCTUnwrap(fixture.owner.view)
        let editor = try XCTUnwrap(library.searchField.currentEditor())
        XCTAssertTrue(fixture.window.firstResponder === editor)
        fixture.owner.hide()
        XCTAssertNil(library.searchField.currentEditor())
        XCTAssertFalse(fixture.window.firstResponder === editor)
    }

    func testRejectedBackAndSwipePreserveLibraryComposition() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        let (library, editor) = try enterSearch(fixture)
        editor.setMarkedText("かな", selectedRange: .init(location: 2, length: 0),
                             replacementRange: .init(location: NSNotFound, length: 0))
        fixture.owner.canTransition = { false }
        fixture.window.beforeRelinquishing = { XCTFail("Reject admission before attempting resignation") }
        fixture.owner.back()
        XCTAssertFalse(fixture.owner.backToFirstGridPage())
        fixture.window.beforeRelinquishing = nil
        XCTAssertTrue(fixture.owner.isOpen)
        XCTAssertTrue(library.superview === fixture.host)
        XCTAssertTrue(fixture.window.firstResponder === editor)
        XCTAssertTrue(editor.hasMarkedText())
    }

    func testResponderAcquiredDuringResignationIsPreserved() async throws {
        let fixture = await loadedFixture()
        defer { fixture.teardown() }
        _ = try enterSearch(fixture)
        fixture.window.afterRelinquishing = {
            fixture.window.afterRelinquishing = nil
            XCTAssertTrue(fixture.window.makeFirstResponder(fixture.gridSearch))
        }
        fixture.owner.hide()
        fixture.window.afterRelinquishing = nil
        let editor = try XCTUnwrap(fixture.gridSearch.currentEditor())
        XCTAssertTrue(fixture.window.firstResponder === editor)
    }
}
