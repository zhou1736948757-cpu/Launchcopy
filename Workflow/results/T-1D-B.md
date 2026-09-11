# T-1D-B — 搜索 presentation 层（provider base/presentation records + 搜索呈现控制器 + 无结果中性态）

**Worker**: worker-b（T-1D-B）
**任务**: 实现搜索的 presentation 层：`AppGridSearchPresentationController`（拥有查询代 latest-wins token，接收查询变化与 catalog 快照，计算过滤结果集，驱动 provider 的 presentation records，idle 边界提交）+ 扩展 `AppGridUIPageContentProvider` 持有 `baseSnapshot` + `presentationRecords`（`servedRevision` 保持 `baseSnapshot.revision.value`，绝不 mint 假 revision）+ 无结果中性态（`AppGridUIState.noResults` / `AppGridStatusView` 渲染）。
**日期**: 2026-08-30
**接口契约**: PHASE1D_SEARCH_PROMPT §9.3（结果呈现）、§10（UI 状态与优先级）、§16.2（provider/presentation 测试）；ADR-007 §2.2（presentation records 单 owner）、§2.3（query generation 与 catalog revision 独立）、§2.4（busy pending vs catalog refresh 优先级）、§2.5（anchor/focus/pageCount-shrink）；T-1D-A（AppSearchQuery/Matcher/ResultSet 只读）；T-1D-C（PagingSurface.reloadCurrentPresentation 窄 seam 只读）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（亲笔声明：未读取 `/Users/mac/Projects/BuhoReverseNotes/`、`/Users/mac/Projects/LaunchBetter/`、`2026-08-25-buho-launchpad-reverse` 任何内容；仅依据本 Prompt、Apple 公开文档与本工程自身文件）

---

## 一、实现（扩展 2 个源文件 + 新增 1 个源文件 + 新增 2 个测试文件）

| 文件 | 内容 |
|---|---|
| `Sources/AppGridUI/AppGridUIPageContentProvider.swift`（扩展） | 新增 `baseSnapshot`（= `servedSnapshot` 别名，完整目录）、`presentationRecords`（已提交呈现记录；空查询 → base records）、`activeQuery`（当前已提交查询）、`pendingSearchResult`（同 revision latest query result）+ `hasPendingSearchResult`。`servedPageCount` 改为基于 `presentationRecords`（0 结果 = 0 页）。`content(for:)` 切片 `presentationRecords`（只命中已提交呈现，不读 pending）。`applyPending` 提交新 base 时把 `presentationRecords` 重置为 base records、清空 `activeQuery`/`pendingSearchResult`（控制器在新 base 上重跑查询）。`anchorCandidate`/`pageIndex(of:)` 改为基于 `presentationRecords`（搜索激活时锚点/定位反映结果集）。新增 `stageSearchResult` / `discardPendingSearchResult` / `commitPendingSearchResult(query:)`（latest-wins 双轴：仅当结果 base revision 与当前 base 一致才提交）。 |
| `Sources/AppGridUI/AppGridSearchPresentationController.swift`（新） | `@MainActor` 搜索呈现编排器：拥有 `latestGeneration`（查询代，与 `baseCatalogRevision` 完全独立）+ `currentQuery`；`updateQuery(_:)` 递增查询代、用 T-1D-A matcher 计算过滤结果集（空/纯空白/换行 query → base records）、`stageSearchResult`；`receive(_:)` 转发 provider pendingCatalogSnapshot；`applyPendingAtIdleBoundary(currentPage:)` idle 边界提交（catalog refresh 优先 → 新 base 上重跑当前查询 → 提交搜索结果；否则提交 pendingSearchResult）；`uiState` 推导（无 base → .loading；base 空 → .empty；base 非空 + active 非空 query + 0 结果 → .noResults；否则 .ready）；回调 `onPresentationUpdate` / `onSearchResultCommitted`（装配层接 `surface.reloadCurrentPresentation()`）/ `onStateChange`。 |
| `Sources/AppGridUI/AppGridUIState.swift`（扩展） | 新增 `.noResults` 中性态（accessibilityDescription = "No applications match the search"，不含 query 原文；isBusy = false）。不改既有 5 态语义。 |
| `Sources/AppGridUI/AppGridStatusView.swift` | **无需代码改动**：视图数据驱动（`state.accessibilityDescription` / `state.isBusy` 计算属性），`.noResults` 自动正确渲染（中性文本、无 spinner）。新增测试覆盖其渲染。 |
| `Tests/AppGridUITests/AppGridUIPageContentProviderSearchPresentationTests.swift`（新） | 11 测试：空 query = base records；非空 query = filtered records；servedRevision 不因 query 变化（不 mint 假 revision）；page count 由 result count 推导（70→2、1→1、0→0）；content 只命中已提交 result（pending 不读）；pending search 不泄露到当前手势页；快速 query latest-wins；旧 base revision 结果拒绝（latest-wins 双轴）；anchor 保留/降级；base 空 vs 无搜索结果区分。 |
| `Tests/AppGridUITests/AppGridSearchPresentationControllerTests.swift`（新） | 9 测试：updateQuery 过滤结果集（保持 base 顺序）；空 query = base records；查询代单调；idle 边界提交搜索结果（onSearchResultCommitted 触发、servedRevision 保持 base）；idle 边界无 pending 无操作；catalog refresh 重跑 query（新 base 上）；catalog refresh 取代旧同 revision query 结果；uiState 区分 loading/empty/ready/noResults；noResults 状态视图渲染（中性文本、无 spinner、不含 query 原文）。 |

