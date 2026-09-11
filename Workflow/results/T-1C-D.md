# Task T-1C-D — 键盘/窗口 UX 调整 结果

- Phase: 1C follow-up
- Owner: Worker (implementation) → Independent Reviewer
- Predecessors: T-1C-C (r2 PASSED), T-1C-C-F1-repair (PASSED)
- Baseline: 517 tests green

## Verdict
**DONE** — 5 项 UX 调整实现完成，`swift test` 全绿（**520 passed / 0 fail**），debug & release 构建均 exit 0，禁止树 mtime 未动。

## 变更文件清单（允许范围）
1. `Sources/PagingPrototypeApp/KeyboardFocusController.swift` — 变更 1/2/3
2. `Sources/PagingPrototypeApp/AppDelegate.swift` — 变更 4/5
3. `Tests/PagingUITests/KeyboardFocusControllerTests.swift` — 3 个新增测试 + `readyDeferredController`/`escapeKey` 辅助
4. `Docs/ADR-006-KEYBOARD-FOCUS.md` — §5 更新（ESC 行为变更记录）

## 实现摘要

### 变更 1：左跨页落点修复（bug-1，最高优先）
- `pendingCrossPageSettleTarget` 由 `Int?`（只存页）改为 `AppGridFocusIdentity?`（存完整目标身份 页+槽）。
- `handleArrow` 跨页分支改为存完整 `target` 身份（原只存 `target.pageIndex`）。
- `reconcileSettledCrossPage(committedPage:)`：仅当 `pending.pageIndex == committedPage` 且 `pending.slotIndex` 在 committed 页仍有效（`currentLayout().validAppID(page:slot:) != nil`）时，在 pending 槽位保留行感知落点（针对当前 `layout.revision` 重建身份）；否则回退 `committedPageTarget`（确定性首 cell）或空态清空。不触碰 PagingCore。

### 变更 2：延迟焦点（deferred focus）
- `install(on:)` 移除自动播种（原 `if self.focusModel.current == nil, let layout = currentLayout() { self.focusModel.apply(layout: layout) }`）。
- 新增 `private var isDeferredSelection = true`。
- `applyLayout(_:)` 在 `isDeferredSelection == true` 时跳过 `focusModel.apply(layout:)`（因 AppGridFocusModel.apply 空 current 会播种到 page 0——禁止修改行为）。
- `handleArrow` 首段：`focusModel.current == nil`（deferred）→ 清 `isDeferredSelection`，用 `committedPageTarget(committedPage: surface.core.committedPage)` 播种到当前 committed 页首行首格，`applyFocusVisual()`，仅显示不移动，return。

### 变更 3：ESC 退出键盘选择
- `keyDown` 首行：`event.keyCode == KeyCodes.escape`（53）→ `exitKeyboardSelection()`，return（不 fall through）。
- 新增 `private func exitKeyboardSelection()`：`focusModel = AppGridFocusModel(current: nil)`、`lastAppliedIdentity = nil`、`isDeferredSelection = true`、`applyFocusVisual()`。
- `Docs/ADR-006-KEYBOARD-FOCUS.md` §5 更新：ESC 有意更改为退出键盘选择。

### 变更 4：仅全屏（移除窗口形态）
- `installFullScreenToggle(_:)` 删除 NSButton + NSTitlebarAccessoryViewController 创建，仅保留最小菜单（App 菜单退出 Cmd+Q + View "切换全屏" Ctrl+Cmd+F）。
- 移除 `if options.fullscreen { ... }` 门控，**总是**全屏：`window.collectionBehavior.insert(.fullScreenPrimary)` + `asyncAfter(0.3s){ window?.toggleFullScreen(nil) }`；`--fullscreen` 保留为兼容 no-op。
- 移除 `fullScreenButton` 属性及 `windowDidEnterFullScreen`/`windowDidExitFullScreen` 引用。
- 保留 `toggleFullScreenAction`（菜单仍用）。

### 变更 5：单击空白背景退出
- 给 contentView（PagingSurface `surface`）挂 `NSClickGestureRecognizer`（numberOfClicksRequired=1）。
- action：`gesture.location(in: view)` + `view.hitTest(point)`；命中沿 superview 链查找 `AppGridCellView`（含 cell 内部 iconView/nameLabel 子视图），命中则 return；否则 `NSApp.terminate(nil)`。
- 拖动翻页不误判（NSClickGestureRecognizer 默认 allowableMovement）。
- 退出逻辑只在 AppDelegate，未写入 PagingUI/AppGridUI。

