# 帧交付节奏不规则 — 简报分析（对 `FRAME_LAG_PROBLEM_BRIEF.md`）

- 日期: 2026-08-30
- 输入: `Docs/FRAME_LAG_PROBLEM_BRIEF.md`（T-1D-framelag-probe SELFDRIVE）+ 既有 hitch / tolerance / callback-boundary / correlation 证据
- 性质: **分析备忘，不是修复、不是调参、不是根因定论**
- 诊断 token 保持:

```text
CAUSALITY_UNRESOLVED
PARTIAL_CONTRIBUTOR_SUPPORTED
SUPPORTED_PARTIAL_CONTRIBUTOR_TIMER_TOLERANCE_FOR_20_TO_25MS
PHYSICAL_20_TO_25MS_RUNLOOP_EXIT_ENTRY_APPROX_10MS
PRODUCT_DEFAULT_UNCHANGED
REQUIRE_PHYSICAL_AB_BEFORE_TIMER_TOLERANCE_DEFAULT_CHANGE
```

- 禁止升级: `ROOT_CAUSE_FOUND` / `ALL_HITCHES_FIXED` / `FIX_VALIDATED` / `SCHEDULER_CONFIRMED` / `WINDOWSERVER_CONFIRMED` / `GPU_CONFIRMED`
- 红线: 生产默认 `Timer.tolerance = 8.333ms` 未改；`--frame-driver displaylink` **并不驱动分页帧**。

---

## 0. 先给可执行结论

用户主观「轻微卡顿」**有客观对应**：60Hz 上生产默认回调间隔 p95 22.2ms、>20ms 47 次，等价于经常晚 ½–1 帧。这不是心理作用，也不是 UI/渲染太重（回调内 ~0.7ms）。

两段尾巴要分开，不能合成一个根因：

| 段 | 典型宽度 | 已支持的贡献者 | 未定位 |
|---|---|---|---|
| 短尾 | 20–25ms | 默认 8.333ms Timer tolerance（SELFDRIVE 单变量 A/B，Full+Lite 同向，20–25ms 频率降 ~63–69%） | 精确内核机制（见 §1，推断为 coalescing / leeway，未在 kqueue 层证实） |
| 粗长尾 | >25ms，偶发 37–72ms | **不是** tolerance。物理轨上每个 >25ms remainder 含一次 ~10ms `exit→entry` | 为何 RunLoop 离开 ~10ms；SELFDRIVE 的另一些 >25ms 形状还不同 |

**不要**把生产默认改成 0ms。SELFDRIVE 上 0ms 会改变 commit 数（约 17–20 → 29–30 / 40 fling），可能是更稳 cadence 的真效果，也可能是合成输入 × Timer restart 的耦合。门是 `REQUIRE_PHYSICAL_AB_BEFORE_DEFAULT_CHANGE`。

**不要**把 `--frame-driver displaylink` 当成「切 vsync 帧源」。现实现里 `DisplayLinkFrameDriver` 只观测，真正 `advanceFrame` 仍来自内部 `RunLoopFrameDriver`。要做帧源对照，必须新写「真驱动」实现，走 Worker；不是 CLI 开关。

往下按流程拆：

| 动作 | 类型 | 要不要用户 `decision_recorded` |
|---|---|---|
| tolerance 梯度 SELFDRIVE `0/2/4/8.333` | 测量探针（现有 CLI） | 否 |
| 用户亲手 A/B：默认 vs `--frame-timer-tolerance-ms 0`（及可选 4） | 物理手感对照，不改代码 | 否（人手操作，不是调参） |
| 读真实 `Timer.fireDate` / 真 CADisplayLink 驱动臂 | 测量向 Worker（默认不变） | 否（opt-in 实验缝，默认仍 RunLoop 8.333） |
| 把生产默认 tolerance 改成 4 或 0 | 调参 | **是** |
| 把生产帧源改成 DisplayLink | 调参 + 新代码 | **是**（且须先有真驱动实验数据） |

---

## 1. 机制：8.333ms tolerance 为何放大成 20–25ms

**等级: `INFERRED` 机制 + `SUPPORTED_PARTIAL_CONTRIBUTOR` 效应。**

