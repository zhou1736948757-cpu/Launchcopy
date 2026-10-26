// AppGridUITests — FolderCellTests（Phase 1E §3.1C folder cell 渲染）
// 验证：folder cell 与 app cell 可区分；folder cell 显示中性符号 + 标题 + 成员计数；
// folder cell 绝不请求/写回 app 图标；复用清空 folder 标题/符号/成员计数/焦点；
// folder cell 无障碍（role/label/help）。
//
// 全部 @MainActor：视图主线程受限；IconPipeline 保证 onApply 在 MainActor 投递。
// fake loader（GatedIconLoader）；程序生成图像；绝不触碰真实 /Applications。

import AppCatalogCore
import AppIconPipeline
import AppKit
import PagingUI
@testable import AppGridUI
import XCTest

@MainActor
final class FolderCellTests: XCTestCase {

    private func makePage(loader: GatedIconLoader) -> (AppGridPageView, IconPipeline) {
        let pipeline = IconPipeline(loader: loader, limits: .init())
        let page = AppGridPageView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
        return (page, pipeline)
    }

    /// 构造含单个 folder 条目的页面内容（identity = FolderID）。
    private func makeFolderContent(revision: UInt64, page: Int, folderID: FolderID,
                                   title: String, itemsPerPage: Int = 35) -> PagingPageContent {
        let presentation = PagePresentationID(revision: revision, pageIndex: page)
        let item = PagingPageContentItem(slot: page * itemsPerPage,
                                         identity: AnyHashable(folderID), title: title)
        return PagingPageContent(presentationID: presentation, items: [item], isPlaceholder: false)
    }

    private func makeSnapshot(folderID: FolderID, title: String, members: [AppID]) -> FolderSnapshot {
        FolderSnapshot(generation: .zero,
                       entries: [FolderEntry(id: folderID, title: title, members: members)])
    }

    // MARK: - app vs folder 可区分

    func testFolderCellDistinctFromAppCell() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let folderID = FolderID()
        page.folderSnapshotProvider = {
            self.makeSnapshot(folderID: folderID, title: "Group 1",
                              members: [makeAppID("fixture.a"), makeAppID("fixture.b")])
        }
        page.render(pageIndex: 0,
                    content: makeFolderContent(revision: 1, page: 0, folderID: folderID, title: "Group 1"),
                    pageCount: 1, reuseGeneration: 1)

