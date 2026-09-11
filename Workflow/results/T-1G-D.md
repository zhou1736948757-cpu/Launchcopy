# T-1G-D — Global Shortcut + Hot Corner adapters（Worker 结果）

- **Task**: T-1G-D（chef-worker-reviewer-workflow v1.4.1，Worker 角色）
- **Date**: 2026-09-10
- **Status**: COMPLETED（测试全绿；未自证 PASS，待 Reviewer）
- **Objective**: 生产适配 GlobalShortcutRegistrar + HotCornerMonitor（+ WorkspaceSessionObserver）；锁定 ADR-012 Q2/Q3；Fake 可测；默认 Off

## Changed files

| 文件 | 类型 | 说明 |
|---|---|---|
| `Sources/PagingPrototypeApp/GlobalShortcutRegistrar.swift` | CREATE | `GlobalShortcutRegistering` + `FakeGlobalShortcutRegistrar` + `CarbonGlobalShortcutRegistrar`（RegisterEventHotKey）；debounce；rollback reconfigure |
| `Sources/PagingPrototypeApp/HotCornerMonitor.swift` | CREATE | 可暂停主线程 Timer 调度 + 注入 pointer/geometry/scheduler/clock；只回调 show；`ScreenGeometrySnapshotBuilder` |
| `Sources/PagingPrototypeApp/WorkspaceSessionObserver.swift` | CREATE | sleep/session/screens 观察 + Fake + `WorkspaceSessionHotCornerBridge` |
| `Docs/ADR-012-SYSTEM-WIDE-ACTIVATION-PRIVACY.md` | EDIT | Q2/Q3 **ACCEPTED**（API + scheduler 比较表 + 实现契约） |
| `Docs/PARAMETER_RATIONALE.md` | EDIT | 追加 §5 Hot Corner/shortcut 参数 |
| `Tests/PagingUITests/GlobalShortcutRegistrarTests.swift` | CREATE | 10 tests（success/conflict/rollback/unregister/debounce/bare key/default Off） |
| `Tests/PagingUITests/HotCornerMonitorTests.swift` | CREATE | 8 tests（zero timer/dwell once/leave cancel/suspend/resume re-enter/session bridge/disable） |
| `Workflow/results/T-1G-D.md` | CREATE | 本结果 |

## Untouched（硬约束）

- `Sources/PagingPrototypeApp/AppDelegate.swift` — **未改**（并行 T-1G-C / 后续 T-1G-E）
- `Package.swift` — **未改**（Carbon `import` 探针证明无需 linkerSettings）
- 冻结树 / AppLaunchController / StatusItemController — 未改
- 无 commit/push

## Carbon / Package.swift 结论

- 探针包 `/tmp/CarbonProbePkg`：`import Carbon` + `RegisterEventHotKey` / `InstallEventHandler` **链接成功，无 linkerSettings**。
- 因此 **生产 `CarbonGlobalShortcutRegistrar` 已交付**，**不**对 Main 报 BLOCKED。
- 若未来工具链回归需要 `linkerSettings`，仍须 Main 独占改 Package.swift。

## ADR-012 Q2/Q3 lock

| 问 | 定案 | 证据 |
|---|---|---|
| Q2 快捷键 API | **ACCEPTED**：公开 `RegisterEventHotKey`/`UnregisterEventHotKey`；窄 protocol；禁 global monitor/tap | ADR-012 Q2 表 + `CarbonGlobalShortcutRegistrar` |
| Q3 poll scheduler | **ACCEPTED**：主线程 `Timer`（`.common`，tolerance≈25%）；默认 75ms；disabled=零 timer；不用 DispatchSourceTimer / 帧泵 | ADR-012 Q3 比较表 + `MainRunLoopHotCornerScheduler` / Fake 测试 |

## Test counts

- 命令：`swift test --filter 'GlobalShortcutRegistrarTests|HotCornerMonitorTests'`
- exit code：**0**
- executed：**18**；passed：**18**；failed：**0**

| 套件 | executed | passed | failed |
|---|---:|---:|---:|
| GlobalShortcutRegistrarTests | 10 | 10 | 0 |
| HotCornerMonitorTests | 8 | 8 | 0 |
| **合计** | **18** | **18** | **0** |

### Evidence（命令输出摘要）

