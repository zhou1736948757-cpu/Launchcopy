# T-1F-B10 源码摘要（Buho 逆向维度）— BuhoReverseNotes × PagingPrototype BUG10

> **AccessDeclaration: PRIOR_EXPOSURE**（2026-09-03 主控-用户授权审阅，已记 CONTAMINATION_LOG.md）
> 只读诊断产物：不修改任何代码、不写产品文件。产出：本文件（结构化材料）＋回复（<400 词）。
> 姊妹篇：`T-1F-B10-source-digest-touch.md`（触摸/轻点维度）、`T-1F-B10-source-digest-launchbetter.md`（LaunchBetter 维度）。

## ① 本维度材料清单（全部精读）

- 逆向笔记 01–07（01-background-window 320 行 / 02-item-views 455 / 03-content-grid 492 / 04-search-group 534 / 05-appdelegate-launch 299 / 06-window-events-indicator 413 / 07-group-editor-drag-model 303）
- `DRAG_DROP_MECHANICS_EXTRACTION.md`（710 行，拖拽力学汇总）
- BuhoRebuild Swift 源码（grep 43 命中 + 精读 `LaunchpadWindow.swift` 191 行、`Views/LaunchpadItemView.swift` 266 行、`AppDelegate.swift` 116 行）

**对 BUG10 的核心结论先行**：Buho 家族是「窗口层手动接管投递」的架构 —— `LaunchpadWindow.sendEvent:` 拦截 leftMouseDown/Up/Dragged，按 `type`（与 subtype 无关）直接 `[view mouseDown:]`，命中 nil 即**静默丢弃**；外加一组**本地/全局事件监视器**（本地监视器 return nil 即吞事件，全局监视器返回值被忽略）。「NSApp 收到、零视图收到 mouseDown」在该架构下有且仅有两条机制：**① sendEvent 路由时 hitTest 返回 nil；② 本地监视器吞掉事件**。subtype=3（轻点合成）事件在此架构中与实体点击无差别（type 判定）。

## ② LaunchpadWindow.sendEvent 手动路由（06 §sendEvent，0x1000b3108→FUN_1000b2fec，L132813-132868）★ 核心

```c
switch (event.type) {
case 1 /* leftMouseDown */:
    view = [windowContentView hitTest:event.locationInWindow];
    lastMouseDownView = view;                 // ★ 记录按下命中视图
    if (view != nil) [view mouseDown:event];  // ★ nil → 静默丢弃
    return;                                   // ★ 从不调 super
case 2 /* leftMouseUp */:
    if (lastMouseDownView != nil) [lastMouseDownView mouseUp:event];
    lastMouseDownView = nil;
    return;
case 6 /* leftMouseDragged */:
    if (lastMouseDownView != nil) [lastMouseDownView mouseDragged:event];
    return;
default: [super sendEvent:event]; }
```

- 特征：(a) 左键三态**绕过 NSWindow 内部派发** → 对「激活点击被吞」天然免疫；(b) 判定只看 `event.type`，**无 subtype 分支** → 轻点（subtype=3）到达 sendEvent 时按 leftMouseDown 照常投递；(c) `hitTest` 根 = `windowContentView`，nil 时事件在此层蒸发 —— 这是 BUG10 症状的**结构级复制点**。
- `lastMouseDownView` ivar：拖拽出界不丢事件；窗口自身不处理左键，空白点击沿响应链上浮到窗口 `mouseUp:` → `FUN_1000b6478(8)` 隐藏（06 §mouseUp:，0x1000b6fb4；条件反编译为 nil||!isVisible，语义存疑，未确认项 ①）。

## ③ hitTest 门控清单（可能让路由命中 nil —— BUG10 候选断点 B1）

