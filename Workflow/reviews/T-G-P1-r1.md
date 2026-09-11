# T-G-P1 Review r1 — 独立四指识别器（纯值状态机）

- **Reviewer**: 独立评审（只读实现；未编辑任何实现/测试文件；未 commit/push/tag）
- **Date**: 2026-09-05
- **Task packet**: `Workflow/tasks/T-G-P1.md`
- **Worker result**: `Workflow/results/T-G-P1.md`
- **Review basis**: `AGENTS.md`、`MEMORY.md`、`Workflow/PLAN.md`（§4 冻结树 / §9 不变量 #9 / §10 全局验收 / §11 隐私红线 / §19.2 十二条合同 / §19.3 / §21.1 / §23.1 P01-P20 表）、`Workflow/decisions/2026-09-05-four-finger-user-decisions.md`、`Docs/FOUR_FINGER_REFERENCE_AUDIT.md`、实际实现 `Sources/PagingPrototypeApp/PinchRecognizer.swift`（629 行）+ 两个新测试文件、`git status`/文件 mtime、实测命令输出
- **Access declaration**: 本 Reviewer **未读取** `LaunchBetter/`、`BuhoReverseNotes/` 源码（遵守评审禁令）；未读取白名单外参考文件；未运行任何采集/设备访问代码
- **Verdict**: **PASS**（0 BLOCKER / 0 MAJOR / 1 MINOR / 4 QUESTION / 4 INFO）

---

## 0. 结论摘要

T-G-P1 交付物满足任务包全部验收标准与 §19.2 十二条可测语义。45 个定向测试（35+10）与全量 1247 测试均 0 失败；隐私红线静态扫描零命中；写集合规（仅 3 个新文件，冻结树/AppDelegate/Package.swift 未触碰）；无 AppKit import、无真实设备访问、无 commit/push/tag。发现 1 MINOR（未测边界）与 4 QUESTION（设计决策需 Chief/用户确认或 T-G-P6 实机验证），均不构成验收阻断。

---

## 1. 逐验收标准结果（任务包「验收」节）

| 验收标准 | 证据 | 结果 |
|---|---|---|
| P01-P20 纯逻辑部分全部 executed > 0 且 0 failures | `swift test --filter PinchRecognizer` → **45 tests, 0 failures**（35 + 10），exit 0。P01-P15、P17、P19 全部有对应测试（见 §5 测试清单）；P16（coordinator 级）/P18（配置）/P20（回归）按 §23.1 表属其他任务，正确延后 | ✅ |
| 测试断言「不该触发」（负样本），不只 happy path | 负样本断言：`XCTAssertEqual(events, [])` ×24、`XCTAssertEqual(r.fireCount, 0)` ×17、无触发状态断言（idle/candidate/recognizing）×77（两测试文件合计） | ✅ |
| 无 AppKit import | `grep -n 'import AppKit'` 三新文件 → 零命中；`PinchRecognizer.swift` L14 仅 `import Foundation` | ✅ |
| 无真实设备访问 | 实现为纯值类型（无 I/O、无采集 API）；测试全部使用合成匿名触点夹具（`squareContacts`/`frame`，`PinchRecognizerTests.swift` L45/L56） | ✅ |
| 不 commit/push/tag | `git log` → `fatal: your current branch 'main' does not have any commits yet`（仓库零提交）；Reviewer 未执行任何 git 写操作 | ✅ |

## 2. Objective 逐项验证

