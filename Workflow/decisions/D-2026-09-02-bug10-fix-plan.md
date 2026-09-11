# D-2026-09-02-bug10-fix-plan — BUG10 修复规划决策

Status: adopted（BUG10 规划轮，Chief 定案；上游 FIX-PROMPT §0 证据等级为权威）

## D1 C 单点修复范围（数值证明 → 直接实现）

只改 `DropZoneGeometry.insertionIndex`（DropIntent.swift:90-125）：行划分循环 :99-105 `frames[end].frame.minY <= bottom` 是 y-down 单向不等式，生产全 y-up（isFlipped 全仓零命中；FolderOverlayView.swift:444 / AppGridPageView.swift:303 均 `y = area.maxY - (row+1)*pitch`）→ 全行并一、越界 8→末帧右缘=用户「下一行正中间」。修法=竖直区间重叠聚类（不假设方向，零尺寸帧并入语义 :98 保留）+ 行序按阅读序（帧已按阅读序传入，换行=与当前行竖直不重叠）。`:86-89` 与 `:98` 注释同步。**不改 insertionRect**（DragUIVisuals.swift:191-206）、不动 hitItem 功能路径（DropIntent.swift:230-236 与行划分不同源、本就正确——BUG6 §0「净删/单点」先例）。

## D2 B1 vs B2 定案：**B1**（宿主随 scope 切换）

- 依据：FIX-PROMPT §3.2 建议 B1（改动面小、可测、复用既有坐标链）；B2 虽经用户裁决解冻（CONTAMINATION_LOG.md:22 记录），但改动面=窗口生命周期+屏幕坐标转换+teardown/Reduce Motion 全路径重写，风险与本缺陷（单层级遮挡）不成比例。
- B1 风险两点写入 wave-b 必测：①attach（DragUIVisuals.swift:214-217 `view.superview !== host` 短路）切换宿主时 AppKit 自动从旧父移除——幂等性要有测试（无视图在两父间漂移、teardown :125-131 零残留）；②preview 坐标系与 pointerDragged（DragUISessionCoordinator.swift:257-259 `visualHost.convert`）**必须同源**——切换 visualHost 与 visuals.host 是同一动作两半，契约测试锁死。host 声明现为 `private weak var host`（DragUIVisuals.swift:19），改可切换并写清 weak 生命周期。
- 附带项（§3.3）：makeDragGeometry（AppDelegate.swift:627-664）注释写死「哪些帧在哪个坐标系」契约；move-out 跨 scope 测试必做。

## D3 A 取证前置门（强假设 → 禁止直接改）

**D3 增补（Main 重钉 census run2 后 Chief 定夺）**：sA_launch_accepted ×4-8 实落在 :121-149（s8d 死窗 :65-115 之后、s10 恢复 :190 之前）→ 存在「s10 不增但 sA 增」路径 = Path A surface 手势未死。**定夺一**：forensics 加布点 5（`surface_gesture_fired`）。**定夺二（Main 实机核实后终局）**：AppLaunchController.swift:95 手势 target/action 均指向 AppLaunchController 自身（handleGesture @objc private :102-106），AppDelegate 无挂接闭包 → **s18 不落地、不申请冻结面升级**。理由：①判别已足够——sA 增（onLaunchAttempt :377-385）+ s10 不增即推出 Path A 承接；s18 仅能多区分「手势触发但 handleCell 未达」中间态，run2 观测中该中间态无证据对应；②冻结树文件任何写入（含纯计数）都使合并面/Reviewer 门禁/回归基线失守，冻结语义不宜做「纯计数豁免��例外；③C 方案（KVO/通知/手势 delegate 拦截）均为侵入式替换或 hook，复杂度与收益不成比例且引入行为风险，一并否决。判别表第 5 行降级为「s8d 增、s10 不增、s14 不参与、sA 增」。Path A 自身不可靠性（AppDelegate.swift:935-942 自述位移>10pt 静默失败）不改、另立观察项——用户「全部打不开」若实为「时通时断」，以 census 读数归因。

FIX-PROMPT §4.1-4.3 已把触发条件修正为「开过 folder 再关」（census run2 时序：s4a+s4d 空白关夹后 s8d 7→29 连续 23 次窗口放行而 s10 恒 5 不增；s8e key1_active1 排除 R5；s13a/b/s9b 配平排除 R2 滞留；s10 早期正常触发排除 R1 路由）。静态假设=closeFolder（AppDelegate.swift:774-782）只 removeFromSuperview，而 hitTest（FolderOverlayView.swift:297-303）非按钮恒 self → overlay 残留吞事件。**wave-a-fix 保持 blocked**；解除条件=取证读数回 Main 且判别表命中某行。命中行决定写范围：假设成立→overlay 移除/hitTest 生命周期；s7b→launchMember 调用方（AppDelegate）；sA_rejected→handleCell 校验链**调用方**（AppLaunchController.swift:129-143 本体冻结永不改）；步6也复现→回 Main 重新定位。

## D4 C 回归锁（必做，bug 逃逸根因）

测试夹具 Bug6DropZoneGeometryTests.swift:30-38 `gridFrames()` y-down 与生产反向是 bug 逃逸直接原因。wave-c 必做：①新增 y-up 夹具（镜像生产 `y = maxY - (row+1)*pitch`）——结构性回归锁；②既有 y-down 断言保留（坐标系无关实现应两者皆过；若某条必然改变须在结果文件写明原期望值错误推导）；③`[0,count]` 闭区间边界锁；④顶层同构锁（AppGridPageView 同 y-up）。

## D5 并发资格

wave-c（DropIntent.swift + 几何测试）∥ wave-b（DragUIVisuals/Coordinator/AppDelegate 切换驱动）∥ wave-a-forensics（FolderOverlayView/AppDelegate census 布点）三者实现文件零交集，准许并行（max_worker_concurrency=3，MAIN_BRIEF 1E 沿用）。AppDelegate.swift 双波共写（b/forensics）区域不交集但 Main 控制合并序（建议 forensics 先并）；wave-a-fix blocked，独立 Reviewer。

## D6 纪律

不新增 DragParameters 字段（FIX-PROMPT §5：想加参数=方向错，先报 Main）；census sink 中性名+计数+布尔位；B2 仅作记录不采用；全部 file:line 以本决策与任务包核验值为准（FIX-PROMPT 若与源码漂移以源码为准并报 deviation）。