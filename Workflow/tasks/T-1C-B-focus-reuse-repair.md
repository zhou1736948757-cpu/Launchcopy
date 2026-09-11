# Task Packet: T-1C-B-focus-reuse-repair

- **Task ID**: T-1C-B-focus-reuse-repair
- **Role**: Worker (fresh context)
- **Phase**: 1C — 焦点视觉复用修复（Reviewer F2 MINOR）
- **Source**: `Workflow/reviews/T-1C-B-r1.md` finding F2

## Objective

修复焦点视觉在 cell 复用路径上的残留：`AppGridCellView.clearContent` 与 `AppGridPageView.clearForReuse` 必须重置焦点视觉状态（layer border/background + accessibility focus），使一个被非键盘页面切换（触控板 fling、refresh）回收的聚焦 cell 不会在另一个 app 上残留旧的焦点边框。满足 Prompt §4.3「焦点视觉状态不能因为 cell 复用而残留在错误的 app 上」。

## Context

- T-1C-B 已 PASS。`Sources/AppGridUI/AppGridCellFocus.swift` 提供 `AppGridCellView.setFocused(_:)` / `isFocused`（layer border/background + `setAccessibilityFocused`）。
- 键盘路径已安全（旧 cell 在回收前显式 unhighlight）；本修复覆盖**非键盘**页面切换（触控板 fling、refresh）回收聚焦 cell 的路径。
- 只读参考：`AppGridCellView.swift`（`clearContent`）、`AppGridPageView.swift`（`clearForReuse`）、`AppGridCellFocus.swift`。

## Scope

- 在 `AppGridCellView.clearContent` 中重置焦点视觉（调用 `setFocused(false)` 或等价，确保 layer border/background 与 accessibility focus 清空）。
- 在 `AppGridPageView.clearForReuse` 中确保其 cell 的焦点视觉被重置（若 clearForReuse 遍历 cell 调用 clearContent 则自动覆盖；否则显式处理）。
- 新增/更新测试：复用路径下聚焦 cell 被回收后无残留焦点视觉。

## Allowed Write Scope

- `Sources/AppGridUI/AppGridCellView.swift`（修改 `clearContent`）
- `Sources/AppGridUI/AppGridPageView.swift`（修改 `clearForReuse`，若需要）
- `Tests/AppGridUITests/AppGridCellFocusReuseTests.swift`（新）

## Forbidden Write Scope

- `Sources/PagingCore/`（冻结）
- `Sources/PagingUI/`、`Sources/PagingPrototypeApp/`
- `Sources/AppGridUI/AppGridFocus*.swift`、`AppGridCellFocus.swift`（只读）
- `Tests/PagingUITests/`、`Tests/PagingCoreTests/` 等他人 test 目录
- `Package.swift`、`Docs/`、`PROVENANCE/`

## Constraints

- 不改变焦点模型/导航逻辑；只修复用路径的视觉残留。
- 不引入全局监听/权限/同步 I/O。
- 命名中性；不回滚他人改动；不修改 Package.swift。

## Acceptance Criteria

- [ ] 聚焦 cell 被 `clearContent` 回收后，焦点视觉（border/background + accessibility focus）被重置
- [ ] `clearForReuse` 路径下无残留焦点视觉
- [ ] 键盘路径（显式 unhighlight）不回归
- [ ] 新增测试覆盖复用残留场景

## Required Verification

- `swift build` 成功（AppGridUI target 编译通过）
- `swift test` 全部 AppGridUITests 通过（含新增复用测试）
- `exit_code == 0` 且 `executed_tests > 0`（非 INVALID_TEST_EXECUTION）

## Reviewer Focus

- 复用路径焦点视觉是否真正重置（非键盘页面切换）
- 是否改变焦点模型/导航逻辑（应无）
- 是否引入全局监听/权限/同步 I/O（应无）
- 隐私：不记录 app 名/bundle ID/路径/URL/图标数据

## Deliverables

- 修改的 `AppGridCellView.swift` / `AppGridPageView.swift`
- `Tests/AppGridUITests/AppGridCellFocusReuseTests.swift`（新）
- `Workflow/results/T-1C-B-focus-reuse-repair.md`（Worker Result）
