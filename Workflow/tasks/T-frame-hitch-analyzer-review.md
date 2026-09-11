# Review: T-frame-hitch-analyzer

- **Status**: PASS
- **Artifact**: `Workflow/reviews/T-frame-hitch-analyzer-r1.md`

## Objective

独立只读审查 `T-frame-hitch-analyzer` 的实现、测试、文档与现有匿名数据复算证据。Reviewer 不得修改实现、测试、文档或输入 JSONL；唯一允许写入是正式 review artifact：

`Workflow/reviews/T-frame-hitch-analyzer-r1.md`

## Evidence to inspect

- `Workflow/tasks/T-frame-hitch-analyzer.md`
- `Workflow/results/T-frame-hitch-analyzer.md`
- `Tools/analyze_frame_hitches.py`
- `Tools/tests/test_analyze_frame_hitches.py`
- `Docs/FRAME_HITCH_ANALYZER.md`
- 匿名输入：
  - `/tmp/launch-copy-paging-prototype-phys1b-05.jsonl`
  - `/tmp/launch-copy-paging-prototype-phys1b-05-profile.jsonl`
  - `/tmp/launch-copy-paging-prototype-selfdrive-neutral.jsonl`
  - `/tmp/launch-copy-paging-prototype-selfdrive-neutral-profile.jsonl`

## Acceptance focus

- telemetry wall-clock 与 profile/runloop uptime 不发生跨时钟相减；
- ordinal 对齐与相邻 interval 验证不会把不匹配样本升级为已关联；
- hitch 前窗方向正确，不纳入 frame 之后事件；
- runloop pair 必须由真实相邻 observation 与 timestamp delta 验证后，才可标记 `active-like` / `waiting-like`；
- `waiting-like` 不被写成 scheduler/WindowServer 根因；
- 缺 profile/runloop 时诚实降级；SELFDRIVE 不作为物理手感证据；
- 成功报告严格使用匿名白名单，不泄漏 app 名、bundle ID、URL、输入路径、run ID、图标数据或未知字段；
- 人手-B 必须复算为 596 frames、16 个 >20ms、max 23.702ms；SELFDRIVE-neutral 必须为 638 / 12 / 53.510ms；
- 测试是否足以覆盖上述关键失败模式。

## Required output

在正式 artifact 中给出 `PASS` 或 `FAIL`，列出 P0/P1/P2、文件与行号证据、实际运行的测试/复算命令，以及自动化结论边界。不得修改任何被审实现文件。
