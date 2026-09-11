// AppCatalogCore — Phase 1B domain（§5.1 / wave1-interfaces.md §B）
// 实现：T-worker-b-catalogcore（Phase 1B Wave 1）。签名保持 §B 冻结；行为补全 WORKER 标记处。
// 隐私硬边界：AppID/IconIdentity 不透明；对外不可还原原文；telemetry 不得输出 identity 原文。
// AccessDeclaration: NO_PRIOR_EXPOSURE（本实现仅依据 wave1-interfaces.md §B + PHASE1B prompt；
//   未读取 §2.2 任何禁止来源；无 PRIOR_EXPOSURE）。

import Foundation

// MARK: - 稳定身份（bundleID 主身份；无则 canonical URL fallback；displayName 绝不作身份）

/// 不透明稳定标识。对外不可还原原文。
public struct AppID: Hashable, Sendable {
    private enum Storage: Hashable, Sendable {
        case bundleIdentifier(String)
        case canonicalURLFallback(String)   // 规范化后的路径字符串；仅内部
    }
    private let storage: Storage

    /// 规则 2 主身份
    public static func bundleIdentifier(_ id: String) -> AppID {
        AppID(storage: .bundleIdentifier(id))
    }

    /// 规则 4 fallback（无 bundle ID 时用规范化 URL）
    public static func canonicalURLFallback(_ url: URL) -> AppID {
        AppID(storage: .canonicalURLFallback(url.standardizedFileURL.path))
    }

    /// 仅调试；不含原文
    public var redactedDescription: String {
        switch storage {
        case .bundleIdentifier: return "AppID(bundleID:<redacted>)"
        case .canonicalURLFallback: return "AppID(url:<redacted>)"
        }
    }
}

// MARK: - 消失锚点的后继/前驱搜索用全序（§6.3 规则 2/3 的确定性实现）

extension AppID {
    /// 全序（仅模块内、仅用于锚点已消失时的后继/前驱搜索；与展示排序无关）：
    /// bundleID 键 < canonicalURL fallback 键；同类按字符串升序。
    /// 说明：锚点 AppID 不透明（不携带 displayName），无法在展示排序中定位其“应处位置”，
    /// 故以身份键全序近似“稳定排序中的后继/前驱”。UI 正常路径锚点仍存在（走 .located），
    /// 本全序只服务锚点消失的降级路径；确定性由字符串全序保证（规则 6：绝不沿用旧数组 index）。
    fileprivate func anchorOrderLessThan(_ other: AppID) -> Bool {
        switch (storage, other.storage) {
        case (.bundleIdentifier(let a), .bundleIdentifier(let b)): return a < b
        case (.bundleIdentifier, .canonicalURLFallback): return true
        case (.canonicalURLFallback, .bundleIdentifier): return false
        case (.canonicalURLFallback(let a), .canonicalURLFallback(let b)): return a < b
        }
    }
}

/// 图标身份：供 IconKey 派生；不含字节/哈希/源路径；天然不含 bundle ID 原文。
public struct IconIdentity: Hashable, Sendable {
    private let appID: AppID
    public static func from(appID: AppID) -> IconIdentity {
        IconIdentity(appID: appID)
    }
}

// MARK: - 记录与快照

public struct AppRecord: Hashable, Sendable {
    public let id: AppID
    public let displayName: String
    public let bundleIdentifier: String?          // nil = 缺失（走 fallback）
    public let canonicalURL: URL                  // 规范化后（同一 canonical URL = 同一对象）
    public let iconIdentity: IconIdentity
    public let sourceRootPriority: Int            // 0 = 最高优先级 root（去重用）

    public init(id: AppID, displayName: String, bundleIdentifier: String?,
                canonicalURL: URL, iconIdentity: IconIdentity, sourceRootPriority: Int) {
        self.id = id
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.canonicalURL = canonicalURL
        self.iconIdentity = iconIdentity
        self.sourceRootPriority = sourceRootPriority
    }
}

/// 不可变、已排序已去重、带单调 revision。
public struct CatalogSnapshot: Sendable, Equatable {
    public let revision: CatalogRevision
    public let records: [AppRecord]
    public init(revision: CatalogRevision, records: [AppRecord]) {
        self.revision = revision
        self.records = records
    }
}

