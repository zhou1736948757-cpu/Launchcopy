# T-1F-B10 Source Digest — LaunchBetter 点击→启动链路与事件分发

> **AccessDeclaration: PRIOR_EXPOSURE** — 本 Worker 经 2026-09-03 主控-用户明确命令授权审阅 LaunchBetter 工程（命令要求"详细阅读 /Users/mac/Projects/LaunchBetter 目录下的工程（源代码+文档+快照）"），已记 CONTAMINATION_LOG.md。只读诊断，未修改任何代码/产品文件。

## ① 目录总览

工程为 Swift Package 分层 + 薄 App 壳：

| 层 | 路径 | 职责 |
|---|---|---|
| App 壳 | `LaunchBetterApp/` | main.swift、AppDelegate、LauncherStore（launch 唯一入口）、ActivationCoordinator、ThreeFingerDragCoordinator、DependencyContainer、Diagnostics/（22 个探针） |
| LaunchUI | `Packages/LaunchUI/Sources/LaunchUI/` | **全部视图/控制器**：LauncherWindow(.swift)、LauncherWindowController(.swift)、GridViewController(.swift)、ClickableCollectionView(.swift)、AppCellView(.swift)、FolderViewController(.swift)、AppLibraryViewController(.swift)、AppLibraryCardCell(.swift)、PageDotView(.swift)、PagingInteractionController(.swift)、PageSnapAnimator、PageCompositor/PageVisualRenderer（页快照/文件夹缩略图）、PausableLibraryScrollView(在 AppLibraryViewController.swift 内)、SettingsInteractionShield(在 LauncherWindowController.swift 内) |
| LaunchPlatform | `Packages/LaunchPlatform/Sources/LaunchPlatform/` | 发现/图标/持久化 + **MultitouchSupport.swift（私有框架原始触点）**、GestureCaptureEngine（三指拖拽）、HotCornerMonitor |
| LaunchCore | `Packages/LaunchCore/Sources/LaunchCore/` | 纯模型：PagingSpring、PagingGestureSession、PagingTargetResolver、GridGeometry、LayoutEditor 等 |

文档：`Docs/Architecture/`（2 篇）、`Docs/Tasks/`（点击相关：pa3-blank-click、v1-blank-click-fix、x2-library-first-interaction）、`Docs/aegis/work/2026-08-25-buho-launchpad-reverse/report.md`（**对可工作 Launchpad 商业应用 BuhoLaunchpad v1.7.0 的完整逆向报告**，含事件路由实锤）。

## ② 点击→启动完整链路

```
触控板轻点/鼠标左键
 └─ LauncherWindow（无边框 NSWindow, canBecomeKey/Main=true, level=.screenSaver）
     └─ GridViewController.container(NSView) → NSScrollView → ClickableCollectionView(文档视图)
         mouseDown(with:)  [ClickableCollectionView.swift:96]  记录 mouseDownPoint + receivedMouseDown
         mouseUp(with:)    [ClickableCollectionView.swift:126] 未拖动 → onClick?(point) [:141]
         └─ onClick 接线 [GridViewController.swift:391-393]
             → handleClick(at:) [GridViewController.swift:1119-1149]
                 index item 命中 .app(id) → store.launch(id) [:1134]
                 index 未命中（空白）→ onClickBlank?() → LauncherWindowController.swift:622-625 → hide()
         └─ LauncherStore.launch(_:) [LaunchBetterApp/LauncherStore.swift:446-450]
             guard NSWorkspace.shared.open(record.url) → 异步 recordLaunch（唯一启动入口，Library 共用）
```

