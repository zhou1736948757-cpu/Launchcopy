# T-1F-C-tests-drop — DropResolver/DropIntent/DragMutationEngine 测试编写

## 背景
T-1F-C（DragSession）Worker 在完成源码后因上下文耗尽中断，测试文件未写。编译修复（T-1F-BC-compile-repair）已合并，基线 837/0。本任务只写 drop 组件测试（resolver/zones/classifier/engine），不写 session 状态机测试（T-1F-C-tests-session 负责）、不写 edge 测试（T-1F-C-tests-edge 负责）、不改源码。

## 任务
新建 `Tests/AppGridUITests/DragDropTests.swift`，覆盖 drop 组件测试矩阵（见下）。**必须使用现有 `Tests/AppGridUITests/DragSessionTestSupport.swift` 的工厂**（FakeDragClock、makeDragLayout、ref、rowFrames、appFrame、folderFrame、topLevelGeometry、folderGeometry、assertContains）。

## 只读范围（仅此 8 文件，不要读其他文件）
- `Sources/AppGridUI/DragSession/DropResolver.swift`
- `Sources/AppGridUI/DragSession/DropIntent.swift`（DropIntent/DropZones/DropZoneBuilder/DropZoneClassifier/AppCenterZone/FolderCellZone）
- `Sources/AppGridUI/DragSession/DragMutationEngine.swift`
- `Sources/AppGridUI/DragSession/DragTransaction.swift`（DragTransaction/DragScope/DragSourceIdentity）
- `Sources/AppGridUI/DragSession/DragGeometry.swift`（DragPoint/DragRect/DragItemFrame/DragGeometry）
- `Sources/AppGridUI/DragSession/DragParameters.swift`
- `Sources/AppGridUI/LayoutDomain/PersistentWorkspaceLayout.swift`（布局构造 + LayoutMutation）
- `Tests/AppGridUITests/DragSessionTestSupport.swift`（工厂，必用）

## 公开 API 摘要（Main 已提取）
- `DropResolver`：`public let transaction: DragTransaction`；`public private(set) var consumed: Bool`；`public init(transaction:)`；`public mutating func consume(token: UInt64, intent: DropIntent, layout: PersistentWorkspaceLayout, catalogGeneration: UInt64) -> DropResolution`（.accept(intent) / .reject(DropRejectionReason)）；拒绝路径：invalidToken / tokenConsumed / staleLayout / staleCatalog / sourceMissing / targetMissing / invalidDropTarget
- `DropIntent`：`.insertion(index: Int)` / `.createFolder(target: PersistentAppReference)` / `.intoFolder(target: FolderID, at: FolderInsertionPosition)` / `.topLevelTarget(index: Int)` / `.invalid`
- `DropZoneBuilder.zones(itemFrames: [DragItemFrame], topLevelFrames: [DragItemFrame], containerWidth: Double, moveOutArmed: Bool, parameters: DragParameters) -> DropZones`（insertion 带：首条目前/相邻间/末条后；app 中心区；folder cell 区；顶层落点区仅 moveOutArmed 时产出）
- `DropZoneClassifier.classify(pointer: DragPoint, source: DragSourceIdentity, zones: DropZones) -> DropIntent`（folder 源：folder-on-folder/app-on-folder 一律 .invalid；app 源：中心区 → .createFolder（排除源自身）；insertion vs create-folder 区分；move-out 落点）
- `DragMutationEngine.apply(intent: DropIntent, source: DragSourceIdentity, layout: PersistentWorkspaceLayout) -> LayoutMutationResult`（M1 顶层 app 重排 / M2 顶层 folder 重排 / M3 createFolder / M4 intoFolder 含跨 folder 原子 move / M5 move-out；同一引擎；拒绝时原布局不变、无半提交）

## 测试矩阵（Prompt §10.1 drag 部分）
1. **consume 接受**：合法 token+合法 intent → .accept(intent)、consumed = true。
2. **consume 拒绝**：错误 token → .invalidToken；二次消费 → .tokenConsumed；layout generation 过期 → .staleLayout；catalogGeneration 过期 → .staleCatalog；source 已不在布局 → .sourceMissing；target 缺失 → .targetMissing；.invalid intent → .invalidDropTarget。
3. **zones 构造**：insertion 带首/中/末三区几何正确；app 中心区；folder cell 区；moveOutArmed=false 无顶层落点、true 有。
4. **classify 分类**：app 源中心区 → .createFolder（源自身中心 → 非 createFolder）；insertion 带 → .insertion(index)；folder 源落 folder/app 中心 → .invalid；move-out 落顶层目标 → .topLevelTarget(index)（以源码为准）。
5. **engine 5 类 mutation**：M1 顶层 app 重排 / M2 顶层 folder 重排 / M3 createFolder（目标+源为初始成员，先目标后源）/ M4 intoFolder（含跨 folder 原子 move）/ M5 move-out——每类验证新布局正确、generation +1。
6. **engine 拒绝**：stale/非法 target/将破坏不变量 → 拒绝、原布局不变、无半提交（以源码 LayoutMutationResult 为准）。

## 写范围（仅此 1 文件）
- `Tests/AppGridUITests/DragDropTests.swift`（新建）

## 禁止
- 不改任何源码文件（DragSession/ 全部 9 文件、LayoutDomain/、冻结树一律不动）。
- 不写 session 状态机测试 / edge 测试（其他任务负责）。
- 不读禁止来源；无 git 操作；隐私红线（中性假数据，fixture 标题如 "app1"）。

## 验证（必须全部通过）
1. `swift build -c debug` exit 0。
2. `swift test` 全量：期望 837 + 新增全绿、0 failures（写范围外失败如实报告、不修改）。
3. `swift build -c release` exit 0。

## 输出纪律
- 先写 `Workflow/results/T-1F-C-tests-drop.md`（状态 in progress + 计划），再动手。
- 完成后更新结果文件：测试文件路径、测试数、3 项验证输出、Status: PASS。
- 回复 <250 词，无大代码块。
