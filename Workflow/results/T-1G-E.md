# T-1G-E — AppDelegate composition root（Worker 结果）

- **Task**: T-1G-E
- **Date**: 2026-09-10
- **Status**: COMPLETED（构建/测试全绿；未自证 Reviewer PASS）
- **Decision input**: `Workflow/decisions/2026-09-10-phase1g-continuation.md` → Option B + `PROCEED_WITH_DEFERRED_GATES`
- **Prior**: T-1G-B / T-1G-C / T-1G-D

## Objective

Wire all activation entries through a single `LauncherWindowController` / presentation coordinator. Flip product semantics to resident launcher: blank/ESC/launch/close → **hide**; only Quit → **terminate**. Start Hot Corner / shortcut / four-finger from prefs. Keep B10/B11/M01–M12 physical gates deferred (do not invent PASS).

## Changed files

| 文件 | 类型 | 说明 |
|---|---|---|
| `Sources/PagingPrototypeApp/AppDelegate.swift` | EDIT | ActivationComposition 宿主；blank/ESC/launch/close→hide；Quit/willTerminate→quit+terminate+teardown；`lastWindowClosed=false`；prefs→services |
| `Sources/PagingPrototypeApp/ActivationComposition.swift` | CREATE | 可注入 fake 的组合根：shortcut/hot-corner/four-finger process+flush/session；hide≠terminate |
| `Sources/PagingPrototypeApp/LauncherResidentPolicy.swift` | CREATE | `terminateAfterLastWindowClosed = false` |
| `Sources/PagingPrototypeApp/LauncherWindowController.swift` | EDIT | `adoptCoordinator`；中断在飞动画时同步 complete（修 flake） |
| `Sources/PagingPrototypeApp/FourFingerActivationCoordinator.swift` | EDIT | `adoptPresentation`（与窗控同步单一状态机） |
| `Sources/PagingPrototypeApp/KeyboardFocusController.swift` | EDIT | `onEscapeExhausted`（title/folder/selection 耗尽 → hide） |
| `Tests/PagingUITests/LauncherIntegrationTests.swift` | CREATE | 8 项 fake 集成测试 |
| `Tests/PagingUITests/LauncherWindowControllerTests.swift` | EDIT | interrupt 用例轮询 harden |
| `Docs/PHASE1G_CHECKPOINT.md` | EDIT | T-1G-E 状态 + 物理门诚实 PENDING |
| `Workflow/stage-summaries/2026-09-08-phase1g-continuation.md` | EDIT | 波次收口 |
| `Workflow/results/T-1G-E.md` | CREATE | 本结果 |

## Untouched（硬约束）

- `Sources/PagingPrototypeApp/AppLaunchController.swift` — **未改**（仅经 `onLaunchAttempt` 接线）
- `Package.swift` — **未改**
- 冻结树（PagingCore / PagingTelemetry / PagingUI / AppCatalogCore / MacAppCatalog / AppIconPipeline / LayoutDomain/Store/DragSession）— **未改**
- 无 commit/push；无 global NSEvent monitor / CGEvent tap / Accessibility

## Composition approach（四指 ↔ presentation）

**Chosen: sync via `adoptPresentation` / `adoptCoordinator` around `process` + `flushPendingShows`.**

1. Flush 前：`fourFinger.adoptPresentation(launcher.coordinator)`
2. `process(frame)` → 入队 show tokens
3. `flushPendingShows()` → 在同一 coordinator 上产出 effects（含 requestID）
4. `launcher.adoptCoordinator(fourFinger.presentation)` → `launcher.apply(effect)` 逐条执行

生产路径**不是** external-only `handlePinchEvent`；是 **process + flush**。单一窗控权威，无第二窗路径。

## Hide vs terminate（ADR-011 Q5/Q6）

| 入口 | 行为 |
|---|---|
| Blank（folder/search/drag 优先级后） | `hide(.backgroundClick)` |
| ESC（title→folder→selection 后） | `onEscapeExhausted` → `hide(.escape)` |
| 成功 app launch | `onLaunchAttempt(.launched)` → `hide(.appLaunched)` |
| Window close | `windowShouldClose` → hide，返回 `false` |
| Status Quit / Cmd-Q / willTerminate | `quit` → `terminate` → activation teardown once → `teardownAll` |
| `applicationShouldTerminateAfterLastWindowClosed` | **false**（`LauncherResidentPolicy`） |

Hide 前 `prepareTransientCancellationForHide`：cancel drag / title / folder / search（ADR-011 Q7）。

## Prefs → services

- Load `UserDefaultsActivationPreferencesStore`（失败→内存默认）
- shortcut：仅 `globalShortcutEnabled`+spec 时 `CarbonGlobalShortcutRegistrar.register`；默认 Off
- hot corner：仅 enabled+corner 时 `HotCornerMonitor.enable`；默认 Off（零 timer）
- four-finger：`fourFingerActivationEnabled`（默认 true）→ `MultitouchSupportBackend` + coordinator `userEnabled`
- `WorkspaceSessionObserver` → hot-corner bridge + four-finger/launcher suspend/resume
- Activation policy：**保持 `.regular`**（Dock reopen；未隐藏 Dock 图标）