**未触碰**：`Sources/PagingCore/`（冻结）、`Sources/PagingUI/`（含 `PagingSurface.swift`，Worker C 所有）、`Sources/PagingPrototypeApp/`（含 `AppLaunchController.swift`）、`Sources/MacAppCatalog/`、`Sources/AppCatalogCore/`、`Sources/AppIconPipeline/`、`Sources/AppGridUI/AppSearchQuery.swift` / `AppSearchMatcher.swift` / `AppSearchResultSet.swift`（T-1D-A 只读）、`AppGridCellView.swift` / `AppGridPageView.swift` / `AppGridRefreshController.swift` / `ItemBindingToken.swift`（只读）、`Package.swift`、`Docs/`、`PROVENANCE/`、他人 test 目录。

---

## 二、验收标准逐项结果（§16.2 provider/presentation）

| 验收标准 | 结果 | 测试 |
|---|---|---|
| 空 query = base records | ✅ | `testEmptyQueryPresentsBaseRecords` / `testEmptyQueryStagesBaseRecords` |
| non-empty query = filtered records | ✅ | `testNonEmptyQueryPresentsFilteredRecords` / `testUpdateQueryStagesFilteredResult` |
| `servedRevision` 不因 query 变化 | ✅ | `testServedRevisionUnchangedByQuery` / `testIdleBoundaryCommitsSearchResult` |
| page count 基于 result count | ✅ | `testPageCountFromResultCount` |
| content 只命中已提交 result | ✅ | `testContentOnlyHitsCommittedResult` |
| pending search 不泄露到当前手势页 | ✅ | `testPendingSearchNotLeakedToCurrentGesturePage` |
| query 快速变化 latest-wins | ✅ | `testRapidQueryLatestWins` / `testQueryGenerationMonotonic` |
| catalog refresh + active query 重跑 | ✅ | `testCatalogRefreshRerunsQueryOnNewBase` |
| anchor 保留/降级 | ✅ | `testAnchorPreservedWhenStillInResults` / `testAnchorDegradesWhenRemovedFromResults` |
| base catalog empty 与 no search results 状态区分 | ✅ | `testBaseEmptyVsNoSearchResultsDistinguished` / `testUIStateDistinguishesEmptyAndNoResults` |

---

## 三、验证证据

1. **`swift test --filter SearchPresentation`** → **20/20 全绿，0 failures**，exit 0（9 controller + 11 provider）。
2. **`swift test --filter AppGridUI`** → **130/130 全绿，0 failures**（含既有 provider/status/refresh 套件，无回归）。
3. **全量 `swift test`** → **593 tests，0 failures**（含 Worker C 的 `PagingSurfaceSearchReloadTests` 14 测试，全绿）。
4. **`swift build -c debug`** → **exit 0**（Build complete）。
5. **`swift build -c release`** → **exit 0**（Build complete）。
6. 冲突标记 / trailing whitespace 扫描（5 个文件）：无。
7. 隐私：query 原文/归一化文本/结果 app 名绝不进入 telemetry/log/stdout/signpost/profile/report；`AppGridUIState.noResults` 描述文本中性（不含 query 原文）；不改 `PagingTelemetry` 契约。

