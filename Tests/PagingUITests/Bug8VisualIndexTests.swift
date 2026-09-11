// PagingUITests — Bug8VisualIndexTests（T-1F-B8-wave-v）
// BUG8 缺陷 1：蓝条钳位页末右缘——DragUIVisuals 消费全局 intent 下标但以页内
// frames 定位，page≥1 时全局下标 ≥ 页内帧数 → insertionRect clamp 末帧右缘
// = 网格右下角（BUG8-REPORT §1）。
// 修复契约：showInsertionBar 入口按帧注记回减 local = global − pageIndex ×
// itemsPerPage，clamp [0, frames.count]；注记 nil（page 0 / folder 成员帧 /
// 夹具直构）→ 原样。.insertion 与 .topLevelTarget 同修；insertionRect 页内
// 纯函数与 :176-178 clamp 保留（local == count = 页末右缘是正确位）。
// 页号陷阱锁：几何构造 committedPage(=1) ≠ geometry.page(innerPage=0)，
// 修复若误用 geometry.page 立即失败（绝不使用 geometry.page，只信帧注记）。
// fixture 全部中性合成（bundleID = "fixture.*"），无真实 app 身份。

import AppKit
import XCTest
@testable import AppGridUI

@MainActor
final class Bug8VisualIndexTests: XCTestCase {

    /// 与 BUG7 wave-b 定案一致的每页容量（7 列 × 5 行）。
    private let itemsPerPage = 35

    // MARK: - 工厂（夹具中性：单行 5 帧，pitch 90，帧宽/高 80）

    /// 页内帧（host 坐标系）：frame[i] = (x: i*90, y: 0, w: 80, h: 80)。
    /// bar 宽 3（insertionRect 常量）。
    private func pageFrames(count: Int, pageIndex: Int?, itemsPerPage annotation: Int?) -> [DragItemFrame] {
        (0..<count).map { i in
            let frame = DragRect(x: Double(i) * 90, y: 0, width: 80, height: 80)
            let item = DragItemFrame(identity: .app(PersistentAppReference.bundleID("fixture.bug8-\(i)")),
                                     frame: frame)
            if let pageIndex, let itemsPerPage = annotation {
                return item.annotated(pageIndex: pageIndex, itemsPerPage: itemsPerPage)
            }
            return item
        }
    }

    private func makeVisuals() -> (host: NSView, visuals: DragUIVisuals) {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let visuals = DragUIVisuals(host: host, reduceMotionProvider: { false })
        return (host, visuals)
    }

    /// 期望值：页内 local 下标 i 的中点插入带 x（帧 i-1/i 之间）。
    private func midpointX(_ i: Int) -> Double {
        let a = Double(i - 1) * 90 + 80   // frames[i-1].maxX
        let b = Double(i) * 90            // frames[i].minX
        return (a + b) / 2 - 1.5          // barWidth = 3
    }

    /// 末帧右缘 x（count 帧）。
    private func lastFrameRightX(_ count: Int) -> Double {
        Double(count - 1) * 90 + 80 - 3
    }

    private func assertBar(_ visuals: DragUIVisuals,
                           visible: Bool,
                           x: Double? = nil,
                           file: StaticString = #filePath,
                           line: UInt = #line) {
        XCTAssertEqual(visuals.isInsertionIndicatorVisible, visible, file: file, line: line)
        if let x {
            XCTAssertEqual(visuals.insertionIndicatorFrame.origin.x, CGFloat(x), accuracy: 0.001,
                           "bar x", file: file, line: line)
            XCTAssertEqual(visuals.insertionIndicatorFrame.size.width, 3, accuracy: 0.001,
                           "bar width", file: file, line: line)
            XCTAssertEqual(visuals.insertionIndicatorFrame.origin.y, 0, accuracy: 0.001,
                           "bar y", file: file, line: line)
            XCTAssertEqual(visuals.insertionIndicatorFrame.size.height, 80, accuracy: 0.001,
                           "bar height", file: file, line: line)
        }
    }

    // MARK: - ① page≥1 中部列：不钳位

