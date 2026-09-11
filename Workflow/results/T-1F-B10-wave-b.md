# T-1F-B10-wave-b 结果（BUG10 缺陷 B，方案 B1 宿主切换）

## 结论
修复完成，全部验证通过。drag preview 在 folder scope 下不再被 overlay 遮罩盖住：视觉宿主随 folder 打开/关闭在 overlay/surface 间切换，且与指针坐标系同源（同一动作切换，契约测试锁死）。

## 改动清单（4 文件，全部在写范围内）

1. **Sources/AppGridUI/DragUI/DragUIVisuals.swift**
   - 新增 `public func setHost(_ newHost: NSView?)`：weak 语义保持；切换时**已挂载**的视觉视图立即迁移（AppKit addSubview 自动从旧父移除；`view.superview !== host` 短路保证同一视图绝不挂两父/漂移）；未挂载（含 teardown 后）不重新挂载；同值重复幂等。
   - 新增诊断可观测 `public var visualViewSuperviews: [NSView?]`（四视图父视图，测试断言迁移/零残留用）。
   - 未触碰：showPreview/movePreview/updateIntent/Reduce Motion 分支（:67-75 原 :90-98）/teardown/attach/insertionRect/localInsertionIndex。

2. **Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift**
   - 新增 `public func setVisualHost(_ newHost: NSView?)`：**同一动作**同时更新 `visualHost`（指针坐标系）与 `visuals.setHost`（preview/指示坐标系）——同源锁。
   - 仅新增方法 + 注释；ClickCensus 区（:28-113）零触碰；init/pointerDown/pointerDragged/pointerUp/teardown 未改。

3. **Sources/PagingPrototypeApp/AppDelegate.swift**
   - `refreshFolderOverlay`（:827-847）：**宿主切换唯一驱动点**——openEntry 非 nil → `dragCoordinator?.setVisualHost(folderOverlay)`；nil → `setVisualHost(surface)`。
   - `closeFolder`（:784-793）：移除 overlay 的路径改为经 `refreshFolderOverlay` 统一出口（原直接 clearContent+removeFromSuperview），保证关闭后宿主切回 surface（顶层拖拽零回归）。
   - `makeDragGeometry`（:625-635）：坐标系契约注释写死——host = visualHost 与 attach 宿主同源；topLevel scope 帧 = surface 系；folder scope 成员帧与顶层帧**均 convert 到 overlay 系**（同系，move-out 不跳变）；成员帧不注记分页、顶层帧注记 committedPage（绝不复用 geometry.page=innerPage）。
   - 未触碰：openFolder/setFolderInnerPage 逻辑、层级挂载（:208-213）、teardownAll。

4. **Tests/AppGridUITests/Bug10PreviewHostTests.swift**（新增，7 测试）

## 测试证据（原文摘录）

```
Test Suite 'Bug10PreviewHostTests' passed
	 Executed 7 tests, with 0 failures (0 unexpected) in 0.319 (0.322) seconds
Test Suite 'PagingPrototypePackageTests.xctest' passed
	 Executed 1073 tests, with 0 failures (0 unexpected) in 34.346 (34.605) seconds
```

- `swift build -c debug`：Build complete（35.11s），exit 0
- `swift build -c release`：Build complete（52.57s），exit 0
- `swift test` 全量：**1073 tests, 0 failures**（基线 1066 + 新增 7）

### 契约测试逐条（任务包 §7）

| # | 测试 | 断言要点 | 结果 |
|---|------|---------|------|
| ① | testSetHostSameValueIsIdempotent | 同值 setHost 不重复 addSubview、preview 帧不漂移 | PASS |
| ① | testSetHostMigratesAttachedViewsExactlyOnce | 异值切换：已挂载视图全部迁移、旧宿主零残留、迁移后同值不重复 | PASS |
| ① | testSetHostAfterTeardownDoesNotReattach | teardown 后 setHost 不重新挂载（零残留） | PASS |
| ①/④ | testSetVisualHostSameValueIsIdempotentNoDrift | coordinator 层同值幂等 + preview 不漂移 | PASS |
| ④ | testTopLevelDragRegressionHostStaysSurface | 顶层拖拽：host 恒 surface、commit 正常、attach 不变 | PASS |
| ② | testPreviewStaysGluedToPointerAfterHostSwitch | 窗口化双宿主（overlay 偏移 (100,50)）：切换后 preview 帧 = overlay.convert(pointer) − 偏移，贴指针不偏移；继续拖动仍贴 | PASS |
| ③ | testMoveOutBarAndPreviewShareOverlayCoordinateSystem | 窗口化：成员拖到顶层缝隙，顶层蓝条 (77,0,3,80) 与 preview (152,64,96,88) **同在 overlay 系**，不跳变 | PASS |

## Deviation（逐条）

1. **closeFolder 改经 refreshFolderOverlay 统一出口**：任务包写范围列 AppDelegate「仅 refreshFolderOverlay 切换驱动 + makeDragGeometry 契约注释」。实现中发现 closeFolder 原直接 clearContent+removeFromSuperview、绕过 refreshFolderOverlay——若只改 refreshFolderOverlay，关闭 folder 后宿主不会切回 surface（顶层拖拽将经已移除的 overlay 换算坐标）。故 closeFolder 的移除逻辑收敛到 refreshFolderOverlay（行为等价：clearContent+removeFromSuperview 原样保留在 nil 分支），属同一「切换驱动」面的必要最小改动。已在改动清单 3 声明。
2. **新增诊断可观测 visualViewSuperviews**：测试①需要断言「切换后 attach 不重复 addSubview / teardown 零残留」，既有可观测（isPreviewVisible 等）只覆盖 hidden 状态不覆盖挂载关系。仅测试/诊断用途，无生产行为影响。
3. 其余无 deviation。未新增 DragParameters 字段；未引入独立窗口（B2 未采用）；未改坐标换算本身。

## 未触碰声明

- 冻结树零触碰：Sources/PagingCore、AppCatalogCore、MacAppCatalog、AppIconPipeline、PagingTelemetry、PagingUI、Package.swift、PagingPrototypeApp/AppLaunchController.swift。
- 未读：LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse/Ghidra/otool dump。
- 无 git 操作；未改 Docs/。
- 未碰 DropIntent.swift（wave-c 领地）；未碰 FolderOverlayView.swift 坐标链（memberDragItemFrames 原样）。
- DragUISessionCoordinator ClickCensus 区（:28-113）零触碰；DragUIVisuals Reduce Motion 路径未触碰。
