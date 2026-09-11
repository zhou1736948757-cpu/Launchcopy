# T-1C-D-blankclick-repair — 单击空白背景退出不可靠

- 创建: Main, 2026-08-30
- 类型: repair（T-1C-D 变更 ⑤ 的可靠性修复）
- 关联: T-1C-D（已 PASS 的 5 项键盘/窗口 UX 变更）
- 状态: READY

## 观察到的症状（用户 verbatim）
> 单击空白处退出 app —— 就是我不知道为什么，就我最开始点了一下没有退出，点了两三下才退出，可能是我点的位置不对吧。

即：全屏下单击空白背景**首次点击经常不退出**，需连点 2–3 次才退出。目标：**空白背景任意位置单击，首次点击必须可靠退出**。

## 当前实现（Main 已定位，供 Worker 依据，非内联实现）
文件：`Sources/PagingPrototypeApp/AppDelegate.swift`
- `installBackgroundClickToQuit(on:)`（L413–417）：`NSClickGestureRecognizer(target:self, action:#selector(backgroundClick(_:)))`, `numberOfClicksRequired = 1`，`view.addGestureRecognizer(click)`（`view` = container surface）。
- `backgroundClick(_:)`（L419–437）：`view.hitTest(point)`；`hit == nil` → terminate；沿 `hit.superview` 链找 `AppGridCellView`，命中（含 cell 内 icon/label 子视图）→ return 不退出；否则 `terminateOnBackgroundClick()` → `NSApp.terminate(nil)`（L439–441）。
- 启动时序：`applicationDidFinishLaunching` 里 `window.makeKeyAndOrderFront`(L192) + `NSApp.activate(ignoringOtherApps:true)`(L199)，随后 **0.3s 延迟 `toggleFullScreen`**(L206–215)使窗口进入全屏（app 现为仅全屏，T-1C-D 变更④）。

## 可靠根因假设（Worker 需核实并取最稳方案）
1. **全屏过渡吞掉首击**：`toggleFullScreen` 异步动画期间（0.3s 延迟 + 过渡期约一秒）`NSClickGestureRecognizer` 常不触发或事件被 window server 吃掉 → 首击静默失效。
2. **`NSClickGestureRecognizer` 语义**：只在 mouseDown+mouseUp 且位移 ≤ `allowableMovement`（默认 10pt）的「被识别」点击才 fire；点击稍有抖动/位移即失败且**无任何反馈** → 用户以为没点到，连点几次才 hit 到可识别的一次。
3. 非 key/frontmost 时首击用于激活窗口，recognizer 不 fire。

## 关键约束与上下文（决定修复方向）
- **翻页不是鼠标拖拽**：翻页走 `scrollWheel`（冻结 `Sources/PagingUI/PagingSurface.swift` `scrollWheel(with:)` → `ScrollInputMapper`），**项目中没有鼠标 press-drag 翻页手势**。因此把空白点击改为「容器视图 `mouseDown(with:)` 每次实击都评估」（而非仅在被识别的 click 时）**不会破坏翻页**；Worker 仍需确保 scrollWheel 翻页、键盘导航不受影响。
- **cell 启动 recognizer 冻结不可动**：`Sources/PagingPrototypeApp/AppLaunchController.swift` L95–96 的 `NSClickGestureRecognizer` 挂在同一 surface 上负责单击 cell 启动（该文件**冻结**）。空白点击处理器必须满足：命中 `AppGridCellView`（或其 icon/label 子视图）→ **不退出**、正常启动。两个 recognizer 同挂 surface 的既有共存方式可保留，但若改 mouseDown 方案须证明与 cell 启动不互斥（点 cell 仍能启动、点空白仍退出）。
- 红线不变：不引入全局 `NSEvent` monitor、不碰 Accessibility 权限、无同步 I/O、telemetry 不记录任何 app 名/bundleID/路径/URL/图标/用户输入（本修复不涉及 telemetry）；`AppGridUI`/`PagingUI`/`PagingCore`/`MacAppCatalog`/`Package.swift`/`AppLaunchController.swift` 一律不动；不 git commit/push/tag；生产 Timer tolerance 8.333ms 不动。

## 允许改动范围
- 仅 `Sources/PagingPrototypeApp/AppDelegate.swift`（可加该文件内的私有 helper / 极小背景视图子类）与 `Tests/PagingUITests/KeyboardFocusControllerTests.swift`（或新建对应测试文件，若需测 blank-vs-cell 分类逻辑）。
- 禁止树 mtime 必须在修复前后保持不变。

## 验收（Worker 必达）
1. `swift test` ≥ 520 / 0（若新增测试则 520+N / 0）。
2. `swift build -c debug`、`swift build -c release` 均 exit 0。
3. 从代码上论证「首次单击空白必退」：每次真实 mouseDown 都会评估命中（不再依赖 may-not-fire 的点击识别），且与 cell 启动、scrollWheel 翻页、键盘导航互斥无冲突。
4. 可行时加单测（如把 blank-vs-cell 分类抽成可测 helper）；纯 UI 点击可靠性如实标注为 GUI 手工门禁。
5. 写 `Workflow/results/T-1C-D-blankclick-repair.md`：改动 diff、测试数、双构建 exit、禁止树核验、以及「为何首击现在可靠」的一页论证。

## 交付
Worker 返回 verdict（DONE/BLOCKED）+ 上述结果 → 独立 Reviewer PASS 后才允许 Main 重建 + 重开 app 供用户实测。
