# Frame Hitch Deep Dive — 阶段性证据报告

> 状态：**已定位一个可重复的部分贡献因素，但尚未定位全部长尾或最终系统组件**。2026-08-29 的双轨 SELFDRIVE 单变量 A/B 支持：默认 `8.333ms` Timer tolerance 会显著增加 `20–25ms` 短尾；`>25ms` 没有稳定改善，历史 `27.986–53.510ms` 仍未解释。waiting-like、unclassified mode-boundary 仍不能命名为 wake-up、scheduler、WindowServer 或 Core Animation 根因。
>
> 当前日期基准为 **2026-08-29**。SELFDRIVE 结果只作受控性能比较，不替代真实触控板物理门。

## 1. Executive conclusion

### MEASURED

1. 修复版真实触控板运行 `phys1b-06` 记录 591 个 telemetry frame，其中 17 个 interval >20ms，3 个 >25ms，最大 27.986ms；正好完成 30 个 gesture begin/end 序列，并有 teardown 完成记录。
2. `phys1b-06` 的 17 个 hitch 全部具备本地 frame-profile ordinal 相关性；按正确的 preceding-callback 归因，区间起点 callback 的 `total_ns` 最大仅 **0.937ms**。以最大样本计，至少 **96.0%** 的 wall interval 位于该已测 callback 窗口之外。
3. `phys1b-06` 的 frame/profile 计数为 591/591；590 个相邻 interval 中 561 个在容差内验证，29 个不匹配被透明保留；17 个 hitch 本身全部通过局部验证。
4. 17 个 hitch 的 runloop 分解显示：典型 hitch 的 waiting-like 每-frame 中位数 14.072ms，已对齐正常 frame 为 10.958ms；active-like 中位数几乎不变（0.810 vs 0.812ms）。这支持“waiting-like 绝对时间更长”的模式判断，但不证明具体 wake-up 或调度因果。
5. 少数 hitch 有 unclassified mode-boundary 长尾：3/17 的 exit→entry 每-frame sum 超过 10ms，1 个经验证超过 20ms；exit→entry 中位数与正常组近似，不能说它是所有 hitch 的普遍模式。
6. 历史人手-B 重新按 preceding callback 归因后，16 个 hitch 的 callback max 为 **0.936ms**（不是旧报告中的 0.820ms）；SELFDRIVE-neutral 对照的 callback max 为 **9.386ms**，因此不能把“callback 很短”外推为所有内容/所有运行的普遍结论。
7. 图标并非严格“零重叠”：历史人手-B 有 1/16 hitch 前窗出现匿名 icon 事件，其余 15/16 无此前窗共现；SELFDRIVE 仅是性能对照，不是物理手感证据。

### INFERRED

当前最强假设不是 PagingCore 算法本身，而是以下一类或多类：

- 主 runloop Timer/source 处理或唤醒 cadence 抖动；
- AppKit 在 callback 返回后的 deferred layout/display；
- Core Animation transaction/提交或 WindowServer 合成相关等待；
- 进程被抢占、timer wake-up 延迟、电源/调度因素；
- 少数 icon apply 触发的延迟绘制/纹理提交；
- 旧版诊断工具的同步写盘污染（已通过异步 writer 修复；不再作为 `phys1b-06` 的当前解释）。

`phys1b-04` 多次出现“长 interval 后接短 interval”的恢复形态，例如 48.021→25.141→16.667ms、47.670→25.186→9.994ms。这与 Timer/runloop cadence 抖动或补偿式恢复相容，但不能单独证明具体系统组件。

### UNRESOLVED

现有**人手**数据已经有粗粒度 runloop phase 记录，但仍没有 AppKit display、CA commit、WindowServer、CPU sampling 或系统调度 trace 的 duration/调用栈。因此现在不能诚实地声称：

- 已定位到唯一 CFRunLoop phase 或其中的具体系统根因；
- 已证明 WindowServer 或 Core Animation 是根因；
- 已量化 icon/layout/系统调度各自贡献百分比；
- 已完成最终修复。

