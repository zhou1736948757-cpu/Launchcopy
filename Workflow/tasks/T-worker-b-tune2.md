# Task Packet: T-worker-b-tune2（momentum-decay 范围扩展）

- **Task ID**: T-worker-b-tune2
- **Role**: Worker（PagingPrototypeApp 作者）
- **来源**: T-step8 物理调参第 2 轮：用户要滑行 ≈0.1s
- **日期**: 2026-08-28

## 用户反馈

"滑行时长还是太长，你把滑行时长改到 0.1"——目标：滑行时长 ≈ 0.1 秒。

## 背景（Main 已计算）

- momentumDecay 是**每帧衰减系数**（非秒数）。0.85 时典型甩速 1000px/s → 约 0.33s 滑行（仍太长）。
- 要 ≈0.1s（6 帧 @60Hz 内衰减到停止阈值 40px/s = velocityThreshold×5%）：decay ≈ 0.55。
- 当前 CLI 合法范围 0.80–0.99 容纳不了 → 扩展为 **0.50–0.99**。

## 任务

1. `Sources/PagingPrototypeApp/AppArguments.swift`：`--momentum-decay` 合法范围 0.80–0.99 → **0.50–0.99**；帮助文本同步。
2. 测试更新：边界 0.80 → 0.50/0.99；越界用例 0.49（原 0.79 用例保留仍越界）；其余解析/接线测试不变。
3. `swift build` exit 0（0 warning）；`swift test` 全量 0 failures。
4. 不改 PagingCore 默认值；不改 glide 机制。

## Write Scope

- `Sources/PagingPrototypeApp/AppArguments.swift`
- 相关测试文件
- `Workflow/results/T-worker-b-tune2.md`（简短结果即可）

## Forbidden

- `Package.swift`、`Docs/`、`PROVENANCE/`、`Workflow/`（结果文件除外）、`Sources/PagingCore/`、`Sources/PagingUI/`、`Sources/PagingTelemetry/`
- §1.3 禁止路径与治理文档

## Verification

- `swift test` 全量 0 failures
- `swift run -c release PagingPrototypeApp --momentum-decay 0.55` → parse OK
- `swift run -c release PagingPrototypeApp --momentum-decay 0.49` → exit 2

## Status

- 2026-08-28：Main 记录决策（≈0.1s → 0.55）；Worker 执行中。
