# T-1F-B11-row-boundary-indicator

状态：**实现完成；fresh runtime 验证受环境阻断，交 Reviewer/Main 复核**

任务包：`Workflow/tasks/T-1F-B11-row-boundary-indicator.md`

角色：Luna Worker。无 git 操作；仅写入任务包允许的两个实现文件、一个新测试文件和本结果文件。

## 1. 改动

### `Sources/AppGridUI/DragUI/DragUIVisuals.swift`

- 保留 public `updateIntent(_:geometry:)` 签名；新增模块内
  `updateIntent(_:geometry:pointer:)` seam，coordinator 可将当前 pointer 传入视觉层。
- `insertionRect` 仅在相邻帧竖直区间真正不重叠时走跨行分支：
  - pointer 更接近前帧行：前帧右缘；
  - pointer 更接近后帧行：后帧左缘（沿用首帧左侧的 4pt inset）；
  - 距离相等：固定前帧（较早阅读序行）；
  - y/height 取所选 anchor frame，自身不做跨行 union；算法不假设 y-up/y-down。
- public 无 pointer 兼容入口的跨行 canonical fallback 固定为前帧右缘，避免再次产生跨行中点错误；同行仍使用原中点，首项/尾项/空 frames 逻辑不变。
- `.insertion` 与 `.topLevelTarget` 继续共用 `showInsertionBar`/`insertionRect`；分页 global→local 回减未改。
- 增加模块内 `pointerAwareRefreshCountForTesting`，仅用于证明非 insertion 视觉没有逐帧重复刷新，不构成 public API。

### `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift`

- `intentChanged` 路径继续以当前 pointer 更新一次视觉。
- 每次有效 `pointerDragged` 的补刷严格限于 `.insertion` / `.topLevelTarget`；`.createFolder`、`.intoFolder`、`.invalid` 不在 intent 未变时重建视觉/layer。
- preview、edge paging、resolver、mutation、commit 和 generation 语义未改。

### `Tests/PagingUITests/Bug11RowBoundaryIndicatorTests.swift`

新增 **10 个**测试：

1. y-up `[5,3]` 行末右半：intent 5，bar `(521,496,3,88)`，拒绝旧 `(272.5,392,3,88)`。
2. 同一 intent 5 的下一行首项左半：bar `(20,392,3,88)`。
3. coordinator 同一 session 跨行移动、intent 不变时蓝条换行。
4. 行末右缘外空白：BUG10-C `insertionIndex == 5` 且前行右缘。
5. public 无 pointer fallback：跨行 index 5 仍前行右缘。
6. create-folder intent 不变时不重复 pointer-aware 刷新。
7. into-folder intent 不变时不重复 pointer-aware 刷新。
8. 同行中点、首项前、末项后、空 frames 控制项。
9. `.topLevelTarget` page 1 global 40→local 5，覆盖跨行两侧锚点。
10. y-down 镜像与 gap tie（较早阅读序行胜出）。

## 2. 几何判定要点

任务夹具实际为 5 列生产网格：`frame[4] = (436.8,496,87.2,88)`，`frame[5] = (24,392,87.2,88)`。

| pointer 位置 | intent | 选定 anchor | 期望 bar |
|---|---:|---|---|
| frame[4] 右半 `(510,540)` | 5 | frame[4] | `(521,496,3,88)` |
| frame[5] 左半 `(40,436)` | 5 | frame[5] | `(20,392,3,88)` |
| 两行 gap tie | 5 | 较早阅读序行 | 前行右缘 |

## 3. 验证事实

### 3.1 本次源码静态编译（已运行）

- `swiftc -typecheck`：AppGridUI 全部 **44 个** Swift 源文件，`-Onone`：exit 0。
- 同一 44 文件集合，`-O`：exit 0。
- 用本次修改后的 AppGridUI 临时模块对新测试文件执行 `swiftc -typecheck`：exit 0。
- 仅有既存 warning（`DragUIVisuals.showPreview` 的 unused `host`、`FolderOverlayView` 的 unused `index`），无本波错误。

### 3.2 fresh SwiftPM 尝试（阻断，不能算 PASS）

以下命令均在一次有界尝试中执行；未绕过 sandbox，未重复重试：

| 命令 | 结果 |
|---|---|
| `swift test --filter Bug11RowBoundaryIndicatorTests` | exit 1；manifest 编译遇到 `sandbox_apply: Operation not permitted`、clang module cache 不可写及 `.build/build.db` readonly；最终 `Executed 0 tests`，新测试未运行。 |
| `swift test --filter Bug8VisualIndexTests` | exit 1（同一 readonly/build 错误）；随后复用了已有 bundle 输出 9/0，非 fresh。 |
| `swift test --filter Bug6DropZoneGeometryTests` | exit 1（同上）；已有 bundle 输出 14/0，非 fresh。 |
| `swift test --filter DragUIIntegrationTests` | exit 1（同上）；已有 bundle 输出 10/0，非 fresh。 |
| `swift test` | exit 1（manifest/cache/build DB）；旧 bundle 后续输出 1123/0，不能视为本次源码全量通过。 |
| `swift build -c debug` | exit 1；manifest/cache/build DB 权限阻断。 |
| `swift build -c release` | exit 1；manifest/cache/build DB 权限阻断。 |

