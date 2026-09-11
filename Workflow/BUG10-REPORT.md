# BUG10-REPORT — 实机复测（BUG9 wave-a/b 合并后）：3 缺陷报告（详细描述 + 上下文标注，供 OBS 审查）

- 日期：2026-09-02
- 基线：1062/0（BUG9 wave-a hitTest 漏斗 + wave-b s8e/s13 census 已合并）
- 复测环境：release 二进制（23:20 强制重建，含 wave-a+wave-b），PAGING_CLICK_CENSUS=1，census 日志 /tmp/bug9_census_run2.log
- 本报告性质：Main 只读整理（不修代码）；用户要求「详细描述 + 上下文标注」后交 OBS 审查

---

## §0 用户原话（逐字，隐私代称 A/B/C）

> 「很多个bug。首先第一个bug就是形成这个Folder以后啊，主界面的这个应用点击还是打不开。第二个打开Folder以后啊，这个应用点击确实能够打开了。但是呢，这里面这个应用啊，对吧？拖动这个应用的时候，它会显示其实是在主界面里面拖动，不是在Folder里面拖动。然后的话把这个应用拖动到右边的这个边边上，还有8个。就是拖是能拖过去的，就是放到这个边边的这个应用，比如说把边边这个应用，就是右边这个最上边这个应用称之为B的话，把这个B拖到这个B应用的这个右边的话，是能把这个应用拖过去，但是下面的蓝标啊，会显示在下面一行正中间的那个APP的正中间。」

---

## §1 缺陷 A：形成 Folder 后，主界面应用点击打不开（症状第三/四次复发）

### 现象
- 建夹（createFolder）**之后**，主界面顶层 app 点击无法启动。
- 打开 folder 后，folder **内**成员点击**能**打开（对照项正常）。

### 已确认事实（census 证据）
- BUG9 wave-a 合并前的诊断运行（/tmp/bug9_census_run.log）：9 次点击全部 `s8d_window_cell_passthrough`（窗口层判 cell）且 **s10 零输出** → cell.mouseDown 从未被调用（R1：子视图拦截）。wave-a hitTest 漏斗修复了该段。
- wave-a 合并后的运行（/tmp/bug9_census_run2.log）：前 5 次点击完整链路 `s8d → s10 → s13a → s13b/s9b`（无 s6/sA）；后续点击 `s6_dispatch_click_cell` + `sA_launch_accepted` ×3（**能启动**）；`s13a 10 == s13b 10 == s9b 10` 配平、无 s9_leak。
- **但用户本轮报告「建夹之后」主界面点击打不开**——census 日志中能启动的 3 次是否发生在建夹之前，无法从日志区分（日志无时间戳、无建夹事件计数）。**建夹是必要条件疑点**。

### 代码上下文（现行行号，2026-09-02）
- 点击派发链（Path B）：`AppGridCellView.mouseDown`（Sources/AppGridUI/AppGridCellView.swift:188-195，s10 计数 :189，`dragCoordinator ?? shared` 解析 nil 时 s11 :191）→ `DragUISessionCoordinator.pointerDown`（Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift:200-236）→ pointerUp click 路径 → `dispatchClick`（:474/:477）→ `onCellClick`（AppDelegate.swift:590-592）→ `handleDragCellClick`（AppDelegate.swift:672-688，folder→handleFolderCellClick / app→`launchMember(appID)` :683）。
- 建夹 commit 链：`DragUISessionCoordinator.onCommit`（AppDelegate.swift:569-589）→ `self.sessionLayout = newLayout`（:573）→ `provider.applyCommittedLayout(newLayout, atCurrentPage: surface.core.committedPage, itemsPerPage: surface.itemsPerPage)`（:576-578）→ `applyPresentationUpdate(update, overridePageCount: true)`（:582，实现 :697-709：:700 `dragCoordinator?.cancel(reason: .catalogRefresh)` → :701 `surface.refreshPresentation()` → :703 `surface.setPageCount(...)`）。
- **候选根因区（未定位）**：
  1. `applyPresentationUpdate` 重建/重渲染后，live cell 的 `bindingToken` 与 `AppLaunchController.handleCell` 校验链（Sources/PagingPrototypeApp/AppLaunchController.swift:129-143，**冻结不可改**：①`token.catalogRevision == served` ②bundleURL 存在 ③磁盘 fileExists ④launcher.open）——BUG7 缺陷3 曾指向此处（H3 revision 回弹），T-1F-B7-wave-c 已将顶层点击改为 `launchMember(appID)` 合成 cell 路径（AppDelegate.swift:668-670 注释），但本轮复发说明路径可能仍有缺环。
  2. `layoutProvider`（AppDelegate.swift:551-559）一旦 `sessionLayout` 非 nil 恒返回它（:553）——`makeSessionLayout` 恒产出 `generation: .zero`（DragUISessionCoordinator.swift:444 附近），与 `applyCommittedLayout` 递增的 folder generation 不协调（BUG6-FIX-PROMPT §4.3 观察项：「第二次拖拽行为异常」指向此处）。建夹后 sessionLayout 非 nil，后续点击的解析是否受影响待查。
  3. 建夹后 `dragCoordinator?.cancel(reason: .catalogRefresh)`（:700）在 idle 时 no-op，但 `refreshPresentation` + `setPageCount` 后的视觉/焦点重建是否影响后续 mouseDown 路由（s10/s6 计数可判别——**当前无建夹后点击的 census 读数**）。

