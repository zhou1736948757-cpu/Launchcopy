# T-step6 — 性能实验（live views baseline + 达标判断）

**Worker**: D（延续 T-worker-d；PagingUI/App 作者）
**Scope**: `Sources/PagingUI/`、`Sources/PagingPrototypeApp/`、`Tests/PagingUITests/`
**未触碰**: `Package.swift`、`Sources/PagingCore/`、`Sources/PagingTelemetry/`、`Docs/`、`PROVENANCE/`、`Workflow/`（本结果文件除外）
**AccessDeclaration: NO_PRIOR_EXPOSURE**（未读取任何禁止来源；未从旧项目搬运优化策略/参数；参数类别未使用禁用三类）

---

## 1. Baseline 数据（5 预设 × 7 指标；脚本化手势旅程 200 甩动/预设，真实输入路径）

### 1.1 纯 Core 处理开销（CLI 探针 run1 / run3，单位 µs/甩动 = 4 阶段 + settle 全帧）

| pages | run1 mean/p99/max | run3 mean/p99/max |
|---|---|---|
| 1 | 9.1 / 14.1 / 92.0 | 6.3 / 8.0 / 93.0 |
| 2 | 10.1 / 15.0 / 30.0 | 7.2 / 12.0 / 12.0 |
| 5 | 9.5 / 12.0 / 34.1 | 7.2 / 9.1 / 9.1 |
| 10 | 11.5 / 23.0 / 39.9 | 7.2 / 9.1 / 9.1 |
| 20 | 10.9 / 14.1 / 16.1 | 7.3 / 9.1 / 9.1 |

XCTest 同进程对照：裸 Core 6.2µs；surface 事件接线（AppKit a11y 更新）存活时 103.7µs（max 764µs）——两探针裸 Core 一致；接线成本仍 ≪ 1ms。

### 1.2 单帧 update CPU（CLI 探针 run1 带 telemetry / run2 无 telemetry，µs/帧）

| pages | 帧数 | mean(带/不带) | p99(带/不带) | max(带/不带) | miss16 | hitch50 |
|---|---|---|---|---|---|---|
| 1 | 2800 | 22.5 / 4.5 | 62.9 / 12.0 | 70 / 13.1 | 0 | 0 |
| 2 | 3700 | 22.2 / 4.9 | 64.0 / 15.0 | 69 / 17.0 | 0 | 0 |
| 5 | 3727 | 53.6 / 35.6 | 2258 / 2201 | 2481 / 2443 | 0 | 0 |
| 10 | 3772 | 53.8 / 36.0 | 2239 / 2176 | 2767 / 2687 | 0 | 0 |
| 20 | 3862 | 54.2 / 36.6 | 2227 / 2171 | 3309 / 3249 | 0 | 0 |

XCTest 探针（5 页、无 telemetry）：4236 帧 mean 5.9µs，max 21.9µs，miss16=0，hitch50=0。
**归因（隔离实验）**：p99≈2.2ms 尖峰在无 telemetry 时不变、且仅出现在有范围平移的预设（5/10/20 页）→ 属**事件驱动 relayout**（回收 + 重建 ≤35 瓦片含 NSTextField + 容器重排），≈每 2 次翻页 1 次；telemetry 每帧 JSON 编码 + 文件写盘 ≈ 18µs 均值（22.5−4.5）。两者均未导致任何帧 > 16.7ms。

### 1.3 页面 view 数量 / 布局次数 / 预热缓存 / 内存 / stale（run1 与 run3 一致）

| pages | livePeak | poolPeak | layouts 总(次/甩动) | fresh | reuse | 复用率 | commits | stales |
|---|---|---|---|---|---|---|---|---|
| 1 | 1 | 0 | 2 (0.01) | 0 | 0 | – | 200 | 0 |
| 2 | 2 | 0 | 2 (0.01) | 0 | 0 | – | 200 | 0 |
| 5 | 5 | 1 | 101 (0.51) | 1 | 49 | 0.980 | 200 | 0 |
| 10 | 7 | 3 | 110 (0.55) | 3 | 54 | 0.947 | 200 | 0 |
| 20 | 7 | 3 | 120 (0.60) | 3 | 69 | 0.958 | 200 | 0 |