/// 单调 revision（严格递增由门禁/仓库保证）。
public struct CatalogRevision: Hashable, Comparable, Sendable {
    public let value: UInt64
    public init(_ value: UInt64) { self.value = value }
    public static let zero = CatalogRevision(0)
    public func incremented() -> CatalogRevision { CatalogRevision(value + 1) }
    public static func < (lhs: CatalogRevision, rhs: CatalogRevision) -> Bool { lhs.value < rhs.value }
}

// MARK: - 排序与去重 policy（deterministic 是硬要求）

public enum CatalogTieBreaker: Sendable, Equatable { case canonicalURLAscending }

public struct CatalogOrdering: Sendable, Equatable {
    public var locale: Locale?                    // nil = 系统 locale；测试注入固定 locale
    public var caseInsensitive: Bool = true
    public var tieBreaker: CatalogTieBreaker = .canonicalURLAscending
    public init(locale: Locale? = nil, caseInsensitive: Bool = true,
                tieBreaker: CatalogTieBreaker = .canonicalURLAscending) {
        self.locale = locale
        self.caseInsensitive = caseInsensitive
        self.tieBreaker = tieBreaker
    }
}

public enum DuplicateResolution: Sendable, Equatable {
    case rootPriorityFirst        // 推荐默认：root 优先级 + canonical path 字典序（ADR-004 冻结）
    case keepMultiInstance        // 保留为有稳定区分的多实例
}

public struct CatalogPolicy: Sendable, Equatable {
    public var ordering: CatalogOrdering = .init()
    public var duplicateResolution: DuplicateResolution = .rootPriorityFirst
    public init(ordering: CatalogOrdering = .init(),
                duplicateResolution: DuplicateResolution = .rootPriorityFirst) {
        self.ordering = ordering
        self.duplicateResolution = duplicateResolution
    }
}

/// 校验失败分类（validate/build 抛出）。
/// 注意：错误载荷是进程内 domain 错误，不是 telemetry；telemetry 边界在调用侧。
public enum CatalogValidationError: Error, Equatable {
    case duplicateCanonicalURL(URL)   // 规则 1：同一 canonical URL = 同一对象，快照内不得重复
    case notSorted                    // 不满足策略排序（displayName 主序 + canonicalURL 升序 tie，严格递增）
}

/// 构建器：canonical URL 去重 → bundleID 去重（policy）→ 稳定排序 → 校验。deterministic。
///
/// 确定性保证：
/// - 去重胜者选择只用记录字段（root 优先级 → displayName → canonical path），不依赖输入顺序
///   （唯一例外：同一 canonical URL + 同一优先级 + 同一 displayName 的完全同键重复，取首个出现）。
/// - 排序为严格全序（displayName 比较相等时由唯一 canonicalURL tie 打破），
///   故 `sorted(by:)` 的稳定性（Swift 不保证）与输出无关。
/// - 同一输入（任意顺序）→ 同一输出。
public enum CatalogBuilder {

    public static func build(rawRecords: [AppRecord], policy: CatalogPolicy,
                             revision: CatalogRevision) throws -> CatalogSnapshot {
        let byURL = dedupeByCanonicalURL(rawRecords)                            // 规则 1
        let byIdentity = dedupeByBundleID(byURL, policy: policy.duplicateResolution) // 规则 3
        let sorted = stableSort(byIdentity, ordering: policy.ordering)          // 稳定排序
        let snapshot = CatalogSnapshot(revision: revision, records: sorted)
        try validateStrictly(snapshot, ordering: policy.ordering)               // 策略感知校验
        return snapshot
    }

