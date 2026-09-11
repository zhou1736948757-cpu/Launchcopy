# T-1F-D1-fix-planning — Chief 规划：D1 拖拽实机缺陷修复任务包

Status: in progress
Created: 2026-08-31 (Main)
Role: Chief（规划者，不实现）
Deliverable: 详细修复任务包（一个或多个 Workflow/tasks/T-1F-D1-fix-*.md），供 Worker 直接执行

## 背景

Phase 1F（拖拽编排+文件夹变更+本地持久化）T-1F-D1（AppKit 拖拽 UI）已合并（997/0 基线）。
用户实机验收报告 4 个缺陷（逐字，中文）：

> "首先第一个，在主面板，拖动软件的话，拖动软件的时候，拖动的过程当中，指针上面会显示这个软件的名字，但是实际上应该是这个软件的图标和名字一起的那个小块能够移动。然后其次在拖动以后，好像是不生效的。而且不管是改变顺序的拖动，还是形成Folder拖动，都不生效。并且在拖动完以后，这两个就是应用，就比如说我把A应用移到B应用上面，让它形成Folder嘛。移了以后，实际上没有形成Folder，然后A B应用的位置也没有改变，然后A B这两个应用点击也没有反应。然后移动位置的话，比如说我想把A应用移到B应用的右边，那我在移动以后的话，AB应用也是没有反应，然后A应用的话，点击也是没有反应的。然后在这个Folder里面的话呢，完全按了就是没有反应。我建议你把这个相关的问题直接打包相关信息交给chef，然后让chef去给一个详细的prompt再交给worker，因为我感觉这个问题比较难。"

## Main 只读诊断证据（已确认，供 Chief 引用）

### 缺陷 1：拖动时指针只显示 app 名字文本，期望整个 cell 块（图标+名字）移动
- Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift handleEvents `.dragBegan` 分支：`visuals.showPreview(title: sourceCell?.boundName, at: ...)` — 只传标题字符串。
- Sources/AppGridUI/DragUI/DragUIVisuals.swift showPreview(title:at:) :46-61：小圆角矩形（cornerRadius 12、controlBackgroundColor、borderWidth 1、separatorColor、shadow）+ previewLabel（NSTextField labelWithString，:23）仅显示文本；无图标。previewView :22 是裸 NSView。
- 期望：preview 显示源 cell 的视觉副本（图标+名字小块）。修复方向：快照源 cell（dataWithPDF(inside:) / cacheDisplay）或构建迷你 cell 视图（iconView+label）。

### 缺陷 2：拖动不生效（reorder 与 createFolder 均无效）
- Sources/PagingPrototypeApp/AppDelegate.swift :547-549 `coordinator.onCommit = { [weak self] newLayout in self?.sessionLayout = newLayout }` — 注释 "T-1F-E 接 provider/persist"。
- 根因：commit 只暂存 sessionLayout，从未应用到 provider/渲染 → 网格永不重渲染 → 顺序不变、不建文件夹。这是 T-1F-E 集成工作（drag commit → provider presentation → focus reconcile → async persist）尚未做。
- 注意：LayoutStore（T-1F-B，Sources/AppGridUI/LayoutStore/）已构建并测试（LayoutStore 协议：load/enqueue/flush/reset/currentState/lockMode/staleRejectionCount；ApplicationSupportLayoutStoreDirectory "PagingPrototypeLayout"）——persist 可直接接线。
- 相关：AppDelegate applyPresentationUpdate :629+（cancel(.catalogRefresh) + surface.refreshPresentation + setPageCount + telemetry + 焦点布局重建）是既有呈现提交统一出口；applyPendingAtIdleBoundary :660+ 是 idle 边界统一提交。

### 缺陷 3：拖动后 app 点击无反应
- Sources/AppGridUI/DragSession/DragSessionController.swift pointerDown :170-176：`if state != .idle { events += cancel(reason: .secondDrag) }; guard let source else { return events }; guard sourcePresent(source, in: layout) else { return events }` — stale source 拒绝会**吞掉点击**（无 .pressed → 无 .clicked → 无派发）。
- sourcePresent :263-271：.topLevelApp → layout.topLevelOrder 含 .app(ref)；.topLevelFolder → 含 .folder(id)；.folderMember → layout.folder(id:)?.members.contains(ref)。
- 机制（createFolder 场景）：A 拖到 B 上 → commit → sessionLayout 暂存（A+B 已进新文件夹）→ 用户点击 A（顶层 cell）→ pointerDown 传 layoutProvider() = sessionLayout → sourcePresent(.topLevelApp(A), in: sessionLayout) = false → 点击被吞。B 同理。**与用户报告"A B 这两个应用点击也没有反应"完全吻合**。
- 附带：可见网格与 layout 因缺陷 2 未修复而持续分叉。
- 修复方向（Chief 定夺）：点击路径不应被 stale-source 守卫吞掉（click 与 drag 解耦），或 layout 与可见网格保持同步（缺陷 2 修复后自然缓解），或 pointerDown 对 click 场景放宽。

