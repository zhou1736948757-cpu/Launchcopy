# T-1D-A — 纯搜索 domain（查询 / 匹配 / 结果集）

**Worker**: worker-a（T-1D-A）
**任务**: 实现搜索的纯逻辑 domain：`AppSearchQuery`（查询值 + 可注入 `Locale` + 归一化）、`AppSearchMatcher`（仅对 `AppRecord.displayName` 做大小写/变音/宽度不敏感的字面子串匹配）、`AppSearchResultSet`（携带 `baseCatalogRevision` + `queryGeneration` + 过滤后记录 + `resultCount` + `isEmpty` 的提交单元）+ `AppSearchGeneration`（单调 latest-wins token）
**日期**: 2026-08-30
**接口契约**: PHASE1D_SEARCH_PROMPT §6（匹配语义）、§9.1（纯搜索域）、§16.1（搜索域测试）；ADR-007 §2.3（query generation 与 catalog revision 独立）、§2.6（七字段 token）；AppCatalogCore（AppRecord / CatalogSnapshot / CatalogRevision / AppID）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（亲笔声明：未读取 `/Users/mac/Projects/BuhoReverseNotes/`、`/Users/mac/Projects/LaunchBetter/`、`2026-08-25-buho-launchpad-reverse` 任何内容；仅依据本 Prompt、Apple 公开文档与本工程自身文件）

---

## 一、实现（新增 3 个源文件 + 3 个测试文件）

| 文件 | 内容 |
|---|---|
| `Sources/AppGridUI/AppSearchQuery.swift` | `AppSearchQuery`（`raw: String` + 可注入 `locale: Locale`）：`trimmed`（去头尾 `whitespacesAndNewlines`）、`normalized`（trim → case/diacritic/width folding）、`isEmpty`（空/纯空白/换行 → 无过滤）。纯 Foundation，无 AppKit/I/O。 |
| `Sources/AppGridUI/AppSearchMatcher.swift` | `AppSearchMatcher`（纯函数 `matches(_:query:)`）：空/纯空白/换行 query → 恒 true（全目录）；否则将 `displayName` 与 query 在**同一 Locale**（`query.locale`）下 folding 后做**字面 substring** 搜索（`.literal`）。只读 `displayName`；不匹配 bundleID / canonicalURL / 路径 / AppID / 图标 metadata；无拼音/首字母/模糊/编辑距离/排名。 |
| `Sources/AppGridUI/AppSearchResultSet.swift` | `AppSearchGeneration`（单调 latest-wins token，`Hashable/Comparable/Sendable`，与 `CatalogRevision` 完全独立）+ `AppSearchResultSet`（`baseCatalogRevision` + `queryGeneration` + `records`（保持快照稳定顺序）+ `resultCount` + `isEmpty` + `pageCount(itemsPerPage:)`（0 结果 = 0 页，公式与 `CatalogPlanner` 一致）+ `isCurrent(latestGeneration:latestRevision:)`（latest-wins 提交校验，旧 generation / 旧 revision 拒绝））。无 debug description 可逆向输出 AppID。 |
| `Tests/AppGridUITests/AppSearchQueryTests.swift` | 9 测试：空/纯空白/换行 query、trim、case/diacritic/width folding、固定 Locale 确定性。 |
| `Tests/AppGridUITests/AppSearchMatcherTests.swift` | 15 测试：空/纯空白/换行全目录、case/diacritic/width、substring、不匹配 bundleID/path/URL/AppID、无拼音/首字母/模糊扩展、结果顺序 = base 子序列、固定 Locale 确定性。 |
| `Tests/AppGridUITests/AppSearchResultSetTests.swift` | 9 测试：resultCount/isEmpty、0/1/35/36/70 结果分页、query generation 单调、旧 generation / 旧 catalog revision 拒绝、records 保持 base 顺序。 |

**未触碰**：`Sources/PagingCore/`（冻结）、`Sources/PagingUI/`、`Sources/PagingPrototypeApp/`、`Sources/AppGridUI/AppGridUIPageContentProvider.swift`、`AppGridSearchPresentationController.swift`、`AppGridUIState.swift`、`AppGridStatusView.swift`、`AppGridCellView.swift`、`AppGridPageView.swift`、`AppGridRefreshController.swift`、`ItemBindingToken.swift`、`Package.swift`、`Docs/`、`PROVENANCE/`、他人 test 目录。

---

## 二、验收标准逐项结果

