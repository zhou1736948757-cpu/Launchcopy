// PagingUITests — Bug11RowBoundaryIndicatorTests（T-1F-B11）
// 跨行插入槽的蓝条锚点回归：DropIntent 的线性 index 保持不变，视觉层
// 结合当前 pointer 选择上一行右缘或下一行左缘。
// fixture 全部为合成数据，不读取真实应用或图标。

import AppCatalogCore
import AppKit
import XCTest
@testable import AppGridUI
@testable import PagingUI

@MainActor
final class Bug11RowBoundaryIndicatorTests: XCTestCase {

    private let barWidth = 3.0
    private let frameWidth = 87.2
    private let frameHeight = 88.0
    private let columnPitch = 103.2
    private let firstColumnX = 24.0
    private let rowPitch = 104.0

    // MARK: - fixtures

    /// 复刻 BUG10 几何 census：5 列生产网格首行有 5 项、次行有 3 项。
    /// y-up 阅读序：首行 y=496，次行 y=392；y-down 镜像则为 y=0/104。
    private func makeFrames(rowCounts: [Int] = [5, 3],
                            yUp: Bool = true,
                            annotation: (page: Int, itemsPerPage: Int)? = nil)
        -> [DragItemFrame] {
        var frames: [DragItemFrame] = []
        var itemIndex = 0
        for (row, count) in rowCounts.enumerated() {
            let y = yUp ? 600.0 - rowPitch - Double(row) * rowPitch
                        : Double(row) * rowPitch
            for column in 0..<count {
                let item = DragItemFrame(
                    identity: .app(.bundleID("fixture.bug11-item\(itemIndex)")),
                    frame: DragRect(x: firstColumnX + Double(column) * columnPitch,
                                    y: y, width: frameWidth, height: frameHeight))
                if let annotation {
                    frames.append(item.annotated(pageIndex: annotation.page,
                                                 itemsPerPage: annotation.itemsPerPage))
                } else {
                    frames.append(item)
                }
                itemIndex += 1
            }
        }
        return frames
    }

    private func makeGeometry(itemFrames: [DragItemFrame],
                              topLevelFrames: [DragItemFrame]? = nil,
                              page: Int = 0,
                              pageCount: Int = 1,
                              itemsPerPage: Int = 35) -> DragGeometry {
        DragGeometry(itemFrames: itemFrames,
                     topLevelFrames: topLevelFrames,
                     containerWidth: 700,
                     page: page,
                     pageCount: pageCount,
                     itemsPerPage: itemsPerPage)
    }

