# T-1F-B8-wave-c — BUG8 缺陷 2：建夹后顶层 app 单击无响应（Stage 1 取证装置 + harness 补盲区）

- Role: Worker（chef-worker-reviewer-workflow v1.4.1）｜Task: T-1F-B8-wave-c
- AccessDeclaration: **NO_PRIOR_EXPOSURE**（未读取 /Users/mac/Projects/LaunchBetter/、BuhoReverseNotes/、2026-08-25-buho-launchpad-reverse 及任何 Ghidra/otool dump）
- 日期：2026-09-01/02 · 零 git 操作 · 零结构性行为修改（Stage 1 = 取证装置 + 观测）
- Status：**Stage 1 完成；实机 E1-E7 待 Main 转交用户执行回填；Stage 2 未启动**

---

## Stage 1.0 范围声明

本阶段产出：①中性 sink census 装置（S1-S9 各计数点 + 抑制滞留单独计数）；②全链 harness 测试（补 C′ 五层盲区）；③E1-E7 实机操作定义（Main 转交用户，回填后进入 Stage 2 census 处置）。**未做任何 Stage 2 结构修改**；Stage 2 预授权项（N1/N3/N2）的修法映射见 §Stage1.6。

## Stage 1.1 census 装置（中性 sink 计数器）

定义：`ClickCensus`（`Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift`，public enum；AppDelegate 经 import AppGridUI 使用）。
- **输出门**：stderr 逐行 `PAGING_CLICK_CENSUS <sink> <n>` 仅在 env `PAGING_CLICK_CENSUS=1` 时输出；默认关 = **零输出**（全量既有测试全绿即证，含 census 相关断言不受 env 影响）。
- **内存可读**：计数恒维护；`ClickCensus.count(_:)/snapshot()/resetForTesting()` 供测试与诊断读取。仅计数，**无身份/无标题/无路径**（sink 名为结构性字符串）。

### sink 清单（S 编号 ↔ 位置 ↔ 语义；行号为 2026-09-02 现行行号）

| sink | 位置 | 语义 / S 映射 |
|---|---|---|
| `s0_pd_torndown` | DragUISessionCoordinator.swift:104 | teardown 后指针事件被拒 |
| `s1_draggate_closed` | :105 | **S1** dragGate 关闭（搜索激活/标题编辑；N2 面证据点） |
| `s2_visualhost_nil` | :106 | **S2** visualHost nil |
| `s3_layoutprovider_nil` | :121 | **S3** layoutProvider nil（controller.pointerDown 之前被拒） |
| `s4a_pendingblank_nocell` | :117-118 | **S4 族** resolveSource nil 且 sourceCell==nil（真空白按下，对照） |
| `s4b_pendingblank_withcell` | :117-118 | **S4 族 / N3 证据**：sourceCell≠nil 但解析失败（有 cell 的按下被当空白＝死路 A） |
| `s4c_fallback_armed` | :129-131 | **S4 族** stale source 回退武装（Defect-3 健康路径） |
| `s4d_blankbranch_dispatch` | :181-184 | **S4 族 / N1 面**：blank 分支派发 onOverlayBlankClick |
| `s4e_blankbranch_suppressed` | :181 | **N1 滞留形成点**：blank 分支执行时抑制仍 true（分支无 endSession） |
| `s4f_fallback_dispatch` | :188-198 | **S4 族** fallback 分支派发（内含 endSession，健康对照） |
| `s5_up_idle_swallow` | :202 | **S5** pointerUp 时 controller 已 idle → 吞点 |
| `s6_dispatch_click_cell` | dispatchClick | Path B click 派发到达装配层（链段桥接点） |
| `s6b_dispatch_click_blank` | dispatchClick | Path B blank 派发 |
| `s7_handleclick_silent` | AppDelegate.swift:655/:660 | **S6** handleDragCellClick if-let cast 静默 |
| `s7b_launchmember_silent` | AppDelegate.swift:764-765 | **S7** launchMember guard 静默（无 launchController/assembly 或无 servedRevision） |
| `s8_window_blank_unclassified` | QuitOnBlankClickWindow.sendEvent :1040 | **S8** 命中未分类为 cell |
| `s8b_window_dragactive_swallow` | :1045 | **S8** 空白命中 + drag 激活 → 吞点 |
| `s8c_window_blank_terminate` | :1064 | **S8** 空白命中 → onBlankClick（=NSApp.terminate 通路） |
| `s8d_window_cell_passthrough` | cell 命中放行 super | **S8 对照**：cell 命中放行（AppKit 路由 → cell.mouseDown/recognizer） |
| `s9_leak_suppression_resident` | pointerDown 入口 | **抑制滞留（mandate 单独计数）**：抑制标志 true 而无任何活会话（controller idle 且无空白候选） |
| `s9b_endsession_restored` | endSession | endSession 实际恢复抑制（健康对照，与 s9_leak 判读配对） |
| `sA_launch_rejected_<outcome>` | AppDelegate 经公开 `onLaunchAttempt` | **S9** recognizer 通路拒绝（rejectedStaleRevision/rejectedNoBinding/rejectedMissingApp/rejectedMissingFile/failedToLaunch）；AppLaunchController 冻结面只读观察 |
| `sA_launch_accepted` | 同上 | **S9** .launched 基线 |

