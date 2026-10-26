# Implementation Log — PagingPrototype (Phase 1A)

逐阶段记录文件、原因、验证与未完成项。测试通过只代表对应测试范围，不等于完整交付或物理门通过。

## Step 0 — 环境与来源记录（2026-08-28）

### 工具链

| 项 | 值 | 命令 |
|---|---|---|
| Xcode | 26.6 (Build 17F113) | `xcodebuild -version`（exit 0） |
| Swift | 6.3.3 (swiftlang-6.3.3.1.3, clang-2100.1.1.101), arm64-apple-macosx26.0 | `swift --version`（exit 0） |
| macOS | 26.5.2 (Build 25F84) | `sw_vers` |
| 架构 | arm64 | — |

### 目录与 Git 状态

- 工程根：`/Users/mac/Projects/Launch_Copy/PagingPrototype/`（本阶段新建）
- Git：`git init` 完成（2026-08-28 14:49，空仓库，**未 commit**）；无历史、无远端
- 初始目录内容：`Workflow/`（本工作流骨架）、`AGENTS.md`、`MEMORY.md`、`PROVENANCE/`、`Docs/`、`Sources/`、`Tests/`（后三者刚建空目录）
- 未发现无法确认来源的文件；未执行任何破坏性 Git 命令；未修改 LaunchBetter / BuhoReverseNotes

### 来源记录

- 实施 Prompt：`/Users/mac/Projects/Launch_Copy/PHASE1_PAGING_PROTOTYPE_PROMPT.md`
  - SHA-256：`06594a34677474d5ff2c88b8d65cc44c4f6a6958db4fd0629cf89790e4bf16e4`（与 CONTEXT_LEDGER §8.8 一致）
- 治理文档（仅 Main/Chief 可读）：RISK_REDUCTION_PLAN.md / CONTEXT_LEDGER.md / SOURCE_MANIFEST.md —— 已由 Main 于 2026-08-28 阅读
- 参与者访问声明：`PROVENANCE/ACCESS_DECLARATION.md`（Main=PRIOR_EXPOSURE（仅治理文档）；Worker/Reviewer=NO_PRIOR_EXPOSURE 待确认；禁止统一代签）
- Fresh-context 机制：实现 worker 为 AgentTeams fresh member，不继承含逆向材料的旧会话上下文
- 污染日志：`PROVENANCE/CONTAMINATION_LOG.md` —— 无事件

### Workflow 状态

- chef-worker-reviewer-workflow v1.4.1 初始化完成；subagent_mode=ENABLED；max_worker_concurrency=3
- Watchdog：pid 77071 运行中（interval/stale 600s）
- Chief 初始全局规划完成并通过 Main 验证（PLAN.md / MAIN_BRIEF.md / 10 个任务包）

### 未完成项

- 无（Step 0 全部完成）

---

（后续步骤在此追加）

## Step 1 — 规格与 ADR（2026-08-28，进行中）

### 已完成

| 交付物 | 状态 | 验证 |
|---|---|---|
| `Package.swift` | DONE | `swift package dump-package` 通过：macOS 14.0、4 source target + 3 test target、依赖正确（`swift package describe` 因 target 目录暂空报错，属预期，待 Worker 落文件后复验） |
| `Docs/PHASE1_SPEC.md` | DONE | 覆盖 §1 目标/§2 范围/§3 测试页/§4 模块/§5 CLI/§6 telemetry/§7 参数/§9 来源纪律 |
| `Docs/VALIDATION_PLAN.md` | DONE | 覆盖 §7 自动化 + §8 物理矩阵 + §13 状态分类 |
| `Docs/ADR-002-PAGE-HOSTING.md` | DONE | 方案 1 vs 方案 2 比较；决策=先 live views，telemetry 驱动；被否决方案与理由；设计者接触声明 |
| `Docs/ADR-001-PAGING-STATE-MODEL.md` | PENDING | 等待 T-explorer 只读分析（进行中） |
| `Docs/PARAMETER_RATIONALE.md` | PENDING | 等待 T-explorer 参数来源类别建议 |

### 记录

- Package.swift 为 Main 独占；已确认不依赖任何旧项目路径。
- ADR-002 决策：方案 1（live views）先行；T-step6 若需切方案 2 须经 Chief（PLAN.md Chief-Owned #5）。
- 工具链复验：无新增。

### 未完成项

- ADR-001（依赖 T-explorer 分析）；
- PARAMETER_RATIONALE.md（依赖 T-explorer 参数建议）；
- README 构建/运行说明（待源码可构建后补充）。

## Step 2 — PagingCore / PagingTelemetry（2026-08-28，进行中）

### PagingTelemetry（T-worker-c，Worker C）— 已完成并通过 Main 验证

- 交付：`Sources/PagingTelemetry/`（门面/Event 17+4 字段/Session 生命周期/参数解析）+ `Tests/PagingTelemetryTests/`（33 测试）
- 主包验证：`swift build --target PagingTelemetry` exit 0；`swift test --filter PagingTelemetryTests` 33/0 exit 0
- 来源扫描：无 Buho/LaunchBetter/绝对路径（唯一匹配为规格要求的禁止性注释）
- 注意：App 层 `--paging-telemetry`/`--run-id` 最终接线归 Worker D（T-worker-d）

### 目录修复（Main，2026-08-28）

- SwiftPM 对**缺失** target 目录报错、对存在的空目录容忍。已补建 `Sources/PagingUI`、`Sources/PagingPrototypeApp`、`Tests/PagingUITests` 空目录（未写文件；Worker D 独占内容不变）。

### PagingCore（T-worker-b，Worker B）— 进行中

- 已见 `Sources/PagingCore/PagingParameters.swift`；其余实现/测试待 Worker B 完成。

### 未完成项

- PagingCore 实现与单元测试（Worker B）；
- PagingUI / PagingPrototypeApp / PagingUITests（Worker D，待 T-worker-b 完成）。

## Step 3–5 — PagingUI / App 入口 / Telemetry 接线（2026-08-28，已完成）

### 交付与验证（T-worker-d，Worker D）

- `Sources/PagingUI/`：ScrollInputMapper（NSEvent→Core 归一化，自然滚动/方向约定）、PageHostView（live 页面承载/prepare/reuse）、PagingFrameDriver（display link 驱动 settle + 中断接管）、PagingSurface（Core 接线/事件转发/relayout/teardown）
- `Sources/PagingPrototypeApp/`：AppArguments（7 CLI 参数+帮助）、PagingTelemetryBridge（telemetry 最终接线）、AppDelegate、AppMain（NSApplication 启动）
- `Tests/PagingUITests/`：51 测试（§7.3 六判据、§3.F 六门禁+momentum 接管、§3.I 内容正确性、§7.4 四边界、§10 参数、RM 三态、telemetry 开关两态）
- 全包验证：`swift build` exit 0；`swift test` 135 tests 0 failures（51 Core + 33 Telemetry + 51 UI）
- smoke：全参数 exit 0；`--help` exit 0；坏参数 exit 2 不崩溃；GUI 启动存活 + telemetry run.begin 落盘
- 物理门：NOT_RUN（无头环境，不冒认）
- 关键修复：SurfaceReference 转发 box 强捕获（弱捕获致 Core→UI 事件静默丢失，测试暴露并修复）

### 方向约定（产品决策，2026-08-28）

- 手指左移 → 下一页；滚轮向右 → 下一页（水平滚动条类比）；记录于 Worker Result。

### 未完成项

- 真实触控板物理验收（T-step8，等待用户）；
- composited 承载（保留参数，按 ADR-002 未实现）。

## Step 6 — 性能实验（2026-08-28，已完成并通过 Main 验证）

- baseline（5 预设 × 7 指标，200 甩动/预设）：纯 Core 6-11µs/甩动；单帧 update mean 4.5-5.9µs（无 telemetry）、max 3.3ms、miss16=0、hitch50=0；view live≤7/pool≤7；layout 0.5-0.6 次/甩动；冷创建≤3 后 100% 复用；stale 零提交
- 归因：p99≈2.2ms 尖峰 = 事件驱动 relayout（≈1/40 帧，7.5x 余量）；telemetry ≈18µs/帧
- 修复：PagingSurface 漏转发 onStaleRejection/onInterruption（30/0 → 37/37，新增回归测试）
- 结论：自动可测指标全部达标 → 按 ADR-002 不启用方案 2；物理门 NOT_RUN（无头 CADisplayLink 不触发，run1 零帧事件为硬证据）
- telemetry 日志 9 个全保留（/tmp/launch-copy-paging-prototype-*）

## Step 7 — 清洁构建与自动化验证（2026-08-28，已完成）

### 清洁构建（.build 已删除，全新状态）

| 命令 | 退出码 |
|---|---|
| `swift build -c debug` | 0 |
| `swift build -c release` | 0 |
| `swift test`（清洁，debug） | 0（140 tests, 0 failures；51+33+51+5） |

