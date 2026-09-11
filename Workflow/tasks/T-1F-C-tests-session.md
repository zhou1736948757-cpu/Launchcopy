# T-1F-C-tests-session — DragSessionController 测试编写

## 背景
T-1F-C（DragSession）Worker 在完成源码后因上下文耗尽中断，测试文件未写。编译修复（T-1F-BC-compile-repair）已合并，基线 837/0。本任务只写 DragSessionController 状态机测试，不写 drop/edge 测试（后续任务）、不改源码。

## 任务
新建 `Tests/AppGridUITests/DragSessionControllerTests.swift`，覆盖 DragSessionController 测试矩阵（见下）。**必须使用现有 `Tests/AppGridUITests/DragSessionTestSupport.swift` 的工厂**（FakeDragClock、makeDragLayout、ref、rowFrames、appFrame、folderFrame、topLevelGeometry、folderGeometry、assertContains）。

## 只读范围（仅此 7 文件，不要读其他文件）
- `Sources/AppGridUI/DragSession/DragSessionController.swift`
- `Sources/AppGridUI/DragSession/DragSessionEvents.swift`（DragSessionState/DragCancelReason/DragSessionOutcome/DragSessionEvent/DropRejectionReason）
- `Sources/AppGridUI/DragSession/DragTransaction.swift`（DragTransaction/DragScope/DragSourceIdentity）
- `Sources/AppGridUI/DragSession/DragGeometry.swift`（DragPoint/DragRect/DragItemFrame/DragGeometry）
- `Sources/AppGridUI/DragSession/DragParameters.swift`
- `Sources/AppGridUI/LayoutDomain/PersistentWorkspaceLayout.swift`（布局构造）
- `Tests/AppGridUITests/DragSessionTestSupport.swift`（工厂，必用）

## 公开 API 摘要（Main 已提取）
- `public final class DragSessionController`；`public init(parameters: DragParameters = .default, clock: DragClock = SystemDragClock())`
- 可读状态：`state: DragSessionState`（.idle/.pressed/.dragging/.edgeTurnPending）、`activeTransaction: DragTransaction?`、`lastOutcome: DragSessionOutcome?`、`edgeDwellDeadline: TimeInterval?`、`lastIntent: DropIntent`、`moveOutArmed: Bool`
- 输入方法（均 `@discardableResult -> [DragSessionEvent]`）：
  - `pointerDown(at: DragPoint, source: DragSourceIdentity?, layout: PersistentWorkspaceLayout, catalogGeneration: UInt64)` — 硬门：非 idle 先 cancel(.secondDrag)；source nil 拒绝；stale source 拒绝；成功 → .pressed
  - `pointerMoved(to: DragPoint, geometry: DragGeometry, layout: PersistentWorkspaceLayout, catalogGeneration: UInt64)` — 阈值仲裁 → .dragBegan；edge 调度；intent 分类；双 generation 过期 → 统一 cancel
  - `edgeTimerFired(geometry: DragGeometry, layout: PersistentWorkspaceLayout, catalogGeneration: UInt64)` — dwell 满 → page turn
  - `pointerUp(at: DragPoint, geometry: DragGeometry, layout: PersistentWorkspaceLayout, catalogGeneration: UInt64)` — pressed 态 → .clicked；dragging 态 → commit/noOp/rejected
  - `cancel(reason: DragCancelReason) -> [DragSessionEvent]` — 统一 cancel 出口
- `DragParameters`：`dragStartThresholdPT`、`edgeDwellDurationMs`、`edgeZoneWidthPT`、`edgeHysteresisPT`、`dropZoneMarginsPT`、`overlayMoveOutArmThresholdPT`、`edgeTurnMinIntervalMs`、`maxDragPreviewScale`（构造小阈值参数便于测试）
- `DragSourceIdentity`：`.topLevelApp(PersistentAppReference)` / `.topLevelFolder(FolderID)` / 成员源（以源码为准）
- `DragSessionOutcome`：`.committed(PersistentWorkspaceLayout)` / `.noOp` / `.cancelled(DragCancelReason)` / `.rejected(DropRejectionReason)`

## 测试矩阵（Prompt §10.1 drag 部分）
1. **click vs drag 阈值仲裁**：pointerDown → pointerUp（未过阈值）→ [.clicked]、state 回 .idle、无 transaction；pointerDown → pointerMoved 过阈值 → .dragBegan、state = .dragging。
2. **状态机**：idle→pressed→dragging→（edgeTurnPending 视时序）→commit/cancel→idle 全路径；每 session 至多一个 lastOutcome。
3. **stale 防护**：source 不在布局中 → pointerDown 拒绝（无 .pressed）；layout generation 过期 / catalogGeneration 过期 → pointerMoved/pointerUp → 统一 cancel（.cancelled(.layoutChanged) 或 .rejected(.staleLayout/.staleCatalog)，以源码为准）。
4. **invalid token / duplicate drop**：无活动 session 的 drop 拒绝；同一 token 二次消费 → .rejected(.tokenConsumed)（以源码为准）。
5. **second drag 使旧 session 失效**：drag 进行中再次 pointerDown → 先 cancel(.secondDrag) 再开新 session。
6. **统一 cancel 全路径**：对 DragCancelReason 全 case（escape/windowResign/catalogRefresh/searchActivated/titleEditBegan/overlayClosed/teardown/secondDrag/layoutChanged）逐一 cancel → .cancelled(reason)、state 回 .idle、activeTransaction nil、零残留（后续 pointerUp 无事件）。
7. **edge 全序列**：拖入边缘 → edgeEntered → dwell 计时（FakeDragClock 推进）→ dwellStarted → pageTurnRequested；离开 → edgeLeft；全局首页左缘 → atFirstPage；末页右缘 → atLastPage（以源码行为为准）。
8. **commit 路径**：合法 drop（如顶层 insertion）→ .committed(新布局)（构造合法 intent 场景，以源码为准）。

## 写范围（仅此 1 文件）
- `Tests/AppGridUITests/DragSessionControllerTests.swift`（新建）

## 禁止
- 不改任何源码文件（DragSession/ 全部 9 文件、LayoutDomain/、冻结树一律不动）。
- 不写 drop/edge 测试（后续任务）。
- 不读禁止来源；无 git 操作；隐私红线（中性假数据，fixture 标题如 "app1"）。

## 验证（必须全部通过）
1. `swift build -c debug` exit 0。
2. `swift test` 全量：期望 837 + 新增全绿、0 failures（写范围外失败如实报告、不修改）。
3. `swift build -c release` exit 0。

## 输出纪律
- 先写 `Workflow/results/T-1F-C-tests-session.md`（状态 in progress + 计划），再动手。
- 完成后更新结果文件：测试文件路径、测试数、3 项验证输出、Status: PASS。
- 回复 <250 词，无大代码块。
