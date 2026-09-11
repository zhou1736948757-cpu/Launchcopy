# T-G-P6 Worker Result — 四指轨真实 MultitouchSupport 后端与采集实验工具

- **Worker**: T-G-P6 Worker（chef-worker-reviewer-workflow v1.4.1）
- **Date**: 2026-09-05
- **Task packet**: `Workflow/tasks/T-G-P6.md`
- **Scope**: 交付物 1（真实后端 provider）+ 交付物 2（采集实验工具）+ 交付物 3（测试）+ 验收（build/test 全量 + 复核结论）
- **未执行**: 实机采集实验（M01-M12 验证矩阵、能耗 A/B）——按任务包，实验前 Main 必须再次告知用户具体实验内容并获确认；本 Worker 不运行实验，只交付工具与后端。
- **不 commit/push/tag**；未修改冻结树/AppDelegate/AppMain/AppArguments/KeyboardFocusController/Package.swift。

---

## §1 后端实现（交付物 1）

**文件**: `Sources/PagingPrototypeApp/MultitouchSupportBackend.swift`（新增，编译进 target；运行时仅在四指开关启用且用户确认后由上层 start()，与 ADR-013 §8 区分表一致——本文件不自动启动、不触碰窗口/UI、不申请权限、不弹权限窗）

### 1.1 私有 ABI 接入（按审计文档 §2.2 签名）

- `dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_LAZY)`；失败 → `libraryFactory()` 返回 nil → state `.unavailable`（`lastStartDetail = "dlopenFailed"`），不崩溃。
- 符号（任一缺失 → dlclose + nil，优雅不可用）：`MTDeviceCreateList` / `MTRegisterContactFrameCallback` / `MTUnregisterContactFrameCallback` / `MTDeviceStart` / `MTDeviceStop`。
- `MTTouch` 结构布局逐字段按审计文档 §2.2（frame:Int32 / timestamp:Double / identifier:Int32 / state:Int32 / fingerID:Int32 / handID:Int32 / normalized:MTReadout / size:Float / zero1:Int32 / angle:Float / majorAxis:Float / minorAxis:Float / absolute:MTReadout / zero2:(Int32,Int32) / density:Float；MTReadout = position+velocity，各 MTPoint{x,y}Float）。来源为参考实现 legacy 本机验证注释（R-01 已确认；跨版本不保证）。
- 回调签名 `@convention(c) (MTDeviceRef, UnsafeMutableRawPointer, Int32, Double, Int32) -> Int32`（文件级非捕获 `contactFrameCallback`）。

### 1.2 回调与锁序（§20.2）

- 回调内只做最小拷贝：`MTTouch → RawTouch`（identifier/state/normalized 坐标）快照；合成 + 有界入队持窄锁（NSLock）；`onFrame`/`onStateChange` 锁外派发（回调内可安全 start/stop/restart 重入，测试验证无死锁）。
- 有界缓冲 `BoundedFrameQueue`（maxQueueSize 默认 64，与 Mock 一致）：过载只丢 moved（可压缩），保留 began/ended/cancelled（重新武装条件）；无 moved 可丢时拒绝新帧。
- 交付模式：`.asynchronous`（生产默认，串行派发队列交付，多设备串行消费）/ `.synchronous`（测试用）。drain 循环带竞态防护（drainScheduled 置 false 后复查队列，保证入队帧最终交付或随 stop 丢弃）。

### 1.3 帧合成与设备隔离（§20.1）

- `MultitouchFrameSynthesizer`（纯逻辑，可测）：按设备维护会话状态，合成 began → moved* → ended/cancelled 契约帧；零触点/全部离面 = 结束证据（.ended 空触点）；无会话的 moved/ended/cancelled 拒绝；会话中段新指落面降级为 moved（不重复 began）。
- 触点 state 分类（R-02 待实机核实，采集实验记录分布）：0=未触摸 / 1=began / 2=moved / 3=ended / 4=cancelled / 其他=视为活跃。
- 设备隔离：回调保留 device 参数；全局注册表 `backendRegistry[MTDeviceRef: MultitouchSupportBackend]` 按设备指针路由；每设备独立注册/注销/会话；设备标识 = 进程内不透明 token（PinchDeviceID，不写盘）。
- 单调时间域（§19.3）：首帧锚定 `systemUptime`，后续帧按回调时间戳相对增量换算（`anchorUptime + (callbackTimestamp - anchorCallbackTime)`）；禁 Date()/墙钟差值。

### 1.4 生命周期（幂等 + teardown 顺序）

