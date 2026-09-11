# BUG10 修复任务 Prompt（Chief 拆包 / Worker 实现 / Reviewer 独立判定）

- 日期：2026-09-02
- 上游：`Workflow/BUG10-REPORT.md`（用户实机复测，3 缺陷）
- 基线：1062/0（BUG9 wave-a + wave-b 已合并）
- 本文用途：把三个缺陷的根因定位、改法、回归锁、验收标准写死
- 隐私：全文 A/B/C 代称；禁真实 app 名 / bundle ID / 路径 / folder 标题 / 成员列表

---

## 0. 证据等级声明（Worker 必读，决定你能不能直接动手）

三个缺陷的确定性**不同**，不要一视同仁：

| 缺陷 | 等级 | 依据 | 可否直接实现 |
|---|---|---|---|
| C 蓝条错位 | **已数值证明** | 照抄现行算法喂生产帧复现出与用户描述逐字吻合的错位（§3.1 脚本可复跑） | ✅ 可直接实现 |
| B preview 在主界面 | **已静态证明** | 视图层级链确定（container vs surface 父子关系，代码行号确凿） | ✅ 可直接实现 |
| A 建夹后点不开 | **强假设，未实机确认** | census 日志时序 + 静态路径推导（§4.1）；**触发条件与报告不同** | ⚠️ 先取证（§4.4），禁止直接改 |

**缺陷 A 的红线**：不得在假设上写实现代码。先跑 §4.4 的取证复测，census 读数确认后再回 Main 领实现任务包。

**建议顺序：C → B → A**。C 是纯几何单点、有确定性验证；B 是单处 attach 目标变更；A 需实机取证前置。

---

## 1. 三缺陷根因总览

| 缺陷 | 用户症状 | 根因一句话 |
|---|---|---|
| A | 建夹后主界面点击打不开 | （待确认）`closeFolder` 后 overlay 残留吞事件，触发条件是**开过再关 folder**，非建夹 |
| B | folder 内拖成员，preview 显示在主界面 | preview attach 到 `surface`，而 overlay 挂在 `surface` 的**父视图** `container` 上 → 被整块遮罩盖住 |
| C | 蓝条显示在下一行正中间 app 的正中间 | `insertionIndex` 行划分假设 y 向下增长，生产视图是 **y-up** → 所有行被并成一行 |

---

## 2. 缺陷 C：insertionIndex 行划分坐标系反向（先修这个）

### 2.1 根因（已数值证明）

`Sources/AppGridUI/DragSession/DropIntent.swift:90-125`，`DropZoneGeometry.insertionIndex` 的行划分循环：

```swift
while end < frames.count, frames[end].frame.minY <= bottom {   // ← bug
    bottom = max(bottom, frames[end].frame.maxY)
    end += 1
}
```

这个条件只在 **y 向下增长**（row 0 的 y 最小）时才正确。但生产视图全部是 **y-up**：

- 全库无任何 `isFlipped` override（已 grep 确认 `Sources/` `Tests/` 零命中）→ AppKit 默认 y-up
- `FolderOverlayView.layoutPanel:444`：`let y = area.maxY - CGFloat(row + 1) * (cellHeight + spacing)` → **row 0 的 y 最大**
- `AppGridPageView.layout:303`：`let y = area.maxY - CGFloat(row + 1) * (cellHeight + spacing)` → **顶层网格同构，同样受影响**

于是每个后续行的 `minY` 恒 `<=` 当前行的 `bottom`（因为后续行在**下方** = y 更小），合并条件恒真 → **全部条目被并成一行**。

### 2.2 复现脚本（Worker 应先跑一遍，确认自己理解了 bug）

把 `insertionIndex` 逐字抄出来，喂生产 folder 面板几何（5 列 / spacing 16 / cellHeight 88 / `y = area.maxY - (row+1)*pitch`），8 个成员：

