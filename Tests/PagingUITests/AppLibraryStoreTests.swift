import AppGridUI
import Darwin
import Foundation
import XCTest
@testable import PagingPrototypeApp

private final class LibraryMemoryIO: AppLibraryFileIO, @unchecked Sendable {
    private let lock = NSLock()
    private var bytes: Data?
    private var writes = 0
    private var failWrites = false
    private var failAfterReplacementOnce = false
    init(_ bytes: Data? = nil, failWrites: Bool = false, failAfterReplacementOnce: Bool = false) {
        self.bytes = bytes
        self.failWrites = failWrites
        self.failAfterReplacementOnce = failAfterReplacementOnce
    }
    func read(maximumBytes: Int) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        return bytes.map { Data($0.prefix(maximumBytes + 1)) }
    }
    func replaceAtomically(_ data: Data, expecting expected: Data?) throws {
        lock.lock(); defer { lock.unlock() }
        guard bytes == expected else { throw AppLibraryFileError.unavailable }
        if failWrites { throw AppLibraryFileError.unavailable }
        bytes = data
        writes += 1
        if failAfterReplacementOnce {
            failAfterReplacementOnce = false
            throw AppLibraryFileError.unavailable
        }
    }
    var writeCount: Int { lock.lock(); defer { lock.unlock() }; return writes }
}

final class AppLibraryStoreTests: XCTestCase {
    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("LibraryTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        // Foundation may intentionally spell /private/var as /var again; use the
        // descriptor-level canonical path for the no-follow traversal fixture.
        let resolved = root.withUnsafeFileSystemRepresentation { path -> UnsafeMutablePointer<CChar>? in
            guard let path else { return nil }
            return realpath(path, nil)
        }
        let canonical = try XCTUnwrap(resolved)
        defer { free(canonical) }
        return URL(fileURLWithPath: String(cString: canonical), isDirectory: true)
    }

