# concurrency-check-1g-wave1 — Wave 1 并发检查记录

## 决策
- 计划 Worker 数：2（T-1G-A、T-G-P0 剩余部分）
- 计划 Reviewer 数：0（本波无评审，评审在 Worker 完成后独立波）
- 隔离边界：T-1G-A 写 Sources/PagingPrototypeApp 新文件 + Tests/PagingUITests + Docs/ADR-011/012；T-G-P0 写 Docs/ADR-013 + PROVENANCE；写集不相交
- 依赖假设：T-1G-A 无依赖；T-G-P0 无依赖（FOUR_FINGER_REFERENCE_AUDIT.md 已由 Main 完成，作为只读输入物化）
- 测试隔离：T-1G-A 用 swift test --filter 相关套件；T-G-P0 无测试
- 质量理由：两任务写集互斥、无共享可变状态、无顺序依赖，并发不降低质量；max_worker_concurrency=3 未超限
