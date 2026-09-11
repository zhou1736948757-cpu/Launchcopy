# concurrency-check-1g-wave5 — Wave 5 并发检查记录

## 决策
- 计划 Worker 数：1（T-G-P4 先行）
- 计划 Reviewer 数：0（评审在 Worker 完成后独立波）
- 串行理由：SwiftPM .build 目录共享，full build/test 必须串行（PLAN §6）；T-G-P4 写 LauncherPresentationState.swift（T-1G-A 产物）需 T-1G-A 测试回归，与任何并行 Worker 冲突
- 依赖假设：T-G-P4 依赖 T-G-P1（PASSED）+ T-G-P2（PASSED）+ T-G-P3（PASSED）+ T-1G-A（PASSED）
- 质量理由：串行避免 .build 竞争与测试污染；max_worker_concurrency=3 未超限但本波只用 1
