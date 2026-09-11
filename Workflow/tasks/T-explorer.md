# Task Packet: T-explorer

- **Task ID**: T-explorer
- **Role**: Explorer A (read-only analysis)
- **Step**: — (advisory, feeds into T-step1)


## Objective

对分页状态模型、中断不变量、stale completion 拒绝机制和 page count/resize/teardown 边界进行只读分析，产出设计建议供 Main 编写 ADR-001 时参考

## Dependencies

- **T-step0**（需要 provenance 骨架和访问声明建立后进行）

## Context

Prompt §12 推荐 Explorer A 负责只读分析/建议：状态模型、interruption invariants、stale completion、page count/resize/teardown 边界。Explorer A 是 advisory 角色，不写产品代码，不写 ADR 文件。分析输出供 Main 在 T-step1 中编写 ADR-001 时使用。

**Explorer A 允许读取**：
- 本 Prompt（PHASE1_PAGING_PROTOTYPE_PROMPT.md）
- Apple 官方公开文档
- 新工程中由本阶段独立生成的文件

**Explorer A 禁止读取**：
- Prompt §1.3 列出的任何路径
- Launch_Copy 三份治理文档（RISK_REDUCTION_PLAN/CONTEXT_LEDGER/SOURCE_MANIFEST）中的来源审计细节

## Scope

只读分析以下主题，产出结构化建议：

1. **状态模型语义**：idle / tracking gesture / settling to page / interrupted / cancelled 的转换条件、所有权和不变量
2. **中断不变量（Prompt §3.F 核心硬门禁）**：
   - settle 动画未结束时新手势如何立即接管
   - 接管位置如何与用户当前看到的位置连续
   - 如何防止跳回旧动画逻辑起点或目标点
   - 旧动画完成事件如何确认/丧失提交资格
   - 快速连续正反向操作如何避免双重 commit
   - resize/close/pageCount 变化时 transition 如何安全取消或重新基准化
3. **Stale completion rejection**：transition identity/context 的设计建议；旧回调如何识别自己已过期
4. **Page count / resize / teardown 边界**：
   - pageCount 在 tracking 时减少如何处理
   - pageCount 在 settling 时减少如何处理
   - resize/page-width 变化如何 rebase 当前偏移
   - teardown 如何保证无残留 display callback
5. **Reduce Motion 影响**：降级路径如何保持中断和旧回调失效机制正确

## Out of Scope

- 写产品代码
- 写 ADR 文件（Main 在 T-step1 中编写）
- 写规格文档
- 修改任何项目文件
- 做性能分析

## Expected / Allowed Write Scope

- 无（只读分析角色）。分析输出以消息/报告形式提交给 Main。

## Constraints

- 只读：不修改任何项目文件
- 不读 Prompt §1.3 列出的任何路径
- 不使用旧项目的精确参数、字段名、类结构或状态机映射作为设计依据
- 建议必须基于 Prompt §3 的需求描述和公开平台知识
- 参数建议必须标记来源类别（PRODUCT_DECISION / PLATFORM_REQUIREMENT / ACCESSIBILITY_REQUIREMENT / INDEPENDENT_EXPERIMENT / PUBLIC_DOCUMENTATION）

## Acceptance Criteria

- [ ] 状态模型语义分析覆盖全部 5 种状态及其转换条件
- [ ] 中断不变量分析覆盖 Prompt §3.F 全部 6 条硬门禁
- [ ] Stale completion rejection 机制有明确设计建议（transition identity 如何生成和比较）
- [ ] Page count / resize / teardown 边界分析覆盖 Prompt §7.1 相关测试场景
- [ ] Reduce Motion 对中断机制的影响有分析
- [ ] 分析中不引用旧项目字段名、类结构或精确参数簇
- [ ] 所有参数建议有来源类别标记

## Required Verification

- 分析输出提交给 Main 并记录在 events.jsonl
- Main 确认分析覆盖了 ADR-001 所需的全部设计决策点

## Reviewer Focus

- 分析是否引用了旧项目的内部结构或精确参数（来源污染风险）
- 中断不变量分析是否完整覆盖 Prompt §3.F
- 建议是否把实现手段包装成了产品需求（应只描述可观察结果层需求）

## Deliverables

- 结构化分析报告（消息/文档形式提交给 Main，由 Main 存档到 Workflow/results/ 或直接用于 ADR-001 编写）