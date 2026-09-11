# Worker Result — T-1C-C F1 Repair（键盘跨页 settle 焦点调和）

- **Task**: T-1C-C — Reviewer F1 (MAJOR) + F2 (MINOR) + F3 (MINOR) repair
- **Role**: Worker（fresh-context implementation）
- **Review basis**: `Workflow/reviews/T-1C-C-r1.md`
- **Status**: **DONE**
- **Date**: 2026-08-30

## 摘要

修复独立 Reviewer 命中的 F1（MAJOR）：键盘**跨页** settle 完成/中断后不把焦点重新调和到
committed/displayed 页。原先 AppDelegate 只在 `onPresentationUpdate`（catalog-refresh 驱动）里
`applyLayout`，而 `KeyboardFocusController.refreshFocusVisual()`/调和从未被 AppDelegate 调用，
键盘跨页走 `KeyboardPageTurner` 合成手势（不触发 catalog 刷新）→ 焦点可能残留到未显示的旧/目标页。
本修复在既有 seam 上补齐：键盘跨页被接受时给控制器打一个"进行中键盘跨页 settle"标记，
`AppDelegate.onIdleBoundary`（Core 回 idle 的唯一 settle 完成/中断边界）在同一回调里调用新增的
`reconcileSettledCrossPage(committedPage:)`，把焦点重新落定到 committed/displayed 页的确定性目标。

同时：实现 AC9 所述真实跨页 settle 测试并修正 `Docs/PHASE1C_VALIDATION_PLAN.md` AC9（F2）；
新增可访问性焦点 / 视觉焦点 / 启动对象一致性断言（ADDED）；F3 记录为开放跟进（未扩展范围实现）。

## 修改 / 新增文件清单

| 文件 | 类型 | 内容 |
|------|------|------|
| `Sources/PagingPrototypeApp/KeyboardFocusController.swift` | 修改 | F1：新增 `pendingCrossPageSettleTarget` 标记 + 公开 `reconcileSettledCrossPage(committedPage:)` + 私有 `committedPageTarget(committedPage:)`；`handleArrow` 跨页被接受时置位标记 |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | 修改 | `surface.onIdleBoundary` 回调末尾调用 `keyboardController?.reconcileSettledCrossPage(committedPage: surface.core.committedPage)` |
| `Tests/PagingUITests/KeyboardFocusControllerTests.swift` | 修改 | 新增 `testCrossPageSettleReconcilesFocusToCommittedPage`、`testInterruptedCrossPageSettleReclampsFocusToCommittedPage` + `overlaySettleReconcile()` helper |
| `Tests/PagingUITests/KeyboardLaunchTests.swift` | 修改 | 新增 `testAccessibilityVisualFocusLaunchObjectConsistency`（§4.2 一致性三要素，ADDED） |
| `Docs/PHASE1C_VALIDATION_PLAN.md` | 修改 | AC9 行 + §3 测试矩阵改为引用真实测试名（F2） |
| `Workflow/results/T-1C-C-F1-repair.md` | 新增 | 本结果 |

## F1 调和机制（为什么在既有 seam 内、不触碰 Core）

- **问题定位**：键盘跨页 `handleArrow` 在 `pageTurner.turn == .turned(target)` 被接受后**立即**把
  `focusModel` 设为目标页（`KeyboardFocusController.handleArrow`），此时 settle 尚未 commit。若该
  settle 被触控板接管/中断，最终 committed/displayed 页可能与键盘目标页背离；而 `onPresentationUpdate`
  只由 catalog-refresh 触发，不在键盘跨页 settle 完成时触发。
- **seam**：`PagingSurface.core` 回 `.idle`（settle 完成 / 中断结束）经 `handleCoreState(.idle)` 唯一触发
  `surface.onIdleBoundary`（PagingSurface.swift:501–506）——这是键盘跨页 settle 的收敛边界，也是
  AppDelegate 已接线 idle 提交的回调。
- **机制**：键盘跨页被接受时置 `pendingCrossPageSettleTarget`；`onIdleBoundary` 回调末尾
  `reconcileSettledCrossPage(committedPage:)` —— 仅当标记非 nil 才调和（普通触控板手势不触发），
  先清标记，再用 `currentLayout()` 构建布局、`committedPageTarget` 取 committed 页**首个有效 cell**
  （确定性目标，placeholder/空 slot 排除），`focusModel = AppGridFocusModel(current: target)` 后
  `applyFocusVisual()`（复用既有增量高亮）。committed 页无有效 cell → 焦点清空（旧映射不残存）。
