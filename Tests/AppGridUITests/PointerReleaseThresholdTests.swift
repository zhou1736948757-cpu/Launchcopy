import XCTest
@testable import AppGridUI

final class PointerReleaseThresholdTests: XCTestCase {
    func testFarReleaseWithoutProcessedMoveNeverClicksForMainOrFolder() {
        for folderMember in [false, true] {
            let a = PersistentAppReference.bundleID("fixture.release.alpha")
            let b = PersistentAppReference.bundleID("fixture.release.beta")
            let id = FolderID()
            let layout = PersistentWorkspaceLayout(generation: .zero,
                topLevelOrder: folderMember ? [.folder(id)] : [.app(a), .app(b)],
                folders: folderMember ? [.init(id: id, title: "Group", members: [a, b])] : [])
            let source: DragSourceIdentity = folderMember ? .folderMember(folderID: id, app: a) : .topLevelApp(a)
            let controller = DragSessionController()
            _ = controller.pointerDown(at: .init(x: 100, y: 100), source: source, layout: layout, catalogGeneration: 1)
            let events = controller.pointerUp(at: .init(x: 200, y: 100),
                geometry: .init(itemFrames: [], containerWidth: 600, page: 0, pageCount: 1),
                layout: layout, catalogGeneration: 1)
            XCTAssertEqual(events, [.noOp], "Distant release is not click intent, even when no move was processed")
            XCTAssertEqual(controller.state, .idle)
            XCTAssertNil(controller.activeTransaction)
        }
    }

    func testNearReleaseWithoutMoveStillClicksAndExactThresholdDoesNot() {
        let a = PersistentAppReference.bundleID("fixture.release.alpha")
        let layout = PersistentWorkspaceLayout(generation: .zero, topLevelOrder: [.app(a)], folders: [])
        for delta in [0.0, 5.99, 6.0, 100.0] {
            let controller = DragSessionController()
            _ = controller.pointerDown(at: .init(x: 100, y: 100), source: .topLevelApp(a), layout: layout, catalogGeneration: 1)
            let events = controller.pointerUp(at: .init(x: 100 + delta, y: 100),
                geometry: .init(itemFrames: [], containerWidth: 600, page: 0, pageCount: 1),
                layout: layout, catalogGeneration: 1)
            XCTAssertEqual(events, delta < 6 ? [.clicked] : [.noOp])
            XCTAssertEqual(controller.state, .idle)
        }
    }
}
