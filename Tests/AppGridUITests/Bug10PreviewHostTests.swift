// AppGridUITests — Bug10PreviewHostTests（BUG10 缺陷 B，方案 B1 宿主切换契约测试）
// 覆盖（任务包 §7）：
// ① setHost 幂等：同值/异值重复、切换后 attach 不重复 addSubview、teardown 零残留
// ② preview 坐标 = visualHost.convert 同源锁：切换后 preview 仍贴指针（不偏移）
// ③ move-out 跨 scope：成员拖到顶层缝隙，preview 与顶层蓝条同系不跳变
// ④ 顶层拖拽回归：host 恒 surface，既有行为零变化
// fixture 标题为合成数据（无真实 app 身份）。

import AppCatalogCore
import AppIconPipeline
import AppKit
import Foundation
import PagingUI
import XCTest
@testable import AppGridUI

@MainActor
final class Bug10PreviewHostTests: XCTestCase {

    /// host 强引用（visualHost/visuals.host 均为 weak；测试期间必须存活）。
    private var retainedHost: NSView?

    override func tearDown() {
        retainedHost = nil
        super.tearDown()
    }

    // MARK: - 工厂

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

    /// 窗口化双宿主：surface（窗口 contentView）+ overlay（surface 子视图，偏移 (100,50)）。
    /// 真实窗口保证 convert(from: nil) 语义与生产一致（overlay 系 ≠ surface 系）。
    private func makeWindowedHosts() -> (window: NSWindow, surface: NSView, overlay: NSView) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let surface = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let overlay = NSView(frame: NSRect(x: 100, y: 50, width: 400, height: 300))
        window.contentView = surface
        surface.addSubview(overlay)
        surface.layoutSubtreeIfNeeded()
        return (window, surface, overlay)
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

    /// folder scope 几何：成员帧 + 顶层帧**均 convert 到 overlay 系**（makeDragGeometry 契约）。
    private func folderScopeGeometry(folderID: FolderID, page: Int = 0, pageCount: Int = 2) -> DragGeometry {
        folderGeometry(memberFrames: rowFrames([.app(ref("app1")), .app(ref("app2"))]),
                       topLevelFrames: [folderFrame(folderID, x: 0)],
                       containerWidth: 400, page: page, pageCount: pageCount)
    }

    /// 断言：所有已挂载视觉视图的父视图 === host（未挂载的保持 nil）。
    private func assertAllAttached(_ visuals: DragUIVisuals, to host: NSView?,
                                   file: StaticString = #filePath, line: UInt = #line) {
        for (index, superview) in visuals.visualViewSuperviews.enumerated() {
            if let superview {
                XCTAssertTrue(superview === host,
                              "view[\(index)] 挂载到意外父视图", file: file, line: line)
            }
        }
    }

    /// 断言：四视觉视图全部无父视图（teardown 零残留）。
    private func assertAllDetached(_ visuals: DragUIVisuals,
                                   file: StaticString = #filePath, line: UInt = #line) {
        for (index, superview) in visuals.visualViewSuperviews.enumerated() {
            XCTAssertNil(superview, "view[\(index)] teardown 后仍有父视图", file: file, line: line)
        }
    }

    // MARK: - ① setHost 幂等（DragUIVisuals 直构）

    func testSetHostSameValueIsIdempotent() {
        let hostA = makeHost()
        let visuals = DragUIVisuals(host: hostA, reduceMotionProvider: { false })
        let cell = makeAppCell("app1")
        visuals.showPreview(sourceCell: cell, at: NSPoint(x: 50, y: 40))
        assertAllAttached(visuals, to: hostA)
        let subviewCount = hostA.subviews.count
        XCTAssertGreaterThan(subviewCount, 0)

        visuals.setHost(hostA)   // 同值重复
        assertAllAttached(visuals, to: hostA)
        XCTAssertEqual(hostA.subviews.count, subviewCount, "同值 setHost 不重复 addSubview")
        XCTAssertEqual(visuals.previewFrame, NSRect(x: 2, y: 64, width: 96, height: 88),
                       "同值 setHost 不漂移")
    }

