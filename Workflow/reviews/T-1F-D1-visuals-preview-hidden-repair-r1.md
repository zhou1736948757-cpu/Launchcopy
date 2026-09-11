# Review: T-1F-D1-visuals-preview-hidden-repair (r1)

Verdict: **PASS**

## Verification points

### Change correctness (Sources/AppGridUI/DragUI/DragUIVisuals.swift)
- `configureViews()` 末尾（`createFolderIndicator.addSubview(createFolderBadge)` 之后，:223）新增一行
  `hide(previewView, insertionIndicator, folderHighlight, createFolderIndicator)`（:226），附注释说明
  NSView isHidden 默认 false、可观测状态须从 false 起步（:225）。✓
- 复用既有 `hide(_ views: NSView...)` 助手（:187-189），未新增逻辑。✓
- showPreview/movePreview/updateIntent/showInsertionBar/showFolderHighlight/showCreateFolderIndicator/
  attach/clearAll/teardown 全部原样（逐段核对 :46-119、:123-156、:182-189），零改动。✓
- 四个指示视图均为 `NSView()`（:22/:24/:25/:26）；`isPreviewVisible = !previewView.isHidden`（:31）
  → init 后为 false，testSubThresholdMoveStaysPressedThenClick:159 断言成立。✓

### Scope / mtime 证据
- 本波次仅 1 文件变更：DragUIVisuals.swift mtime 2026-08-31 09:46:19。✓
- 09:40:28（DragUISessionCoordinator.swift）、09:41:15（DragUISessionCoordinatorTests.swift）、
  09:41:47（DragUIIntegrationTests.swift）属上一波 T-1F-D1-test-repair（其 result 记录 mtime 一致）。✓
- 窗口 09:41:47→09:47:00 内 Sources/Tests 仅 DragUIVisuals.swift 变更；09:46:19 之后无任何变更。✓
- 冻结树零触碰：PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/PagingUI
  无 09:00 后变更；Package.swift 2026-08-28 20:42:55、AppLaunchController.swift 2026-08-28 21:46:54。✓

### 串行验证（${PIPESTATUS[0]}）
1. `swift build -c debug` → exit 0（Build complete! 0.17s，增量缓存）。✓
2. `swift test` 全量 → **Executed 997 tests, with 0 failures (0 unexpected) in 13.125 (13.164) seconds**，
   exit 0；testSubThresholdMoveStaysPressedThenClick（测试文件 :144）通过，最后失败已消除。✓
3. `swift build -c release` → exit 0（Build complete! 0.17s）。✓

## MINOR notes（非阻塞）
- Worker 披露的两处既有编译警告（DragUIVisuals.swift:47 `guard let host` 未使用、
  FolderOverlayView.swift:276 `index` 未使用）本次增量构建未重编译故未复现；属既有代码、非本包引入，
  不影响验收。
- 验收项（isPreviewVisible 初始 false / showPreview 后 true / clearAll/teardown 后 false）由既有测试
  全绿覆盖证实。
