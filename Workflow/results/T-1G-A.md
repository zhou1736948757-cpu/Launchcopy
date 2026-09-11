# T-1G-A — ADR-011/012 草稿 + 纯 presentation/activation 状态机（Worker 结果）

- **Task**: T-1G-A（chef-worker-reviewer-workflow v1.4.1，Worker 角色）
- **Date**: 2026-09-05
- **Status**: COMPLETED（测试全绿；未自证 PASS，待 Reviewer）
- **Objective 完成度**: 3/3（ADR 草稿 ×2、纯 Foundation 状态机 ×6 文件、测试 ×4 套件 65 项）

## Changed files

| 文件 | 类型 | 说明 |
|---|---|---|
| `Sources/PagingPrototypeApp/LauncherPresentationState.swift` | 新增 | LauncherPresentationState / LauncherActivationSource / LauncherCommand / DismissReason / LauncherSuspensionReason / ScreenID / LauncherPresentationEffect |
| `Sources/PagingPrototypeApp/LauncherPresentationCoordinator.swift` | 新增 | 纯状态机：request generation / stale rejection / toggle 原子 / 中断策略 / show-hide 幂等 / quit dominates / terminate teardown once / suspend-resume |
| `Sources/PagingPrototypeApp/HotCornerStateMachine.swift` | 新增 | HotCorner / HotCornerClock（可注入 fake clock）/ HotCornerParameters / HotCornerStateMachine（.disabled/.armed/.insideCandidate/.triggeredAwaitingExit/.suspended）+ HotCornerEvent（只发 .show） |
| `Sources/PagingPrototypeApp/ScreenGeometrySnapshot.swift` | 新增 | LauncherPoint/LauncherRect/LauncherSize 自含值类型 + ScreenGeometrySnapshot（负坐标/多屏/内角规则/原子替换/re-arm 判定） |
| `Sources/PagingPrototypeApp/ShortcutRegistrationOutcome.swift` | 新增 | ShortcutRegistrationOutcome（configured/conflict/unavailable）+ ShortcutSpec/ShortcutModifiers + ShortcutRegistration（rollback 语义） |
| `Sources/PagingPrototypeApp/ActivationSettings.swift` | 新增 | 纯值模型（§9.8 纯逻辑）：默认全 Off、安全解码、未来 schema 安全默认、resetActivation |
| `Tests/PagingUITests/LauncherPresentationCoordinatorTests.swift` | 新增 | §9.1 12 项 + 负样本（24 tests） |
| `Tests/PagingUITests/HotCornerStateMachineTests.swift` | 新增 | §9.6 14 项 + 负样本（20 tests） |
| `Tests/PagingUITests/ScreenGeometrySnapshotTests.swift` | 新增 | §9.7 10 项 + re-arm 附加（11 tests） |
| `Tests/PagingUITests/ActivationSettingsTests.swift` | 新增 | §9.8 9 项（10 tests） |
| `Docs/ADR-011-LAUNCHER-PRESENTATION-LIFECYCLE.md` | 新增 | Chief DRAFT，答 Prompt §5.1 全部 12 问 |
| `Docs/ADR-012-SYSTEM-WIDE-ACTIVATION-PRIVACY.md` | 新增 | Chief DRAFT，答 Prompt §5.2 全部 12 问 |
| `Docs/PRIVACY_DATA_MAP.md` | 追加 | §9 激活入口与 Hot Corner 数据边界（Phase 1G 追加段） |

未改动：冻结树、Package.swift、AppDelegate/AppMain/AppArguments/KeyboardFocusController、AppLaunchController.swift、任何既有测试。

## Test counts

- 命令：`swift test --filter 'LauncherPresentationCoordinatorTests|HotCornerStateMachineTests|ScreenGeometrySnapshotTests|ActivationSettingsTests'`
- exit code：**0**
- executed：**65**；passed：**65**；failed：**0**

