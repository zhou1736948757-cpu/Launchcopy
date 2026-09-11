# Callback Boundary ABBA Results — 2026-08-29

## 1. 任务与窄结论

本轮把 callback cadence 切到 Timer callback recorder 的可观测边界，回答一个有限问题：在本次 GUI SELFDRIVE ABBA 捕获中，5 个严格大于 25ms 的 entry-to-entry interval，能否由上一 recorded segment 已测得的 current-thread CPU 时间充分解释。

最终门：

```text
TIMER_ENTRY_TO_POST_ADVANCEFRAME_PROBE_IMPLEMENTED_AND_DIAGNOSTICALLY_VALIDATED
PRECEDING_RECORDED_SEGMENT_THREAD_CPU_INSUFFICIENT_FOR_5_OBSERVED_GT25MS_ENTRY_INTERVALS
POST_RECORDED_EXIT_REMAINDER_MEASURED_FOR_ALL_5_OBSERVED_GT25MS_ENTRY_INTERVALS
ONE_OBSERVED_GT25MS_ENTRY_INTERVAL_REMAINS_A_SUBSTANTIAL_MIXED_RECORDED_SEGMENT_CASE
FIRST_TICK_GT25MS_DELAYS_EXIST_SEPARATELY_AND_ARE_EXCLUDED_FROM_RAW_INTERVAL_DISTRIBUTIONS
POST_RECORDED_EXIT_AND_FIRST_TICK_DELAY_CAUSALITY_UNRESOLVED
FULL_TIMER_CLOSURE_EXIT_UNOBSERVED
CAUSAL_SYSTEM_COMPONENT_NOT_IDENTIFIED
SELFDRIVE_ONLY_FOR_CALLBACK_ABBA
REQUIRE_PHYSICAL_AB_BEFORE_TIMER_TOLERANCE_DEFAULT_CHANGE
REQUIRE_FULL_TIMER_CLOSURE_EXIT_AND_SAME_CLOCK_RUNLOOP_CORRELATION_FOR_DEEPER_CAUSAL_CLAIMS
```

这不是 `ROOT_CAUSE_FOUND`，也不是 `ALL_HITCHES_FIXED`。这里的 `recorded exit boundary` 是 `advanceFrame` 返回后、`endCallback` 开头采样的 recorder 边界；它不证明 Timer closure 已经返回。该边界之后仍可能包含本 callback 内的 JSON 构造、buffer enqueue、deadline bookkeeping，以及下一 callback entry 之前的其他未观测时间。因此本文不把 remainder 命名为“callback 外时间”，也不据此指定系统组件。

## 2. 探针实现与审查后加固

新增/接线内容：

- `FrameCallbackProfileRecorder`：记录 monotonic entry/recorded-exit、current-thread CPU、nominal deadline、lateness、missed periods、first tick、raw callback interval、simulation dt 和匿名 RunLoop mode；
- `RunLoopFrameDriver`：在真实 Timer callback 入口 begin，在 `advanceFrame` 返回后调用 end；nominal deadline 按绝对节奏递推；
- callback 内同步 `stop()` 后仍接受当前已开始的完整记录；
- restart 使用新 generation，callback sequence 连续；
- 独立审查后增加 generation guard，防止旧 generation callback 在同步 `stop()+start()` 后覆盖新 generation 的 nominal deadline；新增真实 RunLoop 回归测试；
- `DisplayLinkFrameDriver` 只把 recorder 透传给内部真实 RunLoop Timer 帧源，不能解释为 display link 已驱动 surface；
- `AppDelegate`：`--frame-callback-profile` opt-in 创建单一 recorder，teardown 后 flush；
- `--disable-telemetry-bridge` 用于 callback-only 隔离轨；
- 未修改 `Sources/PagingCore/`。

ABBA 原始捕获早于 generation guard 加固，但用于本文主要结论的 raw entry interval、recorded-segment wall 和 current-thread CPU 字段不依赖 deadline 写回。另对四轮全部 generation transition 做了检查：没有新 generation 首记录的 `scheduled_ns` 早于或等于上一条 recorded exit 的样本。

