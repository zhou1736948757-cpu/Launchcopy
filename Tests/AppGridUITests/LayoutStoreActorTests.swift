// AppGridUITests — LayoutStoreActorTests（Phase 1F §10.1 自动化验证矩阵，store actor 部分）
// 实现：T-1F-B-tests-actor（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
// 隐私：全部 fixture 用中性假数据（"fixture.alpha"/"fixture.beta"/"Group 1"），
// 无真实 app 名/bundle ID/路径；每个测试独立临时根（FileManager.temporaryDirectory + UUID），
// tearDown 统一清理（矩阵点 13）。
//
// 覆盖 §10.1 store 矩阵：首启；save-load-restart 往返；原子替换（无 temp 残留 + codec 可 decode）；
// 中断写只读保护（证据保留、enqueue no-op）；主槽坏+备槽有效 → loadedFromBackup；双槽坏 → 只读保护；
// 写失败 → persistenceDegraded（重试恢复、LKG 不清除）；coalescing latest-wins；flush barrier 幂等；
// reset 归档+立即持久化默认；未知未来版本绝不覆盖；多实例 last-writer-wins + stale 拒绝计数。

import AppCatalogCore
import Foundation
import XCTest
@testable import AppGridUI

final class LayoutStoreActorTests: XCTestCase {

    // MARK: - 夹具（中性）

    private var tempRoots: [URL] = []

    override func tearDown() {
        for root in tempRoots {
            try? FileManager.default.removeItem(at: root)
        }
        tempRoots = []
        super.tearDown()
    }

    /// 每个测试独立临时根（矩阵点 13），tearDown 统一清理。
    private func makeTempStoreDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("layout-store-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        tempRoots.append(root)
        return root
    }

    private func slotA(_ dir: URL) -> URL {
        dir.appendingPathComponent("workspace-layout-v1-a.json")
    }

    private func slotB(_ dir: URL) -> URL {
        dir.appendingPathComponent("workspace-layout-v1-b.json")
    }

    /// 中性布局构造（generation 可指定；withFolder 时含一个 folder，成员不进顶层）。
    private func makeLayout(generation: UInt64, withFolder: Bool = false) -> PersistentWorkspaceLayout {
        let refA = PersistentAppReference.bundleID("fixture.alpha")
        let refB = PersistentAppReference.bundleID("fixture.beta")
        if withFolder {
            let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
            return PersistentWorkspaceLayout(
                generation: LayoutGeneration(generation),
                topLevelOrder: [.folder(folderID)],
                folders: [PersistentFolderRecord(id: folderID, title: "Group 1", members: [refA, refB])])
        }
        return PersistentWorkspaceLayout(
            generation: LayoutGeneration(generation),
            topLevelOrder: [.app(refA), .app(refB)],
            folders: [])
    }

    private func encode(_ layout: PersistentWorkspaceLayout, writeGeneration: UInt64) throws -> Data {
        try LayoutStoreCodec.encode(layout, writeGeneration: writeGeneration)
    }

    private func writeSlot(_ url: URL, data: Data) throws {
        try data.write(to: url, options: .atomic)
    }

    private func writeCorruptSlot(_ url: URL) throws {
        try writeSlot(url, data: Data("not a valid layout payload".utf8))
    }

    private func slotFiles(in dir: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
    }

    private func hasTempFiles(in dir: URL) -> Bool {
        slotFiles(in: dir).contains { $0.lastPathComponent.hasSuffix(".tmp") }
    }

    /// 磁盘两槽中最高 layout generation（无有效槽 → nil）。
    private func maxPersistedLayoutGeneration(in dir: URL) -> UInt64? {
        var maxGen: UInt64?
        for url in [slotA(dir), slotB(dir)] {
            guard let data = try? Data(contentsOf: url) else { continue }
            if case .valid(let decoded) = LayoutStoreCodec.decode(data) {
                maxGen = max(maxGen ?? 0, decoded.layout.generation.value)
            }
        }
        return maxGen
    }

    // MARK: - 1. 首启

