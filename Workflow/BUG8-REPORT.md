# BUG8 诊断报告 — 蓝条视觉位置 + 建夹后顶层 app 单击打不开（症状三现）

- Chief 诊断（chef-worker-reviewer-workflow v1.4.1）；基线 1036/0（Wave C′ 合并后）
- 所有 file:line 均对照当前工作树实测（2026-09-02）；修正旧报告漂移见 §2.7
- AccessDeclaration: **NO_PRIOR_EXPOSURE** —— 本诊断未读取 LaunchBetter/、BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse、任何 Ghidra/otool dump

## §0 用户原话（原话要点）

1. 「a软件移到边缘的时候，也就是右边最后一列那里的时候，蓝色的那个线会显示到最右下角的地方，但是功能是没问题的」
2. 「形成folder以后folder里面的软件点击是可以打开的，但是主页面里面的软件点击打不开」

## §1 缺陷 1（视觉：蓝条钳到页末右缘）—— 根因静态铁证，定案

**链路**：B′ 之后 intent 携带**全局**下标（DropIntent.swift:245-250 `page * itemsPerPage + localIndex`，消费点 :214-217/:235/:238），DragUIVisuals 消费同一 intent：

- `DragUIVisuals.updateIntent`（DragUIVisuals.swift:87-112）：`.insertion(index)` → :89-90 `showInsertionBar(at: index, frames: geometry.itemFrames)`；`.topLevelTarget(index)` → :92-93 `showInsertionBar(at: index, frames: geometry.topLevelFrames)` —— **全局下标直接进页内 frames**。
- `insertionRect(for:frames:)`（:169-184）：`index >= frames.count` → :176-178 clamp 到**末帧右缘**。page≥1 时全局下标（如 38）≥ 页内帧数（5）→ 蓝条恒钳到该页最后一格右缘 = **网格右下角**，与用户「显示到最右下角」逐字吻合。落点/功能正确（resolver/engine 消费同一全局值），纯视觉层。
- **同病潜伏点**：`.topLevelTarget`（:92-93）在 folder move-out 场景同样拿全局下标配 topLevelFrames（帧注记 topPage，AppDelegate.swift:634-636），同波必须一并修。

**修法（定案，单文件）**：在 `showInsertionBar` 入口做 global→local 回减：读 `DragItemFrame` 注记（DragGeometry.swift:80-82/:96-99），`local = global − pageIndex×itemsPerPage`，clamp [0, frames.count]；注记 nil（page 0/folder 成员帧/夹具）→ 原样（向后兼容，兼收 B′ r1 MINOR-3）。`insertionRect` 保持页内纯函数不动；:176-178 clamp 保留（local==count = 页末右缘是**正确**位置）。注意用**帧注记的 pageIndex**，绝不用 `geometry.page`（folder scope 下是 innerPage，B′ 页号陷阱）。→ 任务包 T-1F-B8-wave-v（ready）。

## §2 缺陷 2（建夹后顶层 app 单击打不开）—— 定位与机制推演

### 2.1 现行点击链全图（实测；顶层 app 单击，建夹 commit 后）

1. `QuitOnBlankClickWindow.sendEvent`（AppDelegate.swift:1029-1070）：leftMouseDown → :1039 hitTest → :1040 `blankClickResolvesToCell(hit)`（:1077-1090，沿 superview 链找 AppGridCellView）→ cell 命中 :1069 super；空白命中 → :1045 onDragActiveCancel（session active 才吞）→ :1051 folder open 放行 → :1059 退搜索 → :1064 **onBlankClick → terminateOnBackgroundClick（:233-235 退出 app）并吞**。
2. `AppGridCellView.mouseDown`（:184-187，**不调 super**）→ `coordinator.pointerDown(sourceCell: self, memberFolderID: nil)`。
3. `DragUISessionCoordinator.pointerDown`（DragUISessionCoordinator.swift:103-135）静默门：:104 isTornDown、:105 **dragGate**、:106 visualHost nil、:116-120 resolveSource nil→pendingBlankPress（死路 A）、:121 layoutProvider nil；:123 `controller.pointerDown`（DragSessionController.swift:62-92，:71 sourcePresent 拒绝）→ 无 .pressed 且 sourceCell≠nil → :129-133 fallback 武装。
4. `pointerUp`（:174-226）：:181-186 blank 分支 → onOverlayBlankClick → `closeFolder`（:749-757，主界面无夹时 no-op = **静默**）；:188-200 fallback → endSession + onCellClick；:202 state idle 静默；:204-212 .pressed → .clicked → dispatchClick(:333-339) + endSession。
5. `onCellClick` → `handleDragCellClick`（AppDelegate.swift:653-663）：folder cell :654-659 先行 return；app cell :660-662 `if let appID = cell.bindingToken?.appID as? AppID` → `launchMember`（:763-768，三重静默 guard :764-765 + makeMemberLaunchCell AppCatalogAssembly:450-462 + handleCell AppLaunchController.swift:129-143 冻结）。
6. **并行通路**：surface `NSClickGestureRecognizer`（AppLaunchController.install() :93-98 冻结）独立触发 → handleCell(liveCell) → token revision 校验 → launch / rejectedStaleRevision（静默记录）。
7. **folder cell 点击不受 coordinator 影响**：cell 自带 `folderClickRecognizer`（AppGridCellView.swift:168-172/:178-180）→ onFolderClick；member 点击经 overlay :277-278 进同一 coordinator。

