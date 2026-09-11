# ADR-011 — LAUNCHER PRESENTATION LIFECYCLE

- **状态**：**ACCEPTED（Q3 Option B）** — T-1G-A 纯逻辑已落地；T-1G-B（2026-09-10）锁定窗口形态为 screen-covering borderless panel；Main 决策见 `Workflow/decisions/2026-09-10-phase1g-continuation.md`
- **阶段**：Phase 1G（PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT §3.1-3.3、§5.1；权威依据）
- **关联**：ADR-012（系统级激活隐私/权限）；ADR-009/ADR-010（布局持久化/拖拽保留）；PARAMETER_RATIONALE；PRIVACY_DATA_MAP
- **回答**：Prompt §5.1 全部 12 问（§Q1–Q12 一一对应）
- **范围**：presentation 状态机与 request generation 所有权、幂等/中断语义、窗口形态（**Option B 已定案**）、单窗复用、hide/terminate teardown 边界、dismiss 优先级、多屏 target、Reduce Motion、B10 保持、私有 API 排除

## 背景

Phase 1G 新增产品变量：应用作为驻留进程时可靠显示/隐藏/切换**唯一**启动器窗口；多入口（initialLaunch/dockReopen/statusItem/globalShortcut/hotCorner/fourFingerPinch/testHarness）同时到达由单一 `LauncherPresentationCoordinator` 仲裁（无双窗口、无反向 toggle、无卡死全屏 Space、无旧回调覆盖）。本 ADR 定 presentation 生命周期与仲裁语义；纯逻辑部分已由 T-1G-A 实现并测试（§9.1 12 项），窗口行为由 T-1G-B 实现。

## Q1. presentation state 和 request generation 谁拥有？

**决策**：**单一 `LauncherPresentationCoordinator`（纯 Foundation 值类型）拥有 committed state 与 request generation**；UI 层（T-1G-B 窗口控制器）只执行 coordinator 输出的 effect（`.present/.dismiss/.suspend/.terminate/.teardown`），不自行维护第二份状态，不直接操作窗口。

- requestID：单调递增 `UInt64`；`activeRequestID` 唯一；每个 transition（present/dismiss）消耗一个新 ID；transition 完成或作废后归零。
- 全部激活入口只经 coordinator（PLAN §9 不变量 2），无直接窗口操作路径。
- 菜单 validation 从 `committedVisibility`（committed state 派生）读取，不另存 toggle 状态。

**理由**：多入口先读后写必然产生竞态；单一写者 + generation 使"旧 completion 永不覆盖新状态"成为可测不变量（§9.1 项 8）。

## Q2. show/hide/toggle/quit 的幂等和中断语义是什么？

**决策**（T-1G-A 已实现，§9.1 12 项测试锁定）：

| 命令 | hidden | presenting | visible | dismissing | suspended | terminating |
|---|---|---|---|---|---|---|
| show | → presenting（新 request） | **幂等 .none** | **幂等 .none** | → presenting（中断反向） | → presenting（恢复） | 拒绝 |
| hide | **幂等 .none** | → dismissing（中断反向） | → dismissing | **幂等 .none** | 幂等（已隐藏） | 拒绝 |
| toggle | → presenting | → dismissing（中断） | → dismissing | → presenting（中断） | → presenting | 拒绝 |
| quit | → terminating | → terminating | → terminating | → terminating | → terminating | 拒绝 |

- **中断（interrupt）策略**：presenting/dismissing 中收到相反命令 → 旧 transition 作废（其 completion 变 stale），立即开始反向 transition。选中断而非排队：响应性、无积压、状态可测；排队仅在 UI 层动画不可中断时作为降级（T-1G-B 决定，本 ADR 默认中断）。
- **quit dominates**：任何状态 → `.terminating`，后续命令全部拒绝（§9.1 项 11）。
- **Hot Corner 只发 `.show`**，重复 show 永不反向 hide（§9.1 项 10）；status item 与 global shortcut 可发 `.toggle`；Dock reopen 发 `.show`；explicit Quit 才发 `.quit`。
- 不用通知风暴或延迟 `asyncAfter` 猜测状态；transition 完成由 UI 层在动画结束后显式调用 `completeTransition(requestID:)`。