- **不变量**：完全复用既有 reconcile 机制（`currentLayout` + `applyFocusVisual` 已在 T-1C-B 建好）；
  未改 `PagingCore`、未改 `KeyboardPageTurner`、未改 `AppLaunchController`、未新增 launch 路径/NSWorkspace。
- **F2 修正**：AC9 从虚假的"KeyboardLaunchTests 横跨断 settle"改为引用真实新增测试名
  （`KeyboardFocusControllerTests.*`）+ ADDED 一致性测试名。
- **F3（开放跟进，未实现）**：first-responder 一次性设置，窗口 key 后其它 responder 抢走焦点时
  Return 会静默失效。加 `NSWindow` key/first-responder 观察重设 `makeFirstResponder` 属 UX 增强，
  需调整 responder 语义并新增测试 → **记录为开放跟进**，不在本 bounded repair 内扩展范围（约束允许）。

## 真实测试名与执行计数

新测试（`swift test --filter`，exit 0，executed_tests 3 > 0）：

| 测试 | 结果 |
|------|------|
| `KeyboardFocusControllerTests.testCrossPageSettleReconcilesFocusToCommittedPage` | PASS |
| `KeyboardFocusControllerTests.testInterruptedCrossPageSettleReclampsFocusToCommittedPage` | PASS |
| `KeyboardLaunchTests.testAccessibilityVisualFocusLaunchObjectConsistency` | PASS |

- `swift test --filter "KeyboardLaunchTests|KeyboardFocusControllerTests|KeyboardPageTurnerTests"`：
  **27/27 通过**（11 + 10 + 6），0 失败 —— 既有键盘路径无回归。
- `swift test` 全量：**517/517 通过，0 失败**（基线 514 + 3 新增）。
  （Reviewer 确认基线为 514；本修复 +3 → 517，与基线一致无删除。）

## 构建

| 命令 | exit | 说明 |
|------|------|------|
| `swift build -c debug` | 0 | Build complete（0 警告无改动热路径） |
| `swift build -c release` | 0 | Build complete（0 警告） |

（SwiftPM 序列化于 `.build`，debug/release 顺序执行。）

## 越权 / 冻结 / 隐私检查

- **PagingCore + AppLaunchController 未修改**：`Sources/PagingCore` max mtime 08-29 21:16、
  `AppLaunchController.swift` 08-28 21:46、`Package.swift` 08-28 20:42 —— 全部早于本窗口，未触碰。
  `PagingUI` / `AppGridUI` / `KeyboardPageTurner` / `KeyboardLaunchAdapter` 亦未改动。
- 写进范围仅限声明的 5 个文件（见清单）。
- **禁止树扫描**：对修改的源/测试 grep `BuhoReverseNotes|LaunchBetter|2026-08-25-buho-launchpad-reverse`
  → 无命中；未读取任何禁止来源。
- **隐私扫描**（修改的 2 个源文件）：grep `url(string|nsurl|bundleid|.app 后缀|NSWorkspace.shared(启动)` 仅命中
  AppDelegate 既有的 telemetry wiring 与 Reduce-Motion 的 `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`
  （非启动路径）。键盘启动仍经 `KeyboardLaunchAdapter` → `AppLaunchController.handleCell`，无并行 launch 路径。
- **诊断状态**：保持 `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`，
  未写 `FIX_VALIDATED` / `ALL_HITCHES_FIXED` / `ROOT_CAUSE_FOUND`。本修复仅涉键盘焦点一致性，
  不涉及触控板卡顿；生产默认 `Timer tolerance = 8.333ms`、帧源、PagingCore 参数均未改动。
- **无并行 launch 路径**：未新增任何绕过 `AppLaunchController` 的启动入口，未从 cell 读 URL 调 `NSWorkspace`。

## F3 后续跟进（开放）

- **开放跟进**：Return 的可用性依赖 `window.makeFirstResponder(keyboardController)` 一次性设置；
  若用户点击其它 responder（如 cell/字段），Return 可能不再到达键盘代理。建议后续加
  `NSWindow.didBecomeKeyNotification` / first-responder 变化观察在聚焦丢失后重设键盘代理。
  本 bounded repair 记录为开放跟进，未实现。