### §2.1 差分定位（成员/folder 能开、顶层 app 不能开）

成员与顶层走**同一 coordinator 管线**（overlay :277-278 vs cell :184-186），resolveSource 两分支几乎同构（:372-375 vs :381-383，都查 appReference）→ snapshot/快照层健康（成员能开即证明）。sourcePresent 失败走 fallback 仍能启动（:129-133/:188-200，C′ 已堵）。因此**纯 coordinator 内部差异解释不了症状**；吞点必在 coordinator 门（:104/:105/:106/:117/:121）、window 层（:1040 误判空白→:1064 退出——但用户未报「点一下就退出」，弱排除）、或**两路启动通路同时失效**。

### §2.2 C′ harness 结构性盲区（「无法复现」的根因，已实证）

DragCommitIntegrationTests.swift 取证测试**直呼** `fixture.coordinator.pointerDown/pointerUp`（:463-471）+ 用 `handleCellClick` **镜像**（:152-163）替代真 AppDelegate.handleDragCellClick。**从未建模 5 层**：①QuitOnBlankClickWindow.sendEvent/hitTest/blank 分类；②AppGridCellView.mouseDown 真实 AppKit 路由；③surface NSClickGestureRecognizer（AppLaunchController）并行通路；④key window/first-responder/activation-click 状态；⑤真 AppDelegate.handleDragCellClick。故 harness 只证明「token→bundleURL→launcher 数据管线健康」，对真机吞点**结构性失明**——这是三现而三修不中的方法论根因（§5）。

### §2.3 静默 sink 清单（顶层 app 点击可无反馈消失的全部出口）

S1 dragGate false（:105，search active / isTitleEditing）；S2 visualHost nil（:106）；S3 layoutProvider nil（:121）；S4 resolveSource nil→pendingBlankPress→onOverlayBlankClick→closeFolder no-op（:117-120/:181-186/:749-757，死路 A）；S5 pointerUp :202 idle 吞（down/up 之间被 cancel）；S6 handleDragCellClick :655/:660 if-let 失败静默；S7 launchMember :764-765 guard 静默；S8 窗口空白误判 → terminate（用户应可见，弱排除）；S9 recognizer 通路 rejectedStaleRevision/rejectedNoBinding 静默（AppLaunchController 冻结，不可改，只能计数观察）。

### §2.4 新发现（本次静态全链新产出，超出 C′ QUESTION-1）

- **N1（高嫌疑，潜伏缺陷）**：`pointerUp` blank 分支（:181-186）**不调 endSession()**。pendingBlankPress 在 :116-120 于 controller.pointerDown **之前**武装——若此时旧会话仍活跃（state≠idle），旧会话既不走 secondDrag 取消、也不被 blank 分支终结 → **仲裁态/抑制（beginArbitration :343-348 关掉 surface recognizer + cell folderClickRecognizer）永久滞留** → isSessionActive 恒 true、surface 识别器恒禁用、window blank 分支恒吞。**「coordinator 路径 + recognizer 路径同时死」正是「点了完全没反应」的唯一自洽形态**（单靠 S4 死路 A 时识别器通路应仍能启动）。Wave C（BUG6）只堵了 **fallback** 分支的 endSession，**blank 分支从未被审计**。
- **N2（文档/实现矛盾，潜伏）**：dragGate 注释（coordinator :52-53、AppDelegate :532）称「点击不受影响」，实现 :105 在 dragGate false 时**连点击一起拦**（search active/标题编辑中所有 coordinator 点击死亡；平时被 S9 recognizer 通路掩蔽）。
- **N3（死路 A，C′ QUESTION-1 转正）**：resolveSource nil 把「有 cell 的按下」当「空白按下」——语义越界：pendingBlankPress 应专属 sourceCell==nil。修法（取证后）：sourceCell≠nil 但 resolveSource 失败 → 改武装 clickFallbackCell（点击仍派发，身份在派发处再读），blank 语义归位。

### §2.5 主假设与判别（实机取证裁决，见 §4 wave-c mandate）

- **H1（首选）**：N1 会话/抑制滞留 × S4 死路 A 耦合 —— 建夹 commit 时序内某次 pointerDown 以 resolveSource nil 收场（重建 cell token 瞬态/复用窗口）或上一会话未净，之后抑制滞留 + 顶层 cell 解析失败 → 双通路齐灭。判别：census 显示 blank 分支命中 + 抑制滞留 + recognizer 禁用。
- **H2（备选）**：activation click —— 成员启动（用户先开了夹点了成员，launcher 失 key）后，首击仅激活窗口（AppGridCellView 无 acceptsFirstMouse override，已核 :184-197 无此 override）→ mouseDown 不达。判别：**第二次连点是否恢复**（H2 第二击必活；H1 持续死）。
- **H3（备选）**：commit→异步持久化（AppDelegate :573-576 layoutStore.enqueue）→ servedRevision 回弹 → applyPendingAtIdleBoundary（:696-712）二次刷新与用户点击竞争 → token/解析瞬态。判别：延迟点击是否恢复、census 的 S9 计数。

