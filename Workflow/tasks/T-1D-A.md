# Task Packet: T-1D-A

- **Task ID**: T-1D-A
- **Role**: Worker A (fresh context — 不继承含逆向材料的旧会话上下文)
- **Phase**: 1D — 纯搜索 domain（查询 / 匹配 / 结果集）
- **Prompt**: `Docs/PHASE1D_SEARCH_PROMPT.md` §15 Worker A

## Objective

实现搜索的**纯逻辑 domain**：`AppSearchQuery`（查询值 + 可注入 `Locale` + 归一化）、`AppSearchMatcher`（仅对 `AppRecord.displayName` 做大小写/变音/宽度不敏感的**字面子串**匹配）、`AppSearchResultSet`（携带 `baseCatalogRevision` + `queryGeneration` + 过滤后记录 + 计数 + isEmpty 的提交单元）。全部为纯逻辑，不依赖 AppKit，可单测。

## Dependencies

- **无**（纯逻辑；只读现有类型 `AppRecord`、`CatalogSnapshot`、`CatalogRevision`、`AppID`）。

## Context

**Fresh Context 要求（来源纪律）**：此 Worker 使用不继承旧逆向上下文的 fresh context。只接收：本 Prompt、Apple 官方公开文档、新工程自身文件。**不得读取**：`/Users/mac/Projects/BuhoReverseNotes/`（全部）、`/Users/mac/Projects/LaunchBetter/`（全部）、`2026-08-25-buho-launchpad-reverse`。误触 → 立即 `PROVENANCE/CONTAMINATION_LOG.md` + `BLOCKED_FOR_REVIEW`。

**关键既有类型（只读）**：
- `AppRecord`（`AppCatalogCore`）：`id: AppID`、`displayName: String`、`bundleIdentifier: String?`、`canonicalURL: URL`、`iconIdentity: IconIdentity`、`sourceRootPriority: Int`。**只匹配 `displayName`**。
- `CatalogSnapshot`：`revision: CatalogRevision`、`records: [AppRecord]`（已稳定排序去重）。
- `CatalogRevision`：`value: UInt64`、`zero`、`incremented()`、`Comparable`。
- `CatalogOrdering`（`AppCatalogCore`）：用于**排序**（locale + caseInsensitive + tieBreaker），**不是匹配**。匹配必须用独立的 `AppSearchMatcher`，不得复用 `CatalogOrdering` 的排序语义。

## Scope

- 定义 `AppSearchQuery`：携带原始查询字符串 + 可注入 `Locale`；归一化（大小写/变音/宽度）为纯函数；空/纯空白查询 → "无过滤"（全目录）。
- 定义 `AppSearchMatcher`：纯 `matches(record:query:)` —— 仅对 `displayName` 做字面子串匹配，大小写/变音/宽度不敏感，可注入 `Locale`。确定性、无 AppKit、可单测。
- 定义 `AppSearchResultSet`：纯值类型，携带 `baseCatalogRevision: CatalogRevision` + `queryGeneration: UInt64` + 过滤后 `[AppRecord]`（**保持快照稳定顺序**，不重排）+ `resultCount` + `isEmpty`。作为 presentation controller 的提交单元。
- 测试：`Tests/AppGridUITests/AppSearch*.swift`（匹配语义、Locale 注入、空查询、稳定顺序、结果集字段）。

## Out of Scope

- AppKit responder / NSSearchField / Command-F（T-1D-D）。
- Presentation controller / provider 记录 / 状态机（T-1D-B）。
- PagingUI 重载 seam（T-1D-C）。
- 装配 / 空白点击 / 启动集成（T-1D-E）。
- 修改 `Sources/PagingCore/`、`Package.swift`、`Docs/`、`PROVENANCE/`。
- Spotlight / 模糊 / 前缀 / 分词 / 排序 / 排名搜索；文件夹；拖拽；Hot Corner；120Hz；vsync；帧卡顿修复。

## Expected / Allowed Write Scope

- `Sources/AppGridUI/AppSearchQuery.swift`（新）
- `Sources/AppGridUI/AppSearchMatcher.swift`（新）
- `Sources/AppGridUI/AppSearchResultSet.swift`（新）
- `Tests/AppGridUITests/AppSearchQueryTests.swift`（新）
- `Tests/AppGridUITests/AppSearchMatcherTests.swift`（新）
- `Tests/AppGridUITests/AppSearchResultSetTests.swift`（新）

## Forbidden Write Scope

- `Sources/PagingCore/`（冻结）
- `Sources/PagingUI/`、`Sources/PagingPrototypeApp/`
- `Sources/AppGridUI/AppGridUIPageContentProvider.swift`、`AppGridSearchPresentationController.swift`、`AppGridUIState.swift`、`AppGridStatusView.swift`、`AppGridCellView.swift`、`AppGridPageView.swift`、`AppGridRefreshController.swift`、`ItemBindingToken.swift`（只读）
- `Tests/PagingUITests/`、`Tests/PagingCoreTests/` 等他人 test 目录
- `Package.swift`、`Docs/`、`PROVENANCE/`

## Constraints

- 只匹配 `AppRecord.displayName`；字面子串；大小写/变音/宽度不敏感；可注入 `Locale`。
- 空/纯空白查询 → 全目录（无过滤）。
- 结果保持快照稳定顺序，不重排、不排名。
- 无 Spotlight / NSMetadataQuery / 持久化 / 磁盘 I/O。
- 隐私：查询原文/归一化文本/结果 app 名**绝不**进入 telemetry/JSONL/stdout/signpost/profile/report；不改 `PagingTelemetry` 契约。
- 不 commit/push/tag/reset/clean；不修改 LaunchBetter / BuhoReverseNotes。
- 诊断状态保持 `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`。
