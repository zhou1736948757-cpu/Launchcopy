import AppGridUI
import Darwin
import Foundation
import XCTest
@testable import PagingPrototypeApp

private final class ActivityMemoryIO: AppLibraryFileIO, @unchecked Sendable {
    private let lock = NSLock()
    private var bytes: Data?
    private var writes = 0
    private var reads = 0
    private var requestedBound: Int?
    private let failReads: Bool
    private let failWrites: Bool
    private var failAfterReplacementOnce: Bool

    init(_ bytes: Data? = nil, failReads: Bool = false, failWrites: Bool = false,
         failAfterReplacementOnce: Bool = false) {
        self.bytes = bytes
        self.failReads = failReads
        self.failWrites = failWrites
        self.failAfterReplacementOnce = failAfterReplacementOnce
    }

    func read(maximumBytes: Int) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        reads += 1
        requestedBound = maximumBytes
        if failReads { throw AppLibraryFileError.unavailable }
        return bytes.map { Data($0.prefix(maximumBytes + 1)) }
    }

    func replaceAtomically(_ data: Data, expecting expected: Data?) throws {
        lock.lock(); defer { lock.unlock() }
        guard bytes == expected, !failWrites else { throw AppLibraryFileError.unavailable }
        bytes = data
        writes += 1
        if failAfterReplacementOnce {
            failAfterReplacementOnce = false
            throw AppLibraryFileError.unavailable
        }
    }

    var writeCount: Int { lock.lock(); defer { lock.unlock() }; return writes }
    var readCount: Int { lock.lock(); defer { lock.unlock() }; return reads }
    var lastReadBound: Int? { lock.lock(); defer { lock.unlock() }; return requestedBound }
    var storedBytes: Data? { lock.lock(); defer { lock.unlock() }; return bytes }
}

final class LaunchActivityStoreTests: XCTestCase {
    private let salt = String(repeating: "a", count: 64)

    private struct Envelope: Codable {
        let schemaVersion: Int
        let document: LaunchActivityDocument
    }

