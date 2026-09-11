# T-worker-b-overshoot — momentum 过冲钳制（momentumMaxOvershoot）

**Worker**: B/D 同人（PagingCore 作者）
**来源**: 物理调参第 5 轮，用户反馈（原话）："滑快了感觉有种我一下子甩到个第四页、第五页，然后再被强制拉回第二页的感觉……因为太快了，我看不清楚。"
**日期**: 2026-08-28
**Scope**: `Sources/PagingCore/`（PagingParameters + PagingCore）、`Tests/PagingCoreTests/`、`Workflow/results/T-worker-b-overshoot.md`
**未触碰**: Package.swift / Docs / PROVENANCE / Workflow（结果文件除外）/ PagingUI / PagingTelemetry / PagingPrototypeApp（本波不加 CLI）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（重申）

---

## 根因（Main 量化，phys-auto-07 telemetry 复读）

gi=69 快甩：ended offset=2.429 → momentum 跟随事件流（2N=10 截断）冲到 **4.036**（1.6 页过冲）→
一页一翻目标 committed=3 → **settle 从 4.036 拉回 3.0**（1 页拉回 = "飞越再拉回"视觉）。
gi=68/71 同型（拉回 0.8–1 页）。根因：momentum 跟随窗口内系统惯性事件 delta 大（~0.17 页/事件），
offset 被推远超决策目标。

## 钳制机制

`PagingParameters.momentumMaxOvershoot: Double = 0.35`（页；PRODUCT_DECISION；物理调参中；默认值直接生效，本波无 CLI）：

- **触发范围**：仅 momentum 跟随阶段（`session.momentumActive`；applyTrackedDelta 内钳制）——
  手指跟踪阶段不钳制（直接操纵，钳制会破坏跟手）。
- **钳制界**：正向 `committedPage + 1 + momentumMaxOvershoot`；负向 `committedPage - momentumMaxOvershoot`。
- **边界页**：`committed` 在首/末页时 guard 跳过——既有 applyingBoundary 阻尼（增量 ×boundaryResistance、
  深度封顶 maximumOverscroll 0.25）已约束且其上限 ≤ 钳制上界，不冲突。
- **顺序**：先 applyingBoundary 后钳制（边界阻尼优先，钳制只收紧非边界页过冲）。

## 速度/决策分离：**不需要分离**（理由）

速度估算走 **样本真实 delta/dt**（`session.recordDelta` 存未钳制的 `scaledDeltaPx`/`dt`，
`recomputeVelocity` = ΣΔ/Σdt）——钳制只改 `resultingOffset`（currentOffset），**从不触碰样本**，
因此：
- 截断点 finishGesture 的速度输入 = 真实事件速度（测试断言截断前 velocity ≫ 800px/s）；
- 决策的 offset 输入 = 钳制后（可见）位置——语义正确：决策基准与用户所见一致（gi=69 位移 2.429→3.35
  均 ≥ 0.5，决策不变；force-advance 由速度触发，不受影响）。
- beginSettle fromOffset = 钳制位 → spring 从可见位置起跳，无跳变。

## 测试（+4，全 Core）

| 测试 | 断言 |
|---|---|
| `testMomentumOvershootClampedFastFling` | gi=69 事件形态（N=5、2N=10 截断、初始 committed 2）：峰值 == 3.35（= committed+1+0.35；无钳制会到 4.036）；截断点 settle、target 3、fromOffset 3.35、**拉回 = 0.35 ≤ 0.35**；截断前速度 ≫ 800（决策速度保留）；后续事件拒绝；commit 恰 1 次、stale 0 |
| `testMomentumOvershootSlowFlingUnclamped` | 慢甩（位移 0.64 ≥ 0.5、速度 400）：峰值 2.64 < 3.35 钳制不触发；翻页正常；commit 1 |
| `testMomentumOvershootBoundaryLastPageDampingGoverns` | 末页正向：峰值 4.1575 = 边界阻尼递推值（手指 0.07 + 5×0.0175），≤ 4.25 封顶；钳制 guard 跳过；commit 1 |
| `testMomentumOvershootBoundaryFirstPageBackward` | 首页负向：谷值 -0.105 = 阻尼递推值，≥ -0.25；钳制 guard 跳过；commit 1 |

## Verification（命令 + 退出码）

| 命令 | 结果 |
|---|---|
| `swift build`（debug + release） | exit 0（0 warning） |
| `swift test --filter MomentumOvershoot` | 4 tests, 0 failures |
| `swift test`（全量） | **168 tests, 0 failures**（164 → +4），exit 0 |
| 既有 momentum/边界/RM 测试 | 全部保持通过（含 testReduceMotionMomentumStillTurnsPage、glide 截断 5 测试、overscroll 既有测试） |

## Changed Files

| 文件 | 变更 |
|---|---|
| `Sources/PagingCore/PagingParameters.swift` | +`momentumMaxOvershoot: Double = 0.35`（文档：语义/边界/速度保留/来源） |
| `Sources/PagingCore/PagingCore.swift` | applyTrackedDelta：momentum 阶段钳制；+`applyingMomentumOvershootClamp` |
| `Tests/PagingCoreTests/PagingCoreTests.swift` | +4 测试（gi=69 快甩/慢甩/末页/首页） |
| `Workflow/results/T-worker-b-overshoot.md` | 本文件 |

## Deviations

1. **测试期望首版 3 处错（非实现错）**：边界页手指阶段的 delta 也走阻尼（0.2×0.35=0.07 深度起始，
   非 0.2）；慢甩位移 0.14 < 0.5 判回弹（非翻页）——按实际阻尼递推与决策语义修正期望值（精确断言
   阻尼递推值 4.1575/-0.105，比封顶断言更强）。
2. **决策 offset 用钳制值**（非原始 4.036）：意图内——决策基准与可见位置一致；速度输入不受影响
   （样本真实 delta/dt），force-advance 与位移判定在 gi=69 形态下决策结果不变（advance→3）。
3. **本波无 CLI**（任务要求）：默认 0.35 直接生效；用户确认后如需微调再 CLI 化（届时走
   AppArguments + AppParameters.make 既有模式）。
4. Docs/PARAMETER_RATIONALE.md 参数表行回填留 Main（本波禁写 Docs）。

## Memory Candidates

- 边界阻尼作用于**所有** track delta（含手指阶段）——测试期望必须从阻尼后状态递推，不能假设
  offset == raw 累计。
- 速度估算样本与展示 offset 解耦（recordDelta 存真实 delta）→ "展示钳制"可安全叠加在任意
  输入路径上而不污染决策速度；此结构是 momentum 阶段视觉修正的安全基础。
- 钳制界相对 committed（非相对当前 offset）——一页一翻目标的天然上界，拉回距离恒 ≤ 0.35。