工具链：Xcode 26.6 (17F113) / Swift 6.3.3 (swiftlang-6.3.3.1.3) / macOS 26.5.2 (25F84) / arm64。

产物 hash（SHA-256）：
- Debug：`7563875b684a3783f41c42dc4b7615a8696eb1905d81722f6c97b15268124ccc`
- Release：`179d57ec87b08e9cecd3379927fe8abb84be1057e0303e1d5607fc6fa3579d22`

### 静态来源预警扫描（8 类；**仅是泄漏预警，不是原创性证明**）

| 类别 | 结果 |
|---|---|
| 源码/测试 | 0 命中（buho/launchbetter/2026-08-25/decompil/disassembl 全 0） |
| 文档/README/PROVENANCE | 3 处"Buho/LaunchBetter"字样——全部为规格要求的禁止性说明/扫描记录，非泄漏 |
| 资源 | 无（0 xcassets/plist/Info.plist） |
| Git history | 仓库无任何提交（git init 后未 commit），无可扫描历史 |
| 构建产物 strings | 0 命中（debug/release 二进制，唯一匹配为输出文件名前缀 launch-copy-paging-prototype） |
| 绝对路径 | 3 处——均为工程自身路径（工程根/实施 Prompt 路径），非禁止路径 |

### git diff --check

- 首次执行发现两类问题并已修复：①`.build/` 产物噪音 → 新增 `.gitignore`（Main 计划内有限适应，已记录）②两个任务包 EOF 多余空行（归一化引入）→ 已清理。
- 复跑：`git diff --check` exit 0。未执行任何 commit/staging 保留（`git add -N` 探测后 `git reset` 还原）。

### 产物

- `Docs/VALIDATION_RESULTS.md` 初始状态已写入：BUILD_DEBUG=PASS、BUILD_RELEASE=PASS、AUTOMATED_TESTS=PASS；CODE_REVIEWED / SOURCE_REVIEWED / VISUAL_NEUTRALITY_REVIEWED / MANUAL_PHYSICAL_GATE_60HZ / MANUAL_PHYSICAL_GATE_120HZ = NOT_RUN。
- 无产品代码修改（未发现需路由 Worker 的 bug）。

### 未完成项

- Reviewer E 审查（T-reviewer）；
- 物理验收材料与用户人工执行（T-step8）。

## Step 7.5 — Reviewer E 独立审查（2026-08-28，PASS）

- Verdict：**PASS**（无 BLOCKER/MAJOR；5 MINOR + 2 QUESTION；Confidence ~90%）；报告 `Workflow/reviews/T-reviewer-r1.md`。
- 7 项范围全部通过：来源纪律（亲笔声明无代签、8 类扫描独立复跑 0 泄漏）、参数来源（23/23 合规）、自动化诚实性（8 项状态分离、140 tests 逐文件清点吻合）、物理门诚实（60/120Hz=NOT_RUN、synthetic 帧泵诚实标注）、命名中立、结构独立迹象、ADR 完整性（§3.G 七问/两方案/接触声明）。
- MINOR 处理：M-1/M-2/M-5 → Main 已回填（PROVENANCE 登记、PARAMETER_RATIONALE 补列+验证回填、README 快速开始）；M-3/M-4/Q-2 → 修复波（Worker，进行中）。
- 回填：VALIDATION_RESULTS 的 CODE_REVIEWED / SOURCE_REVIEWED / VISUAL_NEUTRALITY_REVIEWED = PASS。
- 备注（Q-1）：Worker B/D 为同一 fresh member 顺序承担，已在 ACCESS_DECLARATION §3 记录（fresh-context 纪律不受影响）。

## Step 8 — 物理验收准备（2026-08-28，材料就绪，等待用户）

- `Docs/MANUAL_TEST_STEPS.md`：环境证据 11 项模板、页面矩阵 5 预设、手势矩阵 12 项、正确性硬门、主观评分、60/120Hz 目标与 BLOCKED 规则、结果回填方法。
- 物理门状态保持 NOT_RUN（60Hz）/ NOT_RUN（120Hz，无设备证据将转 BLOCKED）；**等待用户执行**。

## Step 7.6 — Reviewer MINOR 修复波（2026-08-28，已完成并通过 Main 验证）

- M-3（注释一致性）：PageTargetPolicy.swift:71 velocityContribution 注释对齐 0.0–0.5；零行为改动
- M-4（高度 resize 边缘）：PagingSurface.layout() 守卫放宽为宽度或高度任一 >0.5；仅高度变化触发 relayoutPages（不触碰 Core）；+3 回归测试
- Q-2（诊断字段）：PagingCore 三处重启路径 createdAt 0 → 真实时间戳；+1 测试（测试设计修正已记录：setPageCount 合法 target 不重启 settle / RM 下 settle 即时完成）
- 验证：全量 **144 tests, 0 failures**；`swift build` exit 0（发现 1 条预存警告 PagingTelemetryBridge.swift:118 `var event` 从未修改 → 微修复波 T-worker-b-repair-2 处理中）
- M-5（README）已由 Main 重写完成（T-step8 准备阶段）

## Step 7.7 — 微修复 + 最终清洁复验（2026-08-28，完成）

- PagingTelemetryBridge.swift:118 `var event` → `let event`（消除唯一编译警告，语义零改动）。
- 最终清洁复验（删 .build 后）：
  - `swift build -c debug`：exit 0，**0 警告**
  - `swift build -c release`：exit 0，**0 警告**
  - `swift test`：**144 tests, 0 failures**，exit 0
- 最终产物 hash（SHA-256，修复波后更新）：
  - Debug：`224d13052266e8ef94b7721b601f2a3a96dfde53c3ea822420d3df0da81fd979`
  - Release：`183b7eb64c6d1f0acb3f7ac2b11d8786c2ccafb854820e2b8b06754a53d6297a`
- 全部实现波次关闭：T-step0 → T-explorer → T-step1 → T-worker-b/c/d → T-step6 → T-step7 → T-reviewer（PASS）→ 修复波（144/0）→ 微修复（0 警告）。

## Step 8 — 状态（等待用户执行物理门）

- 材料：`Docs/MANUAL_TEST_STEPS.md`（环境证据/页面矩阵/手势矩阵/正确性硬门/主观评分/60Hz+120Hz 规则）。
- MANUAL_PHYSICAL_GATE_60HZ = NOT_RUN；MANUAL_PHYSICAL_GATE_120HZ = NOT_RUN（无 120Hz 设备证据将转 BLOCKED）。

## Step 7.7 — 微修复 + 最终清洁复验（2026-08-28，完成）

- PagingTelemetryBridge.swift:118 `var event` → `let event`（消除唯一编译警告，语义零改动）。
- 最终清洁复验（删 .build 后）：
  - `swift build -c debug`：exit 0，**0 警告**
  - `swift build -c release`：exit 0，**0 警告**
  - `swift test`：**144 tests, 0 failures**，exit 0
- 最终产物 hash（SHA-256，修复波后更新）：
  - Debug：`224d13052266e8ef94b7721b601f2a3a96dfde53c3ea822420d3df0da81fd979`
  - Release：`183b7eb64c6d1f0acb3f7ac2b11d8786c2ccafb854820e2b8b06754a53d6297a`
- 全部实现波次关闭：T-step0 → T-explorer → T-step1 → T-worker-b/c/d → T-step6 → T-step7 → T-reviewer（PASS）→ 修复波（144/0）→ 微修复（0 警告）。

## Step 8 — 状态（等待用户执行物理门）

- 材料：`Docs/MANUAL_TEST_STEPS.md`（环境证据/页面矩阵/手势矩阵/正确性硬门/主观评分/60Hz+120Hz 规则）。
- MANUAL_PHYSICAL_GATE_60HZ = NOT_RUN；MANUAL_PHYSICAL_GATE_120HZ = NOT_RUN（无 120Hz 设备证据将转 BLOCKED）。

## Step 8.1 — 物理复测 #1/#2 与帧驱动修复（2026-08-28）

- 复测 #1（用户真机）：释放后无决策（不回弹/不翻页/不吸住）→ 修复 T-worker-b-input-fix（ended 后 100ms 帧检查自动 finishGesture）→ 148 tests。
- 复测 #2（用户真机）：仍卡两页中间。telemetry 实锤：全程 0 frame 事件（transition.begin 2 / commit 0）——**display link 在本机环境零回调**（T-step6 误判"无头"；Aqua 会话实证）。
- 修复 T-worker-b-frame-fix：DisplayLinkFrameDriver → **RunLoopFrameDriver**（主 runloop common 模式 60Hz Timer 帧泵；dt clamp 0.1s；幂等 start；deinit invalidate）。不保留 display link 优先（本机必失败）；**帧源 = runloop 60Hz ≈16.67ms，非 vsync 对齐（诚实标注三处），vsync 对齐留 Phase 1B**（协议不变，届时换实现零接线改动）。
- 真机自驱冒烟（release，SELFDRIVE）：frame 0→560；transition.commit 0→15；stale 25=interruption 25（自驱节奏 0.4s < settle 时长被接管打断，设计内）。
- 测试：151 tests, 0 failures（+3 RunLoopFrameDriverTests：真实 runloop 投递帧 / 真实泵完成 settle→commit（phys-auto-02 卡死路径回归）/ teardown 零回调）。

