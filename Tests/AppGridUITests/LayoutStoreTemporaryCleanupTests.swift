import Foundation
import XCTest
@testable import AppGridUI

/// Every on-disk entry belongs to a unique synthetic sandbox. The sibling
/// sentinel directory represents data outside the journal, never real user data.
final class LayoutStoreTemporaryCleanupTests: XCTestCase {
    private let temporaryNames = ["workspace-layout-v1-a.json.tmp", "workspace-layout-v1-b.json.tmp"]
    private var sandboxes: [URL] = []

    override func tearDownWithError() throws {
        for sandbox in sandboxes {
            try FileManager.default.removeItem(at: sandbox)
        }
        sandboxes.removeAll()
        try super.tearDownWithError()
    }

    func testLoadCleansOnlyExactOwnedRegularFilesWithLock() async throws {
        let fixture = try makeFixture()
        let unrelated = try seedUnrelatedEntries(in: fixture.store)
        for url in temporaryURLs(in: fixture.store) {
            try Data("interrupted journal".utf8).write(to: url)
        }
        let io = TemporaryCleanupIO()
        let store = LayoutStoreActor(storeDirectory: fixture.store, io: io)

        let result = await store.load()

        XCTAssertEqual(result, .firstLaunch)
        try assertUnrelatedEntriesPreserved(unrelated)
        for url in temporaryURLs(in: fixture.store) {
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
        let removals = await io.removals
        let enumerations = await io.directoryEnumerations
        let mode = await store.lockMode()
        XCTAssertEqual(removals.map(\.standardizedFileURL.path),
                       temporaryURLs(in: fixture.store).map(\.standardizedFileURL.path))
        XCTAssertEqual(enumerations, 0)
        XCTAssertEqual(mode, .singleWriter)
    }

    func testLoadPreservesRecognizedSymlinksAndDirectoriesIncludingOutsideSentinels() async throws {
        // Exercise both recognized names as symlinks, to a file and a directory.
        for symlinkIndex in temporaryNames.indices {
            let fixture = try makeFixture()
            let protected = try seedProtectedEntries(fixture, symlinkIndex: symlinkIndex)
            let store = LayoutStoreActor(storeDirectory: fixture.store)

            let result = await store.load()

            XCTAssertEqual(result, .firstLaunch)
            try assertProtectedEntriesPreserved(protected)
            let mode = await store.lockMode()
            XCTAssertEqual(mode, .singleWriter)
        }
    }

    func testResetCleansOnlyExactOwnedRegularFilesWithLock() async throws {
        let fixture = try makeFixture()
        let io = TemporaryCleanupIO()
        let store = LayoutStoreActor(storeDirectory: fixture.store, io: io)
        _ = await store.load()
        await io.clearCleanupObservations()
        let unrelated = try seedUnrelatedEntries(in: fixture.store)
        for url in temporaryURLs(in: fixture.store) {
            try Data("interrupted journal".utf8).write(to: url)
        }

        let result = await store.reset(defaultLayout: emptyLayout())

        XCTAssertEqual(result, .reset(writeGeneration: 1))
        try assertUnrelatedEntriesPreserved(unrelated)
        for url in temporaryURLs(in: fixture.store) {
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        }
        let removals = await io.removals
        let enumerations = await io.directoryEnumerations
        XCTAssertEqual(removals.map(\.standardizedFileURL.path),
                       temporaryURLs(in: fixture.store).map(\.standardizedFileURL.path))
        XCTAssertEqual(enumerations, 0)
        let slot = fixture.store.appendingPathComponent("workspace-layout-v1-a.json")
        guard case .valid(let decoded) = LayoutStoreCodec.decode(try Data(contentsOf: slot)) else {
            return XCTFail("Reset should preserve ordinary journal encoding")
        }
        XCTAssertEqual(decoded.layout, emptyLayout())
        XCTAssertEqual(decoded.writeGeneration, 1)
    }

    func testResetCleanupPreservesRecognizedSymlinkAndDirectory() async throws {
        let fixture = try makeFixture()
        // Stop after cleanup: the existing write path is intentionally outside
        // this test's scope and must not write through the synthetic symlink.
        let io = TemporaryCleanupIO(rejectWrites: true)
        let store = LayoutStoreActor(storeDirectory: fixture.store, io: io)
        _ = await store.load()
        await io.clearCleanupObservations()
        let protected = try seedProtectedEntries(fixture, symlinkIndex: 0)

        let result = await store.reset(defaultLayout: emptyLayout())

        XCTAssertEqual(result, .failed)
        try assertProtectedEntriesPreserved(protected)
        let removals = await io.removals
        let writes = await io.writeAttempts
        let enumerations = await io.directoryEnumerations
        XCTAssertEqual(removals.map(\.standardizedFileURL.path),
                       temporaryURLs(in: fixture.store).map(\.standardizedFileURL.path))
        XCTAssertEqual(writes, 1)
        XCTAssertEqual(enumerations, 0)
    }

    func testNoLockPeerDoesNotCleanDuringLoadOrReset() async throws {
        let fixture = try makeFixture()
        let owner = LayoutStoreActor(storeDirectory: fixture.store)
        _ = await owner.load()
        let io = TemporaryCleanupIO(rejectWrites: true)
        let peer = LayoutStoreActor(storeDirectory: fixture.store, io: io)
        let unrelated = try seedUnrelatedEntries(in: fixture.store)
        let bytes = Data("owner's in-flight temporary bytes".utf8)
        for url in temporaryURLs(in: fixture.store) { try bytes.write(to: url) }

        let loaded = await peer.load()
        let peerMode = await peer.lockMode()
        let reset = await peer.reset(defaultLayout: emptyLayout())

        XCTAssertEqual(loaded, .firstLaunch)
        XCTAssertEqual(peerMode, .lastWriterWins)
        XCTAssertEqual(reset, .failed)
        for url in temporaryURLs(in: fixture.store) {
            XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
        try assertUnrelatedEntriesPreserved(unrelated)
        let removals = await io.removals
        let enumerations = await io.directoryEnumerations
        XCTAssertTrue(removals.isEmpty)
        XCTAssertEqual(enumerations, 0)
        // Keep the owner's real flock alive through every peer operation.
        let ownerMode = await owner.lockMode()
        XCTAssertEqual(ownerMode, .singleWriter)
    }

    func testLockFailureDoesNotCleanDuringLoadOrReset() async throws {
        let fixture = try makeFixture()
        let io = TemporaryCleanupIO(rejectWrites: true, failLock: true)
        let store = LayoutStoreActor(storeDirectory: fixture.store, io: io)
        let bytes = Data("unclaimed temporary bytes".utf8)
        for url in temporaryURLs(in: fixture.store) { try bytes.write(to: url) }

        _ = await store.load()
        let reset = await store.reset(defaultLayout: emptyLayout())

        XCTAssertEqual(reset, .failed)
        for url in temporaryURLs(in: fixture.store) {
            XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
        let removals = await io.removals
        let enumerations = await io.directoryEnumerations
        let mode = await store.lockMode()
        XCTAssertTrue(removals.isEmpty)
        XCTAssertEqual(enumerations, 0)
        XCTAssertEqual(mode, .lastWriterWins)
    }

    func testProductionRemovalPreservesUnrelatedNamesAndDanglingSymlink() async throws {
        let fixture = try makeFixture()
        let unrelated = try seedUnrelatedEntries(in: fixture.store)
        let link = temporaryURLs(in: fixture.store)[0]
        let missingTarget = fixture.outside.appendingPathComponent("missing")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: missingTarget)
        let io = FileManagerLayoutStoreIO()

        for url in [unrelated.file, unrelated.directory, unrelated.nearMatch, link] {
            await io.removeFileIfExists(at: url)
        }

        try assertUnrelatedEntriesPreserved(unrelated)
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path), missingTarget.path)
    }

