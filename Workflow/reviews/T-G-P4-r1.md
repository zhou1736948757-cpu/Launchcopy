# T-G-P4 Review r1 — 协调器接线（四指入口 → coordinator）

- **Reviewer**: 独立评审（只读实现；未编辑任何实现/测试文件；未 commit/push/tag）
- **Date**: 2026-09-05
- **Task packet**: `Workflow/tasks/T-G-P4.md`
- **Worker result**: `Workflow/results/T-G-P4.md`
- **Review basis**: `AGENTS.md`、`Workflow/PLAN.md`（§5 写集 / §7 任务表 / §9 不变量 #2/#3/#6/#7 / §10 全局验收 / §11 隐私红线）、`Workflow/decisions/2026-09-05-pending-questions-1g.md`（Q-1）、`Workflow/reviews/T-G-P3-r1.md`（QUESTION-1/QUESTION-2）、实际实现 3 文件（`Sources/PagingPrototypeApp/LauncherPresentationState.swift`、`Sources/PagingPrototypeApp/FourFingerActivationCoordinator.swift`、`Tests/PagingUITests/FourFingerActivationCoordinatorTests.swift`）、参考 `Sources/PagingPrototypeApp/LauncherPresentationCoordinator.swift`、`Sources/PagingPrototypeApp/PinchRecognizer.swift`、`Sources/PagingPrototypeApp/FourFingerActivationState.swift`、`git status`/文件 mtime、实测命令输出
- **Access declaration**: 本 Reviewer **未读取** `LaunchBetter/`、`BuhoReverseNotes/` 源码（遵守评审禁令）；未运行任何采集/设备访问代码；仅执行 `swift test`（一次过滤 + 两次全量）与只读 grep/stat/find；未修改任何产品文件
- **Verdict**: **PASS**（0 BLOCKER / 0 MAJOR / 1 MINOR / 2 QUESTION / 5 INFO）

---

## 0. 结论摘要

T-G-P4 交付物满足任务包全部验收标准：`.fourFingerPinch` case 加入（allCases == 7 顺序固化；`dismissReason(for:)` default 中性回退；仓库无其他穷尽 switch 破坏）；接线唯一出口 `presentation.show(source: .fourFingerPinch, targetScreen:)`（FourFingerActivationCoordinator.swift L280）且 targetScreen 注入；四指只发 show 永不 hide/quit（组件无 hide/toggle/quit 方法；visible/terminating 状态行为符合 §21.1）；去重（`lastConsumedToken` 全等 generation+sessionID）；**Q-1 闭环**（suspend() 清队列 + 派发时挂起拒绝双机制，`testQueuedShowBeforeSuspendNotReplayedAfterResume` 覆盖全链）；**QUESTION-1 闭环**（`handleProviderState(.ready)` guard `activation.state != .ready` 幂等，失败态恢复路径合法）；**QUESTION-2 确认**（(enabled:true, state:.off) → .disabled 文档化 + 测试固化，含 (false,.ready)/(true,.ready) 对照）；输入交接（handoffToken 派发时设置、识别器回 idle 清除；同会话/跨设备去重测试）。独立重跑 `swift test --filter FourFingerActivationCoordinatorTests` → **20 tests / 0 failures / exit 0**（与 worker 声明一致）；全量 `swift test` → **1362 tests / 0 failures / exit 0**（基线 1342 + 本任务 20，与 worker 声明一致）。写集合规（仅 3 文件在任务窗口，冻结树/AppDelegate/AppMain/AppArguments/KeyboardFocusController/Package.swift/AppLaunchController.swift 未触碰）；隐私红线静态扫描零命中（仅 2 处既有政策文字注释）；无 AppKit、无墙钟依赖、无 commit/push/tag。7 项偏差全部在代码中核实。发现 1 MINOR / 2 QUESTION / 5 INFO，均不构成验收阻断。

---

## 1. 逐验收标准结果（任务包「验收」节）

