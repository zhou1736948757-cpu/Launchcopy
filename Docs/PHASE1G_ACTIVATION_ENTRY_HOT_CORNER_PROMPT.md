# Phase 1G 开发 Prompt：驻留启动器、菜单栏、快捷键、Hot Corner 与四指捏合呼出

> 项目：`/Users/mac/Projects/Launch_Copy/PagingPrototype`
>
> 日期基线：2026-09-05（Asia/Shanghai）
>
> 性质：下一阶段的自包含开发输入，不是 Phase 1F 已完成证明，不是发布授权，也不是第三方实现复刻说明。
>
> 本文中的 **activation / 激活入口** 只指“显示、隐藏或切换本启动器界面”，绝不指许可证、注册码、付费授权或 activation bypass。

> **2026-09-05 四指捏合扩展版**：用户新增“后台四指向内捏合呼出”需求，指定 LaunchBetter 手势代码作为参考。新增 §16–§25 为本轮细化要求；与旧条款冲突时，以本说明、修订后的 §2 和 §16–§25 为准。
>
> **先看风险边界**：参考实现使用私有 MultitouchSupport.framework。允许读取指定文件不等于允许使用任意私有 API、申请输入权限或获得发布资格。先做技术与来源决策门，再实现真实后台采集。四指呼出是新增必验项，不可用快捷键、前台缩放事件或 mock 演示替代。
>
> **本文件是开发输入，不是实施结果**。本次仅更新 Prompt；没有接入功能，没有运行测试，没有确认手势在本机可用。历史测试数和 Workflow 状态都必须重新核实。

---

## 0. 总目标

在现有分页、应用目录、启动、搜索、文件夹、拖拽和布局持久化基础上，新增一套**独立设计、基础入口采用公开 API、四指采集单独决策、默认低权限**的启动器呈现入口：

1. 应用作为驻留进程时，可以可靠地显示、隐藏和切换唯一的启动器窗口；
2. 菜单栏提供稳定的 Show/Hide、设置入口和真正 Quit；
3. Dock/Reopen 能显示现有窗口，而不是重复创建窗口；
4. 可选全局快捷键可触发 Show/Hide，且不读取普通键盘内容；
5. 可选 Hot Corner 可在后台触发 Show，且不使用全局事件监听、CGEvent tap 或辅助功能权限；
6. 多入口同时到达时由单一 coordinator 仲裁，不产生双窗口、反向 toggle、卡死全屏 Space 或旧回调覆盖；
7. 隐藏/再次显示不破坏 Phase 1F 的布局持久化、拖拽、文件夹、搜索、焦点和应用启动；
8. 应用启动、空白点击和 ESC 从“退出进程”迁移为“关闭启动器界面”，只有明确 Quit 才终止驻留进程；
9. 全部参数、权限、能耗和物理行为有可重复证据；
10. 在进程驻留且界面隐藏时，四指向内捏合发出一次 Show；向外张开不自动 Hide。

本阶段不追求品牌视觉，也不照搬任何第三方产品的菜单、快捷键、触发区尺寸、延迟、动画、窗口层级或图标。

---

## 1. Gate 0：先核实 Phase 1F，不能直接相信“已完成”

### 1.1 用户输入与当前仓库事实必须分开

用户在 2026-09-05 报告：

```text
Folder 功能已经实现（用户明确确认；拖拽与持久化其余验收仍按实际证据对账）
```

把它记录为：

```text
USER_REPORTED_PHASE1F_FUNCTIONALLY_COMPLETE
```

它是重要的实机验收输入，但不能自动改写尚未闭合的 Workflow 或证明用户运行的是哪个 binary、哪个环境门控。

本 Prompt 编写前的只读快照显示：

```text
Workflow/STATE.json phase = PHASE_1F_IN_PROGRESS
Workflow/STATE.json workflow_status = ACTIVE
STATE.next_action 仍指向早已完成的 T-1F-A
active_agent_jobs = []
T-1F-B / T-1F-C / resume 项仍为 EXECUTING
T-1F-B10-regression 仍为 REVIEWING
T-1F-B10-regression-fix = PASSED，但生产候选门控默认关闭的历史需要定案
T-1F-B11-row-boundary-indicator = PASSED，但事件 next_action 仍要求一次真实窗口视觉验收
最近可见自动基线为 1133 tests / 0 failures，但本 Prompt 编写轮没有重跑
```

且以下 Phase 1F 收尾文档在快照时不存在：

```text
Docs/PHASE1F_SPEC.md
Docs/PHASE1F_VALIDATION_PLAN.md
Docs/PHASE1F_VALIDATION_RESULTS.md
Docs/PHASE1F_REPORT.md
```

因此，**Phase 1G 代码开工前必须先完成 Gate 0 对账**。不得为了进入下一阶段而伪造历史 review、补造 subagent 事件或把旧测试数当作当前结果。

### 1.2 Gate 0 必读

至少读取：

```text
AGENTS.md
MEMORY.md
Workflow/config.json
Workflow/STATE.json
Workflow/events.jsonl（尾部及全部 T-1F 相关事件）
Workflow/PLAN.md
Workflow/MAIN_BRIEF.md
Workflow/BUG8-REPORT.md
Workflow/BUG9-REPORT.md（如存在）
Workflow/BUG10-REGRESSION-REPORT.md
Workflow/BUG10-CODEX-HANDOFF.md
Workflow/tasks/T-1F-B10-regression*.md
Workflow/results/T-1F-B10-*.md
Workflow/reviews/T-1F-B10-*.md
Workflow/tasks/T-1F-B11-row-boundary-indicator.md
Workflow/results/T-1F-B11-row-boundary-indicator.md
Workflow/reviews/T-1F-B11-row-boundary-indicator-r1.md
Docs/PHASE1F_DRAG_PERSISTENCE_PROMPT.md
Docs/ADR-009-WORKSPACE-LAYOUT-AND-PERSISTENCE.md
Docs/ADR-010-DRAG-SESSION-AND-DROP-SEMANTICS.md
Docs/PRIVACY_DATA_MAP.md
Docs/PARAMETER_RATIONALE.md
Docs/IMPLEMENTATION_LOG.md
PROVENANCE/ACCESS_DECLARATION.md
PROVENANCE/CONTAMINATION_LOG.md
```

### 1.3 Gate 0 必做

1. 确认当前没有真实运行中的 Worker/Reviewer；修正 `active_agent_jobs` 与事实一致；
2. 对遗留 `EXECUTING`、`REVIEWING`、`READY` 状态逐项找真实 result/review/event，不得只看文件名猜；
3. 为已完成但历史生命周期不完整的旧任务使用项目既有的诚实状态标签，不补造不存在的 review；
4. 确认 B10 单击/打开/启动回归的**生产默认路径**到底是什么：
   - `PAGING_CLICK_PROBE_MANUAL_DELIVERY` 只能是诊断门；
   - `PAGING_CLICK_MANUAL_DELIVERY` 若仍默认关闭，则“开门控后可用”不等于生产修复完成；
   - 必须记录用户验收时门控值、启动命令、binary hash 和行为；
   - 如果无法对应，做最小真实窗口 A/B，不得推断；
5. 确认 B11 的跨行/行末 insertion indicator 已由用户在真实窗口验收，或者明确记 `PHYSICAL_VISUAL_ACCEPTANCE_PENDING`；
6. 新鲜运行全部自动测试、Debug build、Release build，记录 executed/passed/failed 和 exit code；
7. 记录 Debug/Release executable SHA-256；
8. 检查 layout store 测试没有触碰真实 Application Support；
9. 创建/补全 Phase 1F 的 SPEC、VALIDATION_PLAN、VALIDATION_RESULTS、REPORT 和 artifact manifest；
10. 使用 `python3 Workflow/record_workflow_event.py ...` 或项目规定脚本更新 append-only 事件；不要手改历史行；
11. 只有下列条件同时满足，才把 Phase 1F 关为通过并开始 Phase 1G 实现：

```text
当前生产默认构建的拖拽、folder、点击、打开、启动、空白和 ESC 行为通过
fresh full tests = 0 failures, executed > 0
Debug/Release = exit 0
关键 T-1F 状态与真实证据对齐
Phase 1F 收尾文档存在且不夸大
```

如果只有自动化通过、物理门不完整，使用：

```text
PHASE1F_AUTOMATED_COMPLETE_PHYSICAL_PENDING
```

并停止 Phase 1G 行为代码，不得让新生命周期改动掩盖旧输入回归。

### 1.4 继续保留的性能事实

```text
PRODUCT_TIMER_TOLERANCE_0MS
SHORT_TAIL_MITIGATED_BY_TOLERANCE
CAUSALITY_UNRESOLVED_FOR_GT25MS
```

- 0ms 是当前生产默认定案；
- `SHORT_TAIL_MITIGATED_BY_TOLERANCE` 只覆盖 20–25ms 短尾；
- 严格 `>25ms` 长尾根因仍未解决；
- Phase 1G 不修改 Timer tolerance、PagingCore 参数或 frame source 默认值。

---

## 2. 独立实现与来源边界

### 2.1 来源隔离与用户授权的有限例外

仍禁止读取或使用：

