# T-1F-B10 源码摘要（触摸/轻点/事件类型维度）— BuhoReverseNotes × LaunchBetter

> **AccessDeclaration: PRIOR_EXPOSURE**（2026-09-03 主控-用户明确命令授权审阅两目录，已记 CONTAMINATION_LOG.md）
> 只读诊断产物：不修改任何代码、不写产品文件。产出：本文件（结构化材料）＋回复（<400 词）。

## ① 两目录触摸/轻点/事件类型相关材料清单

**两目录共同结论：零原生触摸处理。** 全树 grep（NSTouch / touchesBegan/Moved/Ended / allowedTouchTypes / wantsRestingTouches）在 BuhoReverseNotes 与 LaunchBetter 的 Swift/ObjC/md 中均 **0 命中**。两项目都不收原始触摸事件，仅依赖 AppKit 合成鼠标事件；「轻点（tap to click）」在两目录中仅出现一次 —— 正是 LaunchBetter X2 任务的用户口述。

**BuhoReverseNotes（真实 Buho 逆向 + BuhoRebuild 复刻）：**
- `06-window-events-indicator.md` §sendEvent（0x1000b3108→FUN_1000b2fec）：LaunchpadWindow.sendEvent **按事件类型（1=leftMouseDown/2=leftMouseUp/6=leftMouseDragged）拦截** —— 与 subtype 完全无关。按下时对 contentView `hitTest:` 手动命中 → 记 `lastMouseDownView` → 直接 `[view mouseDown:]`；mouseUp/mouseDragged 路由回 lastMouseDownView（拖拽出界不丢事件）；其余走 super。窗口自身不处理左键，空白点击沿响应链上浮到窗口 `mouseUp:` → hide。另：本地监视器 mask=leftMouseDown、全局监视器 mask=0x46。
- BuhoRebuild `LaunchpadWindow.swift`：borderless **nonactivating NSPanel**，show 序列 = `orderFrontRegardless()` → `makeKey()`（canBecomeKey=true）。复刻版未重写 sendEvent（原版才做手动路由）。
- 关键点：Buho 手动投递绕开 NSWindow 内部派发 → 激活吞点对之免疫；且其判定只看 event.type，轻点（subtype=3）到达 sendEvent 时同样是 leftMouseDown，照常投递。

**LaunchBetter（本项目已解决的同类缺陷）：**
- `Docs/Tasks/x2-library-first-interaction.md`：用户实测「进入 App Library 后必须**轻点一下或划一下**才能交互，首次点击/滚动像被『激活』消耗掉」。候选根因清单含：Library 非 first responder/窗口焦点未落、host cell 未布局（frame=0 hitTest 落空）、scroll 轴仲裁残留吞首滚、外层 host cell 拦截首击、makeFirstResponder 未设。
- **修复 commit `f6f7f1b`**（v0.4.2 "X2 library first interaction"）三管齐下：
  1. `LauncherWindowController.swift`（现 :808 注释原文）：「启动器是覆盖式界面……否则窗口可见但非 key，macOS 会把用户首次 mouseDown 当作『激活点击』吞掉……必须先把本应用提升为前台并把窗口激活为 key——`makeKeyAndOrderFront` 在未激活应用下不会真正置 key，必须先 `NSApp.activate(ignoringOtherApps: true)`」。
  2. `PausableLibraryScrollView.resetGestureState()`：进 surface 清 arbiter.end / momentumRoute=.undecided / pendingBeganEvent=nil，防旧锁定吞首滚。
  3. host cell 挂载后立即 `needsLayout + layoutSubtreeIfNeeded()` 落定布局，防首击 hitTest 命中零 frame 卡。
- `LibraryInteractionProbe.swift`（`--libraryinteracttrace`）：真实 `window.sendEvent` 路径断言「修复前首击被窗口激活吞掉（detail=0），修复后立即生效」；无头环境 key=0 时首击必然被吞（探针只报诊断）。`LibraryBlankTraceProbe.swift:509-511`：「`window.sendEvent` 会把『激活点击』吞掉（只有 acceptsFirstMouse 的控件才收到事件）」。
- `v1-blank-click-fix`（Tasks + BlankTraceProbe）：空白区 hitTest 返回 **NSClipView**，clip view 吞掉点击 → 空白不隐藏；修复前空白点击归属 = hitTest 目标错误，属同族问题。
- LaunchBetter 卡片打开 = 纯 `mouseDown/mouseUp` 转发（AppLibraryCardCell 根视图→cell→onLaunch），**无** NSClickGestureRecognizer；mouseUp 位移 >6pt 不转发。`LauncherWindow`：borderless fullSizeContentView NSWindow，canBecomeKey/Main=true，`showOnScreen` 里 makeKeyAndOrderFront（激活在窗口控制器 show() 内先行）。

## ② 点击机制对照表（两项目 vs PagingPrototype）