| 验收标准 | 证据 | 结果 |
|---|---|---|
| 接线测试 executed > 0 且 0 failures | 实测 `swift test --filter FourFingerActivationCoordinatorTests` → 20/0，exit 0（见 §7） | ✅ |
| T-1G-A 既有测试回归 0 failures | 实测全量 `swift test` → 1362/0，exit 0（含 LauncherPresentationCoordinatorTests 等既有套件；`LauncherActivationSource` 无其他穷尽 switch 需适配，见 §8.9） | ✅ |
| Q-1 场景有测试（suspend 后旧事件不重放） | `testQueuedShowBeforeSuspendNotReplayedAfterResume`（FourFingerActivationCoordinatorTests.swift L115-135）+ `testShowEventWhileSuspendedRejected`（L137-146） | ✅ |
| 重复 ready 幂等有测试 | `testRepeatedReadyIsIdempotent`（L150-161）+ `testRepeatedReadyFromFailureStatesRecovers`（L163-176） | ✅ |
| 不 commit/push/tag | 仓库无基线提交（`git log` → `your current branch 'main' does not have any commits yet`）；git status 全部 untracked 无 staged；Reviewer 未执行任何 git 写操作 | ✅ |

## 2. Objective 逐项验证

| Objective 要求 | 实现位置（已逐行核对） | 结果 |
|---|---|---|
| 接线：`PinchEvent.showRequested(token:)` → `coordinator.show(source: .fourFingerPinch, targetScreen:)`；四指只发 show 永不反向 hide（不变量 3） | `dispatchShow` 唯一出口 `presentation.show(source: .fourFingerPinch, targetScreen: targetScreen)`（FourFingerActivationCoordinator.swift L280）；组件无 hide/toggle/quit 方法（grep 仅注释命中 L9/L239）；`testShowRequestedPresentsWithFourFingerPinchSource`（L60-74）、`testFourFingerNeverHidesOrQuits`（L247-263）、`testShowWhileVisibleIsNoop`（L265-280）、`testShowWhileTerminatingRejected`（L282-296） | ✅ |
| `.fourFingerPinch` case 加入（不变量 2；CaseIterable 与穷尽 switch 同步适配，T-1G-A 回归） | LauncherPresentationState.swift L30（hotCorner 与 testHarness 之间，注释 L29）；`testLauncherActivationSourceIncludesFourFingerPinch`（L377-383：allCases == 7，顺序 [initialLaunch, dockReopen, statusItem, globalShortcut, hotCorner, fourFingerPinch, testHarness]）；`dismissReason(for:)`（LauncherPresentationCoordinator.swift L197-206）default → .statusItem 中性回退；仓库 grep 确认无其他穷尽 switch | ✅ |
| 去重与 generation：同一 PinchEventToken 只一次 show；识别器 generation 与 coordinator request generation 各自独立 | `lastConsumedToken` 全等比较（L264，PinchEventToken Equatable = generation+sessionID）；generation 校验 `token.generation == recognizer.generation`（L258）；`testSameTokenDeliveredTwiceProducesOneShow`（L87-97）、`testStaleGenerationEventDropped`（L101-111） | ✅ |
| **Q-1 处理**：suspend 前排队事件 suspend 后不重放 | 双机制：①`suspend()` 清空 `pendingShowTokens`（L144，注释 L139「suspend 不递增识别器 generation，只能靠清队列防重放」）；②`dispatchShow` 挂起检查（L248-256，activation/presentation 任一 suspended → 拒绝）；`testQueuedShowBeforeSuspendNotReplayedAfterResume` 全链（排队→suspend→flush 空→resume→flush 空→showCount 0→新手势可触发） | ✅ |
| **QUESTION-1 处理**：provider 重复 ready 幂等接受（不崩溃、不重复启动） | `handleProviderState(.ready)` guard `activation.state != .ready`（L216）→ 拦截 (.ready,.backendReady) 非法转换；`testRepeatedReadyIsIdempotent`（generation/isEnabled/fireCount 不变）、`testRepeatedReadyFromFailureStatesRecovers`（noDevice/unavailable/permissionNotConfirmed → ready 恢复，状态机合法表 FourFingerActivationState.swift L100-119） | ✅ |
| **QUESTION-2 确认**：displayKind (enabled:true, state:.off) 组合语义 | 接线层 `displayStatus`（L102-104）= `FourFingerActivationStatus(enabled: userEnabled, state: activation.state)`；displayKind state .off → .disabled 不区分 enabled（FourFingerActivationState.swift L174-175）；`testDisplayKindEnabledOffCombinationIsDisabled`（L180-198：(true,.off)→.disabled、isReady false；(false,.ready)→.disabled；(true,.ready)→.ready 对照） | ✅ |
| 输入交接（§21.1 会话结束优先）：fired 后交接期间新 show 去重；会话结束（全指释放）优先 | `handoffToken` 派发时设置（L276-278）、`process()` 观察 latched→idle 转换时清除（L164-169）；`testHandoffSuppressesNewShowUntilSessionEnd`（L202-224）、`testSecondDeviceShowDuringHandoffDropped`（L226-243：A 释放 B 锁存 → 交接保持；B 释放 → 清除） | ✅ |
| 接线组件纯逻辑（可注入 clock/recognizer/coordinator），不接 AppDelegate、不碰窗口行为代码 | 标准 init（L55-74）注入 clock/targetScreen/parameters/userEnabled；全注入 init（L77-97）注入 recognizer/presentation/activation；无 AppDelegate/窗口引用（红线扫描零命中） | ✅ |

