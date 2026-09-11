# T-worker-b-runloopprofile — runloop 级主线程探针（--frame-profile 同开）

**Worker**: worker-frameprofile（deepseek-v4-flash:0731, max）
**任务**: t21（Worker RunLoopProfile：runloop 级主线程探针）
**日期**: 2026-08-29
**背景依据**: Main 已分析 phys1b-05 + SELFDRIVE 对照 —— 帧回调内耗时 max 2.7ms（人手）/ 31.7ms 一次（SELFDRIVE 密集连翻，view 段），帧回调路径基本健康；帧间隔仍有偶发 20–53ms 卡顿（真实/中性内容都有），发生在帧回调之外：主线程其他 runloop 工作（图标写回、布局、绘制提交、其他 source）或系统调度。
**Scope（互斥）**: `Sources/PagingUI/RunLoopProfileRecorder.swift`（新建）、`Sources/PagingPrototypeApp/`（AppDelegate 接线 + AppArguments 帮助文本）、`Tests/PagingUITests/RunLoopProfileTests.swift`（新建）、`Workflow/results/T-worker-b-runloopprofile.md`（本文件）
**未触碰**: Package.swift / PagingCore / PagingTelemetry（契约零改动，17 必需 + 7 可选冻结未动）/ AppCatalogCore / MacAppCatalog / AppIconPipeline / AppGridUI / Docs / PROVENANCE / Workflow（结果文件除外；未运行 record_workflow_event.py）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（亲笔声明：未读取任何禁止来源；仅依据 Main 任务指令、PagingPrototype 既有源码/测试/ADR 与 Workflow 结果文件）

---

## 一、改动摘要

| 文件 | 变更 |
|---|---|
| `Sources/PagingUI/RunLoopProfileRecorder.swift`（新建） | CFRunLoopObserver 主线程探针：活动掩码 entry/beforeTimers/beforeSources/beforeWaiting/afterWaiting/exit；每次观察记录 timestamp + activity + gap_ns + since_same_ns（纳秒级 ContinuousClock）；内存缓冲 + 阈值批量落盘；默认关闭（isActive == false 时零观察者、零文件、零逻辑参与） |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `--frame-profile` 同开 runloop 探针：创建 `RunLoopProfileRecorder(runID: session.runID, active: true)` + `start()`，stdout 打印文件路径；teardownAll 移除观察者 + 落盘 |
| `Sources/PagingPrototypeApp/AppArguments.swift` | 帮助文本（文件头注释 + helpText）说明 `--frame-profile` 同时输出 runloop 探针文件 |
| `Tests/PagingUITests/RunLoopProfileTests.swift`（新建） | 6 个测试（缺省关闭 / 文件命名 / 净化 / 观察记录与阶段结构 / start-stop 幂等 / 帮助文本） |

**参数接线决策**：复用 `--frame-profile`（不新增 `--runloop-profile`）——runloop 探针回答"帧回调之间主线程做了什么"，与帧探针同属一个诊断会话；单开关 = 单接线点，参数表面零新增（既有 `--frame-profile` 解析测试已覆盖）。smoke 行无需同步（无新参数）。

**默认路径零行为变化**：`--frame-profile` 缺省时两个 recorder 均不创建（AppDelegate 不接线），无观察者注册、无文件、无测量。

## 二、观察者设计（活动掩码 / 阶段定义）

CFRunLoopObserver 注册到主 runloop（`.commonModes`，与帧驱动 timer 同源），repeats = true，order = 0。

