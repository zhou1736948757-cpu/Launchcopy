# 任务：继续定位 macOS 分页原型偶发长帧根因——Timer closure tail 与同钟 RunLoop 关联

> 日期：2026-08-29
> 这是一份自包含任务书。执行者不需要此前对话，但必须先读取本文件列出的当前权威材料。
> 核心纪律：**先建立能排除歧义的测量边界，再谈根因；不要因为某个时间段“落在 callback marker 之后”就把它命名为 scheduler、RunLoop、WindowServer 或 callback 外时间。**

---

## 0. 工作目录与硬性边界

项目：

```text
/Users/mac/Projects/Launch_Copy/PagingPrototype
```

只允许在该项目内工作。禁止访问：

```text
/Users/mac/Projects/LaunchBetter/
/Users/mac/Projects/BuhoReverseNotes/
```

冻结目录，只读，禁止修改：

```text
Sources/PagingCore/
```

禁止执行：

```text
commit
push
tag
reset
clean
发布或分发产物（本地 `swift build -c release` 验证允许）
```

仓库当前没有 commit，项目文件处于 untracked 状态。因此：

- `git diff --check` exit 0 **不等于**已检查全部文件；
- 必须额外对本轮实际改动文件运行 trailing-whitespace、conflict-marker 和必要的静态扫描；
- 不得清理、覆盖或“恢复”现有工作区。

隐私红线：诊断记录和报告不得包含：

```text
app 名称
bundle ID
应用路径或用户路径
URL
搜索词
图标数据
原始 RunLoop mode 字符串
窗口标题或用户输入内容
```

RunLoop mode 只允许固定类别：

```text
default
eventTracking
modalPanel
other
none
```

---

## 1. 当前目标

继续定位分页原型中偶发的 `>25ms` Timer entry-to-entry interval 和独立 first-tick delay 的根因。

上一阶段已经证明一个有限事实：在一次 GUI SELFDRIVE ABBA 中捕获的 5 个严格 `>25ms` entry interval，上一 recorded segment 的 current-thread CPU 最多为 `1.928ms`，不足以解释完整 interval；多数 wall time 位于 recorded-exit marker 与下一 Timer entry 之间。

但上一阶段的 `exit_ns` 是：

```text
Timer closure entry
  → handleFrame
  → PagingSurface.advanceFrame 返回
  → FrameCallbackProfileRecorder.endCallback 开头采样 exit_ns
```

它**不是** Timer closure return。其后仍可能存在：

```text
JSON/record 构造
buffer enqueue
nominal deadline bookkeeping
generation 检查
closure 尾部其他工作
下一 Timer entry 前的 RunLoop active/waiting 区间
线程等待、阻塞或抢占
```

所以本阶段的第一目标不是直接宣布某个系统组件为根因，而是将当前 remainder 进一步分割成可验证的时间区间：

1. `Timer entry → post-advanceFrame marker`；
2. `post-advanceFrame marker → closure-return-adjacent marker`；
3. `closure-return-adjacent marker → next Timer entry`；
4. 第 3 段内可由同一单调时钟观测到的 RunLoop activity 边界；
5. 仍然无法由应用内探针分类的区间。

若应用内探针仍不足以区分，才进入 `os_signpost + xctrace/System Trace/Time Profiler` 轨道，观察主线程究竟是：

```text
on-CPU 执行应用/AppKit工作
阻塞或等待
runnable 但未获调度
休眠直到 Timer/RunLoop 唤醒
其他未分类状态
```

---

## 2. 必须先读的权威材料

执行前按顺序阅读：

```text
Docs/CALLBACK_BOUNDARY_ABBA_RESULTS.md
Docs/FRAME_HITCH_DEEP_DIVE_REPORT.md
Docs/IMPLEMENTATION_LOG.md
Docs/TIMER_TOLERANCE_AB_RESULTS.md
Workflow/results/T-targeted-callback-boundary-probe.md
Workflow/STATE.json
Sources/PagingUI/FrameCallbackProfileRecorder.swift
Sources/PagingUI/RunLoopProfileRecorder.swift
Sources/PagingUI/PagingFrameDriver.swift
Sources/PagingPrototypeApp/AppDelegate.swift
Tools/analyze_callback_cadence.py
Tools/analyze_frame_hitches.py
Tests/PagingUITests/FrameCallbackProfileTests.swift
Tests/PagingUITests/RunLoopProfileTests.swift
Tests/PagingUITests/RunLoopFrameDriverTests.swift
```

