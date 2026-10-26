// PagingUITests — KeyboardLaunchTests（Phase 1C §4.3 键盘启动适配）
// 实现：T-1C-C（Worker C）。
//
// 验证：Return/Enter 对有效焦点启动一次；stale revision / 缺 AppID / 文件消失拒绝；
// 启动失败非致命；无焦点 / 空 slot 不启动；鼠标与键盘共享同一校验管线；telemetry 红线。
// 全部经 fake launcher / fake .app / 临时目录；绝不启动真实 bundle、不触碰 /Applications。

import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import AppIconPipeline
@testable import PagingPrototypeApp
@testable import PagingTelemetry
@testable import PagingUI

@MainActor
final class KeyboardLaunchTests: XCTestCase {

    private var factory: FakeAppFactory!
    private var surface: PagingSurface!
    private var assembly: AppCatalogAssembly!
    private var launcher: RecordingLauncher!
    private var launchController: AppLaunchController!
    private var keyboard: KeyboardFocusController!
    private var adapter: KeyboardLaunchAdapter!

    override func setUpWithError() throws {
        factory = try FakeAppFactory()
        surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        wireAssembly(assembly, to: surface)
        launcher = RecordingLauncher()
    }

    override func tearDownWithError() throws {
        adapter = nil
        keyboard = nil
        launchController = nil
        assembly?.teardown()
        assembly = nil
        surface?.teardown()
        surface = nil
        factory?.removeRoot()
        factory = nil
    }

    private enum TestError: Error { case missingCell }