任务包 §5.1 列举的 15 个行位置（coordinator :104/:105/:106/:117/:121/:129/:181/:188/:202 + window :1040/:1045/:1064 + handleDragCellClick :655/:660 + launchMember :764-765）**全部落计数点**；每 sink ≥1 计数点。

## Stage 1.2 harness 补盲区（C′ 五层 → 建模层/未建模层）

新增 6 测试（`Tests/PagingUITests/DragCommitIntegrationTests.swift` §4，全绿）：
1. `testFullChainRealPointerSessionCreateFolderThenCellMouseDownLaunches` —— 真实 QuitOnBlankClickWindow + 合成 NSEvent 经 **AppGridCellView.mouseDown 真视图入口** + **真实 pointer 会话建夹**（mouseDown→dragged→mouseUp 过阈值落 B 中心 → .createFolder → .committed，**弃 onCommit seam 直呼**）+ E2 核心（建夹后立点顶层 app → launched）+ census 链段断言 + Path A 抑制/恢复状态断言 + 连点 6 次。
2. `testWindowSendEventClassifiesCellAndBlankWithCensus` —— 真 window.sendEvent + 真 `blankClickResolvesToCell` 分类：cell 命中放行（s8d）/空白命中走 terminate 通路（s8a+s8c，本地旗标观测不真退）。
3. `testWindowSwallowsBlankClickWhileSessionActiveWithCensus` —— 会话活跃时空白 mouseDown → onDragActiveCancel → cancel(.escape) → 吞点（s8b）。
4. `testBlankBranchWhileSuppressedFormsSuppressionResidency` —— **N1 结构性复现**（见 §Stage1.5-2）。
5. `testSuppressionResidencyObservedAtNextPointerDownAfterStaleSecondDrag` —— 纯滞留态形成（stale-source secondDrag 保持仲裁 → controller idle 但抑制 true）+ s9_leak 入口观测 + fallback 分支 endSession 自愈 + 回退派发仍启动。
6. `testDragGateClosedSilentlyRejectsPointerDownWithCensus` —— N2 面：dragGate 关闭时 Path B click 一并被拒（s1+1、launcher 不动、controller idle），Path A 仍活（对照）。

fixture 生产保真升级（同文件）：`closeFolder` 补 `coordinator.cancel(.overlayClosed)`（AppDelegate:751 同构；C′ 缺此行会高估滞留）；`dragGate` 标题编辑腿（AppDelegate:597-602 同构）；`DragUISessionCoordinator.shared` 设置（AppDelegate:536 同构——cell.mouseDown 的 `dragCoordinator ?? shared` 兜底）；`launch.onLaunchAttempt` census 观察；挂载后 `layoutSubtreeIfNeeded()`（headless 无显示周期，惰性 cell 零 frame——只补布局不改语义）。

