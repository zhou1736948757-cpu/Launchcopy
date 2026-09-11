# T-worker-b-frameprofile — 帧路径耗时探针（--frame-profile 诊断模式）

**Worker**: worker-frameprofile（deepseek-v4-flash:0731, max）
**任务**: t20（Worker FrameProfile：帧路径耗时探针）
**日期**: 2026-08-29
**背景依据**: Main 已分析 phys1b-03/04 telemetry —— 卡顿帧（frame_interval > 20ms，偶发 20–48ms）全部发生在 gesture.changed / transition / momentum 期间；与图标加载（启动 1s 内完成）零重叠；与 layout 零共现（0/50、0/21）；无周期性（排除 GC）。卡顿在交互/渲染路径（输入处理 → 状态机 → 视图更新），具体环节未知 → 本任务加耗时探针定位。
**Scope（互斥）**: `Sources/PagingUI/`（FrameProfileRecorder.swift 新建 + PagingSurface.swift 插桩）、`Sources/PagingPrototypeApp/`（AppArguments/AppMain/AppDelegate）、`Tests/PagingUITests/`（FrameProfileTests.swift 新建）、`Workflow/results/T-worker-b-frameprofile.md`（本文件）
**未触碰**: Package.swift / PagingCore / PagingTelemetry（契约零改动，17 必需 + 7 可选字段冻结未动）/ AppCatalogCore / MacAppCatalog / AppIconPipeline / AppGridUI / Docs / PROVENANCE / Workflow（结果文件除外；未运行 record_workflow_event.py）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（亲笔声明：未读取任何禁止来源；仅依据 Main 任务指令、PagingPrototype 既有源码/测试/ADR 与 Workflow 结果文件）

---

## 一、改动摘要

| 文件 | 变更 |
|---|---|
| `Sources/PagingUI/FrameProfileRecorder.swift`（新建） | 帧路径耗时探针：纳秒级（ContinuousClock）阶段计时、内存缓冲 + 阈值批量落盘、JSONL 输出、runID 净化、phase 描述；默认关闭（isActive == false 时全部方法 no-op） |
| `Sources/PagingUI/PagingSurface.swift` | 新增 `public var frameProfiler: FrameProfileRecorder?`（缺省 nil = 零测量零开销）；`advanceFrame` 插桩（input/state/view/total 四阶段）；`handleScrollInput` 插桩（kind=input 记录）；`apply` 内 core 调用与 onGestureEvent 经 `profileCoreWork`/`profileViewWork` 包裹（探针不参与逻辑）；4 个 core 事件同步回调（handleCoreState/Offset/TransitionBegin/Commit）经 viewWork 计时 |
| `Sources/PagingPrototypeApp/AppArguments.swift` | 新增 `--frame-profile`（Options.frameProfile，缺省 false）+ 帮助文本 |
| `Sources/PagingPrototypeApp/AppMain.swift` | smoke 输出行加 `frameProfile=` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `--frame-profile` 接线：创建 `FrameProfileRecorder(runID: session.runID, active: true)` 挂到 surface，stdout 打印文件路径；teardownAll 落盘 + 释放 |
| `Tests/PagingUITests/FrameProfileTests.swift`（新建） | 10 个测试（参数解析 / 缺省关闭 / 输出格式 / 帧记录 / 输入记录 / 行为不变性） |

**默认路径零行为变化**：`--frame-profile` 缺省时 `surface.frameProfiler == nil`，帧回调/输入路径仅多一次可选链 nil 检查（纳秒级）；无测量、无文件、无逻辑参与。PagingTelemetry 契约零改动（探针独立于 telemetry，runID 仅复用其自动生成值做文件名）。

## 二、测量点与阶段定义

两类样本写同一 JSONL 文件（`kind` 区分），每行一条 JSON（sortedKeys）：

### kind=frame（帧回调 `PagingSurface.advanceFrame`，每帧一条）
| 字段 | 定义 |
|---|---|
| `input_ns` | 输入处理：pending 输入分发（待决释放决策窗口检查 + `core.finishGesture`） |
| `state_ns` | 状态机推进：`core.tick`（扣除同步视图回调后的纯状态机耗时） |
| `view_ns` | 视图更新：core 事件同步回调（handleCoreOffset/State/TransitionBegin/Commit，含 relayout/可访问性/lab 叠加）内耗时 + 帧末驱动控制（updateAnimationDriver） |
| `total_ns` | 帧回调总耗时（未归属 = onAnimationFrame 观察钩子 + 测量自身开销，计入 total 不入阶段） |
| `gesture_active` | 是否手势活动（`core.isAnimating || pendingFinishSince != nil`） |

### kind=input（输入事件 `PagingSurface.handleScrollInput`，gesture.changed 等，每事件一条）
| 字段 | 定义 |
|---|---|
| `input_ns` | 输入处理：ScrollInputMapper.map + 动作分发（扣除 core/view 后余量） |
| `state_ns` | 状态机推进：`core.handleGesturePhase`/`finishGesture`/`legacyScrollDelta` 调用耗时 |
| `view_ns` | 视图更新：core 事件同步回调 + onGestureEvent 观察钩子 |
| `total_ns` | 输入处理总耗时（未归属 = updateAnimationDriver + 测量自身开销） |
| `phase` | 事件阶段（began/changed/ended/cancelled/stationary/mayBegin/none；momentum 事件带 `momentum.` 前缀） |
| `gesture_active` | 是否手势活动（`core.state != .idle`） |

