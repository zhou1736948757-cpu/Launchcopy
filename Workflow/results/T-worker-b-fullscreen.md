# T-worker-b-fullscreen — 全屏支持 + 全屏基准阈值（前进 0.48 / 回退 0.42）+ 补充（切换按钮/快捷键、N=1）

**Worker**: B/D 同人（PagingPrototypeApp + PagingCore 作者）
**来源**: 物理调参第 10 轮，用户决策（原话）："那肯定是全屏为准啊……我不可能是以窗口来用的呀。"——
全屏（1470pt 宽）为调参基准（窗口 1000pt 只是测试形态，1.47× 页宽差导致页比例类参数在全屏下更"沉"）。
用户目标阈值：**前进 0.48、回退 0.42**。
**日期**: 2026-08-28
**Scope**: `Sources/PagingPrototypeApp/`（AppArguments + AppDelegate）、`Sources/PagingCore/PagingParameters.swift`、`Tests/PagingCoreTests/`、`Tests/PagingUITests/AppArgumentsTests.swift`、`Workflow/results/T-worker-b-fullscreen.md`
**未触碰**: Package.swift / Docs / PROVENANCE / Workflow（结果文件除外）/ PagingUI / PagingTelemetry
**AccessDeclaration: NO_PRIOR_EXPOSURE**（重申）

## A. 全屏启动支持（PagingPrototypeApp）

1. CLI `--fullscreen`（布尔可选，无值；缺省 false = 窗口形态不变）。
2. AppDelegate 实现（等价可靠形式 + 理由）：`window.collectionBehavior.insert(.fullScreenPrimary)` +
   **makeKeyAndOrderFront + activate 之后延迟 0.3s 再 `toggleFullScreen(nil)`**（asyncAfter 等窗口在
   window server 首帧就位）。理由（实测证据）：同步 toggle（窗口刚 order front 立即调用）在本环境
   约 5–10s 后应用被终止（退出码 0——窗口在全屏过渡中被关，触发
   `applicationShouldTerminateAfterLastWindowClosed`）；延迟一拍后稳定存活。
3. `--help` 补行 ✓（`swift run -c release ... --help | grep fullscreen` 命中）。
4. 冒烟诊断：仅 `--fullscreen` 时 2.5s 后打印 `paging-fullscreen: styleMask.fullScreen=<bool> frame=... screen=...`
   （fflush 冲刷——stdout 重定向到文件为全缓冲）。

### fs-smoke 冒烟数字（CGWindowList + 应用内双证据）

| 项 | 值 |
|---|---|
| 屏幕 frame | **(0,0) 1470×956**（与任务预期一致） |
| visibleFrame | (0,70) 1470×853 |
| 应用内（v4，延迟 toggle） | `styleMask.fullScreen=true` **frame=(0,0) 1470×923** |
| CGWindowList（v1 同步 toggle、全屏 Space 活动时） | **(0,33) 1470×923**——与应用内 frame 一致 |
| CGWindowList（非活动 Space 视角） | 全屏窗口以每 Space 裁剪表示：4× (0,0) 1470×33 条 + 旧空间表示 (235,63) 1000×732（同 pid 5 个 window number） |
| 结论 | **真实全屏 Space**（styleMask .fullScreen ✓）；宽 = 屏幕宽 1470 精确；高 = 956−33（本环境菜单栏 33pt 不自动隐藏——应用非前台；用户交互会话中活动全屏 Space 下菜单栏自动隐藏 → 1470×956） |

## B. 全屏基准阈值（PagingCore）

1. `displacementThreshold` 默认 **0.5 → 0.48**（注释：全屏基准，第 10 轮用户决策）。
2. `retreatDisplacementFactor` 默认 **0.9 → 0.875**（回退 = 0.48×0.875 = **0.42**；注释同步）。
3. 判定逻辑不变（PageTargetPolicy：direction == -1 时两处位移阈值 × 系数；速度强制路径不变）。

## 测试（+1 net；179 → 180）