- view 预算：live ≤ 7、pool ≤ 7、合计 ≤ 14（§7.4 上界验证，全预设）
- layout 事件驱动：0.5~0.6 次/甩动（仅范围平移时），非每帧
- 预热：全旅程冷创建 ≤ 3（初始范围外页面），此后 100% 复用（XCTest：fresh=3 reused=13）
- **stale completion 零提交：全预设 stales=0，commits=200（= 甩动数，无重复提交）**

### 1.4 GUI telemetry（真实 app 实例 + 真实 runloop）

- `perf-gui-01`（run1）：display link 无头环境**不触发**（零 frame 事件，证据保留）；9 次提交全部来自边界即时提交路径（beginSettle from==target 无需动画帧）。
- `perf-gui-02`（run2，回退帧泵）：1240 事件：frame 787 条 @ 16.67ms 均值；transition.begin 40 = commit 3 + **stale_rejected 37 + interruption.began 37（1:1）**；prepare 3 + reuse 33；teardown.complete + run.end 完整闭合。
- 真实 display link 帧节奏：**NOT_RUN**（无头环境 CADisplayLink 不触发；证据：run1 零帧事件 + run2 检测日志）。

## 2. 达标判断（§8.5/§2.5 初始目标 60Hz）

| 指标 | 自动可测结果 | 判定 |
|---|---|---|
| 无 >50ms 主线程 hitch | 0 次（max 3.3ms，含 relayout 峰值） | 自动 **PASS**；物理 NOT_RUN |
| 手势热路径无同步重资源加载 | 无同步 I/O；唯一重块 = 事件驱动 relayout ≈2.2ms（≈1/40 帧，7.5x 余量） | 自动 **PASS**；物理 NOT_RUN |
| frame miss ≤ 1% | 0%（0/2800~3862 帧/预设） | 自动 **PASS**；物理 NOT_RUN |
| 中断无可见跳变 | §3.F 六门禁 + 接管点=显示位置断言全绿 | 正确性 **PASS**；视觉 NOT_RUN |
| 主观跟手/连续/settle ≥ 4/5 | — | **NOT_RUN**（T-step8 物理门） |

**结论：自动可测指标全部达标（余量 300x~4600x）→ 按 ADR-002 不启用方案 2（compositor），不实现 composited 路径**。优化实验未启动（无未达标项，先正确后优化）。

## 3. 优化实验记录（未启动）+ 探针发现的修复

无优化改动（无未达标指标）。但探针发现并修复一个**真实缺陷**：

- **缺陷**：`PagingSurface` 未转发 Core 的 `onStaleRejection`/`onInterruption` 到 `appEvents`（T-worker-d 交付遗漏；Core 计数正确但外部观察不到）。
- **假设**：telemetry 桥的 stale_rejected / interruption.began 事件从未触发。
- **改动前数据**：perf-gui-01：Core staleRejectionCount=30，telemetry 0 条 stale/interruption 事件。
- **改动后数据**：perf-gui-02：37 stales → 37 stale_rejected + 37 interruption.began（1:1）。
- **是否改善**：是（可观测性契约补齐；telemetry 性能数据完整性恢复）。
- **正确性**：新增转发回归测试 `testStaleAndInterruptionEventsForwardedToAppEvents`；全量 140 测试 0 失败。
- **保留理由**：Core→UI 六事件全转发是 telemetry/可观测性契约的一部分；不保留则 T-step6 的 stale 数据不可验证。

## 4. 异常 run 清单（全部保留，未删除任何日志）