- start/stop/restart 幂等（start 已启动=no-op、stop 未启动=no-op、restart 无条件 generation+1，与 Mock/识别器一致）；stop/restart 清空缓冲与开放会话、generation+1。
- `startAttempt` 代数防护：.checking 通知后（锁外 dlopen/注册）被 stop/restart 打断时撤销本次注册（不泄漏句柄/设备）。
- teardown 顺序：**先 Unregister 再 Stop 再 dlclose**；dlclose 只在无回调在途时（`inFlightCallbacks` 计数归零，超时 1s 则跳过 dlclose 并记录 `lastTeardownDetail = "dlcloseSkippedInFlightCallbacks"`，安全优先）。**deinit 不 dlclose**（ADR-013 §20.3：不在 deinit 承担主要注销）。
- 状态上报：设备列表为空 → `.noDevice`（并关闭库句柄）；dlopen/符号缺失 → `.unavailable`（lastStartDetail 带原因）；正常 → `.ready`。不申请权限、不弹权限窗（§18.2）；无法区分「未授予」与「从未申请」时如实上报。
- 注入缝（测试）：`libraryFactory`（fake dlopen 结果）+ `DeliveryMode`（fake 帧源直调 `ingestRawTouches` 或经真实 C 回调路径）。

### 1.5 中性计数

`deliveredFrameCount` / `rejectedFrameCount` / `droppedMovedFrameCount` / `stateChangeCount` / `pendingFrameCount` / `lastStartDetail` / `lastTeardownDetail`（不记录坐标/序列号/时间戳原始值）。

---

## §2 复核结论（T-G-P2 评审 Q-2：审计 §2.3/2.4 细节复核）

**复核方式**: 对照 `Docs/FOUR_FINGER_REFERENCE_AUDIT.md` §2.3/§2.4 与 LaunchBetter 白名单参考文件（只读）逐行核对。

**结论: 审计结论无出入**（全部事实与参考文件逐行吻合）：

| 审计 §2.3/2.4 声明 | 参考文件核实 | 结果 |
|---|---|---|
| GestureCaptureEngine 回调频率注释 125-250Hz 系统线程 | `GestureCaptureEngine.swift` L156 注释「125-250Hz 系统线程」 | ✅ 一致 |
| Status .unavailable/.running/.waitingForPermission（L17-21） | 逐行核对 | ✅ 一致 |
| 单一 NSLock 保护全部可变状态（L23）；start/stop/restart 整段持锁（L74-136/L138-154/L257-276） | 逐行核对 | ✅ 一致 |
| running 标志 stop 先置 false 迟到回调丢弃（L167-170） | 逐行核对 | ✅ 一致 |
| receive() 锁内更新最新帧+就地分析（L163-225）；GESTURE_DEBUG 输出 frames/sec+us/frame（L202-212） | 逐行核对 | ✅ 一致 |
| 权限检测：启动后 3s 单次 DispatchSourceTimer，无回调且设备枚举 0 → .waitingForPermission（L122-130/L242-254） | 逐行核对 | ✅ 一致 |
| restart() stop → generation 校验 → start（L257-276） | 逐行核对 | ✅ 一致 |
| ActivationCoordinator 权限弹窗 NSAlert + `x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent`（L166-180） | 逐行核对 | ✅ 一致 |
| 非交互 flag（--smoke 等 20 个）不弹窗（L21-32） | 逐行核对 | ✅ 一致 |
| 热键 keyCode + modifiers 位掩码 cmd=256/shift=512/opt=2048/ctrl=4096（L35-50） | 逐行核对 | ✅ 一致 |
| HotCornerMonitor NSEvent.mouseLocation + NSScreen.frame 24pt 阈值（L52-69/L82-87） | 逐行核对 | ✅ 一致 |
| 旧版冲突 com.Eric-Yang.Launchpad-Back bundle ID 探测（L182-189） | 逐行核对 | ✅ 一致 |
| pinchIn→show / pinchOut→hide（L144-149） | 逐行核对 | ✅ 一致 |
| 审计 §2.2 MTTouch 布局与回调签名 | `MultitouchSupport.swift` L20-36/L49-50 逐字段核对 | ✅ 一致 |

**复核记录**: 本复核由 T-G-P6 Worker 于 2026-09-05 执行，重读 LaunchBetter 白名单 4 文件（MultitouchSupport.swift 205 行 / GestureCaptureEngine.swift 300 行 / ActivationCoordinator.swift 195 行 / PinchAnalyzer.swift 107 行）；未读取白名单外文件；未运行任何采集/设备访问代码。审计文档 §2.3/2.4 无内容性错误，实现可直接按审计结论进行。

---

## §3 工具说明（交付物 2）

**目录**: `Tools/FourFingerCaptureTool/`（独立脚本，不动 Package.swift——Main 独占）

