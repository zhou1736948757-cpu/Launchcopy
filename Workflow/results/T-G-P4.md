# T-G-P4 — 四指激活接线组件（PinchEvent → LauncherPresentationCoordinator）（Worker 结果）

- **Task**: T-G-P4（chef-worker-reviewer-workflow v1.4.1，Worker 角色）
- **Date**: 2026-09-05
- **Status**: COMPLETED（测试全绿；未自证 PASS，待 Reviewer）
- **Objective 完成度**: 5/5（LauncherActivationSource 加 .fourFingerPinch + 穷尽性适配；接线组件 showRequested → coordinator.show(.fourFingerPinch)；去重/generation/Q-1 防重放；QUESTION-1 重复 ready 幂等 + QUESTION-2 displayKind 组合语义；输入交接会话结束优先 + 测试矩阵）

## Changed files

| 文件 | 类型 | 说明 |
|---|---|---|
| `Sources/PagingPrototypeApp/LauncherPresentationState.swift` | 修改（仅加 case） | `LauncherActivationSource` 加 `.fourFingerPinch`（L29，位于 hotCorner 与 testHarness 之间）；CaseIterable 现 7 case；仓库内无其他穷尽 switch 需适配（`dismissReason(for:)` 走 default 中性回退；Tests 无 allCases 断言） |
| `Sources/PagingPrototypeApp/FourFingerActivationCoordinator.swift` | 新增 | 接线组件（纯 Foundation 值类型，Sendable）：持有 recognizer/presentation/activation/targetScreen/userEnabled；`process(_ frame:)`（识别器路径，show 事件入队）、`handlePinchEvent(_:)`（外部事件源路径，入队）、`flushPendingShows()`（统一派发，含 terminating/suspended/generation/去重/交接五重校验）、`start/stop/restart/suspend/resume`（生命周期转发）、`handleProviderState(_:)`（QUESTION-1 幂等 ready）、`displayStatus`/`isReady`（QUESTION-2）；中性计数 7 项；排队有界（maxPendingShowTokens=8，首个手势优先） |
| `Tests/PagingUITests/FourFingerActivationCoordinatorTests.swift` | 新增 | 20 tests：接线（含注入 targetScreen）、去重、generation 校验、Q-1 防重放（suspend 清队列 + 挂起期间拒绝 + 恢复后新手势可触发）、QUESTION-1（重复 ready 幂等 + 失败态恢复）、QUESTION-2（(enabled:true, state:.off) → .disabled）、交接（同会话/跨设备去重、全指释放清除）、四指永不 hide/quit、visible/terminating 拒绝、provider 状态映射、生命周期转发、allCases 7 case |

未改动：冻结树（PagingCore/PagingTelemetry/PagingUI/AppCatalogCore/MacAppCatalog/AppIconPipeline/AppGridUI/Package.swift）、AppDelegate/AppMain/AppArguments/KeyboardFocusController、AppLaunchController.swift、任何其他既有源文件/测试文件（mtime 核验：任务窗口 19:55 后 Sources/Tests 仅上述 3 文件）。

## Test counts

- 命令：`swift test --filter FourFingerActivationCoordinatorTests`
- exit code：**0**
- executed：**20**；passed：**20**；failed：**0**

| 套件 | executed | passed | failed | 覆盖 |
|---|---|---|---|---|
| FourFingerActivationCoordinatorTests | 20 | 20 | 0 | 接线/去重/generation/Q-1/QUESTION-1/QUESTION-2/交接/永不 hide/quit/生命周期/allCases |

全量回归：`swift test` → **1362 executed / 0 failures**（基线 1342 + 本任务 20；exit 0）。

## Evidence（命令 + 输出）