    func testFirstLaunchEmptyDirectoryReturnsFirstLaunch() async throws {
        let dir = try makeTempStoreDirectory()
        let actor = LayoutStoreActor(storeDirectory: dir)
        let result = await actor.load()
        XCTAssertEqual(result, .firstLaunch)
        let state = await actor.currentState()
        XCTAssertEqual(state, .healthy)
        let mode = await actor.lockMode()
        XCTAssertEqual(mode, .singleWriter)
    }

    // MARK: - 2. save-load-restart 往返

    func testSaveLoadRestartRoundTripPreservesLayoutAndGeneration() async throws {
        let dir = try makeTempStoreDirectory()
        let layout = makeLayout(generation: 3, withFolder: true)   // 含 folder（codec 修复后可往返）

        let first = LayoutStoreActor(storeDirectory: dir)
        let firstLoad = await first.load()
        XCTAssertEqual(firstLoad, .firstLaunch)
        await first.enqueue(layout)
        _ = await first.flush()

        // 新 actor 实例（模拟重启）
        let second = LayoutStoreActor(storeDirectory: dir)
        let result = await second.load()
        guard case .loaded(let loadedLayout, let writeGeneration) = result else {
            return XCTFail("expected .loaded, got \(result)")
        }
        XCTAssertEqual(loadedLayout, layout)
        XCTAssertEqual(loadedLayout.generation.value, 3)
        XCTAssertEqual(writeGeneration, 1)   // 空 store 首次写 → wg 1
        let secondState = await second.currentState()
        XCTAssertEqual(secondState, .healthy)
    }

    // MARK: - 3. 原子替换

    func testAtomicReplaceLeavesNoTempFilesAndDecodesAsLoaded() async throws {
        let dir = try makeTempStoreDirectory()
        let layout = makeLayout(generation: 1)
        let actor = LayoutStoreActor(storeDirectory: dir)
        _ = await actor.load()
        await actor.enqueue(layout)
        _ = await actor.flush()

        // 持久化后目录无残留 temp 文件
        XCTAssertFalse(hasTempFiles(in: dir))
        // 槽文件可被 codec decode 为 .loaded
        let slotData = try Data(contentsOf: slotA(dir))
        guard case .valid(let decoded) = LayoutStoreCodec.decode(slotData) else {
            return XCTFail("slot should decode as valid")
        }
        XCTAssertEqual(decoded.layout, layout)
        XCTAssertEqual(decoded.writeGeneration, 1)
        // 新 actor load → .loaded
        let reloaded = LayoutStoreActor(storeDirectory: dir)
        let reloadResult = await reloaded.load()
        guard case .loaded = reloadResult else {
            return XCTFail("expected .loaded")
        }
    }

    // MARK: - 4. 中断写

    func testInterruptedWriteTriggersReadOnlyProtectionAndPreservesEvidence() async throws {
        let dir = try makeTempStoreDirectory()
        let corruptBytes = Data("not a valid layout payload".utf8)
        try writeSlot(slotA(dir), data: corruptBytes)
        // 中断写残留 temp 文件
        try Data("partial".utf8).write(to: slotA(dir).appendingPathExtension("tmp"))

        let actor = LayoutStoreActor(storeDirectory: dir)
        let result = await actor.load()
        print("DBG4 load result: \(result)")
        print("DBG4 dir after load: \(slotFiles(in: dir).map(\.lastPathComponent))")
        guard case .readOnlyProtection(let reason) = result else {
            return XCTFail("expected readOnlyProtection, got \(result)")
        }
        XCTAssertEqual(reason, .bothSlotsCorrupt)
        let state = await actor.currentState()
        print("DBG4 state before enqueue: \(state)")
        XCTAssertEqual(state, .readOnlyProtection(.bothSlotsCorrupt))

        // enqueue 为 no-op（持久化暂停），不产生新槽文件
        await actor.enqueue(makeLayout(generation: 1))
        let stateAfterEnqueue = await actor.currentState()
        print("DBG4 state after enqueue: \(stateAfterEnqueue)")
        print("DBG4 dir after enqueue: \(slotFiles(in: dir).map(\.lastPathComponent))")
        XCTAssertEqual(stateAfterEnqueue, .readOnlyProtection(.bothSlotsCorrupt))
        XCTAssertFalse(FileManager.default.fileExists(atPath: slotA(dir).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: slotB(dir).path))

        // temp 残留已清理；损坏证据 quarantine 保留（中性命名，字节不变）
        XCTAssertFalse(hasTempFiles(in: dir))
        let evidence = slotFiles(in: dir).filter { $0.lastPathComponent.contains(".corrupt-") }
        XCTAssertEqual(evidence.count, 1)
        XCTAssertEqual(try Data(contentsOf: evidence[0]), corruptBytes)
    }

