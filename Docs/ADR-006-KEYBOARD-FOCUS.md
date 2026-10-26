# ADR-006 — KEYBOARD-FOCUS（键盘焦点 domain / 导航策略）

- **状态**：Accepted（2026-08-30 Main 定稿；T-1C-A/B/C + F1 repair + **T-1C-D** + blank-click repair 全部过 Reviewer，526 tests 全绿）
- **关联**：PHASE1C_KEYBOARD_INTERACTION_PROMPT §3.1–3.3、§6 Worker A、§7 Worker B、§8 Worker C；ADR-004（remap 五级降级）；ItemBindingToken（七字段 binding token）；T-1C-D（5 项键盘/窗口 UX）
- **范围**：纯逻辑焦点 domain 与导航策略（`AppGridFocusIdentity` / `AppGridFocusLayout` / `AppGridFocusModel` / `AppGridFocusNavigator`），以及 B/C 段集成的**事件分发 / first responder / 键盘启动 / settle 调和**（§6）、**诊断纪律**（§7）与 **T-1C-D 键盘/窗口交互决策**（§8）。

## 背景

窗口获得键盘焦点后，需要明确、可测试、可访问的焦点模型；方向键在真实应用网格中移动焦点；焦点移动不得绕过 `PagingCore` 状态所有权；刷新/复用/teardown 后焦点不得指向不存在或过期的 cell。本 ADR 记录焦点状态模型、导航边界与未支持按键策略。

## 决策

### 1. 焦点身份 revision-stable（`AppGridFocusIdentity`）

焦点不保存裸数组下标，至少携带：

```text
catalogRevision: UInt64
pageIndex: Int
slotIndex: Int
appID: AppID?          // nil = 中性占位（不可启动）
presentationID: PagePresentationID   // revision + pageIndex
```

- `catalogRevision` 与 `presentationID.revision` 必须一致（同一内容基线）。
- 与 `ItemBindingToken` 对齐（catalogRevision / pageIdentity / appID）。
- 隐私：不记录 app 名 / bundle ID 原文 / 路径 / URL / 图标数据（`AppID` 不透明）。

### 2. 纯输入布局（`AppGridFocusLayout`）

- 由 `CatalogSnapshot` 构建（快照只含可启动 app → 每页有效身份 = 快照记录；placeholder/空 slot 天然排除）。
- 提供 `pageCount` / `itemsPerPage` / 每页有效身份（`validSlots(on:)` / `validAppID(page:slot:)` / `validIdentities(on:)`）。
- **行列从 itemsPerPage + 有效 item 数推导，不硬编码 5×7**：`rowCount(page:columns:) = ceil(有效 item 数 / columns)`；导航用 `slot / columns`、`slot % columns` 推导行列。

### 3. 焦点状态模型（`AppGridFocusModel`）

- 当前焦点身份（或 `.none` 空态）。
- **确定性初始焦点**：page 0 第一个有效 cell；空 catalog 不产生虚假焦点。
- **迁移规则**（镜像 `CatalogPlanner.remap` 五级降级，ADR-004 冻结语义）：
  1. 本布局 revision 不新于当前 → `.unchanged`（**旧 revision 永不夺回焦点**）；
  2. 空 catalog → `.empty`；
  3. anchor 仍存在 → `.located`（定位到新位置，**绝不沿用旧 index**）；
  4. anchor 消失 → 委托 `CatalogPlanner.remap` 得 successor/predecessor/clamped 页，聚焦该页首个有效 cell（`.located` 定位到 anchor 精确位置）。
- 迁移结果 `AppGridFocusMigration`：`located / successor / predecessor / clamped / empty / unchanged`。

### 4. 方向键导航（`AppGridFocusNavigator`）

- `columns` 为布局参数（不硬编码 5×7）；行列从 itemsPerPage + 有效 item 数推导。
- **←/→**：行内移动；到行边界 → 切换相邻页（同 row 首个/末个有效 cell；row 越界 clamp 到末个有效 cell）。
- **↑/↓**：同列上下行；目标行不存在 → 确定性 clamp（不移动，返回 nil）。
- **全局边界不环绕**：末页最右 / 首页最左 → 不移动（nil）。
- **stale / 无效守卫**：revision 不匹配或当前 cell 无效 → 不导航（nil）。
- 末页不完整网格：不越界（有效槽位之外不可达）。

### 5. 未支持按键策略