```text
/Users/mac/Projects/BuhoReverseNotes/
/Users/mac/Projects/LaunchBetter/Docs/aegis/work/2026-08-25-buho-launchpad-reverse/
任何 Buho 反编译全文、地址映射、资源、截图或具体代码表达
```

用户在本轮明确指定 `/Users/mac/Projects/LaunchBetter` 的四指手势代码作为参考。
本轮对原先整树禁止读取规则作**有限例外**：只读 §17 列出的手势文件、测试和必要调用点。
不得遍历该目录的逆向资料，不迁移 LaunchBetter 整体架构、资源、品牌或无关功能。
依赖扩展必须先说明文件、用途和来源，获得 Main 范围批准；涉及禁止资料必须停止。
LaunchBetter 的工程指令不自动覆盖目标 PagingPrototype 的流程，更不能带入其发布或推送规则。

本阶段实现依据：

1. 本 Prompt 的可观察产品需求；
2. 当前 PagingPrototype 的源码、测试、ADR 与用户实测；
3. 当前 Xcode SDK headers 和 Apple 公开文档；
4. 本阶段独立实验；
5. 本次授权白名单中的 LaunchBetter 手势参考，必须记录接触和使用方式。

读取参考代码的角色记录 `REFERENCE_EXPOSED`。曾接触逆向资料的角色记录 `PRIOR_EXPOSURE`。
不能声称整个项目或整个会话严格 clean-room。代码所在目录由用户持有，不等于每段代码来源和使用权已验证。
默认提取行为与工程风险后重新实现；如提出直接移植代码，必须先记录来源、权利依据和准确移植范围。

### 2.2 禁止的功能和做法

```text
许可证激活、破解、绕过、注册码、付费状态仿制
Launchpad/Dock 私有数据库读写
私有 AppKit/WindowServer/CoreGraphics API
CGEvent tap
NSEvent.addGlobalMonitorForEvents
全局键盘内容监听
未经单独确认的 Accessibility/Input Monitoring 权限（四指能力例外必须经过 §18 决策门）
屏幕录制权限
记录鼠标轨迹、键码流、窗口标题、前台 app、bundle ID 或路径
复制第三方菜单栏图标、文案、快捷键、Hot Corner 参数、视觉和动画
自动安装、签名、公证、发布、commit、push、tag
```

---

## 3. Phase 1G 产品语义

### 3.1 驻留与呈现生命周期

建立独立的纯逻辑状态机，不让 `AppDelegate` 的零散回调各自决定窗口行为。

建议领域概念：

```text
LauncherPresentationState
  .hidden
  .presenting(requestID, targetScreen)
  .visible(screenID)
  .dismissing(requestID, reason)
  .suspended(reason)
  .terminating

LauncherActivationSource
  .initialLaunch
  .dockReopen
  .statusItem
  .globalShortcut
  .hotCorner
  .testHarness

LauncherCommand
  .show
  .hide
  .toggle
  .quit

DismissReason
  .backgroundClick
  .escape
  .appLaunched
  .statusItem
  .globalShortcut
  .screenConfigurationChanged
  .sessionResigned
  .explicitQuit
```

要求：

- 全部入口进入一个 `LauncherPresentationCoordinator`；
- 一个进程最多一个 launcher window、一个有效 transition、一个 active request ID；
- 旧 animation/completion/request 不能覆盖更新状态；
- `show` 在 visible/presenting 时幂等；
- `hide` 在 hidden/dismissing 时幂等；
- `toggle` 必须在 coordinator 的 committed state 上原子决策，不能由多个入口先读后写；
- Hot Corner 只发 `.show`，不能因重复触发把窗口反向隐藏；
- status item 与 global shortcut 可发 `.toggle`；
- Dock reopen 发 `.show`；
- explicit Quit 才发 `.quit`；
- transition 中收到相反命令时有确定的中断/排队规则，并有测试；
- 不用通知风暴或延迟 `asyncAfter` 猜测状态。

### 3.2 从“一次性全屏应用”迁移为驻留启动器

当前行为包含：

```text
applicationShouldTerminateAfterLastWindowClosed = true
空白点击调用 NSApp.terminate
窗口关闭触发 teardownAll
启动后延迟 toggleFullScreen
```

Phase 1G 必须重新定义：

- 空白点击：关闭 folder/search 等更高优先级状态后，隐藏 launcher，不终止进程；
- ESC：依次取消 title edit → drag → 关闭 folder → 清 search/selection → 隐藏 launcher；优先级必须集中定义；
- 成功启动 app：隐藏 launcher；启动失败/被拒绝时保持可见并给中性反馈；
- 点击窗口关闭按钮若窗口形态仍有按钮：按产品决策隐藏，不等于 Quit；
- `applicationShouldTerminateAfterLastWindowClosed` 不得继续导致隐藏路径退出；
- status menu 的 Quit、Cmd-Q、系统 terminate 才真正结束进程；
- hide 不调用永久 teardown，不丢 catalog/layout store/status item/hotkey/hot-corner 服务；
- termination 才执行最终 teardown 和 bounded layout flush；
- 隐藏时必须取消 drag、edge timer、title edit、search transient state、folder overlay、旧图标 UI 回调和 presentation animation；
- 是否保留 committed outer page、焦点和 folder selection，必须由 ADR 明确；默认不得保留一个“半打开/半拖拽”的交互状态。

### 3.3 窗口形态是架构硬门

当前实现依赖系统 native full-screen Space，并通过延迟 `toggleFullScreen` 启动。反复 show/hide 时可能发生 Space 切换、异步过渡竞争、窗口失 key、重复 toggle 或输入投递回归。

实现前必须用最小 spike 比较：

1. **保留 native full-screen window**：单窗复用，显式等待 `windowDidEnterFullScreen` / `windowDidExitFullScreen`；
2. **公开 API 的 screen-covering borderless window/panel**：不创建独立 full-screen Space，但保持用户观察到的全屏启动器效果；
3. **关闭并重建窗口**：通常不推荐，必须说明为何不会丢运行态或积累观察者。

ADR 必须比较：

- 首次显示、重复显示、快速 toggle；
- 当前 Space、另一个 app 的 full-screen Space、Mission Control；
- 多显示器目标屏幕；
- key/main window 与 first responder；
- Dock/menu bar 是否被意外永久隐藏；
- blank/ESC/app launch 后的 dismiss；
- show/hide 延迟和动画可中断性；
- Reduce Motion；
- B10 click delivery 回归风险；
- 公共 API、权限和发布可行性。

只有 spike 证据支持后才能选择。不得为了看起来像第三方产品而使用特殊 window level、私有 Space API 或硬编码延迟。

### 3.4 菜单栏入口

使用公开 `NSStatusBar` / `NSStatusItem`：

- status item 生命周期由专用 controller 拥有并强引用；
- 图标使用本项目独立 symbol/模板图，不复制第三方资产；
- 至少包含：Show/Hide（状态动态更新）、Activation Settings、Quit；
- status item 单击与菜单命令不得各自维护第二套 toggle 状态；
- 菜单 validation 从 presentation coordinator 的 committed state 派生；
- 无窗口时菜单仍可用；
- status item 创建失败不应使应用崩溃，保留 Dock reopen/其他入口；
- 退出时移除 status item 和 target/action 引用；
- 菜单文案使用项目中性语言，后续品牌阶段再统一。

本阶段不实现自动更新、购买、许可证、最近启动列表或应用清单菜单。

### 3.5 Dock / 应用 Reopen

实现 `applicationShouldHandleReopen(_:hasVisibleWindows:)` 或当前 SDK 对应公开 delegate seam：

- hidden → show；
- visible → 保持 visible 并成为 key，而不是 hide；
- presenting/dismissing → 交给 coordinator 仲裁；
- 不创建第二个 window；
- 不重建 catalog/layout store；
- 不伪造 Dock private state；
- Dock 图标是否长期显示由 ADR 决定，不能未经用户决策切换 `.regular/.accessory` 后破坏入口。

### 3.6 可选全局快捷键

必须比较并记录：

1. 当前 SDK 中公开的 `RegisterEventHotKey` / `UnregisterEventHotKey` 路径；
2. 仅应用 active 时的 `NSMenuItem.keyEquivalent`（不能冒充全局快捷键）；
3. 第三方快捷键依赖（本阶段默认不新增）；
4. `NSEvent` global monitor 或 event tap（禁止）。

若选择 `RegisterEventHotKey`：

- 建立窄 `GlobalShortcutRegistering` protocol 和生产 adapter；
- 全部注册/注销在规定线程执行；
- 只接收一个已注册组合的 hot-key event，不读取一般 keyDown 流；
- 默认非 exclusive，冲突/注册失败显示中性状态且其他入口继续工作；
- reconfigure 必须先安全注册新组合或执行明确 rollback，不能把旧快捷键悄悄丢掉；
- 禁止无修饰键和系统保留组合；
- 重复 key repeat 不产生 show/hide 抖动；
- app inactive、其他 app active 时需要真实物理验证；
- teardown 解除注册和 event handler；
- 测试使用 fake registrar，不抢占真实系统快捷键；
- 不记录用户按过的其他键，也不在 telemetry/stdout 输出真实组合，报告只用中性 `configured/conflict/unavailable`。