Foundation repeating `Timer` 的公开语义（项目计划已写过，见 `Docs/TIMER_TOLERANCE_MODE_AB_PLAN.md` §1）：

- 周期 16.667ms，tolerance 8.333ms；
- 系统**只允许晚、不允许早**，可在 scheduled fire date 之后最多 8.333ms 才服务；
- 下一发仍按**原始节拍**算，不从实际 fire 时刻重排。

因此相邻两次 callback 的合法窗口是：

```text
observed_gap = interval + d2 − d1
d1, d2 ∈ [0, 8.333ms]
⇒ observed_gap ∈ [8.334ms, 25.000ms]
```

20–25ms 正好是这个窗口的上半段：上一拍准时、下一拍被合到 tolerance 末端（或两拍延迟差接近 +8.333ms）。16.667 + 8.333 = **25.000ms** 是「单周期 + 满 leeway」的理论上沿。这与「长间隔后接短间隔」的恢复形态相容（`phys1b-04` 已见 48→25→16.7 / 47→25→10）。

各候选对号：

| 候选 | 判断 | 理由 |
|---|---|---|
| Timer coalescing / leeway（tolerance 的本意） | **最相容** | 短尾集中在 20–25ms；tolerance→0 后 >20ms 47→8、p95 22.2→17.6；Full 与 Lite 同向，排除高频 runloop observer 为充分解释 |
| App Nap | 不像主因 | 全屏前台交互中；Nap 更像长时间让出，不是稳定的 20–25ms 带 |
| 系统负载 / 抢占 | 不是短尾的主形状 | 负载尖峰更散、更长；短尾随 tolerance 单变量消失 |
| RunLoop mode 切换（exit→entry） | **不是这条短尾** | tolerance A/B 是 SELFDRIVE，mode 全是 `default`；物理轨 ~10ms `exit→entry` 出现在 **tolerance=0** 上，aa-f2 该桶为 0。两件事不要并成一个 |

仍不能写「已在内核证实 coalescing」：当前 `scheduled_ns` / `lateness_ns` 是 recorder 自己维持的名义节拍，**不是** `Timer.fireDate` / `CFRunLoopTimer` 报的真实 deadline（`CALLBACK_BOUNDARY_ABBA_RESULTS.md` 术语校正）。要把推断升到「真实 fire deadline 被推到窗口末端」，需要读 Timer 自己的 fire date（见 §4 探针 M3）。

---

## 2. 粗长尾：tolerance-0 下 >25ms 最可能在哪一层

**等级: 形状已收窄，组件未证实。禁止点名单一系统组件。**

先把不同捕获的 >25ms **拆开**，相关报告已明确：不要把物理 25ms、SELFDRIVE 26.5ms、SELFDRIVE 36.5ms 合成一种机制。

### 2.1 已排除

- 回调内加工：均值 ~0.7ms，p95 ~1ms；phys1b-06 preceding callback max 0.937ms。
- 上一 recorded segment 的 current-thread CPU：callback-boundary 五个 >25ms 样本 CPU ≤ 1.928ms，remainder 多数在 recorded-exit → next-entry。
- Timer closure 尾（pre_return − recorded exit）：p99 < 0.01ms，解释不了 remainder。
- 默认 8.333ms tolerance：0ms 后 >25ms 不稳降（本简报 12→4 仍在；历史 Full 5→4；ABBA B2 甚至出现 72.458ms）。

### 2.2 物理轨（更接近用户手感）

tolerance=0、真实触控板 Full profiler（phys-r1/r2）：

- 体 ~0.2ms；
- waiting-like ~14ms；
- 每个 >25ms remainder **都含**一次稳定的 ~10.0–10.2ms `exit→entry`。

这支持：`PARTIAL_CONTRIBUTOR_SUPPORTED` / `PHYSICAL_20_TO_25MS_RUNLOOP_EXIT_ENTRY_APPROX_10MS`。

「为何离开 10ms」仍是 `UNRESOLVED`。相容候选（都不是因果名）：嵌套 `CFRunLoopRunInMode`、AppKit tracking/spin、本次 invocation 之外的 mach wait。导出的 System Trace thread-state **没有**本进程行，runnable-but-unscheduled **未证明**。System Trace 本身会把 leave/re-enter 拉长（phys-st-r1：>25ms 1→25，8–12ms `exit→entry` 17→322）——正式物理门不要开 ST。