| Objective 要求 | 实现位置（已逐行核对） | 结果 |
|---|---|---|
| 状态机 7 态（可合并） | `PinchRecognizerState` L159-167：disabled/idle/candidate/recognizing/fired/waitingForRelease/suspended(reason)。Fired 与 WaitingForRelease 分开保留（任务允许合并；worker 偏差 2 已披露，用于区分 P02/P07 锁存 vs P17 扩张锁存） | ✅ |
| 可注入单调时钟（不用墙钟 Date 差值） | `PinchClock` 协议 L19-21；`PinchSystemClock` L24-29 用 `ProcessInfo.processInfo.systemUptime`（单调）；测试用 `FakePinchClock`（`PinchRecognizerTests.swift` L24-25）。全文件无 `Date()`/`Date.timeIntervalSince`（grep 零命中） | ✅ |
| 严格四个有效触点（不是 >=4） | 候选建立 L399 `frame.contacts.count == parameters.requiredContactCount`；会话推进 L464 同样 `==`。五指/三指均不建立或取消候选（testP04×2） | ✅ |
| 落指不同步需短稳定窗口建基线 | `advanceCandidate` L494-525：首帧建基线（L496-501），窗口满 `baselineStableWindow` 才固定基线半径转 recognizing（L514-523）；testP06/testContract2 验证第 4 指落指不构成收缩 | ✅ |
| 阈值/稳定窗口/时间上限/噪声容忍分别命名 | `PinchParameters` L102-147：10 个具名字段（requiredContactCount/baselineStableWindow/shrinkThreshold/expansionCancelThreshold/maxGestureDuration/noiseTolerance/cooldown/maxContactCount/minBaselineRadius/dataExpiryInterval）；testContract3ThresholdIsEffectiveParameter 验证阈值参数生效 | ✅ |
| 四指平移/旋转/抖动不误触 | testP05×3：平移（重锚定、窗口不完成）、旋转 90°（半径不变）、微抖动 ±0.003（容忍内、窗口完成但不触发） | ✅ |
| 五指进入/触点替换/设备改变/数据过期取消或重建候选 | L464-467 触点数量变化 → cancelSession(.contactCountChanged)；L469-475 触点身份变化 → cancelSession(.contactReplaced)；L374-383 静默超限 → 保守重置（.dataExpired）；设备隔离（sessions 按 deviceID，L248）；testP04Five/testP08×2/testP10Silence | ✅ |
| 触发后锁存 Fired，同一接触会话只发一次 | L488-491 fired/waitingForRelease 锁存返回 []；L539 抑制触发也置 .fired；testP02（20 帧连续收缩零重复）、testP07 | ✅ |
| 全指释放才 re-arm | L386-389 ended/cancelled/零触点 moved → endSession；testP03 释放后新会话可再触发 | ✅（见 QUESTION-2 静默恢复张力） |
| 四变三再变四不绕过锁存 | L464-467 数量变化 → waitingForRelease 锁存；testP07 验证锁存保持、释放后才新触发 | ✅ |
| 缺帧/乱序/NaN/Infinity/近零半径/非法计数安全拒绝 | `validateFrame` L423-444（负时间戳/超 maxContactCount/非有限坐标/重复 ID）；L364-371 未来帧与过期帧拒绝；L408-411 乱序拒绝；L518-521 近零半径 → .degenerateGeometry；testP11×6、testP12×2、testP10Expired | ✅ |
| Suspend/stop/disable/restart 清基线/会话/待派发意图 | L289-336：start/stop/restart/suspend/resume 全部经 `clearAllSessions`（L569-579，清 sessions/activeDeviceID/activeSessionID/lastFireTime）；testContract11×2、testP13×3、testP14×3 | ✅（见 QUESTION-1 generation 缺口） |
| 设备标识=进程内不透明 token，不写盘 | `PinchDeviceID/PinchContactID/PinchSessionID` L34-49：Hashable+Sendable、rawValue Int、进程内 token；无任何持久化代码 | ✅ |
| P01-P20 纯逻辑覆盖（任务包列出的 P09/P10/P11/P12/P13/P14/P15/P17/P19） | 全部有对应测试（§5 清单）；P15 为识别器级同步重入（见 INFO-3） | ✅ |

## 3. §19.2 十二条合同验证

