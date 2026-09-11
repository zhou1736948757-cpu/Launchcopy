# T-1E-folder-mouse-open-repair — Review r1

- Verdict: **PASS**
- Reviewer: independent (read-only; no implementation/test/result files modified)
- Reviewed: 2026-08-30

## Static verification (code on disk)

1. `KeyboardFocusController.openFolderFromClick(_ folderID:)` (Sources/PagingPrototypeApp/KeyboardFocusController.swift:285-294) exists and performs, in order: `openedFolderIdentity = .folder(folderID)`, `innerFocusIndex = 0`, `focusModel = AppGridFocusModel(current: nil)`, `applyFocusVisual()`, `onOpenFolder?(synthetic AppGridFocusIdentity with entryIdentity = .folder(folderID))`, then `applyInnerFocusVisual()` AFTER `onOpenFolder` (overlay configured → memberCells exist). ✓
2. Keyboard path `openFolder(_ identity:)` (:269-276) now also calls `applyInnerFocusVisual()` after `onOpenFolder?(identity)` — both paths show the inner ring on member 1 immediately. ✓
3. `handleInnerArrow` (:330-344), `applyInnerFocusVisual` (:356-363), `closeFolder` (:302-308) semantics unchanged (FolderInnerNavigator move / overlay memberCell setFocused / close + restore). ✓
4. `AppDelegate.handleFolderCellClick(folderID:)` (:559-561) routes through `keyboardController?.openFolderFromClick(folderID)`; `openFolder(folderID:)` (:544-549) kept as state+overlay primitive, still reached via `onOpenFolder` → `openFolder(_ identity:)` (:537-540). Production wiring `installFolderWiring` (:436-438, :465-470) consistent: renderer.onFolderClick → handleFolderCellClick; onOpenFolder → openFolder(identity); state/overlay providers wired. ✓
5. Tests (Tests/PagingUITests/FolderIntegrationTests.swift):
   - (a) `testMouseOpenClearsOuterRingAndShowsInnerRing` (:543-573): outer focus set → click → `focusModel.current == nil` AND `memberCell(at:0)?.isFocused == true`. ✓
   - (b) `testKeyboardOpenShowsInnerRingOnMemberOne` (:575-598): keyboard-open (Return) → inner ring on member 1. ✓
   - (c) `testMouseOpenThenRightArrowMovesInnerRing` (:600-624): click-open then right-arrow → ring at `memberCell(at:1)`, member 0 unfocused. ✓
   - (d) Existing click-open tests (`testFolderCellClickOpensViaRendererSeam` :400-445, `testFolderCellClickOpensImmediately` :447-489) rewired through `makeFolderSeam` (:378-398: onFolderClick → keyboard.openFolderFromClick; onOpenFolder → open state + overlay configure; providers wired); click still opens immediately. ✓
6. Write scope respected: only KeyboardFocusController.swift (20:55:46), AppDelegate.swift (20:55:49), FolderIntegrationTests.swift (20:56:27) modified. All frozen trees (Package.swift, PagingCore, AppCatalogCore, MacAppCatalog, AppIconPipeline, PagingTelemetry, PagingUI, AppLaunchController.swift) have mtimes predating the changed files. FolderOverlayView.swift (20:55:25) predates the worker's files and is owned by the parallel task — not part of this review. ✓
7. No git ops performed. No privacy leaks: review contains neutral counters only. ✓

## Dynamic verification (run serially)

- `swift build -c debug` → exit 0 (Build complete).
- `swift test` → **Executed 772 tests, 0 failures (0 unexpected)**, exit 0. Real executed count > 0 (not INVALID_TEST_EXECUTION). 772 = baseline 767 + 3 (this task) + 2 (parallel task), matching expectation.
- `swift build -c release` → exit 0 (Build complete).

## Findings

- None blocking. The fix matches the spec exactly: mouse-open now clears the outer ring, initializes inner focus state, and shows the inner ring on member 1 immediately; left/right arrows navigate members after mouse-open (verified by test (c)).
- Minor note (non-blocking): `openFolderFromClick` does not guard `surface.isTearingDown`, consistent with the existing keyboard `openFolder` path — no behavior change.
