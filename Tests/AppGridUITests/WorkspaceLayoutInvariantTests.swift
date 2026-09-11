// AppGridUITests — WorkspaceLayoutInvariantTests（Phase 1F §3.1 10 不变量 + §10.1 property/fuzz）
// 实现：T-1F-A（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
// 隐私：全部 fixture 用中性类别标题（Alpha/Beta/... 派生 "fixture.…" 合成 bundleID，
// canonicalPath fallback 用合成路径）；无真实身份原值；fuzz 种子固定（可复现）。
//
// 覆盖：10 不变量逐一具名；validator 逐 issue 检出；成功 mutation 恒满足结构性不变量
// （①–⑤）+ 标题上限；失败/拒绝零副作用；fuzz（500 步 SplitMix64 seeded）保持不变量；
// fallback-only（无 bundle ID）引用语义；keepMultiInstance 去重；PresentationAnchor 解析。

import AppCatalogCore
import Foundation
import XCTest
@testable import AppGridUI

/// SplitMix64（固定种子 → 确定性 fuzz；Swift 标准 RNG 的进程内随机化不影响测试可复现性）。
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class WorkspaceLayoutInvariantTests: XCTestCase {

    func makeDefaultFixture(_ titles: [String], revision: UInt64 = 1)
        throws -> (CatalogSnapshot, PersistentWorkspaceLayout) {
        let snapshot = try makeSnapshot(titles: titles, revision: revision)
        return (snapshot, PersistentWorkspaceLayout.makeDefault(catalog: snapshot))
    }

    func assertNoIssues(_ layout: PersistentWorkspaceLayout,
                        file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(WorkspaceLayoutValidator.validate(layout), [], file: file, line: line)
    }

    func assertRejected(_ result: LayoutMutationResult,
                        file: StaticString = #filePath, line: UInt = #line) {
        guard case .rejected = result else {
            XCTFail("expected rejection, got \(result)", file: file, line: line)
            return
        }
    }

    // MARK: - 10 不变量具名锁定（§3.1）

    func testAllTenInvariantsEnumerated() {
        let invariants = WorkspaceInvariant.allCases
        XCTAssertEqual(invariants.count, 10)
        XCTAssertEqual(invariants.map(\.rawValue), Array(1...10))
        for i in 1...5 {
            XCTAssertTrue(WorkspaceInvariant(rawValue: i)!.isStructurallyCheckable)
        }
        for i in 6...10 {
            XCTAssertFalse(WorkspaceInvariant(rawValue: i)!.isStructurallyCheckable)
        }
        for invariant in invariants {
            XCTAssertFalse(invariant.neutralTitle.isEmpty)   // 可打日志的中性描述存在
        }
    }

    // MARK: - validator 逐 issue 检出

    func testValidatorDetectsDuplicateTopLevelAppReference() {
        let ref = PersistentAppReference.bundleID("fixture.alpha")
        let layout = PersistentWorkspaceLayout(generation: .zero,
                                               topLevelOrder: [.app(ref), .app(ref)],
                                               folders: [])
        let issues = WorkspaceLayoutValidator.validate(layout)
        XCTAssertTrue(issues.contains(.duplicateAppReference(ref)))
        XCTAssertThrowsError(try WorkspaceLayoutValidator.assertValid(layout)) { error in
            guard case LayoutValidationError.invariantsViolated = error else {
                return XCTFail("wrong error: \(error)")
            }
        }
    }

    func testValidatorDetectsDuplicateFolderMemberAndCrossFolderDuplicate() {
        let a = PersistentAppReference.bundleID("fixture.alpha")
        let b = PersistentAppReference.bundleID("fixture.beta")
        let f1 = FolderID(uuid: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!)
        let f2 = FolderID(uuid: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!)
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.folder(f1), .folder(f2)],
            folders: [
                PersistentFolderRecord(id: f1, title: "Group 1", members: [a, a]),           // 成员内重复
                PersistentFolderRecord(id: f2, title: "Group 2", members: [a, b]),           // 跨 folder 重复（不变量①）
            ])
        let issues = WorkspaceLayoutValidator.validate(layout)
        XCTAssertTrue(issues.contains(.duplicateFolderMember(a)))
        XCTAssertTrue(issues.contains(.duplicateAppReference(a)))
    }

    func testValidatorDetectsEmptyFolder() {
        let f = FolderID(uuid: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!)
        let layout = PersistentWorkspaceLayout(generation: .zero,
                                               topLevelOrder: [.folder(f)],
                                               folders: [PersistentFolderRecord(id: f, title: "Group 1", members: [])])
        XCTAssertTrue(WorkspaceLayoutValidator.validate(layout).contains(.emptyFolder(f)))
    }

    func testValidatorDetectsSingleMemberFolder() {
        let a = PersistentAppReference.bundleID("fixture.alpha")
        let f = FolderID(uuid: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!)
        let layout = PersistentWorkspaceLayout(generation: .zero,
                                               topLevelOrder: [.folder(f)],
                                               folders: [PersistentFolderRecord(id: f, title: "Group 1", members: [a])])
        XCTAssertTrue(WorkspaceLayoutValidator.validate(layout).contains(.singleMemberFolder(f)))
    }

    func testValidatorDetectsDuplicateFolderRecordAndOrphanEntry() {
        let f = FolderID(uuid: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!)
        let a = PersistentAppReference.bundleID("fixture.alpha")
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.folder(f), .folder(f)],
            folders: [PersistentFolderRecord(id: f, title: "Group 1", members: [a])])
        let issues = WorkspaceLayoutValidator.validate(layout)
        XCTAssertTrue(issues.contains(.duplicateFolderRecord(f)))

        let orphan = PersistentWorkspaceLayout(generation: .zero,
                                               topLevelOrder: [.folder(f)],
                                               folders: [])
        XCTAssertTrue(WorkspaceLayoutValidator.validate(orphan).contains(.folderEntryWithoutRecord(f)))
    }

    func testValidatorDetectsOversizedTitle() {
        let a = PersistentAppReference.bundleID("fixture.alpha")
        let b = PersistentAppReference.bundleID("fixture.beta")
        let f = FolderID(uuid: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!)
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.folder(f)],
            folders: [PersistentFolderRecord(id: f, title: String(repeating: "N", count: 65), members: [a, b])])
        XCTAssertTrue(WorkspaceLayoutValidator.validate(layout).contains(.titleExceedsGraphemeLimit(f)))
    }

    // MARK: - 结构性不变量在完整 mutation 序列后保持（①–⑤ + 标题上限）

    func testStructuralInvariantsHoldAcrossMutationSequence() throws {
        let (snapshot, defaultLayout) = try makeDefaultFixture(["Alpha", "Beta", "Gamma", "Delta"])
        _ = snapshot
        let refs = defaultLayout.topLevelOrder.compactMap { entry -> PersistentAppReference? in
            if case .app(let r) = entry { return r }
            return nil
        }
        let folderID = FolderID(uuid: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!)
        var layout = defaultLayout
        var engine = LayoutMutation(expectedGeneration: layout.generation)

        func apply(_ next: () -> LayoutMutationResult,
                   file: StaticString = #filePath, line: UInt = #line) {
            let result = next()
            switch result {
            case .success(let newLayout):
                layout = newLayout
                engine = LayoutMutation(expectedGeneration: layout.generation)
                assertNoIssues(layout, file: file, line: line)          // 提交后必满足全部结构性不变量
            default:
                XCTFail("unexpected result: \(result)", file: file, line: line)
            }
        }

        apply { engine.createFolder(in: layout, target: refs[0], source: refs[1], folderID: folderID) }
        apply { engine.addToFolder(in: layout, app: refs[2], folderID: folderID, at: .head) }
        apply { engine.reorderFolderMembers(in: layout, folderID: folderID, member: refs[2], toIndex: 2) }
        apply { engine.renameFolder(in: layout, folderID: folderID, to: "Utilities") }
        apply { engine.moveOutOfFolder(in: layout, folderID: folderID, member: refs[1], toIndex: 3) }
        apply { engine.reorderTopLevel(in: layout, identity: .folder(folderID), toIndex: 2) }   // folder 移末尾
        apply { engine.addToFolder(in: layout, app: refs[1], folderID: folderID) }   // 再移回
        apply { engine.reorderTopLevel(in: layout, identity: .app(refs[3]), toIndex: 1) }   // gamma 移后

        XCTAssertEqual(layout.generation.value, 8)     // 8 次成功 mutation → 单调 +8
        XCTAssertEqual(layout.folders.count, 1)
        for folder in layout.folders {
            XCTAssertTrue(folder.members.count >= 2)
            XCTAssertLessThanOrEqual(folder.title.count, 64)
        }
        assertNoIssues(layout)
    }

    // MARK: - fuzz（500 步 SplitMix64 seeded；成功→不变量 + gen+1；拒绝→布局原值）

    func testFuzzMutationsAlwaysKeepInvariants() throws {
        let (snapshot, defaultLayout) = try makeDefaultFixture(
            ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta"])
        _ = snapshot
        var rng = SplitMix64(seed: 0x5EED_CAFE_DEAD_BEEF)
        var layout = defaultLayout
        var engine = LayoutMutation(expectedGeneration: layout.generation)

        let neutralTitles = ["Utilities", "Work", "Archive", "Reading", "", "   "]
        func randomInt(_ bound: Int) -> Int { bound <= 0 ? 0 : Int(rng.next() % UInt64(bound)) }

        var steps = 0
        for _ in 0..<500 {
            let topLevelApps = layout.topLevelOrder.compactMap { entry -> PersistentAppReference? in
                if case .app(let ref) = entry { return ref }
                return nil
            }
            let folderIDs = layout.folders.map(\.id)

            var op: (() -> LayoutMutationResult)?
            switch randomInt(7) {
            case 0:   // 顶层重排
                if !layout.topLevelOrder.isEmpty {
                    let identity = layout.topLevelOrder[randomInt(layout.topLevelOrder.count)].identity
                    op = { engine.reorderTopLevel(in: layout, identity: identity,
                                                  toIndex: randomInt(layout.topLevelOrder.count + 2) - 1) }
                }
            case 1:   // 建夹（仅顶层 app 操作数 → 永不 invalid/nested；target/source 互异）
                if topLevelApps.count >= 2 {
                    let i = randomInt(topLevelApps.count)
                    var j = randomInt(topLevelApps.count - 1)
                    if j >= i { j += 1 }
                    let target = topLevelApps[i]
                    let source = topLevelApps[j]
                    op = { engine.createFolder(in: layout, target: target, source: source,
                                               title: neutralTitles[randomInt(neutralTitles.count)]) }
                }
            case 2:   // 加入 folder（顶层 app 移入 / 跨 folder move）
                if !folderIDs.isEmpty && !topLevelApps.isEmpty {
                    let app = topLevelApps[randomInt(topLevelApps.count)]
                    let fid = folderIDs[randomInt(folderIDs.count)]
                    op = { engine.addToFolder(in: layout, app: app, folderID: fid,
                                              at: randomInt(2) == 0 ? .head : .tail) }
                }
            case 3:   // 移出 folder
                if !folderIDs.isEmpty {
                    let fid = folderIDs[randomInt(folderIDs.count)]
                    if let folder = layout.folder(id: fid), !folder.members.isEmpty {
                        let member = folder.members[randomInt(folder.members.count)]
                        op = { engine.moveOutOfFolder(in: layout, folderID: fid, member: member,
                                                      toIndex: randomInt(layout.topLevelOrder.count + 2) - 1) }
                    }
                }
            case 4:   // folder 内重排
                if !folderIDs.isEmpty {
                    let fid = folderIDs[randomInt(folderIDs.count)]
                    if let folder = layout.folder(id: fid), folder.members.count >= 2 {
                        let member = folder.members[randomInt(folder.members.count)]
                        op = { engine.reorderFolderMembers(in: layout, folderID: fid, member: member,
                                                           toIndex: randomInt(folder.members.count + 2) - 1) }
                    }
                }
            case 5:   // 改名
                if !folderIDs.isEmpty {
                    let fid = folderIDs[randomInt(folderIDs.count)]
                    let title = neutralTitles[randomInt(neutralTitles.count)]
                    op = { engine.renameFolder(in: layout, folderID: fid, to: title) }
                }
            default:  // stale：错误 expectedGeneration → 必须拒绝且布局不变
                if !layout.topLevelOrder.isEmpty {
                    let identity = layout.topLevelOrder[randomInt(layout.topLevelOrder.count)].identity
                    let wrongGen = LayoutMutation(expectedGeneration: layout.generation.incremented())
                    let before = layout
                    let result = wrongGen.reorderTopLevel(in: layout, identity: identity, toIndex: 0)
                    assertRejected(result)
                    XCTAssertEqual(layout, before)      // 拒绝零副作用
                }
            }

            guard let concrete = op else { continue }
            let before = layout
            let beforeGen = layout.generation
            let result = concrete()
            switch result {
            case .success(let newLayout):
                XCTAssertEqual(newLayout.generation.value, beforeGen.value + 1)   // 成功才递增
                layout = newLayout
                engine = LayoutMutation(expectedGeneration: layout.generation)
                assertNoIssues(layout)                                             // 不变量恒保持
            case .rejected:
                XCTAssertEqual(layout, before)                                     // 拒绝 → 原值
            case .noOp(let unchanged):
                XCTAssertEqual(unchanged, before)
                XCTAssertEqual(unchanged.generation, beforeGen)                    // no-op 不增 generation
                assertNoIssues(layout)
            case .cancelled:
                XCTFail("engine must never produce .cancelled")
            }
            steps += 1
        }
        XCTAssertGreaterThan(steps, 80, "fuzz should exercise a healthy mix of ops")
        assertNoIssues(layout)
    }

    // MARK: - fallback-only 引用（bundleID nil → canonicalPath）

    func testCanonicalPathFallbackReferencesWorkEndToEnd() throws {
        let a = "file:///tmp/Domain/Alpha.app"
        let b = "file:///tmp/Domain/Beta.app"
        let records = [a, b].enumerated().map { index, path in
            let url = URL(fileURLWithPath: path)
            let id = AppID.canonicalURLFallback(url)
            return CatalogFixture.record(id: id,
                                         displayName: ["Alpha", "Beta"][index],
                                         bundleID: nil,                      // 无 bundle ID → fallback
                                         url: url,
                                         icon: IconIdentity.from(appID: id),
                                         rootPriority: 0)
        }
        let snapshot = try CatalogFixture.snapshot(records: records, revision: CatalogRevision(1))
        let layout = PersistentWorkspaceLayout.makeDefault(catalog: snapshot)

        // 引用形态为 canonicalPath；身份等价于规范化后的路径
        let refs = layout.topLevelOrder.compactMap { entry -> PersistentAppReference? in
            if case .app(let r) = entry { return r }
            return nil
        }
        XCTAssertEqual(refs.count, 2)
        guard case .canonicalPath(let p0) = refs[0] else {
            return XCTFail("expected canonicalPath reference")
        }
        XCTAssertEqual(p0, PersistentAppReference.normalizedPath(URL(fileURLWithPath: a)))

        // mutation 全链路可用（建夹 + 移入 + 移出）
        var engine = LayoutMutation(expectedGeneration: layout.generation)
        guard case .success(let withFolder) = engine.createFolder(in: layout, target: refs[0], source: refs[1]) else {
            return XCTFail()
        }
        assertNoIssues(withFolder)
        engine = LayoutMutation(expectedGeneration: withFolder.generation)
        guard case .success(let out) = engine.moveOutOfFolder(in: withFolder, folderID: withFolder.folders[0].id, member: refs[0], toIndex: 0) else {
            return XCTFail()
        }
        assertNoIssues(out)

        // matches(record:)：大小写/尾斜杠归一化
        let upper = URL(fileURLWithPath: "file:///TMP/DOMAIN/ALPHA.APP/")
        let ref = PersistentAppReference.canonicalPath(PersistentAppReference.normalizedPath(upper))
        XCTAssertTrue(ref.matches(record: records[0]))
    }

    func testFallbackDedupesCaseVariantsInDefaultLayout() throws {
        let low = URL(fileURLWithPath: "file:///tmp/Domain/Alpha.app")
        let upper = URL(fileURLWithPath: "file:///TMP/DOMAIN/ALPHA.APP")
        XCTAssertNotEqual(low, upper)   // 不同 URL 原值…
        XCTAssertEqual(PersistentAppReference.normalizedPath(low),
                       PersistentAppReference.normalizedPath(upper))   // …但同一规范化引用（case-insensitive）
        let records = [
            CatalogFixture.record(id: AppID.canonicalURLFallback(low),
                                  displayName: "Alpha", bundleID: nil, url: low,
                                  icon: IconIdentity.from(appID: AppID.canonicalURLFallback(low)), rootPriority: 0),
            CatalogFixture.record(id: AppID.canonicalURLFallback(upper),
                                  displayName: "Alpha Upper", bundleID: nil, url: upper,
                                  icon: IconIdentity.from(appID: AppID.canonicalURLFallback(upper)), rootPriority: 0),
        ]
        let snapshot = try CatalogFixture.snapshot(records: records, revision: CatalogRevision(1))
        let layout = PersistentWorkspaceLayout.makeDefault(catalog: snapshot)
        XCTAssertEqual(layout.appReferenceCount, 1)     // makeDefault 去重（保首个，确定性）
        assertNoIssues(layout)
    }

    // MARK: - keepMultiInstance 去重（bundleID 重复快照 → default 布局单引用）

    func testKeepMultiInstanceSnapshotDedupedInDefaultLayout() throws {
        let urlA = CatalogFixture.tempURL(named: "fixture-multi-a-0.app")
        let urlB = CatalogFixture.tempURL(named: "fixture-multi-b-1.app")
        let idA = CatalogFixture.appID("fixture.multi")
        let idB = CatalogFixture.appID("fixture.multi")
        let records = [
            CatalogFixture.record(id: idA, displayName: "Multi A", bundleID: "fixture.multi",
                                  url: urlA, icon: IconIdentity.from(appID: idA), rootPriority: 0),
            CatalogFixture.record(id: idB, displayName: "Multi B", bundleID: "fixture.multi",
                                  url: urlB, icon: IconIdentity.from(appID: idB), rootPriority: 0),
        ]
        let snapshot = try CatalogFixture.snapshot(
            records: records, revision: CatalogRevision(1),
            policy: CatalogPolicy(duplicateResolution: .keepMultiInstance))
        XCTAssertEqual(snapshot.records.count, 2)       // builder 保留为多实例
        let layout = PersistentWorkspaceLayout.makeDefault(catalog: snapshot)
        XCTAssertEqual(layout.appReferenceCount, 1)     // 布局层同一逻辑引用只出现一次（不变量①）
        assertNoIssues(layout)
    }

    // MARK: - PresentationAnchor（重排/解散后稳定落点；无 hashValue）

    func testPresentationAnchorResolvesAfterReorder() throws {
        let (snapshot, layout) = try makeDefaultFixture(["Alpha", "Beta", "Gamma"])
        let refs = layout.topLevelOrder.compactMap { entry -> PersistentAppReference? in
            if case .app(let r) = entry { return r }
            return nil
        }
        let anchor = PresentationAnchor.topLevelApp(refs[0])
        let before = VisibleWorkspaceProjection.project(layout: layout, catalog: snapshot)
        XCTAssertEqual(PresentationAnchorResolver.resolve(anchor, in: before), 0)
        XCTAssertEqual(PresentationAnchorResolver.resolve(.firstAvailable, in: before), 0)

        guard case .success(let reordered) = LayoutMutation(expectedGeneration: .zero)
            .reorderTopLevel(in: layout, identity: .app(refs[0]), toIndex: 2) else { return XCTFail() }
        let after = VisibleWorkspaceProjection.project(layout: reordered, catalog: snapshot)
        XCTAssertEqual(PresentationAnchorResolver.resolve(anchor, in: after), 2)   // 跟随移动后的新落点
    }

    func testPresentationAnchorForFolderAndDissolvedFolder() throws {
        let (snapshot, layout) = try makeDefaultFixture(["Alpha", "Beta", "Gamma"])
        let refs = layout.topLevelOrder.compactMap { entry -> PersistentAppReference? in
            if case .app(let r) = entry { return r }
            return nil
        }
        let folderID = FolderID(uuid: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!)
        guard case .success(let f) = LayoutMutation(expectedGeneration: .zero).createFolder(
            in: layout, target: refs[0], source: refs[1], folderID: folderID) else { return XCTFail() }
        let projection = VisibleWorkspaceProjection.project(layout: f, catalog: snapshot)
        XCTAssertEqual(PresentationAnchorResolver.resolve(.folder(folderID), in: projection), 0)
        // 锚到成员 app：folder 未 dissolve → members 不在顶层 → nil（调用层回退 firstAvailable 语义）
        XCTAssertNil(PresentationAnchorResolver.resolve(.topLevelApp(refs[0]), in: projection))

        // 解散后：folder 锚 → nil；剩余成员锚 → 确定性新落点（folder 原顶层位）
        guard case .success(let dissolved) = LayoutMutation(expectedGeneration: f.generation)
            .moveOutOfFolder(in: f, folderID: folderID, member: refs[0], toIndex: 3) else { return XCTFail() }
        let after = VisibleWorkspaceProjection.project(layout: dissolved, catalog: snapshot)
        XCTAssertNil(PresentationAnchorResolver.resolve(.folder(folderID), in: after))
        XCTAssertEqual(PresentationAnchorResolver.resolve(.topLevelApp(refs[1]), in: after), 0)
        XCTAssertEqual(PresentationAnchorResolver.resolve(.topLevelApp(refs[0]), in: after), 2)
    }

    func testPresentationAnchorFirstAvailableOnEmptyProjection() throws {
        let emptyCatalog = try makeSnapshot(titles: [], revision: 1)
        let projection = VisibleWorkspaceProjection.project(
            layout: PersistentWorkspaceLayout.empty(), catalog: emptyCatalog)
        XCTAssertNil(PresentationAnchorResolver.resolve(.firstAvailable, in: projection))
        XCTAssertNil(PresentationAnchorResolver.resolve(
            .topLevelApp(.bundleID("fixture.alpha")), in: projection))
        XCTAssertEqual(projection.topLevel.count, 0)
    }

    // MARK: - 引擎绝不产生 .cancelled（语义保留位由调用层映射）

    func testEngineNeverProducesCancelledCase() throws {
        let (_, layout) = try makeDefaultFixture(["Alpha", "Beta"])
        let refs = layout.topLevelOrder.compactMap { entry -> PersistentAppReference? in
            if case .app(let r) = entry { return r }
            return nil
        }
        let results: [LayoutMutationResult] = [
            LayoutMutation(expectedGeneration: .zero)
                .reorderTopLevel(in: layout, identity: .app(refs[0]), toIndex: 1),
            LayoutMutation(expectedGeneration: .zero)
                .createFolder(in: layout, target: refs[0], source: refs[1]),
        ]
        for result in results {
            if case .cancelled = result {
                XCTFail("engine must not produce .cancelled")
            }
        }
        assertNoIssues(layout)
    }
}
