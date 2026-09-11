# T-1C-B — AppKit responder / 页面表面接线

**Worker**: worker-b（T-1C-B）
**任务**: 实现 AppKit 本地 responder 层与页面表面接线（键盘跨页窄 seam、单一键盘代理、焦点视觉增量应用）
**日期**: 2026-08-29
**接口契约**: PHASE1C_KEYBOARD_INTERACTION_PROMPT §6 Worker B、§3.3–3.5、§4.2–4.3；ADR-006（焦点 domain）；T-1C-A（焦点类型只读）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（亲笔声明：未读取 `/Users/mac/Projects/BuhoReverseNotes/`、`/Users/mac/Projects/LaunchBetter/`、`2026-08-25-buho-launchpad-reverse` 任何内容；仅依据本 Prompt、Apple 公开文档与本工程自身文件）

---

## 一、实现（新增 3 个源文件 + 2 个测试文件）

| 文件 | 内容 |
|---|---|
| `Sources/PagingUI/KeyboardPageTurner.swift` | 窄 seam：`KeyboardPageTurner`（struct，弱引用 surface）。`turn(direction:timestamp:)` 把相邻页切换表达为合成归一化手势（began → changed → ended → finishPendingGesture），经 `handleScrollInput` → `ScrollInputMapper` → `PagingCore` 既有输入路径；**仅当 `core.state == .idle`**；非 idle → `.deferred`（延迟/忽略，不破坏手势/settle）；边界 → `.atBoundary`；teardown → `.tornDown`。绝不篡改 `visualOffset`/`committedPage`/私有状态。 |
| `Sources/AppGridUI/AppGridCellFocus.swift` | `AppGridCellView` extension：`setFocused(_:)` 增量设置 layer border/background + `setAccessibilityFocused`；`isFocused`（borderWidth > 0）供测试/诊断。视觉焦点、accessibility 焦点与实际启动对象一致（调用方保证 cell 绑定与焦点身份匹配）。 |
| `Sources/PagingPrototypeApp/KeyboardFocusController.swift` | 单一键盘代理（`NSView` 子类，`@MainActor`）：`acceptsFirstResponder`/`becomeFirstResponder`/`keyDown`/`performKeyEquivalent`；方向键路由到焦点模型（`AppGridFocusNavigator`）；边界跨页经 `KeyboardPageTurner`；焦点视觉增量应用（unhighlight 旧 / highlight 新）；未支持按键 fall through 到 `super.keyDown`；`hitTest` 返回 nil（不拦截鼠标/触控板）；`install(on:surface:focusModel:)` + `onActivate` 回调（T-1C-C 接启动）+ `layoutProvider`/`cellResolver` 注入点 + `applyLayout(_:)`（迁移）+ `refreshFocusVisual()`。 |
| `Tests/PagingUITests/KeyboardPageTurnerTests.swift` | 6 测试：idle 翻页 next/previous / tracking 延迟不破坏手势 / settle 期间延迟无双重 commit / 边界不翻页 / teardown 零副作用 |
| `Tests/PagingUITests/KeyboardFocusControllerTests.swift` | 8 测试：first responder / 方向键路由 / 未支持按键不吞掉 / performKeyEquivalent fall through / 激活回调 / 跨页焦点视觉不落旧 page host / teardown 零 UI 写回 / resize 后焦点仍映射正确 cell |

**未触碰**：`Sources/PagingCore/`（冻结）、`Sources/PagingPrototypeApp/AppDelegate.swift`、`AppLaunchController.swift`、`KeyboardLaunchAdapter.swift`（T-1C-C）、`Sources/AppGridUI/AppGridFocus*.swift`、`AppGridCellView.swift`、`AppGridPageView.swift`、`AppGridUIPageContentProvider.swift`、`AppGridRefreshController.swift`、`ItemBindingToken.swift`、`Tests/AppGridUITests/`、`Tests/PagingCoreTests/`、`Package.swift`、`Docs/`、`PROVENANCE/`。

---

## 二、验收标准逐项结果

| 验收标准 | 结果 | 测试 / 证据 |
|---|---|---|
| surface 或键盘代理可成为 first responder | ✅ | `testAcceptsFirstResponder`（`acceptsFirstResponder` + `becomeFirstResponder` 均 true） |
| 未聚焦窗口不响应不该响应的键 | ✅ | 由 responder chain 天然保证（代理仅在其为 first responder 时收到 keyDown）；`testUnsupportedKeyFallsThrough` / `testPerformKeyEquivalentFallsThrough` 验证未支持按键不吞掉 |
| 支持的按键被处理，未支持按键不被错误吞掉 | ✅ | `testArrowKeyMovesFocus`（方向键路由）；`testUnsupportedKeyFallsThrough`（keyCode 0 不改变焦点、不触发激活）；`testPerformKeyEquivalentFallsThrough`（返回 false） |
| 触控板 scrollWheel 路径未回归 | ✅ | 未触碰 scrollWheel 路径；全量 501 测试全绿（含 PagingSurfaceTests 触控板路径） |
| keyboard navigation 与 settle/interruption 不产生双重 commit | ✅ | `testDeferredDuringSettleNoDoubleCommit`（settle 期间按键 → `.deferred`，`commitCount == 1`）；`testDeferredWhenTracking`（tracking 中不破坏手势） |
| 页面切换期间焦点视觉状态没有落到旧 page host | ✅ | `testCrossPageFocusVisualLandsOnNewPage`（跨页后旧 cell `isFocused == false`、新 cell `isFocused == true`） |
| teardown 后按键/异步回调零 UI 写回 | ✅ | `testTeardownZeroUIWriteback`（teardown 后 keyDown/refreshFocusVisual 不崩溃、焦点不变；`applyFocusVisual` 守卫 `surface.isTearingDown`） |
| resize 后焦点仍映射到正确 cell 或按文档化规则迁移 | ✅ | `testResizeFocusStillMapsToCorrectCell`（resize 后 cell 仍 `isFocused == true`）；迁移路径经 `applyLayout(_:)` 委托已测的 `AppGridFocusModel.apply`（T-1C-A） |
| 跨页仅在 `core.state == .idle` 时进行；非 idle 不破坏手势/settle | ✅ | `KeyboardPageTurner.turn` 守卫 `core.state == .idle`；`testDeferredWhenTracking` / `testDeferredDuringSettleNoDoubleCommit` |