    func testProductionRemovalDoesNotFollowSymlinkedStoreDirectory() async throws {
        let fixture = try makeFixture()
        let bytes = Data("outside journal".utf8)
        let target = fixture.outside.appendingPathComponent(temporaryNames[0])
        try bytes.write(to: target)
        let link = fixture.store.appendingPathComponent("linked-store", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: fixture.outside)

        await FileManagerLayoutStoreIO().removeFileIfExists(at: link.appendingPathComponent(temporaryNames[0]))

        XCTAssertEqual(try Data(contentsOf: target), bytes)
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path), fixture.outside.path)
    }

    private struct Fixture {
        let store: URL
        let outside: URL
    }

    private struct UnrelatedEntries {
        let file: URL
        let directory: URL
        let sentinel: URL
        let nearMatch: URL
    }

    private struct ProtectedEntries {
        let link: URL
        let target: URL
        let outsideSentinel: URL
        let directorySentinel: URL
    }

    private func makeFixture() throws -> Fixture {
        let sandbox = FileManager.default.temporaryDirectory
            .appendingPathComponent("layout-cleanup-tests-\(UUID().uuidString)", isDirectory: true)
        // Record only the unique owned child, never the shared temporary root.
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: false)
        sandboxes.append(sandbox)
        let store = sandbox.appendingPathComponent("store", isDirectory: true)
        let outside = sandbox.appendingPathComponent("outside", isDirectory: true)
        for directory in [store, outside] {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        }
        return Fixture(store: store, outside: outside)
    }

    private func temporaryURLs(in directory: URL) -> [URL] {
        temporaryNames.map { directory.appendingPathComponent($0) }
    }

    private func emptyLayout() -> PersistentWorkspaceLayout {
        PersistentWorkspaceLayout(generation: LayoutGeneration(0), topLevelOrder: [], folders: [])
    }

    private func seedUnrelatedEntries(in directory: URL) throws -> UnrelatedEntries {
        let file = directory.appendingPathComponent("unrelated.tmp")
        let folder = directory.appendingPathComponent("unrelated-directory.tmp", isDirectory: true)
        let sentinel = folder.appendingPathComponent("sentinel")
        let nearMatch = directory.appendingPathComponent("workspace-layout-v1-c.json.tmp")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        for url in [file, sentinel, nearMatch] { try Data("keep".utf8).write(to: url) }
        return UnrelatedEntries(file: file, directory: folder, sentinel: sentinel, nearMatch: nearMatch)
    }

    private func assertUnrelatedEntriesPreserved(_ entries: UnrelatedEntries) throws {
        for url in [entries.file, entries.sentinel, entries.nearMatch] {
            XCTAssertEqual(try Data(contentsOf: url), Data("keep".utf8))
        }
    }

    private func seedProtectedEntries(_ fixture: Fixture, symlinkIndex: Int) throws -> ProtectedEntries {
        let urls = temporaryURLs(in: fixture.store)
        let outsideSentinel = fixture.outside.appendingPathComponent("sentinel")
        try Data("outside sentinel".utf8).write(to: outsideSentinel)
        let target = symlinkIndex == 0 ? outsideSentinel : fixture.outside
        try FileManager.default.createSymbolicLink(at: urls[symlinkIndex], withDestinationURL: target)
        let directory = urls[1 - symlinkIndex]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let directorySentinel = directory.appendingPathComponent("sentinel")
        try Data("directory sentinel".utf8).write(to: directorySentinel)
        return ProtectedEntries(link: urls[symlinkIndex], target: target,
                                outsideSentinel: outsideSentinel, directorySentinel: directorySentinel)
    }

    private func assertProtectedEntriesPreserved(_ entries: ProtectedEntries) throws {
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: entries.link.path), entries.target.path)
        XCTAssertEqual(try Data(contentsOf: entries.outsideSentinel), Data("outside sentinel".utf8))
        XCTAssertEqual(try Data(contentsOf: entries.directorySentinel), Data("directory sentinel".utf8))
    }
}

