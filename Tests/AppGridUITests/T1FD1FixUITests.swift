// AppGridUITests — T1FD1FixUITests（T-1F-D1-fix-ui：Defects 1/3/4 回归）
// 验证：
// - Defect 1: drag preview 显示源 cell 的迷你视觉副本（图标 + 名称），非纯文本；
//   preview 跟随 pointer（point.x - w/2, point.y + 24）。
// - Defect 3: 提交后 stale source 点击不被吞（coordinator 级回退派发 onCellClick）；
//   过阈值拖拽尝试 no-op；cancel/teardown 清除回退。
// - Defect 4: folder 成员点击链（overlay.mouseDown → coordinator.pointerDown →
//   controller .pressed → mouseUp 未过阈值 → .clicked → onCellClick）；提交后成员
//   stale → 回退派发（stale-source guard 是吞点位置，由 Defect-3 回退覆盖）。
//
// 全部 @MainActor；fixture 合成数据（fixture.*），无真实 app 身份。

import AppCatalogCore
import AppIconPipeline
import AppKit
import PagingUI
@testable import AppGridUI
import XCTest

@MainActor
final class T1FD1FixUITests: XCTestCase {

    private var retainedHost: NSView?

    override func tearDown() {
        retainedHost = nil
        super.tearDown()
    }

    private func makeParameters() -> DragParameters {
        DragParameters(dragStartThresholdPT: 6, edgeDwellDurationMs: 100, edgeZoneWidthPT: 40,
                       edgeHysteresisPT: 10, dropZoneMarginsPT: 8, overlayMoveOutArmThresholdPT: 24,
                       edgeTurnMinIntervalMs: 200, maxDragPreviewScale: 1.0)
    }

    private func makeHost() -> NSView {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        retainedHost = host
        return host
    }

