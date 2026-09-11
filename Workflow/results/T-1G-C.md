# T-1G-C — Status Item + Dock Reopen（Worker 结果）

- **Task**: T-1G-C
- **Date**: 2026-09-10
- **Status**: COMPLETED（测试/构建全绿；未自证 Reviewer PASS）
- **Decision input**: `Workflow/decisions/2026-09-10-phase1g-continuation.md` → Option B + `PROCEED_WITH_DEFERRED_GATES`
- **Prior**: `Workflow/results/T-1G-B.md`

## Objective

Add `StatusItemController` (NSStatusBar item with Show/Hide, Activation Settings placeholder, Quit) and Dock reopen adapter so hidden→show / visible→key without a second window. Wire minimally through `LauncherWindowController` / AppDelegate.

## Changes

| 文件 | 类型 | 说明 |
|---|---|---|
| `Sources/PagingPrototypeApp/StatusItemController.swift` | 新增 | `StatusBarProviding`/`StatusItemHandle` 可注入 seam；`SystemStatusBarProvider`；`FakeStatusBarProvider`；`StatusItemController`（SF Symbol `square.grid.2x2`、Show/Hide 动态标题、Activation Settings stub、Quit）；`LauncherTargetScreenResolver`（鼠标屏→key→main→0）；`DockReopenAdapter`（hidden/suspended/dismissing→show；visible/presenting→makeKey；terminating no-op） |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | 最小修改 | `statusItemController` 宿主；`installStatusItem`（`ActivationSettings().showStatusItem` 默认 true）；`applicationShouldHandleReopen` → `DockReopenAdapter`；teardown 移除 status item；View 菜单 toggle 改用 target-screen resolver。**保留** blank-click → terminate（TODO T-1G-E） |
| `Tests/PagingUITests/StatusItemControllerTests.swift` | 新增 | 17 项：install/失败降级/teardown、菜单 validation、Show/Hide/Quit 路由、Dock reopen、target screen fallback、无 UserDefaults 污染 |
| `Workflow/results/T-1G-C.md` | 新增 | 本结果 |

未改：Package.swift、AppLaunchController、LauncherWindowController（逻辑）、HotCornerMonitor/GlobalShortcutRegistrar（并行 D）、冻结树、blank→hide、`applicationShouldTerminateAfterLastWindowClosed`。

### AppDelegate 行为变更（文档化）

- **新增**：启动后按 `ActivationSettings.showStatusItem`（默认 true）安装 status item；菜单 Show/Hide/Quit 经 `launcher.handle`；Dock reopen 经 `DockReopenAdapter`（返回 `false` 避免 AppKit 再建空白窗）。
- **未改（留给 E）**：`terminateOnBackgroundClick` 仍 `NSApp.terminate`；`applicationShouldTerminateAfterLastWindowClosed == true`；无 ActivationPreferences 运行时开关面板；无 shortcut/hot-corner/four-finger → coordinator 接线。

## Verification

### Filtered suites

```
$ swift test --filter 'StatusItemControllerTests'
Test Suite 'StatusItemControllerTests' passed
	 Executed 17 tests, with 0 failures
exit_code=0
```

```
$ swift test --filter 'StatusItemControllerTests|LauncherWindowControllerTests|LauncherPresentationCoordinatorTests'
# StatusItemControllerTests: 17 PASS
# LauncherPresentationCoordinatorTests: 24 PASS
# LauncherWindowControllerTests: 12 PASS + 1 序敏感 flake（见 Residual）
# 单独重跑 flake 用例：PASS
```

### Full suite

```
$ swift test
Executed 1460 tests, with 0 failures (0 unexpected)
exit_code=0
```

（相对 T-1G-B 的 1425：+17 StatusItem；其余增量来自并行 T-1G-D 等。）

### Builds

```
$ swift build            → exit 0
$ swift build -c release → exit 0
```

### Acceptance map

| 验收项 | 结果 | 证据 |
|---|---|---|
| Status item 独立 SF Symbol；`showStatusItem==true` 默认显示 | **PASS** | `makeIndependentSymbolImage` + `testInstallCreatesStatusItemWhenShowStatusItemTrue` |
| Menu Show/Hide / Settings stub / Quit | **PASS** | validation + performShowHide/Quit/ActivationSettings 测试 |
| validation 读 `committedVisibility`（无第二 toggle 状态） | **PASS** | `testMenuValidationReadsCommittedVisibility` |
| 创建失败不崩溃 | **PASS** | `testCreationFailureDoesNotCrash` / `testButtonConfigurationFailureRemovesItemAndDegrades` |
| Dock reopen hidden→show；visible→key；无第二窗 | **PASS** | `testDockReopenHiddenShowsSameWindow` / `testDockReopenVisibleMakesKeyWithoutSecondWindow` |
| target screen 鼠标屏 + key/main fallback | **PASS** | `LauncherTargetScreenResolver` + `testTargetScreenUsesMouseScreenThenFallbacks` |
| teardown 移除 status item | **PASS** | `testTeardownRemovesStatusItem` + AppDelegate.teardownAll |
| 无真实 UserDefaults 污染 | **PASS** | `testNoUserDefaultsPollutionFromStatusItemPath` |
| executed > 0 | **PASS** | 17（全量 1460） |
| 无物理门宣称 PASS | **PASS** | B10/B11 / M01–M12 仍 PHYSICAL_PENDING |

## Residual for T-1G-E（及已知 flake）

### T-1G-E
- 全部入口只经 coordinator（去掉任何直接窗口路径）
- blank / ESC / app launch / window close → **hide**（驻留）
- explicit Quit / Cmd-Q / `applicationWillTerminate` → `quit` + `terminate` teardown once
- `applicationShouldTerminateAfterLastWindowClosed = false`
- ActivationPreferences 运行时开关 ↔ status item install/teardown；真实 Activation Settings 面板
- four-finger `process` + `flushPendingShows`
- B10/B11 回归与物理门仍诚实挂账

### Known flake（非本任务引入）
- `LauncherWindowControllerTests.testInterruptPresentWithDismissCompletesOnlyNewRequest`：单独跑 PASS；与同套件 `testAttach…` 同进程顺序跑时偶发仍停在 `.dismissing`（0.12s RunLoop spin / NSAnimationContext 完成回调序敏感）。全量 `swift test` 本次 0 failures。属 T-1G-B 动画完成路径序敏感，建议 E 或 follow-up 改为 expectation/轮询，不在本任务写集内修改。

## AccessDeclaration

`NO_PRIOR_EXPOSURE` — 未读取 LaunchBetter / BuhoReverseNotes / reverse dumps；未使用私有 Space/WindowServer API、全局 NSEvent monitor、CGEvent tap、Accessibility API。Status item 仅公开 `NSStatusBar`/`NSStatusItem`；Dock reopen 仅 `applicationShouldHandleReopen`。

## Reviewer focus

1. 菜单 validation 是否只读 `committedVisibility`，无本地第二 toggle 位。
2. Dock reopen visible 路径是否只 `makeKeyAndOrderFront`、不发第二 present、不建第二窗。
3. AppDelegate 是否真正「最小」且 blank→terminate 未被误改。
4. 创建失败 / teardown 是否幂等且不崩溃。
5. 隐私：无指针坐标/屏幕 UUID/前台 app/窗口标题日志。
