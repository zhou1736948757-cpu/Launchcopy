# BUG7-REPORT — 三波 BUG6 修复合并后用户实机复测缺陷（待 Ops 审查）

- **日期**：2026-09-01（用户实机复测，构建 = BUG6 三波全部合并后的产物，`swift run PagingPrototypeApp` 窗口模式）
- **基线**：1026 tests / 0 failures（合并后 Main 复跑确认）；debug/release exit 0
- **上游**：Workflow/BUG6-REPORT.md → 三波修复（Wave A/B/C 均已合并）→ 用户实机复测仍报 3 缺陷
- **状态**：待 Ops 决策；本报告只读定位 + 建议波次，未改任何代码

---

## §0 用户原话（2026-09-01）

1. "第一个就是还是像我之前说的，就是你把A软件移到B软件上的时候，形成这个Folder应该是在B软件的位置上。"
2. "在这个拖动软件的时候，到最后一列的，就是比如说我把其他列的软件想拖动到右边就是最靠右边那一列的话，我没有办法移动，没有办法让我的软件，其他列的软件到最后右边那一列。"
3. "拖动把它移成Folder以后，就是在主页面上的这个软件的话，它不能够进行点击，然后打开。"
4. **关键澄清（用户补充）**："进入Folder打开软件是没有问题的"——成员启动正常；问题只限**建夹后主界面（顶层）app 点击打不开**。

实机运行日志证据（DBG pointerDown 输出，T-1F-B-tests-actor-fu-1 遗留未清理项，恰好成为复现证据）：
同一 cell（内存地址 `0xbfb923c00`，坐标 x=390.20 / y=682.81）**连续 6 次 pointerDown 均无后续反应**——即用户在同一 app 图标上连点 6 次，未启动、未拖拽、无任何反馈。

---

## §1 缺陷 1：createFolder 落点仍不在 drop 目标 B 的位置（Wave B 未真正解决）

### 现象
拖 A 到 B 上建夹 → folder **仍然出现在 A（被拖源）原来的格子**，用户期望 folder 出现在 **B（drop 目标）的格子**。

### 代码定位（Wave B 合并后现状）
`Sources/AppGridUI/LayoutDomain/LayoutMutation.swift:124`：
```swift
let insertion = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
ordered.remove(at: max(targetIndex, sourceIndex))
ordered.remove(at: min(targetIndex, sourceIndex))
ordered.insert(.folder(id), at: min(insertion, ordered.count))
```
文件头 :14-16 与 doc :92-94 注释：folder 落点 = "drop 目标 target 原位（source 在 target 前时 targetIndex-1，先算后删再 clamp；BUG6 wave-b 语义修订）"。

### 根因分析（Main 只读定位）
Wave B 引入了 `targetIndex - 1`（当 source 在 target 前时），理由是"移除 source 使 target 左移一位"。**但用户期望的是 B 原来的格子**：

- 相邻左方向 `[A,B,C]`、A→B（source=A idx0，target=B idx1）：`insertion = 1-1 = 0` → 删 1 删 0 → 剩 `[C]` → `[F,C]`。**folder 在 index 0 = A 的原格** —— 与用户在 BUG6-REPORT 中抱怨的旧现象逐字相同（"实际在 min 原 index"，相邻时 targetIndex-1 == min == A）。
- 用户期望 `[C,F]`？或更准确：**folder 占据 B 原格**（视觉 index = targetIndex）。
- 右方向 `[B,A,C]`、A→B（target=B idx0）：`insertion = 0` → `[F,C]`，folder 在 idx0 = B 原格 ✓ 恰好正确。
- 非相邻 `[A,X,B,C]`、A→B：`insertion = 2-1 = 1` → `[X,F,C]`，folder 落在 X 与 C 之间（B 原格是 idx2）——比用户期望（B 原格）**左偏一格**。

