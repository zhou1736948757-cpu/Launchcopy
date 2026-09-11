# T-1F-B9-wave-b — BUG9 取证补盲 Stage 1（s8e 窗口 key 态 + s13 抑制可见性，零行为变更）

Status: **complete（Stage 1）— 待 Reviewer 门禁 + Main 合并**
Worker: chef-worker-reviewer-workflow Worker（BUG9-wave-b Stage 1；Stage 2 未实现，仅判定建议）
基线：BUG8 wave-c+wave-v 已合并（BUG9-REPORT §0：1052/0）。

## §1 实施快照（Stage 1 范围，全部落地）

| 项 | 位置（现行行号） | 内容 |
|---|---|---|
| s8e_window_key_state | `Sources/PagingPrototypeApp/AppDelegate.swift:1069-1074` `QuitOnBlankClickWindow.sendEvent` leftMouseDown 分支首行（`if let contentView` 之前） | 每次 leftMouseDown 计数一次；sink 名携带 `key{n}_active{n}` 两状态位（`isKeyWindow` / `NSApp.isActive`），仅入内存 snapshot；stderr 只打 sink 名+计数（无身份） |
| s13a/s13b | 同文件 `installDragUI` 抑制闭包 `:603-614`（`guard let surface` 之后） | coordinator 语义：闭包收到 `enabled=false`（抑制启用/仲裁窗口开启）→ `s13a_enable`；`enabled=true`（endSession 恢复）→ `s13b_disable`。仅计实际作用于 surface 识别器集合的 toggle |
| sink 声明 | 同文件 `:1140-1161` `extension ClickCensus.Sink`（任务包 §3 允许放同文件） | `windowKeyStateBase` / `windowKeyState(isKeyWindow:appActive:)`（两 bool → 四变体）/ `suppressionEnable`（"s13a_enable"）/ `suppressionDisable`（"s13b_disable"） |
| 测试 | `Tests/PagingUITests/DragCommitIntegrationTests.swift`（并入既有 window/装配 census 测试文件） | ① fixture 抑制闭包同步为生产同构 + census 行（:282-294 区域）；② 新增 3 测试：`testWindowKeyStateCensusCountsInKeyAndNonKeyFixtures`、`testWindowKeyStateCensusVariantNamesCarryKeyAndActiveBits`、`testSuppressionToggleCensusMatchesRecognizerTransitions` |

- 零行为变更声明：新增代码仅 `ClickCensus.hit(...)` 递增与两 bool 读取；未改任何分支条件、事件路由、hitTest/acceptsFirstMouse（Stage 2 预授权项未实现）。env `PAGING_CLICK_CENSUS=1` 门控沿用既有机制（未改）。
- 既有测试文件仅两处触碰：fixture 抑制闭包加一行 census（生产保真，不改 fixture 行为语义）+ 文件尾追加 3 个新测试；wave-c 既有测试断言零改动（census 机制为附加 sink，不影响其既有 sink 计数断言）。

## §2 census 表（Stage 1 读数）

### s8e key 状态分布

单测夹具读数（`swift test` 实测；本沙箱 NSApp.isActive 实测为 0 → 夹具命中 `key0_active0` 变体）：

| sink 变体 | 单测（非 key 夹具） | 单测（key 夹具，授权被拒仍计数） | E1 冷启首击图标 | E2 冷启首击 cell 背景 | E3 切走切回首击 | E4 folder 成员 | E5 空白 |
|---|---|---|---|---|---|---|---|
| s8e_window_key_state_key1_active1 | 0 | 0 | — | — | — | — | — |
| s8e_window_key_state_key1_active0 | 0 | 0 | — | — | — | — | — |
| s8e_window_key_state_key0_active1 | 0 | 0 | — | — | — | — | — |
| s8e_window_key_state_key0_active0 | 1 | 1 | — | — | — | — | — |

E1-E5 列留待 Main 实机（census 开启）回填——**s8e 的 R5 判别价值（死点击时 key/active 位分布）必须来自实机读数**，单测只证明装置本身逐事件计数 + 状态位实测写入。

### s13 抑制可见性

| sink | 语义 | 单测读数（两会话周期后） | 实机读数 |
|---|---|---|---|
| s13a_enable | 抑制启用向（suppressor(false)，beginArbitration） | 2 | — |
| s13b_disable | 抑制恢复向（suppressor(true)，endSession） | 2 | — |

联动一致性（新测试 `testSuppressionToggleCensusMatchesRecognizerTransitions`）：单会话 toggle 序列恰为 beginArbitration 一次 `false` + endSession 一次 `true` → s13a/s13b 各 +1 且与 `s9b_endsession_restored` 计数等值（2==2）；`s9_leak_suppression_resident` == 0（健康链）。既有抑制链路测试（s9/s4c/s4f/s4e 系列，同文件 `testSuppressionResidency…` / `testBlankBranchEndsSessionWhileSuppressedN1Fix` / `testTokenlessCellInterleave…` / 全链测试）共用本 fixture 生产同构闭包，s13 计数随各测试的抑制状态机同步联动、全量跑绿（见 §3）。

## §3 测试证据（真实执行）

