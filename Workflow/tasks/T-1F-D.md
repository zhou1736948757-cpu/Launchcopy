# T-1F-D — AppKit drag UI（Worker）

- 创建：2026-08-31（Asia/Tokyo）——预写骨架，C 合并后若有 API 名称偏差以实际为准
- 依赖：T-1F-C（DragSession 纯状态机 + drop resolver）；ADR-010 转正后为权威
- 角色：Worker（AppKit 视图层薄壳：cell/overlay drag source+destination、preview、edge turn 视觉、move-out 协调；纯逻辑全部走 C 的引擎）
- 依据：Docs/PHASE1F_DRAG_PERSISTENCE_PROMPT.md §3.4/§6.2；Docs/ADR-010-DRAG-SESSION-AND-DROP-SEMANTICS.md；Workflow/PLAN.md §7/§10

## 范围

- `AppGridCellView`/`AppGridPageView`/`FolderOverlayView` 的 drag source + destination 接线（pointer-down 硬门只进 pressed；click 阈值仲裁；click-launch 不回归）
- 顶层 + folder 内 + move-out（"先退 overlay 再落顶层"经 C 的显式 coordinator 状态）三场景
- drag preview（跟随指针的视觉；Reduce Motion 时降级）
- edge turn 视觉（edge enter/dwell/turn/leave/cancel/first-last 的视图反馈，调度逻辑在 C）
- 统一 cancel 的视图侧（ESC/resign/refresh/search/title edit/overlay close/teardown/second drag → 清 preview/edge 残留）
- 键盘/VoiceOver 等价入口（Move Before/After、previous/next page、Move Into/Out of Folder、in-folder Move Before/After、cancel reorder——菜单/上下文菜单/键盘 reorder 模式/NSAccessibility custom actions，全部路由到 C 的同一 mutation 引擎，无第二算法）
- 无障碍 announcement（中性描述，无身份原值）

## 写集（仅这些）

```
Sources/AppGridUI/AppGridCellView.swift、AppGridPageView.swift、FolderOverlayView.swift（drag 接线扩展）
Sources/AppGridUI/（新增 drag presentation 文件，如 DragPresentation/ 或按 C 实际结构）
Tests/AppGridUITests/（新 AppKit drag 集成测试——可测部分；纯 AppKit 手势留手动门）
Tests/PagingUITests/（如需要集成断言）
Docs/ADR-010-DRAG-SESSION-AND-DROP-SEMANTICS.md（末尾追加「T-1F-D 实现注记」，不改草案主体）
Workflow/results/T-1F-D.md（先写 in-progress）
```

## 禁止写（只读）

```
Sources/AppGridUI/LayoutDomain/（A 的产物）
Sources/AppGridUI/LayoutStore/（B 的产物）
Sources/AppGridUI/DragSession/（C 的产物）
Sources/PagingPrototypeApp/（含 AppDelegate、AppLaunchController；E 层才接线）
Sources/PagingUI/、Sources/PagingCore/、Sources/MacAppCatalog/、Sources/AppCatalogCore/、Sources/AppIconPipeline/、Sources/PagingTelemetry/
Package.swift
```

## 红线

- 禁止读取：/Users/mac/Projects/LaunchBetter/、/Users/mac/Projects/BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse、任何反编译 dump；接触即标 PRIOR_EXPOSURE。
- 隐私：app 名/bundle ID/path/FolderID/标题/身份数据绝不进 telemetry/JSONL/stdout/log/report/测试输出/announcement；announcement 只含中性类别。
- 冻结树 mtime 不得改变（除允许写集）。
- 无 git 操作。

## 验证

- `swift build -c debug` exit 0；`swift test` 全量（基线 789 + A/B/C 新增 + D 新增；既有不得回归；写集外失败如实报告不修改）。
- 验证后更新 ADR-010 末尾「T-1F-D 实现注记」。

## 验收（对 Prompt §10.4）

AppKit drag 集成测试矩阵（可测部分）+ 手动门（TOP_LEVEL_DRAG/FOLDER_DRAG/EDGE_PAGING/KEYBOARD_ACCESSIBILITY 由用户实机验收，本任务只保证自动化部分 + 接线正确）。

## 输出纪律

- 先写 Workflow/results/T-1F-D.md（"in progress" + 交付摘要），完成后更新完整结果；
- 最终回复 <250 词：新增文件、测试数、验证命令结果、偏差与理由、PRIOR_EXPOSURE（无则 NO_PRIOR_EXPOSURE）。不贴大代码块。