不要重新使用已经被 supersede 的宽泛历史结论。当前权威 gate 是：

```text
TIMER_ENTRY_TO_POST_ADVANCEFRAME_PROBE_IMPLEMENTED_AND_DIAGNOSTICALLY_VALIDATED
PRECEDING_RECORDED_SEGMENT_THREAD_CPU_INSUFFICIENT_FOR_5_OBSERVED_GT25MS_ENTRY_INTERVALS
POST_RECORDED_EXIT_AND_FIRST_TICK_DELAY_CAUSALITY_UNRESOLVED
FULL_TIMER_CLOSURE_EXIT_UNOBSERVED
CAUSAL_SYSTEM_COMPONENT_NOT_IDENTIFIED
SELFDRIVE_ONLY_FOR_CALLBACK_ABBA
REQUIRE_PHYSICAL_AB_BEFORE_TIMER_TOLERANCE_DEFAULT_CHANGE
REQUIRE_FULL_TIMER_CLOSURE_EXIT_AND_SAME_CLOCK_RUNLOOP_CORRELATION_FOR_DEEPER_CAUSAL_CLAIMS
```

禁止把本阶段起点描述为：

```text
根因已经是 scheduler
已经定位到 callback 外
RunLoop 已确认
WindowServer 已确认
全部卡顿已修复
0ms tolerance 应改为默认
```

---

## 3. 已有基线

截至 2026-08-29：

```text
Swift：454 tests, 0 failures
Python：20 tests, 0 failures
Release build：PASS
```

当前可执行文件 SHA-256：

```text
Debug  524e995b47c9aa7dcc07d10d6c3bde671b314a92616d74bc67ac6a9516449f05
Release 3742ee9ea8db98aecdcba62bb1df612851f12d2957a1c1f8c92216d4dcb3b700
```

上一轮 callback ABBA：

```text
A1 = Timer tolerance 8.333ms
B1 = Timer tolerance 0ms
B2 = Timer tolerance 0ms
A2 = Timer tolerance 8.333ms
```

总计：

```text
2,017 input records
2,017 accepted callbacks
0 rejected callback records
0 ignored non-callback records
1,907 raw intervals
110 first ticks，raw interval = null
```

严格 `>25ms` 的 5 个 raw intervals：

| Run | generation/seq | entry interval | preceding recorded-segment wall | preceding segment thread CPU | recorded-exit→next-entry remainder |
|---|---:|---:|---:|---:|---:|
| A2 | 2/38 | 25.100ms | 0.416ms | 0.416ms | 24.684ms |
| B2 | 1/2 | 27.372ms | 6.830ms | 1.928ms | 20.543ms |
| B2 | 1/4 | 72.458ms | 0.677ms | 0.643ms | 71.781ms |
| B2 | 15/293 | 37.325ms | 1.030ms | 0.978ms | 36.295ms |
| B2 | 17/320 | 27.055ms | 11.835ms | 0.921ms | 15.220ms |

First tick 独立结果：

```text
A: n=60, p99=25.792ms, max=26.666ms
B: n=50, p99=32.645ms, max=35.841ms
```

注意：旧 JSONL 只能用于上一阶段结论，不能凭空生成本阶段缺失的 closure-tail 或同钟 RunLoop 边界。本阶段需要重新采集。

---

## 4. 本阶段的核心问题

必须依次回答，不能跳步：

### Q1. 当前 recorded exit 到 Timer closure 尾部之间究竟有多少时间？

需要新增一个**closure-return-adjacent marker**。它必须尽可能接近 Timer closure 的词法末端，并清楚命名为：

```text
closure_tail_marker
pre_return_marker
```

或同等准确名称。

禁止命名为：

```text
closure_return
callback_return
true_exit
```

因为应用代码无法在 closure 已经返回后再执行记录。

必须量化：

