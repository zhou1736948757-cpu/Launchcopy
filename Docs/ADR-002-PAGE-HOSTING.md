# ADR-002 — 页面承载方案（Page Hosting）

- **状态**：ACCEPTED（2026-08-28，T-step1，Main 编写；本 ADR 自查通过后生效）
- **决策范围**：Phase 1A 页面承载方式；受 `Docs/PHASE1_SPEC.md` §2.1.H 约束
- **变更需**：Chief 决策（PLAN.md Chief-Owned Decisions #5：从 live views 切换到 compositor 属方案级变更；T-step6 若需修订本 ADR 必须经 Main 路由 Chief）

## 1. 背景

分页滑动时页面内容如何承载，直接影响跟手性、内存上界与实现复杂度。需比较两种候选并给出可验证的选择理由，不得未经测量假定复杂方案更快。

## 2. 候选方案

### 方案 1：live AppKit view 层级

- 每个页面是一组真实 `NSView`，随手势热路径移动（`frame`/`bounds` 变换或容器滚动）；
- 页面内容按需 prepare/reuse；手势热路径只做几何变换与合成，不做重资源操作。

**优点**
- 实现简单直接，正确性调试成本低；
- 与 AppKit 合成、辅助功能、`accessibility` 描述天然一致；
- 页面内容正确性（空白/重复/错页）可被 UI 测试直接观察；
- 便于先验证状态机正确性（Prompt §6 Step 3："先确保正确性，再优化"）。

**缺点**
- 页面数/视图数增长时，view 层级与内存随 live radius 线性增长（需上界策略）；
- 重资源内容（真实图标解码等）若误入热路径会造成 hitch（本阶段用占位几何图形规避）。

### 方案 2：轻量 compositor / 预渲染页面视觉

- 滑动期间显示预渲染位图/轻量绘制层，稳定后恢复 live content（或全程轻量绘制）。

**优点**
- 热路径只合成像素，view 数量与页面数解耦；
- 页面数量大时内存更可预测。

**缺点**
- 需要管理"预渲染快照 vs live 内容"两套状态与同步，引入快照过期/恢复错位风险；
- 辅助功能/可访问性描述需要额外桥接；
- 正确性（旧内容残留、快照与 live 错位）更难测试；
- 实现复杂，若没有测量证据，无法证明更快（Prompt §3.H 明确禁止假定）。

## 3. 决策：先实现方案 1（live AppKit views），telemetry 驱动是否启用方案 2

### 3.1 选择理由

1. Phase 1A 的目标是验证**分页交互引擎**（跟手/连续/中断/稳定），页面内容为中性的占位几何图形，view 承载的负载边界清晰；
2. Prompt §6 明确要求"先确保正确性，再优化"；方案 1 让正确性测试（§7.3）直接可观察；
3. 方案 2 的正确性风险（快照恢复、双状态同步）会污染本阶段的核心变量——中断与 stale rejection；
4. 性能问题（如有）将由 T-step6 telemetry 量化（view 数、layout 次数、frame interval、内存增长），用数据决定是否实验方案 2；
5. 命令行已预留 `--page-hosting live|composited` 切换位，方案 2 作为可实验分支保留，不预先实现。

### 3.2 被否决方案

- **方案 2 直接启用**：否决。无测量证据；正确性风险干扰核心变量；与"先正确后优化"矛盾。
- **每帧重建页面 view tree**：否决（属反模式而非方案）。违反 Prompt §3.H"不在每个帧周期重建整个页面 view tree"。

## 4. 热路径约束（无论哪种方案，必须满足）

- 手势热路径**不做**同步图标解码、应用目录扫描、数据库访问；
- 不在每个帧周期重建整个页面 view tree；
- 页面 prepare / reuse / snapshot 不得显示旧内容；
- 页面数量增长时，内存与 view 数量有**上界策略**（live page radius + prewarm distance 参数化，见 PARAMETER_RATIONALE.md）；
- resize 后的几何更新不得在每帧重复触发布局风暴（resize 事件驱动的单次重新布局）。

## 5. 验证方式

- T-worker-d：UI 正确性测试（§7.3）在 live 模式下全部通过；
- T-step6：live views baseline（view 数、layout 次数、frame interval、内存增长、stale completion=0）；
- 若 baseline 未达 §8.5 初始目标 → 按 T-step6 任务包实验方案 2（A/B `--page-hosting`），保留改动前后数据；切换方案需 Main 路由 Chief 修订本 ADR。

## 6. 设计者接触声明

- 设计者（Main，T-step1）：未读取 BuhoRebuild / LaunchBetter 源码；阅读过 Launch_Copy 治理文档（审计摘要，非实现细节）。本 ADR 的优缺点与理由基于 Prompt §3.H 需求、公开 AppKit 平台知识与本项目的实验目标独立推导。

## 7. 变更记录

| 日期 | 变更 | 执行人 |
|---|---|---|
| 2026-08-28 | 创建并 ACCEPTED（方案 1 先行） | Main |