| 套件 | executed | passed | failed | 覆盖 |
|---|---|---|---|---|
| LauncherPresentationCoordinatorTests | 24 | 24 | 0 | §9.1 12 项 + 负样本 |
| HotCornerStateMachineTests | 20 | 20 | 0 | §9.6 14 项 + 负样本 |
| ScreenGeometrySnapshotTests | 11 | 11 | 0 | §9.7 10 项 + re-arm 附加 |
| ActivationSettingsTests | 10 | 10 | 0 | §9.8 9 项 |

## Evidence（命令 + 输出）

```
$ swift test --filter 'LauncherPresentationCoordinatorTests|HotCornerStateMachineTests|ScreenGeometrySnapshotTests|ActivationSettingsTests'
Test Suite 'ActivationSettingsTests' passed at 2026-09-05 18:31:09.199.
	 Executed 10 tests, with 0 failures (0 unexpected) in 0.003 (0.003) seconds
Test Suite 'HotCornerStateMachineTests' passed at 2026-09-05 18:31:09.203.
	 Executed 20 tests, with 0 failures (0 unexpected) in 0.003 (0.004) seconds
Test Suite 'LauncherPresentationCoordinatorTests' passed at 2026-09-05 18:31:09.207.
	 Executed 24 tests, with 0 failures (0 unexpected) in 0.003 (0.004) seconds
Test Suite 'ScreenGeometrySnapshotTests' passed at 2026-09-05 18:31:09.209.
	 Executed 11 tests, with 0 failures (0 unexpected) in 0.002 (0.002) seconds
Test Suite 'Selected tests' passed at 2026-09-05 18:31:09.209.
	 Executed 65 tests, with 0 failures (0 unexpected) in 0.010 (0.015) seconds
$ echo $?
0
```

## Per-criterion results（任务包验收逐项）

| 验收项 | 结果 | 证据 |
|---|---|---|
| 相关测试套件 executed > 0 且 0 failures | **PASS** | 65/65，exit 0（见上） |
| show 在 visible/presenting 幂等 | **PASS** | `testVisibleShowIsIdempotent` / `testPresentingRepeatedShowIsIdempotent` |
| hide 在 hidden/dismissing 幂等 | **PASS** | `testHiddenHideIsIdempotent` / `testDismissingHideIsIdempotent` |
| toggle 原子 | **PASS** | `testVisibleToggleHides` / `testHiddenToggleShows` / `testPresentingToggleInterruptsToDismiss`（coordinator 唯一写者，committed state 单步决策） |
| Hot Corner 只发 .show 永不反向 hide | **PASS** | `testHotCornerRepeatedShowNeverHides`（visible + show(.hotCorner) ×3 → .none）；HotCornerEvent 仅 .showRequested 一个 case |
| quit dominates | **PASS** | `testQuitDominatesLaterRequests` / `testQuitFromEveryState` |
| stale completion rejected | **PASS** | `testStaleCompletionRejected` / `testSuspendCancelsInFlightTransition` |
| terminate teardown once | **PASS** | `testTerminateTeardownOnce` / `testQuitThenTerminateTeardownOnce`（teardownCount 0→1） |
| 无 AppKit import（纯 Foundation） | **PASS** | 6 个新源文件全部仅 `import Foundation`（grep 验证）；无 CoreGraphics（自含 Point/Rect） |
| 测试断言负样本 | **PASS** | 每套件含负样本：terminating 拒绝一切、suspended hide 幂等、未选 corner 不触发、快速跨角不触发、内角不命中、屏外点不命中、cooldown 内不触发、stale 样本忽略、非法值回 Off、未来 schema 安全默认 |
| 不污染真实 UserDefaults | **PASS** | 测试零 UserDefaults 接触（纯值模型 + JSON 内存编解码）；持久化留给 T-G-P3 ActivationPreferences（独立 suite） |
| 不改冻结树 / 不 commit | **PASS** | 见 Changed files；无 git 操作 |

## Deviations（范围披露）