- `main.swift`: CLI 采集工具。启动后实时打印每帧触点计数/state 摘要（中性：只打印计数与状态枚举，不打印坐标原始值）；输入场景名（slow-pinch / fast-pinch / spread / negative）开始一段采集，按 Enter 结束本段（打印该场景统计摘要），Ctrl-C 整体停止（SIGINT DispatchSourceSignal + 优雅收尾）。
- 匿名帧记录：仅内存 + 实验结束后写临时文件 `/tmp/fourfinger-capture-<ISO8601>.jsonl`（含 normalized 坐标——仅实验用途；代码注释与 README 标注实验用途与删除义务）。
- 输出统计（`FourFingerCaptureStats`，Sources/PagingPrototypeApp/FourFingerCaptureStats.swift，可测）：每场景帧数、触点计数分布、会话数（began→ended/cancelled/零触点 moved 闭合序列）、began/moved/ended/cancelled 帧数。
- `build.sh`: `swiftc -O` 编译 app 纯逻辑源文件（PinchRecognizer/TouchProvider/MultitouchSupportBackend/FourFingerCaptureStats）+ main.swift → `/tmp/fourfinger-capture-tool`（已验证构建成功）。
- `README.md`: 用途（R-01/R-02 实验目标）、构建/运行、数据义务、输出格式。

**实验门**: 按任务包，实验前 Main 必须再次告知用户具体实验内容（采集什么、运行多久、数据去向、如何停止），用户确认后才运行。本 Worker 未运行实验。

---

## §4 测试计数（交付物 3）

**文件**（Tests/PagingUITests/，4 个新文件，41 个新测试）：

| 测试文件 | 覆盖 | 计数 |
|---|---|---|
| `MultitouchFrameSynthesisTests.swift` | 帧序列分类（began→moved*→ended/cancelled）、零触点/全离面结束证据、无会话拒绝、中段 began 降级、未知 state 视为活跃、设备隔离、单调时间锚定、触点身份映射 | 14 |
| `BoundedFrameQueueTests.swift` | 有界缓冲丢弃策略（过载只丢 moved 保 begin/end/cancel）、无 moved 拒绝、顺序、removeAll、maxSize 钳制 | 5 |
| `MultitouchSupportBackendTests.swift` | 状态机上报路径（fake dlopen：unavailable/noDevice/ready）、生命周期幂等、teardown 顺序（unregister→stop→dlclose）、stop 后迟到帧丢弃、全链路（fake 帧源→真实 C 回调→合成→缓冲→onFrame）、双设备隔离、异步突发全量交付、回调内 stop/restart 无死锁 | 14 |
| `FourFingerCaptureStatsTests.swift` | 每场景帧数、触点计数分布、会话数（began→ended/cancelled/零触点 moved）、未闭合不计、场景独立、summary 格式 | 8 |

**实测结果**（2026-09-05，独立运行）：

```
swift test --filter "MultitouchFrameSynthesisTests|BoundedFrameQueueTests|MultitouchSupportBackendTests|FourFingerCaptureStatsTests"
  Executed 41 tests, with 0 failures (0 unexpected)
swift test（全量）
  Executed 1403 tests, with 0 failures (0 unexpected) in 18.992 (19.075) seconds
```

- 基线 1362（T-G-P5 评审确认）→ **1403**（+41 新测试），全量 0 failures，exit 0。
- `swift build` 通过（0 errors）。
- 真实后端无法在 CI 测（需真实设备）→ 全部经注入缝（libraryFactory fake dlopen 结果 + FakeMultitouchDevice fake 帧源走真实 C 回调路径）。

---

## 写集合规

新增 9 个文件（2 源 + 4 测试 + 3 工具），零修改冻结树/共享文件（Package.swift/AppDelegate/AppMain/AppArguments/KeyboardFocusController 未触碰，mtime 验证）。不 commit/push/tag。

## 挂账项（供 Main/后续任务）

- 实机采集实验（M01-M12 验证矩阵、能耗 A/B）未运行——需 Main 告知用户实验内容并获确认后执行。
- R-02 触点 state 分类（1/2/3/4）为未核实假设，待采集实验记录 state 分布核实；若分类不符，仅需调整 `MultitouchFrameSynthesizer` 的 `MTTouchState` 常量。
- 后端接入（四指开关启用 + 用户确认后 start()）由 T-G-P4 协调器接线层落实，本任务未接线。

---

## R-02 实机核实（Main/MultitouchSupportBackend 修正前，2026-09-05）

### 证据来源
原始诊断工具 Tools/FourFingerCaptureTool/rawdiag.swift（独立 swiftc 最小实现，不过滤不合成，直接 C 回调打印原始 state/identifier/count）在真实设备（MacBook 内置触控板 26×18）运行 64905 帧：
- 设备 1 台（`*** Recognized (0x6e) family***`），注册成功，回调持续到达。
- **count=4 帧 1848 次**，最大触点 4——系统正常上报 4 触点（如 #64726-64731 连续 6 帧 `count=4 states=[4,4,4,4]` = 四指平放静止）。
- state 直方图：`1:1703 2:290 3:1693 4:81644 5:1592 6:571 7:1703`。
- **无 state=0 触点**（直方图键 1-7；回调从不报 0；离面 = 触点从帧消失 + count=0 空帧）。

