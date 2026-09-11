# Task Packet: T-worker-b-softdamp（过冲软阻尼，消除"顿一下"）

- **Task ID**: T-worker-b-softdamp
- **Role**: Worker（PagingCore 作者）
- **来源**: T-step8 物理调参第 7 轮：用户感知往左"拉一小段后顿一下再吸过去"
- **日期**: 2026-08-28

## 用户反馈（原话）

"往左走的话感觉是拉一小段以后会顿一下，然后再吸过去。"

## 证据（phys-auto-09 telemetry，已量化）

**28 次手势**的 momentum 阶段出现 **4 个连续静止帧**（offset 硬顶在钳制线：`committed+1+0.20`（如 2.8/3.8）或 `committed−0.20`（如 0.8/−0.25）后冻结 ~60ms），随后截断决策 → settle"吸过去"。硬钳制造成静止（顿感）；往右方向同样存在（用户左甩多所以感知单向）。

## 修复要求

1. **硬钳制 → 软阻尼逼近**：momentum 阶段 offset 越过 `committed+1+maxOvershoot`（正）/ `committed−maxOvershoot`（负）后，超出部分按阻尼系数**渐进吸收**（offset 持续单调变化，**无连续静止帧**）。阻尼系数建议 0.2（与既有边界 overscroll 阻尼一致，风格统一）；实现方式（一次性 `upper + excess×0.2` 或递推逼近）自选，写理由，必须保证：
   - offset 单调逼近上限、永不"顶死"（钳制区内相邻事件 offset 变化 > 0）
   - 决策速度不受影响（样本记录不动）
   - 慢甩（未越限）路径零变化；边界页既有 overscroll 阻尼递推不变
2. `momentumMaxOvershoot` 默认 0.20 不变（仅语义变软）；`--momentum-overshoot` CLI 不变。
3. **测试**：
   - 快甩（gi=69 形态 + 现有快甩序列）：钳制区内**无静止帧**（断言相邻 momentum offset 变化 > 0，直到截断）；峰值 ≤ upper+ε；拉回 ≤ 0.2+ε；commit 恰 1 次；stale 0；决策速度保留（>800px/s 断言保持）。
   - 慢甩无钳制；边界（4.1575/−0.105）与 RM/glide 断言不变。
   - 全量 swift test 0 failures（172+）。
4. `swift build` exit 0（0 warning）。

## Write Scope

- `Sources/PagingCore/`（PagingCore momentum 钳制段 + PagingParameters 注释）
- `Tests/PagingCoreTests/`
- `Workflow/results/T-worker-b-softdamp.md`

## Forbidden

- `Package.swift`、`Docs/`、`PROVENANCE/`、`Workflow/`（结果文件除外）
- `Sources/PagingUI/`、`Sources/PagingTelemetry/`、`Sources/PagingPrototypeApp/`
- §1.3 禁止路径与治理文档

## Verification

- `swift test` 全量 0 failures；`swift build` exit 0（0 warning）
- 心跳 role Worker, task-id T-worker-b-softdamp, ACTIVE

## Status

- 2026-08-28：Main 量化确认静止帧（28 手势 × 4 帧）；Worker 实施中。
