# 帧交付节奏不规则 — 修复计划

- 日期: 2026-08-30
- 项目: PagingPrototype
- 依据: `Docs/FRAME_LAG_PROBLEM_BRIEF.md`、`Docs/FRAME_LAG_ANALYSIS.md`、既有 hitch / tolerance / callback-boundary / correlation 证据
- 性质: **分轨、有门禁的修复计划**。不是「已经修好」，也不是静默改默认。
- 与 Phase 1D 的关系: `Workflow/PLAN.md` 把 hitch-fix / vsync 帧源切换列为 Phase 1D **非目标**。本文是**独立工作流**，不修订 Phase 1D 方案。派工前须用户确认启用本工作流；生产 Timer tolerance / 帧源仍是 **Chief 拥有项**。

```text
CAUSALITY_UNRESOLVED
PARTIAL_CONTRIBUTOR_SUPPORTED
SUPPORTED_PARTIAL_CONTRIBUTOR_TIMER_TOLERANCE_FOR_20_TO_25MS
PHYSICAL_20_TO_25MS_RUNLOOP_EXIT_ENTRY_APPROX_10MS
PRODUCT_DEFAULT_UNCHANGED
REQUIRE_PHYSICAL_AB_BEFORE_TIMER_TOLERANCE_DEFAULT_CHANGE
```

全程禁止: `ROOT_CAUSE_FOUND` / `ALL_HITCHES_FIXED` / `FIX_VALIDATED` / `SCHEDULER_CONFIRMED` / `WINDOWSERVER_CONFIRMED` / `GPU_CONFIRMED`。短尾改善后最多写 `SHORT_TAIL_MITIGATED_BY_TOLERANCE`，长尾仍 `UNRESOLVED`。

---

## 0. 「修复」在本计划里指什么

用户现象是全屏 60Hz 触控板翻页「轻微卡顿 / 帧节奏不跟手」。客观对应是 **Timer 回调交付间隔不规则**，不是 UI/渲染太重（~0.7ms/帧）。

问题拆成两条，修复也拆成两条。**不能用一个改动宣称全好。**

| 轨 | 现象 | 已有证据 | 本计划的「修好」定义 | 做不到的 |
|---|---|---|---|---|
| **A 短尾** | 20–25ms 间隔（生产默认很常见：本简报 >20ms ×47） | 8.333ms Timer tolerance 是可重复部分贡献者 | 生产默认下 callback 间隔 p95 接近 16.7–18ms，>20ms 率相对 8.333ms 基线下降 ≥50%；物理手感跟手项不降、误 commit 不增 | 不解释 >25ms |
| **B 长尾** | >25ms，偶发 37–72ms | 不是 tolerance。物理轨每个 >25ms remainder 含 ~10ms `exit→entry` | 先定位形状与可干预点；有单变量证据后再谈改动 | 本计划 **不承诺** 本轮消掉长尾 |
| **C 帧源（可选）** | Timer 非 vsync | `--frame-driver displaylink` 只观测、不驱动 | 真 CADisplayLink 驱动臂的测量对照 | 不作为短尾的第一刀，也不当作长尾解药 |

用户能立刻感到的，几乎全在 **轨 A**。轨 B 是稀有尖峰；轨 C 是架构备选。计划按这个 ROI 排序。

---

## 1. 非目标 / 冻结

- 不改 `Sources/PagingCore/` 状态机、阈值、settle 弹簧（除非将来用户另开调参轮，与本计划无关）。
- 不改 `Package.swift`、`AppLaunchController.swift` 默认。
- 不读 LaunchBetter / Buho 逆向材料。
- 不把无头 PerfBenchmark `miss16=0` 当交付节奏证据。
- 不把 SELFDRIVE 当物理手感 PASS。
- 不把 System Trace hitch **率** 当正式门（已证明它放大 `exit→entry`）。
- 不在正式物理门开 ST / Time Profiler。
- 不点名 scheduler / WindowServer / GPU 为根因。
- 不启用全局 NSEvent monitor、Accessibility、同步 I/O。
- 隐私: JSONL 不含 app 名 / bundle ID / 路径 / URL / 搜索词 / 图标；mode 只允许 `default|eventTracking|modalPanel|other|none`。
- 120Hz 面板: `BLOCKED_BY_HARDWARE`。触控板高采样率 ≠ 显示 120Hz。
- git commit / push / tag: 各任务包自行写明；默认不做。