| 视图 | hitTest 门控 | 证据 |
|---|---|---|
| LaunchpadItemView.hitTest（0x1000a0894） | **isHidden / alphaValue≤0 → nil；!isSelected → nil**；否则 super | 02 §1.6（精确条件标注未确认） |
| LaunchpadGroupView.hitTest | **仅 isEditing 时响应，否则 nil（点击穿透）** | 02 §GroupView |
| ContainerView.hitTest（0x1000657c0） | isEnabled==1 → super，否则 **nil（穿透）** | 07 §ContainerView |
| GroupNameEditor.hitTest（0x100065f78） | currentEditor==nil && 点在 frame 内 → self；否则 super | 07 |
| LaunchpadPageIndicatorItem.hitTest（0x1000a60e4） | frame 内缩矩形 containsPoint，否则 nil | 06 |
| BuhoRebuild LaunchpadItemView.swift:197-201 | **仅 iconRect 命中 → self，否则 nil**（无 isSelected 门！） | 源码 |

- 关键对比：真实 Buho 二进制 item 命中 = **选中态门控**（isSelected==false 时点击对 item 无效）；BuhoRebuild 复刻版**主动删掉**了 isSelected 门（改用 iconRect 收紧）。若 PagingPrototype 保留选中态门而选中状态未同步，轻点将全员落空（键盘导航驱动 selection，03 §PageView ff70 selectedIndex）。重建版「收紧命中区不收紧门控」是家族内已知的正确修法示例。

## ④ open 发生在 mouseUp（不是 mouseDown）—— 时序契约

- **item `mouseDown:`（0x1000a0a2c）只做**：记录 startX/Y、dragChecker.isMouseDown=false、沿 superview 链找 ContentView → `beginDrag(item)`、`setAlphaValue(0.9)`（02 §1.7）。
- **item `mouseUp:`（0x1000a0bc0）才 open**：`openMethod="mouse"` → `vtable+0x138 open(method:)` 启动应用（拖过 6pt 阈值 → 不触发）；`openMethod="keyboard"` 复位。BuhoRebuild LaunchpadItemView.swift:234-243 同构：`onClick?()` 仅在未拖拽的 mouseUp 触发。
- open 链（03 §FUN_100063560）：searchResultView 未隐藏 → 其 selectedItemView；否则 groupItemView 分支；否则 pagerView.selectedPageView.selectedItemView → vtable+0x138。键盘：ContentView.keyDown 0x24(Return) → 同链；Esc → cancelOperation → 隐藏（03）。
- **推论**：即便 mouseDown 投递成功，若 mouseUp 丢失（lastMouseDownView 被清 / 监视器吞 Up），Buho 模型下"点击打开"同样不触发 —— 症状「tap 无效」的另一半结构。

## ⑤ 事件监视器（06 §FUN_1000b4860 惰性安装，windowWillClose 全拆）—— BUG10 候选断点 B2

1. **本地监视器 mask=2(leftMouseDown)** → FUN_1000b7424：`w=event.window`；`w==nil` → **视为外部点击 → hide(0) 但仍 return event**（不吞）；w==self / NSPanel / sheetParent 是 NSPanel / 其他 LaunchpadWindow → return event 放行；否则 hide(0)。**恒 return event（永远放行）**。
2. **全局监视器 mask=0x46(leftMouseDown|leftMouseUp|otherMouseUp)** → FUN_1000b50b8：`event.window != nil` → return 0（交本地）；点在 self.frame 内 → FUN_1000e3674()（语义未确认，未确认项 ②）分两路（可见则放行 / 记录 `closeByDockMouseUpTimestamp` + 拖拽标志）；frame 外 → hide(7)。**注意：全局监视器返回值被 AppKit 忽略（只能观察不能吞）**。
3. 热角：本地+全局 mouseMoved 监视器；AppDelegate keyDown 本地监视器（BuhoRebuild AppDelegate.swift:87，仅热键 return nil）。

**★ 移植陷阱**：Buho 的「外部点击处理」分本地（可吞，但恒放行）与全局（不可吞）两层；且本地监视器对 `event.window==nil`（合成事件常见窗口属性缺失）走"外部 → hide 但放行"。任何把全局逻辑抄成本地监视器、或对 nil-window 分支 `return nil` 的移植，都会在 **NSApp 层吞掉轻点** —— 与 BUG10「NSApp 接收但从不投递」的取证描述精确吻合。Buho 全局监视器对 `event.window==nil` 的事件（合成 tap 的形态）会走 "点在 frame 内 → FUN_1000e3674" 路径，语义未还原（未确认项 ②），存在对合成事件区分处理的空间。