### 3.3 已有预编译 bundle（已运行，明确为非 fresh）

直接 `xcrun xctest -XCTest ... .build/arm64-apple-macosx/debug/PagingPrototypePackageTests.xctest` 的旧 bundle 结果：

- `Bug8VisualIndexTests`：**9/0**；
- `Bug6DropZoneGeometryTests`：**14/0**；
- `Bug10PreviewHostTests`：**7/0**；
- `DragUIIntegrationTests`：**10/0**。

这些结果只说明既有预编译回归 bundle 在当前环境可执行，**不包含本次新增的 B11 测试或本次源码重建**。

## 4. 变异证明

由于 fresh B11 runtime 被 sandbox 阻断，以下为测试设计的静态判别矩阵，尚未声称已执行：

| 变异 | 应被击中的测试 | 预期错误 |
|---|---|---|
| 删除跨行分支、始终取相邻帧中点 | 1、2、4、5、9、10 | 重新得到旧跨行中点或错误 y/height；测试 1 明确拒绝 `(272.5,392,3,88)`。 |
| coordinator 只在 `intentChanged` 刷新 | 3 | 第二次 pointerDragged 的 intent 仍为 5，但蓝条停留在前一行。 |
| 跨行始终选前帧 | 2、3、9、10 | 下一行首项左半无法切到 `(20,392,3,88)`/对应 y-down 后行锚点。 |
| 非 insertion intent 仍逐帧刷新 | 6、7 | `pointerAwareRefreshCountForTesting` 在相同 create/into-folder intent 的第二次 pointerDragged 后错误增加。 |

注：B11 核心跨行变异由 1、2、4、5、9、10 覆盖，6/7 专门锁刷新预算。

## 5. 未触碰清单

零改动：

- `Sources/AppGridUI/DragSession/DropIntent.swift`
- `DragGeometry.swift`、`DropResolver.swift`、`DragMutationEngine.swift`、`DragSessionController.swift`
- `Sources/PagingPrototypeApp/AppDelegate.swift`、`AppLaunchController.swift`
- `Sources/PagingCore/`、`AppCatalogCore/`、`MacAppCatalog/`、`AppIconPipeline/`、`PagingTelemetry/`、`PagingUI/`
- `Package.swift`、Docs、MEMORY、现有 Workflow 历史文件
- 既有测试文件（仅新增 `Bug11RowBoundaryIndicatorTests.swift`）

未执行 git add/commit/reset/restore。

## 6. Reviewer focus

1. 检查 `pointerDragged` 的 switch 是否确实只让 insertion/topLevelTarget 进入 pointer-aware 补刷，create/into-folder 只经 intentChanged。
2. 复核 public 无 pointer 跨行 fallback 为前帧右缘，且同行 midpoint 与 BUG8 global→local 回减未回退。
3. 在可写 build scratch 或解除环境权限后运行 `swift test --filter Bug11RowBoundaryIndicatorTests`，应执行 10 tests；再运行任务包列出的 Bug8/Bug6/DragUIIntegration、全量及 debug/release build。
4. 对三类变异实际执行并记录失败计数；本结果中的变异部分目前是静态预期，不是 runtime 事实。
5. 独立检查 commit order/generation 回归（本波未改 resolver/engine，当前仅有非 fresh 预编译集成证据）。

## 7. Main fresh 验证补录（2026-09-05）

Worker 沙箱中的 SwiftPM 阻断已由 Main 在实际项目目录中解除并重新验证；以下结果取代 §3.2 中“尚未 fresh”的证据上限：

- `swift test --filter Bug11RowBoundaryIndicatorTests`：**10 tests / 0 failures**。
- BUG8、BUG6、BUG10PreviewHost、DragUIIntegration 相关回归：**40 tests / 0 failures**。
- `swift test`：**1133 tests / 0 failures**，exit 0。
- `swift build -c debug`：exit 0。
- `swift build -c release`：exit 0；仅见既存 unused-variable warnings。
- 冻结路径 hash 复核保持不变；产品实现仍只涉及 `DragUIVisuals.swift` 与 `DragUISessionCoordinator.swift`，测试只新增 `Bug11RowBoundaryIndicatorTests.swift`。

独立 Reviewer 报告：`Workflow/reviews/T-1F-B11-row-boundary-indicator-r1.md`，结论 **PASS**（BLOCKER 0 / MAJOR 0 / MINOR 0）。真实窗口/触控板拖拽仍作为最终人工观察项，不冒充自动化覆盖。
