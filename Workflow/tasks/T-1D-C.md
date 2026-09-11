# Task Packet: T-1D-C

- **Task ID**: T-1D-C
- **Role**: Worker C (fresh context — 不继承含逆向材料的旧会话上下文)
- **Phase**: 1D — PagingUI 窄同 revision 重载 seam
- **Prompt**: `Docs/PHASE1D_SEARCH_PROMPT.md` §15 Worker C

## Objective

在 `PagingSurface`（`Sources/PagingUI/`）实现一个**窄的同 revision 重载 seam**（如 `reloadCurrentPresentation()`）：以**相同 `servedRevision`** 重渲染 live hosts，但使用 provider 当前的 presentation records（pageCount 可能变化）。必须尊重 idle/busy latest-wins、不丢失 pending catalog revision、不让旧同 revision 重载覆盖新 catalog revision、强制重渲染使旧图标回调无法写入新查询的 cell、teardown 后零写回。**不触碰 `PagingCore`。**

## Dependencies

- **无**（窄 seam；只读现有 `PagingSurface` 内部状态与 `PagingPageContentProviding` 契约）。

## Context

**Fresh Context 要求（来源纪律）**：此 Worker 使用不继承旧逆向上下文的 fresh context。只接收：本 Prompt、Apple 官方公开文档、新工程自身文件。**不得读取**：`/Users/mac/Projects/BuhoReverseNotes/`（全部）、`/Users/mac/Projects/LaunchBetter/`（全部）、`2026-08-25-buho-launchpad-reverse`。误触 → 立即 `PROVENANCE/CONTAMINATION_LOG.md` + `BLOCKED_FOR_REVIEW`。

**关键既有 seam（只读）**：
- `PagingSurface.refreshPresentation()` — 既有 **revision 变化** seam：idle/cancelled → `applyPresentation(revision:)`；tracking/settling/interrupted → `pendingLatestSnapshot`（latest-wins）。Phase 1D 需要**新增**一个窄的**同 revision** 重载 seam。
- `applyPresentation(revision:)` — `servedRevision = revision`；若 `provider.servedPageCount != core.pageCount` → `core.setPageCount`；`refreshLiveHostContent(revision:)`；`pendingLatestSnapshot = nil`。
- `refreshLiveHostContent(revision:)` — 对每个 live host `render(pageIndex:content:pageCount:reuseGeneration:)`。
- `relayoutPages()` — seam 单点；pass revision = `effectiveRevisionForPass()`；回收/复用/2b revision 漂移重渲染。
- `effectiveRevisionForPass()` = `pinnedPresentation?.revision ?? servedRevision`。
- `requestContent(pageIndex:revision:)` — 同步内存命中；idle/cancelled 防御性采纳 provider 实际 revision。
- `surfaceGeneration`（teardown 时 bump）— 七字段 binding token 字段 7 的源；作废在途异步绑定。
- `ItemBindingToken`（7 字段：catalogRevision / pageIdentity / itemSlot / appID / reuseGeneration / iconKey / surfaceGeneration）——**保持 7 字段**。

## Scope

- 在 `PagingSurface` 新增窄方法 `reloadCurrentPresentation()`（或 Chief 确认的等价窄 seam 名）：
  - 以**相同 `servedRevision`** 重渲染 live hosts，但使用 provider 当前 presentation records（pageCount 可能变化）。
  - 尊重 idle/busy latest-wins：busy → stage（不覆盖 pending catalog revision）；idle → apply。
  - **不丢失 pending catalog revision**：更新的 base revision 必须优先于旧的同 revision 重载。
  - **不让旧同 revision 重载覆盖新 catalog revision**。
  - **强制重渲染**：使旧图标回调无法写入新查询的 cell（generation/token gating）。
  - **teardown 后零写回**。
- 测试：`Tests/PagingUITests/PagingSurfaceSearchReloadTests.swift`（同 revision 重载、pageCount 变化、busy/idle latest-wins、旧重载不覆盖新 revision、图标回调 gating、teardown 零写回）。

## Out of Scope

- 修改 `PagingCore`（冻结）。
- 搜索 domain（T-1D-A）、presentation controller / provider 记录（T-1D-B）、AppKit 搜索/responder（T-1D-D）、装配/空白点击/启动（T-1D-E）。
- 修改 `Package.swift`、`Docs/`、`PROVENANCE/`。
- Spotlight / 模糊 / 文件夹 / 拖拽 / Hot Corner / 120Hz / vsync / 帧卡顿修复。

## Expected / Allowed Write Scope

- `Sources/PagingUI/PagingSurface.swift`（**仅**新增窄 `reloadCurrentPresentation()` seam；不改既有方法语义）
- `Tests/PagingUITests/PagingSurfaceSearchReloadTests.swift`（新）

## Forbidden Write Scope

- `Sources/PagingCore/`（冻结）
- `Sources/AppGridUI/`、`Sources/PagingPrototypeApp/`、`Sources/MacAppCatalog/`、`Sources/AppCatalogCore/`、`Sources/AppIconPipeline/`
- `Tests/AppGridUITests/`、`Tests/PagingCoreTests/` 等他人 test 目录
- `Package.swift`、`Docs/`、`PROVENANCE/`

## Constraints

- **`Sources/PagingCore/` FROZEN** — 不修改、不在 Core 内加 seam。不得 mutate `committedPage`/`visualOffset`/transition token、不得重建 Core 强制 page 0、不得 shrink-then-restore pageCount。
- 同 revision 重载 seam 只在 `PagingUI`；**绝不 mint 假 `CatalogRevision`**。
- 七字段 `ItemBindingToken` 契约默认保持；若测试证明 7 字段不足 → **STOP 并上报 Chief**（不加第 8 字段）。
- 隐私：查询/结果名绝不进 telemetry/log；不改 `PagingTelemetry` 契约。
- 不 commit/push/tag/reset/clean；不修改 LaunchBetter / BuhoReverseNotes。
- 诊断状态保持 `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`。
