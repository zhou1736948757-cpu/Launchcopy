# Phase 1C — Keyboard Launch Integration Validation Plan

**Task:** T-1C-C — Return/Enter keyboard launch reusing `AppLaunchController`'s unified
validation pipeline, plus complete AppDelegate wiring (focus model + keyboard controller +
launch adapter).

**Status:** FINAL / MANUAL GUI GATE PASSED (integrated 2026-08-30). AC1–AC9 verified by independent Reviewer r1 + F1
repair r1; **526 tests green** (517 + 9 T-1C-D: deferred focus / ESC / row-end settle / blank-click
classification). AC9 no longer references fabricated coverage — it names the real
settle-reconcile tests; consistency triad asserted in
`testAccessibilityVisualFocusLaunchObjectConsistency` (F2 resolved, per Reviewer r1).
T-1C-D (5 keyboard/window UX changes + blank-click reliability repair) verified by their own
Worker→Reviewer rounds; see §7. On 2026-08-30 the user completed the real full-screen GUI +
physical-keyboard check and reported no issue for the requested keyboard matrix; see §8.

---

## 1. Scope

- Return/Enter on a focused, bound cell launches the app through the **same** validation
  pipeline as a mouse click (`AppLaunchController.handleCell(_:)` → `launch(from:)`).
- No parallel launch path. The keyboard path must not read a cell URL and call `NSWorkspace`
  directly, and must not bypass the stale-revision / AppID / file-existence checks.
- Complete AppDelegate wiring: focus model + keyboard controller + launch adapter.
- Reconcile focus on settle completion/interruption (Reviewer F1) so focus never points to a
  non-displayed page.

## 2. Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| AC1 | Return/Enter on a valid focused cell launches exactly once through `AppLaunchController` | `KeyboardLaunchTests` — assert `RecordingLauncher` opened the app once, outcome `.launched` |
| AC2 | Stale catalog revision is rejected (no launch) | Assert `.rejectedStaleRevision`, launcher not called |
| AC3 | Focused identity with no AppID in current catalog is rejected | Assert `.rejectedMissingApp`, launcher not called |
| AC4 | App file missing on disk is rejected | Assert `.rejectedMissingFile`, launcher not called |
| AC5 | Launch failure is non-fatal (no crash, outcome recorded) | Assert `.failedToLaunch` recorded, no throw |
| AC6 | No focus / empty cell / placeholder does not launch | Assert launcher not called, no outcome side effect |
| AC7 | Mouse click and keyboard share the same validation pipeline | Both funnel through `handleCell`/`handleClick` → `launch(from:)`; assert same outcome for same cell |
| AC8 | No real URL / path / bundleID / app name in telemetry | Assert telemetry JSONL contains only neutral `app.launch` phase event |
| AC9 | Focus reconciled to committed/displayed page after keyboard cross-page settle completion/interruption (F1) | `KeyboardFocusControllerTests.testCrossPageSettleReconcilesFocusToCommittedPage` + `testInterruptedCrossPageSettleReclampsFocusToCommittedPage` — keyboard cross-page turn, settle / interrupt-settle, assert `focusModel.current.pageIndex == surface.core.committedPage` and visual focus lands on the committed page's deterministic target (no stale page mapping). Consistency triad (accessibility-focus / visual-focus / launch-object) asserted in `KeyboardLaunchTests.testAccessibilityVisualFocusLaunchObjectConsistency`. |

## 3. Test Matrix

- `Tests/PagingUITests/KeyboardLaunchTests.swift` (new) — covers AC1–AC8, plus
  `testAccessibilityVisualFocusLaunchObjectConsistency` (AC9 consistency triad, ADDED).
- `Tests/PagingUITests/KeyboardFocusControllerTests.swift` — `testCrossPageSettleReconcilesFocusToCommittedPage`
  + `testInterruptedCrossPageSettleReclampsFocusToCommittedPage` (AC9 F1 settle reconciliation).
