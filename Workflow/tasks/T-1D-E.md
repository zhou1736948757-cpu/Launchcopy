# Task Packet: T-1D-E

- **Task ID**: T-1D-E
- **Role**: Worker E (fresh context — 不继承含逆向材料的旧会话上下文)
- **Phase**: 1D — 装配 / 空白点击 / 启动集成（serial after A–D）
- **Prompt**: `Docs/PHASE1D_SEARCH_PROMPT.md` §15 Worker E

## Objective

把搜索装配进既有 composition root：`AppDelegate.swift`（接线搜索 field + controller + presentation controller；Command-F 聚焦；空白点击 interaction-zone 分类；启动复用 `AppLaunchController.handleCell`）+ `AppCatalogAssembly.swift`（**仅搜索接线**）。搜索 field/editor/clear button 不触发空白点击退出；真实背景空白仍首击退出；无并行启动路径。

## Dependencies

- **T-1D-A**（搜索 domain 类型）。
- **T-1D-B**（presentation controller / provider 记录）。
- **T-1D-C**（PagingUI 重载 seam 契约）。
- **T-1D-D**（AppKit 搜索 field / responder / controller）。

## Context

**Fresh Context 要求（来源纪律）**：此 Worker 使用不继承旧逆向上下文的 fresh context。只接收：本 Prompt、Apple 官方公开文档、新工程自身文件。**不得读取**：`/Users/mac/Projects/BuhoReverseNotes/`（全部）、`/Users/mac/Projects/LaunchBetter/`（全部）、`2026-08-25-buho-launchpad-reverse`。误触 → 立即 `PROVENANCE/CONTAMINATION_LOG.md` + `BLOCKED_FOR_REVIEW`。

**关键既有 seam（只读）**：
- `AppDelegate.swift`（`Sources/PagingPrototypeApp/`，523 行）：`installContentAssembly(surface:)` 装配 provider/renderer/refreshController/launch/keyboard；`QuitOnBlankClickWindow.sendEvent`（L491）每次真实 `.leftMouseDown` 经 hitTest + `blankClickResolvesToCell(_:)`（L514，superview 链找 `AppGridCellView`）判定空白 → `NSApp.terminate`。**搜索 field/editor/clear button 必须分类为 "interaction zone"**（扩展 `blankClickResolvesToCell` 或加搜索 field 检查），使点击它们不退出；真实背景空白仍首击退出。**不做 hitTest 改写**（保留 scrollWheel 路由）。
- `AppLaunchController.handleCell(_ cell:)`（`Sources/PagingPrototypeApp/`，**默认不变**）——统一启动校验管线（revision → AppID → file-existence → NSWorkspace）。搜索结果启动复用此路径；无并行启动路径。
- `AppCatalogAssembly.swift`（`Sources/PagingPrototypeApp/`）——composition root；`IconURLResolver`（identity→URL 仅内存）、`CatalogRepositoryDataSource`（AppGridDataSource 适配）。**仅搜索接线**。
- `AppGridSearchPresentationController`（T-1D-B）、`AppSearchController` / `AppSearchFieldView`（T-1D-D）、`PagingSurface.reloadCurrentPresentation()`（T-1D-C）。

## Scope

- `AppDelegate.swift`：接线搜索 field + controller + presentation controller 进既有装配；Command-F 聚焦；空白点击 interaction-zone 分类（field/editor/clear button 不退出；真实背景空白仍首击退出）；启动复用 `AppLaunchController.handleCell`（无并行路径）。
- `AppCatalogAssembly.swift`（**仅搜索接线**）：连接 search controller → presentation controller → provider。
- 测试：`Tests/PagingUITests/AppSearchIntegrationTests.swift`（Command-F 聚焦、实时输入过滤、Escape 清空/还焦、刷新重跑查询、启动复用 handleCell、无并行路径）、`BlankClickToQuitTests.swift`（field/editor/clear button 不退出；真实背景空白仍退出）。

## Out of Scope

- 搜索 domain（T-1D-A）、presentation controller / provider 记录（T-1D-B）、PagingUI 重载 seam（T-1D-C）、AppKit 搜索/responder（T-1D-D）。
- 修改 `Sources/PagingCore/`、`Package.swift`、`Docs/`、`PROVENANCE/`。
- Spotlight / 模糊 / 文件夹 / 拖拽 / Hot Corner / 120Hz / vsync / 帧卡顿修复。

## Expected / Allowed Write Scope

- `Sources/PagingPrototypeApp/AppDelegate.swift`（搜索接线 + 空白点击 interaction-zone 分类）
- `Sources/PagingPrototypeApp/AppCatalogAssembly.swift`（**仅搜索接线**）
- `Tests/PagingUITests/AppSearchIntegrationTests.swift`（新）
- `Tests/PagingUITests/BlankClickToQuitTests.swift`（扩展：搜索 field 分类）

## Forbidden Write Scope

- `Sources/PagingCore/`（冻结）
- `Sources/AppGridUI/`、`Sources/PagingUI/`、`Sources/MacAppCatalog/`、`Sources/AppCatalogCore/`、`Sources/AppIconPipeline/`
- `Sources/PagingPrototypeApp/AppLaunchController.swift`（**默认不变**）、`AppSearchController.swift`、`AppSearchFieldView.swift`（T-1D-D，只读）
- `Tests/AppGridUITests/`、`Tests/PagingCoreTests/` 等他人 test 目录
- `Package.swift`、`Docs/`、`PROVENANCE/`

## Constraints

- **`AppLaunchController.swift` 默认不变**；搜索启动经其统一校验路径（`handleCell`）。无并行启动路径。
- **`Sources/PagingCore/` FROZEN** — 不修改、不在 Core 内加 seam。
- **无全局 NSEvent monitor、无 Accessibility/Input Monitoring、无 Spotlight/FDA。**
- 搜索 field/editor/clear button 是空白点击的显式 "interaction zone"（不退出）；真实背景空白仍首击退出。**不做 hitTest 改写**（保留 scrollWheel 路由）。
- 隐私：查询/结果名绝不进 telemetry/log；不改 `PagingTelemetry` 契约。
- 不 commit/push/tag/reset/clean；不修改 LaunchBetter / BuhoReverseNotes。
- 诊断状态保持 `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`。