    func testSetHostMigratesAttachedViewsExactlyOnce() {
        let hostA = makeHost()
        let hostB = makeHost()
        let visuals = DragUIVisuals(host: hostA, reduceMotionProvider: { false })
        let cell = makeAppCell("app1")
        visuals.showPreview(sourceCell: cell, at: NSPoint(x: 50, y: 40))
        visuals.updateIntent(.insertion(index: 1), geometry: twoAppGeometry())
        assertAllAttached(visuals, to: hostA)
        let attachedCount = hostA.subviews.count
        XCTAssertEqual(attachedCount, 2, "preview + insertion 竖条")

        visuals.setHost(hostB)   // 异值切换
        assertAllAttached(visuals, to: hostB)
        XCTAssertEqual(hostB.subviews.count, attachedCount, "已挂载视图全部迁移且不重复")
        XCTAssertEqual(hostA.subviews.count, 0, "旧宿主零残留")

        visuals.setHost(hostB)   // 迁移后同值重复
        XCTAssertEqual(hostB.subviews.count, attachedCount, "迁移后同值 setHost 不重复 addSubview")
    }

    func testSetHostAfterTeardownDoesNotReattach() {
        let hostA = makeHost()
        let hostB = makeHost()
        let visuals = DragUIVisuals(host: hostA, reduceMotionProvider: { false })
        let cell = makeAppCell("app1")
        visuals.showPreview(sourceCell: cell, at: NSPoint(x: 50, y: 40))
        visuals.teardown()
        assertAllDetached(visuals)

        visuals.setHost(hostB)   // teardown 后切换：不得重新挂载
        assertAllDetached(visuals)
        XCTAssertEqual(hostB.subviews.count, 0, "teardown 后 setHost 不重新挂载")
    }

    // MARK: - ①/④ coordinator 层：同值幂等 + 顶层拖拽回归

