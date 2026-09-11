# Task Packet: T-1C-C

- **Task ID**: T-1C-C
- **Role**: Worker C (fresh context — 不继承含逆向材料的旧会话上下文)
- **Phase**: 1C — 键盘启动适配与集成
- **Prompt**: `Docs/PHASE1C_KEYBOARD_INTERACTION_PROMPT.md` §6 Worker C

## Objective

实现 Return/Enter 键盘启动集成：复用已有 `AppLaunchController` 的统一校验管线（revision / AppID / 文件存在性 / 非致命失败），不复制一套绕过 stale 防线的启动逻辑。完成 AppDelegate 最终接线（焦点模型 + 键盘控制器 + 启动适配器）。起草 `Docs/PHASE1C_VALIDATION_PLAN.md`。

## Dependencies

- **T-1C-A**（需要 `AppGridFocusModel` 解析聚焦 cell）
- **T-1C-B**（需要 `KeyboardFocusController` 的 `onActivate` 回调）

## Context

**Fresh Context 要求（来源纪律）**：同 T-1C-A。不得读取禁止来源；误触 → `PROVENANCE/CONTAMINATION_LOG.md` + `BLOCKED_FOR_REVIEW`。

**关键既有类型（只读）**：
- `AppLaunchController`（`handleCell(_ cell:)` 公开共享校验管线：revision → AppID → file-existence → NSWorkspace；`handleClick(at:)`；`onLaunchAttempt`；`outcomeCounts`）。**键盘启动复用 `handleCell`**。
- `AppCatalogAssembly`（`provider`、`renderer`、`bundleURL(for:)`、`refreshController`）。
- `AppDelegate`（`installContentAssembly(surface:)` 内创建 `AppLaunchController` 并 `install()`）。
- `AppGridRenderer`（`pageView(forPage:)`）、`AppGridPageView`（`cell(at:)`）、`AppGridCellView`（`bindingToken`）。

## Scope

- `Sources/PagingPrototypeApp/KeyboardLaunchAdapter.swift`（新）：订阅键盘控制器的 `onActivate` 回调，解析聚焦 cell，调用 `AppLaunchController.handleCell(_:)`。无并行启动路径。
- `Sources/PagingPrototypeApp/AppDelegate.swift`（修改，接线）：创建焦点模型（T-1C-A）、键盘控制器（T-1C-B）、启动适配器（本任务），接线并安装到 surface。
- `Sources/PagingPrototypeApp/AppLaunchController.swift`（**仅当需要提取共享入口时**修改；若 `handleCell` 已足够则只读）。
- `Tests/PagingUITests/KeyboardLaunchTests.swift`（新）。
- `Docs/PHASE1C_VALIDATION_PLAN.md`（新，草稿；Main 最终整合）。

## Out of Scope

- 焦点纯逻辑 domain（T-1C-A）。
- AppKit responder / 页面表面接线（T-1C-B）。
- 修改 `Sources/PagingCore/`、`Package.swift`、`Docs/`（除 VALIDATION_PLAN 草稿）、`PROVENANCE/`。
- 搜索、文件夹、拖拽、Hot Corner、120Hz、vsync、帧卡顿修复。

## Expected / Allowed Write Scope

- `Sources/PagingPrototypeApp/KeyboardLaunchAdapter.swift`（新）
- `Sources/PagingPrototypeApp/AppDelegate.swift`（修改，接线）
- `Sources/PagingPrototypeApp/AppLaunchController.swift`（仅当需要提取共享入口）
- `Tests/PagingUITests/KeyboardLaunchTests.swift`（新）
- `Docs/PHASE1C_VALIDATION_PLAN.md`（新，草稿）

## Forbidden Write Scope

- `Sources/PagingCore/`（冻结）
- `Sources/PagingUI/`、`Sources/AppGridUI/`
- `Sources/PagingPrototypeApp/KeyboardFocusController.swift`（T-1C-B）
- `Tests/AppGridUITests/`、`Tests/PagingCoreTests/` 等他人 test 目录
- `Package.swift`、`Docs/`（除 VALIDATION_PLAN 草稿）、`PROVENANCE/`

## Constraints

- 键盘启动**必须**复用 `AppLaunchController` 校验（revision / AppID / 文件存在性 / 非致命失败）。无并行启动路径绕过 stale 防线。
- 键盘路径不得直接从 cell 读 URL 后调用 `NSWorkspace`。
- 启动失败非致命、中性结果。
- 不记录 app 名/bundle ID/路径/URL/用户输入到 telemetry。
- 鼠标单击启动路径与键盘启动共享相同校验。
- 命名中性；不回滚他人改动；不修改 Package.swift。

## Acceptance Criteria

- [ ] Return/Enter 对有效焦点调用一次 launcher
- [ ] stale revision 拒绝
- [ ] 当前 snapshot 缺少 AppID 拒绝
- [ ] 文件消失拒绝
- [ ] 启动失败非致命
- [ ] 无焦点、空 cell、placeholder 不启动
- [ ] 鼠标单击启动路径与键盘启动共享相同校验
- [ ] 不产生真实 URL/path/bundle ID telemetry

## Required Verification

- `swift build` 成功（PagingPrototypeApp target 编译通过）
- `swift test` 全部 PagingUITests 启动测试通过
- `exit_code == 0` 且 `executed_tests > 0`（非 INVALID_TEST_EXECUTION）
- 测试输出记录到 Worker Result

## Reviewer Focus

- 键盘启动是否复用 `AppLaunchController` 校验（无并行路径绕过 stale 防线）
- 是否从 cell 直接读 URL 调 NSWorkspace（应无）
- 启动失败是否非致命
- 鼠标/键盘启动是否共享同一校验
- 隐私：无真实 URL/path/bundle ID telemetry
- AppDelegate 接线是否完整且不越权

## Deliverables

- `Sources/PagingPrototypeApp/KeyboardLaunchAdapter.swift`（新）
- `Sources/PagingPrototypeApp/AppDelegate.swift`（接线）
- `Sources/PagingPrototypeApp/AppLaunchController.swift`（仅当需要）
- `Tests/PagingUITests/KeyboardLaunchTests.swift`（新）
- `Docs/PHASE1C_VALIDATION_PLAN.md`（草稿）
- `Workflow/results/T-1C-C.md`（Worker Result）