**环境事实（实测，e2e-rlp-001 81,585 条记录）**：
1. 本环境 SDK 的 CFRunLoop.h 被裁剪（缺 `kCFRunLoopAfterTimers`(1<<3) 与 `kCFRunLoopAfterSources`(1<<4)），且**运行时也不投递这两个活动**——实测观察序列为 `beforeTimers → beforeSources → beforeWaiting → afterWaiting → exit`（entry 在 runloop 进入时一次）。
2. **本环境 runloop 先做工作再发 before* 观察**：帧驱动 timer 回调实测落在 `afterWaiting → beforeTimers` 段（帧 begin 在 afterWaiting 后 ~21µs，帧 end 在 beforeTimers 前 ~35µs；beforeTimers 的 gap_ns ≈ 帧回调耗时 + 唤醒开销，与 FrameProfileRecorder 的 total_ns 交叉验证一致）。
3. 本环境 runloop 高频 exit/entry（自驱模式 ~700 次/秒；真实 app.run() 单次进入，无此现象）——exit/entry 是自驱/环境 artifact，非主线程工作。

**阶段映射（本环境实测）**：

| 相邻观察对 | 阶段含义 | 卡顿归因 |
|---|---|---|
| `afterWaiting` → `beforeTimers` | **主线程工作**（timer + source 处理；帧驱动 timer 在此段触发；beforeTimers 的 gap_ns ≈ 帧回调耗时 + 其他工作） | 主线程忙（timer/source 风暴） |
| `beforeTimers` → `beforeSources` → `beforeWaiting` | 观察器开销（实测微秒级） | 通常可忽略 |
| `beforeWaiting` → `afterWaiting` | **线程睡眠**（调度延迟，非主线程工作） | 系统调度/空闲 |
| `exit` → `entry` | runloop 重新进入（本环境高频；自驱/环境 artifact） | 非主线程工作 |

**记录字段**（每行一条 JSON，sortedKeys）：
- `activity`：entry/beforeTimers/beforeSources/beforeWaiting/afterWaiting/exit
- `timestamp`：systemUptime（秒，6 位小数；与帧 profile 同时钟基，可跨文件关联）
- `gap_ns`：自上次观察以来（相邻观察对界定阶段耗时）
- `since_same_ns`：自上次同活动以来（活动周期，如 beforeTimers 周期 ≈ 帧周期）

## 三、输出格式

- 文件：`/tmp/launch-copy-paging-prototype-<run-id>-runloop.jsonl`（runID 净化规则同 FrameProfileRecorder/PagingTelemetry；独立文件，不与帧 profile 混频）
- 每行示例：`{"activity":"beforeTimers","gap_ns":355200,"kind":"runloop","since_same_ns":16666666,"timestamp":123456.789012}`
- stdout 摘要：`paging-runloop-profile: <文件路径>`（与 `paging-frame-profile:` 相邻打印）
- 落盘策略：内存缓冲（上限 20,000 条）+ 阈值批量写（512 条触发；观察回调内不做 I/O）+ teardown 显式 flush；写失败计数不崩溃
- 隐私：纯耗时测量，无 app 名/路径/图标数据

## 四、测试证据

### 新增 `RunLoopProfileTests.swift`（6 测试，全绿）
1. `testRunLoopProfileDefaultOff` — 未激活：start() 不注册观察者（isObserving == false）、flush 后无文件、recordCount == 0
2. `testRunLoopProfileFileNaming` — 缺省文件名 `launch-copy-paging-prototype-<runID>-runloop.jsonl`、目录 /tmp
3. `testRunLoopProfileSanitizedRunID` — 净化规则（空格/斜杠 → `_`、空 → `run`）
4. `testRunLoopProfileRecordsActivities` — 主 runloop 转 50ms：产生观察记录，activity ∈ 已知集合，timestamp/gap_ns/since_same_ns 合法；阶段结构断言（beforeTimers→beforeSources 相邻、beforeSources→beforeWaiting 相邻）
5. `testRunLoopProfileStartStopIdempotent` — 重复 start/stop 安全（不重复注册、不崩溃）
6. `testRunLoopProfileHelpTextMentionsRunLoop` — 帮助文本含 `--frame-profile` 与 runloop 说明

