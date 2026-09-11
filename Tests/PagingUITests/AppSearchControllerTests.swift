// PagingUITests — AppSearchControllerTests（Phase 1D §16.4 AppKit/responder：控制器逻辑）
// 实现：T-1D-D（Worker D）。
//
// 验证：Command-F 进入搜索；实时输入 → 查询代（latest-wins）；Escape 非空清 query / 空退出；
// ↓/Return/Enter 只转移焦点到首个已显示结果（首次不启动）；网格焦点后 Return 启动一次；
// Tab 不吞；无已提交结果 / pending generation 不启动旧结果；无结果不建伪焦点。

import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import AppIconPipeline
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class AppSearchControllerTests: XCTestCase {

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
        // 容器：surface + search field 作为 sibling overlay（不随页面容器平移）。
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

    private func type(_ text: String) {
        search.field.stringValue = text
        search.field.currentEditor()?.string = text
        search.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: search.field))
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

    private func returnKeyEvent() -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                         timestamp: 0, windowNumber: 0, context: nil,
                         characters: "\r", charactersIgnoringModifiers: "\r",
                         isARepeat: false, keyCode: 36)!
    }

    private func doCommand(_ selector: Selector) -> Bool {
        search.control(search.field, textView: NSTextView(), doCommandBy: selector)
    }

    // MARK: - Command-F 进入搜索

    func testCommandFEntersSearch() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        XCTAssertTrue(window.firstResponder === keyboard)
        let handled = keyboard.performKeyEquivalent(with: commandFEvent())
        XCTAssertTrue(handled, "Command-F 被键盘代理处理")
        XCTAssertTrue(fieldIsFirstResponder(), "Command-F → 搜索框 first responder")
    }

    // MARK: - 实时输入 → 查询代

    func testTypingUpdatesQueryAndCommits() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        search.activateSearch()
        type("e")
        XCTAssertEqual(search.presentation.currentQuery?.raw, "e")
        XCTAssertEqual(search.presentation.latestGeneration, AppSearchGeneration(1))
        XCTAssertEqual(search.presentation.provider.presentationRecords.map { $0.displayName }, ["Beta"],
                       "实时输入 → 过滤结果提交")
    }

    func testRapidTypingLatestWins() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma", "Delta"])
        search.activateSearch()
        type("a")
        type("b")
        type("d")
        XCTAssertEqual(search.presentation.currentQuery?.raw, "d", "latest-wins：只最新 query 生效")
        XCTAssertEqual(search.presentation.latestGeneration, AppSearchGeneration(3), "查询代单调递增")
        XCTAssertEqual(search.presentation.provider.presentationRecords.map { $0.displayName }, ["Delta"])
    }

    // MARK: - Escape 语义

    func testEscapeNonEmptyClearsQueryKeepsField() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        search.activateSearch()
        type("e")
        XCTAssertEqual(search.presentation.provider.presentationRecords.map { $0.displayName }, ["Beta"])
        let handled = doCommand(#selector(NSResponder.cancelOperation(_:)))
        XCTAssertTrue(handled)
        XCTAssertEqual(search.field.stringValue, "", "Escape 清空 field 文本")
        XCTAssertEqual(search.presentation.provider.presentationRecords.count, 3, "恢复全 catalog")
        XCTAssertTrue(fieldIsFirstResponder(), "Escape 非空后保持搜索框 first responder")
    }

    func testEscapeEmptyExitsRestoresKeyboardDeferred() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        search.activateSearch()
        XCTAssertTrue(fieldIsFirstResponder())
        let handled = doCommand(#selector(NSResponder.cancelOperation(_:)))
        XCTAssertTrue(handled)
        XCTAssertTrue(window.firstResponder === keyboard, "Escape 空 query → 恢复键盘控制器")
        XCTAssertNil(keyboard.focusModel.current, "恢复后保持延迟焦点（无自动选择框）")
    }

    // MARK: - ↓/Return/Enter 转移焦点（首次不启动）

    func testDownTransfersFocusToFirstResultNoLaunch() async throws {
        let apps = (0..<10).map { String(format: "App%02d", $0) }
        try await readyCatalog(apps: apps)
        search.activateSearch()
        type("App")
        XCTAssertEqual(search.presentation.provider.presentationRecords.count, 10)
        var activated = 0
        keyboard.onActivate = { _ in activated += 1 }
        let handled = doCommand(#selector(NSResponder.moveDown(_:)))
        XCTAssertTrue(handled)
        XCTAssertEqual(keyboard.focusModel.current?.pageIndex, 0, "焦点转移到当前已显示页")
        XCTAssertEqual(keyboard.focusModel.current?.slotIndex, 0, "首个有效结果")
        XCTAssertTrue(window.firstResponder === keyboard, "焦点转移到网格（键盘控制器）")
        XCTAssertEqual(activated, 0, "首次不启动")
    }

    func testReturnTransfersFocusThenGridReturnLaunchesOnce() async throws {
        let apps = (0..<10).map { String(format: "App%02d", $0) }
        try await readyCatalog(apps: apps)
        search.activateSearch()
        type("App")
        var activated = 0
        keyboard.onActivate = { _ in activated += 1 }
        // field 中 Return → 只转移焦点，不启动。
        let handled = doCommand(#selector(NSResponder.insertNewline(_:)))
        XCTAssertTrue(handled)
        XCTAssertTrue(window.firstResponder === keyboard)
        XCTAssertEqual(activated, 0, "field 中 Return 不启动")
        // 网格焦点后 Return → 启动一次。
        keyboard.keyDown(with: returnKeyEvent())
        XCTAssertEqual(activated, 1, "网格焦点后 Return 启动一次")
    }

    // MARK: - Tab 不吞

    func testTabNotSwallowed() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta"])
        search.activateSearch()
        XCTAssertFalse(doCommand(#selector(NSResponder.insertTab(_:))), "Tab 交给 AppKit responder chain")
        XCTAssertFalse(doCommand(#selector(NSResponder.insertBacktab(_:))), "Shift-Tab 不吞")
    }

    // MARK: - 无已提交结果 / pending generation 不启动旧结果

    func testNoCommittedResultsReturnDoesNotLaunch() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        search.activateSearch()
        type("zzz") // 无匹配 → presentationRecords 空
        XCTAssertEqual(search.presentation.provider.presentationRecords.count, 0)
        var activated = 0
        keyboard.onActivate = { _ in activated += 1 }
        let handled = doCommand(#selector(NSResponder.insertNewline(_:)))
        XCTAssertFalse(handled, "无已提交结果 → Return 不转移/不启动")
        XCTAssertNil(keyboard.focusModel.current, "不建立伪焦点")
        XCTAssertEqual(activated, 0, "不启动旧结果")
    }

    func testPendingGenerationReturnDoesNotTransfer() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        search.activateSearch()
        type("e") // 提交 [Beta]
        XCTAssertEqual(search.presentation.provider.presentationRecords.map { $0.displayName }, ["Beta"])
        // 暂存新 query（pending generation，未提交）。
        search.presentation.updateQuery(AppSearchQuery(raw: "zzz"))
        XCTAssertTrue(search.presentation.provider.hasPendingSearchResult, "pending generation 存在")
        var activated = 0
        keyboard.onActivate = { _ in activated += 1 }
        let handled = doCommand(#selector(NSResponder.insertNewline(_:)))
        XCTAssertFalse(handled, "pending generation → Return 不转移到旧结果")
        XCTAssertNil(keyboard.focusModel.current, "不建立伪焦点")
        XCTAssertEqual(activated, 0, "不启动旧结果")
    }

    // MARK: - 无结果不建伪焦点

    func testNoResultsNoFakeFocusNoLaunch() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        search.activateSearch()
        type("zzz")
        XCTAssertEqual(search.presentation.provider.presentationRecords.count, 0)
        var activated = 0
        keyboard.onActivate = { _ in activated += 1 }
        let handled = doCommand(#selector(NSResponder.insertNewline(_:)))
        XCTAssertFalse(handled)
        XCTAssertNil(keyboard.focusModel.current, "无结果不建立伪焦点")
        XCTAssertEqual(activated, 0, "无结果不启动")
    }

    // MARK: - T-1D：isSearchActive seam + 共享退出例程

    func testIsSearchActiveTrueWhenFieldFocusedEmptyQuery() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        // canonical case：用户点击搜索框（空 query，还没开始搜索）→ 仍算搜索激活。
        window.makeFirstResponder(search.field)
        XCTAssertTrue(search.isSearchActive, "空 query + field first responder → 搜索激活（canonical）")
    }

    func testIsSearchActiveTrueWithNonEmptyQuery() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        XCTAssertFalse(search.isSearchActive, "初始未激活")
        search.activateSearch()
        type("e")
        XCTAssertTrue(search.isSearchActive, "非空 query → 搜索激活")
    }

    func testIsSearchActiveFalseByDefaultWhenInactive() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        XCTAssertFalse(search.isSearchActive, "搜索未激活 → seam 为 false")
    }

    func testIsSearchActiveFalseAfterEscapeEmptyExit() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        search.activateSearch()
        XCTAssertTrue(search.isSearchActive)
        _ = doCommand(#selector(NSResponder.cancelOperation(_:)))
        XCTAssertFalse(search.isSearchActive, "Escape 空 query 退出后搜索不再激活")
        XCTAssertTrue(window.firstResponder === keyboard, "恢复键盘控制器")
    }

    func testExitSearchAndRestoreFocusClearsQueryRestoresFocus() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        search.activateSearch()
        type("e")
        XCTAssertEqual(search.presentation.provider.presentationRecords.map { $0.displayName }, ["Beta"])
        XCTAssertTrue(search.isSearchActive)
        search.exitSearchAndRestoreFocus()
        XCTAssertFalse(search.isSearchActive, "共享退出例程后搜索不再激活")
        XCTAssertEqual(search.field.stringValue, "", "field 文本清空（若有 query 被清）")
        XCTAssertTrue(search.presentation.currentQuery?.isEmpty == true, "query 被清空")
        XCTAssertEqual(search.presentation.provider.presentationRecords.count, 3, "恢复全 catalog")
        XCTAssertTrue(window.firstResponder === keyboard, "恢复 KeyboardFocusController first responder")
    }
}
