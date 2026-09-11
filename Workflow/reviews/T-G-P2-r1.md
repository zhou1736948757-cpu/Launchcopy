# T-G-P2 Review r1 — 平台 provider（Mock 先行）

- **Reviewer**: 独立评审（只读实现；未编辑任何实现/测试文件；未 commit/push/tag）
- **Date**: 2026-09-05
- **Task packet**: `Workflow/tasks/T-G-P2.md`
- **Worker result**: `Workflow/results/T-G-P2.md`
- **Review basis**: `AGENTS.md`、`MEMORY.md`、`Workflow/PLAN.md`（§4 冻结树 / §5 写集 / §7 任务表 / §9 不变量 #6/#7/#9 / §10 全局验收 / §11 隐私红线）、`Docs/PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT.md`（§20.2 回调与锁序 / §20.3 / §23.1 P13-P15 表）、实际实现 `Sources/PagingPrototypeApp/TouchProvider.swift`（75 行）+ `Sources/PagingPrototypeApp/MockTouchProvider.swift`（258 行）+ 三个新测试文件、消费方参考 `Sources/PagingPrototypeApp/PinchRecognizer.swift`（629 行，T-G-P1 已 PASS）、`git status`/文件 mtime、实测命令输出
- **Access declaration**: 本 Reviewer **未读取** `LaunchBetter/`、`BuhoReverseNotes/` 源码（遵守评审禁令）；未读取白名单外参考文件；未运行任何采集/设备访问代码
- **Verdict**: **PASS**（0 BLOCKER / 0 MAJOR / 1 MINOR / 0 QUESTION / 7 INFO）

---

## 0. 结论摘要

T-G-P2 交付物满足任务包全部验收标准与 §20.2 锁序/缓冲要求、§23.1 P13/P14/P15（provider 域）。独立重跑 `swift test --filter TouchProvider` → **38 tests / 0 failures**（Lifecycle 14 + Mock 17 + Integration 7），全量 `swift test` → **1285 tests / 0 failures**（基线 1247 + 本任务 38），均 exit 0，与 worker 声明完全一致。写集合规（仅 5 个新文件，冻结树/AppDelegate/AppMain/AppArguments/KeyboardFocusController/Package.swift 未触碰）；隐私红线静态扫描零命中（仅注释中的「禁止墙钟 Date()」禁令文字，已披露）；无 AppKit、无真实设备访问、无 dlopen/dlsym/MTDevice*、无 commit/push/tag。6 项偏差全部在代码中核实属实。发现 1 MINOR（异步过载拒绝路径下契约状态残留，mock 域、保守方向）与 7 INFO，均不构成验收阻断。

---

## 1. 逐验收标准结果（任务包「验收」节）

| 验收标准 | 证据 | 结果 |
|---|---|---|
| Mock 生命周期测试 executed > 0 且 0 failures | `swift test --filter TouchProvider` → **38 tests, 0 failures**（14+17+7），exit 0（见 §5） | ✅ |
| 无真实设备访问 | 两个源文件仅 `import Foundation`（TouchProvider.swift L17、MockTouchProvider.swift L14）；零 AppKit/设备/窗口类型；测试全部使用合成匿名触点夹具（`squareContacts`，复用 T-G-P1 夹具模式） | ✅ |
| 无 dlopen/dlsym | 红线扫描 `dlopen|dlsym|MTDevice` 五文件零命中（见 §6） | ✅ |
| 不 commit/push/tag | 仓库零提交（`git log` → `your current branch 'main' does not have any commits yet`）；git status 全部 untracked 无 staged；Reviewer 未执行任何 git 写操作 | ✅ |

## 2. Objective 逐项验证

