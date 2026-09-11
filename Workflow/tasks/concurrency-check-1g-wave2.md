# concurrency-check-1g-wave2 — Wave 2 并发检查记录

## 决策
- 计划 Worker 数：1（T-G-P1 先行）
- 计划 Reviewer 数：0（评审在 Worker 完成后独立波）
- 串行理由：T-G-P2 依赖 P0/P1、T-G-P3 依赖 P0（已满足）但 SwiftPM .build 目录共享，full build/test 必须串行（PLAN §6）；P1 是四指轨核心，先落地
- 依赖假设：T-G-P1 依赖 T-G-P0（PASSED，审计+ADR-013+风险清单已物化）
- 质量理由：串行避免 .build 竞争与测试污染；max_worker_concurrency=3 未超限但本波只用 1