| 测试 | 断言 |
|---|---|
| `testFullscreenBaselineThresholdBoundaries`（新，替代 t19 两测试） | velocityContribution=0 隔离：前进 0.47→bounce / 0.48→advance；回退 0.41→bounce / 0.421→retreat |
| `testFullscreenBaselineDefaultPathAsymmetry`（新） | 默认参数真实混合路径：回退 0.421 @200px/s→retreat（位移分支）；前进 0.47 @16.7px/s→blended 0.4763<0.48→bounce；回退 0.41→blended 0.4163<0.42→bounce |
| `testRetreatVelocityForcedPathUnaffected`（保持） | 857px/s 位移 0.3：回退→retreat、前进→advance（速度强制不变） |
| `testFullscreenFlagParsed`（新，AppArgumentsTests） | `--fullscreen` 解析 true；缺省 false；与其他 flag 组合 |
| 既有：小位移回弹/0.6 翻页/高速小位移/首末越界/RM/glide/momentum/边界阈值 | 全部保持通过 |

### 浮点边缘（记录）

合成 420px/1000px 时 `1.0+(−0.42)` 舍入后 ratio = 0.41999999999999993 < 0.42（阈值 0.48×0.875 恰等于
0.42 字面量）→ "回退 0.42→retreat" 的谓词断言用 −421px（0.421）保证 ≥；谓词语义"ratio ≥ 0.42 翻页"
不受影响（这是合成页宽的舍入伪影，非产品缺陷——真实 1470pt 页宽下同样按 ≥ 谓词判定）。

## Verification（命令 + 退出码）

| 命令 | 结果 |
|---|---|
| `swift build`（debug + release） | exit 0（0 warning） |
| `swift test`（全量） | **180 tests, 0 failures**（179 → +1 net），exit 0 |
| `swift run -c release PagingPrototypeApp --help \| grep fullscreen` | 命中（--fullscreen 行） |
| 冒烟 `swift run -c release PagingPrototypeApp --page-count 5 --items-per-page 35 --fullscreen --paging-telemetry --run-id fs-smoke4` | 全屏 Space 生效：styleMask.fullScreen=true、frame (0,0) 1470×923、屏幕 1470×956（数字见上表）；完成后 kill |

## Changed Files

- `Sources/PagingPrototypeApp/AppArguments.swift`（+`fullscreen` 选项/解析/帮助/头注释）
- `Sources/PagingPrototypeApp/AppDelegate.swift`（延迟 toggle + .fullScreenPrimary + 冒烟诊断 print）
- `Sources/PagingCore/PagingParameters.swift`（0.48 / 0.875 + 注释）
- `Sources/PagingCore/PageTargetPolicy.swift`（注释同步 0.875 → 0.42）
- `Tests/PagingCoreTests/PagingCoreTests.swift`（2 替代 + 更新）
- `Tests/PagingUITests/AppArgumentsTests.swift`（+1）
- `Workflow/results/T-worker-b-fullscreen.md`（本文件）

## Deviations

1. 全屏 bounds 实测 1470×923 而非 1470×956：宽精确 = 屏幕宽；高 = 956−33（本环境菜单栏不自动隐藏，
   应用非前台时）。应用内 frame 与 CGWindowList（Space 活动时）双证据一致；用户交互会话中活动全屏
   Space 下菜单栏自动隐藏 → 1470×956。
2. toggle 延迟 0.3s（asyncAfter）为等价可靠实现（任务允许"或等价可靠实现写理由"）：同步 toggle 实测
   导致应用被终止（退出码 0）。
3. "回退 0.42→retreat" 断言用 −421px（合成 420px 的 1-ulp 舍入边缘，见上）。
4. Docs 参数表行回填留 Main。

## 补充（用户追加反馈，并入本波）

### 1. 全屏 ↔ 窗口切换按钮 + 快捷键

- **按钮**：窗口标题栏 trailing 附件（`NSTitlebarAccessoryViewController`，texturedRounded 按钮
  "全屏"/"退出全屏"动态标题，windowDidEnter/ExitFullScreen 更新；toolTip 提示快捷键）。点击 →
  `toggleFullScreenAction` → `window.toggleFullScreen(nil)`。全屏下标题栏隐藏 → 按钮不可见，
  用快捷键退出（合理设计）。