---

## 2. 输入证据完整性

| 匿名标签 | 类型 | 行数 | SHA-256 |
|---|---|---:|---|
| 人手-A | telemetry | 1,674 | `6e6abe6e2d23ef1d0cdf161d738c36d382e39ec84184e68951355c6cc3cfad23` |
| 人手-B | telemetry | 1,266 | `e5ad613aa1de2b489ccf330211dcffbe456820c844e54c0e0f9704b7e2897258` |
| 人手-B-P | frame profile | 1,761 | `b159703ab92620146b3e424ec14fa17219dfbe0024653b04a27098db15a98c98` |
| 自驱-内容 | telemetry | 1,207 | `0e2a864924f91b6c117c92baf62cae9d39d52f69289eda42b9f2b87119ffd0f2` |
| 自驱-内容-P | frame profile | 766 | `4dc380af567094cacbee22fed583e107e05737ab960d82e66d3f3d9ba4f67009` |
| 自驱-中性 | telemetry | 1,023 | `9e4cc2508c45dddb9b7682d81672092113d0c588e346b14b8aeb556833e45cb2` |
| 自驱-中性-P | frame profile | 798 | `f1dd3785cc59c1e8aef19929b85e6f79b002af8daa1b191f1d5fc70e210a9db9` |
| 人手-C (`phys1b-06`) | telemetry | 1,259 | `b8dcd028e873714a54cb911e2e022808b432b9081af5724cd5b43c4aec172482` |
| 人手-C-P | frame profile | 1,494 | `8e4b5a0501a44f684afc05c7ac7c1bbb8777a59a0210c1800bda7279b205c1f6` |
| 人手-C-R | runloop profile | 254,766 | `3100b291849469eae8545324b4179d6935fcbbb7311d574aa2888bb3e8d5105c` |

所有 JSONL 行均可解析；四份 frame profile 的 `input_ns + state_ns + view_ns <= total_ns` 均为零违反。`phys1b-06` 的 runloop profile 仅在 frame windows 内参与比较。

## 3. Frame interval 量化

| 运行 | Frame | p50 ms | p95 ms | p99 ms | max ms | >20 | >25 | >33.3 | >50 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 人手-A | 835 | 16.667 | 18.088 | 26.145 | 48.021 | 21 | 11 | 7 | 0 |
| 人手-B | 596 | 16.667 | 17.670 | 22.249 | 23.702 | 16 | 0 | 0 | 0 |
| 自驱-内容 | 606 | 16.667 | 18.238 | 19.672 | 39.381 | 5 | 2 | 1 | 0 |
| 自驱-中性 | 638 | 16.667 | 18.107 | 22.423 | 53.510 | 12 | 2 | 2 | 1 |
| 人手-C (`phys1b-06`) | 591 | 16.667 | 18.293 | 21.530 | 27.986 | 17 | 3 | 0 | 0 |

五组运行总计 71 个 >20ms interval；其中只有 `phys1b-06` 同时具备修复后 frame 与 runloop profile，不应把其余运行的聚合统计当作同等粒度的归因证据。

## 4. 关键纠偏

### 4.1 “帧回调 max 2.7ms”只覆盖一个有限窗口

`FrameProfileRecorder.endFrame` 先取得终点并计算 `total_ns`，随后才构造 JSONL、追加缓冲；达到阈值时，旧实现还会同步 `flush()`。因此：

- 它强力排除了被包围的 input/state/view 主体；
- 它没有覆盖 Timer closure 进入 `advanceFrame` 前的调度延迟；
- 它没有覆盖 `endFrame` 取终点后的 recorder 序列化/写盘；
- 它没有覆盖 callback 返回后的 AppKit display/layout/CA 提交。

所以正确说法是：**已计时 callback 主体不是人手-B hitch 的主因**，而不是“整个 callback 与其后续副作用已全部排除”。

### 4.2 `state_ns` 不是纯 PagingCore

