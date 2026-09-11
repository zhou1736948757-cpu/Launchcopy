# Task Packet: T-1C-B

- **Task ID**: T-1C-B
- **Role**: Worker B (fresh context — 不继承含逆向材料的旧会话上下文)
- **Phase**: 1C — AppKit responder / 页面表面接线
- **Prompt**: `Docs/PHASE1C_KEYBOARD_INTERACTION_PROMPT.md` §6 Worker B

## Objective

实现 AppKit 本地 responder 层与页面表面接线：单一键盘代理成为 first responder、`keyDown`/`performKeyEquivalent` 分发、方向键路由到焦点模型、边界跨页经窄 seam 安全切换、焦点视觉增量高亮、未支持按键不吞掉。**不使用全局 NSEvent monitor、不请求 Accessibility 权限、不做同步 I/O、不每按键重建 view tree。**

## Dependencies

- **T-1C-A**（需要 `AppGridFocusModel` / `AppGridFocusNavigator` / `AppGridFocusLayout` 类型与导航策略）。

## Context

**Fresh Context 要求（来源纪律）**：同 T-1C-A。不得读取禁止来源；误触 → `PROVENANCE/CONTAMINATION_LOG.md` + `BLOCKED_FOR_REVIEW`。

**关键既有类型（只读）**：
- `PagingSurface`（`core`、`handleScrollInput(...)`、`beginInteraction`/`endInteraction`、`isTearingDown`、`surfaceGeneration`、`onIdleBoundary`）。
- `PagingCore`（**冻结**）：`state`、`committedPage`、`visualOffset`、`pageCount`、`isAnimating`、`isTearingDown`。**无 programmatic page API**。
- `AppGridCellView`（`bindingToken`、`boundName`、`clearContent`）。
- `AppGridPageView`（`cell(at:)`、`pageIndex`、`presentationID`）。
- `AppGridRenderer`（`pageView(forPage:)`）。
- `AppGridUIPageContentProvider`（`servedSnapshot`、`servedRevision`、`pageIndex(of:appID:)`）。

## Scope

- `Sources/PagingUI/KeyboardPageTurner.swift`（新）：窄 seam，把相邻页切换表达为**经既有输入路径的合成归一化手势**（`handleScrollInput` → `ScrollInputMapper` → `PagingCore`），**仅当 `core.state == .idle`**；非 idle（触控板手势/settle 进行中）→ 延迟或忽略，绝不破坏进行中的手势/settle。保留中断/settle/token/stale 不变量，绝不篡改 `visualOffset`/`committedPage`/私有状态。
- `Sources/PagingPrototypeApp/KeyboardFocusController.swift`（新）：单一键盘代理，`acceptsFirstResponder`/`becomeFirstResponder`/`keyDown`/`performKeyEquivalent`；方向键路由到焦点模型；边界跨页经 `KeyboardPageTurner`；焦点视觉增量应用（unhighlight 旧 / highlight 新）；未支持按键 fall through 到 AppKit responder chain。提供 `install(on:surface:focusModel:)` 与 `onActivate` 回调（供 T-1C-C 接启动）。
- `Sources/AppGridUI/AppGridCellFocus.swift`（新）：`AppGridCellView` extension，`setFocused(_:)` 视觉状态（layer border/background）+ accessibility focus。确保 accessibility 焦点、视觉焦点、实际启动对象一致。
- `Tests/PagingUITests/KeyboardPageTurnerTests.swift`（新）。
- `Tests/PagingUITests/KeyboardFocusControllerTests.swift`（新）。

## Out of Scope

- 焦点纯逻辑 domain（T-1C-A）。
- 键盘启动集成 / AppDelegate 最终接线（T-1C-C）。
- 修改 `Sources/PagingCore/`、`Package.swift`、`Docs/`、`PROVENANCE/`。
- 搜索、文件夹、拖拽、Hot Corner、120Hz、vsync、帧卡顿修复。

## Expected / Allowed Write Scope

- `Sources/PagingUI/KeyboardPageTurner.swift`（新）
- `Sources/PagingPrototypeApp/KeyboardFocusController.swift`（新）
- `Sources/AppGridUI/AppGridCellFocus.swift`（新）
- `Tests/PagingUITests/KeyboardPageTurnerTests.swift`（新）
- `Tests/PagingUITests/KeyboardFocusControllerTests.swift`（新）

## Forbidden Write Scope

- `Sources/PagingCore/`（冻结）
- `Sources/PagingPrototypeApp/AppDelegate.swift`、`AppLaunchController.swift`、`KeyboardLaunchAdapter.swift`（T-1C-C）
- `Sources/AppGridUI/AppGridFocus*.swift`、`AppGridCellView.swift`、`AppGridPageView.swift`、`AppGridUIPageContentProvider.swift`、`AppGridRefreshController.swift`、`ItemBindingToken.swift`（只读，除本任务新增 `AppGridCellFocus.swift`）
- `Tests/AppGridUITests/`、`Tests/PagingCoreTests/` 等他人 test 目录
- `Package.swift`、`Docs/`、`PROVENANCE/`

## Constraints

- 本地 responder chain；无全局 NSEvent monitor；无 Accessibility 权限；无同步磁盘 I/O / 图标读取；不每按键重建 view tree。
- 键盘跨页必须经既有 PagingUI/PagingCore 合法入口（合成手势 seam），不篡改 Core 私有状态。
- 未支持按键不吞掉（fall through）。
- 焦点视觉增量应用；accessibility 焦点、视觉焦点、启动对象一致。
- 触控板 `scrollWheel` 路径不回归。
- 命名中性；不回滚他人改动；不修改 Package.swift。

## Acceptance Criteria

- [ ] surface 或键盘代理可成为 first responder
- [ ] 未聚焦窗口不响应不该响应的键
- [ ] 支持的按键被处理，未支持按键不被错误吞掉
- [ ] 触控板 scrollWheel 路径未回归
- [ ] keyboard navigation 与 settle/interruption 不产生双重 commit
- [ ] 页面切换期间焦点视觉状态没有落到旧 page host
- [ ] teardown 后按键/异步回调零 UI 写回
- [ ] resize 后焦点仍映射到正确 cell 或按文档化规则迁移
- [ ] 跨页仅在 `core.state == .idle` 时进行；非 idle 不破坏手势/settle

## Required Verification

- `swift build` 成功（PagingUI + PagingPrototypeApp + AppGridUI target 编译通过）
- `swift test` 全部 PagingUITests 键盘测试通过
- `exit_code == 0` 且 `executed_tests > 0`（非 INVALID_TEST_EXECUTION）
- 测试输出记录到 Worker Result

## Reviewer Focus

- 是否使用全局监听/权限/同步 I/O（应无）
- 键盘跨页是否经合法入口（不篡改 Core 私有状态）
- 是否破坏触控板中断/settle 连续性
- 焦点视觉是否增量（不每按键重建 view tree）
- 未支持按键是否被吞掉
- accessibility 焦点、视觉焦点、启动对象是否一致
- 隐私：不记录 app 名/bundle ID/路径/URL/图标数据/用户输入

## Deliverables

- `Sources/PagingUI/KeyboardPageTurner.swift`（新）
- `Sources/PagingPrototypeApp/KeyboardFocusController.swift`（新）
- `Sources/AppGridUI/AppGridCellFocus.swift`（新）
- `Tests/PagingUITests/*Keyboard*.swift`（新）
- `Workflow/results/T-1C-B.md`（Worker Result）