## 3. Q-1 闭环验证（决策文件 Q-1 → 本任务处理）

| 要求 | 实现位置 | 测试 | 结果 |
|---|---|---|---|
| suspend 前排队事件 suspend 后不重放（suspend 不 bump generation，清队列是唯一可靠屏障） | `suspend()` L144 `pendingShowTokens.removeAll()`（识别器 suspend L324-329 确认不递增 generation；stop L301/restart L319 才递增） | `testQueuedShowBeforeSuspendNotReplayedAfterResume`（L115-135） | ✅ |
| 挂起期间到达的 show 拒绝 | `dispatchShow` L248-256（activationSuspended \|\| presentationSuspended → droppedSuspendedEventCount+1、.none） | `testShowEventWhileSuspendedRejected`（L137-146） | ✅ |
| 恢复后新手势可正常触发（generation 未变但队列已清） | resume() 后队列为空；新 token 通过 generation 校验 | 同测试 L131-134（start: 2.0 新手势 → [.present]） | ✅ |

**残余缺口（MINOR-1）**：`resume()`（L151-155）不清 `pendingShowTokens`——挂起期间经 `handlePinchEvent` 外部路径注入的事件若 flush 延迟到 resume 之后，会通过挂起检查被派发。识别器路径无此问题（`recognizer.process` 在 .suspended 返回 []，L352-353，生产路径不会产生挂起期间事件）；仅「外部注入路径 + 延迟 flush」组合可达。Q-1 主要求（suspend 前排队事件不重放）已满足。

## 4. QUESTION-1 闭环验证（T-G-P3-r1 QUESTION-1 → 本任务处理）

| 要求 | 实现位置 | 测试 | 结果 |
|---|---|---|---|
| 接线层幂等接受重复 ready（(.ready,.backendReady) 状态机非法 → 接线层拦截） | `handleProviderState(.ready)` L216 `guard activation.state != .ready else { return }`；apply(.backendReady) 仅非 ready 时执行 | `testRepeatedReadyIsIdempotent`（L150-161） | ✅ |
| 不崩溃、不重复启动服务 | 重复 ready 不触碰识别器（generation/isEnabled/fireCount 断言不变）；识别器生命周期由 start/stop/restart 显式驱动（偏差 4） | 同测试 | ✅ |
| 失败态恢复路径 | noDevice/unavailable/permissionNotConfirmed → backendReady 合法（状态机 L100-119） | `testRepeatedReadyFromFailureStatesRecovers`（L163-176） | ✅ |
| 无合法转换的 provider 报告安全忽略 | off+checking / off+ready → apply 返回 false 状态不变（状态机 default nil） | `testProviderStateMapping`（L300-324） | ✅ |

