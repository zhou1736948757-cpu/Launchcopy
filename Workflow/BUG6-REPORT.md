# Bug 6 报告：拖拽交互缺陷（Phase 1F D1 波次实机验收）

- 状态：待 Ops 审查
- 报告人：用户（实机全屏验收）
- 阶段：Phase 1F（拖拽编排 + 文件夹变更 + 本地持久化），D1 波次（AppKit drag UI）已合并
- 测试基线：1012/0（swift test 全量通过）
- 本报告用途：把问题与上下文条件完整列出，供 Ops 决策修复方案

---

## 1. 用户逐字报告（原文）

> "Bug多的我有点受不了了。首先第一个，比如说把A软件移动到B软件上面，形成一个这个Folder对吧？那这个Folder应该在B软件上这个位置形成，而不是在A软件这个位置形成。其次，我不知道为什么，反正我是先把这A软件移到B软件上形成这个Folder，形成Folder以后呢，就是这其他的软件可以拖动改变位置，但是打开不了，而点击空白处也退出不了。然后改变移动位置的话也有bug，就比如说我想把A软件移动到B软件的后面，对吧？也就是想，也就是说想把A软件移动到B软件的右边这个位置。那这时候的话，我如果说把A软件移动到B软件右边这位置的话，它不会显示这个，如果在边边上，就是在这个边缘上面的话，它不会显示这个蓝条。如果说想做到的话，会要需要把这个软件放到这个B软件的左边一点点，然后它会在B软件左边这个地方显示一个蓝条，然后就可以放过去，然后放过去这两个软件就会交换位置。然后还有就是在Folder里面的话，我不知道为什么，就是首先我是创造了一个新的Folder嘛，然后里面只有AB两个软件，然后A在左边B在右边，然后我用三指拖动A软件的时候呢，是直接鼠，直接鼠标就是直动不了了，然后到B软件上呢，怎么拖都没有反应。Bug有点太多了，你可以去看一下LaunchBatter里面是怎么实现的，然后再看一下我们怎么实现的，然后给出一个修复的plan，然后让chef去做。"

> 注：用户建议参考 LaunchBetter 实现——**该来源为项目红线禁止来源**（license route B：独立实现，绝不读 BuhoReverseNotes / LaunchBetter / 2026-08-25-buho-launchpad-reverse）。用户描述的行为期望本身即为规格，全部可在用户可观察结果层面独立实现，不依赖禁止来源。

---

## 2. 缺陷清单（4 项）

### 缺陷 1：createFolder 位置错误（folder 应在目标 B 的位置形成）

- **复现**：把 A 软件拖到 B 软件上 → 形成 Folder。
- **期望**：Folder 在 **B（drop 目标）** 的位置形成。
- **实际**：Folder 在 **A（被拖源）** 的位置形成（两 app 原位置区间内的 min 原 index）。
- **代码**：`Sources/AppGridUI/LayoutDomain/LayoutMutation.swift:94-126` `createFolder(in:target:source:title:folderID:)`
  - `:116-122`：`let first = min(targetIndex, sourceIndex); let second = max(targetIndex, sourceIndex); ordered.remove(at: second); ordered.remove(at: first); let insertion = min(first, ordered.count); ordered.insert(.folder(id), at: insertion)`
  - 头注释 `:14`："新 folder 落在两原位置区间内（min 原 index）"——与用户期望（目标位置）不符。
- **影响**：用户视觉上 folder 出现在 A 的位置而非 B 的位置。

### 缺陷 2：创建 Folder 后，其他软件打不开 + 空白点击退不出

- **复现**：先拖 A 到 B 上形成 Folder 之后。
- **实际**：
  - 其他软件**可以拖动改变位置**（重排生效）。
  - 但**点击打不开**（不启动 / 不打开）。
  - **点击空白处也退出不了**。
- **相关代码**（点击/空白点击路径）：
  - `Sources/PagingPrototypeApp/AppDelegate.swift:640-654` `handleDragCellClick(_:)`：folder cell → `handleFolderCellClick`；app cell → folder 打开中 `launchMember`，否则 `launchController?.handleCell(cell)`。
  - `AppDelegate.swift:578-580`：`coordinator.onCellClick = handleDragCellClick`。
  - `AppDelegate.swift:581-583`：`coordinator.onOverlayBlankClick = closeFolder`。
  - `AppDelegate.swift:1000+` `QuitOnBlankClickWindow`：`sendEvent` 拦截空白点击（`blankClickResolvesToCell` 判定）。
  - `AppDelegate.swift:663-681` `applyPresentationUpdate`：新呈现提交 → `dragCoordinator?.cancel(reason: .catalogRefresh)` + `surface.refreshPresentation()` + `setPageCount` + 焦点布局重建。
  - `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift:103-137` `pointerDown`：stale-source（提交后布局已移动源）→ `clickFallbackCell` 武装（`:131-135`）；`:176-224` `pointerUp`：fallback 未过阈值 → `onCellClick(fallback)`。
