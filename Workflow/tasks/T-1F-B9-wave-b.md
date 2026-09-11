# T-1F-B9-wave-b — BUG9 取证补盲（两段式：Stage 1 census+E 序列；Stage 2 预授权）

Status: ready（Stage 1）；Stage 2 blocked-on-Stage-1 读数
Wave: BUG9-wave-b（与 wave-a 零文件交集，可并行；Stage 2 在 wave-a 合并前后均可按读数触发）
Role: Worker（实现+测试）→ 独立 Reviewer（只读门禁）→ Main 合并

## §1 背景

BUG9-REPORT §2：R5（激活点击吞没/窗口 key 状态）与 R2（Path A 识别器不可靠+抑制不可测）尚无测量装置。全仓无任何 isKeyWindow/NSApp.isActive 观测点（grep 零命中）；抑制状态计数点 s9 在 pointerDown 内部（DragUISessionCoordinator.swift:202-205）——pointerDown 不跑则恒盲。本波补齐窗口层与抑制层计数器，并给出实机判别序列；**Stage 1 零行为变更**。

## §2 根因/取证锚点（现行行号）

- AppDelegate.swift:1016-1130 QuitOnBlankClickWindow.sendEvent（cell 判定 :1077-1090，super 放行 :1069）——s8e 计数点加在 leftMouseDown 分类处。
- AppDelegate.swift 抑制闭包（installDragUI 内 suppressor enable/disable 两向，:591-604 区域）——s13 计数点。
- 已知文档化 Path A 缺陷：AppDelegate.swift:935-942 T-1C-D repair 注记（识别器 may-not-fire：全屏过渡吞首击、位移>10pt 静默失败）。
- 判别逻辑：BUG9-REPORT §5 判别表（E1-E5 → R1/R5/R2 归因）。

## §3 写范围 / 禁写

- 写（Stage 1）：`Sources/PagingPrototypeApp/AppDelegate.swift`（仅 QuitOnBlankClickWindow.sendEvent 一处 + 抑制闭包两向各一处 census 调用；`extension ClickCensus.Sink` 声明可放同文件）。测试可并入既有 window/装配测试或新文件，报告声明。
- 禁写：冻结树（含 AppLaunchController.swift——**Path A 识别器本体在冻结面内，只测不改**）；AppGridCellView.swift/DragUISessionCoordinator.swift/FolderOverlayView.swift（wave-a 领地）；Docs/；无 git。
- Stage 2（仅预授权，读数触发才动）：① s8e 显示死点击时 `!window.isKeyWindow || !NSApp.isActive` → AppGridCellView 加 `override func acceptsFirstMouse(with:) -> Bool { true }`（仅 cell，不改全局）+ AppDelegate 观察 `windowDidEnterFullScreen` 后 `!isKeyWindow` 时 makeKeyAndOrderFront（≤10 行）；② s13 显示抑制滞留（enable 后无对应 disable/会话结束仍 false）→ **不自动修**，回报 Chief 另立波（沿用 BUG8 wave-c N1 处置语义）。

## §4 必读

Workflow/BUG9-REPORT.md 全文；AppDelegate.swift:930-950/:1016-1130（窗口层）/:536-616（installDragUI 与抑制闭包）；DragUISessionCoordinator.swift:22-100。

## §5 实施要求（Stage 1）

1. s8e_window_key_state：sendEvent 处理 leftMouseDown 时计数一次，携带 key 状态仅入内存 snapshot（`window.isKeyWindow`、`NSApp.isActive` 两 bool；stderr 输出保持无身份原则，只打 sink 名+状态位）。
2. s13_suppression_toggle：抑制闭包启用/恢复两向各计一数（s13a_enable/s13b_disable）。
3. 零行为变更：所有新增代码只递增计数/读状态，不改任何分支条件；env PAGING_CLICK_CENSUS=1 门控沿用。

## §6 验证与验收

- 测试：s8e 在 key/非 key 两种夹具窗口下均计数；s13a/s13b 与既有抑制测试联动计数一致；`swift build` debug/release exit 0；`swift test` 全量绿。
- 实机 E 序列（Main 组织，census 开启）：E1 冷启动后首击 **图标**；E2 冷启动后首击 **cell 背景**（不落 icon）；E3 点击后切走再切回的首击；E4 folder 成员点击（对照，应活）；E5 空白点击（已知 terminate，最后做）。读数回填 results census 表。

## §7 输出纪律

results 写 Workflow/results/T-1F-B9-wave-b.md：census 表（s8e key 状态分布/s13a/s13b/E1-E5 对应读数）/deviation/未触碰声明/Stage 2 触发判定建议（触发哪项预授权或均不触发）。

## §8 风险与 Red flags

- 严禁借 Stage 1 顺手改行为（含「顺手修」acceptsFirstMouse）——Stage 2 必须看到读数后才动。
- s8e 不得打印窗口标题/坐标/应用名（隐私 A/B/C）。
- 冻结面出现任何「需要改 AppLaunchController 才能测」→ 停手报告 Chief（BUG8 D4 有冻结面升级路径，走决策不走硬改）。