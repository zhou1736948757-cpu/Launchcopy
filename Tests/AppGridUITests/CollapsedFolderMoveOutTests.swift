import AppCatalogCore
import XCTest
@testable import AppGridUI

final class CollapsedFolderMoveOutTests: XCTestCase {
    private let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000073")!)
    private let bounds = DragRect(x: 0, y: 0, width: 500, height: 300)
    private var members: [DragItemFrame] {
        [.init(identity: .app(ref("app1")), frame: .init(x: 400, y: 100, width: 40, height: 80)),
         .init(identity: .app(ref("app2")), frame: .init(x: 450, y: 100, width: 40, height: 80))]
    }
    private var top: [DragItemFrame] {
        [folderFrame(folderID, x: 0),
         .init(identity: .app(ref("target")), frame: .init(x: 100, y: 100, width: 80, height: 80))]
    }
    private var source: DragSourceIdentity { .folderMember(folderID: folderID, app: ref("app1")) }
    private func zones(collapsed: Bool, armed: Bool = true) -> DropZones {
        DropZoneBuilder.zones(itemFrames: members, topLevelFrames: top, containerWidth: 500,
            moveOutArmed: armed, parameters: .default, topLevelMoveOutBounds: collapsed ? bounds : nil)
    }

    func testCollapsedPresentationIgnoresHiddenMemberRowsAndAcceptsMainCellInterior() {
        XCTAssertEqual(DropZoneClassifier.classify(pointer: .init(x: 160, y: 140), source: source,
                                                  zones: zones(collapsed: true)), .topLevelTarget(index: 2))
        guard case .insertion = DropZoneClassifier.classify(pointer: .init(x: 160, y: 140),
            source: source, zones: zones(collapsed: false)) else {
            return XCTFail("Visible folder must retain internal ordering semantics")
        }
    }

    func testViewportBlankSpaceUsesNearestVisibleGridRowInsteadOfHiddenFolder() {
        XCTAssertEqual(DropZoneClassifier.classify(pointer: .init(x: 350, y: 250), source: source,
                                                  zones: zones(collapsed: true)), .topLevelTarget(index: 2))
    }

    func testOutsideViewportInvalidBoundsAndUnarmedModeRefuseLanding() {
        for point in [DragPoint(x: -1, y: 140), .init(x: 501, y: 140), .init(x: 160, y: 301)] {
            XCTAssertEqual(DropZoneClassifier.classify(pointer: point, source: source,
                zones: zones(collapsed: true)), .invalid)
        }
        var invalid = zones(collapsed: true)
        invalid.topLevelMoveOutBounds = .init(x: 0, y: 0, width: .infinity, height: 300)
        XCTAssertEqual(DropZoneClassifier.classify(pointer: .init(x: 160, y: 140), source: source,
                                                  zones: invalid), .invalid)
        XCTAssertEqual(DropZoneClassifier.classify(pointer: .init(x: 160, y: 140), source: source,
                                                  zones: zones(collapsed: true, armed: false)), .invalid)
    }

    func testVisibleExistingFolderRemainsAnIntoFolderTarget() {
        XCTAssertEqual(DropZoneClassifier.classify(pointer: .init(x: 40, y: 40), source: source,
            zones: zones(collapsed: true)), .intoFolder(target: folderID, at: .tail))
    }

    func testMainPageLogicalIndexMetadataIsNotReinterpretedAsInnerPage() {
        var z = zones(collapsed: true)
        z.topLevelFrames = [.init(identity: .app(ref("target")),
            frame: .init(x: 100, y: 100, width: 80, height: 80), pageIndex: 2, itemsPerPage: 35,
            logicalIndex: 74)]
        XCTAssertEqual(DropZoneClassifier.classify(pointer: .init(x: 160, y: 140), source: source,
                                                  zones: z), .topLevelTarget(index: 75))
    }

    func testDirectFirstEdgeExitRearmsSinglePageFolderForMultiPageMainGrid() {
        let layout = PersistentWorkspaceLayout(generation: .zero,
            topLevelOrder: [.folder(folderID), .app(ref("target"))],
            folders: [.init(id: folderID, title: "Synthetic", members: [ref("app1"), ref("app2")])])
        let clock = FakeDragClock()
        let controller = DragSessionController(clock: clock)
        _ = controller.pointerDown(at: .init(x: 420, y: 140), source: source, layout: layout, catalogGeneration: 1)
        let open = DragGeometry(itemFrames: members, topLevelFrames: top, containerWidth: 500,
                                page: 0, pageCount: 1)
        _ = controller.pointerMoved(to: .init(x: 498, y: 140), geometry: open,
                                    layout: layout, catalogGeneration: 1)
        XCTAssertNil(controller.edgeDwellDeadline, "A single-page folder has no next page")
        let collapsed = DragGeometry(itemFrames: [], topLevelFrames: top, containerWidth: 500,
            page: 0, pageCount: 2, topLevelMoveOutBounds: bounds)
        _ = controller.pointerMoved(to: .init(x: 498, y: 140), geometry: collapsed,
                                    layout: layout, catalogGeneration: 1)
        XCTAssertNotNil(controller.edgeDwellDeadline, "Same edge must rearm in the new visible pager")
        clock.current = 0.6
        let events = controller.edgeTimerFired(geometry: collapsed, layout: layout, catalogGeneration: 1)
        XCTAssertTrue(events.contains(.edge(.pageTurnRequested(.right))))
    }

    func testCollapsedPresentationKeepsMoveOutArmedWhenPointerRevisitsOldMemberPosition() {
        let layout = PersistentWorkspaceLayout(generation: .zero,
            topLevelOrder: [.folder(folderID), .app(ref("target"))],
            folders: [.init(id: folderID, title: "Synthetic", members: [ref("app1"), ref("app2")])])
        let controller = DragSessionController(clock: FakeDragClock())
        _ = controller.pointerDown(at: .init(x: 420, y: 140), source: source, layout: layout, catalogGeneration: 1)
        let open = DragGeometry(itemFrames: members, topLevelFrames: top, containerWidth: 500,
                                page: 0, pageCount: 1)
        _ = controller.pointerMoved(to: .init(x: 200, y: 140), geometry: open, layout: layout, catalogGeneration: 1)
        let collapsed = DragGeometry(itemFrames: [], topLevelFrames: top, containerWidth: 500,
            page: 0, pageCount: 2, topLevelMoveOutBounds: bounds)
        _ = controller.pointerMoved(to: .init(x: 421, y: 140), geometry: collapsed,
                                    layout: layout, catalogGeneration: 1)
        XCTAssertTrue(controller.moveOutArmed)
        XCTAssertEqual(controller.lastIntent, .topLevelTarget(index: 2))
        _ = controller.cancel(reason: .escape)
        XCTAssertEqual(controller.state, .idle)
        XCTAssertFalse(controller.moveOutArmed)
    }
}