### 判别/取证建议（给 OBS 的入手点）
- 复测时记录：建夹前 1 次点击（应 sA_launch_accepted）、建夹后立即 1 次点击、建夹后 2s+ 1 次点击——对照 census 的 `s10/s6/s7_handleclick_silent/s7b_launchmember_silent/sA_launch_rejected_*` 五个 sink 的增量分布，即可定位断在「视图层 / coordinator / 派发层 / 校验链」哪一段。
- 关注 `s7_handleclick_silent`（AppDelegate.swift:678/:686，cast 失败静默）与 `s7b_launchmember_silent`（:791/:796，无 launchController/assembly/servedRevision）两个既有计数点。

---

## §2 缺陷 B：folder 内拖动成员时，preview 显示在主界面（不在 folder overlay 内）

### 现象
- 打开 folder 后，成员点击能打开（正常）。
- **拖动**成员时，拖拽 preview（迷你 cell）显示在主界面网格位置，而非 folder 面板内跟随指针。

### 已确认事实
- folder overlay 添加为 `host?.addSubview(folderOverlay)`（AppDelegate.swift:826，host = surface 即拖拽 visualHost，`:824-828`，`folderOverlay.frame = host?.bounds`，autoresizingMask 铺满）→ **overlay 是 surface 的顶层子视图（后添加 = 更上层）**。
- drag preview 由 `DragUIVisuals` 挂在 host（surface）上：`attach(_ view:)`（Sources/AppGridUI/DragUI/DragUIVisuals.swift:214-217 `host.addSubview(view)`）；`showPreview(sourceCell:at:)`（:57-76）在 host 坐标系定位（pointer 上方 24pt）。
- 拖动时 pointer 坐标链：overlay 内 `mouseDown`（Sources/AppGridUI/FolderOverlayView.swift:267-284，成员 cell → `coordinator.pointerDown(locationInWindow:sourceCell:memberFolderID:)` :277-278）→ coordinator `pointerDragged`（DragUISessionCoordinator.swift:140-173，`host.convert(locationInWindow, from: nil)` :143 转 host 系）→ `visuals.movePreview(to:)`（:170）。

### 机制候选（未定位，静态疑点）
1. **层级遮挡/坐标系错位**：preview attach 到 host（surface），而 overlay 浮在 surface 之上 → preview 被 overlay 盖住，用户看到的是 preview 透过 overlay 边缘/间隙露出的部分，或 preview 与 overlay 面板坐标对不上（preview 在 surface 系、面板在 overlay 系，两系一致但叠加顺序导致视觉上「在主界面」）。候选：需要将 preview 的宿主在 folder scope 下提升为 overlay（或 overlay 之上的兄弟层）。
2. `makeDragGeometry(.folder)`（AppDelegate.swift:642-663）的 `memberFrames = overlay.memberDragItemFrames(convertedTo: host, catalog: catalog)`（:644）——成员帧转换到 **host（surface）坐标系**（成员 cell `convert(bounds, to: host)`，FolderOverlayView.swift:109）——成员帧坐标本身正确（与 preview 同系），故疑点集中在**层级**而非坐标换算。

### 取证建议
- 在 overlay 打开状态下拖动成员，截图/录制：确认 preview 是否可见、位于何处、是否跟手。
- 检查 `DragUIVisuals.host` 在 folder scope 下应否改为 folder overlay 面板视图（涉及 coordinator visualHost 语义与 attach 目标，改动面待 Chief 评估）。

---

## §3 缺陷 C：拖到右缘 app B 的右边，插入蓝条显示在「下一行正中间 app 的正中间」

