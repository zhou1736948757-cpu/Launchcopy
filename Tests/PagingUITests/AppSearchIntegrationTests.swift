// PagingUITests — AppSearchIntegrationTests（Phase 1D §16.5 装配/空白点击/启动集成）
// 实现：T-1D-E（Worker E）。
//
// 验证 AppDelegate 的搜索装配接线（与生产 installContentAssembly 同构）：
// - search field 作为 sibling overlay（不随页面容器平移）；
// - Command-F 激活搜索；
// - 实时输入过滤结果；
// - 空白点击分类：搜索 field/editor/clear button 不退出；真实背景空白仍退出；
// - 启动复用 AppLaunchController.handleCell（无并行启动路径）；
// - 刷新重跑查询（idle 边界搜索提交优先）；
// - Escape 清空/还焦。
//
// 全部经 fake launcher / fake .app / 临时目录；绝不启动真实 bundle、不触碰 /Applications。

import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import AppIconPipeline
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class AppSearchIntegrationTests: XCTestCase {

    private var factory: FakeAppFactory!
    private var surface: PagingSurface!
    private var assembly: AppCatalogAssembly!
    private var window: NSWindow!
    private var container: NSView!
    private var keyboard: KeyboardFocusController!
    private var search: AppSearchController!
    private var launcher: RecordingLauncher!
    private var launchController: AppLaunchController!
    private var adapter: KeyboardLaunchAdapter!

    override func setUpWithError() throws {
        factory = try FakeAppFactory()
        surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        launcher = RecordingLauncher()
        // 容器：surface + search field 作为 sibling overlay（生产 AppDelegate 同构）。
        container = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
                          styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = container
        container.addSubview(surface)
        keyboard = KeyboardFocusController(columns: 5)
        keyboard.install(on: surface, focusModel: AppGridFocusModel())
        wireSearchAssembly()
        window.makeFirstResponder(keyboard)
    }

    override func tearDownWithError() throws {
        search?.teardown()
        search = nil
        adapter = nil
        keyboard = nil
        launchController = nil
        window = nil
        container = nil
        assembly?.teardown()
        assembly = nil
        surface?.teardown()
        surface = nil
        factory?.removeRoot()
        factory = nil
    }

    /// 生产 AppDelegate.installContentAssembly 的搜索接线同构（T-1D-E）。
    private func wireSearchAssembly() {
        // 装配接线（provider/renderer/提交回调/idle 提交/首扫提交）。
        surface.contentProvider = assembly.provider
        surface.renderer = assembly.renderer
        assembly.refreshController.itemsPerPage = surface.itemsPerPage
        assembly.onPresentationUpdate = { [weak self] update in
            self?.applyPresentationUpdate(update, overridePageCount: true)
        }
        // idle 边界：搜索提交优先，刷新控制器随后（生产 applyPendingAtIdleBoundary 同构）。
        surface.onIdleBoundary = { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.applyPendingAtIdleBoundary()
            }
        }
        assembly.refreshController.onStateChange = { [weak self] state in
            guard let self, let surface = self.surface, !state.isBusy else { return }
            if surface.core.state == .idle {
                MainActor.assumeIsolated {
                    self.applyPendingAtIdleBoundary()
                }
            }
        }
        // 搜索接线。
        let presentation = assembly.searchPresentation
        presentation.itemsPerPage = surface.itemsPerPage
        presentation.onSearchResultCommitted = { [weak self] in
            self?.surface?.reloadCurrentPresentation()
        }
        presentation.onPresentationUpdate = { [weak self] update in
            guard let self, let assembly = self.assembly else { return }
            if let snapshot = assembly.dataSource.currentSnapshot {
                assembly.urlResolver.update(from: snapshot)
            }
            let searchActive = self.search?.presentation.currentQuery != nil
            self.applyPresentationUpdate(update, overridePageCount: !searchActive)
        }
        search = AppSearchController(presentation: presentation,
                                     keyboardController: keyboard,
                                     surface: surface)
        container.addSubview(search.field)
        search.install(in: window)
        keyboard.onSearchShortcut = { [weak search] in
            search?.activateSearch()
        }
        // 启动接线（复用 handleCell，无并行路径）。
        launchController = AppLaunchController(surface: surface, assembly: assembly, launcher: launcher)
        launchController.install()
        adapter = KeyboardLaunchAdapter(
            launchController: launchController,
            cellResolver: { [weak surface] identity in
                guard let renderer = surface?.renderer as? AppGridRenderer else { return nil }
                return renderer.pageView(forPage: identity.pageIndex)?.cell(at: identity.slotIndex)
            }
        )
        keyboard.onActivate = { [weak adapter] identity in
            adapter?.activate(identity)
        }
    }

    private func applyPresentationUpdate(_ update: AppGridPresentationUpdate, overridePageCount: Bool) {
        guard let surface = self.surface, let assembly = self.assembly else { return }
        surface.refreshPresentation()
        if overridePageCount {
            surface.setPageCount(update.plan.pageCount)
        }
        let records = assembly.provider.presentationRecords
        if let base = assembly.provider.servedSnapshot {
            let snapshot = CatalogSnapshot(revision: base.revision, records: records)
            let layout = AppGridFocusLayout.build(from: snapshot, itemsPerPage: surface.itemsPerPage)
            self.keyboard?.applyLayout(layout)
        }
    }

    private func applyPendingAtIdleBoundary() {
        guard let surface = self.surface, let assembly = self.assembly else { return }
        self.search?.commitPendingAtIdleBoundary()
        _ = assembly.refreshController.applyPendingAtIdleBoundary(currentPage: surface.core.committedPage)
        self.keyboard?.reconcileSettledCrossPage(committedPage: surface.core.committedPage)
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

    // MARK: - search field 作为 sibling overlay

    func testSearchFieldIsSiblingOverlay() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        XCTAssertTrue(search.field.superview === container, "search field 应挂在容器（sibling overlay）")
        XCTAssertFalse(search.field.superview === surface, "search field 不得是 surface 子视图（不随页面平移）")
        XCTAssertTrue(surface.superview === container, "surface 应挂在容器")
    }

    // MARK: - Command-F 激活

    func testCommandFActivatesSearch() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        XCTAssertTrue(window.firstResponder === keyboard)
        let handled = keyboard.performKeyEquivalent(with: commandFEvent())
        XCTAssertTrue(handled, "Command-F 被键盘代理处理")
        XCTAssertTrue(fieldIsFirstResponder(), "Command-F → 搜索框 first responder")
    }

    // MARK: - 实时输入过滤

    func testTypingFiltersResults() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        search.activateSearch()
        type("e")
        XCTAssertEqual(search.presentation.currentQuery?.raw, "e")
        XCTAssertEqual(search.presentation.provider.presentationRecords.map { $0.displayName }, ["Beta"],
                       "实时输入 → 过滤结果提交")
    }

    // MARK: - 空白点击分类（interaction zone）

    func testBlankClickOnSearchFieldDoesNotQuit() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        // field 本身 → interaction zone（不退出）。
        XCTAssertTrue(blankClickResolvesToCell(search.field), "点击搜索 field 不应判定为空白退出")
        // field editor（编辑中 first responder）→ interaction zone。
        search.activateSearch()
        let editor = search.field.currentEditor()
        XCTAssertNotNil(editor, "激活后应有 field editor")
        if let editor {
            XCTAssertTrue(blankClickResolvesToCell(editor), "点击 field editor 不应判定为空白退出")
        }
    }

    func testBlankClickOnRealBackgroundQuits() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        // 真实背景空白（容器本身，非 cell / 非 search field）→ 仍判定为空白退出。
        XCTAssertFalse(blankClickResolvesToCell(container), "真实背景空白仍应判定为空白退出")
        XCTAssertFalse(blankClickResolvesToCell(nil), "nil hit 仍应判定为空白退出")
    }

    // MARK: - 启动复用 handleCell（无并行路径）

    func testSearchLaunchReusesHandleCell() async throws {
        let apps = try factory.makeApps(names: ["Alpha", "Beta", "Gamma"])
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        search.activateSearch()
        type("e") // 过滤 → [Beta]
        XCTAssertEqual(search.presentation.provider.presentationRecords.map { $0.displayName }, ["Beta"])
        // ↓ 转移焦点到首个结果（首次不启动）。
        let handled = doCommand(#selector(NSResponder.moveDown(_:)))
        XCTAssertTrue(handled)
        XCTAssertTrue(window.firstResponder === keyboard)
        XCTAssertEqual(launcher.opened.count, 0, "转移焦点不启动")
        // 网格焦点后 Return → 经 onActivate → KeyboardLaunchAdapter → handleCell 启动。
        keyboard.keyDown(with: returnKeyEvent())
        XCTAssertEqual(launcher.opened, [apps["Beta"]!], "搜索启动复用 handleCell 校验管线")
        XCTAssertEqual(launchController.outcomeCounts[.launched], 1)
    }

    // MARK: - 刷新重跑查询（idle 边界搜索提交优先）

    func testRefreshRerunsQueryOnNewBase() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        search.activateSearch()
        type("e") // 过滤 → [Beta]
        XCTAssertEqual(search.presentation.provider.presentationRecords.map { $0.displayName }, ["Beta"])
        // 新增匹配 app 并刷新 → 查询在新 base 上重跑。
        _ = try factory.makeApp(named: "Echo", bundleID: "fixture.echo")
        assembly.refreshNow()
        let rerun = await waitUntil {
            self.search.presentation.provider.presentationRecords.map { $0.displayName }.contains("Echo")
        }
        XCTAssertTrue(rerun, "刷新后查询应在新 base 上重跑（含 Echo）")
        XCTAssertEqual(Set(search.presentation.provider.presentationRecords.map { $0.displayName }),
                       ["Beta", "Echo"], "重跑结果 = 新 base 上匹配当前查询")
    }

    // MARK: - Escape 清空/还焦

    func testEscapeClearsQueryAndRestores() async throws {
        try await readyCatalog(apps: ["Alpha", "Beta", "Gamma"])
        search.activateSearch()
        type("e")
        XCTAssertEqual(search.presentation.provider.presentationRecords.map { $0.displayName }, ["Beta"])
        // Escape 非空 → 清空 query、恢复全 catalog、保持 field first responder。
        let handled = doCommand(#selector(NSResponder.cancelOperation(_:)))
        XCTAssertTrue(handled)
        XCTAssertEqual(search.field.stringValue, "", "Escape 清空 field 文本")
        XCTAssertEqual(search.presentation.provider.presentationRecords.count, 3, "恢复全 catalog")
        XCTAssertTrue(fieldIsFirstResponder(), "Escape 非空后保持搜索框 first responder")
        // Escape 空 → 离开搜索框、恢复键盘控制器。
        let handled2 = doCommand(#selector(NSResponder.cancelOperation(_:)))
        XCTAssertTrue(handled2)
        XCTAssertTrue(window.firstResponder === keyboard, "Escape 空 query → 恢复键盘控制器")
    }
}
