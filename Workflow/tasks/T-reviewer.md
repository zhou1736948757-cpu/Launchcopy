# Task Packet: T-reviewer

- **Task ID**: T-reviewer
- **Role**: Reviewer E (read-only)
- **Step**: — (Prompt §12 Reviewer E)


## Objective

独立只读审查全部产出——来源纪律、参数来源文档、自动化结果诚实性、物理门诚实标记、命名中立性、结构相似性

## Dependencies

- **T-step7**（需要清洁构建和自动化验证完成后审查）

## Context

Prompt §12 推荐 Reviewer E 只读审查：
- 检查是否越界读旧材料
- 检查结构和参数是否有来源说明
- 检查自动化结果是否被夸大
- 检查物理门是否仍诚实标记

Reviewer E 是独立审查角色，不编辑实现文件，无架构决策权，不直接消息 Chief。

## Scope

### 来源纪律审查
- 检查 PROVENANCE/ACCESS_DECLARATION.md：每位参与者是否有访问声明，是否如实
- 检查 PROVENANCE/CONTAMINATION_LOG.md：是否有污染记录，如有则受影响组件是否标记 BLOCKED_FOR_REVIEW
- 检查是否有越界读取旧材料的迹象（代码中是否含旧项目字段名、地址、精确参数簇、注释模式）
- 检查来源扫描结果是否覆盖全部 8 类内容

### 参数来源文档审查
- 检查 Docs/PARAMETER_RATIONALE.md：每个参数是否有来源类别
- 检查来源类别是否全部合规（无 REVERSE_ENGINEERING_COPY / OLD_SOURCE_TRANSLATION / UNKNOWN_ORIGIN）
- 检查无法解释的参数是否标 TUNING_REQUIRED
- 检查参数是否有选择理由和验证结果

### 自动化结果诚实性审查
- 检查 Docs/VALIDATION_RESULTS.md：状态是否分开记录
- 检查是否有未执行的 gate 被标为 PASS
- 检查是否有自动化结果被夸大为物理门通过
- 检查 `exit_code == 0` 且 `executed_tests == 0` 是否被不当标为 PASS

### 物理门诚实标记审查
- 检查 MANUAL_PHYSICAL_GATE_60HZ：是否为 NOT_RUN 或 BLOCKED（不应为 PASS，因为物理门在 T-step8 等待用户）
- 检查 MANUAL_PHYSICAL_GATE_120HZ：是否为 NOT_RUN 或 BLOCKED
- 检查是否有用 60Hz 结果推断 120Hz 的迹象
- 检查是否有用 synthetic probe 代替真实触控板的迹象

### 命名中立性审查
- 检查命名是否使用中性项目语言（PagingState/GestureSession/TransitionContext 等）
- 检查是否有 Buho 身份、反编译地址或"原类型一一对应"含义的命名
- 检查是否有旧 bundle identifier、旧日志 subsystem、旧临时文件名

### 结构相似性审查
- 检查状态机结构是否与旧项目形成一一对应（需独立理由或重写）
- 检查常量簇是否与旧项目精确匹配
- 检查测试组织是否照搬旧项目

### ADR 完整性审查
- 检查 ADR-001 是否回答 Prompt §3.G 全部 7 个问题
- 检查 ADR-002 是否比较了两个方案并有被否决方案
- 检查 ADR 是否如实记录设计者接触声明

## Out of Scope

- 编辑实现文件
- 修改任何项目文件
- 做架构决策
- 执行构建或测试
- 直接消息 Chief
- 物理触控板验收

## Expected / Allowed Write Scope

- `Workflow/reviews/T-reviewer-r1.md`（审查报告）
- `Workflow/review-bundles/T-reviewer/`（审查 bundle，如需要）


## Forbidden Write Scope

**禁止写入**：
- 任何 Sources/ 或 Tests/ 文件
- Package.swift
- Docs/ 或 PROVENANCE/
- PLAN.md 或 MAIN_BRIEF.md

## Constraints

- 只读审查：不修改实现文件
- 无架构决策权：审查建议不是修复授权
- 审查报告须包含 Verdict（PASS / FAIL / BLOCKED）、Findings、Evidence、Likely Root Cause、Recommended Solution、Affected Scope、Regression Risks、Confidence
- Findings 使用 BLOCKER / MAJOR / MINOR / QUESTION 分级
- 不直接消息 Chief（通过 Main 路由）

## Acceptance Criteria

- [ ] 来源纪律审查完成（访问声明、污染日志、越界迹象、扫描覆盖）
- [ ] 参数来源文档审查完成（来源类别合规、TUNING_REQUIRED 标记）
- [ ] 自动化结果诚实性审查完成（状态分离、无虚标 PASS）
- [ ] 物理门诚实标记审查完成（60Hz/120Hz 未虚标）
- [ ] 命名中立性审查完成（无 Buho 身份/地址/一一对应含义）
- [ ] 结构相似性审查完成（无未解释的一一映射）
- [ ] ADR 完整性审查完成（§3.G 7 个问题、方案比较、接触声明）
- [ ] 审查报告含 Verdict / Findings / Evidence / Root Cause / Recommended Solution / Affected Scope / Regression Risks / Confidence

## Required Verification

- 审查报告提交到 Workflow/reviews/T-reviewer-r1.md
- Verdict 明确（PASS / FAIL / BLOCKED）
- 如有 BLOCKER 级 Finding，Verdict 不得为 PASS

## Reviewer Focus

（此任务本身就是 Reviewer 角色，不适用 Reviewer Focus 字段。Main 根据审查结果决定后续路由。）

## Deliverables

- Workflow/reviews/T-reviewer-r1.md（审查报告）