    private func bytes(_ document: LaunchActivityDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Envelope(schemaVersion: 1, document: document))
    }

    private func document(at now: Date = Date()) -> LaunchActivityDocument {
        let timestamp = Date(timeIntervalSince1970: floor(now.timeIntervalSince1970))
        let day = Int(floor(timestamp.timeIntervalSince1970 / 86_400))
        return LaunchActivityDocument(enabled: true, salt: salt, entries: [
            "bundle:fixture.activity": .init(lastLaunch: timestamp, dailyCounts: [day: 3])
        ])
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("LaunchActivityTests-" + UUID().uuidString)
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

    func testNonloadedResultsProvideValidDefaultOffDocuments() {
        for result in [LaunchActivityLoadResult.missing, .corrupt, .oversized, .unavailable,
                       .futureVersion, .ambiguousSchema] {
            XCTAssertFalse(result.document.enabled)
            XCTAssertTrue(result.document.entries.isEmpty)
            XCTAssertTrue(result.document.isValid)
        }
        let saved = document()
        XCTAssertEqual(LaunchActivityLoadResult.loaded(saved).document, saved)
    }

    func testMissingLoadDoesNotCreateActivityDirectoryOrFile() async throws {
        let root = try temporaryRoot().appendingPathComponent("uncreated-profile/Activity")
        let store = LaunchActivityFileStore(fileURL: root.appendingPathComponent("activity.json"))
        let loaded = await store.load()
        XCTAssertEqual(loaded, .missing)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
        let io = ActivityMemoryIO()
        let memoryLoaded = await LaunchActivityFileStore(io: io).load()
        XCTAssertEqual(memoryLoaded, .missing)
        XCTAssertEqual(io.writeCount, 0)
        XCTAssertEqual(io.lastReadBound, 1_048_576)
    }

    func testLocalAtomicRoundTripUsesSeparateActivityEnvelopeAndPrivatePermissions() async throws {
        let directory = try temporaryRoot().appendingPathComponent("Activity")
        let file = directory.appendingPathComponent("activity.json")
        let saved = document()
        let store = LaunchActivityFileStore(fileURL: file)
        let receipt = await store.save(saved)
        XCTAssertEqual(receipt, .saved)
        let reloaded = await LaunchActivityFileStore(fileURL: file).load()
        XCTAssertEqual(reloaded, .loaded(saved))
        let payload = try Data(contentsOf: file)
        XCTAssertEqual(LaunchActivityFileStore.decode(payload), .loaded(saved))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        XCTAssertEqual(Set(root.keys), ["schemaVersion", "document"])
        let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o600)
        let directoryPermissions = try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(directoryPermissions?.intValue, 0o700)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.deletingLastPathComponent().appendingPathComponent("Library").path))
        // A fresh actor round trip is not a claim of native process restart acceptance.
    }

    func testLoadPreservesExpiredDocumentForOwnerClockAndReceiptTracking() async throws {
        let old = document(at: Date(timeIntervalSince1970: 86_400))
        let original = try bytes(old)
        XCTAssertEqual(LaunchActivityFileStore.decode(original), .loaded(old))
        let io = ActivityMemoryIO(original)
        let loaded = await LaunchActivityFileStore(io: io).load()
        XCTAssertEqual(loaded, .loaded(old))
        XCTAssertEqual(io.writeCount, 0)
        XCTAssertEqual(io.storedBytes, original)
    }

    func testLoadPreservesFutureRecordsDisabledConsentAndSaltWithoutWriting() async throws {
        var saved = document(at: Date(timeIntervalSince1970: 253_402_300_799))
        saved.enabled = false
        let original = try bytes(saved)
        let io = ActivityMemoryIO(original)
        let loaded = await LaunchActivityFileStore(io: io).load()
        XCTAssertEqual(loaded, .loaded(saved))
        XCTAssertFalse(loaded.document.enabled)
        XCTAssertEqual(loaded.document.salt, saved.salt)
        XCTAssertEqual(io.writeCount, 0)
        XCTAssertEqual(io.storedBytes, original)
    }

    func testMaximumIdentityBucketAndCountDocumentFitsBoundAndRoundTrips() async throws {
        let current = document()
        let timestamp = try XCTUnwrap(current.entries.values.first?.lastLaunch)
        let day = Int(floor(timestamp.timeIntervalSince1970 / 86_400))
        let entry = LaunchActivityEntry(lastLaunch: timestamp,
            dailyCounts: Dictionary(uniqueKeysWithValues: (0..<30).map { (day - $0, 1_000_000) }))
        let saved = LaunchActivityDocument(enabled: true, salt: salt, entries:
            Dictionary(uniqueKeysWithValues: (0..<256).map { ("bundle:fixture.\($0)", entry) }))
        XCTAssertTrue(saved.isValid)
        let encoded = try bytes(saved)
        XCTAssertLessThan(encoded.count, LaunchActivityFileStore.maximumPayloadBytes)
        XCTAssertEqual(LaunchActivityFileStore.decode(encoded), .loaded(saved))
        let io = ActivityMemoryIO()
        let store = LaunchActivityFileStore(io: io)
        let receipt = await store.save(saved)
        XCTAssertEqual(receipt, .saved)
        let loaded = await store.load()
        XCTAssertEqual(loaded, .loaded(saved))
        XCTAssertEqual(io.writeCount, 1, "Loading a maximum-sized supported document must not write")
    }

    func testCorruptionRequiresExplicitRecoveryAndLoadNeverWrites() async {
        let io = ActivityMemoryIO(Data("{broken".utf8))
        let store = LaunchActivityFileStore(io: io)
        let loaded = await store.load()
        XCTAssertEqual(loaded, .corrupt)
        XCTAssertFalse(loaded.document.enabled)
        XCTAssertEqual(io.writeCount, 0)
        let rejected = await store.save(document())
        XCTAssertEqual(rejected, .recoveryRequired)
        XCTAssertEqual(io.writeCount, 0)
        let recovered = await store.save(document(), recoveringCorruptPayload: true)
        XCTAssertEqual(recovered, .saved)
        XCTAssertEqual(io.writeCount, 1)
    }

    func testFutureAndAmbiguousHeadersRemainProtectedEvenWithRecovery() async {
        let fixtures: [(String, LaunchActivityLoadResult)] = [
            (#"{"schemaVersion":2,"future":true}"#, .futureVersion),
            (#"{"schema\u0056ersion":2,"future":true}"#, .futureVersion),
            (#"{"schemaVersion":1e3}"#, .futureVersion),
            (#"{"schemaVersion":999999999999999999999999999999999999999999999999999999999}"#, .futureVersion),
            (#"{"schemaVersion":1e999999}"#, .ambiguousSchema),
            (#"{"schemaVersion":1.0}"#, .ambiguousSchema),
            (#"{"schemaVersion":1,"schemaVersion":2}"#, .ambiguousSchema),
            (#"{"schemaVersion":1,"schema\u0056ersion":2}"#, .ambiguousSchema)
        ]
        for (fixture, expected) in fixtures {
            let original = Data(fixture.utf8)
            XCTAssertEqual(LaunchActivityFileStore.decode(original), expected)
            let io = ActivityMemoryIO(original)
            let store = LaunchActivityFileStore(io: io)
            let receipt = await store.save(document(), recoveringCorruptPayload: true)
            XCTAssertEqual(receipt, .protectedPayload)
            XCTAssertEqual(io.storedBytes, original)
            XCTAssertEqual(io.writeCount, 0)
        }
    }

    func testDuplicateKeysAtEveryObjectLevelIncludingEscapesAreProtected() async throws {
        let original = String(decoding: try bytes(document()), as: UTF8.self)
        let fixtures = [
            original.replacingOccurrences(of: "\"enabled\":true", with: "\"enabled\":true,\"enabled\":false"),
            original.replacingOccurrences(of: "\"enabled\":true", with: #""enabled":true,"enabl\u0065d":false"#),
            original.replacingOccurrences(of: "\"lastLaunch\":", with: "\"lastLaunch\":0,\"lastLaunch\":"),
            original.replacingOccurrences(of: "\"salt\":", with: "\"salt\":\"other\",\"salt\":"),
            #"{"schemaVersion":1,"document":{},"docum\u0065nt":{}}"#,
            #"{"schemaVersion":1,"document":{"entries":{"bundle:a":{},"bundle:\u0061":{}}}}"#,
            #"{"schemaVersion":1,"document":{"entries":{"bundle:a":{"dailyCounts":{"1":1,"\u0031":2}}}}}"#
        ]
        for fixture in fixtures {
            let preserved = Data(fixture.utf8)
            XCTAssertEqual(LaunchActivityFileStore.decode(preserved), .ambiguousSchema)
            let io = ActivityMemoryIO(preserved)
            let receipt = await LaunchActivityFileStore(io: io).save(document(), recoveringCorruptPayload: true)
            XCTAssertEqual(receipt, .protectedPayload)
            XCTAssertEqual(io.storedBytes, preserved)
            XCTAssertEqual(io.writeCount, 0)
        }
    }

    func testEscapedValidHeaderAndNestedHeaderLikeTextAreAccepted() throws {
        var saved = document()
        saved.entries["bundle:schemaVersion"] = saved.entries.removeValue(forKey: "bundle:fixture.activity")
        let text = String(decoding: try bytes(saved), as: UTF8.self)
            .replacingOccurrences(of: "\"schemaVersion\":1", with: #""schema\u0056ersion":1"#)
        XCTAssertEqual(LaunchActivityFileStore.decode(Data(text.utf8)), .loaded(saved))
    }

    func testUnknownFieldsInvalidShapesAndNumericDayAliasesAreCorrupt() throws {
        let saved = document()
        let day = try XCTUnwrap(saved.entries.values.first?.dailyCounts.keys.first)
        let original = String(decoding: try bytes(saved), as: UTF8.self)
        let fixtures = [
            original.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":1,\"extra\":0"),
            original.replacingOccurrences(of: "\"enabled\":true", with: "\"enabled\":true,\"extra\":0"),
            original.replacingOccurrences(of: "\"lastLaunch\":", with: "\"extra\":0,\"lastLaunch\":"),
            original.replacingOccurrences(of: "\"enabled\":true", with: "\"enabled\":1"),
            original.replacingOccurrences(of: "\"salt\":\"" + salt + "\"", with: "\"salt\":\"invalid\""),
            original.replacingOccurrences(of: "\"bundle:fixture.activity\"", with: "\"path:/raw/private.app\""),
            original.replacingOccurrences(of: "\"\(day)\":3", with: "\"0\(day)\":3"),
            original.replacingOccurrences(of: "\"\(day)\":3", with: "\"+\(day)\":3"),
            original.replacingOccurrences(of: "\"\(day)\":3", with: "\"\(day)\":3,\"0\(day)\":2"),
            #"{"schemaVersion":1,"document":{}}"#,
            #"{"schemaVersion":1,"document":{"enabled":false,"salt":"a","entries":[]}}"#,
            #"{"schemaVersion":1,"document":{"entries":{"bundle:a":{"dailyCounts":{"1":1,"01":2}}}}}"#,
            #"{"schemaVersion":1,"document":{"entries":{"bundle:a":{"dailyCounts":{"+1":1}}}}}"#,
            #"{"schemaVersion":true,"document":{}}"#,
            #"{"schemaVersion":"1","document":{}}"#,
            #"{"document":{}}"#
        ]
        for fixture in fixtures {
            XCTAssertEqual(LaunchActivityFileStore.decode(Data(fixture.utf8)), .corrupt)
        }
    }

    func testDecodeRejectsIdentityAndBucketCapsRatherThanSilentlyTruncating() throws {
        var oversized = document()
        let entry = try XCTUnwrap(oversized.entries.values.first)
        oversized.entries = Dictionary(uniqueKeysWithValues: (0..<257).map { ("bundle:fixture.\($0)", entry) })
        XCTAssertEqual(LaunchActivityFileStore.decode(try bytes(oversized)), .corrupt)
        var tooManyBuckets = document()
        let day = Int(floor(entry.lastLaunch.timeIntervalSince1970 / 86_400))
        tooManyBuckets.entries = ["bundle:fixture.activity": .init(lastLaunch: entry.lastLaunch,
            dailyCounts: Dictionary(uniqueKeysWithValues: (0...30).map { (day - $0, 1) }))]
        XCTAssertEqual(LaunchActivityFileStore.decode(try bytes(tooManyBuckets)), .corrupt)
        for count in [0, -1, Int.max] {
            let invalid = LaunchActivityDocument(enabled: true, salt: salt, entries: [
                "bundle:fixture.activity": .init(lastLaunch: entry.lastLaunch, dailyCounts: [day: count])
            ])
            XCTAssertEqual(LaunchActivityFileStore.decode(try bytes(invalid)), .corrupt)
        }
    }

    func testOversizedAndNonUTF8PayloadsCannotBeRecoveredByOverwrite() async {
        let fixtures = [Data(repeating: 32, count: LaunchActivityFileStore.maximumPayloadBytes + 2), Data([0xff, 0xfe])]
        for (index, original) in fixtures.enumerated() {
            let expected: LaunchActivityLoadResult = index == 0 ? .oversized : .ambiguousSchema
            XCTAssertEqual(LaunchActivityFileStore.decode(original), expected)
            let io = ActivityMemoryIO(original)
            let store = LaunchActivityFileStore(io: io)
            let loaded = await store.load()
            XCTAssertEqual(loaded, expected)
            let receipt = await store.save(document(), recoveringCorruptPayload: true)
            XCTAssertEqual(receipt, .protectedPayload)
            XCTAssertEqual(io.writeCount, 0)
            XCTAssertEqual(io.storedBytes, original)
            XCTAssertEqual(io.lastReadBound, 1_048_576)
        }
    }

    func testInvalidDocumentDoesNotReadOrWriteAndIOFailuresAreDistinct() async {
        let io = ActivityMemoryIO()
        let invalid = await LaunchActivityFileStore(io: io).save(.init(salt: "invalid"))
        XCTAssertEqual(invalid, .invalidPreferences)
        XCTAssertEqual(io.readCount, 0)
        XCTAssertEqual(io.writeCount, 0)
        let unreadable = LaunchActivityFileStore(io: ActivityMemoryIO(failReads: true))
        let load = await unreadable.load()
        let save = await unreadable.save(document())
        XCTAssertEqual(load, .unavailable)
        XCTAssertEqual(save, .unavailable)
        let writeFailure = await LaunchActivityFileStore(io: ActivityMemoryIO(failWrites: true)).save(document())
        XCTAssertEqual(writeFailure, .failed)
    }

    func testRetryAfterIndeterminateReplacementRequiresARealSaveReceipt() async {
        let io = ActivityMemoryIO(failAfterReplacementOnce: true)
        let store = LaunchActivityFileStore(io: io)
        let saved = document()
        let first = await store.save(saved)
        XCTAssertEqual(first, .failed)
        let visible = await store.load()
        XCTAssertEqual(visible, .loaded(saved))
        let retried = await store.save(saved)
        XCTAssertEqual(retried, .saved)
        XCTAssertEqual(io.writeCount, 2)
    }

    func testNoFollowRejectsSymlinkFIFOAndDirectoryTargets() async throws {
        let root = try temporaryRoot()
        let original = root.appendingPathComponent("original")
        let preserved = Data("preserved".utf8)
        try preserved.write(to: original)
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: original)
        let fifo = root.appendingPathComponent("fifo")
        let status = fifo.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }
            return mkfifo(path, 0o600)
        }
        XCTAssertEqual(status, 0)
        let directory = root.appendingPathComponent("directory")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for target in [alias, fifo, directory] {
            let store = LaunchActivityFileStore(fileURL: target)
            let loaded = await store.load()
            let rejected = await store.save(document(), recoveringCorruptPayload: true)
            XCTAssertEqual(loaded, .unavailable)
            XCTAssertEqual(rejected, .unavailable)
        }
        XCTAssertEqual(try Data(contentsOf: original), preserved)
    }

    func testSymbolicAncestorAndNonfileURLAreUnavailableWithoutCreation() async throws {
        let root = try temporaryRoot()
        let destination = root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: destination)
        let remote = try XCTUnwrap(URL(string: "https://example.invalid/Activity/activity.json"))
        for url in [alias.appendingPathComponent("activity.json"), remote] {
            let store = LaunchActivityFileStore(fileURL: url)
            let loaded = await store.load()
            let receipt = await store.save(document(), recoveringCorruptPayload: true)
            XCTAssertEqual(loaded, .unavailable)
            XCTAssertEqual(receipt, .unavailable)
        }
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: destination.path).isEmpty)
    }

    func testCooperativeLockPreventsActivityWriteUntilReleased() async throws {
        let directory = try temporaryRoot().appendingPathComponent("Activity")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("activity.json")
        let lock = Darwin.open(directory.appendingPathComponent(".library.lock").path, O_CREAT | O_RDWR, 0o600)
        XCTAssertGreaterThanOrEqual(lock, 0)
        guard lock >= 0 else { return }
        defer { Darwin.close(lock) }
        XCTAssertEqual(flock(lock, LOCK_EX | LOCK_NB), 0)
        let store = LaunchActivityFileStore(fileURL: file)
        let blocked = await store.save(document())
        XCTAssertEqual(blocked, .failed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(flock(lock, LOCK_UN), 0)
        let saved = await store.save(document())
        XCTAssertEqual(saved, .saved)
    }

    func testCompareBeforeCommitPreservesChangedFuturePayload() async throws {
        let root = try temporaryRoot()
        let file = root.appendingPathComponent("activity.json")
        let old = try bytes(document())
        let future = Data(#"{"schemaVersion":9,"future":true}"#.utf8)
        try old.write(to: file)
        let io = LocalAppLibraryFileIO(fileURL: file, beforeReplacement: { try future.write(to: file) })
        let receipt = await LaunchActivityFileStore(io: io).save(document())
        XCTAssertEqual(receipt, .failed)
        XCTAssertEqual(try Data(contentsOf: file), future)
    }

    func testAncestorSwapCannotRedirectActivityReplacement() async throws {
        let root = try temporaryRoot()
        let directory = root.appendingPathComponent("Activity")
        let archived = root.appendingPathComponent("Archived")
        let other = root.appendingPathComponent("Other")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("activity.json")
        let old = try bytes(document()), preserved = Data("other-preserved".utf8)
        try old.write(to: file)
        try preserved.write(to: other.appendingPathComponent("activity.json"))
        let io = LocalAppLibraryFileIO(fileURL: file, beforeReplacement: {
            try FileManager.default.moveItem(at: directory, to: archived)
            try FileManager.default.createSymbolicLink(at: directory, withDestinationURL: other)
        })
        let receipt = await LaunchActivityFileStore(io: io).save(document())
        XCTAssertEqual(receipt, .failed)
        XCTAssertEqual(try Data(contentsOf: other.appendingPathComponent("activity.json")), preserved)
        XCTAssertEqual(try Data(contentsOf: archived.appendingPathComponent("activity.json")), old)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: archived.path).contains { $0.hasPrefix(".library-write-") })
    }
}
