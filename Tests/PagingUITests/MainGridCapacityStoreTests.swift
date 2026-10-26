import AppGridUI
import Darwin
import Foundation
import XCTest
@testable import PagingPrototypeApp

/// Deterministic failures complement real temporary-directory persistence tests.
private final class CapacityMemoryIO: AppLibraryFileIO, @unchecked Sendable {
    private let lock = NSLock()
    private var bytes: Data?
    private var writes = 0
    private var failAfterReplacementOnce: Bool
    private let failReads: Bool
    private let failWrites: Bool

    init(_ bytes: Data? = nil, failReads: Bool = false, failWrites: Bool = false,
         failAfterReplacementOnce: Bool = false) {
        self.bytes = bytes
        self.failReads = failReads
        self.failWrites = failWrites
        self.failAfterReplacementOnce = failAfterReplacementOnce
    }

    func read(maximumBytes: Int) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        if failReads { throw AppLibraryFileError.unavailable }
        return bytes.map { Data($0.prefix(maximumBytes + 1)) }
    }

    func replaceAtomically(_ data: Data, expecting expected: Data?) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !failWrites, bytes == expected else { throw AppLibraryFileError.unavailable }
        writes += 1
        bytes = data
        if failAfterReplacementOnce {
            failAfterReplacementOnce = false
            throw AppLibraryFileError.unavailable
        }
    }

    func replaceExternally(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        bytes = data
    }

    var writeCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return writes
    }
}

final class MainGridCapacityStoreTests: XCTestCase {
    private let valid = Data(#"{"schemaVersion":1,"capacity":{"columns":5,"rows":7}}"#.utf8)

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("CapacityTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let resolved = root.withUnsafeFileSystemRepresentation { path -> UnsafeMutablePointer<CChar>? in
            guard let path else { return nil }
            return realpath(path, nil)
        }
        let canonical = try XCTUnwrap(resolved)
        defer { free(canonical) }
        return URL(fileURLWithPath: String(cString: canonical), isDirectory: true)
    }

    func testMissingLoadCreatesNothingAndUsesDefault() async throws {
        let directory = try temporaryRoot().appendingPathComponent("Capacity")
        let store = FileMainGridCapacityStore(directory: directory)
        let result = await store.load()
        XCTAssertEqual(result, .missing)
        XCTAssertEqual(result.capacity, .default)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        for result in [MainGridCapacityLoadResult.corrupt, .protectedPayload, .unavailable] {
            XCTAssertEqual(result.capacity, .default)
        }
    }