```text
post_advanceFrame → closure_tail_marker wall time
post_advanceFrame → closure_tail_marker current-thread CPU
closure-tail recorder 自身的 wall/CPU 开销（如可测）
```

实现时优先考虑 `defer` 保证所有正常返回路径都记录，但必须审查：

- `defer` 内 marker 的实际位置；
- marker 之后仍执行多少 profiler/Swift runtime 工作；
- `stop()+start()` 重入是否仍安全；
- owner teardown、weak owner 消失等早退路径是否记录，语义是什么；
- 不得为了“测量”改变生产行为或 nominal schedule。

### Q2. Callback 与 RunLoop recorder 是否真正使用同一时钟？

当前 callback recorder 使用：

```text
clock_gettime(CLOCK_MONOTONIC_RAW)
```

当前 RunLoop recorder使用 `ContinuousClock` 计算 gap，并用 `ProcessInfo.systemUptime` 输出 timestamp。不要假设它们天然可以无误差直接 join。

应设计一个模块内部共享的单调时钟抽象，让以下记录使用同一 clock domain、同一纳秒单位：

```text
Timer callback entry
post-advanceFrame marker
closure-tail marker
RunLoop observer activity
Timer generation arm marker（用于 first tick）
```

要求：

- production 默认使用稳定的 monotonic/raw 时钟；
- deterministic tests 可以注入 fake clock；
- inactive profiler 不读取时钟、不建 writer、不建文件；
- 不把 wall clock、Date、systemUptime double 和 raw monotonic ns 混为精确同钟；
- 处理 UInt64 溢出、回退或非法读数；
- 不修改 `PagingCore`。

### Q3. 同钟 RunLoop activity 能把 remainder 分到哪一类？

现有 SDK/实现只能稳定观察：

```text
entry
beforeTimers
beforeSources
beforeWaiting
afterWaiting
exit
```

缺少稳定的 `afterTimers/afterSources`，所以 RunLoop observer 仍然是粗粒度边界。不得把：

```text
beforeWaiting → afterWaiting
```

自动解释成 scheduler delay；它首先只是“观察到的 waiting-bounded interval”。

建议每条 RunLoop 记录至少包含固定 schema：

```text
kind
observation_seq
activity
timestamp_ns
gap_ns
previous_activity
mode
```

可选但需证明必要性：

```text
thread_cpu_ns
runloop_cycle_seq
```

不要把 callback sequence 强行写进 RunLoop observer；优先让 analyzer 用同钟区间 join。若确实需要共享 correlation ID，先解释生命周期、重入和 generation 边界。

Analyzer 应把 `closure-tail → next entry` 分为保守类别，例如：

```text
WAITING_BOUNDED
RUNLOOP_ACTIVE_BOUNDED
MIXED_OBSERVED_BOUNDARIES
NO_OBSERVER_BOUNDARY
UNCLASSIFIED
```

这些是**观测分类**，不是根因名称。

### Q4. First tick 延迟发生在 arm 后的哪一段？

必须明确记录真正的 recorder-derived arm marker，而不是只用：

```text
scheduled_ns - nominal_interval_ns
```

反推出所谓 start time。

每个实际 Timer generation arm 时记录：

```text
driver_generation
arm_ns
nominal_first_deadline_ns
interval_ns
tolerance_ns
```

并验证：

```text
arm_ns <= nominal_first_deadline_ns <= first entry（晚到时）
```

必须观察：

- start 后无 callback 就 stop 的 generation；
- generation 1 callback 内同步 stop/start 后 generation 2；
- first tick 是否落在 waiting-bounded 区间；
- first tick delay 与普通 raw interval 必须继续分开统计。

---

## 5. 推荐实施顺序

### Step 1：只读设计审查

先画出当前真实热路径，至少覆盖：

```text
Timer fire
→ Timer closure entry
→ beginCallback
→ handleFrame
→ PagingSurface.advanceFrame
→ endCallback
→ next deadline bookkeeping
→ closure return
→ RunLoop 后续 activity
→ next Timer entry
```

输出一张边界表：

| Boundary | 当前是否测量 | 当前时钟 | 本阶段计划 | 能证明什么 | 不能证明什么 |
|---|---|---|---|---|---|

在完成该表之前不要改代码。

