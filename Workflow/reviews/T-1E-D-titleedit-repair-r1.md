# Review: T-1E-D-titleedit-repair — stale `isEditingTitle` after Command-F

- **Reviewer**: Independent Reviewer (round 2, read-only)
- **Task**: T-1E-D-titleedit-repair (repair of T-1E-D MAJOR finding, Reviewer 5d79a69b)
- **Verdict**: **PASS**
- **Date**: 2026-08-30

## Scope reviewed

- Task packet `Workflow/tasks/T-1E-D-titleedit-repair.md`
- Repair result `Workflow/results/T-1E-D-titleedit-repair.md`
- Round-1 review `Workflow/reviews/T-1E-D-r1.md` (MAJOR-1 source)
- Fix: `Sources/PagingPrototypeApp/KeyboardFocusController.swift` (closeFolder reset),
  `Sources/AppGridUI/FolderKeyboardLogic.swift` (new pure-logic seam
  `FolderKeyboardPriority.nextEditingState`), `Tests/AppGridUITests/FolderKeyboardLogicTests.swift`
  (3 new regression tests)

## Verdict

**PASS.** The MAJOR finding is genuinely fixed: `closeFolder()` now resets `isEditingTitle = false`
as its first statement, and both reachable folder-close paths in this task's scope (ESC
`.closeFolder`, Command-F `.closeFolderThenSearch`) route through `closeFolder()`. After search
exits and the keyboard controller regains first responder, `isEditingTitle` is `false`, so
arrows/Return navigate again (not dead). The pure-logic seam correctly models the invariant, the
3 regression tests cover the bug scenario, and all verification commands pass. One MINOR noted
(regression tests exercise the seam, not the actual `closeFolder()` reset — a documented
constraint-driven limitation, not a blocker).

## Findings

### BLOCKER
None.

### MAJOR
None. The round-1 MAJOR-1 is resolved.

### MINOR

1. **Regression tests exercise the pure-logic seam, not the actual `closeFolder()` reset.**
   - `testCommandFDuringTitleEditingResetsEditingFlag` / `testAllFolderCloseActionsResetTitleEditing`
     assert `FolderKeyboardPriority.nextEditingState(...)`, which is a **new** test-only seam
     (`Sources/AppGridUI/FolderKeyboardLogic.swift:125-132`). It is not called by production code;
     `KeyboardFocusController` implements the invariant directly (`closeFolder()` line 282,
     `handleEscape` `.cancelTitleEdit` line 348-349, `clearGridSelection`/`search` untouched).
   - Consequence: if the `isEditingTitle = false` line in `closeFolder()` were reverted while the
     seam and tests were kept, the 3 tests would still pass — they do not guard the actual fix.
   - This is the documented deviation (result doc lines 35-41, 80-83): `AppGridUITests` cannot import
     `PagingPrototypeApp`, `PagingUITests` is forbidden, and `PagingPrototypeAppTests` does not exist
     (Package.swift frozen). The seam is the only testable surface. The actual fix is a one-line
     reset verified correct by inspection, and the seam is verified to match every actual behavior
     (`.closeFolder`/`.closeFolderThenSearch`/`.cancelTitleEdit` → false; `.clearGridSelection`/
     `.search` → preserve). Acceptable; not a blocker.

### QUESTION
None.

## Fix verification (MAJOR genuinely fixed)

- `closeFolder()` (`KeyboardFocusController.swift:281-287`) sets `isEditingTitle = false` as the
  first statement, before `onCloseFolder?()` / `restoreFocusAfterClose()`.
- Both reachable close paths in scope route through `closeFolder()`:
  - ESC with folder open (not editing) → `handleEscape` `.closeFolder` → `closeFolder()` (line 351).
  - Command-F with folder open → `handleCommandF` `.closeFolderThenSearch` → `closeFolder()` +
    `onSearchShortcut?()` (line 363-364).
- Scenario trace: folder open + title editing → Command-F → `performKeyEquivalent` line 167
  `isSearchShortcut` → `handleCommandF()` → `.closeFolderThenSearch` → `closeFolder()` resets
  `isEditingTitle = false` → search field becomes first responder. After search exits and the
  controller regains first responder, `isEditingTitle == false` → `keyDown`/`performKeyEquivalent`
  route arrows/Return to navigation/activation (not `super`). Navigation is alive. **Fixed.**
- No path in scope leaves `isEditingTitle` true after a folder close: title editing only occurs with
  a folder open, so the only Command-F-during-edit path is `.closeFolderThenSearch`, which resets.

## Pure-logic seam correctness

`nextEditingState(editingTitle:action:)` (`FolderKeyboardLogic.swift:125-132`):
- `.closeFolder`, `.closeFolderThenSearch`, `.cancelTitleEdit` → `false` (end editing). Matches
  actual: `closeFolder()` resets; `handleEscape` `.cancelTitleEdit` sets `isEditingTitle = false`.