    // MARK: - 5. 主槽损坏 + 备份有效

    func testPrimaryCorruptBackupValidLoadsFromBackup() async throws {
        let dir = try makeTempStoreDirectory()
        let layout = makeLayout(generation: 2)
        try writeCorruptSlot(slotA(dir))
        try writeSlot(slotB(dir), data: encode(layout, writeGeneration: 2))

        let actor = LayoutStoreActor(storeDirectory: dir)
        let result = await actor.load()
        guard case .loadedFromBackup(let loadedLayout, let writeGeneration) = result else {
            return XCTFail("expected .loadedFromBackup, got \(result)")
        }
        XCTAssertEqual(loadedLayout, layout)
        XCTAssertEqual(writeGeneration, 2)
        let state = await actor.currentState()
        XCTAssertEqual(state, .healthy)
        // 损坏证据保留原位（下次成功写才轮换）
        XCTAssertTrue(FileManager.default.fileExists(atPath: slotA(dir).path))
    }

    // MARK: - 6. 双槽损坏

    func testBothSlotsCorruptTriggersReadOnlyProtection() async throws {
        let dir = try makeTempStoreDirectory()
        try writeCorruptSlot(slotA(dir))
        try writeCorruptSlot(slotB(dir))

        let actor = LayoutStoreActor(storeDirectory: dir)
        let result = await actor.load()
        guard case .readOnlyProtection(let reason) = result else {
            return XCTFail("expected readOnlyProtection, got \(result)")
        }
        XCTAssertEqual(reason, .bothSlotsCorrupt)
        // 两槽均 quarantine（证据保留），原槽文件不再存在
        let evidence = slotFiles(in: dir).filter { $0.lastPathComponent.contains(".corrupt-") }
        XCTAssertEqual(evidence.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: slotA(dir).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: slotB(dir).path))
    }

    // MARK: - 7. 写失败 → persistenceDegraded（重试恢复；LKG 不清除）

    func testWriteFailureDegradesThenRecoversAndKeepsLKG() async throws {
        let dir = try makeTempStoreDirectory()
        let io = FaultInjectingIO()
        let actor = LayoutStoreActor(storeDirectory: dir, io: io,
                                     retrySchedule: [0.01, 0.01], flushTimeout: 2.0)

        // 基线：成功落盘 gen 1（LKG）
        _ = await actor.load()
        await actor.enqueue(makeLayout(generation: 1))
        _ = await actor.flush()
        let baselineState = await actor.currentState()
        XCTAssertEqual(baselineState, .healthy)
        XCTAssertEqual(maxPersistedLayoutGeneration(in: dir), 1)

        // 写失败 → persistenceDegraded；LKG 绝不清除
        io.failWrites = true
        await actor.enqueue(makeLayout(generation: 2))
        try? await Task.sleep(nanoseconds: 300_000_000)
        let stateAfterWait = await actor.currentState()
        let rejectionsAfterWait = await actor.staleRejectionCount()
        print("DBG7 state after 300ms: \(stateAfterWait), rejections: \(rejectionsAfterWait)")
        print("DBG7 dir after 300ms: \(slotFiles(in: dir).map(\.lastPathComponent))")
        let t0 = Date()
        let failedFlush = await actor.flush()
        print("DBG7 flush1 result: \(failedFlush) after \(Date().timeIntervalSince(t0))s")
        print("DBG7 dir after flush1: \(slotFiles(in: dir).map(\.lastPathComponent))")
        XCTAssertEqual(failedFlush, .failed)
        let degradedState = await actor.currentState()
        if case .persistenceDegraded(.writeFailed) = degradedState {
            // 符合预期
        } else {
            XCTFail("expected persistenceDegraded(.writeFailed), got \(degradedState)")
        }
        XCTAssertEqual(maxPersistedLayoutGeneration(in: dir), 1)   // LKG 保留

        // 恢复：写成功 → healthy，pending 落盘
        io.failWrites = false
        let recoveredFlush = await actor.flush()
        guard case .persisted = recoveredFlush else {
            return XCTFail("expected .persisted, got \(recoveredFlush)")
        }
        let recoveredState = await actor.currentState()
        XCTAssertEqual(recoveredState, .healthy)
        XCTAssertEqual(maxPersistedLayoutGeneration(in: dir), 2)
    }

    // MARK: - 8. coalescing latest-wins

    func testCoalescingLatestWinsPersistsHighestGeneration() async throws {
        let dir = try makeTempStoreDirectory()
        let actor = LayoutStoreActor(storeDirectory: dir)
        _ = await actor.load()
        await actor.enqueue(makeLayout(generation: 1))
        await actor.enqueue(makeLayout(generation: 2))
        await actor.enqueue(makeLayout(generation: 3))
        _ = await actor.flush()
        XCTAssertEqual(maxPersistedLayoutGeneration(in: dir), 3)
        let state = await actor.currentState()
        XCTAssertEqual(state, .healthy)
    }

    // MARK: - 9. flush barrier（幂等）

    func testFlushBarrierWaitsAndIsIdempotent() async throws {
        let dir = try makeTempStoreDirectory()
        let actor = LayoutStoreActor(storeDirectory: dir)
        _ = await actor.load()

        // 无 pending → nothingPending
        let emptyFlush = await actor.flush()
        XCTAssertEqual(emptyFlush, .nothingPending)

        // enqueue 后 flush：barrier 等待在途持久化完成，pending 已同步落盘
        await actor.enqueue(makeLayout(generation: 1))
        let result = await actor.flush()
        XCTAssertEqual(result, .nothingPending)   // 在途 loop 已排空 pending（实现语义）
        XCTAssertEqual(maxPersistedLayoutGeneration(in: dir), 1)

        // 再次 flush → nothingPending（幂等）
        let again = await actor.flush()
        XCTAssertEqual(again, .nothingPending)
    }

    // MARK: - 10. reset

    func testResetArchivesClearsAndPersistsDefaultLayout() async throws {
        let dir = try makeTempStoreDirectory()
        let actor = LayoutStoreActor(storeDirectory: dir)
        _ = await actor.load()
        await actor.enqueue(makeLayout(generation: 5))
        _ = await actor.flush()
        XCTAssertEqual(maxPersistedLayoutGeneration(in: dir), 5)

        let defaultLayout = makeLayout(generation: 0)
        let result = await actor.reset(defaultLayout: defaultLayout)
        guard case .reset(let writeGeneration) = result else {
            return XCTFail("expected .reset, got \(result)")
        }
        XCTAssertEqual(writeGeneration, 2)   // 归档后立即持久化 → wg = max(lastPersisted, 0) + 1
        let state = await actor.currentState()
        XCTAssertEqual(state, .healthy)

        // 归档文件存在（中性命名 *.reset-*）
        let archives = slotFiles(in: dir).filter { $0.lastPathComponent.contains(".reset-") }
        XCTAssertEqual(archives.count, 1)

        // 新 actor load → 默认布局
        let reloaded = LayoutStoreActor(storeDirectory: dir)
        let loadResult = await reloaded.load()
        guard case .loaded(let loadedLayout, _) = loadResult else {
            return XCTFail("expected .loaded, got \(loadResult)")
        }
        XCTAssertEqual(loadedLayout, defaultLayout)
    }

    // MARK: - 11. 未知未来版本绝不覆盖

    func testUnknownFutureVersionNeverOverwritten() async throws {
        let dir = try makeTempStoreDirectory()
        // 预置 schemaVersion > 1 文件：基于 codec 编码产物提升版本号（保持其余结构完整）
        let encoded = try encode(makeLayout(generation: 1), writeGeneration: 1)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var future = json
        future["schemaVersion"] = 99
        let futureData = try JSONSerialization.data(withJSONObject: future, options: [.sortedKeys])
        try writeSlot(slotA(dir), data: futureData)

        let actor = LayoutStoreActor(storeDirectory: dir)
        let result = await actor.load()
        guard case .readOnlyProtection(let reason) = result else {
            return XCTFail("expected readOnlyProtection, got \(result)")
        }
        XCTAssertEqual(reason, .unknownFutureVersion(99))

        // enqueue no-op；文件字节不变
        await actor.enqueue(makeLayout(generation: 2))
        let state = await actor.currentState()
        XCTAssertEqual(state, .readOnlyProtection(.unknownFutureVersion(99)))
        XCTAssertEqual(try Data(contentsOf: slotA(dir)), futureData)
    }

    // MARK: - 12. 多实例（flock 单写者；last-writer-wins；stale 拒绝计数）

    func testMultiInstanceLastWriterWinsAndStaleRejection() async throws {
        let dir = try makeTempStoreDirectory()
        let first = LayoutStoreActor(storeDirectory: dir)
        let second = LayoutStoreActor(storeDirectory: dir)

        // 第一实例持锁 → singleWriter；第二实例锁被占 → lastWriterWins
        let firstLoad = await first.load()
        XCTAssertEqual(firstLoad, .firstLaunch)
        let firstMode = await first.lockMode()
        XCTAssertEqual(firstMode, .singleWriter)
        let secondLoad = await second.load()
        XCTAssertEqual(secondLoad, .firstLaunch)
        let secondMode = await second.lockMode()
        XCTAssertEqual(secondMode, .lastWriterWins)

        // 第一实例落盘 gen 1
        await first.enqueue(makeLayout(generation: 1))
        _ = await first.flush()
        XCTAssertEqual(maxPersistedLayoutGeneration(in: dir), 1)

        // 第二实例同代 → stale 拒绝（计数递增）
        await second.enqueue(makeLayout(generation: 1))
        _ = await second.flush()
        let rejections = await second.staleRejectionCount()
        XCTAssertEqual(rejections, 1)

        // 第二实例更高代 → last-writer-wins 落盘
        await second.enqueue(makeLayout(generation: 2))
        _ = await second.flush()
        XCTAssertEqual(maxPersistedLayoutGeneration(in: dir), 2)
        let rejectionsAfter = await second.staleRejectionCount()
        XCTAssertEqual(rejectionsAfter, 1)
    }
}