    func testRealAtomicWriteReloadAndScopedBytes() async throws {
        let root = try temporaryRoot()
        let directory = root.appendingPathComponent("Capacity")
        let siblings = ["workspace.json", "appearance.json"]
        let untouched = Data("unrelated-original-bytes".utf8)
        for name in siblings { try untouched.write(to: root.appendingPathComponent(name)) }
        let capacity = try XCTUnwrap(MainGridCapacity(columns: 8, rows: 8))
        let store = FileMainGridCapacityStore(directory: directory)
        let result = await store.save(capacity)
        XCTAssertEqual(result, .saved)
        let loaded = await FileMainGridCapacityStore(directory: directory).load()
        XCTAssertEqual(loaded, .loaded(capacity))
        let file = directory.appendingPathComponent("capacity.json")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["schemaVersion", "capacity"])
        XCTAssertEqual((json["schemaVersion"] as? NSNumber)?.intValue, 1)
        let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: directory.path)), ["capacity.json", ".library.lock"])
        for name in siblings { XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(name)), untouched) }
        // This verifies real file I/O and a fresh actor, not native app restart.
    }

    func testFutureUnknownAmbiguousAndOverflowEnvelopesAreNeverRepaired() async throws {
        let fixtures = [
            #"{"schemaVersion":2,"capacity":{"columns":5,"rows":7}}"#,
            #"{"schemaVersion":2,"capacity": broken"#,
            #"{"schemaVersion":999999999999999999999999999999999999999999999999999999999999999999999999,"capacity":broken"#,
            #"{"schemaVersion":1e10000,"capacity":broken"#,
            #"{"schemaVersion":1.0,"capacity":{"columns":5,"rows":7}}"#,
            #"{"schemaVersion":0,"capacity":{"columns":5,"rows":7}}"#,
            #"{"schemaVersion":-1,"capacity":{"columns":5,"rows":7}}"#,
            #"{"schemaVersion":"1","capacity":{"columns":5,"rows":7}}"#,
            #"{"schemaVersion":true,"capacity":{"columns":5,"rows":7}}"#,
            #"{"schemaVersion":null,"capacity":{"columns":5,"rows":7}}"#,
            #"{"schemaVersion":1,"schemaVersion":2,"capacity":{"columns":5,"rows":7}}"#,
            #"{"schemaVersion":1,"schema\u0056ersion":2,"capacity":{"columns":5,"rows":7}}"#,
            #"{"schema\u0056ersion":2,"capacity":broken"#,
            #"{"schemaVersion":1,"capacity":{"columns":5,"rows":7},"future":true}"#,
            #"{"schemaVersion":1,"capacity":{"columns":5,"rows":7,"future":true}}"#,
            #"{"schemaVersion":1,"capacity":{"columns":5,"rows":7,"future":broken"#,
            #"{"schemaVersion":1,"capacity":{"columns":5,"rows":7},"capacity":{"columns":3,"rows":3}}"#,
            #"{"schemaVersion":1,"capacity":{"columns":5,"columns":3,"rows":7}}"#,
            #"{"schemaVersion":1,"capacity":{"columns":5,"col\u0075mns":3,"rows":7}}"#
        ]
        for fixture in fixtures {
            let original = Data(fixture.utf8)
            let io = CapacityMemoryIO(original)
            let store = FileMainGridCapacityStore(io: io)
            let loaded = await store.load()
            XCTAssertEqual(loaded, .protectedPayload, fixture)
            for recovery in [false, true] {
                let saved = await store.save(.default, recoveringCorruptPayload: recovery)
                XCTAssertEqual(saved, .protectedPayload, fixture)
            }
            XCTAssertEqual(try io.read(maximumBytes: 16_384), original)
            XCTAssertEqual(io.writeCount, 0)
        }
    }

    func testOversizedAndNonUTF8PayloadsStayProtected() async throws {
        for bytes in [Data(repeating: 32, count: FileMainGridCapacityStore.maximumPayloadBytes + 1),
                      Data([0xFF, 0xFE, 0x00])] {
            let io = CapacityMemoryIO(bytes)
            let store = FileMainGridCapacityStore(io: io)
            let loaded = await store.load()
            XCTAssertEqual(loaded, .protectedPayload)
            let saved = await store.save(.default, recoveringCorruptPayload: true)
            XCTAssertEqual(saved, .protectedPayload)
            XCTAssertEqual(try io.read(maximumBytes: 16_384), bytes)
            XCTAssertEqual(io.writeCount, 0)
        }
    }

    func testSupportedCorruptionRequiresExplicitRecoveryAndRealWrite() async throws {
        let fixtures = [
            "{broken",
            #"{"schemaVersion":1,"capacity": broken"#,
            #"{"schemaVersion":1,"capacity":{"columns":2,"rows":7}}"#,
            #"{"schemaVersion":1,"capacity":{"columns":5,"rows":9}}"#,
            #"{"schemaVersion":1,"capacity":{"columns":9223372036854775807,"rows":9223372036854775807}}"#,
            #"{"schemaVersion":1,"capacity":{"columns":5.5,"rows":7}}"#,
            #"{"schemaVersion":1,"capacity":{"columns":true,"rows":7}}"#,
            #"{"schemaVersion":1,"capacity":{"columns":5}}"#
        ]
        for fixture in fixtures {
            let original = Data(fixture.utf8)
            let io = CapacityMemoryIO(original)
            let store = FileMainGridCapacityStore(io: io)
            let loaded = await store.load()
            XCTAssertEqual(loaded, .corrupt, fixture)
            XCTAssertEqual(io.writeCount, 0)
            let refused = await store.save(.default)
            XCTAssertEqual(refused, .recoveryRequired)
            XCTAssertEqual(try io.read(maximumBytes: 16_384), original)
            let saved = await store.save(.default, recoveringCorruptPayload: true)
            XCTAssertEqual(saved, .saved)
            XCTAssertEqual(io.writeCount, 1)
            let repaired = await store.load()
            XCTAssertEqual(repaired, .loaded(.default))
        }
    }

    func testEscapedSupportedKeysDecodeWithoutFalseProtection() {
        let json = #"{"schema\u0056ersion":1,"cap\u0061city":{"col\u0075mns":3,"r\u006fws":8}}"#
        XCTAssertEqual(FileMainGridCapacityStore.decode(Data(json.utf8)),
                       .loaded(MainGridCapacity(columns: 3, rows: 8)!))
    }

    func testFreshProtectionCheckOverridesPriorSuccessfulLoad() async throws {
        let io = CapacityMemoryIO(valid)
        let store = FileMainGridCapacityStore(io: io)
        let loaded = await store.load()
        XCTAssertEqual(loaded, .loaded(.default))
        let future = Data(#"{"schemaVersion":9,"body":broken"#.utf8)
        io.replaceExternally(future)
        let saved = await store.save(.default, recoveringCorruptPayload: true)
        XCTAssertEqual(saved, .protectedPayload)
        XCTAssertEqual(try io.read(maximumBytes: 16_384), future)
        XCTAssertEqual(io.writeCount, 0)
    }

    func testUnavailableReadAndFailedWriteNeverReportSaved() async {
        let unreadable = FileMainGridCapacityStore(io: CapacityMemoryIO(failReads: true))
        let unavailable = await unreadable.load()
        XCTAssertEqual(unavailable, .unavailable)
        let refused = await unreadable.save(.default, recoveringCorruptPayload: true)
        XCTAssertEqual(refused, .failed)
        let io = CapacityMemoryIO(valid, failWrites: true)
        let store = FileMainGridCapacityStore(io: io)
        let saved = await store.save(MainGridCapacity(columns: 3, rows: 3)!)
        XCTAssertEqual(saved, .failed)
        let unchanged = await store.load()
        XCTAssertEqual(unchanged, .loaded(.default))
        XCTAssertEqual(io.writeCount, 0)
    }

    func testNonDirectoryAncestorAndSymlinkTargetAreUnavailable() async throws {
        let root = try temporaryRoot()
        let blocker = root.appendingPathComponent("not-a-directory")
        let original = Data("preserve".utf8)
        try original.write(to: blocker)
        let blockedStore = FileMainGridCapacityStore(directory: blocker.appendingPathComponent("Capacity"))
        let blockedLoad = await blockedStore.load()
        XCTAssertEqual(blockedLoad, .unavailable)
        let blockedSave = await blockedStore.save(.default, recoveringCorruptPayload: true)
        XCTAssertEqual(blockedSave, .failed)
        XCTAssertEqual(try Data(contentsOf: blocker), original)

        let directory = root.appendingPathComponent("Capacity")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: directory.appendingPathComponent("capacity.json"), withDestinationURL: blocker)
        let linkedStore = FileMainGridCapacityStore(directory: directory)
        let linkedLoad = await linkedStore.load()
        XCTAssertEqual(linkedLoad, .unavailable)
        let linkedSave = await linkedStore.save(.default, recoveringCorruptPayload: true)
        XCTAssertEqual(linkedSave, .failed)
        XCTAssertEqual(try Data(contentsOf: blocker), original)
    }

    func testChangedBaselineAtReplacementPreservesExternalPayload() async throws {
        let directory = try temporaryRoot()
        let file = directory.appendingPathComponent("capacity.json")
        try valid.write(to: file)
        let future = Data(#"{"schemaVersion":9,"body":broken"#.utf8)
        let io = LocalAppLibraryFileIO(fileURL: file, beforeReplacement: { try future.write(to: file) })
        let store = FileMainGridCapacityStore(io: io)
        let saved = await store.save(MainGridCapacity(columns: 8, rows: 8)!)
        XCTAssertEqual(saved, .failed)
        XCTAssertEqual(try Data(contentsOf: file), future)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .contains { $0.hasPrefix(".library-write-") })
    }

    func testAncestorSwapRefusesReplacementIntoAnotherDirectory() async throws {
        let root = try temporaryRoot()
        let directory = root.appendingPathComponent("Capacity")
        let archived = root.appendingPathComponent("Archived")
        let other = root.appendingPathComponent("Other")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("capacity.json")
        try valid.write(to: file)
        let old = valid
        let preserved = Data("other-original".utf8)
        try preserved.write(to: other.appendingPathComponent("capacity.json"))
        let io = LocalAppLibraryFileIO(fileURL: file, beforeReplacement: {
            try FileManager.default.moveItem(at: directory, to: archived)
            try FileManager.default.createSymbolicLink(at: directory, withDestinationURL: other)
        })
        let store = FileMainGridCapacityStore(io: io)
        let saved = await store.save(.default)
        XCTAssertEqual(saved, .failed)
        XCTAssertEqual(try Data(contentsOf: other.appendingPathComponent("capacity.json")), preserved)
        XCTAssertEqual(try Data(contentsOf: archived.appendingPathComponent("capacity.json")), old)
    }

    func testCooperativeWriterLockRefusesConcurrentCommitThenAllowsRetry() async throws {
        let directory = try temporaryRoot()
        let lock = Darwin.open(directory.appendingPathComponent(".library.lock").path, O_CREAT | O_RDWR, 0o600)
        XCTAssertGreaterThanOrEqual(lock, 0)
        guard lock >= 0 else { return }
        defer { Darwin.close(lock) }
        XCTAssertEqual(flock(lock, LOCK_EX | LOCK_NB), 0)
        let store = FileMainGridCapacityStore(directory: directory)
        let refused = await store.save(.default)
        XCTAssertEqual(refused, .failed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("capacity.json").path))
        XCTAssertEqual(flock(lock, LOCK_UN), 0)
        let saved = await store.save(.default)
        XCTAssertEqual(saved, .saved)
    }

    func testEqualRetryWritesAfterIndeterminateFlushFailure() async {
        let io = CapacityMemoryIO(nil, failAfterReplacementOnce: true)
        let store = FileMainGridCapacityStore(io: io)
        let failed = await store.save(.default)
        XCTAssertEqual(failed, .failed)
        let visibleButUnacknowledged = await store.load()
        XCTAssertEqual(visibleButUnacknowledged, .loaded(.default))
        let saved = await store.save(.default)
        XCTAssertEqual(saved, .saved)
        XCTAssertEqual(io.writeCount, 2)
    }
}
