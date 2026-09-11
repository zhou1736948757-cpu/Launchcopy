# T-worker-b-thresh43 — 阈值 0.43 / 0.36（Phase 1B 物理调参，第 14 轮用户决策，全屏基准）

**Worker**: worker-pagingcore2（deepseek-v4-flash:0731，max）
**来源**: Phase 1B 物理调参轮，用户真实内容全屏 phys1b-03 实测后指示："前进改成0.43，回退改成0.36"（t16 的 0.45/0.38 已 PASS，本次在其基础上再调）
**日期**: 2026-08-28
**Scope**: `Sources/PagingCore/PagingParameters.swift`、`Sources/PagingCore/PageTargetPolicy.swift`（仅 L64-67 注释）、`Tests/PagingCoreTests/PagingCoreTests.swift`、`Workflow/results/T-worker-b-thresh43.md`
**Forbidden 遵守**: 未触碰 Package.swift / 其他 Sources/ / 其他 Tests/（PagingUI、AppGridUI 等）/ Docs / PROVENANCE / Workflow/STATE.json / Workflow/events.jsonl；未运行 record_workflow_event.py（Main 负责）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（未接触任何治理文档 / §2.2 路径 / 其他项目；仅接触本任务写范围文件）

## 改动摘要（旧值 → 新值）

| 参数 | 旧值（t16） | 新值 | 语义 |
|---|---|---|---|
| `displacementThreshold` | 0.45 | **0.43** | 前进翻页位移阈值（页宽比例） |
| `retreatDisplacementFactor` | 38.0/45.0（≈0.844444） | **36.0/43.0**（≈0.837209） | 回退阈值系数；回退 = 0.43×36/43 = **0.36 页精确** |

- 注释同步：`PagingParameters.swift` 决策链补记第 14 轮（0.45 → 0.43，phys1b-03）；`retreatDisplacementFactor` 注释由 "38/45 ≈ 0.844444 → 0.45×38/45 = 0.38 页精确" 改为 "36/43 ≈ 0.837209 → 0.43×36/43 = 0.36 页精确"；`PageTargetPolicy.swift` L64-67 注释块同步（worker 链补 -thresh43，数值改 36/43 → 0.36 页、前进 0.43 / 回退 0.36）。
- 判定逻辑零改动（PageTargetPolicy.swift 仅注释文本）。
- 冻结参数未动：`momentumDecay` 0.55、`momentumGlideFrames` 1、`momentumMaxOvershoot` 0.20（grep 复核原值在位）。

## 边界测试证据（swift test --filter 实测，两测试均 passed）

### `testFullscreenBaselineThresholdBoundaries`（velocityContribution = 0 隔离纯位移判定）

| 输入 | 期望 | 实测断言 |
|---|---|---|
| 前进 420px（0.42 页）@200px/s | bounce | `committedPage == 0` ✓ "前进 0.42 < 0.43 → bounce" |
| 前进 430px（0.43 页）@200px/s | advance | `committedPage == 1` ✓ "前进 0.43 ≥ 0.43 → advance" |
| 回退 −350px（0.35 页）@200px/s | bounce | `committedPage == 1` ✓ "回退 0.35 < 0.36 → bounce" |
| 回退 −360px（0.36 页）@200px/s | retreat | `committedPage == 0` ✓ "回退 0.36 ≥ 0.36 → retreat" |

### `testFullscreenBaselineDefaultPathAsymmetry`（默认参数、真实混合路径）

| 输入 | 期望 | 实测断言 |
|---|---|---|
| 回退 −360px @200px/s | 位移分支 retreat | `committedPage == 0` ✓ |
| 前进 420px @16.7px/s | blended 0.4263 < 0.43 → bounce | `committedPage == 0` ✓ |
| 回退 −350px @16.7px/s | blended 0.3563 < 0.36 → bounce | `committedPage == 1` ✓ |

## 1-ulp 处理说明（先验证数学再写测试；Main 预验证 + 本 worker 独立复核一致）

`swift -e` 实测（double）：

```
0.43*36.0/43.0 == 0.36   → true   （回退阈值乘积精确）
430.0/1000.0 >= 0.43     → true   （前进命中边界精确）
420.0/1000.0 < 0.43      → true   （前进未命中侧稳定）
360.0/1000.0 == 0.36     → true   （回退命中边界精确）
350.0/1000.0 < 0.36      → true   （回退未命中侧稳定）
(1.0 + (-360.0/1000.0)) - 1.0 == -0.36 → true（减法消位无损失）
```

- **零 1-ulp 偏移**：测试输入即字面边界值（420/430px、350/360px），无需偏移补偿（延续 t16 的 0.45/0.38 时代；0.46 时代的 461px 偏移早已消失）。
- 混合路径数值：0.42 + 0.3×(16.667/800) = 0.42625 < 0.43；0.35 + 0.3×(16.667/800) = 0.35625 < 0.36（swift -e 验证）。
- UI 层（PagingUITests）400px@0.5s 手势速度恰为 800.0 px/s → 走速度强制路径，不受位移阈值影响（全量 414 含 UI 测试全绿佐证）。

## Verification（命令 + 退出码）

| 命令 | 结果 |
|---|---|
| `swift test`（全量，改动后） | **414 tests, 0 failures**，exit 0 |
| `swift test --filter 'PagingCoreTests/testFullscreenBaseline'` | 2 tests, 0 failures（边界证据） |
| `swift build -c release` | exit 0，**0 warnings**（grep -ci warning = 0） |

## Changed Files

- `Sources/PagingCore/PagingParameters.swift`（0.43 / 36.0/43.0 + 注释同步；仅此两常量）
- `Sources/PagingCore/PageTargetPolicy.swift`（仅 L64-67 注释块同步新值，零代码改动）
- `Tests/PagingCoreTests/PagingCoreTests.swift`（两阈值测试原地适配 + 浮点注释）
- `Workflow/results/T-worker-b-thresh43.md`（本文件）

## Deviations / 观察

1. 无偏差。测试输入即字面边界值（0.42/0.43、0.35/0.36），无 1-ulp 偏移。
2. Docs 参数表行回填留 Main。

## Memory Candidates

- 阈值乘积的浮点边缘随系数变化而移动：0.875 时代回退有 1-ulp 边缘（−420px 失败）；20/23 时代回退精确但前进 460px 出现 1-ulp 边缘（需 461px）；38/45 与 36/43 时代（0.45/0.38、0.43/0.36）**两侧全部精确、零偏移**——每次改阈值先 swift -e 验证命中/未命中边界再写测试。
- 本 worker 未自我认证 PASS：以上为事实与证据，由 Main 判定。