## Q3. native full-screen 与 screen-covering panel 选哪个，spike 证据是什么？

**决策**：**ACCEPTED — Option B（公开 API 的 screen-covering borderless window/panel）**。  
定案依据：`Workflow/decisions/2026-09-10-phase1g-continuation.md`（Main，`PROCEED_WITH_DEFERRED_GATES`）+ T-1G-B 实现/对照证据。  
**不采用** native fullscreen Space（A）与关闭重建（C）。标签 `WINDOW_ARCHITECTURE_DECISION_REQUIRED` **已解除**。

### 候选对照与 spike / 生产路径证据（§3.3 全维度）

| 维度 | A. native full-screen（单窗 + windowDidEnter/ExitFullScreen） | B. screen-covering borderless panel（**选用**） | C. 关闭并重建（不推荐） | 证据 / 结论 |
|---|---|---|---|---|
| 首次/重复显示、快速 toggle | 需等系统 fullscreen 过渡回调；当前生产用 `asyncAfter(0.3)` + `toggleFullScreen`（硬编码延迟反模式） | `orderFront` / `orderOut` 直接可控；中断反向 transition 由 coordinator requestID 守卫 | 重建成本 + 观察者积累 | **B 胜**：去掉 0.3s 延迟与 Space 过渡；`LauncherWindowController` + coordinator 可测快速 toggle |
| 当前 Space / 他 app full-screen Space / Mission Control | 进入**独立** fullscreen Space，切换语义重、易卡死 Space | 覆盖当前 Space；`collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`；**不**建新 Space | 同 A 的 Space 问题 | **B 胜**：驻留 show/hide 不 thrash Space |
| 多显示器 target screen | 全屏窗口可指定 screen，但仍绑 Space 过渡 | `ScreenID.index` → `NSScreen.screens[index]`，越界确定性 fallback（main → first → 合成 frame） | 重建时指定 | **B 足够**：Q9 策略可直接落地；fallback 有单测 |
| key/main/first responder | 系统管理，退出 fullscreen 后焦点易丢 | present 时显式 `makeKeyAndOrderFront` + `NSApp.activate` + `preferredFirstResponder` 恢复缝 | 需显式建立 | **B 可接受**：控制器暴露 first-responder 缝，不拥有键盘逻辑 |
| Dock/menu bar 意外永久隐藏 | native fullscreen 常隐藏 Dock/菜单，退出路径失败则永久感 | 覆盖式 panel 不进入系统 fullscreen；Dock/菜单保持系统策略 | 关闭窗口不影响 Dock | **B 胜**：避免“卡在 fullscreen”导致 Dock 异常 |
| blank/ESC/app launch 后 dismiss | 须先退出 fullscreen 再隐藏（双过渡） | 直接 `orderOut`（hide ≠ destroy） | 直接关闭（破坏 assembly） | **B 胜**：与 Q4/Q5/Q6 hide≠terminate 对齐；blank→hide 留给 T-1G-E |
| show/hide 延迟与动画可中断性 | 系统过渡**不可中断** | 自管 opacity 动画；反向命令作废旧 requestID completion | 重建延迟 | **B 胜**：与 Q2 中断策略一致 |
| Reduce Motion | 系统处理（不可细控） | 自管：RM 下时长→0，仍调用 `completeTransition`；状态机不感知 RM | 自管 | **B 胜**：Q10 语义；单测锁定 completion |
| B10 click delivery 回归风险 | 全屏过渡吞首击曾是根因之一（T-1C-D / B10 史） | 无 fullscreen 过渡；保留既有 `QuitOnBlankClickWindow` / click 投递路径；**不**改 `PAGING_CLICK_MANUAL_DELIVERY` | 重建易丢 hit-test 接线 | **B 风险更低**；B10 实机 A/B 仍 `PHYSICAL_PENDING`（不宣称 PASS） |
| 公共 API/权限/发布可行性 | 全公开 API | 全公开 API；无私有 Space/WindowServer；无特殊私有 window level | 全公开 API | **A/B 平**；硬约束满足 → 选 B |

### 选用理由（摘要）

