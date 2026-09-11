# T-1G-B — Launcher window / resident lifecycle（Worker 结果）

- **Task**: T-1G-B
- **Date**: 2026-09-10
- **Status**: COMPLETED（测试/构建全绿；未自证 Reviewer PASS）
- **Decision input**: `Workflow/decisions/2026-09-10-phase1g-continuation.md` → Option B + `PROCEED_WITH_DEFERRED_GATES`

## Objective

Lock ADR-011 Q3 to screen-covering borderless panel; implement `LauncherWindowController` executing coordinator effects; add lifecycle tests; minimal AppDelegate host seam (remove delayed `toggleFullScreen` anti-pattern). Do **not** fully rewire multi-entry activation (T-1G-E).

## Changes

| 文件 | 类型 | 说明 |
|---|---|---|
| `Docs/ADR-011-LAUNCHER-PRESENTATION-LIFECYCLE.md` | 更新 | Q3 **ACCEPTED Option B**；§3.3 全维度对照表填入 spike/生产路径证据；解除 `WINDOW_ARCHITECTURE_DECISION_REQUIRED`；状态改为 ACCEPTED（Q3） |
| `Sources/PagingPrototypeApp/LauncherWindowController.swift` | 新增 | 持有并暴露 `LauncherPresentationCoordinator`；`attach`/`ensureWindow`；`apply` present/dismiss/suspend/terminate/teardown；ScreenID→frame + 确定性 fallback；RM 时长→0 仍 `completeTransition`；requestID 动画守卫；first-responder 缝 |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | 最小修改 | 去掉 `asyncAfter(0.3)+toggleFullScreen+.fullScreenPrimary`；`attach` + `show(.initialLaunch)`；菜单改为显示/隐藏；**保留** blank-click → terminate（TODO T-1G-E） |
| `Tests/PagingUITests/LauncherWindowControllerTests.swift` | 新增 | 13 项生命周期验收 |
| `Workflow/results/T-1G-B.md` | 新增 | 本结果 |

未改：Package.swift、AppLaunchController.swift、冻结树、StatusItem/Shortcut/HotCorner、四指接线、blank→hide 生产行为。

### AppDelegate 行为变更（文档化）

- **之前**：窗口 `center` + `makeKeyAndOrderFront` 后延迟 0.3s `toggleFullScreen`，`collectionBehavior.insert(.fullScreenPrimary)` → 独立 fullscreen Space。
- **现在**：`LauncherWindowController.attach` 将窗口转为 borderless screen-covering panel（`NSScreen` frame / ScreenID index），经 coordinator `show(.initialLaunch)` present；无硬编码延迟、无 native fullscreen Space。
- **未改（留给 E）**：`terminateOnBackgroundClick` 仍 `NSApp.terminate`；`applicationShouldTerminateAfterLastWindowClosed == true`；无 status/shortcut/hot-corner/four-finger → coordinator 接线。

## Verification

### Filtered suites（任务要求）

```
$ swift test --filter 'LauncherWindowControllerTests|LauncherPresentationCoordinatorTests'
Test Suite 'LauncherPresentationCoordinatorTests' passed
	 Executed 24 tests, with 0 failures
Test Suite 'LauncherWindowControllerTests' passed
	 Executed 13 tests, with 0 failures
Executed 37 tests, with 0 failures
exit_code=0
```

### Full suite

```
$ swift test
Executed 1425 tests, with 0 failures (0 unexpected)
exit_code=0
```

（相对历史 1412：+13 = 本任务新套件。）

### Builds

```
$ swift build            → exit 0
$ swift build -c release → exit 0
```

### Acceptance map

| 验收项 | 结果 | 证据 |
|---|---|---|
| ADR-011 Q3 ACCEPTED Option B + 对照表 | **PASS** | ADR 更新；决策文件交叉引用 |
| `LauncherWindowController` 存在且可被 E host | **PASS** | 新文件 + AppDelegate attach 缝 |
| present→visible complete | **PASS** | `testPresentBecomesVisibleAndCoversTargetFrame` |
| dismiss→hidden complete（不销毁） | **PASS** | `testDismissHidesWithoutDestroyingWindow` |
| stale `completeTransition` no-op | **PASS** | `testStaleCompleteTransitionIsNoOp` + interrupt 测试 |
| show while visible 幂等 | **PASS** | `testShowWhileVisibleIsIdempotentViaController` |
| teardown once | **PASS** | `testTeardownOnceClearsWindow` / `testQuitThenTerminateTeardownOnce` |
| Reduce Motion 仍 complete | **PASS** | `testReduceMotionPresentAndDismissStillComplete` |
| screen fallback 确定性 | **PASS** | `testScreenFallbackIsDeterministicWhenIndexMissing` |
| executed > 0 | **PASS** | 13 + 24 = 37（全量 1425） |
| 无物理门宣称 PASS | **PASS** | B10/B11 仍 PHYSICAL_PENDING |

## ADR update summary

- Q3 从「待定 / WINDOW_ARCHITECTURE_DECISION_REQUIRED」→ **ACCEPTED Option B**。
- 对照表覆盖：快速 toggle、Space/Mission Control、多屏、key/main/FR、Dock/菜单、dismiss、可中断动画、Reduce Motion、B10 风险、公共 API。
- 硬约束保持：无私有 Space/WindowServer、无特殊私有 window level、无硬编码延迟猜状态。

## Residual for T-1G-C / D / E

### T-1G-C
- `StatusItemController` + Dock reopen → `launcher.handle(.show/.toggle/.quit, …)`
- 菜单 validation 读 `coordinator.committedVisibility`

### T-1G-D
- `GlobalShortcutRegistrar` / `HotCornerMonitor` / session observer → 同一 coordinator
- target screen：鼠标所在屏 + key/main fallback（Q9）

### T-1G-E（本任务明确未做）
- 全部入口只经 coordinator（去掉任何直接窗口路径）
- blank / ESC / app launch / window close → **hide**（驻留）
- explicit Quit / Cmd-Q / `applicationWillTerminate` → `quit` + `terminate` teardown once
- `applicationShouldTerminateAfterLastWindowClosed = false`
- four-finger `process` + `flushPendingShows`
- B10/B11 回归与物理门仍诚实挂账

## AccessDeclaration

`NO_PRIOR_EXPOSURE` — 未读取 LaunchBetter / BuhoReverseNotes / reverse dumps；未使用私有 Space/WindowServer API、全局 NSEvent monitor、CGEvent tap、Accessibility API。

## Reviewer focus

1. Option B 配置（borderless + `canJoinAllSpaces` + `fullScreenAuxiliary` + level `.normal`）是否满足硬约束。
2. requestID 动画中断是否在非 RM 路径可靠（`testInterruptPresentWithDismissCompletesOnlyNewRequest`）。
3. AppDelegate 改动是否真正「最小」且 TODO(E) 清晰；blank→terminate 是否被误改。
4. 隐私：无屏幕 UUID/名称/指针坐标/frontmost app 日志。
