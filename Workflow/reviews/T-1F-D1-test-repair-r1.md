# Review: T-1F-D1-test-repair (r1)

Verdict: **PASS**

## Verification points

### Fix 1 — Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift (mtime 2026-08-31 09:40:28)
- `private var isTornDown = false`（:80，注释 'teardown 后为终态'）；`teardown()` 首行置
  `isTornDown = true`（:216，幂等终态）。✓
- `pointerDown`(:99)/`pointerDragged`(:127)/`pointerUp`(:154)/`cancel`(:195) 顶部
  `guard !isTornDown else { return }`；其余逻辑零改动（逐段核对）。✓
- 对应根因 B4（teardown 只清当前会话、不永久禁用）。✓

### Fix 2 — Tests/AppGridUITests/DragUISessionCoordinatorTests.swift (mtime 09:41:15)
- `private var retainedHost: NSView?`（:28）+ `override func tearDown()` 置 nil（:30-33）；
  `makeCoordinator` 改 `let host = host ?? makeHost(); retainedHost = host`（:55-56）。✓
  对应根因 A1（visualHost/visuals.host 均 weak → host 立即 dealloc）。✓
- `catalogSnapshotProvider = { catalog }` 全文件 11 处：9 处本波新增
  （testClickBelowThreshold…/testSubThresholdMove…/testDragBeyondThreshold…/
  testCancelAllReasons…（for 循环内）/testCommitSeam…/testEdgeTurnTopLevel…/
  testClickRecognitionSuppressionLifecycle/testSecondDrag…/testTeardownLeavesNoResidue），
  2 处既有（:241/:363）；testDragGateBlocksSessionStart 保持 `_`（gate 短路，无需接线）。✓
  对应根因 A2（catalogSnapshotProvider 默认 nil → 源解析失败）。✓
- 无断言改动、无新增测试（逐段核对）。✓

### Fix 3 — Tests/PagingUITests/DragUIIntegrationTests.swift (mtime 09:41:47)
- makeFixture generator：`configuration: .init(groupSize: 2, enabled: folderLab)`（:182）。✓
  对应根因 B2（generator 恒 enabled: true，忽略 folderLab）。✓
- testAppClickStillLaunchesAndDragNeverLaunches：注释改
  '组合：folder, folder, Foxtrot, Gamma（slot 2 = Foxtrot app cell；catalog 按 bundle ID
  排序 → 分组 [alpha,beta]/[delta,echo]，未分组 [foxtrot,gamma]）'（:280-281）；
  echoCell → foxtrotCell（:283）；期望 commit
  `[.folder(folder1.id), .folder(folder2.id), .app(ref("gamma")), .app(ref("foxtrot"))]`
  （:304-307，消息 '顶层重排：Foxtrot 移到末位'）。✓ 对应根因 B1（组合 folders-first，
  slot 2 = Foxtrot 非 Echo）。✓
- testCellReuseZeroStaleApply：drag 前捕获 `staleBefore`/`overlayStaleBefore`（:521-522），
  断言 `== staleBefore`/`== overlayStaleBefore`（:533-534）。✓ 对应根因 B3（无基线）。✓
- testTeardownZeroResidue：fixture 40 apps + folderLab: false（:541-542，2 页右缘非边界 →
  dwell 可武装）；echoCell → cell（:544）；其余断言不变。✓ 对应根因 B4（1 页 fixture 无法
  武装 dwell；teardown 非终态）。✓

### Scope / mtime 证据
- 窗口 09:38–09:44 内 Sources/Tests 仅上述 3 文件变更（find 实证）。✓
- 冻结树零触碰：PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/
  PagingUI 窗口内无变更；Package.swift 2026-08-28 20:42:55、
  AppLaunchController.swift 2026-08-28 21:46:54（均早于窗口）。✓
- 越界失败由独立任务消除：T-1F-D1-visuals-preview-hidden-repair（result PASS + review r1
  PASS，997/0）；DragUIVisuals.swift mtime 09:46:19 晚于本 Worker 窗口，属该任务。✓

### 串行验证（${PIPESTATUS[0]}）
1. `swift build -c debug` → exit 0（Build complete! 0.17s）。✓
2. `swift test` 全量 → **Executed 997 tests, with 0 failures (0 unexpected) in 13.128
   (13.165) seconds**，exit 0；DragUISessionCoordinatorTests 与 DragUIIntegrationTests 两套件
   全过；原失败 testSubThresholdMoveStaysPressedThenClick（coordinator 级）现通过。✓
3. `swift build -c release` → exit 0（Build complete! 0.17s）。✓

## MINOR notes（非阻塞）
- Worker 结果写于 visuals 修复合并前，如实报告 1 个越界失败（符合包规
  '写范围外失败如实报告，不修改'）；该失败现已被独立任务消除，当前树 997/0 全绿，
  满足验收 '997/0 全绿；debug/release 双构建 exit 0'。
- Worker 披露的两处既有编译警告（FolderOverlayView.swift:276 'index' 未使用、
  DragUIVisuals.swift:47 `guard let host` 未使用）非本波引入；本次增量构建未重编译故未复现，
  不影响验收。
