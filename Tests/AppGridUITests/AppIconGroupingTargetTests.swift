import XCTest
@testable import AppGridUI

final class AppIconGroupingTargetTests: XCTestCase {
    private let cell = DragRect(x: 200, y: 0, width: 160, height: 240)
    private let icon = DragRect(x: 256, y: 170, width: 48, height: 48)

    private func zones(icon: DragRect?) -> DropZones {
        DropZoneBuilder.zones(itemFrames: [
            .init(identity: .app(ref("alpha")), frame: .init(x: 0, y: 0, width: 160, height: 240)),
            .init(identity: .app(ref("beta")), frame: cell, appGroupingFrame: icon)
        ], topLevelFrames: [], containerWidth: 500, moveOutArmed: false, parameters: .default)
    }
    private func classify(_ point: DragPoint, icon: DragRect?) -> DropIntent {
        DropZoneClassifier.classify(pointer: point, source: .topLevelApp(ref("alpha")),
                                   zones: zones(icon: icon))
    }

    func testVisibleIconCenterAndEdgesCreateFolderDespiteOffsetFromCellCenter() {
        for point in [DragPoint(x: 280, y: 194), .init(x: 258, y: 194),
                      .init(x: 302, y: 194), .init(x: 280, y: 172), .init(x: 280, y: 216)] {
            XCTAssertEqual(classify(point, icon: icon), .createFolder(target: ref("beta")))
        }
    }

    func testExplicitIconExcludesLegacyCellCenterCaptionAndPadding() {
        for point in [DragPoint(x: 280, y: 120), .init(x: 280, y: 20), .init(x: 220, y: 194)] {
            guard case .insertion = classify(point, icon: icon) else {
                XCTFail("Non-icon cell content must remain an ordering target"); continue
            }
        }
    }

    func testExplicitEmptyOrNonfiniteIconDoesNotFallBackToLegacyCenter() {
        for invalid in [DragRect(x: 0, y: 0, width: 0, height: 0),
                        .init(x: 256, y: 170, width: -1, height: 48),
                        .init(x: .nan, y: 170, width: 48, height: 48),
                        .init(x: 256, y: 170, width: .infinity, height: 48)] {
            guard case .insertion = classify(.init(x: 280, y: 120), icon: invalid) else {
                XCTFail("Invalid explicit icon must not manufacture a center target"); continue
            }
        }
    }

    func testMissingIconMetadataRetainsLegacyGeometryCompatibility() {
        XCTAssertEqual(classify(.init(x: 280, y: 120), icon: nil), .createFolder(target: ref("beta")))
        guard case .insertion = classify(.init(x: 280, y: 194), icon: nil) else {
            return XCTFail("Legacy non-center point must retain insertion behavior")
        }
    }

    func testGroupingTargetCannotCapturePointersOutsideItsOwningCell() {
        guard case .insertion = classify(.init(x: 380, y: 194),
            icon: .init(x: 256, y: 170, width: 200, height: 48)) else {
            return XCTFail("Grouping must remain bounded by its owning cell")
        }
    }

    func testAnnotationsAndLogicalIndexCopiesPreserveIconTarget() throws {
        let original = DragItemFrame(identity: .app(ref("beta")), frame: cell, appGroupingFrame: icon)
        let annotated = original.annotated(pageIndex: 2, itemsPerPage: 35)
        let mapped = annotated.mapped(toLogicalIndex: 74)
        XCTAssertEqual(mapped.appGroupingFrame, icon)
        XCTAssertEqual(mapped.frame, cell)
        XCTAssertEqual(mapped.pageIndex, 2)
        XCTAssertEqual(mapped.logicalIndex, 74)
        let layout = makeDragLayout(titles: ["alpha", "beta"]).layout
        let canonical = try XCTUnwrap(DragLogicalIndexMap(layout: layout).topLevel([annotated]).first)
        XCTAssertEqual(canonical.appGroupingFrame, icon)
        XCTAssertEqual(canonical.logicalIndex, 1)
        XCTAssertEqual(canonical.pageIndex, 2)
    }

    func testSourceIconCannotMergeWithItselfAndFolderSourceCannotMergeWithApp() {
        let z = zones(icon: icon)
        guard case .insertion = DropZoneClassifier.classify(pointer: .init(x: 280, y: 194),
            source: .topLevelApp(ref("beta")), zones: z) else {
            return XCTFail("Self drop cannot create a folder")
        }
        let folder = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000081")!)
        XCTAssertEqual(DropZoneClassifier.classify(pointer: .init(x: 280, y: 194),
            source: .topLevelFolder(folder), zones: z), .invalid)
    }
}
