// PagingUITests — AppSearchResponderTests（Phase 1D §16.4 AppKit/responder：first responder 转移/恢复）
// 实现：T-1D-D（Worker D）。
//
// 验证：Command-F 清除旧网格焦点视觉（避免双焦点）；窗口 resign/become key 后按状态重建
// first responder（F3 follow-up）；resize/teardown 安全（零 UI 写回、零崩溃）。

import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import AppIconPipeline
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class AppSearchResponderTests: XCTestCase {

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
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = container
        container.addSubview(surface)
        keyboard = KeyboardFocusController(columns: 5)
        keyboard.install(on: surface, focusModel: AppGridFocusModel())
        let presentation = AppGridSearchPresentationController(provider: assembly.provider)
        presentation.onSearchResultCommitted = { [weak surface] in
            surface?.reloadCurrentPresentation()
        }
        search = AppSearchController(presentation: presentation, keyboardController: keyboard, surface: surface)
        container.addSubview(search.field)
        search.install(in: window)
        window.makeFirstResponder(keyboard)
        keyboard.onSearchShortcut = { [weak search] in
            search?.activateSearch()
        }
    }

    override func tearDownWithError() throws {
        search?.teardown()
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

    // MARK: - helpers

    private func readyCatalog(apps: [String]) async throws {
        _ = try factory.makeApps(names: apps)
        assembly.begin()
        let committed = await waitUntil { self.assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
    }

    private func fieldIsFirstResponder() -> Bool {
        window.firstResponder === search.field || window.firstResponder === search.field.currentEditor()
    }

    private func commandFEvent() -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command],
                         timestamp: 0, windowNumber: 0, context: nil,
                         characters: "f", charactersIgnoringModifiers: "f",
                         isARepeat: false, keyCode: 3)!
    }

    // MARK: - Command-F 清除旧网格焦点视觉（避免双焦点）

    func testCommandFClearsGridFocusVisual() async throws {
        let apps = (0..<10).map { String(format: "App%02d", $0) }
        try await readyCatalog(apps: apps)
        // 建立网格焦点。
        let snapshot = try XCTUnwrap(assembly.provider.servedSnapshot)
        let layout = AppGridFocusLayout.build(from: snapshot, itemsPerPage: surface.itemsPerPage)
        let identity = try XCTUnwrap(layout.firstValidIdentity())
        keyboard.setFocus(to: identity)
        let cell = assembly.renderer.pageView(forPage: 0)?.cell(at: 0)
        XCTAssertEqual(cell?.isFocused, true, "网格焦点已建立")
        // Command-F → 搜索框 first responder + 旧网格焦点视觉清除。
        let handled = keyboard.performKeyEquivalent(with: commandFEvent())
        XCTAssertTrue(handled)
        XCTAssertTrue(fieldIsFirstResponder(), "Command-F → 搜索框 first responder")
        XCTAssertEqual(cell?.isFocused, false, "旧网格焦点视觉清除（避免双焦点）")
        XCTAssertNil(keyboard.focusModel.current, "网格焦点模型清空")
    }

    // MARK: - F3：窗口 resign/become key 后按状态重建 first responder

    func testWindowReKeyRestoresSearchFieldWhenActive() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        search.activateSearch()
        XCTAssertTrue(fieldIsFirstResponder())
        // 模拟系统控件夺焦（first responder 被清空）。
        window.makeFirstResponder(nil)
        XCTAssertFalse(fieldIsFirstResponder())
        // 窗口重新成为 key → 重建 first responder 为搜索框。
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
        XCTAssertTrue(fieldIsFirstResponder(), "搜索激活时窗口 re-key → 重建为搜索框")
    }

    func testWindowReKeyRestoresKeyboardWhenInactive() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        XCTAssertTrue(window.firstResponder === keyboard)
        // 模拟夺焦。
        window.makeFirstResponder(nil)
        XCTAssertFalse(window.firstResponder === keyboard)
        // 窗口重新成为 key → 重建 first responder 为键盘控制器。
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: window)
        XCTAssertTrue(window.firstResponder === keyboard, "搜索未激活时窗口 re-key → 重建为键盘控制器")
    }

    // MARK: - resize / teardown 安全

    func testResizeSafe() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        search.activateSearch()
        surface.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        surface.layout()
        // resize 后 field 仍可交互（不崩溃、不改变 first responder 语义）。
        search.field.stringValue = "e"
        search.field.currentEditor()?.string = "e"
        search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: search.field))
        XCTAssertEqual(search.presentation.provider.presentationRecords.map { $0.displayName }, ["Beta"])
    }

    func testTeardownSafe() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        search.activateSearch()
        surface.teardown()
        search.teardown()
        // teardown 后调用 → 零崩溃、零 UI 写回。
        search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: search.field))
        _ = search.control(search.field, textView: NSTextView(), doCommandBy: #selector(NSResponder.insertNewline(_:)))
        _ = search.control(search.field, textView: NSTextView(), doCommandBy: #selector(NSResponder.cancelOperation(_:)))
        XCTAssertTrue(surface.isTearingDown)
        XCTAssertNil(keyboard.focusModel.current, "teardown 后不建立焦点")
    }
}