物理 >25ms 样本的 mode 仍记为 `default`。SELFDRIVE 全 `default`，**覆盖不了** `eventTracking`。`.common` 已在真实 tracking 下无误 —— 这句话仍禁止。

### 2.3 SELFDRIVE 长尾（形状不同）

- 有的是 6.8ms on-CPU body + wait + `afterWaiting→exit`（aa-f2 26.5ms）；
- ST 下 36.5ms 由 `beforeSources→exit` 占 35.5ms；
- B2 72ms / 本简报 56.5ms 是稀有离群，remainder ~99%，不能拿单点定架构。

这些更像「这一轮 RunLoop 在 sources/timers 里停住或根本没回到这条 Timer」，不是 WindowServer 合成或 GPU 提交的直接证据。WindowServer/GPU 若要成为候选，需要 **进程外** 合成延迟且主线程 recorded body 仍短——目前没有这样的同时钟证据。

### 2.4 displaylink vs runloop？

**现在回答不了，因为 displaylink 没有在驱动帧。** 现有长尾全部发生在 RunLoop Timer 路径上。切不切 DisplayLink 与「当前长尾来自哪一层」是两个问题。即便将来真用 CADisplayLink 驱动，它也是 `add(to:runLoop, forMode:.common)`，**RunLoop 离开 10ms 时 DisplayLink 同样到不了**。DisplayLink 可能改善的是 vsync 对齐和 Timer leeway，不是这段 exit→entry。

---

## 3. 方案对比：CADisplayLink / CVDisplayLink 值不值得切

### 3.1 现状（容易误判）

- ADR-001 曾写 CVDisplayLink；实现里 **从未使用 CVDisplayLink**。
- macOS 14 公开路径是 `NSScreen.displayLink(target:selector:)` → `CADisplayLink`，加到 `.common`。
- Phase 1A `phys-auto-02`：Aqua 下 frame 事件 0。当时是 `NSView.displayLink` **没有** `add(to:forMode:)` 的接线问题，T-step6 还误判成无头。
- Phase 1B §8：探针在本机 **可以** ~60Hz 回调（25 @ 0.01597s / 24 @ 0.01594s）。Phase 1A 零回调被标成探测定时器 stop 假象。证据只记录，**未标 PASS，帧源未改**。
- 今天 `--frame-driver displaylink|auto` 仍只观测；`handleTick` 明确「不喂帧」。CLI 开关 **不是** 帧源 A/B。

所以：「本机 DisplayLink 完全不能用」已经过时；「加 `--frame-driver displaylink` 就能对比交付规则性」是错的。真对比 = 新的 `PagingFrameDriving` 实现，从 DisplayLink tick 调 `advanceFrame`，默认仍 RunLoop。

### 3.2 值不值得做真驱动实验

| 预期 | 判断 |
|---|---|
| 消掉 20–25ms Timer-leeway 短尾 | 有希望（DisplayLink 不走 `Timer.tolerance`）。但这与把 Timer tolerance 收到 0/4ms **同类收益**，梯度扫描更便宜 |
| 消掉物理 ~10ms `exit→entry` | **不指望**。两者都趴在同一条主 RunLoop 上 |
| 视觉更跟 vsync（减少 compositor 采样相位抖动） | 合理假设，**未测**。手动插值分页对「写 visualOffset 的相位」可能比纯 callback 间隔更敏感 |
| CPU / 电池 | 动画期两者都是 60Hz 唤醒，差应很小；空闲期现有驱动本来 `stop()`。禁止写「0ms 或 DisplayLink 无能耗代价」。要测就在物理门加一次短采样（`powermetrics` 或 Activity Monitor 能量，正式门不要开 ST） |
| 风险 | 历史零回调/探测假象；必须有 fallback；不能破坏已过的 60Hz RunLoop 路径 |

**建议:** 值得做 **opt-in 真驱动测量臂**（Worker 新代码，默认不变），**不值得**在没有该数据时把生产默认切到 DisplayLink。优先序低于 tolerance 梯度 + 物理手感 A/B。

---