    func testMissingInspectionDoesNotCreateDirectoryOrFile() async throws {
        let root = try temporaryRoot().appendingPathComponent("not-created")
        let store = AppLibraryFileStore(fileURL: root.appendingPathComponent("preferences.json"))
        let result = await store.load()
        XCTAssertEqual(result, .missing)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    func testLocalAtomicRoundTripRetainsDormantOverridesAndPrivatePermissions() async throws {
        let root = try temporaryRoot().appendingPathComponent("Library")
        let file = root.appendingPathComponent("preferences.json")
        let preferences = AppLibraryPreferences(enabled: true, categoryOverrides: ["bundle:absent.fixture": .music])
        let store = AppLibraryFileStore(fileURL: file)
        let saved = await store.save(preferences)
        XCTAssertEqual(saved, .saved)
        let freshStore = AppLibraryFileStore(fileURL: file)
        let loaded = await freshStore.load()
        XCTAssertEqual(loaded, .loaded(preferences))
        let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: root.path)), ["preferences.json", ".library.lock"])
        // A new actor and file round trip is not a physical app-restart acceptance.
    }

    func testFutureAndAmbiguousVersionsProtectExactOriginalBytes() async throws {
        let fixtures = [
            #"{"schemaVersion":2,"future":true}"#,
            #"{"schemaVersion":9999999999999999999999999999999999999999999999999}"#,
            #"{"schemaVersion":1,"schemaVersion":2,"preferences":{"enabled":false,"categoryOverrides":{}}}"#,
            #"{"schemaVersion":1,"schema\u0056ersion":2,"preferences":{"enabled":false,"categoryOverrides":{}}}"#,
            #"{"schema\u0056ersion":2,"future":true}"#
        ]
        for fixture in fixtures {
            let original = Data(fixture.utf8)
            let io = LibraryMemoryIO(original)
            let store = AppLibraryFileStore(io: io)
            let result = await store.save(.init(enabled: true), recoveringCorruptPayload: true)
            XCTAssertEqual(result, .protectedPayload)
            XCTAssertEqual(try io.read(maximumBytes: AppLibraryFileStore.maximumPayloadBytes), original)
            XCTAssertEqual(io.writeCount, 0)
        }
    }

    func testCorruptRecoveryIsExplicitAndLoadingNeverWrites() async {
        let io = LibraryMemoryIO(Data("{broken".utf8))
        let store = AppLibraryFileStore(io: io)
        let loaded = await store.load()
        XCTAssertEqual(loaded, .corrupt)
        XCTAssertEqual(io.writeCount, 0)
        let rejected = await store.save(.init(enabled: true))
        XCTAssertEqual(rejected, .recoveryRequired)
        let recovered = await store.save(.init(enabled: true), recoveringCorruptPayload: true)
        XCTAssertEqual(recovered, .saved)
        XCTAssertEqual(io.writeCount, 1)
    }

    func testOversizedReadAndWriteFailureStaySeparate() async {
        let io = LibraryMemoryIO(Data(repeating: 32, count: AppLibraryFileStore.maximumPayloadBytes + 2))
        let store = AppLibraryFileStore(io: io)
        let loaded = await store.load()
        XCTAssertEqual(loaded, .oversized)
        let rejected = await store.save(.default, recoveringCorruptPayload: true)
        XCTAssertEqual(rejected, .protectedPayload)
        XCTAssertEqual(io.writeCount, 0)
        let failing = AppLibraryFileStore(io: LibraryMemoryIO(nil, failWrites: true))
        let failure = await failing.save(.init(enabled: true))
        XCTAssertEqual(failure, .failed)
    }

    func testInvalidPreferencesNeverWrite() async {
        let io = LibraryMemoryIO()
        let store = AppLibraryFileStore(io: io)
        let rejected = await store.save(.init(enabled: true, categoryOverrides: ["invalid": .music]))
        XCTAssertEqual(rejected, .invalidPreferences)
        XCTAssertEqual(io.writeCount, 0)
    }

    func testSymbolicLinkAndFIFOAreRejectedWithoutOpeningAStream() async throws {
        let root = try temporaryRoot()
        let original = root.appendingPathComponent("original")
        try Data("keep".utf8).write(to: original)
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: original)
        let fifo = root.appendingPathComponent("fifo")
        let status = fifo.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }
            return mkfifo(path, 0o600)
        }
        XCTAssertEqual(status, 0)
        for file in [alias, fifo] {
            let store = AppLibraryFileStore(fileURL: file)
            let loaded = await store.load()
            XCTAssertEqual(loaded, .unavailable)
            let rejected = await store.save(.default, recoveringCorruptPayload: true)
            XCTAssertEqual(rejected, .unavailable)
        }
        XCTAssertEqual(try Data(contentsOf: original), Data("keep".utf8))
    }

    func testEscapedValidHeaderAndHeaderLikeNestedTextAreNotFalseDuplicates() {
        let json = #"{"schema\u0056ersion":1,"preferences":{"enabled":true,"categoryOverrides":{"bundle:schemaVersion": "music"}}}"#
        XCTAssertEqual(AppLibraryFileStore.decode(Data(json.utf8)),
                       .loaded(.init(enabled: true, categoryOverrides: ["bundle:schemaVersion": .music])))
    }

    func testDuplicatePreferenceKeysProtectBytesEvenDuringExplicitRecovery() async throws {
        let fixtures = [
            #"{"schemaVersion":1,"preferences":{"enabled":true,"categoryOverrides":{}},"preferences":{"enabled":false,"categoryOverrides":{}}}"#,
            #"{"schemaVersion":1,"preferences":{"enabled":true,"enabled":false,"categoryOverrides":{}}}"#,
            #"{"schemaVersion":1,"preferences":{"enabled":true,"enabl\u0065d":false,"categoryOverrides":{}}}"#,
            #"{"schemaVersion":1,"preferences":{"enabled":true,"categoryOverrides":{"bundle:fixture":"music","bundle:fixture":"video"}}}"#,
            #"{"schemaVersion":1,"preferences":{"enabled":true,"categoryOverrides":{"bundle:fixture":"music","bundle:fixtur\u0065":"video"}}}"#
        ]
        for fixture in fixtures {
            let original = Data(fixture.utf8)
            let io = LibraryMemoryIO(original)
            let store = AppLibraryFileStore(io: io)
            let result = await store.save(.default, recoveringCorruptPayload: true)
            XCTAssertEqual(result, .protectedPayload)
            XCTAssertEqual(try io.read(maximumBytes: 1_048_576), original)
            XCTAssertEqual(io.writeCount, 0)
        }
    }

    func testChangedProtectedTargetIsRejectedAtCommitAndRetained() throws {
        let directory = try temporaryRoot()
        let file = directory.appendingPathComponent("preferences.json")
        let old = Data(#"{"schemaVersion":1,"preferences":{"enabled":false,"categoryOverrides":{}}}"#.utf8)
        let future = Data(#"{"schemaVersion":9,"future":true}"#.utf8)
        try old.write(to: file)
        let io = LocalAppLibraryFileIO(fileURL: file, beforeReplacement: { try future.write(to: file) })
        XCTAssertThrowsError(try io.replaceAtomically(old, expecting: old))
        XCTAssertEqual(try Data(contentsOf: file), future)
    }

    func testAncestorSwapCannotRedirectCommitIntoSubstitutedDirectory() throws {
        let root = try temporaryRoot()
        let directory = root.appendingPathComponent("Library")
        let archived = root.appendingPathComponent("Archived")
        let other = root.appendingPathComponent("Other")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("preferences.json")
        let old = Data("old".utf8), preserved = Data("other-preserved".utf8)
        try old.write(to: file)
        try preserved.write(to: other.appendingPathComponent("preferences.json"))
        let io = LocalAppLibraryFileIO(fileURL: file, beforeReplacement: {
            try FileManager.default.moveItem(at: directory, to: archived)
            try FileManager.default.createSymbolicLink(at: directory, withDestinationURL: other)
        })
        XCTAssertThrowsError(try io.replaceAtomically(Data("new".utf8), expecting: old))
        XCTAssertEqual(try Data(contentsOf: other.appendingPathComponent("preferences.json")), preserved)
        XCTAssertEqual(try Data(contentsOf: archived.appendingPathComponent("preferences.json")), old)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: archived.path).contains { $0.hasPrefix(".library-write-") })
    }

    func testCooperatingExclusiveLockRejectsSecondWriter() throws {
        let directory = try temporaryRoot()
        let file = directory.appendingPathComponent("preferences.json")
        let lock = Darwin.open(directory.appendingPathComponent(".library.lock").path, O_CREAT | O_RDWR, 0o600)
        XCTAssertGreaterThanOrEqual(lock, 0)
        defer { Darwin.close(lock) }
        XCTAssertEqual(flock(lock, LOCK_EX | LOCK_NB), 0)
        let io = LocalAppLibraryFileIO(fileURL: file)
        XCTAssertThrowsError(try io.replaceAtomically(Data("new".utf8), expecting: nil))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(flock(lock, LOCK_UN), 0)
        try io.replaceAtomically(Data("new".utf8), expecting: nil)
        XCTAssertEqual(try Data(contentsOf: file), Data("new".utf8))
    }

    func testEqualRetryCompletesWriteAfterIndeterminatePostReplacementFailure() async {
        let io = LibraryMemoryIO(nil, failAfterReplacementOnce: true)
        let store = AppLibraryFileStore(io: io)
        let draft = AppLibraryPreferences(enabled: true)
        let failed = await store.save(draft)
        XCTAssertEqual(failed, .failed)
        let visibleButUnacknowledged = await store.load()
        XCTAssertEqual(visibleButUnacknowledged, .loaded(draft))
        let retried = await store.save(draft)
        XCTAssertEqual(retried, .saved)
        XCTAssertEqual(io.writeCount, 2, "Equal content must not bypass the incomplete flush obligation")
    }
}