| Objective 要求 | 实现位置（已逐行核对） | 结果 |
|---|---|---|
| TouchProvider protocol：设备生命周期 start/stop/restart | `TouchProvider.swift` L57-75（`start()`/`stop()`/`restart()` + `state`/`onStateChange`/`onFrame`/`generation`/`isStarted`）；幂等语义文档化 L44-46（start 已启动=no-op、stop 未启动=no-op、restart 新 generation） | ✅ |
| 有效触点帧 device-scoped | `PinchFrame.deviceID`（TouchProvider.swift L49-50）；`MockTouchProvider` `openSessions: Set<PinchDeviceID>`（L58）按设备隔离；`checkContract` L235-250 按 deviceID 判定会话 | ✅ |
| 值转换 | 帧模型复用 `PinchFrame`/`PinchContact`/`PinchPoint`（PinchRecognizer.swift L54-96）；provider 不做坐标变换（无持久化） | ✅ |
| 状态通知 Off/Checking/Ready/NoDevice/Unavailable/PermissionNotConfirmed/Suspended | `TouchProviderState` 七态（TouchProvider.swift L22-30，`suspended(reason: PinchSuspensionReason)` 与识别器对齐）；`testStateNotificationSequence` 断言全序列 [.checking,.ready,.noDevice,.unavailable,.permissionNotConfirmed,.suspended(.sleep),.off] | ✅ |
| Mock provider：合成匿名触点帧注入（可编程序列） | `MockFrameStep`（L19-30）+ `playback(_:deviceID:)`（L201-208，按 timeStep 推进共享时钟）+ 命令式 `push`（L155-197） | ✅ |
| 生命周期测试 start/start、stop/stop、start-stop-start | `testP14StartStartIdempotent` / `testP14StopStopIdempotent` / `testP14StartStopStartSequence`（LifecycleTests） | ✅ |
| 退出时异步回调 | `testP13StopDropsQueuedLateCallbacks`（stop 清队列 → drain 零交付）/ `testP13StopDropsFramesPushedAfterStop`（push 拒绝）/ `testP13StopBumpsGenerationInvalidatingOldEvents` / `testP13RestartClearsQueueAndBumpsGeneration` | ✅ |
| 同步重入假后端无死锁 | `testP15StopInsideFrameCallbackNoDeadlock` / `testP15RestartInsideFrameCallbackNoDeadlock` / `testP15StopInsideStateChangeCallbackNoDeadlock` | ✅ |
| §20.2 锁序（回调锁外派发、缓冲有界、保留 begin/end/cancel） | 见 §3 | ✅ |
| 真实 MultitouchSupport 后端不实现 | 五文件零 MTDevice*/dlopen/dlsym 符号；worker 未决问题 1 明确延后（T-G-P0 风险清单确认后独立子任务） | ✅ |

## 3. §20.2 锁序/缓冲/事件保留验证

| §20.2 要求 | 实现位置 | 测试 | 结果 |
|---|---|---|---|
| user closure 在锁外调用 | `deliver()` L252-257（锁内仅 `deliveredFrameCount += 1`，`onFrame` 锁外）；`start()` L103 / `stop()` L121 / `restart()` L140 / `simulateStateChange` L149 全部锁外派发 | `testSection20_2CallbacksDispatchedOutsideLock`（帧回调内重入 push 成功 = 锁已释放）、`testStateChangeNotificationOutsideLock`（状态回调内 restart 成功） | ✅ |
| 同步重入不死锁（回调内 stop/restart/push） | 锁外派发 + 窄锁（NSLock L42 只保护状态/缓冲） | `testP15*` ×3 + `testSection20_2CallbacksDispatchedOutsideLock` | ✅ |
| 缓冲必须有界 | `maxQueueSize`（init 默认 64，L69；`max(1, ...)` 钳制 L73）；async 模式 `queue.count >= maxQueueSize` 过载处理 L177-187 | `testSection20_2BoundedBufferDropsMovedKeepsBeginEndCancel`（maxQueueSize=2 → pending 2） | ✅ |
| 保留 begin/end/cancel，不「只留最新帧」 | 过载优先丢 moved（L179-181 `firstIndex(where: { $0.phase == .moved })`），无 moved 可丢时拒绝新帧（L182-186）；began/ended/cancelled 永不被挤出 | 同上（droppedMovedFrameCount 3、rejectedFrameCount 0、交付 [.began,.ended]） | ✅ |
| 过载丢帧保守（不凭不完整轨迹 Show） | 丢 moved 是压缩而非取消；关键帧保留；识别器侧另有 dataExpiry 保守重置（PinchRecognizer.swift L374-383） | `testSection20_2AsyncDrainDeliversInOrder`（[.began,.moved,.ended] 按序） | ✅ |
| teardown 时 late callback 与排队事件同时失效 | `stop()` L114-116（generation+1 + queue.removeAll + openSessions.removeAll）；消费方 generation 校验（识别器 L352-353 disabled/suspended → []） | `testP13StopDropsQueuedLateCallbacks`、`testIntegrationStopDropsFramesBeforeRecognizer` | ✅ |
| 主线程消费时验证 generation/功能开关/进程状态 | provider 暴露 `generation`（L51/L64）；识别器 process 对 disabled/suspended 返回 []（L352-353）；集成测试断言 token.generation == r.generation | `testIntegrationSynchronousPushFullPinch` | ✅ |

