# T-worker-d — PagingUI + App 入口（AppKit UI 层）

**Worker**: d（本 worker 亦为 PagingCore 作者；Core 于早前完成，51 测试绿）
**Scope**: `Sources/PagingUI/`、`Sources/PagingPrototypeApp/`、`Tests/PagingUITests/`
**未触碰**: `Package.swift`、`Sources/PagingCore/`、`Sources/PagingTelemetry/`、`Docs/`、`PROVENANCE/`、`Workflow/`（本结果文件除外）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（本 worker 未读取任何禁止来源：BuhoReverseNotes / LaunchBetter / Launch_Copy 治理文档）

---

## Changed Files（全部新建，共 15 个）

| 文件 | 说明 |
|---|---|
| `Sources/PagingUI/ScrollInputMapper.swift` | NSEvent → Core 归一化输入决策（方向/主导/phase/momentum/legacy/异常防御） |
| `Sources/PagingUI/PageHostView.swift` | 单页 host view（圆角卡片 + "Page N of M" 标签 + 瓦片网格；prepare/clearForReuse 绝不显示旧内容） |
| `Sources/PagingUI/PagingFrameDriver.swift` | `PagingFrameDriving` 协议 + `DisplayLinkFrameDriver`（macOS 14 `NSView.displayLink`） |
| `Sources/PagingUI/PagingSurface.swift` | 主视图：输入归一化、Core 事件桥接、live 页面承载（ADR-002 方案 1）、resize 事件驱动重布局、可访问性、lab 叠加、teardown 生命周期 |
| `Sources/PagingPrototypeApp/AppArguments.swift` | 7 项 CLI 参数解析（含 telemetry 委托）+ 帮助文本 |
| `Sources/PagingPrototypeApp/PagingTelemetryBridge.swift` | telemetry 最终接线（手势/transition/layout/prepare/teardown → TelemetryEvent） |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | NSApplication 生命周期、窗口、RM 系统偏好监听、teardown 编排 |
| `Sources/PagingPrototypeApp/AppMain.swift` | `@main` 入口：参数错误打印帮助不崩溃、`--page-hosting composited` 提示、smoke 缝 |
| `Tests/PagingUITests/TestSupport.swift` | 无头测试台（手势 helpers + settle 推进；与真实 scrollWheel 同一输入路径） |
| `Tests/PagingUITests/ScrollInputMapperTests.swift` | 12 个：方向约定/主导/phase/momentum/finish 时机/异常/legacy |
| `Tests/PagingUITests/PagingSurfaceTests.swift` | 13 个：§7.3 全部 + §3.I 内容正确性 + RM 接线 |
| `Tests/PagingUITests/PagingSurfaceInterruptionTests.swift` | 7 个：§3.F 六道门禁 + momentum 接管 |
| `Tests/PagingUITests/PagingSurfacePerformanceTests.swift` | 5 个：§7.4 边界 |
| `Tests/PagingUITests/AppArgumentsTests.swift` | 12 个：CLI 参数/默认值/错误/帮助 |
| `Tests/PagingUITests/PagingTelemetryBridgeTests.swift` | 2 个：telemetry 接线（开启写文件 / 关闭零日志） |

---

## Per-Criterion Results

### §7.3 UI 正确性 — 6/6 自动化通过
| 判据 | 测试 | 结果 |
|---|---|---|
| 页面 frame 与 page width 一致 | `testPageFramesMatchPageWidth` | PASS |
| resize 重新对齐（事件驱动单次布局） | `testResizeRealignsAllPages` / `testResizeSameWidthDoesNotRelayout` | PASS |
| 当前页可访问性描述更新（tracking/settling/commit 三态） | `testAccessibilityDescriptionUpdatesOnCommit` / `...TracksTrackingAndSettleTarget` | PASS |
| 无错误 z 序重叠（页面只挂容器下、相邻 frame 连续） | `testNoOverlappingPagesOrWrongHierarchy` / `testPageFramesNeverOverlapAcrossScroll` | PASS |
| pageCount 变化后页码全部合法（clamp + 标签刷新） | `testPageCountReductionKeepsPageNumbersValid` / `testPageCountReductionDuringSettlingIsSafe` | PASS |
| teardown 后无活跃动画驱动器（display link 停止、输入短路） | `testTeardownStopsAnimationDriver` / `testWindowCloseDuringSettleLeavesNoResidual` | PASS |