## Step 8.2 — 物理门 PASS 与调参史（2026-08-28）

- **MANUAL_PHYSICAL_GATE_60HZ = PASS**（用户真实触控板，全屏 1470pt 基准；主观五项 4/4/4/4/4）。
- **MANUAL_PHYSICAL_GATE_120HZ = BLOCKED**（硬件：主屏 60.0Hz 固定，无 ProMotion；120Hz 留 Phase 1B）。
- 调参史（12 轮，全部记录于 Workflow/events.jsonl decision_recorded）：
  1. 复测 #1 无决策 → T-worker-b-input-fix（ended 后 100ms 帧检查自动 finishGesture）→ 148 tests
  2. 复测 #2 卡两页中间 → T-worker-b-frame-fix（display link 零回调 → RunLoopFrameDriver 60Hz runloop 泵）→ 151 tests
  3. 惯性太长 → momentumDecay CLI 试值 0.85（≈0.33s glide，仍长）
  4. 惯性仍长 → 0.55；根因 = 系统 momentum 事件流（~0.5s/433 事件）→ momentumGlideFrames 截断（nil→10→5→3→1）
  5. 过冲拉回（用户"甩到第 4-5 页再被拉回"）→ telemetry 实锤 1.6 页过冲 → momentumMaxOvershoot 钳制（0.35）
  6. 过冲 0.35→0.20（用户"最多冲到第二页加 1/5 页"）+ CLI --momentum-overshoot
  7. "顿一下再吸"（往左）→ 28 手势 × 4 静止帧实锤 → 硬钳制改软阻尼递推（0.2×delta，无静止帧）
  8. 往左/往右不一致 → 负向阻尼线 committed−0.2 → (committed−1)−0.2（几何对称；首页让位边界阻尼）
  9. 回退偶发翻不过 → 生理不对称（往回滑行程天然短）→ retreatDisplacementFactor 0.9（回退 0.45）
  10. 全屏基准决策（窗口 1000pt vs 全屏 1470pt，1.47×）→ --fullscreen + 阈值 0.48/0.42
  11. 惯性仍长 → momentumGlideFrames 3→1（默认固化）；切换按钮 + Ctrl+Cmd+F（t21）
  12. 阈值 0.48/0.42 → 0.46/0.40（retreatDisplacementFactor 20/23，回退精确 0.40）
- 方向澄清（产品决策确认）：手指左移 = 下一页（Photos 惯例）；用户"往右走"指布局方向（第 2 页在第 1 页右侧），非手指方向。
- 固化默认（T-worker-b-solidify）：momentumGlideFrames 1、momentumDecay 0.55、displacementThreshold 0.46、retreatDisplacementFactor 20/23、momentumMaxOvershoot 0.20（软阻尼）。
- 最终测试基线：180 tests, 0 failures（固化后重跑确认）；swift build debug+release exit 0（0 warning）。
- 最终产物 hash（SHA-256，固化后重算）：
  - Debug：`1ae7dba707085a9f42f615fd854363ca08d5fd3d480a6f7fe64cdb5a1f3d594f`
  - Release：`25c852831ddfdc643a2fcb215070d191540cfe675aa3d544d6fa7adcf8ee4ebe`

## Gate 0 — Phase 1A 基线对账与冻结（2026-08-28 19:44:59–19:45:22）

- 清洁基线：`swift package clean` → `swift test`（**181 tests, 0 failures**，真实执行数）→ `swift build -c debug`（exit 0）→ `swift build -c release`（exit 0，0 warning）。
- 产物 SHA-256（清洁重建后）：Debug `80566d2293c79d66bb80ffeeea2d8908520c57558a194b2fdb5a1785d09e87ee`；Release `f95ea284f11d79d9e3c86a67edf9065432119cedd4c099aae6fb736417d1e044`。
- Tree manifest：`Docs/PHASE1A_BASELINE_MANIFEST.sha256`（118 文件，排序稳定，排除 .git/.build/临时文件）。
- 对账：`Docs/PHASE1A_BASELINE_RECONCILIATION.md`（矛盾清单 + 处置；历史数字 140/144/180 保留于本日志历史段）。
- 60Hz 物理门 = PASS_USER_REPORTED_WITH_EVIDENCE_REFERENCE（2026-08-28 用户实机，主观 4/4/4/4/4）；120Hz = BLOCKED_BY_HARDWARE。
- 帧源 = RunLoopFrameDriver（60Hz Timer，非 vsync）。
- 无自动 commit（§1.4 规则；git 仍 0 commits，11 untracked）。

## Phase 1B — 实现与验证（2026-08-28）

### Gate 0（§1）
- 清洁基线 181 tests 0 failures；manifest 117 文件（shasum -c 全绿；watchdog.json/heartbeats.json 活写排除；Explorer A 核验修复 7/118 失配 + 停 stale watchdog 77071）。
- 对账：Docs/PHASE1A_BASELINE_RECONCILIATION.md；STALE_STATE_RECORDED ×4；无自动 commit。

### Wave 1（§12）
- AppCatalogCore 56 / MacAppCatalog 45 / AppIconPipeline 23；Main 收口 306 tests 0 failures。
- ADR-004 冻结（rootPriorityFirst、canonicalURL 身份、remap 五级降级）。

### Wave 2
- PagingUI seam 93（78+15）/ AppGridUI 49 / Telemetry 54（33+21）；收口 390 tests 0 failures。
- 四层红线冻结；PRIVACY_DATA_MAP.md。

### Wave 3
- 装配：AppCatalogAssembly/AppLaunchController/FrameDriverExperiment/CLI 3 新参数（--catalog-root/--neutral-content/--frame-driver）；414 tests 0 failures。
- APP_LAUNCH_SMOKE = PASS（键盘层延 Phase 1C）。
- §8 帧源实验：display link 本环境 ~60Hz 回调（Phase 1A 零回调 = 探测定时器 stop 假象）；只记录证据，未标 PASS，帧源未改。

### Review（§14）
- Reviewer 三份独立 review 全 PASS（无 BLOCKER/MAJOR；4 MINOR：陈旧注释→修复中、icon_cache 字段预留标注、PROVENANCE 回填→已完成）。

### 60Hz 真实内容物理复验
- 用户实机结果：**PASS**（2026-08-28，phys1b-03/04 真实内容全屏 1470pt 基准）。
- 调参轮（全部 decision_recorded）：0.46/0.40 → 0.45/0.38（第 13 轮，用户"把前进改成45，回退改成38"）→ **0.43/0.36**（第 14 轮，用户"前进改成0.43，回退改成0.36"；factor 36/43，0.43×36/43==0.36 精确，1-ulp 零偏移）。
- 用户最终确认：**"OK的"**，主观五项 4/4/4/4/3.6（跟手性/中断连续性/settle 自然度/边界反馈/总体丝滑）。
- phys1b-04 telemetry 证据：423s、41 翻页尝试（30 commit：28 跨页 + 2 同页 bounce；11 interrupted = stale_rejected 11/11 重合，latest-wins 预期）、835 frame（~16.7ms 60Hz）、icon.async 236（118 completed + 118 stale_rejected）。注：run 未走干净 teardown（窗口仍开，无 run.end），接受证据为 00:04:44 前完整手势段。
- 边界测试（T-worker-b-thresh43）：前进 420px→bounce / 430px→advance；回退 −350px→bounce / −360px→retreat；混合路径 0.4263<0.43→bounce、0.3563<0.36→bounce。
- 414 tests 0 failures（Main 复验）；release build exit 0 零警告。
- 120Hz 仍 BLOCKED_BY_HARDWARE（60.0Hz 面板，无 ProMotion）。
- 最终产物 SHA-256（Phase 1B 414-build，t17 后）：Debug `ca38fd0142cd54a7e9c404c4ff9fc950e368018e44223ddd41d74ef96050eecb`；Release `2b862ebeb735260b60b8603e87a2a55a2256b707150afa9e2b72c128e13dd444`。

## Targeted Timer tolerance / mode localization（2026-08-29）