## 4. 测量方法：怎么继续隔离（只列还没做完、且不会污染结论的）

已经做过、不要重做当「新发现」的：8.333 vs 0 SELFDRIVE（Full+Lite）、callback-boundary ABBA、同时钟 runloop correlation、物理 tolerance=0 Full 捕获、System Trace（已污染 leave/re-enter）。

### 可直接派的测量（无默认改动）

**M1. tolerance 梯度 SELFDRIVE（优先，零新代码）**

```text
--frame-timer-tolerance-ms 0 | 2 | 4 | 8.333
```

- Release、`--neutral-content --disable-telemetry-bridge`，交错顺序（例如 `8.333, 0, 4, 2, 2, 4, 0, 8.333`）。
- 主轨：callback-profile only（少 observer）。可选一轮 Full 只为确认方向。
- 看：20–25ms 率是否随 tolerance 单调；p95 在 4ms 是否已接近 0ms；**每臂 commit/stale 数**（0ms 已有副作用，4ms 未知）。
- 目的：若 4ms 已把短尾打到接近 0ms，则将来调参候选是 4 不是 0（留下一点 leeway）。
- 仍是合成对照，不是手感 PASS。

**M2. 用户亲手物理 A/B（零新代码，T-1D 已列 option a）**

同一 Release 二进制、同一 60Hz 全屏 1470×923、低电量关：

1. 生产默认（不传 tolerance）；
2. `--frame-timer-tolerance-ms 0`；
3. 若 M1 显示 4ms ≈ 0ms，再加 `--frame-timer-tolerance-ms 4`。

协议沿用 `TIMER_TOLERANCE_MODE_AB_PLAN.md` §4.3：30 组手势、两臂各 ≥3 个完整有效 run、主观五项 + 翻页意图/跟手/settle/中断/误 commit。正式 run **不要**挂 System Trace。Profiler 两臂一致；若只为手感，可先关 profile 减污染，另开一轮带 `--frame-callback-profile` 收间隔。

**M3. 真实 Timer deadline（小 Worker，默认不变）**

在 opt-in callback profiler 里于 callback 入口记录 `timer.fireDate`（或 CF 等价）相对 `entry_ns` 的偏差。用来回答 §1 还缺的那一句：20–25ms 是不是「fire date 被推到 tolerance 末端」。`scheduled_ns` 继续标明 recorder-nominal，两套不要混。

**M4. 真 CADisplayLink 驱动臂（中 Worker，默认不变）**

新 `PagingFrameDriving`：tick → `advanceFrame`；失败回退 RunLoop（现有纪律）。CLI 另开明确开关（不要复用现在这个只观测的 `--frame-driver displaylink`，以免证据被读错）。SELFDRIVE 对照：RunLoop@0ms vs DisplayLink。记录 CADisplayLink.timestamp/targetTimestamp vs entry。这才能回答 §3。

### 暂缓 / 不要当下一刀

- 再开 System Trace 当正式 hitch 率：已证明它放大 `exit→entry`。
- 先上 GPU / WindowServer 仪器：当前 remainder 是进程内 RunLoop 形状，点名 GPU 是禁句。
- dispatch source `TIMER_STRICT`：可作更后的第三帧源，先做完 M1/M4。
- 120Hz 面板：`BLOCKED_BY_HARDWARE`。触控板采样率 ≠ 显示刷新率；本机面板 60Hz。
- 更多 RunLoop observer 细分 afterTimers/afterSources：对短尾收益小，对长尾有用但 observer 本身会加噪。

时钟纪律保持：`entry_ns` 单调时钟；禁止 `systemUptime` / Unix wall 与 `entry_ns` 相减；first tick 用 `arm_ns`，禁止 `scheduled_ns − interval`。

---

## 5. 参数建议（现在不要改默认）

生产保持 8.333ms，`PRODUCT_DEFAULT_UNCHANGED`。