### 现象
- 场景：folder 内（或主界面？用户语境为 folder 内拖动后段）把应用拖到右侧边缘的最右列；目标是插到右列最上 app **B 的右边**。
- 功能：插入/重排**成功**（「是能把这个应用拖过去」）。
- 视觉：**蓝色插入条显示在下一行正中间那个 app 的正中间**——插入指示位置与实际插入位置不一致。

### 代码上下文
- 蓝条绘制：`DragUIVisuals.updateIntent`（DragUIVisuals.swift:89-114）→ `.insertion(index)` → `showInsertionBar(at: index, frames: geometry.itemFrames)`（:91-92，folder scope 下 itemFrames = 成员帧）；`insertionRect(for:frames:)`（:191-206）：index<=0 → 首条目左侧；index>=count → 末条目右缘；否则 **相邻帧中点**（:202-205 `(a.maxX + b.minX)/2`）。
- global→local 回减：`showInsertionBar` → `localInsertionIndex(fromGlobal:frames:)`（:158-164）——帧注记 nil（**folder 成员帧不注记**，AppDelegate.swift:651-652 注释「成员帧不注记（folder 内 insertion 不乘外层 itemsPerPage）」）→ 原样返回 globalIndex（:161）。**folder 内 index 即成员列表下标**。
- 插入位计算：`DropZoneGeometry.insertionIndex(pointer:frames:)`（DropIntent.swift:90-125）——「指针左侧水平中点计数」按阅读行划分（:93-105 行=竖直不重叠连续段）；命中时与左半/右半一致（命中位/命中位+1）。
- 成员帧来源：`FolderOverlayView.memberDragItemFrames`（FolderOverlayView.swift:106-116）——`memberCells.compactMap` 顺序（**memberCells 顺序 = ?**，需查 layoutPanel :420-451 的填充顺序与 innerPage 分页时 memberCells 是全部页还是当前页）；5 列布局（:129 `columns = 5`，spacing 16，cellHeight 88）。

### 机制候选（未定位，静态疑点）
1. **成员帧顺序 vs 成员列表下标不一致**：`memberDragItemFrames` 的帧数组顺序（memberCells 视觉顺序）与 classifier 产出的 index（基于 layout 的 members 顺序 / 指针几何）若不同源（如分页后 memberCells 未刷新为当前 innerPage、或 compactMap 跳过 nil 后顺序漂移），index 会映射到错误帧 → 蓝条画错位。「下一行正中间」≈ index 偏移若干格的表现（如目标 index 应为 B 之后，实际帧列表少了/多了条目）。
2. **阅读行划分与 5 列网格的边界**：`insertionIndex` 的行划分（minY<=bottom 并合，:99）依赖帧竖直重叠假设；若成员帧含零尺寸/跨行帧（零帧夹具工件，wave-a 注记），行划分或中点计数错位。
3. **folder 内降级插入（BUG9 wave-a）的 index 语义**：成员正中命中→降级半区插入的逻辑，其产出 index 与 insertionRect 的帧映射是否一致（wave-a 只改了 classify 的 .invalid→.insertion 降级，insertionRect 未动）。

### 取证建议
- 复测记录：folder 成员数、目标 B 的视觉行列、拖放落点（B 左半/右半/正中）、蓝条实际出现位置、插入后顺序。
- 静态核对：memberCells 在 innerPage 翻页后的刷新逻辑（FolderOverlayView `rebuildMembers`/`layoutPanel` 段）+ 成员帧数组与 `members(onPage:)` 的一致性。

---

## §4 已确认健康的项（排除项）

- R5 激活点击吞没：census `s8e key1_active1` 为主（窗口 key、app active），仅 1 次 `key0_active0`（切走切回）——非主因。
- R2 抑制滞留：`s13a 10 == s13b 10 == s9b 10` 配平、s9_leak 零输出——BUG8 N1 修复在位。
- R1 视图路由：s10 触发（wave-a hitTest 漏斗生效）——主界面点击在**非建夹**场景可启动（sA_launch_accepted ×3）。
- 冻结树零触碰；无 git 操作。

## §5 约束与红线

- 冻结树：Sources/PagingCore、AppCatalogCore、MacAppCatalog、AppIconPipeline、PagingTelemetry、PagingUI、Package.swift、PagingPrototypeApp/AppLaunchController.swift（handleCell 校验链 :129-143 不可改）。
- Main/Chief 不实现业务代码；缺陷 → Workflow 任务 → Worker → 独立 Reviewer PASS → 合并。
- 禁读 LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse。
- 隐私：A/B/C 代称；无真实 app 名/bundleID/路径进报告。
