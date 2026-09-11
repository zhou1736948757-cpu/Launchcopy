# T-G-P1 — 独立四指识别器（纯值状态机）（Worker 结果）

- **Task**: T-G-P1（chef-worker-reviewer-workflow v1.4.1，Worker 角色）
- **Date**: 2026-09-05
- **Status**: COMPLETED（测试全绿；未自证 PASS，待 Reviewer）
- **Objective 完成度**: 3/3（识别器纯逻辑、P01-P20 纯逻辑测试矩阵、生命周期测试）

## Changed files

| 文件 | 类型 | 说明 |
|---|---|---|
| `Sources/PagingPrototypeApp/PinchRecognizer.swift` | 新增 | 纯 Foundation 值类型识别器：PinchClock/PinchSystemClock（单调 systemUptime）、PinchDeviceID/PinchContactID/PinchSessionID（进程内不透明 token）、PinchPoint/PinchContact/PinchFrame/PinchFramePhase、PinchParameters（10 项分别命名）、PinchRecognizerState（disabled/idle/candidate/recognizing/fired/waitingForRelease/suspended）、PinchCancelReason、PinchEventToken（generation+sessionID）、PinchEvent（仅 .showRequested，无 hide）、PinchRecognizer（per-device 会话、严格四指、稳定窗口+重锚定基线、归一化收缩、锁存、冷却、静默恢复、generation、中性计数） |
| `Tests/PagingUITests/PinchRecognizerTests.swift` | 新增 | P01-P12/P17/P19 + §19.2 合同 2/3/7/12 专项 + 共享夹具（FakePinchClock/processAt/squareContacts/runStandardPinch）（35 tests） |
| `Tests/PagingUITests/PinchRecognizerLifecycleTests.swift` | 新增 | P13/P14/P15 + §19.2 合同 11（10 tests） |

未改动：冻结树、Package.swift、AppDelegate/AppMain/AppArguments/KeyboardFocusController、AppLaunchController.swift、任何既有测试、任何既有源文件。

## Test counts

- 命令：`swift test --filter PinchRecognizer`
- exit code：**0**
- executed：**45**；passed：**45**；failed：**0**

| 套件 | executed | passed | failed | 覆盖 |
|---|---|---|---|---|
| PinchRecognizerTests | 35 | 35 | 0 | P01-P12/P17/P19 + 合同 2/3/7/12 |
| PinchRecognizerLifecycleTests | 10 | 10 | 0 | P13/P14/P15 + 合同 11 |

全量回归：`swift test` → **1247 executed / 0 failures**（含本任务 45 项；exit 0）。

## Evidence（命令 + 输出）

```
$ swift test --filter PinchRecognizer
Test Suite 'PinchRecognizerTests' passed at 2026-09-05 19:22:43.119.
	 Executed 35 tests, with 0 failures (0 unexpected) in 0.006 (0.007) seconds
Test Suite 'PinchRecognizerLifecycleTests' passed at 2026-09-05 19:22:43.119.
	 Executed 10 tests, with 0 failures (0 unexpected) in 0.002 (0.003) seconds
Test Suite 'Selected tests' passed at 2026-09-05 19:22:43.119.
	 Executed 45 tests, with 0 failures (0 unexpected) in 0.008 (0.011) seconds
$ echo $?
0

$ swift test
Test Suite 'All tests' passed at 2026-09-05 19:23:05.080.
	 Executed 1247 tests, with 0 failures (0 unexpected) in 17.075 (17.153) seconds
```

## Per-criterion results（任务包验收逐项）