### 已建模层（相对 C′ 五盲区）
① window.sendEvent/hitTest/blankClickResolvesToCell 真分类（测试 2/3）；② cell.mouseDown 真视图入口（合成 NSEvent，测试 1/4/5/6）；③ surface NSClickGestureRecognizer 并行通路（以 `isEnabled` 状态代理断言抑制/恢复；测试 1/3/4/5/6）；④ 窗口 seams（onDragActiveCancel/onEscapeDuringDrag/folderOpenStateProvider/onBlankClick 生产同构接线）；⑤ 真实 pointer 会话建夹出 .committed（弃 seam 直呼）。

### 仍未建模层清单（mandate 要求显式列出）
1. **真 AppDelegate.handleDragCellClick/launchMember 方法体**（private；同构转录 + 生产内 s7/s7b 计数点对冲——真机 E 序列经真方法体产出 census，漂移可对账）。为测试放宽访问级别 = Stage 1 未授权结构修改，已拒绝。
2. **AppSearchController 搜索腿**（dragGate 搜索腿 / onBlankClickShouldExitSearch 真接线；harness exitSearch 恒 false）。
3. **super.sendEvent 的 AppKit 无头路由**（cell 命中后 NSWindow 内部 mouseDown 派发到视图；真机 E 序列覆盖）。
4. **key-window / first-responder / activation-click**（H2 判别属 E3 实机）。
5. **全屏过渡吞识别器**（AppDelegate :908-914 注述的历史面）。
6. **NSClickGestureRecognizer 真识别**（headless 仅状态代理，不驱动真识别回调）。
7. **真实 NSWorkspace 启动**（RecordingLauncher 替身）。

## Stage 1.3 实机实验序列 E1-E7 操作定义（Main 转交用户执行；结果回填本文件 §Stage1.4）

统一前置：以 `PAGING_CLICK_CENSUS=1` 启动（release/debug 均可）：
`PAGING_CLICK_CENSUS=1 .build/release/PagingPrototypeApp`（如需持久化基线另加生产既有参数）。
每步记录：①stderr 的 `PAGING_CLICK_CENSUS <sink> <n>` 全量序列（计数为累计值，步进=该步增量）；②启动结果（目标 app 是否启动）；③launcher 窗口是否退出/隐藏/无反应；④点击后间隔约 2s 再做下一步。

- **E1 冷启动单击**：冷启动 → 单击任一顶层 app cell 一次。
  读数要点：期望 `s8d+1`（cell 放行）→ `s6_dispatch_click_cell+1`（Path B 派发）→ `sA_launch_accepted+1`；`s9_leak==0`。判读：`s1+1`→dragGate 关（启动即搜索/标题编辑状态异常）；`s4b+1`→N3；census 全零且未启动→事件未达窗口层（H2 面）；`s8c+1`→空白误判（S8，窗口应消失）。
- **E2 建夹后立点顶层**：同一会话拖 A 到 B 中心建夹 → 松手后立即（≤2s）单击一个剩余顶层 app。**记录 launcher 是否退出/隐藏/无反应。**
  读数要点：`s1`（建夹后 isTitleEditing 残留→+1）、`s4b`（重建后 cell token 解析失败→N3）、`s4e`/`s9_leak`（N1 滞留）、`s7b`（launchMember guard）、`sA_launch_rejected_*`（S9）、`s8c`（误判退出）。
- **E3 同一 app 第二击**：E2 后对同一 app 再单击一次。
  判读：**第二击活（启动或 census 走到 dispatch）= H2 activation-click**（无 acceptsFirstMouse，首击仅激活窗口）；**持续死 = H1/H3 结构滞留**（结合 E2 的 s9_leak/s1 区分）。
- **E4 开夹→成员启动→关夹→再点顶层**：恢复性判别。
  读数要点：关夹应见 `s9b_endsession_restored+1`（closeFolder→cancel(.overlayClosed)→endSession 代偿）且其后 `s9_leak==0`；若关夹后仍滞留→生产代偿面失效证据（Stage 2 N1 强依据）。
- **E5 ESC 后再点**：单击 ESC → 再点顶层 app。
  读数要点：`s8b`（ESC 是否被窗口吞）+ `s1`（ESC 后 isTitleEditing 状态）。
- **E6 搜索开合后再点**：Command-F 开搜索 → ESC 关 → 立即点顶层 app。
  判读：`s1+1` = dragGate 搜索腿残留（N2/搜索状态机面）。
