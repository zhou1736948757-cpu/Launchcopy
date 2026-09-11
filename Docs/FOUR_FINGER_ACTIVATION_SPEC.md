# FOUR_FINGER_ACTIVATION_SPEC — 四指捏合呼出功能规格

> Phase 1G 四指轨最终规格（§24 文档清单；与 ADR-013 互补：ADR 记决策与依据，本文记实现契约）。状态：**DRAFT → 随 T-G-P7 收口定稿**。最后更新：2026-09-06。

## 1. 功能定义

- 应用驻留且界面隐藏时，触控板上**恰好四指**向内捏合 → 发出一次 Show（`LauncherActivationSource.fourFingerPinch`）。
- 向外张开**不**触发 Hide（用户决策 2026-09-05）。
- 严格四指：恰好 4 个有效触点建立候选；5 指/3 指取消（不沿用参考实现 `>=4`）。
- 冷启动进程不在承诺范围（四指「启动」= 进程已驻留时呼出界面）。

## 2. 数据流（T-G-P1/P2/P4 实现）

```
MultitouchSupportBackend（真实后端，T-G-P6）
  → TouchProvider protocol（start/stop/restart 幂等、generation、onFrame/onStateChange）
  → PinchRecognizer（纯值状态机，PinchEvent 仅 .showRequested(token:)）
  → FourFingerActivationCoordinator（dispatchShow 唯一出口、lastConsumedToken 去重、挂起拒绝）
  → LauncherPresentationCoordinator.show(source: .fourFingerPinch, targetScreen:)
```

- 单调时间域：`PinchSystemClock = ProcessInfo.systemUptime`（零 Date()/墙钟）。
- 设备隔离：per-device 会话（两设备各两指不组合）。
- 帧契约：began → moved* → ended/cancelled（TouchProvider 强制；合成器帧间 identifier 集合 diff 判定）。

## 3. 识别器状态机（PinchRecognizer.swift，首帧基线模型）

状态：`disabled / idle / candidate / recognizing / fired / waitingForRelease / suspended`。

- **候选建立**：idle 收到恰好 4 触点 → `.candidate`，首帧建立 `baselineRadius`（质心平均距离；首帧不判定收缩）。
- **触发**：次帧起 `(baselineRadius − currentRadius) / baselineRadius ≥ 0.15` → `.fired`（锁存，一会话一次）。
- **扩张取消**：收缩 ≤ −0.15 → 取消（pinchOut 无 Hide）。
- **取消路径**：触点数变化、触点 ID 更换、五指进入、设备改变、数据过期（0.5s 静默）、时间超限（3.5s）、退化几何（minBaselineRadius 0.02 首帧检查）。
- **冷却**：0.5s 单调时钟，识别器级（跨会话跨设备）。
- **静默恢复两档**：候选/识别中数据过期 → 保守重置；fired/waitingForRelease 锁存保持（仅结束证据清除）。
- **参数**（§19.2 合同 3 分别命名）：requiredContactCount=4 / shrinkThreshold=0.15 / expansionCancelThreshold=0.15 / maxGestureDuration=3.5 / cooldown=0.5 / maxContactCount=8 / minBaselineRadius=0.02 / dataExpiryInterval=0.5 / timeEpsilon=1e-9。
- **validateFrame**：缺帧/乱序/非有限数/非法计数/重复 ID/负值/未来/过期时间戳 → 拒绝（rejectedFrameCount 计数，不改状态）。

## 4. 后端（MultitouchSupportBackend.swift，T-G-P6）

