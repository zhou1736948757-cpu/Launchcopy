# T-1F-C-tests-edge — EdgePagingScheduler 测试编写

## 背景
T-1F-C（DragSession）Worker 在完成源码后因上下文耗尽中断，测试文件未写。编译修复（T-1F-BC-compile-repair）已合并，基线 837/0。本任务只写 EdgePagingScheduler 测试，不写 session/drop 测试（其他任务负责）、不改源码。

## 任务
新建 `Tests/AppGridUITests/EdgePagingSchedulerTests.swift`，覆盖 EdgePagingScheduler 测试矩阵（见下）。**必须使用现有 `Tests/AppGridUITests/DragSessionTestSupport.swift` 的工厂**（FakeDragClock 等；本测试主要用纯调度器 API，无需布局）。

## 只读范围（仅此 4 文件，不要读其他文件）
- `Sources/AppGridUI/DragSession/EdgePagingScheduler.swift`
- `Sources/AppGridUI/DragSession/DragGeometry.swift`（DragPoint/DragRect）
- `Sources/AppGridUI/DragSession/DragParameters.swift`
- `Tests/AppGridUITests/DragSessionTestSupport.swift`（工厂，必用）

## 公开 API 摘要（Main 已提取，源码已全读）
- `public struct EdgePagingScheduler: Equatable, Sendable`；`public init()`（dwellArmed = false）
- 可读状态：`currentZone: EdgeZone?`、`dwellArmed: Bool`、`lastTurnTime: TimeInterval?`
- `public mutating func update(pointer: DragPoint, containerWidth: Double, page: Int, pageCount: Int, now: TimeInterval, parameters: DragParameters) -> [EdgePagingEvent]`：
  - 同区无变化 → []
  - 离开边缘（hysteresis 回退）→ [.edgeLeft(old)]，dwellArmed 复位
  - 进入边缘 → enterEvents（含边界判定：全局首页左缘 → .atFirstPage；末页右缘 → .atLastPage；否则 .edgeEntered + dwell 武装 → .dwellStarted）
  - 跨区（左↔右）→ [.edgeLeft(old)] + enterEvents(new)
- `public mutating func dwellElapsed(now: TimeInterval, page: Int, pageCount: Int, parameters: DragParameters) -> [EdgePagingEvent]`：
  - 未武装/无 zone（过期 timer）→ []
  - 边界 → dwellArmed 复位 + 边界事件
  - 距上次翻页 < edgeTurnMinIntervalMs → []（deadline 重新武装）
  - 否则 → [.pageTurnRequested(zone)]，dwell 保持武装（支持连续翻页）
- `public mutating func cancel() -> [EdgePagingEvent]`：武装中 → [.dwellCancelled]；否则 []；零残留
- `public func nextDwellDeadline(after now: TimeInterval, parameters: DragParameters) -> TimeInterval?`：未武装 → nil；否则 max(now + edgeDwellDurationMs/1000, lastTurnTime + edgeTurnMinIntervalMs/1000)
- `EdgeZone`：.left/.right；`EdgePagingEvent`：edgeEntered/dwellStarted/pageTurnRequested/edgeLeft/dwellCancelled/atFirstPage/atLastPage
- `DragParameters`：edgeDwellDurationMs、edgeZoneWidthPT、edgeHysteresisPT、edgeTurnMinIntervalMs（构造小参数便于测试）

## 测试矩阵（Prompt §10.1 drag 部分）
1. **进入/离开**：指针入左缘 → .edgeEntered(.left) + .dwellStarted(.left)、currentZone = .left、dwellArmed = true；出缘（hysteresis 回退）→ .edgeLeft(.left)、dwellArmed = false。
2. **边界**：page 0 左缘 → .atFirstPage（无 dwell 武装）；page == pageCount-1 右缘 → .atLastPage；中间页正常 dwell。
3. **dwell 满翻页**：dwellElapsed 到点 → .pageTurnRequested(.right)；dwell 保持武装 → 连续翻页（再次 dwellElapsed 再翻）。
4. **翻页最小间隔**：翻页后立即 dwellElapsed → []（间隔内）；推进时钟过 edgeTurnMinIntervalMs → 再翻。
5. **过期 timer**：未武装/无 zone 时 dwellElapsed → []。
6. **跨区**：左缘 → 右缘 → [.edgeLeft(.left)] + [.edgeEntered(.right), .dwellStarted(.right)]。
7. **cancel**：武装中 cancel → [.dwellCancelled]、currentZone nil、dwellArmed false、lastTurnTime 保留；未武装 cancel → []。
8. **nextDwellDeadline**：未武装 → nil；武装 → now + dwell 时长；翻页后 → max(now+dwell, lastTurn+minInterval)。

## 写范围（仅此 1 文件）
- `Tests/AppGridUITests/EdgePagingSchedulerTests.swift`（新建）

## 禁止
- 不改任何源码文件（DragSession/ 全部 9 文件、冻结树一律不动）。
- 不写 session/drop 测试（其他任务负责）。
- 不读禁止来源；无 git 操作；隐私红线（无真实数据，纯几何测试）。

## 验证（必须全部通过）
1. `swift build -c debug` exit 0。
2. `swift test` 全量：期望 837 + 新增全绿、0 failures（写范围外失败如实报告、不修改）。
3. `swift build -c release` exit 0。

## 输出纪律
- 先写 `Workflow/results/T-1F-C-tests-edge.md`（状态 in progress + 计划），再动手。
- 完成后更新结果文件：测试文件路径、测试数、3 项验证输出、Status: PASS。
- 回复 <250 词，无大代码块。
