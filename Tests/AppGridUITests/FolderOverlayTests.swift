// AppGridUITests — FolderOverlayTests（Phase 1E §3.1C 文件夹打开层）
// 验证：configure 渲染标题 + 成员网格；configure 幂等（不重复请求图标）；
// 打开 A 后打开 B：A 的旧成员图标回调被 generation 拒绝（无 cross-overwrite）；
// 点击面板外 → onRequestClose（只关闭文件夹）；点击成员 → onActivateMember；
// 点击面板非成员区 → 忽略；teardown 后零 UI 写回；Reduce Motion 参数路径正确；
// clearContent 清空状态。
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
final class FolderOverlayTests: XCTestCase {

    private func makeOverlay(loader: GatedIconLoader) -> (FolderOverlayView, IconPipeline) {
        let pipeline = IconPipeline(loader: loader, limits: .init())
        let overlay = FolderOverlayView(iconPipeline: pipeline, iconPointSize: 32, displayScale: 1)
        return (overlay, pipeline)
    }

    private func makeEntry(id: FolderID = FolderID(), title: String = "Group 1",
                           members: [AppID]) -> FolderEntry {
        FolderEntry(id: id, title: title, members: members)
    }

    private func makeIDs(_ count: Int) -> [AppID] {
        (0..<count).map { makeAppID("fixture.member\($0)") }
    }

    private func nameMap(_ ids: [AppID]) -> [AppID: String] {
        var map: [AppID: String] = [:]
        for (i, id) in ids.enumerated() { map[id] = "Member\(i)" }
        return map
    }

    // MARK: - configure 渲染