### §3.F 六道中断门禁 — 自动化通过
| 门禁 | 测试 |
|---|---|
| ① settle 未结束新手势立即接管 | `testInterruptTakeoverIsImmediateAndContinuous` |
| ② 接管点 = 当前显示位置（不跳回旧起点/目标） | 同上（`currentSession.startOffset == 接管时 offset`） |
| ③ 接管位置连续（容器 origin 无跳变） | 同上（origin 断言） |
| ④ 旧 completion 不覆盖新状态 | `testOldCompletionDoesNotOverrideNewState`（`completeSettle(旧ctx)` → false，UI 不变） |
| ⑤ 不双重 commit | `testRapidDoubleReverseSingleCommit`（6 轮正反 → commitCount 6 == 轮数） |
| ⑥ resize/pageCount/关闭期间安全 | `testResizeDuringSettlingRebasesAndRealigns` / `testPageCountReductionDuringSettlingIsSafe` / `testWindowCloseDuringSettleLeavesNoResidual` |
| 补充：momentum 滑行被接管 | `testMomentumGlideInterruptedByNewGesture` |

### §3.I 内容正确性 — 自动化通过
- 复用页面内容正确、无旧内容残留：`testPageContentNeverStale`（翻走 6 页再翻回，标签与 items 数正确）
- 页码始终在 [1, M]：全部页码断言 + `testPageFramesNeverOverlapAcrossScroll`
- prepare/reuse 语义：`PageHostView.prepare` 全量重建、`clearForReuse` 清空（UI 侧实现保证）

### §7.4 性能边界（回归预警，非物理门）
- view 数量上界：`testViewBudgetBoundedAcrossLongScroll`（30 页旅程 live ≤ 7、池 ≤ 7、满预算 7）
- 布局次数可观测：`testLayoutCountIsEventDrivenNotPerFrame`（settle 60 帧 ≤ 2 次布局）
- 长序列内存有界：`testLongSequenceMemoryGrowthBounded`（40 页旅程 live+pool ≤ 14）
- stale completion 零提交：`testStaleCompletionZeroCommitUnderRapidInterrupts`（5 次接管零新提交、仅最后 settle 提交）
- 真实触控板物理门：**NOT_RUN**（无头环境；synthetic NSEvent 不作物理门，按约定交由人工验证）

### §10 CLI（7 项参数）
- `--paging-lab` / `--page-count N` / `--items-per-page N` / `--paging-telemetry` / `--run-id <id>` / `--page-hosting live|composited` / `--reduce-motion-override on|off|system` + `--help/-h`：`AppArgumentsTests` 12 个全绿
- smoke 实测：全参数 exit 0；`--help` exit 0；`--page-count abc` → stderr 报错 + exit 2（不崩溃）

### Reduce Motion
- `--reduce-motion-override on|off|system` → AppDelegate 初始值；`NSWorkspace.accessibilityDisplayOptionsDidChangeNotification` 动态刷新
- UI 接线测试：`testReduceMotionProviderWiring`（provider 路径 + 动态切换 + RM 即刻提交）

### Telemetry 最终接线（本 worker 责任）
- `PagingTelemetryBridge`：手势 phase / transition.begin+commit / stale / interruption / layout / page prepare / frame / resize / teardown.complete + run.end
- `PagingTelemetryBridgeTests`：开启 → JSONL 含 `run.begin`/`transition.commit`/`teardown.complete`、run_id 透传；关闭 → 零日志（disabled）
- smoke 与 GUI 启动均实测写出 `/tmp/launch-copy-paging-prototype-<runID>.jsonl`

---

## Verification（含退出码）

