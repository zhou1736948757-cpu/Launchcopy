# 帧交付节奏不规则(滑动轻微卡顿)问题简报 — FRAME_LAG_PROBLEM_BRIEF

- 日期:2026-08-30
- 项目:PagingPrototype(macOS AppKit 分页启动器,Swift Package,独立实现)
- 状态:`CAUSALITY_UNRESOLVED`(根因未定论;已有部分证据支持"Timer tolerance 是 20–25ms 短尾的显著贡献者",但 >25ms 粗长尾在 tolerance-0 下仍存在,说明不止一个根因)
- 红线:未修改任何代码/参数;生产默认 `Timer tolerance = 8.333ms` 原样;无任何"已修复"结论。

---

## 1. 问题现象(用户主观)

用户在全屏分页启动器(1470×923,60Hz 面板)上用触控板滑动翻页时,感觉"轻微卡顿/帧节奏不跟手"。用户怀疑是心理作用,要求客观测量验证。

## 2. 客观测量证据(真实 GUI 采集,非模拟)

### 2.1 方法
- 用 **Release 二进制**(SHA `29ea6928…`)以 `--neutral-content --disable-telemetry-bridge --frame-profile --frame-callback-profile --runloop-profile` 启动,进入真实 GUI 全屏分页。
- **SELFDRIVE 合成滚动**驱动翻页(项目明确定义:合成性能对照,不是真实触控板物理手感证据),采集 RunLoop Timer 帧回调节奏(帧间间隔)。
- 两轨对照:**生产默认(8.333ms tolerance)** vs **`--frame-timer-tolerance-ms 0`(tolerance-0)**。
- 60Hz 目标帧间隔 = **16.67ms**。
- 产物:`/tmp/launch-copy-paging-prototype-swipelag-{callback,profile,runloop}.jsonl` 与 `-swipelag0-*` 对照轨。

### 2.2 结果(帧间间隔分布)

| 指标 | 生产默认(8.333ms tolerance) | tolerance-0 对照 |
|---|---|---|
| 帧间隔 p95 | **22.2ms** | 17.6ms |
| 帧间隔 p99 | **32.9ms** | 20.7ms |
| 帧间隔 max | **37.6ms** | 56.5ms* |
| 间隔 >20ms 次数 | **47** | 8 |
| 间隔 >25ms 次数 | **12** | 4 |
| 间隔 >33ms 次数 | 3 | 3 |
| 间隔 >50ms 次数 | 0 | 1* |

(*tolerance-0 的 56.5ms 为单次离群值)

### 2.3 关键读数
- **每帧加工开销极小**:回调内 wall time 均值 ≈0.7ms,p95 ≈1ms → **卡顿不是 UI/渲染代码太重**。
- 生产默认下回调经常掉到 20–37ms(相当于 60Hz 下掉 1–2 帧),与用户"轻微卡顿"的主观感受一致。
- **8.333ms tolerance 显著贡献 20–25ms 短尾**(tolerance-0 后 >20ms 从 47 次降到 8 次,p95 22.2→17.6ms)。
- **>25ms 的粗长尾在 tolerance-0 下仍存在**(>25ms 4 次、>33ms 3 次、56.5ms 离群)→ **根因不止 tolerance 一个**。

### 2.4 为什么自动化测试测不出
- 无头 PerfBenchmark 探针(1/2/5/10/20 页)全部 `miss16=0, hitch50=0`,帧均值 23–71µs;性能聚焦测试 51/51 通过。
- 原因:这些探针用**显式 `advanceFrame` 驱动**,绕过了真实 Timer 交付路径 → 测的是"加工开销",测不到"交付节奏"。

## 3. 已排除 / 已确认的候选原因

| 候选 | 结论 | 证据 |
|---|---|---|
| UI/渲染代码过重 | **排除** | 每帧回调内工作均值 ≈0.7ms |
| Timer tolerance 8.333ms | **显著贡献者(部分确认)** | tolerance-0 后 p95 22.2→17.6ms,>20ms 47→8 |
| 单一根因 | **排除** | tolerance-0 下 >25ms 粗长尾仍在(56.5ms 离群) |
| 帧源交付节奏(调度/合并/等待边界) | **主嫌疑** | 加工开销小但交付间隔抖动大 |
| 120Hz 面板 | 不适用 | 硬件为 60Hz 面板(120Hz 门 BLOCKED_BY_HARDWARE) |