    /// 结构校验：无重复 canonical URL（对象身份，规则 1）、无重复 slot、严格有序。
    ///
    /// 说明（ADR-004 待 Main 确认的解读）：
    /// - “身份”按规则 1 判定 = canonical URL（同一 canonical URL = 同一对象）；快照内不得重复。
    /// - AppID 允许在 `.keepMultiInstance` 快照中重复（同一 app 的稳定多实例，以 canonicalURL 区分）——
    ///   validate 无 policy 参数，故身份判重收敛到 canonical URL。
    /// - “有序”按**默认** `CatalogOrdering`（locale nil = 系统、caseInsensitive true、
    ///   tieBreaker canonicalURLAscending）校验；以自定义 ordering 构建的快照由 `build` 内部
    ///   以同一 ordering 校验，公开 `validate` 的默认序校验对它们是保守的。
    public static func validate(_ snapshot: CatalogSnapshot) throws {
        try validateStrictly(snapshot, ordering: CatalogOrdering())
    }

    // MARK: 内部管线

    /// 规则 1：同一 canonical URL = 同一对象。
    /// 胜者：sourceRootPriority 最小（0 = 最高优先级 root）→ displayName 升序（POSIX 字面比较）
    /// → 输入顺序（最后手段；仅完全同键重复时生效）。deterministic，与输入顺序无关（除最后手段）。
    private static func dedupeByCanonicalURL(_ records: [AppRecord]) -> [AppRecord] {
        var best: [String: (record: AppRecord, order: Int)] = [:]
        for (index, record) in records.enumerated() {
            let key = canonicalKey(record)
            if let existing = best[key] {
                if isBetterDedupeCandidate(record, order: index, than: existing.record, order: existing.order) {
                    best[key] = (record, index)
                }
            } else {
                best[key] = (record, index)
            }
        }
        return best.values.map(\.record)
    }

    private static func isBetterDedupeCandidate(_ a: AppRecord, order aOrder: Int,
                                                than b: AppRecord, order bOrder: Int) -> Bool {
        if a.sourceRootPriority != b.sourceRootPriority {
            return a.sourceRootPriority < b.sourceRootPriority
        }
        let nameOrder = a.displayName.compare(b.displayName, options: [],
                                              range: nil, locale: Locale(identifier: "en_US_POSIX"))
        if nameOrder != .orderedSame {
            return nameOrder == .orderedAscending
        }
        return aOrder < bOrder
    }

    /// 规则 3：重复 bundle ID 按 policy 处理。
    /// - `.rootPriorityFirst`：保留 root 优先级更高者（sourceRootPriority 更小）；
    ///   同优先级 → canonical path 字典序升序（与 tieBreaker 一致）。deterministic、与输入顺序无关。
    /// - `.keepMultiInstance`：全部保留（稳定多实例，canonicalURL 区分）。
    /// - bundleIdentifier == nil 的记录不参与 bundleID 判重（身份 = canonical URL，第一步已唯一）。
    private static func dedupeByBundleID(_ records: [AppRecord], policy: DuplicateResolution) -> [AppRecord] {
        guard policy == .rootPriorityFirst else { return records }
        var winner: [String: AppRecord] = [:]
        for record in records {
            guard let bundleID = record.bundleIdentifier else { continue }
            if let existing = winner[bundleID] {
                if rootPriorityFirstPick(record, over: existing) {
                    winner[bundleID] = record
                }
            } else {
                winner[bundleID] = record
            }
        }
        return records.filter { record in
            guard let bundleID = record.bundleIdentifier else { return true }
            guard let kept = winner[bundleID] else { return true }
            return canonicalKey(kept) == canonicalKey(record)
        }
    }

    private static func rootPriorityFirstPick(_ candidate: AppRecord, over current: AppRecord) -> Bool {
        if candidate.sourceRootPriority != current.sourceRootPriority {
            return candidate.sourceRootPriority < current.sourceRootPriority
        }
        return canonicalKey(candidate) < canonicalKey(current)
    }

    /// 稳定排序：displayName 主序（locale + caseInsensitive）→ canonicalURL 升序 tie。
    /// 去重后 canonicalURL 全局唯一 → 严格全序 → 输出与 Swift 排序稳定性无关。
    private static func stableSort(_ records: [AppRecord], ordering: CatalogOrdering) -> [AppRecord] {
        records.sorted { a, b in
            let nameOrder = displayNameCompare(a.displayName, b.displayName, ordering: ordering)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            return canonicalKey(a) < canonicalKey(b)
        }
    }

