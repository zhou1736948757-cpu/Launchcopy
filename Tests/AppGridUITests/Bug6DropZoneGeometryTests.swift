// AppGridUITests — Bug6DropZoneGeometryTests（T-1F-B6-wave-a §2d）
// BUG6 缺陷 3+4 回归锁 + off-by-one 双方向锁。§2a 行为表规格：
// 左半→插前、右半→插后、正中→建夹（成员降级插入）、缝隙/空白/边距→最近插入位；
// 任何落点不得 .invalid（死区锁）。off-by-one 双方向：[A,B,C] A→B右=[B,A,C]；
// C→B左=[A,C,B]。中性夹具（fixture.* 计数器，无真实身份）。

import AppCatalogCore
import XCTest
@testable import AppGridUI

final class Bug6DropZoneGeometryTests: XCTestCase {

    private let folder1 = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)

    // MARK: - 工厂

    private func makeZones(itemFrames: [DragItemFrame],
                           topLevelFrames: [DragItemFrame]? = nil,
                           moveOutArmed: Bool = false,
                           containerWidth: Double = 400) -> DropZones {
        DropZoneBuilder.zones(itemFrames: itemFrames, topLevelFrames: topLevelFrames ?? itemFrames,
                              containerWidth: containerWidth, moveOutArmed: moveOutArmed,
                              parameters: .default)
    }

    private func row3() -> [DragItemFrame] {
        rowFrames([.app(ref("app1")), .app(ref("app2")), .app(ref("app3"))])
    }

    /// 3×2 网格：cell 80×80 @ x∈{10,110,210}, y∈{10,110}；containerWidth 400。
    private func gridFrames() -> [DragItemFrame] {
        let xs: [Double] = [10, 110, 210]
        let ys: [Double] = [10, 110]
        return (0..<6).map { i in
            DragItemFrame(identity: .app(ref("app\(i + 1)")),
                          frame: DragRect(x: xs[i % 3], y: ys[i / 3], width: 80, height: 80))
        }
    }

    /// 生产 y-up 网格（BUG10 缺陷 C 回归锁；镜像 FolderOverlayView.layoutPanel:444 /
    /// AppGridPageView.layout:303 的 `y = maxY - (row+1)*pitch`，5 列 / spacing 16 /
    /// cellHeight 88，复刻 FIX-PROMPT §2.2 几何；rowCounts 缺省 [5,3] = 8 成员 2 行）。
    private func productionYUpFrames(rowCounts: [Int] = [5, 3]) -> [DragItemFrame] {
        let maxY = 600.0
        let pitch = 104.0          // cellHeight 88 + spacing 16
        let xs: [Double] = [24.0, 127.2, 230.4, 333.6, 436.8]
        var frames: [DragItemFrame] = []
        for (row, count) in rowCounts.enumerated() {
            let y = maxY - Double(row + 1) * pitch
            for col in 0..<count {
                frames.append(DragItemFrame(
                    identity: .app(ref("yup\(frames.count + 1)")),
                    frame: DragRect(x: xs[col], y: y, width: 87.2, height: 88.0)))
            }
        }
        return frames
    }

    private func assertEngineSuccess(_ result: LayoutMutationResult,
                                     file: StaticString = #filePath,
                                     line: UInt = #line) -> PersistentWorkspaceLayout {
        guard case .success(let newLayout) = result else {
            XCTFail("expected .success, got \(result)", file: file, line: line)
            return PersistentWorkspaceLayout(generation: .zero, topLevelOrder: [], folders: [])
        }
        return newLayout
    }

    private func layout3() -> PersistentWorkspaceLayout {
        makeDragLayout(titles: ["app1", "app2", "app3"]).0
    }

    // MARK: - 1) §2a 行为表：B 左半/右半/正中（缺陷 3 回归锁）

    func testDragALeftHalfOfBInsertsBeforeB() {
        let zones = makeZones(itemFrames: row3())
        // B = app2（x 100-180）；(120,50) 左半区（中心内缩区 x∈[129.3,150.7) 之外）。
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 120, y: 50),
                                                 source: .topLevelApp(ref("app1")), zones: zones)
        XCTAssertEqual(intent, .insertion(index: 1))   // 插到 B 前（意图槽位）
        // A 本就紧邻 B 之前 → remove-then-insert 换算后原位 no-op（行为表第 1 行成立）。
        let result = DragMutationEngine.apply(intent: intent,
                                              source: .topLevelApp(ref("app1")), layout: layout3())
        guard case .noOp = result else { return XCTFail("expected .noOp, got \(result)") }
        XCTAssertEqual(layout3().topLevelOrder,
                       [.app(ref("app1")), .app(ref("app2")), .app(ref("app3"))])
    }

    func testDragARightHalfOfBInsertsAfterB() {
        let zones = makeZones(itemFrames: row3())
        // (155,50) B 右半区 → 蓝条在 B 右侧（缺陷 3 主症状：不再被中心 strip 吞掉）。
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 155, y: 50),
                                                 source: .topLevelApp(ref("app1")), zones: zones)
        XCTAssertEqual(intent, .insertion(index: 2))   // 插到 B 之后
        let newLayout = assertEngineSuccess(DragMutationEngine.apply(
            intent: intent, source: .topLevelApp(ref("app1")), layout: layout3()))
        XCTAssertEqual(newLayout.topLevelOrder,
                       [.app(ref("app2")), .app(ref("app1")), .app(ref("app3"))])
    }

    func testDragACenterOfBCreatesFolder() {
        let zones = makeZones(itemFrames: row3())
        // (140,50) B 正中内缩小方块 → 建夹；建夹指示与插入蓝条形状可区分（Q5）。
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 140, y: 50),
                                                 source: .topLevelApp(ref("app1")), zones: zones)
        XCTAssertEqual(intent, .createFolder(target: ref("app2")))
        // 建夹引擎路径：目标+源初始成员（先目标后源）。
        let newLayout = assertEngineSuccess(DragMutationEngine.apply(
            intent: intent, source: .topLevelApp(ref("app1")), layout: layout3()))
        XCTAssertEqual(newLayout.folders.count, 1)
        XCTAssertEqual(newLayout.folders[0].members, [ref("app2"), ref("app1")])
    }

    // MARK: - 2) 缺陷 4：folder 成员正中 → 降级插入（非 .invalid）

    func testFolderMemberCenterDegradesToInsertionNotInvalid() {
        let zones = makeZones(itemFrames: rowFrames([.app(ref("m1")), .app(ref("m2"))]))
        // (140,50) m2 正中内缩区；成员无建夹语义 → 降级半区插入（中线归右）。
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 140, y: 50),
                                                 source: .folderMember(folderID: folder1, app: ref("m1")),
                                                 zones: zones)
        XCTAssertNotEqual(intent, .invalid)
        XCTAssertEqual(intent, .insertion(index: 2))
    }

    // MARK: - 3) 死区回归锁（3×2 网格九宫格 + 缝隙 + 页边距全采样）

    func testDeadZoneLockNoSamplePointIsInvalid() {
        let frames = gridFrames()
        let zones = makeZones(itemFrames: frames)
        let source = DragSourceIdentity.topLevelApp(ref("app1"))
        var samples: [DragPoint] = []
        // 每格九宫格点（cell 内 12.5% / 50% / 87.5% 采样）。
        let offsets: [Double] = [10, 40, 70]
        for cell in frames {
            for dx in offsets {
                for dy in offsets {
                    samples.append(DragPoint(x: cell.frame.minX + dx, y: cell.frame.minY + dy))
                }
            }
        }
        // 列缝 x=100/200（行内）与行缝 y=100（含交点）。
        for x in [100.0, 200.0] {
            samples.append(DragPoint(x: x, y: 50))
            samples.append(DragPoint(x: x, y: 150))
            samples.append(DragPoint(x: x, y: 100))
        }
        samples.append(DragPoint(x: 50, y: 100))
        samples.append(DragPoint(x: 150, y: 100))
        samples.append(DragPoint(x: 250, y: 100))
        // 页边距（四边 + 角点 + 容器近缘）。
        for y in [50.0, 150.0] {
            samples.append(DragPoint(x: 5, y: y))
            samples.append(DragPoint(x: 395, y: y))
        }
        for x in [50.0, 150.0, 250.0] {
            samples.append(DragPoint(x: x, y: 5))
            samples.append(DragPoint(x: x, y: 195))
        }
        samples.append(DragPoint(x: 5, y: 5))
        samples.append(DragPoint(x: 395, y: 5))
        samples.append(DragPoint(x: 5, y: 195))
        samples.append(DragPoint(x: 395, y: 195))
        samples.append(DragPoint(x: 399, y: 50))
        samples.append(DragPoint(x: 50, y: 209))
        samples.append(DragPoint(x: 399, y: 209))

        var invalidPoints: [DragPoint] = []
        for point in samples {
            if case .invalid = DropZoneClassifier.classify(pointer: point, source: source, zones: zones) {
                invalidPoints.append(point)
            }
        }
        XCTAssertTrue(invalidPoints.isEmpty,
                      "死区回归：\(invalidPoints.count) 点为 .invalid，首点 (\(invalidPoints.first?.x ?? -1), \(invalidPoints.first?.y ?? -1))")
        // 行 1 首条目前。
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 5, y: 150), frames: frames), 3)
    }

    // MARK: - 4) off-by-one 双方向锁（§2c 方案 i，经 classifier → engine 全链）

    func testOffByOneFrontToBackARightOfBYieldsBAC() {
        // [A,B,C] 拖 A 到 B 右半 → .insertion(2) → 引擎换算 -1 → [B,A,C]。
        let zones = makeZones(itemFrames: row3())
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 155, y: 40),
                                                 source: .topLevelApp(ref("app1")), zones: zones)
        XCTAssertEqual(intent, .insertion(index: 2))
        let newLayout = assertEngineSuccess(
            DragMutationEngine.apply(intent: intent, source: .topLevelApp(ref("app1")), layout: layout3()))
        XCTAssertEqual(newLayout.topLevelOrder,
                       [.app(ref("app2")), .app(ref("app1")), .app(ref("app3"))])
    }

    func testOffByOneBackToFrontCLeftOfBYieldsACB() {
        // [A,B,C] 拖 C 到 B 左半 → .insertion(1)（源在槽位右侧 → 无换算）→ [A,C,B]。
        let zones = makeZones(itemFrames: row3())
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 120, y: 40),
                                                 source: .topLevelApp(ref("app3")), zones: zones)
        XCTAssertEqual(intent, .insertion(index: 1))
        let newLayout = assertEngineSuccess(
            DragMutationEngine.apply(intent: intent, source: .topLevelApp(ref("app3")), layout: layout3()))
        XCTAssertEqual(newLayout.topLevelOrder,
                       [.app(ref("app1")), .app(ref("app3")), .app(ref("app2"))])
    }

    func testFolderInternalOffByOneBothDirections() {
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.folder(folder1)],
            folders: [PersistentFolderRecord(id: folder1, title: "Group 1",
                                             members: [ref("m1"), ref("m2"), ref("m3")])])
        let zones = makeZones(itemFrames: rowFrames([.app(ref("m1")), .app(ref("m2")), .app(ref("m3"))]))
        // m1 → m2 右半：slot 2，from 0 < 2 → 1 → [m2, m1, m3]。
        let front = DropZoneClassifier.classify(pointer: DragPoint(x: 155, y: 40),
                                                source: .folderMember(folderID: folder1, app: ref("m1")),
                                                zones: zones)
        XCTAssertEqual(front, .insertion(index: 2))
        XCTAssertEqual(assertEngineSuccess(
            DragMutationEngine.apply(intent: front, source: .folderMember(folderID: folder1, app: ref("m1")),
                                     layout: layout)).folders[0].members,
                       [ref("m2"), ref("m1"), ref("m3")])
        // m3 → m2 左半：slot 1，from 2 不在槽位左侧 → 无换算 → [m1, m3, m2]。
        let back = DropZoneClassifier.classify(pointer: DragPoint(x: 120, y: 40),
                                               source: .folderMember(folderID: folder1, app: ref("m3")),
                                               zones: zones)
        XCTAssertEqual(back, .insertion(index: 1))
        XCTAssertEqual(assertEngineSuccess(
            DragMutationEngine.apply(intent: back, source: .folderMember(folderID: folder1, app: ref("m3")),
                                     layout: layout)).folders[0].members,
                       [ref("m1"), ref("m3"), ref("m2")])
    }

    // MARK: - 5) 顶层落点复用同一插入位函数（M5；armed）

    func testMoveOutLandingReusesMidpointCountOnTopLevelFrames() {
        // 成员行与顶层行分离：只有离开成员行带后的顶层落点才是 move-out。
        let memberFrames = [
            DragItemFrame(identity: .app(ref("m1")), frame: DragRect(x: 0, y: 200, width: 80, height: 80)),
        ]
        let topLevelFrames = rowFrames([.app(ref("app1")), .app(ref("app2")), .app(ref("app3"))])
        let zones = makeZones(itemFrames: memberFrames, topLevelFrames: topLevelFrames,
                              moveOutArmed: true)
        let source = DragSourceIdentity.folderMember(folderID: folder1, app: ref("m1"))
        XCTAssertEqual(DropZoneClassifier.classify(pointer: DragPoint(x: 5, y: 60),
                                                   source: source, zones: zones),
                       .topLevelTarget(index: 0))
        // 缝隙落点（top-level 格内深入区不产 M5 落点——与旧 landing 带语义一致）。
        XCTAssertEqual(DropZoneClassifier.classify(pointer: DragPoint(x: 175, y: 60),
                                                   source: source, zones: zones),
                       .topLevelTarget(index: 2))
        // 深入顶层条目内部：不是合法缝隙落点，且已离开成员行 → .invalid（不再 nearest-row 乱卡蓝条）。
        XCTAssertEqual(DropZoneClassifier.classify(pointer: DragPoint(x: 120, y: 20),
                                                   source: source, zones: zones),
                       .invalid)
        XCTAssertEqual(DropZoneClassifier.classify(pointer: DragPoint(x: 395, y: 60),
                                                   source: source, zones: zones),
                       .topLevelTarget(index: 3))
        // 仍在成员行带内 → 即使 armed 也只能内部插入（防解散）。
        XCTAssertEqual(DropZoneClassifier.classify(pointer: DragPoint(x: 40, y: 240),
                                                   source: source, zones: zones),
                       .insertion(index: 1))
    }

    // MARK: - 6) 纯函数：阅读行中点计数（含首前/末后/缝隙/空白/边距）

    func testInsertionIndexReadingRowsAndMargins() {
        let frames = gridFrames()
        // 首条目前 / 末条目后（行 0）。
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 5, y: 50), frames: frames), 0)
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 395, y: 50), frames: frames), 3)
        // 行 1 首条目前 / 行 1 缝隙。
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 5, y: 150), frames: frames), 3)
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 60, y: 150), frames: frames), 4)
        // 行缝：竖距平手 → 取更早行（行 0）。
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 100, y: 100), frames: frames), 1)
        // 空帧 → 0。
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 0, y: 0), frames: []), 0)
        // 命中/未命中共用一致性：B 左半 (120,50) → 1；右半 (155,50) → 2。
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 120, y: 50), frames: row3()), 1)
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 155, y: 50), frames: row3()), 2)
    }

    // MARK: - 7) BUG10 缺陷 C 回归锁：生产 y-up 网格（坐标系无关行划分）

    /// 主症状锁：右列最上条目（idx4）右缘外 → 期望该条目之后（index 5），
    /// 不得越界取末帧右缘（修前 = 8 → insertionRect 蓝条落到下一行正中）。
    func testYUpRightColumnTopItemRightEdgeOutsideInsertsAfterIt() {
        let frames = productionYUpFrames()
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 530, y: 540), frames: frames), 5)
    }

    /// 多行缝隙落点（≥3 行）：各行缝隙 → 该行行首 + 行内中点计数（行序 = 阅读序）。
    func testYUpMultiRowGapLandings() {
        let frames = productionYUpFrames(rowCounts: [5, 5, 3])
        // 行 0（y 496..584）首条目前。
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 5, y: 540), frames: frames), 0)
        // 行 1（y 392..480）首条目前 / 行 1 缝隙（x=120 位于 idx5 与 idx6 之间，中点 67.6 左侧）。
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 5, y: 436), frames: frames), 5)
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 120, y: 436), frames: frames), 6)
        // 行 2（y 288..376）首条目前。
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 5, y: 332), frames: frames), 10)
        // 行缝（y=488 与行 0/1 等距，平距取更早行 = 行 0）：x=100 位于 idx1 中点 170.8 左侧。
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 100, y: 488), frames: frames), 1)
    }

    /// 闭区间边界锁：insertionIndex 恒在 [0, count]（修前 y-up 下越界 = 8）。
    func testYUpInsertionIndexStaysWithinClosedRange() {
        let frames = productionYUpFrames()
        let xs: [Double] = [5, 60, 100, 200, 300, 400, 500, 530, 600]
        let ys: [Double] = [540, 488, 436, 332, 200, 100]
        for x in xs {
            for y in ys {
                let index = DropZoneGeometry.insertionIndex(pointer: DragPoint(x: x, y: y), frames: frames)
                XCTAssertTrue(index >= 0 && index <= frames.count,
                              "index \(index) out of [0, \(frames.count)] at (\(x), \(y))")
            }
        }
    }

    /// 顶层同构锁：AppGridPageView 同构 y-up 场景（顶层 3 行，行序 = 阅读序）。
    func testYUpTopLevelIsomorphicGrid() {
        let frames = productionYUpFrames(rowCounts: [5, 5, 3])
        // 行 0 首条目前 / 行 0 末条目后。
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 5, y: 540), frames: frames), 0)
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 600, y: 540), frames: frames), 5)
        // 行 1 首条目前 / 行 2 首条目前（行序 = 阅读序，range.lowerBound 即更早行条目总数）。
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 5, y: 436), frames: frames), 5)
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 5, y: 332), frames: frames), 10)
        // 末行末条目后 = count（闭区间上界）。
        XCTAssertEqual(DropZoneGeometry.insertionIndex(pointer: DragPoint(x: 600, y: 332), frames: frames), 13)
    }
}