## 5. QUESTION-2 确认（T-G-P3-r1 QUESTION-2 → 本任务文档化 + 测试）

| 组合 | 期望 | 实现 | 测试断言 | 结果 |
|---|---|---|---|---|
| (enabled: true, state: .off) | .disabled（后端 off = 无活动，事实展示） | displayKind L174-175（state .off → .disabled 不区分 enabled） | `testDisplayKindEnabledOffCombinationIsDisabled` L185-187 | ✅ |
| (enabled: false, state: .ready) | .disabled | displayKind L178-179 | 同测试 L192-193 | ✅ |
| (enabled: true, state: .ready) | .ready | displayKind L178-179 | 同测试 L196-197 | ✅ |
| isReady 语义 | enabled && state == .ready（不变） | FourFingerActivationState.swift L167-169 | 同测试 isReady 断言 | ✅ |

## 6. 输入交接验证（§21.1 会话结束优先）

| 语义 | 实现位置 | 测试 | 结果 |
|---|---|---|---|
| handoffToken 在 show 派发（消费）时设置 | `dispatchShow` L276-278（if handoffToken == nil { handoffToken = token }） | `testHandoffSuppressesNewShowUntilSessionEnd` L209 | ✅ |
| 交接期间新 show 去重（不同 token） | `dispatchShow` L270-274（handoff != token → droppedHandoffEventCount+1、.none） | 同测试 L211-214 | ✅ |
| 会话结束（全指释放）优先清除 | `process()` L164-169（wasLatched && recognizer.state == .idle → handoffToken = nil） | 同测试 L216-217 | ✅ |
| 跨设备：全部会话结束才清除 | 识别器聚合状态（refreshAggregateState L585-605：任一设备会话存在 → 非 idle） | `testSecondDeviceShowDuringHandoffDropped`（L226-243：A 释放 B 锁存 → 保持；B 释放 → 清除） | ✅ |
| 同 token 重派发不被 handoff 误伤 | 校验顺序 dedup（L264）先于 handoff（L270） | `testSameTokenDeliveredTwiceProducesOneShow`（droppedDuplicateEventCount 1 而非 droppedHandoffEventCount） | ✅ |

## 7. 测试证据（实测命令与输出）

**命令 1**：`swift test --filter FourFingerActivationCoordinatorTests`（workdir = /Users/mac/Projects/Launch_Copy/PagingPrototype）
**输出**（节选）：
```
Test Suite 'FourFingerActivationCoordinatorTests' passed at 2026-09-05 20:01:55.598.
	 Executed 20 tests, with 0 failures (0 unexpected) in 0.005 (0.006) seconds
Test Suite 'PagingPrototypePackageTests.xctest' passed at 2026-09-05 20:01:55.598.
	 Executed 20 tests, with 0 failures (0 unexpected) in 0.005 (0.006) seconds
Test Suite 'Selected tests' passed at 2026-09-05 20:01:55.598.
	 Executed 20 tests, with 0 failures (0 unexpected) in 0.005 (0.007) seconds
```
exit code 0。**20/0 与 worker 声明一致**（逐方法计数核对：测试文件 20 个 `func test*`，L60-L383）。

**命令 2**：`swift test`（全量，独立重跑两次）
**输出**（节选，第二次重跑完整捕获）：
```
Test Suite 'All tests' passed at 2026-09-05 20:0X:XX.XXX.
	 Executed 1362 tests, with 0 failures (0 unexpected) in 17.408 (17.505) seconds
```
exit code 0。**1362/0 与 worker 声明一致**（基线 1342 + 本任务 20）。