    /// page 1（5 帧，全局 35-39，注记 1/35）：.insertion(global 38) → local 3
    /// → 竖条在第 3/4 帧之间（BUG8 修复前 38 ≥ 5 → 钳到末帧右缘 = 网格右下角）。
    func testPage1MiddleColumnInsertionBarSitsBetweenFrames34() {
        let (_, visuals) = makeVisuals()
        let frames = pageFrames(count: 5, pageIndex: 1, itemsPerPage: 35)
        let geometry = DragGeometry(itemFrames: frames, containerWidth: 600,
                                    page: 1, pageCount: 2, itemsPerPage: 35)
        visuals.updateIntent(.insertion(index: 38), geometry: geometry)
        assertBar(visuals, visible: true, x: midpointX(3))
        XCTAssertNotEqual(visuals.insertionIndicatorFrame.origin.x, CGFloat(lastFrameRightX(5)),
                          "不得钳位到末帧右缘（BUG8 症状）")
    }

    /// local<0 红旗（§8）：global 10 < 页起点 35 → clamp 0 → 首帧左缘，不越界。
    func testPage1GlobalBelowPageStartClampsToFirstFrameLeftEdge() {
        let (_, visuals) = makeVisuals()
        let frames = pageFrames(count: 5, pageIndex: 1, itemsPerPage: 35)
        let geometry = DragGeometry(itemFrames: frames, containerWidth: 600,
                                    page: 1, pageCount: 2, itemsPerPage: 35)
        visuals.updateIntent(.insertion(index: 10), geometry: geometry)
        XCTAssertEqual(visuals.insertionIndicatorFrame.origin.x, 0, accuracy: 0.001)
        XCTAssertTrue(visuals.isInsertionIndicatorVisible)
    }

    // MARK: - ② page≥1 末列右半：local == count → 末帧右缘正确位

    /// page 1（5 帧，全局 35-39）：.insertion(global 40) → local 5 == count
    /// → 末帧右缘（正确位，非回归钳位）。
    func testPage1AfterLastInsertionBarSitsAtLastFrameRightEdge() {
        let (_, visuals) = makeVisuals()
        let frames = pageFrames(count: 5, pageIndex: 1, itemsPerPage: 35)
        let geometry = DragGeometry(itemFrames: frames, containerWidth: 600,
                                    page: 1, pageCount: 2, itemsPerPage: 35)
        visuals.updateIntent(.insertion(index: 40), geometry: geometry)
        assertBar(visuals, visible: true, x: lastFrameRightX(5))
    }

    // MARK: - ③ page 0 全列行为不变（未注记 = 全局即页内）

    func testPage0UnannotatedInsertionBarBehaviorUnchanged() {
        let (_, visuals) = makeVisuals()
        let frames = pageFrames(count: 5, pageIndex: nil, itemsPerPage: nil)
        let geometry = DragGeometry(itemFrames: frames, containerWidth: 600,
                                    page: 0, pageCount: 2, itemsPerPage: 35)
        // 首帧左缘（index 0）。
        visuals.updateIntent(.insertion(index: 0), geometry: geometry)
        assertBar(visuals, visible: true, x: 0)
        // 中部（index 3：第 3/4 帧之间）。
        visuals.updateIntent(.insertion(index: 3), geometry: geometry)
        assertBar(visuals, visible: true, x: midpointX(3))
        // 末帧右缘（index == count）。
        visuals.updateIntent(.insertion(index: 5), geometry: geometry)
        assertBar(visuals, visible: true, x: lastFrameRightX(5))
        // 越界 clamp 行为不变（index 远超 count → 末帧右缘）。
        visuals.updateIntent(.insertion(index: 38), geometry: geometry)
        assertBar(visuals, visible: true, x: lastFrameRightX(5))
    }

    // MARK: - ④ folder 成员帧（未注记）不回归

    /// 成员帧绝不注记（AppDelegate :625 契约）：成员下标原样消费，
    /// 不被外层 itemsPerPage 放大/回减（BUG7 wave-b 回归锁延续到视觉层）。
    func testFolderMemberFramesUnannotatedIndexUnchanged() {
        let (_, visuals) = makeVisuals()
        let members = pageFrames(count: 5, pageIndex: nil, itemsPerPage: nil)
        let geometry = DragGeometry(itemFrames: members, containerWidth: 600,
                                    page: 0, pageCount: 1, itemsPerPage: 35)
        visuals.updateIntent(.insertion(index: 2), geometry: geometry)
        assertBar(visuals, visible: true, x: midpointX(2))
        // 成员帧下标在页内语义下越界 → 末帧右缘（原 clamp 语义，未注记原样）。
        visuals.updateIntent(.insertion(index: 7), geometry: geometry)
        assertBar(visuals, visible: true, x: lastFrameRightX(5))
    }

