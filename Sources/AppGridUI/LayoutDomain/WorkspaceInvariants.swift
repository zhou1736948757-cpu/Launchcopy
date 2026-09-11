// AppGridUI — LayoutDomain.WorkspaceInvariants + Validator（Phase 1F §3.1 10 不变量 / ADR-009）
// 实现：T-1F-A（Worker）。AccessDeclaration: NO_PRIOR_EXPOSURE。
//
// 10 不变量（Prompt §3.1）逐一具名锁定；结构性不变量（①–⑤ + 标题上限）由本校验器
// 在纯布局上可证；系统级不变量（⑥–⑩）由引擎设计保证并被专门测试锁定：
// ⑥ 纯域无任何文件/启动路径副作用（引擎入参只有布局值）；⑦ 域内不存在第二启动路径概念；
// ⑧ 失败 mutation 无半提交（返回 rejected，原布局值不变）；⑨ generation 分离（独立
// `LayoutGeneration` 类型，引擎不接触 CatalogRevision）；⑩ UI 只消费已提交布局（mutation
// 结果只含完整已提交布局；投影纯读）。
//
// 校验器检查（确定性线性扫描；禁 hash 身份）：
// ① app reference 全局至多一次（顶层 + 全部 folder 成员）；②/③ folder 不嵌套且只含 app
// （成员类型即证明，另查 folder 条目必须有记录、记录不重复）；④ 空 folder 不存在；
// ⑤ 已提交布局不允许单逻辑成员 folder（用户移出致剩 1 → 逻辑 dissolve，ADR-009 Q9）；
// 标题 ≤ 64 grapheme（`FolderTitle.maxLength`，Character 截断不劈 grapheme）。
// 顶层/folder 成员顺序原样保留：由数组构造保证，fuzz/property 测试锁定。

import Foundation

/// 10 不变量（§3.1 编号 1–10）。
public enum WorkspaceInvariant: Int, CaseIterable, Sendable {
    case uniqueAppReference = 1          // ① 同一逻辑 app reference 可见布局最多出现一次
    case noNestedFolders = 2             // ② folder 不嵌套
    case foldersContainOnlyApps = 3      // ③ folder 只含 app
    case noEmptyFolders = 4              // ④ 空 folder 不存在
    case singleMemberLogicalDissolve = 5 // ⑤ 用户主动变更后单成员 folder dissolve
    case noRealAppMutation = 6           // ⑥ 拖拽不删除/移动/修改真实 .app
    case noSecondLaunchPath = 7          // ⑦ 不创建第二条启动路径
    case noPartialCommit = 8             // ⑧ 失败 mutation 无半提交
    case separatedGenerations = 9        // ⑨ layout generation 与其余 generation 分离
    case committedLayoutOnly = 10        // ⑩ UI 只消费已提交 layout

    /// 是否可被纯布局校验器直接证明（①–⑤）。
    public var isStructurallyCheckable: Bool { rawValue <= 5 }

    /// 中性类别描述（不含任何原值）。
    public var neutralTitle: String {
        switch self {
        case .uniqueAppReference: return "unique app reference"
        case .noNestedFolders: return "no nested folders"
        case .foldersContainOnlyApps: return "folders contain apps only"
        case .noEmptyFolders: return "no empty folders"
        case .singleMemberLogicalDissolve: return "single-member logical dissolve"
        case .noRealAppMutation: return "no real app bundle mutation"
        case .noSecondLaunchPath: return "no second launch path"
        case .noPartialCommit: return "no partial commit"
        case .separatedGenerations: return "separated generations"
        case .committedLayoutOnly: return "committed-layout-only consumption"
        }
    }
}

/// 校验问题（进程内 domain 错误；不进 telemetry/日志）。
public enum WorkspaceLayoutIssue: Equatable, Sendable {
    /// 不变量①：同一 app reference 出现 ≥2 次（顶层或 folder 成员）。
    case duplicateAppReference(PersistentAppReference)
    /// 不变量①（局部）：同一 folder 内成员重复。
    case duplicateFolderMember(PersistentAppReference)
    /// 不变量④：空 folder。
    case emptyFolder(FolderID)
    /// 不变量⑤：已提交布局出现单逻辑成员 folder（应已 dissolve）。
    case singleMemberFolder(FolderID)
    /// 顶层引用同一 folder 两次 / folder 记录重复。
    case duplicateFolderRecord(FolderID)
    /// 顶层 folder 条目无对应记录（不变量②/完整性）；或记录无顶层条目（不可达 folder）。
    case folderEntryWithoutRecord(FolderID)
    case folderRecordWithoutEntry(FolderID)
    /// 标题超 64 grapheme。
    case titleExceedsGraphemeLimit(FolderID)
}

/// 校验失败（含全部问题）。
public enum LayoutValidationError: Error, Equatable {
    case invariantsViolated([WorkspaceLayoutIssue])
}

/// 纯布局校验器：`validate` 返回问题清单（空 = 通过）；`assertValid` 抛出。
public enum WorkspaceLayoutValidator {

    public static func validate(_ layout: PersistentWorkspaceLayout) -> [WorkspaceLayoutIssue] {
        var issues: [WorkspaceLayoutIssue] = []
        var seenRefKeys = Set<String>()          // 不变量①（全局唯一）
        var entryFolderIDs = Set<FolderID>()     // 顶层条目引用的 folder
        var recordFolderIDs = Set<FolderID>()    // 记录集合（按记录去重）

        for entry in layout.topLevelOrder {
            switch entry {
            case .app(let ref):
                if !seenRefKeys.insert(ref.comparisonKey).inserted {
                    issues.append(.duplicateAppReference(ref))
                }
            case .folder(let folderID):
                // 同一 folder 在顶层出现两次 → 重复条目。
                if !entryFolderIDs.insert(folderID).inserted {
                    issues.append(.duplicateFolderRecord(folderID))
                }
            }
        }

        for record in layout.folders {
            if !recordFolderIDs.insert(record.id).inserted {
                issues.append(.duplicateFolderRecord(record.id))   // 记录集合内重复
            }
            if record.members.isEmpty {
                issues.append(.emptyFolder(record.id))
            } else if record.members.count == 1 {
                issues.append(.singleMemberFolder(record.id))   // 不变量⑤
            }
            if record.title.count > FolderTitle.maxLength {
                issues.append(.titleExceedsGraphemeLimit(record.id))
            }
            var seenMembers = Set<String>()
            for member in record.members {
                if !seenMembers.insert(member.comparisonKey).inserted {
                    issues.append(.duplicateFolderMember(member))
                }
                if !seenRefKeys.insert(member.comparisonKey).inserted {
                    issues.append(.duplicateAppReference(member))   // 不变量①
                }
            }
        }

        // 完整性：顶层条目 ↔ 记录一一对应（任一方向缺失都检出）。
        for entry in layout.topLevelOrder {
            if case .folder(let folderID) = entry, !recordFolderIDs.contains(folderID) {
                issues.append(.folderEntryWithoutRecord(folderID))
            }
        }
        for record in layout.folders where !entryFolderIDs.contains(record.id) {
            issues.append(.folderRecordWithoutEntry(record.id))
        }
        return issues
    }

    public static func assertValid(_ layout: PersistentWorkspaceLayout) throws {
        let issues = validate(layout)
        guard issues.isEmpty else {
            throw LayoutValidationError.invariantsViolated(issues)
        }
    }
}