### Step 2：最小化实现同钟与 closure-tail marker

优先保持已有 JSON 字段兼容。若调整旧字段语义，必须：

- 新增明确字段，而不是悄悄改变旧字段含义；
- analyzer 同时兼容旧 schema 与新 schema，或明确拒绝旧 schema；
- 报告列出 input/accepted/rejected/ignored 各分母；
- 每条派生结论能回到原始字段。

不得在 Timer closure 或 RunLoop observer 热路径同步写文件。继续使用内存 buffer + 异步批量 writer，或者更轻量的固定结构 ring buffer。

### Step 3：测试先于 GUI 采集

至少增加以下确定性测试：

1. inactive callback/runloop profiler 零时钟读取、零 mode 读取、零 writer、零文件；
2. callback 与 RunLoop recorder 使用同一 fake clock domain；
3. marker 顺序：`entry <= post_advanceFrame <= closure_tail`；
4. `post_advanceFrame → closure_tail` wall/CPU 计算正确；
5. generation arm/first-tick 数据正确；
6. start→stop 且无 tick 的 generation 可观测；
7. reentrant `stop()+start()` 不让旧 generation 污染新 generation；
8. 新 generation first tick 的 raw interval 仍为 null；
9. analyzer 对 malformed、unknown kind、旧 schema、新 schema 分别给出明确计数；
10. analyzer 的区间 join 在边界相等、无 observer、多个 observer、跨 generation 时正确；
11. mode 永远只输出允许的五类；
12. JSON 不含隐私字段或 raw mode；
13. buffer overflow/flush failure 不崩溃且计数可查询；
14. marker/observer instrumentation 默认关闭时不改变分页行为。

不要用固定 `sleep 90ms + lateness < 15ms` 之类依赖机器调度的断言测试状态所有权；优先 fake clock + XCTestExpectation + 精确字段断言。

### Step 4：先做探针开销 A/A，不要直接分析根因

新探针本身可能制造长尾。至少比较：

```text
Control：callback/runloop 新探针关闭
Legacy：现有 callback recorder
Full correlation：callback entry + post-advanceFrame + closure-tail + same-clock RunLoop
```

固定：

```text
Release build
neutral content
同一窗口/全屏模式
同一 page/item 参数
同一 SELFDRIVE 手势序列
同一 Timer tolerance
相同运行时长与 teardown
```

每个 arm 至少 3 轮，顺序交错，不能把一次运行当作结论。报告：

```text
record 数量
writer failure/drop 数量
p50/p95/p99/max
>20/>25/>33.3/>50ms rate
recorded segment wall/CPU
closure-tail recorder wall/CPU
RunLoop observer records per second
```

只有探针开销没有明显改变目标分布，才进入正式因果采集。若明显扰动，应先降低开销，不得继续把被探针污染的数据解释为应用根因。

### Step 5：正式 SELFDRIVE 诊断采集

建议先固定 `tolerance=0ms`，避免已知 8.333ms tolerance 对 20–25ms 短尾的干扰；若资源允许，再做 `8.333/0/0/8.333` ABBA 检查结论是否跨 tolerance 成立。

每轮要求：

```text
Release GUI
neutral content
40 次固定 SELFDRIVE fling
正常 run.end
teardown.complete
callback profile 开启
same-clock runloop profile 开启
必要 telemetry 开启
所有 recorder writeFailureCount == 0
```

不要只报告 pooled 数据；必须同时给出逐轮结果，防止单轮异常支配 pooled tail。

对每个 `>25ms` raw interval，输出隐私安全的逐样本分解：

| Run | generation/seq | entry interval | recorded body | post-advance→tail | tail→next-entry | RunLoop boundary class | first tick? |
|---|---:|---:|---:|---:|---:|---|---|

并给出 wall 与 current-thread CPU，不得只看 wall。

### Step 6：物理触控板采集

SELFDRIVE 只能用于性能复现和探针验证，不等于真实手势门。

如果本机允许人工操作，生成清晰的物理采集命令和操作协议，至少收集 2 个有效 run：

```text
真实触控板
全屏
真实内容与 neutral content 分开
每轮约 30–60 次前进/回退/中断
记录屏幕刷新率
正常 teardown
```

