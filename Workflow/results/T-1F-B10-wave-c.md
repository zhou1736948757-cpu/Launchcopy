# Worker Result — T-1F-B10-wave-c（BUG10 缺陷 C：insertionIndex 坐标系反向 y-up）

- **Task ID**: T-1F-B10-wave-c
- **Role**: Worker（fresh context 实现 worker，deepseek-v4-flash:0731）
- **日期**: 2026-09-02
- **AccessDeclaration**: NO_PRIOR_EXPOSURE
  - 仅读取：任务包 `Workflow/tasks/T-1F-B10-wave-c.md`、`Workflow/BUG10-FIX-PROMPT.md` §0/§2、
    `Workflow/decisions/D-2026-09-02-bug10-fix-plan.md` D1/D4、`DropIntent.swift`、`DragGeometry.swift`（只读）、
    `Bug6DropZoneGeometryTests.swift`、`DragSessionTestSupport.swift`（只读）、既有 results 样例（格式参考）。
  - **未读取**：LaunchBetter / BuhoReverseNotes / 2026-08-25-buho-launchpad-reverse / Ghidra / otool dump（红线零触碰）。
  - 无 git 操作（仓库无任何 commit，`git status` 仅用于自证改动面）；未改 Docs/。

## 改动清单（仅 2 文件）

| 文件 | 改动 |
|---|---|
| `Sources/AppGridUI/DragSession/DropIntent.swift` | 仅 `insertionIndex` 函数体（:90-125 区域）+ 两处注释（:86-89 与 :98）。行划分由 `frames[end].frame.minY <= bottom` 单向比较改为**坐标系无关的竖直区间重叠聚类**：当前行区间 = 已并入帧 minY...maxY 并集，后续帧 `minY <= bottom && maxY >= top` 才并入（含边界 → 零尺寸帧并入语义保留）；方向由帧自身区间给出，不硬编码上下；行序 = 帧传入阅读序（`range.lowerBound` 仍作更早行条目总数）。无新参数、无新字段、未新增 DragParameters 字段。 |
| `Tests/AppGridUITests/Bug6DropZoneGeometryTests.swift` | 新增 `productionYUpFrames(rowCounts:)` 夹具（镜像生产 `y = maxY - (row+1)*pitch`，maxY=600 / pitch=104 / 5 列 / spacing 16 / cellHeight 88，复刻 FIX-PROMPT §2.2 几何）+ 4 个 y-up 回归锁测试（见下）。既有 y-down 断言全部保留未动。 |

## 复现脚本（先行，§6 必做）

脚本 `/tmp/bug10c_repro.swift`：把现行 `insertionIndex` 逐字抄出（修前版本），喂 FIX-PROMPT §2.2 生产几何（8 成员 / 5 列 → 2 行 / y-up）。

**修前读数**（bug 再现，与 FIX-PROMPT §2.2 逐字吻合）：

```
rowRanges = ["0..<8"]        ← 期望 [0..<5, 5..<8]
pointer = (530.0, 540.0) = B(idx4) 右缘外
insertionIndex = 8   (frames.count = 8)
>>> index >= count → insertionRect 取【末帧】idx7 右缘画条（bug 再现）
```

**修后读数**（同输入，Python 与 Swift 实现逐行同构重算）：

```
rowRanges = ['0..<5', '5..<8']
insertionIndex = 5 (frames.count = 8)
```

## 新增回归锁（4 测试）

| 测试 | 锁 |
|---|---|
| `testYUpRightColumnTopItemRightEdgeOutsideInsertsAfterIt` | 主症状锁：右列最上条目（idx4）右缘外 (530,540) → 5（修前 = 8 越界） |
| `testYUpMultiRowGapLandings` | 多行（3 行 [5,5,3]）缝隙落点：行 0/1/2 首条目前 = 0/5/10、行 1 缝隙 (120,436) = 6、行缝平距取更早行 (100,488) = 1 |
| `testYUpInsertionIndexStaysWithinClosedRange` | 闭区间边界锁：9×6 采样点全在 [0, count]（修前 y-up 下越界 = 8） |
| `testYUpTopLevelIsomorphicGrid` | 顶层同构锁（AppGridPageView 同构 y-up）：行序 = 阅读序，末行末条目后 = 13 = count（闭区间上界） |

## 测试证据（原文）

```
swift build -c debug  → Build complete! (14.79s)  exit 0
swift build -c release → Build complete! (60.37s) exit 0

swift test（全量）：
Test Suite 'PagingPrototypePackageTests.xctest' passed at 2026-09-02 16:45:37.988.
	 Executed 1066 tests, with 0 failures (0 unexpected) in 53.190 (53.587) seconds
Test Suite 'All tests' passed at 2026-09-02 16:45:37.988.
	 Executed 1066 tests, with 0 failures (0 unexpected) in 53.190 (53.610) seconds
exit 0

swift test --filter Bug6DropZoneGeometryTests：
Test Case '-[AppGridUITests.Bug6DropZoneGeometryTests testYUpInsertionIndexStaysWithinClosedRange]' passed (0.003 seconds).
Test Case '-[AppGridUITests.Bug6DropZoneGeometryTests testYUpMultiRowGapLandings]' passed (0.001 seconds).
Test Case '-[AppGridUITests.Bug6DropZoneGeometryTests testYUpRightColumnTopItemRightEdgeOutsideInsertsAfterIt]' passed (0.001 seconds).
Test Case '-[AppGridUITests.Bug6DropZoneGeometryTests testYUpTopLevelIsomorphicGrid]' passed (0.001 seconds).
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.080 (0.094) seconds
```

计数：基线 1062 + 新增 4 = **1066 全绿**（0 failures）。

## Deviations

1. **无**。实现、注释、夹具、锁全部按任务包 §5/§6 与 FIX-PROMPT §2.4/§2.5 定案执行；无断言在正确实现下改变（既有 y-down 断言在修前修后均通过——坐标系无关实现两者皆过，符合 D4 预期）。
2. 复现脚本存放于 `/tmp/bug10c_repro.swift`（不入库，任务包未要求入库；结果文件含前后读数）。

## 未触碰声明

- 冻结树零改动：`Sources/PagingCore`、`AppCatalogCore`、`MacAppCatalog`、`AppIconPipeline`、`PagingTelemetry`、`PagingUI`、`Package.swift`、`PagingPrototypeApp/AppLaunchController.swift` 均未触碰（`find Sources Tests -newer <task> -name "*.swift"` 仅命中上述 2 个写范围文件）。
- 禁读来源零接触：LaunchBetter / BuhoReverseNotes / 2026-08-25-buho-launchpad-reverse / Ghidra / otool dump。
- 未改 `DragUIVisuals.swift`（insertionRect/localInsertionIndex 勿动）、`hitItem` 功能路径（DropIntent.swift:230-236 未动）、`DragParameters`（无新字段）、Docs/。
- 无 git 操作（仓库无 commit，无法 `git diff --stat`；以文件 mtime 扫描自证改动面）。
