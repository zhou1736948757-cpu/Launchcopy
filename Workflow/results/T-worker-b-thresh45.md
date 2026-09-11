# T-worker-b-thresh45 — 阈值 0.45 / 0.38（Phase 1B 物理调参，第 13 轮用户决策，全屏基准）

**Worker**: worker-pagingcore2（deepseek-v4-flash:0731，max）
**来源**: Phase 1B 物理调参轮，用户真实内容全屏实测后指示："把前进改成45，回退改成38"
**日期**: 2026-08-28
**Scope**: `Sources/PagingCore/PagingParameters.swift`、`Tests/PagingCoreTests/PagingCoreTests.swift`、`Workflow/results/T-worker-b-thresh45.md`
**Forbidden 遵守**: 未触碰 Package.swift / 其他 Sources/（含 PageTargetPolicy.swift）/ 其他 Tests/（PagingUI、AppGridUI 等）/ Docs / PROVENANCE / Workflow/STATE.json / Workflow/events.jsonl；未运行 record_workflow_event.py（Main 负责）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（未接触任何治理文档 / §2.2 路径 / 其他项目；前一个 worker 上下文耗尽未留改动，本 worker 从干净状态开始）

## 改动摘要（旧值 → 新值）

| 参数 | 旧值 | 新值 | 语义 |
|---|---|---|---|
| `displacementThreshold` | 0.46 | **0.45** | 前进翻页位移阈值（页宽比例） |
| `retreatDisplacementFactor` | 20.0/23.0（≈0.869565） | **38.0/45.0**（≈0.844444） | 回退阈值系数；回退 = 0.45×38/45 = **0.38 页精确** |

- 注释同步：`displacementThreshold` 决策链补记第 13 轮（0.46 → 0.45）；`retreatDisplacementFactor` 注释由 "20/23 ≈ 0.869565 → 0.46×20/23 = 0.40 页精确" 改为 "38/45 ≈ 0.844444 → 0.45×38/45 = 0.38 页精确"。
- 判定逻辑未动（PageTargetPolicy.swift 零改动；速度强制路径不受影响）。
- 冻结参数未动：`momentumDecay` 0.55、`momentumGlideFrames` 1、`momentumMaxOvershoot` 0.20（grep 复核原值在位）。

## 边界测试证据（swift test --filter 实测，两测试均 passed）

### `testFullscreenBaselineThresholdBoundaries`（velocityContribution = 0 隔离纯位移判定）

| 输入 | 期望 | 实测断言 |
|---|---|---|
| 前进 440px（0.44 页）@200px/s | bounce | `committedPage == 0` ✓ "前进 0.44 < 0.45 → bounce" |
| 前进 450px（0.45 页）@200px/s | advance | `committedPage == 1` ✓ "前进 0.45 ≥ 0.45 → advance" |
| 回退 −370px（0.37 页）@200px/s | bounce | `committedPage == 1` ✓ "回退 0.37 < 0.38 → bounce" |
| 回退 −380px（0.38 页）@200px/s | retreat | `committedPage == 0` ✓ "回退 0.38 ≥ 0.38 → retreat" |

### `testFullscreenBaselineDefaultPathAsymmetry`（默认参数、真实混合路径）

| 输入 | 期望 | 实测断言 |
|---|---|---|
| 回退 −380px @200px/s | 位移分支 retreat | `committedPage == 0` ✓ |
| 前进 440px @16.7px/s | blended 0.4463 < 0.45 → bounce | `committedPage == 0` ✓ |
| 回退 −370px @16.7px/s | blended 0.3763 < 0.38 → bounce | `committedPage == 1` ✓ |

## 1-ulp 处理说明（先验证数学再写测试）

`swift -e` 实测（double）：

```
450.0/1000.0 == 0.45        → true   （前进命中边界精确，无需偏移）
440.0/1000.0 < 0.45         → true   （前进未命中侧稳定）
0.45*38.0/45.0 == 0.38      → true   （回退阈值乘积精确）
380.0/1000.0 == 0.38        → true   （回退命中边界精确，无需偏移）
370.0/1000.0 < 0.38         → true   （回退未命中侧稳定）
(1.0 + (-380.0/1000.0)) - 1.0 == -0.38 → true（减法消位无损失）
```

- **0.46 时代的 1-ulp 边缘已消失**：旧 461px 偏移源于 `(1.0+0.46)−1.0` 减法消位得 0.45999999999999996；0.45/0.38 下命中侧全部精确（含从 page 1 出发的回退路径），**本轮零 1-ulp 偏移**，测试输入即字面边界值。
- 混合路径数值：0.44 + 0.3×(16.667/800) = 0.44625 < 0.45；0.37 + 0.3×(16.667/800) = 0.37625 < 0.38（swift -e 验证）。
- UI 层（PagingUITests）400px@0.5s 手势速度恰为 800.0 px/s → 走速度强制路径，不受位移阈值影响（全量 414 含 UI 测试全绿佐证）。

## Verification（命令 + 退出码）

| 命令 | 结果 |
|---|---|
| `swift test`（全量，改动后） | **414 tests, 0 failures**，exit 0 |
| `swift test`（全量，改动前基线） | 414 tests, 0 failures（net 0 测试数变化，两测试原地更新） |
| `swift test --filter 'PagingCoreTests/testFullscreenBaseline'` | 2 tests, 0 failures（边界证据） |
| `swift build -c release` | exit 0，**0 warnings**（grep -ci warning = 0） |

## Changed Files

- `Sources/PagingCore/PagingParameters.swift`（0.45 / 38.0/45.0 + 注释同步；仅此两常量）
- `Tests/PagingCoreTests/PagingCoreTests.swift`（两阈值测试原地适配 + 浮点注释）
- `Workflow/results/T-worker-b-thresh45.md`（本文件）

## Deviations / 观察

1. 无偏差。测试输入即字面边界值（0.44/0.45、0.37/0.38），无 1-ulp 偏移。
2. 观察（未触碰，超出写范围）：`Sources/PagingCore/PageTargetPolicy.swift` L64-66 注释仍写 "0.875 → 0.42 页；全屏基准下前进 0.48 / 回退 0.42"，为 0.46 时代之前的历史残留（与 0.45/0.38 均不符）；该文件不在本 worker 写范围，留 Main 决定是否清理。
3. Docs 参数表行回填留 Main。

## Memory Candidates

- 阈值乘积的浮点边缘随系数变化而移动：0.875 时代回退有 1-ulp 边缘（−420px 失败）；20/23 时代回退精确但前进 460px 出现 1-ulp 边缘（需 461px）；38/45 时代（0.45/0.38）**两侧全部精确、零偏移**——每次改阈值先 swift -e 验证命中/未命中边界再写测试。
- 本 worker 未自我认证 PASS：以上为事实与证据，由 Main 判定。
