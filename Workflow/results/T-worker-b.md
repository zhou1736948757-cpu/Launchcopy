# Worker Result — T-worker-b（PagingCore 实现 + 单元测试）

- **Task ID**: T-worker-b
- **Role**: Worker B（fresh context 实现 worker）
- **Date**: 2026-08-28
- **AccessDeclaration: NO_PRIOR_EXPOSURE**
  未读取任何禁止来源（BuhoReverseNotes / LaunchBetter/Packages / LaunchBetterApp / 2026-08-25-buho-launchpad-reverse / Launch_Copy 治理文档）；
  仅读取任务包指定的 6 份输入（T-worker-b.md / PHASE1_SPEC.md / ADR-001 / PARAMETER_RATIONALE.md / VALIDATION_PLAN.md / Package.swift）。
  未修改 Package.swift、Docs/、PROVENANCE/、Workflow/（除本结果文件与心跳记录）。

## Changed Files

**Sources/PagingCore/（独占写入范围，6 文件）**

| 文件 | 内容 |
|---|---|
| `PagingParameters.swift` | 23 参数集中配置（PARAMETER_RATIONALE.md 全表对应：默认值/合法范围/来源类别注释；RM 生效值 helper） |
| `PagingState.swift` | 五语义状态 `PagingState`（idle/tracking/settling/interrupted/cancelled）+ 归一化 `GesturePhase`（D1） |
| `GestureSession.swift` | 手势会话：startOffset/currentOffset/totalDelta/velocity（ΣΔ/Σdt 窗口，含 began 时间基准）/released/momentum 子阶段/惯性滑行标记/rebase（D1/D4/D5） |
| `TransitionContext.swift` | transition 身份：单调 token + `CommitState` pending/committed/stale + hasCommitted 单次提交 + SettleReason（D3） |
| `PageTargetPolicy.swift` | 目标页策略：位移比例 + 速度（含 momentum）+ 边界 clamp + RM 输入面 → 回弹/前进/后退；阈值全部来自参数（D9） |
| `PagingCore.swift` | 状态机本体：输入分派（D5 防御）、中断接管（D4）、tick 手动 spring 插值（D2）、stale rejection（D3）、resize/pageCount 三分支（D6）、RM 动态切换（D8）、cancel/teardown（D1/D7）、事件出口 |

**Tests/PagingCoreTests/（独占写入范围，2 文件，51 用例）**

| 文件 | 内容 |
|---|---|
| `PagingCoreTests.swift` | §7.1 全部场景（44 用例）+ 测试台 CoreHarness/EventRecorder |
| `PagingCoreSequenceTests.swift` | §7.2 六条可重复事件序列（7 用例） |

## Per-Criterion Results

### §7.1 场景覆盖（Prompt §7.1 / VALIDATION_PLAN §1.1）— 全部通过

| 场景 | 测试 |
|---|---|
| page count 0 / 1 / 2 / 多页 | `testPageCountZero/One/Two`、`testMultiPage` |
| current page 首 / 中 / 尾 | `testCurrentPageFirst/Middle/Last` |
| 小位移回弹 | `testSmallDisplacementBounces` |
| 达到翻页条件 | `testTurnConditionMet` |
| 高速度小位移 | `testHighVelocitySmallDisplacement`（80px @ 4000px/s → 强制翻页） |
| 低速度大位移 | `testLowVelocityLargeDisplacement`（600px @ 300px/s → 位移翻页） |
| 首页向前越界 / 末页向后越界 | `testFirstPageBackwardOverscroll(+Capped)`、`testLastPageForwardOverscroll(+Capped)`（阻尼 ×0.35、封顶 0.25 页） |
| transition 中断 | `testTransitionInterruption` |
| 连续两次反向中断 | `testDoubleReverseInterruption` |
| 旧 completion 晚到 | `testLateCompletionRejected` |
| pageCount tracking 时减少 | `testPageCountReductionDuringTracking(+ToSinglePage)` |
| pageCount settling 时减少 | `testPageCountReductionDuringSettlingValidTarget/InvalidTarget` |
| resize/page width | `testResizeDuringTrackingProportionalRebase`、`testResizeDuringSettlingRecomputesTargetWithNewToken`、`testResizeIdle` |
| cancel | `testCancelDuringTracking/Settling` |
| teardown | `testTeardownNoResidualCallbacks` |
| Reduce Motion | `testReduceMotionInstantCommit/InstantBounce/NoOverscroll/ToggleMidSettle/MomentumStillTurnsPage` |
| 附加（防御性/子阶段） | `testMomentumIsTrackingSubStage`、`testMomentumGlideIntoBoundaryIsSafe`、`testDefensiveDuplicateBeganIgnored/ChangedWithoutSession/EndedWithoutSession/ChangedAfterEndedIgnored/EndedAfterEndedIgnored/MomentumWithoutRelease/MomentumChangedWithoutMomentumBegan/PhaseCancelledSnapsToRest`、`testLegacyScrollFallback` |

### §7.2 序列覆盖（Prompt §7.2 / VALIDATION_PLAN §1.2）— 全部通过

每条断言：最终页 / 视觉偏移 / transition 状态 / commit 次数 / stale callback 数量。

