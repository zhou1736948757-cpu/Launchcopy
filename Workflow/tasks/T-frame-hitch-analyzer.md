# Task: T-frame-hitch-analyzer — 可复跑的隐私安全 hitch 关联分析器

- **Role**: Worker
- **Status**: PASSED
- **Origin**: FRAME_HITCH_DEEP_DIVE；现有分析依赖临时脚本且 telemetry/profile 使用不同绝对时钟。
- **Date basis**: 2026-08-28。仓库/日志中的 2026-08-29 时间戳不用于证明执行先后。
- **Write scope only**:
  - `Tools/analyze_frame_hitches.py`
  - `Tools/tests/test_analyze_frame_hitches.py`
  - `Docs/FRAME_HITCH_ANALYZER.md`
  - `Workflow/results/T-frame-hitch-analyzer.md`
- **Forbidden**: 所有 Swift 源码、`Sources/PagingCore/`、Package.swift、既有 JSONL、Git clean/reset/commit。

## Required behavior

1. Python stdlib-only CLI，接收 telemetry、可选 frame profile、可选 runloop profile。
2. 只把 telemetry `event_phase=frame` 纳入 interval 统计；阈值至少 20/25/33.3/50ms。
3. telemetry↔profile 默认用 frame ordinal 对齐，并验证相邻 frame interval 差异；绝不直接相减 wall-clock 与 uptime timestamp。
4. profile↔runloop 用 uptime hitch window 对齐；解释每条 `gap_ns` 前必须验证实际相邻 activity pair。
5. 对 runloop 只输出 coarse `active-like` / `waiting-like` / `unclassified`；waiting-like 不等价于系统调度根因。
6. 输出 Markdown 和 JSON 两种格式；每个 hitch 包含前/当前/后 interval、callback total、前窗匿名事件类别、runloop 大 gap 分类、证据等级。
7. 不输出原始 app 名、bundle ID、URL、路径、icon 数据或原始未知字段；输入路径仅可在命令行错误中出现，不进入报告正文。
8. 缺 profile/runloop 时诚实降级为 UNRESOLVED；SELFDRIVE 标签必须明确不是物理手感证据。
9. 测试覆盖：时钟误 join 防护、ordinal 对齐、方向正确的前窗、after-event 不当原因防护、runloop pair 解释、隐私字段不泄漏、缺文件降级。
10. 用现有匿名运行验证；不得修改源 JSONL。

## Acceptance

- `python3 -m unittest -v Tools/tests/test_analyze_frame_hitches.py` 全绿。
- 对 phys1b-05 复算出 596 frames、16 个 >20ms、max 23.702ms（允许格式舍入误差）。
- 对 selfdrive neutral 复算出 638 frames、12 个 >20ms、max 53.510ms。
- 结果报告记录命令、hash/行数读取策略、限制与隐私检查。
