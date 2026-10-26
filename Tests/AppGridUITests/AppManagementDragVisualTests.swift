import AppCatalogCore
import AppKit
import PagingUI
import XCTest
@testable import AppGridUI

@MainActor
final class AppManagementDragVisualTests: XCTestCase {
    func testMappedTopLevelMemberAndMoveOutBarsUseDisplayedBoundaries() {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let visuals = DragUIVisuals(host: host, reduceMotionProvider: { true })
        defer { visuals.teardown() }
        let frames = zip(rowFrames([.app(ref("a")), .app(ref("b")), .app(ref("c"))]), [1, 3, 5])
            .map { $0.0.mapped(toLogicalIndex: $0.1).annotated(pageIndex: 4, itemsPerPage: 35) }
        let geometry = topLevelGeometry(frames: frames)
        for intent in [DropIntent.insertion(index: 1), .topLevelTarget(index: 1)] {
            visuals.updateIntent(intent, geometry: geometry)
            XCTAssertTrue(visuals.isInsertionIndicatorVisible)
            XCTAssertEqual(visuals.insertionIndicatorFrame.minX, 0)
        }
        for index in [2, 3] {
            visuals.updateIntent(.insertion(index: index), geometry: geometry)
            XCTAssertEqual(visuals.insertionIndicatorFrame.minX, 88.5)
        }
        for index in [4, 5] {
            visuals.updateIntent(.insertion(index: index), geometry: geometry)
            XCTAssertEqual(visuals.insertionIndicatorFrame.minX, 188.5)
        }
        visuals.updateIntent(.insertion(index: 6), geometry: geometry)
        XCTAssertEqual(visuals.insertionIndicatorFrame.minX, 277)
        // Folder-member frames have no outer page annotation, but the same gaps.
        let members = frames.map { DragItemFrame(identity: $0.identity, frame: $0.frame, logicalIndex: $0.logicalIndex) }
        visuals.updateIntent(.insertion(index: 3), geometry: folderGeometry(memberFrames: members, topLevelFrames: []))
        XCTAssertEqual(visuals.insertionIndicatorFrame.minX, 88.5)
    }

    func testMappedCrossRowBarKeepsPointerChosenRow() {
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let visuals = DragUIVisuals(host: host, reduceMotionProvider: { true })
        defer { visuals.teardown() }
        let frames = [
            DragItemFrame(identity: .app(ref("a")), frame: .init(x: 100, y: 0, width: 80, height: 80), logicalIndex: 3),
            DragItemFrame(identity: .app(ref("b")), frame: .init(x: 20, y: 100, width: 80, height: 80), logicalIndex: 8)
        ]
        let geometry = topLevelGeometry(frames: frames)
        visuals.updateIntent(.insertion(index: 4), geometry: geometry, pointer: .init(x: 170, y: 40))
        XCTAssertEqual(visuals.insertionIndicatorFrame.origin, NSPoint(x: 177, y: 0))
        visuals.updateIntent(.insertion(index: 8), geometry: geometry, pointer: .init(x: 25, y: 140))
        XCTAssertEqual(visuals.insertionIndicatorFrame.origin, NSPoint(x: 16, y: 100))
    }

    func testProjectedSingletonParticipatesInActualSourceResolutionAndReordersItsLatentGroup() throws {
        let (_, catalog) = makeDragLayout(titles: ["target", "alpha"])
        let folder = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000093")!)
        let expected = PersistentWorkspaceLayout(generation: LayoutGeneration(4),
            topLevelOrder: [.app(ref("target")), .folder(folder)],
            folders: [.init(id: folder, title: "Fixture group", members: [ref("alpha"), ref("missing")])])
        let frames = DragLogicalIndexMap(layout: expected).topLevel(rowFrames([.app(ref("target")), .app(ref("alpha"))]))
        XCTAssertEqual(frames.map(\.identity), [.app(ref("target")), .folder(folder)])
        XCTAssertEqual(frames.map(\.logicalIndex), [0, 1])
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let coordinator = DragUISessionCoordinator(host: host, clock: FakeDragClock())
        defer { coordinator.teardown() }
        coordinator.layoutProvider = { expected }
        coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { scope in
            XCTAssertEqual(scope, .topLevel)
            return topLevelGeometry(frames: frames)
        }
        var committed: PersistentWorkspaceLayout?
        coordinator.onCommit = { committed = $0 }
        let record = try XCTUnwrap(catalog.records.first { $0.displayName == "alpha" })
        let cell = AppGridCellView(frame: NSRect(x: 100, y: 0, width: 80, height: 80))
        host.addSubview(cell)
        cell.bind(name: record.displayName, token: .init(catalogRevision: 1,
            pageIdentity: .init(revision: 1, pageIndex: 0), itemSlot: 1,
            appID: AnyHashable(record.id), reuseGeneration: 1, iconKey: nil, surfaceGeneration: 1))
        coordinator.pointerDown(locationInWindow: NSPoint(x: 140, y: 40), sourceCell: cell, memberFolderID: nil)
        XCTAssertEqual(coordinator.controller.state, .pressed)
        coordinator.pointerDragged(locationInWindow: NSPoint(x: 5, y: 40))
        coordinator.pointerUp(locationInWindow: NSPoint(x: 5, y: 40))
        let result = try XCTUnwrap(committed)
        XCTAssertEqual(result.topLevelOrder, [.folder(folder), .app(ref("target"))])
        XCTAssertEqual(result.folders, expected.folders)
        XCTAssertEqual(result.appReferenceCount, expected.appReferenceCount)
    }

