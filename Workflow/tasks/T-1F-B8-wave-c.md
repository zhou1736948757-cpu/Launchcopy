# T-1F-B8-wave-c — BUG8 缺陷 2：建夹后顶层 app 单击无响应（症状三现，取证先行两段式）

Status: ready（Stage 1 取证；Stage 2 结构修改以 Stage 1 证据落盘为闸）
Wave: BUG8-wave-c（可与 wave-v 并行——写范围零交集）
Role: Worker（取证装置+结构修改）→ 独立 Reviewer → Main 合并

## §1 背景

建夹 commit 后顶层 app 单击打不开（folder cell/成员可开），症状三现（BUG6 缺陷2→BUG7 缺陷3→本次）。C′ harness 连点 6 次全 .launched 系**结构性失明**：直呼 coordinator.pointerDown/pointerUp（DragCommitIntegrationTests.swift:463-471）+ handleCellClick 镜像（:152-163），从未建模 window.sendEvent/cell.mouseDown/surface recognizer/key-window/真 handleDragCellClick 五层（BUG8-REPORT §2.2）。诊断产出两条**已证潜伏缺陷**：N1 pointerUp blank 分支（DragUISessionCoordinator.swift:181-186）无 endSession → 会话/抑制滞留；N3 resolveSource nil 把有 cell 的按下当空白（:116-120，死路 A）。另有 N2 dragGate 文档/实现矛盾（:105 vs :52-53、AppDelegate:532）。

## §2 锚点（全部已实测，2026-09-02）

- 链路：AppDelegate.swift:1029-1070（sendEvent，blank 吞点 :1064→terminateOnBackgroundClick :233-235）、:1077-1090（blankClickResolvesToCell）；AppGridCellView.swift:184-197（mouseDown 三件套，无 super、无 acceptsFirstMouse override）；DragUISessionCoordinator.swift:103-135（pointerDown 五静默门 :104/:105/:106/:117-120/:121）、:174-226（pointerUp：blank :181-186 **无 endSession**、fallback :188-200、idle 吞 :202）、:343-366（beginArbitration/endSession）、:370-390（resolveSource/appReference）；DragSessionController.swift:62-92（pointerDown secondDrag :67-69/sourcePresent :71）、:263-272；AppDelegate.swift:653-663（handleDragCellClick :660 if-let 静默）、:749-757（closeFolder）、:763-768（launchMember 三静默 guard）、:539-547（layoutProvider）、:573-576（异步持久化 enqueue）、:591-602（suppressor/dragGate 接线）、:696-712（applyPendingAtIdleBoundary）；FolderOverlayView.swift:267-303（member 路由/hitTest 恒 self）。
- 冻结面：AppLaunchController.swift:93-98 install()、:123-125 handleCell、:129-143 launch —— **绝不触碰**；S9（rejectedStaleRevision/rejectedNoBinding）只能计数观察。

## §3 写范围 / 禁写

- 写：`Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift`（N1/N3/census）、`Sources/PagingPrototypeApp/AppDelegate.swift`（census 计数点 + dragGate 注释修正；行为性修改须证据背书）、测试文件（Tests/PagingUITests/ 新增/扩展）。
- 禁写：冻结树六目录 + Package.swift + **AppLaunchController.swift**；DropIntent/DropResolver/DragMutationEngine/DragSessionController/DragGeometry/DragUIVisuals（wave-v 范围）；Docs/；无 git。

## §4 必读

Workflow/BUG8-REPORT.md（§2 全节 + §2.5 判别假设 + §4 wave-c mandate）、BUG7-REPORT.md、results/T-1F-B7-wave-c.md、reviews/T-1F-B7-wave-c-r1.md QUESTION-1、Docs/ADR-010。

## §5 Stage 1 取证 mandate（先落证据，零结构修改）

1. **中性 sink census**：S1-S9 各一计数点（coordinator :104/:105/:106/:117/:121/:129/:181/:188/:202 + window :1040/:1045/:1064 + handleDragCellClick :655/:660 + launchMember :764-765）；env 开关（如 PAGING_CLICK_CENSUS=1）默认关；仅递增计数（stderr 或内存可读），无身份/标题/路径；抑制滞留（isSuppressingClickRecognition 持续 true 跨会话）单独计数。
2. **harness 补盲区**：新增全链测试——经 `AppGridCellView.mouseDown`（合成 NSEvent）驱动单击 + 真 blankClickResolvesToCell 分类 + 弃镜像、直挂与 AppDelegate 同构的真派发链（PagingUITests 已有 AppDelegate 级先例）；建夹 commit 用**真实 pointer 会话**（pointerDown→dragged→up 出 .committed），不再 onCommit seam 直呼；断言 census 计数与启动结果。报告须显式列「仍未建模层」清单。
3. **实机实验序列（Main 转交用户，结果回填）**：E1 冷启动单击→E2 建夹后立点顶层（记录：launcher 是否退出/隐藏/无反应）→E3 同一 app 第二击（**第二击活 = H2 activation-click；持续死 = H1**）→E4 开夹→成员启动→关夹→再点顶层（恢复性）→E5 ESC 后再点→E6 搜索开合后再点（dragGate 判别）→E7 重启不建夹先点顶层。每步记 census 读数。

## §6 Stage 2 结构修改（Stage 1 证据落盘后；本包预授权项）

1. **N1**：pointerUp blank 分支补会话卫生——onOverlayBlankClick 后（或分支内）调用 endSession()（幂等：isSuppressingClickRecognition guard 使重复调用安全），杜绝抑制滞留。
2. **N3**：pendingBlankPress 收窄为 sourceCell==nil；sourceCell≠nil 但 resolveSource 失败 → 武装 clickFallbackCell（复用 :188-200 既有派发），死路 A 归位为可派发/可计数路径。
3. **N2**：dragGate 注释改为与实现一致（或在证据支持时拆分 drag/click 门——后者需决策文件，勿擅自）。
4. census 按 census 证据处置 H1/H2/H3 其余面；每处修改注明「依据：census E 编号」。**禁止**无证据的额外加固（防过度修复）。

## §7 验证与验收

- Stage 1：新增测试绿 + 全量 `swift test`（1036+；RunLoopFrameDriverTests flaky 按隔离复跑程序）+ debug/release exit 0；census 默认零输出（env 关）既有测试全绿。
- Stage 2：验收 = 复现链（真实会话建夹→cell.mouseDown 顶层单击）在 census 观测下走到 onCellClick/launchMember 且 launched；空白退出/成员启动/folder 打开/拖拽四回归面全绿；抑制滞留计数器在回归测试中断言为 0。
- 验收六态：证据文件含 census 表（E1-E7 × S1-S9）+ 结论 + 修法映射，缺任一不得进入 Stage 2 合并评审。

## §8 输出纪律 / Red flags

results 写 Workflow/results/T-1F-B8-wave-c.md（分 Stage 1/§2 节）；先取证后修改，时序可复核（观测版先跑、结论先落盘、再转硬断言）。Red flags：任何「顺手修」冻结面/AppLaunchController 的冲动；把 Stage 2 未授权项（dragGate 行为变更、census 常开、日志带身份）塞进实现；用镜像路径充当真链路证据。