`onAnimationFrame` telemetry hook 位于 state 计时区间；stale/interruption telemetry 也未全部按 view work 单独归因。因此 `state_ns` 包含部分 bridge/telemetry 成本，不能当作纯状态机算法耗时。

### 4.3 逻辑 layout event 不等于 AppKit layout/display

现有 `layout` telemetry 主要覆盖 `PagingSurface.relayoutPages()` 的 host 复用、frame 设置和逻辑完成事件。它不覆盖所有：

- `NSView.layout()` / `layoutSubtreeIfNeeded`；
- cell/page view 的延迟 layout；
- `NSView.display` / layer display；
- `CATransaction` commit；
- WindowServer composition。

因此“0/37 人手 hitch 有 layout event”只排除了**被记录的逻辑 layout 事件前窗共现**，不能排除 AppKit 延迟渲染。

### 4.4 telemetry 与 profile 不能直接按绝对 timestamp 相减

- telemetry 使用 Unix wall-clock；
- frame/runloop profile 使用 uptime/单调时钟。

现有三组带 profile 的数据可通过 frame ordinal 对齐，并由相邻 frame interval 交叉验证；最大差异约 0.0011ms。后续分析工具必须保留该纪律，不能错误混用原始 timestamp。

### 4.5 SELFDRIVE 的长 callback 不解释其 interval hitch

自驱真实内容存在一次 `total=31.690ms`、`view=31.470ms` 的 callback 峰值，但它对应的 telemetry interval 约 17.033ms，不属于 5 个 >20ms hitch。这证明自驱中有一次 view 尖峰，却不能拿它解释那 5 个 interval hitch。

### 4.6 分析器 callback ordinal 纠偏（已完成）

分析器此前把 hitch interval `i` 的 callback total 取成了 `profile[i]`。调用顺序实际是：第 `i` 次 frame callback 先计算并报告 `dt_i`，再进入 profile `i`；因此 interval `i` 对应的窗口是 `profile[i-1].timestamp → profile[i].timestamp`，可能贡献该窗口起点的已测 callback 是 `profile[i-1]`。

已完成的修复：

- hitch 输出增加固定字段 `callback_frame_ordinal`，明确显示 preceding callback ordinal；
- `callback_total_ms` 改为 `profile[i-1].total_ns`；
- `parts_valid` 也按 preceding callback 检验；
- 首帧没有 preceding profile 时不再伪造 callback 归因；
- 新增“previous/current callback total 刻意不同”的回归测试，防止 future-sample leakage。

Terra 独立只读审查确认该错位属实，影响级别为诊断结论完整性 P1；修复后 Python 分析器为 **15 tests, 0 failures**。所有历史 callback 排除结论均已降级并用修复版重新计算，不能继续引用旧的同 ordinal 数值。

---

## 5. t21 / RunLoop probe 独立审查

### 可保留的部分

- 默认 CLI 未开启 `--frame-profile` 时不创建 runloop observer；
- 记录内容是匿名 phase/timestamp/duration，不包含 app 名、bundle ID、路径或图标数据；
- frame profile 与 runloop profile 都有 uptime timestamp，可用于毫秒级窗口关联；
- `entry/beforeTimers/beforeSources/beforeWaiting/afterWaiting/exit` 能提供粗粒度 runloop pattern。

### 当前不能接受为最终 PASS 的部分

1. **自我污染**：旧版 RunLoop recorder 在 observer callback 累积到 512 条时同步打开/写文件；Frame recorder 也在主线程阈值 flush，且部分位于 `total_ns` 终点之后。
2. **归因过度**：`beforeWaiting→afterWaiting` 只能说呈现 waiting-like 区间；不能单凭它断言“系统调度延迟”。
3. **粒度不足**：当前没有 afterTimers/afterSources，不能稳定细分 timer work 与 source work。
4. **阶段注释冲突**：源码/结果中存在 `afterWaiting→beforeTimers` 与 `beforeTimers→beforeSources` 两套不一致解释。
5. **缺少真实人手 runloop 产物**：现有自驱 smoke 只能验证 recorder 能产出，不能替代触控板运行。
6. **文件权限/保留**：诊断文件应至少收紧到 0600；run ID 净化不是脱敏。

