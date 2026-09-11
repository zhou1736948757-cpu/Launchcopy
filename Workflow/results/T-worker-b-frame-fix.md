# T-worker-b-frame-fix — 帧驱动修复（物理复测 #2 FAIL 的根因修复）

**Worker**: B/D 同人（PagingUI/App 作者）
**来源**: T-step8 物理复测 #2 FAIL（用户手测仍卡两页中间；截图 + telemetry 实证）
**日期**: 2026-08-28
**Scope**: `Sources/PagingUI/PagingFrameDriver.swift`、`Sources/PagingUI/PagingSurface.swift`（默认驱动 + 头注）、`Sources/PagingPrototypeApp/AppDelegate.swift`（自驱接线）、`Tests/PagingUITests/RunLoopFrameDriverTests.swift`（新）、`Workflow/results/T-worker-b-frame-fix.md`
**未触碰**: Package.swift / Docs / PROVENANCE / Workflow（结果文件除外）/ PagingCore / PagingTelemetry / 其他
**AccessDeclaration: NO_PRIOR_EXPOSURE**（重申：未读取 §1.3 禁止路径与治理文档；本任务零外部来源接触）

---

## 根因确认（telemetry 证据复读）

`/tmp/launch-copy-paging-prototype-phys-auto-02.jsonl`（真实 Aqua 会话，非无头）：
`gesture.momentum 433 / changed 85 / began 13 / ended 13 / transition.begin 2 / stale 2 / interruption 2 / **frame 0**`。

- `DisplayLinkFrameDriver.start()` 创建 `NSView.displayLink(target:selector:)` 后零回调——**全程零 frame 事件**，
  含 idle runloop 下的 settle 期（settle 动画也靠 advanceFrame）→ settle 只 begin 不推进、commit=0。
- T-step6 的 runloop 回退泵（Timer 60Hz）实测有效（787 帧 @16.67ms），但仅在 SELFDRIVE=1 下启用；
  T-step6 标注"无头"系误判（launchctl managername=Aqua，窗口真实显示）——实为 display link 未投递帧
  （本环境疑似虚拟显示/无 vsync 对齐的环境级问题：idle runloop + common 模式下零回调，非调度 mode 问题）。
- T-worker-b-input-fix 的 100ms 自动释放帧检查同样依赖 advanceFrame → 慢滑卡死（ended 后零事件且无帧检查）。

## 方案选择与理由：**runloop Timer(.common) 60Hz 帧泵为默认驱动（直接替换 display link，不保留优先）**

任务允许"直接以 Timer 泵为默认并如实标注帧源"。选择理由：

1. **证据决定性**：本环境（物理门所在机器）display link 在真实 Aqua 会话、idle runloop、common 模式下零回调
   （phys-auto-02 + 此前所有 run）——环境/API 级不投递，非"未显式 add"可修复（NSView.displayLink 已负责
   runloop 接线；即便显式 `add(to: .main, forMode: .common)`，idle runloop 也该触发却未触发）。
2. **100ms 待决窗口与逐次探测不兼容**：若"display link 优先 + 1.0s 零帧检测"，本机上每次驱动启动都要空转
   探测窗口（≥ 待决窗口 100ms）→ 用户第一次慢滑仍卡（首个交互吃满探测延迟）——除非进程级 sticky 探测，
   复杂度与收益不成比例，且本机探测必失败。
3. **Timer(.common) 已实证**：T-step6 787 帧 @16.67ms；common 模式在滚动跟踪（eventTracking）期间仍触发，
   与 settle 同源；60Hz 节拍对 spring 插值/glide/momentum 均充足（dt clamp 0.1s 防 runloop 停顿放大 dt）。
4. **诚实标注**：帧源 = runloop 60Hz 节拍（≈16.67ms），**非 vsync 对齐**；vsync 对齐留 Phase 1B
   （届时可作为新驱动实现，协议不变，测试/接线零改动）。

## 修复实现

`Sources/PagingUI/PagingFrameDriver.swift`：`DisplayLinkFrameDriver` + proxy 类整体替换为
`RunLoopFrameDriver`（协议 `PagingFrameDriving` 不变）：
- `start()`：`Timer(timeInterval: 1/60, repeats: true)` + `RunLoop.main.add(timer, forMode: .common)`；
  tolerance 1/120；`guard timer == nil` 幂等；弱捕获 self/owner + `isTearingDown` 短路。
- `stop()`：invalidate + nil + isRunning=false；`deinit` 防御性 invalidate。
- `handleFrame(now:)`：dt = 首帧 1/60，后续 `clamp(now-last, 0, 0.1)`（runloop 停顿恢复不失稳）；调 `advanceFrame`。
- 文件头注：完整记录 T-worker-b-frame-fix 证据与帧源标注。

`Sources/PagingUI/PagingSurface.swift`：默认驱动 `RunLoopFrameDriver(owner: self)`；头注更新。
保活逻辑（`updateAnimationDriver`：`isAnimating || pendingFinishSince != nil` → start）与
`advanceFrame` 100ms 自动释放检查**原样保留**（上一波修复不动）。

`Sources/PagingPrototypeApp/AppDelegate.swift`：删除 SELFDRIVE 的 1.5s 零帧检测 + 回退泵
（驱动已是默认 Timer 泵，双泵会双倍推进）；自驱启动打印帧源标注；teardown 注释更新。

