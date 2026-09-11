// AppGridUITests — Bug7PageAwareDropTests（T-1F-B7-wave-b）
// BUG7 缺陷 2：顶层落点页内→全局下标映射（page ≥ 1 夹具）。
// 根因：intent 产出按当前页 frames 计数 → 页内下标被当全局下标消费。
// 修复契约：D 层为顶层当前页帧注入分页注记（pageIndex, itemsPerPage）；
// classifier 在 intent 产出边界换算 globalIndex = page * itemsPerPage + localIndex；
// folder 成员帧不带注记 → 成员下标不被外层 itemsPerPage 放大（回归锁）。
// fixture 全部中性合成（bundleID = "fixture.*"），无真实 app 身份。

import AppCatalogCore
import Foundation
import XCTest
@testable import AppGridUI

final class Bug7PageAwareDropTests: XCTestCase {

    private let itemsPerPage = 35

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

    private func makeController() -> DragSessionController {
        DragSessionController(parameters: makeParameters(), clock: FakeDragClock(0))
    }

    /// n 个中性 app 的顶层布局（catalog 稳定序 = 展示序）。
    private func makeLayout(count: Int) -> (layout: PersistentWorkspaceLayout, catalog: CatalogSnapshot) {
        makeDragLayout(titles: (1...count).map { String(format: "a%02d", $0) })
    }

    /// 行布局帧 + 分页注记（D 层 makeDragGeometry 顶层当前页帧契约）。
    private func annotatedRowFrames(_ identities: [DragItemIdentity],
                                    page: Int, itemsPerPage: Int) -> [DragItemFrame] {
        identities.enumerated().map { index, identity in
            DragItemFrame(identity: identity,
                          frame: DragRect(x: Double(index * 100), y: 0, width: 80, height: 80))
                .annotated(pageIndex: page, itemsPerPage: itemsPerPage)
        }
    }

    /// 顶层 scope 几何（当前页帧 + itemsPerPage；page = committedPage）。
    private func topLevelPageGeometry(frames: [DragItemFrame],
                                      page: Int, pageCount: Int,
                                      itemsPerPage: Int, containerWidth: Double) -> DragGeometry {
        DragGeometry(itemFrames: frames, containerWidth: containerWidth,
                     page: page, pageCount: pageCount, itemsPerPage: itemsPerPage)
    }

    /// page p 的可见条目（全局下标 p*35 起）对应的帧身份。
    private func pageIdentities(count: Int, page: Int, itemsPerPage: Int) -> [DragItemIdentity] {
        let start = page * itemsPerPage
        let end = min(start + itemsPerPage, count)
        return (start..<end).map { .app(ref(String(format: "a%02d", $0 + 1))) }
    }

    /// folder scope 几何：成员帧不注记；顶层帧按顶层 committedPage 注记（页号陷阱契约）。
    /// geometry.page = innerPage = 0（陷阱：move-out 换算不得用它）。
    private func folderScopeGeometry(topPageFrames: [DragItemFrame]) -> DragGeometry {
        // 成员行与顶层行 Y 分离：move-out 指针落在顶层行时不会误判为成员行带内。
        let memberFrames = [
            DragItemFrame(identity: .app(ref("b1")), frame: DragRect(x: 0, y: 200, width: 80, height: 80)),
            DragItemFrame(identity: .app(ref("b2")), frame: DragRect(x: 100, y: 200, width: 80, height: 80)),
            DragItemFrame(identity: .app(ref("b3")), frame: DragRect(x: 200, y: 200, width: 80, height: 80)),
        ]
        return DragGeometry(itemFrames: memberFrames, topLevelFrames: topPageFrames,
                            containerWidth: 400, page: 0, pageCount: 1, itemsPerPage: 35)
    }

