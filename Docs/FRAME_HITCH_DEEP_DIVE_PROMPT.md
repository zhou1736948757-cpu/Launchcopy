# 任务：深挖 macOS 分页原型的主线程卡顿（帧回调之外）

> 这是一份自包含的任务书。你（GPT）不需要了解本项目的其他背景，所有必要信息都在下面。

## 1. 任务目标

定位一个 macOS AppKit 分页滑动原型中**偶发帧间隔卡顿（20–53ms，正常 16.67ms）**的根本原因。已确认卡顿**不在帧回调路径内**（输入处理/状态机/视图更新三段耗时最坏 2.7ms），需要深挖**帧回调之外**的主线程工作与系统级因素。

## 2. 项目背景（一句话）

`/Users/mac/Projects/Launch_Copy/PagingPrototype/` 是一个 Swift 6 / AppKit 分页原型（5 页 × 35 应用/页，真实应用目录内容 + 运行时图标），帧泵 = 主 runloop 60Hz Timer（非 vsync）。414+ 测试全绿，物理手感用户已接受（主观 4/4/4/4/3.6），当前在做性能深挖。

## 3. 已观察到的现象（真实数据）

### 3.1 人手实测 phys1b-04（423s，41 次手势，图标全尺寸时代）
- 帧间隔：median 16.67ms，p95 18.09ms，**max 48.02ms**；21 个帧 >20ms
- 全部卡顿帧发生在**用户操作期间**（396–423s），与图标加载（启动 0.9–1.2s 完成）**零重叠**
- 与 layout 事件**零共现**（0/21）；无周期性（间隔 0.02–5.7s 随机，排除 GC/autorelease 周期）
- 卡顿帧上下文：全部在 `gesture.changed` / `transition.commit` / `momentum` 期间

### 3.2 人手实测 phys1b-05（39s，29 次手势，图标 256×256 上限后）
- **帧回调内耗时（探针）：median 0.24ms，max 2.7ms，>20ms 的 0 个** ← 关键证据
- 帧间隔：median 16.67ms，max 23.7ms，16 个 >20ms（幅度比 phys1b-04 减半）

### 3.3 SELFDRIVE 对照实验（合成手势 40 flings 相同序列，性能对照非物理证据）
| 指标 | 真实内容 | 中性内容（无图标） |
|---|---|---|
| 帧间隔 >20ms | 5 个 | **12 个** |
| 帧间隔 max | 39.4ms | 53.5ms |
| 帧回调 max | 31.7ms（view 段 31.5ms，1 次） | 9.4ms |

### 3.4 已排除项
- ❌ 图标加载/解码（与卡顿零重叠；中性内容卡顿反而更多）
- ❌ 布局（layout 与卡顿零共现）
- ❌ GC/autorelease 周期（无周期性）
- ❌ 帧回调内三段处理（input/state/view，探针 max 2.7ms 人手）

## 4. 现有工具（可直接用）

### 4.1 运行命令（真实内容全屏 + 帧探针）
```bash
cd /Users/mac/Projects/Launch_Copy/PagingPrototype
swift run -c release PagingPrototypeApp --page-count 5 --items-per-page 35 \
  --momentum-glide-frames 1 --momentum-overshoot 0.2 \
  --paging-telemetry --run-id <your-run-id> --fullscreen --frame-profile
```
- 中性内容对照：加 `--neutral-content`
- 合成手势自驱（40 flings 自动退出）：环境变量 `PAGING_PROTOTYPE_GUI_SELFDRIVE=1`

### 4.2 输出文件
- telemetry：`/tmp/launch-copy-paging-prototype-<run-id>.jsonl`（frame 事件含 `frame_interval`；gesture/transition/momentum/icon.async 事件）
- 帧探针：`/tmp/launch-copy-paging-prototype-<run-id>-profile.jsonl`，两型记录：
  - `frame`：`{"kind":"frame","timestamp":T,"input_ns":N,"state_ns":N,"view_ns":N,"total_ns":N,"gesture_active":bool}`
  - `input`：同结构 + `"phase":"began|changed|ended|momentum.*"`
  - 不变量：`input_ns + state_ns + view_ns ≤ total_ns`（测试已断言）

### 4.3 关键代码位置
- `Sources/PagingUI/PagingSurface.swift` — 帧回调 `advanceFrame` / 输入 `handleScrollInput` / `apply` / core 事件同步回调（探针插桩点）
- `Sources/PagingUI/FrameProfileRecorder.swift` — 现有帧探针（纳秒级 ContinuousClock 阶段计时）
- `Sources/PagingPrototypeApp/AppDelegate.swift` — 接线与 teardown 落盘
- `Sources/PagingCore/` — 纯逻辑状态机（PagingCore 冻结，勿改）

## 5. 待深挖方向（按优先级）

1. **主线程 runloop 级工作**：帧回调之间的主线程在做什么？用 `CFRunLoopObserver`（beforeSources/afterSources/beforeTimers/afterTimers/beforeWaiting/afterWaiting）测量各阶段耗时，与帧间隔对照。重点怀疑：图标异步写回（MainActor）、`NSImageView` 绘制提交、`CATransaction` 提交、其他 runloop source。
2. **绘制/合成提交**：AppKit 绘制与 Core Animation 提交是否在帧回调外产生峰值（`NSView.display`、`layerContents`、窗口 resize/布局）。
3. **系统级调度**：WindowServer 合成、其他进程抢占、电源管理（App Nap）、触控板事件流（NSEvent 分发频率与批量）。
4. **图标写回间接影响**：图标 256 上限后卡顿幅度减半（48→23.7ms），虽对照显示图标非主因，但写回/绘制路径的间接贡献值得量化。

## 6. 约束（必须遵守）

- **隐私红线**：不得记录/输出 app 名称、bundle ID、路径、图标数据、启动 URL；耗时测量与计数可以。
- **诚实标注**：SELFDRIVE 合成手势数据是性能对照，**不是**物理手感证据；任何结论必须区分"实测证据"与"推断"。
- **PagingCore 冻结**：`Sources/PagingCore/` 是冻结状态机，只读，勿改。
- **只读分析优先**：先分析现有数据（`/tmp/launch-copy-paging-prototype-phys1b-05*.jsonl`、`selfdrive-*.jsonl` 等）；如需改代码加探针，说明改动点与理由，改动尽量小且默认关闭。
- 测试纪律：改代码后 `swift test` 全量 ≥429 全绿，`swift build -c release` exit 0 零警告。

## 7. 交付物

1. **定位结论**：卡顿发生在哪一环（runloop 阶段/绘制提交/系统调度/其他），附证据（数据/图表/代码路径）
2. **量化**：各候选来源对卡顿帧的贡献占比（如有数据）
3. **修复建议**：按收益/成本排序的优化方案（含预期效果与风险）
4. **诚实边界**：哪些是实测、哪些是推断、哪些需要更多数据

## 8. 参考数据文件（已存在，可直接分析）

- `/tmp/launch-copy-paging-prototype-phys1b-04.jsonl`（人手 423s，图标全尺寸）
- `/tmp/launch-copy-paging-prototype-phys1b-05.jsonl` + `-profile.jsonl`（人手 39s，图标 256）
- `/tmp/launch-copy-paging-prototype-selfdrive-real.jsonl` + `-profile.jsonl`（合成，真实内容）
- `/tmp/launch-copy-paging-prototype-selfdrive-neutral.jsonl` + `-profile.jsonl`（合成，中性内容）