    private func makeCoordinator(host: NSView) -> DragUISessionCoordinator {
        DragUISessionCoordinator(host: host, parameters: makeParameters(), clock: FakeDragClock(0))
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

    private func makeFolderID() -> FolderID {
        FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    }

    private func makeFolderLayout(folderID: FolderID, members: [String]) -> PersistentWorkspaceLayout {
        PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.folder(folderID)],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1",
                                             members: members.map { ref($0) })])
    }

    // MARK: - Defect 1: preview 显示源 cell 迷你视觉副本

    func testPreviewShowsSourceCellIconAndName() {
        let host = makeHost()
        let coordinator = makeCoordinator(host: host)
        let (layout, snapshot) = makeDragLayout(titles: ["app1", "app2"])
        coordinator.layoutProvider = { layout }
        coordinator.catalogSnapshotProvider = { snapshot }
        coordinator.geometryProvider = { _ in
            topLevelGeometry(frames: rowFrames([.app(ref("app1")), .app(ref("app2"))]))
        }

        let cell = makeAppCell("app1")
        let icon = makeIconImage()
        cell.iconView.image = icon

        var clicks: [AppGridCellView] = []
        coordinator.onCellClick = { clicks.append($0) }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        XCTAssertEqual(coordinator.controller.state, .pressed)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 50, y: 40))   // 10pt ≥ 6 → dragging
        XCTAssertEqual(coordinator.controller.state, .dragging)
        XCTAssertTrue(coordinator.visuals.isPreviewVisible)
        XCTAssertEqual(coordinator.visuals.previewNameText, "app1", "preview 显示源 cell 名称")
        // preview 使用 snapshot/durable 拷贝，不要求与源 NSImage 引用相同（===）。
        XCTAssertNotNil(coordinator.visuals.previewIconImage, "preview 显示源 cell 图标（耐久拷贝）")
        XCTAssertGreaterThan(coordinator.visuals.previewIconImage?.size.width ?? 0, 0)
        XCTAssertEqual(icon.size.width, 32, "源 fixture 图标仍注入 cell 供 snapshot")
        XCTAssertEqual(coordinator.visuals.previewFrame.size, NSSize(width: 96, height: 88),
                       "preview 为 cell 比例迷你块")

        // preview 跟随 pointer（point.x - w/2, point.y + 24）。
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 120, y: 60))
        XCTAssertEqual(coordinator.visuals.previewFrame.midX, 120, accuracy: 0.5)
        XCTAssertEqual(coordinator.visuals.previewFrame.minY, 84, accuracy: 0.5)

        coordinator.pointerUp(locationInWindow: NSPoint(x: 120, y: 60))
        XCTAssertEqual(clicks.count, 0, "拖拽路径不派发点击")
        XCTAssertFalse(coordinator.visuals.isPreviewVisible)
    }

    // MARK: - Defect 3: stale-source 点击回退

    func testStaleSourceClickDispatchesCellClick() {
        let host = makeHost()
        let coordinator = makeCoordinator(host: host)
        // 提交后布局：app1 已移入 folder → 顶层不再含 app1（stale source 场景）。
        // catalog 仍含 app1（resolveSource 成功）；layout 不含 app1（sourcePresent 拒绝）。
        let (_, snapshot) = makeDragLayout(titles: ["app1", "app2"])
        let layout = PersistentWorkspaceLayout(generation: .zero,
                                               topLevelOrder: [.app(ref("app2"))],
                                               folders: [])
        coordinator.layoutProvider = { layout }
        coordinator.catalogSnapshotProvider = { snapshot }

        let cell = makeAppCell("app1")
        var clicks: [AppGridCellView] = []
        coordinator.onCellClick = { clicks.append($0) }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        XCTAssertEqual(coordinator.controller.state, .idle, "stale source 不进入 pressed")
        XCTAssertTrue(coordinator.isSessionActive, "The stale click still owns a held physical pointer")
        coordinator.pointerUp(locationInWindow: NSPoint(x: 40, y: 40))
        XCTAssertFalse(coordinator.isSessionActive)
        XCTAssertEqual(clicks.count, 1, "stale-source 点击回退派发 onCellClick")
        if let first = clicks.first {
            XCTAssertTrue(first === cell)
        }
    }

    func testStaleSourceDragBeyondThresholdIsNoOp() {
        let host = makeHost()
        let coordinator = makeCoordinator(host: host)
        let (_, snapshot) = makeDragLayout(titles: ["app1", "app2"])
        let layout = PersistentWorkspaceLayout(generation: .zero,
                                               topLevelOrder: [.app(ref("app2"))],
                                               folders: [])
        coordinator.layoutProvider = { layout }
        coordinator.catalogSnapshotProvider = { snapshot }

        let cell = makeAppCell("app1")
        var clicks: [AppGridCellView] = []
        var commits: [PersistentWorkspaceLayout] = []
        coordinator.onCellClick = { clicks.append($0) }
        coordinator.onCommit = { commits.append($0) }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 50, y: 40))   // 10pt ≥ 6 → 清除回退
        coordinator.pointerUp(locationInWindow: NSPoint(x: 50, y: 40))
        XCTAssertEqual(clicks.count, 0, "stale-source 拖拽尝试 no-op（不派发点击）")
        XCTAssertEqual(commits.count, 0, "stale-source 拖拽尝试 no-op（不提交）")
    }

    func testFallbackClearedOnCancelAndTeardown() {
        let host = makeHost()
        let coordinator = makeCoordinator(host: host)
        let (_, snapshot) = makeDragLayout(titles: ["app1", "app2"])
        let layout = PersistentWorkspaceLayout(generation: .zero,
                                               topLevelOrder: [.app(ref("app2"))],
                                               folders: [])
        coordinator.layoutProvider = { layout }
        coordinator.catalogSnapshotProvider = { snapshot }

        let cell = makeAppCell("app1")
        var clicks: [AppGridCellView] = []
        coordinator.onCellClick = { clicks.append($0) }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        coordinator.cancel(reason: .escape)
        coordinator.pointerUp(locationInWindow: NSPoint(x: 40, y: 40))
        XCTAssertEqual(clicks.count, 0, "cancel 清除回退")

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        coordinator.teardown()
        coordinator.pointerUp(locationInWindow: NSPoint(x: 40, y: 40))
        XCTAssertEqual(clicks.count, 0, "teardown 清除回退")
    }

    // MARK: - Defect 4: folder 成员点击链（验证优先）

    func testFolderMemberClickChainWorks() {
        let host = makeHost()
        let coordinator = makeCoordinator(host: host)
        let folderID = makeFolderID()
        let layout = makeFolderLayout(folderID: folderID, members: ["app1", "app2"])
        let (_, snapshot) = makeDragLayout(titles: ["app1", "app2"])
        coordinator.layoutProvider = { layout }
        coordinator.catalogSnapshotProvider = { snapshot }

        let memberCell = makeAppCell("app1")
        var clicks: [AppGridCellView] = []
        coordinator.onCellClick = { clicks.append($0) }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40),
                                sourceCell: memberCell, memberFolderID: folderID)
        XCTAssertEqual(coordinator.controller.state, .pressed,
                       "成员源解析 + sourcePresent 通过 → pressed")
        XCTAssertTrue(coordinator.isSessionActive)
        coordinator.pointerUp(locationInWindow: NSPoint(x: 40, y: 40))
        XCTAssertEqual(clicks.count, 1, "成员点击 → .clicked → onCellClick")
        if let first = clicks.first {
            XCTAssertTrue(first === memberCell)
        }
    }

    func testStaleFolderMemberClickAfterCommitDispatchesFallback() {
        let host = makeHost()
        let coordinator = makeCoordinator(host: host)
        let folderID = makeFolderID()
        // 提交后：folder 成员只剩 app2（app1 被移出）→ 点击 app1 成员 stale。
        let layout = makeFolderLayout(folderID: folderID, members: ["app2"])
        let (_, snapshot) = makeDragLayout(titles: ["app1", "app2"])
        coordinator.layoutProvider = { layout }
        coordinator.catalogSnapshotProvider = { snapshot }

        let memberCell = makeAppCell("app1")
        var clicks: [AppGridCellView] = []
        coordinator.onCellClick = { clicks.append($0) }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 40, y: 40),
                                sourceCell: memberCell, memberFolderID: folderID)
        XCTAssertEqual(coordinator.controller.state, .idle, "stale 成员不进入 pressed")
        coordinator.pointerUp(locationInWindow: NSPoint(x: 40, y: 40))
        XCTAssertEqual(clicks.count, 1, "stale 成员点击回退派发 onCellClick")
        if let first = clicks.first {
            XCTAssertTrue(first === memberCell)
        }
    }

    func testOverlayMemberMouseDownRoutesToCoordinatorAndClicks() {
        let loader = GatedIconLoader()
        let pipeline = IconPipeline(loader: loader, limits: .init())
        defer { pipeline.shutdown() }
        let overlay = FolderOverlayView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = overlay
        overlay.layoutSubtreeIfNeeded()

        let ids = [makeAppID("fixture.member0"), makeAppID("fixture.member1")]
        let folderID = makeFolderID()
        let entry = FolderEntry(id: folderID, title: "Group 1", members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { id in
            id == ids[0] ? "Member0" : "Member1"
        }
        overlay.layoutSubtreeIfNeeded()

        let coordinator = makeCoordinator(host: overlay)
        overlay.dragCoordinator = coordinator
        let layout = makeFolderLayout(folderID: folderID, members: ["member0", "member1"])
        let (_, snapshot) = makeDragLayout(titles: ["member0", "member1"])
        coordinator.layoutProvider = { layout }
        coordinator.catalogSnapshotProvider = { snapshot }

        var clicks: [AppGridCellView] = []
        coordinator.onCellClick = { clicks.append($0) }

        guard let memberCell = overlay.memberCell(at: 0) else {
            XCTFail("no member cell")
            return
        }
        // §2c 验证步骤 1/2：成员 bindingToken 非 nil 且带 appID；currentEntry?.id 非 nil。
        XCTAssertNotNil(memberCell.bindingToken, "成员 cell bindingToken 非 nil")
        XCTAssertEqual(memberCell.bindingToken?.appID as? AppID, ids[0], "bindingToken 带成员 appID")
        XCTAssertEqual(overlay.currentEntry?.id, folderID, "currentEntry?.id 非 nil")

        // §2c 验证步骤 4：overlay.mouseDown → coordinator.pointerDown → controller .pressed。
        let windowPoint = memberCell.convert(NSPoint(x: memberCell.bounds.midX, y: memberCell.bounds.midY),
                                             to: nil)
        let event = NSEvent.mouseEvent(with: .leftMouseDown, location: windowPoint,
                                       modifierFlags: [], timestamp: 0,
                                       windowNumber: window.windowNumber, context: nil,
                                       eventNumber: 0, clickCount: 1, pressure: 1)!
        overlay.mouseDown(with: event)
        XCTAssertEqual(coordinator.controller.state, .pressed,
                       "overlay.mouseDown → coordinator.pointerDown → .pressed")
        XCTAssertTrue(coordinator.isSessionActive)

        // mouseUp 未过阈值 → .clicked → onCellClick（装配层 handleDragCellClick → launchMember 静态验证）。
        overlay.mouseUp(with: event)
        XCTAssertEqual(clicks.count, 1, "成员点击 → onCellClick")
        if let first = clicks.first {
            XCTAssertTrue(first === memberCell)
        }
    }
}
