# T-1E-D-titleedit-repair — stale `isEditingTitle` after Command-F

- **Task ID**: T-1E-D-titleedit-repair
- **Role**: Worker (repair of T-1E-D MAJOR finding, Reviewer 5d79a69b)
- **Phase**: 1E — repair
- **ADR**: ADR-008 (ACCEPTED) §3 Q10/Q11/§8.1
- **Status**: IMPLEMENTED (verification complete)

## Objective

Fix the MAJOR finding: Command-F during title editing leaves `isEditingTitle` stale, so after
search exits and the keyboard controller regains first responder, arrows/Return fall through to
`super` and navigation is dead until ESC.

## Root cause (from Reviewer)

`KeyboardFocusController.performKeyEquivalent` handles Command-F **before** the `isEditingTitle`
guard, and `closeFolder()` did **not** reset `isEditingTitle`. After search exits, the stale flag
kept routing arrows/Return to `super`.

## Fix

- **`Sources/PagingPrototypeApp/KeyboardFocusController.swift`** — `closeFolder()` now resets
  `isEditingTitle = false` as the first statement. `closeFolder()` is the single source of truth
  for folder-close state, so both reachable folder-close paths in this task's scope are covered:
  - ESC with folder open (not editing) → `.closeFolder` → `closeFolder()`
  - Command-F with folder open → `.closeFolderThenSearch` → `closeFolder()`
- **`Sources/AppGridUI/FolderKeyboardLogic.swift`** — added pure-logic seam
  `FolderKeyboardPriority.nextEditingState(editingTitle:action:) -> Bool`:
  folder-close actions (`.closeFolder`, `.closeFolderThenSearch`) and `.cancelTitleEdit` end
  title editing (→ false); `.clearGridSelection` / `.search` preserve it. This makes the
  stale-flag invariant testable from `AppGridUITests` (which cannot import `PagingPrototypeApp`).
- **`Tests/AppGridUITests/FolderKeyboardLogicTests.swift`** — 3 regression tests (see below).

### Why a pure-logic seam (not testing through KeyboardFocusController)

`AppGridUITests` depends only on `["AppGridUI", "PagingUI", "AppCatalogCore", "AppIconPipeline"]`
(Package.swift) and cannot import `PagingPrototypeApp`; `PagingUITests` is forbidden for this task
and `PagingPrototypeAppTests` does not exist (Package.swift frozen). The AppKit responder behavior
(arrows/Return actually navigating after the flag reset) is therefore covered by the flag-reset
invariant via the pure-logic seam, which is the root-cause fix.

## Regression tests (3 new)

1. `testCommandFDuringTitleEditingResetsEditingFlag` — Command-F with folder open →
   `.closeFolderThenSearch`; `nextEditingState(editingTitle: true, action:)` → `false`; after reset,
   top-level ESC → `.clearGridSelection` (navigation alive, not dead).
2. `testAllFolderCloseActionsResetTitleEditing` — `.closeFolder`, `.closeFolderThenSearch`,
   `.cancelTitleEdit` all end title editing.
3. `testNonFolderCloseActionsPreserveEditingState` — `.clearGridSelection` / `.search` preserve
   editing state.

## T-1E-E note (NOT implemented here)

The same stale-flag class exists on the other folder-close paths that are **T-1E-E wiring**:
blank-click close (`onRequestClose`) and overlay clear. **T-1E-E must call
`endTitleEditing()` on all folder-close paths** so the editing flag is reset whenever the open
layer closes. This is out of scope for T-1E-D-titleedit-repair and is NOT implemented here.

## Verification (measured)

- `swift test` full suite: **744 tests, 0 failures** — XCTest line `Executed 744 tests, with 0
  failures (0 unexpected) in 13.622s`. (The swift-testing `0 tests in 0 suites` line is NOT the
  count.) Baseline 741 + 3 new regression tests; all existing tests still pass.
- `swift test --filter FolderKeyboardLogicTests`: **35 tests, 0 failures** (32 + 3 new).
- `swift build -c debug`: **exit 0** (Build complete).
- `swift build -c release`: **exit 0** (Build complete).
- **Frozen trees untouched** (mtime check): `Package.swift` (08-28 20:42), `AppLaunchController.swift`
  (08-28 21:46), `Sources/PagingCore/` (08-30 11:46), `AppCatalogCore/` (08-28 20:50),
  `MacAppCatalog/` (08-28 21:01), `AppIconPipeline/` (08-29 00:22), `PagingTelemetry/` (08-28 21:09),
  `PagingUI/` (08-30 15:15) — all unchanged. T-1E-C files (`AppGridCellView.swift` 16:24,
  `AppGridPageView.swift` 16:20, `FolderOpenState.swift` 16:19, `FolderOverlayView.swift` 16:25)
  unchanged.
- **Write scope exactly 3 files**, all within allowed scope: `KeyboardFocusController.swift`,
  `FolderKeyboardLogic.swift`, `FolderKeyboardLogicTests.swift` (mtimes 16:42–16:43).
- **No git operations** performed.

## Deviations

- Regression test is expressed through a pure-logic seam in `FolderKeyboardLogic.swift` rather
  than directly through `KeyboardFocusController`, because `AppGridUITests` cannot import
  `PagingPrototypeApp` (see justification above). The AppKit responder glue change is minimal
  (one line in `closeFolder()`).

## Privacy

- No folder title / membership / identity raw values in telemetry/JSONL/stdout/signpost/profile/
  report; only neutral counters and decision enums. No PagingTelemetry schema change. No global
  NSEvent monitor / Accessibility / Input Monitoring.