### R-02 定案：state 是位掩码，非枚举
- bit2 (4) = 在表面静止（主导，81644 次）
- bit0 (1) = 接触/过渡事件（1/3/5/7 ≈ 各 1600-1700 次，边界帧）
- bit1 (2) = 移动事件（2/6 = 290+571 次，移动帧）
- state∈[1,7]（含 4/5/6/7 = 在表面；1/2/3 = 不在表面但有事件位）
- state=0 不会出现在回调帧（旧注释「0=未触摸」不适用；离面表示=触点从帧消失）

### 旧假设错误与后果
旧 `MTTouchState`（0=notTouching/1=began/2=moved/3=ended/4=cancelled）与合成器 state 值判定（hasCancelled=state==4、hasBegan=state==1、hasEnded=state==3）：
- 四指平放帧 state=[4,4,4,4] 被合成器判 hasCancelled → 每帧关会话 → 主工具实测 moved=0、会话数异常。
- state=1 只在离面过渡出现 → hasBegan 在真实平放/捏合中永不触发（began 只能由「会话未开 + active 非空」路径偶然触发）。

### 修正方案（Worker 5e7dbd26 执行中）
1. `MTTouchState` 改为位掩码常量：onSurfaceBit=4 / contactEventBit=1 / moveEventBit=2；notTouching=0 保留；旧 began/moved/ended/cancelled 常量删除或 OBSOLETE。
2. `MultitouchFrameSynthesizer`：began/ended 判定改**帧间触点 identifier 集合 diff**（per-device lastContactIdentifiers）：
   - 会话未开 + active 非空 → .began
   - 会话开 + active 空/touches 空 → .ended（结束证据）
   - 会话开 + 全部新 identifier → 重锚 .began；部分新 → .moved
   - 会话开 + identifier 全部消失 → .ended；部分消失 → .moved
   - 其余（无边界）→ .moved；无会话拒绝
   - 取消 cancelled 概念（ABI 无证据）；单调时间锚定与 contactIDs 映射不变。
3. 测试按真实位掩码 state 值更新 + 新增四指平放连续帧用例；全量 swift test 0 failures；工具重建验证编译。

---

## R-02 修正落地（Worker 5e7dbd26，2026-09-05）

### 改动文件

| 文件 | 改动 |
|---|---|
| `Sources/PagingPrototypeApp/MultitouchSupportBackend.swift` | `MTTouchState` 改位掩码常量（删除旧 began/moved/ended/cancelled）；`MultitouchFrameSynthesizer` 改帧间 identifier 集合 diff；`DeviceState` 增 `lastContactIdentifiers: Set<Int32>`；文件头 R-02 注释更新 |
| `Tests/PagingUITests/MultitouchFrameSynthesisTests.swift` | 14 → 18 用例：fake 帧源 state 改用真实位掩码（4=静止/5=接触/6=移动/7=接触+移动）；删除 cancelled 语义用例与「无会话 moved 拒绝」（新语义下任意非零 state 帧自动开会话）；新增四指平放 [4,4,4,4]×6 → began1+moved5、state=4 会话中帧 = moved 非 cancelled、触点消失 → ended、全部新 identifier 重锚 began、部分消失保持剩余触点 |
| `Tests/PagingUITests/MultitouchSupportBackendTests.swift` | 14 → 15 用例：mtTouch state 1/2/3 → 5/6 + 空帧 ended；`testTwoDevicesIndependentSessions` 的无会话拒绝改用空帧；新增全链路 `testFullPipelineFourFingerRestNotCancelled`（[4,4,4,4]×6 → began1+moved5） |

### 新逻辑说明（帧间 diff 规则，per-device）

- 活跃判定：`state != 0`（保留）；`activeIdentifiers = Set(active.map(\.identifier))`
- 会话未开 && active 非空 → `.began`（记录集合，会话开）
- 会话开 && active 空 / touches 空 → `.ended`（结束证据；关会话、清集合）
- 会话开 && active 非空：
  1. 全部触点均为新 identifier → `.began` 重锚定（身份映射随会话重置；「全部消失 + active 非空 ⟺ 全部新出现」，重锚定优先于关会话——触点仍在表面时关会话会使识别器丢失一帧）
  2. 部分触点消失 → 该触点即 ended（注销其身份映射，重现身 = 新触点）；剩余触点继续 → `.moved`（仅当会话中触点全部消失才关会话）
  3. 其余（无 began 边界、无消失）→ `.moved`
- cancelled 概念删除（ABI 无证据；触点消失即 ended）；无会话 ended（空帧）拒绝
- 单调时间锚定（`anchorUptime + (callbackTimestamp - anchorCallbackTime)`）与 contactIDs 身份映射算法**保持不变**（映射逻辑提取为 `private static mapContacts`，仅在重锚定前清空映射）

### 测试结果

