import AppKit
import LauncherLocalization
import XCTest
@testable import PagingPrototypeApp

/// The user superseded the old local-blue-decoration design on 2026-10-20.
/// Mounted native controls only; no physical/compositor acceptance is implied.
@MainActor
final class LibrarySearchFocusDrawingTests: XCTestCase {
    private func mounted(_ field: NSSearchField) -> (NSWindow, NSView) {
        let host = NSView(frame: .init(x: 0, y: 0, width: 1000, height: 700))
        let window = NSWindow(contentRect: host.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        field.frame = .init(x: 100, y: 100, width: 640, height: 40)
        host.addSubview(field)
        return (window, host)
    }
    private func dispose(_ window: NSWindow) {
        window.makeFirstResponder(nil); window.contentView = nil; window.close()
    }
    private func assertNoOutline(_ field: NSSearchField, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(field.focusRingType, .none, file: file, line: line)
        XCTAssertEqual(field.cell?.focusRingType, NSFocusRingType.none, file: file, line: line)
        XCTAssertFalse(field.subviews.contains { $0.identifier?.rawValue == "library.search.focusDecoration" }, file: file, line: line)
    }
    func testLibraryAndMainHeaderUseTheSameNativeStyleAndVisiblePlaceholder() {
        let strings = LocalizedStrings(language: .simplifiedChinese)
        let main = AppSearchFieldView()
        main.relabel(strings: strings)
        let library = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700), strings: strings)
        defer { library.reset() }
        XCTAssertEqual(library.searchField.font, main.font)
        XCTAssertEqual(library.searchField.controlSize, main.controlSize)
        XCTAssertEqual(library.searchField.placeholderString, main.placeholderString)
        assertNoOutline(main)
        assertNoOutline(library.searchField)
    }

    func testBothLauncherSearchControlsHaveNoNativeOrCustomOutline() {
        assertNoOutline(AppSearchFieldView(frame: .zero))
        assertNoOutline(LibrarySearchField(frame: .zero))
    }
    func testOrdinarySearchControlsKeepTheirOwnFocusPolicy() {
        let ordinary = NSSearchField()
        let type = ordinary.focusRingType; let cellType = ordinary.cell?.focusRingType
        _ = AppSearchFieldView(); _ = LibrarySearchField()
        XCTAssertEqual(ordinary.focusRingType, type)
        XCTAssertEqual(ordinary.cell?.focusRingType, cellType)
    }
    func testBothControlsKeepNativeRendererAndIntrinsicHeight() {
        for field in [AppSearchFieldView(), LibrarySearchField()] as [NSSearchField] {
            let ordinary = NSSearchField(frame: field.frame)
            XCTAssertEqual(field.wantsUpdateLayer, ordinary.wantsUpdateLayer)
            XCTAssertEqual(field.intrinsicContentSize.height, ordinary.intrinsicContentSize.height)
        }
    }
    func testMainSearchStillAcquiresNativeEditorAndSelection() throws {
        let field = AppSearchFieldView(); let (window, _) = mounted(field)
        defer { dispose(window) }
        field.stringValue = "Synthetic"
        XCTAssertTrue(window.makeFirstResponder(field))
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        editor.setSelectedRange(.init(location: 1, length: 3))
        XCTAssertEqual(editor.selectedRange(), .init(location: 1, length: 3))
        assertNoOutline(field)
    }
    func testLibrarySearchStillAcquiresNativeEditorAndMarkedText() throws {
        let field = LibrarySearchField(); let (window, _) = mounted(field)
        defer { dispose(window) }
        XCTAssertTrue(window.makeFirstResponder(field))
        let editor = try XCTUnwrap(field.currentEditor() as? NSTextView)
        editor.setMarkedText("かな", selectedRange: .init(location: 2, length: 0), replacementRange: .init(location: NSNotFound, length: 0))
        XCTAssertTrue(editor.hasMarkedText())
        assertNoOutline(field)
    }
    func testLayoutAndAncestorTransformNeverCreateDecoration() {
        let field = LibrarySearchField(); let (window, root) = mounted(field)
        defer { dispose(window) }
        root.wantsLayer = true
        for width: CGFloat in [640, 250, 5, 640] {
            field.setFrameSize(.init(width: width, height: 40))
            field.layoutSubtreeIfNeeded()
            root.layer?.setAffineTransform(.init(translationX: -500, y: 0))
            assertNoOutline(field)
        }
    }
    func testRelabelingMainSearchDoesNotRestoreOutlineOrChangeText() {
        let field = AppSearchFieldView(); field.stringValue = "Synthetic"
        field.relabel(strings: .init(language: .japanese))
        XCTAssertEqual(field.stringValue, "Synthetic"); assertNoOutline(field)
    }
    func testLibraryWindowNotificationsPreserveSiblingComposition() throws {
        let library = AppLibraryView(frame: .init(x: 0, y: 0, width: 1000, height: 700), strings: .init(language: .english))
        let root = NSView(frame: library.bounds)
        let window = NSWindow(contentRect: root.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = root
        root.addSubview(library)
        defer { library.reset(); dispose(window) }
        let sibling = NSSearchField(frame: .init(x: 0, y: 0, width: 200, height: 28)); root.addSubview(sibling)
        library.focusSearch(); XCTAssertNotNil(library.searchField.currentEditor())
        XCTAssertTrue(window.makeFirstResponder(sibling))
        let editor = try XCTUnwrap(sibling.currentEditor() as? NSTextView)
        editor.setMarkedText("かな", selectedRange: .init(location: 2, length: 0), replacementRange: .init(location: NSNotFound, length: 0))
        for name in [NSWindow.didUpdateNotification, NSWindow.didResignKeyNotification, NSWindow.didBecomeKeyNotification] {
            NotificationCenter.default.post(name: name, object: window)
        }
        XCTAssertTrue(window.firstResponder === editor); XCTAssertTrue(editor.hasMarkedText())
        assertNoOutline(library.searchField)
    }
    func testEditingOwnershipNotificationsRemainWithoutDecorationState() {
        let library = AppLibraryView(frame: .zero, strings: .init(language: .english))
        var changes = 0; library.onPresentationOwnershipChange = { changes += 1 }
        library.controlTextDidBeginEditing(.init(name: NSControl.textDidBeginEditingNotification, object: library.searchField))
        library.controlTextDidEndEditing(.init(name: NSControl.textDidEndEditingNotification, object: library.searchField))
        XCTAssertEqual(changes, 2); assertNoOutline(library.searchField)
    }
    func testHideResignAndRemovalKeepNoOutline() {
        let field = LibrarySearchField(); let (window, _) = mounted(field)
        defer { dispose(window) }
        _ = window.makeFirstResponder(field)
        field.isHidden = true; field.isHidden = false
        _ = window.makeFirstResponder(nil)
        field.removeFromSuperview()
        assertNoOutline(field); XCTAssertNil(field.window)
    }
}