| 合同 | 实现位置 | 测试 | 结果 |
|---|---|---|---|
| 1 严格四触点建候选 | L399、L464 | testP01、testP04 | ✅ |
| 2 异步落指需短稳定窗口（第 4 指落指 ≠ 收缩） | L494-525 | testP06、testContract2 | ✅ |
| 3 阈值/稳定窗口/时间上限/噪声容忍分别命名 | L102-147 | testContract3ThresholdIsEffectiveParameter、testContract3TimeLimitCancelsCandidate | ✅ |
| 4 平移/旋转/抖动不收缩 | L508-513（重锚定）、L533（半径比） | testP05×3 | ✅ |
| 5 五指/触点替换/设备改变/数据过期取消或重建候选（无旧基线继承） | L464-475、L374-383 | testP04Five、testP08×2、testP10Silence | ✅ |
| 6 锁存 Fired，一会话一次 | L488-491、L539 | testP02、testP07 | ✅ |
| 7 冷却仅附加保护（非唯一 re-arm 条件） | L537-541（冷却检查在收缩达标后） | testCooldownSuppressesRapidRetriggerAcrossSessions | ✅ |
| 8 全指释放/可靠结束才 re-arm | L386-389 | testP03 | ✅（张力见 QUESTION-2） |
| 9 4→3→4 不二次触发 | L464-467 → waitingForRelease | testP07 | ✅ |
| 10 缺帧/乱序/非有限/非法计数/近零半径安全拒绝 | L364-371、L408-411、L423-444、L518-521 | testP10Expired、testP11×6、testP12×2 | ✅ |
| 11 suspend/stop/disable/restart 清基线/会话/待派发意图 | L289-336 + clearAllSessions L569-579 | testContract11×2、testP13×3、testP14×3 | ✅（generation 缺口见 QUESTION-1） |
| 12 无回调超时 ≠ 全释放；保守可验证恢复 | L374-383（候选/识别中静默 → .dataExpired 重置；fired/waitingForRelease 静默 → 锁存保持） | testContract12、testP10Silence、testP12Overload | ✅（解释见 QUESTION-2） |

## 4. §19.3 / §21.1 验证

- **§19.3 单调时钟**：✅ `PinchClock` L19-21 + `systemUptime` L24-29；无墙钟。
- **§19.3 generation + event token 去重/丢弃旧事件**：✅ `PinchEventToken(generation, sessionID)` L185-192；token 在触发时携带当前 generation（L546）；stop/restart 递增 generation（L301/L319）；testP13FiredEventTokenGenerationInvalidatedByStop、testP14StopClearsSessionAndOldGenerationDoesNotAffectNewSubscription 验证。
- **§19.3 不记录原始轨迹**：✅ 会话仅存基线位置 + 基线半径（L202-222），无轨迹数组。
- **§21.1 只发 show(source: fourFingerPinch, eventToken:) 等价语义**：✅ `PinchEvent` 仅 `.showRequested(token:)`（L195-197），无 hide case；testP17EventTypeIsShowOnly 编译期验证；无窗口切换代码。

## 5. 测试证据（实测命令与输出）

**命令 1**：`swift test --filter PinchRecognizer`
**输出**（节选）：
```
Test Suite 'PinchRecognizerTests' passed at 2026-09-05 19:26:34.812.
	 Executed 35 tests, with 0 failures (0 unexpected) in 0.014 (0.017) seconds
Test Suite 'PagingPrototypePackageTests.xctest' passed at 2026-09-05 19:26:34.812.
	 Executed 45 tests, with 0 failures (0 unexpected) in 0.020 (0.024) seconds
Test Suite 'Selected tests' passed at 2026-09-05 19:26:34.812.
	 Executed 45 tests, with 0 failures (0 unexpected) in 0.020 (0.027) seconds
```
exit code 0。**45/0 与 worker 声明一致。**

**命令 2**：`swift test`（全量）
**输出**（节选）：
```
	 Executed 1247 tests, with 0 failures (0 unexpected) in 63.908 (64.615) seconds
```
exit code 0。**1247/0 与 worker 声明一致。**

**测试清单**（`Tests/PagingUITests/PinchRecognizerTests.swift` 35 个 + `PinchRecognizerLifecycleTests.swift` 10 个）：

