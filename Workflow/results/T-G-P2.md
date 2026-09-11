# T-G-P2 — 平台 provider（Mock 先行）（Worker 结果）

- **Task**: T-G-P2（chef-worker-reviewer-workflow v1.4.1，Worker 角色）
- **Date**: 2026-09-05
- **Status**: COMPLETED（测试全绿；未自证 PASS，待 Reviewer）
- **Objective 完成度**: 4/4（TouchProvider protocol、MockTouchProvider、生命周期测试 P13/P14/P15 + §20.2、provider→recognizer 集成测试；真实 MultitouchSupport 后端未实现）

## Changed files

| 文件 | 类型 | 说明 |
|---|---|---|
| `Sources/PagingPrototypeApp/TouchProvider.swift` | 新增 | `TouchProviderState`（off/checking/ready/noDevice/unavailable/permissionNotConfirmed/suspended(reason: PinchSuspensionReason)，与 T-G-P3 入口状态模型对齐）；`PinchClockAdvancing`（测试用时间推进协议）；`TouchProvider` protocol（AnyObject：`state`/`onStateChange`/`onFrame`/`generation`/`isStarted` + `start()`/`stop()`/`restart()`，文档化幂等语义与锁序：start 已启动=no-op、stop 未启动=no-op、restart 生成新 generation；帧 device-scoped 且 timestamp 与注入时钟同一单调时间域，禁止墙钟 Date()） |
| `Sources/PagingPrototypeApp/MockTouchProvider.swift` | 新增 | `MockFrameStep(phase:contacts:timeStep:)` 预置帧序列；`MockTouchProvider`：NSLock 窄锁、`DeliveryMode`（.synchronous/.asynchronous）、`startupState` 可配置（默认 .ready）、start→.checking→startupState 两次通知、stop 清队列+开会话+generation+1→.off、restart generation+1→.checking→startupState、`simulateStateChange(_:)`、`push(_:)`（validate：ts≥0/计数≤maxContactCount(默认16)/began 非空/位置有限/id 唯一；checkContract：began 开会话、moved 需开会话且空触点=结束证据关会话、ended/cancelled 需开会话并关会话）、`push(phase:contacts:deviceID:)` 用 clock.now() 打戳、`playback(_:deviceID:)` 打戳后经 `clock as? PinchClockAdvancing` 推进、`drain()` 交付排队帧、`deliver()` 锁内计 deliveredFrameCount 后锁外调 onFrame；异步有界队列（maxQueueSize 默认 64）过载只丢 moved、保留 began/ended/cancelled；中性计数 deliveredFrameCount/rejectedFrameCount/contractViolationCount/droppedMovedFrameCount/stateChangeCount/pendingFrameCount |
| `Tests/PagingUITests/TouchProviderLifecycleTests.swift` | 新增 | P13/P14/P15 + §20.2 锁序/缓冲/事件保留（14 tests；含 `extension FakePinchClock: PinchClockAdvancing`） |
| `Tests/PagingUITests/MockTouchProviderTests.swift` | 新增 | 帧契约强制、非法帧拒绝、设备隔离、注入时钟打戳、playback 时间推进、状态通知序列（17 tests） |
| `Tests/PagingUITests/TouchProviderIntegrationTests.swift` | 新增 | MockTouchProvider 帧序列 → PinchRecognizer 完整识别接线（7 tests，复用 T-G-P1 夹具模式） |

未改动：冻结树、Package.swift、AppDelegate/AppMain/AppArguments/KeyboardFocusController、AppLaunchController.swift、PinchRecognizer.swift、任何既有测试、任何既有源文件。真实 MultitouchSupport 后端未实现（无 dlopen/dlsym/MTDevice* 符号）。

## Test counts

- 命令：`swift test --filter TouchProvider`
- exit code：**0**
- executed：**38**；passed：**38**；failed：**0**

| 套件 | executed | passed | failed | 覆盖 |
|---|---|---|---|---|
| TouchProviderLifecycleTests | 14 | 14 | 0 | P13/P14/P15 + §20.2 |
| MockTouchProviderTests | 17 | 17 | 0 | 帧契约/非法帧/设备隔离/时钟/状态通知 |
| TouchProviderIntegrationTests | 7 | 7 | 0 | provider→recognizer 接线 |

全量回归：`swift test` → **1285 executed / 0 failures**（基线 1247 + 本任务 38；exit 0）。

## Evidence（命令 + 输出）