快捷键默认值必须是本项目独立产品决策。若没有可配置 UI，本阶段默认应为 **Off**，不能偷偷注册一个系统级组合。

### 3.7 可选 Hot Corner

Hot Corner 默认 **Off**。用户显式选择一个 corner 后才启动检测。

允许的候选实现：

- 公开 `NSEvent.mouseLocation` 的低频、可暂停轮询；
- `NSScreen.screens` / screen frame 的纯几何判定；
- 主线程 Timer、DispatchSourceTimer 或专用低功耗 scheduler，经 ADR 比较。

禁止：

```text
NSEvent.addGlobalMonitorForEvents
CGEvent tap
AXObserver / Accessibility API
IOHID 私有/底层输入抓取
记录或持久化指针轨迹
每帧 60/120Hz 轮询
```

Hot Corner 领域状态建议：

```text
.disabled
.armed
.insideCandidate(corner, enteredAt)
.triggeredAwaitingExit(corner)
.suspended(reason)
```

语义：

- 从 zone 外进入才开始 dwell；应用启动时指针已在角落不应立即触发；
- dwell 满足后只触发一次 `.show`；
- 必须离开带 hysteresis 的 re-arm 区后才能再次触发；
- cooldown、dwell、zone size、poll interval 分离；
- 鼠标任意按键按下、当前 drag active、屏幕锁定/用户 session inactive、系统 sleep 时不触发；
- launcher 已 visible/presenting 时暂停或只保持 triggered，不发重复请求；
- 快速跨越角落、屏幕重配、坐标跳变不触发；
- 不读取系统 Hot Corner 私有偏好；与系统已有 Hot Corner 冲突时只提示用户自行选择，不篡改系统设置；
- 不知道用户前台 app 身份，也不记录前台 app；
- 所有坐标只存在于一次内存判定，日志只能记录中性 corner enum、状态和计数，默认 telemetry 不增加事件；
- disabled 时零 timer、零轮询；隐藏服务 teardown 后零回调。

### 3.8 多显示器与坐标

必须建立纯 `ScreenGeometrySnapshot`，生产 adapter 才接触 `NSScreen`：

- 支持负坐标、上下排列、不同 scale、不同分辨率；
- 明确 `NSEvent.mouseLocation` 与 screen frame 的坐标系；
- 每个 screen 的四角独立生成候选区域；
- 共享边/拼接处不可到达的“内角”如何处理必须有确定规则；
- 屏幕插拔、分辨率/缩放变化后原子替换 geometry，并取消旧 dwell；
- Hot Corner show 的 target screen = 实际触发 screen；
- status item / shortcut / Dock reopen 的 target screen 策略由 ADR 决定，例如鼠标所在屏或 key/main screen fallback；
- target screen 在 presenting 中消失时取消或确定性 fallback，不能把窗口留在不可见坐标；
- 不持久化 display UUID、屏幕名称或几何。

### 3.9 参数与误触控制

以下必须集中在一个参数结构中：

```text
poll interval
corner zone size
dwell duration
hysteresis/re-arm inset
cooldown
toggle debounce
presentation transition duration
```

每个值在 `Docs/PARAMETER_RATIONALE.md` 标注：

```text
APPLE_PUBLIC_BEHAVIOR
ACCESSIBILITY_REQUIREMENT
INDEPENDENT_PRODUCT_DECISION
LOCAL_EXPERIMENT
```

不得标为 reverse-derived。先用保守候选值做 A/B，再由真实鼠标/触控板误触与响应测试定案。参数必须与显示刷新率无关，不能用 frame count 表示 dwell/cooldown。

### 3.10 设置持久化

只持久化少量 activation preference：

```text
hotCornerEnabled / selectedCorner
globalShortcutEnabled / shortcut representation（如本阶段支持配置）
showStatusItem（如允许关闭）
必要 schema version
```

可以使用专用、带 schema/namespace 的 `UserDefaults`，但必须：

- 与 Phase 1F layout store 分离；
- 不保存 pointer coordinates、screen ID、前台 app、按键历史、窗口标题、搜索词或 app identity；
- decode 非法值回到安全 Off，不崩溃；
- tests 注入独立 suite name，绝不污染真实用户 defaults；
- reset activation settings 与 reset layout 是两个动作；
- unknown future schema 不应被旧代码静默覆盖；
- 配置改变后 service start/stop 原子、幂等、可回滚。

### 3.11 睡眠、锁屏与用户会话

使用公开 `NSWorkspace` notifications 或可注入 adapter 处理：

- willSleep → suspend polling、取消 dwell；
- didWake → 重建 screen geometry，要求 pointer 重新离开/进入后才 re-arm；
- sessionDidResignActive / screen locked → suspend；
- sessionDidBecomeActive / unlock → 延迟到稳定状态后重新 arm，但不立即触发；
- app terminating → 全部注销；
- notification observer 生命周期严格成对；
- 测试不用真实 sleep/lock，使用 fake event source。

### 3.12 与现有功能的集成

每次 hide 前必须按单一顺序：

```text
freeze new activation-side input
→ cancel drag/edge paging
→ finish or cancel title editing per ADR
→ close folder overlay
→ exit search / clear transient focus visual
→ stop presentation frame work
→ hide window
→ commit hidden state
```

每次 show：

```text
validate target screen
→ ensure one window/runtime assembly
→ reconcile latest catalog + persisted layout at safe boundary
→ restore documented page/focus policy
→ present window
→ establish key/main/first responder
→ commit visible state
```

要求：

- 不修改或绕过 `AppLaunchController` 的身份/文件存在校验；
- `onLaunchAttempt(.launched)` 可以请求 hide，失败结果不能 hide；
- layout store actor 在 hidden 时仍可完成已提交写入；
- hide 不把 layout store 置 nil；
- show 不用 `--folder-lab` 覆盖正式布局；
- search active 时 activation toggle 的行为确定；
- drag 中 status/hotkey 请求 hide 时先取消 drag，取消路径不写盘；
- folder member launch、top-level launch 和键盘 launch 都走同一 hide policy；
- 不新增第二条 NSWorkspace app-launch 路径；
- 不改变 `PRODUCT_TIMER_TOLERANCE_0MS`。

---

## 4. 性能、能耗与隐私红线

### 4.1 Hot Corner 空闲热路径

一次 poll 只允许：

```text
读取当前 pointer point
读取缓存的 screen geometry
有界 corner hit test
更新小状态机
必要时发一次中性 activation request
```

禁止：

```text
catalog scan
layout encode/write
图标加载
窗口树遍历
应用列表排序
每次 poll 分配大型集合
查询前台 app
日志输出 pointer 坐标
同步等待 actor/queue
```

### 4.2 能耗门

必须做 disabled/enabled A/B：

- disabled 证明无 timer、无 callback；
- enabled-hidden 空闲至少做稳定时段采样；
- 记录 CPU、wakeups/timer firings、内存趋势和触发延迟；
- 轮询不得与 PagingSurface 60Hz frame pump 绑定；
- launcher visible 时暂停 Hot Corner polling；
- sleep/session inactive 时暂停；
- 如果启用后的空闲成本无法与功能收益相称，标记 `HOT_CORNER_ENERGY_GATE_FAILED`，保留菜单/快捷键，不硬上 Hot Corner。

不要只用一次瞬时 Activity Monitor 截图写 PASS。记录方法、时间窗、构建 hash 和原始中性数据。

### 4.3 隐私

不得记录或输出：

```text
raw pointer coordinates
pointer trajectory
screen UUID/name/serial
frontmost application
pressed key stream
真实快捷键文本（默认日志）
app 名称/bundle ID/path/URL
folder title/UUID/member list
搜索词
窗口标题
```

允许的中性证据：

```text
activation source enum
show/hide/toggle/quit outcome enum
corner enum（topLeft 等）
dwell/cooldown state enum
screen count
registration outcome enum
transition duration aggregate
counter
```

更新 `PRIVACY_DATA_MAP.md`，明确系统级 trigger 接触的数据、生命周期、默认 Off、权限和不持久化字段。

---

## 5. 必须创建的 ADR 和文档

实现前创建并经 Chief 接受：

```text
Docs/ADR-011-LAUNCHER-PRESENTATION-LIFECYCLE.md
Docs/ADR-012-SYSTEM-WIDE-ACTIVATION-PRIVACY.md
Docs/PHASE1G_SPEC.md
Docs/PHASE1G_VALIDATION_PLAN.md
```

最终创建：

```text
Docs/PHASE1G_VALIDATION_RESULTS.md
Docs/PHASE1G_REPORT.md
Docs/PHASE1G_ARTIFACTS.sha256
```

### 5.1 ADR-011 至少回答

1. presentation state 和 request generation 谁拥有？
2. show/hide/toggle/quit 的幂等和中断语义是什么？
3. native full-screen 与 screen-covering panel 选哪个，spike 证据是什么？
4. 一个 window/runtime assembly 如何跨 hide/show 复用？
5. hide 与 terminate 的 teardown 边界是什么？
6. background click、ESC、app launch、window close 分别做什么？
7. drag/search/folder/title/focus/page 在 hide 时如何调和？
8. 多入口竞态、旧 completion 和快速 toggle 如何拒绝？
9. 多显示器 target screen 如何选？
10. Reduce Motion 如何影响视觉但不影响状态？
11. B10 click delivery 修复如何保持，不因 window 形态重构回归？
12. 为什么不使用私有 Space/WindowServer API？

