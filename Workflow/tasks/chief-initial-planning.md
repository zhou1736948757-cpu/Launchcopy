# Task Packet: chief-initial-planning

- **Task ID**: chief-initial-planning
- **Role**: Chief
- **Status**: PENDING


## Inputs（只读）

- `/Users/mac/Projects/Launch_Copy/PHASE1_PAGING_PROTOTYPE_PROMPT.md`（主输入，须完整阅读）
- `/Users/mac/Projects/Launch_Copy/RISK_REDUCTION_PLAN.md`（治理）
- `/Users/mac/Projects/Launch_Copy/CONTEXT_LEDGER.md`（治理）
- `/Users/mac/Projects/Launch_Copy/SOURCE_MANIFEST.md`（治理）
- `/Users/mac/Projects/Launch_Copy/PagingPrototype/`（新工程根，工作流骨架已初始化）

## Deliverables（写入项目根，绝对路径）

1. `Workflow/PLAN.md`：Objective / User Requirements / Non-Goals / Repository Understanding / Proposed Approach / Key Design Decisions / Critical Invariants / Global Acceptance Criteria / Task Graph（**仅语义依赖**，不写并发）/ Risks / Main Flexibility / Chief-Owned Decisions
2. `Workflow/MAIN_BRIEF.md`：Current Mission / Execution Starting Point / Runtime Authority / Do Not Decide Without Chief / Failure Policy / Invariants / Escalation Guidance / Artifact Map（短于 PLAN.md）
3. `Workflow/tasks/<task-id>.md`：初始任务包（每任务一个文件），覆盖 Prompt Step 0–8 与 §12 分工（Explorer A / Worker B / C / D / Reviewer E），含 Objective、Acceptance Criteria、Writable Scope、Dependencies、Reviewer Focus
4. 高价值 Memory 候选（写入 MEMORY.md 或单独列出供 Main 把关）

## Constraints

- 不读禁止来源（Prompt §1.3 列表）；不复制旧代码；不计划运行时并发。
- 实现 worker 必须 fresh context（不继承含逆向材料的旧会话）。
- 参数来源类别、物理门诚实标记、停止条件（§14）须体现在任务包验收标准中。
- Chief 不实现、不写产品代码；只规划与决策。
- 完成前后各发一次 watchdog heartbeat（role Chief）。

## Dependencies

无（初始规划任务；依赖 setup 完成）

## Scope

完整阅读 Prompt 与治理文档；产出 PLAN.md / MAIN_BRIEF.md / 任务包 / Memory 候选。

## Required Verification

交付物清单核对；禁止来源读取检查；心跳记录。

## Acceptance Criteria

- [ ] PLAN.md 全章节实质内容（非 Pending 占位）
- [ ] MAIN_BRIEF.md 完成
- [ ] 初始任务包齐全且语义依赖图自洽
- [ ] 无禁止来源读取记录
## Objective

为 Phase 1A 分页原型 Prompt 完成初始全局规划，产出可见规划工件。
