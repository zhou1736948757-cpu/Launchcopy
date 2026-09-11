# Review T-1C-D-r1 — 键盘/窗口 UX 调整（独立 Reviewer 复核）

- Task: T-1C-D（5 项 UX 调整）→ Worker result `Workflow/results/T-1C-D.md` → 本独立复核
- Reviewer: 独立角色（read-only 实现；仅写本报告）
- 禁止读取来源（BuhoReverseNotes / LaunchBetter / 2026-08-25-buho-launchpad-reverse）：未读取。
- 复核方式：从实际代码验证 + 本 Review 自跑 `swift test` / `swift build`。

---

## 结论（Verdict）

**FAIL**（1 个 MAJOR：ESC「清除选择框」在视觉上未清除选择框，用户可见行为不满足验收标准；测试仅断言模型态、掩盖了该缺陷）。

其余 4 项变更（bug-1 ← 行末落点、延迟焦点、仅全屏、空白点击退出）均验证通过；520/0 测试计数与两构建 exit 0 经本人实跑复现为真。

---

## 自跑证据（Reviewer 本人，非 Worker 声称值）

- `swift test` → **Executed 520 tests, with 0 failures (0 unexpected)**，exit 0。
  - `KeyboardFocusControllerTests`：**13/13**（含 3 个新测试），exit 0。
  - 3 个新测试逐一确认运行并通过：`testCrossPageLeftSettlePreservesRowEndLanding` (passed 0.276s)、`testDeferredFocusNoBoxUntilFirstArrow` (passed 0.411s)、`testEscClearsFocusAndReseedsOnNextArrow` (passed 0.140s)。
- `swift build -c debug` → **exit 0**（Build complete 0.52s）。
- `swift build -c release` → **exit 0**（Build complete 5.43s）。

> 注意：`testEscClearsFocusAndReseedsOnNextArrow` 仅断言 `focusModel.current == nil`，**未断言** 视觉 `isFocused == false`。该测试通过**不能**证明选择框被清除（见 finding③）。

---

## 逐项核对

### 1. bug-1 ← 跨页行末落点修复 — PASS

- `Sources/PagingPrototypeApp/KeyboardFocusController.swift:46` — `pendingCrossPageSettleTarget` 已从 `Int?` 改为 `AppGridFocusIdentity?`（存完整 页+槽 身份）。✓
- `KeyboardFocusController.swift:200-202` — `handleArrow` 跨页分支（`result == .turned`）置 `pendingCrossPageSettleTarget = target`（完整身份）。✓
- `KeyboardFocusController.swift:150-174` — `reconcileSettledCrossPage(committedPage:)`：
  - L155-161：`if pending.pageIndex == committedPage, let layout = currentLayout(), let appID = layout.validAppID(page: pending.pageIndex, slot: pending.slotIndex)` → 重建针对当前 `layout.revision` 的身份并保留该行感知落点。✓
  - L167-173：否则回退 `committedPageTarget(committedPage:)`（确定性首 cell）；无有效 cell → `current = nil` 空态清空。✓
  - 分支语义完全符合 spec（仅 `pending.page==committedPage` 且槽位仍有效才保留行末，否则回退/清空）。✓
- Navigator 未改：`Sources/AppGridUI/AppGridFocusNavigator.swift` mtime `2026-08-29 22:35:05`（早于任务窗口），`crossPageLeft`（L83-92）返回上一页同行末位有效 cell（`slots.last(where: { $0/columns == row })`，行不存在则 fallback `slots.last`）；`Tests/AppGridUITests/AppGridFocusNavigatorTests.swift:98 testCrossPageLeft` 仍锁定 `page0 slot4`（行末），未改动。✓
- → 跨页行为不变：`crossPageRight` 返回 next 页首行首个（slot0），reconcile 保留 slot0 与 `committedPageTarget` 一致；中断回落（trackpad 接管回 page0）时 pending.page(1)≠committed(0) → 回退首 cell，`testInterruptedCrossPageSettleReclampsFocusToCommittedPage` 仍通过。✓

### 2. 延迟焦点（deferred focus）— PASS

- `KeyboardFocusController.swift:75-78` — `install(on:)` 已移除自动播种（只剩 `applyFocusVisual()`；测试预置 focusModel 时 current 非 nil → 进入活动态）。✓
- `KeyboardFocusController.swift:49` — `private var isDeferredSelection = true`。✓
- `KeyboardFocusController.swift:128-137` — `applyLayout(_:)` 在 `isDeferredSelection == true` 时跳过 `focusModel.apply(layout:)`（避免 `AppGridFocusModel.apply` 空 current 播种到 page 0——`AppGridFocusModel.swift:41` 确认 `else if let target = initialFocus(in: layout)` 会播种到 `layout.firstValidIdentity()`）。✓
- `KeyboardFocusController.swift:183-189` — `handleArrow` deferred 分支：`focusModel.current == nil` → 清 `isDeferredSelection`，`committedPageTarget(committedPage: surface.core.committedPage)` 播种当前 committed 页首格，`applyFocusVisual()`，return（仅显示不移动）。✓ 用的是 `surface.core.committedPage`（当前所在页，非 page 0）。✓
- 生产空 focusModel：安装时 `current == nil` → `applyFocusVisual()` 无高亮、无选择框；`onPresentationUpdate → applyLayout`（deferred）跳过播种 → 启动无框。✓
- 既有 `readyController` 导航/F1/settle/resize/teardown 测试全绿（13/13）。✓