- 新增 `--frame-timer-tolerance-ms <0–16.667>`；缺省保留 8.333ms，0ms 用于单变量实验，非法值 exit 2。
- `RunLoopFrameDriver` 的 interval/tolerance 可配置并钳制；App/DisplayLink 观察包装路径均传递 tolerance；`Sources/PagingCore/` 未改。
- `RunLoopProfileRecorder` 新增固定匿名 mode：`default|eventTracking|modalPanel|other|none`，不写 raw mode。
- 修复 Swift 编译器无法诊断的大型 smoke 字符串插值：先计算 toleranceDescription，再拆分拼接。
- 验证：定向 43 tests 0 failures；全量 Swift 444 tests 0 failures；Python analyzer 15 tests 0 failures；Release build exit 0；smoke tolerance=0 解析通过。
- 正式 SELFDRIVE A/B：Full probe 6 runs + Lite probe 6 runs，顺序 A1/B1/B2/A2/A3/B3，全部有 run.end + teardown.complete。
- 结果：8.333→0ms 在 Full/Lite 两轨均把 20–25ms rate 降低约 63–69%；>25ms 无稳定改善。
- 证据结论：`SUPPORTED_PARTIAL_CONTRIBUTOR_TIMER_TOLERANCE_FOR_20_TO_25MS`；不能写成全部卡顿已修复。
- 后续门：真实触控板物理 ABBA 后才能改生产默认；长尾继续加 scheduled deadline、lateness、first tick、callback entry/exit 和 CPU 探针。
- 原始临时证据：`/tmp/launch-copy-paging-prototype-timer-ab-*`、`/tmp/launch-copy-paging-prototype-timer-ab-lite-*`；hash 清单在 `Docs/TIMER_TOLERANCE_AB_ARTIFACTS.sha256`。

## Callback boundary probe + GUI ABBA（2026-08-29，独立审查后收紧）

- 新增 opt-in `FrameCallbackProfileRecorder`，记录 nominal deadline、lateness、missed periods、first tick、raw interval、recorded-segment wall/current-thread CPU、simulation dt 和匿名 RunLoop mode；异步 writer，inactive 不建文件。
- `RunLoopFrameDriver` 完成真实 Timer callback 接线；restart 使用新 generation，sequence 连续，nominal deadline 绝对递推。
- 独立审查发现 reentrant `stop()+start()` 后旧 callback 可能覆盖新 generation deadline 的防护缺口；已增加 generation guard 和真实 RunLoop 回归测试。该测试先制造 generation 1 deadline 明确过期，再验证 generation 2 首记录保留 restart 后的新 `scheduled_ns`。
- App/DisplayLink wrapper 完成 recorder 透传；`--disable-telemetry-bridge` 隔离 callback-only 实验热路径。
- 最终 Main 自动复验：Swift 454/0；Python 20/0；Release build exit 0；`py_compile` 通过。`git diff --check` exit 0，但因仓库尚无 tracked baseline，不把它当作完整 untracked-file 检查；本轮 10 个权威文件的独立 trailing-whitespace/conflict-marker 扫描为 0 issue。
- Release GUI SELFDRIVE ABBA：A1/B1/B2/A2，四轮均自动 teardown；2,017 input/accepted callbacks、0 rejected、0 ignored，1,907 raw intervals。
- 严格 >25ms 共 5 个；preceding recorded-segment current-thread CPU max 1.928ms，不足以解释这五个样本。五个样本的 recorded-exit→next-entry remainder 均占 interval 多数；三个为 97.2%–99.1%，另一个 27.055ms 是 substantial mixed case。
- `recorded exit` 是 recorder 在 `endCallback` 开头的测量边界，不证明 Timer closure 已返回；remainder 不得命名为严格“callback 外时间”。
- 另有独立 first-tick >25ms delay，排除在 raw interval 分布之外；其与 post-recorded-exit remainder 的因果均未定位。
- 最终窄门：`TIMER_ENTRY_TO_POST_ADVANCEFRAME_PROBE_IMPLEMENTED_AND_DIAGNOSTICALLY_VALIDATED`；`PRECEDING_RECORDED_SEGMENT_THREAD_CPU_INSUFFICIENT_FOR_5_OBSERVED_GT25MS_ENTRY_INTERVALS`；`POST_RECORDED_EXIT_AND_FIRST_TICK_DELAY_CAUSALITY_UNRESOLVED`。
- 不能宣称 scheduler/RunLoop/WindowServer/AppKit/CA/GPU 根因，不能宣称 `ALL_HITCHES_FIXED`；SELFDRIVE 不替代物理触控板门，也不足以改变产品默认值。
- 证据：`Docs/CALLBACK_BOUNDARY_ABBA_RESULTS.md`、四份 `Docs/CALLBACK_CADENCE_*.md`、`Docs/CALLBACK_BOUNDARY_ABBA_ARTIFACTS.sha256`。
- 2026-08-29T13:11:33+09:00 最终复验重建后的当前可执行文件 SHA-256：Debug `524e995b47c9aa7dcc07d10d6c3bde671b314a92616d74bc67ac6a9516449f05`；Release `3742ee9ea8db98aecdcba62bb1df612851f12d2957a1c1f8c92216d4dcb3b700`。Swift 454/0、Python 20/0、Release build exit 0；callback artifact manifest 8/8 OK。

## Same-clock closure-tail + RunLoop correlation（2026-08-29）

- 共享 `DiagnosticMonotonicClock`（`CLOCK_MONOTONIC_RAW` + thread CPU）。`exit_ns` 语义保持为 post-advanceFrame。新增 `pre_return_ns`（closure-return-adjacent，禁止命名为 closure_return）和 `kind=timer_generation_arm`。
- `--runloop-profile` 独立开关；与 `--frame-profile` 共用一个 observer。RunLoop 记录 `timestamp_ns` 作 join key，遗留 `timestamp`（uptime）不得与 callback ns 相减。
- Analyzer：`Tools/analyze_callback_runloop_correlation.py`（旧 cadence/hitch 分析器未改语义）。
- 验证：Swift 462/0；Python 40/0；Release build PASS。Release SHA-256 `e42535a9054fb5a66dd66052416c21d68519fa6b13d0c62b72900ce035726d9d`。`PagingCore` 未改。
- A/A（tolerance=0, SELFDRIVE 40 flings）：Full 相对 Legacy 未制造新的 `>25ms` 种群，开销门 PASS。第一次 Full 因 argv 把两个 flag 收成一个 token 而无效，已重跑。
- 本捕获两个 `>25ms` 样本（26.549 / 26.542ms）：closure tail <0.01ms；remainder ≈19ms。同钟 Full 样本 join class = `MIXED_OBSERVED_BOUNDARIES`（waiting 6.608 + active 13.014 + uncovered 0.123ms）。历史 72ms 未再现。
- 门：`BOUNDARY_NARROWED` + `CAUSALITY_UNRESOLVED`。物理：`PHYSICAL_CORRELATED_CAPTURE_BLOCKED_PENDING_USER_ACTION`。
- 证据：`Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_RESULTS.md`、`Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_CHECKPOINT.md`、`Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_ARTIFACTS.sha256`。

## Physical 60Hz + remainder pair dump + System Trace（2026-08-29）

- 物理触控板 4 轮（n1/n2 中性，r1/r2 真实内容），60Hz 全屏，用户约 40 次手势。中性无 `>25ms`；真实内容各 1 条刚过 25ms。
- 物理 `>25ms` remainder 不是 25ms CPU：~14ms `beforeWaiting→afterWaiting` + **稳定 ~10ms `exit→entry`**（RunLoop 本次 invocation 不在跑）。body ~0.2ms。
- SELFDRIVE System Trace 轮另有 36.5ms：35.5ms 在 `beforeSources→exit`（无 beforeWaiting）。与物理结构不同，禁止合并成一个根因。
- `OSSignposter` 改为 `PointsOfInterest`；System Trace 已见到 signpost。Time Profiler 栈未符号化，主线程 runnable-but-unscheduled 未证明。
- 门仍 `CAUSALITY_UNRESOLVED`。物理：`PHYSICAL_CORRELATED_CAPTURE_COMPLETED_60HZ`。

## Threshold tuning round 15: 0.43/0.36 → 0.42/0.35（2026-08-29）

- 用户决策（decision_recorded）："前进阈值改成0.42，回退系数改成0.35"（理解=回退阈值 0.35 → retreatDisplacementFactor 35/42）。
- 改动（T-worker-b-thresh42，worker-pagingcore2，NO_PRIOR_EXPOSURE）：`PagingParameters.swift` displacementThreshold 0.43→0.42、retreatDisplacementFactor 36.0/43.0→35.0/42.0；`PageTargetPolicy.swift` 注释同步（零代码改动）；PagingCoreTests 边界适配。
- 1-ulp 零偏移：0.42×35/42==0.35、420/1000>=0.42、350/1000==0.35 精确（Main 预验证 + worker 独立复核）。
- 边界证据（velocityContribution=0 隔离）：前进 410px→bounce / 420px→advance；回退 −340px→bounce / −350px→retreat；混合路径 0.4163<0.42→bounce、0.3463<0.35→bounce。
- Main 复验：462 tests 0 failures（基线 462/0，net 0）；Release build exit 0 零警告；冻结参数（momentumDecay 0.55、glideFrames 1、maxOvershoot 0.20）在位。
- 用户复测 phys1b-06（run B，29.1s/30 手势/19 commit/11 stale；帧间隔 median 16.67ms p95 18.20ms max 26.68ms）：**用户确认"我觉得挺好的"** → ACCEPTED。
- 注：同日用户自行重构帧驱动（PagingFrameDriver 协议抽象 + FrameCallbackProfileRecorder/BufferedJSONLWriter/DiagnosticMonotonicClock + callback-boundary profiler），基线 462 tests；本调参轮未触碰 PagingUI/App 文件。
- 最终 Release SHA-256：见上（e42535a9… 为帧驱动重构后基线；本调参轮仅 PagingCore 常量 + 测试，未重建记录——如需精确哈希可补跑）。

