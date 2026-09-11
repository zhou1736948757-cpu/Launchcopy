# T-worker-b-softdamp — momentum 过冲软阻尼（无静止帧）

**Worker**: B/D 同人（PagingCore 作者）
**来源**: 物理调参第 7 轮，用户反馈（原话）："往左走的话感觉是拉一小段以后会顿一下，然后再吸过去。"
**证据**: phys-auto-09——28 次手势 momentum 阶段出现 4 个连续静止帧（offset 硬顶钳制线后冻结 ~60ms @~66Hz，
随后截断 settle = "顿一下再吸"）。根因：`momentumMaxOvershoot` 为硬上限 clamp，越限即顶死。
**日期**: 2026-08-28
**Scope**: `Sources/PagingCore/`（PagingCore + PagingParameters 注释）、`Tests/PagingCoreTests/`、`Workflow/results/T-worker-b-softdamp.md`
**未触碰**: Package.swift / Docs / PROVENANCE / Workflow（结果文件除外）/ PagingUI / PagingTelemetry / PagingPrototypeApp（默认 0.20 与 CLI 均不变）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（重申）

## 阻尼实现（递推对事件增量）

`applyingMomentumOvershootClamp`：越限（committed+1+0.20 / committed−0.20）后，
**depth = prevDepth + momentumOvershootDamping(0.2) × 本事件 delta**，offset = limit ± depth：
- **无静止帧**：正 delta 下每事件 offset 严格前进 0.2×delta > 0；单调逼近。
- **无状态**：depth 由前一展示位 + 本事件 delta 推出，不引入 session 字段。
- **峰值 = 上限 + 0.2×越限后增量累计**（gi=69 形态：3.20 + 0.2×0.984 = 3.3968）。
- 慢甩未越限路径零变化（分支直接返回 raw）；边界页 guard 跳过（既有 applyingBoundary 递推不变）。
- 决策速度不受影响：样本记录真实 delta/dt，展示钳制不触碰样本（既有机制，未改）。

**实现取舍**（结果文件记录）：一次性 `limit+excess×0.2` 形式对**已阻尼展示位**重复应用会复合衰减
（越限区 offset 回退漂移，实测 3.4055→3.2189，破坏单调）；递推对增量阻尼无此问题。

## 测试（+2：纯钳制区压力 + 反向；快甩/自定义更新）

| 测试 | 断言 |
|---|---|
| `testMomentumOvershootClampedFastFling`（更新） | gi=69 形态：10 事件 offset **严格递增**（无静止帧）；峰值 = 3.20+0.2×0.984 = 3.3968（精确）；截断点 settle、target 3、fromOffset = 峰值位、拉回 = 0.3968 ≤ 0.20+0.1968；决策速度 ≫ 800；commit 1、stale 0 |
| `testMomentumOvershootSoftDampNoFrozenFrames`（新） | 8×0.3 页全越限压力：每事件严格递增，峰值 = 3.20+6×0.06 = 3.56（硬钳制会冻结 6 帧） |
| `testMomentumOvershootSoftDampReverse`（新） | 负向（往左，用户感知方向）gi=71 形态：每事件严格后退；终点 = 2.8−(0.925+0.2×1.607) = 1.5536（精确）；retreat → 2；拉回 0.4464 ≤ 0.20+0.3214；速度保留；commit 1、stale 0 |
| `testMomentumOvershootCustomValueApplied`（更新） | 自定义 0.1 → 峰值 3.2968（CLI 可调路径） |
| 慢甩 / 边界（4.1575 / −0.105）/ RM / glide | 断言不变，全部通过 |

## 测试期间发现并修正（非实现错，测试 setup 错）

快甩测试原 `change(2429)` 从 page 2 落点 raw 4.429 **超出末页边界** → 边界阻尼 0.429×0.35=0.15015
→ 实际 ended = 4.15015（非注释的 2.429）。硬钳制时代该偏差被"顶死 3.20"掩盖（峰值断言仍过）；
软阻尼 + 单调断言暴露。修正为 `change(429)`（真 ended 2.429，不触边界）。边界测试本就设计为触界，
不受影响。

## Verification（命令 + 退出码）

| 命令 | 结果 |
|---|---|
| `swift build`（debug + release） | exit 0（0 warning） |
| `swift test`（全量） | **174 tests, 0 failures**（172 → +2），exit 0 |
| `swift test --filter MomentumOvershoot` | 10 tests, 0 failures |

## Changed Files

- `Sources/PagingCore/PagingCore.swift`（+`momentumOvershootDamping = 0.2` 常量；clamp 改递推；注释）
- `Sources/PagingCore/PagingParameters.swift`（注释同步：硬钳制 → 软阻尼）
- `Tests/PagingCoreTests/PagingCoreTests.swift`（+2 测试；2 更新；setup 修正）
- `Workflow/results/T-worker-b-softdamp.md`（本文件）

## Deviations

1. 峰值/拉回断言按递推公式取精确值（ε 由公式给出），非硬钳制时代的 0.20 整值——软阻尼语义下
   "上限"是逼近线而非硬顶线，拉回 = 0.20 + 0.2×越限增量累计。
2. 无新参数（阻尼系数 0.2 为私有常量，任务建议值）；`momentumMaxOvershoot` 默认 0.20 与
   `--momentum-overshoot` CLI 未动。
3. Docs 参数表行回填留 Main（本波禁写 Docs）。

## Memory Candidates

- **边界阻尼作用于所有 track delta（含手指）**：测试 setup 必须核算落点是否触界（2429px 从 page 2
  落 4.429 → 边界阻尼到 4.15015）——硬钳制会掩盖此类 setup 错，加"无静止帧/单调"断言后才能暴露。
- 展示钳制若对"已阻尼展示位"重复应用会复合衰减（回退漂移）——对增量阻尼（depth += k×delta）是
  无状态单调的正确形式。
- 往左（负向）分支：began 时可能已越限（1.875 < 2.8）——depth 初值含 began 位越深，公式天然覆盖。
