# PHASE1A_BASELINE_RECONCILIATION.md — Phase 1A 基线对账（Gate 0）

- **日期**：2026-08-28
- **执行**：Main（Gate 0，Phase 1B Prompt §1）
- **目的**：冻结 Phase 1A 真实基线，消除磁盘记录不一致；不伪造历史事件；不自动 commit。

## 1. 只读盘点结果（§1.2）

### 1.1 环境

| 项 | 值 |
|---|---|
| Git branch | `main` |
| HEAD | **无**（0 commits；全部文件 untracked，11 项） |
| Swift | 6.3.3（swiftlang-6.3.3.1.3，arm64-apple-macosx26.0） |
| Xcode | 26.6 (17F113) |
| macOS | 26.5.2 (25F84) |
| 架构 | arm64（MacBook Air M3） |

### 1.2 源码/测试清单

- Sources：20 个 Swift 文件（PagingCore 6 / PagingTelemetry 4 / PagingUI 4 / PagingPrototypeApp 6）
- Tests：17 个 Swift 文件（Core 2 / Telemetry 4 / UI 11）
- 静态 `func test` 计数：**181**（仅交叉检查，非执行数）

### 1.3 当前默认参数（PagingParameters）

| 参数 | 默认值 |
|---|---|
| displacementThreshold | 0.46 |
| retreatDisplacementFactor | 20.0/23.0（回退 0.40） |
| momentumDecay | 0.55 |
| momentumGlideFrames | 1（显式 nil = 跟完整系统流） |
| momentumMaxOvershoot | 0.20（软阻尼 0.2×delta） |

### 1.4 当前帧驱动

- `RunLoopFrameDriver`：主 runloop common 模式 60Hz Timer 帧泵（≈16.67ms），**非 vsync**（本机 display link 零回调实证）；vsync 对齐留 Phase 1B 可选实验。

## 2. 文档矛盾清单（§1.2 记录）

| 位置 | 记录 | 实际 | 处置 |
|---|---|---|---|
| README.md | 140 tests；物理门 NOT_RUN | 181 tests；60Hz PASS（用户实机） | 更新为本次真实执行结果 |
| Docs/PHASE1A_REPORT.md | 旧版（144 tests；Step 8 等待用户） | 已过时 | 保留历史 + 顶部标注 superseded by 根 PHASE1A_REPORT.md |
| PHASE1A_REPORT.md（根） | 180 tests | 181（固化后 +1） | 更新为 181 |
| Docs/VALIDATION_RESULTS.md | 60Hz PASS / 120Hz BLOCKED | 一致 | 无动作（保留） |
| Workflow/STATE.json | T-worker-b=EXECUTING；T-worker-b-tune/tune2/togglebtn=REVIEWING | 实际已完成（有结果文件/事件） | 标 `STALE_STATE_RECORDED`（不伪造 review） |
| Workflow/events.jsonl | append-only | — | 不重写 |

## 3. 清洁基线（§1.3，本次真实执行）

- 命令：`swift package clean` → `swift test` → `swift build -c debug` → `swift build -c release`
- 时间：见 IMPLEMENTATION_LOG.md Gate 0 段（开始/结束时间戳）
- executed test count：**181 tests, 0 failures**（2026-08-28 19:44:59–19:45:22，swift test 真实输出）
- Debug：`80566d2293c79d66bb80ffeeea2d8908520c57558a194b2fdb5a1785d09e87ee`；Release：`f95ea284f11d79d9e3c86a67edf9065432119cedd4c099aae6fb736417d1e044`（清洁重建后）
- Tree manifest：`Docs/PHASE1A_BASELINE_MANIFEST.sha256`（排序稳定，排除 .git/.build/临时文件）

## 4. 对账动作（§1.4）

1. README.md：测试数/物理门表述更新为本次真实结果（140 历史数字保留在 IMPLEMENTATION_LOG 历史段）。
2. Docs/PHASE1A_REPORT.md：顶部加 superseded 标注（历史保留，不删除）。
3. 根 PHASE1A_REPORT.md：AUTOMATED_TESTS 180 → 181。
4. Workflow/STATE.json：4 个陈旧任务标 `STALE_STATE_RECORDED`（附 result/event 证据引用；**不补写不存在的 review**）。
5. 60Hz 物理门：引用用户 2026-08-28 实机结果（主观 4/4/4/4/4），明确为**用户实机证据**，非本次自动化重跑证据。
6. 120Hz：保持 `BLOCKED_BY_HARDWARE`（无新设备证据）。
7. 帧源：文档统一写 `RunLoopFrameDriver（60Hz Timer，非 vsync）`。
8. 不自动 commit/push/tag/release；以 manifest/hash 冻结。

## 5. Gate 0 通过条件（§1.5）

| 条件 | 状态 |
|---|---|
| PHASE1A_BASELINE_RECONCILED | **PASS**（本文件 + 对账动作完成） |
| PHASE1A_BASELINE_FROZEN | **PASS**（Docs/PHASE1A_BASELINE_MANIFEST.sha256，118 文件） |
| BUILD_DEBUG / BUILD_RELEASE | **PASS**（清洁重建 exit 0，0 warning） |
| AUTOMATED_TESTS | **PASS**（181 tests, 0 failures，真实执行） |
| MANUAL_PHYSICAL_GATE_60HZ | PASS_USER_REPORTED_WITH_EVIDENCE_REFERENCE（2026-08-28 用户实机） |
| MANUAL_PHYSICAL_GATE_120HZ | BLOCKED_BY_HARDWARE（60.0Hz 面板，无 ProMotion） |