---

## 2. 总策略（一句话）

> 短尾用 **缩小 Timer.tolerance** 去合法窗口（先测 0/2/4/8.333，物理手感过了再改默认）。长尾另开调查，不绑在同一次默认变更上。DisplayLink 真驱动只作后续对照，不复用现在的观测 CLI。

机制（`INFERRED` + 短尾效应 `SUPPORTED_PARTIAL_CONTRIBUTOR`）:

```text
repeating Timer interval = 16.667ms
tolerance（生产）     = 8.333ms   // 只允许晚
下一拍仍按原始节拍

observed_gap ∈ [8.334ms, 25.000ms]
20–25ms = 该窗口上半段
```

把 tolerance 收到 4ms → 理论上沿 20.667ms；收到 0ms → 窗口塌成 ~16.667ms 加调度噪声。这是轨 A 的全部杠杆。它 **动不了** 物理 ~10ms RunLoop leave。

---

## 3. 阶段总图（语义依赖，不是并发计划）

```text
Phase 0  用户确认启用本工作流
    │
    ├─► Phase 1  测量（无默认改动）
    │     T-A1  tolerance 梯度 SELFDRIVE 0/2/4/8.333     [现有 CLI]
    │     T-A2  用户亲手物理 A/B（默认 vs 0，可选 4）      [人手]
    │     T-A3  （可选）Timer.fireDate 探针                 [小 Worker]
    │
    ├─► Phase 2  用户决策（Chief 拥有）
    │     选项: 保持 8.333 / 改为 4 / 改为 0 / 暂缓
    │     必须 `decision_recorded`
    │
    ├─► Phase 3  实现默认值（仅当 Phase 2 选了 4 或 0）
    │     T-A4  Worker 改默认 + 测试 + 文档
    │     T-A4-r Reviewer PASS
    │     重建 Release，token → SHORT_TAIL_MITIGATED… 仍非 ALL_HITCHES_FIXED
    │
    ├─► Phase 4  物理验收（默认已改之后）
    │     T-A5  真实触控板 ABBA（旧默认二进制 vs 新默认）
    │     失败 → 回滚默认，PRODUCT_DEFAULT_UNCHANGED 恢复
    │
    └─► Phase 5  长尾 + 可选帧源（不阻塞轨 A）
          T-B1  长尾形状备忘 / 干预点清单（只读）
          T-B2  （可选）start() 立即首 tick 实验
          T-C1  （可选）真 CADisplayLink 驱动臂
```

Main 可在 Phase 1 内把 T-A1 与「请用户做 T-A2」并行；T-A3 / T-B / T-C 不得挡住 T-A1。T-A4 硬依赖 Phase 2 的 `decision_recorded`。

---

## 4. Phase 0 — 启用门

问用户三件事，书面记下再派工：

1. 是否启用本独立工作流（不并入 Phase 1D）？
2. Phase 1 是否立刻派 T-A1（梯度 SELFDRIVE）？
3. 用户是否愿意按 §6 协议亲手做 T-A2（约 6 次 × 30 手势，同一台 60Hz 全屏机）？

未确认前：不改代码、不改默认、不创建「已修复」叙事。

---

## 5. Phase 1 / T-A1 — tolerance 梯度 SELFDRIVE

**类型:** investigation-only，零新代码。  
**决策:** 不需要 `decision_recorded`。  
**目的:** 在 0/2/4/8.333 上画出短尾是否单调；看 4ms 是否已经够用；量每臂 commit/stale（0ms 已有 17–20 → 29–30 的副作用）。