    private func makeVisuals() -> (host: NSView, visuals: DragUIVisuals) {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 700))
        let visuals = DragUIVisuals(host: host, reduceMotionProvider: { true })
        return (host, visuals)
    }

    private func assertBar(_ visuals: DragUIVisuals,
                           x: Double,
                           y: Double,
                           height: Double,
                           file: StaticString = #filePath,
                           line: UInt = #line) {
        XCTAssertTrue(visuals.isInsertionIndicatorVisible, "蓝条应可见", file: file, line: line)
        XCTAssertEqual(visuals.insertionIndicatorFrame.origin.x, CGFloat(x), accuracy: 0.001,
                       "bar x", file: file, line: line)
        XCTAssertEqual(visuals.insertionIndicatorFrame.origin.y, CGFloat(y), accuracy: 0.001,
                       "bar y", file: file, line: line)
        XCTAssertEqual(visuals.insertionIndicatorFrame.size.width, CGFloat(barWidth), accuracy: 0.001,
                       "bar width", file: file, line: line)
        XCTAssertEqual(visuals.insertionIndicatorFrame.size.height, CGFloat(height), accuracy: 0.001,
                       "bar height", file: file, line: line)
    }

    private func midpointX(for index: Int) -> Double {
        let previousMaxX = firstColumnX + Double(index - 1) * columnPitch + frameWidth
        let nextMinX = firstColumnX + Double(index) * columnPitch
        return (previousMaxX + nextMinX) / 2 - barWidth / 2
    }

    private func makeCoordinatorFixture(frames: [DragItemFrame])
        -> (coordinator: DragUISessionCoordinator,
            host: NSView,
            cell: AppGridCellView,
            layout: PersistentWorkspaceLayout,
            catalog: CatalogSnapshot,
            geometry: DragGeometry) {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 700))
        let coordinator = DragUISessionCoordinator(
            host: host,
            parameters: DragParameters(
                dragStartThresholdPT: 6,
                edgeDwellDurationMs: 500,
                edgeZoneWidthPT: 5,
                edgeHysteresisPT: 2,
                dropZoneMarginsPT: 8,
                overlayMoveOutArmThresholdPT: 24,
                edgeTurnMinIntervalMs: 400,
                maxDragPreviewScale: 1),
            reduceMotionProvider: { true })

        let sourceID = AppID.bundleIdentifier("fixture.bug11-source")
        let sourceReference = PersistentAppReference.bundleID("fixture.bug11-source")
        let sourceRecord = CatalogFixture.record(
            id: sourceID,
            displayName: "Source",
            bundleID: "fixture.bug11-source",
            url: URL(fileURLWithPath: "/tmp/fixture-bug11-source.app"),
            icon: IconIdentity.from(appID: sourceID),
            rootPriority: 0)
        let catalog = CatalogSnapshot(revision: CatalogRevision(1), records: [sourceRecord])
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.app(sourceReference)],
            folders: [])
        let geometry = makeGeometry(itemFrames: frames)

        let cell = AppGridCellView(frame: NSRect(x: 0, y: 0, width: 80, height: 80))
        cell.bind(name: "Source", token: ItemBindingToken(
            catalogRevision: 1,
            pageIdentity: PagePresentationID(revision: 1, pageIndex: 0),
            itemSlot: 0,
            appID: AnyHashable(sourceID),
            reuseGeneration: 0,
            iconKey: nil,
            surfaceGeneration: 0))

        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in geometry }
        return (coordinator, host, cell, layout, catalog, geometry)
    }

    private func makeFolderCoordinatorFixture()
        -> (coordinator: DragUISessionCoordinator,
            host: NSView,
            cell: AppGridCellView,
            sourceFolder: FolderID,
            targetFolder: FolderID) {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 700))
        let coordinator = DragUISessionCoordinator(
            host: host,
            parameters: DragParameters(
                dragStartThresholdPT: 6,
                edgeDwellDurationMs: 500,
                edgeZoneWidthPT: 5,
                edgeHysteresisPT: 2,
                dropZoneMarginsPT: 8,
                overlayMoveOutArmThresholdPT: 24,
                edgeTurnMinIntervalMs: 400,
                maxDragPreviewScale: 1),
            reduceMotionProvider: { true })

        let sourceID = AppID.bundleIdentifier("fixture.bug11-member")
        let sourceReference = PersistentAppReference.bundleID("fixture.bug11-member")
        let catalog = CatalogSnapshot(revision: CatalogRevision(1), records: [
            CatalogFixture.record(
                id: sourceID,
                displayName: "Member",
                bundleID: "fixture.bug11-member",
                url: URL(fileURLWithPath: "/tmp/fixture-bug11-member.app"),
                icon: IconIdentity.from(appID: sourceID),
                rootPriority: 0)
        ])
        let sourceFolder = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!)
        let targetFolder = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!)
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.folder(sourceFolder), .folder(targetFolder)],
            folders: [
                PersistentFolderRecord(id: sourceFolder, title: "Source", members: [sourceReference]),
                PersistentFolderRecord(id: targetFolder, title: "Target", members: [])
            ])
        let memberFrame = DragItemFrame(
            identity: .app(sourceReference),
            frame: DragRect(x: firstColumnX, y: 496, width: frameWidth, height: frameHeight))
        let targetFrame = DragItemFrame(
            identity: .folder(targetFolder),
            frame: DragRect(x: 200, y: 496, width: frameWidth, height: frameHeight))
        let geometry = DragGeometry(itemFrames: [memberFrame],
                                    topLevelFrames: [targetFrame],
                                    containerWidth: 700,
                                    page: 0,
                                    pageCount: 1)

        let cell = AppGridCellView(frame: NSRect(x: 0, y: 0, width: 80, height: 80))
        cell.bind(name: "Member", token: ItemBindingToken(
            catalogRevision: 1,
            pageIdentity: PagePresentationID(revision: 1, pageIndex: 0),
            itemSlot: 0,
            appID: AnyHashable(sourceID),
            reuseGeneration: 0,
            iconKey: nil,
            surfaceGeneration: 0))

        coordinator.layoutProvider = { layout }
        coordinator.catalogGenerationProvider = { 1 }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in geometry }
        return (coordinator, host, cell, sourceFolder, targetFolder)
    }

    // MARK: - y-up cross-row index 5

    /// 行末 frame[4] 右半命中时，分类仍为 index 5，但蓝条应锚定 frame[4] 右缘。
    func testYUpLastColumnRightHalfUsesPreviousRowRightEdge() {
        let (_, visuals) = makeVisuals()
        let frames = makeFrames()
        let pointer = DragPoint(x: 510, y: 540)
        let zones = DropZones(itemFrames: frames, marginPT: 8)
        let source = DragSourceIdentity.topLevelApp(.bundleID("fixture.bug11-source"))

        XCTAssertEqual(DropZoneGeometry.hitItem(pointer: pointer, frames: frames)?.index, 4)
        let intent = DropZoneClassifier.classify(pointer: pointer, source: source, zones: zones)
        XCTAssertEqual(intent, .insertion(index: 5))

        visuals.updateIntent(intent, geometry: makeGeometry(itemFrames: frames), pointer: pointer)
        assertBar(visuals, x: 521, y: 496, height: 88)
        XCTAssertNotEqual(visuals.insertionIndicatorFrame,
                          NSRect(x: 272.5, y: 392, width: 3, height: 88),
                          "不得使用跨行相邻帧中点")
    }

    /// 同一 index 5 也可由下一行首项左半产生，蓝条必须切换到 frame[5] 左缘。
    func testYUpSameInsertionIndexUsesNextRowLeftEdgeWhenPointerMovesThere() {
        let (_, visuals) = makeVisuals()
        let frames = makeFrames()
        let pointer = DragPoint(x: 40, y: 436)
        let source = DragSourceIdentity.topLevelApp(.bundleID("fixture.bug11-source"))
        let intent = DropZoneClassifier.classify(
            pointer: pointer,
            source: source,
            zones: DropZones(itemFrames: frames, marginPT: 8))
        XCTAssertEqual(intent, .insertion(index: 5))

        visuals.updateIntent(intent, geometry: makeGeometry(itemFrames: frames), pointer: pointer)
        // 与首项左侧 insertion 的既有 4pt inset 一致：24 - 4 = 20。
        assertBar(visuals, x: 20, y: 392, height: 88)
    }

    /// 真实 coordinator 路径：第二次 pointerDragged 不改变 intent，却必须重刷蓝条锚点。
    func testCoordinatorRefreshesSameIndexWhenPointerChangesRows() {
        let frames = makeFrames()
        let fixture = makeCoordinatorFixture(frames: frames)
        let coordinator = fixture.coordinator
        defer { coordinator.teardown() }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 30, y: 40),
                                 sourceCell: fixture.cell,
                                 memberFolderID: nil)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 510, y: 540))
        XCTAssertEqual(coordinator.controller.state, .dragging)
        XCTAssertEqual(coordinator.controller.lastIntent, .insertion(index: 5))
        assertBar(coordinator.visuals, x: 521, y: 496, height: 88)

        // frame[5] 左半：intent index 仍为 5，但视觉行应跟随 pointer。
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 40, y: 436))
        XCTAssertEqual(coordinator.controller.lastIntent, .insertion(index: 5),
                       "跨行两侧共享同一个 insertion index")
        assertBar(coordinator.visuals, x: 20, y: 392, height: 88)
        XCTAssertEqual(fixture.layout.generation, .zero, "视觉刷新不得改 layout generation")
    }

    /// frame[4] 右缘外空白仍由 BUG10-C 分类为 index 5；视觉锚点保持上一行右缘。
    func testYUpBlankPastLastColumnPreservesBug10InsertionIndexAndAnchor() {
        let (_, visuals) = makeVisuals()
        let frames = makeFrames()
        let pointer = DragPoint(x: 530, y: 540)
        let source = DragSourceIdentity.topLevelApp(.bundleID("fixture.bug11-source"))
        let intent = DropZoneClassifier.classify(
            pointer: pointer,
            source: source,
            zones: DropZones(itemFrames: frames, marginPT: 8))
        XCTAssertEqual(intent, .insertion(index: 5))

        visuals.updateIntent(intent, geometry: makeGeometry(itemFrames: frames), pointer: pointer)
        assertBar(visuals, x: 521, y: 496, height: 88)
    }

    /// public 兼容入口没有 pointer 时也不能回到跨行中点；使用前帧右缘 canonical fallback。
    func testPublicUpdateIntentUsesPreviousRowRightEdgeWithoutPointer() {
        let (_, visuals) = makeVisuals()
        let frames = makeFrames()
        visuals.updateIntent(.insertion(index: 5), geometry: makeGeometry(itemFrames: frames))
        assertBar(visuals, x: 521, y: 496, height: 88)
    }

    /// 非 insertion 视觉只在 intentChanged 时更新：同一 create-folder intent 不逐帧重建。
    func testCoordinatorDoesNotRefreshCreateFolderForUnchangedIntent() {
        let frames = makeFrames()
        let fixture = makeCoordinatorFixture(frames: frames)
        let coordinator = fixture.coordinator
        defer { coordinator.teardown() }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 30, y: 40),
                                 sourceCell: fixture.cell,
                                 memberFolderID: nil)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 510, y: 540))
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 67.6, y: 540))
        XCTAssertTrue(coordinator.visuals.isCreateFolderIndicatorVisible)
        let refreshesAfterIntentChange = coordinator.visuals.pointerAwareRefreshCountForTesting

        coordinator.pointerDragged(locationInWindow: NSPoint(x: 67.6, y: 540))
        XCTAssertEqual(coordinator.controller.lastIntent, .createFolder(
            target: .bundleID("fixture.bug11-item0")))
        XCTAssertEqual(coordinator.visuals.pointerAwareRefreshCountForTesting,
                       refreshesAfterIntentChange,
                       "create-folder 在 intent 未变时不得逐帧重建")
    }

    /// 同一结构性门也覆盖 into-folder：folder 高亮不应被 pointerDragged 重复刷新。
    func testCoordinatorDoesNotRefreshIntoFolderForUnchangedIntent() {
        let fixture = makeFolderCoordinatorFixture()
        let coordinator = fixture.coordinator
        defer { coordinator.teardown() }

        coordinator.pointerDown(locationInWindow: NSPoint(x: 30, y: 40),
                                 sourceCell: fixture.cell,
                                 memberFolderID: fixture.sourceFolder)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 243.6, y: 540))
        XCTAssertEqual(coordinator.controller.lastIntent,
                       .intoFolder(target: fixture.targetFolder, at: .tail))
        XCTAssertTrue(coordinator.visuals.isFolderHighlightVisible)
        let refreshesAfterIntentChange = coordinator.visuals.pointerAwareRefreshCountForTesting

        coordinator.pointerDragged(locationInWindow: NSPoint(x: 243.6, y: 540))
        XCTAssertEqual(coordinator.visuals.pointerAwareRefreshCountForTesting,
                       refreshesAfterIntentChange,
                       "into-folder 在 intent 未变时不得逐帧重建")
    }

    // MARK: - same-row and boundary controls

    func testSameRowFirstMiddleTailAndEmptyFramesRemainUnchanged() {
        let (_, visuals) = makeVisuals()
        let frames = makeFrames(rowCounts: [5])
        let geometry = makeGeometry(itemFrames: frames)

        visuals.updateIntent(.insertion(index: 0), geometry: geometry,
                             pointer: DragPoint(x: 10, y: 540))
        assertBar(visuals, x: 20, y: 496, height: 88)

        visuals.updateIntent(.insertion(index: 3), geometry: geometry,
                             pointer: DragPoint(x: 300, y: 540))
        assertBar(visuals, x: midpointX(for: 3), y: 496, height: 88)

        visuals.updateIntent(.insertion(index: 5), geometry: geometry,
                             pointer: DragPoint(x: 600, y: 540))
        assertBar(visuals, x: 521, y: 496, height: 88)

        visuals.updateIntent(.insertion(index: 0), geometry: makeGeometry(itemFrames: []),
                             pointer: DragPoint(x: 10, y: 540))
        XCTAssertFalse(visuals.isInsertionIndicatorVisible, "empty frames 保持隐藏")
    }

    // MARK: - .topLevelTarget + page 1 global index

    func testTopLevelTargetUsesAnnotatedPageAndCrossRowAnchor() {
        let (_, visuals) = makeVisuals()
        let topLevel = makeFrames(annotation: (page: 1, itemsPerPage: 35))
        let members = makeFrames()
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!)
        let source = DragSourceIdentity.folderMember(
            folderID: folderID,
            app: .bundleID("fixture.bug11-source"))
        let zones = DropZones(itemFrames: members,
                              topLevelFrames: topLevel,
                              moveOutArmed: true,
                              marginPT: 8)
        let geometry = makeGeometry(itemFrames: members,
                                    topLevelFrames: topLevel,
                                    page: 0,
                                    pageCount: 1)

        // 行末右侧空白：local 5，换算为 page 1 的 global 40。
        let previousPointer = DragPoint(x: 530, y: 540)
        XCTAssertEqual(DropZoneClassifier.classify(pointer: previousPointer,
                                                    source: source,
                                                    zones: zones),
                       .topLevelTarget(index: 40))
        visuals.updateIntent(.topLevelTarget(index: 40), geometry: geometry,
                             pointer: previousPointer)
        assertBar(visuals, x: 521, y: 496, height: 88)

        // 同一 global index 的下一行首项左侧落点：local 5 仍不变，锚到 frame[5] 左缘。
        let nextPointer = DragPoint(x: 20, y: 436)
        XCTAssertEqual(DropZoneClassifier.classify(pointer: nextPointer,
                                                    source: source,
                                                    zones: zones),
                       .topLevelTarget(index: 40))
        visuals.updateIntent(.topLevelTarget(index: 40), geometry: geometry,
                             pointer: nextPointer)
        assertBar(visuals, x: 20, y: 392, height: 88)
    }

    // MARK: - y-down mirror and tie rule

    func testYDownMirrorChoosesNearestRowAndEarlierRowOnTie() {
        let (_, visuals) = makeVisuals()
        let frames = makeFrames(yUp: false)
        let source = DragSourceIdentity.topLevelApp(.bundleID("fixture.bug11-source"))
        let geometry = makeGeometry(itemFrames: frames)

        let previousPointer = DragPoint(x: 510, y: 40)
        XCTAssertEqual(DropZoneClassifier.classify(pointer: previousPointer,
                                                    source: source,
                                                    zones: DropZones(itemFrames: frames, marginPT: 8)),
                       .insertion(index: 5))
        visuals.updateIntent(.insertion(index: 5), geometry: geometry, pointer: previousPointer)
        assertBar(visuals, x: 521, y: 0, height: 88)

        let nextPointer = DragPoint(x: 40, y: 144)
        visuals.updateIntent(.insertion(index: 5), geometry: geometry, pointer: nextPointer)
        assertBar(visuals, x: 20, y: 104, height: 88)

        // gap = 16pt，y=96 到两行边界均为 8pt；阅读序较早的首行获胜。
        visuals.updateIntent(.insertion(index: 5), geometry: geometry,
                             pointer: DragPoint(x: 500, y: 96))
        assertBar(visuals, x: 521, y: 0, height: 88)
    }
}