- Reuses: `FakeAppFactory`, `wireAssembly`, `makeSurface`, `settleFrames`,
  `flingForwardOnce`/`flingBackwardOnce`, `RecordingLauncher`, `keyEvent(36)` (Return).

## 4. Privacy Redline

- Telemetry must contain **no** app name, bundleID, path, or URL.
- Only a neutral `TelemetryEvent(phase: "app.launch")` is recorded.
- Test asserts the JSONL contains none of the fixture app names / bundle IDs / paths.

## 5. Verification Commands

```sh
swift build
swift test --filter KeyboardLaunch
swift test
```

Gate: `exit_code == 0` AND `executed_tests > 0` (NOT `INVALID_TEST_EXECUTION`).

## 6. Reviewer Focus

- Confirm keyboard launch reuses `AppLaunchController` (no parallel path).
- Confirm F1 reconciliation: focus never points to a non-displayed page after settle
  completion or interruption.
- Confirm privacy redline (no real URL/path/bundleID in telemetry).

## 7. T-1C-D Acceptance (5 keyboard/window UX changes + blank-click reliability)

| # | Criterion | Verification |
|---|-----------|--------------|
| T-D1 | LEFT cross-page row-end: from page-N row-1 first cell, ← lands previous page row-1 LAST cell (not first) even after settle reconcile | `KeyboardFocusControllerTests.testCrossPageLeftSettlePreservesRowEndLanding` + existing `testCrossPageLeft` |
| T-D2 | Deferred focus: no selection box at entry; first arrow seeds current-page row-1 first valid cell, then navigates | `testDeferredFocusNoBoxUntilFirstArrow` |
| T-D3 | ESC exits keyboard-select and visually clears the box (old cell `isFocused == false`); next arrow reseeds | `testEscClearsFocusAndReseedsOnNextArrow` |
| T-D4 | Fullscreen-only: no windowed mode; always `.fullScreenPrimary` | Manual/GUI + log `paging-fullscreen styleMask.fullScreen=true`; no toggle/`--fullscreen` |
| T-D5 | Blank-background single-click quits on the FIRST received click; cell/icon/label click still launches | `BlankClickToQuitTests` (blank/nil/unrelated→not-cell; cell/iconView/nameLabel→cell); GUI manual gate for real first-click reliability |

**Verification commands** (unchanged, now expect ≥526/0):

```sh
swift build
swift test --filter KeyboardLaunch
swift test
```

Gate: `exit_code == 0` AND `executed_tests > 0` (NOT `INVALID_TEST_EXECUTION`).

**Reviewer focus (T-1C-D):** confirm ← row-end preserved after settle; deferred focus does not
reseed on install; ESC clears visual not just model; `QuitOnBlankClickWindow` intercepts only
`.leftMouseDown` (no global `NSEvent` monitor redline) and passes cells through to the frozen
launch recognizer; scrollWheel paging / keyboard nav untouched; forbidden trees unchanged.

## 8. Manual GUI / Physical Keyboard Result (2026-08-30)

| Gate | Result | User evidence |
|------|--------|---------------|
| `MANUAL_KEYBOARD_GUI_GATE` | **PASS_USER_REPORTED_WITH_EVIDENCE** | User tested the relaunched real full-screen app and reported “没有问题” after the requested matrix: arrow navigation and repeated movement, cross-page LEFT row-end landing, deferred-focus first-arrow seeding, ESC visual clear/reseed, and Return/Enter launch. |
| `MANUAL_BLANKCLICK_GUI_GATE` | **PASS_USER_REPORTED_WITH_EVIDENCE** | User had already confirmed the repaired first received blank-background click exits correctly (“OK了，没有问题了”); the final keyboard pass did not report a regression. |

This is a user-reported real GUI acceptance result, not automated evidence and not a claim that
the separate frame-hitch causality investigation is resolved. The diagnostic status remains
`CAUSALITY_UNRESOLVED`; production Timer defaults remain unchanged.
