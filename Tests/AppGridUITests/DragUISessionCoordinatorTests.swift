// AppGridUITests — DragUISessionCoordinatorTests（T-1F-D1 测试）
// 覆盖 coordinator（D 层薄壳）仲裁矩阵（§10.1 drag UI 部分）：
// 1) click vs drag 阈值仲裁（onCellClick 单次派发 / drag 绝不派发 click）
// 2) 几何构建（cell frame → DragItemFrame；host 坐标系）
// 3) move-out 状态机（folder scope；moveOutArmed → topLevelTarget → commit）
// 4) 统一 cancel 全路径（每个 DragCancelReason → idle + 零残留）
// 5) commit seam 调用 + 会话复位
// 6) edge turn 入口选择（topLevel → topLevelPageTurn spy；folder → folderPageTurn spy）
// 7) click 识别抑制生命周期（仲裁窗口内 false / 结束后 true）
// 8) 空白按下仲裁（overlay 面板外；未过阈值 → onOverlayBlankClick）
// 9) drag 门（搜索/标题编辑 → 禁拖）
// 10) second drag（旧 session 失效 + 抑制保持）
// 11) teardown 零残留
// 12) BUG6 Wave C：fallback 路径抑制泄漏堵漏（suppressor 直接断言 + 20 次配平）
// 全部经 DragSessionTestSupport 工厂；fixture 标题为合成数据（无真实 app 身份）。

import AppCatalogCore
import AppIconPipeline
import AppKit
import Foundation
import PagingUI
import XCTest
@testable import AppGridUI

@MainActor
final class DragUISessionCoordinatorTests: XCTestCase {

    /// host 强引用（visualHost/visuals.host 均为 weak；测试期间必须存活）。
    private var retainedHost: NSView?

    override func tearDown() {
        retainedHost = nil
        super.tearDown()
    }

    // MARK: - 工厂

    /// 小阈值参数（与 DragSessionControllerTests 同构）：阈值 6pt、dwell 100ms、边缘 40pt。
    private func makeParameters() -> DragParameters {
        DragParameters(dragStartThresholdPT: 6,
                       edgeDwellDurationMs: 100,
                       edgeZoneWidthPT: 40,
                       edgeHysteresisPT: 10,
                       dropZoneMarginsPT: 8,
                       overlayMoveOutArmThresholdPT: 24,
                       edgeTurnMinIntervalMs: 200,
                       maxDragPreviewScale: 1.0)
    }

    private func makeHost() -> NSView {
        NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
    }

    private func makeCoordinator(clock: FakeDragClock = FakeDragClock(0),
                                 host: NSView? = nil) -> DragUISessionCoordinator {
        let host = host ?? makeHost()
        retainedHost = host
        return DragUISessionCoordinator(host: host,
                                        parameters: makeParameters(),
                                        clock: clock)
    }

    private func makeTwoAppLayout() -> (layout: PersistentWorkspaceLayout, catalog: CatalogSnapshot) {
        makeDragLayout(titles: ["app1", "app2"])
    }

    private func twoAppGeometry(page: Int = 0, pageCount: Int = 1) -> DragGeometry {
        topLevelGeometry(frames: rowFrames([.app(ref("app1")), .app(ref("app2"))]),
                         containerWidth: 400, page: page, pageCount: pageCount)
    }

    /// 绑定 app cell（token.appID = fixture AppID；与 makeDragLayout catalog 同源）。
    private func makeAppCell(_ title: String) -> AppGridCellView {
        let cell = AppGridCellView(frame: NSRect(x: 0, y: 0, width: 80, height: 80))
        cell.bind(name: title, token: ItemBindingToken(
            catalogRevision: 1,
            pageIdentity: PagePresentationID(revision: 1, pageIndex: 0),
            itemSlot: 0,
            appID: AnyHashable(makeAppID("fixture.\(title.lowercased())")),
            reuseGeneration: 0,
            iconKey: nil,
            surfaceGeneration: 0))
        return cell
    }

