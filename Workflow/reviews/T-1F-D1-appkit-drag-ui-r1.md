# Review: T-1F-D1-appkit-drag-ui (r1)

Verdict: **PASS**

## Verification points

### §5.1 统一输入仲裁硬门（DragUISessionCoordinator.swift + DragSessionController.swift + 视图接线）
- `pointerDown` 只进入 `.pressed`（controller :62-92 硬门；coordinator :99-118 先过 dragGate、空白按下进 pendingBlankPress 仲裁）。mouseDown 绝不启动/打开（AppGridCellView :184-187、FolderOverlayView :267-284 只路由到 coordinator，不调 super）。✓
- 阈值仲裁：`dragStartThresholdPT`（测试参数 6pt）未过阈值保持 `.pressed`，过阈值才 `.dragging` + `.dragBegan`（controller :113-120）。✓
- click 仅 mouse-up 未过阈值派发：controller pointerUp `.pressed` → `.clicked`（:177-180）→ coordinator dispatchClick（onCellClick / onOverlayBlankClick）；`.dragging` 路径绝不派发 click。✓
- drag 绝不启动/打开：集成测试 testAppClickStillLaunchesAndDragNeverLaunches（launcher.opened 恒 1，drag 后仍 1）、testFolderClickStillOpensAndDragFolderNeverOpens（drag folder 后 isOpen false）。✓
- NSClickGestureRecognizer 协调：coordinator beginArbitration 经 clickRecognitionSuppressor 禁用 surface 上全部 NSClickGestureRecognizer，endSession/cancel/teardown 恢复（AppDelegate :563-568；testClickRecognitionSuppressionLifecycle、testCancelAllReasonsLeaveNoResidue 断言 suppression 序列）。✓

### §5.2 源/目标 + 几何 + commit seam
- 源：topLevel app/folder cell（resolveSource 经 catalogSnapshotProvider）、folder member（memberFolderID → .folderMember）；stale source 拒绝（controller sourcePresent :263-272）。✓
- 目标：insertion / topLevelTarget / intoFolder / createFolder / moveOut（DropZoneBuilder + DropZoneClassifier，frozen T-1F-C）；几何每 pointerMoved 构建且 bounded（AppGridPageView.dragItemFrames / FolderOverlayView.memberDragItemFrames 仅遍历 cell；AppDelegate.makeDragGeometry :580-606）。✓
- DropResolver.consume 校验 token/layoutGeneration/catalogGeneration/target/session（controller pointerUp :197-200；双 generation 过期 → cancel，:103-108/:183-188）。✓
- commit 经 onCommit seam 仅存会话内布局（AppDelegate :547-549 `sessionLayout = newLayout`，零磁盘写；T-1F-E 接 provider/persist）。✓

### §5.3 边缘翻页 seam
- topLevel → `KeyboardPageTurner(surface:).turn(direction:timestamp:)`（AppDelegate :556-558；coordinator performPageTurn 用 systemUptime；绝不直接改 visualOffset）。✓
- folder → `FolderOverlayView.nextPage()/prevPage()`（AppDelegate :559-562；overlay :308-314 @objc public → onInnerPageChange）。✓
- turn 后重验：edgeTimerFired 重验双 generation（controller :149-166）；下一 pointerMoved 以新页几何重新 hit-test + intent 分类。✓
- 越界防护：EdgePagingScheduler（frozen T-1F-C 已审）；ESC/mouseUp/resign/refresh/teardown 均 cancel 边缘 turn（cancel 统一出口 + edgeScheduler.cancel）。✓
- 测试：testEdgeTurnTopLevelUsesKeyboardPageTurnerSeam、testEdgeTurnFolderUsesOverlayPageTurnSeam、testCrossPageDropCommitsSeamLevel（40 apps 跨页 turn → committedPage 1 → 新页 drop commit）。✓

### §5.4 move-out
- `overlayMoveOutArmThresholdPT`（测试参数 24pt）→ `moveOutArmed`（controller :123-125，仅 folder scope）；drop 到顶层落点 → topLevelTarget → commit（testMoveOutArmsAndCommitsTopLevelTarget：成员移出到顶层）。✓

### §5.5 统一 cancel（零残留）
- 全路径接线：ESC（window.onDragActiveCancel/onEscapeDuringDrag → cancel(.escape)，AppDelegate :236-245）、resign（windowDidResignKey/applicationDidResignActive → .windowResign，:890/:895）、refresh（applyPresentationUpdate/applyPendingAtIdleBoundary → .catalogRefresh，:638/:662）、search（onSearchShortcut → .searchActivated 先 cancel 再 activateSearch，:420-423）、titleEdit（beginTitleEditing → .titleEditBegan，:772）、overlayClose（closeFolder → .overlayClosed，:714）、teardown（teardownAll → coordinator.teardown() + shared=nil + sessionLayout=nil，:933-936）、secondDrag（controller pointerDown 先 cancel(.secondDrag)，:67-69）。✓
- 零残留：testCancelAllReasonsLeaveNoResidue（全部 DragCancelReason → idle + 清 preview + 恢复 click 识别 + edgeTimerFired no-op）、testTeardownLeavesNoResidue、testTeardownZeroResidue（edge dwell 武装中 teardown → idle；全链 teardown 后零 click/commit 回调）。✓
- 搜索 active 禁拖 / 标题编辑禁拖：dragGate = !search.isSearchActive && !isTitleEditing（AppDelegate :569-574）；testSearchActiveDisablesDragAndCommandFCancelsFirst、testTitleEditingDisablesDrag。✓
- isTornDown 永久（:80/:216，guards :99/:127/:154/:195）——与 test-repair 审查一致。✓