- `.clearGridSelection`, `.search` → preserve `editingTitle`. Matches actual: `exitKeyboardSelection()`
  and `onSearchShortcut?()` do not touch `isEditingTitle`.
- Invariant correctly modeled: folder-close + cancelTitleEdit end editing; clearGridSelection/search
  preserve.

## Regression tests (3 new, would fail against pre-fix code)

- `testCommandFDuringTitleEditingResetsEditingFlag` (line 164): Command-F with folder open →
  `.closeFolderThenSearch`; `nextEditingState(editingTitle: true, action:)` → `false`; after reset,
  top-level ESC → `.clearGridSelection` (navigation alive). Models the exact bug scenario.
- `testAllFolderCloseActionsResetTitleEditing` (line 177): `.closeFolder`, `.closeFolderThenSearch`,
  `.cancelTitleEdit` all end editing.
- `testNonFolderCloseActionsPreserveEditingState` (line 185): `.clearGridSelection`/`.search`
  preserve editing state.
- Against pre-fix code, `nextEditingState` does not exist → the test file fails to compile (a
  failure). The tests verify the invariant that the fix implements. See MINOR-1 for the seam-vs-
  actual-fix coverage caveat.

## Write scope / frozen trees (verified)

- **Repair write scope exactly 3 files**, all within allowed scope (mtimes 16:42–16:43):
  `KeyboardFocusController.swift` (16:42:55), `FolderKeyboardLogic.swift` (16:42:58),
  `FolderKeyboardLogicTests.swift` (16:43:00).
- `AppSearchController.swift` (16:37:22) and `FolderTitleEditor.swift` (16:37:34) belong to the
  original T-1E-D task (round 1), not this repair — their mtimes predate the repair's 3 files.
- **Frozen trees untouched**: `Package.swift` (08-28 20:42), `AppLaunchController.swift` (08-28
  21:46), `Sources/PagingCore/` (08-30 11:46), `AppCatalogCore/` (08-28 20:50), `MacAppCatalog/`
  (08-28 21:01), `AppIconPipeline/` (08-29 00:22), `PagingTelemetry/` (08-28 21:09), `PagingUI/`
  (08-30 15:15) — all predate the repair.
- **T-1E-B/C files untouched**: `AppGridUIPageContentProvider.swift` (16:28),
  `AppGridSearchPresentationController.swift` (16:26), `AppGridCellView.swift` (16:24),
  `AppGridPageView.swift` (16:20), `FolderOpenState.swift` (16:19), `FolderOverlayView.swift`
  (16:25), `FolderDomain.swift` (16:12) — all predate the repair.

## T-1E-E handoff note (recorded, NOT implemented)

Result doc lines 53-58 record the handoff: the same stale-flag class exists on the other
folder-close paths that are T-1E-E wiring (blank-click close via `onRequestClose`, overlay clear);
**T-1E-E must call `endTitleEditing()` on all folder-close paths**. Explicitly marked as out of
scope for this repair and NOT implemented. Correctly recorded.

## Privacy redline (verified)

- No `addGlobalMonitor` / `addLocalMonitor` / `CGEventTap` / `AXIsProcessTrusted` / `NSEvent.add`
  in the 3 changed files (grep verified).
- No `print` / `NSLog` / `os_signpost` / `PagingTelemetry` / `JSONL` / `FileHandle` / `UserDefaults`
  usage in the 3 changed files (grep verified; only comment mentions of "telemetry/JSONL" in
  `FolderKeyboardLogic.swift` lines 14, 172). No PagingTelemetry schema change (tree frozen).
- No git operations performed by reviewer; no implementation files modified.

## Verification evidence (measured)

- `swift test` (full suite): **744 tests, 0 failures** — XCTest line `Executed 744 tests, with 0
  failures (0 unexpected) in 13.132 (13.178) seconds`. (The swift-testing `0 tests in 0 suites`
  line is NOT the count.) Exit 0. Baseline 741 + 3 new regression tests.
- `swift test --filter FolderKeyboardLogicTests`: **35 tests, 0 failures** (32 + 3 new). Exit 0.
- `swift build -c debug`: **exit 0** (Build complete).
- `swift build -c release`: **exit 0** (Build complete).

## Recommendation

PASS. The MAJOR is fixed and verified. Address MINOR-1 (regression tests guard the seam, not the
actual `closeFolder()` reset) only if a later phase can test through `PagingPrototypeApp` when
Package.swift becomes mutable; it does not block this repair. Ensure T-1E-E implements the recorded
`endTitleEditing()` handoff on all folder-close paths.
