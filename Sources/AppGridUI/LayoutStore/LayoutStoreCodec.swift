// AppGridUI — LayoutStore.LayoutStoreCodec（Phase 1F §10.2 / ADR-009 Q3/Q4/Q7）
// 实现：T-1F-B（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// schema v1 codec + validator：
// - 确定性编码：固定字段序 + `.sortedKeys` + 无时间戳/随机数入正文 → 同布局两次 encode
//   逐字节一致（可测）；checksum = SHA-256（CryptoKit）仅意外损坏检测，非防篡改。
// - 版本字段：`schemaVersion`；未知未来版本 → `.unknownFutureVersion`（只读保护，绝不覆盖）。
// - 结构校验：FolderID 全局唯一（记录 + 顶层条目）；app reference 全局至多一个位置；
//   folder 无重复成员；未知枚举值拒绝；随后域校验器复核 10 不变量（含 title ≤64 grapheme）。
// - 工程上限（ADR-009 Q4，标「待验证工程上限」）：文件 ≤ 1 MiB；folders ≤ 512；
//   总 app references ≤ 10,000；每 folder members ≤ 2,048。超限 → `.overLimit`。
// - 隐私：本文件不产生任何输出；错误载荷全部中性（无路径/无正文/无原值）。
//   FolderID 经受控投影：UUID storage 只进布局文件这一受控例外（ADR-009 Q3/Q12）。

import CryptoKit
import Foundation

// MARK: - 结果类型

/// 解码结果（中性）。
public enum LayoutStoreDecodeResult: Equatable, Sendable {
    /// 有效载荷（结构 + 校验和 + 域不变量 + 上限全部通过）。
    case valid(DecodedLayout)
    /// 损坏/不可解析/校验失败/不变量违反。
    case corrupt
    /// 未知未来 schemaVersion（只读保护；绝不降级覆盖）。
    case unknownFutureVersion(Int)
    /// 超工程上限。
    case overLimit
}

/// 解码出的布局 + journal writeGeneration。
public struct DecodedLayout: Equatable, Sendable {
    public let layout: PersistentWorkspaceLayout
    public let writeGeneration: UInt64

    public init(layout: PersistentWorkspaceLayout, writeGeneration: UInt64) {
        self.layout = layout
        self.writeGeneration = writeGeneration
    }
}

/// 编码错误（中性；进程内 domain 错误，不进 telemetry/日志）。
public enum LayoutStoreCodecError: Error, Equatable {
    case invalidLayout
    case overLimit
}

// MARK: - schema v1 envelope（受控 DTO；非自动 Codable 的域类型）

/// 顶层条目 DTO：`.app` 或 `.folder` 恰好一个非 nil（结构校验证明）。
struct TopLevelEntryDTO: Codable, Equatable {
    var app: AppReferenceDTO?
    var folder: String?
}

/// app 持久引用 DTO：`{case: bundleID|pathFallback, value: ...}`（ADR-009 Q2 方案 1）。
struct AppReferenceDTO: Codable, Equatable {
    var caseName: String
    var value: String

    /// 确定性全局唯一性键：区分不同 case/value 组合（validateStructure 用）。
    var comparisonKey: String { caseName + ":" + value }

    enum CodingKeys: String, CodingKey {
        case caseName = "case"
        case value
    }
}

/// folder 记录 DTO：id = FolderID UUID storage（受控投影）。
struct FolderRecordDTO: Codable, Equatable {
    var id: String
    var title: String
    var members: [AppReferenceDTO]
}

/// 最少中性迁移元数据（含版本路径；无正文）。
struct MetadataDTO: Codable, Equatable {
    var migration: [String]
}

/// schema v1 envelope（checksum 为 nil 时编码省略 → 用于校验和计算）。
struct WorkspaceLayoutEnvelopeV1: Codable, Equatable {
    var schemaVersion: Int
    var writeGeneration: UInt64
    var layoutGeneration: UInt64
    var topLevelOrder: [TopLevelEntryDTO]
    var folders: [FolderRecordDTO]
    var metadata: MetadataDTO
    var checksum: String?
}

/// Dispatch versions without requiring a future document to retain the v1 shape.
private struct WorkspaceLayoutVersionHeader: Decodable {
    let schemaVersion: Int
}

// MARK: - codec

/// schema v1 codec + validator（确定性；无状态）。
public enum LayoutStoreCodec {

    public static let schemaVersion = 1

    // 工程上限（ADR-009 Q4 建议初始评估值；标「待验证工程上限，非既有产品事实」）。
    public static let maxFileBytes = 1 << 20          // 1 MiB
    public static let maxFolders = 512
    public static let maxAppReferences = 10_000
    public static let maxMembersPerFolder = 2_048