**结论**：Wave B 的 `targetIndex-1` 在"源位于目标前"时整体左偏一格；相邻场景下与旧 bug 行为完全相同，用户可见现象未变（"还是像我之前说的"）。符合用户期望的公式候选：**insertion = targetIndex（不做 -1），即 folder 顶替 B 原来的格子**（移除两项后 `min(insertion, count)` clamp 兜底不变）。该结论与 BUG6-FIX-PROMPT §3.3 验收表曾写"folder 在索引 1（B 原位），结果 [folder,C]"的自相矛盾相关——当时裁决为"索引 1 = B 原布局锚点"（相对序语义），**用户实机证明该裁决与用户期望不符**（用户要的是格子位置，不是相对锚点）。须 Chief 重定语义 + 修订 ADR-010 M3 + 更新 Wave B 全部测试期望（两方向 + 非相邻），新增"folder 占 B 原格"断言。

---

## §2 缺陷 2：拖到最右列/最后一列无法移动

### 现象
把某列的软件拖到"最靠右边那一列"无法移动（放下无效/无法落位）；用户原话"我没有办法移动，没有办法让我的软件，其他列的软件到最后右边那一列"。

### 代码定位
`Sources/AppGridUI/DragSession/DragSessionController.swift:255-260`（currentIntent 用 `geometry.itemFrames`）；
`Sources/PagingPrototypeApp/AppDelegate.swift:612-618`（makeDragGeometry topLevel：**只取当前页** `pageView(forPage: surface.core.committedPage)` 的 `dragItemFrames`）；
`Sources/AppGridUI/DragSession/DropIntent.swift:90-125`（`DropZoneGeometry.insertionIndex`：按指针左侧水平中点计数，返回**当前帧集内的页内下标**）；
`Sources/AppGridUI/DragSession/DropResolver.swift:63-70`（校验 `index >= 0 && index <= layout.topLevelOrder.count` —— **用全局布局序计数**）；
`Sources/AppGridUI/DragSession/DragMutationEngine.swift:24-31`（`.insertion(index)` → `reorderTopLevel(toIndex: index)` 按全局下标执行）。

### 根因候选（待 Ops/Chief 验证，未单方定论）
- **候选①（高置信）：页内下标 vs 全局下标映射缺失。** `insertionIndex` 基于**当前页** itemFrames 产出页内下标（0..itemsPerPage-1），但 `.insertion(index)` 直接被当作**全局** `topLevelOrder` 下标消费（DropResolver 校验与 DragMutationEngine 插入均按全局）。**第 1 页之后（page ≥ 1）的任何 drop 插入都会落到错误的全局位置**；拖到"最后一页/最后一列"正是跨页场景。若用户从第 1 页拖到最后一页的最右列，edge turn 翻页后页面 frames 换成新页，index 仍按页内算 → 错位（可能插到页面开头、被 clamp、或蓝条显示在错误位置→"没有办法移动"）。
- **候选②（中置信）：右侧 edge zone（40pt）吞没最后一列右侧的插入落点。** ADR-010 Q6 参数 `edgeZoneWidthPT=40`（DragParameters）：指针进入容器右缘 40pt 条带 → edge paging 驻留投票 → 500ms dwell 后翻页。最后一列的右侧 margin（dropZoneMarginsPT=8pt 内缩）完全落在 40pt 右缘带内 → 用户试图落在"最后一列条目右侧"时持续触发翻页/落点几何漂移，无法稳定放置。
- **候选③（低·需实机确认）：同页最右列落点也存在** —— 若用户指的是同页内最右列（非跨页），则候选①不适用，需复现确认蓝条是否出现/落点是否被页边距几何误判。
- **验证建议（不修，先取证）**：分两种场景实机复现（a）同页内拖到最右列右侧；（b）跨页拖到末页最右列；配合临时日志打印 drop 时 `geometry.page` 与 intent 的下标值。自动化层面：新增"page≥1 时 insertion 下标=页内+页偏移"单测（当前测试全在 page 0/单页夹具，**覆盖缺口**）。

---