- **E7 重启不建夹先点顶层**：重启 → **第一次交互即**单击顶层 app（对照基线 + 持久化 load 后 servedRevision 时序）。
  读数要点：`s7b`/`sA_launch_rejected_rejectedStaleRevision`（S7/S9 时序面）；健康则与 E1 同形。

### census 表（E1-E7 × S1-S9）——**待回填**（占位；用户执行后由 Main/Worker 填入每步累计读数与步进）

| sink | E1 | E2 | E3 | E4 | E5 | E6 | E7 |
|---|---|---|---|---|---|---|---|
| s0/s1/s2/s3 | — | — | — | — | — | — | — |
| s4a/s4b/s4c/s4d/s4e/s4f | — | — | — | — | — | — | — |
| s5/s6/s6b | — | — | — | — | — | — | — |
| s7/s7b | — | — | — | — | — | — | — |
| s8/s8b/s8c/s8d | — | — | — | — | — | — | — |
| s9_leak/s9b | — | — | — | — | — | — | — |
| sA_launch_* | — | — | — | — | — | — | — |

## Stage 1.4 验证记录（真实执行）

- `swift build -c debug` → exit 0。
- `swift test` 全量 → **1051 tests, 0 failures**（含本任务新增 6；本任务前基线实测 1045——任务包所记 1036 为早前快照，其间并行波有增量）。RunLoopFrameDriverTests 本轮无 flaky 复现（未触发隔离复跑程序）。0 executed 情形未出现（非 INVALID_TEST_EXECUTION）。
- `swift build -c release` → exit 0。
- census env 默认关 → 既有测试全绿（零输出不破坏任何既有断言）。

## Stage 1.5 census/harness 初步发现（观测形态，先于任何结构修改落盘）

1. **双启动通路拓扑（装置建立时确认的链路事实）**：Path A = AppLaunchController surface `NSClickGestureRecognizer`（AppLaunchController.swift:93-98 install，冻结文件）→ handleGesture → handleClick → 沿视图链找 cell → handleCell 校验链；Path B = cell.mouseDown → coordinator → .clicked → onCellClick → handleDragCellClick（AppDelegate:653-663）→ launchMember（:763-768）→ makeMemberLaunchCell → handleCell。**耦合机制**：beginArbitration（coordinator:343-348）的 clickRecognitionSuppressor(false)（AppDelegate:591-595）禁用的是 surface 上**全部** NSClickGestureRecognizers——含 Path A 的启动识别器；folder 开夹走 **cell 级** folderClickRecognizer（AppGridCellView:43/94-96，不在 surface 上）不受 surface 级抑制影响 → 与症状「folder cell/成员可开、顶层 app 单击无响应」结构吻合。
2. **N1 精确形态（harness 确定性复现）**：(a) 纯空白路径（:117 sourceCell==nil → :181）从不设抑制，N1 在纯空白流无害；(b) 滞留形成 = 「活会话持有抑制」时叠加空白候选（N3 面的 pendingBlank 武装）→ pointerUp 走 blank 分支（:181-186 无 endSession）→ controller 僵尸 .pressed + 抑制滞留 + **Path A（surface 启动识别器）死**（测试 4）；(c) 纯滞留态（抑制 true + 无活会话）第二形成面 = stale-source secondDrag「保持仲裁」→ controller 归 idle 但抑制仍 true → 下一次 pointerDown 入口 `s9_leak` 观测（测试 5）。
3. **生产代偿耦合（关键保真发现）**：AppDelegate.closeFolder（:749-757）首行 `dragCoordinator?.cancel(.overlayClosed)` → controller 非 idle 时 endSession → blank 分支残留被**同一事件内**代偿。即生产当前依赖 onOverlayBlankClick 的实现细节做会话卫生；C′ fixture 缺该行（本波已补）。⇒ N1 的实际危害窗口 = onOverlayBlankClick 接线不含 cancel 的任何形态/未来回归；Stage 2 N1（blank 分支补 endSession）解除该耦合。
4. **N2 证实（census 面）**：dragGate 注释「点击不受影响」（AppDelegate:532、coordinator :52-53）与实现矛盾——dragGate 在 pointerDown 最早段拦截，Path B click 一并静默丢失（测试 6：s1+1、launcher 不动、controller idle、Path A 仍活）。**双通路齐灭 = Path A 死（抑制滞留/S9 rejected_*）⊕ Path B 静默门（s1/s4b/s3/s7b 任一）**——单 N2 只有 Path B 死，不构成完整症状。
5. **双 dead-面交叉（无需抑制的最短形态）**：cell token 不可解析（bindingToken nil/查无 record）→ Path B 走 s4b（pendingBlank）→ blank 分支 → onOverlayBlankClick → closeFolder no-op；Path A handleCell → rejectedNoBinding。两路齐灭且窗口不退（cell 分类为真 → 不走 s8c）＝「点了没反应」。E2/E3 的 s4b/sA_launch_rejected_rejectedNoBinding 读数直接判别。
6. **真机判读规则（E1-E7 回填用）**：s1+1→H 系 dragGate 面；s4b+1→N3；s4e/s9_leak→N1；s8c+1→S8（用户可见退出）；s7b→S7；sA_launch_rejected_*→S9；census 全零+未启动→窗口层/key-window 面（H2，看 E3 第二击）。