    /// 含 folder 布局的顶层 page-1 帧身份（顶层 = [folder, a01...a40] → 索引 35...40 = a35...a40）。
    private func folderLayoutTopPageFrames() -> [DragItemFrame] {
        annotatedRowFrames((35...40).map { DragItemIdentity.app(ref(String(format: "a%02d", $0))) },
                           page: 1, itemsPerPage: itemsPerPage)
    }

    /// 含 folder 的布局：顶层 = [folder, a01...a40]。
    private func makeFolderLayout(folderID: FolderID) -> PersistentWorkspaceLayout {
        var topLevel: [WorkspaceTopLevelEntry] = [.folder(folderID)]
        topLevel += (1...40).map { WorkspaceTopLevelEntry.app(ref(String(format: "a%02d", $0))) }
        return PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: topLevel,
            folders: [PersistentFolderRecord(id: folderID, title: "Group A",
                                             members: [ref("b1"), ref("b2"), ref("b3")])])
    }

    // MARK: - ① page 1 页内 index k 的 insertion → 全局 itemsPerPage + k

    func testPage1InsertionConvertsToGlobalIndex() {
        let controller = makeController()
        let (layout, _) = makeLayout(count: 40)   // page 0 = a01...a35，page 1 = a36...a40
        let frames = annotatedRowFrames(pageIdentities(count: 40, page: 1, itemsPerPage: itemsPerPage),
                                        page: 1, itemsPerPage: itemsPerPage)
        let geometry = topLevelPageGeometry(frames: frames, page: 1, pageCount: 2,
                                            itemsPerPage: itemsPerPage, containerWidth: 400)

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("a01")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        // 页内 local 2（a38）右半 → 页内槽 3 → 全局 35 + 3 = 38（修复前会写 3）。
        let moved = controller.pointerMoved(to: DragPoint(x: 270, y: 40),
                                            geometry: geometry, layout: layout, catalogGeneration: 1)
        assertContains(moved, .intentChanged(.insertion(index: 38)))
        XCTAssertEqual(controller.lastIntent, .insertion(index: 38))

        let up = controller.pointerUp(at: DragPoint(x: 270, y: 40),
                                      geometry: geometry, layout: layout, catalogGeneration: 1)
        guard case .committed(let newLayout)? = controller.lastOutcome else {
            return XCTFail("expected commit, got \(up)")
        }
        // remove-then-insert：源 a01（全局 0）在槽 38 左侧 → 37；a38 后即插入（a39 前）。
        XCTAssertEqual(newLayout.topLevelOrder.count, 40)
        XCTAssertEqual(newLayout.topLevelOrder[37], .app(ref("a01")))
        XCTAssertEqual(newLayout.topLevelOrder[36], .app(ref("a38")))
        XCTAssertEqual(newLayout.topLevelOrder[38], .app(ref("a39")))
    }

    // MARK: - ② 末页最右列：左半 = 该全局槽之前；放下后源项出现在末列

    func testLastPageRightmostLeftHalfInsertsBeforeGlobalSlot() {
        let controller = makeController()
        let (layout, _) = makeLayout(count: 70)   // page 1 = a36...a70（满页），最右条目 = a70（全局 69）
        let frames = annotatedRowFrames(pageIdentities(count: 70, page: 1, itemsPerPage: itemsPerPage),
                                        page: 1, itemsPerPage: itemsPerPage)
        let geometry = topLevelPageGeometry(frames: frames, page: 1, pageCount: 2,
                                            itemsPerPage: itemsPerPage, containerWidth: 3600)

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("a01")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        // 最右条目（页内 local 34）左半 → 页内槽 34 → 全局 69（该全局槽之前）。
        let moved = controller.pointerMoved(to: DragPoint(x: 3420, y: 40),
                                            geometry: geometry, layout: layout, catalogGeneration: 1)
        assertContains(moved, .intentChanged(.insertion(index: 69)))

        _ = controller.pointerUp(at: DragPoint(x: 3420, y: 40),
                                 geometry: geometry, layout: layout, catalogGeneration: 1)
        guard case .committed(let newLayout)? = controller.lastOutcome else { return XCTFail("expected commit") }
        // 源 a01 落在末页（全局 68，紧邻原最右条目左侧；原最右 a70 仍在 69）。
        XCTAssertEqual(newLayout.topLevelOrder[68], .app(ref("a01")))
        XCTAssertEqual(newLayout.topLevelOrder[69], .app(ref("a70")))
        XCTAssertEqual(newLayout.topLevelOrder.count, 70)
    }

    func testLastPageRightmostDropLandsSourceInRightmostColumn() {
        let controller = makeController()
        let (layout, _) = makeLayout(count: 70)
        let frames = annotatedRowFrames(pageIdentities(count: 70, page: 1, itemsPerPage: itemsPerPage),
                                        page: 1, itemsPerPage: itemsPerPage)
        let geometry = topLevelPageGeometry(frames: frames, page: 1, pageCount: 2,
                                            itemsPerPage: itemsPerPage, containerWidth: 3600)

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("a01")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        // 最右条目右半（页内 local 35）→ 全局 70 → 源落在全局 69 = 末页最右列。
        let moved = controller.pointerMoved(to: DragPoint(x: 3470, y: 40),
                                            geometry: geometry, layout: layout, catalogGeneration: 1)
        assertContains(moved, .intentChanged(.insertion(index: 70)))

        _ = controller.pointerUp(at: DragPoint(x: 3470, y: 40),
                                 geometry: geometry, layout: layout, catalogGeneration: 1)
        guard case .committed(let newLayout)? = controller.lastOutcome else { return XCTFail("expected commit") }
        XCTAssertEqual(newLayout.topLevelOrder[69], .app(ref("a01")), "源项出现在末页最右列")
        XCTAssertEqual(newLayout.topLevelOrder.count, 70)
    }

    // MARK: - ③ 满页插最后一个之后 = 全局末尾（公式自然闭合）

    func testFullPageInsertAfterLastClosesAtGlobalTail() {
        let controller = makeController()
        let (layout, _) = makeLayout(count: 70)
        let frames = annotatedRowFrames(pageIdentities(count: 70, page: 1, itemsPerPage: itemsPerPage),
                                        page: 1, itemsPerPage: itemsPerPage)
        let geometry = topLevelPageGeometry(frames: frames, page: 1, pageCount: 2,
                                            itemsPerPage: itemsPerPage, containerWidth: 3600)

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("a01")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        // 末条目之后（页内 local 35）→ 全局 70 == topLevelOrder.count → resolver 接受。
        let moved = controller.pointerMoved(to: DragPoint(x: 3500, y: 40),
                                            geometry: geometry, layout: layout, catalogGeneration: 1)
        assertContains(moved, .intentChanged(.insertion(index: 70)))

        _ = controller.pointerUp(at: DragPoint(x: 3500, y: 40),
                                 geometry: geometry, layout: layout, catalogGeneration: 1)
        guard case .committed(let newLayout)? = controller.lastOutcome else { return XCTFail("expected commit") }
        XCTAssertEqual(newLayout.topLevelOrder.count, 70)
        XCTAssertEqual(newLayout.topLevelOrder[69], .app(ref("a01")), "全局末尾")
    }

    // MARK: - ④ folder 内 insertion 不得乘外层 itemsPerPage（回归锁）

    func testFolderInnerInsertionNotMultipliedByOuterItemsPerPage() {
        let controller = makeController()
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let layout = makeFolderLayout(folderID: folderID)
        // 顶层帧带 page 1 注记（committedPage = 1）；成员帧无注记 → 成员下标不被外层放大。
        let geometry = folderScopeGeometry(topPageFrames: folderLayoutTopPageFrames())

        // 成员行在 y=200（与顶层行分离）；在成员行内操作。
        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 240),
                                              source: .folderMember(folderID: folderID, app: ref("b1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        // 位移 ≥ arm 阈值（armed）但指针仍在成员行 → 必须内部插入，不得 move-out；
        // b2（local 1）右半 → 成员下标 2，不是 35 + 2 = 37。
        let moved = controller.pointerMoved(to: DragPoint(x: 170, y: 240),
                                            geometry: geometry, layout: layout, catalogGeneration: 1)
        assertContains(moved, .intentChanged(.insertion(index: 2)))
        XCTAssertEqual(controller.lastIntent, .insertion(index: 2), "folder 内 insertion 不乘外层 itemsPerPage")

        _ = controller.pointerUp(at: DragPoint(x: 170, y: 240),
                                 geometry: geometry, layout: layout, catalogGeneration: 1)
        guard case .committed(let newLayout)? = controller.lastOutcome else { return XCTFail("expected commit") }
        XCTAssertEqual(newLayout.folder(id: folderID)?.members, [ref("b2"), ref("b1"), ref("b3")])
        XCTAssertEqual(newLayout.topLevelOrder, layout.topLevelOrder, "顶层序不变")
    }

    // MARK: - ⑤ move-out（.topLevelTarget）用顶层 committedPage，不用 innerPage（页号陷阱）

    func testMoveOutFromFolderOnTopPage1UsesCommittedPage() {
        let controller = makeController()
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let layout = makeFolderLayout(folderID: folderID)
        // geometry.page = innerPage = 0；顶层帧注记 = committedPage 1 → 全局 35 + local。
        let geometry = folderScopeGeometry(topPageFrames: folderLayoutTopPageFrames())

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .folderMember(folderID: folderID, app: ref("b1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        // 250pt ≥ arm 阈值 → armed；指针在顶层帧缝隙（a37/a38 之间）→ 顶层落点。
        // 页内 local 3 → 全局 35 + 3 = 38（若误用 innerPage 0 会得 3）。
        let moved = controller.pointerMoved(to: DragPoint(x: 290, y: 40),
                                            geometry: geometry, layout: layout, catalogGeneration: 1)
        assertContains(moved, .intentChanged(.topLevelTarget(index: 38)))
        XCTAssertEqual(controller.lastIntent, .topLevelTarget(index: 38))

        _ = controller.pointerUp(at: DragPoint(x: 290, y: 40),
                                 geometry: geometry, layout: layout, catalogGeneration: 1)
        guard case .committed(let newLayout)? = controller.lastOutcome else { return XCTFail("expected commit") }
        XCTAssertEqual(newLayout.topLevelOrder.count, 42)
        XCTAssertEqual(newLayout.topLevelOrder[38], .app(ref("b1")))
        XCTAssertEqual(newLayout.folder(id: folderID)?.members, [ref("b2"), ref("b3")])
    }

    // MARK: - 分类器直测：注记帧 vs 无注记帧（同一指针，换算只此一次）

    func testClassifierAnnotationDrivesGlobalConversion() {
        let identities: [DragItemIdentity] = [.app(ref("b1")), .app(ref("b2")), .app(ref("b3"))]
        let zones = DropZones(itemFrames: annotatedRowFrames(identities, page: 1, itemsPerPage: 35))
        // local 1 右半 → 页内 2 → 全局 37。
        let annotated = DropZoneClassifier.classify(pointer: DragPoint(x: 170, y: 40),
                                                    source: .topLevelApp(ref("b1")), zones: zones)
        XCTAssertEqual(annotated, .insertion(index: 37))
        // 同一帧无注记（page 0 / 既有夹具）→ 页内即全局。
        let plain = DropZoneClassifier.classify(
            pointer: DragPoint(x: 170, y: 40), source: .topLevelApp(ref("b1")),
            zones: DropZones(itemFrames: rowFrames(identities)))
        XCTAssertEqual(plain, .insertion(index: 2))
    }
}