| 验收标准（§16.1） | 结果 | 测试 |
|---|---|---|
| 空 query / 纯空白 / 换行 query 返回完整 catalog | ✅ | `testEmptyQueryMatchesAll` / `testWhitespaceQueryMatchesAll` / `testNewlineQueryMatchesAll` |
| case-insensitive | ✅ | `testCaseInsensitiveMatch` / `testCaseInsensitiveFolding` |
| diacritic-insensitive | ✅ | `testDiacriticInsensitiveMatch` / `testDiacriticInsensitiveFolding` |
| width-insensitive | ✅ | `testWidthInsensitiveMatch` / `testWidthInsensitiveFolding` |
| substring 匹配 | ✅ | `testSubstringMatch` |
| 不匹配 bundle ID / path / URL / AppID | ✅ | `testNotMatchingBundleID` / `testNotMatchingPathURL` / `testNotMatchingAppID` |
| 不做拼音 / 模糊 / 首字母扩展 | ✅ | `testNoPinyinExpansion` / `testNoInitialExpansion` / `testNoFuzzyEditDistance` |
| 结果顺序 = base snapshot 子序列 | ✅ | `testResultOrderIsBaseSubsequence` / `testRecordsPreserveBaseOrder` |
| 0/1/35/36/70 结果分页 | ✅ | `testPagingZeroOneThirtyFiveThirtySixSeventy` |
| 固定 Locale 下输出确定 | ✅ | `testDeterministicUnderFixedLocale`（query + matcher） |
| query generation 单调 | ✅ | `testQueryGenerationMonotonic` |
| 旧 generation / 旧 catalog revision 结果拒绝 | ✅ | `testOldGenerationRejected` / `testOldCatalogRevisionRejected` / `testBothAxesStaleRejected` / `testCurrentGenerationAndRevisionAccepted` |

---

## 三、验证证据

1. **`swift test --filter AppSearch`** → **33/33 全绿，0 failures**，exit 0（15 matcher + 9 query + 9 result set）。
2. **`swift build -c debug`** → **exit 0**（Build complete）。
3. **`swift build -c release`** → **exit 0**（Build complete）。
4. **全量 `swift test`** → 573 tests，**4 failures 全部位于 `Tests/PagingUITests/PagingSurfaceSearchReloadTests.swift`**（Worker C 的 PagingUI 同 revision reload seam，并发进行中，非本任务范围）。本任务 AppGridUITests 搜索套件 33/33 全绿，无回归。
5. 冲突标记 / trailing whitespace 扫描（6 个新文件）：无。
6. 隐私：query 原文/归一化文本/结果 app 名绝不进入 telemetry/log/stdout/signpost/profile/report；`AppSearchResultSet` 无 debug description 可逆向输出 AppID；不改 `PagingTelemetry` 契约。

---

## 四、偏离与说明

- **`AppSearchGeneration` 放置**：任务 packet 的 Expected/Allowed Write Scope 仅列 3 个源文件，而任务要求实现 `AppSearchGeneration`。故将其置于 `AppSearchResultSet.swift`（结果集携带 `queryGeneration` 的自然归属），未新增第 4 个源文件，保持在允许写入范围内。
- **Locale 单一来源**：`AppSearchMatcher.matches` 使用 `query.locale` 对 `displayName` 做 folding，与 query 归一化使用同一 Locale，保证一致性（可注入 Locale 经 `AppSearchQuery.locale` 注入）。
- **latest-wins 提交校验**：`isCurrent(latestGeneration:latestRevision:)` 为纯函数，供搜索控制器在 idle 边界判断"最新 generation + 最新 base revision 才可写回 UI"；旧 generation / 旧 catalog revision 任一过期即拒绝。实际"拒绝写回"的编排在 Worker B/D 控制器，本域只提供判定。
- **分页 helper**：`pageCount(itemsPerPage:)` 镜像 `CatalogPlanner.plan` 公式（0 结果 = 0 页、35 = 1 页、36 = 2 页），使 0/1/35/36/70 分页测试在纯域内可测；实际分页由 provider/planner 承担。
- **全量测试 4 failures 归属**：均为 Worker C 的 `PagingSurfaceSearchReloadTests`（并发进行中），非本任务引入；本任务不修改 PagingUI，不代为修复。

---

## 五、Reviewer Focus

- 是否只匹配 `AppRecord.displayName`（字面子串，case/diacritic/width 不敏感）✅
- 是否不匹配 bundleID / path / URL / AppID / 图标 metadata ✅
- 是否无拼音 / 首字母 / token ranking / 编辑距离 / 学习排序 ✅
- 空/纯空白/换行 query → 全目录 ✅
- 结果是否保持快照稳定顺序（不重排、不排名）✅
- `queryGeneration` 是否与 `baseCatalogRevision` 完全独立（不伪造 `CatalogRevision`、不把 query hash 塞进 revision）✅
- 是否纯 Foundation（无 AppKit / I/O / Spotlight / NSMetadataQuery）✅
- 隐私：query 原文/结果 app 名不进入 telemetry/log；无 debug description 逆向输出 AppID ✅
- 是否引入旧项目字段名/映射痕迹 ✅（中性命名）

## 六、Memory 候选

- 纯搜索域：`AppSearchQuery`（raw + 可注入 Locale + trim + case/diacritic/width folding + isEmpty）、`AppSearchMatcher`（仅对 displayName 做字面子串匹配，用 query.locale 折叠）、`AppSearchResultSet`（baseCatalogRevision + queryGeneration + records + resultCount + isEmpty + pageCount + isCurrent）、`AppSearchGeneration`（单调 latest-wins token，与 CatalogRevision 独立）。
- latest-wins 提交校验：`isCurrent(latestGeneration:latestRevision:)` 要求 generation 与 base revision 均最新才可写回 UI；旧 generation / 旧 catalog revision 拒绝。
- 分页公式与 `CatalogPlanner` 一致：0 结果 = 0 页、35 = 1 页、36 = 2 页。
