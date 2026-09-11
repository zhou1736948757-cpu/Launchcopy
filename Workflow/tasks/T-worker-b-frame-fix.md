# Task Packet: T-worker-b-frame-fix（帧驱动修复）

- **Task ID**: T-worker-b-frame-fix
- **Role**: Worker（PagingUI 作者）
- **来源**: T-step8 物理复测 #2 FAIL（用户手测仍卡两页中间）
- **日期**: 2026-08-28

## 症状

慢滑/快甩松手后页面卡在两页中间（截图 + telemetry 实证）。

## 证据（phys-auto-02，真实 GUI 会话 = Aqua，非无头）

事件统计：`gesture.momentum 433 / changed 85 / began 13 / ended 13 / transition.begin 2 / stale 2 / interruption 2 / **frame 0**`——**全程零 frame 事件**。

## 根因（Main 已定位）

1. `DisplayLinkFrameDriver.start()` 创建 `NSView.displayLink(target:selector:)` 后**未显式 `add(to:forMode:)`** → 该 API 在此环境（macOS 26.6 / Aqua 会话）零回调（T-step6 误判"无头"，实为驱动未接入 runloop）。
2. 所有动画（settle 插值、momentum glide、T-worker-b-input-fix 的 100ms 自动释放帧检查）都依赖 `advanceFrame` → 帧永不执行 → 慢滑卡死（ended 后零事件且无帧检查）、快甩 settle 只 begin 不推进（transition.begin 2 次、commit 0）。
3. T-step6 的 runloop 回退泵（Timer 60Hz）实测有效（787 帧 @16.67ms），但**仅在 PAGING_PROTOTYPE_GUI_SELFDRIVE=1 下启用**，正常 GUI 运行无回退。

## 修复要求

1. **帧驱动默认可靠**：
   - 优先：`DisplayLinkFrameDriver.start()` 显式 `link.add(to: .main, forMode: .common)`（滚动跟踪期间 runloop 在 eventTracking mode，common 集合保证触发）。注意 CADisplayLink 不能重复加入同一 runloop（会异常）——先确认 NSView.displayLink 返回的 link 是否已自动加入（读 API 语义/实测，避免 double-add）。
   - 兜底：**默认启用 runloop Timer(.common) 60Hz 帧泵**作为驱动（把 T-step6 的 SELFDRIVE 回退泵机制推广为默认帧源），display link 正常时优先 display link；或直接以 Timer 泵为默认并如实标注帧源（runloop 60Hz 节拍 ≈16.67ms，非 vsync 对齐——Phase 1B 再追求 vsync）。方案自选但必须真实有效（真机帧事件 > 0），并在结果中写明选择理由。
   - 启动后 1.0s 内零帧自动切换/确保 Timer 泵生效（防静默）。
2. 保活逻辑（T-worker-b-input-fix 的 `pendingFinishSince`/`updateAnimationDriver`）不变。
3. `PAGING_PROTOTYPE_GUI_SELFDRIVE=1` 自驱冒烟保留并用于真机验证（帧统计 > 0）。
4. 新增/调整测试：帧驱动协议已有（测试注入 nil 手动帧），补充一个"真实驱动冒烟"集成测试可选（不强制；真机验证为主）。既有 148 测试必须全绿。

## Write Scope

- `Sources/PagingUI/PagingFrameDriver.swift`、`Sources/PagingUI/PagingSurface.swift`（如需要）
- `Sources/PagingPrototypeApp/`（如需要默认回退泵接线）
- `Tests/PagingUITests/`、`Tests/PagingUITests`（回归）
- `Workflow/results/T-worker-b-frame-fix.md`

## Forbidden

- `Package.swift`、`Docs/`、`PROVENANCE/`、`Workflow/`（结果文件除外）、`Sources/PagingCore/`、`Sources/PagingTelemetry/`
- §1.3 禁止路径与治理文档

## Verification（真机）

1. `swift build` exit 0；`swift test` 全量 0 failures
2. `PAGING_PROTOTYPE_GUI_SELFDRIVE=1 swift run -c release PagingPrototypeApp --page-count 5 --items-per-page 35 --paging-telemetry --run-id frame-fix-smoke` → 自驱统计帧数 > 0（记录数字）
3. 用户复测：慢滑回弹 / 过半翻页吸住 / 快甩惯性吸住

## Status

- 2026-08-28：Main 定位 display link 零回调；Worker 修复中。
