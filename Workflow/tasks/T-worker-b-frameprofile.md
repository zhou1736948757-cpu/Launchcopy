# Task: T-worker-b-frameprofile — 帧路径耗时探针（--frame-profile）

- **Task ID**: T-worker-b-frameprofile
- **Role**: Worker (PagingUI / PagingPrototypeApp)
- **Status**: PASSED (Main 判定)
- **Origin**: 用户指示「把卡顿深挖一下」（2026-08-29 decision_recorded；分析已证卡顿在交互路径）
- **Write scope**: `Sources/PagingUI/FrameProfileRecorder.swift`（新建）、`Sources/PagingUI/PagingSurface.swift`、`Sources/PagingPrototypeApp/AppArguments.swift`、`AppMain.swift`、`AppDelegate.swift`、`Tests/PagingUITests/FrameProfileTests.swift`（新建）、`Workflow/results/T-worker-b-frameprofile.md`
- **Forbidden**: PagingTelemetry 契约、Package.swift、其他 Sources/、其他 Tests/、Docs/、Workflow/STATE.json、Workflow/events.jsonl（Main 独占）

## 改动
- `--frame-profile` 诊断模式（默认关闭，零测量零开销）：帧回调/输入事件各阶段耗时（纳秒级 ContinuousClock）→ `/tmp/launch-copy-paging-prototype-<run-id>-profile.jsonl`
- 两型记录：frame（input_ns/state_ns/view_ns/total_ns/gesture_active）、input（+phase）
- 不变量 input+state+view ≤ total（测试断言 + 端到端 0 违例）

## 验证（Main 独立复验）
- `swift test` 全量：**429 tests, 0 failures**（414 + t19 5 + t20 10）
- `swift build -c release`：exit 0（本任务零警告；1 条既有警告 PagingPageContent:38 AnyHashable Sendable 已派修复）
- 端到端：GUI 自驱 40 flings + --frame-profile，660 条记录 0 违例
- 初步信号：最差 8.9ms 卡顿（gesture.changed）归属 view_ns=8.9ms（state 仅 50µs）→ 指向视图更新路径

## 结果文件
`Workflow/results/T-worker-b-frameprofile.md`（worker-frameprofile，NO_PRIOR_EXPOSURE 声明，未自我认证 PASS）
