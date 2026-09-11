# VALIDATION_RESULTS.md — Phase 1A + Phase 1B + Phase 1C 验证结果

- **创建**：2026-08-28（T-step7，Main）
- **更新规则**：状态分开记录；未执行项写 `NOT_RUN` 或 `BLOCKED`，**不写 PASS**；Reviewer E 与人工物理验收后回填。
- **状态总表**：

| 状态项 | 状态 | 证据 |
|---|---|---|
| BUILD_DEBUG | **PASS** | `swift build -c debug`（清洁 .build）exit 0；2026-08-28；Xcode 26.6 (17F113)/Swift 6.3.3/macOS 26.5.2 arm64 |
| BUILD_RELEASE | **PASS** | `swift build -c release`（清洁 .build）exit 0 |
| AUTOMATED_TESTS | **PASS** | `swift test` **181 tests, 0 failures**, exit 0（Gate 0 清洁基线 2026-08-28 真实执行；历史：140→144→180→181，见 IMPLEMENTATION_LOG） |
| CODE_REVIEWED | **PASS** | Reviewer E 独立审查 PASS（`Workflow/reviews/T-reviewer-r1.md`，2026-08-28；无 BLOCKER/MAJOR，5 MINOR+2 QUESTION 已处理/修复波） |
| SOURCE_REVIEWED | **PASS** | Reviewer E 独立复跑 8 类扫描（禁词/路径/bundle-id/绝对路径 0 泄漏；strings 0 命中；git 无提交；9 个 telemetry 工件在案）。注：扫描=泄漏预警，非原创性证明 |
| VISUAL_NEUTRALITY_REVIEWED | **PASS** | Reviewer E：命名中立（0 Buho 身份/地址/一一对应含义）；页面中性几何占位、无品牌元素（T-worker-d 交付） |
| MANUAL_PHYSICAL_GATE_60HZ | **PASS** | 2026-08-28 用户真实触控板全屏复测（1470pt 基准）：主观五项 4/4/4/4/4（跟手性/中断连续性/settle 自然度/边界反馈/总体丝滑）；调参史 12 轮（input-fix→frame-fix→decay→glide 10/5/3/1→overshoot 0.35/0.20 软阻尼→对称阻尼线→回退宽容 0.45/0.42/0.40→全屏基准 0.48/0.46）；181 tests 0 failures（Gate 0 清洁基线）；telemetry 全链路（frame/transition/commit/stale）正常；帧源 = runloop 60Hz ≈16.67ms（非 vsync，诚实标注，vsync 留 Phase 1B） |
| MANUAL_PHYSICAL_GATE_120HZ | **BLOCKED** | 硬件实锤：CGDisplayCopyDisplayMode 主屏 60.0 Hz（MacBook Air M3，无 ProMotion；displayMinInterval==displayMaxInterval），无 120Hz 设备证据 → 按 §8 纪律 BLOCKED，不写 PASS；120Hz 目标留 Phase 1B（换 120Hz 设备后重跑） |
| AUTOMATED_TESTS_1B | **PASS** | `swift test` **414 tests, 0 failures**, exit 0（Phase 1B 全量，2026-08-28 真实执行；Gate 0 基线 181 → Wave1 306 → Wave2 390 → Wave3 414） |
| BUILD_1B | **PASS** | `swift build -c release` exit 0 零警告（Phase 1B 装配后，Main 复验） |
| APP_LAUNCH_SMOKE_1B | **PASS** | §3.2 全项（单击触发/NSWorkspace 公开 API/stale 拒绝/失败非致命/telemetry 无真实 URL）；键盘层按 §9 延 Phase 1C |
| MANUAL_PHYSICAL_GATE_60HZ_REAL_CONTENT | **PASS** | 2026-08-28 用户真实内容全屏复测（1470pt 基准，phys1b-03/04）：主观五项 4/4/4/4/3.6（跟手性/中断连续性/settle 自然度/边界反馈/总体丝滑），用户确认"OK的"；调参史 14 轮（…→0.46/0.40→0.45/0.38→**0.43/0.36**）；phys1b-04 telemetry：423s、41 翻页尝试（30 commit：28 跨页 + 2 同页 bounce；11 interrupted = stale_rejected 11/11 重合，latest-wins 预期）、835 frame（~16.7ms 60Hz）、icon 118 completed + 118 stale_rejected；414 tests 0 failures；帧源 = runloop 60Hz（非 vsync，诚实标注）。注：phys1b-04 run 未走干净 teardown（窗口仍开，无 run.end），接受证据为 00:04:44 前完整手势段 |
| MANUAL_PHYSICAL_GATE_120HZ_1B | **BLOCKED** | 同 Phase 1A：主屏 60.0 Hz 硬件实锤，无 ProMotion → 120Hz 不写 PASS；留待 120Hz 设备 |
| AUTOMATED_TESTS_1C | **PASS** | `swift test` **526 tests, 0 failures**，exit 0；含键盘焦点/方向键/跨页调和/Return-Enter 启动/ESC 清框/空白单击分类回归 |
| BUILD_1C | **PASS** | `swift build -c debug` + `swift build -c release` exit 0（Phase 1C 最终基线） |
| REVIEW_1C | **PASS** | T-1C-A/B/C/D 及 repair 均经独立 Reviewer；T-1C-D 首轮 ESC 视觉残留 FAIL 经 repair + re-review 闭合；blank-click review 无 BLOCKER/MAJOR/MINOR |
| MANUAL_KEYBOARD_GUI_GATE_1C | **PASS_USER_REPORTED_WITH_EVIDENCE** | 2026-08-30 用户在重新拉起的真实全屏 GUI + 物理键盘上完成请求矩阵后确认「没有问题」：方向键连续导航/跨页、← 行末落位、延迟焦点播种、ESC 清框、Return/Enter 启动 |
| MANUAL_BLANKCLICK_GUI_GATE_1C | **PASS_USER_REPORTED_WITH_EVIDENCE** | 用户真实全屏复测确认首个已接收的空白单击退出「OK了，没有问题了」；最终键盘验收未报告回归 |