### 3.1 既有历史证据(本项目早期调查,未解决)
- `Docs/FRAME_HITCH_DEEP_DIVE_REPORT.md`:已记录(未解决)的帧卡顿深潜发现,与本报告一致。
- `Docs/FRAME_HITCH_ROOT_CAUSE_CORRELATION_RESULTS.md:226` + events.jsonl seq181:**物理触控板 20–25ms 区间,约 10ms 由 RunLoop exit→entry 部分贡献**(诊断 token:`PARTIAL_CONTRIBUTOR_SUPPORTED`)。
- 诊断纪律:禁止声称 `ROOT_CAUSE_FOUND` / `ALL_HITCHES_FIXED` / `FIX_VALIDATED`;当前 token 保持 `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`。

## 4. 系统架构上下文(供分析)

- **帧源**:RunLoop Timer,生产默认 `tolerance = 8.333ms`(合法范围 0–16.667ms,CLI 可调 `--frame-timer-tolerance-ms`);另有 `--frame-driver runloop|displaylink|auto` 选项(displaylink 驱动存在但非默认)。
- **输入链**:触控板 scrollWheel → ScrollInputMapper → GestureSession(速度窗口 0.1s,≤8 样本,ΣscaledΔ/Σdt;释放后速度由 momentum 样本决定)→ PageTargetPolicy(位移阈值 前进 0.42 / 回退 0.35;速度 ≥700px/s 强制翻页;否则 位移比+0.3×归一化速度 混合分)→ PagingCore 状态机 → settle 动画(0.15–0.4s)。
- **渲染**:每帧刷新 live host 内容(全窗口宽);加工开销 ≈0.7ms/帧。
- **运行环境**:macOS 全屏 1470×923,60Hz 面板;AppKit 应用,无全局事件监听、无 Accessibility 权限、无同步 I/O。

## 5. 待 GPT 分析的问题(开放问题)

1. **机制**:为什么 8.333ms tolerance(半帧)在真实 RunLoop 上会放大出 20–25ms 的交付间隔?是 Timer 合并(coalescing)、App Nap、系统负载、还是 RunLoop 模式切换(exit→entry)的代价?
2. **粗长尾**:tolerance-0 下仍存在的 >25ms(含 56.5ms 离群)最可能来自哪一层?窗口服务器(WindowServer)合成、GPU 提交、系统调度抢占、还是 displaylink 与 runloop 驱动差异?
3. **方案对比**:对 60Hz 帧源,`CVDisplayLink`(displaylink 驱动)是否比 RunLoop Timer 交付更规则?项目已有该选项但未默认启用——值得切吗?代价(CPU 唤醒、电池)如何?
4. **测量方法**:如何进一步隔离各层贡献(如 mach_absolute_time 打点、dispatch source、CADisplayLink 对照、tolerance 梯度扫描 0/2/4/8ms)?
5. **参数建议**:若要把生产默认 tolerance 从 8.333ms 调小(如 0 或 4ms),权衡是什么?是否应同时评估 `--frame-driver displaylink`?
6. **验证闭环**:真实触控板物理手感门(120Hz 触控板)与合成 SELFDRIVE 的关系——合成对照能证明"交付节奏不规则"这一客观事实,但最终手感仍需物理门确认,如何设计可重复的物理门?

## 6. 约束与后续路径

- 本简报为**纯调查证据**,未改任何代码;生产默认参数未动。
- 若决定调整(如 tolerance 默认值、帧驱动切换),按项目流程走**用户决策调参轮**(decision_recorded → Worker 实现 → 独立 Reviewer PASS → 重建),不会静默修改。
- 诊断状态保持 `CAUSALITY_UNRESOLVED` / `PARTIAL_CONTRIBUTOR_SUPPORTED` / `PRODUCT_DEFAULT_UNCHANGED`,直到有可重复的根因证据。