### 3. ESC 退出键盘选择 — **MAJOR（视觉未清除选择框）**

- `KeyboardFocusController.swift:92-95` — `keyDown` 首行 `event.keyCode == KeyCodes.escape`（53）→ `exitKeyboardSelection()` 后 **return**（不再 fall through）。✓
- `KeyboardFocusController.swift:226-231` — `exitKeyboardSelection()`：
  ```swift
  focusModel = AppGridFocusModel(current: nil)
  lastAppliedIdentity = nil
  isDeferredSelection = true
  applyFocusVisual()
  ```
- **缺陷**：`applyFocusVisual()` 在 `current == nil` 分支（L211-217）依赖 `lastAppliedIdentity` 来对旧 cell 调 `setFocused(false)`（清除 box）。但这里先执行 `lastAppliedIdentity = nil` 再调 `applyFocusVisual()`，导致该方法读到 `last` 为 nil，**永远不会 unhighlight** 当前高亮 cell。
  - 证据：`AppGridCellFocus.swift:14-16` `isFocused = (layer?.borderWidth ?? 0) > 0`；`setFocused(true)` 置 borderWidth=3、`setFocused(false)` 置 0。ESC 路径没有任何 `setFocused(false)`（除 `exitKeyboardSelection` 里那次因 last 被前置清空而失效）。
  - 因此用户按 ESC 后，高亮 box **仍停留在当前 cell 上**——不满足用户要求「按一下 ESC 退出键盘选择（清除选择框）」与 ADR-006 §5「清除选择框」。
  - 进一步：ESC 后按方向键重新播种（deferred 分支）时，由于旧 cell 从未 unhighlight、`lastAppliedIdentity` 又为 nil，新播种 cell 被高亮而旧 cell 仍高亮 → **两个 box 并存**。
  - 测试掩盖：`testEscClearsFocusAndReseedsOnNextArrow` 只断言 `current == nil` 与 reseed 到 slot0，**未断言** `isFocused == false`，故 520/0 掩盖了该缺陷。
- **根因**：`lastAppliedIdentity = nil` 在 `applyFocusVisual()` 之前执行（task packet §3 亦照此规定，属既有设计缺陷被照搬；Worker 忠实实现了 spec 但行为不满足验收）。
- **建议修复**：`exitKeyboardSelection` 内先 `applyFocusVisual()`（其 nil-current 分支会 unhighlight `last` 并自清 `lastAppliedIdentity`）再置 `lastAppliedIdentity = nil`（或直接删掉这行）；并在测试中补 `cell?.isFocused == false` 断言。
- 严重度：MAJOR。模型态正确、导航/播种正常、无崩溃；属纯视觉回归，但恰好落在用户明确要求的「清除选择框」上，故据此判 FAIL。

### 4. 仅全屏（移除窗口形态）— PASS

- `AppDelegate.swift:385-402` — `installFullScreenToggle(_:)`：无 `NSButton`、无 `NSTitlebarAccessoryViewController`；仅最小菜单（App 菜单 退出 Cmd+Q `keyEquivalent:"q"`；View 菜单「切换全屏」Ctrl+Cmd+F `toggleFullScreenAction`）。✓
- `AppDelegate.swift:204` + `213-216` — 移除 `if options.fullscreen` 门控；总是：`window.collectionBehavior.insert(.fullScreenPrimary)` + `asyncAfter(0.3s){ window?.toggleFullScreen(nil) }`。✓
- `--fullscreen` 保留为 no-op：仅 `AppArguments.swift:243` 解析置 `options.fullscreen = true`，AppDelegate 内**无任何 `options.fullscreen` 读取引用**（grep 确认）。✓
- `fullScreenButton` / `windowDidEnterFullScreen` / `windowDidExitFullScreen` / `NSTitlebarAccessoryViewController` 全仓无残留（grep exit 1）。✓
- `toggleFullScreenAction`（L404-406）保留，菜单仍可用。✓
- 未触碰 `Package.swift` / `PagingCore` / `AppGridUI` / `PagingUI` / `AppLaunchController.swift`（mtime 均早于任务窗口）。✓

### 5. 单击空白背景退出 — PASS（superview-chain 偏离安全且合规）

