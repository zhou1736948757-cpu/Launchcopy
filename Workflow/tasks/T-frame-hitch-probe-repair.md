# Task: T-frame-hitch-probe-repair — 去除诊断探针的主线程写盘污染

- **Role**: Worker
- **Status**: PASSED
- **Origin**: FRAME_HITCH_DEEP_DIVE；独立审查发现 frame/runloop recorder 每 512 条在主线程同步 I/O，且 frame flush 位于 `total_ns` 终点之后。
- **Date basis**: 2026-08-28。仓库/日志存在 2026-08-29 时间戳，视为机器时钟或记录来源未校正，不用它证明执行先后。
- **Write scope only**:
  - `Sources/PagingUI/FrameProfileRecorder.swift`
  - `Sources/PagingUI/RunLoopProfileRecorder.swift`
  - 可新增 `Sources/PagingUI/BufferedJSONLWriter.swift`
  - `Tests/PagingUITests/FrameProfileRecorderTests.swift`（若实际测试文件名不同，只可修改对应 FrameProfile 测试文件）
  - `Tests/PagingUITests/RunLoopProfileTests.swift`
  - `Workflow/results/T-frame-hitch-probe-repair.md`
- **Forbidden**: `Sources/PagingCore/`、PagingTelemetry 契约、AppDelegate、Package.swift、Docs、其他模块、Git clean/reset/commit。

## Required changes

1. observer/frame hot callback 内不得执行目录创建、FileHandle open/write/synchronize 等磁盘 I/O。
2. 使用专用串行 writer，主线程只切批并异步排队；teardown `flush()` 可以 barrier 等待并保证所有已接收记录按序落盘。
3. 保持默认关闭时零 observer、零文件、零 writer 工作；保持现有 JSONL 字段兼容。
4. 修正 RunLoop 注释：只能声称 coarse active-vs-waiting pattern；不能把 waiting 单独证明为系统调度，也不能声称可细分 timer/source。
5. 收紧诊断文件权限到 owner-only（0600），失败不崩溃并可查询 failure count。
6. 避免 public 可变 active 状态造成 observer 残留；维持 start/stop 幂等。
7. 新增测试：顺序完整落盘、阈值切批不在调用线程执行阻塞 I/O（可通过可注入 sink/queue 做确定性测试）、stop+flush 完整性、默认关闭、权限（平台允许时）。
8. 不放宽任何既有性能阈值。

## Acceptance

- 定向 PagingUI tests 全绿。
- 全量 `swift test` 全绿，记录实际执行数。
- `swift build -c release` exit 0，记录 warning。
- 结果报告列出精确文件、测试命令、已知边界，不自我扩大为物理手感 PASS。