该审查针对旧版 t21。修复任务现已完成并通过独立 Reviewer：

- hot callback 不再执行目录创建、文件 open/write、权限调整或 `Data` 构造；只切分内存批次并异步 enqueue；
- 专用串行 writer 保持 FIFO；teardown `flush()` 等待此前已接收批次完成；
- 新建与既有诊断文件均收紧为 `0600`；失败按批计数且不崩溃；
- runloop 注释与测试已收紧为 coarse active-vs-waiting 线索，不再宣称 timer/source 或系统调度已归因；
- 独立 Reviewer 结论为 **PASS，P0/P1=0**；仅保留主线程契约未机械强制、恢复路径测试可加强、runloop 专属非阻塞测试可补齐等 P2。

证据：

- `/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/results/T-frame-hitch-probe-repair.md`
- `/Users/mac/Projects/Launch_Copy/PagingPrototype/Workflow/reviews/T-frame-hitch-probe-repair-r1.md`

因此，**“修复探针”自动化门与修复版真实触控板采集均已完成**。单次采集支持下一轮针对 Timer cadence / mode boundary 的实验，但不支持在当前阶段宣称已经定位系统根因。

### 5.1 `phys1b-06` 真实触控板结果

匿名环境记录：主显示器 60Hz、屏幕 1470×956pt、全屏 app frame 1470×923pt、低电量模式关闭、真实触控板；共 30 个 gesture begin/end 序列。应用通过正常 Cmd-Q 退出，`teardown.complete` 与 `run.end` 均已写入，不能使用此前未关闭时的部分统计。

| 产物 | 行数 | SHA-256 |
|---|---:|---|
| telemetry | 1,259 | `b8dcd028e873714a54cb911e2e022808b432b9081af5724cd5b43c4aec172482` |
| frame profile | 1,494 | `8e4b5a0501a44f684afc05c7ac7c1bbb8777a59a0210c1800bda7279b205c1f6` |
| runloop profile | 254,766 | `3100b291849469eae8545324b4179d6935fcbbb7311d574aa2888bb3e8d5105c` |

计数与完整性：telemetry 591 frame、30 began、30 ended、107 changed、90 momentum；frame profile 591 frame；所有 JSONL 行可解析。runloop 文件较大是因为应用空闲等待期间 observer 仍在记录；最终分析只使用 frame windows，不将空闲尾部当作 hitch 证据。

### 5.2 `phys1b-06` runloop 分解（描述性，不是因果证明）

独立只读分解与本地复核一致：17 个 hitch 与 544 个已对齐正常 frame 比较，典型 hitch 的 waiting-like 每-frame 中位数为 **14.072ms**，正常为 **10.958ms**（约 +3.114ms）；active-like 为 **0.810ms vs 0.812ms**；unclassified 为 **5.093ms vs 4.830ms**。全部 17 个 hitch 的 preceding callback 中位数为 **0.647ms**，最大 **0.937ms**。

这只能支持以下窄结论：

> 在这一次 60Hz 真实触控板运行中，典型 >20ms frame interval 包含了更长的 `beforeWaiting→afterWaiting` waiting-like 区段，而已分类 active-like 时间没有同步增加。

它不能升级为以下强结论：

- 已证明线程 wake-up latency、内核调度或 Timer tolerance 是根因；
- 已证明 WindowServer、Core Animation、AppKit deferred display/layout 中的任一项；
- 已证明 17 个 hitch 属于同一原因；
- 已证明用户一定能感知每一个 >20ms interval。

尤其是 4 个包含 >10ms unclassified 片段的 hitch，应保留为未分类；3 个明显的 `exit→entry` 长尾不能被重命名为 scheduler 或 WindowServer。

---

## 6. 修复与验证优先级

