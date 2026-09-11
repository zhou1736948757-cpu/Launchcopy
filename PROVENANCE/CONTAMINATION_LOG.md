# PROVENANCE / CONTAMINATION_LOG.md

- **日期**：2026-08-28
- **用途**：真实记录任何对 Prompt §1.3 禁止来源的意外接触。**不隐藏、不删除、不倒填。**
- **另记录**：非禁止来源、但具 license 审计意义的治理层授权访问（如 route-B 冻结副本 BuhoRebuild 的审阅）——同上原则如实登记，供 license 审查追溯。

## 记录格式

```text
时间：<ISO 时间>
接触者：<参与者/会话>
接触对象：<路径/材料>
影响范围：<组件>
处理：<立即停止该组件实现；标记 BLOCKED_FOR_REVIEW；等待主控决定重写/隔离/更换实施者>
```

## 事件记录

| 时间 | 接触者 | 接触对象 | 影响组件 | 处理 | 状态 |
|---|---|---|---|---|---|
| 2026-08-31（BUG6-FIX-PROMPT 编制期） | Ops（用户，方案编制侧） | BuhoRebuild 工程（RESEARCH_PROTOTYPE_ONLY 冻结副本；**非** §1.3 禁止来源，route-B 治理层授权审阅） | BUG6 修复方案（缺陷 3+4 落点判定重算 / 缺陷 2 点击通路简化）——仅行为层结论 | 已授权审阅；行为层启发提炼进 BUG6-FIX-PROMPT §2.3/§4.2（图标即实体、单一点击通路），未含其代码结构；Worker clean-room 链不受影响（Worker 不读该来源）；license 审查时可引用本记录 | 已记录 |
| 2026-09-03（BUG10 点击投递诊断胶着期） | Ops（用户）命令 + Main 执行派发 | BuhoReverseNotes + LaunchBetter（**均为 §1.3 禁止来源**；用户明确命令「派多个worker去详细读一下…然后让chief判断下」，因主界面点击打不开问题长期未解「卡太久了」） | BUG10 回归诊断（触摸类事件路由缺失候选的对照取证；Worker 只读产出结构化摘要 → Chief 基于摘要判断，不直接读源） | **治理变更：用户（主控）明确授权本次诊断性审阅**。Worker 本次任务 AccessDeclaration=PRIOR_EXPOSURE；诊断结论与实现方案仍须经既有 Worker→Reviewer 门禁；若据此形成修复方案，该方案来源标记为本次授权审阅成果（影响原 clean-room 声明范围，license 审查可追溯本记录与全部 Worker 结果文件） | 已记录 · 主控授权 |
| 2026-09-02（OBS 审查期，外部审查方经用户转达） | OBS（外部审查方） | BuhoReverseNotes（**§1.3 禁止来源**） | 缺陷 B 拖拽代理承载方案（B2「独立无边框窗口承载拖拽代理」） | **意外接触**。B2 方案直接源自该逆向笔记 dragWindow 结构（非 AppKit 通用模式，标注 PUBLIC_DOCUMENTATION 不准确）；缺陷 C（insertionIndex 行划分坐标方向）与缺陷 A（overlay 残留取证）两根因与此来源无关。下游 Worker 禁读该来源；**B2 曾标记 BLOCKED_FOR_REVIEW，2026-09-02 主控（用户）明确裁决「可以使用b2方案」→ 解冻可用**，license 审查可追溯本记录 | 已记录 · 主控裁决 B2 可用 |

## 更新记录

| 日期 | 更新 | 执行人 |
|---|---|---|
| 2026-08-28 | 创建空骨架 | Main |
| 2026-08-31 | 登记 Ops 对 BuhoRebuild（route-B 冻结副本）的授权审阅——非 §1.3 禁止来源，license 审计追溯用 | Main |
| 2026-09-02 | 登记 OBS 对 BuhoReverseNotes（**§1.3 禁止来源**）的意外接触；B2 拖拽代理方案曾标记 BLOCKED_FOR_REVIEW，同日主控裁决「可以使用b2方案」解冻 | Main |
| 2026-09-03 | 登记主控（用户）命令授权 Worker 审阅 BuhoReverseNotes + LaunchBetter（**§1.3 禁止来源**）用于 BUG10 点击投递诊断；Worker AccessDeclaration=PRIOR_EXPOSURE，Chief 基于摘要判断 | Main |