## 回归测试（`Tests/PagingUITests/RunLoopFrameDriverTests.swift`，+3）

| 测试 | 断言 |
|---|---|
| `testRunLoopFrameDriverPumpsFrames` | 真实 runloop 旋转 0.15s → onAnimationFrame 计数 > 0（Timer 真实投递）；stop() 后 0.1s 内零新增 |
| `testStartIsIdempotentAndPumpCompletesSettleThenTeardownStops` | 手势→settle→真实泵推进 → commit 1、idle、驱动自停（**phys-auto-02 卡死路径回归**）；teardown 后零回调、staleRejection=0 |
| `testStaleCompletionRejectedAfterTeardown` | teardown 后泵回调被 isTearingDown 短路；零 commit、零 stale |

（注：测试 2 首版假设"空闲 surface 手动 start 后驱动保持运行"——实测 surface 的 updateAnimationDriver
首帧即自停（正确行为），改为以 settle 保活驱动的真实集成路径断言。）

## Verification（命令 + 退出码 + 真机冒烟）

| 命令 | 结果 |
|---|---|
| `swift build`（全包） | exit 0（0 warning） |
| `swift test`（全量） | **151 tests, 0 failures**（148 → +3），exit 0 |
| `PAGING_PROTOTYPE_GUI_SELFDRIVE=1 swift run -c release PagingPrototypeApp --page-count 5 --items-per-page 35 --paging-telemetry --run-id frame-fix-smoke`（真机 Aqua 会话） | exit 0；**SELFDRIVE stats: flings=40 committed=15 stales=25 live=5 pool=0 layouts=23 telemetryEvents=940** |

telemetry 逐类计数（`/tmp/launch-copy-paging-prototype-frame-fix-smoke.jsonl`，修复后 vs phys-auto-02 修复前）：
```
frame 560（前 0）  state.changed 120  gesture.{began,changed,ended} 各 40
transition.begin 40  transition.commit 15（前 0）  transition.stale_rejected 25
interruption.began 25  layout 22  page.reuse 10  teardown.complete 1
```
- **frame 0 → 560**：帧驱动真实投递（每 fling settle 全程推进）。
- **commit 0 → 15**：settle 动画真实完成提交（15 次成功翻页；40 flings 中 25 次被下一个 fling
  按设计打断 → stale/interruption 25，1:1 对应，行为正确——自驱节奏 0.4s < settle 时长）。
- stales=25 与 interruption=25 1:1（D3/D4 语义：新手势接管旧动画），非缺陷。

## Changed Files

| 文件 | 变更 |
|---|---|
| `Sources/PagingUI/PagingFrameDriver.swift` | DisplayLinkFrameDriver → RunLoopFrameDriver（Timer .common 60Hz；幂等 start；dt clamp；弱捕获；deinit invalidate；头注证据） |
| `Sources/PagingUI/PagingSurface.swift` | 默认驱动换 RunLoopFrameDriver；头注更新（保活逻辑未动） |
| `Sources/PagingPrototypeApp/AppDelegate.swift` | 删 SELFDRIVE 零帧回退泵（双泵风险）；帧源标注打印；注释更新 |
| `Tests/PagingUITests/RunLoopFrameDriverTests.swift` | 新增 3 测试（真实 runloop 泵冒烟 + settle 完成 + teardown 门禁） |
| `Workflow/results/T-worker-b-frame-fix.md` | 本文件 |

## Deviations

1. **不保留 display link 优先**（任务"或直接以 Timer 泵为默认"选项）：本机证据下 display link 必失败，
   逐次探测与 100ms 待决窗口冲突；vsync 对齐明确延后 Phase 1B（协议不变，届时可换实现零接线改动）。
2. **自驱回退泵删除**：驱动即默认泵后，SELFDRIVE 的 1.5s 检测 + 回退泵成为双帧源（双倍 advanceFrame），
   已移除；自驱统计输出保留（帧计数经 onAnimationFrame 组合钩子）。
3. **测试 2 设计修正**（首版失败 1 次后修正，见上）：空闲 surface 手动 start 被 surface 自停逻辑
   正确覆盖；改为真实手势→settle→泵完成的集成断言（更强，覆盖 phys-auto-02 卡死路径）。
4. **帧源诚实标注**：60Hz runloop 节拍非 vsync；SELFDRIVE 启动行 + 驱动头注 + 本文件三处声明；
   §2.5 帧节奏目标（60Hz 无 >50ms hitch 等）的自动化回归语义不变，物理门仍归 T-step8 用户复测。

## Memory Candidates

- 本机 NSView.displayLink 零回调是**环境级**（Aqua + idle runloop + common 模式仍零帧）——疑似
  虚拟显示/无 vsync；"无头"误判教训：以 launchctl managername 判 GUI 会话，不以 display link 是否触发判。
- 帧泵自停语义：surface 的 updateAnimationDriver 是 start/stop 唯一权威（空闲自停）；测试手动 start
  驱动必须在动画/待决窗口内才会保持。
- 自驱节奏 0.4s < settle 时长 → 25/40 被接管打断（stale=interruption 1:1）——这是设计行为，
  统计解释须与 fling 节奏关联，不能当缺陷。
