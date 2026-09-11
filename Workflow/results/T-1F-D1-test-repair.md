# T-1F-D1-test-repair 结果

Status: PASS

## 变更文件（含 mtime）

1. `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift` — 2026-08-31 09:40:28
   - 新增 `private var isTornDown = false`（:80，注释 'teardown 后为终态'）；
   - `teardown()` 首行置 `isTornDown = true`（:216，幂等终态）；
   - `pointerDown`(:99)/`pointerDragged`(:127)/`pointerUp`(:154)/`cancel`(:195) 顶部
     `guard !isTornDown else { return }`。其余逻辑零改动。

2. `Tests/AppGridUITests/DragUISessionCoordinatorTests.swift` — 2026-08-31 09:41:15
   - 新增 `private var retainedHost: NSView?`(:28) + `override func tearDown()`(:30-33)；
   - `makeCoordinator` 改 `let host = host ?? makeHost(); retainedHost = host`(:55-56)；
   - 9 个测试接线 `coordinator.catalogSnapshotProvider = { catalog }`（`let (layout, _)` →
     `(layout, catalog)`）：testClickBelowThresholdDispatchesCellClickOnce /
     testSubThresholdMoveStaysPressedThenClick / testDragBeyondThresholdNeverDispatchesClick /
     testCancelAllReasonsLeaveNoResidue（for 循环内）/ testCommitSeamReceivesNewLayoutAndSessionResets /
     testEdgeTurnTopLevelUsesKeyboardPageTurnerSeam / testClickRecognitionSuppressionLifecycle /
     testSecondDragCancelsPreviousAndKeepsArbitration / testTeardownLeavesNoResidue；
   - testDragGateBlocksSessionStart 保持 `_`（gate 短路，无需接线）；
   - 2 处既有接线未动（testMoveOutArmsAndCommitsTopLevelTarget ~:241、
     testEdgeTurnFolderUsesOverlayPageTurnSeam ~:363）；全文件共 11 处
     `catalogSnapshotProvider = { catalog }`。无断言改动、无新增测试。

3. `Tests/PagingUITests/DragUIIntegrationTests.swift` — 2026-08-31 09:41:47
   - (a) makeFixture folderSnapshotGenerator：`enabled: true` → `enabled: folderLab`(:182)；
   - (b) testAppClickStillLaunchesAndDragNeverLaunches：注释改
     '组合：folder, folder, Foxtrot, Gamma（slot 2 = Foxtrot app cell；catalog 按 bundle ID
     排序 → 分组 [alpha,beta]/[delta,echo]，未分组 [foxtrot,gamma]）'；echoCell → foxtrotCell；
     期望 commit `[.folder(folder1.id), .folder(folder2.id), .app(ref("gamma")), .app(ref("foxtrot"))]`
     （消息 '顶层重排：Foxtrot 移到末位'）；
   - (c) testCellReuseZeroStaleApply：click+drag 前捕获 `staleBefore`/`overlayStaleBefore`(:521-522)，
     断言 `== staleBefore`/`== overlayStaleBefore`(:533-534)；
   - (d) testTeardownZeroResidue：fixture 40 apps（`(1...40).map { String(format: "App%02d", $0) }`）
     + folderLab: false(:541-542)；echoCell → cell；其余断言不变。

## 验证证据（串行）

1. `swift build -c debug` → exit 0（'Build complete! (1.95s)'；仅既有警告
   FolderOverlayView.swift:276 'index' never used — 越界，未动）。
2. `swift test` 全量 → 997 项执行，1 失败（0 unexpected），13.1s。
   - DragUIIntegrationTests：10/10 通过。
   - DragUISessionCoordinatorTests：14/15 通过。
   - 失败：`testSubThresholdMoveStaysPressedThenClick` :159
     `XCTAssertFalse(coordinator.visuals.isPreviewVisible)`（隔离复跑同样失败，确定性）。
3. `swift build -c release` → exit 0（'Build complete! (7.19s)'）。

## 偏差（越界失败，如实报告，未修改）

- 失败测试：testSubThresholdMoveStaysPressedThenClick:159。
- 根因：`DragUIVisuals.previewView.isHidden` 默认 false（NSView 默认值，已实测确认），
  `isPreviewVisible` 自 coordinator 创建即为 true，直到 clearAll()/teardown()。
  3pt 位移 < 6pt 阈值，controller 不产生 `.dragBegan`，preview 从未被 show——断言仍失败。
- 该测试在修复前同样为红（无 catalog 接线时源解析失败 → :158 state != .pressed 先失败）；
  本次按规格接线后失败点移至 :159。接线本身正确，残余失败与接线无关。
- 修复需改 `DragUIVisuals.swift`（禁写清单）或改断言（规格禁止 'No assertion changes'）
  或 coordinator init 加 clearAll（规格 'Nothing else changed'）——均不可行，故未修改。
- 建议：单独任务在 DragUIVisuals 初始化时隐藏 previewView（configureViews 内
  `previewView.isHidden = true`），即可使该测试转绿。

## 未解决问题

- 无（上述越界失败已定位根因并给出修复建议，待独立任务处理）。
