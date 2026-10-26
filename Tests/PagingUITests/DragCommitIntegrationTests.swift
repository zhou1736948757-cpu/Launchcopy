// PagingUITests — DragCommitIntegrationTests（T-1F-D1-fix-e1 集成测试）
// seam 驱动（参照 DragUIIntegrationTests 模式）：复刻 AppDelegate.installDragUI 装配 +
// 新 onCommit 接线（applyCommittedLayout → 呈现刷新 → LayoutStore 异步持久化），验证
// 用户缺陷 2 的完整 commit 路径：
// 1) drag 重排 → provider 呈现新顺序 + surface 重渲染 + 布局入 store（flush/load 往返）
// 2) createFolder commit → folder cell 含 A+B（snapshot 成员）+ folder cell 点击仍打开
// 3) 移动后 cell 点击仍启动（layoutProvider = sessionLayout 与可见网格一致）
// 隐私：仅中性 fixture 数据（fixture.alpha/beta、'Group 1'、固定 UUID）；store 用临时根。

import AppKit
import XCTest
@testable import AppCatalogCore
@testable import AppGridUI
@testable import AppIconPipeline
@testable import PagingPrototypeApp
@testable import PagingUI

@MainActor
final class DragCommitIntegrationTests: XCTestCase {

    /// fixture app 持久引用（bundleID = "fixture." + 小写标题；与 FakeAppFactory 同源）。
    private func ref(_ title: String) -> PersistentAppReference {
        PersistentAppReference.bundleID("fixture.\(title.lowercased())")
    }

    /// WorkspaceTopLevelEntry → 中性顶层身份（bundleID 引用 → AppID；folder → FolderID）。
    private func identity(for entry: WorkspaceTopLevelEntry) -> TopLevelEntryIdentity? {
        switch entry {
        case .app(let ref):
            if case .bundleID(let id) = ref { return .app(CatalogFixture.appID(id)) }
            return nil
        case .folder(let id): return .folder(id)
        }
    }

    private var factory: FakeAppFactory!
    private var tempRoots: [URL] = []
    /// T-1F-B8-wave-c：挂在真实 QuitOnBlankClickWindow 里的窗口（防提前释放）。
    private var mountedWindows: [NSWindow] = []
    /// T-1F-B8-wave-c：空白点击 terminate 通路观测旗标盒（不真退）。
    private final class TerminationBox { var terminated = false }

    override func setUpWithError() throws {
        factory = try FakeAppFactory()
        ClickCensus.resetForTesting()
    }

    override func tearDownWithError() throws {
        factory?.removeRoot()
        factory = nil
        mountedWindows.removeAll()
        for root in tempRoots {
            try? FileManager.default.removeItem(at: root)
        }
        tempRoots = []
    }

    /// 每个测试独立临时 store 根（与 LayoutStoreActorTests 同法），tearDown 统一清理。
    private func makeTempStoreDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("drag-commit-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        tempRoots.append(root)
        return root
    }

    // MARK: - fixture（复刻 AppDelegate.installDragUI 装配 + T-1F-D1-fix-e1 onCommit 接线）

    @MainActor
    private final class CommitFixture {
        let assembly: AppCatalogAssembly
        let surface: PagingSurface
        let keyboard: KeyboardFocusController
        let folderOpenState: FolderOpenState
        let overlay: FolderOverlayView
        let launch: AppLaunchController
        let launcher: RecordingLauncher
        let coordinator: DragUISessionCoordinator
        let store: LayoutStoreActor
        let storeDirectory: URL
        var sessionLayout: PersistentWorkspaceLayout?
        var commits: [PersistentWorkspaceLayout] = []
        var enqueued = 0
        /// T-1F-B8-wave-c：dragGate 标题编辑腿（生产同构 AppDelegate:597-602 的 isTitleEditing leg；
        /// 搜索腿未建模——见结果文件「仍未建模层」清单）。
        var isTitleEditing = false

        init(assembly: AppCatalogAssembly, surface: PagingSurface,
             keyboard: KeyboardFocusController, folderOpenState: FolderOpenState,
             overlay: FolderOverlayView, launch: AppLaunchController,
             launcher: RecordingLauncher, coordinator: DragUISessionCoordinator,
             store: LayoutStoreActor, storeDirectory: URL) {
            self.assembly = assembly
            self.surface = surface
            self.keyboard = keyboard
            self.folderOpenState = folderOpenState
            self.overlay = overlay
            self.launch = launch
            self.launcher = launcher
            self.coordinator = coordinator
            self.store = store
            self.storeDirectory = storeDirectory
        }

        /// 与 AppDelegate.onCommit 同构（T-1F-D1-fix-e1 生产接线）：
        /// sessionLayout → provider.applyCommittedLayout → 呈现刷新（refreshPresentation +
        /// setPageCount + 焦点布局重建）→ 异步 enqueue。
        func handleCommit(_ newLayout: PersistentWorkspaceLayout) {
            let shouldCloseOpenFolder: Bool
            if let folderID = folderOpenState.openFolderID {
                let committedMemberCount = newLayout.folder(id: folderID)?.members.count ?? 0
                shouldCloseOpenFolder = committedMemberCount < folderOpenState.memberCount
            } else {
                shouldCloseOpenFolder = false
            }
            sessionLayout = newLayout
            commits.append(newLayout)
            let moveOutProxyHost = shouldCloseOpenFolder ? overlay.moveOutRemainingAppProxyHost : nil
            let moveOutProxy = overlay.moveOutRemainingAppProxy
            let moveOutProxyFrame = moveOutProxyHost?.frame
            if shouldCloseOpenFolder {
                closeFolder()
                if let moveOutProxyHost, let moveOutProxyFrame {
                    if let moveOutProxy {
                        moveOutProxyHost.addSubview(moveOutProxy)
                        moveOutProxy.frame = moveOutProxyHost.bounds
                    }
                    surface.addSubview(moveOutProxyHost, positioned: .above, relativeTo: nil)
                    overlay.reattachMoveOutRemainingAppProxyHost(moveOutProxyHost, frame: moveOutProxyFrame)
                }
            }
            let provider = assembly.provider
            let update = provider.applyCommittedLayout(newLayout,
                                                       atCurrentPage: surface.core.committedPage,
                                                       itemsPerPage: surface.itemsPerPage)
            if let update {
                surface.refreshPresentation()
                surface.setPageCount(update.plan.pageCount)
                if let base = provider.servedSnapshot {
                    let layout = AppGridFocusLayout.build(from: base,
                                                          composition: provider.presentationEntries,
                                                          itemsPerPage: surface.itemsPerPage)
                    keyboard.applyLayout(layout)
                }
            }
            // 与 AppDelegate.resyncOpenFolderAfterLayoutCommit 同构：folder 保持打开时
            // 把 openEntry / overlay 对齐刚提交的 servedFolderSnapshot（否则成员重排
            // 只改数据面，打开层仍显示打开时的旧序 → "拖拽无效果"）。
            if !shouldCloseOpenFolder,
               let folderID = folderOpenState.openFolderID,
               let updated = provider.servedFolderSnapshot?.entry(for: folderID) {
                folderOpenState.updateOpenEntry(updated)
                overlay.configure(entry: updated, innerPage: folderOpenState.innerPage,
                                  reduceMotion: false) { [weak self] appID in
                    self?.memberName(for: appID)
                }
                overlay.layout()
            }
            if shouldCloseOpenFolder {
                overlay.clearMoveOutRemainingAppProxy()
                // 即使 owner 在 closeFolder/refresh 间丢失，也不允许暂存 host 成为 orphan。
                moveOutProxyHost?.removeFromSuperview()
            }
            Task { [weak self] in
                guard let self else { return }
                await self.store.enqueue(newLayout)
                self.enqueued += 1
            }
        }

