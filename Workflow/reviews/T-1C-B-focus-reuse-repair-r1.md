# Review: T-1C-B-focus-reuse-repair — 复用路径焦点视觉重置（Reviewer F2 MINOR）

- **Reviewer**: independent (read-only)
- **Date**: 2026-08-29
- **Verdict**: **PASS**
- **Review revision**: r1
- **Source finding**: `Workflow/reviews/T-1C-B-r1.md` F2 (MINOR)

## Scope reviewed

The actual diff (repair window 2026-08-29 22:51–22:53):
- `Sources/AppGridUI/AppGridCellView.swift` — `clearContent()` 末尾新增 `setFocused(false)`（mtime 22:51:53）
- `Tests/AppGridUITests/AppGridCellFocusReuseTests.swift` — 新增 3 个测试（mtime 22:53:00）

Claimed NOT modified (verified):
- `Sources/AppGridUI/AppGridPageView.swift` — mtime 08-28 21:25:23，未变 ✅

Read-only reference (verified untouched):
- `Sources/AppGridUI/AppGridCellFocus.swift` — mtime 22:44:48（早于修复窗口）✅
- `Sources/AppGridUI/AppGridFocusModel.swift` (22:35:00), `AppGridFocusNavigator.swift` (22:35:05), `AppGridFocusIdentity.swift` (22:34:48), `AppGridFocusLayout.swift` (22:34:56) — 全部早于修复窗口 ✅

## Verification executed (independent, not trusting Worker summary)

| Command | Exit | Executed | Passed | Failed |
|---|---|---|---|---|
| `swift test --filter AppGridCellFocusReuseTests` | 0 | 3 | 3 | 0 |
| `swift test --filter AppGridUITests` | 0 | 77 | 77 | 0 |
| `swift test`（全量） | 0 | 504 | 504 | 0 |

`exit_code == 0` 且 `executed_tests == 504 > 0` → **valid test execution**（非 INVALID_TEST_EXECUTION）。Worker 声称的 3/3、77/77、504/504 全部独立复现。

## Acceptance criteria — per-criterion result

| Criterion | Result | Evidence |
|---|---|---|
| 聚焦 cell 被 `clearContent` 回收后，焦点视觉（border/background + accessibility focus）被重置 | ✅ | `AppGridCellView.swift:77` `clearContent()` 调用 `setFocused(false)`；`setFocused(false)`（`AppGridCellFocus.swift:27–32`）清 layer borderWidth/borderColor/backgroundColor 并 `setAccessibilityFocused(false)`。`testClearContentResetsFocusVisual` 断言 `isFocused == false` 且背景恢复 `controlBackgroundColor` |
| `clearForReuse` 路径下无残留焦点视觉 | ✅ | `AppGridPageView.swift:140` `clearForReuse()` → `clearCells()`（:185–187）→ `cell.clearContent()`（:186）。`testClearForReuseResetsFocusedCell` 断言回收后 `isFocused == false` |
| 键盘路径（显式 unhighlight）不回归 | ✅ | 未改焦点模型/导航；`AppGridFocus*.swift`/`AppGridCellFocus.swift` 只读未动。全量 504 测试（含 PagingUITests 键盘路径）0 失败 |
| 新增测试覆盖复用残留场景 | ✅ | 3 个测试：clearContent 重置、clearForReuse 重置、复用后重绑不继承旧焦点 |

## Constraints verified

- **焦点模型/导航逻辑未改**：只改 `clearContent` 复用路径视觉；`AppGridFocus*.swift`、`AppGridCellFocus.swift` mtime 均早于修复窗口（22:34–22:44 < 22:51）。
- **无全局监听 / 权限 / 同步 I/O**：对两个改动文件 grep `NSEvent|addGlobalMonitor|addLocalMonitor|AXIsProcessTrusted|AXUIElement|FileManager|Data(contentsOf|NSWorkspace|UserDefaults|NotificationCenter|DispatchQueue|sleep` → CLEAN。
- **命名中性 / 隐私**：无 app 名/bundleID/path/URL/icon 数据字面量。测试用 fixture ID（`fixture.alpha`/`fixture.beta`/`fixture.gamma`），程序生成图像，绝不触碰真实 `/Applications`（仅注释声明）。
- **无 conflict markers / trailing whitespace**（grep clean）。