- **状态**：根因**未完全定位**（疑点见 §4）。

### 缺陷 3：插入蓝条位置（A 移到 B 右边不显示蓝条）

- **复现**：想把 A 移到 B 的右边（B 后面）。
  - A 放到 **B 右边** → **不显示蓝条**。
  - A 放到 **B 左边一点点** → B 左边显示蓝条 → 放过去 → 两软件**交换位置**。
- **期望**：A 移到 B 右侧应显示 **B 右侧的插入蓝条**（insert after B）。
- **实际**：B 右半区域（B 的中心 strip 内）→ 命中 `appCenterZone` → **createFolder 意图**（显示 create-folder 指示，非蓝条）；只有指针进入条目间 gap 区才命中 insertion 带。
- **代码**：`Sources/AppGridUI/DragSession/DropIntent.swift`
  - `:74-155` `DropZoneBuilder.zones`：insertion 带 = 首条目前（`x:0 → first.minX+margin`）/ 末条目后（`x:last.maxX-margin → containerWidth`）/ 相邻条目间（`x:a.maxX-margin → b.minX+margin`）；`appCenterZones` = 每 app 帧**中间 1/3 高度 strip、全宽**（`:107-117`）。
  - `:159-209` `DropZoneClassifier.classify`：`.topLevelApp` 源 → **appCenterZone 优先**（命中 → `.createFolder`，`:174-179`）→ folderCellZone → insertionIntent。
- **影响**：用户无法直观地把 A 插到 B 后面；B 右半被 createFolder 语义占据。

### 缺陷 4：Folder 内三指拖动成员无反应

- **复现**：创建新 Folder（仅 A、B 两成员，A 左 B 右），打开 Folder，**三指拖动 A**。
- **实际**：鼠标（指针）"直动不了了"；拖到 B 上怎么拖都没反应。
- **相关代码**（folder 内成员拖拽链路）：
  - `Sources/AppGridUI/FolderOverlayView.swift:267-284` `mouseDown`：面板内成员 cell → `coordinator.pointerDown(locationInWindow:sourceCell:memberFolderID: currentEntry?.id)`；面板外 → `pointerDown(sourceCell: nil)`。
  - `FolderOverlayView.swift:286-289` `mouseDragged` → `coordinator.pointerDragged`；`:291-294` `mouseUp` → `coordinator.pointerUp`。
  - `FolderOverlayView.swift:297-303` `hitTest`：除 prev/next 按钮外全返回 self（成员 cell 自身不接收事件）。
  - `AppDelegate.swift:619-633` `makeDragGeometry(.folder)`：`overlay.memberDragItemFrames` + `state.innerPage/innerPageCount` + 顶层 frames；守卫 `state.isOpen(folderID)`。
  - `DragUISessionCoordinator.swift:368-382` `resolveSource`：`memberFolderID` 非 nil → `cell.bindingToken?.appID as? AppID` → `appReference(for:)` → `.folderMember(folderID:app:)`。
  - `Sources/AppGridUI/DragSession/DragSessionController.swift:62-92` `pointerDown`：`sourcePresent(source, in: layout)` 守卫（`:71`）；`:263-271` `sourcePresent`：`.folderMember` → `layout.folder(id:)?.members.contains(ref)`。
- **状态**：根因**未完全定位**（疑点见 §4）。

---

## 3. 已确认的代码事实（Main 只读诊断证据）

### 3.1 拖拽协调器（`Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift`，446 行）

- `pointerDown` `:103-137`：守卫链 = `isTornDown` → `dragGate()`（搜索激活/标题编辑禁拖）→ `visualHost`（weak）→ `resolveSource`（nil → `pendingBlankPress` 武装）→ `layoutProvider`；`controller.pointerDown` 无 `.pressed` 且 `sourceCell != nil` → `clickFallbackCell` 武装（stale-source 点击回退，缺陷 3 修复波次引入）。
- `pointerDragged` `:140-173`：blank/fallback 过阈值清除；`controller.pointerMoved`；`.dragging` → `visuals.movePreview`；`scheduleEdgeTimerIfNeeded`。
- `pointerUp` `:176-224`：blank 未过阈值 → `onOverlayBlankClick`；fallback 未过阈值 → `onCellClick(fallback)`；`.pressed` → click 路径（空几何）；`.dragging` → drop 解析（geometry/layout 守卫失败 → `cancel(.teardown)`）。
- `handleEvents` `:264-304`：`.committed` → `onCommit(newLayout)` + `endSession`；`.cancelled(.secondDrag)` 保持仲裁；其余 → `endSession`。
- `endSession` `:348-364`：恢复 click 识别（`setClickRecognitionEnabled(true)` + `clickRecognitionSuppressor?(true)`）、清状态/视觉/edge timer。
- `resolveSource` `:368-382`：`.topLevelApp` / `.topLevelFolder` / `.folderMember`（经 `catalogSnapshotProvider` 解析 `PersistentAppReference`）。
- `DragUISessionLayoutFactory.makeSessionLayout` `:424-445`：顶层顺序 = 呈现条目顺序；folder 成员经 catalog 记录解析（不在 catalog 的成员跳过）。

