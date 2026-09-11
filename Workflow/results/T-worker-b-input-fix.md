# T-worker-b-input-fix — 真实输入释放决策修复（物理门 FAIL 触发的最高优先级修复）

**Worker**: B/D 同人（PagingUI 作者）
**来源**: T-step8 首次真实触控板物理验收 FAIL（用户手测："可以滑，但是滑了以后不会自己停下来，也没有回弹，它会按照我的这个滑动滑"）
**日期**: 2026-08-28
**Scope**: `Sources/PagingUI/PagingSurface.swift`、`Tests/PagingUITests/PagingSurfacePendingFinishTests.swift`（新）、`Workflow/results/T-worker-b-input-fix.md`
**未触碰**: Package.swift / Docs / PROVENANCE / Workflow（结果文件除外）/ PagingCore / PagingTelemetry / 其他 Sources
**AccessDeclaration: NO_PRIOR_EXPOSURE**（重申：未读取 §1.3 禁止路径与治理文档；本任务零外部来源接触）

---

## 根因确认（复读代码核实，与 Main 定位一致）

`PagingSurface.apply()` `.gestureEnded` 原实现（:318-321）只置 `needsFinish = true` 并调用
`core.handleGesturePhase(.ended)`（Core 侧仅 `session.markReleased()`）；真正的释放决策
`core.finishGesture()`（`PagingCore.swift:161`，要求 `state == .tracking` + 会话存在，决策 → beginSettle）
依赖**下一事件**（新 began / momentumBegan / finishPendingGesture / legacyScroll）触发。

- 真实触控板慢滑：`.ended` 后无 momentum 事件（速度低于系统 momentum 阈值）→ **没有任何下一事件**
  → Core 永久停在 tracking(released)，`visualOffset` 冻结在手指释放位置 → 不回弹/不翻页/不吸住。
- 合成测试全绿的原因：TestSupport 所有 fling 路径都显式发送了 `finishPendingGesture`，未覆盖
  "ended 后零事件"路径。**物理门存在的意义得到验证。**
- 补充确认：`core.tick` 对 tracking(released) 非 momentum 会话是 no-op；`isAnimating` 在
  tracking(released) 为 false → **ended 后驱动已停**，故自动释放必须同时让 display link 在待决窗口内运行。

## 修复实现（帧驱动方案，理由见下）

`Sources/PagingUI/PagingSurface.swift`：

1. **待决状态**：新增 `pendingFinishSince: TimeInterval?`（ended 时刻，internal 只读供测试断言）、
   `pendingFinishThreshold: TimeInterval = 0.1`（内部可调）、
   `pendingFinishTimeSource: () -> TimeInterval`（默认 `ProcessInfo.processInfo.systemUptime`，
   与 NSEvent.timestamp 同基的单调时钟；测试注入合成时钟 → 完全确定性、零真实等待）。
2. **`.gestureEnded`**：`needsFinish = true` 同处记录 `pendingFinishSince = timeSource()`。
3. **`advanceFrame`**：帧首检查 `needsFinish && now - pendingFinishSince >= 0.1` →
   `clearPendingFinish()` + `core.finishGesture(timestamp: since)`（timestamp 用 ended 时刻，
   释放速度语义与 finishPendingGesture 路径一致）。**在 tick 之前**执行，让决策当帧生效。
4. **驱动保活**：`updateAnimationDriver()` 条件从 `core.isAnimating` 扩为
   `core.isAnimating || pendingFinishSince != nil` —— 否则 ended 后驱动已停、advanceFrame 永不触发
   （这是修复在真实 app 生效的关键一环）。
5. **取消/清理点（全部）**：新 `clearPendingFinish()`（清 needsFinish + pendingFinishSince）——
   `.gestureBegan`（先 finishGesture 再清）、`.momentumBegan`（momentum 接管；保留
   `hadPendingFinish` 防御分支）、`.gestureCancelled`、`.finishPendingGesture`、`.legacyScroll`、
   `teardown()`（§7.3：teardown 后零回调门禁——待决释放不得在关闭后触发）。
   刻意**不在 `.gestureChanged` 清理**：Core `handleChanged` 拒绝 released 会话（`!session.released`
   守卫，PagingCore.swift:427），零效果；保持窗口存活让随后的真实 ended 重设窗口。

**阈值选择（100ms）理由**：真实快甩的 momentum 事件流在 ended 后 1–3 帧内到达（<50ms），
100ms 窗口绝不误伤 fling（测试 B 实证）；慢滑释放后 100ms 内自动回弹/吸住，用户感知及时。
**帧驱动 vs Timer 的理由**：滚动跟踪期间 runloop 停在 eventTracking mode，`Timer`（含 .common）
在部分真实场景不触发；display link 与 settle 同源（PagingFrameDriver 头注：macOS 14+ CADisplayLink，
主 runloop common 模式），且复用 `advanceFrame` 单帧入口（零新增回调面）。

