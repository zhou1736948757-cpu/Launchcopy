# T-1F-B11-row-boundary-indicator — 跨行插入蓝条锚点修复

Status: passed — implementation complete; Main fresh 1133/1133 + debug/release; independent Luna Reviewer PASS
Role: Luna Worker 实现与测试 → 独立 Luna Reviewer 只读门禁 → Main 亲自复核
User report: 「把软件拖动到最右边那一列时，蓝色的条条会在下面一行正中间，而不是在最右边那一列的软件右边。」

## 根因边界

- `DropZoneClassifier` 命中一行末项右半时正确产生 `.insertion(index: rowEnd + 1)`；不得修改 intent、resolver、mutation 或持久化语义。
- `DragUIVisuals.insertionRect` 对所有 `0 < index < frames.count` 无条件取前后两帧中点；当两帧跨行时，把上一行末项与下一行首项做中点，导致蓝条落到下一行中部。
- 旧 BUG10-C 仅修复条目外落点的 y-up `insertionIndex` 行划分；本任务不得回退或重做该修复。
- 同一跨行 index 同时代表「上一行末项右侧」与「下一行首项左侧」。只按 index 固定画在一边会制造镜像缺陷；视觉必须使用当前 pointer 所在/最近行选择锚点。

## 实现要求

1. 保留现有 public `DragUIVisuals.updateIntent(_:geometry:)` API；增加 module-internal pointer-aware seam，不破坏调用方。
2. 同行相邻帧继续使用现有中点算法。
3. 相邻帧竖直区间不重叠时视为跨行槽：pointer 更接近前帧行则画前帧右缘；更接近后帧行则画后帧左缘；平局固定选阅读序较早行。判定必须同时适配 y-up/y-down，不硬编码坐标方向。
4. 蓝条 frame 使用所选 anchor frame 的 y/height，不得做跨行 vertical union。
5. coordinator 必须在有效 pointerDragged 更新中刷新视觉，即使 `DropIntent` index 未变化；覆盖从上一行末项右半移动到下一行首项左半、intent 仍相同的情况。
6. `.insertion` 与 `.topLevelTarget` 共享修复；preview、edge paging、drop commit、folder/create-folder 语义不变。

## 写范围

- `Sources/AppGridUI/DragUI/DragUIVisuals.swift`
- `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift`
- `Tests/PagingUITests/Bug11RowBoundaryIndicatorTests.swift`（优先新文件）
- 如确需 coordinator 集成夹具，可修改一个最相关的现有 DragUI 测试文件，并在结果中逐项说明。
- `Workflow/results/T-1F-B11-row-boundary-indicator.md`

## 禁写

- `Sources/AppGridUI/DragSession/DropIntent.swift`、`DragGeometry.swift`、`DropResolver.swift`、`DragMutationEngine.swift`
- `Sources/PagingPrototypeApp/AppDelegate.swift`（含 BUG10 B1）
- 冻结树：`Sources/PagingCore/`、`AppCatalogCore/`、`MacAppCatalog/`、`AppIconPipeline/`、`PagingTelemetry/`、`PagingUI/`、`Package.swift`、`Sources/PagingPrototypeApp/AppLaunchController.swift`
- Docs、MEMORY、现有 Workflow 历史；无 git 操作。

## 必测矩阵

1. y-up `[5,3]`：frame[4] 右半 → intent 5，bar `(521,496,3,88)`，且不等于旧错位 `(272.5,392,3,88)`。
2. 同一 intent 5：frame[5] 左半 → bar 在下一行首项左缘。
3. 同一 session 从 1 移到 2：intent 不变但 bar 必须换行刷新。
4. frame[4] 右缘外空白 → 旧 BUG10-C `insertionIndex == 5` 且 bar 在上一行右缘。
5. 同行中点、首项前、末项后、空 frames 不回归。
6. `.topLevelTarget` 多行同构；page 1 global→local 后再做跨行定位。
7. y-down 镜像夹具同语义。
8. commit 最终顺序/generation 不因视觉修复改变。

## 验证

- `swift test --filter Bug11RowBoundaryIndicatorTests`
- `swift test --filter Bug8VisualIndexTests`
- `swift test --filter Bug6DropZoneGeometryTests`
- `swift test --filter DragUIIntegrationTests`
- `swift test`
- `swift build -c debug`; `swift build -c release`
- 变异证明：删跨行分支、只在 intentChanged 刷新、跨行永远选前帧三类错误分别必须被测试击中。

Worker 结果必须区分 fresh build/test 与已有预编译 bundle；`executed_tests == 0` 不得算 PASS。
