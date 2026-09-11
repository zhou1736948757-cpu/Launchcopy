# T-1F-D1-test-repair: D1 测试夹具与 teardown 语义修复

Status: in progress
Phase: 1F
Depends: T-1F-D1-appkit-drag-ui（Worker 中断，源码+测试已落盘，验证未完成）
Created: 2026-08-31（Main）

## 背景

T-1F-D1 Worker 上下文耗尽中断：8 个写范围文件全部落盘（DragUISessionCoordinator.swift /
DragUIVisuals.swift / AppGridCellView.swift / AppGridPageView.swift / AppDelegate.swift /
FolderOverlayView.swift / DragUISessionCoordinatorTests.swift / DragUIIntegrationTests.swift），
结果文件仅 'Status: in progress'。Main 只读诊断（swift build exit 0；swift test 失败 +
临时探针实证）定位全部根因如下。**本包只修测试夹具与一处 coordinator 语义缺陷；不重写
D1 业务实现。**

## 根因（Main 实证）

### A. DragUISessionCoordinatorTests（15 测试全受影响，2 个空转通过）

1. **host 无强引用**：`makeCoordinator()` 内联创建 NSView（`host ?? makeHost()`），
   `DragUISessionCoordinator.visualHost` 与 `DragUIVisuals.host` 均为 `weak` →
   测试中 host 立即 dealloc → `pointerDown` 在 `guard let host = visualHost` 提前返回 →
   全部会话测试失败（state 恒 idle）；testBlankPressBeyondThresholdCancelsBlankClick 与
   testDragGateBlocksSessionStart 空转通过（断言恰好匹配"什么都没发生"）。
2. **catalogSnapshotProvider 未接线**：仅 2 个测试（:228/:347）接线；其余 app 源测试
   `resolveSource → appReference(for:)` 返回 nil → 空白按下候选 → 无会话。
3. **崩溃**：testClickBelowThresholdDispatchesCellClickOnce :127 `clicks[0]` 在 clicks 空时
   越界（Swift/ContiguousArrayBuffer.swift:692 Fatal error: Index out of range，
   xctest signal 5）——1+2 修复后自然消失。

### B. DragUIIntegrationTests（10 测试 6 失败）

1. **testAppClickStillLaunchesAndDragNeverLaunches :303 期望错误**：FakeAppFactory 目录
   扫描按 bundle ID 排序（探针实证 servedSnapshot = [Alpha, Beta, Delta, Echo, Foxtrot,
   Gamma]）→ 分组 G1=[alpha,beta]、G2=[delta,echo]，未分组=[foxtrot,gamma] →
   组合 = [folder1, folder2, foxtrot, gamma]（slot 2 = Foxtrot，非 Echo）。拖 slot 2 到
   x=520 → 正确重排 foxtrot 到末位 → commit = [folder1, folder2, gamma, foxtrot]。
   测试期望 [folder1, folder2, foxtrot, echo] 错误（echo 在 G2 内，顶层不存在）。
2. **testCrossPageDropCommitsSeamLevel :478 fixture 缺陷**：`folderSnapshotGenerator` 恒
   `enabled: true`，忽略 `folderLab` 参数 → folderLab: false 时仍生成 20 个 folder →
   `XCTAssertNil(fixture.folder)` 失败 → 组合 20 条目 → slot 29 不存在 →
   `cellCenter(slot: 29)` nil → XCTUnwrap 失败。
3. **testCellReuseZeroStaleApply :528 无基线**：探针实证 staleIconApplyCount 在 fixture
   setup 期间已是 6（begin→rebuild→apply 三次 render × 2 个 app cell 图标请求，旧代结果
   到达时已 re-render → stale）。测试断言 0 无基线 → 恒失败。drag 本身不新增 stale。
