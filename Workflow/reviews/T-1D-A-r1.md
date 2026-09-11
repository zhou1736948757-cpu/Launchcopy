# Review: T-1D-A — 纯搜索 domain（查询 / 匹配 / 结果集）

- **Reviewer**: independent reviewer (chef-worker-reviewer-workflow)
- **Task**: T-1D-A (Phase 1D local app-name search — pure search domain)
- **Date**: 2026-08-30
- **Verdict**: **PASS**

---

## 一、Verdict

**PASS** — 实现与接口契约（PHASE1D_SEARCH_PROMPT §6.1 / §6.2 / §9.1 / §16.1、ADR-007 §2.3/§2.6）一致；33 个搜索域测试全绿；全量 620 测试 0 失败；debug/release 构建均 exit 0；隐私红线与冻结树约束全部满足。

---

## 二、Findings

### BLOCKER
- 无。

### MAJOR
- 无。

### MINOR
- 无。

### QUESTION
- **Q1（非阻塞）**：Worker 结果报告全量测试为「573 tests / 4 failures（Worker C 的 `PagingSurfaceSearchReloadTests`，并发进行中）」。Reviewer 实测全量 `swift test` 为 **620 tests / 0 failures**。差异为正向：Worker C 的 reload seam 测试现已通过，非 T-1D-A 引入、亦非 T-1D-A 修复。仅记录，不构成问题。

---

## 三、逐项核对（T-1D-A scope）

### AppSearchQuery（`Sources/AppGridUI/AppSearchQuery.swift`）
- ✅ `raw: String` + 可注入 `locale: Locale`（默认 `.current`）。
- ✅ `trimmed` = `raw.trimmingCharacters(in: .whitespacesAndNewlines)`。
- ✅ `normalized` = trim → `folding([.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale:)`。
- ✅ `isEmpty` = `trimmed.isEmpty`（空/纯空白/换行 → 无过滤）。
- ✅ 纯 Foundation 值类型，无 AppKit / I/O / 持久化。

### AppSearchMatcher（`Sources/AppGridUI/AppSearchMatcher.swift`）
- ✅ `matches(_:query:)`：空/纯空白/换行 query → 恒 true（全目录）。
- ✅ 仅对 `displayName` 做字面子串匹配：`normalizedName.range(of: normalizedQuery, options: [.literal], locale: query.locale)`。
- ✅ 折叠使用 `query.locale`，与 query 归一化同一 Locale，保证一致性。
- ✅ 只读 `displayName`；不读 bundleIdentifier / canonicalURL / AppID / 图标 metadata。
- ✅ 无拼音 / 首字母 / token ranking / 编辑距离 / 学习排序。

### AppSearchResultSet / AppSearchGeneration（`Sources/AppGridUI/AppSearchResultSet.swift`）
- ✅ `AppSearchGeneration`：单调 latest-wins token（`UInt64`，`Hashable/Comparable/Sendable`），与 `CatalogRevision` 完全独立；不伪造 revision、不把 query hash 塞进 revision。
- ✅ `AppSearchResultSet` 携带 `baseCatalogRevision` + `queryGeneration` + `records`（保持快照稳定顺序）+ `resultCount` + `isEmpty`。
- ✅ `pageCount(itemsPerPage:)` = `resultCount == 0 ? 0 : (resultCount + itemsPerPage - 1) / itemsPerPage`，与 `CatalogPlanner`（`AppGridUIPageContentProvider.swift:170`）公式逐字一致；0/1/35/36/70 分页正确。
- ✅ `isCurrent(latestGeneration:latestRevision:)`：generation 与 base revision 均最新才 true；任一轴过期拒绝。
- ✅ 无 debug description / CustomStringConvertible 可逆向输出 AppID。

### 测试（`Tests/AppGridUITests/`）
- ✅ `AppSearchQueryTests` = **9**（空/纯空白/换行、trim、case/diacritic/width folding、固定 Locale 确定性）。
- ✅ `AppSearchMatcherTests` = **15**（空/纯空白/换行全目录、case/diacritic/width、substring、不匹配 bundleID/path/URL/AppID、无拼音/首字母/模糊、结果顺序=base 子序列、固定 Locale 确定性）。
- ✅ `AppSearchResultSetTests` = **9**（resultCount/isEmpty、0/1/35/36/70 分页、generation 单调、旧 generation/旧 revision 拒绝、records 保持 base 顺序）。
- ✅ 合计 **33**，覆盖 §16.1 全部要求。

