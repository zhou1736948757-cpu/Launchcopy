# T-1F-B10-wave-b — BUG10 缺陷 B：drag preview 被 overlay 遮挡（方案 B1 定案）

Status: ready
Wave: BUG10-wave-b（与 wave-c、wave-a-forensics 实现文件零交集，可并行；AppDelegate 与 forensics 区域不交集，合并序 Main 定）
Role: Worker（实现+测试）→ 独立 Reviewer（只读门禁）→ Main 合并

## §1 背景（FIX-PROMPT §3，已静态证明）

preview attach 到 surface（DragUIVisuals.host=surface，attach :214-217），folderOverlay 挂在 surface 的**父视图** container（AppDelegate.swift:824-828）且后添加更上层、init:142 遮罩 black 0.35 → preview 被整块盖住，用户看到的是透过遮罩的主界面网格位置 preview。坐标换算本身正确（memberDragItemFrames(convertedTo:)，FolderOverlayView.swift:106-116）**不要改**。

## §2 方案定案（决策 D2：B1，B2 不采用）

folder scope 下把 DragUIVisuals 视觉宿主切换为 overlay（topLevel 维持 surface 不变）。B2（独立无边框窗口）虽经主控解冻（CONTAMINATION_LOG.md:22），但改动面（窗口生命周期/屏幕坐标/teardown/Reduce Motion 全路径）与本缺陷不成比例，**本波不采用**，记入决策文件作后续选项。

## §3 根因锚点（全部已实测）

- Sources/AppGridUI/DragUI/DragUIVisuals.swift:19 `private weak var host: NSView?`；:57-76 `showPreview`（attach(previewView)）；:89-114 `updateIntent`（.insertion 用 geometry.itemFrames / .topLevelTarget 用 topLevelFrames，两坐标系问题源）；:125-131 `teardown`（clearAll + 三视图 removeFromSuperview）；:214-217 `attach`（`guard view.superview !== host` 短路→切换宿主时 AppKit 自动从旧父移除，幂等性必须测试锁）。
- 宿主同源约束：DragUISessionCoordinator.swift:160 `public weak var visualHost: NSView?`、:257-259 `pointerDragged` 用 `visualHost.convert` —— preview 坐标系与指针坐标系必须同源，否则偏移（方案最易错点，测试锁）。
- 层级：AppDelegate.swift:208-213 container/contentView+surface；:547 `DragUISessionCoordinator(host: surface)`；:824-828 refreshFolderOverlay（`folderOverlay.superview == nil` 时挂 `container ?? surface`）。
- 坐标链（勿动，契约引用）：FolderOverlayView.swift:106-116 memberDragItemFrames(convertedTo:)。
- makeDragGeometry（AppDelegate.swift:627-664）：host 取 `dragCoordinator?.visualHost`（:631）——宿主切换后帧转换目标随动，契约注释写死。

## §4 写范围 / 禁写

- 写：`Sources/AppGridUI/DragUI/DragUIVisuals.swift`（host 可切换 + attach/teardown 幂等）+ `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift`（仅 visualHost 切换面/同源，census 区零触碰）+ `Sources/PagingPrototypeApp/AppDelegate.swift`（仅 refreshFolderOverlay 处切换驱动 + makeDragGeometry 坐标系契约注释）+ 测试（新文件 `Tests/AppGridUITests/Bug10PreviewHostTests.swift` 或并入既有，报告声明）。
- 禁写：冻结树全列（含 AppLaunchController.swift）；DropIntent.swift（wave-c 领地）；DragParameters（不新增字段）；FolderOverlayView.swift（坐标链与 forensics 布点领地）；Docs/；无 git。

## §5 必读

Workflow/BUG10-FIX-PROMPT.md §3（权威）；decisions/D-2026-09-02-bug10-fix-plan.md D2；§2 全部锚点文件。

## §6 实施要求

1. DragUIVisuals host 由固定改为**可切换**（建议 `func setHost(_:)` 或等价；保持 weak 语义）；切换时旧宿主视图安全迁移（attach 幂等：同一 NSView 不得同时挂在两父/漂移；teardown 后零残留）。
2. 宿主切换与 `coordinator.visualHost` 切换**同一动作/同一处驱动**（AppDelegate 刷新 overlay 时驱动），保证 preview 坐标系=指针坐标系同源——契约测试锁死。
3. makeDragGeometry 注释写死「哪些帧在哪个坐标系」契约（成员帧→overlay 系；顶层帧→surface 系；move-out 横跨两 scope 的帧归属显式化，FIX-PROMPT §3.3）。
4. 顶层拖拽（folder 未开）零行为变化；Reduce Motion 路径不变（:73-79 既有分支不触碰）。
5. 不新增 DragParameters 字段；不改坐标换算本身（memberDragItemFrames/DropIntent 产出边界）。

## §7 验证与验收

- 测试：①宿主切换幂等（重复 setHost 同值/异值、切换后 attach 不重复 addSubview、teardown 零残留）；②preview 坐标=visualHost.convert 同源锁（切换后不偏移）；③move-out 跨 scope：成员拖到顶层缝隙，preview 与顶层蓝条同系不跳变；④顶层拖拽回归（host 恒 surface，既有测试全绿）。
- `swift build` debug/release exit 0；`swift test` 全量（1062+新增）。
- 实机验收：folder 内拖成员 preview **面板内跟手**；move-out 不跳变；顶层零回归。

## §8 输出纪律 / §9 风险

- results 写 Workflow/results/T-1F-B10-wave-b.md（同既往：改动清单/测试证据原文/deviation/未触碰声明）。
- Red flags：①visualHost 与 preview host 不同步 = 本方案最易错点，契约测试不过不得合并；②发现需改 DropIntent/insertionIndex 才能实现 → 越界，报 Chief；③想引入独立窗口（B2）= 偏离 D2 定案，停手。