```
=== 8 个成员（5 列 → 2 行）生产 y-up 帧 ===
  idx0  x=24.0..111.2   y=496.0..584.0   centerX=67.6
  idx1  x=127.2..214.4  y=496.0..584.0   centerX=170.8
  idx2  x=230.4..317.6  y=496.0..584.0   centerX=274.0
  idx3  x=333.6..420.8  y=496.0..584.0   centerX=377.2
  idx4  x=436.8..524.0  y=496.0..584.0   centerX=480.4     ← B（右列最上）
  idx5  x=24.0..111.2   y=392.0..480.0   centerX=67.6
  idx6  x=127.2..214.4  y=392.0..480.0   centerX=170.8
  idx7  x=230.4..317.6  y=392.0..480.0   centerX=274.0

行划分结果 rowRanges = [0..<8]        ← 期望 [0..<5, 5..<8]
指针 (530.0, 540.0) = B(idx4) 右缘外
insertionIndex = 8                    ← 期望 5
frames.count = 8
>>> index >= count → insertionRect 取【末帧】idx7（第二行中列）右缘画条
>>> 蓝条落点 x≈314.6 y≈392.0（下一行、正中附近）

=== 对照：测试夹具 y-down ===
y-down rowRanges = [0..<3, 3..<6]     ← 正确分两行，所以 1062 测试全绿
```

`>>>` 三行**就是用户逐字描述的「下面一行正中间那个 APP 的正中间」**。根因确认闭环。

### 2.3 为什么「功能成功、只有视觉错」（关键，别改错地方）

两条路径不同源：

- **功能路径**：命中 B 右半 → `insertionIntent` 的 `hitItem` 分支（`DropIntent.swift:230-236`）→ `index + 1` → **不经行划分，正确**
- **视觉路径**：`DragUIVisuals.showInsertionBar:138` → `localInsertionIndex` → `insertionRect:191-206`。而蓝条 index 来自 intent，intent 在**未命中条目**（缝隙/边距）时才落到 `insertionIndex` 行划分

用户「拖到 B 右边」若落在 B 右缘**外**（右列外侧边距，非 B 内部）→ 未命中 → 走行划分 → 得 8（越界）→ `insertionRect` 的 `index >= count` 分支取末帧右缘。

所以**修 `insertionIndex` 一处即可同时修好功能与视觉**，不要去改 `insertionRect`。

### 2.4 改法

`DropIntent.swift:95-105` 的行划分改为**坐标系无关**写法。要求：

1. 不假设 y 增长方向；按「竖直区间重叠」聚类，而非「minY <= bottom」单向比较
2. 保留零尺寸帧并入当前行的既有语义（wave-a 夹具工件，`:98` 注释）
3. 行的先后顺序必须按**阅读序**（视觉从上到下 = y-up 下 y 递减），因为 `range.lowerBound` 被当作「更早行的条目总数」直接使用
4. 纯函数、无新增参数、无新增字段

参考方向（Worker 自行定案并写清理由）：帧已按阅读序传入（`DragItemFrame` 契约：D 层按阅读序提供），所以「换行」判定可用「与当前行竖直区间不重叠」，方向由帧自身给出，不硬编码上下。

**同时更新 `:86-89` 与 `:98` 的注释**——现注释写「行 = 竖直不重叠的连续段（阅读序布局假设）」，语义是对的，但实现把它写成了单向不等式。注释与实现的偏离要一并消除（BUG6 §0 同类先例：规格写错就改规格）。

### 2.5 回归锁（**必做，否则改完测试会红**）

`Tests/AppGridUITests/Bug6DropZoneGeometryTests.swift:30-38` 的 `gridFrames()` 是 **y-down**（`ys = [10, 110]`，row 0 在上）：

```swift
private func gridFrames() -> [DragItemFrame] {
    let xs: [Double] = [10, 110, 210]
    let ys: [Double] = [10, 110]          // ← row 0 的 y 最小 = y-down = 与生产反向
```

**这是 bug 逃逸的直接原因**：夹具坐标系与生产反向，掩盖了行划分错误。

要求：

1. **新增** y-up 夹具（镜像生产：`y = maxY - (row+1)*pitch`），对同一批断言点给出期望值 —— 这是本缺陷的**结构性回归锁**
2. 既有 y-down 断言**保留**（坐标系无关的实现应两者皆过）；若某条 y-down 断言在正确实现下必然改变，需在结果文件写明该断言原期望值本身是错的及推导
3. 新增覆盖：`insertionIndex` 结果落在 `[0, count]` 闭区间的边界锁；右列最上条目右缘外 → 期望该条目之后（本缺陷主症状点）
4. 顶层网格（`AppGridPageView` 同构 y-up）也要有一条锁，证明修复不止覆盖 folder 内

---

## 3. 缺陷 B：drag preview 被 folder overlay 遮挡

### 3.1 根因（已静态证明）

