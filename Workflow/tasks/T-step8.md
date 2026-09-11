# Task Packet: T-step8

- **Task ID**: T-step8
- **Role**: Main
- **Step**: 8 (Prompt §6 Step 8)


## Objective

生成明确的物理验收手工步骤和环境证据模板，等待用户在真实 GUI 和触控板上执行或授权代理协助执行。**不可自行把物理门标为 PASS。**

## Dependencies

- **T-step7**（清洁构建和自动化验证完成）
- **T-reviewer**（来源和验收审查完成，Verdict 为 PASS 或 BLOCKER 已处理）

## Context

Prompt §6 Step 8 要求自动化通过后，生成明确的手工步骤，等待用户在真实 GUI 和触控板上执行。这是 Phase 1A 的最终 Gate——不能自行标 PASS。

## Scope

### 物理验收手工步骤生成
生成覆盖 Prompt §8 全部矩阵的明确步骤文档：

1. **环境证据模板**（Prompt §8.1）：
   - Mac 型号
   - macOS 版本
   - 显示器
   - 分辨率和缩放
   - 实际刷新率
   - 触控板类型
   - Reduce Motion 状态
   - Debug 或 Release
   - commit/hash
   - 是否接电
   - 是否有明显后台负载

2. **页面矩阵**（Prompt §8.2）：
   - 1 页、2 页、5 页、10 页、20 页压力模式

3. **手势矩阵**（Prompt §8.3）：
   - 慢速拖动后回弹
   - 慢速拖动后翻页
   - 快速甩动
   - 小幅快速输入
   - settle 中同向接管
   - settle 中反向接管
   - 连续快速来回
   - 首页向外拉
   - 末页向外拉
   - 滑动时 resize
   - 滑动时关闭窗口
   - Reduce Motion

4. **正确性硬门清单**（Prompt §8.4）：
   - 跳回旧位置 → FAIL
   - 一次手势 commit 多次 → FAIL
   - 旧 completion 改写新页 → FAIL
   - 空白/重复/错页 → FAIL
   - 越界 → FAIL
   - resize 后错位 → FAIL
   - 关闭后仍有 callback → FAIL
   - 崩溃 → FAIL
   - telemetry 无法对应 gesture 和 transition → FAIL
   - 通过删除异常 run 美化结论 → FAIL

5. **初始性能目标**（Prompt §8.5）：
   - 60Hz：不出现无法解释的 >50ms 主线程 hitch；frame miss ≤1%；中断时无可见跳变；主观三项中位数 ≥4/5
   - 120Hz：只有在能证明实际 120Hz 时才执行；不使用 60Hz 推断；不使用 synthetic probe；frame miss ≤2%；不出现 >33ms hitch；主观三项中位数 ≥4/5
   - 无 120Hz 设备时：`MANUAL_PHYSICAL_GATE_120HZ = BLOCKED`

6. **主观评分模板**（Prompt §8.6）：
   - 跟手性：1–5
   - 中断连续性：1–5
   - settle 自然度：1–5
   - 边界反馈：1–5
   - 总体丝滑度：1–5
   - 备注：自由文本
   - 保留异常和低分 run

### VALIDATION_RESULTS.md 最终更新
- 更新全部 8 项 gate 状态
- MANUAL_PHYSICAL_GATE_60HZ = NOT_RUN（等待用户执行）
- MANUAL_PHYSICAL_GATE_120HZ = NOT_RUN 或 BLOCKED（视环境）
- 其他 gate 按 T-step7 和 T-reviewer 结果更新

### 最终汇报准备（Prompt §16 格式）
准备最终汇报模板：
- A. 完成内容
- B. 验证结果表
- C. 诚实边界
- D. 是否进入 Phase 1B（RECOMMEND_PROCEED / RECOMMEND_TUNE / RECOMMEND_REWORK / BLOCKED）

## Out of Scope

- 执行物理验收（等待用户）
- 自行标物理门为 PASS
- 用自动化结果替代物理门
- 用 60Hz 结果推断 120Hz

## Expected / Allowed Write Scope

- `Docs/VALIDATION_RESULTS.md`（最终更新）
- `Docs/VALIDATION_PLAN.md`（补充手工步骤，如需）
- `Docs/IMPLEMENTATION_LOG.md`（Step 8 记录）

## Constraints

- **不可自行把物理门标为 PASS**
- 120Hz 只有在能证明实际刷新率时才执行和标记
- 无 120Hz 设备时标 BLOCKED，不标 NOT_RUN 后被误读为"可能通过"
- 保留异常和低分 run，不只保存平均值
- 最终汇报格式须符合 Prompt §16
- Phase 1B 推荐须有证据，不得只写"感觉很丝滑"

## Acceptance Criteria

- [ ] 物理验收手工步骤文档已生成，覆盖 §8.1–8.6 全部矩阵
- [ ] 环境证据模板完整（11 项环境信息）
- [ ] 页面矩阵覆盖 5 种预设
- [ ] 手势矩阵覆盖 12 种手势
- [ ] 正确性硬门清单覆盖 10 条 FAIL 条件
- [ ] 性能目标文档包含 60Hz 和 120Hz 目标，120Hz 无设备时标 BLOCKED
- [ ] 主观评分模板包含 5 项评分 + 备注
- [ ] VALIDATION_RESULTS.md 更新：MANUAL_PHYSICAL_GATE_60HZ = NOT_RUN，MANUAL_PHYSICAL_GATE_120HZ = NOT_RUN 或 BLOCKED
- [ ] 最终汇报模板已准备（§16 四部分）
- [ ] 未自行标物理门为 PASS

## Required Verification

- 手工步骤文档可被用户直接执行（步骤明确、可操作）
- VALIDATION_RESULTS.md 状态诚实（物理门为 NOT_RUN 或 BLOCKED，非 PASS）
- 最终汇报模板符合 §16 格式

## Reviewer Focus

- 物理门是否被自行标为 PASS（应为 NOT_RUN 或 BLOCKED）
- 120Hz 是否被不当推断或用 synthetic probe
- 手工步骤是否完整覆盖 §8 矩阵
- VALIDATION_RESULTS.md 状态是否诚实
- 最终汇报是否包含诚实边界

## Deliverables

- Docs/VALIDATION_RESULTS.md（最终状态）
- Docs/VALIDATION_PLAN.md（手工步骤补充）
- Docs/IMPLEMENTATION_LOG.md（Step 8 记录）
- 最终汇报（Prompt §16 格式，提交给用户）