### 3.2 纯域（`Sources/AppGridUI/LayoutDomain/` 与 `Sources/AppGridUI/DragSession/`）

- `LayoutMutation.swift`（315 行）：
  - `reorderTopLevel` `:68-84`（remove at fromIndex + insert at clamped；无位移 → noOp）。
  - `createFolder` `:94-126`（见缺陷 1；`target != source` 否则 `.duplicateReference`；任一已在 folder → `.nestedFolder`；标题 `Group N` 最小未用 N）。
  - `addToFolder` `:142-169`（顶层 app 移入 / 跨 folder 原子 move；已是成员 → noOp）。
  - `moveOutOfFolder` `:176-213`（剩 1 → 原子 dissolve；剩 0 → 删 folder）。
  - `reorderFolderMembers` `:218-240`。
  - `renameFolder` `:247-262`。
- `DropIntent.swift`（210 行）：`DropIntent` 五态（insertion/createFolder/intoFolder/topLevelTarget/invalid）；`DropZoneBuilder.zones` 与 `DropZoneClassifier.classify`（见缺陷 3）。
- `DragMutationEngine.swift`（58 行）：5 类 mutation 统一引擎，全部经 `LayoutMutation(expectedGeneration:)` 单一写入口。
- `DragSessionController.swift`：状态机 `idle→pressed→dragging/edgeTurnPending→commit|cancel→idle`；`sourcePresent` 守卫 `:71`。

### 3.3 装配层（`Sources/PagingPrototypeApp/AppDelegate.swift`，1074 行）

- `installDragUI` `:534-604`：`layoutProvider`（`sessionLayout ?? makeSessionLayout(catalog:entries:folderSnapshot:)`）、`catalogGenerationProvider`（servedRevision）、`catalogSnapshotProvider`（servedSnapshot）、`geometryProvider`（makeDragGeometry）、`onCommit`（sessionLayout 暂存 + `provider.applyCommittedLayout` + `applyPresentationUpdate(update, overridePageCount: true)` + 异步 `layoutStore?.enqueue`）、`onCellClick`、`onOverlayBlankClick`（closeFolder）、`topLevelPageTurn`（KeyboardPageTurner.turn）、`folderPageTurn`（overlay prev/nextPage）、`clickRecognitionSuppressor`（surface 上 NSClickGestureRecognizer isEnabled）、`dragGate`（search.isSearchActive / isTitleEditing）。
- `makeDragGeometry` `:608-634`：topLevel → 当前页 `pageView.dragItemFrames`；folder → `overlay.memberDragItemFrames` + `state.innerPage/innerPageCount` + 顶层 frames；守卫 `state.isOpen(folderID)`。
- `handleDragCellClick` `:640-654`（见缺陷 2）。
- `applyPresentationUpdate` `:663-681`：`dragCoordinator?.cancel(reason: .catalogRefresh)` → `surface.refreshPresentation()` → `setPageCount` → telemetry → 焦点布局重建（`AppGridFocusLayout.build(from:composition:itemsPerPage:)`）。
- `applyPendingAtIdleBoundary` `:687-703`：cancel(.catalogRefresh) → 搜索提交优先 → folder 组合重建 → refreshController.applyPending → 键盘跨页 settle 调和。
- `QuitOnBlankClickWindow` `:1000+`：`sendEvent` 每次真实 mouseDown 评估命中；`onDragActiveCancel`（`:239-242`，isSessionActive 时 cancel 并吞事件）、`onEscapeDuringDrag`（`:244-248`）；`blankClickResolvesToCell` `:1061`。

### 3.4 文件夹打开层（`Sources/AppGridUI/FolderOverlayView.swift`，452 行）