    // MARK: - ⑤ .topLevelTarget move-out（帧注记 topPage，页号陷阱锁）

    /// folder scope move-out 几何：committedPage(=1) ≠ geometry.page(innerPage=0)。
    /// topLevelFrames 注记 topPage=1 → .topLevelTarget(global 38) → local 3
    /// → 竖条在第 3/4 顶层帧之间；若误用 geometry.page(=0) 回减 → local 38
    /// → 钳末帧右缘 → 本测试失败（结构性锁死页号陷阱）。
    func testMoveOutTopLevelTargetSubtractsAnnotatedTopPageNotGeometryPage() {
        let (_, visuals) = makeVisuals()
        let members = pageFrames(count: 5, pageIndex: nil, itemsPerPage: nil)          // innerPage 帧（不注记）
        let topLevel = pageFrames(count: 5, pageIndex: 1, itemsPerPage: 35)            // committedPage=1 注记
        let geometry = DragGeometry(itemFrames: members, topLevelFrames: topLevel,
                                    containerWidth: 600,
                                    page: 0, pageCount: 1, itemsPerPage: 35)           // page = innerPage 陷阱位
        visuals.updateIntent(.topLevelTarget(index: 38), geometry: geometry)
        assertBar(visuals, visible: true, x: midpointX(3))
        XCTAssertNotEqual(visuals.insertionIndicatorFrame.origin.x, CGFloat(lastFrameRightX(5)),
                          "不得因 geometry.page=innerPage 而钳位")
    }

    // MARK: - ⑥ 未注记/空注记回退路径

    /// 空注记（注记不成对：pageIndex 有、itemsPerPage nil）→ 原样（全局语义，
    /// 与未注记一致；D 层成对注入，此为防御性回退）。
    func testPartialAnnotationFallsBackToUnchangedBehavior() {
        let (_, visuals) = makeVisuals()
        let frames: [DragItemFrame] = (0..<5).map { i in
            DragItemFrame(identity: .app(PersistentAppReference.bundleID("fixture.bug8-p-\(i)")),
                          frame: DragRect(x: Double(i) * 90, y: 0, width: 80, height: 80),
                          pageIndex: 1, itemsPerPage: nil)
        }
        let geometry = DragGeometry(itemFrames: frames, containerWidth: 600,
                                    page: 1, pageCount: 2, itemsPerPage: 35)
        visuals.updateIntent(.insertion(index: 38), geometry: geometry)
        assertBar(visuals, visible: true, x: lastFrameRightX(5))
    }

    /// 空 frames → 回退维持 hide（insertionRect 空列表返回 nil）。
    func testEmptyFramesKeepsInsertionIndicatorHidden() {
        let (_, visuals) = makeVisuals()
        let geometry = DragGeometry(itemFrames: [], containerWidth: 600,
                                    page: 1, pageCount: 2, itemsPerPage: 35)
        visuals.updateIntent(.insertion(index: 38), geometry: geometry)
        XCTAssertFalse(visuals.isInsertionIndicatorVisible)
        visuals.updateIntent(.topLevelTarget(index: 38), geometry: geometry)
        XCTAssertFalse(visuals.isInsertionIndicatorVisible)
    }

    /// .topLevelTarget 未注记 topLevelFrames（夹具直构）→ 原样（全局即页内）。
    func testTopLevelTargetUnannotatedFramesUnchanged() {
        let (_, visuals) = makeVisuals()
        let frames = pageFrames(count: 5, pageIndex: nil, itemsPerPage: nil)
        let geometry = DragGeometry(itemFrames: frames, containerWidth: 600,
                                    page: 0, pageCount: 2, itemsPerPage: 35)
        visuals.updateIntent(.topLevelTarget(index: 3), geometry: geometry)
        assertBar(visuals, visible: true, x: midpointX(3))
    }
}