视图层级（行号确凿）：

```
window.contentView = container            AppDelegate.swift:208-210
├── surface (PagingSurface)               :211-213   ← DragUIVisuals.host
├── search field                          :216-218
└── folderOverlay                         :826       ← host = container ?? surface
```

- `installDragUI:547`：`DragUISessionCoordinator(host: surface)` → `DragUIVisuals.host = surface`
- `DragUIVisuals.attach:214-217`：`host.addSubview(view)` → preview 是 **surface 的子视图**
- `refreshFolderOverlay:825-826`：`let host = container ?? surface; host?.addSubview(folderOverlay)` → overlay 是 **container 的子视图**，与 surface 是**兄弟**，且后添加 = **更上层**
- `FolderOverlayView.init:142`：`layer?.backgroundColor = NSColor.black.withAlphaComponent(0.35)` → 整块半透明遮罩铺满

结论：preview 挂在 surface 上，被整块 overlay 盖住。用户看到的是**透过 35% 遮罩的、位于主界面网格坐标上的 preview** —— 与「显示其实是在主界面里面拖动」逐字吻合。

坐标换算本身**没有问题**：`memberDragItemFrames(convertedTo: host)`（`FolderOverlayView.swift:109`）与 preview 同为 host(surface) 系，两者一致。**不要去改坐标换算。**

### 3.2 两个方案（Chief 定案）

**方案 B1：folder scope 下把视觉宿主提升为 overlay（推荐）**

让 `DragUIVisuals` 的 attach 目标随 scope 切换：folder scope → overlay（或 overlay 内一个专用的、位于 panel 之上的视觉层）；topLevel scope → surface（不变）。

- 优点：改动集中在 D 层；复用既有坐标链（成员帧已可转任意 host）
- 代价：`DragUIVisuals.host` 由 `let` 语义变为可切换 → 必须保证切换时旧宿主上的视图被 `removeFromSuperview`，否则同一 NSView 在两个父视图间漂移
- 注意：`attach:215` 现有 `view.superview !== host` 短路，切换宿主时该判断会重新 addSubview（AppKit 会自动从旧父移除），但 `teardown()` 只移除一次 —— 需复核幂等性
- 注意：切换后 preview 坐标系变为 overlay 系，而 `pointerDragged:260` 的 `host.convert(locationInWindow, from: nil)` 用的是 coordinator 的 `visualHost`。**两者必须同源**，否则 preview 偏移。这是本方案最容易错的点，要有测试锁

**方案 B2：独立无边框窗口承载拖拽代理**

拖拽代理放进一个 borderless `NSWindow`（`.popUpMenu` level）跟随指针，彻底脱离主窗口视图层级。

- 优点：一劳永逸，不受任何 overlay/层级影响；`AppGridPageView` 与 folder 都不用区分
- 代价：改动面大（窗口生命周期、坐标从 window 系转屏幕系、teardown 路径、Reduce Motion 动画路径）
- 来源标注：`PUBLIC_DOCUMENTATION`（AppKit 拖拽代理的通用做法；本项目独立决定）

**建议 B1**（改动面小、可测），B2 记入 Docs 作为后续选项。

### 3.3 附带项（同波修，低风险）

`DragUIVisuals.updateIntent:89-114` 在 folder scope 下 `.insertion` 用 `geometry.itemFrames`（成员帧），`.topLevelTarget` 用 `geometry.topLevelFrames`（顶层帧）。宿主切换后，**两者不在同一坐标系**（成员帧转 host、顶层帧也转 host，但 host 变了）。

要求：宿主切换方案必须给出「哪些帧在哪个坐标系」的显式契约，并在 `makeDragGeometry`（`AppDelegate.swift:627-664`）注释里写死。move-out（成员拖到顶层）横跨两个 scope，是本项最危险的路径，必须有测试。

### 3.4 验收

- folder 打开 → 拖成员 → preview 在**面板内跟手**，不再出现在主界面网格位置
- move-out（成员拖出到顶层缝隙）→ preview 与顶层落点蓝条位置一致、不跳变
- 顶层拖拽（folder 未打开）→ 零行为变化（回归）
- Reduce Motion 路径不变

---

## 4. 缺陷 A：建夹后主界面点击打不开（**先取证，禁止直接改**）

### 4.1 报告漏掉的关键证据

`/tmp/bug9_census_run2.log` 第 71-115 行（BUG10-REPORT 未引用此段）：