## §3 缺陷 3：建夹后主界面 app 点击打不开（成员启动正常）

### 现象
建夹之后，主界面（顶层）其他 app 单击**无法启动**（连点 6 次无反应，日志实证）；但**打开 folder 后点击成员启动正常**（用户明确澄清）。此缺陷与 BUG6 缺陷 2 症状同源表象，但 **Wave C 已修复 fallback 路径的 endSession 泄漏**，用户复测仍现 —— 说明用户实际走的是**非 fallback 路径**，Wave C 修复未覆盖。

### 代码定位
点击链路（主界面顶层 app cell）：
`AppGridCellView.mouseDown(:184-187)` → `DragUISessionCoordinator.pointerDown(:103-137)`（含 `resolveSource` → `controller.pointerDown`；`sourcePresent` 失败才武装 clickFallbackCell）→ `pointerUp(:176-224)`：
- 正常路径：`state == .pressed` → `controller.pointerUp` → `.clicked` → `dispatchClick` → `onCellClick(cell)`（`AppDelegate.swift:578-580`）→ `handleDragCellClick`（`:640-654`）→ `launchController?.handleCell(cell)`（app cell、folder 未开）。
- `handleCell` 校验链（`AppLaunchController.swift:129-143`）：① `token.catalogRevision == servedRevision`（stale 拒绝）② `assembly.bundleURL(for:)` ③ `fileManager.fileExists` ④ `launcher.open`。`lastOutcome`/`outcomeCounts`（:65-67）记录每次结果 —— **可诊断**。

### 根因候选（按优先级，待验证）
- **候选①（高置信）：`handleCell` 校验静默拒绝。** 建夹后 `applyCommittedLayout` 走**同 revision 呈现更新**（不 mint CatalogRevision；`AppGridUIPageContentProvider.swift:253-307`，plan.snapshotRevision = servedSnapshot.revision）→ `servedRevision` 不变；但页面 cell 经 `setPageCount → refreshLiveHostContent` 重建后，**bindingToken.catalogRevision 与新呈现的关系、以及 `bundleURL(for:)` 的 identity→URL 映射在 presentationRecords 重构后是否仍命中**，需要验证。每次点击被静默拒绝（无启动、无提示）与"连点 6 次无反应"吻合。**验证手段：读 `launchController.lastOutcome` / 临时中性日志打印 outcome 计数**（不改行为，只取证）。
- **候选②（中置信）：点击未到达 handleCell。** 若 pointerDown 时 `sourcePresent` 判定失败→ clickFallbackCell 武装 → pointerUp 走 fallback 分支 → `onCellClick`（Wave C 已恢复 endSession）→ 应该仍可启动；除非 fallback 的 cell 是**重建前**的旧 cell 实例（bindingToken 指向已过期的呈现），stale 拒绝。也需验证。
- **候选③（与缺陷 2 关联）：建夹后 sessionLayout 生命周期。** `AppDelegate.swift:539-547` layoutProvider 一旦 `sessionLayout` 非 nil 恒返回它（T-1F-E 以 store 替换前）；建夹 commit 后 sessionLayout 持有新布局，若后续 catalog 刷新/呈现更新与 sessionLayout 的 generation/条目集合不一致，`sourcePresent` 或 handleCell 校验路径可能错判。**观察项 sessionLayout generation 恒零（coordinator.swift:444）与此同族**——用户复测若现"第二次拖拽行为异常"直接指向它（BUG6-FIX-PROMPT §4.3 已记录）。

### 排除项
- Wave C 已修 fallback 泄漏；用户路径非 fallback 首因（但 fallback 旧 cell 问题仍为候选②）。
- 成员启动正常 → `launchMember`（makeMemberLaunchCell + handleCell 管线）与 folder 内合成 cell 路径健康；问题限定在顶层 cell 的点击→handleCell 链。

---

## §4 约束（沿用 BUG6 全项）