## Timer tolerance 生产默认 8.333ms → 4ms（T-A4，2026-08-30）

- 生产默认 `Timer.tolerance` 8.333ms → 4ms（`PRODUCT_TIMER_TOLERANCE_4MS`）。

## Timer tolerance 生产默认 4ms → 0ms（T-A4-0ms，2026-08-30）

- 生产默认 `Timer.tolerance` 4ms → 0ms（`PRODUCT_TIMER_TOLERANCE_0MS`）。

## T-A5 物理验收 PASS（用户定案，2026-08-30）

- 0ms 定案为生产默认；短尾改善 token `SHORT_TAIL_MITIGATED_BY_TOLERANCE` 允许；`REQUIRE_PHYSICAL_AB_BEFORE_TIMER_TOLERANCE_DEFAULT_CHANGE` 移除（活状态）。
- 证据：T-A2 完整 6 轮物理 A/B（跟手 4.00 vs 3.87、总体 3.85 vs 3.77、误 commit 0 双臂）+ T-A1 梯度（p95 17.57 ≤ 18.5、>20ms 率降 67% ≥ 50%）；0ms SELFDRIVE commit 副作用物理未复现，归档为合成伪影。
- 长尾 >25ms 仍 `CAUSALITY_UNRESOLVED`；未宣称全部卡顿已修复。

## Phase 1E 文件夹基础垂直切片（T-1E-A..E + H2-repair，2026-08-30）

- 领域模型：`FolderDomain.swift`（FolderID 非名称派生、FolderGeneration 独立单调 token、FolderTitle、FolderEntry、FolderSnapshot、TopLevelEntry、ActivationRouter、rebase dissolve 单成员）；`FolderLabFixture.swift`（--folder-lab 分组，默认 off，groupSize 35，中性 `Group N`）。
- 顶层呈现：`AppGridUIPageContentProvider` 统一 `[TopLevelEntry]` 组合（app+folder），latest-wins + idle 提交，页数/锚点/5 级 remap；搜索扁平化 app-only；死 `onStateChange` 回调移除（记录决策）。
- 文件夹视觉/打开层：`AppGridCellView` folder cell 模式（中性 SF Symbol + 标题 + 成员数，拒 app 图标写回）；`FolderOverlayView`（层外点击只关文件夹、成员激活、内部分页、generation 门控、Reduce Motion）；修复 overlay 点击坐标 bug（`panel.convert(point, from: self)`）。
- 键盘/焦点/标题编辑：`FolderKeyboardLogic.swift` 纯逻辑 + `FolderTitleEditor.swift`（Enter/Escape/失焦，无磁盘/telemetry）；Command-F 标题编辑残留 isEditingTitle MAJOR → repair（closeFolder 先复位 + nextEditingState seam + 3 回归测试）。
- 集成：`--folder-lab` 标志、`makeMemberLaunchCell` 成员启动复用 AppLaunchController.handleCell 精确管线、两段式空白单击（folder 开→关文件夹，下一真实背景点击退出）。
- 基线 631 → **756 tests, 0 failures**；Debug/Release exit 0；冻结树未改；手动门 NOT_RUN。

## 2026-10-17 — Live Appearance and integrated main-grid settings
Approved liveeffect+autosave/six-tab mergedAppearance delivered. Final2951/0,broadened260/0,Debug/Release/package323keys×3languages; currentb1ca4fcbisolatedappopened. Normalrestartretentionnativeobserved, olduser-own-test23/54/12+6×5restored. TwoCUA mousedragsunchanged, physicalhelddragpending; no falsephysicalPASS. Fullresults Workflow/results/LIVE_APPEARANCE_GRID_RESULTS.md and stage/receipts retainallreview/RED/oldcontractmigrationfailures and evidencebounds. No formalinstall/sign/commit/sourcecopy/OSchanges.

## Human live-effect acceptance — 2026-10-17

The human replied “实时变化正常” to the request to continuously drag the Appearance sliders in the delivered isolated candidate. This resolves the pending human continuous-drag/live-effect gate. The merged Appearance/row-column feature is accepted within its delivered scope; the reply specifically confirms real-time visual changes, not a separate measured performance or persistence result. Existing native save/restart observations and automated results remain their own evidence.

The two earlier inconclusive CUA drag attempts remain recorded as not PASS; human acceptance does not relabel those attempts. No source changes, rebuild, app restart, or preference restoration were performed for this closeout. Current user settings are left untouched. Other product acceptance and root-cause gates remain open; full LaunchBetter parity is not complete. Older pending-gate snapshots below are historical and superseded only for this human live-effect gate.

## 2026-10-18 — Current parity reconciliation and localized live Appearance
Main verified unchanged488 inputs/exact b1ca4fcb existing candidate, performed native English/Japanese Appearance top/bottom scroll/layout checks, restored Follow System and preserved current human28.40063010899183/54/12/names-on/6x5 settings. No code/build/test/restart. Bounded native PASS only; ready wallpaper observation not a cause fix. Helmholtz completed/closed the independent current requirements reconciliation, mapping approved deliveries and reserved branches without inventing defects. Proposed optional local Recent/Frequent activity spec written; explicit human confirmation pending before any implementation/collection. Reports and receipt linked in Workflow/stage-summaries/2026-10-18-current-parity-and-locales.md. Full goal incomplete.

## Recent/Frequent code verified and packaged; native pending — 2026-10-18

Approved optional localRecent/Frequent implemented defaultOFF. Finalfocused151/0(9.078s),full3033/0(99.364s),Debug0.60s,actualRelease29.62s/347keys×3languages/packageentry/diffcheckPASS. IndependentfoundationSOURCEPASS andintegrationR3SOURCEPASS; R1/R2 actualRED2/7and1/5failures retained/repaired (clear+privacyOff barrier, failedLibraryOff auto-resume andinitialload overwritingOff). All500frozeninputsmatch,16modified+12new/zero removed/PagingCoreunchanged. Workers/reviewers/jobsclosed.

Newunsigned/uninstalledcandidate `.build/candidates/library-launch-activity-rc-20261018-r3/LaunchcopyUITest.app`,SHA310b61f240e3c8c7412b6582d8b21554d787d66240c637351b577aa59acab70c, NOTLAUNCHED. TwoactualCUAchecksreturnedlockedMac; explicitasyncmanualunlockrequestpending. Previousownb1ca4fcb/PID29032retained. Newownfixture80Info-only+inert6972probe/authoredlayoutcapacityseedonly, nohistory/preferences/cache/locksimported; activityfile/Librarypreferenceabsentafterpackage. Noformaltracking/OS/install/sign/kill/commitaction. Nativeoptin/off/realacceptedrequestcapture/RecentFrequent/clearCancel+explicitconfirm/samecandidateQuitrestart andhumanperformancepending, notPASS. Fullobjectiveincomplete. Stage Workflow/stage-summaries/2026-10-18-library-launch-activity.md; fullreport Workflow/results/LIBRARY_LAUNCH_ACTIVITY_RESULTS.md; `.build/verification/20261018/library-launch-activity/final-receipt.json`. Nextactualunlock normalownoldQuit/exactabsence→directr3open→nativegates; no needrebuildunchangedinputs. Earlier PROPOSED/verificationlive/r1/r2candidate entries below arehistorical supersededonlybythischeckpoint.

## Native verification resumed after human unlock — 2026-10-18

This checkpoint supersedes the earlier locked-Mac / NOT LAUNCHED snapshots below, without rewriting their history. The human explicitly authorized continued testing. Main normally quit the old isolated instance, verified its exact executable was absent, and opened the final r3 candidate. No formal version was installed or overwritten.

Actual native results for executable SHA-256 `310b61f240e3c8c7412b6582d8b21554d787d66240c637351b577aa59acab70c`:
- Default OFF: startup and a real controlled grid launch created no activity file.
- Explicit Library and tracking opt-in: empty initial activity; the prior OFF request was not replayed.
- One grid launch and one Library details Open each started the authored inert probe (new exact process verified before CUA binding). The persisted total is exactly two requests for one identity. Recent and Frequent each displayed that application.
- Clear warning and Cancel: scope is stated explicitly; Cancel retained both requests. Actual irreversible Clear is PENDING action-time human confirmation, not native PASS.
- Tracking OFF: a further real grid launch started the probe, but the persisted total stayed two; Recent/Frequent were hidden.
- Same-candidate normal Quit / exact process absence / reopen verified both OFF and ON persistence. Existing records were retained; no OFF-period replay occurred.
- Library OFF also switched tracking OFF; Library ON did not resume tracking. Final handover leaves both OFF, preserving the two synthetic requests until the Clear decision.
- Appearance remains names ON, blur 28.40063010899183 (native rounded display 28), icon 54, font 12, columns 6 / rows 5. The old profile is untouched.