4. **testTeardownZeroResidue :543/:560**：
   - :543 期望 .edgeTurnPending 但 fixture 只有 1 页（4 条目/35 每页 → 呈现更新把
     pageCount 设为 1）→ 右缘是边界 → 不武装 dwell → state 恒 .dragging。
   - :560 coordinator 缺陷：`teardown()` 只清当前会话（endSession），不永久禁用 →
     teardown 后新 pointerDown 开新会话 → click 回调 1 次。测试期望 0（teardown = 终态）。

## 修复规格

### 写范围（仅 3 文件）

1. `Tests/AppGridUITests/DragUISessionCoordinatorTests.swift`
   - `makeCoordinator` 保留 host 强引用（测试类属性，如 `private var retainedHost: NSView?`，
     makeCoordinator 内赋值；tearDown 置 nil）。
   - 所有需要源解析的测试接线 `coordinator.catalogSnapshotProvider = { catalog }`
     （catalog 来自 makeTwoAppLayout/makeFolderLayout；参照 :228/:347 既有模式）。
   - 不改任何断言语义；不新增测试。
2. `Tests/PagingUITests/DragUIIntegrationTests.swift`
   - :303 期望改为 `[.folder(folder1.id), .folder(folder2.id), .app(ref("gamma")),
     .app(ref("foxtrot"))]`，注释改为"组合：folder, folder, Foxtrot, Gamma（slot 2 =
     Foxtrot app cell；catalog 按 bundle ID 排序 → 分组 [alpha,beta]/[delta,echo]，
     未分组 [foxtrot,gamma]）"。
   - makeFixture 的 generator 改 `configuration: .init(groupSize: 2, enabled: folderLab)`。
   - testCellReuseZeroStaleApply：drag 前捕获 `let staleBefore = pageView.staleIconApplyCount`
     （+ overlay 同），断言 drag 后计数不变（`== staleBefore`）。
   - testTeardownZeroResidue：fixture 改 40 apps + folderLab: false（2 页，右缘非边界 →
     dwell 可武装）；slot 2 仍存在（40 条目 page 0 = 35）；其余断言不变。
3. `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift`
   - 新增 `private var isTornDown = false`；`teardown()` 置 `isTornDown = true`（幂等）；
     `pointerDown`/`pointerDragged`/`pointerUp`/`cancel` 顶部 `guard !isTornDown else { return }`。
   - 不改其他逻辑。

### 禁止写

DragSession/、LayoutDomain/、FolderDomain.swift、FolderKeyboardLogic.swift、
AppGridFocusNavigator/Layout/Identity.swift、AppGridCellFocus.swift、FolderOpenState.swift、
AppGridUIPageContentProvider.swift、AppGridSearchPresentationController.swift、
AppGridUIState.swift、AppGridCellView.swift、AppGridPageView.swift、FolderOverlayView.swift、
AppDelegate.swift、DragUIVisuals.swift、既有其他测试、全部冻结树、Docs/、PROVENANCE/。

### 必读（只读）

- 本包 + Workflow/tasks/T-1F-D1-appkit-drag-ui.md（写范围/实现要求背景）
- Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift（teardown/pointer 方法）
- Tests/AppGridUITests/DragUISessionCoordinatorTests.swift（夹具）
- Tests/PagingUITests/DragUIIntegrationTests.swift（4 个失败测试 + makeFixture）

### 验证（串行）

1. `swift build -c debug` exit 0。
2. `swift test` 全量：期望 997 项 0 失败（基线 972 + D1 25：coordinator 15 + integration 10）。
   写范围外失败如实报告，不修改。
3. `swift build -c release` exit 0。

### 红线

无 git；不读禁止来源；隐私中性（fixture.* 数据）；不改冻结树；不写 Docs/PROVENANCE；
不新增依赖；输出纪律：先写结果文件 in-progress，回复 <250 词无大代码块。

## 验收

- 997/0 全绿；debug/release 双构建 exit 0。
- 4 个集成失败测试 + 15 个 coordinator 测试全部通过（无空转：断言真实路径）。
- teardown 后 pointerDown/pointerUp 零回调（isTornDown 生效）。