- **快捷键**：View 菜单"切换全屏" `Ctrl+Cmd+F`（macOS 惯例；keyEquivalent "f" +
  [.command, .control]）。同时建最小 mainMenu（App 菜单 Quit + View 菜单——无 mainMenu 时
  keyEquivalent 无处挂载）。按钮与菜单项共用同一 action。
- CLI `--fullscreen` 保留（启动即全屏）。

### 切换冒烟（真实键盘事件，bounds 前后记录）

| 阶段 | CGWindowList bounds | 状态 |
|---|---|---|
| S0 启动（无 --fullscreen） | (235,63) **1000×732** | 窗口形态 |
| S1 投递 Ctrl+Cmd+F 后 | (0,33) **1470×923** | **全屏**（宽=屏幕 1470；高=956−33 菜单栏；Space 活动时完整上报） |
| S2 再投递 Ctrl+Cmd+F 后 | (235,63) **1000×732** | **回窗口** |

真实键盘事件（CGEvent post .cghidEventTap）→ keyEquivalent → 菜单 action → toggle 往返成功。

### 2. momentumGlideFrames 默认 3 → 1（第 11 轮用户决策："手往左滑一下，然后它要惯性滑好久才会停"）

- `PagingParameters.momentumGlideFrames: Int?` 默认 **nil → 1**（松手后最多跟随 2N=2 个惯性事件
  → 立即决策 → settle 吸住；settle 动画保持不动——用户确认 N=1 效果后再议）。
- CLI `--momentum-glide-frames` 缺省语义不变（nil = 用 PagingParameters 默认，现为 1）；
  help 文本同步（"默认 1 = 最多跟随 2 个惯性事件"）。
- nil（跟随完整系统流）仍可用（显式传参）。

### 测试（181 → 182 基线变更：本波净 +2，见下）

- `testMomentumGlideDefaultIsOne`（新）：**默认参数**下第 2 个 momentum 事件后截断 → settle；
  截断后系统流防御拒绝；commit 恰 1 次、stale 0。
- `testMomentumGlideFramesNilFollowsFullStream`（更新）：默认已变 N=1 → 显式 `glideParameters(nil)`
  保留 nil 语义覆盖（长系统流不截断）。
- `AppParametersTests.testNilKeepsCoreDefault`（更新）：缺省 glide 断言 nil → 1。
- `testMomentumGlideFramesOneTruncatesLongStream`（t16 既有，N=1 显式）与默认行为一致，保留。
- 全量 **181 tests, 0 failures**（180 → +1 net）；swift build debug+release exit 0（0 warning）。

## Changed Files（补充）

- `Sources/PagingPrototypeApp/AppDelegate.swift`（+installFullScreenToggle：titlebar 按钮 +
  View 菜单 Ctrl+Cmd+F + toggleFullScreenAction + 动态标题）
- `Sources/PagingCore/PagingParameters.swift`（momentumGlideFrames 默认 1 + 注释）
- `Sources/PagingPrototypeApp/AppArguments.swift`（help 文本同步）
- `Tests/PagingCoreTests/PagingCoreTests.swift`（+testMomentumGlideDefaultIsOne；nil 测试显式化）
- `Tests/PagingUITests/AppParametersTests.swift`（默认断言更新）

## Memory Candidates（补充）

- swift run 的 stdout 重定向到文件为全缓冲：存活进程的 print 不可见，诊断需显式 fflush(stdout)。
- 非活动全屏 Space 的窗口在 CGWindowList 中按每 Space 裁剪表示（33pt 条/旧帧）——"bounds == 屏幕
  frame" 验证要以应用内 window.frame/styleMask 为准，CGWindowList 需 Space 活动时才有完整 frame。
- 同步 toggleFullScreen（order front 后立即）在过渡窗口状态上调用可能触发窗口关闭 → 延迟一拍更稳。
- CGEvent post（.cghidEventTap）投递真实键盘事件在本环境可用（无需辅助功能权限）——快捷键冒烟
  用真实事件验证 keyEquivalent → 菜单 action → toggle 全链路。
- 菜单 keyEquivalent 需 mainMenu 存在（无菜单时快捷键无处挂载）；按钮与菜单项共用同一 action
  可让两条输入路径共用一条被验证的代码路径。