---

## 四、Verification Numbers（Reviewer 实测）

| 项 | 期望 | 实测 |
|---|---|---|
| `swift test --filter AppSearch`（AppGridUI 搜索域） | 33 tests / 0 failures | **33 tests / 0 failures**（Matcher 15 + Query 9 + ResultSet 9） |
| `swift test` 全量 | ≥ 620 tests / 0 failures | **620 tests / 0 failures**（`All tests` passed） |
| `swift build -c debug` | exit 0 | **exit 0**（Build complete） |
| `swift build -c release` | exit 0 | **exit 0**（Build complete） |

> 注：`--filter AppSearch` 另匹配到 Worker D 的 `AppSearchResponderTests`（PagingUITests，5 tests），非本任务范围；AppGridUI 搜索域 33 项单独确认。

---

## 五、Red Lines / 约束确认

- ✅ **无 git commit/push/tag**：仓库无任何 commit（`git log` exit 128，全部文件 untracked），无 push/tag 可能。
- ✅ **隐私**：3 个新源文件为纯 Foundation 值类型，无 `print` / `os_signpost` / `Telemetry` / `JSONEncoder` / `FileHandle` / `write`；`AppSearchResultSet` 无 debug description 可逆向输出 AppID；不改 `PagingTelemetry` 契约。query 原文/归一化文本/结果 app 名不进入任何输出面。
- ✅ **无全局 NSEvent monitor / Accessibility / Spotlight / sync I/O / 持久化**：新文件无 AppKit、无 I/O、无 Spotlight/NSMetadataQuery。
- ✅ **诊断状态**：T-1D-A 为纯搜索域，未触碰 PagingCore 诊断；`CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED` 保持。
- ✅ **不伪造 CatalogRevision**：`AppSearchGeneration` 为独立 `UInt64` token；`baseCatalogRevision` 由外部（CatalogRepository）传入，域内不 mint。

---

## 六、Forbidden Tree 确认

- ✅ 冻结树 `Sources/PagingCore/`、`Sources/PagingUI/`、`Sources/PagingPrototypeApp/`、`Package.swift` 未被 T-1D-A 修改：其 mtime（08-28/08-29）早于 3 个新文件（08-30T10:47）。
- ✅ 冻结树内无 T-1D-A 域类型（`AppSearchQuery`/`AppSearchMatcher`/`AppSearchResultSet`/`AppSearchGeneration`）的实现或写入。
- ✅ `Sources/PagingPrototypeApp/AppSearchFieldView.swift`、`AppSearchController.swift` 为 **Worker D**（T-1D-D，AppKit 搜索 UI/responder）的并发交付，非 T-1D-A 写入；其 `AppSearchController.swift:101` 引用 `AppSearchQuery(raw:)` 是跨任务消费公开域类型，属正常依赖，不构成违规。
- ✅ 新文件仅落在任务允许写入范围（3 源 + 3 测试）；未触碰 `AppGridUIPageContentProvider.swift` 等只读文件、`Package.swift`、`Docs/`、`PROVENANCE/`、他人 test 目录。

---

## 七、Deviations

- **`AppSearchGeneration` 放置**：任务 packet 的 Expected/Allowed Write Scope 仅列 3 个源文件，而任务要求实现 `AppSearchGeneration`；Worker 将其置于 `AppSearchResultSet.swift`（结果集携带 `queryGeneration` 的自然归属），未新增第 4 个源文件，保持在允许写入范围内。**可接受**，已在 Worker 结果中如实记录。
- **全量测试计数差异**：Worker 报告 573/4 failures（Worker C 并发中）；Reviewer 实测 620/0 failures。正向差异，非偏离。

---

## 八、结论

T-1D-A 纯搜索域实现正确、测试充分、约束全部满足，**PASS**。无 BLOCKER / MAJOR / MINOR 发现。
