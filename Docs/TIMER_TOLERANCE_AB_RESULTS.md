# Timer Tolerance A/B — SELFDRIVE 结果

> **后续术语校正（2026-08-29）：** 后续实现记录的是 Timer closure entry 到 `advanceFrame` 返回后的 recorded-exit marker；该 marker 不等于已确认的 Timer closure return。`scheduled_ns` / `lateness_ns` 基于 recorder-maintained nominal schedule，而不是 Timer/CFRunLoop 报告的真实 fire deadline。当前权威结论见 `Docs/CALLBACK_BOUNDARY_ABBA_RESULTS.md`。


> 日期：2026-08-29  
> 状态：`SUPPORTED_PARTIAL_CONTRIBUTOR`（仅覆盖 `20–25ms` 短尾；不是全部 hitch 根因）  
> 运行环境：同一台 60Hz Mac、本地 Release build、neutral content、RunLoop Timer 实际帧源、窗口模式、交错顺序 `A1 B1 B2 A2 A3 B3`。

## 1. 结论先行

默认 `8.333ms` Timer tolerance 是当前实现中 **`20–25ms` frame interval 的可重复部分贡献因素**。

这个判断在两条独立采样轨道中重复出现：

- Full probe：telemetry + frame profile + runloop observer；
- Lite probe：telemetry only，无 frame/runloop profiler。

把 tolerance 从 8.333ms 改为 0ms 后：

- `20–25ms` 频率在 Full probe 下降约 **68.7%**；
- `20–25ms` 频率在 Lite probe 下降约 **63.2%**；
- 两条轨道的每轮 A 与 B 均呈一致方向，且 Lite probe 的 A/B 每轮 `>20ms` 计数范围不重叠；
- `>25ms` 没有稳定改善，因此 tolerance **不能解释剩余长尾**，更不能解释历史 27.986–53.510ms 的全部样本。

所以当前定位不是“所有卡顿已修复”，而是：

```text
20–25ms 短尾：Timer tolerance 已获单变量重复证据
>25ms 长尾：仍未定位，需要 deadline/lateness/first-tick/callback-boundary 探针
```

## 2. Track 1 — Full probe

配置：

```text
--neutral-content
--paging-telemetry
--frame-profile
--frame-timer-tolerance-ms 8.333|0
```

### 2.1 每轮结果

| Run | Arm | Frames | >20ms | >25ms | >33.3ms | p95 | p99 | Max |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| a01 | 8.333ms | 553 | 18 | 1 | 0 | 19.324 | 23.479 | 30.286 |
| a02 | 8.333ms | 556 | 16 | 2 | 0 | 19.061 | 22.939 | 32.515 |
| a03 | 8.333ms | 566 | 16 | 2 | 1 | 18.827 | 22.345 | 33.348 |
| b01 | 0ms | 517 | 3 | 0 | 0 | 18.016 | 18.675 | 23.094 |
| b02 | 0ms | 511 | 6 | 1 | 0 | 18.080 | 20.382 | 27.376 |
| b03 | 0ms | 516 | 8 | 3 | 0 | 18.058 | 20.874 | 30.884 |

### 2.2 聚合

| Arm | Frames | >20ms | rate/1000 | 20–25ms | rate/1000 | >25ms | rate/1000 | pooled p95 | pooled p99 | max |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 8.333ms | 1,675 | 50 | 29.85 | 45 | 26.87 | 5 | 2.99 | 19.042 | 23.231 | 33.348 |
| 0ms | 1,544 | 17 | 11.01 | 13 | 8.42 | 4 | 2.59 | 18.039 | 20.257 | 30.884 |

变化：

- `>20ms` rate：下降约 **63.1%**；
- `20–25ms` rate：下降约 **68.7%**；
- `>25ms` 样本过少且仅 5→4，不能宣称改善；
- p95 下降约 1.003ms，p99 下降约 2.974ms。

### 2.3 Runloop 与 mode

- 六轮 runloop 记录总数约 476k；每轮约 79k；
- 所有 mode 都是 `default`；
- 这说明 SELFDRIVE 没有覆盖真实触控板的 `eventTracking` 场景，不能用本轮排除 mode-boundary；
- Full probe hitch 的 waiting-like/unclassified 构成会随 tolerance 改变，但缺少 deadline、callback boundary 和 CPU time，不能把这些类别升级为系统组件因果。