```
71  s8d_window_cell_passthrough 7
73  s8d_window_cell_passthrough 8
...
115 s8d_window_cell_passthrough 29        ← 连续 23 次，窗口层判 cell 并放行 super
    （此段内 s10_cell_mousedown_fired 恒不增，停在 5）
```

**23 次点击落在 cell 上、窗口层放行，但 `AppGridCellView.mouseDown` 一次都没触发。**

全段 `s8e_window_key_state_key1_active1`（窗口 key、app active）→ **排除 R5 激活吞点**。

### 4.2 时序（决定性）

紧邻该段之前，第 64-69 行：

```
64  s8e_window_key_state_key0_active0 1      ← 切走切回
65  s8_window_blank_unclassified 6
66  s8e_window_key_state_key1_active1 12
67  s8_window_blank_unclassified 7
68  s4a_pendingblank_nocell 1                 ← overlay 空白按下（folder 已打开）
69  s4d_blankbranch_dispatch 1                ← 空白点击派发 → closeFolder
70  s8e_window_key_state_key1_active1 13
71  s8d_window_cell_passthrough 7             ← 此后 cell 全死
```

而 `sA_launch_accepted`（8 次）**全部出现在第 68 行之前**。

**推翻报告的「建夹是必要条件」**：真正的触发条件是**开过 folder 再关**（建夹只是让 folder 存在、能被打开）。这解释了用户为何觉得「建夹后」—— 建夹后自然会去点开新 folder 看看，然后关掉。

### 4.3 静态路径（假设）

`closeFolder`（`AppDelegate.swift:774-782`）：

```swift
dragCoordinator?.cancel(reason: .overlayClosed)
keyboardController?.endTitleEditing()
isTitleEditing = false
folderOpenState?.close()
folderOverlay?.clearContent()
folderOverlay?.removeFromSuperview()      // ← 只做了这一步
```

而 `FolderOverlayView.hitTest:297-303` 对所有非按钮区**返回 self**：

```swift
public override func hitTest(_ point: NSPoint) -> NSView? {
    let hit = super.hitTest(point)
    if hit === prevButton || hit === nextButton { return hit }
    return self                            // ← 吞掉一切
}
```

假设：overlay 若在某条路径下仍被 `contentView.hitTest` 命中（或仍在响应链），则 `blankClickResolvesToCell`（`:1125-1138`，沿 superview 链找 `AppGridCellView`）在 overlay 内的成员 cell 上会返回 **true** → 窗口层记 `s8d` 放行 super → 但 AppKit 把事件投给 overlay（hitTest 返回 self）→ overlay 的 `mouseDown` 在 `panel.frame.contains` 为假时**静默 return**（`:283` 前的 `for` 循环无命中 → `:281` return）→ **cell.mouseDown 永不触发，且不留任何 census 痕迹**。

这与观测完全一致：`s8d` 增、`s10` 不增、无任何 s0-s9 计数。

**为什么这只是假设**：`removeFromSuperview` 之后 overlay 理应不再被 hitTest 命中。需要实机确认的是「它为何仍在命中」—— 候选：`refreshFolderOverlay:824` 的 `superview == nil` 判断与 `closeFolder` 的移除竞争；或 `folderOpenState?.close()` 与视图移除顺序导致某条路径重新挂回；或 overlay 未移除而只是 `clearContent`（`clearContent` 不移除视图，`:216-226`）。

### 4.4 取证复测（Worker 第一个任务包，只加 census，不改行为）

**布点要求（零行为变更，仅计数）**：

1. `FolderOverlayView.hitTest` 入口 —— sink：overlay 参与 hitTest 的次数 + `superview == nil` 状态位
2. `FolderOverlayView.mouseDown` 的静默 return 路径（`:281`，panel 内非成员区）—— 现无计数点
3. `closeFolder` 执行后，overlay 的 `superview` 是否为 nil —— sink 携带该状态位
4. `blankClickResolvesToCell` 返回 true 时，命中链中是否包含 `FolderOverlayView` —— 这是判别「cell 在 overlay 内 vs 在 grid 内」的关键位

**复测脚本（用户执行，PAGING_CLICK_CENSUS=1）**：