物理数据必须单独标记，不与 SELFDRIVE 混池。若当前无法人工完成，状态写：

```text
PHYSICAL_CORRELATED_CAPTURE_BLOCKED_PENDING_USER_ACTION
```

不能用更多 SELFDRIVE 替代。

### Step 7：只有应用内边界仍无法分类时，进入系统 trace

如果多个 `>25ms` 样本仍有大段 `UNCLASSIFIED`，增加低开销 `os_signpost`，至少围绕：

```text
Timer closure
advanceFrame
closure tail
Timer generation arm/first tick
```

然后使用本机可用的 `xctrace` 模板采集 Time Profiler 或 System Trace。执行前先检查本机模板与命令，不要猜模板名称。

系统级归因门：

- **应用/AppKit on-CPU**：主线程 stack/time profile 在目标区间内存在可重复热点；
- **阻塞/等待**：目标区间显示明确 wait/block 原语或等待栈；
- **runnable but unscheduled**：System Trace 能证明线程已 runnable 但未运行，并量化持续时间；
- **WindowServer/Core Animation/GPU**：不能仅凭时间邻近命名，必须有对应 trace 证据和最好有单变量干预；
- trace 与应用 marker 必须能用 signpost/同一时间轴关联。

若无法取得满足条件的 trace，只能输出：

```text
APPLICATION_INTERNAL_BOUNDARIES_NARROWED
SYSTEM_CAUSAL_COMPONENT_UNRESOLVED
```

---

## 6. 因果结论门槛

### 可以写 `ROOT_CAUSE_FOUND` 的最低条件

必须同时满足：

1. 同一类 `>25ms` 现象在至少 2 个独立有效 run 中复现；
2. 同钟 marker/trace 覆盖目标 interval，而不是用不同时间域近似对齐；
3. 候选机制能解释目标 interval 的主要时长；
4. 有单变量干预或修复；
5. 干预后，同协议 ABBA 中对应 tail 指标重复下降；
6. 没有把探针开销当成根因；
7. 物理轨和 SELFDRIVE 轨的证据边界分别说明。

否则只允许使用：

```text
CANDIDATE_SUPPORTED
PARTIAL_CONTRIBUTOR_SUPPORTED
BOUNDARY_NARROWED
CAUSALITY_UNRESOLVED
```

### 可以写 `FIX_VALIDATED` 的最低条件

必须同时有：

```text
自动测试
Release build
探针开销对照
修复前后重复 ABBA
至少一次物理触控板复测
功能/手感无回归
```

没有物理复测时最多写：

```text
AUTOMATED_PERFORMANCE_FIX_SUPPORTED
PHYSICAL_ACCEPTANCE_PENDING
```

---

## 7. Analyzer 输出要求

新增或扩展 analyzer 时，Markdown 至少包含：

```text
input records
accepted callback records
rejected callback records
ignored non-callback records
accepted runloop records
rejected runloop records
raw intervals analyzed
first ticks analyzed separately
generations observed
writer/drop/failure counters（如输入可得）
```

逐样本必须使用固定、不泄露隐私的标识：

```text
run arm label
driver generation
callback sequence
ordinal
```

不能回显未知 JSON 字段，也不能复制输入中的路径、run ID、原始 mode 或自由文本。

所有 remainder 必须给公式。例如：

```text
recorded_body_ns = post_advance_ns - entry_ns
closure_tail_ns = pre_return_marker_ns - post_advance_ns
post_tail_remainder_ns = next_entry_ns - pre_return_marker_ns
```

若发生负值、溢出、marker 缺失、跨 generation 或 sequence 不连续，必须拒绝该样本或单列为 invalid，不得静默钳制成 0。

---

## 8. 工作流与并发要求

项目已有 Main/Chief/Worker/Reviewer 工作流，按 `/Users/mac/Projects/Launch_Copy/PagingPrototype/AGENTS.md` 执行。

允许使用多个 subagent，但必须避免写入冲突。推荐第一轮并发只读审查：

