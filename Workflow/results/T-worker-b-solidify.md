# T-worker-b-solidify — 固化最终默认参数（glide 1 / decay 0.55）

**Worker**: B/D 同人（PagingCore 作者）
**来源**: 60Hz 物理门 PASS（用户主观 4/4/4/4/4，全屏基准）——调参期间 CLI 试值固化进默认值
**日期**: 2026-08-28
**Scope**: `Sources/PagingCore/PagingParameters.swift`、`Tests/PagingCoreTests/`、`Tests/PagingUITests/`（断言同步，见 Deviations ①）、`Workflow/results/T-worker-b-solidify.md`
**Forbidden 遵守**: 未触碰 Package.swift / Docs / PROVENANCE / Workflow（结果文件除外）/ PagingUI / PagingTelemetry / PagingPrototypeApp（Sources）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（重申）

## 参数固化

1. `momentumGlideFrames` 默认 **nil → 1**（注释：物理门固化，第 11 轮用户决策"惯性滑好久才会停"；
   松手后最多跟 2 个惯性事件 → 立即决策 → settle 吸住；**显式 nil 仍 = 跟随完整系统流，语义保留**）。
2. `momentumDecay` 默认 **0.95 → 0.55**（注释：物理门固化，第 2 轮用户决策；N=1 下 glide 段极短
   但保持一致；固化值 0.55 超出原标注合法范围 0.8–0.99，注释同步说明）。
3. 其余默认已固化（本任务未动）：displacementThreshold 0.46、retreatDisplacementFactor 20/23、
   momentumMaxOvershoot 0.20（软阻尼）、momentumOvershootDamping 0.2（私有常量）。
4. CLI 语义不变：`--momentum-glide-frames` / `--momentum-decay` 可覆盖默认。

## 测试（181 全量，0 failures；180 → +1 net）

| 测试 | 断言 |
|---|---|
| `testMomentumGlideDefaultIsOne`（新） | **默认参数**下第 2 个 momentum 事件后截断 → settle；截断后系统流防御拒绝；commit 恰 1 次、stale 0 |
| `testMomentumGlideFramesNilFollowsFullStream`（更新） | 默认已变 N=1 → 显式 `glideParameters(nil)` 保留 nil 语义覆盖（长系统流不截断） |
| `AppParametersTests.testNilKeepsCoreDefault`（更新） | 缺省断言：momentumDecay 0.95→**0.55**、momentumGlideFrames nil→**1** |
| `AppArgumentsTests`（注释更新） | CLI 缺省仍 nil（= 用 PagingParameters 默认 1），断言不变 |
| 既有：N=1 显式截断/N=0 直接决策/RM 忽略/边界/速度强制/阈值 0.46/0.40/过冲软阻尼 | 全部保持通过（不回归） |

## Verification（命令 + 退出码）

| 命令 | 结果 |
|---|---|
| `swift test`（全量） | **181 tests, 0 failures**，exit 0 |
| `swift build`（debug + release） | exit 0（0 warning） |

## Changed Files

- `Sources/PagingCore/PagingParameters.swift`（glide 默认 1 + decay 默认 0.55 + 注释）
- `Tests/PagingCoreTests/PagingCoreTests.swift`（+testMomentumGlideDefaultIsOne；nil 测试显式化）
- `Tests/PagingUITests/AppParametersTests.swift`（缺省断言 0.55 / 1）
- `Tests/PagingUITests/AppArgumentsTests.swift`（注释同步）
- `Workflow/results/T-worker-b-solidify.md`（本文件）

## Deviations

1. `Tests/PagingUITests/AppParametersTests.swift` 在 Write Scope（Tests/PagingCoreTests/）之外，
   但其缺省断言（0.95 / nil）与固化默认冲突，不更新则全量测试失败——按"全量 0 failures"要求
   同步更新（仅断言值，无行为改动）。
2. momentumDecay 固化值 0.55 超出原注释合法范围 0.8–0.99——注释同步说明（物理门调参结果）。

## Memory Candidates

- 默认参数断言散落在 PagingCoreTests（行为）与 PagingUITests（AppParameters 缺省）两处——
  固化默认时两处都要同步，否则全量测试红。
- momentumDecay 只影响 Core tick 驱动的滑行模拟（PagingCore.swift:656），测试中无依赖
  默认衰减距离的断言（仅 glide 启动条件），改默认安全。