- P01: testP01StrictFourFingerPinchTriggersOnce（触发一次、latency 0.11、token 携带 generation+sessionID）
- P02: testP02SameSessionContinuousContractionFiresOnce（20 帧连续收缩零重复）
- P03: testP03FullReleaseReArmsForNewSession（释放 → 新会话再触发，fireCount 2）
- P04: testP04TwoAndThreeFingersDoNotTrigger、testP04FiveFingersDoNotTrigger（2/3/5 指不触发；4 指候选 + 第 5 指 → contactCountChanged 取消）
- P05: testP05FourFingerTranslationDoesNotTrigger、testP05FourFingerRotationDoesNotTrigger、testP05MicroJitterDoesNotTrigger
- P06: testP06SequentialLandingDoesNotCountAsContraction（1→2→3→4 逐指落指，第 4 指建基线，不触发）
- P07: testP07FourThreeFourDoesNotRetriggerLatchedSession
- P08: testP08ContactReplacementDoesNotInheritBaseline、testP08DeviceChangeDoesNotInheritBaseline（A/B 设备独立会话各触发一次）
- P09: testP09TwoDevicesTwoFingersEachDoNotCombine（两设备各两指交错 → 无会话、无取消、idle）
- P10: testP10ZeroContactFrameEndsSession、testP10CancelledFrameEndsSession、testP10DeviceDisconnectEndsSession、testP10ExpiredDataRejected、testP10SilenceInCandidateConservativelyResets
- P11: testP11NaNRejected、testP11InfinityRejected、testP11ExcessiveContactCountRejected（9>8）、testP11NearZeroBaselineRadiusCancels、testP11NegativeTimestampRejected、testP11DuplicateContactIDsRejected
- P12: testP12OutOfOrderFrameRejected、testP12FutureFrameRejected、testP12OverloadFrameDropDoesNotWronglyShow（2s 静默 → dataExpired 重置 → 新窗口后才触发）
- P13: testP13DisableDropsLateCallbacks、testP13SuspendDropsCallbacks、testP13TeardownDropsCallbacks、testP13FiredEventTokenGenerationInvalidatedByStop
- P14: testP14StartStopReentryIdempotent、testP14StopClearsSessionAndOldGenerationDoesNotAffectNewSubscription、testP14RestartClearsSessionAndBumpsGeneration
- P15: testP15SynchronousReentryFakeBackendNoDeadlock（见 INFO-3）
- P17: testP17PinchOutProducesNoHideAndCancels（扩张 → expansion 取消、锁存至释放、零事件）、testP17EventTypeIsShowOnly
- P19: testP19InputHandoffDoesNotBreakRecognizerOrOtherInput（触发 → 释放 → 二指帧无干扰 → 新四指触发）
- 合同补充: testContract2FourthFingerLandingIsNotContraction、testContract3ThresholdIsEffectiveParameter（0.5 不触发/0.1 触发）、testContract3TimeLimitCancelsCandidate（maxGestureDuration 0.5 → timeLimitExceeded）、testCooldownSuppressesRapidRetriggerAcrossSessions（生产参数：0.41s 抑制 + suppressedFireCount 1 + 锁存；释放后 0.71s 触发）、testContract12SilenceIsNotReleaseForLatchedSession（fired + 10s 静默 → 锁存保持、显式结束才 idle）、testContract11SuspendClearsSessionAndPendingIntent、testContract11StopClearsSession

**夹具**（`PinchRecognizerTests.swift`）：`FakePinchClock` L24-25（`nonisolated(unsafe) var current`，测试单线程）、`makeRecognizer` L31（默认 `PinchParameters(cooldown: 0)`）、`processAt` L39（先拨时钟再投递）、`squareContacts` L45（中心 (0.5,0.5)）、`frame` L56、`runStandardPinch` L62（t0 began h=0.2 → +0.1 moved h=0.2 → +0.11 moved h=0.16，收缩 0.2 ≥ 0.15）。合成匿名触点，无真实轨迹。

## 6. 隐私红线静态扫描（PLAN §11）

命令：`grep -nE 'addGlobalMonitorForEvents|CGEvent\.tapCreate|AXIsProcessTrusted|IOHID|LaunchBetter|Buho|frontmostApplication|dlopen|NSEvent\.addGlobalMonitor|pointer coordinate|NSApp\.activate|private API'` 三新文件 → **零命中**（exit 1）。`import AppKit` → 零命中。墙钟 `Date()`/`Date.timeIntervalSince` → 零命中。

## 7. 写集合规核查

- 仓库无基线提交（`git log`：`your current branch 'main' does not have any commits yet`），以文件 mtime 为准：
  - `Sources/PagingPrototypeApp/PinchRecognizer.swift`、`Tests/PagingUITests/PinchRecognizerTests.swift`、`Tests/PagingUITests/PinchRecognizerLifecycleTests.swift`：**2026-09-05 19:22**（T-G-P1 工作窗口，最新）
  - 冻结树：`Package.swift` 2026-08-28 19:42、`Sources/PagingPrototypeApp/AppLaunchController.swift` 2026-08-28 20:46 — **未触碰** ✅
  - `Sources/PagingPrototypeApp/AppDelegate.swift` 2026-09-05 14:09 — 早于 T-G-P1（19:22），属先前任务（T-1G-A 窗口 18:27-18:30 之前的 14:09-14:13 批次），非本任务改动 ✅
