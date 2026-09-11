# T-1F-B10-wave-c — BUG10 缺陷 C：insertionIndex 坐标系反向（y-up）

Status: ready
Wave: BUG10-wave-c（与 wave-b、wave-a-forensics 实现文件零交集，可并行）
Role: Worker（实现+测试）→ 独立 Reviewer（只读门禁）→ Main 合并

## §1 背景（FIX-PROMPT §2，已数值证明）

`DropZoneGeometry.insertionIndex` 行划分假设 y 向下增长，生产全 y-up → 所有行并成一行、结果越界、蓝条落到下一行末帧右缘=用户「下面一行正中间那个 APP 的正中间」。测试夹具 y-down 与生产反向是 bug 逃逸直接原因（FIX-PROMPT §2.5）。功能路径（hitItem）与视觉路径不同源，功能成功仅视觉错——**只修 insertionIndex 一处**。

## §2 根因锚点（全部已实测，2026-09-02 现行树）

- Sources/AppGridUI/DragSession/DropIntent.swift:86-89 注释（「行 = 竖直不重叠的连续段」——语义对、实现偏）；:90-125 `insertionIndex(pointer:frames:)`；:99-105 行划分循环 `while end < frames.count, frames[end].frame.minY <= bottom { bottom = max(bottom, frames[end].frame.maxY); end += 1 }`（y-down 单向不等式=bug）；:98 零尺寸帧并入注释。
- 生产 y-up 证据：FolderOverlayView.swift:444 与 AppGridPageView.swift:303 均 `let y = area.maxY - CGFloat(row + 1) * (cellHeight + spacing)`；全仓 isFlipped 零命中（Sources/+Tests/ grep=0）。
- 功能路径对照（勿动）：DropIntent.swift:230-236 hitItem 命中分支 `leftHalf ? index : index+1`，不经行划分。
- 夹具（bug 逃逸根因）：Tests/AppGridUITests/Bug6DropZoneGeometryTests.swift:30-38 `gridFrames()` `ys: [Double] = [10, 110]`（y-down）。
- 消费方（只读，勿动）：DragUIVisuals.swift:138-164 `showInsertionBar`/`localInsertionIndex`、:191-206 `insertionRect`（`index >= count` 取末帧右缘分支）。
- FIX-PROMPT §2.2 数值复现脚本（Worker 先跑一遍自证理解）。

## §3 写范围 / 禁写

- 写：`Sources/AppGridUI/DragSession/DropIntent.swift`（仅 :86-125 insertionIndex 函数体+两处注释）+ `Tests/AppGridUITests/Bug6DropZoneGeometryTests.swift`（新 y-up 夹具+锁；既有断言保留）。
- 禁写：DragUIVisuals.swift（insertionRect/localInsertionIndex 勿动）；DragParameters.swift（不新增字段）；DragGeometry.swift/DropResolver/engine/coordinator；AppDelegate/FolderOverlayView/AppGridPageView；冻结树全列（PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/PagingUI/Package.swift/AppLaunchController.swift）；Docs/；无 git。

## §4 必读

Workflow/BUG10-FIX-PROMPT.md §0/§2（权威）；Workflow/decisions/D-2026-09-02-bug10-fix-plan.md D1/D4；DropIntent.swift:86-125/:230-236；Bug6DropZoneGeometryTests.swift:25-45。

## §5 实施要求（FIX-PROMPT §2.4 定案）

1. 行划分改**坐标系无关**：按「与当前行竖直区间不重叠」聚类（替代 `minY <= bottom` 单向比较）；方向由帧自身竖直区间给出，不硬编码上下。零尺寸帧并入当前行语义保留（原 :98）。
2. 行序按**阅读序**（帧已按阅读序传入，`range.lowerBound` 被 :123-125 直接当「更早行条目总数」用，行序乱=落点错）。
3. 纯函数：无新参数、无新字段、无新增 DragParameters。
4. 同步更新 :86-89 与 :98 注释，使注释与实现一致（BUG6 §0 先例：注释与实现不一致 = Reviewer FAIL）。

## §6 验证与验收（回归锁，D4 必做）

- 新增 y-up 夹具（镜像生产：`y = maxY - (row+1)*pitch`，5 列/spacing 16/cellHeight 88 复刻 FIX-PROMPT §2.2 几何）：右列最上条目右缘外 → 期望该条目之后（主症状锁）；多行各行缝隙落点�`insertionIndex ∈ [0, count]` 闭区间边界锁；顶层同构锁（AppGridPageView 同构 y-up 场景一条）。
- 既有 y-down 断言全部保留且应通过；若有断言在正确实现下必然改变 → 结果文件写明原期望值本身错误的推导，不得静默删改。
- 复现脚本先行：把现行 insertionIndex 逐字抄出喂 §2.2 生产几何，确认 rowRanges=[0..<8]、index=8（bug 再现），修后同输入得 5。
- `swift build -c debug` / `-c release` exit 0；`swift test` 全量（1062+新增）。

## §7 输出纪律

results 写 Workflow/results/T-1F-B10-wave-c.md：改动清单/复现脚本前后读数/测试证据（executed/failures 原文）/deviation 逐条/未触碰声明。禁大代码块贴报告。

## §8 风险与 Red flags

- 「顺手统一」hitItem 与 insertionIndex = 规格理解错误（两者不同源是既有设计，§1）。
- 行序未按阅读序 → nearest 行选错（更早行条目总数错位），y-up 夹具多行用例必须覆盖 ≥3 行。
- 出现「必须改 insertionRect/DragParameters/冻结文件」的冲动 = 理解错误，回读 §2/§5。