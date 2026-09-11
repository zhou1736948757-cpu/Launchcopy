# T-1F-D1-fix-ui — Worker result (Defects 1/3/4)

Status: complete
Role: Worker (implement + verify)
Task packet: Workflow/tasks/T-1F-D1-fix-ui.md (authoritative)

## Changes

### Defect 1 — preview shows source cell visual (icon + name)
- `Sources/AppGridUI/DragUI/DragUIVisuals.swift`:
  - Replaced `previewLabel` with `previewIconView` (NSImageView) + `previewNameLabel`
    (11pt, cell-style) inside the existing rounded-rect `previewView`.
  - New `showPreview(sourceCell: AppGridCellView?, at point: NSPoint)`: mini cell
    96x88, icon 48pt top / name bottom (layout mirrors `AppGridCellView.layout`),
    same frame math (point.x - w/2, point.y + 24) and Reduce Motion behavior.
    Content is same-source (cell's own icon/name) — no new privacy exposure.
  - Removed old `showPreview(title:at:)` (grep: no remaining callers/tests).
  - Added test/diagnostic observables: `previewIconImage`, `previewNameText`,
    `previewFrame`.
- `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift` `.dragBegan`:
  `visuals.showPreview(sourceCell: sourceCell, at: ...)` (was `title: sourceCell?.boundName`).

### Defect 3 — click not swallowed by stale-source guard (coordinator level)
- `Sources/AppGridUI/DragUI/DragUISessionCoordinator.swift` (pure controller untouched):
  - New `clickFallbackCell` + `clickFallbackDownPoint` state.
  - `pointerDown`: when `controller.pointerDown` produces no `.pressed` (stale
    source after commit) and sourceCell != nil → arm fallback (no blank press).
  - `pointerDragged`: fallback armed + distance >= threshold → clear (no-op drag).
  - `pointerUp`: fallback armed + distance < threshold → `onCellClick(fallback)`;
    clear; skip controller path.
  - `cancel`/`teardown`/`endSession`: clear fallback.

### Defect 4 — folder-inner verification-first (see section below)
- No FolderOverlayView/AppDelegate change needed: chain verified intact fresh;
  the swallowing point after a prior commit is the same stale-source guard,
  covered by the Defect-3 fallback.

### New tests
- `Tests/AppGridUITests/T1FD1FixUITests.swift` (7 tests, neutral fixture.* names):
  preview icon+name+follow; stale-source click fallback; stale-source drag no-op;
  fallback cleared on cancel/teardown; folder-member click chain (direct);
  stale folder-member after commit → fallback; overlay.mouseDown → coordinator
  end-to-end member click (real NSEvent + window).

## Defect-4 verified failure point

Verification-first per packet §2c (all steps executed; evidence in
`Tests/AppGridUITests/T1FD1FixUITests.swift`):

1. Member cell bindingToken non-nil with appID — YES (overlay `memberToken`
   sets `appID: AnyHashable(member)`; asserted in overlay test).
2. `currentEntry?.id` non-nil while overlay visible — YES (configure sets
   `currentEntry`; asserted equal to folder id in overlay test).
3. servedFolderSnapshot non-nil and contains the open folder — YES (static:
   `AppGridUIPageContentProvider.servedFolderSnapshot` is the folder source;
   `openFolder` gates on `servedFolderSnapshot?.entry(for:)`; lab fixture
   `FolderLabFixture` builds non-empty `FolderSnapshot`).
4. overlay.mouseDown → coordinator.pointerDown → controller `.pressed` →
   mouseUp under threshold → `.clicked` → onCellClick — VERIFIED END-TO-END
   (overlay test drives real `NSEvent` through `FolderOverlayView.mouseDown`
   into the coordinator; `.pressed` asserted, click dispatched with the member
   cell). AppDelegate tail (`handleDragCellClick` → `folderOpenState?.isOpen ==
   true ? launchMember(appID)` → `AppCatalogAssembly.makeMemberLaunchCell` +
   `launchController.handleCell`) verified statically (AppDelegate not in a
   test target).
5. Stale-source guard after prior commit — CONFIRMED as the swallowing point:
   with a committed layout that moved the member (folder no longer contains
   it), `sourcePresent(.folderMember)` fails → no `.pressed` → click dead.
   Covered by the Defect-3 fallback (test
   `testStaleFolderMemberClickAfterCommitDispatchesFallback`).

**Verified failure point: the stale-source guard
(`DragSessionController.pointerDown` :71) after a prior commit — same root
cause as Defect 3; fixed at coordinator level via clickFallbackCell. The
fresh-state member chain (overlay → coordinator → controller → onCellClick)
is intact.**

## Verification evidence

- `swift build -c debug` → EXIT=0 (Build complete, 42.65s)
- `swift test` → **1012 tests, 0 failures (0 unexpected)** in 16.106s;
  EXIT=0. Baseline 1005 all green + 7 new T1FD1FixUITests all green.
- `swift build -c release` → EXIT=0 (Build complete, 13.04s)

## Acceptance mapping

- Defect 1: drag preview now shows the source cell's icon+name mini block
  (test asserts icon identity + name text + 96x88 cell-proportioned frame +
  pointer follow).
- Defect 3: after a createFolder/reorder commit, clicking the involved apps
  dispatches `onCellClick` (fallback test); drag attempts on stale sources are
  no-ops.
- Defect 4: folder-inner member clicks activate via the intact chain; stale
  members after commit fall back to click dispatch; member drags unchanged
  (existing move-out tests still green).

## Out-of-scope findings

- Pre-existing warning (not introduced by this change, not fixed per scope):
  `Sources/AppGridUI/FolderOverlayView.swift:276` — immutable value 'index'
  never used in `for (index, cell) in memberCells.enumerated()`.
- No out-of-scope test failures.

## Risks

- Fallback click bypasses the controller's click path (no `.pressed`/arbitration
  window): acceptable — it only fires when the controller rejected the press as
  stale, and it reuses the same `onCellClick` seam as the normal click path.
- Preview for folder cells shows name only (folder cells have no `iconView`
  image by design); same-source content, no privacy exposure.