### 回归
| 项 | 结果 |
|---|---|
| PagingUITests（既有 127 + 新增 6） | ✅ **133/133** 全绿（0 failure） |
| 全量 `swift test` | ✅ **435/435** 全绿（0 failure，≥429 要求达成；6 次全量运行中 5 次全绿，1 次命中既有性能阈值 flake，见下） |
| `swift build -c release` | ✅ exit 0，**零警告**（PagingPageContent Sendable 警告未回归） |
| 端到端（GUI 自驱 40 flings + --frame-profile，e2e-rlp-001） | ✅ 两个文件均产出（frame 519 条 + runloop 81,585 条），stdout 打印两路径 |

### 既有性能阈值 flake（非本任务引入，如实上报）
- 测试：`PagingPerformanceProbeTests.testPureCoreFlingCostWellBelowFrameBudget`（Tests/PagingUITests/PagingPerformanceProbeTests.swift:64，`XCTAssertLessThan(surfaceMean, 1_000)`）。
- 现象：6 次全量运行中 1 次失败——surfaceCoreMeanUs = 1026.4µs vs 1000µs 预算（2.6% 超限，机器负载噪声）；其余 5 次全绿。
- 与本任务无关的证据：该测试只驱动 PagingCore（本任务未触碰 PagingCore）；surface 的 frameProfiler 缺省 nil（零测量）；RunLoopProfileRecorder 仅 --frame-profile 时创建（单测不触发）。隔离运行 5/5 全绿（mean 151–554µs）。
- 处置建议：阈值属 T-step8 性能探针任务所有，未擅自放宽；建议 Main 视需要派 follow-up（如加容差或降采样）。

### 端到端分析能力演示（e2e-rlp-001）
- runloop 记录 81,585 条：entry 13,400 / beforeTimers 13,988 / beforeSources 13,988 / beforeWaiting 13,405 / afterWaiting 13,405 / exit 13,399（自驱模式高频 exit/entry）。
- 工作段（afterWaiting→beforeTimers，beforeTimers 的 gap_ns）：median 4.1µs，p99 415µs，max 176ms（启动/收尾 artifact）。
- 睡眠段（beforeWaiting→afterWaiting，afterWaiting 的 gap_ns）：median 7.6µs，p99 14.6ms，max 734ms（自驱 fling 间停顿）。
- 交叉验证：帧 begin 在 afterWaiting 后 ~21µs、帧 end 在 beforeTimers 前 ~35µs → beforeTimers 的 gap_ns 与帧 profile 的 total_ns 同源（本环境 timer 工作段）。
- 结论：**帧间隔 >20ms 的卡顿窗口内，查 beforeTimers 的 gap_ns（主线程忙）vs afterWaiting 的 gap_ns（调度延迟）即可归因**——探针达成目标分析能力。

## 五、给 Main 的备注

1. **分析脚本建议**：按 timestamp 关联 `-profile.jsonl`（帧 total_ns）与 `-runloop.jsonl`；帧间隔 >20ms 时查该窗口内 runloop 记录——`beforeTimers` 的 gap_ns 大 → 主线程忙（timer/source 工作，含帧回调本身）；`afterWaiting` 的 gap_ns 大 → 调度延迟（主线程空闲）。
2. **环境 SDK/运行时裁剪事实**：CFRunLoop.h 缺 afterTimers/afterSources 位且运行时不投递；且本环境 runloop 先做工作再发 before* 观察（帧 timer 落在 afterWaiting→beforeTimers 段）。若后续换标准环境，观察序列会变为标准 8 活动序（beforeTimers→afterTimers = timer 工作；beforeSources→afterSources = source 工作），阶段映射需按标准序重新解释；记录格式不变。
3. **exit/entry 高频是自驱 artifact**：真实 app.run() 单次进入 runloop，无 exit/entry 风暴；分析真实运行数据时忽略 exit/entry 对。
4. **探针独立于 telemetry**：PagingTelemetry 契约零改动；runID 复用 session 自动生成值仅为文件名唯一性。
5. **不自我认证 PASS**：本文件为结果报告，PASS 判定归 Reviewer/Main。
