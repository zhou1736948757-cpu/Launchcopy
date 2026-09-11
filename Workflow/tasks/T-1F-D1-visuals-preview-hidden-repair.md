# T-1F-D1-visuals-preview-hidden-repair: DragUIVisuals 初始隐藏修复

Status: in progress
Phase: 1F
Depends: T-1F-D1-test-repair（已 PASS，997 执行 1 失败——本包消除该失败）
Created: 2026-08-31（Main）

## 背景

T-1F-D1-test-repair Worker 如实报告 1 个写范围外失败：
`Tests/AppGridUITests/DragUISessionCoordinatorTests.swift` testSubThresholdMoveStaysPressedThenClick:159
`XCTAssertFalse(coordinator.visuals.isPreviewVisible)` 确定性失败（隔离重跑确认）。

## 根因（Main 只读确认）

`Sources/AppGridUI/DragUI/DragUIVisuals.swift`：
- :22-26 四个指示视图 `previewView`/`insertionIndicator`/`folderHighlight`/`createFolderIndicator`
  均为 `NSView()`，`isHidden` 默认 false（NSView 默认值，Worker 实证）。
- :31 `isPreviewVisible: Bool { !previewView.isHidden }` → 创建即 true。
- :186-189 `hide(_ views: NSView...)` 助手存在，但 `configureViews()`（:191，init :40 调用）
  从未调用它 → 初始状态全部可见。
- 3pt 移动 < 6pt 阈值 → 无 .dragBegan → preview 从未 show → :159 断言仍失败。

## 修复规格

### 写范围（仅 1 文件）

`Sources/AppGridUI/DragUI/DragUIVisuals.swift`：
- `configureViews()` 末尾调用 `hide(previewView, insertionIndicator, folderHighlight, createFolderIndicator)`
  （复用既有 :186 助手；或等价逐视图 `isHidden = true`）。
- 不改任何其他逻辑（show/attach/clearAll/teardown 均不动）。

### 禁止写

DragSession/、LayoutDomain/、FolderDomain.swift、FolderKeyboardLogic.swift、
AppGridFocusNavigator/Layout/Identity.swift、AppGridCellFocus.swift、FolderOpenState.swift、
AppGridUIPageContentProvider.swift、AppGridSearchPresentationController.swift、
AppGridUIState.swift、AppGridCellView.swift、AppGridPageView.swift、FolderOverlayView.swift、
AppDelegate.swift、DragUISessionCoordinator.swift、全部测试文件、全部冻结树、Docs/、PROVENANCE/。

### 必读（只读）

- 本包 + Workflow/tasks/T-1F-D1-test-repair.md（背景/根因）
- Sources/AppGridUI/DragUI/DragUIVisuals.swift（:18-45 声明与 init、:186-206 hide/configureViews）

### 验证（串行）

1. `swift build -c debug` exit 0。
2. `swift test` 全量：期望 **997 项 0 失败**（修复后 testSubThresholdMoveStaysPressedThenClick 通过）。
   用 `${PIPESTATUS[0]}` 取退出码。写范围外失败如实报告，不修改。
3. `swift build -c release` exit 0。

### 红线

无 git；不读禁止来源；隐私中性；不改冻结树；不写 Docs/PROVENANCE；不新增依赖；
输出纪律：先写结果文件 in-progress，回复 <250 词无大代码块。

## 验收

- 997/0 全绿；debug/release 双构建 exit 0。
- isPreviewVisible 初始为 false；showPreview 后 true；clearAll/teardown 后 false（既有测试覆盖）。