- 写范围合规：仅 3 个新文件；无 provider/后端、无窗口代码、无 AppDelegate 改动、无 Package.swift 改动、无真实轨迹提交。

## 8. Findings

### BLOCKER
无。

### MAJOR
无。

### MINOR

**MINOR-1 [verified] 会话结束后过期帧可重建新候选（未测边界）**
- 位置：`PinchRecognizer.swift` L408-411（乱序检查仅对**已存在**会话生效）。`endSession`（L564-567）移除会话后，一帧时间戳早于上一会话 `lastSeenTimestamp`、但仍在 `dataExpiryInterval`（0.5s）内的 4 触点帧，会走 L398-405 的「无会话」分支建立新候选，基线取该过期位置。
- 影响：低。新候选仍需稳定窗口 + 收缩才触发；过期帧位置成为基线只会导致后续收缩判定基于错误基线，最坏情况是误触发概率极低（需过期帧恰好 4 触点 + 后续 0.1s 稳定 + 收缩 ≥0.15）。
- 建议：在 L398 无会话分支前增加「帧时间戳不得早于最近结束会话的 lastSeenTimestamp」守卫，或补一条测试固化当前行为。非验收阻断。

### QUESTION

**QUESTION-1 [verified] suspend() 不递增 generation（§16.1 重放风险）**
- 位置：`PinchRecognizer.swift` L324-329（suspend 仅 clearAllSessions + 置 suspended，**无** `generation += 1`）；对比 stop L301、restart L319 均递增。
- 事实：识别器无事件队列（process 同步返回事件），suspend 后 process 返回 []（L352-353），合同 11 字面（清基线/会话/待派发意图）在识别器层满足。但 §19.3 的 generation 机制是消费方（T-G-P4）丢弃旧事件的唯一信号：若消费方在 suspend 前收到 showRequested 并暂存（如应用处于不可呼出状态），suspend 不递增 generation 则恢复后无法凭 generation 判定该事件已过期 → 违反 §16.1「恢复后不能重放之前的手势」。
- 性质：**推断**（消费方尚未实现，风险为设计一致性缺口而非已观察缺陷）。
- 建议：suspend() 增加 `generation += 1`（一行，与 stop/restart 对齐），或由 T-G-P4 在消费侧处理；并补一条「suspend 使旧 token 失效」测试。若 T-G-P4 集成时未处理，本项升级为 MAJOR。

**QUESTION-2 [verified] 静默恢复在无结束证据下重新武装（合同 8 vs 合同 12 张力）**
- 位置：`PinchRecognizer.swift` L374-383。候选/识别中静默 > dataExpiryInterval → 移除会话 + recordCancel(.dataExpired) → 聚合状态回 idle（L591-595）→ 下一帧 4 触点帧建立**新**候选（L398-405）。
- 事实：worker 已披露（偏差 4）。恢复是保守的——新候选必须重新走稳定窗口 + 基线 + 收缩，静默保持的 4 指姿势不会触发（无新帧）；fired/waitingForRelease 静默保持锁存（L380-381）。但严格读合同 8「全指释放才 re-arm」，静默恢复属于无结束证据的重新武装；合同 12 允许「保守可验证恢复」。测试 testP10SilenceInCandidateConservativelyResets、testP12OverloadFrameDropDoesNotWronglyShow 固化该行为。
- 性质：**设计决策**（两合同条款的合理解释问题），需 Chief/用户确认或文档化。
- 建议：在 §19.2 定案时明确「静默超限 = 可靠结束证据」的语义归属，或保持现状并记录为已接受解释。

**QUESTION-3 [verified] 慢速连续收缩可能永不触发（重锚定语义）**
- 位置：`PinchRecognizer.swift` L508-513。候选阶段任何触点位移超过 `noiseTolerance × 基线半径` 即重锚定基线并**重启稳定窗口**；若用户以慢速连续内收（无停顿）完成捏合，窗口永不完成 → 永不触发。testP05FourFingerTranslationDoesNotTrigger 依赖该行为（平移不误触）。
- 事实：worker 已披露（P05 测试依赖）。这是「平移不误触」与「慢速捏合可触发」之间的固有取舍，需 T-G-P6 实机验证。
- 建议：T-G-P6 物理验证时评估「窗口完成时重锚定基线」或「基线取窗口内均值」等替代语义；当前保守行为可接受为暂定。