1. **`ActivationSettings.swift` 新增**（任务包写集未显式列出，但 §9.8 9 项测试要求 Preferences 纯逻辑）：实现为纯值模型（无 UserDefaults），文件名避开 T-G-P3 的 `ActivationPreferences.swift`（PLAN §7 写集互斥）；T-G-P3 在其上做持久化 + 独立 suite。属任务包"等，文件名可调"范围内，已披露。
2. **`Docs/PRIVACY_DATA_MAP.md` 追加 §9 段**（Prompt §4.3 明确要求更新；Docs/ 在 PLAN 允许写集内）：仅追加，未改既有内容。
3. **toggle 的 DismissReason 归因**：toggle/handle(.hide) 从 source 派生 reason（statusItem→.statusItem、globalShortcut→.globalShortcut、其余中性回退 .statusItem），代码注释已文档化。
4. **suspend/resume 语义**（任务包未细定）：suspend 取消 in-flight transition（completion 变 stale）；resume 确定性回 .hidden（唤醒不自动弹窗）；Hot Corner resume 要求指针重新离开/进入（§3.11）。ADR-011 Q5/Q6、ADR-012 Q6 已记录。
5. **中断策略**：presenting/dismissing 收到相反命令 → 中断（interrupt）而非排队；ADR-011 Q2 记录"排队仅作 UI 层动画不可中断时的降级（T-1G-B 决定）"。

## Unresolved questions

1. 窗口形态（native fullscreen vs screen-covering panel）——ADR-011 Q3 待 T-1G-B spike 证据，Chief 决策项（`WINDOW_ARCHITECTURE_DECISION_REQUIRED`）。
2. Hot Corner poll scheduler（Timer vs DispatchSourceTimer vs 专用低功耗）——ADR-012 Q3 待 T-1G-D 比较证据。
3. status/shortcut/Dock 的 target screen 策略（鼠标所在屏 vs key/main fallback）——ADR-011 Q9 原则已定，T-1G-C/D 实现时验证。
4. §9.7 任务包说 10 项、Prompt 列 9 项：第 10 项按"point outside all screens no match"实现（负样本），如 Reviewer 认为应换为其他项可指出。
5. B10 实机 A/B 与 120Hz/多显示器物理门挂账（PHYSICAL_PENDING），与本任务无关。

## Reviewer focus

1. 状态机语义与任务包验收逐项对照（上表）；特别检查 toggle 原子性（无先读后写）与 stale rejection 路径。
2. 纯 Foundation 约束：6 源文件仅 `import Foundation`；无 AppKit/CoreGraphics 类型泄漏。
3. §9.8 的"isolated suite"项：本套件零 UserDefaults 接触是否符合预期（持久化在 T-G-P3）。
4. 内角规则（`isValidOuterCorner` 含边界判定）与 cornerZone 确定性（列表序第一个命中）是否符合 §3.8。
5. ADR-011/012 草稿：12 问一一对应、Chief DRAFT 标注、待 spike 项未越权定案。
6. 隐私红线：新文件无 `addGlobalMonitorForEvents`/`CGEvent.tapCreate`/`AXIsProcessTrusted`/`IOHID`/`LaunchBetter`/`Buho`/`frontmostApplication`（grep 验证，仅注释提及"无 AppKit"与 NSEvent.mouseLocation 的 adapter 职责描述）。

## Memory candidates（供 Main 门控）

1. **内角规则**：共享边/拼接处角点落在另一屏幕 frame 内（含边界）→ 该角 internal 非有效热角；左右排列下 B 的 topLeft/bottomLeft 是内角（测试曾误用，已修正为 topRight）。
2. **Hot Corner 触发后 re-arm**：必须离开 zoneSize+hysteresis 扩展区；cooldown 从 lastTriggerTime 起算，与 dwell 独立。
3. **唤醒语义**：Hot Corner resume 后 requiresExitBeforeDwell（指针须先离开再进入）；presentation resume 确定性回 .hidden。
4. **测试教训**：负坐标屏的 topLeft = (minX, maxY)，不是"左上角直觉坐标"；side-by-side 屏的共享边角是内角——写几何测试前先列有效外角集合。
