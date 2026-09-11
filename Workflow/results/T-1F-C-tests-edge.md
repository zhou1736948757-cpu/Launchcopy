# T-1F-C-tests-edge — EdgePagingScheduler 测试

Status: PASS

## 计划

- 写范围（仅 1 文件）：新建 `Tests/AppGridUITests/EdgePagingSchedulerTests.swift`。
- 覆盖任务包测试矩阵 8 项：进入/离开（含 hysteresis 回退）、首尾边界（atFirstPage/atLastPage、不武装 dwell）、dwell 满翻页（保持武装连续翻页）、翻页最小间隔、过期 timer、跨区（左↔右）、cancel（武装/未武装、lastTurnTime 保留）、nextDwellDeadline（未武装 nil / 武装 now+dwell / 翻页后 max 规则）。
- 必须使用 `Tests/AppGridUITests/DragSessionTestSupport.swift` 的工厂：`FakeDragClock` 驱动全部时序（now 由 clock.now() 注入）。
- 只读参考（任务包 4 文件 + 编排者指定 2 文件）：`EdgePagingScheduler.swift`、`DragGeometry.swift`、`DragParameters.swift`、`DragSessionTestSupport.swift`、`DragSessionEvents.swift`、`DragSessionController.swift`。
- 验证（串行，项目根）：`swift build -c debug` → `swift test` → `swift build -c release`，全部 exit 0、0 failures。
- 约束：不改任何源码/现有测试/冻结树；无 git 操作；纯几何 fixture（无真实 app 数据）。

## 测试清单

`Tests/AppGridUITests/EdgePagingSchedulerTests.swift` — 26 个测试，全部通过：

1. `testEnterLeftEdgeArmsDwell` — 入左缘 → edgeEntered(.left)+dwellStarted(.left)，currentZone=.left，dwellArmed=true
2. `testLeaveLeftEdgeEmitsEdgeLeftAndDisarms` — 出左缘（hysteresis 回退）→ edgeLeft(.left)，dwellArmed=false
3. `testHysteresisKeepsZoneWithinFallbackBand` — 回退带内（x=45）保持 .left、无事件
4. `testLeaveRightEdgeWithHysteresis` — 右缘回退带内保持；越过（x=340）→ edgeLeft(.right)
5. `testUpdateWithinSameZoneEmitsNothing` — 同区移动无事件
6. `testUpdateOutsideZoneEmitsNothing` — 区外移动无事件
7. `testFirstPageLeftEdgeEmitsAtFirstPageWithoutDwell` — page 0 左缘 → atFirstPage，不武装
8. `testLastPageRightEdgeEmitsAtLastPageWithoutDwell` — 末页右缘 → atLastPage，不武装
9. `testMiddlePageRightEdgeArmsDwell` — 中间页右缘正常武装
10. `testSinglePageBothEdgesAreBoundaries` — 单页（pageCount=1）左右缘均为边界
11. `testLeaveBoundaryZoneEmitsEdgeLeft` — 边界区离开 → edgeLeft
12. `testDwellElapsedRequestsPageTurnAndStaysArmed` — dwell 满 → pageTurnRequested，保持武装连续翻页，lastTurnTime 更新
13. `testDwellElapsedAtBoundaryAfterPageChangeDisarmsAndEmitsBoundary` — 翻页到末页后 timer 触发 → atLastPage + 复位
14. `testTurnMinIntervalSuppressesImmediateSecondTurn` — 翻页后立即触发 → []；过 edgeTurnMinIntervalMs → 再翻
15. `testDwellElapsedWithoutArmingReturnsEmpty` — 未武装 timer → []
16. `testDwellElapsedAfterLeaveReturnsEmpty` — 离开后残留 timer → []
17. `testCrossZoneLeftToRightEmitsLeaveThenEnter` — 左→右 → edgeLeft(.left)+edgeEntered(.right)+dwellStarted(.right)
18. `testCrossZoneRightToLeft` — 右→左对称
19. `testCancelWhileArmedEmitsDwellCancelledAndClearsState` — 武装 cancel → dwellCancelled，zone nil、dwellArmed false、lastTurnTime 保留
20. `testCancelWhileUnarmedReturnsEmpty` — 未武装 cancel → []
21. `testReenterAfterCancelArmsFreshly` — cancel 后重入重新武装
22. `testNextDwellDeadlineNilWhenUnarmed` — 未武装 → nil
23. `testNextDwellDeadlineNilAtBoundary` — 边界不武装 → nil
24. `testNextDwellDeadlineArmedIsNowPlusDwell` — 武装 → now + dwell 时长
25. `testNextDwellDeadlineAfterTurnRespectsMinInterval` — 翻页后 → max(now+dwell, lastTurn+minInterval)
26. `testNextDwellDeadlineMinIntervalDominatesWhenDwellShorter` — dwell < minInterval 时最小间隔主导

## 验证证据

（串行，项目根 `/Users/mac/Projects/Launch_Copy/PagingPrototype`）

1. `swift build -c debug` → `Build complete!`，exit 0。
2. `swift test` → `Test Suite 'All tests' passed`，**Executed 972 tests, with 0 failures (0 unexpected)**，exit 0。
   - 基线 946（编排者提供；任务包内 837 为旧值，已被后续任务测试数超越）+ 本任务 26 = 972 ✓。
   - 定向复核：`swift test --filter EdgePagingSchedulerTests` → `Executed 26 tests, with 0 failures`，exit 0。
3. `swift build -c release` → `Build complete!`，exit 0。

## 偏差与说明

- 无偏差。写范围仅 1 个新测试文件；未改任何源码/现有测试/冻结树；无 git 操作；fixture 全为合成几何数据。
- 任务包基线 837 与编排者摘要基线 946 不一致：以实际运行结果为准（972 = 946 + 26），0 failures。
