# T-1F-B11-row-boundary-indicator — Luna 独立 Reviewer r1

- 角色：独立 Reviewer（Luna，只读；未修改产品源码或测试）
- 评审对象：`DragUIVisuals.swift`、`DragUISessionCoordinator.swift`、`Bug11RowBoundaryIndicatorTests.swift`，以及任务包和 Worker 结果
- 评审日期：2026-09-05（Asia/Shanghai）
- 结论：**PASS**
- 计数：BLOCKER 0 / MAJOR 0 / MINOR 0 / QUESTION 2

## 1. 判定依据

根因与实现一致：分类层仍把行末项右半和下一行首项左半编码为同一个线性 insertion index；修复只改变视觉层对该 index 的锚点选择，没有修改 `DropIntent`、resolver、mutation 或持久化语义。

### 1.1 `DragUIVisuals` 视觉几何

- public `updateIntent(_:geometry:)` 签名仍在，且只增加了 module-internal 的 `updateIntent(_:geometry:pointer:)` seam；外部调用方无需改变。
- `.insertion` 与 `.topLevelTarget` 都经过同一个 `showInsertionBar` / `insertionRect`，因此共享修复。
- `insertionRect` 保留 `index <= 0`、`index >= frames.count` 和同行 midpoint 路径；仅当相邻帧竖直区间不重叠时进入跨行分支。
- 跨行分支使用 pointer 到两个帧竖直区间的距离：前帧更近或平局选前帧右缘，后帧更近选后帧左缘；没有假设 y-up/y-down，y/height 取所选 anchor frame，不做跨行 vertical union。
- 无 pointer 的 public 兼容路径固定回退到阅读序较早的前帧右缘，不再产生旧的跨行 midpoint。
- global→local 的页注记回减仍位于 `showInsertionBar` 入口，`.insertion` 与 `.topLevelTarget` 均覆盖；未读取 `geometry.page`，没有回退 BUG8 修复。

### 1.2 `DragUISessionCoordinator` 刷新边界

- `intentChanged` 继续使用当前 pointer 更新视觉。
- 每次有效 `pointerDragged` 在 `dragging` / `edgeTurnPending` 状态下，只有 `.insertion` 和 `.topLevelTarget` 进入 pointer-aware 补刷；`.createFolder`、`.intoFolder`、`.invalid` 明确 `break`。
- 因而同一个 index 从上一行末项右半移动到下一行首项左半时，即使 `controller.lastIntent` 不变，蓝条仍会换行；create-folder 的 CAShapeLayer、folder 高亮和 invalid 清屏不会在 intent 未变的每帧重复重建。
- preview 移动、edge 调度、事件状态机、drop commit 与 generation 没有被本次补刷逻辑改写；当前代码没有触碰 resolver/mutation/commit 路径。

## 2. 必测矩阵核对

| 任务包要求 | 源码/测试证据 | 判定 |
|---|---|---|
| y-up `[5,3]` 行末右半 → 前行右缘 `(521,496,3,88)`，拒绝旧 `(272.5,392,3,88)` | `Bug11RowBoundaryIndicatorTests.testYUpLastColumnRightHalfUsesPreviousRowRightEdge`；`insertionRect` 跨行分支 | ✅ |
| 同一 index 的下一行首项左半 → 后行左缘 `(20,392,3,88)` | `testYUpSameInsertionIndexUsesNextRowLeftEdgeWhenPointerMovesThere` | ✅ |
| intent 不变的真实 coordinator 跨行刷新 | `testCoordinatorRefreshesSameIndexWhenPointerChangesRows`；第二次 pointerDragged 仍断言 `.insertion(index: 5)` 且蓝条换行 | ✅ |
| BUG10-C 右缘外空白保持 index 5 和前行锚点 | `testYUpBlankPastLastColumnPreservesBug10InsertionIndexAndAnchor` | ✅ |
| public 入口兼容及同行 midpoint/首项/末项/空 frames | `testPublicUpdateIntentUsesPreviousRowRightEdgeWithoutPointer`、`testSameRowFirstMiddleTailAndEmptyFramesRemainUnchanged` | ✅ |
| `.topLevelTarget` 与 page 1 global→local | `testTopLevelTargetUsesAnnotatedPageAndCrossRowAnchor`；global 40 回减为 local 5，并覆盖两侧 pointer | ✅ |
| y-down 镜像和平局规则 | `testYDownMirrorChoosesNearestRowAndEarlierRowOnTie` | ✅ |
| 非 insertion 视觉不得逐帧重建 | `testCoordinatorDoesNotRefreshCreateFolderForUnchangedIntent`、`testCoordinatorDoesNotRefreshIntoFolderForUnchangedIntent`；源码 switch 亦明确排除 invalid | ✅ |
| commit 顺序/generation 不由视觉修复改变 | resolver/engine 未改；既有 `DragUIIntegrationTests` 的 commit/generation 断言 + Main fresh 全量回归；B11 coordinator 另断言视觉刷新不改 layout generation | ✅ |