| 维度 | Buho（真实+复刻） | LaunchBetter | PagingPrototype |
|---|---|---|---|
| 窗口 | 非激活 NSPanel 浮层；canBecomeKey=true | 无边框 NSWindow；canBecomeKey/Main=true | `QuitOnBlankClickWindow: NSWindow`（AppDelegate.swift:1096）|
| 窗口层事件 | **sendEvent 手动路由**：hitTest→记 lastMouseDownView→直接发 mouseDown/Up/Dragged（按 type，非 subtype）| 默认 NSWindow 派发；`window.sendEvent`（probe 实证）会吞激活点击 | sendEvent 手动 hitTest **仅分类**空白 vs cell；cell 命中→`super.sendEvent` 靠 AppKit 内部路由；空白→drag-cancel/folder/exit-search/terminate 分支 |
| 点开应用链路 | 视图 `mouseUp:` 上溯容器闭包（item mouseDown 仅弹菜单/记录）| cell 根视图 mouseDown/mouseUp 转发→onLaunch | AppGridCellView.mouseDown→DragUISessionCoordinator→onCellClick→launch；+ AppLaunchController NSClickGestureRecognizer 双通路 |
| 激活顺序 | orderFrontRegardless→makeKey（激活隐含）| **NSApp.activate 在先，再 makeKeyAndOrderFront**（X2 教训）| makeKeyAndOrderFront（:276）→ activate（:281）**顺序反了**；+0.3s 全屏 toggle 再扰动 key 态 |
| subtype 3 处理 | 无显式处理；type 判定使其天然兼容 | 无显式处理 | census 判 subtype≠0 为「非正常事件」（仅观测，零行为）；投递路径对 subtype 无分支 |
| 吞点史 | — | **X2 激活吞首击**（已修）、clip view 吞空白（已修）| s15 overlay 静默 return、page view 转发、blank/drag 分支吞点（wav 取证中）|

## ③ 两目录「点击/轻点失灵」已解决案例（根因与修法）

1. **X2 首击被激活吞掉（LaunchBetter，最直接对照）**：根因 = 覆盖式启动器唤起时应用未激活/窗口非 key，macOS 将首次 mouseDown 当作激活点击消费，不投递视图（仅 acceptsFirstMouse 控件收事件）。修法 = `NSApp.activate(ignoringOtherApps:true)` 先于 `makeKeyAndOrderFront` + 清手势残留 + host 立即布局。验收探针 `--libraryinteracttrace` 走真实 sendEvent 路径断言首击即达。
2. **空白不隐藏（LaunchBetter v1）**：根因 = 文档外空白 hitTest 命中 NSClipView（NSScrollView 不拦截），clip 吞点。修法 = 命中识别下沉/分类，空白归事件所有者处理。
3. **Buho 拖拽出界丢事件（逆向结论）**：修法 = sendEvent 手动路由 lastMouseDownView（同一家族：窗口层接管投递保证确定性）。

## ④ 本缺陷最可能机制假设（基于两目录材料）

**主假设（激活吞点，强烈支持）**：subtype=3 轻点事件到达窗口层时是**真 leftMouseDown**，走同一 NSWindow 内部派发；若窗口非 key → `super.sendEvent` 内部把点击消费为激活而不投递视图 —— 与 LaunchBetter `LibraryBlankTraceProbe.swift:509`「激活点击吞掉」实证完全同构。用户观察到的「轻点失灵、实体按压可开」极可能是**时序混淆**：每次唤起后首个交互（用户习惯轻点）被吞，第二击（可能换成实体按）才生效 → 表现为「tap 无效、click 有效」。PP 侧支持证据：(a) :281 的 activate 在 makeKeyAndOrderFront **之后**，违反 X2 修复教训；(b) :0.3s 全屏 toggle 在激活之后再扰动 key 态（s8e census 显示 toggle 后 key 从未被观测——正是事件非 key 态被吞的形态）；(c) 全树 `sendEvent` 对 cell 命中只放行 super，无任何兜底手动投递 = 与 Buho 的根本差异。

**次假设（内部投递目标失配）**：`deliveryProbeInternalHitTestAbsent`（AppKit 未咨询视图树）—— 若坐实，事件被窗口内部以缓存/基坐标失配方式吞掉，同样会优先表现为轻点（合成事件时间戳/坐标语义与实体点击略有差异）；需结合 wave 取证分布定夺。

**三假设（吞点视图）**：hitTest 命中静默 return 或零 frame 视图（PP s15 overlay / LB clip view / X2 host 未布局），两目录三案例同族，但 PP 已布 s14/s15/s16 census 排查。

## ⑤ 未覆盖项

- 两目录均无 NSTouch/触摸 API 先例，故「AppKit 对 subtype=3 特殊处理」无法从材料直接证实/证伪（仅知 Buho type 判定兼容、LB 从未遇到 tap 独吞）。
- Buho 原版窗口是否在 sendEvent 之前有激活/置 key 分支（反汇编仅见 type 分派）未细读；复刻版无 sendEvent。
- PP 侧 `--libraryinteracttrace` 式真实 sendEvent 首击探针尚未存在（wave 内 ClickCensus 仅计数，无「零前置输入首击直达 cell」断言）。
- 用户「实体按压 subtype=0 可打开」的实测记录文件未在两目录（属 PP 侧），其 key 态时序未取证。

*—— 诊断 Worker（触摸/轻点维度），2026-09-03*