/// Observe actor cleanup boundaries while using production filesystem behavior.
/// Rejected writes let reset cleanup be checked without exercising its write path.
private actor TemporaryCleanupIO: LayoutStoreIO {
    private let real = FileManagerLayoutStoreIO()
    private let rejectWrites: Bool
    private let failLock: Bool
    private(set) var removals: [URL] = []
    private(set) var directoryEnumerations = 0
    private(set) var writeAttempts = 0

    init(rejectWrites: Bool = false, failLock: Bool = false) {
        self.rejectWrites = rejectWrites
        self.failLock = failLock
    }

    func clearCleanupObservations() {
        removals.removeAll()
        directoryEnumerations = 0
    }

    func createDirectoryIfNeeded(at url: URL) async throws {
        try await real.createDirectoryIfNeeded(at: url)
    }

    func writeFile(_ data: Data, to url: URL) async throws {
        writeAttempts += 1
        if rejectWrites { throw LayoutStoreIOError.writeFailed }
        try await real.writeFile(data, to: url)
    }

    func replaceFile(at source: URL, with destination: URL) async throws {
        try await real.replaceFile(at: source, with: destination)
    }

    func readFile(at url: URL) async -> Data? { await real.readFile(at: url) }

    func removeFileIfExists(at url: URL) async {
        removals.append(url)
        await real.removeFileIfExists(at: url)
    }

    func moveFile(from source: URL, to destination: URL) async throws {
        try await real.moveFile(from: source, to: destination)
    }

    func fileExists(at url: URL) async -> Bool { await real.fileExists(at: url) }

    func contentsOfDirectory(at url: URL) async -> [URL] {
        directoryEnumerations += 1
        return await real.contentsOfDirectory(at: url)
    }

    func acquireLock(at url: URL) async throws -> LayoutStoreLock? {
        if failLock { throw LayoutStoreIOError.lockFailed }
        return try await real.acquireLock(at: url)
    }

    func fsyncDirectory(at url: URL) async { await real.fsyncDirectory(at: url) }
}