## 新增/变更测试（确名）
1. `testCrossPageLeftSettlePreservesRowEndLanding` —— bug-1 ← 跨页 settle 后焦点落到上一页第 1 行末位（slot 4），视觉断言落末位 cell。
2. `testDeferredFocusNoBoxUntilFirstArrow` —— install 空 focusModel 后 current == nil；首次方向键播种到 committed 页 slot 0（不移动）；再按右移 → slot 1。
3. `testEscClearsFocusAndReseedsOnNextArrow` —— 选择后 ESC（keyCode 53）→ current == nil；再按方向键重新播种 slot 0。

辅助：`readyDeferredController(apps:)`（空 focusModel 安装）、`escapeKey()`（keyEvent(53)）。

## 测试计数
- `swift test` 全绿：**Executed 520 tests, with 0 failures (0 unexpected)**。基线 517 + 新增 3 = 520。
- `KeyboardFocusControllerTests`：13/13 通过（含 3 新增 + 既有 F1/F1-repair/导航/teardown/resize）。
- `AppGridFocusNavigatorTests`：全绿（含锁定位的 `testCrossPageLeft`；计入 520）。
- 517 基线未回退。

## 构建结果
- `swift build -c debug` → exit 0
- `swift build -c release` → exit 0

## 禁止树核验
记录会话开始时间 `2026-08-30 01:16:08`。`find Sources/PagingCore Sources/PagingUI Sources/AppGridUI Sources/MacAppCatalog Package.swift Sources/PagingPrototypeApp/AppLaunchController.swift -type f -newermt "2026-08-30 01:16:08"` → **空输出**。抽查 mtime 未变：
- `Package.swift` Aug 28 20:42:55
- `Sources/PagingPrototypeApp/AppLaunchController.swift` Aug 28 21:46:54
- `Sources/AppGridUI/AppGridFocusNavigator.swift` Aug 29 22:35:05
未读取禁读来源（BuhoReverseNotes / LaunchBetter / 2026-08-25-buho-launchpad-reverse）。

## 隐私核验
本次改动的 telemetry 相关代码（AppDelegate telemetry session/makeSession/bridge 接线）未改动。改动仅涉键盘焦点状态机（`AppGridFocusIdentity` 只含 opaque AppID）与窗口 UX（全屏切换、空白点击退出）。无任何 app 名 / bundleID / 路径 / URL / 图标数据 / 用户输入被记录。

## 红线核验
- 未 git commit/push/tag。
- 生产 frame Timer tolerance 8.333ms 未动（AppDelegate 缺省 `frameTimerToleranceMS` → 1/120.0 逻辑未改）。
- 未声称修复 hitch；诊断 token 未触碰。
- 未修改 Package.swift / PagingCore / PagingUI / AppGridUI / MacAppCatalog / AppLaunchController。

## 供 Reviewer 关注
1. bug-1 修复的 reconcile 分支逻辑（KeyboardFocusController.reconcileSettledCrossPage 行 ~150-174）：`pending.pageIndex == committedPage` 才保留行感知落点，否则回退——请核对 ← 与 →、中断回落两条既有 F1 测试行为。
2. 变更 5 hit-test：为防点击 cell 内部 iconView/nameLabel 子视图被误判退出，沿 superview 链查找 `AppGridCellView`（比 spec 字面"命中为 AppGridCellView"更稳健）。若 Reviewer 认为必须严格字面（仅当 hit 恰为 AppGridCellView 本身才 return），请给出指示。
3. 全屏恒进改动影响 AppDelegate 启动路径（无窗口形态），无对应单元测试覆盖（需 GUI 冒烟）；`--fullscreen` 为 no-op 未做单独断言。

## Memory 候选
- bug-1 根因确认：F1 settle 调和无条件钳制到 committed 页首个 cell，覆盖了 Navigator 已正确返回的 ← 行末落点；修复 = pending 存完整身份 + reconcile 按槽位保留。AppGridFocusNavigator.crossPageLeft 本身正确，未改。
