# Task Packet: T-worker-b-overshoot（momentum 过冲钳制）

- **Task ID**: T-worker-b-overshoot
- **Role**: Worker（PagingCore 作者）
- **来源**: T-step8 物理调参第 5 轮：用户感知"甩到第 4-5 页再被拉回"
- **日期**: 2026-08-28

## 用户反馈（原话）

"滑快了感觉有种我一下子甩到个第四页、第五页，然后再被强制拉回第二页的感觉……因为太快了，我看不清楚。"

## 证据（phys-auto-07 telemetry，非幻觉，已量化）

gi=69（快甩）：ended 时 offset=2.429 → momentum 跟随事件流：2.65→2.858→3.052→3.234→3.405→3.557→3.702→3.841→3.975→**4.036**（第 10 事件=截断点，2N=10）→ 决策目标 committed=3（一页一翻策略：prev committed 2 → +1 = 3）→ **settle 从 4.036 拉回 3.0**（1 页拉回，视觉"飞越再拉回"）。
gi=68 同型：ended 1.324 → 2.823 → commit 2（拉回 0.8 页）。
gi=71（反向快甩）：ended 1.875 → momentum 反推至 1.041 → commit 2（目标 2，拉回 ~1 页）。

**根因**：momentum 跟随窗口（2N 事件）内系统惯性事件 delta 大（~0.17 页/事件），offset 被推远超决策目标（1.6 页过冲）；"一页一翻"策略目标远小于当前 offset → spring 长距离拉回。

## 修复要求

1. **PagingParameters 加 `momentumMaxOvershoot: Double = 0.35`（页）**（PRODUCT_DECISION；物理调参中）：momentum 跟随阶段，offset 相对"决策上界"的越界量受钳制。
   - 语义建议：momentum 阶段 offset 不得超过 `committedPage + 1 + momentumMaxOvershoot`（正向）与 `committedPage - momentumMaxOvershoot`（负向，边界页另按 overscroll 阻尼既有逻辑）。
   - 钳制只限 offset 展示位置，**不得破坏速度估算与决策**（截断点 finishGesture 的翻页判定仍以真实事件速度为据——若钳制影响计速，需分离"展示 offset"与"决策速度"，写明理由与实现）。
2. 快甩视觉：最多冲到目标页 + 0.35 页 → 拉回距离 ≤0.35 页（无飞越感）。
3. 慢滑/边界/反向路径不受影响（边界 overscroll 阻尼既有逻辑不变；RM 强制 0 不变）。
4. **测试**：
   - 快甩序列（复用 gi=69 形态的事件流）：offset 峰值 ≤ committed+1+0.35；commit 恰 1 次；settle 起点与目标距离 ≤0.35。
   - 慢甩：无钳制触发（offset 未越限，行为同旧）。
   - 边界页反向甩：不回越过边界（既有 overscroll 测试保持）。
   - 全量 swift test 0 failures（164+）。
5. 不改：momentumGlideFrames 语义、一页一翻策略、其余参数默认。

## Write Scope

- `Sources/PagingCore/`（PagingParameters + momentum 钳制）
- `Tests/PagingCoreTests/`
- `Workflow/results/T-worker-b-overshoot.md`

## Forbidden

- `Package.swift`、`Docs/`、`PROVENANCE/`、`Workflow/`（结果文件除外）
- `Sources/PagingUI/`、`Sources/PagingTelemetry/`、`Sources/PagingPrototypeApp/`（本波不加 CLI；试值确认后可 CLI 化）
- §1.3 禁止路径与治理文档

## Verification

- `swift build` exit 0（0 warning）；`swift test` 全量 0 failures
- 结果文件记录：钳制机制、速度/决策分离与否及理由、测试证据

## Status

- 2026-08-28：Main 量化确认过冲（1.6 页）；Worker 实施中。