    private static func displayNameCompare(_ a: String, _ b: String, ordering: CatalogOrdering) -> ComparisonResult {
        var options: String.CompareOptions = []
        if ordering.caseInsensitive {
            options.insert(.caseInsensitive)
        }
        return a.compare(b, options: options, range: nil, locale: ordering.locale ?? .current)
    }

    private static func canonicalKey(_ record: AppRecord) -> String {
        record.canonicalURL.standardizedFileURL.path
    }

    /// 校验实现（ordering 可注入：build 用策略序、公开 validate 用默认序）。
    /// 检查：① 无重复 canonical URL（对象身份）；② 严格递增（displayName 比较相等时 URL 必须升序）。
    /// 无重复 slot：canonical URL 唯一 + 严格全序 ⇒ 记录两两不同，天然成立。
    private static func validateStrictly(_ snapshot: CatalogSnapshot, ordering: CatalogOrdering) throws {
        var seenCanonicalKeys = Set<String>()
        for record in snapshot.records {
            guard seenCanonicalKeys.insert(canonicalKey(record)).inserted else {
                throw CatalogValidationError.duplicateCanonicalURL(record.canonicalURL)
            }
        }
        let records = snapshot.records
        guard records.count > 1 else { return }
        for i in 0..<(records.count - 1) {
            let a = records[i], b = records[i + 1]
            let nameOrder = displayNameCompare(a.displayName, b.displayName, ordering: ordering)
            if nameOrder == .orderedDescending {
                throw CatalogValidationError.notSorted
            }
            if nameOrder == .orderedSame && canonicalKey(a) >= canonicalKey(b) {
                throw CatalogValidationError.notSorted
            }
        }
    }
}

// MARK: - Diff 与 stale 拒绝

public struct CatalogDiff: Sendable, Equatable {
    public let fromRevision: CatalogRevision
    public let toRevision: CatalogRevision
    public let added: [AppRecord]
    public let removed: [AppRecord]
    public let moved: [AppID]                     // 重排涉及项（add/remove/reorder，10.2）
    public init(fromRevision: CatalogRevision, toRevision: CatalogRevision,
                added: [AppRecord], removed: [AppRecord], moved: [AppID]) {
        self.fromRevision = fromRevision
        self.toRevision = toRevision
        self.added = added
        self.removed = removed
        self.moved = moved
    }
}

/// diff 语义（deterministic）：
/// - `added`：仅存在于 to（保持 to 顺序）。
/// - `removed`：仅存在于 from（保持 from 顺序）。
/// - `moved`：重排涉及项 = 索引在 from→to 间变化的全部 AppID（新增、移除、重排、
///   以及移除/插入引发的位移），顺序 = to 顺序，from-only（removed）按 from 顺序补尾。
///   AppID 在 `.keepMultiInstance` 快照中可重复 → 索引取首次出现（与去重后的常规快照一致）。
public enum CatalogDiffBuilder {
    public static func diff(from: CatalogSnapshot, to: CatalogSnapshot) throws -> CatalogDiff {
        guard to.revision > from.revision else {
            throw CatalogGateError.nonMonotonic(attempted: to.revision, previous: from.revision)
        }
        let fromIDs = Set(from.records.map(\.id))
        let toIDs = Set(to.records.map(\.id))
        let added = to.records.filter { !fromIDs.contains($0.id) }
        let removed = from.records.filter { !toIDs.contains($0.id) }

        var fromIndex: [AppID: Int] = [:]
        for (i, record) in from.records.enumerated() where fromIndex[record.id] == nil {
            fromIndex[record.id] = i
        }
        var toIndex: [AppID: Int] = [:]
        for (i, record) in to.records.enumerated() where toIndex[record.id] == nil {
            toIndex[record.id] = i
        }

        var moved: [AppID] = []
        var seen = Set<AppID>()
        for record in to.records {          // to 顺序：added / reordered / 位移项
            let id = record.id
            guard !seen.contains(id) else { continue }
            if fromIndex[id] != toIndex[id] {
                moved.append(id)
                seen.insert(id)
            }
        }
        for record in from.records {        // from-only（removed）按 from 顺序补尾
            let id = record.id
            if toIndex[id] == nil && !seen.contains(id) {
                moved.append(id)
            }
        }
        return CatalogDiff(fromRevision: from.revision, toRevision: to.revision,
                           added: added, removed: removed, moved: moved)
    }
}

