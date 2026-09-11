# Reviewer Report — T-1C-D-ESC-repair (r2 / re-review)

Phase: 1C follow-up repair
Task: `Workflow/tasks/T-1C-D-ESC-repair.md`
Result: `Workflow/results/T-1C-D-ESC-repair.md`
Role: Independent Reviewer (re-review) — verified from actual code + own test/build runs.
Baseline for forbidden-tree mtime check: `2026-08-30 01:16:08`.
Repair window (Worker session start, per result doc): `2026-08-30 01:26:56`.

---

## VERDICT: **PASS**

The single MAJOR from T-1C-D-r1 (premature `lastAppliedIdentity = nil` defeated the ESC visual clear) is fixed. The new test assertion verifies the visual clear on a real rendered cell and would fail under the old ordering. Full suite green (520/0), both builds exit 0, no scope/regression violations.

---

## 1. ESC visual clear — now correct  ✅ (verified in code)

File: `Sources/PagingPrototypeApp/KeyboardFocusController.swift`

- `exitKeyboardSelection()` (L226–232) — the premature `lastAppliedIdentity = nil` is **gone**:
  ```swift
  226:  private func exitKeyboardSelection() {
  227:      focusModel = AppGridFocusModel(current: nil)
  228:      // 保留 lastAppliedIdentity：applyFocusVisual() 的 nil-current 分支依赖它
  229:      // 对旧 cell 调 setFocused(false) 完成 unhighlight；之后再自清。
  230:      isDeferredSelection = true
  231:      applyFocusVisual()
  232:  }
  ```
  It still does `focusModel = AppGridFocusModel(current: nil)` (L227) + `isDeferredSelection = true` (L230) + `applyFocusVisual()` (L231). ✓

- `applyFocusVisual()` nil-current branch (L211–217) — correctly unhighlights the previously focused cell and self-clears `lastAppliedIdentity`:
  ```swift
  211:  guard let identity = focusModel.current else {
  212:      if let last = lastAppliedIdentity {
  213:          cell(for: last)?.setFocused(false)
  214:      }
  215:      lastAppliedIdentity = nil
  216:      return
  217:  }
  ```
  With `lastAppliedIdentity` preserved into `applyFocusVisual()`, the old cell now receives `setFocused(false)` (L213) and `lastAppliedIdentity` is self-cleared (L215). ✓

Semantics confirmation (read-only): `AppGridUI/AppGridCellFocus.swift` L14-15 `isFocused` = `(layer?.borderWidth ?? 0) > 0`; `setFocused(false)` sets `borderWidth = 0` (L28). So the visual selection box genuinely disappears. The `guard let surface, !isTearingDown` early-return (L209-210) merely no-ops during teardown — irrelevant to the ESC path (surface is active).

## 2. Test assertion added — verifies visual clear (would fail under old ordering) ✅

File: `Tests/PagingUITests/KeyboardFocusControllerTests.swift`, `testEscClearsFocusAndReseedsOnNextArrow` (L299–318):

- Before ESC: `let selectedCell = assembly.renderer.pageView(forPage: 0)?.cell(at: 1)` (L307); pre-confirm `XCTAssertEqual(selectedCell?.isFocused, true, ...)` (L308).
- After ESC, keeps `current == nil` assertion (L311) **and** adds the visual-clear key assertion:
  ```swift
  312:  // 视觉清除：ESC 后旧 cell 的焦点框须真正消失（isFocused == false）。
  313:  XCTAssertEqual(selectedCell?.isFocused, false, "ESC 后旧 cell 焦点视觉清除")
  ```
- Reseed retained (L315–317).

Verified-by-inspection that the new assertion fails under the OLD buggy ordering: the old `exitKeyboardSelection()` set `lastAppliedIdentity = nil` before `applyFocusVisual()`; the nil branch's unhighlight (L212–213) is gated on `if let last = lastAppliedIdentity`, so with it already nil the old cell never gets `setFocused(false)` → `selectedCell.isFocused` (borderWidth) stays `true` → the new assertion fails. Because `isFocused` reflects real `layer.borderWidth` state (not just the model), the assertion is a genuine visual-clear check, not a proxy for `current == nil`. (Noted: reviewer did not mutate sources to re-run the failing build — that is out of scope for the read-only Reviewer role; the assertion's validity is established by the code trace above.)

## 3. Scope / no regression — clean ✅

- Files touched inside the repair window (since `01:26:56`), outside `Workflow/`:
  - `Sources/PagingPrototypeApp/KeyboardFocusController.swift` (01:27:00)
  - `Tests/PagingUITests/KeyboardFocusControllerTests.swift` (01:27:07)
  Only these two → exactly the allowed write scope.
- `Workflow/` changes since `01:26:56`: only bookkeeping (`STATE.json`, `heartbeats.json`, `events.jsonl`, `results/T-1C-D-ESC-repair.md`). Expected.
- Forbidden-tree mtime check since `01:16:08`:
  `find Sources/PagingCore Sources/PagingUI Sources/AppGridUI Sources/MacAppCatalog -type f -newermt "2026-08-30 01:16:08"` → **empty (0 files)**.
  `find Sources/PagingPrototypeApp/AppLaunchController.swift Package.swift -newermt "2026-08-30 01:16:08"` → **empty**. ✓
- `AppDelegate.swift` mtime 01:18:13 is after 01:16:08 but **before** the repair window (01:26:56) — it belongs to the parent T-1C-D implementation, not this repair; untouched by the repair worker.
- Git: repository has **zero commits** (all files untracked), no pushes possible, no tags (`git tag -l` empty). No commit/push/tag performed. ✓
- Production Timer default still 8.333ms: `AppArguments.swift` L128 `frameTimerToleranceMS: nil` (→ `1_000.0/120.0` default, cf. AppArguments L26–27 / AppDelegate L96); repair did not touch any timer code. ✓
- Telemetry untouched: `Sources/PagingPrototypeApp/PagingTelemetryBridge.swift` mtime 08-28 21:47 (pre-repair). ✓

## 4. Measured test count + builds (run by this reviewer, serial) — ✅

| Step | Result |
|------|--------|
| `swift test --filter KeyboardFocusControllerTests.testEscClearsFocusAndReseedsOnNextArrow` | **PASSED (0.072s)** — the ESC test with the new `isFocused == false` assertion |
| `swift test` (full suite) | **Executed 520 tests, with 0 failures** (10.123s) |
| `swift build -c debug` | **exit 0** (Build complete) |
| `swift build -c release` | **exit 0** (Build complete) |

All results measured by the reviewer's own runs (Swift 6.3.3, arm64-apple-macosx26.0).

## 5. Explicit confirmation

**The ESC visual clear now works.** After ESC, the previously focused cell's `AppGridCellFocus.isFocused` becomes `false` (borderWidth → 0), verified both by code (nil-current branch unhighlights last via `setFocused(false)` before self-clearing `lastAppliedIdentity`) and by the passing test assertion `XCTAssertEqual(selectedCell?.isFocused, false)`.

---

## Findings Summary

| ID | Severity | Finding |
|----|----------|---------|
| — | **BLOCKER** | none |
| — | **MAJOR** | none |
| — | **MINOR** | none |
| — | **QUESTION** | none |

## Confidence: High
All three verification lines confirmed from the actual source and the reviewer's own serial test/build runs; scope, forbidden-tree, git, timer, and telemetry checks all clean.
