# Review T-1F-C-tests-session-r1 — DragSessionControllerTests 交付审核

- Reviewer: independent (read-only; no implementation files touched)
- Deliverable: `Tests/AppGridUITests/DragSessionControllerTests.swift` (22 tests, 514 lines)
- Reference: `Sources/AppGridUI/DragSession/DragSessionController.swift`, `EdgePagingScheduler.swift`, `DropResolver.swift`, `DropIntent.swift`, `DragMutationEngine.swift`, `DragSessionEvents.swift`, `DragTransaction.swift`, `DragGeometry.swift`, `DragParameters.swift`; `Tests/AppGridUITests/DragSessionTestSupport.swift`
- Verdict: **PASS**

## 1. Matrix coverage (8/8)

| # | Matrix item | Test(s) |
|---|---|---|
| 1 | 阈值仲裁 (click vs drag) | `testClickBelowThresholdYieldsClickedAndReturnsToIdle` (:47), `testSubThresholdMoveStaysPressedThenClick` (:67), `testMovePastThresholdBeginsDrag` (:86) |
| 2 | 状态机全路径 | `testStateMachineFullPathThroughEdgeTurnToCommit` (:103) |
| 3 | stale source/layout/catalog 拒绝 | `testStaleSourceRejectedAtPointerDown` (:155), `testStaleLayoutGenerationCancelsOnMove` (:168), `testStaleCatalogGenerationCancelsOnMove` (:186), `testStaleLayoutGenerationCancelsOnPointerUp` (:201) |
| 4 | 无活动 session / 重复 drop 拒绝 | `testDropWithoutActiveSessionYieldsNoEvents` (:223), `testDuplicateDropAfterCommitYieldsNoEvents` (:241) |
| 5 | second drag 使旧 session 失效 | `testSecondDragCancelsFirstSession` (:265) |
| 6 | 统一 cancel 全路径 + dwell-armed | `testUnifiedCancelAllReasons` (:295, 遍历 `DragCancelReason.allCases` 全部 9 个 case), `testCancelWhenIdleYieldsNoEvents` (:317), `testCancelWhileDwellArmedEmitsDwellCancelled` (:324) |
| 7 | edge 序列 enter-dwell-turn-leave + 边界 | `testEdgeSequenceEnterDwellTurnLeave` (:347), `testEdgeFirstPageLeftEmitsAtFirstPageWithoutDwell` (:383), `testEdgeLastPageRightEmitsAtLastPageWithoutDwell` (:399), `testEdgeTimerFiredWhilePressedYieldsNoEvents` (:416), `testEdgeTimerFiredWithStaleLayoutCancels` (:429) |
| 8 | commit 路径 committed/noOp/rejected | `testCommitTopLevelInsertionProducesNewLayout` (:456), `testNoOpDropAtSameIndex` (:479), `testInvalidDropRejected` (:497) |

## 2. Test quality — real behavior, matches source semantics

All 22 tests manually traced against source; expectations match:

- **阈值**: `dragStartThresholdPT 6` — 3pt move 保持 `.pressed`，10pt move 触发 `.dragBegan`（`pointerMoved`: `distance(to: downPoint) >= dragStartThresholdPT`）。
- **状态机全路径** (page1/pageCount3): move x=10 → `[.edgeEntered(.left), .dwellStarted(.left)]`，deadline 0.1s；clock 0.2 → `[.pageTurnRequested(.left)]`；move x=100 → `[.edgeLeft(.left), .intentChanged(.insertion(1))]`（zone1 72..100）；drop x=90 → committed `[app2, app1]` gen 1。与 `EdgePagingScheduler`（hysteresis 进入 x<40 / 离开 x>=50；`edgeTurnMinIntervalMs 200` → 二次 deadline = max(0.3, 0.4)）及 `DragMutationEngine`（insertion+topLevelApp → reorderTopLevel，generation +1）一致。
- **stale 拒绝**: layout gen 1 / catalog gen 2 在 move 与 pointerUp 均 → `[.cancelled(.layoutChanged)]` / `[.cancelled(.catalogRefresh)]`；`sourcePresent` 检查（ghost 标题不在 layout/catalog）→ pointerDown 直接拒绝，无 `.pressed`。
- **无 session / 重复 drop**: 均 → `[]`（controller 层无 session 即 no-op；tokenConsumed 在 `DropResolver` 内部，测试注释已说明该边界）。
- **second drag**: 非 idle 时 pointerDown 先 `[.cancelled(.secondDrag)]` 再 `.pressed`，新 session 清 `lastOutcome`（`DragSessionController.swift:85`）。
- **cancel 全路径**: 9 个 `DragCancelReason` case 逐一 → `[.cancelled(reason)]` + 回 idle + nil transaction + `lastOutcome` 记录 + 残留 pointerUp → `[]`；idle 时 cancel → `[]`；dwell-armed 时 cancel → `[.edge(.dwellCancelled), .cancelled(reason)]`（`edgeScheduler.cancel()` 先发 dwellCancelled）。
- **edge 边界**: page0 左缘 → `[.dragBegan, .edgeEntered(.left), .atFirstPage(.left)]` 无 dwell（`atBoundary` 不 arm）；page2/pageCount3 右缘 x=390 → `[.dragBegan, .edgeEntered(.right), .atLastPage(.right), .intentChanged(.insertion(2))]`；pressed 态 timer → `[]`；armed + stale layout timer → `[.edge(.dwellCancelled), .cancelled(.layoutChanged)]`。
- **commit 路径**: x=5 → insertion(0) 同 index → `[.noOp]`；x=60（own app center zone）→ `[.rejected(.targetMissing)]`（`.invalid` intent 在 `DropResolver.consume` 中先命中 `targetStillValid` → `.targetMissing`，与源码一致）。

