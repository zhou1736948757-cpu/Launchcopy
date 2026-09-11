# Project Memory

<!-- chef-worker-reviewer-workflow:memory:start -->
## Durable project memory

- Workflow version: `1.4` (v1.4.1 repair)
- Project: `PagingPrototype`
- Initialized at: `2026-08-28T14:38:59+09:00`
- Artifact root: `Workflow/`
- Source contract: `AGENTS.md`
- Runtime state: `Workflow/STATE.json`
- Runtime events: `Workflow/events.jsonl`
- Watchdog settings: `Workflow/watchdog.json`
- Role heartbeats: `Workflow/heartbeats.json`
- Watchdog alerts: `Workflow/watchdog-alerts.jsonl`

### Runtime configuration summary
<!-- chef-worker-reviewer-workflow:runtime-config:start -->

- Main/Orchestrator model declaration: `current-main-conversation` (current main conversation; routing may be unverified)
- Chief model: `glm-5.3` (config.json; MEMORY 由 5.2 对齐)
- Worker model: `deepseek-v4-flash:0731`
- Reviewer model: `glm-5.3-flash:cloud`
- Worker maximum concurrency: `3`
- Main thinking depth: `max`
- Chief thinking depth: `max`
- Worker thinking depth: `max`
- Reviewer thinking depth: `max`
- Configuration file: `Workflow/config.json`
- Watchdog interval: 600 seconds by default; suspected stalls are reported to Main for a decision

<!-- chef-worker-reviewer-workflow:runtime-config:end -->

### Project facts

- 工程根：`/Users/mac/Projects/Launch_Copy/PagingPrototype/`；Prompt：`/Users/mac/Projects/Launch_Copy/PHASE1_PAGING_PROTOTYPE_PROMPT.md`（SHA-256 `06594a34677474d5ff2c88b8d65cc44c4f6a6958db4fd0629cf89790e4bf16e4`，CONTEXT_LEDGER §8.8）
- 工具链（2026-08-28 Step 0）：Xcode 26.6 (17F113) / Swift 6.3.3 / macOS 26.5.2 (arm64)
- 治理文档：RISK_REDUCTION_PLAN / CONTEXT_LEDGER / SOURCE_MANIFEST 仅 Main/Chief 可读；实现 worker 不接收其来源审计细节

### Confirmed decisions

- 许可路线 B（独立实现，面向闭源/专有目标），不复制 LaunchBetter Swift 源码/测试/注释/文件结构（CONTEXT_LEDGER §8.4）
- Phase 1A 范围：只验证分页交互引擎与页面承载；搜索/文件夹/拖拽/Hot Corner/数据库/应用扫描/正式视觉延后 Phase 1B
- 能力对标 = 用户可观察结果层能力，不指逐帧轨迹/精确参数/内部结构一致（Prompt §2.1）
- 实现 worker 用 fresh context，只接收 Prompt + Apple 公开文档 + 新工程自身文件
- `max_worker_concurrency = 3`（2026-08-28 用户调整，`Workflow/decisions/2026-08-28-concurrency-3.md`）
- 生产默认 `Timer.tolerance = 0ms`（`PRODUCT_TIMER_TOLERANCE_0MS`，T-A4-0ms，2026-08-30）；T-A5 物理验收 PASS（用户定案 2026-08-30）→ 短尾改善 `SHORT_TAIL_MITIGATED_BY_TOLERANCE`（仅短尾，非全部卡顿）；长尾 >25ms 仍 `CAUSALITY_UNRESOLVED`，不宣称已修复

### Important discoveries

- 中断后释放决策以 **committedPage 为基准**（D9），非接管点：反向接管后小幅回拉回弹到 committed 页，属正确语义（T-worker-b，2026-08-28）
- 边界阻尼作用于**越界增量**而非绝对位置；overscroll 深度上限 maximumOverscroll（RM=0），向内回拉不阻尼
- teardown 第一时间置 `isTearingDown`，全部入口首查短路——"无残留回调"的单一机制
- momentum 分工：momentumChanged 事件驱动；momentumEnded 后速度 > velocityThreshold×5% 进入 tick 驱动滑行（momentumDecay 每帧衰减）
- ended 后无 momentum 事件时 UI 层必须调用 `finishGesture()` 触发释放决策（Core 停留 tracking(released)）
- settle 完成判据：位置容差 1e-3 页 + 速度容差 0.05 页/s；spring ω0 = ln(100)/(ζ·duration)——文档化实现常量，非交互参数
- CoreHarness（固定 dt、显式时间戳、事件记录）可复用于 UI 集成测试

