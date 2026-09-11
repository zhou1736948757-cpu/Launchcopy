# Phase 1F 规格（SPEC）

> 状态：**AUTOMATED_COMPLETE_PHYSICAL_PENDING**（2026-09-05 Gate 0 对账补建）
> 本文件由 Phase 1G Gate 0 对账补建，基于 Workflow 既有任务包/结果/评审与 fresh 验证，不夸大。

## 1. 范围

Phase 1F = 拖拽持久化与布局存储阶段，在 Phase 1E（分页/目录/启动/搜索/文件夹）基础上新增：

1. **拖拽交互**：reorder / create folder / add to folder / move out / cross-folder 拖拽语义（ADR-010）。
2. **布局持久化**：workspace layout store（schema v1 codec/validator、A/B journal、coalescing、flush barrier、失败态、reset、多实例策略）（ADR-009）。
3. **点击/启动回归修复**：BUG6（点击双启动通路拓扑）、BUG7（createFolder 落点 index 语义）、BUG8（蓝条 global→local 回减）、BUG9（主页面点击失效诊断）、BUG10（click delivery 生产默认路径）、BUG11（跨行/行末 insertion indicator）。

## 2. 非目标

- 不引入搜索/文件夹/Hot Corner/120Hz/vsync 新功能（属后续阶段）。
- 不修改 PagingCore 分页参数、Timer tolerance（`PRODUCT_TIMER_TOLERANCE_0MS` 保持）。
- 不读取/复制 LaunchBetter、BuhoReverseNotes 或任何外部实现（来源红线保持）。

## 3. 关键设计决策

| 决策 | 内容 | 依据 |
|---|---|---|
| 拖拽落点几何 | 纯函数（命中查询 + 意图判定 + 插入位=指针左侧条目水平中点计数），不用预计算 zone 表 | BUG6 wave-a |
| createFolder 落点 | drop 目标 target 原 index（格子位置语义，不做 −1） | BUG7 wave-a 修订 + 用户实机裁定 |
| 蓝条坐标 | localInsertionIndex 只信帧注记（pageIndex/itemsPerPage），禁读 geometry.page | BUG8 wave-v |
| 点击双通路 | Path A=surface NSClickGestureRecognizer→handleCell；Path B=cell.mouseDown→coordinator→.clicked→onCellClick；beginArbitration 抑制只禁 surface 级 | BUG6 wave-c |
| B10 生产路径 | `PAGING_CLICK_MANUAL_DELIVERY=1` 门控手动投递（含完整 up/dragged 闭环）；**默认关闭**；`PAGING_CLICK_PROBE_MANUAL_DELIVERY` 仅诊断 | T-1F-B10-regression-fix |
| B11 指示器 | 跨行/行末 insertion indicator 逐帧 pointer-aware 补刷（仅 insertion/topLevelTarget），create/into-folder 只经 intentChanged | T-1F-B11 |
| 布局存储 | LayoutStoreActor + FileManagerLayoutStoreIO，A/B 双槽 + corrupt 保护 + 多实例裁决 | T-1F-B/C |

## 4. 冻结范围（Phase 1F 内）

`Sources/PagingCore/`、`PagingTelemetry/`、`PagingUI/`、`AppCatalogCore/`、`MacAppCatalog/`、`AppIconPipeline/`、`AppGridUI/LayoutDomain/`、`LayoutStore/`、`DragSession/`、`Package.swift`、`AppLaunchController.swift` 在 Phase 1F 收尾后冻结（Phase 1G 不得修改）。

## 5. 验收判据（自动化）

- fresh `swift test`：executed > 0 且 0 failures；
- `swift build`（debug）与 `swift build -c release`：exit 0；
- 记录 Debug/Release executable SHA-256；
- layout store 测试使用临时目录，不触碰真实 Application Support。

## 6. 物理验收判据（用户实机）

- B10：门控关基线对照 + 门控开 10+ 击 s10==击数、空白 s8c、ESC、拖拽预览、搜索与 folder 开合（Q-1 未回填）；
- B11：真实窗口/触控板拖拽的跨行/行末指示器视觉验收（未执行）；
- 拖拽/持久化/重启恢复的用户实机确认（用户已报告 Folder 功能实现，其余按证据对账）。