```
Test Suite 'GlobalShortcutRegistrarTests' passed ...
	 Executed 10 tests, with 0 failures (0 unexpected)
Test Suite 'HotCornerMonitorTests' passed ...
	 Executed 8 tests, with 0 failures (0 unexpected)
Test Suite 'Selected tests' passed ...
	 Executed 18 tests, with 0 failures (0 unexpected)
$ echo $? → 0
```

Build：`swift build --target PagingPrototypeApp` exit 0（含新三文件编译）。

## Per-criterion（任务包 Acceptance）

| # | 验收项 | 结果 | 证据 |
|---|---|---|---|
| 1 | ADR-012 Q2/Q3 ACCEPTED + rationale | **PASS** | ADR 文件 Q2/Q3 段 |
| 2a | register success/conflict/rollback；unregister | **PASS** | GlobalShortcutRegistrarTests |
| 2b | hot corner disabled 零 timer；dwell 一次；leave 取消；suspend 停轮询 | **PASS** | HotCornerMonitorTests |
| 2c | 新源无坐标/真实快捷键日志字符串 | **PASS** | grep：无 `NSLog`/`print`；`mouseLocation` 仅读取非日志；禁 API 仅注释提及 |
| 3 | builds green；executed > 0 | **PASS** | 18/18，exit 0 |
| 4 | 注明 E 接线责任 | **PASS** | 见下节 |

## T-1G-E 必须接线（本任务不写 AppDelegate）

1. **Prefs → 启停**：`ActivationPreferences`/`ActivationServicePlan` diff →
   - Hot Corner：`monitor.enable(corner:)` / `disable()` / `teardown()`
   - Shortcut：`registrar.register(spec)` / `unregister()` / `reconfigure(spec)`；展示 `registration.outcome`
2. **Callbacks → presentation**：
   - `registrar.onFired` → `LauncherWindowController`/`coordinator.toggle(source: .globalShortcut, targetScreen: …)`
   - `monitor.onShowRequested` → `show(source: .hotCorner, targetScreen:)`（**永不 hide**）
3. **Session**：`WorkspaceSessionObserver.start()`；`onEvent` → `WorkspaceSessionHotCornerBridge.apply(_:to:)`
4. **Launcher visible**：presenting/visible → `monitor.setLauncherVisible(true)`；hidden → `false`
5. **Screens**：已由 observer `.screensChanged` 覆盖；亦可在窗控层补调
6. **Teardown / quit**：先 `registrar.teardown()`/`unregister()` + `monitor.teardown()` + `observer.stop()`，再窗控 terminate
7. **默认 Off**：启动时不要 register/enable，除非 prefs 显式开启

## Privacy / red-line

- 无 `addGlobalMonitorForEvents` / `CGEvent.tapCreate` / `AXIsProcessTrusted` / `IOHID` / `frontmostApplication`（新源 grep）
- 不持久化/不日志鼠标坐标、屏幕 UUID/名称、真实快捷键文本
- 允许中性：outcome enum、corner enum、ScreenID.index、trigger/poll/show 计数

## Deviations / disclosures

1. **生产 Carbon adapter 已实现**（非 fake-only），因 Package.swift 无需改动。
2. **launcher visible 时本实现不停 timer**，仅状态机抑制 show（ADR-012 Q3 已注明；T-1G-F 能耗门可收紧为 visible 时 `stop`）。
3. **并行编译观察到** `StatusItemController.swift` / `AppDelegate.swift` 存在于构建图（T-1G-C）；本 Worker **未编辑**二者。
4. `ActivationPreferences` 已由 T-G-P3 交付，本任务未重复实现持久化。

## Memory candidates（供 Main 门控）

1. 当前 SDK（macOS 14+ / Xcode 工具链）下 SPM `import Carbon` **无需** Package.swift `linkerSettings` 即可链接 `RegisterEventHotKey`。
2. Hot Corner poll 定案：主线程 `Timer` @ 75ms；disabled = 零 timer。

## Unresolved / follow-ups

- T-1G-E 组合接线与物理门（快捷键在 app inactive 时、多屏、能耗 A/B）
- 系统保留快捷键清单的产品级拒绝策略（当前依赖系统 conflict + 禁止裸键）
- Reviewer 独立裁决 PASS/FAIL

## Reviewer focus

1. Q2/Q3 是否真正 ACCEPTED 且比较表充分
2. Fake 测试是否覆盖 rollback / zero timer / suspend
3. Carbon 路径是否在主线程约束下安全；pending-ID reconfigure 是否正确
4. 确认未改 AppDelegate / Package.swift
5. 隐私扫描与默认 Off