Record findings that remain useful after the current task ends.

- macOS 14 的 display link 入口是 `NSView.displayLink(target:selector:)`（`CADisplayLink.init` 在 macOS 不可用）
- 手势速度估计以 session 内 dt（began 为基准）；UI 不得在 `.ended` 事件内调 finishGesture（否则丢失 fling 速度），由下一事件触发
- 布局风暴守卫：`layout()` 仅当 |bounds.width − lastLayoutWidth| > 0.5 才 setPageWidth+relayout
- Core→UI 事件转发 box 必须强捕获（弱捕获 = 事件静默丢失）
- 测试助手 deltaX = 手指意图位移（自然滚动下 scrollingDeltaX = -deltaX）

### Known pitfalls

- 旧 `.build` 不是当前构建证明；清洁构建须从零开始
- 改名 ≠ 独立实现证明；需要需求驱动状态模型 + 架构记录
- 来源扫描通过 ≠ 原创性证明；仅泄漏预警
- `exit_code == 0` 且 `executed_tests == 0` = INVALID_TEST_EXECUTION
- 自动化性能测试不能替代真实触控板物理门
- guardrail 脚本 `validate_task_plan.py` 要求任务 ID 大写 `T-` 前缀、`## Objective` 与 `## Expected / Allowed Write Scope` 段名（已归一化）

### User constraints

- **强制 Worker/Reviewer 分工（2026-08-30 用户明确固化，除非用户明确关闭）：** Main 一律不得直接实现/修改业务代码（Sources/ Tests/ 等）——所有实现/修复必须先派发 Worker 实现、再由独立 Reviewer 评审（PASS 才合主线/重建/发布）。Main 只负责 dispatch / 顺序 / 并发 / 证据 / 状态 / 运行时适配。用户说"记得要使用 Workflow / 使用 Worker Reviewer / 不要自己改代码"即指向本条。
- 禁止读取 Prompt §1.3 全部路径（BuhoReverseNotes、LaunchBetter/Packages、LaunchBetterApp、2026-08-25-buho-launchpad-reverse）
- 参数来源类别仅限 5 类，禁用 REVERSE_ENGINEERING_COPY / OLD_SOURCE_TRANSLATION / UNKNOWN_ORIGIN
- 物理门不可虚标：60Hz/120Hz 须真实触控板；120Hz 无证明时标 BLOCKED
- Package.swift 由 Main 独占；Worker 不得并行修改
- 不自动 commit/push/tag/release（除非用户明确要求）；不修改 LaunchBetter / BuhoReverseNotes

### Durable risks

- 来源污染：fresh worker 误触禁止来源须立即 CONTAMINATION_LOG + BLOCKED_FOR_REVIEW（owner: Main，next: 每次 dispatch）
- 120Hz 环境不可用 → 物理门 BLOCKED（owner: Main，next: T-step8 确认设备）
- 状态模型缺陷导致 UI 返工（owner: Chief，next: T-step1 ADR-001 自查）

### Memory candidates

Worker and Reviewer may propose additions here in their Result/Review artifacts. Main is the Memory Gatekeeper and decides whether a candidate has durable value before merging it into this file.

### Retention boundary

Do not record Worker/Reviewer started or finished events, routine PASS/FAIL trace, shell exits, retries, interruptions, continuations, timeouts, waiting, status sync, concurrency checks, or ordinary tool logs here. Those belong in `Workflow/events.jsonl`, `Workflow/STATE.json`, task artifacts, results, reviews, or decisions.

### Update rules

- Keep this file concise, high-density, and append-oriented.
- Do not delete old history during v1.3 → v1.4 compatibility migration.
- Record a Memory Delta when a Chief decision adds, supersedes, or removes durable knowledge.
- Never store secrets or sensitive personal data.
<!-- chef-worker-reviewer-workflow:memory:end -->

## Chief-Proposed Memory Candidates (2026-08-28 Initial Planning)

> **Main gate：已批准（2026-08-28）**。Chief 在初始全局规划中提出的全部候选（Confirmed Decisions ×4、User Constraints ×6、Durable Risks ×3、Known Pitfalls ×5）已由 Main 审查并并入上方 managed 区对应章节；本段仅作批准记录，内容不再重复。

## Phase 1C planning memory candidates (2026-08-29, Chief Initial Global Planning)