### 5.1 二进制与命令

使用当前 Release（或重建一次，记下 SHA-256）。每臂同一二进制。

```bash
.build/release/PagingPrototypeApp \
  --neutral-content \
  --disable-telemetry-bridge \
  --frame-callback-profile \
  --frame-timer-tolerance-ms <ARM>
```

环境: `PAGING_PROTOTYPE_GUI_SELFDRIVE=1`，40 次 synthetic fling，正常 teardown。  
主轨 **不要** `--frame-profile` / `--runloop-profile`（减少 observer）。可选加一轮 8.333 vs 0 的 Full 只为方向复核，不当主统计。

### 5.2 交错顺序（固定，禁止事后挑 run）

```text
G1  8.333
G2  0
G3  4
G4  2
G5  2
G6  4
G7  0
G8  8.333
```

每臂 2 个完整有效 run。`run.end=1` 且 `teardown.complete=1` 才算有效。失败 run 保留，不删。

### 5.3 指标（每 run + 每臂池化，池化只描述）

| 字段 | 来源 |
|---|---|
| raw interval 数（first tick 排除） | callback JSONL |
| p50 / p95 / p99 / max | 同上 |
| >20 / 20–25 / >25 / >33.3 / >50 次数与 /1000 | 同上 |
| first-tick 数、arm→first-entry p99/max | 同上，独立表 |
| gesture.began / ended | telemetry 若关 bridge 则用 SELFDRIVE 退出码 + 现有 stdout；优先能拿到的 commit/stale 计数 |
| committed / stale / interrupted | 若无 telemetry，从 SELFDRIVE 日志或补开一轮 **仅** `--paging-telemetry` 无 profile 的轻量轨 |

commit 计数是 **硬指标**。短尾再好看，commit 暴增也不得推荐该臂为生产默认。

### 5.4 判读规则

```text
短尾单调:     8.333 的 20–25ms 率 > 4 > 2 > 0（允许 2 与 0 接近）
4ms 足够:     4ms 的 p95 ≤ 18.5ms 且 20–25ms 率 ≤ 8.333ms 臂的 40%
0ms 副作用:   0ms commit 数相对 8.333 变化 > 20% → 写入风险，推荐倾向 4ms
>25ms:        任何臂之间的差异不得写成「0ms 改善/恶化长尾」（样本太稀）
```

产出: `Docs/TIMER_TOLERANCE_GRADIENT_RESULTS.md` + SHA-256 清单。  
**禁止:** 改默认；写 `ROOT_CAUSE_FOUND`；把 SELFDRIVE 当手感 PASS。

### 5.5 Reviewer 焦点（若走 Worker 采集）

- 顺序是否按表执行、有效 run 是否完整。
- first tick 是否排除在 raw interval 外。
- 是否把 >25ms 写成 tolerance 效应。
- 隐私扫描 JSONL。

---

## 6. Phase 1 / T-A2 — 用户亲手物理 A/B

**类型:** 人手，不改代码。  
**决策:** 不需要 `decision_recorded`（这是对照，不是改默认）。  
**目的:** 短尾改善是否变成「跟手」；0/4ms 会不会多翻页、少跟手、settle 发硬。

### 6.1 环境钉死

| 项 | 值 |
|---|---|
| 机器 | 同一台，主屏 60Hz |
| 窗口 | 全屏 1470×923 |
| 电源 | 插电，低电量关 |
| 内容 | 真实目录（手感权威）；可选另做一轮 neutral 只为间隔 |
| 二进制 | 与 T-A1 同一 SHA |
| 仪器 | **正式 run 不开 System Trace** |

### 6.2 臂

- **A** 生产默认（不传 `--frame-timer-tolerance-ms`）
- **B** `--frame-timer-tolerance-ms 0`
- **C** `--frame-timer-tolerance-ms 4` — 仅当 T-A1 显示「4ms 足够」或用户愿意多做一轮

