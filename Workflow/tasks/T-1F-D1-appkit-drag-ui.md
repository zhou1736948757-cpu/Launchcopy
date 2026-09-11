# T-1F-D1 — AppKit drag UI（拖拽 UI 核心）

Status: in progress
Created: 2026-08-31 (Main)
Depends on: T-1F-A (layout domain), T-1F-C (drag state machine + drop resolver + edge scheduler) — all merged.
Split decision (Main, recorded): T-1F-D split into D1 (drag UI core) + D2 (accessibility reorder actions) — serial waves, both depend on C; write sets overlap on AppDelegate.swift → serial. Rationale: single giant packet repeatedly exhausted Workers.

## 1. 目标

把已合并的纯 DragSession 域（Sources/AppGridUI/DragSession/）接到 AppKit 视图层：cell/overlay 拖拽源与目标、进程内 opaque token（ADR-010 决策：自定义窗口内 pointer state machine，**不使用 pasteboard**——token 只存在于内存 active-drag registry）、中性拖拽视觉、边缘翻页、顶层 + folder 内 + move-out UI、click/open/launch/blank-click 不回归、Reduce Motion。**不做**：provider 提交链、持久化、无障碍重排动作（T-1F-E / T-1F-D2）。

## 2. 写范围（仅这些文件）

- 新建 `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift` — 指针事件桥 + 状态机驱动 + 视觉呈现 seam + move-out 模式 + 统一 cancel 入口
- 新建 `Sources/AppGridUI/DragUI/DragUIVisuals.swift` — 中性 drag preview / 插入指示 / folder highlight / create-folder 指示（与插入视觉可区分，不只用颜色）
- 修改 `Sources/AppGridUI/AppGridCellView.swift` — 拖拽源（mouseDown/mouseDragged/mouseUp 跟踪 + 阈值仲裁，与既有 NSClickGestureRecognizer 协调）
- 修改 `Sources/AppGridUI/AppGridPageView.swift` — 向 coordinator 提供 cell frame 几何 + drop 目标 hit-test
- 修改 `Sources/AppGridUI/FolderOverlayView.swift` — 成员拖拽源/目标、move-out 模式、folder scope 边缘翻页
- 修改 `Sources/PagingPrototypeApp/AppDelegate.swift` — 装配 coordinator（几何提供、edge turn 入口、commit seam、cancel 钩子）
- 新建 `Tests/AppGridUITests/DragUISessionCoordinatorTests.swift` — 纯逻辑测试
- 新建 `Tests/PagingUITests/DragUIIntegrationTests.swift` — seam 驱动集成测试

**禁止写**：Sources/AppGridUI/DragSession/（已合并冻结）、Sources/AppGridUI/LayoutDomain/、Sources/AppGridUI/FolderDomain.swift、Sources/AppGridUI/FolderKeyboardLogic.swift、Sources/AppGridUI/AppGridFocusNavigator.swift、Sources/AppGridUI/AppGridFocusLayout.swift、Sources/AppGridUI/AppGridFocusIdentity.swift、Sources/AppGridUI/AppGridCellFocus.swift、Sources/AppGridUI/FolderOpenState.swift、Sources/AppGridUI/AppGridUIPageContentProvider.swift、Sources/AppGridUI/AppGridSearchPresentationController.swift、Sources/AppGridUI/AppGridUIState.swift、Tests/AppGridUITests/ 既有文件、Tests/PagingUITests/ 既有文件、全部冻结树（PagingCore/、AppCatalogCore/、MacAppCatalog/、AppIconPipeline/、PagingTelemetry/、PagingUI/、Package.swift、AppLaunchController.swift）、Docs/、PROVENANCE/。

## 3. 必读（严格限制，勿读其他）

1. 本包（含下方 API 摘要）
2. `Sources/AppGridUI/DragSession/DragSessionController.swift`（状态机驱动方式）
3. `Sources/AppGridUI/DragSession/DropIntent.swift` + `DropResolver.swift`（drop intent 分类与消费）
4. `Sources/AppGridUI/DragSession/EdgePagingScheduler.swift`（边缘翻页调度）
5. `Sources/AppGridUI/AppGridCellView.swift`、`Sources/AppGridUI/AppGridPageView.swift`、`Sources/AppGridUI/FolderOverlayView.swift`（现状）
6. `Sources/PagingPrototypeApp/AppDelegate.swift` 的 installFolderWiring 段（约 :418-473）与 search/titleEdit 段（约 :455-473、:620-624）
7. `Tests/PagingUITests/FolderIntegrationTests.swift` 的 makeFolderSeamFixture（约 :540）作测试模式参考
8. `Tests/AppGridUITests/DragSessionTestSupport.swift`（工厂）

**勿读**：LayoutDomain/、LayoutStore/、ADR-009/010、PHASE1F_DRAG_PERSISTENCE_PROMPT.md 全文（本包已含所需约束）、禁止来源（BuhoReverseNotes、LaunchBetter、2026-08-25-buho-launchpad-reverse）。

