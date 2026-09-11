# Task Packet: T-worker-b-input-fix（真实输入释放决策修复）

- **Task ID**: T-worker-b-input-fix
- **Role**: Worker（PagingUI 作者）
- **来源**: T-step8 首次真实触控板物理验收 FAIL（用户手测）
- **日期**: 2026-08-28

## 症状（用户原话）

"可以滑，但是滑了以后不会自己停下来，也没有回弹，它会按照我的这个滑动滑"——跟手正常，但释放后**无任何释放决策**：不回弹、不翻页、不吸住（滚筒式自由滑动）。

## 根因（Main 已定位）

`Sources/PagingUI/PagingSurface.swift` `.gestureEnded` case（:318-321）仅置 `needsFinish = true`，真正的 `core.finishGesture()` 依赖**下一事件**触发（新 began / momentumBegan / 任何输入 / finishPendingGesture）。真实触控板**慢滑释放后没有任何下一事件** → Core 永远停在 tracking(released)，visualOffset 冻结在手指释放位置。合成事件测试都有显式后续事件，所以全绿——真实输入路径漏洞。

## 修复方向（Main 建议，Worker 可优化并说明理由）

- `gestureEnded` 时记录 `pendingFinishSince = now`（needsFinish 置 true 同处）。
- 在 `advanceFrame(deltaTime:)`（display link 每帧驱动，不受 runloop mode 影响）内检查：`needsFinish && now - pendingFinishSince >= 阈值(建议 100ms) && 期间无 momentumBegan` → 调 `core.finishGesture()`、清 needsFinish/pendingFinishSince。
- 取消条件：momentumBegan（进入 momentum 流程）/ 新 gestureBegan / 任何输入事件 / gestureCancelled / teardown。
- 阈值理由：快甩的 momentum 事件在 ended 后 1–3 帧内到达（<50ms）；100ms 不误伤 fling 速度且用户感知及时（系统级回弹/吸住手感）。
- 也可用 Timer + RunLoop common modes 实现，二选一并在结果里写明理由（倾向帧驱动：与 settle 同一驱动、滚动跟踪 runloop mode 下仍触发）。

## Write Scope

- `Sources/PagingUI/PagingSurface.swift`
- `Tests/PagingUITests/`（回归测试）
- `Workflow/results/T-worker-b-input-fix.md`（结果文件）

## Forbidden

- `Package.swift`、`Docs/`、`PROVENANCE/`、`Workflow/`（结果文件除外）、其余 Sources/Tests
- §1.3 禁止路径与治理文档

## Verification

- `swift build` exit 0；`swift test` 全量 0 failures
- 新增回归测试：**ended 后无任何后续事件 → 推进 N 帧（≥阈值）→ 断言释放决策发生**（回弹或翻页 + commit 计数）；同时保留"ended 后有 momentumBegan"不误伤路径的测试

## Status

- 2026-08-28：Main 定位根因；Worker 修复中。
