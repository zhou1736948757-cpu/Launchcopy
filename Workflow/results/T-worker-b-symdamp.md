# T-worker-b-symdamp — 负向阻尼线对称化

**Worker**: B/D 同人（PagingCore 作者）
**来源**: 物理调参第 8 轮，用户反馈（原话）："这个你就不能改成跟往右走一样吗？"——往左（下一页）与
往右（上一页）手感不一致。
**根因（Main 定位，代码 + telemetry 双证据）**：正向阻尼线 = `committed+1+0.2`（offset 到目标页 +0.2 才阻尼）
→ 往左 momentum 全量滑 ~0.37 页；负向阻尼线 = `committed−0.2`（offset 往回滑 0.2 页就阻尼）
→ 往右 momentum 滑 ~0.15 页（后半已阻尼）——往左拖沓、往右干脆。
**日期**: 2026-08-28
**Scope**: `Sources/PagingCore/PagingCore.swift`（负向分支 + 注释）、`Tests/PagingCoreTests/`、`Workflow/results/T-worker-b-symdamp.md`
**未触碰**: Package.swift / Docs / PROVENANCE / Workflow（结果文件除外）/ PagingUI / PagingTelemetry / PagingPrototypeApp；默认 0.20、CLI、递推机制均不动
**AccessDeclaration: NO_PRIOR_EXPOSURE**（重申）

## 阻尼线公式（对称化后）

- 正向：`committed + 1 + overshoot`（目标 = committed+1，线 = 目标 + overshoot）
- 负向：`(committed − 1) − overshoot`（目标 = committed−1，线 = 目标 − overshoot）——**与正向同构**
- guard `committedPage > 0` 保留；**新增**：负向线低于首页（committed=1 → 线 −0.2 < minLegal 0）时
  钳制不介入（首页 overscroll 由既有边界阻尼负责）——见下"发现"。

## 行为（对称后）

- 往右（committed=1）：阻尼线 = −0.2 → momentum 段全程全量滑（行程与往左同量级）；
- 往左：不变（线 3.2，与第 7 轮相同）；
- 边界页：不变（首/末页由 applyingBoundary 负责）。

## 测试（+2；reverse 更新）

| 测试 | 断言 |
|---|---|
| `testMomentumOvershootSoftDampReverse`（更新） | gi=71 形态：阻尼线 2.8 → **1.8**（(3−1)−0.2）；began 位 1.875 在线内（初深 0）→ 终点 = 1.8 − 0.2×1.607 = **1.4786**（精确）；retreat → 2；拉回 0.5214 ≤ 0.20+0.3214；无静止帧（严格后退）；速度保留 |
| `testMomentumOvershootSymmetryForwardBackward`（新） | 阻尼线 = 目标±0.2：正/负向相同 |delta| 序列（0.1 页×10）自由行程**相同 0.7 页**、均事件 8 首触阻尼、阻尼段每事件位移相同（0.02）——精确对称断言（3.2+0.06 / 1.8−0.06） |
| `testMomentumOvershootFirstPageBoundaryGoverns`（新） | committed=1 负向线 −0.2 < 0：钳制不介入，10×(−0.2) 冲过首页 → 边界递推封顶 **−0.25**（精确）；retreat → 0 |
| 正向快甩/慢甩/边界（4.1575/−0.105）/RM/glide | 断言不变，全部通过 |

## 发现（实现第 2 版修正，非测试错）

committed=1 时若钳制照常介入（线 −0.2），与边界阻尼（minLegal 0 起阻尼、封顶 −0.25）**双重阻尼互相
抵消**：边界推 display → −0.25，钳制把"相对 −0.2 的增量"再阻尼 → display 弹回 ~−0.227 并震荡。
修正：负向分支 `guard limit >= 0`——阻尼线低于首页时钳制整体让位，边界独管（与正向末页
`committed < pageCount-1` guard 对称：任一方向的阻尼线超出合法区间时由边界负责）。

## Verification（命令 + 退出码）

| 命令 | 结果 |
|---|---|
| `swift build`（debug + release） | exit 0（0 warning） |
| `swift test`（全量） | **176 tests, 0 failures**（174 → +2），exit 0 |
| `swift test --filter MomentumOvershoot` | 12 tests, 0 failures |

## Changed Files

- `Sources/PagingCore/PagingCore.swift`（负向阻尼线 `(committed−1)−overshoot` + `limit >= 0` 让位 guard + 注释）
- `Sources/PagingCore/PagingParameters.swift`（注释同步：负向线 = `committedPage - 1 - momentumMaxOvershoot`）
- `Tests/PagingCoreTests/PagingCoreTests.swift`（reverse 更新 +2 测试）
- `Workflow/results/T-worker-b-symdamp.md`（本文件）

## Deviations

1. 首版测试期望 3 处错（非实现错）：对称测试事件 8–10 只 3 个阻尼事件（我写成 4×0.02）；
   首页测试 10×(−0.1) 只越过 0.05（未达封顶）——改 10×(−0.2)。
2. 负向分支新增 `limit >= 0` 让位 guard（任务文本只要求 `committedPage > 0` 保留——发现双重阻尼
   打架后按任务意图"第 1 页 overscroll 由既有边界阻尼管负责"落实）。
3. Docs 参数表行回填留 Main。

## Memory Candidates

- 阻尼线超出合法区间（正向末页 / 负向 committed=1）时，钳制必须整体让位给边界阻尼——
  两套递推在同一区间叠加会互相抵消（display 在 −0.25 ↔ −0.227 间震荡）。
- 对称性断言模板：相同 |delta| 序列 + 到各自阻尼线等距起点 → 自由行程/首触事件号/阻尼段步长三
  重相等（比"同距离翻页"更直接）。
