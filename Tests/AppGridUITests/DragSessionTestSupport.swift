// AppGridUITests — DragSessionTestSupport（T-1F-C 测试助手）
// 假时钟 + 布局/几何工厂。fixture 标题为合成数据（无真实 app 身份）。

import AppCatalogCore
import Foundation
import XCTest
@testable import AppGridUI

/// 可编程假时钟（dwell/turn 时序测试）。
final class FakeDragClock: DragClock, @unchecked Sendable {
    var current: TimeInterval
    init(_ current: TimeInterval = 0) {
        self.current = current
    }
    func now() -> TimeInterval { current }
}

/// 由 fixture catalog 构建默认布局（顶层 app 保持 catalog 稳定序）。
func makeDragLayout(titles: [String], revision: UInt64 = 1)
    -> (layout: PersistentWorkspaceLayout, catalog: CatalogSnapshot) {
    let catalog = try! makeSnapshot(titles: titles, revision: revision)
    return (PersistentWorkspaceLayout.makeDefault(catalog: catalog), catalog)
}

/// fixture app 持久引用（bundleID = "fixture." + 小写标题）。
func ref(_ title: String) -> PersistentAppReference {
    PersistentAppReference.bundleID("fixture.\(title.lowercased())")
}

/// 行布局帧：item i 位于 x = i*100, y=0, w=80, h=80（间距 20）。
func rowFrames(_ identities: [DragItemIdentity]) -> [DragItemFrame] {
    identities.enumerated().map { index, identity in
        DragItemFrame(identity: identity, frame: DragRect(x: Double(index * 100), y: 0, width: 80, height: 80))
    }
}

func appFrame(_ title: String) -> DragItemFrame {
    DragItemFrame(identity: .app(ref(title)), frame: DragRect(x: 0, y: 0, width: 80, height: 80))
}

func folderFrame(_ id: FolderID, x: Double) -> DragItemFrame {
    DragItemFrame(identity: .folder(id), frame: DragRect(x: x, y: 0, width: 80, height: 80))
}

/// 顶层 scope 几何（itemFrames = topLevelFrames）。
func topLevelGeometry(frames: [DragItemFrame],
                      containerWidth: Double = 400,
                      page: Int = 0,
                      pageCount: Int = 1) -> DragGeometry {
    DragGeometry(itemFrames: frames, containerWidth: containerWidth, page: page, pageCount: pageCount)
}

/// folder scope 几何（成员帧 + 顶层帧；move-out 落点用）。
func folderGeometry(memberFrames: [DragItemFrame],
                    topLevelFrames: [DragItemFrame],
                    containerWidth: Double = 400,
                    page: Int = 0,
                    pageCount: Int = 1) -> DragGeometry {
    DragGeometry(itemFrames: memberFrames, topLevelFrames: topLevelFrames,
                 containerWidth: containerWidth, page: page, pageCount: pageCount)
}

/// 断言事件序列包含指定事件（顺序无关的包含检查）。
func assertContains<T: Equatable>(_ events: [T], _ expected: T,
                                  file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(events.contains(expected), "expected \(expected) in \(events)", file: file, line: line)
}