### 5.2 ADR-012 至少回答

1. status item、Dock reopen、shortcut、Hot Corner 哪些默认启用？
2. 全局快捷键用什么公开 API，为什么不监听一般键盘事件？
3. Hot Corner 用什么公开 API、poll scheduler 与纯状态机？
4. 为什么不使用 global NSEvent monitor、CGEvent tap 或 Accessibility？
5. dwell/hysteresis/cooldown/re-arm 语义是什么？
6. 多屏幕、屏幕变化、sleep/lock/session inactive 如何处理？
7. 配置如何持久化、迁移、reset 和测试隔离？
8. 哪些数据短暂接触、哪些严禁日志/持久化？
9. 能耗门与失败降级是什么？
10. shortcut 冲突和注册失败如何恢复？
11. 用户未配置任何系统级 trigger 时应用如何访问和退出？
12. 哪些行为延期到下一阶段？

---

## 6. 冻结范围与写入纪律

### 6.1 默认冻结

```text
Sources/PagingCore/
Sources/PagingTelemetry/
Sources/PagingUI/
Sources/AppCatalogCore/
Sources/MacAppCatalog/
Sources/AppIconPipeline/
Sources/AppGridUI/LayoutDomain/
Sources/AppGridUI/LayoutStore/
Sources/AppGridUI/DragSession/
Package.swift
Sources/PagingPrototypeApp/AppLaunchController.swift
```

理由：Phase 1G 是呈现入口/应用生命周期阶段，不是分页、catalog、图标、layout schema、drag mutation 或启动安全重写。

### 6.2 默认允许

优先在 `Sources/PagingPrototypeApp/` 新增窄文件：

```text
LauncherPresentationState.swift
LauncherPresentationCoordinator.swift
LauncherWindowController.swift
StatusItemController.swift
GlobalShortcutRegistrar.swift
HotCornerMonitor.swift
HotCornerGeometry.swift
ActivationPreferences.swift
WorkspaceSessionObserver.swift
```

文件名可调整，但职责不能重新塞回一个更大的 `AppDelegate.swift`。

允许按任务修改：

```text
Sources/PagingPrototypeApp/AppDelegate.swift
Sources/PagingPrototypeApp/AppMain.swift
Sources/PagingPrototypeApp/AppArguments.swift
Sources/PagingPrototypeApp/KeyboardFocusController.swift（仅 ESC/dismiss seam）
Tests/PagingUITests/
Tests/AppGridUITests/（仅必要集成回归）
Docs/
PROVENANCE/
Workflow/
```

### 6.3 例外

- 若 import 系统 Carbon/HIToolbox 确需 `Package.swift` 调整，只能由 Main 单独修改并 Reviewer；不得加入第三方 dependency；
- 若需要 AppGridUI 暴露一个窄 cancel/reconcile seam，先由 Chief 证明 App 层无法安全组合，再建独占任务；
- 不得借 Phase 1G 清理或重构全部 B10 诊断代码；诊断移除必须是独立任务，先证明不影响生产修复和历史证据。

---

## 7. 推荐 Task DAG

```text
Gate 0 — Phase 1F 事实/生产默认/物理门/文档收口
   │
   ▼
T-1G-A — ADR + 纯 presentation/activation state machine
   │
   ├───────────────┬────────────────┐
   ▼               ▼                ▼
T-1G-B          T-1G-C           T-1G-D
Window/lifecycle  Status/Dock      Shortcut + Hot Corner 纯领域/adapters
   └───────────────┴────────────────┘
                   ▼
T-1G-E — AppDelegate 单点集成 + existing-feature reconcile
                   │
                   ▼
T-1G-F — 独立审查、能耗、真实设备与收尾
```

### T-1G-A — 纯状态机与 ADR

范围：Foundation 纯逻辑，无 AppKit side effect。

交付：

- `LauncherPresentationState`；
- activation source/command/dismiss reason；
- request generation/stale rejection；
- toggle arbitration；
- opposite-command interruption policy；
- Hot Corner state machine + fake clock；
- screen/corner geometry value model；
- shortcut registration outcome model；
- ADR-011/012 draft；
- property/sequence tests。

### T-1G-B — Window 与驻留生命周期

依赖 A。

交付：

- native-fullscreen vs overlay spike；
- 单 window controller；
- show/hide/present/dismiss；
- key/main/first responder；
- Reduce Motion；
- hide vs terminate teardown；
- multi-screen target；
- transition callback generation guard；
- window lifecycle tests。

### T-1G-C — Status Item 与 Dock Reopen

依赖 A；与 B 仅在协议稳定后、写集完全分离时并发。

交付：

- status item controller；
- dynamic menu validation；
- Show/Hide、Settings、Quit；
- Dock reopen adapter；
- fake command sink tests；
- 无窗口/失败/teardown tests。

### T-1G-D — Shortcut、Hot Corner 与 Preferences

依赖 A；不得修改 B/C 文件。

交付：

- public hotkey registrar adapter；
- Hot Corner poll scheduler；
- screen adapter；
- sleep/session observer；
- activation preferences store；
- default Off；
- conflict/suspend/re-arm/energy instrumentation；
- fake-clock/fake-screen/fake-registrar tests。

### T-1G-E — 串行集成

依赖 A/B/C/D；共享文件必须串行。

交付：

- AppDelegate 只做 composition root；
- initial launch / Dock / status / shortcut / corner 进入同一 coordinator；
- blank/ESC/app launch/window close → hide；
- explicit Quit → terminate；
- drag/search/folder/title/focus/layout flush 调和；
- B10/B11 回归；
- menu/settings wiring；
- smoke/CLI/test-mode 隔离；
- hidden/visible/reopen/rapid-toggle integration tests。

### T-1G-F — Review 与物理验收

- 每个行为任务独立 Reviewer；
- privacy reviewer 和 lifecycle reviewer 可并发只读，但维度必须分离；
- Main fresh full test/build/hash；
- disabled/enabled Hot Corner 能耗 A/B；
- 真实鼠标、触控板、快捷键、menu、Dock reopen；
- 多显示器可用时实测；没有硬件则诚实 BLOCKED；
- sleep/wake/lock/unlock 最小真实门；
- final docs/artifact manifest；
- 唯一下一阶段建议。

---

## 8. 并发与 Workflow 纪律

当前配置快照声明：

```text
workflow = chef-worker-reviewer-workflow 1.4
Main = current-main-conversation / max
Chief = glm-5.3 / max
Worker = deepseek-v4-flash:0731 / max
Reviewer = glm-5.3-flash:cloud / max
max_worker_concurrency = 3
```

这些是本地声明，不证明实际上游路由。执行时重新读取 `Workflow/config.json`，不要用本文覆盖配置。

提醒：Main 是当前主对话和 Runtime 编排中心；Chief 负责架构/计划级决策；Worker 实现；Reviewer 独立审核；必要时才用 Expert Worker。

每个阶段前必须记录并发检查：

```text
依赖是否已满足？
写入文件是否完全不重叠？
测试是否使用隔离 UserDefaults suite / timer / window / .build？
是否会同时写 AppDelegate、ADR、Package.swift 或 workflow state？
Reviewer 是否有稳定独立证据？
并发是否真的提高质量？
```

规则：

- Gate 0 串行；
- A 串行；
- B/C/D 只有协议和写集冻结后才能并发；
- E 串行；
- SwiftPM full build/test 默认串行，避免共享 `.build`；
- `AppDelegate.swift`、`Package.swift`、ADR canonical files、STATE/events updater 只能单写者；
- Reviewer 只读，不修代码；
- `events.jsonl` append-only；
- watchdog alert 只是疑似 stall，不是失败或替换 agent 的授权；
- 中断优先同 session 继续，不因超时更换模型；
- 不 commit/push/tag/reset/clean。

---

## 9. 自动化验证矩阵

### 9.1 Presentation state machine

- hidden + show；
- visible + show 幂等；
- hidden + hide 幂等；
- visible + toggle；
- presenting + repeated show；
- presenting + hide；
- dismissing + show；
- stale completion rejected；
- two sources same timestamp；
- hot corner repeated show 不反向 hide；
- quit dominates later requests；
- terminate teardown once。

### 9.2 Window lifecycle

- one process/one window；
- 20 次 show/hide 不增加 window/observer/timer；
- key/main/first responder restored；
- hide 不 teardown catalog/layout/status services；
- terminate 才 teardown；
- native full-screen transition interruption；
- target screen disappears；
- Reduce Motion；
- no duplicate Space/window；
- old async completion zero writeback。

### 9.3 Dismiss priority

- ESC during title edit；
- ESC during drag；
- ESC with folder open；
- ESC with search active；
- ESC with selection only；
- ESC from neutral visible → hide；
- blank click folder two-stage semantics；
- blank click search exit then hide；
- successful app launch → hide；
- failed/rejected launch → visible；
- window close button → hide；
- explicit Quit → process terminate。

### 9.4 Menu/Dock