## Verification

### Builds

```
$ swift build
Build complete!
DEBUG_EXIT=0

$ swift build -c release
Build complete!
RELEASE_EXIT=0
```

### Filtered integration

```
$ swift test --filter LauncherIntegrationTests
Test Suite 'LauncherIntegrationTests' passed
	 Executed 8 tests, with 0 failures (0 unexpected)
exit_code=0
```

### Full suite

```
$ swift test
Test Suite 'All tests' passed
	 Executed 1468 tests, with 0 failures (0 unexpected)
exit_code=0
```

（相对 T-1G-C 的 1460：+8 = `LauncherIntegrationTests`。）

| 套件（本任务相关） | executed | passed | failed |
|---|---:|---:|---:|
| LauncherIntegrationTests | 8 | 8 | 0 |
| LauncherWindowControllerTests | 13 | 13 | 0 |
| **全量** | **1468** | **1468** | **0** |

`executed_tests == 1468 > 0` → 有效测试执行（非 INVALID_TEST_EXECUTION）。

## Acceptance map

| # | 验收项 | 结果 | 证据 |
|---|---|---|---|
| 1 | debug+release build exit 0 | **PASS** | 上方 Builds |
| 2 | full `swift test` PASS，executed 上报 | **PASS** | 1468/0 |
| 3 | Manual smoke note | **见下** | 用户稍后物理确认 |
| 4 | 物理门诚实 PENDING | **PASS** | 本节 Residual |
| 5 | 无隐私红线 | **PASS** | 无 global monitor/tap/AX；无坐标/快捷键原文日志 |

## Manual smoke（用户物理确认；Worker 不宣称 PASS）

1. `swift run PagingPrototypeApp`（或 Xcode 跑 executable）
2. 启动后应为 Option B 覆盖式 panel（非 native fullscreen Space）
3. **空白点击** → 窗口隐藏，进程仍在（菜单栏 status item / Dock 仍在）
4. Status **Show Launcher** 或 Dock 点击 → 再显示同一窗
5. **ESC**（无 title/folder/选择时）→ hide
6. 启动任一 app（成功）→ hide
7. Status **Quit** 或 Cmd-Q → 进程退出；菜单栏 item 消失
8. 若 prefs 开 hot corner / shortcut：对应入口应 show/toggle（默认 Off 时不应注册）
9. 四指（默认 prefs on + 后端 ready）：捏合应 show；**不**因 spread hide

## Residual physical gates（PENDING — 不宣称 PASS）

| Gate | Status |
|---|---|
| Phase 1F B10 real-machine A/B | **PHYSICAL_PENDING** |
| Phase 1F B11 visual acceptance | **PHYSICAL_PENDING** |
| Phase 1G M01–M12 | **PHYSICAL_PENDING**（依赖本集成后实机） |
| Energy A/B / MULTI_DISPLAY / 120Hz / SLEEP_LOCK / RAPID_RACE | **PHYSICAL_PENDING** |
| Activation Settings 真实面板 | Stub（未做） |

## Deviations / disclosures

1. 新增 `ActivationComposition.swift` + `LauncherResidentPolicy.swift`（任务允许的小 helper）。
2. 修复 T-1G-B 已知 interrupt 动画 flake：中断在飞 transition 时强制 `duration=0` 同步 complete；测试改为轮询。
3. Status item Quit：仍由 `StatusItemController` 调 `terminateApp`；AppDelegate `applicationWillTerminate` 补齐 quit+terminate+teardown。
4. `AppMain` 保持 `.regular` activation policy（文档化；未改文件——默认已满足）。

## AccessDeclaration

`NO_PRIOR_EXPOSURE` — 未读取 LaunchBetter / BuhoReverseNotes / reverse dumps；未新增私有 Space/WindowServer API、全局 NSEvent monitor、CGEvent tap、Accessibility API。四指仍仅经既有 MultitouchSupport 后端（用户已确认风险清单）。

## Memory candidates（供 Main 门控）

1. 四指组合必须 `adoptPresentation`↔`adoptCoordinator` 围绕 `process`+`flush`，否则 requestID/状态分叉。
2. 中断 NSAnimationContext 在飞动画时，新 transition 宜同步 complete（duration→0），否则 dismiss 可能卡在 `.dismissing`。
3. `applicationShouldTerminateAfterLastWindowClosed` 必须 false，否则 hide 路径仍会杀进程。

## Reviewer focus

1. 是否所有入口只经同一 launcher（无第二窗/直接 orderFront 旁路）。
2. blank/ESC/launch/close 是否真 hide；Quit 是否 teardown once。
3. 四指是否 process+flush（非仅 handlePinchEvent）。
4. 默认 shortcut/hot corner Off；fourFinger 默认 true 仅开 prefs，不等于 Ready。
5. 隐私扫描；物理门未误标 PASS。
6. `AppLaunchController.swift` / `Package.swift` / 冻结树未被改。