        /// 拖拽几何（host 坐标系；与 AppDelegate.makeDragGeometry 同构）。
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
                let isMovingOut = overlay.isMoveOutPresentationCollapsed
                let memberFrames = isMovingOut ? [] : overlay.memberDragItemFrames(convertedTo: surface, catalog: catalog)
                let page = isMovingOut ? surface.core.committedPage : folderOpenState.innerPage
                let pageCount = isMovingOut ? surface.core.pageCount : folderOpenState.innerPageCount
                let topLevelFrames: [DragItemFrame]
                if let pageView = assembly.renderer.pageView(forPage: surface.core.committedPage) {
                    topLevelFrames = pageView.dragItemFrames(convertedTo: surface, catalog: catalog)
                } else {
                    topLevelFrames = memberFrames
                }
                return DragGeometry(itemFrames: memberFrames, topLevelFrames: topLevelFrames,
                                    containerWidth: Double(surface.bounds.width),
                                    page: page, pageCount: pageCount,
                                    topLevelMoveOutBounds: isMovingOut ? .init(x: 0, y: 0,
                                        width: Double(surface.bounds.width), height: Double(surface.bounds.height)) : nil)
            }
        }

        /// click 派发（与 AppDelegate.handleDragCellClick 同构；T-1F-B7-wave-c 含合成 cell 路径）。
        func handleCellClick(_ cell: AppGridCellView) {
            if cell.isFolderCell {
                if let folderID = cell.bindingToken?.appID as? FolderID {
                    openFolder(folderID)
                }
                return
            }
            // 顶层/成员统一：合成 cell + 当前 servedRevision（不信任 live token；缺陷 3 修复镜像）。
            guard let appID = cell.bindingToken?.appID as? AppID,
                  let served = assembly.provider.servedRevision else { return }
            _ = launch.handleCell(
                AppCatalogAssembly.makeMemberLaunchCell(appID: appID, servedRevision: served))
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
            // T-1F-B8-wave-c 生产保真：与 AppDelegate.closeFolder 同构——
            // closeFolder 首行 cancel(.overlayClosed)；controller 非 idle 时 → endSession。
            // （原 fixture 缺此行，会高估 blank 分支残留；C′ 差异已记入结果文件。）
            coordinator.cancel(reason: .overlayClosed)
            folderOpenState.close()
            overlay.clearContent()
            overlay.removeFromSuperview()
            // T-1F-B10-wave-a forensics 生产保真：AppDelegate.closeFolder s16 census 同构
            // （仅计数，零行为变更）——fixture 关闭路径与生产同一状态位观测，夹具可断言。
            ClickCensus.hit(ClickCensus.Sink.closeFolderOverlayState(
                superviewIsNil: overlay.superview == nil))
        }

        func memberName(for appID: AppID) -> String? {
            assembly.provider.servedSnapshot?.records.first { $0.id == appID }?.displayName
        }

        /// 当前页某 slot 的 cell 中心（surface 坐标系）。
        func cellCenter(slot: Int) -> NSPoint? {
            guard let pageView = assembly.renderer.pageView(forPage: surface.core.committedPage),
                  let cell = pageView.cell(at: slot) else { return nil }
            let rect = cell.convert(cell.bounds, to: surface)
            return NSPoint(x: rect.midX, y: rect.midY)
        }

        /// 当前页指定 Folder cell 的真实 frame（surface 坐标系）。
        func folderCellFrame(_ folderID: FolderID) -> NSRect? {
            guard let pageView = assembly.renderer.pageView(forPage: surface.core.committedPage),
                  let cell = (0..<pageView.cellCount).compactMap({ pageView.cell(at: $0) })
                    .first(where: { ($0.bindingToken?.appID as? FolderID) == folderID }) else {
                return nil
            }
            return cell.convert(cell.bounds, to: surface)
        }

        /// 与生产 onMemberDragExitPanel 同构：折叠后以真实 Folder frame 挂代理。
        func showMoveOutPreview() {
            guard let folderID = folderOpenState.openFolderID,
                  let frame = folderCellFrame(folderID) else { return }
            overlay.showMoveOutRemainingAppProxy(in: surface, frame: frame)
            coordinator.setVisualHost(surface)
        }
    }

    private func makeFixture(appNames: [String] = ["Alpha", "Beta", "Gamma", "Delta", "Echo", "Foxtrot"],
                             folderLab: Bool = false) async throws -> CommitFixture {
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
        let launcher = RecordingLauncher()
        let launch = AppLaunchController(surface: surface, assembly: assembly, launcher: launcher)
        launch.install()
        assembly.begin()
        let committed = await waitUntil { assembly.provider.servedSnapshot != nil }
        XCTAssertTrue(committed)
        assembly.rebuildFolderCompositionIfNeeded()
        _ = assembly.refreshController.applyPendingAtIdleBoundary(currentPage: 0)

        let storeDirectory = try makeTempStoreDirectory()
        let store = LayoutStoreActor(storeDirectory: storeDirectory)
        let coordinator = DragUISessionCoordinator(host: surface)
        overlay.dragCoordinator = coordinator
        let fixture = CommitFixture(assembly: assembly, surface: surface, keyboard: keyboard,
                                   folderOpenState: folderOpenState, overlay: overlay,
                                   launch: launch, launcher: launcher, coordinator: coordinator,
                                   store: store, storeDirectory: storeDirectory)
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
            fixture?.handleCommit(newLayout)
        }
        coordinator.onCellClick = { [weak fixture] cell in
            fixture?.handleCellClick(cell)
        }
        coordinator.onOverlayBlankClick = { [weak fixture] in
            fixture?.closeFolder()
        }
        coordinator.topLevelPageTurn = { [weak fixture] direction, timestamp in
            guard let fixture else { return .deferred }
            return KeyboardPageTurner(surface: fixture.surface).turn(direction: direction, timestamp: timestamp)
        }
        coordinator.folderPageTurn = { [weak fixture] delta in
            guard let fixture else { return }
            if delta < 0 { fixture.overlay.prevPage() } else { fixture.overlay.nextPage() }
        }
        overlay.onMemberDragExitPanel = { [weak fixture] in
            guard let fixture else { return }
            // Match production capture/elevation ordering, not only collapse/host switch.
            fixture.overlay.prepareMoveOutIconCache()
            fixture.coordinator.prepareAndElevateMoveOutPreview(above: fixture.overlay)
            fixture.overlay.setMoveOutPresentationCollapsed(true)
            fixture.showMoveOutPreview()
            fixture.coordinator.elevateMoveOutPreview(above: fixture.overlay)
        }
        coordinator.onSessionStateChange = { [weak fixture] state in
            guard state == .idle,
                  let fixture,
                  fixture.folderOpenState.isOpen,
                  fixture.overlay.isMoveOutPresentationCollapsed else { return }
            fixture.overlay.clearMoveOutRemainingAppProxy()
            fixture.overlay.setMoveOutPresentationCollapsed(false)
            fixture.coordinator.setVisualHost(fixture.overlay)
        }
        // T-1F-B9-wave-b Stage 1 生产保真：抑制闭包含 s13a/s13b census（AppDelegate.installDragUI
        // 抑制闭包同构；仅计数，零行为变更）→ 既有抑制链路测试同步联动 s13 计数。
        // coordinator 语义：enabled=false = 抑制启用 → s13a_enable；enabled=true = 恢复 → s13b_disable。
        coordinator.clickRecognitionSuppressor = { [weak surface] enabled in
            guard let surface else { return }
            ClickCensus.hit(enabled ? ClickCensus.Sink.suppressionDisable
                                    : ClickCensus.Sink.suppressionEnable)
            for recognizer in surface.gestureRecognizers where recognizer is NSClickGestureRecognizer {
                recognizer.isEnabled = enabled
            }
        }
        // T-1F-B8-wave-c 生产保真：dragGate 标题编辑腿（AppDelegate:597-602 同构；搜索腿未建模）。
        coordinator.dragGate = { [weak fixture] in
            guard let fixture else { return true }
            return !fixture.isTitleEditing
        }
        // T-1F-B8-wave-c 生产保真：共享实例（AppDelegate.installDragUI :536 同构；
        // cell.mouseDown 经 `dragCoordinator ?? shared` 兜底）。新测试 defer 清 nil。
        DragUISessionCoordinator.shared = coordinator
        // T-1F-B8-wave-c 生产保真：AppLaunchController 通路结果经公开 onLaunchAttempt
        // 计入 census（与 AppDelegate 接线同构；S9 recognizer 通路观测）。
        launch.onLaunchAttempt = { outcome in
            if outcome == .launched {
                ClickCensus.hit(ClickCensus.Sink.launchAccepted)
            } else {
                ClickCensus.hit(ClickCensus.Sink.launchRejectedPrefix + String(describing: outcome))
            }
        }
        return fixture
    }

    // MARK: - 1) drag 重排 → 呈现新顺序 + 重渲染 + 入 store

    /// 用户缺陷 2 主路径：drag 重排两个顶层 app → 网格按新顺序重渲染；布局入 store
    /// （flush/load 往返）；移动后 cell 点击仍启动。
    func testDragReorderCommitReRendersAndPersists() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        // 无 folder lab → 顶层 = catalog 序（bundle ID 升序）[alpha, beta, delta, echo, foxtrot, gamma]。
        XCTAssertEqual(fixture.assembly.provider.presentationEntries.map(\.identity),
                       [.app(CatalogFixture.appID("fixture.alpha")), .app(CatalogFixture.appID("fixture.beta")),
                        .app(CatalogFixture.appID("fixture.delta")), .app(CatalogFixture.appID("fixture.echo")),
                        .app(CatalogFixture.appID("fixture.foxtrot")), .app(CatalogFixture.appID("fixture.gamma"))])

        // drag delta（slot 2）到 x=520 → commit seam（落点语义由 mutation 引擎决定，
        // DragDropTests 已覆盖；此处只断言 commit 发生 + 呈现 = 已提交布局）。
        // Known-ready pixels must survive the synchronous reorder commit, while
        // every slot receives a new token. This is not a native scanout assertion.
        let page = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0))
        var readyImages: [AppID: NSImage] = [:]
        var previousBindings: [ItemBindingToken] = []
        for slot in 0..<page.cellCount {
            let cell = try XCTUnwrap(page.cell(at: slot))
            let token = try XCTUnwrap(cell.bindingToken)
            let id = try XCTUnwrap(token.appID as? AppID)
            let image = RecordingIconLoader.solidImage()
            XCTAssertTrue(cell.applyIconIfValid(image, token: token))
            readyImages[id] = image
            previousBindings.append(token)
        }
        let center = try XCTUnwrap(fixture.cellCenter(slot: 2))
        let deltaCell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 2))
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: deltaCell, memberFolderID: nil)
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: center.x + 30, y: center.y))
        XCTAssertEqual(fixture.coordinator.controller.state, .dragging)
        fixture.coordinator.pointerDragged(locationInWindow: NSPoint(x: 520, y: center.y))
        fixture.coordinator.pointerUp(locationInWindow: NSPoint(x: 520, y: center.y))
        XCTAssertEqual(fixture.commits.count, 1, "合法 drop → commit seam 一次")
        XCTAssertFalse(readyImages.isEmpty)
        XCTAssertTrue(fixture.assembly.renderer.pageView(forPage: 0) === page)
        XCTAssertEqual(page.cellCount, readyImages.count)
        for slot in previousBindings.indices {
            let cell = try XCTUnwrap(page.cell(at: slot))
            let id = try XCTUnwrap(cell.bindingToken?.appID as? AppID)
            let displayedImage = try XCTUnwrap(cell.iconView.image)
            let expectedImage = try XCTUnwrap(readyImages[id])
            XCTAssertTrue(displayedImage === expectedImage)
            XCTAssertNotEqual(cell.bindingToken, previousBindings[slot])
        }

        XCTAssertNotEqual(fixture.commits[0].topLevelOrder,
                          [.app(ref("alpha")), .app(ref("beta")), .app(ref("delta")),
                           .app(ref("echo")), .app(ref("foxtrot")), .app(ref("gamma"))],
                          "重排后顺序 ≠ 原 catalog 序")

        // provider 呈现 = 已提交布局顺序（核心断言：commit 落到呈现面）。
        let committed = fixture.commits[0]
        let expectedIdentities = committed.topLevelOrder.compactMap(identity(for:))
        XCTAssertEqual(fixture.assembly.provider.presentationEntries.map(\.identity), expectedIdentities,
                       "呈现 = 布局顺序")
        // surface 重渲染：content 服务新顺序（同 revision）。
        let snapshot = try XCTUnwrap(fixture.assembly.provider.servedSnapshot)
        let expectedTitles = committed.topLevelOrder.compactMap { entry -> String? in
            if case .app(let ref) = entry {
                return snapshot.records.first { ref.matches(record: $0) }?.displayName
            }
            return nil
        }
        let content = fixture.assembly.provider.content(
            for: PagePresentationID(revision: fixture.assembly.provider.servedRevision ?? 0, pageIndex: 0),
            itemsPerPage: 35)
        XCTAssertEqual(content.items.map(\.title), expectedTitles, "content(for:) 服务新顺序")
        XCTAssertEqual(fixture.surface.core.pageCount, 1, "6 条 / 35 每页 = 1 页")
        // layoutProvider 一致性：sessionLayout == 已提交布局（后续 drag/点击按新布局解析）。
        XCTAssertEqual(fixture.coordinator.layoutProvider(), committed)

        // 布局入 store（异步 enqueue → flush barrier → 新实例 load 往返）。
        let enqueued = await waitUntil { fixture.enqueued == 1 }
        XCTAssertTrue(enqueued)
        let flushResult = await fixture.store.flush()
        switch flushResult {
        case .persisted, .nothingPending:
            break   // persist loop 可能已先行落盘（enqueue 完成即 spawn）→ nothingPending 亦为成功
        default:
            return XCTFail("期望 flush .persisted/.nothingPending，got \(flushResult)")
        }
        let reloaded = LayoutStoreActor(storeDirectory: fixture.storeDirectory)
        let loadResult = await reloaded.load()
        guard case .loaded(let storedLayout, _) = loadResult else {
            return XCTFail("期望 load .loaded，got \(loadResult)")
        }
        XCTAssertEqual(storedLayout.topLevelOrder, committed.topLevelOrder, "store 往返保留布局顺序")

        // 移动后 cell 点击仍启动（gamma 现居新位置）。
        let gammaID = CatalogFixture.appID("fixture.gamma")
        let gammaSlot = try XCTUnwrap(
            fixture.assembly.provider.presentationEntries.firstIndex(where: { $0.identity == .app(gammaID) }))
        let movedCenter = try XCTUnwrap(fixture.cellCenter(slot: gammaSlot))
        let movedCell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: gammaSlot))
        XCTAssertEqual(movedCell.bindingToken?.appID as? AppID, gammaID)
        fixture.coordinator.pointerDown(locationInWindow: movedCenter, sourceCell: movedCell, memberFolderID: nil)
        fixture.coordinator.pointerUp(locationInWindow: movedCenter)
        XCTAssertEqual(fixture.launcher.opened.count, 1, "移动后 cell 点击仍启动")
    }

    // MARK: - 2) createFolder commit → folder cell 含 A+B + 点击仍打开

    /// 用户缺陷 2 主路径：drag A 到 B（createFolder）→ folder cell 含 A+B；folder cell
    /// 点击仍打开；布局入 store。
    func testCreateFolderCommitShowsFolderCellAndPersists() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000D4")!)
        let layout = PersistentWorkspaceLayout(
            generation: LayoutGeneration(1),
            topLevelOrder: [.folder(folderID), .app(ref("gamma")), .app(ref("delta")),
                            .app(ref("echo")), .app(ref("foxtrot"))],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1",
                                             members: [ref("alpha"), ref("beta")])])

        // 直接经 onCommit seam 提交（mutation 引擎输出由 DragDropTests 覆盖）。
        fixture.coordinator.onCommit(layout)
        XCTAssertEqual(fixture.commits.count, 1)

        // folder cell 含 A+B（snapshot 成员 = 数据源；渲染器经 folderSnapshotProvider 同源）。
        guard case .folder(let folderEntry)? = fixture.assembly.provider.presentationEntries.first else {
            return XCTFail("期望首个条目为 folder")
        }
        XCTAssertEqual(folderEntry.members, [CatalogFixture.appID("fixture.alpha"), CatalogFixture.appID("fixture.beta")])
        XCTAssertEqual(fixture.assembly.provider.servedFolderSnapshot?.entry(for: folderID)?.members,
                       [CatalogFixture.appID("fixture.alpha"), CatalogFixture.appID("fixture.beta")])
        let content = fixture.assembly.provider.content(
            for: PagePresentationID(revision: fixture.assembly.provider.servedRevision ?? 0, pageIndex: 0),
            itemsPerPage: 35)
        XCTAssertEqual(content.items[0].identity as? FolderID, folderID, "网格显示 folder cell")
        XCTAssertEqual(content.items[0].title, "Group 1")

        // folder cell 点击仍打开（成员 A+B 可见）。
        let folderCenter = try XCTUnwrap(fixture.cellCenter(slot: 0))
        let folderCell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        XCTAssertTrue(folderCell.isFolderCell)
        fixture.coordinator.pointerDown(locationInWindow: folderCenter, sourceCell: folderCell, memberFolderID: nil)
        fixture.coordinator.pointerUp(locationInWindow: folderCenter)
        XCTAssertTrue(fixture.folderOpenState.isOpen, "folder cell 点击仍打开")
        XCTAssertEqual(fixture.folderOpenState.openFolderID, folderID)

        // 布局入 store。
        let enqueued = await waitUntil { fixture.enqueued == 1 }
        XCTAssertTrue(enqueued)
        let flushResult = await fixture.store.flush()
        switch flushResult {
        case .persisted, .nothingPending:
            break   // persist loop 可能已先行落盘（enqueue 完成即 spawn）→ nothingPending 亦为成功
        default:
            return XCTFail("期望 flush .persisted/.nothingPending，got \(flushResult)")
        }
        let reloaded = LayoutStoreActor(storeDirectory: fixture.storeDirectory)
        let loadResult = await reloaded.load()
        guard case .loaded(let storedLayout, _) = loadResult else {
            return XCTFail("期望 load .loaded，got \(loadResult)")
        }
        XCTAssertEqual(storedLayout.topLevelOrder, layout.topLevelOrder)
        XCTAssertEqual(storedLayout.folder(id: folderID)?.members, [ref("alpha"), ref("beta")])
    }

    // MARK: - Folder move-out commit closes overlay

    /// 当前打开 folder 的成员成功移到顶层后，统一 commit 接线必须关闭 overlay；
    /// 仅在 folder 内重排时成员数不变，overlay 必须继续保持打开。
    func testFolderMoveOutCommitClosesOverlayButInternalReorderKeepsItOpen() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }

        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000E5")!)
        let initial = PersistentWorkspaceLayout(
            generation: LayoutGeneration(1),
            topLevelOrder: [.folder(folderID), .app(ref("delta")),
                            .app(ref("echo")), .app(ref("foxtrot"))],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1",
                                             members: [ref("alpha"), ref("beta"), ref("gamma")])])
        fixture.coordinator.onCommit(initial)
        fixture.openFolder(folderID)
        XCTAssertTrue(fixture.folderOpenState.isOpen)
        XCTAssertNotNil(fixture.overlay.superview)

        let reorder = LayoutMutation(expectedGeneration: initial.generation)
            .reorderFolderMembers(in: initial, folderID: folderID,
                                  member: ref("alpha"), toIndex: 2)
        guard case .success(let reordered) = reorder else {
            return XCTFail("期望 folder 内重排成功，got \(reorder)")
        }
        fixture.coordinator.onCommit(reordered)
        XCTAssertTrue(fixture.folderOpenState.isOpen,
                      "成员数不变的 folder 内重排不得关闭 overlay")
        XCTAssertNotNil(fixture.overlay.superview)
        // T-1G-FOLDER-DRAG-FIX：commit 后 openEntry / overlay 必须反映新成员序
        // （否则用户看到拖拽预览有、放下无效果）。
        XCTAssertEqual(fixture.folderOpenState.openEntry?.members,
                       [CatalogFixture.appID("fixture.beta"),
                        CatalogFixture.appID("fixture.gamma"),
                        CatalogFixture.appID("fixture.alpha")],
                       "openEntry 成员序应与 commit 后 snapshot 对齐")
        XCTAssertEqual(fixture.overlay.memberAppID(at: 0),
                       CatalogFixture.appID("fixture.beta"),
                       "overlay 成员格 0 应重绑为重排后首位")
        XCTAssertEqual(fixture.overlay.memberAppID(at: 2),
                       CatalogFixture.appID("fixture.alpha"),
                       "overlay 成员格 2 应重绑为重排后末位")

        let moveOut = LayoutMutation(expectedGeneration: reordered.generation)
            .moveOutOfFolder(in: reordered, folderID: folderID,
                             member: ref("alpha"), toIndex: 1)
        guard case .success(let movedOut) = moveOut else {
            return XCTFail("期望成员移出成功，got \(moveOut)")
        }
        fixture.coordinator.onCommit(movedOut)

        XCTAssertFalse(fixture.folderOpenState.isOpen,
                       "成员成功移出当前 folder 后应立即关闭")
        XCTAssertNil(fixture.overlay.superview,
                     "关闭后 overlay 必须从视图树移除")
        XCTAssertEqual(movedOut.folder(id: folderID)?.members.count, 2)
        XCTAssertTrue(movedOut.topLevelOrder.contains(.app(ref("alpha"))))
    }

    /// 真实 mouseDown→mouseDragged：成员越过 panel 边界时应立刻折叠 Folder 外观，
    /// 同时保持 drag session；若随后取消，Folder 外观必须恢复。
    func testMemberDragExitPanelCollapsesPresentationAndCancelRestoresIt() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let (window, _, _) = try mountInQuitWindow(fixture)

        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000E6")!)
        let initial = PersistentWorkspaceLayout(
            generation: LayoutGeneration(1),
            topLevelOrder: [.folder(folderID), .app(ref("delta")),
                            .app(ref("echo")), .app(ref("foxtrot"))],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1",
                                             members: [ref("alpha"), ref("beta")])])
        fixture.coordinator.onCommit(initial)
        fixture.openFolder(folderID)
        fixture.overlay.layoutSubtreeIfNeeded()
        let baselineGeneration = fixture.sessionLayout?.generation
        let baselineCommitCount = fixture.commits.count
        let baselineEnqueued = fixture.enqueued

        let memberCell = try XCTUnwrap(fixture.overlay.memberCell(at: 0))
        let down = windowPoint(of: memberCell)
        fixture.overlay.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: down, in: window))
        XCTAssertEqual(fixture.coordinator.controller.state, .pressed)

        let outsideInOverlay = NSPoint(x: fixture.overlay.panelFrame.maxX + 40,
                                       y: fixture.overlay.panelFrame.midY)
        let outsideInWindow = fixture.overlay.convert(outsideInOverlay, to: nil)
        fixture.overlay.mouseDragged(with: pointerEvent(.leftMouseDragged,
                                                         atWindowPoint: outsideInWindow,
                                                         in: window))

        XCTAssertTrue(fixture.overlay.isMoveOutPresentationCollapsed,
                      "成员拖出 panel 时 Folder 外观应立即折叠")
        XCTAssertTrue(fixture.folderOpenState.isOpen,
                      "视觉折叠阶段仍保留逻辑状态，等待 drop commit")
        XCTAssertTrue(fixture.coordinator.isSessionActive,
                      "Folder 折叠不得取消正在进行的拖拽")
        XCTAssertNotNil(fixture.overlay.moveOutRemainingAppProxy,
                        "两成员 Folder 越界时应显示剩余成员代理")

        fixture.coordinator.cancel(reason: .escape)
        XCTAssertFalse(fixture.overlay.isMoveOutPresentationCollapsed,
                       "未提交而取消时应恢复 Folder 外观")
        XCTAssertNil(fixture.overlay.moveOutRemainingAppProxy,
                     "取消后不得残留 transient 代理")
        XCTAssertTrue(fixture.folderOpenState.isOpen)
        XCTAssertNotNil(fixture.overlay.superview)
        XCTAssertEqual(fixture.sessionLayout?.generation, baselineGeneration)
        XCTAssertEqual(fixture.commits.count, baselineCommitCount)
        XCTAssertEqual(fixture.enqueued, baselineEnqueued)
    }

    /// 完整真实手势：成员从 Folder 拖到顶层条目间隙，越界先折叠，mouseUp 后
    /// move-out commit，并真正关闭/移除 Folder overlay。
    func testRealPointerFolderMoveOutCollapsesThenCommitsAndClosesOverlay() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let (window, _, _) = try mountInQuitWindow(fixture)

        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000E7")!)
        let initial = PersistentWorkspaceLayout(
            generation: LayoutGeneration(1),
            topLevelOrder: [.folder(folderID), .app(ref("delta")),
                            .app(ref("echo")), .app(ref("foxtrot"))],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1",
                                             members: [ref("alpha"), ref("beta"), ref("gamma")])])
        fixture.coordinator.onCommit(initial)
        fixture.openFolder(folderID)
        fixture.overlay.layoutSubtreeIfNeeded()

        let memberCell = try XCTUnwrap(fixture.overlay.memberCell(at: 0))
        let down = windowPoint(of: memberCell)
        let pageView = try XCTUnwrap(
            fixture.assembly.renderer.pageView(forPage: fixture.surface.core.committedPage))
        let topFrames = pageView.dragItemFrames(
            convertedTo: fixture.surface,
            catalog: fixture.assembly.provider.servedSnapshot)
        XCTAssertGreaterThanOrEqual(topFrames.count, 2)
        let first = topFrames[0].frame
        let second = topFrames[1].frame
        let landingInSurface = NSPoint(x: (first.maxX + second.minX) / 2,
                                       y: first.minY + first.height / 2)
        let landingInWindow = fixture.surface.convert(landingInSurface, to: nil)
        let landingInOverlay = fixture.overlay.convert(landingInWindow, from: nil)
        XCTAssertFalse(fixture.overlay.panelFrame.contains(landingInOverlay),
                       "夹具必须把顶层间隙放在 Folder panel 外")

        fixture.overlay.mouseDown(with: pointerEvent(.leftMouseDown,
                                                      atWindowPoint: down,
                                                      in: window))
        fixture.overlay.mouseDragged(with: pointerEvent(.leftMouseDragged,
                                                         atWindowPoint: landingInWindow,
                                                         in: window))
        XCTAssertTrue(fixture.overlay.isMoveOutPresentationCollapsed)
        XCTAssertNil(fixture.overlay.moveOutRemainingAppProxy,
                     "三成员 Folder 不应显示唯一剩余 App 代理")
        guard case .topLevelTarget(let targetIndex) = fixture.coordinator.controller.lastIntent else {
            return XCTFail("越过 Folder panel 后应进入顶层落点语义，got \(fixture.coordinator.controller.lastIntent)")
        }
        XCTAssertGreaterThanOrEqual(targetIndex, 0)

        fixture.overlay.mouseUp(with: pointerEvent(.leftMouseUp,
                                                    atWindowPoint: landingInWindow,
                                                    in: window))

        XCTAssertEqual(fixture.commits.last?.generation, LayoutGeneration(2))
        XCTAssertFalse(fixture.folderOpenState.isOpen)
        XCTAssertNil(fixture.overlay.superview)
        XCTAssertTrue(fixture.sessionLayout?.topLevelOrder.contains(.app(ref("alpha"))) == true)
        XCTAssertEqual(fixture.sessionLayout?.folder(id: folderID)?.members.count, 2)
        XCTAssertFalse(fixture.coordinator.isSessionActive)
    }

    /// 两成员 Folder 的真实 move-out 预览：越界但尚未 mouseUp 时，唯一剩余成员
    /// 覆盖原 Folder cell；commit 后代理清除且剩余成员占据 Folder 原位置。
    /// First out-of-panel event is aligned with a now-hidden member row.
    func testTwoMemberMoveOutIgnoresHiddenRowsAndLandsOnMainWithoutExtraMovement() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let (window, _, _) = try mountInQuitWindow(fixture)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000E9")!)
        let initial = PersistentWorkspaceLayout(generation: LayoutGeneration(1),
            topLevelOrder: [.folder(folderID), .app(ref("delta")), .app(ref("echo")),
                            .app(ref("foxtrot")), .app(ref("gamma"))],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1",
                                             members: [ref("alpha"), ref("beta")])])
        fixture.coordinator.onCommit(initial)
        fixture.openFolder(folderID)
        fixture.overlay.layoutSubtreeIfNeeded()
        let member = try XCTUnwrap(fixture.overlay.memberCell(at: 0))
        let iconsReady = await waitUntil { fixture.overlay.memberCell(at: 0)?.iconView.image != nil
            && fixture.overlay.memberCell(at: 1)?.iconView.image != nil }
        XCTAssertTrue(iconsReady)
        let down = member.iconView.convert(NSPoint(x: member.iconView.bounds.midX,
                                                   y: member.iconView.bounds.midY), to: nil)
        let memberRect = member.convert(member.bounds, to: fixture.overlay)
        let exitPoint = NSPoint(x: fixture.overlay.panelFrame.maxX + 20, y: memberRect.midY)
        let drop = fixture.overlay.convert(exitPoint, to: nil)
        let commitsBefore = fixture.commits.count
        fixture.overlay.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: down, in: window))
        fixture.overlay.mouseDragged(with: pointerEvent(.leftMouseDragged, atWindowPoint: drop, in: window))
        XCTAssertTrue(fixture.overlay.isMoveOutPresentationCollapsed)
        if case .topLevelTarget = fixture.coordinator.controller.lastIntent {} else {
            XCTFail("Collapsed panel must not keep a hidden-member insertion marker")
        }
        XCTAssertTrue(fixture.coordinator.visuals.isPreviewVisible)
        XCTAssertNotNil(fixture.coordinator.visuals.previewIconImage)
        XCTAssertTrue(fixture.coordinator.visuals.visualViewSuperviews[0] === window.contentView)
        let carried = fixture.coordinator.visuals.previewFrame
        let pointer = try XCTUnwrap(window.contentView).convert(drop, from: nil)
        XCTAssertEqual(carried.midX, pointer.x, accuracy: 0.01)
        XCTAssertEqual(carried.minY, pointer.y + 24, accuracy: 0.01)
        fixture.overlay.mouseUp(with: pointerEvent(.leftMouseUp, atWindowPoint: drop, in: window))
        XCTAssertEqual(fixture.commits.count, commitsBefore + 1)
        XCTAssertNil(fixture.sessionLayout?.folder(id: folderID))
        XCTAssertEqual(fixture.sessionLayout?.topLevelOrder.first, .app(ref("beta")))
        XCTAssertTrue(fixture.sessionLayout?.topLevelOrder.contains(.app(ref("alpha"))) == true)
        XCTAssertFalse(fixture.coordinator.visuals.isPreviewVisible)
        XCTAssertNil(fixture.overlay.superview)
        XCTAssertTrue(fixture.launcher.opened.isEmpty)
        let acceptedWrites = await waitUntil { fixture.enqueued == fixture.commits.count }
        XCTAssertTrue(acceptedWrites)
        switch await fixture.store.flush() {
        case .persisted, .nothingPending: break
        default: return XCTFail("Move-out commit must persist in the isolated fixture store")
        }
        let reloaded = LayoutStoreActor(storeDirectory: fixture.storeDirectory)
        guard case .loaded(let saved, _) = await reloaded.load() else {
            return XCTFail("Move-out must survive a fresh store reload")
        }
        XCTAssertEqual(saved, fixture.sessionLayout)
        XCTAssertNil(saved.folder(id: folderID))
    }

    func testTwoMemberFolderMoveOutShowsRemainingAppProxyThenDissolves() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let (window, _, _) = try mountInQuitWindow(fixture)
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000E8")!)
        let initial = PersistentWorkspaceLayout(
            generation: LayoutGeneration(1),
            topLevelOrder: [.folder(folderID), .app(ref("delta")),
                            .app(ref("echo")), .app(ref("foxtrot")), .app(ref("gamma"))],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1",
                                             members: [ref("alpha"), ref("beta")])])
        fixture.coordinator.onCommit(initial)
        fixture.openFolder(folderID)
        fixture.overlay.layoutSubtreeIfNeeded()

        let memberCell = try XCTUnwrap(fixture.overlay.memberCell(at: 0))
        let remainingCell = try XCTUnwrap(fixture.overlay.memberCell(at: 1))
        _ = await waitUntil { remainingCell.iconView.image != nil }
        let folderFrame = try XCTUnwrap(fixture.folderCellFrame(folderID))
        let folderTopCell = try XCTUnwrap(
            (0..<fixture.assembly.renderer.pageView(forPage: 0)!.cellCount)
                .compactMap { fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: $0) }
                .first { ($0.bindingToken?.appID as? FolderID) == folderID })
        let down = windowPoint(of: memberCell)
        let pageView = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0))
        let catalog = fixture.assembly.provider.servedSnapshot
        let topFrames = pageView.dragItemFrames(convertedTo: fixture.surface, catalog: catalog)
        let memberFrames = fixture.overlay.memberDragItemFrames(convertedTo: fixture.surface,
                                                                  catalog: catalog)
        let memberMinY = memberFrames.map(\.frame.minY).min() ?? 0
        let memberMaxY = memberFrames.map(\.frame.maxY).max() ?? 0
        // 行带优先契约：落点 Y 必须离开成员行带，同时仍落在某条顶层行带内（isTopLevelLanding）。
        // 优先选与成员行带竖直分离的顶层帧；找不到时再退到成员带外最近顶层中线。
        let separatedTop = topFrames.first {
            $0.frame.maxY < memberMinY - 1 || $0.frame.minY > memberMaxY + 1
        }
        let landingY: Double
        if let separatedTop {
            landingY = separatedTop.frame.y + separatedTop.frame.height / 2
        } else if let anyTop = topFrames.first {
            landingY = memberMinY > anyTop.frame.minY
                ? min(memberMinY - 4, anyTop.frame.maxY)
                : max(memberMaxY + 4, anyTop.frame.minY)
        } else {
            landingY = memberMinY - 20
        }
        // 右侧页边距 + 成员行带外顶层缝隙：真实 move-out，A 落到 B 之后。
        let landingInSurface = NSPoint(x: fixture.surface.bounds.maxX - 4, y: landingY)
        let landingInWindow = fixture.surface.convert(landingInSurface, to: nil)

        fixture.overlay.mouseDown(with: pointerEvent(.leftMouseDown,
                                                      atWindowPoint: down, in: window))
        fixture.overlay.mouseDragged(with: pointerEvent(.leftMouseDragged,
                                                         atWindowPoint: landingInWindow, in: window))

        XCTAssertTrue(fixture.overlay.isMoveOutPresentationCollapsed)
        XCTAssertTrue(fixture.coordinator.isSessionActive)
        guard case .topLevelTarget = fixture.coordinator.controller.lastIntent else {
            return XCTFail("越界后应进入顶层落点语义，got \(fixture.coordinator.controller.lastIntent)")
        }
        let proxy = try XCTUnwrap(fixture.overlay.moveOutRemainingAppProxy)
        let proxyHost = try XCTUnwrap(fixture.overlay.moveOutRemainingAppProxyHost)
        XCTAssertEqual(fixture.overlay.moveOutRemainingAppProxyFrame, folderFrame,
                       "代理必须精确覆盖真实 Folder cell frame")
        XCTAssertEqual(proxy.boundName, remainingCell.boundName)
        if let proxyImage = proxy.iconView.image, let remainingImage = remainingCell.iconView.image {
            XCTAssertEqual(proxyImage.tiffRepresentation, remainingImage.tiffRepresentation,
                           "Production pre-collapse capture retains the survivor icon pixels durably")
        } else {
            XCTFail("剩余成员与代理都应有 fixture 图标")
        }
        // 活跃拖拽期间的普通 configure 不得展开 Folder 或清掉 transient 代理。
        let activeEntry = try XCTUnwrap(fixture.overlay.currentEntry)
        fixture.overlay.configure(entry: activeEntry, innerPage: fixture.overlay.currentInnerPage,
                                   reduceMotion: false) { appID in
            fixture.memberName(for: appID)
        }
        XCTAssertTrue(fixture.overlay.isMoveOutPresentationCollapsed)
        XCTAssertNotNil(fixture.overlay.moveOutRemainingAppProxy)
        let proxyPoint = NSPoint(x: folderFrame.midX, y: folderFrame.midY)
        XCTAssertFalse(fixture.surface.hitTest(proxyPoint) === proxy,
                       "transient 代理 wrapper 不得抢占 surface hit-test")
        XCTAssertEqual(folderTopCell.bindingToken?.appID as? FolderID, folderID,
                       "真实 Folder cell binding 不得被代理改写")

        fixture.overlay.mouseUp(with: pointerEvent(.leftMouseUp,
                                                    atWindowPoint: landingInWindow, in: window))

        XCTAssertEqual(fixture.commits.last?.generation, LayoutGeneration(2))
        XCTAssertNil(fixture.sessionLayout?.folder(id: folderID), "两成员 Folder 解散")
        XCTAssertEqual(fixture.sessionLayout?.topLevelOrder.first, .app(ref("beta")),
                       "剩余 B 占据原 Folder 顶层位置")
        XCTAssertTrue(fixture.sessionLayout?.topLevelOrder.contains(.app(ref("alpha"))) == true)
        XCTAssertNil(fixture.overlay.moveOutRemainingAppProxy)
        XCTAssertNil(proxyHost.superview, "commit 后 transient proxy host 不得残留")
        XCTAssertNil(fixture.overlay.superview)
        XCTAssertFalse(fixture.coordinator.isSessionActive)
    }

    // MARK: - 3) T-1F-B7-wave-c 缺陷 3 回归：建夹 commit 后顶层 app 单击仍启动

    /// 缺陷 3 主路径：建夹 commit（onCommit seam）后点击剩余顶层 app cell → 启动管线被调用
    /// （fake launcher 断言）；连点 6 次不回归；folder cell 点击仍打开；合成 cell 成员路径
    /// （共用路径）不回归；关闭 folder 后顶层单击不回归。取证基线：真实栈下 token
    /// catalogRevision == servedRevision、bundleURL 命中（results 文件 §1.1）。
    func testFolderCreateCommitThenTopLevelClickLaunches() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }

        // 基线：建夹前，顶层 app（catalog 序 gamma 在 slot 5）单击 → 启动。
        let bCenter = try XCTUnwrap(fixture.cellCenter(slot: 5))
        let bCell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 5))
        fixture.coordinator.pointerDown(locationInWindow: bCenter, sourceCell: bCell, memberFolderID: nil)
        fixture.coordinator.pointerUp(locationInWindow: bCenter)
        XCTAssertEqual(fixture.launcher.opened.count, 1, "建夹前顶层单击启动")
        XCTAssertEqual(fixture.launch.lastOutcome, .launched)

        // 建夹 commit（alpha+beta 入夹；gamma 落顶层 slot 1）。
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000D4")!)
        let layout = PersistentWorkspaceLayout(
            generation: LayoutGeneration(1),
            topLevelOrder: [.folder(folderID), .app(ref("gamma")), .app(ref("delta")),
                            .app(ref("echo")), .app(ref("foxtrot"))],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1",
                                             members: [ref("alpha"), ref("beta")])])
        fixture.coordinator.onCommit(layout)
        XCTAssertEqual(fixture.commits.count, 1)

        // 缺陷 3 核心：建夹后点击剩余顶层 app（gamma，slot 1）→ 启动管线被调用。
        let center = try XCTUnwrap(fixture.cellCenter(slot: 1))
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 1))
        XCTAssertFalse(cell.isFolderCell)
        XCTAssertEqual(cell.bindingToken?.appID as? AppID, CatalogFixture.appID("fixture.gamma"))
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: cell, memberFolderID: nil)
        fixture.coordinator.pointerUp(locationInWindow: center)
        XCTAssertEqual(fixture.launcher.opened.count, 2, "建夹后顶层单击 → 启动管线被调用")
        XCTAssertEqual(fixture.launch.lastOutcome, .launched)

        // 连点 6 次（对齐用户取证）不回归。
        for _ in 2...6 {
            fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: cell, memberFolderID: nil)
            fixture.coordinator.pointerUp(locationInWindow: center)
        }
        XCTAssertEqual(fixture.launcher.opened.count, 7, "建夹后顶层连点 6 次全部启动")

        // folder cell 点击仍打开（不回归）。
        let folderCenter = try XCTUnwrap(fixture.cellCenter(slot: 0))
        let folderCell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        XCTAssertTrue(folderCell.isFolderCell)
        fixture.coordinator.pointerDown(locationInWindow: folderCenter, sourceCell: folderCell, memberFolderID: nil)
        fixture.coordinator.pointerUp(locationInWindow: folderCenter)
        XCTAssertTrue(fixture.folderOpenState.isOpen, "folder cell 点击仍打开")

        // 合成 cell 成员路径（顶层现共用的同一管线）不回归。
        let memberCell = AppCatalogAssembly.makeMemberLaunchCell(
            appID: CatalogFixture.appID("fixture.alpha"),
            servedRevision: fixture.assembly.provider.servedRevision ?? 0)
        _ = fixture.launch.handleCell(memberCell)
        XCTAssertEqual(fixture.launch.lastOutcome, .launched, "合成 cell 成员路径不回归")
        XCTAssertEqual(fixture.launcher.opened.count, 8)

        // 关闭 folder → 顶层单击仍启动（真实用户时序：建夹 → 开夹看成员 → 关夹 → 点顶层）。
        fixture.closeFolder()
        XCTAssertFalse(fixture.folderOpenState.isOpen)
        // T-1F-B10-wave-a：closeFolder 后 overlay.superview==nil 状态位（夹具生产同构 s16）。
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.closeFolderOverlayState(superviewIsNil: true)), 1,
                       "closeFolder 后 overlay 已摘除（_sv1）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.closeFolderOverlayState(superviewIsNil: false)), 0,
                       "无 _sv0 残留观测")
        XCTAssertNil(fixture.overlay.superview, "fixture overlay 已从视图树移除")
        fixture.coordinator.pointerDown(locationInWindow: center, sourceCell: cell, memberFolderID: nil)
        fixture.coordinator.pointerUp(locationInWindow: center)
        XCTAssertEqual(fixture.launcher.opened.count, 9, "关夹后顶层单击仍启动")
        XCTAssertEqual(fixture.launch.lastOutcome, .launched)
    }

    // MARK: - 4) T-1F-B8-wave-c Stage 1：全链 harness（补 C′ 五层盲区）+ census 断言

    /// 把 fixture 的 surface 挂进真实 QuitOnBlankClickWindow（BlankClickToQuitTests 同法），
    /// 接生产同构窗口 seams（onDragActiveCancel / folderOpenStateProvider / onBlankClick）。
    /// onBlankClick 只置本地旗标（不真退 NSApp）。
    @discardableResult
    private func mountInQuitWindow(_ fixture: CommitFixture) throws
        -> (window: QuitOnBlankClickWindow, container: NSView, termination: TerminationBox) {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        let window = QuitOnBlankClickWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = container
        fixture.surface.frame = container.bounds
        container.addSubview(fixture.surface)
        // T-1F-B8-wave-c：headless 无显示周期，惰性创建的 cell 零 frame → 强制全树布局
        //（真实 app 中由窗口显示周期完成；此行只补布局，不改变任何行为语义）。
        fixture.surface.layoutSubtreeIfNeeded()
        let termination = TerminationBox()
        // 生产同构（AppDelegate:228-248）；搜索腿未建模 → exitSearch 恒 false（走 terminate 通路）。
        window.onBlankClickShouldExitSearch = { false }
        window.onBlankClick = { [weak termination] in termination?.terminated = true }
        window.onDragActiveCancel = { [weak fixture] in
            guard let fixture, fixture.coordinator.isSessionActive else { return false }
            fixture.coordinator.cancel(reason: .escape)
            return true
        }
        window.onEscapeDuringDrag = { [weak fixture] in
            guard let fixture, fixture.coordinator.isSessionActive else { return false }
            fixture.coordinator.cancel(reason: .escape)
            return true
        }
        window.folderOpenStateProvider = { [weak fixture] in fixture?.folderOpenState }
        mountedWindows.append(window)
        return (window, container, termination)
    }

    /// 合成 NSEvent（window 基坐标）。
    private func pointerEvent(_ type: NSEvent.EventType, atWindowPoint p: NSPoint,
                              in window: NSWindow) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: p, modifierFlags: [],
                           timestamp: ProcessInfo.processInfo.systemUptime,
                           windowNumber: window.windowNumber, context: nil,
                           eventNumber: 0, clickCount: 1, pressure: 1)!
    }

    /// 真 cell 坐标 → window 基坐标（event.locationInWindow 同基）。
    private func windowPoint(of cell: AppGridCellView) -> NSPoint {
        let rect = cell.convert(cell.bounds, to: nil)
        return NSPoint(x: rect.midX, y: rect.midY)
    }

    /// Path A 存活代理：AppLaunchController 挂在 surface 上的单击识别器。
    private func surfaceLaunchRecognizer(_ surface: PagingSurface) -> NSClickGestureRecognizer? {
        surface.gestureRecognizers
            .first(where: { $0 is NSClickGestureRecognizer }) as? NSClickGestureRecognizer
    }

    /// C′ 五层盲区补齐主测试（T-1F-B8-wave-c Stage 1 mandate §5.2）：
    /// 真实 QuitOnBlankClickWindow + 合成 NSEvent 经 AppGridCellView.mouseDown 真视图入口 +
    /// **真实 pointer 会话建夹**（mouseDown→dragged→up 出 .committed，弃 onCommit seam 直呼）+
    /// census 链段计数断言 + Path A（surface 启动识别器）抑制/恢复状态断言。
    /// 「仍未建模层」清单见结果文件 §Stage1.4（真 handleDragCellClick 方法体、AppSearchController、
    /// key-window/全屏传递、真实 NSWorkspace 启动）。
    /// Actual visible icon edge, not the unrelated central third of the cell.
    /// Synthetic pointer delivery exercises runtime geometry and the shared commit path.
    func testDropInsideVisibleIconCreatesFolderRatherThanReordering() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let (window, _, _) = try mountInQuitWindow(fixture)
        let page = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0))
        let source = try XCTUnwrap(page.cell(at: 0))
        let target = try XCTUnwrap(page.cell(at: 1))
        let down = source.iconView.convert(NSPoint(x: source.iconView.bounds.midX,
                                                   y: source.iconView.bounds.midY), to: nil)
        let localDrop = NSPoint(x: target.iconView.frame.minX + 2,
                                y: target.iconView.frame.midY)
        XCTAssertTrue(target.acceptsLaunchHit(at: localDrop))
        let drop = target.convert(localDrop, to: nil)
        let surfaceDrop = fixture.surface.convert(drop, from: nil)
        let cellFrame = target.convert(target.bounds, to: fixture.surface)
        XCTAssertNotEqual(DropZoneGeometry.hitZone(
            pointer: .init(x: surfaceDrop.x, y: surfaceDrop.y),
            frame: .init(x: cellFrame.minX, y: cellFrame.minY,
                         width: cellFrame.width, height: cellFrame.height),
            margin: DragParameters.default.dropZoneMarginsPT), .center,
            "Regression point must demonstrate the previous cell-center miss")
        source.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: down, in: window))
        source.mouseDragged(with: pointerEvent(.leftMouseDragged, atWindowPoint: drop, in: window))
        XCTAssertEqual(fixture.coordinator.controller.lastIntent, .createFolder(target: ref("beta")))
        XCTAssertTrue(fixture.coordinator.visuals.isCreateFolderIndicatorVisible)
        XCTAssertFalse(fixture.coordinator.visuals.isInsertionIndicatorVisible)
        source.mouseUp(with: pointerEvent(.leftMouseUp, atWindowPoint: drop, in: window))
        XCTAssertFalse(fixture.coordinator.visuals.isCreateFolderIndicatorVisible)
        XCTAssertEqual(fixture.commits.count, 1)
        let layout = try XCTUnwrap(fixture.commits.first)
        XCTAssertEqual(layout.folders.count, 1)
        XCTAssertEqual(layout.folders.first?.members, [ref("beta"), ref("alpha")])
        XCTAssertTrue(fixture.launcher.opened.isEmpty, "Dragging must not launch either app")
    }

    func testFullChainRealPointerSessionCreateFolderThenCellMouseDownLaunches() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let (window, _, _) = try mountInQuitWindow(fixture)
        let recognizer = try XCTUnwrap(surfaceLaunchRecognizer(fixture.surface))
        XCTAssertTrue(recognizer.isEnabled, "空闲态：Path A surface 启动识别器可用")

        // 真实 pointer 会话建夹：alpha(slot 0) 拖到 beta(slot 1) 中心内缩区 → .createFolder(target: beta)。
        let alphaCell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let betaCell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 1))
        let aPoint = windowPoint(of: alphaCell)
        let bPoint = windowPoint(of: betaCell)
        alphaCell.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: aPoint, in: window))
        XCTAssertEqual(fixture.coordinator.controller.state, .pressed, "cell.mouseDown（真视图入口）→ pressed")
        XCTAssertFalse(recognizer.isEnabled, "仲裁窗口内 Path A 被抑制（beginArbitration → suppressor(false)）")
        for t in stride(from: 0.25, through: 1.0, by: 0.25) {
            let p = NSPoint(x: aPoint.x + (bPoint.x - aPoint.x) * t,
                            y: aPoint.y + (bPoint.y - aPoint.y) * t)
            alphaCell.mouseDragged(with: pointerEvent(.leftMouseDragged, atWindowPoint: p, in: window))
        }
        XCTAssertEqual(fixture.coordinator.controller.state, .dragging, "过阈值 → dragging")
        alphaCell.mouseUp(with: pointerEvent(.leftMouseUp, atWindowPoint: bPoint, in: window))
        XCTAssertEqual(fixture.commits.count, 1, "真实 pointer 会话（非 onCommit seam 直呼）→ .committed")
        let committedLayout = try XCTUnwrap(fixture.commits.first, "commit 缺失，后续断言无意义")
        XCTAssertEqual(committedLayout.folders.count, 1)
        XCTAssertEqual(committedLayout.folders.first?.members, [ref("beta"), ref("alpha")],
                       "M3 成员序 = [target, source]（ADR-010）")
        // folder 占 target（beta）原 index = 1；alpha/beta 不再在顶层序。
        guard case .folder = committedLayout.topLevelOrder[1] else {
            return XCTFail("期望顶层 index 1 为 folder（target 原 index）")
        }
        XCTAssertFalse(committedLayout.topLevelOrder.contains(.app(ref("alpha"))))
        XCTAssertFalse(committedLayout.topLevelOrder.contains(.app(ref("beta"))))
        XCTAssertTrue(recognizer.isEnabled, "commit → endSession → Path A 恢复")

        // E2 核心：建夹后立点顶层 app——合成 NSEvent 经 cell.mouseDown（真视图入口）。
        // 真实会话建夹落位：folder 占 target（beta）原 index，成员 [beta, alpha] 出顶层
        // → 顶层条目序 = [delta, folder, echo, foxtrot, gamma]（动态定位，不硬编码 slot）。
        let entries = fixture.assembly.provider.presentationEntries
        let gammaID = CatalogFixture.appID("fixture.gamma")
        let gammaSlot = try XCTUnwrap(entries.firstIndex(where: { $0.identity == .app(gammaID) }))
        let folderSlot = try XCTUnwrap(entries.firstIndex(where: {
            if case .folder = $0.identity { return true }; return false
        }))
        let gammaCell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: gammaSlot))
        XCTAssertFalse(gammaCell.isFolderCell)
        XCTAssertEqual(gammaCell.bindingToken?.appID as? AppID, gammaID)
        let gPoint = windowPoint(of: gammaCell)
        let openedBefore = fixture.launcher.opened.count
        let dispatchBefore = ClickCensus.count(ClickCensus.Sink.dispatchClickCell)
        gammaCell.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: gPoint, in: window))
        gammaCell.mouseUp(with: pointerEvent(.leftMouseUp, atWindowPoint: gPoint, in: window))
        XCTAssertEqual(fixture.launcher.opened.count, openedBefore + 1, "建夹后顶层单击（真视图入口）→ 启动")
        XCTAssertEqual(fixture.launch.lastOutcome, .launched)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.dispatchClickCell), dispatchBefore + 1,
                       "Path B click 派发到达装配层（census）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.dragGateClosed), 0, "dragGate 未拦截（健康链）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.pendingBlankWithCell), 0, "无 N3 死路 A")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionResident), 0, "无抑制滞留（N1 健康链）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.pointerUpIdleSwallow), 0, "无 idle 吞点")
        XCTAssertTrue(recognizer.isEnabled, "单击会话完整 → Path A 恢复")

        // 连点 6 次（对齐用户取证）+ census 无滞留。
        for _ in 0..<6 {
            gammaCell.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: gPoint, in: window))
            gammaCell.mouseUp(with: pointerEvent(.leftMouseUp, atWindowPoint: gPoint, in: window))
        }
        XCTAssertEqual(fixture.launcher.opened.count, openedBefore + 7, "建夹后连点全部启动")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionResident), 0, "连点后仍无滞留")

        // folder cell 点击仍打开（Path B → handleCellClick → openFolder）。
        let folderCell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: folderSlot))
        XCTAssertTrue(folderCell.isFolderCell)
        let fPoint = windowPoint(of: folderCell)
        folderCell.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: fPoint, in: window))
        folderCell.mouseUp(with: pointerEvent(.leftMouseUp, atWindowPoint: fPoint, in: window))
        XCTAssertTrue(fixture.folderOpenState.isOpen, "folder cell 点击仍打开")
        fixture.closeFolder()
    }

    /// 窗口层分类 census（C′ 盲区①）：真 QuitOnBlankClickWindow.sendEvent + 真
    /// blankClickResolvesToCell 命中分类——cell 命中放行 super（s8d）、空白命中走
    /// terminate 通路（s8a + s8c，本地旗标观测）。AppKit 无头环境下 super.sendEvent
    /// 对 cell 的最终 mouseDown 路由不在断言范围（未建模层清单）。
    func testWindowSendEventClassifiesCellAndBlankWithCensus() async throws {
        // B1 转正（2026-09-06）后默认开；本测试验证窗口层分类 census → 显式关 B1
        // （B1 开时 cell down 手动投递会激活 drag 会话，空白点击被 drag 守卫吞掉，偏离本测试意图）。
        XCTAssertEqual(setenv("PAGING_CLICK_MANUAL_DELIVERY", "0", 1), 0, "测试 env 设置")
        defer { unsetenv("PAGING_CLICK_MANUAL_DELIVERY") }
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let (window, container, termination) = try mountInQuitWindow(fixture)

        // cell 命中：blankClickResolvesToCell true → 放行 super（s8d 计数）。
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let point = windowPoint(of: cell)
        let containerPoint = container.convert(point, from: nil)
        XCTAssertTrue(blankClickResolvesToCell(container.hitTest(containerPoint)),
                      "真分类：cell 命中链含 AppGridCellView")
        window.sendEvent(pointerEvent(.leftMouseDown, atWindowPoint: point, in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowCellPassthrough), 1, "cell 命中放行（census）")
        XCTAssertFalse(termination.terminated, "cell 命中不触发空白退出")

        // 空白命中（surface 本体非 cell）→ s8a + terminate 通路（s8c）。
        let blankPoint = container.convert(NSPoint(x: 500, y: 60), from: nil)
        XCTAssertFalse(blankClickResolvesToCell(container.hitTest(blankPoint)), "空白分类")
        window.sendEvent(pointerEvent(.leftMouseDown, atWindowPoint: NSPoint(x: 500, y: 60), in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowBlankUnclassified), 1, "空白命中（census）")
        XCTAssertTrue(termination.terminated, "空白 + 搜索未激活 → onBlankClick（生产 = NSApp.terminate）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowBlankTerminate), 1, "terminate 通路（census）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowDragActiveSwallow), 0, "无 drag 激活（不吞）")
    }

    /// 窗口层 drag 激活守卫（T-1F-B7-wave-c 收窄回归 + census）：会话活跃时空白 mouseDown →
    /// onDragActiveCancel → cancel(.escape) → 吞点（不退出）。
    func testWindowSwallowsBlankClickWhileSessionActiveWithCensus() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let (window, _, termination) = try mountInQuitWindow(fixture)
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let point = windowPoint(of: cell)
        cell.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: point, in: window))
        XCTAssertTrue(fixture.coordinator.isSessionActive, "会话活跃（.pressed）")
        window.sendEvent(pointerEvent(.leftMouseDown, atWindowPoint: NSPoint(x: 500, y: 60), in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowBlankUnclassified), 1)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.windowDragActiveSwallow), 1, "drag 激活吞点（census）")
        XCTAssertFalse(termination.terminated, "吞点：不走 terminate")
        XCTAssertFalse(fixture.coordinator.isSessionActive, "cancel(.escape) → endSession 清理")
        XCTAssertTrue(surfaceLaunchRecognizer(fixture.surface)?.isEnabled ?? false, "抑制已恢复")
    }

    /// N3 修复验证（T-1F-B8-wave-c Stage 2 预授权）：tokenless cell 交错按下不再当空白
    ///（原死路 A）→ 武装 fallback（s4c）→ pointerUp 走 fallback 分支既有派发
    ///（s4f + endSession 先清后派发）→ 抑制恢复、无滞留；blank 分支不参与（s4d == 0）。
    /// 依据：census s4b/s4c/s4f/s4d + harness 测试 4 原滞留形态（Stage 1 复现）。
    func testTokenlessCellInterleaveArmsFallbackAndEndsSessionN3Fix() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let recognizer = try XCTUnwrap(surfaceLaunchRecognizer(fixture.surface))
        var blankClicks = 0
        fixture.coordinator.onOverlayBlankClick = { blankClicks += 1 }   // 隔离 closeFolder 补偿
        let (window, _, _) = try mountInQuitWindow(fixture)

        // 1) 活会话（.pressed → 抑制 ON）。
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let point = windowPoint(of: cell)
        cell.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: point, in: window))
        XCTAssertEqual(fixture.coordinator.controller.state, .pressed)
        XCTAssertFalse(recognizer.isEnabled)

        // 2) 无 up：无 binding cell 的 pointerDown → N3：武装 fallback（s4c），不再 arm 空白候选。
        let tokenlessCell = AppGridCellView(frame: NSRect(x: 0, y: 0, width: 60, height: 60))
        XCTAssertNil(tokenlessCell.bindingToken)
        fixture.coordinator.pointerDown(locationInWindow: point, sourceCell: tokenlessCell, memberFolderID: nil)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.pendingBlankWithCell), 1, "N3 观测：有 cell 按下解析失败（census）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.fallbackArmed), 1, "N3：归位为 fallback 武装")
        XCTAssertEqual(fixture.coordinator.controller.state, .pressed, "controller 仍持有旧会话")

        // 3) pointerUp → fallback 分支既有派发（s4f）→ endSession 恢复抑制；blank 分支不参与。
        cell.mouseUp(with: pointerEvent(.leftMouseUp, atWindowPoint: point, in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.fallbackDispatch), 1, "fallback 派发（census）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.blankBranchDispatch), 0, "N3：不再走 blank 分支")
        XCTAssertEqual(blankClicks, 0, "无空白派发")
        XCTAssertTrue(recognizer.isEnabled, "endSession 恢复抑制（N3 归位后无滞留）")
        XCTAssertEqual(fixture.launcher.opened.count, 0, "tokenless → handleCellClick 静默（S6 面）")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionResident), 0, "N1/N3 修复：无抑制滞留形成")

        // 4) 自愈确认：下一次有效 pointerDown（secondDrag 重建会话）→ click 正常派发启动。
        cell.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: point, in: window))
        cell.mouseUp(with: pointerEvent(.leftMouseUp, atWindowPoint: point, in: window))
        XCTAssertFalse(fixture.coordinator.isSessionActive, "secondDrag 重建会话 → .clicked → endSession")
        XCTAssertTrue(recognizer.isEnabled)
        XCTAssertEqual(fixture.launch.lastOutcome, .launched)
    }

    /// N1 修复验证（T-1F-B8-wave-c Stage 2 预授权）：真空白交错（sourceCell == nil）在
    /// 抑制 ON 时走 blank 分支 → s4e 观测后 endSession 立即自愈——不再依赖 closeFolder
    /// 的 cancel(.overlayClosed) 代偿面（onOverlayBlankClick 置空隔离）→ 识别器恢复、
    /// 无滞留（s9_leak == 0）。依据：harness 测试 4/5 + census s4e/s9b/s9_leak。
    func testBlankBranchEndsSessionWhileSuppressedN1Fix() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let recognizer = try XCTUnwrap(surfaceLaunchRecognizer(fixture.surface))
        var blankClicks = 0
        fixture.coordinator.onOverlayBlankClick = { blankClicks += 1 }   // 隔离 closeFolder 补偿
        let (window, _, _) = try mountInQuitWindow(fixture)

        // 1) 活会话（.pressed → 抑制 ON）。
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let point = windowPoint(of: cell)
        cell.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: point, in: window))
        XCTAssertEqual(fixture.coordinator.controller.state, .pressed)
        XCTAssertFalse(recognizer.isEnabled)

        // 2) 无 up：stale secondDrag（布局换代不含 alpha）→ controller 归 idle + 保持仲裁
        //    → 抑制仍 ON 的纯滞留态（fallback 武装，s4c）。
        fixture.sessionLayout = PersistentWorkspaceLayout(
            generation: LayoutGeneration(9),
            topLevelOrder: [.app(ref("gamma")), .app(ref("delta")), .app(ref("echo")),
                            .app(ref("foxtrot"))],
            folders: [])
        cell.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: point, in: window))
        XCTAssertEqual(fixture.coordinator.controller.state, .idle, "stale secondDrag → controller 归 idle")
        XCTAssertFalse(recognizer.isEnabled, "secondDrag 后抑制仍 true（纯滞留态）")

        // 3) 真空白按下（sourceCell == nil）→ pendingBlank 武装（s4a；N3 保留真空白语义）。
        let blankPoint = NSPoint(x: 500, y: 60)
        fixture.coordinator.pointerDown(locationInWindow: blankPoint, sourceCell: nil, memberFolderID: nil)
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.pendingBlankNoCell), 1, "真空白候选（census）")
        XCTAssertTrue(fixture.coordinator.isSessionActive, "空白候选在仲裁")

        // 4) pointerUp → blank 分支：s4d + s4e（抑制仍 true 的观测）→ endSession（N1）→ 派发。
        fixture.coordinator.pointerUp(locationInWindow: blankPoint)
        XCTAssertEqual(blankClicks, 1, "blank 分支派发 onOverlayBlankClick")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.blankBranchWhileSuppressed), 1, "s4e 观测（保留）")
        XCTAssertTrue(recognizer.isEnabled, "N1：blank 分支自身 endSession 恢复抑制（Path A 复活）")
        XCTAssertFalse(fixture.coordinator.isSessionActive, "endSession 清理空白候选")

        // 5) 下一次 pointerDown → 无新滞留（step 3 入口的 s9_leak 是 secondDrag 滞留态的
        //    合法观测、已被 step 4 的 endSession 愈合；修复前 blank 分支滞留会再次计数）。
        let residentBefore = ClickCensus.count(ClickCensus.Sink.suppressionResident)
        cell.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: point, in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionResident), residentBefore,
                       "N1 修复：blank 分支 endSession 后无新滞留形成")
        cell.mouseUp(with: pointerEvent(.leftMouseUp, atWindowPoint: point, in: window))
        XCTAssertEqual(fixture.launch.lastOutcome, .launched, "点击回归：启动正常")
        XCTAssertTrue(recognizer.isEnabled)
    }

    /// 抑制滞留观测面（T-1F-B8-wave-c census s9）：stale-source secondDrag「保持仲裁」
    /// 后 controller 归 idle 但抑制仍 true —— 下一次 pointerDown 入口 s9_leak 计数；
    /// 随后 fallback 分支 endSession 自愈（Defect-3 路径健康形态）。
    func testSuppressionResidencyObservedAtNextPointerDownAfterStaleSecondDrag() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let recognizer = try XCTUnwrap(surfaceLaunchRecognizer(fixture.surface))
        let (window, _, _) = try mountInQuitWindow(fixture)

        // 1) 会话活跃（.pressed → 抑制 ON）。
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let point = windowPoint(of: cell)
        cell.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: point, in: window))
        XCTAssertEqual(fixture.coordinator.controller.state, .pressed)

        // 2) 无 up：sourceCell 合法但布局已不含该 app（stale source）→ controller
        //    The controller returns idle, but the stale click fallback still owns the
        //    physical pointer. Suppression is legitimate until the release boundary.
        fixture.sessionLayout = PersistentWorkspaceLayout(
            generation: LayoutGeneration(9),
            topLevelOrder: [.app(ref("gamma")), .app(ref("delta")), .app(ref("echo")),
                            .app(ref("foxtrot"))],
            folders: [])
        cell.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: point, in: window))
        XCTAssertEqual(fixture.coordinator.controller.state, .idle, "stale secondDrag → controller 归 idle")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.fallbackArmed), 1, "stale source 回退武装（census）")
        XCTAssertTrue(fixture.coordinator.isSessionActive,
                      "An idle controller's fallback still owns the physical pointer until release")

        // 3) A replacing down is not ownerless suppression residency while input is held.
        cell.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: point, in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionResident), 0,
                       "Held fallback arbitration is not ownerless suppression residency")
        XCTAssertFalse(recognizer.isEnabled, "滞留窗口内 Path A 仍死")

        // 4) pointerUp → fallback 分支 endSession 自愈 + click 回退派发（Defect-3 健康形态）。
        cell.mouseUp(with: pointerEvent(.leftMouseUp, atWindowPoint: point, in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.fallbackDispatch), 1, "fallback 派发（census）")
        XCTAssertTrue(recognizer.isEnabled, "endSession 恢复抑制")
        XCTAssertEqual(fixture.launch.lastOutcome, .launched, "stale-source 点击回退派发仍启动")
    }

    /// N2 面取证（T-1F-B8-wave-c）：dragGate 关闭时 pointerDown 静默拒绝——
    /// 注释称「点击不受影响」，实现连 Path B click 一并拒绝（census s1 计数点）。
    /// Path A（surface 识别器）不受影响 → 仍可启动（对照形态）。
    func testDragGateClosedSilentlyRejectsPointerDownWithCensus() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let recognizer = try XCTUnwrap(surfaceLaunchRecognizer(fixture.surface))
        let (window, _, _) = try mountInQuitWindow(fixture)
        fixture.isTitleEditing = true
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let point = windowPoint(of: cell)
        cell.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: point, in: window))
        cell.mouseUp(with: pointerEvent(.leftMouseUp, atWindowPoint: point, in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.dragGateClosed), 1, "dragGate 静默拒绝（census s1）")
        XCTAssertEqual(fixture.coordinator.controller.state, .idle, "未进入会话")
        XCTAssertEqual(fixture.launcher.opened.count, 0, "Path B 静默丢失")
        XCTAssertTrue(recognizer.isEnabled, "抑制未启动 → Path A 仍活（对照；双通路齐灭需叠加其它面）")
        fixture.isTitleEditing = false
    }

    // MARK: - 5) T-1F-B9-wave-b Stage 1：s8e 窗口 key 态 + s13 抑制可见性（零行为变更）

    /// s8e（T-1F-B9-wave-b Stage 1）：key / 非 key 两种夹具窗口下每次 leftMouseDown 均
    /// 计数一次，key 状态位随事件实测写入 sink 名。
    /// 环境注记（results §3 探针证据）：本仓 `swift test` 沙箱可 orderFront（isVisible true）
    /// 但 key/active 授权被平台拒绝——`activate()`/`makeKey()` 后 `isKeyWindow`/`isActive`
    /// 恒 false。故 key0 腿为硬断言；key 夹具腿真实执行 sendEvent 并断言计数（s8e 计数与
    /// key 状态无关，这正是本装置契约）；key1 翻转断言在环境授予 key 时执行，沙箱内由
    /// 变体名编码测试覆盖，实机 key1 读数由 Main E 序列回填 census 表。
    func testWindowKeyStateCensusCountsInKeyAndNonKeyFixtures() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let (window, _, _) = try mountInQuitWindow(fixture)
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let point = windowPoint(of: cell)

        // 非 key 夹具：未 makeKey → isKeyWindow == false → key0 变体计数（硬断言）。
        XCTAssertFalse(window.isKeyWindow, "夹具前提：窗口未成 key")
        window.sendEvent(pointerEvent(.leftMouseDown, atWindowPoint: point, in: window))
        XCTAssertEqual(
            ClickCensus.count(ClickCensus.Sink.windowKeyState(isKeyWindow: false, appActive: NSApp.isActive)),
            1, "非 key 窗口 leftMouseDown → s8e 计数一次（active 位为实测值）")
        XCTAssertEqual(
            ClickCensus.count(ClickCensus.Sink.windowKeyState(isKeyWindow: true, appActive: true))
                + ClickCensus.count(ClickCensus.Sink.windowKeyState(isKeyWindow: true, appActive: false)),
            0, "非 key 夹具不产生 key1 变体")

        // key 夹具：激活 app + makeKeyAndOrderFront（仅测试夹具需要；不改任何生产行为）。
        _ = NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.sendEvent(pointerEvent(.leftMouseDown, atWindowPoint: point, in: window))
        if window.isKeyWindow {
            // 环境授予 key：key 状态位实测翻转（key1 变体）。
            XCTAssertEqual(
                ClickCensus.count(ClickCensus.Sink.windowKeyState(isKeyWindow: true, appActive: NSApp.isActive)),
                1, "key 窗口 leftMouseDown → s8e 计数一次（key 位实测翻转）")
        } else {
            // 沙箱 key 授权被拒（探针：orderFront 可见、makeKey/activate 恒拒）：
            // s8e 计数不依赖 key 状态——本事件仍必须恰好再计数一次。
            let s8eTotal = ClickCensus.snapshot()
                .filter { $0.key.hasPrefix(ClickCensus.Sink.windowKeyStateBase) }
                .values.reduce(0, +)
            XCTAssertEqual(s8eTotal, 2, "key 夹具（授权被拒仍非 key）leftMouseDown → s8e 再计数一次")
        }
        // 两次 leftMouseDown 合计恰好 2 条 s8e（基名前缀聚合；active 位随 NSApp 实测可能跨变体）。
        let s8eTotal = ClickCensus.snapshot()
            .filter { $0.key.hasPrefix(ClickCensus.Sink.windowKeyStateBase) }
            .values.reduce(0, +)
        XCTAssertEqual(s8eTotal, 2, "两次 leftMouseDown → s8e 各计数一次")
    }

    /// s8e 状态位编码（快照契约）：两 bool → 四个互异 sink 名，key/active 位逐位可辨；
    /// 变体名只含状态位（无窗口标题/无坐标/无应用名，隐私 A/B/C）。
    func testWindowKeyStateCensusVariantNamesCarryKeyAndActiveBits() {
        XCTAssertEqual(ClickCensus.Sink.windowKeyState(isKeyWindow: true, appActive: true),
                       "s8e_window_key_state_key1_active1")
        XCTAssertEqual(ClickCensus.Sink.windowKeyState(isKeyWindow: true, appActive: false),
                       "s8e_window_key_state_key1_active0")
        XCTAssertEqual(ClickCensus.Sink.windowKeyState(isKeyWindow: false, appActive: true),
                       "s8e_window_key_state_key0_active1")
        XCTAssertEqual(ClickCensus.Sink.windowKeyState(isKeyWindow: false, appActive: false),
                       "s8e_window_key_state_key0_active0")
        let names = [true, false].flatMap { key in
            [true, false].map { ClickCensus.Sink.windowKeyState(isKeyWindow: key, appActive: $0) }
        }
        XCTAssertEqual(Set(names).count, 4, "四变体互异（快照键无碰撞）")
    }

    /// s13（T-1F-B9-wave-b Stage 1）：抑制闭包两向 census 与抑制状态联动一致——
    /// pointerDown（beginArbitration → suppressor(false)）→ s13a_enable +1 且 Path A 识别器禁用；
    /// pointerUp（endSession → suppressor(true)）→ s13b_disable +1 且识别器恢复。
    /// 与既有抑制链路测试（s9/s4c/s4f/endSessionRestored）共用同一 fixture 生产同构闭包。
    func testSuppressionToggleCensusMatchesRecognizerTransitions() async throws {
        let fixture = try await makeFixture()
        defer {
            DragUISessionCoordinator.shared = nil
            fixture.coordinator.teardown()
            fixture.assembly.teardown()
            fixture.surface.teardown()
        }
        let recognizer = try XCTUnwrap(surfaceLaunchRecognizer(fixture.surface))
        let (window, _, _) = try mountInQuitWindow(fixture)
        let cell = try XCTUnwrap(fixture.assembly.renderer.pageView(forPage: 0)?.cell(at: 0))
        let point = windowPoint(of: cell)

        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionEnable), 0, "前置：无启用向计数")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionDisable), 0, "前置：无恢复向计数")

        // 会话开启 → 抑制启用向（s13a）+1，识别器禁用（与既有抑制断言同语义）。
        cell.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: point, in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionEnable), 1, "抑制启用向计数")
        XCTAssertFalse(recognizer.isEnabled, "抑制 ON（Path A 识别器禁用）")

        // 会话完整结束（单击 .clicked → endSession）→ 抑制恢复向（s13b）+1，识别器恢复。
        cell.mouseUp(with: pointerEvent(.leftMouseUp, atWindowPoint: point, in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionDisable), 1, "抑制恢复向计数")
        XCTAssertTrue(recognizer.isEnabled, "抑制恢复（Path A 识别器可用）")

        // 第二个会话周期：单会话 toggle 序列恰为 beginArbitration 一次 false + endSession
        // 一次 true（与既有抑制测试的 census 语义一致）→ 两向各再 +1，且与 s9b 联动等值。
        cell.mouseDown(with: pointerEvent(.leftMouseDown, atWindowPoint: point, in: window))
        cell.mouseUp(with: pointerEvent(.leftMouseUp, atWindowPoint: point, in: window))
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionEnable), 2, "第二会话启用向再 +1")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionDisable), 2, "第二会话恢复向再 +1")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.endSessionRestored), 2,
                       "s13b 与 s9b_endsession_restored 联动等值")
        XCTAssertEqual(ClickCensus.count(ClickCensus.Sink.suppressionResident), 0, "无抑制滞留（健康链）")
    }
}