1. 现网路径（`AppDelegate` 延迟 `toggleFullScreen` + `.fullScreenPrimary`）制造独立 Space + 硬编码延迟，正是本 ADR 禁止的反模式。  
2. 驻留启动器需要可中断 show/hide、快速 toggle、多入口，无 Space thrash。  
3. Panel 路径：直接显隐、可控动画 / Reduce Motion、显式 key/main/first responder、target-screen 放置。  
4. Hide 不销毁 assembly；terminate/teardown 分离（Q4–Q5）。  

**硬约束（保持）**：不得使用特殊私有 window level、私有 Space/WindowServer API、硬编码延迟猜测状态；B10 生产默认与 click 交付路径不因本定案改写。

## Q4. 一个 window/runtime assembly 如何跨 hide/show 复用？

**决策**：**一进程最多一个 launcher window/runtime assembly**（PLAN §9 不变量 1）；hide 不销毁窗口与运行态；show 复用同一 assembly。

- hide 保留：catalog、layout store（actor 在 hidden 时仍可完成已提交写入，hide 不把 layout store 置 nil）、status item、hotkey、hot-corner 服务。
- show 流程（§3.12）：validate target screen → ensure 单窗 assembly → 在安全边界 reconcile 最新 catalog + 持久化布局 → 恢复文档化 page/focus 策略 → present 窗口 → 建立 key/main/first responder → commit visible state。
- 窗口形态（Q3 的 A 或 B）不影响该复用原则。

## Q5. hide 与 terminate 的 teardown 边界是什么？

**决策**：

- **hide（含 dismiss 完成）**：仅隐藏窗口 + 取消瞬态（drag/edge timer/title edit/search transient/folder overlay/旧图标回调/presentation animation），**不 teardown 服务**。
- **terminate（quit 或系统终止）**：最终 teardown **恰好一次**（`teardownCount` 0→1，§9.1 项 12）+ bounded layout flush；`terminate()` 幂等。
- `quit()`（命令）→ `.terminate` effect（UI 终止进程）；`terminate()`（最终 teardown）→ `.teardown` effect 一次；系统直接终止（Cmd-Q/applicationWillTerminate）也走 `terminate()`。
- 隐藏时取消路径不写盘；不保留"半打开/半拖拽"交互状态（§3.2）。

## Q6. background click、ESC、app launch、window close 分别做什么？

**决策**：全部 → **hide（进程驻留），不终止进程**；仅 status menu Quit / Cmd-Q / 系统 terminate 终止进程（PLAN §9 不变量 4）。

- **ESC 优先级集中定义**（§3.2）：依次取消 title edit → drag → 关闭 folder → 清 search/selection → 隐藏 launcher。
- **background click**：先关闭 folder/search 等更高优先级状态，再隐藏 launcher。
- **app launch 成功** → 隐藏 launcher；**启动失败/被拒绝** → 保持可见 + 中性反馈（不 hide）。
- **window close 按钮** → 隐藏 ≠ Quit；`applicationShouldTerminateAfterLastWindowClosed` 不得继续导致隐藏路径退出。
- DismissReason 枚举（.backgroundClick/.escape/.appLaunched/.statusItem/.globalShortcut/.screenConfigurationChanged/.sessionResigned/.explicitQuit）为中性归因（允许记录）。

## Q7. drag/search/folder/title/focus/page 在 hide 时如何调和？

**决策**（§3.12 hide 顺序，T-1G-E 集成验证）：

1. freeze 新激活侧输入 → 2. cancel drag/edge paging → 3. 按本 ADR 完成或取消 title edit → 4. 关闭 folder overlay → 5. 退出 search/清瞬态焦点视觉 → 6. 停止 presentation frame work → 7. 隐藏窗口 → 8. commit hidden state。

- **保留策略**：committed outer page 与焦点身份保留（revision-stable，与 1C 焦点身份对齐）；folder selection **不保留半开状态**（默认关闭 overlay）；取消路径不写盘。
- 隐藏时取消 drag/edge timer/title edit/search transient/folder overlay/旧图标回调/presentation animation（PLAN §9 不变量 12）。
- folder member launch、top-level launch、键盘 launch 走同一 hide policy；不新增第二条 NSWorkspace app-launch 路径（不绕过 AppLaunchController 校验）。