```
$ swift test --filter TouchProvider
Test Suite 'TouchProviderLifecycleTests' passed at 2026-09-05 19:38:10.458.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.002 (0.002) seconds
Test Suite 'MockTouchProviderTests' passed at 2026-09-05 19:38:10.458.
	 Executed 17 tests, with 0 failures (0 unexpected) in 0.003 (0.003) seconds
Test Suite 'TouchProviderIntegrationTests' passed at 2026-09-05 19:38:10.458.
	 Executed 7 tests, with 0 failures (0 unexpected) in 0.002 (0.002) seconds
Test Suite 'PagingPrototypePackageTests.xctest' passed at 2026-09-05 19:38:10.458.
	 Executed 38 tests, with 0 failures (0 unexpected) in 0.007 (0.009) seconds
Test Suite 'Selected tests' passed at 2026-09-05 19:38:10.458.
	 Executed 38 tests, with 0 failures (0 unexpected) in 0.007 (0.010) seconds
$ echo $?
0

$ swift test
Test Suite 'All tests' passed at 2026-09-05 19:39:29.147.
	 Executed 1285 tests, with 0 failures (0 unexpected) in 71.616 (72.280) seconds
```

## Per-criterion results（任务包验收逐项）

| 验收项 | 结果 | 证据 |
|---|---|---|
| P13 start/start 幂等、stop/stop 幂等、start-stop-start 序列正确 | **PASS** | `testP14StartStartIdempotent`（二次 start 零状态变化、stateChangeCount 不变）/ `testP14StopStopIdempotent` / `testP14StartStopStartSequence`（stop 后重新 start 可正常交付） |
| P14 退出时异步回调（stop 后迟到回调被丢弃/拒绝，generation 校验） | **PASS** | `testP13StopDropsQueuedLateCallbacks`（async 排队帧 stop 后 drain 零交付）/ `testP13StopDropsFramesPushedAfterStop`（push 拒绝）/ `testP13StopBumpsGenerationInvalidatingOldEvents` / `testP13RestartClearsQueueAndBumpsGeneration` / `testP14RestartGeneratesNewGenerationAndDelivers` |
| P15 同步重入假后端无死锁（回调内 stop/restart） | **PASS** | `testP15StopInsideFrameCallbackNoDeadlock` / `testP15RestartInsideFrameCallbackNoDeadlock` / `testP15StopInsideStateChangeCallbackNoDeadlock`（均完成且无死锁） |
| §20.2 回调锁外派发（回调内不持锁做重活） | **PASS** | `testSection20_2CallbacksDispatchedOutsideLock`（帧回调内重入 push 成功 = 锁已释放）/ `testStateChangeNotificationOutsideLock`（状态回调内 restart 成功） |
| §20.2 缓冲有界（迟到帧不无限堆积） | **PASS** | `testSection20_2BoundedBufferDropsMovedKeepsBeginEndCancel`（maxQueueSize=2 过载只丢 moved，保留 [.began, .ended]；droppedMovedFrameCount 计数） |
| §20.2 保留 begin/end/cancel 事件不丢 | **PASS** | 同上 + `testSection20_2AsyncDrainDeliversInOrder`（async 交付顺序 [.began, .moved, .ended]） |
| 帧契约 began→moved*→ended/cancelled（provider 层强制） | **PASS** | `testContractBeganMidSessionRejected` / `testContractMovedWithoutBeganRejected` / `testContractEndedWithoutBeganRejected` / `testContractCancelledWithoutBeganRejected` / `testContractMovedAfterEndEvidenceRejected`（contractViolationCount 计数）；零触点 moved/ended/cancelled 关会话后可新 began（`testContractZeroContactMovedClosesSession` 等） |
| 有效触点帧 device-scoped、单调时间域 | **PASS** | `testDeviceScopedSessionsIndependent` / `testDeviceScopedBeganIsPerDevice` / `testFramesStampedFromInjectedClock`（42.0/42.5 来自注入时钟）/ `testPlaybackPresetSequenceAdvancesTime`（stamps [0, 0.1, 0.11]，clock.current=0.11） |
| 状态通知 Off/Checking/Ready/NoDevice/Unavailable/PermissionNotConfirmed/Suspended | **PASS** | `testStateNotificationSequence`（checking→ready→noDevice→unavailable→permissionNotConfirmed→suspended(sleep)→off 全序列）/ `testStartupStateConfigurable` |
| 集成：MockTouchProvider 帧序列 → PinchRecognizer 完整识别 | **PASS** | `testIntegrationSynchronousPushFullPinch`（1 个 showRequested，token.generation == recognizer.generation）/ `testIntegrationReleaseReArmsThroughProvider`（释放后经 provider 再触发，2 fires）/ `testIntegrationTwoDevicesIndependentSessions`（2 fires）/ `testIntegrationAsyncDrainFullPinch` / `testIntegrationPlaybackFullPinch` / `testIntegrationStopDropsFramesBeforeRecognizer`（stop 后帧不达识别器，识别器状态不变）/ `testIntegrationSuspendedFramesDroppedByRecognizer` |
| 非法帧安全拒绝 | **PASS** | `testInvalidFramesRejected`（NaN/Inf/负 ts/重复 id/17 触点/空 began 六类，rejectedFrameCount 计数） |
| 无真实设备访问；无 dlopen/dlsym | **PASS** | 新文件仅 `import Foundation`；零设备/窗口/AppKit 类型；无 MTDevice* 符号 |
| 不 commit/push/tag | **PASS** | 无 git 操作 |