- status item retained；
- Show/Hide label/enable state follows committed state；
- menu command goes through coordinator；
- menu available while hidden；
- Dock reopen hidden→show；
- Dock reopen visible→focus；
- no duplicate window；
- status item failure fallback；
- Quit always available；
- teardown removes target/action references。

### 9.5 Shortcut

- default Off = no registration；
- enable success；
- conflict/unavailable；
- reconfigure success；
- reconfigure failure rollback；
- disable/unregister；
- repeat debounce；
- duplicate event once；
- inactive app trigger；
- teardown；
- fake registrar only in unit tests；
- no general key stream observer。

### 9.6 Hot Corner pure state

- disabled zero action；
- starts inside zone no trigger；
- outside→inside→dwell trigger once；
- exit before dwell cancel；
- hysteresis re-arm；
- cooldown；
- repeated samples no duplicate；
- launcher visible pause；
- mouse button/drag suppression；
- sleep/session inactive suppression；
- wake requires exit/re-enter；
- screen geometry change cancels dwell；
- stale timer/session ignored；
- timer stop on disable/teardown。

### 9.7 Multi-screen geometry

- single screen；
- negative-origin screen；
- vertical/horizontal arrangement；
- different scale/resolution；
- pointer exactly on bounds；
- shared-edge/internal corner policy；
- screen removed during dwell；
- trigger screen becomes target；
- no screen ID persistence/logging。

### 9.8 Preferences

- default all system-wide triggers Off；
- encode/decode round trip；
- invalid enum fallback Off；
- future schema safe behavior；
- isolated suite；
- reset activation settings only；
- changing corner stops old service before new service；
- shortcut rollback；
- no coordinates/app data in defaults。

### 9.9 Existing feature regression

至少覆盖当前 full suite，再专项：

- 触控板分页 60Hz 参数不变；
- click app / Return app / folder member launch；
- top-level folder open；
- drag reorder/create/add/move-out/cross-folder；
- B10 production default click delivery；
- B11 row-boundary insertion indicator；
- search enter/exit；
- folder title edit；
- layout persist/restart/recovery；
- cancel drag then hide, no write；
- hide/show 后 page reuse 无串图；
- hidden 时 catalog refresh，show 后正确 reconcile；
- telemetry schema 无身份扩张。

### 9.10 静态红线扫描

新增/修改源码不得出现未经 ADR 批准的：

```text
addGlobalMonitorForEvents
CGEvent.tapCreate
AXIsProcessTrusted
IOHID
private API selector strings
LaunchBetter
Buho
license crack / bypass
pointer coordinate logging
frontmostApplication query
```

允许在 Prompt/文档的“禁止项”中出现上述文字；扫描器必须区分源码与政策文档。

---

## 10. 真实设备验收

### 10.1 构建身份

每轮记录：

```text
日期/时区
macOS 版本
Mac 型号
显示器数量、排列与实际刷新率
输入设备
Reduce Motion
activation preferences
shortcut registration outcome
Debug/Release
executable SHA-256
是否设置任何诊断 env gate
```

不得记录屏幕序列号、真实 app 清单、路径或 pointer 坐标。

### 10.2 单显示器矩阵

1. 菜单栏 Show → 可交互；
2. 菜单栏 Hide → 进程仍驻留；
3. Dock reopen → 同一窗口恢复；
4. 快捷键从其他普通 app 中触发 show/hide；
5. Hot Corner Off → 无触发；
6. Hot Corner On：快速掠过不触发，dwell 触发一次；
7. 留在角落不重复 toggle；
8. 离开再进入可再次触发；
9. 触发后立即拖拽/搜索/folder/启动 app；
10. app 启动成功后 launcher 隐藏但进程驻留；
11. 空白/ESC 隐藏；
12. Quit 真正退出。

### 10.3 快速竞态矩阵

- 快捷键连按；
- status item 与 shortcut 交错；
- Hot Corner presenting 时再按快捷键；
- show 动画中 ESC；
- hide 动画中 Dock reopen；
- drag 中 shortcut hide；
- folder title edit 中 Hot Corner/shortcut；
- screen change 中 presenting；
- 20 次循环无多窗、无卡住、无残留 timer。

### 10.4 多显示器

有多显示器时：

- 四角逐屏检查；
- 负坐标/上下排列；
- 内角/共享边误触；
- 每个入口的 target screen；
- 拔掉触发屏幕后的 fallback；
- 不在两个屏幕同时出现窗口。

无多显示器时标：

```text
MULTI_DISPLAY_PHYSICAL_GATE_BLOCKED_BY_HARDWARE
```

不能用单元测试冒充物理 PASS。

### 10.5 Sleep/Lock

- sleep 前 inside candidate，wake 后不得立刻弹出；
- lock/session resign 时不触发；
- unlock 后需重新离开/进入；
- observer/timer 没有重复注册；
- app hidden/visible/quit 均可恢复。

### 10.6 性能与动画

- 60Hz 真实设备 show/hide 不引入明显卡顿；
- 记录 transition duration 与异常样本；
- 120Hz 只有真实 120Hz 硬件才可写 PASS；
- 无硬件时继续：

```text
120HZ_PHYSICAL_GATE_BLOCKED_BY_HARDWARE
```

- Phase 1G 不重新宣称严格 `>25ms` 长尾已修复。

---

## 11. 测试与构建命令纪律

Main 最终至少运行：

```bash
swift test
swift build
swift build -c release
```

要求：

- exit 0；
- executed tests > 0；
- 报告精确 executed/passed/failed；
- 不能只写“all tests passed”；
- full suite 串行，避免多 Worker 争用 `.build`；
- 记录 Debug/Release hash；
- 对实际修改文件扫描 trailing whitespace、conflict markers；
- 仓库大量 untracked 时，`git diff --check` 不能证明全部文件；
- 测试的 UserDefaults、hotkey registrar、screen、timer、workspace notification 全部 fake/injected；
- 自动测试不得抢真实快捷键、操作真实 pointer、进入真实 Hot Corner 或污染真实 preferences；
- GUI/物理门与 unit tests 分开报告。

---

## 12. 停止条件

遇到以下任一项立即停止相关实现并交 Main/Chief：

```text
Phase 1F 生产默认点击/拖拽仍坏
必须使用私有 Space/WindowServer API
必须请求 Accessibility/Input Monitoring/Screen Recording
必须安装全局事件 monitor 或 CGEvent tap
必须读取系统 Dock/Launchpad 私有配置
必须修改 PagingCore/Timer 参数才能完成 activation
Hot Corner 空闲能耗门失败且无低成本替代
native fullscreen 与驻留 show/hide 无法可靠共存，且 overlay 方案改变用户语义未获决策
需要加入第三方 dependency 但无用户/Chief 授权
需要 activation/license bypass
需要复制第三方 UI、参数或文案
```

使用相应标签：

```text
BLOCKED_BY_PHASE1F_REGRESSION
SCOPE_EXPANSION_REQUIRES_USER_DECISION
PERMISSION_EXPANSION_REQUIRES_USER_DECISION
WINDOW_ARCHITECTURE_DECISION_REQUIRED
HOT_CORNER_ENERGY_GATE_FAILED
PHYSICAL_ACCEPTANCE_PENDING
```

不要为了“完成 Phase 1G”降低权限/隐私/物理门。

---

## 13. 最终报告必须回答

`Docs/PHASE1G_REPORT.md` 至少包含：

1. Gate 0 如何将 Phase 1F 的用户报告、binary、门控和 Workflow 对齐；
2. Phase 1F 最终 fresh baseline 与 hashes；
3. 选择了哪种 window architecture，为什么；
4. show/hide/toggle/quit 的最终状态机；
5. status item、Dock、shortcut、Hot Corner 各自默认值；
6. shortcut API、冲突和权限；
7. Hot Corner API、参数、能耗和 re-arm；
8. 多显示器和 sleep/lock 语义；
9. hide vs terminate 的 teardown 边界；
10. drag/search/folder/layout/launch 回归结果；
11. 自动测试精确计数、build exit、binary hashes；
12. 真实物理矩阵和硬件阻塞；
13. privacy/provenance 扫描；
14. 未解决问题；
15. 以下性能 tokens 的最终状态；
16. 唯一下一阶段建议。

继续保留：

```text
PRODUCT_TIMER_TOLERANCE_0MS
SHORT_TAIL_MITIGATED_BY_TOLERANCE
CAUSALITY_UNRESOLVED_FOR_GT25MS
```

除非本阶段获得新的因果证据，否则不得改写第三项。

---

## 14. 完成定义

只有同时满足以下条件，Phase 1G 才能写完成：

```text
Phase 1F Gate 0 真正关闭
单一 presentation coordinator 生效
驻留进程 show/hide/toggle/quit 语义通过
status item + Dock reopen 通过
shortcut 若启用则真实系统级门通过；否则明确 Off/Deferred
Hot Corner 若启用则隐私、能耗、单屏物理门通过；否则明确 Off/Failed/Deferred
基础入口不申请 Accessibility/Input Monitoring/Screen Recording 权限；四指入口如需额外权限须单独批准并验收
四指后台向内捏合物理门通过；不可用/Deferred 不算该项完成
私有框架如被采用，其范围、批准、失败降级与发布限制均已记录
无 global NSEvent monitor / CGEvent tap
无双窗口、旧 completion、残留 timer/observer
drag/search/folder/layout/app launch 无回归
fresh full tests 0 failures
Debug/Release exit 0
独立 Reviewer 0 BLOCKER / 0 MAJOR
文档、事件和 manifest 完整
```

