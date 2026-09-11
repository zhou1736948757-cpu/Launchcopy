# Task: T-worker-b-runloopprofile — runloop 级主线程探针

- **Task ID**: T-worker-b-runloopprofile
- **Role**: Worker (PagingUI / PagingPrototypeApp)
- **Status**: PASSED (Main 判定)
- **Origin**: 用户确认「去深挖」帧回调之外的主线程卡顿（2026-08-29；对照实验后）
- **Write scope**: `Sources/PagingUI/RunLoopProfileRecorder.swift`（新建）、`Sources/PagingPrototypeApp/AppDelegate.swift`、`AppArguments.swift`、`Tests/PagingUITests/RunLoopProfileTests.swift`（新建）、`Workflow/results/T-worker-b-runloopprofile.md`
- **Forbidden**: PagingTelemetry 契约、Package.swift、其他 Sources/、其他 Tests/、Docs/、Workflow/STATE.json、Workflow/events.jsonl（Main 独占）

## 改动
- `--frame-profile` 同开 runloop 探针（复用开关，零新参数）：CFRunLoopObserver 主 runloop（common modes），活动掩码 entry/beforeTimers/beforeSources/beforeWaiting/afterWaiting/exit
- 记录：timestamp + activity + gap_ns + since_same_ns（纳秒级）→ `/tmp/launch-copy-paging-prototype-<run-id>-runloop.jsonl`
- 默认关闭零开销；teardown 移除观察者 + 落盘

## 环境发现（实测）
- SDK 头文件裁剪 + 运行时均不投递 afterTimers/afterSources；runloop 先做工作再发 before* 观察
- 帧驱动 timer 落 afterWaiting→beforeTimers 段；beforeTimers gap = 主线程工作（与帧 profile total_ns 交叉验证一致）；afterWaiting gap = 睡眠/调度延迟
- 归因能力：帧间隔 >20ms 窗口内查 beforeTimers gap（忙）vs afterWaiting gap（调度）

## 验证（Main 独立复验）
- `swift test` 全量：**435 tests, 0 failures**（429 + 6 新增）
- `swift build -c release`：0 warnings
- 端到端自驱：81,585 条 runloop 记录 + 519 条帧记录
- 1 条既有性能阈值 flake（testPureCoreFlingCostWellBelowFrameBudget，1026µs vs 1000µs，机器负载；隔离 5/5 全绿）——非本任务引入，未擅自放宽，已记录

## 结果文件
`Workflow/results/T-worker-b-runloopprofile.md`（worker-frameprofile，NO_PRIOR_EXPOSURE 声明，未自我认证 PASS）