## ⑥ BuhoRebuild 复刻版差异（「干净移植」基线，供 PP 对照）

- **未重写 sendEvent**（LaunchpadWindow.swift:4 仅注释提及）；窗口 = borderless **nonactivating NSPanel**，canBecomeKey=true，show 序 = `orderFrontRegardless()` → `makeKey()`（**无 NSApp.activate**——但手动路由缺位时这正是不吞点的唯一依赖）。
- item hitTest 收紧为 iconRect 且无选中态门；无鼠标本地/全局监视器（仅热角 mouseMoved）；无空白点击隐藏监视器（onRequestClose 闭包代偿）。
- 拖拽：DragChecker 6pt 阈值；mouseDragged 仅标记（NSDraggingSession 未实现，Integration 层代管）。
- 合成事件先例（07 §endedAtPoint FUN_10008c884 / DRAG_DROP §2.3）：拖拽结束时 `NSEvent.mouseEventWithType` 合成 mouseUp **直接** `view.mouseUp(event)` 投递 —— 家族有「合成鼠标事件 + 手动投递」的成熟做法，PP 若同样手投合成 tap，投递成败 = 完全取决于 hitTest 结果。

## ⑦ BUG10 机制假设排序（Buho 维度证据）

1. **B1（强）**：sendEvent 手动路由 + hitTest nil → 静默丢弃。Buho 家族是唯一已知「NSApp 层零投递」的 macOS 架构；其自身的选中态门控（③）与 nil-window 判定（⑤）是 nil 的两大来源。PP census 已证事件达 NSApp、零视图收到 —— 与 ②(c) 结构完全同构。
2. **B2（强）**：本地监视器吞事件（nil-window 分支 return nil / 全局逻辑误抄本地）。与 BUG10 取证「NSApp 分发层（local monitor 确认）后从不投递」逐字吻合。
3. **B3（中）**：open-on-mouseUp 契约下 Up 丢失（监视器吞 Up / lastMouseDownView 清空）→ tap 全链失效。
4. **B4（弱）**：subtype 过滤分支 —— Buho 二进制无 subtype 判定（天然兼容）；PP 若增加 subtype≠0 早退（census 之外的零行为），即自断轻点。

## ⑧ 交叉引用表（特征 → 笔记 → 行/址）

| 特征 | 位置 |
|---|---|
| sendEvent 手动路由 | 06 §sendEvent，0x1000b3108，L132813-132868 |
| 统一隐藏入口 FUN_1000b6478(reason 0-9) | 06，L134807-134887 |
| 监视器安装/拆除 | 06 §FUN_1000b4860 / windowWillClose |
| item 三态 + 6pt + open-on-mouseUp | 02 §1.7，0x1000a0a2c/0b70/0bc0 |
| item hitTest 选中态门 | 02 §1.6，0x1000a0894 |
| open 链 / keyDown Return | 03 §FUN_100063560 / §ContentView |
| 页面/选中模型（selectedIndex/isSelected） | 03 §LaunchpadPageView ff70；BuhoRebuild Pager:247、PageView.swift:198-203 |
| 拖拽结束合成 mouseUp | 07 §endedAtPoint FUN_10008c884；DRAG_DROP §2.3 |

## ⑨ 未确认项（对 BUG10 判定有影响）

1. 窗口 `mouseUp:` 隐藏条件反编译疑似翻转（06 未确认项 ①）。
2. 全局监视器 `FUN_1000e3674` 语义（06 未确认项 ②）—— 决定合成事件（window==nil）在 frame 内时走放行还是记录分支。
3. item hitTest 精确条件（02 标注未确认）：`isHidden/alpha≤0/isSelected` 三条件的组合与顺序。
4. PageView 初始选中态（03：init 后 isSelected=1）与键盘导航何时驱动 isSelected —— 决定 tap 到达时命中门开关状态。

*—— 诊断 Worker（Buho 逆向维度），2026-09-03*