    func testSetVisualHostSameValueIsIdempotentNoDrift() {
        let host = makeHost()
        let coordinator = makeCoordinator(host: host)
        let (layout, catalog) = makeTwoAppLayout()
        let cell = makeAppCell("app1")
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in self.twoAppGeometry() }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 50, y: 40))
        XCTAssertEqual(coordinator.controller.state, .dragging)
        assertAllAttached(coordinator.visuals, to: host)
        let subviewCount = host.subviews.count

        coordinator.setVisualHost(host)   // 同值
        assertAllAttached(coordinator.visuals, to: host)
        XCTAssertEqual(host.subviews.count, subviewCount, "同值 setVisualHost 不重复 addSubview")
        XCTAssertEqual(coordinator.visuals.previewFrame, NSRect(x: 2, y: 64, width: 96, height: 88),
                       "同值切换 preview 不漂移")
    }

    func testTopLevelDragRegressionHostStaysSurface() {
        let host = makeHost()
        let coordinator = makeCoordinator(host: host)
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
        XCTAssertEqual(coordinator.controller.state, .dragging)
        XCTAssertTrue(coordinator.visuals.isPreviewVisible)
        assertAllAttached(coordinator.visuals, to: host)

        coordinator.pointerDragged(locationInWindow: NSPoint(x: 155, y: 40))
        coordinator.pointerUp(locationInWindow: NSPoint(x: 155, y: 40))
        XCTAssertEqual(commits.count, 1, "顶层拖拽 commit 正常")
        XCTAssertEqual(coordinator.controller.state, .idle)
        assertAllAttached(coordinator.visuals, to: host)
    }

    // MARK: - ② preview 坐标 = visualHost.convert 同源锁

    func testPreviewStaysGluedToPointerAfterHostSwitch() {
        let (window, surface, overlay) = makeWindowedHosts()
        _ = window
        retainedHost = surface
        let coordinator = DragUISessionCoordinator(host: surface,
                                                   parameters: makeParameters(),
                                                   clock: FakeDragClock(0))
        let (layout, catalog) = makeTwoAppLayout()
        let cell = makeAppCell("app1")
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in self.twoAppGeometry() }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 50, y: 40))
        XCTAssertEqual(coordinator.controller.state, .dragging)
        XCTAssertEqual(coordinator.visuals.previewFrame, NSRect(x: 2, y: 64, width: 96, height: 88),
                       "surface 系 preview 贴指针")

        // 宿主切换（folder 打开）：同一动作同步 visualHost 与 visuals.host
        coordinator.setVisualHost(overlay)
        XCTAssertTrue(coordinator.visualHost === overlay)
        assertAllAttached(coordinator.visuals, to: overlay)

        // 同源锁：切换后 preview 帧 = overlay.convert(pointer) − 偏移（贴指针，不偏移）
        let p1 = overlay.convert(NSPoint(x: 150, y: 90), from: nil)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 150, y: 90))
        XCTAssertEqual(coordinator.visuals.previewFrame,
                       NSRect(x: p1.x - 48, y: p1.y + 24, width: 96, height: 88),
                       "切换后 preview 与指针同源（overlay 系）")
        XCTAssertEqual(coordinator.visuals.previewFrame, NSRect(x: 2, y: 64, width: 96, height: 88),
                       "overlay 偏移 (100,50) 下 (150,90) → overlay 系 (50,40)")

        let p2 = overlay.convert(NSPoint(x: 250, y: 140), from: nil)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 250, y: 140))
        XCTAssertEqual(coordinator.visuals.previewFrame,
                       NSRect(x: p2.x - 48, y: p2.y + 24, width: 96, height: 88),
                       "继续拖动仍贴指针（overlay 系）")
    }

    // MARK: - ③ move-out 跨 scope：preview 与顶层蓝条同系不跳变

    func testMoveOutBarAndPreviewShareOverlayCoordinateSystem() {
        let (window, _, overlay) = makeWindowedHosts()
        _ = window
        retainedHost = overlay
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let coordinator = DragUISessionCoordinator(host: overlay,
                                                   parameters: makeParameters(),
                                                   clock: FakeDragClock(0))
        let (layout, catalog) = makeFolderLayout(folderID: folderID)
        let memberCell = makeAppCell("app1")
        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        // folder scope：成员帧 + 顶层帧均 convert 到 overlay 系（makeDragGeometry 契约）
        coordinator.geometryProvider = { _ in self.folderScopeGeometry(folderID: folderID) }

        // 成员按下（overlay 系 (40,40)：窗口 (140,90)）
        coordinator.pointerDown(locationInWindow: NSPoint(x: 140, y: 90),
                                sourceCell: memberCell, memberFolderID: folderID)
        // 位移 30pt ≥ 24 → moveOutArmed（overlay 系 (70,40)：窗口 (170,90)）
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 170, y: 90))
        XCTAssertEqual(coordinator.controller.state, .dragging)
        XCTAssertTrue(coordinator.controller.moveOutArmed, "move-out 显式 arm")

        // 拖到顶层缝隙（overlay 系 (200,40)：窗口 (300,90)；顶层帧 [folderFrame(x:0)] 之外）
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 300, y: 90))
        XCTAssertTrue(coordinator.visuals.isInsertionIndicatorVisible, "move-out 顶层落点 → 顶层蓝条")
        // 顶层蓝条 = 顶层帧末右缘（overlay 系）：x = 0 + 80 − 3 = 77
        XCTAssertEqual(coordinator.visuals.insertionIndicatorFrame,
                       NSRect(x: 77, y: 0, width: 3, height: 80),
                       "顶层蓝条在 overlay 系（与 preview 同系）")
        // preview 同系：overlay 系 (200,40) → (152, 64, 96, 88)
        XCTAssertEqual(coordinator.visuals.previewFrame,
                       NSRect(x: 152, y: 64, width: 96, height: 88),
                       "preview 在 overlay 系（与顶层蓝条同系，不跳变）")
        assertAllAttached(coordinator.visuals, to: overlay)
    }
}