## 回归测试（`Tests/PagingUITests/PagingSurfacePendingFinishTests.swift`，+4）

| 测试 | 场景 | 断言 |
|---|---|---|
| `testEndedWithNoFurtherEventsAutoFinishes`（A） | began→changed(400px@0.5s)→ended→**零后续事件**→帧推进 | 窗口未满保持 tracking；期满 → settle(reason=.gestureRelease)、needsFinish/pendingFinishSince 清空 → 翻页 commit 1 → idle |
| `testEndedAtBoundaryAutoFinishBouncesBack`（A2） | 首页越界慢滑 → 自动释放 | 回弹：settle → commit 0（同页）、visualOffset=0 |
| `testMomentumWithinWindowNotClobbered`（B） | 快甩 ended → 0.52s momentumBegan（窗口内）→ 时钟拨到 5.0 + 推帧 | pending 被 momentum 接管清除；推进帧无提前 finish/commit、momentum 会话存活；momentumEnded → glide（1000px/s>40px/s）→ 滑行耗尽 → commit 1（**fling 速度未丢**） |
| `testTeardownClearsPendingAndZeroCallbacks`（C） | ended → teardown → 时钟 5.0 + 推帧 | pending/needsFinish 清空；onCommit/onStateChange/onVisualOffsetChange **零回调**；staleRejection=0（§7.3 门禁不回归） |

合成时钟注入（`pendingFinishTimeSource`）使全部断言确定性，无真实等待。

## Verification（命令 + 退出码）

| 命令 | 结果 |
|---|---|
| `swift build`（全包） | exit 0（0 warning） |
| `swift test --filter "PagingSurfacePendingFinishTests"` | 4 tests, 0 failures, exit 0 |
| `swift test`（全量） | **148 tests, 0 failures**（144 → +4），exit 0 |

## Changed Files

| 文件 | 变更 |
|---|---|
| `Sources/PagingUI/PagingSurface.swift` | 待决释放状态（since/threshold/timeSource）；gestureEnded 记录 since；advanceFrame 自动 finishGesture；updateAnimationDriver 待决窗口保活；clearPendingFinish 于 6 个取消点；teardown 清理 |
| `Tests/PagingUITests/PagingSurfacePendingFinishTests.swift` | 新增 A/A2/B/C 4 个回归测试 |
| `Workflow/results/T-worker-b-input-fix.md` | 本文件 |

## Deviations

1. **驱动保活是本修复的必需第三件**（任务方向只提 advanceFrame 检查）：ended 后 `isAnimating`=false，
   驱动已停 → 无帧 → 检查永不执行。已通过 `updateAnimationDriver` 的 `pendingFinishSince != nil`
   条件解决；窗口期满自动 finish 后若决策为即时提交则驱动立即停止（无空转）。
2. **`.gestureChanged` 不清理待决**（任务列的"任何输入事件"中该路径刻意豁免）：Core 对 released
   会话的 changed 返回 false（零效果），清理反而会让"手指未真正抬起"的畸形序列失去自动释放兜底；
   新 began/momentum 路径（真正接管者）全部清理。已在代码注释说明。
3. **测试 C 计数归零**：onStateChange/onVisualOffsetChange 在跟踪期间正常触发（idle→tracking、
   changed 偏移），断言前归零，只测 teardown 后的新增回调。
4. **时钟注入**：任务建议"推进 N 帧"——真实时钟下测试循环 µs 级完成、真实时间不流逝，无法满足
   ≥100ms 窗口；改为可注入时间源（生产默认 systemUptime 不变），语义等价的确定性验证。

## Memory Candidates

- 真实触控板 ended 后**没有** momentum 事件（慢滑）→ 释放决策必须由 UI 自行触发；
  "下一事件触发 finish"（Worker B 偏差 #1）在真实输入下是漏洞——合成事件测试无法覆盖。
- 物理门（T-step8）是合成回归测不到的真实路径：ended→零事件是首个被物理门抓到的 bug。
- 帧驱动在 ended 后已停止（isAnimating=false）→ 任何"帧内自动动作"都需同步保活驱动。
- Core `handleChanged`/`handleEnded` 均要求 `!session.released`（PagingCore.swift:427,433）——
  released 会话只接受 momentum 与 finish。
- momentum 滑行阈值 = velocityThreshold × glideStopFraction（800×0.05=40px/s）。