### §2.6 结论

无唯一静态铁证（这正是症状三现的根源：每次修的层都真实有病，但都不是真机复现的那条）；缺陷 1 有铁证可直修；缺陷 2 按「取证先行 → 双通路 census → 可控实验序列 → 再结构修改」执行，结构修改范围含 N1/N3 两条已证潜伏缺陷。

### §2.7 漂移修正（对照旧报告）

C′ results 行号 → 现行：handleDragCellClick :651-665→**:653-663**；launchMember :763-770→**:763-768**；coordinator pointerDown :103-137→**:103-135**、pointerUp :176-240→**:174-226**、resolveSource :372-386→**:370-384**；QuitOnBlankClickWindow sendEvent :1026-1043→**:1029-1070**（blank 分类 :1077-1090）；AppDelegate onBlankClick 接线 :233-235。DragUIVisuals/DragGeometry 注记行号为 B′ 后首测（updateIntent :87-112、insertionRect :169-184、annotated DragGeometry.swift:96-99）。

## §3 约束与红线（Chief 声明）

- 禁读来源零触碰：LaunchBetter/、BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse、Ghidra/otool dump——本诊断全部依据用户原话 + 本仓源码实测。
- 冻结树不写：Sources/PagingCore/、AppCatalogCore/、MacAppCatalog/、AppIconPipeline/、PagingTelemetry/、PagingUI/、Package.swift、**AppLaunchController.swift**（缺陷 2 修复绝不触碰；S9 只能经中性计数观察）。
- 隐私：A/B 代称、中性计数（sink 命中数/outcome 计数），无身份/bundleID/路径/标题原文。
- 无 git 操作；Main 不实现业务代码；每缺陷 Worker→独立 Reviewer PASS→Main 合并。
- 基线 1036/0；已知 flaky：RunLoopFrameDriverTests（B′ r1 MINOR-1 处置程序适用）。

## §4 修复波次建议

1. **T-1F-B8-wave-v（ready，可与 wave-c 并行——文件零交集）**：蓝条 global→local 回减，单文件 DragUIVisuals.swift（§1）；含 .topLevelTarget 同病；测试锁：page≥1 中部列、末列右半（local==count 页末右缘=正确位）、page 0 不回归、folder 未注记帧不回归。
2. **T-1F-B8-wave-c（两段式，取证先行）**：
   - **Stage 1 取证（零结构修改）**：①中性 sink census——S1-S7/S8/S9 计数点（env 开关，默认关，仅计数无身份）；②harness 补盲区：经 `AppGridCellView.mouseDown`（合成 NSEvent）驱动 + 真 window 分类（blankClickResolvesToCell 纯函数已有测试面）+ 弃镜像直挂 AppDelegate 等价链（PagingUITests 可行范围内），至少把「建夹→cell.mouseDown→coordinator→真 handleDragCellClick」全链贯通；③实机实验序列（Main 转交用户）：E1 冷启动单击（基线）→E2 建夹后立点顶层（复现点：**是否连 launcher 都退出/隐藏**=S8 判别）→E3 同一 app 第二击（H1/H2 判别：第二击活=H2）→E4 点 folder cell→开夹→成员启动→关夹→再点顶层（恢复性判别）→E5 ESC 后再点→E6 搜索开合后再点→E7 重启后先点顶层（无建夹，隔离会话残留）。census 输出 + E 序列结果回填结果文件。
   - **Stage 2 结构修改（取证结论落盘后）**：必做 N1（blank 分支会话卫生：endSession 幂等补齐）+ N3（pendingBlankPress 收窄为 sourceCell==nil；resolveSource 失败有 cell → fallback）+ N2 文档修正；再按 census 证据处置 H1/H2/H3 对应面。禁写 AppLaunchController/冻结树/Docs。
3. 若 Stage 1 证据指到 AppLaunchController 冻结面（S9 rejected 族），按 D 决策升 Main（等效评估先例 = BUG6 C2/D4）。

## §5 教训反思（症状三现）

三现 = BUG6 缺陷2（fallback endSession 泄漏）→ BUG7 缺陷3（live-token 信任）→ 本次（真根因仍未触及）：三次修复各自堵住了一条**真实存在**的静默 sink，但每次的取证装置都与真机隔了同一堵墙——harness 直呼 coordinator/镜像 AppDelegate，绕过 window/cell/recognizer/key-window 层。**「harness 无法复现」被当成了「数据管线无恙」的结论（正确）与「修法已覆盖真机根因」的结论（不成立）之间的缝隙**。纪律固化：①修「复现不了」的缺陷时，取证装置必须显式声明覆盖层清单（本波起 harness 报告须列「未建模层」）；②吞点类缺陷先做 sink census 再定修法，禁止单点静态推理直改；③同一症状第二次复现即触发「换层排查」强制项，而非在已修层加固。