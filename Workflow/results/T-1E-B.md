# T-1E-B — 顶层组合 provider（app + folder）+ 搜索扁平化 + 刷新不重复/不遗漏/不伪造

**Worker**: worker-b（T-1E-B）
**任务**: 扩展 `AppGridUIPageContentProvider` 呈现中性顶层组合 `[TopLevelEntry]`（app+folder，ADR-008 §2.1）；搜索扁平化为 app-only；页数/anchor/idle-commit/latest-wins 正确；刷新不重复/不遗漏/不伪造 `CatalogRevision`；移除 `AppGridSearchPresentationController` 死回调 `onStateChange`。
**日期**: 2026-08-30
**接口契约**: `Workflow/tasks/T-1E-B.md`；ADR-008（§2.1 统一顶层组合、§2.4 单成员解散、§2.5 folder-lab）；Phase 1E 提示
**AccessDeclaration: NO_PRIOR_EXPOSURE**（亲笔声明：未读取 `BuhoReverseNotes` / `LaunchBetter` / `2026-08-25-buho-launchpad-reverse` 任何内容；仅依据本任务包、ADR-008、Apple 公开文档与本工程自身文件）

---

## 一、实现（修改 2 个源文件 + 新增 2 个测试文件）

| 文件 | 内容 |
|---|---|
| `Sources/AppGridUI/AppGridUIPageContentProvider.swift`（修改） | 呈现类型从 `[AppRecord]` 扩展为**顶层组合** `[TopLevelEntry]`（app+folder，ADR-008 §2.1）：新增 `presentationEntries`（已提交组合）、`servedFolderSnapshot`/`pendingFolderSnapshot`（folder 快照 latest-wins）、`receiveFolderSnapshot`/`discardPendingFolderSnapshot`/`hasPendingFolderSnapshot`；`servedPageCount` 由组合条目数推导（每个 folder = 一个槽位，0 条目 = 0 页，用实例 `itemsPerPage`）；`content(for:)` 切片组合（folder → `AnyHashable(FolderID)` + 标题）；`applyPending` 原子提交 catalog + folder（folder 经 `FolderMembership.rebase` 收缩并分配新 generation）；`topLevelAnchorCandidate`/`topLevelPageIndex`（稳定顶层条目身份 app AppID 或 folder FolderID）；`AppGridPresentationUpdate` 新增 `topLevelAnchor` 字段（保留 `anchor: AppID?` 向后兼容）；五级降级 remap（app-only 委托 `CatalogPlanner` 精确既有行为；混合组合用组合感知 remap）；搜索扁平化：非空 query → app-only（成员扁平化），空 query → 恢复完整顶层组合 |
| `Sources/AppGridUI/AppGridSearchPresentationController.swift`（修改） | 移除死回调 `onStateChange`（无设置方、无调用方；记录为 Phase 1E 决策，非未记录修复）。无其他行为变化 |
| `Tests/AppGridUITests/TopLevelCompositionTests.swift`（新增） | 15 测试：空查询 apps+folders、页数由组合条目数推导、folder 一个槽位、topLevelAnchorCandidate/topLevelPageIndex、idle 原子提交 catalog+folder、folder latest-wins、applyPending 无 pending 无操作、刷新 no-repeat/no-miss/no-forge、folder generation 独立于 CatalogRevision、单成员解散、刷新删成员/解散/空移除、混合组合 folder anchor remap located |
| `Tests/AppGridUITests/FolderSearchFlatteningTests.swift`（新增） | 5 测试：搜索扁平化为 app-only、搜索只按 app 显示名过滤（绝不按 folder 标题）、退出搜索恢复完整顶层组合、搜索激活页数由扁平化 app 数推导、搜索 content 为 app-only |

