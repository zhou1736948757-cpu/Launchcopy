# Task Packet: T-worker-b-thresh46（阈值 0.46/0.40）

- **Task ID**: T-worker-b-thresh46
- **Role**: Worker（PagingCore 作者）
- **来源**: T-step8 物理调参第 12 轮（全屏基准）
- **日期**: 2026-08-28

## 用户决策

"改成前进0.46，回退0.4"（全屏复测后微调）。

## 任务

1. `PagingParameters.displacementThreshold` 默认 0.48 → **0.46**（注释同步：全屏基准第 12 轮）。
2. `retreatDisplacementFactor` 默认 0.875 → **20.0/23.0**（≈0.869565；回退 = 0.46 × 20/23 = **0.40** 精确；注释同步用户决策）。
3. 测试更新：
   - 前进 0.45 → bounce / 0.46 → advance（velocityContribution=0 隔离 + 默认混合路径各一）
   - 回退 0.39 → bounce / 0.40 → retreat（同）
   - 不对称断言值更新；速度强制/边界/RM/glide/momentum 不回归
   - 全量 swift test 0 failures（180+）
4. `swift build` exit 0（0 warning）。

## Write Scope

- `Sources/PagingCore/PagingParameters.swift`
- `Tests/PagingCoreTests/`
- `Workflow/results/T-worker-b-thresh46.md`（简短）

## Forbidden

- `Package.swift`、`Docs/`、`PROVENANCE/`、`Workflow/`（结果文件除外）
- `Sources/PagingUI/`、`Sources/PagingTelemetry/`、`Sources/PagingPrototypeApp/`
- §1.3 禁止路径与治理文档

## Verification

- `swift test` 全量 0 failures；`swift build` exit 0（0 warning）
- 心跳 role Worker, task-id T-worker-b-thresh46, ACTIVE

## Status

- 2026-08-28：Main 记录决策；Worker 实施中。