顺序: `A1 B1 B2 A2 A3 B3`（有 C 则插入 `… C1 C2`，仍交错，不要 CCC 连打）。

### 6.3 手势协议（每 run 30 组，checklist 打勾）

沿用 `Docs/TIMER_TOLERANCE_MODE_AB_PLAN.md` §4.3，补本问题特有项：

1. 慢拖不足阈值 → 应回弹（10）
2. 慢拖过阈值 → 应翻页（6）
3. 轻甩（速度过门）→ 应翻页（6）
4. 翻页中反向中断（4）
5. 边界 overscroll（4）

方向大致一半前进一半回退。不要「随便滑一会儿」充当 run。

### 6.4 主观五项（每 run 结束立刻打分，1–4，可 0.5）

跟手性 / 中断连续性 / settle 自然度 / 边界反馈 / 总体丝滑。

另记: 误 commit（不该翻却翻）、误回弹（该翻却回）、是否感到「一顿一顿」。

### 6.5 客观（若该 run 开了 `--frame-callback-profile`）

与 T-A1 同一套间隔表。建议:

- 每臂至少 1 个手感-only run（无 profile，减污染）
- 每臂至少 1 个诊断 run（`--frame-callback-profile`，不要 runloop observer）

### 6.6 PASS 倾向（给 Phase 2 用，不是自动改默认）

候选臂（0 或 4）同时满足才进入「可提交用户决策」：

1. 主观跟手 ≥ 默认臂，总体不降超过 0.5；
2. 误 commit 不增加；
3. 诊断 run 的 >20ms 率相对默认下降（方向与 T-A1 一致）；
4. 用户口头可接受能耗（无数字也要记一句「未测 / 可接受 / 不可接受」）。

任一失败 → 该臂不得推荐为生产默认。

---

## 7. Phase 1 / T-A3 — 可选 fireDate 探针

**类型:** 小 Worker，默认不变。  
**目的:** 把 §2 的 leeway 推断从 recorder-nominal 升到「Timer 自己的 fire date」。  
**不阻塞** T-A1 / T-A2 / Phase 2。若工期紧可整段跳过。

### 7.1 改动范围

- `Sources/PagingUI/FrameCallbackProfileRecorder.swift`：新增可选字段 `timer_fire_date_ns` / `timer_lateness_ns`（相对真实 fireDate，**另外**保留现有 `scheduled_ns`）。
- `Sources/PagingUI/PagingFrameDriver.swift`：仅当 profiler active，在 callback 入口读 `timer.fireDate`。
- 测试: schema、disabled 零文件、两套 deadline 不混用。
- **禁止**改生产 `interval`/`tolerance` 默认。

### 7.2 验收

- 全量测试绿；Release 构建绿。
- 一轮 SELFDRIVE 8.333 vs 0：8.333 臂的 `timer_lateness` 上分位明显高于 0 臂，且与 20–25ms raw interval 共现。
- 文档标明: `scheduled_ns` = recorder nominal；`timer_fire_date_ns` = Foundation Timer。禁止相减跨字段拼因果。

---

## 8. Phase 2 — 用户决策（硬门）

Main 把 T-A1 表 + T-A2 主观五项摊开，**只问这一题**（推荐项按数据填，不得在数据前写死 0ms）:

> 生产默认 `Timer.tolerance` 选哪一个？
>
> 1. 保持 8.333ms（短尾保留，零行为风险）
> 2. 改为 4ms（推荐条件: T-A1「4ms 足够」且 T-A2 手感不差、commit 稳定）
> 3. 改为 0ms（推荐条件: 短尾最好 **且** T-A1 commit 副作用可解释为「跟手变稳」而非乱翻页，T-A2 误 commit 不增）
> 4. 暂缓，继续只做轨 B/C

必须 `Workflow/events.jsonl` 的 `decision_recorded`。没有它，T-A4 **不得开工**。

Chief 拥有: 生产 Timer tolerance、帧源、PagingCore 参数。Main 不得代选。