## Deviations（范围披露）

1. **start() 同步发两次状态通知**（.checking → startupState）：同步重入回调可能观察到过期通知（如回调内读 state 仍为 .checking）；消费方以 `state` 属性为权威，通知仅作提示。与识别器"事件同步返回、无待派发队列"语义一致。
2. **零触点 moved 关闭 provider 会话**（结束证据）：其后同会话 ended 视为契约违反（`testContractMovedAfterEndEvidenceRejected`）；识别器同样把零触点 moved 当结束证据，语义对齐。
3. **push 只受 isStarted 门控，不受 state 门控**：suspended 期间 push 仍入队/交付，由消费方（识别器）丢弃——识别器在 .suspended/.disabled 下 process 返回 []（P13 语义），provider 不重复实现门控。
4. **playback 时间推进依赖 `PinchClockAdvancing`**（仅测试用途协议）：生产时钟（PinchSystemClock）不实现该协议，playback 在非测试时钟下只打戳不推进（文档化）。
5. **generation 在 stop 与 restart 都递增**：与 PinchRecognizer 语义一致（stop/restart 均 generation+1）；任务只要求 restart 生成新 generation，stop 递增是同一机制的保守超集。
6. **provider 级 maxContactCount=16**（默认）：识别器 maxContactCount=8 更严，provider 上限仅防畸形帧，识别器仍会拒绝 >8。

## Unresolved questions

1. 真实 MultitouchSupport 后端（dlopen/dlsym/MTDevice*）未实现——需 T-G-P0 风险清单用户确认后独立子任务（任务包明确禁止本轮实现）。
2. 状态模型与 T-G-P3 入口状态展示的最终映射（Off/Checking/Ready/NoDevice/Unavailable/PermissionNotConfirmed/Suspended → UI 文案/降级）由 T-G-P3 实现；本任务只定义通知机制。
3. 异步交付的线程模型：Mock 的 .asynchronous 用 DispatchQueue 模拟迟到回调；真实后端回调线程与主线程消费的 generation 校验由 T-G-P4 接线时落实（ADR-013 §5：teardown 期间 late callback 与已排队主线程事件同时失效）。
4. 过载丢帧策略（只丢 moved、保留 began/ended/cancelled）为 provider 层默认；真实后端若需不同积压策略（如取消整会话）由后端子任务定案。

## Reviewer focus

1. 锁序：`deliver()` 锁内只读状态+计数，onFrame/onStateChange 均在锁外调用；回调内重入 push/stop/restart 不死锁（P15 测试证明）。
2. 幂等语义：start/start、stop/stop、start-stop-start、restart 的 generation 语义与识别器一致。
3. 缓冲有界：async 队列 maxQueueSize 过载只丢 moved、保留 began/ended/cancelled（不丢重新武装条件，ADR-013 §5）。
4. 帧契约强制：began→moved*→ended/cancelled 在 provider 层 checkContract 强制 + 测试断言；非法帧 validate 拒绝。
5. 隐私红线：新文件无 `addGlobalMonitorForEvents`/`CGEvent.tapCreate`/`AXIsProcessTrusted`/`IOHID`/`LaunchBetter`/`Buho`/`frontmostApplication`；无触点坐标持久化（仅中性 enum/计数）；注释仅出现"禁止墙钟 Date()"禁令文字。
6. 集成接线：provider 帧 → 识别器完整识别（含 token.generation 校验、释放 re-arm、设备隔离、stop/suspended 丢弃）。
7. 状态通知与 T-G-P3 对齐：TouchProviderState 七态与 ADR-013 §7 状态模型一致（Enabled≠Ready 由 T-G-P3 表达）。

## Memory candidates（供 Main 门控）

1. **锁外派发模式**：provider 回调（onFrame/onStateChange）必须在锁外调用；锁内只做状态读取与计数——回调内重入 stop/restart/push 是合法场景（P15 测试），锁内派发会死锁。
2. **过载丢帧策略**：有界缓冲只丢 moved、保留 began/ended/cancelled——"只留最新帧"会丢重新武装条件（ADR-013 §5 明确禁止）。
3. **generation 双递增**：stop 与 restart 都递增 generation（与识别器一致）；消费方以 generation 校验丢弃旧事件，teardown 期间 late callback 与排队事件同时失效。
4. **provider 不重复实现识别器门控**：suspended/disabled 丢弃是消费方（识别器）职责；provider 只做 isStarted 门控 + 帧契约强制，避免双层语义漂移。