```
swift test --filter "MultitouchFrameSynthesisTests|MultitouchSupportBackendTests"
  Executed 33 tests, with 0 failures (0 unexpected)   （18 合成 + 15 后端）
swift test --filter "…|BoundedFrameQueueTests|FourFingerCaptureStatsTests|MockTouchProviderTests|TouchProviderLifecycleTests|TouchProviderIntegrationTests|PinchRecognizerTests|PinchRecognizerLifecycleTests"
  Executed 129 tests, with 0 failures (0 unexpected)
swift test（全量）
  Executed 1408 tests, with 0 failures (0 unexpected) in 22.212 seconds
swift build
  0 errors（Build complete）
swiftc -O … -o /tmp/fourfinger-capture-tool（工具重建，仅验证编译）
  成功（316232 字节）
```

- 基线 1403 → **1408**（+5：合成 +4、后端 +1）。全量 0 failures，exit 0。
- 冻结树零触碰（mtime 核验：PagingCore/PagingTelemetry/PagingUI/AppCatalogCore/MacAppCatalog/AppIconPipeline/AppGridUI/Package.swift/AppLaunchController/AppDelegate/AppMain/AppArguments 均早于本次会话开始）；不 commit/push/tag。
- Tools/FourFingerCaptureTool/main.swift 未改（消费 PinchFrame phase，不依赖原 state 枚举）；touch 语义变更仅由合成器承担。

### 偏差说明

1. 「无会话 moved 拒绝」路径随新语义自然消失：任意非零 state 帧在无会话时按规格「会话未开 && active 非空 → .began」开会话，不再存在「moved 无会话」输入形态；拒绝仅剩空帧（ended）路径。原 `testMovedWithoutSessionRejected` 改为 `testActiveFrameWithoutSessionOpensSession`。
2. 全部消失 + 本帧有活动触点时优先重锚 `.began` 而非 `.ended`（规格两条款描述同一帧；按「全部新出现 → .began 重开会话（首帧类场景/重锚定）」执行，避免触点仍在表面时误关会话）。
3. 消失触点的 `contactIDs` 映射按「该触点 ended」语义注销（重现身获得新 PinchContactID）；映射算法本身未变。

## §R-03 实机采集验证（2026-09-05 22:36，slow-pinch 8168 帧）

### 合成器修正验证（通过）
- 场景统计：`sessions=182 began=182 moved=7804 ended=182 cancelled=0`（began/ended 平衡，cancelled=0）
- 4 触点帧 403 帧（ID 恒定 (237,238,239,240) 零变化）
- 四指段扩散度 0.3328 → 0.1571（缩小 52.8% = 真实捏合动作）
- 数据文件 /tmp/fourfinger-capture-2026-09-05T14-36-13Z.jsonl（8168 帧，实验后删除）

### 识别器端到端回放（离线，ReplayClock 推进到帧时间戳）
- 基线参数（maxGestureDuration=1.5s）：**fired=0**
  - 轨迹：candidate(1001917.754) → recognizing(1001918.058, baselineRadius=0.3236) → waitingForRelease(1001919.258)
  - **根因：timeLimitExceeded**——候选创建到捏合开始 1.6s > 1.5s 上限，候选在捏合开始前 0.1s 被取消
  - 确认 T-G-P1 Q-3 挂账（慢速连续捏合永不触发）
- maxGestureDuration=5.0s：**fired=1**（1001919.362 触发）
  - 轨迹：candidate(1001917.754) → recognizing(1001918.058) → fired(1001919.362)
  - 收缩判定正确（基线 0.3236 → 捏合 0.1571 = 51.4% > 15% 阈值）

### 参数定案建议（§19.2，待 Worker 实施 + Reviewer 评审）
- **maxGestureDuration: 1.5s → 3.5s**（覆盖慢速手势：平放 1.6s + 捏合 1.6s；候选创建=第 4 指落下时刻）
- 其余参数暂定值保持（4/0.1/0.15/0.15/3.5/0.02/0.5/8/0.02/0.5），待 fast-pinch/spread/negative 场景补充证据

### 回放工具教训
- ReplayClock 必须引用类型（class）：PinchRecognizer 持有 clock 拷贝，值类型 advance 只改外部拷贝 → 识别器内 now()=0 → 全部帧判「未来帧」拒绝（rejected=8168）
- 识别器 init 后 state=.disabled，必须 start() 才接收帧
- 参数扫描实验（值类型时钟）全部无效，引用时钟后重跑

## §R-04 fast-pinch 实机诊断（2026-09-06 14:14，471 帧，6 段 4 触点）

