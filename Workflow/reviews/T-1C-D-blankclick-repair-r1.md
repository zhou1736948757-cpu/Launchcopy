# T-1C-D-blankclick-repair — 独立复核报告 (r1)

- Reviewer: r1（独立 — 从实际代码 + 自身运行核对，不信任 Worker 摘要）
- Reviewed: 2026-08-30
- Spec: `Workflow/tasks/T-1C-D-blankclick-repair.md`
- **VERDICT: PASS**

---

## 0. 结论总览

修复采用 `QuitOnBlankClickWindow: NSWindow` 子类覆盖 `sendEvent(_:)`，对**每次真实 `.leftMouseDown`** 在本窗口内评估命中（`contentView.hitTest` + `blankClickResolvesToCell` 沿 superview 链分类），空白 → 立即 `NSApp.terminate`，命中 cell/icon/label → 原样 `super.sendEvent` 放行给冻结的 cell 启动识别器。机制正确、安全、合规，非全局 monitor，首击可靠。单测 6/6、全量 **526 / 0**、双构建 exit 0。**PASS。**

---

## 1. 逐项核对（file:line 证据）

### F1 — 机制正确 & 安全（PASS）
- 窗口子类仅特判 `.leftMouseDown`，其余事件全部走 `super.sendEvent(event)`（scrollWheel/keyDown/rightMouseDown/mouseMoved 零改动）：
  - `Sources/PagingPrototypeApp/AppDelegate.swift:491` `private final class QuitOnBlankClickWindow: NSWindow`
  - `:495` `override func sendEvent(_ event: NSEvent)`
  - `:496` `if event.type == .leftMouseDown {` — 仅左键按下分支；`:508` `super.sendEvent(event)` 承载所有其余事件。
- 空白实击立即退出：`:498-505` `contentView.hitTest(point)`（`contentView.convert(event.locationInWindow, from: nil)`）→ `blankClickResolvesToCell(hit)` 为 false → `onBlankClick?()` + `return`（不落 mouseUp、无 allowableMovement 门限）。
- 命中 cell/icon/label → fallthrough 到 `super.sendEvent`（`:506-508`），冻结的 cell 启动识别器照常收 mouseDown/mouseUp 而启动。
- 窗口确实被实例化且退出回调接线：`:181` `let window = QuitOnBlankClickWindow(...)`；`:190-192` `window.onBlankClick = { [weak self] in self?.terminateOnBackgroundClick() }`；`:423-425` `terminateOnBackgroundClick() { NSApp.terminate(nil) }`；`:201` `self.window = window`。
- 旧点击识别器方案已彻底移除：grep `Sources` 无 `installBackgroundClickToQuit` / `backgroundClick` 定义（`AppDelegate.swift` 中 `NSClickGestureRecognizer` 仅存在于注释 L416、L483，无代码）。
- 不依赖 `NSClickGestureRecognizer` 的「被识别点击」；退出路径纯 mouseDown 判定。

### F2 — 非红线全局 monitor（PASS）
- grep `Sources`：**无** `NSEvent.addGlobalMonitorForEvents`、**无** `NSEvent.addLocalMonitorForEvents`。相关字样仅出现在注释 `AppDelegate.swift:483`（解释为何非全局 monitor）。
- 拦截点是**本窗口** `sendEvent`（per-window），窗口外/其他 app 完全不触碰 → 红线合规，无需 Accessibility 授权。

### F3 — 首击可靠论证（PASS）
- 每次真实 `.leftMouseDown` 必然经过窗口 `sendEvent` 并对 `.leftMouseDown` 分支评估（`:496-505`），不依赖 `allowableMovement` / mouseUp / 「被识别」。首个非 cell 实击即 `NSApp.terminate`。
- 残余窗口（spec 已认可）：全屏过渡（0.3s 延迟 + 约 1s 动画）内点击可能被 window server 在到达窗口前丢弃，应用内无法收到 → 属瞬时、应用不可修复，非缺陷。

### F4 — 单测（PASS）
`Tests/PagingUITests/BlankClickToQuitTests.swift` 覆盖：
- 空白/非 cell → 走退出：`testBlankRootIsNotCell`（L30）、`testBlankNilIsNotCell`（L35，`nil` hit）、`testUnrelatedNestedViewIsNotCell`（L39）。
- cell/icon/label → 放行：`testCellItselfIsCell`（L48）、`testCellIconSubviewIsCell`（L53，`cell.iconView`）、`testCellNameLabelSubviewIsCell`（L59，`cell.nameLabel`）。
- 无头安全：纯 `NSView` 层次构造 + superview 链判定，不建窗口/不走手势/不触发退出/无副作用。实测 `swift test --filter BlankClickToQuitTests` → **6 tests, 0 failures**。
- `AppGridCellView` 公开属性 `iconView`/`nameLabel` 确认存在（`Sources/AppGridUI/AppGridCellView.swift:18,20`），`AppGridCellView` 为 `public final`（同文件 L12）。