## 4. §23.1 P13/P14/P15 验证（provider 域）

> 注：任务包（Chief 编写）将 P13/P14 编号与 Prompt §23.1 表互换（包内 P13=幂等、P14=迟到回调丢弃；Prompt P13=迟到回调丢弃、P14=start/stop 重入）。Worker 按任务包编号命名测试；两组语义均有完整覆盖（见 INFO-7）。

| 编号（任务包语义） | 实现位置 | 测试 | 结果 |
|---|---|---|---|
| P13 start/start、stop/stop、start-stop-start 幂等 | `start()` L89-92（`guard !isStarted` no-op）、`stop()` L109-112（`guard isStarted` no-op）、`restart()` L124-141 | `testP14StartStartIdempotent`（generation/state/stateChangeCount 全不变）、`testP14StopStopIdempotent`、`testP14StartStopStartSequence`（stop 后重新 start 可正常交付） | ✅ |
| P14 退出时异步回调丢弃 + generation 校验 | `stop()` L114-116（generation+1、清队列、清会话）；`push` L158-161（未启动拒绝）；`drain()` L211-218（队列已清 → 零交付） | `testP13StopDropsQueuedLateCallbacks`、`testP13StopDropsFramesPushedAfterStop`、`testP13StopBumpsGenerationInvalidatingOldEvents`、`testP13RestartClearsQueueAndBumpsGeneration`、`testP14RestartGeneratesNewGenerationAndDelivers` | ✅ |
| P15 同步重入假后端注册/注销无死锁 | 锁外派发（§3）；回调内 stop/restart 合法 | `testP15StopInsideFrameCallbackNoDeadlock`、`testP15RestartInsideFrameCallbackNoDeadlock`、`testP15StopInsideStateChangeCallbackNoDeadlock`（均完成、无死锁、最终状态正确） | ✅ |

## 5. 测试证据（实测命令与输出）

**命令 1**：`swift test --filter TouchProvider`
**输出**（节选）：
```
Test Suite 'TouchProviderLifecycleTests' passed at 2026-09-05 19:41:01.122.
	 Executed 14 tests, with 0 failures (0 unexpected) in 0.002 (0.003) seconds
Test Suite 'PagingPrototypePackageTests.xctest' passed at 2026-09-05 19:41:01.122.
	 Executed 38 tests, with 0 failures (0 unexpected) in 0.008 (0.011) seconds
Test Suite 'Selected tests' passed at 2026-09-05 19:41:01.122.
	 Executed 38 tests, with 0 failures (0 unexpected) in 0.008 (0.012) seconds
```
exit code 0。**38/0 与 worker 声明一致**（Lifecycle 14 + Mock 17 + Integration 7，逐套件核对通过）。

**命令 2**：`swift test`（全量，独立重跑）
**输出**（节选）：
```
	 Executed 1285 tests, with 0 failures (0 unexpected) in 22.824 (22.956) seconds
```
exit code 0。**1285/0 与 worker 声明一致**（基线 1247 + 本任务 38）。

**测试清单**：

