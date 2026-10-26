import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import AppIconPipeline
@testable import PagingPrototypeApp
@testable import PagingUI

/// Delegate-level composition ownership, not a physical input-method test.
@MainActor
final class AppSearchCompositionCommandTests: XCTestCase {
    private var factory: FakeAppFactory!
    private var surface: PagingSurface!
    private var assembly: AppCatalogAssembly!
    private var window: NSWindow!
    private var keyboard: KeyboardFocusController!
    private var search: AppSearchController!

    override func setUpWithError() throws {
        factory = try FakeAppFactory()
        surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        wireAssembly(assembly, to: surface)
        let bounds = NSRect(x: 0, y: 0, width: 1000, height: 700)
        window = NSWindow(contentRect: bounds, styleMask: [.titled], backing: .buffered, defer: false)
        let root = NSView(frame: bounds)
        window.contentView = root
        root.addSubview(surface)
        keyboard = KeyboardFocusController(columns: 5)
        keyboard.install(on: surface, focusModel: AppGridFocusModel())
        let presentation = AppGridSearchPresentationController(provider: assembly.provider)
        presentation.onSearchResultCommitted = { [weak surface] in surface?.reloadCurrentPresentation() }
        search = AppSearchController(presentation: presentation, keyboardController: keyboard, surface: surface)
        root.addSubview(search.field)
    }

    override func tearDownWithError() throws {
        search?.teardown()
        window?.makeFirstResponder(nil)
        search = nil
        keyboard = nil
        window = nil
        assembly?.teardown()
        assembly = nil
        surface?.teardown()
        surface = nil
        factory?.removeRoot()
        factory = nil
    }

    private func composingEditor() async throws -> NSTextView {
        _ = try factory.makeApps(names: ["App One", "App Two", "Other"])
        assembly.begin()
        let loaded = await waitUntil { self.assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(loaded)
        search.activateSearch()
        let editor = try XCTUnwrap(search.field.currentEditor() as? NSTextView)
        editor.setMarkedText("App", selectedRange: NSRange(location: 3, length: 0),
                             replacementRange: NSRange(location: NSNotFound, length: 0))
        search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: search.field))
        XCTAssertTrue(editor.hasMarkedText())
        XCTAssertTrue(window.firstResponder === editor)
        XCTAssertEqual(search.presentation.provider.presentationRecords.count, 2)
        return editor
    }

    private func assertCompositionRetained(for selector: Selector,
                                            file: StaticString = #filePath, line: UInt = #line) async throws {
        let editor = try await composingEditor()
        let marked = editor.markedRange(), selected = editor.selectedRange()
        let query = search.presentation.currentQuery?.raw
        let generation = search.presentation.latestGeneration
        let records = search.presentation.provider.presentationRecords.map(\.id)
        var exits = 0, activations = 0
        search.onSearchExited = { exits += 1 }
        keyboard.onActivate = { _ in activations += 1 }

        XCTAssertFalse(search.control(search.field, textView: editor, doCommandBy: selector), file: file, line: line)
        XCTAssertTrue(editor.hasMarkedText(), file: file, line: line)
        XCTAssertEqual(editor.markedRange(), marked, file: file, line: line)
        XCTAssertEqual(editor.selectedRange(), selected, file: file, line: line)
        XCTAssertEqual(editor.string, "App", file: file, line: line)
        XCTAssertEqual(search.presentation.currentQuery?.raw, query, file: file, line: line)
        XCTAssertEqual(search.presentation.latestGeneration, generation, file: file, line: line)
        XCTAssertEqual(search.presentation.provider.presentationRecords.map(\.id), records, file: file, line: line)
        XCTAssertTrue(window.firstResponder === editor, file: file, line: line)
        XCTAssertNil(keyboard.focusModel.current, file: file, line: line)
        XCTAssertEqual(exits, 0, file: file, line: line)
        XCTAssertEqual(activations, 0, file: file, line: line)
    }

    func testMarkedEscapeRemainsOwnedByNativeEditor() async throws {
        try await assertCompositionRetained(for: #selector(NSResponder.cancelOperation(_:)))
    }

    func testMarkedReturnDoesNotTransferToGrid() async throws {
        try await assertCompositionRetained(for: #selector(NSResponder.insertNewline(_:)))
    }

    func testMarkedDownDoesNotTransferToGrid() async throws {
        try await assertCompositionRetained(for: #selector(NSResponder.moveDown(_:)))
    }

    func testMarkedTabRemainsNative() async throws {
        try await assertCompositionRetained(for: #selector(NSResponder.insertTab(_:)))
    }

    func testReturnAfterCompositionStillTransfersWithoutLaunching() async throws {
        let editor = try await composingEditor()
        editor.unmarkText()
        var activations = 0
        keyboard.onActivate = { _ in activations += 1 }
        XCTAssertTrue(search.control(search.field, textView: editor,
                                     doCommandBy: #selector(NSResponder.insertNewline(_:))))
        XCTAssertTrue(window.firstResponder === keyboard)
        XCTAssertEqual(keyboard.focusModel.current?.slotIndex, 0)
        XCTAssertEqual(activations, 0)
    }
}