    /// 装配 + 首扫提交 + 建 launchController，返回 page 0 slot 0 的 cell。
    private func readyCell() async throws -> AppGridCellView {
        assembly.begin()
        let committed = await waitUntil { self.assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        launchController = AppLaunchController(surface: surface, assembly: assembly, launcher: launcher)
        guard let cell = assembly.renderer.pageView(forPage: 0)?.cell(at: 0) else {
            XCTFail("page 0 应有 cell")
            throw TestError.missingCell
        }
        return cell
    }

    /// 装配 + 首扫提交 + 焦点模型 + 键盘控制器 + 启动适配器（生产 AppDelegate 接线同构）。
    private func readyKeyboard(apps: [String]) async throws {
        _ = try factory.makeApps(names: apps)
        assembly.begin()
        let committed = await waitUntil { self.assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        let snapshot = try XCTUnwrap(assembly.provider.servedSnapshot)
        let layout = AppGridFocusLayout.build(from: snapshot, itemsPerPage: surface.itemsPerPage)
        var focusModel = AppGridFocusModel()
        focusModel.apply(layout: layout)
        launchController = AppLaunchController(surface: surface, assembly: assembly, launcher: launcher)
        keyboard = KeyboardFocusController(columns: 5)
        keyboard.install(on: surface, focusModel: focusModel)
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

    private func keyEvent(_ keyCode: UInt16) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                         timestamp: 0, windowNumber: 0, context: nil,
                         characters: "", charactersIgnoringModifiers: "",
                         isARepeat: false, keyCode: keyCode)!
    }

    private func returnKey() -> NSEvent { keyEvent(36) }

    // MARK: - AC1/AC2：Return 对有效焦点启动一次

    func testReturnLaunchesFocusedAppOnce() async throws {
        let apps = try factory.makeApps(names: ["Alpha", "Beta"])
        try await readyKeyboard(apps: ["Alpha", "Beta"])
        // 初始焦点 = page 0 slot 0（Alpha）。
        XCTAssertEqual(keyboard.focusModel.current?.slotIndex, 0)
        keyboard.keyDown(with: returnKey())
        XCTAssertEqual(launcher.opened, [apps["Alpha"]!], "Return 应启动聚焦的 Alpha 一次")
        XCTAssertEqual(launchController.outcomeCounts[.launched], 1)
    }

    func testReturnOnMovedFocusLaunchesThatApp() async throws {
        let apps = try factory.makeApps(names: ["Alpha", "Beta"])
        try await readyKeyboard(apps: ["Alpha", "Beta"])
        // 右移 → 焦点到 slot 1（Beta）。
        keyboard.keyDown(with: keyEvent(124))
        XCTAssertEqual(keyboard.focusModel.current?.slotIndex, 1)
        keyboard.keyDown(with: returnKey())
        XCTAssertEqual(launcher.opened, [apps["Beta"]!], "Return 应启动当前聚焦的 Beta")
    }

    // MARK: - AC3：stale revision 拒绝

    func testStaleRevisionRejected() async throws {
        _ = try factory.makeApps(names: ["Alpha"])
        let cell = try await readyCell()
        let served = try XCTUnwrap(assembly.provider.servedRevision)
        // 构造 stale cell：catalog revision 落后于已服务 revision（§3.2 stale 拒绝）。
        let staleToken = ItemBindingToken(
            catalogRevision: served - 1,
            pageIdentity: PagePresentationID(revision: served - 1, pageIndex: 0),
            itemSlot: 0,
            appID: cell.bindingToken?.appID,
            reuseGeneration: 1,
            iconKey: nil,
            surfaceGeneration: 1
        )
        let staleCell = AppGridCellView()
        staleCell.bind(name: "Alpha", token: staleToken)
        let adapter = KeyboardLaunchAdapter(launchController: launchController, cellResolver: { _ in staleCell })
        let identity = AppGridFocusIdentity(catalogRevision: served - 1, pageIndex: 0, slotIndex: 0,
                                            appID: cell.bindingToken?.appID as? AppID)
        let outcome = adapter.activate(identity)
        XCTAssertEqual(outcome, .rejectedStaleRevision, "旧 revision 焦点必须拒绝")
        XCTAssertTrue(launcher.opened.isEmpty, "stale 拒绝不得启动任何 bundle")
    }

    // MARK: - AC4：当前 snapshot 缺 AppID 拒绝

    func testMissingAppRejected() async throws {
        _ = try factory.makeApps(names: ["Alpha"])
        _ = try await readyCell()
        let served = try XCTUnwrap(assembly.provider.servedRevision)
        // 幽灵 AppID（不在当前 catalog 的 identity→URL 映射）→ 重新确认失败。
        let ghostToken = ItemBindingToken(
            catalogRevision: served,
            pageIdentity: PagePresentationID(revision: served, pageIndex: 0),
            itemSlot: 99,
            appID: AnyHashable(AppID.bundleIdentifier("fixture.ghost")),
            reuseGeneration: 1,
            iconKey: nil,
            surfaceGeneration: 1
        )
        let ghostCell = AppGridCellView()
        ghostCell.bind(name: "Ghost", token: ghostToken)
        let adapter = KeyboardLaunchAdapter(launchController: launchController, cellResolver: { _ in ghostCell })
        let identity = AppGridFocusIdentity(catalogRevision: served, pageIndex: 0, slotIndex: 99,
                                            appID: AppID.bundleIdentifier("fixture.ghost"))
        let outcome = adapter.activate(identity)
        XCTAssertEqual(outcome, .rejectedMissingApp, "不在当前 catalog → 拒绝")
        XCTAssertTrue(launcher.opened.isEmpty)
    }

    // MARK: - AC5：文件消失拒绝

    func testDeletedFileRejected() async throws {
        let apps = try factory.makeApps(names: ["Alpha"])
        let cell = try await readyCell()
        // catalog 与磁盘不一致：扫描后删除 bundle（磁盘重新确认失败）。
        try FileManager.default.removeItem(at: apps["Alpha"]!)
        let adapter = KeyboardLaunchAdapter(launchController: launchController, cellResolver: { _ in cell })
        let identity = AppGridFocusIdentity(catalogRevision: try XCTUnwrap(assembly.provider.servedRevision),
                                            pageIndex: 0, slotIndex: 0,
                                            appID: cell.bindingToken?.appID as? AppID)
        let outcome = adapter.activate(identity)
        XCTAssertEqual(outcome, .rejectedMissingFile, "bundle 已从磁盘消失 → 拒绝启动")
        XCTAssertTrue(launcher.opened.isEmpty)
    }

    // MARK: - AC6：启动失败非致命

    func testLaunchFailureNonFatalAndRecovers() async throws {
        _ = try factory.makeApps(names: ["Alpha"])
        try await readyKeyboard(apps: ["Alpha"])
        launcher.shouldSucceed = false
        keyboard.keyDown(with: returnKey())
        XCTAssertEqual(launchController.outcomeCounts[.failedToLaunch], 1, "启动失败 → 中性失败结果（非崩溃）")
        // 非致命：随后可正常启动（同会话继续可用）。
        launcher.shouldSucceed = true
        keyboard.keyDown(with: returnKey())
        XCTAssertEqual(launchController.outcomeCounts[.launched], 1, "失败非致命，后续启动恢复")
    }

    // MARK: - AC7：无焦点 / 空 slot 不启动

    func testNoFocusDoesNotLaunch() async throws {
        _ = try factory.makeApps(names: ["Alpha"])
        _ = try await readyCell()
        // 无焦点：空焦点模型（不 install，避免自动初始化焦点）→ Return 不触发激活。
        let keyboard = KeyboardFocusController(columns: 5)
        var activated = false
        keyboard.onActivate = { _ in activated = true }
        keyboard.keyDown(with: returnKey())
        XCTAssertFalse(activated, "无焦点 → 不触发激活回调")
        XCTAssertTrue(launcher.opened.isEmpty, "无焦点 → 不启动")
    }

    func testEmptySlotNoLaunch() async throws {
        _ = try factory.makeApps(names: ["Alpha", "Beta"])
        _ = try await readyCell()
        let served = try XCTUnwrap(assembly.provider.servedRevision)
        // 空 slot（itemsPerPage 35，仅 2 个有效 item → slot 5 无 cell）→ 中性拒绝，不启动。
        let identity = AppGridFocusIdentity(catalogRevision: served, pageIndex: 0, slotIndex: 5, appID: nil)
        let adapter = KeyboardLaunchAdapter(
            launchController: launchController,
            cellResolver: { [weak surface] id in
                guard let renderer = surface?.renderer as? AppGridRenderer else { return nil }
                return renderer.pageView(forPage: id.pageIndex)?.cell(at: id.slotIndex)
            }
        )
        let outcome = adapter.activate(identity)
        XCTAssertEqual(outcome, .rejectedNoBinding, "空 slot → 中性拒绝")
        XCTAssertTrue(launcher.opened.isEmpty)
    }

    // MARK: - AC8：鼠标与键盘共享同一校验管线

    func testMouseAndKeyboardShareValidation() async throws {
        let apps = try factory.makeApps(names: ["Alpha"])
        try await readyKeyboard(apps: ["Alpha"])
        // 键盘：Return 启动。
        keyboard.keyDown(with: returnKey())
        XCTAssertEqual(launchController.outcomeCounts[.launched], 1)
        // 鼠标：同一 cell 单击启动（共享 handleCell 校验管线）。
        let cell = try XCTUnwrap(assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let mouseOutcome = launchController.handleCell(cell)
        XCTAssertEqual(mouseOutcome, .launched)
        XCTAssertEqual(launchController.outcomeCounts[.launched], 2)
        XCTAssertEqual(launcher.opened, [apps["Alpha"]!, apps["Alpha"]!], "鼠标与键盘启动同一 bundle URL")
    }

    // MARK: - 红线：telemetry 无 URL/身份原文

    func testLaunchTelemetryContainsNoURL() async throws {
        let apps = try factory.makeApps(names: ["Alpha"])
        try await readyKeyboard(apps: ["Alpha"])

        let configuration = TelemetryConfiguration(
            enabled: true,
            runID: "keyboard-launch-redline-001",
            outputDirectory: factory.root.appendingPathComponent("telemetry", isDirectory: true)
        )
        let session = TelemetrySession(configuration: configuration)
        session.begin()
        // 重建 launchController 带 session（键盘路径同样只记中性 app.launch 事件）。
        launchController = AppLaunchController(surface: surface, assembly: assembly, launcher: launcher, session: session)
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
        keyboard.keyDown(with: returnKey())
        session.end()

        let url = factory.root.appendingPathComponent("telemetry/launch-copy-paging-prototype-keyboard-launch-redline-001.jsonl")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("\"event_phase\":\"app.launch\""), "应有 app.launch 中性事件")
        XCTAssertFalse(text.contains("Alpha"), "JSONL 不得含 app 名")
        XCTAssertFalse(text.contains("fixture.alpha"), "JSONL 不得含 bundle ID")
        XCTAssertFalse(text.contains(apps["Alpha"]!.path), "JSONL 不得含启动 URL/路径")
        XCTAssertFalse(text.contains(".app"), "JSONL 不得含 bundle 后缀")
    }

    // MARK: - ADDED（F1 repair）：可访问性焦点 / 视觉焦点 / 启动对象一致性（§4.2）

    /// 单一键盘代理必须保证 可访问性焦点、视觉焦点、实际启动对象 三者一致（§4.2），
    /// 且都指向 committed/displayed 页 —— 键盘跨页 settle 调和后的可执行断言。
    func testAccessibilityVisualFocusLaunchObjectConsistency() async throws {
        let names = (0..<60).map { String(format: "ConsistentApp%02d", $0) }
        let apps = try factory.makeApps(names: names)
        try await readyKeyboard(apps: names)
        // 装配：既有 idle 处理 + F1 键盘跨页 settle 调和（生产 AppDelegate 接线同构）。
        let prev = surface.onIdleBoundary
        surface.onIdleBoundary = { [weak keyboard, weak surface] in
            prev?()
            guard let keyboard, let surface else { return }
            keyboard.reconcileSettledCrossPage(committedPage: surface.core.committedPage)
        }
        // 导航到 page 0, slot 34（页末）→ 键盘跨页到 page 1。
        for _ in 0..<34 {
            keyboard.keyDown(with: keyEvent(124))
        }
        XCTAssertEqual(keyboard.focusModel.current?.pageIndex, 0)
        keyboard.keyDown(with: keyEvent(124))
        settleFrames(surface)
        let committed = surface.core.committedPage
        let identity = try XCTUnwrap(keyboard.focusModel.current)
        // ① 可访问性焦点（页描述）与焦点 pageIndex 都指向 committed/displayed 页。
        await drainDeferredPresentationTurns()
        XCTAssertEqual(surface.accessibilityDescription, "Page \(committed + 1) of \(surface.core.pageCount)")
        XCTAssertEqual(identity.pageIndex, committed, "焦点 pageIndex 与 committed 页一致（可访问性一致）")
        // ② 视觉焦点 = committed 页首个有效 cell（确定性目标）。
        let focusedCell = try XCTUnwrap(assembly.renderer.pageView(forPage: committed)?.cell(at: 0))
        XCTAssertEqual(focusedCell.isFocused, true, "视觉焦点落在 committed 页确定性目标")
        // ③ 启动对象 = 焦点身份解析的同一 cell（与视觉焦点同 appID），键盘路径启动该对象。
        XCTAssertEqual(identity.appID, focusedCell.bindingToken?.appID as? AppID,
                       "启动对象与视觉焦点 appID 一致")
        let outcome = adapter.activate(identity)
        XCTAssertEqual(outcome, .launched, "键盘路径经统一校验启动聚焦对象")
        XCTAssertEqual(launcher.opened, [apps[names[committed * 35]]!],
                       "Return 启动的是 committed 页首个可启动对象")
    }
}