- `TouchProviderLifecycleTests.swift`（14）：testP13StopDropsQueuedLateCallbacks、testP13StopDropsFramesPushedAfterStop、testP13StopBumpsGenerationInvalidatingOldEvents、testP13RestartClearsQueueAndBumpsGeneration、testP14StartStartIdempotent、testP14StopStopIdempotent、testP14StartStopStartSequence、testP14RestartGeneratesNewGenerationAndDelivers、testP15StopInsideFrameCallbackNoDeadlock、testP15RestartInsideFrameCallbackNoDeadlock、testP15StopInsideStateChangeCallbackNoDeadlock、testSection20_2CallbacksDispatchedOutsideLock、testSection20_2BoundedBufferDropsMovedKeepsBeginEndCancel、testSection20_2AsyncDrainDeliversInOrder
- `MockTouchProviderTests.swift`（17）：testContractBeganMidSessionRejected、testContractMovedWithoutBeganRejected、testContractEndedWithoutBeganRejected、testContractCancelledWithoutBeganRejected、testContractZeroContactMovedClosesSession、testContractEndedClosesSession、testContractCancelledClosesSession、testContractMovedAfterEndEvidenceRejected、testInvalidFramesRejected、testDeviceScopedSessionsIndependent、testDeviceScopedBeganIsPerDevice、testFramesStampedFromInjectedClock、testPlaybackPresetSequenceAdvancesTime、testPlaybackRequiresStarted、testStateNotificationSequence、testStartupStateConfigurable、testStateChangeNotificationOutsideLock
- `TouchProviderIntegrationTests.swift`（7）：testIntegrationSynchronousPushFullPinch、testIntegrationReleaseReArmsThroughProvider、testIntegrationTwoDevicesIndependentSessions、testIntegrationAsyncDrainFullPinch、testIntegrationPlaybackFullPinch、testIntegrationStopDropsFramesBeforeRecognizer、testIntegrationSuspendedFramesDroppedByRecognizer

**集成验收逐项**（provider → PinchRecognizer 完整识别）：

| 集成项 | 测试 | 结果 |
|---|---|---|
| 完整识别 + token.generation 校验 | `testIntegrationSynchronousPushFullPinch`（1 个 showRequested；`token.generation == r.generation`；`token.sessionID == r.activeSessionID`；state .fired） | ✅ |
| 释放 re-arm | `testIntegrationReleaseReArmsThroughProvider`（零触点 moved → idle → 新会话再触发，2 fires） | ✅ |
| 双设备隔离 | `testIntegrationTwoDevicesIndependentSessions`（A/B 各触发，2 fires） | ✅ |
| 异步 drain 完整识别 | `testIntegrationAsyncDrainFullPinch`（3 帧排队 → drain 后 1 fire） | ✅ |
| playback 预置序列完整识别 | `testIntegrationPlaybackFullPinch`（1 fire） | ✅ |
| stop 后帧不达识别器 | `testIntegrationStopDropsFramesBeforeRecognizer`（provider 拒绝；识别器状态保持 .candidate 不被迟到帧改变） | ✅ |
| suspended 帧由识别器丢弃 | `testIntegrationSuspendedFramesDroppedByRecognizer`（provider 放行、识别器 process 返回 []，P13 消费方语义） | ✅ |

**夹具**：`FakePinchClock`（T-G-P1 夹具）+ `extension FakePinchClock: PinchClockAdvancing`（LifecycleTests L16-18，使 playback 时间推进生效）、`squareContacts`（合成匿名触点，无真实轨迹）。

## 6. 隐私红线静态扫描（PLAN §11）

命令：`grep -nE 'addGlobalMonitorForEvents|CGEvent\.tapCreate|AXIsProcessTrusted|IOHID|LaunchBetter|Buho|frontmostApplication|dlopen|dlsym|MTDevice|NSEvent|AppKit|Date\(\)|Date\.timeIntervalSince|pointer coordinate|NSApp'` 五文件 → 仅 `TouchProvider.swift` L10/L50 命中注释中的「禁止墙钟 `Date()`」禁令文字（worker 已披露，属政策文字非代码使用）；其余四文件零命中。`import` 检查：源文件仅 `import Foundation`（TouchProvider.swift L17、MockTouchProvider.swift L14）；测试文件 `import XCTest` + `@testable import PagingPrototypeApp`。无触点坐标持久化（仅中性 enum/计数：deliveredFrameCount/rejectedFrameCount/contractViolationCount/droppedMovedFrameCount/stateChangeCount/pendingFrameCount，MockTouchProvider.swift L61-65/L78-82）。

## 7. 写集合规核查

