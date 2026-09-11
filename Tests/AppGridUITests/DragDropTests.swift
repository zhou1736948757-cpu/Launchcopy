// AppGridUITests — DragDropTests（T-1F-C 测试）
// 覆盖 drop 组件测试矩阵（§10.1 drag 部分）：DropResolver consume 接受/拒绝、
// DropZoneBuilder zones 构造、DropZoneClassifier 分类、DragMutationEngine 5 类
// mutation 与拒绝路径。全部经 DragSessionTestSupport 工厂（makeDragLayout / ref /
// rowFrames / appFrame / folderFrame / topLevelGeometry / folderGeometry /
// assertContains）；fixture 标题为合成数据（bundleID = "fixture.*"），无真实 app 身份。
//
// 注：FakeDragClock 属 DragSessionController 时序测试（dwell/turn），drop 组件
// （resolver/zones/classifier/engine）无时钟依赖，本套件不使用。

import AppCatalogCore
import Foundation
import XCTest
@testable import AppGridUI

final class DragDropTests: XCTestCase {

    // MARK: - 工厂

    /// 固定 UUID（确定性；不携带任何名称/路径原文）。
    private let folder1 = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
    private let folder2 = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)

    private func makeTransaction(source: DragSourceIdentity,
                                 layout: PersistentWorkspaceLayout,
                                 token: UInt64 = 42,
                                 catalogGeneration: UInt64 = 1) -> DragTransaction {
        DragTransaction(opaqueToken: token,
                        scope: source.scope,
                        sourceIdentity: source,
                        layoutGeneration: layout.generation,
                        catalogGeneration: catalogGeneration)
    }

    private func makeZones(itemFrames: [DragItemFrame],
                           topLevelFrames: [DragItemFrame],
                           moveOutArmed: Bool = false,
                           containerWidth: Double = 400) -> DropZones {
        DropZoneBuilder.zones(itemFrames: itemFrames, topLevelFrames: topLevelFrames,
                              containerWidth: containerWidth, moveOutArmed: moveOutArmed,
                              parameters: .default)
    }

    private func assertRejected(_ result: LayoutMutationResult, _ expected: LayoutMutationRejection,
                                file: StaticString = #filePath, line: UInt = #line) {
        guard case .rejected(let reason) = result else {
            return XCTFail("expected .rejected(\(expected)), got \(result)", file: file, line: line)
        }
        XCTAssertEqual(reason, expected, file: file, line: line)
    }

    // MARK: - 1) consume 接受

    func testConsumeAcceptsValidTopLevelInsertion() {
        let (layout, _) = makeDragLayout(titles: ["app1", "app2"])
        let transaction = makeTransaction(source: .topLevelApp(ref("app1")), layout: layout)
        var resolver = DropResolver(transaction: transaction)
        XCTAssertFalse(resolver.consumed)
        let result = resolver.consume(token: 42, intent: .insertion(index: 1),
                                      layout: layout, catalogGeneration: 1)
        XCTAssertEqual(result, .accept(.insertion(index: 1)))
        XCTAssertTrue(resolver.consumed)
    }

    func testConsumeAcceptsFolderScopeInsertion() {
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.folder(folder1)],
            folders: [PersistentFolderRecord(id: folder1, title: "Group 1",
                                             members: [ref("app1"), ref("app2")])])
        let transaction = makeTransaction(source: .folderMember(folderID: folder1, app: ref("app1")),
                                           layout: layout)
        var resolver = DropResolver(transaction: transaction)
        let result = resolver.consume(token: 42, intent: .insertion(index: 1),
                                      layout: layout, catalogGeneration: 1)
        XCTAssertEqual(result, .accept(.insertion(index: 1)))
        XCTAssertTrue(resolver.consumed)
    }

    // MARK: - 2) consume 拒绝

    func testConsumeRejectsWrongToken() {
        let (layout, _) = makeDragLayout(titles: ["app1", "app2"])
        let transaction = makeTransaction(source: .topLevelApp(ref("app1")), layout: layout)
        var resolver = DropResolver(transaction: transaction)
        let result = resolver.consume(token: 7, intent: .insertion(index: 1),
                                      layout: layout, catalogGeneration: 1)
        XCTAssertEqual(result, .reject(.invalidToken))
        XCTAssertFalse(resolver.consumed)
    }

    func testConsumeRejectsSecondConsume() {
        let (layout, _) = makeDragLayout(titles: ["app1", "app2"])
        let transaction = makeTransaction(source: .topLevelApp(ref("app1")), layout: layout)
        var resolver = DropResolver(transaction: transaction)
        XCTAssertEqual(resolver.consume(token: 42, intent: .insertion(index: 1),
                                        layout: layout, catalogGeneration: 1),
                       .accept(.insertion(index: 1)))
        let second = resolver.consume(token: 42, intent: .insertion(index: 1),
                                      layout: layout, catalogGeneration: 1)
        XCTAssertEqual(second, .reject(.tokenConsumed))
    }

    func testConsumeRejectsStaleLayoutGeneration() {
        let (layout, _) = makeDragLayout(titles: ["app1", "app2"])
        let transaction = makeTransaction(source: .topLevelApp(ref("app1")), layout: layout)
        var resolver = DropResolver(transaction: transaction)
        let stale = PersistentWorkspaceLayout(generation: LayoutGeneration(1),
                                              topLevelOrder: layout.topLevelOrder,
                                              folders: layout.folders)
        let result = resolver.consume(token: 42, intent: .insertion(index: 1),
                                      layout: stale, catalogGeneration: 1)
        XCTAssertEqual(result,
                       .reject(.staleLayout(expected: LayoutGeneration(0), current: LayoutGeneration(1))))
        XCTAssertFalse(resolver.consumed)
    }

    func testConsumeRejectsStaleCatalogGeneration() {
        let (layout, _) = makeDragLayout(titles: ["app1", "app2"])
        let transaction = makeTransaction(source: .topLevelApp(ref("app1")), layout: layout)
        var resolver = DropResolver(transaction: transaction)
        let result = resolver.consume(token: 42, intent: .insertion(index: 1),
                                      layout: layout, catalogGeneration: 2)
        XCTAssertEqual(result, .reject(.staleCatalog(expected: 1, current: 2)))
        XCTAssertFalse(resolver.consumed)
    }

    func testConsumeRejectsSourceMissing() {
        let (layout, _) = makeDragLayout(titles: ["app1", "app2"])
        let transaction = makeTransaction(source: .topLevelApp(ref("ghost")), layout: layout)
        var resolver = DropResolver(transaction: transaction)
        let result = resolver.consume(token: 42, intent: .insertion(index: 1),
                                      layout: layout, catalogGeneration: 1)
        XCTAssertEqual(result, .reject(.sourceMissing))
        XCTAssertFalse(resolver.consumed)
    }

    func testConsumeRejectsTargetMissing() {
        let (layout, _) = makeDragLayout(titles: ["app1", "app2"])
        // insertion 越界（count 2，index 3）。
        var resolver = DropResolver(transaction: makeTransaction(source: .topLevelApp(ref("app1")),
                                                                layout: layout))
        XCTAssertEqual(resolver.consume(token: 42, intent: .insertion(index: 3),
                                        layout: layout, catalogGeneration: 1), .reject(.targetMissing))
        // createFolder 目标不在布局。
        var resolver2 = DropResolver(transaction: makeTransaction(source: .topLevelApp(ref("app1")),
                                                                 layout: layout))
        XCTAssertEqual(resolver2.consume(token: 42, intent: .createFolder(target: ref("ghost")),
                                         layout: layout, catalogGeneration: 1), .reject(.targetMissing))
        // intoFolder 目标 folder 不存在。
        var resolver3 = DropResolver(transaction: makeTransaction(source: .topLevelApp(ref("app1")),
                                                                 layout: layout))
        XCTAssertEqual(resolver3.consume(token: 42, intent: .intoFolder(target: folder1, at: .tail),
                                         layout: layout, catalogGeneration: 1), .reject(.targetMissing))
    }

    func testConsumeRejectsInvalidIntent() {
        // 源码现状：targetStillValid(.invalid) 恒 false → 先命中 .targetMissing；
        // `.invalidDropTarget` 分支当前不可达（死分支，如实报告，不改源码）。
        let (layout, _) = makeDragLayout(titles: ["app1", "app2"])
        let transaction = makeTransaction(source: .topLevelApp(ref("app1")), layout: layout)
        var resolver = DropResolver(transaction: transaction)
        let result = resolver.consume(token: 42, intent: .invalid, layout: layout, catalogGeneration: 1)
        XCTAssertEqual(result, .reject(.targetMissing))
        XCTAssertFalse(resolver.consumed)
    }

    // MARK: - 3) zones 构造
    // BUG6 wave-a：insertion 带 / appCenter strip / 顶层落点带三个 zone 表已删除，
    // 对应构造测试移除；几何行为由 Bug6DropZoneGeometryTests 纯函数/行为表测试锁定。

    func testZonesFolderCellZonesFromItemAndTopLevelFrames() {
        // folder cell 区 = itemFrames + topLevelFrames 中的 folder 帧（跨 folder move 目标）。
        let itemFrames = [appFrame("app1"), appFrame("app2")]
        let topLevelFrames = [folderFrame(folder1, x: 0), appFrame("app3")]
        let zones = makeZones(itemFrames: itemFrames, topLevelFrames: topLevelFrames)
        assertContains(zones.folderCellZones,
                       FolderCellZone(folderID: folder1, rect: DragRect(x: 8, y: 8, width: 64, height: 64)))
    }

    // MARK: - 4) classify 分类

    func testClassifyAppSourceOnOtherAppCenterCreatesFolder() {
        let frames = rowFrames([.app(ref("app1")), .app(ref("app2"))])
        let zones = makeZones(itemFrames: frames, topLevelFrames: frames)
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 140, y: 30),
                                                 source: .topLevelApp(ref("app1")), zones: zones)
        XCTAssertEqual(intent, .createFolder(target: ref("app2")))
    }

    func testClassifyAppSourceOnOwnCenterIsNotCreateFolder() {
        let frames = rowFrames([.app(ref("app1")), .app(ref("app2"))])
        let zones = makeZones(itemFrames: frames, topLevelFrames: frames)
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 40, y: 30),
                                                 source: .topLevelApp(ref("app1")), zones: zones)
        // 落回自身中心 → 排除 createFolder → 降级半区插入（无死区；中线归右
        // → .insertion(index: 1)，引擎换算后 no-op）。
        XCTAssertNotEqual(intent, .createFolder(target: ref("app1")))
        XCTAssertEqual(intent, .insertion(index: 1))
    }

    func testClassifyAppSourceOnInsertionBand() {
        let frames = rowFrames([.app(ref("app1")), .app(ref("app2"))])
        let zones = makeZones(itemFrames: frames, topLevelFrames: frames)
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 75, y: 40),
                                                 source: .topLevelApp(ref("app1")), zones: zones)
        XCTAssertEqual(intent, .insertion(index: 1))
    }

    func testClassifyAppSourceOnFolderCellIntoFolder() {
        let frames = rowFrames([.app(ref("app1")), .folder(folder1), .app(ref("app2"))])
        let zones = makeZones(itemFrames: frames, topLevelFrames: frames)
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 140, y: 10),
                                                 source: .topLevelApp(ref("app1")), zones: zones)
        XCTAssertEqual(intent, .intoFolder(target: folder1, at: .tail))
    }

    func testClassifyFolderSourceOnFolderCellInvalid() {
        let frames = rowFrames([.app(ref("app1")), .folder(folder1), .app(ref("app2"))])
        let zones = makeZones(itemFrames: frames, topLevelFrames: frames)
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 140, y: 40),
                                                 source: .topLevelFolder(folder1), zones: zones)
        XCTAssertEqual(intent, .invalid)
    }

    func testClassifyFolderSourceOnAppCenterInvalid() {
        let frames = rowFrames([.app(ref("app1")), .folder(folder1), .app(ref("app2"))])
        let zones = makeZones(itemFrames: frames, topLevelFrames: frames)
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 40, y: 30),
                                                 source: .topLevelFolder(folder1), zones: zones)
        XCTAssertEqual(intent, .invalid)
    }

    func testClassifyFolderSourceOnInsertionBand() {
        let frames = rowFrames([.app(ref("app1")), .folder(folder1), .app(ref("app2"))])
        let zones = makeZones(itemFrames: frames, topLevelFrames: frames)
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 75, y: 40),
                                                 source: .topLevelFolder(folder1), zones: zones)
        XCTAssertEqual(intent, .insertion(index: 1))
    }

    func testClassifyMemberSourceOnTopLevelLandingMoveOut() {
        // move-out armed：仅当指针**离开成员行带**后，顶层落点才优先于 inner insertion。
        // 成员行放在 y=200，顶层行在 y=0——模拟 overlay 面板与背景顶层网格分离。
        let memberFrames = [
            DragItemFrame(identity: .app(ref("app1")), frame: DragRect(x: 0, y: 200, width: 80, height: 80)),
            DragItemFrame(identity: .app(ref("app2")), frame: DragRect(x: 100, y: 200, width: 80, height: 80)),
        ]
        let topLevelFrames = rowFrames([.app(ref("app3")), .app(ref("app4"))])
        let zones = makeZones(itemFrames: memberFrames, topLevelFrames: topLevelFrames,
                              moveOutArmed: true)
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 75, y: 40),
                                                 source: .folderMember(folderID: folder1, app: ref("app1")),
                                                 zones: zones)
        XCTAssertEqual(intent, .topLevelTarget(index: 1))
    }

    func testClassifyMemberSourceInMemberRowPrefersInsertionEvenWhenMoveOutArmed() {
        // 回归：成员行带与顶层行带 Y 重叠时，贴着成员/缝隙/蓝条不得误触 move-out（否则两成员 folder 解散）。
        let memberFrames = rowFrames([.app(ref("app1")), .app(ref("app2"))])
        let topLevelFrames = rowFrames([.app(ref("app3")), .app(ref("app4"))])
        let zones = makeZones(itemFrames: memberFrames, topLevelFrames: topLevelFrames,
                              moveOutArmed: true)
        let source = DragSourceIdentity.folderMember(folderID: folder1, app: ref("app1"))
        // 缝隙（旧测试曾期望 topLevelTarget）→ 现在必须是内部插入。
        XCTAssertEqual(DropZoneClassifier.classify(pointer: DragPoint(x: 75, y: 40),
                                                   source: source, zones: zones),
                       .insertion(index: 1))
        // 贴着 app2 中心 → 半区插入，绝非 move-out。
        XCTAssertEqual(DropZoneClassifier.classify(pointer: DragPoint(x: 140, y: 40),
                                                   source: source, zones: zones),
                       .insertion(index: 2))
    }

    func testClassifyMemberSourceOnFolderCellIntoFolder() {
        let memberFrames = rowFrames([.app(ref("app1")), .app(ref("app2"))])
        let topLevelFrames = [folderFrame(folder1, x: 0), appFrame("app3")]
        let zones = makeZones(itemFrames: memberFrames, topLevelFrames: topLevelFrames,
                              moveOutArmed: true)
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 40, y: 10),
                                                 source: .folderMember(folderID: folder1, app: ref("app1")),
                                                 zones: zones)
        XCTAssertEqual(intent, .intoFolder(target: folder1, at: .tail))
    }

    func testClassifyMemberSourceOnCenterDegradesToInsertion() {
        // BUG6 缺陷 4 修复：成员命中他人中心 → 降级半区插入，不再是 .invalid。
        // 未 armed（moveOutArmed: false）→ inner 插入；(140,30) 在 app2 中心内缩区
        // [129.33,150.67)² → 中线归右 → .insertion(index: 2)（插到 app2 之后）。
        let memberFrames = rowFrames([.app(ref("app1")), .app(ref("app2"))])
        let topLevelFrames = [folderFrame(folder1, x: 0), appFrame("app3")]
        let zones = makeZones(itemFrames: memberFrames, topLevelFrames: topLevelFrames,
                              moveOutArmed: false)
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 140, y: 30),
                                                 source: .folderMember(folderID: folder1, app: ref("app1")),
                                                 zones: zones)
        XCTAssertEqual(intent, .insertion(index: 2))
    }

    func testClassifyMemberSourceOnInnerInsertionBand() {
        // 未 armed：无顶层落点 → 回退 inner insertion。
        let memberFrames = rowFrames([.app(ref("app1")), .app(ref("app2"))])
        let topLevelFrames = [folderFrame(folder1, x: 0), appFrame("app3")]
        let zones = makeZones(itemFrames: memberFrames, topLevelFrames: topLevelFrames,
                              moveOutArmed: false)
        let intent = DropZoneClassifier.classify(pointer: DragPoint(x: 75, y: 40),
                                                 source: .folderMember(folderID: folder1, app: ref("app1")),
                                                 zones: zones)
        XCTAssertEqual(intent, .insertion(index: 1))
    }

    // MARK: - 5) engine 5 类 mutation

    func testEngineM1TopLevelAppReorder() {
        let (layout, _) = makeDragLayout(titles: ["app1", "app2", "app3"])
        // insertion(2)（原布局序：插到 app3 前）+ 源 app1 在槽位左侧 → 换算 -1 →
        // remove app1 [app2,app3] insert 1 → [app2, app1, app3]（off-by-one 修复）。
        let result = DragMutationEngine.apply(intent: .insertion(index: 2),
                                              source: .topLevelApp(ref("app1")), layout: layout)
        guard case .success(let newLayout) = result else {
            return XCTFail("expected .success, got \(result)")
        }
        XCTAssertEqual(newLayout.generation, LayoutGeneration(1))
        XCTAssertEqual(newLayout.topLevelOrder, [.app(ref("app2")), .app(ref("app1")), .app(ref("app3"))])
        XCTAssertTrue(newLayout.folders.isEmpty)
    }

    func testEngineM2TopLevelFolderReorder() {
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.app(ref("app1")), .folder(folder1), .app(ref("app2"))],
            folders: [PersistentFolderRecord(id: folder1, title: "Group 1",
                                             members: [ref("app3"), ref("app4")])])
        let result = DragMutationEngine.apply(intent: .insertion(index: 0),
                                              source: .topLevelFolder(folder1), layout: layout)
        guard case .success(let newLayout) = result else {
            return XCTFail("expected .success, got \(result)")
        }
        XCTAssertEqual(newLayout.generation, LayoutGeneration(1))
        XCTAssertEqual(newLayout.topLevelOrder, [.folder(folder1), .app(ref("app1")), .app(ref("app2"))])
        // folder 记录（ID/标题/成员）不变。
        XCTAssertEqual(newLayout.folders, [PersistentFolderRecord(id: folder1, title: "Group 1",
                                                                  members: [ref("app3"), ref("app4")])])
    }

    func testEngineM3CreateFolderTargetThenSource() {
        let (layout, _) = makeDragLayout(titles: ["app1", "app2", "app3"])
        let result = DragMutationEngine.apply(intent: .createFolder(target: ref("app2")),
                                              source: .topLevelApp(ref("app1")), layout: layout)
        guard case .success(let newLayout) = result else {
            return XCTFail("expected .success, got \(result)")
        }
        XCTAssertEqual(newLayout.generation, LayoutGeneration(1))
        guard case .folder(let folderID) = newLayout.topLevelOrder[1] else {
            return XCTFail("expected folder at index 1 (target app2 原格), got \(newLayout.topLevelOrder)")
        }
        // 新 folder 落在 drop 目标 target 原位（格子位置语义；不做 targetIndex-1；
        // BUG7 wave-a）；两 app 移除，app3 补到左边：[app3, F]。
        XCTAssertEqual(newLayout.topLevelOrder, [.app(ref("app3")), .folder(folderID)])
        XCTAssertEqual(newLayout.folders.count, 1)
        XCTAssertEqual(newLayout.folders[0].id, folderID)
        XCTAssertEqual(newLayout.folders[0].title, "Group 1")
        // 初始成员：先目标后源。
        XCTAssertEqual(newLayout.folders[0].members, [ref("app2"), ref("app1")])
    }

    func testEngineM4TopLevelAppIntoFolder() {
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.app(ref("app1")), .folder(folder1), .app(ref("app2"))],
            folders: [PersistentFolderRecord(id: folder1, title: "Group 1", members: [ref("app3")])])
        let result = DragMutationEngine.apply(intent: .intoFolder(target: folder1, at: .tail),
                                              source: .topLevelApp(ref("app1")), layout: layout)
        guard case .success(let newLayout) = result else {
            return XCTFail("expected .success, got \(result)")
        }
        XCTAssertEqual(newLayout.generation, LayoutGeneration(1))
        XCTAssertEqual(newLayout.topLevelOrder, [.folder(folder1), .app(ref("app2"))])
        XCTAssertEqual(newLayout.folders[0].members, [ref("app3"), ref("app1")])
    }

    func testEngineM4CrossFolderAtomicMove() {
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.app(ref("app1")), .folder(folder1), .folder(folder2)],
            folders: [PersistentFolderRecord(id: folder1, title: "Group 1",
                                             members: [ref("app2"), ref("app3")]),
                      PersistentFolderRecord(id: folder2, title: "Group 2",
                                             members: [ref("app4")])])
        let result = DragMutationEngine.apply(intent: .intoFolder(target: folder2, at: .tail),
                                              source: .folderMember(folderID: folder1, app: ref("app2")),
                                              layout: layout)
        guard case .success(let newLayout) = result else {
            return XCTFail("expected .success, got \(result)")
        }
        XCTAssertEqual(newLayout.generation, LayoutGeneration(1))
        // 源 folder 剩 1 成员 → 一次原子 dissolve：剩余成员回 folder 原顶层位。
        XCTAssertEqual(newLayout.topLevelOrder, [.app(ref("app1")), .app(ref("app3")), .folder(folder2)])
        XCTAssertEqual(newLayout.folders.count, 1)
        XCTAssertEqual(newLayout.folders[0].id, folder2)
        XCTAssertEqual(newLayout.folders[0].members, [ref("app4"), ref("app2")])
    }

    func testEngineM5MoveOutDissolvesSingleRemainingMember() {
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.app(ref("app1")), .folder(folder1)],
            folders: [PersistentFolderRecord(id: folder1, title: "Group 1",
                                             members: [ref("app2"), ref("app3")])])
        let result = DragMutationEngine.apply(intent: .topLevelTarget(index: 0),
                                              source: .folderMember(folderID: folder1, app: ref("app2")),
                                              layout: layout)
        guard case .success(let newLayout) = result else {
            return XCTFail("expected .success, got \(result)")
        }
        XCTAssertEqual(newLayout.generation, LayoutGeneration(1))
        // 移出成员插到 index 0；剩 1 → dissolve（app3 回 folder 原顶层位）。
        XCTAssertEqual(newLayout.topLevelOrder, [.app(ref("app2")), .app(ref("app1")), .app(ref("app3"))])
        XCTAssertTrue(newLayout.folders.isEmpty)
    }

    func testEngineM5MoveOutDeletesEmptyFolder() {
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.app(ref("app1")), .folder(folder1)],
            folders: [PersistentFolderRecord(id: folder1, title: "Group 1", members: [ref("app2")])])
        let result = DragMutationEngine.apply(intent: .topLevelTarget(index: 0),
                                              source: .folderMember(folderID: folder1, app: ref("app2")),
                                              layout: layout)
        guard case .success(let newLayout) = result else {
            return XCTFail("expected .success, got \(result)")
        }
        XCTAssertEqual(newLayout.generation, LayoutGeneration(1))
        // 剩 0 → 删除 folder。
        XCTAssertEqual(newLayout.topLevelOrder, [.app(ref("app2")), .app(ref("app1"))])
        XCTAssertTrue(newLayout.folders.isEmpty)
    }

    func testEngineM5MoveOutKeepsFolderWhenMembersRemain() {
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.app(ref("app1")), .folder(folder1)],
            folders: [PersistentFolderRecord(id: folder1, title: "Group 1",
                                             members: [ref("app2"), ref("app3"), ref("app4")])])
        let result = DragMutationEngine.apply(intent: .topLevelTarget(index: 0),
                                              source: .folderMember(folderID: folder1, app: ref("app2")),
                                              layout: layout)
        guard case .success(let newLayout) = result else {
            return XCTFail("expected .success, got \(result)")
        }
        XCTAssertEqual(newLayout.generation, LayoutGeneration(1))
        XCTAssertEqual(newLayout.topLevelOrder, [.app(ref("app2")), .app(ref("app1")), .folder(folder1)])
        XCTAssertEqual(newLayout.folders[0].members, [ref("app3"), ref("app4")])
    }

    func testEngineFolderInternalReorder() {
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.app(ref("app1")), .folder(folder1)],
            folders: [PersistentFolderRecord(id: folder1, title: "Group 1",
                                             members: [ref("app2"), ref("app3")])])
        let result = DragMutationEngine.apply(intent: .insertion(index: 0),
                                              source: .folderMember(folderID: folder1, app: ref("app3")),
                                              layout: layout)
        guard case .success(let newLayout) = result else {
            return XCTFail("expected .success, got \(result)")
        }
        XCTAssertEqual(newLayout.generation, LayoutGeneration(1))
        XCTAssertEqual(newLayout.topLevelOrder, [.app(ref("app1")), .folder(folder1)])
        XCTAssertEqual(newLayout.folders[0].members, [ref("app3"), ref("app2")])
    }

    // MARK: - 6) engine 拒绝（原布局不变、无半提交）
    // 注：DragMutationEngine.apply 恒以 layout.generation 作为 expectedGeneration，
    // 故 staleGeneration 拒绝在引擎入口不可达（stale 防护由 DropResolver 层覆盖，
    // 见 consume 拒绝测试）；此处覆盖其余全部拒绝路径。

    func testEngineRejectsInvalidIntent() {
        let (layout, _) = makeDragLayout(titles: ["app1", "app2"])
        let result = DragMutationEngine.apply(intent: .invalid,
                                              source: .topLevelApp(ref("app1")), layout: layout)
        assertRejected(result, .invalidTarget)
        XCTAssertEqual(layout.generation, .zero, "拒绝后原布局不变")
    }

    func testEngineRejectsCreateFolderInvalidOperands() {
        let (layout, _) = makeDragLayout(titles: ["app1", "app2", "app3"])
        // 非顶层 app 源（folder 成员）→ invalidTarget。
        let memberSource = DragMutationEngine.apply(
            intent: .createFolder(target: ref("app2")),
            source: .folderMember(folderID: folder1, app: ref("app1")), layout: layout)
        assertRejected(memberSource, .invalidTarget)
        // 目标 == 源 → duplicateReference。
        let duplicate = DragMutationEngine.apply(
            intent: .createFolder(target: ref("app1")),
            source: .topLevelApp(ref("app1")), layout: layout)
        assertRejected(duplicate, .duplicateReference)
        // 未知目标 → invalidTarget。
        let unknown = DragMutationEngine.apply(
            intent: .createFolder(target: ref("ghost")),
            source: .topLevelApp(ref("app1")), layout: layout)
        assertRejected(unknown, .invalidTarget)
        XCTAssertEqual(layout.generation, .zero, "拒绝后原布局不变")
    }

    func testEngineRejectsCreateFolderNestedOperand() {
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.app(ref("app1")), .folder(folder1), .app(ref("app2"))],
            folders: [PersistentFolderRecord(id: folder1, title: "Group 1", members: [ref("app3")])])
        // 源已在 folder 内 → nestedFolder（不隐式嵌套/合并）。
        let result = DragMutationEngine.apply(
            intent: .createFolder(target: ref("app2")),
            source: .topLevelApp(ref("app3")), layout: layout)
        assertRejected(result, .nestedFolder)
        XCTAssertEqual(layout.generation, .zero, "拒绝后原布局不变")
    }

    func testEngineRejectsIntoFolderInvalidTargets() {
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.app(ref("app1")), .folder(folder1)],
            folders: [PersistentFolderRecord(id: folder1, title: "Group 1", members: [ref("app2")])])
        // folder 源无 appReference → invalidTarget。
        let folderSource = DragMutationEngine.apply(
            intent: .intoFolder(target: folder1, at: .tail),
            source: .topLevelFolder(folder1), layout: layout)
        assertRejected(folderSource, .invalidTarget)
        // 未知 folder → folderDoesNotExist。
        let unknownFolder = DragMutationEngine.apply(
            intent: .intoFolder(target: folder2, at: .tail),
            source: .topLevelApp(ref("app1")), layout: layout)
        assertRejected(unknownFolder, .folderDoesNotExist(folder2))
        // app 不在布局 → invalidTarget。
        let unknownApp = DragMutationEngine.apply(
            intent: .intoFolder(target: folder1, at: .tail),
            source: .topLevelApp(ref("ghost")), layout: layout)
        assertRejected(unknownApp, .invalidTarget)
        XCTAssertEqual(layout.generation, .zero, "拒绝后原布局不变")
    }

    func testEngineRejectsTopLevelTargetInvalidSources() {
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.app(ref("app1")), .folder(folder1)],
            folders: [PersistentFolderRecord(id: folder1, title: "Group 1", members: [ref("app2")])])
        // 非成员源 → invalidTarget。
        let appSource = DragMutationEngine.apply(
            intent: .topLevelTarget(index: 0),
            source: .topLevelApp(ref("app1")), layout: layout)
        assertRejected(appSource, .invalidTarget)
        // 未知 folder → folderDoesNotExist。
        let unknownFolder = DragMutationEngine.apply(
            intent: .topLevelTarget(index: 0),
            source: .folderMember(folderID: folder2, app: ref("app2")), layout: layout)
        assertRejected(unknownFolder, .folderDoesNotExist(folder2))
        // 成员不在 folder → memberNotFound。
        let unknownMember = DragMutationEngine.apply(
            intent: .topLevelTarget(index: 0),
            source: .folderMember(folderID: folder1, app: ref("ghost")), layout: layout)
        assertRejected(unknownMember, .memberNotFound(ref("ghost")))
        XCTAssertEqual(layout.generation, .zero, "拒绝后原布局不变")
    }

    func testEngineRejectsInsertionUnknownIdentity() {
        let (layout, _) = makeDragLayout(titles: ["app1", "app2"])
        let result = DragMutationEngine.apply(intent: .insertion(index: 0),
                                              source: .topLevelApp(ref("ghost")), layout: layout)
        assertRejected(result, .topLevelEntryNotFound(.app(ref("ghost"))))
        XCTAssertEqual(layout.generation, .zero, "拒绝后原布局不变")
    }
}
