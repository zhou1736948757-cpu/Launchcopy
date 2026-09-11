# T-1E-folder-mouse-open-repair — Worker Result

- Status: PASS
- Task: Bug 2 — after mouse-click opening a folder, outer blue focus ring stays on outer panel; left/right arrows cannot select folder members inside.

## What changed

1. `Sources/PagingPrototypeApp/KeyboardFocusController.swift`
   - Added `public func openFolderFromClick(_ folderID: FolderID)` (line ~285): mirrors the keyboard open path — sets `openedFolderIdentity = .folder(folderID)`, `innerFocusIndex = 0`, `focusModel = AppGridFocusModel(current: nil)`, `applyFocusVisual()`, then `onOpenFolder?(synthetic identity with entryIdentity = .folder(folderID))`, then `applyInnerFocusVisual()`.
   - In existing `openFolder(_ identity:)` (line ~275): added `applyInnerFocusVisual()` after `onOpenFolder?(identity)` — both open paths now show the inner ring on member 1 immediately (also resolves T-1E-D-r1 MINOR).
   - Did NOT change `handleInnerArrow` / `applyInnerFocusVisual` / `closeFolder` semantics.
2. `Sources/PagingPrototypeApp/AppDelegate.swift`
   - `handleFolderCellClick(folderID:)` (line ~559) now routes through `keyboardController?.openFolderFromClick(folderID)` instead of calling `openFolder(folderID:)` directly. `openFolder(folderID:)` kept as the state+overlay primitive (still called via `onOpenFolder`). Click still does not set keyboard focus on the folder cell.
3. `Tests/PagingUITests/FolderIntegrationTests.swift`
   - Replaced `makeFolderClickHandler` with `makeFolderSeam` (wires renderer.onFolderClick → keyboard.openFolderFromClick; keyboard.onOpenFolder → open state + configure overlay; folderOpenStateProvider / folderOverlayProvider).
   - Updated `testFolderCellClickOpensFolderViaRendererSeam` and `testFolderCellClickOpensImmediately` to the new seam (click still opens immediately).
   - Added tests: `testMouseOpenClearsOuterRingAndShowsInnerRing` (outer focus set → click → focusModel.current == nil AND memberCell(at:0).isFocused == true), `testKeyboardOpenShowsInnerRingOnMemberOne` (setFocus folder + Return → member 1 ring), `testMouseOpenThenRightArrowMovesInnerRing` (click-open then right-arrow → ring moves to memberCell(at:1)).

## Verification evidence

- `swift build -c debug` → exit 0.
- `swift test` → 772 executed, 0 failures, exit 0 (two consecutive clean runs; baseline 767 + 5 new tests). One earlier run showed 5 flaky timing failures (24s vs ~11.7s contention); two subsequent full runs were clean.
- `swift build -c release` → exit 0.
- Frozen-tree mtime check: all frozen trees (PagingCore, AppCatalogCore, MacAppCatalog, AppIconPipeline, PagingTelemetry, PagingUI, AppGridUI/FolderOverlayView.swift, AppLaunchController.swift, Package.swift) have mtimes older than my edits — untouched.

## Deviations from packet spec

- None. All fix steps, tests (a)-(d), write scope, and forbidden scope honored. No git ops.