**构建新鲜度**：测试输出中的测试名与当前源文件一一对应（如 `testQueuedShowBeforeSuspendNotReplayedAfterResume`、`testRepeatedReadyIsIdempotent`、`testLauncherActivationSourceIncludesFourFingerPinch`），证明编译的是当前源码而非旧 `.build` 产物。

## 8. 隐私红线静态扫描（PLAN §11）

命令：`grep -nE 'addGlobalMonitorForEvents|CGEvent\.tapCreate|AXIsProcessTrusted|IOHID|LaunchBetter|Buho|frontmostApplication|NSEvent|NSApp|AppKit|dlopen|dlsym|MTDevice|Date\(\)|Date\.timeIntervalSince|pointer coordinate|CGEvent|NSEvent\.mouseLocation|private API|selector'` 三文件 → 仅 2 处命中，均为 `LauncherPresentationState.swift` **既有**政策文字注释（L8「纯 Foundation，无 AppKit。全部类型为中性 enum/值」、L71「本模块纯逻辑，不触碰 AppKit」——T-G-P3 评审已接受同类注释）；`FourFingerActivationCoordinator.swift` 与测试文件**零命中**。`import` 检查：源文件仅 `import Foundation`（LauncherPresentationState.swift L11、FourFingerActivationCoordinator.swift L20）；测试文件 `import XCTest`（L14）+ `@testable import PagingPrototypeApp`（L15）。墙钟依赖检查：`Date\(\)|Date\.|timeIntervalSince|CACurrentMediaTime|ProcessInfo|wall` 两新文件零命中（grep exit 1）。无触点坐标/设备序列号/时间戳原始值记录（仅中性计数 7 项）。

## 9. 写集合规核查

- 仓库无基线提交（`git log`：`your current branch 'main' does not have any commits yet`），以文件 mtime 为准：
  - 3 个变更文件：`LauncherPresentationState.swift` 19:59:13、`FourFingerActivationCoordinator.swift` 19:59:43、`FourFingerActivationCoordinatorTests.swift` 19:59:33 — 全部落在 T-G-P4 工作窗口（19:55 后），且 `find Sources Tests -newermt '2026-09-05 19:55:00'` 仅命中这 3 文件
  - 冻结树：`Package.swift` 2026-08-28 19:42:55、`AppLaunchController.swift` 2026-08-28 20:46:54；冻结目录（PagingCore/PagingTelemetry/PagingUI/AppCatalogCore/MacAppCatalog/AppIconPipeline/AppGridUI）`find -newermt` 零命中 ✅
  - 共享文件：`AppDelegate.swift` 2026-09-05 14:09:47、`AppMain.swift` 2026-08-29 12:33:36、`AppArguments.swift` 2026-08-30 15:49:20、`KeyboardFocusController.swift` 2026-08-30 20:20:09 — 均早于窗口，未触碰 ✅
  - 既有相关文件：`LauncherPresentationCoordinator.swift`、`PinchRecognizer.swift`、`FourFingerActivationState.swift` 及测试夹具文件（`PinchRecognizerTests.swift` 19:22:38 等）均早于窗口，未触碰 ✅
  - 窗口内其他改动仅 `Workflow/` 文件（events.jsonl、heartbeats.json、results/T-G-P4.md、STATE.json、watchdog.json）— 属 PLAN §5 允许写集 ✅
- 写范围合规：仅 1 个既有文件加 case + 2 个新文件；无 AppDelegate 接线、无窗口代码、无 Package.swift 改动、无 git 操作。

## 10. Findings

### BLOCKER
无。

### MAJOR
无。

### MINOR