## Q8. 多入口竞态、旧 completion 和快速 toggle 如何拒绝？

**决策**（T-1G-A 已实现）：

- **request generation + stale rejection**：`completeTransition(requestID:)` 仅当 `requestID == activeRequestID` 生效，否则拒绝（.none）；旧 completion 永不覆盖新状态（§9.1 项 8）。
- **toggle 原子**：coordinator 是唯一写者，toggle 在 committed state 上单步决策，无先读后写竞态（§9.1 项 4）。
- **同刻多入口**：顺序处理，第二个 show 幂等，只产生一个 present effect（§9.1 项 9）。
- **快速 toggle**：presenting↔dismissing 中断互转，requestID 单调递增，无状态回跳。
- **Hot Corner 重复 show** 永不反向 hide（§9.1 项 10）。

## Q9. 多显示器 target screen 如何选？

**决策**：

- **Hot Corner** → 实际触发 screen（corner 所在屏；§9.7 项 8 测试锁定）。
- **status item / global shortcut / Dock reopen** → 鼠标所在屏，fallback key/main screen（T-1G-C/D 实现时验证）。
- target screen 在 presenting 中消失 → 取消或确定性 fallback（不把窗口留在不可见坐标）。
- `ScreenID` = 当前屏幕列表序号（中性，不持久化 display UUID/名称/几何；§9.7 项 9）。

## Q10. Reduce Motion 如何影响视觉但不影响状态？

**决策**：**Reduce Motion 只影响 presentation 动画（时长/是否动画），不影响状态机语义与 transition 完成判定**；状态机不感知 RM。RM 下动画缩短或跳过，但 `completeTransition` 仍由 UI 层在动画（或跳过）结束后调用；`committedVisibility` 与 requestID 语义不变。具体动画策略由 T-1G-B 实现。

## Q11. B10 click delivery 修复如何保持，不因 window 形态重构回归？

**决策**：

- 窗口形态 spike（Q3）必须包含 **B10 click delivery 回归风险**维度（§3.3 清单）。
- B10 定案不变：`PAGING_CLICK_MANUAL_DELIVERY` 生产默认关；不因窗口形态重构改变 click 交付路径。
- 不改变 `PRODUCT_TIMER_TOLERANCE_0MS` / `SHORT_TAIL_MITIGATED_BY_TOLERANCE` / `CAUSALITY_UNRESOLVED_FOR_GT25MS`（PLAN §9 不变量 10）。
- B10 实机 A/B 挂账（`PHYSICAL_PENDING`），不宣称已修复。

## Q12. 为什么不使用私有 Space/WindowServer API？

**决策**：**不使用私有 Space/WindowServer API**（如 CGSSpace 等）。

- 理由：发布/签名/公证可行性；隐私红线（PLAN §11）；公共 API 优先（§3.3 硬约束）。
- native fullscreen 与驻留 show/hide 若无法可靠共存 → 走 screen-covering panel 公开 API 路线（Q3 候选 B），不降级到私有 API。
- 若未来必须私有 API → 触发 `WINDOW_ARCHITECTURE_DECISION_REQUIRED` 停止条件，需用户决策，不自行采用。

## 实现注记（T-1G-A / T-1G-B）

- 纯逻辑交付（T-1G-A）：`LauncherPresentationState.swift`、`LauncherPresentationCoordinator.swift`、`HotCornerStateMachine.swift`、`ScreenGeometrySnapshot.swift`、`ShortcutRegistrationOutcome.swift`、`ActivationSettings.swift`；测试 `Tests/PagingUITests/` 四套件（§9.1/§9.6/§9.7/§9.8）。
- 窗口形态交付（T-1G-B）：`LauncherWindowController.swift` 执行 coordinator effect（present/dismiss/suspend/terminate/teardown）；Option B screen-covering borderless panel；AppDelegate 最小 attach/host 缝（去掉延迟 `toggleFullScreen`）；测试 `LauncherWindowControllerTests`。
- 待 T-1G-C/D/E 回填：status item/Dock/shortcut/Hot Corner adapter、AppDelegate 全入口单点集成（blank/ESC/launch→hide；Quit→terminate；`applicationShouldTerminateAfterLastWindowClosed = false`）。