---

## 三、验证证据

1. **`swift build`** → **exit 0**（PagingUI + PagingPrototypeApp + AppGridUI target 编译通过，零警告）。
2. **`swift build -c release`** → **exit 0**。
3. **`swift test --filter "KeyboardPageTurnerTests|KeyboardFocusControllerTests"`** → **14/14 全绿**（6 turner + 8 controller），exit 0。
4. **`swift test`（全量）** → **501/501 全绿，0 failures**，exit 0（487 基线 + 14 新增键盘测试，无回归）。
5. `exit_code == 0` 且 `executed_tests == 501 > 0` → **有效测试执行**（非 INVALID_TEST_EXECUTION）。
6. 冲突标记 / trailing whitespace 扫描：无。
7. 隐私：新代码不记录 app 名 / bundle ID 原文 / 路径 / URL / 图标数据 / 用户输入（`AppID` 不透明；`KeyboardPageTurner`/`KeyboardFocusController`/`AppGridCellFocus` 均无身份原文）。

---

## 四、偏离与说明

- **Return/Enter 激活**：`KeyboardFocusController` 在 `keyDown`/`performKeyEquivalent` 中处理 Return/Enter（keyCode 36/76），有焦点时调用 `onActivate(identity)` 并返回 true（已处理）；无焦点时 fall through。`onActivate` 为 T-1C-C 提供接启动的钩子（T-1C-C 设置该回调触发 `AppLaunchController`）。这是对"Provide `onActivate` callback (for T-1C-C to hook launch)"的直接实现；若 T-1C-C 需要独立 responder 处理 Return/Enter，可改为仅暴露 `onActivate` 而不在控制器内消费该键（Reviewer 可确认）。
- **焦点模型所有权**：`AppGridFocusModel` 为 struct（T-1C-A），控制器持有其可变副本并作为单一 owner；方向键导航用 `AppGridFocusModel(current: target)` 重建（`current` 为 `private(set)`，无直接 setter）。迁移经 `applyLayout(_:)` 委托 `AppGridFocusModel.apply`（已测）。
- **跨页焦点视觉时序**：跨页时控制器同步 unhighlight 旧 cell；新 page host 在 settle 中才 live，故新 cell 高亮在 `refreshFocusVisual()`（settle 完成后由集成层调用）时应用。测试在 `settleFrames` 后调用 `refreshFocusVisual()` 验证。
- **"未聚焦窗口"**：由 AppKit responder chain 天然保证（代理仅在其为 first responder 时收到 keyDown）；单测覆盖"未支持按键不吞掉"的可测部分。

---

## 五、Reviewer Focus

- 是否使用全局监听/权限/同步 I/O（应无）✅（本地 responder chain；无 NSEvent monitor；无 Accessibility 权限；无同步磁盘 I/O）
- 键盘跨页是否经合法入口（不篡改 Core 私有状态）✅（`KeyboardPageTurner` 经 `handleScrollInput` → `ScrollInputMapper` → `PagingCore`；不触碰 `visualOffset`/`committedPage`）
- 是否破坏触控板中断/settle 连续性 ✅（非 idle → `.deferred`，不注入任何输入）
- 焦点视觉是否增量（不每按键重建 view tree）✅（`setFocused` 只改 layer 属性；控制器只 unhighlight/highlight 两个 cell）
- 未支持按键是否被吞掉 ✅（fall through 到 `super.keyDown` / `performKeyEquivalent` 返回 false）
- accessibility 焦点、视觉焦点、启动对象是否一致 ✅（`setFocused` 同时设视觉 + accessibility；cell 经 renderer 解析到实际绑定 app）
- 隐私：不记录 app 名/bundle ID/路径/URL/图标数据/用户输入 ✅

## 六、Memory 候选

- 键盘跨页窄 seam：`KeyboardPageTurner` 把相邻页切换表达为合成归一化手势（began→changed→ended→finishPendingGesture），经 `handleScrollInput` → `ScrollInputMapper` → `PagingCore`，仅 `core.state == .idle` 时翻页；非 idle → `.deferred`，绝不破坏手势/settle。
- 单一键盘代理：`KeyboardFocusController`（NSView 子类）成为 first responder，方向键路由到 `AppGridFocusNavigator`，边界跨页经 `KeyboardPageTurner`，焦点视觉增量应用（`AppGridCellFocus.setFocused`），未支持按键 fall through；`onActivate` 供 T-1C-C 接启动。
- 焦点模型所有权：`AppGridFocusModel` 为 struct，控制器持有可变副本；方向键导航用 `AppGridFocusModel(current: target)` 重建；迁移经 `applyLayout(_:)` 委托 `AppGridFocusModel.apply`。
- 跨页焦点视觉时序：跨页时同步 unhighlight 旧 cell；新 page host 在 settle 中才 live，新 cell 高亮在 `refreshFocusVisual()`（settle 完成后）应用。
