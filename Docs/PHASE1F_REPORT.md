# Phase 1F 报告（REPORT）

> 状态：**AUTOMATED_COMPLETE_PHYSICAL_PENDING**（2026-09-05 Gate 0 对账补建）
> 本报告由 Phase 1G Gate 0 对账产出，全部结论基于 Workflow 既有证据 + 2026-09-05 fresh 重跑。

## 1. 目标与交付

Phase 1F 交付拖拽持久化与布局存储：拖拽 reorder/create/add/move-out/cross-folder 语义（ADR-010）、workspace layout store（schema v1、A/B journal、coalescing、flush barrier、失败态、reset、多实例，ADR-009）、以及 BUG6/7/8/9/10/11 点击/启动/指示器回归修复。

## 2. 用户输入与仓库事实分离

- 用户 2026-09-05 报告 Folder 功能已实现 → 记录为 `USER_REPORTED_PHASE1F_FUNCTIONALLY_COMPLETE`（实机验收输入，不自动改写 Workflow 状态）。
- 本 Prompt 编写前快照的遗留状态（T-1F-B/C/resume EXECUTING、B10-regression REVIEWING、next_action 过时）经 Gate 0 逐项对账：子任务全 PASSED、主任务标签过时、B9-diagnosis 有 worker_completed 无独立评审、B10-regression-fix r5 PASS 但实机 A/B 未回填。

## 3. Fresh 基线（2026-09-05）

- `swift test`：**1137 tests / 0 failures**，exit 0；
- `swift build` / `swift build -c release`：exit 0；
- Debug SHA-256 `69f7f88f…`，Release SHA-256 `ebbf77c0…`（完整值见 VALIDATION_RESULTS）；
- layout store 测试仅用临时目录，不触碰真实 Application Support。

## 4. 关键结论

| 主题 | 结论 |
|---|---|
| B10 生产默认路径 | `PAGING_CLICK_MANUAL_DELIVERY` 默认关 = 生产零行为变更（Fixture A/B 双自证）；门控开全链 14/14 自动化通过；**实机 A/B 未回填（Q-1）** |
| B11 指示器 | 跨行/行末 insertion indicator 实现 + 10/0 测试 + r1 PASS；**真实窗口视觉验收 PENDING** |
| 拖拽/持久化 | 自动化全绿；用户已确认 Folder 功能；重启恢复等其余实机项按证据对账 |
| 性能 token | `PRODUCT_TIMER_TOLERANCE_0MS` / `SHORT_TAIL_MITIGATED_BY_TOLERANCE` / `CAUSALITY_UNRESOLVED_FOR_GT25MS` 保持，Phase 1G 不修改 |

## 5. 未解决问题

1. B10 实机 A/B 读数未回填（r5 Q-1：门控关基线 35-38 击 / 门控开 10+ 击 s10==击数、空白 s8c、ESC、拖拽预览、搜索与 folder 开合；Q-2：门控开点搜索框聚焦、开 folder→关 folder→顶层点击启动）。
2. B11 真实窗口/触控板视觉验收未执行。
3. T-1F-B9-diagnosis 无独立评审文件（诚实标记，不补造）。
4. RunLoopFrameDriverTests 既有 flaky（隔离 3/3 绿，全量负载间歇失败）——独立挂账，非 Phase 1F 引入。

## 6. 结论与下一阶段

Phase 1F 自动化完成、物理门未闭合 → **`PHASE1F_AUTOMATED_COMPLETE_PHYSICAL_PENDING`**。
Phase 1G（驻留启动器 + 菜单栏 + 快捷键 + Hot Corner + 四指捏合）行为代码在物理门回填前不启动；纯逻辑状态机、四指识别器 Mock、文档与 ADR 工作可先行。