| 步骤 | 结果 |
|---|---|
| `swift build --target PagingUI` | exit 0 |
| `swift build --target PagingPrototypeApp` | exit 0 |
| `swift test --filter PagingUITests` | 51 tests, 0 failures, exit 0 |
| `swift test`（全包） | **135 tests, 0 failures**（51 Core + 33 Telemetry + 51 UI），exit 0 |
| `PAGING_PROTOTYPE_SMOKE=1 swift run ...`（全参数） | exit 0，telemetry 文件 2 事件 |
| smoke 坏参数 `--page-count abc` | exit 2，stderr 错误（不崩溃） |
| GUI 真实启动（`swift run PagingPrototypeApp --page-count 5 --paging-telemetry --run-id gui-smoke-01`） | 进程存活 6s 后人工终止；telemetry 写出 `run.begin`（run_id 正确） |
| GUI 交互（触控板手势/动画视觉） | **NOT_RUN**（无头环境；物理门留人工） |

---

## Deviations

1. **finishGesture UI 调用时机（继承 Worker B 偏差 #1）**：`.ended` 后不在 ended 事件内调用 finishGesture（否则 momentum fling 速度丢失）；由下一事件（无 momentumPhase 的任意事件 / 新 `.began`）触发。UI 测试以 `finishPendingGesture` 显式验证该路径。
2. **SurfaceReference 强捕获**：Core events 闭包经 box 间接转发（init 前不可捕获 self）；box 必须被闭包**强捕获**（box 内 surface 弱引用，无循环）。弱捕获曾致 Core→UI 事件静默丢失（§7.3 可访问性/容器跟随测试即时暴露并修复）。
3. **relayoutPages 重对齐全部 live host**：resize 后既有页面 frame 同样按新 pageWidth 刷新（不只新增页）；事件驱动调用，成本 O(live) 非每帧。
4. **setPageCount 刷新既有 live 页面**：页码标签 "Page N of M" 的 M 变化时重新 prepare。
5. **测试助手符号约定**：helpers 的 `deltaX` = 手指意图位移（自然滚动下实际 `scrollingDeltaX = -deltaX`）；mapper 纯函数测试直测原始映射。物理约定不变：手指左移 → 下一页；滚轮向右 → 下一页（水平滚动条类比）。
6. **视图预算观察值**：radius 3 时 center 0 → 范围 [0,3]（4 页 live）；满预算 7 页需 center ≥ 3。预算本身未改。
7. **`--page-hosting composited` 保留未实现**：AppMain 打印提示后按 live 运行（ADR-002 方案 1 先行；composited 留后续）。
8. **物理门 NOT_RUN**：GUI 启动已验证，但真实触控板手势/视觉验收无法在无头环境执行，按任务书记录 NOT_RUN 不冒认。
9. **commitCount 语义**：Core 文档即含同页回弹自然完成；性能测试以确定性序列（先离边界再接管）断言精确计数。

---

## Memory Candidates

- macOS 14 的 CADisplayLink 入口是 `NSView.displayLink(target:selector:)`；`CADisplayLink.init(target:selector:)` 在 macOS 不可用。
- `NSColor.systemGray2` 等 systemGrayN 仅 iOS；macOS 用 systemGray/systemBlue/systemIndigo/systemTeal/systemCyan/systemPurple。
- 手势速度估计以 session 内 dt（began 为基准）计算；UI 不得在 `.ended` 内 finishGesture（保留 fling 速度）。
- 布局风暴守卫：`layout()` 仅当 |bounds.width − lastLayoutWidth| > 0.5 才 setPageWidth + relayout（宽度未变零成本）。
- 测试助手 deltaX 语义 = 手指意图（非 scrollingDeltaX 原始值），防符号混淆。
- SurfaceReference 转发 box 必须强捕获（弱捕获 = 事件静默丢失的隐性故障）。
- `NSEvent.Phase` 空相位（`[]`）驱动 legacy fallback 路径（`hasPreciseScrollingDeltas` 未用；滚轮行距 ~10px 可接受）。