| 序列 | 测试 | 断言要点 |
|---|---|---|
| begin → changes → end | `testSequenceBeginChangesEnd` | committed=1、offset=1.0、ctx pending→committed、commit=1、stale=0 |
| begin → changes → end → momentum | `testSequenceBeginChangesEndMomentum` | momentum+滑行改变结果（无 momentum 对照回弹）；committed=1、stale=0 |
| settling → begin opposite direction | `testSequenceSettlingBeginOppositeDirection` | 接管点连续（startOffset==接管前 offset）、stale=1、结果反转落 2、commit=1 |
| settling → resize | `testSequenceSettlingResize` | 物理位置保持（offset×2）、round+clamp 新 target、新 token、stale=1、commit=1 |
| settling → pageCount reduction | `testSequenceSettlingPageCountReduction(+ValidTarget)` | 越界 target 作废+clamp+重置（commit=2）、合法 target 继续（stale=0） |
| tracking → window close | `testSequenceTrackingWindowClose` | teardown 后所有入口短路、回调冻结、commit=0、stale=0 |

### §3.F 中断安全硬门禁（6 条）— 全部覆盖

| 门禁 | 机制 | 测试证据 |
|---|---|---|
| 1 立即接管 | settling + began 同步中断（D4） | `testTransitionInterruption`、S3 序列 |
| 2 位置连续 | 新 session startOffset = 当前 visualOffset（精确相等断言） | S3 序列、`testDoubleReverseInterruption`（两次接管均断言） |
| 3 不跳回旧点 | 旧 TransitionContext 作废，不再被读取 | 中断后 activeTransition==nil；旧 ctx 偏移不再参与 |
| 4 旧 completion 不覆盖 | token 三防线（D3） | `testLateCompletionRejected`、`testDoubleReverseInterruption`（旧 ctx 晚到被拒） |
| 5 无双重 commit | commitState + hasCommitted 单次（D3） | 全部序列 commit==1 断言 |
| 6 close/resize/pageCount 安全 | D6/D7 | S4/S5/S6 序列 |

## Verification

```text
命令 1：cd /Users/mac/Projects/Launch_Copy/PagingPrototype && swift build --target PagingCore
        结果：Build of target: 'PagingCore' complete!（无警告无错误）   exit_code = 0
命令 2：cd /Users/mac/Projects/Launch_Copy/PagingPrototype && swift test --filter PagingCoreTests
        结果：Test Suite 'PagingPrototypePackageTests.xctest' passed
              Executed 51 tests, with 0 failures (0 unexpected)          exit_code = 0
        （44 个 §7.1 用例 + 7 个 §7.2 序列用例；executed_tests = 51 > 0，非 INVALID_TEST_EXECUTION）
```

兄弟 target（PagingTelemetry/PagingUI/App）为空仅产生 source-path warning，不影响本 target 构建与测试（与任务包预验证一致）。

## Deviations

1. **momentum 释放时序**：`gestureEnded` 后 Core 停留在 tracking（session.released 子阶段），由 `finishGesture()`（无 momentum 时 UI 调用）或 `momentumEnded`（惯性耗尽或滑行结束）触发释放决策。此实现使 momentum 严格作为 tracking 子阶段（D1），并让 §7.2 序列 1/2 可确定性区分。UI 层（Worker D）须在 ended 后无 momentum 事件时调用 `finishGesture()`。
2. **teardown 拒绝计数语义**：D3 的 `staleRejectionCount` 在 teardown 后对迟到 completion 仍计数（满足"否则计数"），但按 D7 不触发任何回调事件（`onStaleRejection` 在 `isTearingDown` 后抑制）。已在代码注释与测试中明确。
3. **RM 下 momentum 降级**：D8"momentum 缩短"落实为 RM 下不做惯性滑行（`momentumEnded` 直接释放决策），速度仍参与翻页决策；状态机/token 逻辑不变。
4. **pageCount 减少时的"短 settle"**：D6 的"可新启短 settle"落实为以正常 settleDuration 重启（token 递增）；RM 下为即刻提交。未引入额外时长参数。
5. **settle 完成判据**：位置容差 1e-3 页（0.1%）+ 速度容差 0.05 页/s；spring 角频率由 `ω0 = ln(100)/(ζ×settleDuration)` 推导（包络 1% 时刻 = settleDuration）。两者为文档化的实现细节常量，非交互参数（未计入 23 参数表）。
6. **速度估计**：`ΣscaledΔ / Σdt` 滑窗（0.1s / 8 样本），单样本即得 delta/dt（dt 含 began 时间基准）；momentumBegan 清空手指样本使 momentum 速度由 momentum 事件决定（物理上 momentum 代表释放瞬间甩动速度）。

## Memory Candidates（供后续阶段）

- 中断后释放决策以 **committedPage 为基准**（D9：位移比例 = offset − committedPage），非以接管点为基准——反向接管后小幅回拉仍回弹到 committed 页（两个测试曾据此修正预期，属正确行为）。
- 边界阻尼作用于**越界增量**而非绝对位置（单调连续、不振荡）；overscroll 深度上限为 maximumOverscroll（RM 为 0），向内回拉不阻尼。
- teardown 必须第一时间置 `isTearingDown`，所有入口（handleGesturePhase/finishGesture/tick/completeSettle/setPageWidth/setPageCount/setReduceMotion/cancel/legacyScrollDelta）首查短路——这是"无残留回调"的单一机制。
- 事件驱动 momentum + 滑行模拟的分工：momentumChanged 期间由事件驱动；momentumEnded 后若速度 > velocityThreshold×5% 进入 tick 驱动滑行（momentumDecay 每帧衰减），撞边界或耗尽即释放决策。
- 测试台模式（CoreHarness：固定 dt、显式时间戳、事件记录）可复用于 Worker C/D 的集成测试。

## 未完成项

- 无（任务包范围内全部完成）。多页甩动（一次手势跨多页）按 D9 回弹/前进/后退语义为单页前进，属设计内边界，未实现亦未列入验收。