Native receipt: `.build/verification/20261018/library-launch-activity/native-acceptance-r3.json`. All 500 frozen source inputs and the exact candidate hash still match after testing. Automated baseline remains 3033/0; no source change or redundant rebuild was needed. Two CUA probe-binding restarts are excluded from product-launch evidence; post-Quit bindings must not be queried because the automation can reopen an app. Actual launch controls used exact pre-click absence checks.

Current own candidate PID at receipt: 36593. Unsigned / uninstalled. No reference code/assets, formal tracking, process signals, OS/security changes, commit or cleanup. No human feature/performance acceptance or full parity completion is inferred. Goal tool retains its historical BLOCKED status (no supported active-setting API); actual human-authorized native progress resumed, so old consecutive lock counts do not carry forward.

Next action: apply only the human's action-time Clear decision, verify retained enabled choice / cleared activity / unchanged unrelated layout and capacity, then leave the isolated app safe for handover. Full parity and physical performance gates remain separate.

## Authorized Clear verified / routine-decision preference — 2026-10-18

The human explicitly authorized irreversible deletion of the two synthetic launch requests in the isolated r3 profile. Main confirmed the native feature-only warning, executed Clear, observed success and disabled Clear, and read entries=0 / enabled=OFF with a rotated document salt. All 84 unrelated fixture JSON/plist inputs (including layout, Library preferences, capacity and authored bundle metadata) were byte-identical. Normal Quit, exact process absence and reopening the same candidate preserved the empty history, Library OFF and tracking OFF. The ordinary non-topmost main window is left available. Formal data and the old candidate profile are untouched.

This supersedes only the pending actual-Clear gate above/below. Controlled native acceptance for this feature now passes within the described fixture and viewport; 3033/0 automated evidence and bounded source-review PASS remain separate. All 500 frozen code inputs and candidate SHA `310b61f240e3c8c7412b6582d8b21554d787d66240c637351b577aa59acab70c` still match. No rebuild, installation or release action occurred. Receipts: `.build/verification/20261018/library-launch-activity/native-clear-r3.json` and `native-acceptance-r3.json`. Human feature acceptance, matched physical performance and full LaunchBetter parity are not inferred.

The human additionally requested autonomous handling of non-major decisions: proceed with routine implementation, repairs and verification inside approved scope without repeated questions. Escalate material product/scope/architecture changes and actions requiring explicit data-deletion/security/permission authorization. Do not treat this preference as blanket consent for destructive operations or unapproved features. Next: continue already-approved non-destructive acceptance / defect work, preserving physical-performance and historical causality boundaries.

## Main-search composition repair delivered — 2026-10-18

Concrete progress toward the full objective: Poincare current-scope audit found a main-search delegate composition gap; Main reproduced marked Escape/Return/Down losing draft/query/focus in actual undisplayed AppKit field editors (5 tests, 3 failed methods, 26 assertion failures). Added only an early hasMarkedText returnfalse, matching the existing Library rule. Ordinary text behavior remains unchanged. Five new tests preserve marked/selected ranges, draft, query/generation/results, focus and no launch/exit effects, with Tab and post-unmark Return controls. This is delegate-level synthetic composition evidence, NOT real Chinese/Japanese IME acceptance.

Final focused42/0(3.166s), full3038/0(77.267s), Debug0.37s, actualRelease17.01s/package347keys×3languages and reserved native entry PASS. Fermat boundedSOURCEPASS, all agents/jobs closed. First package invocation used a wrong SwiftPM product override and failed before artifact creation; retained package-r1.log. Corrected invocation package-r2.log succeeded without source/test changes. 501 frozen inputs match after native; exactly1existingproductionfile+1newtest versus500baseline; PagingCore/physics unchanged.

Latest unsigned/uninstalled isolated candidate `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/search-composition-rc-20261018-r1/LaunchcopyUITest.app`, SHA `bcf43c54566300767429a46bd471eeec113d82a3799ee0cf29c2f4eceb25b872`, RUNNING (native-handover-r1.json process receipt). Previous own activityr3 normallyQuit and exact executable absence checked before new native open. Native plainLatin search/firstReturnselect-without-launch/CmdF/Down/twoEscape priorities observed. User appearance restored28.40063010899183/54/12/namesON/6×5; Library/tracking remain defaultOFF, no activity or Library preference file. Only authored81app fixture/layout/capacity seeded; no formal data/preferences/history/cache/locks copied. Main window ordinary non-topmost/noquery/folderclosed. Newrun wallpaper stillloading/black, NOT_FIXED.

English and Japanese activity-settings new controls/privacy/status/Clear fit the preceding exact310b61f2 native500pt window; FollowSystem restored. Settings window is not resizable, so no smaller-native-window PASS fabricated. RealIME/spokenVoiceOver/matchedphysical60/120Hz/energyRSS/multidisplay/originalfolder-scroll+wallpapercausality/fullparity remain separate and incomplete. No install/sign/publish/commit/reset/clean/reference/OS/security/signal actions. Next continue actual unclosed non-destructive acceptance or reproduce a concrete approved defect, not reserved features or repeated closed tests. Full goal unachieved; previous/current goal turns are concretePROGRESS, no inheritedblockedcount.

Report: `Workflow/results/POST_ACTIVITY_INTEGRATION_RESULTS.md`; receipts: `.build/verification/20261018/post-activity-integration/`.

## Native search Undo/Redo verified — 2026-10-18

New controllednative evidence on unchanged bcf43c54 candidate/PID30428: own temporaryquery from initiallyemptysearch showed noresults; Editmenu UndoTyping enabled, Redodisabled. NativeUndo restoredemptyquery/originalfolder+apps/twopages andkeptsearchfocus. RedoTyping thenenabled; actualRedo restoredexacttoken/noresults. CmdZ/CmdShiftZ producedsameempty/tokenpair. No clipboardCopy/Cut/paste orapp launch/storage edits. Cleanupclickedownsearch+Escape thenemptyEscape, finalmainpage/noquery/folderclosed.501frozeninputs/exactexe/authoredlayoutcapacityunchanged; Library/trackingdefaultOFF/noactivityfile; no rebuild needed.

NativeTab didnotidentify a next focusedcontrol unambiguously; subsequentCmdZdidnotvisiblychangequery. This is retainedINCONCLUSIVE, notTabPASS orconfirmedproductdefect. UndoRedoPASSislimitedtoobservedactivefieldeditorsession, notcrosssessionundohistory/realIME/spokenVoiceOver. Wallpaperstillloading/black, notfixed. Allpriorjobs/agentsclosed; previous/currentgoalturnsconcretePROGRESS, nooldblockedcount. Fullparity/physicalperformance/reservedmajorfeaturesremainincomplete. Receipt `.build/verification/20261018/native-search-undo-redo/native-results-r1.json`; summary `Workflow/stage-summaries/2026-10-18-native-search-undo-redo.md`.

## Next major parity branch proposed: explicit app removal — 2026-10-18

After native Undo/Redo progress, Main inspected current approved roadmap and actual context/Library action sources. The previously reserved uninstall/delete feature is genuinely unimplemented, unlike already-delivered capacity/history. New English `Docs/APP_REMOVAL_PROPOSAL.md` specifies one-item standard macOS Move to Trash with explicit default-Cancel confirmation, conservative local/non-system/current-user-owned/not-running eligibility, test-profile confinement, existing immutable action binding and actual async receipt/Quit/refresh semantics. No support-file cleanup, permanent deletion, privilege, forcequit, extra gestures or page-model changes. Simple bundle trash is not claimed as complete uninstall; adversarial filesystem replacement is not claimed race-proof.

One asynchronous material-feature approval requested; routine autonomy does not override the earlier explicit destructive-scope reservation. NO implementation or removal authority inferred yet, and no real application will be used for native removal tests. Current501input/bcf43c54 candidate/3038green and controllednative states retained; no new build/test/UI or source edits. Full objective incomplete, with reserved gesture/page-model and physical/IME/VoiceOver/wallpaper/performance evidence gates still distinct. This turn PROGRESS through concrete next-feature specification/discovery, not a verified live-job wait. No agents/jobs running; do not repeat completed acceptance to create activity. Stage `Workflow/stage-summaries/2026-10-18-app-removal-discovery.md`.

## Safe app removal code verified and packaged; native pending — 2026-10-18