如果 status/Dock/生命周期完成，但 Hot Corner 尚未通过能耗或物理门，必须写部分完成，不得把整个 Phase 1G 写成 PASS。

---

## 15. 下一阶段建议边界

若 Phase 1G 全部通过，下一阶段只允许提出一个候选：

```text
RECOMMEND_PROCEED_TO_PHASE_1H_PRODUCT_SETTINGS_AND_PACKAGING_READINESS
```

Phase 1H 可评估：正式设置窗口、Launch at Login、独立品牌/UI 接入、应用图标、签名/沙盒/公证准备和诊断代码去产品化。

但即使 Phase 1G 通过，也不自动授权：

```text
发布
签名/公证
安装 Launch at Login
删除历史证据
commit/push/tag
activation/license 逻辑
读取第三方实现或资源
```

如果产品优先级不同，先向用户提出决策，不自行扩大范围。



---

## 16. 新需求：四指向内捏合呼出启动器

### 16.1 用户需求与准确语义

用户原话：

> 我想，你再加一个功能，就是四指捏合可以启动。/Users/mac/Projects/LaunchBetter 在这个里面有关于这个功能的代码。你把这个也写到Prompt里面，然后写一个详细一点的、长一点的Prompt。

本轮将“启动”定义为：**当前进程已驻留时，呼出启动器界面**。
不表示进程完全退出后依然可以监听触控板，不授权新建后台 helper、LaunchAgent、登录项或常驻守护进程。

产品合同：

| 状态 / 动作 | 预期结果 |
|---|---|
| 驻留、隐藏、功能启用，四指向内收拢 | 请求一次 Show |
| 正在显示或已显示时再次捏合 | 幂等，不变成 Hide，不重置页面或搜索 |
| 正在隐藏时收到新捏合 | 协调器按最新有效 Show 意图处理，不直接抢窗口 |
| 四指向外张开 | 不触发呼出；本轮不实现张开关闭 |
| 四指平移 | 不触发捏合呼出 |
| 二指缩放或滚动、三指手势 | 不触发呼出，不劫持原动作 |
| 功能关闭 | 不订阅触点、不处理旧回调、不弹授权提示 |
| 进程退出 | 不再捕获；不能承诺仍可通过捏合启动进程 |
| 锁屏、睡眠、会话不活跃 | 不呼出，恢复后不能重放之前的手势 |

本轮默认严格四个有效接触点；参考实现的“至少四指”不是自动继承的产品要求。
如果实机证明严格四指不合理，应提交样本统计和取舍，经决策后修改，不得静默支持五指。

### 16.2 不随需求扩张的内容

不新增三指拖动、系统手势替代、向外张开关闭、鼠标手势、压力手势、多手同时识别。
不做系统事件屏蔽，不修改系统手势偏好，不杀掉其他手势软件，不读取其用户配置。
系统或其他工具同时响应时记录冲突，提供用户自行选择的说明，不使用私有手段压制系统行为。
四指入口不能绕过 ESC 层级、拖拽事务、搜索或文件夹的已有语义。

## 17. LaunchBetter 参考证据与读取白名单

### 17.1 本轮已核实的源文件

所有路径相对 `/Users/mac/Projects/LaunchBetter`：

| 文件 | 只读参考用途 | 不可直接推导的结论 |
|---|---|---|
| `Packages/LaunchPlatform/Sources/LaunchPlatform/PinchAnalyzer.swift` | 有效触点计数、质心平均半径、收缩/扩张识别 | 旧参数对本项目最优 |
| `Packages/LaunchPlatform/Sources/LaunchPlatform/MultitouchSupport.swift` | 动态加载、C 回调、设备订阅、owner 管理 | ABI 有公开稳定保证或不需要权限 |
| `Packages/LaunchPlatform/Sources/LaunchPlatform/GestureCaptureEngine.swift` | start/stop/restart、状态通知、回调到离散事件 | 注释中的性能/权限说法已得到当前实测支持 |
| `LaunchBetterApp/ActivationCoordinator.swift` | onGesture 到主线程窗口入口的接线 | 应整体迁移窗口或权限处理 |
| `Packages/LaunchPlatform/Tests/LaunchPlatformTests/PinchAnalyzerTests.swift` | 旧用例的覆盖思路 | 旧测试已在本轮运行或覆盖新合同 |
| `Packages/LaunchPlatform/Tests/LaunchPlatformTests/GestureEngineLifecycleTests.swift` | 生命周期回归场景 | 新后端线程安全已证明 |

必要的仓库 AGENTS.md 可读取用于遵守参考库只读边界。
本轮已读前四项的相关代码；测试文件仅定位，不把它们当已执行证据。
未来执行者需记录实际读过的文件与范围，不沿着 legacy 注释追入旧仓库或逆向目录。

### 17.2 已核实的实现事实

1. `PinchAnalyzer` 默认 requiredFingerCount 为 4，但判定使用 `>=`，实际上接受四指及以上。
2. 识别量为接触点到质心的平均距离相对起点的变化。
3. 旧默认 threshold 为 0.18、cooldown 为 0.2 秒；它们只是参考事实，不是新项目验收值。
4. 旧算法超过阈值后更新起始距离；冷却结束后，持续手势可能再次达到条件。因此不能把冷却等同于“一次接触会话只触发一次”。
5. 采集包装通过 dlopen/dlsym 加载系统私有目录中的 MultitouchSupport.framework，使用设备与触点回调符号。
6. 参考 C 回调忽略 count <= 0；它没有给下游保留 device 参数，且把 state != 0 解释为活跃。
7. 包装中包含 legacy 布局对齐注释；这提示 ABI 与来源需要核实，并不证明当前系统所有状态值都能这样解释。
8. `ActivationCoordinator` 把 pinchIn 映射为 show，把 pinchOut 映射为 hide。新需求仅采纳前者。
9. 引擎包含锁、owner token、generation 和状态通知；不能因为存在这些字段就宣布没有竞态。
10. 引擎把传入 timestamp 包装成 Date。新实现必须明确时钟语义，不能把未知时间基准冒充墙钟。

上面是源码阅读证据，不是运行结论。没有本轮后台触控板验证、权限验证或能耗采样。
本轮尝试访问 Apple 在线资料未得到可用正文；不得把本文件写成已完成官方 API/分发政策核验。

### 17.3 参考报告要求

新增 `Docs/FOUR_FINGER_REFERENCE_AUDIT.md`，逐项包含：

- 文件、行号、内容摘要、读取日期；只摘必要短段，不复制整份参考源代码。
- 哪些是代码事实、哪些是注释、哪些是推断、哪些经本机验证。
- 来源标注及未核实的权利依据。
- 提取出的行为规格，准备重新设计的部分，明确拒绝沿用的部分。
- 私有 ABI、触点状态、零触点事件、设备混流和锁序的风险清单。
- 如果拟直接复用任何代码：先提交范围和依据，不能先复制再补说明。

## 18. Gate G-P0：API、权限与交付路线决策

### 18.1 不允许用假能力绕过决策门

“窗口内能收到 magnify/触摸事件”不等于“应用隐藏且非前台时能识别四指”。
普通缩放事件有数值变化，也不等于带有四个独立触点身份。
必须独立验证后台可达性、手指数可判定性和触点生命周期，不可用前台模拟冒充系统级实现。

优先检索当前 SDK 和 Apple 文档，记录准确接口及适用范围；不能凭记忆承诺存在公开全局四指 API。
若未找到符合需求的公开接口，写“本轮未找到可验证方案”，而不是无证据宣布全平台绝不可能。

### 18.2 决策表

| 路线 | 工作 | 可进入程度 |
|---|---|---|
| 可验证公开 API | 用最小实验核实后台四指能力 | 通过证据审查后正常接入 |
| 私有 MultitouchSupport 后端 | 提交 ADR、来源核实、兼容性/权限/退出策略 | 用户明确接受私有后端风险后，才运行采集实验及接入 |
| 后端仍不可用或用户不接受私有路线 | 完成纯识别器、provider 协议和其他入口 | 四指标为 BLOCKED，不得标完成 |

本次“参考这份代码”不是无限制私有 API 或权限授权。Main 汇总需要用户确认的具体决定；Worker 不各自询问。
等待决定时继续做不依赖真实采集的纯逻辑测试和既有 Phase 1G 入口，不把整个阶段空转挂起。

仅为获批四指 provider 允许窄范围私有 MultitouchSupport 例外；不解除私有 AppKit/WindowServer、事件 tap 和全局键盘监听禁令。
如需 Input Monitoring，必须独立说明用途、实测依据、拒绝后的功能降级；未经同意不申请、不自动打开系统设置。
不因为没回调就认定用户拒绝权限；无触摸、无设备、设备类型、ABI 不支持、注册失败都可能产生相似现象。
设备枚举成功也不能单独证明权限已授予。

### 18.3 分发与默认状态

本阶段不做商店上架、签名、公证或公开发布结论。私有接口能运行不等于符合分发政策。
未来选定分发渠道时单独核查最新要求，不通过隐藏符号字符串、伪装调用或隐瞒权限规避审查。