决策记录至少含: 选中值、依据（T-A1 臂、T-A2 五项）、明确「长尾仍未修」。

---

## 9. Phase 3 / T-A4 — 改生产默认（仅决策之后）

**类型:** 用户决策调参轮。流程: `decision_recorded` → Worker → 独立 Reviewer PASS → 重建。

### 9.1 唯一允许的产品行为变化

把缺省 `Timer.tolerance` 从 `1.0/120.0`（8.333ms）改为决策值（4ms = `0.004` 或 `4.0/1000`；0ms = `0`）。CLI `--frame-timer-tolerance-ms` 仍可用，合法范围仍 0–16.667。

### 9.2 预期写入范围

| 文件 | 做什么 |
|---|---|
| `Sources/PagingUI/PagingFrameDriver.swift` | `init` 默认 `tolerance:` |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | `?? (1.0 / 120.0)` 改为新默认 |
| `Tests/PagingUITests/RunLoopFrameDriverTests.swift` | 若有断言默认 1/120，改为新值；CLI 边界测试不动 |
| `Docs/PARAMETER_RATIONALE.md` | **新增**平台参数行（现表没有 Timer tolerance）：默认值、范围、来源 `PRODUCT_DECISION`、理由、验证状态 `TUNING_REQUIRED` 直到 T-A5 PASS |
| `MEMORY.md` | 默认值事实；诊断 token 见下 |
| `Docs/IMPLEMENTATION_LOG.md` | 一行变更记录 |

**禁止树:** `Sources/PagingCore/`（除用户另开的无关调参）、`Package.swift`、`AppLaunchController.swift`、DisplayLink 观测器改成驱动、telemetry schema。

### 9.3 诊断 token（改默认之后）

```text
CAUSALITY_UNRESOLVED                  # 长尾仍在
PARTIAL_CONTRIBUTOR_SUPPORTED
SHORT_TAIL_MITIGATED_BY_TOLERANCE     # 仅当 T-A5 也过
PRODUCT_TIMER_TOLERANCE_<N>MS         # 例如 PRODUCT_TIMER_TOLERANCE_4MS
REQUIRE_PHYSICAL_AB_BEFORE_…          # T-A5 完成前仍保留
```

**仍然禁止** `ALL_HITCHES_FIXED` / `FIX_VALIDATED` / `ROOT_CAUSE_FOUND`。

### 9.4 Worker 验收

- `swift test` 全绿（executed>0）。
- `swift build -c debug` / `-c release` exit 0。
- 禁止树 hash/mtime 未改。
- 不传 CLI 时 stdout/代码路径确为新默认。
- 无 git commit。

### 9.5 Reviewer 焦点

- 是否只改了默认 tolerance，有没有顺手改帧源/Core。
- 文档与代码一致。
- 有没有把长尾写成已修。
- 隐私、无全局 monitor。

---

## 10. Phase 4 / T-A5 — 改默认后的物理验收

**对照:** 旧默认 Release（改前 SHA）vs 新默认 Release（T-A4 后 SHA）。同一台 60Hz 全屏，协议同 T-A2。

**PASS（同时）:**

1. 用户五项：跟手不降，总体 ≥ 旧默认；
2. 误 commit 不增；
3. 新默认诊断 run：p95 ≤ 18.5ms **或** >20ms 率相对旧默认下降 ≥50%（与 T-A1 方向一致）；
4. >25ms 不作为 PASS 条件（仍可能存在）；报告里如实列出。

**FAIL → 回滚:** Worker 把默认改回 8.333ms，走同一 Reviewer 门。token 恢复 `PRODUCT_DEFAULT_UNCHANGED`。不保留「修了一半」的默认。

T-A5 PASS 后才允许把 `PARAMETER_RATIONALE` 该行写成物理门 PASS，并去掉 `REQUIRE_PHYSICAL_AB_BEFORE_TIMER_TOLERANCE_DEFAULT_CHANGE`。

---

## 11. 轨 B — 长尾（不阻塞轨 A）

