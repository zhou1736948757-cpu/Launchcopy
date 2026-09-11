// AppGridUITests — DragSessionControllerTests（T-1F-C 测试）
// 覆盖 DragSessionController 状态机测试矩阵（§10.1 drag 部分）：
// 1) click vs drag 阈值仲裁 2) 状态机全路径 3) stale source/layout/catalog 拒绝
// 4) 无活动 session / 重复 drop 拒绝 5) second drag 使旧 session 失效
// 6) 统一 cancel 全路径 7) edge 全序列 8) commit 路径。
// 全部经 DragSessionTestSupport 工厂（FakeDragClock / makeDragLayout / ref /
// rowFrames / topLevelGeometry / assertContains）；fixture 标题为合成数据
// （bundleID = "fixture.*"），无真实 app 身份。

import AppCatalogCore
import Foundation
import XCTest
@testable import AppGridUI

final class DragSessionControllerTests: XCTestCase {

    // MARK: - 工厂

    /// 小阈值参数（便于测试）：阈值 6pt、dwell 100ms、边缘 40pt、hysteresis 10pt。
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

    private func makeController(clock: FakeDragClock = FakeDragClock(0)) -> DragSessionController {
        DragSessionController(parameters: makeParameters(), clock: clock)
    }

    /// 两 app 顶层布局（generation 0）：[app1, app2]。
    private func makeTwoAppLayout() -> (layout: PersistentWorkspaceLayout, catalog: CatalogSnapshot) {
        makeDragLayout(titles: ["app1", "app2"])
    }

    private func twoAppGeometry(page: Int = 0, pageCount: Int = 1) -> DragGeometry {
        topLevelGeometry(frames: rowFrames([.app(ref("app1")), .app(ref("app2"))]),
                         containerWidth: 400, page: page, pageCount: pageCount)
    }

    // MARK: - 1) click vs drag 阈值仲裁

    func testClickBelowThresholdYieldsClickedAndReturnsToIdle() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()
        let geometry = twoAppGeometry()