| 文件 | 说明 |
|---|---|
| `/tmp/launch-copy-paging-prototype-perf-gui-01.jsonl` | display link 静默 run（无 frame 事件）——保留为无头环境证据 |
| `/tmp/launch-copy-paging-prototype-perf-gui-02.jsonl` | 回退泵 run（synthetic 帧源，明确标注） |
| `/tmp/launch-copy-paging-prototype-perf-cli-p{1,2,5,10,20}.jsonl` | CLI 探针日志（追加模式，多 run 累积；p10 含 2 个 run） |
| `/tmp/perf-bench-run1.txt` / `run2-notelemetry.txt` / `run3.txt` | 探针 stdout 全量 |
| `/tmp/gui-selfdrive-run1.log` / `run2.log` | GUI 自驱 stdout 全量 |

## 5. 验证命令与退出码

| 命令 | 结果 |
|---|---|
| `swift build --target PagingUI` | exit 0 |
| `swift build --target PagingPrototypeApp` | exit 0 |
| `swift build`（全包，0 warning） | exit 0 |
| `swift test`（全量，**140 tests 0 failures**：51 Core + 33 Telemetry + 56 UI） | exit 0 |
| `PAGING_PROTOTYPE_PERF=1 swift run PagingPrototypeApp`（run1/run3 带 telemetry，run2 隔离） | exit 0（3 次） |
| `PAGING_PROTOTYPE_GUI_SELFDRIVE=1 swift run PagingPrototypeApp --page-count 10 --paging-telemetry --run-id perf-gui-0X` | exit 0（2 次，自终止） |
| `swift test --filter PagingPerformanceProbeTests` | 4 tests, 0 failures |

## 6. Changed Files（本任务）

| 文件 | 变更 |
|---|---|
| `Sources/PagingPrototypeApp/PerfBenchmark.swift` | 新增：无头性能探针（PAGING_PROTOTYPE_PERF=1；5 预设 × 脚本旅程；纯 Core/单帧/预算/预热/stale；每预设 telemetry 日志） |
| `Sources/PagingPrototypeApp/AppMain.swift` | PERF 分支入口 |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | GUI 自驱模式（PAGING_PROTOTYPE_GUI_SELFDRIVE=1）+ display link 静默检测 + runloop 回退泵 |
| `Sources/PagingUI/PagingSurface.swift` | 新增 `simulateScrollInput`/`simulateFrame` 探针缝（公开，注明非物理门）；**修复 onStaleRejection/onInterruption 转发** |
| `Tests/PagingUITests/PagingPerformanceProbeTests.swift` | 新增 4 探针测试（帧成本/纯 Core/预热/预算，宽松回归预警） |
| `Tests/PagingUITests/PagingSurfaceInterruptionTests.swift` | +1 转发回归测试 |
| `Workflow/results/T-step6.md` | 本文件 |

## 7. Deviations / Memory Candidates

- CADisplayLink 在无头环境不触发（零帧事件为硬证据）；GUI 帧节奏只能物理门测（T-step8）。
- relayout（回收 + 重建 ≤35 瓦片含 NSTextField）≈2.2ms = PagingUI 热路径最大单块成本；事件驱动（≈1/40 帧），未优化（数据达标）。
- telemetry 每帧 JSON 编码 + 文件写盘 ≈18µs 均值热路径成本（隔离实验测得）；未导致帧超时；保留不删。
- 边界即时提交（beginSettle from==target）无需动画帧——无头 GUI run 中 9 次 commit 的来源（勿误读为动画完成）。
- PagingSurface 必须转发 Core 全部 6 类事件（曾漏 2 类 → telemetry 静默缺失；Core 计数正确 ≠ 外部可见）。
- 手势热路径成本分层：裸 Core ~6µs → +a11y 接线 ~104µs → +relayout 峰值 ~2.2ms。
- 探针缝 `simulateScrollInput`/`simulateFrame` 与真实路径同一实现；仅作自动化回归/无头探针，明确非物理门。