/// 门禁：严格递增；拒绝 stale。拒绝不改变内部状态（可继续接受更新 revision）。
public struct SnapshotGate: Sendable {
    public private(set) var current: CatalogRevision?
    public init() {}
    public mutating func accept(_ snapshot: CatalogSnapshot) throws -> CatalogSnapshot {
        guard let current else {
            self.current = snapshot.revision
            return snapshot
        }
        guard snapshot.revision > current else {
            throw CatalogGateError.staleRevision(current: current, attempted: snapshot.revision)
        }
        self.current = snapshot.revision
        return snapshot
    }
}
public enum CatalogGateError: Error, Equatable {
    case staleRevision(current: CatalogRevision?, attempted: CatalogRevision)
    case nonMonotonic(attempted: CatalogRevision, previous: CatalogRevision)
}

// MARK: - 分页计划与锚点重映射（§6.2/6.3）

public struct PagePlan: Sendable, Equatable {
    public let snapshotRevision: CatalogRevision
    public let itemsPerPage: Int
    public let itemCount: Int
    public let pageCount: Int                    // 0 记录 → 0 页（空 catalog 合法态）

    /// 内容索引（内部）：planner 构造时携带与 itemCount 等长的 records；公开 init 构造的
    /// 空记录 plan 无法索引内容（`appID(page:slot:)` 恒返回 nil——与“越界/空返回 nil”一致）。
    private let records: [AppRecord]

    public init(snapshotRevision: CatalogRevision, itemsPerPage: Int, itemCount: Int, pageCount: Int) {
        self.init(snapshotRevision: snapshotRevision, itemsPerPage: itemsPerPage,
                  itemCount: itemCount, pageCount: pageCount, records: [])
    }

    internal init(snapshotRevision: CatalogRevision, itemsPerPage: Int, itemCount: Int,
                  pageCount: Int, records: [AppRecord]) {
        self.snapshotRevision = snapshotRevision
        self.itemsPerPage = itemsPerPage
        self.itemCount = itemCount
        self.pageCount = pageCount
        self.records = records
    }

    /// page/slot → AppID；越界（负、超出 pageCount/itemsPerPage/itemCount）或空返回 nil。
    public func appID(page: Int, slot: Int) -> AppID? {
        guard page >= 0, slot >= 0, page < pageCount, slot < itemsPerPage else { return nil }
        let index = page * itemsPerPage + slot
        guard index < itemCount, index < records.count else { return nil }
        return records[index].id
    }
}

public enum AnchorOutcome: Sendable, Equatable { // 规则 1–5 顺序即判定顺序
    case located(pageIndex: Int)                 // anchor 仍存在 → 新页
    case successor(pageIndex: Int)               // 消失 → 稳定排序后继所在页
    case predecessor(pageIndex: Int)             // 无后继 → 前驱
    case clamped(pageIndex: Int)                 // 都无 → clamp 合法页
    case emptyCatalog                            // 空 catalog：UI 合法空态
}

/// 分页计划与锚点重映射（§6.2/6.3）。
/// remap 规则 6：绝不沿用旧数组 index —— remap 只接收新 snapshot + 锚点 AppID，
/// 结果完全由新快照推导；旧上下文（页/索引）不存在于签名中，结构性杜绝旧 index 泄漏。
public struct CatalogPlanner {
    public init() {}

    /// itemsPerPage 必须 > 0（接口契约）；pageCount = itemCount == 0 ? 0 : ceil(itemCount / itemsPerPage)
    /// （与 PagingSurface 默认 35 对齐：35 条 = 1 页、36 条 = 2 页）。
    public func plan(snapshot: CatalogSnapshot, itemsPerPage: Int) -> PagePlan {
        precondition(itemsPerPage > 0, "itemsPerPage 必须 > 0（接口契约）")
        let itemCount = snapshot.records.count
        let pageCount = itemCount == 0 ? 0 : (itemCount + itemsPerPage - 1) / itemsPerPage
        return PagePlan(snapshotRevision: snapshot.revision, itemsPerPage: itemsPerPage,
                        itemCount: itemCount, pageCount: pageCount, records: snapshot.records)
    }