```
$ swift test --filter FourFingerActivationCoordinatorTests
Test Suite 'FourFingerActivationCoordinatorTests' passed at 2026-09-05 19:59:53.660.
	 Executed 20 tests, with 0 failures (0 unexpected) in 0.004 (0.005) seconds
Test Suite 'PagingPrototypePackageTests.xctest' passed at 2026-09-05 19:59:53.660.
	 Executed 20 tests, with 0 failures (0 unexpected) in 0.004 (0.005) seconds
Test Suite 'Selected tests' passed at 2026-09-05 19:59:53.660.
	 Executed 20 tests, with 0 failures (0 unexpected) in 0.004 (0.006) seconds
$ echo ${PIPESTATUS[0]}
0

$ swift test
Test Suite 'All tests' passed at 2026-09-05 20:00:38.502.
	 Executed 1362 tests, with 0 failures (0 unexpected) in 16.218 (16.299) seconds
$ echo ${PIPESTATUS[0]}
0
```

## Per-criterion results（任务包验收逐项）

| 验收项 | 结果 | 证据 |
|---|---|---|
| 加 `.fourFingerPinch` 到 LauncherActivationSource，同步适配 CaseIterable/穷尽 switch | **PASS** | LauncherPresentationState.swift L29 加 case；`testLauncherActivationSourceIncludesFourFingerPinch`（allCases == 7，顺序 [initialLaunch, dockReopen, statusItem, globalShortcut, hotCorner, fourFingerPinch, testHarness]）；仓库 grep 确认无其他穷尽 switch（dismissReason 走 default；Tests 无 allCases 断言）→ 无既有测试需适配 |
| 接线组件：showRequested(token:) → coordinator.show(source: .fourFingerPinch, targetScreen:)；targetScreen 调用方注入 | **PASS** | `dispatchShow` 唯一出口 `presentation.show(source: .fourFingerPinch, targetScreen: targetScreen)`；`testShowRequestedPresentsWithFourFingerPinchSource`（effect .present(requestID:1, targetScreen: screenA, source: .fourFingerPinch)）；`testShowUsesInjectedTargetScreen`（ScreenID(index:3) 注入生效） |
| 四指只发 show，永不 hide/quit（PLAN §9 不变量 3） | **PASS** | 组件无 hide/toggle/quit 方法；`testFourFingerNeverHidesOrQuits`（同会话锁存零事件、会话结束+新手势仍只发 show、presentation 状态永不反向）；`testShowWhileVisibleIsNoop`（已显示无副作用）；`testShowWhileTerminatingRejected`（正在 Quit 拒绝新请求，§21.1） |
| 去重：同一 PinchEventToken 只一次 show（token.generation + sessionID 校验） | **PASS** | `lastConsumedToken` 全等比较（generation+sessionID）；`testSameTokenDeliveredTwiceProducesOneShow`（两次注入 → [.present, .none]，showCount 1，droppedDuplicateEventCount 1） |
| **Q-1 处理**：suspend 前排队/未消费 show 在 suspend 后不得重放（generation 校验或 suspend 时清队列；测试覆盖） | **PASS** | 双机制：①`suspend()` 清空 `pendingShowTokens`（"suspend 时清队列"——识别器 suspend 不递增 generation，故清队列是唯一可靠屏障）；②`dispatchShow` 挂起检查（activation/presentation 任一 suspended → 拒绝）。`testQueuedShowBeforeSuspendNotReplayedAfterResume`（fire → 入队 1 → suspend 清空 → flush 空 → resume 后 flush 空、showCount 0 → 新手势正常触发）；`testShowEventWhileSuspendedRejected`（挂起期间到达 → .none，droppedSuspendedEventCount 1） |
| **QUESTION-1 处理**：provider 重复上报 ready → 幂等接受（不崩溃、不重复启动服务） | **PASS** | `handleProviderState(.ready)` 先 guard `activation.state != .ready` 再 apply(.backendReady)（(.ready,.backendReady) 在状态机非法 → 接线层拦截）；`testRepeatedReadyIsIdempotent`（重复上报 → 状态 .ready、recognizer.generation/isEnabled/fireCount 不变）；`testRepeatedReadyFromFailureStatesRecovers`（noDevice/unavailable/permissionNotConfirmed → ready 恢复路径） |
| **QUESTION-2 确认**：displayKind (enabled:true, state:.off) 组合语义——接线层定义并测试 | **PASS** | 接线层语义：**开关开 + 后端 off → `.disabled`**（后端 off = 无活动，事实展示，不冒充就绪；与 T-G-P3 displayKind 实现一致，本层文档化 + 测试固化）；`testDisplayKindEnabledOffCombinationIsDisabled`（(true,.off)→.disabled、isReady false；对照 (false,.ready)→.disabled、(true,.ready)→.ready） |
| 输入交接（§21.1 会话结束优先）：fired 后交接期间新 show 去重；会话结束（全指释放）优先 | **PASS** | `handoffToken` 在 show 派发时设置、识别器回到 idle（全指释放）时清除；`testHandoffSuppressesNewShowUntilSessionEnd`（派发后另一会话 show → .none、droppedHandoffEventCount 1；释放帧 → handoffToken nil；新手势可再触发）；`testSecondDeviceShowDuringHandoffDropped`（设备 B 交接期间触发去重；A 释放后交接保持、B 也释放后清除——全指释放语义） |
| 测试：接线/去重/generation/Q-1 场景/重复 ready/交接/displayKind 组合；T-1G-A 既有测试回归 | **PASS** | 20 tests 覆盖全部要求项（见 Changed files）；T-1G-A 既有测试（LauncherPresentationCoordinatorTests 24 项等）零适配需求（无 allCases/穷尽断言），全量 1362/0 回归确认 |
| 写集合规（仅新文件 + LauncherPresentationState.swift 加 case + 新测试） | **PASS** | mtime 核验：任务窗口（19:55 后）Sources/Tests 仅 3 文件（LauncherPresentationState.swift 19:59:13、FourFingerActivationCoordinator.swift 19:59:43、FourFingerActivationCoordinatorTests.swift 19:59:33）；冻结树 find -newermt 零命中；AppDelegate/AppMain/AppArguments/KeyboardFocusController/Package.swift/AppLaunchController.swift mtime 均早于窗口 |
| 隐私红线（PLAN §11 静态扫描） | **PASS** | 新文件 grep 零命中（addGlobalMonitorForEvents/CGEvent.tapCreate/AXIsProcessTrusted/IOHID/LaunchBetter/Buho/frontmostApplication/NSEvent/NSApp/AppKit/dlopen/dlsym/MTDevice/Date()/pointer coordinate/CGEvent）；LauncherPresentationState.swift 仅 2 处既有政策文字注释命中（"纯 Foundation，无 AppKit"，T-G-P3 评审已接受）；纯 Foundation，无墙钟依赖；不记录触点坐标/设备序列号/时间戳原始值（仅中性计数） |
| 不 commit/push/tag | **PASS** | 无任何 git 操作（仓库无基线提交） |

