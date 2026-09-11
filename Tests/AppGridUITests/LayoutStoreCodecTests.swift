// AppGridUITests — LayoutStoreCodecTests（Phase 1F §10.1 自动化验证矩阵，store codec 域）
// 实现：T-1F-B-tests-codec（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
// 隐私：全部 fixture 用中性假数据（"com.example.appN" / "Group N" / "/Applications/Example.app"），
// 无真实 app 名/bundle ID/路径；测试体不含任何真实身份原值。
//
// 覆盖 §10.1 store 部分：往返；确定性；校验和篡改；结构校验（FolderID/app ref/成员重复、
// 顶层条目恰好一个非 nil、未知枚举、空值、非法 UUID）；工程上限（文件大小/folders/app refs/
// members）；未知未来版本；域不变量（title ≤64 grapheme、空/单成员 folder、成员重复、
// 悬空引用）；垃圾数据（随机字节/空 Data/截断 JSON/非 envelope JSON/缺校验和）。

import AppCatalogCore
import CryptoKit
import Foundation
import XCTest
@testable import AppGridUI

final class LayoutStoreCodecTests: XCTestCase {

    // MARK: - 夹具（中性）

    private func makeAppOnlyLayout(generation: UInt64 = 0) -> PersistentWorkspaceLayout {
        PersistentWorkspaceLayout(
            generation: LayoutGeneration(generation),
            topLevelOrder: [.app(.bundleID("com.example.app1")),
                            .app(.canonicalPath("/Applications/Example.app"))],
            folders: [])
    }

    private func refDTO(_ value: String, caseName: String = "bundleID") -> AppReferenceDTO {
        AppReferenceDTO(caseName: caseName, value: value)
    }

    private func folderDTO(id: String, title: String = "Group 1",
                           members: [AppReferenceDTO] = []) -> FolderRecordDTO {
        FolderRecordDTO(id: id, title: title, members: members)
    }

    private func envelope(topLevel: [TopLevelEntryDTO] = [],
                          folders: [FolderRecordDTO] = [],
                          schemaVersion: Int = LayoutStoreCodec.schemaVersion,
                          writeGeneration: UInt64 = 0) -> WorkspaceLayoutEnvelopeV1 {
        WorkspaceLayoutEnvelopeV1(schemaVersion: schemaVersion,
                                  writeGeneration: writeGeneration,
                                  layoutGeneration: 0,
                                  topLevelOrder: topLevel,
                                  folders: folders,
                                  metadata: MetadataDTO(migration: ["v1"]),
                                  checksum: nil)
    }