- `mouseDown` `:267-284` / `mouseDragged` `:286-289` / `mouseUp` `:291-294` 全部转发 coordinator（`dragCoordinator ?? DragUISessionCoordinator.shared`）。
- `hitTest` `:297-303`：除 prev/next 按钮外全返回 self。
- `memberDragItemFrames(convertedTo:catalog:)` `:106-116`：成员 cell frame → DragItemFrame（bindingToken → catalog 解析）。
- `memberToken` `:356-367`：`appID: AnyHashable(member)`（成员 cell 有 bindingToken）。
- 布局 `layoutPanel` `:420-451`：5 列动态 pitch。

---

## 4. 未确认疑点（需进一步诊断，Ops 决策时参考）

### 缺陷 2 疑点（点击打不开 + 空白点击退不出）

- a) `applyCommittedLayout` 后呈现更新（`applyPresentationUpdate`）重建 cell；新 cell 的 bindingToken / 点击路径是否完好（`handleDragCellClick` 依赖 `cell.bindingToken?.appID`）。
- b) `clickRecognitionSuppressor` 恢复时序：`endSession` 恢复 surface 级 NSClickGestureRecognizer；fallback 路径（`pointerUp` `:190-199`）不调用 `endSession`（但 fallback 路径也未 `beginArbitration`，理论上无抑制残留）。
- c) `QuitOnBlankClickWindow.sendEvent` 空白点击与 coordinator `pendingBlankPress` 的交互：顶层空白点击是否被 coordinator 路径吞掉（`onOverlayBlankClick` 只接 closeFolder，顶层空白退出键盘选择是否仍走窗口层）。
- d) 用户"打不开"的对象：其他 app（launch 失败）还是 folder（open 失败）——复现时需区分。

### 缺陷 4 疑点（folder 内三指拖动无反应）

- a) `makeDragGeometry(.folder)` 返回 nil：`folderOverlay` / `folderOpenState` / `state.isOpen(folderID)` 守卫是否通过。
- b) `sourcePresent(.folderMember)` 失败：`layoutProvider()` 返回的 sessionLayout 中 folder 成员解析（`makeSessionLayout` 依赖 `servedFolderSnapshot` + catalog records）。
- c) 三指拖移事件流：mouseDown 是否到达 overlay（hitTest 返回 self 应保证）；`dragGate()` 是否误判。
- d) 用户"鼠标直动不了了"的精确含义：preview 不出现 / 指针不跟随 / 无任何视觉反馈——复现时需确认。

---

## 5. 约束与红线（Ops 决策与后续任务必须遵守）

- **冻结树（绝不修改）**：`Sources/PagingCore/`、`Sources/AppCatalogCore/`、`Sources/MacAppCatalog/`、`Sources/AppIconPipeline/`、`Sources/PagingTelemetry/`、`Sources/PagingUI/`、`Package.swift`、`Sources/PagingPrototypeApp/AppLaunchController.swift`。
- **流程**：Main 不实现/修复业务代码；每个缺陷 = 新 Workflow 任务包 → Worker 实现 → 独立 Reviewer PASS → 才合并；事件记录经 `record_workflow_event.py`（任务包文件必须先存在）。
- **隐私红线**：报告/telemetry/日志禁真实 app 名、bundle ID、路径、folder 标题、成员列表；本报告用 A/B 代称。
- **禁止来源**：BuhoReverseNotes / LaunchBetter / 2026-08-25-buho-launchpad-reverse 绝不读取；行为期望以用户描述为准独立实现。
- **无 git 操作**（仓库无提交）。
- **测试基线**：1012/0（swift test 全量；debug/release 双构建 exit 0）。
- **Worker 输出纪律**：先写结果文件 in-progress、回复 <250 词、无大代码块。

---

## 6. 建议下一步（供 Ops 决策）

1. 按缺陷拆分修复任务（建议 2 个波次，AppDelegate.swift 共享 → 串行）：
   - 波次 A：缺陷 1（createFolder 位置 → 目标位置）+ 缺陷 3（插入带/中心区几何与分类优先级）。
   - 波次 B：缺陷 2（点击/空白点击）+ 缺陷 4（folder 内拖动），先按 §4 疑点做验证优先诊断再修。
2. 每波次：Chief 规划 → Worker → 独立 Reviewer → 合并 → 重建重启 → 用户实机复测。
3. 修复验收标准（用户可观察结果层面）：
   - 拖 A 到 B 上 → folder 在 B 的位置形成。
   - 拖 A 到 B 右侧 → B 右侧显示插入蓝条，放下后 A 在 B 后面。
   - 形成 folder 后：其他 app 点击正常启动/打开；空白点击正常退出。
   - 打开 folder 后：三指拖动成员可重排；拖到另一成员上/拖出 folder 有正确反应。