## Deviations（范围披露）

1. **接线组件持有识别器（process 路径为主）**：任务允许"PinchRecognizer（或 PinchEvent 源）"二选一；本实现持有识别器，`process(_ frame:)` 为事件主路径（show 事件自动入队），`handlePinchEvent(_:)` 为外部事件源注入路径（同一队列）。两条路径均经 `flushPendingShows()` 统一派发——Q-1"suspend 时清队列"对两条路径一致生效。
2. **handlePinchEvent 返回 Void（入队语义）**：外部源路径的事件入队而非立即派发，effect 由 `flushPendingShows()` 产出；契约：外部源不得跨 suspend 保留事件（suspend 清队列；挂起期间到达的事件在派发时被拒）。
3. **交接窗口定义为"show 派发 → 全指释放"**：`handoffToken` 在派发（消费）时设置、识别器回到 idle 时清除；与"fired 后交接期间"在正常同步路径（process 后立即 flush）等价；延迟 flush 的病理场景下首个手势优先（与排队溢出策略一致）。
4. **handleProviderState 仅更新状态机**：识别器生命周期由 `start()/stop()/restart()` 显式驱动（"不重复启动服务"= 重复 ready 不触碰识别器，测试固化）；provider 报告 checking/ready 在无合法状态机转换时（如 off/ready 组合）被安全忽略（不崩溃、状态不变）。
5. **userEnabled 仅用于展示**：`displayStatus`/`isReady` 消费用户开关；不 gate 识别器生命周期与 show 派发（功能启停由接线层 start/stop 控制）。
6. **未接真实屏幕/AppDelegate**：targetScreen 由调用方注入（任务包明确 T-1G-E 集成时接）；组件为纯逻辑，无窗口行为代码。
7. **未新增 completeTransition 等呈现转发方法**：测试经全注入 init（presentation initialState .visible/.terminating）覆盖特殊状态；T-1G-E 集成时如需呈现层转发方法可扩展（本任务写集最小化）。