## Stage 1.6 Stage 2 修法映射（预授权项；待 E1-E7 回填后执行）

| 项 | 修法 | 依据 |
|---|---|---|
| N1 | pointerUp blank 分支补 `endSession()`（幂等：isSuppressingClickRecognition guard 使重复调用安全） | harness 测试 4/5 确定性复现滞留形成 + `s4e`/`s9_leak` 计数点；E 序列回填后标注「依据：census E 编号」 |
| N3 | pendingBlankPress 收窄为 sourceCell==nil；sourceCell≠nil 但 resolveSource 失败 → 武装 clickFallbackCell（复用 :188-200 既有派发） | `s4b_pendingblank_withcell` 计数点语义（死路 A 归位为可派发/可计数路径） |
| N2 | dragGate 注释改为与实现一致（:52-53、AppDelegate:532；不拆分 drag/click 门——后者需决策文件，未授权不擅自） | 测试 6 证实「点击不受影响」注释为假；`s1` 计数点 |
| 其余 H1/H2/H3 面 | **待 E1-E7 census 读数**；每处修改注明「依据：census E 编号」；禁止无证据加固 | census 表回填 |

## Stage 1.7 结论与建议

- Stage 1 mandate 三件套全部完成：census 装置（默认零输出、仅计数、内存可读）、全链 harness（6 测试绿 + 仍未建模层清单）、E1-E7 操作定义。
- **提前进入 Stage 2 建议**：N1 滞留形成已获 harness 结构性铁证（测试 4/5，含 Path A 死亡的识别器状态代理断言），N2 矛盾已证实，N3 计数点已就位——**N1/N3/N2 三项预授权修法可立即执行，不必等待 E1-E7**；E1-E7 回填仅用于 (a) census 表六态验收、(b) H1/H2/H3 其余面处置、(c) 每处修改的「依据：census E 编号」标注（N1/N3/N2 的依据可先引 harness 测试 + E 回填后补注）。
- Red flags 自查：零触碰 AppLaunchController/冻结树/Package.swift/Docs/PROVENANCE；无 dragGate 行为变更、census 无常开（env 门控）、无身份输出；真链路证据 = cell.mouseDown 合成 NSEvent + 真实 pointer 会话（镜像路径仅作 Path B 尾部同构转录并列未建模层）。
## Stage 2 修法执行（Main 批准 N1/N3/N2 三项；其余 H 面不动）

### Stage 2.1 改动清单（落点 + 依据标注）

1. **N1** DragUISessionCoordinator.swift pointerUp `pendingBlankPress` 分支（Stage1 行号 :181-186）：补 `endSession()`，位置 = census 计数后、`onOverlayBlankClick()` **之前**（与 fallback 分支 BUG6 Wave C「先清会话/恢复抑制再派发」同一先例；幂等：isSuppressingClickRecognition guard）。结构改为 `isBlankClick` 先判，endSession 覆盖分支两子形态（未过阈值派发 / 过阈值取消）。
   **依据：harness 测试 4/5（Stage 1 滞留确定性复现）+ census `s4e_blankbranch_suppressed` / `s9_leak_suppression_resident`**（E1-E7 回填后补注「依据：census E 编号」）。