## 自动化测试明细（2026-08-28 清洁状态）

| 套件 | 数量 | 结果 |
|---|---|---|
| PagingCoreTests（§7.1 场景 + §7.2 序列） | 51 | 0 failures |
| PagingTelemetryTests | 33 | 0 failures |
| PagingUITests（§7.3 正确性 + §7.4 性能边界 + §3.F 门禁） | 60 | 0 failures |
| 性能探针（PerfBenchmark CLI + 探针测试） | 5 | 0 failures |
| Reviewer 修复波回归（M-4 高度 resize ×3 + Q-2 时间戳 ×1） | 4 | 0 failures |
| **合计（Gate 0 清洁基线）** | **181** | **0 failures** |

## Phase 1B 自动化测试明细（2026-08-28 清洁状态）

| 套件 | 数量 | 结果 |
|---|---|---|
| AppCatalogCoreTests | 56 | 0 failures |
| MacAppCatalogTests | 45 | 0 failures |
| AppIconPipelineTests | 23 | 0 failures |
| PagingUITests（含 seam 15） | 93 | 0 failures |
| AppGridUITests | 49 | 0 failures |
| PagingTelemetryTests（含红线 21） | 54 | 0 failures |
| PagingCoreTests（Phase 1A 基线） | 70 | 0 failures |
| 集成/装配（Wave 3） | 24 | 0 failures |
| **合计（Phase 1B 全量）** | **414** | **0 failures** |

## 诚实边界（Prompt §16.C 对应）

- 以上全部为**自动化验证**（构建 + 测试 + 性能探针），不是物理验收。
- 自动化性能测试仅作回归预警（§7.4）；§8.5 的 60Hz 目标中"主观跟手/连续/settle ≥4/5"与真实帧节奏**未执行**。
- 无头环境 CADisplayLink 不触发（T-step6 run1 零帧事件为硬证据），真实显示节奏验证依赖 T-step8 人工。
- 来源扫描 = 泄漏预警（见 IMPLEMENTATION_LOG Step 7），不是原创性或法律证明；正式 SOURCE_REVIEWED 待 Reviewer E。
- 无任何 commit/push；git init 后仓库保持无提交状态。
- 人工物理验收步骤见 `Docs/MANUAL_TEST_STEPS.md`（T-step8 材料，等待用户执行）。

## 更新记录

| 日期 | 更新 | 执行人 |
|---|---|---|
| 2026-08-28 | 创建初始状态（T-step7） | Main |
| 2026-08-28 | Phase 1B 回填：414 tests、BUILD_1B、APP_LAUNCH_SMOKE_1B、60Hz 真实内容物理门 PASS（用户 4/4/4/4/3.6）、120Hz 仍 BLOCKED | Main |
| 2026-08-30 | Phase 1C 回填：526 tests、Debug/Release、独立 Review 全部 PASS；真实键盘 GUI 门与 blank-click GUI 门获用户报告通过；`RECOMMEND_PROCEED_TO_PHASE_1D` 生效 | Main |
| 2026-08-30 | Phase 1D 回填：620 tests（526 + 94：T-1D-A 33 / T-1D-C 14 / T-1D-B 20 / T-1D-D 16 / T-1D-E 8 + BlankClickToQuit 3）、Debug/Release、独立 Review T-1D-A..E 各 r1 全 PASS；手动 GUI 门（搜索 GUI/键盘/触控板/空白单击回归）NOT_RUN；`RECOMMEND_PROCEED_TO_PHASE_1E` 待手动门通过后生效 | Main |
| 2026-08-30 | Phase 1E 回填：756 tests（631 + 125：H2 2 / T-1E-A 27 / T-1E-B 20 / T-1E-C 29 / T-1E-D 32 / T-1E-D-repair 3 / T-1E-E 12）、Debug/Release、独立 Review T-1E-A..E + H2 + D-repair 全 PASS；手动门（文件夹 GUI/键盘/触控板回归）NOT_RUN；`RECOMMEND_PROCEED_TO_PHASE_1F_DRAG_AND_PERSISTENCE` 待手动门通过后生效 | Main |
| 2026-08-30 | Phase 1E 修复波次：Bug 1-4 + 打字机（inner-nav 16 / focus-layout 10 / keyboard-return 3 / typewriter-outer 2 / typewriter-inner 2 = +33）→ 789 tests, 0 failures；用户实机验收打字机"没问题了"（decision_recorded T-1E-nav-typewriter-user-accepted）；文件夹 GUI/键盘门 PASS_USER_REPORTED_WITH_EVIDENCE，触控板 60Hz 回归门保持 NOT_RUN | Main |
| 2026-08-30 | Phase 1F Gate 0 对账：T-1E-folder-open-repair EXECUTING→PASSED（拆分任务证据）；ADR-006 §9 日期笔误修正（08-31→08-30）；复跑 789/0 + debug/release exit 0；`Docs/PHASE1F_BASELINE_MANIFEST.sha256` 创建；`PHASE_1E_WORKFLOW_RECONCILED`；`PHASE_1E_KEYBOARD_AND_FOLDER_GUI_ACCEPTED` / `PHASE_1E_TRACKPAD_60HZ_REGRESSION_PENDING` | Main |
