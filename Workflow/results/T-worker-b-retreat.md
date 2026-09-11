# T-worker-b-retreat — 回退方向位移阈值宽容化（retreatDisplacementFactor 0.9）

**Worker**: B/D 同人（PagingCore 作者）
**来源**: 物理调参第 9 轮，用户决策（原话）："调到0.45试一下"——回退方向（手指右滑/上一页）位移阈值
0.5 → 0.45。phys-auto-12：回退成功行程 0.524–0.658 贴门槛、前进 0.7+（生理不对称：往回滑行程天然短）。
**日期**: 2026-08-28
**Scope**: `Sources/PagingCore/PagingParameters.swift`（+retreatDisplacementFactor）、`Sources/PagingCore/PageTargetPolicy.swift`（阈值应用）、`Tests/PagingCoreTests/`、`Workflow/results/T-worker-b-retreat.md`
**未触碰**: Package.swift / Docs / PROVENANCE / Workflow（结果文件除外）/ PagingUI / PagingTelemetry / PagingPrototypeApp（本波不加 CLI）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（重申）

## 参数与判定改动

- `PagingParameters.retreatDisplacementFactor: Double = 0.9`（合法范围 0.7–1.0；0.9 × 0.5 = 0.45 页）。
- `PageTargetPolicy.decide`：`direction == -1` 时，**位移条件与位移+速度混合条件的阈值** =
  `displacementThreshold × retreatDisplacementFactor`（0.45）；前进方向保持 0.5；
  速度强制路径（absVelocity ≥ velocityThreshold）不变。
- **无循环依赖**：direction 由"速度 ≥ 阈值 ? 速度符号 : 位移符号"先行决定，阈值在其后计算。
- 边界 clamp 不变（候选目标页 clamp 后等于当前页 → 回弹）。

## 测试（+3）

| 测试 | 断言 |
|---|---|
| `testRetreatDisplacementFactorAsymmetry` | **核心不对称**：0.46 页 @100px/s（默认参数、真实混合路径）——回退 ≥ 0.45 → retreat；前进 blended 0.4975 < 0.5 → bounce |
| `testRetreatDisplacementFactorThresholdBoundary` | 阈值边界（velocityContribution=0 隔离纯位移）：回退 0.44 < 0.45 → bounce；前进 0.50 ≥ 0.5 → advance |
| `testRetreatVelocityForcedPathUnaffected` | 857px/s 位移 0.3：回退 → retreat、前进 → advance（速度强制路径两方向不受系数影响） |
| 既有判定（小位移回弹/0.6 翻页/高速小位移/首末越界/RM/glide/momentum） | 全部保持通过（179 全量 0 failures） |

## Verification（命令 + 退出码）

| 命令 | 结果 |
|---|---|
| `swift build`（debug + release） | exit 0（0 warning） |
| `swift test`（全量） | **179 tests, 0 failures**（176 → +3），exit 0 |
| `swift test --filter Retreat` | 3 tests, 0 failures |

## Changed Files

- `Sources/PagingCore/PagingParameters.swift`（+`retreatDisplacementFactor = 0.9`，注释含用户决策/数据依据）
- `Sources/PagingCore/PageTargetPolicy.swift`（threshold = direction == -1 ? 0.5×0.9 : 0.5，两条位移路径共用）
- `Tests/PagingCoreTests/PagingCoreTests.swift`（+3）
- `Workflow/results/T-worker-b-retreat.md`（本文件）

## Deviations

1. 回退 0.44 边界测试须 velocityContribution=0 隔离（默认 0.3 下 blended = 0.44+0.3×0.0625 =
   0.45875 ≥ 0.45 会误判翻页）；核心不对称测试保留默认参数走真实混合路径（dt 4.6 → 100px/s）。
2. 速度强制方向由速度符号决定（既有一致行为）——回退速度强制不受系数影响，测试两方向同路径断言。
3. Docs 参数表行回填留 Main。

## Memory Candidates

- 方向相关阈值（retreatDisplacementFactor）作用于"位移条件 + 混合条件"两处，速度强制分支必须
  保持原阈值——不对称宽容化只影响低速度判定。
- 混合路径下边界测试要用 velocityContribution=0 或近零速度隔离，否则速度权重会吞掉阈值边界断言。
