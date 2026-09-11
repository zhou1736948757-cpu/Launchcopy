# Decision: max_worker_concurrency 2 → 3

- **Date**: 2026-08-28
- **Requested by**: 用户（直接授权，覆盖"活动进行中不改并发"的默认约束）
- **Scope**: 仅 `Workflow/config.json` 的 `max_worker_concurrency`；模型与思考深度不变
- **Decision**: `max_worker_concurrency = 3`

## Rationale

- Phase 1A 的三个实现 worker 写入范围互斥（Worker B: `Sources/PagingCore` + `Tests/PagingCoreTests`；Worker C: `Sources/PagingTelemetry` + `Tests/PagingTelemetryTests`；Worker D: `Sources/PagingUI` + `Sources/PagingPrototypeApp` + `Tests/PagingUITests`），具备 3 路并行的隔离基础。
- `Package.swift`、Docs、PROVENANCE 骨架由 Main 统一整合，任何 Worker 不得并行修改。
- 3 是硬上限，不是默认值：每个 Worker/Reviewer wave 仍按质量门做并发检查并记录计划数量、隔离边界与理由。
- 本变更不影响 Chief 规划中的语义依赖 DAG（Chief 只规划语义依赖，不规划运行时并发）。

## Effects

- 后续 worker wave 可在满足质量门时最多同时运行 3 个 Worker。
- Reviewer 并发不受此值限制（由 Main 按证据独立性决定）。