The human explicitly approved the bounded Move to Trash contract. Implementation adds context-menu and Library details actions with default-Cancel single-app confirmation; one off-main eligibility/receipt service, current binding/catalog/profile/owner/lifecycle checks, conservative running-app refusal, existing refresh/dormant organization and bounded Quit protection. No force quit, privilege, permanent delete, support-file cleanup or removal of formal apps during acceptance. It is not complete uninstall.

Final executed focused128/0(9.555s), full3095/0(109.343s), Debug0.58s, actualRelease61.86s and resourceprobe2.47s/package361keys×3languages/nativeentry/diffcheck PASS. Foundation/localization DeweyR2 boundedSOURCEPASS and integration DescartesR2 boundedSOURCEPASS; all agents/jobs closed. Preserve actual focusedR1 122/2assertfails (decoded NUL path guard) and reviewRED3methods/5assertfails (case-alias running match and hide/show late presentation). Repairs retain control/path guards plus legitimate percent filenames, fixed-POSIX conservative complete-path matching only for running refusal, off-main canonicalization with post-await validation/bounded cancellation, and hide-invalidated presentation epochs preserving actual receipts/refresh/Quit. No real APFS/native Trash claim from these regressions.

All511frozeninputs match after verification,14existingmodified+10new/zero removed versus501baseline; PagingCore and paging parameters unchanged. Original unchanged WallpaperBackdropControllerTests weak-variable warning is historical, not a new zero-warning claim.

New unsigned/uninstalled candidate `/Users/mac/Projects/Launch_Copy/PagingPrototype/.build/candidates/app-removal-rc-20261018-r1/LaunchcopyUITest.app`, executable SHA256 `975db8309a82e316c53e5c4d8f0fab189ebe521af94e9575b5f9f41c1748dbb8`, NOT LAUNCHED. Old own bcf43c54/PID30428 retained. New own82app fixture includes uniquely named valid disposable APPL app using only independently authored inert6972probe executable; no preferences/history/cache/locks imported. Disposable bundle untouched; no activity/Library preference file created. Fresh post-package CUA stilllocked, so no oldQuit/newOpen/actualTrash/Finderrecovery attempted. One concise manual-unlock request pending; no workaround or duplicate material approval request.

Current goal turn is concretePROGRESS (approved implementation, actual failure reproduction/repairs/reviews/tests/package), not a live-job wait or completion. No old blocked audit count carries forward; goal tool historicalBLOCKED cannot be setACTIVE by this API. Full parity/physicalperformance/realIME/spokenVoiceOver/120Hz/multidisplay/wallpaper and original folder-scroll causality remain incomplete. No install/sign/notarize/publish/commit/reset/clean/OS/security/reference-tree actions.

Authoritative report: `Workflow/results/APP_REMOVAL_RESULTS.md`; stage `Workflow/stage-summaries/2026-10-18-app-removal-implementation.md`; `.build/verification/20261018/app-removal/final-receipt.json`. After actual unlock: normal old-own Quit/exactabsence, exactnewcandidate open, preserve current user appearance/6×5, verify Cancel and only the authored disposable app's real Trash/refresh/dormant state/Finder recovery, then handover. Native outcome is NOT PASS yet; no need rebuild unchanged511inputs.


## Current supersession: native removal paths exercised — 2026-10-19

Manual unlock allowed actual testing of unchanged `app-removal-rc-20261018-r1` (SHA `975db830…`,511 inputs still match). Grid Cancel/real own-fixture Trash/automatic catalog disappearance and rediscovery, Library-details Cancel, real-running-probe refusal, normal Quit/restart and layout/capacity byte retention were observed. No real user app was removed. **Finder Put Back was disabled**; recovery passed only using native Finder Copy followed by Move Item Here into the exact original directory. Do not claim one-click Put Back or full native coverage.

Full dated report: `Workflow/results/APP_REMOVAL_NATIVE_ACCEPTANCE_2026-10-19.md`; receipt: `.build/verification/20261019/app-removal/native-results-r1.json`. Historical NOT LAUNCHED/locked snapshots below are preserved but superseded only for these gates. Latest own test PID98940 is available; Library/trackingOFF, FollowSystem, namesON/icon54/font12/6×5; integer blur reload28. No source changes, rebuild, install, commit or full-goal completion. Physical performance/realIME/spokenVoiceOver/wallpaper and original folder-scroll causality remain incomplete.

## Current delivery: responsive Library focus repaired — 2026-10-19

A concrete P2 was reproduced and repaired: results-table focus was lost when layout hid it before checking ownership. Capture ownership before visibility changes, then hand off only displaced results focus to the visible details-close button. Exactly2 existing source/test files changed; paging and storage contracts unchanged. Corrected RED3methods/2failures; focused45/0, full3098/0, Debug/actualRelease/package361keys×3languages and independent Kepler bounded source review passed. Native1400×1000px and800×1000px drawer transitions now focus the close button; Space returns to results. Search focus survives enlargement. These are scoped observed outcomes, not physical-performance/realIME/VoiceOver/full-parity acceptance.

Current unsigned/uninstalled isolated app: `.build/candidates/library-drawer-focus-rc-20261019-r1/LaunchcopyUITest.app`, SHA `658bd6b9…`, PID15521. Ordinary original-size main window, query empty, folder/settings closed; Library/trackingOFF, FollowSystem, namesON/blur28/icon54/font12/6×5. All511 inputs and seeded fixture bytes match. Wallpaper stillloading, NOT_FIXED. Full goal remains incomplete; this turn is concrete progress. Report `Workflow/results/LIBRARY_DRAWER_FOCUS_RESULTS.md`; stage `Workflow/stage-summaries/2026-10-19-library-compact-native.md`; dated receipts under `.build/verification/20261019/library-drawer-focus/`. Historical candidate/status snapshots below are preserved, not current handover.

## Current wallpaper wait localized on latest candidate — 2026-10-19

One path-free own-PID sample on current658bd6b9/PID15521 found the bounded LatestWallpaperRenderWorker waiting in decodeThumbnail→ImageIO source-open→open/__open (178nested observations). No condition-wait token in this window; not global absence or timing proof. Current failure is still NOT_FIXED; no evidence-based blur/compositor/permission/concurrency patch follows. All511inputs/87seededfiles unchanged, no new code/build/native setting changes. The separately proposed temporary OS-wallpaper A/B/A experiment still needs its explicit approval; no duplicate question or workaround. New current-build evidence is progress, not full-goal acceptance. Report `Workflow/results/WALLPAPER_CURRENT_WAIT_2026-10-19.md`; all prior physical/IME/VoiceOver/parity boundaries retained.

## Compact activity and Japanese Library controls verified — 2026-10-19

On unchanged658bd6b9/PID15521, actual800×1000px native Recent/Frequent menus, single controlled app display, search-empty/clear restoration and Japanese details/scroll-bottom/action-caption fitting were observed. One product-origin launch started own probePID19906 before binding; normal Quit/exact absence verified. No real user app/history. All511source inputs and85pre-existingJSON/plist fixture files unchanged; no rebuild/test rerun. FollowSystem/LibraryOFF/trackingOFF/original2000×1400px/emptyquery restored. One own synthetic request intentionally remains disabled in the isolated profile; do not Clear without action-time approval. This is not multi-app ranking/expiry, realIME/spokenVoiceOver/physical performance/human/full-parity acceptance. Full goal active and incomplete; wallpaper source-open problem remains NOT_FIXED and its OS-source experiment still unapproved. Report `Workflow/results/LIBRARY_COMPACT_ACTIVITY_LOCALE_NATIVE_RESULTS.md`; receipts `.build/verification/20261019/library-compact-activity-locale/`. Previous/current turns are concrete progress, no inherited blocked count.

## Resumed: populated source-loss integrity verified — 2026-10-19

Desktop access restored; same658bd6b9/PID15521, goal tool freshly ACTIVE. Native SourcesON/enabled→own metadata+same-inode root park→degraded/query retained/no apps→exact root restored→app returned before retry but status still degraded→native Refresh Now restores enabled coverage. Folder title/35 canonical members and native3pages01–15/16–30/31–35 survived. Exact86payloads including disabled one-request activity plus511sourceinputs unchanged; fault fullyrestored/parkabsent. No new source/build/test, formal-data/OS/security action. Main window original ordinary size, queryempty/folderclosed. This supersedes historical locked/blocked preflight, not full migration acceptance. Wallpaper now render-failed before/after fault; cause NOT_FIXED, no wallpaper change. Report `Workflow/results/POPULATED_SOURCE_LOSS_NATIVE_RESULTS.md`; receipts `.build/verification/20261019/populated-source-loss/`. A bounded folder-dismissal AX source audit is active; count differences alone are not a proven defect/VoiceOver claim. Full objective unchanged/incomplete; fresh blocked counts reset by actual progress.

## Current checkpoint: recovery passed; count-only AX hypothesis not established — 2026-10-19