| 优先级 | 动作 | 预期收益 | 成本/风险 |
|---:|---|---|---|
| DONE | 把 frame/runloop recorder 写盘移出 hot callback；teardown barrier flush | 已去除已知同步写盘污染；独立 Reviewer PASS | 自动化完成；不等于物理手感 PASS |
| DONE | 用修复后探针完成一次真实触控板运行 | 已获得一次真实 runloop phase 分解 | 单次样本；不等于根因定位 |
| DONE | 用可复跑 analyzer 生成逐 hitch 报告并修正 preceding-callback ordinal | 已消除临时脚本、跨时钟误 join 与一帧归因错位 | Python stdlib；15 tests 全绿 |
| P1 | 若主要为 active-like：用 signpost/Instruments 采样 AppKit display、CA transaction、MainActor icon apply、telemetry flush | 把粗 phase 收窄到调用栈/提交点 | 中；需 GUI/Instruments，observer 本身不能完成 |
| P0 | 针对 Timer cadence 与 mode-boundary 做 A/B：先减小/置零 Timer tolerance，再对 exit→entry 与 afterWaiting→beforeTimers 长尾加最小额外探针 | 区分 cadence/tolerance 候选与仍未解释的 mode-boundary 长尾 | 中；仍需保持探针异步写盘与匿名约束 |
| P1 | 若主要为 waiting-like 且 callback 很短：验证 Timer cadence、wake-up、App Nap/电源状态，并重启 vsync 路线 | 当前 60Hz Timer 非 vsync，是结构性抖动候选 | 中到高；此前 display-link 在真实 Aqua 环境有零 callback 历史，不能盲切 |
| P2 | 仅当 icon apply 与 hitch 稳定共现时再优化图标 draw/texture 路径 | 避免优化错误目标 | 中 |
| P2 | 仅当 AppKit deferred layout/display 被采样证实时，优化 layer backing、失效范围或预绘制 | 有针对性减少主线程/提交峰值 | 中到高 |


## 6.1 可复跑 analyzer 状态

已交付：

- `Tools/analyze_frame_hitches.py`
- `Tools/tests/test_analyze_frame_hitches.py`
- `Docs/FRAME_HITCH_ANALYZER.md`
- `Workflow/results/T-frame-hitch-analyzer.md`
- `Workflow/reviews/T-frame-hitch-analyzer-r1.md`

原独立 Reviewer 曾给出 **PASS，P0/P1/P2=0**；该结论已被后续 Terra 审计发现的 callback ordinal P1 缺陷所取代。当前状态是：缺陷已修复、15 个 Python 测试通过、历史样本已按 preceding callback 语义重算。

约束已在工具中固化：仅统计 telemetry `event_phase=frame`；telemetry 与 profile 只按 frame ordinal 关联，并在各自时钟域内验证相邻 interval；runloop `gap_ns` 必须与真实相邻 activity pair 的 timestamp delta 一致后才允许分类；输出只含固定匿名字段。缺 frame 或 runloop profile 时保持 `UNRESOLVED`，SELFDRIVE 明确标注为非物理手感证据。

## 7. 下一阶段实验协议

修复版真实触控板采集已完成。下一步不应继续盲目调 PagingCore 参数，而应做针对性的 Timer/runloop 实验：

```text
A/B-1：保持物理手势协议与页面内容不变，仅将 Timer tolerance 从当前值减小到 0 或一个远小于 frame budget 的值。
A/B-2：保持 A/B-1 不变，继续启用匿名 frame profile + runloop profile；至少重复多轮真实触控板运行。
A/B-3：对 `exit→entry`、`afterWaiting→beforeTimers` 等当前未细分区段增加低开销 phase/mode 边界记录；不把它们预先标为 scheduler、WindowServer 或 CA。
A/B-4：若条件允许，在 120Hz 设备上重跑同一协议；60Hz MacBook Air 结果不能外推为 120Hz。
```

### 实验纪律