- 本 ADR 只定义方向键（←/→/↑/↓）的纯逻辑导航 + Return/Enter 键盘启动。
- **ESC（keyCode 53）**：T-1C-D（用户实测反馈）——有意行为更改为**退出键盘选择**：`KeyboardFocusController.keyDown` 收到 ESC 时清除选择框（`focusModel.current = nil`、`lastAppliedIdentity = nil`、`isDeferredSelection = true`），回落到 deferred 态；下次方向键重新播种。不再 fall through 给 AppKit。变更前的 ADR 原文："Escape / Tab / Space / … 本阶段不吞掉，保持原 AppKit 行为 fall through"——本次仅对 ESC 推翻该决定（显式注册）。
- **Tab / Space / Home / End / PageUp / PageDown**：维持原决策——**不吞掉**（不注册、不拦截），保持原 AppKit 行为 fall through 到 responder chain，避免改变未经测试的系统语义。
- 键盘启动复用已有 `AppLaunchController` 校验，不复制一套绕过 stale 防线的启动逻辑（AC7：与鼠标单击共享统一校验管线）。

## 6. B/C 段集成定稿（事件分发 / first responder / 键盘启动 / settle 调和）

### 6.1 单一键盘代理 first responder（Worker B：`KeyboardFocusController`）

- 本地 responder chain：单一键盘代理（`KeyboardFocusController`，`columns` 为布局参数，默认 5）成为窗口 first responder；`keyDown` / `performKeyEquivalent` 分发方向键。
- **无全局 `NSEvent` monitor、无 Accessibility 权限、无同步 I/O、不每按键重建 view tree**。
- 焦点视觉增量应用：`refreshFocusVisual()`（unhighlight 旧 / highlight 新，经 `AppGridCellFocus.setFocused`）。
- `AppDelegate` 接线：`AppGridFocusModel` → `KeyboardFocusController.install(on:focusModel:)` → `window.makeFirstResponder(keyboardController)`；`onPresentationUpdate` 重建 `AppGridFocusLayout` 并 `keyboard.applyLayout(layout)`（settle 调和 seam，见 §6.3）。teardown 时 nil 掉 `keyboardController` / `launchAdapter`。

### 6.2 键盘启动复用统一校验（Worker C：`KeyboardLaunchAdapter`）

- `KeyboardLaunchAdapter.activate(_ identity: AppGridFocusIdentity) -> AppLaunchOutcome`：只做焦点身份 → cell 解析，然后 `launchController.handleCell(cell)` —— 与鼠标单击**同一校验**（revision→AppID→文件存在性→`NSWorkspace`），**无并行启动路径**。
- 接线：`keyboard.onActivate = { adapter.activate }`。
- 启动失败非致命：outcome `.failedToLaunch` 记录，无抛出、无崩溃（AC5）。

### 6.3 键盘跨页 settle 调和（Reviewer F1 repair：`reconcileSettledCrossPage`）

- 问题：键盘跨页（←/→ 触发 `.turned`）时焦点立即指向目标页，但 settle 尚未 commit；若 settle 完成/中断后页面回滚/落定到不同页，焦点会残留旧页映射。
- 决策：`KeyboardFocusController` 维护 `pendingCrossPageSettleTarget` marker（**唯一**写点 = `handleArrow` 中被接受的跨页 `.turned`，行 163）；`reconcileSettledCrossPage(committedPage:)` 以 marker 卫（marker 为 nil 时 no-op），把焦点 re-clamp 到 committed 页首个有效 cell（`committedPageTarget(committedPage:)` → `currentLayout()` + `refreshFocusVisual`）。
- 触发 seam：`AppDelegate.onIdleBoundary`（行 288–294）在 `applyPendingAtIdleBoundary` 后调用 `reconcileSettledCrossPage(committedPage: surface.core.committedPage)` —— 经 `PagingSurface.handleCoreState(.idle)` 的唯一 idle 边界。
- **触控板不受影响**：触控板手势从不经 `handleArrow`，marker 保持 nil → reconcile 恒为 no-op。`KeyboardPageTurner.turn` 亦只接受 idle 键盘翻页。

## 7. 诊断纪律（hitch 因果保持诚实）

- 本阶段**不宣称修复触控板卡顿**。诊断状态保持三 token：
  - `CAUSALITY_UNRESOLVED`（因果链未最终收敛）
  - `PARTIAL_CONTRIBUTOR_SUPPORTED`（物理触控板 20–25ms 区间 ~10ms RunLoop exit→entry 部分贡献，见 events.jsonl seq181 / `FRAME_HITCH_ROOT_CAUSE_CORRELATION_RESULTS.md`）
  - `PRODUCT_DEFAULT_UNCHANGED`（默认行为未变）