**未触碰（冻结树）**：`Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、`Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`、`Package.swift`、`Sources/PagingPrototypeApp/AppLaunchController.swift`、`Sources/AppGridUI/AppGridUIState.swift`（无需改动）。无 git 操作。

---

## 二、验收标准逐项结果

| 验收标准 | 结果 | 测试 |
|---|---|---|
| 空查询显示 apps+folders | ✅ | `testEmptyQueryShowsAppsAndFolders` |
| 搜索扁平化为 app-only | ✅ | `testSearchFlattensToAppOnly` / `testSearchContentIsAppOnly` |
| 搜索只按 app 显示名过滤（绝不按 folder 标题） | ✅ | `testSearchFiltersByAppNameNotFolderTitle` |
| 退出搜索恢复完整顶层组合 | ✅ | `testExitingSearchRestoresComposition` |
| 页数由顶层组合条目数推导（folder = 一个槽位） | ✅ | `testPageCountFromTopLevelEntries` / `testFolderIsOneSlot` / `testSearchResultAppOnlyPageCount` |
| anchor/pageIndex 作用于顶层组合（app AppID 或 folder FolderID） | ✅ | `testTopLevelAnchorCandidate` / `testTopLevelPageIndex` / `testRemapLocatedForFolderAnchor` |
| idle 原子提交（catalog + folder） | ✅ | `testIdleCommitAtomicCatalogAndFolder` |
| folder latest-wins | ✅ | `testFolderLatestWins` |
| 刷新不重复 / 不遗漏 / 不伪造 CatalogRevision | ✅ | `testRefreshNoRepeat` / `testRefreshNoMiss` / `testRefreshNoForge` |
| folder generation 独立于 CatalogRevision（不 mint/forge） | ✅ | `testFolderGenerationIndependentOfCatalogRevision` |
| 单成员解散 / 刷新删成员 / 空移除 | ✅ | `testSingleMemberFolderDissolves` / `testRefreshRemovesDeletedMembersAndDissolves` |
| 移除死 `onStateChange`（记录决策） | ✅ | 编译通过 + 全量测试无回归（无设置方/调用方） |
| 既有 Phase1B/1D provider 测试保持通过（行为保留） | ✅ | 全量 709/709 全绿（含既有 provider/search/refresh 测试） |
| 隐私红线干净 | ✅ | 无 telemetry/JSONL/stdout/signpost/profile/report 输出；仅中性计数 |

---

## 三、验证证据

1. **`swift test`（全量）** → **709/709 全绿，0 failures**，exit 0。基线 660 + 本任务新增 20（TopLevelComposition 15 + FolderSearchFlattening 5）= 680；另有并行 T-1E-C 新增测试计入 709。既有 Phase1B/1D provider/search/refresh 测试全部保持通过。
2. **`swift build -c debug`** → **exit 0**（AppGridUI 编译通过）。
3. **`swift build -c release`** → **exit 0**。
4. **冻结树未变**：mtime 检查确认本 Worker 未写任何冻结文件。本 Worker 全部写入均在 `Sources/AppGridUI/`（`AppGridUIPageContentProvider.swift` / `AppGridSearchPresentationController.swift`）与 `Tests/AppGridUITests/`（2 个新测试文件）与 `Workflow/results/T-1E-B.md`。冻结树（PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/PagingUI/Package.swift/AppLaunchController.swift）mtime 均早于本任务开始，未变。
5. **隐私**：本任务代码无任何 telemetry/JSONL/stdout/signpost/profile/report 输出；folder 标题/成员/身份原值与图标数据仅用于 UI 呈现（`content(for:)` 的 `PagingPageContentItem.title`/`identity`），绝不进入遥测/日志。仅中性计数（`folderCount`/`memberCount`/`FolderGeneration`）。

---

## 四、偏离与说明

- **`commitPendingSearchResult` 空 query 语义**：任务要求"退出搜索恢复完整顶层组合"。实现为：非空 query → app-only（成员扁平化）；空 query（`query?.isEmpty ?? true`）→ 从 `servedSnapshot` + `servedFolderSnapshot` 重建完整顶层组合（apps + folders）。既有 Phase1B/1D 测试（空 query = base records）在无 folder 时行为不变（组合 = 全部 app 条目）。
- **混合组合 remap 的身份全序**：app-only 组合委托 `CatalogPlanner.remap`（精确既有行为，含 AppID 全序）。混合组合用组合感知 remap：folder 在 app 前，同类按 `hashValue` 稳定序（运行内确定）。后继/前驱降级路径在混合组合下极少命中；新测试不依赖混合组合的具体后继/前驱顺序。
- **`PagePlan` 构造**：`PagePlan` 的 internal init（带 records）在 AppCatalogCore 模块内，AppGridUI 不可调用。用 public init `PagePlan(snapshotRevision:itemsPerPage:itemCount:pageCount:)` 构造（records=[]，`appID(page:slot:)` 恒 nil——无消费者使用，已验证）。
- **`presentationRecords` 保留为 `[AppRecord]`**：冻结消费者（`AppDelegate`/`AppSearchController`）据此构建 `CatalogSnapshot` 供 `AppGridFocusLayout.build`。新增 `presentationEntries` 为已提交组合；`presentationRecords` 为其 app-only 投影。
- **`AppGridPresentationUpdate` 新增 `topLevelAnchor`**：保留 `anchor: AppID?` 向后兼容（= 顶层 anchor 的 appID 投影；首项为 folder → nil）。仅 `applyPending` 构造，测试只读。
- **folder generation**：`rebaseFolder` 从 `servedFolderSnapshot?.generation ?? .zero` 递增分配新 generation（单调、独立于 `CatalogRevision`）；folder 层绝不 mint/forge `CatalogRevision`。

---

## 五、Reviewer Focus

- 顶层组合 `[TopLevelEntry]` 是否按 ADR-008 §2.1 呈现（app + folder，folder = 一个槽位）✅
- 搜索扁平化为 app-only、退出搜索恢复完整组合、只按 app 显示名过滤 ✅
- 页数由组合条目数推导（0 条目 = 0 页；用实例 itemsPerPage）✅
- anchor/pageIndex 作用于组合（app AppID 或 folder FolderID）；五级降级 remap ✅
- idle 原子提交（catalog + folder）；folder latest-wins ✅
- 刷新不重复/不遗漏/不伪造 CatalogRevision；folder generation 独立 ✅
- 死 `onStateChange` 移除（记录决策，无行为变化）✅
- 既有 Phase1B/1D provider 测试保持通过 ✅
- 隐私：folder 原值未进 telemetry/JSONL/stdout/signpost/profile/report ✅
- 冻结树未变 ✅

## 六、Memory 候选

- 顶层组合 `[TopLevelEntry]`（app+folder）由 `AppGridUIPageContentProvider` 呈现；`presentationEntries` 为已提交组合，`presentationRecords` 为其 app-only 投影（冻结消费者据此构建 CatalogSnapshot）。
- 搜索扁平化：非空 query → app-only（成员扁平化）；空 query → 从 servedSnapshot + servedFolderSnapshot 重建完整顶层组合。
- folder 快照 latest-wins（`pendingFolderSnapshot`），idle 边界随 catalog 原子提交；`FolderMembership.rebase` 收缩（删成员/空移除/单成员解散）并分配新 generation（独立于 CatalogRevision，绝不 mint/forge）。
- 五级降级 remap：app-only 委托 `CatalogPlanner`；混合组合用组合感知 remap（folder 在 app 前，同类按 hashValue 稳定序）。
- `AppGridSearchPresentationController.onStateChange` 死回调已移除（Phase 1E 记录决策）。
