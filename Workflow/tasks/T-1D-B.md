# Task Packet: T-1D-B

- **Task ID**: T-1D-B
- **Role**: Worker B (fresh context — 不继承含逆向材料的旧会话上下文)
- **Phase**: 1D — 搜索 presentation controller + provider 记录（base/presentation）
- **Prompt**: `Docs/PHASE1D_SEARCH_PROMPT.md` §15 Worker B

## Objective

实现搜索的 **presentation 层**：`AppGridSearchPresentationController`（拥有查询代 latest-wins token，接收查询变化与 catalog 快照，计算过滤结果集，驱动 provider 的 presentation records，idle 边界提交）+ 扩展 `AppGridUIPageContentProvider` 持有 `baseSnapshot` + `presentationRecords`（`servedRevision` 保持 `baseSnapshot.revision.value`，**绝不**用查询代）+ 无结果中性态（`AppGridUIState` / `AppGridStatusView`）。

## Dependencies

- **T-1D-A**（搜索 domain 类型：`AppSearchQuery` / `AppSearchMatcher` / `AppSearchResultSet`）。
- **T-1D-C 契约**（`PagingSurface.reloadCurrentPresentation()` 窄 seam 的形状与语义）。

## Context

**Fresh Context 要求（来源纪律）**：此 Worker 使用不继承旧逆向上下文的 fresh context。只接收：本 Prompt、Apple 官方公开文档、新工程自身文件。**不得读取**：`/Users/mac/Projects/BuhoReverseNotes/`（全部）、`/Users/mac/Projects/LaunchBetter/`（全部）、`2026-08-25-buho-launchpad-reverse`。误触 → 立即 `PROVENANCE/CONTAMINATION_LOG.md` + `BLOCKED_FOR_REVIEW`。

**关键既有类型（只读）**：
- `AppGridUIPageContentProvider`（`Sources/AppGridUI/`）：`servedSnapshot`、`servedRevision`（= `servedSnapshot?.revision.value`）、`servedPageCount`、`pendingSnapshot`（latest-wins）、`applyPending(atCurrentPage:itemsPerPage:)`（anchor remap 五级）、`content(for:itemsPerPage:)`（切片 `snapshot.records`）、`placeholderContent(for:)`。**扩展为持有 `baseSnapshot` + `presentationRecords`**。
- `AppGridUIState`（`loading/ready/empty/partialFailure/refreshing`）+ `AppGridStatusView`（中性文本）。**新增无结果中性态**（如 `noResults`，中性 accessibility 描述，如 "No applications match the search"），不改既有态语义。
- `AppGridRefreshController`（`@MainActor`）：`onPresentationUpdate` / `onStateChange` / `applyPendingAtIdleBoundary`。刷新在新快照上重跑查询。
- `CatalogPlanner.remap` 五级降级（located → successor → predecessor → clamped → emptyCatalog）——anchor 迁移镜像此语义。
- `ItemBindingToken`（7 字段）——保持 7 字段。

## Scope

- 定义 `AppGridSearchPresentationController`（`AppGridUI`）：拥有**查询代**（search-controller 内部 latest-wins token，与 `baseCatalogRevision` 完全独立）；接收查询变化与 catalog 快照；计算过滤结果集（用 T-1D-A 的 matcher）；驱动 provider 的 presentation records；idle 边界提交（镜像 `pendingLatestSnapshot` 纪律）。
- 扩展 `AppGridUIPageContentProvider`：持有 `baseSnapshot`（已提交 `CatalogSnapshot`）+ `presentationRecords`（过滤切片；空查询 → 全 base records）。`servedRevision` 保持 `baseSnapshot.revision.value`（**不是**查询代）——保证 `AppLaunchController` 的 stale 检查继续工作。`content(for:itemsPerPage:)` 切片 `presentationRecords` 而非 `baseSnapshot.records`。`servedPageCount` 由 `presentationRecords.count` 推导。
- `AppGridUIState` / `AppGridStatusView`：新增无结果中性态（不改既有态语义；中性文本；查询文本绝不渲染进 status）。
- 测试：`Tests/AppGridUITests/*SearchPresentation*.swift`（servedRevision 保持 base revision、content 切片 presentation records、无结果态、查询变化不 mint 假 revision、刷新重跑查询、latest-wins 双轴、idle 边界提交）。

## Out of Scope

- 搜索 domain（T-1D-A）、PagingUI 重载 seam（T-1D-C）、AppKit 搜索/responder（T-1D-D）、装配/空白点击/启动（T-1D-E）。
- 修改 `Sources/PagingCore/`、`Package.swift`、`Docs/`、`PROVENANCE/`。
- Spotlight / 模糊 / 文件夹 / 拖拽 / Hot Corner / 120Hz / vsync / 帧卡顿修复。

## Expected / Allowed Write Scope

- `Sources/AppGridUI/AppGridUIPageContentProvider.swift`（扩展：base/presentation records）
- `Sources/AppGridUI/AppGridSearchPresentationController.swift`（新）
- `Sources/AppGridUI/AppGridUIState.swift`（新增无结果态）
- `Sources/AppGridUI/AppGridStatusView.swift`（无结果态中性文本）
- `Tests/AppGridUITests/AppGridSearchPresentationControllerTests.swift`（新）
- `Tests/AppGridUITests/AppGridUIPageContentProviderSearchTests.swift`（新）

## Forbidden Write Scope

- `Sources/PagingCore/`（冻结）
- `Sources/PagingUI/`、`Sources/PagingPrototypeApp/`、`Sources/MacAppCatalog/`、`Sources/AppCatalogCore/`、`Sources/AppIconPipeline/`
- `Sources/AppGridUI/AppSearchQuery.swift`、`AppSearchMatcher.swift`、`AppSearchResultSet.swift`（T-1D-A，只读）、`AppGridCellView.swift`、`AppGridPageView.swift`、`AppGridRefreshController.swift`、`ItemBindingToken.swift`（只读）
- `Tests/PagingUITests/`、`Tests/PagingCoreTests/` 等他人 test 目录
- `Package.swift`、`Docs/`、`PROVENANCE/`

## Constraints

- **`CatalogRepository` 是唯一 `CatalogRevision` 拥有者**：查询变化**绝不** mint 假 revision / 把查询 hash 塞进 revision / 把查询代当 snapshot revision。`servedRevision` 保持 `baseSnapshot.revision.value`。
- **`Sources/PagingCore/` FROZEN** — 不修改、不在 Core 内加 seam。
- 同 revision 重载 seam 只在 `PagingUI`（T-1D-C 契约）；本任务只消费它。
- 七字段 `ItemBindingToken` 契约默认保持；若测试证明 7 字段不足 → **STOP 并上报 Chief**。
- 隐私：查询/结果名绝不进 telemetry/log；不改 `PagingTelemetry` 契约。
- 不 commit/push/tag/reset/clean；不修改 LaunchBetter / BuhoReverseNotes。
- 诊断状态保持 `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`。
