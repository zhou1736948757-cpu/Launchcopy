# PARAMETER_RATIONALE.md — 参数集中配置与理由

- **日期**：2026-08-28（T-step1 创建；T-step6 后回填验证结果；T-reviewer 后补列）
- **原则**（Prompt §9）：所有交互参数集中在明确配置结构（`PagingParameters`），禁止散落 magic number；每个参数记录默认值/范围/来源类别/理由/验证结果/修改日期。
- **来源类别**：仅限 `PRODUCT_DECISION` / `PLATFORM_REQUIREMENT` / `ACCESSIBILITY_REQUIREMENT` / `INDEPENDENT_EXPERIMENT` / `PUBLIC_DOCUMENTATION`。禁用 `REVERSE_ENGINEERING_COPY` / `OLD_SOURCE_TRANSLATION` / `UNKNOWN_ORIGIN`。
- **验证状态语义**：`TUNING_REQUIRED` = 物理调参未发生（自动化 baseline ≠ 参数验证）；T-step6 已自动验证的指标明确标注；物理门（真实触控板）属于 T-step8，未执行前不标通过。

## 1. 交互参数

| 参数 | 默认值 | 合法范围 | 来源类别 | 选择理由 | 验证结果 | 修改日期 |
|---|---|---:|---:|---|---|---|---|
| `inputSensitivity` | 1.0（1:1） | 0.5–2.0 | PRODUCT_DECISION | 触控板位移→页面位移映射比例；1:1 自然跟随，过高灵敏/过低沉重 | TUNING_REQUIRED（自动化 baseline 通过；物理调参待 T-step8） | 2026-08-28 |
| `boundaryResistance` | 0.35 | 0.1–0.6 | PRODUCT_DECISION | 边界外位移阻尼系数；低=硬边界，高=明显 overscroll | TUNING_REQUIRED（同上） | 2026-08-28 |
| `displacementThreshold` | 0.42 | 0.25–0.75 | PRODUCT_DECISION | 释放时位移超过 pageWidth×threshold 翻页，否则回弹；物理门调参 0.5→0.48→0.46→0.45→0.43→**0.42**（全屏基准第 15 轮，用户决策"前进阈值改成0.42"） | **物理门 PASS**（真实内容 4/4/4/4/3.6；0.42/0.35 用户确认"挺好的"；全屏 1470pt 基准） | 2026-08-29 |
| `velocityContribution` | 0.3 | 0.0–0.5 | PRODUCT_DECISION | 速度对翻页决策权重；0=纯位移，0.5=速度上限加权 | TUNING_REQUIRED（同上） | 2026-08-28 |
| `velocityThreshold` | 800 px/s | 200–2000 | INDEPENDENT_EXPERIMENT | 超此速度强制翻页；需触控板实测标定 | TUNING_REQUIRED（同上） | 2026-08-28 |
| `maximumOverscroll` | 0.25（1/4 页） | 0.0–0.5 | PRODUCT_DECISION | overscroll 最大距离（页宽比例），防视觉断裂 | TUNING_REQUIRED（同上） | 2026-08-28 |
| `settleDuration` | 250 ms | 150–400 ms | PRODUCT_DECISION | settle 动画时长；过短生硬，过长响应感差 | TUNING_REQUIRED（同上） | 2026-08-28 |
| `settleSpringDamping` | 0.85 | 0.7–0.95 | PRODUCT_DECISION | spring 阻尼比；0.85 近临界 | TUNING_REQUIRED（同上） | 2026-08-28 |
| `momentumDecay` | 0.55 | 0.5–0.99 | INDEPENDENT_EXPERIMENT | momentum 每帧速度衰减系数；物理门调参 0.95→0.85→**0.55**（第 2 轮用户决策；N=1 下 glide 段极短，保持一致） | **物理门 PASS**（同上） | 2026-08-28 |
| `momentumGlideFrames` | 1 | 0–10（nil=跟完整系统流） | PRODUCT_DECISION | 系统惯性事件流截断窗口（≤2N 事件后决策）；物理门调参 nil→10→5→3→**1**（第 11 轮用户决策"惯性滑好久才停"；1=松手后最多跟 2 个惯性事件→立即 settle） | **物理门 PASS**（同上） | 2026-08-28 |
| `momentumMaxOvershoot` | 0.20（1/5 页） | 0.05–1.0 | PRODUCT_DECISION | momentum 跟随期过冲上限（目标页±overshoot 软阻尼线）；物理门调参 0.35→**0.20**（第 6 轮用户决策"最多冲到第二页加 1/5 页"）；软阻尼递推（0.2×delta，无静止帧，第 7 轮） | **物理门 PASS**（同上） | 2026-08-28 |
| `retreatDisplacementFactor` | 35/42（≈0.8333） | 0.7–1.0 | PRODUCT_DECISION | 回退方向位移阈值系数（补偿生理不对称：往回滑行程天然短）；物理门调参 0.9→0.875→20/23→38/45→36/43→**35/42**（第 9/12/13/14/15 轮用户决策；回退 = 0.42×35/42 = 0.35 精确） | **物理门 PASS**（同上） | 2026-08-29 |
| `livePageRadius` | 1（当前页±1） | 0–2 | PRODUCT_DECISION | 常驻 live view 半径；上界策略核心 | **T-step6 自动验证 PASS**：live≤7/pool≤7/合计≤14（全预设） | 2026-08-28 |
| `prewarmDistance` | 1.5 页 | 0.5–3.0 | PRODUCT_DECISION | 距目标 prewarmDistance 预热相邻页 view，防 hitch | **T-step6 自动验证 PASS**：冷创建≤3 后 100% 复用 | 2026-08-28 |