- 场景统计：`sessions=14 began=15 moved=442 ended=14 cancelled=0`；4 触点段 6 段（24-29 帧 ≈ 0.2s），ID 全恒定
- **6 段全部 candidate → waitingForRelease（0.2s 内取消，从未 recognizing）**
- 半径曲线：全部收缩 47-57%（远超 shrinkThreshold 15%）
- **稳定帧（位移<2%基线半径）最长连续 0-3 帧（需 12 帧=0.1s）→ 稳定窗口永不满足**
- **结论：快速捏合=全程移动无静止段，稳定窗口+noise 重锚定模型只能识别 slow-pinch（先静止后捏合，§R-03 已验证触发）**
- 架构级缺陷：识别器时间模型不适应主要使用场景（快速捏合）
- 候选调整方向（待 Chief/用户决策）：
  - A 首帧基线+位移容忍（最小改动，风险=落指跳动误判）
  - B 滑动/窗口收缩对比（cur vs W 帧前半径，兼顾快慢，推荐）
  - C 混合双路径（慢速精细+快速直接，最稳但复杂）
  - 参数：maxGestureDuration 1.5→3.5s（§R-03 定案）

## §R-05 识别器重构：首帧基线 + 相对收缩（2026-09-06，用户指示参照 LaunchBetter PinchAnalyzer 模型）

### 决策依据
- 用户指示（events.jsonl #824 decision_recorded）：参照 LaunchBetter PinchAnalyzer 模型（首帧基线 startDistance、无稳定窗口、无噪声容忍、无重锚定），候选段首帧即建基线，逐帧按相对收缩判定。
- §R-04 实机证据：快速捏合全程移动，6/6 段 0.2s 内取消、从未 recognizing；稳定帧最长连续 0-3 帧（需 12 帧）；半径实际收缩 47-57%。旧模型只能识别 slow-pinch。

### 改动摘要（Sources/PagingPrototypeApp/PinchRecognizer.swift）
1. **判定模型**（advanceCandidate/advanceRecognizing）：
   - 候选段首帧（恰好 4 触点）用既有 `radius(of:)`（质心平均距离）建立基线半径；`baselineRadius` 首帧固定，全程不再重锚定。
   - 次帧起 `advance()` 转 `.recognizing` 逐帧判定：`(baselineRadius - currentRadius) / baselineRadius >= shrinkThreshold` → 触发（快速捏合次帧即可触发）；`<= -expansionCancelThreshold` → 扩张取消（pinchOut 无 Hide，保留）。
   - 首帧保留 `.candidate` 相位（基线建立帧），次帧转 `.recognizing`——七态状态机全部相位保持可观察、可测；首帧收缩量恒为 0 不判定。
2. **参数**（PinchParameters，§19.2 合同 3 说明随删随更）：
   - 删除 `baselineStableWindow`（原默认 0.1）、`noiseTolerance`（原默认 0.02）及对应 init 参数/文档注释。
   - `maxGestureDuration` 默认 **1.5s → 3.5s**（§R-03 定案：慢速手势候选到触发 1.6-3.2s，1.5s 在捏合开始前取消）。
   - 其余保持：requiredContactCount=4 / shrinkThreshold=0.15 / expansionCancelThreshold=0.15 / cooldown=0.5 / maxContactCount=8 / minBaselineRadius=0.02 / dataExpiryInterval=0.5。
3. **状态**（PinchDeviceSession）：删除 `windowStartedAt`、`baselinePositions`（重锚定状态）；新增 `contactIDs: Set<PinchContactID>`（承接 P08 触点更换判定，语义不变：首帧后 ID 集合变化 → contactReplaced 取消）。`minBaselineRadius` 退化几何检查从「窗口完成时」提前到**首帧**（首帧半径 < 0.02 立即取消）。
4. **保留未动**：严格 4 指（P04/P07）、触点 ID 更换取消（P08）、触点数变化取消锁存（P04/P07）、扩张取消（P17）、冷却 0.5s（单调时钟、识别器级、跨会话跨设备）、时间上限 3.5s、设备隔离（P09/generation）、静默恢复两档（candidate/recognizing 保守重置 .dataExpired、锁存保持）、validateFrame/rejectedFrameCount/timeEpsilon=1e-9、七态状态机、PinchEvent 仅 .showRequested、PinchEventToken。

### 阈值选择理由（shrinkThreshold = 0.15，未改）
- 实测 6 段快速捏合收缩 47-57%，余量远大于 15%；0.15 相对 LaunchBetter 参考值 0.18 更灵敏（更快触发、更抗 120Hz 采样差异），且 0.15 ≤ 0.18 ≤ 0.20 同一档位内，误触风险由扩张取消/时间上限/冷却三道既有防线兜底。保持 0.15（用户授权区间 0.15-0.20 下界）。
- 冷却保持 0.5s 单调时钟（现有 §19.2 合同 7 定案值），未采用 LaunchBetter 0.2s 墙钟——见偏差 2。