### 11.1 现状（不要再当新发现重测一遍）

- 加工开销不是因。
- 0ms 后 >25ms 仍在。
- 物理: 体 ~0.2ms + ~14ms wait + **~10ms `exit→entry`**。
- SELFDRIVE 另有 6.8ms CPU、`beforeSources→exit` 等形状 — **禁止与物理 25ms 合并**。
- System Trace 污染 leave/re-enter，正式率不用。

### 11.2 T-B1 只读收口（可选，便宜）

把「可干预点」写成清单，每条带证据等级，不写新探针除非必要：

| 假设 | 等级 | 可能干预 | 先做的测量 |
|---|---|---|---|
| 手势期间嵌套 `CFRunLoopRunInMode` / tracking spin | `INFERRED` | 避免动画中进 modal；确认 Timer 已在 `.common`（已是） | 物理 run 的 mode 直方图是否出现 `eventTracking` |
| Timer `start/stop` 重建导致 first-tick 晚 25–35ms | `MEASURED`（ABBA 有过；correlation 捕获未再现） | `start()` 立即 tick，或 `fireDate = now` | 物理间隔是否落在 generation 首帧 |
| AppKit 延迟 layout/display 在 callback 外 | `UNRESOLVED` | 缩小失效范围 | 需 Instruments **GUI** 看主线程，不把 ST 率当证据 |
| 调度抢占 / WindowServer / GPU | `UNRESOLVED` | 无产品改动 | 本阶段不做 |

T-B1 产出: `Docs/FRAME_LAG_LONG_TAIL_HYPOTHESES.md`。禁止升级 token。

### 11.3 T-B2 可选：`start()` 立即首 tick

**仅当** T-B1 或现有 first-tick 表显示首帧延迟与可感卡顿时间重叠。

行为: `RunLoopFrameDriver.start()` 在 `add` 之后立刻 `handleFrame` 一次，或把首次 `fireDate` 设为 now。默认 tolerance **不动**（除非轨 A 已改完）。

验收: SELFDRIVE 的 first-tick arm→entry 从历史 25–35ms 量级掉到 ≪ 一帧；**raw interval 分布不得恶化**；手感另做一轮。这修的是 **first-tick 分布**，不是 10ms `exit→entry`。文档必须写清。

---

## 12. 轨 C — 真 DisplayLink 驱动（可选，靠后）

### 12.1 为什么现在的 CLI 不够

`DisplayLinkFrameDriver` 内部仍是 `RunLoopFrameDriver`；`handleTick`「不喂帧」。`--frame-driver displaylink` **不是**帧源 A/B。Phase 1B 探针在本机可以 ~60Hz 回调，但那只是观测。

### 12.2 T-C1 若做，必须新缝

- 新类型，例如 `DrivingDisplayLinkFrameDriver: PagingFrameDriving`，tick → `owner.advanceFrame`。
- 新 CLI，例如 `--frame-driver-driving displaylink`（名称避免与观测开关混淆）。缺省仍 RunLoop。
- 零回调 / `NSScreen.main == nil` → 回退 RunLoop，stdout 记 reason，**不冻结窗口**。
- DisplayLink `add(to:forMode:.common)`。
- 默认 tolerance / 默认帧源 **不变**，直到另一次 `decision_recorded`。

对照臂（SELFDRIVE）:

```text
R0  RunLoop tolerance=0
D   Driving DisplayLink
```

看间隔规则性 **和** vsync 相位（`CADisplayLink.timestamp` vs callback entry）。  
**预期:** 短尾可能类似 R0（绕开 Timer leeway）；物理 10ms `exit→entry` **不指望**消失。

生产切 DisplayLink 是另一次 Phase 2/3/4，本计划不预授权。

---

## 13. 任务包草图（Main 启用后落 `Workflow/tasks/`）