## 2. 无障碍参数

| 参数 | 默认值 | 合法范围 | 来源类别 | 选择理由 | 验证结果 | 修改日期 |
|---|---|---:|---:|---|---|---|---|
| `respectSystemReduceMotion` | true | — | ACCESSIBILITY_REQUIREMENT | 必须响应系统 Reduce Motion（§3.J） | **实现 + RM 三态接线测试 PASS**；视觉验证待 T-step8 | 2026-08-28 |
| `settleDurationReduceMotion` | 0 ms | 0–50 ms | ACCESSIBILITY_REQUIREMENT | RM 下 settle 时长；状态机逻辑不变（ADR-001 D8） | 同上 | 2026-08-28 |
| `reduceMotionOverscroll` | 0.0 | 0.0–0.1 | ACCESSIBILITY_REQUIREMENT | RM 下最大 overscroll；0=无回弹 | 同上 | 2026-08-28 |
| `reduceMotionChangeHandling` | dynamic | — | PLATFORM_REQUIREMENT | 运行时响应 RM 变化通知，非启动时读一次 | 同上 | 2026-08-28 |

## 3. 平台参数

| 参数 | 默认值 | 合法范围 | 来源类别 | 选择理由 | 验证结果 | 修改日期 |
|---|---|---:|---:|---|---|---|---|
| `naturalScrollDirection` | system | system/natural | PLATFORM_REQUIREMENT | 遵循系统自然滚动方向，不硬编码 | 实现 + mapper 测试 PASS（方向约定记录于 T-worker-d 结果） | 2026-08-28 |
| `gesturePhaseHandling` | full | full/fallback | PLATFORM_REQUIREMENT | 完整 phase 序列 + 异常序列防御（ADR-001 D5） | 实现 + 防御序列测试 PASS | 2026-08-28 |
| `displayLinkStopOnTeardown` | true | true/false | PLATFORM_REQUIREMENT | teardown 必须停帧回调（ADR-001 D7） | 实现 + teardown 零回调测试 PASS | 2026-08-28 |
| `animationRemovalOnInterrupt` | true | true/false | PLATFORM_REQUIREMENT | 中断必须停旧动画（ADR-001 D4） | 实现 + 中断接管测试 PASS | 2026-08-28 |
| `timerTolerance` | 0 ms | 0–16.667 ms | PRODUCT_DECISION | 生产默认 Timer.tolerance 由 4ms 改为 0ms（决策修订 2026-08-30，T-A4-0ms）；合法范围 0–16.667ms 与 CLI `--frame-timer-tolerance-ms` 一致 | **物理门 PASS**（T-A5 用户定案 2026-08-30：T-A2 跟手 4.00 vs 3.87、误 commit 0 双臂；T-A1 p95 17.57、>20ms 率降 67%；短尾改善 `SHORT_TAIL_MITIGATED_BY_TOLERANCE`；长尾 >25ms 仍 CAUSALITY_UNRESOLVED） | 2026-08-30 |

## 4. 性能目标参数（§8.5 初始目标，非平台保证）

| 参数 | 默认值 | 合法范围 | 来源类别 | 选择理由 | 验证结果 | 修改日期 |
|---|---|---:|---:|---|---|---|---|
| `frameMissTarget60Hz` | 1% | 0–5% | PRODUCT_DECISION | 60Hz frame miss 目标（§8.5 建议 ≤1%） | **T-step6 自动探针 PASS**：miss16=0/帧（0%）；物理门待 T-step8 | 2026-08-28 |
| `frameMissTarget120Hz` | 2% | 0–5% | PRODUCT_DECISION | 120Hz frame miss 目标（先证明刷新率） | NOT_RUN（无 120Hz 证据；最终状态 BLOCKED） | 2026-08-28 |
| `hitchThreshold60Hz` | 50 ms | — | PRODUCT_DECISION | 60Hz 不可解释 hitch 阈值 | **T-step6 自动探针 PASS**：max 3.3ms、hitch50=0；物理门待 T-step8 | 2026-08-28 |
| `hitchThreshold120Hz` | 33 ms | — | PRODUCT_DECISION | 120Hz 不可解释 hitch 阈值 | NOT_RUN（同上） | 2026-08-28 |

## 5. Phase 1G 激活入口参数（Hot Corner / Global Shortcut）

来源类别遵循本文档允许集；ADR-012 Q3 文内的 ENGINEERING_JUDGMENT 映射为下表 `PRODUCT_DECISION`（工程判断落在产品保守候选带，**非** reverse-derived）。与显示刷新率无关：dwell/cooldown/poll 均用墙钟秒，不用 frame count。

