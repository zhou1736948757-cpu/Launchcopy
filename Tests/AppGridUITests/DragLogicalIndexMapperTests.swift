import AppCatalogCore
import Foundation
import XCTest
@testable import AppGridUI

/// Synthetic hidden references stay in the canonical layout but have no displayed frames.
final class DragLogicalIndexMapperTests: XCTestCase {
    private let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000081")!)

    private func topLayout() -> PersistentWorkspaceLayout {
        PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.app(ref("hiddenHead")), .app(ref("alpha")),
                            .app(ref("hiddenGap")), .folder(folderID),
                            .app(ref("hiddenGap2")), .app(ref("beta")),
                            .app(ref("hiddenTail")), .app(ref("source"))],
            folders: [PersistentFolderRecord(id: folderID, title: "Synthetic Group",
                                             members: [ref("memberA"), ref("memberB")])])
    }

    private func memberLayout() -> PersistentWorkspaceLayout {
        PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.app(ref("hiddenTop")), .folder(folderID), .app(ref("target"))],
            folders: [PersistentFolderRecord(
                id: folderID, title: "Synthetic Group",
                members: [ref("hiddenHead"), ref("alpha"), ref("hiddenGap"),
                          ref("beta"), ref("hiddenTail"), ref("source")])])
    }

    private func classify(_ pointer: DragPoint, source: DragSourceIdentity,
                          geometry: DragGeometry, moveOutArmed: Bool = false) -> DropIntent {
        DropZoneClassifier.classify(
            pointer: pointer, source: source,
            zones: DropZoneBuilder.zones(
                itemFrames: geometry.itemFrames, topLevelFrames: geometry.topLevelFrames,
                containerWidth: geometry.containerWidth, moveOutArmed: moveOutArmed,
                parameters: .default))
    }

    private func committed(_ result: LayoutMutationResult,
                           file: StaticString = #filePath, line: UInt = #line) throws -> PersistentWorkspaceLayout {
        guard case .success(let layout) = result else {
            XCTFail("Expected a committed mutation, got \(result)", file: file, line: line)
            throw FixtureError.missingCommit
        }
        return layout
    }

    private enum FixtureError: Error { case missingCommit }

    func testTopLevelMapUsesCanonicalIdentityAcrossHiddenAppsAndFolders() {
        let layout = topLayout()
        // Deliberately use a different display order and stale logical annotations.
        let displayed = rowFrames([.app(ref("beta")), .folder(folderID), .app(ref("alpha"))])
            .map { $0.mapped(toLogicalIndex: 99).annotated(pageIndex: 2, itemsPerPage: 35) }
        let mapped = DragLogicalIndexMap(layout: layout).topLevel(displayed)

        XCTAssertEqual(mapped.map(\.logicalIndex), [5, 3, 1])
        XCTAssertEqual(mapped.map(\.identity), displayed.map(\.identity))
        XCTAssertEqual(mapped.map(\.frame), displayed.map(\.frame))
        XCTAssertEqual(mapped.map(\.pageIndex), [2, 2, 2])
        XCTAssertEqual(mapped.map(\.itemsPerPage), [35, 35, 35])
        XCTAssertEqual(DragLogicalIndexMapper.topLevel(displayed, layout: layout), mapped)
        XCTAssertEqual(displayed.map(\.logicalIndex), [99, 99, 99], "Mapping must not mutate caller frames")
    }

    func testMembersMapUsesFolderIndicesRatherThanTopLevelOrDisplayedIndices() {
        let layout = memberLayout()
        let displayed = rowFrames([.app(ref("beta")), .app(ref("alpha")), .app(ref("source"))])
        let mapped = DragLogicalIndexMap(layout: layout).members(displayed, folderID: folderID)

        XCTAssertEqual(mapped.map(\.logicalIndex), [3, 1, 5])
        XCTAssertEqual(mapped.map(\.frame), displayed.map(\.frame))
        XCTAssertEqual(mapped.map(\.identity), displayed.map(\.identity))
        XCTAssertEqual(DragLogicalIndexMapper.members(displayed, folderID: folderID, layout: layout), mapped)
    }

    func testUnknownAndWrongScopeFramesAreOmittedWithoutRenumberingSurvivors() {
        let layout = topLayout()
        let unknownFolder = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000082")!)
        let frames = rowFrames([.app(ref("ghost")), .app(ref("alpha")),
                                .app(ref("memberA")), .folder(unknownFolder), .folder(folderID)])
        let map = DragLogicalIndexMap(layout: layout)
        let top = map.topLevel(frames)
        XCTAssertEqual(top.map(\.identity), [.app(ref("alpha")), .folder(folderID)])
        XCTAssertEqual(top.map(\.logicalIndex), [1, 3])
        XCTAssertEqual(top.map(\.frame), [frames[1].frame, frames[4].frame])

        let members = map.members(frames, folderID: folderID)
        XCTAssertEqual(members.map(\.identity), [.app(ref("memberA"))])
        XCTAssertEqual(members.map(\.logicalIndex), [0])
        XCTAssertTrue(map.members(frames, folderID: unknownFolder).isEmpty)
        XCTAssertTrue(map.topLevel([]).isEmpty)
        XCTAssertTrue(map.members([], folderID: folderID).isEmpty)
    }

    func testAbsentFramesUseSafeEmptyClassificationFallback() {
        let frames = DragLogicalIndexMap(layout: topLayout()).topLevel(rowFrames([.app(ref("ghost"))]))
        let geometry = DragGeometry(itemFrames: frames, containerWidth: 400,
                                    page: 2, pageCount: 3, itemsPerPage: 35)
        XCTAssertEqual(geometry.topLevelFrames, [])
        XCTAssertEqual(classify(DragPoint(x: 90, y: 40), source: .topLevelApp(ref("source")),
                                geometry: geometry), .insertion(index: 0))
        XCTAssertEqual(classify(DragPoint(x: 90, y: 40),
                                source: .folderMember(folderID: folderID, app: ref("memberA")),
                                geometry: geometry, moveOutArmed: true), .invalid)
    }

    func testDefaultCatalogLayoutMapsHiddenGapsWithoutStoredLayout() {
        let (layout, catalog) = makeDragLayout(titles: ["Alpha", "Beta", "Gamma", "Omega"])
        let preferences = AppManagementPreferences.default.settingHidden(true, for: catalog.records[1])
        let visible = preferences.visibleRecords(catalog.records)
        let frames = rowFrames(visible.map { .app(PersistentAppReference.from(record: $0)) })
        let mapped = DragLogicalIndexMapper.topLevel(frames, layout: layout)

        XCTAssertEqual(mapped.map(\.logicalIndex), [0, 2, 3])
        XCTAssertEqual(mapped.count, 3)
        XCTAssertEqual(layout.topLevelOrder.count, 4)
        XCTAssertEqual(classify(DragPoint(x: 120, y: 40), source: .topLevelApp(ref("omega")),
                                geometry: topLevelGeometry(frames: mapped)), .insertion(index: 2))
    }

    func testUnmappedFramesKeepLocalAndPageAnnotationFallbacks() {
        let frames = rowFrames([.app(ref("alpha")), .app(ref("beta"))])
        for (x, local) in [(20.0, 0), (90.0, 1), (190.0, 2)] {
            let pointer = DragPoint(x: x, y: 40)
            XCTAssertEqual(classify(pointer, source: .topLevelApp(ref("source")),
                                    geometry: topLevelGeometry(frames: frames)), .insertion(index: local))
            let paged = frames.map { $0.annotated(pageIndex: 2, itemsPerPage: 35) }
            XCTAssertEqual(classify(pointer, source: .topLevelApp(ref("source")),
                                    geometry: topLevelGeometry(frames: paged)), .insertion(index: 70 + local))
        }
    }

    func testMappedTopLevelLeftHalvesGapsAndTailOverridePageOffsets() {
        let frames = DragLogicalIndexMap(layout: topLayout()).topLevel(
            rowFrames([.app(ref("alpha")), .folder(folderID), .app(ref("beta"))])
                .map { $0.annotated(pageIndex: 2, itemsPerPage: 35) })
        let geometry = topLevelGeometry(frames: frames)
        for (x, slot) in [(20.0, 1), (90.0, 3), (220.0, 5), (270.0, 6), (290.0, 6)] {
            XCTAssertEqual(classify(DragPoint(x: x, y: 40), source: .topLevelApp(ref("source")),
                                    geometry: geometry), .insertion(index: slot), "pointer x=\(x)")
        }
        XCTAssertEqual(geometry.topLevelFrames, frames, "Default geometry must preserve logical indices")
    }

    func testTopLevelReorderThroughClassifierAndMutationPreservesHiddenReferences() throws {
        let layout = topLayout()
        let frames = DragLogicalIndexMapper.topLevel(
            rowFrames([.app(ref("alpha")), .folder(folderID), .app(ref("beta"))]), layout: layout)
        let source = DragSourceIdentity.topLevelApp(ref("source"))
        let intent = classify(DragPoint(x: 220, y: 40), source: source,
                              geometry: topLevelGeometry(frames: frames))
        XCTAssertEqual(intent, .insertion(index: 5))
        let updated = try committed(DragMutationEngine.apply(intent: intent, source: source, layout: layout))

        XCTAssertEqual(updated.topLevelOrder,
                       [.app(ref("hiddenHead")), .app(ref("alpha")), .app(ref("hiddenGap")),
                        .folder(folderID), .app(ref("hiddenGap2")), .app(ref("source")),
                        .app(ref("beta")), .app(ref("hiddenTail"))])
        XCTAssertEqual(updated.folders, layout.folders)
        XCTAssertEqual(updated.appReferenceCount, layout.appReferenceCount)
        XCTAssertEqual(updated.generation, layout.generation.incremented())
    }

    func testForwardReordersAdjustCanonicalSourceIndexRatherThanDisplayedIndex() throws {
        let top = topLayout()
        let topFrames = DragLogicalIndexMapper.topLevel(
            rowFrames([.app(ref("alpha")), .folder(folderID), .app(ref("beta"))]), layout: top)
        let topSource = DragSourceIdentity.topLevelApp(ref("alpha"))
        let topIntent = classify(DragPoint(x: 220, y: 40), source: topSource,
                                 geometry: topLevelGeometry(frames: topFrames))
        XCTAssertEqual(topIntent, .insertion(index: 5))
        let topUpdated = try committed(DragMutationEngine.apply(intent: topIntent, source: topSource, layout: top))
        XCTAssertEqual(topUpdated.topLevelOrder,
                       [.app(ref("hiddenHead")), .app(ref("hiddenGap")), .folder(folderID),
                        .app(ref("hiddenGap2")), .app(ref("alpha")), .app(ref("beta")),
                        .app(ref("hiddenTail")), .app(ref("source"))])
        XCTAssertEqual(topUpdated.folders, top.folders)

        let inner = memberLayout()
        let innerFrames = DragLogicalIndexMapper.members(
            rowFrames([.app(ref("alpha")), .app(ref("beta"))]), folderID: folderID, layout: inner)
        let innerSource = DragSourceIdentity.folderMember(folderID: folderID, app: ref("alpha"))
        let innerIntent = classify(DragPoint(x: 170, y: 40), source: innerSource,
                                   geometry: folderGeometry(memberFrames: innerFrames, topLevelFrames: []))
        XCTAssertEqual(innerIntent, .insertion(index: 4))
        let innerUpdated = try committed(DragMutationEngine.apply(intent: innerIntent, source: innerSource, layout: inner))
        XCTAssertEqual(innerUpdated.folder(id: folderID)?.members,
                       [ref("hiddenHead"), ref("hiddenGap"), ref("beta"),
                        ref("alpha"), ref("hiddenTail"), ref("source")])
        XCTAssertEqual(innerUpdated.topLevelOrder, inner.topLevelOrder)
    }

    func testFolderReorderThroughClassifierAndMutationPreservesHiddenMembers() throws {
        let layout = memberLayout()
        let source = DragSourceIdentity.folderMember(folderID: folderID, app: ref("source"))
        let frames = DragLogicalIndexMapper.members(
            rowFrames([.app(ref("alpha")), .app(ref("beta"))]), folderID: folderID, layout: layout)
        let geometry = folderGeometry(memberFrames: frames, topLevelFrames: [])
        for (x, slot) in [(20.0, 1), (90.0, 3), (120.0, 3), (170.0, 4), (190.0, 4)] {
            XCTAssertEqual(classify(DragPoint(x: x, y: 40), source: source,
                                    geometry: geometry, moveOutArmed: true), .insertion(index: slot))
        }
        let intent = classify(DragPoint(x: 120, y: 40), source: source, geometry: geometry)
        let updated = try committed(DragMutationEngine.apply(intent: intent, source: source, layout: layout))
        XCTAssertEqual(updated.folder(id: folderID)?.members,
                       [ref("hiddenHead"), ref("alpha"), ref("hiddenGap"),
                        ref("source"), ref("beta"), ref("hiddenTail")])
        XCTAssertEqual(updated.topLevelOrder, layout.topLevelOrder)
        XCTAssertEqual(updated.folder(id: folderID)?.title, "Synthetic Group")
        XCTAssertEqual(updated.appReferenceCount, layout.appReferenceCount)
        XCTAssertEqual(updated.generation, layout.generation.incremented())
    }

    /// The documented right-half contract is immediately after the HIT item, before hidden successors.
    /// Keep this assertion even if the implementation currently maps to the next displayed frame.
    func testRightHalfInsertionDoesNotJumpOverHiddenSuccessorReferences() throws {
        let top = topLayout()
        let topFrames = DragLogicalIndexMapper.topLevel(
            rowFrames([.app(ref("alpha")), .app(ref("beta"))]), layout: top)
        let topSource = DragSourceIdentity.topLevelApp(ref("source"))
        let topIntent = classify(DragPoint(x: 70, y: 40), source: topSource,
                                 geometry: topLevelGeometry(frames: topFrames))
        XCTAssertEqual(topIntent, .insertion(index: 2), "Right half means after alpha, before hiddenGap")
        let topUpdated = try committed(DragMutationEngine.apply(intent: topIntent, source: topSource, layout: top))
        XCTAssertEqual(topUpdated.topLevelOrder,
                       [.app(ref("hiddenHead")), .app(ref("alpha")), .app(ref("source")),
                        .app(ref("hiddenGap")), .folder(folderID), .app(ref("hiddenGap2")),
                        .app(ref("beta")), .app(ref("hiddenTail"))])

        let inner = memberLayout()
        let innerFrames = DragLogicalIndexMapper.members(
            rowFrames([.app(ref("alpha")), .app(ref("beta"))]), folderID: folderID, layout: inner)
        let innerSource = DragSourceIdentity.folderMember(folderID: folderID, app: ref("source"))
        let innerIntent = classify(DragPoint(x: 70, y: 40), source: innerSource,
                                   geometry: folderGeometry(memberFrames: innerFrames, topLevelFrames: []))
        XCTAssertEqual(innerIntent, .insertion(index: 2))
        let innerUpdated = try committed(DragMutationEngine.apply(intent: innerIntent, source: innerSource, layout: inner))
        XCTAssertEqual(innerUpdated.folder(id: folderID)?.members,
                       [ref("hiddenHead"), ref("alpha"), ref("source"),
                        ref("hiddenGap"), ref("beta"), ref("hiddenTail")])
    }

    func testMoveOutUsesMappedTopLevelGapAndKeepsHiddenFolderMembers() throws {
        let layout = memberLayout()
        let map = DragLogicalIndexMap(layout: layout)
        let top = map.topLevel(rowFrames([.folder(folderID), .app(ref("target"))])
            .map { $0.annotated(pageIndex: 2, itemsPerPage: 35) })
        let members = map.members([
            DragItemFrame(identity: .app(ref("alpha")),
                          frame: DragRect(x: 0, y: 200, width: 80, height: 80)),
            DragItemFrame(identity: .app(ref("beta")),
                          frame: DragRect(x: 100, y: 200, width: 80, height: 80))], folderID: folderID)
        let geometry = folderGeometry(memberFrames: members, topLevelFrames: top)
        let source = DragSourceIdentity.folderMember(folderID: folderID, app: ref("source"))
        let pointer = DragPoint(x: 90, y: 40)
        XCTAssertEqual(classify(pointer, source: source, geometry: geometry), .invalid)
        let intent = classify(pointer, source: source, geometry: geometry, moveOutArmed: true)
        XCTAssertEqual(intent, .topLevelTarget(index: 2))
        let updated = try committed(DragMutationEngine.apply(intent: intent, source: source, layout: layout))
        XCTAssertEqual(updated.topLevelOrder,
                       [.app(ref("hiddenTop")), .folder(folderID), .app(ref("source")), .app(ref("target"))])
        XCTAssertEqual(updated.folder(id: folderID)?.members,
                       [ref("hiddenHead"), ref("alpha"), ref("hiddenGap"), ref("beta"), ref("hiddenTail")])
        XCTAssertEqual(updated.appReferenceCount, layout.appReferenceCount)
        XCTAssertEqual(updated.generation, layout.generation.incremented())
    }

    func testCenterDropCreatesFolderForVisibleTargetWithoutConsumingHiddenGap() throws {
        let layout = topLayout()
        let frames = DragLogicalIndexMapper.topLevel(rowFrames([.app(ref("alpha")), .app(ref("beta"))]),
                                                     layout: layout)
        let source = DragSourceIdentity.topLevelApp(ref("source"))
        let intent = classify(DragPoint(x: 140, y: 40), source: source,
                              geometry: topLevelGeometry(frames: frames))
        XCTAssertEqual(intent, .createFolder(target: ref("beta")))
        let updated = try committed(DragMutationEngine.apply(intent: intent, source: source, layout: layout))
        let newFolder = try XCTUnwrap(updated.folders.first { $0.id != folderID })
        XCTAssertEqual(newFolder.members, [ref("beta"), ref("source")])
        XCTAssertEqual(updated.topLevelOrder,
                       [.app(ref("hiddenHead")), .app(ref("alpha")), .app(ref("hiddenGap")),
                        .folder(folderID), .app(ref("hiddenGap2")), .folder(newFolder.id), .app(ref("hiddenTail"))])
        XCTAssertEqual(updated.folder(id: folderID), layout.folder(id: folderID))
        XCTAssertEqual(updated.appReferenceCount, layout.appReferenceCount)
    }
}