| 验收项 | 结果 | 证据 |
|---|---|---|
| P01 严格四指内收超过阈值一次触发 | **PASS** | `testP01StrictFourFingerPinchTriggersOnce`（事件 1、fireCount 1、state .fired、lastFireLatency 0.11、token 携带 generation+sessionID） |
| P02 同会话持续收缩超过冷却也只触发一次 | **PASS** | `testP02SameSessionContinuousContractionFiresOnce`（20 帧持续收缩零重复事件） |
| P03 全指释放后新会话可再次触发 | **PASS** | `testP03FullReleaseReArmsForNewSession`（零触点 moved 帧 = 结束证据 → idle → 新会话 fireCount 2） |
| P04 二指缩放/三指平移/五指不误触 | **PASS** | `testP04TwoAndThreeFingersDoNotTrigger`（不建立候选）；`testP04FiveFingersDoNotTrigger`（五指直接进入不建候选；四指候选 + 第五指 → contactCountChanged 取消锁存，无事件） |
| P05 四指平移/旋转/微抖动不误触 | **PASS** | `testP05FourFingerTranslationDoesNotTrigger`（平移重锚定、半径不变）；`testP05FourFingerRotationDoesNotTrigger`（90° 旋转半径不变）；`testP05MicroJitterDoesNotTrigger`（容忍内抖动窗口完成、半径波动 < 阈值） |
| P06 顺次落指不把成员加入当成收缩 | **PASS** | `testP06SequentialLandingDoesNotCountAsContraction`（1→2→3→4 落指零事件；基线 = 第 4 指落下几何） |
| P07 四变三再变四不重复触发已锁存会话 | **PASS** | `testP07FourThreeFourDoesNotRetriggerLatchedSession`（锁存保持 .fired，零事件；释放后新会话 fireCount 2） |
| P08 更换 contact identity 或 device 不继承基线 | **PASS** | `testP08ContactReplacementDoesNotInheritBaseline`（contactReplaced 取消）；`testP08DeviceChangeDoesNotInheritBaseline`（A/B 独立会话各自触发） |
| P09 两设备各两指不能组合触发 | **PASS** | `testP09TwoDevicesTwoFingersEachDoNotCombine`（交错帧零会话零事件零取消） |
| P10 零触点/取消/断开/过期正确结束或取消 | **PASS** | `testP10ZeroContactFrameEndsSession` / `testP10CancelledFrameEndsSession` / `testP10DeviceDisconnectEndsSession` / `testP10ExpiredDataRejected`（过期帧拒绝，状态不变）/ `testP10SilenceInCandidateConservativelyResets`（静默超限 dataExpired 重置，新帧建新候选） |
| P11 NaN/Infinity/近零半径/非法计数/安全边界拒绝 | **PASS** | `testP11NaNRejected` / `testP11InfinityRejected` / `testP11ExcessiveContactCountRejected`（>8 拒绝）/ `testP11NearZeroBaselineRadiusCancels`（degenerateGeometry）/ `testP11NegativeTimestampRejected` / `testP11DuplicateContactIDsRejected` |
| P12 乱序/时间回退/过载丢帧不错误 Show | **PASS** | `testP12OutOfOrderFrameRejected` / `testP12FutureFrameRejected` / `testP12OverloadFrameDropDoesNotWronglyShow`（静默重置后新基线，不凭不完整轨迹触发） |
| P13 开关关闭/暂停/Quit 后 late callback 丢弃 | **PASS** | `testP13DisableDropsLateCallbacks` / `testP13SuspendDropsCallbacks` / `testP13TeardownDropsCallbacks` / `testP13FiredEventTokenGenerationInvalidatedByStop`（stop 使旧 generation 事件失效） |
| P14 start/stop 重入、旧 generation stop 不影响新订阅 | **PASS** | `testP14StartStopReentryIdempotent` / `testP14StopClearsSessionAndOldGenerationDoesNotAffectNewSubscription` / `testP14RestartClearsSessionAndBumpsGeneration` |
| P15 同步重入假后端无死锁 | **PASS** | `testP15SynchronousReentryFakeBackendNoDeadlock`（无锁值类型；事件处理中重入投递下一帧；register/unregister 属 provider 域 T-G-P2） |
| P17 pinchOut 无 Hide | **PASS** | `testP17PinchOutProducesNoHideAndCancels`（扩张超限 → expansion 取消锁存，零事件）；`testP17EventTypeIsShowOnly`（编译期：PinchEvent 仅 .showRequested 一个 case） |
| P19 输入交接不误翻页/不永久禁键盘鼠标 | **PASS** | `testP19InputHandoffDoesNotBreakRecognizerOrOtherInput`（触发→释放→二指帧不干扰→新四指手势正常；识别器只发 .showRequested，被动观察） |
| 测试断言"不该触发"（负样本） | **PASS** | 全部 P04/P05/P07/P09/P10/P11/P12/P17 均为负样本断言；P02 持续收缩零重复 |
| 无 AppKit import；无真实设备访问 | **PASS** | `PinchRecognizer.swift` 仅 `import Foundation`（grep 验证）；零设备/窗口/AppKit 类型 |
| 不 commit/push/tag | **PASS** | 无 git 操作 |

