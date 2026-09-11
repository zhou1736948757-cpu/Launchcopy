// PagingUITests — DragUIIntegrationTests（T-1F-D1 集成测试）
// seam 驱动（参照 FolderIntegrationTests 模式）：复刻 AppDelegate.installDragUI 的
// coordinator 装配（布局/几何/翻页/click 派发/抑制/drag 门），验证：
// 1) app click 仍启动 / drag app 绝不启动
// 2) folder click 仍打开 / drag folder 绝不打开
// 3) 空白点击两段式不变（overlay 空白单击关闭 folder；空白 drag 不关闭）
// 4) 搜索 active 禁拖；Command-F 先 cancel 再搜索
// 5) 标题编辑禁拖
// 6) folder 内 drag 不动外层页
// 7) 跨页 drop 更新可见内容与焦点（seam 层验证）
// 8) source/target cell 复用零 stale apply
// 9) teardown 零 gesture/session/timer/store callback
// 10) Reduce Motion 分支
// 隐私：仅中性 fixture 数据（fixture.alpha/beta、'Group 1'、固定 UUID）；
// 不把标题/成员/身份原值写入 telemetry/JSONL/stdout/report。

import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import AppIconPipeline
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class DragUIIntegrationTests: XCTestCase {

    /// fixture app 持久引用（bundleID = "fixture." + 小写标题；与 FakeAppFactory 同源）。
    private func ref(_ title: String) -> PersistentAppReference {
        PersistentAppReference.bundleID("fixture.\(title.lowercased())")
    }

    private var factory: FakeAppFactory!

    override func setUpWithError() throws {
        factory = try FakeAppFactory()
    }

    override func tearDownWithError() throws {
        factory?.removeRoot()
        factory = nil
    }

    // MARK: - fixture（复刻 AppDelegate.installDragUI 装配）

    @MainActor
    private final class DragUIFixture {
        let assembly: AppCatalogAssembly
        let surface: PagingSurface
        let folderOpenState: FolderOpenState
        let keyboard: KeyboardFocusController
        let overlay: FolderOverlayView
        let folder: FolderEntry?
        let launch: AppLaunchController
        let launcher: RecordingLauncher
        let coordinator: DragUISessionCoordinator
        var sessionLayout: PersistentWorkspaceLayout?
        var searchActive = false
        var titleEditing = false
        var blankClicks = 0
        var commits: [PersistentWorkspaceLayout] = []
        var clicks: [AppGridCellView] = []
        var suppression: [Bool] = []
        var topLevelTurns: [(KeyboardPageDirection, TimeInterval)] = []
        var folderTurns: [Int] = []

        init(assembly: AppCatalogAssembly, surface: PagingSurface,
             folderOpenState: FolderOpenState, keyboard: KeyboardFocusController,
             overlay: FolderOverlayView, folder: FolderEntry?,
             launch: AppLaunchController, launcher: RecordingLauncher,
             coordinator: DragUISessionCoordinator) {
            self.assembly = assembly
            self.surface = surface
            self.folderOpenState = folderOpenState
            self.keyboard = keyboard
            self.overlay = overlay
            self.folder = folder
            self.launch = launch
            self.launcher = launcher
            self.coordinator = coordinator
        }

        // MARK: seams（与 AppDelegate 同构）

        func makeDragGeometry(scope: DragScope) -> DragGeometry? {
            let catalog = assembly.provider.servedSnapshot
            switch scope {
            case .topLevel:
                let page = surface.core.committedPage
                guard let pageView = assembly.renderer.pageView(forPage: page) else { return nil }
                let frames = pageView.dragItemFrames(convertedTo: surface, catalog: catalog)
                return DragGeometry(itemFrames: frames,
                                    containerWidth: Double(surface.bounds.width),
                                    page: page, pageCount: surface.core.pageCount)
            case .folder(let folderID):
                guard folderOpenState.isOpen(folderID) else { return nil }
                let memberFrames = overlay.memberDragItemFrames(convertedTo: surface, catalog: catalog)
                let page = folderOpenState.innerPage
                let pageCount = folderOpenState.innerPageCount
                let topLevelFrames: [DragItemFrame]
                if let pageView = assembly.renderer.pageView(forPage: surface.core.committedPage) {
                    topLevelFrames = pageView.dragItemFrames(convertedTo: surface, catalog: catalog)
                } else {
                    topLevelFrames = memberFrames
                }
                return DragGeometry(itemFrames: memberFrames, topLevelFrames: topLevelFrames,
                                    containerWidth: Double(surface.bounds.width),
                                    page: page, pageCount: pageCount)
            }
        }

        /// click 派发（与 AppDelegate.handleDragCellClick 同构）。
        func handleCellClick(_ cell: AppGridCellView) {
            clicks.append(cell)
            if cell.isFolderCell {
                if let folderID = cell.bindingToken?.appID as? FolderID {
                    openFolder(folderID)
                }
                return
            }
            if let appID = cell.bindingToken?.appID as? AppID {
                if folderOpenState.isOpen {
                    launchMember(appID)
                } else {
                    _ = launch.handleCell(cell)
                }
            }
        }

        func openFolder(_ folderID: FolderID) {
            guard let entry = assembly.provider.servedFolderSnapshot?.entry(for: folderID) else { return }
            folderOpenState.open(entry)
            overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { [weak self] appID in
                self?.memberName(for: appID)
            }
            if overlay.superview == nil {
                surface.addSubview(overlay)
                overlay.frame = surface.bounds
                overlay.autoresizingMask = [.width, .height]
            }
            overlay.layout()
        }

        func closeFolder() {
            folderOpenState.close()
            overlay.clearContent()
            overlay.removeFromSuperview()
        }

        func launchMember(_ appID: AppID) {
            guard let served = assembly.provider.servedRevision else { return }
            let cell = AppCatalogAssembly.makeMemberLaunchCell(appID: appID, servedRevision: served)
            _ = launch.handleCell(cell)
        }

        func memberName(for appID: AppID) -> String? {
            assembly.provider.servedSnapshot?.records.first { $0.id == appID }?.displayName
        }

        /// Command-F 接线（与 AppDelegate.onSearchShortcut 同构：先 cancel 再搜索）。
        func simulateCommandF() {
            coordinator.cancel(reason: .searchActivated)
            searchActive = true
        }

        /// 当前页某 slot 的 cell 中心（surface 坐标系）。
        func cellCenter(slot: Int) -> NSPoint? {
            guard let pageView = assembly.renderer.pageView(forPage: surface.core.committedPage),
                  let cell = pageView.cell(at: slot) else { return nil }
            let rect = cell.convert(cell.bounds, to: surface)
            return NSPoint(x: rect.midX, y: rect.midY)
        }
    }

    private func makeFixture(appNames: [String] = ["Alpha", "Beta", "Gamma", "Delta", "Echo", "Foxtrot"],
                             folderLab: Bool = true) async throws -> DragUIFixture {
        _ = try factory.makeApps(names: appNames)
        let surface = makeSurface(pageCount: 3, itemsPerPage: 35)
        let assembly = AppCatalogAssembly(roots: [factory.root], loader: RecordingIconLoader())
        assembly.folderLabEnabled = folderLab
        assembly.folderSnapshotGenerator = { catalog in
            FolderLabFixture.makeGroups(from: catalog, configuration: .init(groupSize: 2, enabled: folderLab))
        }
        wireAssembly(assembly, to: surface)
        assembly.renderer.folderSnapshotProvider = { [weak assembly] in
            assembly?.provider.servedFolderSnapshot
        }
        let folderOpenState = FolderOpenState(membersPerPage: surface.itemsPerPage)
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
        let launcher = RecordingLauncher()
        let launch = AppLaunchController(surface: surface, assembly: assembly, launcher: launcher)
        launch.install()
        assembly.begin()
        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        assembly.rebuildFolderCompositionIfNeeded()
        _ = assembly.refreshController.applyPendingAtIdleBoundary(currentPage: 0)
        let folder = assembly.provider.servedFolderSnapshot?.entries.first

        let coordinator = DragUISessionCoordinator(host: surface)
        let fixture = DragUIFixture(assembly: assembly, surface: surface,
                                   folderOpenState: folderOpenState, keyboard: keyboard,
                                   overlay: overlay, folder: folder,
                                   launch: launch, launcher: launcher, coordinator: coordinator)
        coordinator.layoutProvider = { [weak fixture] in
            guard let fixture else { return nil }
            if let sessionLayout = fixture.sessionLayout { return sessionLayout }
            return DragUISessionLayoutFactory.makeSessionLayout(
                catalog: fixture.assembly.provider.servedSnapshot,
                entries: fixture.assembly.provider.presentationEntries,
                folderSnapshot: fixture.assembly.provider.servedFolderSnapshot)
        }
        coordinator.catalogGenerationProvider = { [weak fixture] in
            fixture?.assembly.provider.servedRevision ?? 0
        }
        coordinator.catalogSnapshotProvider = { [weak fixture] in
            fixture?.assembly.provider.servedSnapshot
        }
        coordinator.geometryProvider = { [weak fixture] scope in
            fixture?.makeDragGeometry(scope: scope)
        }
        coordinator.onCommit = { [weak fixture] newLayout in
            guard let fixture else { return }
            fixture.sessionLayout = newLayout
            fixture.commits.append(newLayout)
        }
        coordinator.onCellClick = { [weak fixture] cell in
            fixture?.handleCellClick(cell)
        }
        coordinator.onOverlayBlankClick = { [weak fixture] in
            guard let fixture else { return }
            fixture.blankClicks += 1
            fixture.closeFolder()
        }
        coordinator.topLevelPageTurn = { [weak fixture] direction, timestamp in
            guard let fixture else { return .deferred }
            fixture.topLevelTurns.append((direction, timestamp))
            return KeyboardPageTurner(surface: fixture.surface).turn(direction: direction, timestamp: timestamp)
        }
        coordinator.folderPageTurn = { [weak fixture] delta in
            guard let fixture else { return }
            fixture.folderTurns.append(delta)
            if delta < 0 { fixture.overlay.prevPage() } else { fixture.overlay.nextPage() }
        }
        coordinator.clickRecognitionSuppressor = { [weak surface, weak fixture] enabled in
            fixture?.suppression.append(enabled)
            guard let surface else { return }
            for recognizer in surface.gestureRecognizers where recognizer is NSClickGestureRecognizer {
                recognizer.isEnabled = enabled
            }
        }
        coordinator.dragGate = { [weak fixture] in
            guard let fixture else { return false }
            return !fixture.searchActive && !fixture.titleEditing
        }
        return fixture
    }

    // MARK: - 1) app click 仍启动 / drag app 绝不启动

    func testAppClickStillLaunchesAndDragNeverLaunches() async throws {
        let fixture = try await makeFixture()
        defer {
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        // 组合：folder, folder, Foxtrot, Gamma（slot 2 = Foxtrot app cell；catalog 按 bundle ID
        // 排序 → 分组 [alpha,beta]/[delta,echo]，未分组 [foxtrot,gamma]）。
        let center = try XCTUnwrap(fixture.cellCenter(slot: 2))
        let foxtrotCell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 2))
        XCTAssertFalse(foxtrotCell.isFolderCell)

        // click：mouse-up 未过阈值 → 经 coordinator 派发 → AppLaunchController 管线。
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: foxtrotCell, memberFolderID: nil)
        fixture.coordinator.pointerUp(locationInWindow: center)
        XCTAssertEqual(fixture.launcher.opened.count, 1, "app click 仍启动")
        XCTAssertEqual(fixture.launch.outcomeCounts[.launched], 1)
        XCTAssertEqual(fixture.clicks.count, 1)

        // drag：过阈值 → 绝不启动；合法 drop → commit seam。
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: foxtrotCell, memberFolderID: nil)
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: center.x + 30, y: center.y))
        XCTAssertEqual(fixture.coordinator.controller.state, .dragging)
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: 520, y: center.y))
        fixture.coordinator.pointerUp(locationInWindow: NSPoint(x: 520, y: center.y))
        XCTAssertEqual(fixture.launcher.opened.count, 1, "drag 绝不启动")
        XCTAssertEqual(fixture.commits.count, 1, "合法 drop → commit seam 一次")
        XCTAssertEqual(fixture.clicks.count, 1, "drag 不派发 click")
        let folder1 = try XCTUnwrap(fixture.folder)
        let folder2 = try XCTUnwrap(fixture.assembly.provider.servedFolderSnapshot?.entries[1])
        XCTAssertEqual(fixture.commits[0].topLevelOrder,
                       [.folder(folder1.id), .folder(folder2.id),
                        .app(ref("gamma")), .app(ref("foxtrot"))],
                       "顶层重排：Foxtrot 移到末位")
    }

    // MARK: - 2) folder click 仍打开 / drag folder 绝不打开

    func testFolderClickStillOpensAndDragFolderNeverOpens() async throws {
        let fixture = try await makeFixture()
        defer {
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let folder = try XCTUnwrap(fixture.folder)
        let center = try XCTUnwrap(fixture.cellCenter(slot: 0))
        let folderCell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        XCTAssertTrue(folderCell.isFolderCell)

        // click → 打开（复用键盘 seam；不设置键盘焦点）。
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: folderCell, memberFolderID: nil)
        fixture.coordinator.pointerUp(locationInWindow: center)
        XCTAssertTrue(fixture.folderOpenState.isOpen, "folder click 仍打开")
        XCTAssertEqual(fixture.folderOpenState.openFolderID, folder.id)
        XCTAssertNil(fixture.keyboard.focusModel.current, "鼠标打开不设置键盘焦点")
        fixture.closeFolder()

        // drag folder → 绝不打开；合法 drop → commit（顶层重排）。
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: folderCell, memberFolderID: nil)
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: center.x + 30, y: center.y))
        XCTAssertEqual(fixture.coordinator.controller.state, .dragging)
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: 520, y: center.y))
        fixture.coordinator.pointerUp(locationInWindow: NSPoint(x: 520, y: center.y))
        XCTAssertFalse(fixture.folderOpenState.isOpen, "drag folder 绝不打开")
        XCTAssertEqual(fixture.commits.count, 1, "folder 顶层重排 commit")
    }

    // MARK: - 3) 空白点击两段式不变

    func testBlankClickTwoStageUnchanged() async throws {
        let fixture = try await makeFixture()
        defer {
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let folder = try XCTUnwrap(fixture.folder)
        fixture.openFolder(folder.id)
        XCTAssertTrue(fixture.folderOpenState.isOpen)

        // 空白单击（未过阈值）→ 关闭 folder（两段式第一段；不退出）。
        fixture.coordinator.pointerDown(locationInWindow: NSPoint(x: 900, y: 650), sourceCell: nil, memberFolderID: nil)
        fixture.coordinator.pointerUp(locationInWindow: NSPoint(x: 900, y: 650))
        XCTAssertEqual(fixture.blankClicks, 1, "空白单击 → onOverlayBlankClick（关闭 folder）")
        XCTAssertFalse(fixture.folderOpenState.isOpen, "空白单击关闭 folder")

        // 空白 drag（过阈值）→ 不关闭。
        fixture.openFolder(folder.id)
        fixture.coordinator.pointerDown(locationInWindow: NSPoint(x: 900, y: 650), sourceCell: nil, memberFolderID: nil)
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: 920, y: 650))
        fixture.coordinator.pointerUp(locationInWindow: NSPoint(x: 920, y: 650))
        XCTAssertEqual(fixture.blankClicks, 1, "空白 drag 不触发关闭")
        XCTAssertTrue(fixture.folderOpenState.isOpen, "空白 drag 后 folder 保持打开")
    }

    // MARK: - 4) 搜索 active 禁拖；Command-F 先 cancel 再搜索

    func testSearchActiveDisablesDragAndCommandFCancelsFirst() async throws {
        let fixture = try await makeFixture()
        defer {
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let center = try XCTUnwrap(fixture.cellCenter(slot: 2))
        let echoCell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 2))

        // 搜索激活 → 禁拖（不进入仲裁；点击仍走既有识别器路径）。
        fixture.searchActive = true
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: echoCell, memberFolderID: nil)
        XCTAssertEqual(fixture.coordinator.controller.state, .idle, "搜索 active → 禁拖")
        XCTAssertFalse(fixture.coordinator.isSessionActive)
        fixture.coordinator.pointerUp(locationInWindow: center)
        XCTAssertEqual(fixture.clicks.count, 0, "禁拖期间 coordinator 不派发 click")

        // 搜索退出 → 拖拽恢复。
        fixture.searchActive = false
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: echoCell, memberFolderID: nil)
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: center.x + 30, y: center.y))
        XCTAssertEqual(fixture.coordinator.controller.state, .dragging, "搜索退出 → 拖拽恢复")
        fixture.coordinator.cancel(reason: .searchActivated)

        // Command-F：drag 进行中 → 先 cancel 再搜索（接线顺序）。
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: echoCell, memberFolderID: nil)
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: center.x + 30, y: center.y))
        XCTAssertEqual(fixture.coordinator.controller.state, .dragging)
        fixture.simulateCommandF()
        XCTAssertEqual(fixture.coordinator.controller.state, .idle, "Command-F 先 cancel 进行中的 drag")
        XCTAssertTrue(fixture.searchActive, "Command-F 再激活搜索")
        XCTAssertFalse(fixture.coordinator.isSessionActive)
    }

    // MARK: - 5) 标题编辑禁拖

    func testTitleEditingDisablesDrag() async throws {
        let fixture = try await makeFixture()
        defer {
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let center = try XCTUnwrap(fixture.cellCenter(slot: 2))
        let echoCell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 2))

        fixture.titleEditing = true
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: echoCell, memberFolderID: nil)
        XCTAssertEqual(fixture.coordinator.controller.state, .idle, "标题编辑中 → 禁拖")
        fixture.coordinator.pointerUp(locationInWindow: center)
        XCTAssertEqual(fixture.clicks.count, 0)

        fixture.titleEditing = false
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: echoCell, memberFolderID: nil)
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: center.x + 30, y: center.y))
        XCTAssertEqual(fixture.coordinator.controller.state, .dragging, "标题编辑结束 → 拖拽恢复")
        fixture.coordinator.cancel(reason: .titleEditBegan)
    }

    // MARK: - 6) folder 内 drag 不动外层页

    func testFolderInternalDragDoesNotMoveOuterPage() async throws {
        let fixture = try await makeFixture()
        defer {
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let folder = try XCTUnwrap(fixture.folder)
        fixture.openFolder(folder.id)
        XCTAssertTrue(fixture.folderOpenState.isOpen)
        let outerPageBefore = fixture.surface.core.committedPage

        // 成员 0（Alpha）中心（surface 坐标系）。
        let memberCell = try XCTUnwrap(fixture.overlay.memberCell(at: 0))
        let memberRect = memberCell.convert(memberCell.bounds, to: fixture.surface)
        let down = NSPoint(x: memberRect.midX, y: memberRect.midY)
        // 成员 1（Beta）右侧 → 成员间 insertion（index 2）。
        let betaRect = try XCTUnwrap(fixture.overlay.memberCell(at: 1)).convert(
            try XCTUnwrap(fixture.overlay.memberCell(at: 1)).bounds, to: fixture.surface)
        let drop = NSPoint(x: betaRect.maxX + 20, y: memberRect.midY)

        fixture.coordinator.pointerDown(locationInWindow: down, sourceCell: memberCell, memberFolderID: folder.id)
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: down.x + 30, y: down.y))
        XCTAssertEqual(fixture.coordinator.controller.state, .dragging)
        fixture.coordinator.pointerDragged(locationInWindow: drop)
        fixture.coordinator.pointerUp(locationInWindow: drop)

        XCTAssertEqual(fixture.surface.core.committedPage, outerPageBefore, "folder 内 drag 不动外层页")
        XCTAssertEqual(fixture.commits.count, 1, "folder 内重排 commit")
        let committedFolder = try XCTUnwrap(fixture.commits[0].folder(id: folder.id))
        XCTAssertEqual(committedFolder.members, [ref("beta"), ref("alpha")], "成员重排 [Beta, Alpha]")
        XCTAssertEqual(fixture.folderTurns, [], "folder 内 drag 不触发翻页")
    }

    // MARK: - 7) 跨页 drop 更新可见内容与焦点（seam 层验证）

    func testCrossPageDropCommitsSeamLevel() async throws {
        // 40 apps（无 folder lab）→ 顶层 40 条目：page 0 = 35，page 1 = 5。
        let names = (1 ... 40).map { String(format: "App%02d", $0) }
        let fixture = try await makeFixture(appNames: names, folderLab: false)
        defer {
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        XCTAssertNil(fixture.folder, "无 folder lab → 无 folder 条目")
        // page 0 末行可见 cell（slot 29，row 5 col 4）。
        let center = try XCTUnwrap(fixture.cellCenter(slot: 29))
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 29))

        // 拖入右缘（x ≥ 960）→ dwell 武装 → edgeTimerFired → 顶层翻页 seam。
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: cell, memberFolderID: nil)
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: center.x + 30, y: center.y))
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: 980, y: center.y))
        XCTAssertEqual(fixture.coordinator.controller.state, .edgeTurnPending)
        fixture.coordinator.edgeTimerFired()
        XCTAssertEqual(fixture.topLevelTurns.count, 1, "跨页 → KeyboardPageTurner seam")
        XCTAssertEqual(fixture.topLevelTurns[0].0, .next, "右缘 → 下一页")
        _ = settleFrames(fixture.surface)
        XCTAssertEqual(fixture.surface.core.committedPage, 1, "翻页后可见页 = 1")

        // 新页上合法 drop（page 1 末条目后）→ commit seam（跨页可见内容更新由 T-1F-E 接）。
        let rowY = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 1)?.cell(at: 0))
            .convert(try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 1)?.cell(at: 0)).bounds,
                     to: fixture.surface).midY
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: 980, y: rowY))
        fixture.coordinator.pointerUp(locationInWindow: NSPoint(x: 980, y: rowY))
        XCTAssertEqual(fixture.commits.count, 1, "跨页 drop → commit seam 一次")
        XCTAssertEqual(fixture.commits[0].generation, LayoutGeneration(1), "commit 布局 generation +1")
        XCTAssertEqual(fixture.coordinator.controller.state, .idle)
        XCTAssertEqual(fixture.surface.core.committedPage, 1, "drop 后可见页保持 1")
    }

    // MARK: - 8) source/target cell 复用零 stale apply

    func testCellReuseZeroStaleApply() async throws {
        let fixture = try await makeFixture()
        defer {
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let pageView = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0))
        let center = try XCTUnwrap(fixture.cellCenter(slot: 2))
        let echoCell = try XCTUnwrap(pageView.cell(at: 2))
        // fixture setup 期间已有 stale 计数（begin→rebuild→apply 多次 render × app cell 图标请求，
        // 旧代结果到达时已 re-render → 良性 superseded 产物）；以 drag 前计数为基线。
        let staleBefore = pageView.staleIconApplyCount
        let overlayStaleBefore = fixture.overlay.staleIconApplyCount

        // click + drag 各一次（复用同一 cell 作为 source/target）。
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: echoCell, memberFolderID: nil)
        fixture.coordinator.pointerUp(locationInWindow: center)
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: echoCell, memberFolderID: nil)
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: center.x + 30, y: center.y))
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: 520, y: center.y))
        fixture.coordinator.pointerUp(locationInWindow: NSPoint(x: 520, y: center.y))
        XCTAssertEqual(fixture.commits.count, 1)

        XCTAssertEqual(pageView.staleIconApplyCount, staleBefore, "drag 会话零新增 stale icon apply")
        XCTAssertEqual(fixture.overlay.staleIconApplyCount, overlayStaleBefore, "overlay 零新增 stale icon apply")
    }

    // MARK: - 9) teardown 零 gesture/session/timer/store callback

    func testTeardownZeroResidue() async throws {
        // 40 apps（无 folder lab）→ 2 页：右缘非边界 → dwell 可武装；slot 2 仍存在（page 0 = 35）。
        let names = (1 ... 40).map { String(format: "App%02d", $0) }
        let fixture = try await makeFixture(appNames: names, folderLab: false)
        let center = try XCTUnwrap(fixture.cellCenter(slot: 2))
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 2))

        // 进行中的 drag（edge dwell 已武装 → 有 edge timer）。
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: cell, memberFolderID: nil)
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: center.x + 30, y: center.y))
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: 980, y: center.y))
        XCTAssertEqual(fixture.coordinator.controller.state, .edgeTurnPending)

        fixture.coordinator.teardown()
        XCTAssertEqual(fixture.coordinator.controller.state, .idle, "teardown → idle")
        XCTAssertFalse(fixture.coordinator.isSessionActive)
        XCTAssertEqual(fixture.suppression.last, true, "teardown 恢复 click 识别")
        XCTAssertFalse(fixture.coordinator.visuals.isPreviewVisible, "teardown 清 preview")
        fixture.coordinator.edgeTimerFired()
        XCTAssertEqual(fixture.coordinator.controller.state, .idle, "teardown 后 edge timer 无残留")

        // 全链 teardown 后零回调。
        let clicksBefore = fixture.clicks.count
        let commitsBefore = fixture.commits.count
        fixture.assembly.teardown()
        fixture.surface.teardown()
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: cell, memberFolderID: nil)
        fixture.coordinator.pointerUp(locationInWindow: center)
        XCTAssertEqual(fixture.clicks.count, clicksBefore, "teardown 后零 click 回调")
        XCTAssertEqual(fixture.commits.count, commitsBefore, "teardown 后零 commit 回调")
    }

    // MARK: - 10) Reduce Motion 分支

    func testReduceMotionBranch() async throws {
        let fixture = try await makeFixture()
        defer {
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        // 注入 reduceMotion = true 的 coordinator（视觉零动画分支）。
        let center = try XCTUnwrap(fixture.cellCenter(slot: 2))
        let echoCell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 2))
        let rmCoordinator = DragUISessionCoordinator(host: fixture.surface,
                                                     reduceMotionProvider: { true })
        rmCoordinator.layoutProvider = fixture.coordinator.layoutProvider
        rmCoordinator.catalogGenerationProvider = fixture.coordinator.catalogGenerationProvider
        rmCoordinator.catalogSnapshotProvider = fixture.coordinator.catalogSnapshotProvider
        rmCoordinator.geometryProvider = fixture.coordinator.geometryProvider
        rmCoordinator.onCommit = fixture.coordinator.onCommit
        rmCoordinator.onCellClick = fixture.coordinator.onCellClick
        rmCoordinator.onOverlayBlankClick = fixture.coordinator.onOverlayBlankClick
        rmCoordinator.topLevelPageTurn = fixture.coordinator.topLevelPageTurn
        rmCoordinator.folderPageTurn = fixture.coordinator.folderPageTurn
        rmCoordinator.clickRecognitionSuppressor = fixture.coordinator.clickRecognitionSuppressor
        rmCoordinator.dragGate = fixture.coordinator.dragGate

        XCTAssertTrue(rmCoordinator.visuals.reduceMotion, "Reduce Motion 分支激活")
        rmCoordinator.pointerDown(locationInWindow: center, sourceCell: echoCell, memberFolderID: nil)
        rmCoordinator.pointerDragged(locationInWindow: NSPoint(x: center.x + 30, y: center.y))
        XCTAssertEqual(rmCoordinator.controller.state, .dragging)
        XCTAssertTrue(rmCoordinator.visuals.isPreviewVisible, "RM 下 preview 仍显示（零动画）")
        rmCoordinator.pointerUp(locationInWindow: NSPoint(x: center.x + 30, y: center.y))
        XCTAssertEqual(rmCoordinator.controller.state, .idle)
        rmCoordinator.teardown()
    }
}