**阶段不变量**：`input_ns + state_ns + view_ns ≤ total_ns`（测试断言）。视图回调在 core 调用内同步触发（core 事件 → 视图处理），视图耗时是 core 耗时的子集 → 从 core 耗时中扣除（`viewInsideCoreNS`），state/view 不双重计数；帧记录中 pending 分发窗口（finishGesture 同步事件）的视图耗时归属 input_ns（输入处理），从视图归属中剔除。

## 三、输出格式

- 文件：`/tmp/launch-copy-paging-prototype-<run-id>-profile.jsonl`（runID 经文件安全净化：仅 `[A-Za-z0-9._-]`、上限 64、空回退 `run`；与 PagingTelemetry 同规则，PagingUI 不依赖 PagingTelemetry）
- 每行示例：
  - `{"gesture_active":true,"input_ns":1234,"kind":"frame","state_ns":5678,"timestamp":123456.789012,"total_ns":9012,"view_ns":3456}`
  - `{"gesture_active":true,"input_ns":2345,"kind":"input","phase":"changed","state_ns":6789,"timestamp":123456.789012,"total_ns":10112,"view_ns":4567}`
- stdout 摘要一行：`paging-frame-profile: <文件路径>`（AppDelegate 接线时打印 + fflush）
- 落盘策略：内存缓冲（上限 20,000 条，超出丢最旧）+ 阈值批量写（512 条触发；帧路径不做 I/O）+ teardown 显式 flush；写失败计数不崩溃
- 隐私：仅耗时数值与手势阶段枚举，无 app 名/路径/图标数据

## 四、测试证据

### 新增 `FrameProfileTests.swift`（10 测试，全绿）
1. `testFrameProfileArgumentParsed` — `--frame-profile` 解析、缺省 false、与既有参数共存
2. `testFrameProfileHelpText` — 帮助文本含 `--frame-profile`
3. `testDefaultSurfaceHasNoProfiler` — 缺省 `frameProfiler == nil`（零测量路径），行为照旧
4. `testInactiveRecorderProducesNoFile` — 未激活 recorder：flush 后无文件、recordCount == 0
5. `testDefaultFileURLPattern` — 缺省文件名 `launch-copy-paging-prototype-<runID>-profile.jsonl`、目录 /tmp
6. `testRunIDSanitized` — 净化规则（空格/斜杠 → `_`、空 → `run`、合法字符保留）
7. `testFrameRecordsWrittenDuringSettle` — settle 60 帧产生帧记录：每帧 timestamp + 四阶段 ns 非负 + 阶段和 ≤ total + 手势活动标记
8. `testInputRecordsWrittenForGestureChanged` — began + 2×changed + ended + finishPendingGesture = 5 条 input 记录，phase 正确，手势活动标记 true
9. `testMomentumInputRecordsPhase` — momentum.began/changed/ended phase 前缀正确
10. `testProfilerDoesNotChangeBehavior` — 同一手势序列有/无探针：committedPage/commitCount/staleRejectionCount/state/layoutPerformedCount/liveHostCount/poolHostCount 完全一致

### 回归
| 项 | 结果 |
|---|---|
| PagingUITests（既有 117 + 新增 10） | ✅ **127/127** 全绿（0 failure；任务书基线 93 为早期计数，Phase 1B 后续任务已扩充至 117） |
| 全量 `swift test` | ✅ **429/429** 全绿（0 failure，≥414 要求达成） |
| `swift build -c release` | ✅ exit 0（本任务改动文件零警告；仓库存在 1 条**既有**警告：PagingPageContent.swift:38 Sendable/AnyHashable，Wave 1 遗留，非本任务引入） |
| smoke（PAGING_PROTOTYPE_SMOKE=1 --frame-profile） | ✅ parse OK，`frameProfile=true` 输出正确 |
| 端到端（GUI 自驱 40 flings + --frame-profile） | ✅ 660 条记录（160 input + 500 frame），阶段不变量 0 违例，stdout 打印文件路径 |

## 五、给 Main 的备注

1. **探针已就绪，可跑真实卡顿复现**：`swift run PagingPrototypeApp --frame-profile --run-id <id>`（可叠加 `--paging-telemetry` 对照 frame_interval）；profile 文件每帧/每输入事件一条，按 `total_ns` 排序即可定位卡顿帧的归属阶段（input/state/view）。
2. **阶段归属说明**：`state_ns` 与 `view_ns` 是同步子集归属（core 调用内同步触发视图回调，视图耗时从 core 耗时中扣除，不双重计数）；帧记录中 pending 分发窗口的视图耗时归属 input_ns；`onAnimationFrame`（telemetry 观察钩子）与测量自身开销只计入 total —— 若后续发现 total 显著大于三阶段之和，嫌疑在观察钩子/驱动控制。
3. **探针独立于 telemetry**：PagingTelemetry 契约零改动（红线四层测试未触碰）；runID 复用 session 自动生成值仅为文件名唯一性，与 telemetry 开关无关。
4. **既有警告**：`swift build -c release` exit 0；仓库 1 条既有警告（PagingPageContent.swift:38 Sendable/AnyHashable，Wave 1 遗留）非本任务引入，本任务改动文件零警告。
5. **不自我认证 PASS**：本文件为结果报告，PASS 判定归 Reviewer/Main。