    /// 手构 envelope → 带合法 SHA-256 校验和的 Data（绕过 encode 的域校验，供结构/版本测试）。
    private func makeEnvelopeData(_ e: WorkspaceLayoutEnvelopeV1) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var payload = e
        payload.checksum = nil
        let payloadData = try encoder.encode(payload)
        let digest = SHA256.hash(data: payloadData)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        var full = e
        full.checksum = hex
        return try encoder.encode(full)
    }

    // MARK: - 往返 + 确定性

    func testRoundTripPreservesLayoutAndWriteGeneration() throws {
        let layout = PersistentWorkspaceLayout(
            generation: LayoutGeneration(7),
            topLevelOrder: [.app(.bundleID("com.example.app1")),
                            .app(.canonicalPath("/Applications/Example.app"))],
            folders: [])
        let data = try LayoutStoreCodec.encode(layout, writeGeneration: 42)
        let result = LayoutStoreCodec.decode(data)
        guard case .valid(let decoded) = result else {
            return XCTFail("expected .valid, got \(result)")
        }
        XCTAssertEqual(decoded.layout, layout)
        XCTAssertEqual(decoded.writeGeneration, 42)
    }

    func testRoundTripEmptyLayoutIsValid() throws {
        let layout = PersistentWorkspaceLayout.empty()
        let data = try LayoutStoreCodec.encode(layout, writeGeneration: 0)
        let result = LayoutStoreCodec.decode(data)
        guard case .valid(let decoded) = result else {
            return XCTFail("expected .valid, got \(result)")
        }
        XCTAssertEqual(decoded.layout, layout)
        XCTAssertEqual(decoded.writeGeneration, 0)
    }

    // 回归（T-1F-B-codec-folder-duplicate-repair）：含 folder 的合法布局（顶层 folder 条目
    // + 配对 folder record）round-trip decode 必须 .valid——旧实现共享 seenFolderIDs 误判 .corrupt。
    func testRoundTripFolderContainingLayoutIsValid() throws {
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
        let layout = PersistentWorkspaceLayout(
            generation: LayoutGeneration(5),
            topLevelOrder: [.app(.bundleID("com.example.app1")), .folder(folderID)],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1",
                                             members: [.bundleID("com.example.app2"),
                                                       .bundleID("com.example.app3")])])
        let data = try LayoutStoreCodec.encode(layout, writeGeneration: 1)
        let result = LayoutStoreCodec.decode(data)
        guard case .valid(let decoded) = result else {
            return XCTFail("expected .valid, got \(result)")
        }
        XCTAssertEqual(decoded.layout, layout)
        XCTAssertEqual(decoded.writeGeneration, 1)
    }

    func testEncodeIsDeterministicByteIdentical() throws {
        let layout = makeAppOnlyLayout(generation: 3)
        let first = try LayoutStoreCodec.encode(layout, writeGeneration: 9)
        let second = try LayoutStoreCodec.encode(layout, writeGeneration: 9)
        XCTAssertEqual(first, second)
    }

    // MARK: - 校验和篡改

    func testTamperedPayloadByteIsCorrupt() throws {
        let data = try LayoutStoreCodec.encode(makeAppOnlyLayout(), writeGeneration: 1)
        var tampered = data
        tampered[data.count / 2] ^= 0xFF
        XCTAssertEqual(LayoutStoreCodec.decode(tampered), .corrupt)
    }

    // MARK: - 结构校验（手构 envelope 绕过 encode 域校验）

    func testDuplicateFolderRecordIDsAreCorrupt() throws {
        let e = envelope(folders: [folderDTO(id: "00000000-0000-0000-0000-0000000000A1"),
                                   folderDTO(id: "00000000-0000-0000-0000-0000000000A1")])
        XCTAssertEqual(LayoutStoreCodec.decode(try makeEnvelopeData(e)), .corrupt)
    }

    func testDuplicateTopLevelFolderEntriesAreCorrupt() throws {
        let e = envelope(topLevel: [TopLevelEntryDTO(app: nil, folder: "00000000-0000-0000-0000-0000000000A1"),
                                    TopLevelEntryDTO(app: nil, folder: "00000000-0000-0000-0000-0000000000A1")])
        XCTAssertEqual(LayoutStoreCodec.decode(try makeEnvelopeData(e)), .corrupt)
    }

    func testDuplicateTopLevelAppReferencesAreCorrupt() throws {
        let e = envelope(topLevel: [TopLevelEntryDTO(app: refDTO("com.example.app1"), folder: nil),
                                    TopLevelEntryDTO(app: refDTO("com.example.app1"), folder: nil)])
        XCTAssertEqual(LayoutStoreCodec.decode(try makeEnvelopeData(e)), .corrupt)
    }

    func testAppReferenceDuplicatedTopLevelAndMemberIsCorrupt() throws {
        let e = envelope(topLevel: [TopLevelEntryDTO(app: refDTO("com.example.app1"), folder: nil)],
                         folders: [folderDTO(id: "00000000-0000-0000-0000-0000000000A1",
                                             members: [refDTO("com.example.app1"), refDTO("com.example.app2")])])
        XCTAssertEqual(LayoutStoreCodec.decode(try makeEnvelopeData(e)), .corrupt)
    }

    func testDuplicateFolderMembersAreCorrupt() throws {
        let e = envelope(folders: [folderDTO(id: "00000000-0000-0000-0000-0000000000A1",
                                             members: [refDTO("com.example.app1"), refDTO("com.example.app1")])])
        XCTAssertEqual(LayoutStoreCodec.decode(try makeEnvelopeData(e)), .corrupt)
    }

    func testAppReferenceDuplicatedAcrossFoldersIsCorrupt() throws {
        let e = envelope(folders: [folderDTO(id: "00000000-0000-0000-0000-0000000000A1",
                                             members: [refDTO("com.example.app1"), refDTO("com.example.app2")]),
                                   folderDTO(id: "00000000-0000-0000-0000-0000000000A2",
                                             members: [refDTO("com.example.app2"), refDTO("com.example.app3")])])
        XCTAssertEqual(LayoutStoreCodec.decode(try makeEnvelopeData(e)), .corrupt)
    }

    func testTopLevelEntryWithBothAppAndFolderIsCorrupt() throws {
        let e = envelope(topLevel: [TopLevelEntryDTO(app: refDTO("com.example.app1"),
                                                    folder: "00000000-0000-0000-0000-0000000000A1")])
        XCTAssertEqual(LayoutStoreCodec.decode(try makeEnvelopeData(e)), .corrupt)
    }

    func testTopLevelEntryWithNeitherAppNorFolderIsCorrupt() throws {
        let e = envelope(topLevel: [TopLevelEntryDTO(app: nil, folder: nil)])
        XCTAssertEqual(LayoutStoreCodec.decode(try makeEnvelopeData(e)), .corrupt)
    }

    func testUnknownAppReferenceCaseIsCorrupt() throws {
        let e = envelope(topLevel: [TopLevelEntryDTO(app: refDTO("com.example.app1", caseName: "weird"), folder: nil)])
        XCTAssertEqual(LayoutStoreCodec.decode(try makeEnvelopeData(e)), .corrupt)
    }

    func testEmptyAppReferenceValueIsCorrupt() throws {
        let e = envelope(topLevel: [TopLevelEntryDTO(app: refDTO(""), folder: nil)])
        XCTAssertEqual(LayoutStoreCodec.decode(try makeEnvelopeData(e)), .corrupt)
    }

    func testInvalidFolderUUIDIsCorrupt() throws {
        let e = envelope(topLevel: [TopLevelEntryDTO(app: nil, folder: "not-a-uuid")])
        XCTAssertEqual(LayoutStoreCodec.decode(try makeEnvelopeData(e)), .corrupt)
    }

    // 回归（T-1F-B-codec-folder-duplicate-repair，可选加固）：顶层 folder 条目无配对
    // folder record（悬空引用）→ .corrupt。
    func testTopLevelFolderWithoutRecordIsCorrupt() throws {
        let e = envelope(topLevel: [TopLevelEntryDTO(app: nil,
                                                     folder: "00000000-0000-0000-0000-0000000000A1")],
                         folders: [])
        XCTAssertEqual(LayoutStoreCodec.decode(try makeEnvelopeData(e)), .corrupt)
    }

    // MARK: - 工程上限

    func testFileSizeOverMaxIsOverLimit() {
        let data = Data(repeating: 0x20, count: LayoutStoreCodec.maxFileBytes + 1)
        XCTAssertEqual(LayoutStoreCodec.decode(data), .overLimit)
    }

    func testFolderCountOverMaxIsOverLimit() throws {
        var folders: [FolderRecordDTO] = []
        for i in 0..<(LayoutStoreCodec.maxFolders + 1) {
            folders.append(folderDTO(id: String(format: "00000000-0000-0000-0000-%012d", i)))
        }
        XCTAssertEqual(LayoutStoreCodec.decode(try makeEnvelopeData(envelope(folders: folders))), .overLimit)
    }

    func testAppReferenceCountOverMaxIsOverLimit() throws {
        var topLevel: [TopLevelEntryDTO] = []
        for i in 0..<(LayoutStoreCodec.maxAppReferences + 1) {
            topLevel.append(TopLevelEntryDTO(app: refDTO("com.example.app\(i)"), folder: nil))
        }
        XCTAssertEqual(LayoutStoreCodec.decode(try makeEnvelopeData(envelope(topLevel: topLevel))), .overLimit)
    }

    func testEncodeFolderCountOverMaxThrowsOverLimit() {
        var topLevel: [WorkspaceTopLevelEntry] = []
        var records: [PersistentFolderRecord] = []
        for i in 0..<(LayoutStoreCodec.maxFolders + 1) {
            let id = FolderID(uuid: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", i))!)
            topLevel.append(.folder(id))
            records.append(PersistentFolderRecord(id: id, title: "Group \(i)",
                                                  members: [.bundleID("com.example.member\(i)a"),
                                                            .bundleID("com.example.member\(i)b")]))
        }
        let layout = PersistentWorkspaceLayout(generation: .zero, topLevelOrder: topLevel, folders: records)
        XCTAssertThrowsError(try LayoutStoreCodec.encode(layout, writeGeneration: 0)) { error in
            XCTAssertEqual(error as? LayoutStoreCodecError, .overLimit)
        }
    }

    func testEncodeMembersPerFolderOverMaxThrowsOverLimit() {
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
        var members: [PersistentAppReference] = []
        for i in 0..<(LayoutStoreCodec.maxMembersPerFolder + 1) {
            members.append(.bundleID("com.example.member\(i)"))
        }
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.folder(folderID)],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1", members: members)])
        XCTAssertThrowsError(try LayoutStoreCodec.encode(layout, writeGeneration: 0)) { error in
            XCTAssertEqual(error as? LayoutStoreCodecError, .overLimit)
        }
    }

    // MARK: - 未知未来版本

    func testUnknownFutureVersionReturnsVersion() throws {
        let e = envelope(topLevel: [TopLevelEntryDTO(app: refDTO("com.example.app1"), folder: nil)],
                         schemaVersion: 2)
        XCTAssertEqual(LayoutStoreCodec.decode(try makeEnvelopeData(e)), .unknownFutureVersion(2))
    }

    func testFarFutureVersionNeverValid() throws {
        let e = envelope(topLevel: [TopLevelEntryDTO(app: refDTO("com.example.app1"), folder: nil)],
                         schemaVersion: 99)
        let result = LayoutStoreCodec.decode(try makeEnvelopeData(e))
        guard case .unknownFutureVersion(99) = result else {
            return XCTFail("expected unknownFutureVersion(99), got \(result)")
        }
    }

    func testOlderSchemaVersionIsCorrupt() throws {
        let e = envelope(topLevel: [TopLevelEntryDTO(app: refDTO("com.example.app1"), folder: nil)],
                         schemaVersion: 0)
        XCTAssertEqual(LayoutStoreCodec.decode(try makeEnvelopeData(e)), .corrupt)
    }

    // MARK: - 域不变量（encode 抛错）

    func testEncodeRejectsTitleOver64Graphemes() {
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.folder(folderID)],
            folders: [PersistentFolderRecord(id: folderID, title: String(repeating: "N", count: 65),
                                             members: [.bundleID("com.example.app1"), .bundleID("com.example.app2")])])
        XCTAssertThrowsError(try LayoutStoreCodec.encode(layout, writeGeneration: 0))
    }

    func testEncodeRejectsSingleMemberFolder() {
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.folder(folderID)],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1",
                                             members: [.bundleID("com.example.app1")])])
        XCTAssertThrowsError(try LayoutStoreCodec.encode(layout, writeGeneration: 0))
    }

    func testEncodeRejectsEmptyFolder() {
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.folder(folderID)],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1", members: [])])
        XCTAssertThrowsError(try LayoutStoreCodec.encode(layout, writeGeneration: 0))
    }

    func testEncodeRejectsMemberAlsoAtTopLevel() {
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.app(.bundleID("com.example.app1")), .folder(folderID)],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1",
                                             members: [.bundleID("com.example.app1"), .bundleID("com.example.app2")])])
        XCTAssertThrowsError(try LayoutStoreCodec.encode(layout, writeGeneration: 0))
    }

    func testEncodeRejectsTopLevelFolderWithoutRecord() {
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.folder(folderID)],
            folders: [])
        XCTAssertThrowsError(try LayoutStoreCodec.encode(layout, writeGeneration: 0))
    }

    func testEncodeRejectsOrphanFolderRecord() {
        let folderID = FolderID(uuid: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!)
        let layout = PersistentWorkspaceLayout(
            generation: .zero,
            topLevelOrder: [.app(.bundleID("com.example.app3"))],
            folders: [PersistentFolderRecord(id: folderID, title: "Group 1",
                                             members: [.bundleID("com.example.app1"), .bundleID("com.example.app2")])])
        XCTAssertThrowsError(try LayoutStoreCodec.encode(layout, writeGeneration: 0))
    }

    // MARK: - 垃圾数据

    func testRandomBytesAreCorrupt() {
        let data = Data((0..<256).map { UInt8($0) })
        XCTAssertEqual(LayoutStoreCodec.decode(data), .corrupt)
    }

    func testEmptyDataIsCorrupt() {
        XCTAssertEqual(LayoutStoreCodec.decode(Data()), .corrupt)
    }

    func testTruncatedJSONIsCorrupt() throws {
        let data = try LayoutStoreCodec.encode(makeAppOnlyLayout(), writeGeneration: 0)
        XCTAssertEqual(LayoutStoreCodec.decode(Data(data.prefix(data.count / 2))), .corrupt)
    }

    func testNonEnvelopeJSONIsCorrupt() {
        XCTAssertEqual(LayoutStoreCodec.decode(Data("{}".utf8)), .corrupt)
    }

    func testMissingChecksumIsCorrupt() throws {
        let e = envelope(topLevel: [TopLevelEntryDTO(app: refDTO("com.example.app1"), folder: nil)])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        XCTAssertEqual(LayoutStoreCodec.decode(try encoder.encode(e)), .corrupt)
    }
}