- **禁止** `FIX_VALIDATED` / `ALL_HITCHES_FIXED` / `ROOT_CAUSE_FOUND` 声称。

## 后果

- 纯逻辑、无 AppKit 依赖，可单测。
- 焦点身份 revision-stable；迁移确定性；旧 revision 永不夺回焦点；旧 index 绝不复用。
- 导航决策不依赖 Reduce Motion 参数（RM 只影响动画，不影响焦点状态）。
- 事件分发 / first responder / 键盘启动 / settle 调和已在 §6 定稿；诊断纪律在 §7。
- 一致性命中：辅助功能焦点 / 视觉焦点 / 启动对象三者一致，`KeyboardLaunchTests.testAccessibilityVisualFocusLaunchObjectConsistency` 断言完整三元组。

## 8. T-1C-D 键盘 / 窗口交互决策（5 项 UX，2026-08-30，全过 Worker→Reviewer PASS）

由用户 5 项实际反馈固化；均在既有焦点 domain / 启动漏斗之上增量调整，未动 `PagingCore` / `AppLaunchController`。

### 8.1 左跨页行末落位（bug，T-1C-D ①）
- 既有 `AppGridFocusNavigator.crossPageLeft` 语义本就正确（返回上一页同 row 末个有效 cell）；根因是 §6.3 settle 调和把焦点钳到 committed 页**首个**有效 cell，覆盖了 ← 的行末落位。
- 决策：`reconcileSettledCrossPage` 在 `pendingCrossPageSettleTarget.page == committedPage` 且目标 slot 经 `validAppID` 仍有效时**保留行末落位**，否则回退 `committedPageTarget`/empty。新增 `testCrossPageLeftSettlePreservesRowEndLanding` 锁 ← 行末。

### 8.2 延迟焦点（deferred focus，T-1C-D ②）
- 决策：进入无选择框（`isDeferredSelection` 卫，`install` 不再自动播种）；**首个方向键**才在**当前页**行 1 首个有效 cell 播种显示框（`committedPageTarget(committedPage: surface.core.committedPage)`），随后的方向键正常导航。满足用户「无框进入、首按显示框」。
- 测试：`testDeferredFocusNoBoxUntilFirstArrow`。

### 8.3 ESC 退出键盘选择（T-1C-D ③；§5 已细化）
- ESC（keyCode 53）→ `exitKeyboardSelection()`：`focusModel = AppGridFocusModel(current: nil)` + `isDeferredSelection = true` + `applyFocusVisual()`。**applyFocusVisual 必须先于任何 lastAppliedIdentity=nil**（其 nil-current 分支基于 lastAppliedIdentity 对旧 cell `setFocused(false)`），否则旧框不清（Reviewer r1 MAJOR，repair 修正）。下次方向键重播种，无双重框。
- 测试：`testEscClearsFocusAndReseedsOnNextArrow`（含 ESC 后旧 cell `isFocused == false` 视觉断言）。

### 8.4 仅全屏显示（T-1C-D ④）
- 决策：移除窗口模式（删除切换按钮/`--fullscreen` 门控），**恒以 `.fullScreenPrimary` + 0.3s 延迟 `toggleFullScreen` 全屏进入**；保留 Cmd+Q、Ctrl+Cmd+F。`PagingSurface`（全屏 1470×923）唯一铺满窗口。
- 隐私/能力不因此变化：catalog 扫描仍限世界可读目录。

### 8.5 单击空白背景退出（T-1C-D ⑤ + blank-click-repair）
- 目标：全屏下单击任意空白（非 app cell）→ 退出 app，且**首击可靠**。
- 决策（修后）：`QuitOnBlankClickWindow: NSWindow` 覆写 `sendEvent(_:)`——**每次真实 `.leftMouseDown`** 以 `contentView.hitTest` + `blankClickResolvesToCell(_:)`（沿 superview 链找 `AppGridCellView`）评估：空白 → `NSApp.terminate`；命中 cell/icon/label → `super.sendEvent` 透传，由冻结的 `AppLaunchController` cell 启动识别器照常处理。
- 为何不选「容器 NSView mouseDown」：`PagingSurface` 为 `public final`（冻结）且是唯一铺满窗口视图，容器方案需改 hitTest，而 **scrollWheel 事件目标经 hitTest 决定，会破坏翻页**。窗口 `sendEvent` 为窗口内拦截（**非**被禁的全局 `NSEvent.addGlobalMonitorForEvents`），且不改 hitTest → 翻页 / 键盘 / cell 启动路由零改动。
- residual：全屏过渡 ~1s 内 window server 在到达应用前丢点击，应用内方案接不到（瞬时、非缺陷）。
- 测试：`BlankClickToQuitTests`（blank/nil/unrelated → 非 cell；cell/iconView/nameLabel → cell）。

