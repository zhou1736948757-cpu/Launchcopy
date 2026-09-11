# T-1E-A — 纯文件夹/分组领域模型 + folder lab fixture + 焦点身份泛化

**Worker**: worker-a（T-1E-A）
**任务**: 实现纯（无 AppKit）文件夹/分组领域模型（`FolderID` / `FolderEntry` / `FolderSnapshot` / folder generation / 标题规范化 / 成员收缩规则 / `TopLevelEntry` / 激活分流决策 / lab fixture）+ 把 `AppGridFocusIdentity` 泛化为中性顶层条目身份（向后兼容）
**日期**: 2026-08-30
**接口契约**: `Workflow/tasks/T-1E-A.md`；ADR-008（§2.4 单成员解散、§2.5 folder-lab 分组规则）；Phase 1E 提示
**AccessDeclaration: NO_PRIOR_EXPOSURE**（亲笔声明：未读取 `BuhoReverseNotes` / `LaunchBetter` / `2026-08-25-buho-launchpad-reverse` 任何内容；仅依据本任务包、ADR-008、Apple 公开文档与本工程自身文件）

---

## 一、实现（新增 2 个源文件 + 修改 1 个源文件 + 新增 3 个测试文件）

| 文件 | 内容 |
|---|---|
| `Sources/AppGridUI/FolderDomain.swift`（新增） | 纯 Foundation 值类型，无 AppKit / I/O / 磁盘持久化 / 本机依赖：`FolderID`（UUID 承载、非名称/路径派生、`redactedDescription` 不含原文）、`FolderGeneration`（单调 latest-wins token，独立于 `CatalogRevision`，绝不 mint/forge `CatalogRevision`）、`FolderTitle`（trim / 空白回退 / 64-Character 上限 / Unicode grapheme 安全截断）、`FolderEntry` / `FolderEntryBuilder`（稳定顺序 + 去重）、`FolderSnapshot`（不可变 entries + generation）、`TopLevelEntryIdentity`（`.app(AppID)` / `.folder(FolderID)`）、`TopLevelEntry`（`.app(AppRecord)` / `.folder(FolderEntry)` + `identity`）、`ActivationRouter` / `ActivationDecision`（`.openFolder` / `.launchApp` / `.reject`）、`FolderMembership.rebase`（成员收缩：删成员 / 空移除 / 单成员解散）、`TopLevelComposition.build`（文件夹在前 + 未分组 app 在后；单成员解散为 app 条目） |
| `Sources/AppGridUI/FolderLabFixture.swift`（新增） | `FolderLabFixture.makeGroups(from:configuration:generation:)`：默认关闭（`defaultEnabled = false`）、默认每组 35（`defaultGroupSize = 35`）、按稳定 catalog 顺序每 N 个一组、中性标题 `Group 1`…、每组全新 `FolderID`、无 I/O / 无本机依赖 / 无磁盘持久化；`groupSize ≤ 0` 防御性返回 `nil` |
| `Sources/AppGridUI/AppGridFocusIdentity.swift`（修改） | 泛化为中性条目身份：新增存储 `entryIdentity: TopLevelEntryIdentity?`；`appID` 改为**计算属性**（`entryIdentity == .app(id)` 时返回 id，folder/占位 → nil）；保留原 `appID` 构造（向后兼容）；新增 `entryIdentity` 构造。`Hashable/Equatable` 由存储属性合成，行为不变 |
| `Tests/AppGridUITests/FolderDomainTests.swift`（新增） | 15 测试：FolderID 随机/确定性/redacted、FolderGeneration、FolderTitle（trim/回退/截断/Unicode 安全）、FolderEntryBuilder 去重保序、TopLevelEntry.identity、ActivationRouter（entry/identity/nil）、rebase 成员收缩、composition 单成员解散/空移除/≥2 保留、全未分组 |
| `Tests/AppGridUITests/FolderLabFixtureTests.swift`（新增） | 5 测试：默认关闭、关闭返回 nil、开启按稳定顺序分组 + 中性标题 + 全新 FolderID + generation 透传、空 catalog 空 snapshot、非法 groupSize 返回 nil |
| `Tests/AppGridUITests/AppGridFocusIdentityGeneralizationTests.swift`（新增） | 7 测试：appID 构造向后兼容、nil 占位、entryIdentity app/folder/nil、folder 身份 appID 为 nil、Equality/Hash、folder 与 app 身份互异 |