        let cell = try XCTUnwrap(page.cell(at: 0))
        XCTAssertTrue(cell.isFolderCell, "folder cell 与 app cell 可区分")
        XCTAssertTrue(cell.isFolderSymbolVisible, "folder cell 显示中性符号")
        XCTAssertEqual(cell.nameLabel.stringValue, "Group 1")
        await drainDeferredPresentationTurns()
        XCTAssertEqual(cell.memberCountText, "2 items", "folder cell 显示成员计数")
        XCTAssertEqual(loader.pendingKeyCount, 0, "folder cell 绝不请求 app 图标")
    }

    func testAppCellNotFolder() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let alphaID = makeAppID("fixture.alpha")
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: ["Alpha"], appIDs: [alphaID]),
                    pageCount: 1, reuseGeneration: 1)

        let cell = try XCTUnwrap(page.cell(at: 0))
        XCTAssertFalse(cell.isFolderCell)
        XCTAssertFalse(cell.isFolderSymbolVisible, "app cell 不显示 folder 符号")
        XCTAssertEqual(cell.memberCountText, "", "app cell 无成员计数")
    }

    // MARK: - 复用清空 folder 标题/符号/成员计数/焦点

    func testReuseClearsFolderTitleThumbnailFocus() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let folderID = FolderID()
        page.folderSnapshotProvider = {
            self.makeSnapshot(folderID: folderID, title: "Group 1",
                              members: [makeAppID("fixture.a"), makeAppID("fixture.b")])
        }
        page.render(pageIndex: 0,
                    content: makeFolderContent(revision: 1, page: 0, folderID: folderID, title: "Group 1"),
                    pageCount: 1, reuseGeneration: 1)
        let cell = try XCTUnwrap(page.cell(at: 0))
        cell.setFocused(true)
        XCTAssertTrue(cell.isFocused)

        page.clearForReuse()

        XCTAssertFalse(cell.isFolderCell, "复用清空 folder 标记")
        XCTAssertFalse(cell.isFolderSymbolVisible, "复用清空 folder 符号")
        XCTAssertEqual(cell.nameLabel.stringValue, "", "复用清空 folder 标题")
        XCTAssertEqual(cell.memberCountText, "", "复用清空成员计数")
        XCTAssertFalse(cell.isFocused, "复用清空焦点视觉")
        XCTAssertNil(cell.bindingToken, "复用清空 token")
    }

    // MARK: - folder cell 恒拒绝 app 图标写回

    func testFolderCellRejectsIconApply() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let folderID = FolderID()
        page.folderSnapshotProvider = {
            self.makeSnapshot(folderID: folderID, title: "Group 1",
                              members: [makeAppID("fixture.a"), makeAppID("fixture.b")])
        }
        page.render(pageIndex: 0,
                    content: makeFolderContent(revision: 1, page: 0, folderID: folderID, title: "Group 1"),
                    pageCount: 1, reuseGeneration: 1)
        let cell = try XCTUnwrap(page.cell(at: 0))
        let token = try XCTUnwrap(cell.bindingToken)

        let applied = cell.applyIconIfValid(makeIconImage(), token: token)
        XCTAssertFalse(applied, "folder cell 恒拒绝 app 图标写回")
        XCTAssertNil(cell.iconView.image, "folder cell 绝不显示 app 图标")
    }

    // MARK: - folder cell 无障碍

    func testFolderCellAccessibility() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let folderID = FolderID()
        page.folderSnapshotProvider = {
            self.makeSnapshot(folderID: folderID, title: "Group 1",
                              members: [makeAppID("fixture.a"), makeAppID("fixture.b")])
        }
        page.render(pageIndex: 0,
                    content: makeFolderContent(revision: 1, page: 0, folderID: folderID, title: "Group 1"),
                    pageCount: 1, reuseGeneration: 1)
        let cell = try XCTUnwrap(page.cell(at: 0))

        XCTAssertEqual(cell.accessibilityRole(), .button, "folder cell 可激活（role = button）")
        XCTAssertEqual(cell.accessibilityLabel(), "Group 1", "无障碍读完整标题")
        await drainDeferredPresentationTurns()
        XCTAssertEqual(cell.accessibilityHelp(), "Folder with 2 items", "无障碍描述成员计数")
    }

    // MARK: - folder cell 点击 → onFolderClick

    func testFolderCellClickFiresOnFolderClick() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let folderID = FolderID()
        page.folderSnapshotProvider = {
            self.makeSnapshot(folderID: folderID, title: "Group 1",
                              members: [makeAppID("fixture.a"), makeAppID("fixture.b")])
        }
        page.render(pageIndex: 0,
                    content: makeFolderContent(revision: 1, page: 0, folderID: folderID, title: "Group 1"),
                    pageCount: 1, reuseGeneration: 1)

        let cell = try XCTUnwrap(page.cell(at: 0))
        var received: FolderID?
        cell.onFolderClick = { received = $0 }

        cell.handleFolderClick(NSClickGestureRecognizer())

        XCTAssertEqual(received, folderID, "folder cell 点击触发 onFolderClick 且携带正确 FolderID")
    }

    func testAppCellClickDoesNotFireOnFolderClick() async throws {
        let loader = GatedIconLoader()
        let (page, pipeline) = makePage(loader: loader)
        defer { pipeline.shutdown() }

        let alphaID = makeAppID("fixture.alpha")
        page.render(pageIndex: 0,
                    content: makeContent(revision: 1, page: 0, titles: ["Alpha"], appIDs: [alphaID]),
                    pageCount: 1, reuseGeneration: 1)

        let cell = try XCTUnwrap(page.cell(at: 0))
        var fired = false
        cell.onFolderClick = { _ in fired = true }

        cell.handleFolderClick(NSClickGestureRecognizer())

        XCTAssertFalse(fired, "app cell 点击不触发 onFolderClick")
    }

    // MARK: - T-1E repair：大文件夹成员网格全部行可见（动态 pitch）

    /// 构造打开层并布局（frame 高度 900 → panelH = min(max(900*0.8,200),700) = 700，
    /// 复现全屏 700pt 面板场景）。
    private func makeOverlay(memberCount: Int) -> FolderOverlayView {
        let loader = GatedIconLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())
        let overlay = FolderOverlayView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
        let members = (0..<memberCount).map { makeAppID("fixture.member\($0)") }
        let entry = FolderEntry(id: FolderID(), title: "Group", members: members)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { _ in nil }
        overlay.frame = NSRect(x: 0, y: 0, width: 1000, height: 900)
        overlay.layout()
        return overlay
    }

    func testLargeFolderAllRowsVisibleInPanel() throws {
        // 35 成员（5 列 × 7 行）在 700pt 面板上：动态 pitch 使末行落在网格区内（可见）。
        let overlay = makeOverlay(memberCount: 35)
        XCTAssertEqual(overlay.memberCellCount, 35)

        let panel = overlay.panelFrame
        let panelBounds = NSRect(x: 0, y: 0, width: panel.width, height: panel.height)
        for index in 0..<overlay.memberCellCount {
            let cell = try XCTUnwrap(overlay.memberCell(at: index))
            XCTAssertTrue(panelBounds.contains(cell.frame),
                         "member \(index) frame \(cell.frame) 应在面板内 \(panelBounds)")
        }
        // 末行首格（index 30 = row 6, col 0）minY ≥ 面板底 → 可见，↓ 可卡在可见 cell 上。
        let lastCol0 = try XCTUnwrap(overlay.memberCell(at: 30))
        XCTAssertGreaterThanOrEqual(lastCol0.frame.minY, 0,
                                    "末行首格应落在面板内（可见），而非被裁到面板外")
    }

    func testSmallFolderKeepsFixedCellHeight() throws {
        // 13 成员（3 行）→ pitch 104 → cellHeight 88（无视觉变化）。
        let overlay = makeOverlay(memberCount: 13)
        let cell = try XCTUnwrap(overlay.memberCell(at: 0))
        XCTAssertEqual(cell.frame.height, 88, "小文件夹（3 行）保持固定 88pt cellHeight")
    }
}