> **Main gate：已批准（2026-09-02）**。Phase 1C 已执行完毕（526 tests；键盘门 PASS_USER_REPORTED），Chief 候选全部经实机/自动化验证吸收：键盘跨页 idle-only 合成手势、AppLaunchController.handleCell 复用（无并行启动路径）、焦点身份 revision-stable 对齐 ItemBindingToken、增量焦点视觉、无全局 NSEvent monitor/Accessibility 权限、PagingCore 冻结、诊断 token 保持——均已并入上方 managed 区对应章节或由 1C 报告固化；本段仅作批准记录，内容不再重复。

### Confirmed decisions (Phase 1C)

- Phase 1C 范围 = 键盘焦点 + 方向键导航 + Return/Enter 启动；Escape/Tab 仅文档化策略；其余按键延后。不扩大进搜索/文件夹/Hot Corner/120Hz/vsync/帧卡顿修复（Prompt §3.5）。
- 诊断状态保持 `CAUSALITY_UNRESOLVED` / `PRODUCT_DEFAULT_UNCHANGED`；不宣称任何卡顿已修复；不改生产默认 `Timer tolerance = 0ms`、帧源或 PagingCore 参数。
- `Sources/PagingCore/` 冻结；键盘层放 `AppGridUI`（焦点 domain）、`PagingUI` 窄 seam（跨页）、`PagingPrototypeApp`（responder + 启动装配）。
- 键盘跨页 = 经既有输入路径（`handleScrollInput` → `ScrollInputMapper` → `PagingCore`）的**合成归一化手势**，仅当 `core.state == .idle`；非 idle 延迟/忽略，不破坏触控板手势/settle。Core 无 programmatic page API，故用既有公开行为入口表达（Prompt §3.3）。
- 键盘启动复用 `AppLaunchController.handleCell(_:)`（revision → AppID → 文件存在性 → NSWorkspace 共享校验管线）；无并行启动路径绕过 stale 防线。
- 焦点身份 revision-stable 且与 `ItemBindingToken` 对齐：`catalogRevision + pageIndex + slotIndex + appID + presentationID`；迁移 = successor → predecessor → clamped → empty（镜像 `CatalogPlanner.remap`）。
- 单一键盘代理（非每 cell responder）；accessibility 焦点、视觉焦点、启动对象保持一致（Prompt §4.2 允许的替代）。
- 焦点视觉增量应用（unhighlight 旧 / highlight 新），不每按键重建 view tree。
- 不改 `PagingTelemetry` 契约；键盘影响经键盘控制器上的中性计数器报告（如 `keyboardPageTurnCount`），不新增 telemetry 字段。

### User constraints (Phase 1C)

- 无全局 NSEvent monitor、无 Accessibility 权限、无同步磁盘 I/O / 图标读取、不每按键重建 view tree。
- 键盘路径不得从 cell 直接读 URL 后调 `NSWorkspace`（必须经 AppLaunchController 校验）。
- 不 commit/push/tag/reset/clean；不修改 LaunchBetter / BuhoReverseNotes。

### Durable risks (Phase 1C)

- 键盘跨页破坏进行中的触控板手势/settle → 仅 idle 时跨页，测试覆盖（owner: Main，next: T-1C-B）。
- 焦点视觉跨 cell 复用残留 → 焦点身份与 `ItemBindingToken` 交叉校验 + 增量高亮 + 复用/teardown 清焦点（owner: Main，next: T-1C-B）。
- 键盘启动绕过 stale 防线 → 复用 `AppLaunchController.handleCell`（owner: Main，next: T-1C-C）。

### Known pitfalls (Phase 1C)

- `PagingCore` 无 programmatic page API；跨页必须经既有输入路径合成手势，不得篡改 `visualOffset`/`committedPage`/私有状态。
- 网格行列不得硬编码 5×7；从 `itemsPerPage` + 有效 item 数推导。
- 键盘合成手势会经 `handleScrollInput` 触发 telemetry gesture 事件；报告须注明部分 gesture 事件为键盘发起（经中性计数器归因），不得当作真实触控板证据。
- 物理键盘门 `MANUAL_KEYBOARD_GATE` 只能由真实用户真实 GUI + 真实键盘执行；SELFDRIVE/合成 NSEvent/鼠标/单元测试不可替代。

## BUG6/BUG7/BUG8 fix memory candidates (2026-09-01/02, Main gate)