### 测试更新（Tests/PagingUITests/）
- **PinchRecognizerTests.swift**：
  - 改写稳定窗口语义用例：`testP05FourFingerTranslationDoesNotTrigger`（平移首帧基线后直接进入判定，半径不变永不触发/永不取消，删除「停住 0.1s 完成窗口」段落）；`testP11NearZeroBaselineRadiusCancels`（近零半径现在**首帧**即取消）；`testP05MicroJitterDoesNotTrigger`/`testP06`/`testContract2`/`testP12` 注释与断言消息按新语义更新。
  - 新增 3 用例：`testFastPinchNoStableFrameTriggers`（连续移动、每帧位移超旧噪声容忍 ≈0.0057、无静止帧，收缩 0.20 ≥ 0.15 次帧后触发，零取消）；`testSlowPinchStartsWithRestThenContractsTriggers`（先平放 1.6s 再捏合 → 触发，证明 1.6s 候选→触发在 3.5s 上限内，旧 1.5s 会取消）；`testDefaultMaxGestureDurationIs3Point5Seconds`（默认 3.5s 边界内保持、超限 .timeLimitExceeded 锁存）。
  - 保留并全绿：严格 4 指/5 指取消、触点/设备更换、扩张取消（P17）、冷却（生产参数用例）、时间上限专项（0.5s 定制参数）、设备隔离、静默恢复、锁存、乱序/过期/畸形拒绝。
- **PinchRecognizerLifecycleTests.swift**：仅 P15 注释更新（candidate→recognizing 语义）；10 用例全绿。
- **TouchProviderIntegrationTests.swift / FourFingerActivationCoordinatorTests.swift**：零改动（.began→.candidate 断言与协调器 .fired/.waitingForRelease 锁存判定在首帧基线语义下保持不变），全绿。

### 测试计数
- 过滤运行（--filter PinchRecognizer/TouchProviderIntegration/FourFingerActivationCoordinator）：**75 tests，0 failures**（PinchRecognizerTests 38 / PinchRecognizerLifecycleTests 10 / FourFingerActivationCoordinatorTests 20 / TouchProviderIntegrationTests 7）。
- 全量 `swift test`：**1411 tests，0 failures（0 unexpected）**（基线 1408 + 新增 3）。
- `swift build`：**Build complete，exit 0**（前后两次均通过）。

### 偏差披露
1. **LaunchBetter「触发后更新 startDistance」不适用**：本状态机锁存 `.fired`（合同 6：一会话一次），触发后不再判定该会话，故无「触发后重设基线」语义；等价安全由冷却 + 释放后新会话重建基线承担。
2. **冷却 0.5s（单调时钟）而非 LaunchBetter 0.2s（墙钟）**：既有 §19.2 合同 7 值，用户指示仅要求「单调时钟、识别器级」，未指示改值；保守值防快速连续误触。
3. **退化几何检查提前到首帧**：minBaselineRadius 语义从「窗口完成时」变为「首帧即检」，属安全收严；`testP11NearZeroBaselineRadiusCancels` 相应改写并确认。
4. **Docs 契约文本未改（超写范围）**：`Docs/PHASE1G_ACTIVATION_ENTRY_HOT_CORNER_PROMPT.md` L1401-1402 与 `Docs/ADR-013-FOUR-FINGER-ACTIVATION-BACKEND.md` L41-42 仍文字性要求「短稳定窗口 + 噪声容忍」，本次仅更新代码内 §19.2 参数说明（任务写范围 = 识别器 + 测试 + 本结果文件）。提请 Main/Chief 后续同步 Prompt/ADR 契约文本（建议记为 ADR-013 修订条目）。`Workflow/reviews/T-G-P1-r1.md` 为历史旧语义评审记录，未改。
5. **冻结树 & 纪律**：改动仅限 `Sources/PagingPrototypeApp/PinchRecognizer.swift`、`Tests/PagingUITests/PinchRecognizerTests.swift`、`Tests/PagingUITests/PinchRecognizerLifecycleTests.swift`、`Workflow/results/T-G-P6.md` 四个文件；未 commit/push/tag；未改 AppDelegate/AppMain/AppArguments。冻结树 mtime 核验（改动前后一致）：Sources/PagingCore 2026-08-30 10:46:02、PagingTelemetry 2026-08-28 20:09:02、PagingUI 2026-08-30 14:15:30、AppCatalogCore 2026-08-28 19:50:22、MacAppCatalog 2026-08-28 20:01:55、AppIconPipeline 2026-08-28 23:22:40、AppGridUI 2026-09-03 13:52:19、Package.swift 2026-08-28 19:42:55、AppLaunchController.swift 2026-08-28 20:46:54。
6. Tools/FourFingerCaptureTool 未重建：main.swift 不引用已删参数（全仓 grep `baselineStableWindow|noiseTolerance` 仅剩本文件说明性注释/历史文档），SwiftPM 目标构建已覆盖。