- `swift build`（debug）：**exit 0**（Build complete）。
- `swift build -c release`：**exit 0**（Build complete）。
- `swift test` 全量：**exit 0**；原文：`Executed 1062 tests, with 0 failures (0 unexpected) in 27.058 (27.155) seconds`。executed_tests=1062，failures=0。
- 计数对账：基线 1052 + 本波新增 3（本文件 §1 测试行）+ 并行 wave-a 已落定 `Tests/AppGridUITests/Bug9CellHitRoutingTests.swift` 7 = **1062**，逐项对上。
- 新增测试单独跑：`Executed 3 tests, with 0 failures (0 unexpected)`（exit 0）。

### 环境探针（key1 腿的沙箱能力记录）

本仓 `swift test` 沙箱（bash 执行器）可 `orderFrontRegardless`（`isVisible == true`）但 key/active 授权被平台拒绝：`makeKey()`/`makeKeyAndOrderFront()` + runloop spin 后 `isKeyWindow` 恒 false；`setActivationPolicy(.regular)` + `activate(ignoringOtherApps: true)` 后 `NSApp.isActive` 恒 false（三份独立探针脚本证据）。处置：非 key 腿（key0）与状态位编码为硬断言；key 夹具腿真实执行 sendEvent 并硬断言计数（s8e 计数与 key 状态无关）；key1 翻转断言放在 `if window.isKeyWindow` 分支（环境授予即执行），实机 key1 读数由 Main E 序列回填。测试注记与 results 同步声明。

## §4 deviation

1. **s13 单测覆盖面**：生产 `installDragUI` 抑制闭包为 private（不可直接实例化 AppDelegate 驱动），单测经 fixture「生产同构」复刻闭包联动 s13a/s13b（本仓库 wave-c 既有模式，`DragCommitIntegrationTests` 文件头即此模式）；生产闭包本体的实机读数由 Main E 序列覆盖。未改 `installDragUI` 可见性（写范围不含该行）。
2. **key1 夹具沙箱受限**：见 §3 环境探针——key0 腿/变体名编码/计数无条件性为硬断言，key1 翻转断言条件执行；不影响任务包 §6「两种夹具窗口下均计数」（两夹具均真实执行并断言计数）。
3. **过程注记（已修复，非交付态）**：s13 首版方向映射接反（把 closure 参数 `enabled=true` 误映射到 s13a）；被本 Worker 自测第一轮捕获（s13a==0 失败），按 coordinator 语义（`suppressor(false)`=抑制启用）修正生产与 fixture 两处后复跑全绿。
4. 构建/测试与并行 wave-a 共用同一 .build 树：本轮曾捕获一次 wave-a 落定前中间态（`cellLookupNil` 未声明 + 文件写入中报错），等待其落定后重跑即恢复；wave-a 7 条测试与生产改动已随本树全量绿。

## §5 未触碰声明

- 冻结树（PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/PagingUI/Package.swift/AppLaunchController.swift）：未触碰。
- wave-a 领地（AppGridCellView.swift / DragUISessionCoordinator.swift / FolderOverlayView.swift）：未触碰（其树内变更属并行 wave-a Worker）。
- Docs/：未触碰；无 git 操作。
- Stage 2 预授权项（acceptsFirstMouse 覆写 / 全屏后 key 恢复 / N1 抑制滞留上报）：**均未实现**。
- AccessDeclaration: **NO_PRIOR_EXPOSURE**（未读 LaunchBetter/BuhoReverseNotes/2026-08-25-buho-launchpad-reverse 及任何 Ghidra/otool dump）。
- 隐私：s8e/s13 stderr 输出仅 sink 名+计数；sink 变体名仅含 key/active 两状态位，无窗口标题/无坐标/无应用名（隐私 A/B/C）；测试夹具中性（fixture.* / 'Group 1'）。

## §6 Stage 2 触发判定建议

**建议：均不触发，待 Main 实机 E1-E5 读数判定。** 依据：

- 预授权项一（acceptsFirstMouse + 全屏后 key 恢复）触发条件 = s8e 显示**死点击时** `!window.isKeyWindow || !NSApp.isActive`（BUG9-REPORT §5：s8e 显示死点击时 !isKeyWindow → R5 定罪）。Stage 1 单测只证明装置健康（逐事件计数 + 状态位写入），不产生任何死点击样本；key/active 真实分布必须来自实机序列。
- 预授权项二（抑制滞留另立波）触发条件 = s13 显示滞留（enable 后无对应 disable / 会话结束仍 false）。单测健康链读数 s13a==s13b（1:1 配对）且 s9_leak==0，为**健康基线**而非滞留证据；实机若出现 s13a 计数后长期无对应 s13b（或 E 序列中抑制窗口跨会话不恢复），才触发「回报 Chief 另立波」路径（本 Worker 无自动修授权）。
- E 序列判别提醒（Main 组织时对照 BUG9-REPORT §5 判别表）：E2 背景开而 E1 icon 不开 → R1（wave-a 已装漏斗，看 s10/s11）；s8e 死点击 key0/active0 → 预授权项一；E4 folder 成员不开 → 全局交付层升级。