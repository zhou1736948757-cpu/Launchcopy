# Timer Tolerance / RunLoop Mode 定位计划

> **后续术语校正（2026-08-29）：** 后续实现记录的是 Timer closure entry 到 `advanceFrame` 返回后的 recorded-exit marker；该 marker 不等于已确认的 Timer closure return。`scheduled_ns` / `lateness_ns` 基于 recorder-maintained nominal schedule，而不是 Timer/CFRunLoop 报告的真实 fire deadline。当前权威结论见 `Docs/CALLBACK_BOUNDARY_ABBA_RESULTS.md`。


> 日期：2026-08-29  
> 范围：`/Users/mac/Projects/Launch_Copy/PagingPrototype`  
> 目标：定位偶发 `20–53ms` frame interval 的可重复贡献因素；不修改 `Sources/PagingCore/`，不把相关性写成系统组件因果。

## 1. 当前问题定义

现有真实触控板证据 `phys1b-06`：

- 591 个 frame；
- 17 个 `>20ms`；
- 3 个 `>25ms`；
- 最大 27.986ms；
- 已测 preceding `advanceFrame` callback 最大 0.937ms；
- 典型 hitch 的 waiting-like 区间比正常帧长，但不能据此命名为 scheduler、wake-up、WindowServer 或 Core Animation 根因。

当前 `RunLoopFrameDriver` 的名义周期为 `1/60s = 16.667ms`，默认 `Timer.tolerance = 1/120s = 8.333ms`。Foundation repeating Timer 可在 scheduled fire date 后的 tolerance 窗口内被服务，且后续 fire date 保持原始节拍。因此仅在 tolerance 模型内，相邻 callback gap 就可能落在约 `8.334–25.000ms`，并产生“长间隔后接短间隔”的恢复形态。

这只是**可行机制**，不是历史 hitch 已归因。尤其是 `27.986–53.510ms` 超出 tolerance-only 模型，需要另一个或多个贡献因素。

## 2. 证据分级

| 等级 | 含义 |
|---|---|
| `MEASURED` | 当前运行直接记录到的数量、时间或固定枚举 |
| `SUPPORTED_CONTRIBUTOR` | 单变量重复 A/B 中稳定共变，可支持“贡献因素” |
| `INFERRED` | 与代码机制及观测相容，但没有单变量证据 |
| `UNRESOLVED` | 探针当前无法区分，禁止具体归因 |

本阶段不使用 `ROOT_CAUSE_CONFIRMED`。即使 tolerance A/B 显著，也最多先提升为 `SUPPORTED_PARTIAL_CONTRIBUTOR`。

## 3. 已实现的最小实验缝

### 3.1 Timer tolerance 参数

新增：

```text
--frame-timer-tolerance-ms <0–16.667>
```

- 缺省：保留 8.333ms；
- `0`：关闭 Timer tolerance；
- 非数字、负值、超过 16.667ms：显式退出 2，不静默回退；
- RunLoop 和 display-link 观察包装路径均把该值传给实际 RunLoop Timer 帧源；
- `Sources/PagingCore/` 未改。

### 3.2 匿名 runloop mode

Runloop profile 每条记录只允许：

```text
default
eventTracking
modalPanel
other
none
```

不落盘原始 mode 字符串。该字段只说明观测发生时的匿名类别，不能单独证明 mode 导致 hitch。

## 4. 实验矩阵

### 4.1 Tolerance 主 A/B

| Arm | Timer interval | Timer tolerance | Frame source | Content |
|---|---:|---:|---|---|
| A | 16.667ms | 8.333ms | RunLoop Timer | neutral |
| B | 16.667ms | 0ms | RunLoop Timer | neutral |

顺序使用交错序列：

```text
A1 B1 B2 A2 A3 B3
```

每轮必须完整出现 `run.end` 和 `teardown.complete`。主指标：