// MARK: - 故障注入 IO（写失败模拟：权限拒绝/磁盘满）

/// 包装 FileManagerLayoutStoreIO，可切换写失败（线程安全）。
private final class FaultInjectingIO: LayoutStoreIO, @unchecked Sendable {
    private let real = FileManagerLayoutStoreIO()
    private let lock = NSLock()
    private var failWritesFlag = false

    var failWrites: Bool {
        get { lock.lock(); defer { lock.unlock() }; return failWritesFlag }
        set { lock.lock(); defer { lock.unlock() }; failWritesFlag = newValue }
    }

    func createDirectoryIfNeeded(at url: URL) async throws {
        try await real.createDirectoryIfNeeded(at: url)
    }

    func writeFile(_ data: Data, to url: URL) async throws {
        if failWrites { throw LayoutStoreIOError.writeFailed }
        try await real.writeFile(data, to: url)
    }

    func replaceFile(at source: URL, with destination: URL) async throws {
        try await real.replaceFile(at: source, with: destination)
    }

    func readFile(at url: URL) async -> Data? {
        await real.readFile(at: url)
    }

    func removeFileIfExists(at url: URL) async {
        await real.removeFileIfExists(at: url)
    }

    func moveFile(from source: URL, to destination: URL) async throws {
        try await real.moveFile(from: source, to: destination)
    }

    func fileExists(at url: URL) async -> Bool {
        await real.fileExists(at: url)
    }

    func contentsOfDirectory(at url: URL) async -> [URL] {
        await real.contentsOfDirectory(at: url)
    }

    func acquireLock(at url: URL) async throws -> LayoutStoreLock? {
        try await real.acquireLock(at: url)
    }

    func fsyncDirectory(at url: URL) async {
        await real.fsyncDirectory(at: url)
    }
}