**MINOR-1 [verified] `resume()` 不清 `pendingShowTokens`：挂起期间外部注入的事件在「延迟 flush」下可于 resume 后被派发（Q-1 主屏障完好；仅外部路径可达）**
- 位置：`FourFingerActivationCoordinator.swift:151-155`（`resume()` 仅转发 recognizer/activation/presentation，不清队列）。
- 机制：`suspend()`（L144）清空队列 → suspend 前排队事件已消除（Q-1 主屏障 ✅）；但挂起**期间**经 `handlePinchEvent`（L180-184）注入的事件会入队，`dispatchShow` 的挂起拒绝（L248-256）只在 flush 仍处于挂起期时生效——若接线层把 flush 延迟到 `resume()` 之后，事件通过挂起检查被派发（resume 后 activation=.checking、presentation=.hidden，均非 suspended）。
- 可达性：识别器路径无此问题（`PinchRecognizer.process` 在 .suspended 返回 []，PinchRecognizer.swift L352-353，生产路径不会产生挂起期间事件）；仅「外部注入路径 + 延迟 flush」组合可达。worker 偏差 2 披露「挂起期间到达的事件在派发时被拒」对「flush 发生在挂起期间」的前提未显式说明（披露精度问题，与代码缺口同根）。
- 建议：`resume()` 同步清 `pendingShowTokens`（与 suspend/stop/restart 一致），或在偏差 2 中显式声明「外部源不得跨 suspend 保留事件」依赖接线层在挂起期间 flush 的契约。非验收阻断（Q-1 验收项「suspend 前排队事件不重放」已满足）。

### QUESTION

**QUESTION-1 T-1G-E 接线层 flush 时机契约：挂起期间到达事件的拒绝依赖「flush 在挂起期间执行」**
- 位置：`FourFingerActivationCoordinator.swift:188-195`（flushPendingShows）+ L248-256（挂起拒绝）。
- 现状：本层契约（偏差 2）要求外部源不得跨 suspend 保留事件，但本层无法强制 flush 时机；若 T-1G-E 采用异步队列且挂起时未 flush，则 MINOR-1 场景在真实接线中可达。worker 未决问题 2 已提及「需在接线层落实挂起时清外部队列」。
- 建议：T-1G-E 集成时确认 flush 调用点（process/handlePinchEvent 后立即 flush），或本层在 suspend() 时提供清队列的强制语义（见 MINOR-1 建议）。

**QUESTION-2 handoffToken 清除依赖 process() 帧流：外部路径（handlePinchEvent）不喂帧时交接永不清除**
- 位置：`FourFingerActivationCoordinator.swift:164-169`（仅 process() 观察 latched→idle 清除 handoffToken）。
- 现状：若 T-1G-E 主路径为 handlePinchEvent 而非 process()（与偏差 1「process 为主路径」相反），show 派发后 handoffToken 将永久锁存，后续所有 show 被丢（droppedHandoffEventCount 持续递增）。当前测试均经 process() 帧流驱动，未覆盖纯外部路径的交接清除。
- 建议：T-1G-E 确认生产路径恒为 process()（provider 帧交付）；若外部路径成为主路径，需补充「外部结束事件清除交接」的机制或测试。

### INFO

**INFO-1 [verified]** `showCount` 为「show 派发次数」而非「成功 present 次数」：visible 幂等场景（effect .none）showCount 仍递增（`testShowWhileVisibleIsNoop` L279 断言 showCount 1）。设计一致（与 `testHandoffSuppressesNewShowUntilSessionEnd` L221 showCount 2 自洽），建议在属性注释中明确语义。

**INFO-2 [verified]** provider 报告 .off 只更新 activation 状态（L205），不停止识别器（偏差 4 已披露）。生产上 provider off 时无帧到达（识别器无输入），无实际影响；T-1G-E 接线层负责按用户开关驱动 start/stop。

**INFO-3 [verified]** `suppressedShowCount` 覆盖全部拒绝路径（terminating/suspended/stale/duplicate/handoff）+ 队列溢出（L233），语义宽泛但为中性计数，红线允许。

