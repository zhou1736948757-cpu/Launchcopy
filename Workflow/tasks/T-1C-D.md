# Task T-1C-D — 键盘/窗口 UX 调整（用户实测反馈）

Phase: 1C (keyboard interaction) follow-up
Owner: Worker → Independent Reviewer
Predecessors: T-1C-C (r2 PASSED), T-1C-C-F1-repair (PASSED)
Baseline: 517 tests green. 禁止修改 forbidden trees（见下）。

## Objective

实现用户实测要求的 5 项键盘/窗口 UX 调整，全部以新增/更新单元测试覆盖，并保持 517 基线全绿。

### 1. 左跨页落点修复（bug，最高优先）
现状 bug：从第 N 页第 1 行第 1 个 app 按 ← 跨页到第 N-1 页时，本应落在第 N-1 页第 1 行**最后一个** app，实测却跳到第 N-1 页**第一个** app。
根因（Main 已定位，勿重新发明）：
- `AppGridFocusNavigator.crossPageLeft`（`Sources/AppGridUI/AppGridFocusNavigator.swift`，**禁止修改**）**已正确**返回上一页同行末尾 cell；`AppGridFocusNavigatorTests.testCrossPageLeft` 也锁定该预期（517 全绿）。
- 真正元凶是 **F1 settle 调和**：`KeyboardFocusController.reconcileSettledCrossPage(committedPage:)`（`Sources/PagingPrototypeApp/KeyboardFocusController.swift`）在键盘跨页 settle 完成后用 `committedPageTarget` 把焦点**无条件钳制到 committed 页首个有效 cell**（= 该页第一个 app），覆盖了 ← 的行末落点。现有测试 `KeyboardFocusControllerTests.testCrossPageSettleReconcilesFocusToCommittedPage` 只测 →（落点本即首个 cell），不测 ←，故漏过。
修复方案（仅改 KeyboardFocusController，可改）：
- `pendingCrossPageSettleTarget` 从 `Int?`（只存页）改为存**完整目标身份（页+槽）**，即 `AppGridFocusIdentity?`。
- `handleArrow` 跨页分支置位时改存完整 target。
- `reconcileSettledCrossPage(committedPage:)`：仅当 **pending.page == committedPage 且 pending.slot 在 committed 页仍有效**（`currentLayout().validAppID(page:pending.page, slot:pending.slot) != nil`）时，**保留该行感知落点**（针对当前 layout.revision 重建身份）；否则回退到 `committedPageTarget`（确定性首 cell）或空态清空。不触碰 PagingCore。

### 2. 延迟焦点（deferred focus）
现状：启动进入后立即显示焦点框（落在 page 0 第一个 app）。用户要求：**进入后不显示焦点框**；按任意方向键才显示框，框默认落在**当前所在页**（displayed committed 页）第 1 行第 1 个有效 cell；之后再按方向键才移动。
实现要点（KeyboardFocusController，可改）：
- `install(on:)` 不再自动播种初始焦点（去掉 `if self.focusModel.current == nil, let layout = currentLayout() { self.focusModel.apply(layout: layout) }`）。
- 加 `private var isDeferredSelection = true`。
- `applyLayout(_:)` 在 `isDeferredSelection == true` 时**跳过** `focusModel.apply(layout:)`（因 `AppGridFocusModel.apply` 在空 current 时会播种到 **page 0** 首个 cell——`Sources/AppGridUI/AppGridFocusModel.swift` 是**禁止修改**行为；首次方向键播种时经 `currentLayout()` 派生最新布局即可，无需现下播种）。
- `handleArrow`：若 `focusModel.current == nil`（deferred 态）→ 清 `isDeferredSelection`，用 `committedPageTarget(committedPage: surface.core.committedPage)` 播种到 **当前 committed 页**首行首格，`applyFocusVisual()`，仅显示不移动，return。注意播种页是 `surface.core.committedPage`（当前所在页），而非 page 0。
- 现有 `readyController`（`Tests/PagingUITests/KeyboardFocusControllerTests.swift`）已显式预置 focusModel 后再 install，**移除 install 自动播种不会破坏现有导航测试**。

### 3. ESC 退出键盘选择
用户要求：按一下 ESC 退出"键盘选择"功能（清除选择框）。
实现（KeyboardFocusController，可改）：`keyDown` 首行判断 `event.keyCode == 53`（ESC）→ 调用新增 `private func exitKeyboardSelection()`：`focusModel = AppGridFocusModel(current: nil)`、`lastAppliedIdentity = nil`、`isDeferredSelection = true`、`applyFocusVisual()`，return（不再 fall through）。同步更新 `Docs/ADR-006-KEYBOARD-FOCUS.md` §5（原写 Escape/Tab 落 AppKit → 本次有意的行为更改为 ESC 退出键盘选择）。