        let down = controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                           source: .topLevelApp(ref("app1")),
                                           layout: layout, catalogGeneration: 1)
        XCTAssertEqual(down, [.pressed])
        XCTAssertEqual(controller.state, .pressed)
        XCTAssertNotNil(controller.activeTransaction)

        let up = controller.pointerUp(at: DragPoint(x: 40, y: 40),
                                      geometry: geometry, layout: layout, catalogGeneration: 1)
        XCTAssertEqual(up, [.clicked])
        XCTAssertEqual(controller.state, .idle)
        XCTAssertNil(controller.activeTransaction)
        XCTAssertNil(controller.lastOutcome, "click 不产生终局 outcome")
    }

    func testSubThresholdMoveStaysPressedThenClick() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()
        let geometry = twoAppGeometry()

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        // 位移 3pt < 阈值 6pt：仍 pressed，无 .dragBegan。
        let moved = controller.pointerMoved(to: DragPoint(x: 43, y: 40),
                                            geometry: geometry, layout: layout, catalogGeneration: 1)
        XCTAssertEqual(moved, [])
        XCTAssertEqual(controller.state, .pressed)

        XCTAssertEqual(controller.pointerUp(at: DragPoint(x: 43, y: 40),
                                            geometry: geometry, layout: layout, catalogGeneration: 1), [.clicked])
        XCTAssertEqual(controller.state, .idle)
    }

    func testMovePastThresholdBeginsDrag() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()
        let geometry = twoAppGeometry()

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        // 位移 10pt ≥ 阈值 6pt：进入 dragging。
        let moved = controller.pointerMoved(to: DragPoint(x: 50, y: 40),
                                            geometry: geometry, layout: layout, catalogGeneration: 1)
        XCTAssertEqual(moved, [.dragBegan, .intentChanged(.insertion(index: 1))])
        XCTAssertEqual(controller.state, .dragging)
    }

    // MARK: - 2) 状态机全路径（idle→pressed→dragging→edgeTurnPending→commit→idle）

    func testStateMachineFullPathThroughEdgeTurnToCommit() {
        let clock = FakeDragClock(0)
        let controller = makeController(clock: clock)
        let (layout, _) = makeTwoAppLayout()
        // page 1（非首页/末页）→ 左缘可武装 dwell（page 0 左缘是 atFirstPage 边界）。
        let geometry = twoAppGeometry(page: 1, pageCount: 3)

        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        XCTAssertEqual(controller.state, .pressed)

        XCTAssertEqual(controller.pointerMoved(to: DragPoint(x: 50, y: 40),
                                              geometry: geometry, layout: layout, catalogGeneration: 1), [.dragBegan, .intentChanged(.insertion(index: 1))])
        XCTAssertEqual(controller.state, .dragging)

        // 拖入左缘（page 0 / pageCount 3，非首页边界）→ dwell 武装。
        XCTAssertEqual(controller.pointerMoved(to: DragPoint(x: 10, y: 40),
                                               geometry: geometry, layout: layout, catalogGeneration: 1),
                       [.edge(.edgeEntered(.left)), .edge(.dwellStarted(.left)), .intentChanged(.insertion(index: 0))])
        XCTAssertEqual(controller.state, .edgeTurnPending)
        XCTAssertEqual(controller.edgeDwellDeadline, 0.1)

        // dwell 满 → 一次 page turn 请求；dwell 保持武装（连续翻页）。
        clock.current = 0.2
        XCTAssertEqual(controller.edgeTimerFired(geometry: geometry, layout: layout, catalogGeneration: 1),
                       [.edge(.pageTurnRequested(.left))])
        XCTAssertEqual(controller.state, .edgeTurnPending)

        // 离开边缘（hysteresis 回退）→ 回 dragging。
        XCTAssertEqual(controller.pointerMoved(to: DragPoint(x: 100, y: 40),
                                               geometry: geometry, layout: layout, catalogGeneration: 1),
                       [.edge(.edgeLeft(.left)), .intentChanged(.insertion(index: 1))])
        XCTAssertEqual(controller.state, .dragging)
        XCTAssertNil(controller.edgeDwellDeadline)

        // 合法 drop（app2 右半区 → 插到 app2 之后；off-by-one 换算后落位 1）→ commit。
        let up = controller.pointerUp(at: DragPoint(x: 155, y: 40),
                                      geometry: geometry, layout: layout, catalogGeneration: 1)
        guard case .committed(let newLayout)? = up.first else {
            return XCTFail("expected .committed, got \(up)")
        }
        XCTAssertEqual(controller.state, .idle)
        XCTAssertNil(controller.activeTransaction)
        XCTAssertEqual(controller.lastOutcome, .committed(newLayout))
        XCTAssertEqual(newLayout.generation, LayoutGeneration(1))
        XCTAssertEqual(newLayout.topLevelOrder, [.app(ref("app2")), .app(ref("app1"))])
    }

    // MARK: - 3) stale 防护（source / layout generation / catalog generation）

    func testStaleSourceRejectedAtPointerDown() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()

        // source 不在布局中 → pointerDown 拒绝，无 .pressed。
        let events = controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                            source: .topLevelApp(ref("ghost")),
                                            layout: layout, catalogGeneration: 1)
        XCTAssertEqual(events, [])
        XCTAssertEqual(controller.state, .idle)
        XCTAssertNil(controller.activeTransaction)
    }

    func testStaleLayoutGenerationCancelsOnMove() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()
        let stale = PersistentWorkspaceLayout(generation: LayoutGeneration(1),
                                              topLevelOrder: [.app(ref("app1")), .app(ref("app2"))],
                                              folders: [])
        let geometry = twoAppGeometry()

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        let events = controller.pointerMoved(to: DragPoint(x: 50, y: 40),
                                            geometry: geometry, layout: stale, catalogGeneration: 1)
        XCTAssertEqual(events, [.cancelled(.layoutChanged)])
        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(controller.lastOutcome, .cancelled(.layoutChanged))
    }

    func testStaleCatalogGenerationCancelsOnMove() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()
        let geometry = twoAppGeometry()

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        let events = controller.pointerMoved(to: DragPoint(x: 50, y: 40),
                                            geometry: geometry, layout: layout, catalogGeneration: 2)
        XCTAssertEqual(events, [.cancelled(.catalogRefresh)])
        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(controller.lastOutcome, .cancelled(.catalogRefresh))
    }

    func testStaleLayoutGenerationCancelsOnPointerUp() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()
        let stale = PersistentWorkspaceLayout(generation: LayoutGeneration(1),
                                              topLevelOrder: [.app(ref("app1")), .app(ref("app2"))],
                                              folders: [])
        let geometry = twoAppGeometry()

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        XCTAssertEqual(controller.pointerMoved(to: DragPoint(x: 50, y: 40),
                                              geometry: geometry, layout: layout, catalogGeneration: 1), [.dragBegan, .intentChanged(.insertion(index: 1))])
        // pointerUp 防御路径：双 generation 过期 → 统一 cancel。
        let events = controller.pointerUp(at: DragPoint(x: 50, y: 40),
                                          geometry: geometry, layout: stale, catalogGeneration: 1)
        XCTAssertEqual(events, [.cancelled(.layoutChanged)])
        XCTAssertEqual(controller.state, .idle)
    }

    // MARK: - 4) 无活动 session / 重复 drop 拒绝

    func testDropWithoutActiveSessionYieldsNoEvents() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()
        let geometry = twoAppGeometry()

        XCTAssertEqual(controller.pointerUp(at: DragPoint(x: 40, y: 40),
                                            geometry: geometry, layout: layout, catalogGeneration: 1), [])
        XCTAssertEqual(controller.state, .idle)

        // cancel 后同样无活动 session。
        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        XCTAssertEqual(controller.cancel(reason: .escape), [.cancelled(.escape)])
        XCTAssertEqual(controller.pointerUp(at: DragPoint(x: 40, y: 40),
                                            geometry: geometry, layout: layout, catalogGeneration: 1), [])
    }

    func testDuplicateDropAfterCommitYieldsNoEvents() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()
        let geometry = twoAppGeometry()

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        XCTAssertEqual(controller.pointerMoved(to: DragPoint(x: 50, y: 40),
                                              geometry: geometry, layout: layout, catalogGeneration: 1), [.dragBegan, .intentChanged(.insertion(index: 1))])
        let first = controller.pointerUp(at: DragPoint(x: 155, y: 40),
                                         geometry: geometry, layout: layout, catalogGeneration: 1)
        guard case .committed = first.first else {
            return XCTFail("expected .committed, got \(first)")
        }
        // 同一 token 已消费（session 已销毁）→ 二次 drop 无事件（tokenConsumed 在
        // DropResolver 内层强制；controller 层以无活动 session 拒绝）。
        XCTAssertEqual(controller.pointerUp(at: DragPoint(x: 155, y: 40),
                                            geometry: geometry, layout: layout, catalogGeneration: 1), [])
        XCTAssertEqual(controller.state, .idle)
    }

    // MARK: - 5) second drag 使旧 session 失效

    func testSecondDragCancelsFirstSession() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()
        let geometry = twoAppGeometry()

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        XCTAssertEqual(controller.pointerMoved(to: DragPoint(x: 50, y: 40),
                                              geometry: geometry, layout: layout, catalogGeneration: 1), [.dragBegan, .intentChanged(.insertion(index: 1))])
        XCTAssertEqual(controller.state, .dragging)

        // 拖拽中再次 pointerDown → 先 cancel(.secondDrag) 再开新 session。
        let second = controller.pointerDown(at: DragPoint(x: 140, y: 40),
                                            source: .topLevelApp(ref("app2")),
                                            layout: layout, catalogGeneration: 1)
        XCTAssertEqual(second, [.cancelled(.secondDrag), .pressed])
        XCTAssertEqual(controller.state, .pressed)
        // 新 session 启动时清空 lastOutcome（旧 session 的 cancel 仅以事件呈现）。
        XCTAssertNil(controller.lastOutcome)
        XCTAssertEqual(controller.activeTransaction?.sourceIdentity, .topLevelApp(ref("app2")))

        // 新 session 未过阈值 → click 收尾。
        XCTAssertEqual(controller.pointerUp(at: DragPoint(x: 140, y: 40),
                                            geometry: geometry, layout: layout, catalogGeneration: 1), [.clicked])
        XCTAssertEqual(controller.state, .idle)
    }

    // MARK: - 6) 统一 cancel 全路径

    func testUnifiedCancelAllReasons() {
        let (layout, _) = makeTwoAppLayout()
        let geometry = twoAppGeometry()

        for reason in DragCancelReason.allCases {
            let controller = makeController()
            XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                                  source: .topLevelApp(ref("app1")),
                                                  layout: layout, catalogGeneration: 1), [.pressed],
                           "reason \(reason)")
            let events = controller.cancel(reason: reason)
            XCTAssertEqual(events, [.cancelled(reason)], "reason \(reason)")
            XCTAssertEqual(controller.state, .idle, "reason \(reason)")
            XCTAssertNil(controller.activeTransaction, "reason \(reason)")
            XCTAssertEqual(controller.lastOutcome, .cancelled(reason), "reason \(reason)")
            // 零残留：后续 pointerUp 无事件。
            XCTAssertEqual(controller.pointerUp(at: DragPoint(x: 40, y: 40),
                                                geometry: geometry, layout: layout, catalogGeneration: 1), [],
                           "reason \(reason): 零残留")
        }
    }

    func testCancelWhenIdleYieldsNoEvents() {
        let controller = makeController()
        XCTAssertEqual(controller.cancel(reason: .escape), [])
        XCTAssertEqual(controller.state, .idle)
        XCTAssertNil(controller.lastOutcome)
    }

    func testCancelWhileDwellArmedEmitsDwellCancelled() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()
        // page 1（非首页）→ 左缘可武装 dwell。
        let geometry = twoAppGeometry(page: 1, pageCount: 3)

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        XCTAssertEqual(controller.pointerMoved(to: DragPoint(x: 10, y: 40),
                                               geometry: geometry, layout: layout, catalogGeneration: 1),
                       [.dragBegan, .edge(.edgeEntered(.left)), .edge(.dwellStarted(.left)),
                            .intentChanged(.insertion(index: 0))])
        XCTAssertEqual(controller.state, .edgeTurnPending)

        // 统一 cancel 出口同时清掉 edge timer（dwellCancelled）。
        let events = controller.cancel(reason: .escape)
        XCTAssertEqual(events, [.edge(.dwellCancelled), .cancelled(.escape)])
        XCTAssertEqual(controller.state, .idle)
        XCTAssertNil(controller.edgeDwellDeadline)
    }

    // MARK: - 7) edge 全序列

    func testEdgeSequenceEnterDwellTurnLeave() {
        let clock = FakeDragClock(0)
        let controller = makeController(clock: clock)
        let (layout, _) = makeDragLayout(titles: ["app1", "app2", "app3"])
        // page 1（非首页/末页）→ 左缘可武装 dwell。
        let geometry = topLevelGeometry(frames: rowFrames([.app(ref("app1")), .app(ref("app2")), .app(ref("app3"))]),
                                        containerWidth: 400, page: 1, pageCount: 3)

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        // 进入左缘（非首页）→ edgeEntered + dwellStarted，deadline = now + 100ms。
        XCTAssertEqual(controller.pointerMoved(to: DragPoint(x: 10, y: 40),
                                               geometry: geometry, layout: layout, catalogGeneration: 1),
                       [.dragBegan, .edge(.edgeEntered(.left)), .edge(.dwellStarted(.left)),
                            .intentChanged(.insertion(index: 0))])
        XCTAssertEqual(controller.state, .edgeTurnPending)
        XCTAssertEqual(controller.edgeDwellDeadline, 0.1)

        // dwell 满 → pageTurnRequested；deadline 按 min interval 重新武装。
        clock.current = 0.2
        XCTAssertEqual(controller.edgeTimerFired(geometry: geometry, layout: layout, catalogGeneration: 1),
                       [.edge(.pageTurnRequested(.left))])
        XCTAssertEqual(controller.state, .edgeTurnPending)
        XCTAssertEqual(controller.edgeDwellDeadline, 0.4)

        // 离开边缘（hysteresis 回退）→ edgeLeft，回 dragging。
        XCTAssertEqual(controller.pointerMoved(to: DragPoint(x: 100, y: 40),
                                               geometry: geometry, layout: layout, catalogGeneration: 1),
                       [.edge(.edgeLeft(.left)), .intentChanged(.insertion(index: 1))])
        XCTAssertEqual(controller.state, .dragging)
        XCTAssertNil(controller.edgeDwellDeadline)

        // 未武装的过期 timer → 无事件。
        XCTAssertEqual(controller.edgeTimerFired(geometry: geometry, layout: layout, catalogGeneration: 1), [])
    }

    func testEdgeFirstPageLeftEmitsAtFirstPageWithoutDwell() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()
        let geometry = twoAppGeometry(page: 0, pageCount: 1)

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        // 全局首页左缘 → atFirstPage，不武装 dwell。
        let events = controller.pointerMoved(to: DragPoint(x: 10, y: 40),
                                             geometry: geometry, layout: layout, catalogGeneration: 1)
        XCTAssertEqual(events, [.dragBegan, .edge(.edgeEntered(.left)), .edge(.atFirstPage(.left)),
                            .intentChanged(.insertion(index: 0))])
        XCTAssertEqual(controller.state, .dragging)
        XCTAssertNil(controller.edgeDwellDeadline)
    }

    func testEdgeLastPageRightEmitsAtLastPageWithoutDwell() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()
        let geometry = twoAppGeometry(page: 2, pageCount: 3)

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        // 全局末页右缘 → atLastPage，不武装 dwell。
        let events = controller.pointerMoved(to: DragPoint(x: 390, y: 40),
                                             geometry: geometry, layout: layout, catalogGeneration: 1)
        XCTAssertEqual(events, [.dragBegan, .edge(.edgeEntered(.right)), .edge(.atLastPage(.right)),
                                .intentChanged(.insertion(index: 2))])
        XCTAssertEqual(controller.state, .dragging)
        XCTAssertNil(controller.edgeDwellDeadline)
    }

    func testEdgeTimerFiredWhilePressedYieldsNoEvents() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()
        let geometry = twoAppGeometry(page: 0, pageCount: 3)

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        // pressed 态（未过阈值）无 edge timer 语义。
        XCTAssertEqual(controller.edgeTimerFired(geometry: geometry, layout: layout, catalogGeneration: 1), [])
        XCTAssertEqual(controller.state, .pressed)
    }

    func testEdgeTimerFiredWithStaleLayoutCancels() {
        let clock = FakeDragClock(0)
        let controller = makeController(clock: clock)
        let (layout, _) = makeTwoAppLayout()
        let stale = PersistentWorkspaceLayout(generation: LayoutGeneration(1),
                                              topLevelOrder: [.app(ref("app1")), .app(ref("app2"))],
                                              folders: [])
        // page 1（非首页）→ 左缘可武装 dwell。
        let geometry = twoAppGeometry(page: 1, pageCount: 3)

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        XCTAssertEqual(controller.pointerMoved(to: DragPoint(x: 10, y: 40),
                                               geometry: geometry, layout: layout, catalogGeneration: 1),
                       [.dragBegan, .edge(.edgeEntered(.left)), .edge(.dwellStarted(.left)),
                            .intentChanged(.insertion(index: 0))])
        XCTAssertEqual(controller.state, .edgeTurnPending)

        clock.current = 0.2
        // 统一 cancel 出口：dwell 已武装 → 先清 edge timer（dwellCancelled）再 cancel。
        let events = controller.edgeTimerFired(geometry: geometry, layout: stale, catalogGeneration: 1)
        XCTAssertEqual(events, [.edge(.dwellCancelled), .cancelled(.layoutChanged)])
        XCTAssertEqual(controller.state, .idle)
    }

    // MARK: - 8) commit 路径

    func testCommitTopLevelInsertionProducesNewLayout() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()
        let geometry = twoAppGeometry()

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        XCTAssertEqual(controller.pointerMoved(to: DragPoint(x: 50, y: 40),
                                              geometry: geometry, layout: layout, catalogGeneration: 1), [.dragBegan, .intentChanged(.insertion(index: 1))])
        // app2 右半区 → insertion(2) → 引擎换算后 M1 重排 → committed。
        let events = controller.pointerUp(at: DragPoint(x: 155, y: 40),
                                         geometry: geometry, layout: layout, catalogGeneration: 1)
        guard case .committed(let newLayout)? = events.first else {
            return XCTFail("expected .committed, got \(events)")
        }
        XCTAssertEqual(controller.state, .idle)
        XCTAssertNil(controller.activeTransaction)
        XCTAssertEqual(controller.lastOutcome, .committed(newLayout))
        XCTAssertEqual(newLayout.generation, LayoutGeneration(1))
        XCTAssertEqual(newLayout.topLevelOrder, [.app(ref("app2")), .app(ref("app1"))])
    }

    func testNoOpDropAtSameIndex() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()
        let geometry = twoAppGeometry()

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        XCTAssertEqual(controller.pointerMoved(to: DragPoint(x: 50, y: 40),
                                              geometry: geometry, layout: layout, catalogGeneration: 1), [.dragBegan, .intentChanged(.insertion(index: 1))])
        // 落回 app1 左半区 → insertion(0)（源不在槽位左侧 → 无换算）→ 原位 noOp（零写盘）。
        let events = controller.pointerUp(at: DragPoint(x: 5, y: 40),
                                         geometry: geometry, layout: layout, catalogGeneration: 1)
        XCTAssertEqual(events, [.noOp])
        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(controller.lastOutcome, .noOp)
    }

    func testDropBackOnOwnCellYieldsNoOp() {
        let controller = makeController()
        let (layout, _) = makeTwoAppLayout()
        let geometry = twoAppGeometry()

        XCTAssertEqual(controller.pointerDown(at: DragPoint(x: 40, y: 40),
                                              source: .topLevelApp(ref("app1")),
                                              layout: layout, catalogGeneration: 1), [.pressed])
        XCTAssertEqual(controller.pointerMoved(to: DragPoint(x: 50, y: 40),
                                              geometry: geometry, layout: layout, catalogGeneration: 1), [.dragBegan, .intentChanged(.insertion(index: 1))])
        // 落回源自身右半区 → 插到自身之后 → 生成 intent（无死区），引擎换算后
        // 原位 no-op（BUG6：源自身 cell 的 .invalid 死区已删除）。
        let events = controller.pointerUp(at: DragPoint(x: 60, y: 40),
                                         geometry: geometry, layout: layout, catalogGeneration: 1)
        XCTAssertEqual(events, [.noOp])
        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(controller.lastOutcome, .noOp)
    }
}
