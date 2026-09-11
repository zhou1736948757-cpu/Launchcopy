# T-1F-C-resume — DragSession 收尾（Worker）

- 创建：2026-08-31（Asia/Tokyo）
- 依赖：T-1F-A（已合并）；原 T-1F-C Worker（95004630）中途失败，源码已落盘
- 角色：Worker（resume——完成测试、验证、ADR 注记、结果文件；源码缺陷可修）

## 背景

原 Worker C 已落盘 `Sources/AppGridUI/DragSession/` 9 文件（DragTransaction、DragSessionController 状态机、DragGeometry、DragParameters、DragSessionEvents、DropResolver、DropIntent、DragMutationEngine、EdgePagingScheduler）+ Tests/AppGridUITests/DragSessionTestSupport.swift，结果文件 Workflow/results/T-1F-C.md 为 in-progress（含完整交付计划）。**未完成**：4 个 drag-intent 测试文件、swift build/test 验证、ADR-010 注记、结果文件 complete。

## 范围（resume）

1. **只读审查**已落盘 9 个 DragSession 文件 + TestSupport：与 Workflow/tasks/T-1F-C.md 包 + ADR-010（Accepted）对照，确认状态机（idle → pressed → dragging/edgeTurnPending → commit|cancel → idle）、DragTransaction(opaqueToken,scope,sourceIdentity,layoutGeneration,catalogGeneration)、click vs drag 阈值仲裁、drop resolver、hit-zone/drop-intent 分类（insertion vs create-folder enum）、5 类 mutation 统一引擎（经 LayoutMutation(expectedGeneration:) 单一写入口）、edge paging 纯 seam（enter/dwell/turn/leave/cancel/first-last 只产事件）、统一 cancel（ESC/resign/refresh/search/title edit/overlay close/teardown/second drag → 零写盘无残留）、stale 防护（stale source/target/layout/catalog 拒绝；duplicate drop consumed once；invalid/external token rejected；second drag invalidates first）。发现缺陷 → 修复（resume 授权）。
2. **写测试**：Tests/AppGridUITests/ 新增 4 个 drag-intent 测试文件（用已落盘 DragSessionTestSupport.swift）——按 Workflow/tasks/T-1F-C.md 验收矩阵：click below threshold vs drag above；reorder / create / insert / move-into / move-out / cross-folder 分类；invalid/external token rejected；duplicate drop consumed once；stale source/target/layout/catalog rejected；全部 cancel 路径可测；edge enter/dwell/turn/leave/cancel/first-last；second drag invalidates first。
3. **验证**：`swift build -c debug` exit 0；`swift test` 全量（基线 789 + A 48 + C 新增；既有不得回归；写集外失败如实报告不修改）。.build 锁争用则等待重试一次。
4. **ADR-010 末尾追加「T-1F-C 实现注记」**（不改草案主体）。
5. **结果文件更新为 complete**。

## 写集（仅这些）

```
Sources/AppGridUI/DragSession/（已落盘 9 文件——可修）
Tests/AppGridUITests/（DragSessionTestSupport.swift 已落盘 + 4 个新 drag-intent 测试文件）
Docs/ADR-010-DRAG-SESSION-AND-DROP-SEMANTICS.md（末尾注记）
Workflow/results/T-1F-C.md（更新 complete）
```

## 禁止写（只读）

```
Sources/AppGridUI/LayoutDomain/（A 的产物）
Sources/AppGridUI/LayoutStore/（B 的产物，并行 resume Worker 在写）
Sources/AppGridUI/ 下全部既有文件
Sources/PagingPrototypeApp/、Sources/PagingUI/、Sources/PagingCore/、Sources/MacAppCatalog/、Sources/AppCatalogCore/、Sources/AppIconPipeline/、Sources/PagingTelemetry/
Package.swift
Tests/PagingUITests/
```

## 红线

- 禁止读取：/Users/mac/Projects/LaunchBetter/、/Users/mac/Projects/BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse、任何反编译 dump；接触即标 PRIOR_EXPOSURE。
- 隐私：app 名/bundle ID/path/FolderID/标题/身份数据绝不进 telemetry/JSONL/stdout/log/report/测试输出；opaqueToken 零身份；参数来源 5 类（禁 REVERSE_ENGINEERING_COPY/OLD_SOURCE_TRANSLATION/UNKNOWN_ORIGIN）。
- 冻结树 mtime 不得改变（除允许写集）；无 git 操作。

## 输出纪律

- 先更新 Workflow/results/T-1F-C.md（"in progress（resume）"），完成后 complete；
- 最终回复 <250 词：审查结论、测试数、验证输出关键行、修复（如有）、PRIOR_EXPOSURE。不贴大代码块。