    func testDropOntoProjectedSingletonTargetsCanonicalFolderAndPreservesMissingMember() throws {
        let folder = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000094")!)
        let expected = PersistentWorkspaceLayout(generation: .zero,
            topLevelOrder: [.app(ref("source")), .folder(folder)],
            folders: [.init(id: folder, title: "Fixture group", members: [ref("alpha"), ref("missing")])])
        let frames = DragLogicalIndexMap(layout: expected).topLevel(rowFrames([.app(ref("source")), .app(ref("alpha"))]))
        let zones = DropZoneBuilder.zones(itemFrames: frames, topLevelFrames: frames,
            containerWidth: 400, moveOutArmed: false, parameters: .default)
        let source = DragSourceIdentity.topLevelApp(ref("source"))
        let intent = DropZoneClassifier.classify(pointer: .init(x: 140, y: 40), source: source, zones: zones)
        guard case .intoFolder(let target, _) = intent else { return XCTFail("Expected persisted group target") }
        XCTAssertEqual(target, folder)
        guard case .success(let result) = DragMutationEngine.apply(intent: intent, source: source, layout: expected) else {
            return XCTFail("Drop must commit")
        }
        XCTAssertEqual(Set(result.folder(id: folder)!.members.map(\.comparisonKey)),
                       Set([ref("alpha"), ref("missing"), ref("source")].map(\.comparisonKey)))
    }

    func testPathReferenceSurvivesActualDragWhenCatalogRecordNowHasBundleID() throws {
        let (_, catalog) = makeDragLayout(titles: ["alpha", "beta"])
        let alpha = try XCTUnwrap(catalog.records.first { $0.displayName == "alpha" })
        let beta = try XCTUnwrap(catalog.records.first { $0.displayName == "beta" })
        let stored = PersistentAppReference.canonicalPath(PersistentAppReference.normalizedPath(alpha.canonicalURL))
        let expected = PersistentWorkspaceLayout(generation: LayoutGeneration(4),
            topLevelOrder: [.app(stored), .app(.from(record: beta))], folders: [])
        let frames = DragLogicalIndexMap(layout: expected, catalog: catalog).topLevel(
            rowFrames([.app(.from(record: alpha)), .app(.from(record: beta))]))
        XCTAssertEqual(frames.map(\.identity), [.app(stored), .app(.from(record: beta))])
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let coordinator = DragUISessionCoordinator(host: host, clock: FakeDragClock())
        defer { coordinator.teardown() }
        coordinator.layoutProvider = { expected }; coordinator.catalogSnapshotProvider = { catalog }
        coordinator.geometryProvider = { _ in topLevelGeometry(frames: frames) }
        var committed: PersistentWorkspaceLayout?
        coordinator.onCommit = { committed = $0 }
        let cell = AppGridCellView(frame: NSRect(x: 0, y: 0, width: 80, height: 80))
        host.addSubview(cell)
        cell.bind(name: alpha.displayName, token: .init(catalogRevision: 1,
            pageIdentity: .init(revision: 1, pageIndex: 0), itemSlot: 0, appID: AnyHashable(alpha.id),
            reuseGeneration: 1, iconKey: nil, surfaceGeneration: 1))
        coordinator.pointerDown(locationInWindow: .init(x: 40, y: 40), sourceCell: cell, memberFolderID: nil)
        coordinator.pointerDragged(locationInWindow: .init(x: 175, y: 40))
        coordinator.pointerUp(locationInWindow: .init(x: 175, y: 40))
        XCTAssertEqual(committed?.topLevelOrder, [.app(.from(record: beta)), .app(stored)])
        XCTAssertEqual(committed?.appReferenceCount, 2)
    }

    func testFolderDragFramesUseExistingPathReferenceInsteadOfPreferredNewBundleIdentity() throws {
        let (_, catalog) = makeDragLayout(titles: ["alpha", "beta"])
        let alpha = try XCTUnwrap(catalog.records.first { $0.displayName == "alpha" })
        let beta = try XCTUnwrap(catalog.records.first { $0.displayName == "beta" })
        let stored = PersistentAppReference.canonicalPath(PersistentAppReference.normalizedPath(alpha.canonicalURL))
        let folder = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000095")!)
        let expected = PersistentWorkspaceLayout(generation: .zero, topLevelOrder: [.folder(folder)],
            folders: [.init(id: folder, title: "Fixture group", members: [stored, .from(record: beta)])])
        let frames = DragLogicalIndexMap(layout: expected, catalog: catalog).members(
            rowFrames([.app(.from(record: alpha)), .app(.from(record: beta))]), folderID: folder)
        XCTAssertEqual(frames.map(\.identity), [.app(stored), .app(.from(record: beta))])
        XCTAssertEqual(frames.map(\.logicalIndex), [0, 1])
    }
}