**INFO-4 [verified]** 测试夹具（FakePinchClock/frame/squareContacts）复用 `PinchRecognizerTests.swift` 等既有测试文件的共享定义（mtime 19:22:38，早于任务窗口，非本任务写集）；跨文件耦合属测试组织选择，夹具变更会影响本测试套件。

**INFO-5 [verified]** 全注入 init（L77-97）的 presentation/activation 参数带默认值，测试用显式 initialState 覆盖 .visible/.terminating 特殊状态（L265-296），无需呈现层转发方法——写集最小化设计良好。

## 11. 与 worker 结果声明的一致性（含 7 项偏差核对）

| worker 声明 | 复核结果 |
|---|---|
| 20 测试，`swift test --filter FourFingerActivationCoordinatorTests` exit 0 | ✅ 实测 20/0，exit 0（逐方法计数 20 个 test*） |
| 全量 `swift test` 1362/0 | ✅ 实测 1362/0，exit 0（两次独立重跑，第二次完整捕获 17.408s） |
| 变更文件仅 3 个（1 改 + 2 新） | ✅ mtime 验证（19:59 窗口；冻结树/共享文件未触碰；窗口后零改动；Workflow/ 文件属允许写集） |
| 偏差 1：双路径入队统一 flush | ✅ `process()` L170-174 与 `handlePinchEvent()` L180-184 均 enqueueShow；`flushPendingShows()` L188-195 统一派发 |
| 偏差 2：handlePinchEvent 返回 Void（入队语义） | ✅ L180 返回 Void；⚠️ 披露「挂起期间到达的事件在派发时被拒」未显式说明依赖 flush 时机（MINOR-1） |
| 偏差 3：交接窗口 = show 派发 → 全指释放 | ✅ handoffToken L276-278 设置、L164-169 清除；延迟 flush 病理场景首个手势优先（队列顺序派发） |
| 偏差 4：handleProviderState 仅更新状态机 | ✅ L202-227 仅 apply activation 转换；识别器生命周期由 start/stop/restart 驱动；无合法转换安全忽略（测试固化） |
| 偏差 5：userEnabled 仅用于展示 | ✅ 仅 `displayStatus`（L103）消费；不 gate 识别器生命周期与 show 派发 |
| 偏差 6：未接真实屏幕/AppDelegate | ✅ targetScreen 由调用方注入（L31/L62/L81）；组件无窗口/AppDelegate 引用 |
| 偏差 7：未新增 completeTransition 等呈现转发方法 | ✅ 测试经全注入 init 覆盖特殊状态（L265-296） |
| 未决项（T-1G-E 真实接线、外部源跨 suspend 保留、UI 触摸抑制、物理门） | ✅ 均属实且不属本任务验收范围（任务包明确纯逻辑 + 不接 AppDelegate） |

## 12. 置信度

- **高**：验收标准、Q-1/QUESTION-1/QUESTION-2 闭环、交接语义、去重/generation 全部基于逐行代码核对 + 实测命令输出（20/0、1362/0）+ 静态扫描 + mtime 证据，非仅依赖 worker 声明。
- **中**：MINOR-1 为代码路径推演（外部注入路径 + 延迟 flush 组合，当前测试未覆盖该组合）；QUESTION-1/2 为 T-1G-E 集成契约确认点。
- 未执行：真实触控板/设备验证（T-G-P6 范围）、真实接线（T-1G-E）、UI 层触摸抑制、物理门。

---

**Verdict: PASS**（0 BLOCKER / 0 MAJOR / 1 MINOR / 2 QUESTION / 5 INFO）— 满足 PLAN §10 `INDEPENDENT_REVIEW = PASS`（0 BLOCKER/0 MAJOR）与 `FULL_SWIFT_TESTS = PASS_WITH_EXECUTED_COUNT`（1362/0）门槛。MINOR-1 为外部路径 + 延迟 flush 组合的健壮性缺口（Q-1 主屏障完好），QUESTION-1/2 为 T-1G-E 集成契约确认点，均不构成验收阻断。
