# PROVENANCE / ACCESS_DECLARATION.md

- **日期**：2026-08-28
- **阶段**：Phase 1A（PagingPrototype）
- **性质**：参与者访问声明。如实记录，禁止统一代签，禁止倒填"未接触"。

## 1. 声明机制

- 每位参与者在自己的 Worker Result（`Workflow/results/<task-id>.md`）中**亲笔确认**访问声明；Main 收到后将确认结果登记到本文件对应行。
- 本文件的"登记"表示参与者本人已在其产出文件中声明；Main 仅转登记，**不代签**。
- 任何人不得代替他人声明 `NO_PRIOR_EXPOSURE`。

## 2. 参与者与接触层级（2026-08-28 最终登记）

| 参与者 | 角色 | 模型/会话 | 声明 | 接触层级（如适用） | 状态 |
|---|---|---|---|---|---|
| Main（当前主对话） | 主控/编排 | current-main-conversation | **PRIOR_EXPOSURE** | 2026-08-28 阅读 Launch_Copy 三份治理文档（RISK_REDUCTION_PLAN / CONTEXT_LEDGER / SOURCE_MANIFEST）：含审计摘要、文件清单与 hash；**未**读取原始反编译 evidence 正文、BuhoRebuild 源码、LaunchBetter 源码 | 已登记（本人，T-step0 结果） |
| Chief | 持久规划 | subagent b2c93600（ollama/glm-5.2） | **PRIOR_EXPOSURE** | 2026-08-28 规划期间阅读同一三份治理文档（其任务包显式授权读取）；未读取其他受限材料 | 已登记（依据其规划任务交付摘要自述；无独立声明文件，如实注明） |
| Explorer A | 只读分析 | subagent b874a2f3（ollama/glm-5.2） | **NO_PRIOR_EXPOSURE** | — | 已登记（亲笔于 T-explorer 分析报告尾部：未读取禁止路径/治理文档） |
| Worker B | 实现（PagingCore） | subagent f0484f47（ollama/deepseek-v4-flash:0731） | **NO_PRIOR_EXPOSURE** | — | 已登记（亲笔于 T-worker-b 结果） |
| Worker C | 实现（Telemetry） | subagent 7c2b752a（ollama/deepseek-v4-flash:0731） | **NO_PRIOR_EXPOSURE** | — | 已登记（亲笔于 T-worker-c 结果） |
| Worker D | 实现（UI/App/Step6） | subagent f0484f47（同 Worker B，顺序承担；见下） | **NO_PRIOR_EXPOSURE** | — | 已登记（亲笔于 T-worker-d 与 T-step6 结果） |
| Reviewer E | 独立审查 | subagent 083dadbd（ollama/glm-5.3-flash:cloud） | **NO_PRIOR_EXPOSURE** | — | 已登记（亲笔于 T-reviewer-r1 报告） |

## 3. Fresh-context 机制说明（如实记录）

- 编排载体为 AgentTeams：实现 worker 是独立 fresh member，上下文只含系统提示、团队元信息与自己的任务消息；**不继承**主对话、Chief 规划上下文或任何历史会话。
- **运行时串行同人说明（Reviewer Q-1，2026-08-28）**：Worker B 与 Worker D 由同一 fresh member（f0484f47）顺序承担。该成员自加入起零接触受限材料、写入范围互斥（B：PagingCore；D：PagingUI/App），fresh-context 纪律未受影响；PLAN 角色表仍按职责行记录。
- 任务包中出现的禁止路径仅为"不得读取"清单文本（Prompt §1.3），不是受限材料内容。
- 主对话与 Chief 读过治理文档（含审计摘要），因此**不得**向实现 worker 转发治理文档或任何来源审计细节；实现 worker 只接收：本 Prompt、Apple 公开文档、新工程自身文件。
- 本流程是自 2026-08-28 起建立的**前瞻性来源隔离**，不主张历史上从未接触受限材料。

## 4. 更新记录

| 日期 | 更新 | 执行人 |
|---|---|---|
| 2026-08-28 | 创建本文件，登记 Main/Chief/Worker/Reviewer 声明（部分待确认） | Main |
| 2026-08-28 | 最终登记全部参与者亲笔声明（Explorer/Worker B/C/D/Reviewer）；补 Q-1 串行同人说明（Reviewer 审查后） | Main |

## 5. Phase 1B 参与者登记（2026-08-28）

| 参与者 | 角色 | 团队 member | 声明 | 状态 |
|---|---|---|---|---|
| Explorer A（Phase 1B） | Wave 0 只读核验 | d9117908（deepseek-v4-flash:0731） | **NO_PRIOR_EXPOSURE** | 已登记（t1 输出亲笔） |
| Explorer B（Phase 1B） | Wave 0 只读 seam 分析 | c50e6e98（同上） | **NO_PRIOR_EXPOSURE** | 已登记（t2 输出亲笔） |
| Explorer C（Phase 1B） | Wave 0 只读边界分析 | 1a7d3bb6（同上） | **NO_PRIOR_EXPOSURE** | 已登记（t3 输出亲笔） |
| Chief（Phase 1B） | 接口冻结规划 | 6edaf045（同上） | **NO_PRIOR_EXPOSURE** | 已登记（wave1-interfaces.md 头部亲笔） |
| Worker CatalogCore | Wave 1 实现 | 2f2183b8 | **NO_PRIOR_EXPOSURE** | 已登记（T-worker-b-catalogcore.md） |
| Worker MacCatalog | Wave 1 实现 | af1b2869 | **NO_PRIOR_EXPOSURE** | 已登记（T-worker-b-maccatalog.md） |
| Worker Icon | Wave 1 实现 | cfb39756 | **NO_PRIOR_EXPOSURE** | 已登记（T-worker-b-icon.md） |
| Worker PagingUI seam | Wave 2 实现 | eb0247ee | **NO_PRIOR_EXPOSURE** | 已登记（T-worker-b-pagingui-seam.md） |
| Worker AppGridUI | Wave 2 实现 | d7940ea2 | **NO_PRIOR_EXPOSURE** | 已登记（T-worker-b-appgridui.md） |
| Worker Telemetry | Wave 2 实现 | 06e31a6d | **NO_PRIOR_EXPOSURE** | 已登记（T-worker-b-telemetry.md） |
| Worker Integration | Wave 3 实现 | 8075a802 | **NO_PRIOR_EXPOSURE** | 已登记（T-worker-b-integration.md / -launchsmoke.md） |
| Reviewer（Phase 1B） | 独立审查 t12/t13/t14 | 07905540 | **NO_PRIOR_EXPOSURE** | 已登记（t12–t14 输出亲笔） |

- Phase 1B 全部实现/审查参与者 = NO_PRIOR_EXPOSURE（fresh context，只接收 Prompt §2.1 允许材料 + 自身任务消息）。
- 禁止路径清单仅作为"不得读取"文本出现在任务包；未作为内容转发。

## 6. 更新记录（Phase 1B）

| 日期 | 更新 | 执行人 |
|---|---|---|
| 2026-08-28 | Phase 1B 全部参与者登记（Wave 0–3 + Reviewer）；Reviewer §14.C MINOR-3 回填 | Main |