| 参数 | 默认值 | 合法范围 | 来源类别 | 选择理由 | 验证结果 | 修改日期 |
|---|---|---:|---:|---|---|---|---|
| `hotCornerPollInterval` | 0.075 s（75 ms） | 0.05–0.10 s | PRODUCT_DECISION | ADR-012 Q3 选定主线程 Timer；落在 50–100ms 候选带中点偏下，平衡响应与空闲唤醒；disabled=零 timer | 自动化：disabled 零 start（T-1G-D）；能耗门待 T-1G-F | 2026-09-10 |
| `hotCornerZoneSize` | 10 pt | 6–24 pt | PRODUCT_DECISION | 保守热区边长；过小难命中、过大易误触；独立产品候选（非系统 Hot Corner 拷贝） | 状态机单测覆盖；物理误触门待 M 系列 | 2026-09-10 |
| `hotCornerDwellDuration` | 0.15 s | 0.15–0.80 s | PRODUCT_DECISION | 进入热区后驻留才触发；用户反馈 0.35s 偏慢，2026-09-11 改为下限 0.15s | 状态机单测；物理门待 | 2026-09-11 |
| `hotCornerHysteresisInset` | 6 pt | 2–16 pt | PRODUCT_DECISION | 触发后 re-arm 扩展区余量；离开 zone+inset 才允许再次触发 | 状态机单测；物理门待 | 2026-09-10 |
| `hotCornerCooldown` | 1.0 s | 0.3–3.0 s | PRODUCT_DECISION | 触发后冷却，抑制边界抖动连触 | 状态机单测；物理门待 | 2026-09-10 |
| `globalShortcutFireDebounce` | 0.25 s | 0.10–0.50 s | PRODUCT_DECISION | 抑制 key repeat / 抖动导致的 show/hide 连发；Carbon hot-key 本身多为单次 press，debounce 作双保险 | Fake registrar 单测锁定 | 2026-09-10 |
| `presentationPresentDuration` | 0.18 s | 0–0.40 s | PRODUCT_DECISION | LauncherWindowController 非 RM present 动画（T-1G-B）；RM→0 | 窗控单测；视觉门待 | 2026-09-10 |
| `presentationDismissDuration` | 0.14 s | 0–0.40 s | PRODUCT_DECISION | 非 RM dismiss 动画；RM→0 | 同上 | 2026-09-10 |

默认启用策略（非数值参数，见 ADR-012 Q1）：`globalShortcutEnabled=false`、`hotCornerEnabled=false`；用户显式开启前零注册/零轮询。

## 6. 文档级变更记录

| 日期 | 变更 | 执行人 |
|---|---|---|
| 2026-08-28 | 创建 v1.0（23 参数，来源类别齐备；实验值标 TUNING_REQUIRED） | Main（T-step1） |
| 2026-08-28 | T-step6 后回填验证结果；补"修改日期"列；§3 补"合法范围"列（Reviewer M-2） | Main |
| 2026-08-28 | 物理门 PASS 后固化：displacementThreshold 0.46、momentumDecay 0.55、momentumGlideFrames 1、momentumMaxOvershoot 0.20（软阻尼）、retreatDisplacementFactor 20/23（回退 0.40）；试值史入理由列 | Main（T-step8） |
| 2026-08-28 | Phase 1B 真实内容调参轮（用户决策，decision_recorded）：0.46/0.40 → 0.45/0.38（第 13 轮）→ 0.43/0.36（第 14 轮，用户确认 OK 4/4/4/4/3.6）；retreatDisplacementFactor 20/23 → 38/45 → 36/43；1-ulp 零偏移（0.43×36/43==0.36 精确） | Main（T-worker-b-thresh45/43） |
| 2026-08-29 | Phase 1B 后续调参轮（用户决策，decision_recorded）：0.43/0.36 → 0.42/0.35（第 15 轮，用户"前进阈值改成0.42，回退系数改成0.35"→ 理解=回退阈值 0.35 → factor 35/42；phys1b-06 复测用户确认"挺好的"）；1-ulp 零偏移（0.42×35/42==0.35 精确）；同日用户自行重构帧驱动（PagingFrameDriver 协议抽象 + callback-boundary profiler），基线 462 tests | Main（T-worker-b-thresh42） |
| 2026-08-30 | Phase 1D 搜索：无新增平台/性能参数（搜索为纯内存过滤,不引入 debounce 计时器参数;query 归一化用系统 Locale,无硬编码阈值）;基线 526→620 tests | Main（T-1D-A..E） |
| 2026-08-30 | Phase 1E 文件夹：无新增平台/性能参数（folder-lab groupSize 35 为测试入口配置非产品参数；Reduce Motion 参数 0/1/0 与 standard 0.18/0.96/8 入 ADR-008 §5）；基线 631→756 tests | Main（T-1E-A..E） |
| 2026-09-10 | Phase 1G T-1G-D：追加 §5 Hot Corner/shortcut 参数（poll/zone/dwell/hysteresis/cooldown/debounce + presentation durations）；ADR-012 Q2/Q3 ACCEPTED | Worker（T-1G-D） |
