# T-1F-D1-fix-ui — Review r1 (Defects 1/3/4)

Reviewer: independent, read-only. Task packet: `Workflow/tasks/T-1F-D1-fix-ui.md` (authoritative).
Worker result: `Workflow/results/T-1F-D1-fix-ui.md` (Status: complete). No git baseline (zero commits) — scope verified by mtimes.

## Checkpoint findings

### 1. Defect 1 — preview shows source cell visual: PASS
- `DragUIVisuals.swift:55-74` `showPreview(sourceCell:at:)` builds a mini cell: icon 48pt (`AppGridCellView.iconSide`, :204-207) + name 11pt (:223), 96x88 (:59), icon-top/label-bottom layout (:202-209), frame math `point.x - w/2, point.y + 24` (:60-61), Reduce Motion preserved (:65-73).
- Coordinator `.dragBegan` passes `sourceCell` (`DragUISessionCoordinator.swift:273`).
- Old `showPreview(title:at:)` removed; grep across Sources/ and Tests/ → zero remaining callers (only Workflow doc mentions).
- Observables `previewIconImage`/`previewNameText`/`previewFrame` (:37-41) are test/diagnostic only.

### 2. Defect 3 — click fallback: PASS
- Armed only when controller emits no `.pressed` AND `sourceCell != nil` (`pointerDown` :127-135); blank-press path returns early (:118-122) so never armed for blank.
- Cleared on drag ≥ threshold (`pointerDragged` :153-160), `cancel` (:230-231), `teardown` (:253-254), `endSession` (:357-358).
- `pointerUp` < threshold → `onCellClick(fallback)` exactly once, cleared before dispatch (:190-199).
- Pure controller untouched: `DragSessionController.pointerDown` :62-92 (guard `sourcePresent` :71) and `sourcePresent` :263-272 match spec verbatim; mtime 02:13:48 predates window.

### 3. Defect 4 — folder-inner verification: PASS
- Evidence plausible and code-verified: `memberToken` sets `appID` (`FolderOverlayView.swift:356-367`); `currentEntry?.id` passed (`mouseDown` :278); `servedFolderSnapshot` exists (`AppGridUIPageContentProvider.swift:87`) and gates `openFolder` (`AppDelegate.swift:718`); end-to-end test drives a real `NSEvent` through `overlay.mouseDown` → `.pressed` → `mouseUp` → `onCellClick` (`testOverlayMemberMouseDownRoutesToCoordinatorAndClicks`); AppDelegate tail `handleDragCellClick` :640-654 → `launchMember` verified statically.
- No FolderOverlayView/AppDelegate changes this wave (mtimes 09:29:42 / 15:39:51 predate window).

### 4. Write scope: PASS
- Worker window 16:17:55–16:22:16 touches exactly 3 files: `DragUIVisuals.swift`, `DragUISessionCoordinator.swift`, `T1FD1FixUITests.swift`. All frozen trees (PagingCore/AppCatalogCore/MacAppCatalog/AppIconPipeline/PagingTelemetry/PagingUI), Package.swift, AppLaunchController.swift, existing tests (newest 15:45:18), Docs/, PROVENANCE/ predate the window.

### 5. Privacy: PASS
- New code/tests/results use only neutral fixtures (`app1`, `member0`, `Group 1`, `fixture.*`). No app names, bundle IDs, paths, or folder titles. Grep hits are Swift enum case `.app(...)`, not identities.

## Verification evidence (serial, exact commands)

1. `swift build -c debug` → `Build complete!` **EXIT=0**
2. `swift test` → **Executed 1012 tests, with 0 failures (0 unexpected)**; **EXIT=0** (PIPESTATUS[0]). 7/7 `T1FD1FixUITests` passed (grep-verified). Baseline 1005 + 7 new = 1012.
3. `swift build -c release` → `Build complete!` **EXIT=0**

## MINOR notes (non-blocking)

1. Task packet §6 states baseline 997; actual baseline is 1005 (Wave 1 added tests). Packet number stale — actual 1012 matches reviewer expectation. No action needed beyond a packet refresh.
2. Worker reported test wall time 16.106s; reviewer run 21.8s — timing variance only.
3. Pre-existing warning `FolderOverlayView.swift:276` (unused `index`) — out of scope, not introduced by this wave.
4. Fallback click bypasses controller arbitration window — documented risk, per spec (defense in depth; fires only when controller rejected the press as stale, reuses the `onCellClick` seam).

## Verdict

**PASS**
