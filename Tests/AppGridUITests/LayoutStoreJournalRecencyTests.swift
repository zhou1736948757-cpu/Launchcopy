import AppCatalogCore
import Foundation
import XCTest
@testable import AppGridUI

final class LayoutStoreJournalRecencyTests: XCTestCase {
    private var tempRoots: [URL] = []

    override func tearDown() {
        for root in tempRoots {
            try? FileManager.default.removeItem(at: root)
        }
        tempRoots = []
        super.tearDown()
    }

    func testFreshStoreRestoresSecondOfTwoCompletedSaves() async throws {
        let directory = try makeTempDirectory()
        let first = makeLayout(generation: 1)
        let second = makeLayout(generation: 2, withFolder: true)
        await persistTwoLayouts(in: directory, first: first, second: second)

        let firstData = try encode(first, writeGeneration: 1)
        let secondData = try encode(second, writeGeneration: 2)
        // Establish that both saves completed and the writer rotated from A to B.
        XCTAssertEqual(LayoutStoreCodec.decode(try Data(contentsOf: slotURL("a", in: directory))),
                       .valid(DecodedLayout(layout: first, writeGeneration: 1)))
        XCTAssertEqual(LayoutStoreCodec.decode(try Data(contentsOf: slotURL("b", in: directory))),
                       .valid(DecodedLayout(layout: second, writeGeneration: 2)))

        let fresh = LayoutStoreActor(storeDirectory: directory)
        let result = await fresh.load()
        XCTAssertEqual(result, .loaded(second, writeGeneration: 2))
        let state = await fresh.currentState()
        XCTAssertEqual(state, .healthy)
        try assertJournalUnchanged(in: directory, a: firstData, b: secondData)
    }

    func testTwoValidSlotsSelectNewerAEvenWithLowerLayoutGeneration() async throws {
        let a = makeLayout(generation: 1, withFolder: true)
        let b = makeLayout(generation: 900)
        try await assertLoad(a: encode(a, writeGeneration: 42),
                             b: encode(b, writeGeneration: 41),
                             expected: .loaded(a, writeGeneration: 42))
    }

    func testTwoValidSlotsSelectNewerBEvenWithLowerLayoutGeneration() async throws {
        let a = makeLayout(generation: 900)
        let b = makeLayout(generation: 1, withFolder: true)
        try await assertLoad(a: encode(a, writeGeneration: 41),
                             b: encode(b, writeGeneration: 42),
                             expected: .loaded(b, writeGeneration: 42))
    }

    func testEqualWriteGenerationsDeterministicallySelectA() async throws {
        let a = makeLayout(generation: 1, withFolder: true)
        let b = makeLayout(generation: 900)
        try await assertLoad(a: encode(a, writeGeneration: 42),
                             b: encode(b, writeGeneration: 42),
                             expected: .loaded(a, writeGeneration: 42))
    }

    func testFutureVersionInAProtectsStoreDespiteNewerValidB() async throws {
        try await assertLoad(a: futureVersionData(),
                             b: encode(makeLayout(generation: 900), writeGeneration: 900),
                             expected: .readOnlyProtection(.unknownFutureVersion(99)))
    }

    func testFutureVersionInBProtectsStoreDespiteNewerValidA() async throws {
        try await assertLoad(a: encode(makeLayout(generation: 900), writeGeneration: 900),
                             b: futureVersionData(),
                             expected: .readOnlyProtection(.unknownFutureVersion(99)))
    }

    func testOverLimitAProtectsStoreDespiteValidB() async throws {
        try await assertLoad(a: Data(repeating: 0x20, count: LayoutStoreCodec.maxFileBytes + 1),
                             b: encode(makeLayout(generation: 900), writeGeneration: 900),
                             expected: .readOnlyProtection(.exceedsLimits))
    }

    func testOverLimitBProtectsStoreDespiteValidA() async throws {
        try await assertLoad(a: encode(makeLayout(generation: 900), writeGeneration: 900),
                             b: Data(repeating: 0x20, count: LayoutStoreCodec.maxFileBytes + 1),
                             expected: .readOnlyProtection(.exceedsLimits))
    }

    func testCorruptAStillLoadsValidBFromBackupAndPreservesCorruptBytes() async throws {
        let b = makeLayout(generation: 2, withFolder: true)
        try await assertLoad(a: Data("corrupt journal fixture".utf8),
                             b: encode(b, writeGeneration: 42),
                             expected: .loadedFromBackup(b, writeGeneration: 42))
    }

    func testCorruptBStillLoadsValidAAndPreservesCorruptBytes() async throws {
        let a = makeLayout(generation: 2, withFolder: true)
        try await assertLoad(a: encode(a, writeGeneration: 42),
                             b: Data("corrupt journal fixture".utf8),
                             expected: .loaded(a, writeGeneration: 42))
    }