**未触碰（冻结树）**：`Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、`Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`、`Package.swift`、`Sources/PagingPrototypeApp/AppLaunchController.swift`、`Docs/ADR-008-FOLDER-PRESENTATION.md`。无 git 操作。

---

## 二、验收标准逐项结果

| 验收标准 | 结果 | 测试 |
|---|---|---|
| 纯领域模型（无 AppKit） | ✅ | 全部（`FolderDomain.swift` 仅 import AppCatalogCore + Foundation） |
| `FolderID` 稳定、非名称/路径派生、不可还原原文 | ✅ | `testFolderIDRandomDistinct` / `testFolderIDDeterministicUUID` / `testFolderIDRedactedDescriptionHasNoRaw` |
| folder generation 独立于 `CatalogRevision`，不 mint/forge | ✅ | `testFolderGenerationZeroAndIncrement`（`FolderGeneration` 为独立类型，无 `CatalogRevision` 引用） |
| 标题规范化（trim / 空白回退 / 长度上限 / Unicode 安全） | ✅ | `testFolderTitleTrimsWhitespace` / `testFolderTitleBlankFallsBack` / `testFolderTitleTruncatesToMaxLength` / `testFolderTitleUnicodeSafeTruncation` |
| 成员规则：删成员 / 空移除 / 单成员解散 | ✅ | `testRebaseRemovesDeletedMembers` |
| 顶层组合：单成员解散为 app、空移除、≥2 保留、文件夹在前 | ✅ | `testCompositionDissolvesSingleMemberAndDropsEmpty` / `testCompositionAllUngroupedWhenNoFolders` |
| 激活分流决策（folder→openFolder / app→launchApp / nil→reject） | ✅ | `testActivationRouterDecidesByEntry` / `testActivationRouterDecidesByIdentity` |
| folder-lab 分组规则（稳定顺序 / 前 N / 中性标题 / 默认 off / 无 I/O） | ✅ | `testDefaultDisabled` / `testDisabledReturnsNil` / `testEnabledGroupsByStableOrder` / `testEnabledEmptyCatalogReturnsEmptySnapshot` |
| 焦点身份泛化为中性条目身份且向后兼容 | ✅ | `testAppIDInitBackwardCompatible` / `testEntryIdentityAppInit` / `testEntryIdentityFolderInit` / `testEntryIdentityNilPlaceholder` / `testEqualityAndHash` / `testFolderIdentityDistinctFromAppIdentity` |
| 隐私：folder 原值不进 telemetry/JSONL/stdout/signpost/profile/report | ✅ | 领域模型无任何 telemetry 调用；仅中性计数（`folderCount` / `memberCount` / `ActivationDecision` 枚举）；`FolderID.redactedDescription` 不含原文 |

---

## 三、验证证据

1. **`swift build -c debug`** → **exit 0**（AppGridUI 编译通过，零警告）。
2. **`swift build -c release`** → **exit 0**。
3. **`swift test`（全量）** → **660/660 全绿，0 failures**，exit 0。基线 633 + 新增 27 = 660，无回归。
4. **冻结树未变**：mtime 检查确认本 Worker 未写任何冻结文件。本 Worker 全部写入均在 `Sources/AppGridUI/`（`FolderDomain.swift` / `FolderLabFixture.swift` / `AppGridFocusIdentity.swift`）与 `Tests/AppGridUITests/`（3 个新测试文件），时间戳 ≥ 16:12:03。冻结树中唯一近期 mtime 文件 `Sources/PagingUI/PagingFrameDriver.swift`（15:15:30）与 `Sources/PagingPrototypeApp/AppDelegate.swift` 均早于/非本 Worker 写入，来自并发 Worker，非本任务改动。
5. **隐私**：领域模型不记录 app 名 / bundle ID 原文 / 路径 / URL / 图标数据 / folder 标题；`FolderID` 不透明且 `redactedDescription` 为 `FolderID(<redacted>)`。

---

## 四、偏离与说明

- **`FolderLabFixture` 非法 groupSize 处理**：任务包未规定 `groupSize ≤ 0` 行为。采用**防御性返回 `nil`**（而非 `precondition` 崩溃），使 demo 入口在非法配置下安全降级且可测试（`testInvalidGroupSizeReturnsNil`）。`groupSize > 0` 为正常前置条件。
- **`FolderTitle` 空白回退**：任务包要求"空白标题回退（中性，如 `Group N`）"。回退字符串由调用方提供（`normalized(_:fallback:)`），lab fixture 传 `Group N`；领域层不硬编码具体回退文案，保持中性。
- **`TopLevelComposition.build` 顺序**：文件夹在前（snapshot 顺序）、未分组 app 在后（catalog 稳定顺序）。单成员解散成员进入未分组 app 区（不产生 folder 条目），与 ADR-008 §2.4 一致。
- **`AppGridFocusIdentity` 泛化**：`appID` 由存储 `let` 改为**计算属性**（派生自 `entryIdentity`）。所有既有调用点（`AppGridFocusLayout` / `AppGridFocusNavigator` / `KeyboardFocusController` / `KeyboardLaunchAdapter` / `AppSearchController` / 既有测试）读 `.appID` 与用 `appID:` 构造，行为不变；`Hashable/Equatable` 由存储属性合成，语义不变。folder 身份下 `appID == nil`，app 启动路径的 `as? AppID` 拒绝它（ADR-008 统一激活分流）。
- **未触碰** `AppGridUIPageContentProvider.swift`（本阶段由并发 Worker 处理，非本任务范围）。

---

## 五、Reviewer Focus

- 领域模型是否纯（无 AppKit / I/O / 磁盘持久化 / 本机依赖）✅
- `FolderID` 是否非名称/路径派生、不可还原原文 ✅
- folder generation 是否独立于 `CatalogRevision`（未 mint/forge）✅
- 单成员解散 / 空移除 / ≥2 保留是否按 ADR-008 §2.4 实现并测试 ✅
- folder-lab 分组是否默认 off、稳定顺序、中性标题、无 I/O ✅
- 焦点身份泛化是否向后兼容（appID 计算属性 + appID 构造保留）✅
- 隐私：folder 原值是否未进 telemetry/JSONL/stdout/signpost/profile/report ✅
- 冻结树是否未变 ✅

## 六、Memory 候选

- 单成员文件夹策略 = **解散**（ADR-008 §2.4）：folder 条目仅 ≥2 成员存在；单成员解散为顶层 app 条目；空文件夹移除。`FolderMembership.rebase` 与 `TopLevelComposition.build` 实现并测试。
- folder generation 为独立单调 token（`FolderGeneration`），与 `CatalogRevision` 完全独立，绝不 mint/forge `CatalogRevision`。
- `AppGridFocusIdentity` 已泛化为中性条目身份：存储 `entryIdentity: TopLevelEntryIdentity?`，`appID` 为计算属性（folder/占位 → nil），appID 构造保留向后兼容。
- folder-lab 分组（ADR-008 §2.5）：稳定 catalog 顺序前 N 一组、中性标题 `Group N`、默认 off、无 I/O / 无本机依赖 / 无磁盘持久化。