## 3. Track 2 — Lite probe（排除高频 runloop observer 为主要解释）

配置：

```text
--neutral-content
--paging-telemetry
--frame-timer-tolerance-ms 8.333|0
```

没有 `--frame-profile`，因此没有 frame profiler 和 runloop observer。

### 3.1 每轮结果

| Run | Arm | Frames | >20ms | 20–25ms | >25ms | p95 | p99 | Max |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| a01 | 8.333ms | 602 | 16 | 16 | 0 | 19.080 | 23.109 | 24.525 |
| a02 | 8.333ms | 527 | 12 | 12 | 0 | 18.984 | 21.771 | 23.582 |
| a03 | 8.333ms | 566 | 20 | 17 | 3 | 19.412 | 22.824 | 28.399 |
| b01 | 0ms | 512 | 9 | 7 | 2 | 18.376 | 22.179 | 28.044 |
| b02 | 0ms | 513 | 3 | 3 | 0 | 18.105 | 18.885 | 24.982 |
| b03 | 0ms | 512 | 7 | 5 | 2 | 18.247 | 20.463 | 29.862 |

### 3.2 聚合

| Arm | Frames | >20ms | rate/1000 | 20–25ms | rate/1000 | >25ms | rate/1000 | pooled p95 | pooled p99 | max |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 8.333ms | 1,695 | 48 | 28.32 | 45 | 26.55 | 3 | 1.77 | 19.123 | 22.604 | 28.399 |
| 0ms | 1,537 | 19 | 12.36 | 15 | 9.76 | 4 | 2.60 | 18.225 | 21.021 | 29.862 |

变化：

- `>20ms` rate：下降约 **56.4%**；
- `20–25ms` rate：下降约 **63.2%**；
- `>25ms` rate 没有改善；
- p95 下降约 0.898ms，p99 下降约 1.583ms。

Full/Lite 两条轨道方向一致，因此高频 runloop observer 不是该短尾差异的充分解释。但 telemetry 仍在 callback 内同步记录；本轮没有 telemetry-off 的独立 cadence probe，不能宣称已经完全消除 observer effect。

## 4. 完整性

所有 12 个正式 SELFDRIVE run 都有：

- `run.end = 1`；
- `teardown.complete = 1`；
- `gesture.began = 40`；
- `gesture.ended = 40`。

Full probe 的 telemetry/profile frame count 每轮相等；相邻 ordinal 验证仍有 24–33 个 mismatch，已保留，不把全部 ordinal 强行写成相关。

原始文件及 SHA-256 清单见：

```text
Docs/TIMER_TOLERANCE_AB_ARTIFACTS.sha256
```

原始 JSONL 位于 `/tmp`，属于本机临时证据；清理 `/tmp` 前应另行归档。

## 5. 重要副作用/混杂

SELFDRIVE 的 40 次 fling 在两臂产生明显不同的 commit/stale 结果：

- 8.333ms 多数约 17–20 committed；
- 0ms 多数约 29–30 committed。

这说明 tolerance 改变不仅改变 interval 分布，也改变了当前脚本输入时序下的动画/决策结果。它可能是更稳定 cadence 的真实效果，也可能暴露 SELFDRIVE 输入协议与 simulation-dt/Timer restart 的耦合。

因此 0ms **不能直接固化为生产默认**。必须通过真实触控板 ABBA 检查：

- 翻页意图是否保持；
- 跟手性、settle、中断连续性是否改善；
- 是否增加错误 commit；
- CPU/能耗是否可接受。

## 6. 仍未解决的长尾

以下问题仍未被当前实验回答：

1. 为什么 0ms 下仍有 23–31ms 样本；
2. 历史 39–53ms 样本是否来自 missed period、start→first callback、其他主线程工作或系统外部因素；
3. Timer 每次重建后的首 tick 实际 lateness；
4. callback 完整入口/出口以及 callback 外主线程 CPU；
5. 真实触控板 eventTracking 与 default/mode boundary 的关系。

## 7. 当前 gate

```text
SUPPORTED_PARTIAL_CONTRIBUTOR_TIMER_TOLERANCE_FOR_20_TO_25MS
REQUIRE_PHYSICAL_AB_BEFORE_DEFAULT_CHANGE
PROCEED_TO_DEADLINE_FIRST_TICK_CALLBACK_BOUNDARY_PROFILING_FOR_LONG_TAIL
```