    /// 五级降级（§6.3 规则 1–5，顺序即判定顺序）：
    /// 1. 空 catalog → `.emptyCatalog`（pageCount 0，合法空态）；
    /// 2. anchor 存在 → `.located(anchor 在新快照中的页)`；
    /// 3. anchor 消失 → `.successor(新快照稳定顺序中首个 AppID 全序大于 anchor 的记录所在页)`；
    /// 4. 无后继 → `.predecessor(最后一个 AppID 全序小于 anchor 的记录所在页)`；
    /// 5. 都无（含 anchor == nil）→ `.clamped(page 0)`（防御性兜底；非空 catalog 下正常不可达）。
    /// 后继/前驱以 AppID 全序近似（锚点不透明、无 displayName；见 AppID.anchorOrderLessThan）。
    public func remap(snapshot: CatalogSnapshot, anchor: AppID?, itemsPerPage: Int)
        -> (plan: PagePlan, outcome: AnchorOutcome) {
        let plan = plan(snapshot: snapshot, itemsPerPage: itemsPerPage)
        guard plan.itemCount > 0 else { return (plan, .emptyCatalog) }
        let records = snapshot.records
        if let anchor {
            if let index = records.firstIndex(where: { $0.id == anchor }) {
                return (plan, .located(pageIndex: index / itemsPerPage))
            }
            if let index = records.firstIndex(where: { anchor.anchorOrderLessThan($0.id) }) {
                return (plan, .successor(pageIndex: index / itemsPerPage))
            }
            if let index = records.lastIndex(where: { $0.id.anchorOrderLessThan(anchor) }) {
                return (plan, .predecessor(pageIndex: index / itemsPerPage))
            }
        }
        return (plan, .clamped(pageIndex: 0))
    }

    /// 定位 AppID 在新快照中的页；不存在/itemsPerPage <= 0 返回 nil。
    public func pageIndex(of appID: AppID, in snapshot: CatalogSnapshot, itemsPerPage: Int) -> Int? {
        guard itemsPerPage > 0,
              let index = snapshot.records.firstIndex(where: { $0.id == appID }) else { return nil }
        return index / itemsPerPage
    }

    /// = committed page 首个可见 AppID（§6.3 更新前记录）；nearPage 越界/空 catalog 返回 nil。
    public func anchorCandidate(nearPage: Int, in snapshot: CatalogSnapshot, itemsPerPage: Int) -> AppID? {
        guard itemsPerPage > 0, nearPage >= 0 else { return nil }
        let records = snapshot.records
        guard !records.isEmpty else { return nil }
        let pageCount = (records.count + itemsPerPage - 1) / itemsPerPage
        guard nearPage < pageCount else { return nil }
        let index = nearPage * itemsPerPage
        guard index < records.count else { return nil }
        return records[index].id
    }
}

// MARK: - Fake records/fixtures builder（10.2/10.3/10.4 共用；测试资源隔离）

public enum CatalogFixture {
    public static func record(id: AppID, displayName: String, bundleID: String?, url: URL,
                              icon: IconIdentity, rootPriority: Int) -> AppRecord {
        AppRecord(id: id, displayName: displayName, bundleIdentifier: bundleID,
                  canonicalURL: url.standardizedFileURL, iconIdentity: icon, sourceRootPriority: rootPriority)
    }

    /// 经 CatalogBuilder.build 构造（去重 + 排序 + 校验）。
    public static func snapshot(records: [AppRecord], revision: CatalogRevision,
                                policy: CatalogPolicy = .init()) throws -> CatalogSnapshot {
        try CatalogBuilder.build(rawRecords: records, policy: policy, revision: revision)
    }

    public static func appID(_ bundleID: String) -> AppID {
        .bundleIdentifier(bundleID)
    }

    /// 测试临时目录内安全 URL：进程级唯一子目录避免并行测试命名冲突。
    public static func tempURL(named name: String) -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppCatalogCoreFixtures", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appendingPathComponent(name)
    }
}