### 缺陷 4：Folder 内完全没反应（成员点击不激活、成员拖拽不工作）
- Sources/AppGridUI/FolderOverlayView.swift mouseDown :267-283：面板内成员 cell → `coordinator.pointerDown(locationInWindow: sourceCell: cell, memberFolderID: currentEntry?.id)`；面板内非成员区 → return（忽略）；面板外 → pointerDown(sourceCell: nil, memberFolderID: nil)。
- FolderOverlayView.hitTest :296-300：除 prev/next 按钮外全部返回 self → overlay 的 mouseDown 应接管成员点击（成员 cell 自身 mouseDown 不触发）。
- Sources/AppGridUI/AppGridCellView.swift mouseDown :184-186：`coordinator.pointerDown(sourceCell: self, memberFolderID: nil)`（不调 super）。
- resolveSource（DragUISessionCoordinator.swift :322-345）：memberFolderID 非 nil → cell.bindingToken?.appID as? AppID → appReference(for:) → .folderMember(folderID, app)；否则 isFolderCell → .topLevelFolder；否则 .topLevelApp。
- makeSessionLayout :378-400：folders 从 servedFolderSnapshot 构建（members 从 catalog 解析）→ .folderMember 的 sourcePresent 理论上应通过。
- **未决疑点（Worker 需验证）**：成员 cell 的 bindingToken 是否设置（overlay makeMemberCell 是否绑定）；currentEntry?.id 是否非 nil；servedFolderSnapshot 是否非 nil；成员点击的 .clicked → dispatchClick → onCellClick → AppDelegate handleDragCellClick :612-623（app cell → folderOpenState?.isOpen == true ? launchMember(appID) : launchController?.handleCell(cell)）是否正常。
- 用户原话"完全按了就是没有反应"——需确认成员点击是否连文件夹关闭/激活都无反应（若 resolveSource 返回 nil → pendingBlankPress → 未过阈值 mouseUp → onOverlayBlankClick → closeFolder，用户应看到文件夹关闭；用户说无反应，说明可能连 overlay mouseDown 都没到或 coordinator 未收到）。

### 其他相关事实
- Coordinator pointerUp :152-179：.pressed → click 路径（空几何 + layoutProvider() ?? emptyLayout）；.dragging → geometryProvider(scope) + layoutProvider()，失败 → cancel(.teardown)。
- handleEvents :225-270：.clicked → dispatchClick + endSession；.committed → onCommit + endSession；.cancelled(.secondDrag) → 清视觉/计时、保持仲裁、不 endSession。
- dispatchClick :294-299：sourceCell → onCellClick(cell) 否则 onOverlayBlankClick。
- AppDelegate installDragUI :525-575：coordinator(host: surface)、shared、layoutProvider（sessionLayout ?? makeSessionLayout(catalog:servedSnapshot, entries:presentationEntries, folderSnapshot:servedFolderSnapshot)）、catalogGenerationProvider（servedRevision）、catalogSnapshotProvider（servedSnapshot）、geometryProvider（makeDragGeometry :581+：topLevel → pageView.dragItemFrames(convertedTo: host, catalog:)；folder → overlay.memberDragItemFrames + state.innerPage/innerPageCount + topLevelFrames）、onCellClick（handleDragCellClick）、onOverlayBlankClick（closeFolder）、topLevelPageTurn（KeyboardPageTurner.turn）、folderPageTurn（overlay prevPage/nextPage）、clickRecognitionSuppressor（surface.gestureRecognizers 中 NSClickGestureRecognizer isEnabled）、dragGate（search.isSearchActive / isTitleEditing）。
- 基线 997/0（swift test 全量）；debug/release 双构建 exit 0；冻结树（PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/PagingUI/Package.swift/AppLaunchController.swift）绝不修改；无 git 操作；隐私红线（app 名/bundle ID/路径/URL/搜索词/文件夹标题/成员/图标数据绝不进 telemetry/JSONL/stdout/signpost/profile/report，仅中性计数器）。

## Chief 交付要求

1. 产出 1-2 个详细修复任务包（Workflow/tasks/T-1F-D1-fix-*.md），每个包自包含：根因、修复规格（文件级+函数级）、写范围、禁止写、必读文件清单、验证步骤、验收标准、输出纪律。
2. 建议拆分（Chief 定夺）：(a) T-1F-E1 集成（onCommit → provider 呈现提交 + 焦点调和 + LayoutStore persist）——这是缺陷 2 的修复，也是缺陷 3 缓解的前提；(b) D1 修复（preview cell 快照 + 点击不被吞 + folder 内成员拖拽/点击验证修复）。
3. 每个包写范围必须最小化且互斥（若拆两包，AppDelegate.swift 重叠 → 串行波次）。
4. 明确验证：swift build -c debug exit 0、swift test 全量（基线 997 新增全绿既有不回归）、swift build -c release exit 0；写范围外失败如实报告不修改。
5. 输出纪律：Worker 先写结果文件 in-progress、回复 <250 词无大代码块。
6. 隐私/冻结树/无 git 红线同前。

## 验收

Chief 结果文件 Workflow/results/T-1F-D1-fix-planning.md 含：任务包清单（路径）、每个包的根因摘要+修复规格要点、波次顺序建议、风险与未决疑点。Main 据此派发 Worker。
