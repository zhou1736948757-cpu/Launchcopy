# Task Packet: T-worker-b-glide（momentum 滑行 1 帧截断）

- **Task ID**: T-worker-b-glide
- **Role**: Worker（PagingCore + PagingPrototypeApp 作者）
- **来源**: T-step8 物理调参第 3 轮：用户要滑行 ≈1 帧
- **日期**: 2026-08-28

## 用户反馈（原话）

"那这样吧，你把这个滑时间就改成一帧，行不？"——目标：甩动后惯性滑行最多 **1 帧（≈16.7ms @60Hz）**。

## 关键背景（Main 分析；物理调参第 3 轮）

- 真实触控板松手后系统仍发送大量 momentum 事件流（phys-auto-02：433 个 momentum 事件 ≈ 每次手势 ~33 个 ≈ 0.5s+）——**Core 跟随整个系统惯性流**，这是"滑行太长"的主要来源。
- 前两轮调 `momentumDecay`（0.95→0.85→0.55）只影响系统流结束后的 Core glide 段；系统流阶段不受 decay 控制 → 用户仍觉太长。**正确修复 = 截断系统 momentum 流**。
- Core 已有先例：Reduce Motion 路径（D8）momentum 降级 = 不做惯性滑行、直接决策——本任务把该机制**参数化**，正常模式可配置。
- 参数表 +1：`momentumGlideFrames`（来源类别 PRODUCT_DECISION；物理调参中）。

## 任务

1. **PagingParameters 加 `momentumGlideFrames: Int?`**（nil = 跟随系统流=现行为；0 = 直接决策（=RM 降级路径）；N = 最多 N 帧后决策）。RM（reduceMotion）强制 0，不变。
   - 注意：这是 PagingCore 范围改动（Worker 同人拥有 PagingCore 与 App，直接实施；无需报告 Main 之外的任何人）。
2. **Core momentum 截断**：momentumBegan 后按 momentumGlideFrames 限制系统流跟随时长（N=1：约 1 帧/≤2 个 momentumChanged 事件后进入释放决策 → settle；用事件计数或时间戳皆可，选确定性强且可测的，写明理由）。到达截断点时用当前（释放/惯性）速度做翻页决策（回弹/翻页/吸住），**不得跳变**（决策路径复用现有 momentumEnded 决策逻辑）。
   - 截断后系统后续 momentum 事件按 D3/D5 防御拒绝（stale/忽略），不得双重 commit。
3. **CLI `--momentum-glide-frames <0–10>`**（可选；缺省 nil=现行为）：AppArguments 解析 + 越界 exit 2 + 帮助文本；接线覆盖 PagingParameters.momentumGlideFrames。
4. **测试**：
   - Core：momentumGlideFrames=1 → 系统流第 2 个事件后决策 settle（事件流仍长但被截断，commit 1 次、无双重 commit）；=0 → 直接决策；=nil → 现行为（原测试不变）；RM 强制 0。
   - App：解析 0/1/10/越界 11/abc exit 2/缺省 nil；接线覆盖生效。
   - 全量 `swift test` 0 failures（156+）。
5. **不改默认行为**（nil）——试值确认后固化。

## Write Scope

- `Sources/PagingCore/`（PagingParameters + PagingCore momentum 截断）
- `Sources/PagingPrototypeApp/`（CLI + 接线）
- `Tests/PagingCoreTests/`、相关 App 测试
- `Workflow/results/T-worker-b-glide.md`

## Forbidden

- `Package.swift`、`Docs/`、`PROVENANCE/`、`Workflow/`（结果文件除外）
- §1.3 禁止路径与治理文档

## Verification

- `swift build` exit 0（0 warning）；`swift test` 全量 0 failures
- `swift run -c release PagingPrototypeApp --momentum-glide-frames 11` → exit 2
- 结果文件记录：截断机制、测试证据、Deviations

## Status

- 2026-08-28：Main 记录决策（1 帧截断）；Worker 实施中。
