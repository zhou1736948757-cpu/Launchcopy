# Task Packet: T-1D-D

- **Task ID**: T-1D-D
- **Role**: Worker D (fresh context — 不继承含逆向材料的旧会话上下文)
- **Phase**: 1D — AppKit 搜索 field / responder / controller
- **Prompt**: `Docs/PHASE1D_SEARCH_PROMPT.md` §15 Worker D

## Objective

实现 **AppKit 搜索层**：`AppSearchController`（拥有 `NSSearchField`、Command-F 聚焦、实时输入 → 查询代、Escape 清空、查询代 latest-wins token，是 field 与 presentation controller 的桥）+ `AppSearchFieldView`（中性 `NSSearchField`，无预填/无历史/无持久化，作为空白点击的显式 "interaction zone"）。`KeyboardFocusController.swift` **仅当显式分配**才触碰（如 Escape 后把焦点还给网格）。

## Dependencies

- **T-1D-A**（搜索 domain 类型）。
- **T-1D-B**（presentation controller / provider 记录）。
- **T-1D-C**（PagingUI 重载 seam 契约）。

## Context

**Fresh Context 要求（来源纪律）**：此 Worker 使用不继承旧逆向上下文的 fresh context。只接收：本 Prompt、Apple 官方公开文档、新工程自身文件。**不得读取**：`/Users/mac/Projects/BuhoReverseNotes/`（全部）、`/Users/mac/Projects/LaunchBetter/`（全部）、`2026-08-25-buho-launchpad-reverse`。误触 → 立即 `PROVENANCE/CONTAMINATION_LOG.md` + `BLOCKED_FOR_REVIEW`。

**关键既有 seam（只读）**：
- `AppGridSearchPresentationController`（T-1D-B）——查询代 latest-wins token 与提交入口。
- `AppGridUIPageContentProvider`（T-1D-B 扩展）——`servedRevision` 保持 `baseSnapshot.revision.value`。
- `PagingSurface.reloadCurrentPresentation()`（T-1D-C）——同 revision 重载 seam。
- `KeyboardFocusController`（Phase 1C，`Sources/PagingPrototypeApp/`）——单一键盘代理 first responder；**默认只读**，仅当显式分配才触碰。
- `QuitOnBlankClickWindow.sendEvent` + `blankClickResolvesToCell(_:)`（`AppDelegate.swift`）——空白点击退出路径；搜索 field/editor/clear button 必须分类为 "interaction zone"（T-1D-E 负责装配，本任务提供 field 视图）。

## Scope

- 定义 `AppSearchController`（`PagingPrototypeApp`）：拥有 `NSSearchField`；Command-F 聚焦；实时输入 → 查询代（latest-wins）；Escape 清空 field 并把焦点还给网格（文档化策略）；是 field 与 presentation controller 的桥。
- 定义 `AppSearchFieldView`：中性 `NSSearchField`（无预填/无历史/无持久化），作为空白点击的显式 "interaction zone"。
- `KeyboardFocusController.swift` **仅当显式分配**才触碰（如 Escape 后把焦点还给网格）；否则只读。
- 测试：`Tests/PagingUITests/AppSearchControllerTests.swift`、`AppSearchResponderTests.swift`（Command-F 聚焦、实时输入 → 查询代、Escape 清空/还焦、latest-wins、无全局 monitor、无 Accessibility）。

## Out of Scope

- 搜索 domain（T-1D-A）、presentation controller / provider 记录（T-1D-B）、PagingUI 重载 seam（T-1D-C）、装配/空白点击/启动集成（T-1D-E）。
- 修改 `Sources/PagingCore/`、`Package.swift`、`Docs/`、`PROVENANCE/`。
- Spotlight / 模糊 / 文件夹 / 拖拽 / Hot Corner / 120Hz / vsync / 帧卡顿修复。

## Expected / Allowed Write Scope

- `Sources/PagingPrototypeApp/AppSearchController.swift`（新）
- `Sources/PagingPrototypeApp/AppSearchFieldView.swift`（新）
- `Sources/PagingPrototypeApp/KeyboardFocusController.swift`（**仅当显式分配**；否则只读）
- `Tests/PagingUITests/AppSearchControllerTests.swift`（新）
- `Tests/PagingUITests/AppSearchResponderTests.swift`（新）

## Forbidden Write Scope

- `Sources/PagingCore/`（冻结）
- `Sources/AppGridUI/`、`Sources/PagingUI/`、`Sources/MacAppCatalog/`、`Sources/AppCatalogCore/`、`Sources/AppIconPipeline/`
- `Sources/PagingPrototypeApp/AppDelegate.swift`、`AppCatalogAssembly.swift`、`AppLaunchController.swift`（T-1D-E / 只读）
- `Tests/AppGridUITests/`、`Tests/PagingCoreTests/` 等他人 test 目录
- `Package.swift`、`Docs/`、`PROVENANCE/`

## Constraints

- **`AppLaunchController.swift` 默认不变**；搜索启动经其统一校验路径（T-1D-E 装配）。
- **无全局 NSEvent monitor、无 Accessibility/Input Monitoring、无 Spotlight/FDA。**
- 搜索 field/editor/clear button 是空白点击的显式 "interaction zone"（不退出）；真实背景空白仍首击退出（T-1D-E 装配）。
- 隐私：查询/结果名绝不进 telemetry/log；不改 `PagingTelemetry` 契约。
- 不 commit/push/tag/reset/clean；不修改 LaunchBetter / BuhoReverseNotes。
- 诊断状态保持 `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`。