## 9. T-1E 打字机环绕导航决策（2026-08-30，A+B+C 全过 Worker→Reviewer PASS）

由用户设计请求固化（用户逐字：「往下按的话应该跟往右按一样……往右按到第一行的末端了，再往右的话，就会到下面一行的第一个……我在第一列当中往下按到底了，再按一下下的话，应该到下一列的第一个……主页面和这个APP这Folder里面的页面应该都是这样的」）。

### 9.1 决策：打字机环绕模型
- **→** 行末 → 下一行第一个；**←** 行首 → 上一行最后一个；**↓** 列底 → 下一列第一个；**↑** 列顶 → 上一列最后一个。
- 跨页：→ 行末/↓ 列底在页端 → 下一页**首**个有效 slot；← 行首/↑ 列顶在页端 → 上一页**末**个有效 slot（替换 §6 的 row-preserving 跨页落位）。
- 全局边界保持 nil：page 0 上 ↑、末页下 ↓ 不环绕。
- **外层（AppGridFocusNavigator）与文件夹内（FolderInnerNavigator）行为一致**（用户一致性要求）。

### 9.2 外层实现（Task A，T-1E-nav-typewriter-outer-repair）
- `AppGridFocusNavigator.swift` 94→110 行：四方向打字机；`crossPageRight` → 下一页 `validSlots.first`、`crossPageLeft` → 上一页 `validSlots.last`；守卫（`validEntry == entryIdentity`）与 `makeIdentity`（`entryIdentity:`）不变；头注释更新。
- 测试：`AppGridFocusNavigatorTests`（旧 clamp/row-preserving 断言更新 + 新增 `testColumnWrapOnPartialPage`（32 项）与 `testColumnWrapCrossesPage`）；`KeyboardFocusControllerTests` 4 个跨页测试改 34×→ 到页末再跨页、落点 slot 34；`AppGridFocusCompositionTests` 无需改动。
- 写范围外 3 失败（`KeyboardLaunchTests.testAccessibilityVisualFocusLaunchObjectConsistency`，60 apps/35 每页，旧 4×→ 序列在打字机下第 5 次只到 slot 5 不跨页）→ 按包规则报告未修，由 Task C 适配。

### 9.3 内层实现（Task B，T-1E-nav-typewriter-inner-repair）
- `FolderKeyboardLogic.swift`：↓ 列底 → 下一列第一个（同页）；页端 → 下一页首格（`crossedPage: true`）；↑ 列顶 → 上一列最后一个（同页）；首列顶 → 上一页末格（`crossedPage: true`）；←/→ 不变（已是打字机）。
- **包内字面公式偏差（已记录）**：包内 `pageStart + col + 1 < pageEnd` 在满页误触发（35 成员/5 列：slot 34 列底会错误 Move(5,false) 而非跨页）；Worker 按包语义契约实现并加 `col + 1 < columns` 守卫，偏差写入结果文件，Reviewer B 手推核验必要且正确。
- 测试：`FolderKeyboardLogicTests`（2 个 clamp 测试改 wrap 断言 + 新增部分页 8 成员/5 列 wrap、跨页 focus/page 一致性 2 测试）；`FolderIntegrationTests` 无需改动。789/0（基线 787 + 2 新）。

### 9.4 测试适配（Task C，T-1E-nav-typewriter-launch-test-repair）
- `KeyboardLaunchTests.swift`：:302 注释改「导航到 page 0, slot 34（页末）→ 键盘跨页到 page 1」、:303-305 循环 0..<4 → 0..<34、断言 :306-323 不变。787/0。

### 9.5 验收
- 用户实机验收通过（「没问题了」，decision_recorded T-1E-nav-typewriter-user-accepted）；打字机行为（外层四方向 + 文件夹内 ↓/↑ 环绕）全屏实测无回归（Bug 1-3 行为保持）。


---

**Dated correction — 2026-09-16 (D-1J-HIT-REGION-REVERT):** §8.5 所述「命中 cell/icon/label → `super.sendEvent` 透传」反映的是整格命中时期的契约。自 2026-09-16 起启动热区契约恢复为 **icon±4pt**（`acceptsLaunchHit` = 图标/folderSymbol frame 外扩 4pt）：点击名称标签或格内 padding **不再**解析为 cell 命中，走空白分类 → `NSApp.terminate`。icon±4 内命中才透传启动链。此更正不改动本 ADR 的窗口拦截架构决策本身。