- dlopen `/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport`（RTLD_LAZY；失败 → .unavailable 不崩溃）。
- 5 符号：MTDeviceCreateList / MTRegisterContactFrameCallback / MTUnregisterContactFrameCallback / MTDeviceStart / MTDeviceStop。
- MTTouch 布局（审计 §2.2 对齐）：frame:Int32 / timestamp:Double / identifier:Int32 / state:Int32 / fingerID:Int32 / handID:Int32 / normalized:MTReadout / size:Float / zero1:Int32 / angle:Float / majorAxis:Float / minorAxis:Float / absolute:MTReadout / zero2:(Int32,Int32) / density:Float。
- **state 位掩码（R-02 实机定案）**：bit2(4)=在表面静止（主导）/ bit1(2)=移动 / bit0(1)=接触事件；state∈[1,7] 从不出现 0；离面 = 触点从帧消失 + count=0 空帧。合成器用帧间 identifier 集合 diff 判定 began/ended（cancelled 概念删除）。
- 回调 @convention(c) 内最小拷贝 + 锁外派发；有界缓冲 maxQueueSize=64 过载只丢 moved 保 began/ended/cancelled。
- 生命周期：start/stop/restart 幂等 + generation；teardown 先 Unregister 再 Stop 再 dlclose（in-flight 计数归零才 dlclose；deinit 不 dlclose）。
- 不申请权限不弹窗；状态上报 noDevice/unavailable/ready。

## 5. 配置与入口状态（T-G-P3）

- `ActivationPreferences`：专用 suite `com.pagingprototype.activation` + `activation.` key 前缀；schemaVersion 防未来 schema 静默覆盖（load 先读原始版本 → futureSchema 不解码不覆盖；save 前再查版本拒绝写入）；非法布尔 → Off；resetActivation 只清 3 个 activation key。
- `fourFingerActivationEnabled` 默认 **true**（用户决策 2026-09-05 覆盖 ADR-013 §7 原锁定 false；默认开启≠立即启用，仍须实现+验证+物理门通过）。
- 入口状态七态（与 TouchProviderState 1:1）：off / checking / ready / noDevice / unavailable / permissionNotConfirmed / suspended(reason:)；`isReady = enabled && state == .ready`（Enabled≠Ready）。

## 6. 协调器接线（T-G-P4）

- `FourFingerActivationCoordinator`：`dispatchShow` 唯一出口 → `presentation.show(source: .fourFingerPinch, targetScreen:)`；无 hide/toggle/quit 方法。
- 去重：lastConsumedToken 全等去重 + handoffToken（show 派发时设置/识别器回 idle 清除）。
- 挂起：suspend() 清空 pendingShowTokens + 派发时 activation/presentation 任一 suspended 拒绝。
- provider .ready 重复上报幂等（guard activation.state != .ready）。
- 生产路径恒为 process() 帧流；flushPendingShows() 为唯一派发出口（T-1G-E 集成契约）。

## 7. 隐私边界（§4.3/§11 红线）

- 禁记/输出：raw pointer 坐标、轨迹、screen UUID/name/serial、frontmost app、按键流、真实快捷键文本、app 身份、folder 数据、搜索词、窗口标题。
- 允许中性：activation source enum、show/hide/toggle/quit outcome enum、corner enum、dwell/cooldown state enum、screen count、registration outcome enum、transition duration aggregate、counter。
- 触点数据不持久化（采集工具 jsonl 仅实验用途，实验后删除）。
- 静态红线：无 addGlobalMonitorForEvents / CGEvent.tapCreate / AXIsProcessTrusted / IOHID / 私有 API selector 字符串（获批 MultitouchSupport 符号精确白名单除外）。

## 8. 实机验证证据（T-G-P6，2026-09-06）

| 场景 | 数据 | 结果 |
|---|---|---|
| fast-pinch | 471 帧 6 段 | fired=6/6 ✓ |
| slow-pinch | 8168 帧 | fired=1 ✓ |
| spread（张开） | 2536 帧 6 段（扩散 +118~196%） | fired=0 ✓ |
| negative（单/三/五指） | 1970 帧 28 会话 | fired=0 ✓ |

- R-02 state 位掩码定案：rawdiag 64905 帧（state 直方图 1:1703/2:290/3:1693/4:81644/5:1592/6:571/7:1703）。
- 未跑：M01-M12 完整矩阵（依赖 T-1G-E 集成）、能耗 A/B（依赖集成）、快速落指不捏合负样本（M04/M05 补）。

## 9. 挂账与后续

- T-1G-B/C/D/E（窗口/驻留/菜单栏/快捷键/Hot Corner/AppDelegate 集成）待物理门回填 + Chief 确认解除。
- M01-M12 实机矩阵、能耗 A/B 依赖集成后执行。
- 分发未评估（ADR-013 §9）。