提议默认策略：未验证或未获批时 `fourFingerActivationEnabled = false`。
测试构建可在用户批准后显式启用；阶段收口前让用户确认最终开关默认值。
“运行时可关闭”不等于“公开 API 构建中没有私有实现”。ADR 必须区分编译排除与运行时禁用。

## 19. 四指识别器：行为规格，不照搬旧状态机

### 19.1 数据与职责

建议的职责边界如下，名称只是设计建议，不要求创建同名类型：

```text
TouchProvider -> validated device-scoped frames -> PinchRecognizer
             -> discrete activation request -> PresentationCoordinator -> Show
```

- 平台 provider 只负责设备、有效生命周期、采样和值转换。
- 识别器使用值类型和可注入单调时钟，不能引用窗口、catalog、layout store。
- 协调器只接收离散请求，不接收触点序列或实时几何。
- 设备标识只作为进程内不透明 token，不写磁盘、不跨运行关联。
- 若实际 API 无法提供可靠的接触 identity/end/reset 语义，先解决可行性，不杜撰字段。

### 19.2 状态机合同

建议状态：Disabled / Idle / Candidate / Recognizing / Fired / WaitingForRelease / Suspended。
可合并状态，但必须保留以下可测语义：

1. Idle 收到恰好四个有效触点即建立候选（首帧基线；无稳定窗口——2026-09-06 实机定案：快速捏合无静止段，稳定窗口模型识别不了）。
2. 落指不同步不能让第四根手指的出现被当作收缩；基线 = 候选段首帧（首帧不判定收缩）。
3. 从基线计算归一化收缩量；阈值、时间上限必须分别命名（稳定窗口/噪声容忍已随首帧基线模型删除）。
4. 四指平移不应产生收缩；旋转、抖动和噪声不能积累成误触。
5. 五指进入、触点替换、设备改变、数据过期必须取消或重建候选，不能用旧基线继续识别。
6. 触发后锁存 Fired；同一接触会话无论停留多久只能发出一次请求。
7. 冷却只是附加保护，不是重新武装的唯一条件。
8. 全部离面或可靠的接触结束才进入可重新武装状态；新手势必须建立新基线。
9. 四指短暂变三指再变四指不能绕过锁存产生第二次触发。
10. 缺帧、乱序、非有限数、非法计数、近零初始半径都要安全拒绝。
11. Suspend/stop/disable/restart 必须清掉基线、会话和待派发意图。
12. 不将“无回调超时”直接等价为全指释放；如后端缺少结束证据，设计保守且可验证的恢复策略。

几何算法可以采用独立实现的平均半径或其他可解释指标；不能以“看起来像四指”替代明确测试。
必须测试同手势整体平移/旋转后的等价性，以及形状变化、接触点加入/删除产生的假收缩。
参数在独立合成样本与实机验证后定案，不把参考代码 0.18 / 0.2 秒直接宣称最优。

### 19.3 时钟与事件身份

统一用单调时间比较持续时间，不用系统时间修改可影响的 Date 差值作手势计时基准。
后端原始时钟与应用单调时钟若不同，显式转换或保持在同一域，禁止直接相减。
记录会话 generation 和事件 token，用于派发去重和丢弃旧事件，不记录原始手指轨迹。
低频统计可记录识别次数、取消原因、延迟分布，但不得记录可还原手势的坐标序列。

## 20. 采集后端、线程与生命周期

### 20.1 FFI 与私有 ABI 防护

获批私有后端后才执行本节真实采集：

- 函数符号缺失时在注册前失败；部分初始化失败必须按所有权撤销。
- 明确结构布局、对齐、字段解释、函数签名的证据，记录系统版本与架构。
- 指针只在有效回调期间读取；传出纯值副本，不把系统 buffer 指针放进 Task。
- 检查空指针、计数上限、非法数值；不能宣称这些检查足以保证未知 ABI 安全。
- 不把 `state != 0` 无条件当作正在接触；核实 hover/开始/结束/取消的分类。
- 保留设备区分，不合并两个触控板各两个手指为四指。
- 零触点帧、device disconnect 和 cancel 不能被高频压缩逻辑吞掉。
- 热插拔和重枚举不得重复注册；旧设备事件不得进入新设备识别器。
- ABI 无法安全验证时隔离为不可用，不不断重试可能崩溃的内存解释。

### 20.2 回调与锁序

禁止在原始采集回调里执行窗口操作、扫描应用、读写布局、同步等待主线程或 JSON 编码。
在确认事件发生时才派发一次主线程请求，不为每个触点帧创建一个 Task。

可以在串行队列处理，也可以窄锁保护状态，但必须记录选择和积压策略：

- start/register 或 stop/unregister 是否可能同步重入回调；
- 不持有回调需要的锁调用可能等待回调返回的系统 stop/unregister；
- user closure 在锁外调用；
- 缓冲必须有界；保留 begin/end/cancel，不能“只留最新帧”却丢掉重新武装条件；
- 过载丢帧应取消或保守重置，而不是凭不完整轨迹发出 Show；
- teardown 期间 late callback 与已排队主线程事件必须同时失效。

仅后台检查 running 不足以阻止关闭后队列里的 Show；主线程消费时也要验证 generation、功能开关和进程状态。
owner/generation 字段不是线程安全证明，Reviewer 必须检查真实锁序和所有权。

### 20.3 驻留与隐藏

启用四指入口时，隐藏窗口不能 stop 整个采集服务，否则无法再次捏合呼出。
隐藏后仍应停止不必要的 UI 帧泵、动画和绘制工作；四指采集与 UI 动画的生命周期分离。
真正 Quit、关闭功能、睡眠/会话不活跃时按方案停用或暂停；恢复时建立新 generation。
不得在 deinit 中承担主要注销逻辑，不通过永久泄漏库句柄或 callback box 回避安全退出。

start/start、stop/stop、start-stop-start 和退出时异步回调都必须可测。

## 21. 与呈现协调器、配置和现有交互整合

### 21.1 Show 的唯一入口

四指识别器发送 `show(source: fourFingerPinch, eventToken: ...)` 或等价语义。
不得直接调用窗口 toggle、创建第二个窗口、扫描应用、写布局或绕过协调器状态机。

- 已显示：无副作用，不清搜索、不关闭文件夹、不移走键盘焦点。
- 正在显示：合并为已有目标，不重复启动动画。
- 正在隐藏：执行已接受的最新意图策略，旧完成回调不能把新 Show 隐藏。
- 正在 Quit：拒绝新请求，不能重新激活进程。
- 手势触发但原应用还有手指未离面：避免余下触摸立刻在启动器上翻页或点开应用。

最后一项需要有限的输入交接策略：优先基于会话结束，而非全局吞事件或任意长时间禁用交互。
候选策略及键盘/鼠标不受误伤的测试写入 ADR；不能为了解决手势残留破坏已验收翻页核心。

### 21.2 配置与可用性

配置至少能表达：开关、后端可用性、未验证状态和明确失败原因。
若有参数调节先作为诊断选项，不立即扩张为复杂设置界面。

状态建议：Off / Checking / Ready / NoDevice / Unavailable / PermissionNotConfirmed / Suspended。
不要用 “Enabled=true” 冒充 “Ready=true”。用户打开开关但后端失败时，显示事实并保留菜单/Dock/快捷键入口。

持久化只写用户开关及获批配置，不写触点、设备序列号、原始坐标或后台应用身份。
配置迁移遵循现有 schema；设置恢复不自动触发权限弹框或在启动时呼出窗口。

## 22. Task DAG、写入所有权与接力

先由 Main 读取项目当前角色配置、状态、计划；如阶段已推进，不覆盖已完成任务。
Chief 处理架构与本轮来源/API 边界修订；Main 不借文档扩展直接写业务代码。

建议任务：

| 任务 | 输出 | 依赖 / 写入边界 |
|---|---|---|
| G-P0 参考与可行性决策 | 参考审计、API/权限 ADR、用户决定 | 文档；不写真实采集实现 |
| G-P1 独立识别器 | 纯值状态机、时钟、确定性测试 | G-P0 行为合同确定；独占识别器与对应测试 |
| G-P2 平台 provider | Mock 与获批真实后端、生命周期测试 | 真实后端需 G-P0 批准；独占平台目录 |
| G-P3 配置与入口状态 | 开关、迁移、状态展示 | 契约确定；独占设置模块 |
| G-P4 协调器接线 | 去重、generation、隐藏与 Quit、交接 | P1/P2/P3 及基本协调器可用；共享入口串行整合 |
| G-P5 独立评审 | 风险、diff、证据、回归报告 | 稳定快照；Reviewer 不写实现 |
| G-P6 实机与性能 | 人工矩阵、A/B、失败分类、调参记录 | 候选构建明确 |
| G-P7 收口 | 门禁、manifest、报告与接力 | 测试、评审、用户验收齐备 |

只有接口稳定、依赖已满足且写入不冲突时 P1/P2/P3 可并行。
Package.swift、AppDelegate、协调器接线和项目配置由唯一集成 Worker 修改。
其他 Worker 提交所需变更说明，不能一起碰共享文件。
Reviewer 可并发阅读稳定的独立变更；共享 SwiftPM 构建和 GUI/设备实验串行。
没有隔离工作区就不能并行修改同一文件，再寄希望于事后合并。