Populated-source native recovery and exact fault rollback completed on658bd6b9/PID15521:35canonicalmembers/3nativepages and retained disabled one-request history survived; all511sourceinputs/86fixturepayloads unchanged. Sources manual retry restored enabled coverage; query preserved through absence. Folderclosed/mainoriginalordinarysize/queryempty. Separate Chandrasekhar bounded read-only audit (15inputs) found no concrete dismissed-folderAX/focus defect; counts106→166 alone do not justify a patch, and no VoiceOver/nativeAX PASS follows. Reviewer closed, no live work job; intentional app is not a wait. No new source/build/tests/permissions/OS/reference/formaldata actions. Historical grid-capacity proposal now explicitly points to newer approved main-only independent-folder/liveAppearance contracts. Goal ACTIVE/incomplete, old blocked counts reset after actual desktop progress. Reports `Workflow/results/POPULATED_SOURCE_LOSS_NATIVE_RESULTS.md` and `Workflow/reviews/FOLDER_DISMISSAL_AX_AUDIT-r1.md`. Wallpaper currentlyrender-failed, NOT_FIXED; realIME/spokenVoiceOver/physical/hardware/fullparity gates remain.


## 2026-10-19 — Approved wallpaper source control

Executed same-candidate native original/authored/original experiment with verified restoration. All three fresh launches ready; original A recovered before source mutation, so no source-specific cause or fix established. 511inputs/86fixturepayloads unchanged, no new code/build/test. Own test processes normally quit; original OS wallpaper restored. Independent bounded evidence review agrees. Full report: `Workflow/results/WALLPAPER_SOURCE_CONTROL_RESULTS_2026-10-19.md`.


## 2026-10-19 — Bounded main-grid proportion tuning

Selected independent128pt max maincell width in shared frame geometry; vertical/envelope/capacity/order/saved glyph preferences/folder/physics unchanged. 3newtests plus3legacytestassertion adaptations; full3101/0 after retaining failedr1history, focused38/0, builds/package and bounded source reviews. New75ba5344 candidate bounded native observed; finaltestnormallyQuit,6x5restored. Human/physical/wide/drag acceptance remains separate. Report Workflow/results/MAIN_GRID_PROPORTIONS_RESULTS.md.


## 2026-10-19 — Spacious main-grid visual correction
Human rejected narrow-column design. Independently implemented main32–96pt/default80, restored available width, shared main-only height/actual-fit/drag/source geometry, schema3 with legacy nilinheritance and future protection; folders/physics/cache unchanged. Source review reproduced/fixed selected-capacity-fit P2. Full first-run failures and package stale361count preserved, bounded compatibility verifiers/tests corrected without weaker gates. Final514-input frozen r3: focused62/0/full3131/0/Debug/actualRelease/package/resources365×3exit0. Native own ordinary test main80/base48/sourcefolder/search/liveslider/restart observed, suffixr2/sha dc4ed86f…/PID72970 left running. Full report underWorkflow/results/MAIN_GRID_SPACIOUS_ICONS_RESULTS.md; human visual/physical and wallpaperloading/cause/fullparity stillopen. No commit/sign/install/reference/formal-data change.

## 2026-10-19 — Fixed Sources native-entry verification prerequisite
OnlyNativeUITestEntry+2Scriptsmodified, newSwift/Pythontests:strictversion2fixedsources-v1presetusesexistingownedBaselineroot;legacy1/production/UI/Core/cacheuntouched. FirstPythonparserexception-testerrorretainedandexactlycorrected. Final516inputs/Python12/0/focused114/0/full3138/0/Debug/Release/package/resourcesgreen,sourceACCEPT. ActualnativeAddCancel/draft-close/AddApply/querypreserved/Extras+automaticOFFnormalQuit/restartverified;remainingremove/readdlatent/watchpacketpending. Sourcecandidateb88e0968…closed; restoredunchangedvisualdc4ed86fPID86437. WallpaperREADYonreopenedoldvisualnotcausalfix. Fullgoalstillopen; detailedresults/stagesnamedincurrentPLAN.


## 2026-10-19 — Native Sources removal/re-addition and watcher packet
On unchangedb88e candidate, actual cross-source folder creation plus own alias/hidden setup survived native RemoveExtras/Apply/Readd/Apply. Five snapshots/currentdisk prove identical624-bytecanonicaljournal and fouroriginalmetadata; actualfoldermembers/hiddenaliasreturned. SavedOFF native eventabsence/manualdiscovery, savedON separatednestedpark/restoreautoabsence/reappearance, actualQuit/restart organization+automaticON recovery. Controlledmetadata-onlyfixtures, boundedtiming, no realAppLaunch/physical/fullgoalclaim. Eventrestored,Sourceinstancesclosed, unchangedvisualdc4ed/PID94664restored/249seedfilesunchanged;516inputsunchanged/no testsbuildsrerun. Planck boundedhelper/evidenceconsistency supported; documentationP2resolvedbydatedsupersession. NextmanualRefreshconflictingUNSAVEDdraftnativecontrastremains. Currentcompactauthority Docs/CURRENT_DELIVERY_INDEX.md; detailedresult SOURCES_REMOVE_READD_WATCH_NATIVE_RESULTS.md.

## 2026-10-19 — Sources popup width and native locale follow-up

Completed saved/draft Sources evidence review and prior-b88e EN/JA Appearance inspection with exact FollowSystem restoration. Reproduced long source title increasing unshown tab content500→2798; repaired with five popup compression/truncation lines, full menu identities retained. Added one regressiontest; final517inputs/focused56/0/full3139/0/Debug/actualRelease/package365×3 and Turing boundedsource/testreviewpassed. Freshde3b27a6 Chinese nativecompactsource/appearance/selectedpathretentionpassed; no Apply, fixturemetadataunchanged, own26988normallyquit. Restoredunchangeddc4edvisualPID29854ordinary/queryempty/folderclosed/wallpaperREADY. Fullgoalnotcomplete, noformaldata/reference/install/sign/Git/signals. See Workflow/results/SETTINGS_SOURCE_PATH_WIDTH_RESULTS.md and CURRENT_DELIVERY_INDEX.md.

## 2026-10-19 — folder member content refinement
Userrequestedfolderlayouttoo. AddedexplicitfolderGrid centered6ptstack; regular/reused/swipecellsandcapturedfractionalpreviewagree. Replacedpost-collapserecapturewithcached-onlyelevation.5productionfiles+2newtestfiles,8newmethods; frozen519inputs,focused61/0/full3147/0/Debug/actualRelease/package365×3passed. GoodallboundedSOURCEACCEPT. New3f01be1d ownfixture82apps/249verifiedfiles; nativepages1–3/48→explicit64/main80/savedrestartobserved. Current52219ordinary/folderpage1open; old/newseedbytesandcanonicalorderunchanged. Two generateddragattemptsINCONCLUSIVE_NO_COMMIT, notinputrootcauseproof/physicalPASS. Main keepsnextnativecontroldiscriminatorandfullparitylimits explicit. Noformaldata/reference/install/sign/Git/signals. Results:Workflow/results/FOLDER_MEMBER_LAYOUT_REFINEMENT_RESULTS.md.

## 2026-10-23 timestamp repair: native ready for physical retest
Actual4738/4738future-frame rejection captured before reset. Backend ingress bounding +raw-order/invalid-release protection implemented;13newtests, final3609/0, focused74/0, Debug/Release and independent staticaccept.585inputs/currentcandidate9f5ddb04 match. NewnativePID13366 realREADY,parent/outwardON, idle/queryempty/modalclosed, zero prehumanbaseline, observationreset. Previousowned99781 normalQuit/absence+161files preserved; original249/priorphysical161 intact. Wallpaperloading: gestureonly. PhysicalfixstillPENDING; do notclaimsuccess orresetbeforecounterread. Details: Workflow/results/OUTWARD_HIDE_TIMESTAMP_REPAIR_2026-10-23.md.

## 2026-10-23 functional handover complete
After unlock retained realgesturepost-trialcounts (future0/18371, Show4/Hide2;2302expiredunclassified), then normallyQuit owned13366. New same-source normal isolatedcandidate `functional-launch-rc-20261023-r1/LaunchcopyUITest.app`, SHA9f5ddb04, livePID71815. Actual main App38 and folder App01 iconclicks created exactnew-candidate probeprocesses72742/74473 before anytargetbinding; bothsuccesswindowsobserved, normalQuit/exactabsence. No source/testchange;585inputs stillmatch prior3609/0; strictReleasepackage passed. Original+cloned249files/modes/arrangement preserved; allprobesclosed, mainqueryempty/folder/settingsclosed/wallpaperREADY. OrdinaryUIentry remainsfake-only: fourfingervalidation is separate. See Workflow/results/FUNCTIONAL_LAUNCH_HANDOVER_2026-10-23.md and final-native-receipt.json. No fullparity/real-user-app/independentliveReview claim; nothinginstalled/signed/Gitchanged.