- 仓库无基线提交（`git log`：`your current branch 'main' does not have any commits yet`），以文件 mtime 为准：
  - 5 个新文件：`TouchProvider.swift` 2026-09-05 19:33:47、`MockTouchProvider.swift` 19:33:56、`TouchProviderLifecycleTests.swift` 19:34:06、`MockTouchProviderTests.swift` 19:34:17、`TouchProviderIntegrationTests.swift` 19:34:58 — 全部落在 T-G-P2 工作窗口（19:30-19:40），且 `find Sources Tests -newermt 19:30:00 ! -newermt 19:40:00` 仅命中这 5 个文件
  - 冻结树：`Package.swift` 2026-08-28 19:42:55、`AppLaunchController.swift` 2026-08-28 20:46:54 — 未触碰 ✅；冻结目录最新文件 `Sources/AppGridUI/FolderOverlayView.swift` 2026-09-05 14:13:49（早于 T-G-P2 窗口，属先前 14:09-14:13 任务批次）✅
  - 共享文件：`AppDelegate.swift` 2026-09-05 14:09:47（早于窗口）、`AppMain.swift` 2026-08-29、`AppArguments.swift` 2026-08-30、`KeyboardFocusController.swift` 2026-08-30 — 未触碰 ✅
  - 消费方 `PinchRecognizer.swift` 2026-09-05 19:22:13（T-G-P1 窗口，早于 T-G-P2）— 未触碰 ✅
  - 19:35 之后无任何 Sources/Tests 文件被修改（无后续任务污染）
- 写范围合规：仅 5 个新文件；无真实后端、无窗口代码、无 AppDelegate/Package.swift 改动、无真实轨迹提交。

## 8. Findings

### BLOCKER
无。

### MAJOR
无。

### MINOR

**MINOR-1 [verified] 异步过载拒绝路径下契约状态残留（openSessions 提前变更）**
- 位置：`MockTouchProvider.swift` L155-192（`push(_:)`）。执行顺序为 `validate`（L163）→ `checkContract`（L168，**此处已变更 openSessions**）→ 容量检查（L177-187）。当 async 队列满且无 moved 可丢（队列全为 began/ended/cancelled 关键帧）时，新 `.began` 通过 checkContract（设备插入 openSessions）后因容量不足被拒绝（L182-186）——但 openSessions 未回滚。
- 影响：低。该设备后续合法的 `.began` 会被误判为「会话中 began」契约违反（contractViolationCount+1），直到零触点 moved 或 stop/restart 清空会话。方向保守（不会错误 Show；识别器从未收到该 began，无状态污染）；仅 mock 域、仅 async 过载极端场景（需多设备关键帧填满队列），现有测试未覆盖此路径。
- 建议：将 checkContract 的会话变更做成事务性（容量拒绝时回滚 openSessions），或把容量检查移到 checkContract 之前；补一条「过载拒绝 began 后同设备新 began 仍合法」的测试固化。非验收阻断。

### QUESTION
无。

### INFO

**INFO-1 [verified]** `ended`/`cancelled` 帧带非空触点不被 provider 拒绝（`checkContract` L245-247 只查会话存在性）。识别器对 ended/cancelled 一律按结束证据处理（PinchRecognizer.swift L386-389，忽略触点），无功能影响；真实后端应产生空触点 ended，由后端子任务定案。

**INFO-2 [verified]** `drain()`/`deliver()` 与并发 `stop()` 的竞态：drain 在锁内取帧、锁外交付（L211-218），若 stop 在取帧与交付之间执行，帧仍会交付。消费方侧防御成立（识别器 disabled → process 返回 []，L352-353），符合 §20.2「主线程消费时也要验证 generation/功能开关/进程状态」；mock 测试单线程，真实后端线程模型由 T-G-P4 落实（worker 未决问题 3）。

**INFO-3 [verified]** `simulateStateChange`（L144-150）不受 `isStarted` 门控：stop 后仍可把 state 置为非 off。属测试驱动辅助方法（文档注明），真实后端不会出现；mock 域可接受。

**INFO-4 [verified]** `PinchClockAdvancing` 协议声明在生产文件 `TouchProvider.swift` L35-37（测试用途协议入生产源码）——因 `playback()` 的 `clock as? PinchClockAdvancing` 转换（MockTouchProvider.swift L204-206）在 mock 生产代码中，协议必须对生产可见。worker 偏差 4 已披露并文档化；`FakePinchClock` 的 conformance 在测试扩展（LifecycleTests L16-18），生产 `PinchSystemClock` 不实现，playback 在非测试时钟下只打戳不推进。