    func testConfigureRendersTitleAndMembers() async throws {
        let loader = GatedIconLoader()
        let (overlay, pipeline) = makeOverlay(loader: loader)
        defer { pipeline.shutdown() }

        let ids = makeIDs(3)
        let map = nameMap(ids)
        let entry = makeEntry(members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { map[$0] }

        XCTAssertEqual(overlay.memberCellCount, 3)
        XCTAssertEqual(overlay.memberCell(at: 0)?.nameLabel.stringValue, "Member0")
        XCTAssertEqual(overlay.memberCell(at: 2)?.nameLabel.stringValue, "Member2")
        XCTAssertEqual(overlay.currentEntry?.id, entry.id)
        XCTAssertEqual(overlay.currentInnerPage, 0)
        XCTAssertEqual(overlay.accessibilityLabel(), "Group 1", "打开层标题可读")
    }

    func testConfigureInnerPageShowsCorrectMembers() async throws {
        let loader = GatedIconLoader()
        let (overlay, pipeline) = makeOverlay(loader: loader)
        defer { pipeline.shutdown() }

        let ids = makeIDs(7)
        let map = nameMap(ids)
        let entry = makeEntry(title: "G", members: ids)
        overlay.membersPerPage = 3
        overlay.configure(entry: entry, innerPage: 1, reduceMotion: false) { map[$0] }

        XCTAssertEqual(overlay.memberCellCount, 3, "内部页 1 显示 3 个成员")
        XCTAssertEqual(overlay.memberCell(at: 0)?.nameLabel.stringValue, "Member3")
        XCTAssertEqual(overlay.memberCell(at: 2)?.nameLabel.stringValue, "Member5")
        XCTAssertEqual(overlay.memberAppID(at: 0), ids[3])
    }

    // MARK: - configure 幂等

    func testConfigureIdempotentNoDuplicateIconRequests() async throws {
        let loader = GatedIconLoader()
        let (overlay, pipeline) = makeOverlay(loader: loader)
        defer { pipeline.shutdown() }

        let ids = makeIDs(2)
        let map = nameMap(ids)
        let entry = makeEntry(members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { map[$0] }
        await waitForPendingLoads(loader, count: 2)
        XCTAssertEqual(loader.pendingKeyCount, 2)

        let gen = overlay.surfaceGeneration
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { map[$0] }
        XCTAssertEqual(overlay.surfaceGeneration, gen, "幂等：状态未变不 bump generation")
        XCTAssertEqual(loader.pendingKeyCount, 2, "幂等：不重复请求图标")
    }

    // MARK: - 打开 A 后打开 B：A 的旧成员图标回调被拒（无 cross-overwrite）

    func testOpenAThenOpenBNoCrossOverwrite() async throws {
        let loader = GatedIconLoader()
        let (overlay, pipeline) = makeOverlay(loader: loader)
        defer { pipeline.shutdown() }

        let recorder = ApplyRecorder()
        let rejected = expectation(description: "A's old member icon rejected")
        overlay.onIconApplyResult = { token, result in
            recorder.record(token, result)
            if case .rejectedStale = result { rejected.fulfill() }
        }

        // A 与 B 成员集必须不相交（否则同 key 合并，B 的图标会合法落地）。
        let aIDs = (0..<2).map { makeAppID("fixture.a\($0)") }
        let bIDs = (0..<2).map { makeAppID("fixture.b\($0)") }
        let aMap = nameMap(aIDs)
        let bMap = nameMap(bIDs)
        let entryA = makeEntry(title: "A", members: aIDs)
        let entryB = makeEntry(title: "B", members: bIDs)

        overlay.configure(entry: entryA, innerPage: 0, reduceMotion: false) { aMap[$0] }
        await waitForPendingLoads(loader, count: 2)
        // 打开 B：bump generation，请求 B 的成员图标
        overlay.configure(entry: entryB, innerPage: 0, reduceMotion: false) { bMap[$0] }
        await waitForPendingLoads(loader, count: 4)

        // 完成 A 的旧成员图标 → 门控拒绝（stale），绝不写回 B
        let keyA0 = IconKey(identity: IconIdentity.from(appID: aIDs[0]), pointSize: 32, displayScale: 1)
        loader.complete(key: keyA0, image: makeIconImage(r: 200, g: 0, b: 0))
        await fulfillment(of: [rejected], timeout: 3)

        XCTAssertEqual(recorder.count(.rejectedStale), 1, "A 的旧成员图标 apply 被拒")
        XCTAssertEqual(recorder.count(.applied), 0, "A 的旧成员图标绝不写回 B")
        XCTAssertEqual(overlay.memberCell(at: 0)?.nameLabel.stringValue, "Member0", "B 的成员名不受 A 影响")
        XCTAssertEqual(overlay.currentEntry?.id, entryB.id)
    }

    // MARK: - 点击处理

    func testClickOutsideClosesFolder() async throws {
        let loader = GatedIconLoader()
        let (overlay, pipeline) = makeOverlay(loader: loader)
        defer { pipeline.shutdown() }

        var closeCount = 0
        overlay.onRequestClose = { closeCount += 1 }
        overlay.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        overlay.layout()

        overlay.handleClick(at: NSPoint(x: 5, y: 5))  // 面板外（遮罩区）
        XCTAssertEqual(closeCount, 1, "点击面板外 → 只关闭文件夹")
    }

    func testClickMemberActivates() async throws {
        let loader = GatedIconLoader()
        let (overlay, pipeline) = makeOverlay(loader: loader)
        defer { pipeline.shutdown() }

        let ids = makeIDs(1)
        let map = nameMap(ids)
        let entry = makeEntry(members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { map[$0] }
        overlay.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        overlay.layout()

        var activated: AppID?
        overlay.onActivateMember = { activated = $0 }
        let cell = try XCTUnwrap(overlay.memberCell(at: 0))
        // cell frame 在 panel 坐标系 → 转换到 overlay 坐标系
        let cellCenter = NSPoint(x: overlay.panelFrame.minX + cell.frame.midX,
                                 y: overlay.panelFrame.minY + cell.frame.midY)
        overlay.handleClick(at: cellCenter)
        XCTAssertEqual(activated, ids[0], "点击成员 cell → 激活该成员")
    }

    func testClickPanelNonMemberIgnored() async throws {
        let loader = GatedIconLoader()
        let (overlay, pipeline) = makeOverlay(loader: loader)
        defer { pipeline.shutdown() }

        let ids = makeIDs(1)
        let map = nameMap(ids)
        let entry = makeEntry(members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { map[$0] }
        overlay.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        overlay.layout()

        var closeCount = 0
        var activated = false
        overlay.onRequestClose = { closeCount += 1 }
        overlay.onActivateMember = { _ in activated = true }

        // 面板内、非成员区（标题区顶部）→ 忽略
        let titlePoint = NSPoint(x: overlay.panelFrame.midX, y: overlay.panelFrame.maxY - 10)
        overlay.handleClick(at: titlePoint)
        XCTAssertEqual(closeCount, 0, "面板内非成员区不关闭")
        XCTAssertFalse(activated, "面板内非成员区不激活")
    }

    func testVisualOnlyModeSuppressesInputAndRestoresCallbacks() async throws {
        let loader = GatedIconLoader()
        let (overlay, pipeline) = makeOverlay(loader: loader)
        defer { pipeline.shutdown() }

        let ids = makeIDs(1)
        let map = nameMap(ids)
        let entry = makeEntry(members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { map[$0] }
        overlay.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        overlay.layout()

        var activated: AppID?
        var closeCount = 0
        var pageChanges = 0
        overlay.onActivateMember = { activated = $0 }
        overlay.onRequestClose = { closeCount += 1 }
        overlay.onInnerPageChange = { _ in pageChanges += 1 }

        overlay.setVisualOnly(true)
        XCTAssertTrue(overlay.isVisualOnly)
        XCTAssertNil(overlay.hitTest(NSPoint(x: 5, y: 5)), "退出视觉层不参与 hit-test")

        overlay.handleClick(at: NSPoint(x: 5, y: 5))
        overlay.prevPage()
        overlay.nextPage()
        XCTAssertNil(activated, "退出视觉层不激活成员")
        XCTAssertEqual(closeCount, 0, "退出视觉层不关闭文件夹")
        XCTAssertEqual(pageChanges, 0, "退出视觉层不翻内部页")

        // 恢复后 callback 身份不丢失，且当前内容仍可交互。
        overlay.setVisualOnly(false)
        XCTAssertFalse(overlay.isVisualOnly)
        let cell = try XCTUnwrap(overlay.memberCell(at: 0))
        let cellCenter = NSPoint(x: overlay.panelFrame.minX + cell.frame.midX,
                                 y: overlay.panelFrame.minY + cell.frame.midY)
        overlay.handleClick(at: cellCenter)
        XCTAssertEqual(activated, ids[0], "恢复交互后成员 callback 回来")
    }

    func testVisualOnlySuppressesLateIconWriteAndRebindsOnResume() async throws {
        let loader = GatedIconLoader()
        let (overlay, pipeline) = makeOverlay(loader: loader)
        defer { pipeline.shutdown() }

        let ids = makeIDs(1)
        let entry = makeEntry(members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { _ in "Member" }
        await waitForPendingLoads(loader, count: 1)
        let key = IconKey(identity: IconIdentity.from(appID: ids[0]), pointSize: 32, displayScale: 1)
        let oldImage = makeIconImage(r: 220, g: 0, b: 0)

        overlay.setVisualOnly(true)
        loader.complete(key: key, image: oldImage)
        await Task.yield()
        XCTAssertNil(overlay.memberCell(at: 0)?.iconView.image,
                     "visual-only 期间的 one-shot 图标结果不写入冻结视图")

        overlay.setVisualOnly(false)
        await waitForPendingLoads(loader, count: 1)
        let resumedImage = makeIconImage(r: 0, g: 180, b: 0)
        loader.complete(key: key, image: resumedImage)
        await Task.yield()
        XCTAssertNotNil(overlay.memberCell(at: 0)?.iconView.image,
                        "恢复交互后重新绑定并接收图标")
    }

    func testClearContentRestoresMoveOutStateWhileVisualOnly() async throws {
        let loader = GatedIconLoader()
        let (overlay, pipeline) = makeOverlay(loader: loader)
        defer { pipeline.shutdown() }

        overlay.configure(entry: makeEntry(members: makeIDs(2)), innerPage: 0, reduceMotion: false) { _ in
            "Member"
        }
        overlay.setMoveOutPresentationCollapsed(true)
        XCTAssertTrue(overlay.isMoveOutPresentationCollapsed)

        // This is the retained exit-visual cleanup order used by AppDelegate: freeze first,
        // then clear after the visual has been detached.
        overlay.setVisualOnly(true)
        overlay.clearContent()

        XCTAssertFalse(overlay.isMoveOutPresentationCollapsed,
                       "清空冻结退出视觉后不得把折叠状态带到下一次复用")
        XCTAssertNil(overlay.currentEntry)
    }

    // MARK: - teardown 零写回

    func testTeardownZeroCallbacks() async throws {
        let loader = GatedIconLoader()
        let (overlay, pipeline) = makeOverlay(loader: loader)
        defer { pipeline.shutdown() }

        let recorder = ApplyRecorder()
        let ignored = expectation(description: "ignored after teardown")
        overlay.onIconApplyResult = { token, result in
            recorder.record(token, result)
            if case .ignoredAfterTeardown = result { ignored.fulfill() }
        }

        let ids = makeIDs(1)
        let map = nameMap(ids)
        let entry = makeEntry(members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { map[$0] }
        overlay.teardown()

        let key = IconKey(identity: IconIdentity.from(appID: ids[0]), pointSize: 32, displayScale: 1)
        await waitForPendingLoads(loader, count: 1)
        loader.complete(key: key, image: makeIconImage())
        await fulfillment(of: [ignored], timeout: 3)

        XCTAssertEqual(recorder.count(.ignoredAfterTeardown), 1)
        XCTAssertEqual(recorder.count(.applied), 0, "teardown 后零 UI 写回")
        XCTAssertEqual(recorder.count(.rejectedStale), 0)
        XCTAssertEqual(overlay.memberCellCount, 0)
    }

    // MARK: - Reduce Motion 路径

    func testReduceMotionParams() {
        XCTAssertEqual(FolderOverlayView.MotionParams.forReduceMotion(true), .reduceMotion)
        XCTAssertEqual(FolderOverlayView.MotionParams.forReduceMotion(false), .standard)
        XCTAssertEqual(FolderOverlayView.MotionParams.reduceMotion.duration, 0.18, "RM：180ms 淡入淡出")
        XCTAssertEqual(FolderOverlayView.MotionParams.reduceMotion.scale, 1, "RM：无缩放")
        XCTAssertEqual(FolderOverlayView.MotionParams.reduceMotion.displacement, 0, "RM：无位移")
        XCTAssertGreaterThan(FolderOverlayView.MotionParams.standard.duration, 0, "标准：短时动画")
    }

    func testConfigureReduceMotionFlag() async throws {
        let loader = GatedIconLoader()
        let (overlay, pipeline) = makeOverlay(loader: loader)
        defer { pipeline.shutdown() }

        let ids = makeIDs(1)
        let map = nameMap(ids)
        let entry = makeEntry(members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: true) { map[$0] }
        XCTAssertTrue(overlay.reduceMotion, "Reduce Motion 标志被记录")
    }

    // MARK: - clearContent 清空状态

    func testClearContentClearsState() async throws {
        let loader = GatedIconLoader()
        let (overlay, pipeline) = makeOverlay(loader: loader)
        defer { pipeline.shutdown() }

        let ids = makeIDs(2)
        let map = nameMap(ids)
        let entry = makeEntry(members: ids)
        overlay.configure(entry: entry, innerPage: 0, reduceMotion: false) { map[$0] }
        XCTAssertEqual(overlay.memberCell(at: 0)?.nameLabel.stringValue, "Member0")

        overlay.clearContent()
        XCTAssertNil(overlay.currentEntry)
        XCTAssertEqual(overlay.currentInnerPage, 0)
        XCTAssertEqual(overlay.memberCell(at: 0)?.nameLabel.stringValue, "", "清空后无旧成员名")
        XCTAssertFalse(overlay.memberCell(at: 0)?.isFolderCell ?? true)
    }
}