1. **Clock/Recorder Audit**：只读审查共享时钟、closure-tail marker 和 disabled fast path；
2. **RunLoop/Trace Audit**：只读审查 CFRunLoopObserver 能证明与不能证明的边界，以及 xctrace 可行路径；
3. **Analyzer/Experiment Audit**：只读审查 join 算法、统计分母、A/A 与 ABBA 协议。

实现阶段若并发，写入范围必须完全分离，例如：

```text
Worker A：Sources/PagingUI recorder/clock 文件 + 对应 Swift tests
Worker B：Tools analyzer + Python tests
Worker C：仅文档/实验脚本，不修改 A/B 文件
```

Reviewer 必须只读，不得与 Worker 共用自我审查结论。Main 负责最终集成、全量测试和 Workflow 收口。

Workflow 纪律：

- `Workflow/events.jsonl` append-only，不修改历史事件；
- 不给历史 `watchdog_alert` 补造 sequence；
- `Workflow/STATE.json` 保持 `active_agent_jobs` 与真实 agent 状态一致；
- 测量事实、推断、产品决策、物理门分别记录；
- 不得因为自动测试通过就把根因或物理验收标为 PASS。

---

## 9. 验证要求

代码修改后至少执行：

```bash
cd /Users/mac/Projects/Launch_Copy/PagingPrototype
swift test
swift build -c release
PYTHONPATH=. python3 -m unittest \
  Tools.tests.test_analyze_callback_cadence \
  Tools.tests.test_analyze_frame_hitches
python3 -m py_compile Tools/*.py
python3 -m json.tool Workflow/STATE.json >/dev/null
shasum -a 256 -c Docs/CALLBACK_BOUNDARY_ABBA_ARTIFACTS.sha256
```

如果新增 analyzer/test 文件，应加入 Python 全量测试命令。

由于仓库无 tracked baseline，还必须：

- 列出本轮所有修改文件；
- 对这些文件做 trailing-whitespace/conflict-marker 扫描；
- 检查 `Sources/PagingCore/` 没有被本轮修改；
- 执行隐私关键词扫描；
- 记录 Debug/Release 当前 executable SHA-256；
- 如重新生成 callback cadence 文档，更新并验证对应 artifact manifest；
- 不能把本轮重建后的 hash 冒充旧 GUI capture 所使用 binary 的 hash。

SwiftPM 如只因沙箱无法写用户级 module cache 而失败，应明确记录为环境失败，然后在获得授权后原命令重跑；不能把环境失败写成代码失败。

---

## 10. 交付物

至少交付：

```text
Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_PLAN.md
Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_RESULTS.md
Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_ARTIFACTS.sha256
Docs/IMPLEMENTATION_LOG.md 更新
Workflow/results/<task-id>.md
Workflow/STATE.json 更新
Workflow/events.jsonl append-only 更新
```

代码交付物按最终设计决定，但预计涉及：

```text
Sources/PagingUI/FrameCallbackProfileRecorder.swift
Sources/PagingUI/RunLoopProfileRecorder.swift
Sources/PagingUI/PagingFrameDriver.swift
Sources/PagingPrototypeApp/AppDelegate.swift
Tools/analyze_callback_cadence.py 或新的 correlation analyzer
对应 Swift/Python tests
```

最终报告必须分成：

```text
MEASURED
SUPPORTED INFERENCE
UNRESOLVED
INTERVENTION RESULT
PHYSICAL STATUS
```

并在开头给一个窄 gate。除非满足第 6 节因果门槛，否则禁止使用：

```text
ROOT_CAUSE_FOUND
ALL_HITCHES_FIXED
SCHEDULER_CONFIRMED
RUNLOOP_CONFIRMED
WINDOWSERVER_CONFIRMED
GPU_CONFIRMED
FIX_VALIDATED
```

---

## 11. 执行者的第一条回复要求

不要先泛泛解释，也不要直接开始大改。

第一条回复应给出：

1. 已读取的权威文件清单；
2. 当前边界图和最大歧义点；
3. 是否需要 subagent，并给出不冲突的并发拆分；
4. 计划修改的精确文件范围；
5. A/A 开销门、SELFDRIVE 采集门、物理门和系统 trace 门；
6. 明确声明当前仍是：

```text
CAUSALITY_UNRESOLVED
```

然后再按计划执行，不要停留在只给建议。
