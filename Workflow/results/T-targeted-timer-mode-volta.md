# T-targeted-timer-mode-volta — Result

## Verdict

`PASS_READ_ONLY_AUDIT`

## Key findings

- 现有探针缺少 scheduled deadline、callback entry/exit、callback_seq、missed periods 和主线程 CPU time；不能把 waiting-like 命名为 scheduler/wake-up。
- FrameProfileRecorder 不覆盖完整 Timer closure；跨文件仍依赖 ordinal。
- telemetry 每 frame 同步记录，runloop observer 高频执行，二者都需要 observer-effect 对照。
- 最小后续 schema：callback_seq + scheduled/entry/exit/lateness/missed periods + 匿名 mode + thread CPU；frame record 绑定 callback_seq。
- 先做 profiler on/off、telemetry on/off，再做 tolerance、mode registration 和 real/neutral 单变量 A/B。

## Boundary

只读；未修改文件；未访问 LaunchBetter、BuhoReverseNotes 或逆向证据。
