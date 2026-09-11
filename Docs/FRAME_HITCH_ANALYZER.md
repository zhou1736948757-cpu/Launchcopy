# Frame Hitch Analyzer

`Tools/analyze_frame_hitches.py` 是一个只使用 Python 标准库的、可复跑且隐私安全的 JSONL 分析器。它的输出仅含固定匿名类别、frame ordinal 和时长；不复制原始记录，也不输出 app 名、bundle ID、URL、路径、图标数据、run ID、原始未知字段或输入路径。

## 安全关联规则

1. **Telemetry interval**：仅接受 `event_phase == "frame"`；`frame_interval` 按秒换算为毫秒。汇总固定包含 `>20`、`>25`、`>33.3`、`>50 ms`，hitch 明细默认是 `>20 ms`。
2. **Telemetry ↔ frame profile**：二者的 timestamp 时钟不同。工具绝不相减 telemetry wall-clock 与 profile uptime。默认按各自的 frame **ordinal** 配对；对每个相邻 ordinal，在各自时钟域内比较 telemetry interval 与 profile uptime delta。默认容差为 1 ms。对 hitch frame ordinal `i`，interval 窗口是 `profile[i-1].timestamp → profile[i].timestamp`，因此报告的 callback total 明确取 **前一帧 callback `profile[i-1]`**；`profile[i]` callback 位于该 interval 结束之后，不得误归因为当前 hitch。ordinal 0 没有 preceding profile interval，必须保持 callback 未归因/`UNRESOLVED`。
3. **Frame profile ↔ runloop**：仅在 frame profile 存在时，使用 profile uptime hitch window `(profile[i-1], profile[i]]` 关联 runloop。大 `gap_ns` 只有在其确实等于相邻 runloop observation 的 timestamp delta（默认误差 max(1 ms, 2%)）时才解释 activity pair。
4. **Runloop 结论限制**：`beforeWaiting -> afterWaiting` 可标为 `waiting-like`；少数已知非等待 pair 可标为 `active-like`；其余或未验证 pair 为 `unclassified`。`waiting-like` 不是系统调度、WindowServer 或任何单一根因的证明。
5. **事件方向**：每条 hitch 的 telemetry 前窗为上一 frame 到当前 frame 的半开窗口；当前 frame 之后的事件不会被列为前窗关联。

缺 frame profile 或 runloop profile 时，工具不补造关联。缺 frame profile 时每个 hitch 都是 `UNRESOLVED`。`SELFDRIVE` context 会明确写为合成性能对照，**不是物理手感证据**。

## CLI

```bash
cd /Users/mac/Projects/Launch_Copy/PagingPrototype
python3 Tools/analyze_frame_hitches.py \
  "$TELEMETRY_JSONL" \
  --frame-profile "$FRAME_PROFILE_JSONL" \
  --format markdown \
  --run-context MANUAL
```

JSON 输出：

```bash
python3 Tools/analyze_frame_hitches.py \
  "$TELEMETRY_JSONL" \
  --frame-profile "$FRAME_PROFILE_JSONL" \
  --format json \
  --run-context SELFDRIVE
```

可选 runloop profile：

```bash
python3 Tools/analyze_frame_hitches.py \
  "$TELEMETRY_JSONL" \
  --frame-profile "$FRAME_PROFILE_JSONL" \
  --runloop-profile "$RUNLOOP_PROFILE_JSONL" \
  --runloop-gap-ms 20 \
  --format markdown
```

`--output` 可将生成的 Markdown/JSON 写入文件；未提供时输出到 stdout。对不可读取或非 JSONL 的输入，CLI 错误会说明输入路径；成功报告本身不包含路径。

## Evidence levels

每条 hitch 同时输出 `profile_evidence_level` 与总 `evidence_level`，避免把一个有 profile 但缺 runloop 的样本写成完整归因。

- `PROFILE_CORRELATED`：`profile_evidence_level`。该 ordinal 的相邻 profile interval 验证通过，且位于 interval 起点的前一帧 callback（`i-1`）满足 input/state/view 分段不超过 callback total。
- `PROFILE_ORDINAL_UNVERIFIED`：`profile_evidence_level`。按 ordinal 有 profile，但计数、相邻 interval 或 profile 分段完整性不足以确认本地相关。
- `UNRESOLVED`：总 `evidence_level`。缺 frame profile、缺 runloop profile，或该 ordinal 没有 profile frame 时使用；不从 runloop 单独推断 hitch 根因。

## Test

```bash
python3 -m unittest -v Tools/tests/test_analyze_frame_hitches.py
```
