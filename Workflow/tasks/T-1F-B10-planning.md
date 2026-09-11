# T-1F-B10-planning — BUG10 修复波次规划（Main 运行时任务）

- Status: ready
- Role: Chief（glm-5.3，subagent e49900a4 续用）
- 上游：`Workflow/BUG10-REPORT.md`（用户实机复测 3 缺陷）+ `Workflow/BUG10-FIX-PROMPT.md`（OBS 审查结论，334 行，证据等级声明 §0）
- 基线：1062/0（BUG9 wave-a+b 已合并）；debug/release exit 0

## §1 背景（Main 已核验，Chief 不重新诊断）

三缺陷确定性不同（FIX-PROMPT §0 证据等级表）：
- **缺陷 C（蓝条错位）**：已数值证明 → 可直接实现。根因=`DropZoneGeometry.insertionIndex`（Sources/AppGridUI/DragSession/DropIntent.swift:90-125，行划分循环 :95-105 `frames[end].frame.minY <= bottom`）假设 y 向下增长，生产全 y-up（全库无 isFlipped；FolderOverlayView.layoutPanel:444 与 AppGridPageView.layout:303 均 `y = area.maxY - (row+1)*pitch`）→ 全行并一。测试夹具 gridFrames()（Tests/AppGridUITests/Bug6DropZoneGeometryTests.swift:30-38）y-down 与生产反向 = bug 逃逸原因。功能对视觉错=hitItem 分支（:230-236）与 insertionRect 两路径不同源 → **只修 insertionIndex 一处，别动 insertionRect**。
- **缺陷 B（preview 在主界面）**：已静态证明 → 可直接实现。层级遮挡：preview attach 到 surface（DragUIVisuals.host=surface，installDragUI:547，attach:214-217），folderOverlay 挂 container（AppDelegate.swift:825-826，后添加更上层，FolderOverlayView.init:142 black 0.35 遮罩）→ preview 被盖住。坐标换算正确（memberDragItemFrames convertedTo:host，FolderOverlayView.swift:109）不要改。方案 B1（宿主随 scope 切换为 overlay，推荐）/ B2（独立无边框 NSWindow，**用户已裁决可用**，FIX-PROMPT §3.2 标注 PUBLIC_DOCUMENTATION；CONTAMINATION_LOG.md 已登记解冻）。
- **缺陷 A（建夹后点不开）**：强假设未实机确认 → **先取证，禁止直接改**。census 日志（/tmp/bug9_census_run2.log 71-115 行）s8d 7→29 连续 23 次窗口层放行但 s10 恒不增，前接 s4a+s4d（空白点击关 folder）→ 触发条件=开过 folder 再关（非建夹）。静态假设=closeFolder（AppDelegate.swift:774-782）只 removeFromSuperview，FolderOverlayView.hitTest:297-303 非按钮区恒返回 self → overlay 残留命中吞事件。FIX-PROMPT §4.4 取证复测（零行为变更 census 布� 4 处 + 用户实机 6 步脚本 + 判别表 4 行）→ 读数回 Main → 判别表命中 → 再拆实现包。

## §2 Chief 产出要求

1. **Workflow/PLAN.md 追加**「Phase 1F BUG10-fix（2026-09-02）」节：DAG（C→B→A 建议序；A 取证任务包先行）、写范围表、缺陷→验收映射。
2. **Workflow/decisions/D-2026-09-02-bug10-fix-plan.md**：决策 D1-D6（含 B1 vs B2 定案——用户已裁决 B2 可用，Chief 权衡改动面/可测性后定案并写明理由；A 取证前置门；C 单点修复范围；回归锁 y-up 夹具必做；并发资格）。
3. **任务包**（格式同既往，Status: ready/blocked）：
   - `T-1F-B10-wave-c.md`（缺陷 C：DropIntent.swift insertionIndex 坐标系无关重写 + 注释同步 :86-89/:98 + y-up 夹具回归锁 + [0,count] 边界锁 + 顶层同构锁；禁写 insertionRect/DragParameters/冻结树）
   - `T-1F-B10-wave-b.md`（缺陷 B：B1 或 B2 定案后写死；宿主切换幂等/坐标系同源测试锁/move-out 跨 scope 测试；禁写冻结树）
   - `T-1F-B10-wave-a-forensics.md`（缺陷 A 取证：零行为变更 census 布点 4 处=FolderOverlayView.hitTest 入口（参与次数+superview==nil 状态位）/mouseDown 静默 return 路径(:281)/closeFolder 后 overlay.superview 状态位/blankClickResolvesToCell 命中链含 FolderOverlayView 判��位；用户实机 6 步复测脚本；判别表 4 行；**Status: ready，独立于 C/B 可先行**）
   - `T-1F-B10-wave-a-fix.md`（缺陷 A 实现：**Status: blocked**，BLOCKED 条件=取证读数回 Main + 判别表命中某行后解除）
4. 全部 file:line 引用对照源码核实；不二次诊断根因；不读禁止来源；不改产品/测试/冻结代码。

## §3 必读清单（Chief）

- Workflow/BUG10-FIX-PROMPT.md（全文，权威）
- Workflow/BUG10-REPORT.md（背景）
- Sources/AppGridUI/DragSession/DropIntent.swift（:86-125 行划分 + :230-236 hitItem）
- Sources/AppGridUI/DragUI/DragUIVisuals.swift（:57-76 showPreview / :89-114 updateIntent / :138-164 showInsertionBar+localInsertionIndex / :191-206 insertionRect / :214-217 attach）
- Sources/PagingPrototypeApp/AppDelegate.swift（:208-218 层级 / :547 installDragUI / :627-664 makeDragGeometry / :774-782 closeFolder / :824-828 refreshFolderOverlay / :1125-1138 blankClickResolvesToCell）
- Sources/AppGridUI/FolderOverlayView.swift（:106-116 memberDragItemFrames / :267-303 mouseDown+hitTest / :420-451 layoutPanel）
- Tests/AppGridUITests/Bug6DropZoneGeometryTests.swift（:30-38 gridFrames y-down 夹具）
- PROVENANCE/CONTAMINATION_LOG.md（B2 解冻记录，只读）

## §4 红线

- 冻结树零触碰：Sources/PagingCore、AppCatalogCore、MacAppCatalog、AppIconPipeline、PagingTelemetry、PagingUI、Package.swift、PagingPrototypeApp/AppLaunchController.swift（handleCell 校验链 :129-143 不可改；A 若定位校验链改调用方）。
- 禁读 LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse/Ghidra/otool dump。
- 参数纪律：本次不新增 DragParameters 字段。
- 隐私：census sink 只允许中性名+计数+布尔状态位；A/B/C 代称。
- 无 git 操作。

## §5 输出纪律

- 任务包先写 in-progress 再定稿；回复 <250 词；无大代码块。
- 产出物落盘后回复：文件清单 + 波次 DAG + 并发建议 + 待 Main 核验点。