| 步 | 操作 | 期望（假设成立时） |
|---|---|---|
| 1 | 冷启动，点顶层 app | `s10` + `s6` + `sA_launch_accepted` |
| 2 | 建夹（拖 A 到 B 正中） | commit 链；随后点顶层 app → **仍应能启动** |
| 3 | 打开新 folder | 成员点击能启动（对照项） |
| 4 | **空白点击关 folder** | `s4a` + `s4d`；`closeFolder` 后 overlay.superview 应为 nil |
| 5 | 点顶层 app | 假设成立 → `s8d` 增而 `s10` **不增**；新 sink 显示 overlay 仍参与 hitTest |
| 6 | ESC 关 folder（对照，不走空白路径） | 若步 5 复现而本步不复现 → 锁定在空白点击关闭路径 |

**判别表**：

| 观测 | 结论 |
|---|---|
| `s8d` 增、`s10` 不增、overlay 仍在 hitTest | §4.3 假设成立 → 修 overlay 移除/hitTest 生命周期 |
| `s8d` 增、`s10` 增、`s7b_launchmember_silent` 增 | 断在 launchMember guard → 查 servedRevision |
| `s8d` 增、`s10` 增、`sA_launch_rejected_*` 增 | 断在校验链 → 查 revision 回弹（AppLaunchController **冻结**，改调用方） |
| 步 6 也复现 | 与空白路径无关 → 回 Main 重新定位 |

取证结果回 Main → 再拆实现包。**不得跳过本步。**

### 4.5 已排除项（不要再查）

- R5 激活吞点：`s8e key1_active1` 为主（56 次），仅 1 次 `key0_active0`
- R2 抑制滞留：`s13a 14 == s13b 14 == s9b 14` 配平、`s9_leak` 零输出（BUG8 N1 修复在位）
- R1 视图路由：`s10` 在第 68 行之前正常触发（wave-a hitTest 漏斗生效）

---

## 5. 约束与红线（全缺陷适用）

**冻结树，零触碰**：`Sources/PagingCore`、`AppCatalogCore`、`MacAppCatalog`、`AppIconPipeline`、`PagingTelemetry`、`PagingUI`、`Package.swift`、`PagingPrototypeApp/AppLaunchController.swift`（`handleCell` 校验链 `:129-143` 不可改）。

缺陷 A 若定位到校验链，**改调用方**（合成 cell 的 revision 来源），不改 `AppLaunchController`。

**流程**：Main/Chief 不写业务代码；缺陷 → Workflow 任务 → Worker → 独立 Reviewer PASS → 合并。

**参数纪律**：本次不新增 `DragParameters` 字段。若 Worker 认为需要新参数，先停下报 Main（BUG6 §0 先例：往上加状态多半方向错了）。

**隐私**：新增 census sink 只允许中性名 + 计数 + 布尔状态位；禁窗口标题、坐标、app 名、bundle ID、folder 标题、成员列表。

**来源标注**：本文 §3.2 方案 B2「独立窗口承载拖拽代理」标注为 `PUBLIC_DOCUMENTATION`（AppKit 通用模式，本项目独立决定），**不含任何逆向细节**。Worker 不得以任何被禁来源为依据实现。

---

## 6. 总验收标准

**缺陷 C**
- [ ] folder 内：拖到右列最上 app B 的右缘外 → 蓝条出现在 **B 的右侧**，不在下一行
- [ ] 顶层网格：同场景同样正确（y-up 同构，一并修好）
- [ ] 多行 folder（≥ 6 成员，跨行）各行缝隙落点蓝条位置正确
- [ ] `insertionIndex` 结果恒在 `[0, count]`
- [ ] 新增 y-up 夹具锁 + 既有 y-down 断言仍过

**缺陷 B**
- [ ] folder 内拖成员：preview 在面板内跟手
- [ ] move-out：preview 与顶层落点指示同系不跳变
- [ ] 顶层拖拽零回归
- [ ] 宿主切换幂等（无 NSView 在两父视图间漂移；teardown 后零残留）

**缺陷 A**
- [ ] §4.4 取证完成，census 读数写入结果文件
- [ ] 根因定位闭环（判别表命中某一行）后方可实现
- [ ] 修复后：建夹 → 开 folder → 关 folder → 顶层点击**能启动**；`s10` 正常增

**全局**
- [ ] `swift test` 全量通过（≥ 1062，新增锁计入）
- [ ] debug + release 双构建 exit 0
- [ ] 冻结树零改动（`git diff --stat` 自证）
- [ ] 每缺陷独立 Reviewer PASS
