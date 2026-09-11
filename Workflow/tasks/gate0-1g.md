# gate0-1g — Phase 1G Gate 0 对账（Main 直接执行，非 Worker 任务）

## Objective
对账 Phase 1F 事实：fresh 测试/构建/hash、遗留任务状态、B10 生产默认路径、B11 视觉验收、Phase 1F 收尾文档。

## Expected / Allowed Write Scope
Docs/PHASE1F_*.md（新建）、Workflow/STATE.json（诚实标签）、Workflow/events.jsonl（事件）、本任务包。

## Result
Phase 1F 自动化全绿（1137/0，debug/release exit 0，hash 已记录）；物理门 PENDING（B10 实机 A/B 未回填、B11 视觉验收 PENDING）；Phase 1F 收尾四文档已补建；STATE 遗留标签已诚实修正。
