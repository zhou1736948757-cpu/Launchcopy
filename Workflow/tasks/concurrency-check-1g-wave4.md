# concurrency-check-1g-wave4 — Wave 4 并发检查记录

## 决策
- 计划 Worker 数：1（T-G-P3 先行）
- 计划 Reviewer 数：0（评审在 Worker 完成后独立波）
- 串行理由：SwiftPM .build 目录共享，full build/test 必须串行（PLAN §6）；T-G-P3 与 T-G-P2 写集不同文件但共享 .build
- 依赖假设：T-G-P3 依赖 T-G-P0（PASSED）；T-G-P2 已 PASSED（38/0，评审 0 BLOCKER/0 MAJOR）不阻塞 T-G-P3
- 质量理由：串行避免 .build 竞争与测试污染；max_worker_concurrency=3 未超限但本波只用 1