- `>20ms`、`20–25ms`、`>25ms`、`>33.3ms`、`>50ms`；
- p95、p99、max；
- preceding callback duration；
- runloop waiting-like / active-like / unclassified；
- mode 固定枚举分布；
- frame/profile ordinal mismatch；
- SELFDRIVE 行为结果变化（只作混杂/副作用提示，不作物理手感结论）。

### 4.2 探针污染对照

先执行 profile-on A/B，再用相同顺序执行 telemetry-only A/B：

| Track | Telemetry | Frame profile | Runloop observer |
|---|---:|---:|---:|
| Full probe | on | on | on |
| Lite probe | on | off | off |

若 tolerance 的短尾改善只在 Full probe 出现，需优先怀疑 runloop observer 与 tolerance 的交互；若两条 track 都重复出现，则 tolerance 贡献证据增强。

### 4.3 后续物理 A/B

SELFDRIVE 只用于受控性能比较，不是触控板手感验收。生产默认值改变前必须做真实触控板 ABBA：

- 同一 60Hz 设备；
- 同一窗口/全屏尺寸；
- 同一电源和低电量状态；
- 相同 30 组手势协议；
- A/B 各至少 3 个完整有效 run；
- profiling 开关两臂一致；
- 原始异常 run 保留，不静默删除；
- 同时记录主观五项和 telemetry 指标。

## 5. 判读规则

### 5.1 tolerance 可升级为部分贡献因素

需要同时满足：

1. B 在每轮或绝大多数轮中稳定降低 `20–25ms`；
2. Full probe 与 Lite probe 方向一致；
3. `>25ms` 若不改善，明确限定结论只覆盖短尾；
4. 不把剩余 waiting-like 改名为 scheduler/wake-up；
5. 真实触控板 A/B 未出现不可接受的手感、行为或能耗退化，才考虑产品默认。

### 5.2 tolerance 不被支持

若 A/B 分布重叠、方向不稳定或仅单轮改善，则保留为机制假设，不改变默认值。

### 5.3 mode-boundary 后续门

SELFDRIVE 若全部处于 `default`，则它不能验证真实触控板 `eventTracking`。只有物理数据中出现足够的 mode 类别变化，才进入：

```text
common
vs
explicit default + eventTracking
```

注册策略 A/B。`default-only` 只能作为短时负对照，不是产品候选。

## 6. 当前探针盲区

1. 没有 nominal scheduled deadline、callback entry/exit、lateness、missed periods；
2. Timer 每次 start 会重建，首 callback 固定报告 16.667ms，实际 start→首 callback 等待不可见；
3. frame profile 从 `PagingSurface.advanceFrame` 开始，不覆盖完整 Timer closure；
4. telemetry/profile/runloop 没有统一 `callback_seq`，仍依赖 ordinal + 本地相邻 interval 验证；
5. 没有主线程 CPU time，不能区分低 CPU waiting-like 与线程未运行/其他阻塞；
6. `--frame-profile` 仍把 frame probe 与高频 runloop observer 绑定；
7. 当前 display-link 选项不是实际帧源 A/B，实际分页帧仍来自 RunLoop Timer。

## 7. 下一层最小探针（仅在物理 A/B 后仍需深挖时）

建议单独诊断文件，统一 monotonic timestamp，最小字段：

```text
callback_seq
scheduled_ns
entry_ns
exit_ns
lateness_ns
missed_periods
first_tick
driver_generation
raw_callback_interval_ns
simulation_dt_ns
mode (fixed anonymous enum)
thread_cpu_entry_ns
thread_cpu_exit_ns
```

Frame record 只新增 `callback_seq`；runloop boundary 新增 `cycle_seq` 和 `thread_cpu_ns`。主 telemetry schema 暂不扩张。

## 8. 禁止性结论

在现有证据下禁止写：

- “已经修好所有卡顿”；
- “根因就是 macOS scheduler / wake-up”；
- “根因就是 WindowServer / Core Animation / GPU”；
- “`.common` 已在真实 eventTracking 下验证无误”；
- “SELFDRIVE 等于真实触控板 PASS”；
- “0ms tolerance 可以直接作为生产默认且没有能耗代价”。