- `AppDelegate.swift:413-417` — `installBackgroundClickToQuit(on: surface)`：`NSClickGestureRecognizer(numberOfClicksRequired: 1)` 挂到 contentView（PagingSurface）。✓
- `AppDelegate.swift:419-437` — `backgroundClick(_:)`：`gesture.location(in: view)` + `view.hitTest(point)`；`hit == nil`（未命中任何视图）→ `terminateOnBackgroundClick()`；否则沿 **superview 链** 查找 `AppGridCellView`，命中则 return（不退出），否则 terminate。✓
- **偏离评估（相对 spec 字面「命中为 AppGridCellView 即 return」）**：
  - 安全性：点击 cell 内部 iconView/nameLabel 子视图时 `hit` 是该子视图，不再被误判为空白背景退出；cell 的 click-to-launch（`AppLaunchController`）仍正常（手势挂在 surface，点击到 cell 时本 action 仅 return，不吞事件）。✓
  - 翻页不误判：`NSClickGestureRecognizer` 默认 `allowableMovement`（10pt）外即失败，拖动翻页不触发退出。✓
  - 约束合规：仅在 AppDelegate 读取 `AppGridCellView` 类型 + view hierarchy，未改 PagingUI/AppGridUI 内部。✓
  - MINOR 备注：占位/无效 cell 亦为 `AppGridCellView`，点按不会退出（与「空白背景（非 app cell）退出」字面略有出入），但符合「不因点 cell 子视图而误退出」的稳健意图；非缺陷。

### 6. 范围 / 隐私 / 红线 — PASS

- 变更文件全部落在允许范围：`KeyboardFocusController.swift`、`AppDelegate.swift`、`KeyboardFocusControllerTests.swift`、`Docs/ADR-006-KEYBOARD-FOCUS.md`（+ `Workflow/results/T-1C-D.md` 结果文件）。✓
- 禁止树 mtime 未动（本人重跑，任务窗口 01:16:08 后 **空输出**）：
  - `find Sources/PagingCore Sources/PagingUI Sources/AppGridUI Sources/MacAppCatalog -type f -newermt "2026-08-30 01:16:08"` → 空
  - `find Package.swift Sources/PagingPrototypeApp/AppLaunchController.swift -newermt "2026-08-30 01:16:08"` → 空
  - 抽查：`Package.swift` Aug 28 20:42:55、`AppLaunchController.swift` Aug 28 21:46:54、`AppGridFocusNavigator.swift` Aug 29 22:35:05、`AppGridFocusModel.swift` Aug 29 22:35:00——均早于任务。
- 全仓任务窗口（>01:16:08）仅这 4 个允许文件 + Workflow 运行时文件（events/heartbeats/STATE/results/watchdog）。无越界。✓
- 隐私：改动仅涉及焦点身份（`AppGridFocusIdentity` 仅含 opaque `AppID` + page/slot/revision，`AppGridFocusIdentity.swift:17-23`）与窗口 UX（全屏、空白点击退出）；无 app 名/bundleID/路径/URL/图标数据/用户输入被记录。Telemetry 源文件未改动。✓
- 生产 frame Timer tolerance 缺省 `1.0/120.0` = 8.333ms 未变（`AppDelegate.swift:98`）。✓
- 无 git commit/push/tag：仓库 `No commits yet`，全程未执行任何 git 写操作。✓

### 7. 测试存在性与断言 — 部分通过

- 3 个新测试均存在且通过：`testCrossPageLeftSettlePreservesRowEndLanding`（L247，断言 slot4 行末 + 视觉 cell4）、`testDeferredFocusNoBoxUntilFirstArrow`（L282，断言 current==nil + 播种 committed 页 slot0 + 右移 slot1）、`testEscClearsFocusAndReseedsOnNextArrow`（L299）。
- **缺口**：ESC 测试未断言视觉 `isFocused == false`（仅模型态），故未覆盖 finding③ 的缺陷。

---

## Worker 自述核对

| Worker 声称 | 复核结果 |
|---|---|
| `swift test` 520/0 | ✅ 本人实跑 520/0 exit0 |
| KeyboardFocusControllerTests 13/13 | ✅ 本人实跑 13/13 |
| debug/release build exit 0 | ✅ 本人实跑均有 exit 0 |
| 3 新测试确名 | ✅ 存在且通过 |
| bug-1 reconcile 分支 / deferred / ESC / fullscreen / backgroundClick | ⚠️ 前 4 项代码验证属实；**ESC「清除选择框」视觉清除不成立**（见 finding③） |
| 禁止树 mtime 未动 | ✅ 本人 find 空输出 |
| 隐私 / tolerance / 无 git 写操作 | ✅ 核实 |
| 偏离（superview 链找 AppGridCellView） | ✅ 安全且不违反「不改 PagingUI/AppGridUI」 |

---

## Memory 候选（供 Main/Chief 判收）

- ESC `exitKeyboardSelection` 中 `lastAppliedIdentity = nil` 先于 `applyFocusVisual()`，导致清除选择框的视觉 unhighlight 永不执行（测试只断模型态故被掩盖）。修法：先 `applyFocusVisual()`（其 nil-current 分支自清 last）再清 `lastAppliedIdentity`，或直接删该行；测试补 `cell.isFocused == false` 断言。

---

## 建议下一步

修复 finding③（ESC 视觉清除 + 补视觉断言）后重跑 `swift test` 确认回退点（520 基线 + 新断言），即可判 PASS。