## Unresolved questions

1. 真实接线（T-1G-E）：provider onFrame/onStateChange 挂接、targetScreen 真实屏幕列表、AppDelegate 生命周期驱动、呈现层 effect 执行（present/dismiss/suspend/terminate）。
2. 外部事件源路径的跨 suspend 事件保留：本层契约要求外部源不得跨 suspend 保留事件；若 T-1G-E 采用异步队列，需在接线层落实"挂起时清外部队列"（本层已提供 suspended 拒绝兜底）。
3. 交接期间 UI 层触摸抑制（§21.1 最后一项"避免余下触摸立刻在启动器上翻页或点开应用"）：属 UI 层策略（T-1G-E/UI 任务），本层只落实 show 去重与会话结束优先。
4. 物理门（M01-M12）与真实触控板验证（T-G-P6）：自动化测试不能替代实机。

## Reviewer focus

1. **Q-1 闭环**：suspend() 清队列 + 派发时挂起拒绝双机制；`testQueuedShowBeforeSuspendNotReplayedAfterResume` 覆盖"排队 → suspend → resume → 不重放 → 新手势可触发"全链。
2. **QUESTION-1 闭环**：接线层拦截 (.ready,.backendReady) 非法转换（guard 幂等），重复 ready 不崩溃、不重启服务（generation/isEnabled 断言）。
3. **QUESTION-2 语义**：(enabled:true, state:.off) → .disabled 的文档化定义 + 测试（含 isReady 对照）。
4. **交接语义**：handoffToken 派发时设置/全指释放清除；跨设备场景（A 释放 B 锁存 → 交接保持）验证"全指释放"而非单会话释放。
5. **去重与 generation**：lastConsumedToken 全等（generation+sessionID）；stop/restart 后旧 generation 事件丢弃。
6. **四指永不 hide/quit**：组件 API 无 hide/toggle/quit；visible/terminating 状态下的 show 行为符合 §21.1。
7. **写集合规与隐私红线**：3 文件 mtime 证据；新文件红线扫描零命中；纯 Foundation。
8. **全量回归**：1362/0（基线 1342 + 20），T-1G-A 既有测试零适配。

## Memory candidates（供 Main 门控）

1. **Q-1 防重放双机制模式**：识别器 suspend 不递增 generation → 接线层"suspend 时清队列"（唯一可靠屏障）+ 派发时挂起拒绝兜底；恢复后新手势正常触发（generation 未变但队列已清）。
2. **QUESTION-1 幂等 ready 模式**：状态机拒绝 (.ready,.backendReady) → 接线层 guard 拦截（重复 ready = no-op），不崩溃、不重启服务；失败态（noDevice/unavailable/permissionNotConfirmed）→ ready 恢复路径合法。
3. **QUESTION-2 展示语义**：(enabled:true, state:.off) → .disabled（后端 off = 无活动，事实展示）；isReady = enabled && state == .ready 不变。
4. **交接窗口模式**：handoffToken 在 show 派发时设置、识别器回 idle（全指释放）时清除；跨设备场景需全部会话结束才清除。
5. **接线组件形态**：值类型持有 recognizer/presentation/activation，事件入队 + flush 统一派发（五重校验：terminating/suspended/generation/去重/交接），中性计数 7 项；targetScreen/userEnabled 由接线层注入。