### F5 — 范围 / 禁止树（PASS）
- 禁止树逐文件 mtime：重新生成的 `Sources/PagingCore|PagingUI|AppGridUI|MacAppCatalog` 全量列表与基线 `frozen_before.txt` **diff 为空**（38 个文件逐一相同）→ 修复期间未变。
- `Package.swift` md5 = `50998b66f34c68d3a842ebc9ae8432ec`（与 Worker 报告一致，未变）。
- `Sources/PagingPrototypeApp/AppLaunchController.swift` mtime `1787921214`（与报告一致；冻结文件；cell `NSClickGestureRecognizer` 在 L95-96 原样，`public func install()` L93-98 未动）。
- git：分支 `main` **无任何 commit**（`git log` fatal: no commits yet）、无 tag → 无 commit/push/tag。
- Timer tolerance 未动：`AppDelegate.swift:98` `?? (1.0 / 120.0)` = 8.333ms。
- telemetry：本修复未新增任何 telemetry 调用（grep 无新记录点）。
- 本修复写窗口 = 仅 `AppDelegate.swift`（01:49:55）+ `BlankClickToQuitTests.swift`（01:50:04）。
  - 备注（非发现）：`Sources/PagingPrototypeApp/KeyboardFocusController.swift`（01:27:00）与 `KeyboardFocusControllerTests.swift`（01:27:07）mtime 晚于 01:16:08 基线，但早于本修复写窗口 22 分钟、且不在禁止树内 → 属先前 T-1C-B/C 任务产物，本修复未触碰。

### F6 — 自测（PASS）
串行执行（规避 SwiftPM 构建锁）：
| 项 | 结果 |
|---|---|
| `swift test`（全量） | **526 tests, 0 failures**，exit 0（≥ spec ≥526，基线 520 说明见下）|
| `swift test --filter BlankClickToQuitTests` | **6 tests, 0 failures** |
| `swift build -c debug` | **exit 0** |
| `swift build -c release` | **exit 0** |

> 注：全量 526 中包含 PagingUITests.KeyboardFocusControllerTests 等既有测试；BlankClickToQuitTests 贡献其中 6 个，均已运行并通过。

---

## 2. 明确确认（验收 3 要点）

- **(a) 空白单击在 app 自身收到的首次点击即退出**：确认。首个 `.leftMouseDown` 落在非 cell 区域 → hitTest 分类为空 → 当次按下即 `NSApp.terminate`（不需要 mouseUp/识别），正是症状根因（稳态连点 2–3 次）的根治点。
- **(b) scrollWheel 翻页 / 键盘导航 / cell 启动不坏**：确认。`sendEvent` 只拦截 `.leftMouseDown`，scrollWheel/key 事件直接 `super.sendEvent` → `PagingSurface.scrollWheel(with:)`（`PagingSurface.swift:310`，冻结未动）与 `KeyboardFocusController` 事件路由原样；cell 命中放行 → `AppLaunchController.swift` L95-96 的 cell 识别器照常收到成对 mouseDown/mouseUp 而启动。空白与 cell 分支在窗口层严格互斥。
- **(c) 无全局事件 monitor 红线**：确认。为**本窗口** `sendEvent` 逐窗口拦截，非 `NSEvent.addGlobalMonitorForEvents`。

---

## 3. 给 Main 的最终消息

**VERDICT: PASS** — 实测 `swift test` = **526 tests, 0 failures**（含 `BlankClickToQuitTests` 6/6）；`swift build -c debug` / `-c release` 均 **exit 0**。机制（窗口级 `sendEvent` 每次 leftMouseDown 评估→空白首击即退）正确且无全局-monitor 红线；cell 启动、scrollWheel 翻页、键盘导航经代码路径核对零回归；禁止树 mtime/哈希、Package.swift、AppLaunchController、Timer 8.333ms、telemetry 全部核验未变；git 无 commit/tag。BLOCKER=0, MAJOR=0, MINOR=0。唯一残余 = spec 认可的全屏过渡~1s 内 window server 吞点击（不可应用修复），非缺陷。可交 Main 重建重开 app 供用户实测。