---

## 四、偏离与说明

- **测试文件名**：任务 packet 列 `AppGridUIPageContentProviderSearchTests.swift`，但主任务 Prompt 的写范围是 `Tests/AppGridUITests/*SearchPresentation*.swift`（NEW），且验证命令为 `swift test --filter SearchPresentation`。为同时满足 glob 与 filter（两个测试类名均含 "SearchPresentation"），命名 `AppGridUIPageContentProviderSearchPresentationTests.swift` + `AppGridSearchPresentationControllerTests.swift`。属命名偏离，无功能影响。
- **`AppGridStatusView.swift` 未改动**：任务列其为写范围（"extend"），但该视图数据驱动（`state.accessibilityDescription` / `state.isBusy` 计算属性），`.noResults` 自动正确渲染，无需代码改动；新增测试覆盖其 noResults 渲染（中性文本、无 spinner、不含 query 原文）。
- **`servedSnapshot` 保留为存储属性**：为不破坏既有测试（大量读取 `provider.servedSnapshot`），保留 `servedSnapshot` 为已提交 base snapshot 存储属性，`baseSnapshot` 为其计算别名（§9.3 语义一致）。
- **`anchorCandidate`/`pageIndex(of:)` 基于 presentationRecords**：搜索激活时锚点/定位反映结果集（ADR-007 §2.5：anchor = 当前可见/聚焦 AppID，保留/降级镜像 `CatalogPlanner.remap`）。构造轻量 `CatalogSnapshot(revision:records:)` 复用 planner（值类型，零 I/O）。
- **`commitPendingSearchResult` 双轴校验**：provider 与控制器均校验 `result.baseCatalogRevision == servedSnapshot?.revision`（latest-wins 双轴：旧 generation / 旧 catalog revision 拒绝），防御性冗余。
- **诊断状态**：保持 `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`；timer tolerance 8.333ms 未改。

---

## 五、Reviewer Focus

- `servedRevision` 是否保持 `baseSnapshot.revision.value`（不因 query 变化、不 mint 假 revision）✅
- `servedPageCount` 是否基于 `presentationRecords`（0 结果 = 0 页）✅
- `content(for:)` 是否只命中已提交呈现（切片 presentationRecords，不读 pending）✅
- 空 query 是否将 presentationRecords 恢复为 base records ✅
- catalog refresh commit 后是否在新 base 上重跑当前查询 ✅
- 查询代是否与 baseCatalogRevision 完全独立（不伪造 CatalogRevision）✅
- idle 边界提交是否镜像 pendingLatestSnapshot 纪律（catalog refresh 优先，同 revision 搜索结果 latest-wins）✅
- 无结果中性态是否区分 base 空（.empty）与无搜索结果（.noResults），文本不含 query 原文 ✅
- 是否引入旧项目字段名/映射痕迹 ✅（中性命名）
- 隐私：query 原文/结果 app 名不进入 telemetry/log；无 debug description 逆向输出 AppID ✅

## 六、Memory 候选

- provider 扩展：`baseSnapshot`（= servedSnapshot 别名）+ `presentationRecords`（已提交呈现记录）+ `activeQuery` + `pendingSearchResult`；`servedPageCount` 基于 presentationRecords（0 结果 = 0 页）；`content(for:)` 切片 presentationRecords；`applyPending` 提交新 base 时重置 presentationRecords 为 base records；`stageSearchResult`/`discardPendingSearchResult`/`commitPendingSearchResult(query:)`（latest-wins 双轴）。
- 控制器：`AppGridSearchPresentationController`（@MainActor）拥有 `latestGeneration`（查询代，与 baseCatalogRevision 独立）+ `currentQuery`；`updateQuery` 递增代 + matcher 过滤 + stage；`applyPendingAtIdleBoundary` idle 边界提交（catalog refresh 优先 → 新 base 重跑 query → 提交搜索结果）；`uiState` 推导（loading/empty/noResults/ready）。
- `AppGridUIState.noResults`：中性描述 "No applications match the search"，isBusy = false，不含 query 原文。
