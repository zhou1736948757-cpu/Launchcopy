# T-worker-b-thresh46 — 阈值 0.46 / 0.40（第 12 轮用户决策，全屏基准）

**Worker**: B/D 同人（PagingCore 作者）
**来源**: 物理调参第 12 轮，用户原话："改成前进0.46，回退0.4"
**日期**: 2026-08-28
**Scope**: `Sources/PagingCore/PagingParameters.swift`、`Tests/PagingCoreTests/PagingCoreTests.swift`、`Workflow/results/T-worker-b-thresh46.md`
**Forbidden 遵守**: 未触碰 Package.swift / Docs / PROVENANCE / Workflow（结果文件除外）/ PagingUI / PagingTelemetry / PagingPrototypeApp
**AccessDeclaration: NO_PRIOR_EXPOSURE**（重申）

## 参数

1. `displacementThreshold` 默认 **0.48 → 0.46**（注释同步：第 12 轮用户决策）。
2. `retreatDisplacementFactor` 默认 **0.875 → 20.0/23.0**（≈0.869565；回退 = 0.46×20/23 =
   **0.40 页精确**——swift -e 验证 `0.46*(20.0/23.0) == 0.4` 在 double 中为真；注释同步）。
3. 判定逻辑不变（PageTargetPolicy 未动；速度强制路径不受影响）。

## 测试（180 全量，0 failures；两测试原地更新，net 0）

| 测试 | 断言 |
|---|---|
| `testFullscreenBaselineThresholdBoundaries`（velocityContribution=0 隔离） | 前进 450px→bounce / **461px**→advance；回退 −390px→bounce / **−400px**→retreat |
| `testFullscreenBaselineDefaultPathAsymmetry`（默认混合路径） | 回退 −400px @200px/s→retreat（位移分支）；前进 450px @16.7px/s→blended 0.4563<0.46→bounce；回退 −390px @16.7px/s→blended 0.3963<0.40→bounce |
| 速度强制/边界/RM/glide/momentum/过冲 | 全部保持通过（不回归） |

### 浮点边缘（记录）

- **回退 −400px 无需偏移**：`0.46×(20/23) == 0.4` 精确（double），合成 −400px/1000px 的
  ratio 亦恰为 −0.4 → ≥ 成立（t20 的 −420px 1-ulp 边缘随 0.875→20/23 消失）。
- **前进 460px 出现 1-ulp 边缘**：`1.0+(460/1000)` 舍入后 ratio = 0.45999999999999996 < 0.46
  （0.46 的 double 表示略高于字面量）→ 命中用例用 **461px**（0.461 ≥ 0.46）；谓词语义
  "ratio ≥ 0.46 翻页"不受影响（注释已说明）。

## Verification（命令 + 退出码）

| 命令 | 结果 |
|---|---|
| `swift test`（全量） | **180 tests, 0 failures**，exit 0 |
| `swift build`（debug + release） | exit 0（0 warning） |

## Changed Files

- `Sources/PagingCore/PagingParameters.swift`（0.46 / 20.0/23.0 + 注释）
- `Tests/PagingCoreTests/PagingCoreTests.swift`（两测试更新 + 浮点边缘注释）
- `Workflow/results/T-worker-b-thresh46.md`（本文件）

## Deviations

1. 前进命中用例用 461px（460px 的 1-ulp 舍入边缘，见上）——谓词语义不变。
2. 无其他偏差；Docs 参数表行回填留 Main。

## Memory Candidates

- 阈值乘积的浮点边缘随系数变化而移动：0.875 时代回退有 1-ulp 边缘（−420px 失败），20/23 时代
  回退精确（−400px 通过）但前进 460px 出现 1-ulp 边缘（需 461px）——每次改阈值先 swift -e
  验证命中/未命中边界再写测试。