## Forbidden trees untouched

无 git baseline（全部 untracked），用 mtime 验证。修复窗口 22:51–22:53 内仅 2 个文件被改（`AppGridCellView.swift` 22:51:53、`AppGridCellFocusReuseTests.swift` 22:53:00）。全部禁止树早于窗口：

- `Sources/PagingCore/` — mtimes 08-28 → 08-29 21:16:35 ✅
- `Package.swift` — 08-28 20:42:55 ✅
- `Docs/` — 最新 08-29 22:35:46（ADR-006，早于窗口）✅
- `PROVENANCE/` — 最新 08-29 21:29:59 ✅
- `Tests/PagingUITests/`、`Tests/PagingCoreTests/` — 无文件晚于 22:50 ✅
- `Sources/PagingUI/`、`Sources/PagingPrototypeApp/` — 最新 22:44:55（Worker B 原窗口，早于修复窗口）✅

## Findings

### F1 — MINOR: accessibility focus 断言为间接（视觉状态代理）
- **Location**: `Tests/AppGridUITests/AppGridCellFocusReuseTests.swift:36–37`。
- **Observation**: `NSView` 无 Swift 可见的 `accessibilityFocused()` getter（`setAccessibilityFocused` 为 `@objc` 方法，读取 API 已废弃），故测试以视觉状态（`isFocused` = layer borderWidth、背景色）断言 `setFocused(false)` 确实执行；accessibility focus 的清空由 `setFocused(false)` 内 `setAccessibilityFocused(false)` 保证（`AppGridCellFocus.swift:31`，代码审查确认，未改）。
- **Impact**: 测试质量小缺口；代码路径正确，不影响验收。
- **Recommendation**: 可选 — 若需直接断言 accessibility focus，可引入 `NSAccessibility` 读取或 mock；当前间接断言可接受。

### F2 — QUESTION: 同页 refresh 复用路径下焦点由控制器重放
- **Location**: `AppGridPageView.swift:181`（`prepareCells` 复用 cell 时调用 `clearContent`）。
- **Observation**: 同页 re-render（refresh）复用 cell 时 `clearContent` 也会清焦点视觉；键盘控制器在 render 后经 `refreshFocusVisual()` 重放焦点，故焦点恢复。非键盘 refresh 路径下聚焦 cell 被清焦点视觉符合 §4.3 意图。
- **Impact**: 无缺陷；与设计一致（焦点视觉不因复用残留到错误 app）。
- **Recommendation**: 无需处理；记录为设计行为。

## Likely root cause

F2 原缺陷：`clearContent`/`clearForReuse` 清 token/name/icon/accessibility 但未清 layer border/background，导致非键盘页面切换（trackpad fling、refresh）回收的聚焦 cell 在另一 app 上残留旧焦点边框。修复在 `clearContent` 末尾调用 `setFocused(false)`，从根上覆盖所有复用路径（`clearForReuse`→`clearCells`→`clearContent`、`prepareCells` 复用、placeholder `render`→`clearCells`）。

## Recommended solution

已实现且正确。无需进一步修改。

## Affected scope

- `Sources/AppGridUI/AppGridCellView.swift`（`clearContent` 加一行 `setFocused(false)`）
- `Tests/AppGridUITests/AppGridCellFocusReuseTests.swift`（新增 3 测试）
- 无 `PagingCore`、`Package.swift`、`Docs/`、`PROVENANCE/`、他人 test 目录改动。

## Regression risks

- 低。全量 504 测试 0 失败；debug build 通过；禁止树未触碰；无全局监听/权限/同步 I/O。
- 唯一行为变化：任何 `clearContent` 调用现在会清焦点视觉。键盘路径由控制器在 render 后重放焦点，无回归；非键盘路径正是修复目标。

## Confidence

高。修复逻辑经代码审查 + 独立测试执行（3/3、77/77、504/504 全绿）双重确认；禁止树完整性经 mtime 验证；约束/隐私扫描 clean。

## Verdict

**PASS**