## 4. DragSession 公开 API 摘要（Main 提取，权威）

- `DragSessionController`（final class）：`state: DragSessionState`（.idle/.pressed/.dragging/.edgeTurnPending）、`activeTransaction: DragTransaction?`、`lastOutcome: DragSessionOutcome?`、`edgeDwellDeadline: TimeInterval?`、`lastIntent: DropIntent`、`moveOutArmed: Bool`；`init(parameters: DragParameters = .default, clock: DragClock = SystemDragClock())`；`pointerDown(at: DragPoint, source: DragSourceIdentity, layoutGeneration: LayoutGeneration, catalogGeneration: UInt64, geometry: DragGeometry) -> [DragSessionEvent]`；`pointerMoved(to: DragPoint, geometry: DragGeometry) -> [DragSessionEvent]`；`edgeTimerFired(geometry: DragGeometry, now: TimeInterval) -> [DragSessionEvent]`；`pointerUp(at: DragPoint, geometry: DragGeometry) -> [DragSessionEvent]`；`cancel(reason: DragCancelReason) -> [DragSessionEvent]`。
- `DragTransaction`：`opaqueToken: UInt64`、`scope: DragScope`（.topLevel/.folder(FolderID)）、`sourceIdentity: DragSourceIdentity`（.app(PersistentAppReference)/.folder(FolderID)）、`layoutGeneration: LayoutGeneration`、`catalogGeneration: UInt64`。`DragTokenFactory.makeToken()`。
- `DropResolver`：`init(transaction:)`、`mutating consume(token: UInt64, intent: DropIntent, layoutGeneration: LayoutGeneration, catalogGeneration: UInt64) -> DropResolution`（.accepted/.rejected(DropRejectionReason)/.noOp）。
- `DropIntent`：.invalid/.insertion(Int)/.createFolder/.intoFolder(FolderID)/.moveOut(Int)/.reorder(Int)。
- `DropZoneBuilder.zones(itemFrames: [DragItemFrame], topLevelFrames: [DragItemFrame], containerWidth: Double, page: Int, pageCount: Int, parameters: DragParameters) -> DropZones`；`DropZoneClassifier.classify(pointer: DragPoint, zones: DropZones, source: DragSourceIdentity, moveOutArmed: Bool) -> DropIntent`。
- `DragMutationEngine.apply(intent: DropIntent, layout: PersistentWorkspaceLayout, source: DragSourceIdentity, target: DragItemIdentity?, generation: LayoutGeneration) -> LayoutMutationResult`（.applied(LayoutMutation)/.rejected/.noOp）。
- `EdgePagingScheduler`（struct）：`currentZone: EdgeZone?`、`dwellArmed: Bool`、`lastTurnTime: TimeInterval?`；`mutating update(pointer: DragPoint, geometry: DragGeometry, now: TimeInterval) -> [EdgePagingEvent]`；`mutating dwellElapsed(now: TimeInterval, geometry: DragGeometry) -> [EdgePagingEvent]`；`mutating cancel() -> [EdgePagingEvent]`；`nextDwellDeadline(after:)`。EdgePagingEvent：.enter(EdgeZone)/.leave/.dwellArmed/.turn(EdgeZone)/.dwellCancelled。
- `DragGeometry`：`itemFrames: [DragItemFrame]`、`topLevelFrames: [DragItemFrame]`、`containerWidth: Double`、`page: Int`、`pageCount: Int`；`DragItemFrame(identity: DragItemIdentity, frame: DragRect)`；`DragItemIdentity`：.app(PersistentAppReference)/.folder(FolderID)/.member(FolderID, PersistentAppReference)。
- `DragParameters.default`：dragStartThresholdPT、edgeDwellDurationMs、edgeZoneWidthPT、edgeHysteresisPT、dropZoneMarginsPT、overlayMoveOutArmThresholdPT、edgeTurnMinIntervalMs、maxDragPreviewScale。**参数来源类别 = 本阶段独立设计（ADR-010 决策），Main 合并后记入 PARAMETER_RATIONALE.md（Worker 不写 Docs）。**
- `DragSessionEvent`：.stateChanged/.intentChanged/.edge(.edgePagingEvent)/.commit(.committed/.noOp/.rejected)/.cancelled(DragCancelReason)。`DragCancelReason`：.escape/.resign/.refresh/.search/.titleEdit/.teardown/.secondDrag/.invalidTarget/.overlayClosed/.storeFailure。

## 5. 实现要求

### 5.1 统一输入仲裁（硬门）
- pointer-down 只进 `pressed`；越过 dragStartThresholdPT 进 `dragging`；mouse-up 未越阈值才派发既有 click/open/launch（app 启动、folder 打开、空白点击两段式不变）。
- 顶层 cell、folder member、空白点击必须走同一 coordinator 仲裁，避免双重识别。拖拽 app 绝不启动；拖拽 folder 绝不打开。
- 与既有 NSClickGestureRecognizer 协调：drag 期间抑制 click 派发（如 threshold 判定后取消 gesture 或 coordinator 标记 consumed）。