- 文件夹面：FolderViewController.swift:282-289（自己的 ClickableCollectionView.onClick → store.launch(id) :288）。
- Library 面：LibraryCardRootView「卡根视图」捕获 mouseDown/mouseUp 序列 → 路由 .launch/.openDetail [AppLibraryCardCell.swift:620-646]；AppLibraryViewController.swift:423 消费。
- 键盘 Return：LauncherWindow.keyDown [LauncherWindow.swift:13-19] → LauncherWindowController.handleKeyDown [LauncherWindowController.swift:1603-1656] → launchFirstSearchResult() [:1650]。
- 翻页：scrollWheel [ClickableCollectionView.swift:159] → onPageScroll → GridViewController.handlePageScroll [GridViewController.swift:2115-2124] → PagingInteractionController.handleWheel。

## ③ 事件分发实现细节（逐条）

1. **无任何手势识别器**：全工程 `NSClickGestureRecognizer`/`NSTouch`/`subtype`/`event.type` 检查 **0 命中**。点击完全靠 NSView 系 `mouseDown/mouseUp(with:)` 覆写；单击判定在 mouseUp（未超 5pt 拖拽阈值即 onClick）。press feedback 仅是视觉效果（AppCellView.beginPressFeedback）。
2. **孤儿 mouseUp 防护**：`receivedMouseDown` 标志 [ClickableCollectionView.swift:90-94, 126-143]——覆盖层（Folder/Settings）在 mouseDown 后移除祖先导致 mouseUp 落到本视图时，无配对 mouseDown 的 mouseUp 一律忽略，防误触发底层 click。注释明确：AppCellView 本身**不**消费点击，只有按压反馈。
3. **窗口层**：无 sendEvent 覆写（全工程仅探针调用 `window.sendEvent` 注入合成事件）。关键窗口配置：`canBecomeKey/Main = true`（无边框默认不可 key，旧版教训 §92）[LauncherWindow.swift:6-8]；`level = .screenSaver`（盖过 Dock）。
4. **首次点击被"激活点击"吞掉**：show() 时 `NSApp.activate(ignoringOtherApps: true)` 前置 [LauncherWindowController.swift:792-799]——注释原文："macOS 会把用户的首次 mouseDown 当作'激活点击'吞掉（…首次点 App 启动/点空白隐藏失效，需再点一次；用户实测）"。探针 LibraryBlankTraceProbe.swift:507-511 亦确认：非 key 窗口/未激活应用时 "window.sendEvent 会把'激活点击'吞掉（只有 acceptsFirstMouse 的控件才收到事件）"。
5. **hitTest 覆写三处**（都是"子视图吞事件"修复）：
   - FolderCardView.hitTest [FolderViewController.swift:1131-1145]：NSVisualEffectView 会截断子视图 hitTest 下探 → 手动遍历子视图，空白兜底 self。
   - FolderTitleLabel.hitTest [FolderViewController.swift:1244-1249] + own mouseDown：**"NSTextField 的 cell 可能吞掉 mouseDown，NSPressGestureRecognizer 挂 label 上不可靠"** → 必须 self 接管命中。
   - PausableLibraryScrollView.hitTest [AppLibraryViewController.swift:959-973]：**空白区 hitTest 返回 NSClipView，NSScrollView 不拦截，clip view 吞掉点击** → hit 为 NSClipView 时返回 self 接管空白会话（v1-blank-click-fix.md 根治记录）。
6. **触控（三指拖拽）走独立通道**：MultitouchSupport.swift（私有框架 MTTouch 接触帧回调）+ GestureCaptureEngine → ThreeFingerDragCoordinator（位置取 NSEvent.mouseLocation 而非触点中心）。**与 AppKit mouseDown 投递链完全隔离**，不参与点击。
7. Settings 屏蔽层：SettingsInteractionShield + onShieldMouseDown/onShieldMouseUp 序号所有权（mouseUp 完整消费后才恢复所有权）[LauncherWindowController.swift:490-515]。
8. 探针方法论（可直接复用于 BUG10 定位）：LibraryBlankTraceProbe 用 `contentView.hitTest(窗口点)` 采样命中视图类名逐层 trace（:486-530），与 AppKit 派发链同构；LibraryInteractionProbe 用 `window.sendEvent(down/up)` 走真实激活逻辑验证首次交互（:186-189）。

