# T-worker-b-togglebtn — 全屏 ↔ 窗口切换按钮 + 快捷键（Ctrl+Cmd+F）

**Worker**: B/D 同人（PagingPrototypeApp 作者）
**来源**: t20 遗漏补充项（用户原话："在这个软件里面，你应该给一个就是全屏和窗口切换的一个按钮，
按一下就可以切换，这样方便我来回测。"）
**日期**: 2026-08-28
**Scope**: `Sources/PagingPrototypeApp/`（AppDelegate 全屏切换 UI）、`Sources/PagingCore/PagingParameters.swift`（回滚，见 Deviations ①）、`Tests/`（回滚）、`Workflow/results/T-worker-b-togglebtn.md`
**Forbidden 遵守**: 未触碰 Package.swift / Docs / PROVENANCE / Workflow（结果文件除外）/ PagingCore（回滚除外，由本任务指示）/ PagingTelemetry / PagingUI（按钮在 App 层 titlebar accessory，无需碰 Surface——实现最稳、不遮挡分页区域）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（重申）

## 实现（AppDelegate 层，与 --fullscreen CLI 共存）

1. **切换按钮**：`NSTitlebarAccessoryViewController`（.trailing）内 `NSButton`（texturedRounded，
   标题 "全屏"；toolTip 提示快捷键）。点击 → `toggleFullScreenAction` → `window.toggleFullScreen(nil)`。
   动态标题：`windowDidEnterFullScreen` → "退出全屏" / `windowDidExitFullScreen` → "全屏"。
   全屏下标题栏隐藏 → 按钮不可见（设计如此），退出用快捷键。
2. **快捷键**：View 菜单"切换全屏"，keyEquivalent "f" + [.command, .control] = **Ctrl+Cmd+F**
   （macOS 惯例）。按钮与菜单项共用同一 `toggleFullScreenAction`。建立最小 mainMenu
   （App 菜单 Quit + View 菜单——keyEquivalent 需 mainMenu 挂载）。
3. **CLI `--fullscreen` 保留**（启动即全屏；t20 的延迟 0.3s toggle + .fullScreenPrimary 实现保留，
   本任务冒烟同时验证了全屏退出方向：快捷键 S2/S4 两次退出稳定，无 t20 同步 toggle 启动坑）。

## 冒烟（pid 过滤 + AX 真实按钮按下 + 真实键盘事件）

> 前置说明：第一轮冒烟被 Main 的 phys-auto-14 实例（同一 owner 名）污染——CGWindowList 查询
> 返回了 Main 的全屏窗口。重跑改为 **按 pid 过滤**（kCGWindowOwnerPID == 本冒烟实例 pid）。

| 阶段 | 触发 | CGWindowList bounds（本实例 pid） |
|---|---|---|
| S0 | 启动（无 --fullscreen） | (235,64) **1000×732**（窗口形态） |
| S1 | **AX 真实按钮按下**（AXIsProcessTrusted=true；AX 树中找到 kAXButton 标题"全屏"→ AXPress） | (0,33) **1470×923**（**全屏**：宽=屏幕 1470；高=956−33 菜单栏） |
| S2 | Ctrl+Cmd+F（CGEvent postToPid 真实键盘事件） | (235,64) **1000×732**（退出全屏，稳定） |
| S3 | Ctrl+Cmd+F | (0,33) **1470×923**（再进全屏） |
| S4 | Ctrl+Cmd+F | (235,64) **1000×732**（再退） |
| S5 | Ctrl+Cmd+F | (0,33) **1470×923**（第 3 轮进入） |

- **按钮路径**：S0→S1（AXPress 真实触发按钮 action）。
- **快捷键路径**：S2–S5 两个完整往返（退出→进入→退出→进入），**无闪退、窗口不丢**（每阶段
  bounds 均可查、进程存活）。全屏退出方向实测稳定（t20 任务点 1 的要求）。
- **全屏下按钮**：titlebar 隐藏 → 按钮不在 AX 树（设计如此；退出用快捷键）。

## 验证（命令 + 退出码）

| 命令 | 结果 |
|---|---|
| `swift test`（全量） | **180 tests, 0 failures**，exit 0 |
| `swift build`（debug + release） | exit 0（0 warning） |
| 冒烟（上表） | 按钮/快捷键切换 1470×923 ↔ 1000×732 数字记录，≥2 轮无闪退 |

## Changed Files（本任务净效果）

- `Sources/PagingPrototypeApp/AppDelegate.swift` — 切换按钮 + 菜单 + toggleFullScreenAction +
  动态标题（t20 补充随本任务交付并验证；无进一步改动）
- `Sources/PagingCore/PagingParameters.swift` — **回滚** momentumGlideFrames 默认 1 → nil
  （见 Deviations ①；与 t19 基线一致）
- `Sources/PagingPrototypeApp/AppArguments.swift` — help 文本回滚（默认跟随完整系统流）
- `Tests/PagingCoreTests/PagingCoreTests.swift` — 移除 testMomentumGlideDefaultIsOne；nil 测试恢复默认参数形式
- `Tests/PagingUITests/AppParametersTests.swift` / `AppArgumentsTests.swift` — 断言回滚（nil）

## Deviations

1. **t20 补充的 glide 默认改 1 按本任务指示回滚为 nil**（"惯性 3→1 帧不需要代码改动：走 CLI
   （--momentum-glide-frames 1），默认 nil 保持。本任务不含 glide 默认改动"）。当前代码状态：
   默认 nil（跟随完整系统流），CLI `--momentum-glide-frames 1` 用于用户复测。
2. 按钮验证用 **AXPress**（真实按钮元素激活）而非系统鼠标点击：CGEventPostToPid 的鼠标事件
   不经窗口 hit-test，无法路由到按钮；AX 路径是真实按钮 action 触发（S0→S1 全屏生效为证）。
3. 冒烟第一轮被 Main 的 phys-auto-14 实例干扰（同 owner 名）→ 按 pid 过滤重跑；Main 实例
   （pid 5545）全程未动，留给用户复测。
4. 全屏下按钮不可见（标题栏隐藏）——设计如此；退出方向由快捷键承担（同一 action，实测稳定）。

## Memory Candidates

- CGWindowList 查询必须按 pid 过滤：多实例（Main 的复测窗口 + 冒烟实例）同 owner 名时，
  owner 过滤会读到错误实例的窗口。
- CGEventPostToPid 键盘事件可直达目标 app（不经前台分发），鼠标事件不经 hit-test 不可路由——
  按钮类控件验证用 AXPress（AXIsProcessTrusted=true 时可用）。
- 全屏 Space 中 titlebar 附件按钮从 AX 树消失（titlebar 隐藏）——退出路径由快捷键/同一 action 承担。