- **冻结树**：Sources/PagingCore、AppCatalogCore、MacAppCatalog、AppIconPipeline、PagingTelemetry、PagingUI、Package.swift、PagingPrototypeApp/AppLaunchController.swift。
- **Main 不实现/不修复**：每缺陷 = 新 Workflow 任务 → Worker → 独立 Reviewer PASS → 合并。
- **禁读来源**：LaunchBetter / BuhoReverseNotes / 2026-08-25-buho-launchpad-reverse；BuhoRebuild 只有 Ops/Main 侧行为层结论（已记 PROVENANCE/CONTAMINATION_LOG.md）。
- **隐私**：本报告用 A/B/C 代称；telemetry 无真实 app 名/bundleID/path/folder 标题/成员列表。
- **无 git**：不 commit/push/tag/release；文件级证据 + mtime 取证。
- **物理门**：不虚标；本次为窗口模式 GUI 复测，非独立物理门。

---

## §5 建议修复波次（供 Ops/Chief 决策，未派发）

| 波次 | 缺陷 | 内容 | 写范围（草案） | 依赖/串行 |
|---|---|---|---|---|
| **Wave A'** | 缺陷 1 | createFolder 落点语义重定：folder 顶替 **B 原格**（候选公式 `insertion = targetIndex`，两方向+非相邻测试重写）；同步 ADR-010 M3 文本、LayoutMutation 头注释/doc（注释与实现不一致 = FAIL）；**两方向 + 非相邻必须都测** | LayoutMutation.swift + 对应测试 + Docs/ADR-010 | 无（域层） |
| **Wave B'** | 缺陷 2 | 先验证候选①（页内/全局下标映射）：geometry 携带 page 信息 → insertion index 加页偏移（或 intent 语义改为"第 x 条目之前"由引擎换算）；候选②（edge zone 吞右缘）→ 评估 dropZoneMarginsPT/edge zone 交互；补 page≥1 单测 | DragSessionController/DropIntent/DragMutationEngine/AppDelegate geometry + 测试 | 与 A' 无文件冲突可并行（Main 记 concurrency_check） |
| **Wave C'** | 缺陷 3 | 先取证后修：Worker 只读加打印/读 lastOutcome 定位拒绝点（stale? missingApp? missingFile? noBinding?）→ 靶向修复；候选②③ 按 §3 验证；sessionLayout 观察项维持 BUG6-FIX-PROMPT §4.3 处置 | DragUISessionCoordinator / AppDelegate 相关 + 测试 | AppDelegate 共享 → 与 B' 串行评估；A' 可并行 |

**每波验收标准（用户期望）**：①拖 A 到 B 上 → folder 出现在 **B 的格子**；②其他列软件可拖到最右列并落位（蓝条正确、放下到位、跨页正确）；③建夹后主界面任意 app 单击可启动、空白单击仍可退出；④folder 内成员拖拽/启动不回归（现正常，必须保持）。

**实机复验脚本（每波后）**：①[A,B,C] 相邻左/右两方向建夹落点；②跨页拖到末页最右列；③建夹后单击各 app + 空白退出；④交替拖拽点击 20 次无退化。

---

## §6 遗留观察项（本报告不修，记档）

1. **Wave B 语义裁决教训**：任务包验收表内部矛盾（"索引 1" vs "[folder,C]"）当初按相对锚点裁决，用户实机证明应按**格子位置**裁决 —— 后续所有验收表矛盾必须回用户原话字面裁定，不得自行合理化。
2. **DBG pointerDown 打印**（T-1F-B-tests-actor-fu-1 遗留）仍在生产输出中出现，兼作本次复现证据；交付清理项。
3. **测试覆盖缺口**：page≥1 的 drop 插入零测试；createFolder 落点两方向+非相邻已补（Wave B）但语义要重定；主界面点击后 handleCell outcome 无断言测试。
4. **sessionLayout generation 恒零**（coordinator.swift:444）为 fallback 上游成因观察项，维持 BUG6-FIX-PROMPT §4.3。