### 5.2 拖拽源/目标
- 顶层 cell 与 folder member 均可作源；顶层 cell、folder cell、folder 内成员区、overlay 外（move-out）均可作目标。
- 几何：coordinator 从视图层收集 DragItemFrame（cell frame 转 DragRect，containerWidth = 表面宽度），每次 pointerMoved 重建 DragGeometry（有界计算，禁全树重建）。
- drop 消费：DropResolver.consume 验证 token/layoutGeneration/catalogGeneration/target 存在/session 未取消未消费；拒绝外部 payload（本实现无 pasteboard，天然满足）与重复 drop。
- commit：`DragMutationEngine.apply` 成功后经 `onCommit: (PersistentWorkspaceLayout) -> Void` seam 交出新布局（T-1F-E 接 provider/persist）；D1 测试用 spy 验证。commit 后 coordinator 复位。

### 5.3 边缘翻页
- 顶层 scope：edge turn 只调用已接受外层分页入口 `KeyboardPageTurner(surface:).turn(direction:timestamp:)`（KeyboardFocusController 同款用法），**不得直接写 visualOffset**。
- folder scope：只调 FolderOverlayView 的 nextPage()/prevPage()（或等价 onInnerPageChange seam），不触发外层分页。
- 每次 turn 后重新 hit-test 与重新验证 token/generation；到全局首尾页不越界（EdgePagingScheduler 已保证）；ESC/mouseUp/resign/refresh/teardown 取消 edge turn；edge timer 过期零写回。

### 5.4 move-out 模式
- folder overlay 打开时只允许 member drag；指针进入 overlay 边缘区（overlayMoveOutArmThresholdPT）→ moveOutArmed；drop 到 overlay 外 → .moveOut 意图 → 引擎 move-out mutation。取消/离开复位。

### 5.5 统一 cancel（全路径零写盘、零残留）
- ESC、window resign、app resign active、refresh 到达、进入搜索、标题编辑开始、overlay/window close、teardown、第二次 drag 开始 → `cancel(reason:)`；清理 preview/插入指示/edge timer；拒绝旧 callback；已提交布局不变；焦点回合法身份或文档化 fallback。
- Command-F 在 drag 中先 cancel 再进搜索；搜索 active 时禁拖；标题编辑 active 时不开始 drag。

### 5.6 视觉（中性、独立设计）
- 不复制 Buho/LaunchBetter 的 drag ghost/spring-open/缩放/阴影/颜色/间距/动画。insertion 与 create-folder 目标视觉可区分；不只用颜色表达合法/非法。Reduce Motion（NSWorkspace.shared.accessibilityDisplayShouldReduceMotion）下禁不必要大缩放/飞行动画。preview 不进资源/报告，不含真实 app 截图。

### 5.7 热路径
- drag move 热路径禁磁盘写/JSON encode/catalog scan/Bundle 读/图标同步解码/全 view tree 重建/无界 O(n²)/同步等 actor。允许内存 hit-test、局部 preview 更新、纯 mutation 预演。

## 6. 测试要求

- `Tests/AppGridUITests/DragUISessionCoordinatorTests.swift`：几何构建（cell frame → DragItemFrame 映射）、move-out 模式状态机、阈值仲裁决策、cancel 全路径（各 DragCancelReason）、commit seam 调用与复位、edge turn 入口选择（topLevel→KeyboardPageTurner seam / folder→overlay seam，用 seam 注入验证）。
- `Tests/PagingUITests/DragUIIntegrationTests.swift`（seam 驱动，参照 FolderIntegrationTests 模式）：app click 仍启动 / drag app 绝不启动；folder click/Return 仍打开 / drag folder 绝不打开；空白点击两段式不变；搜索 active 禁拖；Command-F 先 cancel 再搜索；标题编辑禁拖；folder 内 drag 不动外层页；跨页 drop 更新可见内容与焦点（seam 层验证）；source/target cell 复用零 stale apply；teardown 零 gesture/session/timer/store callback；Reduce Motion 分支。
- 隐私：仅中性 fixture 数据（fixture.alpha/beta、'Group 1'、固定 UUID）；无真实 app 名/bundle ID/路径。
- 验证（串行，项目根）：`swift build -c debug` exit 0；`swift test` 全量（基线 972，新增全绿，既有不回归；写范围外失败如实报告不修改）；`swift build -c release` exit 0。

## 7. 红线

- 无 git 操作；不读禁止来源；隐私中性（app 名/bundle ID/路径/URL/搜索词/folder 标题/成员/图标数据绝不进 telemetry/JSONL/stdout/报告，仅中性计数器）；不改冻结树；不写 Docs/PROVENANCE（Main 交付物）；不新增第三方依赖；Apple 系统框架使用记录公开 API 与最低系统版本。

## 8. 输出纪律

- 先写 `Workflow/results/T-1F-D1-appkit-drag-ui.md`（"Status: in progress"）再实现；完成后更新为 Status: PASS + 文件清单 + 测试数 + 验证证据。
- 回复 <250 词，无大代码块。
