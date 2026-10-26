import Foundation
import XCTest
@testable import AppGridUI

final class FolderCreationDropContextTests: XCTestCase {
    private func geometry() -> DragGeometry {
        topLevelGeometry(frames: rowFrames([.app(ref("app1")), .app(ref("app2")), .app(ref("app3"))]),
                         containerWidth: 400, page: 0, pageCount: 1)
    }

    func testNamingUsesValidatedReleaseTargetNotPreviousHoverAndConsumesOnlyOnce() throws {
        let controller = DragSessionController()
        let (layout, _) = makeDragLayout(titles: ["app1", "app2", "app3"])
        let geometry = geometry()
        _ = controller.pointerDown(at: .init(x: 40, y: 40), source: .topLevelApp(ref("app1")),
                                   layout: layout, catalogGeneration: 1)
        _ = controller.pointerMoved(to: .init(x: 140, y: 40), geometry: geometry,
                                    layout: layout, catalogGeneration: 1)
        XCTAssertEqual(controller.lastIntent, .createFolder(target: ref("app2")))
        var calls = 0
        let naming: FolderCreationTitleProvider = { target, source, input in
            calls += 1
            XCTAssertEqual(target, ref("app3"))
            XCTAssertEqual(source, ref("app1"))
            XCTAssertEqual(input, layout)
            return "Actual release target"
        }
        let events = controller.pointerUp(at: .init(x: 240, y: 40), geometry: geometry,
            layout: layout, catalogGeneration: 1, folderTitleProvider: naming)
        guard case .committed(let committed) = events.first else { return XCTFail("Expected one creation") }
        XCTAssertEqual(committed.folders.first?.title, "Actual release target")
        XCTAssertEqual(committed.folders.first?.members, [ref("app3"), ref("app1")])
        XCTAssertEqual(committed.generation, layout.generation.incremented())
        XCTAssertTrue(controller.pointerUp(at: .init(x: 240, y: 40), geometry: geometry,
            layout: layout, catalogGeneration: 1, folderTitleProvider: naming).isEmpty)
        XCTAssertEqual(calls, 1)
    }

    func testStaleLayoutOrCatalogCannotInvokeNaming() {
        for staleLayout in [false, true] {
            let controller = DragSessionController()
            let (layout, _) = makeDragLayout(titles: ["app1", "app2", "app3"])
            let geometry = geometry()
            _ = controller.pointerDown(at: .init(x: 40, y: 40), source: .topLevelApp(ref("app1")),
                                       layout: layout, catalogGeneration: 1)
            _ = controller.pointerMoved(to: .init(x: 140, y: 40), geometry: geometry,
                                        layout: layout, catalogGeneration: 1)
            var calls = 0
            let input = staleLayout ? layout.replacing(generation: .init(1)) : layout
            let events = controller.pointerUp(at: .init(x: 140, y: 40), geometry: geometry,
                layout: input, catalogGeneration: staleLayout ? 1 : 2,
                folderTitleProvider: { _, _, _ in calls += 1; return "Must not be used" })
            XCTAssertEqual(calls, 0)
            XCTAssertEqual(events, [.cancelled(staleLayout ? .layoutChanged : .catalogRefresh)])
        }
    }

    func testClickCancelledAndInsertionReleasesDoNotInvokeNaming() {
        let (layout, _) = makeDragLayout(titles: ["app1", "app2", "app3"])
        for mode in 0..<3 {
            let controller = DragSessionController()
            let geometry = geometry()
            _ = controller.pointerDown(at: .init(x: 40, y: 40), source: .topLevelApp(ref("app1")),
                                       layout: layout, catalogGeneration: 1)
            if mode == 1 { _ = controller.cancel(reason: .escape) }
            if mode == 2 {
                _ = controller.pointerMoved(to: .init(x: 50, y: 40), geometry: geometry,
                                            layout: layout, catalogGeneration: 1)
            }
            var calls = 0
            let events = controller.pointerUp(at: .init(x: mode == 2 ? 201 : 40, y: 40),
                geometry: geometry, layout: layout, catalogGeneration: 1,
                folderTitleProvider: { _, _, _ in calls += 1; return "Must not be used" })
            XCTAssertEqual(calls, 0)
            if mode == 0 { XCTAssertEqual(events, [.clicked]) }
            if mode == 1 { XCTAssertTrue(events.isEmpty) }
            if mode == 2 {
                guard case .committed(let committed) = events.first else {
                    return XCTFail("The insertion control must actually commit a reorder")
                }
                XCTAssertTrue(committed.folders.isEmpty)
                XCTAssertEqual(committed.topLevelOrder,
                               [.app(ref("app2")), .app(ref("app1")), .app(ref("app3"))])
            }
        }
    }
}