**INFO-5 [verified]** mock 的 `state`/`generation`/`isStarted` 公开读取未加锁（写侧在锁内，读侧直接访问）。mock 单线程测试下无实际竞态；真实后端必须自行同步（T-G-P4 范围），协议文档已声明消费方串行消费（TouchProvider.swift L62）。

**INFO-6 [verified]** 偏差 1（start 双通知）核实：`start()` L94-101 在锁内收集 [.checking, startupState]，L103 锁外依次派发——`.checking` 回调触发时 `state` 属性已是 startupState（如 .ready），即「回调观察到过期通知」的披露准确；消费方以 `state` 属性为权威，通知仅作提示。与识别器「事件同步返回、无待派发队列」语义一致。

**INFO-7 [verified]** P13/P14 测试命名按任务包编号（与 Prompt §23.1 表互换，见 §4 注）。两组语义（幂等 + 迟到回调丢弃/generation）均有完整测试覆盖，不影响验收；建议 T-G-P4 引用时以语义而非编号为准，避免跨任务歧义。

## 9. 与 worker 结果声明的一致性（含 6 项偏差核对）

| worker 声明 | 复核结果 |
|---|---|
| 38 测试（14+17+7），`swift test --filter TouchProvider` exit 0 | ✅ 实测 38/0，exit 0 |
| 全量 `swift test` 1285/0 | ✅ 实测 1285/0，exit 0 |
| 变更文件仅 5 个新文件 | ✅ mtime 验证（19:33-19:34 窗口；冻结树/共享文件未触碰；19:35 后零改动） |
| 偏差 1：start 双通知 | ✅ L94-101/L103（见 INFO-6） |
| 偏差 2：零触点 moved 关会话 | ✅ `checkContract` L242-244（`moved` + 空触点 → remove）；与识别器结束证据语义对齐（PinchRecognizer.swift L386-389）；`testContractZeroContactMovedClosesSession`/`testContractMovedAfterEndEvidenceRejected` 固化 |
| 偏差 3：push 仅 isStarted 门控 | ✅ L158 `guard isStarted`；suspended 帧由消费方丢弃（识别器 L352-353）；`testIntegrationSuspendedFramesDroppedByRecognizer` 验证 |
| 偏差 4：playback 时间推进依赖 PinchClockAdvancing | ✅ L204-206 + 测试扩展 LifecycleTests L16-18（见 INFO-4） |
| 偏差 5：generation stop/restart 双递增 | ✅ `stop()` L114、`restart()` L128 均 `generation += 1`；与识别器一致（PinchRecognizer.swift L301/L319）；`testP13StopBumpsGenerationInvalidatingOldEvents`/`testP13RestartClearsQueueAndBumpsGeneration` 验证 |
| 偏差 6：maxContactCount=16 | ✅ init 默认 L70；识别器 maxContactCount=8 更严（PinchParameters L132），provider 上限仅防畸形帧；`testInvalidFramesRejected` 用 17 触点验证 |
| 未决项（真实后端、T-G-P3 状态映射、T-G-P4 线程模型、过载策略定案） | ✅ 均属实且不属本任务验收范围（任务包明确禁止真实后端） |

## 10. 置信度

- **高**：验收标准、§20.2 七项、P13/P14/P15、集成七项全部基于逐行代码核对 + 实测命令输出（38/0、1285/0）+ 静态扫描 + mtime 证据，非仅依赖 worker 声明。
- **中**：MINOR-1 为代码顺序推演（未写复现测试，属只读评审边界）；INFO-2 竞态为并发场景推断（mock 测试单线程）。
- 未执行：真实触控板/设备验证（T-G-P6 范围）、真实后端（T-G-P0 批准后子任务）、T-G-P3 状态展示、T-G-P4 接线。

---

**Verdict: PASS**（0 BLOCKER / 0 MAJOR / 1 MINOR / 0 QUESTION / 7 INFO）— 满足 PLAN §10 INDEPENDENT_REVIEW = PASS（0 BLOCKER/0 MAJOR）与 FOUR_FINGER_PROVIDER_MOCK_TESTS = PASS（P13/P14/P15）门槛。