    func testAbsentAStillLoadsValidBNormally() async throws {
        let b = makeLayout(generation: 2, withFolder: true)
        try await assertLoad(a: nil, b: encode(b, writeGeneration: 42),
                             expected: .loaded(b, writeGeneration: 42))
    }

    func testAbsentBStillLoadsValidANormally() async throws {
        let a = makeLayout(generation: 2, withFolder: true)
        try await assertLoad(a: encode(a, writeGeneration: 42), b: nil,
                             expected: .loaded(a, writeGeneration: 42))
    }

    private func makeTempDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("layout-journal-recency-tests-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        tempRoots.append(directory)
        return directory
    }

    private func slotURL(_ slot: String, in directory: URL) -> URL {
        directory.appendingPathComponent("workspace-layout-v1-\(slot).json")
    }

    private func makeLayout(generation: UInt64, withFolder: Bool = false) -> PersistentWorkspaceLayout {
        let alpha = PersistentAppReference.bundleID("fixture.alpha")
        let beta = PersistentAppReference.bundleID("fixture.beta")
        if withFolder {
            let id = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
            return PersistentWorkspaceLayout(
                generation: LayoutGeneration(generation),
                topLevelOrder: [.folder(id)],
                folders: [PersistentFolderRecord(id: id, title: "Group 1", members: [beta, alpha])])
        }
        return PersistentWorkspaceLayout(
            generation: LayoutGeneration(generation),
            topLevelOrder: [.app(alpha), .app(beta)],
            folders: [])
    }

    private func encode(_ layout: PersistentWorkspaceLayout, writeGeneration: UInt64) throws -> Data {
        try LayoutStoreCodec.encode(layout, writeGeneration: writeGeneration)
    }

    private func futureVersionData() throws -> Data {
        let data = try encode(makeLayout(generation: 1), writeGeneration: 1)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        // Decode recognizes future versions before checking the current schema's checksum.
        json["schemaVersion"] = 99
        let future = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        XCTAssertEqual(LayoutStoreCodec.decode(future), .unknownFutureVersion(99))
        return future
    }

    private func persistTwoLayouts(in directory: URL,
                                   first: PersistentWorkspaceLayout,
                                   second: PersistentWorkspaceLayout) async {
        let writer = LayoutStoreActor(storeDirectory: directory)
        let initial = await writer.load()
        XCTAssertEqual(initial, .firstLaunch)
        await writer.enqueue(first)
        let firstFlush = await writer.flush()
        XCTAssertEqual(firstFlush, .nothingPending)
        await writer.enqueue(second)
        let secondFlush = await writer.flush()
        XCTAssertEqual(secondFlush, .nothingPending)
    }

    private func assertLoad(a: Data?, b: Data?, expected: LayoutStoreLoadResult,
                            file: StaticString = #filePath, line: UInt = #line) async throws {
        let directory = try makeTempDirectory()
        if let a { try a.write(to: slotURL("a", in: directory), options: .atomic) }
        if let b { try b.write(to: slotURL("b", in: directory), options: .atomic) }
        let store = LayoutStoreActor(storeDirectory: directory)
        let result = await store.load()
        XCTAssertEqual(result, expected, file: file, line: line)
        let expectedState: LayoutStoreState
        if case .readOnlyProtection(let reason) = expected {
            expectedState = .readOnlyProtection(reason)
            try assertJournalUnchanged(in: directory, a: a, b: b, file: file, line: line)
            // Protection must persist through enqueue, flush and another load.
            await store.enqueue(makeLayout(generation: 1_000, withFolder: true))
            let flush = await store.flush()
            XCTAssertEqual(flush, .readOnly, file: file, line: line)
        } else {
            expectedState = .healthy
        }
        let state = await store.currentState()
        XCTAssertEqual(state, expectedState, file: file, line: line)
        let repeatedLoad = await store.load()
        XCTAssertEqual(repeatedLoad, expected, file: file, line: line)
        try assertJournalUnchanged(in: directory, a: a, b: b, file: file, line: line)
    }

    private func assertJournalUnchanged(in directory: URL, a: Data?, b: Data?,
                                        file: StaticString = #filePath, line: UInt = #line) throws {
        var expectedNames: Set<String> = []
        for (slot, expectedData) in [("a", a), ("b", b)] {
            let url = slotURL(slot, in: directory)
            if let expectedData {
                expectedNames.insert(url.lastPathComponent)
                XCTAssertEqual(try Data(contentsOf: url), expectedData, file: file, line: line)
            } else {
                XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), file: file, line: line)
            }
        }
        let files = try FileManager.default.contentsOfDirectory(at: directory,
                                                                includingPropertiesForKeys: nil)
        let journalNames = Set(files.map(\.lastPathComponent)).subtracting(["workspace-layout.lock"])
        // No writes, quarantine archives or temp files may accompany a protected/healthy load.
        XCTAssertEqual(journalNames, expectedNames, file: file, line: line)
    }
}