隐私边界：不记录 app 名、bundle ID、路径、URL、搜索词或图标数据；mode 只允许 `default|eventTracking|modalPanel|other|none`。

## 3. 最终自动验证

独立审查修复后的最终结果：

- Swift：**454 tests, 0 failures**；
- Python：callback cadence 5 + frame hitch analyzer 15 = **20 tests, 0 failures**；
- Release build：exit 0；
- Debug executable SHA-256：`524e995b47c9aa7dcc07d10d6c3bde671b314a92616d74bc67ac6a9516449f05`；
- Release executable SHA-256：`3742ee9ea8db98aecdcba62bb1df612851f12d2957a1c1f8c92216d4dcb3b700`；
- `py_compile`：通过；`git diff --check` exit 0，但仓库尚无 tracked baseline，因此另对本轮 10 个权威实现/测试/报告/Workflow 文件执行 trailing-whitespace 与 conflict-marker 扫描，结果 0 issue；
- 集成测试覆盖真实 Timer callback、restart generation=2、连续 sequence、新 generation 首记录 raw interval 为 null、simulation dt，以及旧 generation 不覆盖新 deadline 的 reentrant `stop()+start()` 回归。

构建存在 2 条既有测试代码 warning（冗余 `_ =` 忽略 Void 返回值）；不是本轮新增，Release build 无失败。

## 4. SELFDRIVE ABBA 协议

Release GUI、neutral content、RunLoop Timer、callback profile 开启、telemetry bridge 完全关闭。顺序固定：

```text
A1 = tolerance 8.333ms
B1 = tolerance 0ms
B2 = tolerance 0ms
A2 = tolerance 8.333ms
```

每轮由 `PAGING_PROTOTYPE_GUI_SELFDRIVE=1` 自动执行 40 次 synthetic fling 并正常 teardown。SELFDRIVE 是合成性能采样，不是物理触控板手感门。

| Run | tolerance | input / accepted | raw intervals | recorded generations | p95 ms | p99 ms | max ms | >20 | >25 | >33.3 | >50 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| A1 | 8.333ms | 533 / 533 | 502 | 31 | 18.578 | 23.381 | 24.942 | 12 | 0 | 0 | 0 |
| B1 | 0ms | 498 / 498 | 473 | 25 | 17.438 | 18.884 | 21.055 | 3 | 0 | 0 | 0 |
| B2 | 0ms | 489 / 489 | 464 | 25 | 17.560 | 22.157 | 72.458 | 6 | 4 | 2 | 1 |
| A2 | 8.333ms | 497 / 497 | 468 | 29 | 18.263 | 21.122 | 25.100 | 8 | 1 | 0 | 0 |

四轮共 2,017 input records，全部是 accepted callback records；rejected=0，ignored non-callback=0。raw interval 分母为 1,907；110 个 first tick 的 raw interval 为 null，不进入该分布。

Pooled 仅作描述，不把四轮短采样当成生产统计：

| Arm | raw intervals | p95 ms | p99 ms | max ms | >20 /1000 | >25 /1000 |
|---|---:|---:|---:|---:|---:|---:|
| A 8.333ms | 970 | 18.571 | 23.071 | 25.100 | 20.619 | 1.031 |
| B 0ms | 937 | 17.526 | 19.643 | 72.458 | 9.605 | 4.269 |

A/B 对 20–25ms 短尾的方向与此前 Timer tolerance 实验一致，但 B2 的孤立长尾使 `>25ms` pooled rate 更高。不能据此声称 0ms 改善或恶化长尾；只能确认 tolerance 不是本捕获中 >25ms 长尾的完整解释。

## 5. 严格大于 25ms 的 callback-boundary 样本

`recorded-exit→next-entry remainder = raw entry interval - preceding recorded-segment wall`。

