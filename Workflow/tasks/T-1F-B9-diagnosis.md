# T-1F-B9-diagnosis — BUG9 主页面点击全部失效（Chief 诊断任务）

- Status: ready
- Wave: BUG9（串行：诊断 → 修复波次）
- Role: Chief（诊断产出 BUG9-REPORT + 任务包；不写产品代码）
- 上游：用户实机报告（2026-09-02）"现在在主页面点击软件都打不开"；BUG8 wave-c+wave-v 已合并（基线 1052/0）

## §1 用户报告

主页面点击 app 全部打不开（folder 内状态未报告，需 Chief 判定是否需用户补测）。

## §2 Main 已核验事实（只读，2026-09-02 现行行号）

1. census 读数（PAGING_CLICK_CENSUS=1，bash-24）：`s8d_window_cell_passthrough ×9`、`s8_window_blank_unclassified ×1`、`s8c_window_blank_terminate ×1`。窗口层（QuitOnBlankClickWindow.sendEvent，AppDelegate.swift:1016-1130）9 次点击全部 cell 命中放行 super.sendEvent(event)，但 coordinator 层 sink 零输出（s0-s9/sA/s6 全无）。
2. ClickCensus（DragUISessionCoordinator.swift:28-100）所有 sink 同一 stderr 输出（env 门控）——s8d 输出证明机制工作；coordinator 零输出 = pointerDown 未被调用（s9 是 if 非 guard，任何路径都会经过）。
3. 装配完整：installContentAssembly（AppDelegate.swift:312-400）无失败打印；installDragUI（:530-598）执行，:533 `DragUISessionCoordinator.shared = coordinator`。
4. teardownAll（:971-1010，:1000 清 shared=nil）只在 selfDrive 结束（:896）/windowWillClose（:964）/applicationWillTerminate（:968）调用——启动路径无调用。
5. cell 在视图树：AppGridPageView.prepareCells（:213-226）创建 AppGridCellView 并 addSubview（:219）；AppGridCellView.mouseDown（:184-187）调 `(dragCoordinator ?? DragUISessionCoordinator.shared)?.pointerDown(...)`。
6. 全仓仅 2 个 mouseDown 覆写：FolderOverlayView.swift:267、AppGridCellView.swift:184。PagingSurface 无 mouseDown/hitTest 拦截（仅 scrollWheel :317）。AppGridPageView 无事件处理。KeyboardFocusController（NSView 子类）hitTest 返回 nil（:128，穿透）。无 acceptsFirstMouse 覆写（NSView 默认 false）。
7. 窗口流程：makeKeyAndOrderFront（:252）→ makeFirstResponder(keyboardController)（:253-255）→ NSApp.activate（:257）→ 0.3s 后 toggleFullScreen（:266-270，总是全屏）。bash-24 输出 `paging-fullscreen: styleMask.fullScreen=true frame=(0,0,1470,923)`。
8. 视图层级：container（contentView，:209）→ surface（:211-213）+ search field（:216-218）。

## §3 剩余假设（Chief 判定）

- A) cell.mouseDown 未被调用——事件分发问题：窗口非 key（全屏过渡后 key 状态丢失？acceptsFirstMouse 默认 false 首击只激活？9 次全无输出除非窗口一直非 key）；或 hitTest 命中视图非 cell 子视图链。
- B) shared 运行时为 nil——cell.mouseDown 被调用但 `(dragCoordinator ?? DragUISessionCoordinator.shared)?` 静默跳过。
- C) 其他：事件被 AppKit 层吞（全屏过渡吞识别器相关代码 AppDelegate:908-914 未细查）。

## §4 产出要求

- Workflow/BUG9-REPORT.md（根因定位/证据/修复建议）
- Workflow/tasks/T-1F-B9-wave-*.md（修复任务包，沿用 BUG8 格式：根因固化/修法/写范围/禁写/必测/验收）
- 如需要：Workflow/decisions/D-*.md

## §5 约束

冻结树=Sources/PagingCore、AppCatalogCore、MacAppCatalog、AppIconPipeline、PagingTelemetry、PagingUI、Package.swift、PagingPrototypeApp/AppLaunchController.swift；Main 不实现；每缺陷=Worker→独立 Reviewer PASS→合并；禁读 LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse；无 git；隐私 A/B/C 代称。