## ④ 与 BUG10（mouseDown 死链）可能相关的机制

1. **"激活点击"吞事件**是唯一被本工程文档化、用户实测过的"事件到达 NSApp 层却不到 view"现象（x2-library-first-interaction.md + LauncherWindowController.swift:792 注释 + 探针注释）。症状对得上"分发层收到、视图零接收"——但该现象通常只吞**首次**事件。
2. **hitTest 链吞点**：NSClipView/NSVisualEffectView/NSTextField cell 三类子视图都被实测吞过 mouseDown；PagingPrototype 若任一层（如 PageHostView 上的模糊/材质视图、host 内的 NSTextField/滚动容器）返回了错误命中者，会呈现"全视图零接收"。需要 hitTest 逐层采样定位（复用 LaunchBetter 探针方法）。
3. **窗口非 key/非激活 + 无 acceptsFirstMouse**：无边框窗口未显式 canBecomeKey 则点击即"激活点击"。PagingPrototype 若窗口非 key，触控板轻点（tap 合成左键）序列可能整体被激活逻辑消费，与"实体按压可开"（实体按压路径可能走 force click /不同分发）的差异并存。
4. **覆盖窗口/level 竞争**：LauncherWindow 用 .screenSaver 盖一切；若 PagingPrototype 存在更高 level 的透明覆盖层，则下层窗口视图永远收不到事件（AppKit 直接投递覆盖层）。LauncherWindow 的 level+isOpaque=false+backgroundColor=clear 组合（LauncherWindow.swift:28-32）是已知安全配置。
5. **孤儿 mouseUp 防护缺失对照**：LaunchBetter 对"部分序列到达"（只到 up 不到 down）显式防御；PagingPrototype 若用 NSClickGestureRecognizer 且 AppKit 的 tap 合成事件在其内部被拆分/吞掉，识别器可能因缺 mouseDown 永久不触发——与"cell 零接收"吻合。
6. Buho 逆向报告（Docs/aegis/work/2026-08-25-buho-launchpad-reverse/report.md §1.6）：可工作的 Launchpad 用 **LaunchpadWindow.sendEvent: 自定义路由（先监听者后 super）** + 手势监听器 + item 级 mouseDown/Dragged/Up + hitTest。即"窗口级接管"是此类应用的成熟解——PagingPrototype 可在窗口层拦截 subtype=3 事件自行路由。

## ⑤ 架构对照要点

| 维度 | LaunchBetter | PagingPrototype（据任务陈述） |
|---|---|---|
| 页面载体 | **单一** NSCollectionView 文档视图（虚拟分页：PagingGridLayout 按页布 cell，PagingInteractionController+DisplayLink 结算，文档宽度锁定） | container → PagingSurface → PageHostView → AppGridPageView → cell（每页真实 NSView） |
| 点击判定 | 集合视图层 mouseDown/mouseUp 会话（cell 不消费点击，仅按压反馈） | cell 层（待确认，NSClickGestureRecognizer 不触发） |
| 手势 | 无任何 NSGestureRecognizer；纯事件覆写 | 用了 NSClickGestureRecognizer |
| 事件注入 | 探针用 window.sendEvent 真实路径 | local monitor 确认 NSApp 层收到 |
| 触摸 | 原始 MultitouchSupport 帧（三指拖拽，独立通道） | 无（tap 合成 NSEvent subtype=3 未被特殊处理） |
| 已知坑 | 激活点击吞首击；NSClipView/NSTextField cell 吞 mouseDown；孤儿 mouseUp | 未知 |

**要点**：LaunchBetter 证明"无手势识别器、纯 mouseDown/mouseUp 覆写 + 窗口显式 key/activate"在 tap 轻点下是可用链路；其文档化的三个吞事件根因（激活点击、clip view、text field cell）与两个定位工具（hitTest 逐层采样、sendEvent 注入回放）是 BUG10 最直接的参照系。