2. **N3** 同文件 pointerDown resolveSource 失败 guard（Stage1 行号 :117-120）：`pendingBlankPress` 收窄为 `sourceCell == nil`；`sourceCell ≠ nil` 且解析失败 → `ClickCensus.hit(fallbackArmed)` + `clickFallbackCell/clickFallbackDownPoint` 武装（复用 pointerUp fallback 分支既有派发，s4f 路径）。s4b 保留观测。`clickFallbackCell` 文档注释同步扩展（Defect-3 + N3 两种武装形态）。
   **依据：census `s4b_pendingblank_withcell` 计数点语义**（死路 A 归位为可派发/可计数路径）。
3. **N2** 两处注释改与实现一致（不拆门）：coordinator `dragGate` 声明 doc（Stage1 :52-53）+ AppDelegate :542（installDragUI 文档行）。新语义：dragGate false → 整个 pointerDown 静默拒绝（含 Path B click 派发路径；Path A surface 识别器不受影响）。
   **依据：census `s1_draggate_closed` + harness 测试 6（testDragGateClosed…）**。

### Stage 2.2 测试改写（test 4 拆二，净 +1）

- `testTokenlessCellInterleaveArmsFallbackAndEndsSessionN3Fix`：活会话（.pressed+抑制 ON）→ tokenless pointerDown → s4b+s4c（不再 arm 空白候选）→ up → fallback 分支 s4f + endSession + onCellClick（tokenless → handleCellClick 镜像静默 = S6 面）→ 断言 `s4d==0`、blankClicks==0、recognizer 恢复、`s9_leak==0`、二次 pointerDown/up → `.launched`（自愈确认）。
- `testBlankBranchEndsSessionWhileSuppressedN1Fix`：活会话 → stale secondDrag（controller idle+抑制 ON 纯滞留态）→ 真空白 pointerDown（s4a+pendingBlank）→ up → s4d+s4e → **endSession 自愈**（onOverlayBlankClick 置空隔离 closeFolder cancel 代偿面）→ recognizer 恢复 + isSessionActive false；后续 pointerDown 断言 s9_leak **增量**==0（step 3 入口 s9_leak=1 是 secondDrag 滞留态的合法入口观测、已被 step 4 愈合；初版误用绝对零断言，已改增量——census 累计语义教训）→ 点击 `.launched`。
- test 5（`testSuppressionResidencyObservedAtNextPointerDownAfterStaleSecondDrag`）原样保留且通过：其滞留形成 = secondDrag 保持仲裁路径，N1/N3 不触及。
- 全链测试 s9_leak==0 断言维持（验收面：真实会话建夹 → 顶层单击 → launched 且滞留 0）。

### Stage 2.3 验证

- swift test 全量 **1052 / 0 failures**（Stage 2 前基线 1051；+1 = test 4 拆二）；`swift build`（debug，test 隐含）+ `swift build -c release` exit 0。
- 写盘仅四文件（写范围内）：`Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift`（N1/N3/N2）、`Sources/PagingPrototypeApp/AppDelegate.swift`（N2 注释）、`Tests/PagingUITests/DragCommitIntegrationTests.swift`、本结果文件。AppLaunchController.swift / 冻结树 / Package.swift / Docs / PROVENANCE 零触碰；无 git 操作。

### Stage 2.4 E1-E7 回填衔接（census 表就绪，无需等待回填交付）

- 修法已入 debug/release 构建 → Main 转交用户执行 E1-E7（一次完成修复验证 + census 回填，§Stage1.4 操作定义不变）。
- **修复后判读基线**：s4b 仍计数（观测面）但行为已归位 fallback；s4e 仍可计数（分支执行时抑制仍 true 的观测）但应紧随 s9b 恢复；**s9_leak 全序列应恒 0**（任何非零 = 仍有滞留面未闭合，回填后需升级）；s4d 仅真空白（sourceCell==nil）时出现。
- §Stage1.3 census 表回填后逐项补「依据：census E 编号」即可，Stage 2 交付不以其为前置。
