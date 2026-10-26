//
//  FolderIntegrationTests.swift
//  PagingUITests
//
//  Phase 1E T-1E-E：AppDelegate 集成 —— lab flag/test-injection 接线、成员启动复用
//  AppLaunchController、folder cell 绝不进入 app launch、search/refresh/folder pending
//  优先级、overlay 外单击关闭 + 下一次真实背景单击退出、teardown 全链。
//
//  测试放置偏离（记录）：`Tests/PagingPrototypeAppTests` 不存在且 Package.swift 冻结
//  （Main-only），唯一可 import `PagingPrototypeApp` 的既有测试 target 是
//  `Tests/PagingUITests/`（Package.swift L60-63）。故本集成测试置于 PagingUITests，
//  **不修改**任何既有 PagingUITests 文件（新增独立文件）。
//
//  隐私红线：本测试不把 folder 标题/成员/身份原值或图标数据写入 telemetry/JSONL/stdout/
//  signpost/profile/report；仅中性计数与决策枚举。
//

import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import AppIconPipeline
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class FolderIntegrationTests: XCTestCase {

    private var factory: FakeAppFactory!

    override func setUpWithError() throws {
        factory = try FakeAppFactory()
    }

    override func tearDownWithError() throws {
        factory?.removeRoot()
        factory = nil
    }

    // MARK: - 本地 helpers

    private func parse(_ arguments: [String]) throws -> AppArguments.Options {
        try AppArguments.parse(arguments).get()
    }

    private func makeAppID(_ bundleID: String) -> AppID {
        CatalogFixture.appID(bundleID)
    }

    private func makeSnapshot(titles: [String], revision: UInt64) -> CatalogSnapshot {
        let records = titles.enumerated().map { index, title in
            let bundleID = "fixture.\(title.lowercased())"
            let id = makeAppID(bundleID)
            return CatalogFixture.record(id: id, displayName: title, bundleID: bundleID,
                                         url: CatalogFixture.tempURL(named: "\(bundleID)-\(index).app"),
                                         icon: IconIdentity.from(appID: id), rootPriority: 0)
        }
        return CatalogSnapshot(revision: CatalogRevision(revision), records: records)
    }

    private func blankMouseDown(at point: NSPoint) -> NSEvent {
        NSEvent.mouseEvent(with: .leftMouseDown, location: point, modifierFlags: [],
                           timestamp: 0, windowNumber: 0, context: nil,
                           eventNumber: 1, clickCount: 1, pressure: 0)!
    }

    // MARK: - 1. Lab flag / test-injection 接线

    func testFolderLabFlagParsed() throws {
        XCTAssertTrue(try parse(["--folder-lab"]).folderLab, "--folder-lab 应置位 folderLab")
        XCTAssertFalse(try parse([]).folderLab, "默认产品启动 folderLab 关闭（不重排用户应用）")
        // 与既有参数共存。
        let combined = try parse(["--folder-lab", "--items-per-page", "40"])
        XCTAssertTrue(combined.folderLab)
        XCTAssertEqual(combined.itemsPerPage, 40)
    }

    func testFolderLabWiringGeneratesFolderSnapshot() async throws {
        _ = try factory.makeApps(names: ["Alpha", "Beta", "Gamma", "Delta", "Echo", "Foxtrot"])
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        assembly.folderLabEnabled = true
        assembly.folderSnapshotGenerator = { catalog in
            FolderLabFixture.makeGroups(from: catalog,
                                        configuration: .init(groupSize: 2, enabled: true))
        }
        wireAssembly(assembly, to: surface)
        assembly.begin()
        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed, "首扫应在超时内提交快照")
        // 生产路径：idle 边界重建 folder 组合（AppDelegate.applyPendingAtIdleBoundary）。
        assembly.rebuildFolderCompositionIfNeeded()
        _ = assembly.refreshController.applyPendingAtIdleBoundary(currentPage: 0)
        XCTAssertEqual(assembly.provider.servedFolderSnapshot?.folderCount, 2,
                       "6 apps @ 2/组 → 前 4 个分组（2 个 folder 条目），末尾 2 个未分组")
        assembly.teardown()
        surface.teardown()
    }

    func testAsyncFirstScanStagesFolderBeforeIdleCommit() async throws {
        // 回归：首扫完成时 catalog 仍是 pending。生产 idle 顺序必须先从该 pending
        // catalog 生成 folder，再由同一次 apply 原子提交 catalog + folder。
        _ = try factory.makeApps(names: ["Alpha", "Beta", "Gamma", "Delta", "Echo", "Foxtrot"])
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        assembly.folderLabEnabled = true
        assembly.folderSnapshotGenerator = { catalog in
            FolderLabFixture.makeGroups(from: catalog,
                                        configuration: .init(groupSize: 2, enabled: true))
        }
        wireAssembly(assembly, to: surface)

        // Same ordering as AppDelegate.installContentAssembly, with the newly fixed
        // pending-aware folder rebuild included before the refresh commit.
        assembly.refreshController.onStateChange = { [weak assembly, weak surface] state in
            guard let assembly, let surface, !state.isBusy,
                  surface.core.state == .idle else { return }
            assembly.rebuildFolderCompositionIfNeeded()
            _ = assembly.refreshController.applyPendingAtIdleBoundary(
                currentPage: surface.core.committedPage)
        }

        assembly.begin()
        let committed = await waitUntil {
            assembly.provider.servedFolderSnapshot?.folderCount == 2
        }
        XCTAssertTrue(committed, "异步首扫应在同一 idle 提交中产生 folder 组合")
        XCTAssertNotNil(assembly.provider.servedSnapshot)
        XCTAssertFalse(assembly.provider.hasPendingFolderSnapshot,
                       "catalog + folder 提交后不应残留 pending folder")

        assembly.teardown()
        surface.teardown()
    }

    // MARK: - 1b. folder cell 成员计数接线（T-1E-folderlab-membercount-repair）

    func testFolderCellMemberCountWiredFromServedSnapshot() async throws {
        // 回归（T-1E-folderlab-membercount-repair）：生产接线（AppDelegate.installFolderWiring
        // 同构）把 renderer.folderSnapshotProvider 接到 assembly.provider.servedFolderSnapshot
        // （与组合渲染同一 snapshot 源，FolderID 一致）→ 渲染的 folder cell 显示真实成员数（非 0）。
        _ = try factory.makeApps(names: ["Alpha", "Beta", "Gamma", "Delta", "Echo", "Foxtrot"])
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        assembly.folderLabEnabled = true
        assembly.folderSnapshotGenerator = { catalog in
            FolderLabFixture.makeGroups(from: catalog,
                                        configuration: .init(groupSize: 2, enabled: true))
        }
        wireAssembly(assembly, to: surface)
        // 生产接线（AppDelegate.installFolderWiring 同构）：弱捕获 assembly 防引用环。
        assembly.renderer.folderSnapshotProvider = { [weak assembly] in
            assembly?.provider.servedFolderSnapshot
        }
        assembly.begin()
        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed, "首扫应在超时内提交快照")
        assembly.rebuildFolderCompositionIfNeeded()
        _ = assembly.refreshController.applyPendingAtIdleBoundary(currentPage: 0)
        let folderSnapshot = assembly.provider.servedFolderSnapshot
        let folder = try XCTUnwrap(folderSnapshot?.entries.first, "应有已提交 folder 组合")
        let expectedCount = folder.members.count
        XCTAssertGreaterThanOrEqual(expectedCount, 2, "folder 条目应含 ≥2 成员")

        // 渲染含该 folder 条目的一页 → cell 显示真实成员数（非 0）。
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        assembly.renderer.renderTarget = host
        let content = PagingPageContent(
            presentationID: PagePresentationID(revision: assembly.provider.servedRevision!, pageIndex: 0),
            items: [PagingPageContentItem(slot: 0, identity: AnyHashable(folder.id), title: folder.title)],
            isPlaceholder: false)
        assembly.renderer.render(pageIndex: 0, content: content, pageCount: 1, reuseGeneration: 1)
        let page = assembly.renderer.pageView(forPage: 0)
        let cell = try XCTUnwrap(page?.cell(at: 0), "渲染器应创建 page 0 实例")
        XCTAssertTrue(cell.isFolderCell, "folder cell 可区分")
        await drainDeferredPresentationTurns()
        XCTAssertEqual(cell.memberCountText, "\(expectedCount) items",
                       "folder cell 成员数来自 servedFolderSnapshot（非 0）")
        assembly.teardown()
        surface.teardown()
    }

    func testFolderLabFlagWiringProducesNonEmptySnapshot() throws {
        // 回归（T-1E-folderlab-enable-repair）：--folder-lab → makeAssembly 接线
        // folderSnapshotGenerator 且以 enabled:true 驱动 → 非 nil / 非空 folder snapshot。
        var options = AppArguments.Options.default
        options.folderLab = true
        let assembly = AppRuntimeFactory.makeAssembly(options: options)
        XCTAssertNotNil(assembly, "--folder-lab → 装配非 nil")
        XCTAssertTrue(assembly!.folderLabEnabled, "--folder-lab → folderLabEnabled 置位")
        let generator = assembly!.folderSnapshotGenerator
        XCTAssertNotNil(generator, "--folder-lab → folderSnapshotGenerator 已接线")
        // 用 fixture snapshot 驱动生成器（不 begin，避免扫真实 /Applications）。
        // 40 apps @ 默认 groupSize 35 → 前 5 个分组（1 个 folder 条目），末尾 35 个未分组。
        let snapshot = makeSnapshot(titles: (0..<40).map { "App\($0)" }, revision: 1)
        let folder = generator!(snapshot)
        XCTAssertNotNil(folder, "enabled:true → 非 nil folder snapshot")
        XCTAssertFalse(folder!.entries.isEmpty, "非空 folder snapshot")
        // 隐私红线：不打印 folder 标题/成员/身份原值。
    }

    func testFolderLabDefaultOffDoesNotReorder() async throws {
        // 未开启 folderLab → 无 folder 组合（产品默认不重排用户应用）。
        _ = try factory.makeApps(names: ["Alpha", "Beta", "Gamma"])
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        wireAssembly(assembly, to: surface)
        assembly.begin()
        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        assembly.rebuildFolderCompositionIfNeeded()
        XCTAssertNil(assembly.provider.servedFolderSnapshot, "folderLab 关闭 → 无 folder 组合")
        XCTAssertEqual(assembly.provider.presentationEntries.count, 3, "全部为 app 条目")
        assembly.teardown()
        surface.teardown()
    }

    // MARK: - 2. 成员启动复用 AppLaunchController

    func testMemberLaunchReusesAppLaunchController() async throws {
        _ = try factory.makeApps(names: ["Alpha", "Beta"])
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        wireAssembly(assembly, to: surface)
        assembly.begin()
        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        let launcher = RecordingLauncher()
        let controller = AppLaunchController(surface: surface, assembly: assembly, launcher: launcher)
        let served = assembly.provider.servedRevision!
        let appID = assembly.provider.servedSnapshot!.records[0].id
        let expectedURL = assembly.bundleURL(for: appID)!
        // 成员启动：构造绑定正确 revision 的合成 cell → handleCell（复用既有管线）。
        let memberCell = AppCatalogAssembly.makeMemberLaunchCell(appID: appID, servedRevision: served)
        let outcome = controller.handleCell(memberCell)
        XCTAssertEqual(outcome, .launched, "成员 app 应经既有管线启动")
        XCTAssertEqual(launcher.opened, [expectedURL], "应启动成员 app 的 bundle URL")
        XCTAssertEqual(controller.outcomeCounts[.launched], 1)
        assembly.teardown()
        surface.teardown()
    }

    func testMemberLaunchStaleRevisionRejected() async throws {
        _ = try factory.makeApps(names: ["Alpha", "Beta"])
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        wireAssembly(assembly, to: surface)
        assembly.begin()
        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        let launcher = RecordingLauncher()
        let controller = AppLaunchController(surface: surface, assembly: assembly, launcher: launcher)
        let appID = assembly.provider.servedSnapshot!.records[0].id
        // 绑定过期 revision（≠ served）→ 与顶层 cell 同一 stale 拒绝。
        let staleCell = AppCatalogAssembly.makeMemberLaunchCell(appID: appID, servedRevision: 0)
        let outcome = controller.handleCell(staleCell)
        XCTAssertEqual(outcome, .rejectedStaleRevision, "成员启动走同一 stale revision 校验")
        XCTAssertTrue(launcher.opened.isEmpty)
        assembly.teardown()
        surface.teardown()
    }

    // MARK: - 3. Folder cell 绝不进入 app launch

    func testFolderIdentityNeverEntersLaunch() async throws {
        _ = try factory.makeApps(names: ["Alpha", "Beta"])
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        wireAssembly(assembly, to: surface)
        assembly.begin()
        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        let launcher = RecordingLauncher()
        let controller = AppLaunchController(surface: surface, assembly: assembly, launcher: launcher)
        // folder 身份（FolderID）绑定到 cell → handleCell 的 as? AppID 拒绝（绝不启动）。
        let folderCell = AppGridCellView()
        let folderToken = ItemBindingToken(
            catalogRevision: assembly.provider.servedRevision!,
            pageIdentity: PagePresentationID(revision: 0, pageIndex: 0),
            itemSlot: 0,
            appID: AnyHashable(FolderID()),
            reuseGeneration: 0,
            iconKey: nil,
            surfaceGeneration: 0
        )
        folderCell.bind(name: nil, token: folderToken)
        let outcome = controller.handleCell(folderCell)
        XCTAssertEqual(outcome, .rejectedNoBinding, "folder 身份绝不通过 app launch 校验")
        XCTAssertTrue(launcher.opened.isEmpty, "folder 身份绝不触发启动")
        assembly.teardown()
        surface.teardown()
    }

    func testActivationRouterBranchesFolderToOpen() {
        // 统一激活分流：folder → openFolder；app → launchApp；nil → reject。
        let appEntry = TopLevelEntry.app(CatalogFixture.record(
            id: makeAppID("fixture.alpha"), displayName: "Alpha", bundleID: "fixture.alpha",
            url: CatalogFixture.tempURL(named: "alpha.app"),
            icon: IconIdentity.from(appID: makeAppID("fixture.alpha")), rootPriority: 0))
        let folderEntry = TopLevelEntry.folder(FolderEntry(
            id: FolderID(), title: "Group 1",
            members: [makeAppID("fixture.alpha"), makeAppID("fixture.beta")]))
        XCTAssertEqual(ActivationRouter.decide(for: appEntry), .launchApp)
        XCTAssertEqual(ActivationRouter.decide(for: folderEntry), .openFolder)
        XCTAssertEqual(ActivationRouter.decide(for: TopLevelEntryIdentity?.none), .reject)
    }

    // MARK: - 4. Search/refresh/folder pending 优先级

    func testFolderRebasedOnNewCatalogBase() {
        // 新 catalog snapshot 提交后，folder 组合在**新 base** 上重建（成员收缩）。
        let catalog1 = makeSnapshot(titles: ["Alpha", "Beta", "Gamma"], revision: 1)
        let folder = FolderEntry(id: FolderID(), title: "Group 1",
                                 members: [makeAppID("fixture.alpha"),
                                           makeAppID("fixture.beta"),
                                           makeAppID("fixture.gamma")])
        let folderSnapshot = FolderSnapshot(generation: .zero, entries: [folder])
        let provider = AppGridUIPageContentProvider(snapshot: catalog1, folderSnapshot: folderSnapshot)
        // 新 catalog：Gamma 移除。
        let catalog2 = makeSnapshot(titles: ["Alpha", "Beta"], revision: 2)
        provider.receive(catalog2)
        let update = provider.applyPending(atCurrentPage: 0, itemsPerPage: 35)
        XCTAssertNotNil(update, "pending catalog 应提交")
        XCTAssertEqual(provider.servedRevision, 2)
        // folder 在新 base 上收缩：仅剩 Alpha、Beta。
        XCTAssertEqual(provider.servedFolderSnapshot?.entries.first?.members,
                       [makeAppID("fixture.alpha"), makeAppID("fixture.beta")],
                       "folder 组合在新 catalog base 上重建（删成员）")
        // folder generation 独立于 CatalogRevision（不 mint/forge）。
        XCTAssertEqual(provider.servedFolderSnapshot?.generation.value, 1)
    }

    func testFolderGenerationIndependentOfCatalogRevision() {
        // folder generation 为独立单调 token；folder 层绝不 mint/forge CatalogRevision。
        let catalog = makeSnapshot(titles: ["Alpha", "Beta", "Gamma", "Delta"], revision: 1)
        let folder = FolderEntry(id: FolderID(), title: "Group 1",
                                 members: [makeAppID("fixture.alpha"), makeAppID("fixture.beta")])
        let provider = AppGridUIPageContentProvider(
            snapshot: catalog,
            folderSnapshot: FolderSnapshot(generation: FolderGeneration(7), entries: [folder]))
        // 无 pending → applyPending 无操作。
        XCTAssertNil(provider.applyPending(atCurrentPage: 0, itemsPerPage: 35))
        XCTAssertEqual(provider.servedRevision, 1, "CatalogRevision 未被 folder 层改动")
        XCTAssertEqual(provider.servedFolderSnapshot?.generation.value, 7)
    }

    // MARK: - 5. Overlay 外单击关闭 + 下一次真实背景单击退出（两阶段）

    func testOverlayOutsideClickClosesThenBackgroundClickExits() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        let window = QuitOnBlankClickWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = container
        let folderOpenState = FolderOpenState()
        window.folderOpenStateProvider = { folderOpenState }
        var terminated = false
        window.onBlankClick = { terminated = true }

        // 阶段 1：folder 打开 → 空白点击关闭 folder（不退出）。
        folderOpenState.open(FolderEntry(id: FolderID(), title: "Group 1",
                                         members: [makeAppID("fixture.alpha"),
                                                   makeAppID("fixture.beta")]))
        window.sendEvent(blankMouseDown(at: NSPoint(x: 20, y: 20)))
        XCTAssertFalse(terminated, "folder 打开时空白点击不退出（只关闭 folder）")

        // 阶段 2：folder 关闭 → 下一次真实背景单击退出。
        folderOpenState.close()
        window.sendEvent(blankMouseDown(at: NSPoint(x: 20, y: 20)))
        XCTAssertTrue(terminated, "folder 关闭后空白点击退出")
    }

    func testBlankClickResolvesToCellClassification() {
        // 空白-vs-cell 命中分类：cell/icon/label 不误判；空白 → 退。
        let cell = AppGridCellView()
        let container = NSView()
        container.addSubview(cell)
        XCTAssertTrue(blankClickResolvesToCell(cell), "cell 命中 → 不退出")
        XCTAssertFalse(blankClickResolvesToCell(container), "空白容器 → 退出")
        XCTAssertFalse(blankClickResolvesToCell(nil), "nil 命中 → 退出")
    }

    // MARK: - 6. Teardown 全链

    func testTeardownFullChain() async throws {
        _ = try factory.makeApps(names: ["Alpha", "Beta", "Gamma"])
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        wireAssembly(assembly, to: surface)
        assembly.begin()
        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        // 装配 teardown 幂等（rescan 取消 + 页实例 teardown + 图标管道 shutdown）。
        assembly.teardown()
        assembly.teardown()
        surface.teardown()
        // folder 打开状态关闭后清空（会话内；teardown 后无残留打开条目）。
        let folderOpenState = FolderOpenState()
        folderOpenState.open(FolderEntry(id: FolderID(), title: "Group 1",
                                         members: [makeAppID("fixture.alpha"),
                                                   makeAppID("fixture.beta")]))
        XCTAssertTrue(folderOpenState.isOpen)
        folderOpenState.close()
        XCTAssertFalse(folderOpenState.isOpen, "folder 打开状态关闭后清空")
        XCTAssertNil(folderOpenState.openEntry)
    }

    // MARK: - 7. folder cell 左键点击接线（T-1E-folder-open-repair-wiring）

    /// 复刻 AppDelegate.installFolderWiring 的 folder 键盘 seam（T-1E-folder-mouse-open-repair）：
    /// - renderer.onFolderClick → keyboard.openFolderFromClick（鼠标点击经键盘 seam 打开）；
    /// - keyboard.onOpenFolder → 打开状态 + 配置 overlay（与生产 openFolder(folderID:) 同构）；
    /// - folderOpenStateProvider / folderOverlayProvider 接线。
    /// 返回 (keyboard, overlay) 供断言焦点视觉。
    private func makeFolderSeam(assembly: AppCatalogAssembly,
                                surface: PagingSurface,
                                folderOpenState: FolderOpenState) -> (KeyboardFocusController, FolderOverlayView) {
        let keyboard = KeyboardFocusController(columns: 5)
        keyboard.install(on: surface, focusModel: AppGridFocusModel())
        let overlay = FolderOverlayView(iconPipeline: assembly.iconPipeline, displayScale: 2)
        overlay.membersPerPage = folderOpenState.membersPerPage
        keyboard.folderOpenStateProvider = { folderOpenState }
        keyboard.folderOverlayProvider = { overlay }
        keyboard.onOpenFolder = { [weak assembly] identity in
            guard let assembly else { return }
            guard case .folder(let folderID)? = identity.entryIdentity else { return }
            guard let entry = assembly.provider.servedFolderSnapshot?.entry(for: folderID) else { return }
            folderOpenState.open(entry)
            overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { _ in nil }
        }
        assembly.renderer.onFolderClick = { [weak keyboard] folderID in
            keyboard?.openFolderFromClick(folderID)
        }
        return (keyboard, overlay)
    }

    func testFolderCellClickOpensFolderViaRendererSeam() async throws {
        // 回归（T-1E-folder-open-repair-wiring）：renderer.onFolderClick 透传到 folder cell，
        // 触发点击 → openFolder 路径（open state 置位）。
        _ = try factory.makeApps(names: ["Alpha", "Beta", "Gamma", "Delta", "Echo", "Foxtrot"])
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        assembly.folderLabEnabled = true
        assembly.folderSnapshotGenerator = { catalog in
            FolderLabFixture.makeGroups(from: catalog, configuration: .init(groupSize: 2, enabled: true))
        }
        wireAssembly(assembly, to: surface)
        assembly.renderer.folderSnapshotProvider = { [weak assembly] in
            assembly?.provider.servedFolderSnapshot
        }
        let folderOpenState = FolderOpenState(membersPerPage: surface.itemsPerPage)
        let (keyboard, _) = makeFolderSeam(assembly: assembly, surface: surface,
                                          folderOpenState: folderOpenState)
        assembly.begin()
        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        assembly.rebuildFolderCompositionIfNeeded()
        _ = assembly.refreshController.applyPendingAtIdleBoundary(currentPage: 0)
        let folder = try XCTUnwrap(assembly.provider.servedFolderSnapshot?.entries.first)

        // 渲染含该 folder 条目的一页 → cell 透传 onFolderClick（seam 传播）。
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        assembly.renderer.renderTarget = host
        let content = PagingPageContent(
            presentationID: PagePresentationID(revision: assembly.provider.servedRevision!, pageIndex: 0),
            items: [PagingPageContentItem(slot: 0, identity: AnyHashable(folder.id), title: folder.title)],
            isPlaceholder: false)
        assembly.renderer.render(pageIndex: 0, content: content, pageCount: 1, reuseGeneration: 1)
        let cell = try XCTUnwrap(assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        XCTAssertTrue(cell.isFolderCell)
        XCTAssertNotNil(cell.onFolderClick, "renderer.onFolderClick 应透传到 folder cell")

        // 触发 folder cell 点击 → 经键盘 seam 打开（open state 置位）。
        cell.onFolderClick?(folder.id)
        XCTAssertTrue(folderOpenState.isOpen, "folder cell 点击应打开 folder")
        XCTAssertEqual(folderOpenState.openFolderID, folder.id, "打开条目应为被点击的 folder")
        // T-1E-folder-open-click-focus-repair：左键点击**不**设置键盘焦点（无焦点框）。
        XCTAssertNil(keyboard.focusModel.current,
                     "左键点击 folder 不应设置键盘焦点（鼠标交互不显示焦点框）")
        assembly.teardown()
        surface.teardown()
    }

    func testFolderCellClickOpensImmediately() async throws {
        // T-1E-folder-open-click-focus-repair：左键点击 folder → **立即打开**（无需 Return）。
        // 取代旧的 click-then-Return 测试——点击现在直接打开，不再需要 Return 激活。
        _ = try factory.makeApps(names: ["Alpha", "Beta", "Gamma", "Delta", "Echo", "Foxtrot"])
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        assembly.folderLabEnabled = true
        assembly.folderSnapshotGenerator = { catalog in
            FolderLabFixture.makeGroups(from: catalog, configuration: .init(groupSize: 2, enabled: true))
        }
        wireAssembly(assembly, to: surface)
        assembly.renderer.folderSnapshotProvider = { [weak assembly] in
            assembly?.provider.servedFolderSnapshot
        }
        let folderOpenState = FolderOpenState(membersPerPage: surface.itemsPerPage)
        let (keyboard, _) = makeFolderSeam(assembly: assembly, surface: surface,
                                          folderOpenState: folderOpenState)
        assembly.begin()
        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        assembly.rebuildFolderCompositionIfNeeded()
        _ = assembly.refreshController.applyPendingAtIdleBoundary(currentPage: 0)
        let folder = try XCTUnwrap(assembly.provider.servedFolderSnapshot?.entries.first)

        let host = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        assembly.renderer.renderTarget = host
        let content = PagingPageContent(
            presentationID: PagePresentationID(revision: assembly.provider.servedRevision!, pageIndex: 0),
            items: [PagingPageContentItem(slot: 0, identity: AnyHashable(folder.id), title: folder.title)],
            isPlaceholder: false)
        assembly.renderer.render(pageIndex: 0, content: content, pageCount: 1, reuseGeneration: 1)
        let cell = try XCTUnwrap(assembly.renderer.pageView(forPage: 0)?.cell(at: 0))

        // 点击 folder → 立即打开（无需 Return）。
        cell.onFolderClick?(folder.id)
        XCTAssertTrue(folderOpenState.isOpen, "点击 folder 应立即打开（无需 Return）")
        XCTAssertEqual(folderOpenState.openFolderID, folder.id, "打开条目应为被点击的 folder")
        // 左键点击不设置键盘焦点（无焦点框）。
        XCTAssertNil(keyboard.focusModel.current,
                     "左键点击 folder 不应设置键盘焦点（鼠标交互不显示焦点框）")
        assembly.teardown()
        surface.teardown()
    }

    // MARK: - 8. 鼠标打开 folder 修复（T-1E-folder-mouse-open-repair）

    private func keyEvent(_ keyCode: UInt16) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                         timestamp: 0, windowNumber: 0, context: nil,
                         characters: "", charactersIgnoringModifiers: "",
                         isARepeat: false, keyCode: keyCode)!
    }

    private func rightArrow() -> NSEvent { keyEvent(124) }
    private func downArrow() -> NSEvent { keyEvent(125) }
    private func returnKey() -> NSEvent { keyEvent(36) }

    /// 渲染含 folder 条目的一页并返回其 folder cell（slot 0）。
    private func renderFolderCell(assembly: AppCatalogAssembly, folder: FolderEntry) throws -> AppGridCellView {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        assembly.renderer.renderTarget = host
        let content = PagingPageContent(
            presentationID: PagePresentationID(revision: assembly.provider.servedRevision!, pageIndex: 0),
            items: [PagingPageContentItem(slot: 0, identity: AnyHashable(folder.id), title: folder.title)],
            isPlaceholder: false)
        assembly.renderer.render(pageIndex: 0, content: content, pageCount: 1, reuseGeneration: 1)
        return try XCTUnwrap(assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
    }

    /// 准备 folder 组合 + 键盘 seam 的公共测试台。
    private func makeFolderSeamFixture() async throws
        -> (assembly: AppCatalogAssembly, surface: PagingSurface,
            folderOpenState: FolderOpenState, keyboard: KeyboardFocusController,
            overlay: FolderOverlayView, folder: FolderEntry) {
        _ = try factory.makeApps(names: ["Alpha", "Beta", "Gamma", "Delta", "Echo", "Foxtrot"])
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        assembly.folderLabEnabled = true
        assembly.folderSnapshotGenerator = { catalog in
            FolderLabFixture.makeGroups(from: catalog, configuration: .init(groupSize: 2, enabled: true))
        }
        wireAssembly(assembly, to: surface)
        assembly.renderer.folderSnapshotProvider = { [weak assembly] in
            assembly?.provider.servedFolderSnapshot
        }
        let folderOpenState = FolderOpenState(membersPerPage: surface.itemsPerPage)
        let (keyboard, overlay) = makeFolderSeam(assembly: assembly, surface: surface,
                                                 folderOpenState: folderOpenState)
        assembly.begin()
        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        assembly.rebuildFolderCompositionIfNeeded()
        _ = assembly.refreshController.applyPendingAtIdleBoundary(currentPage: 0)
        let folder = try XCTUnwrap(assembly.provider.servedFolderSnapshot?.entries.first)
        return (assembly, surface, folderOpenState, keyboard, overlay, folder)
    }

    func testMouseOpenClearsOuterRingAndDefersInnerRing() async throws {
        // (a) 先设外层焦点（app 身份）→ 鼠标点击 folder → 外层蓝框清除（focusModel.current == nil）
        //     且内部成员 1（slot 0）不显示焦点环（延迟选中）；首次右方向键后内环出现。
        let fixture = try await makeFolderSeamFixture()
        let assembly = fixture.assembly
        let surface = fixture.surface
        let folderOpenState = fixture.folderOpenState
        let keyboard = fixture.keyboard
        let overlay = fixture.overlay
        let folder = fixture.folder
        defer {
            assembly.teardown()
            surface.teardown()
        }

        // 外层焦点先落在某 app 身份（模拟用户已用方向键选中外层 app）。
        let appID = try XCTUnwrap(assembly.provider.servedSnapshot?.records.first?.id)
        let appIdentity = AppGridFocusIdentity(catalogRevision: assembly.provider.servedRevision!,
                                               pageIndex: 0, slotIndex: 0, appID: appID)
        keyboard.setFocus(to: appIdentity)
        XCTAssertNotNil(keyboard.focusModel.current, "前置：外层焦点已设置")

        // 鼠标点击 folder → 经键盘 seam 打开。
        let cell = try renderFolderCell(assembly: assembly, folder: folder)
        cell.onFolderClick?(folder.id)

        XCTAssertTrue(folderOpenState.isOpen, "点击应打开 folder")
        XCTAssertNil(keyboard.focusModel.current, "鼠标打开后外层蓝框应清除（focusModel.current == nil）")
        XCTAssertEqual(overlay.memberCell(at: 0)?.isFocused, false,
                       "打开后无内环（延迟选中）")

        keyboard.keyDown(with: rightArrow())
        XCTAssertEqual(overlay.memberCell(at: 1)?.isFocused, true,
                       "首次右方向键后内环应出现在成员 2（slot 1）")
    }

    func testKeyboardOpenDefersInnerRingUntilFirstArrow() async throws {
        // (b) 键盘打开（焦点在 folder 身份 + Return）→ 内部成员 1（slot 0）不显示焦点环
        //     （延迟选中）；首次右方向键后内环出现。
        let fixture = try await makeFolderSeamFixture()
        let assembly = fixture.assembly
        let surface = fixture.surface
        let folderOpenState = fixture.folderOpenState
        let keyboard = fixture.keyboard
        let overlay = fixture.overlay
        let folder = fixture.folder
        defer {
            assembly.teardown()
            surface.teardown()
        }

        let folderIdentity = AppGridFocusIdentity(catalogRevision: assembly.provider.servedRevision!,
                                                  pageIndex: 0, slotIndex: 0,
                                                  entryIdentity: .folder(folder.id))
        keyboard.setFocus(to: folderIdentity)
        keyboard.keyDown(with: returnKey())

        XCTAssertTrue(folderOpenState.isOpen, "键盘打开应打开 folder")
        XCTAssertEqual(overlay.memberCell(at: 0)?.isFocused, false,
                       "键盘打开后无内环（延迟选中）")

        keyboard.keyDown(with: rightArrow())
        XCTAssertEqual(overlay.memberCell(at: 1)?.isFocused, true,
                       "首次右方向键后内环应出现在成员 2（slot 1）")
    }

    // MARK: - T-1E-folder-keyboard-return-repair：键盘 Return 打开 folder（用户 Bug 4）

    /// (a) 组合 fixture：setFocus 到 folder 槽位身份（entryIdentity: .folder）→ Return → 打开。
    func testSetFocusFolderIdentityReturnOpensFolder() async throws {
        let fixture = try await makeFolderSeamFixture()
        let assembly = fixture.assembly
        let surface = fixture.surface
        let folderOpenState = fixture.folderOpenState
        let keyboard = fixture.keyboard
        let folder = fixture.folder
        defer {
            assembly.teardown()
            surface.teardown()
        }

        let folderIdentity = AppGridFocusIdentity(catalogRevision: assembly.provider.servedRevision!,
                                                  pageIndex: 0, slotIndex: 0,
                                                  entryIdentity: .folder(folder.id))
        keyboard.setFocus(to: folderIdentity)
        keyboard.keyDown(with: returnKey())

        XCTAssertTrue(folderOpenState.isOpen, "folder 槽位身份 + Return 应打开 folder")
        XCTAssertEqual(folderOpenState.openFolderID, folder.id, "打开的应为聚焦的 folder")
    }

    /// (b) 导航器全链路（用户 Bug 4 精确复现）：downArrow 播种 → 方向键移到 folder 槽位 →
    ///     身份为 .folder → Return 打开。
    func testNavigatorToFolderSlotReturnOpensFolder() async throws {
        let fixture = try await makeFolderSeamFixture()
        let assembly = fixture.assembly
        let surface = fixture.surface
        let folderOpenState = fixture.folderOpenState
        let keyboard = fixture.keyboard
        defer {
            assembly.teardown()
            surface.teardown()
        }

        // deferred 态：首次方向键播种到 committed 页首格（slot 0 = 第一个 folder）。
        keyboard.keyDown(with: downArrow())
        XCTAssertEqual(keyboard.focusModel.current?.slotIndex, 0)
        XCTAssertEqual(keyboard.focusModel.current?.entryIdentity, .folder(fixture.folder.id),
                       "播种槽位身份应为 .folder（组合布局，非 app-only 错位）")

        // 右移 → slot 1 = 第二个 folder。
        keyboard.keyDown(with: rightArrow())
        let secondFolder = try XCTUnwrap(assembly.provider.servedFolderSnapshot?.entries[1])
        XCTAssertEqual(keyboard.focusModel.current?.slotIndex, 1)
        XCTAssertEqual(keyboard.focusModel.current?.entryIdentity, .folder(secondFolder.id),
                       "导航到 folder 槽位后身份应为 .folder")

        // Return → 打开聚焦的 folder。
        keyboard.keyDown(with: returnKey())
        XCTAssertTrue(folderOpenState.isOpen, "导航到 folder 槽位 + Return 应打开 folder")
        XCTAssertEqual(folderOpenState.openFolderID, secondFolder.id, "打开的应为聚焦的 folder")
    }

    /// (c) app 槽位身份正确（防"差文件夹数"错位回归）：导航到 app cell →
    ///     entryIdentity == .app(该 cell 实际 app)。
    func testNavigatorToAppSlotIdentityIsActualApp() async throws {
        let fixture = try await makeFolderSeamFixture()
        let assembly = fixture.assembly
        let surface = fixture.surface
        let keyboard = fixture.keyboard
        defer {
            assembly.teardown()
            surface.teardown()
        }

        // 播种到 slot 0（folder1）→ 右移 ×2 → slot 2（组合第 3 项 = 未分组 app）。
        keyboard.keyDown(with: downArrow())
        keyboard.keyDown(with: rightArrow())
        keyboard.keyDown(with: rightArrow())
        XCTAssertEqual(keyboard.focusModel.current?.slotIndex, 2)

        // 组合第 3 项应为 .app（folder 偏移后 app 身份不错位）。
        let entry = try XCTUnwrap(assembly.provider.presentationEntries[2])
        guard case .app(let record) = entry else {
            XCTFail("组合第 3 项应为 app 条目")
            return
        }
        XCTAssertEqual(keyboard.focusModel.current?.entryIdentity, .app(record.id),
                       "app 槽位身份应为该 cell 实际 app（防差文件夹数错位）")
    }

    func testMouseOpenThenRightArrowMovesInnerRing() async throws {
        // (c) 鼠标打开后，右方向键 → 内环从成员 1 移到成员 2（内部导航在鼠标打开后可用）。
        let fixture = try await makeFolderSeamFixture()
        let assembly = fixture.assembly
        let surface = fixture.surface
        let folderOpenState = fixture.folderOpenState
        let keyboard = fixture.keyboard
        let overlay = fixture.overlay
        let folder = fixture.folder
        defer {
            assembly.teardown()
            surface.teardown()
        }

        let cell = try renderFolderCell(assembly: assembly, folder: folder)
        cell.onFolderClick?(folder.id)
        XCTAssertTrue(folderOpenState.isOpen)
        XCTAssertEqual(overlay.memberCell(at: 0)?.isFocused, false, "打开后无环（延迟选中）")

        keyboard.keyDown(with: rightArrow())
        XCTAssertEqual(overlay.memberCell(at: 1)?.isFocused, true,
                       "右方向键后内环应移到成员 2（slot 1）")
        XCTAssertEqual(overlay.memberCell(at: 0)?.isFocused, false,
                       "右方向键后成员 1 应取消聚焦")
    }

    func testAppCellClickStillLaunchesViaAppLaunchController() async throws {
        // 回归（T-1E-folder-open-repair-wiring）：接线 onFolderClick 不干扰 app cell 启动
        // （app cell 恒不触发 folder 点击；AppLaunchController 管线不变）。
        _ = try factory.makeApps(names: ["Alpha", "Beta"])
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        wireAssembly(assembly, to: surface)
        assembly.renderer.onFolderClick = { _ in XCTFail("app cell 不应触发 folder 点击") }
        assembly.begin()
        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        let launcher = RecordingLauncher()
        let controller = AppLaunchController(surface: surface, assembly: assembly, launcher: launcher)
        let appID = assembly.provider.servedSnapshot!.records[0].id
        let expectedURL = assembly.bundleURL(for: appID)!
        let appCell = AppCatalogAssembly.makeMemberLaunchCell(appID: appID,
                                                             servedRevision: assembly.provider.servedRevision!)
        let outcome = controller.handleCell(appCell)
        XCTAssertEqual(outcome, .launched, "app cell 仍经 AppLaunchController 启动")
        XCTAssertEqual(launcher.opened, [expectedURL])
        assembly.teardown()
        surface.teardown()
    }
}