## 3. 变异判别力

三类核心错误均有确定性的测试击中点，静态重演与测试断言一致：

1. 删除跨行分支、始终取相邻帧 midpoint：y-up 前行右缘测试、下一行左缘测试、BUG10 空白、public fallback、topLevelTarget 和 y-down 测试中的位置或 y/height 断言会失败。
2. coordinator 只在 `intentChanged` 更新：`testCoordinatorRefreshesSameIndexWhenPointerChangesRows` 的第二次 pointerDragged 不产生 intent change，但要求蓝条从 `(521,496)` 变为 `(20,392)`，会失败。
3. 跨行永远取前帧：下一行首项左半、coordinator 跨行切换、topLevelTarget 后行锚点和 y-down 后行锚点断言会失败。

Worker 结果如实说明上述变异本轮未实际注入；本 Reviewer 也未对共享源码做变异编辑。这里的判定是基于当前测试源码、分支条件和 fresh 测试结果的机械覆盖证明，不把静态推演冒充 runtime 变异执行。

## 4. 验证证据

### Main 提供的 fresh 证据（计入结论）

- `swift test --filter Bug11RowBoundaryIndicatorTests`：Executed 10 tests, 0 failures。
- 相关回归（Bug8/Bug6/Bug10PreviewHost/DragUIIntegration）：Executed 40 tests, 0 failures。
- `swift test`：Executed 1133 tests, 0 failures，exit 0。
- `swift build -c debug`：exit 0。
- `swift build -c release`：exit 0。

### 本 Reviewer 独立尝试（不冒充 fresh PASS）

本 Reviewer 执行了 `swift test --filter Bug11RowBoundaryIndicatorTests`。当前沙箱拒绝 clang module cache 写入并将 `.build/build.db` 视为只读，命令 exit 1；随后 SwiftPM 输出复用了既有测试 bundle 的 10/0，但没有本次源码重建，因此不计为独立 fresh 测试 PASS。该环境限制与 Worker 结果披露一致，不能推翻 Main 已提供的 fresh 证据。

## 5. 范围、公共 API 与残余问题

- 任务允许的三个产品/测试文件内改动与任务目标一致；冻结树、DropIntent/DragGeometry/DropResolver/DragMutationEngine、AppDelegate、Package.swift 等不在本任务实现范围内的路径没有被当前实现引用改写。Worker 结果及 Main 的 hash 审计记录了冻结文件未变。
- 没有 git add/commit/reset/restore，也没有在本次复审中编辑任何实现或测试文件。
- 未做真实窗口/trackpad 的人工拖拽复现；自动化 fresh 证据覆盖了当前 AppKit coordinator 夹具和视觉坐标计算，但真实 window-server 坐标转换仍应由 Main/用户在实际应用中做最后观察。
- 未实际注入三类 mutant；这不是产品缺陷，属于验证证据上限，已在 §3 明确标注。

## 6. 结论

源码行为与任务包一致，新增测试覆盖了同 index 双行锚点、coordinator 同 index 刷新、双坐标方向、页索引转换、BUG10 空白区、public 兼容入口和非 insertion 刷新预算。结合 Main 的 fresh 10/0、40/0、1133/0 及 debug/release 构建证据，Reviewer 判定：**PASS**。

Confidence：**High**（完整任务/结果/源码/测试审读；核心分支逐条件核对；fresh 结果由 Main 提供并明确区分本 Reviewer 的沙箱阻断）。