## §19.2 十二条合同对照

| 合同 | 实现 | 测试 |
|---|---|---|
| 1 严格四触点才建候选 | 无会话时仅 `count == requiredContactCount` 建候选；候选/识别中计数必须恰好 4 | P01/P04 |
| 2 落指不同步需短稳定窗口建基线 | 候选建立时记录基线；窗口内每触点位移 ≤ noiseTolerance×基线半径 才完成；超限重锚定 | P06、`testContract2FourthFingerLandingIsNotContraction` |
| 3 阈值/稳定窗口/时间上限/噪声容忍分别命名 | shrinkThreshold / baselineStableWindow / maxGestureDuration / noiseTolerance（PinchParameters 独立字段） | `testContract3ThresholdIsEffectiveParameter` / `testContract3TimeLimitCancelsCandidate` |
| 4 平移/旋转/抖动不产生收缩 | 半径 = 质心平均距离（平移/旋转不变）；抖动波动 < 阈值 | P05 |
| 5 五指/触点替换/设备改变/数据过期取消或重建 | contactCountChanged / contactReplaced / 设备隔离 / dataExpired 重置 | P04/P08/P10 |
| 6 触发后锁存 Fired，一会话一次 | .fired 锁存至结束证据 | P02/P07 |
| 7 冷却只是附加保护 | 识别器级 lastFireTime 冷却；抑制仍锁存（suppressedFireCount） | `testCooldownSuppressesRapidRetriggerAcrossSessions`（生产默认参数） |
| 8 全指释放才 re-arm | 零触点 moved/ended/cancelled/disconnect → idle；扩张取消也锁存至释放 | P03/P17 |
| 9 四变三再变四不绕过锁存 | .fired 对任意触点帧保持 | P07 |
| 10 缺帧/乱序/非有限/非法计数/近零半径拒绝 | validateFrame + 乱序/未来/过期拒绝 + degenerateGeometry | P10/P11/P12 |
| 11 Suspend/stop/disable/restart 清基线/会话/待派发意图 | clearAllSessions（事件同步返回，无待派发队列）；generation 递增 | P13/P14、`testContract11SuspendClearsSessionAndPendingIntent` / `testContract11StopClearsSession` |
| 12 无回调超时 ≠ 全指释放 | 候选/识别中静默超限 → 保守重置（dataExpired，非"释放"）；锁存状态静默保持，需显式结束证据 | `testContract12SilenceIsNotReleaseForLatchedSession`、P10/P12 |

## Deviations（范围披露）