本次只是写 Prompt，不创建虚假的 task_started、review PASS 或 agent 派发事件。
未来执行时按现有工作流脚本记录真实事件，不为了接力伪造旧历史。

## 23. 自动化与物理验收矩阵

### 23.1 自动化最低覆盖

| 编号 | 验收场景 |
|---|---|
| P01 | 严格四指内收超过阈值一次触发 |
| P02 | 同一接触会话持续收缩超过冷却也只触发一次 |
| P03 | 全指释放后新会话可再次触发 |
| P04 | 二指缩放、三指平移、五指均不误触 |
| P05 | 四指平移、旋转、微抖动不误触 |
| P06 | 顺次落指不把成员加入当成收缩 |
| P07 | 四变三再变四不重复触发已锁存会话 |
| P08 | 更换 contact identity 或 device 不继承基线 |
| P09 | 两设备各两指不能组合触发 |
| P10 | 零触点、取消、断开、过期数据能正确结束或取消 |
| P11 | NaN/Infinity、近零半径、超大计数、安全边界拒绝 |
| P12 | 回调乱序、时间回退、过载丢帧不会错误 Show |
| P13 | 开关关闭、暂停、Quit 后 late callback 和排队事件被丢弃 |
| P14 | start/stop 重入、旧 generation stop 不影响新订阅 |
| P15 | 同步重入假后端验证注册/注销无死锁 |
| P16 | 显示中/隐藏中/已显示时 Show 幂等且最终状态正确 |
| P17 | pinchOut 无 Hide；没有偷偷沿用参考的张开关闭 |
| P18 | 配置缺项迁移、不可用后端、拒绝权限有明确降级 |
| P19 | 输入交接不引发误翻页/误启动，不永久禁键盘鼠标 |
| P20 | Folder、搜索、打字机导航、拖拽持久化、应用启动回归 |

测试夹具使用合成匿名触点，不提交真实触控板轨迹。
测试必须断言“不该触发”，不能只有 happy path。
Mock 测试只能证明合同，不证明私有 ABI、真实权限或后台可用性。
新测试数由实际执行统计，不承诺固定总数，不把零执行当通过。

### 23.2 实机候选门

本表数值是本轮建议门槛，执行前在验证计划中定案；不能采样完根据结果下调阈值。

| 门 | 操作 | 通过要求 |
|---|---|---|
| M01 后台呼出 | 普通应用在前台，启动器隐藏，正常速度捏合 20 次 | 至少 19 次成功，零重复开关，失败逐条记录 |
| M02 慢速/快速 | 慢速和快速各 10 次 | 每组至少 9 次成功，零二次触发 |
| M03 可见幂等 | 启动器已显示再捏合 10 次 | 不隐藏、不清状态、不重建窗口 |
| M04 反向手势 | 向外张开 20 次 | 零错误呼出/隐藏 |
| M05 负样本 | 二指缩放/滚动、三指动作、四指平移、五指各 20 次 | 零误呼出，保留观察到的系统冲突 |
| M06 连续手势 | 触发后不抬手继续收拢/停留，再全释放重来 | 单会话一次，新会话可重新触发 |
| M07 多入口 | 手势与快捷键/菜单/角落近同时触发 | 无双窗口、闪烁、过期 completion |
| M08 生命周期 | 关闭开关、恢复、睡眠唤醒、锁屏解锁 | 不重放旧手势，不失去其他入口 |
| M09 无设备/不可用 | 假后端自动化 + 真实可得环境 | 不崩溃、不反复弹权限、保留替代入口 |
| M10 设备差异 | 内置/外置、多设备、插拔（有硬件才跑） | 分设备报告，未测不写 PASS |
| M11 输入交接 | 捏合呼出后继续触摸及立即键盘操作 | 无误翻页/误启动，键盘焦点正确 |
| M12 回归 | Folder、搜索、拖拽、重启布局恢复、分页 | 原已验收能力不退化 |

构建记录包含源码状态/变更 manifest、二进制 hash、系统版本、CPU 架构、触控板类别与开关状态。
不能仅靠一条 `gestureDetected` 日志认定窗口已正确显示。用户肉眼验收或获批的低干扰测量另行记录。
权限未授予场景与从未申请场景区分，不擅自重置系统 TCC 数据库制造测试条件。

### 23.3 性能和能耗门

在同一 Release 构建、同一屏幕环境，以功能 Off/On 作 A/B 或 ABBA：

- 隐藏空闲，记录 CPU、唤醒、内存、设备回调数量；不能凭没有日志宣布零开销。
- 可见静止与连续分页分别比较；手势采集不能重新启动隐藏 UI 帧泵。
- 主线程只能收到离散意图，不承受每帧触点任务洪泛。
- 至少每条件三轮固定时长采样，建议空闲每轮 60 秒；先写阈值与测量方法再运行。
- CPU/wakeup 单位、采样工具和噪声必须写明，不用机器间不可比的单个数值定优劣。
- 报告触点处理与识别延迟的 p50/p95/max；要区分识别时间和窗口真正可交互时间。
- “手势开始到识别”的时长含用户手速，不拿它冒充纯软件延迟。
- 物理分页对照用真实触控板；SELFDRIVE 不能代替物理门。
- 20–25ms 短尾改善事实保留，>25ms 长尾仍未解决；新入口不得成为宣称根因修复的理由。
- 已知会显著干扰结果的重型 trace 不作为唯一因果证据。

如出现可重复的明显分页退化、任务积压或隐身忙循环，停止合入真实后端，保留独立模块以便修复。

## 24. 文档、检查点与交付格式

沿用 §5 的基础文档，额外增加或合并到已有同主题文档：

```text
Docs/FOUR_FINGER_REFERENCE_AUDIT.md
Docs/FOUR_FINGER_ACTIVATION_SPEC.md
Docs/FOUR_FINGER_ACTIVATION_VALIDATION.md
Docs/FOUR_FINGER_ACTIVATION_RESULTS.md
Docs/PHASE1G_CHECKPOINT.md
```

ADR 使用当前仓库下一个可用编号，不占用或覆盖既有 ADR。
至少记载 API/权限路线、独立实现来源边界、识别会话、设备隔离、锁序、输入交接、默认开关和私有实现排除方式。

Main 持续更新一个简短接力检查点，不把全量日志塞进 MEMORY：

1. 当前任务、当前构建、测试实际统计；
2. 用户已确认的决定及原话范围；
3. 事实 / 假设 / BLOCKED / 未跑门；
4. Worker / Reviewer 的文件所有权和真实会话状态；
5. 下一条具体动作、所需权限和停止条件；
6. 性能三个 token 与参考接触声明；
7. 样本和报告位置，不包含真实触点原始轨迹。

测试、代码审查、实机验收和发布资格分开汇报。
静态扫描对获批私有符号只允许精确模块白名单，不能全局取消红线扫描。
Docs 中的参考路径允许出现；生产代码不引入第三方品牌或绝对源仓库路径。

## 25. 修订后的阶段完成门与开始指令

### 25.1 完成门

除了 §14，必须回答：

- 用户要求的**后台四指向内捏合**是否已经真实可用？
- 使用何种后端？是公开接口还是获批私有接口？
- 权限是什么？哪些经过真实验证，哪些仍未知？
- 严格四指、一会话一次、松手重置、设备隔离是否通过？
- 向外张开是否保持无动作？
- 隐藏驻留仍能呼出、真正退出后停止是否通过？
- 误触、成功率、能耗和分页回归是否经过物理验证？
- 用户是否确认最终默认开关？未确认不得擅自默认启用。
- 来源与既有接触是否诚实记录，没有宣称未经证明的 clean-room 或发布合规？

状态必须可分解：基础入口 PASS / 四指自动化 PASS / 四指物理 PASS / 兼容性未测 / 分发未评估。
如果四指功能因私有接口决定、权限、ABI 或设备限制没完成，整体写 PARTIAL 或 BLOCKED，不能把“接口已预留”写成用户功能完成。
120Hz、其他设备或其他 macOS 未测，逐项留 NOT_RUN，不妨碍描述已验证的当前设备结果。

### 25.2 执行者开始时先做这些

```text
1. 读取目标仓库 AGENTS.md、MEMORY.md、Workflow 当前状态与本 Prompt 全文。
2. 回读目标：Folder 不重做；新增驻留入口与后台四指向内捏合 Show。
3. 对账 Gate 0；历史状态与测试数不可当实时事实。
4. 列出来源白名单、禁止目录、性能冻结值、四指 API/权限决策门。
5. 提交 Chief 的架构与任务拆分，再按项目工作流调度。
6. 可以先做纯识别器/Mock/其他入口；真实私有后端需用户明确确认后再运行。
7. 保持每项工作的文档检查点、独立 Reviewer 与实机门。
8. 不 commit/push/tag，不发布，不修改 LaunchBetter，不读取 Buho 逆向资料。
```

遇到决策门汇总一次明确的问题；不要反复询问已经定案的内容，不要拿假进度绕过门禁。
最终交付是用户可验证的功能与证据，不是以篇幅、测试数量或 Worker 自评替代实际结果。