| Run | generation/seq | interval ms | preceding recorded wall ms | preceding recorded-segment current-thread CPU ms | recorded-exit→next-entry remainder ms | measured reading |
|---|---|---:|---:|---:|---:|---|
| A2 | 2/38 | 25.100 | 0.416 | 0.416 | 24.684 | remainder 98.3% |
| B2 | 1/2 | 27.372 | 6.830 | 1.928 | 20.543 | remainder 75.0%；recorded-segment wall 也含明显非 CPU 部分 |
| B2 | 1/4 | 72.458 | 0.677 | 0.643 | 71.781 | remainder 99.1% |
| B2 | 15/293 | 37.325 | 1.030 | 0.978 | 36.295 | remainder 97.2% |
| B2 | 17/320 | 27.055 | 11.835 | 0.921 | 15.220 | mixed：remainder 56.3%，recorded segment active wall 占 43.7% |

五个样本的 preceding recorded-segment current-thread CPU 均不超过 1.928ms，因此它不是这五个 interval 的充分解释。五个样本的 remainder 都占 interval 多数；其中三个最清晰样本为 97.2%–99.1%。`27.055ms` 样本仍是 substantial mixed case，不能被归类成“全部时间都在 recorded exit 之后”。

对 mixed 样本，只能说 recorded-segment wall 明显高于 current-thread CPU；现有字段不能区分其原因，也不能指定 scheduler、RunLoop、WindowServer、AppKit、Core Animation、GPU 或其他组件。

## 6. First tick（独立分布）

- A pooled：60 个 first tick，recorder-derived nominal-arm-to-first-entry p99 25.792ms，max 26.666ms；
- B pooled：50 个 first tick，recorder-derived nominal-arm-to-first-entry p99 32.645ms，max 35.841ms；
- B2 在 tolerance=0 时仍有 35.841ms first tick。

first-tick lateness 只描述 recorder-maintained nominal schedule 下，Timer generation arm 到首 callback entry 的派生晚到量；它不是 Timer/CFRunLoop 报告的真实 fire deadline。first tick 的 raw interval 为 null，明确排除在 raw entry-to-entry interval 分布之外；其因果同样未定位。

## 7. 结论边界

### 已支持

1. recorder 接入真实 GUI RunLoop Timer callback，并通过 schema、算术、sequence、hash 和生成报告重算检查；
2. 在本捕获的五个 >25ms interval 中，上一 recorded segment 已测 current-thread CPU 不是充分解释；
3. 五个样本均有多数时长落在上一 recorded exit boundary 与下一 recorded entry boundary 之间，其中一个仍是 substantial mixed recorded-segment case；
4. 另有独立的 >25ms first-tick delay，且未混入 raw interval 分布；
5. tolerance=0 不是这些延迟的完整解释。

### 未支持

- recorded exit 等于 Timer closure 实际返回；
- remainder 等于严格的“callback 外时间”；
- scheduler / wake-up / RunLoop 已确认；
- WindowServer、AppKit、Core Animation、GPU 或其他组件已确认；
- 所有长尾具有同一原因；
- 0ms tolerance 已修复长尾；
- SELFDRIVE 等于真实触控板物理 PASS 或足以改变产品默认值。

## 8. 下一步

1. 保留生产默认 8.333ms，等待真实触控板物理 ABBA 和能耗证据；
2. 若继续追根因，给 callback 与 RunLoop observer 增加可验证的同钟关联/区间 ID；
3. 如要分解 recorded exit 后的 remainder，应把 recorder exit 移到 closure 最末端或增加 closure-return-adjacent 边界，并避免把未测区间预先命名为 scheduler；
4. 在 120Hz 设备上重跑时，仍独立记录硬件刷新率和物理手感门。

## 9. 证据文件

- `Docs/CALLBACK_CADENCE_cb-abba-a1-20260829.md`
- `Docs/CALLBACK_CADENCE_cb-abba-b1-20260829.md`
- `Docs/CALLBACK_CADENCE_cb-abba-b2-20260829.md`
- `Docs/CALLBACK_CADENCE_cb-abba-a2-20260829.md`
- `Docs/CALLBACK_BOUNDARY_ABBA_ARTIFACTS.sha256`
- 原始 JSONL 位于 `/tmp/launch-copy-paging-prototype-cb-abba-*-20260829-callback.jsonl`，属于临时诊断证据。