**QUESTION-4 [verified] 冷却为识别器级（跨设备抑制）**
- 位置：`PinchRecognizer.swift` L251-252（`lastFireTime` 注释「识别器级冷却，跨会话/跨设备」）、L537-541（冷却检查用全局 lastFireTime）。两设备在 0.5s 内各自捏合，第二设备被抑制（suppressedFireCount += 1，不触发）。
- 事实：worker 未决问题 Q4 已披露；测试仅覆盖同设备（testCooldownSuppressesRapidRetriggerAcrossSessions 的「跨会话」指同设备新会话）。当前为最保守选择。
- 建议：确认是否改为按设备冷却（`[PinchDeviceID: TimeInterval]`）；若保持识别器级，补一条跨设备抑制测试固化行为。

### INFO

**INFO-1 [verified]** `rejectedFrameCount` 含未来/过期帧（L365、L369）——与代码注释（L237）一致（worker 偏差 6）。

**INFO-2 [verified]** `timeEpsilon = 1e-9`（L255）——浮点误差防护合理（0.5-0.4 = 0.09999999999999998 < 0.1 的边界；worker 报告修复前 14 个测试失败，偏差 5）。epsilon 远小于任何交互参数，无行为影响。

**INFO-3 [verified]** P15 测试为识别器级同步重入（`PinchRecognizerLifecycleTests.swift` testP15：deliver → process → 事件处理中重入投递；1 事件、fireCount 1、state .fired），测试注释明确 register/unregister 属 provider 域（T-G-P2）。任务包写范围禁止 provider，识别器无锁（L226 注释「无锁，调用方负责串行化」），本任务可达的最大验证即此；provider 级死锁验证归 T-G-P2，可接受。

**INFO-4 [verified]** 参数为暂定值（`PinchParameters` L101 注释「数值为暂定值：待 §19.2 定案与实机验证（T-G-P6）」；worker 偏差 1：requiredContactCount=4 / baselineStableWindow=0.1 / shrinkThreshold=0.15 / expansionCancelThreshold=0.15 / maxGestureDuration=1.5 / noiseTolerance=0.02 / cooldown=0.5 / maxContactCount=8 / minBaselineRadius=0.02 / dataExpiryInterval=0.5）。参考审计已拒绝沿用参考参数 0.18/0.2s，本实现未使用。参数定案不属本任务验收范围。

## 9. 与 worker 结果声明的一致性

| worker 声明 | 复核结果 |
|---|---|
| 45 测试（35+10），`swift test --filter PinchRecognizer` exit 0 | ✅ 实测 45/0，exit 0 |
| 全量 `swift test` 1247/0 | ✅ 实测 1247/0，exit 0 |
| 变更文件仅 3 个新文件 | ✅ mtime 验证（19:22 最新；冻结树/AppDelegate 未触碰） |
| 偏差 1-7（参数暂定/Fired 与 WaitingForRelease 分离/识别器级冷却/静默恢复/timeEpsilon/rejectedFrameCount 语义/Q-1 审计行号不一致仅记录） | ✅ 全部在代码中核实（L101/L158/L251-252/L374-383/L255/L237） |
| 未决项（参数定案、provider 帧契约、P16/P18/P20、冷却跨设备） | ✅ 均属实且不属本任务验收范围 |

## 10. 置信度

- **高**：验收标准、合同 1-12、Objective 全部基于逐行代码核对 + 实测命令输出（45/0、1247/0）+ 静态扫描，非仅依赖 worker 声明。
- **中**：QUESTION-1 的 §16.1 重放风险为推断（消费方未实现）；QUESTION-2/3/4 为设计取舍，最终判定依赖 Chief/用户决策与 T-G-P6 实机数据。
- 未执行：实机触控板验证（T-G-P6 范围）、provider 集成（T-G-P2 范围）、coordinator/配置/回归（P16/P18/P20 其他任务）。

---

**Verdict: PASS**（0 BLOCKER / 0 MAJOR / 1 MINOR / 4 QUESTION / 4 INFO）— 满足 PLAN §10 INDEPENDENT_REVIEW = PASS（0 BLOCKER/0 MAJOR）与 FOUR_FINGER_RECOGNIZER_TESTS = PASS 门槛。