1. 每个 A/B 只改变一个变量；保留设备刷新率、窗口尺寸、电源状态、手势数量和匿名产物 hash。
2. 真实触控板结果与 SELFDRIVE 分开；SELFDRIVE 只做性能对照。
3. 正常退出并确认 teardown flush；不使用仅有 512 行批次或缺少 `run.end` 的部分产物。
4. 继续冻结 `Sources/PagingCore/`；不以参数调优掩盖 instrumentation 或 scheduling 问题。
5. 对不符合已验证相邻 pair 的 gap 保持 `unclassified`；不得把 waiting-like 直接翻译成 wake-up latency。

### 现阶段归因规则

对 hitch 窗口 `(frame[i-1].uptime, frame[i].uptime]`：

- preceding callback 使用 `profile[i-1]`，不能使用 `profile[i]`；
- `beforeWaiting→afterWaiting` 增大时，只报告 waiting-like pattern；
- `afterWaiting→beforeTimers` 等 active-like 增大时，才提升“回调外主线程工作候选”；
- `exit→entry`、`afterWaiting→exit` 等未能证明语义的 pair 保持 unclassified；
- 只有跨多轮 A/B、且与单变量变化稳定共变，才可升级某个候选的证据强度。

## 8. 此前门结论（`phys1b-06`，已由 §9 更新）

- `phys1b-06` 完整落盘：telemetry 591 frame、frame profile 591 frame、runloop profile 可解析；30/30 gesture begin/end；teardown 完成。
- 修复版 analyzer：**15 tests, 0 failures**；preceding-callback ordinal 已明确并有回归测试。
- 修复版 `phys1b-06`：591 frames / 17 个 >20ms / 3 个 >25ms / max 27.986ms；preceding callback max 0.937ms。
- 17/17 hitch 通过局部 profile ordinal 验证；29 个普通相邻 interval mismatch 被透明保留，没有被隐藏或修复成伪对齐。
- runloop 描述性比较支持典型 hitch 的 waiting-like 每-frame 中位数高约 3.114ms；active-like 中位数未增加；少数 unclassified mode-boundary 长尾仍未解释。
- Swift：`phys1b-06` 收口时 Main 复验为 **440 tests, 0 failures**；2026-08-29 定向改动后的当前值见 §9。
- Release：本次 Main 复验 `swift build -c release` exit 0。
- 输入产物 hash、行数和 JSONL 可解析性已复核；生成分析报告隐私扫描 clean。
- `SELFDRIVE` 仍明确是合成性能对照，不是物理手感证据。
- 截至 `phys1b-06` 时尚无 Timer tolerance 单变量证据；该历史门已被 §9 的双轨 A/B 部分更新。线程调度、WindowServer、Core Animation 或 AppKit 单一根因仍未定位。

**历史阶段结论（已由 §9 supersede）：`PROCEED_TO_TARGETED_WAKE_AND_MODE_BOUNDARY_PROFILING`。**

## 9. 2026-08-29 定向 Timer tolerance A/B 补充

### 9.1 实验

为验证默认 `Timer.tolerance = 8.333ms` 是否贡献 `20–25ms` 短尾，增加 `--frame-timer-tolerance-ms`，并按 `A1 B1 B2 A2 A3 B3` 执行两条 Release SELFDRIVE 轨道：

1. Full probe：telemetry + frame profile + runloop observer；
2. Lite probe：telemetry only，用于检查高频 runloop observer 是否足以解释 A/B 差异。

两条轨道均固定 neutral content、RunLoop Timer 实际帧源和窗口模式。每个正式 run 都有 40/40 gesture began/ended、`run.end` 和 `teardown.complete`。

### 9.2 MEASURED

| Track | Arm | Frames | >20ms rate/1000 | 20–25ms rate/1000 | >25ms rate/1000 | pooled p95 | pooled p99 | max |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Full | 8.333ms | 1,675 | 29.85 | 26.87 | 2.99 | 19.042 | 23.231 | 33.348 |
| Full | 0ms | 1,544 | 11.01 | 8.42 | 2.59 | 18.039 | 20.257 | 30.884 |
| Lite | 8.333ms | 1,695 | 28.32 | 26.55 | 1.77 | 19.123 | 22.604 | 28.399 |
| Lite | 0ms | 1,537 | 12.36 | 9.76 | 2.60 | 18.225 | 21.021 | 29.862 |