工厂使用符合任务要求：`FakeDragClock`、`makeDragLayout(titles:revision:)`、`ref(title)` = `.bundleID("fixture.<lowercase>")`、`rowFrames`（x=i*100, w=80, h=80）、`topLevelGeometry(frames:containerWidth:page:pageCount:)`、`assertContains`；参数 `dragStartThresholdPT 6 / edgeDwellDurationMs 100 / edgeZoneWidthPT 40 / edgeHysteresisPT 10 / dropZoneMarginsPT 8 / overlayMoveOutArmThresholdPT 24 / edgeTurnMinIntervalMs 200 / maxDragPreviewScale 1.0`。

## 3. 测试计数核对（MINOR 发现）

- 交付文件实际含 **22** 个 `func test` 方法（grep 计数 22），Worker 结果声称 21。
- 基线为 **885**（`Workflow/results/T-1F-B-actor-hasloaded-repair.md:16` 与 `Workflow/reviews/T-1F-B-tests-actor-r1.md:52` 均记录 885/0），非 Worker 声称的 886。
- **885 + 22 = 907**，与 Worker 报告的总数 907 及实测 `Executed 907 tests` 完全一致。Worker 的分解（886+21）两处均标错，但总数正确，不影响验收。

## 4. Privacy

仅合成 fixture 数据：bundleID `fixture.app1/app2/app3/ghost`，标题 app1/app2/app3/ghost。无真实 app 名称/路径/身份。

## 5. Scope (mtimes)

- Worker 窗口：task 创建 08:46:46（events.jsonl seq 581-583）→ review 开始 08:51:08（seq 584）。
- `Tests/AppGridUITests/DragSessionControllerTests.swift` 08:50:37、`Workflow/results/T-1F-C-tests-session.md` 08:51:01 — 均在窗口内 ✓
- 全部 `Sources/AppGridUI/DragSession/*.swift` 早于窗口：DragGeometry 01:56:58、DragParameters 01:57:03、DragSessionEvents 01:57:14、DragTransaction 01:57:08、DragMutationEngine 02:13:14、DragSessionController 02:13:48、DropResolver 02:13:10、DropIntent 02:47:13、EdgePagingScheduler 05:15:14 ✓
- `DragSessionTestSupport.swift` 03:14:03 — 早于窗口 ✓
- Repo 无 git 历史（全 untracked）；mtimes 为权威 scope 证据。本任务未修改任何源文件。

## 6. Verification runs (serial, project root)

1. `swift build -c debug` → `Build complete!` exit 0 ✓
2. `swift test` → **Executed 907 tests, with 0 failures (0 unexpected) in 12.378s**，exit 0 ✓（完整日志 /tmp/t1fc-swift-test.log，行 2058/2060）
3. `swift build -c release` → `Build complete!` exit 0 ✓

## Findings

- **MINOR**: Worker 结果中测试计数分解标错（声称 21 个方法 + 886 基线；实际 22 个方法 + 885 基线）。总数 907 正确且与实测一致；仅报告表述不精确，不影响交付物质量。

## Verdict

**PASS** — 8/8 矩阵项覆盖；22 个测试逐一对照源码语义全部吻合（含边界行为：page0 左 / 末页右不 arm dwell、dwell-armed cancel 先发 `.dwellCancelled`、second drag 清 `lastOutcome`、`.invalid` intent → `.targetMissing`）；privacy 干净；scope 干净（无源文件改动）；三项验证命令全绿（debug 0 / test 907-0 / release 0）。
