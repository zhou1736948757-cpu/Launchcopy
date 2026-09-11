# Task Packet: T-worker-b-retreat（回退方向宽容化）

- **Task ID**: T-worker-b-retreat
- **Role**: Worker（PagingCore 作者）
- **来源**: T-step8 物理调参第 9 轮：用户回退方向偶发翻不过去（生理不对称）
- **日期**: 2026-08-28

## 背景

- 用户反馈：从第 2 页回第 1 页（手指右滑/回退）偶发"划了没走到"；用户自察为**生理不对称**（往回滑行程天然短）。数据支持：phys-auto-12 回退成功行程 0.524–0.658（贴 0.5 门槛），前进轻松 0.7+。
- 判定逻辑（PageTargetPolicy.decide）：位移阈值 `displacementThreshold`（0.5 页）或速度强制 `velocityThreshold`（800px/s）；方向由速度（≥阈值）或位移符号决定。

## 任务

1. **PagingParameters 加 `retreatDisplacementFactor: Double = 0.9`**（PRODUCT_DECISION；物理调参中；合法范围 0.7–1.0，写注释"回退方向位移阈值系数；0.9 = 0.45 页"）。参数表行回填由 Main 完成。
2. **PageTargetPolicy.decide**：仅当 `direction == -1`（回退）时，位移判定阈值 = `displacementThreshold × retreatDisplacementFactor`（位移条件与位移+速度混合条件都要用）；前进（direction == +1）保持原阈值。**速度强制路径不变**（absVelocity >= velocityThreshold 仍翻页）。
   - 注意 direction 计算不受影响（direction 由速度阈值/位移符号决定，与位移阈值无循环依赖）。
   - 边界 clamp 逻辑不变。
3. **测试**：
   - 不对称断言：回退 0.46 行程（低速度）→ retreat；前进 0.46 行程（低速度）→ bounce
   - 回退 0.44 → bounce（阈值边界）；前进 0.5 → advance 不变
   - 速度强制路径（回退 700px/s 位移 0.3 → retreat？不——700 < 800 不强制，走混合；写清断言）
   - 边界（首/末页）、RM、既有判定测试全部不回归
   - 全量 swift test 0 failures（176+）
4. `swift build` exit 0（0 warning）。本波不加 CLI（factor 固定默认 0.9；用户确认后如需微调再 CLI 化）。

## Write Scope

- `Sources/PagingCore/PagingParameters.swift`、`Sources/PagingCore/PageTargetPolicy.swift`
- `Tests/PagingCoreTests/`
- `Workflow/results/T-worker-b-retreat.md`（简短）

## Forbidden

- `Package.swift`、`Docs/`、`PROVENANCE/`、`Workflow/`（结果文件除外）
- `Sources/PagingUI/`、`Sources/PagingTelemetry/`、`Sources/PagingPrototypeApp/`
- §1.3 禁止路径与治理文档

## Verification

- `swift test` 全量 0 failures；`swift build` exit 0（0 warning）
- 心跳 role Worker, task-id T-worker-b-retreat, ACTIVE

## Status

- 2026-08-28：Main 记录决策（0.45 试值）；Worker 实施中。