- Full 的 `20–25ms` rate 下降约 68.7%；Lite 下降约 63.2%。
- Full/Lite 方向一致，说明 runloop observer 不是短尾差异的充分解释。
- `>25ms` 没有稳定改善，不能归因给 tolerance。
- Full 六轮的匿名 mode 全部为 `default`；SELFDRIVE 没有覆盖真实触控板 `eventTracking`，不能排除或验证 mode-boundary。
- SELFDRIVE 的 commit/stale 结果随 tolerance 明显改变，说明 0ms 不只是日志层变化；生产默认改变前必须做物理 ABBA 和能耗检查。

### 9.3 证据升级与边界

**已升级：**

```text
SUPPORTED_PARTIAL_CONTRIBUTOR_TIMER_TOLERANCE_FOR_20_TO_25MS
```

**仍未升级：**

- tolerance 不是 27–53ms 长尾的完整解释；
- 未证明 scheduler、wake-up、AppKit、Core Animation、WindowServer 或 GPU 根因；
- 未观察 nominal deadline、callback lateness、missed periods、first-tick latency 或完整 Timer callback CPU；
- SELFDRIVE 不是触控板手感 PASS。

详细协议、逐轮数据及 hash：

- `Docs/TIMER_TOLERANCE_MODE_AB_PLAN.md`
- `Docs/TIMER_TOLERANCE_AB_RESULTS.md`
- `Docs/TIMER_TOLERANCE_AB_ARTIFACTS.sha256`

### 9.4 更新后的门

```text
REQUIRE_PHYSICAL_AB_BEFORE_DEFAULT_CHANGE
PROCEED_TO_DEADLINE_FIRST_TICK_CALLBACK_BOUNDARY_PROFILING_FOR_LONG_TAIL
```

本轮验证：Swift **444 tests, 0 failures**；Python analyzer **15 tests, 0 failures**；Release build exit 0。`Sources/PagingCore/` 未修改。

## 10. 2026-08-29 Callback boundary ABBA 补充（独立审查后收紧）

真实 GUI callback recorder 已接入 RunLoop Timer，并完成 callback-only ABBA（8.333ms / 0ms / 0ms / 8.333ms）。独立审查后增加 reentrant `stop()+start()` generation guard 与回归测试；最终自动验证为 Swift **454 tests, 0 failures**、Python **20 tests, 0 failures**、Release build exit 0；`Sources/PagingCore/` 未修改。

四轮共有 2,017 input/accepted callback records、0 rejected、0 ignored non-callback；1,907 个 raw intervals，first ticks 明确排除在 raw interval 分布之外。严格大于 25ms 的 raw interval 共 5 个，上一 recorded segment 的 current-thread CPU 最大 1.928ms，因而不足以解释这五个样本。五个样本都有多数时长落在上一 recorded exit boundary 与下一 recorded entry boundary 之间；三个最清晰样本的 remainder 为 97.2%–99.1%，另一个 27.055ms 样本仍是 substantial mixed recorded-segment case。

`recorded exit boundary` 在 `advanceFrame` 返回后、recorder `endCallback` 开头采样，不等于 Timer closure 已返回。remainder 仍可能包含同一 closure 内剩余工作和下一 recorder entry 前的其他未观测时间。因此不能称为严格的“callback 外时间”，也不能据此归因 scheduler、RunLoop、WindowServer、AppKit、Core Animation、GPU 或其他组件。

另有独立 first-tick >25ms delay；B2 在 tolerance=0 时仍有 35.841ms first tick。其因果未定位，且不进入 raw interval 分布。A/B pooled >25ms rate 受 B2 单轮孤立长尾支配，不能解释为 0ms 改善或恶化长尾。

更新后的窄门：

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

详细结果与 hashes：

- `Docs/CALLBACK_BOUNDARY_ABBA_RESULTS.md`
- `Docs/CALLBACK_BOUNDARY_ABBA_ARTIFACTS.sha256`