| 候选 | 短尾 | 长尾 | 能耗（推断） | 行为副作用 | 何时才能考虑 |
|---|---|---|---|---|---|
| 保持 8.333 | 保留 20–25ms 合法窗 | 无帮助 | 动画期可 coalescing | 已知基线 | 默认 |
| 4ms | 理论上沿 20.67ms，有望切掉大部分 22–25ms | 无帮助 | 介于 0 与 8.333 | 未知，M1 要看 commit 数 | M1 显示 4≈0 的短尾 **且** 物理 A/B 手感不差 |
| 0ms | 已证短尾大降 | 无帮助；B2 仍有 72ms | 动画期无法 leeway；空闲期驱动已 stop，空闲差应为 0。仍禁止宣称无代价 | SELFDRIVE commit 17–20→29–30，必须物理确认不是乱翻页 | 物理 ABBA PASS 且误 commit 不增 |
| DisplayLink 默认 | 可能类似 0ms（绕开 Timer leeway）+ 可能更好的 vsync 相位 | 不解决 10ms leave | 动画期同 60Hz 唤醒 | 需 fallback；历史接线事故 | 先有 M4 数据，再单独 `decision_recorded` |

权衡一句话：8.333ms 是「半帧 leeway」，对 60Hz 手动插值动画过宽——它把「偶尔晚半帧」写成了 API 允许行为。收到 4ms 是比 0ms 更稳的产品候选，但 **证据还没到**。DisplayLink 应与 tolerance 分开评估，不能互相替代。

Chief 拥有的项（Main 不能单独改）：生产 Timer tolerance、帧源、PagingCore 参数。

---

## 6. 验证闭环：SELFDRIVE vs 物理门

SELFDRIVE **已经**证明：「交付节奏不规则」是客观事实，且 8.333ms 贡献 20–25ms 短尾。它 **不能** 证明手感，也覆盖不了 `eventTracking` 和物理 ~10ms `exit→entry`。

可重复物理门（与计划 §4.3 对齐，补几条本问题特有的）：

1. **硬件钉死**：同一台 60Hz、全屏 1470×923、插电、低电量关。120Hz 触控板只说明输入采样，不把帧目标改成 8.33ms。
2. **单一变量**：每轮只改 tolerance 或只改真帧源；内容（真实目录 vs neutral）分开报，不池化。
3. **手势脚本**：30 组，含慢拖、轻甩、反向中断、边界；方向平衡。checklist 打勾，不靠「随便滑一会儿」。
4. **顺序**：ABBA（A=8.333, B=0 或 4），消除疲劳/热机。
5. **双证据**：主观五项（跟手 / 中断 / settle / 边界 / 总体）+ 客观 callback 间隔（p95/p99/>20/>25、mode 直方图、`exit→entry` 8–12ms 次数、commit vs bounce vs interrupt）。
6. **完整落盘**：`run.end` + `teardown.complete`；异常 run 保留不删。
7. **污染控制**：正式手感 run 不开 System Trace、尽量少 observer；诊断 run 另开。
8. **PASS 规则**：不能只看「p95 好看」。必须同时：短尾下降、误 commit 不增、主观跟手不降。任一失败 → 默认不改。

无头 PerfBenchmark 的 miss16=0 继续只当「加工开销」门，不当交付节奏门。

---

## 7. 建议 Main 怎么走

按项目流程，**测量类直接派探针；参数类等用户决策**。

### 现在可派（无需 `decision_recorded`）

1. **T-framelag-tolerance-gradient**（investigation）：M1 梯度 SELFDRIVE。产出：每臂 p95/p99/>20/>25 + commit/stale。不改默认。
2. 请用户做 **M2 亲手 A/B**（option a）。这是人手，不是 Worker 改代码。
3. （可选，第二波 Worker）M3 fireDate 探针、M4 真 DisplayLink 驱动臂——都是 opt-in，生产路径不变，须独立 Reviewer。

### 必须等用户 `decision_recorded` 的

- 生产 `Timer.tolerance` 从 8.333 改为 4 或 0；
- 生产帧源改为 DisplayLink。

在 M1+M2 出来之前，**不建议**把「改默认」提上决策。若用户现在就想改，Main 应 BLOCKED 回去问，推荐项仍是「先梯度 + 物理 A/B，默认不动」。

### 分析自己的边界

本文是对已有证据的机制阅读与实验排序，不是新捕获。没有新 JSONL、没有改代码、没有声称修好。长尾组件名（scheduler / WindowServer / GPU）保持 `UNRESOLVED`。