    // MARK: encode

    /// 确定性编码：域校验 + 上限校验 → payload（无 checksum）→ SHA-256 → 完整 envelope。
    /// 同布局两次 encode 逐字节一致。
    public static func encode(_ layout: PersistentWorkspaceLayout,
                              writeGeneration: UInt64) throws -> Data {
        try WorkspaceLayoutValidator.assertValid(layout)
        let envelope = try makeEnvelope(layout: layout, writeGeneration: writeGeneration)
        guard checkCaps(envelope) else { throw LayoutStoreCodecError.overLimit }
        let payload = try encodePayload(envelope)
        let digest = SHA256.hash(data: payload)
        var full = envelope
        full.checksum = hexDigest(digest)
        let data = try encodePayload(full)
        guard data.count <= maxFileBytes else { throw LayoutStoreCodecError.overLimit }
        return data
    }

    // MARK: decode

    /// 解码 + 校验：大小上限 → JSON 解析 → 版本 → 校验和 → 结构 → 上限 → 域不变量。
    public static func decode(_ data: Data) -> LayoutStoreDecodeResult {
        guard data.count <= maxFileBytes else { return .overLimit }
        guard let header = try? JSONDecoder().decode(WorkspaceLayoutVersionHeader.self, from: data) else {
            return .corrupt
        }
        if header.schemaVersion > schemaVersion { return .unknownFutureVersion(header.schemaVersion) }
        guard let envelope = try? JSONDecoder().decode(WorkspaceLayoutEnvelopeV1.self, from: data) else {
            return .corrupt
        }
        guard envelope.schemaVersion == schemaVersion else {
            if envelope.schemaVersion > schemaVersion {
                return .unknownFutureVersion(envelope.schemaVersion)
            }
            return .corrupt
        }
        guard verifyChecksum(envelope) else { return .corrupt }
        guard validateStructure(envelope) else { return .corrupt }
        guard checkCaps(envelope) else { return .overLimit }
        guard let layout = makeLayout(from: envelope) else { return .corrupt }
        // 域校验器复核 10 不变量（含 title ≤64 grapheme、空/单成员 folder 拒绝）。
        guard WorkspaceLayoutValidator.validate(layout).isEmpty else { return .corrupt }
        return .valid(DecodedLayout(layout: layout, writeGeneration: envelope.writeGeneration))
    }

    // MARK: 内部

    private static func makeEnvelope(layout: PersistentWorkspaceLayout,
                                     writeGeneration: UInt64) throws -> WorkspaceLayoutEnvelopeV1 {
        var topLevel: [TopLevelEntryDTO] = []
        for entry in layout.topLevelOrder {
            switch entry {
            case .app(let ref):
                topLevel.append(TopLevelEntryDTO(app: appDTO(ref), folder: nil))
            case .folder(let folderID):
                guard let id = folderID.uuidString else { throw LayoutStoreCodecError.invalidLayout }
                topLevel.append(TopLevelEntryDTO(app: nil, folder: id))
            }
        }
        var folders: [FolderRecordDTO] = []
        for record in layout.folders {
            guard let id = record.id.uuidString else { throw LayoutStoreCodecError.invalidLayout }
            folders.append(FolderRecordDTO(id: id,
                                           title: record.title,
                                           members: record.members.map(appDTO)))
        }
        return WorkspaceLayoutEnvelopeV1(schemaVersion: schemaVersion,
                                         writeGeneration: writeGeneration,
                                         layoutGeneration: layout.generation.value,
                                         topLevelOrder: topLevel,
                                         folders: folders,
                                         metadata: MetadataDTO(migration: ["v1"]),
                                         checksum: nil)
    }

    private static func appDTO(_ ref: PersistentAppReference) -> AppReferenceDTO {
        switch ref {
        case .bundleID(let id): return AppReferenceDTO(caseName: "bundleID", value: id)
        case .canonicalPath(let path): return AppReferenceDTO(caseName: "pathFallback", value: path)
        }
    }