## §R-06 重构后实机回放验证（2026-09-06，Main 独立执行）
- 回放工具：/tmp/replay3/main.swift（ReplayClock class 可推进时钟 + PinchRecognizer 直接编译，swiftc -O）
- fast-pinch（/tmp/fourfinger-capture-2026-09-06T14-14-03Z.jsonl，471 帧 6 段）：**fired=6** @1086475.762,1086477.410,1086479.154,1086480.698,1086482.218,1086483.858（6 次快速捏合全部触发；旧稳定窗口模型 0 次）
- slow-pinch（/tmp/fourfinger-capture-2026-09-05T14-36-13Z.jsonl，8168 帧）：**fired=1** @1001919.354（单次触发正确）
- 结论：首帧基线+相对收缩模型（T-G-P6-r2 评审 PASS）在实机数据上验证通过：快速/慢速均触发、无重复触发、无假触发（8168 帧慢速长序列仅 1 次）
- 待验证：spread 张开（应不触发）、negative 负样本（单指/五指/移动）、M04/M05 抖动负样本（评审 QUESTION-1 敞口）

## §R-07 负样本实机验证（2026-09-06，Main 独立执行）
- spread（/tmp/fourfinger-capture-2026-09-06T14-56-32Z.jsonl，2536 帧）：**fired=0** ✓；6 个 4 触点会话扩散比 +1.176~+1.959（真实张开 118-196%），识别器全部正确拒绝（张开不触发=用户决策）
- negative（/tmp/fourfinger-capture-2026-09-06T14-59-35Z.jsonl，1970 帧）：**fired=0** ✓；触点分布 {0:28,1:1204,2:14,3:259,4:2,5:463}（单指 1204/三指 259/五指 463/四指仅 2 帧），28 会话零误触
- 实机验证汇总：fast-pinch fired=6/6 ✓、slow-pinch fired=1 ✓、spread fired=0 ✓、negative fired=0 ✓
- 评审 QUESTION-1（落指抖动帧假触发敞口）：spread/negative 已覆盖张开+单指+三指+五指零误触；「快速落指不捏合」场景未单独采集（M04/M05 实机矩阵补）
- 工具写入时机确认：Enter 只结束场景（统计不落盘），quit 才写盘退出（main.swift L199-223）

## §R-08 M-1 修复：静默过期移除会话后刷新聚合状态（T-G-P7，2026-09-06）

### 背景
- T-G-P6-r2 评审 MINOR-1（`Workflow/reviews/T-G-P6-r2.md` M-1）：`process()` 静默过期分支（候选/识别中静默超限 → `sessions.removeValue` + `recordCancel(.dataExpired)`）未调用 `refreshAggregateState()`；若同帧触点数 ≠ 4，无会话分支提前 `return []`，`state` 可观察属性停留在 `.candidate/.recognizing` 而 `sessions` 已空。评审 /tmp scratch driver 复现：`state=candidate` + `dataExpired=1`。无事件/触发/安全影响，仅观察面不一致。

### 改动摘要
- **`Sources/PagingPrototypeApp/PinchRecognizer.swift`**（1 行修复 + 注释）：静默过期分支 `.candidate/.recognizing` 移除会话后立即 `refreshAggregateState()`（L374-376），与 `deviceDisconnected`/`endSession` 移除路径一致。锁存分支（`.fired/.waitingForRelease`）不刷新（会话未移除，状态本就一致）。
- **`Tests/PagingUITests/PinchRecognizerTests.swift`**（+1 用例）：`testM1SilentExpiryWithNonFourContactsRefreshesToIdle` —— 构造评审复现场景：t=0 四指 → `.candidate`；静默超限（0.6s > 0.5s）后同帧仅 2 触点（≠4）→ 断言 `state == .idle`、`activeSessionID/activeDeviceID == nil`、`cancelCounts[.dataExpired] == 1`、零事件零触发；随后 4 触点帧 → 新候选 `.candidate`，结束证据 → `.idle`（识别器功能不受影响）。

### 测试计数
- 过滤 `swift test --filter PinchRecognizer`：**Executed 49 tests, 0 failures (0 unexpected)**，exit 0（PinchRecognizerTests 39 = 38+1 新增 / PinchRecognizerLifecycleTests 10；评审基线 48 + 1）。
- 全量 `swift test`：**Executed 1412 tests, 0 failures (0 unexpected)**，18.5s，exit 0（评审基线 1411 + 1）。
- `swift build`：**Build complete, exit 0**。

### 冻结树核验（改动前后一致）
- Sources/PagingCore 2026-08-30 10:46:02、PagingTelemetry 2026-08-28 20:09:02、PagingUI 2026-08-30 14:15:30、AppCatalogCore 2026-08-28 19:50:22、MacAppCatalog 2026-08-28 20:01:55、AppIconPipeline 2026-08-28 23:22:40、AppGridUI 2026-09-03 13:52:19、Package.swift 2026-08-28 19:42:55、AppLaunchController.swift 2026-08-28 20:46:54。
- 本次会话触碰文件 = 仅 `PinchRecognizer.swift` / `PinchRecognizerTests.swift` / 本结果文件 3 个；未 commit/push/tag。