### 4. 仅全屏（移除窗口形态）
用户要求：删掉窗口显示功能，默认只能全屏显示。
实现（`Sources/PagingPrototypeApp/AppDelegate.swift`，可改；**禁止**改 Package.swift/PagingCore/AppGridUI/PagingUI）：
- `installFullScreenToggle(_:)`：删除创建 `NSButton` + `NSTitlebarAccessoryViewController` 的部分，仅保留最小菜单（App Menu 退出 Cmd+Q + View "切换全屏" Ctrl+Cmd+F）。
- 移除 `if options.fullscreen { ... }` 门控，**总是**进入全屏：`window.collectionBehavior.insert(.fullScreenPrimary)` + `DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { window?.toggleFullScreen(nil) }`。`--fullscreen` 保留为兼容 no-op。
- 清理/移除 `fullScreenButton`（属性 + `windowDidEnterFullScreen`/`windowDidExitFullScreen` 内引用）。
- 保留 `toggleFullScreenAction`（菜单仍用）。

### 5. 单击空白背景退出
用户要求：全屏下单击空白背景（非 app cell）→ 退出应用。
实现（`Sources/PagingPrototypeApp/AppDelegate.swift`，可改；**严禁**改 PagingUI/AppGridUI 内部）：
- 给 contentView（PagingSurface `surface`）挂一个 `NSClickGestureRecognizer`（numberOfClicksRequired=1）。
- action：`gesture.location(in: view)` + `view.hitTest(point)`；命中为 `AppGridCellView` → return（正常启动不退出）；否则 `NSApp.terminate(nil)`。
- 拖动翻页不误判（NSClickGestureRecognizer 超出默认 allowableMovement 即失败）。退出逻辑只放 AppDelegate，严禁放入 PagingUI/AppGridUI。

## Expected / Allowed Write Scope
- 允许：`Sources/PagingPrototypeApp/KeyboardFocusController.swift`、`Sources/PagingPrototypeApp/AppDelegate.swift`、`Tests/PagingUITests/KeyboardFocusControllerTests.swift`、`Docs/ADR-006-KEYBOARD-FOCUS.md`、`Docs/PHASE1C_VALIDATION_PLAN.md`、`Docs/PHASE1C_REPORT.md`、`Workflow/results/T-1C-D.md`。
- 禁止（不得修改，也不得读取禁读来源）：`Sources/PagingCore/`、`Sources/PagingUI/`、`Sources/AppGridUI/`、`Sources/MacAppCatalog/`、`Package.swift`、`Sources/PagingPrototypeApp/AppLaunchController.swift`、`BuhoReverseNotes`、`LaunchBetter`。
- 红线：不 commit/push/tag；隐私（telemetry 不得含 app 名/bundleID/路径/URL/图标数据/用户输入）；生产 frame Timer tolerance 8.333ms 不动；不宣称修了 hitch（诊断 token 维持 CAUSALITY_UNRESOLVED/PARTIAL_CONTRIBUTOR_SUPPORTED/PRODUCT_DEFAULT_UNCHANGED）。

## Tests required
在 `Tests/PagingUITests/KeyboardFocusControllerTests.swift` 新增：
1. `testCrossPageLeftSettlePreservesRowEndLanding` —— ← 跨页 settle 后焦点须落回上一页**行末** cell（bug-1 回归）；断言视觉落在该 cell。
2. `testDeferredFocusNoBoxUntilFirstArrow` —— install（空 focusModel）后 `focusModel.current == nil`；首次方向键播种到 committed 页 slot 0（不移动）；再按右移 → slot 1。
3. `testEscClearsFocusAndReseedsOnNextArrow` —— 选择后按 ESC → `current == nil`；再按方向键重新播种 slot 0。
可复用现有 helper：`readyController`（预置焦点）、`overlaySettleReconcile`、`settleFrames(surface)`、`surface.core.committedPage`、`keyEvent(_:)`。ESC 用 `keyEvent(53)`。必要时新增 `readyDeferredController`（空 focusModel 安装）。

## Done criteria
- `swift test` 全绿，**≥520 passed / 0 fail**；KeyboardFocusControllerTests + AppGridFocusNavigatorTests 全绿；517 基线不回退。
- `swift build -c debug`、`swift build -c release` 各自 exit 0。
- 禁止树 mtime 未动（PagingCore/PagingUI/AppGridUI/MacAppCatalog/Package.swift/AppLaunchController）。
- 结果写入 `Workflow/results/T-1C-D.md`（含：测试计数、改文件清单、新增测试名、禁止树核验、隐私核验、debug/release 构建结果）。
