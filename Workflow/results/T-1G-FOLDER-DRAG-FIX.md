# T-1G-FOLDER-DRAG-FIX — folder-inner drag visual-only / no commit effect

- **Status**: FIXED (pending Reviewer)
- **Date**: 2026-09-10
- **Scope**: non-frozen only (`AppDelegate`, `FolderOpenState`, tests). Frozen trees untouched (`DragSession` / `LayoutDomain` / `LayoutStore` / `PagingCore` / `PagingUI` / `Package.swift` / `AppLaunchController`).

## 1. User symptom

Inside an open Folder, dragging a member shows the drag preview, but drop has no visible effect (reorder/move does not appear to commit).

## 2. Trace (folder-scope drag)

1. `FolderOverlayView.mouseDown` → `DragUISessionCoordinator.pointerDown(..., memberFolderID:)` (`FolderOverlayView.swift` ~339–340)
2. Controller → `.folder` scope; geometry from `AppDelegate.makeDragGeometry(.folder)` → `overlay.memberDragItemFrames` (`AppDelegate.swift` ~822–824)
3. Move/up → `DropZoneClassifier` (folderMember → `.insertion`) → `DropResolver.consume` → `DragMutationEngine.reorderFolderMembers` → `.committed(newLayout)`
4. `onCommit` (`AppDelegate.swift` ~676+):
   - `sessionLayout = newLayout`
   - `provider.applyCommittedLayout(newLayout, …)` updates `servedFolderSnapshot` member order
   - `applyPresentationUpdate` refreshes **top-level** surface only
   - **Before fix**: `folderOpenState.openEntry` stayed at open-time `FolderEntry`; `refreshFolderOverlay()` never ran for in-folder reorder → overlay member cells kept old order

## 3. Root cause (file:line)

**Commit succeeds on the data plane; open-folder UI never resyncs.**

| Layer | What happened | Evidence |
| --- | --- | --- |
| Mutation / commit | Works | `DragUIIntegrationTests.testFolderInternalDragDoesNotMoveOuterPage` asserts `commits[0].members == [beta, alpha]` |
| Provider snapshot | Updated | `applyCommittedLayout` (`AppGridUIPageContentProvider.swift` ~253–307) rewrites `servedFolderSnapshot` |
| Open-state / overlay | **Stale** | `folderOpenState.open` only at open (`AppDelegate.swift` ~934–938); `refreshFolderOverlay` only on open/close/inner-page (`~1000–1030`). Internal reorder kept overlay open (`shouldCloseOpenFolder == false`) without refreshing `openEntry` |

So the user sees a live preview, then drop leaves members visually unchanged — “drag works, no effect.”

Not the frozen-tree causes (stale generation reject, `.invalid` intent, empty geometry): those would cancel/no-op the session before a successful commit payload. Historical BUG6 defect 4 (folderMember → `.invalid`) was already fixed in T-1F-B6-wave-a; this bug is the **post-commit presentation gap**.

## 4. Fix applied

1. **`FolderOpenState.updateOpenEntry(_:)`** (`Sources/AppGridUI/FolderOpenState.swift:74–81`)  
   Replace open entry in place; preserve `innerPage` (clamp); bump generation. Does not reset page to 0 (unlike `open`).

2. **`AppDelegate.resyncOpenFolderAfterLayoutCommit()`** (`Sources/PagingPrototypeApp/AppDelegate.swift:1015–1025`)  
   After successful `applyCommittedLayout`, if the folder stays open: pull entry from `servedFolderSnapshot` → `updateOpenEntry` → `refreshFolderOverlay()`.

3. **Wire into `onCommit`** (`AppDelegate.swift:722–726`) after presentation update, only when `!shouldCloseOpenFolder`.

4. **Test fixture mirror** in `DragCommitIntegrationTests.handleCommit` + assertions that overlay member order matches commit; unit tests for `updateOpenEntry`.

### Files changed

- `Sources/AppGridUI/FolderOpenState.swift` — `updateOpenEntry`
- `Sources/PagingPrototypeApp/AppDelegate.swift` — resync after commit
- `Tests/AppGridUITests/FolderOpenStateTests.swift` — 2 new tests
- `Tests/PagingUITests/DragCommitIntegrationTests.swift` — fixture + overlay order asserts
- `Workflow/results/T-1G-FOLDER-DRAG-FIX.md` — this report

### Frozen trees

**Not modified**: `DragSession/`, `LayoutDomain/`, `LayoutStore/`, `PagingCore/`, `PagingUI/`, `Package.swift`, `AppLaunchController.swift`.

## 5. Verification

```text
swift test --filter 'FolderOpenStateTests|DragCommitIntegrationTests/testFolderMoveOutCommitClosesOverlayButInternalReorderKeepsItOpen|DragUIIntegrationTests/testFolderInternalDragDoesNotMoveOuterPage'
→ Executed 13 tests, 0 failures (exit 0)
```

**Manual**: open a folder with ≥2 apps → drag member A past member B → release → members must swap in the overlay (not only after close/reopen). Move-out past panel edge still closes folder on successful commit.

## 6. Residual risks

- Title-only / no-op commits still call `updateOpenEntry` (generation bump); overlay `configure` short-circuits when `entry == currentEntry`.
- Move-out close path unchanged (`shouldCloseOpenFolder`).
- Physical gate not re-run in this task.