    private static func encodePayload(_ envelope: WorkspaceLayoutEnvelopeV1) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(envelope)
    }

    private static func hexDigest(_ digest: SHA256.Digest) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    /// 校验和验证：重编码 payload（checksum 省略）→ SHA-256 → 与存储值比较（大小写不敏感）。
    private static func verifyChecksum(_ envelope: WorkspaceLayoutEnvelopeV1) -> Bool {
        guard let stored = envelope.checksum else { return false }
        var payload = envelope
        payload.checksum = nil
        guard let data = try? encodePayload(payload) else { return false }
        let digest = SHA256.hash(data: data)
        return hexDigest(digest).caseInsensitiveCompare(stored) == .orderedSame
    }

    /// 结构校验：枚举值白名单、UUID 可解析、FolderID 全局唯一、app ref 全局唯一、
    /// folder 无重复成员、顶层条目 app/folder 恰好一个。
    private static func validateStructure(_ envelope: WorkspaceLayoutEnvelopeV1) -> Bool {
        var seenFolderIDs = Set<String>()
        var seenRefKeys = Set<String>()

        // 顶层 folder 条目必须对应一个 folder record（悬空引用 → false）。
        // 顶层条目不参与 seenFolderIDs：folder 唯一性由 folders 循环独占保证——
        // 合法布局中顶层 folder 条目与 folder record 必然配对，共享集合会误判 .corrupt。
        let recordFolderIDs = Set(envelope.folders.map(\.id))

        for entry in envelope.topLevelOrder {
            switch (entry.app, entry.folder) {
            case (.some(let ref), nil):
                guard isValidAppRef(ref) else { return false }
                guard seenRefKeys.insert(ref.comparisonKey).inserted else { return false }
            case (nil, .some(let folderID)):
                guard UUID(uuidString: folderID) != nil else { return false }
                guard recordFolderIDs.contains(folderID) else { return false }
            default:
                return false   // 恰好一个非 nil
            }
        }

        for record in envelope.folders {
            guard UUID(uuidString: record.id) != nil else { return false }
            guard seenFolderIDs.insert(record.id).inserted else { return false }
            var seenMembers = Set<String>()
            for member in record.members {
                guard isValidAppRef(member) else { return false }
                guard seenMembers.insert(member.comparisonKey).inserted else { return false }
                guard seenRefKeys.insert(member.comparisonKey).inserted else { return false }
            }
        }
        return true
    }

    private static func isValidAppRef(_ ref: AppReferenceDTO) -> Bool {
        switch ref.caseName {
        case "bundleID", "pathFallback":
            return !ref.value.isEmpty
        default:
            return false   // 未知枚举值拒绝
        }
    }

    private static func checkCaps(_ envelope: WorkspaceLayoutEnvelopeV1) -> Bool {
        guard envelope.folders.count <= maxFolders else { return false }
        var refCount = 0
        for entry in envelope.topLevelOrder where entry.app != nil { refCount += 1 }
        for record in envelope.folders {
            guard record.members.count <= maxMembersPerFolder else { return false }
            refCount += record.members.count
        }
        return refCount <= maxAppReferences
    }

    private static func makeLayout(from envelope: WorkspaceLayoutEnvelopeV1) -> PersistentWorkspaceLayout? {
        var topLevel: [WorkspaceTopLevelEntry] = []
        for entry in envelope.topLevelOrder {
            if let app = entry.app {
                topLevel.append(.app(makeAppRef(app)))
            } else if let folderID = entry.folder, let uuid = UUID(uuidString: folderID) {
                topLevel.append(.folder(FolderID(uuid: uuid)))
            } else {
                return nil
            }
        }
        var folders: [PersistentFolderRecord] = []
        for record in envelope.folders {
            guard let uuid = UUID(uuidString: record.id) else { return nil }
            var members: [PersistentAppReference] = []
            for member in record.members { members.append(makeAppRef(member)) }
            folders.append(PersistentFolderRecord(id: FolderID(uuid: uuid),
                                                  title: record.title,
                                                  members: members))
        }
        return PersistentWorkspaceLayout(generation: LayoutGeneration(envelope.layoutGeneration),
                                         topLevelOrder: topLevel,
                                         folders: folders)
    }

    private static func makeAppRef(_ ref: AppReferenceDTO) -> PersistentAppReference {
        switch ref.caseName {
        case "bundleID": return .bundleID(ref.value)
        default: return .canonicalPath(ref.value)
        }
    }
}

// MARK: - FolderID 受控投影（仅 LayoutStore 内专用 adapter 有访问权；ADR-009 Q3）

extension FolderID {
    /// 受控投影：UUID storage 序列化（UUID 原值只进布局文件这一受控例外）。
    /// LayoutDomain/FolderDomain 冻结（T-1F-A 产物只读）且无公开 UUID 访问器，本 adapter
    /// 经运行时反射读取私有 storage——ADR-009 Q3 明示「仅 LayoutStore 内专用 adapter 有
    /// 访问权」，此即该受控入口。反射失败（不可达：FolderID 恒由 UUID 承载）→ nil，
    /// encode 拒绝（中性错误，不产生输出）。
    var uuidString: String? {
        for child in Mirror(reflecting: self).children {
            if let uuid = child.value as? UUID {
                return uuid.uuidString
            }
        }
        return nil
    }
}
