# T-1F-D1-fix-planning — Chief 规划结果

Status: complete
Role: Chief（规划者，不实现）
Baseline: 997/0 tests；swift build -c debug exit 0；swift test 全绿（997 + 新增，无回归）；swift build -c release exit 0

## 任务包清单（2 个，Worker-ready）
1. Workflow/tasks/T-1F-D1-fix-e1-integration.md — Wave 1：drag commit → provider 呈现提交 + 焦点调和 + LayoutStore 异步持久化（用户缺陷 2）
2. Workflow/tasks/T-1F-D1-fix-ui.md — Wave 2：preview 显示源 cell 图标+名称块（缺陷 1）+ 点击不被 stale-source 守卫吞掉（缺陷 3）+ folder 内成员点击/拖拽验证优先修复（缺陷 4）

## 波次顺序（串行）
E1-integration → UI。原因：AppDelegate.swift 共享（E1 改 onCommit/teardownAll；UI 波可能改 handleDragCellClick/launchMember）；E1 先让提交布局驱动网格重渲染，是缺陷 3 的主要缓解，UI 波在其后避免写冲突。

## 根因摘要（已读源码确认）
- 缺陷 2：AppDelegate.swift:547-549 onCommit 仅 `self?.sessionLayout = newLayout`；AppGridUIPageContentProvider 无 apply-layout API（presentationEntries 派生自 TopLevelComposition.build，无法表达 layout.topLevelOrder 任意交错/未分组 app 重排）。
- 缺陷 1：DragUIVisuals.showPreview(title:at:) :46-64 仅 140x56 圆角矩形 + 文本标签；coordinator .dragBegan 只传 boundName。
- 缺陷 3：DragSessionController.pointerDown :71 `guard sourcePresent(source, in: layout) else { return events }` — createFolder 提交后 sessionLayout 已把 A+B 移入 folder，顶层点击 A → sourcePresent=false → 无 .pressed → 无 .clicked。
- 缺陷 4：成员 cell 有 bindingToken（memberToken 设 appID），点击链 FolderOverlayView.mouseDown :267-284 → coordinator.pointerDown(memberFolderID: currentEntry?.id) → resolveSource :329-343 → controller；失败点未静态确认。

## 修复规格要点
- E1：provider 新增 `applyCommittedLayout(_:atCurrentPage:itemsPerPage:) -> AppGridPresentationUpdate?`（layout.topLevelOrder → presentationEntries + layout.folders → servedFolderSnapshot）；onCommit → applyCommittedLayout + applyPresentationUpdate(overridePageCount: true) + `Task { await layoutStore?.enqueue(newLayout) }`（新增 private var layoutStore: LayoutStore?，teardownAll 清 nil）。
- UI：缺陷 1 = DragUIVisuals 新增 showPreview(sourceCell:at:) 迷你 cell 视图（iconView 48pt + nameLabel 11pt，同 AppGridCellView 布局），coordinator .dragBegan 传 sourceCell；缺陷 3 = coordinator 级 clickFallbackCell（controller 无 .pressed 且 sourceCell != nil 时记录，未过阈值 mouseUp → onCellClick，拖过阈值/endSession/cancel/teardown 清除）——纯 controller 与其测试不动；缺陷 4 = 验证优先（bindingToken/currentEntry?.id/servedFolderSnapshot/成员点击链逐环确认）再修，疑点集中在 stale 守卫与 launchMember 静默失败。

## 风险与未决疑点
- 缺陷 4 失败点未确认（Main 未决疑点原样保留）：Worker 必须先验证再修，结果文件须记录证据。
- applyCommittedLayout 的 anchor/remap 语义须与既有 applyPending 一致，避免页面跳变。
- LayoutStore 生产实现（LayoutStoreActor）init 签名未读——Worker 接线时自行确认，不改协议。
- 持久化为异步 enqueue，不阻塞主线程；staleRejection 属正常多实例裁决，不视为失败。
- 隐私红线（中性计数）、冻结树、无 git、无新依赖约束同前。

## 输出纪律
- Worker 写 Workflow/results/<task>.md，回复 <250 词、无大代码块。