> **Main gate：已批准（2026-09-02）**。以下候选由 BUG6/BUG7/BUG8 修复波次（wave-a/b/c、wave-a'/b'/c'、wave-v/c）产出，Main 审查后并入本文件；均为 durable knowledge，后续阶段直接引用。

### Confirmed decisions (BUG6/7/8)

- 拖拽落点几何用**纯函数**（命中查询 + 意图判定 + 插入位=指针左侧条目水平中点计数），不用预计算 zone 表（wave-a；DropIntent.swift 删 insertionZones/appCenterZones/topLevelLandingZones 字段与构建循环）。
- 引擎 remove-then-insert 槽位换算规则：`.insertion(index)` 在 DragMutationEngine 换算（源在槽位左侧 → index−1）；`moveOutOfFolder` 不经换算（成员不在顶层序）；`reorderFolderMembers` 同构同符号（wave-a 方案 i）。
- createFolder 落点 = **drop 目标 target 原 index（格子位置语义，不做 −1）**（BUG7 wave-a 修订；LayoutMutation.swift 头注释/doc/实现三处同步；ADR-010 M3 已誊写，无 min 残留）。
- 蓝条 global→local 回减：`localInsertionIndex` 只信**帧注记**（pageIndex/itemsPerPage），禁读 geometry.page——folder scope 下 geometry.page=innerPage 是陷阱（wave-v）。
- 点击双启动通路拓扑：Path A=AppLaunchController surface NSClickGestureRecognizer（install() 冻结）→handleClick→handleCell 校验链；Path B=cell.mouseDown→coordinator→.clicked→onCellClick→handleDragCellClick→launchMember→makeMemberLaunchCell→handleCell。beginArbitration 的 clickRecognitionSuppressor(false) 只禁 surface 级（Path A）；folder 开夹走 cell 级 folderClickRecognizer 不受 surface 级抑制（wave-c Stage1.5 发现，与"folder 能开、顶层不能开"症状结构吻合）。
- N1 抑制滞留形态：pointerUp blank 分支无 endSession → controller 僵尸 .pressed + 抑制滞留（Path A 死）；生产代偿=closeFolder 首行 cancel(.overlayClosed) 非 idle 时 endSession 代偿。wave-c Stage2 已修：blank 分支补 endSession()（census 计数后、onOverlayBlankClick 派发前，幂等）；N3=pendingBlankPress 收窄为 sourceCell==nil，resolveSource 失败→武装 clickFallbackCell；N2=dragGate 注释与实现对齐（false=整个 pointerDown 静默拒绝含 Path B click，不拆门）。
- sessionLayout generation 恒零观察项（**本三波不修**）：AppDelegate layoutProvider 一旦 sessionLayout 非 nil 恒返回它；makeSessionLayout 恒产出 generation:.zero 与 applyCommittedLayout 递增 folder generation 不协调——是"为什么会走到 fallback 路径"的上游成因；用户实机复测若现"第二次拖拽行为异常"直接指向此处（AppDelegate.swift:539-547/:561；DragUISessionCoordinator.swift:444；AppGridUIPageContentProvider.swift:259）。

### Important discoveries (BUG6/7/8)

- 用户验收表内部矛盾必须回用户原话字面裁定，不得自行合理化（BUG7 教训：wave-b 任务包"索引 1 vs [folder,C]"矛盾按相对锚点裁决被用户实机否定，正确=target 原 index）。
- census 累计语义下滞留断言须用**增量**（初版绝对零断言已纠正；wave-c Stage2 教训）。
- 变异检查方法：禁用修复后恰 N 个带注记路径测试失败 = 测试有效（wave-v：禁用回减后 3 测试 5 断言失败，page0/未注记/回退 6 测试保持绿）。
- 实机点击取证装置：PAGING_CLICK_CENSUS=1 环境变量门控 stderr 输出（默认零输出），sink 清单 s0-sA 覆盖 pointerDown/Dragged/Up/窗口层/启动结果；E1-E7 实机序列（冷启动/建夹后单击/第二击/开夹关夹/ESC/搜索/重启）待用户回填 census 表（results/T-1F-B8-wave-c.md §Stage1.3-1.4）。
- 集成夹具零帧实验室工件：无窗口从未 layout 时 frames 全零（probe cellCenter=(0,0)），insertionIndex 行划分用 minY<=bottom 使退化帧并单一行恢复旧兜底；测试台修复项待 Main 裁定。
- RunLoopFrameDriverTests 既有 flaky（mtime 08-29，隔离 3/3 绿，全量负载间歇失败）——独立任务挂账，非本波引入。