| ID | 类型 | 依赖 | 写入范围 | 用户决策 |
|---|---|---|---|---|
| T-A1 | 探针 | Phase 0 | 文档 + `/tmp` JSONL；**无 Sources** | 否 |
| T-A2 | 人手协议 | Phase 0 | `Docs/` 结果表 | 否（人手） |
| T-A3 | 小 Worker | 无硬依赖 | PagingUI recorder + tests | 否 |
| T-A4 | 调参 Worker | Phase 2 `decision_recorded` | 默认 tolerance + 文档/测试 | **是** |
| T-A4-r | Reviewer | T-A4 | `Workflow/reviews/` | — |
| T-A5 | 物理验收 | T-A4 PASS + 重建 | 文档 | 人手 |
| T-B1 | 只读 | 无 | 一篇 Docs | 否 |
| T-B2 | Worker | T-B1 或 first-tick 证据 | `PagingFrameDriver.start` | 否（默认帧源/tolerance 仍不动） |
| T-C1 | Worker | 不挡轨 A | 新驱动 + 新 CLI + tests | 否（默认仍 RunLoop） |

并发: T-A1 与「约用户做 T-A2」可并行。T-A3 / T-B1 / T-C1 写入文件若重叠 `PagingFrameDriver.swift` 则 **禁止** 与 T-A4 同时改同一 worktree。`max_worker_concurrency=3` 是上限不是承诺。

---

## 14. 回滚与失败

| 失败点 | 动作 |
|---|---|
| T-A1 短尾不单调 / 与历史 8.333 vs 0 反向 | 停轨 A 改默认；回退到「仅调查」；唤醒 Chief |
| T-A2 0/4ms 误 commit 增或跟手下降 | 不提交该臂；默认保持 8.333 |
| T-A4 Reviewer FAIL | 常规 repair；不放宽「只改默认」范围 |
| T-A5 物理 FAIL | **回滚默认到 8.333**，再 Reviewer |
| T-C1 DisplayLink 零回调 | 记 fallback；默认不切；不标 PASS |

回滚必须落到代码默认值，不能只靠「以后别用新二进制」。

---

## 15. 风险

1. **SELFDRIVE commit 副作用** 在物理上可能是真跟手（节奏稳 → 更容易过阈值），也可能是脚本耦合。T-A2 的误 commit 计数是唯一仲裁。
2. **4ms 不够短尾、0ms 手感有副作用** → 无产品候选，轨 A 停在测量。
3. **改 tolerance 被误写成「卡顿已修」** → 用户仍会碰到 >25ms。所有对外句子保留长尾未修。
4. **DisplayLink 观测开关被当成已切帧源** → T-C1 必须新 CLI 名。
5. **System Trace / 多 observer** 制造假长尾 → 正式门禁用。
6. **first-tick 立即 fire** 可能改变 settle 的第一帧 dt → 必须 clamp，且单独 A/B。

---

## 16. Main / Chief 边界

**Main 可直接做:** 派 T-A1；给用户 T-A2 脚本；派 T-A3 / T-B1（默认不变）；T-A4 仅在 `decision_recorded` 之后按选中值实现；Reviewer 调度；T-A5 组织；回滚默认（属于已接受计划内的失败处理）。

**必须 Chief 或用户:** 生产 tolerance 选哪一档；生产帧源切 DisplayLink；把 hitch-fix 并回 Phase 1D；放宽冻结树；把 token 改成 `ROOT_CAUSE_FOUND` / `ALL_HITCHES_FIXED`；改 PagingCore 参数。

---

## 17. 建议的第一刀（用户点头后）

1. 派 **T-A1** 梯度 SELFDRIVE（现有 CLI，当天可出表）。
2. 同时把 **T-A2** 手势清单交给用户，用同一 Release 做默认 vs 0。
3. 两份结果回来再问 Phase 2 那一道决策题。推荐项按数据填：先验是「4ms 比 0ms 更像产品默认」，但 **4ms 还没有梯度证据，不得提前锁定**。
4. T-A3 / T-B / T-C 全部可后置。

当前代码、当前默认、当前 token：**一概不动**，直到 Phase 2 书面决策。