### §5.6 中性视觉 + Reduce Motion（DragUIVisuals.swift）
- 四指示视图默认隐藏（configureViews 末尾 hide(...) :226，visuals-preview-hidden-repair 已审）；isPreviewVisible 等从 false 起步。✓
- 中性：圆角胶囊 + 与 cell 同源标题文本，无真实 app 截图、无 Buho/LaunchBetter 复制；insertion 竖条 vs create-folder 虚线圆角框 + "+" 徽标（CAShapeLayer lineDashPattern [6,4]）——形状可区分，非仅颜色。✓
- Reduce Motion：reduceMotionProvider 默认 `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`；RM 下零动画（alphaValue=1 直置），非 RM 0.12s 淡入；testReduceMotionBranch 注入 { true } 验证。✓

### §5.7 热路径禁令
- DragUI 目录零 FileManager/JSONEncoder/JSONSerialization/Bundle 读取（grep 0 命中）；几何构建仅遍历 cell（线性）；无全树重建、无同步 actor 等待。✓

### 隐私 / pasteboard 中性
- DragUI 无 NSPasteboard 触碰（唯一命中为注释"不触碰 pasteboard"）；无 telemetry 写入（唯一命中为注释）。✓
- stdout 仅 5 处 DBG print（coordinator :100/:101/:105/:115/:118）：dragGate false / no host / point 坐标 + `String(describing: sourceCell)`（AppGridCellView 无自定义 description → `<AppGridCellView: 0x...>`）/ blank press armed / no layout——无 app 名/bundle ID/路径/folder 标题/UUID。✓
- 测试 fixture 全中性（fixture.alpha/beta、'Group 1'、固定 UUID 00000000-...-0001、App01-40）；drag 事务仅不透明 token（DragTokenFactory，ADR-010）。✓

### 范围 / mtime 证据
- 恰好 8 个写范围文件变更于 09:18–09:46（AppGridCellView 09:18、AppGridPageView 09:19、AppDelegate 09:20、FolderOverlayView 09:29、DragUISessionCoordinator 09:40、两测试文件 09:41、DragUIVisuals 09:46）；EdgePagingSchedulerTests.swift 09:01 属 T-1F-C。✓
- 冻结树零触碰：PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/PagingUI 无 09:18 后变更；Package.swift 2026-08-28 20:42:55、AppLaunchController.swift 2026-08-28 21:46:54。✓
- 禁写文件（DragSession/、LayoutDomain/、FolderDomain.swift、FolderKeyboardLogic.swift、AppGridFocus*、AppGridCellFocus.swift、FolderOpenState.swift、AppGridUIPageContentProvider.swift、AppGridSearchPresentationController.swift、AppGridUIState.swift）存在但未修改（pre-existing）。✓

### 测试覆盖（15 + 10）
- DragUISessionCoordinatorTests.swift 15 项：阈值仲裁（click 单次派发 / 亚阈值保持 pressed / 过阈值绝不 click）、几何构建、move-out、全 cancel 原因、commit seam + 会话复位、双 edge turn seam、click 识别抑制生命周期、空白按下两分支、drag 门、second drag、teardown 零残留。✓
- DragUIIntegrationTests.swift 10 项：app click 仍启动 / drag 绝不启动、folder click 仍打开 / drag folder 绝不打开、空白点击两段式不变、搜索禁拖 + Command-F 先 cancel、标题编辑禁拖、folder 内 drag 不动外层页、跨页 drop commit（generation +1）、cell 复用零新增 stale apply（基线计数）、teardown 零 gesture/session/timer/callback、Reduce Motion 分支。✓

### 串行验证（${PIPESTATUS[0]}）
1. `swift build -c debug` → exit 0（Build complete! 0.18s）。✓
2. `swift test` 全量 → **Executed 997 tests, with 0 failures (0 unexpected) in 13.075 (13.112) seconds**，exit 0。✓
3. `swift build -c release` → exit 0（Build complete! 0.17s）。✓

## MINOR notes（不阻塞）
1. DragUISessionCoordinator.swift :100/:101/:105/:115/:118 的 DBG print 无条件输出（内容中性，但生产路径持续打 stdout）；建议后续以编译标志/环境变量门控。
2. drag preview 显示条目显示名文本（与 cell 同源，非截图）——符合 §5.6"preview 文本与 cell 同源"，但严格意义上屏幕可见身份文本；如后续要求完全中性可改为通用占位。
3. FolderOverlayView.handleClick（coordinator nil 回退，mouseDown 即派发）为既有路径，生产恒有 coordinator，不可达；无需处理。
4. Workflow/results/T-1F-D1-appkit-drag-ui.md 仍为 'Status: in progress'（Worker 中断所致，预期）；合并时由 Main 更新。
