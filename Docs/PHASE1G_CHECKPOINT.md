# Phase 1G 接力检查点（Main 持续更新）

> 简短接力检查点（§24 要求）；不塞全量日志。最后更新：2026-09-10（T-1G-E 组合根交付，物理门仍挂账）。

## 1. 当前任务 / 构建 / 测试

- **当前任务**：T-1G-E AppDelegate composition root（resident launcher）已交付，待 Reviewer；T-1G-B/C/D 已落地。
- **构建**：`swift build` / `swift build -c release` exit 0（T-1G-E Worker）。
- **测试**：见 `Workflow/results/T-1G-E.md`（全量 `swift test` + `LauncherIntegrationTests` 8）。
- 基线：T-1G-C 全量 1460 → T-1G-E 预期 ≥1468（+8 integration）。

## 2. 用户已确认的决定（原话范围）

1. **严格 4 指**（恰好 4 触点，5 指不触发）——2026-09-05。
2. **四指默认开启**（用户选非推荐项；覆盖 ADR-013 §7 原锁定 false；默认开启≠立即启用，仍须实现+验证+物理门通过）。
3. **风险清单接受**（FOUR_FINGER_RISK_REGISTER.md R-01..R-07）→ 允许按防护计划运行采集实验；实验前 Main 再次告知内容。
4. **参照 LaunchBetter PinchAnalyzer 模型调整识别器**（用户是 LaunchBetter 作者，授权直接读其实现；events.jsonl #824）。
5. **张开不自动 Hide**（pinchOut 不触发；spread 实机验证 fired=0 确认）。
6. Phase 1G 先做纯逻辑（2026-09-05 gate0 决策）；B10 默认关定案、B11 验收延后。
7. **继续 T-1G-B→E，B10/B11 挂账不挡**（2026-09-10；`PROCEED_WITH_DEFERRED_GATES`）。

## 3. 事实 / 假设 / BLOCKED / 未跑门

- **事实**：MTTouch state 是位掩码（R-02）；首帧基线+相对收缩模型识别器级实机 PASS。
- **事实**：ADR-011 Q3 **Option B** screen-covering panel；ADR-012 Q2/Q3 Carbon hotkey + Timer poll **ACCEPTED**。
- **事实（T-1G-E）**：blank/ESC/launch/close → **hide**；Quit → quit+terminate+teardown；`applicationShouldTerminateAfterLastWindowClosed = false`；四指 `process`+`flushPendingShows` → 同一 `LauncherWindowController`。
- **BLOCKED**：无。
- **未跑门（诚实 PENDING，不宣称 PASS）**：
  - Phase 1F B10 实机 A/B、B11 视觉验收
  - Phase 1G M01–M12 完整矩阵、能耗 A/B、MULTI_DISPLAY、120Hz、SLEEP_LOCK、RAPID_RACE

## 4. Worker / Reviewer 文件所有权与真实会话状态

| 任务 | 状态 | 备注 |
|---|---|---|
| T-1G-A … T-G-P7 | PASSED（历史） | 四指自动化轨收口 |
| T-1G-B | COMPLETED（待/已 Review） | LauncherWindowController + Option B |
| T-1G-C | COMPLETED（待/已 Review） | StatusItem + Dock reopen |
| T-1G-D | COMPLETED（待/已 Review） | Shortcut + HotCorner + Session |
| T-1G-E | COMPLETED（待 Reviewer） | Composition root；见 results/T-1G-E.md |

## 5. 下一条具体动作 / 所需权限 / 停止条件

1. Reviewer 独立裁决 T-1G-E。
2. T-1G-F / 物理门：M01–M12、能耗、多屏、B10/B11——仅真实证据可 PASS。
3. 偏好 UI 面板仍 stub（Activation Settings…）。
- **停止条件**：`HOT_CORNER_ENERGY_GATE_FAILED` / `PHYSICAL_ACCEPTANCE_PENDING` / 权限扩张需用户决策。

## 6. 性能三个 token 与参考接触声明

- `PRODUCT_TIMER_TOLERANCE_0MS` / `SHORT_TAIL_MITIGATED_BY_TOLERANCE`（20-25ms）/ `CAUSALITY_UNRESOLVED_FOR_GT25MS`——不变，PagingCore 冻结。
- 参考接触：LaunchBetter 白名单只读；Buho 未读；T-1G-E **未**读 LaunchBetter / BuhoReverseNotes。

## 7. 样本和报告位置（不含真实触点原始轨迹）

- 报告：`Workflow/results/T-1G-B.md` … `T-1G-E.md`；`Docs/ADR-011` / `ADR-012` / `ADR-013`；四指 SPEC/VALIDATION/RESULTS。
- 决策：`Workflow/decisions/2026-09-10-phase1g-continuation.md`。

## 8. 更新记录

### 2026-09-06 收口
- T-G-P7 关闭；**PHASE1G_AUTOMATED_COMPLETE_PHYSICAL_PENDING（PARTIAL）**。

### 2026-09-10 T-1G-B→E
- Option B 窗控 + Status Item + Shortcut/HotCorner + **AppDelegate 组合根**落地。
- 产品语义：驻留 hide vs Quit terminate。
- 物理门仍 **PHYSICAL_PENDING**（不发明 PASS）。