    /// 绑定 folder cell（token.appID = FolderID）。
    private func makeFolderCell(_ folderID: FolderID, title: String = "Group 1") -> AppGridCellView {
        let cell = AppGridCellView(frame: NSRect(x: 0, y: 0, width: 80, height: 80))
        cell.bindFolder(title: title, memberCount: 2, token: ItemBindingToken(
            catalogRevision: 1,
            pageIdentity: PagePresentationID(revision: 1, pageIndex: 0),
            itemSlot: 0,
            appID: AnyHashable(folderID),
            reuseGeneration: 0,
            iconKey: nil,
            surfaceGeneration: 0))
        return cell
    }

    /// 单 folder 布局（成员 app1/app2；顶层 [folder]）。
    private func makeFolderLayout(folderID: FolderID)
        -> (layout: PersistentWorkspaceLayout, catalog: CatalogSnapshot) {
        let (_, catalog) = makeTwoAppLayout()
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.folder(folderID)],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1",
                                             members: [ref("app1"), ref("app2")])])
        return (layout, catalog)
    }

    private func folderScopeGeometry(folderID: FolderID, page: Int = 0, pageCount: Int = 2) -> DragGeometry {
        // 成员行 y=200，顶层 folder cell 在 y=0：move-out 落点与成员行带分离。
        let members = [
            DragItemFrame(identity: .app(ref("app1")), frame: DragRect(x: 0, y: 200, width: 80, height: 80)),
            DragItemFrame(identity: .app(ref("app2")), frame: DragRect(x: 100, y: 200, width: 80, height: 80)),
        ]
        return folderGeometry(memberFrames: members,
                              topLevelFrames: [folderFrame(folderID, x: 0)],
                              containerWidth: 400, page: page, pageCount: pageCount)
    }

    // MARK: - 1) click vs drag 阈值仲裁

    func testClickBelowThresholdDispatchesCellClickOnce() {
        let coordinator = makeCoordinator()
        let (layout, catalog) = makeTwoAppLayout()
        let cell = makeAppCell("app1")
        var clicks: [AppGridCellView] = []
        var commits = 0
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in self.twoAppGeometry() }
        coordinator.onCellClick = { clicks.append($0) }
        coordinator.onCommit = { _ in commits += 1 }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        XCTAssertEqual(coordinator.controller.state, .pressed)
        XCTAssertTrue(coordinator.isSessionActive)

        coordinator.pointerUp(locationInWindow: NSPoint(x: 40, y: 40))
        XCTAssertEqual(clicks.count, 1, "click 只派发一次")
        XCTAssertTrue(clicks[0] === cell, "click 派发源 cell")
        XCTAssertEqual(commits, 0, "click 不产生 commit")
        XCTAssertEqual(coordinator.controller.state, .idle)
        XCTAssertFalse(coordinator.isSessionActive)
    }

    func testSubThresholdMoveStaysPressedThenClick() {
        let coordinator = makeCoordinator()
        let (layout, catalog) = makeTwoAppLayout()
        let cell = makeAppCell("app1")
        var clicks = 0
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in self.twoAppGeometry() }
        coordinator.onCellClick = { _ in clicks += 1 }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        // 位移 3pt < 阈值 6pt：仍 pressed，无 preview。
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 43, y: 40))
        XCTAssertEqual(coordinator.controller.state, .pressed)
        XCTAssertFalse(coordinator.visuals.isPreviewVisible)

        coordinator.pointerUp(locationInWindow: NSPoint(x: 43, y: 40))
        XCTAssertEqual(clicks, 1)
        XCTAssertEqual(coordinator.controller.state, .idle)
    }

    func testDragBeyondThresholdNeverDispatchesClick() {
        let coordinator = makeCoordinator()
        let (layout, catalog) = makeTwoAppLayout()
        let cell = makeAppCell("app1")
        var clicks = 0
        var commits: [PersistentWorkspaceLayout] = []
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in self.twoAppGeometry() }
        coordinator.onCellClick = { _ in clicks += 1 }
        coordinator.onCommit = { commits.append($0) }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 50, y: 40))   // 过阈值 → dragBegan
        XCTAssertEqual(coordinator.controller.state, .dragging)
        XCTAssertTrue(coordinator.visuals.isPreviewVisible, "drag 中显示中性 preview")

        coordinator.pointerDragged(locationInWindow: NSPoint(x: 155, y: 40))   // BUG6: app2 右半区 → insertion(2) → commit
        coordinator.pointerUp(locationInWindow: NSPoint(x: 155, y: 40))
        XCTAssertEqual(clicks, 0, "drag 绝不派发 click")
        XCTAssertEqual(commits.count, 1, "合法 drop → commit seam 一次")
        XCTAssertEqual(commits[0].topLevelOrder, [.app(ref("app2")), .app(ref("app1"))])
        XCTAssertEqual(coordinator.controller.state, .idle)
        XCTAssertFalse(coordinator.visuals.isPreviewVisible, "会话结束清 preview")
    }

    // MARK: - 2) 几何构建（cell frame → DragItemFrame）

    func testGeometryBuildingCellFramesToDragItemFrames() {
        let loader = GatedIconLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())
        defer { pipeline.shutdown() }
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
        let page = AppGridPageView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
        page.frame = host.bounds
        host.addSubview(page)
        let alphaID = makeAppID("fixture.alpha")
        let betaID = makeAppID("fixture.beta")
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0,
                                         titles: ["Alpha", "Beta"],
                                         appIDs: [alphaID, betaID]),
                    pageCount: 3, reuseGeneration: 1)
        page.layout()

        let catalog = try! makeSnapshot(titles: ["Alpha", "Beta"], revision: 1)
        let frames = page.dragItemFrames(convertedTo: host, catalog: catalog)
        XCTAssertEqual(frames.count, 2)
        XCTAssertEqual(frames[0].identity, .app(ref("alpha")))
        XCTAssertEqual(frames[1].identity, .app(ref("beta")))

        // host 坐标系：与 cell.convert(cell.bounds, to: host) 一致。
        let cell0 = page.cell(at: 0)!
        let expected = cell0.convert(cell0.bounds, to: host)
        XCTAssertEqual(frames[0].frame,
                       DragRect(x: Double(expected.minX), y: Double(expected.minY),
                                width: Double(expected.width), height: Double(expected.height)))

        // drop 目标 hit-test：页坐标系内命中 cell。
        let mid = NSPoint(x: cell0.frame.midX, y: cell0.frame.midY)
        XCTAssertTrue(page.cell(at: mid) === cell0)
        XCTAssertNil(page.cell(at: NSPoint(x: 9999, y: 9999)))
    }

    // MARK: - 3) move-out 状态机（folder scope）

    func testMoveOutArmsAndCommitsTopLevelTarget() {
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let coordinator = makeCoordinator()
        let (layout, catalog) = makeFolderLayout(folderID: folderID)
        let memberCell = makeAppCell("app1")
        var commits: [PersistentWorkspaceLayout] = []
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in self.folderScopeGeometry(folderID: folderID) }
        coordinator.onCommit = { commits.append($0) }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40),
                                sourceCell: memberCell, memberFolderID: folderID)
        XCTAssertEqual(coordinator.controller.state, .pressed)

        // 位移 30pt ≥ overlayMoveOutArmThresholdPT 24 → moveOutArmed。
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 70, y: 40))
        XCTAssertEqual(coordinator.controller.state, .dragging)
        XCTAssertTrue(coordinator.controller.moveOutArmed, "move-out 显式 arm")

        // 拖到顶层落点（x=200 在顶层 landing zone index 1）→ topLevelTarget → commit。
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 200, y: 40))
        coordinator.pointerUp(locationInWindow: NSPoint(x: 200, y: 40))
        XCTAssertEqual(commits.count, 1, "move-out 合法落点 → commit")
        XCTAssertTrue(commits[0].topLevelOrder.contains(.app(ref("app1"))), "成员移出到顶层")
        XCTAssertEqual(coordinator.controller.state, .idle)
    }

    // MARK: - 4) 统一 cancel 全路径

    func testCancelAllReasonsLeaveNoResidue() {
        for reason in DragCancelReason.allCases {
            let coordinator = makeCoordinator()
            let (layout, catalog) = makeTwoAppLayout()
            let cell = makeAppCell("app1")
            var suppression: [Bool] = []
            coordinator.layoutProvider = { layout }
            coordinator.catalogGenerationProvider = { 1 }
            coordinator.catalogSnapshotProvider = { catalog }
            coordinator.geometryProvider = { _ in self.twoAppGeometry() }
            coordinator.clickRecognitionSuppressor = { suppression.append($0) }

            coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
            coordinator.pointerDragged(locationInWindow: NSPoint(x: 50, y: 40))
            XCTAssertEqual(coordinator.controller.state, .dragging)
            XCTAssertTrue(coordinator.visuals.isPreviewVisible)

            coordinator.cancel(reason: reason)
            XCTAssertEqual(coordinator.controller.state, .idle, "cancel(\(reason)) → idle")
            XCTAssertNil(coordinator.controller.activeTransaction)
            XCTAssertFalse(coordinator.isSessionActive)
            XCTAssertFalse(coordinator.visuals.isPreviewVisible, "cancel(\(reason)) 清 preview")
            XCTAssertEqual(suppression.last, true, "cancel(\(reason)) 恢复 click 识别")
            // 残留防御：cancel 后 edgeTimerFired 是 no-op（无 dwell 残留）。
            coordinator.edgeTimerFired()
            XCTAssertEqual(coordinator.controller.state, .idle)
        }
    }

    // MARK: - 5) commit seam 调用 + 会话复位

    func testCommitSeamReceivesNewLayoutAndSessionResets() {
        let coordinator = makeCoordinator()
        let (layout, catalog) = makeTwoAppLayout()
        let cell = makeAppCell("app1")
        var commits: [PersistentWorkspaceLayout] = []
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in self.twoAppGeometry() }
        coordinator.onCommit = { commits.append($0) }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 50, y: 40))
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 155, y: 40))
        coordinator.pointerUp(locationInWindow: NSPoint(x: 155, y: 40))
        XCTAssertEqual(commits.count, 1)
        XCTAssertEqual(commits[0].generation, LayoutGeneration(1), "commit 布局 generation +1")
        XCTAssertEqual(coordinator.controller.state, .idle)

        // 会话复位：第二次 drag 从零开始（新 commit）。
        coordinator.pointerDown(locationInWindow: NSPoint(x: 140, y: 40), sourceCell: cell, memberFolderID: nil)
        XCTAssertEqual(coordinator.controller.state, .pressed)
        coordinator.pointerUp(locationInWindow: NSPoint(x: 140, y: 40))
        XCTAssertEqual(coordinator.controller.state, .idle)
        XCTAssertEqual(commits.count, 1, "click 不产生新 commit")
    }

    // MARK: - 6) edge turn 入口选择

    func testEdgeTurnTopLevelUsesKeyboardPageTurnerSeam() {
        let clock = FakeDragClock(0)
        let coordinator = makeCoordinator(clock: clock)
        let (layout, catalog) = makeTwoAppLayout()
        let cell = makeAppCell("app1")
        var turns: [(KeyboardPageDirection, TimeInterval)] = []
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in self.twoAppGeometry(page: 1, pageCount: 3) }
        coordinator.topLevelPageTurn = { direction, timestamp in
            turns.append((direction, timestamp))
            return .turned(1)
        }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 50, y: 40))
        // 拖入右缘（page 1/3 非末页）→ dwell 武装。
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 390, y: 40))
        XCTAssertEqual(coordinator.controller.state, .edgeTurnPending)
        XCTAssertEqual(coordinator.controller.edgeDwellDeadline, 0.1)

        clock.current = 0.2
        coordinator.edgeTimerFired()
        XCTAssertEqual(turns.count, 1, "topLevel scope → KeyboardPageTurner seam")
        XCTAssertEqual(turns[0].0, .next, "右缘 → 下一页")
        XCTAssertEqual(coordinator.controller.state, .edgeTurnPending, "dwell 保持武装（连续翻页）")
        coordinator.cancel(reason: .escape)
    }

    func testEdgeTurnFolderUsesOverlayPageTurnSeam() {
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let clock = FakeDragClock(0)
        let coordinator = makeCoordinator(clock: clock)
        let (layout, catalog) = makeFolderLayout(folderID: folderID)
        let memberCell = makeAppCell("app1")
        var folderTurns: [Int] = []
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in self.folderScopeGeometry(folderID: folderID) }
        coordinator.folderPageTurn = { folderTurns.append($0) }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40),
                                sourceCell: memberCell, memberFolderID: folderID)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 50, y: 40))
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 390, y: 40))
        XCTAssertEqual(coordinator.controller.state, .edgeTurnPending)

        clock.current = 0.2
        coordinator.edgeTimerFired()
        XCTAssertEqual(folderTurns, [1], "folder scope → overlay 翻页 seam（右缘 +1）")
        coordinator.cancel(reason: .escape)
    }

    // MARK: - 7) click 识别抑制生命周期

    func testClickRecognitionSuppressionLifecycle() {
        let coordinator = makeCoordinator()
        let (layout, catalog) = makeTwoAppLayout()
        let cell = makeAppCell("app1")
        var suppression: [Bool] = []
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in self.twoAppGeometry() }
        coordinator.clickRecognitionSuppressor = { suppression.append($0) }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        XCTAssertEqual(suppression, [false], "仲裁窗口内禁用 surface click 识别")

        coordinator.pointerUp(locationInWindow: NSPoint(x: 40, y: 40))
        XCTAssertEqual(suppression, [false, true], "会话结束恢复 click 识别")
    }

    // MARK: - 8) 空白按下仲裁（overlay 面板外）

    func testBlankPressBelowThresholdDispatchesOverlayBlankClick() {
        let coordinator = makeCoordinator()
        var blankClicks = 0
        coordinator.onOverlayBlankClick = { blankClicks += 1 }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 200, y: 200), sourceCell: nil, memberFolderID: nil)
        XCTAssertTrue(coordinator.isSessionActive, "空白按下进入仲裁")
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 203, y: 200))   // 3pt < 阈值
        coordinator.pointerUp(locationInWindow: NSPoint(x: 203, y: 200))
        XCTAssertEqual(blankClicks, 1, "未过阈值 → 空白点击（关闭 folder）")
        XCTAssertFalse(coordinator.isSessionActive)
    }

    func testBlankPressBeyondThresholdCancelsBlankClick() {
        let coordinator = makeCoordinator()
        var blankClicks = 0
        coordinator.onOverlayBlankClick = { blankClicks += 1 }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 200, y: 200), sourceCell: nil, memberFolderID: nil)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 210, y: 200))   // 10pt ≥ 阈值
        coordinator.pointerUp(locationInWindow: NSPoint(x: 210, y: 200))
        XCTAssertEqual(blankClicks, 0, "过阈值 → 空白点击候选取消")
        XCTAssertFalse(coordinator.isSessionActive)
    }

    // MARK: - 9) drag 门

    func testDragGateBlocksSessionStart() {
        let coordinator = makeCoordinator()
        let (layout, _) = makeTwoAppLayout()
        let cell = makeAppCell("app1")
        var clicks = 0
        var suppression: [Bool] = []
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.geometryProvider = { _ in self.twoAppGeometry() }
        coordinator.dragGate = { false }   // 搜索激活 / 标题编辑中
        coordinator.onCellClick = { _ in clicks += 1 }
        coordinator.clickRecognitionSuppressor = { suppression.append($0) }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        XCTAssertEqual(coordinator.controller.state, .idle, "drag 门关闭 → 不进入仲裁")
        XCTAssertFalse(coordinator.isSessionActive)
        XCTAssertTrue(suppression.isEmpty, "drag 门关闭 → 不抑制 click 识别（点击仍走既有路径）")
        coordinator.pointerUp(locationInWindow: NSPoint(x: 40, y: 40))
        XCTAssertEqual(clicks, 0, "drag 门关闭 → coordinator 不派发 click（既有识别器处理）")
    }

    // MARK: - 10) second drag

    func testSecondDragCancelsPreviousAndKeepsArbitration() {
        let coordinator = makeCoordinator()
        let (layout, catalog) = makeTwoAppLayout()
        let cellA = makeAppCell("app1")
        let cellB = makeAppCell("app2")
        var clicks = 0
        var suppression: [Bool] = []
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in self.twoAppGeometry() }
        coordinator.onCellClick = { _ in clicks += 1 }
        coordinator.clickRecognitionSuppressor = { suppression.append($0) }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cellA, memberFolderID: nil)
        XCTAssertEqual(coordinator.controller.state, .pressed)
        // 第二个 pointer-down（不同 cell）→ 旧 session 失效 + 新 session 接管。
        coordinator.pointerDown(locationInWindow: NSPoint(x: 140, y: 40), sourceCell: cellB, memberFolderID: nil)
        XCTAssertEqual(coordinator.controller.state, .pressed)
        XCTAssertEqual(coordinator.controller.activeTransaction?.sourceIdentity, .topLevelApp(ref("app2")))
        XCTAssertEqual(suppression, [false], "second drag 期间 surface 抑制保持（无中间恢复）")

        coordinator.pointerUp(locationInWindow: NSPoint(x: 140, y: 40))
        XCTAssertEqual(clicks, 1, "新 session 的 click 正常派发")
        XCTAssertEqual(suppression, [false, true])
    }

    // MARK: - 11) teardown 零残留

    func testTeardownLeavesNoResidue() {
        let coordinator = makeCoordinator()
        let (layout, catalog) = makeTwoAppLayout()
        let cell = makeAppCell("app1")
        var suppression: [Bool] = []
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in self.twoAppGeometry() }
        coordinator.clickRecognitionSuppressor = { suppression.append($0) }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 50, y: 40))
        XCTAssertEqual(coordinator.controller.state, .dragging)

        coordinator.teardown()
        XCTAssertEqual(coordinator.controller.state, .idle)
        XCTAssertFalse(coordinator.isSessionActive)
        XCTAssertEqual(suppression.last, true, "teardown 恢复 click 识别")
        XCTAssertFalse(coordinator.visuals.isPreviewVisible)
        coordinator.edgeTimerFired()
        XCTAssertEqual(coordinator.controller.state, .idle, "teardown 后 edge timer 无残留")
    }

    // MARK: - 12) BUG6 Wave C：fallback 路径抑制泄漏堵漏

    /// fixture：catalog 同时含 app1/app2，但会话布局只含 app1 ——
    /// "app2" cell 是 stale source（controller sourcePresent 拒绝）。
    private func makeLayoutOnlyApp1() -> (layout: PersistentWorkspaceLayout, catalog: CatalogSnapshot) {
        let (_, catalog) = makeTwoAppLayout()
        let layout = PersistentWorkspaceLayout(generation: .zero, topLevelOrder: [.app(ref("app1"))], folders: [])
        return (layout, catalog)
    }

    /// 序列：真实 down（抑制开启）→ 第二个 down 被 sourcePresent 拒绝
    /// （`.cancelled(.secondDrag)` 无 `.pressed` → fallback 武装）→ 未过阈值 up
    /// → 必须先 endSession（恢复 suppressor(true)）再派发 onCellClick(fallback)。
    /// 直接断言 suppressor 调用序列——不能只用 isSessionActive 代替（残留抑制时它也会是 false）。
    func testStaleSourceFallbackClickRestoresSuppressorBeforeDispatchingClick() {
        let coordinator = makeCoordinator()
        let (layout, catalog) = makeLayoutOnlyApp1()
        let cellLive = makeAppCell("app1")
        let cellStale = makeAppCell("app2")
        var timeline: [String] = []
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in self.twoAppGeometry() }
        coordinator.onCellClick = { cell in
            timeline.append(cell === cellStale ? "click(stale)" : "click(live)")
        }
        coordinator.clickRecognitionSuppressor = { enabled in
            timeline.append(enabled ? "suppress(true)" : "suppress(false)")
        }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cellLive, memberFolderID: nil)
        XCTAssertEqual(coordinator.controller.state, .pressed)
        coordinator.pointerDown(locationInWindow: NSPoint(x: 140, y: 40), sourceCell: cellStale, memberFolderID: nil)
        // sourcePresent 拒绝：controller 重置 idle、无 .pressed、抑制保持（残留）。
        XCTAssertEqual(coordinator.controller.state, .idle)

        coordinator.pointerUp(locationInWindow: NSPoint(x: 140, y: 40))
        XCTAssertEqual(timeline,
                       ["suppress(false)", "suppress(true)", "click(stale)"],
                       "fallback up 必须先 endSession 恢复 suppressor(true)，再派发 onCellClick(fallback)")
        XCTAssertFalse(coordinator.isSessionActive)
    }

    /// 同一序列过阈值：fallback 在 pointerDragged 过阈值时清除，同样必须 endSession；
    /// 随后 pointer-up 不再派发回退点击，且 suppressor 不重复调用（无残留）。
    func testStaleSourceFallbackDragOverThresholdRestoresSuppressor() {
        let coordinator = makeCoordinator()
        let (layout, catalog) = makeLayoutOnlyApp1()
        let cellLive = makeAppCell("app1")
        let cellStale = makeAppCell("app2")
        var timeline: [String] = []
        var clicks = 0
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in self.twoAppGeometry() }
        coordinator.onCellClick = { _ in clicks += 1 }
        coordinator.clickRecognitionSuppressor = { enabled in
            timeline.append(enabled ? "suppress(true)" : "suppress(false)")
        }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cellLive, memberFolderID: nil)
        coordinator.pointerDown(locationInWindow: NSPoint(x: 140, y: 40), sourceCell: cellStale, memberFolderID: nil)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 160, y: 40))   // 过阈值 → 清 fallback + endSession
        XCTAssertEqual(timeline, ["suppress(false)", "suppress(true)"],
                       "过阈值清除 fallback 必须恢复 suppressor(true)")

        coordinator.pointerUp(locationInWindow: NSPoint(x: 160, y: 40))
        XCTAssertEqual(clicks, 0, "过阈值清除后 pointer-up 不再派发回退点击")
        XCTAssertEqual(timeline, ["suppress(false)", "suppress(true)"], "无重复恢复/残留调用")
        XCTAssertFalse(coordinator.isSessionActive)
    }

    /// 同一序列重复 20 次：断言无抑制状态累积 —— suppressor 的 true/false 调用次数严格配平。
    func testStaleSourceFallbackSuppressionBalanceOver20Repetitions() {
        let coordinator = makeCoordinator()
        let (layout, catalog) = makeLayoutOnlyApp1()
        let cellLive = makeAppCell("app1")
        let cellStale = makeAppCell("app2")
        var trueCount = 0
        var falseCount = 0
        var clicks = 0
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in self.twoAppGeometry() }
        coordinator.onCellClick = { _ in clicks += 1 }
        coordinator.clickRecognitionSuppressor = { enabled in
            if enabled { trueCount += 1 } else { falseCount += 1 }
        }

        for _ in 0..<20 {
            coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cellLive, memberFolderID: nil)
            coordinator.pointerDown(locationInWindow: NSPoint(x: 140, y: 40), sourceCell: cellStale, memberFolderID: nil)
            coordinator.pointerUp(locationInWindow: NSPoint(x: 140, y: 40))
        }
        XCTAssertEqual(clicks, 20, "每次序列都应派发 fallback 点击")
        XCTAssertEqual(falseCount, 20, "每轮 beginArbitration 恰好一次 suppress(false)")
        XCTAssertEqual(trueCount, falseCount, "suppressor true/false 调用次数必须配平（无泄漏累积）")
        XCTAssertFalse(coordinator.isSessionActive)
        XCTAssertEqual(coordinator.controller.state, .idle)
    }
}