1. **参数为暂定值**（requiredContactCount=4 / baselineStableWindow=0.1 / shrinkThreshold=0.15 / expansionCancelThreshold=0.15 / maxGestureDuration=1.5 / noiseTolerance=0.02 / cooldown=0.5 / maxContactCount=8 / minBaselineRadius=0.02 / dataExpiryInterval=0.5）：未采用参考实现参数（审计 §4 明确拒绝参考值来源）；代码注释标注"待 §19.2 定案与实机验证（T-G-P6）后确认，不视为最终交互参数"。
2. **Fired 与 WaitingForRelease 未合并**（任务包允许合并）：分开保留以区分 P02/P07（fired 锁存）与 P17（扩张取消锁存）的可测语义。
3. **冷却为识别器级**（跨会话/跨设备）：合同 7 只要求"附加保护"，识别器级最保守；测试默认 cooldown=0 隔离锁存语义，冷却合同用生产默认参数显式覆盖。
4. **静默恢复策略**（合同 12）：候选/识别中静默 > dataExpiryInterval → 保守重置为 idle（cancelReason .dataExpired，不凭不完整轨迹触发）；fired/waitingForRelease 静默 → 锁存保持（不重新武装），由 provider（T-G-P2）在会话丢失时交付合成结束证据（deviceDisconnected / .cancelled）。
5. **时间比较容差**：`timeEpsilon = 1e-9` 应用于窗口/时间上限/冷却/过期/静默边界比较——测试发现 `0.5 - 0.4 = 0.09999999999999998 < 0.1` 导致稳定窗口永不完成（浮点误差），epsilon 远小于任何交互参数。
6. **rejectedFrameCount 含未来/过期帧**：与代码注释一致（"非有限数/非法计数/乱序/未来/过期/畸形"）。
7. **Q-1（FOUR_FINGER_REFERENCE_AUDIT.md §2.2 引用行号不一致，Reviewer 遗留）**：按任务指示仅记录——本实现为纯逻辑、不依赖 MTTouch ABI，该引用与本任务无关，不构成实现依据。

## Unresolved questions

1. 暂定参数值需 §19.2 定案 + 实机验证（T-G-P6）确认；当前不视为最终交互参数。
2. provider 帧契约（began → moved* → ended/cancelled；timestamp 与注入时钟同一单调时间域）由 T-G-P2 实现并测试；识别器对 began 中段到达保守处理（视为普通帧，不重置锁存）。
3. P16（Show 幂等，coordinator 级）/ P18（配置缺项/不可用后端降级，T-G-P3）/ P20（Folder/搜索/打字机/拖拽/启动集成回归）属其他任务，本任务未覆盖。
4. 冷却跨设备抑制（识别器级）是否过保守：两设备 0.5s 内各自捏合，第二次被抑制——如 Reviewer/Chief 认为应 per-device，可调整（当前最保守）。

## Reviewer focus

1. 十二条合同逐项对照（上表）与任务包验收逐项（P01-P20 纯逻辑部分）。
2. 严格四指语义：无会话时仅恰好 4 触点建候选；五指进入取消锁存（P04）。
3. 锁存与 re-arm：.fired/.waitingForRelease 仅由结束证据（零触点/ended/cancelled/disconnect）解除；静默不重新武装（合同 12）。
4. 设备隔离：per-device 会话字典；两设备各两指不组合（P09）；设备更换不继承基线（P08）。
5. 拒绝路径：validateFrame（非有限/超上限/重复 id/负时间戳）+ 乱序/未来/过期拒绝，均不改变状态。
6. 纯 Foundation 约束：仅 `import Foundation`；无 AppKit/CoreGraphics；无持久化；设备 token 不写盘。
7. 时间比较 epsilon（1e-9）与冷却作用域（识别器级）两个设计决策。
8. 隐私红线：新文件无 `addGlobalMonitorForEvents`/`CGEvent.tapCreate`/`AXIsProcessTrusted`/`IOHID`/`LaunchBetter`/`Buho`/`frontmostApplication`（grep 验证，仅注释提及"无 AppKit"）。

## Memory candidates（供 Main 门控）

1. **浮点时间边界**：`0.5 - 0.4 = 0.09999999999999998 < 0.1`——时间比较必须带 epsilon（本实现 1e-9），否则稳定窗口/冷却/过期边界会静默失效；测试曾因此 14 项失败。
2. **静默 ≠ 释放**：识别器对"无回调超时"的恢复策略分两档——候选/识别中静默超限保守重置（dataExpired，不触发）；fired/waitingForRelease 静默保持锁存，必须由 provider 交付结束证据（合成 cancel/disconnect）才能 re-arm。
3. **冷却作用域**：识别器级冷却（跨会话/跨设备）是"附加保护"的最保守实现；测试默认 cooldown=0 隔离锁存语义，冷却合同用生产默认参数单独覆盖。
