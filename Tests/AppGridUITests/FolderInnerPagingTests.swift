// AppGridUITests — FolderInnerPagingTests（Phase 1E §3.1C 内部分页隔离）
// 验证：内部分页完全独立于外层 PagingCore 状态（FolderOpenState 只维护 innerPage，
// 无外层页字段；overlay 内部分页只触发 onInnerPageChange，绝不驱动/污染外层）；
// 内部分页导航（next/prev → onInnerPageChange）；resize/fullscreen 布局合法。
//
// 全部 @MainActor：视图主线程受限；IconPipeline 保证 onApply 在 MainActor 投递。

import AppCatalogCore
import AppIconPipeline
import AppKit
import PagingUI
@testable import AppGridUI
import XCTest

@MainActor
final class FolderInnerPagingTests: XCTestCase {

    private func makeOverlay(loader: GatedIconLoader) -> (FolderOverlayView, IconPipeline) {
        let pipeline = IconPipeline(loader: loader, limits: .init())
        let overlay = FolderOverlayView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
        return (overlay, pipeline)
    }

    private func makeIDs(_ count: Int) -> [AppID] {
        (0..<count).map { makeAppID("fixture.member\($0)") }
    }

    private func nameMap(_ ids: [AppID]) -> [AppID: String] {
        var map: [AppID: String] = [:]
        for (i, id) in ids.enumerated() { map[id] = "Member\(i)" }
        return map
    }

    // MARK: - 内部分页隔离于外层

    /// FolderOpenState 只维护 innerPage，无任何外层页字段；setInnerPage 绝不触碰外层。
    func testFolderOpenStateHasNoOuterPageState() {
        let state = FolderOpenState(membersPerPage: 3)
        let entry = FolderEntry(id: FolderID(), title: "G", members: makeIDs(7))
        state.open(entry)
        state.setInnerPage(1)
        XCTAssertEqual(state.innerPage, 1)
        XCTAssertEqual(state.innerPageCount, 3)
        // 外层 committed page 由 PagingCore 独占；FolderOpenState 不暴露任何外层页状态/变更。
        // 编译期保证：本类型 API 面只有 open/close/setInnerPage/members/innerPageCount。
        XCTAssertEqual(state.members(onPage: 1).count, 3)
    }

    /// overlay 内部分页只触发 onInnerPageChange；不存在任何外层分页回调/驱动。
    func testInnerPagingOnlyFiresInnerPageChange() async throws {
        let loader = GatedIconLoader()
        let (overlay, pipeline) = makeOverlay(loader: loader)
        defer { pipeline.shutdown() }

        let ids = makeIDs(7)
        let map = nameMap(ids)
        let entry = FolderEntry(id: FolderID(), title: "G", members: ids)
        overlay.membersPerPage = 3
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { map[$0] }

        var innerPages: [Int] = []
        overlay.onInnerPageChange = { innerPages.append($0) }
        overlay.nextPage()
        XCTAssertEqual(innerPages, [1], "内部分页只触发 onInnerPageChange")
        // 无外层分页回调可触发（overlay 不暴露 onOuterPageChange）。
    }

    // MARK: - 内部分页导航

    func testInnerPagingNavigation() async throws {
        let loader = GatedIconLoader()
        let (overlay, pipeline) = makeOverlay(loader: loader)
        defer { pipeline.shutdown() }

        let ids = makeIDs(7)
        let map = nameMap(ids)
        let entry = FolderEntry(id: FolderID(), title: "G", members: ids)
        overlay.membersPerPage = 3
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { map[$0] }

        var innerPages: [Int] = []
        // 模拟装配层：onInnerPageChange 写回 FolderOpenState 并重新 configure（overlay 自身不翻页）。
        overlay.onInnerPageChange = { page in
            innerPages.append(page)
            overlay.configure(entry: entry, innerPage: page, reduceMotion: false) { map[$0] }
        }
        overlay.nextPage()   // currentInnerPage 0 → 上报 1
        overlay.nextPage()   // currentInnerPage 1 → 上报 2
        overlay.prevPage()   // currentInnerPage 2 → 上报 1
        XCTAssertEqual(innerPages, [1, 2, 1], "next/prev 按当前内部页 ±1 上报")
    }

    // MARK: - resize / fullscreen 布局合法

    func testResizeLayoutLegal() async throws {
        let loader = GatedIconLoader()
        let (overlay, pipeline) = makeOverlay(loader: loader)
        defer { pipeline.shutdown() }

        let ids = makeIDs(5)
        let map = nameMap(ids)
        let entry = FolderEntry(id: FolderID(), title: "G", members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { map[$0] }

        // fullscreen 尺寸
        overlay.frame = NSRect(x: 0, y: 0, width: 1920, height: 1080)
        overlay.layout()
        assertPanelAndCellsWithinBounds(overlay)

        // 常规窗口
        overlay.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
        overlay.layout()
        assertPanelAndCellsWithinBounds(overlay)

        // 小窗口（面板 clamp 到最小尺寸，仍合法）
        overlay.frame = NSRect(x: 0, y: 0, width: 320, height: 240)
        overlay.layout()
        assertPanelAndCellsWithinBounds(overlay)
    }

    private func assertPanelAndCellsWithinBounds(_ overlay: FolderOverlayView,
                                                 file: StaticString = #filePath,
                                                 line: UInt = #line) {
        let panel = overlay.panelFrame
        XCTAssertGreaterThanOrEqual(panel.minX, 0, file: file, line: line)
        XCTAssertGreaterThanOrEqual(panel.minY, 0, file: file, line: line)
        XCTAssertLessThanOrEqual(panel.maxX, overlay.bounds.width + 0.5, file: file, line: line)
        XCTAssertLessThanOrEqual(panel.maxY, overlay.bounds.height + 0.5, file: file, line: line)
        for i in 0..<overlay.memberCellCount {
            guard let cell = overlay.memberCell(at: i) else { continue }
            // cell frame 在 panel 坐标系 → 必须落在 panel 内
            XCTAssertGreaterThanOrEqual(cell.frame.minX, 0, file: file, line: line)
            XCTAssertGreaterThanOrEqual(cell.frame.minY, 0, file: file, line: line)
            XCTAssertLessThanOrEqual(cell.frame.maxX, panel.width + 0.5, file: file, line: line)
            XCTAssertLessThanOrEqual(cell.frame.maxY, panel.height + 0.5, file: file, line: line)
        }
    }
}
